import Foundation

// MARK: - Skill store

@MainActor
final class SkillStore: ObservableObject {
    @Published private(set) var globalSkills: [Skill] = []
    @Published private(set) var isRefreshing: Bool = false

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
            self?.isRefreshing = false
        }
    }

    // MARK: - Project-scoped queries

    func installedSkills(for projectPath: String) -> [InstalledSkill] {
        SkillInventoryReader.installedSkills(for: projectPath)
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
