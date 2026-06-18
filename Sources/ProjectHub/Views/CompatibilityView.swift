import SwiftUI
import AppKit

// MARK: - Compatibility check tab

struct CompatibilityIssueReportContext: Equatable {
    let surface: String
    let scope: String
    let runtime: String
    let owner: String
    let write: String
    let afterFix: String
}

struct CompatibilityView: View {
    @EnvironmentObject var projectStore: ProjectStore
    private let fixedProject: Project?
    @State private var selectedProjectPath: String?
    @State private var report: CompatibilityScanResult?
    @State private var selectedIssue: CompatibilityIssue?
    @State private var showMatrix = false
    @State private var applyingFix = false
    @State private var verifyingMCP = false
    @State private var fixError: String?
    @State private var liveReports: [String: MCPHealthReport] = [:]
    @State private var scanTarget: CompatibilityScanTarget = .project
    @State private var scopeFilter: CompatibilityScopeFilter = .allSupported
    @State private var runtimeFilter: CompatibilityRuntimeFilter = .all
    @State private var codexRuntimeProfileName = ""
    @State private var codexProfileNames: [String] = []
    @State private var postFixActions: [CompatibilityManualAction] = []
    @State private var copiedReport = false
    @State private var scanning = false
    @State private var scanRequestID = UUID()
    @State private var applyingScanResult = false

    init(project: Project? = nil) {
        self.fixedProject = project
    }

    private var selectedProject: Project? {
        if let fixedProject { return fixedProject }
        if let selectedProjectPath,
           let project = projectStore.projects.first(where: { $0.path == selectedProjectPath }) {
            return project
        }
        return projectStore.projects.first
    }

    private var scanRoot: String? {
        if let fixedProject { return fixedProject.path }
        return scanTarget == .project ? selectedProject?.path : nil
    }

    private var codexRuntimeProfileSelection: CodexProfileSelection? {
        CodexProfileSelection.cliRuntimeOverride(codexRuntimeProfileName)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            if let report {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        summaryGrid(report)
                        workflowStrip
                        workflowNextStepCard(report)
                        targetFilterStrip(report)
                        coverageOverview(report)
                        liveVerification(report)
                        settingsOverview(report)
                        authOverview(report)
                        skillSupportOverview(report)
                        skillsOverview(report)
                        previewableFixesOverview(report)
                        manualActionsOverview(report)
                        findings(report)
                        if showMatrix {
                            matrix(report)
                        }
                    }
                    .padding(12)
                }
            } else {
                emptyState
            }
        }
        .onAppear {
            ensureSelectedProject()
            reloadCodexProfileNames()
        }
        .onChange(of: selectedProjectPath) { _, _ in
            if fixedProject == nil { invalidateReport() }
        }
        .onChange(of: scanTarget) { _, _ in
            if fixedProject == nil { invalidateReport() }
        }
        .onChange(of: codexRuntimeProfileName) { _, _ in
            if !applyingScanResult { invalidateReport() }
        }
        .sheet(item: $selectedIssue) { issue in
            issueSheet(issue)
                .frame(width: 460)
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Compatibility")
                    .font(.system(size: 13, weight: .semibold))
                Text(scanRoot.map(shortPath) ?? "Global tool state")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            projectPicker
            codexProfilePicker
            Button(action: copyCompatibilityReport) {
                Image(systemName: copiedReport ? "checkmark.circle.fill" : "doc.on.clipboard")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(copiedReport ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(report == nil)
            .help("Copy compatibility report")

            Button {
                showMatrix.toggle()
            } label: {
                Image(systemName: showMatrix ? "tablecells.badge.ellipsis" : "tablecells")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(showMatrix ? "Hide matrix" : "Show matrix")

            Button(action: verifyMCPServers) {
                HStack(spacing: 4) {
                    if verifyingMCP {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "checkmark.seal")
                    }
                    Text(verifyingMCP ? "Verifying" : "Verify")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(verifyingMCP ? .secondary : .accentColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(verifyingMCP || report.map { verifiableServers($0).isEmpty } ?? true)
            .help("Verify checks MCP server handshakes. Settings, skills, auth policy, and instruction fixes are confirmed by Scan and the owning app/session reload.")

            Button(action: refresh) {
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
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(ContentView.headerGrad)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(scanning)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var scanTargetPicker: some View {
        if fixedProject == nil {
            Picker("Scan target", selection: $scanTarget) {
                Text("Global").tag(CompatibilityScanTarget.global)
                Text("Project").tag(CompatibilityScanTarget.project)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 150)
            .disabled(projectStore.projects.isEmpty)
            .help("Choose whether Scan inspects only global tool state or includes the selected project's local configuration.")
        }
    }

    @ViewBuilder
    private var projectPicker: some View {
        if fixedProject == nil && scanTarget == .project && !projectStore.projects.isEmpty {
            Picker("Project", selection: Binding(
                get: { selectedProjectPath ?? projectStore.projects.first?.path ?? "" },
                set: { selectedProjectPath = $0 }
            )) {
                ForEach(projectStore.projects) { project in
                    Text(project.displayName)
                        .tag(project.path)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 170)
            .help("Choose the project to scan")
        }
    }

    @ViewBuilder
    private var codexProfilePicker: some View {
        let profiles = codexProfileNames
        if !profiles.isEmpty {
            Picker("Codex CLI profile", selection: $codexRuntimeProfileName) {
                Text("Codex default").tag("")
                ForEach(profiles, id: \.self) { profile in
                    Text(profile).tag(profile)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 150)
            .help("Optional: scan Codex CLI as if it was launched with codex --profile <name>. Codex Desktop and default/static evidence stay unchanged.")
        }
    }

    private func summaryGrid(_ report: CompatibilityScanResult) -> some View {
        let serverCounts = healthCounts(filteredServers(report).map { effectiveHealth(for: $0) })
        let issueCounts = healthCounts(filteredIssues(report).map(\.state))

        return VStack(alignment: .leading, spacing: 8) {
            summarySectionTitle("MCP Server Health")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                summaryTile(.broken, count: serverCounts[.broken, default: 0], icon: "xmark.octagon.fill", color: .red)
                summaryTile(.needsAuth, count: serverCounts[.needsAuth, default: 0], icon: "key.fill", color: .orange)
                summaryTile(.authExpired, count: serverCounts[.authExpired, default: 0], icon: "key.slash.fill", color: .orange)
                summaryTile(.needsRestart, count: serverCounts[.needsRestart, default: 0], icon: "arrow.clockwise.circle.fill", color: .blue)
                summaryTile(.conflict, count: serverCounts[.conflict, default: 0], icon: "exclamationmark.triangle.fill", color: .yellow)
                summaryTile(.disabled, count: serverCounts[.disabled, default: 0], icon: "pause.circle.fill", color: .secondary)
                summaryTile(.unknown, count: serverCounts[.unknown, default: 0], icon: "questionmark.circle.fill", color: .purple)
                summaryTile(.working, count: serverCounts[.working, default: 0], icon: "checkmark.circle.fill", color: .green)
            }

            summarySectionTitle("Findings by State")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                summaryTile(.broken, count: issueCounts[.broken, default: 0], icon: "xmark.octagon.fill", color: .red)
                summaryTile(.needsAuth, count: issueCounts[.needsAuth, default: 0], icon: "key.fill", color: .orange)
                summaryTile(.authExpired, count: issueCounts[.authExpired, default: 0], icon: "key.slash.fill", color: .orange)
                summaryTile(.needsRestart, count: issueCounts[.needsRestart, default: 0], icon: "arrow.clockwise.circle.fill", color: .blue)
                summaryTile(.conflict, count: issueCounts[.conflict, default: 0], icon: "exclamationmark.triangle.fill", color: .yellow)
                summaryTile(.disabled, count: issueCounts[.disabled, default: 0], icon: "pause.circle.fill", color: .secondary)
                summaryTile(.unknown, count: issueCounts[.unknown, default: 0], icon: "questionmark.circle.fill", color: .purple)
            }
        }
    }

    private func summarySectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.top, 2)
    }

    private func healthCounts(_ states: [CompatibilityHealthState]) -> [CompatibilityHealthState: Int] {
        states.reduce(into: [:]) { counts, state in
            counts[state, default: 0] += 1
        }
    }

    private func summaryTile(_ state: CompatibilityHealthState, count: Int, icon: String, color: Color) -> some View {
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 15, weight: .bold))
            }
            Text(stateLabel(state))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(9)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.18), lineWidth: 1))
    }

    private var workflowStrip: some View {
        HStack(spacing: 6) {
            workflowStep("Scan", icon: "magnifyingglass")
            workflowStep("Explain", icon: "text.bubble")
            workflowStep("Fix", icon: "wrench.and.screwdriver")
            workflowStep("Verify", icon: "checkmark.seal")
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func workflowNextStepCard(_ report: CompatibilityScanResult) -> some View {
        let fixes = previewableFixes(report)
        let actions = manualActions(report)
        let verifiable = verifiableServers(report)
        let servers = filteredServers(report)
        let liveFollowUp = actions.first { $0.issue == nil }

        let icon: String
        let title: String
        let detail: String
        let buttonTitle: String
        let action: (() -> Void)?
        let tint: Color

        if let fix = fixes.first {
            icon = fix.plan.icon
            title = "Next: preview a safe file fix"
            detail = "\(fix.plan.title) changes \(shortPath(fix.plan.path)) only after you review the diff."
            buttonTitle = "Preview"
            tint = .accentColor
            action = {
                fixError = nil
                selectedIssue = fix.issue
            }
        } else if let manual = actions.first(where: { $0.issue != nil }), let issue = manual.issue {
            icon = stateIcon(manual.state)
            title = "Next: finish the app-owned step"
            detail = manual.hint ?? manual.detail
            buttonTitle = "Open"
            tint = stateColor(manual.state)
            action = {
                fixError = nil
                selectedIssue = issue
            }
        } else if let liveFollowUp {
            icon = stateIcon(liveFollowUp.state)
            title = "Next: resolve live verification"
            detail = liveFollowUp.hint ?? liveFollowUp.detail
            buttonTitle = "Review"
            tint = stateColor(liveFollowUp.state)
            action = nil
        } else if !verifiable.isEmpty && liveReports.isEmpty {
            icon = "checkmark.seal"
            title = "Next: verify MCP handshakes"
            detail = "\(verifiable.count) directly verifiable MCP server\(verifiable.count == 1 ? "" : "s") can be checked with initialize and tools/list."
            buttonTitle = "Verify"
            tint = .green
            action = verifyMCPServers
        } else if servers.isEmpty {
            icon = "tray"
            title = "No MCP servers in this lens"
            detail = "Switch the target or scope lens if you expected Claude or Codex MCP servers here."
            buttonTitle = "Scan"
            tint = .secondary
            action = refresh
        } else {
            icon = "checkmark.seal.fill"
            title = "This target is ready to rescan later"
            detail = "No previewable fixes or manual follow-ups are visible for the current lens."
            buttonTitle = "Rescan"
            tint = .green
            action = refresh
        }

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                action?()
            } label: {
                Text(buttonTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(action == nil ? .secondary : tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(tint.opacity(action == nil ? 0.06 : 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(action == nil || verifyingMCP)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.16), lineWidth: 1))
    }

    private func targetFilterStrip(_ report: CompatibilityScanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: targetPreset.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                Picker("Target", selection: Binding(
                    get: { targetPreset },
                    set: { applyTargetPreset($0) }
                )) {
                    ForEach(CompatibilityTargetPreset.visibleOptions(current: targetPreset)) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Divider()
                    .frame(height: 18)

                Picker("Scope", selection: $scopeFilter) {
                    ForEach(CompatibilityScopeFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Picker("Runtime", selection: $runtimeFilter) {
                    ForEach(CompatibilityRuntimeFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 220)

                Text("\(filteredIssues(report).count) findings")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.10))
                    .clipShape(Capsule())
            }
            Text(scanLensSummary(report))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func coverageOverview(_ report: CompatibilityScanResult) -> some View {
        let surfaces = filteredMatrix(report)
        let issues = filteredIssues(report)
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Tool Coverage", count: CompatibilityToolID.allCases.count)
            VStack(spacing: 6) {
                ForEach(CompatibilityToolID.allCases) { tool in
                    coverageRow(
                        tool: tool,
                        surfaces: surfaces.filter { $0.toolID == tool },
                        issues: issues.filter { $0.toolID == tool }
                    )
                }
            }
        }
    }

    private func coverageRow(
        tool: CompatibilityToolID,
        surfaces: [CompatibilityMatrixEntry],
        issues: [CompatibilityIssue]
    ) -> some View {
        let configCount = surfaces.filter { $0.kind == .settings || $0.kind == .auth || $0.kind == .context }.count
        let writableCount = surfaces.filter { $0.canWriteSafely }.count
        let appOwnedCount = surfaces.filter { $0.writeMethod == .cli || $0.writeMethod == .appUI || $0.writeMethod == .runtimeOnly }.count
        let readOnlyCount = surfaces.filter { !$0.canWriteSafely && $0.writeMethod == .unsupported }.count
        let restartCount = surfaces.filter { $0.requiresRestartAfterWrite }.count
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.label)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text("\(surfaces.count) surface\(surfaces.count == 1 ? "" : "s") in this lens")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 118, alignment: .leading)

            coverageMetric("MCP", count: surfaces.filter { $0.kind == .mcp }.count)
            coverageMetric("Skills", count: surfaces.filter { $0.kind == .skills }.count)
            coverageMetric("Cfg/Auth", count: configCount)
            coverageMetric("Writable", count: writableCount, tint: writableCount > 0 ? .green : .secondary)
            coverageMetric("App/CLI", count: appOwnedCount)
            coverageMetric("Read-only", count: readOnlyCount)
            coverageMetric("Restart", count: restartCount, tint: restartCount > 0 ? .blue : .secondary)
            coverageMetric("Findings", count: issues.count, tint: issues.isEmpty ? .secondary : .orange)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5))
    }

    private func coverageMetric(_ label: String, count: Int, tint: Color = .accentColor) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(count == 0 ? .secondary : tint)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(minWidth: 46)
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background((count == 0 ? Color.secondary : tint).opacity(count == 0 ? 0.06 : 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func workflowStep(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
    }

    private func scanLensSummary(_ report: CompatibilityScanResult) -> String {
        let scanText = report.projectRoot == nil
            ? "Scanning global tool state only."
            : "Scanning project config plus global tool state."
        let profileText = codexRuntimeProfileName.isEmpty
            ? ""
            : " Codex CLI runtime profile: \(codexRuntimeProfileName)."
        return "\(scanText)\(profileText) Target: \(targetPreset.label). Advanced lens: \(scopeFilter.label) scope, \(runtimeFilter.label.lowercased()) runtimes."
    }

    private var targetPreset: CompatibilityTargetPreset {
        if scopeFilter == .allSupported && runtimeFilter == .all {
            return scanTarget == .global ? .global : .allSupported
        }
        if scopeFilter == .project && runtimeFilter == .all { return .project }
        if scopeFilter == .global && runtimeFilter == .all { return .global }
        if scopeFilter == .allSupported && runtimeFilter == .cli { return .cli }
        if scopeFilter == .allSupported && runtimeFilter == .desktop { return .desktop }
        return .custom
    }

    private func applyTargetPreset(_ preset: CompatibilityTargetPreset) {
        switch preset {
        case .allSupported:
            scanTarget = projectStore.projects.isEmpty ? .global : .project
            scopeFilter = .allSupported
            runtimeFilter = .all
        case .project:
            scanTarget = .project
            scopeFilter = .project
            runtimeFilter = .all
        case .global:
            scanTarget = .global
            scopeFilter = .global
            runtimeFilter = .all
        case .cli:
            scanTarget = projectStore.projects.isEmpty ? .global : .project
            scopeFilter = .allSupported
            runtimeFilter = .cli
        case .desktop:
            scanTarget = projectStore.projects.isEmpty ? .global : .project
            scopeFilter = .allSupported
            runtimeFilter = .desktop
        case .custom:
            break
        }
    }

    private func liveVerification(_ report: CompatibilityScanResult) -> some View {
        let servers = filteredServers(report)
        let verifiable = verifiableServers(report)
        let visibleLiveReports = liveReports.filter { id, _ in servers.contains(where: { $0.id == id }) }
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Live Verification", count: visibleLiveReports.count)
            if verifyingMCP {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 16, height: 16)
                    Text("Running MCP initialize and tools/list checks...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if visibleLiveReports.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal")
                        .foregroundColor(.secondary)
                    Text(verificationEmptyMessage(servers: servers, verifiable: verifiable))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 6) {
                    ForEach(servers.filter { liveReports[$0.id] != nil }) { server in
                        if let health = liveReports[server.id] {
                            liveReportRow(server: server, health: health)
                        }
                    }
                }
            }
        }
    }

    private func verifiableServers(_ report: CompatibilityScanResult) -> [CompatibilityServerObservation] {
        filteredServers(report).filter {
            CompatibilityScanner.healthEntry(for: $0, matrix: report.matrix) != nil
        }
    }

    private func verificationEmptyMessage(
        servers: [CompatibilityServerObservation],
        verifiable: [CompatibilityServerObservation]
    ) -> String {
        if servers.isEmpty {
            return "No MCP servers to verify for this target."
        }
        if verifiable.isEmpty {
            return "No directly verifiable MCP servers for this target. App-managed connectors and extensions must be checked in the owning app."
        }
        return "Run Verify to test live MCP handshakes for this target."
    }

    private func liveReportRow(server: CompatibilityServerObservation, health: MCPHealthReport) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: healthIcon(health.status))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(healthColor(health.status))
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(server.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(server.surfaceLabel)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.10))
                        .clipShape(Capsule())
                }
                Text(health.summary)
                    .font(.system(size: 10))
                    .foregroundColor(healthColor(health.status))
                    .lineLimit(2)
                if let hint = health.fixHint {
                    Text(hint)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Text(health.status.rawValue)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(healthColor(health.status))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(healthColor(health.status).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(healthColor(health.status).opacity(0.14), lineWidth: 1))
    }

    private func settingsOverview(_ report: CompatibilityScanResult) -> some View {
        let settings = filteredSettings(report)
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Settings & Context", count: settings.count)
            if settings.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.gearshape")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("No local settings or instruction files were found for the selected target.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(settings.prefix(8))) { setting in
                        settingsRow(setting)
                    }
                    if settings.count > 8 {
                        Text("+ \(settings.count - 8) more settings surface\(settings.count - 8 == 1 ? "" : "s") in the matrix")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 2)
                    }
                }
            }
        }
    }

    private func settingsRow(_ setting: CompatibilitySettingsObservation) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: settingsIcon(setting))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(setting.canWriteSafely ? .accentColor : .secondary)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(setting.label)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(setting.scope.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.10))
                        .clipShape(Capsule())
                    Text(setting.writeMethod.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(setting.canWriteSafely ? .green : .secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background((setting.canWriteSafely ? Color.green : Color.secondary).opacity(0.10))
                        .clipShape(Capsule())
                }

                Text(setting.summary)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Text(shortPath(setting.path))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if !setting.keys.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(setting.keys.prefix(6), id: \.self) { key in
                                Text(key)
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            Spacer()
            if setting.requiresRestartAfterWrite {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.blue)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5))
    }

    private func settingsIcon(_ setting: CompatibilitySettingsObservation) -> String {
        if setting.surfaceID.contains("context") {
            return "doc.text"
        }
        switch setting.toolID {
        case .claudeCode:
            return "terminal"
        case .claudeDesktop:
            return "macwindow"
        case .codexCLI:
            return "command"
        case .codexDesktop:
            return "app.badge"
        }
    }

    private func authOverview(_ report: CompatibilityScanResult) -> some View {
        let surfaces = filteredMatrix(report).filter { $0.kind == .auth }
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Authentication", count: surfaces.count)
            if surfaces.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "key")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("No authentication surfaces are visible for the selected target.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 6) {
                    ForEach(surfaces) { surface in
                        authSurfaceRow(surface, report: report)
                    }
                }
            }
        }
    }

    private func authSurfaceRow(_ surface: CompatibilityMatrixEntry, report: CompatibilityScanResult) -> some View {
        let issue = primaryAuthIssue(for: surface, report: report)
        let state = authState(for: surface, issue: issue)
        return Button {
            if let issue {
                fixError = nil
                selectedIssue = issue
            }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: stateIcon(state))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(stateColor(state))
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text(surface.label)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text(state.label)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(stateColor(state))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(stateColor(state).opacity(0.12))
                            .clipShape(Capsule())
                        Text(surface.writeMethod.rawValue)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.10))
                            .clipShape(Capsule())
                    }

                    Text(authDetail(for: surface, issue: issue, state: state))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    Text(surface.path.map(shortPath) ?? "App/runtime managed")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                if issue != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(stateColor(state).opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(issue == nil)
    }

    private func primaryAuthIssue(for surface: CompatibilityMatrixEntry, report: CompatibilityScanResult) -> CompatibilityIssue? {
        let issues = report.issues.filter { $0.surfaceID == surface.id }
        return issues.first { issue in
            switch issue.code {
            case .serverAuthMissing, .serverAuthExpired, .serverOAuthNeeded,
                 .serverAuthRuntimeManaged, .authCredentialStore, .configInvalidJSON:
                return true
            default:
                return false
            }
        } ?? issues.first
    }

    private func authState(for surface: CompatibilityMatrixEntry, issue: CompatibilityIssue?) -> CompatibilityHealthState {
        if let issue { return issue.state }
        if surface.path == nil { return .unknown }
        return .working
    }

    private func authDetail(
        for surface: CompatibilityMatrixEntry,
        issue: CompatibilityIssue?,
        state: CompatibilityHealthState
    ) -> String {
        if let issue { return issue.detail }
        if surface.path == nil {
            return "\(surface.toolID.label) owns this login state at runtime; Project Hub will not read or write secrets."
        }
        switch state {
        case .working:
            return "Auth evidence was found and did not contain an expired timestamp that Project Hub could recognize."
        case .unknown:
            return "Auth state is app-managed or stored outside a readable local file."
        default:
            return surface.note
        }
    }

    private func skillsOverview(_ report: CompatibilityScanResult) -> some View {
        let skills = filteredSkills(report)
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Skills", count: skills.count)
            if skills.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("No skills were found for the selected target.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(skills.prefix(8))) { skill in
                        skillRow(skill)
                    }
                    if skills.count > 8 {
                        Text("+ \(skills.count - 8) more skill\(skills.count - 8 == 1 ? "" : "s") in this target")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 2)
                    }
                }
            }
        }
    }

    private func skillSupportOverview(_ report: CompatibilityScanResult) -> some View {
        let support = filteredSkillSupport(report)
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Skill Availability", count: support.count)
            VStack(spacing: 6) {
                ForEach(support) { item in
                    skillSupportRow(item)
                }
            }
        }
    }

    private func skillSupportRow(_ item: CompatibilitySkillSupportObservation) -> some View {
        let color = skillSupportColor(item.state)
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: skillSupportIcon(item.state))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(item.toolID.label)
                        .font(.system(size: 12, weight: .semibold))
                    Text(item.state.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                    if item.requiresRestartAfterWrite {
                        Text("Restart after changes")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }

                Text(item.summary)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text(item.detail)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                if !item.roots.isEmpty {
                    Text(item.roots.map(shortPath).joined(separator: "  |  "))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.16), lineWidth: 1))
    }

    private func skillSupportColor(_ state: CompatibilitySkillSupportState) -> Color {
        switch state {
        case .supported, .shared:
            return .accentColor
        case .appManaged:
            return .blue
        case .unsupported:
            return .secondary
        case .unknown:
            return .orange
        }
    }

    private func skillSupportIcon(_ state: CompatibilitySkillSupportState) -> String {
        switch state {
        case .supported:
            return "wand.and.stars"
        case .shared:
            return "link.circle.fill"
        case .appManaged:
            return "person.crop.circle.badge.gearshape"
        case .unsupported:
            return "slash.circle"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    private func skillRow(_ skill: CompatibilitySkillObservation) -> some View {
        let disabled = skill.enabledOverride == false
        let color: Color = !skill.parseOK ? .orange : (disabled ? .secondary : .accentColor)
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: !skill.parseOK ? "exclamationmark.triangle.fill" : (disabled ? "pause.circle.fill" : "wand.and.stars"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(skill.displayName ?? skill.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    if skill.displayName != nil && skill.displayName != skill.name {
                        Text(skill.name)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    Text(skill.scope.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.10))
                        .clipShape(Capsule())
                    if let version = skill.version {
                        Text("v\(version)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    if disabled {
                        Text("Disabled")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    if skill.allowImplicitInvocation == false {
                        Text("Explicit only")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    if skill.claudeDisableModelInvocation == true {
                        Text("Manual")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    if skill.claudeUserInvocable == false {
                        Text("Hidden in /")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    if let override = skill.claudeOverrideState, override != "on" {
                        Text(claudeOverrideBadge(override))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(override == "off" ? .secondary : .blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background((override == "off" ? Color.secondary : Color.blue).opacity(0.10))
                            .clipShape(Capsule())
                    }
                }

                Text(skill.shortDescription ?? (skill.description.isEmpty ? "No description in SKILL.md frontmatter." : skill.description))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                if let summary = claudeInvocationSummary(skill) {
                    Text("Claude: \(summary)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let override = skill.claudeOverrideState {
                    Text("Claude override: \(override)\(skill.claudeOverrideSource.map { " from \($0)" } ?? "")")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if !skill.claudeSkillPermissionRules.isEmpty {
                    Text("Claude permissions: \(joinedCompact(skill.claudeSkillPermissionRules, limit: 3))")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if !skill.mcpDependencies.isEmpty {
                    Text("Requires MCP: \(skill.mcpDependencies.joined(separator: ", "))")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if !skill.claudeAllowedTools.isEmpty {
                    Text("Claude tools: \(joinedCompact(skill.claudeAllowedTools))")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let details = claudeRuntimeSummary(skill) {
                    Text("Claude runtime: \(details)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if !skill.claudePaths.isEmpty {
                    Text("Claude paths: \(joinedCompact(skill.claudePaths, limit: 3))")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Text(shortPath(skill.path))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 4) {
                    ForEach(skill.availableIn, id: \.rawValue) { tool in
                        Text(tool.label)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.16), lineWidth: 1))
    }

    private func manualActionsOverview(_ report: CompatibilityScanResult) -> some View {
        let actions = manualActions(report)
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Manual Actions", count: actions.count)
            if actions.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                    Text("No visible login, restart, disabled, conflict, or app-owned follow-up for this scan lens.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 6) {
                    ForEach(actions.prefix(8)) { action in
                        manualActionRow(action)
                    }
                    if actions.count > 8 {
                        Text("+ \(actions.count - 8) more manual action\(actions.count - 8 == 1 ? "" : "s") in findings")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 2)
                    }
                }
            }
        }
    }

    private func manualActionRow(_ action: CompatibilityManualAction) -> some View {
        Button {
            if let issue = action.issue {
                fixError = nil
                selectedIssue = issue
            }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: stateIcon(action.state))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(stateColor(action.state))
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(action.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text(action.state.label)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(stateColor(action.state))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(stateColor(action.state).opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text(action.detail)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    if let hint = action.hint {
                        Text(hint)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    if let path = action.path {
                        Text(shortPath(path))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer()
                if action.issue != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(stateColor(action.state).opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(action.issue == nil)
    }

    private func previewableFixesOverview(_ report: CompatibilityScanResult) -> some View {
        let fixes = previewableFixes(report)
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Previewable Fixes", count: fixes.count)
            if fixes.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.gearshape")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("No safe file fixes are available for this scan lens. Remaining items need manual review, app login, or runtime reload.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 6) {
                    ForEach(fixes.prefix(8)) { fix in
                        previewableFixRow(fix)
                    }
                    if fixes.count > 8 {
                        Text("+ \(fixes.count - 8) more previewable fix\(fixes.count - 8 == 1 ? "" : "es") in findings")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 2)
                    }
                }
            }
        }
    }

    private func previewableFixRow(_ fix: CompatibilityPreviewableFix) -> some View {
        Button {
            fixError = nil
            selectedIssue = fix.issue
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: fix.plan.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(fix.plan.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text(fix.plan.requiresRestart ? "Restart" : "Rescan")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(fix.plan.requiresRestart ? .blue : .secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background((fix.plan.requiresRestart ? Color.blue : Color.secondary).opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text(fix.plan.summary)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    Text(shortPath(fix.plan.path))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func findings(_ report: CompatibilityScanResult) -> some View {
        let issues = filteredIssues(report)
        let previewableIDs = Set(previewableFixes(report).map(\.id))
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Findings", count: issues.count)
            if issues.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No local compatibility issues found for this target")
                            .font(.system(size: 12, weight: .semibold))
                        Text("This covers file parsing, local commands, env placeholders, duplicates, and skill metadata. Run Verify for live MCP handshakes.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 6) {
                    ForEach(issues) { issue in
                        Button {
                            fixError = nil
                            selectedIssue = issue
                        } label: {
                            issueRow(issue, canPreviewFix: previewableIDs.contains(issue.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func issueRow(_ issue: CompatibilityIssue, canPreviewFix: Bool) -> some View {
        let color = severityColor(issue.severity)
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: severityIcon(issue.severity))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(issue.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(issue.code.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                }
                Text(issueSurfaceCaption(for: issue))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                if let path = evidencePath(for: issue) {
                    Text(shortPath(path))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            Text(canPreviewFix ? "Preview fix" : "Manual")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(canPreviewFix ? .accentColor : .secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background((canPreviewFix ? Color.accentColor : Color.secondary).opacity(0.10))
                .clipShape(Capsule())
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.14), lineWidth: 1))
    }

    private func matrix(_ report: CompatibilityScanResult) -> some View {
        let surfaces = filteredMatrix(report)
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Compatibility Matrix", count: surfaces.count)
            VStack(spacing: 6) {
                ForEach(surfaces) { surface in
                    matrixRow(surface)
                }
            }
        }
    }

    private func matrixRow(_ surface: CompatibilityMatrixEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(surface.toolID.label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.10))
                    .clipShape(Capsule())
                Text(surface.label)
                    .font(.system(size: 12, weight: .semibold))
                Text(surface.scope.rawValue)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.10))
                    .clipShape(Capsule())
                Spacer()
                if surface.requiresRestartAfterWrite {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.blue)
                }
                if !surface.canWriteSafely {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            Text(surface.path.map(shortPath) ?? "UI/runtime only")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: 5) {
                capability("MCP", surface.kind == .mcp)
                capability("Skills", surface.kind == .skills)
                capability("Settings", surface.kind == .settings)
                capability("Auth", surface.kind == .auth)
                capability("Context", surface.kind == .context)
                capability("Read", surface.fileControlled || surface.path != nil || surface.format == .accountRuntime)
                capability("OAuth", surface.supportsOAuth)
                capability("Disable", surface.supportsDisable)
                capability("Env", surface.supportsEnvExpansion)
                capability("P\(surface.precedence)", true)
                capability(surface.format.rawValue.uppercased(), true)
                capability(writeLabel(surface), surface.canWriteSafely)
            }
            Text(surface.note)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5))
    }

    private func capability(_ label: String, _ enabled: Bool) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(enabled ? .accentColor : .secondary.opacity(0.6))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background((enabled ? Color.accentColor : Color.secondary).opacity(enabled ? 0.12 : 0.08))
        .clipShape(Capsule())
    }

    private func writeLabel(_ surface: CompatibilityMatrixEntry) -> String {
        Self.writeLabel(for: surface)
    }

    static func writeLabel(for surface: CompatibilityMatrixEntry) -> String {
        switch surface.writeMethod {
        case .file:
            return surface.canWriteSafely ? "Preview write" : "File read-only"
        case .cli:
            return "CLI-owned"
        case .appUI:
            return "App-owned"
        case .runtimeOnly:
            return "Runtime-only"
        case .unsupported:
            return "Read-only"
        }
    }

    private func issueSurface(for issue: CompatibilityIssue) -> CompatibilityMatrixEntry? {
        guard let surfaceID = issue.surfaceID else { return nil }
        return report?.matrix.first { $0.id == surfaceID }
    }

    private func issueSurfaceCaption(for issue: CompatibilityIssue) -> String {
        guard let surface = issueSurface(for: issue) else {
            return issue.toolID?.label ?? "Multiple tools"
        }
        return "\(surface.toolID.label) - \(scopeLabel(surface.scope)) - \(surface.label)"
    }

    @ViewBuilder
    private func issueApplicabilityBlock(_ issue: CompatibilityIssue) -> some View {
        if let surface = issueSurface(for: issue) {
            let context = Self.issueReportContext(for: issue, surface: surface, shortPath: shortPath)
            VStack(alignment: .leading, spacing: 8) {
                Text("WHERE THIS APPLIES")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    issueContextRow("Surface", context.surface)
                    issueContextRow("Scope", context.scope)
                    issueContextRow("Runtime", context.runtime)
                    issueContextRow("Owner", context.owner, monospaced: surface.path != nil)
                    issueContextRow("Write", context.write)
                    issueContextRow("After fix", context.afterFix)
                }

                if let profileName = Self.codexPluginPolicyProfileName(from: issue) {
                    Text("This finding applies when Codex CLI is launched with `codex --profile \(profileName)`. Codex Desktop uses separate default/static Codex config evidence unless another Desktop finding is shown.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(9)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5))
        }
    }

    private func issueContextRow(_ title: String, _ value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 54, alignment: .leading)
            Text(value)
                .font(monospaced ? .system(size: 10, design: .monospaced) : .system(size: 10))
                .foregroundColor(.primary)
                .lineLimit(2)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }

    private func runtimeLabel(for issue: CompatibilityIssue, surface: CompatibilityMatrixEntry) -> String {
        Self.runtimeLabel(for: issue, surface: surface)
    }

    static func runtimeLabel(for issue: CompatibilityIssue, surface: CompatibilityMatrixEntry) -> String {
        if surface.toolID == .codexCLI,
           let profileName = Self.codexPluginPolicyProfileName(from: issue) {
            return "Codex CLI - codex --profile \(profileName)"
        }
        return surface.toolID.label
    }

    private func scopeLabel(_ scope: CompatibilityScope) -> String {
        Self.scopeLabel(scope)
    }

    static func scopeLabel(_ scope: CompatibilityScope) -> String {
        switch scope {
        case .global:
            return "Global"
        case .project:
            return "Project"
        case .localProjectUser:
            return "Local project user"
        case .desktopApp:
            return "Desktop app"
        case .account:
            return "Account"
        case .runtime:
            return "Runtime"
        }
    }

    static let findingReportHeaderColumns = [
        "Severity",
        "State",
        "Tool",
        "Surface",
        "Scope",
        "Runtime",
        "Owner",
        "Write",
        "After fix",
        "Finding",
        "Subject",
        "Evidence path"
    ]

    static func issueReportContext(
        for issue: CompatibilityIssue,
        surface: CompatibilityMatrixEntry?,
        shortPath: (String) -> String
    ) -> CompatibilityIssueReportContext {
        guard let surface else {
            return CompatibilityIssueReportContext(
                surface: issue.surfaceID ?? "Multiple surfaces",
                scope: "",
                runtime: issue.toolID?.label ?? "Project Hub",
                owner: issue.path.map(shortPath) ?? "",
                write: "",
                afterFix: ""
            )
        }

        return CompatibilityIssueReportContext(
            surface: surface.label,
            scope: scopeLabel(surface.scope),
            runtime: runtimeLabel(for: issue, surface: surface),
            owner: surface.path.map(shortPath) ?? "UI/runtime only",
            write: writeLabel(for: surface),
            afterFix: surface.requiresRestartAfterWrite ? "Restart required" : "Rescan after reload"
        )
    }

    static func findingReportValues(
        for issue: CompatibilityIssue,
        surface: CompatibilityMatrixEntry?,
        evidencePath: String?,
        shortPath: (String) -> String,
        stateLabel: (CompatibilityHealthState) -> String
    ) -> [String] {
        let context = issueReportContext(for: issue, surface: surface, shortPath: shortPath)
        return [
            "\(issue.severity)",
            stateLabel(issue.state),
            issue.toolID?.label ?? "Project Hub",
            context.surface,
            context.scope,
            context.runtime,
            context.owner,
            context.write,
            context.afterFix,
            "\(issue.title): \(issue.detail)",
            issue.subjectPath ?? "",
            evidencePath.map(shortPath) ?? ""
        ]
    }

    private func claudeInvocationSummary(_ skill: CompatibilitySkillObservation) -> String? {
        var parts: [String] = []
        if skill.claudeDisableModelInvocation == true {
            parts.append("user only")
        } else if skill.claudeDisableModelInvocation == false {
            parts.append("model allowed")
        }
        if skill.claudeUserInvocable == false {
            parts.append("hidden from slash menu")
        } else if skill.claudeUserInvocable == true {
            parts.append("slash menu")
        }
        if let hint = skill.claudeArgumentHint {
            parts.append("hint \(hint)")
        } else if !skill.claudeArguments.isEmpty {
            parts.append("args \(joinedCompact(skill.claudeArguments, limit: 3))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private func claudeRuntimeSummary(_ skill: CompatibilitySkillObservation) -> String? {
        var parts: [String] = []
        if let model = skill.claudeModel {
            parts.append("model \(model)")
        }
        if let effort = skill.claudeEffort {
            parts.append("effort \(effort)")
        }
        if let context = skill.claudeContext {
            parts.append("context \(context)")
        }
        if let agent = skill.claudeAgent {
            parts.append("agent \(agent)")
        }
        if let shell = skill.claudeShell {
            parts.append("shell \(shell)")
        }
        if skill.claudeHooks != nil {
            parts.append("hooks")
        }
        if skill.claudeShellExecutionDisabled {
            parts.append("shell disabled")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private func claudeOverrideBadge(_ state: String) -> String {
        switch state {
        case "name-only":
            return "Name only"
        case "user-invocable-only":
            return "User only"
        case "off":
            return "Off"
        default:
            return state
        }
    }

    private func joinedCompact(_ values: [String], limit: Int = 4) -> String {
        guard values.count > limit else { return values.joined(separator: ", ") }
        let visible = values.prefix(limit).joined(separator: ", ")
        return "\(visible), +\(values.count - limit)"
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary.opacity(0.75))
            Text("\(count)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checklist.checked")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("Run a compatibility scan")
                .font(.system(size: 13, weight: .semibold))
            Text("Scans Claude Code, Claude Desktop, Codex CLI, and Codex Desktop across MCP, skills, settings, auth, and project context.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button(action: refresh) {
                HStack(spacing: 5) {
                    if scanning {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.white)
                    }
                    Text(scanning ? "Scanning" : "Scan")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(ContentView.headerGrad)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .disabled(scanning)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private func issueSheet(_ issue: CompatibilityIssue) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 14, weight: .semibold))
                Text(issue.title)
                    .font(.system(size: 15, weight: .bold))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(ContentView.headerGrad)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    labelBlock("What we found", issue.detail)
                    labelBlock("Affected tool", issue.toolID?.label ?? "Multiple tools")
                    issueApplicabilityBlock(issue)
                    if let path = evidencePath(for: issue) {
                        labelBlock("File", shortPath(path), monospaced: true)
                    }
                    labelBlock("Recommended fix", issue.fixHint ?? "Review this item before applying automated changes.")
                    labelBlock("Issue code", issue.code.rawValue, monospaced: true)

                    if let plan = fixPlan(for: issue) {
                        safeFixBlock(plan)
                    } else {
                        manualFixBlock(for: issue)
                    }

                    if let fixError {
                        HStack(alignment: .top, spacing: 7) {
                            Image(systemName: "xmark.octagon.fill")
                                .foregroundColor(.red)
                            Text(fixError)
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(9)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                }
                .padding(14)
            }
        }
    }

    private func safeFixBlock(_ plan: CompatibilityFixPlan) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "wrench.adjustable.fill")
                    .foregroundColor(.accentColor)
                Text("Previewed file fix")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text(plan.requiresRestart ? "Restart required" : "Rescan after reload")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(plan.requiresRestart ? .blue : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((plan.requiresRestart ? Color.blue : Color.secondary).opacity(0.10))
                    .clipShape(Capsule())
            }
            Text(plan.summary)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(shortPath(plan.path))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if let willChange = plan.willChange {
                changeNote("Will change", willChange, icon: "pencil.and.list.clipboard")
            }
            if let willNotChange = plan.willNotChange {
                changeNote("Will not change", willNotChange, icon: "lock.doc")
            }

            diffPreview(before: plan.before, after: plan.after)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "externaldrive.badge.timemachine")
                    .foregroundColor(.secondary)
                Text("Project Hub creates a timestamped backup before replacing an existing file.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button {
                    apply(plan)
                } label: {
                    HStack(spacing: 5) {
                        if applyingFix {
                            ProgressView()
                                .scaleEffect(0.55)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: plan.icon)
                        }
                        Text(plan.actionLabel)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ContentView.headerGrad)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(applyingFix)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.18), lineWidth: 1))
    }

    private func changeNote(_ title: String, _ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                Text(text)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background(Color(NSColor.textBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func manualFixBlock(for issue: CompatibilityIssue) -> some View {
        let guidance = manualGuidance(for: issue)
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: guidance.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(stateColor(issue.state))
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 3) {
                    Text(guidance.title)
                        .font(.system(size: 11, weight: .bold))
                    Text(guidance.detail)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(guidance.steps.enumerated()), id: \.offset) { index, step in
                    manualStepRow(number: index + 1, text: step)
                }
            }

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lock.shield")
                    .foregroundColor(.secondary)
                Text(guidance.safetyNote)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if let path = issue.path {
                    Button {
                        revealPath(path)
                    } label: {
                        Label("Reveal Evidence", systemImage: "folder")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                }

                if issue.toolID == .claudeDesktop {
                    Button {
                        openClaudeDesktop()
                    } label: {
                        Label("Open Claude", systemImage: "arrow.up.right.square")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                }

                if issue.toolID == .codexDesktop {
                    Button {
                        openCodexDesktop()
                    } label: {
                        Label("Open Codex", systemImage: "arrow.up.right.square")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Button {
                    copyManualChecklist(for: issue)
                } label: {
                    Label("Copy Checklist", systemImage: "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(stateColor(issue.state).opacity(0.16), lineWidth: 1))
    }

    private func manualStepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Text("\(number)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 17, height: 17)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func manualGuidance(for issue: CompatibilityIssue) -> CompatibilityManualGuidance {
        if let guidance = codexRequirementsManualGuidance(for: issue) {
            return guidance
        }

        if isMissingCodexInstructionFileIssue(issue) {
            let key = issue.subjectPath ?? "model_instructions_file"
            return CompatibilityManualGuidance(
                title: "Repair Codex instruction override",
                icon: "text.badge.xmark",
                detail: "Codex is configured to use a \(key) path, but that file was not found. Project Hub cannot tell whether the path is stale or the file still needs to be created.",
                steps: [
                    "Open the listed missing file path and the Codex config surface shown in Where this applies.",
                    "If the override is intentional, create the referenced file or update \(key) to the correct path.",
                    "If the override is stale, remove \(key) so Codex can fall back to normal AGENTS.md project guidance.",
                    "Restart or reload the affected Codex runtime if needed, then run Scan again."
                ],
                safetyNote: "Project Hub only removes this override automatically when it can preview the exact Codex config key that will change."
            )
        }

        switch issue.code {
        case .serverAuthMissing, .serverAuthExpired, .serverOAuthNeeded, .authCredentialStore:
            return CompatibilityManualGuidance(
                title: "Use the official auth flow",
                icon: "key.fill",
                detail: "This needs a login, OAuth refresh, credential-store check, or app-owned token update outside Project Hub.",
                steps: [
                    "Open the affected tool and complete its official login, connector, or OAuth flow.",
                    "If this server uses an environment-backed token, set it in the launch environment for that tool.",
                    "Restart the affected app or terminal session if credentials or environment changed.",
                    "Run Scan, then Verify to confirm the MCP handshake and tools/list call."
                ],
                safetyNote: "Project Hub does not write secrets, read keychain tokens, or ask you to paste credentials into this app."
            )
        case .serverAuthRuntimeManaged:
            return CompatibilityManualGuidance(
                title: "Verify app-managed authentication",
                icon: "key.fill",
                detail: "The target tool owns this MCP authentication through OAuth, a connector, a credential store, or a headers helper.",
                steps: [
                    "Open the affected tool and check the MCP connector, OAuth, or login status there.",
                    "If this uses a headers helper, verify the helper through the target tool; Project Hub will not execute it.",
                    "Refresh or complete the browser login if the connector reports an expired or missing token.",
                    "Restart or reload the target runtime if the auth state changed, then run Scan and Verify again."
                ],
                safetyNote: "Project Hub preserves app-owned auth metadata but does not execute helper commands, read keychain secrets, or impersonate browser OAuth flows."
            )
        case .serverEnvMissing:
            return CompatibilityManualGuidance(
                title: "Provide the launch environment",
                icon: "terminal.fill",
                detail: "The server references an environment variable that is not visible to the target process.",
                steps: [
                    "Set the missing variable in the shell, launch agent, app config, or official connector flow used by the target tool.",
                    "Keep credential values in environment, keychain, or the vendor auth flow rather than committing them to project files.",
                    "Quit and reopen the affected app or start a fresh terminal session so it inherits the new environment.",
                    "Run Scan, then Verify to confirm Project Hub can see the variable and the server starts."
                ],
                safetyNote: "Project Hub reports the missing variable name only; it will not store or write the secret value."
            )
        case .serverNeedsRestart, .settingsSessionReloadRequired:
            return CompatibilityManualGuidance(
                title: "Restart or reload the target",
                icon: "arrow.clockwise.circle.fill",
                detail: "The file state changed, but this tool usually reads MCP or settings at launch.",
                steps: [
                    "Quit and reopen the affected desktop app, or start a fresh CLI session for the project.",
                    "If the tool has a reload command for MCP or connectors, use that official reload path.",
                    "Run Scan again to clear stale restart findings.",
                    "Run Verify to confirm the server responds after reload."
                ],
                safetyNote: "Project Hub can preview file edits, but it cannot force every external app to reload its cached runtime state."
            )
        case .settingsManagedRequirement:
            return CompatibilityManualGuidance(
                title: "Managed by policy or runtime",
                icon: "building.2.crop.circle",
                detail: "This setting is controlled by an admin, device policy, or app/runtime surface.",
                steps: [
                    "Review the listed policy or runtime-owned setting and decide whether it is expected for this machine.",
                    "If it is unexpected, change it through the administrator, MDM profile, vendor app UI, or account console.",
                    "Do not edit managed policy files directly unless you own that management channel.",
                    "Run Scan again after the policy or runtime setting changes."
                ],
                safetyNote: "Project Hub keeps managed/admin settings read-only to avoid fighting the tool that owns them."
            )
        case .serverDisabled, .skillDisabled:
            return CompatibilityManualGuidance(
                title: "Review disabled availability",
                icon: "pause.circle.fill",
                detail: "This item is installed or configured, but the target tool currently treats it as disabled.",
                steps: [
                    "Decide whether this item should stay intentionally disabled for this target and scope.",
                    "If a previewed Enable action is available above, review exactly which file will change before applying it.",
                    "If no previewed action is available, enable it through the owning app UI or the documented config file for that tool.",
                    "Restart or reload the affected tool if the owning surface reads config only at launch, then run Scan again."
                ],
                safetyNote: "Project Hub only enables disabled items automatically when it can preview a precise file move or override change."
            )
        case .serverDuplicateName, .serverConflictDifferentConfig, .serverShadowedByProjectLayer,
             .skillDuplicateName, .skillVersionConflict,
             .projectSettingsShadowed, .contextDiverged:
            return CompatibilityManualGuidance(
                title: "Resolve the precedence conflict",
                icon: "exclamationmark.triangle.fill",
                detail: "Multiple definitions or settings can affect the same name, so the tool may choose one by precedence.",
                steps: [
                    "Compare each listed path and scope before deleting, renaming, or promoting a definition.",
                    "Keep duplicates only when the override is intentional and the winning scope is clear.",
                    "Use a previewed fix when Project Hub offers one; otherwise change the owning config directly or through the tool UI.",
                    "Run Scan again to confirm only the intended definition or version remains active."
                ],
                safetyNote: "Project Hub avoids guessing which duplicate should win because that choice can change behavior across CLI, desktop, and project scopes."
            )
        case .serverHealthUnknown:
            return CompatibilityManualGuidance(
                title: "Verify the runtime state",
                icon: "questionmark.circle.fill",
                detail: "The static scan cannot prove whether this server or runtime-owned surface is currently usable.",
                steps: [
                    "Use Verify for direct MCP handshakes when this is a local or remote MCP server.",
                    "For app-owned extensions or account connectors, open the owning app UI and check its connector status.",
                    "Inspect the evidence path when present for recent startup, auth, timeout, or protocol messages.",
                    "Run Scan again after fixing any app-side state."
                ],
                safetyNote: "Project Hub avoids launching app-managed extension internals unless the target surface is safe to verify directly."
            )
        case .serverRuntimeManaged:
            return CompatibilityManualGuidance(
                title: "Verify in the owning app",
                icon: "app.fill",
                detail: "The static scan found a runtime-owned MCP surface, such as a Desktop connector or MCPB/DXT extension, that Project Hub should not launch directly.",
                steps: [
                    "Open the owning app UI for this connector or extension.",
                    "Check required user configuration, permissions, signing, and enabled/disabled state.",
                    "Use the app's own reload, reconnect, or extension settings flow if anything changed.",
                    "Run Scan again after the app updates its local state or logs."
                ],
                safetyNote: "Project Hub keeps app-owned runtime surfaces read-only so it does not fight connector state, extension installers, or account-managed configuration."
            )
        default:
            return CompatibilityManualGuidance(
                title: "Manual follow-up required",
                icon: "hand.raised.fill",
                detail: "This item does not have a safe automatic writer yet.",
                steps: [
                    "Review the finding and the affected tool before changing configuration.",
                    "Use the tool's official UI, installer, login flow, or documented config path for the change.",
                    "Run Scan again after the change.",
                    "Run Verify when the finding affects an MCP server."
                ],
                safetyNote: "Project Hub only applies fixes when it can preview an exact local file change and back it up first."
            )
        }
    }

    private func codexRequirementsManualGuidance(for issue: CompatibilityIssue) -> CompatibilityManualGuidance? {
        guard issue.surfaceID == "codex-requirements" else { return nil }
        let pathText = issue.path.map { " at \($0)" } ?? ""
        let subject = issue.subjectPath ?? "this requirement"

        if subject.hasPrefix("permissions.filesystem") || issue.title.localizedCaseInsensitiveContains("filesystem") {
            return CompatibilityManualGuidance(
                title: "Fix Codex filesystem requirement",
                icon: "lock.shield.fill",
                detail: "This Codex requirements policy\(pathText) is malformed. Requirements are admin-enforced, so Project Hub keeps this file read-only.",
                steps: [
                    "Change \(subject) through the owner of the requirements policy, not through a user or project config override.",
                    "Use permissions.filesystem.deny_read as an array of string paths or glob patterns.",
                    "Ask the policy owner to remove or replace unknown filesystem requirement keys such as read_only unless they are confirmed in the current Codex config reference.",
                    "Run Scan again after the policy file or managed source is updated."
                ],
                safetyNote: "Project Hub treats requirements as machine-level policy and will not try to override or edit them from user/project config."
            )
        }

        if subject.hasPrefix("mcp_servers.") || issue.title.localizedCaseInsensitiveContains("identity") {
            return CompatibilityManualGuidance(
                title: "Fix Codex MCP identity requirement",
                icon: "checkmark.shield.fill",
                detail: "This Codex MCP identity requirement\(pathText) is malformed. Requirements are admin-enforced, so Project Hub keeps this file read-only.",
                steps: [
                    "Change \(subject) through the owner of the requirements policy, not through a user or project config override.",
                    "Set mcp_servers.<id>.identity as a table with exactly one identity type.",
                    "Use command = \"...\" for stdio MCP servers or url = \"https://...\" for streamable HTTP MCP servers.",
                    "Ask the policy owner to remove or replace unknown identity keys and run Scan again after the policy source is updated."
                ],
                safetyNote: "Project Hub does not edit requirements.toml because it may be managed by an administrator, deployment image, or cloud policy."
            )
        }

        return CompatibilityManualGuidance(
            title: "Fix Codex requirements policy",
            icon: "building.2.crop.circle",
            detail: "This Codex requirements policy\(pathText) is malformed or unsupported. Project Hub treats requirements as inspect-only managed policy.",
            steps: [
                "Review the finding and confirm which admin, image, or cloud-managed source owns this requirements file.",
                "Update the requirement through that owner using Codex's documented requirements keys.",
                "Avoid trying to override the requirement in user or project config.",
                "Run Scan again after the policy source is updated."
            ],
            safetyNote: "Project Hub keeps requirements read-only so it does not weaken or fight machine-level Codex policy."
        )
    }

    private func diffPreview(before: String, after: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("FILE PREVIEW")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Before -> After")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.75))
            }
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lineDiff(before: before, after: after).enumerated()), id: \.offset) { _, line in
                        HStack(spacing: 0) {
                            Text(line.symbol)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(line.color)
                                .frame(width: 14, alignment: .leading)
                            Text(line.text.isEmpty ? " " : line.text)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(line.color)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 180)
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor).opacity(0.55), lineWidth: 0.5))
        }
    }

    private func fixPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        if let plan = claudeApprovalConflictPlan(for: issue) {
            return plan
        }
        if let plan = disabledCodexPluginMCPServerPlan(for: issue) {
            return plan
        }
        if let plan = shadowedCodexPluginMCPPolicyPlan(for: issue) {
            return plan
        }
        if let plan = invalidCodexPluginMCPPolicyKeyPlan(for: issue) {
            return plan
        }
        if let plan = disabledCodexSkillOverridePlan(for: issue) {
            return plan
        }
        if let plan = staleCodexSkillOverridePlan(for: issue) {
            return plan
        }
        if let plan = deprecatedCodexApprovalPlan(for: issue) {
            return plan
        }
        if let plan = deprecatedCodexInstructionFilePlan(for: issue) {
            return plan
        }
        if let plan = missingCodexInstructionFilePlan(for: issue) {
            return plan
        }
        if let plan = unknownCodexApprovalPlan(for: issue) {
            return plan
        }
        if let plan = unknownCodexSandboxModePlan(for: issue) {
            return plan
        }
        if let plan = invalidCodexTopLevelEnumPlan(for: issue) {
            return plan
        }
        if let plan = invalidCodexProfileEnumPlan(for: issue) {
            return plan
        }
        if let plan = invalidCodexProjectTrustPlan(for: issue) {
            return plan
        }
        if let plan = unknownCodexGranularApprovalKeyPlan(for: issue) {
            return plan
        }
        if let plan = unknownCodexSandboxWorkspaceWriteKeyPlan(for: issue) {
            return plan
        }
        if let plan = unknownCodexWebSearchKeyPlan(for: issue) {
            return plan
        }
        if let plan = invalidCodexWebSearchSettingPlan(for: issue) {
            return plan
        }
        if let plan = unknownCodexNetworkProxyKeyPlan(for: issue) {
            return plan
        }
        if let plan = invalidCodexNetworkProxySettingPlan(for: issue) {
            return plan
        }
        if let plan = invalidCodexNetworkProxyRulePlan(for: issue) {
            return plan
        }
        if let plan = invalidCodexPermissionNetworkSettingPlan(for: issue) {
            return plan
        }
        if let plan = invalidCodexPermissionNetworkRulePlan(for: issue) {
            return plan
        }
        if let plan = unknownCodexPermissionNetworkKeyPlan(for: issue) {
            return plan
        }
        if let plan = invalidCodexFilesystemGlobDepthPlan(for: issue) {
            return plan
        }
        if let plan = invalidCodexWorkspaceRootEntryPlan(for: issue) {
            return plan
        }
        if let plan = invalidCodexFilesystemPermissionRulePlan(for: issue) {
            return plan
        }
        if let plan = invalidCodexProjectDocMaxBytesPlan(for: issue) {
            return plan
        }
        if let plan = invalidCodexFallbackFilenamesPlan(for: issue) {
            return plan
        }
        if let plan = invalidCodexProjectRootMarkersPlan(for: issue) {
            return plan
        }
        if let plan = codexProjectTrustPlan(for: issue) {
            return plan
        }
        if let plan = claudeLocalSettingsGitignorePlan(for: issue) {
            return plan
        }
        if let plan = codexProjectOverlapPlan(for: issue) {
            return plan
        }
        if let plan = ignoredCodexProjectSettingsPlan(for: issue) {
            return plan
        }
        if let plan = instructionSyncPlan(for: issue) {
            return plan
        }
        if let plan = emptyInstructionSyncPlan(for: issue) {
            return plan
        }
        if let plan = instructionMergePlan(for: issue) {
            return plan
        }
        if let plan = disabledCodexProjectDocMaxBytesPlan(for: issue) {
            return plan
        }
        if let plan = codexProjectDocMaxBytesPlan(for: issue) {
            return plan
        }

        guard let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              let server = matchingServer(for: issue, in: report),
              let target = writerTarget(for: surface, report: report)
        else { return nil }

        switch issue.code {
        case .serverDisabled where surface.supportsDisable:
            guard let preview = ConfigWriter.previewSetServerEnabled(
                toolID: target.toolID,
                scope: target.scope,
                projectRoot: target.projectRoot,
                name: server.name,
                enabled: true
            ) else { return nil }
            return CompatibilityFixPlan(
                title: "Enable \(server.name)",
                summary: "Move this MCP server back into the active set for \(surface.label).",
                actionLabel: "Enable server",
                icon: "play.fill",
                path: target.path,
                before: preview.before,
                after: preview.after,
                willChange: "Move \(server.name) from the disabled MCP set into the active set.",
                willNotChange: "Installed packages, credentials, and unrelated MCP servers stay untouched.",
                requiresRestart: surface.requiresRestartAfterWrite,
                apply: {
                    try ConfigWriter.applyTextPreview(
                        configPath: target.path,
                        expectedBefore: preview.before,
                        approvedAfter: preview.after
                    )
                }
            )
        case .serverCommandMissing, .serverMissingLaunchTarget, .serverUnsupportedTransport:
            guard let preview = ConfigWriter.previewRemoveServer(
                toolID: target.toolID,
                scope: target.scope,
                projectRoot: target.projectRoot,
                name: server.name
            ) else { return nil }
            return CompatibilityFixPlan(
                title: "Remove \(server.name)",
                summary: "Remove this broken MCP definition from \(surface.label). This does not uninstall packages or touch credentials.",
                actionLabel: "Remove server",
                icon: "trash.fill",
                path: target.path,
                before: preview.before,
                after: preview.after,
                willChange: "Remove only the \(server.name) registration from this config file.",
                willNotChange: "Packages, source files, credentials, and other MCP server entries stay untouched.",
                requiresRestart: surface.requiresRestartAfterWrite,
                apply: {
                    try ConfigWriter.applyTextPreview(
                        configPath: target.path,
                        expectedBefore: preview.before,
                        approvedAfter: preview.after
                    )
                }
            )
        default:
            return nil
        }
    }

    private func instructionSyncPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configMissing,
              issue.title.localizedCaseInsensitiveContains("project instructions missing"),
              let targetPath = issue.path,
              let sourcePath = issue.subjectPath,
              !FileManager.default.fileExists(atPath: targetPath),
              let raw = try? String(contentsOfFile: sourcePath, encoding: .utf8)
        else { return nil }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let content = raw.hasSuffix("\n") ? raw : raw + "\n"
        guard let preview = ConfigWriter.previewWriteTextFileIfMissing(path: targetPath, content: content) else {
            return nil
        }

        let targetName = (targetPath as NSString).lastPathComponent
        let sourceName = (sourcePath as NSString).lastPathComponent
        let title = targetName == "CLAUDE.md" ? "Create Claude instructions" : "Create Codex instructions"

        return CompatibilityFixPlan(
            title: title,
            summary: "Create \(targetName) from \(sourceName) so Claude and Codex have matching project guidance to review.",
            actionLabel: "Create \(targetName)",
            icon: "doc.badge.plus",
            path: targetPath,
            before: preview.before,
            after: preview.after,
            willChange: "Create \(CompatibilityScanner.tilde(targetPath)) with the current contents of \(CompatibilityScanner.tilde(sourcePath)).",
            willNotChange: "The source instruction file, MCP servers, auth files, skills, and tool settings stay untouched.",
            requiresRestart: true,
            apply: {
                try ConfigWriter.writeTextFileIfMissing(path: targetPath, content: content)
            }
        )
    }

    private func emptyInstructionSyncPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .contextEmpty,
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              surface.kind == .context,
              surface.scope == .project,
              let targetPath = issue.path,
              let sourcePath = counterpartInstructionSource(for: surface, in: report),
              let raw = try? String(contentsOfFile: sourcePath, encoding: .utf8)
        else { return nil }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let content = raw.hasSuffix("\n") ? raw : raw + "\n"
        guard let preview = ConfigWriter.previewWriteTextFileIfEmpty(path: targetPath, content: content) else {
            return nil
        }

        let targetName = (targetPath as NSString).lastPathComponent
        let sourceName = (sourcePath as NSString).lastPathComponent
        let title = targetName == "CLAUDE.md" ? "Fill Claude instructions" : "Fill Codex instructions"

        return CompatibilityFixPlan(
            title: title,
            summary: "Fill the empty \(targetName) from \(sourceName) so Claude and Codex have matching project guidance to review.",
            actionLabel: "Fill \(targetName)",
            icon: "doc.badge.gearshape",
            path: targetPath,
            before: preview.before,
            after: preview.after,
            willChange: "Replace only the empty \(CompatibilityScanner.tilde(targetPath)) with the current contents of \(CompatibilityScanner.tilde(sourcePath)).",
            willNotChange: "Non-empty instruction files, the source instruction file, MCP servers, auth files, skills, and tool settings stay untouched.",
            requiresRestart: true,
            apply: {
                try ConfigWriter.writeTextFileIfEmpty(path: targetPath, content: content)
            }
        )
    }

    private func instructionMergePlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .contextDiverged,
              let targetPath = issue.path,
              let sourcePath = issue.subjectPath,
              (targetPath as NSString).lastPathComponent == "CLAUDE.md",
              (targetPath as NSString).deletingLastPathComponent == (sourcePath as NSString).deletingLastPathComponent,
              let existing = try? String(contentsOfFile: targetPath, encoding: .utf8),
              let sourceRaw = try? String(contentsOfFile: sourcePath, encoding: .utf8),
              !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !sourceRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !claudeInstructionImports(existing, sourcePath: sourcePath, from: targetPath)
        else { return nil }

        let sourceName = (sourcePath as NSString).lastPathComponent
        let merged = "@\(sourceName)\n\n" + existing
        guard let preview = ConfigWriter.previewMergeTextFile(
            path: targetPath,
            expectedBefore: existing,
            mergedContent: merged
        ) else { return nil }

        return CompatibilityFixPlan(
            title: "Import Codex guidance",
            summary: "Add an @\(sourceName) import to CLAUDE.md so Claude Code reads the same base project guidance as Codex.",
            actionLabel: "Add import",
            icon: "doc.on.doc.fill",
            path: targetPath,
            before: preview.before,
            after: preview.after,
            willChange: "Prepend @\(sourceName) to \(CompatibilityScanner.tilde(targetPath)) and keep the existing Claude-specific content below it.",
            willNotChange: "\(CompatibilityScanner.tilde(sourcePath)), MCP servers, auth files, skills, and tool settings stay untouched.",
            requiresRestart: true,
            apply: {
                try ConfigWriter.mergeTextFile(
                    path: targetPath,
                    expectedBefore: existing,
                    mergedContent: merged
                )
            }
        )
    }

    private func counterpartInstructionSource(
        for surface: CompatibilityMatrixEntry,
        in report: CompatibilityScanResult
    ) -> String? {
        guard let targetPath = surface.path else { return nil }
        let targetName = (targetPath as NSString).lastPathComponent

        if surface.toolID == .claudeCode {
            guard targetName == "CLAUDE.md" else { return nil }
            return activeCodexInstructionPath(
                in: report,
                directory: instructionDirectory(for: targetPath, toolID: surface.toolID)
            )
        }

        guard (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              targetName == "AGENTS.md",
              activeCodexInstructionPath(
                in: report,
                directory: instructionDirectory(for: targetPath, toolID: surface.toolID)
              ) == nil,
              let claudePath = activeClaudeInstructionPath(
                in: report,
                directory: instructionDirectory(for: targetPath, toolID: surface.toolID)
              ),
              instructionFileIsNonEmpty(claudePath)
        else { return nil }
        return claudePath
    }

    private func activeCodexInstructionPath(
        in report: CompatibilityScanResult,
        directory: String
    ) -> String? {
        let candidates = report.matrix
            .filter { $0.toolID == .codexCLI && $0.scope == .project && $0.kind == .context }
            .compactMap(\.path)
            .filter { instructionDirectory(for: $0, toolID: .codexCLI) == directory }
            .filter(instructionFileIsNonEmpty)
        return candidates.sorted { lhs, rhs in
            if codexInstructionRank(lhs) != codexInstructionRank(rhs) {
                return codexInstructionRank(lhs) < codexInstructionRank(rhs)
            }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }.first
    }

    private func activeClaudeInstructionPath(
        in report: CompatibilityScanResult,
        directory: String
    ) -> String? {
        let candidates = report.matrix
            .filter { $0.toolID == .claudeCode && $0.kind == .context }
            .compactMap(\.path)
            .filter { instructionDirectory(for: $0, toolID: .claudeCode) == directory }
            .filter(instructionFileIsNonEmpty)
        return candidates.sorted { lhs, rhs in
            if claudeInstructionRank(lhs) != claudeInstructionRank(rhs) {
                return claudeInstructionRank(lhs) < claudeInstructionRank(rhs)
            }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }.first
    }

    private func instructionFileIsNonEmpty(_ path: String) -> Bool {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return false }
        return !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func claudeInstructionImports(_ claudeRaw: String, sourcePath: String, from claudePath: String) -> Bool {
        let sourceURL = URL(fileURLWithPath: sourcePath).standardizedFileURL
        let claudeDirectory = URL(fileURLWithPath: claudePath).deletingLastPathComponent()
        return claudeRaw.components(separatedBy: .newlines).contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("@") else { return false }
            let importPath = String(trimmed.dropFirst())
                .split(whereSeparator: { $0 == " " || $0 == "\t" })
                .first
                .map(String.init) ?? ""
            guard !importPath.isEmpty else { return false }
            let resolved: URL
            if importPath.hasPrefix("~") {
                resolved = URL(fileURLWithPath: (importPath as NSString).expandingTildeInPath)
            } else if importPath.hasPrefix("/") {
                resolved = URL(fileURLWithPath: importPath)
            } else {
                resolved = claudeDirectory.appendingPathComponent(importPath)
            }
            return resolved.standardizedFileURL.path == sourceURL.path
        }
    }

    private func instructionDirectory(for path: String, toolID: CompatibilityToolID) -> String {
        if toolID == .claudeCode,
           (path as NSString).lastPathComponent == "CLAUDE.md",
           ((path as NSString).deletingLastPathComponent as NSString).lastPathComponent == ".claude" {
            return (((path as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent)
        }
        return (path as NSString).deletingLastPathComponent
    }

    private func codexInstructionRank(_ path: String) -> Int {
        let filename = (path as NSString).lastPathComponent
        if filename == "AGENTS.override.md" { return 0 }
        if filename == "AGENTS.md" { return 1 }
        return 2
    }

    private func claudeInstructionRank(_ path: String) -> Int {
        let filename = (path as NSString).lastPathComponent
        if filename == "CLAUDE.md" {
            let directory = (path as NSString).deletingLastPathComponent
            return (directory as NSString).lastPathComponent == ".claude" ? 1 : 0
        }
        if filename == "CLAUDE.local.md" { return 2 }
        return 3
    }

    private func invalidCodexProjectDocMaxBytesPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configUnsupportedShape,
              issue.title.localizedCaseInsensitiveContains("project_doc_max_bytes"),
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path,
              let preview = ConfigWriter.previewUpsertTopLevelTOMLIntSetting(
                configPath: path,
                key: "project_doc_max_bytes",
                value: 32_768
              )
        else { return nil }

        return CompatibilityFixPlan(
            title: "Reset Codex instruction limit",
            summary: "Replace the malformed project_doc_max_bytes value with Codex's default positive integer.",
            actionLabel: "Use 32768",
            icon: "text.badge.checkmark",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Change only the top-level project_doc_max_bytes value to 32768 in \(surface.label).",
            willNotChange: "MCP servers, approvals, sandbox mode, profiles, project sections, auth files, skills, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func invalidCodexTopLevelEnumPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        let removableKeys: Set<String> = [
            "model_reasoning_effort",
            "model_reasoning_summary",
            "model_verbosity",
            "oss_provider",
            "approvals_reviewer",
            "web_search"
        ]
        guard issue.code == .configUnsupportedShape,
              issue.title.hasPrefix("Invalid Codex "),
              let key = issue.subjectPath,
              removableKeys.contains(key),
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path,
              let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
                configPath: path,
                keys: [key]
              )
        else { return nil }

        return CompatibilityFixPlan(
            title: "Remove invalid Codex \(key)",
            summary: "Delete the invalid top-level \(key) value so Codex can use its documented default or profile-specific override.",
            actionLabel: "Remove setting",
            icon: "text.badge.minus",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only the top-level \(key) line from \(surface.label).",
            willNotChange: "MCP servers, approvals, sandbox mode, profiles, project sections, auth files, skills, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func invalidCodexProfileEnumPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        let removableKeys: Set<String> = [
            "model_reasoning_effort",
            "model_reasoning_summary",
            "model_verbosity",
            "oss_provider",
            "approvals_reviewer",
            "web_search",
            "approval_policy",
            "sandbox_mode"
        ]
        guard issue.code == .configUnsupportedShape,
              let subjectPath = issue.subjectPath,
              let key = removableKeys.first(where: { subjectPath.hasSuffix(".\($0)") }),
              issue.title == "Invalid Codex \(key)",
              let section = codexProfileRootSection(from: subjectPath, key: key),
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path,
              let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
                configPath: path,
                section: section,
                keys: [key]
              )
        else { return nil }

        return CompatibilityFixPlan(
            title: "Remove invalid Codex profile \(key)",
            summary: "Delete the invalid \(key) value from \(section) so that profile falls back to the global/default Codex value.",
            actionLabel: "Remove profile setting",
            icon: "text.badge.minus",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only \(key) from [\(section)] in \(surface.label).",
            willNotChange: "Top-level settings, sibling profiles, project sections, MCP servers, auth files, skills, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func codexProfileRootSection(from subjectPath: String, key: String) -> String? {
        let suffix = ".\(key)"
        guard subjectPath.hasSuffix(suffix) else { return nil }
        let section = String(subjectPath.dropLast(suffix.count))
        guard section.hasPrefix("profiles.") else { return nil }
        let profileName = String(section.dropFirst("profiles.".count))
        guard !profileName.isEmpty,
              !profileName.contains("."),
              !profileName.contains("["),
              !profileName.contains("]") else { return nil }
        return section
    }

    private func invalidCodexProjectTrustPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        let key = "trust_level"
        guard issue.code == .configUnsupportedShape,
              issue.title == "Invalid Codex trust_level",
              let subjectPath = issue.subjectPath,
              let section = codexProjectSection(from: subjectPath),
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path,
              let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
                configPath: path,
                section: section,
                keys: [key]
              )
        else { return nil }

        return CompatibilityFixPlan(
            title: "Remove invalid Codex project trust",
            summary: "Delete the malformed trust_level value from \(section) so Codex can fall back to its normal project trust flow.",
            actionLabel: "Remove trust value",
            icon: "shield.slash.fill",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only trust_level from [\(section)] in \(surface.label).",
            willNotChange: "Top-level settings, profile settings, sibling project sections, MCP servers, auth files, skills, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func codexProjectSection(from subjectPath: String) -> String? {
        let suffix = ".trust_level"
        guard subjectPath.hasSuffix(suffix) else { return nil }
        let section = String(subjectPath.dropLast(suffix.count))
        guard section.hasPrefix("projects.") else { return nil }
        let projectKey = String(section.dropFirst("projects.".count))
        guard !projectKey.isEmpty,
              !projectKey.contains("["),
              !projectKey.contains("]") else { return nil }
        return section
    }

    private func unknownCodexGranularApprovalKeyPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configUnsupportedShape,
              issue.title == "Unknown Codex granular approval key",
              let subjectPath = issue.subjectPath,
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path,
              let target = codexGranularApprovalKeyTarget(from: subjectPath)
        else { return nil }

        if target.isTopLevelDotted,
           let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: path,
            keys: [subjectPath]
           ) {
            return codexGranularApprovalKeyFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "top-level \(subjectPath)",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTopLevelTOMLKeys(
                        configPath: path,
                        keys: [subjectPath]
                    )
                }
            )
        }

        guard let section = target.section,
              let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
                configPath: path,
                section: section,
                keys: [target.key]
              )
        else { return nil }

        return codexGranularApprovalKeyFixPlan(
            surface: surface,
            path: path,
            key: target.key,
            location: "[\(section)]",
            preview: (preview.before, preview.after),
            apply: {
                try ConfigWriter.removeTOMLSectionKeys(
                    configPath: path,
                    section: section,
                    keys: [target.key]
                )
            }
        )
    }

    private func codexGranularApprovalKeyFixPlan(
        surface: CompatibilityMatrixEntry,
        path: String,
        key: String,
        location: String,
        preview: (before: String, after: String),
        apply _: @escaping () throws -> Void
    ) -> CompatibilityFixPlan {
        CompatibilityFixPlan(
            title: "Remove unknown Codex approval key",
            summary: "Delete the unsupported granular approval key \(key) from \(location).",
            actionLabel: "Remove approval key",
            icon: "checkmark.shield.fill",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only the unknown granular approval key \(key) from \(surface.label).",
            willNotChange: "Known approval keys, profiles, project sections, MCP servers, auth files, skills, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func codexGranularApprovalKeyTarget(
        from subjectPath: String
    ) -> (key: String, section: String?, isTopLevelDotted: Bool)? {
        let topLevelPrefix = "approval_policy.granular."
        if subjectPath.hasPrefix(topLevelPrefix) {
            let key = String(subjectPath.dropFirst(topLevelPrefix.count))
            guard isSimpleTOMLKey(key) else { return nil }
            return (key, "approval_policy.granular", true)
        }

        let profileMarker = ".approval_policy.granular."
        guard let markerRange = subjectPath.range(of: profileMarker) else { return nil }
        let section = String(subjectPath[..<markerRange.upperBound]).dropLast()
        let key = String(subjectPath[markerRange.upperBound...])
        guard section.hasPrefix("profiles."),
              isSimpleTOMLKey(key) else { return nil }
        return (key, String(section), false)
    }

    private func isSimpleTOMLKey(_ key: String) -> Bool {
        !key.isEmpty
            && !key.contains(".")
            && !key.contains("[")
            && !key.contains("]")
            && !key.contains("\"")
            && !key.contains("'")
    }

    private func unknownCodexSandboxWorkspaceWriteKeyPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configUnsupportedShape,
              issue.title == "Unknown Codex sandbox workspace-write key",
              let subjectPath = issue.subjectPath,
              let target = codexSandboxWorkspaceWriteKeyTarget(from: subjectPath),
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path
        else { return nil }

        if let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: path,
            keys: [subjectPath]
        ) {
            return codexSandboxWorkspaceWriteKeyFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "top-level \(subjectPath)",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTopLevelTOMLKeys(
                        configPath: path,
                        keys: [subjectPath]
                    )
                }
            )
        }

        if let section = target.tableSection,
           let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: section,
            keys: [target.key]
           ) {
            return codexSandboxWorkspaceWriteKeyFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "[\(section)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTOMLSectionKeys(
                        configPath: path,
                        section: section,
                        keys: [target.key]
                    )
                }
            )
        }

        if target.parentSection == nil,
           let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: nil,
            assignmentKey: "sandbox_workspace_write",
            keys: [target.key]
           ) {
            return codexSandboxWorkspaceWriteKeyFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "inline sandbox_workspace_write table",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeInlineTOMLTableKeys(
                        configPath: path,
                        section: nil,
                        assignmentKey: "sandbox_workspace_write",
                        keys: [target.key]
                    )
                }
            )
        }

        if let parentSection = target.parentSection,
           let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: parentSection,
            assignmentKey: "sandbox_workspace_write",
            keys: [target.key]
           ) {
            return codexSandboxWorkspaceWriteKeyFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "inline sandbox_workspace_write table in [\(parentSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeInlineTOMLTableKeys(
                        configPath: path,
                        section: parentSection,
                        assignmentKey: "sandbox_workspace_write",
                        keys: [target.key]
                    )
                }
            )
        }

        guard let parentSection = target.parentSection,
              let parentKey = target.parentSectionKey,
              let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
                configPath: path,
                section: parentSection,
                keys: [parentKey]
              )
        else { return nil }

        return codexSandboxWorkspaceWriteKeyFixPlan(
            surface: surface,
            path: path,
            key: target.key,
            location: "[\(parentSection)]",
            preview: (preview.before, preview.after),
            apply: {
                try ConfigWriter.removeTOMLSectionKeys(
                    configPath: path,
                    section: parentSection,
                    keys: [parentKey]
                )
            }
        )
    }

    private func codexSandboxWorkspaceWriteKeyFixPlan(
        surface: CompatibilityMatrixEntry,
        path: String,
        key: String,
        location: String,
        preview: (before: String, after: String),
        apply _: @escaping () throws -> Void
    ) -> CompatibilityFixPlan {
        CompatibilityFixPlan(
            title: "Remove unknown Codex sandbox key",
            summary: "Delete the unsupported sandbox workspace-write key \(key) from \(location).",
            actionLabel: "Remove sandbox key",
            icon: "lock.slash.fill",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only the unknown sandbox_workspace_write key \(key) from \(surface.label).",
            willNotChange: "Known sandbox keys, other profile settings, project trust sections, MCP servers, auth files, skills, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func codexSandboxWorkspaceWriteKeyTarget(
        from subjectPath: String
    ) -> (key: String, tableSection: String?, parentSection: String?, parentSectionKey: String?)? {
        let prefix = "sandbox_workspace_write."
        if subjectPath.hasPrefix(prefix) {
            let key = String(subjectPath.dropFirst(prefix.count))
            guard isSimpleTOMLKey(key) else { return nil }
            return (key, "sandbox_workspace_write", nil, nil)
        }

        let profileMarker = ".sandbox_workspace_write."
        guard let markerRange = subjectPath.range(of: profileMarker) else { return nil }
        let profileSection = String(subjectPath[..<markerRange.lowerBound])
        let key = String(subjectPath[markerRange.upperBound...])
        guard profileSection.hasPrefix("profiles."),
              isSimpleTOMLKey(key) else { return nil }

        return (
            key,
            "\(profileSection).sandbox_workspace_write",
            profileSection,
            "sandbox_workspace_write.\(key)"
        )
    }

    private func unknownCodexWebSearchKeyPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configUnsupportedShape,
              issue.title == "Unknown Codex tools.web_search key"
                || issue.title == "Unknown Codex web search location key",
              let subjectPath = issue.subjectPath,
              let target = codexWebSearchKeyTarget(from: subjectPath, title: issue.title),
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path
        else { return nil }

        if let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: path,
            keys: [subjectPath]
        ) {
            return codexWebSearchKeyFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                settingName: target.settingName,
                location: "top-level \(subjectPath)",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTopLevelTOMLKeys(
                        configPath: path,
                        keys: [subjectPath]
                    )
                }
            )
        }

        if let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: target.tableSection,
            keys: [target.key]
        ) {
            return codexWebSearchKeyFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                settingName: target.settingName,
                location: "[\(target.tableSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTOMLSectionKeys(
                        configPath: path,
                        section: target.tableSection,
                        keys: [target.key]
                    )
                }
            )
        }

        if target.settingName == "tools.web_search",
           target.profileSection == nil,
           let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: nil,
            assignmentKey: "tools.web_search",
            keys: [target.key]
           ) {
            return codexWebSearchKeyFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                settingName: target.settingName,
                location: "inline tools.web_search table",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeInlineTOMLTableKeys(
                        configPath: path,
                        section: nil,
                        assignmentKey: "tools.web_search",
                        keys: [target.key]
                    )
                }
            )
        }

        if target.settingName == "tools.web_search",
           let parentSection = target.parentSection,
           let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: parentSection,
            assignmentKey: "web_search",
            keys: [target.key]
           ) {
            return codexWebSearchKeyFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                settingName: target.settingName,
                location: "inline web_search table in [\(parentSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeInlineTOMLTableKeys(
                        configPath: path,
                        section: parentSection,
                        assignmentKey: "web_search",
                        keys: [target.key]
                    )
                }
            )
        }

        if target.settingName == "tools.web_search",
           let profileSection = target.profileSection,
           let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: profileSection,
            assignmentKey: "tools.web_search",
            keys: [target.key]
           ) {
            return codexWebSearchKeyFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                settingName: target.settingName,
                location: "inline tools.web_search table in [\(profileSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeInlineTOMLTableKeys(
                        configPath: path,
                        section: profileSection,
                        assignmentKey: "tools.web_search",
                        keys: [target.key]
                    )
                }
            )
        }

        guard let parentSection = target.parentSection,
              let parentKey = target.parentSectionKey,
              let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
                configPath: path,
                section: parentSection,
                keys: [parentKey]
              )
        else { return nil }

        return codexWebSearchKeyFixPlan(
            surface: surface,
            path: path,
            key: target.key,
            settingName: target.settingName,
            location: "[\(parentSection)]",
            preview: (preview.before, preview.after),
            apply: {
                try ConfigWriter.removeTOMLSectionKeys(
                    configPath: path,
                    section: parentSection,
                    keys: [parentKey]
                )
            }
        )
    }

    private func codexWebSearchKeyFixPlan(
        surface: CompatibilityMatrixEntry,
        path: String,
        key: String,
        settingName: String,
        location: String,
        preview: (before: String, after: String),
        apply _: @escaping () throws -> Void
    ) -> CompatibilityFixPlan {
        CompatibilityFixPlan(
            title: "Remove unknown Codex web search key",
            summary: "Delete the unsupported \(settingName) key \(key) from \(location).",
            actionLabel: "Remove web key",
            icon: "magnifyingglass.circle.fill",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only the unknown \(settingName) key \(key) from \(surface.label). If it is profile-scoped, only that profile's web search setting is edited.",
            willNotChange: "Documented web search keys, other settings in the same profile, sibling profiles, project sections, MCP servers, auth files, skills, and managed policy files are not changed.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func codexWebSearchKeyTarget(
        from subjectPath: String,
        title: String
    ) -> (key: String, tableSection: String, parentSection: String?, parentSectionKey: String?, profileSection: String?, settingName: String)? {
        if title == "Unknown Codex web search location key" {
            return codexNestedWebSearchKeyTarget(
                from: subjectPath,
                topLevelPrefix: "tools.web_search.location.",
                profileMarker: ".tools.web_search.location.",
                tableSuffix: "tools.web_search.location",
                parentSuffix: "tools.web_search",
                parentKeyPrefix: "location.",
                settingName: "tools.web_search.location"
            )
        }

        return codexNestedWebSearchKeyTarget(
            from: subjectPath,
            topLevelPrefix: "tools.web_search.",
            profileMarker: ".tools.web_search.",
            tableSuffix: "tools.web_search",
            parentSuffix: "tools",
            parentKeyPrefix: "web_search.",
            settingName: "tools.web_search"
        )
    }

    private func codexNestedWebSearchKeyTarget(
        from subjectPath: String,
        topLevelPrefix: String,
        profileMarker: String,
        tableSuffix: String,
        parentSuffix: String,
        parentKeyPrefix: String,
        settingName: String
    ) -> (key: String, tableSection: String, parentSection: String?, parentSectionKey: String?, profileSection: String?, settingName: String)? {
        if subjectPath.hasPrefix(topLevelPrefix) {
            let key = String(subjectPath.dropFirst(topLevelPrefix.count))
            guard isSimpleTOMLKey(key) else { return nil }
            return (key, tableSuffix, nil, nil, nil, settingName)
        }

        guard let markerRange = subjectPath.range(of: profileMarker) else { return nil }
        let profileSection = String(subjectPath[..<markerRange.lowerBound])
        let key = String(subjectPath[markerRange.upperBound...])
        guard profileSection.hasPrefix("profiles."),
              isSimpleTOMLKey(key) else { return nil }

        return (
            key,
            "\(profileSection).\(tableSuffix)",
            "\(profileSection).\(parentSuffix)",
            "\(parentKeyPrefix)\(key)",
            profileSection,
            settingName
        )
    }

    private func unknownCodexNetworkProxyKeyPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configUnsupportedShape,
              issue.title == "Unknown Codex network proxy key",
              let subjectPath = issue.subjectPath,
              let target = codexNetworkProxyKeyTarget(from: subjectPath),
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path
        else { return nil }

        if let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: path,
            keys: [subjectPath]
        ) {
            return codexNetworkProxyKeyFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "top-level \(subjectPath)",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTopLevelTOMLKeys(
                        configPath: path,
                        keys: [subjectPath]
                    )
                }
            )
        }

        if let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: target.tableSection,
            keys: [target.key]
        ) {
            return codexNetworkProxyKeyFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "[\(target.tableSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTOMLSectionKeys(
                        configPath: path,
                        section: target.tableSection,
                        keys: [target.key]
                    )
                }
            )
        }

        if target.profileSection == nil,
           let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: nil,
            assignmentKey: "features.network_proxy",
            keys: [target.key]
           ) {
            return codexNetworkProxyKeyFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "inline features.network_proxy table",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeInlineTOMLTableKeys(
                        configPath: path,
                        section: nil,
                        assignmentKey: "features.network_proxy",
                        keys: [target.key]
                    )
                }
            )
        }

        if let parentSection = target.parentSection,
           let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: parentSection,
            assignmentKey: "network_proxy",
            keys: [target.key]
           ) {
            return codexNetworkProxyKeyFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "inline network_proxy table in [\(parentSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeInlineTOMLTableKeys(
                        configPath: path,
                        section: parentSection,
                        assignmentKey: "network_proxy",
                        keys: [target.key]
                    )
                }
            )
        }

        if let profileSection = target.profileSection,
           let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: profileSection,
            assignmentKey: "features.network_proxy",
            keys: [target.key]
           ) {
            return codexNetworkProxyKeyFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "inline features.network_proxy table in [\(profileSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeInlineTOMLTableKeys(
                        configPath: path,
                        section: profileSection,
                        assignmentKey: "features.network_proxy",
                        keys: [target.key]
                    )
                }
            )
        }

        guard let parentSection = target.parentSection,
              let parentKey = target.parentSectionKey,
              let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
                configPath: path,
                section: parentSection,
                keys: [parentKey]
              )
        else { return nil }

        return codexNetworkProxyKeyFixPlan(
            surface: surface,
            path: path,
            key: target.key,
            location: "[\(parentSection)]",
            preview: (preview.before, preview.after),
            apply: {
                try ConfigWriter.removeTOMLSectionKeys(
                    configPath: path,
                    section: parentSection,
                    keys: [parentKey]
                )
            }
        )
    }

    private func codexNetworkProxyKeyFixPlan(
        surface: CompatibilityMatrixEntry,
        path: String,
        key: String,
        location: String,
        preview: (before: String, after: String),
        apply _: @escaping () throws -> Void
    ) -> CompatibilityFixPlan {
        CompatibilityFixPlan(
            title: "Remove unknown Codex network proxy key",
            summary: "Delete the unsupported features.network_proxy key \(key) from \(location).",
            actionLabel: "Remove proxy key",
            icon: "network",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only the unknown features.network_proxy key \(key) from \(surface.label). If it is profile-scoped, only that profile's network proxy setting is edited.",
            willNotChange: "Documented network proxy keys, domain rules, Unix socket rules, other settings in the same profile, sibling profiles, project sections, MCP servers, auth files, skills, and managed policy files are not changed.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func codexNetworkProxyKeyTarget(
        from subjectPath: String
    ) -> (key: String, tableSection: String, parentSection: String?, parentSectionKey: String?, profileSection: String?)? {
        let topLevelPrefix = "features.network_proxy."
        if subjectPath.hasPrefix(topLevelPrefix) {
            let key = String(subjectPath.dropFirst(topLevelPrefix.count))
            guard isSimpleTOMLKey(key) else { return nil }
            return (key, "features.network_proxy", nil, nil, nil)
        }

        let profileMarker = ".features.network_proxy."
        guard let markerRange = subjectPath.range(of: profileMarker) else { return nil }
        let profileSection = String(subjectPath[..<markerRange.lowerBound])
        let key = String(subjectPath[markerRange.upperBound...])
        guard profileSection.hasPrefix("profiles."),
              isSimpleTOMLKey(key) else { return nil }

        return (
            key,
            "\(profileSection).features.network_proxy",
            "\(profileSection).features",
            "network_proxy.\(key)",
            profileSection
        )
    }

    private func codexNetworkProxyRuleTarget(
        from subjectPath: String
    ) -> (mapKey: String, key: String, tableSection: String, parentSection: String, profileSection: String?, profileFeaturesSection: String?)? {
        if let target = codexNetworkProxyRuleTarget(
            from: subjectPath,
            prefix: "features.network_proxy.",
            tableBase: "features.network_proxy",
            profileName: nil
        ) {
            return target
        }

        let marker = ".features.network_proxy."
        guard subjectPath.hasPrefix("profiles."),
              let markerRange = subjectPath.range(of: marker) else { return nil }
        let profileName = String(subjectPath[subjectPath.index(subjectPath.startIndex, offsetBy: "profiles.".count)..<markerRange.lowerBound])
        guard isSimpleTOMLKey(profileName) else { return nil }
        let suffix = String(subjectPath[markerRange.upperBound...])
        return codexNetworkProxyRuleTarget(
            from: suffix,
            prefix: "",
            tableBase: "profiles.\(profileName).features.network_proxy",
            profileName: profileName
        )
    }

    private func codexNetworkProxyRuleTarget(
        from subjectPath: String,
        prefix: String,
        tableBase: String,
        profileName: String?
    ) -> (mapKey: String, key: String, tableSection: String, parentSection: String, profileSection: String?, profileFeaturesSection: String?)? {
        for mapKey in ["domains", "unix_sockets"] {
            let marker = "\(prefix)\(mapKey)."
            guard subjectPath.hasPrefix(marker) else { continue }
            let key = String(subjectPath.dropFirst(marker.count))
            guard !key.isEmpty else { return nil }
            return (
                mapKey,
                key,
                "\(tableBase).\(mapKey)",
                tableBase,
                profileName.map { "profiles.\($0)" },
                profileName.map { "profiles.\($0).features" }
            )
        }
        return nil
    }

    private func invalidCodexWebSearchSettingPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configUnsupportedShape,
              [
                "Invalid Codex tools.web_search",
                "Invalid Codex web search context size",
                "Invalid Codex web search allowed domains"
              ].contains(issue.title),
              let subjectPath = issue.subjectPath,
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path
        else { return nil }

        if issue.title == "Invalid Codex tools.web_search" {
            return invalidCodexWholeWebSearchPlan(
                surface: surface,
                path: path,
                subjectPath: subjectPath
            )
        }

        guard let target = codexWebSearchKeyTarget(
            from: subjectPath,
            title: "Unknown Codex tools.web_search key"
        ) else { return nil }

        if let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: path,
            keys: [subjectPath]
        ) {
            return codexInvalidWebSearchValueFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "top-level \(subjectPath)",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTopLevelTOMLKeys(
                        configPath: path,
                        keys: [subjectPath]
                    )
                }
            )
        }

        if let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: target.tableSection,
            keys: [target.key]
        ) {
            return codexInvalidWebSearchValueFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "[\(target.tableSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTOMLSectionKeys(
                        configPath: path,
                        section: target.tableSection,
                        keys: [target.key]
                    )
                }
            )
        }

        if target.profileSection == nil,
           let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: nil,
            assignmentKey: "tools.web_search",
            keys: [target.key]
           ) {
            return codexInvalidWebSearchValueFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "inline tools.web_search table",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeInlineTOMLTableKeys(
                        configPath: path,
                        section: nil,
                        assignmentKey: "tools.web_search",
                        keys: [target.key]
                    )
                }
            )
        }

        if let parentSection = target.parentSection,
           let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: parentSection,
            assignmentKey: "web_search",
            keys: [target.key]
           ) {
            return codexInvalidWebSearchValueFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "inline web_search table in [\(parentSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeInlineTOMLTableKeys(
                        configPath: path,
                        section: parentSection,
                        assignmentKey: "web_search",
                        keys: [target.key]
                    )
                }
            )
        }

        if let profileSection = target.profileSection,
           let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: profileSection,
            assignmentKey: "tools.web_search",
            keys: [target.key]
           ) {
            return codexInvalidWebSearchValueFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "inline tools.web_search table in [\(profileSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeInlineTOMLTableKeys(
                        configPath: path,
                        section: profileSection,
                        assignmentKey: "tools.web_search",
                        keys: [target.key]
                    )
                }
            )
        }

        guard let parentSection = target.parentSection,
              let parentKey = target.parentSectionKey,
              let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
                configPath: path,
                section: parentSection,
                keys: [parentKey]
              )
        else { return nil }

        return codexInvalidWebSearchValueFixPlan(
            surface: surface,
            path: path,
            key: target.key,
            location: "[\(parentSection)]",
            preview: (preview.before, preview.after),
            apply: {
                try ConfigWriter.removeTOMLSectionKeys(
                    configPath: path,
                    section: parentSection,
                    keys: [parentKey]
                )
            }
        )
    }

    private func invalidCodexWholeWebSearchPlan(
        surface: CompatibilityMatrixEntry,
        path: String,
        subjectPath: String
    ) -> CompatibilityFixPlan? {
        if let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: path,
            keys: [subjectPath]
        ) {
            return codexInvalidWebSearchValueFixPlan(
                surface: surface,
                path: path,
                key: "tools.web_search",
                location: "top-level \(subjectPath)",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTopLevelTOMLKeys(
                        configPath: path,
                        keys: [subjectPath]
                    )
                }
            )
        }

        if subjectPath == "tools.web_search",
           let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: "tools",
            keys: ["web_search"]
           ) {
            return codexInvalidWebSearchValueFixPlan(
                surface: surface,
                path: path,
                key: "tools.web_search",
                location: "[tools]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTOMLSectionKeys(
                        configPath: path,
                        section: "tools",
                        keys: ["web_search"]
                    )
                }
            )
        }

        guard let markerRange = subjectPath.range(of: ".tools.web_search") else { return nil }
        let profileSection = String(subjectPath[..<markerRange.lowerBound])
        guard profileSection.hasPrefix("profiles.") else { return nil }

        if let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: profileSection,
            keys: ["tools.web_search"]
        ) {
            return codexInvalidWebSearchValueFixPlan(
                surface: surface,
                path: path,
                key: "tools.web_search",
                location: "[\(profileSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTOMLSectionKeys(
                        configPath: path,
                        section: profileSection,
                        keys: ["tools.web_search"]
                    )
                }
            )
        }

        let parentSection = "\(profileSection).tools"
        guard let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: parentSection,
            keys: ["web_search"]
        ) else { return nil }

        return codexInvalidWebSearchValueFixPlan(
            surface: surface,
            path: path,
            key: "tools.web_search",
            location: "[\(parentSection)]",
            preview: (preview.before, preview.after),
            apply: {
                try ConfigWriter.removeTOMLSectionKeys(
                    configPath: path,
                    section: parentSection,
                    keys: ["web_search"]
                )
            }
        )
    }

    private func codexInvalidWebSearchValueFixPlan(
        surface: CompatibilityMatrixEntry,
        path: String,
        key: String,
        location: String,
        preview: (before: String, after: String),
        apply _: @escaping () throws -> Void
    ) -> CompatibilityFixPlan {
        CompatibilityFixPlan(
            title: "Remove malformed Codex web search value",
            summary: "Delete the malformed tools.web_search value \(key) from \(location).",
            actionLabel: "Remove web value",
            icon: "magnifyingglass.circle.fill",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only the malformed tools.web_search value \(key) from \(surface.label). If it is profile-scoped, only that profile's web search setting is edited.",
            willNotChange: "Documented sibling web search settings, location values, other settings in the same profile, sibling profiles, project sections, MCP servers, auth files, skills, and managed policy files are not changed.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func invalidCodexNetworkProxySettingPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configUnsupportedShape,
              [
                "Invalid Codex features.network_proxy",
                "Invalid Codex network proxy boolean",
                "Invalid Codex network proxy mode",
                "Invalid Codex network proxy string"
              ].contains(issue.title),
              let subjectPath = issue.subjectPath,
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path
        else { return nil }

        if issue.title == "Invalid Codex features.network_proxy" {
            return invalidCodexWholeNetworkProxyPlan(
                surface: surface,
                path: path,
                subjectPath: subjectPath
            )
        }

        guard let target = codexNetworkProxyKeyTarget(from: subjectPath) else { return nil }

        if let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: path,
            keys: [subjectPath]
        ) {
            return codexInvalidNetworkProxyValueFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "top-level \(subjectPath)",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTopLevelTOMLKeys(
                        configPath: path,
                        keys: [subjectPath]
                    )
                }
            )
        }

        if let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: target.tableSection,
            keys: [target.key]
        ) {
            return codexInvalidNetworkProxyValueFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "[\(target.tableSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTOMLSectionKeys(
                        configPath: path,
                        section: target.tableSection,
                        keys: [target.key]
                    )
                }
            )
        }

        if target.profileSection == nil,
           let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: nil,
            assignmentKey: "features.network_proxy",
            keys: [target.key]
           ) {
            return codexInvalidNetworkProxyValueFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "inline features.network_proxy table",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeInlineTOMLTableKeys(
                        configPath: path,
                        section: nil,
                        assignmentKey: "features.network_proxy",
                        keys: [target.key]
                    )
                }
            )
        }

        if let parentSection = target.parentSection,
           let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: parentSection,
            assignmentKey: "network_proxy",
            keys: [target.key]
           ) {
            return codexInvalidNetworkProxyValueFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "inline network_proxy table in [\(parentSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeInlineTOMLTableKeys(
                        configPath: path,
                        section: parentSection,
                        assignmentKey: "network_proxy",
                        keys: [target.key]
                    )
                }
            )
        }

        if let profileSection = target.profileSection,
           let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: profileSection,
            assignmentKey: "features.network_proxy",
            keys: [target.key]
           ) {
            return codexInvalidNetworkProxyValueFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                location: "inline features.network_proxy table in [\(profileSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeInlineTOMLTableKeys(
                        configPath: path,
                        section: profileSection,
                        assignmentKey: "features.network_proxy",
                        keys: [target.key]
                    )
                }
            )
        }

        guard let parentSection = target.parentSection,
              let parentKey = target.parentSectionKey,
              let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
                configPath: path,
                section: parentSection,
                keys: [parentKey]
              )
        else { return nil }

        return codexInvalidNetworkProxyValueFixPlan(
            surface: surface,
            path: path,
            key: target.key,
            location: "[\(parentSection)]",
            preview: (preview.before, preview.after),
            apply: {
                try ConfigWriter.removeTOMLSectionKeys(
                    configPath: path,
                    section: parentSection,
                    keys: [parentKey]
                )
            }
        )
    }

    private func invalidCodexWholeNetworkProxyPlan(
        surface: CompatibilityMatrixEntry,
        path: String,
        subjectPath: String
    ) -> CompatibilityFixPlan? {
        if let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: path,
            keys: [subjectPath]
        ) {
            return codexInvalidNetworkProxyValueFixPlan(
                surface: surface,
                path: path,
                key: "features.network_proxy",
                location: "top-level \(subjectPath)",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTopLevelTOMLKeys(
                        configPath: path,
                        keys: [subjectPath]
                    )
                }
            )
        }

        if subjectPath == "features.network_proxy",
           let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: "features",
            keys: ["network_proxy"]
           ) {
            return codexInvalidNetworkProxyValueFixPlan(
                surface: surface,
                path: path,
                key: "features.network_proxy",
                location: "[features]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTOMLSectionKeys(
                        configPath: path,
                        section: "features",
                        keys: ["network_proxy"]
                    )
                }
            )
        }

        guard let markerRange = subjectPath.range(of: ".features.network_proxy") else { return nil }
        let profileSection = String(subjectPath[..<markerRange.lowerBound])
        guard profileSection.hasPrefix("profiles.") else { return nil }

        if let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: profileSection,
            keys: ["features.network_proxy"]
        ) {
            return codexInvalidNetworkProxyValueFixPlan(
                surface: surface,
                path: path,
                key: "features.network_proxy",
                location: "[\(profileSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTOMLSectionKeys(
                        configPath: path,
                        section: profileSection,
                        keys: ["features.network_proxy"]
                    )
                }
            )
        }

        let parentSection = "\(profileSection).features"
        guard let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: parentSection,
            keys: ["network_proxy"]
        ) else { return nil }

        return codexInvalidNetworkProxyValueFixPlan(
            surface: surface,
            path: path,
            key: "features.network_proxy",
            location: "[\(parentSection)]",
            preview: (preview.before, preview.after),
            apply: {
                try ConfigWriter.removeTOMLSectionKeys(
                    configPath: path,
                    section: parentSection,
                    keys: ["network_proxy"]
                )
            }
        )
    }

    private func codexInvalidNetworkProxyValueFixPlan(
        surface: CompatibilityMatrixEntry,
        path: String,
        key: String,
        location: String,
        preview: (before: String, after: String),
        apply _: @escaping () throws -> Void
    ) -> CompatibilityFixPlan {
        CompatibilityFixPlan(
            title: "Remove malformed Codex network proxy value",
            summary: "Delete the malformed features.network_proxy value \(key) from \(location).",
            actionLabel: "Remove proxy value",
            icon: "network",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only the malformed features.network_proxy value \(key) from \(surface.label). If it is profile-scoped, only that profile's network proxy setting is edited.",
            willNotChange: "Documented sibling network proxy settings, domain rules, Unix socket rules, other settings in the same profile, sibling profiles, project sections, MCP servers, auth files, skills, and managed policy files are not changed.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func invalidCodexNetworkProxyRulePlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configUnsupportedShape,
              [
                "Invalid Codex network proxy domain rule",
                "Invalid Codex network proxy Unix socket rule"
              ].contains(issue.title),
              let subjectPath = issue.subjectPath,
              let target = codexNetworkProxyRuleTarget(from: subjectPath),
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path
        else { return nil }

        if let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: path,
            keys: [subjectPath]
        ) {
            return codexNetworkProxyRuleFixPlan(
                surface: surface,
                path: path,
                ruleKey: target.key,
                mapKey: target.mapKey,
                location: "top-level \(subjectPath)",
                preview: (preview.before, preview.after)
            )
        }

        if let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: target.tableSection,
            keys: [target.key]
        ) {
            return codexNetworkProxyRuleFixPlan(
                surface: surface,
                path: path,
                ruleKey: target.key,
                mapKey: target.mapKey,
                location: "[\(target.tableSection)]",
                preview: (preview.before, preview.after)
            )
        }

        if let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: target.parentSection,
            keys: codexNestedRuleSectionKeys(mapKey: target.mapKey, key: target.key)
        ) {
            return codexNetworkProxyRuleFixPlan(
                surface: surface,
                path: path,
                ruleKey: target.key,
                mapKey: target.mapKey,
                location: "[\(target.parentSection)]",
                preview: (preview.before, preview.after)
            )
        }

        if let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: target.parentSection,
            assignmentKey: target.mapKey,
            keys: [target.key]
        ) {
            return codexNetworkProxyRuleFixPlan(
                surface: surface,
                path: path,
                ruleKey: target.key,
                mapKey: target.mapKey,
                location: "inline \(target.mapKey) table in [\(target.parentSection)]",
                preview: (preview.before, preview.after)
            )
        }

        if let preview = ConfigWriter.previewRemoveNestedInlineTOMLTableKeys(
            configPath: path,
            section: target.profileSection,
            assignmentKey: "features.network_proxy",
            tableKey: target.mapKey,
            keys: [target.key]
        ) {
            let location = target.profileSection.map { "inline features.network_proxy table in [\($0)]" }
                ?? "inline features.network_proxy table"
            return codexNetworkProxyRuleFixPlan(
                surface: surface,
                path: path,
                ruleKey: target.key,
                mapKey: target.mapKey,
                location: location,
                preview: (preview.before, preview.after)
            )
        }

        guard let profileFeaturesSection = target.profileFeaturesSection,
              let preview = ConfigWriter.previewRemoveNestedInlineTOMLTableKeys(
                configPath: path,
                section: profileFeaturesSection,
                assignmentKey: "network_proxy",
                tableKey: target.mapKey,
                keys: [target.key]
              )
        else { return nil }

        return codexNetworkProxyRuleFixPlan(
            surface: surface,
            path: path,
            ruleKey: target.key,
            mapKey: target.mapKey,
            location: "inline network_proxy table in [\(profileFeaturesSection)]",
            preview: (preview.before, preview.after)
        )
    }

    private func codexNetworkProxyRuleFixPlan(
        surface: CompatibilityMatrixEntry,
        path: String,
        ruleKey: String,
        mapKey: String,
        location: String,
        preview: (before: String, after: String)
    ) -> CompatibilityFixPlan {
        let label = mapKey == "domains" ? "domain" : "Unix socket"
        return CompatibilityFixPlan(
            title: "Remove invalid Codex network proxy rule",
            summary: "Delete the malformed features.network_proxy \(label) rule \(ruleKey) from \(location).",
            actionLabel: "Remove proxy rule",
            icon: "network",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only the invalid features.network_proxy \(mapKey) rule \(ruleKey) from \(surface.label). Valid sibling rules in the same map stay in place.",
            willNotChange: "Documented network proxy keys, valid domain/socket rules, profile siblings, project sections, MCP servers, auth files, skills, and managed policy files are not changed.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func unknownCodexPermissionNetworkKeyPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configUnsupportedShape,
              issue.title == "Unknown Codex permission network key",
              let subjectPath = issue.subjectPath,
              let target = codexPermissionNetworkKeyTarget(from: subjectPath),
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path
        else { return nil }

        if let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: path,
            keys: [subjectPath]
        ) {
            return codexPermissionNetworkKeyFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                permissionName: target.permissionName,
                location: "top-level \(subjectPath)",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTopLevelTOMLKeys(
                        configPath: path,
                        keys: [subjectPath]
                    )
                }
            )
        }

        if let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: target.tableSection,
            keys: [target.key]
        ) {
            return codexPermissionNetworkKeyFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                permissionName: target.permissionName,
                location: "[\(target.tableSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTOMLSectionKeys(
                        configPath: path,
                        section: target.tableSection,
                        keys: [target.key]
                    )
                }
            )
        }

        guard let parentSection = target.parentSection,
              let parentKey = target.parentSectionKey,
              let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
                configPath: path,
                section: parentSection,
                keys: [parentKey]
              )
        else { return nil }

        return codexPermissionNetworkKeyFixPlan(
            surface: surface,
            path: path,
            key: target.key,
            permissionName: target.permissionName,
            location: "[\(parentSection)]",
            preview: (preview.before, preview.after),
            apply: {
                try ConfigWriter.removeTOMLSectionKeys(
                    configPath: path,
                    section: parentSection,
                    keys: [parentKey]
                )
            }
        )
    }

    private func codexPermissionNetworkKeyFixPlan(
        surface: CompatibilityMatrixEntry,
        path: String,
        key: String,
        permissionName: String,
        location: String,
        preview: (before: String, after: String),
        apply _: @escaping () throws -> Void
    ) -> CompatibilityFixPlan {
        CompatibilityFixPlan(
            title: "Remove unknown Codex permission network key",
            summary: "Delete the unsupported permissions.\(permissionName).network key \(key) from \(location).",
            actionLabel: "Remove network key",
            icon: "network.badge.shield.half.filled",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only the unknown permissions.\(permissionName).network key \(key) from \(surface.label).",
            willNotChange: "Documented permission network keys, domain rules, Unix socket rules, other permission profiles, project sections, MCP servers, auth files, skills, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func invalidCodexPermissionNetworkSettingPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configUnsupportedShape,
              [
                "Invalid Codex permission network",
                "Invalid Codex permission network boolean",
                "Invalid Codex permission network mode",
                "Invalid Codex permission network string"
              ].contains(issue.title),
              let subjectPath = issue.subjectPath,
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path
        else { return nil }

        if issue.title == "Invalid Codex permission network" {
            return invalidCodexWholePermissionNetworkPlan(
                surface: surface,
                path: path,
                subjectPath: subjectPath
            )
        }

        guard let target = codexPermissionNetworkKeyTarget(from: subjectPath) else { return nil }

        if let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: path,
            keys: [subjectPath]
        ) {
            return codexInvalidPermissionNetworkValueFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                permissionName: target.permissionName,
                location: "top-level \(subjectPath)",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTopLevelTOMLKeys(
                        configPath: path,
                        keys: [subjectPath]
                    )
                }
            )
        }

        if let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: target.tableSection,
            keys: [target.key]
        ) {
            return codexInvalidPermissionNetworkValueFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                permissionName: target.permissionName,
                location: "[\(target.tableSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTOMLSectionKeys(
                        configPath: path,
                        section: target.tableSection,
                        keys: [target.key]
                    )
                }
            )
        }

        if let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: nil,
            assignmentKey: "permissions.\(target.permissionName).network",
            keys: [target.key]
        ) {
            return codexInvalidPermissionNetworkValueFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                permissionName: target.permissionName,
                location: "inline permissions.\(target.permissionName).network table",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeInlineTOMLTableKeys(
                        configPath: path,
                        section: nil,
                        assignmentKey: "permissions.\(target.permissionName).network",
                        keys: [target.key]
                    )
                }
            )
        }

        if let parentSection = target.parentSection,
           let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: parentSection,
            assignmentKey: "network",
            keys: [target.key]
           ) {
            return codexInvalidPermissionNetworkValueFixPlan(
                surface: surface,
                path: path,
                key: target.key,
                permissionName: target.permissionName,
                location: "inline network table in [\(parentSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeInlineTOMLTableKeys(
                        configPath: path,
                        section: parentSection,
                        assignmentKey: "network",
                        keys: [target.key]
                    )
                }
            )
        }

        guard let parentSection = target.parentSection,
              let parentKey = target.parentSectionKey,
              let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
                configPath: path,
                section: parentSection,
                keys: [parentKey]
              )
        else { return nil }

        return codexInvalidPermissionNetworkValueFixPlan(
            surface: surface,
            path: path,
            key: target.key,
            permissionName: target.permissionName,
            location: "[\(parentSection)]",
            preview: (preview.before, preview.after),
            apply: {
                try ConfigWriter.removeTOMLSectionKeys(
                    configPath: path,
                    section: parentSection,
                    keys: [parentKey]
                )
            }
        )
    }

    private func invalidCodexWholePermissionNetworkPlan(
        surface: CompatibilityMatrixEntry,
        path: String,
        subjectPath: String
    ) -> CompatibilityFixPlan? {
        guard let target = codexPermissionNetworkWholeTarget(from: subjectPath) else { return nil }

        if let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: path,
            keys: [subjectPath]
        ) {
            return codexInvalidPermissionNetworkValueFixPlan(
                surface: surface,
                path: path,
                key: "network",
                permissionName: target.permissionName,
                location: "top-level \(subjectPath)",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTopLevelTOMLKeys(
                        configPath: path,
                        keys: [subjectPath]
                    )
                }
            )
        }

        guard let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: target.parentSection,
            keys: ["network"]
        ) else { return nil }

        return codexInvalidPermissionNetworkValueFixPlan(
            surface: surface,
            path: path,
            key: "network",
            permissionName: target.permissionName,
            location: "[\(target.parentSection)]",
            preview: (preview.before, preview.after),
            apply: {
                try ConfigWriter.removeTOMLSectionKeys(
                    configPath: path,
                    section: target.parentSection,
                    keys: ["network"]
                )
            }
        )
    }

    private func codexInvalidPermissionNetworkValueFixPlan(
        surface: CompatibilityMatrixEntry,
        path: String,
        key: String,
        permissionName: String,
        location: String,
        preview: (before: String, after: String),
        apply _: @escaping () throws -> Void
    ) -> CompatibilityFixPlan {
        CompatibilityFixPlan(
            title: "Remove malformed Codex permission network value",
            summary: "Delete the malformed permissions.\(permissionName).network value \(key) from \(location).",
            actionLabel: "Remove network value",
            icon: "network",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only the malformed permissions.\(permissionName).network value \(key) from \(surface.label). This does not create a replacement network policy.",
            willNotChange: "Documented permission network keys, domain rules, Unix socket rules, other permission profiles, project sections, MCP servers, auth files, skills, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func invalidCodexPermissionNetworkRulePlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configUnsupportedShape,
              [
                "Invalid Codex permission network domain rule",
                "Invalid Codex permission network Unix socket rule"
              ].contains(issue.title),
              let subjectPath = issue.subjectPath,
              let target = codexPermissionNetworkRuleTarget(from: subjectPath),
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path
        else { return nil }

        if let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: path,
            keys: [subjectPath]
        ) {
            return codexPermissionNetworkRuleFixPlan(
                surface: surface,
                path: path,
                permissionName: target.permissionName,
                ruleKey: target.key,
                mapKey: target.mapKey,
                location: "top-level \(subjectPath)",
                preview: (preview.before, preview.after)
            )
        }

        if let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: target.tableSection,
            keys: [target.key]
        ) {
            return codexPermissionNetworkRuleFixPlan(
                surface: surface,
                path: path,
                permissionName: target.permissionName,
                ruleKey: target.key,
                mapKey: target.mapKey,
                location: "[\(target.tableSection)]",
                preview: (preview.before, preview.after)
            )
        }

        if let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: target.parentSection,
            keys: codexNestedRuleSectionKeys(mapKey: target.mapKey, key: target.key)
        ) {
            return codexPermissionNetworkRuleFixPlan(
                surface: surface,
                path: path,
                permissionName: target.permissionName,
                ruleKey: target.key,
                mapKey: target.mapKey,
                location: "[\(target.parentSection)]",
                preview: (preview.before, preview.after)
            )
        }

        if let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: target.parentSection,
            assignmentKey: target.mapKey,
            keys: [target.key]
        ) {
            return codexPermissionNetworkRuleFixPlan(
                surface: surface,
                path: path,
                permissionName: target.permissionName,
                ruleKey: target.key,
                mapKey: target.mapKey,
                location: "inline \(target.mapKey) table in [\(target.parentSection)]",
                preview: (preview.before, preview.after)
            )
        }

        if let preview = ConfigWriter.previewRemoveNestedInlineTOMLTableKeys(
            configPath: path,
            section: nil,
            assignmentKey: "permissions.\(target.permissionName).network",
            tableKey: target.mapKey,
            keys: [target.key]
        ) {
            return codexPermissionNetworkRuleFixPlan(
                surface: surface,
                path: path,
                permissionName: target.permissionName,
                ruleKey: target.key,
                mapKey: target.mapKey,
                location: "inline permissions.\(target.permissionName).network table",
                preview: (preview.before, preview.after)
            )
        }

        guard let preview = ConfigWriter.previewRemoveNestedInlineTOMLTableKeys(
            configPath: path,
            section: target.permissionSection,
            assignmentKey: "network",
            tableKey: target.mapKey,
            keys: [target.key]
        ) else { return nil }

        return codexPermissionNetworkRuleFixPlan(
            surface: surface,
            path: path,
            permissionName: target.permissionName,
            ruleKey: target.key,
            mapKey: target.mapKey,
            location: "inline network table in [\(target.permissionSection)]",
            preview: (preview.before, preview.after)
        )
    }

    private func codexPermissionNetworkRuleFixPlan(
        surface: CompatibilityMatrixEntry,
        path: String,
        permissionName: String,
        ruleKey: String,
        mapKey: String,
        location: String,
        preview: (before: String, after: String)
    ) -> CompatibilityFixPlan {
        let label = mapKey == "domains" ? "domain" : "Unix socket"
        return CompatibilityFixPlan(
            title: "Remove invalid Codex permission network rule",
            summary: "Delete the malformed permissions.\(permissionName).network \(label) rule \(ruleKey) from \(location).",
            actionLabel: "Remove network rule",
            icon: "network.badge.shield.half.filled",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only the invalid permissions.\(permissionName).network \(mapKey) rule \(ruleKey) from \(surface.label). Valid sibling rules in the same map stay in place.",
            willNotChange: "Documented permission network keys, valid domain/socket rules, other permission profiles, project sections, MCP servers, auth files, skills, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func codexPermissionNetworkWholeTarget(
        from subjectPath: String
    ) -> (permissionName: String, parentSection: String)? {
        let parts = subjectPath.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              parts[0] == "permissions",
              !parts[1].isEmpty,
              parts[2] == "network",
              isSimpleTOMLKey(parts[1]) else { return nil }
        return (parts[1], "permissions.\(parts[1])")
    }

    private func codexPermissionNetworkKeyTarget(
        from subjectPath: String
    ) -> (permissionName: String, key: String, tableSection: String, parentSection: String?, parentSectionKey: String?)? {
        let parts = subjectPath.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 4,
              parts[0] == "permissions",
              !parts[1].isEmpty,
              parts[2] == "network" else { return nil }
        let permissionName = parts[1]
        let key = parts.dropFirst(3).joined(separator: ".")
        guard isSimpleTOMLKey(permissionName),
              isSimpleTOMLKey(key) else { return nil }
        return (
            permissionName,
            key,
            "permissions.\(permissionName).network",
            "permissions.\(permissionName)",
            "network.\(key)"
        )
    }

    private func codexPermissionNetworkRuleTarget(
        from subjectPath: String
    ) -> (permissionName: String, mapKey: String, key: String, tableSection: String, parentSection: String, permissionSection: String)? {
        let basePrefix = "permissions."
        guard subjectPath.hasPrefix(basePrefix) else { return nil }
        let rest = String(subjectPath.dropFirst(basePrefix.count))
        guard let markerRange = rest.range(of: ".network.") else { return nil }
        let permissionName = String(rest[..<markerRange.lowerBound])
        guard !permissionName.isEmpty,
              isSimpleTOMLKey(permissionName) else { return nil }
        let suffix = String(rest[markerRange.upperBound...])

        for mapKey in ["domains", "unix_sockets"] {
            let marker = "\(mapKey)."
            guard suffix.hasPrefix(marker) else { continue }
            let key = String(suffix.dropFirst(marker.count))
            guard !key.isEmpty else { return nil }
            return (
                permissionName,
                mapKey,
                key,
                "permissions.\(permissionName).network.\(mapKey)",
                "permissions.\(permissionName).network",
                "permissions.\(permissionName)"
            )
        }
        return nil
    }

    private func codexNestedRuleSectionKeys(mapKey: String, key: String) -> [String] {
        var candidates = ["\(mapKey).\(key)"]
        if !key.hasPrefix("\""), !key.hasPrefix("'") {
            candidates.append("\(mapKey).\"\(key)\"")
        }
        return candidates
    }

    private func invalidCodexFilesystemGlobDepthPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configUnsupportedShape,
              issue.title == "Invalid Codex filesystem glob depth",
              let subjectPath = issue.subjectPath,
              let target = codexNamedFilesystemGlobDepthTarget(from: subjectPath),
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path
        else { return nil }

        if let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: path,
            keys: [subjectPath]
        ) {
            return codexFilesystemGlobDepthFixPlan(
                surface: surface,
                path: path,
                permissionName: target.permissionName,
                location: "top-level \(subjectPath)",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTopLevelTOMLKeys(
                        configPath: path,
                        keys: [subjectPath]
                    )
                }
            )
        }

        guard let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: target.section,
            keys: [target.key]
        ) else { return nil }

        return codexFilesystemGlobDepthFixPlan(
            surface: surface,
            path: path,
            permissionName: target.permissionName,
            location: "[\(target.section)]",
            preview: (preview.before, preview.after),
            apply: {
                try ConfigWriter.removeTOMLSectionKeys(
                    configPath: path,
                    section: target.section,
                    keys: [target.key]
                )
            }
        )
    }

    private func codexFilesystemGlobDepthFixPlan(
        surface: CompatibilityMatrixEntry,
        path: String,
        permissionName: String,
        location: String,
        preview: (before: String, after: String),
        apply _: @escaping () throws -> Void
    ) -> CompatibilityFixPlan {
        CompatibilityFixPlan(
            title: "Remove invalid Codex filesystem glob depth",
            summary: "Delete the malformed permissions.\(permissionName).filesystem.glob_scan_max_depth value from \(location).",
            actionLabel: "Remove glob depth",
            icon: "folder.badge.minus",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only the invalid glob_scan_max_depth setting from \(surface.label).",
            willNotChange: "Filesystem path rules, workspace-root rules, other permission profiles, project sections, MCP servers, auth files, skills, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func codexNamedFilesystemGlobDepthTarget(
        from subjectPath: String
    ) -> (permissionName: String, key: String, section: String)? {
        let parts = subjectPath.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4,
              parts[0] == "permissions",
              !parts[1].isEmpty,
              parts[2] == "filesystem",
              parts[3] == "glob_scan_max_depth",
              isSimpleTOMLKey(parts[1]) else { return nil }
        return (
            parts[1],
            "glob_scan_max_depth",
            "permissions.\(parts[1]).filesystem"
        )
    }

    private func invalidCodexWorkspaceRootEntryPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configUnsupportedShape,
              issue.title == "Invalid Codex workspace root entry",
              let subjectPath = issue.subjectPath,
              let target = codexWorkspaceRootEntryTarget(from: subjectPath),
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path
        else { return nil }

        if let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: path,
            keys: [subjectPath]
        ) {
            return codexWorkspaceRootEntryFixPlan(
                surface: surface,
                path: path,
                permissionName: target.permissionName,
                entryKey: target.entryKey,
                location: "top-level \(subjectPath)",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTopLevelTOMLKeys(
                        configPath: path,
                        keys: [subjectPath]
                    )
                }
            )
        }

        if let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: target.tableSection,
            keys: [target.tableKey]
        ) {
            return codexWorkspaceRootEntryFixPlan(
                surface: surface,
                path: path,
                permissionName: target.permissionName,
                entryKey: target.entryKey,
                location: "[\(target.tableSection)]",
                preview: (preview.before, preview.after),
                apply: {
                    try ConfigWriter.removeTOMLSectionKeys(
                        configPath: path,
                        section: target.tableSection,
                        keys: [target.tableKey]
                    )
                }
            )
        }

        guard let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: target.parentSection,
            keys: [target.parentKey]
        ) else { return nil }

        return codexWorkspaceRootEntryFixPlan(
            surface: surface,
            path: path,
            permissionName: target.permissionName,
            entryKey: target.entryKey,
            location: "[\(target.parentSection)]",
            preview: (preview.before, preview.after),
            apply: {
                try ConfigWriter.removeTOMLSectionKeys(
                    configPath: path,
                    section: target.parentSection,
                    keys: [target.parentKey]
                )
            }
        )
    }

    private func codexWorkspaceRootEntryFixPlan(
        surface: CompatibilityMatrixEntry,
        path: String,
        permissionName: String,
        entryKey: String,
        location: String,
        preview: (before: String, after: String),
        apply _: @escaping () throws -> Void
    ) -> CompatibilityFixPlan {
        CompatibilityFixPlan(
            title: "Remove invalid Codex workspace root",
            summary: "Delete the malformed permissions.\(permissionName).workspace_roots entry \(entryKey) from \(location).",
            actionLabel: "Remove workspace root",
            icon: "folder.badge.minus",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only the invalid workspace_roots entry \(entryKey) from \(surface.label).",
            willNotChange: "Valid workspace roots, permission profiles, filesystem path rules, project sections, MCP servers, auth files, skills, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func codexWorkspaceRootEntryTarget(
        from subjectPath: String
    ) -> (permissionName: String, entryKey: String, tableSection: String, tableKey: String, parentSection: String, parentKey: String)? {
        let prefix = "permissions."
        let marker = ".workspace_roots."
        guard subjectPath.hasPrefix(prefix),
              let markerRange = subjectPath.range(of: marker) else { return nil }
        let permissionName = String(subjectPath[prefix.endIndex..<markerRange.lowerBound])
        let entryKey = String(subjectPath[markerRange.upperBound...])
        guard isSimpleTOMLKey(permissionName),
              !entryKey.isEmpty,
              !entryKey.contains("["),
              !entryKey.contains("]") else { return nil }
        let tableKey = entryKey.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return (
            permissionName,
            entryKey,
            "permissions.\(permissionName).workspace_roots",
            tableKey,
            "permissions.\(permissionName)",
            "workspace_roots.\(entryKey)"
        )
    }

    private func invalidCodexFilesystemPermissionRulePlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configUnsupportedShape,
              issue.title == "Invalid Codex filesystem permission rule",
              let subjectPath = issue.subjectPath,
              let target = codexFilesystemPermissionRuleTarget(from: subjectPath),
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path
        else { return nil }

        if let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: path,
            keys: [subjectPath]
        ) {
            return codexFilesystemPermissionRuleFixPlan(
                surface: surface,
                path: path,
                permissionName: target.permissionName,
                ruleKey: target.ruleKey,
                location: "top-level \(subjectPath)",
                preview: (preview.before, preview.after)
            )
        }

        if let tableSection = target.tableSection,
           let tableKey = target.tableKey,
           let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: path,
            section: tableSection,
            keys: [tableKey]
           ) {
            return codexFilesystemPermissionRuleFixPlan(
                surface: surface,
                path: path,
                permissionName: target.permissionName,
                ruleKey: target.ruleKey,
                location: "[\(tableSection)]",
                preview: (preview.before, preview.after)
            )
        }

        if let parentSection = target.parentSection,
           let inlineKey = target.inlineKey,
           let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: parentSection,
            assignmentKey: "filesystem",
            keys: [inlineKey]
           ) {
            return codexFilesystemPermissionRuleFixPlan(
                surface: surface,
                path: path,
                permissionName: target.permissionName,
                ruleKey: target.ruleKey,
                location: "[\(parentSection)] filesystem",
                preview: (preview.before, preview.after)
            )
        }

        if let topLevelInlineAssignment = target.topLevelInlineAssignment,
           let inlineKey = target.inlineKey,
           let preview = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: path,
            section: nil,
            assignmentKey: topLevelInlineAssignment,
            keys: [inlineKey]
           ) {
            return codexFilesystemPermissionRuleFixPlan(
                surface: surface,
                path: path,
                permissionName: target.permissionName,
                ruleKey: target.ruleKey,
                location: "top-level \(topLevelInlineAssignment)",
                preview: (preview.before, preview.after)
            )
        }

        if let nestedTableKey = target.nestedInlineTableKey,
           let nestedEntryKey = target.nestedInlineEntryKey,
           let preview = ConfigWriter.previewRemoveNestedInlineTOMLTableKeys(
            configPath: path,
            section: "permissions.\(target.permissionName)",
            assignmentKey: "filesystem",
            tableKey: nestedTableKey,
            keys: [nestedEntryKey]
           ) {
            return codexFilesystemPermissionRuleFixPlan(
                surface: surface,
                path: path,
                permissionName: target.permissionName,
                ruleKey: target.ruleKey,
                location: "[permissions.\(target.permissionName)] filesystem.\(nestedTableKey)",
                preview: (preview.before, preview.after)
            )
        }

        if let nestedTableKey = target.nestedInlineTableKey,
           let nestedEntryKey = target.nestedInlineEntryKey,
           let preview = ConfigWriter.previewRemoveNestedInlineTOMLTableKeys(
            configPath: path,
            section: nil,
            assignmentKey: "permissions.\(target.permissionName).filesystem",
            tableKey: nestedTableKey,
            keys: [nestedEntryKey]
           ) {
            return codexFilesystemPermissionRuleFixPlan(
                surface: surface,
                path: path,
                permissionName: target.permissionName,
                ruleKey: target.ruleKey,
                location: "top-level permissions.\(target.permissionName).filesystem.\(nestedTableKey)",
                preview: (preview.before, preview.after)
            )
        }

        return nil
    }

    private func codexFilesystemPermissionRuleFixPlan(
        surface: CompatibilityMatrixEntry,
        path: String,
        permissionName: String,
        ruleKey: String,
        location: String,
        preview: (before: String, after: String)
    ) -> CompatibilityFixPlan {
        CompatibilityFixPlan(
            title: "Remove invalid Codex filesystem rule",
            summary: "Delete the malformed permissions.\(permissionName).filesystem rule \(ruleKey) from \(location).",
            actionLabel: "Remove rule",
            icon: "folder.badge.minus",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only the invalid filesystem rule \(ruleKey) from \(surface.label).",
            willNotChange: "Valid read/write/deny filesystem rules, workspace-root siblings, other permission profiles, project sections, MCP servers, auth files, skills, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func codexFilesystemPermissionRuleTarget(
        from subjectPath: String
    ) -> (
        permissionName: String,
        ruleKey: String,
        tableSection: String?,
        tableKey: String?,
        parentSection: String?,
        inlineKey: String?,
        topLevelInlineAssignment: String?,
        nestedInlineTableKey: String?,
        nestedInlineEntryKey: String?
    )? {
        let prefix = "permissions."
        let filesystemMarker = ".filesystem."
        guard subjectPath.hasPrefix(prefix),
              let filesystemRange = subjectPath.range(of: filesystemMarker) else { return nil }

        let permissionName = String(subjectPath[prefix.endIndex..<filesystemRange.lowerBound])
        let ruleKey = String(subjectPath[filesystemRange.upperBound...])
        guard isSimpleTOMLKey(permissionName),
              !ruleKey.isEmpty,
              ruleKey != "glob_scan_max_depth",
              !ruleKey.contains("["),
              !ruleKey.contains("]") else { return nil }

        let filesystemSection = "permissions.\(permissionName).filesystem"
        for marker in [#"":workspace_roots"."#, "':workspace_roots'.", ":workspace_roots."] {
            guard ruleKey.hasPrefix(marker) else { continue }
            let entryKey = String(ruleKey.dropFirst(marker.count))
            guard !entryKey.isEmpty,
                  !entryKey.contains("["),
                  !entryKey.contains("]") else { return nil }
            let tableMarker = String(marker.dropLast())
            let tableKey = entryKey.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return (
                permissionName,
                entryKey,
                "\(filesystemSection).\(tableMarker)",
                tableKey,
                nil,
                nil,
                nil,
                ":workspace_roots",
                tableKey
            )
        }

        let canAddressAsSimpleLeaf = !ruleKey.contains(".")
            && !ruleKey.contains("\"")
            && !ruleKey.contains("'")

        return (
            permissionName,
            ruleKey,
            canAddressAsSimpleLeaf ? filesystemSection : nil,
            canAddressAsSimpleLeaf ? ruleKey : nil,
            canAddressAsSimpleLeaf ? "permissions.\(permissionName)" : nil,
            canAddressAsSimpleLeaf ? ruleKey : nil,
            canAddressAsSimpleLeaf ? "\(filesystemSection)" : nil,
            nil,
            nil
        )
    }

    private func invalidCodexFallbackFilenamesPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        let key = "project_doc_fallback_filenames"
        guard issue.code == .configUnsupportedShape,
              issue.title.localizedCaseInsensitiveContains("fallback filenames"),
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path
        else { return nil }

        let repaired: [String]
        if let current = ConfigWriter.topLevelTOMLStringArraySetting(configPath: path, key: key) {
            repaired = uniqueCodexFallbackFilenames(current)
            guard repaired != current else { return nil }
        } else if let scalar = ConfigWriter.topLevelTOMLStringSetting(configPath: path, key: key),
                  isCodexFallbackFilename(scalar.trimmingCharacters(in: .whitespacesAndNewlines)) {
            repaired = [scalar.trimmingCharacters(in: .whitespacesAndNewlines)]
        } else {
            return nil
        }

        guard let preview = ConfigWriter.previewUpsertTopLevelTOMLStringArraySetting(
            configPath: path,
            key: key,
            values: repaired
        ) else { return nil }

        return CompatibilityFixPlan(
            title: "Clean Codex fallback filenames",
            summary: "Rewrite project_doc_fallback_filenames as a valid array of local filenames.",
            actionLabel: "Clean fallbacks",
            icon: "doc.badge.gearshape",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Change only the top-level project_doc_fallback_filenames value in \(surface.label).",
            willNotChange: "MCP servers, approvals, sandbox mode, profiles, project sections, auth files, skills, and instruction files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func uniqueCodexFallbackFilenames(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let filename = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isCodexFallbackFilename(filename),
                  !seen.contains(filename) else { continue }
            seen.insert(filename)
            result.append(filename)
        }
        return result
    }

    private func isCodexFallbackFilename(_ value: String) -> Bool {
        !value.isEmpty
            && !value.contains("/")
            && !value.contains("\\")
            && value != "."
            && value != ".."
    }

    private func invalidCodexProjectRootMarkersPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        let key = "project_root_markers"
        guard issue.code == .configUnsupportedShape,
              issue.title.localizedCaseInsensitiveContains("project root markers"),
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path
        else { return nil }

        let repaired: [String]
        if let current = ConfigWriter.topLevelTOMLStringArraySetting(configPath: path, key: key) {
            repaired = uniqueCodexProjectRootMarkers(current)
            guard repaired != current, !repaired.isEmpty else { return nil }
        } else if let scalar = ConfigWriter.topLevelTOMLStringSetting(configPath: path, key: key),
                  isCodexProjectRootMarker(scalar.trimmingCharacters(in: .whitespacesAndNewlines)) {
            repaired = [scalar.trimmingCharacters(in: .whitespacesAndNewlines)]
        } else {
            return nil
        }

        guard let preview = ConfigWriter.previewUpsertTopLevelTOMLStringArraySetting(
            configPath: path,
            key: key,
            values: repaired
        ) else { return nil }

        return CompatibilityFixPlan(
            title: "Clean Codex root markers",
            summary: "Rewrite project_root_markers as a valid array of safe relative marker paths.",
            actionLabel: "Clean markers",
            icon: "folder.badge.gearshape",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Change only the top-level project_root_markers value in \(surface.label).",
            willNotChange: "MCP servers, approvals, sandbox mode, profiles, project sections, auth files, skills, and instruction files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func uniqueCodexProjectRootMarkers(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let marker = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isCodexProjectRootMarker(marker),
                  !seen.contains(marker) else { continue }
            seen.insert(marker)
            result.append(marker)
        }
        return result
    }

    private func isCodexProjectRootMarker(_ value: String) -> Bool {
        !value.isEmpty
            && value != "."
            && value != ".."
            && !value.hasPrefix("/")
            && !value.contains("..")
            && !value.contains("\\")
    }

    private func codexProjectDocMaxBytesPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .contextTooLarge,
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .context,
              surface.scope == .project,
              let instructionPath = issue.path,
              let raw = try? String(contentsOfFile: instructionPath, encoding: .utf8)
        else { return nil }

        let byteCount = raw.utf8.count
        guard byteCount > 0 else { return nil }
        let targetBytes = max(32_768, roundUp(byteCount, toMultipleOf: 4_096))
        let codexHome = ProjectHubPaths.codexHome(home: NSHomeDirectory())
        let configPath = "\(codexHome)/config.toml"
        guard let preview = ConfigWriter.previewUpsertTopLevelTOMLIntSetting(
            configPath: configPath,
            key: "project_doc_max_bytes",
            value: targetBytes
        ) else { return nil }

        return CompatibilityFixPlan(
            title: "Raise Codex instruction limit",
            summary: "Set project_doc_max_bytes high enough for this project instruction file to load without crossing the current limit.",
            actionLabel: "Raise limit",
            icon: "text.badge.checkmark",
            path: configPath,
            before: preview.before,
            after: preview.after,
            willChange: "Set top-level project_doc_max_bytes to \(targetBytes) in the user-level Codex config.",
            willNotChange: "The project instruction file, MCP servers, auth files, skills, project config, and managed Codex policy files stay untouched.",
            requiresRestart: true,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: configPath,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func missingCodexInstructionFilePlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard isMissingCodexInstructionFileIssue(issue),
              let report,
              let key = issue.subjectPath,
              key == "model_instructions_file" || key == "experimental_instructions_file",
              let configPath = issue.metadata["codexInstructionFileConfigPath"],
              !configPath.isEmpty,
              let missingPath = issue.path,
              !FileManager.default.fileExists(atPath: missingPath),
              let surface = report.matrix.first(where: {
                  $0.path == configPath
                      && $0.kind == .settings
                      && $0.format == .toml
                      && $0.canWriteSafely
                      && $0.writeMethod == .file
                      && $0.toolID == issue.toolID
              }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              let currentValue = ConfigWriter.topLevelTOMLStringSetting(configPath: configPath, key: key),
              Self.resolvedCodexInstructionPath(configPath: configPath, configuredPath: currentValue) == missingPath,
              let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(configPath: configPath, keys: [key])
        else { return nil }

        let isDeprecated = key == "experimental_instructions_file"
        let title = isDeprecated
            ? "Remove stale deprecated Codex instruction override"
            : "Remove stale Codex instruction override"
        let summary = isDeprecated
            ? "Remove the missing experimental_instructions_file override so Codex can use the supported instruction search path."
            : "Remove the missing model_instructions_file override so Codex can fall back to AGENTS.md/default project guidance."

        return CompatibilityFixPlan(
            title: title,
            summary: summary,
            actionLabel: "Remove override",
            icon: "text.badge.xmark",
            path: configPath,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only the top-level \(key) value from \(surface.label).",
            willNotChange: "Instruction files, MCP servers, approvals, sandbox mode, profiles, project sections, auth files, skills, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                if FileManager.default.fileExists(atPath: missingPath) {
                    throw ConfigWriter.WriteError.writeFailure("Refusing to remove \(key) because the referenced file now exists: \(missingPath)")
                }
                guard let latestValue = ConfigWriter.topLevelTOMLStringSetting(configPath: configPath, key: key),
                      Self.resolvedCodexInstructionPath(configPath: configPath, configuredPath: latestValue) == missingPath else {
                    throw ConfigWriter.WriteError.writeFailure("Refusing to remove \(key) because the Codex instruction override changed after scan.")
                }
                try ConfigWriter.applyTOMLPreview(
                    configPath: configPath,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private static func resolvedCodexInstructionPath(configPath: String, configuredPath: String) -> String {
        let trimmed = configuredPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let expanded = (trimmed as NSString).expandingTildeInPath
        let resolved = expanded.hasPrefix("/")
            ? expanded
            : ((configPath as NSString).deletingLastPathComponent as NSString).appendingPathComponent(expanded)
        return URL(fileURLWithPath: resolved).standardizedFileURL.path
    }

    private func disabledCodexProjectDocMaxBytesPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .settingsSessionReloadRequired,
              issue.title == "Codex project instructions disabled",
              let report,
              let configPath = issue.metadata["codexProjectDocMaxBytesConfigPath"],
              !configPath.isEmpty,
              let surface = report.matrix.first(where: {
                  $0.path == configPath
                      && $0.kind == .settings
                      && $0.format == .toml
                      && $0.canWriteSafely
                      && $0.writeMethod == .file
                      && $0.toolID == issue.toolID
              }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              let instructionPath = issue.path,
              let raw = try? String(contentsOfFile: instructionPath, encoding: .utf8)
        else { return nil }

        let byteCount = raw.utf8.count
        let targetBytes = max(32_768, roundUp(byteCount, toMultipleOf: 4_096))
        guard let preview = ConfigWriter.previewUpsertTopLevelTOMLIntSetting(
            configPath: configPath,
            key: "project_doc_max_bytes",
            value: targetBytes
        ) else { return nil }

        return CompatibilityFixPlan(
            title: "Enable Codex project instructions",
            summary: "Raise project_doc_max_bytes in the config layer that currently disables project instruction files.",
            actionLabel: "Enable instructions",
            icon: "text.badge.checkmark",
            path: configPath,
            before: preview.before,
            after: preview.after,
            willChange: "Set top-level project_doc_max_bytes to \(targetBytes) in \(surface.label).",
            willNotChange: "The project instruction file, MCP servers, auth files, skills, other Codex settings, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: configPath,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func disabledCodexPluginMCPServerPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .serverDisabled,
              let report,
              let surfaceID = issue.surfaceID,
              surfaceID.hasPrefix("codex-plugin-mcp|"),
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              surface.toolID == .codexCLI || surface.toolID == .codexDesktop,
              let server = matchingServer(for: issue, in: report),
              let policyPath = issue.subjectPath,
              let pluginID = codexPluginID(fromMCPSurfaceID: surfaceID),
              let preview = ConfigWriter.previewSetCodexPluginMCPServerEnabled(
                configPath: policyPath,
                pluginID: pluginID,
                serverName: server.name,
                enabled: true,
                profileName: Self.codexPluginPolicyProfileName(from: issue)
              )
        else { return nil }

        return CompatibilityFixPlan(
            title: "Enable \(server.name)",
            summary: "Remove the disabled Codex plugin MCP policy for this server in the config layer that set it.",
            actionLabel: "Enable server",
            icon: "play.fill",
            path: policyPath,
            before: preview.before,
            after: preview.after,
            willChange: "Remove the effective enabled = false policy for \(server.name) from the Codex plugin MCP policy layer in \(shortPath(policyPath)).",
            willNotChange: "Plugin-owned MCP files, installed plugin files, credentials, and unrelated Codex settings stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyCodexPluginMCPServerEnabledPreview(
                    configPath: policyPath,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func shadowedCodexPluginMCPPolicyPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .projectSettingsShadowed,
              issue.title == "Codex plugin MCP policy shadowed",
              let report,
              let surfaceID = issue.surfaceID,
              surfaceID.hasPrefix("codex-plugin-mcp|"),
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              surface.toolID == .codexCLI || surface.toolID == .codexDesktop,
              let server = matchingServer(for: issue, in: report),
              let shadowedPath = issue.subjectPath,
              let pluginID = codexPluginID(fromMCPSurfaceID: surfaceID),
              let preview = ConfigWriter.previewSetCodexPluginMCPServerEnabled(
                configPath: shadowedPath,
                pluginID: pluginID,
                serverName: server.name,
                enabled: true,
                profileName: Self.codexPluginPolicyProfileName(from: issue)
              )
        else { return nil }

        return CompatibilityFixPlan(
            title: "Remove shadowed \(server.name) policy",
            summary: "Remove a lower-precedence Codex plugin MCP policy that no longer controls the effective server state.",
            actionLabel: "Remove shadowed policy",
            icon: "eraser.fill",
            path: shadowedPath,
            before: preview.before,
            after: preview.after,
            willChange: "Remove the shadowed enabled policy for \(server.name) from \(shortPath(shadowedPath)).",
            willNotChange: "The effective higher-precedence policy, plugin-owned MCP files, installed plugin files, credentials, and unrelated Codex settings stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyCodexPluginMCPServerEnabledPreview(
                    configPath: shadowedPath,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func invalidCodexPluginMCPPolicyKeyPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configUnsupportedShape,
              issue.title == "Unknown Codex plugin MCP policy key" || issue.title == "Invalid Codex plugin MCP policy value",
              issue.metadata["codexPluginMCPPolicyRepair"] == "remove-section-key",
              let section = issue.metadata["codexPluginMCPPolicySection"],
              let key = issue.metadata["codexPluginMCPPolicyKey"],
              !section.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.writeMethod == .file,
              surface.canWriteSafely,
              let path = issue.path ?? surface.path,
              let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
                configPath: path,
                section: section,
                keys: [key]
              )
        else { return nil }

        let expected = issue.metadata["codexPluginMCPPolicyExpected"] ?? "the documented Codex plugin MCP policy schema"
        return CompatibilityFixPlan(
            title: "Remove invalid plugin MCP policy",
            summary: "Remove one unsupported or malformed key from the Codex plugin MCP policy section.",
            actionLabel: "Remove policy key",
            icon: "eraser.fill",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove only \(section).\(key) from \(shortPath(path)). Codex expects \(expected).",
            willNotChange: "Plugin-owned MCP files, installed plugin files, credentials, and other Codex settings stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func disabledCodexSkillOverridePlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .skillDisabled,
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.writeMethod == .file,
              let path = surface.path,
              let subjectPath = issue.subjectPath,
              let skill = report.skills.first(where: { skill in
                  guard skill.enabledOverride == false else { return false }
                  let skillMD = (skill.path as NSString).appendingPathComponent("SKILL.md")
                  return Project.canonicalize(skillMD) == Project.canonicalize(subjectPath)
              })
        else { return nil }

        let skillMD = subjectPath
        guard let preview = ConfigWriter.previewSetCodexSkillOverrideEnabled(
            configPath: path,
            skillMDPath: skillMD,
            enabled: true
        ) else { return nil }

        return CompatibilityFixPlan(
            title: "Enable \(skill.name)",
            summary: "Set the matching Codex skill override to enabled so this installed skill can be used again.",
            actionLabel: "Enable skill",
            icon: "play.fill",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Change only the [[skills.config]] entry for \(CompatibilityScanner.tilde(skillMD)) to enabled = true.",
            willNotChange: "Skill files, MCP servers, auth files, and unrelated Codex settings stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func staleCodexSkillOverridePlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .skillMissingSkillMD,
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.writeMethod == .file,
              let path = surface.path,
              let preview = ConfigWriter.previewRemoveStaleCodexSkillOverrides(configPath: path)
        else { return nil }

        let count = preview.removed.count
        return CompatibilityFixPlan(
            title: "Remove stale Codex skill overrides",
            summary: "Remove \(count) [[skills.config]] \(count == 1 ? "entry" : "entries") that point to missing SKILL.md files.",
            actionLabel: "Remove stale overrides",
            icon: "trash.fill",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Delete only stale Codex skill override sections from this TOML config.",
            willNotChange: "Installed skills, MCP servers, auth files, and other Codex settings stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func claudeApprovalConflictPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .projectSettingsShadowed,
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              surface.toolID == .claudeCode,
              surface.kind == .settings,
              surface.writeMethod == .file,
              !surface.id.contains("managed"),
              let path = surface.path
        else { return nil }

        let conflicts = ConfigWriter.claudeMCPApprovalConflictNames(path: path)
        guard !conflicts.isEmpty,
              let preview = ConfigWriter.previewResolveClaudeMCPApprovalConflict(
                path: path,
                serverNames: conflicts
              )
        else { return nil }

        let names = conflicts.joined(separator: ", ")
        return CompatibilityFixPlan(
            title: "Resolve Claude approval conflict",
            summary: "Remove \(names) from disabledMcpjsonServers while leaving enabledMcpjsonServers intact.",
            actionLabel: "Resolve conflict",
            icon: "checkmark.shield.fill",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Clear the duplicate disabled approval entries for \(names).",
            willNotChange: "Project MCP definitions, installed packages, credentials, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func deprecatedCodexApprovalPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .settingsDeprecatedValue,
              issue.subjectPath != "experimental_instructions_file",
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path,
              let preview = ConfigWriter.previewReplaceTopLevelTOMLStringSetting(
                configPath: path,
                key: "approval_policy",
                from: "on-failure",
                to: "on-request"
              )
        else { return nil }

        return CompatibilityFixPlan(
            title: "Update Codex approval policy",
            summary: "Replace the deprecated top-level approval_policy value with on-request for interactive Codex runs.",
            actionLabel: "Use on-request",
            icon: "checkmark.shield.fill",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Change only the top-level approval_policy value from on-failure to on-request in \(surface.label).",
            willNotChange: "MCP servers, profiles, project sections, auth files, skills, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func deprecatedCodexInstructionFilePlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .settingsDeprecatedValue,
              issue.title == "Deprecated Codex experimental_instructions_file",
              issue.subjectPath == "experimental_instructions_file",
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path,
              let preview = ConfigWriter.previewMigrateDeprecatedCodexInstructionFile(configPath: path)
        else { return nil }

        let action = preview.migrated ? "Rename key" : "Remove duplicate"
        let title = preview.migrated ? "Rename Codex instruction override" : "Remove deprecated Codex instruction override"
        let summary = preview.migrated
            ? "Rename experimental_instructions_file to model_instructions_file using the same configured path."
            : "Remove experimental_instructions_file because model_instructions_file is already present."
        let willChange = preview.migrated
            ? "Rename only the top-level experimental_instructions_file key to model_instructions_file in \(surface.label)."
            : "Remove only the top-level experimental_instructions_file key from \(surface.label)."

        return CompatibilityFixPlan(
            title: title,
            summary: summary,
            actionLabel: action,
            icon: "text.badge.checkmark",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: willChange,
            willNotChange: "MCP servers, approvals, sandbox mode, profiles, project sections, auth files, skills, model instruction files, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func unknownCodexApprovalPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configUnsupportedShape,
              issue.title.localizedCaseInsensitiveContains("approval policy"),
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path,
              let currentValue = ConfigWriter.topLevelTOMLStringSetting(
                configPath: path,
                key: "approval_policy"
              ),
              !["untrusted", "on-request", "never"].contains(currentValue),
              let preview = ConfigWriter.previewReplaceTopLevelTOMLStringSetting(
                configPath: path,
                key: "approval_policy",
                from: currentValue,
                to: "on-request"
              )
        else { return nil }

        return CompatibilityFixPlan(
            title: "Reset Codex approval policy",
            summary: "Replace the unknown approval_policy value with Codex's standard on-request mode for interactive runs.",
            actionLabel: "Use on-request",
            icon: "checkmark.shield.fill",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Change only the top-level approval_policy value from \(currentValue) to on-request in \(surface.label).",
            willNotChange: "MCP servers, sandbox mode, profiles, project sections, auth files, skills, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func unknownCodexSandboxModePlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .configUnsupportedShape,
              issue.title.localizedCaseInsensitiveContains("sandbox mode"),
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path,
              let currentValue = ConfigWriter.topLevelTOMLStringSetting(
                configPath: path,
                key: "sandbox_mode"
              ),
              !["read-only", "workspace-write", "danger-full-access"].contains(currentValue),
              let preview = ConfigWriter.previewReplaceTopLevelTOMLStringSetting(
                configPath: path,
                key: "sandbox_mode",
                from: currentValue,
                to: "workspace-write"
              )
        else { return nil }

        return CompatibilityFixPlan(
            title: "Reset Codex sandbox mode",
            summary: "Replace the unknown sandbox_mode value with Codex's standard workspace-write mode.",
            actionLabel: "Use workspace-write",
            icon: "checkmark.shield.fill",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Change only the top-level sandbox_mode value from \(currentValue) to workspace-write in \(surface.label).",
            willNotChange: "MCP servers, approvals, profiles, project sections, auth files, skills, and managed policy files stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func claudeLocalSettingsGitignorePlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .projectLocalSettingsTracked,
              let settingsPath = issue.path
        else { return nil }

        let claudeDir = (settingsPath as NSString).deletingLastPathComponent
        let projectRoot = (claudeDir as NSString).deletingLastPathComponent
        let gitignorePath = (projectRoot as NSString).appendingPathComponent(".gitignore")
        let pattern = ".claude/settings.local.json"
        guard let preview = ConfigWriter.previewAppendGitignorePattern(
            gitignorePath: gitignorePath,
            pattern: pattern
        ) else { return nil }

        return CompatibilityFixPlan(
            title: "Ignore local Claude settings",
            summary: "Add Claude's user-private local settings file to this project's .gitignore.",
            actionLabel: "Add ignore rule",
            icon: "lock.doc.fill",
            path: gitignorePath,
            before: preview.before,
            after: preview.after,
            willChange: "Append \(pattern) to the project .gitignore.",
            willNotChange: "Claude settings, MCP servers, credentials, skills, and tracked project files stay untouched.",
            requiresRestart: false,
            apply: {
                try ConfigWriter.appendGitignorePattern(
                    gitignorePath: gitignorePath,
                    pattern: pattern
                )
            }
        )
    }

    private func codexProjectTrustPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .projectTrustRequired,
              let report,
              let projectRoot = report.projectRoot,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.scope == .project
        else { return nil }

        let codexHome = ProjectHubPaths.codexHome(home: NSHomeDirectory())
        let globalPath = "\(codexHome)/config.toml"
        guard let preview = ConfigWriter.previewSetCodexProjectTrust(
            globalConfigPath: globalPath,
            projectRoot: projectRoot,
            trusted: true
        ) else { return nil }

        return CompatibilityFixPlan(
            title: "Trust Codex project",
            summary: "Add a user-level Codex project trust entry so Codex can load this project's .codex/config.toml.",
            actionLabel: "Trust project",
            icon: "checkmark.shield.fill",
            path: globalPath,
            before: preview.before,
            after: preview.after,
            willChange: "Set trust_level = \"trusted\" for \(CompatibilityScanner.tilde(projectRoot)) in the user-level Codex config.",
            willNotChange: "Project files, MCP servers, skills, auth files, and managed Codex policy files stay untouched.",
            requiresRestart: true,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: globalPath,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func ignoredCodexProjectSettingsPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .projectSettingsIgnored,
              let report,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.scope == .project,
              surface.format == .toml,
              surface.canWriteSafely,
              surface.writeMethod == .file,
              let path = surface.path,
              let preview = ConfigWriter.previewRemoveIgnoredCodexProjectSettings(configPath: path)
        else { return nil }

        let count = preview.removed.count
        return CompatibilityFixPlan(
            title: "Remove ignored Codex project settings",
            summary: "Remove \(count) setting\(count == 1 ? "" : "s") that Codex ignores in project-local config.",
            actionLabel: "Clean project config",
            icon: "wand.and.stars.inverse",
            path: path,
            before: preview.before,
            after: preview.after,
            willChange: "Remove ignored project-local Codex keys/sections: \(preview.removed.joined(separator: ", ")).",
            willNotChange: "MCP server tables, valid project settings, global Codex config, auth files, and skills stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                try ConfigWriter.applyTOMLPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func codexProjectOverlapPlan(for issue: CompatibilityIssue) -> CompatibilityFixPlan? {
        guard issue.code == .projectSettingsShadowed,
              let report,
              let projectRoot = report.projectRoot,
              let surfaceID = issue.surfaceID,
              let surface = report.matrix.first(where: { $0.id == surfaceID }),
              (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
              surface.kind == .settings,
              surface.scope == .global,
              surface.format == .toml,
              surface.writeMethod == .file,
              let globalPath = surface.path
        else { return nil }

        let projectConfigPath = (projectRoot as NSString).appendingPathComponent(".codex/config.toml")
        let overlap = ConfigWriter.codexProjectSettingOverlap(
            globalConfigPath: globalPath,
            projectConfigPath: projectConfigPath,
            projectRoot: projectRoot
        )
        guard !overlap.isEmpty,
              let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
                configPath: projectConfigPath,
                keys: overlap
              )
        else { return nil }

        return CompatibilityFixPlan(
            title: "Use user-level Codex project override",
            summary: "Remove duplicated project settings from .codex/config.toml so the user-level [projects] entry is the only active source.",
            actionLabel: "Remove duplicates",
            icon: "arrow.triangle.2.circlepath.doc.on.clipboard",
            path: projectConfigPath,
            before: preview.before,
            after: preview.after,
            willChange: "Remove top-level duplicate keys from project config: \(preview.removed.joined(separator: ", ")).",
            willNotChange: "Global Codex config, MCP server tables, auth files, skills, and unrelated project settings stay untouched.",
            requiresRestart: surface.requiresRestartAfterWrite,
            apply: {
                let latestOverlap = ConfigWriter.codexProjectSettingOverlap(
                    globalConfigPath: globalPath,
                    projectConfigPath: projectConfigPath,
                    projectRoot: projectRoot
                )
                guard Set(latestOverlap) == Set(overlap) else {
                    throw ConfigWriter.WriteError.writeFailure("Refusing to remove Codex project keys because the overlap changed after preview.")
                }
                try ConfigWriter.applyTOMLPreview(
                    configPath: projectConfigPath,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
            }
        )
    }

    private func matchingServer(for issue: CompatibilityIssue, in report: CompatibilityScanResult) -> CompatibilityServerObservation? {
        guard let surfaceID = issue.surfaceID else { return nil }
        let candidates = report.servers.filter { $0.surfaceID == surfaceID }
        return candidates.first { issue.detail.contains("\"\($0.name)\"") }
            ?? candidates.first { issue.title.localizedCaseInsensitiveContains($0.name) }
    }

    private func codexPluginID(fromMCPSurfaceID surfaceID: String) -> String? {
        let prefix = "codex-plugin-mcp|"
        guard surfaceID.hasPrefix(prefix) else { return nil }
        let pieces = surfaceID.dropFirst(prefix.count)
            .split(separator: "|", maxSplits: 4, omittingEmptySubsequences: false)
        guard let plugin = pieces.first, !plugin.isEmpty else { return nil }
        return String(plugin)
    }

    static func codexPluginPolicyProfileName(from issue: CompatibilityIssue) -> String? {
        let value = issue.metadata["codexPluginPolicyProfileName"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    private func writerTarget(
        for surface: CompatibilityMatrixEntry,
        report: CompatibilityScanResult
    ) -> (toolID: String, scope: ConfigScope, projectRoot: String?, path: String)? {
        guard surface.kind == .mcp,
              surface.canWriteSafely,
              surface.writeMethod == .file
        else { return nil }

        let scope: ConfigScope = surface.scope == .project ? .project : .user
        let projectRoot = scope == .project ? report.projectRoot : nil
        if scope == .project && projectRoot == nil { return nil }

        let toolID: String
        switch surface.toolID {
        case .claudeDesktop:
            guard surface.id == "claude-desktop-json-mcp" else { return nil }
            toolID = "claude-desktop"
        case .claudeCode:
            guard surface.scope == .project else { return nil }
            toolID = "claude-code"
        case .codexCLI, .codexDesktop:
            toolID = "codex"
        }

        guard let path = ConfigWriter.previewPath(toolID: toolID, scope: scope, projectRoot: projectRoot) else { return nil }
        return (toolID, scope, projectRoot, path)
    }

    private func apply(_ plan: CompatibilityFixPlan) {
        applyingFix = true
        fixError = nil
        do {
            try plan.apply()
            let followUp = restartFollowUp(for: plan)
            applyingFix = false
            selectedIssue = nil
            refresh()
            if let followUp {
                postFixActions.append(followUp)
            }
        } catch {
            applyingFix = false
            fixError = error.localizedDescription
        }
    }

    private func restartFollowUp(for plan: CompatibilityFixPlan) -> CompatibilityManualAction? {
        guard plan.requiresRestart else { return nil }
        return CompatibilityManualAction(
            title: "Restart required",
            detail: "\(plan.title) changed \(shortPath(plan.path)).",
            hint: "Restart or reopen the affected Claude/Codex app or session, then run Scan. Run Verify only for MCP server fixes.",
            path: plan.path,
            state: .needsRestart,
            issue: nil
        )
    }

    private func verifyMCPServers() {
        guard !verifyingMCP, let report else { return }
        let targets = verifiableServers(report).compactMap { server -> (observation: CompatibilityServerObservation, entry: ServerEntry, toolID: String)? in
            guard let entry = CompatibilityScanner.healthEntry(for: server, matrix: report.matrix) else { return nil }
            return (server, entry, healthToolID(for: server.toolID))
        }
        guard !targets.isEmpty else { return }
        verifyingMCP = true
        liveReports = [:]

        Task {
            for target in targets {
                let health = await MCPHealthChecker.verify(
                    server: target.entry,
                    toolID: target.toolID,
                    configPath: target.observation.path,
                    context: verificationContext(for: target.observation.toolID)
                )
                await MainActor.run {
                    liveReports[target.observation.id] = health
                }
            }
            await MainActor.run {
                verifyingMCP = false
            }
        }
    }

    private func healthToolID(for toolID: CompatibilityToolID) -> String {
        switch toolID {
        case .claudeCode:
            return "claude-code"
        case .claudeDesktop:
            return "claude-desktop"
        case .codexCLI, .codexDesktop:
            return "codex"
        }
    }

    private func verificationContext(for toolID: CompatibilityToolID) -> MCPVerificationContext? {
        switch toolID {
        case .claudeDesktop:
            return desktopRuntimeContext(
                ownerName: "Claude Desktop",
                bundleIdentifiers: ["com.anthropic.claudefordesktop"],
                localizedNames: ["Claude"]
            )
        case .codexDesktop:
            return desktopRuntimeContext(
                ownerName: "Codex Desktop",
                bundleIdentifiers: ["com.openai.codex", "com.openai.chat"],
                localizedNames: ["Codex", "ChatGPT"]
            )
        case .claudeCode, .codexCLI:
            return nil
        }
    }

    private func desktopRuntimeContext(
        ownerName: String,
        bundleIdentifiers: [String],
        localizedNames: [String]
    ) -> MCPVerificationContext {
        let apps = NSWorkspace.shared.runningApplications
        let running = apps.first { app in
            if let bundleID = app.bundleIdentifier,
               bundleIdentifiers.contains(bundleID) {
                return true
            }
            guard let name = app.localizedName else { return false }
            return localizedNames.contains { name.localizedCaseInsensitiveCompare($0) == .orderedSame }
        }
        guard let running else {
            return .notRunning(ownerName: ownerName)
        }
        if let launchDate = running.launchDate {
            return .loadedAt(launchDate, ownerName: ownerName)
        }
        return .unknown(ownerName: ownerName)
    }

    private func filteredServers(_ report: CompatibilityScanResult) -> [CompatibilityServerObservation] {
        let servers = report.servers.filter { includes(toolID: $0.toolID, scope: $0.scope) }
        guard runtimeFilter == .all else {
            return servers
        }
        return CompatibilityScanner.deduplicatedSharedCodexServers(servers)
    }

    private func filteredSettings(_ report: CompatibilityScanResult) -> [CompatibilitySettingsObservation] {
        report.settings.filter { includes(toolID: $0.toolID, scope: $0.scope) }
    }

    private func filteredSkills(_ report: CompatibilityScanResult) -> [CompatibilitySkillObservation] {
        report.skills.filter { scopeFilter.includes(scope: $0.scope) && runtimeFilter.includes(skill: $0) }
    }

    private func filteredSkillSupport(_ report: CompatibilityScanResult) -> [CompatibilitySkillSupportObservation] {
        report.skillSupport.filter { scopeFilter.includes(scope: $0.scope) && runtimeFilter.includes(toolID: $0.toolID, scope: $0.scope) }
    }

    private func filteredMatrix(_ report: CompatibilityScanResult) -> [CompatibilityMatrixEntry] {
        report.matrix.filter { includes(toolID: $0.toolID, scope: $0.scope) }
    }

    private func filteredIssues(_ report: CompatibilityScanResult) -> [CompatibilityIssue] {
        let filtered = report.issues.filter { issue in
            guard !issueIsSupersededByLiveVerify(issue, report: report) else { return false }
            if let surfaceID = issue.surfaceID,
               let surface = report.matrix.first(where: { $0.id == surfaceID }) {
                return includes(toolID: surface.toolID, scope: surface.scope)
            }
            if let toolID = issue.toolID {
                return scopeFilter == .allSupported && runtimeFilter.includes(toolID: toolID, scope: nil)
            }
            return scopeFilter == .allSupported && runtimeFilter == .all
        }
        return deduplicateSharedCodexIssues(filtered, report: report)
    }

    private func includes(toolID: CompatibilityToolID, scope: CompatibilityScope?) -> Bool {
        scopeFilter.includes(scope: scope) && runtimeFilter.includes(toolID: toolID, scope: scope)
    }

    private func deduplicateSharedCodexIssues(
        _ issues: [CompatibilityIssue],
        report: CompatibilityScanResult
    ) -> [CompatibilityIssue] {
        guard runtimeFilter == .all else {
            return issues
        }

        var seen = Set<String>()
        var output: [CompatibilityIssue] = []
        for issue in issues {
            guard let surfaceID = issue.surfaceID,
                  let surface = report.matrix.first(where: { $0.id == surfaceID }),
                  (surface.toolID == .codexCLI || surface.toolID == .codexDesktop),
                  let path = issue.path else {
                output.append(issue)
                continue
            }
            let key = [
                issue.code.rawValue,
                normalizedIssuePath(path),
                issue.title,
                issue.subjectPath.map(normalizedIssuePath) ?? ""
            ].joined(separator: "|")
            if seen.insert(key).inserted {
                output.append(issue)
            }
        }
        return output
    }

    private func normalizedIssuePath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        return (expanded as NSString).standardizingPath
    }

    private func effectiveHealth(for server: CompatibilityServerObservation) -> CompatibilityHealthState {
        guard let live = liveReports[server.id] else { return server.health }
        return state(for: live.status)
    }

    private func issueIsSupersededByLiveVerify(_ issue: CompatibilityIssue, report: CompatibilityScanResult) -> Bool {
        guard issue.code == .serverHealthUnknown,
              issue.title.localizedCaseInsensitiveContains("handshake"),
              let server = matchingServer(for: issue, in: report),
              liveReports[server.id] != nil
        else { return false }
        return true
    }

    private func manualActions(_ report: CompatibilityScanResult) -> [CompatibilityManualAction] {
        var actions = postFixActions

        for issue in filteredIssues(report) {
            guard isManualActionIssue(issue) else { continue }
            guard fixPlan(for: issue) == nil else { continue }
            actions.append(CompatibilityManualAction(
                title: issue.title,
                detail: issue.detail,
                hint: issue.fixHint,
                path: issue.path,
                state: issue.state,
                issue: issue
            ))
        }

        let visibleServers = filteredServers(report)
        for server in visibleServers {
            guard let health = liveReports[server.id],
                  isManualActionHealth(health.status) else { continue }
            actions.append(CompatibilityManualAction(
                title: "\(server.name) live verification",
                detail: health.summary,
                hint: health.fixHint,
                path: server.path,
                state: state(for: health.status),
                issue: nil
            ))
        }

        var seen = Set<String>()
        return actions.filter { action in
            let key = "\(action.title)|\(action.detail)|\(action.path ?? "")|\(action.state.rawValue)"
            return seen.insert(key).inserted
        }
    }

    private func previewableFixes(_ report: CompatibilityScanResult) -> [CompatibilityPreviewableFix] {
        filteredIssues(report).compactMap { issue in
            guard let plan = fixPlan(for: issue) else { return nil }
            return CompatibilityPreviewableFix(issue: issue, plan: plan)
        }
    }

    private func isManualActionIssue(_ issue: CompatibilityIssue) -> Bool {
        if isMissingCodexInstructionFileIssue(issue) {
            return true
        }

        if issue.surfaceID == "codex-requirements" {
            return true
        }

        switch issue.code {
        case .serverAuthMissing, .serverAuthExpired, .serverOAuthNeeded,
             .serverEnvMissing, .serverNeedsRestart, .settingsSessionReloadRequired,
             .serverHealthUnknown, .serverAuthRuntimeManaged, .serverRuntimeManaged, .authCredentialStore,
             .settingsManagedRequirement, .settingsDeprecatedValue, .projectTrustRequired, .serverDisabled, .skillDisabled,
             .serverDuplicateName, .serverConflictDifferentConfig, .serverShadowedByProjectLayer,
             .skillDuplicateName,
             .skillVersionConflict, .projectSettingsShadowed, .contextDiverged:
            return true
        default:
            return false
        }
    }

    private func isMissingCodexInstructionFileIssue(_ issue: CompatibilityIssue) -> Bool {
        issue.code == .configMissing
            && issue.title == "Codex model instructions file missing"
            && (issue.subjectPath == "model_instructions_file" || issue.subjectPath == "experimental_instructions_file")
            && issue.metadata["codexInstructionFileConfigPath"]?.isEmpty == false
    }

    private func isManualActionHealth(_ status: MCPHealthStatus) -> Bool {
        switch status {
        case .broken, .needsAuth, .authExpired, .needsRestart, .unknown:
            return true
        case .working, .disabled:
            return false
        }
    }

    private func state(for status: MCPHealthStatus) -> CompatibilityHealthState {
        switch status {
        case .working:
            return .working
        case .broken:
            return .broken
        case .needsAuth:
            return .needsAuth
        case .authExpired:
            return .authExpired
        case .needsRestart:
            return .needsRestart
        case .disabled:
            return .disabled
        case .unknown:
            return .unknown
        }
    }

    private func roundUp(_ value: Int, toMultipleOf multiple: Int) -> Int {
        guard multiple > 0 else { return value }
        let remainder = value % multiple
        return remainder == 0 ? value : value + multiple - remainder
    }

    private func lineDiff(before: String, after: String) -> [CompatibilityDiffLine] {
        let beforeLines = before.components(separatedBy: "\n")
        let afterLines = after.components(separatedBy: "\n")
        let beforeSet = Set(beforeLines)
        let afterSet = Set(afterLines)
        var out: [CompatibilityDiffLine] = []
        for line in afterLines {
            out.append(.init(kind: beforeSet.contains(line) ? .same : .add, text: line))
        }
        for line in beforeLines where !afterSet.contains(line) {
            out.append(.init(kind: .remove, text: line))
        }
        if out.count > 160 {
            return Array(out.prefix(160)) + [.init(kind: .same, text: "... (truncated)")]
        }
        return out
    }

    private func labelBlock(_ title: String, _ text: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
            Text(text)
                .font(monospaced ? .system(size: 11, design: .monospaced) : .system(size: 12))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func refresh() {
        ensureSelectedProject()
        guard !scanning else { return }

        let requestID = UUID()
        let requestedRoot = scanRoot
        let requestedProfileName = codexRuntimeProfileName

        scanRequestID = requestID
        scanning = true

        Task.detached(priority: .userInitiated) {
            let profileNames = CompatibilityScanner.codexConfiguredProfileNames()
            let normalizedProfileName = profileNames.contains(requestedProfileName) ? requestedProfileName : ""
            let scanResult = CompatibilityScanner.scan(
                projectRoot: requestedRoot,
                codexProfileSelection: CodexProfileSelection.cliRuntimeOverride(normalizedProfileName)
            )

            await MainActor.run {
                guard scanRequestID == requestID else {
                    scanning = false
                    return
                }
                applyingScanResult = true
                codexProfileNames = profileNames
                codexRuntimeProfileName = normalizedProfileName
                report = scanResult
                liveReports = [:]
                scanning = false
                DispatchQueue.main.async {
                    applyingScanResult = false
                }
            }
        }
    }

    private func invalidateReport() {
        if scanning {
            scanRequestID = UUID()
        }
        report = nil
        liveReports = [:]
        postFixActions = []
        selectedIssue = nil
        copiedReport = false
    }

    private func reloadCodexProfileNames() {
        codexProfileNames = CompatibilityScanner.codexConfiguredProfileNames()
    }

    private func normalizeCodexRuntimeProfileSelection() {
        guard !codexRuntimeProfileName.isEmpty else { return }
        if !codexProfileNames.contains(codexRuntimeProfileName) {
            codexRuntimeProfileName = ""
        }
    }

    private func ensureSelectedProject() {
        guard fixedProject == nil else { return }
        if projectStore.projects.isEmpty {
            scanTarget = .global
            selectedProjectPath = nil
            return
        }
        if let selectedProjectPath,
           projectStore.projects.contains(where: { $0.path == selectedProjectPath }) {
            return
        }
        selectedProjectPath = projectStore.projects.first?.path
    }

    private func revealPath(_ path: String) {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            }
            return
        }

        let parent = URL(fileURLWithPath: path).deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: parent.path) {
            NSWorkspace.shared.open(parent)
        }
    }

    private func openClaudeDesktop() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.anthropic.claudefordesktop") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            return
        }

        let fallback = URL(fileURLWithPath: "/Applications/Claude.app")
        if FileManager.default.fileExists(atPath: fallback.path) {
            NSWorkspace.shared.openApplication(at: fallback, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private func openCodexDesktop() {
        for bundleID in ["com.openai.codex", "com.openai.chat"] {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                return
            }
        }

        for path in ["/Applications/Codex.app", "/Applications/ChatGPT.app"] {
            let fallback = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: fallback.path) {
                NSWorkspace.shared.openApplication(at: fallback, configuration: NSWorkspace.OpenConfiguration())
                return
            }
        }
    }

    private func copyManualChecklist(for issue: CompatibilityIssue) {
        let guidance = manualGuidance(for: issue)
        var lines = [
            "\(guidance.title) - \(issue.toolID?.label ?? "Project Hub")",
            issue.title,
            issue.detail
        ]
        if let path = issue.path {
            lines.append("Evidence: \(path)")
        }
        lines.append("")
        for (index, step) in guidance.steps.enumerated() {
            lines.append("\(index + 1). \(step)")
        }
        lines.append("")
        lines.append(guidance.safetyNote)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lines.joined(separator: "\n"), forType: .string)
    }

    private func copyCompatibilityReport() {
        guard let report else { return }
        let markdown = compatibilityReportMarkdown(report)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(markdown, forType: .string)
        copiedReport = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            copiedReport = false
        }
    }

    private func compatibilityReportMarkdown(_ report: CompatibilityScanResult) -> String {
        let generatedAt = Self.reportDateFormatter.string(from: report.generatedAt)
        let servers = filteredServers(report)
        let settings = filteredSettings(report)
        let skills = filteredSkills(report)
        let skillSupport = filteredSkillSupport(report)
        let issues = filteredIssues(report)
        let surfaces = filteredMatrix(report)
        let previewFixes = previewableFixes(report)
        let actions = manualActions(report)
        let live = servers
            .compactMap { liveReports[$0.id] }
            .sorted {
                if $0.toolID != $1.toolID { return $0.toolID < $1.toolID }
                return $0.serverName.localizedCaseInsensitiveCompare($1.serverName) == .orderedAscending
            }

        var lines: [String] = [
            "# Project Hub Compatibility Report",
            "",
            "- Generated: \(generatedAt)",
            "- Scan target: \(report.projectRoot == nil ? "Global tool state" : "Project + global tool state")",
            "- Target preset: \(targetPreset.label)",
            "- Codex CLI runtime profile: \(report.codexProfileSelection?.name ?? "Default config")",
            "- Scope lens: \(scopeFilter.label)",
            "- Runtime lens: \(runtimeFilter.label)",
            "- Project root: \(report.projectRoot.map(shortPath) ?? "Global tool state")",
            "- Surfaces: \(surfaces.count)",
            "- MCP servers: \(servers.count)",
            "- Settings/context files: \(settings.count)",
            "- Skills: \(skills.count)",
            "- Skill support rows: \(skillSupport.count)",
            "- Findings: \(issues.count)",
            ""
        ]

        lines.append("## MCP Server Health")
        lines.append("")
        lines.append("| State | Count |")
        lines.append("| --- | ---: |")
        for state in CompatibilityHealthState.allCasesForReport {
            let count = servers.filter { effectiveHealth(for: $0) == state }.count
            lines.append("| \(escapeMarkdown(stateLabel(state))) | \(count) |")
        }
        lines.append("")

        lines.append("## Findings by State")
        lines.append("")
        lines.append("| State | Count |")
        lines.append("| --- | ---: |")
        for state in CompatibilityHealthState.allCasesForReport where state != .working {
            let count = issues.filter { $0.state == state }.count
            lines.append("| \(escapeMarkdown(stateLabel(state))) | \(count) |")
        }
        lines.append("")

        if !live.isEmpty {
            lines.append("## Live Verify")
            lines.append("")
            lines.append("| Tool | Server | Status | Summary |")
            lines.append("| --- | --- | --- | --- |")
            for health in live {
                lines.append("| \(escapeMarkdown(health.toolID)) | \(escapeMarkdown(health.serverName)) | \(escapeMarkdown(health.status.rawValue)) | \(escapeMarkdown(health.summary)) |")
            }
            lines.append("")
        }

        lines.append("## Tool Coverage Matrix")
        lines.append("")
        lines.append("| Tool | Surfaces | MCP | Skills | Settings/Auth/Context | Writable | App/CLI/Runtime-owned | Read-only | Restart | Findings |")
        lines.append("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
        for tool in CompatibilityToolID.allCases {
            let toolSurfaces = surfaces.filter { $0.toolID == tool }
            let toolIssues = issues.filter { $0.toolID == tool }
            let configCount = toolSurfaces.filter { $0.kind == .settings || $0.kind == .auth || $0.kind == .context }.count
            let appOwnedCount = toolSurfaces.filter { $0.writeMethod == .cli || $0.writeMethod == .appUI || $0.writeMethod == .runtimeOnly }.count
            let readOnlyCount = toolSurfaces.filter { !$0.canWriteSafely && $0.writeMethod == .unsupported }.count
            lines.append([
                tool.label,
                "\(toolSurfaces.count)",
                "\(toolSurfaces.filter { $0.kind == .mcp }.count)",
                "\(toolSurfaces.filter { $0.kind == .skills }.count)",
                "\(configCount)",
                "\(toolSurfaces.filter { $0.canWriteSafely }.count)",
                "\(appOwnedCount)",
                "\(readOnlyCount)",
                "\(toolSurfaces.filter { $0.requiresRestartAfterWrite }.count)",
                "\(toolIssues.count)"
            ].map(escapeMarkdown).joined(separator: " | ").wrappedTableRow)
        }
        lines.append("")

        if !skillSupport.isEmpty {
            lines.append("## Skill Availability")
            lines.append("")
            lines.append("| Tool | State | Summary | Roots |")
            lines.append("| --- | --- | --- | --- |")
            for item in skillSupport {
                lines.append([
                    item.toolID.label,
                    item.state.rawValue,
                    item.summary,
                    item.roots.map(shortPath).joined(separator: ", ")
                ].map(escapeMarkdown).joined(separator: " | ").wrappedTableRow)
            }
            lines.append("")
        }

        if !skills.isEmpty {
            lines.append("## Skills")
            lines.append("")
            lines.append("| Tool | Skill | Scope | Invocation | MCP Dependencies | Claude Tools | Claude Runtime | Claude Policy | Path |")
            lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
            for skill in skills {
                lines.append([
                    skill.toolID.label,
                    skill.displayName ?? skill.name,
                    skill.scope.rawValue,
                    skillInvocationReportValue(skill),
                    skill.mcpDependencies.joined(separator: ", "),
                    joinedCompact(skill.claudeAllowedTools),
                    claudeRuntimeSummary(skill) ?? "",
                    claudePolicyReportValue(skill),
                    shortPath(skill.path)
                ].map(escapeMarkdown).joined(separator: " | ").wrappedTableRow)
            }
            lines.append("")
        }

        if !previewFixes.isEmpty {
            lines.append("## Previewable Fixes")
            lines.append("")
            lines.append("| State | Fix | Change | Path | After fix |")
            lines.append("| --- | --- | --- | --- | --- |")
            for fix in previewFixes.prefix(40) {
                lines.append([
                    stateLabel(fix.issue.state),
                    fix.plan.title,
                    fix.plan.willChange ?? fix.plan.summary,
                    shortPath(fix.plan.path),
                    fix.plan.requiresRestart ? "Restart required" : "Rescan/reload"
                ].map(escapeMarkdown).joined(separator: " | ").wrappedTableRow)
            }
            if previewFixes.count > 40 {
                lines.append("")
                lines.append("_\(previewFixes.count - 40) additional previewable fix\(previewFixes.count - 40 == 1 ? "" : "es") omitted from clipboard report._")
            }
            lines.append("")
        }

        if !actions.isEmpty {
            lines.append("## Manual Actions")
            lines.append("")
            lines.append("| State | Action | Detail | Path |")
            lines.append("| --- | --- | --- | --- |")
            for action in actions.prefix(40) {
                lines.append([
                    stateLabel(action.state),
                    action.title,
                    action.detail,
                    action.path.map(shortPath) ?? ""
                ].map(escapeMarkdown).joined(separator: " | ").wrappedTableRow)
            }
            if actions.count > 40 {
                lines.append("")
                lines.append("_\(actions.count - 40) additional manual action\(actions.count - 40 == 1 ? "" : "s") omitted from clipboard report._")
            }
            lines.append("")
        }

        lines.append("## Compatibility Matrix")
        lines.append("")
        lines.append("| Tool | Surface | Scope | Kind | Format | File-controlled | Safe write | Disable | OAuth/Auth | Env expansion | Restart | Precedence | Path | Notes |")
        lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | --- | --- |")
        for surface in surfaces {
            lines.append([
                surface.toolID.label,
                surface.label,
                surface.scope.rawValue,
                surface.kind.rawValue,
                surface.format.rawValue,
                surface.fileControlled ? "yes" : "no",
                writeLabel(surface),
                surface.supportsDisable ? "yes" : "no",
                surface.supportsOAuth ? "yes" : "no",
                surface.supportsEnvExpansion ? "yes" : "no",
                surface.requiresRestartAfterWrite ? "yes" : "no",
                "\(surface.precedence)",
                surface.path.map(shortPath) ?? "runtime/account",
                surface.note
            ].map(escapeMarkdown).joined(separator: " | ").wrappedTableRow)
        }
        lines.append("")

        if !issues.isEmpty {
            lines.append("## Findings")
            lines.append("")
            lines.append(Self.findingReportHeaderColumns.map(escapeMarkdown).joined(separator: " | ").wrappedTableRow)
            lines.append(Array(repeating: "---", count: Self.findingReportHeaderColumns.count).joined(separator: " | ").wrappedTableRow)
            for issue in issues.prefix(40) {
                let surface = issue.surfaceID.flatMap { surfaceID in
                    report.matrix.first { $0.id == surfaceID }
                }
                lines.append(Self.findingReportValues(
                    for: issue,
                    surface: surface,
                    evidencePath: evidencePath(for: issue),
                    shortPath: shortPath,
                    stateLabel: stateLabel
                ).map(escapeMarkdown).joined(separator: " | ").wrappedTableRow)
            }
            if issues.count > 40 {
                lines.append("")
                lines.append("_\(issues.count - 40) additional finding\(issues.count - 40 == 1 ? "" : "s") omitted from clipboard report._")
            }
            lines.append("")
        }

        if !servers.isEmpty {
            lines.append("## MCP Servers")
            lines.append("")
            lines.append("| Tool | Server | Scope | Transport | Health | Startup Timeout | Tool Timeout | Detail |")
            lines.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
            for server in servers.prefix(60) {
                let healthEntry = CompatibilityScanner.healthEntry(for: server, matrix: report.matrix)
                lines.append([
                    server.toolID.label,
                    server.name,
                    server.scope.rawValue,
                    server.transport,
                    stateLabel(effectiveHealth(for: server)),
                    timeoutReportValue(healthEntry?.startupTimeoutSeconds ?? server.startupTimeoutSeconds),
                    timeoutReportValue(healthEntry?.toolTimeoutSeconds ?? server.toolTimeoutSeconds),
                    server.detail
                ].map(escapeMarkdown).joined(separator: " | ").wrappedTableRow)
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func timeoutReportValue(_ timeout: TimeInterval?) -> String {
        guard let timeout else { return "" }
        if timeout.rounded() == timeout {
            return "\(Int(timeout))s"
        }
        return String(format: "%.2gs", timeout)
    }

    private static let reportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZ"
        return formatter
    }()

    private func escapeMarkdown(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "|", with: "\\|")
    }

    private func shortPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }

    private func evidencePath(for issue: CompatibilityIssue) -> String? {
        if let subjectPath = issue.subjectPath,
           subjectPath.hasPrefix("/") {
            return subjectPath
        }
        return issue.path
    }

    private func skillInvocationReportValue(_ skill: CompatibilitySkillObservation) -> String {
        var parts: [String] = []
        if skill.allowImplicitInvocation == false {
            parts.append("Codex explicit only")
        }
        if let claudeSummary = claudeInvocationSummary(skill) {
            parts.append("Claude \(claudeSummary)")
        }
        return parts.isEmpty ? "allowed" : parts.joined(separator: "; ")
    }

    private func claudePolicyReportValue(_ skill: CompatibilitySkillObservation) -> String {
        var parts: [String] = []
        if let override = skill.claudeOverrideState {
            parts.append("override \(override)")
        }
        if !skill.claudeSkillPermissionRules.isEmpty {
            parts.append("permissions \(joinedCompact(skill.claudeSkillPermissionRules, limit: 3))")
        }
        if skill.claudeShellExecutionDisabled {
            parts.append("shell disabled")
        }
        return parts.joined(separator: "; ")
    }

    private func stateLabel(_ state: CompatibilityHealthState) -> String {
        switch state {
        case .working: return "Working"
        case .broken: return "Broken"
        case .needsAuth: return "Needs auth"
        case .authExpired: return "Auth expired"
        case .needsRestart: return "Needs restart"
        case .disabled: return "Disabled"
        case .conflict: return "Conflict"
        case .unknown: return "Unknown"
        }
    }

    private func severityColor(_ severity: CompatibilityIssueSeverity) -> Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .error, .critical: return .red
        }
    }

    private func severityIcon(_ severity: CompatibilityIssueSeverity) -> String {
        switch severity {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error, .critical: return "xmark.octagon.fill"
        }
    }

    private func stateColor(_ state: CompatibilityHealthState) -> Color {
        switch state {
        case .working: return .green
        case .broken: return .red
        case .needsAuth, .authExpired: return .orange
        case .needsRestart: return .blue
        case .disabled: return .secondary
        case .conflict: return .yellow
        case .unknown: return .purple
        }
    }

    private func stateIcon(_ state: CompatibilityHealthState) -> String {
        switch state {
        case .working: return "checkmark.circle.fill"
        case .broken: return "xmark.octagon.fill"
        case .needsAuth: return "key.fill"
        case .authExpired: return "key.slash.fill"
        case .needsRestart: return "arrow.clockwise.circle.fill"
        case .disabled: return "pause.circle.fill"
        case .conflict: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    private func healthColor(_ status: MCPHealthStatus) -> Color {
        switch status {
        case .working: return .green
        case .broken: return .red
        case .needsAuth, .authExpired: return .orange
        case .needsRestart: return .blue
        case .disabled: return .secondary
        case .unknown: return .purple
        }
    }

    private func healthIcon(_ status: MCPHealthStatus) -> String {
        switch status {
        case .working: return "checkmark.circle.fill"
        case .broken: return "xmark.octagon.fill"
        case .needsAuth: return "key.fill"
        case .authExpired: return "key.slash.fill"
        case .needsRestart: return "arrow.clockwise.circle.fill"
        case .disabled: return "pause.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

private struct CompatibilityFixPlan {
    let title: String
    let summary: String
    let actionLabel: String
    let icon: String
    let path: String
    let before: String
    let after: String
    let willChange: String?
    let willNotChange: String?
    let requiresRestart: Bool
    let apply: () throws -> Void
}

private struct CompatibilityPreviewableFix: Identifiable {
    var id: UUID { issue.id }
    let issue: CompatibilityIssue
    let plan: CompatibilityFixPlan
}

private extension CompatibilityHealthState {
    static var allCasesForReport: [CompatibilityHealthState] {
        [.broken, .needsAuth, .authExpired, .needsRestart, .conflict, .disabled, .unknown, .working]
    }
}

private extension String {
    var wrappedTableRow: String { "| \(self) |" }
}

private struct CompatibilityManualAction: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let hint: String?
    let path: String?
    let state: CompatibilityHealthState
    let issue: CompatibilityIssue?
}

private struct CompatibilityManualGuidance {
    let title: String
    let icon: String
    let detail: String
    let steps: [String]
    let safetyNote: String
}

private enum CompatibilityTargetPreset: String, CaseIterable, Identifiable {
    case allSupported
    case project
    case global
    case cli
    case desktop
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .allSupported: return "All"
        case .project: return "Project"
        case .global: return "Global"
        case .cli: return "CLI"
        case .desktop: return "Desktop"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .allSupported: return "square.grid.2x2"
        case .project: return "folder"
        case .global: return "globe"
        case .cli: return "terminal"
        case .desktop: return "desktopcomputer"
        case .custom: return "slider.horizontal.3"
        }
    }

    static func visibleOptions(current: CompatibilityTargetPreset) -> [CompatibilityTargetPreset] {
        var options: [CompatibilityTargetPreset] = [.allSupported, .project, .global, .cli, .desktop]
        if current == .custom {
            options.append(.custom)
        }
        return options
    }
}

private enum CompatibilityScanTarget: String, CaseIterable, Identifiable {
    case global
    case project
    var id: String { rawValue }
}

enum CompatibilityScopeFilter: String, CaseIterable, Identifiable {
    case allSupported
    case project
    case global

    var id: String { rawValue }

    var label: String {
        switch self {
        case .allSupported: return "All supported"
        case .project: return "Project"
        case .global: return "Global"
        }
    }

    var icon: String {
        switch self {
        case .allSupported: return "square.grid.2x2"
        case .project: return "folder"
        case .global: return "globe"
        }
    }

    func includes(scope: CompatibilityScope?) -> Bool {
        switch self {
        case .allSupported:
            return true
        case .project:
            return scope == .project || scope == .localProjectUser
        case .global:
            return scope == .global
        }
    }
}

enum CompatibilityRuntimeFilter: String, CaseIterable, Identifiable {
    case all
    case cli
    case desktop

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .cli:
            return "CLI"
        case .desktop:
            return "Desktop"
        }
    }

    func includes(toolID: CompatibilityToolID, scope: CompatibilityScope?) -> Bool {
        switch self {
        case .all:
            return true
        case .cli:
            return toolID == .claudeCode || toolID == .codexCLI
        case .desktop:
            return toolID == .claudeDesktop || toolID == .codexDesktop || scope == .desktopApp
        }
    }

    func includes(skill: CompatibilitySkillObservation) -> Bool {
        switch self {
        case .all:
            return true
        case .cli:
            return skill.availableIn.contains(.claudeCode) || skill.availableIn.contains(.codexCLI)
        case .desktop:
            return skill.availableIn.contains(.claudeDesktop) || skill.availableIn.contains(.codexDesktop)
        }
    }
}

private struct CompatibilityDiffLine {
    enum Kind { case same, add, remove }

    let kind: Kind
    let text: String

    var symbol: String {
        switch kind {
        case .same: return " "
        case .add: return "+"
        case .remove: return "-"
        }
    }

    var color: Color {
        switch kind {
        case .same: return .secondary
        case .add: return .green
        case .remove: return .red
        }
    }
}
