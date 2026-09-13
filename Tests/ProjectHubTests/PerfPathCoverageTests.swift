import XCTest
@testable import ProjectHub

/// Measures every user-facing path against the real home directory. The tests
/// always pass; the printed table is the artifact. Re-run to compare.
final class PerfPathCoverageTests: XCTestCase {

    private func now() -> Date { Date() }

    @discardableResult
    private func time(_ label: String, _ block: () -> Void) -> Double {
        let started = now()
        block()
        let elapsed = now().timeIntervalSince(started) * 1000
        print(String(format: "%-44@ %9.1f ms", label as NSString, elapsed))
        return elapsed
    }

    @discardableResult
    private func timeAsync(_ label: String, _ block: () async -> Void) async -> Double {
        let started = now()
        await block()
        let elapsed = now().timeIntervalSince(started) * 1000
        print(String(format: "%-44@ %9.1f ms", label as NSString, elapsed))
        return elapsed
    }

    private func realProjectPaths(limit: Int) -> [String] {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(".claude.json")
        guard let data = FileManager.default.contents(atPath: path),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projects = root["projects"] as? [String: Any] else { return [] }
        return projects.keys
            .filter { FileManager.default.fileExists(atPath: $0) }
            .sorted()
            .prefix(limit)
            .map { $0 }
    }

    private func realProjects(limit: Int) -> [Project] {
        realProjectPaths(limit: limit).map {
            Project(id: UUID(), path: $0, displayName: ($0 as NSString).lastPathComponent,
                    addedAt: Date(), lastOpenedAt: Date())
        }
    }

    private func header(_ title: String) {
        print("\n── \(title) " + String(repeating: "─", count: max(0, 46 - title.count)))
    }

    /// Every tab and every path the user can open, timed once end to end.
    @MainActor
    func testEveryUserFacingPath() async throws {
        print("\n════════════ FULL PATH COVERAGE ════════════")

        let fm = FileManager.default
        let projects = realProjects(limit: 60)
        guard projects.count >= 5 else { print("not enough real projects"); return }
        let sample = Array(projects.prefix(20))
        let one = projects[2]

        header("App launch")
        let store = ProjectStore()
        let launchStart = now()
        store.scan()
        while store.isScanning && now().timeIntervalSince(launchStart) < 20 {
            try await Task.sleep(for: .milliseconds(20))
        }
        let launchElapsed = now().timeIntervalSince(launchStart) * 1000
        print(String(format: "%-44@ %9.1f ms  (%d discovered, isScanning=%@)",
                     "ProjectStore.scan()" as NSString, launchElapsed,
                     store.discovered.count, store.isScanning ? "true" : "false"))

        header("Projects tab")
        time("ProjectFacts x \(sample.count) (rows + inspector)") {
            for p in sample { _ = ProjectFacts(path: p.path) }
        }
        time("detectedTools x \(sample.count)") {
            for p in sample { _ = ProjectStore.detectedTools(at: p.path, fm: fm) }
        }
        time("row cost x \(sample.count) (facts + tools)") {
            for p in sample { _ = ProjectFacts(path: p.path); _ = ProjectStore.detectedTools(at: p.path, fm: fm) }
        }
        time("whole list x \(projects.count) (facts + tools)") {
            for p in projects { _ = ProjectFacts(path: p.path); _ = ProjectStore.detectedTools(at: p.path, fm: fm) }
        }

        header("Skills tab (per project)")
        SkillInventoryReader.invalidateCaches()
        time("installedSkills cold (first open)") { _ = SkillInventoryReader.installedSkills(for: one.path) }
        time("installedSkills warm (x20, same project)") {
            for _ in 0..<20 { _ = SkillInventoryReader.installedSkills(for: one.path) }
        }
        time("installedSkills x \(sample.count) distinct projects") {
            for p in sample { _ = SkillInventoryReader.installedSkills(for: p.path) }
        }

        header("Skills tab (global) + badge refresh")
        let skillStore = SkillStore()
        let deadline = Date().addingTimeInterval(30)
        while skillStore.globalSkills.isEmpty && Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        print(String(format: "%-44@ %9d", "global skills discovered" as NSString, skillStore.globalSkills.count))
        SkillInventoryReader.invalidateCaches()
        time("installedProjectCounts x \(projects.count) cold") {
            _ = SkillStore.installedProjectCounts(
                globalSkills: skillStore.globalSkills, projects: projects,
                installedSkillsProvider: { SkillInventoryReader.installedSkills(for: $0) })
        }
        time("installedProjectCounts x \(projects.count) warm") {
            _ = SkillStore.installedProjectCounts(
                globalSkills: skillStore.globalSkills, projects: projects,
                installedSkillsProvider: { SkillInventoryReader.installedSkills(for: $0) })
        }
        SkillInventoryReader.invalidateCaches()
        await timeAsync("installedProjectCounts parallel (what ships)") {
            _ = await SkillStore.installedProjectCountsConcurrently(
                globalSkills: skillStore.globalSkills, projects: projects,
                installedSkillsProvider: { SkillInventoryReader.installedSkills(for: $0) })
        }

        header("Agents tab")
        time("AgentReader.agents x \(sample.count)") {
            for p in sample { _ = AgentReader.agents(for: p.path) }
        }

        header("MCP tab")
        time("ConfigWriter.readAllServerEntries project x \(sample.count)") {
            for p in sample {
                _ = ConfigWriter.readAllServerEntries(toolID: "claude-code", scope: .project, projectRoot: p.path)
            }
        }
        time("ConfigReader.readAllTools() (global MCP)") { _ = ConfigReader.shared.readAllTools() }

        header("Usage tab")
        UsageReader.homeOverride = nil
        time("UsageReader.summarize() cold") { _ = UsageReader.summarize() }
        time("UsageReader.summarize() warm") { _ = UsageReader.summarize() }

        header("Live Mode")
        time("ContextEstimator cold (reuseStatic: false)") {
            _ = ContextEstimator.estimate(for: one.path, reuseStatic: false)
        }
        time("ContextEstimator warm (reuseStatic: true)") {
            _ = ContextEstimator.estimate(for: one.path, reuseStatic: true)
        }

        header("Checks tab")
        time("CompatibilityScanner.scan full (one project)") {
            _ = CompatibilityScanner.scan(projectRoot: one.path, kind: .full)
        }
        time("CompatibilityScanner.scan plugins only (one project)") {
            _ = CompatibilityScanner.scan(projectRoot: one.path, kind: .plugins)
        }
        time("CompatibilityScanner.scan full (second project)") {
            _ = CompatibilityScanner.scan(projectRoot: projects[3].path, kind: .full)
        }

        print("\n════════════ END ════════════\n")
    }

    /// Prints the actual card values next to the timing so the reverse scan can be
    /// checked for both speed and equivalence, not just speed.
    func testUsageSpeedAndValues() throws {
        print("\n── Usage after the reverse scan ───────────────────")
        var cards: [UsageCard] = []
        time("UsageReader.summarize() cold") { cards = UsageReader.summarize() }
        time("UsageReader.summarize() warm") { _ = UsageReader.summarize() }
        for card in cards where card.featured || card.today.tokens > 0 || card.week.tokens > 0 {
            print(String(format: "  %-16@ today %8d  week %8d  last %8d  plan %@",
                         card.provider as NSString,
                         card.today.tokens, card.week.tokens, card.lastSession.tokens,
                         (card.plan ?? "-") as NSString))
        }
        print("")
    }

    /// Attributes the Usage tab's 21s cold cost: the directory walk versus reading
    /// whole session files and parsing every line.
    func testUsageAttribution() throws {
        print("\n── Usage attribution ──────────────────────────────")
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let roots: [(String, String)] = [
            ("~/.claude/projects", (home as NSString).appendingPathComponent(".claude/projects")),
            ("~/.codex/sessions", (home as NSString).appendingPathComponent(".codex/sessions")),
            ("~/Library/.../local-agent-mode-sessions",
             (home as NSString).appendingPathComponent("Library/Application Support/Claude/local-agent-mode-sessions"))
        ]

        var found: [String: [String]] = [:]
        for (label, root) in roots {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: root, isDirectory: &isDir), isDir.boolValue else {
                print(String(format: "%-44@ %9@", label as NSString, "missing" as NSString)); continue
            }
            var files: [String] = []
            let elapsed = time("walk \(label)") {
                guard let enumerator = fm.enumerator(atPath: root) else { return }
                var visited = 0
                while let relative = enumerator.nextObject() as? String {
                    visited += 1
                    if visited > 4_000 { break }
                    let lowered = relative.lowercased()
                    if lowered.contains("node_modules") || lowered.contains("/.git/") || lowered.contains("/.build/") {
                        enumerator.skipDescendants(); continue
                    }
                    guard relative.hasSuffix(".jsonl") else { continue }
                    let path = (root as NSString).appendingPathComponent(relative)
                    _ = (try? fm.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? .distantPast
                    files.append(path)
                }
            }
            _ = elapsed
            found[label] = files
            print(String(format: "%-44@ %9d", "  jsonl seen within 4k cap" as NSString, files.count))
        }

        let claudeFiles = (found["~/.claude/projects"] ?? []).sorted().suffix(80)
        var bytes = 0
        time("read + JSON-parse newest \(claudeFiles.count) claude files") {
            for path in claudeFiles {
                guard let handle = FileHandle(forReadingAtPath: path) else { continue }
                defer { try? handle.close() }
                let data = handle.readDataToEndOfFile()
                bytes += data.count
                guard data.count < 8_000_000,
                      let text = String(data: data, encoding: .utf8) else { continue }
                for line in text.split(whereSeparator: \.isNewline) {
                    _ = try? JSONSerialization.jsonObject(with: Data(line.utf8))
                }
            }
        }
        print(String(format: "%-44@ %9.1f MB", "  bytes read" as NSString, Double(bytes) / 1_048_576))

        let codexFiles = (found["~/.codex/sessions"] ?? []).suffix(80)
        var codexBytes = 0
        var codexTotal = 0
        time("read + JSON-parse newest \(codexFiles.count) codex files") {
            for path in codexFiles {
                guard let handle = FileHandle(forReadingAtPath: path) else { continue }
                defer { try? handle.close() }
                let data = handle.readDataToEndOfFile()
                codexBytes += data.count
                guard data.count < 8_000_000, let text = String(data: data, encoding: .utf8) else { continue }
                for line in text.split(whereSeparator: \.isNewline) {
                    if (try? JSONSerialization.jsonObject(with: Data(line.utf8))) != nil { codexTotal += 1 }
                }
            }
        }
        print(String(format: "%-44@ %9.1f MB (%d lines)",
                     "  bytes read" as NSString, Double(codexBytes) / 1_048_576, codexTotal))
        print("")
    }
}
