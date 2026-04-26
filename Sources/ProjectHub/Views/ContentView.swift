import SwiftUI
import AppKit

// MARK: - Root content view (4 tabs: Projects | Skills | MCP | Settings)

struct ContentView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @EnvironmentObject var skillStore:   SkillStore
    @EnvironmentObject var mcpStore:     MCPStore
    @State private var tab: Int = 0

    static let headerGrad = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.10, blue: 0.18),
            Color(red: 0.14, green: 0.18, blue: 0.30),
        ],
        startPoint: .topLeading,
        endPoint:   .bottomTrailing
    )

    var body: some View {
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

            Button(action: {
                NotificationCenter.default.post(name: .projecthubExpandWindow, object: nil)
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Expand to window")

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
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
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
            tabButton(title: "Projects", icon: "folder.fill",              tag: 0)
            tabButton(title: "Skills",   icon: "book.closed.fill",         tag: 1)
            tabButton(title: "MCP",      icon: "server.rack",              tag: 2)
            tabButton(title: "Settings", icon: "gearshape.fill",           tag: 3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func tabButton(title: String, icon: String, tag: Int) -> some View {
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
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(active ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
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
        case 0:  ProjectsView()
        case 1:  GlobalSkillsView()
        case 2:  GlobalMCPView()
        default: SettingsView()
        }
    }
}
