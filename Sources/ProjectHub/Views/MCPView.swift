import SwiftUI
import AppKit

// MARK: - MCP sub-tab (full CRUD for project-scope configs)

struct MCPView: View {
    let project: Project
    @EnvironmentObject var mcpStore: MCPStore

    @State private var showImport = false
    @State private var editingServer: (toolID: String, name: String)? = nil
    @State private var confirmDelete: (toolID: String, name: String)? = nil
    @State private var reloadTick = 0

    private let projectScopedToolIDs = ["claude-code", "cursor", "codex", "vscode", "roo"]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            let allEmpty = allServers.isEmpty
            if allEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(projectScopedToolIDs, id: \.self) { toolID in
                            let servers = projectServers(for: toolID)
                            if !servers.isEmpty {
                                toolSection(toolID: toolID, servers: servers)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }
        }
        .id(reloadTick)
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
                    _ = mcpStore.replaceServerConfig(
                        toolID: d.toolID,
                        scope: .project,
                        projectRoot: project.path,
                        name: d.name,
                        config: [:]
                    )
                    // Actually use removeServer
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
    }

    private var editingBinding: Binding<IdentifiableMCPServer?> {
        Binding(
            get: { editingServer.map { IdentifiableMCPServer(toolID: $0.toolID, name: $0.name) } },
            set: { if $0 == nil { editingServer = nil } }
        )
    }

    // MARK: - Data helpers

    private func projectServers(for toolID: String) -> [(name: String, detail: String, disabled: Bool)] {
        let servers = ConfigWriter.readAllServers(toolID: toolID, scope: .project, projectRoot: project.path)
        return servers.map { (name: $0.key, detail: serverDetail($0.value), disabled: false) }
            .sorted { $0.name < $1.name }
    }

    private var allServers: [(toolID: String, name: String)] {
        projectScopedToolIDs.flatMap { toolID in
            ConfigWriter.readAllServers(toolID: toolID, scope: .project, projectRoot: project.path)
                .keys.map { (toolID: toolID, name: $0) }
        }
    }

    private func serverDetail(_ cfg: [String: Any]) -> String {
        if let url = cfg["url"] as? String { return url }
        let cmd  = cfg["command"] as? String ?? ""
        let args = cfg["args"] as? [String] ?? []
        return ([cmd] + args).filter { !$0.isEmpty }.joined(separator: " ")
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
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(ContentView.headerGrad)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Tool section

    private func toolSection(toolID: String, servers: [(name: String, detail: String, disabled: Bool)]) -> some View {
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
                    Text(configPath)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
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
                ForEach(servers, id: \.name) { server in
                    serverRow(server: server, toolID: toolID, color: c)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(c.opacity(0.20), lineWidth: 1))
    }

    private func serverRow(server: (name: String, detail: String, disabled: Bool), toolID: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color.opacity(0.6))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.system(size: 12, weight: .semibold))
                if !server.detail.isEmpty {
                    Text(server.detail)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(ContentView.headerGrad)
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
