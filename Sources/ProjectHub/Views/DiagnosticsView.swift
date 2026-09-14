import SwiftUI
import AppKit

// MARK: - Diagnostics (doctor)

struct DiagnosticsView: View {
    @EnvironmentObject var projectStore: ProjectStore

    @State private var report: DiagnosticsReport?
    @State private var scanning = false

    private static let ageFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var projectRoot: String? { projectStore.projects.first?.path }

    var body: some View {
        VStack(spacing: 0) {
            HubPageHeader(
                title: "Diagnostics",
                subtitle: scanCaption,
                actions: { headerActions }
            )
            if let report {
                ScrollView {
                    VStack(alignment: .leading, spacing: HubTheme.sectionGap) {
                        summary(report)
                        findings(report)
                        paths(report)
                        overrides(report)
                    }
                    .padding(HubTheme.contentPadding)
                }
            } else {
                emptyState
            }
        }
        .background(HubTheme.bg)
    }

    private var scanCaption: String {
        guard let report else {
            let target = projectRoot.map(shortPath) ?? "global tool state"
            return "Nothing scanned yet · \(target)"
        }
        let target = report.projectRoot.map(shortPath) ?? "global tool state"
        return "Scanned \(target) · \(age(report.generatedAt))"
    }

    @ViewBuilder
    private var headerActions: some View {
        HubButton(title: scanning ? "Scanning" : "Run scan", kind: .primary, action: runScan)
            .disabled(scanning)
            .keyboardShortcut("r", modifiers: .command)
    }

    // MARK: - Summary

    private func summary(_ report: DiagnosticsReport) -> some View {
        let present = report.probes.filter(\.exists).count
        let skipped = report.probes.filter(\.skipped).count
        let stale = report.findings.count

        var parts = ["\(report.probes.count) paths probed", "\(present) present"]
        if skipped > 0 { parts.append("\(skipped) skipped") }

        return HStack(spacing: 10) {
            StatusLabel(
                status: stale == 0 ? .ok : .bad,
                text: stale == 0 ? "No stale config" : "\(stale) stale finding\(stale == 1 ? "" : "s")"
            )
            Text(parts.joined(separator: " · "))
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.textDim)
                .lineLimit(1)
            Spacer(minLength: 12)
            Text(age(report.generatedAt))
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.textFaint)
        }
        .padding(.horizontal, HubTheme.cardPadding)
        .frame(minHeight: HubTheme.listRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hubCard()
    }

    // MARK: - Stale findings

    private func findings(_ report: DiagnosticsReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading("Stale config", count: report.findings.count)
            if report.findings.isEmpty {
                HStack(spacing: 8) {
                    StatusLabel(status: .ok, text: "Nothing points at a missing file")
                    Spacer(minLength: 8)
                    Text("every probe either exists or was skipped")
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textFaint)
                }
                .padding(.horizontal, HubTheme.contentPadding)
                .frame(height: HubTheme.tableRowHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .hubCard()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(report.findings.enumerated()), id: \.element.id) { index, finding in
                        if index > 0 { HubRowSeparator() }
                        findingRow(finding)
                    }
                }
                .hubCard()
            }
        }
    }

    private func findingRow(_ finding: DiagnosticsStaleFinding) -> some View {
        let tone = status(for: finding.severity)
        return HStack(alignment: .center, spacing: 10) {
            StatusDot(status: tone)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    if let toolID = finding.toolID {
                        ProviderTile(toolID: toolID, size: 14)
                    }
                    Text(finding.explanation)
                        .font(HubFont.sans(12.5, .medium))
                        .foregroundStyle(HubTheme.text)
                        .lineLimit(1)
                }
                Text(shortPath(finding.file))
                    .font(HubFont.machine)
                    .foregroundStyle(HubTheme.textDim)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            monoBadge(finding.kind.rawValue)
            Text(severityText(finding.severity))
                .font(HubFont.mono(10, .medium))
                .foregroundStyle(tone.color)
        }
        .padding(.horizontal, HubTheme.contentPadding)
        .frame(minHeight: HubTheme.listRowHeight)
        .contentShape(Rectangle())
    }

    // MARK: - Paths probed

    private func paths(_ report: DiagnosticsReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading("Paths probed", count: report.probes.count)
            LazyVStack(spacing: 0) {
                ForEach(Array(report.probes.enumerated()), id: \.element.id) { index, probe in
                    if index > 0 { HubRowSeparator() }
                    probeRow(probe)
                }
            }
            .hubCard()
        }
    }

    private func probeRow(_ probe: DiagnosticsPathProbe) -> some View {
        HStack(alignment: .center, spacing: 10) {
            StatusDot(status: probe.exists ? .ok : .neutral)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    if let toolID = probe.toolID {
                        ProviderTile(toolID: toolID, size: 14)
                    }
                    Text(probe.label)
                        .font(HubFont.sans(12.5, .medium))
                        .foregroundStyle(HubTheme.text)
                        .lineLimit(1)
                    monoBadge(probe.kind.rawValue)
                }
                Text(shortPath(probe.path))
                    .font(HubFont.machine)
                    .foregroundStyle(HubTheme.textDim)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let failure = probe.parseFailure {
                    Text(failure)
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.bad)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text(probeOutcome(probe))
                    .font(HubFont.machine)
                    .foregroundStyle(probe.exists ? HubTheme.textMid : HubTheme.textFaint)
                if let modified = probe.modifiedAt {
                    Text(age(modified))
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textFaint)
                }
            }
        }
        .padding(.horizontal, HubTheme.contentPadding)
        .frame(minHeight: HubTheme.listRowHeight)
        .opacity(probe.skipped ? 0.55 : 1)
        .contentShape(Rectangle())
    }

    private func probeOutcome(_ probe: DiagnosticsPathProbe) -> String {
        if probe.skipped { return "not scanned" }
        if !probe.exists { return probe.isSymlink ? "broken symlink" : "not found" }
        var parts: [String] = []
        if let count = probe.itemCount { parts.append(countText(count, kind: probe.kind)) }
        if let size = probe.byteSize {
            parts.append(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
        }
        return parts.isEmpty ? "present" : parts.joined(separator: " · ")
    }

    private func countText(_ count: Int, kind: DiagnosticsPathProbe.Kind) -> String {
        switch kind {
        case .skillRoot:       return "\(count) skill\(count == 1 ? "" : "s")"
        case .mcpConfig:       return "\(count) server\(count == 1 ? "" : "s")"
        case .agentRoot:       return "\(count) agent file\(count == 1 ? "" : "s")"
        case .instructionFile: return "readable"
        case .path:            return "\(count) item\(count == 1 ? "" : "s")"
        }
    }

    // MARK: - Environment overrides

    private func overrides(_ report: DiagnosticsReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading("Environment overrides", count: report.overrides.isEmpty ? nil : report.overrides.count)
            if report.overrides.isEmpty {
                HStack(spacing: 8) {
                    StatusLabel(status: .neutral, text: "No path overrides are set for this launch")
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, HubTheme.contentPadding)
                .frame(height: HubTheme.tableRowHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .hubCard()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(report.overrides.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { HubRowSeparator() }
                        overrideRow(entry)
                    }
                }
                .hubCard()
            }
        }
    }

    private func overrideRow(_ entry: DiagnosticsEnvironmentOverride) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(entry.name)
                .font(HubFont.mono(11))
                .foregroundStyle(HubTheme.accentText)
                .lineLimit(1)
            Text(entry.value)
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.textDim)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 12)
            Text(entry.affects)
                .font(HubFont.caption)
                .foregroundStyle(HubTheme.textMid)
                .lineLimit(1)
        }
        .padding(.horizontal, HubTheme.contentPadding)
        .frame(minHeight: HubTheme.listRowHeight)
        .contentShape(Rectangle())
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "stethoscope")
                .font(.system(size: 24))
                .foregroundStyle(HubTheme.textDim)
            Text("Run a diagnostics scan")
                .font(HubFont.sans(13, .semibold))
                .foregroundStyle(HubTheme.textStrong)
            Text("Probes every path Project Hub reads — provider homes, skill roots, MCP configs, agent folders — and lists config entries that point at files which no longer exist.")
                .font(HubFont.caption)
                .foregroundStyle(HubTheme.textDim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            HubButton(title: scanning ? "Scanning" : "Scan", kind: .primary, systemImage: "stethoscope", action: runScan)
                .disabled(scanning)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    // MARK: - Actions

    private func runScan() {
        guard !scanning else { return }
        scanning = true
        let root = projectRoot
        Task.detached(priority: .utility) {
            let result = await DiagnosticsReader.scan(projectRoot: root)
            await MainActor.run {
                report = result
                scanning = false
            }
        }
    }

    // MARK: - Helpers

    private func status(for severity: CompatibilityIssueSeverity) -> HubStatus {
        switch severity {
        case .critical, .error: return .bad
        case .warning:          return .warn
        case .info:             return .neutral
        }
    }

    private func severityText(_ severity: CompatibilityIssueSeverity) -> String {
        switch severity {
        case .critical: return "Critical"
        case .error:    return "Error"
        case .warning:  return "Warning"
        case .info:     return "Info"
        }
    }

    private func monoBadge(_ text: String) -> some View {
        Text(text)
            .font(HubFont.mono(9))
            .foregroundStyle(HubTheme.textFaint)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(HubTheme.stroke, lineWidth: 1)
            )
    }

    private func shortPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }

    private func age(_ date: Date) -> String {
        Self.ageFormatter.localizedString(for: date, relativeTo: Date())
    }
}
