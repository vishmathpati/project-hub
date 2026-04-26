import Foundation

// MARK: - MCP config reader (read-only)

enum MCPReader {

    /// Read all MCP servers for a project path across all three config sources.
    static func servers(for projectPath: String) -> [MCPServerInfo] {
        var results: [MCPServerInfo] = []
        results += fromClaudeCode(projectPath)
        results += fromCodex(projectPath)
        results += fromCursor(projectPath)
        return results
    }

    // MARK: - Claude Code (.mcp.json)

    static func fromClaudeCode(_ projectPath: String) -> [MCPServerInfo] {
        let jsonPath = (projectPath as NSString).appendingPathComponent(".mcp.json")
        guard let data = FileManager.default.contents(atPath: jsonPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = json["mcpServers"] as? [String: Any]
        else { return [] }

        return servers.keys.sorted().map { name in
            let cfg = servers[name] as? [String: Any] ?? [:]
            let detail = serverDetail(from: cfg)
            return MCPServerInfo(source: .claudeCode, name: name, detail: detail)
        }
    }

    // MARK: - Cursor (.cursor/mcp.json)

    static func fromCursor(_ projectPath: String) -> [MCPServerInfo] {
        let jsonPath = (projectPath as NSString).appendingPathComponent(".cursor/mcp.json")
        guard let data = FileManager.default.contents(atPath: jsonPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = json["mcpServers"] as? [String: Any]
        else { return [] }

        return servers.keys.sorted().map { name in
            let cfg = servers[name] as? [String: Any] ?? [:]
            let detail = serverDetail(from: cfg)
            return MCPServerInfo(source: .cursor, name: name, detail: detail)
        }
    }

    // MARK: - Codex (.codex/config.toml) — simple regex parser

    static func fromCodex(_ projectPath: String) -> [MCPServerInfo] {
        let tomlPath = (projectPath as NSString).appendingPathComponent(".codex/config.toml")
        guard let content = try? String(contentsOfFile: tomlPath, encoding: .utf8) else { return [] }

        // Match [mcp_servers."<name>"] section headers and gather key-value pairs
        guard let sectionRegex = try? NSRegularExpression(
            pattern: #"\[mcp_servers\."([^"]+)"\]"#
        ) else { return [] }

        let nsContent = content as NSString
        let fullRange = NSRange(location: 0, length: nsContent.length)
        let matches = sectionRegex.matches(in: content, range: fullRange)

        var results: [MCPServerInfo] = []

        for (i, match) in matches.enumerated() {
            guard let nameRange = Range(match.range(at: 1), in: content) else { continue }
            let name = String(content[nameRange])

            // Content between this header and the next
            let sectionStart = match.range.upperBound
            let sectionEnd   = i + 1 < matches.count
                ? matches[i + 1].range.lowerBound
                : content.endIndex.utf16Offset(in: content)

            let sectionRange = NSRange(location: sectionStart, length: sectionEnd - sectionStart)
            guard let swiftRange = Range(sectionRange, in: content) else { continue }
            let sectionText = String(content[swiftRange])

            let cmd = tomlValue(key: "command", in: sectionText)
            let url = tomlValue(key: "url",     in: sectionText)
            let detail = cmd ?? url ?? ""

            results.append(MCPServerInfo(source: .codex, name: name, detail: detail))
        }

        return results
    }

    // MARK: - Helpers

    private static func serverDetail(from cfg: [String: Any]) -> String {
        if let url = cfg["url"] as? String { return url }
        let cmd  = cfg["command"] as? String ?? ""
        let args = cfg["args"] as? [String] ?? []
        return ([cmd] + args).filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Extract a simple `key = "value"` or `key = value` from a TOML section string.
    private static func tomlValue(key: String, in text: String) -> String? {
        let pattern = #"^\s*"# + NSRegularExpression.escapedPattern(for: key) + #"\s*=\s*"?([^"\n]+)"?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return nil }
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}
