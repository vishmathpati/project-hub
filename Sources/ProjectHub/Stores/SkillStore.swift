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
        Task.detached(priority: .utility) { [weak self] in
            let skills = SkillStore.scanGlobalSkills()
            await MainActor.run {
                self?.globalSkills = skills
                self?.isRefreshing = false
            }
        }
    }

    // MARK: - Project-scoped queries

    func installedSkills(for projectPath: String) -> [InstalledSkill] {
        let fm = FileManager.default

        // Claude: .claude/skills/<name>/SKILL.md
        let claudeSkillsDir = (projectPath as NSString).appendingPathComponent(".claude/skills")
        // Codex: .agents/skills/<name>/SKILL.md
        let codexSkillsDir  = (projectPath as NSString).appendingPathComponent(".agents/skills")

        var byName: [String: (claudePath: String?, codexPath: String?, desc: String)] = [:]

        for (dir, kind) in [(claudeSkillsDir, "claude"), (codexSkillsDir, "codex")] {
            guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for entry in entries.sorted() {
                let skillDir = (dir as NSString).appendingPathComponent(entry)
                let skillMd  = (skillDir as NSString).appendingPathComponent("SKILL.md")
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: skillDir, isDirectory: &isDir), isDir.boolValue else { continue }
                guard fm.fileExists(atPath: skillMd) else { continue }

                let parsed = SkillReader.parse(at: skillMd)
                let desc   = parsed?.description ?? ""
                let name   = parsed?.name ?? entry

                if byName[name] == nil {
                    byName[name] = (claudePath: nil, codexPath: nil, desc: desc)
                }
                if kind == "claude" {
                    byName[name]?.claudePath = skillDir
                } else {
                    byName[name]?.codexPath = skillDir
                }
                if byName[name]?.desc.isEmpty == true && !desc.isEmpty {
                    byName[name]?.desc = desc
                }
            }
        }

        return byName.keys.sorted().map { name in
            let info = byName[name]!
            return InstalledSkill(
                name:        name,
                description: info.desc,
                claudePath:  info.claudePath,
                codexPath:   info.codexPath
            )
        }
    }

    /// Install a global skill into the project (copies to .claude/skills AND .agents/skills).
    func install(skill: Skill, to projectPath: String) {
        let fm = FileManager.default
        let targets: [(String, String)] = [
            ((projectPath as NSString).appendingPathComponent(".claude/skills"), skill.name),
            ((projectPath as NSString).appendingPathComponent(".agents/skills"), skill.name),
        ]

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

    /// Remove a skill from the project (deletes from both .claude/skills and .agents/skills).
    func remove(skillName: String, from projectPath: String) {
        let fm = FileManager.default
        let targets = [
            (projectPath as NSString).appendingPathComponent(".claude/skills/\(skillName)"),
            (projectPath as NSString).appendingPathComponent(".agents/skills/\(skillName)"),
        ]
        for path in targets {
            guard fm.fileExists(atPath: path) else { continue }
            try? fm.removeItem(atPath: path)
        }
    }

    // MARK: - Global skill scan (nonisolated)

    nonisolated private static func scanGlobalSkills() -> [Skill] {
        let home = NSHomeDirectory()
        let dirs: [(String, SkillSource)] = [
            ((home as NSString).appendingPathComponent(".claude/skills"),        .claudeGlobal),
            ((home as NSString).appendingPathComponent(".codex/skills"),         .codexGlobal),
            ((home as NSString).appendingPathComponent(".cursor/skills-cursor"), .cursorGlobal),
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
}
