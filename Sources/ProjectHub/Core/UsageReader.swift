import Foundation

struct UsageWindow: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let usedPercent: Double
    let resetsAt: Date?
    let windowMinutes: Int?

    var remainingPercent: Double { max(0, min(100, 100 - usedPercent)) }
}

struct UsageTotals: Equatable {
    var input: Int = 0
    var output: Int = 0
    var cacheWrite: Int = 0
    var cacheRead: Int = 0
    var cost: Double = 0

    var tokens: Int { input + output + cacheWrite + cacheRead }

    mutating func add(_ other: UsageTotals) {
        input += other.input
        output += other.output
        cacheWrite += other.cacheWrite
        cacheRead += other.cacheRead
        cost += other.cost
    }
}

struct UsageCard: Identifiable, Equatable {
    var id: String { provider }
    let provider: String
    let providerID: String
    let plan: String
    let windows: [UsageWindow]
    let today: UsageTotals
    let week: UsageTotals
    let block: UsageTotals
    let blockEndsAt: Date?
    let lastSession: UsageTotals
    let lastSessionAt: Date?
    let lastModel: String?
    let note: String?
    let featured: Bool
}

enum UsageReader {
    static var homeOverride: String?

    private static var home: String {
        homeOverride ?? NSHomeDirectory()
    }

    private static var cachedCards: [UsageCard] = []
    private static var cachedAt: Date?

    static func summarize() -> [UsageCard] {
        if let cachedAt, Date().timeIntervalSince(cachedAt) < 60, !cachedCards.isEmpty {
            return cachedCards
        }
        let cards = summarizeUncached()
        cachedCards = cards
        cachedAt = Date()
        return cards
    }

    private static func summarizeUncached() -> [UsageCard] {
        let claude = claudeCard()
        return [
            claude,
            UsageCard(
                provider: "Claude Desktop",
                providerID: "claude-desktop",
                plan: claude.plan,
                windows: [],
                today: UsageTotals(),
                week: UsageTotals(),
                block: UsageTotals(),
                blockEndsAt: nil,
                lastSession: UsageTotals(),
                lastSessionAt: nil,
                lastModel: nil,
                note: "Cowork sessions are folded into Claude Code when they write local logs.",
                featured: false
            ),
            codexCard(),
            compactCard(id: "cursor", name: "Cursor", note: "No local 5-hour or weekly quota file."),
            compactCard(id: "vscode", name: "VS Code", note: "Copilot remaining credits stay in the VS Code status bar."),
            compactCard(id: "antigravity", name: "Antigravity", note: "No local remaining-quota file."),
            compactCard(id: "opencode", name: "OpenCode", note: "Usage lives in a local DB, not a vendor quota file."),
            compactCard(id: "zed", name: "Zed", note: "Hosted-model usage is in threads.db, not a weekly quota file."),
            grokCard(),
            piCard(),
            commandCodeCard(),
        ]
    }

    private static func compactCard(id: String, name: String, note: String) -> UsageCard {
        UsageCard(
            provider: name,
            providerID: id,
            plan: "Local only",
            windows: [],
            today: UsageTotals(),
            week: UsageTotals(),
            block: UsageTotals(),
            blockEndsAt: nil,
            lastSession: UsageTotals(),
            lastSessionAt: nil,
            lastModel: nil,
            note: note,
            featured: false
        )
    }

    // MARK: - Claude

    private static func claudeCard() -> UsageCard {
        let account = claudeAccount()
        let roots = [
            (home as NSString).appendingPathComponent(".claude/projects"),
            (home as NSString).appendingPathComponent("Library/Application Support/Claude/local-agent-mode-sessions"),
        ]
        let events = loadEvents(under: roots, kind: .claude)
        let snapshot = snapshot(from: events)
        return UsageCard(
            provider: "Claude Code",
            providerID: "claude-code",
            plan: account.plan,
            windows: [],
            today: snapshot.today,
            week: snapshot.week,
            block: snapshot.block,
            blockEndsAt: snapshot.blockEndsAt,
            lastSession: snapshot.lastSession,
            lastSessionAt: snapshot.lastSessionAt,
            lastModel: snapshot.lastModel,
            note: snapshot.week.tokens == 0 ? account.note : "Estimated at published API rates from local session logs. Not a bill.",
            featured: true
        )
    }

    private static func claudeAccount() -> (plan: String, note: String?) {
        let path = (home as NSString).appendingPathComponent(".claude.json")
        guard
            let data = FileManager.default.contents(atPath: path),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ("Unknown plan", "No local Claude session logs yet.")
        }
        let account = root["oauthAccount"] as? [String: Any] ?? [:]
        let orgType = string(account["organizationType"])
        let tier = string(account["organizationRateLimitTier"])
            ?? string(account["userRateLimitTier"])
            ?? string(root["claudeMaxTier"])
        let seat = string(account["seatTier"])
        var parts: [String] = []
        if orgType == "claude_max" { parts.append("Claude Max") }
        else if let orgType { parts.append(orgType.replacingOccurrences(of: "_", with: " ").capitalized) }
        if let tier, tier.contains("5x") { parts.append("5x") }
        else if let tier, tier != "not_max" { parts.append(tier.replacingOccurrences(of: "_", with: " ")) }
        if let seat, seat != tier { parts.append(seat.replacingOccurrences(of: "_", with: " ")) }
        let plan = parts.isEmpty ? "Claude" : parts.joined(separator: " · ")
        return (plan, "Open Claude Code once so it writes session logs under ~/.claude/projects.")
    }

    // MARK: - Codex

    private static func codexCard() -> UsageCard {
        let sessions = (ProjectHubPaths.codexHome(home: home) as NSString).appendingPathComponent("sessions")
        let limits = latestCodexRateLimits(under: sessions)
        var windows: [UsageWindow] = []
        if let primary = limits?["primary"] as? [String: Any] {
            windows.append(window(from: primary, title: windowTitle(minutes: int(primary["window_minutes"]))))
        }
        if let secondary = limits?["secondary"] as? [String: Any] {
            windows.append(window(from: secondary, title: windowTitle(minutes: int(secondary["window_minutes"]))))
        }
        let plan = string(limits?["plan_type"])?.capitalized ?? "Codex"
        let events = loadEvents(under: [sessions], kind: .codex)
        let snapshot = snapshot(from: events)
        return UsageCard(
            provider: "Codex",
            providerID: "codex",
            plan: plan,
            windows: windows,
            today: snapshot.today,
            week: snapshot.week,
            block: snapshot.block,
            blockEndsAt: snapshot.blockEndsAt,
            lastSession: snapshot.lastSession,
            lastSessionAt: snapshot.lastSessionAt,
            lastModel: snapshot.lastModel,
            note: windows.isEmpty && snapshot.week.tokens == 0
                ? "Open Codex once so it writes sessions and rate limits locally."
                : nil,
            featured: true
        )
    }

    private static func latestCodexRateLimits(under root: String) -> [String: Any]? {
        for file in newestSessionFiles(under: [root], limit: 8) {
            if let limits = lastRateLimits(in: file.path) {
                return limits
            }
        }
        return nil
    }

    private static func lastRateLimits(in path: String) -> [String: Any]? {
        guard let object = lastJSONObject(in: path, matching: { ($0["payload"] as? [String: Any])?["rate_limits"] != nil }) else {
            return nil
        }
        return (object["payload"] as? [String: Any])?["rate_limits"] as? [String: Any]
    }

    // MARK: - Grok CLI

    private static func grokCard() -> UsageCard {
        let sessions = grokSessionSignals()
        var today = UsageTotals()
        var week = UsageTotals()
        var last = UsageTotals()
        var lastAt: Date?
        var lastModel: String?
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        for session in sessions {
            var totals = UsageTotals()
            totals.input = session.tokens
            totals.cost = Double(session.tokens) * rates(for: session.model).input
            if session.updated >= weekStart { week.add(totals) }
            if session.updated >= startOfDay { today.add(totals) }
            if lastAt == nil || session.updated > lastAt! {
                last = totals
                lastAt = session.updated
                lastModel = session.model
            }
        }
        let defaultModel = grokDefaultModel()
        let windows: [UsageWindow]
        if let latest = sessions.max(by: { $0.updated < $1.updated }), latest.contextWindow > 0 {
            windows = [
                UsageWindow(
                    title: "Context",
                    usedPercent: min(100, max(0, Double(latest.contextUsed) / Double(latest.contextWindow) * 100)),
                    resetsAt: nil,
                    windowMinutes: nil
                )
            ]
        } else {
            windows = []
        }
        return UsageCard(
            provider: "Grok CLI",
            providerID: "grok",
            plan: defaultModel ?? "Grok",
            windows: windows,
            today: today,
            week: week,
            block: last,
            blockEndsAt: nil,
            lastSession: last,
            lastSessionAt: lastAt,
            lastModel: lastModel ?? defaultModel,
            note: sessions.isEmpty
                ? "No local Grok session signals yet."
                : "Tokens from ~/.grok/sessions/*/signals.json. Not an xAI remaining-quota bar.",
            featured: FileManager.default.fileExists(atPath: (home as NSString).appendingPathComponent(".grok"))
        )
    }

    private struct GrokSignal {
        let tokens: Int
        let contextUsed: Int
        let contextWindow: Int
        let model: String?
        let updated: Date
    }

    private static func grokSessionSignals() -> [GrokSignal] {
        let root = (home as NSString).appendingPathComponent(".grok/sessions")
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: root) else { return [] }
        var rows: [GrokSignal] = []
        var visited = 0
        while let relative = enumerator.nextObject() as? String {
            visited += 1
            if visited > 6_000 { break }
            guard relative.hasSuffix("/signals.json") || relative == "signals.json" else { continue }
            let path = (root as NSString).appendingPathComponent(relative)
            guard
                let data = fm.contents(atPath: path),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            let tokens = int(object["totalTokensBeforeCompaction"])
                ?? int(object["contextTokensUsed"])
                ?? 0
            let used = int(object["contextTokensUsed"]) ?? tokens
            let window = int(object["contextWindowTokens"]) ?? 0
            let model = string(object["primaryModelId"])
            let mtime = (try? fm.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? .distantPast
            let summaryPath = ((path as NSString).deletingLastPathComponent as NSString).appendingPathComponent("summary.json")
            let updated: Date
            if let summaryData = fm.contents(atPath: summaryPath),
               let summary = try? JSONSerialization.jsonObject(with: summaryData) as? [String: Any],
               let date = parseDate(summary["last_active_at"]) ?? parseDate(summary["updated_at"]) {
                updated = date
            } else {
                updated = mtime
            }
            rows.append(GrokSignal(tokens: tokens, contextUsed: used, contextWindow: window, model: model, updated: updated))
            if rows.count >= 200 { break }
        }
        return rows
    }

    private static func grokDefaultModel() -> String? {
        let path = (home as NSString).appendingPathComponent(".grok/config.toml")
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        for line in raw.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("default"),
               let start = trimmed.firstIndex(of: "\""),
               let end = trimmed[trimmed.index(after: start)...].firstIndex(of: "\"") {
                return String(trimmed[trimmed.index(after: start)..<end])
            }
        }
        return nil
    }

    // MARK: - Pi / Command Code

    private static func piCard() -> UsageCard {
        let events = loadEvents(
            under: [(home as NSString).appendingPathComponent(".pi/agent/sessions")],
            kind: .generic
        )
        let snapshot = snapshot(from: events)
        return UsageCard(
            provider: "Pi",
            providerID: "pi",
            plan: "Local sessions",
            windows: [],
            today: snapshot.today,
            week: snapshot.week,
            block: snapshot.block,
            blockEndsAt: snapshot.blockEndsAt,
            lastSession: snapshot.lastSession,
            lastSessionAt: snapshot.lastSessionAt,
            lastModel: snapshot.lastModel,
            note: "Pi does not publish a vendor quota file.",
            featured: false
        )
    }

    private static func commandCodeCard() -> UsageCard {
        let events = loadEvents(
            under: [(home as NSString).appendingPathComponent(".commandcode/projects")],
            kind: .generic
        )
        let snapshot = snapshot(from: events)
        return UsageCard(
            provider: "Command Code",
            providerID: "command-code",
            plan: "Local sessions",
            windows: [],
            today: snapshot.today,
            week: snapshot.week,
            block: snapshot.block,
            blockEndsAt: snapshot.blockEndsAt,
            lastSession: snapshot.lastSession,
            lastSessionAt: snapshot.lastSessionAt,
            lastModel: snapshot.lastModel,
            note: "Remaining quota is only on their Studio site.",
            featured: false
        )
    }

    // MARK: - Events

    private enum Kind { case claude, codex, generic }

    private struct Event {
        let date: Date
        let file: String
        let model: String?
        let totals: UsageTotals
        let requestID: String?
    }

    private struct Snapshot {
        var today = UsageTotals()
        var week = UsageTotals()
        var block = UsageTotals()
        var blockEndsAt: Date?
        var lastSession = UsageTotals()
        var lastSessionAt: Date?
        var lastModel: String?
    }

    private static func loadEvents(under roots: [String], kind: Kind) -> [Event] {
        var events: [Event] = []
        var seen = Set<String>()
        for file in newestSessionFiles(under: roots, limit: 80) {
            events.append(contentsOf: eventsInFile(file.path, kind: kind, seen: &seen))
        }
        return events.sorted { $0.date < $1.date }
    }

    private static func eventsInFile(_ path: String, kind: Kind, seen: inout Set<String>) -> [Event] {
        guard let handle = FileHandle(forReadingAtPath: path) else { return [] }
        defer { try? handle.close() }
        let data = handle.readDataToEndOfFile()
        guard data.count < 8_000_000,
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return [] }

        var result: [Event] = []
        for line in text.split(whereSeparator: \.isNewline) {
            guard let payload = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
                continue
            }
            guard let totals = totals(in: object, kind: kind), totals.tokens > 0 else { continue }
            let requestID = string(object["requestId"]) ?? string(object["request_id"])
            if let requestID, !seen.insert("\(path)|\(requestID)").inserted { continue }
            let date = parseDate(object["timestamp"]) ?? parseDate(object["created_at"]) ?? .distantPast
            let model = string((object["message"] as? [String: Any])?["model"])
                ?? string(object["model"])
            result.append(Event(date: date, file: path, model: model, totals: totals, requestID: requestID))
        }
        if kind == .codex {
            return result.suffix(1).map { $0 }
        }
        return result
    }

    private static func snapshot(from events: [Event]) -> Snapshot {
        var snap = Snapshot()
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let blockStart = activeBlockStart(in: events, now: now)
        if let blockStart {
            snap.blockEndsAt = blockStart.addingTimeInterval(5 * 60 * 60)
        }
        let lastFile = events.max(by: { $0.date < $1.date })?.file
        for event in events {
            if event.date >= weekStart { snap.week.add(event.totals) }
            if event.date >= startOfDay { snap.today.add(event.totals) }
            if let blockStart, event.date >= blockStart, event.date < blockStart.addingTimeInterval(5 * 60 * 60) {
                snap.block.add(event.totals)
            }
            if event.file == lastFile {
                snap.lastSession.add(event.totals)
                snap.lastSessionAt = event.date
                if let model = event.model { snap.lastModel = model }
            }
        }
        return snap
    }

    private static func activeBlockStart(in events: [Event], now: Date) -> Date? {
        let recent = events.filter { now.timeIntervalSince($0.date) < 5 * 60 * 60 && $0.date <= now }
        guard let first = recent.first else { return nil }
        return floorToHour(first.date)
    }

    private static func floorToHour(_ date: Date) -> Date {
        var components = Calendar.current.dateComponents(in: TimeZone.current, from: date)
        components.minute = 0
        components.second = 0
        components.nanosecond = 0
        return Calendar.current.date(from: components) ?? date
    }

    private static func totals(in object: [String: Any], kind: Kind) -> UsageTotals? {
        if kind == .codex,
           let payload = object["payload"] as? [String: Any],
           let info = payload["info"] as? [String: Any],
           let bag = info["last_token_usage"] as? [String: Any] ?? info["total_token_usage"] as? [String: Any] {
            return priced(bag, model: string(object["model"]), explicitCost: nil)
        }
        if let message = object["message"] as? [String: Any],
           (message["role"] as? String) == "assistant" || message["usage"] != nil,
           let bag = message["usage"] as? [String: Any] {
            return priced(bag, model: string(message["model"]), explicitCost: double(object["costUSD"]) ?? double(object["cost"]))
        }
        if let bag = object["usage"] as? [String: Any] {
            return priced(bag, model: string(object["model"]), explicitCost: double(object["costUSD"]) ?? double(object["cost"]))
        }
        return nil
    }

    static func priced(_ bag: [String: Any], model: String?, explicitCost: Double?) -> UsageTotals {
        let input = int(bag["input_tokens"]) ?? int(bag["input"]) ?? 0
        let output = int(bag["output_tokens"]) ?? int(bag["output"]) ?? 0
        let cacheWrite = int(bag["cache_creation_input_tokens"]) ?? 0
        let cacheRead = int(bag["cache_read_input_tokens"]) ?? 0
        let cache = bag["cache_creation"] as? [String: Any] ?? [:]
        let write1h = int(cache["ephemeral_1h_input_tokens"]) ?? 0
        let write5m = int(cache["ephemeral_5m_input_tokens"]) ?? max(0, cacheWrite - write1h)
        var totals = UsageTotals(input: input, output: output, cacheWrite: cacheWrite, cacheRead: cacheRead, cost: 0)
        if let explicitCost, explicitCost > 0 {
            totals.cost = explicitCost
        } else {
            let rate = rates(for: model)
            totals.cost =
                Double(input) * rate.input
                + Double(output) * rate.output
                + Double(write5m) * rate.input * 1.25
                + Double(write1h) * rate.input * 2.0
                + Double(cacheRead) * rate.input * 0.1
        }
        return totals
    }

    private static func rates(for model: String?) -> (input: Double, output: Double) {
        let name = (model ?? "").lowercased()
        if name.contains("haiku") { return (1.0 / 1_000_000, 5.0 / 1_000_000) }
        if name.contains("opus") { return (15.0 / 1_000_000, 75.0 / 1_000_000) }
        if name.contains("sonnet") { return (3.0 / 1_000_000, 15.0 / 1_000_000) }
        if name.contains("gpt") || name.contains("codex") { return (2.0 / 1_000_000, 8.0 / 1_000_000) }
        if name.contains("grok") { return (3.0 / 1_000_000, 15.0 / 1_000_000) }
        return (3.0 / 1_000_000, 15.0 / 1_000_000)
    }

    // MARK: - Files

    private struct SessionFile {
        let path: String
        let mtime: Date
    }

    private static func newestSessionFiles(under roots: [String], limit: Int) -> [SessionFile] {
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-8 * 24 * 60 * 60)
        var files: [SessionFile] = []
        for root in roots {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: root, isDirectory: &isDir), isDir.boolValue else { continue }
            guard let enumerator = fm.enumerator(atPath: root) else { continue }
            var visited = 0
            while let relative = enumerator.nextObject() as? String {
                visited += 1
                if visited > 4_000 { break }
                let lowered = relative.lowercased()
                if lowered.contains("node_modules") || lowered.contains("/.git/") || lowered.contains("/.build/") {
                    enumerator.skipDescendants()
                    continue
                }
                guard relative.hasSuffix(".jsonl") else { continue }
                let path = (root as NSString).appendingPathComponent(relative)
                let mtime = (try? fm.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? .distantPast
                guard mtime >= cutoff else { continue }
                files.append(SessionFile(path: path, mtime: mtime))
            }
        }
        return files.sorted { $0.mtime > $1.mtime }.prefix(limit).map { $0 }
    }

    private static func lastJSONObject(in path: String, matching: ([String: Any]) -> Bool) -> [String: Any]? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let size = handle.seekToEndOfFile()
        let window = min(size, 256_000)
        handle.seek(toFileOffset: size > window ? size - window : 0)
        let data = handle.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return nil
        }
        var match: [String: Any]?
        for line in text.split(whereSeparator: \.isNewline) {
            guard let payload = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
                  matching(object) else { continue }
            match = object
        }
        return match
    }

    static func tokens(in object: [String: Any]) -> (total: Int, last: Int?) {
        if let payload = object["payload"] as? [String: Any],
           let info = payload["info"] as? [String: Any] {
            let last = tokenBag(info["last_token_usage"])
            let total = tokenBag(info["total_token_usage"])
            return (total ?? last ?? 0, last)
        }
        let bags = [
            object["usage"] as? [String: Any],
            object["token_count"] as? [String: Any],
            (object["message"] as? [String: Any])?["usage"] as? [String: Any]
        ]
        var sum = 0
        for bag in bags {
            if let value = tokenBag(bag) { sum += value }
        }
        return (sum, sum == 0 ? nil : sum)
    }

    private static func tokenBag(_ raw: Any?) -> Int? {
        guard let bag = raw as? [String: Any] else { return nil }
        let input = int(bag["input_tokens"]) ?? int(bag["input"]) ?? 0
        let output = int(bag["output_tokens"]) ?? int(bag["output"]) ?? 0
        let total = int(bag["total_tokens"])
        let value = total ?? (input + output)
        return value > 0 ? value : nil
    }

    private static func window(from raw: [String: Any], title: String) -> UsageWindow {
        UsageWindow(
            title: title,
            usedPercent: min(max(double(raw["used_percent"]) ?? 0, 0), 100),
            resetsAt: int(raw["resets_at"]).map { Date(timeIntervalSince1970: TimeInterval($0)) },
            windowMinutes: int(raw["window_minutes"])
        )
    }

    private static func windowTitle(minutes: Int?) -> String {
        switch minutes {
        case 300, 270, 240: return "5-hour"
        case 10080: return "Weekly"
        case let value?:
            if value >= 10080 { return "Weekly" }
            if value >= 240 && value <= 360 { return "5-hour" }
            return "\(value) min"
        default:
            return "Limit"
        }
    }

    private static func parseDate(_ value: Any?) -> Date? {
        if let seconds = value as? Int {
            return Date(timeIntervalSince1970: TimeInterval(seconds))
        }
        if let seconds = value as? Double {
            if seconds > 1_000_000_000_000 {
                return Date(timeIntervalSince1970: seconds / 1000)
            }
            return Date(timeIntervalSince1970: seconds)
        }
        if let string = value as? String {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: string) { return date }
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: string)
        }
        return nil
    }

    private static func string(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func int(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? Double { return Int(number) }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private static func double(_ value: Any?) -> Double? {
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        if let string = value as? String { return Double(string) }
        return nil
    }
}
