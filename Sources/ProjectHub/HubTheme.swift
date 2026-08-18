import SwiftUI
import AppKit

enum HubTheme {
    static let sidebarWidth: CGFloat = 216
    static let radius: CGFloat = 10

    static var page: Color { Color(NSColor.windowBackgroundColor) }
    static var sidebar: Color { Color(NSColor.controlBackgroundColor).opacity(0.72) }
    static var card: Color { Color(NSColor.controlBackgroundColor) }
    static var hairline: Color { Color(NSColor.separatorColor).opacity(0.32) }
}

extension View {
    func hubCard() -> some View {
        self
            .background(HubTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: HubTheme.radius))
            .overlay(
                RoundedRectangle(cornerRadius: HubTheme.radius)
                    .stroke(HubTheme.hairline, lineWidth: 0.5)
            )
    }
}
