import Foundation

// MARK: - Options & Result

struct CopyOptions {
    var skills: Bool = true
    var agents: Bool = true
    var mcpServers: Bool = false
}

struct CopyResult {
    let skillsCopied: Int
    let agentsCopied: Int
    let mcpCopied: Int
    var errors: [String]
}

// MARK: - ProfileCopier

enum ProfileCopier {

    // MARK: - Preview

    /// Returns counts of copyable items in the source project without performing any writes.
    static func preview(from sourcePath: String) -> (skills: Int, agents: Int, mcp: Int) {
        let fm = FileManager.default
        let sourceRoot = canonicalFilePath(ProjectRootDetector.detect(from: sourcePath))

        let skillCount = copyableSkillOrigins(from: sourcePath).count

        // Agents: .md files in .claude/agents/
        let agentsDir = (sourceRoot as NSString).appendingPathComponent(".claude/agents")
        let agentFiles = ((try? fm.contentsOfDirectory(atPath: agentsDir)) ?? [])
            .filter { $0.hasSuffix(".md") }

        // MCP servers: count project-scoped MCP configs across Claude/Codex.
        var mcpCount = 0
        mcpCount += mcpJsonServerCount(at: (sourceRoot as NSString).appendingPathComponent(".mcp.json"), key: "mcpServers")
        mcpCount += codexMcpServerCount(at: (sourceRoot as NSString).appendingPathComponent(".codex/config.toml"))

        return (skillCount, agentFiles.count, mcpCount)
    }

    // MARK: - Copy

    /// Copies selected profile components from source to target. Never overwrites existing items.
    static func copy(from sourcePath: String, to targetPath: String, options: CopyOptions) -> CopyResult {
        var skillsCopied = 0
        var agentsCopied = 0
        var mcpCopied    = 0
        var errors: [String] = []

        if options.skills {
            let (count, errs) = copySkills(from: sourcePath, to: targetPath)
            skillsCopied = count
            errors += errs
        }

        if options.agents {
            let (count, errs) = copyAgents(from: sourcePath, to: targetPath)
            agentsCopied = count
            errors += errs
        }

        if options.mcpServers {
            let (count, errs) = copyMCPServers(from: sourcePath, to: targetPath)
            mcpCopied = count
            errors += errs
        }

        return CopyResult(
            skillsCopied: skillsCopied,
            agentsCopied: agentsCopied,
            mcpCopied:    mcpCopied,
            errors:       errors
        )
    }

    // MARK: - Skills

    private static func copySkills(from sourcePath: String, to targetPath: String) -> (Int, [String]) {
        let fm = FileManager.default
        var copied = 0
        var errors: [String] = []
        let sourceRoot = canonicalFilePath(ProjectRootDetector.detect(from: sourcePath))
        let targetRoot = canonicalFilePath(ProjectRootDetector.detect(from: targetPath))
        var warningKeys = Set<String>()

        for skill in copyableSkillOrigins(from: sourcePath) {
            guard let relative = relativePath(skill.path, from: sourceRoot) else { continue }
            let dstEntry = (targetRoot as NSString).appendingPathComponent(relative)
            guard !fm.fileExists(atPath: dstEntry) else { continue }
            do {
                try fm.createDirectory(
                    atPath: (dstEntry as NSString).deletingLastPathComponent,
                    withIntermediateDirectories: true
                )
                try fm.copyItem(atPath: skill.path, toPath: dstEntry)
                copied += 1
            } catch {
                errors.append("Could not copy skill \(skill.name) from \(relative): \(error.localizedDescription)")
            }

            if skill.state != .active, warningKeys.insert("state:\(skill.path)").inserted {
                errors.append("Copied \(skill.name), but its \(skill.state.rawValue.lowercased()) policy state is not migrated automatically. Scan the target project before relying on it.")
            }
            if !isPrimaryProjectSkillPath(skill.path, projectRoot: sourceRoot),
               warningKeys.insert("root:\(skill.path)").inserted {
                errors.append("Copied \(skill.name) from \(relative). If this came from a configured additional skill directory, make sure the target tool also loads that directory.")
            }
        }

        return (copied, errors)
    }

    private static func copyableSkillOrigins(from sourcePath: String) -> [InstalledSkill] {
        SkillInventoryReader.installedSkills(for: sourcePath)
            .filter(\.canRemove)
            .sorted { lhs, rhs in
                lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
            }
    }

    private static func isPrimaryProjectSkillPath(_ path: String, projectRoot: String) -> Bool {
        let canonicalPath = canonicalFilePath(path)
        let canonicalRoot = canonicalFilePath(projectRoot)
        guard canonicalPath.hasPrefix(canonicalRoot + "/") else { return false }
        return canonicalPath.contains("/.claude/skills/")
            || canonicalPath.contains("/.agents/skills/")
    }

    // MARK: - Agents

    private static func copyAgents(from sourcePath: String, to targetPath: String) -> (Int, [String]) {
        let fm = FileManager.default
        var copied = 0
        var errors: [String] = []
        let sourceRoot = canonicalFilePath(ProjectRootDetector.detect(from: sourcePath))
        let targetRoot = canonicalFilePath(ProjectRootDetector.detect(from: targetPath))

        let srcDir = (sourceRoot as NSString).appendingPathComponent(".claude/agents")
        let dstDir = (targetRoot as NSString).appendingPathComponent(".claude/agents")

        guard let entries = try? fm.contentsOfDirectory(atPath: srcDir) else {
            return (0, [])
        }

        do {
            try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        } catch {
            return (0, ["Could not create .claude/agents: \(error.localizedDescription)"])
        }

        for entry in entries.sorted() where entry.hasSuffix(".md") {
            let src = (srcDir as NSString).appendingPathComponent(entry)
            let dst = (dstDir as NSString).appendingPathComponent(entry)
            guard !fm.fileExists(atPath: dst) else { continue } // skip existing
            do {
                try fm.copyItem(atPath: src, toPath: dst)
                copied += 1
            } catch {
                errors.append("Could not copy agent \(entry): \(error.localizedDescription)")
            }
        }

        return (copied, errors)
    }

    // MARK: - MCP Servers

    private static func copyMCPServers(from sourcePath: String, to targetPath: String) -> (Int, [String]) {
        var totalCopied = 0
        var errors: [String] = []
        let sourceRoot = canonicalFilePath(ProjectRootDetector.detect(from: sourcePath))
        let targetRoot = canonicalFilePath(ProjectRootDetector.detect(from: targetPath))

        // .mcp.json
        let (c1, e1) = mergeMCPJson(
            src: (sourceRoot as NSString).appendingPathComponent(".mcp.json"),
            dst: (targetRoot as NSString).appendingPathComponent(".mcp.json"),
            key: "mcpServers"
        )
        totalCopied += c1
        errors += e1

        // .codex/config.toml
        let codexDir = (targetRoot as NSString).appendingPathComponent(".codex")
        if !FileManager.default.fileExists(atPath: codexDir) {
            try? FileManager.default.createDirectory(atPath: codexDir, withIntermediateDirectories: true)
        }
        let (c3, e3) = mergeCodexTOML(
            src: (sourceRoot as NSString).appendingPathComponent(".codex/config.toml"),
            dst: (targetRoot as NSString).appendingPathComponent(".codex/config.toml")
        )
        totalCopied += c3
        errors += e3

        return (totalCopied, errors)
    }

    // MARK: - JSON MCP merge

    /// Merges server keys from src JSON into dst JSON. Skips existing keys.
    private static func mergeMCPJson(src: String, dst: String, key: String) -> (Int, [String]) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: src) else { return (0, []) }

        guard let srcJSON = loadJsonObject(at: src),
              let srcServers = srcJSON[key] as? [String: Any]
        else {
            return (0, ["Could not parse \(key) in \(src)"])
        }

        // Load or create destination JSON
        var dstJSON: [String: Any]
        if fm.fileExists(atPath: dst) {
            guard let parsed = loadJsonObject(at: dst) else {
                return (0, ["Could not parse existing destination JSON in \(dst)"])
            }
            dstJSON = parsed
        } else {
            dstJSON = [:]
        }

        var dstServers = dstJSON[key] as? [String: Any] ?? [:]
        var copied = 0

        for (key, value) in srcServers {
            guard dstServers[key] == nil else { continue } // skip existing
            dstServers[key] = value
            copied += 1
        }

        guard copied > 0 else { return (0, []) }

        dstJSON[key] = dstServers

        do {
            let outData = try JSONSerialization.data(withJSONObject: dstJSON, options: [.prettyPrinted, .sortedKeys])
            try outData.write(to: URL(fileURLWithPath: dst))
        } catch {
            return (0, ["Could not write \(dst): \(error.localizedDescription)"])
        }

        return (copied, [])
    }

    // MARK: - TOML MCP merge

    /// Merges `[mcp_servers."name"]` blocks from src TOML into dst TOML. Appends missing blocks.
    private static func mergeCodexTOML(src: String, dst: String) -> (Int, [String]) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: src) else { return (0, []) }

        guard let srcContent = try? String(contentsOfFile: src, encoding: .utf8) else {
            return (0, ["Could not read \(src)"])
        }

        // Extract [mcp_servers."name"] blocks from source
        let srcBlocks = extractTOMLMCPBlocks(from: srcContent)
        guard !srcBlocks.isEmpty else { return (0, []) }

        // Load destination content (or empty string)
        let dstContent: String
        if fm.fileExists(atPath: dst),
           let content = try? String(contentsOfFile: dst, encoding: .utf8) {
            dstContent = content
        } else {
            dstContent = ""
        }

        // Find which names already exist in destination
        let dstNames = extractTOMLMCPBlockNames(from: dstContent)

        var appended = 0
        var output = dstContent

        for (name, block) in srcBlocks {
            guard !dstNames.contains(name) else { continue }
            // Ensure there's a trailing newline before appending
            if !output.isEmpty && !output.hasSuffix("\n") {
                output += "\n"
            }
            output += "\n" + block
            appended += 1
        }

        guard appended > 0 else { return (0, []) }

        do {
            try output.write(toFile: dst, atomically: true, encoding: .utf8)
        } catch {
            return (0, ["Could not write \(dst): \(error.localizedDescription)"])
        }

        return (appended, [])
    }

    /// Returns array of (name, fullBlock) tuples for each Codex MCP section.
    private static func extractTOMLMCPBlocks(from content: String) -> [(String, String)] {
        var blocks: [(String, String)] = []
        let lines = content.components(separatedBy: "\n")
        var index = 0
        while index < lines.count {
            guard let identity = codexMCPSectionIdentity(in: lines[index]) else {
                index += 1
                continue
            }

            var blockLines = [lines[index]]
            var cursor = index + 1
            while cursor < lines.count {
                if let next = codexMCPSectionIdentity(in: lines[cursor]) {
                    guard next.name == identity.name else { break }
                } else if isTOMLSectionHeader(lines[cursor]) {
                    break
                }
                blockLines.append(lines[cursor])
                cursor += 1
            }

            while blockLines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
                blockLines.removeLast()
            }
            blocks.append((identity.name, blockLines.joined(separator: "\n")))
            index = cursor
        }

        return blocks
    }

    private static func codexMCPSectionIdentity(in line: String) -> (name: String, nested: String?)? {
        guard let section = tomlSectionName(from: line) else { return nil }
        let segments = tomlDottedSegments(section)
        guard segments.count >= 2,
              segments[0] == "mcp_servers",
              !segments[1].isEmpty else { return nil }
        let nested = segments.count > 2 ? segments.dropFirst(2).joined(separator: ".") : nil
        return (segments[1], nested)
    }

    private static func tomlSectionName(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("["),
              !trimmed.hasPrefix("[["),
              let close = trimmed.firstIndex(of: "]") else { return nil }
        return String(trimmed[trimmed.index(after: trimmed.startIndex)..<close])
            .trimmingCharacters(in: .whitespaces)
    }

    private static func tomlDottedSegments(_ value: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escaped = false

        for ch in value {
            if escaped {
                current.append(ch)
                escaped = false
                continue
            }
            if inDouble && ch == "\\" {
                escaped = true
                current.append(ch)
                continue
            }
            if ch == "\"", !inSingle {
                inDouble.toggle()
                continue
            }
            if ch == "'", !inDouble {
                inSingle.toggle()
                continue
            }
            if ch == ".", !inSingle, !inDouble {
                parts.append(trimTOMLSegment(current))
                current = ""
                continue
            }
            current.append(ch)
        }

        parts.append(trimTOMLSegment(current))
        return parts
    }

    private static func trimTOMLSegment(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 2,
           (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\""))
            || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    private static func isTOMLSectionHeader(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("[") && trimmed.contains("]")
    }

    /// Returns set of names already declared in Codex MCP server headers.
    private static func extractTOMLMCPBlockNames(from content: String) -> Set<String> {
        Set(extractTOMLMCPBlocks(from: content).map(\.0))
    }

    // MARK: - Preview helpers

    private static func mcpJsonServerCount(at path: String, key: String) -> Int {
        guard let json = loadJsonObject(at: path),
              let servers = json[key] as? [String: Any]
        else { return 0 }
        return servers.count
    }

    private static func loadJsonObject(at path: String) -> [String: Any]? {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let stripped = ConfigWriter.stripJsonComments(raw)
        guard let data = stripped.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func codexMcpServerCount(at path: String) -> Int {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return 0 }
        return extractTOMLMCPBlockNames(from: content).count
    }

    private static func relativePath(_ path: String, from root: String) -> String? {
        let canonicalPath = canonicalFilePath(path)
        let canonicalRoot = canonicalFilePath(root)
        guard canonicalPath == canonicalRoot || canonicalPath.hasPrefix(canonicalRoot + "/") else {
            return nil
        }
        if canonicalPath == canonicalRoot { return "" }
        return String(canonicalPath.dropFirst(canonicalRoot.count + 1))
    }

    private static func canonicalFilePath(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }
}
