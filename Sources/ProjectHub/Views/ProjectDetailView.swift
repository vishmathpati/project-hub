import SwiftUI
import AppKit

// MARK: - Project detail: Claude/Codex sub-tabs across compact rows

struct ProjectDetailView: View {
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
    @State private var subTab: Int = 0
    @State private var reloadTick: Int = 0
    @State private var showCopySheet: Bool = false

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
        .sheet(isPresented: $showCopySheet) {
            CopyProfileSheet(
                targetProject: project,
                allProjects: projectStore.projects
            ) {
                reloadTick &+= 1
            }
        }
    }

    private var compactBody: some View {
        VStack(spacing: 0) {
            header
            Divider()
            subTabBar
            Divider()
            content
        }
    }

    private var desktopBody: some View {
        VStack(spacing: 0) {
            desktopHeader
            HStack(spacing: 0) {
                desktopSubTabSidebar
                Rectangle().fill(HubTheme.line).frame(width: 1)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(HubTheme.bg)
            }
            FooterHintBar(hints: [
                ("⌘1–7", "sections"),
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

            Button { reloadTick &+= 1 } label: {
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
            ProviderTileRow(toolIDs: projectStore.detectedToolIDs(for: project))

            HubButton(title: "Copy from…", kind: .secondary) { showCopySheet = true }

            HubButton(title: "Finder", kind: .secondary) {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.path)])
            }

            HubIconButton(systemImage: "arrow.clockwise", help: "Rescan") { reloadTick &+= 1 }

            HubButton(title: "Open project", kind: .primary) {
                AppActions.openInTerminal(project.path)
            }
        }
    }

    // MARK: - Sub-tab bar (two rows of three)

    private var subTabBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                subTabButton(title: "Health",   icon: "stethoscope",             tag: 0)
                subTabButton(title: "Skills",   icon: "book.closed.fill",        tag: 1)
                subTabButton(title: "Agents",   icon: "person.fill.viewfinder",   tag: 2)
                subTabButton(title: "MCP",      icon: "server.rack",              tag: 3)
            }
            HStack(spacing: 4) {
                subTabButton(title: "Hooks",        icon: "bolt.fill",       tag: 4)
                subTabButton(title: "Instructions", icon: "doc.text.fill",   tag: 5)
                subTabButton(title: "Rules",        icon: "list.bullet.rectangle", tag: 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func subTabButton(title: String, icon: String, tag: Int) -> some View {
        let active = subTab == tag
        return Button(action: { withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) { subTab = tag } }) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 9, weight: .semibold))
                Text(title).font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(active ? HubTheme.onAccent : HubTheme.textMid)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(
                Group {
                    if active {
                        AnyView(HubTheme.accent)
                    } else {
                        AnyView(HubTheme.raised)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .stroke(active ? Color.clear : HubTheme.line.opacity(0.5), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var desktopSubTabSidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text("This folder").groupHeadingStyle(HubTheme.headingText)
                Text("Everything here writes to files in this folder.")
                    .font(HubFont.railCaption)
                    .foregroundStyle(HubTheme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            ForEach(projectSections, id: \.tag) { item in
                desktopSubTabButton(title: item.title, tag: item.tag)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(width: HubTheme.subRailWidth)
        .background(HubTheme.panelBg)
    }

    private var projectSections: [(title: String, icon: String, tag: Int)] {
        [
            ("Health", "stethoscope", 0),
            ("Skills", "book.closed.fill", 1),
            ("Agents", "person.fill.viewfinder", 2),
            ("MCP", "server.rack", 3),
            ("Hooks", "bolt.fill", 4),
            ("Instructions", "doc.text.fill", 5),
            ("Rules", "list.bullet.rectangle", 6),
        ]
    }

    private func desktopSubTabButton(title: String, tag: Int) -> some View {
        let active = subTab == tag
        return Button {
            subTab = tag
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(active ? HubFont.navItemSel : HubFont.navItem)
                    .foregroundStyle(active ? HubTheme.accent : HubTheme.textMid)
                Spacer(minLength: 4)
                Text("⌘\(tag + 1)")
                    .font(HubFont.mono(10))
                    .foregroundStyle(HubTheme.textFaint)
            }
            .padding(.horizontal, 8)
            .frame(height: HubTheme.navRowHeight)
            .background(active ? HubTheme.accentBg : .clear)
            .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.control))
            .overlay(alignment: .leading) {
                if active {
                    Rectangle()
                        .fill(HubTheme.accent)
                        .frame(width: 2)
                        .padding(.vertical, 6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character("\(tag + 1)")), modifiers: .command)
        .animation(HubTheme.selectionAnimation, value: active)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch subTab {
        case 0: healthLanding
        case 1: SkillsView(project: project, reloadTick: reloadTick)
        case 2: AgentsView(project: project, reloadTick: $reloadTick)
        case 3: MCPView(project: project)
        case 4: HooksView(project: project)
        case 5: ClaudeMdView(project: project)
        default: CursorRulesView(project: project)
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
        let tools = projectStore.detectedToolIDs(for: project)
        let columns = [
            HubTableColumn("Provider", width: 150),
            HubTableColumn("Config file"),
            HubTableColumn("Skills", width: 52, alignment: .trailing),
            HubTableColumn("MCP", width: 44, alignment: .trailing),
            HubTableColumn("Agents", width: 56, alignment: .trailing),
            HubTableColumn("State", width: 96),
        ]
        let facts = ProjectFacts(path: project.path)

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

                        Text(ProjectFacts.configFiles(for: toolID, at: project.path))
                            .font(HubFont.machine)
                            .foregroundStyle(HubTheme.textDim)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        numericCell(facts.skills, width: 52)
                        numericCell(facts.mcpServers, width: 44)
                        numericCell(facts.agents, width: 56)

                        let configured = ProjectFacts.configFiles(for: toolID, at: project.path) != "not configured"
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
