import XCTest
@testable import ProjectHub

final class MarkdownDiffPreviewTests: XCTestCase {
    func testCommandUpdateRefusesStalePreview() throws {
        let root = try makeTempDirectory()
        try createCommandDir(root: root, name: "deploy", description: "old")

        let path = commandPath(root: root, name: "deploy")
        let before = try XCTUnwrap(CommandsReader.currentText(at: path))
        let rendered = CommandsReader.renderedDocument(
            for: SlashCommand(
                name: "deploy", description: "new", argumentHint: "",
                allowedTools: [], model: "", body: "body",
                filePath: path, scope: .project
            ),
            currentFileContent: before
        )
        XCTAssertNotEqual(rendered, before)

        // Simulate an external edit after the preview was staged.
        try "\(before)\n# external\n".write(toFile: path, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(
            try CommandsReader.update(
                SlashCommand(
                    name: "deploy", description: "new", argumentHint: "",
                    allowedTools: [], model: "", body: "body",
                    filePath: path, scope: .project
                ),
                in: root.path,
                expectedBefore: before
            )
        )
        // The external edit must survive.
        XCTAssertTrue(try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8).contains("# external"))
    }

    func testAgentUpdateRefusesStalePreview() throws {
        let root = try makeTempDirectory()
        let path = try createAgentFile(root: root, name: "reviewer", description: "old")

        let before = try XCTUnwrap(AgentReader.currentText(at: path))
        let rendered = AgentReader.renderedDocument(for: Agent(
            name: "reviewer", description: "new", model: "sonnet",
            tools: [], filePath: path, body: "body"
        ))
        XCTAssertNotEqual(rendered, before)

        try "\(before)\n# external\n".write(toFile: path, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(
            try AgentReader.update(
                Agent(
                    name: "reviewer", description: "new", model: "sonnet",
                    tools: [], filePath: path, body: "body"
                ),
                in: root.path,
                expectedBefore: before
            )
        )
        XCTAssertTrue(try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8).contains("# external"))
    }

    func testCursorRuleUpdateRefusesStalePreview() throws {
        let root = try makeTempDirectory()
        try CursorRulesReader.create(
            description: "use bun", globs: "*.ts", alwaysApply: false,
            body: "body", in: root.path
        )
        let rule = try XCTUnwrap(CursorRulesReader.rules(for: root.path).first)

        let before = try XCTUnwrap(CursorRulesReader.currentText(at: rule.filePath))
        let rendered = CursorRulesReader.renderedDocument(
            description: "use node", globs: "*.ts", alwaysApply: false,
            body: "body", currentFileContent: before
        )
        XCTAssertNotEqual(rendered, before)

        try "\(before)\n# external\n".write(toFile: rule.filePath, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(
            try CursorRulesReader.update(
                rule: rule, description: "use node", globs: "*.ts",
                alwaysApply: false, body: "body", expectedBefore: before
            )
        )
        XCTAssertTrue(try String(contentsOf: URL(fileURLWithPath: rule.filePath), encoding: .utf8).contains("# external"))
    }

    func testInstructionFileWriteRefusesStalePreview() throws {
        let root = try makeTempDirectory()
        let document = InstructionDocument(relativePath: "AGENTS.md", title: "AGENTS.md")
        try InstructionFileReader.write("# Agents v1\n", document, to: root.path)

        let before = try XCTUnwrap(InstructionFileReader.read(document, from: root.path))
        try InstructionFileReader.write("# Agents v2\n", document, to: root.path)

        XCTAssertThrowsError(
            try InstructionFileReader.write("# Agents v3\n", document, to: root.path, expectedBefore: before)
        )
        XCTAssertEqual(InstructionFileReader.read(document, from: root.path), "# Agents v2\n")
    }

    // MARK: - Helpers

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubMarkdownDiffTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func createCommandDir(root: URL, name: String, description: String) throws {
        let dir = root.appendingPathComponent(".claude/commands", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let content = CommandsReader.renderedDescription(
            description: description, argumentHint: "", allowedTools: [],
            model: "", body: "body"
        )
        try content.write(to: dir.appendingPathComponent("\(name).md"), atomically: true, encoding: .utf8)
    }

    private func commandPath(root: URL, name: String) -> String {
        root.appendingPathComponent(".claude/commands/\(name).md").path
    }

    private func createAgentFile(root: URL, name: String, description: String) throws -> String {
        let dir = root.appendingPathComponent(".claude/agents", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("\(name).md").path
        let agent = Agent(name: name, description: description, model: "sonnet", tools: [], filePath: path, body: "body")
        try AgentReader.renderedDocument(for: agent).write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }
}
