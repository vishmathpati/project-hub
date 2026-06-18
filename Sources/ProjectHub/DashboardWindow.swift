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
        w.minSize = NSSize(width: 900, height: 620)
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        w.collectionBehavior.insert(.fullScreenPrimary)
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }

    var isOpen: Bool { window?.isVisible ?? false }

    private static func initialFrame() -> NSRect {
        let fallback = NSRect(x: 120, y: 120, width: 1180, height: 760)
        guard let visible = NSScreen.main?.visibleFrame else { return fallback }
        let maxWidth = max(900, visible.width - 48)
        let maxHeight = max(620, visible.height - 48)
        let width = min(min(max(980, visible.width * 0.72), 1280), maxWidth)
        let height = min(min(max(660, visible.height * 0.78), 840), maxHeight)
        let origin = NSPoint(
            x: visible.midX - width / 2,
            y: visible.midY - height / 2
        )
        return NSRect(origin: origin, size: NSSize(width: width, height: height))
    }
}

// MARK: - Notification

extension Notification.Name {
    static let projecthubExpandWindow = Notification.Name("com.projecthub.expandWindow")
}
