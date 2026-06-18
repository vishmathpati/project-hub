import SwiftUI
import AppKit

// MARK: - Primary desktop window
//
// Singleton. Opens a standalone NSWindow showing the same ContentView that
// lives in the compact popover, but sized as the default desktop experience.
// Calling open() when the window is already visible just brings it to front.

@MainActor
final class DashboardWindow {

    static let shared = DashboardWindow()
    private var window: NSWindow?
    private init() {}

    func open(projectStore: ProjectStore, skillStore: SkillStore, agentStore: AgentStore, mcpStore: MCPStore) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let content = ContentView(showsExpandButton: false)
            .environmentObject(projectStore)
            .environmentObject(skillStore)
            .environmentObject(agentStore)
            .environmentObject(mcpStore)

        let hc = NSHostingController(rootView: AnyView(content))
        let w = NSWindow(contentViewController: hc)
        w.title = "Project Hub"
        w.setFrame(Self.initialFrame(), display: true)
        w.minSize = NSSize(width: 580, height: 500)
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        w.collectionBehavior.insert(.fullScreenPrimary)
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }

    var isOpen: Bool { window?.isVisible ?? false }

    private static func initialFrame() -> NSRect {
        let fallback = NSRect(x: 80, y: 80, width: 1180, height: 780)
        guard let visible = NSScreen.main?.visibleFrame else { return fallback }
        let inset: CGFloat = 24
        let frame = visible.insetBy(dx: min(inset, visible.width * 0.03),
                                    dy: min(inset, visible.height * 0.03))
        guard frame.width >= 580, frame.height >= 500 else { return visible }
        return frame
    }
}

// MARK: - Notification

extension Notification.Name {
    static let projecthubExpandWindow = Notification.Name("com.projecthub.expandWindow")
}
