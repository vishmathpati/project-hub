import XCTest
@testable import ProjectHub

final class ImportParserCommandTests: XCTestCase {
    func testBareCommandParsesLeadingInlineEnvAssignment() throws {
        let server = try firstParsed("API_KEY=secret npx -y @example/mcp-server")

        XCTAssertEqual(server.config["command"] as? String, "npx")
        XCTAssertEqual(server.config["args"] as? [String], ["-y", "@example/mcp-server"])
        XCTAssertEqual(server.config["env"] as? [String: String], ["API_KEY": "secret"])
    }

    func testBareCommandParsesEnvWrapperAssignment() throws {
        let server = try firstParsed("env API_KEY=secret uvx example-mcp")

        XCTAssertEqual(server.config["command"] as? String, "uvx")
        XCTAssertEqual(server.config["args"] as? [String], ["example-mcp"])
        XCTAssertEqual(server.config["env"] as? [String: String], ["API_KEY": "secret"])
    }

    func testBareCommandParsesAbsoluteEnvWrapperAssignment() throws {
        let server = try firstParsed("/usr/bin/env API_KEY=secret uvx example-mcp")

        XCTAssertEqual(server.config["command"] as? String, "uvx")
        XCTAssertEqual(server.config["args"] as? [String], ["example-mcp"])
        XCTAssertEqual(server.config["env"] as? [String: String], ["API_KEY": "secret"])
    }

    func testBareCommandParsesEnvSplitStringWrapper() throws {
        let server = try firstParsed(#"/usr/bin/env -S "API_KEY=secret uvx example-mcp --stdio""#)

        XCTAssertEqual(server.config["command"] as? String, "uvx")
        XCTAssertEqual(server.config["args"] as? [String], ["example-mcp", "--stdio"])
        XCTAssertEqual(server.config["env"] as? [String: String], ["API_KEY": "secret"])
    }

    func testBareCommandParsesEnvWrapperPassthroughVariable() throws {
        let server = try firstParsed("env API_KEY npx -y @example/mcp-server")

        XCTAssertEqual(server.config["command"] as? String, "npx")
        XCTAssertEqual(server.config["args"] as? [String], ["-y", "@example/mcp-server"])
        XCTAssertEqual(server.config["env"] as? [String: String], ["API_KEY": "${API_KEY}"])
    }

    func testCliAddParsesDoubleDashEnvWrappedCommand() throws {
        let server = try firstParsed("claude mcp add github -- env GITHUB_PERSONAL_ACCESS_TOKEN=secret npx -y @modelcontextprotocol/server-github")

        XCTAssertEqual(server.name, "github")
        XCTAssertEqual(server.config["command"] as? String, "npx")
        XCTAssertEqual(server.config["args"] as? [String], ["-y", "@modelcontextprotocol/server-github"])
        XCTAssertEqual(server.config["env"] as? [String: String], ["GITHUB_PERSONAL_ACCESS_TOKEN": "secret"])
    }

    func testClaudeCliAddParsesOfficialRemoteFlagBeforeName() throws {
        let server = try firstParsed("claude mcp add --transport http stripe https://mcp.stripe.com")

        XCTAssertEqual(server.name, "stripe")
        XCTAssertEqual(server.config["type"] as? String, "http")
        XCTAssertEqual(server.config["url"] as? String, "https://mcp.stripe.com")
    }

    func testClaudeCliAddParsesSupabaseHostedRemoteCommand() throws {
        let server = try firstParsed(#"claude mcp add --scope project --transport http supabase "https://mcp.supabase.com/mcp""#)

        XCTAssertEqual(server.name, "supabase")
        XCTAssertEqual(server.config["type"] as? String, "http")
        XCTAssertEqual(server.config["url"] as? String, "https://mcp.supabase.com/mcp")
    }

    func testClaudeCliAddParsesRemoteHeaderAfterURL() throws {
        let server = try firstParsed("""
        claude mcp add --transport http github https://api.githubcopilot.com/mcp/ \
          --header "Authorization: Bearer YOUR_GITHUB_PAT"
        """)

        XCTAssertEqual(server.name, "github")
        XCTAssertEqual(server.config["type"] as? String, "http")
        XCTAssertEqual(server.config["url"] as? String, "https://api.githubcopilot.com/mcp/")
        XCTAssertEqual(server.config["headers"] as? [String: String], [
            "Authorization": "Bearer YOUR_GITHUB_PAT"
        ])
    }

    func testClaudeCliAddParsesOfficialStdioDoubleDashCommand() throws {
        let server = try firstParsed("""
        claude mcp add --transport stdio db -- npx -y @bytebase/dbhub \
          --dsn "postgresql://readonly:pass@prod.db.com:5432/analytics"
        """)

        XCTAssertEqual(server.name, "db")
        XCTAssertEqual(server.config["command"] as? String, "npx")
        XCTAssertEqual(server.config["args"] as? [String], [
            "-y",
            "@bytebase/dbhub",
            "--dsn",
            "postgresql://readonly:pass@prod.db.com:5432/analytics"
        ])
    }

    func testClaudeCliAddParsesOfficialOAuthFlagsBeforeName() throws {
        let server = try firstParsed("""
        claude mcp add --transport http \
          --client-id your-client-id --client-secret --callback-port 8080 \
          my-server https://mcp.example.com/mcp
        """)

        XCTAssertEqual(server.name, "my-server")
        XCTAssertEqual(server.config["type"] as? String, "http")
        XCTAssertEqual(server.config["url"] as? String, "https://mcp.example.com/mcp")
        let oauth = try XCTUnwrap(server.config["oauth"] as? [String: Any])
        XCTAssertEqual(oauth["clientId"] as? String, "your-client-id")
        XCTAssertEqual(oauth["callbackPort"] as? Int, 8080)
        XCTAssertNil(oauth["clientSecret"])
    }

    func testClaudeCliAddJSONPreservesOfficialOAuthConfig() throws {
        let server = try firstParsed("""
        claude mcp add-json my-server '{"type":"http","url":"https://mcp.example.com/mcp","oauth":{"clientId":"your-client-id","callbackPort":8080}}'
        """)

        XCTAssertEqual(server.name, "my-server")
        XCTAssertEqual(server.config["type"] as? String, "http")
        XCTAssertEqual(server.config["url"] as? String, "https://mcp.example.com/mcp")
        let oauth = try XCTUnwrap(server.config["oauth"] as? [String: Any])
        XCTAssertEqual(oauth["clientId"] as? String, "your-client-id")
        XCTAssertEqual(oauth["callbackPort"] as? Int, 8080)
    }

    func testPromptPrefixedReadmeLineParsesInlineEnvCommand() throws {
        let server = try firstParsed("""
        Install it with:

        $ GITHUB_PERSONAL_ACCESS_TOKEN=<YOUR_TOKEN> npx -y @modelcontextprotocol/server-github
        """)

        XCTAssertEqual(server.config["command"] as? String, "npx")
        XCTAssertEqual(server.config["args"] as? [String], ["-y", "@modelcontextprotocol/server-github"])
        XCTAssertEqual(server.config["env"] as? [String: String], ["GITHUB_PERSONAL_ACCESS_TOKEN": "<YOUR_TOKEN>"])
    }

    func testJSONCommandStringWithEnvPrefixIsNormalized() throws {
        let server = try firstParsed("""
        {
          "name": "github",
          "command": "GITHUB_PERSONAL_ACCESS_TOKEN=${GITHUB_PERSONAL_ACCESS_TOKEN} npx -y @modelcontextprotocol/server-github"
        }
        """)

        XCTAssertEqual(server.name, "github")
        XCTAssertEqual(server.config["command"] as? String, "npx")
        XCTAssertEqual(server.config["args"] as? [String], ["-y", "@modelcontextprotocol/server-github"])
        XCTAssertEqual(server.config["env"] as? [String: String], ["GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}"])
    }

    func testJSONImportParsesSnakeCaseMCPServersWrapper() throws {
        let server = try firstParsed("""
        {
          "mcp_servers": {
            "docs": {
              "command": "npx",
              "args": ["-y", "@example/docs-mcp"]
            }
          }
        }
        """)

        XCTAssertEqual(server.name, "docs")
        XCTAssertEqual(server.config["command"] as? String, "npx")
        XCTAssertEqual(server.config["args"] as? [String], ["-y", "@example/docs-mcp"])
    }

    func testDockerEnvFlagAddsLaunchEnvHint() throws {
        let server = try firstParsed("docker run -i --rm --env GITHUB_PERSONAL_ACCESS_TOKEN ghcr.io/github/github-mcp-server")

        XCTAssertEqual(server.config["command"] as? String, "docker")
        XCTAssertEqual(
            server.config["args"] as? [String],
            ["run", "-i", "--rm", "--env", "GITHUB_PERSONAL_ACCESS_TOKEN", "ghcr.io/github/github-mcp-server"]
        )
        XCTAssertEqual(server.config["env"] as? [String: String], ["GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}"])
    }

    func testDockerEnvFileAddsLaunchEnvFileHint() throws {
        let server = try firstParsed("docker run -i --rm --env-file .env.mcp ghcr.io/github/github-mcp-server")

        XCTAssertEqual(server.config["command"] as? String, "docker")
        XCTAssertEqual(
            server.config["args"] as? [String],
            ["run", "-i", "--rm", "--env-file", ".env.mcp", "ghcr.io/github/github-mcp-server"]
        )
        XCTAssertEqual(server.config["envFile"] as? String, ".env.mcp")
    }

    func testDockerEnvFileInlineFlagAddsLaunchEnvFileHint() throws {
        let server = try firstParsed("docker run --env-file=.env.local ghcr.io/github/github-mcp-server")

        XCTAssertEqual(server.config["command"] as? String, "docker")
        XCTAssertEqual(server.config["envFile"] as? String, ".env.local")
    }

    func testNpmExecCommandKeepsWrapperAndInfersPackageName() throws {
        let server = try firstParsed("npm exec --yes @scope/docs-mcp -- --token ${DOCS_TOKEN}")

        XCTAssertEqual(server.name, "scope-docs-mcp")
        XCTAssertEqual(server.config["command"] as? String, "npm")
        XCTAssertEqual(server.config["args"] as? [String], ["exec", "--yes", "@scope/docs-mcp", "--", "--token", "${DOCS_TOKEN}"])
        XCTAssertNil(ImportParser.interactiveInstaller(from: "npm exec --yes @scope/docs-mcp -- --token ${DOCS_TOKEN}"))
    }

    func testNpmXCommandKeepsWrapperAndInfersPackageName() throws {
        let server = try firstParsed("npm x --yes @scope/search-mcp")

        XCTAssertEqual(server.name, "scope-search-mcp")
        XCTAssertEqual(server.config["command"] as? String, "npm")
        XCTAssertEqual(server.config["args"] as? [String], ["x", "--yes", "@scope/search-mcp"])
    }

    func testPnpmDlxCommandKeepsWrapperAndInfersPackageName() throws {
        let server = try firstParsed("pnpm dlx @scope/repo-mcp --stdio")

        XCTAssertEqual(server.name, "scope-repo-mcp")
        XCTAssertEqual(server.config["command"] as? String, "pnpm")
        XCTAssertEqual(server.config["args"] as? [String], ["dlx", "@scope/repo-mcp", "--stdio"])
    }

    func testUVRunWithCommandKeepsWrapperAndInfersPackageName() throws {
        let server = try firstParsed("uv run --with fastmcp fastmcp-mcp --stdio")

        XCTAssertEqual(server.name, "fastmcp")
        XCTAssertEqual(server.config["command"] as? String, "uv")
        XCTAssertEqual(server.config["args"] as? [String], ["run", "--with", "fastmcp", "fastmcp-mcp", "--stdio"])
    }

    func testWizardInstallerDoesNotBecomeBareNpxServer() throws {
        let command = "npx @posthog/wizard mcp add"

        XCTAssertTrue(ImportParser.importChoices(from: command).isEmpty)
        switch ImportParser.parse(command) {
        case .success(let servers):
            XCTFail("Expected wizard handoff, got \(servers)")
        case .failure(let error):
            XCTAssertEqual(error, .wizardCommand)
        }

        let installer = try XCTUnwrap(ImportParser.interactiveInstaller(from: command))
        XCTAssertEqual(installer.rawCommand, command)
        XCTAssertEqual(installer.runtime, "Node package installer")
        XCTAssertTrue(installer.summary.contains("Prompt-driven MCP installer"))
    }

    func testPackageRunnerMCPAddInstallersUseWizardHandoff() throws {
        let commands = [
            "px mcp add",
            "npm exec @vendor/wizard mcp add",
            "pnpm dlx @vendor/wizard mcp add",
            "bun @vendor/wizard mcp add",
            "bunx @vendor/wizard mcp add",
            "uvx vendor-wizard mcp add",
            "pipx run vendor-wizard mcp add"
        ]

        for command in commands {
            XCTAssertTrue(ImportParser.importChoices(from: command).isEmpty, command)
            switch ImportParser.parse(command) {
            case .success(let servers):
                XCTFail("Expected wizard handoff for \(command), got \(servers)")
            case .failure(let error):
                XCTAssertEqual(error, .wizardCommand, command)
            }
            XCTAssertEqual(ImportParser.interactiveInstaller(from: command)?.rawCommand, command)
        }
    }

    func testDirectMCPAddOnlyUsesWizardHandoffWhenNotParseable() throws {
        switch ImportParser.parse("mcp add") {
        case .success(let servers):
            XCTFail("Expected wizard handoff, got \(servers)")
        case .failure(let error):
            XCTAssertEqual(error, .wizardCommand)
        }
        XCTAssertEqual(ImportParser.interactiveInstaller(from: "mcp add")?.runtime, "MCP installer")

        let server = try firstParsed("mcp add docs --transport http https://example.com/mcp")
        XCTAssertEqual(server.name, "docs")
        XCTAssertEqual(server.config["url"] as? String, "https://example.com/mcp")
        XCTAssertNil(ImportParser.interactiveInstaller(from: "mcp add docs --transport http https://example.com/mcp"))
    }

    private func firstParsed(_ raw: String) throws -> ParsedServer {
        switch ImportParser.parse(raw) {
        case .success(let servers):
            return try XCTUnwrap(servers.first)
        case .failure(let error):
            XCTFail("Expected parse success, got \(error)")
            throw error
        }
    }
}
