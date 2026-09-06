import SwiftUI
import AppKit

// MARK: - MCP sub-tab (full CRUD for project-scope configs)

struct MCPView: View {
    let project: Project
    @EnvironmentObject var mcpStore: MCPStore

    @State private var showImport = false
    @State private var editingServer: (toolID: String, name: String)? = nil
    @State private var confirmDelete: (toolID: String, name: String)? = nil
    @State private var pendingToggle: ProjectMCPToggle? = nil
    @State private var toggleError: ProjectMCPError? = nil
    @State private var reloadTick = 0
    @State private var serversByTool: [String: [ProjectMCPServerRow]] = [:]

    private var projectScopedToolIDs: [String] {
        ALL_TOOL_META
            .map(\.id)
            .filter { PRIMARY_TOOL_IDS.contains($0) && ToolSpecs.projectScopedTools.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            if projectScopedToolIDs.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(projectScopedToolIDs, id: \.self) { toolID in
                            toolSection(toolID: toolID, servers: serversByTool[toolID] ?? [])
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }
        }
        .onAppear { reloadProjectServers() }
        .onChange(of: reloadTick) { _, _ in reloadProjectServers() }
        .sheet(isPresented: $showImport) {
            MCPImportSheet(onClose: {
                showImport = false
                reloadTick += 1
            })
            .environmentObject(mcpStore)
            .frame(width: 480)
        }
        .sheet(item: editingBinding) { item in
            MCPEditServerSheet(
                toolID: item.toolID,
                toolLabel: ALL_TOOL_META.first(where: { $0.id == item.toolID })?.label ?? item.toolID,
                serverName: item.name,
                projectRoot: project.path,
                onClose: {
                    editingServer = nil
                    reloadTick += 1
                }
            )
            .environmentObject(mcpStore)
        }
        .alert("Delete server?", isPresented: Binding(
            get: { confirmDelete != nil },
            set: { if !$0 { confirmDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let d = confirmDelete {
                    try? ConfigWriter.removeServer(
                        toolID: d.toolID,
                        scope: .project,
                        projectRoot: project.path,
                        name: d.name
                    )
                    confirmDelete = nil
                    reloadTick += 1
                }
            }
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            if let d = confirmDelete {
                Text("Remove \"\(d.name)\" from \(ALL_TOOL_META.first(where: { $0.id == d.toolID })?.label ?? d.toolID)?")
            }
        }
        .confirmationDialog(
            pendingToggle?.title ?? "Change MCP availability",
            isPresented: Binding(
                get: { pendingToggle != nil },
                set: { if !$0 { pendingToggle = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let item = pendingToggle {
                Button(item.actionLabel) {
                    applyToggle(item)
                    pendingToggle = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let item = pendingToggle {
                Text(item.message)
            }
        }
        .alert(item: $toggleError) { error in
            Alert(
                title: Text("Could not update server"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var editingBinding: Binding<IdentifiableMCPServer?> {
        Binding(
            get: { editingServer.map { IdentifiableMCPServer(toolID: $0.toolID, name: $0.name) } },
            set: { if $0 == nil { editingServer = nil } }
        )
    }

    // MARK: - Data helpers

    private func reloadProjectServers() {
        var next: [String: [ProjectMCPServerRow]] = [:]
        for toolID in projectScopedToolIDs {
            next[toolID] = projectServers(for: toolID)
        }
        serversByTool = next
    }

    private func projectServers(for toolID: String) -> [ProjectMCPServerRow] {
        let claudeApproval = toolID == "claude-code"
            ? MCPReader.claudeCodeProjectMCPApprovalState(projectPath: project.path)
            : MCPReader.ClaudeProjectMCPApprovalState()
        let projectMCPPath = (project.path as NSString).appendingPathComponent(".mcp.json")

        let projectRows = ConfigWriter.readAllServerEntries(toolID: toolID, scope: .project, projectRoot: project.path)
            .map {
                let approvalSources = claudeApproval.disabledSources(for: $0.name)
                return ProjectMCPServerRow(
                    originID: "\(toolID)::project::\($0.name)",
                    toolID: toolID,
                    source: toolID == "claude-code" ? .claudeCode : mcpSource(for: toolID),
                    name: $0.name,
                    detail: $0.detail,
                    sourceLabel: "Project",
                    sourcePathLabel: ToolSpecs.spec(for: toolID, scope: .project, projectRoot: project.path)?.path
                        .replacingOccurrences(of: project.path + "/", with: "") ?? "project MCP config",
                    isReadOnly: false,
                    readOnlyReason: nil,
                    disabled: $0.isDisabled || claudeApproval.disabled.contains($0.name),
                    disabledByConfig: $0.isDisabled,
                    disabledByClaudeApproval: claudeApproval.disabled.contains($0.name),
                    claudeApprovalDisableSources: approvalSources,
                    canResolveClaudeApprovalFromProjectMCP: approvalSources.contains(projectMCPPath)
                )
            }

        let localRows = localClaudeProjectRows(for: toolID)

        return (projectRows + localRows)
            .sorted {
                if $0.name != $1.name { return $0.name < $1.name }
                return $0.originID < $1.originID
            }
    }

    private var allServers: [(toolID: String, name: String)] {
        projectScopedToolIDs.flatMap { toolID in
            (serversByTool[toolID] ?? []).map { (toolID: toolID, name: $0.name) }
        }
    }

    private func localClaudeProjectRows(for toolID: String) -> [ProjectMCPServerRow] {
        guard toolID == "claude-code" else { return [] }
        return MCPReader.fromClaudeCodeLocalProjectState(project.path).map { server in
            ProjectMCPServerRow(
                originID: "claude-code::local-private::\(server.name)",
                toolID: "claude-code",
                source: server.source,
                name: server.name,
                detail: server.detail,
                sourceLabel: "Private",
                sourcePathLabel: server.source.configRelativePath,
                isReadOnly: true,
                readOnlyReason: "Stored by Claude Code as local project state. Use Claude Code to edit this private scope.",
                disabled: server.isDisabled,
                disabledByConfig: false,
                disabledByClaudeApproval: false,
                claudeApprovalDisableSources: [],
                canResolveClaudeApprovalFromProjectMCP: false
            )
        }
    }

    private func mcpSource(for toolID: String) -> MCPConfigSource {
        switch toolID {
        case "claude-code": return .claudeCode
        case "codex": return .codex
        case "cursor": return .cursor
        case "vscode": return .vscode
        case "opencode": return .opencode
        case "antigravity": return .antigravity
        case "pi": return .pi
        case "command-code": return .commandCode
        case "grok": return .grok
        default: return .claudeCode
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            let count = allServers.count
            Text("\(count) MCP server\(count == 1 ? "" : "s") in project")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting(
                    [URL(fileURLWithPath: project.path)]
                )
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                    Text("Finder")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Button {
                showImport = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11, weight: .medium))
                    Text("Import")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(HubTheme.onAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(HubTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Tool section

    private func toolSection(toolID: String, servers: [ProjectMCPServerRow]) -> some View {
        let c = ToolPalette.color(for: toolID)
        let label = ALL_TOOL_META.first(where: { $0.id == toolID })?.label ?? toolID
        let configPath = ToolSpecs.spec(for: toolID, scope: .project, projectRoot: project.path)?.path
            .replacingOccurrences(of: project.path + "/", with: "") ?? ""

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(c.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: ToolPalette.icon(for: toolID))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(c)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                    if !configPath.isEmpty {
                        Text("project config")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text("\(servers.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(c)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(c.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(10)

            Divider().opacity(0.5)

            VStack(spacing: 1) {
                if servers.isEmpty {
                    Text("No project servers yet")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(servers) { server in
                        serverRow(server: server, toolID: toolID, color: c)
                    }
                }
            }
        }
        .background(HubTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(c.opacity(0.20), lineWidth: 1))
    }

    private func serverRow(server: ProjectMCPServerRow, toolID: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(server.disabled ? Color.secondary.opacity(0.55) : color.opacity(0.6))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.system(size: 12, weight: .semibold))
                if server.disabled {
                    Text("Disabled")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Text("\(server.sourceLabel)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if !server.detail.isEmpty, !server.detail.hasPrefix("/"), !server.detail.hasPrefix("~") {
                    Text(server.detail)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if server.isReadOnly {
                Image(systemName: "lock")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .help(server.readOnlyReason ?? "Read-only MCP source")
            } else {
                Button {
                    pendingToggle = ProjectMCPToggle(server: server)
                } label: {
                    Image(systemName: server.disabled ? "eye" : "eye.slash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(server.enableBlockedByExternalClaudeApproval)
                .help(server.enableBlockedByExternalClaudeApproval ? server.externalClaudeApprovalMessage : (server.disabled ? "Enable in project" : "Disable in project"))

                Button {
                    editingServer = (toolID: toolID, name: server.name)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Edit")

                Button {
                    confirmDelete = (toolID: toolID, name: server.name)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Remove from project")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func applyToggle(_ item: ProjectMCPToggle) {
        guard !item.server.isReadOnly else {
            toggleError = ProjectMCPError(message: item.server.readOnlyReason ?? "This MCP source is read-only.")
            return
        }

        if item.enable, item.server.disabledByClaudeApproval {
            guard item.server.canResolveClaudeApprovalFromProjectMCP else {
                toggleError = ProjectMCPError(message: item.server.externalClaudeApprovalMessage)
                return
            }
            let path = (project.path as NSString).appendingPathComponent(".mcp.json")
            do {
                try ConfigWriter.resolveClaudeMCPApprovalConflict(path: path, serverNames: [item.server.name])
            } catch {
                toggleError = ProjectMCPError(message: error.localizedDescription)
                return
            }
        }

        if !item.enable || item.server.disabledByConfig {
            let result = mcpStore.toggleServerDisabled(
                toolID: item.server.toolID,
                scope: .project,
                projectRoot: project.path,
                name: item.server.name,
                currently: item.server.disabledByConfig
            )
            guard result.ok else {
                toggleError = ProjectMCPError(message: result.error ?? "Unknown error")
                return
            }
        }

        reloadTick += 1
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 26))
                .foregroundColor(.secondary)
            Text("No MCP servers in this project")
                .font(.system(size: 14, weight: .semibold))
            Button {
                showImport = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import a server")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(HubTheme.onAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(HubTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            Text("Or add via CLI:\n`claude mcp add --scope project myserver npx -y myserver`")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}

// MARK: - Identifiable helper

private struct IdentifiableMCPServer: Identifiable {
    let id = UUID()
    let toolID: String
    let name: String
}

private struct ProjectMCPServerRow: Identifiable {
    var id: String { originID }
    let originID: String
    let toolID: String
    let source: MCPConfigSource
    let name: String
    let detail: String
    let sourceLabel: String
    let sourcePathLabel: String
    let isReadOnly: Bool
    let readOnlyReason: String?
    let disabled: Bool
    let disabledByConfig: Bool
    let disabledByClaudeApproval: Bool
    let claudeApprovalDisableSources: [String]
    let canResolveClaudeApprovalFromProjectMCP: Bool

    var enableBlockedByExternalClaudeApproval: Bool {
        disabled && disabledByClaudeApproval && !canResolveClaudeApprovalFromProjectMCP
    }

    var externalClaudeApprovalMessage: String {
        let sources = claudeApprovalDisableSources.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")
        let suffix = sources.isEmpty ? "Claude settings" : sources
        return "Disabled by \(suffix). Review that Claude settings source before enabling."
    }
}

private struct ProjectMCPToggle: Identifiable {
    var id: String { "\(server.id)::\(enable ? "enable" : "disable")" }
    let server: ProjectMCPServerRow
    let enable: Bool

    init(server: ProjectMCPServerRow) {
        self.server = server
        self.enable = server.disabled
    }

    var title: String {
        enable ? "Enable MCP server?" : "Disable MCP server?"
    }

    var actionLabel: String {
        enable ? "Enable \(server.name)" : "Disable \(server.name)"
    }

    var message: String {
        let relativePath: String
        switch server.toolID {
        case "claude-code":
            relativePath = ".mcp.json"
        case "codex":
            relativePath = ".codex/config.toml"
        default:
            relativePath = "project MCP config"
        }

        if enable, server.disabledByClaudeApproval, !server.disabledByConfig {
            if !server.canResolveClaudeApprovalFromProjectMCP {
                return "This server is disabled by Claude settings outside .mcp.json. Review \(server.claudeApprovalDisableSources.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")) before enabling it."
            }
            return "This removes \(server.name) from disabledMcpjsonServers in \(relativePath). Packages, credentials, and other servers stay unchanged."
        }

        let verb = enable
            ? "moves \(server.name) back to the active project MCP set"
            : "moves \(server.name) to the disabled project MCP set"
        return "This \(verb) in \(relativePath). Packages, credentials, and other servers stay unchanged."
    }
}

private struct ProjectMCPError: Identifiable {
    let id = UUID()
    let message: String
}
