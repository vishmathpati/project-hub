import SwiftUI

// MARK: - Live Mode sidebar view

struct LiveModeView: View {
    @ObservedObject var watcher:    ProjectWatcher
    @ObservedObject var skillStore: SkillStore
    @ObservedObject var mcpStore:   MCPStore

    @State private var snapshot: ContextSnapshot? = nil
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let snap = snapshot {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        contextSection(snap)
                        Divider().padding(.horizontal, 4)
                        skillsSection(snap)
                        Divider().padding(.horizontal, 4)
                        mcpSection(snap)
                    }
                    .padding(12)
                }
            } else {
                Spacer()
                emptyState
                Spacer()
            }
        }
        .onChange(of: watcher.activeProject) { refreshSnapshot() }
        .onAppear { refreshSnapshot() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Claude Code status dot
                Circle()
                    .fill(watcher.claudeIsFront ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
                    .animation(.easeInOut(duration: 0.3), value: watcher.claudeIsFront)

                if let proj = watcher.activeProject {
                    Text(proj.name)
                        .font(.system(.subheadline, design: .default))
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("Detecting project…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isRefreshing {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Button { refreshSnapshot() } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh")
                }
            }

            // Project path subtitle
            if let proj = watcher.activeProject {
                Text(proj.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Context section

    private func contextSection(_ snap: ContextSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Context Window", icon: "chart.bar.fill")

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor(snap.usedFraction))
                        .frame(width: geo.size.width * snap.usedFraction)
                        .animation(.easeOut(duration: 0.4), value: snap.usedFraction)
                }
                .frame(height: 10)
            }
            .frame(height: 10)

            HStack {
                Text("\(tokenLabel(snap.totalTokens)) used")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(barColor(snap.usedFraction))
                Spacer()
                Text("\(tokenLabel(snap.remainingTokens)) left")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // Breakdown chips
            HStack(spacing: 10) {
                chip("Skills",    value: snap.skillsTotal,      color: .blue)
                chip("MCPs",      value: snap.mcpTotal,         color: .purple)
                chip("CLAUDE.md", value: snap.claudeMdTokens,   color: .orange)
            }
        }
    }

    private func chip(_ label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text("\(label) \(tokenLabel(value))")
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
    }

    // MARK: - Skills section

    private func skillsSection(_ snap: ContextSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("Skills", icon: "wand.and.stars")
                Spacer()
                countBadge(active: snap.skills.filter { $0.enabled }.count,
                           total:  snap.skills.count)
            }

            if snap.skills.isEmpty {
                emptyRow("No skills installed in this project")
            } else {
                ForEach(snap.skills) { item in
                    skillRow(item, snapshot: snap)
                }
            }
        }
    }

    private func skillRow(_ item: SkillTokenItem, snapshot: ContextSnapshot) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { item.enabled },
                set: { enable in toggleSkill(item: item, enable: enable, snapshot: snapshot) }
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
            Text(tokenLabel(item.tokens))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .opacity(item.enabled ? 1 : 0.45)
    }

    // MARK: - MCP section

    private func mcpSection(_ snap: ContextSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("MCP Servers", icon: "server.rack")
                Spacer()
                countBadge(active: snap.mcpServers.filter { $0.enabled }.count,
                           total:  snap.mcpServers.count)
            }

            if snap.mcpServers.isEmpty {
                emptyRow("No MCP servers in .mcp.json")
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
                set: { enable in toggleMCP(item: item, enable: enable, snapshot: snapshot) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()

            Text(item.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            Spacer()
            Text(tokenLabel(item.tokens))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .opacity(item.enabled ? 1 : 0.45)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Open a project in Claude Code")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("The most recently active session\nwill appear here automatically.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Reusable sub-views

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
    }

    private func countBadge(active: Int, total: Int) -> some View {
        Text("\(active)/\(total)")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.leading, 4)
    }

    // MARK: - Actions

    private func refreshSnapshot() {
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
        let fm          = FileManager.default
        let skillsDir   = (snapshot.projectPath as NSString).appendingPathComponent(".claude/skills")
        let disabledDir = (skillsDir as NSString).appendingPathComponent("_disabled")
        let enabledPath  = (skillsDir as NSString).appendingPathComponent(item.id)
        let disabledPath = (disabledDir as NSString).appendingPathComponent(item.id)

        do {
            if enable {
                if fm.fileExists(atPath: disabledPath) {
                    try fm.createDirectory(atPath: skillsDir, withIntermediateDirectories: true)
                    if fm.fileExists(atPath: enabledPath) { try fm.removeItem(atPath: enabledPath) }
                    try fm.moveItem(atPath: disabledPath, toPath: enabledPath)
                }
            } else {
                if fm.fileExists(atPath: enabledPath) {
                    try fm.createDirectory(atPath: disabledDir, withIntermediateDirectories: true)
                    if fm.fileExists(atPath: disabledPath) { try fm.removeItem(atPath: disabledPath) }
                    try fm.moveItem(atPath: enabledPath, toPath: disabledPath)
                }
            }
        } catch { /* silent — never steal focus */ }

        refreshSnapshot()
    }

    private func toggleMCP(item: MCPTokenItem, enable: Bool, snapshot: ContextSnapshot) {
        ConfigWriter.toggleProjectServer(projectPath: snapshot.projectPath,
                                         name: item.name, enable: enable)
        refreshSnapshot()
    }

    // MARK: - Helpers

    private func tokenLabel(_ n: Int) -> String {
        n >= 1_000 ? String(format: "%.1fk", Double(n) / 1_000) : "\(n)"
    }

    private func barColor(_ f: Double) -> Color {
        switch f {
        case ..<0.5:  return .green
        case ..<0.75: return .yellow
        case ..<0.9:  return .orange
        default:      return .red
        }
    }
}
