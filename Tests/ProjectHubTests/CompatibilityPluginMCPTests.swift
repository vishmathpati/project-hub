import XCTest
@testable import ProjectHub

final class CompatibilityPluginMCPTests: XCTestCase {
    func testCodexConfiguredProfileNamesIncludesDefaultAndNestedProfileSections() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try """
        profile = "personal"

        [profiles.work.plugins."docs@team-tools".mcp_servers.search]
        enabled = false

        [profiles."deep review"]
        model_reasoning_effort = "high"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try """
        model = "gpt-5.3-codex"
        """.write(to: codexHome.appendingPathComponent("profile-name.config.toml"), atomically: true, encoding: .utf8)
        try """
        model = "gpt-5.3-codex"
        """.write(to: codexHome.appendingPathComponent("deep.review.config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            XCTAssertEqual(
                CompatibilityScanner.codexConfiguredProfileNames(),
                ["deep review", "deep.review", "personal", "profile-name", "work"]
            )
        }
    }

    func testCodexPluginMCPServersAreDiscoveredForCLIAndDesktop() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let pluginRoot = try writeCodexPlugin(
            pluginID: "project-tools@team-tools",
            codexHome: codexHome,
            enabled: true,
            mcpJSON: """
            {
              "mcpServers": {
                "plugin-db": {
                  "command": "./bin/server",
                  "args": ["mcp"],
                  "cwd": "."
                }
              }
            }
            """
        )
        let server = pluginRoot.appendingPathComponent("bin/server")
        try FileManager.default.createDirectory(at: server.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\nexit 0\n".write(to: server, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: server.path)

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let mcpPath = canonicalFilePath(pluginRoot.appendingPathComponent(".mcp.json").path)
            let cliServer = try XCTUnwrap(report.servers.first {
                $0.toolID == .codexCLI
                    && $0.name == "plugin-db"
                    && $0.path == mcpPath
            })
            let desktopServer = try XCTUnwrap(report.servers.first {
                $0.toolID == .codexDesktop
                    && $0.name == "plugin-db"
                    && $0.path == mcpPath
            })
            let healthEntry = try XCTUnwrap(CompatibilityScanner.healthEntry(for: cliServer, matrix: report.matrix))

            XCTAssertTrue(report.matrix.contains {
                $0.id.hasPrefix("codex-plugin-mcp|project-tools@team-tools|enabled|codexCLI|")
                    && $0.path == mcpPath
                    && $0.canWriteSafely == false
                    && $0.requiresRestartAfterWrite == true
            })
            XCTAssertTrue(report.matrix.contains {
                $0.id.hasPrefix("codex-plugin-mcp|project-tools@team-tools|enabled|codexDesktop|")
                    && $0.path == mcpPath
            })
            XCTAssertFalse(cliServer.disabled)
            XCTAssertFalse(desktopServer.disabled)
            XCTAssertEqual(healthEntry.command, canonicalFilePath(server.path))
            XCTAssertEqual(healthEntry.args, ["mcp"])
            XCTAssertEqual(healthEntry.env, [:])
        }
    }

    func testCodexPluginMCPServersSupportOfficialWrappedAndDirectMaps() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        _ = try writeCodexPlugin(
            pluginID: "wrapped@team-tools",
            codexHome: codexHome,
            enabled: true,
            mcpJSON: """
            {
              "mcp_servers": {
                "wrapped-http": {
                  "type": "http",
                  "url": "https://example.invalid/mcp"
                }
              }
            }
            """
        )
        _ = try writeCodexPlugin(
            pluginID: "direct@team-tools",
            codexHome: codexHome,
            enabled: true,
            mcpJSON: """
            {
              "direct-http": {
                "type": "http",
                "url": "https://direct.example.invalid/mcp"
              }
            }
            """
        )

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            XCTAssertTrue(report.servers.contains {
                $0.toolID == .codexCLI
                    && $0.name == "wrapped-http"
                    && $0.transport == "http"
            })
            XCTAssertTrue(report.servers.contains {
                $0.toolID == .codexDesktop
                    && $0.name == "direct-http"
                    && $0.transport == "http"
            })
        }
    }

    func testDisabledCodexPluginAndBundledMCPServersAreReportedDisabled() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let disabledPluginRoot = try writeCodexPlugin(
            pluginID: "disabled-plugin@team-tools",
            codexHome: codexHome,
            enabled: false,
            mcpJSON: """
            {
              "mcpServers": {
                "plugin-off": {
                  "command": "node",
                  "args": ["server.js"]
                }
              }
            }
            """
        )
        let serverPolicyRoot = try writeCodexPlugin(
            pluginID: "server-policy@team-tools",
            codexHome: codexHome,
            enabled: true,
            extraConfig: """

            [plugins."server-policy@team-tools".mcp_servers.plugin-db]
            enabled = false
            """,
            mcpJSON: """
            {
              "mcpServers": {
                "plugin-db": {
                  "command": "node",
                  "args": ["server.js"]
                }
              }
            }
            """
        )

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let disabledPluginPath = canonicalFilePath(disabledPluginRoot.appendingPathComponent(".mcp.json").path)
            let serverPolicyPath = canonicalFilePath(serverPolicyRoot.appendingPathComponent(".mcp.json").path)
            let pluginOff = try XCTUnwrap(report.servers.first {
                $0.toolID == .codexCLI && $0.name == "plugin-off" && $0.path == disabledPluginPath
            })
            let pluginDB = try XCTUnwrap(report.servers.first {
                $0.toolID == .codexDesktop && $0.name == "plugin-db" && $0.path == serverPolicyPath
            })

            XCTAssertTrue(pluginOff.disabled)
            XCTAssertEqual(pluginOff.health, .disabled)
            XCTAssertTrue(pluginDB.disabled)
            XCTAssertEqual(pluginDB.health, .disabled)
            let configPath = canonicalFilePath(codexHome.appendingPathComponent("config.toml").path)
            let policyIssue = try XCTUnwrap(report.issues.first {
                $0.code == .serverDisabled
                    && $0.title == "Server disabled"
                    && $0.path == serverPolicyPath
            })
            XCTAssertEqual(policyIssue.subjectPath, configPath)
            XCTAssertTrue(policyIssue.detail.contains(configPath.replacingOccurrences(of: NSHomeDirectory(), with: "~")))
            XCTAssertTrue(report.issues.contains {
                $0.code == .serverDisabled
                    && $0.title == "Server disabled"
                    && $0.path == disabledPluginPath
                    && $0.subjectPath == nil
            })
        }
    }

    func testTrustedProjectCodexPluginMCPPolicyOverridesGlobalPolicy() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let pluginRoot = try writeCodexPlugin(
            pluginID: "precedence@team-tools",
            codexHome: codexHome,
            enabled: true,
            extraConfig: """

            [plugins."precedence@team-tools".mcp_servers.plugin-db]
            enabled = false
            """,
            mcpJSON: """
            {
              "mcpServers": {
                "plugin-db": {
                  "command": "node",
                  "args": ["server.js"]
                }
              }
            }
            """
        )
        let globalConfig = codexHome.appendingPathComponent("config.toml")
        let trustedProjectConfig = root.appendingPathComponent(".codex/config.toml")
        try FileManager.default.createDirectory(at: trustedProjectConfig.deletingLastPathComponent(), withIntermediateDirectories: true)
        let existing = try String(contentsOf: globalConfig, encoding: .utf8)
        try """
        \(existing)

        [projects."\(root.path)"]
        trust_level = "trusted"
        """.write(to: globalConfig, atomically: true, encoding: .utf8)
        try """
        [plugins."precedence@team-tools".mcp_servers.plugin-db]
        enabled = true
        """.write(to: trustedProjectConfig, atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let mcpPath = canonicalFilePath(pluginRoot.appendingPathComponent(".mcp.json").path)
            XCTAssertTrue(report.servers.contains {
                $0.toolID == .codexCLI
                    && $0.name == "plugin-db"
                    && $0.path == mcpPath
                    && !$0.disabled
            })
            XCTAssertFalse(report.issues.contains {
                $0.code == .serverDisabled
                    && $0.path == mcpPath
                    && $0.subjectPath == canonicalFilePath(trustedProjectConfig.path)
            })
        }

        try """
        [plugins."precedence@team-tools".mcp_servers.plugin-db]
        enabled = false
        """.write(to: trustedProjectConfig, atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let mcpPath = canonicalFilePath(pluginRoot.appendingPathComponent(".mcp.json").path)
            let issue = try XCTUnwrap(report.issues.first {
                $0.code == .serverDisabled
                    && $0.path == mcpPath
                    && $0.subjectPath == canonicalFilePath(trustedProjectConfig.path)
            })
            XCTAssertEqual(issue.toolID, .codexCLI)
        }
    }

    func testCodexPluginMCPPolicyConflictNamesShadowedLayer() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let pluginRoot = try writeCodexPlugin(
            pluginID: "shadowed-policy@team-tools",
            codexHome: codexHome,
            enabled: true,
            extraConfig: """

            [plugins."shadowed-policy@team-tools".mcp_servers.plugin-db]
            enabled = false
            """,
            mcpJSON: """
            {
              "mcpServers": {
                "plugin-db": {
                  "command": "node",
                  "args": ["server.js"]
                }
              }
            }
            """
        )
        let globalConfig = codexHome.appendingPathComponent("config.toml")
        let trustedProjectConfig = root.appendingPathComponent(".codex/config.toml")
        try FileManager.default.createDirectory(at: trustedProjectConfig.deletingLastPathComponent(), withIntermediateDirectories: true)
        let existing = try String(contentsOf: globalConfig, encoding: .utf8)
        try """
        \(existing)

        [projects."\(root.path)"]
        trust_level = "trusted"
        """.write(to: globalConfig, atomically: true, encoding: .utf8)
        try """
        [plugins."shadowed-policy@team-tools".mcp_servers.plugin-db]
        enabled = true
        """.write(to: trustedProjectConfig, atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let mcpPath = canonicalFilePath(pluginRoot.appendingPathComponent(".mcp.json").path)
            let globalPath = canonicalFilePath(globalConfig.path)
            let projectPath = canonicalFilePath(trustedProjectConfig.path)
            let server = try XCTUnwrap(report.servers.first {
                $0.toolID == .codexCLI && $0.name == "plugin-db" && $0.path == mcpPath
            })
            let shadowed = try XCTUnwrap(report.issues.first {
                $0.code == .projectSettingsShadowed
                    && $0.title == "Codex plugin MCP policy shadowed"
                    && $0.path == mcpPath
                    && $0.subjectPath == globalPath
            })

            XCTAssertFalse(server.disabled)
            XCTAssertTrue(shadowed.detail.contains(projectPath.replacingOccurrences(of: NSHomeDirectory(), with: "~")))
            XCTAssertTrue(shadowed.detail.contains(globalPath.replacingOccurrences(of: NSHomeDirectory(), with: "~")))
            XCTAssertTrue(shadowed.fixHint?.contains("shadowed enabled policy") == true)
        }
    }

    func testActiveProfileCodexPluginMCPPolicyOverridesTrustedProjectPolicy() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let pluginRoot = try writeCodexPlugin(
            pluginID: "profile-precedence@team-tools",
            codexHome: codexHome,
            enabled: true,
            mcpJSON: """
            {
              "mcpServers": {
                "plugin-db": {
                  "command": "node",
                  "args": ["server.js"]
                }
              }
            }
            """
        )
        let globalConfig = codexHome.appendingPathComponent("config.toml")
        let trustedProjectConfig = root.appendingPathComponent(".codex/config.toml")
        try FileManager.default.createDirectory(at: trustedProjectConfig.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        profile = "work"

        [plugins."profile-precedence@team-tools"]
        enabled = true

        [profiles.work.plugins."profile-precedence@team-tools".mcp_servers.plugin-db]
        enabled = false

        [projects."\(root.path)"]
        trust_level = "trusted"
        """.write(to: globalConfig, atomically: true, encoding: .utf8)
        try """
        [plugins."profile-precedence@team-tools".mcp_servers.plugin-db]
        enabled = true
        """.write(to: trustedProjectConfig, atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let mcpPath = canonicalFilePath(pluginRoot.appendingPathComponent(".mcp.json").path)
            let configPath = canonicalFilePath(globalConfig.path)
            let server = try XCTUnwrap(report.servers.first {
                $0.toolID == .codexCLI && $0.name == "plugin-db" && $0.path == mcpPath
            })
            let issue = try XCTUnwrap(report.issues.first {
                $0.code == .serverDisabled
                    && $0.path == mcpPath
                    && $0.subjectPath == configPath
            })

            XCTAssertTrue(server.disabled)
            XCTAssertEqual(server.health, .disabled)
            XCTAssertTrue(issue.detail.contains("active default profile work"))
            XCTAssertEqual(issue.metadata["codexPluginPolicyProfileName"], "work")
            XCTAssertEqual(issue.metadata["codexPluginPolicyProfileSource"], CodexProfileSelection.Source.defaultConfig.rawValue)
        }
    }

    func testActiveProfileCodexPluginMCPPolicyConflictNamesProjectLayerAsShadowed() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let pluginRoot = try writeCodexPlugin(
            pluginID: "profile-shadow@team-tools",
            codexHome: codexHome,
            enabled: true,
            mcpJSON: """
            {
              "mcpServers": {
                "plugin-db": {
                  "command": "node",
                  "args": ["server.js"]
                }
              }
            }
            """
        )
        let globalConfig = codexHome.appendingPathComponent("config.toml")
        let trustedProjectConfig = root.appendingPathComponent(".codex/config.toml")
        try FileManager.default.createDirectory(at: trustedProjectConfig.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        profile = "work"

        [plugins."profile-shadow@team-tools"]
        enabled = true

        [profiles.work.plugins."profile-shadow@team-tools".mcp_servers.plugin-db]
        enabled = false

        [projects."\(root.path)"]
        trust_level = "trusted"
        """.write(to: globalConfig, atomically: true, encoding: .utf8)
        try """
        [plugins."profile-shadow@team-tools".mcp_servers.plugin-db]
        enabled = true
        """.write(to: trustedProjectConfig, atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let mcpPath = canonicalFilePath(pluginRoot.appendingPathComponent(".mcp.json").path)
            let projectPath = canonicalFilePath(trustedProjectConfig.path)
            let shadowed = try XCTUnwrap(report.issues.first {
                $0.code == .projectSettingsShadowed
                    && $0.title == "Codex plugin MCP policy shadowed"
                    && $0.path == mcpPath
                    && $0.subjectPath == projectPath
            })

            XCTAssertTrue(shadowed.detail.contains("default profile work"))
            XCTAssertTrue(shadowed.detail.contains("disables"))
            XCTAssertTrue(shadowed.detail.contains("enables"))
            XCTAssertNil(shadowed.metadata["codexPluginPolicyProfileName"])
            XCTAssertNil(shadowed.metadata["codexPluginPolicyProfileSource"])
        }
    }

    func testCodexPluginMarketplaceFilesAreVisibleForCLIAndDesktop() throws {
        let root = try makeTempProject()
        let agentsHome = root.appendingPathComponent("agents-home", isDirectory: true)
        let personalMarketplace = agentsHome.appendingPathComponent("plugins/marketplace.json")
        let projectMarketplace = root.appendingPathComponent(".agents/plugins/marketplace.json")
        let legacyMarketplace = root.appendingPathComponent(".claude-plugin/marketplace.json")
        for path in [personalMarketplace, projectMarketplace, legacyMarketplace] {
            try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
            try """
            {
              "plugins": [
                {
                  "name": "example",
                  "path": "./plugins/example"
                }
              ]
            }
            """.write(to: path, atomically: true, encoding: .utf8)
        }

        withEnv("PROJECTHUB_AGENTS_HOME", agentsHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            for path in [personalMarketplace, projectMarketplace, legacyMarketplace].map({ canonicalFilePath($0.path) }) {
                XCTAssertTrue(report.settings.contains {
                    $0.toolID == .codexCLI
                        && $0.path == path
                        && $0.summary == "1 plugin entry"
                })
                XCTAssertTrue(report.settings.contains {
                    $0.toolID == .codexDesktop
                        && $0.path == path
                        && $0.summary == "1 plugin entry"
                })
            }
        }
    }

    func testCodexPluginInventoryReportsCacheConfigAndMarketplaceModes() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let agentsHome = root.appendingPathComponent("agents-home", isDirectory: true)
        let personalMarketplace = agentsHome.appendingPathComponent("plugins/marketplace.json")
        let projectMarketplace = root.appendingPathComponent(".agents/plugins/marketplace.json")
        let pluginRoot = try writeCodexPlugin(
            pluginID: "toolbox@team-tools",
            codexHome: codexHome,
            enabled: true,
            manifestJSON: """
            {
              "name": "toolbox",
              "version": "local",
              "mcpServers": "./.mcp.json",
              "skills": "./skills",
              "hooks": "./hooks/hooks.json"
            }
            """,
            mcpJSON: """
            {
              "mcpServers": {
                "toolbox": {
                  "command": "node",
                  "args": ["server.js"]
                }
              }
            }
            """
        )
        try FileManager.default.createDirectory(
            at: pluginRoot.appendingPathComponent("skills/toolbox", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: personalMarketplace.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: projectMarketplace.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        {
          "plugins": [
            {
              "name": "personal-helper",
              "path": "./personal-helper",
              "version": "0.1.0"
            }
          ]
        }
        """.write(to: personalMarketplace, atomically: true, encoding: .utf8)
        try """
        {
          "plugins": {
            "project-helper": {
              "path": "./plugins/project-helper"
            }
          }
        }
        """.write(to: projectMarketplace, atomically: true, encoding: .utf8)
        let configPath = codexHome.appendingPathComponent("config.toml")
        let existingConfig = try String(contentsOf: configPath, encoding: .utf8)
        try """
        \(existingConfig)

        [marketplaces.local-team]
        source = "\(root.appendingPathComponent("local-marketplace").path)"

        [plugins."missing@team-tools"]
        enabled = true
        """.write(to: configPath, atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            try withEnv("PROJECTHUB_AGENTS_HOME", agentsHome.path) {
                let report = CompatibilityScanner.scan(projectRoot: root.path)
                let installed = try XCTUnwrap(report.plugins.first {
                    $0.toolID == .codexCLI
                        && $0.pluginID == "toolbox@team-tools"
                        && $0.installMethod == .codexCache
                })

                XCTAssertEqual(installed.enabled, true)
                XCTAssertEqual(installed.marketplace, "team-tools")
                XCTAssertTrue(installed.components.contains("MCP"))
                XCTAssertTrue(installed.components.contains("skills"))
                XCTAssertTrue(installed.components.contains("hooks"))
                XCTAssertTrue(report.plugins.contains {
                    $0.toolID == .codexDesktop
                        && $0.pluginID == "toolbox@team-tools"
                        && $0.installMethod == .codexCache
                })
                XCTAssertTrue(report.plugins.contains {
                    $0.toolID == .codexCLI
                        && $0.pluginID == "marketplace:local-team"
                        && $0.installMethod == .codexMarketplaceConfig
                })
                XCTAssertTrue(report.plugins.contains {
                    $0.toolID == .codexCLI
                        && $0.pluginID == "personal-helper@personal"
                        && $0.installMethod == .codexMarketplaceFile
                        && $0.sourcePath == canonicalFilePath(personalMarketplace.path)
                })
                XCTAssertTrue(report.plugins.contains {
                    $0.toolID == .codexDesktop
                        && $0.pluginID == "project-helper@project"
                        && $0.installMethod == .codexMarketplaceFile
                        && $0.sourcePath == canonicalFilePath(projectMarketplace.path)
                })
                XCTAssertTrue(report.plugins.contains {
                    $0.toolID == .codexCLI
                        && $0.pluginID == "missing@team-tools"
                        && $0.installMethod == .codexConfig
                        && $0.enabled == true
                })
                XCTAssertTrue(report.issues.contains {
                    $0.title == "Codex plugin configured but not installed"
                        && $0.subjectPath == "missing@team-tools"
                })
            }
        }
    }

    func testCodexPluginManifestReportsInvalidAndMissingMCPPaths() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let outOfRoot = try writeCodexPlugin(
            pluginID: "outside@team-tools",
            codexHome: codexHome,
            enabled: true,
            manifestJSON: """
            {
              "name": "outside",
              "version": "local",
              "mcpServers": "../outside.json"
            }
            """,
            mcpJSON: nil
        )
        let missing = try writeCodexPlugin(
            pluginID: "missing@team-tools",
            codexHome: codexHome,
            enabled: true,
            manifestJSON: """
            {
              "name": "missing",
              "version": "local",
              "mcpServers": "./missing.mcp.json"
            }
            """,
            mcpJSON: nil
        )
        let wrongType = try writeCodexPlugin(
            pluginID: "wrongtype@team-tools",
            codexHome: codexHome,
            enabled: true,
            manifestJSON: """
            {
              "name": "wrongtype",
              "version": "local",
              "mcpServers": {
                "bad": true
              }
            }
            """,
            mcpJSON: nil
        )

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let invalidManifest = canonicalFilePath(outOfRoot.appendingPathComponent(".codex-plugin/plugin.json").path)
            let missingManifest = canonicalFilePath(missing.appendingPathComponent(".codex-plugin/plugin.json").path)
            let wrongTypeManifest = canonicalFilePath(wrongType.appendingPathComponent(".codex-plugin/plugin.json").path)

            XCTAssertFalse(report.matrix.contains {
                $0.kind == .mcp
                    && ($0.path?.hasPrefix(canonicalFilePath(outOfRoot.path)) == true
                        || $0.path?.hasPrefix(canonicalFilePath(missing.path)) == true
                        || $0.path?.hasPrefix(canonicalFilePath(wrongType.path)) == true)
            })
            XCTAssertTrue(report.issues.contains {
                $0.code == .configUnsupportedShape
                    && $0.path == invalidManifest
                    && $0.title == "Invalid Codex plugin MCP path"
            })
            XCTAssertTrue(report.issues.contains {
                $0.code == .configMissing
                    && $0.path == missingManifest
                    && $0.title == "Codex plugin MCP file missing"
            })
            XCTAssertTrue(report.issues.contains {
                $0.code == .configUnsupportedShape
                    && $0.path == wrongTypeManifest
                    && $0.title == "Invalid Codex plugin MCP path"
            })
        }
    }

    func testCodexPluginMCPPolicyIsSurfacedAsSettingsEvidence() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        _ = try writeCodexPlugin(
            pluginID: "policy@team-tools",
            codexHome: codexHome,
            enabled: true,
            extraConfig: """

            [plugins."policy@team-tools".mcp_servers.docs]
            enabled = true
            default_tools_approval_mode = "auto"
            enabled_tools = ["search"]

            [plugins."policy@team-tools".mcp_servers.docs.tools.search]
            approval_mode = "approve"
            """,
            mcpJSON: """
            {
              "mcpServers": {
                "docs": {
                  "type": "http",
                  "url": "https://docs.example.invalid/mcp"
                }
              }
            }
            """
        )

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let settings = try XCTUnwrap(report.settings.first {
                $0.surfaceID == "codex-cli-global-settings"
            })

            XCTAssertTrue(settings.summary.contains("1 plugin MCP policy"))
            XCTAssertTrue(settings.keys.contains("plugins.mcp_servers"))
            XCTAssertTrue(settings.keys.contains("plugins.policy@team-tools.mcp_servers.docs.default_tools_approval_mode"))
            XCTAssertTrue(settings.keys.contains("plugins.policy@team-tools.mcp_servers.docs.enabled_tools"))
            XCTAssertTrue(settings.keys.contains("plugins.policy@team-tools.mcp_servers.docs.tools.search.approval_mode"))
            XCTAssertFalse(report.issues.contains {
                $0.path == canonicalFilePath(codexHome.appendingPathComponent("config.toml").path)
                    && $0.subjectPath?.contains("policy@team-tools") == true
                    && $0.code == .configUnsupportedShape
            })
        }
    }

    func testProfileScopedCodexPluginMCPPolicyIsSurfacedAsSettingsEvidenceOnlyWithoutActiveProfile() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let pluginRoot = try writeCodexPlugin(
            pluginID: "profile-policy@team-tools",
            codexHome: codexHome,
            enabled: true,
            extraConfig: """

            [profiles.work.plugins."profile-policy@team-tools".mcp_servers.docs]
            enabled = false
            default_tools_approval_mode = "prompt"
            enabled_tools = ["search"]

            [profiles.work.plugins."profile-policy@team-tools".mcp_servers.docs.tools.search]
            approval_mode = "approve"
            """,
            mcpJSON: """
            {
              "mcpServers": {
                "docs": {
                  "type": "http",
                  "url": "https://docs.example.invalid/mcp"
                }
              }
            }
            """
        )

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let settings = try XCTUnwrap(report.settings.first {
                $0.surfaceID == "codex-cli-global-settings"
            })
            let mcpPath = canonicalFilePath(pluginRoot.appendingPathComponent(".mcp.json").path)
            let server = try XCTUnwrap(report.servers.first {
                $0.toolID == .codexCLI && $0.name == "docs" && $0.path == mcpPath
            })

            XCTAssertTrue(settings.summary.contains("1 plugin MCP policy"))
            XCTAssertTrue(settings.keys.contains("profiles"))
            XCTAssertTrue(settings.keys.contains("profiles.work.plugins.mcp_servers"))
            XCTAssertTrue(settings.keys.contains("profiles.work.plugins.profile-policy@team-tools.mcp_servers.docs.enabled"))
            XCTAssertTrue(settings.keys.contains("profiles.work.plugins.profile-policy@team-tools.mcp_servers.docs.default_tools_approval_mode"))
            XCTAssertTrue(settings.keys.contains("profiles.work.plugins.profile-policy@team-tools.mcp_servers.docs.enabled_tools"))
            XCTAssertTrue(settings.keys.contains("profiles.work.plugins.profile-policy@team-tools.mcp_servers.docs.tools.search.approval_mode"))
            XCTAssertFalse(server.disabled)
            XCTAssertNotEqual(server.health, .disabled)
            let conditional = try XCTUnwrap(report.issues.first {
                $0.code == .settingsProfileScopedPolicy
                    && $0.subjectPath == #"profiles.work.plugins."profile-policy@team-tools".mcp_servers.docs.enabled"#
            })
            XCTAssertEqual(conditional.severity, .info)
            XCTAssertTrue(conditional.detail.contains("codex --profile work"))
            XCTAssertTrue(conditional.detail.contains("No default profile is set"))
            XCTAssertFalse(report.issues.contains {
                $0.path == canonicalFilePath(codexHome.appendingPathComponent("config.toml").path)
                    && $0.subjectPath?.contains("profile-policy@team-tools") == true
                    && $0.code == .configUnsupportedShape
            })
        }
    }

    func testNonDefaultProfileCodexPluginMCPPolicyIsSurfacedAsConditionalEvidence() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let pluginRoot = try writeCodexPlugin(
            pluginID: "non-default-profile@team-tools",
            codexHome: codexHome,
            enabled: true,
            mcpJSON: """
            {
              "mcpServers": {
                "docs": {
                  "type": "http",
                  "url": "https://docs.example.invalid/mcp"
                }
              }
            }
            """
        )
        try """
        profile = "personal"

        [plugins."non-default-profile@team-tools"]
        enabled = true

        [profiles.work.plugins."non-default-profile@team-tools".mcp_servers.docs]
        enabled = false
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let mcpPath = canonicalFilePath(pluginRoot.appendingPathComponent(".mcp.json").path)
            let server = try XCTUnwrap(report.servers.first {
                $0.toolID == .codexCLI && $0.name == "docs" && $0.path == mcpPath
            })
            let conditional = try XCTUnwrap(report.issues.first {
                $0.code == .settingsProfileScopedPolicy
                    && $0.subjectPath == #"profiles.work.plugins."non-default-profile@team-tools".mcp_servers.docs.enabled"#
            })

            XCTAssertFalse(server.disabled)
            XCTAssertNotEqual(server.health, .disabled)
            XCTAssertEqual(conditional.severity, .info)
            XCTAssertTrue(conditional.detail.contains("current default profile is personal"))
            XCTAssertTrue(conditional.detail.contains("codex --profile work"))
            XCTAssertFalse(report.issues.contains {
                $0.code == .serverDisabled && $0.path == mcpPath
            })
        }
    }

    func testRuntimeProfileCodexPluginMCPPolicyDisablesCLIBundledServer() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let pluginRoot = try writeCodexPlugin(
            pluginID: "runtime-profile@team-tools",
            codexHome: codexHome,
            enabled: true,
            mcpJSON: """
            {
              "mcpServers": {
                "docs": {
                  "type": "http",
                  "url": "https://docs.example.invalid/mcp"
                }
              }
            }
            """
        )
        let configURL = codexHome.appendingPathComponent("config.toml")
        try """
        profile = "personal"

        [plugins."runtime-profile@team-tools"]
        enabled = true

        [plugins."runtime-profile@team-tools".mcp_servers.docs]
        enabled = true

        [profiles.work.plugins."runtime-profile@team-tools".mcp_servers.docs]
        enabled = false
        """.write(to: configURL, atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let defaultReport = CompatibilityScanner.scan(projectRoot: root.path)
            let runtimeReport = CompatibilityScanner.scan(
                projectRoot: root.path,
                codexProfileSelection: try XCTUnwrap(CodexProfileSelection.cliRuntimeOverride("work"))
            )
            let mcpPath = canonicalFilePath(pluginRoot.appendingPathComponent(".mcp.json").path)
            let configPath = canonicalFilePath(configURL.path)

            let defaultServer = try XCTUnwrap(defaultReport.servers.first {
                $0.toolID == .codexCLI && $0.name == "docs" && $0.path == mcpPath
            })
            let defaultConditional = try XCTUnwrap(defaultReport.issues.first {
                $0.code == .settingsProfileScopedPolicy
                    && $0.subjectPath == #"profiles.work.plugins."runtime-profile@team-tools".mcp_servers.docs.enabled"#
            })

            XCTAssertFalse(defaultServer.disabled)
            XCTAssertNotEqual(defaultServer.health, .disabled)
            XCTAssertTrue(defaultConditional.detail.contains("current default profile is personal"))
            XCTAssertTrue(defaultConditional.detail.contains("codex --profile work"))
            XCTAssertFalse(defaultReport.issues.contains {
                $0.code == .serverDisabled && $0.path == mcpPath
            })

            let cliServer = try XCTUnwrap(runtimeReport.servers.first {
                $0.toolID == .codexCLI && $0.name == "docs" && $0.path == mcpPath
            })
            let desktopServer = try XCTUnwrap(runtimeReport.servers.first {
                $0.toolID == .codexDesktop && $0.name == "docs" && $0.path == mcpPath
            })
            let disabled = try XCTUnwrap(runtimeReport.issues.first {
                $0.code == .serverDisabled
                    && $0.toolID == .codexCLI
                    && $0.path == mcpPath
                    && $0.subjectPath == configPath
            })

            XCTAssertTrue(cliServer.disabled)
            XCTAssertEqual(cliServer.health, .disabled)
            XCTAssertFalse(desktopServer.disabled)
            XCTAssertNotEqual(desktopServer.health, .disabled)
            XCTAssertTrue(disabled.detail.contains("runtime profile work"))
            XCTAssertEqual(disabled.metadata["codexPluginPolicyProfileName"], "work")
            XCTAssertEqual(disabled.metadata["codexPluginPolicyProfileSource"], CodexProfileSelection.Source.cliRuntimeOverride.rawValue)
            XCTAssertFalse(runtimeReport.issues.contains {
                $0.code == .settingsProfileScopedPolicy
                    && $0.toolID == .codexCLI
                    && $0.subjectPath == #"profiles.work.plugins."runtime-profile@team-tools".mcp_servers.docs.enabled"#
            })
            XCTAssertTrue(runtimeReport.issues.contains {
                $0.code == .settingsProfileScopedPolicy
                    && $0.toolID == .codexDesktop
                    && $0.subjectPath == #"profiles.work.plugins."runtime-profile@team-tools".mcp_servers.docs.enabled"#
            })
        }
    }

    func testRuntimeProfileFileCodexPluginMCPPolicyDisablesOnlyCLIBundledServer() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let pluginRoot = try writeCodexPlugin(
            pluginID: "profile-file@team-tools",
            codexHome: codexHome,
            enabled: true,
            extraConfig: """

            [plugins."profile-file@team-tools".mcp_servers.docs]
            enabled = true
            """,
            mcpJSON: """
            {
              "mcpServers": {
                "docs": {
                  "type": "http",
                  "url": "https://docs.example.invalid/mcp"
                }
              }
            }
            """
        )
        let profileURL = codexHome.appendingPathComponent("work.config.toml")
        try """
        model = "gpt-5.3-codex"

        [plugins."profile-file@team-tools".mcp_servers.docs]
        enabled = false
        """.write(to: profileURL, atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(
                projectRoot: root.path,
                codexProfileSelection: try XCTUnwrap(CodexProfileSelection.cliRuntimeOverride("work"))
            )
            let mcpPath = canonicalFilePath(pluginRoot.appendingPathComponent(".mcp.json").path)
            let profilePath = canonicalFilePath(profileURL.path)

            let cliServer = try XCTUnwrap(report.servers.first {
                $0.toolID == .codexCLI && $0.name == "docs" && $0.path == mcpPath
            })
            let desktopServer = try XCTUnwrap(report.servers.first {
                $0.toolID == .codexDesktop && $0.name == "docs" && $0.path == mcpPath
            })
            let disabled = try XCTUnwrap(report.issues.first {
                $0.code == .serverDisabled
                    && $0.toolID == .codexCLI
                    && $0.path == mcpPath
                    && $0.subjectPath == profilePath
            })

            XCTAssertTrue(cliServer.disabled)
            XCTAssertEqual(cliServer.health, .disabled)
            XCTAssertFalse(desktopServer.disabled)
            XCTAssertNotEqual(desktopServer.health, .disabled)
            XCTAssertTrue(disabled.detail.contains("runtime profile work"))
            XCTAssertEqual(disabled.metadata["codexPluginPolicyProfileName"], "work")
            XCTAssertEqual(disabled.metadata["codexPluginPolicyProfileSource"], CodexProfileSelection.Source.cliRuntimeOverride.rawValue)
            XCTAssertTrue(report.matrix.contains {
                $0.id == "codex-cli-profile-mcp|work"
                    && $0.toolID == .codexCLI
                    && $0.path.map(canonicalFilePath) == profilePath
            })
            XCTAssertTrue(report.matrix.contains {
                $0.id == "codex-cli-profile-settings|work"
                    && $0.toolID == .codexCLI
                    && $0.path.map(canonicalFilePath) == profilePath
            })
        }
    }

    func testRuntimeProfileFileCodexPluginInstallIsDiscoveredForCLIOnly() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let pluginRoot = try writeCodexPlugin(
            pluginID: "profile-only@team-tools",
            codexHome: codexHome,
            enabled: true,
            mcpJSON: """
            {
              "mcpServers": {
                "docs": {
                  "type": "http",
                  "url": "https://docs.example.invalid/mcp"
                }
              }
            }
            """
        )
        try "".write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try """
        [plugins."profile-only@team-tools"]
        enabled = true
        """.write(to: codexHome.appendingPathComponent("work.config.toml"), atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(
                projectRoot: root.path,
                codexProfileSelection: try XCTUnwrap(CodexProfileSelection.cliRuntimeOverride("work"))
            )
            let mcpPath = canonicalFilePath(pluginRoot.appendingPathComponent(".mcp.json").path)

            XCTAssertTrue(report.servers.contains {
                $0.toolID == .codexCLI && $0.name == "docs" && $0.path == mcpPath
            })
            XCTAssertFalse(report.servers.contains {
                $0.toolID == .codexDesktop && $0.name == "docs" && $0.path == mcpPath
            })
        }
    }

    func testActiveProfileCodexPluginMCPPolicyDisablesBundledServer() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let pluginRoot = try writeCodexPlugin(
            pluginID: "active-profile@team-tools",
            codexHome: codexHome,
            enabled: true,
            mcpJSON: """
            {
              "mcpServers": {
                "docs": {
                  "type": "http",
                  "url": "https://docs.example.invalid/mcp"
                }
              }
            }
            """
        )
        let configURL = codexHome.appendingPathComponent("config.toml")
        try """
        profile = "work"

        [plugins."active-profile@team-tools"]
        enabled = true

        [plugins."active-profile@team-tools".mcp_servers.docs]
        enabled = true

        [profiles.work.plugins."active-profile@team-tools".mcp_servers.docs]
        enabled = false
        """.write(to: configURL, atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let mcpPath = canonicalFilePath(pluginRoot.appendingPathComponent(".mcp.json").path)
            let configPath = canonicalFilePath(configURL.path)
            let server = try XCTUnwrap(report.servers.first {
                $0.toolID == .codexCLI && $0.name == "docs" && $0.path == mcpPath
            })
            let issue = try XCTUnwrap(report.issues.first {
                $0.code == .serverDisabled && $0.path == mcpPath && $0.subjectPath == configPath
            })

            XCTAssertTrue(server.disabled)
            XCTAssertEqual(server.health, .disabled)
            XCTAssertTrue(issue.detail.contains("active default profile work"))
        }
    }

    func testSingleQuotedActiveProfileCodexPluginMCPPolicyMatchesWriterIdentity() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let pluginRoot = try writeCodexPlugin(
            pluginID: "quoted.policy@team-tools",
            codexHome: codexHome,
            enabled: true,
            mcpJSON: """
            {
              "mcpServers": {
                "doc.search": {
                  "type": "http",
                  "url": "https://docs.example.invalid/mcp"
                }
              }
            }
            """
        )
        let configURL = codexHome.appendingPathComponent("config.toml")
        try """
        profile = 'work.profile'

        [plugins."quoted.policy@team-tools"]
        enabled = true

        [profiles.'work.profile'.plugins.'quoted.policy@team-tools'.mcp_servers.'doc.search']
        enabled = false
        enabled_tools = ["query"]
        """.write(to: configURL, atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let mcpPath = canonicalFilePath(pluginRoot.appendingPathComponent(".mcp.json").path)
            let configPath = canonicalFilePath(configURL.path)
            let server = try XCTUnwrap(report.servers.first {
                $0.toolID == .codexCLI && $0.name == "doc.search" && $0.path == mcpPath
            })
            let issue = try XCTUnwrap(report.issues.first {
                $0.code == .serverDisabled && $0.path == mcpPath && $0.subjectPath == configPath
            })

            XCTAssertTrue(server.disabled)
            XCTAssertEqual(server.health, .disabled)
            XCTAssertEqual(issue.metadata["codexPluginPolicyProfileName"], "work.profile")

            let preview = try XCTUnwrap(ConfigWriter.previewSetCodexPluginMCPServerEnabled(
                configPath: configURL.path,
                pluginID: "quoted.policy@team-tools",
                serverName: "doc.search",
                enabled: true,
                profileName: "work.profile"
            ))

            XCTAssertFalse(preview.after.contains("enabled = false"))
            XCTAssertTrue(preview.after.contains(#"enabled_tools = ["query"]"#))
            XCTAssertTrue(preview.after.contains("[profiles.'work.profile'.plugins.'quoted.policy@team-tools'.mcp_servers.'doc.search']"))
            XCTAssertFalse(preview.after.contains(#"[profiles."work.profile".plugins."quoted.policy@team-tools".mcp_servers."doc.search"]"#))

            try ConfigWriter.applyCodexPluginMCPServerEnabledPreview(
                configPath: configURL.path,
                expectedBefore: preview.before,
                approvedAfter: preview.after
            )

            let fixedReport = CompatibilityScanner.scan(projectRoot: root.path)
            let fixedServer = try XCTUnwrap(fixedReport.servers.first {
                $0.toolID == .codexCLI && $0.name == "doc.search" && $0.path == mcpPath
            })
            XCTAssertFalse(fixedServer.disabled)
            XCTAssertFalse(fixedReport.issues.contains {
                $0.code == .serverDisabled && $0.path == mcpPath && $0.subjectPath == configPath
            })
        }
    }

    func testCodexPluginMCPPolicyValidationReportsMalformedValuesAndSections() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        _ = try writeCodexPlugin(
            pluginID: "policy-bad@team-tools",
            codexHome: codexHome,
            enabled: true,
            extraConfig: """

            [plugins."policy-bad@team-tools".mcp_servers]
            stray = true

            [plugins."policy-bad@team-tools".mcp_servers.docs]
            enabled = "false"
            default_tools_approval_mode = "telepathic"
            enabled_tools = "search"
            disabled_tools = [false]
            unsupported = true

            [plugins."policy-bad@team-tools".mcp_servers.docs.tools]
            stray = true

            [plugins."policy-bad@team-tools".mcp_servers.docs.tools.search]
            approval_mode = "telepathic"
            extra = true

            [plugins."policy-bad@team-tools".mcp_servers.docs.tools.search.extra]
            approval_mode = "auto"
            """,
            mcpJSON: """
            {
              "mcpServers": {
                "docs": {
                  "type": "http",
                  "url": "https://docs.example.invalid/mcp"
                }
              }
            }
            """
        )

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let configPath = canonicalFilePath(codexHome.appendingPathComponent("config.toml").path)
            let issues = report.issues.filter {
                $0.path == configPath
                    && $0.code == .configUnsupportedShape
                    && ($0.subjectPath?.contains("policy-bad@team-tools") == true)
            }

            XCTAssertTrue(issues.contains { $0.subjectPath == #"plugins."policy-bad@team-tools".mcp_servers"# })
            XCTAssertTrue(issues.contains { $0.subjectPath == #"plugins."policy-bad@team-tools".mcp_servers.docs.enabled"# })
            XCTAssertTrue(issues.contains { $0.subjectPath == #"plugins."policy-bad@team-tools".mcp_servers.docs.default_tools_approval_mode"# })
            XCTAssertTrue(issues.contains { $0.subjectPath == #"plugins."policy-bad@team-tools".mcp_servers.docs.enabled_tools"# })
            XCTAssertTrue(issues.contains { $0.subjectPath == #"plugins."policy-bad@team-tools".mcp_servers.docs.disabled_tools"# })
            XCTAssertTrue(issues.contains { $0.subjectPath == #"plugins."policy-bad@team-tools".mcp_servers.docs.unsupported"# })
            XCTAssertTrue(issues.contains { $0.subjectPath == #"plugins."policy-bad@team-tools".mcp_servers.docs.tools"# })
            XCTAssertTrue(issues.contains { $0.subjectPath == #"plugins."policy-bad@team-tools".mcp_servers.docs.tools.search.approval_mode"# })
            XCTAssertTrue(issues.contains { $0.subjectPath == #"plugins."policy-bad@team-tools".mcp_servers.docs.tools.search.extra"# })
            let unsupported = try XCTUnwrap(issues.first { $0.subjectPath == #"plugins."policy-bad@team-tools".mcp_servers.docs.unsupported"# })
            XCTAssertEqual(unsupported.metadata["codexPluginMCPPolicySection"], #"plugins."policy-bad@team-tools".mcp_servers.docs"#)
            XCTAssertEqual(unsupported.metadata["codexPluginMCPPolicyKey"], "unsupported")
            XCTAssertEqual(unsupported.metadata["codexPluginMCPPolicyRepair"], "remove-section-key")
            let badApproval = try XCTUnwrap(issues.first { $0.subjectPath == #"plugins."policy-bad@team-tools".mcp_servers.docs.tools.search.approval_mode"# })
            XCTAssertEqual(badApproval.metadata["codexPluginMCPPolicySection"], #"plugins."policy-bad@team-tools".mcp_servers.docs.tools.search"#)
            XCTAssertEqual(badApproval.metadata["codexPluginMCPPolicyKey"], "approval_mode")
            XCTAssertEqual(badApproval.metadata["codexPluginMCPPolicyRepair"], "remove-section-key")
            XCTAssertGreaterThanOrEqual(issues.count, 9)
        }
    }

    func testProfileScopedCodexPluginMCPPolicyValidationReportsMalformedValuesAndSections() throws {
        let root = try makeTempProject()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        _ = try writeCodexPlugin(
            pluginID: "profile-bad@team-tools",
            codexHome: codexHome,
            enabled: true,
            extraConfig: """

            [profiles.work.plugins."profile-bad@team-tools".mcp_servers]
            stray = true

            [profiles.work.plugins."profile-bad@team-tools".mcp_servers.docs]
            enabled = "false"
            default_tools_approval_mode = "telepathic"
            enabled_tools = "search"
            disabled_tools = [false]
            unsupported = true

            [profiles.work.plugins."profile-bad@team-tools".mcp_servers.docs.tools]
            stray = true

            [profiles.work.plugins."profile-bad@team-tools".mcp_servers.docs.tools.search]
            approval_mode = "telepathic"
            extra = true

            [profiles.work.plugins."profile-bad@team-tools".mcp_servers.docs.tools.search.extra]
            approval_mode = "auto"
            """,
            mcpJSON: """
            {
              "mcpServers": {
                "docs": {
                  "type": "http",
                  "url": "https://docs.example.invalid/mcp"
                }
              }
            }
            """
        )

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let configPath = canonicalFilePath(codexHome.appendingPathComponent("config.toml").path)
            let issues = report.issues.filter {
                $0.path == configPath
                    && $0.code == .configUnsupportedShape
                    && ($0.subjectPath?.contains("profile-bad@team-tools") == true)
            }

            XCTAssertTrue(issues.contains { $0.subjectPath == #"profiles.work.plugins."profile-bad@team-tools".mcp_servers"# })
            XCTAssertTrue(issues.contains { $0.subjectPath == #"profiles.work.plugins."profile-bad@team-tools".mcp_servers.docs.enabled"# })
            XCTAssertTrue(issues.contains { $0.subjectPath == #"profiles.work.plugins."profile-bad@team-tools".mcp_servers.docs.default_tools_approval_mode"# })
            XCTAssertTrue(issues.contains { $0.subjectPath == #"profiles.work.plugins."profile-bad@team-tools".mcp_servers.docs.enabled_tools"# })
            XCTAssertTrue(issues.contains { $0.subjectPath == #"profiles.work.plugins."profile-bad@team-tools".mcp_servers.docs.disabled_tools"# })
            XCTAssertTrue(issues.contains { $0.subjectPath == #"profiles.work.plugins."profile-bad@team-tools".mcp_servers.docs.unsupported"# })
            XCTAssertTrue(issues.contains { $0.subjectPath == #"profiles.work.plugins."profile-bad@team-tools".mcp_servers.docs.tools"# })
            XCTAssertTrue(issues.contains { $0.subjectPath == #"profiles.work.plugins."profile-bad@team-tools".mcp_servers.docs.tools.search.approval_mode"# })
            XCTAssertTrue(issues.contains { $0.subjectPath == #"profiles.work.plugins."profile-bad@team-tools".mcp_servers.docs.tools.search.extra"# })
            XCTAssertGreaterThanOrEqual(issues.count, 9)
        }
    }

    func testClaudePluginMCPServersAreDiscoveredFromInstalledPluginInventory() throws {
        let root = try makeTempProject()
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        let pluginRoot = claudeHome
            .appendingPathComponent("plugins/marketplaces/team-tools/project-tools", isDirectory: true)
        let server = pluginRoot.appendingPathComponent("bin/server")
        try FileManager.default.createDirectory(at: server.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\nexit 0\n".write(to: server, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: server.path)
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
        try """
        {
          "mcpServers": {
            "plugin-db": {
              "command": "${CLAUDE_PLUGIN_ROOT}/bin/server",
              "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"],
              "env": {
                "DB_PATH": "${CLAUDE_PLUGIN_ROOT}/data"
              }
            }
          }
        }
        """.write(to: pluginRoot.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        try withClaudeHome(claudeHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let mcpPath = canonicalFilePath(pluginRoot.appendingPathComponent(".mcp.json").path)
            let observed = try XCTUnwrap(report.servers.first {
                $0.toolID == .claudeCode
                    && $0.name == "plugin-db"
                    && $0.path == mcpPath
            })
            let healthEntry = try XCTUnwrap(CompatibilityScanner.healthEntry(for: observed, matrix: report.matrix))

            XCTAssertTrue(report.matrix.contains {
                $0.id.hasPrefix("claude-code-plugin-mcp|project-tools@team-tools|enabled|")
                    && $0.path == mcpPath
                    && $0.canWriteSafely == false
                    && $0.requiresRestartAfterWrite == true
            })
            XCTAssertFalse(observed.disabled)
            XCTAssertEqual(healthEntry.command, canonicalFilePath(server.path))
            XCTAssertEqual(healthEntry.args, ["--config", canonicalFilePath(pluginRoot.appendingPathComponent("config.json").path)])
            XCTAssertEqual(healthEntry.env["DB_PATH"], canonicalFilePath(pluginRoot.appendingPathComponent("data").path))
            XCTAssertFalse(report.issues.contains {
                $0.code == .serverEnvMissing && $0.detail.contains("CLAUDE_PLUGIN_ROOT")
            })
        }
    }

    func testClaudePluginInlineManifestMCPServersAreDiscovered() throws {
        let root = try makeTempProject()
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        let pluginRoot = claudeHome
            .appendingPathComponent("plugins/marketplaces/team-tools/project-tools", isDirectory: true)
        let manifestDirectory = pluginRoot.appendingPathComponent(".claude-plugin", isDirectory: true)
        try FileManager.default.createDirectory(at: manifestDirectory, withIntermediateDirectories: true)
        try writeInstalledClaudePlugin(
            pluginID: "project-tools@team-tools",
            scope: "user",
            installPath: pluginRoot.path,
            claudeHome: claudeHome
        )
        try """
        {
          "name": "project-tools",
          "mcpServers": {
            "inline-api": {
              "type": "http",
              "url": "https://example.invalid/mcp"
            }
          }
        }
        """.write(to: manifestDirectory.appendingPathComponent("plugin.json"), atomically: true, encoding: .utf8)

        withClaudeHome(claudeHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let manifestPath = canonicalFilePath(manifestDirectory.appendingPathComponent("plugin.json").path)

            XCTAssertTrue(report.matrix.contains {
                $0.id.hasPrefix("claude-code-plugin-mcp|project-tools@team-tools|enabled|")
                    && $0.path == manifestPath
            })
            XCTAssertTrue(report.servers.contains {
                $0.toolID == .claudeCode
                    && $0.name == "inline-api"
                    && $0.path == manifestPath
                    && $0.transport == "http"
            })
        }
    }

    func testDisabledClaudePluginMCPServersAreReportedDisabled() throws {
        let root = try makeTempProject()
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        let pluginRoot = claudeHome
            .appendingPathComponent("plugins/marketplaces/team-tools/project-tools", isDirectory: true)
        try FileManager.default.createDirectory(at: pluginRoot, withIntermediateDirectories: true)
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
        try """
        {
          "mcpServers": {
            "plugin-db": {
              "command": "node",
              "args": ["server.js"]
            }
          }
        }
        """.write(to: pluginRoot.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        try withClaudeHome(claudeHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let mcpPath = canonicalFilePath(pluginRoot.appendingPathComponent(".mcp.json").path)
            let observed = try XCTUnwrap(report.servers.first { $0.name == "plugin-db" && $0.path == mcpPath })

            XCTAssertTrue(observed.disabled)
            XCTAssertEqual(observed.health, .disabled)
            XCTAssertTrue(report.issues.contains {
                $0.code == .serverDisabled
                    && $0.title == "Server disabled"
                    && $0.path == mcpPath
            })
        }
    }

    func testClaudePluginInventoryReportsInstalledSettingsSkillsDirAndMarketplaceModes() throws {
        let root = try makeTempProject()
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        let pluginRoot = claudeHome
            .appendingPathComponent("plugins/cache/team-tools/project-tools/1.0.0", isDirectory: true)
        let manifestDirectory = pluginRoot.appendingPathComponent(".claude-plugin", isDirectory: true)
        try FileManager.default.createDirectory(at: manifestDirectory, withIntermediateDirectories: true)
        try """
        {
          "name": "project-tools",
          "version": "1.0.0",
          "skills": ["./skills"],
          "commands": ["./commands"],
          "agents": ["./agents"],
          "hooks": ["./hooks"],
          "mcpServers": {
            "inline-api": {
              "type": "http",
              "url": "https://example.invalid/mcp"
            }
          }
        }
        """.write(to: manifestDirectory.appendingPathComponent("plugin.json"), atomically: true, encoding: .utf8)
        try writeInstalledClaudePlugin(
            pluginID: "project-tools@team-tools",
            scope: "user",
            installPath: pluginRoot.path,
            claudeHome: claudeHome
        )

        let skillsDirPlugin = claudeHome.appendingPathComponent("skills/local-helper/.claude-plugin", isDirectory: true)
        try FileManager.default.createDirectory(at: skillsDirPlugin, withIntermediateDirectories: true)
        try """
        {
          "name": "local-helper",
          "version": "0.2.0",
          "skills": ["./skills"]
        }
        """.write(to: skillsDirPlugin.appendingPathComponent("plugin.json"), atomically: true, encoding: .utf8)

        let marketplacePlugin = claudeHome
            .appendingPathComponent("plugins/marketplaces/local-upload/dodo/.claude-plugin", isDirectory: true)
        try FileManager.default.createDirectory(at: marketplacePlugin, withIntermediateDirectories: true)
        try """
        {
          "name": "dodo",
          "version": "0.1.0",
          "commands": ["./commands"]
        }
        """.write(to: marketplacePlugin.appendingPathComponent("plugin.json"), atomically: true, encoding: .utf8)

        try """
        {
          "enabledPlugins": {
            "project-tools@team-tools": true,
            "missing@team-tools": true
          },
          "extraKnownMarketplaces": {
            "team-tools": {
              "type": "github",
              "repo": "org/team-tools"
            },
            "local-tools": "/tmp/local-tools"
          }
        }
        """.write(to: claudeHome.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)

        try withClaudeHome(claudeHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let installed = try XCTUnwrap(report.plugins.first {
                $0.toolID == .claudeCode
                    && $0.pluginID == "project-tools@team-tools"
                    && $0.installMethod == .claudeInstalledInventory
            })

            XCTAssertEqual(installed.enabled, true)
            XCTAssertEqual(installed.version, "1.0.0")
            XCTAssertTrue(installed.components.contains("MCP"))
            XCTAssertTrue(installed.components.contains("skills"))
            XCTAssertTrue(installed.components.contains("commands"))
            XCTAssertTrue(installed.components.contains("agents"))
            XCTAssertTrue(installed.components.contains("hooks"))
            XCTAssertTrue(report.plugins.contains {
                $0.pluginID == "missing@team-tools"
                    && $0.installMethod == .claudeSettings
                    && $0.enabled == true
            })
            XCTAssertTrue(report.plugins.contains {
                $0.pluginID == "marketplace:team-tools"
                    && $0.installMethod == .claudeKnownMarketplace
                    && $0.installPath == "org/team-tools"
            })
            XCTAssertTrue(report.plugins.contains {
                $0.pluginID == "local-helper@skills-dir"
                    && $0.installMethod == .claudeSkillsDirectory
                    && $0.version == "0.2.0"
            })
            XCTAssertTrue(report.plugins.contains {
                $0.pluginID == "dodo@local-upload"
                    && $0.installMethod == .claudeMarketplaceDirectory
                    && $0.version == "0.1.0"
            })
            XCTAssertTrue(report.issues.contains {
                $0.title == "Claude Code plugin configured but not installed"
                    && $0.subjectPath == "missing@team-tools"
            })
        }
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

    private func writeCodexPlugin(
        pluginID: String,
        codexHome: URL,
        enabled: Bool,
        extraConfig: String = "",
        manifestJSON: String? = nil,
        mcpJSON: String?
    ) throws -> URL {
        let parts = try XCTUnwrap(splitCodexPluginID(pluginID))
        let pluginRoot = codexHome
            .appendingPathComponent("plugins", isDirectory: true)
            .appendingPathComponent("cache", isDirectory: true)
            .appendingPathComponent(parts.marketplace, isDirectory: true)
            .appendingPathComponent(parts.name, isDirectory: true)
            .appendingPathComponent("local", isDirectory: true)
        let manifestDirectory = pluginRoot.appendingPathComponent(".codex-plugin", isDirectory: true)
        try FileManager.default.createDirectory(at: manifestDirectory, withIntermediateDirectories: true)
        let manifest = manifestJSON ?? """
        {
          "name": "\(parts.name)",
          "version": "local",
          "mcpServers": "./.mcp.json"
        }
        """
        try manifest.write(to: manifestDirectory.appendingPathComponent("plugin.json"), atomically: true, encoding: .utf8)
        if let mcpJSON {
            try mcpJSON.write(to: pluginRoot.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)
        }

        let configPath = codexHome.appendingPathComponent("config.toml")
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        let existing = (try? String(contentsOf: configPath, encoding: .utf8)) ?? ""
        try """
        \(existing)

        [plugins."\(pluginID)"]
        enabled = \(enabled ? "true" : "false")
        \(extraConfig)
        """.write(to: configPath, atomically: true, encoding: .utf8)
        return pluginRoot
    }

    private func splitCodexPluginID(_ pluginID: String) -> (name: String, marketplace: String)? {
        guard let at = pluginID.lastIndex(of: "@") else { return nil }
        let name = String(pluginID[..<at])
        let marketplace = String(pluginID[pluginID.index(after: at)...])
        guard !name.isEmpty, !marketplace.isEmpty else { return nil }
        return (name, marketplace)
    }

    private func withClaudeHome(_ path: String, run: () throws -> Void) rethrows {
        let key = "PROJECTHUB_CLAUDE_HOME"
        let previous = getenv(key).map { String(cString: $0) }
        setenv(key, path, 1)
        defer {
            if let previous {
                setenv(key, previous, 1)
            } else {
                unsetenv(key)
            }
        }
        try run()
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

    private func withCodexHome(_ path: String, run: () throws -> Void) rethrows {
        let key = "CODEX_HOME"
        let previous = getenv(key).map { String(cString: $0) }
        setenv(key, path, 1)
        defer {
            if let previous {
                setenv(key, previous, 1)
            } else {
                unsetenv(key)
            }
        }
        try run()
    }

    private func canonicalFilePath(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    private func makeTempProject() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubCompatibilityPluginMCPTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }

    func testPluginScanSkipsMCPServerInspection() throws {
        let root = try makeTempProject()
        try """
        {
          "mcpServers": {
            "local-notes": {
              "command": "npx",
              "args": ["-y", "mcp-server"]
            }
          }
        }
        """.write(to: root.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        let full = CompatibilityScanner.scan(projectRoot: root.path, kind: .full)
        let plugins = CompatibilityScanner.scan(projectRoot: root.path, kind: .plugins)

        XCTAssertFalse(full.servers.isEmpty, "full scan should read project MCP")
        XCTAssertTrue(plugins.servers.isEmpty, "plugin scan must not inspect MCP servers")
        XCTAssertEqual(plugins.skills.count, 0)
        XCTAssertEqual(plugins.settings.count, 0)
    }
}
