import SwiftUI
import AppKit

// MARK: - Resizable dashboard window
//
// Singleton. Opens a standalone NSWindow (900×700, resizable) showing the same
// ContentView that lives in the popover but with room to breathe.
// Calling open() when the window is already visible just brings it to front.

@MainActor
final class DashboardWindow {

    static let shared = DashboardWindow()
    private var window: NSWindow?
    private init() {}

    func open(projectStore: ProjectStore, skillStore: SkillStore, agentStore: AgentStore) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let content = ContentView()
            .environmentObject(projectStore)
            .environmentObject(skillStore)
            .environmentObject(agentStore)

        let hc = NSHostingController(rootView: AnyView(content))
        let w = NSWindow(contentViewController: hc)
        w.title = "Project Hub"
        w.setContentSize(NSSize(width: 900, height: 700))
        w.minSize = NSSize(width: 580, height: 500)
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        w.isReleasedWhenClosed = false
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }

    var isOpen: Bool { window?.isVisible ?? false }
}

// MARK: - Notification

extension Notification.Name {
    static let projecthubExpandWindow = Notification.Name("com.projecthub.expandWindow")
}
