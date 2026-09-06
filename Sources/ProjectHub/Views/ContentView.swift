import SwiftUI
import AppKit

// MARK: - Root content view
//
// Eight flat tabs became three captioned groups (DESIGN.md §6). Same
// destinations, reordered by intent, with a one-line caption on each group so a
// user never has to click a tab to learn what it does.

enum HubDestination: String, CaseIterable, Identifiable, Hashable {
    case projects
    case skills
    case plugins
    case mcp
    case providers
    case checks
    case usage
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .projects:  return "Projects"
        case .skills:    return "Skills"
        case .plugins:   return "Plugins"
        case .mcp:       return "MCP servers"
        case .providers: return "Providers"
        case .checks:    return "Checks"
        case .usage:     return "Usage"
        case .settings:  return "Settings"
        }
    }

    /// The subtitle beside each page title — what this page answers.
    var pageSubtitle: String {
        switch self {
        case .projects:  return "The folders you work in"
        case .skills:    return "One library, and which providers can see each skill"
        case .plugins:   return "Bundles, expanded so you know what lands on disk"
        case .mcp:       return "Grouped by the provider that launches them, health inline"
        case .providers: return "Which apps read your folders"
        case .checks:    return "What is wrong, ranked, with the fix attached to each line"
        case .usage:     return "Read from files on this Mac · quota first, cost second"
        case .settings:  return "Paths and homes shown with the provider they belong to"
        }
    }

    var footerHints: [(key: String, label: String)] {
        switch self {
        case .projects:  return [("↑↓", "move"), ("⏎", "open"), ("T", "track"), ("⌘K", "commands")]
        case .skills:    return [("↑↓", "move"), ("I", "install"), ("E", "edit"), ("⌘⌫", "remove")]
        case .plugins:   return [("↑↓", "move"), ("→", "expand"), ("I", "install")]
        case .mcp:       return [("↑↓", "move"), ("V", "verify"), ("E", "edit"), ("C", "copy to another provider")]
        case .providers: return [("⌘K", "commands"), ("⏎", "manage provider")]
        case .checks:    return [("↑↓", "move"), ("F", "fix"), ("D", "diff"), ("⌘R", "rescan")]
        case .usage:     return [("⌘R", "refresh"), ("", "updated every 2 minutes")]
        case .settings:  return [("⌘,", "settings"), ("⌘Q", "quit")]
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @EnvironmentObject var skillStore:   SkillStore
    @EnvironmentObject var mcpStore:     MCPStore

    private let showsExpandButton: Bool

    @State private var destination: HubDestination = .projects
    @State private var railSearch: String = ""
    @State private var usagePercent: Int? = nil
    @StateObject private var pluginInventoryStore = PluginInventoryStore()
    @StateObject private var compatStore = CompatibilityStore()

    init(showsExpandButton: Bool = true) {
        self.showsExpandButton = showsExpandButton
    }

    var body: some View {
        Group {
            if showsExpandButton {
                compactShell
            } else {
                desktopShell
            }
        }
        .background(HubTheme.bg)
        .environmentObject(compatStore)
        .onAppear {
            compatStore.restore(projectRoot: nil)
            loadUsage()
        }
        .onReceive(Timer.publish(every: 120, on: .main, in: .common).autoconnect()) { _ in
            loadUsage()
        }
    }

    // MARK: - Desktop shell (§5.1)

    private var desktopShell: some View {
        HStack(spacing: 0) {
            rail
            Rectangle().fill(HubTheme.line).frame(width: 1)
            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                FooterHintBar(hints: destination.footerHints)
            }
            .background(HubTheme.bg)
        }
        .frame(
            minWidth: HubTheme.minWindowWidth,
            idealWidth: HubTheme.idealWindowWidth,
            minHeight: HubTheme.minWindowHeight,
            idealHeight: HubTheme.idealWindowHeight
        )
    }

    // MARK: - Rail (§6)

    private var rail: some View {
        VStack(alignment: .leading, spacing: 0) {
            railBrand
            HubSearchField(text: $railSearch)
                .padding(.horizontal, 12)
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    railGroup("Workspace", items: [.projects])
                    railGroup("Capabilities", items: [.skills, .plugins, .mcp, .providers])
                    railGroup("Health", items: [.checks, .usage])
                }
                .padding(.horizontal, 12)
            }

            Spacer(minLength: 8)

            Rectangle().fill(HubTheme.line).frame(height: 1)
            navRow(.settings)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(width: HubTheme.railWidth)
        .background(HubTheme.panelBg)
    }

    private var railBrand: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: HubTheme.Radius.tileLarge)
                    .fill(HubTheme.accentBg)
                Text("PH")
                    .font(HubFont.mono(9, .bold))
                    .foregroundStyle(HubTheme.accent)
            }
            .frame(width: 22, height: 22)

            Text("Project Hub")
                .font(HubFont.sans(13, .semibold))
                .foregroundStyle(HubTheme.textStrong)

            Spacer(minLength: 4)

            HubIconButton(
                systemImage: "arrow.clockwise",
                help: "Rescan",
                isActive: projectStore.isScanning,
                spinning: projectStore.isScanning,
                action: refreshWorkspace
            )
            moreMenu
        }
        .padding(.horizontal, 12)
        .frame(height: HubTheme.toolbarHeight)
    }

    private func railGroup(_ title: String, items: [HubDestination]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .groupHeadingStyle(HubTheme.headingText)
                .padding(.horizontal, 8)

            VStack(spacing: 2) {
                ForEach(items) { item in
                    navRow(item)
                }
            }
        }
    }

    @ViewBuilder
    private func navRow(_ item: HubDestination) -> some View {
        let selected = destination == item
        Button {
            destination = item
        } label: {
            HStack(spacing: 8) {
                Text(item.title)
                    .font(selected ? HubFont.navItemSel : HubFont.navItem)
                    .foregroundStyle(selected ? HubTheme.accent : HubTheme.textMid)
                Spacer(minLength: 8)
                trailingCount(for: item)
            }
            .padding(.horizontal, 8)
            .frame(height: HubTheme.navRowHeight)
            .background(selected ? HubTheme.accentBg : .clear)
            .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.control))
            .overlay(alignment: .leading) {
                if selected {
                    Rectangle()
                        .fill(HubTheme.accent)
                        .frame(width: 2)
                        .padding(.vertical, 6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(HubTheme.selectionAnimation, value: selected)
    }

    /// Every nav row carries a trailing count in mono 10. Checks carries a
    /// bad-tinted capsule badge when non-zero, a plain count when zero.
    @ViewBuilder
    private func trailingCount(for item: HubDestination) -> some View {
        switch item {
        case .checks:
            let failing = failingCheckCount
            if failing > 0 {
                Text("\(failing)")
                    .font(HubFont.mono(10, .medium))
                    .foregroundStyle(HubTheme.bad)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(HubTheme.warnBg)
                    .clipShape(Capsule())
            } else if let total = checkTotalCount {
                countLabel("\(total)")
            }
        case .usage:
            if let usagePercent {
                countLabel("\(usagePercent)%")
            }
        case .settings:
            EmptyView()
        default:
            if let value = count(for: item) {
                countLabel("\(value)")
            }
        }
    }

    private func countLabel(_ text: String) -> some View {
        Text(text)
            .font(HubFont.mono(10))
            .foregroundStyle(HubTheme.textFaint)
    }

    private func count(for item: HubDestination) -> Int? {
        switch item {
        case .projects:
            return projectStore.projects.count + projectStore.discovered.count
        case .skills:
            return SkillStore.deduplicatedGlobalSkills(skillStore.globalSkills).count
        case .plugins:
            guard let report = pluginInventoryStore.report(for: "global") else { return nil }
            return PluginInventoryGroup.groups(from: report.plugins).count
        case .mcp:
            return mcpStore.serverCount
        case .providers:
            return ProviderCatalog.specs().count
        default:
            return nil
        }
    }

    private var failingCheckCount: Int {
        compatStore.result?.issues.filter { $0.severity >= .error }.count ?? 0
    }

    private var checkTotalCount: Int? {
        compatStore.result?.issues.count
    }

    private func loadUsage() {
        Task.detached(priority: .utility) {
            let cards = UsageReader.summarize()
            let peak = cards
                .flatMap(\.windows)
                .map { Int($0.usedPercent.rounded()) }
                .max()
            await MainActor.run { usagePercent = peak }
        }
    }

    private func refreshWorkspace() {
        projectStore.scan()
        skillStore.refresh()
        mcpStore.refresh()
    }

    // MARK: - Compact shell (menu bar panel)

    private var compactShell: some View {
        VStack(spacing: 0) {
            compactHeader
            Rectangle().fill(HubTheme.line).frame(height: 1)
            content
            FooterHintBar(hints: destination.footerHints)
        }
        .frame(minWidth: 480)
        .background(HubTheme.bg)
    }

    private var compactHeader: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: HubTheme.Radius.tileLarge)
                    .fill(HubTheme.accentBg)
                Text("PH")
                    .font(HubFont.mono(9, .bold))
                    .foregroundStyle(HubTheme.accent)
            }
            .frame(width: 22, height: 22)

            Menu {
                Section("Workspace") {
                    compactMenuItem(.projects)
                }
                Section("Capabilities") {
                    compactMenuItem(.skills)
                    compactMenuItem(.plugins)
                    compactMenuItem(.mcp)
                    compactMenuItem(.providers)
                }
                Section("Health") {
                    compactMenuItem(.checks)
                    compactMenuItem(.usage)
                }
                Divider()
                compactMenuItem(.settings)
            } label: {
                Text(destination.title)
                    .font(HubFont.sans(13, .semibold))
                    .foregroundStyle(HubTheme.textStrong)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer(minLength: 8)

            HubIconButton(
                systemImage: "arrow.clockwise",
                help: "Rescan",
                isActive: projectStore.isScanning,
                spinning: projectStore.isScanning,
                action: refreshWorkspace
            )

            if showsExpandButton {
                HubIconButton(systemImage: "arrow.up.left.and.arrow.down.right", help: "Expand to window") {
                    NotificationCenter.default.post(name: .projecthubExpandWindow, object: nil)
                }
            }

            moreMenu
        }
        .padding(.horizontal, 12)
        .frame(height: HubTheme.toolbarHeight)
        .background(HubTheme.panelBg)
    }

    private func compactMenuItem(_ item: HubDestination) -> some View {
        Button(item.title) { destination = item }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch destination {
        case .projects:
            ProjectsView(presentation: showsExpandButton ? .compact : .desktop)
        case .skills:
            GlobalSkillsView()
        case .plugins:
            PluginsView(store: pluginInventoryStore)
        case .mcp:
            GlobalMCPView()
        case .providers:
            ProvidersView()
        case .checks:
            CompatibilityView()
        case .usage:
            UsageView()
        case .settings:
            SettingsView()
        }
    }

    private var moreMenu: some View {
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
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(HubTheme.textMid)
                .frame(width: HubTheme.buttonHeight, height: HubTheme.buttonHeight)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More")
    }
}
