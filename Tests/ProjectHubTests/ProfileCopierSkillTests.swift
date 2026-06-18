import XCTest
@testable import ProjectHub

final class ProfileCopierSkillTests: XCTestCase {
    func testPreviewAndCopyUseWritableSkillInventoryOrigins() throws {
        let root = try makeTempDirectory()
        let source = root.appendingPathComponent("source", isDirectory: true)
        let target = root.appendingPathComponent("target", isDirectory: true)
        let nested = source.appendingPathComponent("packages/app", isDirectory: true)
        let shared = source.appendingPathComponent("shared-work", isDirectory: true)
        try FileManager.default.createDirectory(at: source.appendingPathComponent(".git", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target.appendingPathComponent(".git", isDirectory: true), withIntermediateDirectories: true)
        try writeSkill(named: "deploy", under: source.appendingPathComponent(".claude/skills", isDirectory: true))
        try writeSkill(named: "deploy", under: source.appendingPathComponent(".agents/skills", isDirectory: true))
        try writeSkill(named: "app-claude", under: nested.appendingPathComponent(".claude/skills", isDirectory: true))
        try writeSkill(named: "shared-claude", under: shared.appendingPathComponent(".claude/skills", isDirectory: true))
        try FileManager.default.createDirectory(at: source.appendingPathComponent(".claude", isDirectory: true), withIntermediateDirectories: true)
        try """
        {
          "additionalDirectories": ["shared-work"]
        }
        """.write(to: source.appendingPathComponent(".claude/settings.json"), atomically: true, encoding: .utf8)

        withIsolatedToolHomes(root) {
            XCTAssertEqual(ProfileCopier.preview(from: source.path).skills, 4)

            let result = ProfileCopier.copy(
                from: source.path,
                to: target.path,
                options: CopyOptions(skills: true, agents: false, mcpServers: false)
            )

            XCTAssertEqual(result.skillsCopied, 4)
            XCTAssertTrue(result.errors.isEmpty)
            XCTAssertTrue(FileManager.default.fileExists(atPath: target.appendingPathComponent(".claude/skills/deploy/SKILL.md").path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: target.appendingPathComponent(".agents/skills/deploy/SKILL.md").path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: target.appendingPathComponent("packages/app/.claude/skills/app-claude/SKILL.md").path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: target.appendingPathComponent("shared-work/.claude/skills/shared-claude/SKILL.md").path))
        }
    }

    func testCopyFromSelectedSubdirectoryPreservesCodexWorkingDirectorySkills() throws {
        let root = try makeTempDirectory()
        let source = root.appendingPathComponent("source", isDirectory: true)
        let target = root.appendingPathComponent("target", isDirectory: true)
        let sourceApp = source.appendingPathComponent("packages/app", isDirectory: true)
        let targetApp = target.appendingPathComponent("packages/app", isDirectory: true)
        try FileManager.default.createDirectory(at: source.appendingPathComponent(".git", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: targetApp, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target.appendingPathComponent(".git", isDirectory: true), withIntermediateDirectories: true)
        try writeSkill(named: "root-codex", under: source.appendingPathComponent(".agents/skills", isDirectory: true))
        try writeSkill(named: "app-codex", under: sourceApp.appendingPathComponent(".agents/skills", isDirectory: true))

        withIsolatedToolHomes(root) {
            XCTAssertEqual(ProfileCopier.preview(from: sourceApp.path).skills, 2)

            let result = ProfileCopier.copy(
                from: sourceApp.path,
                to: targetApp.path,
                options: CopyOptions(skills: true, agents: false, mcpServers: false)
            )

            XCTAssertEqual(result.skillsCopied, 2)
            XCTAssertTrue(result.errors.isEmpty)
            XCTAssertTrue(FileManager.default.fileExists(atPath: target.appendingPathComponent(".agents/skills/root-codex/SKILL.md").path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: target.appendingPathComponent("packages/app/.agents/skills/app-codex/SKILL.md").path))
        }
    }

    func testCopySkipsPluginAndGlobalSkillEvidence() throws {
        let root = try makeTempDirectory()
        let source = root.appendingPathComponent("source", isDirectory: true)
        let target = root.appendingPathComponent("target", isDirectory: true)
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        let pluginRoot = claudeHome.appendingPathComponent("plugins/marketplaces/team-tools/project-tools", isDirectory: true)
        try FileManager.default.createDirectory(at: source.appendingPathComponent(".git", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target.appendingPathComponent(".git", isDirectory: true), withIntermediateDirectories: true)
        try writeSkill(named: "project-skill", under: source.appendingPathComponent(".claude/skills", isDirectory: true))
        try writeSkill(named: "global-skill", under: claudeHome.appendingPathComponent("skills", isDirectory: true))
        try writeSkill(named: "plugin-skill", under: pluginRoot.appendingPathComponent("skills", isDirectory: true))
        try writeInstalledClaudePlugin(
            pluginID: "project-tools@team-tools",
            installPath: pluginRoot.path,
            claudeHome: claudeHome
        )

        withIsolatedToolHomes(root, claudeHomeOverride: claudeHome) {
            XCTAssertEqual(ProfileCopier.preview(from: source.path).skills, 1)

            let result = ProfileCopier.copy(
                from: source.path,
                to: target.path,
                options: CopyOptions(skills: true, agents: false, mcpServers: false)
            )

            XCTAssertEqual(result.skillsCopied, 1)
            XCTAssertTrue(FileManager.default.fileExists(atPath: target.appendingPathComponent(".claude/skills/project-skill/SKILL.md").path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: target.appendingPathComponent(".claude/skills/global-skill/SKILL.md").path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: target.appendingPathComponent("plugins/marketplaces/team-tools/project-tools/skills/plugin-skill/SKILL.md").path))
        }
    }

    private func writeSkill(named name: String, under skillsRoot: URL) throws {
        let skill = skillsRoot.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)
        try """
        ---
        name: \(name)
        description: Test skill.
        ---

        Test.
        """.write(to: skill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    }

    private func writeInstalledClaudePlugin(
        pluginID: String,
        installPath: String,
        claudeHome: URL
    ) throws {
        let pluginsDirectory = claudeHome.appendingPathComponent("plugins", isDirectory: true)
        try FileManager.default.createDirectory(at: pluginsDirectory, withIntermediateDirectories: true)
        try """
        {
          "version": 2,
          "plugins": {
            "\(pluginID)": [
              {
                "scope": "user",
                "installPath": "\(installPath)",
                "version": "1.0.0"
              }
            ]
          }
        }
        """.write(to: pluginsDirectory.appendingPathComponent("installed_plugins.json"), atomically: true, encoding: .utf8)
    }

    private func withIsolatedToolHomes(
        _ root: URL,
        claudeHomeOverride: URL? = nil,
        run: () throws -> Void
    ) rethrows {
        let claudeHome = claudeHomeOverride ?? root.appendingPathComponent("isolated-claude-home", isDirectory: true)
        let codexHome = root.appendingPathComponent("isolated-codex-home", isDirectory: true)
        try? FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try withEnv("PROJECTHUB_CLAUDE_HOME", claudeHome.path) {
            try withEnv("PROJECTHUB_CLAUDE_JSON_PATH", root.appendingPathComponent("claude.json").path) {
                try withEnv("CODEX_HOME", codexHome.path, run: run)
            }
        }
    }

    private func withEnv(_ key: String, _ value: String, run: () throws -> Void) rethrows {
        let previous = getenv(key).map { String(cString: $0) }
        setenv(key, value, 1)
        defer {
            if let previous {
                setenv(key, previous, 1)
            } else {
                unsetenv(key)
            }
        }
        try run()
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubProfileCopierSkillTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
