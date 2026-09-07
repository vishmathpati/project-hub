import XCTest
@testable import ProjectHub

final class GeneratedFilenameTests: XCTestCase {
    func testEachCreatedAgentGetsItsOwnFile() throws {
        let root = try makeTempDirectory()
        try AgentReader.create(
            agent: AgentTemplate(name: "Reviewer", description: "reviews code", model: "sonnet", tools: []),
            in: root.path
        )
        try AgentReader.create(
            agent: AgentTemplate(name: "Deploy Bot", description: "ships things", model: "opus", tools: []),
            in: root.path
        )

        let dir = root.appendingPathComponent(".claude/agents", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()

        XCTAssertEqual(
            files,
            ["deploy-bot.md", "reviewer.md"],
            "Each agent must land in a file named after it. A shared filename means the second create silently destroys the first."
        )
    }

    func testCursorRuleFilenameComesFromItsDescription() throws {
        let root = try makeTempDirectory()
        try CursorRulesReader.create(
            description: "Swift Style",
            globs: "*.swift",
            alwaysApply: false,
            body: "use four spaces",
            in: root.path
        )

        let dir = root.appendingPathComponent(".cursor/rules", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()

        XCTAssertEqual(files, ["swift-style.mdc"], "The filename is meant to be derived from the description.")
    }

    func testAgentNamesThatCollapseToTheSameStemDoNotOverwrite() throws {
        let root = try makeTempDirectory()
        try AgentReader.create(
            agent: AgentTemplate(name: "Code Helper", description: "first", model: "sonnet", tools: []),
            in: root.path
        )
        try AgentReader.create(
            agent: AgentTemplate(name: "code-helper", description: "second", model: "opus", tools: []),
            in: root.path
        )

        let dir = root.appendingPathComponent(".claude/agents", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()

        XCTAssertEqual(files.count, 2, "Two agents whose names sanitise to the same stem must not share a file. Found \(files).")
    }

    func testAgentWithNoUsableCharactersStillGetsAFilename() throws {
        let root = try makeTempDirectory()
        try AgentReader.create(
            agent: AgentTemplate(name: "!!!", description: "punctuation only", model: "sonnet", tools: []),
            in: root.path
        )

        let dir = root.appendingPathComponent(".claude/agents", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)

        XCTAssertEqual(files, ["agent.md"], "A name with nothing usable must fall back to a real filename, not \".md\".")
    }

    func testCreatingTheSameAgentNameTwiceIsRejected() throws {
        let root = try makeTempDirectory()
        let template = AgentTemplate(name: "Code Helper", description: "first", model: "sonnet", tools: [])
        try AgentReader.create(agent: template, in: root.path)

        XCTAssertThrowsError(
            try AgentReader.create(agent: template, in: root.path),
            "Agent.id is the name, so two agents sharing one name give SwiftUI duplicate ids and make delete-by-name ambiguous."
        )

        let dir = root.appendingPathComponent(".claude/agents", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertEqual(files, ["code-helper.md"], "the rejected create must not leave a second file behind")
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubGeneratedFilenameTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
