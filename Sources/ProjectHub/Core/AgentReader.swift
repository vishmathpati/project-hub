import Foundation

// MARK: - Agent parsing helpers

enum AgentReader {

    /// Parse a `.claude/agents/<name>.md` file.
    static func parse(at filePath: String) -> Agent? {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { return nil }

        let fm = SkillReader.parseFrontmatter(content)
        let description = fm?["description"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let model       = fm?["model"]?.trimmingCharacters(in: .whitespaces) ?? "sonnet"
        let toolsStr    = fm?["tools"] ?? ""
        let tools       = toolsStr.components(separatedBy: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        let body = stripFrontmatter(from: content)

        // Infer name from filename stem if frontmatter name is absent
        let stem = ((filePath as NSString).lastPathComponent as NSString).deletingPathExtension
        let finalName = fm?["name"] ?? stem

        return Agent(
            name:        finalName,
            description: description,
            model:       model,
            tools:       tools,
            filePath:    filePath,
            body:        body
        )
    }

    /// Scan `<projectPath>/.claude/agents/` for all .md files.
    static func agents(for projectPath: String) -> [Agent] {
        let agentsDir = (projectPath as NSString)
            .appendingPathComponent(".claude/agents")
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: agentsDir) else { return [] }

        return entries
            .filter { $0.hasSuffix(".md") }
            .sorted()
            .compactMap { entry in
                let path = (agentsDir as NSString).appendingPathComponent(entry)
                return parse(at: path)
            }
    }

    /// Write a new agent .md file from a template.
    static func create(agent: AgentTemplate, in projectPath: String) throws {
        let agentsDir = (projectPath as NSString).appendingPathComponent(".claude/agents")
        let fm = FileManager.default
        if !fm.fileExists(atPath: agentsDir) {
            try fm.createDirectory(atPath: agentsDir, withIntermediateDirectories: true)
        }

        // Sanitise the name into a filename
        let filename = agent.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")))
            .joined()
        let filePath = (agentsDir as NSString).appendingPathComponent("\(filename).md")

        let toolsLine = agent.tools.isEmpty ? "" : agent.tools.joined(separator: ", ")
        let content = """
        ---
        name: \(agent.name)
        description: \(agent.description)
        model: \(agent.model)
        tools: \(toolsLine)
        ---

        (Agent instructions go here.)
        """

        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    /// Delete an agent file.
    static func delete(agentName: String, from projectPath: String) throws {
        let agentsDir = (projectPath as NSString).appendingPathComponent(".claude/agents")
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: agentsDir) else { return }

        // Find file whose frontmatter name or stem matches
        for entry in entries where entry.hasSuffix(".md") {
            let path = (agentsDir as NSString).appendingPathComponent(entry)
            if let agent = parse(at: path), agent.name == agentName {
                try fm.removeItem(atPath: path)
                return
            }
        }
    }

    // MARK: - Helpers

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
