import SwiftUI

// MARK: - Plugins inventory (top-level tab)

struct PluginsView: View {
    @EnvironmentObject var projectStore: ProjectStore

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
    @State private var report: CompatibilityScanResult? = nil
    @State private var scanning = false
    @State private var expandedPluginID: String? = nil
    @State private var scanError: String? = nil

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
            topBar
            Divider()
            content
        }
        .onAppear {
            if selectedProjectID == nil {
                selectedProjectID = projectStore.projects.first?.id
            }
        }
        .onChange(of: scanTarget) { _, _ in
            report = nil
            expandedPluginID = nil
            scanError = nil
        }
        .onChange(of: selectedProjectID) { _, _ in
            if scanTarget == .project {
                report = nil
                expandedPluginID = nil
                scanError = nil
            }
        }
        .onChange(of: projectStore.projects.map(\.id)) { _, ids in
            guard let selectedProjectID, ids.contains(selectedProjectID) else {
                self.selectedProjectID = ids.first
                return
            }
        }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Picker("Plugin scope", selection: $scanTarget) {
                    ForEach(ScanTarget.allCases) { target in
                        Text(target.title).tag(target)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 150)
                .disabled(scanning)

                Spacer(minLength: 8)

                Button(action: scan) {
                    HStack(spacing: 4) {
                        if scanning {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(scanning ? "Scanning" : "Scan")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(scanning ? .secondary : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(scanning ? Color.secondary.opacity(0.12) : Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(scanning || (scanTarget == .project && selectedProject == nil))
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summaryText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Text(scanRoot.map(shortPath) ?? "Global Claude/Codex plugin state")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                if scanTarget == .project && !projectStore.projects.isEmpty {
                    projectPicker
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
        return "\(pluginGroups.count) plugin\(pluginGroups.count == 1 ? "" : "s") detected"
    }

    @ViewBuilder
    private var content: some View {
        if scanning && report == nil {
            loadingState
        } else if let scanError {
            errorState(scanError)
        } else if report == nil {
            emptyScanState
        } else if pluginGroups.isEmpty {
            emptyPluginsState
        } else {
            pluginList
        }
    }

    private var pluginList: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(pluginGroups) { group in
                    pluginRow(group)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func pluginRow(_ group: PluginInventoryGroup) -> some View {
        let expanded = expandedPluginID == group.id
        let color = statusColor(group.status)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.16)) {
                    expandedPluginID = expanded ? nil : group.id
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 14)

                    Image(systemName: group.status == .disabled ? "puzzlepiece.extension" : "puzzlepiece.extension.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(group.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 5) {
                                ForEach(group.toolLabels, id: \.self) { label in
                                    badge(label, color: toolColor(label))
                                }
                                badge(group.status.label, color: color)
                                ForEach(group.components.prefix(5), id: \.self) { component in
                                    badge(component, color: .secondary)
                                }
                                if group.requiresRestartAfterWrite {
                                    badge("Restart", color: .blue)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    metric(value: "\(group.observations.count)", label: "surface\(group.observations.count == 1 ? "" : "s")", icon: "externaldrive")
                }
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                pluginDetail(group)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(color.opacity(0.18), lineWidth: 0.8))
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
        .background(Color(NSColor.windowBackgroundColor).opacity(0.55))
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

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundColor(.orange)
            Text("Plugin scan failed")
                .font(.system(size: 14, weight: .semibold))
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private func scan() {
        guard !scanning else { return }
        scanning = true
        scanError = nil
        expandedPluginID = nil
        let root = scanRoot

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                CompatibilityScanner.scan(projectRoot: root)
            }.value

            await MainActor.run {
                report = result
                scanning = false
            }
        }
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

private struct PluginInventoryGroup: Identifiable {
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
