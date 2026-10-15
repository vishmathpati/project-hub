import SwiftUI
import AppKit

// MARK: - Project detail: Claude/Codex sub-tabs across compact rows

struct ProjectDetailView: View {
    enum ProjectSection: Int, CaseIterable, Identifiable {
        case health = 0
        case skills = 1
        case agents = 2
        case mcp = 3
        case hooks = 4
        case instructions = 5
        case rules = 6
        case commands = 7
        case overview = 8

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .health: "Health"
            case .skills: "Skills"
            case .agents: "Agents"
            case .mcp: "MCP"
            case .hooks: "Hooks"
            case .instructions: "Instructions"
            case .rules: "Rules"
            case .commands: "Commands"
            case .overview: "Overview"
            }
        }

        var icon: String {
            switch self {
            case .health: "stethoscope"
            case .skills: "book.closed.fill"
            case .agents: "person.fill.viewfinder"
            case .mcp: "server.rack"
            case .hooks: "bolt.fill"
            case .instructions: "doc.text.fill"
            case .rules: "list.bullet.rectangle"
            case .commands: "slash.circle.fill"
            case .overview: "chart.bar.doc.horizontal"
            }
        }

        var shortcutNumber: Int { rawValue + 1 }

        static let displayOrder: [ProjectSection] = [
            .overview, .skills, .mcp, .health, .agents, .hooks, .instructions, .rules, .commands,
        ]

        static let primary: [ProjectSection] = [.overview, .skills, .mcp]
        static let configuration: [ProjectSection] = [.health, .agents, .hooks, .instructions, .rules, .commands]

        static func shortcutSection(for characters: String) -> ProjectSection? {
            guard characters.count == 1,
                  let number = Int(characters),
                  (1...9).contains(number) else { return nil }
            return ProjectSection(rawValue: number - 1)
        }

        static func acceptsShortcut(modifierFlags: NSEvent.ModifierFlags) -> Bool {
            modifierFlags.intersection([.command, .option, .control, .shift]) == .command
        }
    }

    enum Presentation {
        case compact
        case desktop
    }

    let project: Project
    let onBack: () -> Void
    let presentation: Presentation

    @EnvironmentObject var projectStore: ProjectStore
    @EnvironmentObject var skillStore:   SkillStore
    @EnvironmentObject var agentStore:   AgentStore
    @State private var section: ProjectSection = .overview
    @State private var reloadTick: Int = 0
    @State private var showCopySheet: Bool = false
    @State private var detailToolIDs: [String] = []
    @State private var detailFacts: ProjectFacts?

    init(project: Project, onBack: @escaping () -> Void, presentation: Presentation = .compact) {
        self.project = project
        self.onBack = onBack
        self.presentation = presentation
    }

    var body: some View {
        Group {
            if presentation == .desktop {
                desktopBody
            } else {
                compactBody
            }
        }
        .background {
            ProjectSectionShortcutBridge(selection: $section)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        // Opening a project used to stat the folder inside the first body pass.
        // The provider table renders AbsentValue for zero, so waiting one hop costs
        // nothing visually and keeps the click responsive.
        .task(id: "\(project.path)#\(reloadTick)") {
            let snapshot = await projectStore.inspectionSnapshot(for: project)
            detailToolIDs = snapshot.toolIDs
            detailFacts = snapshot.facts
        }
        .sheet(isPresented: $showCopySheet) {
            CopyProfileSheet(
                targetProject: project,
                allProjects: projectStore.projects
            ) {
                reloadProjectCaches()
            }
        }
    }

    private func reloadProjectCaches() {
        projectStore.invalidateInspectionCache(path: project.path)
        skillStore.invalidateInstalledSkills(for: project.path)
        agentStore.invalidate(projectPath: project.path)
        reloadTick &+= 1
    }

    private var compactBody: some View {
        VStack(spacing: 0) {
            header
            Divider()
            projectSectionBar
            Divider()
            content
        }
    }

    private var desktopBody: some View {
        VStack(spacing: 0) {
            desktopHeader
            Rectangle().fill(HubTheme.line).frame(height: 1)
            projectSectionBar
            Rectangle().fill(HubTheme.line).frame(height: 1)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(HubTheme.bg)
            FooterHintBar(hints: [
                ("⌘1–9", "sections"),
                ("⌘R", "rescan"),
                ("⌘⌫", "remove project"),
            ])
        }
        .background(HubTheme.bg)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 26, height: 26)
                    .background(HubTheme.raised)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(HubTheme.line.opacity(0.5), lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(project.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Text(shortPath(project.path))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Copy profile from another project
            Button {
                showCopySheet = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Copy from…")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(HubTheme.raised)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(HubTheme.line.opacity(0.5), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help("Copy Claude/Codex skills, agents, and MCP servers from another project")

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.path)])
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open in Finder")

            Button { reloadProjectCaches() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var desktopHeader: some View {
        HubPageHeader(
            title: project.displayName,
            subtitle: shortPath(project.path),
            backTitle: "Projects",
            back: onBack
        ) {
            ProviderTileRow(toolIDs: detailToolIDs)

            HubButton(title: "Copy from…", kind: .secondary) { showCopySheet = true }

            HubButton(title: "Finder", kind: .secondary) {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.path)])
            }

            HubIconButton(systemImage: "arrow.clockwise", help: "Rescan") {
                reloadProjectCaches()
            }

            HubButton(title: "Open project", kind: .primary) {
                AppActions.openInTerminal(project.path)
            }
        }
    }

    private var projectSectionBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                ForEach(ProjectSection.primary) { item in
                    projectSectionButton(item)
                }
                configurationMenu
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Text("Section")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HubTheme.textDim)
                Menu {
                    ForEach(ProjectSection.displayOrder) { item in
                        Button {
                            section = item
                        } label: {
                            Label(item.title, systemImage: item.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: section.icon)
                        Text(section.title)
                        Spacer(minLength: 8)
                        Text("⌘\(section.shortcutNumber)")
                            .font(HubFont.mono(10))
                            .foregroundStyle(HubTheme.textFaint)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .frame(width: 230, height: HubTheme.navRowHeight)
                    .background(HubTheme.raised.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.control))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("Project section, \(section.title)")
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, HubTheme.contentPadding)
        .padding(.vertical, 8)
        .background(HubTheme.panelBg)
    }

    private func projectSectionButton(_ item: ProjectSection) -> some View {
        let active = section == item
        return Button {
            section = item
        } label: {
            Label(item.title, systemImage: item.icon)
                .font(.system(size: 12, weight: active ? .semibold : .medium))
                .foregroundStyle(active ? HubTheme.accent : HubTheme.textMid)
                .padding(.horizontal, 11)
                .frame(height: HubTheme.navRowHeight)
                .background(active ? HubTheme.accentBg : HubTheme.raised.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.control))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(HubTheme.selectionAnimation, value: active)
    }

    private var configurationMenu: some View {
        let active = ProjectSection.configuration.contains(section)
        return Menu {
            ForEach(ProjectSection.configuration) { item in
                Button {
                    section = item
                } label: {
                    Label(item.title, systemImage: item.icon)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: active ? section.icon : "slider.horizontal.3")
                Text(active ? section.title : "Configuration")
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(.system(size: 12, weight: active ? .semibold : .medium))
            .foregroundStyle(active ? HubTheme.accent : HubTheme.textMid)
            .padding(.horizontal, 11)
            .frame(height: HubTheme.navRowHeight)
            .background(active ? HubTheme.accentBg : HubTheme.raised.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.control))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch section {
        case .health: healthLanding
        case .skills: SkillsView(project: project, reloadTick: reloadTick)
        case .agents: AgentsView(project: project, reloadTick: $reloadTick)
        case .mcp: MCPView(project: project)
        case .hooks: HooksView(project: project)
        case .instructions: ClaudeMdView(project: project)
        case .rules: CursorRulesView(project: project)
        case .commands: CommandsView(project: project, reloadTick: $reloadTick)
        case .overview:
            ContextView(project: project, reloadTick: reloadTick) { destination in
                section = destination
            }
            .id(project.path)
        }
    }

    /// Health answers "is this folder set up correctly" before offering
    /// anything to edit, so the provider table leads and the scan follows.
    private var healthLanding: some View {
        VStack(spacing: 0) {
            providerCoverageTable
                .padding(HubTheme.contentPadding)
            CompatibilityView(project: project)
        }
    }

    private var providerCoverageTable: some View {
        let tools = detailToolIDs
        let columns = [
            HubTableColumn("Provider", width: 150),
            HubTableColumn("Config file"),
            HubTableColumn("Skills", width: 52, alignment: .trailing),
            HubTableColumn("MCP", width: 44, alignment: .trailing),
            HubTableColumn("Agents", width: 56, alignment: .trailing),
            HubTableColumn("State", width: 96),
        ]
        let facts = detailFacts

        return VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading("What each provider sees in this folder", count: tools.count)
            VStack(spacing: 0) {
                HubTableHeader(columns: columns)
                ForEach(Array(tools.enumerated()), id: \.element) { index, toolID in
                    if index > 0 { HubRowSeparator() }
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            ProviderTile(toolID: toolID)
                            Text(ToolPalette.label(for: toolID))
                                .font(HubFont.rowPrimary)
                                .foregroundStyle(HubTheme.text)
                                .lineLimit(1)
                        }
                        .frame(width: 150, alignment: .leading)

                        Text(projectStore.configFileSummary(for: toolID, at: project.path))
                            .font(HubFont.machine)
                            .foregroundStyle(HubTheme.textDim)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        numericCell(facts?.skills ?? 0, width: 52)
                        numericCell(facts?.mcpServers ?? 0, width: 44)
                        numericCell(facts?.agents ?? 0, width: 56)

                        let configured = projectStore.configFileSummary(for: toolID, at: project.path) != "not configured"
                        Group {
                            if configured {
                                StatusLabel(status: .ok, text: "in sync", font: HubFont.machine)
                            } else {
                                Text("not configured")
                                    .font(HubFont.machine)
                                    .foregroundStyle(HubTheme.textFaint)
                            }
                        }
                        .frame(width: 96, alignment: .leading)
                    }
                    .padding(.horizontal, HubTheme.contentPadding)
                    .frame(height: HubTheme.tableRowHeight)
                }
            }
            .hubCard()
        }
    }

    private func numericCell(_ value: Int, width: CGFloat) -> some View {
        Group {
            if value > 0 {
                Text("\(value)")
                    .font(HubFont.machine)
                    .foregroundStyle(HubTheme.text)
            } else {
                AbsentValue()
            }
        }
        .frame(width: width, alignment: .trailing)
    }

    private func shortPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }
}

/// SwiftUI registers shortcuts inside unopened `Menu` content lazily. This tiny
/// AppKit bridge owns one exact Command+digit route for the window containing the
/// active project detail, while SwiftUI remains the only owner of selection.
private struct ProjectSectionShortcutBridge: NSViewRepresentable {
    @Binding var selection: ProjectDetailView.ProjectSection

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> ProjectSectionShortcutHostView {
        let view = ProjectSectionShortcutHostView(frame: .zero)
        view.onWindowChange = { [weak coordinator = context.coordinator] window in
            coordinator?.setWindow(window)
        }
        return view
    }

    func updateNSView(_ nsView: ProjectSectionShortcutHostView, context: Context) {
        context.coordinator.selection = $selection
        context.coordinator.setWindow(nsView.window)
    }

    static func dismantleNSView(_ nsView: ProjectSectionShortcutHostView, coordinator: Coordinator) {
        nsView.onWindowChange = nil
        coordinator.stop()
    }

    final class Coordinator {
        var selection: Binding<ProjectDetailView.ProjectSection>
        private weak var window: NSWindow?
        private var monitor: Any?

        init(selection: Binding<ProjectDetailView.ProjectSection>) {
            self.selection = selection
        }

        func setWindow(_ window: NSWindow?) {
            self.window = window
            guard window != nil, monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.handle(event)
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
            window = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let window,
                  event.window === window,
                  ProjectDetailView.ProjectSection.acceptsShortcut(modifierFlags: event.modifierFlags),
                  let characters = event.charactersIgnoringModifiers,
                  let destination = ProjectDetailView.ProjectSection.shortcutSection(for: characters)
            else { return event }

            selection.wrappedValue = destination
            return nil
        }
    }
}

private final class ProjectSectionShortcutHostView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}
