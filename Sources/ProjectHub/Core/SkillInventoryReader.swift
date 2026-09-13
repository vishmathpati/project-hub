import Foundation

enum SkillInventoryReader {

    // MARK: - Stamped scan memo

    /// A parsed skill root is a pure function of the SKILL.md files inside it.
    /// Fingerprinting the directory's own modified date keeps the check to a single
    /// stat per candidate root instead of one per skill, which is what made the
    /// project-count loop cost seconds. In-place SKILL.md edits are covered by
    /// `invalidateCaches()`, which every in-app install, edit, and removal calls.
    private struct RootStamp: Equatable {
        let entryCount: Int
        let modified: Date?

        init?(path: String) {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else {
                return nil
            }
            let names = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
            entryCount = names.count
            modified = attrs[.modificationDate] as? Date
        }
    }

    /// Plugin bundles nest three levels deep, so the fingerprint comes from the
    /// markets themselves; installing, removing, or updating a plugin changes one.
    /// Which ones are enabled lives in config.toml, so that file is part of the key.
    private struct PluginCacheStamp: Equatable {
        let signature: [String]
        let configModified: Date?

        init(cachePath: String, configPath: String) {
            let fm = FileManager.default
            var parts: [String] = []
            for market in (try? fm.contentsOfDirectory(atPath: cachePath)) ?? [] where !market.hasPrefix(".") {
                let marketDir = (cachePath as NSString).appendingPathComponent(market)
                let entries = (try? fm.contentsOfDirectory(atPath: marketDir))?.count ?? 0
                let modified = (try? fm.attributesOfItem(atPath: marketDir))?[.modificationDate] as? Date
                parts.append("\(market)|\(entries)|\(modified?.timeIntervalSince1970 ?? 0)")
            }
            signature = parts.sorted()
            configModified = (try? fm.attributesOfItem(atPath: configPath))?[.modificationDate] as? Date
        }
    }

    private final class ScanMemo: @unchecked Sendable {
        private let lock = NSLock()
        private var roots: [String: (RootStamp, [Skill])] = [:]
        private var plugins: (PluginCacheStamp, [RawSkill])?
        /// `String??` distinguishes "not read yet" from "read, has no version".
        private var versions: [String: String?] = [:]

        func skills(for path: String, matching stamp: RootStamp) -> [Skill]? {
            lock.lock(); defer { lock.unlock() }
            guard let hit = roots[path], hit.0 == stamp else { return nil }
            return hit.1
        }

        func store(_ skills: [Skill], for path: String, matching stamp: RootStamp) {
            lock.lock(); defer { lock.unlock() }
            roots[path] = (stamp, skills)
        }

        func pluginRows(matching stamp: PluginCacheStamp) -> [RawSkill]? {
            lock.lock(); defer { lock.unlock() }
            guard let hit = plugins, hit.0 == stamp else { return nil }
            return hit.1
        }

        func storePluginRows(_ rows: [RawSkill], matching stamp: PluginCacheStamp) {
            lock.lock(); defer { lock.unlock() }
            plugins = (stamp, rows)
        }

        /// Reading a version means reading SKILL.md, and that read repeated for every
        /// collected skill on every inventory. The value is memoized instead; the
        /// owning root's stamp and `invalidateCaches()` cover staleness.
        func version(for path: String) -> String?? {
            lock.lock(); defer { lock.unlock() }
            return versions[path]
        }

        func storeVersion(_ version: String?, for path: String) {
            lock.lock(); defer { lock.unlock() }
            versions[path] = version
        }

        func clear() {
            lock.lock(); defer { lock.unlock() }
            roots.removeAll()
            plugins = nil
            versions.removeAll()
        }
    }

    private static let memo = ScanMemo()

    /// Drops every parsed root. Callers must run this after a skill is installed,
    /// edited, or removed, so an in-place SKILL.md edit is not masked by the stamp.
    static func invalidateCaches() {
        memo.clear()
    }

    private static func cachedScanSkillDir(_ dirPath: String, source: SkillSource) -> [Skill] {
        guard let stamp = RootStamp(path: dirPath) else {
            return SkillReader.scanSkillDir(dirPath, source: source)
        }
        if let hit = memo.skills(for: dirPath, matching: stamp) { return hit }
        let skills = SkillReader.scanSkillDir(dirPath, source: source)
        memo.store(skills, for: dirPath, matching: stamp)
        return skills
    }

    static func installedSkills(for projectPath: String) -> [InstalledSkill] {
        var collected: [RawSkill] = []
        var seenPaths = Set<String>()

        // Directory discovery mixes two path forms: the walk-up uses the path as
        // given, while the nested walk resolves symlinks (so /var becomes
        // /private/var on macOS). Skills are deduped on their resolved path so the
        // same skill never reads as two origins, but ownership is judged on the
        // path as written: an installed skill is a link that sits inside the
        // project and points outside it.
        let canonicalRoot = literalPath(ProjectRootDetector.detect(from: projectPath))
        // "Outside the selected project root" means outside the repository, not
        // outside the subdirectory you happen to have selected — a skill in a
        // sibling package is still yours to copy.
        let canonicalProject = literalPath(projectPath)

        for entry in skillDirectories(for: projectPath) {
            for skill in cachedScanSkillDir(entry.path, source: .claudeGlobal) {
                // Dedupe on the resolved path so a linked skill and its target read
                // as one entry, but judge ownership on the path as written: an
                // installed skill is a link that sits in the project and points
                // outside it, and removing it only deletes the link.
                let resolvedSkill = canonicalPath(skill.path)
                guard seenPaths.insert(resolvedSkill).inserted else { continue }
                collected.append(
                    RawSkill(
                        skill: skill,
                        sourceLabel: entry.sourceLabel,
                        toolLabels: entry.toolLabels,
                        claude: entry.kind == .claude,
                        codex: entry.kind == .codex,
                        canMutate: isWithin(literalPath(skill.path), canonicalRoot),
                        readOnlyReason: entry.readOnlyReason,
                        nameOverride: nil
                    )
                )
            }
        }

        for plugin in codexPluginSkills() {
            guard seenPaths.insert(plugin.skill.path).inserted else { continue }
            collected.append(plugin)
        }

        let disabled = disabledSkillPaths(from: projectPath)
        let versions = collected.map { version(at: $0.skill.path) }
        let names = Dictionary(grouping: collected.indices, by: { collected[$0].displayName.lowercased() })

        return collected.enumerated().map { index, raw in
            var diagnostics: [String] = []
            if (names[raw.displayName.lowercased()]?.count ?? 0) > 1 {
                diagnostics.append("Duplicate name")
            }
            let groupVersions = Set((names[raw.displayName.lowercased()] ?? []).compactMap { versions[$0] })
            if groupVersions.count > 1 {
                diagnostics.append("Version conflict")
            }
            let path = raw.skill.path
            let state: InstalledSkill.State = disabled.contains(path) || disabled.contains((path as NSString).appendingPathComponent("SKILL.md"))
                ? .disabled
                : .active
            return InstalledSkill(
                originID: path,
                name: raw.displayName,
                description: raw.skill.description,
                claudePath: raw.claude ? path : nil,
                codexPath: raw.codex ? path : nil,
                path: path,
                skillMDPath: (path as NSString).appendingPathComponent("SKILL.md"),
                sourceLabel: raw.sourceLabel,
                scopeLabel: isWithin(literalPath(path), canonicalProject) ? "Project" : "Parent",
                toolLabels: raw.toolLabels,
                state: state,
                version: versions[index],
                diagnostics: diagnostics,
                canEdit: raw.canMutate,
                canRemove: raw.canMutate,
                readOnlyReason: raw.canMutate ? nil : raw.readOnlyReason
            )
        }
        .sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Resolves symlinks and tilde so two spellings of one directory compare equal.
    private static func canonicalPath(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    /// The path as written, tilde expanded but symlinks left alone. Ownership tests
    /// use this so a link inside the project counts as belonging to the project.
    private static func literalPath(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL
            .path
    }

    private static func isWithin(_ path: String, _ root: String) -> Bool {
        path == root || path.hasPrefix(root + "/")
    }

    private struct DirSpec {
        enum Kind { case claude, codex, other }
        let path: String
        let sourceLabel: String
        let toolLabels: [String]
        let kind: Kind
        let readOnlyReason: String?
    }

    private struct RawSkill {
        let skill: Skill
        let sourceLabel: String
        let toolLabels: [String]
        let claude: Bool
        let codex: Bool
        let canMutate: Bool
        let readOnlyReason: String?
        let nameOverride: String?

        var displayName: String { nameOverride ?? skill.name }
    }

    private static func skillDirectories(for projectPath: String) -> [DirSpec] {
        var dirs: [DirSpec] = []
        var seen = Set<String>()
        var current = URL(fileURLWithPath: projectPath)
        let specs = ProviderCatalog.specs()

        for _ in 0..<6 {
            for spec in specs {
                for relative in spec.projectSkillDirs {
                    let path = current.appendingPathComponent(relative).path
                    guard seen.insert(path).inserted else { continue }
                    dirs.append(dirSpec(path: path, specID: spec.id, specName: spec.name, extraLabel: nil))
                }
            }
            appendAdditionalClaudeDirectories(from: current, into: &dirs, seen: &seen)
            if FileManager.default.fileExists(atPath: current.appendingPathComponent(".git").path) {
                break
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }

        for nested in KnownSkillRoots.existingNestedClaudeSkillDirectories(
            from: URL(fileURLWithPath: projectPath),
            excluding: Set(dirs.map(\.path)),
            maxDepth: 4,
            maxDirectoriesVisited: 80
        ) {
            guard seen.insert(nested.path).inserted else { continue }
            dirs.append(dirSpec(path: nested.path, specID: "claude-code", specName: "Claude Code", extraLabel: nil))
        }
        return dirs
    }

    private static func appendAdditionalClaudeDirectories(from root: URL, into dirs: inout [DirSpec], seen: inout Set<String>) {
        let settings = root.appendingPathComponent(".claude/settings.json")
        guard let raw = try? String(contentsOfFile: settings.path, encoding: .utf8),
              let data = ConfigWriter.stripJsonComments(raw).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        var extras: [String] = stringArray(json["additionalDirectories"])
        if let permissions = json["permissions"] as? [String: Any] {
            extras += stringArray(permissions["additionalDirectories"])
        }
        for extra in extras {
            let expanded: URL
            if extra.hasPrefix("/") || extra.hasPrefix("~") {
                expanded = URL(fileURLWithPath: (extra as NSString).expandingTildeInPath)
            } else {
                expanded = root.appendingPathComponent(extra)
            }
            let path = expanded.appendingPathComponent(".claude/skills").path
            guard seen.insert(path).inserted else { continue }
            dirs.append(
                DirSpec(
                    path: path,
                    sourceLabel: "Claude Code additional-directory skills",
                    toolLabels: ["Claude Code"],
                    kind: .claude,
                    readOnlyReason: "This skill is outside the selected project root."
                )
            )
        }
    }

    private static func dirSpec(path: String, specID: String, specName: String, extraLabel: String?) -> DirSpec {
        let kind: DirSpec.Kind
        let labels: [String]
        switch specID {
        case "claude-code":
            kind = .claude
            labels = ["Claude Code"]
        case "codex":
            kind = .codex
            labels = ["Codex CLI", "Codex Desktop"]
        default:
            kind = .other
            labels = [specName]
        }
        return DirSpec(
            path: path,
            sourceLabel: extraLabel ?? specName,
            toolLabels: labels,
            kind: kind,
            readOnlyReason: "This skill is outside the selected project root."
        )
    }

    private static func disabledSkillPaths(from projectPath: String) -> Set<String> {
        var disabled = Set<String>()
        var current = URL(fileURLWithPath: projectPath)
        for _ in 0..<6 {
            let toml = current.appendingPathComponent(".codex/config.toml")
            if let raw = try? String(contentsOfFile: toml.path, encoding: .utf8) {
                disabled.formUnion(disabledPaths(inTOML: raw))
            }
            if FileManager.default.fileExists(atPath: current.appendingPathComponent(".git").path) {
                break
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }
        return disabled
    }

    private static func disabledPaths(inTOML raw: String) -> Set<String> {
        var disabled = Set<String>()
        var currentPath: String?
        for line in raw.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("path") {
                if let start = trimmed.firstIndex(of: "\""),
                   let end = trimmed[trimmed.index(after: start)...].firstIndex(of: "\"") {
                    currentPath = String(trimmed[trimmed.index(after: start)..<end])
                }
            }
            if trimmed.contains("enabled") && (trimmed.contains("false") || trimmed.contains("0")) {
                if let currentPath { disabled.insert(currentPath) }
            }
        }
        return disabled
    }

    private static func codexPluginSkills() -> [RawSkill] {
        let codexHome = ProjectHubPaths.codexHome()
        let cache = (codexHome as NSString).appendingPathComponent("plugins/cache")
        let configPath = (codexHome as NSString).appendingPathComponent("config.toml")
        let stamp = PluginCacheStamp(cachePath: cache, configPath: configPath)
        if let hit = memo.pluginRows(matching: stamp) { return hit }

        let enabled = enabledCodexPlugins(configPath: configPath)
        let rows: [RawSkill]
        if enabled.isEmpty {
            rows = allCachedPluginSkills(cachePath: cache)
        } else {
            var collected: [RawSkill] = []
            for plugin in enabled {
                collected.append(contentsOf: pluginSkillRows(name: plugin.name, market: plugin.market, cachePath: cache))
            }
            rows = collected
        }
        memo.storePluginRows(rows, matching: stamp)
        return rows
    }

    /// Codex records every known plugin in `~/.codex/config.toml` as
    /// `[plugins."name@market"]` with an `enabled` flag. Reading that one small file
    /// beats walking the cache: this machine holds 65 cached plugins but only 15 are
    /// enabled, so the walk parsed 435 SKILL.md files and reported roughly 50
    /// plugins that are not installed as if they were.
    private static func enabledCodexPlugins(configPath: String) -> [(name: String, market: String)] {
        guard let text = try? String(contentsOfFile: configPath, encoding: .utf8) else { return [] }
        var enabled: [(name: String, market: String)] = []
        var pending: (name: String, market: String)?

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("[plugins.") {
                let inner = line.dropFirst("[plugins.".count).dropLast(line.hasSuffix("]") ? 1 : 0)
                let cleaned = inner.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                guard let at = cleaned.lastIndex(of: "@") else { pending = nil; continue }
                let name = String(cleaned[cleaned.startIndex..<at])
                let market = String(cleaned[cleaned.index(after: at)...])
                pending = (name.isEmpty || market.isEmpty) ? nil : (name, market)
                continue
            }

            guard let current = pending, line.hasPrefix("enabled") else { continue }
            if line.contains("true") { enabled.append(current) }
            pending = nil
        }
        return enabled
    }

    /// Newest version only, matching how Codex resolves a plugin's active bundle.
    private static func pluginSkillRows(name: String, market: String, cachePath: String) -> [RawSkill] {
        let pluginDir = ((cachePath as NSString).appendingPathComponent(market) as NSString)
            .appendingPathComponent(name)
        guard let versions = try? FileManager.default.contentsOfDirectory(atPath: pluginDir) else { return [] }
        for versionName in versions.sorted().reversed() {
            let skillDir = ((pluginDir as NSString).appendingPathComponent(versionName) as NSString)
                .appendingPathComponent("skills")
            return pluginRows(plugin: name, in: skillDir)
        }
        return []
    }

    private static func pluginRows(plugin: String, in skillDir: String) -> [RawSkill] {
        SkillReader.scanSkillDir(skillDir, source: .codexManaged).map { skill in
            RawSkill(
                skill: skill,
                sourceLabel: "Codex plugin",
                toolLabels: ["Codex CLI", "Codex Desktop"],
                claude: false,
                codex: true,
                canMutate: false,
                readOnlyReason: "Installed by a Codex plugin.",
                nameOverride: "\(plugin):\(skill.name)"
            )
        }
    }

    /// Fallback for a Codex install whose config has no `[plugins.*]` section.
    private static func allCachedPluginSkills(cachePath: String) -> [RawSkill] {
        guard let markets = try? FileManager.default.contentsOfDirectory(atPath: cachePath) else { return [] }
        var rows: [RawSkill] = []
        for market in markets where !market.hasPrefix(".") {
            let marketDir = (cachePath as NSString).appendingPathComponent(market)
            guard let plugins = try? FileManager.default.contentsOfDirectory(atPath: marketDir) else { continue }
            for plugin in plugins where !plugin.hasPrefix(".") {
                rows.append(contentsOf: pluginSkillRows(name: plugin, market: market, cachePath: cachePath))
            }
        }
        return rows
    }

    private static func version(at skillDirectory: String) -> String? {
        if let cached = memo.version(for: skillDirectory) { return cached }

        let path = (skillDirectory as NSString).appendingPathComponent("SKILL.md")
        var parsed: String?
        if let content = try? String(contentsOfFile: path, encoding: .utf8) {
            for line in content.split(whereSeparator: \.isNewline) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("version:") else { continue }
                let value = trimmed.dropFirst("version:".count).trimmingCharacters(in: .whitespaces)
                parsed = value.isEmpty ? nil : value
                break
            }
        }
        memo.storeVersion(parsed, for: skillDirectory)
        return parsed
    }

    private static func stringArray(_ value: Any?) -> [String] {
        if let strings = value as? [String] { return strings }
        if let any = value as? [Any] { return any.compactMap { $0 as? String } }
        return []
    }
}
