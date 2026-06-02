import XCTest
@testable import ProjectHub

final class CompatibilityMCPAuthTests: XCTestCase {
    func testClaudeCodeAuthSurfaceIsCliManagedAndUnknownWhenStatusUnavailable() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let surface = report.matrix.first { $0.id == "claude-code-auth" }
            let authIssue = report.issues.first { $0.surfaceID == "claude-code-auth" }

            XCTAssertEqual(surface?.writeMethod, .cli)
            XCTAssertEqual(surface?.fileControlled, false)
            XCTAssertEqual(authIssue?.code, .serverHealthUnknown)
            XCTAssertEqual(authIssue?.state, .unknown)
            XCTAssertTrue(authIssue?.detail.contains("claude auth status") == true)
        }
    }

    func testCompatibilityMatrixUsesResolvedCodexHomePaths() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        withCodexHome(codexHome.path) {
            withEnvironmentVariables(["CODEX_HOME": "   "]) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let defaultAuthPath = (FileManager.default.homeDirectoryForCurrentUser.path as NSString)
                    .appendingPathComponent(".codex/auth.json")
                XCTAssertEqual(
                    report.matrix.first { $0.id == "codex-auth" }?.path,
                    defaultAuthPath
                )
            }
        }

        let folder = ".projecthub-compat-codex-\(UUID().uuidString)"
        let expanded = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: expanded, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: expanded)
        }

        withCodexHome(codexHome.path) {
            withEnvironmentVariables(["CODEX_HOME": "~/\(folder)"]) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                XCTAssertEqual(
                    report.matrix.first { $0.id == "codex-auth" }?.path,
                    expanded.appendingPathComponent("auth.json").path
                )
                XCTAssertEqual(
                    report.matrix.first { $0.id == "codex-cli-global-mcp" }?.path,
                    expanded.appendingPathComponent("config.toml").path
                )
            }
        }
    }

    func testClaudeCodeAuthStatusExitOneReportsLoginRequired() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let fakeClaude = root.appendingPathComponent("claude")
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        #!/bin/sh
        exit 1
        """.write(to: fakeClaude, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeClaude.path)

        withCodexHome(codexHome.path) {
            withEnvironmentVariables([
                "PROJECTHUB_CLAUDE_COMMAND_PATH": fakeClaude.path,
                "ANTHROPIC_API_KEY": "real-api-key"
            ]) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let authIssue = report.issues.first { $0.surfaceID == "claude-code-auth" }

                XCTAssertEqual(authIssue?.code, .serverAuthMissing)
                XCTAssertEqual(authIssue?.state, .needsAuth)
                XCTAssertEqual(authIssue?.title, "Claude Code login required")
                XCTAssertNil(authIssue?.metadata["source"])
                XCTAssertFalse(authIssue?.detail.contains("real-api-key") == true)
            }
        }
    }

    func testClaudeCodeAnthropicAuthTokenEnvIsDetectedAndRedactedWhenStatusUnavailable() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        withCodexHome(codexHome.path) {
            withEnvironmentVariables(["ANTHROPIC_AUTH_TOKEN": "real-secret-token"]) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let authIssue = report.issues.first { $0.surfaceID == "claude-code-auth" }

                XCTAssertEqual(authIssue?.code, .authCredentialStore)
                XCTAssertEqual(authIssue?.state, .unknown)
                XCTAssertEqual(authIssue?.title, "Claude Code auth token in environment")
                XCTAssertEqual(authIssue?.metadata["source"], "ANTHROPIC_AUTH_TOKEN")
                XCTAssertTrue(authIssue?.detail.contains("ANTHROPIC_AUTH_TOKEN") == true)
                XCTAssertFalse(authIssue?.detail.contains("real-secret-token") == true)
            }
        }
    }

    func testClaudeCodeCloudProviderEnvWinsOverApiKeyEnv() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        withCodexHome(codexHome.path) {
            withEnvironmentVariables([
                "CLAUDE_CODE_USE_BEDROCK": "1",
                "ANTHROPIC_API_KEY": "real-api-key"
            ]) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let authIssue = report.issues.first { $0.surfaceID == "claude-code-auth" }

                XCTAssertEqual(authIssue?.code, .authCredentialStore)
                XCTAssertEqual(authIssue?.title, "Claude Code cloud-provider auth requested")
                XCTAssertEqual(authIssue?.metadata["source"], "CLAUDE_CODE_USE_BEDROCK")
                XCTAssertFalse(authIssue?.detail.contains("real-api-key") == true)
            }
        }
    }

    func testClaudeCodePlaceholderApiKeyEnvReportsNeedsAuthAndRedactsValue() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        withCodexHome(codexHome.path) {
            withEnvironmentVariables(["ANTHROPIC_API_KEY": "YOUR_TOKEN"]) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let authIssue = report.issues.first { $0.surfaceID == "claude-code-auth" }

                XCTAssertEqual(authIssue?.code, .serverAuthMissing)
                XCTAssertEqual(authIssue?.state, .needsAuth)
                XCTAssertEqual(authIssue?.title, "Claude Code environment credential is empty")
                XCTAssertEqual(authIssue?.metadata["source"], "ANTHROPIC_API_KEY")
                XCTAssertTrue(authIssue?.detail.contains("ANTHROPIC_API_KEY") == true)
                XCTAssertFalse(authIssue?.detail.contains("YOUR_TOKEN") == true)
            }
        }
    }

    func testClaudeCodeAPIKeyHelperTakesPrecedenceOverOAuthTokenEnv() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let claudeHome = codexHome.appendingPathComponent("isolated-claude-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "apiKeyHelper": "/safe/helper"
        }
        """.write(to: claudeHome.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            withEnvironmentVariables(["CLAUDE_CODE_OAUTH_TOKEN": "real-oauth-token"]) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let authIssue = report.issues.first { $0.surfaceID == "claude-code-auth" }

                XCTAssertEqual(authIssue?.code, .authCredentialStore)
                XCTAssertEqual(authIssue?.title, "Claude Code API key helper configured")
                XCTAssertFalse(authIssue?.detail.contains("real-oauth-token") == true)
                XCTAssertFalse(authIssue?.detail.contains("/safe/helper") == true)
            }
        }
    }

    func testClaudeCodeProjectMCPPlaceholderDoesNotBecomeToolLoginNeedsAuth() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "supabase": {
              "env": {
                "SUPABASE_ACCESS_TOKEN": "YOUR_TOKEN"
              }
            }
          }
        }
        """.write(to: codexHome.appendingPathComponent("claude.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let authIssue = report.issues.first { $0.surfaceID == "claude-code-auth" }

            XCTAssertEqual(authIssue?.code, .serverHealthUnknown)
            XCTAssertEqual(authIssue?.state, .unknown)
            XCTAssertFalse(authIssue?.detail.contains("mcpServers") == true)
            XCTAssertFalse(authIssue?.detail.contains("YOUR_TOKEN") == true)
        }
    }

    func testClaudeCodeLegacyOAuthPlaceholderIsNeedsAuthAndRedacted() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "oauthAccount": {
            "accessToken": "YOUR_TOKEN",
            "refreshToken": "real-refresh-value"
          }
        }
        """.write(to: codexHome.appendingPathComponent("claude.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let authIssue = report.issues.first { $0.surfaceID == "claude-code-auth" }

            XCTAssertEqual(authIssue?.code, .serverAuthMissing)
            XCTAssertEqual(authIssue?.state, .needsAuth)
            XCTAssertEqual(authIssue?.title, "Claude Code auth credential is empty")
            XCTAssertTrue(authIssue?.detail.contains("oauthAccount.accessToken") == true)
            XCTAssertFalse(authIssue?.detail.contains("YOUR_TOKEN") == true)
            XCTAssertFalse(authIssue?.detail.contains("real-refresh-value") == true)
        }
    }

    func testClaudeCodeLegacyOAuthExpirationIsAuthExpired() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "oauthAccount": {
            "accessToken": "live-access-token",
            "expiresAt": "2000-01-01T00:00:00Z"
          }
        }
        """.write(to: codexHome.appendingPathComponent("claude.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let authIssue = report.issues.first { $0.surfaceID == "claude-code-auth" }

            XCTAssertEqual(authIssue?.code, .serverAuthExpired)
            XCTAssertEqual(authIssue?.state, .authExpired)
            XCTAssertEqual(authIssue?.title, "Claude Code authentication may be expired")
        }
    }

    func testClaudeCodeAPIKeyHelperIsRuntimeManagedAndRedacted() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let claudeHome = codexHome.appendingPathComponent("isolated-claude-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "apiKeyHelper": "/safe/helper"
        }
        """.write(to: claudeHome.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let authIssue = report.issues.first { $0.surfaceID == "claude-code-auth" }

            XCTAssertEqual(authIssue?.code, .authCredentialStore)
            XCTAssertEqual(authIssue?.state, .unknown)
            XCTAssertEqual(authIssue?.title, "Claude Code API key helper configured")
            XCTAssertFalse(authIssue?.detail.contains("/safe/helper") == true)
        }
    }

    func testClaudeDesktopAuthSurfaceIsRuntimeManaged() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let authIssue = report.issues.first { $0.surfaceID == "claude-desktop-account-auth" }

            XCTAssertEqual(authIssue?.code, .serverAuthRuntimeManaged)
            XCTAssertEqual(authIssue?.state, .unknown)
            XCTAssertEqual(authIssue?.title, "Runtime-managed authentication")
        }
    }

    func testClaudeCodePlaceholderOAuthWithCallbackPortDoesNotSuppressHostedOAuthMissingAuth() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "supabase": {
              "type": "http",
              "url": "https://mcp.supabase.com/mcp",
              "oauth": {
                "clientId": "your-client-id",
                "callbackPort": 8080
              }
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let hostedOAuth = report.issues.first {
                $0.code == .serverOAuthNeeded
                    && $0.title == "Hosted MCP OAuth required"
                    && $0.surfaceID == "claude-code-project-mcp"
            }
            let appOAuth = report.issues.first {
                $0.code == .serverAuthRuntimeManaged
                    && $0.title == "Auth managed by target tool OAuth"
                    && $0.surfaceID == "claude-code-project-mcp"
            }
            let server = report.servers.first {
                $0.toolID == .claudeCode
                    && $0.surfaceID == "claude-code-project-mcp"
                    && $0.name == "supabase"
            }
            let entry = server.flatMap {
                CompatibilityScanner.healthEntry(for: $0, matrix: report.matrix)
            }

            XCTAssertNotNil(hostedOAuth, report.issues.map(\.detail).joined(separator: "\n"))
            XCTAssertNil(appOAuth, report.issues.map(\.detail).joined(separator: "\n"))
            XCTAssertEqual(entry?.oauth, [:])
        }
    }

    func testClaudeCodeHeadersHelperSuppressesHostedOAuthMissingAuth() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "supabase": {
              "type": "http",
              "url": "https://mcp.supabase.com/mcp",
              "headersHelper": "/opt/bin/get-mcp-auth-headers.sh"
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let server = report.servers.first {
                $0.toolID == .claudeCode
                    && $0.surfaceID == "claude-code-project-mcp"
                    && $0.name == "supabase"
            }
            let entry = server.flatMap {
                CompatibilityScanner.healthEntry(for: $0, matrix: report.matrix)
            }
            let helperIssue = report.issues.first {
                $0.code == .serverAuthRuntimeManaged
                    && $0.title == "Auth managed by Claude Code headersHelper"
                    && $0.surfaceID == "claude-code-project-mcp"
            }

            XCTAssertEqual(entry?.headersHelper, "/opt/bin/get-mcp-auth-headers.sh")
            XCTAssertNotNil(helperIssue, report.issues.map(\.detail).joined(separator: "\n"))
            XCTAssertFalse(report.issues.contains {
                $0.surfaceID == "claude-code-project-mcp"
                    && ($0.code == .serverOAuthNeeded || $0.code == .serverAuthMissing)
            }, report.issues.map(\.detail).joined(separator: "\n"))
        }
    }

    func testClaudeProjectMCPCommandEnvFallbackDoesNotReportMissingCommand() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "local-tool": {
              "command": "${PROJECTHUB_OPTIONAL_MCP_BIN:-/bin/echo}",
              "args": []
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withEnvironmentVariablesUnset(["PROJECTHUB_OPTIONAL_MCP_BIN"]) {
            withCodexHome(codexHome.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                XCTAssertFalse(report.issues.contains {
                    $0.surfaceID == "claude-code-project-mcp"
                        && $0.code == .serverCommandMissing
                        && $0.detail.contains("local-tool")
                }, report.issues.map(\.detail).joined(separator: "\n"))
            }
        }
    }

    func testCodexMCPOAuthCredentialStoreDoesNotSuppressMainMissingAuthFinding() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        mcp_oauth_credentials_store = "keyring"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let authIssues = report.issues.filter {
                ["codex-auth", "codex-desktop-auth"].contains($0.surfaceID)
            }

            XCTAssertTrue(authIssues.contains {
                $0.code == .authCredentialStore
                    && $0.title == "Codex MCP OAuth may be in keychain"
                    && $0.detail.contains("mcp_oauth_credentials_store")
            }, authIssues.map(\.detail).joined(separator: "\n"))
            XCTAssertTrue(authIssues.contains {
                $0.code == .serverAuthMissing
                    && $0.title == "Authentication not found"
            }, authIssues.map(\.detail).joined(separator: "\n"))
        }
    }

    func testCodexOpenAIAPIKeyEnvIsAvailableForLoginAndRedacted() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        withCodexHome(codexHome.path) {
            withEnvironmentVariables(["OPENAI_API_KEY": "real-openai-key"]) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let authIssues = report.issues.filter {
                    ["codex-auth", "codex-desktop-auth"].contains($0.surfaceID)
                }

                XCTAssertTrue(authIssues.contains {
                    $0.code == .authCredentialStore
                        && $0.title == "OpenAI API key available for Codex login"
                        && $0.metadata["source"] == "OPENAI_API_KEY"
                        && $0.detail.contains("codex login --with-api-key")
                        && !$0.detail.contains("real-openai-key")
                }, authIssues.map(\.detail).joined(separator: "\n"))
            }
        }
    }

    func testCodexPlaceholderAccessTokenEnvIsNeedsAuthAndRedacted() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        withCodexHome(codexHome.path) {
            withEnvironmentVariables(["CODEX_ACCESS_TOKEN": "YOUR_TOKEN"]) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let authIssues = report.issues.filter {
                    ["codex-auth", "codex-desktop-auth"].contains($0.surfaceID)
                }

                XCTAssertTrue(authIssues.contains {
                    $0.code == .serverAuthMissing
                        && $0.state == .needsAuth
                        && $0.title == "Codex environment credential is empty"
                        && $0.metadata["source"] == "CODEX_ACCESS_TOKEN"
                        && !$0.detail.contains("YOUR_TOKEN")
                }, authIssues.map(\.detail).joined(separator: "\n"))
            }
        }
    }

    func testEmptyCodexAuthFileIsNeedsAuth() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "tokens": {}
        }
        """.write(to: codexHome.appendingPathComponent("auth.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let authIssues = report.issues.filter {
                ["codex-auth", "codex-desktop-auth"].contains($0.surfaceID)
            }

            XCTAssertTrue(authIssues.contains {
                $0.code == .serverAuthMissing
                    && $0.state == .needsAuth
                    && $0.title == "Authentication credential not found"
            }, authIssues.map(\.detail).joined(separator: "\n"))
        }
    }

    func testExistingCodexAuthFileWithPlaceholderTokenIsNeedsAuth() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "tokens": {
            "access_token": "YOUR_TOKEN",
            "refresh_token": "real-refresh-value"
          }
        }
        """.write(to: codexHome.appendingPathComponent("auth.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let authIssues = report.issues.filter {
                ["codex-auth", "codex-desktop-auth"].contains($0.surfaceID)
            }

            XCTAssertTrue(authIssues.contains {
                $0.code == .serverAuthMissing
                    && $0.state == .needsAuth
                    && $0.title == "Authentication credential is empty"
                    && $0.detail.contains("tokens.access_token")
                    && !$0.detail.contains("YOUR_TOKEN")
                    && !$0.detail.contains("real-refresh-value")
            }, authIssues.map(\.detail).joined(separator: "\n"))
        }
    }

    func testExistingCodexAuthFileExpiresInDurationIsNotTreatedAsExpired() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "tokens": {
            "access_token": "live-access-token",
            "refresh_token": "live-refresh-token",
            "expires_in": 3600
          }
        }
        """.write(to: codexHome.appendingPathComponent("auth.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let authIssues = report.issues.filter {
                ["codex-auth", "codex-desktop-auth"].contains($0.surfaceID)
            }

            XCTAssertFalse(authIssues.contains {
                $0.code == .serverAuthExpired
                    || $0.code == .serverAuthMissing
            }, authIssues.map(\.detail).joined(separator: "\n"))
        }
    }

    func testCodexMCPEnvHTTPHeadersAndLocalEnvVarsAreReportedMissing() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        [mcp_servers.supabase]
        url = "https://mcp.supabase.com/mcp?project_ref=example"
        startup_timeout_sec = 12.5
        tool_timeout_sec = 70

        [mcp_servers.supabase.env_http_headers]
        Authorization = "PROJECTHUB_MISSING_HEADER_MCP_ENV"

        [mcp_servers.context7]
        command = "/bin/echo"
        env_vars = ["PROJECTHUB_MISSING_LOCAL_MCP_ENV", { name = "PROJECTHUB_REMOTE_ONLY_MCP_ENV", source = "remote" }]
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withEnvironmentVariablesUnset([
            "PROJECTHUB_MISSING_LOCAL_MCP_ENV",
            "PROJECTHUB_REMOTE_ONLY_MCP_ENV",
            "PROJECTHUB_MISSING_HEADER_MCP_ENV"
        ]) {
            withCodexHome(codexHome.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let missingEnvIssues = report.issues.filter {
                    $0.code == .serverEnvMissing
                        && $0.title == "Missing environment variable"
                }
                let details = missingEnvIssues.map(\.detail).joined(separator: "\n")

                XCTAssertTrue(details.contains("PROJECTHUB_MISSING_LOCAL_MCP_ENV"), details)
                XCTAssertTrue(details.contains("PROJECTHUB_MISSING_HEADER_MCP_ENV"), details)
                XCTAssertFalse(details.contains("PROJECTHUB_REMOTE_ONLY_MCP_ENV"), details)
                XCTAssertTrue(report.servers.contains {
                    $0.name == "supabase" && $0.health == .needsAuth
                })
                let supabase = report.servers.first { server in
                    server.name == "supabase"
                        && server.toolID.rawValue == "codexCLI"
                        && server.path == codexHome.appendingPathComponent("config.toml").path
                }
                let supabaseEntry = supabase.flatMap {
                    CompatibilityScanner.healthEntry(for: $0, matrix: report.matrix)
                }
                XCTAssertEqual(supabase?.startupTimeoutSeconds, 12.5)
                XCTAssertEqual(supabase?.toolTimeoutSeconds, 70)
                XCTAssertEqual(supabaseEntry?.startupTimeoutSeconds, 12.5)
                XCTAssertEqual(supabaseEntry?.toolTimeoutSeconds, 70)
                XCTAssertTrue(report.servers.contains {
                    $0.name == "context7" && $0.health == .needsAuth
                })
            }
        }
    }

    func testInputVariablePlaceholdersAreReportedAsPromptBackedAuth() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        try """
        {
          "inputs": [
            {
              "type": "promptString",
              "id": "perplexity-key",
              "description": "Perplexity API Key",
              "password": true
            }
          ],
          "mcpServers": {
            "perplexity": {
              "command": "npx",
              "args": ["-y", "server-perplexity-ask"],
              "env": {
                "PERPLEXITY_API_KEY": "${input:perplexity-key}"
              }
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let inputIssue = report.issues.first {
                $0.code == .serverAuthMissing
                    && $0.title == "Input variable prompt required"
                    && $0.surfaceID == "claude-code-project-mcp"
            }

            XCTAssertNotNil(inputIssue, report.issues.map(\.detail).joined(separator: "\n"))
            XCTAssertTrue(inputIssue?.detail.contains("perplexity-key") == true)
            XCTAssertTrue(report.servers.contains {
                $0.name == "perplexity"
                    && $0.surfaceID == "claude-code-project-mcp"
                    && $0.health == .needsAuth
            })
        }
    }

    func testEditorEnvTemplatesAreReportedMissing() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "editor-token": {
              "type": "stdio",
              "command": "${env:PROJECTHUB_MISSING_EDITOR_MCP_BIN}",
              "args": ["--token", "${env:PROJECTHUB_MISSING_EDITOR_TOKEN}"],
              "env": {
                "EXAMPLE_TOKEN": "${env:PROJECTHUB_MISSING_EDITOR_ENV_VALUE}"
              }
            },
            "remote-editor-token": {
              "type": "http",
              "url": "https://${env:PROJECTHUB_MISSING_EDITOR_HOST}/mcp",
              "headers": {
                "Authorization": "Bearer ${env:PROJECTHUB_MISSING_EDITOR_HEADER}"
              }
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withEnvironmentVariablesUnset([
            "PROJECTHUB_MISSING_EDITOR_MCP_BIN",
            "PROJECTHUB_MISSING_EDITOR_TOKEN",
            "PROJECTHUB_MISSING_EDITOR_ENV_VALUE",
            "PROJECTHUB_MISSING_EDITOR_HOST",
            "PROJECTHUB_MISSING_EDITOR_HEADER"
        ]) {
            withCodexHome(codexHome.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let details = report.issues
                    .filter { $0.code == .serverEnvMissing }
                    .map(\.detail)
                    .joined(separator: "\n")

                XCTAssertTrue(details.contains("PROJECTHUB_MISSING_EDITOR_MCP_BIN"), details)
                XCTAssertTrue(details.contains("PROJECTHUB_MISSING_EDITOR_TOKEN"), details)
                XCTAssertTrue(details.contains("PROJECTHUB_MISSING_EDITOR_ENV_VALUE"), details)
                XCTAssertTrue(details.contains("PROJECTHUB_MISSING_EDITOR_HOST"), details)
                XCTAssertTrue(details.contains("PROJECTHUB_MISSING_EDITOR_HEADER"), details)
                XCTAssertFalse(report.issues.contains {
                    $0.code == .serverCommandMissing
                        && $0.detail.contains("editor-token")
                }, report.issues.map(\.detail).joined(separator: "\n"))
                XCTAssertTrue(report.servers.contains {
                    $0.name == "editor-token"
                        && $0.surfaceID == "claude-code-project-mcp"
                        && $0.health == .needsAuth
                })
                XCTAssertTrue(report.servers.contains {
                    $0.name == "remote-editor-token"
                        && $0.surfaceID == "claude-code-project-mcp"
                        && $0.health == .needsAuth
                })
            }
        }
    }

    func testDockerEnvFlagsAreReportedMissing() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let docker = root.appendingPathComponent("docker")
        try "#!/bin/sh\nexit 0\n".write(to: docker, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: docker.path)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "dockerized": {
              "command": "\(docker.path)",
              "args": ["run", "-i", "--rm", "--env", "PROJECTHUB_MISSING_DOCKER_TOKEN", "ghcr.io/example/mcp-server"]
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withEnvironmentVariablesUnset(["PROJECTHUB_MISSING_DOCKER_TOKEN"]) {
            withCodexHome(codexHome.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let details = report.issues
                    .filter { $0.code == .serverEnvMissing }
                    .map(\.detail)
                    .joined(separator: "\n")

                XCTAssertTrue(details.contains("PROJECTHUB_MISSING_DOCKER_TOKEN"), details)
                XCTAssertTrue(report.servers.contains {
                    $0.name == "dockerized"
                        && $0.surfaceID == "claude-code-project-mcp"
                        && $0.health == .needsAuth
                })
            }
        }
    }

    func testDockerEnvFileAndMountPathsAreReportedMissing() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let docker = root.appendingPathComponent("docker")
        try "#!/bin/sh\nexit 0\n".write(to: docker, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: docker.path)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "dockerized": {
              "command": "\(docker.path)",
              "args": [
                "run",
                "--env-file",
                ".env.missing",
                "--mount",
                "type=bind,source=./missing-data,target=/data",
                "ghcr.io/example/mcp-server"
              ]
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let envDetails = report.issues
                .filter { $0.code == .serverEnvMissing }
                .map(\.detail)
                .joined(separator: "\n")
            let pathDetails = report.issues
                .filter { $0.code == .serverPathMissing }
                .map(\.detail)
                .joined(separator: "\n")

            XCTAssertTrue(envDetails.contains(".env.missing"), envDetails)
            XCTAssertTrue(pathDetails.contains("missing-data"), pathDetails)
            XCTAssertTrue(report.servers.contains {
                $0.name == "dockerized"
                    && $0.surfaceID == "claude-code-project-mcp"
                    && ($0.health == .needsAuth || $0.health == .broken)
            })
        }
    }

    func testEnvWrappedDockerEnvFileAndMountPathsAreReportedMissing() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "dockerized": {
              "command": "/usr/bin/env",
              "args": [
                "docker",
                "run",
                "--env-file",
                ".env.missing",
                "--mount",
                "type=bind,source=./missing-data,target=/data",
                "ghcr.io/example/mcp-server"
              ]
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let envDetails = report.issues
                .filter { $0.code == .serverEnvMissing }
                .map(\.detail)
                .joined(separator: "\n")
            let pathDetails = report.issues
                .filter { $0.code == .serverPathMissing }
                .map(\.detail)
                .joined(separator: "\n")

            XCTAssertTrue(envDetails.contains(".env.missing"), envDetails)
            XCTAssertTrue(pathDetails.contains("missing-data"), pathDetails)
            XCTAssertTrue(report.servers.contains {
                $0.name == "dockerized"
                    && $0.surfaceID == "claude-code-project-mcp"
                    && ($0.health == .needsAuth || $0.health == .broken)
            })
        }
    }

    func testEnvSplitStringDockerEnvFileAndMountPathsAreReportedMissing() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "dockerized": {
              "command": "/usr/bin/env",
              "args": [
                "-S",
                "docker run --env-file .env.missing --mount type=bind,source=./missing-data,target=/data ghcr.io/example/mcp-server"
              ]
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let envDetails = report.issues
                .filter { $0.code == .serverEnvMissing }
                .map(\.detail)
                .joined(separator: "\n")
            let pathDetails = report.issues
                .filter { $0.code == .serverPathMissing }
                .map(\.detail)
                .joined(separator: "\n")

            XCTAssertTrue(envDetails.contains(".env.missing"), envDetails)
            XCTAssertTrue(pathDetails.contains("missing-data"), pathDetails)
        }
    }

    func testDockerPathVariablesAreReportedBeforePathLookup() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let docker = root.appendingPathComponent("docker")
        try "#!/bin/sh\nexit 0\n".write(to: docker, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: docker.path)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "dockerized": {
              "command": "\(docker.path)",
              "args": [
                "run",
                "--env-file",
                "${env:PROJECTHUB_DOCKER_ENV_FILE_PATH}",
                "--mount",
                "type=bind,source=${input:data-dir},target=/data",
                "ghcr.io/example/mcp-server"
              ]
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withEnvironmentVariablesUnset(["PROJECTHUB_DOCKER_ENV_FILE_PATH"]) {
            withCodexHome(codexHome.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let dockerPathDetails = report.issues
                    .filter { $0.title == "Missing Docker path variable" }
                    .map(\.detail)
                    .joined(separator: "\n")
                let inputDetails = report.issues
                    .filter { $0.title == "Input variable prompt required" }
                    .map(\.detail)
                    .joined(separator: "\n")
                let pathDetails = report.issues
                    .filter { $0.title == "Missing Docker mount path" || $0.title == "Missing Docker env file" }
                    .map(\.detail)
                    .joined(separator: "\n")

                XCTAssertTrue(dockerPathDetails.contains("PROJECTHUB_DOCKER_ENV_FILE_PATH"), dockerPathDetails)
                XCTAssertTrue(inputDetails.contains("data-dir"), inputDetails)
                XCTAssertFalse(pathDetails.contains("PROJECTHUB_DOCKER_ENV_FILE_PATH"), pathDetails)
                XCTAssertFalse(pathDetails.contains("data-dir"), pathDetails)
            }
        }
    }

    func testDockerMountDuplicateFieldsAreReportedWithoutCrashing() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let docker = root.appendingPathComponent("docker")
        try "#!/bin/sh\nexit 0\n".write(to: docker, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: docker.path)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "dockerized": {
              "command": "\(docker.path)",
              "args": [
                "run",
                "--mount",
                "type=bind,source=./old,source=./missing-data,target=/data",
                "ghcr.io/example/mcp-server"
              ]
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let pathDetails = report.issues
                .filter { $0.code == .serverPathMissing }
                .map(\.detail)
                .joined(separator: "\n")

            XCTAssertTrue(pathDetails.contains("missing-data"), pathDetails)
        }
    }

    func testDockerNamedVolumesDoNotReportMissingHostPaths() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let docker = root.appendingPathComponent("docker")
        try "#!/bin/sh\nexit 0\n".write(to: docker, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: docker.path)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "short-volume": {
              "command": "\(docker.path)",
              "args": ["run", "-v", "projecthub-cache:/data", "ghcr.io/example/mcp-server"]
            },
            "structured-volume": {
              "command": "\(docker.path)",
              "args": ["run", "--mount", "type=volume,source=projecthub-cache,target=/data", "ghcr.io/example/mcp-server"]
            },
            "plain-bind": {
              "command": "\(docker.path)",
              "args": ["run", "--mount", "type=bind,source=missing-data,target=/data", "ghcr.io/example/mcp-server"]
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let pathDetails = report.issues
                .filter { $0.code == .serverPathMissing }
                .map(\.detail)
                .joined(separator: "\n")

            XCTAssertFalse(pathDetails.contains("projecthub-cache"), pathDetails)
            XCTAssertTrue(pathDetails.contains("plain-bind"), pathDetails)
            XCTAssertTrue(pathDetails.contains("missing-data"), pathDetails)
        }
    }

    func testCodexLiteralEnvTemplatesAreReportedEvenWhenEnvironmentIsSet() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        [mcp_servers.local_secret]
        command = "/bin/echo"
        env = { API_KEY = "${PROJECTHUB_PRESENT_LITERAL_ENV_TOKEN}" }

        [mcp_servers.remote_secret]
        url = "https://example.com/mcp"
        http_headers = { Authorization = "Bearer ${env:PROJECTHUB_PRESENT_LITERAL_HEADER_TOKEN}" }
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withEnvironmentVariables([
            "PROJECTHUB_PRESENT_LITERAL_ENV_TOKEN": "env-secret",
            "PROJECTHUB_PRESENT_LITERAL_HEADER_TOKEN": "header-secret"
        ]) {
            withCodexHome(codexHome.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let details = report.issues
                    .filter { $0.code == .serverEnvMissing }
                    .map { "\($0.title): \($0.detail)" }
                    .joined(separator: "\n")

                XCTAssertTrue(details.contains("Codex env template is literal"), details)
                XCTAssertTrue(details.contains("PROJECTHUB_PRESENT_LITERAL_ENV_TOKEN"), details)
                XCTAssertTrue(details.contains("Codex header template is literal"), details)
                XCTAssertTrue(details.contains("PROJECTHUB_PRESENT_LITERAL_HEADER_TOKEN"), details)
                XCTAssertTrue(report.servers.contains {
                    $0.name == "local_secret" && $0.health == .needsAuth
                })
                XCTAssertTrue(report.servers.contains {
                    $0.name == "remote_secret" && $0.health == .needsAuth
                })
            }
        }
    }

    func testEnvFileIsReportedAsAppSpecificMCPAuthSetup() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "perplexity": {
              "command": "npx",
              "args": ["-y", "server-perplexity-ask"],
              "envFile": "${workspaceFolder}/.env"
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let envFileIssue = report.issues.first {
                $0.code == .serverEnvMissing
                    && $0.title == "Missing MCP env file"
                    && $0.surfaceID == "claude-code-project-mcp"
            }
            let server = report.servers.first {
                $0.name == "perplexity"
                    && $0.surfaceID == "claude-code-project-mcp"
            }
            let entry = server.flatMap {
                CompatibilityScanner.healthEntry(for: $0, matrix: report.matrix)
            }

            XCTAssertNotNil(envFileIssue, report.issues.map(\.detail).joined(separator: "\n"))
            XCTAssertTrue(envFileIssue?.detail.contains("envFile ${workspaceFolder}/.env") == true)
            XCTAssertEqual(server?.health, .needsAuth)
            XCTAssertEqual(entry?.envFile, "${workspaceFolder}/.env")
        }
    }

    func testEnvFilePathEnvTemplateIsReportedWithoutGenericEnvFileNoise() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "env-file-path": {
              "command": "/bin/echo",
              "envFile": "${env:PROJECTHUB_MISSING_ENV_FILE_PATH}"
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withEnvironmentVariablesUnset(["PROJECTHUB_MISSING_ENV_FILE_PATH"]) {
            withCodexHome(codexHome.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let envIssues = report.issues.filter {
                    $0.surfaceID == "claude-code-project-mcp"
                        && $0.code == .serverEnvMissing
                }
                let details = envIssues.map { "\($0.title): \($0.detail)" }.joined(separator: "\n")

                XCTAssertTrue(details.contains("Missing envFile path variable"), details)
                XCTAssertTrue(details.contains("PROJECTHUB_MISSING_ENV_FILE_PATH"), details)
                XCTAssertFalse(details.contains("Missing MCP env file"), details)
                XCTAssertFalse(details.contains("MCP env file requires conversion"), details)
            }
        }
    }

    func testUserHomeEnvFilePlaceholderReportsMissingFile() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let envFile = "${userHome}/projecthub-missing-env-\(UUID().uuidString)"
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "user-home-env": {
              "command": "/bin/echo",
              "envFile": "\(envFile)"
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let details = report.issues
                .filter { $0.surfaceID == "claude-code-project-mcp" && $0.code == .serverEnvMissing }
                .map { "\($0.title): \($0.detail)" }
                .joined(separator: "\n")

            XCTAssertTrue(details.contains("Missing MCP env file"), details)
            XCTAssertTrue(details.contains(envFile), details)
            XCTAssertFalse(details.contains("MCP env file requires conversion"), details)
        }
    }

    func testMissingMCPWorkingDirectoryIsReportedBroken() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "workspace-tool": {
              "command": "/bin/echo",
              "cwd": "${workspaceFolder}/missing-tools"
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let cwdIssue = report.issues.first {
                $0.code == .serverPathMissing
                    && $0.title == "Working directory not found"
                    && $0.surfaceID == "claude-code-project-mcp"
            }
            let server = report.servers.first {
                $0.name == "workspace-tool"
                    && $0.surfaceID == "claude-code-project-mcp"
            }
            let entry = server.flatMap {
                CompatibilityScanner.healthEntry(for: $0, matrix: report.matrix)
            }

            XCTAssertNotNil(cwdIssue, report.issues.map(\.detail).joined(separator: "\n"))
            XCTAssertEqual(server?.health, .broken)
            XCTAssertEqual(entry?.cwd, "${workspaceFolder}/missing-tools")
        }
    }

    func testUserHomeCWDPlaceholderReportsMissingDirectory() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let cwd = "${userHome}/projecthub-missing-cwd-\(UUID().uuidString)"
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "user-home-cwd": {
              "command": "/bin/echo",
              "cwd": "\(cwd)"
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let issue = report.issues.first {
                $0.code == .serverPathMissing
                    && $0.title == "Working directory not found"
                    && $0.surfaceID == "claude-code-project-mcp"
            }

            XCTAssertNotNil(issue, report.issues.map(\.detail).joined(separator: "\n"))
            XCTAssertTrue(issue?.detail.contains(cwd) == true)
        }
    }

    func testVSCodeSandboxAndDevModeAreReportedAsAppSpecificRuntime() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "sandboxed-tool": {
              "command": "/bin/echo",
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
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let sandboxIssue = report.issues.first {
                $0.code == .serverRuntimeManaged
                    && $0.title == "VS Code MCP sandbox is app-specific"
                    && $0.surfaceID == "claude-code-project-mcp"
            }
            let devIssue = report.issues.first {
                $0.code == .serverRuntimeManaged
                    && $0.title == "VS Code MCP dev mode is app-specific"
                    && $0.surfaceID == "claude-code-project-mcp"
            }
            let server = report.servers.first {
                $0.name == "sandboxed-tool"
                    && $0.surfaceID == "claude-code-project-mcp"
            }
            let entry = server.flatMap {
                CompatibilityScanner.healthEntry(for: $0, matrix: report.matrix)
            }

            XCTAssertNotNil(sandboxIssue, report.issues.map(\.detail).joined(separator: "\n"))
            XCTAssertNotNil(devIssue, report.issues.map(\.detail).joined(separator: "\n"))
            XCTAssertEqual(server?.health, .unknown)
            XCTAssertEqual(entry?.sandboxEnabled, true)
            XCTAssertEqual(entry?.sandboxSummary, "{filesystem, network}")
            XCTAssertEqual(entry?.devSummary, "{debug, watch}")
        }
    }

    func testRooToolControlMetadataIsReportedAsAppSpecificRuntime() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "roo-tool": {
              "command": "/bin/echo",
              "alwaysAllow": ["search"],
              "disabledTools": ["write"],
              "watchPaths": ["src/server.ts"],
              "timeout": 120
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let runtimeIssue = report.issues.first {
                $0.code == .serverRuntimeManaged
                    && $0.title == "Roo MCP tool controls are app-specific"
                    && $0.surfaceID == "claude-code-project-mcp"
            }
            let server = report.servers.first {
                $0.name == "roo-tool"
                    && $0.surfaceID == "claude-code-project-mcp"
            }
            let entry = server.flatMap {
                CompatibilityScanner.healthEntry(for: $0, matrix: report.matrix)
            }

            XCTAssertNotNil(runtimeIssue, report.issues.map(\.detail).joined(separator: "\n"))
            XCTAssertEqual(server?.health, .unknown)
            XCTAssertEqual(entry?.alwaysAllowTools, ["search"])
            XCTAssertEqual(entry?.disabledTools, ["write"])
            XCTAssertEqual(entry?.watchPaths, ["src/server.ts"])
            XCTAssertEqual(entry?.serverTimeoutSeconds, 120)
            XCTAssertEqual(entry?.toolTimeoutSeconds, 120)
        }
    }

    func testCodexDirectToolControlsAreNotReportedAsRooSpecific() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        try """
        [mcp_servers.docs]
        command = "npx"
        args = ["-y", "@example/docs"]
        enabled_tools = ["search"]
        disabled_tools = ["write"]
        default_tools_approval_mode = "prompt"

        [mcp_servers.docs.tools.search]
        approval_mode = "approve"
        """.write(to: project.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let server = report.servers.first {
                $0.name == "docs"
                    && $0.surfaceID == "codex-cli-project-mcp"
            }
            let entry = server.flatMap {
                CompatibilityScanner.healthEntry(for: $0, matrix: report.matrix)
            }

            XCTAssertNotNil(server, report.servers.map { "\($0.surfaceID):\($0.name)" }.joined(separator: "\n"))
            XCTAssertFalse(report.issues.contains {
                $0.code == .serverRuntimeManaged
                    && $0.title == "Roo MCP tool controls are app-specific"
                    && $0.surfaceID == "codex-cli-project-mcp"
            }, report.issues.map(\.detail).joined(separator: "\n"))
            XCTAssertEqual(entry?.enabledTools, ["search"])
            XCTAssertEqual(entry?.disabledTools, ["write"])
            XCTAssertEqual(entry?.defaultToolApprovalMode, "prompt")
            XCTAssertEqual(entry?.toolApprovalModes["search"], "approve")
        }
    }

    func testSupabaseStyleBearerHeaderTemplateIsReportedMissing() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        [mcp_servers.supabase]
        url = "https://mcp.supabase.com/mcp?project_ref=example"
        http_headers = { Authorization = "Bearer ${PROJECTHUB_MISSING_SUPABASE_PAT}" }
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withEnvironmentVariablesUnset(["PROJECTHUB_MISSING_SUPABASE_PAT"]) {
            withCodexHome(codexHome.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let details = report.issues
                    .filter { $0.code == .serverEnvMissing }
                    .map(\.detail)
                    .joined(separator: "\n")

                XCTAssertTrue(details.contains("PROJECTHUB_MISSING_SUPABASE_PAT"), details)
                XCTAssertTrue(report.servers.contains {
                    $0.name == "supabase" && $0.health == .needsAuth
                })
            }
        }
    }

    func testSupabaseHostedOAuthConfigIsReportedNeedsAuthWithoutPATHeader() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        [mcp_servers.supabase]
        type = "http"
        url = "https://mcp.supabase.com/mcp"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let oauthIssue = report.issues.first {
                $0.code == .serverOAuthNeeded
                    && $0.title == "Hosted MCP OAuth required"
                    && $0.detail.contains("Supabase")
            }

            XCTAssertNotNil(oauthIssue, report.issues.map(\.detail).joined(separator: "\n"))
            XCTAssertTrue(report.servers.contains {
                $0.name == "supabase" && $0.health == .needsAuth
            })
        }
    }

    func testKnownHostedOAuthProvidersAreReportedNeedsAuthWithoutPATHeader() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        [mcp_servers.github]
        type = "http"
        url = "https://api.githubcopilot.com/mcp/"

        [mcp_servers.notion]
        type = "http"
        url = "https://mcp.notion.com/mcp"

        [mcp_servers.atlassian]
        type = "http"
        url = "https://mcp.atlassian.com/v1/mcp/authv2"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let details = report.issues
                .filter { $0.code == .serverOAuthNeeded && $0.title == "Hosted MCP OAuth required" }
                .map(\.detail)
                .joined(separator: "\n")

            XCTAssertTrue(details.contains("GitHub"), details)
            XCTAssertTrue(details.contains("Notion"), details)
            XCTAssertTrue(details.contains("Atlassian"), details)
            XCTAssertTrue(report.servers.contains { $0.name == "github" && $0.health == .needsAuth })
            XCTAssertTrue(report.servers.contains { $0.name == "notion" && $0.health == .needsAuth })
            XCTAssertTrue(report.servers.contains { $0.name == "atlassian" && $0.health == .needsAuth })
        }
    }

    func testPlaceholderOAuthMetadataDoesNotSuppressHostedOAuthMissingAuth() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "supabase": {
              "url": "https://mcp.supabase.com/mcp",
              "oauth": {
                "clientId": "your-client-id",
                "authServerMetadataUrl": "..."
              }
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let hostedOAuthDetails = report.issues
                .filter { $0.surfaceID == "claude-code-project-mcp" && $0.code == .serverOAuthNeeded && $0.title == "Hosted MCP OAuth required" }
                .map(\.detail)
                .joined(separator: "\n")
            let appOAuthDetails = report.issues
                .filter { $0.surfaceID == "claude-code-project-mcp" && $0.code == .serverAuthRuntimeManaged && $0.title == "Auth managed by target tool OAuth" }
                .map(\.detail)
                .joined(separator: "\n")

            XCTAssertTrue(hostedOAuthDetails.contains("supabase"), hostedOAuthDetails)
            XCTAssertFalse(appOAuthDetails.contains("supabase"), appOAuthDetails)
        }
    }

    func testRealOAuthMetadataSuppressesHostedOAuthMissingAuth() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {
            "supabase": {
              "url": "https://mcp.supabase.com/mcp",
              "oauth": {
                "clientId": "projecthub-client",
                "authServerMetadataUrl": "https://example.com/.well-known/oauth-authorization-server"
              }
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let hostedOAuthDetails = report.issues
                .filter { $0.surfaceID == "claude-code-project-mcp" && $0.code == .serverOAuthNeeded && $0.title == "Hosted MCP OAuth required" }
                .map(\.detail)
                .joined(separator: "\n")
            let appOAuthDetails = report.issues
                .filter { $0.surfaceID == "claude-code-project-mcp" && $0.code == .serverAuthRuntimeManaged && $0.title == "Auth managed by target tool OAuth" }
                .map(\.detail)
                .joined(separator: "\n")

            let allIssues = report.issues
                .map { "\($0.surfaceID ?? "-"): \($0.title): \($0.detail)" }
                .joined(separator: "\n")
            XCTAssertFalse(hostedOAuthDetails.contains("supabase"), allIssues)
            XCTAssertTrue(appOAuthDetails.contains("supabase"), appOAuthDetails)
        }
    }

    private func withCodexHome(_ path: String, run: () throws -> Void) rethrows {
        let previous = getenv("CODEX_HOME").map { String(cString: $0) }
        let previousClaudeHome = getenv("PROJECTHUB_CLAUDE_HOME").map { String(cString: $0) }
        let previousClaudeJSONPath = getenv("PROJECTHUB_CLAUDE_JSON_PATH").map { String(cString: $0) }
        let previousClaudeCommandPath = getenv("PROJECTHUB_CLAUDE_COMMAND_PATH").map { String(cString: $0) }
        let codexAuthEnvKeys = [
            "CODEX_ACCESS_TOKEN",
            "OPENAI_API_KEY"
        ]
        let previousCodexAuthEnv = Dictionary(uniqueKeysWithValues: codexAuthEnvKeys.map { key in
            (key, getenv(key).map { String(cString: $0) })
        })
        let claudeAuthEnvKeys = [
            "CLAUDE_CODE_USE_ANTHROPIC_AWS",
            "CLAUDE_CODE_USE_BEDROCK",
            "CLAUDE_CODE_USE_VERTEX",
            "CLAUDE_CODE_USE_FOUNDRY",
            "CLAUDE_CODE_USE_MANTLE",
            "ANTHROPIC_AUTH_TOKEN",
            "ANTHROPIC_API_KEY",
            "CLAUDE_CODE_OAUTH_TOKEN"
        ]
        let previousClaudeAuthEnv = Dictionary(uniqueKeysWithValues: claudeAuthEnvKeys.map { key in
            (key, getenv(key).map { String(cString: $0) })
        })
        let isolatedClaudeHome = (path as NSString).appendingPathComponent("isolated-claude-home")
        let isolatedClaudeJSONPath = (path as NSString).appendingPathComponent("claude.json")
        let missingClaudeCommandPath = (path as NSString).appendingPathComponent("missing-claude")
        setenv("CODEX_HOME", path, 1)
        setenv("PROJECTHUB_CLAUDE_HOME", isolatedClaudeHome, 1)
        setenv("PROJECTHUB_CLAUDE_JSON_PATH", isolatedClaudeJSONPath, 1)
        setenv("PROJECTHUB_CLAUDE_COMMAND_PATH", missingClaudeCommandPath, 1)
        for key in codexAuthEnvKeys {
            unsetenv(key)
        }
        for key in claudeAuthEnvKeys {
            unsetenv(key)
        }
        defer {
            if let previous {
                setenv("CODEX_HOME", previous, 1)
            } else {
                unsetenv("CODEX_HOME")
            }
            if let previousClaudeHome {
                setenv("PROJECTHUB_CLAUDE_HOME", previousClaudeHome, 1)
            } else {
                unsetenv("PROJECTHUB_CLAUDE_HOME")
            }
            if let previousClaudeJSONPath {
                setenv("PROJECTHUB_CLAUDE_JSON_PATH", previousClaudeJSONPath, 1)
            } else {
                unsetenv("PROJECTHUB_CLAUDE_JSON_PATH")
            }
            if let previousClaudeCommandPath {
                setenv("PROJECTHUB_CLAUDE_COMMAND_PATH", previousClaudeCommandPath, 1)
            } else {
                unsetenv("PROJECTHUB_CLAUDE_COMMAND_PATH")
            }
            for key in codexAuthEnvKeys {
                let value = previousCodexAuthEnv[key] ?? nil
                if let value {
                    setenv(key, value, 1)
                } else {
                    unsetenv(key)
                }
            }
            for key in claudeAuthEnvKeys {
                let value = previousClaudeAuthEnv[key] ?? nil
                if let value {
                    setenv(key, value, 1)
                } else {
                    unsetenv(key)
                }
            }
        }
        try run()
    }

    private func withEnvironmentVariablesUnset(_ keys: [String], run: () throws -> Void) rethrows {
        let previous = Dictionary(uniqueKeysWithValues: keys.map { key in
            (key, getenv(key).map { String(cString: $0) })
        })
        for key in keys {
            unsetenv(key)
        }
        defer {
            for key in keys {
                let value = previous[key] ?? nil
                if let value {
                    setenv(key, value, 1)
                } else {
                    unsetenv(key)
                }
            }
        }
        try run()
    }

    private func withEnvironmentVariables(_ values: [String: String], run: () throws -> Void) rethrows {
        let previous = Dictionary(uniqueKeysWithValues: values.keys.map { key in
            (key, getenv(key).map { String(cString: $0) })
        })
        for (key, value) in values {
            setenv(key, value, 1)
        }
        defer {
            for key in values.keys {
                let value = previous[key] ?? nil
                if let value {
                    setenv(key, value, 1)
                } else {
                    unsetenv(key)
                }
            }
        }
        try run()
    }

    private func makeTempDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubCompatibilityMCPAuthTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }
}
