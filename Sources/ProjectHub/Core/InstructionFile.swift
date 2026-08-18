import Foundation

struct InstructionDocument: Identifiable, Hashable {
    let relativePath: String
    let title: String

    var id: String { relativePath }

    static let projectCatalog: [InstructionDocument] = [
        .init(relativePath: "AGENTS.md", title: "AGENTS.md"),
        .init(relativePath: "AGENTS.override.md", title: "AGENTS.override.md"),
        .init(relativePath: "CLAUDE.md", title: "CLAUDE.md"),
        .init(relativePath: ".claude/CLAUDE.md", title: ".claude/CLAUDE.md"),
        .init(relativePath: "CLAUDE.local.md", title: "CLAUDE.local.md"),
        .init(relativePath: "GEMINI.md", title: "GEMINI.md"),
    ]

    func absolutePath(in projectPath: String) -> String {
        (projectPath as NSString).appendingPathComponent(relativePath)
    }

    static func preferred(in projectPath: String) -> InstructionDocument {
        present(in: projectPath).first ?? projectCatalog[0]
    }

    static func present(in projectPath: String) -> [InstructionDocument] {
        projectCatalog.filter { InstructionFileReader.exists($0, in: projectPath) }
    }
}

enum InstructionFileReader {
    static func exists(_ document: InstructionDocument, in projectPath: String) -> Bool {
        FileManager.default.fileExists(atPath: document.absolutePath(in: projectPath))
    }

    static func read(_ document: InstructionDocument, from projectPath: String) -> String? {
        let path = document.absolutePath(in: projectPath)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    static func write(_ content: String, _ document: InstructionDocument, to projectPath: String) throws {
        let path = document.absolutePath(in: projectPath)
        let folder = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
