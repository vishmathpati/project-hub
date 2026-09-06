import SwiftUI
import AppKit

// MARK: - Settings (screen 3h)
//
// Grouped cards. Every skill path and provider home carries the tile of the
// provider it belongs to, so a path is never an orphan string (§12).

struct SettingsView: View {
    @EnvironmentObject var skillStore: SkillStore
    @EnvironmentObject var mcpStore:   MCPStore

    @State private var launchAtLogin = false
    @State private var beaconVisible = false

    var body: some View {
        VStack(spacing: 0) {
            HubPageHeader(
                title: "Settings",
                subtitle: "Version \(AppActions.currentVersion)"
            ) {
                HubButton(title: "View on GitHub", kind: .secondary) { AppActions.openRepo() }
                HubButton(title: "About", kind: .secondary) { AppActions.about() }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: HubTheme.sectionGap) {
                    general
                    skillPathsSection
                    providerHomes
                    quitSection
                }
                .padding(HubTheme.contentPadding)
            }
        }
        .background(HubTheme.bg)
        .onAppear {
            launchAtLogin = AppActions.launchAtLoginEnabled
            beaconVisible = LiveModeWindow.shared.isActive
        }
    }

    // MARK: - General

    private var general: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading("General")
            VStack(spacing: 0) {
                settingRow(
                    title: "Launch at login",
                    detail: "Project Hub starts with your Mac and waits in the menu bar",
                    isOn: Binding(
                        get: { launchAtLogin },
                        set: {
                            launchAtLogin = $0
                            AppActions.launchAtLoginEnabled = $0
                        }
                    )
                )
                HubRowSeparator()
                settingRow(
                    title: "Show the menu bar beacon",
                    detail: "A 48pt dot tracking context fill while Claude Code is frontmost",
                    isOn: Binding(
                        get: { beaconVisible },
                        set: { _ in
                            LiveModeWindow.shared.toggle(skillStore: skillStore, mcpStore: mcpStore)
                            beaconVisible = LiveModeWindow.shared.isActive
                        }
                    )
                )
            }
            .hubCard()
        }
    }

    private func settingRow(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HubFont.rowPrimary)
                    .foregroundStyle(HubTheme.text)
                Text(detail)
                    .font(HubFont.caption)
                    .foregroundStyle(HubTheme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            HubToggle(isOn: isOn)
        }
        .padding(.horizontal, HubTheme.cardPadding)
        .padding(.vertical, 11)
    }

    // MARK: - Skill search paths

    private var skillPathsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading("Where skills are read from", count: SettingsView.skillPaths.count)
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(SettingsView.skillPaths, id: \.path) { entry in
                        HStack(spacing: 8) {
                            ProviderTile(toolID: entry.toolID)
                            Text(entry.path)
                                .font(HubFont.machine)
                                .foregroundStyle(entry.readOnly ? HubTheme.textFaint : HubTheme.textDim)
                                .textSelection(.enabled)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if entry.readOnly {
                                Text("read-only")
                                    .font(HubFont.mono(9))
                                    .foregroundStyle(HubTheme.textFaint)
                            }
                            Spacer(minLength: 0)
                        }
                        .hubHitTarget(minHeight: 22)
                    }
                }
            }
            .padding(HubTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hubCard()
        }
    }

    struct SkillPathEntry {
        let toolID: String
        let path: String
        var readOnly: Bool = false
    }

    static let skillPaths: [SkillPathEntry] = [
        SkillPathEntry(toolID: "claude-code",  path: "~/.claude/skills/"),
        SkillPathEntry(toolID: "claude-code",  path: "~/.agents/skills/"),
        SkillPathEntry(toolID: "cursor",       path: "~/.cursor/skills/"),
        SkillPathEntry(toolID: "cursor",       path: "~/.cursor/skills-cursor/"),
        SkillPathEntry(toolID: "opencode",     path: "~/.config/opencode/skills/"),
        SkillPathEntry(toolID: "antigravity",  path: "~/.gemini/antigravity-cli/skills/"),
        SkillPathEntry(toolID: "pi",           path: "~/.pi/agent/skills/"),
        SkillPathEntry(toolID: "command-code", path: "~/.commandcode/skills/"),
        SkillPathEntry(toolID: "grok",         path: "~/.grok/skills/"),
        SkillPathEntry(toolID: "vscode",       path: "~/.copilot/skills/"),
        SkillPathEntry(toolID: "codex",        path: "/etc/codex/skills/", readOnly: true),
    ]

    // MARK: - Provider homes

    private var providerHomes: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading("Provider homes", count: ProviderCatalog.specs().count)
            VStack(spacing: 0) {
                ForEach(Array(ProviderCatalog.specs().enumerated()), id: \.element.id) { index, spec in
                    if index > 0 { HubRowSeparator() }
                    HStack(spacing: 10) {
                        ProviderTile(toolID: spec.id)
                        Text(spec.name)
                            .font(HubFont.rowPrimary)
                            .foregroundStyle(HubTheme.text)
                            .frame(width: 140, alignment: .leading)
                        Text(tilde(spec.globalHome))
                            .font(HubFont.machine)
                            .foregroundStyle(HubTheme.textDim)
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 12)
                        HubButton(title: "reveal", kind: .inlineAction) {
                            AppActions.openInFinder(spec.globalHome)
                        }
                    }
                    .padding(.horizontal, HubTheme.cardPadding)
                    .frame(height: HubTheme.tableRowHeight)
                }
            }
            .hubCard()
        }
    }

    // MARK: - Quit

    private var quitSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Quit Project Hub")
                    .font(HubFont.rowPrimary)
                    .foregroundStyle(HubTheme.text)
                Text("The beacon and the menu bar item close with it.")
                    .font(HubFont.caption)
                    .foregroundStyle(HubTheme.textDim)
            }
            Spacer(minLength: 12)
            HubButton(title: "Quit", kind: .destructive) { AppActions.quit() }
        }
        .padding(HubTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HubTheme.badBg)
        .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: HubTheme.Radius.card)
                .strokeBorder(HubTheme.badBorder, lineWidth: 1)
        )
    }

    private func tilde(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}
