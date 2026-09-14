import Foundation

// MARK: - Diagnostics models

struct DiagnosticsReport {
    let generatedAt: Date
    let projectRoot: String?
    let probes: [DiagnosticsPathProbe]
    let findings: [DiagnosticsStaleFinding]
    let overrides: [DiagnosticsEnvironmentOverride]
}

struct DiagnosticsPathProbe: Identifiable {
    enum Kind: String {
        case path = "Path"
        case skillRoot = "Skills"
        case mcpConfig = "MCP config"
        case agentRoot = "Agents"
        case instructionFile = "Instruction"
    }

    var id: String { path }

    let toolID: String?
    let label: String
    let path: String
    let kind: Kind
    let exists: Bool
    let isSymlink: Bool
    let byteSize: Int64?
    let modifiedAt: Date?
    let itemCount: Int?
    let parseFailure: String?
    let skipped: Bool
}

struct DiagnosticsStaleFinding: Identifiable {
    enum Kind: String {
        case mcpServer = "MCP server"
        case skill = "Skill"
        case agent = "Agent"
        case hook = "Hook"
        case instruction = "Instruction"
    }

    var id: String { "\(kind.rawValue)|\(file)|\(explanation)" }

    let severity: CompatibilityIssueSeverity
    let kind: Kind
    let toolID: String?
    let file: String
    let explanation: String
}

struct DiagnosticsEnvironmentOverride: Identifiable {
    var id: String { name }

    let name: String
    let value: String
    let affects: String
}

// MARK: - Doctor scan

enum DiagnosticsReader {

    /// One scan at a time: a second call while a scan is running joins that scan
    /// instead of starting another.
    static func scan(projectRoot: String?) async -> DiagnosticsReport {
        let (id, task) = gate.begin {
            Task.detached(priority: .utility) { run(projectRoot: projectRoot) }
        }
        let report = await task.value
        gate.end(id)
        return report
    }

    // Stores reach tens of gigabytes, so a scan lists each root one level deep and
    // never walks it; session and project trees are never entered.

    private static let maxFileBytes: Int64 = 8 * 1024 * 1024
    private static let maxDirectoryEntries = 1_000
    private static let maxScanWork = 20_000

    private static let gate = DiagnosticsScanGate()

    private struct Candidate {
        let toolID: String?
        let label: String
        let path: String
        let kind: DiagnosticsPathProbe.Kind
        var mcpScope: ConfigScope? = nil
        var mcpProjectRoot: String? = nil
    }

    private static let projectAgentDirectories: [(relative: String, label: String, toolID: String)] = [
        (".claude/agents", "Claude Code agent files", "claude-code"),
        (".cursor/agents", "Cursor agent files", "cursor"),
        (".opencode/agents", "OpenCode agent files", "opencode"),
        (".commandcode/agents", "Command Code agent files", "command-code"),
    ]

    private static func run(projectRoot: String?) -> DiagnosticsReport {
        let home = NSHomeDirectory()
        let budget = DiagnosticsScanBudget(limit: maxScanWork)
        var findings: [DiagnosticsStaleFinding] = []
        var probes: [DiagnosticsPathProbe] = []

        for candidate in candidates(home: home, projectRoot: projectRoot) {
            probes.append(probe(candidate, budget: budget, findings: &findings))
        }
        findings.append(contentsOf: hookFindings(projectRoot: projectRoot, home: home))

        probes.sort { lhs, rhs in
            if lhs.exists != rhs.exists { return lhs.exists }
            let order = lhs.label.localizedCaseInsensitiveCompare(rhs.label)
            if order != .orderedSame { return order == .orderedAscending }
            return lhs.path < rhs.path
        }
        findings.sort { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
            if lhs.file != rhs.file { return lhs.file < rhs.file }
            return lhs.explanation < rhs.explanation
        }

        return DiagnosticsReport(
            generatedAt: Date(),
            projectRoot: projectRoot,
            probes: probes,
            findings: findings,
            overrides: environmentOverrides()
        )
    }

    // MARK: - Probe candidates

    private static func candidates(home: String, projectRoot: String?) -> [Candidate] {
        var list: [Candidate] = []

        for spec in ProviderCatalog.specs(home: home) {
            list.append(Candidate(toolID: spec.id, label: "\(spec.name) home", path: spec.globalHome, kind: .path))
            for path in spec.detectPaths {
                list.append(Candidate(toolID: spec.id, label: "\(spec.name) install", path: path, kind: .path))
            }
            for path in spec.globalSkillDirs {
                list.append(Candidate(toolID: spec.id, label: "\(spec.name) skills", path: path, kind: .skillRoot))
            }
            if let configPath = ToolSpecs.spec(for: spec.id, scope: .user, projectRoot: nil)?.path {
                list.append(Candidate(toolID: spec.id, label: "\(spec.name) MCP config", path: configPath, kind: .mcpConfig, mcpScope: .user))
            }
            for path in agentRoots(spec) {
                list.append(Candidate(toolID: spec.id, label: "\(spec.name) agent files", path: path, kind: .agentRoot))
            }
        }

        let codexHome = ProjectHubPaths.codexHome(home: home)
        list.append(Candidate(toolID: "claude-code", label: "Claude Code hooks", path: "\(home)/.claude/settings.json", kind: .path))
        list.append(Candidate(toolID: "codex", label: "Codex hooks", path: "\(codexHome)/hooks.json", kind: .path))

        if let root = projectRoot {
            for spec in ProviderCatalog.specs(home: home) {
                for relative in spec.projectSkillDirs {
                    list.append(Candidate(toolID: spec.id, label: "\(spec.name) project skills", path: join(root, relative), kind: .skillRoot))
                }
                for relative in spec.instructionFiles {
                    list.append(Candidate(toolID: spec.id, label: relative, path: join(root, relative), kind: .instructionFile))
                }
                for relative in spec.extraProjectDirs {
                    list.append(Candidate(toolID: spec.id, label: "\(spec.name) project path", path: join(root, relative), kind: .path))
                }
                if let configPath = ToolSpecs.spec(for: spec.id, scope: .project, projectRoot: root)?.path {
                    list.append(Candidate(toolID: spec.id, label: "\(spec.name) project MCP config", path: configPath, kind: .mcpConfig, mcpScope: .project, mcpProjectRoot: root))
                }
            }
            for entry in projectAgentDirectories {
                list.append(Candidate(toolID: entry.toolID, label: entry.label, path: join(root, entry.relative), kind: .agentRoot))
            }
            list.append(Candidate(toolID: "claude-code", label: "Claude Code hooks", path: join(root, ".claude/settings.json"), kind: .path))
            list.append(Candidate(toolID: "claude-code", label: "Claude Code hooks", path: join(root, ".claude/settings.local.json"), kind: .path))
            list.append(Candidate(toolID: "codex", label: "Codex hooks", path: join(root, ".codex/hooks.json"), kind: .path))
        }

        return dedupe(list)
    }

    private static func agentRoots(_ spec: ProviderCatalog.Spec) -> [String] {
        switch spec.id {
        case "claude-code", "cursor", "opencode", "command-code":
            return [join(spec.globalHome, "agents")]
        case "pi":
            return [join(spec.globalHome, "extensions")]
        default:
            return []
        }
    }

    private static func dedupe(_ candidates: [Candidate]) -> [Candidate] {
        var order: [String] = []
        var byPath: [String: Candidate] = [:]
        for candidate in candidates {
            let key = URL(fileURLWithPath: candidate.path).standardizedFileURL.path
            if let existing = byPath[key] {
                if kindRank(candidate.kind) > kindRank(existing.kind) {
                    byPath[key] = candidate
                }
                continue
            }
            byPath[key] = candidate
            order.append(key)
        }
        return order.compactMap { byPath[$0] }
    }

    private static func kindRank(_ kind: DiagnosticsPathProbe.Kind) -> Int {
        switch kind {
        case .skillRoot:       return 4
        case .mcpConfig:       return 3
        case .agentRoot:       return 2
        case .instructionFile: return 1
        case .path:            return 0
        }
    }

    // MARK: - Probing

    private static func probe(_ candidate: Candidate, budget: DiagnosticsScanBudget, findings: inout [DiagnosticsStaleFinding]) -> DiagnosticsPathProbe {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        let exists = fm.fileExists(atPath: candidate.path, isDirectory: &isDirectory)
        let isSymlink = (try? fm.destinationOfSymbolicLink(atPath: candidate.path)) != nil
        let attributes = try? fm.attributesOfItem(atPath: candidate.path)
        let modifiedAt: Date? = exists ? attributes?[.modificationDate] as? Date : nil
        let byteSize: Int64? = exists && !isDirectory.boolValue ? (attributes?[.size] as? NSNumber)?.int64Value : nil

        var itemCount: Int?
        var parseFailure: String?
        var skipped = false

        switch candidate.kind {
        case .path:
            if exists, isDirectory.boolValue {
                let listing = listDirectory(candidate.path, budget: budget)
                itemCount = listing.count
                parseFailure = listing.failure
                skipped = listing.skipped
            }
        case .skillRoot:
            if exists, isDirectory.boolValue {
                let outcome = scanSkillRoot(candidate, budget: budget, findings: &findings)
                itemCount = outcome.parsed
                parseFailure = outcome.failure
                skipped = outcome.skipped
            }
        case .mcpConfig:
            if exists, !isDirectory.boolValue {
                if let size = byteSize, size > maxFileBytes {
                    skipped = true
                } else {
                    let outcome = scanMCPConfig(candidate, budget: budget, findings: &findings)
                    itemCount = outcome.count
                    parseFailure = outcome.failure
                    skipped = outcome.skipped
                }
            }
        case .agentRoot:
            if exists, isDirectory.boolValue {
                let outcome = scanAgentRoot(candidate, budget: budget, findings: &findings)
                itemCount = outcome.parsed
                parseFailure = outcome.failure
                skipped = outcome.skipped
            }
        case .instructionFile:
            if !exists {
                if isSymlink {
                    findings.append(DiagnosticsStaleFinding(
                        severity: .error,
                        kind: .instruction,
                        toolID: candidate.toolID,
                        file: candidate.path,
                        explanation: "\(candidate.label) is a symlink to a file that no longer exists"
                    ))
                }
            } else if !isDirectory.boolValue {
                if let size = byteSize, size > maxFileBytes {
                    skipped = true
                } else {
                    let readable = (try? String(contentsOfFile: candidate.path, encoding: .utf8)) != nil
                    itemCount = readable ? 1 : nil
                    parseFailure = readable ? nil : "Not readable as UTF-8"
                }
            }
        }

        return DiagnosticsPathProbe(
            toolID: candidate.toolID,
            label: candidate.label,
            path: candidate.path,
            kind: candidate.kind,
            exists: exists,
            isSymlink: isSymlink,
            byteSize: byteSize,
            modifiedAt: modifiedAt,
            itemCount: itemCount,
            parseFailure: parseFailure,
            skipped: skipped
        )
    }

    private static func listDirectory(_ path: String, budget: DiagnosticsScanBudget) -> (count: Int?, failure: String?, skipped: Bool) {
        guard budget.take(1) else { return (nil, nil, true) }
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return (nil, "Directory listing failed", false)
        }
        _ = budget.take(names.count)
        return (names.count, nil, false)
    }

    private static func scanSkillRoot(_ candidate: Candidate, budget: DiagnosticsScanBudget, findings: inout [DiagnosticsStaleFinding]) -> (parsed: Int?, failure: String?, skipped: Bool) {
        let fm = FileManager.default
        let directSkillMD = (candidate.path as NSString).appendingPathComponent("SKILL.md")
        var directories: [(name: String, path: String)] = []
        if fm.fileExists(atPath: directSkillMD) {
            directories = [((candidate.path as NSString).lastPathComponent, candidate.path)]
        } else {
            guard budget.take(1), let entries = try? fm.contentsOfDirectory(atPath: candidate.path) else { return (nil, nil, true) }
            guard entries.count <= maxDirectoryEntries else { return (nil, nil, true) }
            _ = budget.take(entries.count)
            directories = entries.sorted().compactMap { entry -> (name: String, path: String)? in
                let directory = (candidate.path as NSString).appendingPathComponent(entry)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: directory, isDirectory: &isDir), isDir.boolValue else { return nil }
                return (entry, directory)
            }
        }

        var parsed = 0
        var unparsed = 0
        var oversized = 0
        var skipped = false
        for directory in directories {
            let skillMD = (directory.path as NSString).appendingPathComponent("SKILL.md")
            guard fm.fileExists(atPath: skillMD) else {
                findings.append(DiagnosticsStaleFinding(
                    severity: .warning,
                    kind: .skill,
                    toolID: candidate.toolID,
                    file: skillMD,
                    explanation: "\(directory.name) is a folder in a skill root but has no SKILL.md"
                ))
                continue
            }
            guard budget.take(1) else {
                skipped = true
                break
            }
            if let size = fileSize(skillMD), size > maxFileBytes {
                oversized += 1
                continue
            }
            if SkillReader.parse(at: skillMD) != nil {
                parsed += 1
            } else {
                unparsed += 1
            }
        }

        var notes: [String] = []
        if unparsed > 0 { notes.append("\(unparsed) of \(directories.count) SKILL.md files did not parse") }
        if oversized > 0 { notes.append("\(oversized) larger than 8 MB") }
        return (parsed, notes.isEmpty ? nil : notes.joined(separator: " · "), skipped)
    }

    private static func scanAgentRoot(_ candidate: Candidate, budget: DiagnosticsScanBudget, findings: inout [DiagnosticsStaleFinding]) -> (parsed: Int?, failure: String?, skipped: Bool) {
        guard budget.take(1), let entries = try? FileManager.default.contentsOfDirectory(atPath: candidate.path) else { return (nil, nil, true) }
        guard entries.count <= maxDirectoryEntries else { return (nil, nil, true) }
        _ = budget.take(entries.count)

        var parsed = 0
        var malformed = 0
        var unreadable = 0
        var skipped = false
        for name in entries.filter({ $0.hasSuffix(".md") }).sorted() {
            guard budget.take(1) else {
                skipped = true
                break
            }
            let path = (candidate.path as NSString).appendingPathComponent(name)
            guard let size = fileSize(path), size <= maxFileBytes,
                  let content = try? String(contentsOfFile: path, encoding: .utf8) else {
                unreadable += 1
                continue
            }
            if SkillReader.parseFrontmatter(content) == nil {
                malformed += 1
                findings.append(DiagnosticsStaleFinding(
                    severity: .warning,
                    kind: .agent,
                    toolID: candidate.toolID,
                    file: path,
                    explanation: "\(name) has no frontmatter Project Hub can parse"
                ))
            } else {
                parsed += 1
            }
        }

        var notes: [String] = []
        if malformed > 0 { notes.append("\(malformed) agent files have malformed frontmatter") }
        if unreadable > 0 { notes.append("\(unreadable) agent files could not be read") }
        return (parsed, notes.isEmpty ? nil : notes.joined(separator: " · "), skipped)
    }

    private static func scanMCPConfig(_ candidate: Candidate, budget: DiagnosticsScanBudget, findings: inout [DiagnosticsStaleFinding]) -> (count: Int?, failure: String?, skipped: Bool) {
        guard let toolID = candidate.toolID else { return (nil, nil, true) }
        let scope = candidate.mcpScope ?? .user
        let servers = ConfigWriter.readAllServerEntries(toolID: toolID, scope: scope, projectRoot: candidate.mcpProjectRoot)

        for server in servers {
            let report = MCPHealthChecker.evaluate(server: server, toolID: toolID, configPath: candidate.path)
            guard report.status == .broken else { continue }
            findings.append(DiagnosticsStaleFinding(
                severity: .error,
                kind: .mcpServer,
                toolID: toolID,
                file: candidate.path,
                explanation: "\(server.name): \(report.summary)"
            ))
        }

        return (servers.count, jsonParseFailure(candidate, toolID: toolID, scope: scope, budget: budget), false)
    }

    private static func jsonParseFailure(_ candidate: Candidate, toolID: String, scope: ConfigScope, budget: DiagnosticsScanBudget) -> String? {
        guard let spec = ToolSpecs.spec(for: toolID, scope: scope, projectRoot: candidate.mcpProjectRoot) else { return nil }
        switch spec.kind {
        case .json, .jsonNested:
            break
        case .toml, .yaml:
            return nil
        }
        guard budget.take(1), let raw = try? String(contentsOfFile: candidate.path, encoding: .utf8) else { return nil }
        let stripped = ConfigWriter.stripJsonComments(raw)
        guard let data = stripped.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            return "Not valid JSON"
        }
        return nil
    }

    // MARK: - Hooks

    private static func hookFindings(projectRoot: String?, home: String) -> [DiagnosticsStaleFinding] {
        // HooksReader reads its own source files, so skip the pass when one of them
        // is too large to read safely.
        guard hookSourceFiles(projectRoot: projectRoot, home: home).allSatisfy({ (fileSize($0) ?? 0) <= maxFileBytes }) else { return [] }

        // With no project selected only the global hook files exist, and "/" has no
        // project-level ones.
        var findings: [DiagnosticsStaleFinding] = []
        for hook in HooksReader.hooks(for: projectRoot ?? "/") {
            guard let binary = hookBinary(hook.command) else { continue }
            let probe = ServerEntry(
                name: hook.event,
                transport: "stdio",
                command: binary,
                args: [],
                url: nil,
                env: [:],
                headers: [:],
                bearerTokenEnvVar: nil
            )
            let report = MCPHealthChecker.evaluate(server: probe, toolID: hookToolID(hook.tool))
            guard report.status == .broken else { continue }
            findings.append(DiagnosticsStaleFinding(
                severity: .error,
                kind: .hook,
                toolID: hookToolID(hook.tool),
                file: hookSourcePath(hook, projectRoot: projectRoot, home: home),
                explanation: "\(hook.tool) \(hook.event) hook: \(report.summary)"
            ))
        }
        return findings
    }

    /// Shell built-ins resolve without a binary on disk, so a PATH lookup would
    /// read them as missing.
    private static let shellBuiltins: Set<String> = [
        "cd", "export", "source", "eval", "exec", "set", "unset", "alias", "read", "local", "trap", "wait"
    ]

    private static func hookBinary(_ command: String) -> String? {
        let launch = MCPLaunchNormalizer.launch(command: command, args: [])
        guard let raw = launch.command?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let binary = raw.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? raw
        guard binary.rangeOfCharacter(from: CharacterSet(charactersIn: "\"'|&;<>()=$`\\*?[]{}!")) == nil else { return nil }
        guard !shellBuiltins.contains(binary) else { return nil }
        return binary
    }

    private static func hookToolID(_ tool: String) -> String {
        tool.contains("Codex") ? "codex" : "claude-code"
    }

    private static func hookSourcePath(_ hook: HookEntry, projectRoot: String?, home: String) -> String {
        let root = projectRoot ?? ""
        let candidates: [String]
        if hook.tool == "Codex" {
            let codexHome = ProjectHubPaths.codexHome(home: home)
            candidates = hook.scope == "project"
                ? [join(root, ".codex/hooks.json"), join(root, ".codex/config.toml")]
                : ["\(codexHome)/hooks.json", "\(codexHome)/config.toml"]
        } else {
            candidates = hook.scope == "project"
                ? [join(root, ".claude/settings.json"), join(root, ".claude/settings.local.json")]
                : ["\(home)/.claude/settings.json"]
        }
        return candidates.first { fileContains($0, text: hook.command) } ?? candidates.first ?? ""
    }

    private static func hookSourceFiles(projectRoot: String?, home: String) -> [String] {
        let codexHome = ProjectHubPaths.codexHome(home: home)
        var files = ["\(home)/.claude/settings.json", join(codexHome, "hooks.json"), join(codexHome, "config.toml")]
        if let root = projectRoot {
            files += [
                join(root, ".claude/settings.json"),
                join(root, ".claude/settings.local.json"),
                join(root, ".codex/hooks.json"),
                join(root, ".codex/config.toml"),
            ]
        }
        return files
    }

    private static func fileContains(_ path: String, text: String) -> Bool {
        guard let size = fileSize(path), size <= maxFileBytes,
              let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return false }
        return raw.contains(text)
    }

    // MARK: - Environment overrides

    private static func environmentOverrides() -> [DiagnosticsEnvironmentOverride] {
        let environment = ProcessInfo.processInfo.environment
        let tracked: [(name: String, affects: String)] = [
            ("PROJECTHUB_CLAUDE_HOME", "Claude home behind settings and MCP approval state"),
            ("CLAUDE_CONFIG_DIR", "Claude config directory when PROJECTHUB_CLAUDE_HOME is unset"),
            ("PROJECTHUB_CLAUDE_JSON_PATH", "Claude Code state file read for MCP servers"),
            ("PROJECTHUB_CLAUDE_DESKTOP_SUPPORT_DIR", "Claude Desktop support directory"),
            ("PROJECTHUB_CLAUDE_CODE_MANAGED_DIR", "Claude Code managed settings directory"),
            ("PROJECTHUB_MANAGED_PREFERENCES_DIR", "Managed preferences directory"),
            ("PROJECTHUB_CLAUDE_CODE_SERVER_MANAGED_SETTINGS_PATH", "Server-managed Claude Code settings file"),
            ("CODEX_HOME", "Codex home"),
            ("PROJECTHUB_CODEX_REQUIREMENTS_PATH", "Codex admin requirements file"),
            ("PROJECTHUB_AGENTS_HOME", "Shared ~/.agents skills home"),
            ("PROJECTHUB_CLAUDE_DESKTOP_LOGS_DIR", "Claude Desktop logs directory"),
        ]
        return tracked.compactMap { entry in
            guard let value = environment[entry.name]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return nil }
            return DiagnosticsEnvironmentOverride(name: entry.name, value: value, affects: entry.affects)
        }
    }

    // MARK: - Helpers

    private static func join(_ base: String, _ relative: String) -> String {
        (base as NSString).appendingPathComponent(relative)
    }

    private static func fileSize(_ path: String) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else { return nil }
        return (attributes[.size] as? NSNumber)?.int64Value
    }
}

// MARK: - Scan plumbing

private final class DiagnosticsScanGate: @unchecked Sendable {
    private let lock = NSLock()
    private var inFlight: (id: UUID, task: Task<DiagnosticsReport, Never>)?

    func begin(_ start: () -> Task<DiagnosticsReport, Never>) -> (id: UUID, task: Task<DiagnosticsReport, Never>) {
        lock.lock()
        defer { lock.unlock() }
        if let inFlight { return inFlight }
        let entry = (id: UUID(), task: start())
        inFlight = entry
        return entry
    }

    func end(_ id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        if inFlight?.id == id { inFlight = nil }
    }
}

private final class DiagnosticsScanBudget: @unchecked Sendable {
    private var remaining: Int

    init(limit: Int) {
        remaining = limit
    }

    func take(_ amount: Int) -> Bool {
        guard amount <= remaining else { return false }
        remaining -= amount
        return true
    }
}
