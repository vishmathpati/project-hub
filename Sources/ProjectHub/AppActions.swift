import AppKit
import Foundation
import ServiceManagement

// MARK: - Central place for app-level actions

@MainActor
enum AppActions {

    // MARK: - Launch at login (macOS 13+, SMAppService)

    static var launchAtLoginEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    if SMAppService.mainApp.status == .enabled { return }
                    try SMAppService.mainApp.register()
                } else {
                    if SMAppService.mainApp.status != .enabled { return }
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                let alert = NSAlert()
                alert.messageText = newValue
                    ? "Couldn't enable launch at login"
                    : "Couldn't disable launch at login"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
        }
    }

    // MARK: - Version + URLs

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    // Stub — update when the repo is created
    static let repoURL = URL(string: "https://github.com/vishmathpati/projecthub")!

    // MARK: - Actions

    static func quit()     { NSApp.terminate(nil) }
    static func openRepo() { NSWorkspace.shared.open(repoURL) }

    static func about() {
        let alert = NSAlert()
        alert.messageText = "Project Hub"
        alert.informativeText = """
        Version \(currentVersion)

        Manage AI coding tools across all your projects — skills, agents, and MCP servers — from one menu bar app.

        github.com/vishmathpati/projecthub
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open GitHub")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn { openRepo() }
    }

    // MARK: - Open in Finder / Terminal

    static func openInFinder(_ path: String) {
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url.deletingLastPathComponent()])
        }
    }

    static func openInTerminal(_ path: String) {
        // Try Warp first, then Terminal
        let warp = URL(fileURLWithPath: "/Applications/Warp.app")
        let term = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        let app  = FileManager.default.fileExists(atPath: warp.path) ? warp : term

        NSWorkspace.shared.open(
            [URL(fileURLWithPath: path)],
            withApplicationAt: app,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}
