import AppKit
import SwiftUI

// MARK: - Custom NSPanel that intercepts mouse events at the window level.
// With backgroundColor = .clear + isOpaque = false, macOS skips transparent
// pixels during hit-testing, so NSView-level overrides (acceptsFirstMouse,
// addSubview overlay, etc.) never fire.  sendEvent() runs BEFORE the
// transparency check, making it the only reliable way to catch clicks on a
// clear-background borderless panel.

private final class BeaconPanel: NSPanel {

    var onTap:       (() -> Void)?
    var onDragEnded: ((NSPoint) -> Void)?

    private var dragOrigin: NSPoint?
    private var didDrag     = false
    private let threshold: CGFloat = 5

    override var canBecomeKey:  Bool { false }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {

        case .leftMouseDown:
            dragOrigin = NSEvent.mouseLocation
            didDrag    = false
            // Don't forward — we own all left-mouse events

        case .leftMouseDragged:
            guard let origin = dragOrigin else { return }
            let loc = NSEvent.mouseLocation
            if !didDrag &&
               (abs(loc.x - origin.x) > threshold || abs(loc.y - origin.y) > threshold) {
                didDrag = true
            }
            if didDrag {
                setFrameOrigin(NSPoint(
                    x: frame.origin.x + event.deltaX,
                    y: frame.origin.y - event.deltaY
                ))
            }

        case .leftMouseUp:
            let wasDrag = didDrag
            dragOrigin  = nil
            didDrag     = false
            if wasDrag { onDragEnded?(frame.origin) }
            else        { onTap?() }

        case .rightMouseUp:
            // Show context menu via AppKit directly (no view needed)
            let menu = NSMenu()
            let item = NSMenuItem(title: "Close Live Mode",
                                  action: #selector(closeLiveModeFromMenu),
                                  keyEquivalent: "")
            item.target = self
            menu.addItem(item)
            // Pop menu at current mouse location
            if let screen = NSScreen.main {
                let loc  = NSEvent.mouseLocation
                let flip = NSPoint(x: loc.x, y: screen.frame.height - loc.y)
                menu.popUp(positioning: nil,
                           at: NSPoint(x: frame.origin.x + event.locationInWindow.x,
                                       y: frame.origin.y + event.locationInWindow.y),
                           in: contentView)
            }

        default:
            super.sendEvent(event)
        }
    }

    @objc private func closeLiveModeFromMenu() {
        NotificationCenter.default.post(name: .projecthubLiveModeClose, object: nil)
    }
}

// MARK: - State shared between dot + sidebar

@MainActor
final class LiveModeState: ObservableObject {
    @Published var usedFraction: Double = 0
    @Published var sidebarOpen: Bool = false
}

// MARK: - Floating dot + optional sidebar manager

@MainActor
final class LiveModeWindow {

    static let shared = LiveModeWindow()

    private var dotPanel:     BeaconPanel?
    private var sidebarPanel: NSPanel?
    private var watcher:      ProjectWatcher?
    private let state         = LiveModeState()
    private var snapshotTimer: Timer?

    private var isOpen: Bool { dotPanel != nil }

    private static let savedPositionKey = "projecthub.liveMode.dotOrigin"

    // MARK: - Toggle (called from App menu)

    func toggle(skillStore: SkillStore, mcpStore: MCPStore) {
        if isOpen { close() } else { open(skillStore: skillStore, mcpStore: mcpStore) }
    }

    var isActive: Bool { isOpen }

    // MARK: - Open

    func open(skillStore: SkillStore, mcpStore: MCPStore) {
        guard !isOpen else { return }

        let watcher = ProjectWatcher()
        self.watcher = watcher

        // Observe close notification (right-click → Close Live Mode)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloseNotification),
            name: .projecthubLiveModeClose,
            object: nil
        )

        // Build the dot panel
        dotPanel = makeDotPanel(watcher: watcher, skillStore: skillStore, mcpStore: mcpStore)
        dotPanel?.orderFrontRegardless()

        watcher.start()

        // Kick off snapshot refresh timer
        startSnapshotTimer(skillStore: skillStore, mcpStore: mcpStore)
    }

    // MARK: - Close

    func close() {
        snapshotTimer?.invalidate()
        snapshotTimer = nil

        NotificationCenter.default.removeObserver(self, name: .projecthubLiveModeClose, object: nil)

        closeSidebar()
        dotPanel?.close()
        dotPanel = nil

        watcher?.stop()
        watcher = nil

        state.sidebarOpen  = false
        state.usedFraction = 0

        NotificationCenter.default.post(name: .projecthubLiveModeDidClose, object: nil)
    }

    @objc private func handleCloseNotification() { close() }

    // MARK: - Dot panel

    private func makeDotPanel(watcher: ProjectWatcher, skillStore: SkillStore, mcpStore: MCPStore) -> BeaconPanel {
        let size: CGFloat = 52

        // BeaconPanel owns all mouse handling at the window level — no view subclass needed.
        let panel = BeaconPanel(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        panel.level              = .floating
        panel.isFloatingPanel    = true
        panel.hidesOnDeactivate  = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        // 0.01 alpha = invisible BUT non-zero → macOS routes events to this window.
        // .clear (alpha=0) causes macOS to skip event delivery entirely.
        panel.backgroundColor    = NSColor.black.withAlphaComponent(0.01)
        panel.isOpaque           = false
        panel.hasShadow          = false

        panel.setFrameOrigin(savedOrDefaultOrigin(size: size))

        // Wire callbacks
        panel.onTap = { [weak self, weak panel] in
            guard let self, let panel else { return }
            self.handleDotTap(dotPanel: panel, skillStore: skillStore, mcpStore: mcpStore)
        }
        panel.onDragEnded = { [weak self, weak panel] origin in
            UserDefaults.standard.set(NSStringFromPoint(origin),
                                      forKey: LiveModeWindow.savedPositionKey)
            Task { @MainActor [weak self, weak panel] in
                guard let self, let panel else { return }
                if let sidebar = self.sidebarPanel {
                    self.positionSidebar(sidebar, relativeTo: panel)
                }
            }
        }

        // SwiftUI content — purely visual, no hit testing required
        panel.contentViewController = NSHostingController(
            rootView: BeaconHostView(watcher: watcher, state: state)
        )

        return panel
    }

    private func handleDotTap(dotPanel: NSPanel, skillStore: SkillStore, mcpStore: MCPStore) {
        if state.sidebarOpen {
            closeSidebar()
        } else {
            openSidebar(dotPanel: dotPanel, skillStore: skillStore, mcpStore: mcpStore)
        }
    }

    // MARK: - Sidebar panel

    private func openSidebar(dotPanel: NSPanel, skillStore: SkillStore, mcpStore: MCPStore) {
        guard let w = watcher else { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 500),
            styleMask:   [.titled, .closable, .resizable, .nonactivatingPanel, .hudWindow],
            backing:     .buffered,
            defer:       false
        )
        panel.title              = "Live Mode"
        panel.level              = .floating
        panel.isFloatingPanel    = true
        panel.hidesOnDeactivate  = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentMinSize     = NSSize(width: 260, height: 320)

        panel.contentViewController = NSHostingController(
            rootView: LiveModeView(watcher: w, skillStore: skillStore, mcpStore: mcpStore)
        )

        positionSidebar(panel, relativeTo: dotPanel)
        panel.orderFrontRegardless()

        // Track close via red X button
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sidebarWillClose(_:)),
            name:     NSWindow.willCloseNotification,
            object:   panel
        )

        sidebarPanel      = panel
        state.sidebarOpen = true
    }

    private func closeSidebar() {
        sidebarPanel?.close()
        sidebarPanel      = nil
        state.sidebarOpen = false
    }

    @objc private func sidebarWillClose(_ note: Notification) {
        guard (note.object as? NSPanel) === sidebarPanel else { return }
        sidebarPanel      = nil
        state.sidebarOpen = false
    }

    // MARK: - Sidebar positioning

    private func positionSidebar(_ sidebar: NSPanel, relativeTo dot: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let sf     = screen.visibleFrame
        let dFrame = dot.frame
        let sSize  = sidebar.frame.size
        let gap: CGFloat = 10

        // Left or right of the dot?
        let x: CGFloat
        if dFrame.midX > sf.midX {
            x = dFrame.minX - sSize.width - gap   // dot on right → sidebar left
        } else {
            x = dFrame.maxX + gap                 // dot on left → sidebar right
        }

        // Align tops, clamped to screen
        let y = min(dFrame.maxY - sSize.height,
                    sf.maxY - sSize.height - gap)
        let clampedY = max(sf.minY + gap, y)

        sidebar.setFrameOrigin(CGPoint(x: x, y: clampedY))
    }

    // MARK: - Snapshot refresh (updates beacon ring)

    private func startSnapshotTimer(skillStore: SkillStore, mcpStore: MCPStore) {
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshSnapshot() }
        }
        refreshSnapshot()
    }

    private func refreshSnapshot() {
        guard let proj = watcher?.activeProject else {
            state.usedFraction = 0
            return
        }
        Task.detached(priority: .background) { [weak self] in
            let snap = ContextEstimator.estimate(for: proj.path)
            await MainActor.run {
                self?.state.usedFraction = snap.usedFraction
            }
        }
    }

    // MARK: - Saved position

    private func savedOrDefaultOrigin(size: CGFloat) -> CGPoint {
        let raw = UserDefaults.standard.string(forKey: Self.savedPositionKey) ?? ""
        let pt  = NSPointFromString(raw)
        if pt != .zero, NSScreen.screens.contains(where: { $0.frame.contains(pt) }) {
            return pt
        }
        // Default: bottom-right, 80pt above dock
        let sf = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return CGPoint(x: sf.maxX - size - 20, y: sf.minY + 80)
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let projecthubLiveModeDidClose = Notification.Name("com.projecthub.liveModeDidClose")
    // projecthubExpandWindow is defined in DashboardWindow.swift
}
