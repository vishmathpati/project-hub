import XCTest
@testable import ProjectHub

final class ProviderCatalogTests: XCTestCase {
    func testPrimaryProviderNamesAreVisible() {
        let names = ProviderCatalog.specs(home: "/tmp/projecthub-provider-home").map(\.name)
        XCTAssertEqual(names, [
            "Claude Code",
            "Claude Desktop",
            "Codex",
            "Cursor",
            "VS Code",
            "Antigravity",
            "OpenCode",
            "Zed",
            "Pi",
            "Command Code",
            "Grok CLI",
        ])
    }

    @MainActor
    func testCreateSkillUsesProviderProjectDir() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubProviderCreate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = SkillStore()
        let path = try XCTUnwrap(store.createSkill(named: "demo-skill", providerID: "opencode", projectPath: root.path))
        XCTAssertTrue(path.contains("/.opencode/skills/demo-skill"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent("SKILL.md")))
    }
}
