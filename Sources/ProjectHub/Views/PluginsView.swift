import SwiftUI

// MARK: - Plugins inventory (top-level tab)

struct PluginsView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @ObservedObject var store: PluginInventoryStore

    private enum ScanTarget: String, CaseIterable, Identifiable {
        case global
        case project

        var id: String { rawValue }

        var title: String {
            switch self {
            case .global: return "Global"
            case .project: return "Project"
            }
        }
    }

    @State private var scanTarget: ScanTarget = .global
    @State private var selectedProjectID: UUID? = nil
    @State private var expandedPluginID: String? = nil

    private var scanKey: String {
        switch scanTarget {
        case .global:
            return "global"
        case .project:
            return "project:\(scanRoot ?? "<none>")"
        }
    }

    private var report: CompatibilityScanResult? {
        store.report(for: scanKey)
    }

    private var scanning: Bool {
        store.isScanning(scanKey)
    }

    private var selectedProject: Project? {
        if let selectedProjectID,
           let project = projectStore.projects.first(where: { $0.id == selectedProjectID }) {
            return project
        }
        return projectStore.projects.first
    }

    private var scanRoot: String? {
        scanTarget == .project ? selectedProject?.path : nil
    }

    private var pluginGroups: [PluginInventoryGroup] {
        PluginInventoryGroup.groups(from: report?.plugins ?? [])
    }

    var body: some View {
        VStack(spacing: 0) {
            HubPageHeader(
                title: "Plugins",
                subtitle: summaryText,
                actions: { headerActions }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: HubTheme.sectionGap) {
                    HubPageNote(
                        text: "A plugin is a bundle that installs several things at once — skills, sub-agents, MCP servers and slash commands. Expand one to see exactly what it will put on disk before you install it."
                    )
                    content
                }
                .padding(HubTheme.contentPadding)
            }
        }
        .background(HubTheme.bg)
        .onAppear {
            if selectedProjectID == nil {
                selectedProjectID = projectStore.projects.first?.id
            }
            store.restore(key: scanKey, projectRoot: scanRoot)
        }
        .onChange(of: scanTarget) { _, _ in
            expandedPluginID = nil
            store.restore(key: scanKey, projectRoot: scanRoot)
        }
        .onChange(of: selectedProjectID) { _, _ in
            if scanTarget == .project {
                expandedPluginID = nil
            }
        }
        .onChange(of: projectStore.projects.map(\.id)) { _, ids in
            guard let selectedProjectID, ids.contains(selectedProjectID) else {
                self.selectedProjectID = ids.first
                return
            }
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        Menu {
            ForEach(ScanTarget.allCases) { target in
                Button(target.title) { scanTarget = target }
            }
        } label: {
            Text("scope: \(scanTarget.title.lowercased()) ▾")
                .font(HubFont.mono(10))
                .foregroundStyle(HubTheme.textMid)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(scanning)

        if scanTarget == .project, !projectStore.projects.isEmpty {
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
            .disabled(scanning)
        }

        Text(scanRoot.map(shortPath) ?? "global plugin state")
            .font(HubFont.machine)
            .foregroundStyle(HubTheme.textFaint)
            .lineLimit(1)
            .truncationMode(.middle)

        HubButton(title: scanning ? "Scanning" : "Rescan", kind: .primary, action: scan)
            .disabled(scanning || (scanTarget == .project && selectedProject == nil))
    }

    private var projectPicker: some View {
        Picker("Project", selection: Binding(
            get: { selectedProjectID ?? projectStore.projects.first?.id },
            set: { selectedProjectID = $0 }
        )) {
            ForEach(projectStore.projects) { project in
                Text(project.displayName).tag(Optional(project.id))
            }
        }
        .labelsHidden()
        .frame(maxWidth: 190)
        .disabled(scanning)
    }

    private var summaryText: String {
        if scanning { return "Scanning plugin evidence" }
        guard report != nil else { return "Scan to inspect plugins" }
        return "\(pluginGroups.count) bundle\(pluginGroups.count == 1 ? "" : "s") found"
    }

    @ViewBuilder
    private var content: some View {
        if scanning && report == nil {
            loadingState
        } else if report == nil {
            emptyScanState
        } else if pluginGroups.isEmpty {
            emptyPluginsState
        } else {
            pluginList
        }
    }

    /// Bundles grouped by the provider that installs them (§3d).
    private var groupedBundles: [(providerID: String, groups: [PluginInventoryGroup])] {
        var buckets: [String: [PluginInventoryGroup]] = [:]
        var order: [String] = []
        for group in pluginGroups {
            let id = group.providerIDs.first ?? "claude-code"
            if buckets[id] == nil { order.append(id) }
            buckets[id, default: []].append(group)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    private var pluginList: some View {
        VStack(alignment: .leading, spacing: HubTheme.sectionGap) {
            ForEach(groupedBundles, id: \.providerID) { bucket in
                VStack(alignment: .leading, spacing: 8) {
                    HubSectionHeading(
                        "\(ToolPalette.label(for: bucket.providerID)) bundles",
                        count: bucket.groups.count
                    )
                    VStack(spacing: 0) {
                        ForEach(Array(bucket.groups.enumerated()), id: \.element.id) { index, group in
                            if index > 0 { HubRowSeparator() }
                            pluginRow(group)
                        }
                    }
                    .hubCard()
                }
            }
        }
    }

    private func pluginRow(_ group: PluginInventoryGroup) -> some View {
        let expanded = expandedPluginID == group.id
        let status: HubStatus = {
            switch group.status {
            case .enabled:  return .ok
            case .detected: return .ok
            case .disabled: return .neutral
            case .missing:  return .bad
            }
        }()

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(HubTheme.disclosureAnimation) {
                    expandedPluginID = expanded ? nil : group.id
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
                            StatusLabel(status: status, text: group.status.label.lowercased(), font: HubFont.mono(9))
                            if group.requiresRestartAfterWrite {
                                Text("needs restart")
                                    .font(HubFont.mono(9))
                                    .foregroundStyle(HubTheme.warn)
                            }
                        }
                        // What this bundle actually puts on disk, before install.
                        Text(group.componentSummary)
                            .font(HubFont.body)
                            .foregroundStyle(HubTheme.textDim)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    ProviderTileRow(toolIDs: group.providerIDs)

                    Text("\(group.observations.count) srf")
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
                pluginDetail(group)
                    .padding(.horizontal, HubTheme.contentPadding)
                    .padding(.bottom, 12)
            }
        }
    }

    private func pluginDetail(_ group: PluginInventoryGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            if group.pluginID != group.name {
                Text(group.pluginID)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if !group.components.isEmpty {
                detailSection(title: "Components") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(group.components, id: \.self) { component in
                                badge(component, color: .secondary)
                            }
                        }
                    }
                }
            }

            detailSection(title: "Surfaces") {
                VStack(spacing: 5) {
                    ForEach(group.observations) { observation in
                        pluginSurfaceRow(observation)
                    }
                }
            }
        }
    }

    private func pluginSurfaceRow(_ plugin: CompatibilityPluginObservation) -> some View {
        let color = observationColor(plugin)
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: plugin.enabled == false ? "pause.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(plugin.toolID.label)
                        .font(.system(size: 11, weight: .semibold))
                    badge(plugin.scope.rawValue, color: .secondary)
                    badge(plugin.installMethod.label, color: .secondary)
                    if let enabled = plugin.enabled {
                        badge(enabled ? "Enabled" : "Disabled", color: enabled ? .accentColor : .secondary)
                    }
                    if let version = plugin.version {
                        badge("v\(version)", color: .secondary)
                    }
                }

                Text(plugin.summary)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                if let path = plugin.installPath ?? plugin.sourcePath {
                    Text(shortPath(path))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
        }
        .padding(7)
        .background(HubTheme.bg.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 7))
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

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Scanning plugins")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private var emptyScanState: some View {
        VStack(spacing: 10) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No plugin scan yet")
                .font(.system(size: 14, weight: .semibold))
            Text("Scan global tool state or a selected project to see plugin bundles, components, and install evidence.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private var emptyPluginsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No plugins found")
                .font(.system(size: 14, weight: .semibold))
            Text("The selected scan did not find Claude or Codex plugin evidence.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private func scan() {
        expandedPluginID = nil
        store.scan(key: scanKey, projectRoot: scanRoot)
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

    private func toolColor(_ label: String) -> Color {
        if label.contains("Claude") { return .orange }
        if label.contains("Codex") { return .purple }
        return .secondary
    }

    private func statusColor(_ status: PluginInventoryGroup.Status) -> Color {
        switch status {
        case .enabled: return .accentColor
        case .missing: return .orange
        case .disabled, .detected: return .secondary
        }
    }

    private func observationColor(_ plugin: CompatibilityPluginObservation) -> Color {
        if plugin.enabled == false { return .secondary }
        if plugin.installPath == nil && (plugin.installMethod == .codexConfig || plugin.installMethod == .claudeSettings) {
            return .orange
        }
        return .accentColor
    }

    private func shortPath(_ path: String) -> String {
        CompatibilityScanner.tilde(path)
    }
}

@MainActor
final class PluginInventoryStore: ObservableObject {
    @Published private var reports: [String: CompatibilityScanResult] = [:]
    @Published private var scanningKeys: Set<String> = []

    func report(for key: String) -> CompatibilityScanResult? {
        reports[key]
    }

    func isScanning(_ key: String) -> Bool {
        scanningKeys.contains(key)
    }

    func restore(key: String, projectRoot: String?) {
        guard reports[key] == nil else { return }
        if let cached = ConfigScanCache.load(projectRoot: projectRoot) {
            reports[key] = cached
        }
    }

    func scan(key: String, projectRoot: String?) {
        guard !scanningKeys.contains(key) else { return }
        scanningKeys.insert(key)

        Task {
            let result = await Task.detached(priority: .utility) {
                CompatibilityScanner.scan(projectRoot: projectRoot)
            }.value
            ConfigScanCache.save(result)

            await MainActor.run {
                reports[key] = result
                scanningKeys.remove(key)
            }
        }
    }
}

struct PluginInventoryGroup: Identifiable {
    enum Status {
        case enabled
        case disabled
        case missing
        case detected

        var label: String {
            switch self {
            case .enabled: return "Enabled"
            case .disabled: return "Disabled"
            case .missing: return "Missing"
            case .detected: return "Detected"
            }
        }
    }

    var id: String { pluginID.lowercased() }
    let pluginID: String
    let name: String
    let observations: [CompatibilityPluginObservation]

    var status: Status {
        if observations.contains(where: { $0.installPath == nil && ($0.installMethod == .codexConfig || $0.installMethod == .claudeSettings) }) {
            return .missing
        }
        let enabledValues = observations.compactMap(\.enabled)
        if enabledValues.contains(true) { return .enabled }
        if !enabledValues.isEmpty && enabledValues.allSatisfy({ !$0 }) { return .disabled }
        return .detected
    }

    var toolLabels: [String] {
        unique(observations.map { $0.toolID.label })
    }

    var components: [String] {
        unique(observations.flatMap(\.components))
    }

    var requiresRestartAfterWrite: Bool {
        observations.contains { $0.requiresRestartAfterWrite }
    }

    /// Provider ids that install this bundle — the tiles on the row (§3d).
    var providerIDs: [String] {
        var ids: [String] = []
        for observation in observations {
            let id = PluginInventoryGroup.providerID(for: observation.toolID)
            if !ids.contains(id) { ids.append(id) }
        }
        return ids
    }

    static func providerID(for toolID: CompatibilityToolID) -> String {
        switch toolID {
        case .claudeCode:    return "claude-code"
        case .claudeDesktop: return "claude-desktop"
        case .codexCLI, .codexDesktop: return "codex"
        }
    }

    /// What this bundle puts on disk, read before you install it.
    var componentSummary: String {
        let parts = components
        if parts.isEmpty { return "no components declared" }
        return parts.prefix(6).joined(separator: " · ")
    }

    static func groups(from observations: [CompatibilityPluginObservation]) -> [PluginInventoryGroup] {
        Dictionary(grouping: observations, by: { $0.pluginID.lowercased() })
            .values
            .compactMap { group in
                guard let first = group.sorted(by: observationSort).first else { return nil }
                return PluginInventoryGroup(
                    pluginID: first.pluginID,
                    name: first.name,
                    observations: group.sorted(by: observationSort)
                )
            }
            .sorted {
                if $0.status.label != $1.status.label {
                    return statusSortOrder($0.status) < statusSortOrder($1.status)
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private static func observationSort(
        _ lhs: CompatibilityPluginObservation,
        _ rhs: CompatibilityPluginObservation
    ) -> Bool {
        if lhs.toolID.rawValue != rhs.toolID.rawValue {
            return lhs.toolID.rawValue < rhs.toolID.rawValue
        }
        if lhs.scope.rawValue != rhs.scope.rawValue {
            return lhs.scope.rawValue < rhs.scope.rawValue
        }
        return lhs.installMethod.rawValue < rhs.installMethod.rawValue
    }

    private static func statusSortOrder(_ status: Status) -> Int {
        switch status {
        case .missing: return 0
        case .enabled: return 1
        case .detected: return 2
        case .disabled: return 3
        }
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
