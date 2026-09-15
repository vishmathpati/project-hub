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

    enum WriteError: LocalizedError {
        case duplicateName(String)
        case outsideProject(String)
        case stalePreview(String)

        var errorDescription: String? {
            switch self {
            case .duplicateName(let name):
                return "An agent named \(name) already exists in this project."
            case .outsideProject(let name):
                return "\(name) is not inside this project's .claude/agents folder."
            case .stalePreview(let name):
                return "\"\(name)\" changed on disk after the preview. Review the new text before saving again."
            }
        }
    }

    /// Write a new agent .md file from a template.
    static func create(agent: AgentTemplate, in projectPath: String) throws {
        guard !agents(for: projectPath).contains(where: { $0.name == agent.name }) else {
            throw WriteError.duplicateName(agent.name)
        }

        let agentsDir = (projectPath as NSString).appendingPathComponent(".claude/agents")
        let fm = FileManager.default
        if !fm.fileExists(atPath: agentsDir) {
            try fm.createDirectory(atPath: agentsDir, withIntermediateDirectories: true)
        }

        // Sanitise the name into a filename
        let stem = agent.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).inverted)
            .joined()
        let base = stem.isEmpty ? "agent" : stem

        var filename = "\(base).md"
        var counter = 2
        while fm.fileExists(atPath: (agentsDir as NSString).appendingPathComponent(filename)) {
            filename = "\(base)-\(counter).md"
            counter += 1
        }
        let filePath = (agentsDir as NSString).appendingPathComponent(filename)

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

    /// The full file content an update would write, built without touching disk.
    static func renderedDocument(for agent: Agent) -> String {
        let toolsLine = agent.tools.isEmpty ? "" : agent.tools.joined(separator: ", ")
        let frontmatter = """
        ---
        name: \(agent.name)
        description: \(agent.description)
        model: \(agent.model)
        tools: \(toolsLine)
        ---
        """
        let trimmedBody = agent.body.trimmingCharacters(in: .newlines)
        return trimmedBody.isEmpty ? frontmatter : "\(frontmatter)\n\n\(trimmedBody)"
    }

    /// The text currently on disk. Enables a before/after preview plus a
    /// confirm-against-truth write instead of a blind overwrite.
    static func currentText(at filePath: String) -> String? {
        try? String(contentsOfFile: filePath, encoding: .utf8)
    }

    /// Rewrite an agent from the detail sheet. Refuses when the file changed
    /// since the previewed text, or when the file sits outside the project's
    /// `.claude/agents/` tree.
    static func update(_ agent: Agent, in projectPath: String, expectedBefore: String? = nil) throws {
        guard isInsideAgentsTree(agent.filePath, projectPath: projectPath) else {
            throw WriteError.outsideProject(agent.name)
        }
        let existing = currentText(at: agent.filePath) ?? ""
        if let expectedBefore, existing != expectedBefore {
            throw WriteError.stalePreview(agent.name)
        }
        let content = renderedDocument(for: agent)
        guard content != existing else { return }
        try content.write(toFile: agent.filePath, atomically: true, encoding: .utf8)
    }

    private static func isInsideAgentsTree(_ filePath: String, projectPath: String) -> Bool {
        let root = URL(fileURLWithPath: (projectPath as NSString).appendingPathComponent(".claude/agents"))
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        let target = URL(fileURLWithPath: filePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        return target.hasPrefix(root + "/")
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
