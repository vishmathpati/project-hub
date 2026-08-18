import XCTest
@testable import ProjectHub

final class InstructionFileTests: XCTestCase {
    func testWritesAndReadsSelectedInstructionFiles() throws {
        let root = try makeTempDirectory()
        let agents = InstructionDocument(relativePath: "AGENTS.md", title: "AGENTS.md")
        let nested = InstructionDocument(relativePath: ".claude/CLAUDE.md", title: ".claude/CLAUDE.md")

        XCTAssertFalse(InstructionFileReader.exists(agents, in: root.path))
        try InstructionFileReader.write("# Agents\n", agents, to: root.path)
        try InstructionFileReader.write("# Claude\n", nested, to: root.path)

        XCTAssertEqual(InstructionFileReader.read(agents, from: root.path), "# Agents\n")
        XCTAssertEqual(InstructionFileReader.read(nested, from: root.path), "# Claude\n")
        XCTAssertEqual(
            InstructionDocument.preferred(in: root.path).relativePath,
            "AGENTS.md"
        )
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubInstructionFileTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
