import SwiftUI

struct UsageBreakdownView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case daily, weekly, monthly, model, project

        var id: String { rawValue }

        var title: String {
            switch self {
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            case .model: return "By model"
            case .project: return "By project"
            }
        }

        var columnTitle: String {
            switch self {
            case .daily: return "Day"
            case .weekly: return "Week"
            case .monthly: return "Month"
            case .model: return "Model"
            case .project: return "Project"
            }
        }
    }

    @State private var mode: Mode = .daily
    @State private var rows: [UsageReader.UsageBreakdownRow] = []
    @State private var loading = false

    private var columns: [HubTableColumn] {
        [
            HubTableColumn(mode.columnTitle),
            HubTableColumn("In", width: 84, alignment: .trailing),
            HubTableColumn("Out", width: 84, alignment: .trailing),
            HubTableColumn("Cache-Create", width: 100, alignment: .trailing),
            HubTableColumn("Cache-Read", width: 100, alignment: .trailing),
            HubTableColumn("Total", width: 90, alignment: .trailing),
            HubTableColumn("$", width: 72, alignment: .trailing),
        ]
    }

    private var totals: UsageTotals {
        rows.reduce(into: UsageTotals()) { $0.add($1.totals) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading("Breakdown", count: rows.isEmpty ? nil : rows.count)
            Picker("Breakdown", selection: $mode) {
                ForEach(Mode.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            VStack(spacing: 0) {
                HubTableHeader(columns: columns)
                if loading && rows.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if rows.isEmpty {
                    Text("No usage in local logs yet.")
                        .font(HubFont.body)
                        .foregroundStyle(HubTheme.textFaint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            breakdownRow(label: row.label, sub: sub(row), totals: row.totals)
                            if row.id != rows.last?.id { HubRowSeparator() }
                        }
                    }
                    HubRowSeparator()
                    breakdownRow(label: "Total", sub: nil, totals: totals, strong: true)
                }
            }
            .hubCard()
            Text("Estimated at published API rates from local session logs. Not a bill.")
                .font(HubFont.caption)
                .foregroundStyle(HubTheme.textFaint)
        }
        .onAppear { load() }
        .onChange(of: mode) { _, _ in load() }
    }

    private func sub(_ row: UsageReader.UsageBreakdownRow) -> String? {
        if mode == .model || mode == .project {
            let share = "\(Int((row.share * 100).rounded()))% of tokens"
            if let detail = row.detail { return "\(share) · \(detail)" }
            return share
        }
        return row.detail
    }

    private func breakdownRow(label: String, sub: String?, totals: UsageTotals, strong: Bool = false) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(HubFont.rowPrimary)
                    .foregroundStyle(strong ? HubTheme.textStrong : HubTheme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let sub {
                    Text(sub)
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textFaint)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(tokens(totals.input))
                .frame(width: 84, alignment: .trailing)
                .font(HubFont.machine)
                .foregroundStyle(strong ? HubTheme.textStrong : HubTheme.text)
            Text(tokens(totals.output))
                .frame(width: 84, alignment: .trailing)
                .font(HubFont.machine)
                .foregroundStyle(strong ? HubTheme.textStrong : HubTheme.text)
            Text(tokens(totals.cacheWrite))
                .frame(width: 100, alignment: .trailing)
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.textFaint)
            Text(tokens(totals.cacheRead))
                .frame(width: 100, alignment: .trailing)
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.textFaint)
            Text(tokens(totals.tokens))
                .frame(width: 90, alignment: .trailing)
                .font(HubFont.machine)
                .foregroundStyle(strong ? HubTheme.textStrong : HubTheme.text)
            Text(money(totals.cost))
                .frame(width: 72, alignment: .trailing)
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.textDim)
        }
        .padding(.horizontal, HubTheme.contentPadding)
        .frame(minHeight: HubTheme.tableRowHeight)
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

    private func load() {
        guard !loading else { return }
        if rows.isEmpty { loading = true }
        let current = mode
        Task.detached(priority: .utility) {
            let result: [UsageReader.UsageBreakdownRow]
            switch current {
            case .daily: result = UsageReader.dailyBreakdown()
            case .weekly: result = UsageReader.weeklyBreakdown()
            case .monthly: result = UsageReader.monthlyBreakdown()
            case .model: result = UsageReader.modelBreakdown()
            case .project: result = UsageReader.projectBreakdown()
            }
            await MainActor.run {
                loading = false
                if current == mode {
                    rows = result
                } else {
                    load()
                }
            }
        }
    }
}
