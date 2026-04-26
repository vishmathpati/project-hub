import Foundation

// MARK: - CLAUDE.md reader/writer (v0.5)

enum ClaudeMdReader {

    // MARK: - File path

    private static func filePath(for projectPath: String) -> String {
        (projectPath as NSString).appendingPathComponent("CLAUDE.md")
    }

    // MARK: - Public API

    static func exists(at projectPath: String) -> Bool {
        FileManager.default.fileExists(atPath: filePath(for: projectPath))
    }

    static func read(from projectPath: String) -> String? {
        let path = filePath(for: projectPath)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    static func write(_ content: String, to projectPath: String) throws {
        let path = filePath(for: projectPath)
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    // MARK: - Templates

    static let templates: [(name: String, content: String)] = [
        (
            "Blank",
            "# Project Instructions\n\n"
        ),
        (
            "Minimal",
            """
            # Project Instructions

            ## Stack
            -

            ## Commands
            - Build:
            - Test:
            - Dev:

            ## Rules
            -
            """
        ),
        (
            "Full",
            """
            # Project Instructions

            ## Overview
            What this project does.

            ## Stack
            - Language:
            - Framework:
            - Database:

            ## Commands
            - Build: `...`
            - Test: `...`
            - Dev: `...`
            - Deploy: `...`

            ## File Structure
            ```
            src/       — source code
            tests/     — test files
            ```

            ## Rules
            -
            -

            ## Architecture
            Key decisions and patterns.

            ## Do Not
            -
            """
        ),
    ]
}
