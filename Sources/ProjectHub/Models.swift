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
