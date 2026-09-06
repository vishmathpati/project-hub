import SwiftUI
import AppKit

// MARK: - Projects tab: list + drill-in

struct ProjectsView: View {
    enum Presentation {
        case compact
        case desktop
    }

    let presentation: Presentation
    @EnvironmentObject var projects: ProjectStore
    @State private var selection: Project? = nil
    @State private var renamingID: UUID? = nil
    @State private var draftName: String = ""
    @State private var showWorktrees: Bool = false

    init(presentation: Presentation = .compact) {
        self.presentation = presentation
    }

    var body: some View {
        if let project = selection {
            ProjectDetailView(
                project: project,
                onBack: { withAnimation { selection = nil } },
                presentation: presentation == .desktop ? .desktop : .compact
            )
        } else {
            if presentation == .desktop {
                desktopLanding
            } else {
                landing
            }
        }
    }

    // MARK: - Landing

    private var landing: some View {
        VStack(spacing: 0) {
            addBar
            Divider()
            let hasAny = !projects.projects.isEmpty || !projects.discovered.isEmpty
            if !hasAny && projects.isScanning {
                scanningState
            } else if !hasAny {
                emptyState
            } else {
                list
            }
        }
    }

    // MARK: - Top bar

    private var addBar: some View {
        HStack(spacing: 6) {
            if projects.isScanning {
                HStack(spacing: 5) {
                    ProgressView().scaleEffect(0.55)
                    Text("Scanning…")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } else {
                let total = projects.projects.count + projects.discovered.count
                let hidden = projects.hiddenWorktrees.count
                Text(hidden == 0
                     ? "\(total) project\(total == 1 ? "" : "s")"
                     : "\(total) project\(total == 1 ? "" : "s") · \(hidden) worktree\(hidden == 1 ? "" : "s") hidden")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { projects.scan() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(projects.isScanning)
            .help("Re-scan for projects")
            Button(action: addFolder) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add folder")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(HubTheme.onAccent)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(HubTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .help("Add a project folder")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(projects.projects) { project in
                    projectRow(for: project)
                }
                if !projects.discovered.isEmpty {
                    discoveredSectionHeader
                    ForEach(projects.discovered) { disc in
                        discoveredRow(for: disc)
                    }
                }
                if !projects.hiddenWorktrees.isEmpty {
                    worktreesDisclosure
                    if showWorktrees {
                        ForEach(projects.hiddenWorktrees) { disc in
                            worktreeRow(for: disc)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Desktop landing

    private var desktopLanding: some View {
        let hasAny = !projects.projects.isEmpty || !projects.discovered.isEmpty
        return Group {
            if !hasAny && projects.isScanning {
                scanningState
            } else if !hasAny {
                desktopEmptyState
            } else {
                desktopWorkspace
            }
        }
    }

    private var desktopWorkspace: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                desktopListHeader
                desktopList
            }
            .frame(minWidth: 380, idealWidth: 460, maxWidth: .infinity)

            Rectangle().fill(HubTheme.line).frame(width: 1)

            desktopInspector
        }
    }

    private var desktopListHeader: some View {
        HubPageHeader(title: "Projects", subtitle: projectListSummary) {
            HubIconButton(
                systemImage: "arrow.clockwise",
                help: "Re-scan for projects",
                isActive: projects.isScanning,
                spinning: projects.isScanning
            ) { projects.scan() }
            .disabled(projects.isScanning)

            HubButton(title: "Add folder", kind: .primary, action: addFolder)
        }
    }

    // MARK: - Attention strip (§7.1)
    //
    // Anything broken surfaces above the list it belongs to, with the fix
    // attached to the line. An item with no inline action belongs in Checks.

    private var attentionItems: [AttentionItem] {
        projects.projects.filter { !projects.cachedExists($0) }.map { project in
            AttentionItem(
                id: project.id.uuidString,
                subject: project.displayName,
                problem: "folder no longer exists on disk",
                evidence: shortPath(project.path),
                dismissTitle: "Remove",
                dismiss: { projects.remove(id: project.id) },
                fixTitle: "Locate…",
                fix: {
                    if let replacement = projects.pickFolder() {
                        projects.remove(id: project.id)
                        _ = projects.add(path: replacement, displayName: project.displayName)
                    }
                }
            )
        }
    }

    private var desktopList: some View {
        let tracked = projects.projects
        return ScrollView {
            VStack(alignment: .leading, spacing: HubTheme.sectionGap) {
                AttentionStrip(items: attentionItems)
                    .padding(.horizontal, HubTheme.contentPadding)
                    .padding(.top, HubTheme.contentPadding)

                VStack(alignment: .leading, spacing: 8) {
                    HubSectionHeading("Tracked", count: tracked.count)
                        .padding(.horizontal, HubTheme.contentPadding)
                    VStack(spacing: 0) {
                        ForEach(Array(tracked.enumerated()), id: \.element.id) { index, project in
                            if index > 0 { HubRowSeparator() }
                            projectRow(for: project)
                        }
                    }
                }

                if !projects.discovered.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HubSectionHeading(title: "Found on this Mac", count: projects.discovered.count) {
                            HubButton(title: "track all", kind: .accentInline) {
                                for disc in projects.discovered { _ = projects.addDiscovered(disc) }
                            }
                        }
                        .padding(.horizontal, HubTheme.contentPadding)
                        VStack(spacing: 0) {
                            ForEach(Array(projects.discovered.enumerated()), id: \.element.id) { index, disc in
                                if index > 0 { HubRowSeparator() }
                                discoveredRow(for: disc)
                            }
                        }
                    }
                }

                if !projects.hiddenWorktrees.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("\(projects.hiddenWorktrees.count) related worktree\(projects.hiddenWorktrees.count == 1 ? "" : "s") hidden")
                                .font(HubFont.machine)
                                .foregroundStyle(HubTheme.textFaint)
                            HubButton(title: showWorktrees ? "hide" : "show", kind: .inlineAction) {
                                withAnimation(HubTheme.disclosureAnimation) { showWorktrees.toggle() }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, HubTheme.contentPadding)

                        if showWorktrees {
                            VStack(spacing: 0) {
                                ForEach(Array(projects.hiddenWorktrees.enumerated()), id: \.element.id) { index, disc in
                                    if index > 0 { HubRowSeparator() }
                                    worktreeRow(for: disc)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, HubTheme.contentPadding)
        }
        .background(HubTheme.bg)
    }

    // MARK: - Inspector (§5.1 — 328pt on Projects)

    private var desktopInspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HubTheme.sectionGap) {
                if let project = selection ?? projects.projects.first {
                    projectInspector(project)
                } else {
                    overviewPanel
                    sourcePanel
                }
                if !projects.hiddenWorktrees.isEmpty {
                    worktreePanel
                }
            }
            .padding(HubTheme.contentPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: HubTheme.inspectorWidth)
        .background(HubTheme.panelBg)
    }

    /// Action-led: what you came here to do sits at the top, the inventory of
    /// what the folder can do sits under it, and the tools reading it last.
    private func projectInspector(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: HubTheme.sectionGap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(project.displayName)
                        .font(HubFont.sans(13, .semibold))
                        .foregroundStyle(HubTheme.textStrong)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Menu {
                        Button("Reveal in Finder") { revealInFinder(project) }
                        Button("Rename…") { beginRename(project) }
                        Divider()
                        Button(role: .destructive) { projects.remove(id: project.id) } label: {
                            Text("Remove from list")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(HubTheme.textMid)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
                Text(shortPath(project.path))
                    .font(HubFont.machine)
                    .foregroundStyle(HubTheme.textDim)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HubButton(title: "Open project", kind: .primary) { open(project) }
                    .frame(maxWidth: .infinity)
                HStack(spacing: 6) {
                    HubButton(title: "Reveal in Finder", kind: .secondary) { revealInFinder(project) }
                    Spacer(minLength: 0)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HubSectionHeading("What this project can do")
                VStack(spacing: 0) {
                    let facts = projects.facts(for: project) ?? ProjectFacts(path: project.path)
                    inspectorRow("Skills",        value: facts.skills == 0 ? nil : "\(facts.skills) active")
                    HubRowSeparator()
                    inspectorRow("MCP servers",   value: facts.mcpServers == 0 ? nil : "\(facts.mcpServers) declared")
                    HubRowSeparator()
                    inspectorRow("Sub-agents",    value: facts.agents == 0 ? nil : "\(facts.agents)")
                    HubRowSeparator()
                    inspectorRow("Rules & hooks", value: facts.rulesAndHooks)
                    HubRowSeparator()
                    inspectorRow("CLAUDE.md",     value: facts.claudeMdSize)
                }
                .hubCard()
            }

            VStack(alignment: .leading, spacing: 8) {
                HubSectionHeading("Tools reading this folder")
                let tools = projects.detectedToolIDs(for: project)
                VStack(spacing: 0) {
                    if tools.isEmpty {
                        HStack {
                            Text("Nothing configured here yet")
                                .font(HubFont.secondary)
                                .foregroundStyle(HubTheme.textFaint)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, HubTheme.cardPadding)
                        .frame(height: HubTheme.tableRowHeight)
                    } else {
                        ForEach(Array(tools.enumerated()), id: \.element) { index, toolID in
                            if index > 0 { HubRowSeparator() }
                            HStack(spacing: 10) {
                                ProviderTile(toolID: toolID)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ToolPalette.label(for: toolID))
                                        .font(HubFont.rowPrimary)
                                        .foregroundStyle(HubTheme.text)
                                    Text(ProjectFacts.configFiles(for: toolID, at: project.path))
                                        .font(HubFont.machine)
                                        .foregroundStyle(HubTheme.textDim)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, HubTheme.cardPadding)
                            .frame(height: HubTheme.listRowHeight)
                        }
                    }
                }
                .hubCard()
            }
        }
    }

    private func inspectorRow(_ title: String, value: String?) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(HubFont.rowPrimary)
                .foregroundStyle(HubTheme.text)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(HubFont.machine)
                    .foregroundStyle(HubTheme.textDim)
            } else {
                AbsentValue()
            }
        }
        .padding(.horizontal, HubTheme.cardPadding)
        .frame(height: 38)
    }

    private var overviewPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Overview")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if projects.isScanning {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricTile(title: "Tracked", value: "\(projects.projects.count)", icon: "folder.fill", color: .accentColor)
                metricTile(title: "Discovered", value: "\(projects.discovered.count)", icon: "magnifyingglass", color: .secondary)
                metricTile(title: "Hidden", value: "\(projects.hiddenWorktrees.count)", icon: "arrow.triangle.branch", color: .secondary)
                metricTile(title: "Total", value: "\(projects.projects.count + projects.discovered.count)", icon: "tray.full", color: .primary)
            }
        }
        .padding(14)
        .background(HubTheme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(HubTheme.line.opacity(0.35), lineWidth: 0.5)
        )
    }

    private var sourcePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Discovery sources")
                .font(.system(size: 13, weight: .semibold))
            VStack(spacing: 8) {
                sourceSummaryRow(title: "Claude Code", count: discoveryCount(for: .claudeCode), icon: "terminal.fill", color: .orange)
                sourceSummaryRow(title: "Codex", count: discoveryCount(for: .codexCLI), icon: "sparkles", color: .purple)
                sourceSummaryRow(title: "Grok CLI", count: grokProjectCount, icon: "asterisk.circle.fill", color: .primary)
                sourceSummaryRow(title: "Filesystem", count: discoveryCount(for: .filesystem), icon: "externaldrive", color: .secondary)
            }
        }
        .padding(14)
        .background(HubTheme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(HubTheme.line.opacity(0.35), lineWidth: 0.5)
        )
    }

    private var worktreePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Worktrees")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(showWorktrees ? "Hide" : "Show") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showWorktrees.toggle()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
            }
            Text("\(projects.hiddenWorktrees.count) related worktree\(projects.hiddenWorktrees.count == 1 ? "" : "s"). Add one to manage its own skills and configs.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(HubTheme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(HubTheme.line.opacity(0.35), lineWidth: 0.5)
        )
    }

    private var desktopEmptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(HubTheme.accent.opacity(0.12))
                    .frame(width: 68, height: 68)
                Image(systemName: "folder.fill.badge.plus")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(HubTheme.accent)
            }
            Text("No projects yet")
                .font(.system(size: 18, weight: .semibold))
            Text("Add a folder to start managing its local AI tool configuration.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(action: addFolder) {
                Label("Add project folder", systemImage: "plus.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(HubTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var projectListSummary: String {
        let total = projects.projects.count + projects.discovered.count
        let hidden = projects.hiddenWorktrees.count
        if hidden == 0 {
            return "\(total) project\(total == 1 ? "" : "s")"
        }
        return "\(total) project\(total == 1 ? "" : "s") · \(hidden) worktree\(hidden == 1 ? "" : "s") hidden"
    }

    private func metricTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 22, weight: .semibold))
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HubTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(HubTheme.line.opacity(0.25), lineWidth: 0.5)
        )
    }

    private func sourceSummaryRow(title: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 12))
            Spacer()
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }

    private func discoveryCount(for source: DiscoverySource) -> Int {
        projects.discovered.filter { $0.orderedSources.contains(source) }.count
    }

    private var grokProjectCount: Int {
        let tracked = projects.projects.filter { projects.detectedToolIDs(for: $0).contains("grok") }.count
        let discovered = projects.discovered.filter { $0.detectedTools.contains("grok") }.count
        return tracked + discovered
    }

    // MARK: - Discovered section header

    private var discoveredSectionHeader: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            Text("DISCOVERED ON THIS MAC")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary.opacity(0.7))
                .kerning(0.7)
            Text("\(projects.discovered.count)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.45))
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    private var worktreesDisclosure: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            Text("\(projects.hiddenWorktrees.count) related worktree\(projects.hiddenWorktrees.count == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
            Button(action: { withAnimation(.easeInOut(duration: 0.18)) { showWorktrees.toggle() } }) {
                Label(showWorktrees ? "Hide" : "Show", systemImage: showWorktrees ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help(showWorktrees ? "Hide worktree details" : "Show hidden worktree details")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(HubTheme.raised.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(HubTheme.line.opacity(0.25), lineWidth: 0.5))
        .padding(.top, projects.discovered.isEmpty ? 8 : 4)
    }

    // MARK: - Discovered row

    private func discoveredRow(for disc: DiscoveredProject) -> some View {
        HubListRow(
            status: .neutral,
            name: disc.displayName,
            providers: disc.detectedTools,
            caption: shortPath(disc.path)
        ) { _ in
            HubButton(title: "track", kind: .accentInline) { _ = projects.addDiscovered(disc) }
        }
    }

    private func worktreeRow(for disc: DiscoveredProject) -> some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.10))
                    .frame(width: 34, height: 34)
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(disc.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(shortPath(disc.path))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let mainName = disc.worktreeInfo?.mainRepositoryName {
                    Text("Worktree of \(mainName)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    ForEach(disc.orderedSources, id: \.self) { src in
                        sourceBadge(src)
                    }
                    ForEach(disc.detectedTools, id: \.self) { tool in
                        toolBadge(toolID: tool)
                    }
                    gitBadge
                }
                .padding(.top, 2)
            }
            Spacer()
            Button(action: { projects.addDiscovered(disc) }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(HubTheme.accent)
            }
            .buttonStyle(.plain)
            .help("Add this worktree as its own project")
            Button(action: { revealPathInFinder(disc.path) }) {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .help("Reveal worktree in Finder")
        }
        .padding(10)
        .background(HubTheme.raised.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(HubTheme.line.opacity(0.25), lineWidth: 0.5))
    }

    // MARK: - Added project row

    private func projectRow(for project: Project) -> some View {
        let missing    = !projects.cachedExists(project)
        let isRenaming = renamingID == project.id
        let selected   = selection?.id == project.id
        let facts      = missing ? nil : projects.facts(for: project)

        return HubListRow(
            status: missing ? .neutral : .ok,
            name: project.displayName,
            providers: missing ? [] : projects.detectedToolIDs(for: project),
            caption: missing
                ? "\(shortPath(project.path)) · missing"
                : "\(shortPath(project.path)) · \(relativeTime(project.lastOpenedAt))",
            isSelected: selected,
            isDimmed: missing
        ) { active in
            // Counts and actions share one slot — actions replace counts (§7.2).
            if active && !missing {
                HStack(spacing: 6) {
                    HubButton(title: "open", kind: .inlineAction) { open(project) }
                    HubButton(title: "finder", kind: .inlineAction) { revealInFinder(project) }
                    Menu {
                        Button("Rename…") { beginRename(project) }
                        Divider()
                        Button(role: .destructive) { projects.remove(id: project.id) } label: {
                            Text("Remove from list")
                        }
                    } label: {
                        Text("···")
                            .font(HubFont.mono(10))
                            .foregroundStyle(HubTheme.textMid)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            } else if let facts {
                HubRowCounts(counts: [
                    (facts.skills == 0 ? nil : facts.skills, "skl"),
                    (facts.mcpServers == 0 ? nil : facts.mcpServers, "mcp"),
                    (facts.agents == 0 ? nil : facts.agents, "agt"),
                ])
            }
        }
        .overlay(alignment: .leading) {
            if isRenaming {
                TextField("Name", text: $draftName, onCommit: { commitRename(project) })
                    .textFieldStyle(.roundedBorder)
                    .font(HubFont.rowPrimary)
                    .frame(width: 200)
                    .padding(.leading, 32)
            }
        }
        .onTapGesture { selection = project }
        .simultaneousGesture(TapGesture(count: 2).onEnded { open(project) })
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - States

    private var scanningState: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Scanning for projects on this Mac…")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [HubTheme.accent.opacity(0.14), HubTheme.accent.opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 64, height: 64)
                Image(systemName: "folder.fill.badge.plus")
                    .font(.system(size: 26))
                    .foregroundColor(HubTheme.accent)
            }
            Text("No projects yet")
                .font(.system(size: 14, weight: .semibold))
            Text("Add a folder to manage its skills, agents, and MCP configs.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(action: addFolder) {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add your first project")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(HubTheme.onAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(HubTheme.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    // MARK: - Badge helpers

    private func toolBadge(toolID: String) -> some View {
        let color = toolColor(toolID)
        return Text(toolLabel(toolID))
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var gitBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 8, weight: .semibold))
            Text("git")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.10))
        .clipShape(Capsule())
    }

    private func sourceBadge(_ source: DiscoverySource) -> some View {
        let (label, color): (String, Color) = {
            switch source {
            case .claudeCode: return ("Claude", .orange)
            case .codexCLI:   return ("Codex",  .purple)
            case .filesystem: return ("",        .secondary)
            }
        }()
        if label.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
        )
    }

    private func sourceColor(_ source: DiscoverySource) -> Color {
        switch source {
        case .claudeCode: return .orange
        case .codexCLI:   return .purple
        case .filesystem: return .secondary
        }
    }

    private func sourceIcon(_ source: DiscoverySource) -> String {
        switch source {
        case .claudeCode: return "terminal.fill"
        case .codexCLI:   return "sparkles"
        case .filesystem: return "folder"
        }
    }

    private func toolColor(_ toolID: String) -> Color {
        switch toolID {
        case "claude-code": return .orange
        case "codex":       return .purple
        default:            return .secondary
        }
    }

    private func toolLabel(_ toolID: String) -> String {
        switch toolID {
        case "claude-code": return "Claude"
        case "codex":       return "Codex"
        default:            return toolID
        }
    }

    // MARK: - Actions

    private func open(_ project: Project) {
        projects.touch(id: project.id)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            selection = project
        }
    }

    private func addFolder() {
        guard let path = projects.pickFolder() else { return }
        projects.add(path: path)
    }

    private func revealInFinder(_ project: Project) {
        revealPathInFinder(project.path)
    }

    private func revealPathInFinder(_ path: String) {
        NotificationCenter.default.post(name: .projecthubClosePopover, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        }
    }

    private func beginRename(_ project: Project) {
        draftName = project.displayName
        renamingID = project.id
    }

    private func commitRename(_ project: Project) {
        projects.rename(id: project.id, to: draftName)
        renamingID = nil
        draftName = ""
    }

    private func shortPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }
}

// MARK: - Project facts
//
// The counts on a project row and in the inspector. Everything here is a
// directory listing or a file-size read on the project folder itself — cheap
// enough to compute per row, and always the truth on disk rather than a cache.

struct ProjectFacts {
    let skills: Int
    let mcpServers: Int
    let agents: Int
    let rules: Int
    let hooks: Int
    let claudeMdBytes: Int?

    init(path: String) {
        let fm = FileManager.default

        func entries(_ relative: String) -> Int {
            let dir = (path as NSString).appendingPathComponent(relative)
            guard let names = try? fm.contentsOfDirectory(atPath: dir) else { return 0 }
            return names.filter { !$0.hasPrefix(".") }.count
        }

        func exists(_ relative: String) -> Bool {
            fm.fileExists(atPath: (path as NSString).appendingPathComponent(relative))
        }

        skills = entries(".claude/skills") + entries(".agents/skills") + entries(".cursor/skills")
        agents = entries(".claude/agents") + entries(".agents/agents")
        hooks  = entries(".claude/hooks")
        rules  = entries(".cursor/rules")

        var servers = 0
        for relative in [".mcp.json", ".cursor/mcp.json", ".vscode/mcp.json", ".roo/mcp.json", ".pi/mcp.json"] {
            let file = (path as NSString).appendingPathComponent(relative)
            guard let data = fm.contents(atPath: file),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            if let map = root["mcpServers"] as? [String: Any] { servers += map.count }
            else if let map = root["servers"] as? [String: Any] { servers += map.count }
        }
        for relative in [".codex/config.toml", ".grok/config.toml"] where exists(relative) {
            let file = (path as NSString).appendingPathComponent(relative)
            if let text = try? String(contentsOfFile: file, encoding: .utf8) {
                servers += text
                    .split(separator: "\n")
                    .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("[mcp_servers.") }
                    .count
            }
        }
        mcpServers = servers

        let claudeMd = (path as NSString).appendingPathComponent("CLAUDE.md")
        if let attributes = try? fm.attributesOfItem(atPath: claudeMd),
           let size = attributes[.size] as? Int {
            claudeMdBytes = size
        } else {
            claudeMdBytes = nil
        }
    }

    /// "3 · 1" — rules, then hooks. Absent when the folder has neither.
    var rulesAndHooks: String? {
        guard rules > 0 || hooks > 0 else { return nil }
        return "\(rules) · \(hooks)"
    }

    var claudeMdSize: String? {
        guard let claudeMdBytes else { return nil }
        if claudeMdBytes >= 1024 {
            return String(format: "%.1f KB", Double(claudeMdBytes) / 1024)
        }
        return "\(claudeMdBytes) B"
    }

    /// The config files a given provider actually reads in this folder.
    static func configFiles(for toolID: String, at path: String) -> String {
        let fm = FileManager.default
        let candidates: [String: [String]] = [
            "claude-code":   [".mcp.json", "CLAUDE.md", ".claude/settings.json"],
            "codex":         [".codex/config.toml", "AGENTS.md"],
            "cursor":        [".cursor/mcp.json", ".cursor/rules"],
            "vscode":        [".vscode/mcp.json"],
            "roo":           [".roo/mcp.json"],
            "grok":          [".grok/config.toml"],
            "opencode":      ["opencode.json", "AGENTS.md"],
            "antigravity":   [".agents/mcp_config.json"],
            "pi":            [".pi/mcp.json"],
            "command-code":  [".mcp.json"],
        ]
        let present = (candidates[toolID] ?? []).filter {
            fm.fileExists(atPath: (path as NSString).appendingPathComponent($0))
        }
        return present.isEmpty ? "not configured" : present.joined(separator: " · ")
    }
}
