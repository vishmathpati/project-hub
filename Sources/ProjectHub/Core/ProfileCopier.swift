import Foundation

// MARK: - Options & Result

struct CopyOptions {
    var skills: Bool = true
    var agents: Bool = true
    var cursorRules: Bool = true
    var mcpServers: Bool = false
}

struct CopyResult {
    let skillsCopied: Int
    let agentsCopied: Int
    let rulesCopied: Int
    let mcpCopied: Int
    var errors: [String]
}

// MARK: - ProfileCopier

enum ProfileCopier {

    // MARK: - Preview

    /// Returns counts of copyable items in the source project without performing any writes.
    static func preview(from sourcePath: String) -> (skills: Int, agents: Int, rules: Int, mcp: Int) {
        let fm = FileManager.default

        // Skills: count dirs in .claude/skills + .agents/skills (deduplicated by folder name)
        var skillNames: Set<String> = []
        for dir in [".claude/skills", ".agents/skills"] {
            let full = (sourcePath as NSString).appendingPathComponent(dir)
            let entries = (try? fm.contentsOfDirectory(atPath: full)) ?? []
            for entry in entries {
                let entryPath = (full as NSString).appendingPathComponent(entry)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: entryPath, isDirectory: &isDir), isDir.boolValue {
                    skillNames.insert(entry)
                }
            }
        }

        // Agents: .md files in .claude/agents/
        let agentsDir = (sourcePath as NSString).appendingPathComponent(".claude/agents")
        let agentFiles = ((try? fm.contentsOfDirectory(atPath: agentsDir)) ?? [])
            .filter { $0.hasSuffix(".md") }

        // Cursor rules: .mdc files in .cursor/rules/
        let rulesDir = (sourcePath as NSString).appendingPathComponent(".cursor/rules")
        let ruleFiles = ((try? fm.contentsOfDirectory(atPath: rulesDir)) ?? [])
            .filter { $0.hasSuffix(".mdc") }

        // MCP servers: count keys in .mcp.json + .cursor/mcp.json + entries in .codex/config.toml
        var mcpCount = 0
        mcpCount += mcpJsonServerCount(at: (sourcePath as NSString).appendingPathComponent(".mcp.json"))
        mcpCount += mcpJsonServerCount(at: (sourcePath as NSString).appendingPathComponent(".cursor/mcp.json"))
        mcpCount += codexMcpServerCount(at: (sourcePath as NSString).appendingPathComponent(".codex/config.toml"))

        return (skillNames.count, agentFiles.count, ruleFiles.count, mcpCount)
    }

    // MARK: - Copy

    /// Copies selected profile components from source to target. Never overwrites existing items.
    static func copy(from sourcePath: String, to targetPath: String, options: CopyOptions) -> CopyResult {
        var skillsCopied = 0
        var agentsCopied = 0
        var rulesCopied  = 0
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

        if options.cursorRules {
            let (count, errs) = copyCursorRules(from: sourcePath, to: targetPath)
            rulesCopied = count
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
            rulesCopied:  rulesCopied,
            mcpCopied:    mcpCopied,
            errors:       errors
        )
    }

    // MARK: - Skills

    private static func copySkills(from sourcePath: String, to targetPath: String) -> (Int, [String]) {
        let fm = FileManager.default
        var copied = 0
        var errors: [String] = []

        let pairs: [(String, String)] = [
            (".claude/skills", ".claude/skills"),
            (".agents/skills", ".agents/skills"),
        ]

        for (srcRel, dstRel) in pairs {
            let srcDir = (sourcePath as NSString).appendingPathComponent(srcRel)
            let dstDir = (targetPath as NSString).appendingPathComponent(dstRel)

            guard let entries = try? fm.contentsOfDirectory(atPath: srcDir) else { continue }

            do {
                try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
            } catch {
                errors.append("Could not create \(dstRel): \(error.localizedDescription)")
                continue
            }

            for entry in entries.sorted() {
                let srcEntry = (srcDir as NSString).appendingPathComponent(entry)
                let dstEntry = (dstDir as NSString).appendingPathComponent(entry)

                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: srcEntry, isDirectory: &isDir), isDir.boolValue else { continue }
                guard !fm.fileExists(atPath: dstEntry) else { continue } // skip existing

                do {
                    try fm.copyItem(atPath: srcEntry, toPath: dstEntry)
                    copied += 1
                } catch {
                    errors.append("Could not copy skill \(entry): \(error.localizedDescription)")
                }
            }
        }

        return (copied, errors)
    }

    // MARK: - Agents

    private static func copyAgents(from sourcePath: String, to targetPath: String) -> (Int, [String]) {
        let fm = FileManager.default
        var copied = 0
        var errors: [String] = []

        let srcDir = (sourcePath as NSString).appendingPathComponent(".claude/agents")
        let dstDir = (targetPath as NSString).appendingPathComponent(".claude/agents")

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

    // MARK: - Cursor Rules

    private static func copyCursorRules(from sourcePath: String, to targetPath: String) -> (Int, [String]) {
        let fm = FileManager.default
        var copied = 0
        var errors: [String] = []

        let srcDir = (sourcePath as NSString).appendingPathComponent(".cursor/rules")
        let dstDir = (targetPath as NSString).appendingPathComponent(".cursor/rules")

        guard let entries = try? fm.contentsOfDirectory(atPath: srcDir) else {
            return (0, [])
        }

        do {
            try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        } catch {
            return (0, ["Could not create .cursor/rules: \(error.localizedDescription)"])
        }

        for entry in entries.sorted() where entry.hasSuffix(".mdc") {
            let src = (srcDir as NSString).appendingPathComponent(entry)
            let dst = (dstDir as NSString).appendingPathComponent(entry)
            guard !fm.fileExists(atPath: dst) else { continue }
            do {
                try fm.copyItem(atPath: src, toPath: dst)
                copied += 1
            } catch {
                errors.append("Could not copy rule \(entry): \(error.localizedDescription)")
            }
        }

        return (copied, errors)
    }

    // MARK: - MCP Servers

    private static func copyMCPServers(from sourcePath: String, to targetPath: String) -> (Int, [String]) {
        var totalCopied = 0
        var errors: [String] = []

        // .mcp.json
        let (c1, e1) = mergeMCPJson(
            src: (sourcePath as NSString).appendingPathComponent(".mcp.json"),
            dst: (targetPath as NSString).appendingPathComponent(".mcp.json")
        )
        totalCopied += c1
        errors += e1

        // .cursor/mcp.json
        let cursorDir = (targetPath as NSString).appendingPathComponent(".cursor")
        if !FileManager.default.fileExists(atPath: cursorDir) {
            try? FileManager.default.createDirectory(atPath: cursorDir, withIntermediateDirectories: true)
        }
        let (c2, e2) = mergeMCPJson(
            src: (sourcePath as NSString).appendingPathComponent(".cursor/mcp.json"),
            dst: (targetPath as NSString).appendingPathComponent(".cursor/mcp.json")
        )
        totalCopied += c2
        errors += e2

        // .codex/config.toml
        let codexDir = (targetPath as NSString).appendingPathComponent(".codex")
        if !FileManager.default.fileExists(atPath: codexDir) {
            try? FileManager.default.createDirectory(atPath: codexDir, withIntermediateDirectories: true)
        }
        let (c3, e3) = mergeCodexTOML(
            src: (sourcePath as NSString).appendingPathComponent(".codex/config.toml"),
            dst: (targetPath as NSString).appendingPathComponent(".codex/config.toml")
        )
        totalCopied += c3
        errors += e3

        return (totalCopied, errors)
    }

    // MARK: - JSON MCP merge

    /// Merges `mcpServers` keys from src JSON into dst JSON. Skips existing keys.
    private static func mergeMCPJson(src: String, dst: String) -> (Int, [String]) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: src) else { return (0, []) }

        guard let srcData = fm.contents(atPath: src),
              let srcJSON = try? JSONSerialization.jsonObject(with: srcData) as? [String: Any],
              let srcServers = srcJSON["mcpServers"] as? [String: Any]
        else {
            return (0, ["Could not parse mcpServers in \(src)"])
        }

        // Load or create destination JSON
        var dstJSON: [String: Any]
        if fm.fileExists(atPath: dst),
           let dstData = fm.contents(atPath: dst),
           let parsed = try? JSONSerialization.jsonObject(with: dstData) as? [String: Any] {
            dstJSON = parsed
        } else {
            dstJSON = [:]
        }

        var dstServers = dstJSON["mcpServers"] as? [String: Any] ?? [:]
        var copied = 0

        for (key, value) in srcServers {
            guard dstServers[key] == nil else { continue } // skip existing
            dstServers[key] = value
            copied += 1
        }

        guard copied > 0 else { return (0, []) }

        dstJSON["mcpServers"] = dstServers

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

    /// Returns array of (name, fullBlock) tuples for each `[mcp_servers."name"]` section.
    private static func extractTOMLMCPBlocks(from content: String) -> [(String, String)] {
        guard let headerRegex = try? NSRegularExpression(
            pattern: #"\[mcp_servers\."([^"]+)"\]"#
        ) else { return [] }

        let ns = content as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = headerRegex.matches(in: content, range: range)

        var blocks: [(String, String)] = []
        let lines = content.components(separatedBy: "\n")

        // Find line indices of each header
        var headerLineIndices: [(name: String, lineIndex: Int)] = []
        var lineStart = 0
        var lineIndex = 0
        for line in lines {
            let lineRange = NSRange(location: lineStart, length: (line as NSString).length)
            for m in matches {
                if m.range.location >= lineStart && m.range.location < lineStart + (line as NSString).length + 1 {
                    if let nameRange = Range(m.range(at: 1), in: content) {
                        headerLineIndices.append((String(content[nameRange]), lineIndex))
                    }
                }
            }
            lineStart += (line as NSString).length + 1
            lineIndex += 1
        }

        // Extract block from header line to next `[` header or EOF
        let nextSectionRegex = try? NSRegularExpression(pattern: #"^\s*\["#)
        for (i, (name, startLine)) in headerLineIndices.enumerated() {
            var endLine: Int
            if i + 1 < headerLineIndices.count {
                endLine = headerLineIndices[i + 1].lineIndex
            } else {
                endLine = lines.count
            }

            // Build the block lines
            var blockLines = [lines[startLine]]
            for idx in (startLine + 1)..<endLine {
                let l = lines[idx]
                // Stop at any new top-level section header
                if let re = nextSectionRegex {
                    let r = NSRange(location: 0, length: (l as NSString).length)
                    if re.firstMatch(in: l, range: r) != nil && l.contains("[") {
                        break
                    }
                }
                blockLines.append(l)
            }

            // Trim trailing empty lines
            while blockLines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
                blockLines.removeLast()
            }

            blocks.append((name, blockLines.joined(separator: "\n")))
        }

        return blocks
    }

    /// Returns set of names already declared in `[mcp_servers."name"]` headers.
    private static func extractTOMLMCPBlockNames(from content: String) -> Set<String> {
        guard let regex = try? NSRegularExpression(
            pattern: #"\[mcp_servers\."([^"]+)"\]"#
        ) else { return [] }

        let ns = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: ns.length))
        var names = Set<String>()
        for m in matches {
            if let r = Range(m.range(at: 1), in: content) {
                names.insert(String(content[r]))
            }
        }
        return names
    }

    // MARK: - Preview helpers

    private static func mcpJsonServerCount(at path: String) -> Int {
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = json["mcpServers"] as? [String: Any]
        else { return 0 }
        return servers.count
    }

    private static func codexMcpServerCount(at path: String) -> Int {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return 0 }
        return extractTOMLMCPBlockNames(from: content).count
    }
}
