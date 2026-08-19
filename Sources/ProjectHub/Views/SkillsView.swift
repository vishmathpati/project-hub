import SwiftUI

// MARK: - Skills sub-tab (inside ProjectDetailView)
// Left: installed skills in this project. Right: global library.

struct SkillsView: View {
    let project: Project
    let reloadTick: Int

    @EnvironmentObject var skillStore: SkillStore
    @EnvironmentObject var projectStore: ProjectStore

    @State private var editingSkill: InstalledSkill? = nil
    @State private var localTick: Int = 0


    var body: some View {
        let _ = localTick
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
            Button(action: {
                skillStore.copyAcrossProviders(
                    Skill(
                        name: skill.name,
                        description: skill.description,
                        triggers: [],
                        source: .claudeGlobal,
                        path: skill.path
                    ),
                    in: projectPath
                )
                localTick &+= 1
            }) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy this skill into Claude, Codex, and Cursor folders")
            Menu {
                ForEach(projectStore.projects.filter { $0.path != projectPath }) { target in
                    Button(target.displayName) {
                        skillStore.copyInstalled(skill, to: target.path)
                    }
                }
            } label: {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 22)
            .help("Copy this skill to another project")
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
        .background(HubTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(HubTheme.line.opacity(0.35), lineWidth: 0.5))
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
                    .background((alreadyInstalled || !canInstall) ? Color.secondary.opacity(0.15) : HubTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(alreadyInstalled || !canInstall)
            .help(canInstall ? installLabel(for: skill) : "No safe primary-tool install target for this skill source")
        }
        .padding(8)
        .background(HubTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(HubTheme.line.opacity(0.35), lineWidth: 0.5))
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
        case .providerGlobal: return .mint
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
            return "Install Cursor"
        case .providerGlobal:
            return "Install skill"
        }
    }
}

// MARK: - Global Skills Library view (top-level Skills tab)

struct GlobalSkillsView: View {
    @EnvironmentObject var skillStore: SkillStore
    @EnvironmentObject var projectStore: ProjectStore

    private enum CatalogTab: String, CaseIterable, Identifiable {
        case global
        case project

        var id: String { rawValue }

        var title: String {
            switch self {
            case .global: return "Global Skills"
            case .project: return "Project Skills"
            }
        }
    }

    @State private var selectedTab: CatalogTab = .global
    @State private var expandedGlobalSkillID: String? = nil
    @State private var expandedProjectSkillID: String? = nil
    @State private var selectedProjectID: UUID? = nil
    @State private var projectUsagesBySkillID: [String: [SkillStore.ProjectSkillUsage]] = [:]
    @State private var loadingProjectUsageIDs: Set<String> = []

    private var globalGroups: [SkillStore.GlobalSkillGroup] {
        SkillStore.deduplicatedGlobalSkills(skillStore.globalSkills)
    }

    private var selectedProject: Project? {
        if let selectedProjectID,
           let project = projectStore.projects.first(where: { $0.id == selectedProjectID }) {
            return project
        }
        return projectStore.projects.first
    }

    private var projectSkillGroups: [ProjectSkillGroup] {
        guard let selectedProject else { return [] }
        return ProjectSkillGroup.groups(
            from: skillStore.installedSkills(for: selectedProject.path)
                .filter { $0.scopeLabel == "Project" || $0.scopeLabel == "Private" }
        )
    }

    private var installCountRefreshKey: String {
        let skillKey = globalGroups.map(\.name).sorted().joined(separator: "|")
        let projectKey = projectStore.projects.map(\.path).sorted().joined(separator: "|")
        return "\(skillKey)#\(projectKey)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HubPageHeader(
                title: "Skills",
                subtitle: summaryText,
                actions: { headerActions }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: HubTheme.sectionGap) {
                    HubPageNote(
                        text: "A skill is one folder of instructions. The same folder can be visible to several providers at once — the tiles on each row are the providers that can currently see it."
                    )
                    metrics
                    switch selectedTab {
                    case .global:
                        globalContent
                    case .project:
                        projectContent
                    }
                }
                .padding(HubTheme.contentPadding)
            }
        }
        .background(HubTheme.bg)
        .onAppear {
            if selectedProjectID == nil {
                selectedProjectID = projectStore.projects.first?.id
            }
        }
        .onChange(of: projectStore.projects.map(\.id)) { _, ids in
            guard let selectedProjectID, ids.contains(selectedProjectID) else {
                self.selectedProjectID = ids.first
                return
            }
        }
        .task(id: installCountRefreshKey) {
            skillStore.refreshGlobalSkillInstallCounts(for: projectStore.projects)
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        Menu {
            ForEach(CatalogTab.allCases) { tab in
                Button(tab.title) { selectedTab = tab }
            }
        } label: {
            Text("provider: \(selectedTab == .global ? "all" : "project") ▾")
                .font(HubFont.mono(10))
                .foregroundStyle(HubTheme.textMid)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()

        if !projectStore.projects.isEmpty {
            Menu {
                ForEach(projectStore.projects) { project in
                    Button(project.displayName) { selectedProjectID = project.id }
                }
            } label: {
                Text("for: \(selectedProject?.displayName ?? "—") ▾")
                    .font(HubFont.mono(10))
                    .foregroundStyle(HubTheme.textMid)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }

        if skillStore.isRefreshingInstallCounts {
            Text("counting projects")
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.textFaint)
        }

        HubIconButton(
            systemImage: "arrow.clockwise",
            help: "Refresh skills",
            isActive: skillStore.isRefreshing,
            spinning: skillStore.isRefreshing
        ) { skillStore.refresh() }
    }

    /// Global tab counts what the library holds; project tab counts health,
    /// because that is the only scope where a skill has a state.
    @ViewBuilder
    private var metrics: some View {
        switch selectedTab {
        case .global:
            HStack(spacing: 10) {
                MetricTile(value: "\(globalGroups.count)", label: "unique skills")
                MetricTile(value: "\(skillStore.globalSkills.count)", label: "origins")
                MetricTile(value: "\(uniqueProviderCount)", label: "providers")
            }
        case .project:
            let groups = projectSkillGroups
            let working  = groups.filter { $0.state == .active }.count
            let broken   = groups.filter { $0.state == .invalid }.count
            let disabled = groups.filter { $0.state == .disabled }.count
            HStack(spacing: 10) {
                MetricTile(value: "\(working)",  label: "working",  tone: .ok)
                MetricTile(value: "\(broken)",   label: "broken",   tone: broken > 0 ? .bad : .plain)
                MetricTile(value: "\(disabled)", label: "disabled")
            }
        }
    }

    private var uniqueProviderCount: Int {
        var ids = Set<String>()
        for group in globalGroups { ids.formUnion(group.providerIDs) }
        return ids.count
    }

    private var summaryText: String {
        switch selectedTab {
        case .global:
            let count = globalGroups.count
            return "\(count) unique, across \(uniqueProviderCount) provider\(uniqueProviderCount == 1 ? "" : "s")"
        case .project:
            if let selectedProject {
                return "\(projectSkillGroups.count) project skill\(projectSkillGroups.count == 1 ? "" : "s") in \(selectedProject.displayName)"
            }
            return "No saved projects"
        }
    }

    @ViewBuilder
    private var globalContent: some View {
        if skillStore.isRefreshing {
            loadingState
        } else if globalGroups.isEmpty {
            emptyGlobalState
        } else {
            globalList
        }
    }

    private var globalList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading(title: "In your library", count: globalGroups.count) {
                Text("provider visibility →")
                    .font(HubFont.mono(9))
                    .foregroundStyle(HubTheme.textFaint)
            }
            VStack(spacing: 0) {
                ForEach(Array(globalGroups.enumerated()), id: \.element.id) { index, group in
                    if index > 0 { HubRowSeparator() }
                    globalSkillRow(group)
                }
            }
            .hubCard()
        }
    }

    private func globalSkillRow(_ group: SkillStore.GlobalSkillGroup) -> some View {
        let installedCount = skillStore.globalSkillInstallCounts[group.id] ?? 0
        let expanded = expandedGlobalSkillID == group.id
        let hasSkillMD = group.skills.contains { !$0.description.isEmpty || FileManager.default.fileExists(
            atPath: ($0.path as NSString).appendingPathComponent("SKILL.md")
        ) }

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(HubTheme.disclosureAnimation) {
                    expandedGlobalSkillID = expanded ? nil : group.id
                }
                if !expanded { loadProjectUsage(for: group) }
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(HubTheme.textFaint)
                        .frame(width: 12)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(group.name)
                                .font(HubFont.rowPrimary)
                                .foregroundStyle(HubTheme.text)
                                .lineLimit(1)
                            Text("global")
                                .font(HubFont.mono(9))
                                .foregroundStyle(HubTheme.textFaint)
                            if !hasSkillMD {
                                StatusLabel(status: .warn, text: "no SKILL.md", font: HubFont.mono(9))
                            }
                            if group.hasReadOnlyOrigins {
                                Text("read-only")
                                    .font(HubFont.mono(9))
                                    .foregroundStyle(HubTheme.textFaint)
                            }
                        }
                        if !group.primaryDescription.isEmpty {
                            Text(group.primaryDescription)
                                .font(HubFont.body)
                                .foregroundStyle(HubTheme.textDim)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 12)

                    ProviderTileRow(toolIDs: group.providerIDs)

                    Text("\(installedCount) proj")
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textDim)
                        .frame(width: 52, alignment: .trailing)
                }
                .padding(.horizontal, HubTheme.contentPadding)
                .frame(minHeight: HubTheme.listRowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                globalSkillDetail(group)
                    .padding(.horizontal, HubTheme.contentPadding)
                    .padding(.bottom, 12)
            }
        }
    }


    private func globalSkillDetail(_ group: SkillStore.GlobalSkillGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            if !group.primaryDescription.isEmpty {
                Text(group.primaryDescription)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            detailSection(title: "Origins") {
                VStack(spacing: 5) {
                    ForEach(group.skills, id: \.path) { skill in
                        originRow(
                            title: SkillStore.GlobalSkillGroup.sourceLabel(skill.source),
                            subtitle: shortPath(skill.path),
                            badges: SkillStore.GlobalSkillGroup.toolLabels(for: skill.source)
                        )
                    }
                }
            }

            detailSection(title: "Projects") {
                if loadingProjectUsageIDs.contains(group.id) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Checking saved projects")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 3)
                } else {
                    let usages = projectUsagesBySkillID[group.id] ?? []
                    if usages.isEmpty {
                        Text("No saved projects are safe for background inspection.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    } else {
                        VStack(spacing: 5) {
                            ForEach(usages) { usage in
                                projectUsageRow(usage)
                            }
                        }
                    }
                }
            }
        }
    }

    private func projectUsageRow(_ usage: SkillStore.ProjectSkillUsage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: usage.state == .installed ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(usage.state == .installed ? .accentColor : .secondary)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(usage.project.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    badge(usage.state.label, color: usage.state == .installed ? .accentColor : .secondary)
                }
                if usage.origins.isEmpty {
                    Text("Available through global skill roots")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                } else {
                    Text(usage.origins.map { "\($0.sourceLabel) · \(shortPath($0.path))" }.joined(separator: "  |  "))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
        }
        .padding(7)
        .background(HubTheme.bg.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    @ViewBuilder
    private var projectContent: some View {
        if projectStore.projects.isEmpty {
            emptyProjectState
        } else if projectSkillGroups.isEmpty {
            emptySelectedProjectState
        } else {
            projectSkillList
        }
    }

    private var projectSkillList: some View {
        let enabled  = projectSkillGroups.filter { $0.state != .disabled }
        let disabled = projectSkillGroups.filter { $0.state == .disabled }

        return VStack(alignment: .leading, spacing: HubTheme.sectionGap) {
            if !enabled.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HubSectionHeading(title: "In this project", count: enabled.count) {
                        Text("provider visibility →")
                            .font(HubFont.mono(9))
                            .foregroundStyle(HubTheme.textFaint)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(enabled.enumerated()), id: \.element.id) { index, group in
                            if index > 0 { HubRowSeparator() }
                            projectSkillRow(group)
                        }
                    }
                    .hubCard()
                }
            }
            if !disabled.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HubSectionHeading("Disabled", count: disabled.count)
                    VStack(spacing: 0) {
                        ForEach(Array(disabled.enumerated()), id: \.element.id) { index, group in
                            if index > 0 { HubRowSeparator() }
                            projectSkillRow(group)
                        }
                    }
                    .hubCard()
                }
            }
        }
    }

    private func projectSkillRow(_ group: ProjectSkillGroup) -> some View {
        let expanded = expandedProjectSkillID == group.id
        let status: HubStatus = {
            switch group.state {
            case .active:   return .ok
            case .limited:  return .warn
            case .invalid:  return .bad
            case .disabled: return .neutral
            }
        }()

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(HubTheme.disclosureAnimation) {
                    expandedProjectSkillID = expanded ? nil : group.id
                }
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(HubTheme.textFaint)
                        .frame(width: 12)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(group.name)
                                .font(HubFont.rowPrimary)
                                .foregroundStyle(HubTheme.text)
                                .lineLimit(1)
                            ForEach(group.scopeLabels, id: \.self) { label in
                                Text(label.lowercased())
                                    .font(HubFont.mono(9))
                                    .foregroundStyle(HubTheme.textFaint)
                            }
                            StatusLabel(status: status, text: group.state.label.lowercased(), font: HubFont.mono(9))
                            if group.readOnly {
                                Text("read-only")
                                    .font(HubFont.mono(9))
                                    .foregroundStyle(HubTheme.textFaint)
                            }
                        }
                        if let description = group.description, !description.isEmpty {
                            Text(description)
                                .font(HubFont.body)
                                .foregroundStyle(HubTheme.textDim)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 12)

                    ProviderTileRow(toolIDs: group.providerIDs)

                    Text("\(group.origins.count) org")
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textDim)
                        .frame(width: 52, alignment: .trailing)
                }
                .padding(.horizontal, HubTheme.contentPadding)
                .frame(minHeight: HubTheme.listRowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                projectSkillDetail(group)
                    .padding(.horizontal, HubTheme.contentPadding)
                    .padding(.bottom, 12)
            }
        }
    }


    private func projectSkillDetail(_ group: ProjectSkillGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            if let description = group.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            detailSection(title: "Project Origins") {
                VStack(spacing: 5) {
                    ForEach(group.origins) { origin in
                        originRow(
                            title: origin.sourceLabel,
                            subtitle: shortPath(origin.path),
                            badges: origin.toolLabels + [origin.scopeLabel, origin.state.label]
                        )
                    }
                }
            }
        }
    }

    private func detailSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            content()
        }
    }

    private func originRow(title: String, subtitle: String, badges: [String]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    ForEach(uniqueStrings(badges), id: \.self) { label in
                        badge(label, color: toolColor(label))
                    }
                }
                Text(subtitle)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
        }
        .padding(7)
        .background(HubTheme.bg.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func metric(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
            Text("\(value) \(label)")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.10))
        .clipShape(Capsule())
    }

    private func badge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }

    private func loadProjectUsage(for group: SkillStore.GlobalSkillGroup) {
        guard projectUsagesBySkillID[group.id] == nil,
              !loadingProjectUsageIDs.contains(group.id) else { return }

        loadingProjectUsageIDs.insert(group.id)
        let projects = projectStore.projects
        let globalSkills = group.skills
        let skillName = group.name
        let groupID = group.id

        Task {
            let usages = await Task.detached(priority: .utility) {
                SkillStore.projectUsages(
                    forSkillNamed: skillName,
                    globalSkills: globalSkills,
                    projects: projects
                )
            }.value

            await MainActor.run {
                projectUsagesBySkillID[groupID] = usages
                loadingProjectUsageIDs.remove(groupID)
            }
        }
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

    private var emptyGlobalState: some View {
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

    private var emptyProjectState: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No saved projects")
                .font(.system(size: 14, weight: .semibold))
            Text("Add a project before inspecting project-local skills.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private var emptySelectedProjectState: some View {
        VStack(spacing: 10) {
            Image(systemName: "book.closed")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No project skills")
                .font(.system(size: 14, weight: .semibold))
            Text("This project has no skills inside its project or private skill roots.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private func sourceLabelColor(_ label: String) -> Color {
        if label.contains("Claude") { return .orange }
        if label.contains("admin") { return .indigo }
        if label.contains("managed") { return .teal }
        if label.contains("Codex") { return .purple }
        if label.contains("Cursor") { return .blue }
        return .secondary
    }

    private func toolColor(_ label: String) -> Color {
        if label.contains("Claude") { return .orange }
        if label.contains("Codex") { return .purple }
        if label == "Working" || label == "Installed" { return .accentColor }
        if label == "Limited" { return .yellow }
        if label == "Broken" { return .red }
        if label == "Private" { return .blue }
        return .secondary
    }

    private func stateColor(_ label: String) -> Color {
        switch label {
        case "Working":
            return .accentColor
        case "Limited":
            return .yellow
        case "Broken":
            return .red
        default:
            return .secondary
        }
    }

    private func shortPath(_ path: String) -> String {
        CompatibilityScanner.tilde(path)
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for value in values where seen.insert(value).inserted {
            output.append(value)
        }
        return output
    }
}

private struct ProjectSkillGroup: Identifiable {
    var id: String { name.lowercased() }
    let name: String
    let origins: [InstalledSkill]

    var description: String? {
        origins.first { !$0.description.isEmpty }?.description
    }

    var toolLabels: [String] {
        unique(origins.flatMap(\.toolLabels))
    }

    var scopeLabels: [String] {
        unique(origins.map(\.scopeLabel))
    }

    var stateLabels: [String] {
        unique(origins.map { $0.state.label })
    }

    var readOnly: Bool {
        origins.contains { !$0.canEdit || !$0.canRemove }
    }

    /// Worst state across origins — a skill is only "working" when nothing
    /// backing it is broken.
    var state: InstalledSkill.State {
        if origins.contains(where: { $0.state == .invalid }) { return .invalid }
        if !origins.isEmpty, origins.allSatisfy({ $0.state == .disabled }) { return .disabled }
        if origins.contains(where: { $0.state == .limited }) { return .limited }
        return .active
    }

    /// Providers that can see this skill — the tiles on each row (§3c).
    var providerIDs: [String] {
        var ids: [String] = []
        let specs = ProviderCatalog.specs()
        for origin in origins {
            var matched = false
            for spec in specs {
                let directories = spec.globalSkillDirs + spec.projectSkillDirs
                for directory in directories where origin.path.contains(directory) {
                    if !ids.contains(spec.id) { ids.append(spec.id) }
                    matched = true
                }
            }
            if !matched {
                for label in origin.toolLabels {
                    if let id = ProjectSkillGroup.providerID(forLabel: label), !ids.contains(id) {
                        ids.append(id)
                    }
                }
            }
        }
        return ids
    }

    static func providerID(forLabel label: String) -> String? {
        let lowered = label.lowercased()
        if lowered.contains("claude")      { return "claude-code" }
        if lowered.contains("codex")       { return "codex" }
        if lowered.contains("cursor")      { return "cursor" }
        if lowered.contains("vs code")     { return "vscode" }
        if lowered.contains("opencode")    { return "opencode" }
        if lowered.contains("zed")         { return "zed" }
        if lowered.contains("antigravity") { return "antigravity" }
        if lowered.contains("grok")        { return "grok" }
        if lowered.contains("command")     { return "command-code" }
        if lowered == "pi"                 { return "pi" }
        return nil
    }

    static func groups(from origins: [InstalledSkill]) -> [ProjectSkillGroup] {
        Dictionary(grouping: origins, by: { $0.name.lowercased() })
            .values
            .compactMap { group in
                guard let first = group.sorted(by: originSort).first else { return nil }
                return ProjectSkillGroup(name: first.name, origins: group.sorted(by: originSort))
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private static func originSort(_ lhs: InstalledSkill, _ rhs: InstalledSkill) -> Bool {
        if lhs.scopeLabel != rhs.scopeLabel { return lhs.scopeLabel < rhs.scopeLabel }
        return lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for value in values where seen.insert(value).inserted {
            output.append(value)
        }
        return output
    }
}
