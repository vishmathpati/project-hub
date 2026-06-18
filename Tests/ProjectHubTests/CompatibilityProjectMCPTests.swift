import XCTest
@testable import ProjectHub

final class CompatibilityProjectMCPTests: XCTestCase {
    func testClaudeLocalMCPUsesCanonicalProjectStateFallbackAndDisabledRuntimeList() throws {
        let root = try makeTempDirectory()
        let realParent = root.appendingPathComponent("Real", isDirectory: true)
        let project = realParent.appendingPathComponent("repo", isDirectory: true)
        let aliasParent = root.appendingPathComponent("Alias", isDirectory: true)
        let aliasProject = aliasParent.appendingPathComponent("repo", isDirectory: true)
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        let claudeJSON = root.appendingPathComponent("claude.json")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: aliasParent, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: aliasProject, withDestinationURL: project)

        try """
        {
          "projects": {
            "\(aliasProject.path)": {
              "mcpServers": {
                "docs": {
                  "type": "http",
                  "url": "https://example.com/mcp"
                }
              },
              "disabledMcpServers": ["docs"]
            }
          }
        }
        """.write(to: claudeJSON, atomically: true, encoding: .utf8)

        try withClaudeHome(claudeHome.path) {
            try withClaudeJSONPath(claudeJSON.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let server = try XCTUnwrap(report.servers.first {
                    $0.toolID == .claudeCode
                        && $0.surfaceID.hasPrefix("claude-code-local-mcp")
                        && $0.name == "docs"
                })
                let entry = try XCTUnwrap(CompatibilityScanner.healthEntry(for: server, matrix: report.matrix))

                XCTAssertTrue(server.disabled)
                XCTAssertEqual(server.health, .disabled)
                XCTAssertEqual(entry.url, "https://example.com/mcp")
                XCTAssertTrue(entry.isDisabled)
            }
        }
    }

    func testClaudeProjectMCPDisabledBySettingsIsReportedDisabled() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)

        try """
        {
          "mcpServers": {
            "docs": {
              "type": "http",
              "url": "https://example.com/mcp"
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)
        try """
        {
          // Explicitly rejected project MCP servers should stay visible but disabled.
          "disabledMcpjsonServers": ["docs"]
        }
        """.write(to: project.appendingPathComponent(".claude/settings.local.json"), atomically: true, encoding: .utf8)

        try withClaudeHome(claudeHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let server = try XCTUnwrap(report.servers.first {
                $0.toolID == .claudeCode
                    && $0.surfaceID == "claude-code-project-mcp"
                    && $0.name == "docs"
            })

            XCTAssertTrue(server.disabled)
            XCTAssertEqual(server.health, .disabled)
            XCTAssertTrue(server.issueCodes.contains(.serverDisabled))
            XCTAssertTrue(report.issues.contains {
                $0.code == .serverDisabled
                    && $0.surfaceID == "claude-code-project-mcp"
                    && $0.detail.contains("\"docs\"")
            })

            let entry = try XCTUnwrap(CompatibilityScanner.healthEntry(for: server, matrix: report.matrix))
            XCTAssertEqual(entry.url, "https://example.com/mcp")
            XCTAssertTrue(entry.isDisabled)
        }
    }

    func testClaudeProjectMCPDisabledByManagedSettingsIsReportedDisabled() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        let managedDir = root.appendingPathComponent("managed", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: managedDir, withIntermediateDirectories: true)

        try """
        {
          "mcpServers": {
            "docs": {
              "type": "http",
              "url": "https://example.com/mcp"
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)
        try """
        {
          "disabledMcpjsonServers": ["docs"]
        }
        """.write(to: managedDir.appendingPathComponent("managed-settings.json"), atomically: true, encoding: .utf8)

        try withClaudeHome(claudeHome.path) {
            try withClaudeManagedDir(managedDir.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let server = try XCTUnwrap(report.servers.first {
                    $0.toolID == .claudeCode
                        && $0.surfaceID == "claude-code-project-mcp"
                        && $0.name == "docs"
                })

                XCTAssertTrue(server.disabled)
                XCTAssertEqual(server.health, .disabled)
                XCTAssertTrue(report.issues.contains {
                    $0.code == .serverDisabled
                        && $0.surfaceID == "claude-code-project-mcp"
                        && $0.detail.contains("\"docs\"")
                })
            }
        }
    }

    func testClaudeProjectMCPDisabledByLocalProjectStateIsReportedDisabled() throws {
        let root = try makeTempDirectory()
        let realParent = root.appendingPathComponent("Real", isDirectory: true)
        let project = realParent.appendingPathComponent("repo", isDirectory: true)
        let aliasParent = root.appendingPathComponent("Alias", isDirectory: true)
        let aliasProject = aliasParent.appendingPathComponent("repo", isDirectory: true)
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        let claudeJSON = root.appendingPathComponent("claude.json")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: aliasParent, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: aliasProject, withDestinationURL: project)

        try """
        {
          "mcpServers": {
            "docs": {
              "type": "http",
              "url": "https://example.com/mcp"
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)
        try """
        {
          "projects": {
            "\(aliasProject.path)": {
              "disabledMcpjsonServers": ["docs"]
            }
          }
        }
        """.write(to: claudeJSON, atomically: true, encoding: .utf8)

        try withClaudeHome(claudeHome.path) {
            try withClaudeJSONPath(claudeJSON.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let server = try XCTUnwrap(report.servers.first {
                    $0.toolID == .claudeCode
                        && $0.surfaceID == "claude-code-project-mcp"
                        && $0.name == "docs"
                })
                let entry = try XCTUnwrap(CompatibilityScanner.healthEntry(for: server, matrix: report.matrix))

                XCTAssertTrue(server.disabled)
                XCTAssertEqual(server.health, .disabled)
                XCTAssertTrue(server.issueCodes.contains(.serverDisabled))
                XCTAssertTrue(entry.isDisabled)
                XCTAssertEqual(entry.url, "https://example.com/mcp")
            }
        }
    }

    func testClaudeProjectMCPAllowsStreamableHTTPTransportSpelling() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)

        try """
        {
          "mcpServers": {
            "docs": {
              "type": "streamable-http",
              "url": "https://example.com/mcp"
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)
        try """
        {
          "enableAllProjectMcpServers": true
        }
        """.write(to: project.appendingPathComponent(".claude/settings.local.json"), atomically: true, encoding: .utf8)

        try withClaudeHome(claudeHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let server = try XCTUnwrap(report.servers.first {
                $0.toolID == .claudeCode
                    && $0.surfaceID == "claude-code-project-mcp"
                    && $0.name == "docs"
            })

            XCTAssertEqual(server.transport, "streamable-http")
            XCTAssertFalse(report.issues.contains {
                $0.code == .serverUnsupportedTransport
                    && $0.surfaceID == "claude-code-project-mcp"
                    && $0.detail.contains("\"docs\"")
            })
        }
    }

    func testClaudeProjectMCPAllowsWebSocketTransportSpelling() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)

        try """
        {
          "mcpServers": {
            "events": {
              "type": "ws",
              "url": "wss://example.com/socket",
              "headers": {
                "Authorization": "Bearer ${EVENTS_TOKEN}"
              }
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)
        try """
        {
          "enableAllProjectMcpServers": true
        }
        """.write(to: project.appendingPathComponent(".claude/settings.local.json"), atomically: true, encoding: .utf8)

        try withClaudeHome(claudeHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let server = try XCTUnwrap(report.servers.first {
                $0.toolID == .claudeCode
                    && $0.surfaceID == "claude-code-project-mcp"
                    && $0.name == "events"
            })

            XCTAssertEqual(server.transport, "ws")
            XCTAssertFalse(report.issues.contains {
                $0.code == .serverUnsupportedTransport
                    && $0.surfaceID == "claude-code-project-mcp"
                    && $0.detail.contains("\"events\"")
            })
        }
    }

    func testClaudePrivateProjectStateDenylistDoesNotActAsEffectiveMCPPolicy() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        let claudeJSON = root.appendingPathComponent("claude.json")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)

        try """
        {
          "mcpServers": {
            "docs": {
              "type": "http",
              "url": "https://example.com/mcp"
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)
        try """
        {
          "projects": {
            "\(project.path)": {
              "deniedMcpServers": [
                { "serverName": "docs" }
              ]
            }
          }
        }
        """.write(to: claudeJSON, atomically: true, encoding: .utf8)

        try withClaudeHome(claudeHome.path) {
            try withClaudeJSONPath(claudeJSON.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let server = try XCTUnwrap(report.servers.first {
                    $0.toolID == .claudeCode
                        && $0.surfaceID == "claude-code-project-mcp"
                        && $0.name == "docs"
                })

                XCTAssertFalse(server.disabled)
                XCTAssertFalse(server.issueCodes.contains(.serverDisabled))
                XCTAssertNotEqual(server.health, .disabled)
                XCTAssertFalse(report.issues.contains {
                    $0.code == .serverDisabled
                        && $0.title == "Claude MCP blocked by denylist"
                        && $0.subjectPath == "docs"
                })
                XCTAssertTrue(report.issues.contains {
                    $0.code == .settingsManagedRequirement
                        && $0.surfaceID?.hasPrefix("claude-code-local-project-state") == true
                        && $0.title == "Claude local project state contains policy-shaped fields"
                        && $0.subjectPath?.contains("deniedMcpServers") == true
                })
            }
        }
    }

    func testClaudeProjectMCPApprovalMissingIsReportedUnknown() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        let claudeJSON = root.appendingPathComponent("claude.json")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)

        try """
        {
          "mcpServers": {
            "docs": {
              "type": "http",
              "url": "https://example.com/mcp"
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)
        try """
        {
          "projects": {
            "\(project.path)": {
              "enabledMcpjsonServers": ["other-docs"],
              "disabledMcpjsonServers": []
            }
          }
        }
        """.write(to: claudeJSON, atomically: true, encoding: .utf8)

        try withClaudeHome(claudeHome.path) {
            try withClaudeJSONPath(claudeJSON.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let server = try XCTUnwrap(report.servers.first {
                    $0.toolID == .claudeCode
                        && $0.surfaceID == "claude-code-project-mcp"
                        && $0.name == "docs"
                })

                XCTAssertFalse(server.disabled)
                XCTAssertEqual(server.health, .unknown)
                XCTAssertTrue(report.issues.contains {
                    $0.code == .serverHealthUnknown
                        && $0.title == "Claude project MCP approval not recorded"
                        && $0.subjectPath == "docs"
                })
            }
        }
    }

    func testClaudeProjectMCPApprovalRecordedSuppressesApprovalUnknown() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        let claudeJSON = root.appendingPathComponent("claude.json")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)

        try """
        {
          "mcpServers": {
            "docs": {
              "type": "http",
              "url": "https://example.com/mcp"
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)
        try """
        {
          "projects": {
            "\(project.path)": {
              "enabledMcpjsonServers": ["docs"]
            }
          }
        }
        """.write(to: claudeJSON, atomically: true, encoding: .utf8)

        withClaudeHome(claudeHome.path) {
            withClaudeJSONPath(claudeJSON.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)

                XCTAssertFalse(report.issues.contains {
                    $0.code == .serverHealthUnknown
                        && $0.title == "Claude project MCP approval not recorded"
                        && $0.subjectPath == "docs"
                })
            }
        }
    }

    func testSharedCodexProjectMCPServersCanBeDeduplicatedForCombinedViews() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)

        try """
        [mcp_servers.docs]
        url = "https://example.com/mcp"
        """.write(to: project.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let sharedProjectServers = report.servers.filter {
                $0.name == "docs"
                    && $0.path == project.appendingPathComponent(".codex/config.toml").path
                    && ($0.toolID == .codexCLI || $0.toolID == .codexDesktop)
            }

            XCTAssertEqual(sharedProjectServers.count, 2)
            XCTAssertEqual(
                CompatibilityScanner.deduplicatedSharedCodexServers(sharedProjectServers).count,
                1
            )
        }
    }

    func testCodexProjectMCPAllowsStreamableHTTPTransportSpelling() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)

        try """
        [mcp_servers.docs]
        type = "streamable-http"
        url = "https://example.com/mcp"
        """.write(to: project.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let servers = report.servers.filter {
                ($0.toolID == .codexCLI || $0.toolID == .codexDesktop)
                    && $0.name == "docs"
                    && $0.path == project.appendingPathComponent(".codex/config.toml").path
            }

            XCTAssertEqual(servers.count, 2)
            XCTAssertTrue(servers.allSatisfy { $0.transport == "streamable-http" })
            XCTAssertFalse(report.issues.contains {
                $0.code == .serverUnsupportedTransport
                    && ($0.toolID == .codexCLI || $0.toolID == .codexDesktop)
                    && $0.detail.contains("\"docs\"")
            })
        }
    }

    func testCodexProjectMCPQuotedDottedServerNameIsNotSplitAsSubtable() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)

        try """
        [mcp_servers.'github.docs']
        type = "streamable-http"
        url = "https://example.com/github/docs/mcp"
        http_headers = { "X-Static" = "yes" }

        [mcp_servers.'github.docs'.env_http_headers]
        Authorization = "GITHUB_TOKEN"
        """.write(to: project.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let configPath = project.appendingPathComponent(".codex/config.toml").path
            let servers = report.servers.filter {
                ($0.toolID == .codexCLI || $0.toolID == .codexDesktop)
                    && $0.name == "github.docs"
                    && $0.path == configPath
            }

            XCTAssertEqual(servers.count, 2)
            XCTAssertFalse(report.servers.contains {
                ($0.toolID == .codexCLI || $0.toolID == .codexDesktop)
                    && $0.name == "github"
                    && $0.path == configPath
            })
            let entry = try XCTUnwrap(servers.compactMap {
                CompatibilityScanner.healthEntry(for: $0, matrix: report.matrix)
            }.first)
            XCTAssertEqual(entry.url, "https://example.com/github/docs/mcp")
            XCTAssertEqual(entry.headers["X-Static"], "yes")
            XCTAssertEqual(entry.headers["Authorization"], "${GITHUB_TOKEN}")
        }
    }

    func testNestedCodexProjectConfigLayersAreScannedFromSelectedSubdirectory() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)

        try """
        [projects."\(project.path)"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        try """
        [mcp_servers.root_docs]
        url = "https://example.com/root/mcp"
        """.write(to: project.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)

        try """
        [mcp_servers.nested_docs]
        url = "https://example.com/nested/mcp"
        """.write(to: nested.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: nested.path)
            let rootPath = project.appendingPathComponent(".codex/config.toml").path
            let nestedPath = nested.appendingPathComponent(".codex/config.toml").path
            let codexServers = report.servers.filter {
                $0.toolID == .codexCLI || $0.toolID == .codexDesktop
            }

            XCTAssertEqual(report.projectRoot, project.path)
            XCTAssertTrue(codexServers.contains { $0.name == "root_docs" && $0.path == rootPath })
            XCTAssertTrue(codexServers.contains { $0.name == "nested_docs" && $0.path == nestedPath })
            XCTAssertTrue(report.matrix.contains {
                $0.id.hasPrefix("codex-cli-project-settings|")
                    && $0.path == nestedPath
                    && !$0.canWriteSafely
            })
        }
    }

    func testNestedCodexProjectMCPPartialLayerMergesWithRootServer() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)

        try """
        [projects."\(project.path)"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        try """
        [mcp_servers.docs]
        url = "https://example.com/root/mcp"
        """.write(to: project.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)

        try """
        [mcp_servers.docs]
        enabled = false
        """.write(to: nested.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: nested.path)
            let nestedPath = nested.appendingPathComponent(".codex/config.toml").path
            let nestedServer = try XCTUnwrap(report.servers.first {
                $0.toolID == .codexCLI
                    && $0.name == "docs"
                    && $0.path == nestedPath
            })
            let entry = try XCTUnwrap(CompatibilityScanner.healthEntry(for: nestedServer, matrix: report.matrix))

            XCTAssertTrue(nestedServer.disabled)
            XCTAssertEqual(nestedServer.health, .disabled)
            XCTAssertEqual(entry.url, "https://example.com/root/mcp")
            XCTAssertTrue(entry.isDisabled)
            XCTAssertFalse(nestedServer.issueCodes.contains(.serverMissingLaunchTarget))
            XCTAssertFalse(report.issues.contains {
                ($0.code == .serverDuplicateName || $0.code == .serverConflictDifferentConfig || $0.code == .serverShadowedByProjectLayer)
                    && $0.toolID == .codexCLI
                    && $0.detail.contains("\"docs\"")
            })
        }
    }

    func testNestedCodexProjectMCPReportsOnlyOverriddenLeafKeys() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)

        try """
        [projects."\(project.path)"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        try """
        [mcp_servers.docs]
        command = "npx"
        args = ["-y", "@example/root"]
        """.write(to: project.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)

        try """
        [mcp_servers.docs]
        args = ["-y", "@example/nested"]
        """.write(to: nested.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: nested.path)
            let rootPath = project.appendingPathComponent(".codex/config.toml").path
            let nestedPath = nested.appendingPathComponent(".codex/config.toml").path
            let shadowed = report.issues.filter {
                $0.code == .serverShadowedByProjectLayer
                    && $0.toolID == .codexCLI
            }
            let nestedServer = try XCTUnwrap(report.servers.first {
                $0.toolID == .codexCLI
                    && $0.name == "docs"
                    && $0.path == nestedPath
            })
            let entry = try XCTUnwrap(CompatibilityScanner.healthEntry(for: nestedServer, matrix: report.matrix))

            XCTAssertEqual(shadowed.count, 1)
            XCTAssertEqual(shadowed.first?.path, rootPath)
            XCTAssertEqual(shadowed.first?.subjectPath, nestedPath)
            XCTAssertTrue(shadowed.first?.detail.contains("args") == true)
            XCTAssertFalse(report.issues.contains {
                ($0.code == .serverDuplicateName || $0.code == .serverConflictDifferentConfig)
                    && $0.toolID == .codexCLI
                    && $0.detail.contains("\"docs\"")
            })
            XCTAssertEqual(entry.command, "npx")
            XCTAssertEqual(entry.args, ["-y", "@example/nested"])
        }
    }

    func testNestedCodexProjectMCPMergesNestedSubtablesByLeafKey() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)

        try """
        [projects."\(project.path)"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        try """
        [mcp_servers.docs]
        command = "npx"

        [mcp_servers.docs.env]
        FOO = "root"
        BAR = "root"
        """.write(to: project.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)

        try """
        [mcp_servers.docs.env]
        BAR = "nested"
        BAZ = "nested"
        """.write(to: nested.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: nested.path)
            let nestedPath = nested.appendingPathComponent(".codex/config.toml").path
            let nestedServer = try XCTUnwrap(report.servers.first {
                $0.toolID == .codexCLI
                    && $0.name == "docs"
                    && $0.path == nestedPath
            })
            let entry = try XCTUnwrap(CompatibilityScanner.healthEntry(for: nestedServer, matrix: report.matrix))
            let shadowed = try XCTUnwrap(report.issues.first {
                $0.code == .serverShadowedByProjectLayer
                    && $0.toolID == .codexCLI
                    && $0.detail.contains("\"docs\"")
            })

            XCTAssertEqual(entry.command, "npx")
            XCTAssertEqual(entry.env["FOO"], "root")
            XCTAssertEqual(entry.env["BAR"], "nested")
            XCTAssertEqual(entry.env["BAZ"], "nested")
            XCTAssertTrue(shadowed.detail.contains("env.BAR"))
            XCTAssertFalse(shadowed.detail.contains("env.BAZ"))
        }
    }

    func testAdjacentEditorProjectMCPFilesProducePrimaryToolVisibilityFinding() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".cursor"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".vscode"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".roo"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)

        try """
        {
          "mcpServers": {
            "cursor-search": {
              "command": "npx",
              "args": ["-y", "@example/cursor-search"]
            }
          }
        }
        """.write(to: project.appendingPathComponent(".cursor/mcp.json"), atomically: true, encoding: .utf8)
        try """
        {
          "servers": {
            "vscode-docs": {
              "command": "npx",
              "args": ["-y", "@example/vscode-docs"]
            }
          }
        }
        """.write(to: project.appendingPathComponent(".vscode/mcp.json"), atomically: true, encoding: .utf8)
        try """
        {
          "mcpServers": {
            "roo-db": {
              "url": "https://example.com/roo/mcp"
            }
          }
        }
        """.write(to: project.appendingPathComponent(".roo/mcp.json"), atomically: true, encoding: .utf8)

        withClaudeHome(claudeHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let visibilityIssues = report.issues.filter {
                $0.code == .projectMCPNotUsedByPrimaryTools
                    && $0.title.localizedCaseInsensitiveContains("project MCP is editor-specific")
            }

            XCTAssertEqual(visibilityIssues.count, 3)
            XCTAssertTrue(visibilityIssues.allSatisfy { $0.severity == .info && $0.state == .unknown })
            XCTAssertTrue(visibilityIssues.contains {
                $0.path == project.appendingPathComponent(".cursor/mcp.json").path
                    && $0.detail.contains("cursor-search")
                    && $0.detail.contains("not by Claude Code")
            })
            XCTAssertTrue(visibilityIssues.contains {
                $0.path == project.appendingPathComponent(".vscode/mcp.json").path
                    && $0.detail.contains("vscode-docs")
                    && $0.fixHint?.contains(".mcp.json") == true
                    && $0.fixHint?.contains(".codex/config.toml") == true
            })
            XCTAssertTrue(visibilityIssues.contains {
                $0.path == project.appendingPathComponent(".roo/mcp.json").path
                    && $0.detail.contains("roo-db")
            })
        }
    }

    func testAdjacentEditorProjectMCPVisibilityFindingStillAppearsForInvalidConfig() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".vscode"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)
        try "{ invalid".write(to: project.appendingPathComponent(".vscode/mcp.json"), atomically: true, encoding: .utf8)

        withClaudeHome(claudeHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let issue = report.issues.first {
                $0.code == .projectMCPNotUsedByPrimaryTools
                    && $0.path == project.appendingPathComponent(".vscode/mcp.json").path
            }

            XCTAssertEqual(issue?.state, .unknown)
            XCTAssertTrue(issue?.detail.contains("could not read any MCP servers") == true)
        }
    }

    func testNoAdjacentEditorProjectMCPVisibilityFindingWithoutAdjacentConfigs() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)

        withClaudeHome(claudeHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            XCTAssertFalse(report.issues.contains { $0.code == .projectMCPNotUsedByPrimaryTools })
        }
    }

    func testClaudeCodeWorkspaceMCPNameIsReserved() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "workspace": {
              "type": "http",
              "url": "https://example.invalid/mcp"
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withClaudeHome(claudeHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let server = report.servers.first {
                $0.toolID == .claudeCode
                    && $0.surfaceID == "claude-code-project-mcp"
                    && $0.name == "workspace"
            }
            let issue = report.issues.first {
                $0.code == .serverReservedName
                    && $0.surfaceID == "claude-code-project-mcp"
            }

            XCTAssertEqual(server?.health, .broken)
            XCTAssertTrue(server?.issueCodes.contains(.serverReservedName) == true)
            XCTAssertEqual(issue?.state, .broken)
            XCTAssertTrue(issue?.detail.contains("Claude Code reserves") == true)
        }
    }

    func testWorkspaceMCPNameReservedOnlyForClaudeCode() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        [mcp_servers.workspace]
        command = "npx"
        args = ["-y", "@example/workspace-mcp"]
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let codexServers = report.servers.filter {
                $0.name == "workspace"
                    && ($0.toolID == .codexCLI || $0.toolID == .codexDesktop)
            }

            XCTAssertEqual(codexServers.count, 2)
            XCTAssertFalse(codexServers.contains { $0.health == .broken })
            XCTAssertFalse(report.issues.contains { $0.code == .serverReservedName })
        }
    }

    private func withCodexHome(_ path: String, run: () throws -> Void) rethrows {
        let codexKey = "CODEX_HOME"
        let claudeKey = "PROJECTHUB_CLAUDE_HOME"
        let previousCodex = getenv(codexKey).map { String(cString: $0) }
        let previousClaude = getenv(claudeKey).map { String(cString: $0) }
        let isolatedClaudeHome = (path as NSString).appendingPathComponent("isolated-claude-home")
        setenv(codexKey, path, 1)
        setenv(claudeKey, isolatedClaudeHome, 1)
        defer {
            if let previousCodex {
                setenv(codexKey, previousCodex, 1)
            } else {
                unsetenv(codexKey)
            }
            if let previousClaude {
                setenv(claudeKey, previousClaude, 1)
            } else {
                unsetenv(claudeKey)
            }
        }
        try run()
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

    private func withClaudeJSONPath(_ path: String, run: () throws -> Void) rethrows {
        let key = "PROJECTHUB_CLAUDE_JSON_PATH"
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

    private func withClaudeManagedDir(_ path: String, run: () throws -> Void) rethrows {
        let key = "PROJECTHUB_CLAUDE_CODE_MANAGED_DIR"
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

    private func makeTempDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubCompatibilityProjectMCPTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }
}
