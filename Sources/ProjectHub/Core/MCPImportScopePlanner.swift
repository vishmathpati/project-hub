import Foundation

enum MCPImportScopePlanner {
    static func toolIsEligible(_ toolID: String, useProjectScope: Bool, servers: [ParsedServer] = []) -> Bool {
        guard ConfigWriter.supportsNativeWrite(toolID: toolID) else { return false }
        if useProjectScope && !ToolSpecs.projectScopedTools.contains(toolID) { return false }
        let scope: ConfigScope = useProjectScope ? .project : .user
        return servers.allSatisfy {
            ConfigWriter.nativeWriteBlocker(toolID: toolID, scope: scope, name: $0.name, config: $0.config) == nil
        }
    }

    static func toolSupportNote(_ toolID: String, useProjectScope: Bool, servers: [ParsedServer] = []) -> String? {
        if !ConfigWriter.supportsNativeWrite(toolID: toolID) {
            return "use CLI"
        }
        if useProjectScope && !ToolSpecs.projectScopedTools.contains(toolID) {
            return "global only"
        }
        let scope: ConfigScope = useProjectScope ? .project : .user
        if let blocker = servers.compactMap({
            ConfigWriter.nativeWriteBlocker(toolID: toolID, scope: scope, name: $0.name, config: $0.config)
        }).first {
            if toolID == "claude-desktop", containsRemoteMCP(servers) {
                return "use Connectors"
            }
            if toolID == "claude-code", scope == .user {
                return "use Claude CLI"
            }
            return blocker
        }
        return nil
    }

    static func eligibleToolIDs(_ toolIDs: [String], useProjectScope: Bool, servers: [ParsedServer] = []) -> [String] {
        toolIDs.filter { toolIsEligible($0, useProjectScope: useProjectScope, servers: servers) }
    }

    static func canImport(
        selectedTools: Set<String>,
        useProjectScope: Bool,
        projectRoot: String?,
        serverNames: [String],
        servers: [ParsedServer] = []
    ) -> Bool {
        !selectedTools.isEmpty
        && (!useProjectScope || projectRoot != nil)
        && selectedTools.allSatisfy { toolIsEligible($0, useProjectScope: useProjectScope, servers: servers) }
        && serverNames.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    static func containsRemoteMCP(_ servers: [ParsedServer]) -> Bool {
        servers.contains { serverIsRemote($0.config) }
    }

    private static func serverIsRemote(_ config: [String: Any]) -> Bool {
        if let url = config["url"] as? String, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        let rawTransport = (config["type"] as? String ?? config["transport"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
        guard let rawTransport, !rawTransport.isEmpty else { return false }
        return !["stdio", "local"].contains(rawTransport)
    }
}
