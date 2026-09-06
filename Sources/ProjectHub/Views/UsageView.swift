import SwiftUI

// MARK: - Usage (screen 3g)
//
// Quota before cost, always (DESIGN.md §7.7). Cost is a mono note in the card
// header, never the headline. Everything here is read from local files.

struct UsageView: View {
    @State private var cards: [UsageCard] = []
    @State private var loading = false

    /// Cards carrying at least one quota window, ordered by how close they are
    /// to a limit — the ones that can actually stop you working come first.
    private var quotaCards: [UsageCard] {
        cards
            .filter { !$0.windows.isEmpty }
            .sorted { peak($0) > peak($1) }
    }

    private var meteredCards: [UsageCard] {
        cards.filter { $0.windows.isEmpty && ($0.week.cost > 0 || $0.today.cost > 0 || $0.block.tokens > 0) }
    }

    private var quietCards: [UsageCard] {
        cards.filter { $0.windows.isEmpty && $0.week.cost <= 0 && $0.today.cost <= 0 && $0.block.tokens == 0 }
    }

    private func peak(_ card: UsageCard) -> Double {
        card.windows.map(\.usedPercent).max() ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            HubPageHeader(
                title: "Usage",
                subtitle: "Read from files on this Mac · quota first, cost second"
            ) {
                if loading {
                    ProgressView().controlSize(.small)
                }
                HubButton(title: "Refresh", kind: .primary) { load() }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: HubTheme.sectionGap) {
                    if !quotaCards.isEmpty {
                        section("Close to a limit", count: quotaCards.count) {
                            LazyVGrid(columns: twoColumns, spacing: 10) {
                                ForEach(quotaCards) { card in quotaCard(card) }
                            }
                        }
                    }

                    if !meteredCards.isEmpty {
                        section("Metered", count: meteredCards.count) {
                            LazyVGrid(columns: twoColumns, spacing: 10) {
                                ForEach(meteredCards) { card in quotaCard(card) }
                            }
                        }
                    }

                    if !quietCards.isEmpty {
                        section("Other providers", count: quietCards.count) {
                            VStack(spacing: 0) {
                                ForEach(Array(quietCards.enumerated()), id: \.element.id) { index, card in
                                    if index > 0 { HubRowSeparator() }
                                    quietRow(card)
                                }
                            }
                            .hubCard()
                        }
                    }
                }
                .padding(HubTheme.contentPadding)
            }
        }
        .background(HubTheme.bg)
        .onAppear { load() }
        .onReceive(Timer.publish(every: 120, on: .main, in: .common).autoconnect()) { _ in
            load()
        }
    }

    private var twoColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading(title, count: count)
            content()
        }
    }

    // MARK: - Quota card

    private func quotaCard(_ card: UsageCard) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ProviderTile(toolID: card.providerID, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.provider)
                        .font(HubFont.sans(13, .semibold))
                        .foregroundStyle(HubTheme.textStrong)
                    Text(card.plan)
                        .font(HubFont.caption)
                        .foregroundStyle(HubTheme.textDim)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                // Cost is a note in the header, never the headline (§7.7).
                Text(costNote(card))
                    .font(HubFont.machineLarge)
                    .foregroundStyle(HubTheme.textDim)
            }

            if card.windows.isEmpty {
                blockBar(card)
            } else {
                ForEach(card.windows) { window in
                    QuotaBar(
                        label: window.title,
                        percent: Int(window.usedPercent.rounded()),
                        note: resetNote(window)
                    )
                }
            }

            HStack(spacing: 18) {
                spend("Today", card.today)
                spend("7 days", card.week)
                Spacer(minLength: 0)
                if let model = card.lastModel {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("last model")
                            .font(HubFont.mono(9))
                            .foregroundStyle(HubTheme.textFaint)
                        Text(shortModel(model))
                            .font(HubFont.machine)
                            .foregroundStyle(HubTheme.textDim)
                    }
                }
            }

            if let note = card.note {
                Text(note)
                    .font(HubFont.caption)
                    .foregroundStyle(HubTheme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(HubTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hubCard()
    }

    private func blockBar(_ card: UsageCard) -> some View {
        let remaining = card.blockEndsAt.map { max(0, $0.timeIntervalSinceNow) } ?? 0
        let usedFraction = card.blockEndsAt == nil ? 0 : min(1, max(0, 1 - remaining / (5 * 60 * 60)))
        return QuotaBar(
            label: "5-hour window",
            percent: Int((usedFraction * 100).rounded()),
            note: card.blockEndsAt == nil
                ? "not started"
                : "\(hoursMinutes(remaining)) left in the local billing block"
        )
    }

    private func quietRow(_ card: UsageCard) -> some View {
        HStack(spacing: 10) {
            ProviderTile(toolID: card.providerID)
            Text(card.provider)
                .font(HubFont.rowPrimary)
                .foregroundStyle(HubTheme.text)
            Spacer(minLength: 12)
            Text(card.note ?? "no quota data on disk")
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.textFaint)
                .lineLimit(1)
        }
        .padding(.horizontal, HubTheme.contentPadding)
        .frame(height: HubTheme.tableRowHeight)
    }

    private func spend(_ title: String, _ totals: UsageTotals) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(HubFont.mono(9))
                .foregroundStyle(HubTheme.textFaint)
            HStack(spacing: 6) {
                Text(tokens(totals.tokens))
                    .font(HubFont.machine)
                    .foregroundStyle(HubTheme.text)
                if totals.cost > 0 {
                    Text(money(totals.cost))
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textDim)
                }
            }
        }
    }

    // MARK: - Formatting

    private func costNote(_ card: UsageCard) -> String {
        card.week.cost > 0 ? "\(money(card.week.cost)) this week" : "included"
    }

    private func resetNote(_ window: UsageWindow) -> String? {
        guard let reset = window.resetsAt else { return nil }
        let remaining = reset.timeIntervalSinceNow
        if remaining <= 0 { return "resetting now" }
        if remaining < 24 * 60 * 60 { return "resets in \(hoursMinutes(remaining))" }
        return "resets \(reset.formatted(.dateTime.weekday(.wide)))"
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

    private func shortModel(_ model: String) -> String {
        model.replacingOccurrences(of: "claude-", with: "")
    }

    private func load() {
        guard !loading else { return }
        let showSpinner = cards.isEmpty
        if showSpinner { loading = true }
        Task.detached(priority: .utility) {
            let result = UsageReader.summarize()
            await MainActor.run {
                cards = result
                loading = false
            }
        }
    }
}
