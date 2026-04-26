import SwiftUI
import AppKit

// MARK: - Global MCP view: all detected AI tools and their servers

struct GlobalMCPView: View {
    @EnvironmentObject var mcpStore: MCPStore

    @State private var showingImport = false
    @State private var editingServer: (toolID: String, name: String)? = nil
    @State private var copyingServer: (toolID: String, toolLabel: String, name: String)? = nil
    @State private var confirmDelete: (toolID: String, name: String)? = nil

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()

            if mcpStore.isLoading && mcpStore.tools.isEmpty {
                loadingView
            } else if mcpStore.detectedTools.isEmpty {
                emptyState
            } else {
                mainContent
            }
        }
        .sheet(isPresented: $showingImport) {
            MCPImportSheet(onClose: {
                showingImport = false
                mcpStore.refresh()
            })
            .environmentObject(mcpStore)
            .frame(width: 480)
        }
        .sheet(item: editingBinding) { item in
            MCPEditServerSheet(
                toolID: item.toolID,
                toolLabel: ALL_TOOL_META.first(where: { $0.id == item.toolID })?.label ?? item.toolID,
                serverName: item.name,
                projectRoot: nil,
                onClose: {
                    editingServer = nil
                    mcpStore.refresh()
                }
            )
            .environmentObject(mcpStore)
        }
        .sheet(item: copyingBinding) { item in
            MCPCopyToAppsSheet(
                serverName: item.name,
                sourceToolID: item.toolID,
                sourceToolLabel: item.toolLabel,
                onClose: {
                    copyingServer = nil
                    mcpStore.refresh()
                }
            )
            .environmentObject(mcpStore)
            .environmentObject(ProjectStore())
        }
        .alert("Delete server?", isPresented: Binding(
            get: { confirmDelete != nil },
            set: { if !$0 { confirmDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let d = confirmDelete {
                    mcpStore.removeServer(toolID: d.toolID, name: d.name)
                }
                confirmDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            if let d = confirmDelete {
                Text("Remove \"\(d.name)\" from \(ALL_TOOL_META.first(where: { $0.id == d.toolID })?.label ?? d.toolID)?")
            }
        }
        .onAppear { mcpStore.refresh() }
    }

    // MARK: - Helper bindings for sheet items

    private var editingBinding: Binding<IdentifiableServer?> {
        Binding(
            get: { editingServer.map { IdentifiableServer(toolID: $0.toolID, name: $0.name) } },
            set: { if $0 == nil { editingServer = nil } }
        )
    }

    private var copyingBinding: Binding<IdentifiableCopyServer?> {
        Binding(
            get: { copyingServer.map { IdentifiableCopyServer(toolID: $0.toolID, toolLabel: $0.toolLabel, name: $0.name) } },
            set: { if $0 == nil { copyingServer = nil } }
        )
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 11))
            TextField("Search servers…", text: $mcpStore.searchText)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
            if !mcpStore.searchText.isEmpty {
                Button { mcpStore.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button {
                mcpStore.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(mcpStore.isLoading ? .accentColor : .secondary)
                    .rotationEffect(.degrees(mcpStore.isLoading ? 360 : 0))
                    .animation(
                        mcpStore.isLoading
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: mcpStore.isLoading
                    )
            }
            .buttonStyle(.plain)
            .help("Refresh")

            Button {
                showingImport = true
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

    // MARK: - Main content

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Summary pill
                let count = mcpStore.serverCount
                if count > 0 {
                    HStack {
                        Text("\(count) unique server\(count == 1 ? "" : "s") across \(mcpStore.detectedTools.count) tool\(mcpStore.detectedTools.count == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                }

                ForEach(mcpStore.detectedTools) { tool in
                    let visibleServers = tool.servers.filter { mcpStore.matches($0.name) }
                    if !mcpStore.searchText.isEmpty && visibleServers.isEmpty { } else {
                        toolSection(tool: tool, servers: visibleServers)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Tool section

    private func toolSection(tool: ToolSummary, servers: [ServerEntry]) -> some View {
        let c = ToolPalette.color(for: tool.toolID)

        return VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                Group {
                    if let img = ToolPalette.appImage(for: tool.toolID) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(c.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: ToolPalette.icon(for: tool.toolID))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(c)
                        }
                    }
                }
                Text(tool.label)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(tool.servers.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(c)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(c.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            if !servers.isEmpty {
                Divider().opacity(0.5)
                VStack(spacing: 1) {
                    ForEach(servers) { server in
                        serverRow(server: server, tool: tool, color: c)
                    }
                }
            } else if mcpStore.searchText.isEmpty {
                HStack {
                    Text("No servers configured")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(c.opacity(0.20), lineWidth: 1))
    }

    // MARK: - Server row

    private func serverRow(server: ServerEntry, tool: ToolSummary, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(server.isDisabled ? Color.secondary.opacity(0.3) : color.opacity(0.6))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(server.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(server.isDisabled ? .secondary : .primary)
                    if server.isDisabled {
                        Text("disabled")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(server.detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Toggle disabled
            Button {
                mcpStore.toggleServerDisabled(toolID: tool.toolID, name: server.name, currently: server.isDisabled)
            } label: {
                Image(systemName: server.isDisabled ? "eye" : "eye.slash")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(server.isDisabled ? "Enable" : "Disable")

            // Copy to apps
            Button {
                copyingServer = (toolID: tool.toolID, toolLabel: tool.label, name: server.name)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy to other apps")

            // Edit
            Button {
                editingServer = (toolID: tool.toolID, name: server.name)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Edit")

            // Delete
            Button {
                confirmDelete = (toolID: tool.toolID, name: server.name)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.clear)
    }

    // MARK: - Loading / Empty

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Scanning AI tools…")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 26))
                .foregroundColor(.secondary)
            Text("No AI tools detected")
                .font(.system(size: 14, weight: .semibold))
            Text("Install Claude Code, Cursor, or another AI tool to see MCP servers here.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}

// MARK: - Identifiable helpers for sheet presentation

private struct IdentifiableServer: Identifiable {
    let id = UUID()
    let toolID: String
    let name: String
}

private struct IdentifiableCopyServer: Identifiable {
    let id = UUID()
    let toolID: String
    let toolLabel: String
    let name: String
}
