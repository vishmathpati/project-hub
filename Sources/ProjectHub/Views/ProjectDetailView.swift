import SwiftUI
import AppKit

// MARK: - Project detail: six sub-tabs across two rows

struct ProjectDetailView: View {
    let project: Project
    let onBack: () -> Void

    @EnvironmentObject var projectStore: ProjectStore
    @EnvironmentObject var skillStore:   SkillStore
    @EnvironmentObject var agentStore:   AgentStore
    @State private var subTab: Int = 0
    @State private var reloadTick: Int = 0
    @State private var showCopySheet: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            subTabBar
            Divider()
            content
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
            .help("Copy skills, agents, and rules from another project")

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

    // MARK: - Sub-tab bar (two rows of three)

    private var subTabBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                subTabButton(title: "Skills",   icon: "book.closed.fill",       tag: 0)
                subTabButton(title: "Agents",   icon: "person.fill.viewfinder",  tag: 1)
                subTabButton(title: "MCP",      icon: "server.rack",             tag: 2)
            }
            HStack(spacing: 4) {
                subTabButton(title: "Rules",    icon: "text.badge.checkmark",    tag: 3)
                subTabButton(title: "Hooks",    icon: "bolt.fill",               tag: 4)
                subTabButton(title: "CLAUDE.md",icon: "doc.text.fill",           tag: 5)
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

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch subTab {
        case 0: SkillsView(project: project, reloadTick: reloadTick)
        case 1: AgentsView(project: project, reloadTick: $reloadTick)
        case 2: MCPView(project: project)
        case 3: CursorRulesView(project: project)
        case 4: HooksView(project: project)
        default: ClaudeMdView(project: project)
        }
    }

    private func shortPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }
}
