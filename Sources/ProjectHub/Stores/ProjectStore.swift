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
    struct WorktreeInfo: Equatable {
        let gitDir: String?
        let mainRepositoryPath: String?

        var mainRepositoryName: String? {
            mainRepositoryPath.map(Project.folderName)
        }
    }

    let id: UUID
    let path: String
    let displayName: String
    let hasGit: Bool
    let detectedTools: [String]
    let sources: Set<DiscoverySource>
    let worktreeInfo: WorktreeInfo?

    var isWorktree: Bool {
        worktreeInfo != nil
    }

    var primarySource: DiscoverySource {
        if sources.contains(.codexCLI)   { return .codexCLI }
        if sources.contains(.claudeCode) { return .claudeCode }
        return .filesystem
    }

    var orderedSources: [DiscoverySource] {
        [.claudeCode, .codexCLI, .filesystem].filter { sources.contains($0) }
    }
}

struct ProjectDiscoveryResult {
    let projects: [DiscoveredProject]
    let hiddenWorktrees: [DiscoveredProject]
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
    @Published private(set) var hiddenWorktrees: [DiscoveredProject] = []
    @Published private(set) var isScanning: Bool = false

    private let defaultsKey = "projecthub.projects.v1"
    private var inspectionCache: [String: ProjectInspection] = [:]
    private var configFileCache: [String: String] = [:]

    init() {
        load()
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.scan()
        }
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
        invalidateInspectionCache(path: path)
        sortAndPersist()
        return project
    }

    func remove(id: UUID) {
        if let path = projects.first(where: { $0.id == id })?.path {
            invalidateInspectionCache(path: path)
        }
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
        let showSpinner = projects.isEmpty && discovered.isEmpty
        if showSpinner { isScanning = true }
        let existingPaths = Set(projects.map { ProjectStore.discoveryDedupKey($0.path) })
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                ProjectStore.findProjects(excluding: existingPaths)
            }.value
            guard let self else { return }
            if discovered != result.projects {
                discovered = result.projects
            }
            if hiddenWorktrees != result.hiddenWorktrees {
                hiddenWorktrees = result.hiddenWorktrees
            }
            invalidateInspectionCache()
            isScanning = false
        }
    }

    @discardableResult
    func addDiscovered(_ disc: DiscoveredProject) -> Project {
        let p = add(path: disc.path, displayName: disc.displayName)
        discovered.removeAll { $0.id == disc.id }
        hiddenWorktrees.removeAll { $0.id == disc.id }
        return p
    }

    // MARK: - Background scan helpers

    nonisolated private static func findProjects(excluding existingPaths: Set<String>) -> ProjectDiscoveryResult {
        let claudeFound      = fromClaudeJson(excluding: existingPaths)
        let codexFound       = fromCodexSqlite(excluding: existingPaths)
        let codexConfigFound = fromCodexConfig(excluding: existingPaths)
        let fsFound          = fromFilesystem(excluding: existingPaths)

        return mergeDiscoveryCandidates(claudeFound + codexFound + codexConfigFound + fsFound)
    }

    nonisolated static func mergeDiscoveryCandidates(_ candidates: [DiscoveredProject]) -> ProjectDiscoveryResult {
        var byPath: [String: DiscoveredProject] = [:]
        for project in candidates {
            let key = discoveryDedupKey(project.path)
            if let existing = byPath[key] {
                byPath[key] = DiscoveredProject(
                    id:            existing.id,
                    path:          existing.path,
                    displayName:   existing.displayName,
                    hasGit:        existing.hasGit || project.hasGit,
                    detectedTools: Array(Set(existing.detectedTools + project.detectedTools)).sorted(),
                    sources:       existing.sources.union(project.sources),
                    worktreeInfo:  existing.worktreeInfo ?? project.worktreeInfo
                )
            } else {
                byPath[key] = project
            }
        }

        let sorted = byPath.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        return ProjectDiscoveryResult(
            projects: sorted.filter { !$0.isWorktree },
            hiddenWorktrees: sorted.filter(\.isWorktree)
        )
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
            guard let project = makeDiscoveredProject(
                rawPath: rawPath,
                source: .claudeCode,
                excluding: seen,
                fm: fm,
                home: home
            ) else { continue }

            found.append(project)
            seen.insert(discoveryDedupKey(project.path))
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

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        let sql = "SELECT DISTINCT cwd FROM threads WHERE cwd IS NOT NULL AND cwd != '' AND cwd != '/'"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var found: [DiscoveredProject] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let ptr = sqlite3_column_text(stmt, 0) else { continue }
            guard let project = makeDiscoveredProject(
                rawPath: String(cString: ptr),
                source: .codexCLI,
                excluding: seen,
                fm: fm,
                home: home
            ) else { continue }

            found.append(project)
            seen.insert(discoveryDedupKey(project.path))
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
            guard let project = makeDiscoveredProject(
                rawPath: rawPath,
                source: .codexCLI,
                excluding: seen,
                fm: fm,
                home: home
            ) else { continue }

            found.append(project)
            seen.insert(discoveryDedupKey(project.path))
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
                    found.append(p); seen.insert(discoveryDedupKey(p.path))
                } else {
                    guard let level2 = try? fm.contentsOfDirectory(atPath: path) else { continue }
                    for name2 in level2.prefix(20) {
                        guard !name2.hasPrefix("."), !skip.contains(name2) else { continue }
                        let path2 = (path as NSString).appendingPathComponent(name2)
                        var isDir2: ObjCBool = false
                        guard fm.fileExists(atPath: path2, isDirectory: &isDir2), isDir2.boolValue else { continue }
                        if let p = makeProject(at: path2, excluding: seen, fm: fm) {
                            found.append(p); seen.insert(discoveryDedupKey(p.path))
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
        makeDiscoveredProject(
            rawPath: path,
            source: .filesystem,
            excluding: excluding,
            fm: fm,
            home: NSHomeDirectory()
        )
    }

    nonisolated static func makeDiscoveredProject(
        rawPath: String,
        source: DiscoverySource,
        excluding: Set<String>,
        fm: FileManager,
        home: String = NSHomeDirectory()
    ) -> DiscoveredProject? {
        let rawNormalized = normalizedStoredProjectPath(rawPath)
        guard !isProtectedUserStoragePath(rawNormalized, home: home) else { return nil }
        guard let canonical = canonicalDiscoveryPath(rawPath, fm: fm) else { return nil }
        guard !excluding.contains(discoveryDedupKey(canonical)) else { return nil }
        guard !canonical.contains("/.paperclip/") else { return nil }

        let hasGit = hasGitBoundary(at: canonical, fm: fm)
        let tools = detectedTools(at: canonical, fm: fm)
        let worktreeInfo = worktreeInfo(at: canonical, fm: fm)
        let hasCodeMarkers = hasCodeProjectMarkers(at: canonical, fm: fm)

        guard isDiscoverableProjectRoot(
            canonical,
            hasGit: hasGit,
            hasTools: !tools.isEmpty,
            hasCodeMarkers: hasCodeMarkers,
            worktreeInfo: worktreeInfo,
            home: home
        ) else { return nil }

        return DiscoveredProject(
            id:            UUID(),
            path:          canonical,
            displayName:   Project.folderName(at: canonical),
            hasGit:        hasGit,
            detectedTools: tools,
            sources:       [source],
            worktreeInfo:  worktreeInfo
        )
    }

    nonisolated static func canonicalDiscoveryPath(_ rawPath: String, fm: FileManager) -> String? {
        let expanded = (rawPath as NSString).expandingTildeInPath
        let standardized = URL(fileURLWithPath: expanded)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: standardized.path, isDirectory: &isDir) else {
            return nil
        }
        let candidate = isDir.boolValue ? standardized.path : standardized.deletingLastPathComponent().path
        let canonical = Project.canonicalize(candidate)
        var canonicalIsDir: ObjCBool = false
        guard fm.fileExists(atPath: canonical, isDirectory: &canonicalIsDir),
              canonicalIsDir.boolValue else {
            return nil
        }
        return canonical
    }

    nonisolated static func discoveryDedupKey(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
            .lowercased()
    }

    nonisolated static func isDiscoverableProjectRoot(
        _ path: String,
        hasGit: Bool,
        hasTools: Bool,
        hasCodeMarkers: Bool,
        worktreeInfo: DiscoveredProject.WorktreeInfo?,
        home: String = NSHomeDirectory()
    ) -> Bool {
        let canonical = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        guard !isIgnoredDiscoveryRoot(canonical, home: home) else { return false }
        if isCodexSessionRoot(canonical, home: home) {
            return hasGit || hasCodeMarkers || worktreeInfo != nil
        }
        if isGenericContainerNamed(canonical) {
            return hasTools || hasCodeMarkers || worktreeInfo != nil
        }
        return hasGit || hasTools || hasCodeMarkers || worktreeInfo != nil
    }

    nonisolated static func isIgnoredDiscoveryRoot(_ path: String, home: String = NSHomeDirectory()) -> Bool {
        let canonicalHome = URL(fileURLWithPath: (home as NSString).expandingTildeInPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        let canonical = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path

        let exactIgnored: Set<String> = [
            "/",
            canonicalHome,
            (canonicalHome as NSString).appendingPathComponent("Desktop"),
            (canonicalHome as NSString).appendingPathComponent("Documents"),
            (canonicalHome as NSString).appendingPathComponent("Downloads"),
            (canonicalHome as NSString).appendingPathComponent("Library"),
            (canonicalHome as NSString).appendingPathComponent(".codex"),
            (canonicalHome as NSString).appendingPathComponent(".claude"),
            (canonicalHome as NSString).appendingPathComponent(".agents"),
            (canonicalHome as NSString).appendingPathComponent(".cursor"),
            (canonicalHome as NSString).appendingPathComponent("Arel OS"),
            (canonicalHome as NSString).appendingPathComponent("Arel OS/Projects"),
            (canonicalHome as NSString).appendingPathComponent("Arel OS/Projects/Active"),
            (canonicalHome as NSString).appendingPathComponent("Arel OS/Projects/active"),
            (canonicalHome as NSString).appendingPathComponent("Documents/Codex"),
            (canonicalHome as NSString).appendingPathComponent("Documents/New project")
        ]
        return exactIgnored.contains(canonical)
    }

    nonisolated private static func isCodexSessionRoot(_ path: String, home: String) -> Bool {
        let root = URL(fileURLWithPath: (home as NSString).appendingPathComponent("Documents/Codex"))
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        return path == root || path.hasPrefix(root + "/")
    }

    nonisolated private static func isGenericContainerNamed(_ path: String) -> Bool {
        let name = Project.folderName(at: path).lowercased()
        return ["active", "code", "coding", "dev", "projects", "repos", "src", "workspace", "workspaces"].contains(name)
    }

    nonisolated private static func hasGitBoundary(at path: String, fm: FileManager) -> Bool {
        fm.fileExists(atPath: (path as NSString).appendingPathComponent(".git"))
    }

    nonisolated static func hasCodeProjectMarkers(at path: String, fm: FileManager) -> Bool {
        let markerPaths = [
            "Package.swift",
            "package.json",
            "pnpm-lock.yaml",
            "yarn.lock",
            "pyproject.toml",
            "requirements.txt",
            "Cargo.toml",
            "go.mod",
            "pom.xml",
            "build.gradle",
            "settings.gradle",
            "Gemfile",
            "composer.json",
            "mix.exs",
            "deno.json",
            "tsconfig.json",
            "vite.config.js",
            "vite.config.ts",
            "next.config.js",
            "next.config.ts",
            "Sources",
            "src",
            "app",
            "lib",
            "Tests",
            "test",
            "convex"
        ]
        return markerPaths.contains {
            fm.fileExists(atPath: (path as NSString).appendingPathComponent($0))
        }
    }

    nonisolated static func worktreeInfo(at path: String, fm: FileManager) -> DiscoveredProject.WorktreeInfo? {
        let gitPath = (path as NSString).appendingPathComponent(".git")
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: gitPath, isDirectory: &isDir), !isDir.boolValue,
           let content = try? String(contentsOfFile: gitPath, encoding: .utf8),
           let gitDir = parseGitDir(from: content, relativeTo: path) {
            guard let mainRepositoryPath = mainRepositoryPath(fromWorktreeGitDir: gitDir) else {
                return nil
            }
            return DiscoveredProject.WorktreeInfo(
                gitDir: gitDir,
                mainRepositoryPath: mainRepositoryPath
            )
        }

        if path.contains("/.codex/worktrees/") || path.contains("/.claude/worktrees/") {
            return DiscoveredProject.WorktreeInfo(
                gitDir: nil,
                mainRepositoryPath: nil
            )
        }

        return nil
    }

    nonisolated private static func parseGitDir(from content: String, relativeTo worktreePath: String) -> String? {
        guard let line = content.components(separatedBy: .newlines).first(where: {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("gitdir:")
        }) else { return nil }
        let value = line
            .replacingOccurrences(of: "gitdir:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        let url: URL
        if value.hasPrefix("/") || value.hasPrefix("~") {
            url = URL(fileURLWithPath: (value as NSString).expandingTildeInPath)
        } else {
            url = URL(fileURLWithPath: worktreePath).appendingPathComponent(value)
        }
        return url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    nonisolated private static func mainRepositoryPath(fromWorktreeGitDir gitDir: String) -> String? {
        let gitDirURL = URL(fileURLWithPath: gitDir).standardizedFileURL
        let worktreesURL = gitDirURL.deletingLastPathComponent()
        guard worktreesURL.lastPathComponent == "worktrees" else { return nil }
        let gitURL = worktreesURL.deletingLastPathComponent()
        guard gitURL.lastPathComponent == ".git" else { return nil }
        return gitURL.deletingLastPathComponent().path
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

        if exists(".grok/config.toml") || exists(".grok") {
            append("grok")
        }

        return ids
    }

    private struct ProjectInspection {
        let exists: Bool
        let facts: ProjectFacts
        let toolIDs: [String]
    }

    private func inspection(for project: Project) -> ProjectInspection {
        if let cached = inspectionCache[project.path] { return cached }
        let exists = project.exists
        let facts = ProjectFacts(path: project.path)
        let toolIDs = exists
            ? ProjectStore.detectedTools(at: project.path, fm: FileManager.default)
            : []
        let value = ProjectInspection(exists: exists, facts: facts, toolIDs: toolIDs)
        inspectionCache[project.path] = value
        return value
    }

    func invalidateInspectionCache(path: String? = nil) {
        if let path {
            inspectionCache.removeValue(forKey: path)
            let prefix = path + "\u{1f}"
            configFileCache = configFileCache.filter { !$0.key.hasPrefix(prefix) && $0.key != path }
            return
        }
        inspectionCache.removeAll()
        configFileCache.removeAll()
    }

    func detectedToolIDs(for project: Project) -> [String] {
        inspection(for: project).toolIDs
    }

    func facts(for project: Project) -> ProjectFacts? {
        guard inspection(for: project).exists else { return nil }
        return inspection(for: project).facts
    }

    func configFileSummary(for toolID: String, at path: String) -> String {
        let key = path + "\u{1f}" + toolID
        if let cached = configFileCache[key] { return cached }
        let value = ProjectFacts.configFiles(for: toolID, at: path)
        configFileCache[key] = value
        return value
    }

    func cachedExists(_ project: Project) -> Bool {
        inspection(for: project).exists
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
            let sanitized = ProjectStore.sanitizeSavedProjects(decoded)
            projects = sanitized.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
            if sanitized != decoded {
                persist()
            }
        }
    }

    nonisolated static func sanitizeSavedProjects(_ projects: [Project], home: String = NSHomeDirectory()) -> [Project] {
        var seen: Set<String> = []
        var kept: [Project] = []

        for var project in projects {
            let normalized = normalizedStoredProjectPath(project.path)
            guard !isStaleSavedProjectPath(normalized, home: home) else { continue }

            let key = normalized.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            project.path = normalized
            if project.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                project.displayName = Project.folderName(at: normalized)
            }
            kept.append(project)
        }

        return kept
    }

    nonisolated static func isSafeForBackgroundInspection(_ path: String, home: String = NSHomeDirectory()) -> Bool {
        let normalized = normalizedStoredProjectPath(path)
        guard !isStaleSavedProjectPath(normalized, home: home) else { return false }
        return !isProtectedUserStoragePath(normalized, home: home)
    }

    nonisolated private static func normalizedStoredProjectPath(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL
            .path
    }

    nonisolated private static func isStaleSavedProjectPath(_ path: String, home: String) -> Bool {
        let normalizedHome = normalizedStoredProjectPath(home)
        let exactIgnored: Set<String> = [
            "/",
            normalizedHome,
            (normalizedHome as NSString).appendingPathComponent("Desktop"),
            (normalizedHome as NSString).appendingPathComponent("Documents"),
            (normalizedHome as NSString).appendingPathComponent("Downloads"),
            (normalizedHome as NSString).appendingPathComponent("Library"),
            (normalizedHome as NSString).appendingPathComponent(".codex"),
            (normalizedHome as NSString).appendingPathComponent(".claude"),
            (normalizedHome as NSString).appendingPathComponent(".agents"),
            (normalizedHome as NSString).appendingPathComponent(".cursor"),
            (normalizedHome as NSString).appendingPathComponent("Arel OS"),
            (normalizedHome as NSString).appendingPathComponent("Arel OS/Projects"),
            (normalizedHome as NSString).appendingPathComponent("Arel OS/Projects/Active"),
            (normalizedHome as NSString).appendingPathComponent("Arel OS/Projects/active"),
            (normalizedHome as NSString).appendingPathComponent("Documents/Codex"),
            (normalizedHome as NSString).appendingPathComponent("Documents/New project")
        ]
        if exactIgnored.contains(path) { return true }

        let parent = (path as NSString).deletingLastPathComponent
        let topLevelContainerParents: Set<String> = [
            normalizedHome,
            (normalizedHome as NSString).appendingPathComponent("Desktop"),
            (normalizedHome as NSString).appendingPathComponent("Documents"),
            (normalizedHome as NSString).appendingPathComponent("Downloads")
        ]
        return topLevelContainerParents.contains(parent) && isGenericContainerNamed(path)
    }

    nonisolated private static func isProtectedUserStoragePath(_ path: String, home: String) -> Bool {
        let normalizedHome = normalizedStoredProjectPath(home)
        let protectedRoots = [
            (normalizedHome as NSString).appendingPathComponent("Desktop"),
            (normalizedHome as NSString).appendingPathComponent("Documents"),
            (normalizedHome as NSString).appendingPathComponent("Downloads")
        ]
        return protectedRoots.contains { root in
            path == root || path.hasPrefix(root + "/")
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
