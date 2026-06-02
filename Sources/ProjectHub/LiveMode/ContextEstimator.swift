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
    let id: String       // canonical skill directory path
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
        SkillInventoryReader.installedSkills(for: projectPath)
            .compactMap { skill in
                skillItem(from: skill.path, name: skill.name, enabled: skill.isEnabled)
            }
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

        let id = URL(fileURLWithPath: (skillDir as NSString).expandingTildeInPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        return SkillTokenItem(id: id, name: displayName, tokens: tokens, path: skillDir, enabled: enabled)
    }

    // MARK: - MCPs

    private static func estimateMCPs(projectPath: String) -> [MCPTokenItem] {
        var items: [MCPTokenItem] = []
        var seen: Set<String> = []

        for server in MCPReader.servers(for: projectPath) {
            let key = server.id
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            items.append(MCPTokenItem(
                id:      key,
                name:    server.name,
                tokens:  mcpServerOverhead,
                toolID:  server.source.rawValue,
                enabled: !server.isDisabled
            ))
        }

        return items.sorted { $0.name < $1.name }
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
