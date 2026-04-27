import Foundation
import AppKit
import Combine

// MARK: - Watched project snapshot

struct WatchedProject: Equatable {
    let path: String   // absolute path, e.g. /Users/vish/Arel OS/Projects/active/foo
    let name: String   // last path component, e.g. foo
}

// MARK: - Project watcher

/// Tracks whether Claude Code is frontmost and which project is active.
/// • Polls `~/.claude/projects/` every 2 s for most-recently-modified directory.
/// • Resolves dir name → absolute path via `~/.claude.json`.
/// • Published on MainActor so SwiftUI can bind directly.
@MainActor
final class ProjectWatcher: ObservableObject {

    // MARK: Published state

    @Published private(set) var claudeIsFront: Bool = false
    @Published private(set) var activeProject: WatchedProject? = nil

    // MARK: Private

    private var workspaceObserver: Any?
    private var pollTimer: Timer?

    nonisolated static let claudeBundleID = "com.anthropic.claudefordesktop"
    private static let projectsDir: String = {
        (NSHomeDirectory() as NSString).appendingPathComponent(".claude/projects")
    }()
    private static let claudeJsonPath: String = {
        (NSHomeDirectory() as NSString).appendingPathComponent(".claude.json")
    }()

    // Cache of known absolute paths: dirName → absolutePath
    private var knownPaths: [String: String] = [:]
    private var lastKnownPathsMtime: Date = .distantPast

    // MARK: - Start / Stop

    func start() {
        loadKnownPaths()
        checkFrontApp()

        // Workspace observer for frontmost app changes
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication else { return }
            let isClaude = app.bundleIdentifier == ProjectWatcher.claudeBundleID
            Task { @MainActor [weak self] in
                self?.claudeIsFront = isClaude
                if isClaude {
                    self?.startPolling()
                } else {
                    self?.stopPolling()
                }
            }
        }

        // Also start polling immediately if Claude is already front
        if claudeIsFront { startPolling() }
    }

    func stop() {
        stopPolling()
        if let obs = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            workspaceObserver = nil
        }
    }

    // MARK: - Polling

    private func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollActiveProject()
            }
        }
        pollActiveProject()
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Front app check (on launch)

    private func checkFrontApp() {
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let isClaude = bundleID == ProjectWatcher.claudeBundleID
        claudeIsFront = isClaude
        if isClaude { startPolling() }
    }

    // MARK: - Poll: find most-recently-touched project dir

    private func pollActiveProject() {
        let fm = FileManager.default
        let dir = ProjectWatcher.projectsDir

        guard let entries = try? fm.contentsOfDirectory(atPath: dir) else {
            activeProject = nil
            return
        }

        // Reload known paths if ~/.claude.json has changed
        reloadKnownPathsIfNeeded()

        // Find directory with most recent mtime, excluding worktrees
        var best: (mtime: Date, dirName: String)? = nil
        for entry in entries {
            // Skip worktree entries (contain "-claude-worktrees-")
            if entry.contains("-claude-worktrees-") { continue }
            let full = (dir as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else { continue }
            if let attrs = try? fm.attributesOfItem(atPath: full),
               let mtime = attrs[.modificationDate] as? Date {
                if best == nil || mtime > best!.mtime {
                    best = (mtime, entry)
                }
            }
        }

        guard let winner = best else {
            activeProject = nil
            return
        }

        // Resolve dir name → absolute path
        let absolutePath = resolveProjectPath(dirName: winner.dirName)
        let name = (absolutePath as NSString).lastPathComponent
        let project = WatchedProject(path: absolutePath, name: name)
        if project != activeProject { activeProject = project }
    }

    // MARK: - Path resolution

    /// Decode dir name (slashes→dashes) back to absolute path using ~/.claude.json.
    private func resolveProjectPath(dirName: String) -> String {
        // Check cache from ~/.claude.json first (exact match)
        if let known = knownPaths[dirName] { return known }

        // Fallback: naive decode — replace leading dash with slash, remaining dashes
        // that don't match spaces are ambiguous but we do best-effort
        // Strategy: try to match against real fs by converting dashes back to slashes
        // We decode by checking if a reconstructed path exists on disk.
        let candidate = naiveDecode(dirName)
        if FileManager.default.fileExists(atPath: candidate) { return candidate }

        // Last resort: return as-is prepended with home
        return (NSHomeDirectory() as NSString).appendingPathComponent(dirName)
    }

    /// Naive decode: replace `-` → `/`, then prefix with `/`.
    /// Works for most common cases; ambiguous when paths have real dashes.
    private func naiveDecode(_ dirName: String) -> String {
        // The naming convention: absolute path with each `/` replaced by `-`
        // So `/Users/vish/my-project` → `-Users-vish-my-project`
        // We reconstruct by replacing `-` with `/` then prefix `/`
        // But we skip spaces (preserved as-is in dir names)
        var result = dirName.replacingOccurrences(of: "-", with: "/")
        if !result.hasPrefix("/") { result = "/" + result }
        return result
    }

    // MARK: - Known paths cache

    private func loadKnownPaths() {
        guard let data = FileManager.default.contents(atPath: ProjectWatcher.claudeJsonPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projects = json["projects"] as? [String: Any]
        else { return }

        var mapping: [String: String] = [:]
        for absolutePath in projects.keys {
            let dirName = absolutePath.replacingOccurrences(of: "/", with: "-")
            mapping[dirName] = absolutePath
        }
        knownPaths = mapping

        if let attrs = try? FileManager.default.attributesOfItem(atPath: ProjectWatcher.claudeJsonPath),
           let mtime = attrs[.modificationDate] as? Date {
            lastKnownPathsMtime = mtime
        }
    }

    private func reloadKnownPathsIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: ProjectWatcher.claudeJsonPath),
              let mtime = attrs[.modificationDate] as? Date,
              mtime > lastKnownPathsMtime
        else { return }
        loadKnownPaths()
    }
}
