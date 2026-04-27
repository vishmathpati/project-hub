import AppKit
import SwiftUI

// MARK: - Singleton floating panel that lives above Claude Code

@MainActor
final class LiveModeWindow {

    static let shared = LiveModeWindow()

    private var panel: NSPanel?
    private var watcher: ProjectWatcher?
    private var isVisible = false

    // MARK: - Toggle (called from menu)

    func toggle(skillStore: SkillStore, mcpStore: MCPStore) {
        if isVisible {
            close()
        } else {
            open(skillStore: skillStore, mcpStore: mcpStore)
        }
    }

    var isOpen: Bool { isVisible }

    // MARK: - Open

    func open(skillStore: SkillStore, mcpStore: MCPStore) {
        guard !isVisible else { return }

        // Create panel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 520),
            styleMask: [
                .titled,
                .closable,
                .resizable,
                .nonactivatingPanel,
                .hudWindow,
            ],
            backing: .buffered,
            defer: false
        )
        panel.title = "Live Mode"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
        panel.titlebarAppearsTransparent = false
        panel.titleVisibility = .visible
        panel.isOpaque = false
        panel.hasShadow = true

        // Start watcher
        let watcher = ProjectWatcher()
        self.watcher = watcher

        // Build SwiftUI root view
        let rootView = LiveModeView(watcher: watcher, skillStore: skillStore, mcpStore: mcpStore)
            .frame(minWidth: 280, minHeight: 380)

        panel.contentViewController = NSHostingController(rootView: rootView)
        panel.contentMinSize = NSSize(width: 280, height: 380)

        // Position: bottom-right of screen with 20pt margin
        positionPanel(panel)

        panel.orderFrontRegardless()
        self.panel = panel
        self.isVisible = true

        // Listen for close notification (red X button)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelWillClose),
            name: NSWindow.willCloseNotification,
            object: panel
        )

        watcher.start()
    }

    // MARK: - Close

    func close() {
        guard isVisible else { return }
        watcher?.stop()
        watcher = nil
        panel?.close()
        panel = nil
        isVisible = false
    }

    @objc private func panelWillClose(_ notification: Notification) {
        guard let closedPanel = notification.object as? NSPanel,
              closedPanel === panel else { return }
        watcher?.stop()
        watcher = nil
        panel = nil
        isVisible = false
        NotificationCenter.default.post(name: .projecthubLiveModeDidClose, object: nil)
    }

    // MARK: - Position

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize   = panel.frame.size
        let margin: CGFloat = 20
        let origin = CGPoint(
            x: screenFrame.maxX - panelSize.width  - margin,
            y: screenFrame.minY + margin
        )
        panel.setFrameOrigin(origin)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let projecthubLiveModeDidClose = Notification.Name("com.projecthub.liveModeDidClose")
}
