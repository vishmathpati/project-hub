import SwiftUI
import AppKit

// MARK: - Global MCP view: all detected AI tools and their servers

struct GlobalMCPView: View {
    @EnvironmentObject var mcpStore: MCPStore

    @State private var showingImport = false
    @State private var editingServer: (toolID: String, name: String)? = nil
    @State private var copyingServer: (toolID: String, toolLabel: String, name: String)? = nil
    @State private var confirmDelete: (toolID: String, name: String)? = nil
    @State private var pluginPolicyPreview: CodexPluginMCPPolicyPreview?
    @State private var policyError: String?

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
        .sheet(item: $pluginPolicyPreview) { preview in
            codexPluginPolicyPreviewSheet(preview)
                .frame(width: 520, height: 560)
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
        .alert("Could not update plugin policy", isPresented: Binding(
            get: { policyError != nil },
            set: { if !$0 { policyError = nil } }
        )) {
            Button("OK", role: .cancel) { policyError = nil }
        } message: {
            Text(policyError ?? "Unknown error")
        }
        .onAppear { mcpStore.refresh(force: false) }
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
                mcpStore.verifyHealth()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 11, weight: .medium))
                    Text(mcpStore.isVerifyingHealth ? "Verifying" : "Verify")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(mcpStore.isVerifyingHealth ? .secondary : .accentColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(mcpStore.isVerifyingHealth || mcpStore.detectedTools.allSatisfy { $0.servers.isEmpty })
            .help("Verify MCP initialize and tools/list where supported")

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
                    HStack(spacing: 6) {
                        Text("\(count) unique server\(count == 1 ? "" : "s") across \(mcpStore.detectedTools.count) tool\(mcpStore.detectedTools.count == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        if mcpStore.isVerifyingHealth {
                            ProgressView()
                                .scaleEffect(0.45)
                                .frame(width: 14, height: 14)
                            Text("probing MCP endpoints")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        ForEach(MCPHealthStatus.allCases.filter { (mcpStore.healthSummary[$0] ?? 0) > 0 }, id: \.self) { status in
                            healthPill(status: status, count: mcpStore.healthSummary[status] ?? 0)
                        }
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
        let health = mcpStore.health(for: server, toolID: tool.toolID)
        let readOnlyHelp = server.readOnlyReason ?? "This server is read-only in Global MCP."
        let canTogglePolicy = server.canToggleCodexPluginPolicy
        let toggleHelp = canTogglePolicy
            ? "Preview a Codex config policy change for this plugin-bundled MCP server"
            : readOnlyHelp
        return HStack(spacing: 8) {
            Circle()
                .fill(healthColor(health.status).opacity(0.75))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(server.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(server.isDisabled ? .secondary : .primary)
                    if server.isDisabled {
                        statusBadge(health.status)
                    } else {
                        statusBadge(health.status)
                    }
                }
                Text(server.detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let sourceLabel = server.sourceLabel {
                    HStack(spacing: 4) {
                        Image(systemName: server.isReadOnly ? "lock.fill" : "folder")
                            .font(.system(size: 8, weight: .semibold))
                        Text(sourceLabel)
                            .font(.system(size: 10))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .foregroundColor(.secondary)
                }
                if health.status != .working {
                    Text(health.summary)
                        .font(.system(size: 10))
                        .foregroundColor(healthColor(health.status))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Toggle disabled
            Button {
                if server.isReadOnly {
                    if let preview = mcpStore.previewCodexPluginPolicyToggle(
                        toolID: tool.toolID,
                        server: server,
                        currently: server.isDisabled
                    ) {
                        pluginPolicyPreview = preview
                    } else if server.codexPluginEnabled == false {
                        policyError = "The entire Codex plugin is disabled. Enable the plugin itself in Codex config before changing its bundled MCP server policy."
                    } else {
                        policyError = readOnlyHelp
                    }
                } else {
                    mcpStore.toggleServerDisabled(toolID: tool.toolID, name: server.name, currently: server.isDisabled)
                }
            } label: {
                Image(systemName: server.isDisabled ? "eye" : "eye.slash")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(server.isReadOnly && !canTogglePolicy)
            .opacity(server.isReadOnly && !canTogglePolicy ? 0.35 : 1)
            .help(server.isReadOnly ? toggleHelp : (server.isDisabled ? "Enable" : "Disable"))

            // Copy to apps
            Button {
                copyingServer = (toolID: tool.toolID, toolLabel: tool.label, name: server.name)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(server.isReadOnly)
            .opacity(server.isReadOnly ? 0.35 : 1)
            .help(server.isReadOnly ? readOnlyHelp : "Copy to other apps")

            // Edit
            Button {
                editingServer = (toolID: tool.toolID, name: server.name)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(server.isReadOnly)
            .opacity(server.isReadOnly ? 0.35 : 1)
            .help(server.isReadOnly ? readOnlyHelp : "Edit")

            // Delete
            Button {
                confirmDelete = (toolID: tool.toolID, name: server.name)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
            .disabled(server.isReadOnly)
            .opacity(server.isReadOnly ? 0.35 : 1)
            .help(server.isReadOnly ? readOnlyHelp : "Remove")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.clear)
    }

    private func codexPluginPolicyPreviewSheet(_ preview: CodexPluginMCPPolicyPreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: preview.enabled ? "eye" : "eye.slash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(preview.enabled ? "Enable plugin MCP server" : "Disable plugin MCP server")
                        .font(.system(size: 13, weight: .semibold))
                    Text(preview.serverName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                labelLine("Config", preview.configPath)
                labelLine("Plugin", preview.pluginID)
                if let profileName = preview.profileName {
                    labelLine("Profile", profileName)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Project Hub will write Codex plugin MCP policy in config.toml. It will not edit the installed plugin's bundled MCP file.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lineDiff(before: preview.before, after: preview.after).enumerated()), id: \.offset) { _, line in
                        HStack(spacing: 0) {
                            Text(line.symbol)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(line.color)
                                .frame(width: 14, alignment: .leading)
                            Text(line.text.isEmpty ? " " : line.text)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(line.color)
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor), lineWidth: 0.5))

            HStack {
                Button("Cancel") {
                    pluginPolicyPreview = nil
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(preview.enabled ? "Enable" : "Disable") {
                    let result = mcpStore.applyCodexPluginPolicyPreview(preview)
                    pluginPolicyPreview = nil
                    if !result.ok {
                        policyError = result.error ?? "Unknown error"
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
    }

    private func labelLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 48, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }

    private func statusBadge(_ status: MCPHealthStatus) -> some View {
        Text(status.rawValue)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(healthColor(status))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(healthColor(status).opacity(0.12))
            .clipShape(Capsule())
    }

    private func healthPill(status: MCPHealthStatus, count: Int) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(healthColor(status))
                .frame(width: 5, height: 5)
            Text("\(count) \(status.rawValue.lowercased())")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(healthColor(status))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(healthColor(status).opacity(0.10))
        .clipShape(Capsule())
    }

    private func healthColor(_ status: MCPHealthStatus) -> Color {
        switch status {
        case .working: return .green
        case .broken: return .red
        case .needsAuth, .authExpired: return .orange
        case .needsRestart: return .blue
        case .disabled: return .secondary
        case .unknown: return .purple
        }
    }

    private struct PolicyDiffLine {
        enum Kind { case same, add, remove }
        let kind: Kind
        let text: String

        var symbol: String {
            switch kind {
            case .same: return " "
            case .add: return "+"
            case .remove: return "-"
            }
        }

        var color: Color {
            switch kind {
            case .same: return .secondary
            case .add: return .green
            case .remove: return .red
            }
        }
    }

    private func lineDiff(before: String, after: String) -> [PolicyDiffLine] {
        let beforeLines = before.components(separatedBy: "\n")
        let afterLines = after.components(separatedBy: "\n")
        let beforeSet = Set(beforeLines)
        let afterSet = Set(afterLines)
        var out: [PolicyDiffLine] = []
        for line in afterLines {
            out.append(.init(kind: beforeSet.contains(line) ? .same : .add, text: line))
        }
        for line in beforeLines where !afterSet.contains(line) {
            out.append(.init(kind: .remove, text: line))
        }
        if out.count > 140 {
            return Array(out.prefix(140)) + [.init(kind: .same, text: "... (truncated)")]
        }
        return out
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
            Text("Install Claude Desktop, Claude Code, or Codex to see MCP servers here.")
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
