import Foundation

struct MCPVerificationContext {
    enum RuntimeState {
        case unknown
        case notRunning
        case loadedAt(Date)
    }

    let ownerName: String
    let runtimeState: RuntimeState

    static func unknown(ownerName: String) -> MCPVerificationContext {
        MCPVerificationContext(ownerName: ownerName, runtimeState: .unknown)
    }

    static func notRunning(ownerName: String) -> MCPVerificationContext {
        MCPVerificationContext(ownerName: ownerName, runtimeState: .notRunning)
    }

    static func loadedAt(_ date: Date, ownerName: String) -> MCPVerificationContext {
        MCPVerificationContext(ownerName: ownerName, runtimeState: .loadedAt(date))
    }
}

enum MCPHealthChecker {
    private static let appStartedAt = Date()
    private static let defaultProbeTimeout: TimeInterval = 4
    private static let minProbeTimeout: TimeInterval = 0.25
    private static let maxProbeTimeout: TimeInterval = 15

    static func evaluate(
        server: ServerEntry,
        toolID: String,
        configPath: String? = nil,
        context: MCPVerificationContext? = nil
    ) -> MCPHealthReport {
        let server = normalizedLaunch(server)
        if server.isDisabled {
            return report(.disabled, server, toolID, "Disabled in config", "Enable it or leave it disabled intentionally.")
        }

        let inputVariables = inputVariableReferences(in: server)
        if !inputVariables.isEmpty {
            return report(.needsAuth, server, toolID, "Input variable prompt required: \(inputVariables.joined(separator: ", "))", "Open the owning app so it can prompt for these inputs, or replace them with environment-backed values supported by the target tool.")
        }

        if let envFile = normalizedEnvFile(server.envFile) {
            let missingEnvFileVars = missingRequiredEnvExpansionNames(in: envFile)
            if !missingEnvFileVars.isEmpty {
                return report(.needsAuth, server, toolID, "Missing env file path variable: \(missingEnvFileVars.joined(separator: ", "))", "Set the environment variable used by envFile before starting the target app, or replace the envFile path with an explicit path.")
            }
            if let configPath, envFileNeedsMissingFileWarning(envFile, configPath: configPath) {
                return report(.needsAuth, server, toolID, "Missing env file: \(envFile)", "Create the env file, open the owning app so it can load the file, or convert required values to environment-backed config supported by the target tool.")
            }
            return report(.needsAuth, server, toolID, "Env file requires app-specific loading: \(envFile)", "Verify the owning app loads this env file, or convert required values to explicit environment-backed config before copying to Claude/Codex.")
        }

        let missingEnvVars = missingEnvVars(server.envVars)
        if !missingEnvVars.isEmpty {
            return report(.needsAuth, server, toolID, "Missing whitelisted env var: \(missingEnvVars.joined(separator: ", "))", "Set the required local env var before starting the target app or remove it from env_vars if it is not required.")
        }

        if !isSupportedMCPTransport(server.transport, toolID: toolID) {
            return report(.broken, server, toolID, "Unsupported transport: \(server.transport)", "Use stdio, http, streamable-http, or sse where the target tool supports it.")
        }

        if server.transport == "stdio" {
            guard let command = server.command, !command.trimmingCharacters(in: .whitespaces).isEmpty else {
                return report(.broken, server, toolID, "Missing command", "Add a command or replace this with a remote URL config.")
            }
            let resolvedCwd = resolvedCWD(server.cwd, configPath: configPath)
            if let cwd = resolvedCwd, !cwd.contains("${"), missingDirectory(cwd) {
                return report(.broken, server, toolID, "Working directory not found: \(cwd)", "Create the directory or update the MCP cwd/working directory setting.")
            }
            let missingCommandVars = missingRequiredEnvExpansionNames(in: command)
            if !missingCommandVars.isEmpty {
                return report(.needsAuth, server, toolID, "Missing command environment variable: \(missingCommandVars.joined(separator: ", "))", "Set the required command environment variable before starting the target app or replace the command with a default such as ${VAR:-/path/to/server}.")
            }
            let expandedCommand = expandEnvRefs(command)
            if !commandExists(expandedCommand, cwd: resolvedCwd) {
                return report(.broken, server, toolID, "Command not found: \(expandedCommand)", "Install the command or update the config path.")
            }
            if hasMissingEnv(server.env) {
                return report(.needsAuth, server, toolID, "Missing environment value", "Fill required env values in the config or login flow.")
            }
            let missingDockerVars = missingDockerEnvFlagVars(command: expandedCommand, args: server.args)
            if !missingDockerVars.isEmpty {
                return report(.needsAuth, server, toolID, "Missing Docker env var: \(missingDockerVars.joined(separator: ", "))", "Set the required host environment variable before launching the Docker MCP server, or provide it through the target tool's env map.")
            }
            let missingDockerPathVars = missingDockerPathEnvVars(command: expandedCommand, args: server.args)
            if !missingDockerPathVars.isEmpty {
                return report(.needsAuth, server, toolID, "Missing Docker path variable: \(missingDockerPathVars.joined(separator: ", "))", "Set the environment variable used by Docker --env-file or mount paths before launching this MCP server.")
            }
            let missingArgVars = missingRequiredEnvExpansionNames(in: server.args)
            if !missingArgVars.isEmpty {
                return report(.needsAuth, server, toolID, "Missing launch environment variable: \(missingArgVars.joined(separator: ", "))", "Set the required environment variable before starting the target app or replace the launch argument with a secure configured value.")
            }
            let missingDockerEnvFiles = missingDockerEnvFilePaths(command: expandedCommand, args: server.args, cwd: resolvedCwd, configPath: configPath)
            if !missingDockerEnvFiles.isEmpty {
                return report(.needsAuth, server, toolID, "Missing Docker env file: \(missingDockerEnvFiles.joined(separator: ", "))", "Create the env file or update the Docker --env-file path before launching this MCP server.")
            }
            let missingDockerMounts = missingDockerMountPaths(command: expandedCommand, args: server.args, cwd: resolvedCwd, configPath: configPath)
            if !missingDockerMounts.isEmpty {
                return report(.broken, server, toolID, "Missing Docker mount path: \(missingDockerMounts.joined(separator: ", "))", "Create the host path or update the Docker volume/bind mount before launching this MCP server.")
            }
            if hasMissingLaunchCredential(server.args) {
                return report(.needsAuth, server, toolID, "Missing launch credential", "Replace placeholder token/API-key arguments with an environment-backed credential or login flow.")
            }
            return restartAwareReport(server: server, toolID: toolID, configPath: configPath, context: context, summary: "Config looks runnable")
        }

        guard let rawURL = server.url, !rawURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return report(.broken, server, toolID, "Invalid remote URL", "Use an http(s), SSE, or streamable HTTP endpoint.")
        }
        let missingURLVars = missingRequiredEnvExpansionNames(in: rawURL)
        if !missingURLVars.isEmpty {
            return report(.needsAuth, server, toolID, "Missing remote URL env var: \(missingURLVars.joined(separator: ", "))", "Set the required URL environment variable before starting the target app or replace it with a default such as ${VAR:-https://example.com}.")
        }
        let isClaudeCodeWebSocket = isClaudeCodeWebSocketTransport(server.transport, toolID: toolID)
        if isClaudeCodeWebSocket {
            guard let parsed = URL(string: expandEnvRefs(rawURL)),
                  ["ws", "wss"].contains(parsed.scheme?.lowercased() ?? ""),
                  parsed.host != nil else {
                return report(.broken, server, toolID, "Invalid WebSocket URL", "Use a ws:// or wss:// URL for Claude Code WebSocket MCP.")
            }
        } else if let parsed = URL(string: expandEnvRefs(rawURL)), parsed.scheme?.hasPrefix("http") == true {
            // Valid HTTP-family remote URL; auth and hosted-provider checks continue below.
        } else {
            return report(.broken, server, toolID, "Invalid remote URL", "Use an http(s), SSE, or streamable HTTP endpoint.")
        }

        if let helper = normalizedHeadersHelper(server.headersHelper) {
            return report(.unknown, server, toolID, "Auth managed by target tool via headersHelper", "Claude Code will run headersHelper at connection time. Project Hub does not execute arbitrary helper commands; verify this server in Claude Code /mcp. Helper: \(helper)")
        }

        let oauth = meaningfulOAuthMetadata(server.oauth)
        if !oauth.isEmpty {
            let keys = oauth.keys.sorted().joined(separator: ", ")
            return report(.unknown, server, toolID, "Auth managed by target tool via OAuth", "Project Hub preserves OAuth metadata\(keys.isEmpty ? "" : " (\(keys))") but does not complete browser login. Verify this server in the target tool's MCP panel.")
        }

        if let bearer = server.bearerTokenEnvVar,
           ProcessInfo.processInfo.environment[bearer]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            return report(.needsAuth, server, toolID, "Missing bearer token env var", "Set \(bearer) before starting the app.")
        }

        if hasMissingEnv(server.env) || hasMissingEnv(server.headers) || server.headers.values.contains(where: looksLikePlaceholder) {
            return report(.needsAuth, server, toolID, "Missing remote auth value", "Set the bearer token/header env var or complete the app's OAuth flow.")
        }

        if isClaudeCodeWebSocket {
            return report(.unknown, server, toolID, "WebSocket MCP configured", "Claude Code owns WebSocket MCP connection handling. Verify this server in Claude Code /mcp; Project Hub does not open WebSocket MCP sessions yet.")
        }

        if let oauthProvider = hostedOAuthMCPProvider(for: rawURL),
           server.headers.isEmpty,
           server.bearerTokenEnvVar?.isEmpty ?? true {
            return report(.needsAuth, server, toolID, "\(oauthProvider) OAuth login required", "Complete the target tool's MCP OAuth login flow, or configure an environment-backed Authorization header where the tool supports it.")
        }

        if toolID == "claude-desktop", server.transport != "stdio" {
            return report(.unknown, server, toolID, "Runtime managed by Claude Desktop connector UI", "Claude Desktop remote connectors should be configured in Settings > Connectors.")
        }

        return restartAwareReport(server: server, toolID: toolID, configPath: configPath, context: context, summary: "Remote endpoint configured")
    }

    static func verify(
        server: ServerEntry,
        toolID: String,
        configPath: String? = nil,
        context: MCPVerificationContext? = nil
    ) async -> MCPHealthReport {
        let server = normalizedLaunch(server)
        let preflight = evaluate(server: server, toolID: toolID, configPath: configPath, context: context)
        switch preflight.status {
        case .broken, .needsAuth, .authExpired, .disabled, .unknown:
            return preflight
        case .working, .needsRestart:
            break
        }

        if server.transport == "stdio" {
            let live = await Task.detached(priority: .utility) {
                verifyStdio(server: server, toolID: toolID, configPath: configPath)
            }.value
            if preflight.status == .needsRestart, live.status == .working {
                return report(.needsRestart, server, toolID, "Verified, but target app needs restart", restartHint(for: toolID))
            }
            return live
        }

        let live = await verifyRemote(server: server, toolID: toolID)
        if preflight.status == .needsRestart, live.status == .working {
            return report(.needsRestart, server, toolID, "Verified, but target app needs restart", restartHint(for: toolID))
        }
        return live
    }

    static func summarize(_ reports: [MCPHealthReport]) -> [MCPHealthStatus: Int] {
        Dictionary(grouping: reports, by: \.status).mapValues(\.count)
    }

    private static func report(
        _ status: MCPHealthStatus,
        _ server: ServerEntry,
        _ toolID: String,
        _ summary: String,
        _ fixHint: String?
    ) -> MCPHealthReport {
        MCPHealthReport(toolID: toolID, serverName: server.name, status: status, summary: summary, fixHint: fixHint)
    }

    private static func isSupportedMCPTransport(_ transport: String, toolID: String) -> Bool {
        switch transport.lowercased() {
        case "stdio", "http", "https", "remote", "streamable_http", "streamable-http", "streamablehttp", "sse":
            return true
        case "ws":
            return toolID == "claude-code"
        default:
            return false
        }
    }

    private static func isClaudeCodeWebSocketTransport(_ transport: String, toolID: String) -> Bool {
        toolID == "claude-code" && transport.lowercased() == "ws"
    }

    private static func restartAwareReport(
        server: ServerEntry,
        toolID: String,
        configPath: String?,
        context: MCPVerificationContext?,
        summary: String
    ) -> MCPHealthReport {
        if let configPath,
           let modified = try? FileManager.default.attributesOfItem(atPath: configPath)[.modificationDate] as? Date {
            if let context {
                switch context.runtimeState {
                case .loadedAt(let loadedAt):
                    if modified > loadedAt {
                        return report(.needsRestart, server, toolID, "Changed since \(context.ownerName) loaded config", restartHint(for: toolID))
                    }
                    return report(.working, server, toolID, summary, nil)
                case .notRunning:
                    return report(.working, server, toolID, "\(summary); \(context.ownerName) will load it on next launch", nil)
                case .unknown:
                    return report(.needsRestart, server, toolID, "\(context.ownerName) reload state unknown", restartHint(for: toolID))
                }
            }
            if modified > appStartedAt {
                return report(.needsRestart, server, toolID, "Changed since Project Hub opened", restartHint(for: toolID))
            }
        }
        return report(.working, server, toolID, summary, nil)
    }

    private static func restartAwareReport(
        server: ServerEntry,
        toolID: String,
        configPath: String?,
        summary: String
    ) -> MCPHealthReport {
        restartAwareReport(server: server, toolID: toolID, configPath: configPath, context: nil, summary: summary)
    }

    private static func verifyStdio(server: ServerEntry, toolID: String, configPath: String?) -> MCPHealthReport {
        let startupTimeout = probeTimeout(for: server, toolID: toolID)
        let startedAt = Date()
        guard let command = server.command, !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return report(.broken, server, toolID, "Missing command", "Add a command or replace this with a remote URL config.")
        }
        let expandedCommand = expandEnvRefs(command)
        let resolvedCwd = resolvedCWD(server.cwd, configPath: configPath)

        let process = Process()
        if expandedCommand.contains("/") {
            let expandedPath = (expandedCommand as NSString).expandingTildeInPath
            let executablePath: String
            if expandedPath.hasPrefix("/") {
                executablePath = expandedPath
            } else if let resolvedCwd {
                executablePath = URL(fileURLWithPath: expandedPath, relativeTo: URL(fileURLWithPath: resolvedCwd))
                    .standardizedFileURL
                    .path
            } else {
                executablePath = expandedPath
            }
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = server.args.map(expandEnvRefs)
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [expandedCommand] + server.args.map(expandEnvRefs)
        }
        if let resolvedCwd {
            process.currentDirectoryURL = URL(fileURLWithPath: resolvedCwd)
        }

        var environment = ProcessInfo.processInfo.environment
        for (key, value) in server.env {
            environment[key] = expandEnvRefs(value)
        }
        process.environment = environment

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        let response = LockedProbeBuffer()
        let finished = DispatchSemaphore(value: 0)
        let toolsListed = DispatchSemaphore(value: 0)

        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let completed = response.appendStdout(data)
            if completed.contains(1) {
                finished.signal()
            }
            if completed.contains(2) {
                toolsListed.signal()
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            response.appendStderr(data)
        }

        do {
            try process.run()
            let payload = initializePayload()
            stdin.fileHandleForWriting.write(payload)
        } catch {
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            return report(.broken, server, toolID, "Launch failed: \(error.localizedDescription)", "Check command path, permissions, and runtime installation.")
        }

        let wait = finished.wait(timeout: .now() + remainingTimeout(startedAt: startedAt, budget: startupTimeout))
        if wait == .success, let initializeLine = response.responseLine(id: 1) {
            if let error = jsonRPCErrorMessage(initializeLine) {
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                try? stdin.fileHandleForWriting.close()
                if process.isRunning {
                    process.terminate()
                    process.waitUntilExit()
                }
                if let authReport = authSignalReport(error, server: server, toolID: toolID, phase: "MCP initialize") {
                    return authReport
                }
                return report(.broken, server, toolID, "MCP initialize error: \(error)", "Open the server logs or run the command manually.")
            }

            stdin.fileHandleForWriting.write(initializedPayload())
            stdin.fileHandleForWriting.write(toolsListPayload())
        }

        let toolsWait = wait == .success ? toolsListed.wait(timeout: .now() + remainingTimeout(startedAt: startedAt, budget: startupTimeout)) : .timedOut
        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil
        try? stdin.fileHandleForWriting.close()
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }

        if wait == .success, toolsWait == .success, let line = response.responseLine(id: 2) {
            if let error = jsonRPCErrorMessage(line) {
                if let authReport = authSignalReport(error, server: server, toolID: toolID, phase: "MCP tools/list") {
                    return authReport
                }
                return report(.broken, server, toolID, "MCP tools/list error: \(error)", "Open the server logs or run the command manually.")
            }
            if let toolCount = toolsCount(in: line) {
                return report(.working, server, toolID, "MCP initialize and tools/list verified (\(toolCount) tool\(toolCount == 1 ? "" : "s"))", nil)
            }
            return report(.unknown, server, toolID, "MCP initialized, but tools/list response was not recognized", "Inspect server output and protocol compatibility.")
        }

        if wait == .success {
            return report(.unknown, server, toolID, "MCP initialized, but tools/list did not respond", "The server launched and initialized, but Project Hub could not verify its tool list.")
        }

        let err = response.stderrText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !err.isEmpty {
            if let authReport = authSignalReport(err, server: server, toolID: toolID, phase: "MCP startup") {
                return authReport
            }
            return report(.unknown, server, toolID, "No MCP response; stderr: \(redactedDiagnostic(err))", "Run the command manually to inspect startup output.")
        }
        return report(.unknown, server, toolID, "No MCP initialize response", "The process launched but did not answer within \(formatSeconds(startupTimeout)) seconds.")
    }

    private static func verifyRemote(server: ServerEntry, toolID: String) async -> MCPHealthReport {
        let startupTimeout = probeTimeout(for: server, toolID: toolID)
        let startedAt = Date()
        guard let urlString = server.url else {
            return report(.broken, server, toolID, "Invalid remote URL", "Use an http(s), SSE, or streamable HTTP endpoint.")
        }
        let missingURLVars = missingRequiredEnvExpansionNames(in: urlString)
        if !missingURLVars.isEmpty {
            return report(.needsAuth, server, toolID, "Missing remote URL env var: \(missingURLVars.joined(separator: ", "))", "Set the required URL environment variable before starting the target app or replace it with a default such as ${VAR:-https://example.com}.")
        }
        guard let url = URL(string: expandEnvRefs(urlString)) else {
            return report(.broken, server, toolID, "Invalid remote URL", "Use an http(s), SSE, or streamable HTTP endpoint.")
        }

        let transport = server.transport.lowercased()
        let sessionHeaderName = "Mcp-Session-Id"

        func request(method: String, body: Data?, sessionID: String? = nil, timeout: TimeInterval? = nil) -> URLRequest {
            var req = URLRequest(url: url, timeoutInterval: timeout ?? startupTimeout)
            req.httpMethod = method
            req.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
            req.setValue("2025-06-18", forHTTPHeaderField: "MCP-Protocol-Version")
            if let body {
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = body
            }
            if let sessionID, !sessionID.isEmpty {
                req.setValue(sessionID, forHTTPHeaderField: sessionHeaderName)
            }
            for (key, value) in server.headers {
                req.setValue(expandEnvRefs(value), forHTTPHeaderField: key)
            }
            if let bearer = server.bearerTokenEnvVar,
               let token = ProcessInfo.processInfo.environment[bearer],
               !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               req.value(forHTTPHeaderField: "Authorization") == nil {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            return req
        }

        do {
            if transport == "sse" {
                let (data, response) = try await URLSession.shared.data(
                    for: request(method: "GET", body: nil, timeout: remoteRequestTimeout(startedAt: startedAt, budget: startupTimeout))
                )
                guard let http = response as? HTTPURLResponse else {
                    return report(.unknown, server, toolID, "SSE probe returned a non-HTTP response", nil)
                }
                switch http.statusCode {
                case 200...299:
                    let contentType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
                    if !contentType.contains("text/event-stream") {
                        if let authReport = authSignalReport(String(data: data, encoding: .utf8) ?? "", server: server, toolID: toolID, phase: "SSE probe") {
                            return authReport
                        }
                        return report(.unknown, server, toolID, "SSE endpoint returned \(contentType.isEmpty ? "unknown content" : contentType)", "Check whether the URL points to an old SSE endpoint or a login/error page.")
                    }
                    return report(.working, server, toolID, "SSE endpoint opened", "Project Hub verified the SSE endpoint, but old SSE transports do not expose a standard tools/list URL in config.")
                case 401, 403:
                    return authChallengeReport(
                        response: http,
                        server: server,
                        toolID: toolID,
                        fallbackSummary: "SSE endpoint requires authentication"
                    )
                case 404:
                    return report(.broken, server, toolID, "SSE endpoint returned 404", "Check the URL path.")
                default:
                    return report(.unknown, server, toolID, "SSE endpoint returned HTTP \(http.statusCode)", "Check endpoint transport and authentication.")
                }
            }

            let (data, response) = try await URLSession.shared.data(
                for: request(method: "POST", body: initializeBody(), timeout: remoteRequestTimeout(startedAt: startedAt, budget: startupTimeout))
            )
            guard let http = response as? HTTPURLResponse else {
                return report(.unknown, server, toolID, "Remote probe returned a non-HTTP response", nil)
            }

            switch http.statusCode {
            case 200...299:
                let initializeMessages = jsonRPCMessages(in: data, response: http)
                if let error = jsonRPCErrorMessage(initializeMessages, id: 1) {
                    if let authReport = authSignalReport(error, server: server, toolID: toolID, phase: "Remote initialize") {
                        return authReport
                    }
                    return report(.broken, server, toolID, "MCP initialize error: \(error)", "Check the remote MCP endpoint and server logs.")
                }
                let sessionID = http.value(forHTTPHeaderField: sessionHeaderName)
                _ = try? await URLSession.shared.data(
                    for: request(method: "POST", body: initializedBody(), sessionID: sessionID, timeout: remoteRequestTimeout(startedAt: startedAt, budget: startupTimeout, cap: 1))
                )
                let (toolsData, toolsResponse) = try await URLSession.shared.data(
                    for: request(method: "POST", body: toolsListBody(), sessionID: sessionID, timeout: remoteRequestTimeout(startedAt: startedAt, budget: startupTimeout))
                )
                guard let toolsHTTP = toolsResponse as? HTTPURLResponse else {
                    return report(.working, server, toolID, "Remote initialize verified; tools/list returned non-HTTP response", nil)
                }
                switch toolsHTTP.statusCode {
                case 200...299:
                    let toolsMessages = jsonRPCMessages(in: toolsData, response: toolsHTTP)
                    if let error = jsonRPCErrorMessage(toolsMessages, id: 2) {
                        if let authReport = authSignalReport(error, server: server, toolID: toolID, phase: "Remote tools/list") {
                            return authReport
                        }
                        return report(.broken, server, toolID, "Remote tools/list error: \(error)", "Check the remote MCP endpoint and server logs.")
                    }
                    if let count = toolsCount(in: toolsMessages, id: 2) {
                        return report(.working, server, toolID, "Remote MCP handshake verified (\(count) tool\(count == 1 ? "" : "s"))", nil)
                    }
                    return report(.unknown, server, toolID, "Remote tools/list response was not recognized", "Project Hub confirmed initialize, but the tools/list body did not contain result.tools.")
                case 401, 403:
                    return authChallengeReport(
                        response: toolsHTTP,
                        server: server,
                        toolID: toolID,
                        fallbackSummary: "Remote tools/list requires authentication"
                    )
                default:
                    if let authReport = authSignalReport(httpBodyText(toolsData, response: toolsHTTP), server: server, toolID: toolID, phase: "Remote tools/list") {
                        return authReport
                    }
                    return report(.unknown, server, toolID, "Remote initialize verified; tools/list returned HTTP \(toolsHTTP.statusCode)", "Project Hub confirmed initialize but could not read the tool list.")
                }
            case 401, 403:
                return authChallengeReport(
                    response: http,
                    server: server,
                    toolID: toolID,
                    fallbackSummary: "Remote endpoint requires authentication"
                )
            case 404:
                return report(.broken, server, toolID, "Remote endpoint returned 404", "Check the URL path; MCP endpoints are often /mcp or /sse.")
            default:
                return report(.unknown, server, toolID, "Remote endpoint returned HTTP \(http.statusCode)", "Check whether the endpoint expects SSE, Streamable HTTP, or a browser OAuth flow.")
            }
        } catch {
            return report(.unknown, server, toolID, "Remote probe failed: \(error.localizedDescription)", "Check network access, VPN, TLS certificates, and endpoint availability.")
        }
    }

    private static func normalizedLaunch(_ server: ServerEntry) -> ServerEntry {
        guard server.transport == "stdio",
              let command = server.command?.trimmingCharacters(in: .whitespacesAndNewlines),
              !command.isEmpty else {
            return server
        }

        let tokens = server.args.isEmpty ? shellSplit(command) : [command] + server.args
        guard tokens.count > 1,
              let launch = normalizeLaunchTokens(tokens),
              shouldSplitCommandString(firstToken: tokens[0]) else {
            return server
        }
        var env = server.env
        env.merge(launch.env) { current, _ in current }

        return ServerEntry(
            name: server.name,
            transport: server.transport,
            command: launch.command,
            args: launch.args,
            cwd: server.cwd,
            url: server.url,
            env: env,
            headers: server.headers,
            headersHelper: server.headersHelper,
            oauth: server.oauth,
            bearerTokenEnvVar: server.bearerTokenEnvVar,
            envVars: server.envVars,
            envFile: server.envFile,
            sandboxEnabled: server.sandboxEnabled,
            sandboxSummary: server.sandboxSummary,
            devSummary: server.devSummary,
            enabledTools: server.enabledTools,
            alwaysAllowTools: server.alwaysAllowTools,
            disabledTools: server.disabledTools,
            defaultToolApprovalMode: server.defaultToolApprovalMode,
            toolApprovalModes: server.toolApprovalModes,
            watchPaths: server.watchPaths,
            serverTimeoutSeconds: server.serverTimeoutSeconds,
            startupTimeoutSeconds: server.startupTimeoutSeconds,
            toolTimeoutSeconds: server.toolTimeoutSeconds,
            sourcePath: server.sourcePath,
            sourceLabel: server.sourceLabel,
            isReadOnly: server.isReadOnly,
            readOnlyReason: server.readOnlyReason,
            codexPluginID: server.codexPluginID,
            codexPluginPolicyConfigPath: server.codexPluginPolicyConfigPath,
            codexPluginPolicyProfileName: server.codexPluginPolicyProfileName,
            codexPluginEnabled: server.codexPluginEnabled,
            isDisabled: server.isDisabled
        )
    }

    private static func normalizeLaunchTokens(_ rawTokens: [String]) -> (env: [String: String], command: String, args: [String])? {
        let tokens = expandEnvSplitString(rawTokens)
        guard !tokens.isEmpty else { return nil }
        var index = 0
        var env: [String: String] = [:]

        if isEnvCommand(tokens[index]) {
            index += 1
            while index < tokens.count {
                let token = tokens[index]
                if token == "-i" || token == "--ignore-environment" {
                    index += 1
                    continue
                }
                if token == "-u" || token == "--unset" {
                    index += 2
                    continue
                }
                if token.hasPrefix("-u"), token.count > 2 {
                    index += 1
                    continue
                }
                if token.hasPrefix("-") { return nil }
                if let assignment = envAssignment(token) {
                    env[assignment.key] = assignment.value
                    index += 1
                    continue
                }
                if isEnvName(token),
                   index + 1 < tokens.count,
                   commandStarters.contains(URL(fileURLWithPath: tokens[index + 1]).lastPathComponent.lowercased()) {
                    env[token] = "${\(token)}"
                    index += 1
                    continue
                }
                break
            }
        } else {
            while index < tokens.count, let assignment = envAssignment(tokens[index]) {
                env[assignment.key] = assignment.value
                index += 1
            }
        }

        guard index < tokens.count else { return nil }
        return (env, tokens[index], Array(tokens.dropFirst(index + 1)))
    }

    private static func expandEnvSplitString(_ tokens: [String]) -> [String] {
        guard tokens.count >= 3, isEnvCommand(tokens[0]) else { return tokens }
        var out: [String] = [tokens[0]]
        var index = 1
        while index < tokens.count {
            let token = tokens[index]
            if (token == "-S" || token == "--split-string"), index + 1 < tokens.count {
                out.append(contentsOf: shellSplit(tokens[index + 1]))
                index += 2
                continue
            }
            if token.hasPrefix("--split-string=") {
                out.append(contentsOf: shellSplit(String(token.dropFirst("--split-string=".count))))
                index += 1
                continue
            }
            out.append(token)
            index += 1
        }
        return out
    }

    private static func isEnvCommand(_ token: String) -> Bool {
        URL(fileURLWithPath: token).lastPathComponent.lowercased() == "env"
    }

    private static func envAssignment(_ token: String) -> (key: String, value: String)? {
        guard let eq = token.firstIndex(of: "="), eq > token.startIndex else { return nil }
        let key = String(token[..<eq])
        guard isEnvName(key) else { return nil }
        return (key, String(token[token.index(after: eq)...]))
    }

    private static func isEnvName(_ value: String) -> Bool {
        guard let first = value.unicodeScalars.first,
              CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_").contains(first) else {
            return false
        }
        return value.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_").contains($0)
        }
    }

    private static func probeTimeout(for server: ServerEntry, toolID: String) -> TimeInterval {
        if let configured = server.startupTimeoutSeconds, configured > 0 {
            return min(max(configured, minProbeTimeout), maxProbeTimeout)
        }
        if toolID == "roo",
           let configured = server.serverTimeoutSeconds,
           configured > 0 {
            return min(max(configured, minProbeTimeout), maxProbeTimeout)
        }
        if toolID == "claude-code",
           let timeout = ProcessInfo.processInfo.environment["MCP_TIMEOUT"],
           let milliseconds = Double(timeout.trimmingCharacters(in: .whitespacesAndNewlines)),
           milliseconds > 0 {
            return min(max(milliseconds / 1_000, minProbeTimeout), maxProbeTimeout)
        }
        return defaultProbeTimeout
    }

    private static func remainingTimeout(startedAt: Date, budget: TimeInterval) -> TimeInterval {
        max(0.01, budget - Date().timeIntervalSince(startedAt))
    }

    private static func remoteRequestTimeout(startedAt: Date, budget: TimeInterval, cap: TimeInterval = defaultProbeTimeout) -> TimeInterval {
        min(cap, remainingTimeout(startedAt: startedAt, budget: budget))
    }

    private static func normalizedHeadersHelper(_ value: String?) -> String? {
        guard let helper = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !helper.isEmpty else { return nil }
        return helper
    }

    private static func formatSeconds(_ value: TimeInterval) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    private static func shouldSplitCommandString(firstToken: String) -> Bool {
        let lower = URL(fileURLWithPath: firstToken).lastPathComponent.lowercased()
        return commandStarters.contains(lower)
    }

    private static let commandStarters: Set<String> = [
        "env", "npx", "npm", "pnpm", "yarn", "bunx", "bun",
        "uvx", "uv", "python", "python3", "pipx",
        "docker", "node", "deno", "brew", "cargo", "go"
    ]

    private static func shellSplit(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escapeNext = false

        for ch in input {
            if escapeNext {
                current.append(ch)
                escapeNext = false
                continue
            }
            if ch == "\\" && !inSingle {
                escapeNext = true
                continue
            }
            if ch == "'" && !inDouble {
                inSingle.toggle()
                continue
            }
            if ch == "\"" && !inSingle {
                inDouble.toggle()
                continue
            }
            if ch.isWhitespace && !inSingle && !inDouble {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                continue
            }
            current.append(ch)
        }

        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }

    private static func commandExists(_ command: String, cwd: String? = nil) -> Bool {
        if command.contains("/") {
            var isDir: ObjCBool = false
            let expanded = (command as NSString).expandingTildeInPath
            let path: String
            if expanded.hasPrefix("/") {
                path = expanded
            } else if let cwd {
                path = URL(fileURLWithPath: expanded, relativeTo: URL(fileURLWithPath: cwd))
                    .standardizedFileURL
                    .path
            } else {
                path = expanded
            }
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue
        }

        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        return path.split(separator: ":").contains { dir in
            let candidate = "\(dir)/\(command)"
            return FileManager.default.isExecutableFile(atPath: candidate)
        }
    }

    private static func hasMissingEnv(_ env: [String: String]) -> Bool {
        env.contains { key, value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return true }
            if looksLikePlaceholder(trimmed) { return true }
            if requiredEnvExpansionNames(in: trimmed).contains(where: {
                ProcessInfo.processInfo.environment[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
            }) {
                return true
            }
            if key.uppercased().contains("TOKEN") || key.uppercased().contains("KEY") {
                return looksLikePlaceholder(trimmed)
            }
            return false
        }
    }

    private static func resolvedCWD(_ raw: String?, configPath: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        var value = raw
        if let configPath {
            let workspace = workspaceDirectory(forConfigPath: configPath)
            value = expandPathPlaceholders(value, base: workspace)
            value = expandEnvRefs(value)
            let expanded = (value as NSString).expandingTildeInPath
            if expanded.hasPrefix("/") {
                return URL(fileURLWithPath: expanded).standardizedFileURL.path
            }
            return URL(fileURLWithPath: expanded, relativeTo: URL(fileURLWithPath: workspace))
                .standardizedFileURL
                .path
        }
        value = expandPathPlaceholders(value, base: nil)
        value = expandEnvRefs(value)
        let expanded = (value as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardizedFileURL.path
    }

    private static func missingDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) || !isDirectory.boolValue
    }

    private static func normalizedEnvFile(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func envFileNeedsMissingFileWarning(_ raw: String, configPath: String) -> Bool {
        let resolved = resolveEnvFilePath(raw, configPath: configPath)
        guard !resolved.contains("${") else { return false }
        var isDirectory: ObjCBool = false
        return !FileManager.default.fileExists(atPath: resolved, isDirectory: &isDirectory) || isDirectory.boolValue
    }

    private static func resolveEnvFilePath(_ raw: String, configPath: String) -> String {
        let configDirectory = workspaceDirectory(forConfigPath: configPath)
        var value = raw
        value = expandPathPlaceholders(value, base: configDirectory)
        value = expandEnvRefs(value)
        let expanded = (value as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded).standardizedFileURL.path
        }
        return URL(fileURLWithPath: expanded, relativeTo: URL(fileURLWithPath: configDirectory))
            .standardizedFileURL
            .path
    }

    private static func workspaceDirectory(forConfigPath configPath: String) -> String {
        let directory = (configPath as NSString).deletingLastPathComponent
        let name = (directory as NSString).lastPathComponent
        if [".vscode", ".cursor", ".roo", ".claude", ".codex"].contains(name) {
            return (directory as NSString).deletingLastPathComponent
        }
        return directory
    }

    private static func missingEnvVars(_ names: [String]) -> [String] {
        names
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { ProcessInfo.processInfo.environment[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true }
            .sorted()
    }

    private static func missingDockerEnvFlagVars(command: String, args: [String]) -> [String] {
        guard URL(fileURLWithPath: command).lastPathComponent.lowercased() == "docker" else { return [] }
        return dockerEnvFlagVars(in: args)
            .filter { ProcessInfo.processInfo.environment[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true }
            .sorted()
    }

    private static func dockerEnvFlagVars(in args: [String]) -> Set<String> {
        var names = Set<String>()
        var index = 0
        while index < args.count {
            let token = args[index]
            if token == "-e" || token == "--env" {
                index += 1
                if index < args.count {
                    recordDockerEnvFlag(args[index], into: &names)
                }
            } else if token.hasPrefix("--env=") {
                recordDockerEnvFlag(String(token.dropFirst("--env=".count)), into: &names)
            } else if token.hasPrefix("-e"), token.count > 2 {
                recordDockerEnvFlag(String(token.dropFirst(2)), into: &names)
            }
            index += 1
        }
        return names
    }

    private static func missingDockerPathEnvVars(command: String, args: [String]) -> [String] {
        guard URL(fileURLWithPath: command).lastPathComponent.lowercased() == "docker" else { return [] }
        return Array(Set((dockerEnvFileArgs(in: args) + dockerHostMountArgs(in: args)).flatMap(requiredEnvExpansionNames(in:))))
            .filter { ProcessInfo.processInfo.environment[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true }
            .sorted()
    }

    private static func recordDockerEnvFlag(_ raw: String, into names: inout Set<String>) {
        if let eq = raw.firstIndex(of: "="), eq > raw.startIndex {
            let value = String(raw[raw.index(after: eq)...])
            names.formUnion(requiredEnvExpansionNames(in: value))
            return
        }
        if isEnvironmentVariableName(raw) {
            names.insert(raw)
        }
    }

    private static func missingDockerEnvFilePaths(command: String, args: [String], cwd: String?, configPath: String?) -> [String] {
        guard URL(fileURLWithPath: command).lastPathComponent.lowercased() == "docker" else { return [] }
        return dockerEnvFileArgs(in: args)
            .filter { missingRequiredEnvExpansionNames(in: $0).isEmpty && inputVariableReferences(in: $0).isEmpty }
            .map { resolveDockerHostPath($0, cwd: cwd, configPath: configPath) }
            .filter { path in
                var isDirectory: ObjCBool = false
                return !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) || isDirectory.boolValue
            }
            .sorted()
    }

    private static func dockerEnvFileArgs(in args: [String]) -> [String] {
        var paths: [String] = []
        var index = 0
        while index < args.count {
            let token = args[index]
            if token == "--env-file" {
                index += 1
                if index < args.count { paths.append(args[index]) }
            } else if token.hasPrefix("--env-file=") {
                paths.append(String(token.dropFirst("--env-file=".count)))
            }
            index += 1
        }
        return paths.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func missingDockerMountPaths(command: String, args: [String], cwd: String?, configPath: String?) -> [String] {
        guard URL(fileURLWithPath: command).lastPathComponent.lowercased() == "docker" else { return [] }
        return dockerHostMountArgs(in: args)
            .filter { missingRequiredEnvExpansionNames(in: $0).isEmpty && inputVariableReferences(in: $0).isEmpty }
            .map { resolveDockerHostPath($0, cwd: cwd, configPath: configPath) }
            .filter { !FileManager.default.fileExists(atPath: $0) }
            .sorted()
    }

    private static func dockerHostMountArgs(in args: [String]) -> [String] {
        var paths: [String] = []
        var index = 0
        while index < args.count {
            let token = args[index]
            if token == "-v" || token == "--volume" {
                index += 1
                if index < args.count { recordDockerVolumeMount(args[index], into: &paths) }
            } else if token.hasPrefix("--volume=") {
                recordDockerVolumeMount(String(token.dropFirst("--volume=".count)), into: &paths)
            } else if token == "--mount" {
                index += 1
                if index < args.count { recordDockerStructuredMount(args[index], into: &paths) }
            } else if token.hasPrefix("--mount=") {
                recordDockerStructuredMount(String(token.dropFirst("--mount=".count)), into: &paths)
            }
            index += 1
        }
        return paths
    }

    private static func recordDockerVolumeMount(_ raw: String, into paths: inout [String]) {
        guard let colon = raw.firstIndex(of: ":") else { return }
        recordDockerHostPathCandidate(String(raw[..<colon]), treatPlainAsRelative: false, into: &paths)
    }

    private static func recordDockerStructuredMount(_ raw: String, into paths: inout [String]) {
        var fields: [String: String] = [:]
        for field in raw.split(separator: ",") {
            guard let eq = field.firstIndex(of: "=") else { continue }
            let key = field[..<eq].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = field[field.index(after: eq)...].trimmingCharacters(in: .whitespacesAndNewlines)
            fields[key] = value
        }
        let mountType = fields["type"]?.lowercased()
        if let mountType, mountType != "bind" { return }
        if let source = fields["source"] ?? fields["src"] {
            recordDockerHostPathCandidate(source, treatPlainAsRelative: mountType == "bind", into: &paths)
        }
    }

    private static func recordDockerHostPathCandidate(_ raw: String, treatPlainAsRelative: Bool, into paths: inout [String]) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        guard treatPlainAsRelative || value.hasPrefix("/") || value.hasPrefix("~/") || value.hasPrefix("./") || value.hasPrefix("../") || value.contains("${") else { return }
        paths.append(value)
    }

    private static func resolveDockerHostPath(_ raw: String, cwd: String?, configPath: String?) -> String {
        let base = cwd ?? configPath.map(workspaceDirectory(forConfigPath:))
        var value = raw
        value = expandPathPlaceholders(value, base: base)
        value = expandEnvRefs(value)
        let expanded = (value as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded).standardizedFileURL.path
        }
        if let base {
            return URL(fileURLWithPath: expanded, relativeTo: URL(fileURLWithPath: base))
                .standardizedFileURL
                .path
        }
        return URL(fileURLWithPath: expanded).standardizedFileURL.path
    }

    private static func expandPathPlaceholders(_ raw: String, base: String?) -> String {
        var value = raw.replacingOccurrences(
            of: "${userHome}",
            with: FileManager.default.homeDirectoryForCurrentUser.path
        )
        if let base {
            value = value.replacingOccurrences(of: "${workspaceFolder}", with: base)
            value = value.replacingOccurrences(of: "${workspaceFolderBasename}", with: (base as NSString).lastPathComponent)
        }
        return value
    }

    private static func isEnvironmentVariableName(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == value,
              let first = trimmed.unicodeScalars.first,
              first == "_" || CharacterSet.uppercaseLetters.contains(first) || CharacterSet.lowercaseLetters.contains(first) else {
            return false
        }
        return trimmed.unicodeScalars.allSatisfy {
            $0 == "_" || CharacterSet.alphanumerics.contains($0)
        }
    }

    private static func inputVariableReferences(in server: ServerEntry) -> [String] {
        var refs = Set<String>()
        if let command = server.command {
            refs.formUnion(inputVariableReferences(in: command))
        }
        refs.formUnion(server.args.flatMap(inputVariableReferences(in:)))
        if let url = server.url {
            refs.formUnion(inputVariableReferences(in: url))
        }
        if let cwd = server.cwd {
            refs.formUnion(inputVariableReferences(in: cwd))
        }
        if let envFile = server.envFile {
            refs.formUnion(inputVariableReferences(in: envFile))
        }
        refs.formUnion(server.env.values.flatMap(inputVariableReferences(in:)))
        refs.formUnion(server.headers.values.flatMap(inputVariableReferences(in:)))
        if let bearer = server.bearerTokenEnvVar {
            refs.formUnion(inputVariableReferences(in: bearer))
        }
        refs.formUnion(server.envVars.flatMap(inputVariableReferences(in:)))
        return refs.sorted()
    }

    private static func inputVariableReferences(in value: String) -> [String] {
        let pattern = #"\$\{input:([^}]+)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = value as NSString
        return regex.matches(in: value, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            let raw = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            return raw.isEmpty ? nil : raw
        }
    }

    private static func meaningfulOAuthMetadata(_ oauth: [String: String]) -> [String: String] {
        var entries: [String: String] = [:]
        for (key, value) in oauth {
            let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedKey.isEmpty,
                  !normalizedValue.isEmpty,
                  !looksLikePlaceholder(normalizedValue) else { continue }
            entries[normalizedKey] = normalizedValue
        }
        guard entries.contains(where: { key, _ in !isOAuthHintOnlyKey(key) }) else { return [:] }
        return entries
    }

    private static func isOAuthHintOnlyKey(_ key: String) -> Bool {
        let normalized = key
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
        return normalized == "callbackport"
            || normalized == "callbackurl"
            || normalized == "redirecturi"
            || normalized == "scopes"
            || normalized == "scope"
    }

    private static func missingRequiredEnvExpansionNames(in value: String) -> [String] {
        requiredEnvExpansionNames(in: value)
            .filter { ProcessInfo.processInfo.environment[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true }
            .sorted()
    }

    private static func missingRequiredEnvExpansionNames(in values: [String]) -> [String] {
        Array(Set(values.flatMap(requiredEnvExpansionNames(in:))))
            .filter { ProcessInfo.processInfo.environment[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true }
            .sorted()
    }

    private static func hasMissingLaunchCredential(_ args: [String]) -> Bool {
        for (index, arg) in args.enumerated() {
            if looksLikeCredentialFlag(arg),
               index + 1 < args.count,
               looksLikePlaceholder(args[index + 1]) {
                return true
            }
            if looksLikeCredentialArgumentPlaceholder(arg) {
                return true
            }
        }
        return false
    }

    private static func looksLikeCredentialFlag(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.contains("token")
            || lower.contains("api-key")
            || lower.contains("apikey")
            || lower.contains("secret")
            || lower.contains("password")
    }

    private static func hostedOAuthMCPProvider(for urlString: String) -> String? {
        guard let url = URL(string: expandEnvRefs(urlString)),
              let host = url.host?.lowercased() else { return nil }
        if host == "mcp.supabase.com" { return "Supabase" }
        if host == "api.githubcopilot.com" { return "GitHub" }
        if host == "mcp.notion.com" { return "Notion" }
        if host == "mcp.atlassian.com" { return "Atlassian" }
        return nil
    }

    private static func looksLikePlaceholder(_ value: String) -> Bool {
        let upper = value.uppercased()
        return upper.contains("YOUR_")
            || upper.contains("YOUR-")
            || upper.contains("<")
            || upper.contains("...")
            || upper == "TOKEN"
            || upper == "API_KEY"
            || upper == "REPLACE_ME"
    }

    private static func looksLikeCredentialArgumentPlaceholder(_ value: String) -> Bool {
        let upper = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return looksLikePlaceholder(value)
            && (upper.contains("TOKEN")
                || upper.contains("API")
                || upper.contains("SECRET")
                || upper.contains("PASSWORD")
                || upper.contains("KEY")
                || upper.contains("YOUR_")
                || upper.contains("REPLACE_ME")
                || upper.contains("<"))
    }

    private static func authSignalReport(
        _ text: String,
        server: ServerEntry,
        toolID: String,
        phase: String
    ) -> MCPHealthReport? {
        let lower = text.lowercased()
        let expiredSignals = [
            "expired",
            "token has expired",
            "invalid_grant",
            "reauth",
            "re-auth"
        ]
        if expiredSignals.contains(where: lower.contains) {
            return report(
                .authExpired,
                server,
                toolID,
                "\(phase) auth expired: \(redactedDiagnostic(text))",
                "Refresh the vendor login/OAuth token, restart the target app or terminal, then run Verify again."
            )
        }

        let authSignals = [
            "unauthorized",
            "forbidden",
            "authentication required",
            "auth required",
            "authorization required",
            "please authorize",
            "please authenticate",
            "not authenticated",
            "login required",
            "sign in",
            "oauth",
            "api key",
            "apikey",
            "access token",
            "bearer token",
            "missing token",
            "invalid token",
            "invalid api key",
            "401",
            "403"
        ]
        guard authSignals.contains(where: lower.contains) else { return nil }
        return report(
            .needsAuth,
            server,
            toolID,
            "\(phase) requires authentication: \(redactedDiagnostic(text))",
            "Complete the vendor login/OAuth flow or provide the required environment-backed credential, then restart the target app or terminal."
        )
    }

    private static func authChallengeReport(
        response: HTTPURLResponse,
        server: ServerEntry,
        toolID: String,
        fallbackSummary: String
    ) -> MCPHealthReport {
        guard let challenge = response.value(forHTTPHeaderField: "WWW-Authenticate"),
              challenge.lowercased().contains("bearer") else {
            return report(.needsAuth, server, toolID, fallbackSummary, "Complete OAuth/login or configure the required bearer token/header.")
        }

        if let resourceMetadata = authChallengeParameter("resource_metadata", in: challenge) {
            return report(
                .needsAuth,
                server,
                toolID,
                "Remote endpoint requires OAuth login",
                "Complete the target tool's browser/OAuth MCP login flow. Protected resource metadata: \(resourceMetadata)"
            )
        }

        return report(
            .needsAuth,
            server,
            toolID,
            "Remote endpoint requires bearer authentication",
            "Complete OAuth/login or configure the required bearer token/header."
        )
    }

    private static func authChallengeParameter(_ name: String, in challenge: String) -> String? {
        let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: name) + #"\s*=\s*"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = challenge as NSString
        guard let match = regex.firstMatch(in: challenge, range: NSRange(location: 0, length: ns.length)),
              match.range(at: 1).location != NSNotFound else { return nil }
        return ns.substring(with: match.range(at: 1))
    }

    private static func redactedDiagnostic(_ text: String, limit: Int = 140) -> String {
        var output = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            (#"(?i)(bearer\s+)[A-Za-z0-9._~+/=-]+"#, "$1[redacted]"),
            (#"(?i)((?:api[_-]?key|token|secret|password)\s*[:=]\s*)[^\s,;]+"#, "$1[redacted]")
        ]
        for (pattern, replacement) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            output = regex.stringByReplacingMatches(
                in: output,
                range: NSRange(location: 0, length: (output as NSString).length),
                withTemplate: replacement
            )
        }
        return String(output.prefix(limit))
    }

    private static func requiredEnvExpansionNames(in value: String) -> [String] {
        let ns = value as NSString
        let patterns = [
            #"\$\{env:([A-Za-z_][A-Za-z0-9_]*)(?::-[^}]*)?\}"#,
            #"\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-[^}]*)?\}"#
        ]
        var names: [String] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: value, range: NSRange(location: 0, length: ns.length)) {
                let raw = ns.substring(with: match.range(at: 0))
                guard !raw.contains(":-") else { continue }
                let name = ns.substring(with: match.range(at: 1))
                if !isWorkspacePlaceholderName(name) {
                    names.append(name)
                }
            }
        }
        return Array(Set(names)).sorted()
    }

    private static func expandEnvRefs(_ value: String) -> String {
        var result = expandEnvRefs(
            value,
            pattern: #"\$\{env:([A-Za-z_][A-Za-z0-9_]*)(?::-(.*?))?\}"#
        )
        result = expandEnvRefs(
            result,
            pattern: #"\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-(.*?))?\}"#
        )
        return result
    }

    private static func expandEnvRefs(_ value: String, pattern: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        var result = value
        let ns = value as NSString
        let matches = regex.matches(in: value, range: NSRange(location: 0, length: ns.length)).reversed()
        for match in matches {
            let raw = ns.substring(with: match.range(at: 0))
            let name = ns.substring(with: match.range(at: 1))
            let fallback = match.range(at: 2).location != NSNotFound ? ns.substring(with: match.range(at: 2)) : ""
            let replacement: String
            if let envValue = ProcessInfo.processInfo.environment[name] {
                replacement = envValue
            } else if match.range(at: 2).location != NSNotFound {
                replacement = fallback
            } else if isWorkspacePlaceholderName(name) {
                replacement = raw
            } else {
                replacement = ""
            }
            if let range = Range(match.range(at: 0), in: result) {
                result.replaceSubrange(range, with: replacement)
            }
        }
        return result
    }

    private static func isWorkspacePlaceholderName(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized == "workspaceFolder"
            || normalized == "workspaceFolderBasename"
            || normalized == "userHome"
    }

    private static func initializePayload() -> Data {
        var data = initializeBody()
        data.append(0x0A)
        return data
    }

    private static func initializedPayload() -> Data {
        var data = initializedBody()
        data.append(0x0A)
        return data
    }

    private static func initializedBody() -> Data {
        let object: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "notifications/initialized",
            "params": [:]
        ]
        return (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }

    private static func toolsListPayload() -> Data {
        var data = toolsListBody()
        data.append(0x0A)
        return data
    }

    private static func toolsListBody() -> Data {
        let object: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list",
            "params": [:]
        ]
        return (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }

    private static func initializeBody() -> Data {
        let object: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": [
                "protocolVersion": "2025-06-18",
                "capabilities": [:],
                "clientInfo": [
                    "name": "Project Hub",
                    "version": "1.0"
                ]
            ]
        ]
        return (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }

    private static func jsonRPCErrorMessage(_ data: Data) -> String? {
        guard !data.isEmpty,
              let any = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return jsonRPCErrorMessage(any)
    }

    private static func jsonRPCErrorMessage(_ line: String) -> String? {
        guard let data = line.data(using: .utf8),
              let any = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return jsonRPCErrorMessage(any)
    }

    private static func jsonRPCErrorMessage(_ any: Any) -> String? {
        guard let obj = any as? [String: Any],
              let error = obj["error"] as? [String: Any] else { return nil }
        return (error["message"] as? String) ?? "Unknown JSON-RPC error"
    }

    private static func toolsCount(in line: String) -> Int? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = obj["result"] as? [String: Any],
              let tools = result["tools"] as? [Any] else { return nil }
        return tools.count
    }

    private static func toolsCount(in data: Data) -> Int? {
        guard !data.isEmpty,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = obj["result"] as? [String: Any],
              let tools = result["tools"] as? [Any] else { return nil }
        return tools.count
    }

    private static func jsonRPCMessages(in data: Data, response: HTTPURLResponse) -> [Data] {
        guard !data.isEmpty else { return [] }
        let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        guard contentType.contains("text/event-stream") else { return [data] }
        return sseDataMessages(in: data)
    }

    private static func sseDataMessages(in data: Data) -> [Data] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var messages: [Data] = []
        var currentLines: [String] = []

        func flush() {
            let payload = currentLines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !payload.isEmpty,
               let data = payload.data(using: .utf8) {
                messages.append(data)
            }
            currentLines = []
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
            if line.isEmpty {
                flush()
                continue
            }
            if line.hasPrefix("data:") {
                var value = String(line.dropFirst("data:".count))
                if value.hasPrefix(" ") { value.removeFirst() }
                currentLines.append(value)
            }
        }
        flush()
        return messages
    }

    private static func jsonRPCErrorMessage(_ messages: [Data], id: Int) -> String? {
        for data in messages {
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  jsonRPCID(in: obj) == id,
                  let error = obj["error"] else { continue }
            if let errorObject = error as? [String: Any] {
                return (errorObject["message"] as? String) ?? "Unknown JSON-RPC error"
            }
            if let message = error as? String {
                return message
            }
            return "Unknown JSON-RPC error"
        }
        return nil
    }

    private static func toolsCount(in messages: [Data], id: Int) -> Int? {
        for data in messages {
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  jsonRPCID(in: obj) == id,
                  let result = obj["result"] as? [String: Any],
                  let tools = result["tools"] as? [Any] else { continue }
            return tools.count
        }
        return nil
    }

    private static func jsonRPCID(in obj: [String: Any]) -> Int? {
        if let id = obj["id"] as? Int { return id }
        if let id = obj["id"] as? String { return Int(id) }
        return nil
    }

    private static func httpBodyText(_ data: Data, response: HTTPURLResponse) -> String {
        let messages = jsonRPCMessages(in: data, response: response)
        if let error = jsonRPCErrorMessage(messages, id: 2) {
            return error
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func restartHint(for toolID: String) -> String {
        switch toolID {
        case "claude-desktop": return "Quit and reopen Claude Desktop to load the change."
        case "claude-code": return "Restart the Claude Code session to load the change."
        case "codex": return "Restart Codex CLI/Desktop session to load the change."
        default: return "Restart the target app to load the change."
        }
    }
}

private final class LockedProbeBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var stdout = Data()
    private var stderr = Data()
    private var responseLinesByID: [Int: String] = [:]

    func appendStdout(_ data: Data) -> Set<Int> {
        lock.lock()
        defer { lock.unlock() }
        var completed = Set<Int>()
        stdout.append(data)
        guard let text = String(data: stdout, encoding: .utf8) else { return completed }
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, line.contains("\"id\""),
                  let id = jsonRPCID(in: line),
                  responseLinesByID[id] == nil else { continue }
            responseLinesByID[id] = line
            completed.insert(id)
        }
        return completed
    }

    func responseLine(id: Int) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return responseLinesByID[id]
    }

    func appendStderr(_ data: Data) {
        lock.lock()
        stderr.append(data)
        lock.unlock()
    }

    var stderrText: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: stderr, encoding: .utf8) ?? ""
    }

    private func jsonRPCID(in line: String) -> Int? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let id = obj["id"] as? Int { return id }
        if let id = obj["id"] as? String { return Int(id) }
        return nil
    }
}
