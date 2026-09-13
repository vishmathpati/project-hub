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
}
