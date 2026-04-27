import SwiftUI

// MARK: - Live Mode root view

struct LiveModeView: View {
    @ObservedObject var watcher:    ProjectWatcher
    @ObservedObject var skillStore: SkillStore
    @ObservedObject var mcpStore:   MCPStore

    @State private var snapshot: ContextSnapshot? = nil
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            if let snap = snapshot {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        contextBar(snap)
                        Divider()
                        skillsSection(snap)
                        Divider()
                        mcpSection(snap)
                    }
                    .padding(12)
                }
            } else {
                Spacer()
                noProjectView
                Spacer()
            }
        }
        .onChange(of: watcher.activeProject) { refresh() }
        .onAppear { refresh() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            // Claude Code indicator dot
            Circle()
                .fill(watcher.claudeIsFront ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)

            if let proj = watcher.activeProject {
                Text(proj.name)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("No project detected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isRefreshing {
                ProgressView().scaleEffect(0.6)
            } else {
                Button {
                    refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Context bar

    private func contextBar(_ snap: ContextSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Context", systemImage: "chart.bar.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(formatTokens(snap.totalTokens)) / \(formatTokens(ContextSnapshot.contextWindowSize))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(colorFor(fraction: snap.usedFraction))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorFor(fraction: snap.usedFraction))
                        .frame(width: geo.size.width * snap.usedFraction, height: 8)
                        .animation(.easeOut(duration: 0.3), value: snap.usedFraction)
                }
            }
            .frame(height: 8)

            // Breakdown
            HStack(spacing: 12) {
                tokenPill("Skills",    tokens: snap.skillsTotal, color: .blue)
                tokenPill("MCPs",      tokens: snap.mcpTotal,    color: .purple)
                tokenPill("CLAUDE.md", tokens: snap.claudeMdTokens, color: .orange)
            }
            .font(.caption2)
        }
    }

    private func tokenPill(_ label: String, tokens: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text("\(label): \(formatTokens(tokens))")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Skills section

    private func skillsSection(_ snap: ContextSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                title: "Skills",
                icon: "wand.and.stars",
                count: "\(snap.skills.filter { $0.enabled }.count)/\(snap.skills.count) active"
            )

            if snap.skills.isEmpty {
                Text("No skills installed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else {
                ForEach(snap.skills) { item in
                    skillRow(item, snapshot: snap)
                }
            }
        }
    }

    private func skillRow(_ item: SkillTokenItem, snapshot: ContextSnapshot) -> some View {
        HStack(spacing: 8) {
            // Toggle
            Toggle("", isOn: Binding(
                get: { item.enabled },
                set: { newVal in toggleSkill(item: item, enable: newVal, snapshot: snapshot) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }

            Spacer()

            Text("~\(formatTokens(item.tokens))")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(item.enabled ? .secondary : .tertiary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .opacity(item.enabled ? 1.0 : 0.5)
    }

    // MARK: - MCP section

    private func mcpSection(_ snap: ContextSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                title: "MCP Servers",
                icon: "server.rack",
                count: "\(snap.mcpServers.filter { $0.enabled }.count)/\(snap.mcpServers.count) active"
            )

            if snap.mcpServers.isEmpty {
                Text("No MCP servers configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else {
                ForEach(snap.mcpServers) { item in
                    mcpRow(item, snapshot: snap)
                }
            }
        }
    }

    private func mcpRow(_ item: MCPTokenItem, snapshot: ContextSnapshot) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { item.enabled },
                set: { newVal in toggleMCP(item: item, enable: newVal, snapshot: snapshot) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()

            Text(item.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer()

            Text("~\(formatTokens(item.tokens))")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(item.enabled ? .secondary : .tertiary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .opacity(item.enabled ? 1.0 : 0.5)
    }

    // MARK: - No project placeholder

    private var noProjectView: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.dashed")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Open a project in Claude Code")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Section header

    private func sectionHeader(title: String, icon: String, count: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
            Text(count)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Actions

    private func refresh() {
        guard let proj = watcher.activeProject else {
            snapshot = nil
            return
        }
        isRefreshing = true
        Task.detached(priority: .userInitiated) {
            let snap = ContextEstimator.estimate(for: proj.path)
            await MainActor.run {
                self.snapshot     = snap
                self.isRefreshing = false
            }
        }
    }

    private func toggleSkill(item: SkillTokenItem, enable: Bool, snapshot: ContextSnapshot) {
        let fm = FileManager.default
        let skillsDir  = (snapshot.projectPath as NSString).appendingPathComponent(".claude/skills")
        let disabledDir = (skillsDir as NSString).appendingPathComponent("_disabled")

        let enabledPath  = (skillsDir as NSString).appendingPathComponent(item.id)
        let disabledPath = (disabledDir as NSString).appendingPathComponent(item.id)

        do {
            if enable {
                // Move from _disabled back to skills
                if fm.fileExists(atPath: disabledPath) {
                    try fm.createDirectory(atPath: skillsDir, withIntermediateDirectories: true)
                    // Remove destination if it exists
                    if fm.fileExists(atPath: enabledPath) {
                        try fm.removeItem(atPath: enabledPath)
                    }
                    try fm.moveItem(atPath: disabledPath, toPath: enabledPath)
                }
            } else {
                // Move to _disabled
                if fm.fileExists(atPath: enabledPath) {
                    try fm.createDirectory(atPath: disabledDir, withIntermediateDirectories: true)
                    if fm.fileExists(atPath: disabledPath) {
                        try fm.removeItem(atPath: disabledPath)
                    }
                    try fm.moveItem(atPath: enabledPath, toPath: disabledPath)
                }
            }
        } catch {
            // Silently fail — show nothing to avoid activating panel
        }

        // Refresh estimate
        refresh()
    }

    private func toggleMCP(item: MCPTokenItem, enable: Bool, snapshot: ContextSnapshot) {
        // Use ConfigWriter project-scope toggle
        let result = ConfigWriter.toggleProjectServer(
            projectPath: snapshot.projectPath,
            name: item.name,
            enable: enable
        )
        if result { refresh() }
    }

    // MARK: - Helpers

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000 { return String(format: "%.1fk", Double(n) / 1_000) }
        return "\(n)"
    }

    private func colorFor(fraction: Double) -> Color {
        switch fraction {
        case ..<0.5:  return .green
        case ..<0.75: return .yellow
        case ..<0.9:  return .orange
        default:      return .red
        }
    }
}
