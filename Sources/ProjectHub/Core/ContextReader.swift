import Foundation
import SQLite3

enum ContextProvider: String, CaseIterable, Sendable {
    case claude = "Claude"
    case codex = "Codex"
}

struct ContextSessionKey: Hashable, Sendable {
    let provider: ContextProvider
    let home: String
    let id: String
}

struct ContextSessionSummary: Identifiable, Hashable, Sendable {
    var id: ContextSessionKey { key }
    let key: ContextSessionKey
    let projectPath: String
    let sourcePath: String
    let lastEventAt: Date?
    let fileModifiedAt: Date
    let isAgentSession: Bool
}

enum ContextTokenValue: Equatable, Sendable {
    case measured(Int64)
    case projected(Int64, method: String)
    case reconstructed(Int64, method: String)
    case unknown(String)

    var amount: Int64? {
        switch self {
        case .measured(let value), .projected(let value, _), .reconstructed(let value, _): value
        case .unknown: nil
        }
    }

    var qualityLabel: String {
        switch self {
        case .measured: "Provider reported"
        case .projected(_, let method): "Projected · \(method)"
        case .reconstructed(_, let method): "Reconstructed · \(method)"
        case .unknown(let reason): "Unknown · \(reason)"
        }
    }
}

enum ContextSourceScope: String, Sendable {
    case global = "Global"
    case project = "Project"
    case ancestor = "Ancestor"
    case unknown = "Unknown"
}

enum ContextEvidenceBasis: String, Sendable {
    case recorded = "Recorded then"
    case currentCandidate = "Current candidate"
}

enum ContextContributionKind: String, Hashable, Sendable {
    case skill = "Skill"
    case agent = "Agent"
    case mcpSchema = "MCP schema"
    case mcpInstructions = "MCP instructions"
    case instruction = "Instruction"
    case toolSchema = "Tool schema"
}

struct ContextContribution: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let kind: ContextContributionKind
    let owner: String?
    let value: ContextTokenValue
    let scope: ContextSourceScope
    let sourcePath: String?
    let evidenceBasis: ContextEvidenceBasis
    let sourceNote: String?
    let observedAt: Date
}

struct ContextUsageSegments: Equatable, Sendable {
    let freshInput: Int64
    let cacheWrite: Int64
    let cacheRead: Int64
    let output: Int64

    var inputTotal: Int64 { freshInput + cacheWrite + cacheRead }
    var total: Int64 { inputTotal + output }
}

struct ContextUsageReport: Equatable, Sendable {
    let cumulative: ContextUsageSegments?
    let lastRequest: ContextUsageSegments?
}

enum ContextCoverageKind: String, Sendable {
    case malformedRecord = "Malformed record"
    case oversizedRecord = "Oversized record"
    case byteBudget = "Byte budget reached"
    case discoveryLimit = "Discovery limit reached"
    case unknownSchema = "Unknown schema"
    case invalidCounters = "Invalid counters"
    case counterRegression = "Counter regression"
    case incompleteIdentity = "Incomplete request identity"
    case unreadable = "Unreadable source"
    case recordBudget = "Record memory budget reached"
}

struct ContextCoverageIssue: Identifiable, Equatable, Sendable {
    var id: String { "\(kind.rawValue)|\(source)|\(detail)" }
    let kind: ContextCoverageKind
    let source: String
    let detail: String
}

struct ContextCoverage: Equatable, Sendable {
    let bytesRead: Int64
    let bytesDiscovered: Int64
    let issues: [ContextCoverageIssue]

    var isComplete: Bool {
        issues.isEmpty
    }
}

struct ContextSessionReport: Equatable, Sendable {
    let session: ContextSessionSummary
    let usage: ContextUsageReport
    let contributions: [ContextContribution]
    let observedAt: Date
    let coverage: ContextCoverage
}

struct ContextDefaultComponent: Identifiable, Equatable, Sendable {
    let id: String
    let provider: ContextProvider
    let name: String
    let kind: ContextContributionKind
    let scope: ContextSourceScope
    let sourcePath: String
    let projection: ContextTokenValue
    let canMakeUserInvocableOnly: Bool
}

struct ContextCurrentDefaults: Equatable, Sendable {
    let components: [ContextDefaultComponent]
    let observedAt: Date
}

struct ContextPage: Sendable {
    let sessions: [ContextSessionSummary]
    let selected: ContextSessionReport?
    let defaults: ContextCurrentDefaults
    let coverage: ContextCoverage
    let scannedAt: Date
}

struct ContextProviderHomes: Sendable {
    let claude: String
    let codex: String
    let user: String

    static func current(user: String = FileManager.default.homeDirectoryForCurrentUser.path) -> Self {
        let configuredClaude = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let claude = configuredClaude?.isEmpty == false
            ? URL(fileURLWithPath: (configuredClaude! as NSString).expandingTildeInPath).standardizedFileURL.path
            : (user as NSString).appendingPathComponent(".claude")
        return .init(
            claude: claude,
            codex: ProjectHubPaths.codexHome(home: user),
            user: user
        )
    }
}

struct ContextScanBudget: Sendable {
    let maximumBytes: Int64
    let maximumRecordBytes: Int
    let maximumSessions: Int
    let maximumRelevantRecords: Int
    let maximumRetainedBytes: Int64

    init(
        maximumBytes: Int64,
        maximumRecordBytes: Int,
        maximumSessions: Int,
        maximumRelevantRecords: Int = 50_000,
        maximumRetainedBytes: Int64 = 32 * 1_024 * 1_024
    ) {
        self.maximumBytes = maximumBytes
        self.maximumRecordBytes = maximumRecordBytes
        self.maximumSessions = maximumSessions
        self.maximumRelevantRecords = maximumRelevantRecords
        self.maximumRetainedBytes = maximumRetainedBytes
    }

    static let interactive = ContextScanBudget(
        maximumBytes: 128 * 1_024 * 1_024,
        maximumRecordBytes: 4 * 1_024 * 1_024,
        maximumSessions: 200
    )
}

enum ContextReader {
    private struct FileMetadata {
        let id: String
        let cwd: String
        let timestamp: Date?
    }

    private struct LineRecord {
        let offset: Int64
        let object: [String: Any]
    }

    private struct LineScan {
        let records: [LineRecord]
        let bytesRead: Int64
        let fileSize: Int64
        let issues: [ContextCoverageIssue]
    }

    private struct ParsedContribution {
        let key: String
        let name: String
        let kind: ContextContributionKind
        let owner: String?
        let text: String?
        let recordedPath: String?
        let eventAt: Date?
        let sequence: Int64
    }

    static func read(
        projectPath: String,
        homes: ContextProviderHomes = .current(),
        selected: ContextSessionKey? = nil,
        budget: ContextScanBudget = .interactive
    ) async throws -> ContextPage {
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            return try readSynchronously(
                projectPath: projectPath,
                homes: homes,
                selected: selected,
                budget: budget
            )
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private static func readSynchronously(
        projectPath: String,
        homes: ContextProviderHomes,
        selected: ContextSessionKey?,
        budget: ContextScanBudget
    ) throws -> ContextPage {
        let observedAt = Date()
        let canonicalProject = canonical(projectPath)
        var discoveryIssues: [ContextCoverageIssue] = []
        var sessions = discoverClaudeSessions(
            projectPath: canonicalProject,
            home: homes.claude,
            budget: budget,
            issues: &discoveryIssues
        )
        sessions.append(contentsOf: discoverCodexSessions(
            projectPath: canonicalProject,
            home: homes.codex,
            budget: budget,
            issues: &discoveryIssues
        ))
        sessions.sort {
            activityDate($0) > activityDate($1)
        }
        if sessions.count > budget.maximumSessions {
            sessions = Array(sessions.prefix(budget.maximumSessions))
            discoveryIssues.append(.init(
                kind: .discoveryLimit,
                source: canonicalProject,
                detail: "Showing the \(budget.maximumSessions) most recent sessions."
            ))
        }

        let defaults = currentDefaults(projectPath: canonicalProject, homes: homes, observedAt: observedAt)
        let picked = selected.flatMap { key in sessions.first(where: { $0.key == key }) } ?? sessions.first
        let report = try picked.map {
            try parseSession($0, defaults: defaults, homes: homes, budget: budget, observedAt: observedAt)
        }
        let selectedCoverage = report?.coverage
        return ContextPage(
            sessions: sessions,
            selected: report,
            defaults: defaults,
            coverage: .init(
                bytesRead: selectedCoverage?.bytesRead ?? 0,
                bytesDiscovered: selectedCoverage?.bytesDiscovered ?? 0,
                issues: discoveryIssues + (selectedCoverage?.issues ?? [])
            ),
            scannedAt: observedAt
        )
    }

    private static func discoverClaudeSessions(
        projectPath: String,
        home: String,
        budget: ContextScanBudget,
        issues: inout [ContextCoverageIssue]
    ) -> [ContextSessionSummary] {
        let root = (home as NSString).appendingPathComponent("projects")
        let fm = FileManager.default
        let normalized = claudeProjectDirectoryName(projectPath)
        let slashOnly = projectPath.replacingOccurrences(of: "/", with: "-")
        var hintedRoots = [normalized, slashOnly]
            .map { (root as NSString).appendingPathComponent($0) }
            .filter { fm.fileExists(atPath: $0) }
        if hintedRoots.isEmpty, let names = try? fm.contentsOfDirectory(atPath: root) {
            let tail = "-" + claudeProjectDirectoryName((projectPath as NSString).lastPathComponent)
            let alternatives = names.filter { $0.hasSuffix(tail) || $0 == String(tail.dropFirst()) }
            hintedRoots = alternatives.prefix(8).map { (root as NSString).appendingPathComponent($0) }
            if alternatives.count > 8 {
                issues.append(.init(
                    kind: .discoveryLimit,
                    source: root,
                    detail: "More than eight Claude directory hints matched this project name; inspected the first eight and validated their recorded working directories."
                ))
            }
        }
        var found: [ContextSessionSummary] = []
        for hintedRoot in Set(hintedRoots) {
            found.append(contentsOf: discoverJSONLSessions(
                root: hintedRoot,
                provider: .claude,
                home: home,
                projectPath: projectPath,
                budget: budget,
                issues: &issues
            ))
        }
        return found
    }

    private static func discoverCodexSessions(
        projectPath: String,
        home: String,
        budget: ContextScanBudget,
        issues: inout [ContextCoverageIssue]
    ) -> [ContextSessionSummary] {
        var found = discoverCodexSQLite(projectPath: projectPath, home: home, budget: budget, issues: &issues)
        if found.isEmpty {
            let fallbackRoot = (home as NSString).appendingPathComponent("sessions")
            found.append(contentsOf: discoverJSONLSessions(
                root: fallbackRoot,
                provider: .codex,
                home: home,
                projectPath: projectPath,
                budget: budget,
                issues: &issues
            ))
        }
        var seen = Set<String>()
        return found.filter { seen.insert(canonical($0.sourcePath)).inserted }
    }

    private static func discoverJSONLSessions(
        root: String,
        provider: ContextProvider,
        home: String,
        projectPath: String,
        budget: ContextScanBudget,
        issues: inout [ContextCoverageIssue]
    ) -> [ContextSessionSummary] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: root),
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var candidates: [(URL, Date)] = []
        for case let url as URL in enumerator {
            if Task.isCancelled { break }
            guard url.pathExtension == "jsonl",
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  values.isRegularFile == true else { continue }
            candidates.append((url, values.contentModificationDate ?? .distantPast))
        }
        candidates.sort { $0.1 > $1.1 }

        var sessions: [ContextSessionSummary] = []
        let headerBudget = ContextScanBudget(
            maximumBytes: min(budget.maximumBytes, 512 * 1_024),
            maximumRecordBytes: budget.maximumRecordBytes,
            maximumSessions: budget.maximumSessions,
            maximumRelevantRecords: 8,
            maximumRetainedBytes: 512 * 1_024
        )
        for (url, modifiedAt) in candidates.prefix(budget.maximumSessions * 3) {
            if Task.isCancelled { break }
            guard let scan = try? scanLines(path: url.path, budget: headerBudget, stopAfterMetadata: provider),
                  let metadata = metadata(in: scan.records, provider: provider),
                  belongs(metadata.cwd, to: projectPath) else { continue }
            sessions.append(.init(
                key: .init(
                    provider: provider,
                    home: home,
                    id: sessionIdentity(metadata.id, file: url, discoveryRoot: root)
                ),
                projectPath: canonical(metadata.cwd),
                sourcePath: url.path,
                lastEventAt: metadata.timestamp,
                fileModifiedAt: modifiedAt,
                isAgentSession: isNestedSessionFile(url, discoveryRoot: root)
            ))
            if sessions.count >= budget.maximumSessions { break }
        }
        if candidates.count > budget.maximumSessions * 3 {
            issues.append(.init(
                kind: .discoveryLimit,
                source: root,
                detail: "Inspected the \(budget.maximumSessions * 3) newest session files for project metadata."
            ))
        }
        return sessions
    }

    private static func discoverCodexSQLite(
        projectPath: String,
        home: String,
        budget: ContextScanBudget,
        issues: inout [ContextCoverageIssue]
    ) -> [ContextSessionSummary] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: home) else { return [] }
        let databases = names
            .compactMap { name -> (version: Int, path: String)? in
                guard name.hasPrefix("state_"), name.hasSuffix(".sqlite") else { return nil }
                let raw = name.dropFirst("state_".count).dropLast(".sqlite".count)
                guard let version = Int(raw) else { return nil }
                return (version, (home as NSString).appendingPathComponent(name))
            }
            .sorted { $0.version > $1.version }

        for (_, path) in databases {
            var databasePointer: OpaquePointer?
            guard sqlite3_open_v2(path, &databasePointer, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
                  let database = databasePointer else { continue }

            var columns = Set<String>()
            var pragma: OpaquePointer?
            if sqlite3_prepare_v2(database, "PRAGMA table_info(threads)", -1, &pragma, nil) == SQLITE_OK {
                while sqlite3_step(pragma) == SQLITE_ROW {
                    if let pointer = sqlite3_column_text(pragma, 1) { columns.insert(String(cString: pointer)) }
                }
            }
            sqlite3_finalize(pragma)
            guard columns.contains("cwd"), columns.contains("rollout_path") else {
                sqlite3_close(database)
                continue
            }

            let idColumn = columns.contains("id") ? "id" : "rollout_path"
            let dateColumn = ["updated_at", "created_at"].first(where: columns.contains)
            let dateExpression = dateColumn ?? "NULL"
            let order = dateColumn.map { " ORDER BY \($0) DESC" } ?? ""
            let sql = "SELECT \(idColumn), cwd, rollout_path, \(dateExpression) FROM threads WHERE cwd IS NOT NULL AND rollout_path IS NOT NULL\(order)"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                sqlite3_close(database)
                continue
            }

            var sessions: [ContextSessionSummary] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let idPointer = sqlite3_column_text(statement, 0),
                      let cwdPointer = sqlite3_column_text(statement, 1),
                      let rolloutPointer = sqlite3_column_text(statement, 2) else { continue }
                let cwd = String(cString: cwdPointer)
                let rollout = String(cString: rolloutPointer)
                guard belongs(cwd, to: projectPath), fm.fileExists(atPath: rollout) else { continue }
                let timestamp: Date?
                if sqlite3_column_type(statement, 3) == SQLITE_INTEGER {
                    let raw = sqlite3_column_int64(statement, 3)
                    timestamp = Date(timeIntervalSince1970: raw > 10_000_000_000 ? Double(raw) / 1_000 : Double(raw))
                } else if let value = sqlite3_column_text(statement, 3) {
                    timestamp = parseDate(String(cString: value))
                } else {
                    timestamp = nil
                }
                sessions.append(.init(
                    key: .init(provider: .codex, home: home, id: String(cString: idPointer)),
                    projectPath: canonical(cwd), sourcePath: rollout,
                    lastEventAt: timestamp, fileModifiedAt: modificationDate(rollout),
                    isAgentSession: false
                ))
                if sessions.count >= budget.maximumSessions {
                    issues.append(.init(
                        kind: .discoveryLimit, source: path,
                        detail: "Read the \(budget.maximumSessions) newest matching rows supported by the Codex index."
                    ))
                    break
                }
            }
            sqlite3_finalize(statement)
            sqlite3_close(database)
            if !sessions.isEmpty { return sessions }
        }
        return []
    }

    private static func metadata(in records: [LineRecord], provider: ContextProvider) -> FileMetadata? {
        for record in records {
            let object = record.object
            if provider == .claude,
               let cwd = string(object["cwd"]) {
                let id = string(object["sessionId"]) ?? string(object["session_id"]) ?? ""
                return .init(id: id, cwd: cwd, timestamp: timestamp(in: object))
            }
            if provider == .codex {
                let payload = dictionary(object["payload"])
                if string(object["type"]) == "session_meta", let cwd = string(payload?["cwd"]) {
                    let id = string(payload?["id"]) ?? string(object["session_id"]) ?? ""
                    return .init(id: id, cwd: cwd, timestamp: timestamp(in: object))
                }
                if let cwd = string(object["cwd"]), let id = string(object["session_id"]) {
                    return .init(id: id, cwd: cwd, timestamp: timestamp(in: object))
                }
            }
        }
        return nil
    }

    private static func parseSession(
        _ session: ContextSessionSummary,
        defaults: ContextCurrentDefaults,
        homes: ContextProviderHomes,
        budget: ContextScanBudget,
        observedAt: Date
    ) throws -> ContextSessionReport {
        let scan = try scanLines(path: session.sourcePath, budget: budget)
        var issues = scan.issues
        let usage: ContextUsageReport
        switch session.key.provider {
        case .claude:
            usage = parseClaudeUsage(scan.records, source: session.sourcePath, issues: &issues)
        case .codex:
            usage = parseCodexUsage(scan.records, source: session.sourcePath, issues: &issues)
        }
        let parsed = parseContributions(scan.records)
        let candidates = Dictionary(
            grouping: defaults.components.filter { $0.provider == session.key.provider },
            by: { "\($0.kind.rawValue)|\($0.name)" }
        )
        let contributions = parsed.values.map { item -> ContextContribution in
            let matches = candidates["\(item.kind.rawValue)|\(item.name)"] ?? []
            let candidate = matches.count == 1 ? matches[0] : nil
            let path = item.recordedPath ?? candidate?.sourcePath
            let basis: ContextEvidenceBasis = item.recordedPath == nil && candidate != nil ? .currentCandidate : .recorded
            let resolvedScope = item.recordedPath.map {
                scope(for: $0, projectPath: session.projectPath, homes: homes)
            } ?? candidate?.scope ?? .unknown
            return .init(
                id: "\(session.key.provider.rawValue)|\(session.key.id)|\(item.key)|\(item.sequence)",
                name: item.name,
                kind: item.kind,
                owner: item.owner,
                value: item.text.map { .reconstructed(estimatedTokens($0), method: "captured characters ÷ 4") }
                    ?? .unknown("name recorded without captured text"),
                scope: resolvedScope,
                sourcePath: path,
                evidenceBasis: basis,
                sourceNote: item.recordedPath == nil && matches.count > 1
                    ? "Several current sources share this recorded name."
                    : nil,
                observedAt: item.eventAt ?? observedAt
            )
        }.sorted {
            ($0.value.amount ?? -1, $0.name) > ($1.value.amount ?? -1, $1.name)
        }
        return .init(
            session: session,
            usage: usage,
            contributions: contributions,
            observedAt: observedAt,
            coverage: .init(bytesRead: scan.bytesRead, bytesDiscovered: scan.fileSize, issues: issues)
        )
    }

    private static func parseClaudeUsage(
        _ records: [LineRecord],
        source: String,
        issues: inout [ContextCoverageIssue]
    ) -> ContextUsageReport {
        var byIdentity: [String: (segments: ContextUsageSegments, timestamp: Date?, sequence: Int64)] = [:]
        for record in records {
            guard string(record.object["type"]) == "assistant",
                  let message = dictionary(record.object["message"]),
                  let usage = dictionary(message["usage"]) else { continue }
            guard let segments = claudeSegments(usage) else {
                issues.append(.init(kind: .invalidCounters, source: source, detail: "Ignored negative, overflowing, or malformed Claude counters near byte \(record.offset)."))
                continue
            }
            let requestID = string(record.object["requestId"]) ?? string(record.object["request_id"])
                ?? string(message["requestId"]) ?? string(message["request_id"])
            let messageID = string(message["id"])
            let identity: String
            if let requestID, let messageID {
                identity = "\(messageID)|\(requestID)"
            } else if let messageID {
                identity = "message:\(messageID)"
            } else {
                identity = "line:\(record.offset)"
                issues.append(.init(kind: .incompleteIdentity, source: source, detail: "A Claude usage record lacked a stable message identity, so it could not be stream-deduplicated."))
            }
            byIdentity[identity] = (segments, timestamp(in: record.object), record.offset)
        }
        let ordered = byIdentity.values.sorted {
            ($0.timestamp ?? .distantPast, $0.sequence) < ($1.timestamp ?? .distantPast, $1.sequence)
        }
        let cumulative = sum(ordered.map(\.segments), source: source, issues: &issues)
        return .init(cumulative: cumulative, lastRequest: ordered.last?.segments)
    }

    private static func parseCodexUsage(
        _ records: [LineRecord],
        source: String,
        issues: inout [ContextCoverageIssue]
    ) -> ContextUsageReport {
        var latestTotal: ContextUsageSegments?
        var latestLast: ContextUsageSegments?
        for record in records {
            let payload = dictionary(record.object["payload"]) ?? record.object
            let info = dictionary(payload["info"]) ?? dictionary(record.object["info"])
            guard let info else { continue }
            if let rawTotal = dictionary(info["total_token_usage"]) {
                guard let total = codexSegments(rawTotal) else {
                    issues.append(.init(kind: .invalidCounters, source: source, detail: "Ignored invalid Codex cumulative counters near byte \(record.offset)."))
                    continue
                }
                if let previous = latestTotal,
                   total.inputTotal < previous.inputTotal || total.output < previous.output {
                    issues.append(.init(kind: .counterRegression, source: source, detail: "Codex cumulative counters reset or regressed near byte \(record.offset)."))
                }
                latestTotal = total
            }
            if let rawLast = dictionary(info["last_token_usage"]) {
                if let last = codexSegments(rawLast) {
                    latestLast = last
                } else {
                    issues.append(.init(kind: .invalidCounters, source: source, detail: "Ignored invalid Codex last-request counters near byte \(record.offset)."))
                }
            }
        }
        return .init(cumulative: latestTotal, lastRequest: latestLast)
    }

    private static func claudeSegments(_ usage: [String: Any]) -> ContextUsageSegments? {
        guard let input = nonnegative(usage["input_tokens"]),
              let cacheWrite = nonnegative(usage["cache_creation_input_tokens"], default: 0),
              let cacheRead = nonnegative(usage["cache_read_input_tokens"], default: 0),
              let output = nonnegative(usage["output_tokens"]),
              checkedSum([input, cacheWrite, cacheRead, output]) != nil else { return nil }
        return .init(freshInput: input, cacheWrite: cacheWrite, cacheRead: cacheRead, output: output)
    }

    private static func codexSegments(_ usage: [String: Any]) -> ContextUsageSegments? {
        guard let input = nonnegative(usage["input_tokens"]),
              let cached = nonnegative(usage["cached_input_tokens"], default: 0),
              let output = nonnegative(usage["output_tokens"]),
              cached <= input,
              checkedSum([input, output]) != nil else { return nil }
        return .init(freshInput: input - cached, cacheWrite: 0, cacheRead: cached, output: output)
    }

    private static func sum(
        _ values: [ContextUsageSegments],
        source: String,
        issues: inout [ContextCoverageIssue]
    ) -> ContextUsageSegments? {
        guard !values.isEmpty else { return nil }
        guard let fresh = checkedSum(values.map(\.freshInput)),
              let write = checkedSum(values.map(\.cacheWrite)),
              let read = checkedSum(values.map(\.cacheRead)),
              let output = checkedSum(values.map(\.output)),
              checkedSum([fresh, write, read, output]) != nil else {
            issues.append(.init(kind: .invalidCounters, source: source, detail: "Usage counters overflowed while totaling the session."))
            return nil
        }
        return .init(freshInput: fresh, cacheWrite: write, cacheRead: read, output: output)
    }

    private static func parseContributions(_ records: [LineRecord]) -> [String: ParsedContribution] {
        var active: [String: ParsedContribution] = [:]
        for record in records {
            let eventAt = timestamp(in: record.object)
            var attachments: [[String: Any]] = []
            if let attachment = dictionary(record.object["attachment"]) { attachments.append(attachment) }
            if let payload = dictionary(record.object["payload"]), let attachment = dictionary(payload["attachment"]) {
                attachments.append(attachment)
            }
            if string(record.object["type"]) == "prompt_snapshot" { attachments.append(record.object) }
            if let payload = dictionary(record.object["payload"]), string(payload["type"]) == "prompt_snapshot" {
                attachments.append(payload)
            }
            for attachment in attachments {
                let type = string(attachment["type"]) ?? ""
                switch type {
                case "skill_listing":
                    active = active.filter { !$0.key.hasPrefix("skillCatalog|") }
                    let content = string(attachment["content"]) ?? ""
                    let names = stringArray(attachment["names"])
                    let entries = skillEntries(content: content, names: names)
                    for entry in entries {
                        insertContribution(family: "skillCatalog", name: entry.name, kind: .skill, text: entry.text, path: nil, eventAt: eventAt, sequence: record.offset, into: &active)
                    }
                case "agent_listing_delta":
                    if attachment["isInitial"] as? Bool == true {
                        active = active.filter { !$0.key.hasPrefix("agentCatalog|") }
                    }
                    let removed = stringArray(attachment["removedTypes"]) + stringArray(attachment["removedNames"])
                    removeContributions(named: removed, family: "agentCatalog", from: &active)
                    for line in stringArray(attachment["addedLines"]) {
                        let parsed = namedLine(line)
                        insertContribution(family: "agentCatalog", name: parsed.name, kind: .agent, text: line, path: nil, eventAt: eventAt, sequence: record.offset, into: &active)
                    }
                case "deferred_tools_delta":
                    // This is a name/description catalog, not proof that a schema was loaded.
                    continue
                case "mcp_instructions_delta":
                    removeContributions(named: stringArray(attachment["removedNames"]), family: "mcpInstructions", from: &active)
                    let names = stringArray(attachment["addedNames"])
                    let blocks = stringArray(attachment["addedBlocks"])
                    for index in names.indices {
                        let block = index < blocks.count ? blocks[index] : nil
                        insertContribution(family: "mcpInstructions", name: names[index], kind: .mcpInstructions, text: block, path: nil, eventAt: eventAt, sequence: record.offset, into: &active)
                    }
                case "instructions":
                    active = active.filter { !$0.key.hasPrefix("instructions|") }
                    for file in dictionaryArray(attachment["files"]) {
                        let path = string(file["path"])
                        let name = path.map { ($0 as NSString).lastPathComponent } ?? "Instructions"
                        insertContribution(family: "instructions", name: name, kind: .instruction, text: string(file["content"]), path: path, eventAt: eventAt, sequence: record.offset, into: &active)
                    }
                case "prompt_snapshot":
                    active = active.filter { !$0.key.hasPrefix("promptTools|") }
                    for tool in dictionaryArray(attachment["tools"]) {
                        guard let name = string(tool["name"]) else { continue }
                        var parts = [string(tool["description"])].compactMap { $0 }
                        if let schema = tool["schema"], JSONSerialization.isValidJSONObject(schema),
                           let data = try? JSONSerialization.data(withJSONObject: schema),
                           let text = String(data: data, encoding: .utf8) {
                            parts.append(text)
                        }
                        let kind: ContextContributionKind = name.hasPrefix("mcp__") ? .mcpSchema : .toolSchema
                        insertContribution(family: "promptTools", name: name, kind: kind, text: parts.joined(separator: "\n"), path: nil, eventAt: eventAt, sequence: record.offset, into: &active)
                    }
                default:
                    continue
                }
            }
        }
        return active
    }

    private static func insertContribution(
        family: String,
        name: String,
        kind: ContextContributionKind,
        text: String?,
        path: String?,
        eventAt: Date?,
        sequence: Int64,
        into active: inout [String: ParsedContribution]
    ) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        let owner: String?
        if kind == .mcpSchema, cleanName.hasPrefix("mcp__") {
            owner = cleanName.dropFirst(5).split(separator: "__", maxSplits: 1).first.map(String.init)
        } else if (kind == .skill || kind == .agent), cleanName.contains(":") {
            owner = cleanName.split(separator: ":", maxSplits: 1).first.map(String.init)
        } else {
            owner = nil
        }
        let key = "\(family)|\(kind.rawValue)|\(path ?? "")|\(cleanName)"
        active[key] = .init(
            key: key,
            name: cleanName,
            kind: kind,
            owner: owner,
            text: text?.isEmpty == false ? text : nil,
            recordedPath: path,
            eventAt: eventAt,
            sequence: sequence
        )
    }

    private static func removeContributions(
        named names: [String],
        family: String,
        from active: inout [String: ParsedContribution]
    ) {
        guard !names.isEmpty else { return }
        let removed = Set(names)
        active = active.filter { key, value in
            !key.hasPrefix(family + "|") || !removed.contains(value.name)
        }
    }

    private static func currentDefaults(
        projectPath: String,
        homes: ContextProviderHomes,
        observedAt: Date
    ) -> ContextCurrentDefaults {
        var components: [ContextDefaultComponent] = []
        let skillRoots: [(ContextProvider, ContextSourceScope, String)] = [
            (.claude, .global, (homes.claude as NSString).appendingPathComponent("skills")),
            (.claude, .project, (projectPath as NSString).appendingPathComponent(".claude/skills")),
            (.codex, .global, (homes.user as NSString).appendingPathComponent(".agents/skills")),
            (.codex, .global, (homes.codex as NSString).appendingPathComponent("skills")),
            (.codex, .project, (projectPath as NSString).appendingPathComponent(".agents/skills")),
        ]
        for (provider, scopeValue, directory) in skillRoots {
            components.append(contentsOf: skillDefaults(directory: directory, provider: provider, scope: scopeValue))
        }
        let projectAgents = AgentReader.agents(for: projectPath).map { ($0, ContextSourceScope.project) }
        let globalAgents = agents(in: (homes.claude as NSString).appendingPathComponent("agents")).map {
            ($0, ContextSourceScope.global)
        }
        for (agent, scopeValue) in projectAgents + globalAgents {
            components.append(.init(
                id: "agent|\(agent.filePath)", provider: .claude, name: agent.name, kind: .agent,
                scope: scopeValue, sourcePath: agent.filePath,
                projection: projection(forFile: agent.filePath), canMakeUserInvocableOnly: false
            ))
        }
        components.append(contentsOf: currentMCPDefaults(projectPath: projectPath, homes: homes))
        components.append(contentsOf: instructionDefaults(projectPath: projectPath, homes: homes))
        var seen = Set<String>()
        components = components.filter { seen.insert($0.id).inserted }
        let claudeSkillCounts = Dictionary(grouping: components.filter {
            $0.provider == .claude && $0.kind == .skill
        }, by: \.name).mapValues(\.count)
        components = components.map { component in
            guard component.provider == .claude, component.kind == .skill else { return component }
            return .init(
                id: component.id, provider: component.provider, name: component.name, kind: component.kind,
                scope: component.scope, sourcePath: component.sourcePath, projection: component.projection,
                canMakeUserInvocableOnly: component.canMakeUserInvocableOnly && claudeSkillCounts[component.name] == 1
            )
        }
        components.sort { ($0.provider.rawValue, $0.kind.rawValue, $0.name) < ($1.provider.rawValue, $1.kind.rawValue, $1.name) }
        return .init(components: components, observedAt: observedAt)
    }

    private static func agents(in directory: String) -> [Agent] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return [] }
        return names.filter { $0.hasSuffix(".md") }.sorted().compactMap {
            AgentReader.parse(at: (directory as NSString).appendingPathComponent($0))
        }
    }

    private static func skillDefaults(
        directory: String,
        provider: ContextProvider,
        scope: ContextSourceScope
    ) -> [ContextDefaultComponent] {
        SkillReader.scanSkillDir(directory, source: .claudeGlobal).map { skill in
            let file = (skill.path as NSString).appendingPathComponent("SKILL.md")
            return .init(
                id: "skill|\(provider.rawValue)|\(file)", provider: provider, name: skill.name,
                kind: .skill, scope: scope, sourcePath: file, projection: projection(forFile: file, method: "current file size; loaded on invocation"),
                canMakeUserInvocableOnly: provider == .claude && !skill.name.contains(":")
            )
        }
    }

    private static func instructionDefaults(projectPath: String, homes: ContextProviderHomes) -> [ContextDefaultComponent] {
        let fm = FileManager.default
        var result: [ContextDefaultComponent] = []
        let explicit: [(ContextProvider, ContextSourceScope, String)] = [
            (.claude, .project, (projectPath as NSString).appendingPathComponent(".claude/CLAUDE.md")),
            (.claude, .project, (projectPath as NSString).appendingPathComponent("CLAUDE.local.md")),
            (.claude, .global, (homes.claude as NSString).appendingPathComponent("CLAUDE.md")),
            (.codex, .global, (homes.codex as NSString).appendingPathComponent("AGENTS.override.md")),
            (.codex, .global, (homes.codex as NSString).appendingPathComponent("AGENTS.md")),
        ]
        for (provider, scopeValue, path) in explicit where fm.fileExists(atPath: path) {
            result.append(.init(
                id: "instruction|\(provider.rawValue)|\(path)", provider: provider,
                name: (path as NSString).lastPathComponent, kind: .instruction,
                scope: scopeValue, sourcePath: path,
                projection: projection(forFile: path, method: "current file characters ÷ 4"),
                canMakeUserInvocableOnly: false
            ))
        }
        var directory = URL(fileURLWithPath: projectPath).standardizedFileURL
        for _ in 0..<24 {
            for (provider, name) in [(ContextProvider.claude, "CLAUDE.md"), (.codex, "AGENTS.override.md"), (.codex, "AGENTS.md")] {
                let path = directory.appendingPathComponent(name).path
                guard fm.fileExists(atPath: path) else { continue }
                let itemScope: ContextSourceScope = canonical(directory.path) == canonical(projectPath) ? .project : .ancestor
                result.append(.init(
                    id: "instruction|\(provider.rawValue)|\(path)", provider: provider, name: name,
                    kind: .instruction, scope: itemScope, sourcePath: path,
                    projection: projection(forFile: path, method: "current file characters ÷ 4"), canMakeUserInvocableOnly: false
                ))
            }
            if canonical(directory.path) == canonical(homes.user) { break }
            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path || !belongs(projectPath, to: homes.user) { break }
            directory = parent
        }
        return result
    }

    private static func currentMCPDefaults(
        projectPath: String,
        homes: ContextProviderHomes
    ) -> [ContextDefaultComponent] {
        let sources: [(ContextProvider, ContextSourceScope, String)] = [
            (.claude, .global, (homes.user as NSString).appendingPathComponent(".claude.json")),
            (.claude, .project, (projectPath as NSString).appendingPathComponent(".mcp.json")),
            (.codex, .global, (homes.codex as NSString).appendingPathComponent("config.toml")),
            (.codex, .project, (projectPath as NSString).appendingPathComponent(".codex/config.toml")),
        ]
        return sources.flatMap { provider, scope, path in
            mcpNames(in: path, provider: provider).map { name in
                .init(
                    id: "mcp|\(provider.rawValue)|\(path)|\(name)", provider: provider,
                    name: name, kind: .mcpSchema, scope: scope, sourcePath: path,
                    projection: .unknown("schema size is not recorded in config"),
                    canMakeUserInvocableOnly: false
                )
            }
        }
    }

    private static func mcpNames(in path: String, provider: ContextProvider) -> [String] {
        guard let data = FileManager.default.contents(atPath: path) else { return [] }
        if provider == .claude,
           let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let servers = root["mcpServers"] as? [String: Any] {
            return servers.keys.sorted()
        }
        guard provider == .codex, let text = String(data: data, encoding: .utf8) else { return [] }
        var names = Set<String>()
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("[mcp_servers."), trimmed.hasSuffix("]") else { continue }
            var name = String(trimmed.dropFirst("[mcp_servers.".count).dropLast())
            if name.hasPrefix("\"") && name.hasSuffix("\"") { name = String(name.dropFirst().dropLast()) }
            if !name.isEmpty { names.insert(name) }
        }
        return names.sorted()
    }

    private static func projection(forFile path: String, method: String = "current file characters ÷ 4") -> ContextTokenValue {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return .unknown("current file unreadable") }
        return .projected(estimatedTokens(text), method: method)
    }

    private static func scanLines(
        path: String,
        budget: ContextScanBudget,
        stopAfterMetadata provider: ContextProvider? = nil
    ) throws -> LineScan {
        try Task.checkCancellation()
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        defer { try? handle.close() }

        var buffer = Data()
        var records: [LineRecord] = []
        var issues: [ContextCoverageIssue] = []
        var bytesRead: Int64 = 0
        var lineStart: Int64 = 0
        var discardingOversizedLine = false
        var retainedBytes: Int64 = 0
        var hitRecordBudget = false
        let chunkSize = 64 * 1_024

        while bytesRead < min(fileSize, budget.maximumBytes) {
            try Task.checkCancellation()
            let requested = Int(min(Int64(chunkSize), budget.maximumBytes - bytesRead))
            guard requested > 0, let chunk = try handle.read(upToCount: requested), !chunk.isEmpty else { break }
            bytesRead += Int64(chunk.count)
            buffer.append(chunk)

            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = buffer.prefix(upTo: newline)
                let consumed = buffer.distance(from: buffer.startIndex, to: newline) + 1
                if discardingOversizedLine {
                    discardingOversizedLine = false
                } else if line.count > budget.maximumRecordBytes {
                    issues.append(.init(kind: .oversizedRecord, source: path, detail: "Skipped a record larger than \(budget.maximumRecordBytes) bytes at byte \(lineStart)."))
                } else if !line.isEmpty {
                    decode(
                        line: Data(line), offset: lineStart, source: path, budget: budget,
                        retainedBytes: &retainedBytes, hitRecordBudget: &hitRecordBudget,
                        records: &records, issues: &issues
                    )
                }
                buffer.removeSubrange(buffer.startIndex...newline)
                lineStart += Int64(consumed)
                if let provider, metadata(in: records.suffix(1).map { $0 }, provider: provider) != nil {
                    return .init(records: records, bytesRead: bytesRead, fileSize: fileSize, issues: issues)
                }
            }
            if buffer.count > budget.maximumRecordBytes {
                issues.append(.init(kind: .oversizedRecord, source: path, detail: "Skipped a record larger than \(budget.maximumRecordBytes) bytes at byte \(lineStart)."))
                lineStart += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                discardingOversizedLine = true
            }
        }
        if !discardingOversizedLine, !buffer.isEmpty {
            if bytesRead == fileSize {
                decode(
                    line: buffer, offset: lineStart, source: path, budget: budget,
                    retainedBytes: &retainedBytes, hitRecordBudget: &hitRecordBudget,
                    records: &records, issues: &issues
                )
            } else {
                issues.append(.init(kind: .byteBudget, source: path, detail: "The scan stopped before an incomplete record at byte \(lineStart)."))
            }
        }
        if bytesRead < fileSize, !issues.contains(where: { $0.kind == .byteBudget }) {
            issues.append(.init(kind: .byteBudget, source: path, detail: "Read \(bytesRead) of \(fileSize) bytes."))
        }
        if hitRecordBudget {
            issues.append(.init(kind: .recordBudget, source: path, detail: "Relevant records exceeded the in-memory scan budget; later records were not retained."))
        }
        return .init(records: records, bytesRead: bytesRead, fileSize: fileSize, issues: issues)
    }

    private static func decode(
        line: Data,
        offset: Int64,
        source: String,
        budget: ContextScanBudget,
        retainedBytes: inout Int64,
        hitRecordBudget: inout Bool,
        records: inout [LineRecord],
        issues: inout [ContextCoverageIssue]
    ) {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else {
            issues.append(.init(kind: .malformedRecord, source: source, detail: "Skipped malformed JSON near byte \(offset)."))
            return
        }
        guard let compact = compactRecord(object) else { return }
        guard records.count < budget.maximumRelevantRecords,
              retainedBytes + Int64(line.count) <= budget.maximumRetainedBytes else {
            hitRecordBudget = true
            return
        }
        retainedBytes += Int64(line.count)
        records.append(.init(offset: offset, object: compact))
    }

    private static func compactRecord(_ object: [String: Any]) -> [String: Any]? {
        let type = string(object["type"])
        if type == "assistant", let message = dictionary(object["message"]), message["usage"] != nil {
            var compact: [String: Any] = ["type": "assistant"]
            for key in ["requestId", "request_id", "timestamp", "cwd", "sessionId", "session_id"] where object[key] != nil { compact[key] = object[key] }
            var compactMessage: [String: Any] = [:]
            for key in ["id", "requestId", "request_id", "usage"] where message[key] != nil { compactMessage[key] = message[key] }
            compact["message"] = compactMessage
            return compact
        }
        if let attachment = dictionary(object["attachment"]) {
            var compact: [String: Any] = ["attachment": attachment]
            for key in ["timestamp", "cwd", "sessionId", "session_id"] where object[key] != nil { compact[key] = object[key] }
            return compact
        }
        if let payload = dictionary(object["payload"]) {
            if payload["info"] != nil || payload["attachment"] != nil || string(payload["type"]) == "prompt_snapshot" {
                var compact: [String: Any] = ["payload": payload]
                if let timestamp = object["timestamp"] { compact["timestamp"] = timestamp }
                if let type { compact["type"] = type }
                return compact
            }
        }
        if type == "prompt_snapshot" { return object }
        if object["cwd"] != nil || type == "session_meta" {
            var compact: [String: Any] = [:]
            for key in ["type", "cwd", "sessionId", "session_id", "timestamp", "created_at", "updated_at"] {
                if let value = object[key] { compact[key] = value }
            }
            if let payload = dictionary(object["payload"]) {
                compact["payload"] = payload.filter { ["id", "cwd", "timestamp"].contains($0.key) }
            }
            return compact
        }
        return nil
    }

    private static func scope(
        for path: String,
        projectPath: String,
        homes: ContextProviderHomes
    ) -> ContextSourceScope {
        let candidate = canonical(path)
        let project = canonical(projectPath)
        if candidate == project || candidate.hasPrefix(project + "/") { return .project }
        let projectMemory = canonical(
            ((homes.claude as NSString).appendingPathComponent("projects") as NSString)
                .appendingPathComponent(claudeProjectDirectoryName(project))
        )
        if candidate == projectMemory || candidate.hasPrefix(projectMemory + "/") { return .project }
        let globalClaudeJSON = canonical((homes.user as NSString).appendingPathComponent(".claude.json"))
        let globalAgents = canonical((homes.user as NSString).appendingPathComponent(".agents"))
        if candidate == globalClaudeJSON || candidate == globalAgents || candidate.hasPrefix(globalAgents + "/") {
            return .global
        }
        let parent = URL(fileURLWithPath: candidate).deletingLastPathComponent().path
        if project.hasPrefix(candidate + "/") || project == parent || project.hasPrefix(parent + "/") { return .ancestor }
        if candidate == canonical(homes.claude) || candidate.hasPrefix(canonical(homes.claude) + "/")
            || candidate == canonical(homes.codex) || candidate.hasPrefix(canonical(homes.codex) + "/") {
            return .global
        }
        return .unknown
    }

    private static func namedLine(_ line: String) -> (name: String, text: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^-\\s*", with: "", options: .regularExpression)
        let name = trimmed.components(separatedBy: ": ").first ?? trimmed
        return (name.trimmingCharacters(in: .whitespaces), line)
    }

    private static func skillEntries(content: String, names: [String]) -> [(name: String, text: String)] {
        let known = names.sorted { $0.count > $1.count }
        var result: [(String, String)] = []
        var currentName: String?
        var currentLines: [String] = []

        func flush() {
            if let currentName { result.append((currentName, currentLines.joined(separator: "\n"))) }
            currentName = nil
            currentLines = []
        }

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") {
                let remainder = String(trimmed.dropFirst(2))
                let matched = known.first { remainder == $0 || remainder.hasPrefix($0 + ": ") }
                let derived = matched ?? namedLine(line).name
                if !derived.isEmpty {
                    flush()
                    currentName = derived
                    currentLines = [line]
                    continue
                }
            }
            if currentName != nil { currentLines.append(line) }
        }
        flush()
        for name in names where !result.contains(where: { $0.0 == name }) {
            result.append((name, ""))
        }
        return result.map { (name: $0.0, text: $0.1) }
    }

    private static func estimatedTokens(_ text: String) -> Int64 {
        Int64((text.count + 3) / 4)
    }

    private static func dictionary(_ value: Any?) -> [String: Any]? { value as? [String: Any] }
    private static func dictionaryArray(_ value: Any?) -> [[String: Any]] { value as? [[String: Any]] ?? [] }
    private static func string(_ value: Any?) -> String? { value as? String }
    private static func stringArray(_ value: Any?) -> [String] { value as? [String] ?? [] }

    private static func nonnegative(_ value: Any?, default fallback: Int64? = nil) -> Int64? {
        guard let value else { return fallback }
        let number: Int64?
        if let raw = value as? Int64 { number = raw }
        else if let raw = value as? Int { number = Int64(raw) }
        else if let raw = value as? NSNumber {
            guard CFGetTypeID(raw) != CFBooleanGetTypeID() else { return nil }
            let double = raw.doubleValue
            guard double.isFinite, double.rounded() == double,
                  double >= 0, double <= Double(Int64.max) else { return nil }
            number = Int64(double)
        }
        else { number = nil }
        guard let number, number >= 0 else { return nil }
        return number
    }

    private static func checkedSum(_ values: [Int64]) -> Int64? {
        var total: Int64 = 0
        for value in values {
            let (next, overflow) = total.addingReportingOverflow(value)
            guard !overflow else { return nil }
            total = next
        }
        return total
    }

    private static func timestamp(in object: [String: Any]) -> Date? {
        let candidates: [Any?] = [
            object["timestamp"], object["created_at"], object["updated_at"],
            dictionary(object["payload"])?["timestamp"]
        ]
        for candidate in candidates {
            if let text = string(candidate), let date = parseDate(text) { return date }
            if let number = candidate as? NSNumber {
                let raw = number.doubleValue
                return Date(timeIntervalSince1970: raw > 10_000_000_000 ? raw / 1_000 : raw)
            }
        }
        return nil
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private static func canonical(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL.resolvingSymlinksInPath().path
    }

    private static func belongs(_ cwd: String, to projectPath: String) -> Bool {
        let child = canonical(cwd)
        let project = canonical(projectPath)
        return child == project || child.hasPrefix(project + "/")
    }

    private static func modificationDate(_ path: String) -> Date {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        return attributes?[.modificationDate] as? Date ?? .distantPast
    }

    private static func activityDate(_ session: ContextSessionSummary) -> Date {
        session.key.provider == .codex ? (session.lastEventAt ?? session.fileModifiedAt) : session.fileModifiedAt
    }

    private static func claudeProjectDirectoryName(_ path: String) -> String {
        path.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }.joined()
    }

    private static func isNestedSessionFile(_ file: URL, discoveryRoot _: String) -> Bool {
        file.pathComponents.contains("subagents")
    }

    private static func sessionIdentity(_ recordedID: String, file: URL, discoveryRoot: String) -> String {
        let stableID = recordedID.isEmpty ? file.deletingPathExtension().lastPathComponent : recordedID
        guard isNestedSessionFile(file, discoveryRoot: discoveryRoot) else { return stableID }
        let relative = file.path.dropFirst(min(file.path.count, discoveryRoot.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return stableID + ":agent:" + relative.replacingOccurrences(of: "/", with: ":")
    }
}
