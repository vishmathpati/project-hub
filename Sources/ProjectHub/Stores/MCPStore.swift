import Foundation
import Combine

// MARK: - Observable store for global MCP servers across all AI tools.

@MainActor
final class MCPStore: ObservableObject {
    @Published var tools:      [ToolSummary] = []
    @Published var isLoading:  Bool          = false
    @Published var isVerifyingHealth: Bool   = false
    @Published private var verifiedHealthReports: [String: MCPHealthReport] = [:]
    @Published private var evaluatedHealthReports: [String: MCPHealthReport] = [:]
    @Published var searchText: String        = ""

    // Only detected tools, in display order. Hidden tools excluded from UI.
    var detectedTools: [ToolSummary] {
        tools.filter { PRIMARY_TOOL_IDS.contains($0.toolID) }
    }

    // Unique server names across all detected tools
    var allServerNames: [String] {
        let detected = detectedTools
        return Array(Set(detected.flatMap { $0.servers.map { $0.name } }))
            .sorted { a, b in
                let ac = detected.filter { t in t.servers.contains { $0.name == a } }.count
                let bc = detected.filter { t in t.servers.contains { $0.name == b } }.count
                if ac != bc { return ac > bc }
                return a.lowercased() < b.lowercased()
            }
    }

    var serverCount: Int { allServerNames.count }

    var healthReports: [MCPHealthReport] {
        detectedTools.flatMap { tool in
            tool.servers.map { health(for: $0, toolID: tool.toolID) }
        }
    }

    var healthSummary: [MCPHealthStatus: Int] {
        MCPHealthChecker.summarize(healthReports)
    }

    func health(for server: ServerEntry, toolID: String) -> MCPHealthReport {
        let key = healthKey(toolID: toolID, serverID: server.id)
        if let verified = verifiedHealthReports[key] {
            return verified
        }
        if let evaluated = evaluatedHealthReports[key] {
            return evaluated
        }
        let tool = tools.first(where: { $0.toolID == toolID })
        let report = MCPHealthChecker.evaluate(
            server: server,
            toolID: toolID,
            configPath: configPath(for: server, tool: tool)
        )
        evaluatedHealthReports[key] = report
        return report
    }

    func verifyHealth() {
        guard !isVerifyingHealth else { return }
        let snapshot = detectedTools
        guard !snapshot.isEmpty else { return }
        isVerifyingHealth = true
        verifiedHealthReports = [:]

        Task {
            for tool in snapshot {
                for server in tool.servers {
                    let report: MCPHealthReport
                    if self.shouldUseConservativeVerify(for: server, toolID: tool.toolID) {
                        report = MCPHealthReport(
                            toolID: tool.toolID,
                            serverName: server.name,
                            status: .unknown,
                            summary: "Runtime managed by \(server.sourceLabel ?? "owning app")",
                            fixHint: "Verify this server in the owning app. Project Hub does not launch app-managed extension commands."
                        )
                    } else {
                        report = await MCPHealthChecker.verify(
                            server: server,
                            toolID: tool.toolID,
                            configPath: self.configPath(for: server, tool: tool)
                        )
                    }
                    await MainActor.run {
                        self.verifiedHealthReports[self.healthKey(toolID: tool.toolID, serverID: server.id)] = report
                    }
                }
            }
            await MainActor.run {
                self.isVerifyingHealth = false
            }
        }
    }

    func matches(_ name: String) -> Bool {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return true }
        return name.lowercased().contains(q)
    }

    func refresh(force: Bool = true) {
        guard !isLoading else { return }
        if !force && !tools.isEmpty { return }
        let showSpinner = tools.isEmpty
        if showSpinner { isLoading = true }
        Task.detached(priority: .utility) {
            let result = ConfigReader.shared.readAllTools()
            await MainActor.run {
                if result != self.tools {
                    self.tools = result
                    self.verifiedHealthReports = [:]
                    self.evaluatedHealthReports = [:]
                }
                self.isLoading = false
            }
        }
    }

    // MARK: - Lookups

    func toolsHosting(name: String) -> [String] {
        ALL_TOOL_META
            .map { $0.id }
            .filter { id in
                tools.first(where: { $0.toolID == id })?.servers.contains(where: { $0.name == name }) == true
            }
    }

    var nativeWritableDetectedToolIDs: [String] {
        detectedTools
            .map { $0.toolID }
            .filter { ConfigWriter.supportsNativeWrite(toolID: $0) }
    }

    // MARK: - Env updates

    @discardableResult
    func updateServerEnv(
        name: String,
        env: [String: String],
        across toolIDs: [String]
    ) -> (successes: [String], failures: [(toolID: String, message: String)]) {
        var successes: [String] = []
        var failures:  [(String, String)] = []
        for toolID in toolIDs {
            if hasOnlyReadOnlyMatches(toolID: toolID, name: name) {
                failures.append((toolID, "Read-only MCP source"))
                continue
            }
            guard ConfigWriter.supportsNativeWrite(toolID: toolID) else {
                failures.append((toolID, "Format not supported"))
                continue
            }
            do {
                try ConfigWriter.updateServerEnv(toolID: toolID, name: name, env: env)
                successes.append(toolID)
            } catch {
                failures.append((toolID, error.localizedDescription))
            }
        }
        refresh()
        return (successes, failures)
    }

    @discardableResult
    func updateServerCredentials(
        name: String,
        values: [String: String],
        requirements: [ImportCredentialRequirement],
        across toolIDs: [String]
    ) -> (successes: [String], failures: [(toolID: String, message: String)]) {
        var successes: [String] = []
        var failures:  [(String, String)] = []
        for toolID in toolIDs {
            if hasOnlyReadOnlyMatches(toolID: toolID, name: name) {
                failures.append((toolID, "Read-only MCP source"))
                continue
            }
            guard ConfigWriter.supportsNativeWrite(toolID: toolID) else {
                failures.append((toolID, "Format not supported"))
                continue
            }
            do {
                try ConfigWriter.updateServerCredentials(
                    toolID: toolID,
                    name: name,
                    values: values,
                    requirements: requirements
                )
                successes.append(toolID)
            } catch {
                failures.append((toolID, error.localizedDescription))
            }
        }
        refresh()
        return (successes, failures)
    }

    // MARK: - Remove

    @discardableResult
    func removeServer(toolID: String, name: String) -> (ok: Bool, error: String?) {
        if hasOnlyReadOnlyMatches(toolID: toolID, name: name) {
            return (false, "This MCP source is read-only here. Use the Compatibility tab or the owning app/config to change it.")
        }
        guard ConfigWriter.supportsNativeWrite(toolID: toolID) else {
            return (false, "This app's config format (TOML/YAML) isn't supported yet. Remove it manually.")
        }
        do {
            try ConfigWriter.removeServer(toolID: toolID, name: name)
            refresh()
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    @discardableResult
    func removeServerEverywhere(
        name: String
    ) -> (successes: [String], failures: [(toolID: String, message: String)]) {
        var successes: [String] = []
        var failures:  [(String, String)] = []

        let hosts = toolsHosting(name: name)
        for toolID in hosts {
            if hasOnlyReadOnlyMatches(toolID: toolID, name: name) {
                failures.append((toolID, "Read-only MCP source"))
                continue
            }
            guard ConfigWriter.supportsNativeWrite(toolID: toolID) else {
                failures.append((toolID, "Unsupported format — remove manually"))
                continue
            }
            do {
                try ConfigWriter.removeServer(toolID: toolID, name: name)
                successes.append(toolID)
            } catch {
                failures.append((toolID, error.localizedDescription))
            }
        }
        refresh()
        return (successes, failures)
    }

    // MARK: - Copy

    @discardableResult
    func copyServer(
        name: String,
        from sourceToolID: String,
        to targetToolIDs: [String]
    ) -> (successes: [String], failures: [(toolID: String, message: String)]) {
        var successes: [String] = []
        var failures:  [(String, String)] = []

        if hasOnlyReadOnlyMatches(toolID: sourceToolID, name: name) {
            return ([], [(sourceToolID, "This MCP source is read-only here. Use Compatibility to inspect it or import from a writable config.")])
        }

        guard let config = ConfigWriter.readServer(toolID: sourceToolID, name: name) else {
            return ([], [(sourceToolID, "Couldn't read '\(name)' from \(sourceToolID)")])
        }

        for toolID in targetToolIDs {
            guard ConfigWriter.supportsNativeWrite(toolID: toolID) else {
                failures.append((toolID, "Unsupported format — paste manually"))
                continue
            }
            do {
                try ConfigWriter.writeServer(toolID: toolID, name: name, config: config)
                successes.append(toolID)
            } catch {
                failures.append((toolID, error.localizedDescription))
            }
        }
        refresh()
        return (successes, failures)
    }

    // MARK: - Edit (replace entire config)

    @discardableResult
    func replaceServerConfig(
        toolID: String,
        name: String,
        config: [String: Any]
    ) -> (ok: Bool, error: String?) {
        replaceServerConfig(toolID: toolID, scope: .user, projectRoot: nil, name: name, config: config)
    }

    @discardableResult
    func replaceServerConfig(
        toolID: String,
        scope: ConfigScope,
        projectRoot: String?,
        name: String,
        config: [String: Any]
    ) -> (ok: Bool, error: String?) {
        if scope == .user && hasOnlyReadOnlyMatches(toolID: toolID, name: name) {
            return (false, "This MCP source is read-only here. Use the Compatibility tab or the owning app/config to change it.")
        }
        guard ConfigWriter.supportsNativeWrite(toolID: toolID) else {
            return (false, "This app's config format isn't supported yet.")
        }
        do {
            try ConfigWriter.writeServer(toolID: toolID, scope: scope, projectRoot: projectRoot, name: name, config: config)
            if scope == .user { refresh() }
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    // MARK: - Toggle disabled

    @discardableResult
    func toggleServerDisabled(toolID: String, name: String, currently disabled: Bool) -> (ok: Bool, error: String?) {
        toggleServerDisabled(toolID: toolID, scope: .user, projectRoot: nil, name: name, currently: disabled)
    }

    func previewCodexPluginPolicyToggle(
        toolID: String,
        server: ServerEntry,
        currently disabled: Bool
    ) -> CodexPluginMCPPolicyPreview? {
        guard toolID == "codex",
              server.canToggleCodexPluginPolicy,
              let configPath = server.codexPluginPolicyConfigPath,
              let pluginID = server.codexPluginID else {
            return nil
        }
        let enabled = disabled
        let profileName = enabled ? nil : server.codexPluginPolicyProfileName
        guard let preview = ConfigWriter.previewSetCodexPluginMCPServerEnabled(
            configPath: configPath,
            pluginID: pluginID,
            serverName: server.name,
            enabled: enabled,
            profileName: profileName
        ) else {
            return nil
        }
        return CodexPluginMCPPolicyPreview(
            toolID: toolID,
            serverName: server.name,
            configPath: configPath,
            pluginID: pluginID,
            profileName: profileName,
            enabled: enabled,
            before: preview.before,
            after: preview.after
        )
    }

    @discardableResult
    func applyCodexPluginPolicyPreview(_ preview: CodexPluginMCPPolicyPreview) -> (ok: Bool, error: String?) {
        do {
            try ConfigWriter.applyCodexPluginMCPServerEnabledPreview(
                configPath: preview.configPath,
                expectedBefore: preview.before,
                approvedAfter: preview.after
            )
            refresh()
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    @discardableResult
    func toggleServerDisabled(
        toolID: String,
        scope: ConfigScope,
        projectRoot: String?,
        name: String,
        currently disabled: Bool
    ) -> (ok: Bool, error: String?) {
        if scope == .user && hasOnlyReadOnlyMatches(toolID: toolID, name: name) {
            return (false, "This MCP source is read-only here. Use the Compatibility tab or the owning app/config to change it.")
        }
        guard ConfigWriter.supportsNativeWrite(toolID: toolID) else {
            return (false, "This app's config format doesn't support toggling.")
        }
        do {
            if disabled {
                try ConfigWriter.setServerEnabled(
                    toolID: toolID,
                    scope: scope,
                    projectRoot: projectRoot,
                    name: name,
                    enabled: true
                )
            } else {
                try ConfigWriter.setServerEnabled(
                    toolID: toolID,
                    scope: scope,
                    projectRoot: projectRoot,
                    name: name,
                    enabled: false
                )
            }
            if scope == .user { refresh() }
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    // MARK: - Undo

    @discardableResult
    func undoLastChange(toolID: String) -> (ok: Bool, error: String?) {
        guard let spec = ToolSpecs.spec(for: toolID) else {
            return (false, "Unknown tool")
        }
        let ok = ConfigWriter.restoreLatestBackup(forPath: spec.path)
        if ok {
            refresh()
            return (true, nil)
        } else {
            return (false, "No backup to restore.")
        }
    }

    func hasUndoableChange(toolID: String) -> Bool {
        guard let spec = ToolSpecs.spec(for: toolID) else { return false }
        return !ConfigWriter.backups(forPath: spec.path).isEmpty
    }

    private func healthKey(toolID: String, serverName: String) -> String {
        guard let server = tools.first(where: { $0.toolID == toolID })?.servers.first(where: { $0.name == serverName }) else {
            return "\(toolID)/\(serverName)"
        }
        return healthKey(toolID: toolID, serverID: server.id)
    }

    private func healthKey(toolID: String, serverID: String) -> String {
        "\(toolID)/\(serverID)"
    }

    private func configPath(for server: ServerEntry, tool: ToolSummary?) -> String? {
        guard server.isReadOnly,
              let sourcePath = server.sourcePath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !sourcePath.isEmpty else {
            return tool?.configPath
        }
        return sourcePath
    }

    private func shouldUseConservativeVerify(for server: ServerEntry, toolID: String) -> Bool {
        toolID == "claude-desktop"
            && server.isReadOnly
            && server.sourceLabel?.hasPrefix("Claude Desktop extension:") == true
    }

    private func hasOnlyReadOnlyMatches(toolID: String, name: String) -> Bool {
        let matches = tools.first(where: { $0.toolID == toolID })?.servers.filter { $0.name == name } ?? []
        return !matches.isEmpty && matches.allSatisfy(\.isReadOnly)
    }
}
