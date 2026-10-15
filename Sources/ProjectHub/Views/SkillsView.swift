import SwiftUI
import AppKit

// MARK: - Skills sub-tab (inside ProjectDetailView)

struct SkillsView: View {
    let project: Project
    let reloadTick: Int

    @EnvironmentObject var skillStore: SkillStore
    @EnvironmentObject var projectStore: ProjectStore

    private enum ScopeFilter: String, CaseIterable {
        case all = "All"
        case project = "This project"
        case inherited = "Inherited"
        case global = "Global"
        case managed = "Providers"

        func includes(_ group: ProjectSkillGroup) -> Bool {
            switch self {
            case .all:
                true
            case .project:
                group.originDetails.contains { $0.scope == .project || $0.scope == .projectPrivate }
            case .inherited:
                group.originDetails.contains { $0.scope == .ancestor }
            case .global:
                group.originDetails.contains { $0.scope == .global }
            case .managed:
                group.originDetails.contains { $0.scope == .managed }
            }
        }
    }

    @State private var searchText = ""
    @State private var scopeFilter: ScopeFilter = .project
    @State private var expandedSkillID: String?
    @State private var editingSkill: InstalledSkill?
    @State private var showLibrary = false

    var body: some View {
        let installed = skillStore.cachedInstalledSkills(for: project.path)
        let groups = installed.map {
            ProjectSkillGroup.mergedGroups(
                installed: $0,
                globalSkills: skillStore.globalSkills,
                projectPath: project.path
            )
        } ?? []
        let visible = groups.filter { group in
            scopeFilter.includes(group) && matchesSearch(group)
        }

        VStack(spacing: 0) {
            toolbar(groups: groups, visibleCount: visible.count)
            Rectangle().fill(HubTheme.line).frame(height: 1)

            if installed == nil {
                loadingState
            } else if visible.isEmpty {
                emptyState(hasSkills: !groups.isEmpty)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { index, group in
                            if index > 0 { HubRowSeparator() }
                            skillRow(group)
                        }
                    }
                    .hubCard()
                    .padding(HubTheme.contentPadding)
                }
            }
        }
        .background(HubTheme.bg)
        .task(id: "\(project.path)#\(reloadTick)") {
            await skillStore.loadInstalledSkills(for: project.path)
        }
        .sheet(isPresented: $showLibrary) {
            ProjectSkillLibrarySheet(project: project)
                .environmentObject(skillStore)
        }
        .sheet(item: $editingSkill) { skill in
            SkillEditorSheet(
                skillPath: skill.path,
                onSaved: {
                    skillStore.invalidateInstalledSkills(for: project.path)
                    skillStore.refresh()
                }
            )
        }
        .alert("Couldn't update skill", isPresented: Binding(
            get: { skillStore.lastError != nil },
            set: { if !$0 { skillStore.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { skillStore.lastError = nil }
        } message: {
            Text(skillStore.lastError ?? "")
        }
    }

    private func toolbar(groups: [ProjectSkillGroup], visibleCount: Int) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                skillHeading(groups: groups, visibleCount: visibleCount)
                Spacer(minLength: 12)
                searchField
                scopePicker
                addSkillButton
            }
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    skillHeading(groups: groups, visibleCount: visibleCount)
                    Spacer(minLength: 8)
                    addSkillButton
                }
                HStack(spacing: 8) {
                    searchField
                    scopePicker
                }
            }
        }
        .padding(.horizontal, HubTheme.contentPadding)
        .padding(.vertical, 10)
        .background(HubTheme.panelBg)
    }

    private func skillHeading(groups: [ProjectSkillGroup], visibleCount: Int) -> some View {
        let projectCount = groups.filter { group in
            group.originDetails.contains { $0.scope == .project || $0.scope == .projectPrivate }
        }.count
        let globalCount = groups.filter { group in
            group.originDetails.contains { $0.scope == .global }
        }.count
        let managedCount = groups.filter { group in
            group.originDetails.contains { $0.scope == .managed }
        }.count
        return VStack(alignment: .leading, spacing: 2) {
            Text("Skills")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(HubTheme.textStrong)
            Text("\(visibleCount) shown · \(projectCount) project · \(globalCount) global · \(managedCount) managed · \(groups.count) unique")
                .font(.system(size: 12))
                .foregroundStyle(HubTheme.textDim)
        }
    }

    private var searchField: some View {
        TextField("Search skills", text: $searchText)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 150, idealWidth: 210, maxWidth: 240)
    }

    private var scopePicker: some View {
        Picker("Skill scope", selection: $scopeFilter) {
            ForEach(ScopeFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .labelsHidden()
        .frame(width: 138)
    }

    private var addSkillButton: some View {
        Button {
            showLibrary = true
        } label: {
            Label("Add skill", systemImage: "plus")
                .font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Add skill to \(project.displayName)")
    }

    private func skillRow(_ group: ProjectSkillGroup) -> some View {
        let expanded = expandedSkillID == group.id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(HubTheme.disclosureAnimation) {
                    expandedSkillID = expanded ? nil : group.id
                }
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(HubTheme.textFaint)
                        .frame(width: 12)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(HubTheme.text)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)
                    ProviderTileRow(toolIDs: ProviderFamily.uniqueTileIDs(from: group.providerIDs))
                    Text(group.scopeSummary)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HubTheme.textMid)
                        .lineLimit(1)
                    StatusLabel(
                        status: group.hasInstalledOrigin ? status(for: group.state) : .neutral,
                        text: group.availabilityLabel,
                        font: HubFont.mono(9)
                    )
                }
                .padding(.horizontal, HubTheme.contentPadding)
                .frame(minHeight: HubTheme.listRowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(expanded ? "Collapse" : "Expand") \(group.name), \(group.scopeSummary)")

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    if let description = group.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundStyle(HubTheme.textMid)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(group.originDetails) { origin in
                        originRow(origin)
                    }
                }
                .padding(.horizontal, HubTheme.contentPadding)
                .padding(.bottom, 12)
            }
        }
    }

    private func originRow(_ origin: ProjectSkillOrigin) -> some View {
        let skill = origin.installed
        let copyTargets = projectStore.projects.filter { $0.path != project.path }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(origin.scope.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(HubTheme.text)
                        Text(skill.sourceLabel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(HubTheme.textMid)
                        StatusLabel(
                            status: origin.availability == .available ? .neutral : status(for: skill.state),
                            text: origin.statusLabel,
                            font: HubFont.mono(9)
                        )
                    }
                    Text(skill.path)
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textFaint)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 10)
                ProviderTileRow(toolIDs: ProviderFamily.uniqueTileIDs(from: origin.providerIDs))
            }

            HStack(spacing: 12) {
                if origin.canEdit {
                    Button("Edit") { editingSkill = skill }
                        .buttonStyle(.link)
                        .accessibilityLabel("Edit \(skill.name), \(skill.sourceLabel), \(origin.scope.title), \(skill.path)")
                }
                Button("Reveal") { reveal(skill.path) }
                    .buttonStyle(.link)
                    .accessibilityLabel("Reveal \(skill.name), \(skill.sourceLabel), \(origin.scope.title), \(skill.path) in Finder")
                Menu("Copy") {
                    ForEach(copyTargets) { target in
                        Button("Copy to \(target.displayName)") {
                            if let source = origin.sourceSkill {
                                skillStore.install(skill: source, to: target.path)
                            } else {
                                skillStore.copyInstalled(skill, to: target.path)
                            }
                        }
                    }
                    Button("Copy into all tool folders in this project") {
                        skillStore.copyAcrossProviders(origin.sourceSkill ?? copySource(for: skill), in: project.path)
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("Copy \(skill.name), \(skill.sourceLabel), \(origin.scope.title), \(skill.path)")
                if origin.canRemove {
                    Button("Remove", role: .destructive) {
                        skillStore.remove(skill: skill, from: project.path)
                    }
                    .buttonStyle(.link)
                    .accessibilityLabel("Remove \(skill.name), \(skill.sourceLabel), \(origin.scope.title), \(skill.path)")
                } else if let reason = skill.readOnlyReason ?? availableSourceNote(origin) {
                    Text(reason)
                        .font(.system(size: 12))
                        .foregroundStyle(HubTheme.textDim)
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 12, weight: .medium))
        }
        .padding(10)
        .background(HubTheme.bg.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: HubTheme.Radius.control).stroke(HubTheme.line.opacity(0.35), lineWidth: 0.5))
    }

    private var loadingState: some View {
        VStack(spacing: 9) {
            ProgressView().controlSize(.small)
            Text("Reading project skills")
                .font(.system(size: 13, weight: .semibold))
            Text("Checking exact project, inherited, global, and provider origins.")
                .font(.system(size: 12))
                .foregroundStyle(HubTheme.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyState(hasSkills: Bool) -> some View {
        ContentUnavailableView(
            hasSkills ? "No matching skills" : "No project skills",
            systemImage: "book.closed",
            description: Text(hasSkills ? "Try a different search or scope." : "Use Add skill to choose from your library.")
        )
    }

    private func matchesSearch(_ group: ProjectSkillGroup) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return group.name.localizedCaseInsensitiveContains(query)
            || (group.description?.localizedCaseInsensitiveContains(query) ?? false)
            || group.originDetails.contains {
                $0.installed.sourceLabel.localizedCaseInsensitiveContains(query)
                    || $0.installed.path.localizedCaseInsensitiveContains(query)
            }
    }

    private func status(for state: InstalledSkill.State) -> HubStatus {
        switch state {
        case .active: .ok
        case .limited: .warn
        case .invalid: .bad
        case .disabled: .neutral
        }
    }

    private func copySource(for skill: InstalledSkill) -> Skill {
        let source: SkillSource = skill.codexPath != nil ? .codexGlobal
            : skill.claudePath != nil ? .claudeGlobal : .cursorGlobal
        return Skill(name: skill.name, description: skill.description, triggers: [], source: source, path: skill.path)
    }

    private func availableSourceNote(_ origin: ProjectSkillOrigin) -> String? {
        guard origin.availability == .available else { return nil }
        return origin.scope == .managed
            ? "Available globally and managed by the provider. Reveal or copy this source."
            : "Shared global source. Reveal it, or add a project link."
    }

    private func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}

private struct ProjectSkillLibrarySheet: View {
    let project: Project

    @EnvironmentObject private var skillStore: SkillStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        let installed = skillStore.cachedInstalledSkills(for: project.path) ?? []
        let projectInstalled = ProjectSkillGroup.projectInstalledOrigins(from: installed, projectPath: project.path)
        let installedNames = SkillStore.nameIndex(projectInstalled)
        let groups = skillStore.globalSkillGroups.filter(matchesSearch)

        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add skill")
                        .font(.system(size: 17, weight: .bold))
                    Text("Choose the exact library source and provider for \(project.displayName).")
                        .font(.system(size: 12))
                        .foregroundStyle(HubTheme.textDim)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(HubTheme.contentPadding)

            HStack {
                TextField("Search the skill library", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                Text("\(groups.count) unique")
                    .font(.system(size: 12))
                    .foregroundStyle(HubTheme.textDim)
            }
            .padding(.horizontal, HubTheme.contentPadding)
            .padding(.bottom, 10)

            Rectangle().fill(HubTheme.line).frame(height: 1)

            if groups.isEmpty {
                ContentUnavailableView(
                    "No matching library skills",
                    systemImage: "magnifyingglass",
                    description: Text("Try another name or description.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(groups) { group in
                            libraryGroup(group, installedNames: installedNames)
                        }
                    }
                    .padding(HubTheme.contentPadding)
                }
            }
        }
        .frame(minWidth: 620, idealWidth: 720, minHeight: 500, idealHeight: 620)
        .background(HubTheme.bg)
        .alert("Couldn't add skill", isPresented: Binding(
            get: { skillStore.lastError != nil },
            set: { if !$0 { skillStore.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { skillStore.lastError = nil }
        } message: {
            Text(skillStore.lastError ?? "")
        }
    }

    private func libraryGroup(
        _ group: SkillStore.GlobalSkillGroup,
        installedNames: SkillStore.InstalledNameIndex
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name)
                        .font(.system(size: 13, weight: .semibold))
                    if !group.primaryDescription.isEmpty {
                        Text(group.primaryDescription)
                            .font(.system(size: 12))
                            .foregroundStyle(HubTheme.textDim)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 12)
                ProviderTileRow(toolIDs: group.tileIDs)
            }

            ForEach(group.skills, id: \.path) { skill in
                libraryOrigin(skill, installed: installedNames.contains(skill))
            }
        }
        .padding(12)
        .hubCard()
    }

    private func libraryOrigin(_ skill: Skill, installed: Bool) -> some View {
        let canInstall = !skillStore.installTargets(for: skill, projectPath: project.path).isEmpty
        let providerID = SkillStore.GlobalSkillGroup.providerID(for: skill.source)
        return HStack(spacing: 10) {
            if let providerID {
                ProviderTile(toolID: providerID)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(SkillStore.GlobalSkillGroup.sourceLabel(skill.source))
                    .font(.system(size: 12, weight: .semibold))
                Text(skill.path)
                    .font(HubFont.machine)
                    .foregroundStyle(HubTheme.textFaint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 10)
            Button(installed ? "Installed" : installLabel(for: skill)) {
                skillStore.install(skill: skill, to: project.path)
            }
            .buttonStyle(.borderedProminent)
            .tint(installed || !canInstall ? HubTheme.textFaint : HubTheme.accent)
            .disabled(installed || !canInstall)
            .accessibilityLabel("\(installed ? "Installed" : installLabel(for: skill)) \(skill.name) from \(SkillStore.GlobalSkillGroup.sourceLabel(skill.source))")
        }
        .padding(9)
        .background(HubTheme.panelBg.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.control))
    }

    private func matchesSearch(_ group: SkillStore.GlobalSkillGroup) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return group.name.localizedCaseInsensitiveContains(query)
            || group.primaryDescription.localizedCaseInsensitiveContains(query)
            || group.sourceLabels.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private func installLabel(for skill: Skill) -> String {
        switch skill.source {
        case .claudeGlobal: "Add to Claude"
        case .codexGlobal, .codexAdmin, .codexManaged: "Add to Codex"
        case .cursorGlobal: "Add to Cursor"
        case .providerGlobal: "Add skill"
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
    @State private var editingSkillPath: String?
    @State private var showInstructions = false

    private var globalGroups: [SkillStore.GlobalSkillGroup] {
        skillStore.globalSkillGroups
    }

    private var selectedProject: Project? {
        if let selectedProjectID,
           let project = projectStore.projects.first(where: { $0.id == selectedProjectID }) {
            return project
        }
        return projectStore.projects.first
    }

    private var projectSkillGroups: [ProjectSkillGroup]? {
        guard let selectedProject else { return [] }
        guard let installed = skillStore.cachedInstalledSkills(for: selectedProject.path) else { return nil }
        return ProjectSkillGroup.groups(
            from: installed.filter { $0.scopeLabel == "Project" || $0.scopeLabel == "Private" }
        )
    }

    /// A hash instead of a joined string: the string form built ~33 KB and sorted
    /// both lists on every render just to feed `.task(id:)`.
    private var installCountRefreshKey: Int {
        var hasher = Hasher()
        hasher.combine(skillStore.globalSkillGroups.count)
        for group in skillStore.globalSkillGroups { hasher.combine(group.id) }
        hasher.combine(projectStore.projects.count)
        for project in projectStore.projects { hasher.combine(project.path) }
        return hasher.finalize()
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
        .sheet(item: Binding(
            get: { editingSkillPath.map { SkillsIdentifiablePath(path: $0) } },
            set: { editingSkillPath = $0?.path }
        )) { item in
            SkillEditorSheet(skillPath: item.path) {
                skillStore.refresh()
            }
            .frame(width: 520, height: 560)
        }
        .sheet(isPresented: $showInstructions) {
            if let project = selectedProject {
                ClaudeMdView(project: project)
                    .frame(minWidth: 640, minHeight: 560)
            }
        }
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
        .task(id: selectedProject?.path) {
            guard let path = selectedProject?.path else { return }
            await skillStore.loadInstalledSkills(for: path)
        }
        .alert("Couldn't update skill", isPresented: Binding(
            get: { skillStore.lastError != nil },
            set: { if !$0 { skillStore.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { skillStore.lastError = nil }
        } message: {
            Text(skillStore.lastError ?? "")
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        Menu {
            Button("Global") { selectedTab = .global }
            ForEach(projectStore.projects) { project in
                Button(project.displayName) {
                    selectedTab = .project
                    selectedProjectID = project.id
                }
            }
        } label: {
            Text("for: \(selectedTab == .global ? "Global" : (selectedProject?.displayName ?? "—")) ▾")
                .font(HubFont.mono(10))
                .foregroundStyle(HubTheme.textMid)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()

        if skillStore.isRefreshingInstallCounts {
            Text("counting projects")
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.textFaint)
        }

        if selectedTab == .project, selectedProject != nil {
            HubButton(title: "Instructions", kind: .secondary) { showInstructions = true }
        }

        HubIconButton(
            systemImage: "arrow.clockwise",
            help: "Refresh skills",
            isActive: skillStore.isRefreshing,
            spinning: skillStore.isRefreshing
        ) { skillStore.refresh() }
    }

    private var uniqueProviderCount: Int {
        skillStore.globalSkillProviderCount
    }

    private var summaryText: String {
        switch selectedTab {
        case .global:
            let count = globalGroups.count
            return "\(count) unique, across \(uniqueProviderCount) provider\(uniqueProviderCount == 1 ? "" : "s")"
        case .project:
            if let selectedProject {
                guard let groups = projectSkillGroups else {
                    return "Reading \(selectedProject.displayName)…"
                }
                return "\(groups.count) project skill\(groups.count == 1 ? "" : "s") in \(selectedProject.displayName)"
            }
            return "No saved projects"
        }
    }

    @ViewBuilder
    private var globalContent: some View {
        if globalGroups.isEmpty {
            if skillStore.isRefreshing {
                loadingState("Loading global skills…")
            } else {
                emptyGlobalState
            }
        } else {
            globalList
        }
    }

    private var globalList: some View {
        let copyTargets = projectStore.projects
        return VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading("In your library", count: globalGroups.count)
            LazyVStack(spacing: 0) {
                ForEach(Array(globalGroups.enumerated()), id: \.element.id) { index, group in
                    if index > 0 { HubRowSeparator() }
                    globalSkillRow(group, copyTargets: copyTargets)
                }
            }
            .hubCard()
        }
    }

    private func globalSkillRow(_ group: SkillStore.GlobalSkillGroup, copyTargets: [Project]) -> some View {
        let installedCount = skillStore.globalSkillInstallCounts[group.id] ?? 0
        let expanded = expandedGlobalSkillID == group.id
        let hasSkillMD = group.skills.contains { skillStore.skillMarkdownExists($0) }

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 4) {
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
                                if !hasSkillMD {
                                    StatusLabel(status: .warn, text: "no SKILL.md", font: HubFont.mono(9))
                                }
                                if group.hasReadOnlyOrigins {
                                    Text("read-only")
                                        .font(HubFont.mono(9))
                                        .foregroundStyle(HubTheme.textFaint)
                                }
                            }
                        }

                        Spacer(minLength: 12)

                        ProviderTileRow(toolIDs: group.tileIDs)

                        Text("\(installedCount) proj")
                            .font(HubFont.machine)
                            .foregroundStyle(HubTheme.textDim)
                            .frame(width: 52, alignment: .trailing)
                    }
                    .padding(.leading, HubTheme.contentPadding)
                    .frame(minHeight: HubTheme.listRowHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                globalSkillActions(group, copyTargets: copyTargets)
                    .padding(.trailing, HubTheme.contentPadding)
            }

            if expanded {
                globalSkillDetail(group)
                    .padding(.horizontal, HubTheme.contentPadding)
                    .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private func globalSkillActions(_ group: SkillStore.GlobalSkillGroup, copyTargets: [Project]) -> some View {
        let removable = group.skills.filter { $0.source != .codexAdmin && $0.source != .codexManaged }
        Menu {
            ForEach(copyTargets) { project in
                Button("Copy to \(project.displayName)") {
                    if let skill = group.skills.first {
                        skillStore.copy(skill, to: project.path)
                        reloadUsage(for: group)
                    }
                }
            }
            if let project = selectedProject, let skill = group.skills.first {
                Button("Copy into all tool folders in \(project.displayName)") {
                    skillStore.copyAcrossProviders(skill, in: project.path)
                    reloadUsage(for: group)
                }
            }
            if let skill = group.skills.first(where: { skillStore.skillMarkdownExists($0) }) {
                Button("Edit SKILL.md") {
                    editingSkillPath = skill.path
                }
            }
            if !removable.isEmpty {
                Divider()
                ForEach(removable, id: \.path) { skill in
                    Button("Remove \(SkillStore.GlobalSkillGroup.sourceLabel(skill.source))", role: .destructive) {
                        skillStore.removeOrigin(skill)
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(HubTheme.textMid)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }


    private func globalSkillDetail(_ group: SkillStore.GlobalSkillGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            detailSection(title: "Origins") {
                VStack(spacing: 5) {
                    ForEach(group.skills, id: \.path) { skill in
                        originRow(
                            title: SkillStore.GlobalSkillGroup.sourceLabel(skill.source),
                            path: skill.path,
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
                                projectUsageRow(usage, group: group)
                            }
                        }
                    }
                }
            }
        }
    }

    private func projectUsageRow(
        _ usage: SkillStore.ProjectSkillUsage,
        group: SkillStore.GlobalSkillGroup
    ) -> some View {
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
                    Text(usage.origins.map(\.sourceLabel).joined(separator: " · "))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if usage.state == .available, let skill = group.skills.first {
                HubButton(title: "copy here", kind: .accentInline) {
                    skillStore.copy(skill, to: usage.project.path)
                    reloadUsage(for: group)
                }
            } else if usage.state == .installed {
                HubButton(title: "remove", kind: .inlineAction) {
                    skillStore.remove(skillName: group.name, from: usage.project.path)
                    reloadUsage(for: group)
                }
            }
            if let path = usage.origins.first?.path {
                PathOverflowMenu(path: path)
            }
        }
        .padding(7)
        .background(HubTheme.bg.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    @ViewBuilder
    private var projectContent: some View {
        if projectStore.projects.isEmpty {
            emptyProjectState
        } else if let groups = projectSkillGroups {
            if groups.isEmpty {
                emptySelectedProjectState
            } else {
                projectSkillList(groups)
            }
        } else {
            loadingState("Reading project skills…")
        }
    }

    private func projectSkillList(_ groups: [ProjectSkillGroup]) -> some View {
        let enabled  = groups.filter { $0.state != .disabled }
        let disabled = groups.filter { $0.state == .disabled }
        let copyTargets = projectStore.projects.filter { $0.path != selectedProject?.path }

        return VStack(alignment: .leading, spacing: HubTheme.sectionGap) {
            if !enabled.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HubSectionHeading("In this project", count: enabled.count)
                    LazyVStack(spacing: 0) {
                        ForEach(Array(enabled.enumerated()), id: \.element.id) { index, group in
                            if index > 0 { HubRowSeparator() }
                            projectSkillRow(group, copyTargets: copyTargets)
                        }
                    }
                    .hubCard()
                }
            }
            if !disabled.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HubSectionHeading("Disabled", count: disabled.count)
                    LazyVStack(spacing: 0) {
                        ForEach(Array(disabled.enumerated()), id: \.element.id) { index, group in
                            if index > 0 { HubRowSeparator() }
                            projectSkillRow(group, copyTargets: copyTargets)
                        }
                    }
                    .hubCard()
                }
            }
        }
    }

    private func projectSkillRow(_ group: ProjectSkillGroup, copyTargets: [Project]) -> some View {
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
            HStack(alignment: .center, spacing: 4) {
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
                        }

                        Spacer(minLength: 12)

                        ProviderTileRow(toolIDs: ProviderFamily.uniqueTileIDs(from: group.providerIDs))

                        Text("\(group.origins.count) org")
                            .font(HubFont.machine)
                            .foregroundStyle(HubTheme.textDim)
                            .frame(width: 52, alignment: .trailing)
                    }
                    .padding(.leading, HubTheme.contentPadding)
                    .frame(minHeight: HubTheme.listRowHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                projectSkillActions(group, copyTargets: copyTargets)
                    .padding(.trailing, HubTheme.contentPadding)
            }

            if expanded {
                projectSkillDetail(group)
                    .padding(.horizontal, HubTheme.contentPadding)
                    .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private func projectSkillActions(_ group: ProjectSkillGroup, copyTargets: [Project]) -> some View {
        Menu {
            if let project = selectedProject, let origin = group.origins.first {
                ForEach(copyTargets) { target in
                    Button("Copy to \(target.displayName)") {
                        skillStore.copyInstalled(origin, to: target.path)
                    }
                }
                Button("Copy into all tool folders") {
                    skillStore.copyAcrossProviders(
                        Skill(
                            name: origin.name,
                            description: origin.description,
                            triggers: [],
                            source: .claudeGlobal,
                            path: origin.path
                        ),
                        in: project.path
                    )
                }
                if origin.canEdit {
                    Button("Edit SKILL.md") {
                        editingSkillPath = origin.path
                    }
                }
                if origin.canRemove {
                    Divider()
                    Button("Remove from this project", role: .destructive) {
                        skillStore.remove(skill: origin, from: project.path)
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(HubTheme.textMid)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }


    private func projectSkillDetail(_ group: ProjectSkillGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            detailSection(title: "Project Origins") {
                VStack(spacing: 5) {
                    ForEach(group.origins) { origin in
                        originRow(
                            title: origin.sourceLabel,
                            path: origin.path,
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

    private func originRow(title: String, path: String, badges: [String]) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    ForEach(uniqueStrings(badges), id: \.self) { label in
                        badge(label, color: toolColor(label))
                    }
                }
            }
            Spacer(minLength: 8)
            PathOverflowMenu(path: path)
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

    private func reloadUsage(for group: SkillStore.GlobalSkillGroup) {
        projectUsagesBySkillID[group.id] = nil
        loadingProjectUsageIDs.remove(group.id)
        loadProjectUsage(for: group)
        skillStore.refreshGlobalSkillInstallCounts(for: projectStore.projects)
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

    private func loadingState(_ label: String) -> some View {
        VStack(spacing: 10) {
            ProgressView()
            Text(label)
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

enum SkillOriginScope: Equatable {
    case project
    case projectPrivate
    case ancestor
    case global
    case managed
    case unknown(String)

    var title: String {
        switch self {
        case .project: "This project"
        case .projectPrivate: "Project private"
        case .ancestor: "Inherited"
        case .global: "Global"
        case .managed: "Provider managed"
        case .unknown(let label): label.isEmpty ? "Other source" : label
        }
    }

    fileprivate var sortOrder: Int {
        switch self {
        case .project: 0
        case .projectPrivate: 1
        case .ancestor: 2
        case .global: 3
        case .managed: 4
        case .unknown: 5
        }
    }
}

enum ProjectSkillOriginAvailability: Equatable {
    case installed
    case available
}

struct ProjectSkillOrigin: Identifiable {
    var id: String { installed.originID }
    let installed: InstalledSkill
    let scope: SkillOriginScope
    let availability: ProjectSkillOriginAvailability
    let sourceSkill: Skill?

    init(
        installed: InstalledSkill,
        scope: SkillOriginScope,
        availability: ProjectSkillOriginAvailability = .installed,
        sourceSkill: Skill? = nil
    ) {
        self.installed = installed
        self.scope = scope
        self.availability = availability
        self.sourceSkill = sourceSkill
    }

    var providerIDs: [String] {
        ProjectSkillGroup.providerIDs(for: installed)
    }

    var canEdit: Bool { availability == .installed && installed.canEdit }
    var canRemove: Bool { availability == .installed && installed.canRemove }
    var statusLabel: String { availability == .available ? "available" : installed.state.label.lowercased() }
}

struct ProjectSkillGroup: Identifiable {
    var id: String { name.lowercased() }
    let name: String
    let originDetails: [ProjectSkillOrigin]

    init(name: String, originDetails: [ProjectSkillOrigin]) {
        self.name = name
        self.originDetails = originDetails
    }

    var origins: [InstalledSkill] {
        originDetails.map(\.installed)
    }

    var installedOrigins: [ProjectSkillOrigin] {
        originDetails.filter { $0.availability == .installed }
    }

    var hasInstalledOrigin: Bool { !installedOrigins.isEmpty }

    var availabilityLabel: String {
        hasInstalledOrigin ? state.label.lowercased() : "available"
    }

    var description: String? {
        origins.first { !$0.description.isEmpty }?.description
    }

    var toolLabels: [String] {
        unique(origins.flatMap(\.toolLabels))
    }

    var scopeLabels: [String] {
        unique(origins.map(\.scopeLabel))
    }

    var scopeSummary: String {
        unique(originDetails.map { $0.scope.title }).joined(separator: " · ")
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
        let installed = installedOrigins.map(\.installed)
        if installed.contains(where: { $0.state == .invalid }) { return .invalid }
        if !installed.isEmpty, installed.allSatisfy({ $0.state == .disabled }) { return .disabled }
        if installed.contains(where: { $0.state == .limited }) { return .limited }
        return .active
    }

    /// Provider id to skill directory, built once per process. Deriving this per
    /// row rebuilt the whole catalog for every visible row on every render.
    private static let providerDirectories: [(id: String, directory: String)] = {
        var out: [(id: String, directory: String)] = []
        for spec in ProviderCatalog.specs() {
            for directory in spec.globalSkillDirs + spec.projectSkillDirs {
                out.append((spec.id, directory))
            }
        }
        return out
    }()

    /// Providers that can see this skill — the tiles on each row (§3c).
    var providerIDs: [String] {
        var ids: [String] = []
        for origin in origins {
            for id in Self.providerIDs(for: origin) where !ids.contains(id) {
                ids.append(id)
            }
        }
        return ids
    }

    static func providerIDs(for origin: InstalledSkill) -> [String] {
        var ids: [String] = []
        var matched = false
        for entry in providerDirectories where isWithin(origin.path, root: entry.directory) {
            if !ids.contains(entry.id) { ids.append(entry.id) }
            matched = true
        }
        if !matched {
            for label in origin.toolLabels {
                if let id = providerID(forLabel: label), !ids.contains(id) {
                    ids.append(id)
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

    static func groups(
        from origins: [InstalledSkill],
        projectPath: String? = nil,
        globalRoots: [String] = defaultGlobalRoots
    ) -> [ProjectSkillGroup] {
        groups(from: origins.map {
            origin(from: $0, projectPath: projectPath, globalRoots: globalRoots)
        })
    }

    static func mergedGroups(
        installed: [InstalledSkill],
        globalSkills: [Skill],
        projectPath: String,
        globalRoots: [String] = defaultGlobalRoots
    ) -> [ProjectSkillGroup] {
        var details = installed.map {
            origin(from: $0, projectPath: projectPath, globalRoots: globalRoots)
        }
        var seen = Set(details.map(dedupeKey))
        for skill in globalSkills {
            let available = availableOrigin(from: skill)
            guard seen.insert(dedupeKey(available)).inserted else { continue }
            details.append(available)
        }
        return groups(from: details)
    }

    private static func groups(from details: [ProjectSkillOrigin]) -> [ProjectSkillGroup] {
        Dictionary(grouping: details, by: { $0.installed.name.lowercased() })
            .values
            .compactMap { group in
                let sorted = group.sorted(by: originSort)
                guard let first = sorted.first else { return nil }
                return ProjectSkillGroup(
                    name: first.installed.name,
                    originDetails: sorted
                )
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private static func availableOrigin(from skill: Skill) -> ProjectSkillOrigin {
        let managed = skill.source == .codexAdmin || skill.source == .codexManaged
        let sourceLabel = SkillStore.GlobalSkillGroup.sourceLabel(skill.source)
        let installed = InstalledSkill(
            originID: "available|\(skill.source.rawValue)|\(standardized(skill.path))",
            name: skill.name,
            description: skill.description,
            claudePath: skill.source == .claudeGlobal ? skill.path : nil,
            codexPath: [.codexGlobal, .codexAdmin, .codexManaged].contains(skill.source) ? skill.path : nil,
            path: skill.path,
            skillMDPath: (skill.path as NSString).appendingPathComponent("SKILL.md"),
            sourceLabel: sourceLabel,
            scopeLabel: managed ? "Managed" : "Global",
            toolLabels: SkillStore.GlobalSkillGroup.toolLabels(for: skill.source),
            state: .active,
            version: nil,
            diagnostics: [],
            canEdit: false,
            canRemove: false,
            readOnlyReason: managed
                ? "Available globally and managed by the provider. Reveal or copy this source."
                : "Shared global source. Reveal it, or add a project link."
        )
        return ProjectSkillOrigin(
            installed: installed,
            scope: managed ? .managed : .global,
            availability: .available,
            sourceSkill: skill
        )
    }

    private static func origin(
        from installed: InstalledSkill,
        projectPath: String?,
        globalRoots: [String]
    ) -> ProjectSkillOrigin {
        let scope = classify(installed, projectPath: projectPath, globalRoots: globalRoots)
        let availability: ProjectSkillOriginAvailability = scope == .global || scope == .managed
            ? .available
            : .installed
        return ProjectSkillOrigin(installed: installed, scope: scope, availability: availability)
    }

    private static func dedupeKey(_ origin: ProjectSkillOrigin) -> String {
        let providers = ProviderFamily.uniqueTileIDs(from: origin.providerIDs).sorted().joined(separator: ",")
        return "\(origin.installed.name.lowercased())|\(standardized(origin.installed.path))|\(providers)"
    }

    static func classify(
        _ origin: InstalledSkill,
        projectPath: String?,
        globalRoots: [String] = defaultGlobalRoots
    ) -> SkillOriginScope {
        let lowerPath = standardized(origin.path).lowercased()
        let lowerSource = origin.sourceLabel.lowercased()
        let lowerReason = origin.readOnlyReason?.lowercased() ?? ""
        if lowerSource.contains("plugin")
            || lowerReason.contains("plugin")
            || lowerPath.contains("/plugins/cache/")
            || lowerSource.contains("codex managed")
            || lowerSource.contains("codex admin") {
            return .managed
        }

        let scopeLabel = origin.scopeLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        switch scopeLabel.lowercased() {
        case "project": return .project
        case "private": return .projectPrivate
        default: break
        }

        if let projectPath, isWithin(origin.path, root: projectPath) {
            return .project
        }
        if globalRoots.contains(where: { isWithin(origin.path, root: $0) }) {
            return .global
        }
        switch scopeLabel.lowercased() {
        case "global": return .global
        case "parent", "ancestor", "inherited":
            if isAncestorProviderSkill(origin.path, of: projectPath) {
                return .ancestor
            }
            if lowerSource.contains("additional-directory") || lowerSource.contains("additional directory") {
                return .unknown("Additional folder")
            }
            return .unknown("Other source")
        default: return .unknown(scopeLabel)
        }
    }

    static func projectInstalledOrigins(
        from origins: [InstalledSkill],
        projectPath: String,
        globalRoots: [String] = defaultGlobalRoots
    ) -> [InstalledSkill] {
        origins.filter {
            let scope = classify($0, projectPath: projectPath, globalRoots: globalRoots)
            return scope == .project || scope == .projectPrivate
        }
    }

    static var defaultGlobalRoots: [String] {
        var roots = ProviderCatalog.specs().flatMap(\.globalSkillDirs)
        roots.append("/etc/codex/skills")
        return uniqueStatic(roots)
    }

    private static func originSort(_ lhs: ProjectSkillOrigin, _ rhs: ProjectSkillOrigin) -> Bool {
        if lhs.scope.sortOrder != rhs.scope.sortOrder { return lhs.scope.sortOrder < rhs.scope.sortOrder }
        return lhs.installed.path.localizedCaseInsensitiveCompare(rhs.installed.path) == .orderedAscending
    }

    private static func isWithin(_ path: String, root: String) -> Bool {
        let candidate = standardized(path)
        let base = standardized(root)
        return candidate == base || candidate.hasPrefix(base + "/")
    }

    private static func isAncestorProviderSkill(_ path: String, of projectPath: String?) -> Bool {
        guard let projectPath else { return false }
        let candidate = standardized(path)
        let project = standardized(projectPath)
        let projectSkillDirectories = uniqueStatic(ProviderCatalog.specs().flatMap(\.projectSkillDirs))
        for relative in projectSkillDirectories {
            let normalized = relative.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let marker = "/\(normalized)/"
            guard let range = candidate.range(of: marker) else { continue }
            let owner = String(candidate[..<range.lowerBound])
            if project == owner || project.hasPrefix(owner + "/") {
                return true
            }
        }
        return false
    }

    private static func standardized(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL.path
    }

    private static func uniqueStatic(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
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

private struct SkillsIdentifiablePath: Identifiable {
    let path: String
    var id: String { path }
}
