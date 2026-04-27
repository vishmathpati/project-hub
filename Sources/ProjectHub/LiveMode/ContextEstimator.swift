import Foundation

// MARK: - Token estimates

struct ContextSnapshot {
    let projectPath: String

    var skills: [SkillTokenItem]
    var mcpServers: [MCPTokenItem]
    var claudeMdTokens: Int
    var systemPromptTokens: Int

    var skillsTotal: Int { skills.filter { $0.enabled }.map { $0.tokens }.reduce(0, +) }
    var mcpTotal:    Int { mcpServers.filter { $0.enabled }.map { $0.tokens }.reduce(0, +) }

    var totalTokens: Int {
        skillsTotal + mcpTotal + claudeMdTokens + systemPromptTokens
    }

    /// Claude Code context window size (tokens).
    static let contextWindowSize = 200_000

    var usedFraction: Double {
        min(1.0, Double(totalTokens) / Double(Self.contextWindowSize))
    }

    var remainingTokens: Int {
        max(0, Self.contextWindowSize - totalTokens)
    }
}

struct SkillTokenItem: Identifiable {
    let id: String       // skill dir name
    let name: String
    let tokens: Int
    let path: String
    var enabled: Bool    // false if in _disabled/
}

struct MCPTokenItem: Identifiable {
    let id: String       // server name
    let name: String
    let tokens: Int
    let toolID: String   // which AI tool config this came from
    var enabled: Bool    // false if server is disabled
}

// MARK: - Estimator

enum ContextEstimator {

    /// ~3.5 chars per token is a reasonable approximation for code/markdown.
    private static let charsPerToken: Double = 3.5

    /// Rough overhead per MCP server — connection metadata, tool list, etc.
    private static let mcpServerOverhead = 400

    /// Claude Code fixed system prompt estimate.
    private static let systemPromptTokens = 2_000

    // MARK: - Public

    static func estimate(for projectPath: String) -> ContextSnapshot {
        let skills    = estimateSkills(projectPath: projectPath)
        let mcps      = estimateMCPs(projectPath: projectPath)
        let claudeMd  = estimateClaudeMd(projectPath: projectPath)

        return ContextSnapshot(
            projectPath:       projectPath,
            skills:            skills,
            mcpServers:        mcps,
            claudeMdTokens:    claudeMd,
            systemPromptTokens: systemPromptTokens
        )
    }

    // MARK: - Skills

    private static func estimateSkills(projectPath: String) -> [SkillTokenItem] {
        let fm = FileManager.default
        let skillsDir = (projectPath as NSString).appendingPathComponent(".claude/skills")

        guard let entries = try? fm.contentsOfDirectory(atPath: skillsDir) else { return [] }

        var items: [SkillTokenItem] = []

        for entry in entries.sorted() {
            let isDisabledParent = entry == "_disabled"
            if isDisabledParent {
                // Recurse into _disabled to show disabled skills
                let disabledDir = (skillsDir as NSString).appendingPathComponent("_disabled")
                if let disabledEntries = try? fm.contentsOfDirectory(atPath: disabledDir) {
                    for dEntry in disabledEntries.sorted() {
                        let skillDir = (disabledDir as NSString).appendingPathComponent(dEntry)
                        if let item = skillItem(from: skillDir, name: dEntry, enabled: false) {
                            items.append(item)
                        }
                    }
                }
                continue
            }

            let skillDir = (skillsDir as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: skillDir, isDirectory: &isDir), isDir.boolValue else { continue }

            if let item = skillItem(from: skillDir, name: entry, enabled: true) {
                items.append(item)
            }
        }

        return items
    }

    private static func skillItem(from skillDir: String, name: String, enabled: Bool) -> SkillTokenItem? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: skillDir, isDirectory: &isDir), isDir.boolValue else { return nil }

        let skillMd = (skillDir as NSString).appendingPathComponent("SKILL.md")
        let tokens: Int

        if let attrs = try? fm.attributesOfItem(atPath: skillMd),
           let size = attrs[.size] as? Int, size > 0 {
            tokens = Int(Double(size) / charsPerToken)
        } else {
            // Fallback: sum all .md files in the skill directory
            let allMd = (try? fm.contentsOfDirectory(atPath: skillDir))?.filter { $0.hasSuffix(".md") } ?? []
            var totalSize = 0
            for f in allMd {
                let p = (skillDir as NSString).appendingPathComponent(f)
                if let attrs = try? fm.attributesOfItem(atPath: p),
                   let sz = attrs[.size] as? Int {
                    totalSize += sz
                }
            }
            tokens = max(50, Int(Double(totalSize) / charsPerToken))
        }

        // Try to parse name from SKILL.md frontmatter
        let displayName: String
        if let parsed = SkillReader.parse(at: skillMd), !parsed.name.isEmpty {
            displayName = parsed.name
        } else {
            displayName = name
        }

        return SkillTokenItem(id: name, name: displayName, tokens: tokens, path: skillDir, enabled: enabled)
    }

    // MARK: - MCPs

    private static func estimateMCPs(projectPath: String) -> [MCPTokenItem] {
        // Read project-scope .mcp.json
        let projectMcps = MCPReader.fromClaudeCode(projectPath)

        // Also check for disabled servers in .mcp.json (under "mcpServers_disabled")
        let disabledNames = readDisabledServerNames(projectPath: projectPath)

        var items: [MCPTokenItem] = []
        var seen: Set<String> = []

        for info in projectMcps {
            guard !seen.contains(info.name) else { continue }
            seen.insert(info.name)
            let enabled = !disabledNames.contains(info.name)
            items.append(MCPTokenItem(
                id:      info.name,
                name:    info.name,
                tokens:  mcpServerOverhead,
                toolID:  info.source.rawValue,
                enabled: enabled
            ))
        }

        return items.sorted { $0.name < $1.name }
    }

    private static func readDisabledServerNames(projectPath: String) -> Set<String> {
        let jsonPath = (projectPath as NSString).appendingPathComponent(".mcp.json")
        guard let data = FileManager.default.contents(atPath: jsonPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let disabled = json["mcpServers_disabled"] as? [String: Any]
        else { return [] }
        return Set(disabled.keys)
    }

    // MARK: - CLAUDE.md

    private static func estimateClaudeMd(projectPath: String) -> Int {
        let fm = FileManager.default
        var total = 0

        // Check both .claude/CLAUDE.md and project root CLAUDE.md
        let candidates = [
            (projectPath as NSString).appendingPathComponent("CLAUDE.md"),
            (projectPath as NSString).appendingPathComponent(".claude/CLAUDE.md"),
        ]
        for path in candidates {
            if let attrs = try? fm.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int {
                total += Int(Double(size) / charsPerToken)
            }
        }
        return total
    }
}
