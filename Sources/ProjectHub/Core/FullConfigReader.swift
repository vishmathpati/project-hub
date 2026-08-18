import Foundation
import AppKit

// MARK: - Config reader

final class ConfigReader {
    static let shared = ConfigReader()
    private init() {}

    private let home = FileManager.default.homeDirectoryForCurrentUser.path
    private let cwd  = FileManager.default.currentDirectoryPath
    private let fm   = FileManager.default
    private var codexHome: String {
        ProjectHubPaths.codexHome(home: home)
    }
    private var claudeCodeJSONPath: String {
        if let override = ProcessInfo.processInfo.environment["PROJECTHUB_CLAUDE_JSON_PATH"],
           !override.isEmpty {
            return override
        }
        return "\(home)/.claude.json"
    }
    private var claudeDesktopSupportDirectory: String {
        if let override = ProcessInfo.processInfo.environment["PROJECTHUB_CLAUDE_DESKTOP_SUPPORT_DIR"],
           !override.isEmpty {
            return override
        }
        return "\(home)/Library/Application Support/Claude"
    }

    // Read every primary tool from its own config file. Plugin-owned MCP
    // evidence stays on Compat / Plugins — this path must stay page-local.
    func readAllTools() -> [ToolSummary] {
        ALL_TOOL_META.filter { PRIMARY_TOOL_IDS.contains($0.id) }.map { meta in
            let (detected, servers) = readTool(id: meta.id)
            return ToolSummary(
                toolID:   meta.id,
                label:    meta.label,
                short:    meta.short,
                detected: detected,
                configPath: ToolSpecs.spec(for: meta.id)?.path,
                servers:  servers
            )
        }
    }

    // MARK: - Per-tool dispatch

    private func readTool(id: String) -> (detected: Bool, servers: [ServerEntry]) {
        switch id {

        case "claude-desktop":
            let dir  = claudeDesktopSupportDirectory
            let path = "\(dir)/claude_desktop_config.json"
            return (fm.fileExists(atPath: dir) || appExists("com.anthropic.claudefordesktop"),
                    (readJsonServers(path: path, key: "mcpServers") + readClaudeDesktopExtensionServers(supportDirectory: dir))
                        .sorted { $0.name.lowercased() < $1.name.lowercased() })

        case "claude-code":
            let path = claudeCodeJSONPath
            return (onPath("claude") || fm.fileExists(atPath: path),
                    readJsonServers(path: path, key: "mcpServers"))

        case "cursor":
            let path = "\(home)/.cursor/mcp.json"
            return (fm.fileExists(atPath: "\(home)/.cursor") || appExists("com.todesktop.230313mzl4w4u92"),
                    readJsonServers(path: path, key: "mcpServers"))

        case "vscode":
            let path = "\(home)/Library/Application Support/Code/User/mcp.json"
            return (onPath("code") || appExists("com.microsoft.VSCode"),
                    readJsonServers(path: path, key: "servers"))

        case "codex":
            let path = "\(codexHome)/config.toml"
            return (onPath("codex") || fm.fileExists(atPath: codexHome),
                    readCodexServers(path: path))

        case "windsurf":
            let path = "\(home)/.codeium/windsurf/mcp_config.json"
            return (fm.fileExists(atPath: "\(home)/.codeium/windsurf") || appExists("com.codeium.windsurf"),
                    readJsonServers(path: path, key: "mcpServers"))

        case "zed":
            let path = "\(home)/.config/zed/settings.json"
            return (fm.fileExists(atPath: "\(home)/.config/zed") || appExists("dev.zed.Zed"),
                    readJsonNestedServers(path: path, keys: ["context_servers"]))

        case "continue":
            let path = "\(home)/.continue/config.yaml"
            return (fm.fileExists(atPath: "\(home)/.continue"),
                    readYamlServers(path: path))

        case "gemini":
            let path = "\(home)/.gemini/settings.json"
            return (onPath("gemini") || fm.fileExists(atPath: "\(home)/.gemini"),
                    readJsonServers(path: path, key: "mcpServers"))

        case "roo":
            let path = "\(home)/.roo/mcp_settings.json"
            let legacyPath = "\(home)/.roo/mcp.json"
            let servers = readJsonServers(path: path, key: "mcpServers")
            let legacyServers = servers.isEmpty ? readJsonServers(path: legacyPath, key: "mcpServers") : []
            return (fm.fileExists(atPath: "\(home)/.roo") || fm.fileExists(atPath: path) || fm.fileExists(atPath: legacyPath),
                    servers.isEmpty ? legacyServers : servers)

        case "opencode":
            // sst/opencode — global config uses `mcp` key (not mcpServers).
            let path = "\(home)/.config/opencode/opencode.json"
            return (onPath("opencode") || fm.fileExists(atPath: "\(home)/.config/opencode"),
                    readJsonServers(path: path, key: "mcp"))

        case "cline":
            // Cline is a VS Code extension; it writes to its own globalStorage dir.
            let path = "\(home)/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
            return (fm.fileExists(atPath: path) ||
                    fm.fileExists(atPath: "\(home)/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev"),
                    readJsonServers(path: path, key: "mcpServers"))

        case "antigravity":
            let path = "\(home)/.gemini/config/mcp_config.json"
            return (onPath("agy") || fm.fileExists(atPath: "\(home)/.gemini/antigravity-cli") || fm.fileExists(atPath: path),
                    readJsonServers(path: path, key: "mcpServers"))

        case "pi":
            let path = "\(home)/.pi/agent/mcp.json"
            return (onPath("pi") || fm.fileExists(atPath: "\(home)/.pi/agent"),
                    readJsonServers(path: path, key: "mcpServers"))

        case "command-code":
            let path = "\(home)/.commandcode/mcp.json"
            return (onPath("command-code") || onPath("cmdc") || fm.fileExists(atPath: "\(home)/.commandcode"),
                    readJsonServers(path: path, key: "mcpServers"))

        case "grok":
            let path = "\(home)/.grok/config.toml"
            return (onPath("grok") || fm.fileExists(atPath: "\(home)/.grok"),
                    readCodexServers(path: path))

        default:
            return (false, [])
        }
    }

    // MARK: - JSON / JSONC

    private func readJsonServers(path: String, key: String) -> [ServerEntry] {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        let stripped = stripJsonComments(raw)
        guard
            let data = stripped.data(using: .utf8),
            let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        var result: [ServerEntry] = []
        if let dict = obj[key] as? [String: Any] {
            result += parseServerDict(dict, isDisabled: false)
        }
        if let disabled = obj["\(key)_disabled"] as? [String: Any] {
            result += parseServerDict(disabled, isDisabled: true)
        }
        return result.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private func readJsonNestedServers(path: String, keys: [String]) -> [ServerEntry] {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        let stripped = stripJsonComments(raw)
        guard
            let data = stripped.data(using: .utf8),
            var obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        for key in keys.dropLast() {
            guard let next = obj[key] as? [String: Any] else { return [] }
            obj = next
        }
        guard let lastKey = keys.last, let dict = obj[lastKey] as? [String: Any] else { return [] }
        return parseServerDict(dict)
    }

    private func parseServerDict(_ dict: [String: Any], isDisabled: Bool = false) -> [ServerEntry] {
        dict.compactMap { name, value -> ServerEntry? in
            guard let props = value as? [String: Any] else { return nil }
            let launch = launchMetadata(from: props)
            let command = launch.command
            let args = launch.args
            let cwd = props["cwd"] as? String ?? props["workingDirectory"] as? String ?? props["working_directory"] as? String
            let url     = props["url"] as? String
            var env     = stringDict(props["env"])
            env.merge(launch.env) { current, _ in current }
            let envVars = codexLocalEnvVars(props["env_vars"])
            let envFile = props["envFile"] as? String ?? props["env_file"] as? String ?? launch.envFile
            var headers = stringDict(props["headers"])
            headers.merge(stringDict(props["http_headers"])) { _, new in new }
            for (header, envName) in stringDict(props["env_http_headers"]) {
                headers[header] = "${\(envName)}"
            }
            let bearerTokenEnvVar = props["bearer_token_env_var"] as? String
            let inlineDisabled = boolValue(props["disabled"]) == true
            let transport: String
            if let t = props["type"] as? String { transport = t }
            else if url != nil { transport = "http" }
            else { transport = "stdio" }
            return ServerEntry(
                name: name,
                transport: transport,
                command: command,
                args: args,
                cwd: cwd,
                url: url,
                env: env,
                headers: headers,
                headersHelper: props["headersHelper"] as? String,
                oauth: oauthMetadata(props["oauth"]),
                bearerTokenEnvVar: bearerTokenEnvVar,
                envVars: envVars,
                envFile: envFile,
                sandboxEnabled: boolValue(props["sandboxEnabled"] ?? props["sandbox_enabled"]),
                sandboxSummary: configSummary(props["sandbox"]),
                devSummary: configSummary(props["dev"]),
                enabledTools: stringArray(props["enabledTools"] ?? props["enabled_tools"]),
                alwaysAllowTools: stringArray(props["alwaysAllow"] ?? props["always_allow"]),
                disabledTools: stringArray(props["disabledTools"] ?? props["disabled_tools"]),
                defaultToolApprovalMode: props["defaultToolApprovalMode"] as? String ?? props["default_tools_approval_mode"] as? String,
                toolApprovalModes: toolApprovalModes(from: props),
                watchPaths: stringArray(props["watchPaths"] ?? props["watch_paths"]),
                serverTimeoutSeconds: codexNumber(props["timeout"]),
                isDisabled: isDisabled || inlineDisabled
            )
        }
    }

    // MARK: - Claude Desktop extensions

    private func readClaudeDesktopExtensionServers(supportDirectory: String) -> [ServerEntry] {
        let extensionDirectory = (supportDirectory as NSString).appendingPathComponent("Claude Extensions")
        guard let entries = try? fm.contentsOfDirectory(atPath: extensionDirectory) else { return [] }

        return entries.sorted().flatMap { entry -> [ServerEntry] in
            guard !entry.hasPrefix(".") else { return [] }
            let extensionRoot = (extensionDirectory as NSString).appendingPathComponent(entry)
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: extensionRoot, isDirectory: &isDirectory), isDirectory.boolValue else {
                return []
            }
            guard let manifestPath = claudeDesktopExtensionManifestPath(in: extensionRoot),
                  let manifest = readJSONFile(manifestPath),
                  let config = claudeDesktopExtensionMCPConfig(
                    manifest: manifest,
                    extensionRoot: extensionRoot,
                    settings: claudeDesktopExtensionSettings(extensionID: entry, supportDirectory: supportDirectory)
                  ) else {
                return []
            }

            let displayName = claudeDesktopExtensionDisplayName(manifest: manifest, fallback: entry)
            let disabled = claudeDesktopExtensionSettings(extensionID: entry, supportDirectory: supportDirectory)
                .flatMap { $0["isEnabled"] as? Bool }
                .map { !$0 } ?? false
            let reason = "Installed through Claude Desktop extensions. This inventory row is read-only because Claude Desktop owns the extension package and settings."

            return parseServerDict([displayName: config], isDisabled: disabled).map { server in
                ServerEntry(
                    name: server.name,
                    transport: server.transport,
                    command: server.command,
                    args: server.args,
                    cwd: server.cwd,
                    url: server.url,
                    env: server.env,
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
                    sourcePath: manifestPath,
                    sourceLabel: "Claude Desktop extension: \(displayName)",
                    isReadOnly: true,
                    readOnlyReason: reason,
                    isDisabled: server.isDisabled
                )
            }
        }
    }

    private func claudeDesktopExtensionManifestPath(in extensionRoot: String) -> String? {
        let manifest = (extensionRoot as NSString).appendingPathComponent("manifest.json")
        if fm.fileExists(atPath: manifest) { return manifest }
        let bundledManifest = (extensionRoot as NSString).appendingPathComponent("manifest.mcpb.json")
        if fm.fileExists(atPath: bundledManifest) { return bundledManifest }
        return nil
    }

    private func claudeDesktopExtensionSettings(extensionID: String, supportDirectory: String) -> [String: Any]? {
        let path = (supportDirectory as NSString)
            .appendingPathComponent("Claude Extensions Settings/\(extensionID).json")
        return readJSONFile(path)
    }

    private func claudeDesktopExtensionMCPConfig(
        manifest: [String: Any],
        extensionRoot: String,
        settings: [String: Any]?
    ) -> [String: Any]? {
        guard let server = manifest["server"] as? [String: Any] else { return nil }

        if var config = server["mcp_config"] as? [String: Any] {
            config = replaceClaudeDesktopExtensionPlaceholders(
                in: config,
                extensionRoot: extensionRoot,
                manifest: manifest,
                settings: settings
            ) as? [String: Any] ?? config
            if config["type"] == nil { config["type"] = "stdio" }
            return config
        }

        guard let type = (server["type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              type == "uv",
              let entryPoint = (server["entry_point"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !entryPoint.isEmpty else {
            return nil
        }
        return [
            "type": "stdio",
            "command": "uv",
            "args": [entryPoint]
        ]
    }

    private func replaceClaudeDesktopExtensionPlaceholders(
        in value: Any,
        extensionRoot: String,
        manifest: [String: Any],
        settings: [String: Any]?
    ) -> Any {
        if let string = value as? String {
            return replaceClaudeDesktopExtensionPlaceholders(
                in: string,
                extensionRoot: extensionRoot,
                manifest: manifest,
                settings: settings
            )
        }
        if let array = value as? [Any] {
            return array.flatMap { item -> [Any] in
                if let string = item as? String,
                   let replacement = exactClaudeDesktopExtensionUserConfigValue(
                    in: string,
                    manifest: manifest,
                    settings: settings
                   ) {
                    if let values = replacement as? [Any] {
                        return values.map(claudeDesktopExtensionUserConfigString)
                    }
                    return [claudeDesktopExtensionUserConfigString(replacement)]
                }
                return [
                    replaceClaudeDesktopExtensionPlaceholders(
                        in: item,
                        extensionRoot: extensionRoot,
                        manifest: manifest,
                        settings: settings
                    )
                ]
            }
        }
        if let dict = value as? [String: Any] {
            return dict.mapValues {
                replaceClaudeDesktopExtensionPlaceholders(
                    in: $0,
                    extensionRoot: extensionRoot,
                    manifest: manifest,
                    settings: settings
                )
            }
        }
        return value
    }

    private func replaceClaudeDesktopExtensionPlaceholders(
        in string: String,
        extensionRoot: String,
        manifest: [String: Any],
        settings: [String: Any]?
    ) -> String {
        var replaced = string.replacingOccurrences(of: "${__dirname}", with: extensionRoot)
        guard let userConfig = manifest["user_config"] as? [String: Any] else { return replaced }
        for key in userConfig.keys.sorted() {
            guard let value = claudeDesktopExtensionUserConfigValue(
                key: key,
                manifest: manifest,
                settings: settings
            ) else { continue }
            replaced = replaced.replacingOccurrences(
                of: "${user_config.\(key)}",
                with: claudeDesktopExtensionUserConfigString(value)
            )
        }
        return replaced
    }

    private func exactClaudeDesktopExtensionUserConfigValue(
        in string: String,
        manifest: [String: Any],
        settings: [String: Any]?
    ) -> Any? {
        guard string.hasPrefix("${user_config."),
              string.hasSuffix("}") else { return nil }
        let start = string.index(string.startIndex, offsetBy: "${user_config.".count)
        let key = String(string[start..<string.index(before: string.endIndex)])
        return claudeDesktopExtensionUserConfigValue(key: key, manifest: manifest, settings: settings)
    }

    private func claudeDesktopExtensionUserConfigValue(
        key: String,
        manifest: [String: Any],
        settings: [String: Any]?
    ) -> Any? {
        if let configured = settings?["userConfig"] as? [String: Any],
           let value = configured[key] {
            return value
        }
        guard let definitions = manifest["user_config"] as? [String: Any],
              let definition = definitions[key] as? [String: Any],
              let value = definition["default"] else {
            return nil
        }
        if let array = value as? [Any], array.isEmpty { return nil }
        if let string = value as? String, string.isEmpty { return nil }
        return value
    }

    private func claudeDesktopExtensionUserConfigString(_ value: Any) -> String {
        if let string = value as? String { return string }
        if let strings = value as? [String] { return strings.joined(separator: ",") }
        if let array = value as? [Any] {
            return array.map(claudeDesktopExtensionUserConfigString).joined(separator: ",")
        }
        if let number = value as? NSNumber { return number.stringValue }
        return "\(value)"
    }

    private func claudeDesktopExtensionDisplayName(manifest: [String: Any], fallback: String) -> String {
        [manifest["display_name"], manifest["name"], fallback]
            .compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? fallback
    }

    private func launchCommand(from props: [String: Any]) -> (command: String?, args: [String]) {
        let launch = launchMetadata(from: props)
        return (launch.command, launch.args)
    }

    private func launchMetadata(from props: [String: Any]) -> MCPLaunchMetadata {
        MCPLaunchNormalizer.metadata(command: props["command"], args: stringArray(props["args"]))
    }

    private func stringDict(_ value: Any?) -> [String: String] {
        guard let dict = value as? [String: Any] else { return [:] }
        return Dictionary(uniqueKeysWithValues: dict.map { ($0.key, "\($0.value)") })
    }

    private func boolValue(_ value: Any?) -> Bool? {
        if let bool = value as? Bool { return bool }
        if let string = value as? String {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        return nil
    }

    private func configSummary(_ value: Any?) -> String? {
        switch value {
        case let dict as [String: Any]:
            let keys = dict.keys.sorted()
            return keys.isEmpty ? "{}" : "{\(keys.joined(separator: ", "))}"
        case let array as [Any]:
            return "[\(array.count) values]"
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let bool as Bool:
            return bool ? "true" : "false"
        case let number as NSNumber:
            return "\(number)"
        case .some(let raw):
            return "\(raw)"
        case .none:
            return nil
        }
    }

    private func oauthMetadata(_ value: Any?) -> [String: String] {
        let entries = stringDict(value).filter { key, value in
            !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !looksLikeCredentialPlaceholder(value)
        }
        guard entries.contains(where: { key, _ in !isOAuthHintOnlyKey(key) }) else { return [:] }
        return entries
    }

    private func isOAuthHintOnlyKey(_ key: String) -> Bool {
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

    private func looksLikeCredentialPlaceholder(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = trimmed.uppercased()
        return trimmed.isEmpty
            || upper.contains("YOUR_")
            || upper.contains("YOUR-")
            || upper.contains("REPLACE_ME")
            || upper.contains("<TOKEN>")
            || upper.contains("<API")
            || upper.contains("...")
            || upper == "TOKEN"
            || upper == "API_KEY"
            || upper == "SECRET"
            || upper == "PASSWORD"
    }

    // MARK: - TOML (Codex: [mcp_servers.name] sections)

    private func readCodexServers(path: String) -> [ServerEntry] {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        let profileConfig = codexDefaultProfileConfig(configPath: path, config: raw)
        let direct = mergeCodexServers(
            base: parseTomlMcpServers(raw),
            overlay: profileConfig.map { parseTomlMcpServers($0.config) } ?? []
        )
        let plugin = readCodexPluginServers(
            configPath: path,
            config: raw,
            profileConfig: profileConfig
        )
        return (direct + plugin).sorted {
            if $0.name.lowercased() != $1.name.lowercased() {
                return $0.name.lowercased() < $1.name.lowercased()
            }
            return ($0.sourceLabel ?? "").localizedCaseInsensitiveCompare($1.sourceLabel ?? "") == .orderedAscending
        }
    }

    private struct CodexDefaultProfileConfig {
        let name: String
        let path: String
        let config: String
    }

    private func codexDefaultProfileConfig(configPath: String, config: String) -> CodexDefaultProfileConfig? {
        guard (configPath as NSString).lastPathComponent == "config.toml",
              let profile = codexActiveProfile(config) else { return nil }
        let trimmed = profile.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("/"),
              !trimmed.contains(":") else { return nil }
        let profilePath = ((configPath as NSString).deletingLastPathComponent as NSString)
            .appendingPathComponent("\(trimmed).config.toml")
        guard let profileConfig = try? String(contentsOfFile: profilePath, encoding: .utf8) else {
            return nil
        }
        return CodexDefaultProfileConfig(name: trimmed, path: profilePath, config: profileConfig)
    }

    private func mergeCodexServers(base: [ServerEntry], overlay: [ServerEntry]) -> [ServerEntry] {
        var byName: [String: ServerEntry] = [:]
        var order: [String] = []
        for server in base + overlay {
            if byName[server.name] == nil {
                order.append(server.name)
            }
            byName[server.name] = server
        }
        return order.compactMap { byName[$0] }
    }

    private func readTomlServers(path: String) -> [ServerEntry] {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        return parseTomlMcpServers(raw)
    }

    private struct CodexPluginInstall {
        let id: String
        let installPath: String
        let version: String
        let enabled: Bool
    }

    private func readCodexPluginServers(
        configPath: String,
        config: String,
        profileConfig: CodexDefaultProfileConfig?
    ) -> [ServerEntry] {
        let effectiveConfig = [config, profileConfig?.config]
            .compactMap { $0 }
            .joined(separator: "\n")
        let installs = codexInstalledPlugins(configPath: configPath, config: effectiveConfig)
        guard !installs.isEmpty else { return [] }

        return installs.flatMap { plugin -> [ServerEntry] in
            let disabledNames = codexPluginDisabledMCPServers(pluginID: plugin.id, config: effectiveConfig)
            let activeProfile = codexActiveProfile(config)
            let profileOwnsPolicy = profileConfig.map {
                codexConfigMentionsPlugin(pluginID: plugin.id, config: $0.config)
            } ?? false
            let policyConfigPath = profileOwnsPolicy ? (profileConfig?.path ?? configPath) : configPath
            return codexPluginMCPConfigPaths(installPath: plugin.installPath).flatMap { mcpPath -> [ServerEntry] in
                readCodexPluginMCPServers(
                    path: mcpPath,
                    policyConfigPath: policyConfigPath,
                    activeProfile: activeProfile,
                    plugin: plugin,
                    disabledNames: disabledNames
                )
            }
        }
    }

    private func codexConfigMentionsPlugin(pluginID: String, config: String) -> Bool {
        for line in config.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let valuePart = tomlValuePart(trimmed)
            guard valuePart.hasPrefix("["),
                  valuePart.hasSuffix("]"),
                  !valuePart.hasPrefix("[[") else { continue }
            let section = String(valuePart.dropFirst().dropLast())
            let parts = splitTomlDottedKey(section)
            if parts.count >= 2, parts[0] == "plugins", parts[1] == pluginID {
                return true
            }
            if parts.count >= 4, parts[0] == "profiles", parts[2] == "plugins", parts[3] == pluginID {
                return true
            }
        }
        return false
    }

    private func codexInstalledPlugins(configPath: String, config: String) -> [CodexPluginInstall] {
        let pluginStates = codexConfiguredPluginStates(config)
        guard !pluginStates.isEmpty else { return [] }

        let cacheRoot = ((configPath as NSString).deletingLastPathComponent as NSString)
            .appendingPathComponent("plugins/cache")
        var installs: [CodexPluginInstall] = []
        for pluginID in pluginStates.keys.sorted() {
            guard let parsed = codexPluginIDParts(pluginID) else { continue }
            let pluginCacheRoot = (((cacheRoot as NSString)
                .appendingPathComponent(parsed.marketplace) as NSString)
                .appendingPathComponent(parsed.name))
            guard let versions = try? fm.contentsOfDirectory(atPath: pluginCacheRoot) else { continue }
            for version in versions.sorted() {
                let installPath = (pluginCacheRoot as NSString).appendingPathComponent(version)
                let manifestPath = (installPath as NSString).appendingPathComponent(".codex-plugin/plugin.json")
                guard fm.fileExists(atPath: manifestPath) else { continue }
                installs.append(CodexPluginInstall(
                    id: pluginID,
                    installPath: installPath,
                    version: version,
                    enabled: pluginStates[pluginID] ?? true
                ))
            }
        }
        return installs
    }

    private func codexConfiguredPluginStates(_ content: String) -> [String: Bool] {
        var states: [String: Bool] = [:]
        var currentPluginID: String?

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let valuePart = tomlValuePart(trimmed)
            if valuePart.hasPrefix("[") && valuePart.hasSuffix("]") && !valuePart.hasPrefix("[[") {
                let section = String(valuePart.dropFirst().dropLast())
                let parts = splitTomlDottedKey(section)
                if parts.count == 2, parts[0] == "plugins", !parts[1].isEmpty {
                    currentPluginID = parts[1]
                    states[parts[1], default: true] = states[parts[1]] ?? true
                } else {
                    currentPluginID = nil
                }
                continue
            }

            guard let currentPluginID,
                  let eq = trimmed.range(of: " = ") ?? trimmed.range(of: "=") else { continue }
            let key = trimTomlQuotes(String(trimmed[..<eq.lowerBound]).trimmingCharacters(in: .whitespaces))
            guard key == "enabled" else { continue }
            let rawValue = String(trimmed[eq.upperBound...]).trimmingCharacters(in: .whitespaces)
            if let enabled = parseTomlScalarValue(rawValue) as? Bool {
                states[currentPluginID] = enabled
            }
        }

        return states
    }

    private func codexPluginIDParts(_ pluginID: String) -> (name: String, marketplace: String)? {
        guard let at = pluginID.lastIndex(of: "@") else { return nil }
        let name = String(pluginID[..<at])
        let marketplace = String(pluginID[pluginID.index(after: at)...])
        guard !name.isEmpty, !marketplace.isEmpty else { return nil }
        return (name, marketplace)
    }

    private func codexPluginMCPConfigPaths(installPath: String) -> [String] {
        let manifestPath = (installPath as NSString).appendingPathComponent(".codex-plugin/plugin.json")
        guard let root = readJSONFile(manifestPath),
              let rawPaths = root["mcpServers"] else { return [] }
        return stringArrayOrSingle(rawPaths)
            .filter { $0.hasPrefix("./") }
            .map { (installPath as NSString).appendingPathComponent(String($0.dropFirst(2))) }
            .filter { path in
                let canonicalInstall = canonicalFilePath(installPath)
                let canonicalPath = canonicalFilePath(path)
                return canonicalPath == canonicalInstall || canonicalPath.hasPrefix(canonicalInstall + "/")
            }
    }

    private func readCodexPluginMCPServers(
        path: String,
        policyConfigPath: String,
        activeProfile: String?,
        plugin: CodexPluginInstall,
        disabledNames: Set<String>
    ) -> [ServerEntry] {
        guard let root = readJSONFile(path),
              let servers = codexPluginServerMap(root) else { return [] }

        let pluginRoot = codexPluginRootForMCPConfig(path)
        let resolved = resolveCodexPluginMCPConfig(servers, pluginRoot: pluginRoot) as? [String: Any] ?? servers
        let reason = "Bundled by Codex plugin \(plugin.id). This inventory row is read-only because it points into installed plugin files; manage enablement from Codex plugin policy or reinstall/update the plugin."

        return parseServerDict(resolved, isDisabled: false).map { server in
            ServerEntry(
                name: server.name,
                transport: server.transport,
                command: server.command,
                args: server.args,
                cwd: server.cwd,
                url: server.url,
                env: server.env,
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
                sourcePath: path,
                sourceLabel: "Codex plugin: \(plugin.id)",
                isReadOnly: true,
                readOnlyReason: reason,
                codexPluginID: plugin.id,
                codexPluginPolicyConfigPath: policyConfigPath,
                codexPluginPolicyProfileName: activeProfile,
                codexPluginEnabled: plugin.enabled,
                isDisabled: plugin.enabled == false || disabledNames.contains(server.name)
            )
        }
    }

    private func codexPluginServerMap(_ root: [String: Any]) -> [String: Any]? {
        if let wrapped = root["mcpServers"] as? [String: Any] { return wrapped }
        if let wrapped = root["mcp_servers"] as? [String: Any] { return wrapped }
        let reserved = Set(["name", "version", "description", "skills", "apps", "mcpServers", "mcp_servers"])
        let serverLike = root.filter { key, value in
            !reserved.contains(key) && value is [String: Any]
        }
        return serverLike.isEmpty ? nil : serverLike
    }

    private func codexPluginRootForMCPConfig(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.deletingLastPathComponent().path
    }

    private func resolveCodexPluginMCPConfig(_ value: Any, pluginRoot: String) -> Any {
        if let string = value as? String {
            if string == "." { return pluginRoot }
            if string.hasPrefix("./") {
                return URL(fileURLWithPath: pluginRoot)
                    .appendingPathComponent(String(string.dropFirst(2)))
                    .path
            }
            return string.replacingOccurrences(of: "${CODEX_PLUGIN_ROOT}", with: pluginRoot)
        }
        if let array = value as? [Any] {
            return array.map { resolveCodexPluginMCPConfig($0, pluginRoot: pluginRoot) }
        }
        if let dict = value as? [String: Any] {
            return dict.mapValues { resolveCodexPluginMCPConfig($0, pluginRoot: pluginRoot) }
        }
        return value
    }

    private func codexPluginDisabledMCPServers(pluginID: String, config: String) -> Set<String> {
        var serverStates: [String: Bool] = [:]
        var profileServerStates: [String: Bool] = [:]
        var currentServer: String?
        let activeProfile = codexActiveProfile(config)
        var currentProfileServer: String?

        for line in config.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let valuePart = tomlValuePart(trimmed)
            if valuePart.hasPrefix("[") && valuePart.hasSuffix("]") && !valuePart.hasPrefix("[[") {
                let section = String(valuePart.dropFirst().dropLast())
                let parts = splitTomlDottedKey(section)
                if parts.count == 4,
                   parts[0] == "plugins",
                   parts[1] == pluginID,
                   parts[2] == "mcp_servers",
                   !parts[3].isEmpty {
                    currentServer = parts[3]
                    currentProfileServer = nil
                } else if let activeProfile,
                          parts.count == 6,
                          parts[0] == "profiles",
                          parts[1] == activeProfile,
                          parts[2] == "plugins",
                          parts[3] == pluginID,
                          parts[4] == "mcp_servers",
                          !parts[5].isEmpty {
                    currentServer = nil
                    currentProfileServer = parts[5]
                } else {
                    currentServer = nil
                    currentProfileServer = nil
                }
                continue
            }

            guard let eq = trimmed.range(of: " = ") ?? trimmed.range(of: "=") else { continue }
            let key = trimTomlQuotes(String(trimmed[..<eq.lowerBound]).trimmingCharacters(in: .whitespaces))
            guard key == "enabled" else { continue }
            let rawValue = String(trimmed[eq.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard let enabled = parseTomlScalarValue(rawValue) as? Bool else { continue }
            if let currentServer {
                serverStates[currentServer] = enabled
            } else if let currentProfileServer {
                profileServerStates[currentProfileServer] = enabled
            }
        }

        for (name, enabled) in profileServerStates {
            serverStates[name] = enabled
        }
        return Set(serverStates.filter { $0.value == false }.map(\.key))
    }

    private func codexActiveProfile(_ config: String) -> String? {
        var currentSection: String?
        for line in config.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let valuePart = tomlValuePart(trimmed)
            if valuePart.hasPrefix("[") && valuePart.hasSuffix("]") && !valuePart.hasPrefix("[[") {
                currentSection = String(valuePart.dropFirst().dropLast())
                continue
            }
            guard currentSection == nil,
                  let eq = trimmed.range(of: " = ") ?? trimmed.range(of: "=") else { continue }
            let key = trimTomlQuotes(String(trimmed[..<eq.lowerBound]).trimmingCharacters(in: .whitespaces))
            guard key == "profile" else { continue }
            let rawValue = String(trimmed[eq.upperBound...]).trimmingCharacters(in: .whitespaces)
            if let profile = parseTomlScalarValue(rawValue) as? String,
               !profile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return profile
            }
        }
        return nil
    }

    private func readJSONFile(_ path: String) -> [String: Any]? {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8),
              let data = stripJsonComments(raw).data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func stringArrayOrSingle(_ value: Any) -> [String] {
        if let string = value as? String { return [string] }
        if let array = value as? [String] { return array }
        if let array = value as? [Any] {
            return array.compactMap { $0 as? String }
        }
        return []
    }

    private func stringArray(_ value: Any?) -> [String] {
        guard let value else { return [] }
        return stringArrayOrSingle(value)
    }

    private func toolApprovalModes(from props: [String: Any]) -> [String: String] {
        var modes: [String: String] = [:]
        if let tools = props["tools"] as? [String: Any] {
            for (tool, raw) in tools {
                if let dict = raw as? [String: Any],
                   let mode = dict["approval_mode"] as? String ?? dict["approvalMode"] as? String {
                    modes[tool] = mode
                }
            }
        }
        for (key, raw) in props where key.hasPrefix("tools.") {
            let parts = key.split(separator: ".").map(String.init)
            if parts.count == 2,
               let dict = raw as? [String: Any],
               let mode = dict["approval_mode"] as? String ?? dict["approvalMode"] as? String {
                modes[parts[1]] = mode
            } else if parts.count >= 3,
                      parts.last == "approval_mode" || parts.last == "approvalMode",
                      let mode = raw as? String {
                modes[parts.dropFirst().dropLast().joined(separator: ".")] = mode
            }
        }
        if let flat = props["toolApprovalModes"] as? [String: String] {
            modes.merge(flat) { _, new in new }
        }
        return modes.filter { !$0.key.isEmpty && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func canonicalFilePath(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL
            .path
    }

    private func parseTomlMcpServers(_ content: String) -> [ServerEntry] {
        var servers: [String: [String: Any]] = [:]
        var currentName: String?
        var currentNested: String?

        func makeServer(name: String, props: [String: Any]) -> ServerEntry {
            let launch = launchMetadata(from: props)
            let command = launch.command
            let args = launch.args
            let cwd = props["cwd"] as? String ?? props["workingDirectory"] as? String ?? props["working_directory"] as? String
            let url = props["url"] as? String
            var env = props["env"] as? [String: String] ?? [:]
            env.merge(launch.env) { current, _ in current }
            let envVars = codexLocalEnvVars(props["env_vars"])
            let envFile = props["envFile"] as? String ?? props["env_file"] as? String ?? launch.envFile
            var headers = props["headers"] as? [String: String] ?? [:]
            headers.merge(props["http_headers"] as? [String: String] ?? [:]) { _, new in new }
            if let envHeaders = props["env_http_headers"] as? [String: String] {
                for (header, envName) in envHeaders {
                    headers[header] = "${\(envName)}"
                }
            }
            let bearerTokenEnvVar = props["bearer_token_env_var"] as? String
            let transport: String
            if let t = props["type"] as? String { transport = t }
            else if url != nil { transport = "http" }
            else { transport = "stdio" }
            let enabled = props["enabled"]
            let isDisabled = (enabled as? Bool) == false || (enabled as? String) == "false" || boolValue(props["disabled"]) == true
            return ServerEntry(
                name: name,
                transport: transport,
                command: command,
                args: args,
                cwd: cwd,
                url: url,
                env: env,
                headers: headers,
                bearerTokenEnvVar: bearerTokenEnvVar,
                envVars: envVars,
                envFile: envFile,
                sandboxEnabled: boolValue(props["sandboxEnabled"] ?? props["sandbox_enabled"]),
                sandboxSummary: configSummary(props["sandbox"]),
                devSummary: configSummary(props["dev"]),
                enabledTools: stringArray(props["enabledTools"] ?? props["enabled_tools"]),
                alwaysAllowTools: stringArray(props["alwaysAllow"] ?? props["always_allow"]),
                disabledTools: stringArray(props["disabledTools"] ?? props["disabled_tools"]),
                defaultToolApprovalMode: props["defaultToolApprovalMode"] as? String ?? props["default_tools_approval_mode"] as? String,
                toolApprovalModes: toolApprovalModes(from: props),
                watchPaths: stringArray(props["watchPaths"] ?? props["watch_paths"]),
                serverTimeoutSeconds: codexNumber(props["timeout"]),
                startupTimeoutSeconds: codexStartupTimeoutSeconds(from: props),
                toolTimeoutSeconds: codexNumber(props["tool_timeout_sec"]),
                isDisabled: isDisabled
            )
        }

        let lines = content.components(separatedBy: .newlines)
        var index = 0
        while index < lines.count {
            let line = lines[index]
            index += 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let sectionLine = tomlValuePart(trimmed)

            if sectionLine.hasPrefix("[") && sectionLine.hasSuffix("]") && !sectionLine.hasPrefix("[[") {
                let section = String(sectionLine.dropFirst().dropLast())
                if let parsed = parseCodexMCPServerSection(section) {
                    currentName = parsed.name
                    currentNested = parsed.nested
                    if servers[parsed.name] == nil { servers[parsed.name] = [:] }
                } else {
                    currentName = nil
                    currentNested = nil
                }
                continue
            }

            guard let currentName else { continue }
            guard let eqRange = trimmed.range(of: " = ") ?? trimmed.range(of: "=") else { continue }
            let key    = String(trimmed[trimmed.startIndex..<eqRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            var rawVal = String(trimmed[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            while tomlValueStartsCollection(rawVal), !tomlCollectionIsComplete(rawVal), index < lines.count {
                rawVal += "\n" + lines[index].trimmingCharacters(in: .whitespaces)
                index += 1
            }
            let keyParts = splitTomlDottedKey(key)
            let normalizedKey = keyParts.joined(separator: ".")
            let value = normalizedKey == "env_vars" ? parseCodexEnvVars(rawVal) : parseTomlScalarValue(rawVal)

            if let currentNested, ["env", "headers", "http_headers", "env_http_headers"].contains(currentNested) {
                let stringValue = "\(value)"
                var nested = servers[currentName]?[currentNested] as? [String: String] ?? [:]
                nested[normalizedKey] = stringValue
                servers[currentName]?[currentNested] = nested
            } else if let currentNested {
                var nested = servers[currentName]?[currentNested] as? [String: Any] ?? [:]
                nested[normalizedKey] = value
                servers[currentName]?[currentNested] = nested
            } else if keyParts.count >= 2,
                      ["env", "headers", "http_headers", "env_http_headers"].contains(keyParts[0]) {
                let nestedName = keyParts[0]
                let nestedKey = keyParts.dropFirst().joined(separator: ".")
                var nested = servers[currentName]?[nestedName] as? [String: String] ?? [:]
                nested[nestedKey] = "\(value)"
                servers[currentName]?[nestedName] = nested
            } else {
                servers[currentName]?[normalizedKey] = value
            }
        }

        return servers
            .map { name, props in makeServer(name: name, props: props) }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    // MARK: - YAML (Continue: mcpServers array)

    private func readYamlServers(path: String) -> [ServerEntry] {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        return parseYamlMcpServers(raw)
    }

    private func parseYamlMcpServers(_ content: String) -> [ServerEntry] {
        var servers: [ServerEntry] = []
        var inBlock  = false
        var inItem   = false
        var props: [String: Any] = [:]

        func flush() {
            guard inItem, let name = props["name"] as? String else { return }
            let command   = props["command"] as? String
            let args      = props["args"] as? [String] ?? []
            let url       = props["url"] as? String
            let transport = url != nil ? "http" : "stdio"
            servers.append(ServerEntry(name: name, transport: transport, command: command, args: args, url: url, env: [:], headers: [:], bearerTokenEnvVar: nil))
            props = [:]; inItem = false
        }

        for line in content.components(separatedBy: .newlines) {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }

            if line == "mcpServers:" || line.hasPrefix("mcpServers:") {
                inBlock = true; continue
            }

            guard inBlock else { continue }

            // Left the block (no leading whitespace)
            if !line.hasPrefix(" ") && !line.hasPrefix("\t") {
                flush(); break
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("- ") {
                flush()
                inItem = true
                let rest = String(trimmed.dropFirst(2))
                parseYamlKeyVal(rest, into: &props)
            } else if inItem {
                parseYamlKeyVal(trimmed, into: &props)
            }
        }

        flush()
        return servers.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private func codexStartupTimeoutSeconds(from props: [String: Any]) -> TimeInterval? {
        if let seconds = codexNumber(props["startup_timeout_sec"]) {
            return seconds
        }
        if let milliseconds = codexNumber(props["startup_timeout_ms"]) {
            return milliseconds / 1_000
        }
        return nil
    }

    private func codexNumber(_ value: Any?) -> TimeInterval? {
        if let double = value as? Double, double > 0 { return double }
        if let int = value as? Int, int > 0 { return TimeInterval(int) }
        if let string = value as? String {
            let normalized = string
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "_", with: "")
            if let double = Double(normalized), double > 0 {
                return double
            }
        }
        return nil
    }

    private func parseYamlKeyVal(_ s: String, into props: inout [String: Any]) {
        guard let colonRange = s.range(of: ": ") else { return }
        let key    = String(s[s.startIndex..<colonRange.lowerBound])
        let rawVal = String(s[colonRange.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        if rawVal.hasPrefix("[") {
            let inner = rawVal.dropFirst().dropLast()
            let items = inner.components(separatedBy: ",").map {
                $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }.filter { !$0.isEmpty }
            props[key] = items
        } else {
            props[key] = rawVal
        }
    }

    private func parseTomlInlineTable(_ raw: String) -> [String: String] {
        let trimmed = tomlValuePart(raw)
        guard trimmed.hasPrefix("{"), trimmed.hasSuffix("}") else { return [:] }
        let inner = trimmed.dropFirst().dropLast()
        var out: [String: String] = [:]
        for pair in splitTomlArray(String(inner)) {
            guard let eq = pair.firstIndex(of: "=") else { continue }
            let key = pair[..<eq]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            let rawValue = String(pair[pair.index(after: eq)...])
            let value = "\(parseTomlScalarValue(rawValue))"
            if !key.isEmpty { out[key] = value }
        }
        return out
    }

    private func parseTomlScalarValue(_ raw: String) -> Any {
        let value = tomlValuePart(raw)
        if value == "true" { return true }
        if value == "false" { return false }
        if let int = Int(value.replacingOccurrences(of: "_", with: "")) { return int }
        if let double = Double(value.replacingOccurrences(of: "_", with: "")) { return double }
        if value.hasPrefix("["), value.hasSuffix("]") {
            let inner = value.dropFirst().dropLast()
            return splitTomlArray(String(inner)).map {
                trimTomlQuotes($0.trimmingCharacters(in: .whitespaces))
            }.filter { !$0.isEmpty }
        }
        if value.hasPrefix("{"), value.hasSuffix("}") {
            return parseTomlInlineTable(value)
        }
        return trimTomlQuotes(value)
    }

    private func parseCodexEnvVars(_ raw: String) -> [[String: String]] {
        let value = tomlValuePart(raw)
        guard value.hasPrefix("["), value.hasSuffix("]") else { return [] }
        let inner = String(value.dropFirst().dropLast())
        return splitTomlArray(inner).compactMap { item in
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            if let name = tomlStringLiteral(trimmed) {
                return ["name": name, "source": "local"]
            }
            if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
                let table = parseTomlInlineTable(trimmed)
                guard table["name"]?.isEmpty == false else { return nil }
                return table
            }
            return nil
        }
    }

    private func tomlValuePart(_ raw: String) -> String {
        var inSingle = false
        var inDouble = false
        var escaped = false
        var inComment = false
        var out = ""

        for ch in raw {
            if inComment {
                if ch == "\n" {
                    inComment = false
                    out.append(ch)
                }
                continue
            }
            if escaped {
                out.append(ch)
                escaped = false
                continue
            }
            if inDouble && ch == "\\" {
                out.append(ch)
                escaped = true
                continue
            }
            if ch == "\"", !inSingle {
                inDouble.toggle()
                out.append(ch)
                continue
            }
            if ch == "'", !inDouble {
                inSingle.toggle()
                out.append(ch)
                continue
            }
            if ch == "#", !inSingle, !inDouble {
                inComment = true
                continue
            }
            out.append(ch)
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tomlValueStartsCollection(_ raw: String) -> Bool {
        let value = tomlValuePart(raw)
        return value.hasPrefix("[") || value.hasPrefix("{")
    }

    private func tomlCollectionIsComplete(_ raw: String) -> Bool {
        var inSingle = false
        var inDouble = false
        var escaped = false
        var bracketDepth = 0
        var braceDepth = 0

        for ch in tomlValuePart(raw) {
            if escaped {
                escaped = false
                continue
            }
            if inDouble && ch == "\\" {
                escaped = true
                continue
            }
            if ch == "\"", !inSingle {
                inDouble.toggle()
                continue
            }
            if ch == "'", !inDouble {
                inSingle.toggle()
                continue
            }
            guard !inSingle, !inDouble else { continue }
            if ch == "[" { bracketDepth += 1 }
            if ch == "]", bracketDepth > 0 { bracketDepth -= 1 }
            if ch == "{" { braceDepth += 1 }
            if ch == "}", braceDepth > 0 { braceDepth -= 1 }
        }

        return bracketDepth == 0 && braceDepth == 0 && !inSingle && !inDouble
    }

    private func codexLocalEnvVars(_ value: Any?) -> [String] {
        if let strings = value as? [String] { return strings }
        if let entries = value as? [[String: String]] {
            return entries.compactMap { entry in
                guard let name = entry["name"], !name.isEmpty else { return nil }
                let source = entry["source"] ?? "local"
                return source == "local" ? name : nil
            }
        }
        if let any = value as? [Any] {
            return any.compactMap { item in
                if let string = item as? String { return string }
                if let entry = item as? [String: String],
                   let name = entry["name"],
                   (entry["source"] ?? "local") == "local" {
                    return name
                }
                if let entry = item as? [String: Any],
                   let name = entry["name"] as? String,
                   (entry["source"] as? String ?? "local") == "local" {
                    return name
                }
                return nil
            }
        }
        return []
    }

    private func splitTomlArray(_ text: String) -> [String] {
        var items: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escaped = false
        var braceDepth = 0
        var bracketDepth = 0

        for ch in text {
            if escaped {
                current.append(ch)
                escaped = false
                continue
            }
            if inDouble && ch == "\\" {
                escaped = true
                current.append(ch)
                continue
            }
            if ch == "'", !inDouble { inSingle.toggle(); current.append(ch); continue }
            if ch == "\"", !inSingle { inDouble.toggle(); current.append(ch); continue }
            if !inSingle, !inDouble {
                if ch == "{" { braceDepth += 1 }
                if ch == "}", braceDepth > 0 { braceDepth -= 1 }
                if ch == "[" { bracketDepth += 1 }
                if ch == "]", bracketDepth > 0 { bracketDepth -= 1 }
                if ch == ",", braceDepth == 0, bracketDepth == 0 {
                    items.append(current)
                    current = ""
                    continue
                }
            }
            current.append(ch)
        }

        if !current.isEmpty { items.append(current) }
        return items
    }

    private func tomlStringLiteral(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2,
              (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\""))
                || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) else { return nil }
        return String(trimmed.dropFirst().dropLast())
    }

    private func parseCodexMCPServerSection(_ section: String) -> (name: String, nested: String?)? {
        let parts = splitTomlDottedKey(section)
        guard parts.count >= 2,
              parts[0] == "mcp_servers",
              !parts[1].isEmpty else { return nil }
        let nested = parts.count > 2 ? parts.dropFirst(2).joined(separator: ".") : nil
        return (parts[1], nested)
    }

    private func splitTomlDottedKey(_ value: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escaped = false

        for ch in value {
            if escaped {
                current.append(ch)
                escaped = false
                continue
            }
            if inDouble && ch == "\\" {
                escaped = true
                current.append(ch)
                continue
            }
            if ch == "\"", !inSingle {
                inDouble.toggle()
                continue
            }
            if ch == "'", !inDouble {
                inSingle.toggle()
                continue
            }
            if ch == ".", !inSingle, !inDouble {
                parts.append(current)
                current = ""
                continue
            }
            current.append(ch)
        }

        parts.append(current)
        return parts.map { trimTomlQuotes($0.trimmingCharacters(in: .whitespaces)) }
    }

    private func trimTomlQuotes(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 2,
           (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\""))
            || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    // MARK: - JSONC comment stripper

    private func stripJsonComments(_ src: String) -> String {
        var out = ""
        var i = src.startIndex
        var inString = false

        while i < src.endIndex {
            let ch = src[i]

            if ch == "\"" {
                let prev = i > src.startIndex ? src[src.index(before: i)] : Character("\0")
                if prev != "\\" { inString = !inString }
                out.append(ch); i = src.index(after: i); continue
            }

            if !inString {
                let next = src.index(after: i)
                if ch == "/" && next < src.endIndex {
                    if src[next] == "/" {
                        while i < src.endIndex && src[i] != "\n" { i = src.index(after: i) }
                        continue
                    }
                    if src[next] == "*" {
                        i = src.index(i, offsetBy: 2)
                        while i < src.endIndex {
                            if src[i] == "*" {
                                let n2 = src.index(after: i)
                                if n2 < src.endIndex && src[n2] == "/" { i = src.index(after: n2); break }
                            }
                            i = src.index(after: i)
                        }
                        continue
                    }
                }
            }

            out.append(ch); i = src.index(after: i)
        }
        return out
    }

    // MARK: - Detection helpers

    private func appExists(_ bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    private func onPath(_ cmd: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        p.arguments = [cmd]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError  = pipe
        try? p.run(); p.waitUntilExit()
        return p.terminationStatus == 0
    }
}
