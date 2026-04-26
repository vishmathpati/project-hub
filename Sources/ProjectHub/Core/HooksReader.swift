import Foundation

// MARK: - Hook entry model

struct HookEntry: Identifiable {
    let id: UUID = UUID()
    let tool: String        // "Claude Code", "Codex", "Cursor"
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
        entries += codexHooks()
        entries += cursorHooks()
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

    private static func codexHooks() -> [HookEntry] {
        let home = NSHomeDirectory()
        let file = (home as NSString).appendingPathComponent(".codex/hooks.json")

        guard
            let data = FileManager.default.contents(atPath: file),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let hooksDict = json["hooks"] as? [String: Any]
        else { return [] }

        var entries: [HookEntry] = []

        for (event, eventVal) in hooksDict {
            guard let groups = eventVal as? [[String: Any]] else { continue }
            for group in groups {
                guard let hookItems = group["hooks"] as? [[String: Any]] else { continue }
                for hookItem in hookItems {
                    guard
                        let type = hookItem["type"] as? String, type == "command",
                        let command = hookItem["command"] as? String
                    else { continue }
                    entries.append(HookEntry(
                        tool:    "Codex",
                        event:   event,
                        matcher: nil,
                        command: command,
                        scope:   "global"
                    ))
                }
            }
        }
        return entries
    }

    // MARK: - Cursor

    private static func cursorHooks() -> [HookEntry] {
        let home = NSHomeDirectory()
        let file = (home as NSString).appendingPathComponent(".cursor/hooks.json")

        guard
            let data = FileManager.default.contents(atPath: file),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let hooksDict = json["hooks"] as? [String: Any]
        else { return [] }

        var entries: [HookEntry] = []

        for (event, eventVal) in hooksDict {
            guard let items = eventVal as? [[String: Any]] else { continue }
            for item in items {
                guard let command = item["command"] as? String else { continue }
                entries.append(HookEntry(
                    tool:    "Cursor",
                    event:   event,
                    matcher: nil,
                    command: command,
                    scope:   "global"
                ))
            }
        }
        return entries
    }
}
