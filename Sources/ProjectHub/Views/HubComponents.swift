import SwiftUI
import AppKit

// MARK: - Provider tile (DESIGN.md §3)
//
// The single most repeated component in the app. Wherever a provider is named,
// its tile precedes the name. Real app icon first, two-character monogram as the
// fallback. Never an SF Symbol — symbols were the old identity and read generic.

struct ProviderTile: View {
    let toolID: String
    var size: CGFloat = 17

    private var radius: CGFloat {
        size > 22 ? HubTheme.Radius.tileLarge : HubTheme.Radius.tile
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(ToolPalette.tileBackground(for: toolID))
            if let icon = ToolPalette.appImage(for: toolID) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: radius))
            } else {
                Text(ToolPalette.mark(for: toolID))
                    .font(HubFont.mono(size > 22 ? 9 : 8, .bold))
                    .foregroundStyle(ToolPalette.tileForeground(for: toolID))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(ToolPalette.label(for: toolID))
    }
}

/// A run of provider tiles, as it appears inline on a list row.
struct ProviderTileRow: View {
    let toolIDs: [String]
    var size: CGFloat = 17
    var limit: Int = 5

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(toolIDs.prefix(limit)), id: \.self) { id in
                ProviderTile(toolID: id, size: size)
            }
            if toolIDs.count > limit {
                Text("+\(toolIDs.count - limit)")
                    .font(HubFont.mono(9))
                    .foregroundStyle(HubTheme.textFaint)
            }
        }
    }
}

// MARK: - Status (§2.3)
//
// Status colour appears as a 6pt dot plus a word. Never a dot alone — colour is
// not the label.

enum HubStatus {
    case ok, warn, bad, neutral

    var color: Color {
        switch self {
        case .ok:      return HubTheme.ok
        case .warn:    return HubTheme.warn
        case .bad:     return HubTheme.bad
        case .neutral: return HubTheme.textFaint
        }
    }
}

struct StatusDot: View {
    let status: HubStatus
    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 6, height: 6)
    }
}

/// Dot plus word. Use this rather than a bare dot anywhere state is communicated.
struct StatusLabel: View {
    let status: HubStatus
    let text: String
    var font: Font = HubFont.secondary

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(status: status)
            Text(text)
                .font(font)
                .foregroundStyle(status == .neutral ? HubTheme.textFaint : status.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

/// Em dash standing in for an absent value — never blank, never zero (§7.3).
struct AbsentValue: View {
    var font: Font = HubFont.machine
    var body: some View {
        Text("—")
            .font(font)
            .foregroundStyle(HubTheme.absent)
    }
}

// MARK: - Buttons (§7.5)

enum HubButtonKind {
    case primary          // accent fill, one per toolbar, one per attention item
    case secondary        // stroke border, sans 12
    case inlineAction     // stroke border, mono 10 — row actions
    case accentInline     // accent text on accentBorder, mono 10 — track / install
    case destructive      // bad text on badBorder
}

struct HubButton: View {
    let title: String
    var kind: HubButtonKind = .secondary
    var systemImage: String? = nil
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: isMono ? 9 : 10, weight: .medium))
                }
                Text(title).font(font)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, isMono ? 9 : 11)
            .frame(height: HubTheme.buttonHeight)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: HubTheme.Radius.control)
                    .strokeBorder(border, lineWidth: border == .clear ? 0 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(HubTheme.selectionAnimation, value: hovering)
    }

    private var isMono: Bool { kind == .inlineAction || kind == .accentInline }

    private var font: Font {
        switch kind {
        case .inlineAction, .accentInline: return HubFont.mono(10)
        case .primary:                     return HubFont.sans(12, .semibold)
        default:                           return HubFont.sans(12)
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary:      return HubTheme.onAccent
        case .accentInline: return HubTheme.accent
        case .destructive:  return HubTheme.bad
        default:            return HubTheme.controlText
        }
    }

    private var background: Color {
        switch kind {
        case .primary:      return HubTheme.accent
        case .accentInline: return hovering ? HubTheme.accentBg : .clear
        case .destructive:  return hovering ? HubTheme.badBg : .clear
        default:            return hovering ? HubTheme.field : .clear
        }
    }

    private var border: Color {
        switch kind {
        case .primary:      return .clear
        case .accentInline: return HubTheme.accentBorder
        case .destructive:  return HubTheme.badBorder
        default:            return HubTheme.stroke
        }
    }
}

/// A borderless toolbar glyph — rescan, collapse inspector, overflow menu.
struct HubIconButton: View {
    let systemImage: String
    var help: String = ""
    var isActive: Bool = false
    var spinning: Bool = false
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isActive ? HubTheme.accent : HubTheme.textMid)
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(
                    spinning
                        ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                        : .default,
                    value: spinning
                )
                .frame(width: HubTheme.buttonHeight, height: HubTheme.buttonHeight)
                .background(hovering ? HubTheme.field : .clear)
                .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.control))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

// MARK: - Section heading (§7.4)
//
// Mono 9 uppercase, count, a hairline rule filling the width, then an optional
// accent action on the right.

struct HubSectionHeading<Trailing: View>: View {
    let title: String
    var count: Int? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            Text(title).groupHeadingStyle(HubTheme.headingText)
            if let count {
                Text("\(count)")
                    .font(HubFont.mono(9))
                    .foregroundStyle(HubTheme.textFaint)
            }
            Rectangle()
                .fill(HubTheme.hairline)
                .frame(height: 1)
                .frame(maxWidth: .infinity)
            trailing()
        }
        .frame(minHeight: 16)
    }
}

extension HubSectionHeading where Trailing == EmptyView {
    init(_ title: String, count: Int? = nil) {
        self.init(title: title, count: count, trailing: { EmptyView() })
    }
}

// MARK: - Attention strip (§7.1)
//
// Sits above the list it concerns, not inside it. An attention item without an
// inline action does not belong here — it belongs in Checks.

struct AttentionItem: Identifiable {
    let id: String
    let subject: String          // rendered semibold inside the title line
    let problem: String          // the rest of the title line
    let evidence: String         // mono 10 — path, config file, age
    let dismissTitle: String     // secondary action
    let dismiss: () -> Void
    let fixTitle: String         // accent primary action
    let fix: () -> Void
}

struct AttentionStrip: View {
    let items: [AttentionItem]
    var hint: String = "fix here, no need to open the project"

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    StatusDot(status: .bad)
                    Text("\(items.count) thing\(items.count == 1 ? "" : "s") need\(items.count == 1 ? "s" : "") you")
                        .font(HubFont.sans(12, .semibold))
                        .foregroundStyle(HubTheme.bad)
                    Spacer(minLength: 12)
                    Text(hint)
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textDim)
                }

                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            (Text(item.subject).font(HubFont.sans(12.5, .semibold))
                                + Text(" · ").font(HubFont.body)
                                + Text(item.problem).font(HubFont.body))
                                .foregroundStyle(HubTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(item.evidence)
                                .font(HubFont.machine)
                                .foregroundStyle(HubTheme.textDim)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer(minLength: 12)
                        HubButton(title: item.dismissTitle, kind: .secondary, action: item.dismiss)
                        HubButton(title: item.fixTitle, kind: .primary, action: item.fix)
                    }
                }
            }
            .padding(HubTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HubTheme.badBg)
            .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: HubTheme.Radius.card)
                    .strokeBorder(HubTheme.badBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Metric tile (§7.6)

struct MetricTile: View {
    let value: String
    let label: String
    var tone: Tone = .plain
    var compact: Bool = false

    enum Tone { case plain, accent, ok, warn, bad }

    private var valueColor: Color {
        switch tone {
        case .plain:  return HubTheme.text
        case .accent: return HubTheme.accent
        case .ok:     return HubTheme.ok
        case .warn:   return HubTheme.warn
        case .bad:    return HubTheme.bad
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(compact ? HubFont.bigNumberSmall : HubFont.bigNumber)
                .foregroundStyle(valueColor)
            Text(label)
                .font(HubFont.secondary)
                .foregroundStyle(HubTheme.textMid)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, HubTheme.cardPadding)
        .hubCard()
    }
}

// MARK: - Quota bar (§7.7)
//
// Quota before cost, always. Thresholds: <70 ok, 70–89 warn, >=90 bad.

struct QuotaBar: View {
    let label: String
    let percent: Int
    var note: String? = nil

    static func tone(for percent: Int) -> HubStatus {
        if percent >= 90 { return .bad }
        if percent >= 70 { return .warn }
        return .ok
    }

    private var color: Color { QuotaBar.tone(for: percent).color }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(HubFont.caption)
                    .foregroundStyle(HubTheme.textMid)
                Spacer(minLength: 8)
                Text("\(percent)%")
                    .font(HubFont.mono(11.5))
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(HubTheme.line)
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, min(1, Double(percent) / 100)) * geo.size.width)
                }
            }
            .frame(height: 5)
            if let note {
                Text(note)
                    .font(HubFont.mono(10.5))
                    .foregroundStyle(HubTheme.textFaint)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(percent) percent")
    }
}

// MARK: - Toggle (§7.8)

struct HubToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? HubTheme.accent : HubTheme.stroke)
                    .frame(width: 34, height: 19)
                Circle()
                    .fill(isOn ? HubTheme.onAccent : HubTheme.textFaint)
                    .frame(width: 13, height: 13)
                    .padding(.horizontal, 3)
            }
            .frame(width: 34, height: 19)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(HubTheme.selectionAnimation, value: isOn)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

// MARK: - Page header and footer (§5.1)

/// The 44pt toolbar row at the top of every content pane.
struct HubPageHeader<Actions: View>: View {
    let title: String
    var subtitle: String? = nil
    var backTitle: String? = nil
    var back: (() -> Void)? = nil
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(spacing: 10) {
            if let backTitle, let back {
                HubButton(title: "‹ \(backTitle)", kind: .secondary, action: back)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(HubFont.pageTitle)
                    .foregroundStyle(HubTheme.textStrong)
                if let subtitle {
                    Text(subtitle)
                        .font(HubFont.caption)
                        .foregroundStyle(HubTheme.textDim)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 12)
            actions()
        }
        .padding(.horizontal, HubTheme.contentPadding)
        .frame(height: HubTheme.toolbarHeight)
        .background(HubTheme.panelBg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(HubTheme.line).frame(height: 1)
        }
    }
}

/// The 28pt keyboard hint bar. Every screen shows its keys (§9).
struct FooterHintBar: View {
    let hints: [(key: String, label: String)]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                HStack(spacing: 5) {
                    Text(hint.key)
                        .font(HubFont.mono(10, .medium))
                        .foregroundStyle(HubTheme.textDim)
                    Text(hint.label)
                        .font(HubFont.mono(10))
                        .foregroundStyle(HubTheme.textFaint)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, HubTheme.contentPadding)
        .frame(height: HubTheme.footerHeight)
        .frame(maxWidth: .infinity)
        .background(HubTheme.panelBg)
        .overlay(alignment: .top) {
            Rectangle().fill(HubTheme.line).frame(height: 1)
        }
    }
}

/// Explanatory sentence under a page header. Prose, so sans — never mono.
struct HubPageNote: View {
    let text: String
    var body: some View {
        Text(text)
            .font(HubFont.body)
            .foregroundStyle(HubTheme.textDim)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Search field

struct HubSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search everything"
    var shortcut: String? = "⌘K"

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(HubTheme.textFaint)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(HubFont.secondary)
                .foregroundStyle(HubTheme.text)
            if let shortcut, text.isEmpty {
                Text(shortcut)
                    .font(HubFont.mono(10))
                    .foregroundStyle(HubTheme.textFaint)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: HubTheme.buttonHeight)
        .background(HubTheme.field)
        .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: HubTheme.Radius.control)
                .strokeBorder(HubTheme.line, lineWidth: 1)
        )
    }
}

// MARK: - Data table (§7.3)

struct HubTableColumn: Identifiable {
    let id: String
    let title: String
    let width: CGFloat?      // nil = flexible
    let alignment: Alignment

    init(_ title: String, width: CGFloat? = nil, alignment: Alignment = .leading) {
        self.id = title
        self.title = title
        self.width = width
        self.alignment = alignment
    }
}

struct HubTableHeader: View {
    let columns: [HubTableColumn]
    var sortedColumn: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            ForEach(columns) { column in
                Text(column.title + (column.id == sortedColumn ? " ↓" : ""))
                    .groupHeadingStyle(HubTheme.tableHeaderText)
                    .frame(width: column.width, alignment: column.alignment)
                    .frame(maxWidth: column.width == nil ? .infinity : nil,
                           alignment: column.alignment)
            }
        }
        .padding(.horizontal, HubTheme.contentPadding)
        .frame(height: HubTheme.tableHeaderHeight)
        .background(HubTheme.panelBg)
    }
}

/// A 1px separator between rows inside a list (§2.1 `hairline`).
struct HubRowSeparator: View {
    var body: some View {
        Rectangle().fill(HubTheme.hairline).frame(height: 1)
    }
}

// MARK: - List row (§7.2)
//
// Status dot, name, inline provider tiles, mono second line, and a right slot
// where counts are replaced by actions on hover or selection.

struct HubListRow<Trailing: View>: View {
    let status: HubStatus
    let name: String
    var providers: [String] = []
    var caption: String? = nil          // mono second line — path · relative time
    var badge: String? = nil            // e.g. "global", "no SKILL.md"
    var isSelected: Bool = false
    var isDimmed: Bool = false          // missing on disk
    @ViewBuilder var trailing: (Bool) -> Trailing   // Bool = hovering or selected

    @State private var hovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            StatusDot(status: status)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(isSelected ? HubFont.rowPrimarySel : HubFont.rowPrimary)
                        .foregroundStyle(isSelected ? HubTheme.textStrong : HubTheme.text)
                        .lineLimit(1)
                    if let badge {
                        Text(badge)
                            .font(HubFont.mono(9))
                            .foregroundStyle(HubTheme.textFaint)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(HubTheme.stroke, lineWidth: 1)
                            )
                    }
                    if !providers.isEmpty {
                        ProviderTileRow(toolIDs: providers)
                    }
                }
                if let caption {
                    Text(caption)
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textDim)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 12)

            trailing(hovering || isSelected)
        }
        .padding(.horizontal, HubTheme.contentPadding)
        .frame(minHeight: HubTheme.listRowHeight)
        .opacity(isDimmed ? 0.55 : 1)
        .background(isSelected ? HubTheme.rowSelected : (hovering ? HubTheme.raised : .clear))
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle()
                    .fill(HubTheme.accent)
                    .frame(width: 2)
                    .padding(.vertical, 4)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(HubTheme.selectionAnimation, value: hovering)
        .animation(HubTheme.selectionAnimation, value: isSelected)
    }
}

/// Mono counts on the right of a row — "7 skl  4 mcp  2 agt".
struct HubRowCounts: View {
    let counts: [(value: Int?, unit: String)]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(counts.enumerated()), id: \.offset) { _, item in
                if let value = item.value, value > 0 {
                    Text("\(value) \(item.unit)")
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textDim)
                } else {
                    AbsentValue()
                }
            }
        }
    }
}
