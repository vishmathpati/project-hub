import XCTest
@testable import ProjectHub

final class SkillInventoryReaderTests: XCTestCase {
    func testInventoryIncludesClaudeParentNestedAndSettingsAdditionalDirectoryRoots() throws {
        let root = try makeTempProject()
        let app = root.appendingPathComponent("packages/app", isDirectory: true)
        let nested = app.appendingPathComponent("features/widget", isDirectory: true)
        let shared = root.appendingPathComponent("shared-work", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try writeSkill(named: "root-skill", under: root.appendingPathComponent(".claude/skills", isDirectory: true))
        try writeSkill(named: "app-skill", under: app.appendingPathComponent(".claude/skills", isDirectory: true))
        try writeSkill(named: "widget-skill", under: nested.appendingPathComponent(".claude/skills", isDirectory: true))
        try writeSkill(named: "shared-skill", under: shared.appendingPathComponent(".claude/skills", isDirectory: true))
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".claude", isDirectory: true), withIntermediateDirectories: true)
        try """
        {
          "additionalDirectories": ["shared-work"]
        }
        """.write(to: root.appendingPathComponent(".claude/settings.json"), atomically: true, encoding: .utf8)

        withIsolatedToolHomes(root) {
            let skills = SkillInventoryReader.installedSkills(for: app.path)
            let names = Set(skills.map(\.name))

            XCTAssertTrue(names.contains("root-skill"))
            XCTAssertTrue(names.contains("app-skill"))
            XCTAssertTrue(names.contains("widget-skill"))
            XCTAssertTrue(names.contains("shared-skill"))
            XCTAssertTrue(skills.contains { $0.name == "shared-skill" && $0.sourceLabel == "Claude Code additional-directory skills" })
        }
    }

    func testInventoryIncludesCodexParentSkillsAndDisabledOverrideState() throws {
        let root = try makeTempProject()
        let app = root.appendingPathComponent("packages/app", isDirectory: true)
        let appSkillRoot = app.appendingPathComponent(".agents/skills", isDirectory: true)
        try writeSkill(named: "root-codex", under: root.appendingPathComponent(".agents/skills", isDirectory: true))
        try writeSkill(named: "app-codex", under: appSkillRoot)
        let skillMD = appSkillRoot.appendingPathComponent("app-codex/SKILL.md")
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".codex", isDirectory: true), withIntermediateDirectories: true)
        try """
        [[skills.config]]
        path = "\(skillMD.path)"
        enabled = false
        """.write(to: root.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)

        try withIsolatedToolHomes(root) {
            let skills = SkillInventoryReader.installedSkills(for: app.path)

            XCTAssertTrue(skills.contains { $0.name == "root-codex" && $0.codexPath != nil })
            let appSkill = try XCTUnwrap(skills.first { $0.name == "app-codex" })
            XCTAssertEqual(appSkill.state, .disabled)
            XCTAssertFalse(appSkill.isEnabled)
            XCTAssertEqual(Set(appSkill.toolLabels), Set(["Codex CLI", "Codex Desktop"]))
        }
    }

    @MainActor
    func testRemoveTargetsOnlySelectedOrigin() throws {
        let root = try makeTempProject()
        try writeSkill(named: "deploy", under: root.appendingPathComponent(".claude/skills", isDirectory: true))
        try writeSkill(named: "deploy", under: root.appendingPathComponent(".agents/skills", isDirectory: true))

        try withIsolatedToolHomes(root) {
            let store = SkillStore()
            let skills = store.installedSkills(for: root.path)
            let codexSkill = try XCTUnwrap(skills.first { $0.name == "deploy" && $0.codexPath != nil })

            store.remove(skill: codexSkill, from: root.path)

            XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(".claude/skills/deploy/SKILL.md").path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".agents/skills/deploy/SKILL.md").path))
        }
    }

    func testContextEstimatorUsesSharedInventoryForCodexSkills() throws {
        let root = try makeTempProject()
        try writeSkill(named: "codex-only", under: root.appendingPathComponent(".agents/skills", isDirectory: true))

        withIsolatedToolHomes(root) {
            let snapshot = ContextEstimator.estimate(for: root.path)

            XCTAssertTrue(snapshot.skills.contains { $0.name == "codex-only" && $0.enabled })
        }
    }

    func testGlobalSkillInstallCountsScanEachProjectOnce() {
        let globalSkills = [
            Skill(name: "deploy", description: "", triggers: [], source: .claudeGlobal, path: "/global/deploy"),
            Skill(name: "lint", description: "", triggers: [], source: .codexGlobal, path: "/global/lint"),
        ]
        let projects = [
            Project(id: UUID(), path: "/projects/one", displayName: "one", addedAt: Date(), lastOpenedAt: Date()),
            Project(id: UUID(), path: "/projects/two", displayName: "two", addedAt: Date(), lastOpenedAt: Date()),
        ]
        var scannedPaths: [String] = []

        let counts = SkillStore.installedProjectCounts(
            globalSkills: globalSkills,
            projects: projects
        ) { path in
            scannedPaths.append(path)
            if path.hasSuffix("/one") {
                return [
                    installedSkill(name: "deploy", path: "\(path)/.claude/skills/deploy"),
                    installedSkill(name: "deploy", path: "\(path)/.agents/skills/deploy"),
                    installedSkill(name: "local-only", path: "\(path)/.claude/skills/local-only"),
                ]
            }
            return [
                installedSkill(name: "deploy", path: "\(path)/.claude/skills/deploy"),
                installedSkill(name: "lint", path: "\(path)/.agents/skills/lint"),
            ]
        }

        XCTAssertEqual(scannedPaths, projects.map(\.path))
        XCTAssertEqual(counts["deploy"], 2)
        XCTAssertEqual(counts["lint"], 1)
        XCTAssertNil(counts["local-only"])
    }

    func testGlobalSkillInstallCountRefreshSkipsProtectedStorageProjects() throws {
        let home = try makeTempProject()
        let globalSkills = [
            Skill(name: "deploy", description: "", triggers: [], source: .claudeGlobal, path: "/global/deploy")
        ]
        let projects = [
            Project(
                id: UUID(),
                path: home.appendingPathComponent("Desktop/projecthub", isDirectory: true).path,
                displayName: "projecthub desktop",
                addedAt: Date(),
                lastOpenedAt: Date()
            ),
            Project(
                id: UUID(),
                path: home.appendingPathComponent("Arel OS/Projects/Active/projecthub", isDirectory: true).path,
                displayName: "projecthub",
                addedAt: Date(),
                lastOpenedAt: Date()
            )
        ]
        var scannedPaths: [String] = []

        let counts = SkillStore.installedProjectCounts(
            globalSkills: globalSkills,
            projects: projects,
            home: home.path
        ) { path in
            scannedPaths.append(path)
            return [
                installedSkill(name: "deploy", path: "\(path)/.claude/skills/deploy")
            ]
        }

        XCTAssertEqual(scannedPaths, [projects[1].path])
        XCTAssertEqual(counts["deploy"], 1)
    }

    func testGlobalSkillGroupsDeduplicateNamesCaseInsensitively() {
        let groups = SkillStore.deduplicatedGlobalSkills([
            Skill(name: "Deploy", description: "Claude copy", triggers: [], source: .claudeGlobal, path: "/claude/deploy"),
            Skill(name: "deploy", description: "Codex copy", triggers: [], source: .codexGlobal, path: "/codex/deploy"),
            Skill(name: "lint", description: "", triggers: [], source: .codexGlobal, path: "/codex/lint"),
        ])

        XCTAssertEqual(groups.map(\.name), ["Deploy", "lint"])
        let deploy = groups.first { $0.id == "deploy" }
        XCTAssertEqual(deploy?.originCount, 2)
        XCTAssertEqual(Set(deploy?.toolLabels ?? []), Set(["Claude Code", "Codex CLI", "Codex Desktop"]))
    }

    func testGlobalInstallCountsNormalizeSkillNamesCaseInsensitively() {
        let globalSkills = [
            Skill(name: "Deploy", description: "", triggers: [], source: .claudeGlobal, path: "/global/deploy")
        ]
        let projects = [
            Project(id: UUID(), path: "/projects/one", displayName: "one", addedAt: Date(), lastOpenedAt: Date())
        ]

        let counts = SkillStore.installedProjectCounts(
            globalSkills: globalSkills,
            projects: projects
        ) { path in
            [installedSkill(name: "deploy", path: "\(path)/.claude/skills/deploy")]
        }

        XCTAssertEqual(counts["deploy"], 1)
        XCTAssertNil(counts["Deploy"])
    }

    func testProjectUsagesShowsInstalledFirstAndSkipsProtectedProjects() throws {
        let home = try makeTempProject()
        let globalSkills = [
            Skill(name: "deploy", description: "", triggers: [], source: .claudeGlobal, path: "/global/deploy")
        ]
        let protected = Project(
            id: UUID(),
            path: home.appendingPathComponent("Desktop/projecthub", isDirectory: true).path,
            displayName: "protected",
            addedAt: Date(),
            lastOpenedAt: Date()
        )
        let installed = Project(
            id: UUID(),
            path: home.appendingPathComponent("Arel OS/Projects/Active/installed", isDirectory: true).path,
            displayName: "installed",
            addedAt: Date(),
            lastOpenedAt: Date()
        )
        let available = Project(
            id: UUID(),
            path: home.appendingPathComponent("Arel OS/Projects/Active/available", isDirectory: true).path,
            displayName: "available",
            addedAt: Date(),
            lastOpenedAt: Date()
        )

        var scannedPaths: [String] = []
        let usages = SkillStore.projectUsages(
            forSkillNamed: "Deploy",
            globalSkills: globalSkills,
            projects: [protected, available, installed],
            home: home.path
        ) { path in
            scannedPaths.append(path)
            guard path == installed.path else { return [] }
            return [installedSkill(name: "deploy", path: "\(path)/.claude/skills/deploy")]
        }

        XCTAssertEqual(scannedPaths, [available.path, installed.path])
        XCTAssertEqual(usages.map { $0.project.displayName }, ["installed", "available"])
        XCTAssertEqual(usages.map(\.state.label), ["Installed", "Available"])
    }

    func testInventoryCarriesDuplicateAndVersionDiagnostics() throws {
        let root = try makeTempProject()
        let app = root.appendingPathComponent("packages/app", isDirectory: true)
        try writeSkill(named: "deploy", version: "1.0.0", under: root.appendingPathComponent(".agents/skills", isDirectory: true))
        try writeSkill(named: "deploy", version: "2.0.0", under: app.appendingPathComponent(".agents/skills", isDirectory: true))

        withIsolatedToolHomes(root) {
            let skills = SkillInventoryReader.installedSkills(for: app.path)
            let deploySkills = skills.filter { $0.name == "deploy" }

            XCTAssertEqual(deploySkills.count, 2)
            XCTAssertTrue(deploySkills.allSatisfy { $0.diagnostics.contains("Duplicate name") })
            XCTAssertTrue(deploySkills.allSatisfy { $0.diagnostics.contains("Version conflict") })
        }
    }

    func testInventoryIncludesReadOnlyCodexPluginSkills() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("isolated-codex-home", isDirectory: true)
        let pluginRoot = try writeInstalledCodexPlugin(
            pluginID: "docs@market",
            codexHome: codexHome
        )
        try writeSkill(named: "lint", under: pluginRoot.appendingPathComponent("skills", isDirectory: true))

        try withIsolatedToolHomes(root) {
            let skills = SkillInventoryReader.installedSkills(for: root.path)
            let pluginSkill = try XCTUnwrap(skills.first { $0.name == "docs:lint" })

            XCTAssertNotNil(pluginSkill.codexPath)
            XCTAssertEqual(Set(pluginSkill.toolLabels), Set(["Codex CLI", "Codex Desktop"]))
            XCTAssertFalse(pluginSkill.canEdit)
            XCTAssertFalse(pluginSkill.canRemove)
            XCTAssertTrue(pluginSkill.readOnlyReason?.contains("plugin") == true)
        }
    }

    private func writeSkill(named name: String, version: String?, under skillsRoot: URL) throws {
        let skill = skillsRoot.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)
        let versionLine = version.map { "version: \($0)\n" } ?? ""
        try """
        ---
        name: \(name)
        description: Test skill.
        \(versionLine)---

        Test.
        """.write(to: skill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    }

    private func writeSkill(named name: String, under skillsRoot: URL) throws {
        try writeSkill(named: name, version: nil, under: skillsRoot)
    }

    private func writeInstalledCodexPlugin(pluginID: String, codexHome: URL) throws -> URL {
        guard let at = pluginID.lastIndex(of: "@") else {
            throw NSError(domain: "SkillInventoryReaderTests", code: 1)
        }
        let name = String(pluginID[..<at])
        let marketplace = String(pluginID[pluginID.index(after: at)...])
        let pluginRoot = codexHome
            .appendingPathComponent("plugins/cache/\(marketplace)/\(name)/1.0.0", isDirectory: true)
        try FileManager.default.createDirectory(
            at: pluginRoot.appendingPathComponent(".codex-plugin", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try """
        [plugins."\(pluginID)"]
        enabled = true
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try """
        {
          "name": "\(name)",
          "version": "1.0.0",
          "skills": "./skills"
        }
        """.write(to: pluginRoot.appendingPathComponent(".codex-plugin/plugin.json"), atomically: true, encoding: .utf8)
        return pluginRoot
    }

    private func installedSkill(name: String, path: String) -> InstalledSkill {
        InstalledSkill(
            originID: path,
            name: name,
            description: "",
            claudePath: path,
            codexPath: nil,
            path: path,
            skillMDPath: (path as NSString).appendingPathComponent("SKILL.md"),
            sourceLabel: "Test",
            scopeLabel: "Project",
            toolLabels: ["Claude Code"],
            state: .active,
            version: nil,
            diagnostics: [],
            canEdit: true,
            canRemove: true,
            readOnlyReason: nil
        )
    }

    private func withIsolatedToolHomes(_ root: URL, run: () throws -> Void) rethrows {
        let claudeHome = root.appendingPathComponent("isolated-claude-home", isDirectory: true)
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

    private func makeTempProject() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubSkillInventoryReaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }
}
