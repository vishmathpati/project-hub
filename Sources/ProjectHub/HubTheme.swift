import SwiftUI
import AppKit

// MARK: - Design tokens
//
// Project Hub owns its own surface: dark-first, dense, keyboard-forward.
// Dark is the designed appearance; light is derived from it (DESIGN.md §2.5).
// Every colour, size and radius used by a view comes from here.

enum HubTheme {

    // MARK: Neutrals (§2.1)

    static var bg:        Color { dyn("#0A0B0C", "#F7F8F9") }
    static var panelBg:   Color { dyn("#0D0E10", "#F1F2F4") }
    static var raised:    Color { dyn("#0F1113", "#FFFFFF") }
    static var field:     Color { dyn("#131416", "#FFFFFF") }
    static var line:      Color { dyn("#1C1E21", "#DDE0E4") }
    static var hairline:  Color { dyn("#17191C", "#E7E9EC") }
    static var stroke:    Color { dyn("#23262A", "#C9CDD3") }

    static var text:       Color { dyn("#E6E7E9", "#1D2024") }
    static var textStrong: Color { dyn("#F2F3F5", "#0D0F12") }
    static var textMid:    Color { dyn("#9AA0A8", "#5A6069") }
    static var textDim:    Color { dyn("#7A8089", "#6E747C") }
    static var textFaint:  Color { dyn("#5E636B", "#8A9099") }

    /// Group headings in the rail and section headings in content.
    static var headingText: Color { dyn("#868C95", "#666C75") }
    /// Table column headers.
    static var tableHeaderText: Color { dyn("#6B7078", "#767C85") }
    /// Secondary button / inline action label.
    static var controlText: Color { dyn("#C9CDD3", "#31363C") }
    /// Em dash standing in for an absent value.
    static var absent: Color { dyn("#5C5750", "#9AA0A8") }

    // MARK: Accent (§2.2)

    static var accent:       Color { dyn("#FF7A29", "#FF7A29") }
    static var onAccent:     Color { dyn("#17100A", "#17100A") }
    static var accentBg:     Color { dyn("#1C1309", "#FFF1E6") }
    static var accentBorder: Color { dyn("#3D2412", "#F5C79E") }
    static var accentText:   Color { dyn("#C9A98E", "#7A4A22") }

    // MARK: Status (§2.3)

    static var ok:   Color { dyn("#5FC98A", "#2E9A5C") }
    static var warn: Color { dyn("#E0A44B", "#A9701A") }
    static var bad:  Color { dyn("#F2565B", "#D03B41") }

    static var badBg:     Color { dyn("#120D0E", "#FDF2F3") }
    static var badBorder: Color { dyn("#3E1D21", "#F3C9CC") }
    static var warnBg:    Color { dyn("#2B1418", "#FBE9D9") }

    /// Selected list row fill (§7.2).
    static var rowSelected: Color { dyn("#0F1413", "#FFF6EE") }

    // MARK: Metrics (§5)

    static let railWidth:      CGFloat = 232
    static let subRailWidth:   CGFloat = 186
    static let inspectorWidth: CGFloat = 328   // Projects
    static let inspectorWide:  CGFloat = 340   // everywhere else
    static let toolbarHeight:  CGFloat = 44
    static let footerHeight:   CGFloat = 28
    static let navRowHeight:   CGFloat = 32
    static let listRowHeight:  CGFloat = 46
    static let tableRowHeight: CGFloat = 44
    static let tableHeaderHeight: CGFloat = 34
    static let buttonHeight:   CGFloat = 26

    static let minWindowWidth:  CGFloat = 1100
    static let minWindowHeight: CGFloat = 720
    static let idealWindowWidth:  CGFloat = 1240
    static let idealWindowHeight: CGFloat = 820

    static let contentPadding: CGFloat = 16
    static let cardPadding:    CGFloat = 15
    static let sectionGap:     CGFloat = 19

    // MARK: Radii (§5.3)

    enum Radius {
        static let window:    CGFloat = 12
        static let card:      CGFloat = 10
        static let control:   CGFloat = 7
        static let tile:      CGFloat = 4
        static let tileLarge: CGFloat = 6
    }

    // MARK: Motion (§10)

    static let selectionAnimation = Animation.easeOut(duration: 0.12)
    static let disclosureAnimation = Animation.easeInOut(duration: 0.18)

    // MARK: Hex → dynamic Color

    private static func dyn(_ dark: String, _ light: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return nsColor(hex: isDark ? dark : light)
        })
    }

    static func nsColor(hex: String) -> NSColor {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt32(s, radix: 16) ?? 0
        return NSColor(
            srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
            green:   CGFloat((v >>  8) & 0xFF) / 255,
            blue:    CGFloat( v        & 0xFF) / 255,
            alpha: 1
        )
    }

    static func color(hex: String) -> Color { Color(nsColor: nsColor(hex: hex)) }
}

// MARK: - Type (§4)
//
// Two families: IBM Plex Sans for UI, IBM Plex Mono for machine text.
// Both fall back to the system faces when Plex is not installed, which is the
// documented acceptable outcome rather than an error.

enum HubFont {

    private static let sansFamily: String? = resolveFamily(["IBM Plex Sans"])
    private static let monoFamily: String? = resolveFamily(["IBM Plex Mono"])

    private static func resolveFamily(_ names: [String]) -> String? {
        let installed = Set(NSFontManager.shared.availableFontFamilies)
        return names.first(where: installed.contains)
    }

    /// UI text. Prose, labels, titles.
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        guard let family = sansFamily,
              let descriptor = fontDescriptor(family: family, weight: weight),
              NSFont(descriptor: descriptor, size: size) != nil
        else { return .system(size: size, weight: weight) }
        return .custom(descriptor.postscriptName ?? family, size: size)
    }

    /// Machine text. Paths, commands, counts, keys, config filenames — never prose.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        guard let family = monoFamily,
              let descriptor = fontDescriptor(family: family, weight: weight),
              NSFont(descriptor: descriptor, size: size) != nil
        else { return .system(size: size, weight: weight, design: .monospaced) }
        return .custom(descriptor.postscriptName ?? family, size: size)
    }

    private static func fontDescriptor(family: String, weight: Font.Weight) -> NSFontDescriptor? {
        NSFontDescriptor(fontAttributes: [
            .family: family,
            .traits: [NSFontDescriptor.TraitKey.weight: nsWeight(weight)],
        ])
    }

    private static func nsWeight(_ weight: Font.Weight) -> NSFont.Weight {
        switch weight {
        case .bold:     return .bold
        case .semibold: return .semibold
        case .medium:   return .medium
        case .light:    return .light
        default:        return .regular
        }
    }

    // Named roles from the scale, so views do not repeat raw numbers.

    static var pageTitle:      Font { sans(13, .semibold) }
    static var sectionTitle:   Font { sans(13, .semibold) }
    static var rowPrimary:     Font { sans(13, .medium) }
    static var rowPrimarySel:  Font { sans(13, .semibold) }
    static var navItem:        Font { sans(13) }
    static var navItemSel:     Font { sans(13, .medium) }
    static var body:           Font { sans(12.5) }
    static var secondary:      Font { sans(12) }
    static var caption:        Font { sans(11.5) }
    static var railCaption:    Font { sans(11) }
    static var machine:        Font { mono(10) }
    static var machineLarge:   Font { mono(11) }
    static var groupHeading:   Font { mono(9, .semibold) }
    static var bigNumber:      Font { mono(26) }
    static var bigNumberSmall: Font { mono(20) }
}

extension Text {
    /// Group heading treatment: mono 9 semibold, uppercase, tracked out (§4).
    func groupHeadingStyle(_ color: Color) -> some View {
        self.font(HubFont.groupHeading)
            .kerning(1.1)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

// MARK: - Surfaces

extension View {
    /// Card / panel / table container: `raised` on `line`, radius 10 (§5.3).
    func hubCard(radius: CGFloat = HubTheme.Radius.card) -> some View {
        self.background(HubTheme.raised)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(HubTheme.line, lineWidth: 1)
            )
    }

    /// Expands the hit target of a control smaller than the 26pt minimum (§5.4).
    func hubHitTarget(minHeight: CGFloat = HubTheme.buttonHeight) -> some View {
        self.frame(minHeight: minHeight)
            .contentShape(Rectangle())
    }
}
