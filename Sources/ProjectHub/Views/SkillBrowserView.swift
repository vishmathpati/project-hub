import SwiftUI

// MARK: - Skill browser (browse, search, install into any project)

struct SkillBrowserView: View {
    @EnvironmentObject var skillStore: SkillStore
    @EnvironmentObject var projectStore: ProjectStore

    @State private var query = ""
    @State private var selectedProjectID: UUID? = nil

    private var targetProject: Project? {
        if let selectedProjectID,
           let match = projectStore.projects.first(where: { $0.id == selectedProjectID }) {
            return match
        }
        return projectStore.projects.first
    }

    private var trimmedQueryIsEmpty: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let groups = SkillStore.browserGroups(
            globalSkills: skillStore.globalSkills,
            installedByProject: skillStore.installedSkillsByProject,
            query: query
        )
        let targetInstalled: [InstalledSkill]? = targetProject.flatMap { skillStore.cachedInstalledSkills(for: $0.path) }
        let targetIndex: SkillStore.InstalledNameIndex? = targetInstalled.map { SkillStore.nameIndex($0) }
        let cachedCounts = installedProjectCounts()
        let rows: [(group: SkillStore.GlobalSkillGroup, skill: Skill, installed: Bool?, count: Int)] = groups.compactMap { group in
            guard let skill = group.skills.first else { return nil }
            let count = max(skillStore.globalSkillInstallCounts[group.id] ?? 0, cachedCounts[group.id] ?? 0)
            return (group, skill, targetIndex?.contains(skill), count)
        }

        VStack(spacing: 0) {
            HubPageHeader(
                title: "Browse skills",
                subtitle: summaryText(count: rows.count),
                actions: { headerActions }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: HubTheme.sectionGap) {
                    controlsRow
                    if rows.isEmpty {
                        if skillStore.isRefreshing {
                            loadingState("Loading skills…")
                        } else {
                            emptyState
                        }
                    } else {
                        browserList(rows: rows)
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
        .task(id: projectStore.projects.map(\.path)) {
            await skillStore.loadInstalledSkillsForBrowser(projects: projectStore.projects)
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

    private func summaryText(count: Int) -> String {
        if let target = targetProject {
            return "\(count) skill\(count == 1 ? "" : "s") · installing into \(target.displayName)"
        }
        return "\(count) skill\(count == 1 ? "" : "s") · no project to install into"
    }

    private var controlsRow: some View {
        HStack(spacing: 10) {
            HubSearchField(text: $query, placeholder: "Search name or description", shortcut: nil)
                .frame(maxWidth: 320)
            Spacer(minLength: 0)
            if projectStore.projects.isEmpty {
                Text("Add a project to install into")
                    .font(HubFont.secondary)
                    .foregroundStyle(HubTheme.textDim)
            } else {
                Picker("Target project", selection: $selectedProjectID) {
                    ForEach(projectStore.projects) { project in
                        Text(project.displayName).tag(Optional(project.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 240)
            }
        }
    }

    // Background counts skip projects that are unsafe to inspect; the cache
    // covers those once opened, so the row shows whichever is higher.
    private func installedProjectCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for installed in skillStore.installedSkillsByProject.values {
            for name in Set(installed.map { $0.name.lowercased() }) {
                counts[name, default: 0] += 1
            }
        }
        return counts
    }

    private func browserList(rows: [(group: SkillStore.GlobalSkillGroup, skill: Skill, installed: Bool?, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading("All skills", count: rows.count)
            LazyVStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.group.id) { index, row in
                    if index > 0 { HubRowSeparator() }
                    browserRow(group: row.group, skill: row.skill, installed: row.installed, count: row.count)
                }
            }
            .hubCard()
        }
    }

    private func browserRow(group: SkillStore.GlobalSkillGroup, skill: Skill, installed: Bool?, count: Int) -> some View {
        HStack(alignment: .center, spacing: 4) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name)
                        .font(HubFont.rowPrimary)
                        .foregroundStyle(HubTheme.text)
                        .lineLimit(1)
                    if !group.primaryDescription.isEmpty {
                        Text(group.primaryDescription)
                            .font(HubFont.machine)
                            .foregroundStyle(HubTheme.textDim)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Spacer(minLength: 12)

                ProviderTileRow(toolIDs: group.tileIDs)

                Text("\(count) proj")
                    .font(HubFont.machine)
                    .foregroundStyle(HubTheme.textDim)
                    .frame(width: 52, alignment: .trailing)
            }
            .padding(.leading, HubTheme.contentPadding)
            .frame(minHeight: HubTheme.listRowHeight)
            .contentShape(Rectangle())

            HStack(spacing: 4) {
                switch rowInstallState(installed: installed) {
                case .installed:
                    Text("Installed")
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textFaint)
                case .unknown:
                    Text("…")
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textFaint)
                case .available:
                    HubButton(title: "install", kind: .accentInline) {
                        if let target = targetProject {
                            skillStore.install(skill: skill, to: target.path)
                        }
                    }
                    .disabled(targetProject == nil)
                    .help(targetProject.map { "Install \(group.name) into \($0.displayName)" } ?? "Add a project first")
                }
                Menu {
                    Button("Copy to all tool folders") {
                        if let target = targetProject {
                            skillStore.copyAcrossProviders(skill, in: target.path)
                        }
                    }
                    .disabled(targetProject == nil)
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
                .disabled(targetProject == nil)
                .help("Copy \(group.name) into every tool folder in the target project")
            }
            .padding(.trailing, HubTheme.contentPadding)
        }
    }

    private enum RowInstallState {
        case installed
        case unknown
        case available
    }

    private func rowInstallState(installed: Bool?) -> RowInstallState {
        if let installed {
            return installed ? .installed : .available
        }
        return targetProject == nil ? .available : .unknown
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "book.closed")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text(trimmedQueryIsEmpty ? "No skills found" : "No skills match")
                .font(.system(size: 14, weight: .semibold))
            Text(trimmedQueryIsEmpty
                ? "Add skill directories to:\n~/.claude/skills/\n~/.agents/skills/"
                : "Try a different name or description.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}
