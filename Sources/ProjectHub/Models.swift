import Foundation

// MARK: - Skill models

enum SkillSource: String, Codable {
    case claudeGlobal
    case codexGlobal
    case codexAdmin
    case codexManaged
    case cursorGlobal
    case providerGlobal

    var label: String {
        switch self {
        case .claudeGlobal: return "Claude"
        case .codexGlobal:  return "Codex"
        case .codexAdmin:   return "Codex admin"
        case .codexManaged: return "Codex managed"
        case .cursorGlobal: return "Cursor"
        case .providerGlobal: return "Provider"
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
    enum State: String {
        case active
        case disabled
        case limited
        case invalid

        var label: String {
            switch self {
            case .active: return "Working"
            case .disabled: return "Disabled"
            case .limited: return "Limited"
            case .invalid: return "Broken"
            }
        }
    }

    var id: String { originID }
    let originID: String
    let name: String
    let description: String
    let claudePath: String?   // Claude-visible origin if present
    let codexPath: String?    // Codex-visible origin if present
    let path: String
    let skillMDPath: String
    let sourceLabel: String
    let scopeLabel: String
    let toolLabels: [String]
    let state: State
    let version: String?
    let diagnostics: [String]
    let canEdit: Bool
    let canRemove: Bool
    let readOnlyReason: String?

    var isEnabled: Bool { state != .disabled && state != .invalid }
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
    case claudeCodeLocal = "claude-code-local"
    case codex
    case cursor
    case vscode
    case roo
    case opencode
    case antigravity
    case pi
    case commandCode = "command-code"
    case grok

    var label: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .claudeCodeLocal: return "Claude Code local"
        case .codex:      return "Codex"
        case .cursor:     return "Cursor"
        case .vscode:     return "VS Code"
        case .roo:        return "Roo"
        case .opencode:   return "OpenCode"
        case .antigravity: return "Antigravity"
        case .pi:         return "Pi"
        case .commandCode: return "Command Code"
        case .grok:       return "Grok CLI"
        }
    }

    var configRelativePath: String {
        switch self {
        case .claudeCode: return ".mcp.json"
        case .claudeCodeLocal: return "~/.claude.json"
        case .codex:      return ".codex/config.toml"
        case .cursor:     return ".cursor/mcp.json"
        case .vscode:     return ".vscode/mcp.json"
        case .roo:        return ".roo/mcp.json"
        case .opencode:   return "opencode.json"
        case .antigravity: return ".agents/mcp_config.json"
        case .pi:         return ".pi/mcp.json"
        case .commandCode: return ".mcp.json"
        case .grok:       return ".grok/config.toml"
        }
    }
}

struct MCPServerInfo: Identifiable {
    var id: String {
        if let sourcePath, !sourcePath.isEmpty {
            return "\(source.rawValue)/\(sourcePath)/\(name)"
        }
        return "\(source.rawValue)/\(name)"
    }
    let source: MCPConfigSource
    let name: String
    let detail: String        // command or URL
    let isDisabled: Bool
    let sourcePath: String?
}

// MARK: - Global MCP tool models (mirrors MCPBolt)

struct ServerEntry: Identifiable, Hashable {
    var id: String { sourcePath.map { "\(name)@\($0)" } ?? name }
    let name: String
    let transport: String   // "stdio" | "http" | "sse" | "ws"
    let command: String?
    let args: [String]
    let cwd: String?
    let url: String?
    let env: [String: String]
    let headers: [String: String]
    let headersHelper: String?
    let oauth: [String: String]
    let bearerTokenEnvVar: String?
    let envVars: [String]
    let envFile: String?
    let sandboxEnabled: Bool?
    let sandboxSummary: String?
    let devSummary: String?
    let enabledTools: [String]
    let alwaysAllowTools: [String]
    let disabledTools: [String]
    let defaultToolApprovalMode: String?
    let toolApprovalModes: [String: String]
    let watchPaths: [String]
    let serverTimeoutSeconds: TimeInterval?
    let startupTimeoutSeconds: TimeInterval?
    let toolTimeoutSeconds: TimeInterval?
    let sourcePath: String?
    let sourceLabel: String?
    let isReadOnly: Bool
    let readOnlyReason: String?
    let codexPluginID: String?
    let codexPluginPolicyConfigPath: String?
    let codexPluginPolicyProfileName: String?
    let codexPluginEnabled: Bool?
    var isDisabled: Bool = false

    init(
        name: String,
        transport: String,
        command: String?,
        args: [String],
        cwd: String? = nil,
        url: String?,
        env: [String: String],
        headers: [String: String],
        headersHelper: String? = nil,
        oauth: [String: String] = [:],
        bearerTokenEnvVar: String?,
        envVars: [String] = [],
        envFile: String? = nil,
        sandboxEnabled: Bool? = nil,
        sandboxSummary: String? = nil,
        devSummary: String? = nil,
        enabledTools: [String] = [],
        alwaysAllowTools: [String] = [],
        disabledTools: [String] = [],
        defaultToolApprovalMode: String? = nil,
        toolApprovalModes: [String: String] = [:],
        watchPaths: [String] = [],
        serverTimeoutSeconds: TimeInterval? = nil,
        startupTimeoutSeconds: TimeInterval? = nil,
        toolTimeoutSeconds: TimeInterval? = nil,
        sourcePath: String? = nil,
        sourceLabel: String? = nil,
        isReadOnly: Bool = false,
        readOnlyReason: String? = nil,
        codexPluginID: String? = nil,
        codexPluginPolicyConfigPath: String? = nil,
        codexPluginPolicyProfileName: String? = nil,
        codexPluginEnabled: Bool? = nil,
        isDisabled: Bool = false
    ) {
        self.name = name
        self.transport = transport
        self.command = command
        self.args = args
        self.cwd = cwd
        self.url = url
        self.env = env
        self.headers = headers
        self.headersHelper = headersHelper
        self.oauth = oauth
        self.bearerTokenEnvVar = bearerTokenEnvVar
        self.envVars = envVars
        self.envFile = envFile
        self.sandboxEnabled = sandboxEnabled
        self.sandboxSummary = sandboxSummary
        self.devSummary = devSummary
        self.enabledTools = enabledTools
        self.alwaysAllowTools = alwaysAllowTools
        self.disabledTools = disabledTools
        self.defaultToolApprovalMode = defaultToolApprovalMode
        self.toolApprovalModes = toolApprovalModes
        self.watchPaths = watchPaths
        self.serverTimeoutSeconds = serverTimeoutSeconds
        self.startupTimeoutSeconds = startupTimeoutSeconds
        self.toolTimeoutSeconds = toolTimeoutSeconds
        self.sourcePath = sourcePath
        self.sourceLabel = sourceLabel
        self.isReadOnly = isReadOnly
        self.readOnlyReason = readOnlyReason
        self.codexPluginID = codexPluginID
        self.codexPluginPolicyConfigPath = codexPluginPolicyConfigPath
        self.codexPluginPolicyProfileName = codexPluginPolicyProfileName
        self.codexPluginEnabled = codexPluginEnabled
        self.isDisabled = isDisabled
    }

    var canToggleCodexPluginPolicy: Bool {
        codexPluginID?.isEmpty == false
            && codexPluginPolicyConfigPath?.isEmpty == false
            && codexPluginEnabled != false
    }

    var detail: String {
        if transport == "stdio" {
            let parts = ([command] + args.map { Optional($0) }).compactMap { $0 }
            var launch = parts.joined(separator: " ")
            if let cwd, !cwd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                launch += " (cwd: \(cwd))"
            }
            if sandboxEnabled == true {
                launch += " (sandboxed)"
            }
            if devSummary != nil {
                launch += " (dev)"
            }
            if !enabledTools.isEmpty {
                launch += " (enabled tools: \(enabledTools.count))"
            }
            if !alwaysAllowTools.isEmpty {
                launch += " (auto-allow: \(alwaysAllowTools.count))"
            }
            if !disabledTools.isEmpty {
                launch += " (disabled tools: \(disabledTools.count))"
            }
            if let defaultToolApprovalMode {
                launch += " (approval: \(defaultToolApprovalMode))"
            }
            if !toolApprovalModes.isEmpty {
                launch += " (tool approvals: \(toolApprovalModes.count))"
            }
            return launch
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
    let configPath: String?
    var servers: [ServerEntry]
}

struct CodexPluginMCPPolicyPreview: Identifiable {
    var id: String { "\(pluginID)/\(serverName)/\(enabled)" }
    let toolID: String
    let serverName: String
    let configPath: String
    let pluginID: String
    let profileName: String?
    let enabled: Bool
    let before: String
    let after: String
}

enum MCPHealthStatus: String, CaseIterable {
    case working = "Working"
    case broken = "Broken"
    case needsAuth = "Needs auth"
    case authExpired = "Auth expired"
    case needsRestart = "Needs restart"
    case disabled = "Disabled"
    case unknown = "Unknown"

    var sortRank: Int {
        switch self {
        case .broken: return 0
        case .needsAuth: return 1
        case .authExpired: return 2
        case .needsRestart: return 3
        case .unknown: return 4
        case .disabled: return 5
        case .working: return 6
        }
    }
}

struct MCPHealthReport: Identifiable, Hashable {
    var id: String { "\(toolID)/\(serverName)/\(status.rawValue)" }
    let toolID: String
    let serverName: String
    let status: MCPHealthStatus
    let summary: String
    let fixHint: String?
}

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
    ("antigravity",    "Antigravity",    "Ag"),
    ("roo",            "Roo",            "Ro"),
    ("opencode",       "opencode",       "Oc"),
    ("cline",          "Cline",          "Cl"),
    ("pi",             "Pi",             "Pi"),
    ("command-code",   "Command Code",   "Cm"),
    ("grok",           "Grok CLI",       "Gk"),
]

/// Tools shown on the main MCP page. Secondary tools stay readable in code
/// but stay off this list unless the same reader already covers them.
let PRIMARY_TOOL_IDS: Set<String> = [
    "claude-desktop",
    "claude-code",
    "codex",
    "cursor",
    "vscode",
    "opencode",
    "zed",
    "antigravity",
    "pi",
    "command-code",
    "grok",
]

/// Tool IDs hidden from UI but still read/written normally.
let HIDDEN_TOOL_IDS: Set<String> = Set(ALL_TOOL_META.map(\.id)).subtracting(PRIMARY_TOOL_IDS)
