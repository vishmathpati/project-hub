import SwiftUI
import AppKit

// MARK: - Entry point

@main
struct ProjectHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu-bar-only app — Settings scene prevents "no scenes" crash.
        Settings { EmptyView() }
    }
}

// MARK: - App delegate (manages status item + popover)

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem:   NSStatusItem!
    private var popover:      NSPopover!
    private let projectStore  = ProjectStore()
    private let skillStore    = SkillStore()
    private let agentStore    = AgentStore()
    private let mcpStore      = MCPStore()

    // Live Mode state (tracks menu item title)
    private var liveModeEnabled: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setDockIcon()
        setupStatusItem()
        setupPopover()

        // First-launch welcome
        if !UserDefaults.standard.bool(forKey: "projecthub.didShowWelcome") {
            UserDefaults.standard.set(true, forKey: "projecthub.didShowWelcome")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                self?.togglePopover()
            }
        }

        // Live Mode close notification (panel X button)
        NotificationCenter.default.addObserver(
            forName: .projecthubLiveModeDidClose,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.liveModeEnabled = false
            }
        }

        // Close popover notification
        NotificationCenter.default.addObserver(
            forName: .projecthubClosePopover,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.popover.performClose(nil)
            }
        }

        // Expand to window notification
        NotificationCenter.default.addObserver(
            forName: .projecthubExpandWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.popover.performClose(nil)
                DashboardWindow.shared.open(
                    projectStore: self.projectStore,
                    skillStore:   self.skillStore,
                    agentStore:   self.agentStore,
                    mcpStore:     self.mcpStore
                )
            }
        }
    }

    // Dock icon click → toggle popover
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        togglePopover()
        return true
    }

    // MARK: - Dock icon

    private func setDockIcon() {
        let size: CGFloat = 512
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()

        // Deep blue-teal gradient background
        let bg = NSBezierPath(
            roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
            xRadius: 115, yRadius: 115
        )
        if let gradient = NSGradient(colors: [
            NSColor(red: 0.04, green: 0.12, blue: 0.22, alpha: 1),
            NSColor(red: 0.08, green: 0.24, blue: 0.36, alpha: 1)
        ]) {
            gradient.draw(in: bg, angle: 315)
        } else {
            NSColor(red: 0.06, green: 0.18, blue: 0.28, alpha: 1).setFill()
            bg.fill()
        }

        // SF Symbol: square.stack.3d.up.fill in cyan
        let symCfg = NSImage.SymbolConfiguration(pointSize: 260, weight: .bold)
        if let sym = NSImage(systemSymbolName: "square.stack.3d.up.fill",
                             accessibilityDescription: nil)?
            .withSymbolConfiguration(symCfg) {
            let tinted = sym.copy() as! NSImage
            tinted.lockFocus()
            NSColor.cyan.set()
            NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
            tinted.unlockFocus()

            let bw = tinted.size.width, bh = tinted.size.height
            tinted.draw(in: NSRect(x: (size - bw) / 2, y: (size - bh) / 2,
                                   width: bw, height: bh))
        }

        img.unlockFocus()
        NSApp.applicationIconImage = img
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        let img = NSImage(systemSymbolName: "square.stack.3d.up.fill",
                          accessibilityDescription: "Project Hub")
        img?.isTemplate = true
        button.image = img
        button.imagePosition = .imageLeft
        button.action = #selector(handleClick)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func handleClick(sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 480, height: 680)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView()
                .environmentObject(projectStore)
                .environmentObject(skillStore)
                .environmentObject(agentStore)
                .environmentObject(mcpStore)
        )
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            guard let button = statusItem.button else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            // Refresh on each open
            projectStore.scan()
            skillStore.refresh()
        }
    }

    // MARK: - Right-click context menu

    private func showContextMenu() {
        let menu = NSMenu()

        let header = NSMenuItem(title: "Project Hub \(AppActions.currentVersion)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: "Refresh",            action: #selector(refreshFromMenu),     keyEquivalent: "r")
        menu.addItem(NSMenuItem.separator())

        // Live Mode toggle
        let liveModeTitle = liveModeEnabled ? "Hide Live Mode" : "Show Live Mode"
        let liveItem = NSMenuItem(title: liveModeTitle, action: #selector(toggleLiveMode), keyEquivalent: "l")
        liveItem.state = liveModeEnabled ? .on : .off
        menu.addItem(liveItem)
        menu.addItem(NSMenuItem.separator())

        let loginItem = NSMenuItem(title: "Launch at login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.state = AppActions.launchAtLoginEnabled ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: "About Project Hub", action: #selector(aboutFromMenu),    keyEquivalent: "")
        menu.addItem(withTitle: "Visit GitHub",      action: #selector(openRepoFromMenu), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Project Hub",  action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        menu.items.forEach { if $0.action != nil { $0.target = self } }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func refreshFromMenu() {
        projectStore.scan()
        skillStore.refresh()
    }
    @objc private func aboutFromMenu()          { AppActions.about() }
    @objc private func openRepoFromMenu()       { AppActions.openRepo() }
    @objc private func toggleLaunchAtLogin()    { AppActions.launchAtLoginEnabled.toggle() }

    @objc private func toggleLiveMode() {
        liveModeEnabled.toggle()
        LiveModeWindow.shared.toggle(skillStore: skillStore, mcpStore: mcpStore)
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let projecthubClosePopover = Notification.Name("com.projecthub.closePopover")
}
