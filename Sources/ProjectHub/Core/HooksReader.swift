import Foundation

// MARK: - Hook entry model

struct HookEntry: Identifiable {
    let id: UUID = UUID()
    let tool: String        // "Claude Code", "Codex"
    let event: String       // "PreToolUse", "Stop", etc.
    let matcher: String?    // Claude only — tool matcher pattern
    let command: String     // the shell command
    let scope: String       // "project" | "global"
}

// MARK: - Hooks reader

enum HooksReader {

    static func hooks(for projectPath: String) -> [HookEntry] {
        var entries: [HookEntry] = []
        entries += claudeHooks(for: projectPath)
        entries += codexHooks(for: projectPath)
        return entries
    }

    // MARK: - Claude Code

    private static func claudeHooks(for projectPath: String) -> [HookEntry] {
        let home = NSHomeDirectory()
        let sources: [(path: String, scope: String)] = [
            ((projectPath as NSString).appendingPathComponent(".claude/settings.json"),       "project"),
            ((projectPath as NSString).appendingPathComponent(".claude/settings.local.json"), "project"),
            ((home as NSString).appendingPathComponent(".claude/settings.json"),              "global"),
        ]

        var entries: [HookEntry] = []
        for source in sources {
            entries += parseClaude(file: source.path, scope: source.scope)
        }
        return entries
    }

    private static func parseClaude(file: String, scope: String) -> [HookEntry] {
        guard
            let data = FileManager.default.contents(atPath: file),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let hooksDict = json["hooks"] as? [String: Any]
        else { return [] }

        var entries: [HookEntry] = []

        for (event, eventVal) in hooksDict {
            guard let groups = eventVal as? [[String: Any]] else { continue }
            for group in groups {
                let matcher = group["matcher"] as? String
                guard let hookItems = group["hooks"] as? [[String: Any]] else { continue }
                for hookItem in hookItems {
                    guard
                        let type = hookItem["type"] as? String, type == "command",
                        let command = hookItem["command"] as? String
                    else { continue }
                    entries.append(HookEntry(
                        tool:    "Claude Code",
                        event:   event,
                        matcher: matcher,
                        command: command,
                        scope:   scope
                    ))
                }
            }
        }
        return entries
    }

    // MARK: - Codex

    private static func codexHooks(for projectPath: String) -> [HookEntry] {
        let codexHome = ProjectHubPaths.codexHome(home: NSHomeDirectory())
        var entries: [HookEntry] = []

        entries += parseCodexJSON(
            file: (codexHome as NSString).appendingPathComponent("hooks.json"),
            scope: "global"
        )
        entries += parseCodexTOML(
            file: (codexHome as NSString).appendingPathComponent("config.toml"),
            scope: "global"
        )

        if codexProjectIsTrusted(projectPath: projectPath, codexHome: codexHome) {
            let projectCodexDir = (projectPath as NSString).appendingPathComponent(".codex")
            entries += parseCodexJSON(
                file: (projectCodexDir as NSString).appendingPathComponent("hooks.json"),
                scope: "project"
            )
            entries += parseCodexTOML(
                file: (projectCodexDir as NSString).appendingPathComponent("config.toml"),
                scope: "project"
            )
        }

        return entries
    }

    private static func parseCodexJSON(file: String, scope: String) -> [HookEntry] {
        guard
            let data = FileManager.default.contents(atPath: file),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        let hooksDict = json["hooks"] as? [String: Any] ?? json
        return codexHookEntries(from: hooksDict, scope: scope)
    }

    private static func parseCodexTOML(file: String, scope: String) -> [HookEntry] {
        guard
            let raw = try? String(contentsOfFile: file, encoding: .utf8)
        else { return [] }

        var entries: [HookEntry] = []
        var currentEvent: String?
        var currentMatcher: String?
        var inHookHandler = false

        for rawLine in raw.components(separatedBy: .newlines) {
            let trimmed = stripTOMLComment(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("[[") && trimmed.hasSuffix("]]") {
                let section = String(trimmed.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                let parts = dottedTOMLSegments(section)
                if parts.count == 2, parts[0] == "hooks" {
                    currentEvent = parts[1]
                    currentMatcher = nil
                    inHookHandler = false
                } else if parts.count == 3, parts[0] == "hooks", parts[2] == "hooks" {
                    currentEvent = parts[1]
                    inHookHandler = true
                } else {
                    currentEvent = nil
                    currentMatcher = nil
                    inHookHandler = false
                }
                continue
            }

            guard let equals = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<equals].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = trimmed[trimmed.index(after: equals)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if key == "matcher", !inHookHandler {
                currentMatcher = tomlString(rawValue)
                continue
            }
            if key == "command", inHookHandler,
               let event = currentEvent,
               let command = tomlString(rawValue) {
                entries.append(HookEntry(
                    tool: "Codex",
                    event: event,
                    matcher: currentMatcher,
                    command: command,
                    scope: scope
                ))
            }
        }

        return entries
    }

    private static func codexHookEntries(from hooksDict: [String: Any], scope: String) -> [HookEntry] {
        var entries: [HookEntry] = []
        for (event, eventVal) in hooksDict {
            guard let groups = eventVal as? [[String: Any]] else { continue }
            for group in groups {
                let matcher = group["matcher"] as? String
                guard let hookItems = group["hooks"] as? [[String: Any]] else { continue }
                for hookItem in hookItems {
                    guard
                        let type = hookItem["type"] as? String, type == "command",
                        let command = hookItem["command"] as? String
                    else { continue }
                    entries.append(HookEntry(
                        tool:    "Codex",
                        event:   event,
                        matcher: matcher,
                        command: command,
                        scope:   scope
                    ))
                }
            }
        }
        return entries
    }

    private static func codexProjectIsTrusted(projectPath: String, codexHome: String) -> Bool {
        ConfigWriter.codexProjectTrustLevel(
            globalConfigPath: (codexHome as NSString).appendingPathComponent("config.toml"),
            projectRoot: projectPath
        ) == "trusted"
    }

    private static func stripTOMLComment(_ line: String) -> String {
        var result = ""
        var inSingle = false
        var inDouble = false
        var escaping = false
        for char in line {
            if char == "\\" && inDouble && !escaping {
                escaping = true
                result.append(char)
                continue
            }
            if char == "'" && !inDouble {
                inSingle.toggle()
            } else if char == "\"" && !inSingle && !escaping {
                inDouble.toggle()
            } else if char == "#", !inSingle, !inDouble {
                break
            }
            escaping = false
            result.append(char)
        }
        return result
    }

    private static func tomlString(_ raw: Substring) -> String? {
        tomlString(String(raw))
    }

    private static func tomlString(_ raw: String) -> String? {
        let value = stripTOMLComment(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2 else { return nil }
        if value.hasPrefix("\""), value.hasSuffix("\"") {
            let inner = String(value.dropFirst().dropLast())
            return inner
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }
        if value.hasPrefix("'"), value.hasSuffix("'") {
            return String(value.dropFirst().dropLast())
        }
        return nil
    }

    private static func dottedTOMLSegments(_ value: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escaping = false
        for char in value {
            if char == "\\" && inDouble && !escaping {
                escaping = true
                current.append(char)
                continue
            }
            if char == "'" && !inDouble {
                inSingle.toggle()
                current.append(char)
            } else if char == "\"" && !inSingle && !escaping {
                inDouble.toggle()
                current.append(char)
            } else if char == ".", !inSingle, !inDouble {
                parts.append(trimTOMLSegment(current))
                current = ""
            } else {
                current.append(char)
            }
            escaping = false
        }
        parts.append(trimTOMLSegment(current))
        return parts
    }

    private static func trimTOMLSegment(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return tomlString(trimmed) ?? trimmed
    }
}
