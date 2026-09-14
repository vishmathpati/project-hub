import Foundation

// MARK: - Command model

enum CommandScope: String {
    case project
    case global
}

struct SlashCommand: Identifiable {
    var id: String { "\(scope.rawValue)/\(name)" }
    let name: String            // namespaced, e.g. "git:commit" for git/commit.md
    let description: String
    let argumentHint: String
    let allowedTools: [String]
    let model: String
    let body: String            // markdown body after frontmatter
    let filePath: String
    let scope: CommandScope
}

// MARK: - CommandsReader

enum CommandsReader {

    // MARK: - Read

    /// All commands under `<projectPath>/.claude/commands/`, subdirectories namespaced.
    static func commands(for projectPath: String) -> [SlashCommand] {
        scan(root: commandsDirectory(for: projectPath), scope: .project)
    }

    /// All commands under `~/.claude/commands/`.
    static func globalCommands(home: String = NSHomeDirectory()) -> [SlashCommand] {
        scan(root: (home as NSString).appendingPathComponent(".claude/commands"), scope: .global)
    }

    // MARK: - Write

    enum WriteError: LocalizedError {
        case invalidName(String)
        case duplicateName(String)
        case outsideProject(String)

        var errorDescription: String? {
            switch self {
            case .invalidName(let name):
                return "\"\(name)\" is not a valid command name."
            case .duplicateName(let name):
                return "A command named \(name) already exists in this project."
            case .outsideProject(let name):
                return "\(name) is not inside this project's .claude/commands folder."
            }
        }
    }

    /// Write a new command .md file. Refuses to overwrite an existing one.
    static func create(
        name: String,
        description: String,
        argumentHint: String,
        allowedTools: [String],
        model: String,
        body: String,
        in projectPath: String
    ) throws {
        guard let relative = relativePath(for: name) else {
            throw WriteError.invalidName(name)
        }

        let commandsDir = commandsDirectory(for: projectPath)
        let filePath = (commandsDir as NSString).appendingPathComponent(relative)
        let fm = FileManager.default
        guard !fm.fileExists(atPath: filePath) else {
            throw WriteError.duplicateName(name)
        }

        let parent = (filePath as NSString).deletingLastPathComponent
        if !fm.fileExists(atPath: parent) {
            try fm.createDirectory(atPath: parent, withIntermediateDirectories: true)
        }

        let content = document(
            description: description,
            argumentHint: argumentHint,
            allowedTools: allowedTools,
            model: model,
            body: body
        )
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    /// Rewrite an existing command, carrying through frontmatter keys this app
    /// does not model.
    static func update(_ command: SlashCommand, in projectPath: String) throws {
        guard command.scope == .project,
              isInsideCommandsTree(command.filePath, projectPath: projectPath) else {
            throw WriteError.outsideProject(command.name)
        }

        let existing = (try? String(contentsOfFile: command.filePath, encoding: .utf8)) ?? ""
        let content = document(
            description: command.description,
            argumentHint: command.argumentHint,
            allowedTools: command.allowedTools,
            model: command.model,
            body: command.body,
            preserved: SkillReader.preservedFrontmatterLines(in: existing, excluding: editedKeys)
        )
        try content.write(toFile: command.filePath, atomically: true, encoding: .utf8)
    }

    /// Delete a project command. The resolved file path has to sit inside the
    /// project's `.claude/commands/` tree, so a symlink cannot reach elsewhere.
    static func delete(_ command: SlashCommand, from projectPath: String) throws {
        guard command.scope == .project,
              isInsideCommandsTree(command.filePath, projectPath: projectPath) else {
            throw WriteError.outsideProject(command.name)
        }
        try FileManager.default.removeItem(atPath: command.filePath)
    }

    /// Split a frontmatter `allowed-tools` value, written as a comma-separated
    /// scalar or a YAML list.
    static func allowedTools(from raw: String) -> [String] {
        raw
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.hasPrefix("- ") ? String(trimmed.dropFirst(2)) : trimmed
            }
            .filter { !$0.isEmpty }
    }

    // MARK: - Helpers

    private static let editedKeys: Set<String> = ["description", "argument-hint", "allowed-tools", "model"]

    private static func commandsDirectory(for projectPath: String) -> String {
        (projectPath as NSString).appendingPathComponent(".claude/commands")
    }

    private static func scan(root: String, scope: CommandScope) -> [SlashCommand] {
        guard let entries = FileManager.default.enumerator(atPath: root) else { return [] }

        var commands: [SlashCommand] = []
        while let relative = entries.nextObject() as? String {
            guard relative.hasSuffix(".md") else { continue }
            let path = (root as NSString).appendingPathComponent(relative)
            guard let command = parse(at: path, name: namespacedName(relative), scope: scope) else { continue }
            commands.append(command)
        }
        return commands.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func namespacedName(_ relativePath: String) -> String {
        String(relativePath.dropLast(3)).replacingOccurrences(of: "/", with: ":")
    }

    private static func parse(at filePath: String, name: String, scope: CommandScope) -> SlashCommand? {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { return nil }

        let fm = SkillReader.parseFrontmatter(content)
        return SlashCommand(
            name:         name,
            description:  fm?["description"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            argumentHint: fm?["argument-hint"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            allowedTools: allowedTools(from: fm?["allowed-tools"] ?? ""),
            model:        fm?["model"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            body:         stripFrontmatter(from: content),
            filePath:     filePath,
            scope:        scope
        )
    }

    /// "git:commit" → "git/commit.md", one directory per namespace segment.
    private static func relativePath(for name: String) -> String? {
        let segments = name
            .split(separator: ":", omittingEmptySubsequences: false)
            .map { sanitizedSegment(String($0)) }
        guard !segments.isEmpty, segments.allSatisfy({ !$0.isEmpty }) else { return nil }
        return segments.joined(separator: "/") + ".md"
    }

    private static func sanitizedSegment(_ segment: String) -> String {
        segment
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).inverted)
            .joined()
    }

    private static func document(
        description: String,
        argumentHint: String,
        allowedTools: [String],
        model: String,
        body: String,
        preserved: [String] = []
    ) -> String {
        var lines = [
            "description: \(description)",
            "argument-hint: \(argumentHint)",
            "allowed-tools: \(allowedTools.joined(separator: ", "))",
            "model: \(model)"
        ]
        lines += preserved

        let frontmatter = "---\n\(lines.joined(separator: "\n"))\n---"
        let trimmedBody = body.trimmingCharacters(in: .newlines)
        return trimmedBody.isEmpty ? frontmatter : "\(frontmatter)\n\n\(trimmedBody)"
    }

    private static func isInsideCommandsTree(_ filePath: String, projectPath: String) -> Bool {
        let root = URL(fileURLWithPath: commandsDirectory(for: projectPath))
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        let target = URL(fileURLWithPath: filePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        return target.hasPrefix(root + "/")
    }

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
