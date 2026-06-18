import Foundation
import AppKit
import SQLite3

// MARK: - Discovery source

enum DiscoverySource: Equatable, Hashable, CaseIterable {
    case claudeCode   // ~/.claude.json → projects
    case codexCLI     // ~/.codex/state_N.sqlite → threads.cwd
    case filesystem   // filesystem walk of ~/Projects, ~/Developer, etc.
}

// MARK: - Discovered project model

struct DiscoveredProject: Identifiable, Equatable {
    let id: UUID
    let path: String
    let displayName: String
    let hasGit: Bool
    let detectedTools: [String]
    let sources: Set<DiscoverySource>

    var primarySource: DiscoverySource {
        if sources.contains(.codexCLI)   { return .codexCLI }
        if sources.contains(.claudeCode) { return .claudeCode }
        return .filesystem
    }

    var orderedSources: [DiscoverySource] {
        [.claudeCode, .codexCLI, .filesystem].filter { sources.contains($0) }
    }
}

// MARK: - Project model

struct Project: Codable, Identifiable, Equatable {
    let id: UUID
    var path: String
    var displayName: String
    var addedAt: Date
    var lastOpenedAt: Date

    static func canonicalize(_ raw: String) -> String {
        let expanded = (raw as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).standardizedFileURL.resolvingSymlinksInPath()
        return ProjectRootDetector.detect(from: url.path)
    }

    static func folderName(at path: String) -> String {
        (path as NSString).lastPathComponent
    }

    var exists: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}

// MARK: - Store

@MainActor
final class ProjectStore: ObservableObject {
    @Published private(set) var projects:   [Project] = []
    @Published private(set) var discovered: [DiscoveredProject] = []
    @Published private(set) var isScanning: Bool = false

    private let defaultsKey = "projecthub.projects.v1"

    init() {
        load()
        scan()
    }

    // MARK: - Public API

    @discardableResult
    func add(path rawPath: String, displayName: String? = nil) -> Project {
        let path = Project.canonicalize(rawPath)
        if let idx = projects.firstIndex(where: { $0.path == path }) {
            projects[idx].lastOpenedAt = Date()
            if let name = displayName { projects[idx].displayName = name }
            sortAndPersist()
            return projects[idx]
        }
        let now = Date()
        let project = Project(
            id: UUID(),
            path: path,
            displayName: displayName ?? Project.folderName(at: path),
            addedAt: now,
            lastOpenedAt: now
        )
        projects.append(project)
        sortAndPersist()
        return project
    }

    func remove(id: UUID) {
        projects.removeAll { $0.id == id }
        persist()
    }

    func rename(id: UUID, to name: String) {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        projects[idx].displayName = trimmed.isEmpty ? Project.folderName(at: projects[idx].path) : trimmed
        persist()
    }

    func touch(id: UUID) {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[idx].lastOpenedAt = Date()
        sortAndPersist()
    }

    func pickFolder() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Add project folder"
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return Project.canonicalize(url.path)
    }

    // MARK: - Auto-discovery

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        let existingPaths = Set(projects.map { $0.path })
        Task { [weak self] in
            let found = await Task.detached(priority: .utility) {
                ProjectStore.findProjects(excluding: existingPaths)
            }.value
            guard let self else { return }
            discovered = found
            isScanning = false
        }
    }

    @discardableResult
    func addDiscovered(_ disc: DiscoveredProject) -> Project {
        let p = add(path: disc.path, displayName: disc.displayName)
        discovered.removeAll { $0.id == disc.id }
        return p
    }

    // MARK: - Background scan helpers

    nonisolated private static func findProjects(excluding existingPaths: Set<String>) -> [DiscoveredProject] {
        let claudeFound      = fromClaudeJson(excluding: existingPaths)
        let codexFound       = fromCodexSqlite(excluding: existingPaths)
        let codexConfigFound = fromCodexConfig(excluding: existingPaths)
        let fsFound          = fromFilesystem(excluding: existingPaths)

        var byPath: [String: DiscoveredProject] = [:]
        for project in claudeFound + codexFound + codexConfigFound + fsFound {
            if let existing = byPath[project.path] {
                byPath[project.path] = DiscoveredProject(
                    id:            existing.id,
                    path:          existing.path,
                    displayName:   existing.displayName,
                    hasGit:        existing.hasGit || project.hasGit,
                    detectedTools: Array(Set(existing.detectedTools + project.detectedTools)).sorted(),
                    sources:       existing.sources.union(project.sources)
                )
            } else {
                byPath[project.path] = project
            }
        }

        return byPath.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    nonisolated private static func fromClaudeJson(excluding existingPaths: Set<String>) -> [DiscoveredProject] {
        var seen = existingPaths
        let fm   = FileManager.default
        let home = NSHomeDirectory()
        let claudeJsonPath = ProjectRootDetector.claudeJSONPath(home: home)

        guard let data     = fm.contents(atPath: claudeJsonPath),
              let json     = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projects = json["projects"] as? [String: Any]
        else { return [] }

        var found: [DiscoveredProject] = []

        for rawPath in projects.keys {
            let canonical = Project.canonicalize(rawPath)
            guard !seen.contains(canonical) else { continue }
            guard !canonical.contains("/.claude/worktrees/") else { continue }
            guard !canonical.contains("/.paperclip/") else { continue }
            guard canonical != "/", canonical != home else { continue }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: canonical, isDirectory: &isDir), isDir.boolValue else { continue }

            let hasGit = fm.fileExists(atPath: (canonical as NSString).appendingPathComponent(".git"))
            let tools  = detectedTools(at: canonical, fm: fm)

            found.append(DiscoveredProject(
                id:            UUID(),
                path:          canonical,
                displayName:   Project.folderName(at: canonical),
                hasGit:        hasGit,
                detectedTools: tools,
                sources:       [.claudeCode]
            ))
            seen.insert(canonical)
            if found.count >= 60 { break }
        }

        return found
    }

    nonisolated private static func fromCodexSqlite(excluding existingPaths: Set<String>) -> [DiscoveredProject] {
        var seen = existingPaths
        let fm   = FileManager.default
        let home = NSHomeDirectory()
        let codexDir = ProjectHubPaths.codexHome(home: home)

        let dbPath = (1...9).reversed().lazy.compactMap { n -> String? in
            let p = (codexDir as NSString).appendingPathComponent("state_\(n).sqlite")
            return fm.fileExists(atPath: p) ? p : nil
        }.first
        guard let dbPath else { return [] }

        let broadPaths: Set<String> = [
            home, "/",
            (home as NSString).appendingPathComponent("Desktop"),
            (home as NSString).appendingPathComponent("Downloads"),
            (home as NSString).appendingPathComponent("Documents"),
            (home as NSString).appendingPathComponent("Library"),
        ]

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        let sql = "SELECT DISTINCT cwd FROM threads WHERE cwd IS NOT NULL AND cwd != '' AND cwd != '/'"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        let codexSessionDir = (home as NSString).appendingPathComponent("Documents/Codex")
        var found: [DiscoveredProject] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let ptr = sqlite3_column_text(stmt, 0) else { continue }
            let canonical = Project.canonicalize(String(cString: ptr))
            guard !seen.contains(canonical), !broadPaths.contains(canonical) else { continue }
            guard !canonical.hasPrefix(codexSessionDir) else { continue }
            let folderName = Project.folderName(at: canonical)
            let looksLikeSession = folderName.count > 10 &&
                folderName.prefix(4).allSatisfy(\.isNumber) &&
                folderName.dropFirst(4).hasPrefix("-")
            guard !looksLikeSession else { continue }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: canonical, isDirectory: &isDir), isDir.boolValue else { continue }
            let hasGit = fm.fileExists(atPath: (canonical as NSString).appendingPathComponent(".git"))
            let tools = detectedTools(at: canonical, fm: fm)
            guard hasGit || !tools.isEmpty else { continue }
            found.append(DiscoveredProject(
                id: UUID(), path: canonical, displayName: folderName,
                hasGit: hasGit, detectedTools: tools, sources: [.codexCLI]
            ))
            seen.insert(canonical)
            if found.count >= 40 { break }
        }
        return found
    }

    nonisolated private static func fromCodexConfig(excluding existingPaths: Set<String>) -> [DiscoveredProject] {
        let fm   = FileManager.default
        let home = NSHomeDirectory()
        let codexDir = ProjectHubPaths.codexHome(home: home)
        let configPath = (codexDir as NSString).appendingPathComponent("config.toml")

        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else { return [] }

        var seen = existingPaths
        var found: [DiscoveredProject] = []

        for rawPath in ProjectRootDetector.codexProjectRootPaths(in: content) {
            let canonical = Project.canonicalize(rawPath)

            guard !seen.contains(canonical) else { continue }

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: canonical, isDirectory: &isDir), isDir.boolValue else { continue }

            let hasGit = fm.fileExists(atPath: (canonical as NSString).appendingPathComponent(".git"))
            let tools  = detectedTools(at: canonical, fm: fm)

            found.append(DiscoveredProject(
                id:            UUID(),
                path:          canonical,
                displayName:   Project.folderName(at: canonical),
                hasGit:        hasGit,
                detectedTools: tools,
                sources:       [.codexCLI]
            ))
            seen.insert(canonical)
        }

        return found
    }

    nonisolated private static func fromFilesystem(excluding existingPaths: Set<String>) -> [DiscoveredProject] {
        var seen = existingPaths
        let fm   = FileManager.default
        let home = NSHomeDirectory()

        let rootNames = ["Projects", "Developer", "dev", "code", "src", "workspace", "Sites"]
        let roots = rootNames
            .map { (home as NSString).appendingPathComponent($0) }
            .filter { fm.fileExists(atPath: $0) }

        let skip: Set<String> = [
            "node_modules", ".git", ".cache", "Library", ".Trash",
            "build", "dist", ".next", "vendor", ".npm", ".yarn",
            "DerivedData", ".gradle", "__pycache__"
        ]

        var found: [DiscoveredProject] = []

        for root in roots {
            guard let level1 = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for name in level1.sorted() {
                guard !name.hasPrefix("."), !skip.contains(name) else { continue }
                let path = (root as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }

                if let p = makeProject(at: path, excluding: seen, fm: fm) {
                    found.append(p); seen.insert(p.path)
                } else {
                    guard let level2 = try? fm.contentsOfDirectory(atPath: path) else { continue }
                    for name2 in level2.prefix(20) {
                        guard !name2.hasPrefix("."), !skip.contains(name2) else { continue }
                        let path2 = (path as NSString).appendingPathComponent(name2)
                        var isDir2: ObjCBool = false
                        guard fm.fileExists(atPath: path2, isDirectory: &isDir2), isDir2.boolValue else { continue }
                        if let p = makeProject(at: path2, excluding: seen, fm: fm) {
                            found.append(p); seen.insert(p.path)
                        }
                        if found.count >= 40 { break }
                    }
                }
                if found.count >= 40 { break }
            }
            if found.count >= 40 { break }
        }

        return found
    }

    nonisolated private static func makeProject(at path: String, excluding: Set<String>, fm: FileManager) -> DiscoveredProject? {
        let canonical = Project.canonicalize(path)
        guard !excluding.contains(canonical) else { return nil }

        let hasGit = fm.fileExists(atPath: (canonical as NSString).appendingPathComponent(".git"))
        let tools  = detectedTools(at: canonical, fm: fm)
        guard hasGit || !tools.isEmpty else { return nil }

        return DiscoveredProject(
            id:            UUID(),
            path:          canonical,
            displayName:   Project.folderName(at: canonical),
            hasGit:        hasGit,
            detectedTools: tools,
            sources:       [.filesystem]
        )
    }

    nonisolated static func detectedTools(at path: String, fm: FileManager) -> [String] {
        var ids: [String] = []

        func append(_ id: String) {
            if !ids.contains(id) {
                ids.append(id)
            }
        }

        func exists(_ rel: String) -> Bool {
            fm.fileExists(atPath: (path as NSString).appendingPathComponent(rel))
        }

        let claudeMarkers = [
            ".mcp.json",
            "CLAUDE.md",
            "CLAUDE.local.md",
            ".claude/CLAUDE.md",
            ".claude/settings.json",
            ".claude/settings.local.json",
            ".claude/skills"
        ]
        if claudeMarkers.contains(where: exists) {
            append("claude-code")
        }

        let codexMarkers = [
            ".codex/config.toml",
            "AGENTS.md",
            "AGENTS.override.md",
            ".agents/skills"
        ]
        if codexMarkers.contains(where: exists) {
            append("codex")
        }

        if exists(".cursor/mcp.json") {
            append("cursor")
        }

        if exists(".vscode/mcp.json") {
            append("vscode")
        }

        if exists(".roo/mcp.json") {
            append("roo")
        }

        return ids
    }

    func detectedToolIDs(for project: Project) -> [String] {
        ProjectStore.detectedTools(at: project.path, fm: FileManager.default)
    }

    // MARK: - Persistence

    private func sortAndPersist() {
        projects.sort { $0.lastOpenedAt > $1.lastOpenedAt }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        if let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            projects = decoded.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
        }
    }
}

// MARK: - Project root detection

enum ProjectRootDetector {
    static func detect(from rawPath: String) -> String {
        let expanded = (rawPath as NSString).expandingTildeInPath
        let requested = URL(fileURLWithPath: expanded).standardizedFileURL.resolvingSymlinksInPath()
        let fm = FileManager.default
        let startURL: URL
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: requested.path, isDirectory: &isDir), !isDir.boolValue {
            startURL = requested.deletingLastPathComponent()
        } else {
            startURL = requested
        }

        let candidates = ancestorPaths(from: startURL.path)
        let configuredRoots = codexProjectRoots().union(claudeProjectRoots())
        let configuredRoot = bestConfiguredRoot(in: candidates, configuredRoots: configuredRoots)
        let gitRoot = nearestGitRoot(in: candidates, fm: fm)
        if let configuredRoot {
            if let gitRoot,
               let gitIndex = candidates.firstIndex(of: gitRoot),
               let configuredIndex = candidates.firstIndex(of: configuredRoot),
               gitIndex < configuredIndex {
                return gitRoot
            }
            return configuredRoot
        }
        if let gitRoot { return gitRoot }

        var best = startURL.path
        let markers = projectRootMarkers()

        var url = startURL
        while true {
            let path = url.path
            if isMeaningfulConfiguredRoot(path),
               hasProjectMarkers(path, markers: markers) {
                best = path
            }
            let parent = url.deletingLastPathComponent()
            guard parent.path != url.path else { return best }
            url = parent
        }
    }

    private static func ancestorPaths(from start: String) -> [String] {
        var url = URL(fileURLWithPath: start).standardizedFileURL.resolvingSymlinksInPath()
        var paths: [String] = []
        while true {
            paths.append(url.path)
            let parent = url.deletingLastPathComponent()
            guard parent.path != url.path else { break }
            url = parent
        }
        return paths
    }

    private static func bestConfiguredRoot(in ancestors: [String], configuredRoots: Set<String>) -> String? {
        ancestors.first { configuredRoots.contains($0) && isMeaningfulConfiguredRoot($0) }
    }

    private static func nearestGitRoot(in ancestors: [String], fm: FileManager) -> String? {
        ancestors.first { isGitBoundary($0, fm: fm) }
    }

    private static func isGitBoundary(_ path: String, fm: FileManager) -> Bool {
        let gitPath = (path as NSString).appendingPathComponent(".git")
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: gitPath, isDirectory: &isDir) {
            return true
        }
        return false
    }

    private static func claudeProjectRoots() -> Set<String> {
        let path = claudeJSONPath()
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projects = json["projects"] as? [String: Any] else {
            return []
        }
        return Set(projects.keys.map(normalizeConfiguredPath).filter(isMeaningfulConfiguredRoot))
    }

    static func claudeJSONPath(home: String = NSHomeDirectory()) -> String {
        if let override = ProcessInfo.processInfo.environment["PROJECTHUB_CLAUDE_JSON_PATH"],
           !override.isEmpty {
            return (override as NSString).expandingTildeInPath
        }
        return (home as NSString).appendingPathComponent(".claude.json")
    }

    private static func codexProjectRoots() -> Set<String> {
        let codexDir = ProjectHubPaths.codexHome(home: NSHomeDirectory())
        let path = (codexDir as NSString).appendingPathComponent("config.toml")
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return []
        }

        return Set(codexProjectRootPaths(in: content))
    }

    static func codexProjectRootPaths(in content: String) -> [String] {
        let paths = content.components(separatedBy: .newlines).compactMap { rawLine in
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("["),
                  let section = tomlSectionName(from: trimmed) else { return nil }
            let segments = tomlSectionSegments(section)
            guard segments.count == 2, segments[0] == "projects" else { return nil }
            return normalizeConfiguredPath(segments[1])
        }.filter(isMeaningfulConfiguredRoot)
        return uniqueStringsPreservingOrder(paths)
    }

    private static func projectRootMarkers() -> [String] {
        let builtIn = [
            "Package.swift",
            "package.json",
            "pyproject.toml",
            "Cargo.toml",
            "go.mod",
            "AGENTS.md",
            "CLAUDE.md",
            ".mcp.json",
            ".codex/config.toml",
            ".cursor/mcp.json",
            ".vscode/mcp.json",
            ".roo/mcp.json",
            ".agents/skills",
            ".claude/settings.json",
            ".claude/launch.json",
            ".claude/skills"
        ]
        return uniqueStringsPreservingOrder(builtIn + codexProjectRootMarkers())
    }

    private static func codexProjectRootMarkers() -> [String] {
        let codexDir = ProjectHubPaths.codexHome(home: NSHomeDirectory())
        let path = (codexDir as NSString).appendingPathComponent("config.toml")
        guard let content = try? String(contentsOfFile: path, encoding: .utf8),
              let raw = topLevelTOMLValue(named: "project_root_markers", in: content),
              let values = parseTOMLStringArrayLiteral(raw) else { return [] }
        return values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter(isSafeProjectRootMarker)
    }

    private static func normalizeConfiguredPath(_ raw: String) -> String {
        let expanded = (raw as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    private static func isMeaningfulConfiguredRoot(_ path: String) -> Bool {
        let home = normalizeConfiguredPath(NSHomeDirectory())
        let broadPaths: Set<String> = [
            "/",
            home,
            (home as NSString).appendingPathComponent("Desktop"),
            (home as NSString).appendingPathComponent("Documents"),
            (home as NSString).appendingPathComponent("Downloads"),
            (home as NSString).appendingPathComponent("Library")
        ]
        return !broadPaths.contains(path)
    }

    private static func unescapeTOMLBasicString(_ raw: String) -> String {
        var output = ""
        var iterator = raw.makeIterator()
        while let character = iterator.next() {
            guard character == "\\" else {
                output.append(character)
                continue
            }
            guard let escaped = iterator.next() else {
                output.append("\\")
                break
            }
            switch escaped {
            case "b": output.append("\u{08}")
            case "t": output.append("\t")
            case "n": output.append("\n")
            case "f": output.append("\u{0c}")
            case "r": output.append("\r")
            case "\"": output.append("\"")
            case "\\": output.append("\\")
            default:
                output.append("\\")
                output.append(escaped)
            }
        }
        return output
    }

    private static func hasProjectMarkers(_ path: String, markers: [String]) -> Bool {
        let fm = FileManager.default
        return markers.contains {
            fm.fileExists(atPath: (path as NSString).appendingPathComponent($0))
        }
    }

    private static func isSafeProjectRootMarker(_ value: String) -> Bool {
        !value.isEmpty
            && value != "."
            && value != ".."
            && !value.hasPrefix("/")
            && !value.contains("..")
            && !value.contains("\\")
    }

    private static func topLevelTOMLValue(named key: String, in toml: String) -> String? {
        for rawLine in toml.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if trimmed.hasPrefix("[") { return nil }
            guard let eq = rawLine.firstIndex(of: "=") else { continue }
            let rawKey = rawLine[..<eq]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard rawKey == key else { continue }
            return String(rawLine[rawLine.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func parseTOMLStringArrayLiteral(_ raw: String) -> [String]? {
        let value = splitTOMLValueAndComment(raw).value.trimmingCharacters(in: .whitespaces)
        guard value.hasPrefix("["),
              value.hasSuffix("]") else { return nil }
        let inner = String(value.dropFirst().dropLast())
        if inner.trimmingCharacters(in: .whitespaces).isEmpty { return [] }
        var values: [String] = []
        for item in splitTOMLArray(inner) {
            guard let value = parseTOMLStringLiteral(item.trimmingCharacters(in: .whitespaces)) else {
                return nil
            }
            values.append(value)
        }
        return values
    }

    private static func splitTOMLValueAndComment(_ text: String) -> (value: String, comment: String) {
        var inSingle = false
        var inDouble = false
        var escaped = false
        for (offset, char) in text.enumerated() {
            if escaped {
                escaped = false
                continue
            }
            if inDouble && char == "\\" {
                escaped = true
                continue
            }
            if char == "\"", !inSingle {
                inDouble.toggle()
                continue
            }
            if char == "'", !inDouble {
                inSingle.toggle()
                continue
            }
            if char == "#", !inSingle, !inDouble {
                let index = text.index(text.startIndex, offsetBy: offset)
                return (String(text[..<index]), String(text[index...]))
            }
        }
        return (text, "")
    }

    private static func parseTOMLStringLiteral(_ text: String) -> String? {
        if text.hasPrefix("\""), text.hasSuffix("\""), text.count >= 2 {
            var value = ""
            var escaped = false
            for char in text.dropFirst().dropLast() {
                if escaped {
                    switch char {
                    case "n": value.append("\n")
                    case "t": value.append("\t")
                    case "\"": value.append("\"")
                    case "\\": value.append("\\")
                    default: value.append(char)
                    }
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else {
                    value.append(char)
                }
            }
            return escaped ? nil : value
        }
        if text.hasPrefix("'"), text.hasSuffix("'"), text.count >= 2 {
            return String(text.dropFirst().dropLast())
        }
        return nil
    }

    private static func tomlSectionName(from header: String) -> String? {
        let value = splitTOMLValueAndComment(header).value.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("[["),
           value.hasSuffix("]]"),
           value.count > 4 {
            return String(value.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
        }
        if value.hasPrefix("["),
           value.hasSuffix("]"),
           value.count > 2 {
            return String(value.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func tomlSectionSegments(_ section: String) -> [String] {
        var segments: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escaped = false

        func appendSegment() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                segments.append(parseTOMLStringLiteral(trimmed) ?? trimmed)
            }
            current = ""
        }

        for character in section {
            if escaped {
                current.append(character)
                escaped = false
                continue
            }
            if inDouble && character == "\\" {
                current.append(character)
                escaped = true
                continue
            }
            if character == "\"", !inSingle {
                current.append(character)
                inDouble.toggle()
                continue
            }
            if character == "'", !inDouble {
                current.append(character)
                inSingle.toggle()
                continue
            }
            if character == ".", !inSingle, !inDouble {
                appendSegment()
            } else {
                current.append(character)
            }
        }
        appendSegment()
        return segments
    }

    private static func splitTOMLArray(_ text: String) -> [String] {
        var items: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escaped = false

        for character in text {
            if escaped {
                current.append(character)
                escaped = false
                continue
            }
            if inDouble && character == "\\" {
                current.append(character)
                escaped = true
                continue
            }
            if character == "'", !inDouble {
                inSingle.toggle()
                current.append(character)
                continue
            }
            if character == "\"", !inSingle {
                inDouble.toggle()
                current.append(character)
                continue
            }
            if character == ",", !inSingle, !inDouble {
                items.append(current)
                current = ""
                continue
            }
            current.append(character)
        }
        if !current.isEmpty { items.append(current) }
        return items
    }

    private static func uniqueStringsPreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }
}
