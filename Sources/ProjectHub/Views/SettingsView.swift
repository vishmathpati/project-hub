import SwiftUI

// MARK: - Settings tab

struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // App info card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(
                                    colors: [Color.cyan.opacity(0.20), Color.blue.opacity(0.12)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 48, height: 48)
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.cyan)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Project Hub")
                                .font(.system(size: 15, weight: .bold))
                            Text("Version \(AppActions.currentVersion)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5))

                // Launch at login
                settingRow(icon: "power.circle", label: "Launch at login") {
                    Toggle("", isOn: Binding(
                        get: { AppActions.launchAtLoginEnabled },
                        set: { AppActions.launchAtLoginEnabled = $0 }
                    ))
                    .labelsHidden()
                }

                // Links
                VStack(spacing: 1) {
                    linkRow(icon: "arrow.up.right.square", label: "View on GitHub") {
                        AppActions.openRepo()
                    }
                    linkRow(icon: "info.circle", label: "About Project Hub") {
                        AppActions.about()
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5))

                // Skill search paths
                VStack(alignment: .leading, spacing: 6) {
                    Text("Skill search paths")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    let paths = [
                        "~/.claude/skills/",
                        "~/.agents/skills/",
                        "/etc/codex/skills/ (admin, read-only)",
                        "~/.codex/skills/ (managed/legacy)",
                    ]
                    ForEach(paths, id: \.self) { path in
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(path)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5))

                // Compatibility matrix
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "checklist.checked")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.accentColor)
                        Text("Compatibility matrix")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                    }

                    ForEach(compatibilityGroups, id: \.tool.id) { group in
                        compatibilityRow(tool: group.tool, surfaces: group.surfaces)
                    }
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5))

                // Quit
                Button(action: { AppActions.quit() }) {
                    Text("Quit Project Hub")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
    }

    // MARK: - Row builders

    private func settingRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 13))
            Spacer()
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5))
    }

    private func linkRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 22)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var compatibilityGroups: [(tool: CompatibilityToolID, surfaces: [CompatibilityMatrixEntry])] {
        let matrix = CompatibilityScanner.compatibilityMatrix(projectRoot: nil)
        return CompatibilityToolID.allCases.map { tool in
            (tool, matrix.filter { $0.toolID == tool })
        }
    }

    private func compatibilityRow(tool: CompatibilityToolID, surfaces: [CompatibilityMatrixEntry]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(tool.label)
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("\(surfaces.count) locations")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                capabilityLine("MCP", surfaces: surfaces.filter { $0.kind == .mcp })
                capabilityLine("Skills", surfaces: surfaces.filter { $0.kind == .skills })
                capabilityLine("Settings", surfaces: surfaces.filter { $0.kind == .settings || $0.kind == .auth })
            }
        }
        .padding(.vertical, 5)
    }

    private func capabilityLine(_ label: String, surfaces: [CompatibilityMatrixEntry]) -> some View {
        let writable = surfaces.contains { $0.canWriteSafely }
        let firstPath = surfaces.first?.displayPath ?? "UI/runtime only"
        return HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(writable ? .green : .secondary)
                .frame(width: 46, alignment: .leading)
            Text(firstPath)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Text(writable ? "file" : "UI")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(writable ? .green : .secondary)
        }
    }
}
