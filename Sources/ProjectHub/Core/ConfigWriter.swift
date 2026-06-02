import Foundation

// MARK: - Writes server configs into the right file for each tool.
// Supports JSON-based tools natively. TOML (Codex) + YAML (Continue) are
// reported as "unsupported — use CLI" so the user isn't silently dropped.

enum ConfigKind {
    case json(key: String)                  // { mcpServers: { ... } }   or servers
    case jsonNested(keys: [String])         // { ..., context_servers: {...} }
    case toml(key: String)                   // [<key>.name] sections
    case yaml                                // mcpServers: array
}

struct ToolSpec {
    let id:   String
    let path: String
    let kind: ConfigKind
}

/// Scope for a tool config. User = global (home directory); Project = per-project
/// file inside a picked folder. Not every tool has a project scope — those
/// return nil from `spec(for:scope:projectRoot:)` when scope is .project.
enum ConfigScope: String {
    case user
    case project
}

enum ToolSpecs {
    /// Default: user scope (what the existing call sites get).
    static func spec(for toolID: String) -> ToolSpec? {
        spec(for: toolID, scope: .user, projectRoot: nil)
    }

    /// Project-scope variants are currently defined only for tools that
    /// officially support a per-project MCP config file.
    static func spec(for toolID: String, scope: ConfigScope, projectRoot: String?) -> ToolSpec? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let codexHome = ProjectHubPaths.codexHome(home: home)
        let claudeCodeJSONPath = ProcessInfo.processInfo.environment["PROJECTHUB_CLAUDE_JSON_PATH"]
            .flatMap { $0.isEmpty ? nil : ($0 as NSString).expandingTildeInPath }
            ?? "\(home)/.claude.json"
        let claudeDesktopSupportDirectory = ProcessInfo.processInfo.environment["PROJECTHUB_CLAUDE_DESKTOP_SUPPORT_DIR"]
            .flatMap { $0.isEmpty ? nil : ($0 as NSString).expandingTildeInPath }
            ?? "\(home)/Library/Application Support/Claude"

        // Project-scoped specs (only a subset of tools support this).
        if scope == .project {
            guard let root = projectRoot else { return nil }
            switch toolID {
            case "cursor":
                return .init(id: toolID,
                             path: "\(root)/.cursor/mcp.json",
                             kind: .json(key: "mcpServers"))
            case "vscode":
                return .init(id: toolID,
                             path: "\(root)/.vscode/mcp.json",
                             kind: .json(key: "servers"))
            case "roo":
                return .init(id: toolID,
                             path: "\(root)/.roo/mcp.json",
                             kind: .json(key: "mcpServers"))
            case "claude-code":
                // Claude Code respects .mcp.json in the project root.
                return .init(id: toolID,
                             path: "\(root)/.mcp.json",
                             kind: .json(key: "mcpServers"))
            case "codex":
                return .init(id: toolID,
                             path: "\(root)/.codex/config.toml",
                             kind: .toml(key: "mcp_servers"))
            default:
                return nil
            }
        }

        // User scope (default path for every tool).
        switch toolID {
        case "claude-desktop":
            return .init(id: toolID,
                         path: "\(claudeDesktopSupportDirectory)/claude_desktop_config.json",
                         kind: .json(key: "mcpServers"))
        case "claude-code":
            return .init(id: toolID,
                         path: claudeCodeJSONPath,
                         kind: .json(key: "mcpServers"))
        case "cursor":
            return .init(id: toolID,
                         path: "\(home)/.cursor/mcp.json",
                         kind: .json(key: "mcpServers"))
        case "vscode":
            return .init(id: toolID,
                         path: "\(home)/Library/Application Support/Code/User/mcp.json",
                         kind: .json(key: "servers"))
        case "windsurf":
            return .init(id: toolID,
                         path: "\(home)/.codeium/windsurf/mcp_config.json",
                         kind: .json(key: "mcpServers"))
        case "gemini":
            return .init(id: toolID,
                         path: "\(home)/.gemini/settings.json",
                         kind: .json(key: "mcpServers"))
        case "roo":
            return .init(id: toolID,
                         path: "\(home)/.roo/mcp_settings.json",
                         kind: .json(key: "mcpServers"))
        case "zed":
            return .init(id: toolID,
                         path: "\(home)/.config/zed/settings.json",
                         kind: .jsonNested(keys: ["context_servers"]))
        case "codex":
            return .init(id: toolID,
                         path: "\(codexHome)/config.toml",
                         kind: .toml(key: "mcp_servers"))
        case "continue":
            return .init(id: toolID,
                         path: "\(home)/.continue/config.yaml",
                         kind: .yaml)
        case "opencode":
            // opencode uses a slightly different per-server shape
            // ({ type: "local"|"remote", command: [...] }) than Claude Desktop.
            // ConfigWriter translates at I/O boundaries.
            return .init(id: toolID,
                         path: "\(home)/.config/opencode/opencode.json",
                         kind: .json(key: "mcp"))
        case "cline":
            return .init(id: toolID,
                         path: "\(home)/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json",
                         kind: .json(key: "mcpServers"))
        default:
            return nil
        }
    }

    /// Tool IDs that support project scope.
    static let projectScopedTools: Set<String> = ["claude-code", "codex"]
}

enum ConfigWriter {

    enum WriteError: Error, LocalizedError {
        case unsupportedFormat(String)
        case readFailure(String)
        case writeFailure(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let t): return "Format not supported by in-app import: \(t)"
            case .readFailure(let m):       return "Could not read existing config: \(m)"
            case .writeFailure(let m):      return "Could not write config: \(m)"
            }
        }
    }

    /// Returns true if the tool's config file format can be written natively.
    static func supportsNativeWrite(toolID: String) -> Bool {
        guard let spec = ToolSpecs.spec(for: toolID) else { return false }
        switch spec.kind {
        case .json, .jsonNested, .toml: return true
        case .yaml:                     return false
        }
    }

    /// Writes one server into the tool's config (user scope). Throws on failure.
    static func writeServer(
        toolID: String,
        name: String,
        config: [String: Any]
    ) throws {
        try writeServer(toolID: toolID, scope: .user, projectRoot: nil, name: name, config: config)
    }

    /// Scope-aware write. Use `scope: .project` with a `projectRoot` to land
    /// the server in `<projectRoot>/.cursor/mcp.json` (or equivalent).
    /// `config` is in claude-shape ({ command, args, env, ... } or { url, headers, ... }).
    /// We translate to opencode-shape at write time if the target is opencode.
    static func writeServer(
        toolID: String,
        scope: ConfigScope,
        projectRoot: String?,
        name: String,
        config: [String: Any]
    ) throws {
        if let blocker = nativeWriteBlocker(toolID: toolID, scope: scope, name: name, config: config) {
            throw WriteError.writeFailure(blocker)
        }
        guard let spec = ToolSpecs.spec(for: toolID, scope: scope, projectRoot: projectRoot) else {
            throw WriteError.unsupportedFormat(scope == .project ? "\(toolID) (project scope)" : toolID)
        }

        let shaped = shapeConfigForTarget(toolID: toolID, spec: spec, config: config)

        switch spec.kind {
        case .json(let key):
            try writeJson(path: spec.path, key: key, name: name, config: shaped)
        case .jsonNested(let keys):
            try writeJsonNested(path: spec.path, keys: keys, name: name, config: shaped)
        case .toml(let key):
            try writeToml(path: spec.path, tableKey: key, name: name, config: shaped)
        case .yaml:
            throw WriteError.unsupportedFormat(toolID)
        }
    }

    /// Returns the target file path we'd write to for a given tool + scope.
    /// Useful for the diff preview.
    static func previewPath(toolID: String, scope: ConfigScope, projectRoot: String?) -> String? {
        ToolSpecs.spec(for: toolID, scope: scope, projectRoot: projectRoot)?.path
    }

    /// Builds what the file contents WOULD be if we wrote this server now.
    /// Returns (beforeText, afterText). Used for diff preview.
    static func previewWrite(
        toolID: String,
        scope: ConfigScope,
        projectRoot: String?,
        name: String,
        config: [String: Any]
    ) -> (before: String, after: String)? {
        guard nativeWriteBlocker(toolID: toolID, scope: scope, name: name, config: config) == nil else { return nil }
        guard let spec = ToolSpecs.spec(for: toolID, scope: scope, projectRoot: projectRoot) else { return nil }

        // Before: what's currently on disk (raw).
        let before: String = {
            guard FileManager.default.fileExists(atPath: spec.path),
                  let raw = try? String(contentsOfFile: spec.path, encoding: .utf8)
            else { return "" }
            return raw
        }()

        let shaped = shapeConfigForTarget(toolID: toolID, spec: spec, config: config)

        // After: simulated root with the new server applied.
        var root: [String: Any]
        switch spec.kind {
        case .json(let key):
            guard var jsonRoot = loadJsonRootForPreview(path: spec.path) else { return nil }
            var dict = jsonRoot[key] as? [String: Any] ?? [:]
            dict[name] = shaped
            jsonRoot[key] = dict
            root = jsonRoot
        case .jsonNested(let keys):
            guard let jsonRoot = loadJsonRootForPreview(path: spec.path) else { return nil }
            var chain: [[String: Any]] = [jsonRoot]
            for k in keys {
                let current = chain.last!
                chain.append(current[k] as? [String: Any] ?? [:])
            }
            var innermost = chain.removeLast()
            innermost[name] = shaped
            var up = innermost
            for k in keys.reversed() {
                var parent = chain.removeLast()
                parent[k] = up
                up = parent
            }
            root = up
        case .toml(let key):
            let section = serverToTomlSection(tableKey: key, name: name, config: shaped)
            let after = upsertTomlSection(toml: before, tableKey: key, name: name, section: section)
            return (before, after)
        case .yaml:
            return (before, "(YAML preview not supported)")
        }

        let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted])
        let after = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return (before, after)
    }

    /// Builds a preview for a batch import into one target file. This mirrors
    /// sequential writes so multi-server previews show the final combined file.
    static func previewWriteBatch(
        toolID: String,
        scope: ConfigScope,
        projectRoot: String?,
        servers: [(name: String, config: [String: Any])]
    ) -> (before: String, after: String)? {
        guard servers.allSatisfy({ nativeWriteBlocker(toolID: toolID, scope: scope, name: $0.name, config: $0.config) == nil }) else { return nil }
        guard !servers.isEmpty,
              let spec = ToolSpecs.spec(for: toolID, scope: scope, projectRoot: projectRoot)
        else { return nil }

        let before = rawConfigText(path: spec.path)

        switch spec.kind {
        case .json(let key):
            guard var root = loadJsonRootForPreview(path: spec.path) else { return nil }
            var dict = root[key] as? [String: Any] ?? [:]
            for server in servers {
                dict[server.name] = shapeConfigForTarget(toolID: toolID, spec: spec, config: server.config)
            }
            root[key] = dict
            return (before, prettyJSON(root))

        case .jsonNested(let keys):
            guard var root = loadJsonRootForPreview(path: spec.path) else { return nil }
            for server in servers {
                let shaped = shapeConfigForTarget(toolID: toolID, spec: spec, config: server.config)
                var chain: [[String: Any]] = [root]
                for key in keys {
                    let current = chain.last!
                    chain.append(current[key] as? [String: Any] ?? [:])
                }
                var innermost = chain.removeLast()
                innermost[server.name] = shaped
                var up = innermost
                for key in keys.reversed() {
                    var parent = chain.removeLast()
                    parent[key] = up
                    up = parent
                }
                root = up
            }
            return (before, prettyJSON(root))

        case .toml(let key):
            var after = before
            for server in servers {
                let shaped = shapeConfigForTarget(toolID: toolID, spec: spec, config: server.config)
                let section = serverToTomlSection(tableKey: key, name: server.name, config: shaped)
                after = upsertTomlSection(toml: after, tableKey: key, name: server.name, section: section)
            }
            return (before, after)

        case .yaml:
            return nil
        }
    }

    static func previewWriteTextFileIfMissing(path: String, content: String) -> (before: String, after: String)? {
        guard !FileManager.default.fileExists(atPath: path) else { return nil }
        return ("", content)
    }

    static func writeTextFileIfMissing(path: String, content: String) throws {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: path) else {
            throw WriteError.writeFailure("Refusing to overwrite existing file: \(path)")
        }
        ensureParent(of: path)
        guard let data = content.data(using: .utf8) else {
            throw WriteError.writeFailure("Failed to encode file as UTF-8")
        }
        do {
            try data.write(to: URL(fileURLWithPath: path), options: [.atomic])
        } catch {
            throw WriteError.writeFailure(error.localizedDescription)
        }
    }

    static func previewWriteTextFileIfEmpty(path: String, content: String) -> (before: String, after: String)? {
        guard FileManager.default.fileExists(atPath: path),
              let existing = try? String(contentsOfFile: path, encoding: .utf8),
              existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              existing != content
        else { return nil }
        return (existing, content)
    }

    static func writeTextFileIfEmpty(path: String, content: String) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else {
            throw WriteError.writeFailure("Refusing to create missing file through empty-file writer: \(path)")
        }
        guard let existing = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw WriteError.readFailure("Could not read \(path)")
        }
        guard existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WriteError.writeFailure("Refusing to overwrite non-empty file: \(path)")
        }
        guard existing != content else { return }
        try tomlBackupAndWrite(path: path, existing: existing, updated: content)
    }

    static func previewMergeTextFile(
        path: String,
        expectedBefore: String,
        mergedContent: String
    ) -> (before: String, after: String)? {
        guard FileManager.default.fileExists(atPath: path),
              let existing = try? String(contentsOfFile: path, encoding: .utf8),
              existing == expectedBefore,
              existing != mergedContent
        else { return nil }
        return (existing, mergedContent)
    }

    static func mergeTextFile(
        path: String,
        expectedBefore: String,
        mergedContent: String
    ) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else {
            throw WriteError.writeFailure("Refusing to create missing file through merge writer: \(path)")
        }
        guard let existing = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw WriteError.readFailure("Could not read \(path)")
        }
        guard existing == expectedBefore else {
            throw WriteError.writeFailure("Refusing to overwrite file changed after preview: \(path)")
        }
        guard existing != mergedContent else { return }
        try tomlBackupAndWrite(path: path, existing: existing, updated: mergedContent)
    }

    static func previewRemoveServer(
        toolID: String,
        scope: ConfigScope,
        projectRoot: String?,
        name: String
    ) -> (before: String, after: String)? {
        guard let spec = ToolSpecs.spec(for: toolID, scope: scope, projectRoot: projectRoot) else { return nil }
        let before = rawConfigText(path: spec.path)

        switch spec.kind {
        case .json(let key):
            guard var root = loadJsonRootForPreview(path: spec.path) else { return nil }
            var active = root[key] as? [String: Any] ?? [:]
            active.removeValue(forKey: name)
            root[key] = active
            var disabled = root["\(key)_disabled"] as? [String: Any] ?? [:]
            disabled.removeValue(forKey: name)
            if disabled.isEmpty { root.removeValue(forKey: "\(key)_disabled") }
            else { root["\(key)_disabled"] = disabled }
            return (before, prettyJSON(root))
        case .jsonNested(let keys):
            guard var root = loadJsonRootForPreview(path: spec.path) else { return nil }
            var chain: [[String: Any]] = [root]
            for key in keys {
                let current = chain.last!
                chain.append(current[key] as? [String: Any] ?? [:])
            }
            var innermost = chain.removeLast()
            innermost.removeValue(forKey: name)
            var up = innermost
            for key in keys.reversed() {
                var parent = chain.removeLast()
                parent[key] = up
                up = parent
            }
            root = up
            return (before, prettyJSON(root))
        case .toml(let key):
            return (before, removeTomlSection(toml: before, tableKey: key, name: name))
        case .yaml:
            return nil
        }
    }

    static func previewSetServerEnabled(
        toolID: String,
        scope: ConfigScope,
        projectRoot: String?,
        name: String,
        enabled: Bool
    ) -> (before: String, after: String)? {
        guard let spec = ToolSpecs.spec(for: toolID, scope: scope, projectRoot: projectRoot) else { return nil }
        let before = rawConfigText(path: spec.path)

        switch spec.kind {
        case .json(let key):
            guard var root = loadJsonRootForPreview(path: spec.path) else { return nil }
            if toolID == "roo" {
                var active = root[key] as? [String: Any] ?? [:]
                guard var config = active[name] as? [String: Any] else { return nil }
                config["disabled"] = !enabled
                active[name] = config
                root[key] = active
                return (before, prettyJSON(root))
            }
            if enabled {
                var disabled = root["\(key)_disabled"] as? [String: Any] ?? [:]
                guard let config = disabled[name] else { return nil }
                disabled.removeValue(forKey: name)
                if disabled.isEmpty { root.removeValue(forKey: "\(key)_disabled") }
                else { root["\(key)_disabled"] = disabled }
                var active = root[key] as? [String: Any] ?? [:]
                active[name] = config
                root[key] = active
            } else {
                var active = root[key] as? [String: Any] ?? [:]
                guard let config = active[name] else { return nil }
                active.removeValue(forKey: name)
                root[key] = active
                var disabled = root["\(key)_disabled"] as? [String: Any] ?? [:]
                disabled[name] = config
                root["\(key)_disabled"] = disabled
            }
            return (before, prettyJSON(root))
        case .toml(let key):
            let result = updateTomlServerEnabledLine(
                toml: before,
                tableKey: key,
                name: name,
                enabled: enabled
            )
            guard result.found else { return nil }
            return (before, result.updated)
        case .jsonNested, .yaml:
            return nil
        }
    }

    static func claudeMCPApprovalConflictNames(path: String) -> [String] {
        let root = loadJsonRoot(path: path)
        let enabled = Set(stringArray(root["enabledMcpjsonServers"]))
        let disabled = Set(stringArray(root["disabledMcpjsonServers"]))
        return enabled.intersection(disabled).sorted()
    }

    static func previewResolveClaudeMCPApprovalConflict(
        path: String,
        serverNames: [String]
    ) -> (before: String, after: String)? {
        let names = Set(serverNames)
        guard !names.isEmpty else { return nil }
        let before = rawConfigText(path: path)
        var root = loadJsonRoot(path: path)
        let disabled = stringArray(root["disabledMcpjsonServers"])
        let filtered = disabled.filter { !names.contains($0) }
        guard filtered.count != disabled.count else { return nil }
        root["disabledMcpjsonServers"] = filtered
        return (before, prettyJSON(root))
    }

    static func resolveClaudeMCPApprovalConflict(
        path: String,
        serverNames: [String]
    ) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw WriteError.readFailure("Settings file not found at \(path)")
        }
        let names = Set(serverNames)
        guard !names.isEmpty else { return }
        var root = loadJsonRoot(path: path)
        let disabled = stringArray(root["disabledMcpjsonServers"])
        let filtered = disabled.filter { !names.contains($0) }
        guard filtered.count != disabled.count else { return }
        root["disabledMcpjsonServers"] = filtered
        try backupAndWrite(path: path, root: root)
    }

    /// Reads one server's full config from a tool's file, returned in claude-shape (user scope).
    /// Returns nil if the tool's format is unsupported or the server isn't there.
    static func readServer(toolID: String, name: String) -> [String: Any]? {
        readServer(toolID: toolID, scope: .user, projectRoot: nil, name: name)
    }

    /// Scope-aware single-server read.
    static func readServer(
        toolID: String,
        scope: ConfigScope,
        projectRoot: String?,
        name: String
    ) -> [String: Any]? {
        guard let spec = ToolSpecs.spec(for: toolID, scope: scope, projectRoot: projectRoot) else { return nil }
        return readServer(spec: spec, toolID: toolID, name: name)
    }

    private static func readServer(spec: ToolSpec, toolID: String, name: String) -> [String: Any]? {
        let raw: [String: Any]?

        switch spec.kind {
        case .json(let key):
            let root = loadJsonRoot(path: spec.path)
            let active = (root[key] as? [String: Any])?[name] as? [String: Any]
            let disabled = (root["\(key)_disabled"] as? [String: Any])?[name] as? [String: Any]
            raw = active ?? disabled

        case .jsonNested(let keys):
            var cursor: [String: Any] = loadJsonRoot(path: spec.path)
            for k in keys {
                cursor = (cursor[k] as? [String: Any]) ?? [:]
            }
            raw = cursor[name] as? [String: Any]

        case .toml(let key):
            let all = parseTomlSections(
                (try? String(contentsOfFile: spec.path, encoding: .utf8)) ?? "",
                tableKey: key)
            raw = all[name]

        case .yaml:
            return nil
        }

        guard var entry = raw else { return nil }

        if toolID == "opencode" {
            entry = opencodeShapeToClaude(entry)
        }
        return entry
    }

    /// Reads every server declared in a tool's config file at the given scope.
    /// Returns a `[name: config]` dictionary, with each config in claude-shape.
    /// Empty dict if the file doesn't exist or the tool's format is unsupported.
    static func readAllServers(
        toolID: String,
        scope: ConfigScope,
        projectRoot: String?
    ) -> [String: [String: Any]] {
        guard let spec = ToolSpecs.spec(for: toolID, scope: scope, projectRoot: projectRoot),
              FileManager.default.fileExists(atPath: spec.path)
        else { return [:] }

        let dict: [String: Any]
        switch spec.kind {
        case .json(let key):
            dict = (loadJsonRoot(path: spec.path)[key] as? [String: Any]) ?? [:]
        case .jsonNested(let keys):
            var cursor: [String: Any] = loadJsonRoot(path: spec.path)
            for k in keys { cursor = (cursor[k] as? [String: Any]) ?? [:] }
            dict = cursor
        case .toml(let key):
            let raw = (try? String(contentsOfFile: spec.path, encoding: .utf8)) ?? ""
            return parseTomlSections(raw, tableKey: key)

        case .yaml:
            return [:]
        }

        var out: [String: [String: Any]] = [:]
        for (name, value) in dict {
            guard var cfg = value as? [String: Any] else { continue }
            if toolID == "opencode" { cfg = opencodeShapeToClaude(cfg) }
            out[name] = cfg
        }
        return out
    }

    static func readAllServerEntries(
        toolID: String,
        scope: ConfigScope,
        projectRoot: String?
    ) -> [ServerEntry] {
        guard let spec = ToolSpecs.spec(for: toolID, scope: scope, projectRoot: projectRoot),
              FileManager.default.fileExists(atPath: spec.path)
        else { return [] }

        switch spec.kind {
        case .json(let key):
            let root = loadJsonRoot(path: spec.path)
            let active = serverEntries(from: root[key], toolID: toolID, isDisabled: false)
            let disabled = serverEntries(from: root["\(key)_disabled"], toolID: toolID, isDisabled: true)
            return (active + disabled).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        case .jsonNested(let keys):
            var cursor: [String: Any] = loadJsonRoot(path: spec.path)
            for key in keys { cursor = (cursor[key] as? [String: Any]) ?? [:] }
            return serverEntries(from: cursor, toolID: toolID, isDisabled: false)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        case .toml(let key):
            let raw = (try? String(contentsOfFile: spec.path, encoding: .utf8)) ?? ""
            return parseTomlSections(raw, tableKey: key)
                .map { name, cfg in
                    serverEntry(
                        name: name,
                        config: cfg,
                        toolID: toolID,
                        isDisabled: (cfg["enabled"] as? Bool) == false
                    )
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        case .yaml:
            return []
        }
    }

    private static func serverEntries(from value: Any?, toolID: String, isDisabled: Bool) -> [ServerEntry] {
        guard let dict = value as? [String: Any] else { return [] }
        return dict.compactMap { name, value in
            guard var config = value as? [String: Any] else { return nil }
            if toolID == "opencode" { config = opencodeShapeToClaude(config) }
            return serverEntry(name: name, config: config, toolID: toolID, isDisabled: isDisabled)
        }
    }

    private static func serverEntry(
        name: String,
        config: [String: Any],
        toolID: String,
        isDisabled: Bool
    ) -> ServerEntry {
        let launch = launchMetadata(from: config)
        let command = launch.command
        let args = launch.args
        let cwd = config["cwd"] as? String ?? config["workingDirectory"] as? String ?? config["working_directory"] as? String
        let url = config["url"] as? String
        var env = stringDictionary(config["env"])
        env.merge(launch.env) { current, _ in current }
        let inlineDisabled = boolValue(config["disabled"]) == true
        let transport: String
        if let type = config["type"] as? String { transport = type }
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
            headers: serverHeaders(from: config),
            headersHelper: config["headersHelper"] as? String,
            oauth: oauthMetadata(config["oauth"]),
            bearerTokenEnvVar: config["bearer_token_env_var"] as? String,
            envVars: localEnvVars(config["env_vars"]),
            envFile: config["envFile"] as? String ?? config["env_file"] as? String ?? launch.envFile,
            sandboxEnabled: boolValue(config["sandboxEnabled"] ?? config["sandbox_enabled"]),
            sandboxSummary: configSummary(config["sandbox"]),
            devSummary: configSummary(config["dev"]),
            enabledTools: stringArray(config["enabledTools"] ?? config["enabled_tools"]),
            alwaysAllowTools: stringArray(config["alwaysAllow"] ?? config["always_allow"]),
            disabledTools: stringArray(config["disabledTools"] ?? config["disabled_tools"]),
            defaultToolApprovalMode: config["defaultToolApprovalMode"] as? String ?? config["default_tools_approval_mode"] as? String,
            toolApprovalModes: toolApprovalModes(from: config),
            watchPaths: stringArray(config["watchPaths"] ?? config["watch_paths"]),
            serverTimeoutSeconds: codexNumber(config["timeout"]),
            startupTimeoutSeconds: codexStartupTimeoutSeconds(from: config),
            toolTimeoutSeconds: codexNumber(config["tool_timeout_sec"]),
            isDisabled: isDisabled || inlineDisabled
        )
    }

    private static func launchCommand(from config: [String: Any]) -> (command: String?, args: [String]) {
        let launch = launchMetadata(from: config)
        return (launch.command, launch.args)
    }

    private static func launchMetadata(from config: [String: Any]) -> MCPLaunchMetadata {
        MCPLaunchNormalizer.metadata(command: config["command"], args: stringArray(config["args"]))
    }

    private static func serverHeaders(from config: [String: Any]) -> [String: String] {
        var headers = stringDictionary(config["headers"])
        headers.merge(stringDictionary(config["http_headers"])) { _, new in new }
        for (header, envName) in stringDictionary(config["env_http_headers"]) {
            headers[header] = "${\(envName)}"
        }
        return headers
    }

    private static func stringDictionary(_ value: Any?) -> [String: String] {
        guard let dict = value as? [String: Any] else { return [:] }
        return Dictionary(uniqueKeysWithValues: dict.map { ($0.key, "\($0.value)") })
    }

    private static func boolValue(_ value: Any?) -> Bool? {
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

    private static func configSummary(_ value: Any?) -> String? {
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

    private static func oauthMetadata(_ value: Any?) -> [String: String] {
        let entries = stringDictionary(value).filter { key, value in
            !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !looksLikeCredentialPlaceholder(value)
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

    private static func looksLikeCredentialPlaceholder(_ value: String) -> Bool {
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

    private static func localEnvVars(_ value: Any?) -> [String] {
        if let strings = value as? [String] { return strings }
        guard let array = value as? [Any] else { return [] }
        return array.compactMap { item in
            if let string = item as? String { return string }
            if let dict = item as? [String: Any],
               let name = dict["name"] as? String,
               !name.isEmpty {
                let source = (dict["source"] as? String ?? "local")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                return source == "local" ? name : nil
            }
            return nil
        }
    }

    private static func codexStartupTimeoutSeconds(from config: [String: Any]) -> TimeInterval? {
        if let seconds = codexNumber(config["startup_timeout_sec"]) {
            return seconds
        }
        if let milliseconds = codexNumber(config["startup_timeout_ms"]) {
            return milliseconds / 1_000
        }
        return nil
    }

    private static func codexNumber(_ value: Any?) -> TimeInterval? {
        if let double = value as? Double, double > 0 { return double }
        if let int = value as? Int, int > 0 { return TimeInterval(int) }
        if let number = value as? NSNumber {
            let double = number.doubleValue
            return double > 0 ? double : nil
        }
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

    /// Does the tool's config file exist at the given scope? Cheap check — no parsing.
    static func configExists(toolID: String, scope: ConfigScope, projectRoot: String?) -> Bool {
        guard let spec = ToolSpecs.spec(for: toolID, scope: scope, projectRoot: projectRoot) else { return false }
        return FileManager.default.fileExists(atPath: spec.path)
    }

    static func nativeWriteBlocker(toolID: String, scope: ConfigScope, name: String, config: [String: Any]? = nil) -> String? {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if toolID == "claude-code", scope == .user {
            return "Claude Code global MCP lives in private ~/.claude.json state. Use the Claude CLI for global MCP, or choose Project scope to write the team-shared .mcp.json."
        }
        if toolID == "claude-code", normalized == "workspace" {
            return "Claude Code reserves the MCP server name \"workspace\" and skips it at load time. Rename this server before writing it to Claude Code."
        }
        if toolID == "claude-desktop", let config, isRemoteMCPConfig(config) {
            return "Claude Desktop remote MCP servers must be added through Settings > Connectors. Project Hub will not write hosted/remote MCP URLs into claude_desktop_config.json."
        }
        return nil
    }

    private static func isRemoteMCPConfig(_ config: [String: Any]) -> Bool {
        if let url = config["url"] as? String,
           !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        let transport = (config["type"] as? String ?? config["transport"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
        guard let transport, !transport.isEmpty else { return false }
        return !["stdio", "local"].contains(transport)
    }

    private static func shapeConfigForTarget(toolID: String, spec: ToolSpec, config: [String: Any]) -> [String: Any] {
        let sourceShape = appSpecificMCPMetadataStrippedIfNeeded(config, targetToolID: toolID)
        let claudeShape = claudeCompatibleServerConfig(sourceShape)
        if toolID == "opencode" {
            return claudeShapeToOpencode(claudeShape)
        }

        switch spec.kind {
        case .json, .jsonNested:
            return claudeShape
        case .toml, .yaml:
            return toolID == "codex" ? codexCompatibleServerConfig(sourceShape) : sourceShape
        }
    }

    private static func appSpecificMCPMetadataStrippedIfNeeded(_ config: [String: Any], targetToolID: String) -> [String: Any] {
        var out = config
        if targetToolID != "vscode" {
            out.removeValue(forKey: "sandboxEnabled")
            out.removeValue(forKey: "sandbox_enabled")
            out.removeValue(forKey: "sandbox")
            out.removeValue(forKey: "dev")
        }
        if targetToolID != "roo" {
            out.removeValue(forKey: "alwaysAllow")
            out.removeValue(forKey: "always_allow")
            out.removeValue(forKey: "watchPaths")
            out.removeValue(forKey: "watch_paths")
            out.removeValue(forKey: "timeout")
        }
        if targetToolID != "codex" {
            out.removeValue(forKey: "enabledTools")
            out.removeValue(forKey: "enabled_tools")
            out.removeValue(forKey: "defaultToolApprovalMode")
            out.removeValue(forKey: "default_tools_approval_mode")
            out.removeValue(forKey: "tools")
        }
        if targetToolID == "codex" {
            let looksLikeRooToolControl = config["alwaysAllow"] != nil
                || config["always_allow"] != nil
                || config["watchPaths"] != nil
                || config["watch_paths"] != nil
                || config["timeout"] != nil
            if looksLikeRooToolControl {
                out.removeValue(forKey: "disabledTools")
            }
        } else if targetToolID != "roo" {
            out.removeValue(forKey: "disabledTools")
            out.removeValue(forKey: "disabled_tools")
        }
        if boolValue(config["disabled"]) == true {
            if targetToolID == "codex" {
                out["enabled"] = false
            }
            if targetToolID != "roo" {
                out.removeValue(forKey: "disabled")
            }
        }
        return out
    }

    private static func claudeCompatibleServerConfig(_ config: [String: Any]) -> [String: Any] {
        var out = config
        var headers = stringDictionary(config["headers"])
        headers.merge(stringDictionary(config["http_headers"])) { _, new in new }

        for (header, envName) in stringDictionary(config["env_http_headers"]) {
            headers[header] = "${\(envName)}"
        }

        if let bearerEnv = config["bearer_token_env_var"] as? String,
           !bearerEnv.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            headers["Authorization"] = "Bearer ${\(bearerEnv)}"
        }

        if !headers.isEmpty {
            out["headers"] = headers
        }
        out.removeValue(forKey: "bearer_token_env_var")
        out.removeValue(forKey: "http_headers")
        out.removeValue(forKey: "env_http_headers")
        return out
    }

    private static func codexCompatibleServerConfig(_ config: [String: Any]) -> [String: Any] {
        var out = config
        guard out["bearer_token_env_var"] == nil else { return out }

        if let (sourceKey, envName) = authorizationBearerEnvHeader(in: config) {
            out["bearer_token_env_var"] = envName
            removeHeader(sourceKey, "Authorization", from: &out)
        }
        return out
    }

    private static func authorizationBearerEnvHeader(in config: [String: Any]) -> (sourceKey: String, envName: String)? {
        for sourceKey in ["headers", "http_headers"] {
            for (header, value) in stringDictionary(config[sourceKey]) where header.caseInsensitiveCompare("Authorization") == .orderedSame {
                if let envName = bearerEnvPlaceholderName(value) {
                    return (sourceKey, envName)
                }
            }
        }
        return nil
    }

    private static func bearerEnvPlaceholderName(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        guard lower.hasPrefix("bearer ") else { return nil }
        let remainder = String(trimmed.dropFirst("Bearer ".count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return envPlaceholderName(remainder)
    }

    private static func removeHeader(_ sourceKey: String, _ headerName: String, from config: inout [String: Any]) {
        var headers = stringDictionary(config[sourceKey])
        guard !headers.isEmpty else { return }
        for key in headers.keys where key.caseInsensitiveCompare(headerName) == .orderedSame {
            headers.removeValue(forKey: key)
        }
        if headers.isEmpty {
            config.removeValue(forKey: sourceKey)
        } else {
            config[sourceKey] = headers
        }
    }

    // MARK: - Opencode shape translation

    /// Claude-shape: { command: "npx", args: ["-y", "pkg"], env: {...} }
    ///             OR { url: "...", headers: {...} }
    /// Opencode: { type: "local", command: ["npx", "-y", "pkg"], environment: {...} }
    ///         OR { type: "remote", url: "...", headers: {...} }
    static func claudeShapeToOpencode(_ c: [String: Any]) -> [String: Any] {
        if let url = c["url"] as? String {
            var out: [String: Any] = ["type": "remote", "url": url]
            if let h = c["headers"] as? [String: Any], !h.isEmpty { out["headers"] = h }
            return out
        }
        var cmd: [String] = []
        if let command = c["command"] as? String, !command.isEmpty { cmd.append(command) }
        if let args = c["args"] as? [String] { cmd.append(contentsOf: args) }
        var out: [String: Any] = ["type": "local", "command": cmd]
        if let env = c["env"] as? [String: Any], !env.isEmpty { out["environment"] = env }
        if let cwd = c["cwd"] as? String, !cwd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out["cwd"] = cwd
        }
        return out
    }

    static func opencodeShapeToClaude(_ c: [String: Any]) -> [String: Any] {
        let type = c["type"] as? String ?? "local"
        if type == "remote" {
            var out: [String: Any] = [:]
            if let url = c["url"] as? String { out["url"] = url }
            if let h = c["headers"] as? [String: Any], !h.isEmpty { out["headers"] = h }
            return out
        }
        var command = ""
        var args: [String] = []
        if let parts = c["command"] as? [String] {
            command = parts.first ?? ""
            args    = Array(parts.dropFirst())
        } else if let s = c["command"] as? String {
            command = s
        }
        var out: [String: Any] = ["command": command, "args": args]
        if let env = c["environment"] as? [String: Any], !env.isEmpty { out["env"] = env }
        if let cwd = c["cwd"] as? String, !cwd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out["cwd"] = cwd
        }
        return out
    }

    /// Merges env values into an existing server's config, writing back.
    /// Only updates env keys provided; other env keys are left alone.
    /// Empty string values are treated as a delete of that env key.
    static func updateServerEnv(
        toolID: String,
        name: String,
        env: [String: String]
    ) throws {
        guard let spec = ToolSpecs.spec(for: toolID) else {
            throw WriteError.unsupportedFormat(toolID)
        }

        switch spec.kind {
        case .json(let key):
            try updateEnvJson(
                path: spec.path,
                key: key,
                name: name,
                env: env,
                envKey: toolID == "opencode" ? "environment" : "env"
            )
        case .jsonNested(let keys):
            try updateEnvJsonNested(path: spec.path, keys: keys, name: name, env: env, envKey: "env")
        case .toml(let key):
            try updateEnvToml(path: spec.path, tableKey: key, name: name, env: env)
        case .yaml:
            throw WriteError.unsupportedFormat(toolID)
        }
    }

    static func updateServerCredentials(
        toolID: String,
        name: String,
        values: [String: String],
        requirements: [ImportCredentialRequirement]
    ) throws {
        guard !requirements.isEmpty else {
            try updateServerEnv(toolID: toolID, name: name, env: values)
            return
        }
        guard let spec = ToolSpecs.spec(for: toolID) else {
            throw WriteError.unsupportedFormat(toolID)
        }

        switch spec.kind {
        case .json(let key):
            try updateCredentialsJson(
                path: spec.path,
                key: key,
                name: name,
                values: values,
                requirements: requirements,
                toolID: toolID,
                envKey: toolID == "opencode" ? "environment" : "env"
            )
        case .jsonNested(let keys):
            try updateCredentialsJsonNested(
                path: spec.path,
                keys: keys,
                name: name,
                values: values,
                requirements: requirements,
                envKey: "env"
            )
        case .toml(let key):
            try updateCredentialsToml(path: spec.path, tableKey: key, name: name, values: values, requirements: requirements)
        case .yaml:
            throw WriteError.unsupportedFormat(toolID)
        }
    }

    private static func updateEnvJson(
        path: String,
        key: String,
        name: String,
        env: [String: String],
        envKey: String
    ) throws {
        var root = loadJsonRoot(path: path)
        var dict = root[key] as? [String: Any] ?? [:]
        guard var server = dict[name] as? [String: Any] else {
            throw WriteError.readFailure("Server '\(name)' not found in \(path)")
        }
        var currentEnv = (server[envKey] as? [String: Any]) ?? [:]
        for (k, v) in env {
            if v.isEmpty { currentEnv.removeValue(forKey: k) }
            else         { currentEnv[k] = v }
        }
        if currentEnv.isEmpty { server.removeValue(forKey: envKey) }
        else { server[envKey] = currentEnv }
        dict[name]   = server
        root[key]    = dict
        try backupAndWrite(path: path, root: root)
    }

    private static func updateCredentialsJson(
        path: String,
        key: String,
        name: String,
        values: [String: String],
        requirements: [ImportCredentialRequirement],
        toolID: String,
        envKey: String
    ) throws {
        var root = loadJsonRoot(path: path)
        var dict = root[key] as? [String: Any] ?? [:]
        guard var server = dict[name] as? [String: Any] else {
            throw WriteError.readFailure("Server '\(name)' not found in \(path)")
        }
        if let blocker = nativeWriteBlocker(toolID: toolID, scope: .user, name: name, config: server) {
            throw WriteError.writeFailure(blocker)
        }
        applyCredentialValues(to: &server, values: values, requirements: requirements, envKey: envKey)
        dict[name] = server
        root[key] = dict
        try backupAndWrite(path: path, root: root)
    }

    private static func updateEnvJsonNested(
        path: String,
        keys: [String],
        name: String,
        env: [String: String],
        envKey: String
    ) throws {
        let root = loadJsonRoot(path: path)

        var chain: [[String: Any]] = [root]
        for key in keys {
            let current = chain.last!
            let next = current[key] as? [String: Any] ?? [:]
            chain.append(next)
        }

        var innermost = chain.removeLast()
        guard var server = innermost[name] as? [String: Any] else {
            throw WriteError.readFailure("Server '\(name)' not found in \(path)")
        }
        var currentEnv = (server[envKey] as? [String: Any]) ?? [:]
        for (k, v) in env {
            if v.isEmpty { currentEnv.removeValue(forKey: k) }
            else         { currentEnv[k] = v }
        }
        if currentEnv.isEmpty { server.removeValue(forKey: envKey) }
        else { server[envKey] = currentEnv }
        innermost[name] = server

        var up = innermost
        for key in keys.reversed() {
            var parent = chain.removeLast()
            parent[key] = up
            up = parent
        }

        try backupAndWrite(path: path, root: up)
    }

    private static func updateCredentialsJsonNested(
        path: String,
        keys: [String],
        name: String,
        values: [String: String],
        requirements: [ImportCredentialRequirement],
        envKey: String
    ) throws {
        let root = loadJsonRoot(path: path)

        var chain: [[String: Any]] = [root]
        for key in keys {
            let current = chain.last!
            let next = current[key] as? [String: Any] ?? [:]
            chain.append(next)
        }

        var innermost = chain.removeLast()
        guard var server = innermost[name] as? [String: Any] else {
            throw WriteError.readFailure("Server '\(name)' not found in \(path)")
        }
        applyCredentialValues(to: &server, values: values, requirements: requirements, envKey: envKey)
        innermost[name] = server

        var up = innermost
        for key in keys.reversed() {
            var parent = chain.removeLast()
            parent[key] = up
            up = parent
        }

        try backupAndWrite(path: path, root: up)
    }

    // MARK: - Enable / disable (moves between mcpServers and mcpServers_disabled)

    static func disableServer(toolID: String, name: String) throws {
        try setServerEnabled(toolID: toolID, scope: .user, projectRoot: nil, name: name, enabled: false)
    }

    static func enableServer(toolID: String, name: String) throws {
        try setServerEnabled(toolID: toolID, scope: .user, projectRoot: nil, name: name, enabled: true)
    }

    static func setServerEnabled(
        toolID: String,
        scope: ConfigScope,
        projectRoot: String?,
        name: String,
        enabled: Bool
    ) throws {
        guard let spec = ToolSpecs.spec(for: toolID, scope: scope, projectRoot: projectRoot) else {
            throw WriteError.unsupportedFormat(scope == .project ? "\(toolID) (project scope)" : toolID)
        }
        switch spec.kind {
        case .json(let key):
            var root = try loadJsonRootForMutation(path: spec.path)
            if toolID == "roo" {
                var active = root[key] as? [String: Any] ?? [:]
                guard var config = active[name] as? [String: Any] else { return }
                config["disabled"] = !enabled
                active[name] = config
                root[key] = active
                try backupAndWrite(path: spec.path, root: root)
                return
            }
            if enabled {
                guard var disabled = root["\(key)_disabled"] as? [String: Any],
                      let config = disabled[name] else { return }
                disabled.removeValue(forKey: name)
                if disabled.isEmpty { root.removeValue(forKey: "\(key)_disabled") }
                else { root["\(key)_disabled"] = disabled }
                var active = root[key] as? [String: Any] ?? [:]
                active[name] = config
                root[key] = active
            } else {
                guard var active = root[key] as? [String: Any],
                      let config = active[name] else { return }
                active.removeValue(forKey: name)
                root[key] = active
                var disabled = root["\(key)_disabled"] as? [String: Any] ?? [:]
                disabled[name] = config
                root["\(key)_disabled"] = disabled
            }
            try backupAndWrite(path: spec.path, root: root)
        case .jsonNested:
            throw WriteError.unsupportedFormat(toolID)
        case .toml(let key):
            try setTomlEnabled(path: spec.path, tableKey: key, name: name, enabled: enabled)
        case .yaml:
            throw WriteError.unsupportedFormat(toolID)
        }
    }

    /// Removes a server from the tool's config (user scope). Throws on failure.
    static func removeServer(
        toolID: String,
        name: String
    ) throws {
        try removeServer(toolID: toolID, scope: .user, projectRoot: nil, name: name)
    }

    /// Scope-aware remove. With `scope: .project` + a `projectRoot`, removes the
    /// server from `<projectRoot>/.cursor/mcp.json` (or the equivalent per tool).
    static func removeServer(
        toolID: String,
        scope: ConfigScope,
        projectRoot: String?,
        name: String
    ) throws {
        guard let spec = ToolSpecs.spec(for: toolID, scope: scope, projectRoot: projectRoot) else {
            throw WriteError.unsupportedFormat(scope == .project ? "\(toolID) (project scope)" : toolID)
        }

        switch spec.kind {
        case .json(let key):
            try removeJson(path: spec.path, key: key, name: name)
        case .jsonNested(let keys):
            try removeJsonNested(path: spec.path, keys: keys, name: name)
        case .toml(let key):
            try removeToml(path: spec.path, tableKey: key, name: name)
        case .yaml:
            throw WriteError.unsupportedFormat(toolID)
        }
    }

    // MARK: - JSON removers

    private static func removeJson(
        path: String,
        key: String,
        name: String
    ) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return } // nothing to remove

        var root: [String: Any] = try loadJsonRootForMutation(path: path)
        var dict = root[key] as? [String: Any] ?? [:]
        dict.removeValue(forKey: name)
        root[key] = dict
        var disabled = root["\(key)_disabled"] as? [String: Any] ?? [:]
        disabled.removeValue(forKey: name)
        if disabled.isEmpty { root.removeValue(forKey: "\(key)_disabled") }
        else { root["\(key)_disabled"] = disabled }

        try backupAndWrite(path: path, root: root)
    }

    private static func removeJsonNested(
        path: String,
        keys: [String],
        name: String
    ) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return }

        let root: [String: Any] = try loadJsonRootForMutation(path: path)

        // Walk into nested dicts
        var chain: [[String: Any]] = [root]
        for key in keys {
            let current = chain.last!
            let next = current[key] as? [String: Any] ?? [:]
            chain.append(next)
        }

        // Remove from innermost
        var innermost = chain.removeLast()
        innermost.removeValue(forKey: name)

        // Walk back up
        for key in keys.reversed() {
            var parent = chain.removeLast()
            parent[key] = innermost
            innermost = parent
        }

        try backupAndWrite(path: path, root: innermost)
    }

    // MARK: - JSON writers

    private static func writeJson(
        path: String,
        key: String,
        name: String,
        config: [String: Any]
    ) throws {
        ensureParent(of: path)

        var root: [String: Any] = try loadJsonRootForMutation(path: path)
        var dict = root[key] as? [String: Any] ?? [:]
        dict[name] = config
        root[key] = dict

        try backupAndWrite(path: path, root: root)
    }

    private static func writeJsonNested(
        path: String,
        keys: [String],
        name: String,
        config: [String: Any]
    ) throws {
        ensureParent(of: path)

        let root: [String: Any] = try loadJsonRootForMutation(path: path)

        // Walk into nested dicts, creating missing ones
        var chain: [[String: Any]] = [root]
        for key in keys {
            let current = chain.last!
            let next = current[key] as? [String: Any] ?? [:]
            chain.append(next)
        }

        // Set the server in the innermost dict
        var innermost = chain.removeLast()
        innermost[name] = config

        // Walk back up, replacing each level
        for key in keys.reversed() {
            var parent = chain.removeLast()
            parent[key] = innermost
            innermost = parent
        }

        try backupAndWrite(path: path, root: innermost)
    }

    // MARK: - Helpers

    private static func loadJsonRoot(path: String) -> [String: Any] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path),
              let raw = try? String(contentsOfFile: path, encoding: .utf8)
        else { return [:] }
        // Strip JSONC comments using same logic as the reader
        let stripped = stripJsonComments(raw)
        guard let data = stripped.data(using: .utf8),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return obj
    }

    private static func loadJsonRootForPreview(path: String) -> [String: Any]? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return [:] }
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let stripped = stripJsonComments(raw)
        guard let data = stripped.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }

    private static func loadJsonRootForMutation(path: String) throws -> [String: Any] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return [:] }
        let raw: String
        do {
            raw = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw WriteError.readFailure("Could not read \(path): \(error.localizedDescription)")
        }
        let stripped = stripJsonComments(raw)
        guard let data = stripped.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw WriteError.readFailure("Invalid JSON in \(path)")
        }
        return obj
    }

    private static func stringArray(_ value: Any?) -> [String] {
        if let strings = value as? [String] { return strings }
        if let any = value as? [Any] {
            return any.compactMap { $0 as? String }
        }
        return []
    }

    private static func rawConfigText(path: String) -> String {
        guard FileManager.default.fileExists(atPath: path),
              let raw = try? String(contentsOfFile: path, encoding: .utf8)
        else { return "" }
        return raw
    }

    private static func prettyJSON(_ root: [String: Any]) -> String {
        let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted])
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    // Keep the most recent N backups per config file.
    private static let maxBackupsPerFile = 3

    private static func backupAndWrite(path: String, root: [String: Any]) throws {
        let fm = FileManager.default

        // Timestamped backup: <path>.bak.<yyyyMMddHHmmssSSS>
        if fm.fileExists(atPath: path) {
            let stamp = backupStamp()
            let bak = "\(path).bak.\(stamp)"
            try? fm.copyItem(atPath: path, toPath: bak)
            pruneBackups(forPath: path)

            // Also clean up the legacy single ".bak" from older app versions
            // so it doesn't sit around indefinitely with stale keys.
            let legacy = path + ".bak"
            if fm.fileExists(atPath: legacy) { try? fm.removeItem(atPath: legacy) }
        }

        // Serialize pretty
        let data: Data
        do {
            data = try JSONSerialization.data(
                withJSONObject: root,
                options: [.prettyPrinted]
            )
        } catch {
            throw WriteError.writeFailure(error.localizedDescription)
        }

        // Atomic write: writes to a tmp file and renames. Either the old file
        // or the new file is there — never a truncated partial.
        do {
            try data.write(to: URL(fileURLWithPath: path), options: [.atomic])
        } catch {
            throw WriteError.writeFailure(error.localizedDescription)
        }
    }

    private static func backupStamp() -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyyMMddHHmmssSSS"
        return df.string(from: Date())
    }

    /// Returns backup paths for a config, newest first.
    static func backups(forPath path: String) -> [String] {
        let fm  = FileManager.default
        let url = URL(fileURLWithPath: path)
        let dir = url.deletingLastPathComponent().path
        let base = url.lastPathComponent + ".bak."

        guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { return [] }
        let matches = entries.filter { $0.hasPrefix(base) }
        // Timestamps sort lexically because of the yyyyMMddHHmmssSSS format.
        return matches.sorted().reversed().map { "\(dir)/\($0)" }
    }

    private static func pruneBackups(forPath path: String) {
        let all = backups(forPath: path)
        guard all.count > maxBackupsPerFile else { return }
        let fm = FileManager.default
        for old in all.dropFirst(maxBackupsPerFile) {
            try? fm.removeItem(atPath: old)
        }
    }

    /// Restores the most-recent backup over the live file (used by Undo).
    /// Returns true if a restore happened.
    @discardableResult
    static func restoreLatestBackup(forPath path: String) -> Bool {
        let fm = FileManager.default
        guard let latest = backups(forPath: path).first else { return false }
        do {
            if fm.fileExists(atPath: path) { try fm.removeItem(atPath: path) }
            try fm.copyItem(atPath: latest, toPath: path)
            // Consume the backup so Undo is a one-shot (prevents ping-pong).
            try? fm.removeItem(atPath: latest)
            return true
        } catch {
            return false
        }
    }

    private static func ensureParent(of path: String) {
        let url = URL(fileURLWithPath: path)
        let dir = url.deletingLastPathComponent().path
        try? FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true
        )
    }

    // MARK: - TOML writers / readers (Codex: [mcp_servers.<name>] sections)

    /// Write (or replace) a [<tableKey>.<name>] section in a TOML file.
    private static func writeToml(
        path: String,
        tableKey: String,
        name: String,
        config: [String: Any]
    ) throws {
        ensureParent(of: path)
        let existing = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        let section  = serverToTomlSection(tableKey: tableKey, name: name, config: config)
        let updated  = upsertTomlSection(toml: existing, tableKey: tableKey, name: name, section: section)
        try tomlBackupAndWrite(path: path, existing: existing, updated: updated)
    }

    /// Remove a [<tableKey>.<name>] section from a TOML file.
    private static func removeToml(
        path: String,
        tableKey: String,
        name: String
    ) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return }
        guard let existing = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw WriteError.readFailure("Could not read \(path)")
        }
        let updated = removeTomlSection(toml: existing, tableKey: tableKey, name: name)
        if updated == existing { return }
        try tomlBackupAndWrite(path: path, existing: existing, updated: updated)
    }

    /// Set or clear `enabled = false` in a TOML server section (toggle support).
    private static func setTomlEnabled(
        path: String,
        tableKey: String,
        name: String,
        enabled: Bool
    ) throws {
        guard let existing = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw WriteError.readFailure("Could not read \(path)")
        }
        let result = updateTomlServerEnabledLine(
            toml: existing,
            tableKey: tableKey,
            name: name,
            enabled: enabled
        )
        guard result.found else {
            throw WriteError.readFailure("Server '\(name)' not found in \(path)")
        }
        guard result.changed else { return }
        try tomlBackupAndWrite(path: path, existing: existing, updated: result.updated)
    }

    /// Update env keys in a TOML server section (used by NextSteps env-key form).
    private static func updateEnvToml(
        path: String,
        tableKey: String,
        name: String,
        env: [String: String]
    ) throws {
        guard let existing = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw WriteError.readFailure("Could not read \(path)")
        }
        let servers = parseTomlSections(existing, tableKey: tableKey)
        guard var cfg = servers[name] else {
            throw WriteError.readFailure("Server '\(name)' not found in \(path)")
        }
        var currentEnv = (cfg["env"] as? [String: Any]) ?? [:]
        for (k, v) in env {
            if v.isEmpty { currentEnv.removeValue(forKey: k) }
            else         { currentEnv[k] = v }
        }
        if currentEnv.isEmpty { cfg.removeValue(forKey: "env") }
        else                  { cfg["env"] = currentEnv }
        let section = serverToTomlSection(tableKey: tableKey, name: name, config: cfg)
        let updated = upsertTomlSection(toml: existing, tableKey: tableKey, name: name, section: section)
        try tomlBackupAndWrite(path: path, existing: existing, updated: updated)
    }

    private static func updateCredentialsToml(
        path: String,
        tableKey: String,
        name: String,
        values: [String: String],
        requirements: [ImportCredentialRequirement]
    ) throws {
        guard let existing = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw WriteError.readFailure("Could not read \(path)")
        }
        let servers = parseTomlSections(existing, tableKey: tableKey)
        guard var cfg = servers[name] else {
            throw WriteError.readFailure("Server '\(name)' not found in \(path)")
        }
        applyCredentialValues(
            to: &cfg,
            values: values,
            requirements: requirements,
            envKey: "env",
            preferredHeaderKey: "http_headers"
        )
        let section = serverToTomlSection(tableKey: tableKey, name: name, config: cfg)
        let updated = upsertTomlSection(toml: existing, tableKey: tableKey, name: name, section: section)
        try tomlBackupAndWrite(path: path, existing: existing, updated: updated)
    }

    private static func applyCredentialValues(
        to server: inout [String: Any],
        values: [String: String],
        requirements: [ImportCredentialRequirement],
        envKey: String = "env",
        preferredHeaderKey: String = "headers"
    ) {
        var env = (server[envKey] as? [String: Any]) ?? [:]
        var headers: [String: String] = [:]
        if preferredHeaderKey == "http_headers" {
            headers.merge(stringDictionary(server["headers"])) { _, new in new }
            headers.merge(stringDictionary(server["http_headers"])) { _, new in new }
        } else {
            headers.merge(stringDictionary(server["http_headers"])) { _, new in new }
            headers.merge(stringDictionary(server["headers"])) { _, new in new }
        }
        var envHeaders = stringDictionary(server["env_http_headers"])

        for requirement in requirements {
            let valueKey = requirement.envName ?? requirement.name
            let rawValue = values[valueKey] ?? values[requirement.name] ?? ""
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            switch requirement.kind {
            case .env:
                let key = requirement.envName ?? requirement.name
                if trimmed.isEmpty { env.removeValue(forKey: key) }
                else { env[key] = trimmed }
            case .header:
                if trimmed.isEmpty {
                    headers.removeValue(forKey: requirement.name)
                } else {
                    let envPlaceholder = requirement.envName.map { "${\($0)}" }
                    let authoredPlaceholder = requirement.placeholder
                    if var existing = headers[requirement.name],
                       let placeholder = [authoredPlaceholder, envPlaceholder].compactMap({ $0 }).first(where: { existing.contains($0) }) {
                        existing = existing.replacingOccurrences(of: placeholder, with: trimmed)
                        headers[requirement.name] = existing
                    } else {
                        headers[requirement.name] = trimmed
                    }
                    envHeaders.removeValue(forKey: requirement.name)
                }
            case .urlVariable:
                guard !trimmed.isEmpty,
                      var url = server["url"] as? String else { continue }
                let placeholder = requirement.placeholder
                    ?? requirement.envName.map { "${\($0)}" }
                    ?? "{\(requirement.name)}"
                url = url.replacingOccurrences(of: placeholder, with: trimmed)
                if let envName = requirement.envName {
                    url = url.replacingOccurrences(of: "${\(envName)}", with: trimmed)
                }
                url = url.replacingOccurrences(of: "{\(requirement.name)}", with: trimmed)
                server["url"] = url
            }
        }

        if env.isEmpty { server.removeValue(forKey: envKey) }
        else { server[envKey] = env }

        if headers.isEmpty {
            server.removeValue(forKey: preferredHeaderKey)
        } else {
            server[preferredHeaderKey] = headers
        }
        if preferredHeaderKey != "headers" {
            server.removeValue(forKey: "headers")
        }
        if preferredHeaderKey != "http_headers" {
            server.removeValue(forKey: "http_headers")
        }
        if envHeaders.isEmpty { server.removeValue(forKey: "env_http_headers") }
        else { server["env_http_headers"] = envHeaders }
    }

    static func previewRemoveStaleCodexSkillOverrides(
        configPath: String
    ) -> (before: String, after: String, removed: [String])? {
        guard let existing = try? String(contentsOfFile: configPath, encoding: .utf8) else { return nil }
        let result = removeStaleCodexSkillSections(toml: existing, configPath: configPath)
        guard !result.removed.isEmpty, result.updated != existing else { return nil }
        return (existing, result.updated, result.removed)
    }

    static func removeStaleCodexSkillOverrides(configPath: String) throws {
        guard let existing = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            throw WriteError.readFailure("Could not read \(configPath)")
        }
        let result = removeStaleCodexSkillSections(toml: existing, configPath: configPath)
        guard !result.removed.isEmpty, result.updated != existing else { return }
        try tomlBackupAndWrite(path: configPath, existing: existing, updated: result.updated)
    }

    static func previewSetCodexSkillOverrideEnabled(
        configPath: String,
        skillMDPath: String,
        enabled: Bool
    ) -> (before: String, after: String)? {
        guard let existing = try? String(contentsOfFile: configPath, encoding: .utf8),
              let updated = setCodexSkillOverrideEnabled(
                toml: existing,
                configPath: configPath,
                skillMDPath: skillMDPath,
                enabled: enabled
              ),
              updated != existing
        else { return nil }
        return (existing, updated)
    }

    static func setCodexSkillOverrideEnabled(
        configPath: String,
        skillMDPath: String,
        enabled: Bool
    ) throws {
        guard let existing = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            throw WriteError.readFailure("Could not read \(configPath)")
        }
        guard let updated = setCodexSkillOverrideEnabled(
            toml: existing,
            configPath: configPath,
            skillMDPath: skillMDPath,
            enabled: enabled
        ), updated != existing else { return }
        try tomlBackupAndWrite(path: configPath, existing: existing, updated: updated)
    }

    static func previewReplaceTopLevelTOMLStringSetting(
        configPath: String,
        key: String,
        from oldValue: String,
        to newValue: String
    ) -> (before: String, after: String)? {
        guard let existing = try? String(contentsOfFile: configPath, encoding: .utf8),
              let updated = replaceTopLevelTOMLStringSetting(
                toml: existing,
                key: key,
                from: oldValue,
                to: newValue
              ),
              updated != existing
        else { return nil }
        return (existing, updated)
    }

    static func replaceTopLevelTOMLStringSetting(
        configPath: String,
        key: String,
        from oldValue: String,
        to newValue: String
    ) throws {
        guard let existing = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            throw WriteError.readFailure("Could not read \(configPath)")
        }
        guard let updated = replaceTopLevelTOMLStringSetting(
            toml: existing,
            key: key,
            from: oldValue,
            to: newValue
        ), updated != existing else { return }
        try tomlBackupAndWrite(path: configPath, existing: existing, updated: updated)
    }

    static func topLevelTOMLStringSetting(configPath: String, key: String) -> String? {
        guard let existing = try? String(contentsOfFile: configPath, encoding: .utf8) else { return nil }
        return topLevelTOMLStringSetting(toml: existing, key: key)
    }

    static func previewMigrateDeprecatedCodexInstructionFile(
        configPath: String
    ) -> (before: String, after: String, value: String, migrated: Bool)? {
        let existing = rawConfigText(path: configPath)
        guard let result = migrateDeprecatedCodexInstructionFile(toml: existing),
              result.updated != existing
        else { return nil }
        return (existing, result.updated, result.value, result.migrated)
    }

    static func topLevelTOMLStringArraySetting(configPath: String, key: String) -> [String]? {
        guard let existing = try? String(contentsOfFile: configPath, encoding: .utf8) else { return nil }
        return topLevelTOMLStringArraySetting(toml: existing, key: key)
    }

    static func previewUpsertTopLevelTOMLIntSetting(
        configPath: String,
        key: String,
        value: Int
    ) -> (before: String, after: String)? {
        let existing = rawConfigText(path: configPath)
        guard let updated = upsertTopLevelTOMLIntSetting(
            toml: existing,
            key: key,
            value: value
        ), updated != existing else { return nil }
        return (existing, updated)
    }

    static func upsertTopLevelTOMLIntSetting(
        configPath: String,
        key: String,
        value: Int
    ) throws {
        let existing = rawConfigText(path: configPath)
        guard let updated = upsertTopLevelTOMLIntSetting(
            toml: existing,
            key: key,
            value: value
        ), updated != existing else { return }
        try tomlBackupAndWrite(path: configPath, existing: existing, updated: updated)
    }

    static func previewUpsertTopLevelTOMLStringArraySetting(
        configPath: String,
        key: String,
        values: [String]
    ) -> (before: String, after: String)? {
        let existing = rawConfigText(path: configPath)
        guard let updated = upsertTopLevelTOMLStringArraySetting(
            toml: existing,
            key: key,
            values: values
        ), updated != existing else { return nil }
        return (existing, updated)
    }

    static func upsertTopLevelTOMLStringArraySetting(
        configPath: String,
        key: String,
        values: [String]
    ) throws {
        let existing = rawConfigText(path: configPath)
        guard let updated = upsertTopLevelTOMLStringArraySetting(
            toml: existing,
            key: key,
            values: values
        ), updated != existing else { return }
        try tomlBackupAndWrite(path: configPath, existing: existing, updated: updated)
    }

    static func previewAppendGitignorePattern(
        gitignorePath: String,
        pattern: String
    ) -> (before: String, after: String)? {
        let existing = rawConfigText(path: gitignorePath)
        guard let updated = appendGitignorePattern(
            gitignore: existing,
            pattern: pattern
        ), updated != existing else { return nil }
        return (existing, updated)
    }

    static func appendGitignorePattern(
        gitignorePath: String,
        pattern: String
    ) throws {
        let existing = rawConfigText(path: gitignorePath)
        guard let updated = appendGitignorePattern(
            gitignore: existing,
            pattern: pattern
        ), updated != existing else { return }
        try tomlBackupAndWrite(path: gitignorePath, existing: existing, updated: updated)
    }

    static func previewRemoveIgnoredCodexProjectSettings(
        configPath: String
    ) -> (before: String, after: String, removed: [String])? {
        let existing = rawConfigText(path: configPath)
        let result = removeIgnoredCodexProjectSettings(toml: existing)
        guard !result.removed.isEmpty, result.updated != existing else { return nil }
        return (existing, result.updated, result.removed)
    }

    static func removeIgnoredCodexProjectSettings(configPath: String) throws {
        let existing = rawConfigText(path: configPath)
        let result = removeIgnoredCodexProjectSettings(toml: existing)
        guard !result.removed.isEmpty, result.updated != existing else { return }
        try tomlBackupAndWrite(path: configPath, existing: existing, updated: result.updated)
    }

    static func codexProjectSettingOverlap(
        globalConfigPath: String,
        projectConfigPath: String,
        projectRoot: String
    ) -> [String] {
        let global = rawConfigText(path: globalConfigPath)
        let project = rawConfigText(path: projectConfigPath)
        let globalKeys = codexProjectSectionKeys(toml: global, projectRoot: projectRoot)
        let projectKeys = topLevelTOMLKeys(toml: project)
        return Array(globalKeys.intersection(projectKeys).intersection(codexProjectSettingKeys)).sorted()
    }

    static func codexProjectTrustLevel(
        globalConfigPath: String,
        projectRoot: String
    ) -> String? {
        let global = rawConfigText(path: globalConfigPath)
        return codexProjectSectionValues(toml: global, projectRoot: projectRoot)["trust_level"]
    }

    static func previewSetCodexProjectTrust(
        globalConfigPath: String,
        projectRoot: String,
        trusted: Bool
    ) -> (before: String, after: String)? {
        let existing = rawConfigText(path: globalConfigPath)
        let trustLevel = trusted ? "trusted" : "untrusted"
        guard let updated = setCodexProjectTrust(
            toml: existing,
            projectRoot: projectRoot,
            trustLevel: trustLevel
        ), updated != existing else { return nil }
        return (existing, updated)
    }

    static func setCodexProjectTrust(
        globalConfigPath: String,
        projectRoot: String,
        trusted: Bool
    ) throws {
        let existing = rawConfigText(path: globalConfigPath)
        let trustLevel = trusted ? "trusted" : "untrusted"
        guard let updated = setCodexProjectTrust(
            toml: existing,
            projectRoot: projectRoot,
            trustLevel: trustLevel
        ), updated != existing else { return }
        try tomlBackupAndWrite(path: globalConfigPath, existing: existing, updated: updated)
    }

    static func previewRemoveTopLevelTOMLKeys(
        configPath: String,
        keys: [String]
    ) -> (before: String, after: String, removed: [String])? {
        let existing = rawConfigText(path: configPath)
        let result = removeTopLevelTOMLKeys(toml: existing, keys: Set(keys))
        guard !result.removed.isEmpty, result.updated != existing else { return nil }
        return (existing, result.updated, result.removed)
    }

    static func removeTopLevelTOMLKeys(
        configPath: String,
        keys: [String]
    ) throws {
        let existing = rawConfigText(path: configPath)
        let result = removeTopLevelTOMLKeys(toml: existing, keys: Set(keys))
        guard !result.removed.isEmpty, result.updated != existing else { return }
        try tomlBackupAndWrite(path: configPath, existing: existing, updated: result.updated)
    }

    static func previewRemoveTOMLSectionKeys(
        configPath: String,
        section: String,
        keys: [String]
    ) -> (before: String, after: String, removed: [String])? {
        let existing = rawConfigText(path: configPath)
        let result = removeTOMLSectionKeys(toml: existing, section: section, keys: Set(keys))
        guard !result.removed.isEmpty, result.updated != existing else { return nil }
        return (existing, result.updated, result.removed)
    }

    static func removeTOMLSectionKeys(
        configPath: String,
        section: String,
        keys: [String]
    ) throws {
        let existing = rawConfigText(path: configPath)
        let result = removeTOMLSectionKeys(toml: existing, section: section, keys: Set(keys))
        guard !result.removed.isEmpty, result.updated != existing else { return }
        try tomlBackupAndWrite(path: configPath, existing: existing, updated: result.updated)
    }

    static func previewSetCodexPluginMCPServerEnabled(
        configPath: String,
        pluginID: String,
        serverName: String,
        enabled: Bool,
        profileName: String? = nil
    ) -> (before: String, after: String)? {
        let existing = rawConfigText(path: configPath)
        let isProfileFile = codexPluginPolicyPathIsProfileConfigFile(configPath)
        let updated = setCodexPluginMCPServerEnabled(
            toml: existing,
            pluginID: pluginID,
            serverName: serverName,
            enabled: enabled,
            profileName: isProfileFile ? nil : profileName,
            allowActiveProfileInference: !isProfileFile && codexPluginProfilePolicyIsEffectivePath(configPath)
        )
        guard updated != existing else { return nil }
        return (existing, updated)
    }

    static func applyCodexPluginMCPServerEnabledPreview(
        configPath: String,
        expectedBefore: String,
        approvedAfter: String
    ) throws {
        try applyTOMLPreview(
            configPath: configPath,
            expectedBefore: expectedBefore,
            approvedAfter: approvedAfter
        )
    }

    static func applyTOMLPreview(
        configPath: String,
        expectedBefore: String,
        approvedAfter: String
    ) throws {
        try applyTextPreview(
            configPath: configPath,
            expectedBefore: expectedBefore,
            approvedAfter: approvedAfter
        )
    }

    static func applyTextPreview(
        configPath: String,
        expectedBefore: String,
        approvedAfter: String
    ) throws {
        let existing = rawConfigText(path: configPath)
        guard existing == expectedBefore else {
            throw WriteError.writeFailure("Refusing to overwrite file changed after preview: \(configPath)")
        }
        guard existing != approvedAfter else { return }
        ensureParent(of: configPath)
        try backupAndWriteText(path: configPath, existing: existing, updated: approvedAfter)
    }

    static func setCodexPluginMCPServerEnabled(
        configPath: String,
        pluginID: String,
        serverName: String,
        enabled: Bool,
        profileName: String? = nil,
        expectedBefore: String? = nil
    ) throws {
        let existing = rawConfigText(path: configPath)
        if let expectedBefore, existing != expectedBefore {
            throw WriteError.writeFailure("Refusing to overwrite file changed after preview: \(configPath)")
        }
        let isProfileFile = codexPluginPolicyPathIsProfileConfigFile(configPath)
        let updated = setCodexPluginMCPServerEnabled(
            toml: existing,
            pluginID: pluginID,
            serverName: serverName,
            enabled: enabled,
            profileName: isProfileFile ? nil : profileName,
            allowActiveProfileInference: !isProfileFile && codexPluginProfilePolicyIsEffectivePath(configPath)
        )
        guard updated != existing else { return }
        ensureParent(of: configPath)
        try tomlBackupAndWrite(path: configPath, existing: existing, updated: updated)
    }

    static func previewRemoveInlineTOMLTableKeys(
        configPath: String,
        section: String?,
        assignmentKey: String,
        keys: [String]
    ) -> (before: String, after: String, removed: [String])? {
        let existing = rawConfigText(path: configPath)
        let result = removeInlineTOMLTableKeys(
            toml: existing,
            section: section,
            assignmentKey: assignmentKey,
            keys: Set(keys)
        )
        guard !result.removed.isEmpty, result.updated != existing else { return nil }
        return (existing, result.updated, result.removed)
    }

    static func removeInlineTOMLTableKeys(
        configPath: String,
        section: String?,
        assignmentKey: String,
        keys: [String]
    ) throws {
        let existing = rawConfigText(path: configPath)
        let result = removeInlineTOMLTableKeys(
            toml: existing,
            section: section,
            assignmentKey: assignmentKey,
            keys: Set(keys)
        )
        guard !result.removed.isEmpty, result.updated != existing else { return }
        try tomlBackupAndWrite(path: configPath, existing: existing, updated: result.updated)
    }

    static func previewRemoveNestedInlineTOMLTableKeys(
        configPath: String,
        section: String?,
        assignmentKey: String,
        tableKey: String,
        keys: [String]
    ) -> (before: String, after: String, removed: [String])? {
        let existing = rawConfigText(path: configPath)
        let result = removeNestedInlineTOMLTableKeys(
            toml: existing,
            section: section,
            assignmentKey: assignmentKey,
            tableKey: tableKey,
            keys: Set(keys)
        )
        guard !result.removed.isEmpty, result.updated != existing else { return nil }
        return (existing, result.updated, result.removed)
    }

    static func removeNestedInlineTOMLTableKeys(
        configPath: String,
        section: String?,
        assignmentKey: String,
        tableKey: String,
        keys: [String]
    ) throws {
        let existing = rawConfigText(path: configPath)
        let result = removeNestedInlineTOMLTableKeys(
            toml: existing,
            section: section,
            assignmentKey: assignmentKey,
            tableKey: tableKey,
            keys: Set(keys)
        )
        guard !result.removed.isEmpty, result.updated != existing else { return }
        try tomlBackupAndWrite(path: configPath, existing: existing, updated: result.updated)
    }

    // MARK: - TOML text helpers

    /// Serialise a claude-shape server dict into TOML section text.
    private static func serverToTomlSection(tableKey: String, name: String, config: [String: Any]) -> String {
        var lines = ["[\(tableKey).\(tomlKey(name))]"]
        if let enabled = config["enabled"] as? Bool, !enabled {
            lines.append("enabled = false")
        }
        if let startupTimeout = tomlNumber(config["startup_timeout_sec"]) {
            lines.append("startup_timeout_sec = \(startupTimeout)")
        } else if let startupTimeoutMS = tomlNumber(config["startup_timeout_ms"]) {
            lines.append("startup_timeout_ms = \(startupTimeoutMS)")
        }
        if let toolTimeout = tomlNumber(config["tool_timeout_sec"]) {
            lines.append("tool_timeout_sec = \(toolTimeout)")
        }
        if let url = config["url"] as? String {
            lines.append("url = \(tomlStr(url))")
            if let tokenEnv = config["bearer_token_env_var"] as? String, !tokenEnv.isEmpty {
                lines.append("bearer_token_env_var = \(tomlStr(tokenEnv))")
            }
            var headers = tomlStringMap(config["headers"])
            headers.merge(tomlStringMap(config["http_headers"])) { _, new in new }
            var envHeaders = inferredEnvHTTPHeaders(from: headers)
            envHeaders.merge(tomlStringMap(config["env_http_headers"])) { _, explicit in explicit }
            if !headers.isEmpty {
                let pairs = headers.sorted { $0.key < $1.key }
                    .filter { key, value in
                        envHeaders[key].map { "${\($0)}" } != value
                    }
                    .map { "\(tomlKey($0.key)) = \(tomlStr($0.value))" }
                    .joined(separator: ", ")
                if !pairs.isEmpty {
                    lines.append("http_headers = { \(pairs) }")
                }
            }
            if !envHeaders.isEmpty {
                let pairs = envHeaders.sorted { $0.key < $1.key }
                    .map { "\(tomlKey($0.key)) = \(tomlStr($0.value))" }
                    .joined(separator: ", ")
                lines.append("env_http_headers = { \(pairs) }")
            }
        } else {
            if let cmd = config["command"] as? String, !cmd.isEmpty {
                lines.append("command = \(tomlStr(cmd))")
            }
            if let args = config["args"] as? [String], !args.isEmpty {
                lines.append("args = [\(args.map { tomlStr($0) }.joined(separator: ", "))]")
            }
            if let cwd = config["cwd"] as? String ?? config["workingDirectory"] as? String ?? config["working_directory"] as? String,
               !cwd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("cwd = \(tomlStr(cwd))")
            }
            if let env = config["env"] as? [String: Any], !env.isEmpty {
                let pairs = env.sorted { $0.key < $1.key }
                    .map { "\(tomlKey($0.key)) = \(tomlStr($0.value as? String ?? ""))" }
                    .joined(separator: ", ")
                lines.append("env = { \(pairs) }")
            }
            if let envVars = tomlEnvVars(config["env_vars"]) {
                lines.append("env_vars = \(envVars)")
            }
        }
        if let envFile = config["envFile"] as? String ?? config["env_file"] as? String,
           !envFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("env_file = \(tomlStr(envFile))")
        }
        let enabledTools = stringArray(config["enabled_tools"] ?? config["enabledTools"])
        if !enabledTools.isEmpty {
            lines.append("enabled_tools = [\(enabledTools.map { tomlStr($0) }.joined(separator: ", "))]")
        }
        let disabledTools = stringArray(config["disabled_tools"] ?? config["disabledTools"])
        if !disabledTools.isEmpty {
            lines.append("disabled_tools = [\(disabledTools.map { tomlStr($0) }.joined(separator: ", "))]")
        }
        if let approvalMode = config["default_tools_approval_mode"] as? String ?? config["defaultToolApprovalMode"] as? String,
           !approvalMode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("default_tools_approval_mode = \(tomlStr(approvalMode))")
        }
        for (tool, mode) in toolApprovalModes(from: config).sorted(by: { $0.key < $1.key }) {
            lines.append("tools.\(tomlKey(tool)).approval_mode = \(tomlStr(mode))")
        }
        return lines.joined(separator: "\n")
    }

    private static func toolApprovalModes(from config: [String: Any]) -> [String: String] {
        var modes: [String: String] = [:]
        if let tools = config["tools"] as? [String: Any] {
            for (tool, raw) in tools {
                if let dict = raw as? [String: Any],
                   let mode = dict["approval_mode"] as? String ?? dict["approvalMode"] as? String {
                    modes[tool] = mode
                }
            }
        }
        for (key, raw) in config where key.hasPrefix("tools.") {
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
        if let flat = config["toolApprovalModes"] as? [String: String] {
            modes.merge(flat) { _, new in new }
        }
        return modes.filter { !$0.key.isEmpty && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func tomlStringMap(_ value: Any?) -> [String: String] {
        if let strings = value as? [String: String] { return strings }
        if let any = value as? [String: Any] {
            return Dictionary(uniqueKeysWithValues: any.map { ($0.key, "\($0.value)") })
        }
        return [:]
    }

    private static func inferredEnvHTTPHeaders(from headers: [String: String]) -> [String: String] {
        var out: [String: String] = [:]
        for (header, value) in headers {
            if let envName = envPlaceholderName(value) {
                out[header] = envName
            }
        }
        return out
    }

    private static func envPlaceholderName(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("${"),
              trimmed.hasSuffix("}"),
              trimmed.count > 3 else { return nil }
        let name = String(trimmed.dropFirst(2).dropLast())
        guard isShellEnvName(name) else { return nil }
        return name
    }

    private static func isShellEnvName(_ name: String) -> Bool {
        guard let first = name.unicodeScalars.first else { return false }
        guard (first.value >= 65 && first.value <= 90)
                || (first.value >= 97 && first.value <= 122)
                || first.value == 95 else { return false }
        return name.unicodeScalars.dropFirst().allSatisfy {
            ($0.value >= 65 && $0.value <= 90)
                || ($0.value >= 97 && $0.value <= 122)
                || ($0.value >= 48 && $0.value <= 57)
                || $0.value == 95
        }
    }

    private static func tomlEnvVars(_ value: Any?) -> String? {
        if let strings = value as? [String], !strings.isEmpty {
            return "[\(strings.map { tomlStr($0) }.joined(separator: ", "))]"
        }
        if let entries = value as? [[String: String]], !entries.isEmpty {
            let parts = entries.compactMap { entry -> String? in
                guard let name = entry["name"], !name.isEmpty else { return nil }
                let source = entry["source"] ?? "local"
                if source == "local" {
                    return tomlStr(name)
                }
                return "{ name = \(tomlStr(name)), source = \(tomlStr(source)) }"
            }
            return parts.isEmpty ? nil : "[\(parts.joined(separator: ", "))]"
        }
        if let entries = value as? [[String: Any]], !entries.isEmpty {
            let parts = entries.compactMap { entry -> String? in
                guard let name = entry["name"] as? String, !name.isEmpty else { return nil }
                let source = entry["source"] as? String ?? "local"
                if source == "local" {
                    return tomlStr(name)
                }
                return "{ name = \(tomlStr(name)), source = \(tomlStr(source)) }"
            }
            return parts.isEmpty ? nil : "[\(parts.joined(separator: ", "))]"
        }
        return nil
    }

    private static func tomlNumber(_ value: Any?) -> String? {
        if let int = value as? Int, int > 0 { return "\(int)" }
        if let double = value as? Double, double > 0 { return tomlNumberString(double) }
        if let string = value as? String {
            let normalized = string
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "_", with: "")
            if let double = Double(normalized), double > 0 {
                return tomlNumberString(double)
            }
        }
        return nil
    }

    private static func tomlNumberString(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return "\(value)"
    }

    private static func tomlStr(_ s: String) -> String {
        let e = s.replacingOccurrences(of: "\\", with: "\\\\")
                 .replacingOccurrences(of: "\"", with: "\\\"")
                 .replacingOccurrences(of: "\n", with: "\\n")
                 .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(e)\""
    }

    private static func tomlKey(_ s: String) -> String {
        let isBare = s.unicodeScalars.allSatisfy {
            ($0.value >= 65 && $0.value <= 90) ||
            ($0.value >= 97 && $0.value <= 122) ||
            ($0.value >= 48 && $0.value <= 57) ||
            $0.value == 45 || $0.value == 95
        }
        return isBare ? s : tomlStr(s)
    }

    /// Insert or replace a [<tableKey>.<name>] section in TOML text.
    private static func upsertTomlSection(
        toml: String,
        tableKey: String,
        name: String,
        section: String
    ) -> String {
        let target = [tableKey, name]
        let lines = toml.components(separatedBy: "\n")
        var start: Int? = nil
        var end = lines.count

        for (i, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)
            if let header = tomlSectionName(from: t),
               tomlSectionSegments(header) == target {
                start = i
            } else if start != nil && t.hasPrefix("[") && !t.hasPrefix("#") {
                end = i
                break
            }
        }

        let newLines = section.components(separatedBy: "\n")
        if let s = start {
            var result = Array(lines[0..<s])
            result += newLines
            let tail = Array(lines[end...])
            if !tail.isEmpty && !tail[0].trimmingCharacters(in: .whitespaces).isEmpty {
                result.append("")
            }
            result += tail
            return result.joined(separator: "\n")
        } else {
            var result = toml
            if !result.hasSuffix("\n") { result += "\n" }
            if !result.hasSuffix("\n\n") { result += "\n" }
            result += newLines.joined(separator: "\n") + "\n"
            return result
        }
    }

    private static func updateTomlServerEnabledLine(
        toml: String,
        tableKey: String,
        name: String,
        enabled: Bool
    ) -> (updated: String, found: Bool, changed: Bool) {
        var lines = toml.components(separatedBy: "\n")
        var start: Int?
        var end = lines.count

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("["), !trimmed.hasPrefix("#") else { continue }
            guard let header = tomlSectionName(from: trimmed),
                  let identity = tomlServerSectionIdentity(header, tableKey: tableKey) else {
                if start != nil {
                    end = index
                    break
                }
                continue
            }

            if identity.name == name, identity.nested == nil {
                start = index
                end = lines.count
            } else if start != nil {
                end = index
                break
            }
        }

        guard let start else { return (toml, false, false) }

        var enabledLine: Int?
        if start + 1 < end {
            for index in (start + 1)..<end {
                let line = lines[index]
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
                guard let eq = line.firstIndex(of: "=") else { continue }
                let rawKey = line[..<eq].trimmingCharacters(in: .whitespaces)
                if rawKey.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) == "enabled" {
                    enabledLine = index
                    break
                }
            }
        }

        if enabled {
            guard let enabledLine else { return (toml, true, false) }
            lines.remove(at: enabledLine)
            return (lines.joined(separator: "\n"), true, true)
        }

        if let enabledLine {
            let line = lines[enabledLine]
            guard let eq = line.firstIndex(of: "=") else { return (toml, true, false) }
            let valueAndComment = String(line[line.index(after: eq)...])
            let parts = splitTOMLValueAndComment(valueAndComment)
            let current = parts.value.trimmingCharacters(in: .whitespaces)
            guard current != "false" else { return (toml, true, false) }
            let prefix = line[..<line.index(after: eq)]
            let spacing = valueAndComment.prefix { $0 == " " || $0 == "\t" }
            let beforeCommentSpacing = parts.comment.isEmpty
                ? ""
                : String(parts.value.reversed().prefix { $0 == " " || $0 == "\t" }.reversed())
            lines[enabledLine] = "\(prefix)\(spacing)false\(beforeCommentSpacing)\(parts.comment)"
            return (lines.joined(separator: "\n"), true, true)
        }

        var insertIndex = end
        while insertIndex > start + 1,
              lines[insertIndex - 1].trimmingCharacters(in: .whitespaces).isEmpty {
            insertIndex -= 1
        }
        lines.insert("enabled = false", at: insertIndex)
        return (lines.joined(separator: "\n"), true, true)
    }

    /// Delete a [<tableKey>.<name>] section (and its preceding blank lines) from TOML text.
    private static func removeTomlSection(toml: String, tableKey: String, name: String) -> String {
        let lines = toml.components(separatedBy: "\n")
        var removeIndexes = Set<Int>()
        var sectionStart: Int?
        var sectionMatchesTarget = false

        for (i, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("[") && !t.hasPrefix("#") {
                if let sectionStart, sectionMatchesTarget {
                    for index in sectionStart..<i {
                        removeIndexes.insert(index)
                    }
                }
                sectionStart = nil
                sectionMatchesTarget = false
                guard let header = tomlSectionName(from: t) else { continue }
                sectionStart = i
                if let identity = tomlServerSectionIdentity(header, tableKey: tableKey),
                   identity.name == name {
                    sectionMatchesTarget = true
                }
            }
        }

        if let sectionStart, sectionMatchesTarget {
            for index in sectionStart..<lines.count {
                removeIndexes.insert(index)
            }
        }

        guard !removeIndexes.isEmpty else { return toml }
        for index in removeIndexes.sorted() {
            var start = index
            while start > 0,
                  !removeIndexes.contains(start - 1),
                  lines[start - 1].trimmingCharacters(in: .whitespaces).isEmpty {
                removeIndexes.insert(start - 1)
                start -= 1
            }
        }
        let kept = lines.enumerated()
            .filter { !removeIndexes.contains($0.offset) }
            .map(\.element)
        var result = kept.joined(separator: "\n")
        while result.hasSuffix("\n\n\n") { result = String(result.dropLast()) }
        return result
    }

    private static func removeStaleCodexSkillSections(
        toml: String,
        configPath: String
    ) -> (updated: String, removed: [String]) {
        let lines = toml.components(separatedBy: "\n")
        let sections = codexSkillConfigSections(in: lines, configPath: configPath)
        let stale = sections.filter { !FileManager.default.fileExists(atPath: $0.resolvedPath) }
        guard !stale.isEmpty else { return (toml, []) }

        var removeIndexes = Set<Int>()
        for section in stale {
            var start = section.start
            while start > 0 && lines[start - 1].trimmingCharacters(in: .whitespaces).isEmpty {
                start -= 1
            }
            for index in start..<section.end {
                removeIndexes.insert(index)
            }
        }

        let kept = lines.enumerated()
            .filter { !removeIndexes.contains($0.offset) }
            .map(\.element)
        var updated = kept.joined(separator: "\n")
        while updated.hasSuffix("\n\n\n") { updated = String(updated.dropLast()) }
        return (updated, stale.map(\.resolvedPath).sorted())
    }

    private static func setCodexSkillOverrideEnabled(
        toml: String,
        configPath: String,
        skillMDPath: String,
        enabled: Bool
    ) -> String? {
        var lines = toml.components(separatedBy: "\n")
        let target = Project.canonicalize(skillMDPath)
        guard FileManager.default.fileExists(atPath: target) else { return nil }
        let matches = codexSkillConfigSections(in: lines, configPath: configPath)
            .filter { Project.canonicalize($0.resolvedPath) == target }
        guard matches.count == 1, let section = matches.first else { return nil }
        if enabled {
            guard section.enabled == false else { return nil }
        }

        let replacement = "enabled = \(enabled ? "true" : "false")"
        var enabledLine: Int?
        for index in section.start..<section.end {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let eq = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<eq].trimmingCharacters(in: .whitespaces)
            if key == "enabled" {
                enabledLine = index
                break
            }
        }

        if let enabledLine {
            if lines[enabledLine].trimmingCharacters(in: .whitespaces) == replacement {
                return nil
            }
            let prefix = String(lines[enabledLine].prefix { $0 == " " || $0 == "\t" })
            lines[enabledLine] = prefix + replacement
        } else {
            if enabled { return nil }
            lines.insert(replacement, at: section.end)
        }

        return lines.joined(separator: "\n")
    }

    private static func replaceTopLevelTOMLStringSetting(
        toml: String,
        key: String,
        from oldValue: String,
        to newValue: String
    ) -> String? {
        var lines = toml.components(separatedBy: "\n")
        for index in lines.indices {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if trimmed.hasPrefix("[") { break }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let rawKey = line[..<eq].trimmingCharacters(in: .whitespaces)
            guard rawKey.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) == key else { continue }

            let valueAndComment = String(line[line.index(after: eq)...])
            let parts = splitTOMLValueAndComment(valueAndComment)
            guard parseTOMLStringLiteral(parts.value.trimmingCharacters(in: .whitespaces)) == oldValue else { return nil }

            let prefix = line[..<line.index(after: eq)]
            let spacing = valueAndComment.prefix { $0 == " " || $0 == "\t" }
            let beforeCommentSpacing = parts.comment.isEmpty
                ? ""
                : String(parts.value.reversed().prefix { $0 == " " || $0 == "\t" }.reversed())
            lines[index] = "\(prefix)\(spacing)\(tomlStr(newValue))\(beforeCommentSpacing)\(parts.comment)"
            return lines.joined(separator: "\n")
        }
        return nil
    }

    private static func topLevelTOMLStringSetting(toml: String, key: String) -> String? {
        let lines = toml.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if trimmed.hasPrefix("[") { break }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let rawKey = line[..<eq].trimmingCharacters(in: .whitespaces)
            guard rawKey.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) == key else { continue }

            let valueAndComment = String(line[line.index(after: eq)...])
            let parts = splitTOMLValueAndComment(valueAndComment)
            return parseTOMLStringLiteral(parts.value.trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    private static func migrateDeprecatedCodexInstructionFile(
        toml: String
    ) -> (updated: String, value: String, migrated: Bool)? {
        let hasReplacement = topLevelTOMLKeys(toml: toml).contains("model_instructions_file")
        var lines = toml.components(separatedBy: "\n")

        for index in lines.indices {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if trimmed.hasPrefix("[") { break }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let rawKey = line[..<eq].trimmingCharacters(in: .whitespaces)
            guard rawKey.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) == "experimental_instructions_file" else {
                continue
            }

            let valueAndComment = String(line[line.index(after: eq)...])
            let parts = splitTOMLValueAndComment(valueAndComment)
            guard let value = parseTOMLStringLiteral(parts.value.trimmingCharacters(in: .whitespaces)),
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }

            if hasReplacement {
                let result = removeTopLevelTOMLKeys(toml: toml, keys: ["experimental_instructions_file"])
                guard !result.removed.isEmpty else { return nil }
                return (result.updated, value, false)
            }

            let keyPrefix = line[..<eq]
            let indent = String(keyPrefix.prefix { $0 == " " || $0 == "\t" })
            let trailingKeySpacing = String(keyPrefix.reversed().prefix { $0 == " " || $0 == "\t" }.reversed())
            lines[index] = "\(indent)model_instructions_file\(trailingKeySpacing)\(line[eq...])"
            return (lines.joined(separator: "\n"), value, true)
        }

        return nil
    }

    private static func topLevelTOMLStringArraySetting(toml: String, key: String) -> [String]? {
        let lines = toml.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if trimmed.hasPrefix("[") { break }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let rawKey = line[..<eq].trimmingCharacters(in: .whitespaces)
            guard rawKey.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) == key else { continue }

            let valueAndComment = String(line[line.index(after: eq)...])
            let parts = splitTOMLValueAndComment(valueAndComment)
            return parseTOMLStringArrayLiteral(parts.value.trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    private static func upsertTopLevelTOMLIntSetting(
        toml: String,
        key: String,
        value: Int
    ) -> String? {
        upsertTopLevelTOMLSetting(
            toml: toml,
            key: key,
            replacementValue: "\(value)",
            currentValueMatches: { parseTOMLIntLiteral($0) == value }
        )
    }

    private static func upsertTopLevelTOMLStringArraySetting(
        toml: String,
        key: String,
        values: [String]
    ) -> String? {
        upsertTopLevelTOMLSetting(
            toml: toml,
            key: key,
            replacementValue: "[\(values.map(tomlStr).joined(separator: ", "))]",
            currentValueMatches: { parseTOMLStringArrayLiteral($0) == values }
        )
    }

    private static func upsertTopLevelTOMLSetting(
        toml: String,
        key: String,
        replacementValue: String,
        currentValueMatches: (String) -> Bool
    ) -> String? {
        var lines = toml.components(separatedBy: "\n")
        var insertBeforeSection: Int?

        for index in lines.indices {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                insertBeforeSection = index
                break
            }
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let rawKey = line[..<eq].trimmingCharacters(in: .whitespaces)
            guard rawKey.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) == key else { continue }

            let valueAndComment = String(line[line.index(after: eq)...])
            let parts = splitTOMLValueAndComment(valueAndComment)
            let currentValue = parts.value.trimmingCharacters(in: .whitespaces)
            if currentValueMatches(currentValue) {
                return nil
            }

            let prefix = line[..<line.index(after: eq)]
            let spacing = valueAndComment.prefix { $0 == " " || $0 == "\t" }
            let beforeCommentSpacing = parts.comment.isEmpty
                ? ""
                : String(parts.value.reversed().prefix { $0 == " " || $0 == "\t" }.reversed())
            lines[index] = "\(prefix)\(spacing)\(replacementValue)\(beforeCommentSpacing)\(parts.comment)"
            return lines.joined(separator: "\n")
        }

        let newLine = "\(key) = \(replacementValue)"
        if toml.isEmpty {
            return newLine + "\n"
        }

        if let insertBeforeSection {
            var updated = lines
            var insertIndex = insertBeforeSection
            var hasSectionSeparator = false
            while insertIndex > 0,
                  updated[insertIndex - 1].trimmingCharacters(in: .whitespaces).isEmpty {
                hasSectionSeparator = true
                insertIndex -= 1
            }
            if hasSectionSeparator {
                updated.insert(newLine, at: insertIndex)
            } else if insertBeforeSection > 0 {
                updated.insert("", at: insertBeforeSection)
                updated.insert(newLine, at: insertBeforeSection)
            } else {
                updated.insert(newLine, at: insertBeforeSection)
            }
            return updated.joined(separator: "\n")
        }

        var updated = toml
        if !updated.hasSuffix("\n") {
            updated += "\n"
        }
        updated += newLine + "\n"
        return updated
    }

    private static func splitTOMLValueAndComment(_ text: String) -> (value: String, comment: String) {
        var inSingle = false
        var inDouble = false
        var escaped = false
        for (offset, char) in text.enumerated() {
            if escaped {
                escaped = false
                continue
            }
            if inDouble && char == "\\" {
                escaped = true
                continue
            }
            if char == "\"" && !inSingle {
                inDouble.toggle()
                continue
            }
            if char == "'" && !inDouble {
                inSingle.toggle()
                continue
            }
            if char == "#" && !inSingle && !inDouble {
                let index = text.index(text.startIndex, offsetBy: offset)
                return (String(text[..<index]), String(text[index...]))
            }
        }
        return (text, "")
    }

    private static func parseTOMLStringLiteral(_ text: String) -> String? {
        if text.hasPrefix("\""), text.hasSuffix("\""), text.count >= 2 {
            var value = ""
            var escaped = false
            for char in text.dropFirst().dropLast() {
                if escaped {
                    switch char {
                    case "n": value.append("\n")
                    case "t": value.append("\t")
                    case "\"": value.append("\"")
                    case "\\": value.append("\\")
                    default: value.append(char)
                    }
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else {
                    value.append(char)
                }
            }
            return escaped ? nil : value
        }
        if text.hasPrefix("'"), text.hasSuffix("'"), text.count >= 2 {
            return String(text.dropFirst().dropLast())
        }
        return nil
    }

    private static func parseTOMLStringArrayLiteral(_ text: String) -> [String]? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("["),
              trimmed.hasSuffix("]") else { return nil }
        let inner = String(trimmed.dropFirst().dropLast())
        if inner.trimmingCharacters(in: .whitespaces).isEmpty { return [] }
        var values: [String] = []
        for item in splitTOMLArray(inner) {
            guard let value = parseTOMLStringLiteral(item.trimmingCharacters(in: .whitespaces)) else {
                return nil
            }
            values.append(value)
        }
        return values
    }

    private static func parseTOMLIntLiteral(_ text: String) -> Int? {
        let normalized = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "_", with: "")
        guard !normalized.isEmpty else { return nil }
        return Int(normalized)
    }

    private static func splitTOMLArray(_ text: String) -> [String] {
        var items: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escaped = false

        for ch in text {
            if escaped {
                current.append(ch)
                escaped = false
                continue
            }
            if inDouble && ch == "\\" {
                current.append(ch)
                escaped = true
                continue
            }
            if ch == "'", !inDouble {
                inSingle.toggle()
                current.append(ch)
                continue
            }
            if ch == "\"", !inSingle {
                inDouble.toggle()
                current.append(ch)
                continue
            }
            if ch == ",", !inSingle, !inDouble {
                items.append(current)
                current = ""
                continue
            }
            current.append(ch)
        }
        if !current.isEmpty { items.append(current) }
        return items
    }

    private static func appendGitignorePattern(gitignore: String, pattern: String) -> String? {
        let normalizedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPattern.isEmpty else { return nil }
        let lines = gitignore.components(separatedBy: .newlines).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard !lines.contains(normalizedPattern) else { return nil }

        if gitignore.isEmpty {
            return normalizedPattern + "\n"
        }

        var updated = gitignore
        if !updated.hasSuffix("\n") {
            updated += "\n"
        }
        updated += normalizedPattern + "\n"
        return updated
    }

    private static let ignoredCodexProjectTopLevelKeys: Set<String> = [
        "openai_base_url",
        "chatgpt_base_url",
        "model_provider",
        "model_providers",
        "notify",
        "profile",
        "profiles",
        "experimental_realtime_ws_base_url",
        "otel",
        "preferred_auth_method",
        "cli_auth_credentials_store",
        "mcp_oauth_credentials_store"
    ]

    private static let codexProjectSettingKeys: Set<String> = [
        "model",
        "approval_policy",
        "sandbox_mode",
        "model_provider",
        "profile",
        "trust_level",
        "preferred_auth_method"
    ]

    private static let ignoredCodexProjectSectionRoots: [String] = [
        "model_providers",
        "profiles",
        "otel"
    ]

    private static func removeIgnoredCodexProjectSettings(toml: String) -> (updated: String, removed: [String]) {
        let lines = toml.components(separatedBy: "\n")
        var removeIndexes = Set<Int>()
        var removed = Set<String>()
        var inTopLevel = true
        var activeSectionStart: Int?
        var activeSectionName: String?

        func shouldRemoveSection(_ section: String) -> Bool {
            ignoredCodexProjectSectionRoots.contains { root in
                section == root || section.hasPrefix("\(root).")
            }
        }

        func markSectionForRemoval(end: Int) {
            guard let start = activeSectionStart,
                  let name = activeSectionName,
                  shouldRemoveSection(name) else { return }
            var sectionStart = start
            while sectionStart > 0 && lines[sectionStart - 1].trimmingCharacters(in: .whitespaces).isEmpty {
                sectionStart -= 1
            }
            for index in sectionStart..<end {
                removeIndexes.insert(index)
            }
            removed.insert(name)
        }

        for (index, rawLine) in lines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                markSectionForRemoval(end: index)
                inTopLevel = false
                activeSectionStart = index
                activeSectionName = tomlSectionName(from: trimmed)
                continue
            }

            guard inTopLevel,
                  !trimmed.isEmpty,
                  !trimmed.hasPrefix("#"),
                  let eq = rawLine.firstIndex(of: "=") else { continue }
            let key = rawLine[..<eq]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if ignoredCodexProjectTopLevelKeys.contains(key) {
                removeIndexes.insert(index)
                removed.insert(key)
            }
        }

        markSectionForRemoval(end: lines.count)
        guard !removeIndexes.isEmpty else { return (toml, []) }

        let kept = lines.enumerated()
            .filter { !removeIndexes.contains($0.offset) }
            .map(\.element)
        var updated = kept.joined(separator: "\n")
        while updated.hasSuffix("\n\n\n") { updated = String(updated.dropLast()) }
        return (updated, removed.sorted())
    }

    private static func removeTopLevelTOMLKeys(toml: String, keys: Set<String>) -> (updated: String, removed: [String]) {
        guard !keys.isEmpty else { return (toml, []) }
        let lines = toml.components(separatedBy: "\n")
        var removeIndexes = Set<Int>()
        var removed = Set<String>()

        for (index, rawLine) in lines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") { break }
            guard !trimmed.isEmpty,
                  !trimmed.hasPrefix("#"),
                  let eq = rawLine.firstIndex(of: "=") else { continue }
            let rawKey = rawLine[..<eq].trimmingCharacters(in: .whitespaces)
            let strippedKey = rawKey.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            let key: String
            if keys.contains(rawKey) {
                key = rawKey
            } else if keys.contains(strippedKey) {
                key = strippedKey
            } else {
                continue
            }
            guard keys.contains(key) else { continue }
            removeIndexes.insert(index)
            removed.insert(key)
        }

        guard !removeIndexes.isEmpty else { return (toml, []) }
        let kept = lines.enumerated()
            .filter { !removeIndexes.contains($0.offset) }
            .map(\.element)
        var updated = kept.joined(separator: "\n")
        while updated.hasPrefix("\n\n") { updated.removeFirst() }
        while updated.hasSuffix("\n\n\n") { updated = String(updated.dropLast()) }
        return (updated, removed.sorted())
    }

    private static func removeTOMLSectionKeys(
        toml: String,
        section: String,
        keys: Set<String>
    ) -> (updated: String, removed: [String]) {
        guard !section.isEmpty, !keys.isEmpty else { return (toml, []) }
        let lines = toml.components(separatedBy: "\n")
        var removeIndexes = Set<Int>()
        var removed = Set<String>()
        var inTargetSection = false

        for (index, rawLine) in lines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if let header = tomlSectionName(from: trimmed) {
                inTargetSection = header == section
                continue
            }

            guard inTargetSection,
                  !trimmed.isEmpty,
                  !trimmed.hasPrefix("#"),
                  let eq = rawLine.firstIndex(of: "=") else { continue }
            let rawKey = rawLine[..<eq].trimmingCharacters(in: .whitespaces)
            let strippedKey = rawKey.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            let key: String
            if keys.contains(rawKey) {
                key = rawKey
            } else if keys.contains(strippedKey) {
                key = strippedKey
            } else {
                continue
            }
            guard keys.contains(key) else { continue }
            removeIndexes.insert(index)
            removed.insert(key)
        }

        guard !removeIndexes.isEmpty else { return (toml, []) }
        let kept = lines.enumerated()
            .filter { !removeIndexes.contains($0.offset) }
            .map(\.element)
        var updated = kept.joined(separator: "\n")
        while updated.hasSuffix("\n\n\n") { updated = String(updated.dropLast()) }
        return (updated, removed.sorted())
    }

    private static func setCodexPluginMCPServerEnabled(
        toml: String,
        pluginID: String,
        serverName: String,
        enabled: Bool,
        profileName: String? = nil,
        allowActiveProfileInference: Bool = true
    ) -> String {
        guard !pluginID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !serverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return toml
        }
        let profile = profileName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if enabled,
           allowActiveProfileInference,
           profile == nil,
           let activeProfile = codexActiveProfile(toml),
           codexPluginMCPServerEnabledPolicy(
                toml: toml,
                pluginID: pluginID,
                serverName: serverName,
                profileName: activeProfile
           ) == false {
            let profileUpdated = setCodexPluginMCPServerEnabled(
                toml: toml,
                pluginID: pluginID,
                serverName: serverName,
                enabled: true,
                profileName: activeProfile,
                allowActiveProfileInference: false
            )
            guard codexPluginMCPServerEnabledPolicy(
                toml: profileUpdated,
                pluginID: pluginID,
                serverName: serverName,
                profileName: nil
            ) == false else {
                return profileUpdated
            }
            return setCodexPluginMCPServerEnabled(
                toml: profileUpdated,
                pluginID: pluginID,
                serverName: serverName,
                enabled: true,
                profileName: nil,
                allowActiveProfileInference: false
            )
        }
        let target = profile.flatMap { $0.isEmpty ? nil : ["profiles", $0, "plugins", pluginID, "mcp_servers", serverName] }
            ?? ["plugins", pluginID, "mcp_servers", serverName]
        var lines = toml.components(separatedBy: "\n")
        var start: Int?
        var end = lines.count

        for (index, rawLine) in lines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard let section = tomlSectionName(from: trimmed) else { continue }
            if start != nil {
                end = index
                break
            }
            if tomlSectionSegments(section) == target {
                start = index
            }
        }

        guard let start else {
            guard !enabled else { return toml }
            let section = codexPluginMCPPolicySection(
                pluginID: pluginID,
                serverName: serverName,
                enabled: false,
                profileName: profile
            )
            var output = toml
            if !output.isEmpty && !output.hasSuffix("\n") {
                output += "\n"
            }
            if !output.isEmpty {
                output += "\n"
            }
            output += section
            return output
        }

        var enabledLineIndex: Int?
        for index in (start + 1)..<end {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  !trimmed.hasPrefix("#"),
                  let eq = lines[index].firstIndex(of: "=") else { continue }
            let key = lines[index][..<eq]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if key == "enabled" {
                enabledLineIndex = index
                break
            }
        }

        if enabled {
            guard let enabledLineIndex else {
                if profile == nil,
                   allowActiveProfileInference,
                   let activeProfile = codexActiveProfile(toml) {
                    return setCodexPluginMCPServerEnabled(
                        toml: toml,
                        pluginID: pluginID,
                        serverName: serverName,
                        enabled: enabled,
                        profileName: activeProfile,
                        allowActiveProfileInference: false
                    )
                }
                return toml
            }
            lines.remove(at: enabledLineIndex)
            return lines.joined(separator: "\n")
        }

        if let enabledLineIndex {
            let indent = lines[enabledLineIndex].prefix { $0 == " " || $0 == "\t" }
            lines[enabledLineIndex] = "\(indent)enabled = false"
        } else {
            lines.insert("enabled = false", at: start + 1)
        }
        return lines.joined(separator: "\n")
    }

    private static func codexActiveProfile(_ toml: String) -> String? {
        var currentSection: String?
        for rawLine in toml.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if let section = tomlSectionName(from: trimmed) {
                currentSection = section
                continue
            }
            guard currentSection == nil,
                  let eq = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<eq]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard key == "profile" else { continue }
            let rawValue = trimmed[trimmed.index(after: eq)...]
                .trimmingCharacters(in: .whitespaces)
            if let profile = parseTomlVal(String(rawValue)) as? String,
               !profile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return profile
            }
        }
        return nil
    }

    private static func codexPluginProfilePolicyIsEffectivePath(_ configPath: String) -> Bool {
        let standardized = URL(fileURLWithPath: configPath).standardizedFileURL.path
        let codexHome = ProjectHubPaths.codexHome()
        let codexGlobalConfig = URL(fileURLWithPath: codexHome)
            .appendingPathComponent("config.toml")
            .standardizedFileURL
            .path
        if standardized == codexGlobalConfig {
            return true
        }
        let suffix = Array((standardized as NSString).pathComponents.suffix(2))
        return suffix != [".codex", "config.toml"]
    }

    private static func codexPluginPolicyPathIsProfileConfigFile(_ configPath: String) -> Bool {
        let standardized = URL(fileURLWithPath: configPath).standardizedFileURL.path
        let codexHome = ProjectHubPaths.codexHome()
        let standardizedHome = URL(fileURLWithPath: codexHome).standardizedFileURL.path
        guard (standardized as NSString).deletingLastPathComponent == standardizedHome else { return false }
        let filename = (standardized as NSString).lastPathComponent
        return filename != "config.toml" && filename.hasSuffix(".config.toml")
    }

    private static func codexPluginMCPServerEnabledPolicy(
        toml: String,
        pluginID: String,
        serverName: String,
        profileName: String?
    ) -> Bool? {
        let profile = profileName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = profile.flatMap { $0.isEmpty ? nil : ["profiles", $0, "plugins", pluginID, "mcp_servers", serverName] }
            ?? ["plugins", pluginID, "mcp_servers", serverName]
        var inTarget = false

        for rawLine in toml.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if let section = tomlSectionName(from: trimmed) {
                inTarget = tomlSectionSegments(section) == target
                continue
            }
            guard inTarget,
                  let eq = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<eq]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard key == "enabled" else { continue }
            let rawValue = trimmed[trimmed.index(after: eq)...]
                .trimmingCharacters(in: .whitespaces)
            return parseTomlVal(String(rawValue)) as? Bool
        }
        return nil
    }

    private static func codexPluginMCPPolicySection(
        pluginID: String,
        serverName: String,
        enabled: Bool,
        profileName: String?
    ) -> String {
        let section: String
        if let profileName, !profileName.isEmpty {
            section = "[profiles.\(tomlKey(profileName)).plugins.\(tomlStr(pluginID)).mcp_servers.\(tomlKey(serverName))]"
        } else {
            section = "[plugins.\(tomlStr(pluginID)).mcp_servers.\(tomlKey(serverName))]"
        }
        return "\(section)\nenabled = \(enabled ? "true" : "false")\n"
    }

    private static func removeInlineTOMLTableKeys(
        toml: String,
        section: String?,
        assignmentKey: String,
        keys: Set<String>
    ) -> (updated: String, removed: [String]) {
        guard !assignmentKey.isEmpty, !keys.isEmpty else { return (toml, []) }
        var lines = toml.components(separatedBy: "\n")
        var currentSection: String?
        var removed = Set<String>()

        for (index, rawLine) in lines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if let header = tomlSectionName(from: trimmed) {
                currentSection = header
                continue
            }
            guard currentSection == section,
                  !trimmed.isEmpty,
                  !trimmed.hasPrefix("#"),
                  let eq = rawLine.firstIndex(of: "=") else { continue }

            let lineKey = rawLine[..<eq]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard lineKey == assignmentKey else { continue }

            let prefix = rawLine[..<rawLine.index(after: eq)]
            let valueAndComment = rawLine[rawLine.index(after: eq)...]
            let spacing = valueAndComment.prefix { $0 == " " || $0 == "\t" }
            let split = splitTOMLValueAndComment(String(valueAndComment))
            let value = split.value.trimmingCharacters(in: .whitespaces)
            guard value.hasPrefix("{"), value.hasSuffix("}") else { continue }

            let inner = String(value.dropFirst().dropLast())
            guard let table = removeInlineTOMLTableKeys(from: inner, keys: keys),
                  !table.removed.isEmpty,
                  !table.kept.isEmpty else { continue }

            let beforeCommentSpacing = split.comment.isEmpty
                ? ""
                : String(split.value.reversed().prefix { $0 == " " || $0 == "\t" }.reversed())
            lines[index] = "\(prefix)\(spacing){ \(table.kept.joined(separator: ", ")) }\(beforeCommentSpacing)\(split.comment)"
            removed.formUnion(table.removed)
        }

        guard !removed.isEmpty else { return (toml, []) }
        return (lines.joined(separator: "\n"), removed.sorted())
    }

    private static func removeInlineTOMLTableKeys(
        from inner: String,
        keys: Set<String>
    ) -> (kept: [String], removed: Set<String>)? {
        let pairs = splitTOMLInlineTablePairs(inner)
        guard !pairs.isEmpty else { return nil }
        var kept: [String] = []
        var removed = Set<String>()

        for pair in pairs {
            guard let eq = pair.firstIndex(of: "=") else { return nil }
            let key = pair[..<eq]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if keys.contains(key) {
                removed.insert(key)
            } else {
                kept.append(pair.trimmingCharacters(in: .whitespaces))
            }
        }

        return (kept, removed)
    }

    private static func removeNestedInlineTOMLTableKeys(
        toml: String,
        section: String?,
        assignmentKey: String,
        tableKey: String,
        keys: Set<String>
    ) -> (updated: String, removed: [String]) {
        guard !assignmentKey.isEmpty, !tableKey.isEmpty, !keys.isEmpty else { return (toml, []) }
        var lines = toml.components(separatedBy: "\n")
        var currentSection: String?
        var removed = Set<String>()

        for (index, rawLine) in lines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if let header = tomlSectionName(from: trimmed) {
                currentSection = header
                continue
            }
            guard currentSection == section,
                  !trimmed.isEmpty,
                  !trimmed.hasPrefix("#"),
                  let eq = rawLine.firstIndex(of: "=") else { continue }

            let lineKey = rawLine[..<eq]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard lineKey == assignmentKey else { continue }

            let prefix = rawLine[..<rawLine.index(after: eq)]
            let valueAndComment = rawLine[rawLine.index(after: eq)...]
            let spacing = valueAndComment.prefix { $0 == " " || $0 == "\t" }
            let split = splitTOMLValueAndComment(String(valueAndComment))
            let value = split.value.trimmingCharacters(in: .whitespaces)
            guard value.hasPrefix("{"), value.hasSuffix("}") else { continue }

            let inner = String(value.dropFirst().dropLast())
            guard let table = removeNestedInlineTOMLTableKeys(
                from: inner,
                tableKey: tableKey,
                keys: keys
            ),
                  !table.removed.isEmpty,
                  !table.kept.isEmpty else { continue }

            let beforeCommentSpacing = split.comment.isEmpty
                ? ""
                : String(split.value.reversed().prefix { $0 == " " || $0 == "\t" }.reversed())
            lines[index] = "\(prefix)\(spacing){ \(table.kept.joined(separator: ", ")) }\(beforeCommentSpacing)\(split.comment)"
            removed.formUnion(table.removed)
        }

        guard !removed.isEmpty else { return (toml, []) }
        return (lines.joined(separator: "\n"), removed.sorted())
    }

    private static func removeNestedInlineTOMLTableKeys(
        from inner: String,
        tableKey: String,
        keys: Set<String>
    ) -> (kept: [String], removed: Set<String>)? {
        let pairs = splitTOMLInlineTablePairs(inner)
        guard !pairs.isEmpty else { return nil }
        var kept: [String] = []
        var removed = Set<String>()

        for pair in pairs {
            guard let eq = pair.firstIndex(of: "=") else { return nil }
            let rawKey = pair[..<eq].trimmingCharacters(in: .whitespaces)
            let key = rawKey.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            let rawValue = pair[pair.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            guard key == tableKey else {
                kept.append(pair.trimmingCharacters(in: .whitespaces))
                continue
            }
            guard rawValue.hasPrefix("{"), rawValue.hasSuffix("}"),
                  let nested = removeInlineTOMLTableKeys(
                    from: String(rawValue.dropFirst().dropLast()),
                    keys: keys
                  ),
                  !nested.removed.isEmpty,
                  !nested.kept.isEmpty else {
                kept.append(pair.trimmingCharacters(in: .whitespaces))
                continue
            }
            removed.formUnion(nested.removed)
            kept.append("\(rawKey) = { \(nested.kept.joined(separator: ", ")) }")
        }

        return (kept, removed)
    }

    private static func splitTOMLInlineTablePairs(_ inner: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escaped = false
        var bracketDepth = 0
        var braceDepth = 0

        for char in inner {
            if escaped {
                current.append(char)
                escaped = false
                continue
            }
            if inDouble && char == "\\" {
                current.append(char)
                escaped = true
                continue
            }
            if char == "\"", !inSingle {
                inDouble.toggle()
                current.append(char)
                continue
            }
            if char == "'", !inDouble {
                inSingle.toggle()
                current.append(char)
                continue
            }
            if !inSingle && !inDouble {
                switch char {
                case "[":
                    bracketDepth += 1
                case "]":
                    bracketDepth = max(0, bracketDepth - 1)
                case "{":
                    braceDepth += 1
                case "}":
                    braceDepth = max(0, braceDepth - 1)
                case "," where bracketDepth == 0 && braceDepth == 0:
                    let pair = current.trimmingCharacters(in: .whitespaces)
                    if !pair.isEmpty { result.append(pair) }
                    current = ""
                    continue
                default:
                    break
                }
            }
            current.append(char)
        }

        let tail = current.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { result.append(tail) }
        return result
    }

    private static func topLevelTOMLKeys(toml: String) -> Set<String> {
        var keys = Set<String>()
        for rawLine in toml.components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") { break }
            guard !trimmed.isEmpty,
                  !trimmed.hasPrefix("#"),
                  let eq = rawLine.firstIndex(of: "=") else { continue }
            keys.insert(rawLine[..<eq]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'")))
        }
        return keys
    }

    private static func codexProjectSectionKeys(toml: String, projectRoot: String) -> Set<String> {
        Set(codexProjectSectionValues(toml: toml, projectRoot: projectRoot).keys)
    }

    private static func codexProjectSectionValues(toml: String, projectRoot: String) -> [String: String] {
        let target = Project.canonicalize(projectRoot)
        var values: [String: String] = [:]
        var inTargetProject = false

        for rawLine in toml.components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                guard let section = tomlSectionName(from: trimmed),
                      let project = codexProjectPath(fromSection: section) else {
                    inTargetProject = false
                    continue
                }
                inTargetProject = Project.canonicalize(project) == target
                continue
            }

            guard inTargetProject,
                  !trimmed.isEmpty,
                  !trimmed.hasPrefix("#"),
                  let eq = rawLine.firstIndex(of: "=") else { continue }
            let key = rawLine[..<eq]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            let valueAndComment = String(rawLine[rawLine.index(after: eq)...])
            let parts = splitTOMLValueAndComment(valueAndComment)
            if let value = parseTOMLStringLiteral(parts.value.trimmingCharacters(in: .whitespaces)) {
                values[key] = value
            }
        }

        return values
    }

    private static func setCodexProjectTrust(toml: String, projectRoot: String, trustLevel: String) -> String? {
        let lines = toml.components(separatedBy: "\n")
        var targetStart: Int?
        var targetEnd = lines.count
        let target = Project.canonicalize(projectRoot)

        for (index, rawLine) in lines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if targetStart != nil {
                if trimmed.hasPrefix("[") {
                    targetEnd = index
                    break
                }
            }
            guard trimmed.hasPrefix("["),
                  let section = tomlSectionName(from: trimmed),
                  let project = codexProjectPath(fromSection: section) else { continue }
            if Project.canonicalize(project) == target {
                targetStart = index
            }
        }

        var updated = lines
        if let targetStart {
            for index in (targetStart + 1)..<targetEnd {
                let line = updated[index]
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty,
                      !trimmed.hasPrefix("#"),
                      let eq = line.firstIndex(of: "=") else { continue }
                let key = line[..<eq]
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                guard key == "trust_level" else { continue }
                let valueAndComment = String(line[line.index(after: eq)...])
                let parts = splitTOMLValueAndComment(valueAndComment)
                if parseTOMLStringLiteral(parts.value.trimmingCharacters(in: .whitespaces)) == trustLevel {
                    return nil
                }
                let prefix = line[..<line.index(after: eq)]
                let spacing = valueAndComment.prefix { $0 == " " || $0 == "\t" }
                updated[index] = "\(prefix)\(spacing)\(tomlStr(trustLevel))\(parts.comment)"
                return updated.joined(separator: "\n")
            }

            updated.insert("trust_level = \(tomlStr(trustLevel))", at: targetStart + 1)
            return updated.joined(separator: "\n")
        }

        var output = toml
        if !output.isEmpty && !output.hasSuffix("\n") {
            output += "\n"
        }
        if !output.isEmpty {
            output += "\n"
        }
        output += "[projects.\(tomlStr(projectRoot))]\ntrust_level = \(tomlStr(trustLevel))\n"
        return output
    }

    private static func codexProjectPath(fromSection section: String) -> String? {
        let segments = tomlSectionSegments(section)
        guard segments.count == 2, segments[0] == "projects" else { return nil }
        return segments[1]
    }

    private static func tomlSectionName(from header: String) -> String? {
        let value = splitTOMLValueAndComment(header).value
            .trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("[["),
           value.hasSuffix("]]"),
           value.count > 4 {
            return String(value.dropFirst(2).dropLast(2))
                .trimmingCharacters(in: .whitespaces)
        }
        if value.hasPrefix("["),
           value.hasSuffix("]"),
           value.count > 2 {
            return String(value.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func tomlSectionSegments(_ section: String) -> [String] {
        var segments: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escaped = false

        func appendSegment() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                segments.append(parseTOMLStringLiteral(trimmed) ?? trimmed)
            }
            current = ""
        }

        for ch in section {
            if escaped {
                current.append(ch)
                escaped = false
                continue
            }
            if inDouble && ch == "\\" {
                current.append(ch)
                escaped = true
                continue
            }
            if ch == "\"", !inSingle {
                current.append(ch)
                inDouble.toggle()
                continue
            }
            if ch == "'", !inDouble {
                current.append(ch)
                inSingle.toggle()
                continue
            }
            if ch == ".", !inSingle, !inDouble {
                appendSegment()
            } else {
                current.append(ch)
            }
        }
        appendSegment()
        return segments
    }

    private struct CodexSkillConfigSection {
        let start: Int
        let end: Int
        let resolvedPath: String
        let enabled: Bool?
    }

    private static func codexSkillConfigSections(
        in lines: [String],
        configPath: String
    ) -> [CodexSkillConfigSection] {
        var sections: [CodexSkillConfigSection] = []
        var start: Int?
        var rawPath: String?
        var enabled: Bool?

        func flush(end: Int) {
            guard let start, let rawPath else { return }
            sections.append(.init(start: start, end: end, resolvedPath: resolveCodexSkillPath(rawPath, configPath: configPath), enabled: enabled))
        }

        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[[") {
                flush(end: index)
                start = isCodexSkillConfigArrayTable(line) ? index : nil
                rawPath = nil
                enabled = nil
                continue
            }
            guard start != nil, let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            let rawValue = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if key == "path", let parsed = parseTomlVal(rawValue) as? String {
                rawPath = parsed
            } else if key == "enabled", let parsed = parseTomlVal(rawValue) as? Bool {
                enabled = parsed
            }
        }
        flush(end: lines.count)
        return sections
    }

    private static func isCodexSkillConfigArrayTable(_ line: String) -> Bool {
        guard line.hasPrefix("[["),
              let section = tomlSectionName(from: line) else { return false }
        return tomlSectionSegments(section) == ["skills", "config"]
    }

    private static func resolveCodexSkillPath(_ rawPath: String, configPath: String) -> String {
        let expanded = (rawPath as NSString).expandingTildeInPath
        let absolute: String
        if expanded.hasPrefix("/") {
            absolute = expanded
        } else {
            let base = (configPath as NSString).deletingLastPathComponent
            absolute = (base as NSString).appendingPathComponent(expanded)
        }
        if (absolute as NSString).lastPathComponent == "SKILL.md" {
            return absolute
        }
        return (absolute as NSString).appendingPathComponent("SKILL.md")
    }

    /// Parse all [<tableKey>.*] sections from TOML text into a [name: fields] dict.
    private static func parseTomlSections(
        _ toml: String,
        tableKey: String
    ) -> [String: [String: Any]] {
        var result: [String: [String: Any]] = [:]
        var currentName: String? = nil
        var currentSubtable: String? = nil
        var currentFields: [String: Any] = [:]

        func flush() {
            guard let name = currentName, !currentFields.isEmpty else { return }
            if let subtable = currentSubtable {
                var server = result[name] ?? [:]
                var nested = server[subtable] as? [String: Any] ?? [:]
                for (key, value) in currentFields {
                    nested[key] = value
                }
                server[subtable] = nested
                result[name] = server
            } else {
                var server = result[name] ?? [:]
                for (key, value) in currentFields {
                    server[key] = value
                }
                result[name] = server
            }
        }

        for line in toml.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty || t.hasPrefix("#") { continue }

            if t.hasPrefix("[") && !t.hasPrefix("[[") {
                flush()
                currentName = nil
                currentSubtable = nil
                currentFields = [:]
                if let inner = tomlSectionName(from: t),
                   let identity = tomlServerSectionIdentity(inner, tableKey: tableKey) {
                    currentName = identity.name
                    currentSubtable = identity.nested
                }
                continue
            }

            guard currentName != nil else { continue }

            if let eqIdx = t.firstIndex(of: "=") {
                let k = String(t[t.startIndex..<eqIdx]).trimmingCharacters(in: .whitespaces)
                let v = splitTOMLValueAndComment(String(t[t.index(after: eqIdx)...]))
                    .value
                    .trimmingCharacters(in: .whitespaces)
                if !k.isEmpty, let parsed = parseTomlVal(v) {
                    let keySegments = tomlSectionSegments(k)
                    if currentSubtable == nil,
                       keySegments.count >= 2,
                       ["env", "headers", "http_headers", "env_http_headers"].contains(keySegments[0]) {
                        var nested = currentFields[keySegments[0]] as? [String: String] ?? [:]
                        nested[keySegments.dropFirst().joined(separator: ".")] = "\(parsed)"
                        currentFields[keySegments[0]] = nested
                    } else {
                        currentFields[keySegments.joined(separator: ".")] = parsed
                    }
                }
            }
        }

        flush()
        return result
    }

    private static func tomlServerSectionIdentity(
        _ section: String,
        tableKey: String
    ) -> (name: String, nested: String?)? {
        let segments = tomlSectionSegments(section)
        guard segments.count >= 2,
              segments[0] == tableKey,
              !segments[1].isEmpty else { return nil }
        let nested = segments.count > 2 ? segments.dropFirst(2).joined(separator: ".") : nil
        return (segments[1], nested)
    }

    private static func parseTomlVal(_ s: String) -> Any? {
        if s == "true"  { return true  }
        if s == "false" { return false }
        if let n = Int(s) { return n }
        if let n = Double(s), n.isFinite { return n }
        if let string = parseTOMLStringLiteral(s) { return string }

        if s.hasPrefix("\"") {
            var r = ""
            var i = s.index(after: s.startIndex)
            while i < s.endIndex {
                let c = s[i]
                if c == "\\" {
                    let nx = s.index(after: i)
                    if nx < s.endIndex {
                        switch s[nx] {
                        case "\"": r.append("\"")
                        case "\\": r.append("\\")
                        case "n":  r.append("\n")
                        case "t":  r.append("\t")
                        default:   r.append(s[nx])
                        }
                        i = s.index(after: nx)
                    } else { i = s.index(after: i) }
                } else if c == "\"" { break }
                else { r.append(c); i = s.index(after: i) }
            }
            return r
        }

        if s.hasPrefix("[") && s.hasSuffix("]") {
            let values = parseTomlArray(String(s.dropFirst().dropLast()))
            let strings = values.compactMap { $0 as? String }
            return strings.count == values.count ? strings : values
        }
        if s.hasPrefix("{") && s.hasSuffix("}") {
            return parseTomlInlineTable(String(s.dropFirst().dropLast()))
        }
        return nil
    }

    private static func parseTomlArray(_ s: String) -> [Any] {
        splitTopLevelTomlItems(s).compactMap { item in
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return parseTomlVal(trimmed) ?? trimmed
        }
    }

    private static func splitTopLevelTomlItems(_ s: String) -> [String] {
        var items: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escaped = false
        var braceDepth = 0
        var bracketDepth = 0

        for ch in s {
            if escaped {
                current.append(ch)
                escaped = false
                continue
            }
            if inDouble && ch == "\\" {
                current.append(ch)
                escaped = true
                continue
            }
            if ch == "'", !inDouble {
                current.append(ch)
                inSingle.toggle()
                continue
            }
            if ch == "\"", !inSingle {
                current.append(ch)
                inDouble.toggle()
                continue
            }
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
        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(current)
        }
        return items
    }

    private static func parseTomlInlineTable(_ s: String) -> [String: String] {
        var result: [String: String] = [:]
        var rem = s.trimmingCharacters(in: .whitespaces)
        while !rem.isEmpty {
            guard let eqIdx = rem.firstIndex(of: "=") else { break }
            var key = String(rem[rem.startIndex..<eqIdx]).trimmingCharacters(in: .whitespaces)
            if key.hasPrefix("\"") && key.hasSuffix("\"") && key.count >= 2 {
                key = String(key.dropFirst().dropLast())
            }
            rem = String(rem[rem.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
            if rem.hasPrefix("\"") {
                var val = ""
                var i = rem.index(after: rem.startIndex)
                var found = false
                while i < rem.endIndex {
                    let c = rem[i]
                    if c == "\\" {
                        let nx = rem.index(after: i)
                        if nx < rem.endIndex { val.append(rem[nx]); i = rem.index(after: nx) }
                        else { i = rem.index(after: i) }
                    } else if c == "\"" { i = rem.index(after: i); found = true; break }
                    else { val.append(c); i = rem.index(after: i) }
                }
                if found {
                    result[key] = val
                    rem = String(rem[i...]).trimmingCharacters(in: .whitespaces)
                    if rem.hasPrefix(",") { rem = String(rem.dropFirst()).trimmingCharacters(in: .whitespaces) }
                } else { break }
            } else {
                if let ci = rem.firstIndex(of: ",") {
                    result[key] = String(rem[rem.startIndex..<ci]).trimmingCharacters(in: .whitespaces)
                    rem = String(rem[rem.index(after: ci)...]).trimmingCharacters(in: .whitespaces)
                } else {
                    result[key] = rem.trimmingCharacters(in: .whitespaces)
                    break
                }
            }
        }
        return result
    }

    /// Backup + atomic write for a TOML file (string-based, not JSON serialisation).
    private static func tomlBackupAndWrite(path: String, existing: String, updated: String) throws {
        try backupAndWriteText(path: path, existing: existing, updated: updated)
    }

    /// Backup + atomic write for text files whose approved preview is already fully rendered.
    private static func backupAndWriteText(path: String, existing: String, updated: String) throws {
        let fm = FileManager.default
        ensureParent(of: path)
        if fm.fileExists(atPath: path) {
            let stamp = backupStamp()
            try? existing.data(using: .utf8)?.write(
                to: URL(fileURLWithPath: "\(path).bak.\(stamp)"), options: [.atomic])
            pruneBackups(forPath: path)
            let legacy = path + ".bak"
            if fm.fileExists(atPath: legacy) { try? fm.removeItem(atPath: legacy) }
        }
        guard let data = updated.data(using: .utf8) else {
            throw WriteError.writeFailure("Failed to encode config as UTF-8")
        }
        do {
            try data.write(to: URL(fileURLWithPath: path), options: [.atomic])
        } catch {
            throw WriteError.writeFailure(error.localizedDescription)
        }
    }

    // MARK: - JSONC comment stripper (duplicated from reader to avoid coupling)

    static func stripJsonComments(_ src: String) -> String {
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
                                if n2 < src.endIndex && src[n2] == "/" {
                                    i = src.index(after: n2); break
                                }
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
}

// MARK: - Project-scope MCP toggle (used by LiveModeView)

extension ConfigWriter {

    /// Toggle a server in the project's `.mcp.json` between enabled and disabled.
    /// Returns `true` on success, `false` if the file doesn't exist or the server wasn't found.
    @discardableResult
    static func toggleProjectServer(projectPath: String, name: String, enable: Bool) -> Bool {
        let jsonPath = (projectPath as NSString).appendingPathComponent(".mcp.json")
        guard FileManager.default.fileExists(atPath: jsonPath) else { return false }

        var root = loadJsonRoot(path: jsonPath)
        let key = "mcpServers"
        let disabledKey = "\(key)_disabled"

        if enable {
            // Move from disabled → enabled
            guard var disabled = root[disabledKey] as? [String: Any],
                  let config   = disabled[name] else { return false }
            disabled.removeValue(forKey: name)
            if disabled.isEmpty { root.removeValue(forKey: disabledKey) }
            else { root[disabledKey] = disabled }
            var enabled = root[key] as? [String: Any] ?? [:]
            enabled[name] = config
            root[key] = enabled
        } else {
            // Move from enabled → disabled
            guard var enabled = root[key] as? [String: Any],
                  let config  = enabled[name] else { return false }
            enabled.removeValue(forKey: name)
            root[key] = enabled
            var disabled = root[disabledKey] as? [String: Any] ?? [:]
            disabled[name] = config
            root[disabledKey] = disabled
        }

        do {
            try backupAndWrite(path: jsonPath, root: root)
            return true
        } catch {
            return false
        }
    }
}
