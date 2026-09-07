import XCTest
@testable import ProjectHub

final class FrontmatterPreservationTests: XCTestCase {
    func testPreservesScalarListAndBlockKeysItDoesNotOwn() {
        let content = """
        ---
        name: deploy
        version: 1.2.0
        allowed-tools:
          - Bash
          - Read
        notes: |
          first line
          second line
        description: ships things
        ---

        body text
        """

        let preserved = SkillReader.preservedFrontmatterLines(
            in: content,
            excluding: ["name", "description"]
        )

        XCTAssertEqual(preserved, [
            "version: 1.2.0",
            "allowed-tools:",
            "  - Bash",
            "  - Read",
            "notes: |",
            "  first line",
            "  second line"
        ], "Keys the editor does not model must survive verbatim, including list items and block scalars.")
    }

    func testReturnsNothingWhenThereIsNoFrontmatter() {
        XCTAssertEqual(SkillReader.preservedFrontmatterLines(in: "just a body", excluding: ["name"]), [String]())
    }

    func testCursorRuleUpdateKeepsUnknownKeys() throws {
        let root = try makeTempDirectory()
        let rulesDir = root.appendingPathComponent(".cursor/rules", isDirectory: true)
        try FileManager.default.createDirectory(at: rulesDir, withIntermediateDirectories: true)
        let path = rulesDir.appendingPathComponent("style.mdc")
        try """
        ---
        description: old
        globs: "*.swift"
        alwaysApply: false
        priority: 10
        owner: platform-team
        ---

        original body
        """.write(to: path, atomically: true, encoding: .utf8)

        let rule = CursorRule(
            filename: "style.mdc",
            filePath: path.path,
            description: "old",
            globs: "*.swift",
            alwaysApply: false,
            body: "original body"
        )
        try CursorRulesReader.update(
            rule: rule,
            description: "new",
            globs: "*.swift",
            alwaysApply: true,
            body: "new body"
        )

        let written = try String(contentsOf: path, encoding: .utf8)
        XCTAssertTrue(written.contains("description: new"), "the edited value must be written")
        XCTAssertTrue(written.contains("priority: 10"), "priority is not modelled by the editor and must survive")
        XCTAssertTrue(written.contains("owner: platform-team"), "owner is not modelled by the editor and must survive")
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubFrontmatterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
