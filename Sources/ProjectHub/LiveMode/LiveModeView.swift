import SwiftUI

// MARK: - Live Mode sidebar view

struct LiveModeView: View {
    @ObservedObject var watcher:    ProjectWatcher
    @ObservedObject var skillStore: SkillStore
    @ObservedObject var mcpStore:   MCPStore

    /// User-pinned project path. nil = auto-follow watcher.activeProject.
    @State private var pinnedProjectPath: String? = nil
    @State private var snapshot: ContextSnapshot? = nil
    @State private var isRefreshing = false
    /// Incremented on every refresh; lets background tasks discard stale results.
    @State private var refreshGeneration = 0

    // Disclosure state for collapsible groups
    @State private var globalSkillsExpanded = false
    @State private var pluginSkillsExpanded = false
    @State private var globalMcpExpanded = false

    /// The project whose data we're displaying right now.
    private var displayProject: WatchedProject? {
        if let pinned = pinnedProjectPath,
           let match = watcher.openProjects.first(where: { $0.path == pinned }) {
            return match
        }
        return watcher.activeProject
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            // Multi-project switcher — only shown when 2+ real project tabs are open
            if watcher.openProjects.count > 1 {
                projectPicker
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
            }

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
        .onChange(of: watcher.activeProject) { _, _ in
            if pinnedProjectPath == nil { refreshSnapshot() }
        }
        .onChange(of: pinnedProjectPath) { _, _ in refreshSnapshot() }
        .onChange(of: watcher.openProjects) { _, newProjects in
            if let pinned = pinnedProjectPath,
               !newProjects.contains(where: { $0.path == pinned }) {
                pinnedProjectPath = nil
            }
        }
        .onAppear { refreshSnapshot() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(watcher.claudeIsFront ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
                    .animation(.easeInOut(duration: 0.3), value: watcher.claudeIsFront)

                if let proj = displayProject {
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

            if let proj = displayProject {
                Text(proj.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(HubTheme.panelBg)
    }

    // MARK: - Multi-project picker

    private var projectPicker: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.stack.3d.up")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Picker("Project", selection: $pinnedProjectPath) {
                Text("Auto (most recent)")
                    .tag(Optional<String>.none)
                ForEach(watcher.openProjects, id: \.path) { proj in
                    Text(proj.name)
                        .tag(Optional(proj.path))
                }
            }
            .labelsHidden()
            .font(.caption)
            .help("Switch between open projects")
        }
        .padding(.vertical, 4)
    }

    // MARK: - Context section

    private func contextSection(_ snap: ContextSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Context Window", icon: "chart.bar.fill")

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
                HStack(spacing: 4) {
                    Text("\(tokenLabel(snap.totalTokens)) used")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(barColor(snap.usedFraction))
                    if snap.hasRealSessionData {
                        Text("· last turn")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Text("\(tokenLabel(snap.remainingTokens)) left")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if snap.hasRealSessionData {
                HStack(spacing: 10) {
                    chip("Input",  value: snap.sessionInputTokens, color: .blue)
                    chip("Cache↑", value: snap.sessionCacheCreate, color: .orange)
                    chip("Cache↓", value: snap.sessionCacheRead,   color: .green)
                }
            } else {
                HStack(spacing: 10) {
                    chip("Skills",    value: snap.skillsTotal,    color: .blue)
                    chip("MCPs",      value: snap.mcpTotal,       color: .purple)
                    chip("CLAUDE.md", value: snap.claudeMdTokens, color: .orange)
                }
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
        let projectSkills = snap.skills.filter { $0.source == "project" }
        let globalSkills  = snap.skills.filter { $0.source == "global" }
        let pluginSkills  = snap.skills.filter { $0.source == "plugin" }
        let enabledCount  = snap.skills.filter { $0.enabled }.count

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("Skills", icon: "wand.and.stars")
                Spacer()
                countBadge(active: enabledCount, total: snap.skills.count)
            }

            // ── Project skills ──────────────────────────────────────────────
            if projectSkills.isEmpty && pluginSkills.isEmpty {
                emptyRow("No project or plugin skills")
            } else {
                if !projectSkills.isEmpty {
                    ForEach(projectSkills) { item in
                        skillRow(item, snapshot: snap)
                    }
                }
            }

            // ── Plugin skills ───────────────────────────────────────────────
            if !pluginSkills.isEmpty {
                DisclosureGroup(isExpanded: $pluginSkillsExpanded) {
                    ForEach(pluginSkills) { item in
                        skillRow(item, snapshot: snap)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("PLUGINS")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.tertiary)
                        Text("\(pluginSkills.count)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(tokenLabel(pluginSkills.filter { $0.enabled }.map { $0.tokens }.reduce(0, +)))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // ── Global skills (collapsed by default — there can be 50+) ─────
            if !globalSkills.isEmpty {
                DisclosureGroup(isExpanded: $globalSkillsExpanded) {
                    ForEach(globalSkills) { item in
                        skillRow(item, snapshot: snap)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("GLOBAL")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.tertiary)
                        Text("\(globalSkills.filter { $0.enabled }.count)/\(globalSkills.count)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(tokenLabel(globalSkills.filter { $0.enabled }.map { $0.tokens }.reduce(0, +)))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func skillRow(_ item: SkillTokenItem, snapshot: ContextSnapshot) -> some View {
        HStack(spacing: 8) {
            if item.source == "plugin" {
                // Plugin skills are read-only — no toggle
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: 26)
            } else {
                Toggle("", isOn: Binding(
                    get: { item.enabled },
                    set: { enable in toggleSkill(item: item, enable: enable, snapshot: snapshot) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }

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

    // MARK: - MCP section

    private func mcpSection(_ snap: ContextSnapshot) -> some View {
        let projectMcps = snap.mcpServers.filter { $0.source == "project" }
        let globalMcps  = snap.mcpServers.filter { $0.source == "global" }
        let enabledCount = snap.mcpServers.filter { $0.enabled }.count

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("MCP Servers", icon: "server.rack")
                Spacer()
                countBadge(active: enabledCount, total: snap.mcpServers.count)
            }

            // ── Project MCP servers ─────────────────────────────────────────
            if projectMcps.isEmpty && globalMcps.isEmpty {
                emptyRow("No MCP servers configured")
            } else {
                if !projectMcps.isEmpty {
                    ForEach(projectMcps) { item in
                        mcpRow(item, snapshot: snap)
                    }
                } else {
                    emptyRow("No project MCP servers")
                }
            }

            // ── Global MCP servers (collapsible) ────────────────────────────
            if !globalMcps.isEmpty {
                DisclosureGroup(isExpanded: $globalMcpExpanded) {
                    ForEach(globalMcps) { item in
                        mcpRow(item, snapshot: snap)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("GLOBAL")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.tertiary)
                        Text("\(globalMcps.filter { $0.enabled }.count)/\(globalMcps.count)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(tokenLabel(globalMcps.filter { $0.enabled }.map { $0.tokens }.reduce(0, +)))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
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
        guard let proj = displayProject else {
            // Don't wipe snapshot — keep last known data visible while we wait
            isRefreshing = false
            return
        }
        isRefreshing = true
        refreshGeneration += 1
        let gen  = refreshGeneration
        let path = proj.path

        Task.detached(priority: .userInitiated) {
            let snap = ContextEstimator.estimate(for: path)
            await MainActor.run {
                // Discard result if a newer refresh already fired
                guard self.refreshGeneration == gen else { return }
                self.snapshot     = snap
                self.isRefreshing = false
            }
        }
    }

    private func toggleSkill(item: SkillTokenItem, enable: Bool, snapshot: ContextSnapshot) {
        guard item.source != "plugin" else { return } // Plugin and non-Claude skills are read-only here.
        let fm = FileManager.default
        let canonicalPath = URL(fileURLWithPath: item.path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        guard canonicalPath.contains("/.claude/skills/") else {
            refreshSnapshot()
            return
        }

        let skillName = (canonicalPath as NSString).lastPathComponent
        let parentDir = (canonicalPath as NSString).deletingLastPathComponent
        let enabledDir: String
        let disabledDir: String
        let enabledPath: String
        let disabledPath: String

        if (parentDir as NSString).lastPathComponent == "_disabled" {
            disabledDir = parentDir
            enabledDir = (parentDir as NSString).deletingLastPathComponent
            disabledPath = canonicalPath
            enabledPath = (enabledDir as NSString).appendingPathComponent(skillName)
        } else {
            enabledDir = parentDir
            disabledDir = (enabledDir as NSString).appendingPathComponent("_disabled")
            enabledPath = canonicalPath
            disabledPath = (disabledDir as NSString).appendingPathComponent(skillName)
        }

        do {
            if enable {
                if fm.fileExists(atPath: disabledPath) {
                    try fm.createDirectory(atPath: enabledDir, withIntermediateDirectories: true)
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
        if item.source == "global" {
            ConfigWriter.toggleGlobalMcpForProject(
                projectPath: snapshot.projectPath,
                name: item.name,
                enable: enable
            )
        } else {
            ConfigWriter.toggleProjectServer(
                projectPath: snapshot.projectPath,
                name: item.name,
                enable: enable
            )
        }
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
