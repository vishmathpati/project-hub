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
            if NSApp.isActive == false {
                NSApp.activate(ignoringOtherApps: true)
            }
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
        w.minSize = NSSize(width: HubTheme.minWindowWidth, height: HubTheme.minWindowHeight)
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        w.collectionBehavior.insert(.fullScreenPrimary)
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
        if NSApp.isActive == false {
            NSApp.activate(ignoringOtherApps: true)
        }
        window = w
    }

    var isOpen: Bool { window?.isVisible ?? false }

    private static func initialFrame() -> NSRect {
        // Design target is 1240 × 820, minimum 1100 × 720 (DESIGN.md §5.1).
        let fallback = NSRect(x: 120, y: 120, width: HubTheme.idealWindowWidth, height: HubTheme.idealWindowHeight)
        guard let visible = NSScreen.main?.visibleFrame else { return fallback }
        let maxWidth = max(HubTheme.minWindowWidth, visible.width - 48)
        let maxHeight = max(HubTheme.minWindowHeight, visible.height - 48)
        let width = min(min(max(HubTheme.minWindowWidth, visible.width * 0.72), HubTheme.idealWindowWidth), maxWidth)
        let height = min(min(max(HubTheme.minWindowHeight, visible.height * 0.78), HubTheme.idealWindowHeight), maxHeight)
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
