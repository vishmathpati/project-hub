import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { AppActions.launchAtLoginEnabled },
                    set: { AppActions.launchAtLoginEnabled = $0 }
                ))
                LabeledContent("Version", value: AppActions.currentVersion)
            }

            Section("Links") {
                Button("View on GitHub") { AppActions.openRepo() }
                Button("About Project Hub") { AppActions.about() }
            }

            Section("Skill search paths") {
                ForEach(skillPaths, id: \.self) { path in
                    Text(path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section("Provider homes") {
                ForEach(ProviderCatalog.specs(), id: \.id) { spec in
                    LabeledContent {
                        Text(spec.globalHome.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    } label: {
                        Label(spec.name, systemImage: ToolPalette.icon(for: spec.id))
                    }
                }
            }

            Section {
                Button("Quit Project Hub", role: .destructive) {
                    AppActions.quit()
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }

    private var skillPaths: [String] {
        [
            "~/.claude/skills/",
            "~/.agents/skills/",
            "~/.cursor/skills/",
            "~/.cursor/skills-cursor/",
            "~/.config/opencode/skills/",
            "~/.gemini/antigravity-cli/skills/",
            "~/.pi/agent/skills/",
            "~/.commandcode/skills/",
            "~/.grok/skills/",
            "~/.copilot/skills/",
            "/etc/codex/skills/ (admin, read-only)",
        ]
    }
}
