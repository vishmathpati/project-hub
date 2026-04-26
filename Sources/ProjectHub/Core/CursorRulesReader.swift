import Foundation

// MARK: - Cursor Rule model

struct CursorRule: Identifiable {
    var id: String { filename }
    let filename: String      // e.g. "use-bun.mdc"
    let filePath: String      // full absolute path to the .mdc file
    let description: String
    let globs: String         // comma-separated glob patterns, empty = all files
    let alwaysApply: Bool
    let body: String          // markdown body after frontmatter
}

// MARK: - CursorRulesReader

enum CursorRulesReader {

    // MARK: - Read

    /// Return all rules from `<projectPath>/.cursor/rules/*.mdc`.
    static func rules(for projectPath: String) -> [CursorRule] {
        let rulesDir = rulesDirectory(for: projectPath)
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: rulesDir) else { return [] }

        return entries
            .filter { $0.hasSuffix(".mdc") }
            .sorted()
            .compactMap { entry in
                let path = (rulesDir as NSString).appendingPathComponent(entry)
                return parse(at: path, filename: entry)
            }
    }

    // MARK: - Write

    /// Create a new .mdc file in `<projectPath>/.cursor/rules/`.
    static func create(
        description: String,
        globs: String,
        alwaysApply: Bool,
        body: String,
        in projectPath: String
    ) throws {
        let rulesDir = rulesDirectory(for: projectPath)
        let fm = FileManager.default
        if !fm.fileExists(atPath: rulesDir) {
            try fm.createDirectory(atPath: rulesDir, withIntermediateDirectories: true)
        }

        // Derive a filename from the description
        let stem = description
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")))
            .joined()
            .prefix(60)
        let base = stem.isEmpty ? "rule" : String(stem)

        // Avoid collisions
        var filename = "\(base).mdc"
        var counter = 2
        while fm.fileExists(atPath: (rulesDir as NSString).appendingPathComponent(filename)) {
            filename = "\(base)-\(counter).mdc"
            counter += 1
        }

        let filePath = (rulesDir as NSString).appendingPathComponent(filename)
        let content  = buildContent(description: description, globs: globs, alwaysApply: alwaysApply, body: body)
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    /// Delete a .mdc file by filename.
    static func delete(filename: String, from projectPath: String) throws {
        let path = (rulesDirectory(for: projectPath) as NSString).appendingPathComponent(filename)
        try FileManager.default.removeItem(atPath: path)
    }

    /// Overwrite an existing .mdc file with updated content.
    static func update(
        rule: CursorRule,
        description: String,
        globs: String,
        alwaysApply: Bool,
        body: String
    ) throws {
        let content = buildContent(description: description, globs: globs, alwaysApply: alwaysApply, body: body)
        try content.write(toFile: rule.filePath, atomically: true, encoding: .utf8)
    }

    // MARK: - Helpers

    private static func rulesDirectory(for projectPath: String) -> String {
        (projectPath as NSString).appendingPathComponent(".cursor/rules")
    }

    private static func parse(at filePath: String, filename: String) -> CursorRule? {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { return nil }

        let fm          = SkillReader.parseFrontmatter(content)
        let description = fm?["description"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let globs       = fm?["globs"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let alwaysApply = fm?["alwaysApply"].flatMap { Bool($0) } ?? false
        let body        = stripFrontmatter(from: content)

        return CursorRule(
            filename:    filename,
            filePath:    filePath,
            description: description,
            globs:       globs,
            alwaysApply: alwaysApply,
            body:        body
        )
    }

    private static func buildContent(
        description: String,
        globs: String,
        alwaysApply: Bool,
        body: String
    ) -> String {
        let globLine = globs.isEmpty ? "globs: \"\"\n" : "globs: \"\(globs)\"\n"
        let fm = "---\ndescription: \(description)\n\(globLine)alwaysApply: \(alwaysApply)\n---"
        let trimmedBody = body.trimmingCharacters(in: .newlines)
        return trimmedBody.isEmpty ? fm : "\(fm)\n\n\(trimmedBody)"
    }

    /// Strip YAML frontmatter from .mdc content (same pattern as AgentReader.stripFrontmatter).
    private static func stripFrontmatter(from content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return content }

        var pastSecondDash = false
        var bodyLines: [String] = []
        var dashCount = 0

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                dashCount += 1
                if dashCount == 2 { pastSecondDash = true; continue }
            }
            if pastSecondDash { bodyLines.append(line) }
        }
        return bodyLines.joined(separator: "\n").trimmingCharacters(in: .newlines)
    }
}
