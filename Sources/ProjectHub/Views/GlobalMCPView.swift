import SwiftUI
import AppKit

// MARK: - Global MCP view: all detected AI tools and their servers

struct GlobalMCPView: View {
    @EnvironmentObject var mcpStore: MCPStore
    @EnvironmentObject var projectStore: ProjectStore

    @State private var showingImport = false
    @State private var editingServer: (toolID: String, name: String)? = nil
    @State private var copyingServer: (toolID: String, toolLabel: String, name: String)? = nil
    @State private var confirmDelete: (toolID: String, name: String)? = nil
    @State private var pluginPolicyPreview: CodexPluginMCPPolicyPreview?
    @State private var policyError: String?

    var body: some View {
        VStack(spacing: 0) {
            HubPageHeader(
                title: "MCP servers",
                subtitle: "\(mcpStore.serverCount) unique across \(mcpStore.detectedTools.count) provider\(mcpStore.detectedTools.count == 1 ? "" : "s")",
                actions: { headerActions }
            )

            if mcpStore.isLoading && mcpStore.tools.isEmpty {
                loadingView
            } else if mcpStore.detectedTools.isEmpty {
                emptyState
            } else {
                mainContent
            }
        }
        .background(HubTheme.bg)
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
            .environmentObject(projectStore)
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

    @ViewBuilder
    private var headerActions: some View {
        HubSearchField(text: $mcpStore.searchText, placeholder: "search servers", shortcut: nil)
            .frame(width: 180)

        HubIconButton(
            systemImage: "arrow.clockwise",
            help: "Refresh",
            isActive: mcpStore.isLoading,
            spinning: mcpStore.isLoading
        ) { mcpStore.refresh() }

        HubButton(title: mcpStore.isVerifyingHealth ? "Verifying" : "Verify all", kind: .secondary) {
            mcpStore.verifyHealth()
        }
        .disabled(mcpStore.isVerifyingHealth || mcpStore.detectedTools.allSatisfy { $0.servers.isEmpty })

        HubButton(title: "Import", kind: .primary) { showingImport = true }
    }

    // MARK: - Main content

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HubTheme.sectionGap) {
                healthStrip

                ForEach(mcpFamilies) { family in
                    mcpFamilySection(family)
                }
            }
            .padding(HubTheme.contentPadding)
        }
    }

    /// One line of health counts, each a dot plus a word (§2.3).
    private var healthStrip: some View {
        HStack(spacing: 18) {
            ForEach(MCPHealthStatus.allCases.filter { (mcpStore.healthSummary[$0] ?? 0) > 0 }, id: \.self) { status in
                StatusLabel(
                    status: hubStatus(status),
                    text: "\(mcpStore.healthSummary[status] ?? 0) \(status.rawValue.lowercased())"
                )
            }
            if mcpStore.isVerifyingHealth {
                Text("probing endpoints")
                    .font(HubFont.machine)
                    .foregroundStyle(HubTheme.textFaint)
            }
            Spacer(minLength: 0)
        }
    }

    private func hubStatus(_ status: MCPHealthStatus) -> HubStatus {
        switch status {
        case .working:                              return .ok
        case .broken:                               return .bad
        case .needsAuth, .authExpired, .needsRestart: return .warn
        case .disabled, .unknown:                   return .neutral
        }
    }

    // MARK: - Provider group

    private var mcpFamilies: [MCPFamilySection] {
        ProviderFamily.grouped(mcpStore.detectedTools, id: \.toolID).compactMap { group in
            let tools = group.items.filter { tool in
                let visible = tool.servers.filter { mcpStore.matches($0.name) }
                return mcpStore.searchText.isEmpty || !visible.isEmpty
            }
            guard !tools.isEmpty else { return nil }
            return MCPFamilySection(id: group.id, tools: tools)
        }
    }

    private func mcpFamilySection(_ family: MCPFamilySection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if family.tools.count > 1 {
                HStack(spacing: 10) {
                    ProviderTile(toolID: ProviderFamily.iconToolID(for: family.id))
                    Text(ProviderFamily.displayName(for: family.id))
                        .font(HubFont.sans(13, .semibold))
                        .foregroundStyle(HubTheme.textStrong)
                    Text(family.tools.map { ProviderFamily.memberLabel(for: $0.toolID) }.joined(separator: " · "))
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textDim)
                }
            }
            ForEach(family.tools) { tool in
                let visibleServers = tool.servers.filter { mcpStore.matches($0.name) }
                if family.tools.count > 1 {
                    Text(ProviderFamily.memberLabel(for: tool.toolID))
                        .font(HubFont.mono(9))
                        .foregroundStyle(HubTheme.textFaint)
                        .padding(.leading, 4)
                }
                toolSection(tool: tool, servers: visibleServers, showBrand: family.tools.count == 1)
            }
        }
    }

    private func toolSection(tool: ToolSummary, servers: [ServerEntry], showBrand: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if showBrand {
                    ProviderTile(toolID: tool.toolID)
                    Text(tool.label)
                        .font(HubFont.sans(13, .semibold))
                        .foregroundStyle(HubTheme.textStrong)
                }
                Text(configSummary(for: tool))
                    .font(HubFont.machine)
                    .foregroundStyle(HubTheme.textDim)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Rectangle()
                    .fill(HubTheme.hairline)
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
                Text("\(tool.servers.count) server\(tool.servers.count == 1 ? "" : "s")")
                    .font(HubFont.mono(9))
                    .foregroundStyle(HubTheme.textFaint)
            }

            if servers.isEmpty {
                Text("No servers configured")
                    .font(HubFont.secondary)
                    .foregroundStyle(HubTheme.textFaint)
                    .padding(.horizontal, HubTheme.contentPadding)
                    .frame(height: HubTheme.tableRowHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .hubCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(servers.enumerated()), id: \.element.id) { index, server in
                        if index > 0 { HubRowSeparator() }
                        serverRow(server: server, tool: tool)
                    }
                }
                .hubCard()
            }
        }
    }

    private func configSummary(for tool: ToolSummary) -> String {
        var seen: [String] = []
        for server in tool.servers {
            guard let label = server.sourceLabel, !seen.contains(label) else { continue }
            seen.append(label)
        }
        return seen.prefix(2).joined(separator: " · ")
    }

    // MARK: - Server row

    private func serverRow(server: ServerEntry, tool: ToolSummary) -> some View {
        let health = mcpStore.health(for: server, toolID: tool.toolID)
        let status = hubStatus(health.status)
        let readOnlyHelp = server.readOnlyReason ?? "This server is read-only in Global MCP."
        let canTogglePolicy = server.canToggleCodexPluginPolicy
        let toggleHelp = canTogglePolicy
            ? "Preview a Codex config policy change for this plugin-bundled MCP server"
            : readOnlyHelp
        let needsAuth = health.status == .needsAuth || health.status == .authExpired

        return HStack(alignment: .center, spacing: 10) {
            StatusDot(status: status)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(server.name)
                        .font(HubFont.rowPrimary)
                        .foregroundStyle(server.isDisabled ? HubTheme.textMid : HubTheme.text)
                    Text(server.transport)
                        .font(HubFont.mono(9))
                        .foregroundStyle(HubTheme.textFaint)
                    if server.isReadOnly {
                        Text("read-only")
                            .font(HubFont.mono(9))
                            .foregroundStyle(HubTheme.textFaint)
                    }
                }
                Text(health.status == .working ? server.detail : "\(server.detail) · \(health.summary)")
                    .font(HubFont.machine)
                    .foregroundStyle(HubTheme.textDim)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            // Colour is never the only signal — the state is spelled out (§2.3).
            Text(health.status.rawValue.lowercased())
                .font(HubFont.machine)
                .foregroundStyle(status == .neutral ? HubTheme.textFaint : status.color)

            if needsAuth {
                // The fix travels with the line it belongs to (§7.1).
                HubButton(title: "sign in", kind: .accentInline) {
                    editingServer = (toolID: tool.toolID, name: server.name)
                }
            }

            HubIconButton(
                systemImage: server.isDisabled ? "eye" : "eye.slash",
                help: server.isReadOnly ? toggleHelp : (server.isDisabled ? "Enable" : "Disable")
            ) {
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
            }
            .disabled(server.isReadOnly && !canTogglePolicy)
            .opacity(server.isReadOnly && !canTogglePolicy ? 0.35 : 1)

            HubIconButton(
                systemImage: "square.and.arrow.up",
                help: server.isReadOnly ? readOnlyHelp : "Copy to other providers"
            ) {
                copyingServer = (toolID: tool.toolID, toolLabel: tool.label, name: server.name)
            }
            .disabled(server.isReadOnly)
            .opacity(server.isReadOnly ? 0.35 : 1)

            if !server.isReadOnly, ProviderFamily.groupID(for: tool.toolID) == "claude" {
                let sibling = tool.toolID == "claude-code" ? "claude-desktop" : "claude-code"
                if mcpStore.detectedTools.contains(where: { $0.toolID == sibling }) {
                    HubButton(title: "to \(ProviderFamily.memberLabel(for: sibling))", kind: .inlineAction) {
                        _ = mcpStore.copyServer(name: server.name, from: tool.toolID, to: [sibling])
                    }
                }
            }

            HubButton(title: "edit", kind: .inlineAction) {
                editingServer = (toolID: tool.toolID, name: server.name)
            }
            .disabled(server.isReadOnly)
            .opacity(server.isReadOnly ? 0.35 : 1)

            HubIconButton(
                systemImage: "trash",
                help: server.isReadOnly ? readOnlyHelp : "Remove"
            ) {
                confirmDelete = (toolID: tool.toolID, name: server.name)
            }
            .disabled(server.isReadOnly)
            .opacity(server.isReadOnly ? 0.35 : 1)
        }
        .padding(.horizontal, HubTheme.contentPadding)
        .frame(minHeight: HubTheme.tableRowHeight)
        .opacity(server.isDisabled ? 0.6 : 1)
    }

    private func codexPluginPolicyPreviewSheet(_ preview: CodexPluginMCPPolicyPreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: preview.enabled ? "eye" : "eye.slash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(HubTheme.accent)
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
            .background(HubTheme.raised)
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
            .background(HubTheme.field)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(HubTheme.line, lineWidth: 0.5))

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

    private func healthColor(_ status: MCPHealthStatus) -> Color {
        hubStatus(status).color
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

private struct MCPFamilySection: Identifiable {
    let id: String
    let tools: [ToolSummary]
}

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
