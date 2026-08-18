import Foundation

struct ProviderFeatureStatus: Identifiable {
    var id: String { name }
    let name: String
    let available: Bool
    let count: Int
    let detail: String
}

struct ProviderAsset: Identifiable, Hashable {
    enum Kind: String {
        case skill
        case mcp
        case instruction
        case agent
        case hook
        case plugin
    }

    var id: String { "\(kind.rawValue)|\(scope)|\(path)|\(name)" }
    let kind: Kind
    let name: String
    let scope: String
    let path: String
    let enabled: Bool
}

struct ProviderSnapshot: Identifiable {
    let id: String
    let name: String
    let detected: Bool
    let globalHome: String
    let projectRoot: String?
    let features: [ProviderFeatureStatus]
    let assets: [ProviderAsset]
    let globalPaths: [String]
    let projectPaths: [String]
}

enum ProviderCatalog {
    struct Spec {
        let id: String
        let name: String
        let commands: [String]
        let detectPaths: [String]
        let globalHome: String
        let globalSkillDirs: [String]
        let projectSkillDirs: [String]
        let instructionFiles: [String]
        let extraProjectDirs: [String]
    }

    static func specs(home: String = NSHomeDirectory()) -> [Spec] {
        [
            Spec(
                id: "claude-code",
                name: "Claude Code",
                commands: ["claude"],
                detectPaths: ["\(home)/.claude", "\(home)/.claude.json"],
                globalHome: "\(home)/.claude",
                globalSkillDirs: ["\(home)/.claude/skills"],
                projectSkillDirs: [".claude/skills"],
                instructionFiles: ["CLAUDE.md", ".claude/CLAUDE.md", "CLAUDE.local.md"],
                extraProjectDirs: [".claude", ".mcp.json"]
            ),
            Spec(
                id: "claude-desktop",
                name: "Claude Desktop",
                commands: [],
                detectPaths: ["\(home)/Library/Application Support/Claude"],
                globalHome: "\(home)/Library/Application Support/Claude",
                globalSkillDirs: [],
                projectSkillDirs: [],
                instructionFiles: [],
                extraProjectDirs: []
            ),
            Spec(
                id: "codex",
                name: "Codex",
                commands: ["codex"],
                detectPaths: [ProjectHubPaths.codexHome(home: home)],
                globalHome: ProjectHubPaths.codexHome(home: home),
                globalSkillDirs: ["\(home)/.agents/skills", "\(ProjectHubPaths.codexHome(home: home))/skills"],
                projectSkillDirs: [".agents/skills"],
                instructionFiles: ["AGENTS.md", "AGENTS.override.md"],
                extraProjectDirs: [".codex", ".agents"]
            ),
            Spec(
                id: "cursor",
                name: "Cursor",
                commands: ["cursor"],
                detectPaths: ["\(home)/.cursor", "/Applications/Cursor.app"],
                globalHome: "\(home)/.cursor",
                globalSkillDirs: ["\(home)/.cursor/skills", "\(home)/.cursor/skills-cursor", "\(home)/.agents/skills"],
                projectSkillDirs: [".cursor/skills", ".agents/skills"],
                instructionFiles: ["AGENTS.md"],
                extraProjectDirs: [".cursor"]
            ),
            Spec(
                id: "vscode",
                name: "VS Code",
                commands: ["code"],
                detectPaths: ["\(home)/Library/Application Support/Code", "/Applications/Visual Studio Code.app"],
                globalHome: "\(home)/Library/Application Support/Code/User",
                globalSkillDirs: ["\(home)/.copilot/skills", "\(home)/.agents/skills"],
                projectSkillDirs: [".github/skills", ".agents/skills"],
                instructionFiles: [".github/copilot-instructions.md", "AGENTS.md"],
                extraProjectDirs: [".vscode", ".github"]
            ),
            Spec(
                id: "antigravity",
                name: "Antigravity",
                commands: ["agy"],
                detectPaths: ["\(home)/.gemini/antigravity-cli", "\(home)/.gemini/config", "/Applications/Antigravity.app"],
                globalHome: "\(home)/.gemini",
                globalSkillDirs: ["\(home)/.gemini/antigravity-cli/skills", "\(home)/.gemini/config/skills"],
                projectSkillDirs: [".agents/skills", ".gemini/skills"],
                instructionFiles: ["AGENTS.md", "GEMINI.md"],
                extraProjectDirs: [".agents", ".gemini"]
            ),
            Spec(
                id: "opencode",
                name: "OpenCode",
                commands: ["opencode"],
                detectPaths: ["\(home)/.config/opencode", "/Applications/OpenCode.app"],
                globalHome: "\(home)/.config/opencode",
                globalSkillDirs: ["\(home)/.config/opencode/skills"],
                projectSkillDirs: [".opencode/skills", ".agents/skills"],
                instructionFiles: ["AGENTS.md"],
                extraProjectDirs: [".opencode", "opencode.json"]
            ),
            Spec(
                id: "zed",
                name: "Zed",
                commands: ["zed"],
                detectPaths: ["\(home)/.config/zed", "/Applications/Zed.app"],
                globalHome: "\(home)/.config/zed",
                globalSkillDirs: ["\(home)/.agents/skills"],
                projectSkillDirs: [".agents/skills"],
                instructionFiles: ["AGENTS.md"],
                extraProjectDirs: [".zed"]
            ),
            Spec(
                id: "pi",
                name: "Pi",
                commands: ["pi"],
                detectPaths: ["\(home)/.pi/agent"],
                globalHome: "\(home)/.pi/agent",
                globalSkillDirs: ["\(home)/.pi/agent/skills", "\(home)/.agents/skills"],
                projectSkillDirs: [".pi/skills", ".agents/skills"],
                instructionFiles: ["AGENTS.md", "CLAUDE.md"],
                extraProjectDirs: [".pi"]
            ),
            Spec(
                id: "command-code",
                name: "Command Code",
                commands: ["command-code", "cmdc"],
                detectPaths: ["\(home)/.commandcode", "/Applications/Command Code.app"],
                globalHome: "\(home)/.commandcode",
                globalSkillDirs: ["\(home)/.commandcode/skills"],
                projectSkillDirs: [".commandcode/skills"],
                instructionFiles: ["AGENTS.md"],
                extraProjectDirs: [".commandcode"]
            ),
            Spec(
                id: "grok",
                name: "Grok CLI",
                commands: ["grok"],
                detectPaths: ["\(home)/.grok", "\(home)/.grok/config.toml"],
                globalHome: "\(home)/.grok",
                globalSkillDirs: ["\(home)/.grok/skills", "\(home)/.agents/skills"],
                projectSkillDirs: [".agents/skills", ".grok/skills"],
                instructionFiles: ["AGENTS.md"],
                extraProjectDirs: [".grok"]
            ),
        ]
    }

    static func snapshots(projectPath: String?, home: String = NSHomeDirectory()) -> [ProviderSnapshot] {
        specs(home: home).map { spec in
            snapshot(spec: spec, projectPath: projectPath, home: home)
        }
    }

    static func snapshot(spec: Spec, projectPath: String?, home: String = NSHomeDirectory()) -> ProviderSnapshot {
        let fm = FileManager.default
        let detected = spec.detectPaths.contains { fm.fileExists(atPath: $0) }
            || spec.commands.contains { commandExists($0) }

        var assets: [ProviderAsset] = []

        for dir in spec.globalSkillDirs {
            for skill in SkillReader.scanSkillDir(dir, source: .claudeGlobal) {
                assets.append(ProviderAsset(kind: .skill, name: skill.name, scope: "global", path: skill.path, enabled: true))
            }
        }
        if let root = projectPath {
            for relative in spec.projectSkillDirs {
                let dir = (root as NSString).appendingPathComponent(relative)
                for skill in SkillReader.scanSkillDir(dir, source: .claudeGlobal) {
                    assets.append(ProviderAsset(kind: .skill, name: skill.name, scope: "project", path: skill.path, enabled: true))
                }
            }
        }

        let userServers = ConfigWriter.readAllServerEntries(toolID: spec.id, scope: .user, projectRoot: nil)
        let projectServers = projectPath.map {
            ConfigWriter.readAllServerEntries(toolID: spec.id, scope: .project, projectRoot: $0)
        } ?? []
        if let specPath = ToolSpecs.spec(for: spec.id, scope: .user, projectRoot: nil)?.path {
            for server in userServers {
                assets.append(ProviderAsset(kind: .mcp, name: server.name, scope: "global", path: specPath, enabled: !server.isDisabled))
            }
        }
        if let root = projectPath,
           let specPath = ToolSpecs.spec(for: spec.id, scope: .project, projectRoot: root)?.path {
            for server in projectServers {
                assets.append(ProviderAsset(kind: .mcp, name: server.name, scope: "project", path: specPath, enabled: !server.isDisabled))
            }
        }

        let instructionHits = (projectPath.map { root in
            spec.instructionFiles.compactMap { relative -> String? in
                let path = (root as NSString).appendingPathComponent(relative)
                guard fileExists(path) else { return nil }
                assets.append(ProviderAsset(kind: .instruction, name: relative, scope: "project", path: path, enabled: true))
                return relative
            }
        }) ?? []

        for dir in agentDirectories(spec: spec, home: home, projectPath: projectPath) {
            assets.append(contentsOf: markdownAssets(in: dir.path, kind: .agent, scope: dir.scope))
        }
        for dir in pluginDirectories(spec: spec, home: home, projectPath: projectPath) {
            assets.append(contentsOf: folderAssets(in: dir.path, kind: .plugin, scope: dir.scope))
        }
        if let projectPath {
            for hook in HooksReader.hooks(for: projectPath) where hook.tool.lowercased().contains(spec.name.split(separator: " ").first.map(String.init)?.lowercased() ?? spec.id) {
                assets.append(ProviderAsset(kind: .hook, name: hook.event, scope: hook.scope, path: projectPath, enabled: true))
            }
        }

        let globalSkills = assets.filter { $0.kind == .skill && $0.scope == "global" }.count
        let projectSkills = assets.filter { $0.kind == .skill && $0.scope == "project" }.count
        let mcpUser = userServers.count
        let mcpProject = projectServers.count

        var features: [ProviderFeatureStatus] = [
            .init(
                name: "Skills",
                available: globalSkills + projectSkills > 0 || !spec.globalSkillDirs.isEmpty || !spec.projectSkillDirs.isEmpty,
                count: globalSkills + projectSkills,
                detail: "\(globalSkills) global · \(projectSkills) project"
            ),
            .init(
                name: "MCP",
                available: ToolSpecs.spec(for: spec.id) != nil,
                count: mcpUser + mcpProject,
                detail: "\(mcpUser) global · \(mcpProject) project"
            ),
            .init(
                name: "Instructions",
                available: !spec.instructionFiles.isEmpty,
                count: instructionHits.count,
                detail: instructionHits.isEmpty ? spec.instructionFiles.joined(separator: ", ") : instructionHits.joined(separator: ", ")
            ),
            .init(
                name: "Agents",
                available: true,
                count: assets.filter { $0.kind == .agent }.count,
                detail: "Markdown agents"
            ),
            .init(
                name: "Hooks",
                available: true,
                count: assets.filter { $0.kind == .hook }.count,
                detail: "Lifecycle hooks"
            ),
            .init(
                name: "Plugins",
                available: true,
                count: assets.filter { $0.kind == .plugin }.count,
                detail: "Installed bundles"
            ),
        ]

        if spec.id == "pi" {
            let extensions = extensionCount(in: "\(home)/.pi/agent/extensions")
            let hasAdapter = fm.fileExists(atPath: "\(home)/.pi/agent/mcp.json")
                || fm.fileExists(atPath: "\(home)/.pi/agent/npm/node_modules/pi-mcp-adapter")
            features.append(.init(
                name: "Extensions",
                available: true,
                count: extensions,
                detail: hasAdapter ? "MCP adapter present" : "MCP only if an adapter is installed"
            ))
        }

        let projectPaths = (projectPath.map { root in
            (spec.projectSkillDirs + spec.instructionFiles + spec.extraProjectDirs)
                .map { ($0.hasPrefix(".") || $0.contains("/")) ? (root as NSString).appendingPathComponent($0) : (root as NSString).appendingPathComponent($0) }
                .filter { fileExists($0) }
        }) ?? []

        return ProviderSnapshot(
            id: spec.id,
            name: spec.name,
            detected: detected,
            globalHome: spec.globalHome,
            projectRoot: projectPath,
            features: features,
            assets: assets,
            globalPaths: spec.detectPaths.filter { fileExists($0) },
            projectPaths: projectPaths
        )
    }

    private static func agentDirectories(spec: Spec, home: String, projectPath: String?) -> [(path: String, scope: String)] {
        var dirs: [(path: String, scope: String)] = [
            (path: "\(home)/.claude/agents", scope: "global"),
            (path: "\(home)/.cursor/agents", scope: "global"),
            (path: "\(home)/.config/opencode/agents", scope: "global"),
            (path: "\(home)/.commandcode/agents", scope: "global"),
            (path: "\(home)/.pi/agent/extensions", scope: "global"),
        ]
        if let projectPath {
            dirs += [
                (path: "\(projectPath)/.claude/agents", scope: "project"),
                (path: "\(projectPath)/.cursor/agents", scope: "project"),
                (path: "\(projectPath)/.opencode/agents", scope: "project"),
                (path: "\(projectPath)/.commandcode/agents", scope: "project"),
            ]
        }
        return dirs.filter { $0.path.lowercased().contains(agentToken(for: spec.id)) }
    }

    private static func pluginDirectories(spec: Spec, home: String, projectPath: String?) -> [(path: String, scope: String)] {
        var dirs: [(path: String, scope: String)] = [
            (path: "\(home)/.claude/plugins", scope: "global"),
            (path: "\(ProjectHubPaths.codexHome(home: home))/plugins/cache", scope: "global"),
            (path: "\(home)/.config/opencode/plugins", scope: "global"),
            (path: "\(home)/.pi/agent/extensions", scope: "global"),
            (path: "\(home)/.grok/installed-plugins", scope: "global"),
        ]
        if let projectPath {
            dirs += [
                (path: "\(projectPath)/.opencode/plugins", scope: "project"),
                (path: "\(projectPath)/.pi/extensions", scope: "project"),
            ]
        }
        return dirs.filter { $0.path.lowercased().contains(pluginToken(for: spec.id)) }
    }

    private static func agentToken(for id: String) -> String {
        switch id {
        case "claude-code": return ".claude/agents"
        case "cursor": return ".cursor/agents"
        case "opencode": return "opencode/agents"
        case "command-code": return "commandcode/agents"
        case "pi": return "extensions"
        default: return "///none///"
        }
    }

    private static func pluginToken(for id: String) -> String {
        switch id {
        case "claude-code": return ".claude/plugins"
        case "codex": return "plugins/cache"
        case "opencode": return "opencode/plugins"
        case "pi": return "/.pi/"
        case "grok": return "installed-plugins"
        default: return "///none///"
        }
    }

    private static func markdownAssets(in directory: String, kind: ProviderAsset.Kind, scope: String) -> [ProviderAsset] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return [] }
        return names.filter { $0.hasSuffix(".md") }.sorted().map { name in
            ProviderAsset(
                kind: kind,
                name: (name as NSString).deletingPathExtension,
                scope: scope,
                path: (directory as NSString).appendingPathComponent(name),
                enabled: true
            )
        }
    }

    private static func folderAssets(in directory: String, kind: ProviderAsset.Kind, scope: String) -> [ProviderAsset] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return [] }
        return names.filter { !$0.hasPrefix(".") }.prefix(30).map { name in
            ProviderAsset(
                kind: kind,
                name: name,
                scope: scope,
                path: (directory as NSString).appendingPathComponent(name),
                enabled: true
            )
        }
    }

    private static func extensionCount(in directory: String) -> Int {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return 0 }
        return entries.filter { !$0.hasPrefix(".") }.count
    }

    private static func fileExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    private static func commandExists(_ name: String) -> Bool {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        return path.split(separator: ":").contains { dir in
            FileManager.default.isExecutableFile(atPath: "\(dir)/\(name)")
        }
    }
}
