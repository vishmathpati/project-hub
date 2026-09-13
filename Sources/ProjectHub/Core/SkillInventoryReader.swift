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
    private struct PluginCacheStamp: Equatable {
        let signature: [String]

        init(cachePath: String) {
            let fm = FileManager.default
            var parts: [String] = []
            for market in (try? fm.contentsOfDirectory(atPath: cachePath)) ?? [] where !market.hasPrefix(".") {
                let marketDir = (cachePath as NSString).appendingPathComponent(market)
                let entries = (try? fm.contentsOfDirectory(atPath: marketDir))?.count ?? 0
                let modified = (try? fm.attributesOfItem(atPath: marketDir))?[.modificationDate] as? Date
                parts.append("\(market)|\(entries)|\(modified?.timeIntervalSince1970 ?? 0)")
            }
            signature = parts.sorted()
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
        // /private/var on macOS). Compare canonical paths, or the same skill
        // reads as two origins and the nested one looks read-only.
        let canonicalProject = canonicalPath(projectPath)
        // "Outside the selected project root" means outside the repository, not
        // outside the subdirectory you happen to have selected — a skill in a
        // sibling package is still yours to copy.
        let canonicalRoot = canonicalPath(ProjectRootDetector.detect(from: projectPath))

        for entry in skillDirectories(for: projectPath) {
            for skill in cachedScanSkillDir(entry.path, source: .claudeGlobal) {
                let canonicalSkill = canonicalPath(skill.path)
                guard seenPaths.insert(canonicalSkill).inserted else { continue }
                collected.append(
                    RawSkill(
                        skill: skill,
                        sourceLabel: entry.sourceLabel,
                        toolLabels: entry.toolLabels,
                        claude: entry.kind == .claude,
                        codex: entry.kind == .codex,
                        canMutate: isWithin(canonicalSkill, canonicalRoot),
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
                scopeLabel: isWithin(canonicalPath(path), canonicalProject) ? "Project" : "Parent",
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
        let cache = (ProjectHubPaths.codexHome() as NSString).appendingPathComponent("plugins/cache")
        let stamp = PluginCacheStamp(cachePath: cache)
        if let hit = memo.pluginRows(matching: stamp) { return hit }

        guard let markets = try? FileManager.default.contentsOfDirectory(atPath: cache) else { return [] }
        var rows: [RawSkill] = []
        for market in markets where !market.hasPrefix(".") {
            let marketDir = (cache as NSString).appendingPathComponent(market)
            guard let plugins = try? FileManager.default.contentsOfDirectory(atPath: marketDir) else { continue }
            for plugin in plugins where !plugin.hasPrefix(".") {
                let pluginDir = (marketDir as NSString).appendingPathComponent(plugin)
                guard let versions = try? FileManager.default.contentsOfDirectory(atPath: pluginDir) else { continue }
                for versionName in versions.sorted().reversed() {
                    let root = (pluginDir as NSString).appendingPathComponent(versionName)
                    let skillDir = (root as NSString).appendingPathComponent("skills")
                    for skill in SkillReader.scanSkillDir(skillDir, source: .codexManaged) {
                        rows.append(
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
                        )
                    }
                    break
                }
            }
        }
        memo.storePluginRows(rows, matching: stamp)
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
