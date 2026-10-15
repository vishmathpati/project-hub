import SwiftUI
import AppKit

struct ContextView: View {
    let project: Project
    let reloadTick: Int

    private enum Mode: String, CaseIterable {
        case session = "Session"
        case defaults = "Current defaults"
    }

    private enum ScopeFilter: String, CaseIterable {
        case all = "All scopes"
        case global = "Global"
        case project = "Project"
        case ancestor = "Ancestor"
        case unknown = "Unknown"

        func includes(_ scope: ContextSourceScope) -> Bool {
            self == .all || rawValue == scope.rawValue
        }
    }

    @State private var page: ContextPage?
    @State private var selectedSession: ContextSessionKey?
    @State private var mode: Mode = .session
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var preview: ContextChangePreview?
    @State private var receipt: ContextChangeReceipt?
    @State private var actionMessage: String?
    @State private var localReload = 0
    @State private var searchText = ""
    @State private var scopeFilter: ScopeFilter = .all
    @State private var scanLevel = 1

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            Group {
                if let page {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if let errorMessage {
                                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                                    .font(HubFont.caption)
                                    .foregroundStyle(HubTheme.bad)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(HubTheme.badBg)
                                    .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.control))
                            }
                            coverageBanner(page.coverage)
                            if mode == .session {
                                sessionContent(page)
                            } else {
                                defaultsContent(page.defaults)
                            }
                        }
                        .padding(HubTheme.contentPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if isLoading {
                    ProgressView("Reading local session records…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        "Context unavailable",
                        systemImage: "chart.bar.doc.horizontal",
                        description: Text(errorMessage ?? "No local session records were found for this project.")
                    )
                }
            }
        }
        .background(HubTheme.bg)
        .task(id: taskIdentity) { await load() }
    }

    private var taskIdentity: String {
        let selected = selectedSession.map { "\($0.provider.rawValue)|\($0.home)|\($0.id)" } ?? "latest"
        return "\(project.path)|\(reloadTick)|\(localReload)|\(selected)"
    }

    private var toolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                toolbarTitle
                Spacer()
                wideControls
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack { toolbarTitle; Spacer(); refreshButton }
                HStack(spacing: 8) {
                    Picker("View", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    TextField("Search items", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    Picker("Scope", selection: $scopeFilter) {
                        ForEach(ScopeFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 105)
                }
            }
        }
        .padding(.horizontal, HubTheme.contentPadding)
        .padding(.vertical, 9)
        .frame(minHeight: 58)
    }

    private var toolbarTitle: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Context")
                .font(.system(size: 15, weight: .bold))
            Text("Local evidence from Claude and Codex sessions")
                .font(HubFont.caption)
                .foregroundStyle(HubTheme.textDim)
        }
    }

    private var wideControls: some View {
        HStack(spacing: 12) {
            Picker("View", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 250)

            TextField("Search items", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)

            Picker("Scope", selection: $scopeFilter) {
                ForEach(ScopeFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
            .frame(width: 112)
            refreshButton
        }
    }

    private var refreshButton: some View {
        Button {
            localReload &+= 1
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.borderless)
        .help("Refresh context evidence")
    }

    @ViewBuilder
    private func coverageBanner(_ coverage: ContextCoverage) -> some View {
        if !coverage.issues.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("Partial coverage", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HubTheme.warn)
                ForEach(coverage.issues.prefix(4)) { issue in
                    Text("\(issue.kind.rawValue): \(issue.detail)")
                        .font(HubFont.caption)
                        .foregroundStyle(HubTheme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if coverage.issues.count > 4 {
                    Text("+ \(coverage.issues.count - 4) more coverage notes")
                        .font(HubFont.caption)
                        .foregroundStyle(HubTheme.textFaint)
                }
                if coverage.issues.contains(where: { $0.kind == .byteBudget || $0.kind == .recordBudget }) {
                    Button("Scan more") {
                        scanLevel &+= 1
                        localReload &+= 1
                    }
                    .help("Increase the selected-session byte and retained-record budgets, then scan again")
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HubTheme.warn.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.card))
        }
    }

    @ViewBuilder
    private func sessionContent(_ page: ContextPage) -> some View {
        if page.sessions.isEmpty {
            emptySessions
        } else {
            sessionPicker(page.sessions)
            if let report = page.selected {
                usageSummary(report)
                usageBar(report.usage.cumulative)
                capturedEstimateBars(report)
                contributions(report)
                evidenceFooter(report)
            }
        }
    }

    private var emptySessions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No matching sessions", systemImage: "clock.badge.questionmark")
                .font(.system(size: 14, weight: .semibold))
            Text("Project Hub only attributes a transcript after its recorded working directory matches this project. Start or resume Claude Code or Codex here, then refresh.")
                .font(HubFont.body)
                .foregroundStyle(HubTheme.textDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hubCard()
    }

    private func sessionPicker(_ sessions: [ContextSessionSummary]) -> some View {
        HStack(spacing: 10) {
            Text("Recent session")
                .font(.system(size: 12, weight: .semibold))
            Picker("Recent session", selection: $selectedSession) {
                ForEach(sessions) { session in
                    Text(sessionLabel(session)).tag(Optional(session.key))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 520)
            Spacer()
            if isLoading { ProgressView().controlSize(.small) }
        }
    }

    private func usageSummary(_ report: ContextSessionReport) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { usageMetricCards(report) }
            VStack(spacing: 12) { usageMetricCards(report) }
        }
    }

    @ViewBuilder
    private func usageMetricCards(_ report: ContextSessionReport) -> some View {
        metricCard(
            title: report.coverage.isComplete ? "Last request input" : "Last scanned input",
            value: report.usage.lastRequest.map { tokenText($0.inputTotal) } ?? "Unknown",
            detail: "Fresh + cache write + cache read"
        )
        metricCard(
            title: report.coverage.isComplete ? "Session traffic" : "Scanned session traffic",
            value: report.usage.cumulative.map { tokenText($0.total) } ?? "Unknown",
            detail: "Deduplicated provider counters"
        )
    }

    private func metricCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(HubFont.groupHeading)
                .foregroundStyle(HubTheme.textDim)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(HubTheme.text)
            Text(detail)
                .font(HubFont.caption)
                .foregroundStyle(HubTheme.textFaint)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hubCard()
    }

    @ViewBuilder
    private func usageBar(_ usage: ContextUsageSegments?) -> some View {
        if let usage, usage.total > 0 {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Measured session traffic")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("Provider reported")
                        .font(HubFont.caption)
                        .foregroundStyle(HubTheme.textDim)
                }
                GeometryReader { proxy in
                    HStack(spacing: 1) {
                        usageSegment(usage.freshInput, total: usage.total, width: proxy.size.width, color: HubTheme.accent)
                        usageSegment(usage.cacheWrite, total: usage.total, width: proxy.size.width, color: .orange)
                        usageSegment(usage.cacheRead, total: usage.total, width: proxy.size.width, color: .purple)
                        usageSegment(usage.output, total: usage.total, width: proxy.size.width, color: .green)
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 10)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { usageLegend(usage) }
                    VStack(alignment: .leading, spacing: 5) { usageLegend(usage) }
                }
            }
            .padding(14)
            .hubCard()
        }
    }

    private func usageSegment(_ value: Int64, total: Int64, width: CGFloat, color: Color) -> some View {
        color.frame(width: max(0, width * CGFloat(Double(value) / Double(total))))
    }

    private func legend(_ title: String, _ value: Int64, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(title) \(tokenText(value))")
                .font(HubFont.caption)
                .foregroundStyle(HubTheme.textDim)
        }
    }

    @ViewBuilder
    private func usageLegend(_ usage: ContextUsageSegments) -> some View {
        legend("Fresh", usage.freshInput, color: HubTheme.accent)
        legend("Cache write", usage.cacheWrite, color: .orange)
        legend("Cache read", usage.cacheRead, color: .purple)
        legend("Output", usage.output, color: .green)
    }

    private func contributions(_ report: ContextSessionReport) -> some View {
        let filtered = report.contributions.filter {
            scopeFilter.includes($0.scope) && matchesSearch(name: $0.name, path: $0.sourcePath)
        }
        let groups = Dictionary(grouping: filtered) { $0.owner ?? "" }
        let owners = groups.keys.sorted { lhs, rhs in
            if lhs.isEmpty { return true }
            if rhs.isEmpty { return false }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
        return VStack(alignment: .leading, spacing: 10) {
            HubSectionHeading("Latest captured items", count: filtered.count)
            Text("These are reconstructed from text captured in the selected session. They are estimates at the shown observation time, not a measured current context window.")
                .font(HubFont.caption)
                .foregroundStyle(HubTheme.textDim)
                .fixedSize(horizontal: false, vertical: true)

            if filtered.isEmpty {
                Text(report.contributions.isEmpty
                     ? "This session did not record supported prompt catalogs or instruction snapshots."
                     : "No captured items match the current search and scope filter.")
                    .font(HubFont.body)
                    .foregroundStyle(HubTheme.textFaint)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .hubCard()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(owners.enumerated()), id: \.element) { ownerIndex, owner in
                        if ownerIndex > 0 { Divider() }
                        if !owner.isEmpty {
                            Text("Plugin or server · \(owner)")
                                .font(HubFont.groupHeading)
                                .foregroundStyle(HubTheme.textDim)
                                .padding(.horizontal, 12)
                                .padding(.top, 10)
                        }
                        ForEach(groups[owner] ?? []) { contribution in
                            contributionRow(contribution)
                            if contribution.id != groups[owner]?.last?.id { Divider().padding(.leading, 12) }
                        }
                    }
                }
                .hubCard()
            }
        }
    }

    private func contributionRow(_ contribution: ContextContribution) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon(for: contribution.kind))
                .foregroundStyle(HubTheme.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(contribution.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HubTheme.text)
                Text("\(contribution.kind.rawValue) · \(contribution.scope.rawValue) · \(contribution.evidenceBasis.rawValue)")
                    .font(HubFont.caption)
                    .foregroundStyle(HubTheme.textDim)
                if let note = contribution.sourceNote {
                    Text(note).font(HubFont.caption).foregroundStyle(HubTheme.warn)
                }
                if let path = contribution.sourcePath {
                    HStack(spacing: 5) {
                        Text(path)
                            .font(HubFont.machine)
                            .foregroundStyle(HubTheme.textFaint)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Reveal") { reveal(path) }
                            .buttonStyle(.link)
                            .font(HubFont.caption)
                    }
                }
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 3) {
                Text(valueText(contribution.value))
                    .font(HubFont.machine)
                    .foregroundStyle(contribution.value.amount == nil ? HubTheme.textFaint : HubTheme.text)
                Text(contribution.value.qualityLabel)
                    .font(HubFont.caption)
                    .foregroundStyle(HubTheme.textFaint)
                Text(contribution.observedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(HubFont.caption)
                    .foregroundStyle(HubTheme.textFaint)
            }
        }
        .padding(12)
    }

    private func evidenceFooter(_ report: ContextSessionReport) -> some View {
        HStack(spacing: 8) {
            Image(systemName: report.coverage.isComplete ? "checkmark.circle" : "exclamationmark.triangle")
            Text("Observed \(report.observedAt.formatted(date: .abbreviated, time: .standard)) · read \(byteText(report.coverage.bytesRead)) of \(byteText(report.coverage.bytesDiscovered))")
            Spacer()
            Button("Reveal log") { reveal(report.session.sourcePath) }
                .buttonStyle(.link)
        }
        .font(HubFont.caption)
        .foregroundStyle(HubTheme.textDim)
    }

    private func defaultsContent(_ defaults: ContextCurrentDefaults) -> some View {
        let filtered = defaults.components.filter {
            scopeFilter.includes($0.scope) && matchesSearch(name: $0.name, path: $0.sourcePath)
        }
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Project reductions")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Changes apply only to this project's Claude settings and always show an exact preview first.")
                            .font(HubFont.caption)
                            .foregroundStyle(HubTheme.textDim)
                    }
                    Spacer()
                    Button("Enable MCP tool search") {
                        prepare(.enableClaudeToolSearch(projectPath: project.path))
                    }
                }
                Text("Requires a model and proxy that support tool search. Managed, HIPAA, and older-model environments may not support it; no savings are guaranteed.")
                    .font(HubFont.caption)
                    .foregroundStyle(HubTheme.textFaint)
            }
            .padding(14)
            .hubCard()

            Text("Available sources are a current inventory of candidates. Presence here does not prove a source was automatically loaded, and projections are not historical costs.")
                .font(HubFont.caption)
                .foregroundStyle(HubTheme.textDim)
                .fixedSize(horizontal: false, vertical: true)

            if let preview {
                changePreview(preview)
            } else if let receipt {
                undoCard(receipt)
            }

            if let actionMessage {
                Text(actionMessage)
                    .font(HubFont.caption)
                    .foregroundStyle(errorMessage == nil ? HubTheme.ok : HubTheme.bad)
            }

            HStack {
                HubSectionHeading("Available sources", count: filtered.count)
                Spacer()
                Text("Scanned \(defaults.observedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(HubFont.caption)
                    .foregroundStyle(HubTheme.textFaint)
            }

            LazyVStack(spacing: 0) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, component in
                    if index > 0 { Divider().padding(.leading, 12) }
                    defaultRow(component)
                }
            }
            .hubCard()
        }
    }

    private func defaultRow(_ component: ContextDefaultComponent) -> some View {
        HStack(spacing: 12) {
            Text(component.provider.rawValue)
                .font(HubFont.groupHeading)
                .foregroundStyle(HubTheme.accent)
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(component.name)
                    .font(.system(size: 12, weight: .semibold))
                Text("\(component.kind.rawValue) · \(component.scope.rawValue) · current candidate")
                    .font(HubFont.caption)
                    .foregroundStyle(HubTheme.textDim)
                Text(component.sourcePath)
                    .font(HubFont.machine)
                    .foregroundStyle(HubTheme.textFaint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 10)
            VStack(alignment: .trailing, spacing: 2) {
                Text(valueText(component.projection))
                    .font(HubFont.machine)
                    .foregroundStyle(component.projection.amount == nil ? HubTheme.textFaint : HubTheme.text)
                Text(component.projection.qualityLabel)
                    .font(HubFont.caption)
                    .foregroundStyle(HubTheme.textFaint)
                    .help(component.projection.qualityLabel)
            }
            if component.canMakeUserInvocableOnly {
                Button("On demand") {
                    prepare(.makeClaudeSkillUserInvocableOnly(
                        projectPath: project.path,
                        skillName: component.name,
                        skillSourcePath: component.sourcePath
                    ))
                }
                .help("Preview a project-only user-invocable-only override")
            }
            Button {
                reveal(component.sourcePath)
            } label: {
                Image(systemName: "arrow.forward.square")
            }
            .buttonStyle(.borderless)
            .help(component.kind == .mcpSchema ? "Manage MCP source" : "Reveal source")
        }
        .padding(12)
    }

    private func changePreview(_ preview: ContextChangePreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(preview.title)
                .font(.system(size: 13, weight: .semibold))
            Text(preview.explanation)
                .font(HubFont.caption)
                .foregroundStyle(HubTheme.textDim)
            Text(preview.targetPath)
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.textFaint)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(alignment: .top, spacing: 10) {
                previewText("Before", preview.before.isEmpty ? "(file did not exist)" : preview.before)
                previewText("After", preview.after)
            }
            Text("Applies to new Claude sessions in this project.")
                .font(HubFont.caption)
                .foregroundStyle(HubTheme.textDim)
            HStack {
                Spacer()
                Button("Cancel") { self.preview = nil }
                Button("Apply") { apply(preview) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .hubCard()
    }

    private func previewText(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased()).font(HubFont.groupHeading).foregroundStyle(HubTheme.textDim)
            ScrollView([.horizontal, .vertical]) {
                Text(text)
                    .font(HubFont.machine)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 150)
            .padding(8)
            .background(HubTheme.field)
            .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.control))
        }
        .frame(maxWidth: .infinity)
    }

    private func undoCard(_ receipt: ContextChangeReceipt) -> some View {
        HStack {
            Label("Applied \(receipt.preview.title)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(HubTheme.ok)
            Spacer()
            Button("Undo") { undo(receipt) }
        }
        .font(.system(size: 12, weight: .semibold))
        .padding(12)
        .hubCard()
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await ContextReader.read(
                projectPath: project.path,
                selected: selectedSession,
                budget: .init(
                    maximumBytes: Int64(scanLevel) * 128 * 1_024 * 1_024,
                    maximumRecordBytes: 4 * 1_024 * 1_024,
                    maximumSessions: 200,
                    maximumRelevantRecords: scanLevel * 50_000,
                    maximumRetainedBytes: Int64(scanLevel) * 32 * 1_024 * 1_024
                )
            )
            guard !Task.isCancelled else { return }
            page = loaded
            if selectedSession != loaded.selected?.session.key {
                selectedSession = loaded.selected?.session.key
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func prepare(_ action: ContextReductionAction) {
        do {
            preview = try ContextActions.preview(action)
            receipt = nil
            actionMessage = nil
            errorMessage = nil
        } catch {
            actionMessage = error.localizedDescription
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ preview: ContextChangePreview) {
        do {
            receipt = try ContextActions.apply(preview)
            self.preview = nil
            actionMessage = "Applied to this project. New Claude sessions will use the updated setting."
            errorMessage = nil
            localReload &+= 1
        } catch {
            actionMessage = error.localizedDescription
            errorMessage = error.localizedDescription
        }
    }

    private func undo(_ receipt: ContextChangeReceipt) {
        do {
            try ContextActions.undo(receipt)
            self.receipt = nil
            actionMessage = "Restored the exact pre-change state."
            errorMessage = nil
            localReload &+= 1
        } catch {
            actionMessage = error.localizedDescription
            errorMessage = error.localizedDescription
        }
    }

    private func sessionLabel(_ session: ContextSessionSummary) -> String {
        let date = session.fileModifiedAt.formatted(date: .abbreviated, time: .shortened)
        let role = session.isAgentSession ? " agent" : ""
        return "\(session.key.provider.rawValue)\(role) · \(date) · \(session.key.id.prefix(8))"
    }

    private func capturedEstimateBars(_ report: ContextSessionReport) -> some View {
        let measured = Dictionary(grouping: report.contributions) { $0.kind }.mapValues { rows in
            rows.compactMap(\.value.amount).reduce(Int64(0), +)
        }.filter { $0.value > 0 }
        let ranked = measured.sorted { $0.value > $1.value }
        let maximum = ranked.first?.value ?? 0
        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Approximate captured text by kind")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("Reconstructed · partial")
                    .font(HubFont.caption)
                    .foregroundStyle(HubTheme.textDim)
            }
            if ranked.isEmpty {
                Text("No captured text estimates are available for this session.")
                    .font(HubFont.caption)
                    .foregroundStyle(HubTheme.textFaint)
            } else {
                ForEach(ranked, id: \.key) { kind, amount in
                    HStack(spacing: 10) {
                        Text(kind.rawValue)
                            .font(HubFont.caption)
                            .foregroundStyle(HubTheme.textMid)
                            .frame(width: 92, alignment: .leading)
                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(HubTheme.accent.opacity(0.75))
                                .frame(width: maximum > 0 ? proxy.size.width * CGFloat(Double(amount) / Double(maximum)) : 0)
                        }
                        .frame(height: 8)
                        Text(tokenText(amount))
                            .font(HubFont.machine)
                            .foregroundStyle(HubTheme.text)
                            .frame(width: 92, alignment: .trailing)
                    }
                }
            }
            Text("Bars compare only captured reconstructed text. They do not represent total context or window utilization.")
                .font(HubFont.caption)
                .foregroundStyle(HubTheme.textFaint)
        }
        .padding(14)
        .hubCard()
    }

    private func matchesSearch(name: String, path: String?) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return name.localizedCaseInsensitiveContains(query)
            || (path?.localizedCaseInsensitiveContains(query) ?? false)
    }

    private func valueText(_ value: ContextTokenValue) -> String {
        switch value {
        case .measured(let amount): tokenText(amount)
        case .projected(let amount, _), .reconstructed(let amount, _): "~" + tokenText(amount)
        case .unknown: "Unknown"
        }
    }

    private func tokenText(_ value: Int64) -> String {
        value.formatted(.number.grouping(.automatic)) + " tokens"
    }

    private func byteText(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    private func icon(for kind: ContextContributionKind) -> String {
        switch kind {
        case .skill: "book.closed"
        case .agent: "person.crop.circle"
        case .mcpSchema: "server.rack"
        case .mcpInstructions: "text.quote"
        case .instruction: "doc.text"
        case .toolSchema: "wrench.and.screwdriver"
        }
    }

    private func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}
