import SwiftUI
import AppKit

// MARK: - Root content view (6 tabs: Projects | Skills | Plugins | MCP | Compat | Settings)

struct ContentView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @EnvironmentObject var skillStore:   SkillStore
    @EnvironmentObject var mcpStore:     MCPStore
    private let showsExpandButton: Bool
    @State private var tab: AppTab = .projects

    init(showsExpandButton: Bool = true) {
        self.showsExpandButton = showsExpandButton
    }

    private enum AppTab: Int, CaseIterable, Identifiable {
        case projects
        case skills
        case plugins
        case mcp
        case compat
        case settings

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .projects: return "Projects"
            case .skills: return "Skills"
            case .plugins: return "Plugins"
            case .mcp: return "MCP"
            case .compat: return "Compat"
            case .settings: return "Settings"
            }
        }

        var sidebarDetail: String {
            switch self {
            case .projects: return "Folders and worktrees"
            case .skills: return "Skill availability"
            case .plugins: return "Bundles and components"
            case .mcp: return "Servers and tools"
            case .compat: return "Scan and verify"
            case .settings: return "Preferences"
            }
        }

        var icon: String {
            switch self {
            case .projects: return "folder.fill"
            case .skills: return "book.closed.fill"
            case .plugins: return "puzzlepiece.extension.fill"
            case .mcp: return "server.rack"
            case .compat: return "checklist.checked"
            case .settings: return "gearshape.fill"
            }
        }
    }

    static let headerGrad = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.10, blue: 0.18),
            Color(red: 0.14, green: 0.18, blue: 0.30),
        ],
        startPoint: .topLeading,
        endPoint:   .bottomTrailing
    )

    var body: some View {
        Group {
            if showsExpandButton {
                compactShell
            } else {
                desktopShell
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Desktop shell

    private var desktopShell: some View {
        HStack(spacing: 0) {
            desktopSidebar
            Divider()
            VStack(spacing: 0) {
                desktopToolbar
                Divider()
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .frame(minWidth: 900, minHeight: 620)
    }

    private var desktopSidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Project Hub")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Local workspace control")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 2)

            VStack(spacing: 6) {
                ForEach(AppTab.allCases) { item in
                    desktopNavButton(item)
                }
            }

            Spacer(minLength: 12)

            VStack(spacing: 8) {
                sidebarMetric(
                    title: "Projects",
                    value: "\(projectStore.projects.count + projectStore.discovered.count)",
                    icon: "folder"
                )
                sidebarMetric(
                    title: "MCP servers",
                    value: "\(mcpStore.serverCount)",
                    icon: "server.rack"
                )
            }
        }
        .padding(16)
        .frame(width: 246)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
    }

    private func desktopNavButton(_ item: AppTab) -> some View {
        let active = tab == item
        return Button {
            withAnimation(.easeOut(duration: 0.16)) {
                tab = item
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(active ? .accentColor : .secondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(item.sidebarDetail)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if active {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .background(active ? Color.accentColor.opacity(0.10) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(active ? Color.accentColor.opacity(0.22) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func sidebarMetric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
        )
    }

    private var desktopToolbar: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(tab.title)
                    .font(.system(size: 23, weight: .semibold))
                Text(toolbarDetail(for: tab))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            toolbarPill(value: "\(projectStore.projects.count + projectStore.discovered.count)",
                        label: "projects",
                        icon: "folder")

            if mcpStore.serverCount > 0 {
                toolbarPill(value: "\(mcpStore.serverCount)",
                            label: "MCP",
                            icon: "server.rack")
            }

            Button(action: refreshWorkspace) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(projectStore.isScanning ? .accentColor : .secondary)
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(projectStore.isScanning ? 360 : 0))
                    .animation(
                        projectStore.isScanning
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: projectStore.isScanning
                    )
            }
            .buttonStyle(.plain)
            .help("Refresh")

            moreMenu(foreground: .secondary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func toolbarDetail(for item: AppTab) -> String {
        switch item {
        case .projects:
            let total = projectStore.projects.count + projectStore.discovered.count
            let hidden = projectStore.hiddenWorktrees.count
            if hidden == 0 {
                return "\(total) project\(total == 1 ? "" : "s")"
            }
            return "\(total) project\(total == 1 ? "" : "s") · \(hidden) worktree\(hidden == 1 ? "" : "s") hidden"
        case .skills:
            let count = SkillStore.deduplicatedGlobalSkills(skillStore.globalSkills).count
            return "\(count) unique skill\(count == 1 ? "" : "s")"
        case .plugins:
            return "Claude and Codex plugin bundles"
        case .mcp:
            return "\(mcpStore.serverCount) server\(mcpStore.serverCount == 1 ? "" : "s") across \(mcpStore.detectedTools.count) tool\(mcpStore.detectedTools.count == 1 ? "" : "s")"
        case .compat:
            return "Local compatibility, plugin, auth, and settings checks"
        case .settings:
            return "Project Hub preferences and local support paths"
        }
    }

    private func toolbarPill(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text("\(value) \(label)")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5))
    }

    private func refreshWorkspace() {
        projectStore.scan()
        skillStore.refresh()
        mcpStore.refresh()
    }

    // MARK: - Compact shell

    private var compactShell: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabBar
            Divider()
            content
        }
        .frame(minWidth: 480)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.cyan)
            }

            Text("Project Hub")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            let total = projectStore.projects.count + projectStore.discovered.count
            statPill(value: "\(total)",
                     label: "project\(total == 1 ? "" : "s")",
                     icon: "folder.fill")

            let serverCount = mcpStore.serverCount
            if serverCount > 0 {
                statPill(value: "\(serverCount)", label: "MCP", icon: "server.rack")
            }

            Button(action: {
                projectStore.scan()
                skillStore.refresh()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(projectStore.isScanning ? 1.0 : 0.65))
                    .rotationEffect(.degrees(projectStore.isScanning ? 360 : 0))
                    .animation(
                        projectStore.isScanning
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: projectStore.isScanning
                    )
            }
            .buttonStyle(.plain)
            .help("Refresh")

            if showsExpandButton {
                Button(action: {
                    NotificationCenter.default.post(name: .projecthubExpandWindow, object: nil)
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Expand to window")
            }

            moreMenu(foreground: .white.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(ContentView.headerGrad)
    }

    private func statPill(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
            Text("\(value) \(label)")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.88))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.14))
        .clipShape(Capsule())
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 5) {
            tabButton(title: "Projects", icon: "folder.fill",              tag: .projects)
            tabButton(title: "Skills",   icon: "book.closed.fill",         tag: .skills)
            tabButton(title: "Plugins",  icon: "puzzlepiece.extension.fill", tag: .plugins)
            tabButton(title: "MCP",      icon: "server.rack",              tag: .mcp)
            tabButton(title: "Compat",   icon: "checklist.checked",        tag: .compat)
            tabButton(title: "Settings", icon: "gearshape.fill",           tag: .settings)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func tabButton(title: String, icon: String, tag: AppTab) -> some View {
        let active = tab == tag
        return Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                self.tab = tag
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundColor(active ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 7)
            .background(
                Group {
                    if active {
                        AnyView(ContentView.headerGrad)
                    } else {
                        AnyView(Color(NSColor.controlBackgroundColor))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(active ? Color.clear : Color(NSColor.separatorColor).opacity(0.6), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab content

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .projects:
            ProjectsView(presentation: showsExpandButton ? .compact : .desktop)
        case .skills:
            GlobalSkillsView()
        case .plugins:
            PluginsView()
        case .mcp:
            GlobalMCPView()
        case .compat:
            CompatibilityView()
        case .settings:
            SettingsView()
        }
    }

    private func moreMenu(foreground: Color) -> some View {
        Menu {
            Toggle(isOn: Binding(
                get: { AppActions.launchAtLoginEnabled },
                set: { AppActions.launchAtLoginEnabled = $0 }
            )) {
                Label("Launch at login", systemImage: "power.circle")
            }
            Divider()
            Button { AppActions.about() } label: {
                Label("About Project Hub", systemImage: "info.circle")
            }
            Button { AppActions.openRepo() } label: {
                Label("Visit GitHub", systemImage: "arrow.up.right.square")
            }
            Divider()
            Button(role: .destructive) { AppActions.quit() } label: {
                Label("Quit Project Hub", systemImage: "power")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(foreground)
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More")
    }
}
