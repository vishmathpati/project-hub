import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum UsageRangePreset: String, CaseIterable, Identifiable {
    case today, thisWeek, thisMonth, last30Days, all, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This week"
        case .thisMonth: return "This month"
        case .last30Days: return "Last 30 days"
        case .all: return "All"
        case .custom: return "Custom"
        }
    }

    func range(customStart: Date, customEnd: Date, now: Date = Date()) -> UsageReader.UsageDateRange {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: now)
        switch self {
        case .today:
            return UsageReader.UsageDateRange(label: title, start: day, end: nil)
        case .thisWeek:
            return UsageReader.UsageDateRange(label: title, start: calendar.dateInterval(of: .weekOfYear, for: now)?.start, end: nil)
        case .thisMonth:
            return UsageReader.UsageDateRange(label: title, start: calendar.dateInterval(of: .month, for: now)?.start, end: nil)
        case .last30Days:
            return UsageReader.UsageDateRange(label: title, start: calendar.date(byAdding: .day, value: -29, to: day), end: nil)
        case .all:
            return UsageReader.UsageDateRange(label: title, start: nil, end: nil)
        case .custom:
            let from = calendar.startOfDay(for: min(customStart, customEnd))
            let to = calendar.startOfDay(for: max(customStart, customEnd))
            return UsageReader.UsageDateRange(
                label: title,
                start: from,
                end: calendar.date(byAdding: .day, value: 1, to: to)
            )
        }
    }
}

struct UsageFilterBar: View {
    @Binding var preset: UsageRangePreset
    @Binding var customStart: Date
    @Binding var customEnd: Date
    @Binding var ascending: Bool
    let onExport: (UsageExporter.Format) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Range", selection: $preset) {
                ForEach(UsageRangePreset.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            if preset == .custom {
                HStack(spacing: 8) {
                    Text("From")
                        .font(HubFont.caption)
                        .foregroundStyle(HubTheme.textDim)
                    DatePicker("", selection: $customStart, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    Text("to")
                        .font(HubFont.caption)
                        .foregroundStyle(HubTheme.textDim)
                    DatePicker("", selection: $customEnd, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    Spacer(minLength: 0)
                }
            }
            HStack(spacing: 8) {
                Text("Ascending")
                    .font(HubFont.caption)
                    .foregroundStyle(HubTheme.textMid)
                HubToggle(isOn: $ascending)
                Spacer(minLength: 0)
                HubButton(title: "JSON", kind: .inlineAction) { onExport(.json) }
                HubButton(title: "CSV", kind: .inlineAction) { onExport(.csv) }
            }
        }
    }
}

enum UsageExporter {
    enum Format: String { case json, csv }

    static func save(
        format: Format,
        suggestedName: String,
        message: String,
        failure: Binding<String?>,
        contents: @escaping () throws -> Data
    ) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.message = message
        panel.allowedContentTypes = format == .json ? [UTType.json] : [UTType.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        failure.wrappedValue = nil
        Task.detached(priority: .utility) {
            do {
                try contents().write(to: url, options: .atomic)
            } catch {
                await MainActor.run { failure.wrappedValue = error.localizedDescription }
            }
        }
    }

    static func dateStamp() -> String {
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd"
        return format.string(from: Date())
    }
}

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
        .onChange(of: preset) { _, _ in load() }
        .onChange(of: customStart) { _, _ in load() }
        .onChange(of: customEnd) { _, _ in load() }
        .onChange(of: ascending) { _, _ in load() }
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
        let currentRange = range
        let order = ascending
        Task.detached(priority: .utility) {
            let result: [UsageReader.UsageBreakdownRow]
            switch current {
            case .daily: result = UsageReader.dailyBreakdown(in: currentRange, ascending: order)
            case .weekly: result = UsageReader.weeklyBreakdown(in: currentRange, ascending: order)
            case .monthly: result = UsageReader.monthlyBreakdown(in: currentRange, ascending: order)
            case .model: result = UsageReader.modelBreakdown(in: currentRange, ascending: order)
            case .project: result = UsageReader.projectBreakdown(in: currentRange, ascending: order)
            }
            await MainActor.run {
                loading = false
                if current == mode, currentRange == range, order == ascending {
                    rows = result
                } else {
                    load()
                }
            }
        }
    }

    private func export(_ format: UsageExporter.Format) {
        let snapshot = rows
        let column = mode.columnTitle
        let stamp = UsageExporter.dateStamp()
        UsageExporter.save(
            format: format,
            suggestedName: "usage-\(mode.rawValue)-\(stamp).\(format.rawValue)",
            message: "\(snapshot.count) rows · \(range.label)",
            failure: $exportError
        ) {
            switch format {
            case .json:
                return try UsageReader.jsonData(snapshot)
            case .csv:
                return UsageReader.csvData(
                    header: [column, "In", "Out", "Cache-Create", "Cache-Read", "Total", "$"],
                    rows: Self.csvRows(snapshot)
                )
            }
        }
    }

    private static func csvRows(_ rows: [UsageReader.UsageBreakdownRow]) -> [[String]] {
        var lines = rows.map { row in [row.label] + csvFields(row.totals) }
        if !rows.isEmpty {
            let sums = rows.reduce(into: UsageTotals()) { $0.add($1.totals) }
            lines.append(["Total"] + csvFields(sums))
        }
        return lines
    }

    private static func csvFields(_ totals: UsageTotals) -> [String] {
        [
            "\(totals.input)",
            "\(totals.output)",
            "\(totals.cacheWrite)",
            "\(totals.cacheRead)",
            "\(totals.tokens)",
            String(format: "%.6f", totals.cost),
        ]
    }
}
