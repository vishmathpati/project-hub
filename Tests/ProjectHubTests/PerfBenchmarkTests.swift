import XCTest
@testable import ProjectHub

/// Wall-clock measurements against the real home directory rather than a
/// synthetic fixture. The test always passes; the printed breakdown is the
/// artifact, and it is what says where a stall actually lives.
final class PerfBenchmarkTests: XCTestCase {

    private func now() -> Date { Date() }

    private func ms(_ label: String, _ block: () -> Void) -> Double {
        let started = now()
        block()
        let elapsed = now().timeIntervalSince(started) * 1000
        print(String(format: "  %-46@ %8.1f ms", label as NSString, elapsed))
        return elapsed
    }

    /// Real project paths the app would discover, from the live ~/.claude.json.
    private func realProjectPaths(limit: Int) -> [String] {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(".claude.json")
        guard let data = FileManager.default.contents(atPath: path),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projects = root["projects"] as? [String: Any] else {
            return []
        }
        return projects.keys
            .filter { FileManager.default.fileExists(atPath: $0) }
            .sorted()
            .prefix(limit)
            .map { $0 }
    }

    func testMeasureRealHotPaths() throws {
        let fm = FileManager.default
        print("\n=== PerfBenchmark (real home) ===")

        let claudeJSON = (NSHomeDirectory() as NSString).appendingPathComponent(".claude.json")
        if let attrs = try? fm.attributesOfItem(atPath: claudeJSON),
           let size = attrs[.size] as? Int {
            print(String(format: "  ~/.claude.json: %.0f KB", Double(size) / 1024))
        }

        let allPaths = realProjectPaths(limit: 100_000)
        print("  existing projects in ~/.claude.json: \(allPaths.count)")

        let sample = Array(allPaths.prefix(60))
        print("  sampling: \(sample.count) projects\n")

        print("[1] per-project inspection (Projects rows + inspector)")
        var factsTotal: Double = 0
        for path in sample {
            factsTotal += ms("ProjectFacts(\(path.split(separator: "/").last ?? ""))") {
                _ = ProjectFacts(path: path)
            }
        }
        let factsPer = factsTotal / Double(max(sample.count, 1))
        print(String(format: "      => %.2f ms/project, %.0f ms for %d projects\n",
                     factsPer, factsPer * Double(sample.count), sample.count))

        print("[2] detectedTools (3-source tool detection per row)")
        let toolsTotal = ms("detectedTools x \(sample.count)") {
            for path in sample {
                _ = ProjectStore.detectedTools(at: path, fm: fm)
            }
        }
        print(String(format: "      => %.2f ms/project\n\n", toolsTotal / Double(max(sample.count, 1))))

        print("[3] full Projects-tab row cost (facts + tools per project)")
        let rowCost = ms("ProjectFacts + detectedTools x \(sample.count)") {
            for path in sample {
                _ = ProjectFacts(path: path)
                _ = ProjectStore.detectedTools(at: path, fm: fm)
            }
        }
        print(String(format: "      => %.2f ms/project, %.0f ms for all %d existing projects\n\n",
                     rowCost / Double(max(sample.count, 1)),
                     rowCost / Double(max(sample.count, 1)) * Double(allPaths.count),
                     allPaths.count))

        print("[4] skill inventory (opening a project's Skills tab)")
        if let first = sample.first {
            _ = ms("SkillInventoryReader.installedSkills x \(sample.count)") {
                for path in sample {
                    _ = SkillInventoryReader.installedSkills(for: path)
                }
            }
        }

        print("\n[5] Live Mode estimate (runs on the 3s timer)")
        if let first = sample.first {
            _ = ms("ContextEstimator.estimate (cold, reuseStatic=false)") {
                _ = ContextEstimator.estimate(for: first, reuseStatic: false)
            }
            _ = ms("ContextEstimator.estimate (warm, reuseStatic=true)") {
                _ = ContextEstimator.estimate(for: first, reuseStatic: true)
            }
        }

        print("\n[6] Checks tab full scan")
        if let first = sample.first {
            _ = ms("CompatibilityScanner.scan (one project)") {
                _ = CompatibilityScanner.scan(projectPath: first)
            }
        }
        print("\n=== end ===\n")
    }

    @MainActor
    func testMeasureProjectDiscovery() throws {
        print("\n=== discovery (app launch path) ===")
        let store = ProjectStore()
        let started = now()
        store.scan()
        while store.isScanning && now().timeIntervalSince(started) < 20 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        print(String(format: "  ProjectStore.scan()  %.0f ms, discovered %d",
                     now().timeIntervalSince(started) * 1000, store.discovered.count))
        print("")
    }

    /// Locates which projects dominate the inventory scan, and how much of the
    /// cost is tree-walking versus known-path reads.
    func testMeasureSkillInventoryOutliers() throws {
        print("\n=== installedSkills, per project (worst first) ===")
        let paths = realProjectPaths(limit: 25)
        var rows: [(String, Double)] = []
        for path in paths {
            let started = now()
            _ = SkillInventoryReader.installedSkills(for: path)
            rows.append((path, now().timeIntervalSince(started) * 1000))
        }
        for (path, elapsed) in rows.sorted(by: { $0.1 > $1.1 }).prefix(12) {
            let short = path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
            print(String(format: "  %8.1f ms  %@", elapsed, short as NSString))
        }
        let total = rows.reduce(0) { $0 + $1.1 }
        print(String(format: "  total %.0f ms over %d projects\n", total, rows.count))

        print("=== how many directories get visited per project ===")
        for path in rows.sorted(by: { $0.1 > $1.1 }).prefix(4) {
            var visited = 0
            let started = now()
            _ = KnownSkillRoots.existingNestedClaudeSkillDirectories(
                from: URL(fileURLWithPath: path.0),
                excluding: [],
                maxDepth: 4,
                maxDirectoriesVisited: 80
            )
            for _ in 0..<1 { visited += 1 }
            let elapsed = now().timeIntervalSince(started) * 1000
            print(String(format: "  %8.1f ms  nested walk  %@", elapsed,
                         path.0.replacingOccurrences(of: NSHomeDirectory(), with: "~") as NSString))
            _ = visited
        }
        print("")
    }

    /// Attributes the ~300ms/project inventory cost by replicating the candidate
    /// directory set and timing each part.
    func testMeasureInventoryAttribution() throws {
        print("\n=== installedSkills attribution ===")

        _ = ms("ProviderCatalog.specs() x100", {
            for _ in 0..<100 { _ = ProviderCatalog.specs() }
        })

        guard let project = realProjectPaths(limit: 1).first else { return }
        let short = project.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        print("  project: \(short)")

        // Replicate skillDirectories()' candidate set.
        var candidates: [String] = []
        var seen = Set<String>()
        var current = URL(fileURLWithPath: project)
        let specs = ProviderCatalog.specs()
        for _ in 0..<6 {
            for spec in specs {
                for relative in spec.projectSkillDirs {
                    let p = current.appendingPathComponent(relative).path
                    if seen.insert(p).inserted { candidates.append(p) }
                }
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }
        for nested in KnownSkillRoots.existingNestedClaudeSkillDirectories(
            from: URL(fileURLWithPath: project), excluding: Set(candidates),
            maxDepth: 4, maxDirectoriesVisited: 80
        ) {
            if seen.insert(nested.path).inserted { candidates.append(nested.path) }
        }

        let existing = candidates.filter { FileManager.default.fileExists(atPath: $0) }
        print("  candidate dirs: \(candidates.count), existing: \(existing.count)")

        var scanned = 0
        var total = 0.0
        for dir in existing {
            let started = now()
            let found = SkillReader.scanSkillDir(dir, source: .claudeGlobal)
            let elapsed = now().timeIntervalSince(started) * 1000
            total += elapsed
            scanned += found.count
            if elapsed > 5 {
                print(String(format: "  %8.1f ms  %-52@ (%d skills)", elapsed,
                             dir.replacingOccurrences(of: NSHomeDirectory(), with: "~") as NSString,
                             found.count))
            }
        }
        print(String(format: "  scanSkillDir total: %.1f ms, %d skills parsed\n", total, scanned))

        // The walk-up cost alone: how many directory probes happen with no cache.
        _ = ms("FileManager.fileExists x \(candidates.count * 3)", {
            for _ in 0..<3 {
                for c in candidates { _ = FileManager.default.fileExists(atPath: c) }
            }
        })
        print("")
    }

    /// Times the individual calls inside installedSkills to find the constant cost.
    func testMeasurePerCallCosts() throws {
        print("\n=== per-call costs (the constant in installedSkills) ===")

        let paths = ["/", NSHomeDirectory(), NSHomeDirectory() + "/Arel Ecosystem"]
            + realProjectPaths(limit: 6)

        for path in paths.prefix(6) {
            let short = path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
            var detectTotal = 0.0
            var canonTotal = 0.0
            let iterations = 10
            for _ in 0..<iterations {
                var t = now()
                _ = ProjectRootDetector.detect(from: path)
                detectTotal += now().timeIntervalSince(t)

                t = now()
                _ = Project.rootOwning(path)
                canonTotal += now().timeIntervalSince(t)
            }
            let invStart = now()
            _ = SkillInventoryReader.installedSkills(for: path)
            let invTotal = now().timeIntervalSince(invStart) * 1000

            print(String(format: "  %-34@ detect %.2f ms | canonicalize %.2f ms | installedSkills %.0f ms",
                         short as NSString,
                         detectTotal / Double(iterations),
                         canonTotal / Double(iterations),
                         invTotal))
        }
        print("")
    }

    /// Measures the global Codex plugin-cache walk that installedSkills runs on
    /// every call, independent of which project is asked for.
    func testMeasureCodexPluginCacheWalk() throws {
        print("\n=== Codex plugin cache walk (globally re-scanned per call) ===")
        let fm = FileManager.default
        let cache = (ProjectHubPaths.codexHome() as NSString).appendingPathComponent("plugins/cache")
        guard fm.fileExists(atPath: cache) else { print("  no cache\n"); return }

        var dirsVisited = 0
        var skillFilesParsed = 0

        let started = now()
        if let markets = try? fm.contentsOfDirectory(atPath: cache) {
            for market in markets where !market.hasPrefix(".") {
                let marketDir = (cache as NSString).appendingPathComponent(market)
                dirsVisited += 1
                guard let plugins = try? fm.contentsOfDirectory(atPath: marketDir) else { continue }
                for plugin in plugins where !plugin.hasPrefix(".") {
                    let pluginDir = (marketDir as NSString).appendingPathComponent(plugin)
                    dirsVisited += 1
                    guard let versions = try? fm.contentsOfDirectory(atPath: pluginDir) else { continue }
                    for versionName in versions.sorted().reversed() {
                        let root = (pluginDir as NSString).appendingPathComponent(versionName)
                        let skillDir = (root as NSString).appendingPathComponent("skills")
                        dirsVisited += 1
                        for skill in SkillReader.scanSkillDir(skillDir, source: .codexManaged) {
                            skillFilesParsed += 1
                        }
                        break
                    }
                }
            }
        }
        let walkMs = now().timeIntervalSince(started) * 1000
        print(String(format: "  %.0f ms  (%d dirs, %d skills) — paid on EVERY installedSkills call",
                     walkMs, dirsVisited, skillFilesParsed))

        let skillsRoot = (NSHomeDirectory() as NSString).appendingPathComponent(".claude/skills")
        let claudeStart = now()
        var claudeSkills = 0
        for dir in (try? fm.contentsOfDirectory(atPath: skillsRoot)) ?? [] {
            let path = (skillsRoot as NSString).appendingPathComponent(dir)
            for skill in SkillReader.scanSkillDir(path, source: .claudeGlobal) { _ = skill; claudeSkills += 1 }
        }
        print(String(format: "  %.0f ms  (~/.claude/skills walk, %d skills)",
                     now().timeIntervalSince(claudeStart) * 1000, claudeSkills))
        print("")
    }

    /// installedSkills does two per-skill operations that scale with how many skills
    /// exist, not with the project. Times them at realistic counts.
    func testMeasurePerSkillOperations() throws {
        print("\n=== per-skill operations (scale with skill count, not project) ===")

        let roots = [
            (NSHomeDirectory() as NSString).appendingPathComponent(".claude/skills"),
            (ProjectHubPaths.codexHome() as NSString).appendingPathComponent("plugins/cache")
        ]
        var skillFiles: [String] = []
        let fm = FileManager.default
        for root in roots {
            guard let walker = fm.enumerator(atPath: root) else { continue }
            for case let rel as String in walker where rel.hasSuffix("SKILL.md") {
                skillFiles.append((root as NSString).appendingPathComponent(rel))
                if skillFiles.count >= 300 { break }
            }
            if skillFiles.count >= 300 { break }
        }
        print("  sampled \(skillFiles.count) real SKILL.md paths")

        let canonMs = ms("resolvingSymlinksInPath x \(skillFiles.count)") {
            for file in skillFiles {
                _ = URL(fileURLWithPath: file).standardizedFileURL.resolvingSymlinksInPath().path
            }
        }

        let versionMs = ms("read SKILL.md + scan for version x \(skillFiles.count)") {
            for file in skillFiles {
                guard let content = try? String(contentsOfFile: file, encoding: .utf8) else { continue }
                for line in content.split(whereSeparator: \.isNewline) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed.hasPrefix("version:") else { continue }
                    _ = trimmed
                    break
                }
            }
        }

        let attrsMs = ms("attributesOfItem x \(skillFiles.count)") {
            for file in skillFiles {
                _ = try? FileManager.default.attributesOfItem(atPath: file)
            }
        }

        print(String(format: "      => per full inventory call: canonicalize %.0f ms + versions %.0f ms + stamp stats %.0f ms = %.0f ms",
                     canonMs, versionMs, attrsMs, canonMs + versionMs + attrsMs))
        print("")
    }

    /// The real user-facing path: the "installed in N projects" badge refresh over
    /// every tracked project. Compares serial against concurrent.
    @MainActor
    func testMeasureInstallCountRefresh() async throws {
        print("\n=== install-count refresh (the badge path) ===")

        let store = SkillStore()
        let deadline = Date().addingTimeInterval(30)
        while store.globalSkills.isEmpty && Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        let globalSkills = store.globalSkills
        print("  global skills: \(globalSkills.count)")

        let projects = realProjectPaths(limit: 60).map {
            Project(id: UUID(), path: $0, displayName: ($0 as NSString).lastPathComponent,
                    addedAt: Date(), lastOpenedAt: Date())
        }
        print("  projects: \(projects.count)")

        SkillInventoryReader.invalidateCaches()
        let coldStart = now()
        _ = SkillStore.installedProjectCounts(
            globalSkills: globalSkills,
            projects: projects,
            installedSkillsProvider: { SkillInventoryReader.installedSkills(for: $0) }
        )
        let cold = now().timeIntervalSince(coldStart) * 1000
        print(String(format: "  cold        %8.0f ms", cold))

        let warmStart = now()
        _ = SkillStore.installedProjectCounts(
            globalSkills: globalSkills,
            projects: projects,
            installedSkillsProvider: { SkillInventoryReader.installedSkills(for: $0) }
        )
        let warm = now().timeIntervalSince(warmStart) * 1000
        print(String(format: "  warm        %8.0f ms", warm))

        SkillInventoryReader.invalidateCaches()
        let parStart = now()
        _ = await SkillStore.installedProjectCountsConcurrently(
            globalSkills: globalSkills,
            projects: projects,
            installedSkillsProvider: { SkillInventoryReader.installedSkills(for: $0) }
        )
        let parallel = now().timeIntervalSince(parStart) * 1000
        print(String(format: "  parallel    %8.0f ms   (cold serial %.1fx)", parallel, cold / max(parallel, 1)))
        print("")
    }

    /// Times the parts of one Checks scan so the 2s is attributable.
    func testMeasureCompatibilityScanParts() throws {
        print("\n=== CompatibilityScanner.scan breakdown (one project) ===")
        guard let path = realProjectPaths(limit: 5).first else { return }
        print("  project: \(path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))")

        _ = ms("scan() total") {
            _ = CompatibilityScanner.scan(projectPath: path)
        }
        _ = ms("scan() total (second run, warm OS cache)") {
            _ = CompatibilityScanner.scan(projectPath: path)
        }
        _ = ms("KnownSkillRoots nested walk") {
            _ = KnownSkillRoots.existingNestedClaudeSkillDirectories(
                from: URL(fileURLWithPath: path), excluding: [], maxDepth: 4, maxDirectoriesVisited: 80
            )
        }
        print("")
    }
}
