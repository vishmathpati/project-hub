import XCTest
@testable import ProjectHub

final class CompatibilitySkillSupportTests: XCTestCase {
    func testScanReportsClaudeSkillMetadata() throws {
        let root = try makeTempProject()
        let skill = root
            .appendingPathComponent(".claude/skills/deploy-helper", isDirectory: true)
        try FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)
        try """
        ---
        name: deploy-helper
        description: Deploy the application.
        when_to_use: Use when preparing release deploys.
        allowed-tools: Read Bash(git status)
        disable-model-invocation: true
        user-invocable: false
        argument-hint: "[environment]"
        arguments:
          - environment
          - release
        model: sonnet
        effort: high
        context: fork
        agent: release
        paths: "scripts/**, deploy/**"
        shell: bash
        ---

        Deploy carefully.
        """.write(to: skill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let report = CompatibilityScanner.scan(projectRoot: root.path)
        let observed = try XCTUnwrap(report.skills.first { $0.toolID == .claudeCode && $0.name == "deploy-helper" })

        XCTAssertEqual(observed.claudeWhenToUse, "Use when preparing release deploys.")
        XCTAssertEqual(observed.claudeAllowedTools, ["Read", "Bash(git status)"])
        XCTAssertEqual(observed.claudeDisableModelInvocation, true)
        XCTAssertEqual(observed.claudeUserInvocable, false)
        XCTAssertEqual(observed.claudeArgumentHint, "[environment]")
        XCTAssertEqual(observed.claudeArguments, ["environment", "release"])
        XCTAssertEqual(observed.claudeModel, "sonnet")
        XCTAssertEqual(observed.claudeEffort, "high")
        XCTAssertEqual(observed.claudeContext, "fork")
        XCTAssertEqual(observed.claudeAgent, "release")
        XCTAssertEqual(observed.claudePaths, ["scripts/**", "deploy/**"])
        XCTAssertEqual(observed.claudeShell, "bash")
    }

    func testScanReportsClaudeSkillOverridesAndPolicies() throws {
        let root = try makeTempProject()
        let skillsRoot = root.appendingPathComponent(".claude/skills", isDirectory: true)
        try writeSkill(named: "deploy", under: skillsRoot)
        try writeSkill(named: "review", under: skillsRoot)
        let settingsDirectory = root.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        try ".claude/settings.local.json\n".write(to: root.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8)
        try """
        {
          "disableSkillShellExecution": true,
          "permissions": {
            "allow": ["Skill"],
            "deny": ["Skill(deploy *)"]
          },
          "skillOverrides": {
            "deploy": "off",
            "review": "name-only"
          }
        }
        """.write(to: settingsDirectory.appendingPathComponent("settings.local.json"), atomically: true, encoding: .utf8)

        let report = CompatibilityScanner.scan(projectRoot: root.path)
        let deploy = try XCTUnwrap(report.skills.first { $0.toolID == .claudeCode && $0.name == "deploy" })
        let review = try XCTUnwrap(report.skills.first { $0.toolID == .claudeCode && $0.name == "review" })

        XCTAssertEqual(deploy.claudeOverrideState, "off")
        XCTAssertTrue(deploy.claudeOverrideSource?.contains("local project settings") == true)
        XCTAssertTrue(deploy.claudeShellExecutionDisabled)
        XCTAssertEqual(Set(deploy.claudeSkillPermissionRules), Set(["allow: Skill", "deny: Skill(deploy *)"]))
        XCTAssertEqual(review.claudeOverrideState, "name-only")
        XCTAssertTrue(review.claudeSkillPermissionRules.contains("allow: Skill"))

        let disabledIssues = report.issues.filter {
            $0.code == .skillDisabled
                && $0.title == "Claude skill disabled"
                && $0.subjectPath?.hasPrefix(root.path) == true
        }
        let visibilityIssues = report.issues.filter {
            $0.code == .skillVisibilityLimited
                && $0.subjectPath?.hasPrefix(root.path) == true
        }
        let shellPolicyIssues = report.issues.filter { $0.title == "Claude skill shell execution disabled" }
        XCTAssertEqual(disabledIssues.count, 1)
        XCTAssertEqual(visibilityIssues.count, 1)
        XCTAssertEqual(shellPolicyIssues.count, 1)
    }

    func testInvalidClaudeSkillOverrideStateIsReported() throws {
        let root = try makeTempProject()
        let settingsDirectory = root.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        try """
        {
          "skillOverrides": {
            "deploy": "sometimes"
          }
        }
        """.write(to: settingsDirectory.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)

        let report = CompatibilityScanner.scan(projectRoot: root.path)

        XCTAssertTrue(report.issues.contains {
            $0.code == .configUnsupportedShape
                && $0.title == "Invalid Claude skill override state"
                && $0.subjectPath == "skillOverrides.deploy"
        })
    }

    func testClaudeSettingsAdditionalDirectoriesDoNotAddSkillRoots() throws {
        let root = try makeTempProject()
        let settingsDirectory = root.appendingPathComponent(".claude", isDirectory: true)
        let shared = root.appendingPathComponent("shared-work", isDirectory: true)
        try FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        try writeSkill(named: "shared-skill", under: shared.appendingPathComponent(".claude/skills", isDirectory: true))
        try """
        {
          "additionalDirectories": ["shared-work"]
        }
        """.write(to: settingsDirectory.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)

        let report = CompatibilityScanner.scan(projectRoot: root.path)
        let additionalSkillRoot = shared.appendingPathComponent(".claude/skills").path

        XCTAssertFalse(report.matrix.contains {
            $0.id.hasPrefix("claude-code-additional-directory-skills|")
                && $0.path == additionalSkillRoot
        })
        XCTAssertFalse(report.skills.contains {
            $0.toolID == .claudeCode
                && $0.name == "shared-skill"
                && $0.path.hasPrefix(additionalSkillRoot)
        })
    }

    func testManagedStrictPluginOnlyCustomizationBlocksFilesystemSkills() throws {
        let root = try makeTempProject()
        let managed = root.appendingPathComponent("managed", isDirectory: true)
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        let pluginRoot = claudeHome
            .appendingPathComponent("plugins/marketplaces/team-tools/project-tools", isDirectory: true)
        try FileManager.default.createDirectory(at: managed, withIntermediateDirectories: true)
        try writeSkill(named: "project-skill", under: root.appendingPathComponent(".claude/skills", isDirectory: true))
        try writeSkill(named: "plugin-skill", under: pluginRoot.appendingPathComponent("skills", isDirectory: true))
        try writeInstalledClaudePlugin(
            pluginID: "project-tools@team-tools",
            scope: "user",
            installPath: pluginRoot.path,
            claudeHome: claudeHome
        )
        try """
        {
          "strictPluginOnlyCustomization": ["skills"]
        }
        """.write(to: managed.appendingPathComponent("managed-settings.json"), atomically: true, encoding: .utf8)

        withClaudeHome(claudeHome.path) {
            withClaudeManagedDirectory(managed.path) {
                let report = CompatibilityScanner.scan(projectRoot: root.path)
                let canonicalPluginRoot = canonicalFilePath(pluginRoot.path)
                XCTAssertTrue(report.issues.contains {
                    $0.title == "Claude skills restricted to plugins or managed sources"
                        && $0.path == managed.appendingPathComponent("managed-settings.json").path
                })
                XCTAssertTrue(report.issues.contains {
                    $0.code == .skillDisabled
                        && $0.title == "Claude filesystem skill blocked by managed policy"
                        && $0.subjectPath?.hasPrefix(root.path) == true
                })
                XCTAssertTrue(report.skills.contains {
                    $0.name == "project-tools:plugin-skill"
                        && canonicalFilePath($0.path).hasPrefix(canonicalPluginRoot)
                })
                XCTAssertFalse(report.issues.contains {
                    $0.title == "Claude filesystem skill blocked by managed policy"
                        && $0.subjectPath.map { canonicalFilePath($0).hasPrefix(canonicalPluginRoot) } == true
                })
            }
        }
    }

    func testClaudePluginSkillsAreDiscoveredFromInstalledPluginInventory() throws {
        let root = try makeTempProject()
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        let pluginRoot = claudeHome
            .appendingPathComponent("plugins/marketplaces/team-tools/project-tools", isDirectory: true)
        try writeSkill(named: "lint", under: pluginRoot.appendingPathComponent("skills", isDirectory: true))
        try writeSkill(named: "review", under: pluginRoot.appendingPathComponent("extra-skills", isDirectory: true))
        try FileManager.default.createDirectory(
            at: pluginRoot.appendingPathComponent(".claude-plugin", isDirectory: true),
            withIntermediateDirectories: true
        )
        try """
        {
          "name": "project-tools",
          "version": "1.0.0",
          "skills": ["./extra-skills"]
        }
        """.write(to: pluginRoot.appendingPathComponent(".claude-plugin/plugin.json"), atomically: true, encoding: .utf8)
        try writeInstalledClaudePlugin(
            pluginID: "project-tools@team-tools",
            scope: "user",
            installPath: pluginRoot.path,
            claudeHome: claudeHome
        )
        try """
        {
          "enabledPlugins": {
            "project-tools@team-tools": true
          }
        }
        """.write(to: claudeHome.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)

        withClaudeHome(claudeHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let skillsRoot = canonicalFilePath(pluginRoot.appendingPathComponent("skills").path)
            let extraSkillsRoot = canonicalFilePath(pluginRoot.appendingPathComponent("extra-skills").path)

            XCTAssertTrue(report.matrix.contains {
                $0.id.hasPrefix("claude-code-plugin-skills|project-tools@team-tools|enabled|")
                    && $0.path == skillsRoot
                    && $0.canWriteSafely == false
            })
            XCTAssertTrue(report.matrix.contains {
                $0.id.hasPrefix("claude-code-plugin-skills|project-tools@team-tools|enabled|")
                    && $0.path == extraSkillsRoot
            })
            XCTAssertTrue(report.skills.contains {
                $0.toolID == .claudeCode
                    && $0.name == "project-tools:lint"
                    && canonicalFilePath($0.path).hasPrefix(skillsRoot)
            })
            XCTAssertTrue(report.skills.contains {
                $0.toolID == .claudeCode
                    && $0.name == "project-tools:review"
                    && canonicalFilePath($0.path).hasPrefix(extraSkillsRoot)
            })
        }
    }

    func testDisabledClaudePluginSkillsAreReported() throws {
        let root = try makeTempProject()
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        let pluginRoot = claudeHome
            .appendingPathComponent("plugins/marketplaces/team-tools/project-tools", isDirectory: true)
        try writeSkill(named: "lint", under: pluginRoot.appendingPathComponent("skills", isDirectory: true))
        try writeInstalledClaudePlugin(
            pluginID: "project-tools@team-tools",
            scope: "user",
            installPath: pluginRoot.path,
            claudeHome: claudeHome
        )
        try """
        {
          "enabledPlugins": {
            "project-tools@team-tools": false
          }
        }
        """.write(to: claudeHome.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)

        withClaudeHome(claudeHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let canonicalPluginRoot = canonicalFilePath(pluginRoot.path)

            XCTAssertTrue(report.skills.contains { $0.name == "project-tools:lint" })
            XCTAssertTrue(report.issues.contains {
                $0.code == .skillDisabled
                    && $0.title == "Claude plugin skill disabled"
                    && $0.subjectPath.map { canonicalFilePath($0).hasPrefix(canonicalPluginRoot) } == true
            })
        }
    }

    func testCodexPluginSkillsAreDiscoveredFromInstalledPluginInventory() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let pluginRoot = try writeInstalledCodexPlugin(
            pluginID: "docs@market",
            enabled: true,
            codexHome: codexHome
        )
        try writeSkill(named: "lint", under: pluginRoot.appendingPathComponent("skills", isDirectory: true))

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let skillsRoot = canonicalFilePath(pluginRoot.appendingPathComponent("skills").path)

            XCTAssertTrue(report.matrix.contains {
                $0.id.hasPrefix("codex-plugin-skills|docs@market|enabled|codexCLI|")
                    && $0.kind == .skills
                    && $0.toolID == .codexCLI
                    && $0.path == skillsRoot
                    && $0.canWriteSafely == false
            })
            XCTAssertTrue(report.matrix.contains {
                $0.id.hasPrefix("codex-plugin-skills|docs@market|enabled|codexDesktop|")
                    && $0.kind == .skills
                    && $0.toolID == .codexDesktop
                    && $0.path == skillsRoot
            })
            XCTAssertTrue(report.skills.contains {
                $0.name == "docs:lint"
                    && canonicalFilePath($0.path).hasPrefix(skillsRoot)
                    && Set($0.availableIn) == Set([.codexCLI, .codexDesktop])
            })
        }
    }

    func testDisabledCodexPluginSkillsAreReported() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let pluginRoot = try writeInstalledCodexPlugin(
            pluginID: "docs@market",
            enabled: false,
            codexHome: codexHome
        )
        try writeSkill(named: "lint", under: pluginRoot.appendingPathComponent("skills", isDirectory: true))

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let canonicalPluginRoot = canonicalFilePath(pluginRoot.path)

            XCTAssertTrue(report.skills.contains {
                $0.name == "docs:lint"
                    && $0.enabledOverride == false
            })
            XCTAssertTrue(report.issues.contains {
                $0.code == .skillDisabled
                    && $0.title == "Codex plugin skill disabled"
                    && $0.subjectPath.map { canonicalFilePath($0).hasPrefix(canonicalPluginRoot) } == true
            })
        }
    }

    func testScanReportsOpenAIMetadataAndMissingMCPDependency() throws {
        let root = try makeTempProject()
        let skill = root
            .appendingPathComponent(".agents/skills/docs-skill", isDirectory: true)
        try FileManager.default.createDirectory(
            at: skill.appendingPathComponent("agents", isDirectory: true),
            withIntermediateDirectories: true
        )
        try """
        ---
        name: docs-skill
        description: Use when searching documentation.
        version: 1.0.0
        ---

        Search docs.
        """.write(to: skill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try """
        interface:
          display_name: "Docs Skill"
          short_description: "Searches docs with the docs MCP."
          icon_small: "./assets/small-logo.svg"
          icon_large: "./assets/large-logo.png"
          brand_color: "#3B82F6"
          default_prompt: "Search the docs for this API."
        policy:
          allow_implicit_invocation: false
        dependencies:
          tools:
            - type: "mcp"
              value: "openaiDeveloperDocs"
        """.write(to: skill.appendingPathComponent("agents/openai.yaml"), atomically: true, encoding: .utf8)

        let report = CompatibilityScanner.scan(projectRoot: root.path)
        let docsSkills = report.skills.filter { $0.name == "docs-skill" }
        let dependencyIssues = report.issues.filter { $0.code == .skillMissingDependency }

        XCTAssertFalse(docsSkills.isEmpty)
        XCTAssertTrue(docsSkills.allSatisfy { $0.displayName == "Docs Skill" })
        XCTAssertTrue(docsSkills.allSatisfy { $0.shortDescription == "Searches docs with the docs MCP." })
        XCTAssertTrue(docsSkills.allSatisfy { $0.iconSmall == "./assets/small-logo.svg" })
        XCTAssertTrue(docsSkills.allSatisfy { $0.iconLarge == "./assets/large-logo.png" })
        XCTAssertTrue(docsSkills.allSatisfy { $0.brandColor == "#3B82F6" })
        XCTAssertTrue(docsSkills.allSatisfy { $0.defaultPrompt == "Search the docs for this API." })
        XCTAssertTrue(docsSkills.allSatisfy { $0.allowImplicitInvocation == false })
        XCTAssertTrue(docsSkills.allSatisfy { $0.mcpDependencies == ["openaiDeveloperDocs"] })
        XCTAssertFalse(dependencyIssues.isEmpty)
        XCTAssertTrue(dependencyIssues.allSatisfy { $0.subjectPath?.hasSuffix("agents/openai.yaml") == true })
    }

    func testQuotedCodexSkillConfigOverrideDisablesSkillAndCanPreviewEnable() throws {
        let root = try makeTempProject()
        let skillsRoot = root.appendingPathComponent(".agents/skills", isDirectory: true)
        let configPath = root.appendingPathComponent(".codex/config.toml")
        try FileManager.default.createDirectory(at: configPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writeSkill(named: "docs-skill", under: skillsRoot)
        let skillMD = skillsRoot.appendingPathComponent("docs-skill/SKILL.md")
        try """
        [["skills"."config"]]
        path = "\(skillMD.path)"
        enabled = false
        """.write(to: configPath, atomically: true, encoding: .utf8)

        let report = CompatibilityScanner.scan(projectRoot: root.path)
        let docsSkill = try XCTUnwrap(report.skills.first {
            $0.toolID == .codexCLI
                && $0.name == "docs-skill"
                && canonicalFilePath($0.path) == canonicalFilePath(skillMD.deletingLastPathComponent().path)
        })

        XCTAssertEqual(docsSkill.enabledOverride, false)
        XCTAssertTrue(report.issues.contains {
            $0.code == .skillDisabled
                && $0.title == "Skill disabled"
                && $0.subjectPath.map { canonicalFilePath($0) == canonicalFilePath(skillMD.path) } == true
        })

        let preview = try XCTUnwrap(ConfigWriter.previewSetCodexSkillOverrideEnabled(
            configPath: configPath.path,
            skillMDPath: skillMD.path,
            enabled: true
        ))
        XCTAssertTrue(preview.after.contains(#"[["skills"."config"]]"#))
        XCTAssertTrue(preview.after.contains("enabled = true"))
        XCTAssertFalse(preview.after.contains("enabled = false"))
    }

    func testRuntimeProfileFileCodexSkillOverrideDisablesCLIOnly() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let skillsRoot = root.appendingPathComponent(".agents/skills", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try writeSkill(named: "docs-skill", under: skillsRoot)
        let skillMD = skillsRoot.appendingPathComponent("docs-skill/SKILL.md")
        let profilePath = codexHome.appendingPathComponent("work.config.toml")
        try """
        [["skills"."config"]]
        path = "\(skillMD.path)"
        enabled = false
        """.write(to: profilePath, atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(
                projectRoot: root.path,
                codexProfileSelection: try XCTUnwrap(CodexProfileSelection.cliRuntimeOverride("work"))
            )
            let cliSkill = try XCTUnwrap(report.skills.first {
                $0.toolID == .codexCLI
                    && $0.name == "docs-skill"
                    && canonicalFilePath($0.path) == canonicalFilePath(skillMD.deletingLastPathComponent().path)
            })
            let desktopSkill = try XCTUnwrap(report.skills.first {
                $0.toolID == .codexDesktop
                    && $0.name == "docs-skill"
                    && canonicalFilePath($0.path) == canonicalFilePath(skillMD.deletingLastPathComponent().path)
            })

            XCTAssertEqual(cliSkill.enabledOverride, false)
            XCTAssertNil(desktopSkill.enabledOverride)
            XCTAssertTrue(report.issues.contains {
                $0.code == .skillDisabled
                    && $0.toolID == .codexCLI
                    && $0.title == "Skill disabled"
                    && $0.path.map(canonicalFilePath) == canonicalFilePath(profilePath.path)
                    && $0.subjectPath.map { canonicalFilePath($0) == canonicalFilePath(skillMD.path) } == true
            })
            XCTAssertFalse(report.issues.contains {
                $0.code == .skillDisabled
                    && $0.toolID == .codexDesktop
                    && $0.subjectPath.map { canonicalFilePath($0) == canonicalFilePath(skillMD.path) } == true
            })
        }
    }

    func testOpenAIMCPDependencyMatchesConfiguredServerByURLWhenNameDiffers() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try """
        [mcp_servers.docs]
        type = "streamable_http"
        url = "https://developers.openai.com/mcp/"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try writeOpenAIDependencySkill(
            named: "docs-skill",
            under: root.appendingPathComponent(".agents/skills", isDirectory: true),
            dependencyName: "openaiDeveloperDocs",
            transport: "streamable_http",
            url: "https://developers.openai.com/mcp"
        )

        withEnv("CODEX_HOME", codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let dependencyIssues = report.issues.filter {
                $0.code == .skillMissingDependency
                    && $0.subjectPath?.hasSuffix("docs-skill/agents/openai.yaml") == true
            }

            XCTAssertTrue(dependencyIssues.isEmpty, dependencyIssues.map(\.detail).joined(separator: "\n"))
            XCTAssertTrue(report.skills.contains {
                $0.name == "docs-skill" && $0.mcpDependencies == ["openaiDeveloperDocs"]
            })
        }
    }

    func testOpenAIMCPDependencyWithURLDoesNotMatchSameNameWrongEndpoint() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try """
        [mcp_servers.openaiDeveloperDocs]
        type = "http"
        url = "https://wrong.example.com/mcp"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try writeOpenAIDependencySkill(
            named: "docs-skill",
            under: root.appendingPathComponent(".agents/skills", isDirectory: true),
            dependencyName: "openaiDeveloperDocs",
            transport: "streamable-http",
            url: "https://developers.openai.com/mcp"
        )

        withEnv("CODEX_HOME", codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let dependencyIssues = report.issues.filter {
                $0.code == .skillMissingDependency
                    && $0.subjectPath?.hasSuffix("docs-skill/agents/openai.yaml") == true
            }

            XCTAssertFalse(dependencyIssues.isEmpty)
            XCTAssertTrue(dependencyIssues.contains {
                $0.detail.contains("URL https://developers.openai.com/mcp")
                    && $0.fixHint?.contains("name, transport, or URL") == true
            })
        }
    }

    func testOpenAIMCPDependencyDoesNotMatchDisabledServer() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try """
        [mcp_servers.docs]
        enabled = false
        type = "http"
        url = "https://developers.openai.com/mcp"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try writeOpenAIDependencySkill(
            named: "docs-skill",
            under: root.appendingPathComponent(".agents/skills", isDirectory: true),
            dependencyName: "openaiDeveloperDocs",
            transport: "http",
            url: "https://developers.openai.com/mcp"
        )

        withEnv("CODEX_HOME", codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let dependencyIssues = report.issues.filter {
                $0.code == .skillMissingDependency
                    && $0.subjectPath?.hasSuffix("docs-skill/agents/openai.yaml") == true
            }

            XCTAssertFalse(dependencyIssues.isEmpty)
        }
    }

    func testScanReportsExplicitSkillSupportForAllPrimaryTools() throws {
        let root = try makeTempProject()
        let report = CompatibilityScanner.scan(projectRoot: root.path)
        let supportByTool = Dictionary(uniqueKeysWithValues: report.skillSupport.map { ($0.toolID, $0) })

        XCTAssertEqual(supportByTool[.claudeCode]?.state, .supported)
        XCTAssertEqual(supportByTool[.claudeDesktop]?.state, .appManaged)
        XCTAssertEqual(supportByTool[.codexCLI]?.state, .supported)
        XCTAssertEqual(supportByTool[.codexDesktop]?.state, .shared)
        XCTAssertEqual(supportByTool[.claudeCode]?.requiresRestartAfterWrite, false)

        XCTAssertTrue(supportByTool[.claudeCode]?.roots.contains { $0.hasSuffix(".claude/skills") } == true)
        XCTAssertTrue(supportByTool[.codexCLI]?.roots.contains { $0.hasSuffix(".agents/skills") } == true)
        XCTAssertTrue(supportByTool[.codexCLI]?.roots.contains("/etc/codex/skills") == true)
        XCTAssertTrue(supportByTool[.codexDesktop]?.roots.contains { $0.hasSuffix(".agents/skills") } == true)
        XCTAssertTrue(supportByTool[.codexDesktop]?.roots.contains("/etc/codex/skills") == true)
        XCTAssertEqual(supportByTool[.claudeDesktop]?.roots, [])

        let claudeDesktopSkillSurface = try XCTUnwrap(report.matrix.first {
            $0.id == "claude-desktop-account-skills"
        })
        XCTAssertEqual(claudeDesktopSkillSurface.toolID, .claudeDesktop)
        XCTAssertEqual(claudeDesktopSkillSurface.kind, .skills)
        XCTAssertEqual(claudeDesktopSkillSurface.format, .accountRuntime)
        XCTAssertFalse(claudeDesktopSkillSurface.fileControlled)

        let claudeCodePersonalSkillSurface = try XCTUnwrap(report.matrix.first {
            $0.id == "claude-code-global-skills"
        })
        XCTAssertFalse(claudeCodePersonalSkillSurface.requiresRestartAfterWrite)
    }

    func testClaudeCodeSkillsScanWorkingParentAndNestedDirectories() throws {
        let root = try makeTempProject()
        let app = root.appendingPathComponent("packages/app", isDirectory: true)
        let feature = app.appendingPathComponent("features/widget", isDirectory: true)
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: feature, withIntermediateDirectories: true)
        try writeSkill(named: "root-skill", under: root.appendingPathComponent(".claude/skills", isDirectory: true))
        try writeSkill(named: "app-skill", under: app.appendingPathComponent(".claude/skills", isDirectory: true))
        try writeSkill(named: "widget-skill", under: feature.appendingPathComponent(".claude/skills", isDirectory: true))

        let report = CompatibilityScanner.scan(projectRoot: app.path)
        let claudeSkillNames = Set(report.skills
            .filter { $0.toolID == .claudeCode }
            .map(\.name))

        XCTAssertTrue(claudeSkillNames.contains("root-skill"))
        XCTAssertTrue(claudeSkillNames.contains("app-skill"))
        XCTAssertTrue(claudeSkillNames.contains("widget-skill"))
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

    private func writeOpenAIDependencySkill(
        named name: String,
        under skillsRoot: URL,
        dependencyName: String,
        transport: String,
        url: String
    ) throws {
        let skill = skillsRoot.appendingPathComponent(name, isDirectory: true)
        let agents = skill.appendingPathComponent("agents", isDirectory: true)
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
        try """
        ---
        name: \(name)
        description: Test skill.
        ---

        Test.
        """.write(to: skill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try """
        dependencies:
          tools:
            - type: "mcp"
              value: "\(dependencyName)"
              transport: "\(transport)"
              url: "\(url)"
        """.write(to: agents.appendingPathComponent("openai.yaml"), atomically: true, encoding: .utf8)
    }

    private func writeInstalledClaudePlugin(
        pluginID: String,
        scope: String,
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
                "scope": "\(scope)",
                "installPath": "\(installPath)",
                "version": "1.0.0"
              }
            ]
          }
        }
        """.write(to: pluginsDirectory.appendingPathComponent("installed_plugins.json"), atomically: true, encoding: .utf8)
    }

    private func writeInstalledCodexPlugin(
        pluginID: String,
        enabled: Bool,
        codexHome: URL
    ) throws -> URL {
        guard let at = pluginID.lastIndex(of: "@") else {
            throw NSError(domain: "CompatibilitySkillSupportTests", code: 1)
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
        enabled = \(enabled ? "true" : "false")
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

    private func canonicalFilePath(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    private func withClaudeManagedDirectory(_ path: String, run: () throws -> Void) rethrows {
        try withEnv("PROJECTHUB_CLAUDE_CODE_MANAGED_DIR", path, run: run)
    }

    private func withClaudeHome(_ path: String, run: () throws -> Void) rethrows {
        try withEnv("PROJECTHUB_CLAUDE_HOME", path, run: run)
    }

    private func withCodexHome(_ path: String, run: () throws -> Void) rethrows {
        try withEnv("CODEX_HOME", path, run: run)
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
            .appendingPathComponent("ProjectHubCompatibilitySkillSupportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }
}
