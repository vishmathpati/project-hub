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
            Divider()
            HStack(spacing: 0) {
                desktopSubTabSidebar
                Divider()
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5))
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
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5))
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
        HStack(spacing: 12) {
            Button(action: onBack) {
                Label("Projects", systemImage: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor).opacity(0.45), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: project.exists ? "folder.fill" : "folder.badge.questionmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(project.exists ? .accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(project.displayName)
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(1)
                Text(shortPath(project.path))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 16)

            Button {
                showCopySheet = true
            } label: {
                Label("Copy from", systemImage: "arrow.down.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor).opacity(0.45), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .help("Copy Claude/Codex skills, agents, and MCP servers from another project")

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.path)])
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Open in Finder")

            Button { reloadTick &+= 1 } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(Color(NSColor.windowBackgroundColor))
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
            .foregroundColor(active ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(
                Group {
                    if active {
                        AnyView(ContentView.headerGrad)
                    } else {
                        AnyView(Color(NSColor.controlBackgroundColor))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .stroke(active ? Color.clear : Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var desktopSubTabSidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Project")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)

            ForEach(projectSections, id: \.tag) { item in
                desktopSubTabButton(title: item.title, icon: item.icon, tag: item.tag)
            }

            Spacer()
        }
        .padding(14)
        .frame(width: 190)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.38))
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

    private func desktopSubTabButton(title: String, icon: String, tag: Int) -> some View {
        let active = subTab == tag
        return Button(action: {
            withAnimation(.easeOut(duration: 0.16)) {
                subTab = tag
            }
        }) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(active ? .accentColor : .secondary)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                if active {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
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

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch subTab {
        case 0: CompatibilityView(project: project)
        case 1: SkillsView(project: project, reloadTick: reloadTick)
        case 2: AgentsView(project: project, reloadTick: $reloadTick)
        case 3: MCPView(project: project)
        case 4: HooksView(project: project)
        case 5: ClaudeMdView(project: project)
        default: CursorRulesView(project: project)
        }
    }

    private func shortPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }
}
