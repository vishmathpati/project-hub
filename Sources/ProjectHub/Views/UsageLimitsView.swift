import SwiftUI

struct UsageLimitsView: View {
    @State private var state = UsageLimitsState()
    @State private var progresses: [LimitProgress] = []
    @State private var period: LimitPeriod = .week
    @State private var explicitText = ""
    @State private var loaded = false

    private var limit: UsageLimit? {
        state.limit(for: period)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading("Token limits")
            editorCard
            gaugeCard
            eventSection
        }
        .onAppear { load() }
        .onChange(of: period) { _, _ in syncText() }
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Period", selection: $period) {
                ForEach(LimitPeriod.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            HStack(spacing: 8) {
                Text("Use max previous")
                    .font(HubFont.caption)
                    .foregroundStyle(HubTheme.textMid)
                HubToggle(isOn: maxBinding)
                Spacer(minLength: 0)
            }
            if !(limit?.isMaxPrevious ?? true) {
                HStack(spacing: 8) {
                    TextField("Token cap", text: $explicitText)
                        .textFieldStyle(.plain)
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.text)
                        .padding(.horizontal, 9)
                        .frame(height: HubTheme.buttonHeight)
                        .background(HubTheme.field)
                        .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.control))
                        .overlay(
                            RoundedRectangle(cornerRadius: HubTheme.Radius.control)
                                .strokeBorder(HubTheme.line, lineWidth: 1)
                        )
                        .frame(maxWidth: 160)
                    HubButton(title: "Set cap", kind: .inlineAction) { saveExplicit() }
                }
            } else {
                Text("Cap follows the highest previous period.")
                    .font(HubFont.caption)
                    .foregroundStyle(HubTheme.textFaint)
            }
        }
        .padding(HubTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hubCard()
    }

    private var gaugeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if progresses.isEmpty {
                Text(loaded ? "Set a cap to start the gauge." : "Reading local logs…")
                    .font(HubFont.body)
                    .foregroundStyle(HubTheme.textFaint)
            } else {
                ForEach(progresses, id: \.period) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        QuotaBar(
                            label: "\(item.period.title) · \(tokens(item.used)) of \(tokens(item.cap))",
                            percent: Int(item.percent.rounded()),
                            note: markerNote(item)
                        )
                        StatusLabel(status: gaugeTone(item.status), text: item.statusText)
                    }
                }
            }
        }
        .padding(HubTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hubCard()
    }

    private var eventSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading("Threshold events", count: state.events.isEmpty ? nil : min(state.events.count, 8))
            VStack(spacing: 0) {
                if state.events.isEmpty {
                    Text("No threshold crossings yet. Defaults fire at 75% and 90%, plus on reset.")
                        .font(HubFont.body)
                        .foregroundStyle(HubTheme.textFaint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(state.events.prefix(8))) { event in
                            eventRow(event)
                            if event.id != state.events.prefix(8).last?.id { HubRowSeparator() }
                        }
                    }
                }
            }
            .hubCard()
        }
    }

    private func eventRow(_ event: ThresholdEvent) -> some View {
        HStack(spacing: 10) {
            StatusDot(status: event.kind == .reset ? .neutral : .warn)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.text)
                    .font(HubFont.rowPrimary)
                    .foregroundStyle(HubTheme.text)
                Text(event.date.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                    .font(HubFont.machine)
                    .foregroundStyle(HubTheme.textFaint)
            }
            Spacer(minLength: 12)
        }
        .padding(.horizontal, HubTheme.contentPadding)
        .frame(minHeight: HubTheme.tableRowHeight)
    }

    private var maxBinding: Binding<Bool> {
        Binding(
            get: { limit?.isMaxPrevious ?? true },
            set: { value in
                if value {
                    state.setMode(.maxPrevious, for: period)
                } else {
                    state.setExplicit(Int(explicitText) ?? 0, for: period)
                }
                persist()
            }
        )
    }

    private func markerNote(_ item: LimitProgress) -> String? {
        if item.status == .exceeded { return "alert marker · over 90% · \(Int(item.percent.rounded()))%" }
        if item.status == .warning { return "warning marker · approaching · \(Int(item.percent.rounded()))%" }
        return "\(Int(item.percent.rounded()))% of cap"
    }

    private func gaugeTone(_ status: LimitStatus) -> HubStatus {
        switch status {
        case .ok: return .ok
        case .warning: return .warn
        case .exceeded: return .bad
        }
    }

    private func tokens(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM tok", Double(value) / 1_000_000) }
        if value >= 1_000 { return "\(value.formatted()) tok" }
        return "\(value) tok"
    }

    private func syncText() {
        explicitText = "\(state.limit(for: period)?.explicitValue ?? 0)"
    }

    private func saveExplicit() {
        state.setExplicit(Int(explicitText) ?? 0, for: period)
        persist()
    }

    private func persist() {
        let snapshot = state
        progresses = UsageLimits.progressAll(state: snapshot)
        let copy = state
        Task.detached(priority: .utility) {
            UsageLimits.save(copy)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        Task.detached(priority: .utility) {
            var stored = UsageLimits.load()
            _ = UsageLimits.poll(&stored, now: Date())
            UsageLimits.save(stored)
            let advances = UsageLimits.progressAll(state: stored)
            await MainActor.run {
                state = stored
                progresses = advances
                syncText()
            }
        }
    }
}
