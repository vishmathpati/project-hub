import Foundation
import AppKit

// MARK: - Watched project snapshot

struct WatchedProject: Equatable {
    let path: String   // absolute path, e.g. /Users/vish/Arel OS/Projects/active/foo
    let name: String   // last path component, e.g. foo
}

// MARK: - Project watcher

/// Detects which Claude Code project was most recently active.
/// Strategy: find the most-recently-modified `.jsonl` conversation file across
/// all `~/.claude/projects/<dir>/` subdirectories.  Every message appended in
/// Claude Code updates the active session file's mtime, making this a reliable
/// signal even when Claude Code merely switches projects in the sidebar.
@MainActor
final class ProjectWatcher: ObservableObject {

    // MARK: Published

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

    /// dirName → absolute path, loaded from ~/.claude.json
    private var knownPaths: [String: String] = [:]
    private var lastKnownPathsMtime: Date = .distantPast

    // MARK: - Lifecycle

    func start() {
        loadKnownPaths()
        checkFrontApp()

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication else { return }
            let isClaude = app.bundleIdentifier == ProjectWatcher.claudeBundleID
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.claudeIsFront = isClaude
            }
        }

        // Always poll — we want to track the active project regardless of focus
        startPolling()
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

    private func checkFrontApp() {
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        claudeIsFront = bundleID == ProjectWatcher.claudeBundleID
    }

    // MARK: - Core detection: find most recently modified .jsonl

    private func pollActiveProject() {
        let fm = FileManager.default
        let projectsRoot = ProjectWatcher.projectsDir

        guard let projectDirs = try? fm.contentsOfDirectory(atPath: projectsRoot) else {
            activeProject = nil
            return
        }

        reloadKnownPathsIfNeeded()

        var bestMtime: Date = .distantPast
        var bestDirName: String? = nil

        for dirName in projectDirs {
            // Skip worktree entries
            if dirName.contains("-claude-worktrees-") { continue }

            let dirPath = (projectsRoot as NSString).appendingPathComponent(dirName)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dirPath, isDirectory: &isDir), isDir.boolValue else { continue }

            // Find the most-recently modified .jsonl file in this project dir
            guard let files = try? fm.contentsOfDirectory(atPath: dirPath) else { continue }
            for file in files {
                guard file.hasSuffix(".jsonl") else { continue }
                let filePath = (dirPath as NSString).appendingPathComponent(file)
                guard let attrs  = try? fm.attributesOfItem(atPath: filePath),
                      let mtime  = attrs[.modificationDate] as? Date else { continue }
                if mtime > bestMtime {
                    bestMtime    = mtime
                    bestDirName  = dirName
                }
            }
        }

        guard let dirName = bestDirName else {
            activeProject = nil
            return
        }

        let absolutePath = resolveProjectPath(dirName: dirName)
        let name         = (absolutePath as NSString).lastPathComponent
        let project      = WatchedProject(path: absolutePath, name: name)
        if project != activeProject { activeProject = project }
    }

    // MARK: - Path resolution

    private func resolveProjectPath(dirName: String) -> String {
        // Cache hit from ~/.claude.json (most reliable)
        if let known = knownPaths[dirName] { return known }

        // Fallback: try to reverse the encoding for simple paths
        // Encoding rule: every '/', ' ', '.' in the original path → '-'
        // We can reconstruct by replacing leading/segment '-' back to '/',
        // but it's ambiguous for paths with hyphens/spaces. Best effort:
        let candidate = "/" + dirName.dropFirst()  // drop leading '-', prepend '/'
            .replacingOccurrences(of: "-", with: "/")
        if FileManager.default.fileExists(atPath: candidate) { return candidate }

        // Last resort
        return NSHomeDirectory() + "/" + dirName
    }

    // MARK: - Known paths cache

    /// Claude Code path encoding: '/', ' ', and '.' each become '-'.
    private static func encodePath(_ absolutePath: String) -> String {
        absolutePath
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ".", with: "-")
    }

    private func loadKnownPaths() {
        guard let data = FileManager.default.contents(atPath: ProjectWatcher.claudeJsonPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projects = json["projects"] as? [String: Any]
        else { return }

        var mapping: [String: String] = [:]
        for absolutePath in projects.keys {
            let dirName = ProjectWatcher.encodePath(absolutePath)
            mapping[dirName] = absolutePath
        }
        knownPaths = mapping

        if let attrs = try? FileManager.default.attributesOfItem(
            atPath: ProjectWatcher.claudeJsonPath),
           let mtime = attrs[.modificationDate] as? Date {
            lastKnownPathsMtime = mtime
        }
    }

    private func reloadKnownPathsIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(
            atPath: ProjectWatcher.claudeJsonPath),
              let mtime = attrs[.modificationDate] as? Date,
              mtime > lastKnownPathsMtime
        else { return }
        loadKnownPaths()
    }
}
