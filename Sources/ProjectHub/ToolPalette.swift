import SwiftUI
import AppKit

// MARK: - Per-tool visual identity (color + SF Symbol)

struct ToolPalette {
    struct Entry {
        let color: Color
        let icon:  String   // SF Symbol name
    }

    static let map: [String: Entry] = [
        "claude-desktop": Entry(
            color: Color(red: 0.84, green: 0.38, blue: 0.38),
            icon:  "bubble.left.and.bubble.right.fill"
        ),
        "claude-code": Entry(
            color: Color(red: 0.74, green: 0.27, blue: 0.27),
            icon:  "terminal.fill"
        ),
        "cursor": Entry(
            color: Color(red: 0.54, green: 0.34, blue: 0.96),
            icon:  "cursorarrow.rays"
        ),
        "vscode": Entry(
            color: Color(red: 0.02, green: 0.47, blue: 0.87),
            icon:  "chevron.left.forwardslash.chevron.right"
        ),
        "codex": Entry(
            color: Color(red: 0.20, green: 0.76, blue: 0.44),
            icon:  "sparkles"
        ),
        "windsurf": Entry(
            color: Color(red: 0.06, green: 0.72, blue: 0.60),
            icon:  "wind"
        ),
        "zed": Entry(
            color: Color(red: 0.53, green: 0.19, blue: 0.90),
            icon:  "bolt.circle.fill"
        ),
        "continue": Entry(
            color: Color(red: 0.18, green: 0.78, blue: 0.43),
            icon:  "arrow.clockwise"
        ),
        "gemini": Entry(
            color: Color(red: 0.25, green: 0.54, blue: 0.98),
            icon:  "sparkle"
        ),
        "roo": Entry(
            color: Color(red: 0.98, green: 0.44, blue: 0.10),
            icon:  "antenna.radiowaves.left.and.right"
        ),
        "opencode": Entry(
            color: Color(red: 0.92, green: 0.58, blue: 0.16),
            icon:  "curlybraces"
        ),
        "cline": Entry(
            color: Color(red: 0.13, green: 0.65, blue: 0.82),
            icon:  "scroll.fill"
        ),
        "antigravity": Entry(
            color: Color(red: 0.30, green: 0.50, blue: 0.96),
            icon:  "sparkle"
        ),
        "pi": Entry(
            color: Color(red: 0.15, green: 0.55, blue: 0.70),
            icon:  "circle.hexagongrid.fill"
        ),
        "command-code": Entry(
            color: Color(red: 0.90, green: 0.40, blue: 0.20),
            icon:  "command"
        ),
        "grok": Entry(
            color: Color(red: 0.72, green: 0.76, blue: 0.84),
            icon:  "asterisk.circle.fill"
        ),
    ]

    // MARK: - Provider tile identity (DESIGN.md §2.4)
    //
    // Brand colour is confined to the provider tile. Rows, badges and buttons
    // around it stay neutral — that is what lets ten providers sit on one screen.

    struct Brand {
        let mark: String        // two-character monogram, from ALL_TOOL_META.short
        let label: String
        let fgDark: String      // tile foreground on dark
        let bgDark: String      // tile background on dark
        let fgLight: String     // darkened to hold 4.5:1 on the light tile
        let bgLight: String
    }

    static let brands: [String: Brand] = [
        "claude":         Brand(mark: "Cl", label: "Claude",        fgDark: "#D06A6A", bgDark: "#2A1616", fgLight: "#8E3232", bgLight: "#F7E9E9"),
        "claude-code":    Brand(mark: "CC", label: "Claude Code",   fgDark: "#D06A6A", bgDark: "#2A1616", fgLight: "#8E3232", bgLight: "#F7E9E9"),
        "claude-desktop": Brand(mark: "Cl", label: "Claude Desktop", fgDark: "#D06A6A", bgDark: "#2A1616", fgLight: "#8E3232", bgLight: "#F7E9E9"),
        "codex":          Brand(mark: "Cx", label: "Codex",         fgDark: "#4FD187", bgDark: "#12251A", fgLight: "#1D7746", bgLight: "#E6F6EC"),
        "cursor":         Brand(mark: "Cu", label: "Cursor",        fgDark: "#A985F8", bgDark: "#1E1830", fgLight: "#5B37B0", bgLight: "#EFEAFB"),
        "vscode":         Brand(mark: "VS", label: "VS Code",       fgDark: "#4A9BEA", bgDark: "#10202F", fgLight: "#1C5C9C", bgLight: "#E6F0FA"),
        "zed":            Brand(mark: "Ze", label: "Zed",           fgDark: "#A96BF0", bgDark: "#1E1630", fgLight: "#5C2CA6", bgLight: "#F0E8FC"),
        "opencode":       Brand(mark: "Oc", label: "opencode",      fgDark: "#EFA84D", bgDark: "#2A1F10", fgLight: "#8A5A0C", bgLight: "#FBF0DF"),
        "antigravity":    Brand(mark: "Ag", label: "Antigravity",   fgDark: "#7CA0F8", bgDark: "#161E30", fgLight: "#33509E", bgLight: "#E9EFFC"),
        "pi":             Brand(mark: "Pi", label: "Pi",            fgDark: "#4FA8CC", bgDark: "#10222A", fgLight: "#1B6280", bgLight: "#E4F2F7"),
        "command-code":   Brand(mark: "Cm", label: "Command Code",  fgDark: "#EE8055", bgDark: "#2A1A12", fgLight: "#93411C", bgLight: "#FBEBE4"),
        "grok":           Brand(mark: "Gk", label: "Grok CLI",      fgDark: "#B8C2D6", bgDark: "#1D2029", fgLight: "#454E60", bgLight: "#ECEEF3"),
        "windsurf":       Brand(mark: "Wi", label: "Windsurf",      fgDark: "#3FBFA9", bgDark: "#0F2523", fgLight: "#186B5D", bgLight: "#E4F4F1"),
        "continue":       Brand(mark: "Co", label: "Continue",      fgDark: "#4FD187", bgDark: "#12251A", fgLight: "#1D7746", bgLight: "#E6F6EC"),
        "gemini":         Brand(mark: "Ge", label: "Gemini",        fgDark: "#7CA0F8", bgDark: "#161E30", fgLight: "#33509E", bgLight: "#E9EFFC"),
        "roo":            Brand(mark: "Ro", label: "Roo",           fgDark: "#EFA84D", bgDark: "#2A1F10", fgLight: "#8A5A0C", bgLight: "#FBF0DF"),
        "cline":          Brand(mark: "Cn", label: "Cline",         fgDark: "#4FA8CC", bgDark: "#10222A", fgLight: "#1B6280", bgLight: "#E4F2F7"),
    ]

    /// Two-character monogram shown when the provider's app icon is unavailable.
    static func mark(for toolID: String) -> String {
        if let brand = brands[toolID] { return brand.mark }
        let letters = toolID.split(whereSeparator: { !$0.isLetter })
        if let first = letters.first {
            let head = first.prefix(1).uppercased()
            if letters.count > 1, let second = letters.dropFirst().first {
                return head + second.prefix(1).lowercased()
            }
            return head + first.dropFirst().prefix(1).lowercased()
        }
        return "??"
    }

    /// Human-readable provider name, used as the tile's accessibility label.
    static func label(for toolID: String) -> String {
        brands[toolID]?.label ?? toolID
    }

    static func tileForeground(for toolID: String) -> Color {
        guard let brand = brands[toolID] else { return HubTheme.textMid }
        return dynamic(dark: brand.fgDark, light: brand.fgLight)
    }

    static func tileBackground(for toolID: String) -> Color {
        guard let brand = brands[toolID] else { return HubTheme.raised }
        return dynamic(dark: brand.bgDark, light: brand.bgLight)
    }

    private static func dynamic(dark: String, light: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return HubTheme.nsColor(hex: isDark ? dark : light)
        })
    }

    static func color(for toolID: String) -> Color {
        map[toolID]?.color ?? HubTheme.accent
    }

    static func icon(for toolID: String) -> String {
        map[toolID]?.icon ?? "app.fill"
    }

    // Returns the real app icon if the .app bundle is installed.
    // Uses Bundle to read CFBundleIconFile directly — more reliable than NSWorkspace.
    private static var imageCache: [String: NSImage] = [:]
    private static var missingIconIDs: Set<String> = []

    static func appImage(for toolID: String) -> NSImage? {
        if missingIconIDs.contains(toolID) { return nil }
        if let cached = imageCache[toolID] { return cached }
        guard let img = loadAppImage(for: toolID) else {
            missingIconIDs.insert(toolID)
            return nil
        }
        imageCache[toolID] = img
        return img
    }

    private static func loadAppImage(for toolID: String) -> NSImage? {
        let familyIcon = ProviderFamily.iconToolID(for: ProviderFamily.groupID(for: toolID))
        if let bundled = bundledIcon(named: toolID) ?? bundledIcon(named: familyIcon) {
            return bundled
        }
        let candidates: [String: [String]] = [
            "claude-desktop": ["/Applications/Claude.app"],
            "claude-code":    ["/Applications/Claude.app"],   // same icon as Desktop
            "cursor":         ["/Applications/Cursor.app",
                               NSString("~/Applications/Cursor.app").expandingTildeInPath],
            "vscode":         ["/Applications/Visual Studio Code.app",
                               "/Applications/VSCode.app"],
            "codex":          ["/Applications/Codex.app"],
            "windsurf":       ["/Applications/Windsurf.app"],
            "zed":            ["/Applications/Zed.app", "/Applications/Zed Preview.app"],
            "roo":            ["/Applications/Roo.app"],
            "continue":       ["/Applications/Continue.app"],
            "cline":          ["/Applications/Cline.app"],
            "opencode":       ["/Applications/OpenCode.app"],
            "gemini":         ["/Applications/Gemini.app",
                               "/Applications/Google Gemini.app"],
            "antigravity":    ["/Applications/Antigravity.app"],
            "pi":             ["/Applications/Pi.app"],
            "command-code":   ["/Applications/Command Code.app"],
            "grok":           ["/Applications/Grok.app"],
        ]
        guard let paths = candidates[toolID] else { return nil }
        let fm = FileManager.default
        for path in paths {
            guard fm.fileExists(atPath: path) else { continue }
            // Read icon directly from bundle — avoids NSWorkspace permission issues
            if let bundle = Bundle(path: path),
               let iconName = bundle.infoDictionary?["CFBundleIconFile"] as? String,
               let resourcePath = bundle.resourcePath {
                let icns = iconName.hasSuffix(".icns") ? iconName : "\(iconName).icns"
                if let img = NSImage(contentsOfFile: "\(resourcePath)/\(icns)") {
                    img.size = NSSize(width: 36, height: 36)
                    return img
                }
                // Some bundles store without extension
                if let img = NSImage(contentsOfFile: "\(resourcePath)/\(iconName)") {
                    img.size = NSSize(width: 36, height: 36)
                    return img
                }
            }
            // Fallback to NSWorkspace (still works for most apps)
            return NSWorkspace.shared.icon(forFile: path)
        }
        return nil
    }

    private static func bundledIcon(named id: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: id, withExtension: "png", subdirectory: "Providers"),
              let img = NSImage(contentsOf: url) else { return nil }
        img.size = NSSize(width: 36, height: 36)
        return img
    }
}
