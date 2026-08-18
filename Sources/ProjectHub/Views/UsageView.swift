import SwiftUI

struct UsageView: View {
    @State private var cards: [UsageCard] = []
    @State private var loading = false

    private var featured: [UsageCard] { cards.filter(\.featured) }
    private var rest: [UsageCard] { cards.filter { !$0.featured } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("From files on this Mac. Quota first, cost second.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                if loading {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Refresh") { load() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(loading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(featured) { card in
                            featuredCard(card)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Other providers")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        ForEach(rest) { card in
                            compactRow(card)
                        }
                    }
                }
                .padding(20)
            }
        }
        .onAppear { load() }
        .onReceive(Timer.publish(every: 120, on: .main, in: .common).autoconnect()) { _ in
            load()
        }
    }

    private func featuredCard(_ card: UsageCard) -> some View {
        let color = ToolPalette.color(for: card.providerID)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: ToolPalette.icon(for: card.providerID))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 1) {
                    Text(card.provider)
                        .font(.system(size: 14, weight: .semibold))
                    Text(card.plan)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            if !card.windows.isEmpty {
                ForEach(card.windows) { window in
                    quotaBar(window)
                }
            }
            if card.blockEndsAt != nil || (card.windows.isEmpty && card.block.tokens > 0) {
                blockBar(card)
            }
            if card.windows.isEmpty && card.blockEndsAt == nil && card.block.tokens == 0 {
                Text("No local quota window yet.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Divider().opacity(0.45)

            HStack(spacing: 16) {
                spend(title: "Today", totals: card.today)
                spend(title: "7 days", totals: card.week)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Last session")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(card.lastSession.tokens == 0 ? "—" : "\(tokens(card.lastSession.tokens))")
                        .font(.system(size: 12, weight: .medium))
                    Text(card.lastSession.cost == 0 ? "" : money(card.lastSession.cost))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    if let model = card.lastModel {
                        Text(shortModel(model))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let note = card.note {
                Text(note)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hubCard()
    }

    private func compactRow(_ card: UsageCard) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ToolPalette.icon(for: card.providerID))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ToolPalette.color(for: card.providerID))
                .frame(width: 22)
            Text(card.provider)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 120, alignment: .leading)
            Text(card.note ?? "No local quota file")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
            Spacer()
            if card.week.tokens > 0 {
                Text(money(card.week.cost))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .hubCard()
    }

    private func quotaBar(_ window: UsageWindow) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(Int(window.remainingPercent.rounded()))% left")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
            }
            ProgressView(value: window.usedPercent / 100)
                .tint(window.usedPercent >= 90 ? Color.orange : Color.accentColor)
            HStack {
                Text("\(Int(window.usedPercent.rounded()))% used")
                    .font(.system(size: 11))
                    .foregroundColor(window.usedPercent >= 90 ? .orange : .secondary)
                Spacer()
                if let reset = window.resetsAt {
                    Text("Resets \(reset.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func blockBar(_ card: UsageCard) -> some View {
        let remaining = card.blockEndsAt.map { max(0, $0.timeIntervalSinceNow) } ?? 0
        let fraction = min(1, max(0, 1 - remaining / (5 * 60 * 60)))
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text("5-hour window")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(card.blockEndsAt == nil ? "Not started" : "\(hoursMinutes(remaining)) left")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
            }
            ProgressView(value: card.blockEndsAt == nil ? 0 : fraction)
            HStack {
                Text("Time left in the local billing block")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                if let end = card.blockEndsAt {
                    Text("Ends \(end.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func spend(title: String, totals: UsageTotals) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            Text(tokens(totals.tokens))
                .font(.system(size: 12, weight: .medium))
            Text(money(totals.cost))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private func money(_ value: Double) -> String {
        if value <= 0 { return "$0.00" }
        if value < 0.01 { return "<$0.01" }
        return value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }

    private func tokens(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM tok", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return "\(value.formatted()) tok"
        }
        return value == 0 ? "0 tok" : "\(value) tok"
    }

    private func hoursMinutes(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func shortModel(_ model: String) -> String {
        model.replacingOccurrences(of: "claude-", with: "")
    }

    private func load() {
        guard !loading else { return }
        loading = true
        Task.detached(priority: .utility) {
            let result = UsageReader.summarize()
            await MainActor.run {
                cards = result
                loading = false
            }
        }
    }
}
