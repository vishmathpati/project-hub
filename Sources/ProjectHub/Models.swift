import Foundation

// MARK: - Skill models

enum SkillSource: String, Codable {
    case claudeGlobal
    case codexGlobal
    case cursorGlobal

    var label: String {
        switch self {
        case .claudeGlobal: return "Claude"
        case .codexGlobal:  return "Codex"
        case .cursorGlobal: return "Cursor"
        }
    }
}

struct Skill: Identifiable {
    var id: String { name }
    let name: String
    let description: String
    let triggers: [String]
    let source: SkillSource
    let path: String          // full path to skill directory
}

struct InstalledSkill: Identifiable {
    var id: String { name }
    let name: String
    let description: String
    let claudePath: String?   // .claude/skills/<name> if present
    let codexPath: String?    // .agents/skills/<name> if present
}

// MARK: - Agent models

struct Agent: Identifiable {
    var id: String { name }
    let name: String
    let description: String
    let model: String
    let tools: [String]
    let filePath: String
    let body: String          // markdown body after frontmatter
}

struct AgentTemplate {
    let name: String
    let description: String
    let model: String
    let tools: [String]
}

// MARK: - MCP models

enum MCPConfigSource: String {
    case claudeCode = "claude-code"
    case codex
    case cursor

    var label: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex:      return "Codex"
        case .cursor:     return "Cursor"
        }
    }

    var configRelativePath: String {
        switch self {
        case .claudeCode: return ".mcp.json"
        case .codex:      return ".codex/config.toml"
        case .cursor:     return ".cursor/mcp.json"
        }
    }
}

struct MCPServerInfo: Identifiable {
    var id: String { "\(source.rawValue)/\(name)" }
    let source: MCPConfigSource
    let name: String
    let detail: String        // command or URL
}

// MARK: - Global MCP tool models (mirrors MCPBolt)

struct ServerEntry: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let transport: String   // "stdio" | "http" | "sse"
    let command: String?
    let args: [String]
    let url: String?
    var isDisabled: Bool = false

    var detail: String {
        if transport == "stdio" {
            let parts = ([command] + args.map { Optional($0) }).compactMap { $0 }
            return parts.joined(separator: " ")
        }
        return url ?? ""
    }
}

struct ToolSummary: Identifiable {
    var id: String { toolID }
    let toolID: String
    let label: String
    let short: String
    let detected: Bool
    var servers: [ServerEntry]
}

/// Tool IDs hidden from UI but still read/written normally.
let HIDDEN_TOOL_IDS: Set<String> = ["continue"]

let ALL_TOOL_META: [(id: String, label: String, short: String)] = [
    ("claude-desktop", "Claude Desktop", "CD"),
    ("claude-code",    "Claude Code",    "CC"),
    ("cursor",         "Cursor",         "Cu"),
    ("vscode",         "VS Code",        "VS"),
    ("codex",          "Codex",          "Cx"),
    ("windsurf",       "Windsurf",       "Wi"),
    ("zed",            "Zed",            "Ze"),
    ("continue",       "Continue",       "Co"),
    ("gemini",         "Gemini",         "Ge"),
    ("roo",            "Roo",            "Ro"),
    ("opencode",       "opencode",       "Oc"),
    ("cline",          "Cline",          "Cl"),
]
