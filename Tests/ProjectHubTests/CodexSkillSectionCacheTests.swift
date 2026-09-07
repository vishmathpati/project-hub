import XCTest
@testable import ProjectHub

final class CodexSkillSectionCacheTests: XCTestCase {
    func testAnEditBetweenCallsIsNotServedFromTheCache() throws {
        let root = try makeTempDirectory()
        let skillA = try writeSkill(named: "alpha", under: root)
        let skillB = try writeSkill(named: "beta", under: root)
        let configPath = root.appendingPathComponent("config.toml").path

        try config(enabling: skillA, enabled: false).write(toFile: configPath, atomically: true, encoding: .utf8)
        XCTAssertNotNil(
            ConfigWriter.previewSetCodexSkillOverrideEnabled(configPath: configPath, skillMDPath: skillA, enabled: true),
            "alpha is the only section, so enabling it must preview"
        )

        try config(enabling: skillB, enabled: false).write(toFile: configPath, atomically: true, encoding: .utf8)
        XCTAssertNil(
            ConfigWriter.previewSetCodexSkillOverrideEnabled(configPath: configPath, skillMDPath: skillA, enabled: true),
            "alpha is no longer in the file. A cached parse of the previous contents would still find it."
        )
        XCTAssertNotNil(
            ConfigWriter.previewSetCodexSkillOverrideEnabled(configPath: configPath, skillMDPath: skillB, enabled: true),
            "beta is now the only section and must preview"
        )
    }

    func testIdenticalContentAtTwoPathsIsNotShared() throws {
        let root = try makeTempDirectory()
        let skill = try writeSkill(named: "shared", under: root)
        let first = root.appendingPathComponent("first.toml").path
        let second = root.appendingPathComponent("second.toml").path
        let text = config(enabling: skill, enabled: false)
        try text.write(toFile: first, atomically: true, encoding: .utf8)
        try text.write(toFile: second, atomically: true, encoding: .utf8)

        XCTAssertNotNil(ConfigWriter.previewSetCodexSkillOverrideEnabled(configPath: first, skillMDPath: skill, enabled: true))
        XCTAssertNotNil(
            ConfigWriter.previewSetCodexSkillOverrideEnabled(configPath: second, skillMDPath: skill, enabled: true),
            "the second path has identical bytes but is a different config; it must still resolve"
        )
    }

    private func config(enabling skillMDPath: String, enabled: Bool) -> String {
        """
        [[skills.config]]
        path = "\(skillMDPath)"
        enabled = \(enabled)
        """
    }

    private func writeSkill(named name: String, under root: URL) throws -> String {
        let dir = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let md = dir.appendingPathComponent("SKILL.md")
        try "---\nname: \(name)\n---\n".write(to: md, atomically: true, encoding: .utf8)
        return md.path
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubCodexSectionCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
