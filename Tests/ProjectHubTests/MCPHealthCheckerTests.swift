import XCTest
import Network
@testable import ProjectHub

final class MCPHealthCheckerTests: XCTestCase {
    func testVerifyStdioServerCompletesInitializeAndToolsList() async throws {
        let script = try makeExecutableScript("""
        #!/bin/sh
        while IFS= read -r line; do
          case "$line" in
            *'"id":1'*)
              printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{},"serverInfo":{"name":"fixture","version":"1.0.0"}}}'
              ;;
            *'"id":2'*)
              printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"echo","description":"Echo","inputSchema":{"type":"object"}}]}}'
              exit 0
              ;;
          esac
        done
        """)

        let report = await MCPHealthChecker.verify(
            server: server(command: script.path),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .working)
        XCTAssertTrue(report.summary.contains("tools/list verified"))
        XCTAssertTrue(report.summary.contains("1 tool"))
    }

    func testVerifyStdioUsesConfiguredCWDForRelativeCommand() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubMCPWorkingDirectory-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        let script = directory.appendingPathComponent("fixture-mcp.sh")
        try """
        #!/bin/sh
        while IFS= read -r line; do
          case "$line" in
            *'"id":1'*)
              printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{},"serverInfo":{"name":"fixture","version":"1.0.0"}}}'
              ;;
            *'"id":2'*)
              printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"tools":[]}}'
              exit 0
              ;;
          esac
        done
        """.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

        let report = await MCPHealthChecker.verify(
            server: server(command: "./fixture-mcp.sh", cwd: directory.path),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .working, report.summary)
    }

    func testEvaluateMissingCWDIsBroken() {
        let report = MCPHealthChecker.evaluate(
            server: server(command: "/bin/echo", cwd: "/tmp/projecthub-missing-cwd-\(UUID().uuidString)"),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .broken)
        XCTAssertTrue(report.summary.contains("Working directory not found"))
    }

    func testEvaluateUserHomeCWDPlaceholderChecksResolvedDirectory() {
        let missing = "${userHome}/projecthub-missing-cwd-\(UUID().uuidString)"
        let report = MCPHealthChecker.evaluate(
            server: server(command: "/bin/echo", cwd: missing),
            toolID: "vscode",
            configPath: "/tmp/projecthub-userhome-cwd/.vscode/mcp.json"
        )

        XCTAssertEqual(report.status, .broken)
        XCTAssertTrue(report.summary.contains("Working directory not found"))
    }

    func testEvaluateUnsupportedRemoteTransportIsBrokenBeforeURLProbe() {
        let report = MCPHealthChecker.evaluate(
            server: remoteServer(url: "https://example.com/mcp", transport: "websocket"),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .broken)
        XCTAssertEqual(report.summary, "Unsupported transport: websocket")
    }

    func testVerifyUnsupportedRemoteTransportReturnsPreflightBroken() async {
        let report = await MCPHealthChecker.verify(
            server: remoteServer(url: "https://example.com/mcp", transport: "websocket"),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .broken)
        XCTAssertEqual(report.summary, "Unsupported transport: websocket")
    }

    func testEvaluateClaudeCodeWebSocketTransportIsManualVerifyUnknown() {
        let report = MCPHealthChecker.evaluate(
            server: remoteServer(url: "wss://example.com/socket", transport: "ws"),
            toolID: "claude-code"
        )

        XCTAssertEqual(report.status, .unknown)
        XCTAssertEqual(report.summary, "WebSocket MCP configured")
        XCTAssertTrue(report.fixHint?.contains("Claude Code /mcp") == true)
    }

    func testVerifyClaudeCodeWebSocketTransportReturnsPreflightUnknown() async {
        let report = await MCPHealthChecker.verify(
            server: remoteServer(url: "wss://example.com/socket", transport: "ws"),
            toolID: "claude-code"
        )

        XCTAssertEqual(report.status, .unknown)
        XCTAssertEqual(report.summary, "WebSocket MCP configured")
    }

    func testVerifyStdioUsesConfiguredStartupTimeout() async throws {
        let script = try makeExecutableScript("""
        #!/bin/sh
        sleep 2
        """)

        let startedAt = Date()
        let report = await MCPHealthChecker.verify(
            server: server(command: script.path, startupTimeoutSeconds: 1),
            toolID: "codex"
        )
        let elapsed = Date().timeIntervalSince(startedAt)

        XCTAssertEqual(report.status, .unknown)
        XCTAssertEqual(report.summary, "No MCP initialize response")
        XCTAssertEqual(report.fixHint, "The process launched but did not answer within 1 seconds.")
        XCTAssertLessThan(elapsed, 1.8)
    }

    func testVerifyStdioUsesClaudeMCPTimeoutEnvironment() async throws {
        let script = try makeExecutableScript("""
        #!/bin/sh
        sleep 2
        """)

        let startedAt = Date()
        let report = await withEnvironmentVariable("MCP_TIMEOUT", value: "500") {
            await MCPHealthChecker.verify(
                server: server(command: script.path),
                toolID: "claude-code"
            )
        }
        let elapsed = Date().timeIntervalSince(startedAt)

        XCTAssertEqual(report.status, .unknown)
        XCTAssertEqual(report.summary, "No MCP initialize response")
        XCTAssertEqual(report.fixHint, "The process launched but did not answer within 0.5 seconds.")
        XCTAssertLessThan(elapsed, 1.2)
    }

    func testVerifyStdioInitializeAuthErrorNeedsAuthAndRedactsSecret() async throws {
        let script = try makeExecutableScript("""
        #!/bin/sh
        while IFS= read -r line; do
          case "$line" in
            *'"id":1'*)
              printf '%s\n' '{"jsonrpc":"2.0","id":1,"error":{"code":-32001,"message":"Unauthorized token=secret123"}}'
              exit 0
              ;;
          esac
        done
        """)

        let report = await MCPHealthChecker.verify(
            server: server(command: script.path),
            toolID: "claude-code"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertTrue(report.summary.contains("requires authentication"))
        XCTAssertTrue(report.summary.contains("token=[redacted]"))
        XCTAssertFalse(report.summary.contains("secret123"))
    }

    func testVerifyStdioExpiredAuthErrorIsAuthExpiredAndRedactsSecret() async throws {
        let script = try makeExecutableScript("""
        #!/bin/sh
        while IFS= read -r line; do
          case "$line" in
            *'"id":1'*)
              printf '%s\n' '{"jsonrpc":"2.0","id":1,"error":{"code":-32001,"message":"Token has expired token=secret123"}}'
              exit 0
              ;;
          esac
        done
        """)

        let report = await MCPHealthChecker.verify(
            server: server(command: script.path),
            toolID: "claude-code"
        )

        XCTAssertEqual(report.status, .authExpired)
        XCTAssertTrue(report.summary.contains("auth expired"))
        XCTAssertTrue(report.summary.contains("token=[redacted]"))
        XCTAssertFalse(report.summary.contains("secret123"))
    }

    func testEvaluateMissingCredentialPlaceholderNeedsAuth() {
        let report = MCPHealthChecker.evaluate(
            server: server(
                command: "/bin/echo",
                args: ["--api-key", "<YOUR_API_KEY>"]
            ),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertEqual(report.summary, "Missing launch credential")
    }

    func testEvaluateStdioLaunchArgEnvTemplateNeedsAuth() {
        withEnvironmentVariablesUnset(["PROJECTHUB_MISSING_ARG_MCP_TOKEN"]) {
            let report = MCPHealthChecker.evaluate(
                server: server(
                    command: "/bin/echo",
                    args: ["--api-key", "${PROJECTHUB_MISSING_ARG_MCP_TOKEN}"]
                ),
                toolID: "codex"
            )

            XCTAssertEqual(report.status, .needsAuth)
            XCTAssertEqual(report.summary, "Missing launch environment variable: PROJECTHUB_MISSING_ARG_MCP_TOKEN")
        }
    }

    func testEvaluateStdioLaunchArgEditorEnvTemplateNeedsAuth() {
        withEnvironmentVariablesUnset(["PROJECTHUB_MISSING_EDITOR_ARG_MCP_TOKEN"]) {
            let report = MCPHealthChecker.evaluate(
                server: server(
                    command: "/bin/echo",
                    args: ["--api-key", "${env:PROJECTHUB_MISSING_EDITOR_ARG_MCP_TOKEN}"]
                ),
                toolID: "vscode"
            )

            XCTAssertEqual(report.status, .needsAuth)
            XCTAssertEqual(report.summary, "Missing launch environment variable: PROJECTHUB_MISSING_EDITOR_ARG_MCP_TOKEN")
        }
    }

    func testEvaluateStdioCommandEnvTemplateNeedsAuthBeforeCommandLookup() {
        withEnvironmentVariablesUnset(["PROJECTHUB_MISSING_MCP_BIN"]) {
            let report = MCPHealthChecker.evaluate(
                server: server(command: "${PROJECTHUB_MISSING_MCP_BIN}"),
                toolID: "claude-code"
            )

            XCTAssertEqual(report.status, .needsAuth)
            XCTAssertEqual(report.summary, "Missing command environment variable: PROJECTHUB_MISSING_MCP_BIN")
        }
    }

    func testEvaluateStdioCommandEditorEnvTemplateNeedsAuthBeforeCommandLookup() {
        withEnvironmentVariablesUnset(["PROJECTHUB_MISSING_EDITOR_MCP_BIN"]) {
            let report = MCPHealthChecker.evaluate(
                server: server(command: "${env:PROJECTHUB_MISSING_EDITOR_MCP_BIN}"),
                toolID: "vscode"
            )

            XCTAssertEqual(report.status, .needsAuth)
            XCTAssertEqual(report.summary, "Missing command environment variable: PROJECTHUB_MISSING_EDITOR_MCP_BIN")
        }
    }

    func testEvaluateStdioCommandEnvTemplateFallbackExpandsBeforeCommandLookup() {
        withEnvironmentVariablesUnset(["PROJECTHUB_OPTIONAL_MCP_BIN"]) {
            let report = MCPHealthChecker.evaluate(
                server: server(command: "${PROJECTHUB_OPTIONAL_MCP_BIN:-/bin/echo}"),
                toolID: "claude-code"
            )

            XCTAssertEqual(report.status, .working)
            XCTAssertEqual(report.summary, "Config looks runnable")
        }
    }

    func testEvaluateStdioLaunchArgEnvTemplateFallbackDoesNotNeedAuth() {
        withEnvironmentVariablesUnset(["PROJECTHUB_OPTIONAL_ARG_MCP_TOKEN"]) {
            let report = MCPHealthChecker.evaluate(
                server: server(
                    command: "/bin/echo",
                    args: ["--api-key", "${PROJECTHUB_OPTIONAL_ARG_MCP_TOKEN:-anonymous}"]
                ),
                toolID: "codex"
            )

            XCTAssertEqual(report.status, .working)
        }
    }

    func testEvaluateDockerEnvFlagNeedsHostEnv() throws {
        let docker = try makeExecutableScript(named: "docker", content: "#!/bin/sh\nexit 0\n")

        withEnvironmentVariablesUnset(["PROJECTHUB_DOCKER_MCP_TOKEN"]) {
            let report = MCPHealthChecker.evaluate(
                server: server(
                    command: docker.path,
                    args: ["run", "-i", "--rm", "--env", "PROJECTHUB_DOCKER_MCP_TOKEN", "ghcr.io/example/mcp-server"]
                ),
                toolID: "claude-code"
            )

            XCTAssertEqual(report.status, .needsAuth)
            XCTAssertEqual(report.summary, "Missing Docker env var: PROJECTHUB_DOCKER_MCP_TOKEN")
        }
    }

    func testEvaluateDockerEnvFileNeedsExistingFile() throws {
        let docker = try makeExecutableScript(named: "docker", content: "#!/bin/sh\nexit 0\n")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubDockerEnvFile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let report = MCPHealthChecker.evaluate(
            server: server(
                command: docker.path,
                args: ["run", "--env-file", ".env.missing", "ghcr.io/example/mcp-server"],
                cwd: directory.path
            ),
            toolID: "claude-code"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertTrue(report.summary.contains("Missing Docker env file"), report.summary)
        XCTAssertTrue(report.summary.contains(".env.missing"), report.summary)
    }

    func testEvaluateEnvWrappedDockerEnvFileNeedsExistingFile() throws {
        let docker = try makeExecutableScript(named: "docker", content: "#!/bin/sh\nexit 0\n")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubEnvWrappedDockerEnvFile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let report = MCPHealthChecker.evaluate(
            server: server(
                command: "/usr/bin/env",
                args: [docker.path, "run", "--env-file", ".env.missing", "ghcr.io/example/mcp-server"],
                cwd: directory.path
            ),
            toolID: "claude-code"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertTrue(report.summary.contains("Missing Docker env file"), report.summary)
        XCTAssertTrue(report.summary.contains(".env.missing"), report.summary)
    }

    func testEvaluateEnvSplitStringDockerEnvFileNeedsExistingFile() throws {
        let docker = try makeExecutableScript(named: "docker", content: "#!/bin/sh\nexit 0\n")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubEnvSplitDockerEnvFile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let report = MCPHealthChecker.evaluate(
            server: server(
                command: "/usr/bin/env",
                args: ["-S", "\(docker.path) run --env-file .env.missing ghcr.io/example/mcp-server"],
                cwd: directory.path
            ),
            toolID: "claude-code"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertTrue(report.summary.contains("Missing Docker env file"), report.summary)
        XCTAssertTrue(report.summary.contains(".env.missing"), report.summary)
    }

    func testEvaluateDockerEnvFilePathVariableNeedsAuthBeforeFileLookup() throws {
        let docker = try makeExecutableScript(named: "docker", content: "#!/bin/sh\nexit 0\n")

        withEnvironmentVariablesUnset(["PROJECTHUB_DOCKER_ENV_FILE_PATH"]) {
            let report = MCPHealthChecker.evaluate(
                server: server(
                    command: docker.path,
                    args: ["run", "--env-file", "${env:PROJECTHUB_DOCKER_ENV_FILE_PATH}", "ghcr.io/example/mcp-server"]
                ),
                toolID: "claude-code"
            )

            XCTAssertEqual(report.status, .needsAuth)
            XCTAssertEqual(report.summary, "Missing Docker path variable: PROJECTHUB_DOCKER_ENV_FILE_PATH")
        }
    }

    func testEvaluateDockerBindMountNeedsExistingHostPath() throws {
        let docker = try makeExecutableScript(named: "docker", content: "#!/bin/sh\nexit 0\n")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubDockerMount-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let report = MCPHealthChecker.evaluate(
            server: server(
                command: docker.path,
                args: ["run", "--mount", "type=bind,source=./missing-data,target=/data", "ghcr.io/example/mcp-server"],
                cwd: directory.path
            ),
            toolID: "claude-code"
        )

        XCTAssertEqual(report.status, .broken)
        XCTAssertTrue(report.summary.contains("Missing Docker mount path"), report.summary)
        XCTAssertTrue(report.summary.contains("missing-data"), report.summary)
    }

    func testEvaluateDockerStructuredBindPlainSourceNeedsExistingHostPath() throws {
        let docker = try makeExecutableScript(named: "docker", content: "#!/bin/sh\nexit 0\n")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubDockerPlainBind-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let report = MCPHealthChecker.evaluate(
            server: server(
                command: docker.path,
                args: ["run", "--mount", "type=bind,source=missing-data,target=/data", "ghcr.io/example/mcp-server"],
                cwd: directory.path
            ),
            toolID: "claude-code"
        )

        XCTAssertEqual(report.status, .broken)
        XCTAssertTrue(report.summary.contains("Missing Docker mount path"), report.summary)
        XCTAssertTrue(report.summary.contains("missing-data"), report.summary)
    }

    func testEvaluateDockerStructuredBindTypeIsCaseInsensitive() throws {
        let docker = try makeExecutableScript(named: "docker", content: "#!/bin/sh\nexit 0\n")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubDockerUpperBind-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let report = MCPHealthChecker.evaluate(
            server: server(
                command: docker.path,
                args: ["run", "--mount", "type=BIND,source=missing-data,target=/data", "ghcr.io/example/mcp-server"],
                cwd: directory.path
            ),
            toolID: "claude-code"
        )

        XCTAssertEqual(report.status, .broken)
        XCTAssertTrue(report.summary.contains("Missing Docker mount path"), report.summary)
        XCTAssertTrue(report.summary.contains("missing-data"), report.summary)
    }

    func testEvaluateDockerNamedVolumesDoNotRequireHostPath() throws {
        let docker = try makeExecutableScript(named: "docker", content: "#!/bin/sh\nexit 0\n")

        let shortVolume = MCPHealthChecker.evaluate(
            server: server(
                command: docker.path,
                args: ["run", "-v", "projecthub-cache:/data", "ghcr.io/example/mcp-server"]
            ),
            toolID: "claude-code"
        )
        let structuredVolume = MCPHealthChecker.evaluate(
            server: server(
                command: docker.path,
                args: ["run", "--mount", "type=volume,source=projecthub-cache,target=/data", "ghcr.io/example/mcp-server"]
            ),
            toolID: "claude-code"
        )

        XCTAssertNotEqual(shortVolume.status, .broken, shortVolume.summary)
        XCTAssertFalse(shortVolume.summary.contains("Missing Docker mount path"), shortVolume.summary)
        XCTAssertNotEqual(structuredVolume.status, .broken, structuredVolume.summary)
        XCTAssertFalse(structuredVolume.summary.contains("Missing Docker mount path"), structuredVolume.summary)
    }

    func testEvaluateDockerMountInputVariableNeedsAuthBeforePathLookup() throws {
        let docker = try makeExecutableScript(named: "docker", content: "#!/bin/sh\nexit 0\n")

        let report = MCPHealthChecker.evaluate(
            server: server(
                command: docker.path,
                args: ["run", "--mount", "type=bind,source=${input:data-dir},target=/data", "ghcr.io/example/mcp-server"]
            ),
            toolID: "vscode"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertEqual(report.summary, "Input variable prompt required: data-dir")
    }

    func testEvaluateDockerMountDuplicateFieldsDoesNotCrash() throws {
        let docker = try makeExecutableScript(named: "docker", content: "#!/bin/sh\nexit 0\n")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubDockerDuplicateMount-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let report = MCPHealthChecker.evaluate(
            server: server(
                command: docker.path,
                args: ["run", "--mount", "type=bind,source=./old,source=./missing-data,target=/data", "ghcr.io/example/mcp-server"],
                cwd: directory.path
            ),
            toolID: "claude-code"
        )

        XCTAssertEqual(report.status, .broken)
        XCTAssertTrue(report.summary.contains("Missing Docker mount path"), report.summary)
        XCTAssertTrue(report.summary.contains("missing-data"), report.summary)
    }

    func testEvaluateInputVariablePromptNeedsAuthBeforeLaunch() {
        let report = MCPHealthChecker.evaluate(
            server: ServerEntry(
                name: "input-fixture",
                transport: "stdio",
                command: "/bin/echo",
                args: ["--api-key", "${input:perplexity-key}"],
                url: nil,
                env: [
                    "PERPLEXITY_API_KEY": "${input:perplexity-key}"
                ],
                headers: [:],
                bearerTokenEnvVar: nil,
                isDisabled: false
            ),
            toolID: "vscode"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertEqual(report.summary, "Input variable prompt required: perplexity-key")
        XCTAssertTrue(report.fixHint?.contains("owning app") == true)
    }

    func testEvaluateEnvFileInputVariableNeedsAuthBeforeFileLookup() {
        let report = MCPHealthChecker.evaluate(
            server: server(command: "/bin/echo", envFile: "${input:env-file-path}"),
            toolID: "vscode",
            configPath: "/tmp/projecthub-envfile-input/.vscode/mcp.json"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertEqual(report.summary, "Input variable prompt required: env-file-path")
    }

    func testEvaluateCWDInputVariableNeedsAuthBeforeLaunch() {
        let report = MCPHealthChecker.evaluate(
            server: server(command: "/bin/echo", cwd: "${input:workspace-root}"),
            toolID: "vscode",
            configPath: "/tmp/projecthub-cwd-input/.vscode/mcp.json"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertEqual(report.summary, "Input variable prompt required: workspace-root")
    }

    func testEvaluateEnvFileNeedsAuthAndReportsMissingFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubEnvFile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory.appendingPathComponent(".vscode", isDirectory: true),
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        let report = MCPHealthChecker.evaluate(
            server: ServerEntry(
                name: "env-file-fixture",
                transport: "stdio",
                command: "/bin/echo",
                args: [],
                url: nil,
                env: [:],
                headers: [:],
                bearerTokenEnvVar: nil,
                envFile: "${workspaceFolder}/.env",
                isDisabled: false
            ),
            toolID: "vscode",
            configPath: directory.appendingPathComponent(".vscode/mcp.json").path
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertEqual(report.summary, "Missing env file: ${workspaceFolder}/.env")
        XCTAssertTrue(report.fixHint?.contains("env file") == true)
    }

    func testEvaluateUserHomeEnvFilePlaceholderChecksResolvedFile() {
        let missing = "${userHome}/projecthub-missing-env-\(UUID().uuidString)"
        let report = MCPHealthChecker.evaluate(
            server: server(command: "/bin/echo", envFile: missing),
            toolID: "vscode",
            configPath: "/tmp/projecthub-userhome-envfile/.vscode/mcp.json"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertEqual(report.summary, "Missing env file: \(missing)")
    }

    func testEvaluateEnvFilePathEditorEnvTemplateNeedsAuthBeforeFileLookup() {
        withEnvironmentVariablesUnset(["PROJECTHUB_MISSING_ENV_FILE_PATH"]) {
            let report = MCPHealthChecker.evaluate(
                server: ServerEntry(
                    name: "env-file-path-fixture",
                    transport: "stdio",
                    command: "/bin/echo",
                    args: [],
                    url: nil,
                    env: [:],
                    headers: [:],
                    bearerTokenEnvVar: nil,
                    envFile: "${env:PROJECTHUB_MISSING_ENV_FILE_PATH}",
                    isDisabled: false
                ),
                toolID: "vscode",
                configPath: "/tmp/project/.vscode/mcp.json"
            )

            XCTAssertEqual(report.status, .needsAuth)
            XCTAssertEqual(report.summary, "Missing env file path variable: PROJECTHUB_MISSING_ENV_FILE_PATH")
        }
    }

    func testEvaluateMissingCodexEnvVarsNeedsAuth() {
        let report = MCPHealthChecker.evaluate(
            server: ServerEntry(
                name: "env-vars-fixture",
                transport: "stdio",
                command: "/bin/echo",
                args: [],
                url: nil,
                env: [:],
                headers: [:],
                bearerTokenEnvVar: nil,
                envVars: ["PROJECTHUB_MISSING_CONTEXT7_TOKEN"],
                isDisabled: false
            ),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertTrue(report.summary.contains("PROJECTHUB_MISSING_CONTEXT7_TOKEN"))
    }

    func testEvaluateEmbeddedRemoteHeaderEnvTemplateNeedsAuth() {
        withEnvironmentVariablesUnset(["PROJECTHUB_MISSING_SUPABASE_ACCESS_TOKEN"]) {
            let report = MCPHealthChecker.evaluate(
                server: ServerEntry(
                    name: "supabase",
                    transport: "http",
                    command: nil,
                    args: [],
                    url: "https://mcp.supabase.com/mcp?project_ref=example",
                    env: [:],
                    headers: [
                        "Authorization": "Bearer ${PROJECTHUB_MISSING_SUPABASE_ACCESS_TOKEN}"
                    ],
                    bearerTokenEnvVar: nil,
                    isDisabled: false
                ),
                toolID: "codex"
            )

            XCTAssertEqual(report.status, .needsAuth)
            XCTAssertEqual(report.summary, "Missing remote auth value")
        }
    }

    func testVerifyRemoteHeadersHelperIsUnknownAndDoesNotExecuteHelper() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubHeadersHelper-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let marker = directory.appendingPathComponent("executed")
        let helper = directory.appendingPathComponent("helper.sh")
        try """
        #!/bin/sh
        touch "\(marker.path)"
        printf '{"Authorization":"Bearer should-not-run"}'
        """.write(to: helper, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        let report = await MCPHealthChecker.verify(
            server: ServerEntry(
                name: "internal-api",
                transport: "http",
                command: nil,
                args: [],
                url: "https://example.invalid/mcp",
                env: [:],
                headers: [:],
                headersHelper: helper.path,
                bearerTokenEnvVar: nil,
                isDisabled: false
            ),
            toolID: "claude-code"
        )

        XCTAssertEqual(report.status, .unknown)
        XCTAssertEqual(report.summary, "Auth managed by target tool via headersHelper")
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testVerifyRemoteOAuthConfigIsUnknownAndDoesNotProbe() async throws {
        let fixture = try LocalMCPHTTPFixture(mode: .unauthorized)
        let report = await MCPHealthChecker.verify(
            server: ServerEntry(
                name: "supabase",
                transport: "http",
                command: nil,
                args: [],
                url: fixture.url,
                env: [:],
                headers: [:],
                oauth: [
                    "callbackPort": "8080",
                    "clientId": "projecthub-client"
                ],
                bearerTokenEnvVar: nil,
                isDisabled: false
            ),
            toolID: "claude-code"
        )

        XCTAssertEqual(report.status, .unknown)
        XCTAssertEqual(report.summary, "Auth managed by target tool via OAuth")
        XCTAssertTrue(report.fixHint?.contains("clientId") == true)
        XCTAssertTrue(report.fixHint?.contains("callbackPort") == true)
    }

    func testEvaluateRemoteHeaderEnvTemplateFallbackDoesNotNeedAuth() {
        withEnvironmentVariablesUnset(["PROJECTHUB_OPTIONAL_SUPABASE_ACCESS_TOKEN"]) {
            let report = MCPHealthChecker.evaluate(
                server: ServerEntry(
                    name: "supabase",
                    transport: "http",
                    command: nil,
                    args: [],
                    url: "https://mcp.supabase.com/mcp?project_ref=example",
                    env: [:],
                    headers: [
                        "Authorization": "Bearer ${PROJECTHUB_OPTIONAL_SUPABASE_ACCESS_TOKEN:-anonymous}"
                    ],
                    bearerTokenEnvVar: nil,
                    isDisabled: false
                ),
                toolID: "codex"
            )

            XCTAssertEqual(report.status, .working)
        }
    }

    func testEvaluateRemoteURLEnvTemplateNeedsAuthBeforeURLParsing() {
        withEnvironmentVariablesUnset(["PROJECTHUB_MISSING_MCP_BASE_URL"]) {
            let report = MCPHealthChecker.evaluate(
                server: remoteServer(url: "${PROJECTHUB_MISSING_MCP_BASE_URL}/mcp"),
                toolID: "codex"
            )

            XCTAssertEqual(report.status, .needsAuth)
            XCTAssertEqual(report.summary, "Missing remote URL env var: PROJECTHUB_MISSING_MCP_BASE_URL")
        }
    }

    func testEvaluateRemoteURLEnvTemplateFallbackDoesNotNeedAuth() {
        withEnvironmentVariablesUnset(["PROJECTHUB_OPTIONAL_MCP_BASE_URL"]) {
            let report = MCPHealthChecker.evaluate(
                server: remoteServer(url: "${PROJECTHUB_OPTIONAL_MCP_BASE_URL:-https://mcp.example.com}/mcp"),
                toolID: "codex"
            )

            XCTAssertEqual(report.status, .working)
        }
    }

    func testEvaluateUsesTargetRuntimeLaunchForRestartState() throws {
        let config = try makeTempConfig()
        let modifiedAt = Date()
        try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: config.path)

        let staleRuntime = MCPVerificationContext.loadedAt(modifiedAt.addingTimeInterval(-30), ownerName: "Claude Desktop")
        let staleReport = MCPHealthChecker.evaluate(
            server: server(command: "/bin/echo"),
            toolID: "claude-desktop",
            configPath: config.path,
            context: staleRuntime
        )

        XCTAssertEqual(staleReport.status, .needsRestart)
        XCTAssertEqual(staleReport.summary, "Changed since Claude Desktop loaded config")

        let freshRuntime = MCPVerificationContext.loadedAt(modifiedAt.addingTimeInterval(30), ownerName: "Claude Desktop")
        let freshReport = MCPHealthChecker.evaluate(
            server: server(command: "/bin/echo"),
            toolID: "claude-desktop",
            configPath: config.path,
            context: freshRuntime
        )

        XCTAssertEqual(freshReport.status, .working)
        XCTAssertEqual(freshReport.summary, "Config looks runnable")
    }

    func testEvaluateHandlesUnknownAndNotRunningRuntimeEvidence() throws {
        let config = try makeTempConfig()
        let unknownReport = MCPHealthChecker.evaluate(
            server: server(command: "/bin/echo"),
            toolID: "claude-desktop",
            configPath: config.path,
            context: .unknown(ownerName: "Claude Desktop")
        )

        XCTAssertEqual(unknownReport.status, .needsRestart)
        XCTAssertEqual(unknownReport.summary, "Claude Desktop reload state unknown")

        let notRunningReport = MCPHealthChecker.evaluate(
            server: server(command: "/bin/echo"),
            toolID: "claude-desktop",
            configPath: config.path,
            context: .notRunning(ownerName: "Claude Desktop")
        )

        XCTAssertEqual(notRunningReport.status, .working)
        XCTAssertEqual(notRunningReport.summary, "Config looks runnable; Claude Desktop will load it on next launch")
    }

    func testVerifyDoesNotStayNeedsRestartWhenRuntimeLoadedAfterConfigChange() async throws {
        let script = try makeExecutableScript("""
        #!/bin/sh
        while IFS= read -r line; do
          case "$line" in
            *'"id":1'*)
              printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{},"serverInfo":{"name":"fixture","version":"1.0.0"}}}'
              ;;
            *'"id":2'*)
              printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"tools":[]}}'
              exit 0
              ;;
          esac
        done
        """)
        let config = try makeTempConfig()
        let modifiedAt = Date()
        try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: config.path)

        let report = await MCPHealthChecker.verify(
            server: server(command: script.path),
            toolID: "claude-desktop",
            configPath: config.path,
            context: .loadedAt(modifiedAt.addingTimeInterval(30), ownerName: "Claude Desktop")
        )

        XCTAssertEqual(report.status, .working)
        XCTAssertTrue(report.summary.contains("tools/list verified"))
    }

    func testVerifyStillRunsHandshakeWhenRuntimeReloadStateIsUnknown() async throws {
        let script = try makeExecutableScript("""
        #!/bin/sh
        while IFS= read -r line; do
          case "$line" in
            *'"id":1'*)
              printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{},"serverInfo":{"name":"fixture","version":"1.0.0"}}}'
              ;;
            *'"id":2'*)
              printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"echo","inputSchema":{"type":"object"}}]}}'
              exit 0
              ;;
          esac
        done
        """)

        let report = await MCPHealthChecker.verify(
            server: server(command: script.path),
            toolID: "claude-desktop",
            configPath: try makeTempConfig().path,
            context: .unknown(ownerName: "Claude Desktop")
        )

        XCTAssertEqual(report.status, .needsRestart)
        XCTAssertEqual(report.summary, "Verified, but target app needs restart")
    }

    func testEvaluateRemoteMissingCodexEnvVarsNeedsAuth() {
        let report = MCPHealthChecker.evaluate(
            server: ServerEntry(
                name: "remote-env-vars-fixture",
                transport: "http",
                command: nil,
                args: [],
                url: "https://example.invalid/mcp",
                env: [:],
                headers: [:],
                bearerTokenEnvVar: nil,
                envVars: ["PROJECTHUB_MISSING_REMOTE_MCP_TOKEN"],
                isDisabled: false
            ),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertTrue(report.summary.contains("PROJECTHUB_MISSING_REMOTE_MCP_TOKEN"))
    }

    func testEvaluateMissingCommandIsBroken() {
        let report = MCPHealthChecker.evaluate(
            server: server(command: "/no/such/projecthub-mcp-fixture"),
            toolID: "claude-desktop"
        )

        XCTAssertEqual(report.status, .broken)
        XCTAssertTrue(report.summary.contains("Command not found"))
    }

    func testVerifyRemoteHTTPServerCompletesHandshake() async throws {
        let fixture = try LocalMCPHTTPFixture(mode: .working)
        addTeardownBlock { fixture.stop() }

        let report = await MCPHealthChecker.verify(
            server: remoteServer(url: fixture.url),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .working, report.summary)
        XCTAssertTrue(report.summary.contains("Remote"), report.summary)
        XCTAssertTrue(report.summary.contains("verified"), report.summary)
    }

    func testVerifyRemoteHTTPUnauthorizedNeedsAuth() async throws {
        let fixture = try LocalMCPHTTPFixture(mode: .unauthorized)
        addTeardownBlock { fixture.stop() }

        let report = await MCPHealthChecker.verify(
            server: remoteServer(url: fixture.url),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertEqual(report.summary, "Remote endpoint requires authentication")
    }

    func testVerifyRemoteHTTPWWWAuthenticateOAuthChallengeNeedsAuth() async throws {
        let fixture = try LocalMCPHTTPFixture(mode: .oauthChallenge)
        addTeardownBlock { fixture.stop() }

        let report = await MCPHealthChecker.verify(
            server: remoteServer(url: fixture.url),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertEqual(report.summary, "Remote endpoint requires OAuth login")
        XCTAssertTrue(report.fixHint?.contains("https://mcp.supabase.com/.well-known/oauth-protected-resource/mcp") == true)
    }

    func testVerifyRemoteStreamableHTTPSSECompletesHandshake() async throws {
        let fixture = try LocalMCPHTTPFixture(mode: .streamableSSEWorking)
        addTeardownBlock { fixture.stop() }

        let report = await MCPHealthChecker.verify(
            server: remoteServer(url: fixture.url),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .working, report.summary)
        XCTAssertTrue(report.summary.contains("2 tools"), report.summary)
    }

    func testVerifyRemoteStreamableHTTPSSEAuthErrorNeedsAuthAndRedactsSecret() async throws {
        let fixture = try LocalMCPHTTPFixture(mode: .streamableSSEInitializeAuthError)
        addTeardownBlock { fixture.stop() }

        let report = await MCPHealthChecker.verify(
            server: remoteServer(url: fixture.url),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertTrue(report.summary.contains("requires authentication"))
        XCTAssertTrue(report.summary.contains("token=[redacted]"))
        XCTAssertFalse(report.summary.contains("secret123"))
    }

    func testVerifyRemoteStreamableHTTPSSEExpiredAuthIsAuthExpired() async throws {
        let fixture = try LocalMCPHTTPFixture(mode: .streamableSSEInitializeExpiredAuthError)
        addTeardownBlock { fixture.stop() }

        let report = await MCPHealthChecker.verify(
            server: remoteServer(url: fixture.url),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .authExpired)
        XCTAssertTrue(report.summary.contains("auth expired"))
    }

    func testVerifyRemoteToolsListHTTPErrorBodyCanNeedAuth() async throws {
        let fixture = try LocalMCPHTTPFixture(mode: .toolsListInvalidToken)
        addTeardownBlock { fixture.stop() }

        let report = await MCPHealthChecker.verify(
            server: remoteServer(url: fixture.url),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertTrue(report.summary.contains("requires authentication"))
    }

    func testVerifyRemoteMalformedToolsListIsUnknown() async throws {
        let fixture = try LocalMCPHTTPFixture(mode: .toolsListMalformed)
        addTeardownBlock { fixture.stop() }

        let report = await MCPHealthChecker.verify(
            server: remoteServer(url: fixture.url),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .unknown)
        XCTAssertEqual(report.summary, "Remote tools/list response was not recognized")
    }

    func testVerifyLegacySSELoginPageIsNeedsAuth() async throws {
        let fixture = try LocalMCPHTTPFixture(mode: .sseLoginPage)
        addTeardownBlock { fixture.stop() }

        let report = await MCPHealthChecker.verify(
            server: ServerEntry(
                name: "legacy-sse-fixture",
                transport: "sse",
                command: nil,
                args: [],
                url: fixture.url,
                env: [:],
                headers: [:],
                bearerTokenEnvVar: nil,
                isDisabled: false
            ),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertTrue(report.summary.contains("requires authentication"))
    }

    func testEvaluateKnownHostedOAuthProvidersNeedLogin() {
        let cases: [(url: String, provider: String)] = [
            ("https://api.githubcopilot.com/mcp/", "GitHub"),
            ("https://mcp.notion.com/mcp", "Notion"),
            ("https://mcp.atlassian.com/v1/mcp/authv2", "Atlassian")
        ]

        for testCase in cases {
            let report = MCPHealthChecker.evaluate(
                server: remoteServer(url: testCase.url),
                toolID: "codex"
            )

            XCTAssertEqual(report.status, .needsAuth, testCase.url)
            XCTAssertEqual(report.summary, "\(testCase.provider) OAuth login required")
        }
    }

    func testEvaluateRemotePlaceholderOAuthMetadataDoesNotSuppressHostedOAuth() {
        let report = MCPHealthChecker.evaluate(
            server: ServerEntry(
                name: "github",
                transport: "http",
                command: nil,
                args: [],
                url: "https://api.githubcopilot.com/mcp/",
                env: [:],
                headers: [:],
                oauth: ["clientId": "your-client-id"],
                bearerTokenEnvVar: nil,
                isDisabled: false
            ),
            toolID: "codex"
        )

        XCTAssertEqual(report.status, .needsAuth)
        XCTAssertEqual(report.summary, "GitHub OAuth login required")
    }

    private func server(command: String, args: [String] = [], cwd: String? = nil, envFile: String? = nil, startupTimeoutSeconds: TimeInterval? = nil) -> ServerEntry {
        ServerEntry(
            name: "fixture",
            transport: "stdio",
            command: command,
            args: args,
            cwd: cwd,
            url: nil,
            env: [:],
            headers: [:],
            bearerTokenEnvVar: nil,
            envFile: envFile,
            startupTimeoutSeconds: startupTimeoutSeconds,
            isDisabled: false
        )
    }

    private func remoteServer(url: String, transport: String = "http") -> ServerEntry {
        ServerEntry(
            name: "remote-fixture",
            transport: transport,
            command: nil,
            args: [],
            url: url,
            env: [:],
            headers: [:],
            bearerTokenEnvVar: nil,
            isDisabled: false
        )
    }

    private func makeExecutableScript(_ content: String) throws -> URL {
        try makeExecutableScript(named: "fixture-mcp.sh", content: content)
    }

    private func makeExecutableScript(named name: String, content: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubMCPHealthCheckerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        let script = directory.appendingPathComponent(name)
        try content.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        return script
    }

    private func makeTempConfig() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubMCPHealthCheckerConfigTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        let config = directory.appendingPathComponent("mcp.json")
        try "{}\n".write(to: config, atomically: true, encoding: .utf8)
        return config
    }

    private func withEnvironmentVariablesUnset(_ keys: [String], run: () -> Void) {
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
        run()
    }

    private func withEnvironmentVariable<T>(
        _ key: String,
        value: String,
        run: () async throws -> T
    ) async rethrows -> T {
        let previous = getenv(key).map { String(cString: $0) }
        setenv(key, value, 1)
        defer {
            if let previous {
                setenv(key, previous, 1)
            } else {
                unsetenv(key)
            }
        }
        return try await run()
    }
}

private final class LocalMCPHTTPFixture: @unchecked Sendable {
    enum Mode {
        case working
        case unauthorized
        case oauthChallenge
        case streamableSSEWorking
        case streamableSSEInitializeAuthError
        case streamableSSEInitializeExpiredAuthError
        case toolsListInvalidToken
        case toolsListMalformed
        case sseLoginPage
    }

    private(set) var url = ""
    private let listener: NWListener
    private let queue = DispatchQueue(label: "ProjectHubTests.LocalMCPHTTPFixture")
    private let mode: Mode

    init(mode: Mode) throws {
        self.mode = mode
        listener = try NWListener(using: .tcp, on: .any)
        let ready = DispatchSemaphore(value: 0)
        var startupError: Error?

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                ready.signal()
            case .failed(let error):
                startupError = error
                ready.signal()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: queue)

        guard ready.wait(timeout: .now() + 2) == .success else {
            listener.cancel()
            throw FixtureError.startupTimeout
        }
        if let startupError {
            listener.cancel()
            throw startupError
        }
        guard let port = listener.port else {
            listener.cancel()
            throw FixtureError.missingPort
        }
        url = "http://127.0.0.1:\(port.rawValue)/mcp"
    }

    func stop() {
        listener.cancel()
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        var buffer = Data()

        func receiveMore() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, isComplete, _ in
                guard let self else {
                    connection.cancel()
                    return
                }
                if let data {
                    buffer.append(data)
                }
                guard self.httpRequestIsComplete(buffer) || isComplete else {
                    receiveMore()
                    return
                }
                let request = String(data: buffer, encoding: .utf8) ?? ""
                let response = self.response(for: request)
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }

        receiveMore()
    }

    private func httpRequestIsComplete(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8),
              let headerRange = text.range(of: "\r\n\r\n") else {
            return false
        }
        let headers = String(text[..<headerRange.lowerBound])
        let bodyStart = text.distance(from: text.startIndex, to: headerRange.upperBound)
        let contentLength = headers.components(separatedBy: "\r\n")
            .compactMap { line -> Int? in
                let parts = line.split(separator: ":", maxSplits: 1).map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                guard parts.count == 2,
                      parts[0].lowercased() == "content-length" else { return nil }
                return Int(parts[1])
            }
            .first ?? 0
        return data.count >= bodyStart + contentLength
    }

    private func response(for request: String) -> Data {
        if mode == .unauthorized {
            return http(status: 401, body: #"{"error":"unauthorized"}"#)
        }
        if mode == .oauthChallenge {
            return http(
                status: 401,
                body: #"{"error":"unauthorized"}"#,
                headers: [
                    "WWW-Authenticate": #"Bearer error="invalid_request", error_description="No access token was provided in this request", resource_metadata="https://mcp.supabase.com/.well-known/oauth-protected-resource/mcp""#
                ]
            )
        }
        if mode == .sseLoginPage {
            return http(
                status: 200,
                body: "<html><body>sign in required token=secret123</body></html>",
                contentType: "text/html"
            )
        }

        if request.contains(#""id":1"#) {
            if mode == .streamableSSEInitializeAuthError {
                return http(
                    status: 200,
                    body: sseJSON(#"{"jsonrpc":"2.0","id":1,"error":{"code":-32001,"message":"Unauthorized token=secret123"}}"#),
                    contentType: "text/event-stream"
                )
            }
            if mode == .streamableSSEInitializeExpiredAuthError {
                return http(
                    status: 200,
                    body: sseJSON(#"{"jsonrpc":"2.0","id":1,"error":{"code":-32001,"message":"Token has expired token=secret123"}}"#),
                    contentType: "text/event-stream"
                )
            }
            if mode == .streamableSSEWorking {
                return http(
                    status: 200,
                    body: sseJSON(#"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{},"serverInfo":{"name":"fixture","version":"1.0.0"}}}"#),
                    headers: ["Mcp-Session-Id": "fixture-session"],
                    contentType: "text/event-stream"
                )
            }
            return http(
                status: 200,
                body: #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{},"serverInfo":{"name":"fixture","version":"1.0.0"}}}"#,
                headers: ["Mcp-Session-Id": "fixture-session"]
            )
        }
        if request.contains(#""id":2"#) {
            if mode == .streamableSSEWorking {
                return http(
                    status: 200,
                    body: sseJSON(#"{"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"echo"},{"name":"search"}]}}"#),
                    contentType: "text/event-stream"
                )
            }
            if mode == .toolsListInvalidToken {
                return http(
                    status: 400,
                    body: #"{"error":{"message":"invalid token"}}"#
                )
            }
            if mode == .toolsListMalformed {
                return http(status: 200, body: #"{"ok":true}"#)
            }
            return http(
                status: 200,
                body: #"{"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"echo","description":"Echo","inputSchema":{"type":"object"}}]}}"#
            )
        }
        return http(status: 202, body: #"{}"#)
    }

    private func sseJSON(_ json: String) -> String {
        "event: message\ndata: \(json)\n\n"
    }

    private func http(
        status: Int,
        body: String,
        headers: [String: String] = [:],
        contentType: String = "application/json"
    ) -> Data {
        let statusText = status == 200 ? "OK" : (status == 202 ? "Accepted" : "Unauthorized")
        let bodyData = Data(body.utf8)
        var lines = [
            "HTTP/1.1 \(status) \(statusText)",
            "Content-Type: \(contentType)",
            "Content-Length: \(bodyData.count)",
            "Connection: close"
        ]
        for (key, value) in headers {
            lines.append("\(key): \(value)")
        }
        lines.append("")
        lines.append("")

        var data = Data(lines.joined(separator: "\r\n").utf8)
        data.append(bodyData)
        return data
    }

    enum FixtureError: Error {
        case startupTimeout
        case missingPort
    }
}
