import Foundation

struct SessionExplorerSession: Identifiable, Equatable {
    var id: String { path }
    let path: String
    let title: String
    let firstAt: Date?
    let lastAt: Date?
    let messageCount: Int
    let tokenTotal: Int
    let cost: Double
}

enum SessionExplorerRole: String, Equatable {
    case user
    case assistant
    case tool
    case system
}

struct SessionExplorerEntry: Identifiable, Equatable {
    var id: Int { index }
    let index: Int
    let role: SessionExplorerRole
    let timestamp: Date?
    let text: String
    let toolName: String?
    let tokens: Int?
}

struct SessionExplorerToolFrequency: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let count: Int
}

enum SessionExplorerReader {
    static var homeOverride: String?
    static let maxFileBytes = 8 * 1024 * 1024
    static let maxEntries = 800
    static let maxTextChars = 2000
    static let maxSessions = 150

    static func sessions(forProjectPath projectPath: String) -> [SessionExplorerSession] {
        var rows: [SessionExplorerSession] = []
        for dir in projectDirs(for: projectPath) {
            rows += sessionFiles(under: dir).map { summarizeFile(at: $0.path, mtime: $0.mtime) }
        }
        return rows.sorted { ($0.lastAt ?? .distantPast) > ($1.lastAt ?? .distantPast) }
    }

    static func transcript(forSessionPath path: String) -> [SessionExplorerEntry] {
        guard fileSize(at: path) <= maxFileBytes, let data = FileManager.default.contents(atPath: path) else { return [] }
        var entries: [SessionExplorerEntry] = []
        var index = 0
        for raw in data.split(separator: UInt8(ascii: "\n")) {
            if entries.count >= maxEntries { break }
            guard let object = try? JSONSerialization.jsonObject(with: Data(raw)) as? [String: Any] else { continue }
            if let entry = entry(from: object, index: index) {
                entries.append(entry)
                index += 1
            }
        }
        return entries
    }

    static func toolFrequencies(for entries: [SessionExplorerEntry]) -> [SessionExplorerToolFrequency] {
        var counts: [String: Int] = [:]
        for entry in entries {
            if let name = entry.toolName { counts[name, default: 0] += 1 }
        }
        return counts.map { SessionExplorerToolFrequency(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Files

    private struct FoundFile {
        let path: String
        let mtime: Date
    }

    private static func home() -> String {
        homeOverride ?? UsageReader.homeOverride ?? NSHomeDirectory()
    }

    private static func projectDirs(for projectPath: String) -> [String] {
        let root = (home() as NSString).appendingPathComponent(".claude/projects")
        let fm = FileManager.default
        let trimmed = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/") {
            let encoded = "-" + String(trimmed.dropFirst()).replacingOccurrences(of: "/", with: "-")
            let direct = (root as NSString).appendingPathComponent(encoded)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: direct, isDirectory: &isDir), isDir.boolValue { return [direct] }
            return subdirs(of: root).filter { decodeProjectDir(($0 as NSString).lastPathComponent) == trimmed }
        }
        let direct = (root as NSString).appendingPathComponent(trimmed)
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: direct, isDirectory: &isDir), isDir.boolValue { return [direct] }
        return []
    }

    private static func subdirs(of root: String) -> [String] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: root) else { return [] }
        return names.map { (root as NSString).appendingPathComponent($0) }
    }

    private static func decodeProjectDir(_ encoded: String) -> String? {
        guard encoded.hasPrefix("-") else { return nil }
        return "/" + String(encoded.dropFirst()).replacingOccurrences(of: "-", with: "/")
    }

    private static func sessionFiles(under dir: String) -> [FoundFile] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: dir) else { return [] }
        var files: [FoundFile] = []
        var visited = 0
        while let relative = enumerator.nextObject() as? String {
            visited += 1
            if visited > 5_000 { break }
            guard relative.hasSuffix(".jsonl") else { continue }
            let path = (dir as NSString).appendingPathComponent(relative)
            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let mtime = attrs[.modificationDate] as? Date
            else { continue }
            files.append(FoundFile(path: path, mtime: mtime))
        }
        return Array(files.sorted { $0.mtime > $1.mtime }.prefix(maxSessions))
    }

    private static func summarizeFile(at path: String, mtime: Date) -> SessionExplorerSession {
        let title = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        let empty = SessionExplorerSession(path: path, title: title, firstAt: nil, lastAt: mtime, messageCount: 0, tokenTotal: 0, cost: 0)
        guard fileSize(at: path) <= maxFileBytes, let data = FileManager.default.contents(atPath: path) else { return empty }
        var count = 0
        var tokens = 0
        var cost = 0.0
        var first: Date?
        var last: Date?
        for raw in data.split(separator: UInt8(ascii: "\n")) {
            guard let object = try? JSONSerialization.jsonObject(with: Data(raw)) as? [String: Any],
                  includeLine(object)
            else { continue }
            count += 1
            tokens += UsageReader.tokens(in: object).total
            cost += costOf(object)
            if let date = parseDate(object["timestamp"]) {
                if first == nil || date < first! { first = date }
                if last == nil || date > last! { last = date }
            }
        }
        return SessionExplorerSession(path: path, title: title, firstAt: first, lastAt: last ?? mtime, messageCount: count, tokenTotal: tokens, cost: cost)
    }

    private static func fileSize(at path: String) -> Int {
        (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
    }

    // MARK: - Lines

    private static func includeLine(_ object: [String: Any]) -> Bool {
        if UsageReader.tokens(in: object).total > 0 { return true }
        if string(object["summary"]) != nil { return true }
        let message = object["message"] as? [String: Any]
        if let content = message?["content"] ?? object["content"] {
            if let text = content as? String { return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if let blocks = content as? [[String: Any]] { return !blocks.isEmpty }
        }
        return string(object["text"]) != nil
    }

    private static func entry(from object: [String: Any], index: Int) -> SessionExplorerEntry? {
        let message = object["message"] as? [String: Any]
        let (text, toolName, isToolResult) = extractContent(object, message: message)
        let total = UsageReader.tokens(in: object).total
        guard !text.isEmpty || toolName != nil || total > 0 else { return nil }
        return SessionExplorerEntry(
            index: index,
            role: roleOf(object, message: message, toolName: toolName, isToolResult: isToolResult),
            timestamp: parseDate(object["timestamp"]),
            text: truncate(text),
            toolName: toolName,
            tokens: total > 0 ? total : nil
        )
    }

    private static func extractContent(_ object: [String: Any], message: [String: Any]?) -> (String, String?, Bool) {
        if string(object["type"]) == "summary", let summary = string(object["summary"]) {
            return (summary, nil, false)
        }
        var texts: [String] = []
        var tools: [String] = []
        var isToolResult = false
        let content = message?["content"] ?? object["content"]
        if let text = content as? String {
            texts.append(text)
        } else if let blocks = content as? [[String: Any]] {
            for block in blocks {
                switch block["type"] as? String {
                case "text":
                    if let text = string(block["text"]) { texts.append(text) }
                case "tool_use":
                    if let name = string(block["name"]) { tools.append(name) }
                case "tool_result":
                    isToolResult = true
                    if let name = string(block["name"]) { tools.append(name) }
                    if let text = string(block["content"]) {
                        texts.append(text)
                    } else if let parts = block["content"] as? [[String: Any]] {
                        for part in parts {
                            if let text = string(part["text"]) { texts.append(text) }
                        }
                    }
                default:
                    if let text = string(block["text"]) { texts.append(text) }
                }
            }
        }
        if texts.isEmpty, let fallback = string(object["text"]) ?? string(object["summary"]) {
            texts.append(fallback)
        }
        let joined = texts.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (joined, tools.first, isToolResult)
    }

    private static func roleOf(_ object: [String: Any], message: [String: Any]?, toolName: String?, isToolResult: Bool) -> SessionExplorerRole {
        let type = string(object["type"])
        let role = string(message?["role"]) ?? string(object["role"])
        if isToolResult || role == "tool" || type == "tool_result" { return .tool }
        if type == "summary" || type == "system" { return .system }
        if role == "user" || role == "human" || type == "user" { return .user }
        if role == "assistant" || type == "assistant" { return .assistant }
        if toolName != nil { return .assistant }
        return .system
    }

    private static func costOf(_ object: [String: Any]) -> Double {
        let message = object["message"] as? [String: Any]
        let explicit = double(object["costUSD"]) ?? double(object["cost"])
        guard let bag = (object["usage"] as? [String: Any]) ?? (message?["usage"] as? [String: Any]) else {
            return explicit ?? 0
        }
        let model = string(message?["model"]) ?? string(object["model"])
        return UsageReader.priced(bag, model: model, explicitCost: explicit).cost
    }

    private static func truncate(_ text: String) -> String {
        guard text.count > maxTextChars else { return text }
        return String(text.prefix(maxTextChars)) + "… (truncated)"
    }

    private static func parseDate(_ value: Any?) -> Date? {
        if let seconds = value as? Int { return Date(timeIntervalSince1970: TimeInterval(seconds)) }
        if let seconds = value as? Double {
            if seconds > 1_000_000_000_000 { return Date(timeIntervalSince1970: seconds / 1000) }
            return Date(timeIntervalSince1970: seconds)
        }
        if let raw = value as? String {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: raw) { return date }
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: raw)
        }
        return nil
    }

    private static func string(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func double(_ value: Any?) -> Double? {
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        if let raw = value as? String { return Double(raw) }
        return nil
    }
}
