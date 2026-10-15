import XCTest
@testable import ProjectHub

final class ContextActionsTests: XCTestCase {
    func testToolSearchPreviewPreservesUnrelatedKeysAndUndoRestoresExactBytes() throws {
        let project = try makeProject()
        let target = project.appendingPathComponent(".claude/settings.local.json")
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = "{\n  \"permissions\": {\"allow\": [\"Read\"]},\n  \"env\": {\"KEEP\": \"yes\"}\n}\n"
        try original.write(to: target, atomically: true, encoding: .utf8)

        let preview = try ContextActions.preview(.enableClaudeToolSearch(projectPath: project.path))
        XCTAssertEqual(preview.before, original)
        XCTAssertTrue(preview.after.contains("\"KEEP\" : \"yes\""))
        XCTAssertTrue(preview.after.contains("\"ENABLE_TOOL_SEARCH\" : \"true\""))
        XCTAssertTrue(preview.after.contains("\"permissions\""))
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), original, "Preview must not write")

        let receipt = try ContextActions.apply(preview)
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), preview.after)
        try ContextActions.undo(receipt)
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), original)
    }

    func testUndoRemovesFileThatDidNotExistBeforeApply() throws {
        let project = try makeProject()
        let target = project.appendingPathComponent(".claude/settings.local.json")
        let preview = try ContextActions.preview(.enableClaudeToolSearch(projectPath: project.path))
        XCTAssertFalse(preview.existedBefore)
        let receipt = try ContextActions.apply(preview)
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
        try ContextActions.undo(receipt)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }

    func testSkillOverridePreservesOtherOverridesAndRejectsPluginIdentity() throws {
        let project = try makeProject()
        let target = project.appendingPathComponent(".claude/settings.local.json")
        let skillName = "context-actions-unique-review"
        let skill = project.appendingPathComponent(".claude/skills/\(skillName)/SKILL.md")
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: skill.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "---\nname: \(skillName)\ndescription: Review\n---\n".write(to: skill, atomically: true, encoding: .utf8)
        try "{\"skillOverrides\":{\"keep\":\"enabled\"}}".write(to: target, atomically: true, encoding: .utf8)

        let preview = try ContextActions.preview(.makeClaudeSkillUserInvocableOnly(
            projectPath: project.path, skillName: skillName, skillSourcePath: skill.path
        ))
        XCTAssertTrue(preview.after.contains("\"keep\" : \"enabled\""))
        XCTAssertTrue(preview.after.contains("\"\(skillName)\" : \"user-invocable-only\""))
        XCTAssertThrowsError(try ContextActions.preview(
            .makeClaudeSkillUserInvocableOnly(projectPath: project.path, skillName: "plugin:review", skillSourcePath: skill.path)
        )) { error in
            XCTAssertEqual(error as? ContextActionError, .ineligibleSkill("plugin:review"))
        }
    }

    func testMalformedAndUnsupportedExistingJSONAreRejected() throws {
        let project = try makeProject()
        let target = project.appendingPathComponent(".claude/settings.local.json")
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "{bad".write(to: target, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ContextActions.preview(.enableClaudeToolSearch(projectPath: project.path)))

        try "{\"env\":[]}".write(to: target, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ContextActions.preview(.enableClaudeToolSearch(projectPath: project.path))) { error in
            XCTAssertEqual(error as? ContextActionError, .unsupportedShape("env"))
        }
    }

    func testApplyAndUndoRejectStaleContent() throws {
        let project = try makeProject()
        let target = project.appendingPathComponent(".claude/settings.local.json")
        let preview = try ContextActions.preview(.enableClaudeToolSearch(projectPath: project.path))
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "{}".write(to: target, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ContextActions.apply(preview)) { error in
            XCTAssertEqual(error as? ContextActionError, .stale(target.path))
        }

        try FileManager.default.removeItem(at: target)
        let fresh = try ContextActions.preview(.enableClaudeToolSearch(projectPath: project.path))
        let receipt = try ContextActions.apply(fresh)
        try "{\"changed\":true}".write(to: target, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ContextActions.undo(receipt)) { error in
            XCTAssertEqual(error as? ContextActionError, .stale(target.path))
        }
    }

    func testMissingTargetReplacedByEmptyFileIsStale() throws {
        let project = try makeProject()
        let target = project.appendingPathComponent(".claude/settings.local.json")
        let preview = try ContextActions.preview(.enableClaudeToolSearch(projectPath: project.path))
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "".write(to: target, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try ContextActions.apply(preview)) { error in
            XCTAssertEqual(error as? ContextActionError, .stale(target.path))
        }
    }

    func testSkillIdentityIsRevalidatedAtApply() throws {
        let project = try makeProject()
        let name = "context-actions-changing-skill"
        let skill = project.appendingPathComponent(".claude/skills/\(name)/SKILL.md")
        try FileManager.default.createDirectory(at: skill.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "---\nname: \(name)\ndescription: Before\n---\n".write(to: skill, atomically: true, encoding: .utf8)
        let preview = try ContextActions.preview(.makeClaudeSkillUserInvocableOnly(
            projectPath: project.path, skillName: name, skillSourcePath: skill.path
        ))
        try "---\nname: changed\ndescription: After\n---\n".write(to: skill, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try ContextActions.apply(preview)) { error in
            XCTAssertEqual(error as? ContextActionError, .ineligibleSkill(name))
        }
    }

    func testSymlinkedSettingsDirectoryIsRejected() throws {
        let project = try makeProject()
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.createSymbolicLink(
            at: project.appendingPathComponent(".claude"),
            withDestinationURL: outside
        )
        XCTAssertThrowsError(try ContextActions.preview(.enableClaudeToolSearch(projectPath: project.path))) { error in
            guard case .symlinkTarget = error as? ContextActionError else {
                return XCTFail("Expected symlink rejection, got \(error)")
            }
        }
    }

    private func makeProject() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
