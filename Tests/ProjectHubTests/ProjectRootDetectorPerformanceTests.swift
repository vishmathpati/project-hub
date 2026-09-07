import XCTest
@testable import ProjectHub

final class ProjectRootDetectorPerformanceTests: XCTestCase {
    private struct Fixture {
        let outer: URL
        let inner: URL
        let nested: URL
        let claudeJSON: URL
    }

    func testRepeatedDetectionWithUnchangedConfigStaysFast() throws {
        let fixture = try makeFixture(registrySize: 327)

        let start = Date()
        for _ in 0..<100 {
            _ = ProjectRootDetector.detect(from: fixture.nested.path)
        }
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(
            elapsed,
            0.5,
            "100 detections took \(String(format: "%.2f", elapsed))s. Each call re-reads and re-parses the whole Claude project registry, so opening a project runs this thousands of times on the main thread and freezes the app."
        )
    }

    func testDetectionReflectsClaudeRegistryChangesBetweenCalls() throws {
        let fixture = try makeFixture(registrySize: 8)

        XCTAssertEqual(ProjectRootDetector.detect(from: fixture.nested.path), fixture.outer.path)

        try writeRegistry(at: fixture.claudeJSON, size: 8, extraRoots: [fixture.inner.path])

        XCTAssertEqual(ProjectRootDetector.detect(from: fixture.nested.path), fixture.inner.path)
    }

    private func makeFixture(registrySize: Int) throws -> Fixture {
        let temp = try makeTempDirectory()
        let codexHome = temp.appendingPathComponent("codex-home", isDirectory: true)
        let outer = temp.appendingPathComponent("outer", isDirectory: true)
        let inner = outer.appendingPathComponent("inner", isDirectory: true)
        let nested = inner.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "{}".write(to: outer.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        try "{}".write(to: inner.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

        let claudeJSON = temp.appendingPathComponent("claude.json")
        try writeRegistry(at: claudeJSON, size: registrySize, extraRoots: [], parent: temp)

        setenv("CODEX_HOME", codexHome.path, 1)
        setenv("PROJECTHUB_CLAUDE_JSON_PATH", claudeJSON.path, 1)
        addTeardownBlock {
            unsetenv("CODEX_HOME")
            unsetenv("PROJECTHUB_CLAUDE_JSON_PATH")
        }

        return Fixture(outer: outer, inner: inner, nested: nested, claudeJSON: claudeJSON)
    }

    private func writeRegistry(
        at url: URL,
        size: Int,
        extraRoots: [String],
        parent: URL? = nil
    ) throws {
        let base = parent ?? url.deletingLastPathComponent()
        var projects: [String: [String: String]] = [:]
        for index in 0..<size {
            let dir = base.appendingPathComponent("registry/project-\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            projects[dir.path] = ["lastUsed": "2026-01-01"]
        }
        for root in extraRoots {
            projects[root] = ["lastUsed": "2026-01-01"]
        }
        try JSONSerialization.data(withJSONObject: ["projects": projects]).write(to: url)
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubRootDetectorPerformanceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
