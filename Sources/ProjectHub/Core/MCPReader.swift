import Foundation

// MARK: - MCP config reader (read-only)

enum MCPReader {

    struct ClaudeProjectMCPApprovalState {
        var enabled = Set<String>()
        var disabled = Set<String>()
        var approveAll = false
        var disabledSourcePaths: [String: Set<String>] = [:]

        func disabledSources(for serverName: String) -> [String] {
            disabledSourcePaths[serverName]?.sorted() ?? []
        }
    }

    /// Read all MCP servers for a project path across supported project config sources.
    static func servers(for projectPath: String) -> [MCPServerInfo] {
        var results: [MCPServerInfo] = []
        results += fromClaudeCode(projectPath)
        results += fromCodex(projectPath)
        results += fromCompatibilityInventory(projectPath)
        return dedupeServers(results)
    }

    // MARK: - Claude Code (.mcp.json)

    static func fromClaudeCode(_ projectPath: String) -> [MCPServerInfo] {
        let approval = claudeCodeProjectMCPApprovalState(projectPath: projectPath)
        let projectServers = fromProjectTool(
            "claude-code",
            source: .claudeCode,
            projectPath: projectPath,
            additionalDisabledNames: approval.disabled
        )
        return (projectServers + fromClaudeCodeLocalProjectState(projectPath))
            .sorted(by: sortServers)
    }

    static func fromClaudeCodeLocalProjectState(_ projectPath: String) -> [MCPServerInfo] {
        let path = claudeCodeJSONPath()
        guard let root = readJSONDictionary(at: path),
              let projectState = claudeProjectState(projectRoot: projectPath, root: root) else {
            return []
        }

        let disabledNames = Set(stringArray(projectState["disabledMcpServers"]))
        let active = mcpServerInfoRows(
            from: projectState["mcpServers"],
            source: .claudeCodeLocal,
            disabledNames: disabledNames,
            forceDisabled: false
        )
        let disabled = mcpServerInfoRows(
            from: projectState["mcpServers_disabled"],
            source: .claudeCodeLocal,
            disabledNames: disabledNames,
            forceDisabled: true
        ).filter { disabledRow in
            !active.contains { $0.name == disabledRow.name }
        }

        return (active + disabled)
            .sorted(by: sortServers)
    }

    // MARK: - Cursor (.cursor/mcp.json)

    static func fromCursor(_ projectPath: String) -> [MCPServerInfo] {
        fromProjectTool("cursor", source: .cursor, projectPath: projectPath)
    }

    // MARK: - VS Code (.vscode/mcp.json)

    static func fromVSCode(_ projectPath: String) -> [MCPServerInfo] {
        fromProjectTool("vscode", source: .vscode, projectPath: projectPath)
    }

    // MARK: - Roo (.roo/mcp.json)

    static func fromRoo(_ projectPath: String) -> [MCPServerInfo] {
        fromProjectTool("roo", source: .roo, projectPath: projectPath)
    }

    // MARK: - Codex (.codex/config.toml)

    static func fromCodex(_ projectPath: String) -> [MCPServerInfo] {
        fromProjectTool("codex", source: .codex, projectPath: projectPath)
    }

    // MARK: - Helpers

    private static func fromProjectTool(
        _ toolID: String,
        source: MCPConfigSource,
        projectPath: String,
        additionalDisabledNames: Set<String> = []
    ) -> [MCPServerInfo] {
        ConfigWriter.readAllServerEntries(toolID: toolID, scope: .project, projectRoot: projectPath)
            .map { entry in
                MCPServerInfo(
                    source: source,
                    name: entry.name,
                    detail: entry.detail,
                    isDisabled: entry.isDisabled || additionalDisabledNames.contains(entry.name),
                    sourcePath: nil
                )
            }
            .sorted(by: sortServers)
    }

    private static func fromCompatibilityInventory(_ projectPath: String) -> [MCPServerInfo] {
        CompatibilityScanner.mcpInventory(projectRoot: projectPath)
            .filter { row in
                row.scope == .project || row.scope == .localProjectUser
            }
            .compactMap { row in
                guard let source = mcpSource(for: row) else { return nil }
                return MCPServerInfo(
                    source: source,
                    name: row.server.name,
                    detail: row.server.detail,
                    isDisabled: row.server.isDisabled,
                    sourcePath: row.server.sourcePath
                )
            }
            .sorted(by: sortServers)
    }

    private static func mcpSource(for row: CompatibilityMCPInventoryRow) -> MCPConfigSource? {
        switch row.toolID {
        case .claudeCode:
            return row.scope == .localProjectUser ? .claudeCodeLocal : .claudeCode
        case .codexCLI, .codexDesktop:
            return .codex
        case .claudeDesktop:
            return nil
        }
    }

    private static func dedupeServers(_ servers: [MCPServerInfo]) -> [MCPServerInfo] {
        var seen = Set<String>()
        var output: [MCPServerInfo] = []
        for server in servers {
            let key = [
                server.source.rawValue,
                server.name,
                server.detail,
                server.isDisabled ? "disabled" : "enabled"
            ].joined(separator: "\u{1e}")
            guard seen.insert(key).inserted else { continue }
            output.append(server)
        }
        return output.sorted(by: sortServers)
    }

    private static func sortServers(_ lhs: MCPServerInfo, _ rhs: MCPServerInfo) -> Bool {
        let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
        if lhs.source.rawValue != rhs.source.rawValue { return lhs.source.rawValue < rhs.source.rawValue }
        return (lhs.sourcePath ?? "").localizedCaseInsensitiveCompare(rhs.sourcePath ?? "") == .orderedAscending
    }

    private static func mcpServerInfoRows(
        from value: Any?,
        source: MCPConfigSource,
        disabledNames: Set<String>,
        forceDisabled: Bool
    ) -> [MCPServerInfo] {
        guard let dict = value as? [String: Any] else { return [] }
        return dict.compactMap { name, value in
            guard let config = value as? [String: Any] else { return nil }
            return MCPServerInfo(
                source: source,
                name: name,
                detail: serverDetail(config),
                isDisabled: forceDisabled || disabledNames.contains(name),
                sourcePath: nil
            )
        }
    }

    private static func serverDetail(_ config: [String: Any]) -> String {
        if let url = config["url"] as? String, !url.isEmpty {
            return url
        }
        let launch = launchCommand(from: config)
        return ([launch.command] + launch.args.map { Optional($0) })
            .compactMap { $0 }
            .joined(separator: " ")
    }

    private static func launchCommand(from config: [String: Any]) -> (command: String?, args: [String]) {
        MCPLaunchNormalizer.launch(command: config["command"], args: stringArray(config["args"]))
    }

    static func disabledClaudeCodeServerNames(projectPath: String) -> Set<String> {
        claudeCodeProjectMCPApprovalState(projectPath: projectPath).disabled
    }

    static func claudeCodeProjectMCPApprovalState(projectPath: String) -> ClaudeProjectMCPApprovalState {
        var state = ClaudeProjectMCPApprovalState()
        let jsonPath = (projectPath as NSString).appendingPathComponent(".mcp.json")
        if let root = readJSONDictionary(at: jsonPath) {
            recordDisabled(Array((root["mcpServers_disabled"] as? [String: Any] ?? [:]).keys), sourcePath: jsonPath, in: &state)
            recordApproval(root, sourcePath: jsonPath, in: &state)
        }

        for path in claudeCodeProjectMCPApprovalSettingPaths(projectPath: projectPath) {
            guard let root = readJSONDictionary(at: path) else { continue }
            recordApproval(root, sourcePath: path, in: &state)
        }

        if let root = readJSONDictionary(at: claudeCodeJSONPath()),
           let projectState = claudeProjectState(projectRoot: projectPath, root: root) {
            recordApproval(projectState, sourcePath: claudeCodeJSONPath(), in: &state)
        }

        return state
    }

    private static func claudeCodeProjectMCPApprovalSettingPaths(projectPath: String) -> [String] {
        let claudeHome = claudeHomeDirectory()
        var paths = [
            "\(claudeHome)/settings.json",
            "\(projectPath)/.claude/settings.json",
            "\(projectPath)/.claude/settings.local.json"
        ]

        for baseDir in claudeCodeManagedDirectories() {
            paths.append((baseDir as NSString).appendingPathComponent("managed-settings.json"))
            let dropInDir = (baseDir as NSString).appendingPathComponent("managed-settings.d")
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dropInDir) else { continue }
            paths += entries
                .filter { !$0.hasPrefix(".") && $0.lowercased().hasSuffix(".json") }
                .sorted()
                .map { (dropInDir as NSString).appendingPathComponent($0) }
        }
        return uniqueStringsPreservingOrder(paths)
    }

    private static func recordApproval(_ root: [String: Any], sourcePath: String, in state: inout ClaudeProjectMCPApprovalState) {
        state.enabled.formUnion(stringArray(root["enabledMcpjsonServers"]))
        let disabled = stringArray(root["disabledMcpjsonServers"])
        recordDisabled(disabled, sourcePath: sourcePath, in: &state)
        if boolSetting(root["enableAllProjectMcpServers"]) == true {
            state.approveAll = true
        }
    }

    private static func recordDisabled(_ names: [String], sourcePath: String, in state: inout ClaudeProjectMCPApprovalState) {
        for name in names {
            state.disabled.insert(name)
            state.disabledSourcePaths[name, default: []].insert(sourcePath)
        }
    }

    private static func readJSONDictionary(at path: String) -> [String: Any]? {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8),
              let data = ConfigWriter.stripJsonComments(raw).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    private static func stringArray(_ value: Any?) -> [String] {
        if let strings = value as? [String] { return strings }
        if let any = value as? [Any] {
            return any.compactMap { $0 as? String }
        }
        return []
    }

    private static func boolSetting(_ value: Any?) -> Bool? {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String {
            switch string.lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        return nil
    }

    private static func claudeHomeDirectory(home: String = NSHomeDirectory()) -> String {
        if let override = ProcessInfo.processInfo.environment["PROJECTHUB_CLAUDE_HOME"],
           !override.isEmpty {
            return override
        }
        if let configDir = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"],
           !configDir.isEmpty {
            return (configDir as NSString).expandingTildeInPath
        }
        return "\(home)/.claude"
    }

    private static func claudeCodeJSONPath(home: String = NSHomeDirectory()) -> String {
        if let override = ProcessInfo.processInfo.environment["PROJECTHUB_CLAUDE_JSON_PATH"],
           !override.isEmpty {
            return override
        }
        return "\(home)/.claude.json"
    }

    private static func claudeCodeManagedDirectories() -> [String] {
        if let override = ProcessInfo.processInfo.environment["PROJECTHUB_CLAUDE_CODE_MANAGED_DIR"],
           !override.isEmpty {
            return [override]
        }
        return [
            "/Library/Application Support/ClaudeCode",
            "/etc/claude-code"
        ]
    }

    private static func claudeProjectState(projectRoot: String, root: [String: Any]) -> [String: Any]? {
        guard let projects = root["projects"] as? [String: Any] else { return nil }
        if let projectState = projects[projectRoot] as? [String: Any] {
            return projectState
        }
        let canonicalRoot = canonicalFilePath(projectRoot)
        if let canonicalMatch = projects.first(where: { key, _ in
            canonicalFilePath(key) == canonicalRoot
        })?.value as? [String: Any] {
            return canonicalMatch
        }
        let foldedRoot = canonicalRoot.lowercased()
        return projects.first { key, _ in
            canonicalFilePath(key).lowercased() == foldedRoot
        }?.value as? [String: Any]
    }

    private static func canonicalFilePath(_ path: String) -> String {
        URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
    }

    private static func uniqueStringsPreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

}
