import XCTest
@testable import ProjectHub

final class ProjectMCPReaderTests: XCTestCase {
    func testProjectMCPReaderIncludesVSCodeAndRooProjectConfigs() throws {
        let root = try makeTempDirectory()
        try writeJSON(
            """
            {
              "servers": {
                "vscode-docs": {
                  "command": "npx",
                  "args": ["-y", "@example/vscode-docs"]
                }
              }
            }
            """,
            to: root.appendingPathComponent(".vscode/mcp.json")
        )
        try writeJSON(
            """
            {
              "mcpServers": {
                "roo-db": {
                  "url": "https://example.com/roo/mcp"
                }
              }
            }
            """,
            to: root.appendingPathComponent(".roo/mcp.json")
        )

        let servers = MCPReader.servers(for: root.path)

        XCTAssertTrue(servers.contains {
            $0.source == .vscode
            && $0.name == "vscode-docs"
            && $0.detail.contains("@example/vscode-docs")
        })
        XCTAssertTrue(servers.contains {
            $0.source == .roo
            && $0.name == "roo-db"
            && $0.detail == "https://example.com/roo/mcp"
        })
    }

    func testProjectStoreDetectedToolsIncludesVSCodeAndRooProjectConfigs() throws {
        let root = try makeTempDirectory()
        try writeJSON(#"{"servers":{}}"#, to: root.appendingPathComponent(".vscode/mcp.json"))
        try writeJSON(#"{"mcpServers":{}}"#, to: root.appendingPathComponent(".roo/mcp.json"))

        let tools = ProjectStore.detectedTools(at: root.path, fm: FileManager.default)

        XCTAssertTrue(tools.contains("vscode"))
        XCTAssertTrue(tools.contains("roo"))
    }

    func testProjectStoreDetectedToolsIncludesClaudeSkillsAndProjectSettings() throws {
        let root = try makeTempDirectory()
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".claude/skills/deploy", isDirectory: true), withIntermediateDirectories: true)
        try "Review local setup.".write(to: root.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try writeJSON(#"{"permissions":{"allow":[]}}"#, to: root.appendingPathComponent(".claude/settings.json"))
        try "description: Deploy\n".write(to: root.appendingPathComponent(".claude/skills/deploy/SKILL.md"), atomically: true, encoding: .utf8)

        let tools = ProjectStore.detectedTools(at: root.path, fm: FileManager.default)

        XCTAssertEqual(tools.filter { $0 == "claude-code" }.count, 1)
    }

    func testProjectStoreDetectedToolsIncludesCodexSkillsAndInstructions() throws {
        let root = try makeTempDirectory()
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".agents/skills/docs", isDirectory: true), withIntermediateDirectories: true)
        try "Use the docs skill.".write(to: root.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)
        try "description: Docs\n".write(to: root.appendingPathComponent(".agents/skills/docs/SKILL.md"), atomically: true, encoding: .utf8)

        let tools = ProjectStore.detectedTools(at: root.path, fm: FileManager.default)

        XCTAssertEqual(tools.filter { $0 == "codex" }.count, 1)
    }

    func testProjectMCPReaderShowsEnvSplitStringLauncherDetail() throws {
        let root = try makeTempDirectory()
        try writeJSON(
            """
            {
              "servers": {
                "dockerized": {
                  "command": "/usr/bin/env",
                  "args": [
                    "-S",
                    "API_TOKEN docker run --env-file .env.mcp --env SERVICE_TOKEN ghcr.io/example/mcp:latest"
                  ]
                }
              }
            }
            """,
            to: root.appendingPathComponent(".vscode/mcp.json")
        )

        let servers = MCPReader.servers(for: root.path)
        let row = try XCTUnwrap(servers.first { $0.source == .vscode && $0.name == "dockerized" })
        XCTAssertEqual(row.detail, "docker run --env-file .env.mcp --env SERVICE_TOKEN ghcr.io/example/mcp:latest")

        let entry = try XCTUnwrap(ConfigWriter.readAllServerEntries(
            toolID: "vscode",
            scope: .project,
            projectRoot: root.path
        ).first { $0.name == "dockerized" })
        XCTAssertEqual(entry.command, "docker")
        XCTAssertEqual(entry.args, ["run", "--env-file", ".env.mcp", "--env", "SERVICE_TOKEN", "ghcr.io/example/mcp:latest"])
        XCTAssertEqual(entry.env["API_TOKEN"], "${API_TOKEN}")
        XCTAssertEqual(entry.env["SERVICE_TOKEN"], "${SERVICE_TOKEN}")
        XCTAssertEqual(entry.envFile, ".env.mcp")
    }

    func testProjectServerEntriesIncludeDisabledJSONServers() throws {
        let root = try makeTempDirectory()
        try writeJSON(
            """
            {
              "servers": {
                "active": { "command": "npx", "args": ["-y", "@example/active"] }
              },
              "servers_disabled": {
                "paused": { "url": "https://example.com/paused/mcp" }
              }
            }
            """,
            to: root.appendingPathComponent(".vscode/mcp.json")
        )

        let entries = ConfigWriter.readAllServerEntries(
            toolID: "vscode",
            scope: .project,
            projectRoot: root.path
        )

        XCTAssertTrue(entries.contains { $0.name == "active" && !$0.isDisabled })
        XCTAssertTrue(entries.contains { $0.name == "paused" && $0.isDisabled })
    }

    func testProjectServerEntriesNormalizeCommandArrays() throws {
        let root = try makeTempDirectory()
        try writeJSON(
            """
            {
              "servers": {
                "array-command": {
                  "command": ["docker", "run", "--rm", "ghcr.io/example/mcp:latest"]
                },
                "string-command": {
                  "command": "npx -y @example/mcp"
                },
                "homebrew": {
                  "command": "brew mcp-server"
                },
                "crates": {
                  "command": "cargo run --release",
                  "cwd": "/path/to/crates-mcp"
                },
                "go-tools": {
                  "command": "go run ./cmd/server"
                }
              }
            }
            """,
            to: root.appendingPathComponent(".vscode/mcp.json")
        )

        let entries = ConfigWriter.readAllServerEntries(
            toolID: "vscode",
            scope: .project,
            projectRoot: root.path
        )
        let arrayCommand = try XCTUnwrap(entries.first { $0.name == "array-command" })
        let stringCommand = try XCTUnwrap(entries.first { $0.name == "string-command" })
        let homebrew = try XCTUnwrap(entries.first { $0.name == "homebrew" })
        let crates = try XCTUnwrap(entries.first { $0.name == "crates" })
        let goTools = try XCTUnwrap(entries.first { $0.name == "go-tools" })

        XCTAssertEqual(arrayCommand.command, "docker")
        XCTAssertEqual(arrayCommand.args, ["run", "--rm", "ghcr.io/example/mcp:latest"])
        XCTAssertEqual(stringCommand.command, "npx")
        XCTAssertEqual(stringCommand.args, ["-y", "@example/mcp"])
        XCTAssertEqual(homebrew.command, "brew")
        XCTAssertEqual(homebrew.args, ["mcp-server"])
        XCTAssertEqual(crates.command, "cargo")
        XCTAssertEqual(crates.args, ["run", "--release"])
        XCTAssertEqual(goTools.command, "go")
        XCTAssertEqual(goTools.args, ["run", "./cmd/server"])
    }

    func testProjectMCPReaderPreservesDisabledProjectServers() throws {
        let root = try makeTempDirectory()
        try writeJSON(
            """
            {
              "servers": {
                "active": { "command": "npx", "args": ["-y", "@example/active"] }
              },
              "servers_disabled": {
                "paused": { "url": "https://example.com/paused/mcp" }
              }
            }
            """,
            to: root.appendingPathComponent(".vscode/mcp.json")
        )
        try writeJSON(
            """
            {
              "mcpServers": {
                "docs": { "command": "node", "args": ["server.js"] }
              },
              "disabledMcpjsonServers": ["docs"],
              "mcpServers_disabled": {
                "legacy-paused": { "url": "https://example.com/legacy/mcp" }
              }
            }
            """,
            to: root.appendingPathComponent(".mcp.json")
        )

        let servers = MCPReader.servers(for: root.path)

        XCTAssertTrue(servers.contains {
            $0.source == .vscode && $0.name == "active" && !$0.isDisabled
        })
        XCTAssertTrue(servers.contains {
            $0.source == .vscode && $0.name == "paused" && $0.isDisabled
        })
        XCTAssertTrue(servers.contains {
            $0.source == .claudeCode && $0.name == "docs" && $0.isDisabled
        })
        XCTAssertTrue(servers.contains {
            $0.source == .claudeCode && $0.name == "legacy-paused" && $0.isDisabled
        })
    }

    func testProjectMCPReaderShowsCommandArrayDetailsFromClaudeLocalState() throws {
        let root = try makeTempDirectory()
        let claudeJSON = root.appendingPathComponent("claude.json")
        try writeJSON(
            """
            {
              "projects": {
                "\(root.path)": {
                  "mcpServers": {
                    "local-array": {
                      "command": ["uvx", "example-mcp", "--stdio"]
                    }
                  }
                }
              }
            }
            """,
            to: claudeJSON
        )

        withEnv("PROJECTHUB_CLAUDE_JSON_PATH", claudeJSON.path) {
            let servers = MCPReader.servers(for: root.path)

            XCTAssertTrue(servers.contains {
                $0.source == .claudeCodeLocal
                    && $0.name == "local-array"
                    && $0.detail == "uvx example-mcp --stdio"
            })
        }
    }

    func testProjectMCPReaderShowsEnvSplitStringDetailsFromClaudeLocalState() throws {
        let root = try makeTempDirectory()
        let claudeJSON = root.appendingPathComponent("claude.json")
        try writeJSON(
            """
            {
              "projects": {
                "\(root.path)": {
                  "mcpServers": {
                    "local-env-split": {
                      "command": "/usr/bin/env",
                      "args": [
                        "-S",
                        "API_TOKEN uvx example-mcp --stdio"
                      ]
                    }
                  }
                }
              }
            }
            """,
            to: claudeJSON
        )

        withEnv("PROJECTHUB_CLAUDE_JSON_PATH", claudeJSON.path) {
            let servers = MCPReader.servers(for: root.path)

            XCTAssertTrue(servers.contains {
                $0.source == .claudeCodeLocal
                    && $0.name == "local-env-split"
                    && $0.detail == "uvx example-mcp --stdio"
            })
        }
    }

    func testProjectMCPReaderIncludesQuotedCodexProjectServerNamesWithDots() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent(".codex/config.toml")
        try FileManager.default.createDirectory(at: config.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        [mcp_servers.'github.docs']
        command = 'npx'
        enabled = false

        [mcp_servers.'github.docs'.env]
        GITHUB_TOKEN = "${GITHUB_TOKEN}"
        """.write(to: config, atomically: true, encoding: .utf8)

        let servers = MCPReader.servers(for: root.path)

        XCTAssertTrue(servers.contains {
            $0.source == .codex
                && $0.name == "github.docs"
                && $0.detail.contains("npx")
                && $0.isDisabled
        })
        XCTAssertFalse(servers.contains {
            $0.source == .codex && $0.name == "github"
        })
    }

    func testClaudeDisabledProjectServerNamesIncludeDisabledMapAndApprovalList() throws {
        let root = try makeTempDirectory()
        try writeJSON(
            """
            {
              "mcpServers": {},
              "mcpServers_disabled": {
                "legacy-disabled": { "command": "node" }
              }
            }
            """,
            to: root.appendingPathComponent(".mcp.json")
        )

        XCTAssertEqual(
            MCPReader.disabledClaudeCodeServerNames(projectPath: root.path),
            ["legacy-disabled"]
        )

        try writeJSON(
            """
            {
              "mcpServers": {},
              "disabledMcpjsonServers": ["approval-disabled"]
            }
            """,
            to: root.appendingPathComponent(".mcp.json")
        )

        XCTAssertEqual(
            MCPReader.disabledClaudeCodeServerNames(projectPath: root.path),
            ["approval-disabled"]
        )
    }

    func testClaudeDisabledProjectServerNamesUnionDisabledShapesAndStripComments() throws {
        let root = try makeTempDirectory()
        try writeJSON(
            """
            {
              // Claude Code can leave JSONC-style comments in local config.
              "mcpServers": {},
              "mcpServers_disabled": {
                "legacy-disabled": { "command": "node" }
              },
              "disabledMcpjsonServers": ["approval-disabled"]
            }
            """,
            to: root.appendingPathComponent(".mcp.json")
        )

        XCTAssertEqual(
            MCPReader.disabledClaudeCodeServerNames(projectPath: root.path),
            ["legacy-disabled", "approval-disabled"]
        )
    }

    func testClaudeProjectMCPReaderMarksSettingsLocalDisabledMcpjsonServersDisabled() throws {
        let root = try makeTempDirectory()
        try writeJSON(
            """
            {
              "mcpServers": {
                "docs": { "command": "npx", "args": ["-y", "@example/docs"] }
              }
            }
            """,
            to: root.appendingPathComponent(".mcp.json")
        )
        let settingsLocal = root.appendingPathComponent(".claude/settings.local.json")
        try writeJSON(
            """
            {
              "disabledMcpjsonServers": ["docs"]
            }
            """,
            to: settingsLocal
        )

        try withEnv("PROJECTHUB_CLAUDE_HOME", root.appendingPathComponent("claude-home", isDirectory: true).path) {
            let servers = MCPReader.servers(for: root.path)
            let docs = try XCTUnwrap(servers.first { $0.source == .claudeCode && $0.name == "docs" })
            let approval = MCPReader.claudeCodeProjectMCPApprovalState(projectPath: root.path)

            XCTAssertTrue(docs.isDisabled)
            XCTAssertEqual(approval.disabledSources(for: "docs"), [settingsLocal.path])
        }
    }

    func testClaudeProjectMCPReaderMarksManagedDisabledMcpjsonServersDisabled() throws {
        let root = try makeTempDirectory()
        let managedDir = root.appendingPathComponent("managed", isDirectory: true)
        let managedSettings = managedDir.appendingPathComponent("managed-settings.json")
        try FileManager.default.createDirectory(at: managedDir, withIntermediateDirectories: true)
        try writeJSON(
            """
            {
              "mcpServers": {
                "docs": { "command": "npx", "args": ["-y", "@example/docs"] }
              }
            }
            """,
            to: root.appendingPathComponent(".mcp.json")
        )
        try writeJSON(
            """
            {
              "disabledMcpjsonServers": ["docs"]
            }
            """,
            to: managedSettings
        )

        try withEnv("PROJECTHUB_CLAUDE_HOME", root.appendingPathComponent("claude-home", isDirectory: true).path) {
            try withEnv("PROJECTHUB_CLAUDE_CODE_MANAGED_DIR", managedDir.path) {
                let servers = MCPReader.servers(for: root.path)
                let docs = try XCTUnwrap(servers.first { $0.source == .claudeCode && $0.name == "docs" })
                let approval = MCPReader.claudeCodeProjectMCPApprovalState(projectPath: root.path)

                XCTAssertTrue(docs.isDisabled)
                XCTAssertEqual(approval.disabledSources(for: "docs"), [managedSettings.path])
            }
        }
    }

    func testClaudeProjectMCPReaderMarksPrivateProjectStateDisabledMcpjsonServersDisabled() throws {
        let root = try makeTempDirectory()
        let realProject = root.appendingPathComponent("real/repo", isDirectory: true)
        let aliasProject = root.appendingPathComponent("alias/repo", isDirectory: true)
        let claudeJSON = root.appendingPathComponent("claude.json")
        try FileManager.default.createDirectory(at: realProject, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: aliasProject.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: aliasProject, withDestinationURL: realProject)
        try writeJSON(
            """
            {
              "mcpServers": {
                "docs": { "url": "https://example.com/mcp" }
              }
            }
            """,
            to: realProject.appendingPathComponent(".mcp.json")
        )
        try writeJSON(
            """
            {
              "projects": {
                "\(aliasProject.path)": {
                  "disabledMcpjsonServers": ["docs"]
                }
              }
            }
            """,
            to: claudeJSON
        )

        try withEnv("PROJECTHUB_CLAUDE_HOME", root.appendingPathComponent("claude-home", isDirectory: true).path) {
            try withEnv("PROJECTHUB_CLAUDE_JSON_PATH", claudeJSON.path) {
                let servers = MCPReader.servers(for: realProject.path)
                let docs = try XCTUnwrap(servers.first { $0.source == .claudeCode && $0.name == "docs" })
                let approval = MCPReader.claudeCodeProjectMCPApprovalState(projectPath: realProject.path)

                XCTAssertTrue(docs.isDisabled)
                XCTAssertEqual(approval.disabledSources(for: "docs"), [claudeJSON.path])
            }
        }
    }

    func testProjectMCPReaderIncludesClaudeCodeLocalProjectStateServers() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let claudeJSON = root.appendingPathComponent("claude.json")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try writeJSON(
            """
            {
              "projects": {
                "\(project.path)": {
                  "mcpServers": {
                    "private": {
                      "type": "stdio",
                      "command": "/bin/echo",
                      "args": ["local"]
                    }
                  }
                }
              }
            }
            """,
            to: claudeJSON
        )

        try withEnv("PROJECTHUB_CLAUDE_HOME", root.appendingPathComponent("claude-home", isDirectory: true).path) {
            try withEnv("PROJECTHUB_CLAUDE_JSON_PATH", claudeJSON.path) {
                let servers = MCPReader.servers(for: project.path)
                let local = try XCTUnwrap(servers.first { $0.source == .claudeCodeLocal && $0.name == "private" })

                XCTAssertEqual(local.detail, "/bin/echo local")
                XCTAssertFalse(local.isDisabled)
            }
        }
    }

    func testProjectMCPReaderKeepsClaudeProjectAndLocalServersDistinct() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let claudeJSON = root.appendingPathComponent("claude.json")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try writeJSON(
            """
            {
              "mcpServers": {
                "docs": { "command": "npx", "args": ["-y", "@example/docs"] }
              }
            }
            """,
            to: project.appendingPathComponent(".mcp.json")
        )
        try writeJSON(
            """
            {
              "projects": {
                "\(project.path)": {
                  "mcpServers": {
                    "docs": { "url": "https://private.example.com/mcp" }
                  }
                }
              }
            }
            """,
            to: claudeJSON
        )

        withEnv("PROJECTHUB_CLAUDE_HOME", root.appendingPathComponent("claude-home", isDirectory: true).path) {
            withEnv("PROJECTHUB_CLAUDE_JSON_PATH", claudeJSON.path) {
                let docs = MCPReader.servers(for: project.path).filter { $0.name == "docs" }

                XCTAssertEqual(Set(docs.map(\.source)), [.claudeCode, .claudeCodeLocal])
                XCTAssertEqual(Set(docs.map(\.id)), ["claude-code/docs", "claude-code-local/docs"])
            }
        }
    }

    func testProjectMCPReaderMarksClaudeLocalDisabledMCPServersDisabled() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let claudeJSON = root.appendingPathComponent("claude.json")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try writeJSON(
            """
            {
              "projects": {
                "\(project.path)": {
                  "mcpServers": {
                    "private": { "url": "https://private.example.com/mcp" }
                  },
                  "mcpServers_disabled": {
                    "paused": { "command": "/bin/echo", "args": ["paused"] }
                  },
                  "disabledMcpServers": ["private"]
                }
              }
            }
            """,
            to: claudeJSON
        )

        try withEnv("PROJECTHUB_CLAUDE_HOME", root.appendingPathComponent("claude-home", isDirectory: true).path) {
            try withEnv("PROJECTHUB_CLAUDE_JSON_PATH", claudeJSON.path) {
                let servers = MCPReader.servers(for: project.path)
                let privateServer = try XCTUnwrap(servers.first { $0.source == .claudeCodeLocal && $0.name == "private" })
                let paused = try XCTUnwrap(servers.first { $0.source == .claudeCodeLocal && $0.name == "paused" })

                XCTAssertTrue(privateServer.isDisabled)
                XCTAssertTrue(paused.isDisabled)
            }
        }
    }

    func testContextEstimatorIncludesClaudeLocalProjectStateServers() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let claudeJSON = root.appendingPathComponent("claude.json")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try writeJSON(
            """
            {
              "projects": {
                "\(project.path)": {
                  "mcpServers": {
                    "private": { "url": "https://private.example.com/mcp" }
                  },
                  "disabledMcpServers": ["private"]
                }
              }
            }
            """,
            to: claudeJSON
        )

        withEnv("PROJECTHUB_CLAUDE_HOME", root.appendingPathComponent("claude-home", isDirectory: true).path) {
            withEnv("PROJECTHUB_CLAUDE_JSON_PATH", claudeJSON.path) {
                let snapshot = ContextEstimator.estimate(for: project.path)

                XCTAssertTrue(snapshot.mcpServers.contains {
                    $0.id == "claude-code-local/private"
                        && $0.toolID == "claude-code-local"
                        && !$0.enabled
                })
            }
        }
    }

    func testContextEstimatorUsesClaudeSettingsLocalApprovalDisable() throws {
        let root = try makeTempDirectory()
        try writeJSON(
            """
            {
              "mcpServers": {
                "docs": { "command": "npx", "args": ["-y", "@example/docs"] }
              }
            }
            """,
            to: root.appendingPathComponent(".mcp.json")
        )
        try writeJSON(
            """
            {
              "disabledMcpjsonServers": ["docs"]
            }
            """,
            to: root.appendingPathComponent(".claude/settings.local.json")
        )

        withEnv("PROJECTHUB_CLAUDE_HOME", root.appendingPathComponent("claude-home", isDirectory: true).path) {
            let snapshot = ContextEstimator.estimate(for: root.path)

            XCTAssertTrue(snapshot.mcpServers.contains {
                $0.id == "claude-code/docs" && !$0.enabled
            })
        }
    }

    func testContextEstimatorIncludesDisabledProjectMCPEntriesAcrossSources() throws {
        let root = try makeTempDirectory()
        try writeJSON(
            """
            {
              "servers": {
                "active": { "command": "npx", "args": ["-y", "@example/active"] }
              },
              "servers_disabled": {
                "paused": { "url": "https://example.com/paused/mcp" }
              }
            }
            """,
            to: root.appendingPathComponent(".vscode/mcp.json")
        )

        let snapshot = ContextEstimator.estimate(for: root.path)

        XCTAssertTrue(snapshot.mcpServers.contains {
            $0.id == "vscode/active" && $0.enabled
        })
        XCTAssertTrue(snapshot.mcpServers.contains {
            $0.id == "vscode/paused" && !$0.enabled
        })
    }

    func testProfileCopierCountsAndCopiesClaudeAndCodexMCPServers() throws {
        let source = try makeTempDirectory().appendingPathComponent("source", isDirectory: true)
        let target = try makeTempDirectory().appendingPathComponent("target", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        try writeJSON(
            """
            {
              // Claude Code project MCP files are JSONC in practice.
              "mcpServers": {
                "claude-docs": {
                  "command": "npx",
                  "args": ["-y", "@example/claude"]
                }
              }
            }
            """,
            to: source.appendingPathComponent(".mcp.json")
        )
        try FileManager.default.createDirectory(
            at: source.appendingPathComponent(".codex", isDirectory: true),
            withIntermediateDirectories: true
        )
        try """
        [mcp_servers."codex-db"]
        url = "https://example.com/codex/mcp"
        """.write(to: source.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)

        XCTAssertEqual(ProfileCopier.preview(from: source.path).mcp, 2)

        let result = ProfileCopier.copy(
            from: source.path,
            to: target.path,
            options: CopyOptions(skills: false, agents: false, mcpServers: true)
        )

        XCTAssertEqual(result.mcpCopied, 2)
        XCTAssertTrue(result.errors.isEmpty)
        let claude = try String(contentsOf: target.appendingPathComponent(".mcp.json"), encoding: .utf8)
        let codex = try String(contentsOf: target.appendingPathComponent(".codex/config.toml"), encoding: .utf8)
        XCTAssertTrue(claude.contains("\"claude-docs\""))
        XCTAssertTrue(claude.contains("\"mcpServers\""))
        XCTAssertTrue(codex.contains(#"[mcp_servers."codex-db"]"#))
    }

    func testProfileCopierRefusesInvalidDestinationMCPJson() throws {
        let source = try makeTempDirectory().appendingPathComponent("source", isDirectory: true)
        let target = try makeTempDirectory().appendingPathComponent("target", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        try writeJSON(
            #"{"mcpServers":{"claude-docs":{"command":"npx","args":["-y","@example/claude"]}}}"#,
            to: source.appendingPathComponent(".mcp.json")
        )
        let invalidTarget = target.appendingPathComponent(".mcp.json")
        try "{ invalid".write(to: invalidTarget, atomically: true, encoding: .utf8)

        let result = ProfileCopier.copy(
            from: source.path,
            to: target.path,
            options: CopyOptions(skills: false, agents: false, mcpServers: true)
        )

        XCTAssertEqual(result.mcpCopied, 0)
        XCTAssertTrue(result.errors.contains { $0.contains("Could not parse existing destination JSON") })
        XCTAssertEqual(try String(contentsOf: invalidTarget, encoding: .utf8), "{ invalid")
    }

    private func writeJSON(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubProjectMCPReaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
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
}
