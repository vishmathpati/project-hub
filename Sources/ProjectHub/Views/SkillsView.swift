import SwiftUI

// MARK: - Skills sub-tab (inside ProjectDetailView)
// Left: installed skills in this project. Right: global library.

struct SkillsView: View {
    let project: Project
    let reloadTick: Int

    @EnvironmentObject var skillStore: SkillStore

    var body: some View {
        let installed = skillStore.installedSkills(for: project.path)
        let globals   = skillStore.globalSkills
        let installedNames = Set(installed.map { $0.name })

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
                                          alreadyInstalled: installedNames.contains(skill.name),
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
        .id(reloadTick)   // force re-render when parent bumps tick
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
                    if skill.claudePath != nil {
                        sourcePill("Claude", color: .orange)
                    }
                    if skill.codexPath != nil {
                        sourcePill("Codex", color: .purple)
                    }
                }
            }
            Spacer()
            Button(action: {
                skillStore.remove(skillName: skill.name, from: projectPath)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Remove skill")
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5))
    }

    // MARK: - Global library row

    private func globalRow(_ skill: Skill, alreadyInstalled: Bool, projectPath: String) -> some View {
        HStack(spacing: 8) {
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
                Text(alreadyInstalled ? "Installed" : "Install")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(alreadyInstalled ? .secondary : .white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(alreadyInstalled ? Color.secondary.opacity(0.15) : Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(alreadyInstalled)
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
            Text("Add skills to ~/.claude/skills/")
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
        case .cursorGlobal: return .blue
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
            case .codexGlobal:  return ("~/.codex/skills",  .purple)
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
            Text("Add skill directories to:\n~/.claude/skills/\n~/.codex/skills/\n~/.cursor/skills-cursor/")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}
