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
                .foregroundColor(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(ContentView.headerGrad)
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
                Divider()
                desktopList
            }
            .frame(minWidth: 360, idealWidth: 430, maxWidth: 520)

            Divider()

            desktopInspector
        }
    }

    private var desktopListHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Project folders")
                    .font(.system(size: 13, weight: .semibold))
                Text(projectListSummary)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: { projects.scan() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(projects.isScanning ? .accentColor : .secondary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .disabled(projects.isScanning)
            .help("Re-scan for projects")

            Button(action: addFolder) {
                Label("Add", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .help("Add a project folder")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var desktopList: some View {
        ScrollView {
            VStack(spacing: 8) {
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
            .padding(14)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var desktopInspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                overviewPanel
                sourcePanel
                if !projects.hiddenWorktrees.isEmpty {
                    worktreePanel
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.25))
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
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
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
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
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
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
        )
    }

    private var desktopEmptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 68, height: 68)
                Image(systemName: "folder.fill.badge.plus")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.accentColor)
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
                    .background(Color.accentColor.opacity(0.12))
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
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor).opacity(0.25), lineWidth: 0.5)
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
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor).opacity(0.25), lineWidth: 0.5))
        .padding(.top, projects.discovered.isEmpty ? 8 : 4)
    }

    // MARK: - Discovered row

    private func discoveredRow(for disc: DiscoveredProject) -> some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(sourceColor(disc.primarySource).opacity(0.10))
                    .frame(width: 34, height: 34)
                Image(systemName: sourceIcon(disc.primarySource))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(sourceColor(disc.primarySource))
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
                HStack(spacing: 4) {
                    ForEach(disc.orderedSources, id: \.self) { src in
                        sourceBadge(src)
                    }
                    if disc.hasGit { gitBadge }
                }
                .padding(.top, 2)
            }
            Spacer()
            Button(action: { projects.addDiscovered(disc) }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .help("Add to my projects")
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5))
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
                    .foregroundColor(.accentColor)
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
        .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(NSColor.separatorColor).opacity(0.25), lineWidth: 0.5))
    }

    // MARK: - Added project row

    private func projectRow(for project: Project) -> some View {
        let missing    = !project.exists
        let isRenaming = renamingID == project.id

        return Button(action: { open(project) }) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(missing ? Color.secondary.opacity(0.18) : Color.accentColor.opacity(0.14))
                        .frame(width: 34, height: 34)
                    Image(systemName: missing ? "folder.badge.questionmark" : "folder.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(missing ? .secondary : .accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if isRenaming {
                        TextField("Name", text: $draftName, onCommit: { commitRename(project) })
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, weight: .semibold))
                    } else {
                        Text(project.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(missing ? .secondary : .primary)
                            .lineLimit(1)
                    }
                    Text(shortPath(project.path))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    // Tool badges
                    let tools = projects.detectedToolIDs(for: project)
                    if !tools.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(tools, id: \.self) { tool in
                                toolBadge(toolID: tool)
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))

                Menu {
                    Button("Open in Finder") { revealInFinder(project) }
                    Button("Rename\u{2026}") { beginRename(project) }
                    Divider()
                    Button(role: .destructive) {
                        projects.remove(id: project.id)
                    } label: { Text("Remove from list") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color(NSColor.controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5))
            .opacity(missing ? 0.75 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isRenaming)
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
                        colors: [Color.accentColor.opacity(0.14), Color.accentColor.opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 64, height: 64)
                Image(systemName: "folder.fill.badge.plus")
                    .font(.system(size: 26))
                    .foregroundColor(.accentColor)
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
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(ContentView.headerGrad)
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
