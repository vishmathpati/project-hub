import XCTest
@testable import ProjectHub

final class ConfigWriterProjectScopeTests: XCTestCase {
    func testSingleServerReadFallsBackToDisabledJSONMap() throws {
        let root = try makeTempDirectory()
        try writeJSON(
            """
            {
              "mcpServers": {},
              "mcpServers_disabled": {
                "docs": {
                  "command": "npx",
                  "args": ["-y", "@example/docs"],
                  "env": { "DOCS_TOKEN": "${DOCS_TOKEN}" }
                }
              }
            }
            """,
            to: root.appendingPathComponent(".mcp.json")
        )

        let raw = try XCTUnwrap(ConfigWriter.readServer(
            toolID: "claude-code",
            scope: .project,
            projectRoot: root.path,
            name: "docs"
        ))

        XCTAssertEqual(raw["command"] as? String, "npx")
        XCTAssertEqual(raw["args"] as? [String], ["-y", "@example/docs"])
        XCTAssertEqual((raw["env"] as? [String: String])?["DOCS_TOKEN"], "${DOCS_TOKEN}")
    }

    func testSingleServerReadPreservesRawEnvSplitStringWrapper() throws {
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

        let raw = try XCTUnwrap(ConfigWriter.readServer(
            toolID: "vscode",
            scope: .project,
            projectRoot: root.path,
            name: "dockerized"
        ))

        XCTAssertEqual(raw["command"] as? String, "/usr/bin/env")
        XCTAssertEqual(raw["args"] as? [String], [
            "-S",
            "API_TOKEN docker run --env-file .env.mcp --env SERVICE_TOKEN ghcr.io/example/mcp:latest"
        ])
    }

    func testVSCodeSandboxDevMetadataIsOnlyWrittenBackToVSCodeTargets() throws {
        let root = try makeTempDirectory()
        let vscodeProject = root.appendingPathComponent("vscode-repo", isDirectory: true)
        let claudeProject = root.appendingPathComponent("claude-repo", isDirectory: true)
        let codexProject = root.appendingPathComponent("codex-repo", isDirectory: true)
        try FileManager.default.createDirectory(at: vscodeProject, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeProject, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexProject, withIntermediateDirectories: true)

        let config: [String: Any] = [
            "command": "npx",
            "args": ["-y", "@example/docs"],
            "sandboxEnabled": true,
            "sandbox": [
                "filesystem": ["allowWrite": ["${workspaceFolder}"]],
                "network": ["allowedDomains": ["api.example.com"]]
            ],
            "dev": [
                "watch": "src/**/*.ts",
                "debug": ["type": "node"]
            ]
        ]

        try ConfigWriter.writeServer(
            toolID: "vscode",
            scope: .project,
            projectRoot: vscodeProject.path,
            name: "docs",
            config: config
        )
        try ConfigWriter.writeServer(
            toolID: "claude-code",
            scope: .project,
            projectRoot: claudeProject.path,
            name: "docs",
            config: config
        )
        try ConfigWriter.writeServer(
            toolID: "codex",
            scope: .project,
            projectRoot: codexProject.path,
            name: "docs",
            config: config
        )

        let vscodeRaw = try String(contentsOf: vscodeProject.appendingPathComponent(".vscode/mcp.json"), encoding: .utf8)
        let claudeRaw = try String(contentsOf: claudeProject.appendingPathComponent(".mcp.json"), encoding: .utf8)
        let codexRaw = try String(contentsOf: codexProject.appendingPathComponent(".codex/config.toml"), encoding: .utf8)

        XCTAssertTrue(vscodeRaw.contains("sandboxEnabled"))
        XCTAssertTrue(vscodeRaw.contains("\"sandbox\""))
        XCTAssertTrue(vscodeRaw.contains("\"dev\""))
        XCTAssertFalse(claudeRaw.contains("sandboxEnabled"))
        XCTAssertFalse(claudeRaw.contains("\"sandbox\""))
        XCTAssertFalse(claudeRaw.contains("\"dev\""))
        XCTAssertFalse(codexRaw.contains("sandbox"))
        XCTAssertFalse(codexRaw.contains("dev"))
    }

    func testRooToolControlMetadataIsOnlyWrittenBackToRooTargets() throws {
        let root = try makeTempDirectory()
        let rooProject = root.appendingPathComponent("roo-repo", isDirectory: true)
        let claudeProject = root.appendingPathComponent("claude-repo", isDirectory: true)
        let codexProject = root.appendingPathComponent("codex-repo", isDirectory: true)
        try FileManager.default.createDirectory(at: rooProject, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeProject, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexProject, withIntermediateDirectories: true)

        let config: [String: Any] = [
            "command": "npx",
            "args": ["-y", "@example/docs"],
            "alwaysAllow": ["search"],
            "disabledTools": ["write"],
            "watchPaths": ["src/server.ts"],
            "timeout": 120,
            "disabled": true
        ]

        try ConfigWriter.writeServer(
            toolID: "roo",
            scope: .project,
            projectRoot: rooProject.path,
            name: "docs",
            config: config
        )
        try ConfigWriter.writeServer(
            toolID: "claude-code",
            scope: .project,
            projectRoot: claudeProject.path,
            name: "docs",
            config: config
        )
        try ConfigWriter.writeServer(
            toolID: "codex",
            scope: .project,
            projectRoot: codexProject.path,
            name: "docs",
            config: config
        )

        let rooRaw = try String(contentsOf: rooProject.appendingPathComponent(".roo/mcp.json"), encoding: .utf8)
        let claudeRaw = try String(contentsOf: claudeProject.appendingPathComponent(".mcp.json"), encoding: .utf8)
        let codexRaw = try String(contentsOf: codexProject.appendingPathComponent(".codex/config.toml"), encoding: .utf8)

        XCTAssertTrue(rooRaw.contains("alwaysAllow"))
        XCTAssertTrue(rooRaw.contains("disabledTools"))
        XCTAssertTrue(rooRaw.contains("watchPaths"))
        XCTAssertTrue(rooRaw.contains("timeout"))
        XCTAssertTrue(rooRaw.contains("\"disabled\" : true"))
        XCTAssertFalse(claudeRaw.contains("alwaysAllow"))
        XCTAssertFalse(claudeRaw.contains("disabledTools"))
        XCTAssertFalse(claudeRaw.contains("watchPaths"))
        XCTAssertFalse(claudeRaw.contains("timeout"))
        XCTAssertFalse(claudeRaw.contains("disabled"))
        XCTAssertFalse(codexRaw.contains("alwaysAllow"))
        XCTAssertFalse(codexRaw.contains("disabledTools"))
        XCTAssertFalse(codexRaw.contains("watchPaths"))
        XCTAssertFalse(codexRaw.contains("timeout"))
        XCTAssertFalse(codexRaw.contains("disabled"))
        XCTAssertTrue(codexRaw.contains("enabled = false"))

        let rooEntry = try XCTUnwrap(ConfigWriter.readAllServerEntries(
            toolID: "roo",
            scope: .project,
            projectRoot: rooProject.path
        ).first { $0.name == "docs" })
        XCTAssertTrue(rooEntry.isDisabled)
        XCTAssertEqual(rooEntry.alwaysAllowTools, ["search"])
        XCTAssertEqual(rooEntry.disabledTools, ["write"])
        XCTAssertEqual(rooEntry.watchPaths, ["src/server.ts"])
        XCTAssertEqual(rooEntry.serverTimeoutSeconds, 120)

        try ConfigWriter.setServerEnabled(
            toolID: "roo",
            scope: .project,
            projectRoot: rooProject.path,
            name: "docs",
            enabled: true
        )
        var rooJSON = try readJSON(rooProject.appendingPathComponent(".roo/mcp.json"))
        var rooServers = try XCTUnwrap(rooJSON["mcpServers"] as? [String: Any])
        var docs = try XCTUnwrap(rooServers["docs"] as? [String: Any])
        XCTAssertEqual(docs["disabled"] as? Bool, false)

        try ConfigWriter.setServerEnabled(
            toolID: "roo",
            scope: .project,
            projectRoot: rooProject.path,
            name: "docs",
            enabled: false
        )
        rooJSON = try readJSON(rooProject.appendingPathComponent(".roo/mcp.json"))
        rooServers = try XCTUnwrap(rooJSON["mcpServers"] as? [String: Any])
        docs = try XCTUnwrap(rooServers["docs"] as? [String: Any])
        XCTAssertEqual(docs["disabled"] as? Bool, true)
    }

    func testCodexProjectWritePreservesDirectToolControls() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("codex-repo", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        let config: [String: Any] = [
            "command": "npx",
            "args": ["-y", "@example/docs"],
            "enabledTools": ["search"],
            "disabledTools": ["write"],
            "defaultToolApprovalMode": "prompt",
            "toolApprovalModes": ["search": "approve"]
        ]

        try ConfigWriter.writeServer(
            toolID: "codex",
            scope: .project,
            projectRoot: project.path,
            name: "docs",
            config: config
        )

        let raw = try String(contentsOf: project.appendingPathComponent(".codex/config.toml"), encoding: .utf8)
        XCTAssertTrue(raw.contains(#"enabled_tools = ["search"]"#), raw)
        XCTAssertTrue(raw.contains(#"disabled_tools = ["write"]"#), raw)
        XCTAssertTrue(raw.contains(#"default_tools_approval_mode = "prompt""#), raw)
        XCTAssertTrue(raw.contains(#"tools.search.approval_mode = "approve""#), raw)

        let entry = try XCTUnwrap(ConfigWriter.readAllServerEntries(
            toolID: "codex",
            scope: .project,
            projectRoot: project.path
        ).first { $0.name == "docs" })
        XCTAssertEqual(entry.enabledTools, ["search"])
        XCTAssertEqual(entry.disabledTools, ["write"])
        XCTAssertEqual(entry.defaultToolApprovalMode, "prompt")
        XCTAssertEqual(entry.toolApprovalModes["search"], "approve")
    }

    func testCodexRemoteWritePreservesEnvFile() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("codex-repo", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        let config: [String: Any] = [
            "url": "https://mcp.example.com/mcp",
            "envFile": "${workspaceFolder}/.env.mcp",
            "headers": ["X-Token": "${REMOTE_TOKEN}"]
        ]

        try ConfigWriter.writeServer(
            toolID: "codex",
            scope: .project,
            projectRoot: project.path,
            name: "remote-docs",
            config: config
        )

        let raw = try String(contentsOf: project.appendingPathComponent(".codex/config.toml"), encoding: .utf8)
        XCTAssertTrue(raw.contains(#"url = "https://mcp.example.com/mcp""#), raw)
        XCTAssertTrue(raw.contains(#"env_file = "${workspaceFolder}/.env.mcp""#), raw)

        let entry = try XCTUnwrap(ConfigWriter.readAllServerEntries(
            toolID: "codex",
            scope: .project,
            projectRoot: project.path
        ).first { $0.name == "remote-docs" })
        XCTAssertEqual(entry.envFile, "${workspaceFolder}/.env.mcp")
    }

    func testProjectInventoryIgnoresPlaceholderOnlyOAuthMetadata() throws {
        let root = try makeTempDirectory()
        try writeJSON(
            """
            {
              "mcpServers": {
                "placeholder": {
                  "url": "https://mcp.supabase.com/mcp",
                  "oauth": {
                    "clientId": "your-client-id",
                    "authServerMetadataUrl": "..."
                  }
                },
                "configured": {
                  "url": "https://mcp.example.com/mcp",
                  "oauth": {
                    "clientId": "projecthub-client",
                    "authServerMetadataUrl": "https://example.com/.well-known/oauth-authorization-server",
                    "callbackPort": 8080,
                    "scopes": "read write"
                  }
                }
              }
            }
            """,
            to: root.appendingPathComponent(".mcp.json")
        )

        let entries = ConfigWriter.readAllServerEntries(
            toolID: "claude-code",
            scope: .project,
            projectRoot: root.path
        )
        let placeholder = entries.first { $0.name == "placeholder" }
        let configured = entries.first { $0.name == "configured" }

        XCTAssertEqual(placeholder?.oauth, [:])
        XCTAssertEqual(configured?.oauth["clientId"], "projecthub-client")
        XCTAssertEqual(configured?.oauth["authServerMetadataUrl"], "https://example.com/.well-known/oauth-authorization-server")
        XCTAssertEqual(configured?.oauth["callbackPort"], "8080")
        XCTAssertEqual(configured?.oauth["scopes"], "read write")
    }

    func testCodexRemoteAuthIsNormalizedWhenWritingClaudeProjectJSON() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try """
        [mcp_servers.supabase]
        type = "streamable-http"
        url = "https://mcp.supabase.com/mcp"
        bearer_token_env_var = "SUPABASE_ACCESS_TOKEN"
        http_headers = { "X-Static" = "yes" }
        env_http_headers = { "X-Env" = "SUPABASE_PROJECT_REF" }
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let config = try XCTUnwrap(ConfigWriter.readServer(toolID: "codex", name: "supabase"))
            XCTAssertEqual(config["bearer_token_env_var"] as? String, "SUPABASE_ACCESS_TOKEN")

            let preview = try XCTUnwrap(ConfigWriter.previewWrite(
                toolID: "claude-code",
                scope: .project,
                projectRoot: project.path,
                name: "supabase",
                config: config
            ))
            XCTAssertTrue(preview.after.contains("\"headers\""))
            XCTAssertTrue(preview.after.contains("\"Authorization\" : \"Bearer ${SUPABASE_ACCESS_TOKEN}\""))
            XCTAssertTrue(preview.after.contains("\"X-Static\" : \"yes\""))
            XCTAssertTrue(preview.after.contains("\"X-Env\" : \"${SUPABASE_PROJECT_REF}\""))
            XCTAssertFalse(preview.after.contains("bearer_token_env_var"))
            XCTAssertFalse(preview.after.contains("http_headers"))
            XCTAssertFalse(preview.after.contains("env_http_headers"))

            try ConfigWriter.writeServer(
                toolID: "claude-code",
                scope: .project,
                projectRoot: project.path,
                name: "supabase",
                config: config
            )

            let written = try readJSON(project.appendingPathComponent(".mcp.json"))
            let servers = try XCTUnwrap(written["mcpServers"] as? [String: Any])
            let supabase = try XCTUnwrap(servers["supabase"] as? [String: Any])
            let headers = try XCTUnwrap(supabase["headers"] as? [String: String])
            XCTAssertEqual(supabase["type"] as? String, "streamable-http")
            XCTAssertEqual(supabase["url"] as? String, "https://mcp.supabase.com/mcp")
            XCTAssertEqual(headers["Authorization"], "Bearer ${SUPABASE_ACCESS_TOKEN}")
            XCTAssertEqual(headers["X-Static"], "yes")
            XCTAssertEqual(headers["X-Env"], "${SUPABASE_PROJECT_REF}")
            XCTAssertNil(supabase["bearer_token_env_var"])
            XCTAssertNil(supabase["http_headers"])
            XCTAssertNil(supabase["env_http_headers"])
        }
    }

    func testCodexRemoteAuthKeepsCodexShapeWhenWritingCodexTOML() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        [mcp_servers.supabase]
        url = "https://mcp.supabase.com/mcp"
        bearer_token_env_var = "SUPABASE_ACCESS_TOKEN"
        http_headers = { "X-Static" = "yes" }
        env_http_headers = { "X-Env" = "SUPABASE_PROJECT_REF" }
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let config = try XCTUnwrap(ConfigWriter.readServer(toolID: "codex", name: "supabase"))
            try ConfigWriter.writeServer(
                toolID: "codex",
                scope: .project,
                projectRoot: project.path,
                name: "supabase",
                config: config
            )
        }

        let raw = try String(contentsOf: project.appendingPathComponent(".codex/config.toml"), encoding: .utf8)
        XCTAssertTrue(raw.contains("bearer_token_env_var = \"SUPABASE_ACCESS_TOKEN\""))
        XCTAssertTrue(raw.contains("http_headers = { X-Static = \"yes\" }"))
        XCTAssertTrue(raw.contains("env_http_headers = { X-Env = \"SUPABASE_PROJECT_REF\" }"))
        XCTAssertFalse(raw.contains("\nheaders = {"))
    }

    func testClaudeBearerHeaderEnvTemplateBecomesCodexBearerTokenEnvVar() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        let config: [String: Any] = [
            "type": "http",
            "url": "https://mcp.supabase.com/mcp",
            "headers": [
                "Authorization": "Bearer ${SUPABASE_ACCESS_TOKEN}",
                "X-Static": "yes"
            ]
        ]

        let preview = try XCTUnwrap(ConfigWriter.previewWrite(
            toolID: "codex",
            scope: .project,
            projectRoot: project.path,
            name: "supabase",
            config: config
        ))
        XCTAssertTrue(preview.after.contains("bearer_token_env_var = \"SUPABASE_ACCESS_TOKEN\""))
        XCTAssertTrue(preview.after.contains("http_headers = { X-Static = \"yes\" }"))
        XCTAssertFalse(preview.after.contains("Authorization = \"Bearer ${SUPABASE_ACCESS_TOKEN}\""))

        try ConfigWriter.writeServer(
            toolID: "codex",
            scope: .project,
            projectRoot: project.path,
            name: "supabase",
            config: config
        )

        let raw = try String(contentsOf: project.appendingPathComponent(".codex/config.toml"), encoding: .utf8)
        XCTAssertTrue(raw.contains("bearer_token_env_var = \"SUPABASE_ACCESS_TOKEN\""))
        XCTAssertTrue(raw.contains("http_headers = { X-Static = \"yes\" }"))
        XCTAssertFalse(raw.contains("Authorization = \"Bearer ${SUPABASE_ACCESS_TOKEN}\""))
    }

    func testClaudeCodeWorkspaceMCPNameIsRejectedBeforeWrite() throws {
        let root = try makeTempDirectory()
        let config: [String: Any] = [
            "type": "http",
            "url": "https://example.invalid/mcp"
        ]

        XCTAssertNil(ConfigWriter.previewWrite(
            toolID: "claude-code",
            scope: .project,
            projectRoot: root.path,
            name: "workspace",
            config: config
        ))
        XCTAssertNil(ConfigWriter.previewWriteBatch(
            toolID: "claude-code",
            scope: .project,
            projectRoot: root.path,
            servers: [(name: "workspace", config: config)]
        ))
        XCTAssertEqual(
            ConfigWriter.nativeWriteBlocker(toolID: "claude-code", scope: .project, name: "workspace"),
            "Claude Code reserves the MCP server name \"workspace\" and skips it at load time. Rename this server before writing it to Claude Code."
        )
        XCTAssertThrowsError(try ConfigWriter.writeServer(
            toolID: "claude-code",
            scope: .project,
            projectRoot: root.path,
            name: "workspace",
            config: config
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("reserves the MCP server name \"workspace\""))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".mcp.json").path))
    }

    func testCodexWorkspaceMCPNameCanStillBeWritten() throws {
        let root = try makeTempDirectory()
        let path = root.appendingPathComponent(".codex/config.toml")
        let config: [String: Any] = [
            "command": "npx",
            "args": ["-y", "@example/workspace-mcp"]
        ]

        XCTAssertNil(ConfigWriter.nativeWriteBlocker(toolID: "codex", scope: .project, name: "workspace"))
        XCTAssertNotNil(ConfigWriter.previewWrite(
            toolID: "codex",
            scope: .project,
            projectRoot: root.path,
            name: "workspace",
            config: config
        ))
        try ConfigWriter.writeServer(
            toolID: "codex",
            scope: .project,
            projectRoot: root.path,
            name: "workspace",
            config: config
        )

        let raw = try String(contentsOf: path, encoding: .utf8)
        XCTAssertTrue(raw.contains("[mcp_servers.workspace]"))
        XCTAssertTrue(ConfigWriter.readAllServerEntries(
            toolID: "codex",
            scope: .project,
            projectRoot: root.path
        ).contains { $0.name == "workspace" && $0.command == "npx" })
    }

    func testClaudeDesktopRemoteMCPIsRejectedBeforeWrite() {
        let config: [String: Any] = [
            "type": "http",
            "url": "https://mcp.example.com/mcp"
        ]

        XCTAssertNil(ConfigWriter.previewWrite(
            toolID: "claude-desktop",
            scope: .user,
            projectRoot: nil,
            name: "remote",
            config: config
        ))
        XCTAssertNil(ConfigWriter.previewWriteBatch(
            toolID: "claude-desktop",
            scope: .user,
            projectRoot: nil,
            servers: [(name: "remote", config: config)]
        ))
        XCTAssertEqual(
            ConfigWriter.nativeWriteBlocker(toolID: "claude-desktop", scope: .user, name: "remote", config: config),
            "Claude Desktop remote MCP servers must be added through Settings > Connectors. Project Hub will not write hosted/remote MCP URLs into claude_desktop_config.json."
        )
        XCTAssertThrowsError(try ConfigWriter.writeServer(
            toolID: "claude-desktop",
            scope: .user,
            projectRoot: nil,
            name: "remote",
            config: config
        ))
    }

    func testClaudeDesktopStdioMCPIsNotConnectorBlocked() {
        let config: [String: Any] = [
            "command": "/bin/echo",
            "args": []
        ]

        XCTAssertNil(ConfigWriter.nativeWriteBlocker(toolID: "claude-desktop", scope: .user, name: "stdio", config: config))
    }

    func testProjectJSONServerToggleMovesBetweenActiveAndDisabledMaps() throws {
        let tools = [
            (toolID: "claude-code", path: ".mcp.json", key: "mcpServers"),
            (toolID: "cursor", path: ".cursor/mcp.json", key: "mcpServers"),
            (toolID: "vscode", path: ".vscode/mcp.json", key: "servers"),
            (toolID: "roo", path: ".roo/mcp.json", key: "mcpServers")
        ]

        for tool in tools {
            let root = try makeTempDirectory()
            try writeJSON(
                """
                {
                  "\(tool.key)": {
                    "docs": { "command": "npx", "args": ["-y", "@example/docs"] }
                  }
                }
                """,
                to: root.appendingPathComponent(tool.path)
            )

            try ConfigWriter.setServerEnabled(
                toolID: tool.toolID,
                scope: .project,
                projectRoot: root.path,
                name: "docs",
                enabled: false
            )

            var entries = ConfigWriter.readAllServerEntries(
                toolID: tool.toolID,
                scope: .project,
                projectRoot: root.path
            )
            XCTAssertTrue(
                entries.contains { $0.name == "docs" && $0.isDisabled },
                "\(tool.toolID) should disable docs"
            )

            try ConfigWriter.setServerEnabled(
                toolID: tool.toolID,
                scope: .project,
                projectRoot: root.path,
                name: "docs",
                enabled: true
            )

            entries = ConfigWriter.readAllServerEntries(
                toolID: tool.toolID,
                scope: .project,
                projectRoot: root.path
            )
            XCTAssertTrue(
                entries.contains { $0.name == "docs" && !$0.isDisabled },
                "\(tool.toolID) should re-enable docs"
            )
        }
    }

    func testVSCodeProjectInventoryPreservesEnvFile() throws {
        let root = try makeTempDirectory()
        try writeJSON(
            """
            {
              "inputs": [
                { "type": "promptString", "id": "token", "password": true }
              ],
              "servers": {
                "docs": {
                  "command": "npx",
                  "args": ["-y", "@example/docs"],
                  "cwd": "${workspaceFolder}/tools",
                  "envFile": "${workspaceFolder}/.env",
                  "sandboxEnabled": true,
                  "sandbox": {
                    "filesystem": { "allowWrite": ["${workspaceFolder}"] },
                    "network": { "allowedDomains": ["api.example.com"] }
                  },
                  "dev": {
                    "watch": "src/**/*.ts",
                    "debug": { "type": "node" }
                  }
                }
              }
            }
            """,
            to: root.appendingPathComponent(".vscode/mcp.json")
        )

        let server = try XCTUnwrap(ConfigWriter.readAllServerEntries(
            toolID: "vscode",
            scope: .project,
            projectRoot: root.path
        ).first { $0.name == "docs" })

        XCTAssertEqual(server.envFile, "${workspaceFolder}/.env")
        XCTAssertEqual(server.cwd, "${workspaceFolder}/tools")
        XCTAssertEqual(server.sandboxEnabled, true)
        XCTAssertEqual(server.sandboxSummary, "{filesystem, network}")
        XCTAssertEqual(server.devSummary, "{debug, watch}")
    }

    func testProjectCodexServerToggleWritesEnabledFalseAndRemovesItOnEnable() throws {
        let root = try makeTempDirectory()
        let path = root.appendingPathComponent(".codex/config.toml")
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        [mcp_servers.docs]
        command = "npx"
        args = ["-y", "@example/docs"]

        """.write(to: path, atomically: true, encoding: .utf8)

        try ConfigWriter.setServerEnabled(
            toolID: "codex",
            scope: .project,
            projectRoot: root.path,
            name: "docs",
            enabled: false
        )

        var raw = try String(contentsOf: path, encoding: .utf8)
        XCTAssertTrue(raw.contains("enabled = false"))
        XCTAssertTrue(ConfigWriter.readAllServerEntries(
            toolID: "codex",
            scope: .project,
            projectRoot: root.path
        ).contains { $0.name == "docs" && $0.isDisabled })

        try ConfigWriter.setServerEnabled(
            toolID: "codex",
            scope: .project,
            projectRoot: root.path,
            name: "docs",
            enabled: true
        )

        raw = try String(contentsOf: path, encoding: .utf8)
        XCTAssertFalse(raw.contains("enabled = false"))
        XCTAssertTrue(ConfigWriter.readAllServerEntries(
            toolID: "codex",
            scope: .project,
            projectRoot: root.path
        ).contains { $0.name == "docs" && !$0.isDisabled })
    }

    func testProjectCodexQuotedDottedServerTogglePreservesQuotedSectionHeader() throws {
        let root = try makeTempDirectory()
        let path = root.appendingPathComponent(".codex/config.toml")
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        [mcp_servers.'github.docs']
        command = "npx"
        args = ["-y", "@modelcontextprotocol/server-github"]

        [mcp_servers.'github.docs'.env]
        GITHUB_TOKEN = "${GITHUB_TOKEN}"
        """.write(to: path, atomically: true, encoding: .utf8)

        let preview = try XCTUnwrap(ConfigWriter.previewSetServerEnabled(
            toolID: "codex",
            scope: .project,
            projectRoot: root.path,
            name: "github.docs",
            enabled: false
        ))
        XCTAssertTrue(preview.after.contains("[mcp_servers.'github.docs']"))
        XCTAssertTrue(preview.after.contains("[mcp_servers.'github.docs'.env]"))
        XCTAssertFalse(preview.after.contains("env = {"))
        XCTAssertEqual(preview.after.components(separatedBy: "[mcp_servers.").count - 1, 2)

        try ConfigWriter.setServerEnabled(
            toolID: "codex",
            scope: .project,
            projectRoot: root.path,
            name: "github.docs",
            enabled: false
        )

        var raw = try String(contentsOf: path, encoding: .utf8)
        XCTAssertTrue(raw.contains("[mcp_servers.'github.docs']"))
        XCTAssertTrue(raw.contains("enabled = false"))
        XCTAssertTrue(raw.contains("[mcp_servers.'github.docs'.env]"))
        XCTAssertFalse(raw.contains("env = {"))
        XCTAssertFalse(raw.contains("[mcp_servers.github.docs]"))
        XCTAssertEqual(raw.components(separatedBy: "[mcp_servers.").count - 1, 2)
        XCTAssertTrue(ConfigWriter.readAllServerEntries(
            toolID: "codex",
            scope: .project,
            projectRoot: root.path
        ).contains { $0.name == "github.docs" && $0.isDisabled })

        try ConfigWriter.setServerEnabled(
            toolID: "codex",
            scope: .project,
            projectRoot: root.path,
            name: "github.docs",
            enabled: true
        )

        raw = try String(contentsOf: path, encoding: .utf8)
        XCTAssertFalse(raw.contains("enabled = false"))
        XCTAssertTrue(raw.contains("[mcp_servers.'github.docs']"))
        XCTAssertTrue(raw.contains("[mcp_servers.'github.docs'.env]"))
        XCTAssertFalse(raw.contains("env = {"))
        XCTAssertEqual(raw.components(separatedBy: "[mcp_servers.").count - 1, 2)
    }

    func testProjectCodexServerEntriesNormalizeHTTPHeadersAndEnvHTTPHeaders() throws {
        let root = try makeTempDirectory()
        let path = root.appendingPathComponent(".codex/config.toml")
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        [mcp_servers.'github.docs']
        type = "streamable-http"
        url = "https://example.com/mcp"
        http_headers = { "X-Static" = "static-value" } # keep static header
        env_http_headers.Authorization = "GITHUB_TOKEN" # token comes from env
        bearer_token_env_var = "GITHUB_PAT"
        startup_timeout_sec = 12
        tool_timeout_sec = 34

        [mcp_servers.'github.docs'.env_http_headers]
        "X-Project" = "OPENAI_PROJECT"

        [mcp_servers.other]
        url = "https://example.com/other"
        """.write(to: path, atomically: true, encoding: .utf8)

        let entries = ConfigWriter.readAllServerEntries(
            toolID: "codex",
            scope: .project,
            projectRoot: root.path
        )
        let docs = try XCTUnwrap(entries.first { $0.name == "github.docs" })

        XCTAssertEqual(entries.map(\.name), ["github.docs", "other"])
        XCTAssertEqual(docs.transport, "streamable-http")
        XCTAssertEqual(docs.url, "https://example.com/mcp")
        XCTAssertEqual(docs.headers["X-Static"], "static-value")
        XCTAssertEqual(docs.headers["Authorization"], "${GITHUB_TOKEN}")
        XCTAssertEqual(docs.headers["X-Project"], "${OPENAI_PROJECT}")
        XCTAssertEqual(docs.bearerTokenEnvVar, "GITHUB_PAT")
        XCTAssertEqual(docs.startupTimeoutSeconds, 12)
        XCTAssertEqual(docs.toolTimeoutSeconds, 34)
    }

    func testProjectCodexServerEntriesParseQuotedRootAndFilterRemoteEnvVars() throws {
        let root = try makeTempDirectory()
        let path = root.appendingPathComponent(".codex/config.toml")
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        ["mcp_servers"."github.docs"]
        command = "npx"
        args = ["-y", "@example/docs"]
        env_vars = ["LOCAL_TOKEN", { name = "REMOTE_TOKEN", source = "remote" }, { name = "LOCAL_OBJECT_TOKEN", source = "local" }]
        """.write(to: path, atomically: true, encoding: .utf8)

        let docs = try XCTUnwrap(ConfigWriter.readAllServerEntries(
            toolID: "codex",
            scope: .project,
            projectRoot: root.path
        ).first { $0.name == "github.docs" })

        XCTAssertEqual(docs.command, "npx")
        XCTAssertEqual(docs.args, ["-y", "@example/docs"])
        XCTAssertEqual(docs.envVars, ["LOCAL_TOKEN", "LOCAL_OBJECT_TOKEN"])
    }

    func testProjectCodexQuotedDottedServerRemoveDeletesParentAndNestedSubtables() throws {
        let root = try makeTempDirectory()
        let path = root.appendingPathComponent(".codex/config.toml")
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        [mcp_servers.'github.docs']
        command = "npx"

        [mcp_servers.'github.docs'.env]
        GITHUB_TOKEN = "${GITHUB_TOKEN}"

        [mcp_servers.other]
        command = "uvx"
        """.write(to: path, atomically: true, encoding: .utf8)

        try ConfigWriter.removeServer(
            toolID: "codex",
            scope: .project,
            projectRoot: root.path,
            name: "github.docs"
        )

        let raw = try String(contentsOf: path, encoding: .utf8)
        XCTAssertFalse(raw.contains("github.docs"))
        XCTAssertTrue(raw.contains("[mcp_servers.other]\ncommand = \"uvx\""))
        XCTAssertEqual(
            ConfigWriter.readAllServerEntries(
                toolID: "codex",
                scope: .project,
                projectRoot: root.path
            ).map(\.name),
            ["other"]
        )
    }

    func testClaudeApprovalDisabledServerCanBeClearedWithoutMovingActiveConfig() throws {
        let root = try makeTempDirectory()
        let path = root.appendingPathComponent(".mcp.json")
        try writeJSON(
            """
            {
              "mcpServers": {
                "docs": { "command": "npx", "args": ["-y", "@example/docs"] }
              },
              "disabledMcpjsonServers": ["docs"]
            }
            """,
            to: path
        )

        try ConfigWriter.resolveClaudeMCPApprovalConflict(path: path.path, serverNames: ["docs"])

        let raw = try String(contentsOf: path, encoding: .utf8)
        XCTAssertTrue(raw.contains("\"docs\""))
        XCTAssertFalse(raw.contains("disabledMcpjsonServers\": [\n    \"docs\""))
        XCTAssertTrue(MCPReader.disabledClaudeCodeServerNames(projectPath: root.path).isEmpty)
        XCTAssertTrue(ConfigWriter.readAllServerEntries(
            toolID: "claude-code",
            scope: .project,
            projectRoot: root.path
        ).contains { $0.name == "docs" && !$0.isDisabled })
    }

    func testClaudeCodeUserScopeIsCliOnlyForWrites() {
        let config: [String: Any] = [
            "command": "npx",
            "args": ["-y", "@example/docs"]
        ]

        XCTAssertNil(ConfigWriter.previewWrite(
            toolID: "claude-code",
            scope: .user,
            projectRoot: nil,
            name: "docs",
            config: config
        ))
        XCTAssertEqual(
            ConfigWriter.nativeWriteBlocker(toolID: "claude-code", scope: .user, name: "docs", config: config),
            "Claude Code global MCP lives in private ~/.claude.json state. Use the Claude CLI for global MCP, or choose Project scope to write the team-shared .mcp.json."
        )
        XCTAssertThrowsError(try ConfigWriter.writeServer(
            toolID: "claude-code",
            scope: .user,
            projectRoot: nil,
            name: "docs",
            config: config
        ))
    }

    func testToolSpecsUseClaudePathOverrides() throws {
        let root = try makeTempDirectory()
        let claudeJSONPath = root.appendingPathComponent("custom-claude.json").path
        let desktopSupport = root.appendingPathComponent("ClaudeSupport", isDirectory: true).path

        withEnvironment("PROJECTHUB_CLAUDE_JSON_PATH", claudeJSONPath) {
            XCTAssertEqual(ToolSpecs.spec(for: "claude-code")?.path, claudeJSONPath)
        }
        withEnvironment("PROJECTHUB_CLAUDE_DESKTOP_SUPPORT_DIR", desktopSupport) {
            XCTAssertEqual(
                ToolSpecs.spec(for: "claude-desktop")?.path,
                (desktopSupport as NSString).appendingPathComponent("claude_desktop_config.json")
            )
        }
    }

    func testCodexHomePathIsTrimmedTildeExpandedAndSharedByToolSpecs() throws {
        let defaultCodexHome = (FileManager.default.homeDirectoryForCurrentUser.path as NSString)
            .appendingPathComponent(".codex")
        withEnvironment("CODEX_HOME", "   ") {
            XCTAssertEqual(ProjectHubPaths.codexHome(), defaultCodexHome)
            XCTAssertEqual(
                ToolSpecs.spec(for: "codex")?.path,
                (defaultCodexHome as NSString).appendingPathComponent("config.toml")
            )
        }

        let folder = ".projecthub-codex-home-\(UUID().uuidString)"
        let expanded = (FileManager.default.homeDirectoryForCurrentUser.path as NSString)
            .appendingPathComponent(folder)
        addTeardownBlock {
            try? FileManager.default.removeItem(atPath: expanded)
        }
        withEnvironment("CODEX_HOME", "~/\(folder)") {
            XCTAssertEqual(ProjectHubPaths.codexHome(), expanded)
            XCTAssertEqual(
                ToolSpecs.spec(for: "codex")?.path,
                (expanded as NSString).appendingPathComponent("config.toml")
            )
        }
    }

    private func writeJSON(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func readJSON(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func withCodexHome(_ path: String, run: () throws -> Void) rethrows {
        let previous = getenv("CODEX_HOME").map { String(cString: $0) }
        setenv("CODEX_HOME", path, 1)
        defer {
            if let previous {
                setenv("CODEX_HOME", previous, 1)
            } else {
                unsetenv("CODEX_HOME")
            }
        }
        try run()
    }

    private func withEnvironment(_ key: String, _ value: String, run: () -> Void) {
        let previous = getenv(key).map { String(cString: $0) }
        setenv(key, value, 1)
        defer {
            if let previous {
                setenv(key, previous, 1)
            } else {
                unsetenv(key)
            }
        }
        run()
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubConfigWriterProjectScopeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
