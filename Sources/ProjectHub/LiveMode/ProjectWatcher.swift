import Foundation
import AppKit

// MARK: - Watched project snapshot

struct WatchedProject: Equatable {
    let path: String   // absolute path, e.g. /Users/vish/Arel OS/Projects/active/foo
    let name: String   // last path component, e.g. foo
}

// MARK: - Project watcher

/// Detects which Claude Code project was most recently active.
///
/// Two-strategy detection:
///
/// **Strategy A – JSONL mtime** (primary)
///   Finds the most-recently modified `.jsonl` conversation file across all
///   `~/.claude/projects/<dir>/` subdirectories.  Works for both CLI sessions
///   and Desktop sessions where the user is actively sending messages.
///
/// **Strategy B – Desktop process cwd** (path-resolution + fallback)
///   The Claude Code Desktop app spawns one `claude` CLI subprocess per open
///   tab, each running with the project directory as its working directory.
///   We enumerate those cwds via `lsof` and maintain an `encodedPath →
///   absolutePath` cache.  This cache is used in two ways:
///     1. **Path resolution fix**: resolves ambiguous dir names like
///        `-Users-foo-Arel-OS-bar` → `/Users/foo/Arel OS/bar` (spaces and
///        dots both encode as `-`, making the reverse mapping ambiguous;
///        process cwds are unambiguous).
///     2. **Fallback**: if no recent JSONL exists, show the project whose
///        tab is currently open in the Desktop app.
@MainActor
final class ProjectWatcher: ObservableObject {

    // MARK: Published

    @Published private(set) var claudeIsFront: Bool = false
    @Published private(set) var activeProject: WatchedProject? = nil

    /// All projects currently open as tabs in Claude Code Desktop.
    /// Derived from running claude process cwds. Updated every ~10 s.
    @Published private(set) var openProjects: [WatchedProject] = []

    // MARK: Private

    private var workspaceObserver: Any?
    private var pollTimer: Timer?

    nonisolated static let claudeBundleID = "com.anthropic.claudefordesktop"

    nonisolated private static let projectsDir: String = {
        (NSHomeDirectory() as NSString).appendingPathComponent(".claude/projects")
    }()
    nonisolated private static let claudeJsonPath: String = {
        (NSHomeDirectory() as NSString).appendingPathComponent(".claude.json")
    }()

    /// dirName → absolute path, loaded from ~/.claude.json
    private var knownPaths: [String: String] = [:]
    private var lastKnownPathsMtime: Date = .distantPast

    /// encodedDirName → absolute path, scraped from running claude Desktop processes.
    /// Refreshed asynchronously every ~10 s.
    private var desktopCwdCache: [String: String] = [:]
    private var desktopCwdTask: Task<Void, Never>?
    private var pollCount = 0

    // MARK: - Lifecycle

    func start() {
        loadKnownPaths()
        checkFrontApp()
        refreshDesktopCwdCache()   // kick off first scan immediately

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
        desktopCwdTask?.cancel()
        desktopCwdTask = nil
        if let obs = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            workspaceObserver = nil
        }
    }

    // MARK: - Polling

    private func startPolling() {
        guard pollTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollActiveProject()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
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
        pollCount += 1
        if pollCount % 5 == 0 {
            refreshDesktopCwdCache()
        }

        let known = knownPaths
        let desktop = desktopCwdCache
        let lastMtime = lastKnownPathsMtime
        Task.detached(priority: .utility) { [weak self] in
            let refreshedKnown = Self.knownPathsIfStale(current: known, lastMtime: lastMtime)
            let mapping = refreshedKnown.mapping
            let found = Self.detectActiveProject(knownPaths: mapping, desktopCwdCache: desktop)
            await MainActor.run { [weak self] in
                guard let self else { return }
                if refreshedKnown.didReload {
                    self.knownPaths = mapping
                    self.lastKnownPathsMtime = refreshedKnown.mtime
                }
                if found != self.activeProject {
                    self.activeProject = found
                }
            }
        }
    }

    private struct KnownPathsReload {
        let mapping: [String: String]
        let mtime: Date
        let didReload: Bool
    }

    nonisolated private static func knownPathsIfStale(
        current: [String: String],
        lastMtime: Date
    ) -> KnownPathsReload {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: claudeJsonPath),
              let mtime = attrs[.modificationDate] as? Date,
              mtime > lastMtime
        else {
            return KnownPathsReload(mapping: current, mtime: lastMtime, didReload: false)
        }
        return KnownPathsReload(mapping: loadKnownPathMapping(), mtime: mtime, didReload: true)
    }

    nonisolated private static func loadKnownPathMapping() -> [String: String] {
        guard let data = FileManager.default.contents(atPath: claudeJsonPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projects = json["projects"] as? [String: Any]
        else { return [:] }

        var mapping: [String: String] = [:]
        for absolutePath in projects.keys {
            mapping[encodePath(absolutePath)] = absolutePath
        }
        return mapping
    }

    nonisolated private static func detectActiveProject(
        knownPaths: [String: String],
        desktopCwdCache: [String: String]
    ) -> WatchedProject? {
        let fm = FileManager.default
        let projectsRoot = projectsDir

        guard let projectDirs = try? fm.contentsOfDirectory(atPath: projectsRoot) else {
            return bestDesktopProject(desktopCwdCache: desktopCwdCache)
        }

        var bestMtime: Date = .distantPast
        var bestDirName: String? = nil

        for dirName in projectDirs {
            if dirName.contains("-claude-worktrees-") { continue }

            let dirPath = (projectsRoot as NSString).appendingPathComponent(dirName)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dirPath, isDirectory: &isDir), isDir.boolValue else { continue }

            guard let files = try? fm.contentsOfDirectory(atPath: dirPath) else { continue }
            for file in files {
                guard file.hasSuffix(".jsonl") else { continue }
                let filePath = (dirPath as NSString).appendingPathComponent(file)
                guard let attrs = try? fm.attributesOfItem(atPath: filePath),
                      let mtime = attrs[.modificationDate] as? Date else { continue }
                if mtime > bestMtime {
                    bestMtime = mtime
                    bestDirName = dirName
                }
            }
        }

        guard let dirName = bestDirName else {
            return bestDesktopProject(desktopCwdCache: desktopCwdCache)
        }

        let absolutePath = resolveProjectPath(
            dirName: dirName,
            knownPaths: knownPaths,
            desktopCwdCache: desktopCwdCache
        )
        return WatchedProject(path: absolutePath, name: (absolutePath as NSString).lastPathComponent)
    }

    nonisolated private static func resolveProjectPath(
        dirName: String,
        knownPaths: [String: String],
        desktopCwdCache: [String: String]
    ) -> String {
        if let known = knownPaths[dirName] { return known }
        if let fromProcess = desktopCwdCache[dirName] { return fromProcess }
        let candidate = "/" + dirName.dropFirst()
            .replacingOccurrences(of: "-", with: "/")
        if FileManager.default.fileExists(atPath: candidate) { return candidate }
        return NSHomeDirectory() + "/" + dirName
    }

    nonisolated private static func bestDesktopProject(desktopCwdCache: [String: String]) -> WatchedProject? {
        let home = NSHomeDirectory()
        let cwds = desktopCwdCache.values.filter {
            $0 != "/" && $0 != home && $0.count > home.count + 2
        }
        guard let path = cwds.first else { return nil }
        return WatchedProject(path: path, name: (path as NSString).lastPathComponent)
    }

    /// Launches an async background task that runs `lsof` to scrape the cwds of
    /// all `claude` CLI processes spawned by Claude Code Desktop.
    private func refreshDesktopCwdCache() {
        desktopCwdTask?.cancel()
        desktopCwdTask = Task.detached(priority: .background) { [weak self] in
            let cache = await ProjectWatcher.scanDesktopCwds()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.desktopCwdCache = cache
                // Rebuild openProjects from the new cwd cache
                let home = NSHomeDirectory()
                self.openProjects = cache.values
                    .filter { $0 != "/" && $0 != home && $0.count > home.count + 2 }
                    .sorted()
                    .map { WatchedProject(path: $0, name: ($0 as NSString).lastPathComponent) }
            }
        }
    }

    /// Runs `lsof -F pn -d cwd -c claude` to collect cwds of all running claude
    /// processes, then returns a `[encodedDirName: absolutePath]` mapping.
    ///
    /// This is a `nonisolated static` so it can run on a background executor without
    /// touching actor-isolated state.
    private nonisolated static func scanDesktopCwds() async -> [String: String] {
        return await Task.detached(priority: .background) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
            // -F pn  : output fields: p=pid, n=name(path)
            // -d cwd : only the current-working-directory entry per process
            // -c claude : only processes whose command name contains "claude"
            task.arguments = ["-F", "pn", "-d", "cwd", "-c", "claude"]

            let outPipe = Pipe()
            let errPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError  = errPipe

            do { try task.run() } catch { return [:] }
            task.waitUntilExit()

            let output = String(
                data: outPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""

            // lsof -F output format:
            //   p<PID>
            //   n<path>
            // (one process block per process)
            var mapping: [String: String] = [:]
            var pendingPath: String? = nil

            for rawLine in output.components(separatedBy: "\n") {
                guard !rawLine.isEmpty else { continue }
                let indicator = rawLine.prefix(1)
                let value     = String(rawLine.dropFirst())

                switch indicator {
                case "n":
                    pendingPath = value
                    // A valid Desktop project cwd — must pass all of:
                    //   1. Under /Users/ (not /private/… or other roots)
                    //   2. Longer than the bare home dir
                    //   3. Actually a directory on disk (not a file like settings.json)
                    //   4. Last component doesn't start with '.' (skip .claude, .cursor, etc.)
                    //   5. Last component doesn't end with a config file extension
                    //   6. At least 2 path components below home (e.g., ~/Projects/foo, not ~/foo)
                    let home = NSHomeDirectory()
                    if let path = pendingPath,
                       path.hasPrefix("/Users/"),
                       path != home {

                        let name = (path as NSString).lastPathComponent
                        let isHidden    = name.hasPrefix(".")
                        let isConfigExt = name.hasSuffix(".json") || name.hasSuffix(".toml")
                                       || name.hasSuffix(".yaml") || name.hasSuffix(".plist")
                                       || name.hasSuffix(".lock")
                        // macOS container/system dirs — never real project paths
                        let isSystemPath = path.contains("/Library/")
                                        || path.contains("/Containers/")
                                        || path.contains("/Application Support/")
                        var isDir: ObjCBool = false
                        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
                        // Require ≥ 2 segments below home to avoid ~/SomeSingleDir noise
                        let extraPath = path.dropFirst(home.count)
                        let depth = extraPath.components(separatedBy: "/").filter { !$0.isEmpty }.count

                        if exists, isDir.boolValue, !isHidden, !isConfigExt, !isSystemPath, depth >= 2 {
                            let encoded = ProjectWatcher.encodePath(path)
                            mapping[encoded] = path
                        }
                    }
                default:
                    break
                }
            }

            return mapping
        }.value
    }

    // MARK: - Known paths cache

    /// Claude Code path encoding: '/', ' ', and '.' each become '-'.
    nonisolated static func encodePath(_ absolutePath: String) -> String {
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
}
