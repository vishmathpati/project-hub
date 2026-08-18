import XCTest
@testable import ProjectHub

final class KnownSkillRootsTests: XCTestCase {
    func testFindsNestedClaudeSkillsAndSkipsHeavyDirectories() throws {
        let root = try makeTempDirectory()
        try writeSkill(named: "app-skill", under: root.appendingPathComponent(".claude/skills", isDirectory: true))
        try writeSkill(
            named: "widget-skill",
            under: root.appendingPathComponent("features/widget/.claude/skills", isDirectory: true)
        )
        try writeSkill(
            named: "junk-skill",
            under: root.appendingPathComponent("node_modules/pkg/.claude/skills", isDirectory: true)
        )
        try writeSkill(
            named: "build-skill",
            under: root.appendingPathComponent(".build/checkouts/pkg/.claude/skills", isDirectory: true)
        )

        let found = KnownSkillRoots.existingNestedClaudeSkillDirectories(
            from: root,
            excluding: []
        )
        let names = Set(found.map { $0.appendingPathComponent("placeholder").deletingLastPathComponent().lastPathComponent })
        let skillNames = Set(found.compactMap { URL in
            (try? FileManager.default.contentsOfDirectory(atPath: URL.path))?.first
        })

        XCTAssertTrue(skillNames.contains("app-skill"))
        XCTAssertTrue(skillNames.contains("widget-skill"))
        XCTAssertFalse(skillNames.contains("junk-skill"))
        XCTAssertFalse(skillNames.contains("build-skill"))
        XCTAssertEqual(names, ["skills"])
    }

    func testDoesNotFollowSymlinksOutOfTheProject() throws {
        let root = try makeTempDirectory()
        let outside = try makeTempDirectory()
        try writeSkill(named: "outside-skill", under: outside.appendingPathComponent(".claude/skills", isDirectory: true))
        let link = root.appendingPathComponent("escape")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)

        let found = KnownSkillRoots.existingNestedClaudeSkillDirectories(from: root, excluding: [])
        let skillNames = Set(found.compactMap { url in
            (try? FileManager.default.contentsOfDirectory(atPath: url.path))?.first
        })

        XCTAssertFalse(skillNames.contains("outside-skill"))
    }

    func testInventoryFromWorktreeDoesNotUseMainRepoSkills() throws {
        let temp = try makeTempDirectory()
        let main = temp.appendingPathComponent("main", isDirectory: true)
        let worktree = temp.appendingPathComponent("feature", isDirectory: true)
        try FileManager.default.createDirectory(at: main.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)
        try "gitdir: \(main.path)/.git/worktrees/feature\n"
            .write(to: worktree.appendingPathComponent(".git"), atomically: true, encoding: .utf8)
        try writeSkill(named: "main-skill", under: main.appendingPathComponent(".claude/skills", isDirectory: true))
        try writeSkill(named: "worktree-skill", under: worktree.appendingPathComponent(".claude/skills", isDirectory: true))

        XCTAssertEqual(ProjectRootDetector.detect(from: worktree.path), worktree.path)

        withIsolatedHomes(temp) {
            let skills = SkillInventoryReader.installedSkills(for: worktree.path)
            let names = Set(skills.map(\.name))
            XCTAssertTrue(names.contains("worktree-skill"))
            XCTAssertFalse(names.contains("main-skill"))
        }
    }

    private func writeSkill(named name: String, under skillsRoot: URL) throws {
        let dir = skillsRoot.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try """
        ---
        name: \(name)
        description: test
        ---
        # \(name)
        """.write(to: dir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    }

    private func withIsolatedHomes(_ root: URL, run: () -> Void) {
        let claudeHome = root.appendingPathComponent("isolated-claude-home", isDirectory: true)
        let codexHome = root.appendingPathComponent("isolated-codex-home", isDirectory: true)
        try? FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        let previousClaude = getenv("PROJECTHUB_CLAUDE_HOME").map { String(cString: $0) }
        let previousJSON = getenv("PROJECTHUB_CLAUDE_JSON_PATH").map { String(cString: $0) }
        let previousCodex = getenv("CODEX_HOME").map { String(cString: $0) }
        setenv("PROJECTHUB_CLAUDE_HOME", claudeHome.path, 1)
        setenv("PROJECTHUB_CLAUDE_JSON_PATH", root.appendingPathComponent("claude.json").path, 1)
        setenv("CODEX_HOME", codexHome.path, 1)
        defer {
            if let previousClaude { setenv("PROJECTHUB_CLAUDE_HOME", previousClaude, 1) } else { unsetenv("PROJECTHUB_CLAUDE_HOME") }
            if let previousJSON { setenv("PROJECTHUB_CLAUDE_JSON_PATH", previousJSON, 1) } else { unsetenv("PROJECTHUB_CLAUDE_JSON_PATH") }
            if let previousCodex { setenv("CODEX_HOME", previousCodex, 1) } else { unsetenv("CODEX_HOME") }
        }
        run()
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubKnownSkillRootsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
