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
        return url.path
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
        Task.detached(priority: .utility) { [weak self] in
            let found = ProjectStore.findProjects(excluding: existingPaths)
            await MainActor.run {
                self?.discovered = found
                self?.isScanning = false
            }
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
        let claudeJsonPath = (home as NSString).appendingPathComponent(".claude.json")

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
        let codexDir = (home as NSString).appendingPathComponent(".codex")

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
            guard hasGit else { continue }
            let tools = detectedTools(at: canonical, fm: fm)
            found.append(DiscoveredProject(
                id: UUID(), path: canonical, displayName: folderName,
                hasGit: true, detectedTools: tools, sources: [.codexCLI]
            ))
            seen.insert(canonical)
            if found.count >= 40 { break }
        }
        return found
    }

    nonisolated private static func fromCodexConfig(excluding existingPaths: Set<String>) -> [DiscoveredProject] {
        let fm   = FileManager.default
        let home = NSHomeDirectory()
        let configPath = (home as NSString).appendingPathComponent(".codex/config.toml")

        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else { return [] }

        let broadPaths: Set<String> = [
            home, "/",
            (home as NSString).appendingPathComponent("Desktop"),
            (home as NSString).appendingPathComponent("Downloads"),
            (home as NSString).appendingPathComponent("Documents"),
            (home as NSString).appendingPathComponent("Library"),
        ]

        guard let regex = try? NSRegularExpression(pattern: #"\[projects\."([^"]+)"\]"#) else { return [] }
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        var seen = existingPaths
        var found: [DiscoveredProject] = []

        for match in matches {
            guard let pathRange = Range(match.range(at: 1), in: content) else { continue }
            let rawPath = String(content[pathRange])
            let canonical = Project.canonicalize(rawPath)

            guard !seen.contains(canonical) else { continue }
            guard !broadPaths.contains(canonical) else { continue }

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

    nonisolated private static func detectedTools(at path: String, fm: FileManager) -> [String] {
        let checks: [(String, String)] = [
            (".mcp.json",        "claude-code"),
            (".cursor/mcp.json", "cursor"),
            (".codex/config.toml", "codex"),
        ]
        return checks.compactMap { (rel, id) in
            fm.fileExists(atPath: (path as NSString).appendingPathComponent(rel)) ? id : nil
        }
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
