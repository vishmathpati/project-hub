import SwiftUI

struct UsageInsightsView: View {
    @State private var sessions: [UsageReader.UsageSessionRow] = []
    @State private var burn: UsageReader.UsageBurnRate?
    @State private var loading = false
    @State private var preset: UsageRangePreset = .all
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    @State private var customEnd = Date()
    @State private var ascending = false
    @State private var exportError: String?

    private var range: UsageReader.UsageDateRange {
        preset.range(customStart: customStart, customEnd: customEnd)
    }

    private var columns: [HubTableColumn] {
        [
            HubTableColumn("Session"),
            HubTableColumn("In", width: 84, alignment: .trailing),
            HubTableColumn("Out", width: 84, alignment: .trailing),
            HubTableColumn("Cache-Create", width: 100, alignment: .trailing),
            HubTableColumn("Cache-Read", width: 100, alignment: .trailing),
            HubTableColumn("Total", width: 90, alignment: .trailing),
            HubTableColumn("$", width: 72, alignment: .trailing),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HubTheme.sectionGap) {
                VStack(alignment: .leading, spacing: 8) {
                    UsageFilterBar(
                        preset: $preset,
                        customStart: $customStart,
                        customEnd: $customEnd,
                        ascending: $ascending,
                        onExport: { export($0) }
                    )
                    if let exportError {
                        Text(exportError)
                            .font(HubFont.caption)
                            .foregroundStyle(HubTheme.bad)
                    }
                }
                activeBlockSection
                sessionSection
            }
            .padding(HubTheme.contentPadding)
        }
        .background(HubTheme.bg)
        .onAppear { load() }
        .onChange(of: preset) { _, _ in load() }
        .onChange(of: customStart) { _, _ in load() }
        .onChange(of: customEnd) { _, _ in load() }
        .onChange(of: ascending) { _, _ in load() }
        .onReceive(Timer.publish(every: 120, on: .main, in: .common).autoconnect()) { _ in
            load()
        }
    }

    // MARK: - Active block

    private var activeBlockSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading("Active block")
            if let burn {
                blockCard(burn)
            } else {
                Text("No active block")
                    .font(HubFont.body)
                    .foregroundStyle(HubTheme.textFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .hubCard()
            }
        }
    }

    private func blockCard(_ rate: UsageReader.UsageBurnRate) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("5-hour block")
                .font(HubFont.sans(13, .semibold))
                .foregroundStyle(HubTheme.textStrong)
            HStack(alignment: .top, spacing: 24) {
                stat("burn rate", rateText(rate.tokensPerMinute))
                stat("cost per hour", "\(money(rate.costPerHour))/hr")
                stat("elapsed", hoursMinutes(rate.elapsed))
                stat("remaining", hoursMinutes(rate.remaining))
                Spacer(minLength: 0)
            }
            Text("Projected block total \(tokens(rate.projectedTokens)) · \(money(rate.projectedCost)) at the current rate")
                .font(HubFont.caption)
                .foregroundStyle(HubTheme.textFaint)
        }
        .padding(HubTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hubCard()
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(HubFont.mono(9))
                .foregroundStyle(HubTheme.textFaint)
            Text(value)
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.text)
        }
    }

    // MARK: - Sessions

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading("Sessions", count: sessions.isEmpty ? nil : sessions.count)
            VStack(spacing: 0) {
                HubTableHeader(columns: columns)
                if loading && sessions.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if sessions.isEmpty {
                    Text("No sessions in local logs yet.")
                        .font(HubFont.body)
                        .foregroundStyle(HubTheme.textFaint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(sessions) { row in
                            sessionRow(row)
                            if row.id != sessions.last?.id { HubRowSeparator() }
                        }
                    }
                }
            }
            .hubCard()
            Text("Estimated at published API rates from local session logs. Not a bill.")
                .font(HubFont.caption)
                .foregroundStyle(HubTheme.textFaint)
        }
    }

    private func sessionRow(_ row: UsageReader.UsageSessionRow) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(row.label) · \(row.detail.prefix(8))")
                    .font(HubFont.rowPrimary)
                    .foregroundStyle(HubTheme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(caption(row))
                    .font(HubFont.machine)
                    .foregroundStyle(HubTheme.textFaint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(tokens(row.totals.input))
                .frame(width: 84, alignment: .trailing)
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.text)
            Text(tokens(row.totals.output))
                .frame(width: 84, alignment: .trailing)
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.text)
            Text(tokens(row.totals.cacheWrite))
                .frame(width: 100, alignment: .trailing)
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.textFaint)
            Text(tokens(row.totals.cacheRead))
                .frame(width: 100, alignment: .trailing)
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.textFaint)
            Text(tokens(row.totals.tokens))
                .frame(width: 90, alignment: .trailing)
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.text)
            Text(money(row.totals.cost))
                .frame(width: 72, alignment: .trailing)
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.textDim)
        }
        .padding(.horizontal, HubTheme.contentPadding)
        .frame(minHeight: HubTheme.tableRowHeight)
    }

    // MARK: - Formatting

    private func caption(_ row: UsageReader.UsageSessionRow) -> String {
        var parts: [String] = []
        if !row.models.isEmpty {
            parts.append(row.models.map(shortModel).joined(separator: ", "))
        }
        parts.append("\(moment(row.firstAt)) – \(moment(row.lastAt))")
        return parts.joined(separator: " · ")
    }

    private func rateText(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM tok/min", value / 1_000_000) }
        return "\(Int(value.rounded()).formatted()) tok/min"
    }

    private func money(_ value: Double) -> String {
        if value <= 0 { return "$0.00" }
        if value < 0.01 { return "<$0.01" }
        return value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }

    private func tokens(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM tok", Double(value) / 1_000_000) }
        if value >= 1_000 { return "\(value.formatted()) tok" }
        return "\(value) tok"
    }

    private func hoursMinutes(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours) h \(minutes) m" }
        return "\(minutes) min"
    }

    private func moment(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }

    private func shortModel(_ model: String) -> String {
        model.replacingOccurrences(of: "claude-", with: "")
    }

    private func load() {
        guard !loading else { return }
        if sessions.isEmpty { loading = true }
        let currentRange = range
        let order = ascending
        Task.detached(priority: .utility) {
            let rate = UsageReader.burnRate(in: currentRange)
            let rows = UsageReader.sessionBreakdown(in: currentRange, ascending: order)
            await MainActor.run {
                loading = false
                if currentRange == range, order == ascending {
                    burn = rate
                    sessions = rows
                } else {
                    load()
                }
            }
        }
    }

    private func export(_ format: UsageExporter.Format) {
        let snapshot = sessions
        let stamp = UsageExporter.dateStamp()
        UsageExporter.save(
            format: format,
            suggestedName: "usage-sessions-\(stamp).\(format.rawValue)",
            message: "\(snapshot.count) rows · \(range.label)",
            failure: $exportError
        ) {
            switch format {
            case .json:
                return try UsageReader.jsonData(snapshot)
            case .csv:
                return UsageReader.csvData(
                    header: ["Session", "Models", "First", "Last", "In", "Out", "Cache-Create", "Cache-Read", "Total", "$"],
                    rows: Self.csvRows(snapshot)
                )
            }
        }
    }

    private static func csvRows(_ rows: [UsageReader.UsageSessionRow]) -> [[String]] {
        rows.map { row in
            [
                "\(row.label) · \(row.detail)",
                row.models.joined(separator: " "),
                row.firstAt.formatted(.iso8601),
                row.lastAt.formatted(.iso8601),
                "\(row.totals.input)",
                "\(row.totals.output)",
                "\(row.totals.cacheWrite)",
                "\(row.totals.cacheRead)",
                "\(row.totals.tokens)",
                String(format: "%.6f", row.totals.cost),
            ]
        }
    }
}
