import SwiftUI

// MARK: - Skills sub-tab (inside ProjectDetailView)
// Left: installed skills in this project. Right: global library.

struct SkillsView: View {
    let project: Project
    let reloadTick: Int

    @EnvironmentObject var skillStore: SkillStore

    @State private var editingSkill: InstalledSkill? = nil
    @State private var localTick: Int = 0

    var body: some View {
        let installed = skillStore.installedSkills(for: project.path)
        let globals   = skillStore.globalSkills

        HStack(alignment: .top, spacing: 0) {
            // MARK: Left — Installed
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader(title: "Installed", count: installed.count, color: .green)
                Divider()
                if installed.isEmpty {
                    emptyInstalled
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(installed) { skill in
                                installedRow(skill, projectPath: project.path)
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            // MARK: Right — Global library
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader(title: "Library", count: globals.count, color: .cyan)
                Divider()
                if globals.isEmpty {
                    emptyLibrary
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(globals) { skill in
                                globalRow(skill,
                                          alreadyInstalled: skillStore.isInstalled(skill, in: installed),
                                          projectPath: project.path)
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
        .id("\(reloadTick)-\(localTick)")   // force re-render when parent or local tick bumps
        .sheet(item: $editingSkill) { skill in
            SkillEditorSheet(
                skillPath: skill.claudePath ?? skill.codexPath ?? "",
                onSaved: {
                    skillStore.refresh()
                    localTick += 1
                }
            )
        }
    }

    // MARK: - Section header

    private func sectionHeader(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.primary)
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(color.opacity(0.15))
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Installed row

    private func installedRow(_ skill: InstalledSkill, projectPath: String) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    ForEach(skill.toolLabels, id: \.self) { label in
                        sourcePill(label, color: toolColor(label))
                    }
                    sourcePill(skill.scopeLabel, color: .secondary)
                    sourcePill(skill.state.label, color: stateColor(skill.state))
                    ForEach(skill.diagnostics, id: \.self) { diagnostic in
                        sourcePill(diagnostic, color: .orange)
                    }
                }
                if !skill.sourceLabel.isEmpty {
                    Text(skill.sourceLabel)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button(action: { editingSkill = skill }) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!skill.canEdit)
            .help(skill.canEdit ? "Edit skill" : (skill.readOnlyReason ?? "This skill is read-only"))
            Button(action: {
                skillStore.remove(skill: skill, from: projectPath)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
            .disabled(!skill.canRemove)
            .help(skill.canRemove ? "Remove this skill origin" : (skill.readOnlyReason ?? "This skill is read-only"))
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5))
    }

    // MARK: - Global library row

    private func globalRow(_ skill: Skill, alreadyInstalled: Bool, projectPath: String) -> some View {
        let canInstall = !skillStore.installTargets(for: skill, projectPath: projectPath).isEmpty
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                sourcePill(skill.source.label, color: sourceColor(skill.source))
            }
            Spacer()
            Button(action: {
                skillStore.install(skill: skill, to: projectPath)
            }) {
                Text(alreadyInstalled ? "Installed" : installLabel(for: skill))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor((alreadyInstalled || !canInstall) ? .secondary : .white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((alreadyInstalled || !canInstall) ? Color.secondary.opacity(0.15) : Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(alreadyInstalled || !canInstall)
            .help(canInstall ? installLabel(for: skill) : "No safe primary-tool install target for this skill source")
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5))
    }

    // MARK: - Empty states

    private var emptyInstalled: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed")
                .font(.system(size: 22))
                .foregroundColor(.secondary)
            Text("No skills installed")
                .font(.system(size: 12, weight: .semibold))
            Text("Install from the library →")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    private var emptyLibrary: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 22))
                .foregroundColor(.secondary)
            Text("No global skills")
                .font(.system(size: 12, weight: .semibold))
            Text("Add skills to ~/.claude/skills or ~/.agents/skills.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    // MARK: - Helpers

    private func sourcePill(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func sourceColor(_ source: SkillSource) -> Color {
        switch source {
        case .claudeGlobal: return .orange
        case .codexGlobal:  return .purple
        case .codexAdmin:   return .indigo
        case .codexManaged: return .teal
        case .cursorGlobal: return .blue
        }
    }

    private func toolColor(_ label: String) -> Color {
        if label.contains("Claude") { return .orange }
        if label.contains("Codex") { return .purple }
        return .secondary
    }

    private func stateColor(_ state: InstalledSkill.State) -> Color {
        switch state {
        case .active: return .green
        case .disabled: return .secondary
        case .limited: return .yellow
        case .invalid: return .red
        }
    }

    private func installLabel(for skill: Skill) -> String {
        switch skill.source {
        case .claudeGlobal:
            return "Install Claude"
        case .codexGlobal, .codexAdmin, .codexManaged:
            return "Install Codex"
        case .cursorGlobal:
            return "Inspect only"
        }
    }
}

// MARK: - Global Skills Library view (top-level Skills tab)

struct GlobalSkillsView: View {
    @EnvironmentObject var skillStore: SkillStore
    @EnvironmentObject var projectStore: ProjectStore

    var body: some View {
        VStack(spacing: 0) {
            bar
            Divider()
            if skillStore.isRefreshing {
                loadingState
            } else if skillStore.globalSkills.isEmpty {
                emptyState
            } else {
                list
            }
        }
    }

    private var bar: some View {
        HStack {
            Text("\(skillStore.globalSkills.count) global skill\(skillStore.globalSkills.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Button(action: { skillStore.refresh() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(skillStore.isRefreshing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(skillStore.globalSkills) { skill in
                    globalSkillCard(skill)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func globalSkillCard(_ skill: Skill) -> some View {
        // Count how many projects have this skill installed
        let installedCount = projectStore.projects.filter { project in
            let installed = skillStore.installedSkills(for: project.path)
            return installed.contains { $0.name == skill.name }
        }.count

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name)
                        .font(.system(size: 13, weight: .semibold))
                    sourceLabel(skill.source)
                }
                Spacer()
                if installedCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 9))
                        Text("\(installedCount)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                    .help("\(installedCount) project\(installedCount == 1 ? "" : "s") have this skill installed")
                }
            }
            if !skill.description.isEmpty {
                Text(skill.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            if !skill.triggers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(skill.triggers, id: \.self) { trigger in
                            Text(trigger)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.10))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5))
    }

    private func sourceLabel(_ source: SkillSource) -> some View {
        let (label, color): (String, Color) = {
            switch source {
            case .claudeGlobal: return ("~/.claude/skills", .orange)
            case .codexGlobal:  return ("~/.agents/skills",  .purple)
            case .codexAdmin:   return ("/etc/codex/skills", .indigo)
            case .codexManaged: return ("~/.codex/skills managed", .teal)
            case .cursorGlobal: return ("~/.cursor/skills-cursor", .blue)
            }
        }()
        return Text(label)
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(color.opacity(0.8))
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Loading global skills…")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "book.closed")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No global skills found")
                .font(.system(size: 14, weight: .semibold))
            Text("Add skill directories to:\n~/.claude/skills/\n~/.agents/skills/\n/etc/codex/skills/ (admin, read-only)\n~/.codex/skills/ (managed/legacy)")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}
