import Foundation

// MARK: - Skill store

@MainActor
final class SkillStore: ObservableObject {
    @Published private(set) var globalSkills: [Skill] = []
    @Published private(set) var globalSkillInstallCounts: [String: Int] = [:]
    @Published private(set) var isRefreshing: Bool = false
    @Published private(set) var isRefreshingInstallCounts: Bool = false

    private var installCountTask: Task<Void, Never>?

    init() {
        refresh()
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task { [weak self] in
            let skills = await Task.detached(priority: .utility) {
                SkillStore.scanGlobalSkills()
            }.value
            self?.globalSkills = skills
            self?.globalSkillInstallCounts = [:]
            self?.isRefreshing = false
        }
    }

    func refreshGlobalSkillInstallCounts(for projects: [Project]) {
        installCountTask?.cancel()

        let skillSnapshot = globalSkills
        let projectSnapshot = projects

        guard !skillSnapshot.isEmpty, !projectSnapshot.isEmpty else {
            globalSkillInstallCounts = [:]
            isRefreshingInstallCounts = false
            return
        }

        isRefreshingInstallCounts = true
        installCountTask = Task { [weak self] in
            let counts = await Task.detached(priority: .utility) {
                SkillStore.installedProjectCounts(
                    globalSkills: skillSnapshot,
                    projects: projectSnapshot,
                    installedSkillsProvider: SkillStore.scanInstalledSkills(for:)
                )
            }.value

            guard !Task.isCancelled else { return }
            self?.globalSkillInstallCounts = counts
            self?.isRefreshingInstallCounts = false
        }
    }

    // MARK: - Project-scoped queries

    func installedSkills(for projectPath: String) -> [InstalledSkill] {
        SkillStore.scanInstalledSkills(for: projectPath)
    }

    /// Install a global skill into the matching project skill root.
    func install(skill: Skill, to projectPath: String) {
        let fm = FileManager.default
        let targets = installTargets(for: skill, projectPath: projectPath)

        for (baseDir, name) in targets {
            let destDir = (baseDir as NSString).appendingPathComponent(name)
            if fm.fileExists(atPath: destDir) { continue }   // already installed
            do {
                try fm.createDirectory(atPath: baseDir, withIntermediateDirectories: true)
                try fm.copyItem(atPath: skill.path, toPath: destDir)
            } catch {
                // Best-effort; surface errors silently for now
            }
        }
    }

    /// Remove only the selected installed skill origin.
    func remove(skill: InstalledSkill, from projectPath: String) {
        guard skill.canRemove else { return }
        let canonicalProject = Project.canonicalize(ProjectRootDetector.detect(from: projectPath))
        let canonicalSkill = canonicalFilePath(skill.path)
        guard canonicalSkill == canonicalProject || canonicalSkill.hasPrefix(canonicalProject + "/") else { return }
        try? FileManager.default.removeItem(atPath: skill.path)
    }

    /// Legacy caller support: remove writable origins with the selected name.
    func remove(skillName: String, from projectPath: String) {
        for skill in installedSkills(for: projectPath) where skill.name == skillName && skill.canRemove {
            remove(skill: skill, from: projectPath)
        }
    }

    func installTargets(for skill: Skill, projectPath: String) -> [(String, String)] {
        switch skill.source {
        case .claudeGlobal:
            return [((projectPath as NSString).appendingPathComponent(".claude/skills"), skill.name)]
        case .codexGlobal, .codexAdmin, .codexManaged:
            return [((projectPath as NSString).appendingPathComponent(".agents/skills"), skill.name)]
        case .cursorGlobal:
            return []
        }
    }

    func isInstalled(_ skill: Skill, in installed: [InstalledSkill]) -> Bool {
        switch skill.source {
        case .claudeGlobal:
            return installed.contains { $0.name == skill.name && $0.claudePath != nil }
        case .codexGlobal, .codexAdmin, .codexManaged:
            return installed.contains { $0.name == skill.name && $0.codexPath != nil }
        case .cursorGlobal:
            return installed.contains { $0.name == skill.name }
        }
    }

    // MARK: - Global skill scan (nonisolated)

    nonisolated private static func scanGlobalSkills() -> [Skill] {
        let home = NSHomeDirectory()
        let codexHome = ProjectHubPaths.codexHome(home: home)
        let dirs: [(String, SkillSource)] = [
            ((home as NSString).appendingPathComponent(".claude/skills"),        .claudeGlobal),
            ((home as NSString).appendingPathComponent(".agents/skills"),         .codexGlobal),
            ("/etc/codex/skills",                                                .codexAdmin),
            ((codexHome as NSString).appendingPathComponent("skills"),           .codexManaged),
        ]

        var all: [Skill] = []
        for (dir, source) in dirs {
            all += SkillReader.scanSkillDir(dir, source: source)
        }
        return all.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    nonisolated static func installedProjectCounts(
        globalSkills: [Skill],
        projects: [Project],
        home: String = NSHomeDirectory(),
        installedSkillsProvider: (String) -> [InstalledSkill]
    ) -> [String: Int] {
        let globalSkillNames = Set(globalSkills.map(\.name))
        guard !globalSkillNames.isEmpty else { return [:] }

        var counts: [String: Int] = [:]
        for project in projects where ProjectStore.isSafeForBackgroundInspection(project.path, home: home) {
            let installedNames = Set(installedSkillsProvider(project.path).map(\.name))
            for name in installedNames where globalSkillNames.contains(name) {
                counts[name, default: 0] += 1
            }
        }
        return counts
    }

    nonisolated private static func scanInstalledSkills(for projectPath: String) -> [InstalledSkill] {
        SkillInventoryReader.installedSkills(for: projectPath)
    }

    // MARK: - Convenience: global skill names set

    func globalSkillNames() -> Set<String> {
        Set(globalSkills.map { $0.name })
    }

    private func canonicalFilePath(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }
}
