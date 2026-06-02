import XCTest
@testable import ProjectHub

final class FullConfigReaderTests: XCTestCase {
    func testCodexTOMLMCPReaderKeepsNestedEnvAndHeaderSectionsWithParentServer() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try """
        [mcp_servers.supabasesnapfinder] # Supabase-style hosted MCP
        url = "https://mcp.supabase.com/mcp?project_ref=jpnnqtjgvrhkvivzbzgl"
        bearer_token_env_var = "SUPABASE_ACCESS_TOKEN"
        enabled = false # temporarily disabled during auth setup
        startup_timeout_sec = 12.5
        tool_timeout_sec = 70
        headers = { "X-Static" = "legacy" }
        http_headers = { "X-Static" = "yes,please" }
        env_http_headers."X-Extra-Token" = "EXTRA_TOKEN"

        [mcp_servers.supabasesnapfinder.env_http_headers]
        Authorization = "SUPABASE_ACCESS_TOKEN"
        "X-Project-Ref" = "SNAPFINDER_PROJECT_REF"

        [mcp_servers.context7]
        command = "npx"
        startup_timeout_ms = 1500
        args = [
          "-y",
          "@upstash/context7-mcp",
          "--label=a,b",
          "--filter=\\\"alpha,beta\\\"",
        ] # quoted commas should stay inside their arguments
        env_vars = [
          "CONTEXT7_API_KEY",
          { name = "REMOTE_CONTEXT", source = "remote" },
        ] # Codex remote env var should not be required locally
        env.EXTRA_CONTEXT = "${EXTRA_CONTEXT}"

        [mcp_servers.context7.env]
        CONTEXT7_API_KEY = "${CONTEXT7_API_KEY}" # local expansion

        [mcp_servers.'github.docs']
        command = 'npx'
        args = ["-y", "@modelcontextprotocol/server-github"]
        enabled = false
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let codex = ConfigReader.shared.readAllTools().first { $0.toolID == "codex" }
            let servers = codex?.servers ?? []
            let names = Set(servers.map(\.name))
            let supabase = servers.first { $0.name == "supabasesnapfinder" }
            let context7 = servers.first { $0.name == "context7" }
            let githubDocs = servers.first { $0.name == "github.docs" }

            XCTAssertEqual(names, ["context7", "github.docs", "supabasesnapfinder"])
            XCTAssertEqual(supabase?.transport, "http")
            XCTAssertEqual(supabase?.url, "https://mcp.supabase.com/mcp?project_ref=jpnnqtjgvrhkvivzbzgl")
            XCTAssertEqual(supabase?.bearerTokenEnvVar, "SUPABASE_ACCESS_TOKEN")
            XCTAssertEqual(supabase?.headers["X-Static"], "yes,please")
            XCTAssertEqual(supabase?.headers["Authorization"], "${SUPABASE_ACCESS_TOKEN}")
            XCTAssertEqual(supabase?.headers["X-Project-Ref"], "${SNAPFINDER_PROJECT_REF}")
            XCTAssertEqual(supabase?.headers["X-Extra-Token"], "${EXTRA_TOKEN}")
            XCTAssertEqual(supabase?.isDisabled, true)
            XCTAssertEqual(supabase?.startupTimeoutSeconds, 12.5)
            XCTAssertEqual(supabase?.toolTimeoutSeconds, 70)
            XCTAssertEqual(context7?.transport, "stdio")
            XCTAssertEqual(context7?.command, "npx")
            XCTAssertEqual(context7?.args, ["-y", "@upstash/context7-mcp", "--label=a,b", "--filter=\\\"alpha,beta\\\""])
            XCTAssertEqual(context7?.env["CONTEXT7_API_KEY"], "${CONTEXT7_API_KEY}")
            XCTAssertEqual(context7?.env["EXTRA_CONTEXT"], "${EXTRA_CONTEXT}")
            XCTAssertEqual(context7?.envVars, ["CONTEXT7_API_KEY"])
            XCTAssertEqual(context7?.startupTimeoutSeconds, 1.5)
            XCTAssertNil(context7?.toolTimeoutSeconds)
            XCTAssertEqual(githubDocs?.command, "npx")
            XCTAssertEqual(githubDocs?.args, ["-y", "@modelcontextprotocol/server-github"])
            XCTAssertEqual(githubDocs?.isDisabled, true)
        }
    }

    func testCodexTOMLMCPReaderPreservesDirectToolControls() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try """
        [mcp_servers.docs]
        command = "npx"
        args = ["-y", "@example/docs"]
        enabled_tools = ["search"]
        disabled_tools = ["write"]
        default_tools_approval_mode = "prompt"

        [mcp_servers.docs.tools.search]
        approval_mode = "approve"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let server = ConfigReader.shared.readAllTools()
                .first { $0.toolID == "codex" }?
                .servers
                .first { $0.name == "docs" }

            XCTAssertEqual(server?.enabledTools, ["search"])
            XCTAssertEqual(server?.disabledTools, ["write"])
            XCTAssertEqual(server?.defaultToolApprovalMode, "prompt")
            XCTAssertEqual(server?.toolApprovalModes["search"], "approve")
            XCTAssertEqual(server?.detail, "npx -y @example/docs (enabled tools: 1) (disabled tools: 1) (approval: prompt) (tool approvals: 1)")
        }
    }

    func testCodexInventoryUnwrapsEnvSplitStringWrapper() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try """
        [mcp_servers.dockerized]
        command = "/usr/bin/env"
        args = ["-S", "API_TOKEN docker run --env-file .env.mcp --env SERVICE_TOKEN ghcr.io/example/mcp:latest"]
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let server = ConfigReader.shared.readAllTools()
                .first { $0.toolID == "codex" }?
                .servers
                .first { $0.name == "dockerized" }

            XCTAssertEqual(server?.command, "docker")
            XCTAssertEqual(server?.args, ["run", "--env-file", ".env.mcp", "--env", "SERVICE_TOKEN", "ghcr.io/example/mcp:latest"])
            XCTAssertEqual(server?.env["API_TOKEN"], "${API_TOKEN}")
            XCTAssertEqual(server?.env["SERVICE_TOKEN"], "${SERVICE_TOKEN}")
            XCTAssertEqual(server?.envFile, ".env.mcp")
        }
    }

    func testCodexTOMLMCPReaderParsesQuotedRootMCPServerSections() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try """
        ["mcp_servers"."github.docs"]
        command = "npx"
        args = ["-y", "@example/docs"]
        enabled = false

        ["mcp_servers"."github.docs"."env_http_headers"]
        Authorization = "GITHUB_TOKEN"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let server = try XCTUnwrap(ConfigReader.shared.readAllTools()
                .first { $0.toolID == "codex" }?
                .servers
                .first { $0.name == "github.docs" })

            XCTAssertEqual(server.command, "npx")
            XCTAssertEqual(server.args, ["-y", "@example/docs"])
            XCTAssertEqual(server.headers["Authorization"], "${GITHUB_TOKEN}")
            XCTAssertTrue(server.isDisabled)
        }
    }

    func testCodexGlobalInventoryIncludesConfiguredPluginMCPServersAsReadOnly() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)

        let enabledPlugin = try writeCodexPlugin(
            codexHome: codexHome,
            pluginID: "computer-use@openai-bundled",
            version: "1.0.799",
            mcpJSON: """
            {
              "mcpServers": {
                "computer-use": {
                  "command": "./Codex Computer Use.app/Contents/MacOS/ComputerUse",
                  "args": ["mcp"],
                  "cwd": "."
                }
              }
            }
            """
        )
        let disabledPlugin = try writeCodexPlugin(
            codexHome: codexHome,
            pluginID: "cloudflare@openai-curated",
            version: "6188456f",
            mcpJSON: """
            {
              "mcpServers": {
                "cloudflare-api": {
                  "type": "http",
                  "url": "https://mcp.cloudflare.com/mcp",
                  "headersHelper": "/opt/bin/cloudflare-mcp-headers"
                }
              }
            }
            """
        )
        _ = try writeCodexPlugin(
            codexHome: codexHome,
            pluginID: "vercel-plugin@vercel",
            version: "8db97f0c",
            mcpJSON: """
            {
              "mcpServers": {
                "vercel": {
                  "type": "http",
                  "url": "https://mcp.vercel.com"
                }
              }
            }
            """
        )

        try """
        [mcp_servers.direct]
        command = "npx"
        args = ["direct-mcp"]

        [plugins."computer-use@openai-bundled"]
        enabled = true

        [plugins."cloudflare@openai-curated"]
        enabled = false
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let codex = ConfigReader.shared.readAllTools().first { $0.toolID == "codex" }
            let servers = codex?.servers ?? []
            let names = Set(servers.map(\.name))
            let computerUse = servers.first { $0.name == "computer-use" }
            let cloudflare = servers.first { $0.name == "cloudflare-api" }

            XCTAssertEqual(names, ["cloudflare-api", "computer-use", "direct"])
            XCTAssertEqual(computerUse?.sourcePath, enabledPlugin.appendingPathComponent(".mcp.json").path)
            XCTAssertEqual(computerUse?.sourceLabel, "Codex plugin: computer-use@openai-bundled")
            XCTAssertEqual(computerUse?.isReadOnly, true)
            XCTAssertEqual(computerUse?.codexPluginID, "computer-use@openai-bundled")
            XCTAssertEqual(computerUse?.codexPluginPolicyConfigPath, codexHome.appendingPathComponent("config.toml").path)
            XCTAssertNil(computerUse?.codexPluginPolicyProfileName)
            XCTAssertEqual(computerUse?.codexPluginEnabled, true)
            XCTAssertEqual(computerUse?.canToggleCodexPluginPolicy, true)
            XCTAssertEqual(
                computerUse?.readOnlyReason,
                "Bundled by Codex plugin computer-use@openai-bundled. This inventory row is read-only because it points into installed plugin files; manage enablement from Codex plugin policy or reinstall/update the plugin."
            )
            XCTAssertEqual(computerUse?.isDisabled, false)
            XCTAssertEqual(
                computerUse?.command,
                enabledPlugin.appendingPathComponent("Codex Computer Use.app/Contents/MacOS/ComputerUse").path
            )
            XCTAssertEqual(computerUse?.cwd, enabledPlugin.path)
            XCTAssertEqual(cloudflare?.sourcePath, disabledPlugin.appendingPathComponent(".mcp.json").path)
            XCTAssertEqual(cloudflare?.isReadOnly, true)
            XCTAssertEqual(cloudflare?.isDisabled, true)
            XCTAssertEqual(cloudflare?.codexPluginEnabled, false)
            XCTAssertEqual(cloudflare?.headersHelper, "/opt/bin/cloudflare-mcp-headers")
            XCTAssertEqual(cloudflare?.canToggleCodexPluginPolicy, false)
            XCTAssertFalse(names.contains("vercel"))
        }
    }

    func testCodexPluginInventoryNormalizesCommandArrays() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)

        let pluginRoot = try writeCodexPlugin(
            codexHome: codexHome,
            pluginID: "array@team",
            version: "1.0.0",
            mcpJSON: """
            {
              "mcpServers": {
                "array-tool": {
                  "command": ["./bin/server", "--stdio"],
                  "cwd": "."
                }
              }
            }
            """
        )
        try """
        [plugins."array@team"]
        enabled = true
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let server = ConfigReader.shared.readAllTools()
                .first { $0.toolID == "codex" }?
                .servers
                .first { $0.name == "array-tool" }

            XCTAssertEqual(server?.command, pluginRoot.appendingPathComponent("bin/server").path)
            XCTAssertEqual(server?.args, ["--stdio"])
            XCTAssertEqual(server?.cwd, pluginRoot.path)
        }
    }

    func testCodexGlobalInventoryIncludesDefaultProfileFileServersAndPlugins() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        let pluginRoot = try writeCodexPlugin(
            codexHome: codexHome,
            pluginID: "profile-only@team-tools",
            version: "1.0.0",
            mcpJSON: """
            {
              "mcpServers": {
                "profile-plugin": {
                  "type": "http",
                  "url": "https://docs.example.invalid/mcp"
                }
              }
            }
            """
        )

        try """
        profile = "work"

        [mcp_servers.docs]
        command = "npx"
        args = ["global-docs"]
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try """
        [mcp_servers.docs]
        command = "npx"
        args = ["profile-docs"]

        [mcp_servers.profile_direct]
        command = "uvx"
        args = ["profile-direct"]

        [plugins."profile-only@team-tools"]
        enabled = true
        """.write(to: codexHome.appendingPathComponent("work.config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let servers = ConfigReader.shared.readAllTools()
                .first { $0.toolID == "codex" }?
                .servers ?? []
            let docs = servers.first { $0.name == "docs" }
            let profileDirect = servers.first { $0.name == "profile_direct" }
            let profilePlugin = servers.first { $0.name == "profile-plugin" }

            XCTAssertEqual(docs?.args, ["profile-docs"])
            XCTAssertEqual(profileDirect?.command, "uvx")
            XCTAssertEqual(profilePlugin?.sourcePath, pluginRoot.appendingPathComponent(".mcp.json").path)
            XCTAssertEqual(profilePlugin?.codexPluginPolicyConfigPath, codexHome.appendingPathComponent("work.config.toml").path)
            XCTAssertEqual(profilePlugin?.codexPluginPolicyProfileName, "work")
            XCTAssertEqual(profilePlugin?.codexPluginEnabled, true)
        }
    }

    func testGlobalInventoryIgnoresPlaceholderOnlyOAuthMetadata() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)

        _ = try writeCodexPlugin(
            codexHome: codexHome,
            pluginID: "oauth@team",
            version: "1.0.0",
            mcpJSON: """
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
            """
        )
        try """
        [plugins."oauth@team"]
        enabled = true
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let servers = ConfigReader.shared.readAllTools()
                .first { $0.toolID == "codex" }?
                .servers ?? []
            let placeholder = servers.first { $0.name == "placeholder" }
            let configured = servers.first { $0.name == "configured" }

            XCTAssertEqual(placeholder?.oauth, [:])
            XCTAssertEqual(configured?.oauth["clientId"], "projecthub-client")
            XCTAssertEqual(configured?.oauth["authServerMetadataUrl"], "https://example.com/.well-known/oauth-authorization-server")
            XCTAssertEqual(configured?.oauth["callbackPort"], "8080")
            XCTAssertEqual(configured?.oauth["scopes"], "read write")
        }
    }

    @MainActor
    func testMCPStorePreviewsAndAppliesCodexPluginPolicyForGlobalPluginRow() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        _ = try writeCodexPlugin(
            codexHome: codexHome,
            pluginID: "docs@team",
            version: "abc123",
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

        [plugins."docs@team"]
        enabled = true
        """.write(to: configURL, atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let server = try XCTUnwrap(ConfigReader.shared.readAllTools()
                .first { $0.toolID == "codex" }?
                .servers
                .first { $0.name == "docs" })
            let store = MCPStore()

            let preview = try XCTUnwrap(store.previewCodexPluginPolicyToggle(
                toolID: "codex",
                server: server,
                currently: false
            ))
            XCTAssertEqual(preview.pluginID, "docs@team")
            XCTAssertEqual(preview.profileName, "work")
            XCTAssertEqual(preview.enabled, false)
            XCTAssertTrue(preview.after.contains(#"[profiles.work.plugins."docs@team".mcp_servers.docs]"#))
            XCTAssertTrue(preview.after.contains("enabled = false"))

            let applied = store.applyCodexPluginPolicyPreview(preview)
            XCTAssertTrue(applied.ok, applied.error ?? "")
            let updated = try String(contentsOf: configURL, encoding: .utf8)
            XCTAssertTrue(updated.contains(#"[profiles.work.plugins."docs@team".mcp_servers.docs]"#))
            XCTAssertTrue(updated.contains("enabled = false"))
        }
    }

    @MainActor
    func testMCPStoreRefusesStaleCodexPluginPolicyPreview() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        _ = try writeCodexPlugin(
            codexHome: codexHome,
            pluginID: "docs@team",
            version: "abc123",
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
        [plugins."docs@team"]
        enabled = true
        """.write(to: configURL, atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let server = try XCTUnwrap(ConfigReader.shared.readAllTools()
                .first { $0.toolID == "codex" }?
                .servers
                .first { $0.name == "docs" })
            let store = MCPStore()
            let preview = try XCTUnwrap(store.previewCodexPluginPolicyToggle(
                toolID: "codex",
                server: server,
                currently: false
            ))

            try """
            [plugins."docs@team"]
            enabled = true
            # edited after preview
            """.write(to: configURL, atomically: true, encoding: .utf8)

            let applied = store.applyCodexPluginPolicyPreview(preview)
            XCTAssertFalse(applied.ok)
            XCTAssertTrue(applied.error?.contains("changed after preview") == true)

            let updated = try String(contentsOf: configURL, encoding: .utf8)
            XCTAssertFalse(updated.contains("[plugins.\"docs@team\".mcp_servers.docs]"))
            XCTAssertTrue(updated.contains("# edited after preview"))
        }
    }

    func testCodexGlobalPluginServerPolicyDisablesOneBundledServerAndKeepsDuplicateIDsUnique() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        let pluginRoot = try writeCodexPlugin(
            codexHome: codexHome,
            pluginID: "tools@team",
            version: "abc123",
            mcpJSON: """
            {
              "mcp_servers": {
                "direct": {
                  "command": "./bin/direct"
                },
                "helper": {
                  "command": "npx",
                  "args": ["helper-mcp"]
                }
              }
            }
            """
        )

        try """
        [mcp_servers.direct]
        command = "npx"
        args = ["direct-mcp"]

        [plugins."tools@team"]
        enabled = true

        [plugins."tools@team".mcp_servers.helper]
        enabled = false
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let codex = ConfigReader.shared.readAllTools().first { $0.toolID == "codex" }
            let servers = codex?.servers ?? []
            let directRows = servers.filter { $0.name == "direct" }
            let helper = servers.first { $0.name == "helper" }

            XCTAssertEqual(directRows.count, 2)
            XCTAssertEqual(Set(directRows.map(\.id)).count, 2)
            XCTAssertTrue(directRows.contains { $0.isReadOnly == false && $0.command == "npx" })
            XCTAssertTrue(directRows.contains {
                $0.isReadOnly == true
                    && $0.command == pluginRoot.appendingPathComponent("bin/direct").path
            })
            XCTAssertEqual(helper?.isReadOnly, true)
            XCTAssertEqual(helper?.isDisabled, true)
        }
    }

    func testCodexGlobalInventoryAppliesActiveProfilePluginServerPolicy() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        _ = try writeCodexPlugin(
            codexHome: codexHome,
            pluginID: "docs@team",
            version: "abc123",
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
        profile = "work"

        [plugins."docs@team"]
        enabled = true

        [plugins."docs@team".mcp_servers.docs]
        enabled = true

        [profiles.work.plugins."docs@team".mcp_servers.docs]
        enabled = false
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let codex = ConfigReader.shared.readAllTools().first { $0.toolID == "codex" }
            let docs = codex?.servers.first { $0.name == "docs" }
            XCTAssertEqual(docs?.isReadOnly, true)
            XCTAssertEqual(docs?.isDisabled, true)
        }
    }

    func testCodexPluginEnableFixClearsInheritedAndActiveProfileDisablePolicy() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        _ = try writeCodexPlugin(
            codexHome: codexHome,
            pluginID: "docs@team",
            version: "abc123",
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
        let configPath = codexHome.appendingPathComponent("config.toml")

        try """
        profile = "work"

        [plugins."docs@team"]
        enabled = true

        [plugins."docs@team".mcp_servers.docs]
        enabled = false

        [profiles.work.plugins."docs@team".mcp_servers.docs]
        enabled = false
        """.write(to: configPath, atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            var codex = ConfigReader.shared.readAllTools().first { $0.toolID == "codex" }
            XCTAssertEqual(codex?.servers.first { $0.name == "docs" }?.isDisabled, true)

            try ConfigWriter.setCodexPluginMCPServerEnabled(
                configPath: configPath.path,
                pluginID: "docs@team",
                serverName: "docs",
                enabled: true
            )

            codex = ConfigReader.shared.readAllTools().first { $0.toolID == "codex" }
            XCTAssertEqual(codex?.servers.first { $0.name == "docs" }?.isDisabled, false)
        }
    }

    func testClaudeDesktopExtensionInventoryIncludesReadOnlyExtensionServer() throws {
        let root = try makeTempDirectory()
        let support = root.appendingPathComponent("ClaudeSupport", isDirectory: true)
        let extensionRoot = support
            .appendingPathComponent("Claude Extensions", isDirectory: true)
            .appendingPathComponent("docs-extension", isDirectory: true)
        let settingsRoot = support.appendingPathComponent("Claude Extensions Settings", isDirectory: true)
        try FileManager.default.createDirectory(at: extensionRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: settingsRoot, withIntermediateDirectories: true)

        try """
        {
          "name": "docs-extension",
          "display_name": "Docs Extension",
          "server": {
            "mcp_config": {
              "command": "${__dirname}/bin/server",
              "args": ["--stdio", "${user_config.project}"],
              "cwd": "${__dirname}"
            }
          },
          "user_config": {
            "project": {
              "type": "string",
              "default": "default-project"
            }
          }
        }
        """.write(to: extensionRoot.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
        try """
        {
          "isEnabled": false,
          "userConfig": {
            "project": "projecthub"
          }
        }
        """.write(to: settingsRoot.appendingPathComponent("docs-extension.json"), atomically: true, encoding: .utf8)

        try withEnv("PROJECTHUB_CLAUDE_DESKTOP_SUPPORT_DIR", support.path) {
            let desktop = ConfigReader.shared.readAllTools().first { $0.toolID == "claude-desktop" }
            let server = try XCTUnwrap(desktop?.servers.first { $0.name == "Docs Extension" })

            XCTAssertEqual(server.command, extensionRoot.appendingPathComponent("bin/server").path)
            XCTAssertEqual(server.args, ["--stdio", "projecthub"])
            XCTAssertEqual(server.cwd, extensionRoot.path)
            XCTAssertEqual(server.sourcePath, extensionRoot.appendingPathComponent("manifest.json").path)
            XCTAssertEqual(server.sourceLabel, "Claude Desktop extension: Docs Extension")
            XCTAssertTrue(server.isReadOnly)
            XCTAssertTrue(server.isDisabled)
            XCTAssertEqual(server.readOnlyReason, "Installed through Claude Desktop extensions. This inventory row is read-only because Claude Desktop owns the extension package and settings.")
        }
    }

    @MainActor
    func testMCPStoreHealthUsesServerSourcePathForReadOnlyRows() throws {
        let root = try makeTempDirectory()
        let sourceRoot = root.appendingPathComponent("plugin", isDirectory: true)
        let wrongRoot = root.appendingPathComponent("wrong", isDirectory: true)
        let binRoot = sourceRoot.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: binRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: wrongRoot, withIntermediateDirectories: true)

        let executable = binRoot.appendingPathComponent("server")
        try "#!/bin/sh\nexit 0\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let sourceConfig = sourceRoot.appendingPathComponent("mcp.json")
        try "{}".write(to: sourceConfig, atomically: true, encoding: .utf8)
        let wrongConfig = wrongRoot.appendingPathComponent("config.toml")
        try "{}".write(to: wrongConfig, atomically: true, encoding: .utf8)

        let server = ServerEntry(
            name: "source-owned",
            transport: "stdio",
            command: "bin/server",
            args: [],
            cwd: ".",
            url: nil,
            env: [:],
            headers: [:],
            bearerTokenEnvVar: nil,
            sourcePath: sourceConfig.path,
            sourceLabel: "Read-only source",
            isReadOnly: true
        )
        let store = MCPStore()
        store.tools = [
            ToolSummary(
                toolID: "codex",
                label: "Codex",
                short: "Cx",
                detected: true,
                configPath: wrongConfig.path,
                servers: [server]
            )
        ]

        let report = store.health(for: server, toolID: "codex")

        XCTAssertNotEqual(report.status, .broken)
        XCTAssertFalse(report.summary.contains("Command not found"))
    }

    @MainActor
    func testMCPStoreHealthKeepsWritableRowsOnToolConfigPath() throws {
        let root = try makeTempDirectory()
        let configRoot = root.appendingPathComponent("project", isDirectory: true)
        let wrongRoot = root.appendingPathComponent("wrong", isDirectory: true)
        let binRoot = configRoot.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: binRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: wrongRoot, withIntermediateDirectories: true)

        let executable = binRoot.appendingPathComponent("server")
        try "#!/bin/sh\nexit 0\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let configPath = configRoot.appendingPathComponent("config.toml")
        try "{}".write(to: configPath, atomically: true, encoding: .utf8)
        let wrongSourcePath = wrongRoot.appendingPathComponent("mcp.json")
        try "{}".write(to: wrongSourcePath, atomically: true, encoding: .utf8)

        let server = ServerEntry(
            name: "writable",
            transport: "stdio",
            command: "bin/server",
            args: [],
            cwd: ".",
            url: nil,
            env: [:],
            headers: [:],
            bearerTokenEnvVar: nil,
            sourcePath: wrongSourcePath.path,
            sourceLabel: "Compatibility evidence",
            isReadOnly: false
        )
        let store = MCPStore()
        store.tools = [
            ToolSummary(
                toolID: "codex",
                label: "Codex",
                short: "Cx",
                detected: true,
                configPath: configPath.path,
                servers: [server]
            )
        ]

        let report = store.health(for: server, toolID: "codex")

        XCTAssertNotEqual(report.status, .broken)
        XCTAssertFalse(report.summary.contains("Command not found"))
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

    func testConfigReaderUsesTildeExpandedCodexHome() throws {
        let folder = ".projecthub-full-config-codex-\(UUID().uuidString)"
        let expanded = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: expanded, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: expanded)
        }
        try """
        [mcp_servers.docs]
        command = "/bin/echo"
        args = ["ok"]
        """.write(to: expanded.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        try withCodexHome("~/\(folder)") {
            let codex = try XCTUnwrap(ConfigReader.shared.readAllTools().first { $0.toolID == "codex" })
            XCTAssertEqual(codex.configPath, expanded.appendingPathComponent("config.toml").path)
            XCTAssertTrue(codex.servers.contains { $0.name == "docs" })
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
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubFullConfigReaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }

    @discardableResult
    private func writeCodexPlugin(
        codexHome: URL,
        pluginID: String,
        version: String,
        mcpJSON: String
    ) throws -> URL {
        let parts = try XCTUnwrap(splitCodexPluginID(pluginID))
        let pluginRoot = codexHome
            .appendingPathComponent("plugins/cache", isDirectory: true)
            .appendingPathComponent(parts.marketplace, isDirectory: true)
            .appendingPathComponent(parts.name, isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)
        let manifestDirectory = pluginRoot.appendingPathComponent(".codex-plugin", isDirectory: true)
        try FileManager.default.createDirectory(at: manifestDirectory, withIntermediateDirectories: true)
        try """
        {
          "name": "\(parts.name)",
          "version": "\(version)",
          "mcpServers": "./.mcp.json"
        }
        """.write(to: manifestDirectory.appendingPathComponent("plugin.json"), atomically: true, encoding: .utf8)
        try mcpJSON.write(to: pluginRoot.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)
        return pluginRoot
    }

    private func splitCodexPluginID(_ pluginID: String) -> (name: String, marketplace: String)? {
        guard let at = pluginID.lastIndex(of: "@") else { return nil }
        let name = String(pluginID[..<at])
        let marketplace = String(pluginID[pluginID.index(after: at)...])
        guard !name.isEmpty, !marketplace.isEmpty else { return nil }
        return (name, marketplace)
    }
}
