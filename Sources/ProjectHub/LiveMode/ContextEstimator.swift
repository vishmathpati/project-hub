import Foundation

// MARK: - Token estimates

struct ContextSnapshot {
    let projectPath: String

    var skills: [SkillTokenItem]
    var mcpServers: [MCPTokenItem]
    var claudeMdTokens: Int

    // Real session token counts read from the active JSONL file.
    // -1 means "not yet known" (no JSONL / no usage data found).
    var sessionInputTokens: Int   // input_tokens (non-cached new tokens)
    var sessionCacheCreate: Int   // cache_creation_input_tokens
    var sessionCacheRead: Int     // cache_read_input_tokens
    var sessionOutputTokens: Int

    var skillsTotal: Int { skills.filter { $0.enabled }.map { $0.tokens }.reduce(0, +) }
    var mcpTotal:    Int { mcpServers.filter { $0.enabled }.map { $0.tokens }.reduce(0, +) }

    /// Total tokens occupying the context window right now (from JSONL).
    /// Falls back to static file-size estimate if JSONL data isn't available.
    var totalTokens: Int {
        let realTotal = sessionInputTokens + sessionCacheCreate + sessionCacheRead
        if realTotal > 0 { return realTotal }
        // Static fallback
        return skillsTotal + mcpTotal + claudeMdTokens + 2_000
    }

    /// Claude Code context window size (tokens).
    static let contextWindowSize = 200_000

    var usedFraction: Double {
        min(1.0, Double(totalTokens) / Double(Self.contextWindowSize))
    }

    var remainingTokens: Int {
        max(0, Self.contextWindowSize - totalTokens)
    }

    var hasRealSessionData: Bool { sessionInputTokens + sessionCacheCreate + sessionCacheRead > 0 }
}

struct SkillTokenItem: Identifiable {
    let dirName: String    // raw directory name (used for file ops)
    let name: String       // display name (from SKILL.md or dir name)
    let tokens: Int
    let path: String       // full absolute path to skill directory
    var enabled: Bool      // false if in _disabled/
    let source: String     // "project" | "global" | "plugin"

    /// Unique across all sources.
    var id: String { "\(source):\(path)" }
}

struct MCPTokenItem: Identifiable {
    let id: String       // server name
    let name: String
    let tokens: Int
    let toolID: String
    let source: String   // "project", "global"
    var enabled: Bool
}

// MARK: - Estimator

enum ContextEstimator {

    /// ~3.5 chars per token is a reasonable approximation for code/markdown.
    private static let charsPerToken: Double = 3.5

    /// Rough overhead per MCP server — connection metadata, tool list, etc.
    private static let mcpServerOverhead = 400

    private static let projectsDir: String = {
        (NSHomeDirectory() as NSString).appendingPathComponent(".claude/projects")
    }()
    private static let claudeJsonPath: String = {
        (NSHomeDirectory() as NSString).appendingPathComponent(".claude.json")
    }()
    private static let globalSkillsDir: String = {
        (NSHomeDirectory() as NSString).appendingPathComponent(".claude/skills")
    }()
    private static let pluginsJsonPath: String = {
        (NSHomeDirectory() as NSString).appendingPathComponent(".claude/plugins/installed_plugins.json")
    }()

    // MARK: - Public

    private static var staticCache: [String: StaticEstimate] = [:]
    private static let cacheLock = NSLock()

    private struct StaticEstimate {
        let skills: [SkillTokenItem]
        let mcpServers: [MCPTokenItem]
        let claudeMdTokens: Int
    }

    static func estimate(for projectPath: String, reuseStatic: Bool = true) -> ContextSnapshot {
        let session = readSessionTokens(projectPath: projectPath)
        let packed: StaticEstimate
        if reuseStatic, let cached = cachedStatic(for: projectPath) {
            packed = cached
        } else {
            packed = StaticEstimate(
                skills: estimateSkills(projectPath: projectPath),
                mcpServers: estimateMCPs(projectPath: projectPath),
                claudeMdTokens: estimateClaudeMd(projectPath: projectPath)
            )
            storeStatic(packed, for: projectPath)
        }

        return ContextSnapshot(
            projectPath:         projectPath,
            skills:              packed.skills,
            mcpServers:          packed.mcpServers,
            claudeMdTokens:      packed.claudeMdTokens,
            sessionInputTokens:  session.input,
            sessionCacheCreate:  session.cacheCreate,
            sessionCacheRead:    session.cacheRead,
            sessionOutputTokens: session.output
        )
    }

    static func invalidate(projectPath: String? = nil) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let projectPath {
            staticCache.removeValue(forKey: projectPath)
        } else {
            staticCache.removeAll()
        }
    }

    private static func cachedStatic(for projectPath: String) -> StaticEstimate? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return staticCache[projectPath]
    }

    private static func storeStatic(_ value: StaticEstimate, for projectPath: String) {
        cacheLock.lock()
        staticCache[projectPath] = value
        cacheLock.unlock()
    }

    // MARK: - Session token count (real, from JSONL)

    private static func readSessionTokens(projectPath: String) -> (input: Int, cacheCreate: Int, cacheRead: Int, output: Int) {
        let encoded = encodePath(projectPath)
        let sessionDir = (projectsDir as NSString).appendingPathComponent(encoded)
        let fm = FileManager.default

        guard let files = try? fm.contentsOfDirectory(atPath: sessionDir) else {
            return (0, 0, 0, 0)
        }

        // Find most recently CREATED .jsonl file — creation date identifies the newest session.
        // Modification date is unreliable: a just-closed session's JSONL gets a fresh mtime
        // when Claude Code flushes it on exit, making it look newer than the current session.
        var bestCdate: Date = .distantPast
        var bestJsonl: String? = nil
        for file in files {
            guard file.hasSuffix(".jsonl") else { continue }
            let path = (sessionDir as NSString).appendingPathComponent(file)
            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let cdate = attrs[.creationDate] as? Date else { continue }
            if cdate > bestCdate { bestCdate = cdate; bestJsonl = path }
        }

        guard let jsonlPath = bestJsonl else { return (0, 0, 0, 0) }

        // Read only the last 128 KB — the last assistant message is always near the end
        guard let fh = FileHandle(forReadingAtPath: jsonlPath) else { return (0, 0, 0, 0) }
        defer { try? fh.close() }

        let fileSize = (try? fh.seekToEnd()) ?? 0
        let chunkSize: UInt64 = 131_072  // 128 KB
        let readFrom = fileSize > chunkSize ? fileSize - chunkSize : 0
        try? fh.seek(toOffset: readFrom)
        let data = fh.readDataToEndOfFile()
        guard let chunk = String(data: data, encoding: .utf8) else { return (0, 0, 0, 0) }

        // Scan BACKWARDS for the last assistant message with usage data
        let lines = chunk.components(separatedBy: "\n").reversed()
        for line in lines {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  obj["type"] as? String == "assistant",
                  let msg = obj["message"] as? [String: Any],
                  let usage = msg["usage"] as? [String: Any]
            else { continue }

            let input       = usage["input_tokens"] as? Int ?? 0
            let cacheCreate = usage["cache_creation_input_tokens"] as? Int ?? 0
            let cacheRead   = usage["cache_read_input_tokens"] as? Int ?? 0
            let output      = usage["output_tokens"] as? Int ?? 0
            return (input, cacheCreate, cacheRead, output)
        }
        return (0, 0, 0, 0)
    }

    // MARK: - Skills

    private static func estimateSkills(projectPath: String) -> [SkillTokenItem] {
        SkillInventoryReader.installedSkills(for: projectPath)
            .compactMap { skill in
                makeSkillItem(
                    dir: skill.path,
                    dirName: skill.originID,
                    displayName: skill.name,
                    enabled: skill.isEnabled,
                    source: liveSkillSource(for: skill, projectPath: projectPath)
                )
            }
    }

    private static func liveSkillSource(for skill: InstalledSkill, projectPath: String) -> String {
        let path = URL(fileURLWithPath: (skill.path as NSString).expandingTildeInPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        let globalClaudeSkills = URL(fileURLWithPath: globalSkillsDir)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        let projectClaudeSkills = URL(fileURLWithPath: (projectPath as NSString).appendingPathComponent(".claude/skills"))
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path

        if path.hasPrefix(globalClaudeSkills + "/") { return "global" }
        if path.hasPrefix(projectClaudeSkills + "/") { return "project" }
        return "plugin"
    }

    private static func makeSkillItem(
        dir: String,
        dirName: String,
        displayName: String,
        enabled: Bool,
        source: String
    ) -> SkillTokenItem? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else { return nil }

        let skillMd = (dir as NSString).appendingPathComponent("SKILL.md")
        let tokens: Int

        if let attrs = try? fm.attributesOfItem(atPath: skillMd),
           let size = attrs[.size] as? Int, size > 0 {
            tokens = Int(Double(size) / charsPerToken)
        } else {
            let allMd = (try? fm.contentsOfDirectory(atPath: dir))?.filter { $0.hasSuffix(".md") } ?? []
            var totalSize = 0
            for f in allMd {
                let p = (dir as NSString).appendingPathComponent(f)
                if let attrs = try? fm.attributesOfItem(atPath: p),
                   let sz = attrs[.size] as? Int { totalSize += sz }
            }
            tokens = max(50, Int(Double(totalSize) / charsPerToken))
        }

        return SkillTokenItem(dirName: dirName, name: displayName, tokens: tokens,
                              path: dir, enabled: enabled, source: source)
    }

    // MARK: - MCPs (project + global)

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
                source:  "project",
                enabled: !server.isDisabled
            ))
        }

        let globalMcps = readGlobalMcpServers()
        let disabledGlobalNames = readGlobalMcpDisabledForProject(projectPath: projectPath)

        for name in globalMcps.sorted() {
            let key = "claude-code-global/\(name)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            let enabled = !disabledGlobalNames.contains(name)
            items.append(MCPTokenItem(
                id:      key,
                name:    name,
                tokens:  mcpServerOverhead,
                toolID:  "claude-code-global",
                source:  "global",
                enabled: enabled
            ))
        }

        return items.sorted { $0.name < $1.name }
    }

    /// All server names from the global ~/.claude.json mcpServers key.
    private static func readGlobalMcpServers() -> [String] {
        guard let data = FileManager.default.contents(atPath: claudeJsonPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = json["mcpServers"] as? [String: Any]
        else { return [] }
        return Array(servers.keys)
    }

    /// Names of global servers that are explicitly disabled for the given project.
    private static func readGlobalMcpDisabledForProject(projectPath: String) -> Set<String> {
        guard let data = FileManager.default.contents(atPath: claudeJsonPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projects = json["projects"] as? [String: Any],
              let proj = projects[projectPath] as? [String: Any],
              let disabled = proj["disabledMcpServers"] as? [String]
        else { return [] }
        return Set(disabled)
    }

    // MARK: - CLAUDE.md

    private static func estimateClaudeMd(projectPath: String) -> Int {
        let fm = FileManager.default
        var total = 0
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

    // MARK: - Path encoding (mirrors ProjectWatcher)

    static func encodePath(_ absolutePath: String) -> String {
        absolutePath
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ".", with: "-")
    }
}
