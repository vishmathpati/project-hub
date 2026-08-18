import Foundation
import Combine
import Dispatch

// MARK: - Compatibility matrix

enum CompatibilityToolID: String, CaseIterable, Identifiable, Codable {
    case claudeCode
    case claudeDesktop
    case codexCLI
    case codexDesktop

    var id: String { rawValue }

    var label: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .claudeDesktop: return "Claude Desktop"
        case .codexCLI: return "Codex CLI"
        case .codexDesktop: return "Codex Desktop"
        }
    }
}

enum CompatibilityScope: String, Codable {
    case global
    case project
    case localProjectUser
    case desktopApp
    case account
    case runtime
}

enum CompatibilitySurfaceKind: String, Codable {
    case mcp
    case skills
    case settings
    case auth
    case context
}

enum CompatibilityConfigFormat: String, Codable {
    case json
    case jsonc
    case toml
    case plist
    case markdown
    case directory
    case keychain
    case accountRuntime
    case unknown
}

enum CompatibilityWriteMethod: String, Codable {
    case file
    case cli
    case appUI
    case runtimeOnly
    case unsupported
}

struct CompatibilityMatrixEntry: Identifiable, Codable {
    let id: String
    let toolID: CompatibilityToolID
    let kind: CompatibilitySurfaceKind
    let scope: CompatibilityScope
    let label: String
    let path: String?
    let format: CompatibilityConfigFormat
    let fileControlled: Bool
    let canWriteSafely: Bool
    let writeMethod: CompatibilityWriteMethod
    let requiresRestartAfterWrite: Bool
    let supportsDisable: Bool
    let supportsOAuth: Bool
    let supportsEnvExpansion: Bool
    let precedence: Int
    let note: String
}

enum CompatibilityHealthState: String, Codable {
    case working
    case broken
    case needsAuth
    case authExpired
    case needsRestart
    case disabled
    case conflict
    case unknown

    var label: String {
        switch self {
        case .working: return "Working"
        case .broken: return "Broken"
        case .needsAuth: return "Needs auth"
        case .authExpired: return "Auth expired"
        case .needsRestart: return "Needs restart"
        case .disabled: return "Disabled"
        case .conflict: return "Conflict"
        case .unknown: return "Unknown"
        }
    }
}

enum CompatibilityIssueSeverity: Int, Codable, Comparable {
    case info = 0
    case warning = 1
    case error = 2
    case critical = 3

    static func < (lhs: CompatibilityIssueSeverity, rhs: CompatibilityIssueSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum CompatibilityIssueCode: String, Codable {
    case configMissing = "config.missing"
    case configInvalidJSON = "config.invalid-json"
    case configInvalidTOML = "config.invalid-toml"
    case configUnsupportedShape = "config.unsupported-shape"
    case serverDisabled = "server.disabled"
    case serverDuplicateName = "server.duplicate-name"
    case serverConflictDifferentConfig = "server.conflict-different-config"
    case serverShadowedByProjectLayer = "server.shadowed-by-project-layer"
    case serverMissingLaunchTarget = "server.missing-command-or-url"
    case serverCommandMissing = "server.command-missing"
    case serverPathMissing = "server.path-missing"
    case serverEnvMissing = "server.env-missing"
    case serverAuthMissing = "server.auth-missing"
    case serverAuthExpired = "server.auth-expired"
    case serverOAuthNeeded = "server.oauth-needed"
    case serverUnsupportedTransport = "server.transport-unsupported"
    case serverReservedName = "server.reserved-name"
    case serverNeedsRestart = "server.needs-restart"
    case serverHealthUnknown = "server.health-unknown"
    case serverAuthRuntimeManaged = "server.auth-runtime-managed"
    case serverRuntimeManaged = "server.runtime-managed"
    case skillInvalidFrontmatter = "skill.invalid-frontmatter"
    case skillMissingSkillMD = "skill.missing-skill-md"
    case skillDisabled = "skill.disabled"
    case skillDuplicateName = "skill.duplicate-name"
    case skillVersionConflict = "skill.version-conflict"
    case skillMissingDependency = "skill.missing-dependency"
    case skillVisibilityLimited = "skill.visibility-limited"
    case projectRootAmbiguous = "project.root-ambiguous"
    case projectTrustRequired = "project.trust-required"
    case projectSettingsShadowed = "project.settings-shadowed"
    case projectSettingsIgnored = "project.settings-ignored"
    case projectMCPNotUsedByPrimaryTools = "project.mcp-not-used-by-primary-tools"
    case settingsDeprecatedValue = "settings.deprecated-value"
    case settingsManagedRequirement = "settings.managed-requirement"
    case settingsSessionReloadRequired = "settings.session-reload-required"
    case projectLocalSettingsTracked = "project.local-settings-tracked"
    case settingsProfileScopedPolicy = "settings.profile-scoped-policy"
    case authCredentialStore = "auth.credential-store"
    case contextEmpty = "context.empty"
    case contextDiverged = "context.diverged"
    case contextTooLarge = "context.too-large"
    case contextExternalImportApprovalUnknown = "context.external-import-approval-unknown"
    case writeUnsafeTarget = "write.unsafe-target"
}

struct CompatibilityIssue: Identifiable, Codable {
    let id: UUID
    let code: CompatibilityIssueCode
    let severity: CompatibilityIssueSeverity
    let toolID: CompatibilityToolID?
    let surfaceID: String?
    let title: String
    let detail: String
    let path: String?
    let subjectPath: String?
    let fixHint: String?
    let metadata: [String: String]

    init(
        id: UUID,
        code: CompatibilityIssueCode,
        severity: CompatibilityIssueSeverity,
        toolID: CompatibilityToolID?,
        surfaceID: String?,
        title: String,
        detail: String,
        path: String?,
        subjectPath: String?,
        fixHint: String?,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.code = code
        self.severity = severity
        self.toolID = toolID
        self.surfaceID = surfaceID
        self.title = title
        self.detail = detail
        self.path = path
        self.subjectPath = subjectPath
        self.fixHint = fixHint
        self.metadata = metadata
    }
}

struct CompatibilityServerObservation: Identifiable, Codable {
    let id: String
    let toolID: CompatibilityToolID
    let surfaceID: String
    let surfaceLabel: String
    let name: String
    let transport: String
    let detail: String
    let path: String
    let scope: CompatibilityScope
    let disabled: Bool
    let startupTimeoutSeconds: TimeInterval?
    let toolTimeoutSeconds: TimeInterval?
    let fingerprint: String
    var health: CompatibilityHealthState
    var issueCodes: [CompatibilityIssueCode]
}

struct CompatibilitySkillObservation: Identifiable, Codable {
    let id: String
    let toolID: CompatibilityToolID
    let surfaceID: String
    let name: String
    let path: String
    let scope: CompatibilityScope
    let description: String
    let version: String?
    let parseOK: Bool
    let enabledOverride: Bool?
    let availableIn: [CompatibilityToolID]
    let displayName: String?
    let shortDescription: String?
    let iconSmall: String?
    let iconLarge: String?
    let brandColor: String?
    let defaultPrompt: String?
    let allowImplicitInvocation: Bool?
    let mcpDependencies: [String]
    let claudeWhenToUse: String?
    let claudeAllowedTools: [String]
    let claudeDisableModelInvocation: Bool?
    let claudeUserInvocable: Bool?
    let claudeArgumentHint: String?
    let claudeArguments: [String]
    let claudeModel: String?
    let claudeEffort: String?
    let claudeContext: String?
    let claudeAgent: String?
    let claudePaths: [String]
    let claudeShell: String?
    let claudeHooks: String?
    let claudeOverrideState: String?
    let claudeOverrideSource: String?
    let claudeShellExecutionDisabled: Bool
    let claudeSkillPermissionRules: [String]
}

enum CompatibilitySkillSupportState: String, Codable, CaseIterable {
    case supported = "Supported"
    case shared = "Shared"
    case appManaged = "App/account managed"
    case unsupported = "Unsupported"
    case unknown = "Unknown"
}

struct CompatibilitySkillSupportObservation: Identifiable, Codable {
    let id: String
    let toolID: CompatibilityToolID
    let state: CompatibilitySkillSupportState
    let scope: CompatibilityScope
    let roots: [String]
    let summary: String
    let detail: String
    let requiresRestartAfterWrite: Bool
}

enum CompatibilityPluginInstallMethod: String, Codable {
    case codexCache
    case codexConfig
    case codexMarketplaceConfig
    case codexMarketplaceFile
    case claudeInstalledInventory
    case claudeSettings
    case claudeKnownMarketplace
    case claudeSkillsDirectory
    case claudeMarketplaceDirectory

    var label: String {
        switch self {
        case .codexCache:
            return "Codex cache"
        case .codexConfig:
            return "Codex config"
        case .codexMarketplaceConfig:
            return "Codex marketplace"
        case .codexMarketplaceFile:
            return "Marketplace file"
        case .claudeInstalledInventory:
            return "Claude inventory"
        case .claudeSettings:
            return "Claude settings"
        case .claudeKnownMarketplace:
            return "Known marketplace"
        case .claudeSkillsDirectory:
            return "Skills directory"
        case .claudeMarketplaceDirectory:
            return "Marketplace directory"
        }
    }
}

struct CompatibilityPluginObservation: Identifiable, Codable {
    let id: String
    let toolID: CompatibilityToolID
    let pluginID: String
    let name: String
    let marketplace: String?
    let version: String?
    let scope: CompatibilityScope
    let installMethod: CompatibilityPluginInstallMethod
    let installPath: String?
    let sourcePath: String?
    let enabled: Bool?
    let components: [String]
    let summary: String
    let requiresRestartAfterWrite: Bool
}

struct CompatibilitySettingsObservation: Identifiable, Codable {
    let id: String
    let toolID: CompatibilityToolID
    let surfaceID: String
    let label: String
    let path: String
    let scope: CompatibilityScope
    let keys: [String]
    let summary: String
    let fileControlled: Bool
    let canWriteSafely: Bool
    let writeMethod: CompatibilityWriteMethod
    let requiresRestartAfterWrite: Bool
    let precedence: Int
}

struct CompatibilityScanResult: Codable {
    let projectRoot: String?
    let codexProfileSelection: CodexProfileSelection?
    let generatedAt: Date
    let matrix: [CompatibilityMatrixEntry]
    let servers: [CompatibilityServerObservation]
    let skills: [CompatibilitySkillObservation]
    let skillSupport: [CompatibilitySkillSupportObservation]
    let plugins: [CompatibilityPluginObservation]
    let settings: [CompatibilitySettingsObservation]
    let issues: [CompatibilityIssue]

    var summary: [CompatibilityHealthState: Int] {
        Dictionary(grouping: servers, by: \.health).mapValues(\.count)
    }

    var detectedRoot: String {
        projectRoot ?? NSHomeDirectory()
    }

    func count(_ state: CompatibilityHealthState) -> Int {
        summary[state, default: 0]
    }
}

struct CompatibilitySkillInventory {
    let projectRoot: String?
    let matrix: [CompatibilityMatrixEntry]
    let skills: [CompatibilitySkillObservation]
}

struct CompatibilityMCPInventoryRow {
    let appToolID: String
    let toolID: CompatibilityToolID
    let surfaceID: String
    let surfaceLabel: String
    let scope: CompatibilityScope
    let path: String?
    let canWriteSafely: Bool
    let writeMethod: CompatibilityWriteMethod
    let server: ServerEntry
}

struct CodexProfileSelection: Equatable, Codable {
    enum Source: String, Codable {
        case defaultConfig
        case cliRuntimeOverride
    }

    let name: String
    let source: Source

    static func cliRuntimeOverride(_ name: String) -> CodexProfileSelection? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return .init(name: trimmed, source: .cliRuntimeOverride)
    }
}

extension CompatibilityIssue {
    var state: CompatibilityHealthState {
        switch code {
        case .serverDisabled:
            return .disabled
        case .serverAuthExpired:
            return .authExpired
        case .serverAuthMissing, .serverOAuthNeeded, .serverEnvMissing:
            return .needsAuth
        case .serverNeedsRestart, .settingsSessionReloadRequired:
            return .needsRestart
        case .serverConflictDifferentConfig, .serverDuplicateName, .serverShadowedByProjectLayer,
             .skillDuplicateName,
             .skillVersionConflict, .projectSettingsShadowed, .projectLocalSettingsTracked,
             .contextDiverged:
            return .conflict
        case .configMissing, .serverHealthUnknown, .serverAuthRuntimeManaged, .serverRuntimeManaged,
             .settingsProfileScopedPolicy, .authCredentialStore, .settingsManagedRequirement,
             .projectTrustRequired, .projectMCPNotUsedByPrimaryTools, .contextEmpty, .contextTooLarge,
             .contextExternalImportApprovalUnknown, .skillVisibilityLimited:
            return .unknown
        case .configInvalidJSON, .configInvalidTOML, .configUnsupportedShape,
             .serverMissingLaunchTarget, .serverCommandMissing, .serverPathMissing,
             .serverUnsupportedTransport, .serverReservedName, .skillInvalidFrontmatter, .skillMissingSkillMD,
             .skillMissingDependency, .projectRootAmbiguous, .projectSettingsIgnored,
             .settingsDeprecatedValue, .writeUnsafeTarget:
            return .broken
        case .skillDisabled:
            return .disabled
        }
    }

    var toolName: String {
        toolID?.label ?? "Project Hub"
    }

    var scope: String {
        surfaceID ?? "workspace"
    }

    var recommendation: String {
        fixHint ?? "Review the config, then re-run Scan to verify."
    }
}

extension CompatibilityMatrixEntry {
    var toolName: String { toolID.label }
    var displayPath: String { path.map(CompatibilityScanner.tilde) ?? "Runtime/account managed" }
    var reloadNote: String { note }
    var supportsMCP: Bool { kind == .mcp }
    var supportsSkills: Bool { kind == .skills }
    var supportsProjectSettings: Bool { kind == .settings || kind == .context }
}

// MARK: - Scanner

enum CompatibilityScanner {
    static func scan(projectPath: String?, codexProfileSelection: CodexProfileSelection? = nil) -> CompatibilityScanResult {
        scan(projectRoot: projectPath, codexProfileSelection: codexProfileSelection)
    }

    static func mcpInventory(
        projectRoot: String?,
        codexProfileSelection: CodexProfileSelection? = nil
    ) -> [CompatibilityMCPInventoryRow] {
        let selectedPath = projectRoot.map(expandedPath)
        let normalizedRoot = projectRoot.map(Project.canonicalize)
        let matrix = compatibilityMatrix(
            projectRoot: normalizedRoot,
            selectedPath: selectedPath,
            codexProfileSelection: codexProfileSelection
        )

        return matrix
            .filter { $0.kind == .mcp }
            .flatMap { surface -> [CompatibilityMCPInventoryRow] in
                let read = readServers(from: surface, codexProfileSelection: codexProfileSelection)
                return read.servers.compactMap { server in
                    mcpInventoryRow(for: server, surface: surface, matrix: matrix)
                }
            }
            .sorted { lhs, rhs in
                if lhs.appToolID != rhs.appToolID { return lhs.appToolID < rhs.appToolID }
                if lhs.scope.rawValue != rhs.scope.rawValue { return lhs.scope.rawValue < rhs.scope.rawValue }
                if lhs.surfaceID != rhs.surfaceID { return lhs.surfaceID < rhs.surfaceID }
                return lhs.server.name.localizedCaseInsensitiveCompare(rhs.server.name) == .orderedAscending
            }
    }

    static func codexConfiguredProfileNames() -> [String] {
        let codexHome = ProjectHubPaths.codexHome(home: NSHomeDirectory())
        let path = (codexHome as NSString).appendingPathComponent("config.toml")
        var names = Set<String>()
        names.formUnion(codexProfileConfigFiles(codexHome: codexHome).map(\.name))
        if let raw = try? String(contentsOfFile: path, encoding: .utf8) {
            let document = parseSettingsTOMLDocument(raw)
            if let defaultProfile = stringSetting("profile", in: document) {
                names.insert(defaultProfile)
            }
            for section in document.sectionKeys.keys {
                let segments = tomlSectionSegments(section)
                if segments.count >= 2, segments[0] == "profiles" {
                    names.insert(segments[1])
                }
            }
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func tilde(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }

    private static func expandedPath(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    private static func uniqueStringsPreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            unique.append(value)
        }
        return unique
    }

    private static func codexProfileConfigFiles(codexHome: String) -> [(name: String, path: String)] {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: codexHome) else { return [] }
        let suffix = ".config.toml"
        return entries.compactMap { entry -> (name: String, path: String)? in
            guard entry.hasSuffix(suffix), entry != "config.toml" else { return nil }
            let name = String(entry.dropLast(suffix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return (name, (codexHome as NSString).appendingPathComponent(entry))
        }
        .sorted { lhs, rhs in lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending }
    }

    private static func codexProfileConfigPath(codexHome: String, profileName: String) -> String? {
        let trimmed = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("/"),
              !trimmed.contains(":") else { return nil }
        let path = (codexHome as NSString).appendingPathComponent("\(trimmed).config.toml")
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    static func scan(projectRoot: String?, codexProfileSelection: CodexProfileSelection? = nil) -> CompatibilityScanResult {
        let selectedPath = projectRoot.map(expandedPath)
        let normalizedRoot = projectRoot.map(Project.canonicalize)
        let matrix = compatibilityMatrix(
            projectRoot: normalizedRoot,
            selectedPath: selectedPath,
            codexProfileSelection: codexProfileSelection
        )
        var issues: [CompatibilityIssue] = []
        var servers: [CompatibilityServerObservation] = []
        var settings: [CompatibilitySettingsObservation] = []

        if let requestedRoot = selectedPath,
           let normalizedRoot,
           requestedRoot != normalizedRoot {
            issues.append(CompatibilityIssue(
                id: UUID(),
                code: .projectRootAmbiguous,
                severity: .info,
                toolID: nil,
                surfaceID: nil,
                title: "Project root normalized",
                detail: "The selected folder resolves to \(tilde(normalizedRoot)) for Claude/Codex project-scoped configuration.",
                path: normalizedRoot,
                subjectPath: normalizedRoot,
                fixHint: "Use this resolved root when writing project MCP, skills, and settings so every supported tool sees the same workspace."
            ))
        }

        for surface in matrix where surface.kind == .mcp {
            let read = readServers(from: surface, codexProfileSelection: codexProfileSelection)
            issues.append(contentsOf: read.issues)
            servers.append(contentsOf: read.servers)
        }

        for surface in matrix where surface.kind == .settings || surface.kind == .context {
            let read = readSettings(
                from: surface,
                projectRoot: normalizedRoot,
                codexProfileSelection: codexProfileSelection
            )
            issues.append(contentsOf: read.issues)
            settings.append(contentsOf: read.settings)
        }

        for surface in matrix where surface.kind == .auth {
            issues.append(contentsOf: readAuth(from: surface))
        }

        let claudeMCPPolicy = claudeCodeMCPPolicy(from: matrix)
        for index in servers.indices {
            let serverIssues = inspectServer(
                servers[index],
                surface: matrix.first { $0.id == servers[index].surfaceID },
                matrix: matrix,
                claudeMCPPolicy: claudeMCPPolicy,
                codexProfileSelection: codexProfileSelection
            )
            servers[index].issueCodes.append(contentsOf: serverIssues.map(\.code))
            servers[index].health = healthState(for: servers[index], issueCodes: servers[index].issueCodes)
            issues.append(contentsOf: serverIssues)
        }

        let conflictIssues = detectConflicts(in: &servers)
        issues.append(contentsOf: conflictIssues)
        issues.append(contentsOf: detectCodexInstructionShadowing(in: matrix))
        issues.append(contentsOf: detectAdjacentProjectMCPConfigs(projectRoot: normalizedRoot))

        let skillRead = readSkills(from: matrix, servers: servers)
        issues.append(contentsOf: skillRead.issues)
        let skillSupport = skillSupportObservations(from: matrix)
        let pluginRead = readPlugins(
            from: matrix,
            projectRoot: normalizedRoot,
            codexProfileSelection: codexProfileSelection
        )
        issues.append(contentsOf: pluginRead.issues)

        return CompatibilityScanResult(
            projectRoot: normalizedRoot,
            codexProfileSelection: codexProfileSelection,
            generatedAt: Date(),
            matrix: matrix,
            servers: servers.sorted { lhs, rhs in
                if lhs.toolID.rawValue != rhs.toolID.rawValue { return lhs.toolID.rawValue < rhs.toolID.rawValue }
                if lhs.scope.rawValue != rhs.scope.rawValue { return lhs.scope.rawValue < rhs.scope.rawValue }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            },
            skills: skillRead.skills,
            skillSupport: skillSupport,
            plugins: pluginRead.plugins,
            settings: settings.sorted { lhs, rhs in
                if lhs.toolID.rawValue != rhs.toolID.rawValue { return lhs.toolID.rawValue < rhs.toolID.rawValue }
                if lhs.precedence != rhs.precedence { return lhs.precedence < rhs.precedence }
                return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            },
            issues: issues.sorted {
                if $0.severity != $1.severity { return $0.severity > $1.severity }
                return $0.code.rawValue < $1.code.rawValue
            }
        )
    }

    static func deduplicatedSharedCodexServers(
        _ servers: [CompatibilityServerObservation]
    ) -> [CompatibilityServerObservation] {
        var seen = Set<String>()
        var output: [CompatibilityServerObservation] = []
        for server in servers {
            guard server.toolID == .codexCLI || server.toolID == .codexDesktop else {
                output.append(server)
                continue
            }
            let key = [
                Project.canonicalize(server.path),
                server.scope.rawValue,
                server.name,
                server.fingerprint
            ].joined(separator: "\u{1f}")
            guard seen.insert(key).inserted else { continue }
            output.append(server)
        }
        return output
    }

    private static func detectAdjacentProjectMCPConfigs(projectRoot: String?) -> [CompatibilityIssue] {
        guard let projectRoot else { return [] }

        struct AdjacentProjectMCPConfig {
            let id: String
            let label: String
            let relativePath: String
            let serverKeys: [String]
        }

        let candidates = [
            AdjacentProjectMCPConfig(
                id: "cursor",
                label: "Cursor",
                relativePath: ".cursor/mcp.json",
                serverKeys: ["mcpServers"]
            ),
            AdjacentProjectMCPConfig(
                id: "vscode",
                label: "VS Code",
                relativePath: ".vscode/mcp.json",
                serverKeys: ["servers"]
            ),
            AdjacentProjectMCPConfig(
                id: "roo",
                label: "Roo Code",
                relativePath: ".roo/mcp.json",
                serverKeys: ["mcpServers"]
            )
        ]

        return candidates.compactMap { candidate in
            let path = (projectRoot as NSString).appendingPathComponent(candidate.relativePath)
            guard FileManager.default.fileExists(atPath: path) else { return nil }

            let names = adjacentProjectMCPServerNames(path: path, serverKeys: candidate.serverKeys)
            let detail: String
            let subjectPath: String?
            if names.isEmpty {
                detail = "\(candidate.label) defines \(candidate.relativePath), but Project Hub could not read any MCP servers from it. This project MCP file is loaded by \(candidate.label), not by Claude Code or Codex."
                subjectPath = nil
            } else {
                let display = names.map { "\"\($0)\"" }.joined(separator: ", ")
                detail = "\(candidate.label) defines \(display) in \(candidate.relativePath). That project MCP file is loaded by \(candidate.label), not by Claude Code or Codex."
                subjectPath = names.joined(separator: ",")
            }

            return CompatibilityIssue(
                id: UUID(),
                code: .projectMCPNotUsedByPrimaryTools,
                severity: .info,
                toolID: nil,
                surfaceID: "adjacent-project-mcp-\(candidate.id)",
                title: "\(candidate.label) project MCP is editor-specific",
                detail: detail,
                path: path,
                subjectPath: subjectPath,
                fixHint: "Copy the server into project .mcp.json for Claude Code or .codex/config.toml for Codex if it should be available in the primary tools."
            )
        }
    }

    private static func adjacentProjectMCPServerNames(path: String, serverKeys: [String]) -> [String] {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        let stripped = ConfigWriter.stripJsonComments(raw)
        guard let data = stripped.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        for key in serverKeys {
            guard let value = root[key] as? [String: Any],
                  let servers = serverConfigMap(value) else { continue }
            return servers.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
        return []
    }

    static func compatibilityMatrix(projectRoot: String?) -> [CompatibilityMatrixEntry] {
        compatibilityMatrix(projectRoot: projectRoot, selectedPath: projectRoot, codexProfileSelection: nil)
    }

    private static func compatibilityMatrix(
        projectRoot: String?,
        selectedPath: String?,
        codexProfileSelection: CodexProfileSelection?
    ) -> [CompatibilityMatrixEntry] {
        let home = NSHomeDirectory()
        let userName = NSUserName()
        let claudeHome = claudeHomeDirectory(home: home)
        let claudeJSONPath = claudeCodeJSONPath(home: home)
        let claudeDesktopSupport = claudeDesktopApplicationSupportDirectory(home: home)
        let codexHome = ProjectHubPaths.codexHome(home: home)
        let codexRequirementsPath = ProcessInfo.processInfo.environment["PROJECTHUB_CODEX_REQUIREMENTS_PATH"] ?? "/etc/codex/requirements.toml"
        let claudeManagedDirs = claudeCodeManagedDirectories()
        let managedPreferencesRoot = managedPreferencesDirectory()
        let serverManagedSettingsPath = claudeCodeServerManagedSettingsPath(claudeHome: claudeHome)
        let claudeLocalMCPID = projectRoot.map { "claude-code-local-mcp|\($0)" } ?? "claude-code-local-mcp"
        var surfaces: [CompatibilityMatrixEntry] = [
            .init(
                id: claudeLocalMCPID,
                toolID: .claudeCode,
                kind: .mcp,
                scope: .localProjectUser,
                label: "Claude Code local MCP",
                path: claudeJSONPath,
                format: .jsonc,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .cli,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: true,
                supportsEnvExpansion: true,
                precedence: 30,
                note: "Private per-project Claude Code MCP state; prefer the Claude CLI for writes."
            ),
            .init(
                id: "claude-code-user-mcp",
                toolID: .claudeCode,
                kind: .mcp,
                scope: .global,
                label: "Claude Code user MCP",
                path: claudeJSONPath,
                format: .jsonc,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .cli,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: true,
                supportsEnvExpansion: true,
                precedence: 10,
                note: "User-scope Claude Code MCP servers are available across projects and should be managed with the Claude CLI."
            ),
            .init(
                id: "claude-code-user-global-config",
                toolID: .claudeCode,
                kind: .settings,
                scope: .global,
                label: "Claude Code user global config",
                path: claudeJSONPath,
                format: .jsonc,
                fileControlled: false,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 11,
                note: "Claude Code stores OAuth/session data, user/local MCP state, per-project runtime state, and some global config in this private file. Project Hub inspects it only."
            ),
            .init(
                id: "claude-code-auth",
                toolID: .claudeCode,
                kind: .auth,
                scope: .global,
                label: "Claude Code auth",
                path: claudeJSONPath,
                format: .jsonc,
                fileControlled: false,
                canWriteSafely: false,
                writeMethod: .cli,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: true,
                supportsEnvExpansion: false,
                precedence: 0,
                note: "Claude Code authentication is verified through the Claude CLI and OS credential storage. Project Hub treats ~/.claude.json auth-shaped fields only as legacy/inferred evidence and never displays credential values."
            ),
            .init(
                id: projectRoot.map { "claude-code-local-project-state|\($0)" } ?? "claude-code-local-project-state",
                toolID: .claudeCode,
                kind: .settings,
                scope: .localProjectUser,
                label: "Claude Code local project state",
                path: claudeJSONPath,
                format: .jsonc,
                fileControlled: false,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 32,
                note: "Private Claude Code runtime state for the selected project. Project Hub uses it only as evidence, not as a write target."
            ),
            .init(
                id: "claude-code-managed-mcp-macos",
                toolID: .claudeCode,
                kind: .mcp,
                scope: .global,
                label: "Claude Code managed MCP",
                path: "\(claudeManagedDirs.macOS)/managed-mcp.json",
                format: .jsonc,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: true,
                supportsEnvExpansion: true,
                precedence: 0,
                note: "Enterprise-managed macOS MCP config. When present, it can define the fixed allowed server set."
            ),
            .init(
                id: "claude-code-managed-mcp-unix",
                toolID: .claudeCode,
                kind: .mcp,
                scope: .global,
                label: "Claude Code managed MCP (Unix)",
                path: "\(claudeManagedDirs.unix)/managed-mcp.json",
                format: .jsonc,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: true,
                supportsEnvExpansion: true,
                precedence: 0,
                note: "Enterprise-managed Unix MCP config. Project Hub inspects only."
            ),
            .init(
                id: "claude-code-user-settings",
                toolID: .claudeCode,
                kind: .settings,
                scope: .global,
                label: "Claude Code user settings",
                path: "\(claudeHome)/settings.json",
                format: .jsonc,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .file,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 20,
                note: "Holds Claude Code settings such as approvals and project MCP choices."
            ),
            .init(
                id: "claude-code-server-managed-settings",
                toolID: .claudeCode,
                kind: .settings,
                scope: .global,
                label: "Claude Code server-managed settings",
                path: serverManagedSettingsPath,
                format: serverManagedSettingsPath == nil ? .accountRuntime : .jsonc,
                fileControlled: false,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 0,
                note: "Claude.ai admin-console managed settings. Claude Code caches this read-only managed settings file at remote-settings.json under the active Claude home and reports it as Enterprise managed settings (remote) in /status."
            ),
            .init(
                id: "claude-code-managed-settings-macos",
                toolID: .claudeCode,
                kind: .settings,
                scope: .global,
                label: "Claude Code managed settings",
                path: "\(claudeManagedDirs.macOS)/managed-settings.json",
                format: .jsonc,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 0,
                note: "Enterprise managed policy on macOS; Project Hub can inspect but must not write it."
            ),
            .init(
                id: "claude-code-managed-settings-unix",
                toolID: .claudeCode,
                kind: .settings,
                scope: .global,
                label: "Claude Code managed settings (Unix)",
                path: "\(claudeManagedDirs.unix)/managed-settings.json",
                format: .jsonc,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 0,
                note: "Enterprise managed policy on Linux/WSL; Project Hub can inspect but must not write it."
            ),
            .init(
                id: "claude-code-managed-policy-user",
                toolID: .claudeCode,
                kind: .settings,
                scope: .global,
                label: "Claude Code managed policy (user)",
                path: "\(managedPreferencesRoot)/\(userName)/com.anthropic.claudecode.plist",
                format: .plist,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 0,
                note: "macOS MDM managed preferences for Claude Code. The plist mirrors managed-settings.json and takes precedence over file-based managed settings."
            ),
            .init(
                id: "claude-code-managed-policy-machine",
                toolID: .claudeCode,
                kind: .settings,
                scope: .global,
                label: "Claude Code managed policy (machine)",
                path: "\(managedPreferencesRoot)/com.anthropic.claudecode.plist",
                format: .plist,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 0,
                note: "Machine-wide macOS MDM managed preferences for Claude Code. Project Hub inspects only."
            ),
            .init(
                id: "claude-desktop-json-mcp",
                toolID: .claudeDesktop,
                kind: .mcp,
                scope: .desktopApp,
                label: "Claude Desktop local MCP",
                path: "\(claudeDesktopSupport)/claude_desktop_config.json",
                format: .jsonc,
                fileControlled: true,
                canWriteSafely: true,
                writeMethod: .file,
                requiresRestartAfterWrite: true,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 10,
                note: "Local MCP servers configured for Claude Desktop."
            ),
            .init(
                id: "claude-desktop-dxt",
                toolID: .claudeDesktop,
                kind: .mcp,
                scope: .desktopApp,
                label: "Claude Desktop extensions",
                path: "\(claudeDesktopSupport)/Claude Extensions",
                format: .directory,
                fileControlled: false,
                canWriteSafely: false,
                writeMethod: .appUI,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 11,
                note: "MCPB/DXT extensions are installed through Claude Desktop. Project Hub treats this local data directory as experimental read-only evidence."
            ),
            .init(
                id: "claude-desktop-remote-connectors",
                toolID: .claudeDesktop,
                kind: .mcp,
                scope: .account,
                label: "Claude remote connectors",
                path: nil,
                format: .accountRuntime,
                fileControlled: false,
                canWriteSafely: false,
                writeMethod: .appUI,
                requiresRestartAfterWrite: false,
                supportsDisable: true,
                supportsOAuth: true,
                supportsEnvExpansion: false,
                precedence: 12,
                note: "Remote connectors are account/runtime managed, not local JSON config."
            ),
            .init(
                id: "claude-desktop-managed-policy-user",
                toolID: .claudeDesktop,
                kind: .settings,
                scope: .desktopApp,
                label: "Claude Desktop managed policy (user)",
                path: "\(managedPreferencesRoot)/\(userName)/com.anthropic.claudefordesktop.plist",
                format: .plist,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 0,
                note: "Highest-precedence macOS MDM preferences for Claude Desktop; Project Hub inspects only."
            ),
            .init(
                id: "claude-desktop-managed-policy-machine",
                toolID: .claudeDesktop,
                kind: .settings,
                scope: .desktopApp,
                label: "Claude Desktop managed policy (machine)",
                path: "\(managedPreferencesRoot)/com.anthropic.claudefordesktop.plist",
                format: .plist,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 1,
                note: "Machine-wide macOS MDM preferences for Claude Desktop; Project Hub inspects only."
            ),
            .init(
                id: "claude-desktop-user-preferences",
                toolID: .claudeDesktop,
                kind: .settings,
                scope: .desktopApp,
                label: "Claude Desktop user preferences",
                path: "\(home)/Library/Preferences/com.anthropic.claudefordesktop.plist",
                format: .plist,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .appUI,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 30,
                note: "User preference domain used by Claude Desktop; prefer the app UI for changes."
            ),
            .init(
                id: "claude-desktop-code-policy-user",
                toolID: .claudeDesktop,
                kind: .settings,
                scope: .desktopApp,
                label: "Claude Desktop Code policy (user)",
                path: "\(managedPreferencesRoot)/\(userName)/com.anthropic.Claude.plist",
                format: .plist,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 0,
                note: "Managed macOS preference domain documented for Claude Code in the Desktop app; Project Hub inspects only."
            ),
            .init(
                id: "claude-desktop-code-policy-machine",
                toolID: .claudeDesktop,
                kind: .settings,
                scope: .desktopApp,
                label: "Claude Desktop Code policy (machine)",
                path: "\(managedPreferencesRoot)/com.anthropic.Claude.plist",
                format: .plist,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 1,
                note: "Machine-wide managed preference domain documented for Claude Code in the Desktop app; Project Hub inspects only."
            ),
            .init(
                id: "claude-desktop-account-skills",
                toolID: .claudeDesktop,
                kind: .skills,
                scope: .account,
                label: "Claude Desktop account skills",
                path: nil,
                format: .accountRuntime,
                fileControlled: false,
                canWriteSafely: false,
                writeMethod: .appUI,
                requiresRestartAfterWrite: false,
                supportsDisable: true,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 10,
                note: "Claude Desktop/Claude.ai skills are managed through Customize > Skills and organization settings. Project Hub does not have an official local filesystem root to scan or write."
            ),
            .init(
                id: "claude-desktop-account-auth",
                toolID: .claudeDesktop,
                kind: .auth,
                scope: .account,
                label: "Claude Desktop account auth",
                path: nil,
                format: .accountRuntime,
                fileControlled: false,
                canWriteSafely: false,
                writeMethod: .appUI,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: true,
                supportsEnvExpansion: false,
                precedence: 0,
                note: "Claude Desktop login and remote connector OAuth are managed by the Claude app/account. Local desktop extension credentials remain app-owned extension settings."
            ),
            .init(
                id: "codex-cli-global-mcp",
                toolID: .codexCLI,
                kind: .mcp,
                scope: .global,
                label: "Codex CLI global MCP",
                path: "\(codexHome)/config.toml",
                format: .toml,
                fileControlled: true,
                canWriteSafely: true,
                writeMethod: .file,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: true,
                supportsEnvExpansion: true,
                precedence: 10,
                note: "Global Codex config; project config can override it."
            ),
            .init(
                id: "codex-cli-global-settings",
                toolID: .codexCLI,
                kind: .settings,
                scope: .global,
                label: "Codex CLI global settings",
                path: "\(codexHome)/config.toml",
                format: .toml,
                fileControlled: true,
                canWriteSafely: true,
                writeMethod: .file,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: true,
                supportsEnvExpansion: true,
                precedence: 10,
                note: "Model, approvals, sandbox, profiles, projects, plugins, and MCP server tables."
            ),
            .init(
                id: "codex-desktop-global-mcp",
                toolID: .codexDesktop,
                kind: .mcp,
                scope: .global,
                label: "Codex Desktop shared MCP",
                path: "\(codexHome)/config.toml",
                format: .toml,
                fileControlled: true,
                canWriteSafely: true,
                writeMethod: .file,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: true,
                supportsEnvExpansion: true,
                precedence: 10,
                note: "Codex Desktop uses the Codex local configuration/app runtime surface."
            ),
            .init(
                id: "codex-desktop-global-settings",
                toolID: .codexDesktop,
                kind: .settings,
                scope: .global,
                label: "Codex Desktop shared settings",
                path: "\(codexHome)/config.toml",
                format: .toml,
                fileControlled: true,
                canWriteSafely: true,
                writeMethod: .file,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: true,
                supportsEnvExpansion: true,
                precedence: 10,
                note: "Shared Codex local configuration used by desktop sessions where supported."
            ),
            .init(
                id: "codex-desktop-user-preferences",
                toolID: .codexDesktop,
                kind: .settings,
                scope: .desktopApp,
                label: "Codex Desktop preferences",
                path: "\(home)/Library/Preferences/com.openai.codex.plist",
                format: .plist,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .appUI,
                requiresRestartAfterWrite: true,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 30,
                note: "macOS preference domain for Codex Desktop UI/app behavior. Agent config still lives in shared config.toml."
            ),
            .init(
                id: "codex-desktop-application-support",
                toolID: .codexDesktop,
                kind: .settings,
                scope: .desktopApp,
                label: "Codex Desktop app support",
                path: "\(home)/Library/Application Support/Codex",
                format: .directory,
                fileControlled: false,
                canWriteSafely: false,
                writeMethod: .appUI,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 31,
                note: "Local Codex Desktop runtime state and caches. Project Hub treats it as read-only evidence, not agent configuration."
            ),
            .init(
                id: "codex-admin-mcp",
                toolID: .codexCLI,
                kind: .mcp,
                scope: .global,
                label: "Codex admin MCP",
                path: "/etc/codex/config.toml",
                format: .toml,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: true,
                supportsEnvExpansion: true,
                precedence: 1,
                note: "Machine-admin Codex MCP configuration; Project Hub should inspect only."
            ),
            .init(
                id: "codex-admin-config",
                toolID: .codexCLI,
                kind: .settings,
                scope: .global,
                label: "Codex admin config",
                path: "/etc/codex/config.toml",
                format: .toml,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: true,
                supportsEnvExpansion: true,
                precedence: 1,
                note: "Machine-admin Codex configuration; Project Hub should inspect only."
            ),
            .init(
                id: "codex-managed-mcp",
                toolID: .codexCLI,
                kind: .mcp,
                scope: .global,
                label: "Codex managed MCP",
                path: "/etc/codex/managed_config.toml",
                format: .toml,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: true,
                supportsEnvExpansion: true,
                precedence: 0,
                note: "Managed Codex MCP policy/configuration; Project Hub should inspect only."
            ),
            .init(
                id: "codex-managed-config",
                toolID: .codexCLI,
                kind: .settings,
                scope: .global,
                label: "Codex managed config",
                path: "/etc/codex/managed_config.toml",
                format: .toml,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: true,
                supportsEnvExpansion: true,
                precedence: 0,
                note: "Managed Codex policy/configuration; Project Hub should inspect only."
            ),
            .init(
                id: "codex-requirements",
                toolID: .codexCLI,
                kind: .settings,
                scope: .global,
                label: "Codex requirements",
                path: codexRequirementsPath,
                format: .toml,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: true,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 0,
                note: "Machine policy requirements; Project Hub should inspect only."
            ),
            .init(
                id: "codex-auth",
                toolID: .codexCLI,
                kind: .auth,
                scope: .global,
                label: "Codex auth",
                path: "\(codexHome)/auth.json",
                format: .json,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .cli,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 0,
                note: "Detected for auth status only; Project Hub should not write credentials."
            ),
            .init(
                id: "codex-desktop-auth",
                toolID: .codexDesktop,
                kind: .auth,
                scope: .global,
                label: "Codex Desktop auth",
                path: "\(codexHome)/auth.json",
                format: .json,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .cli,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 0,
                note: "Codex app, CLI, and IDE surfaces share cached Codex login details or OS credential storage."
            ),
            .init(
                id: "claude-code-global-skills",
                toolID: .claudeCode,
                kind: .skills,
                scope: .global,
                label: "Claude Code personal skills",
                path: "\(claudeHome)/skills",
                format: .directory,
                fileControlled: true,
                canWriteSafely: true,
                writeMethod: .file,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 10,
                note: "Personal Claude Code skills. Claude Code live-watches existing skill directories; restart only if the top-level skills directory was created after the session started."
            ),
            .init(
                id: "codex-global-skills",
                toolID: .codexCLI,
                kind: .skills,
                scope: .global,
                label: "Codex global skills",
                path: "\(home)/.agents/skills",
                format: .directory,
                fileControlled: true,
                canWriteSafely: true,
                writeMethod: .file,
                requiresRestartAfterWrite: true,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 10,
                note: "Official user-authored Codex skill root."
            ),
            .init(
                id: "codex-desktop-global-skills",
                toolID: .codexDesktop,
                kind: .skills,
                scope: .global,
                label: "Codex Desktop global skills",
                path: "\(home)/.agents/skills",
                format: .directory,
                fileControlled: true,
                canWriteSafely: true,
                writeMethod: .file,
                requiresRestartAfterWrite: true,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 10,
                note: "Codex Desktop shares user-authored Codex skills from ~/.agents/skills."
            ),
            .init(
                id: "codex-managed-global-skills",
                toolID: .codexDesktop,
                kind: .skills,
                scope: .global,
                label: "Codex managed/legacy skills",
                path: "\(codexHome)/skills",
                format: .directory,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .file,
                requiresRestartAfterWrite: true,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 11,
                note: "Local evidence path; official user-authored skills live in ~/.agents/skills."
            ),
            .init(
                id: "codex-admin-skills",
                toolID: .codexCLI,
                kind: .skills,
                scope: .global,
                label: "Codex admin skills",
                path: "/etc/codex/skills",
                format: .directory,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: true,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 12,
                note: "Machine-admin Codex skill root."
            ),
            .init(
                id: "codex-desktop-admin-skills",
                toolID: .codexDesktop,
                kind: .skills,
                scope: .global,
                label: "Codex Desktop admin skills",
                path: "/etc/codex/skills",
                format: .directory,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: true,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 12,
                note: "Machine-admin Codex skill root shared with the Codex app."
            )
        ]

        surfaces.append(contentsOf: Self.codexPluginMCPSurfaces(
            codexHome: codexHome,
            projectRoot: projectRoot,
            codexProfileSelection: codexProfileSelection
        ))
        surfaces.append(contentsOf: Self.codexProfileConfigSurfaces(
            codexHome: codexHome,
            selection: codexProfileSelection
        ))
        surfaces.append(contentsOf: Self.codexPluginSkillSurfaces(
            codexHome: codexHome,
            codexProfileSelection: codexProfileSelection
        ))
        surfaces.append(contentsOf: Self.codexPluginManifestSurfaces(
            codexHome: codexHome,
            codexProfileSelection: codexProfileSelection
        ))
        surfaces.append(contentsOf: Self.codexPluginMarketplaceSurfaces(home: home, projectRoot: projectRoot))
        surfaces.append(contentsOf: Self.codexGlobalInstructionSurfaces(codexHome: codexHome))
        surfaces.append(contentsOf: Self.claudeCodeManagedSettingsDropInSurfaces(
            baseDirs: [claudeManagedDirs.macOS, claudeManagedDirs.unix]
        ))

        var claudeMemoryConfig = Self.claudeMemoryConfiguration(from: surfaces, projectRoot: projectRoot)

        if let root = projectRoot {
            let cliInstructionConfig = codexInstructionConfig(
                codexHome: codexHome,
                projectRoot: root,
                selectedPath: selectedPath,
                codexProfileSelection: codexProfileSelection,
                includeProfileFile: true,
                toolIDs: [.codexCLI]
            )
            let desktopInstructionConfig = codexInstructionConfig(
                codexHome: codexHome,
                projectRoot: root,
                selectedPath: selectedPath,
                codexProfileSelection: nil,
                includeProfileFile: false,
                toolIDs: [.codexDesktop]
            )
            surfaces.append(contentsOf: [
                .init(
                    id: "claude-code-project-mcp",
                    toolID: .claudeCode,
                    kind: .mcp,
                    scope: .project,
                    label: "Claude Code project MCP",
                    path: "\(root)/.mcp.json",
                    format: .jsonc,
                    fileControlled: true,
                    canWriteSafely: true,
                    writeMethod: .file,
                    requiresRestartAfterWrite: true,
                    supportsDisable: false,
                    supportsOAuth: true,
                    supportsEnvExpansion: true,
                    precedence: 20,
                    note: "Team-shared project MCP file."
                ),
                .init(
                    id: "claude-code-project-settings",
                    toolID: .claudeCode,
                    kind: .settings,
                    scope: .project,
                    label: "Claude Code project settings",
                    path: "\(root)/.claude/settings.json",
                    format: .jsonc,
                    fileControlled: true,
                    canWriteSafely: false,
                    writeMethod: .file,
                    requiresRestartAfterWrite: false,
                    supportsDisable: false,
                    supportsOAuth: false,
                    supportsEnvExpansion: false,
                    precedence: 21,
                    note: "Shared Claude Code project settings."
                ),
                .init(
                    id: "claude-code-project-local-settings",
                    toolID: .claudeCode,
                    kind: .settings,
                    scope: .localProjectUser,
                    label: "Claude Code local project settings",
                    path: "\(root)/.claude/settings.local.json",
                    format: .jsonc,
                    fileControlled: true,
                    canWriteSafely: false,
                    writeMethod: .file,
                    requiresRestartAfterWrite: false,
                    supportsDisable: false,
                    supportsOAuth: false,
                    supportsEnvExpansion: false,
                    precedence: 31,
                    note: "User-private Claude Code project settings."
                ),
                .init(
                    id: "claude-desktop-project-launch",
                    toolID: .claudeDesktop,
                    kind: .settings,
                    scope: .project,
                    label: "Claude Desktop project launch",
                    path: "\(root)/.claude/launch.json",
                    format: .jsonc,
                    fileControlled: true,
                    canWriteSafely: false,
                    writeMethod: .file,
                    requiresRestartAfterWrite: false,
                    supportsDisable: false,
                    supportsOAuth: false,
                    supportsEnvExpansion: true,
                    precedence: 22,
                    note: "Claude Desktop Code preview/dev-server settings for the selected project folder."
                ),
            ])
            claudeMemoryConfig = Self.claudeMemoryConfiguration(from: surfaces, projectRoot: projectRoot)
            let instructionStart = instructionSurfaceStart(projectRoot: root, selectedPath: selectedPath)
            surfaces.append(contentsOf: Self.claudeRepositoryInstructionSurfaces(
                start: instructionStart,
                projectRoot: root,
                exclusions: claudeMemoryConfig.excludes
            ))
            surfaces.append(contentsOf: Self.claudeRepositoryRuleSurfaces(
                projectRoot: root,
                exclusions: claudeMemoryConfig.excludes
            ))
            surfaces.append(contentsOf: Self.claudeAdditionalDirectoryInstructionSurfaces(
                from: surfaces,
                projectRoot: projectRoot,
                exclusions: claudeMemoryConfig.excludes
            ))
            surfaces.append(contentsOf: Self.codexProjectConfigSurfaces(projectRoot: root, selectedPath: selectedPath))
            let skillStart = selectedPath ?? root
            surfaces.append(contentsOf: Self.claudeRepositorySkillSurfaces(start: skillStart))
            let additionalDirectorySkillConfig = Self.claudeMemoryConfiguration(from: surfaces, projectRoot: projectRoot)
            var existingClaudeSkillRoots = Set(surfaces
                .filter { $0.toolID == .claudeCode && $0.kind == .skills }
                .compactMap(\.path)
                .map(canonicalFilePath))
            let additionalDirectorySkillSurfaces = Self.claudeAdditionalDirectorySkillSurfaces(
                from: additionalDirectorySkillConfig,
                excluding: existingClaudeSkillRoots
            )
            surfaces.append(contentsOf: additionalDirectorySkillSurfaces)
            existingClaudeSkillRoots.formUnion(additionalDirectorySkillSurfaces.compactMap(\.path).map(canonicalFilePath))
            surfaces.append(contentsOf: Self.claudeLocalProjectAdditionalDirectorySkillSurfaces(
                projectRoot: projectRoot,
                claudeJSONPath: claudeJSONPath,
                excluding: existingClaudeSkillRoots
            ))
            surfaces.append(contentsOf: Self.codexRepositorySkillSurfaces(start: skillStart))
            surfaces.append(contentsOf: Self.codexRepositoryInstructionSurfaces(
                start: instructionStart,
                fallbackFilenames: cliInstructionConfig.fallbackFilenames,
                toolID: .codexCLI
            ))
            surfaces.append(contentsOf: Self.codexRepositoryInstructionSurfaces(
                start: instructionStart,
                fallbackFilenames: desktopInstructionConfig.fallbackFilenames,
                toolID: .codexDesktop
            ))
            surfaces.append(contentsOf: Self.codexConfiguredInstructionFileSurfaces(config: cliInstructionConfig))
            surfaces.append(contentsOf: Self.codexConfiguredInstructionFileSurfaces(config: desktopInstructionConfig))
        }
        surfaces.append(contentsOf: Self.claudeUserRuleSurfaces(
            claudeHome: claudeHome,
            exclusions: claudeMemoryConfig.excludes
        ))
        surfaces.append(contentsOf: Self.claudePluginSkillSurfaces(
            claudeHome: claudeHome,
            projectRoot: projectRoot
        ))
        surfaces.append(contentsOf: Self.claudePluginMCPSurfaces(
            claudeHome: claudeHome,
            projectRoot: projectRoot
        ))
        return surfaces
    }

    private static func claudeCodeManagedDirectories() -> (macOS: String, unix: String) {
        if let override = ProcessInfo.processInfo.environment["PROJECTHUB_CLAUDE_CODE_MANAGED_DIR"],
           !override.isEmpty {
            return (override, override)
        }
        return ("/Library/Application Support/ClaudeCode", "/etc/claude-code")
    }

    private static func managedPreferencesDirectory() -> String {
        if let override = ProcessInfo.processInfo.environment["PROJECTHUB_MANAGED_PREFERENCES_DIR"],
           !override.isEmpty {
            return (override as NSString).expandingTildeInPath
        }
        return "/Library/Managed Preferences"
    }

    private static func claudeCodeServerManagedSettingsPath(claudeHome: String) -> String? {
        if let override = ProcessInfo.processInfo.environment["PROJECTHUB_CLAUDE_CODE_SERVER_MANAGED_SETTINGS_PATH"],
           !override.isEmpty {
            return (override as NSString).expandingTildeInPath
        }
        return "\(claudeHome)/remote-settings.json"
    }

    private static func claudeHomeDirectory(home: String = NSHomeDirectory()) -> String {
        if let override = ProcessInfo.processInfo.environment["PROJECTHUB_CLAUDE_HOME"],
           !override.isEmpty {
            return override
        }
        if let configDir = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"],
           !configDir.isEmpty {
            return (configDir as NSString).expandingTildeInPath
        }
        return "\(home)/.claude"
    }

    private static func claudeCodeJSONPath(home: String = NSHomeDirectory()) -> String {
        if let override = ProcessInfo.processInfo.environment["PROJECTHUB_CLAUDE_JSON_PATH"],
           !override.isEmpty {
            return override
        }
        return "\(home)/.claude.json"
    }

    private static func claudeDesktopApplicationSupportDirectory(home: String = NSHomeDirectory()) -> String {
        if let override = ProcessInfo.processInfo.environment["PROJECTHUB_CLAUDE_DESKTOP_SUPPORT_DIR"],
           !override.isEmpty {
            return override
        }
        return "\(home)/Library/Application Support/Claude"
    }

    private static func claudeCodeManagedSettingsDropInSurfaces(baseDirs: [String]) -> [CompatibilityMatrixEntry] {
        var surfaces: [CompatibilityMatrixEntry] = []
        var seen = Set<String>()
        for baseDir in baseDirs {
            let dropInDir = (baseDir as NSString).appendingPathComponent("managed-settings.d")
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dropInDir) else { continue }
            for entry in entries.sorted()
                where !entry.hasPrefix(".") && entry.lowercased().hasSuffix(".json") {
                let path = (dropInDir as NSString).appendingPathComponent(entry)
                guard seen.insert(Project.canonicalize(path)).inserted else { continue }
                surfaces.append(.init(
                    id: "claude-code-managed-settings-dropin|\(path)",
                    toolID: .claudeCode,
                    kind: .settings,
                    scope: .global,
                    label: "Claude Code managed settings drop-in",
                    path: path,
                    format: .jsonc,
                    fileControlled: true,
                    canWriteSafely: false,
                    writeMethod: .unsupported,
                    requiresRestartAfterWrite: false,
                    supportsDisable: false,
                    supportsOAuth: false,
                    supportsEnvExpansion: false,
                    precedence: 0,
                    note: "Managed settings drop-in fragment. Claude Code merges managed-settings.json first, then sorted managed-settings.d/*.json files."
                ))
            }
        }
        return surfaces
    }

    private static func instructionSurfaceStart(projectRoot: String, selectedPath: String?) -> String {
        guard let selectedPath else { return projectRoot }
        let expanded = expandedPath(selectedPath)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), !isDirectory.boolValue {
            return (expanded as NSString).deletingLastPathComponent
        }
        return expanded
    }

    private static func claudeUserRuleSurfaces(
        claudeHome: String,
        exclusions: [String]
    ) -> [CompatibilityMatrixEntry] {
        claudeRuleSurfaces(
            root: (claudeHome as NSString).appendingPathComponent("rules"),
            idPrefix: "claude-code-user-rule",
            scope: .global,
            labelPrefix: "Claude Code user rule",
            precedenceBase: 12,
            note: "Personal Claude Code rule from ~/.claude/rules. User rules apply to every project before project rules.",
            exclusions: exclusions
        )
    }

    private static func claudeRepositoryInstructionSurfaces(
        start: String,
        projectRoot: String,
        exclusions: [String]
    ) -> [CompatibilityMatrixEntry] {
        let repoRoot = nearestRepositoryRoot(from: start) ?? projectRoot
        let startURL = URL(fileURLWithPath: expandedPath(start))
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let stopURL = URL(fileURLWithPath: Project.canonicalize(repoRoot))
        var directories: [URL] = []
        var current = startURL

        while true {
            directories.append(current)
            if current.path == stopURL.path { break }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }

        let rootToWorkingDirectory = directories.reversed()
        var surfaces: [CompatibilityMatrixEntry] = []
        for (directoryIndex, directory) in rootToWorkingDirectory.enumerated() {
            let isRoot = directory.path == stopURL.path
            let location = isRoot ? "repository" : "nested"
            let claudePath = directory.appendingPathComponent("CLAUDE.md").path
            if !claudeMemoryPathIsExcluded(claudePath, by: exclusions) {
                surfaces.append(CompatibilityMatrixEntry(
                    id: isRoot ? "claude-code-project-context" : "claude-code-project-context|\(directory.path)|CLAUDE.md",
                    toolID: .claudeCode,
                    kind: .context,
                    scope: .project,
                    label: "Claude Code \(location) instructions",
                    path: claudePath,
                    format: .markdown,
                    fileControlled: true,
                    canWriteSafely: false,
                    writeMethod: .file,
                    requiresRestartAfterWrite: false,
                    supportsDisable: false,
                    supportsOAuth: false,
                    supportsEnvExpansion: false,
                    precedence: 20 + (directoryIndex * 10),
                    note: isRoot
                        ? "Claude project guidance file. Claude Code loads CLAUDE.md files from the working directory hierarchy unless excluded by claudeMdExcludes."
                        : "Nested Claude guidance file loaded when the session starts in or enters this directory hierarchy unless excluded by claudeMdExcludes."
                ))
            }

            if isRoot {
                let dotClaudePath = directory.appendingPathComponent(".claude/CLAUDE.md").path
                if !claudeMemoryPathIsExcluded(dotClaudePath, by: exclusions) {
                    surfaces.append(CompatibilityMatrixEntry(
                        id: "claude-code-project-context|\(directory.path)|.claude/CLAUDE.md",
                        toolID: .claudeCode,
                        kind: .context,
                        scope: .project,
                        label: "Claude Code repository .claude instructions",
                        path: dotClaudePath,
                        format: .markdown,
                        fileControlled: true,
                        canWriteSafely: false,
                        writeMethod: .file,
                        requiresRestartAfterWrite: false,
                        supportsDisable: false,
                        supportsOAuth: false,
                        supportsEnvExpansion: false,
                        precedence: 21,
                        note: "Alternate team-shared Claude project guidance location documented for Claude Code; can be skipped by claudeMdExcludes."
                    ))
                }
            }

            let localPath = directory.appendingPathComponent("CLAUDE.local.md").path
            if !claudeMemoryPathIsExcluded(localPath, by: exclusions) {
                surfaces.append(CompatibilityMatrixEntry(
                    id: "claude-code-local-context|\(directory.path)|CLAUDE.local.md",
                    toolID: .claudeCode,
                    kind: .context,
                    scope: .localProjectUser,
                    label: "Claude Code \(location) local instructions",
                    path: localPath,
                    format: .markdown,
                    fileControlled: true,
                    canWriteSafely: false,
                    writeMethod: .file,
                    requiresRestartAfterWrite: false,
                    supportsDisable: false,
                    supportsOAuth: false,
                    supportsEnvExpansion: false,
                    precedence: 22 + (directoryIndex * 10),
                    note: "User-private Claude project guidance loaded after CLAUDE.md at this directory level unless excluded by claudeMdExcludes; it should usually be gitignored."
                ))
            }
        }
        return surfaces
    }

    private static func claudeRepositoryRuleSurfaces(
        projectRoot: String,
        exclusions: [String]
    ) -> [CompatibilityMatrixEntry] {
        claudeRuleSurfaces(
            root: (projectRoot as NSString).appendingPathComponent(".claude/rules"),
            idPrefix: "claude-code-project-rule",
            scope: .project,
            labelPrefix: "Claude Code project rule",
            precedenceBase: 23,
            note: "Project Claude rule from .claude/rules. Rules without paths frontmatter load at launch; path-scoped rules load when Claude reads matching files unless excluded by claudeMdExcludes.",
            exclusions: exclusions
        )
    }

    private static func claudeRuleSurfaces(
        root: String,
        idPrefix: String,
        scope: CompatibilityScope,
        labelPrefix: String,
        precedenceBase: Int,
        note: String,
        exclusions: [String]
    ) -> [CompatibilityMatrixEntry] {
        markdownFilesRecursively(in: root)
            .filter { !claudeMemoryPathIsExcluded($0, by: exclusions) }
            .enumerated()
            .map { index, path in
            let relative = relativePath(path, from: root) ?? (path as NSString).lastPathComponent
            return CompatibilityMatrixEntry(
                id: "\(idPrefix)|\(path)",
                toolID: .claudeCode,
                kind: .context,
                scope: scope,
                label: "\(labelPrefix): \(relative)",
                path: path,
                format: .markdown,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .file,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: precedenceBase + index,
                note: note
            )
        }
    }

    private struct ClaudeMemoryConfiguration {
        var excludes: [String]
        var additionalDirectories: [(path: String, source: CompatibilityMatrixEntry)]
    }

    private static func claudeMemoryConfiguration(
        from surfaces: [CompatibilityMatrixEntry],
        projectRoot: String?
    ) -> ClaudeMemoryConfiguration {
        var excludes: [String] = []
        var directories: [(path: String, source: CompatibilityMatrixEntry)] = []

        for surface in surfaces where surface.toolID == .claudeCode && surface.kind == .settings {
            guard let path = surface.path,
                  FileManager.default.fileExists(atPath: path),
                  let raw = try? String(contentsOfFile: path, encoding: .utf8),
                  let data = ConfigWriter.stripJsonComments(raw).data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            excludes.append(contentsOf: stringArray(root["claudeMdExcludes"]))
            let memoryRoot = claudeProjectState(from: surface, root: root) ?? root
            for directory in claudeAdditionalDirectories(in: memoryRoot) {
                guard let resolved = resolveClaudeAdditionalDirectory(directory, surface: surface, projectRoot: projectRoot) else {
                    continue
                }
                directories.append((resolved, surface))
            }
        }

        var seenDirectories = Set<String>()
        let prioritizedDirectories = directories.sorted { lhs, rhs in
            if lhs.source.fileControlled != rhs.source.fileControlled {
                return lhs.source.fileControlled && !rhs.source.fileControlled
            }
            return lhs.source.precedence < rhs.source.precedence
        }
        let uniqueDirectories = prioritizedDirectories.filter { entry in
            seenDirectories.insert(Project.canonicalize(entry.path)).inserted
        }

        return ClaudeMemoryConfiguration(
            excludes: uniqueStringsPreservingOrder(excludes),
            additionalDirectories: uniqueDirectories
        )
    }

    private static func claudeAdditionalDirectories(in root: [String: Any]) -> [String] {
        var directories = stringArray(root["additionalDirectories"])
        if let permissions = root["permissions"] as? [String: Any] {
            directories += stringArray(permissions["additionalDirectories"])
        }
        return uniqueStringsPreservingOrder(directories)
    }

    private static func claudeAdditionalDirectoryInstructionSurfaces(
        from surfaces: [CompatibilityMatrixEntry],
        projectRoot: String?,
        exclusions: [String]
    ) -> [CompatibilityMatrixEntry] {
        guard claudeAdditionalDirectoryMemoryEnabled() else { return [] }
        let config = claudeMemoryConfiguration(from: surfaces, projectRoot: projectRoot)
        var entries: [CompatibilityMatrixEntry] = []

        for (index, entry) in config.additionalDirectories.enumerated() {
            let base = URL(fileURLWithPath: entry.path)
            let candidates: [(suffix: String, label: String, path: String, scope: CompatibilityScope, precedenceOffset: Int, note: String)] = [
                (
                    "CLAUDE.md",
                    "Claude Code additional-directory instructions",
                    base.appendingPathComponent("CLAUDE.md").path,
                    entry.source.scope,
                    0,
                    "Loaded from additionalDirectories because CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD is enabled."
                ),
                (
                    ".claude/CLAUDE.md",
                    "Claude Code additional-directory .claude instructions",
                    base.appendingPathComponent(".claude/CLAUDE.md").path,
                    entry.source.scope,
                    1,
                    "Alternate additional-directory Claude guidance loaded when CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD is enabled."
                ),
                (
                    "CLAUDE.local.md",
                    "Claude Code additional-directory local instructions",
                    base.appendingPathComponent("CLAUDE.local.md").path,
                    .localProjectUser,
                    2,
                    "User-private additional-directory guidance loaded when CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD is enabled and local settings sources are active."
                )
            ]

            for candidate in candidates where !claudeMemoryPathIsExcluded(candidate.path, by: exclusions) {
                entries.append(CompatibilityMatrixEntry(
                    id: "claude-code-additional-directory-context|\(entry.path)|\(candidate.suffix)",
                    toolID: .claudeCode,
                    kind: .context,
                    scope: candidate.scope,
                    label: candidate.label,
                    path: candidate.path,
                    format: .markdown,
                    fileControlled: true,
                    canWriteSafely: false,
                    writeMethod: .file,
                    requiresRestartAfterWrite: false,
                    supportsDisable: false,
                    supportsOAuth: false,
                    supportsEnvExpansion: false,
                    precedence: 70 + (index * 10) + candidate.precedenceOffset,
                    note: "\(candidate.note) Source: \(entry.source.label)."
                ))
            }

            entries.append(contentsOf: claudeRuleSurfaces(
                root: base.appendingPathComponent(".claude/rules").path,
                idPrefix: "claude-code-additional-directory-rule|\(entry.path)",
                scope: entry.source.scope,
                labelPrefix: "Claude Code additional-directory rule",
                precedenceBase: 73 + (index * 10),
                note: "Rule loaded from additionalDirectories when CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD is enabled. Source: \(entry.source.label).",
                exclusions: exclusions
            ))
        }

        return entries
    }

    private static func claudeAdditionalDirectorySkillSurfaces(
        from config: ClaudeMemoryConfiguration,
        excluding existingRoots: Set<String>
    ) -> [CompatibilityMatrixEntry] {
        var seenRoots = existingRoots
        return config.additionalDirectories.enumerated().compactMap { index, entry in
            let skillsRoot = URL(fileURLWithPath: entry.path)
                .appendingPathComponent(".claude/skills")
                .path
            guard seenRoots.insert(canonicalFilePath(skillsRoot)).inserted else { return nil }
            return CompatibilityMatrixEntry(
                id: "claude-code-additional-directory-skills|\(entry.path)",
                toolID: .claudeCode,
                kind: .skills,
                scope: entry.source.scope,
                label: "Claude Code additional-directory skills",
                path: skillsRoot,
                format: .directory,
                fileControlled: true,
                canWriteSafely: true,
                writeMethod: .file,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 50 + index,
                note: "Skill root inferred from Claude Code additionalDirectories. Source: \(entry.source.label)."
            )
        }
    }

    private static func claudeLocalProjectAdditionalDirectorySkillSurfaces(
        projectRoot: String?,
        claudeJSONPath: String,
        excluding existingRoots: Set<String>
    ) -> [CompatibilityMatrixEntry] {
        guard let projectRoot,
              let root = readJSONDictionary(at: claudeJSONPath),
              let state = claudeProjectState(projectRoot: projectRoot, root: root) else {
            return []
        }

        let source = CompatibilityMatrixEntry(
            id: "claude-code-local-project-state|\(projectRoot)",
            toolID: .claudeCode,
            kind: .settings,
            scope: .localProjectUser,
            label: "Claude Code local project state",
            path: claudeJSONPath,
            format: .jsonc,
            fileControlled: false,
            canWriteSafely: false,
            writeMethod: .unsupported,
            requiresRestartAfterWrite: false,
            supportsDisable: false,
            supportsOAuth: false,
            supportsEnvExpansion: false,
            precedence: 32,
            note: "Private Claude Code runtime state for the selected project. Project Hub uses it only as evidence, not as a write target."
        )

        var seenRoots = existingRoots
        return claudeAdditionalDirectories(in: state).enumerated().compactMap { index, rawPath in
            guard let directory = resolveClaudeAdditionalDirectory(rawPath, surface: source, projectRoot: projectRoot) else {
                return nil
            }
            let skillsRoot = URL(fileURLWithPath: directory)
                .appendingPathComponent(".claude/skills")
                .path
            guard seenRoots.insert(canonicalFilePath(skillsRoot)).inserted else { return nil }
            return CompatibilityMatrixEntry(
                id: "claude-code-local-project-additional-directory-skills|\(directory)",
                toolID: .claudeCode,
                kind: .skills,
                scope: .localProjectUser,
                label: "Claude Code local additional-directory skills",
                path: skillsRoot,
                format: .directory,
                fileControlled: true,
                canWriteSafely: true,
                writeMethod: .file,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 55 + index,
                note: "Skill root inferred from Claude Code local project additionalDirectories."
            )
        }
    }

    private static func claudeAdditionalDirectoryMemoryEnabled() -> Bool {
        guard let value = ProcessInfo.processInfo.environment["CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD"] else {
            return false
        }
        return ["1", "true", "yes", "on"].contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private static func claudeMemoryPathIsExcluded(_ path: String, by patterns: [String]) -> Bool {
        let canonical = canonicalFilePath(path)
        return patterns.contains { pattern in
            globMatchesAbsolutePath(pattern, path: canonical)
        }
    }

    private static func globMatchesAbsolutePath(_ pattern: String, path: String) -> Bool {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let expanded = (trimmed as NSString).expandingTildeInPath
        let candidates: [String]
        if expanded.hasPrefix("/") || expanded.hasPrefix("**/") {
            candidates = [expanded]
        } else {
            candidates = [expanded, "**/\(expanded)"]
        }
        return candidates.contains { candidate in
            expandSingleBraceGlob(candidate).contains { expandedPattern in
                guard let regex = try? NSRegularExpression(pattern: "^" + regexPattern(forGlob: expandedPattern) + "$") else {
                    return false
                }
                let range = NSRange(location: 0, length: (path as NSString).length)
                return regex.firstMatch(in: path, range: range) != nil
            }
        }
    }

    static func skillInventory(projectRoot: String?) -> CompatibilitySkillInventory {
        let selectedPath = projectRoot.map(expandedPath)
        let normalizedRoot = projectRoot.map(Project.canonicalize)
        let matrix = compatibilityMatrix(
            projectRoot: normalizedRoot,
            selectedPath: selectedPath,
            codexProfileSelection: nil
        )
        let read = readSkills(from: matrix, servers: [])
        return CompatibilitySkillInventory(
            projectRoot: normalizedRoot,
            matrix: matrix,
            skills: read.skills
        )
    }

    private static func expandSingleBraceGlob(_ pattern: String) -> [String] {
        guard let open = pattern.firstIndex(of: "{"),
              let close = pattern[open...].firstIndex(of: "}") else {
            return [pattern]
        }
        let prefix = String(pattern[..<open])
        let suffix = String(pattern[pattern.index(after: close)...])
        let body = pattern[pattern.index(after: open)..<close]
        return body.split(separator: ",").map { prefix + String($0) + suffix }
    }

    private static func regexPattern(forGlob glob: String) -> String {
        var regex = ""
        var index = glob.startIndex
        let special = Set("\\.[]{}()+-^$|")
        while index < glob.endIndex {
            let char = glob[index]
            if char == "*" {
                let next = glob.index(after: index)
                if next < glob.endIndex, glob[next] == "*" {
                    regex += ".*"
                    index = glob.index(after: next)
                } else {
                    regex += "[^/]*"
                    index = next
                }
                continue
            }
            if char == "?" {
                regex += "[^/]"
            } else if special.contains(char) {
                regex += "\\\(char)"
            } else {
                regex.append(char)
            }
            index = glob.index(after: index)
        }
        return regex
    }

    private static func markdownFilesRecursively(in root: String) -> [String] {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: root, isDirectory: &isDirectory), isDirectory.boolValue,
              let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        var paths: [String] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "md" else { continue }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            if values?.isRegularFile == false { continue }
            paths.append(url.path)
        }
        return paths.sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    private static func codexProjectConfigSurfaces(projectRoot: String, selectedPath: String?) -> [CompatibilityMatrixEntry] {
        codexProjectConfigLayerRoots(projectRoot: projectRoot, selectedPath: selectedPath).enumerated().flatMap { index, layerRoot in
            let suffix = index == 0 ? "" : "|\(layerRoot)"
            let layerLabel = index == 0 ? "" : " (\(relativePath(layerRoot, from: projectRoot) ?? layerRoot))"
            let basePrecedence = 20 + index
            let configPath = (layerRoot as NSString).appendingPathComponent(".codex/config.toml")
            let reloadForCLI = index == 0 ? false : true
            let note = index == 0
                ? "Project-level Codex config overrides global config."
                : "Nested Codex project config layer loaded after the project root layer when the session starts inside this subdirectory."

            return [
                CompatibilityMatrixEntry(
                    id: "codex-cli-project-mcp\(suffix)",
                    toolID: .codexCLI,
                    kind: .mcp,
                    scope: .project,
                    label: "Codex CLI project MCP\(layerLabel)",
                    path: configPath,
                    format: .toml,
                    fileControlled: true,
                    canWriteSafely: index == 0,
                    writeMethod: index == 0 ? .file : .unsupported,
                    requiresRestartAfterWrite: reloadForCLI,
                    supportsDisable: true,
                    supportsOAuth: true,
                    supportsEnvExpansion: true,
                    precedence: basePrecedence,
                    note: note
                ),
                CompatibilityMatrixEntry(
                    id: "codex-cli-project-settings\(suffix)",
                    toolID: .codexCLI,
                    kind: .settings,
                    scope: .project,
                    label: "Codex CLI project settings\(layerLabel)",
                    path: configPath,
                    format: .toml,
                    fileControlled: true,
                    canWriteSafely: index == 0,
                    writeMethod: index == 0 ? .file : .unsupported,
                    requiresRestartAfterWrite: true,
                    supportsDisable: true,
                    supportsOAuth: true,
                    supportsEnvExpansion: true,
                    precedence: basePrecedence,
                    note: index == 0
                        ? "Project-level Codex configuration overrides global defaults for this workspace."
                        : "Nested Codex project configuration overrides broader project layers for sessions started inside this subdirectory."
                ),
                CompatibilityMatrixEntry(
                    id: "codex-desktop-project-mcp\(suffix)",
                    toolID: .codexDesktop,
                    kind: .mcp,
                    scope: .project,
                    label: "Codex Desktop project MCP\(layerLabel)",
                    path: configPath,
                    format: .toml,
                    fileControlled: true,
                    canWriteSafely: index == 0,
                    writeMethod: index == 0 ? .file : .unsupported,
                    requiresRestartAfterWrite: true,
                    supportsDisable: true,
                    supportsOAuth: true,
                    supportsEnvExpansion: true,
                    precedence: basePrecedence,
                    note: index == 0
                        ? "Project-level Codex config seen by Codex app sessions for this workspace."
                        : "Nested Codex project config layer visible to Codex app sessions opened inside this subdirectory."
                ),
                CompatibilityMatrixEntry(
                    id: "codex-desktop-project-settings\(suffix)",
                    toolID: .codexDesktop,
                    kind: .settings,
                    scope: .project,
                    label: "Codex Desktop project settings\(layerLabel)",
                    path: configPath,
                    format: .toml,
                    fileControlled: true,
                    canWriteSafely: index == 0,
                    writeMethod: index == 0 ? .file : .unsupported,
                    requiresRestartAfterWrite: true,
                    supportsDisable: true,
                    supportsOAuth: true,
                    supportsEnvExpansion: true,
                    precedence: basePrecedence,
                    note: index == 0
                        ? "Project-level Codex configuration visible to Codex app sessions for this workspace."
                        : "Nested Codex project configuration visible to Codex app sessions opened inside this subdirectory."
                )
            ]
        }
    }

    private static func codexProjectConfigLayerRoots(projectRoot: String, selectedPath: String?) -> [String] {
        var layers = [projectRoot]
        guard let selectedDirectory = selectedDirectory(for: selectedPath),
              selectedDirectory != projectRoot,
              selectedDirectory.hasPrefix(projectRoot + "/") else {
            return layers
        }

        var cursor = projectRoot
        let relative = String(selectedDirectory.dropFirst(projectRoot.count + 1))
        for part in relative.split(separator: "/").map(String.init) {
            cursor = (cursor as NSString).appendingPathComponent(part)
            guard FileManager.default.fileExists(atPath: (cursor as NSString).appendingPathComponent(".codex/config.toml")) else {
                continue
            }
            layers.append(cursor)
        }
        return layers
    }

    private static func codexProfileConfigSurfaces(
        codexHome: String,
        selection: CodexProfileSelection?
    ) -> [CompatibilityMatrixEntry] {
        guard let selection = codexActiveProfileSelection(
                codexHome: codexHome,
                selection: selection,
                allowDefaultConfig: true
              ),
              let path = codexProfileConfigPath(codexHome: codexHome, profileName: selection.name) else {
            return []
        }
        let safeID = selection.name.replacingOccurrences(of: "|", with: "_")
        return [
            CompatibilityMatrixEntry(
                id: "codex-cli-profile-mcp|\(safeID)",
                toolID: .codexCLI,
                kind: .mcp,
                scope: .global,
                label: "Codex CLI profile MCP (\(selection.name))",
                path: path,
                format: .toml,
                fileControlled: true,
                canWriteSafely: true,
                writeMethod: .file,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: true,
                supportsEnvExpansion: true,
                precedence: 11,
                note: "Active Codex CLI profile config file. Project Hub includes this layer for the selected or default profile scan."
            ),
            CompatibilityMatrixEntry(
                id: "codex-cli-profile-settings|\(safeID)",
                toolID: .codexCLI,
                kind: .settings,
                scope: .global,
                label: "Codex CLI profile settings (\(selection.name))",
                path: path,
                format: .toml,
                fileControlled: true,
                canWriteSafely: true,
                writeMethod: .file,
                requiresRestartAfterWrite: true,
                supportsDisable: true,
                supportsOAuth: true,
                supportsEnvExpansion: true,
                precedence: 11,
                note: "Active Codex CLI profile config file. Codex loads it beside CODEX_HOME/config.toml."
            )
        ]
    }

    private static func codexActiveProfileSelection(
        codexHome: String,
        selection: CodexProfileSelection?,
        allowDefaultConfig: Bool
    ) -> CodexProfileSelection? {
        if let selection {
            return selection
        }
        guard allowDefaultConfig else { return nil }
        let configPath = (codexHome as NSString).appendingPathComponent("config.toml")
        let document = parseSettingsTOMLDocument((try? String(contentsOfFile: configPath, encoding: .utf8)) ?? "")
        return codexEffectiveProfile(in: document, toolID: .codexCLI, selection: nil)
    }

    private static func selectedDirectory(for selectedPath: String?) -> String? {
        guard let selectedPath else { return nil }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: selectedPath, isDirectory: &isDirectory),
           !isDirectory.boolValue {
            return (selectedPath as NSString).deletingLastPathComponent
        }
        return selectedPath
    }

    private static func relativePath(_ path: String, from root: String) -> String? {
        guard path.hasPrefix(root + "/") else { return nil }
        return String(path.dropFirst(root.count + 1))
    }

    private struct CodexInstructionConfig {
        let fallbackFilenames: [String]
        let maxBytes: Int
        let projectDocsDisabled: Bool
        let projectDocMaxBytesSource: CodexProjectDocMaxBytesSource?
        let modelInstructionsFile: CodexConfiguredInstructionFile?
        let experimentalInstructionsFile: CodexConfiguredInstructionFile?
    }

    private struct CodexProjectDocMaxBytesSource {
        let value: Int
        let configPath: String
        let scope: CompatibilityScope
        let layerLabel: String
    }

    private static func codexInstructionConfig(codexHome: String) -> CodexInstructionConfig {
        codexInstructionConfig(
            codexHome: codexHome,
            projectRoot: nil,
            selectedPath: nil,
            codexProfileSelection: nil,
            includeProfileFile: false,
            toolIDs: [.codexCLI, .codexDesktop]
        )
    }

    private struct CodexConfiguredInstructionFile {
        let key: String
        let configuredPath: String
        let resolvedPath: String
        let configPath: String
        let scope: CompatibilityScope
        let layerLabel: String
        let toolIDs: [CompatibilityToolID]
    }

    private static func codexInstructionConfig(
        codexHome: String,
        projectRoot: String?,
        selectedPath: String?,
        codexProfileSelection: CodexProfileSelection?,
        includeProfileFile: Bool,
        toolIDs: [CompatibilityToolID]
    ) -> CodexInstructionConfig {
        var config = CodexInstructionConfig(
            fallbackFilenames: [],
            maxBytes: 32_768,
            projectDocsDisabled: false,
            projectDocMaxBytesSource: nil,
            modelInstructionsFile: nil,
            experimentalInstructionsFile: nil
        )
        let globalConfigPath = "\(codexHome)/config.toml"
        config = applyCodexInstructionConfigLayer(
            path: globalConfigPath,
            scope: .global,
            layerLabel: "global",
            toolIDs: toolIDs,
            to: config
        )
        if includeProfileFile,
           let activeProfile = codexActiveProfileSelection(
            codexHome: codexHome,
            selection: codexProfileSelection,
            allowDefaultConfig: true
           ),
           let profilePath = codexProfileConfigPath(codexHome: codexHome, profileName: activeProfile.name) {
            let label = activeProfile.source == .cliRuntimeOverride
                ? "runtime profile \(activeProfile.name)"
                : "default profile \(activeProfile.name)"
            config = applyCodexInstructionConfigLayer(
                path: profilePath,
                scope: .global,
                layerLabel: label,
                toolIDs: [.codexCLI],
                to: config
            )
        }
        guard let projectRoot,
              codexProjectIsTrusted(codexHome: codexHome, projectRoot: projectRoot) else {
            return config
        }
        for layerRoot in codexProjectConfigLayerRoots(projectRoot: projectRoot, selectedPath: selectedPath) {
            let configPath = (layerRoot as NSString).appendingPathComponent(".codex/config.toml")
            let layerLabel = relativePath(layerRoot, from: projectRoot) ?? "project"
            config = applyCodexInstructionConfigLayer(
                path: configPath,
                scope: .project,
                layerLabel: layerRoot == projectRoot ? "project" : layerLabel,
                toolIDs: toolIDs,
                to: config
            )
        }
        return config
    }

    private static func applyCodexInstructionConfigLayer(
        path configPath: String,
        scope: CompatibilityScope,
        layerLabel: String,
        toolIDs: [CompatibilityToolID] = [.codexCLI, .codexDesktop],
        to config: CodexInstructionConfig
    ) -> CodexInstructionConfig {
        guard let raw = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return config
        }
        let document = parseSettingsTOMLDocument(raw)
        let fallbackFilenames = document.topLevelKeys.contains("project_doc_fallback_filenames")
            ? uniqueStringsPreservingOrder(codexFallbackFilenames(in: document))
            : config.fallbackFilenames
        let rawMaxBytes = document.topLevelKeys.contains("project_doc_max_bytes")
            ? (document.topLevelValues["project_doc_max_bytes"] as? Int)
            : nil
        let maxBytes: Int
        let projectDocsDisabled: Bool
        let projectDocMaxBytesSource: CodexProjectDocMaxBytesSource?
        if let rawMaxBytes {
            maxBytes = max(0, rawMaxBytes)
            projectDocsDisabled = rawMaxBytes == 0
            projectDocMaxBytesSource = CodexProjectDocMaxBytesSource(
                value: rawMaxBytes,
                configPath: configPath,
                scope: scope,
                layerLabel: layerLabel
            )
        } else if document.topLevelKeys.contains("project_doc_max_bytes") {
            maxBytes = config.maxBytes
            projectDocsDisabled = config.projectDocsDisabled
            projectDocMaxBytesSource = config.projectDocMaxBytesSource
        } else {
            maxBytes = config.maxBytes
            projectDocsDisabled = config.projectDocsDisabled
            projectDocMaxBytesSource = config.projectDocMaxBytesSource
        }
        return CodexInstructionConfig(
            fallbackFilenames: fallbackFilenames,
            maxBytes: maxBytes,
            projectDocsDisabled: projectDocsDisabled,
            projectDocMaxBytesSource: projectDocMaxBytesSource,
            modelInstructionsFile: codexConfiguredInstructionFile(
                key: "model_instructions_file",
                document: document,
                configPath: configPath,
                scope: scope,
                layerLabel: layerLabel,
                toolIDs: toolIDs
            ) ?? config.modelInstructionsFile,
            experimentalInstructionsFile: codexConfiguredInstructionFile(
                key: "experimental_instructions_file",
                document: document,
                configPath: configPath,
                scope: scope,
                layerLabel: layerLabel,
                toolIDs: toolIDs
            ) ?? config.experimentalInstructionsFile
        )
    }

    private static func codexProjectIsTrusted(codexHome: String, projectRoot: String) -> Bool {
        ConfigWriter.codexProjectTrustLevel(
            globalConfigPath: "\(codexHome)/config.toml",
            projectRoot: projectRoot
        ) == "trusted"
    }

    private static func codexConfiguredInstructionFile(
        key: String,
        document: SettingsTOMLDocument,
        configPath: String,
        scope: CompatibilityScope,
        layerLabel: String,
        toolIDs: [CompatibilityToolID]
    ) -> CodexConfiguredInstructionFile? {
        guard let raw = document.topLevelRawValues[key],
              let configuredPath = parseTOMLStringLiteral(splitTOMLValueAndComment(raw).value.trimmingCharacters(in: .whitespacesAndNewlines)),
              !configuredPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let base = (configPath as NSString).deletingLastPathComponent
        let expanded = (configuredPath as NSString).expandingTildeInPath
        let resolved = expanded.hasPrefix("/")
            ? expanded
            : (base as NSString).appendingPathComponent(expanded)
        return CodexConfiguredInstructionFile(
            key: key,
            configuredPath: configuredPath,
            resolvedPath: URL(fileURLWithPath: resolved).standardizedFileURL.path,
            configPath: configPath,
            scope: scope,
            layerLabel: layerLabel,
            toolIDs: toolIDs
        )
    }

    private static func codexFallbackFilenames(in document: SettingsTOMLDocument) -> [String] {
        guard let raw = document.topLevelRawValues["project_doc_fallback_filenames"],
              let values = parseTOMLStringArrayLiteral(raw) else { return [] }
        let cleaned = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter(isCodexFallbackFilename)
        return uniqueStringsPreservingOrder(cleaned)
    }

    private static func codexProjectDocMaxBytesMetadata(_ source: CodexProjectDocMaxBytesSource?) -> [String: String] {
        guard let source else { return [:] }
        return [
            "codexProjectDocMaxBytesConfigPath": source.configPath,
            "codexProjectDocMaxBytesScope": source.scope.rawValue,
            "codexProjectDocMaxBytesLayer": source.layerLabel,
            "codexProjectDocMaxBytesValue": "\(source.value)"
        ]
    }

    private static func isCodexFallbackFilename(_ value: String) -> Bool {
        !value.isEmpty
            && !value.contains("/")
            && !value.contains("\\")
            && value != "."
            && value != ".."
    }

    private static func codexGlobalInstructionSurfaces(codexHome: String) -> [CompatibilityMatrixEntry] {
        let candidates: [(suffix: String, filename: String, label: String, note: String, precedence: Int)] = [
            (
                "override",
                "AGENTS.override.md",
                "Codex global override instructions",
                "Codex reads this from CODEX_HOME before project guidance. When this non-empty file exists, global AGENTS.md is ignored.",
                4
            ),
            (
                "base",
                "AGENTS.md",
                "Codex global instructions",
                "Codex reads this from CODEX_HOME only when AGENTS.override.md is absent or empty.",
                5
            )
        ]
        let tools: [(CompatibilityToolID, String)] = [
            (.codexCLI, "cli"),
            (.codexDesktop, "desktop")
        ]

        return tools.flatMap { tool, toolSlug in
            candidates.map { candidate in
                CompatibilityMatrixEntry(
                    id: "codex-\(toolSlug)-global-context-\(candidate.suffix)",
                    toolID: tool,
                    kind: .context,
                    scope: .global,
                    label: tool == .codexCLI ? candidate.label : candidate.label.replacingOccurrences(of: "Codex", with: "Codex Desktop"),
                    path: "\(codexHome)/\(candidate.filename)",
                    format: .markdown,
                    fileControlled: true,
                    canWriteSafely: false,
                    writeMethod: .file,
                    requiresRestartAfterWrite: false,
                    supportsDisable: false,
                    supportsOAuth: false,
                    supportsEnvExpansion: false,
                    precedence: candidate.precedence,
                    note: candidate.note
                )
            }
        }
    }

    private static func codexConfiguredInstructionFileSurfaces(config: CodexInstructionConfig) -> [CompatibilityMatrixEntry] {
        [
            config.modelInstructionsFile,
            config.experimentalInstructionsFile
        ].compactMap { $0 }.flatMap { file in
            file.toolIDs.map { configuredCodexInstructionFileSurface(file, toolID: $0) }
        }
    }

    private static func configuredCodexInstructionFileSurface(
        _ file: CodexConfiguredInstructionFile,
        toolID: CompatibilityToolID
    ) -> CompatibilityMatrixEntry {
        let isDeprecated = file.key == "experimental_instructions_file"
        let scopeSlug = file.scope == .global ? "global" : "project"
        let toolSlug = toolID == .codexCLI ? "cli" : "desktop"
        let toolLabel = toolID == .codexCLI ? "Codex CLI" : "Codex Desktop"
        let labelLayer = file.layerLabel == "global" ? "" : " (\(file.layerLabel))"
        return CompatibilityMatrixEntry(
            id: "codex-\(toolSlug)-\(scopeSlug)-model-instructions|\(file.key)|\(file.configPath)",
            toolID: toolID,
            kind: .context,
            scope: file.scope,
            label: isDeprecated
                ? "\(toolLabel) deprecated model instructions\(labelLayer)"
                : "\(toolLabel) model instructions\(labelLayer)",
            path: file.resolvedPath,
            format: .markdown,
            fileControlled: true,
            canWriteSafely: false,
            writeMethod: .file,
            requiresRestartAfterWrite: true,
            supportsDisable: false,
            supportsOAuth: false,
            supportsEnvExpansion: false,
            precedence: file.scope == .global ? 6 : 18,
            note: isDeprecated
                ? "Deprecated Codex instruction override from \(file.key) in \(tilde(file.configPath)); rename the key to model_instructions_file."
                : "Codex model instruction override from \(file.key) in \(tilde(file.configPath)). Use AGENTS.md for normal project guidance."
        )
    }

    private static func codexRepositorySkillSurfaces(start: String) -> [CompatibilityMatrixEntry] {
        let repoRoot = nearestRepositoryRoot(from: start) ?? start
        let startURL = URL(fileURLWithPath: expandedPath(start))
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let stopURL = URL(fileURLWithPath: Project.canonicalize(repoRoot))
        var directories: [URL] = []
        var current = startURL

        while true {
            directories.append(current)
            if current.path == stopURL.path { break }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }

        return directories.enumerated().map { index, directory in
            [
                CompatibilityMatrixEntry(
                    id: "codex-cli-project-skills|\(directory.path)",
                    toolID: .codexCLI,
                    kind: .skills,
                    scope: .project,
                    label: index == 0 ? "Codex CLI working-directory skills" : "Codex CLI parent-directory skills",
                    path: directory.appendingPathComponent(".agents/skills").path,
                    format: .directory,
                    fileControlled: true,
                    canWriteSafely: true,
                    writeMethod: .file,
                    requiresRestartAfterWrite: true,
                    supportsDisable: false,
                    supportsOAuth: false,
                    supportsEnvExpansion: false,
                    precedence: 20 + index,
                    note: "Codex CLI scans .agents/skills from the working directory up to the repository root."
                ),
                CompatibilityMatrixEntry(
                    id: "codex-desktop-project-skills|\(directory.path)",
                    toolID: .codexDesktop,
                    kind: .skills,
                    scope: .project,
                    label: index == 0 ? "Codex Desktop working-directory skills" : "Codex Desktop parent-directory skills",
                    path: directory.appendingPathComponent(".agents/skills").path,
                    format: .directory,
                    fileControlled: true,
                    canWriteSafely: true,
                    writeMethod: .file,
                    requiresRestartAfterWrite: true,
                    supportsDisable: false,
                    supportsOAuth: false,
                    supportsEnvExpansion: false,
                    precedence: 20 + index,
                    note: "Codex Desktop app sessions share Codex .agents/skills discovery for the selected workspace."
                )
            ]
        }
        .flatMap { $0 }
    }

    private static func claudeRepositorySkillSurfaces(start: String) -> [CompatibilityMatrixEntry] {
        let repoRoot = nearestRepositoryRoot(from: start) ?? start
        let startURL = URL(fileURLWithPath: expandedPath(start))
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let stopURL = URL(fileURLWithPath: Project.canonicalize(repoRoot))
        var directories: [URL] = []
        var current = startURL

        while true {
            directories.append(current)
            if current.path == stopURL.path { break }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }

        let upwardPaths = Set(directories.map { $0.appendingPathComponent(".claude/skills").path })
        let upwardSurfaces = directories.enumerated().map { index, directory in
            CompatibilityMatrixEntry(
                id: "claude-code-project-skills|\(directory.path)",
                toolID: .claudeCode,
                kind: .skills,
                scope: .project,
                label: index == 0 ? "Claude Code working-directory skills" : "Claude Code parent-directory skills",
                path: directory.appendingPathComponent(".claude/skills").path,
                format: .directory,
                fileControlled: true,
                canWriteSafely: true,
                writeMethod: .file,
                requiresRestartAfterWrite: false,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: false,
                precedence: 20 + index,
                note: "Claude Code scans .claude/skills from the starting directory up to the repository root and live-watches existing skill directories."
            )
        }
        let nestedSurfaces = existingClaudeNestedSkillRoots(from: startURL, excluding: upwardPaths)
            .enumerated()
            .map { index, skillsRoot in
                CompatibilityMatrixEntry(
                    id: "claude-code-nested-project-skills|\(skillsRoot.path)",
                    toolID: .claudeCode,
                    kind: .skills,
                    scope: .project,
                    label: "Claude Code nested skills",
                    path: skillsRoot.path,
                    format: .directory,
                    fileControlled: true,
                    canWriteSafely: true,
                    writeMethod: .file,
                    requiresRestartAfterWrite: false,
                    supportsDisable: false,
                    supportsOAuth: false,
                    supportsEnvExpansion: false,
                    precedence: 40 + index,
                    note: "Claude Code discovers nested .claude/skills directories below the starting directory when working in those subtrees and live-watches existing skill files."
                )
            }
        return upwardSurfaces + nestedSurfaces
    }

    private static func existingClaudeNestedSkillRoots(from startURL: URL, excluding excludedPaths: Set<String>) -> [URL] {
        KnownSkillRoots.existingNestedClaudeSkillDirectories(
            from: startURL,
            excluding: excludedPaths
        )
    }

    private static let claudePluginSkillSurfacePrefix = "claude-code-plugin-skills|"
    private static let claudePluginMCPSurfacePrefix = "claude-code-plugin-mcp|"
    private static let codexPluginSkillSurfacePrefix = "codex-plugin-skills|"
    private static let codexPluginMCPSurfacePrefix = "codex-plugin-mcp|"
    private static let codexPluginManifestSurfacePrefix = "codex-plugin-manifest|"
    private static let codexPluginMarketplaceSurfacePrefix = "codex-plugin-marketplace|"

    private static func claudePluginSkillSurfaces(claudeHome: String, projectRoot: String?) -> [CompatibilityMatrixEntry] {
        var surfaces: [CompatibilityMatrixEntry] = []
        var seen = Set<String>()

        for plugin in claudeInstalledPlugins(claudeHome: claudeHome, projectRoot: projectRoot) {
            for root in claudePluginSkillRoots(installPath: plugin.installPath) {
                let canonicalRoot = expandedPath(root)
                let key = "\(plugin.id)|\(canonicalRoot)"
                guard seen.insert(key).inserted else { continue }
                surfaces.append(.init(
                    id: "\(claudePluginSkillSurfacePrefix)\(plugin.id)|\(plugin.enabled ? "enabled" : "disabled")|\(canonicalRoot)",
                    toolID: .claudeCode,
                    kind: .skills,
                    scope: claudePluginScope(plugin.scope),
                    label: "Claude Code plugin skills",
                    path: canonicalRoot,
                    format: .directory,
                    fileControlled: true,
                    canWriteSafely: false,
                    writeMethod: .appUI,
                    requiresRestartAfterWrite: true,
                    supportsDisable: true,
                    supportsOAuth: false,
                    supportsEnvExpansion: false,
                    precedence: 50 + surfaces.count,
                    note: "Plugin-managed skills from \(plugin.id)\(plugin.version.map { " \($0)" } ?? ""). Use Claude Code plugin commands or /reload-plugins after plugin changes."
                ))
            }
        }

        return surfaces
    }

    private static func claudePluginMCPSurfaces(claudeHome: String, projectRoot: String?) -> [CompatibilityMatrixEntry] {
        var surfaces: [CompatibilityMatrixEntry] = []
        var seen = Set<String>()

        for plugin in claudeInstalledPlugins(claudeHome: claudeHome, projectRoot: projectRoot) {
            for path in claudePluginMCPConfigPaths(installPath: plugin.installPath) {
                let canonicalPath = expandedPath(path)
                let key = "\(plugin.id)|\(canonicalPath)"
                guard seen.insert(key).inserted else { continue }
                surfaces.append(.init(
                    id: "\(claudePluginMCPSurfacePrefix)\(plugin.id)|\(plugin.enabled ? "enabled" : "disabled")|\(canonicalPath)",
                    toolID: .claudeCode,
                    kind: .mcp,
                    scope: claudePluginScope(plugin.scope),
                    label: "Claude Code plugin MCP",
                    path: canonicalPath,
                    format: .jsonc,
                    fileControlled: true,
                    canWriteSafely: false,
                    writeMethod: .appUI,
                    requiresRestartAfterWrite: true,
                    supportsDisable: true,
                    supportsOAuth: true,
                    supportsEnvExpansion: true,
                    precedence: 12 + surfaces.count,
                    note: "Plugin-managed MCP servers from \(plugin.id)\(plugin.version.map { " \($0)" } ?? ""). Use Claude Code plugin commands or /reload-plugins after plugin changes."
                ))
            }
        }

        return surfaces
    }

    private static func codexPluginSkillSurfaces(
        codexHome: String,
        codexProfileSelection: CodexProfileSelection?
    ) -> [CompatibilityMatrixEntry] {
        var surfaces: [CompatibilityMatrixEntry] = []
        var seen = Set<String>()

        for toolID in [CompatibilityToolID.codexCLI, .codexDesktop] {
            for plugin in codexInstalledPlugins(
                codexHome: codexHome,
                toolID: toolID,
                codexProfileSelection: codexProfileSelection
            ) {
                for root in codexPluginSkillRoots(installPath: plugin.installPath) {
                    let canonicalRoot = expandedPath(root)
                    let key = "\(plugin.id)|\(canonicalRoot)|\(toolID.rawValue)"
                    guard seen.insert(key).inserted else { continue }
                    let toolLabel = toolID == .codexCLI ? "Codex CLI" : "Codex Desktop"
                    surfaces.append(.init(
                        id: "\(codexPluginSkillSurfacePrefix)\(plugin.id)|\(plugin.enabled ? "enabled" : "disabled")|\(toolID.rawValue)|\(canonicalRoot)",
                        toolID: toolID,
                        kind: .skills,
                        scope: .global,
                        label: "\(toolLabel) plugin skills",
                        path: canonicalRoot,
                        format: .directory,
                        fileControlled: true,
                        canWriteSafely: false,
                        writeMethod: .appUI,
                        requiresRestartAfterWrite: true,
                        supportsDisable: true,
                        supportsOAuth: false,
                        supportsEnvExpansion: false,
                        precedence: 50 + surfaces.count,
                        note: "Plugin-managed skills from \(plugin.id) \(plugin.version). Configure plugin enablement in Codex config; restart Codex after plugin policy changes."
                    ))
                }
            }
        }

        return surfaces
    }

    private static func codexPluginMCPSurfaces(
        codexHome: String,
        projectRoot: String?,
        codexProfileSelection: CodexProfileSelection?
    ) -> [CompatibilityMatrixEntry] {
        var surfaces: [CompatibilityMatrixEntry] = []
        var seen = Set<String>()

        for toolID in [CompatibilityToolID.codexCLI, .codexDesktop] {
            for plugin in codexInstalledPlugins(
                codexHome: codexHome,
                toolID: toolID,
                codexProfileSelection: codexProfileSelection
            ) {
                for path in codexPluginMCPConfigPaths(installPath: plugin.installPath) {
                    let canonicalPath = expandedPath(path)
                    let projectToken = projectRoot ?? "__none__"
                    let key = "\(plugin.id)|\(canonicalPath)|\(toolID.rawValue)|\(projectToken)"
                    guard seen.insert(key).inserted else { continue }
                    let toolLabel = toolID == .codexCLI ? "Codex CLI" : "Codex Desktop"
                    surfaces.append(.init(
                        id: "\(codexPluginMCPSurfacePrefix)\(plugin.id)|\(plugin.enabled ? "enabled" : "disabled")|\(toolID.rawValue)|\(projectToken)|\(canonicalPath)",
                        toolID: toolID,
                        kind: .mcp,
                        scope: .global,
                        label: "\(toolLabel) plugin MCP",
                        path: canonicalPath,
                        format: .jsonc,
                        fileControlled: true,
                        canWriteSafely: false,
                        writeMethod: .appUI,
                        requiresRestartAfterWrite: true,
                        supportsDisable: true,
                        supportsOAuth: true,
                        supportsEnvExpansion: true,
                        precedence: 12 + surfaces.count,
                        note: "Plugin-managed MCP servers from \(plugin.id) \(plugin.version). Configure enablement and tool policy in Codex config; restart Codex after plugin policy changes."
                    ))
                }
            }
        }

        return surfaces
    }

    private static func codexPluginManifestSurfaces(
        codexHome: String,
        codexProfileSelection: CodexProfileSelection?
    ) -> [CompatibilityMatrixEntry] {
        [CompatibilityToolID.codexCLI, .codexDesktop].flatMap { toolID in
            codexInstalledPlugins(
                codexHome: codexHome,
                toolID: toolID,
                codexProfileSelection: codexProfileSelection
            ).map { plugin in
                let manifestPath = (plugin.installPath as NSString)
                    .appendingPathComponent(".codex-plugin/plugin.json")
                let toolLabel = toolID == .codexCLI ? "Codex CLI" : "Codex Desktop"
                return CompatibilityMatrixEntry(
                    id: "\(codexPluginManifestSurfacePrefix)\(plugin.id)|\(plugin.enabled ? "enabled" : "disabled")|\(toolID.rawValue)|\(manifestPath)",
                    toolID: toolID,
                    kind: .settings,
                    scope: .global,
                    label: "\(toolLabel) plugin manifest",
                    path: manifestPath,
                    format: .jsonc,
                    fileControlled: true,
                    canWriteSafely: false,
                    writeMethod: .unsupported,
                    requiresRestartAfterWrite: true,
                    supportsDisable: true,
                    supportsOAuth: true,
                    supportsEnvExpansion: true,
                    precedence: 12,
                    note: "Installed Codex plugin manifest for \(plugin.id) \(plugin.version). Codex loads plugin components from the installed cache copy."
                )
            }
        }
    }

    private static func codexPluginMarketplaceSurfaces(home: String, projectRoot: String?) -> [CompatibilityMatrixEntry] {
        var surfaces: [CompatibilityMatrixEntry] = []
        let agentsHome = ProcessInfo.processInfo.environment["PROJECTHUB_AGENTS_HOME"] ?? "\(home)/.agents"

        surfaces.append(contentsOf: codexPluginMarketplaceSurfaces(
            id: "personal",
            scope: .global,
            label: "Codex personal plugin marketplace",
            path: "\(agentsHome)/plugins/marketplace.json",
            note: "Personal Codex plugin marketplace. Installed plugins still load from the Codex plugin cache."
        ))

        if let projectRoot {
            surfaces.append(contentsOf: codexPluginMarketplaceSurfaces(
                id: "project",
                scope: .project,
                label: "Codex project plugin marketplace",
                path: "\(projectRoot)/.agents/plugins/marketplace.json",
                note: "Repository plugin marketplace for Codex plugin discovery in this project."
            ))
            surfaces.append(contentsOf: codexPluginMarketplaceSurfaces(
                id: "legacy-project",
                scope: .project,
                label: "Codex legacy plugin marketplace",
                path: "\(projectRoot)/.claude-plugin/marketplace.json",
                note: "Legacy-compatible repository plugin marketplace that Codex can read."
            ))
        }

        return surfaces
    }

    private static func codexPluginMarketplaceSurfaces(
        id: String,
        scope: CompatibilityScope,
        label: String,
        path: String,
        note: String
    ) -> [CompatibilityMatrixEntry] {
        [CompatibilityToolID.codexCLI, .codexDesktop].map { toolID in
            let toolLabel = toolID == .codexCLI ? "Codex CLI" : "Codex Desktop"
            return CompatibilityMatrixEntry(
                id: "\(codexPluginMarketplaceSurfacePrefix)\(id)|\(toolID.rawValue)",
                toolID: toolID,
                kind: .settings,
                scope: scope,
                label: "\(toolLabel) \(label.dropFirst("Codex ".count))",
                path: path,
                format: .jsonc,
                fileControlled: true,
                canWriteSafely: false,
                writeMethod: .unsupported,
                requiresRestartAfterWrite: true,
                supportsDisable: false,
                supportsOAuth: false,
                supportsEnvExpansion: true,
                precedence: 13,
                note: note
            )
        }
    }

    private struct ClaudeInstalledPlugin {
        let id: String
        let scope: String
        let installPath: String
        let version: String?
        let enabled: Bool
    }

    private struct CodexInstalledPlugin {
        let id: String
        let installPath: String
        let version: String
        let enabled: Bool
    }

    private struct PluginRead {
        var plugins: [CompatibilityPluginObservation]
        var issues: [CompatibilityIssue]
    }

    private struct PluginConfigState {
        let pluginID: String
        let enabled: Bool
        let sourcePath: String
        let profileName: String?
    }

    private struct CodexCachedPlugin {
        let id: String
        let name: String
        let marketplace: String
        let version: String
        let installPath: String
    }

    private struct MarketplacePluginEntry {
        let name: String
        let path: String?
        let version: String?
        let detail: String?
    }

    private static func readPlugins(
        from matrix: [CompatibilityMatrixEntry],
        projectRoot: String?,
        codexProfileSelection: CodexProfileSelection?
    ) -> PluginRead {
        let home = NSHomeDirectory()
        let codexHome = ProjectHubPaths.codexHome(home: home)
        let claudeHome = claudeHomeDirectory(home: home)
        let codexStates = codexConfiguredPluginStatesByTool(
            codexHome: codexHome,
            codexProfileSelection: codexProfileSelection
        )
        let codexCache = codexCachedPlugins(codexHome: codexHome)
        let codexCacheIDs = Set(codexCache.map(\.id))
        var plugins: [CompatibilityPluginObservation] = []
        var issues: [CompatibilityIssue] = []

        for toolID in [CompatibilityToolID.codexCLI, .codexDesktop] {
            let states = codexStates[toolID] ?? [:]
            for cached in codexCache {
                let state = states[cached.id]
                plugins.append(codexPluginObservation(
                    cached,
                    toolID: toolID,
                    enabled: state?.enabled,
                    sourcePath: state?.sourcePath
                ))
            }
            for state in states.values.sorted(by: { $0.pluginID < $1.pluginID }) where !codexCacheIDs.contains(state.pluginID) {
                plugins.append(codexConfiguredMissingPluginObservation(state, toolID: toolID))
                if state.enabled {
                    issues.append(configuredPluginMissingIssue(
                        pluginID: state.pluginID,
                        toolID: toolID,
                        sourcePath: state.sourcePath,
                        surface: matrix.first { $0.toolID == toolID && $0.kind == .settings && $0.path == state.sourcePath },
                        owner: "Codex"
                    ))
                }
            }
        }

        plugins.append(contentsOf: codexMarketplaceConfigPluginObservations(
            codexHome: codexHome,
            codexProfileSelection: codexProfileSelection
        ))
        plugins.append(contentsOf: codexMarketplaceFilePluginObservations(from: matrix))

        let claudeInstalled = claudeInstalledPlugins(claudeHome: claudeHome, projectRoot: projectRoot)
        let claudeInstalledIDs = Set(claudeInstalled.map(\.id))
        for plugin in claudeInstalled {
            plugins.append(claudeInstalledPluginObservation(plugin))
        }
        plugins.append(contentsOf: claudeSkillsDirectoryPluginObservations(claudeHome: claudeHome, installedIDs: claudeInstalledIDs))
        let claudeSettingsRead = claudeSettingsPluginObservations(from: matrix, installedIDs: claudeInstalledIDs)
        plugins.append(contentsOf: claudeSettingsRead.plugins)
        issues.append(contentsOf: claudeSettingsRead.issues)
        plugins.append(contentsOf: claudeMarketplaceDirectoryPluginObservations(claudeHome: claudeHome, installedIDs: claudeInstalledIDs))

        var seen = Set<String>()
        let unique = plugins
            .filter { seen.insert($0.id).inserted }
            .sorted { lhs, rhs in
                if lhs.toolID.rawValue != rhs.toolID.rawValue { return lhs.toolID.rawValue < rhs.toolID.rawValue }
                if lhs.scope.rawValue != rhs.scope.rawValue { return lhs.scope.rawValue < rhs.scope.rawValue }
                if lhs.pluginID.localizedCaseInsensitiveCompare(rhs.pluginID) != .orderedSame {
                    return lhs.pluginID.localizedCaseInsensitiveCompare(rhs.pluginID) == .orderedAscending
                }
                return lhs.installMethod.rawValue < rhs.installMethod.rawValue
            }

        return PluginRead(plugins: unique, issues: issues)
    }

    private static func codexPluginObservation(
        _ plugin: CodexCachedPlugin,
        toolID: CompatibilityToolID,
        enabled: Bool?,
        sourcePath: String?
    ) -> CompatibilityPluginObservation {
        let components = codexPluginComponents(installPath: plugin.installPath)
        return CompatibilityPluginObservation(
            id: "codex-cache|\(toolID.rawValue)|\(plugin.id)|\(plugin.version)|\(plugin.installPath)",
            toolID: toolID,
            pluginID: plugin.id,
            name: plugin.name,
            marketplace: plugin.marketplace,
            version: plugin.version,
            scope: .global,
            installMethod: .codexCache,
            installPath: plugin.installPath,
            sourcePath: sourcePath,
            enabled: enabled,
            components: components,
            summary: pluginObservationSummary(method: .codexCache, enabled: enabled, components: components),
            requiresRestartAfterWrite: true
        )
    }

    private static func codexConfiguredMissingPluginObservation(
        _ state: PluginConfigState,
        toolID: CompatibilityToolID
    ) -> CompatibilityPluginObservation {
        let parts = codexPluginIDParts(state.pluginID)
        return CompatibilityPluginObservation(
            id: "codex-config|\(toolID.rawValue)|\(state.pluginID)|\(state.sourcePath)|\(state.profileName ?? "default")",
            toolID: toolID,
            pluginID: state.pluginID,
            name: parts?.name ?? state.pluginID,
            marketplace: parts?.marketplace,
            version: nil,
            scope: .global,
            installMethod: .codexConfig,
            installPath: nil,
            sourcePath: state.sourcePath,
            enabled: state.enabled,
            components: [],
            summary: state.enabled ? "Configured but not installed in the local plugin cache" : "Disabled configuration without a local cache entry",
            requiresRestartAfterWrite: true
        )
    }

    private static func codexConfiguredPluginStatesByTool(
        codexHome: String,
        codexProfileSelection: CodexProfileSelection?
    ) -> [CompatibilityToolID: [String: PluginConfigState]] {
        let globalConfigPath = (codexHome as NSString).appendingPathComponent("config.toml")
        var states: [CompatibilityToolID: [String: PluginConfigState]] = [:]
        if let raw = try? String(contentsOfFile: globalConfigPath, encoding: .utf8) {
            let document = parseSettingsTOMLDocument(raw)
            let global = codexPluginConfigStates(document, sourcePath: globalConfigPath, profileName: nil)
            states[.codexCLI, default: [:]].merge(global) { _, new in new }
            states[.codexDesktop, default: [:]].merge(global) { _, new in new }
        }
        if let activeProfile = codexActiveProfileSelection(
            codexHome: codexHome,
            selection: codexProfileSelection,
            allowDefaultConfig: true
        ),
           let profilePath = codexProfileConfigPath(codexHome: codexHome, profileName: activeProfile.name),
           let raw = try? String(contentsOfFile: profilePath, encoding: .utf8) {
            let document = parseSettingsTOMLDocument(raw)
            states[.codexCLI, default: [:]].merge(codexPluginConfigStates(
                document,
                sourcePath: profilePath,
                profileName: activeProfile.name
            )) { _, new in new }
        }
        return states
    }

    private static func codexPluginConfigStates(
        _ document: SettingsTOMLDocument,
        sourcePath: String,
        profileName: String?
    ) -> [String: PluginConfigState] {
        var states: [String: PluginConfigState] = [:]
        for (section, values) in document.sectionValues {
            let segments = tomlSectionSegments(section)
            guard segments.count >= 2, segments[0] == "plugins" else { continue }
            let pluginID = segments[1]
            if states[pluginID] == nil {
                states[pluginID] = PluginConfigState(
                    pluginID: pluginID,
                    enabled: true,
                    sourcePath: sourcePath,
                    profileName: profileName
                )
            }
            if segments.count == 2, let enabled = boolSettingValue(values["enabled"]) {
                states[pluginID] = PluginConfigState(
                    pluginID: pluginID,
                    enabled: enabled,
                    sourcePath: sourcePath,
                    profileName: profileName
                )
            }
        }
        return states
    }

    private static func codexCachedPlugins(codexHome: String) -> [CodexCachedPlugin] {
        let cacheRoot = ((codexHome as NSString).appendingPathComponent("plugins/cache") as NSString)
            .expandingTildeInPath
        let fm = FileManager.default
        guard let marketplaces = try? fm.contentsOfDirectory(atPath: cacheRoot) else { return [] }
        var plugins: [CodexCachedPlugin] = []
        for marketplace in marketplaces.sorted() where !marketplace.hasPrefix(".") {
            let marketplaceRoot = (cacheRoot as NSString).appendingPathComponent(marketplace)
            guard let names = try? fm.contentsOfDirectory(atPath: marketplaceRoot) else { continue }
            for name in names.sorted() where !name.hasPrefix(".") {
                let pluginRoot = (marketplaceRoot as NSString).appendingPathComponent(name)
                guard let versions = try? fm.contentsOfDirectory(atPath: pluginRoot) else { continue }
                for version in versions.sorted() where !version.hasPrefix(".") {
                    let installPath = (pluginRoot as NSString).appendingPathComponent(version)
                    let manifestPath = (installPath as NSString).appendingPathComponent(".codex-plugin/plugin.json")
                    guard fileExists(manifestPath) else { continue }
                    plugins.append(.init(
                        id: "\(name)@\(marketplace)",
                        name: name,
                        marketplace: marketplace,
                        version: version,
                        installPath: expandedPath(installPath)
                    ))
                }
            }
        }
        return plugins
    }

    private static func codexMarketplaceConfigPluginObservations(
        codexHome: String,
        codexProfileSelection: CodexProfileSelection?
    ) -> [CompatibilityPluginObservation] {
        let globalConfigPath = (codexHome as NSString).appendingPathComponent("config.toml")
        var observations: [CompatibilityPluginObservation] = []
        observations.append(contentsOf: codexMarketplaceConfigPluginObservations(
            path: globalConfigPath,
            toolIDs: [.codexCLI, .codexDesktop],
            scope: .global
        ))
        if let activeProfile = codexActiveProfileSelection(
            codexHome: codexHome,
            selection: codexProfileSelection,
            allowDefaultConfig: true
        ),
           let profilePath = codexProfileConfigPath(codexHome: codexHome, profileName: activeProfile.name) {
            observations.append(contentsOf: codexMarketplaceConfigPluginObservations(
                path: profilePath,
                toolIDs: [.codexCLI],
                scope: .global
            ))
        }
        return observations
    }

    private static func codexMarketplaceConfigPluginObservations(
        path: String,
        toolIDs: [CompatibilityToolID],
        scope: CompatibilityScope
    ) -> [CompatibilityPluginObservation] {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        let document = parseSettingsTOMLDocument(raw)
        var output: [CompatibilityPluginObservation] = []
        for (section, values) in document.sectionValues.sorted(by: { $0.key < $1.key }) {
            let segments = tomlSectionSegments(section)
            guard segments.count == 2, segments[0] == "marketplaces" else { continue }
            let marketplace = segments[1]
            let source = stringFromAny(values["source"])
                ?? stringFromAny(values["path"])
                ?? stringFromAny(values["url"])
            for toolID in toolIDs {
                output.append(CompatibilityPluginObservation(
                    id: "codex-marketplace-config|\(toolID.rawValue)|\(marketplace)|\(path)",
                    toolID: toolID,
                    pluginID: "marketplace:\(marketplace)",
                    name: "\(marketplace) marketplace",
                    marketplace: marketplace,
                    version: nil,
                    scope: scope,
                    installMethod: .codexMarketplaceConfig,
                    installPath: source,
                    sourcePath: path,
                    enabled: nil,
                    components: ["source"],
                    summary: source.map { "Marketplace source: \($0)" } ?? "Marketplace source configured",
                    requiresRestartAfterWrite: true
                ))
            }
        }
        return output
    }

    private static func codexMarketplaceFilePluginObservations(
        from matrix: [CompatibilityMatrixEntry]
    ) -> [CompatibilityPluginObservation] {
        var observations: [CompatibilityPluginObservation] = []
        for surface in matrix where isCodexPluginMarketplaceSurface(surface) {
            guard let path = surface.path,
                  let root = readJSONDictionary(at: path) else { continue }
            let marketplace = codexMarketplaceName(from: surface)
            let entries = marketplacePluginEntries(from: root)
            for entry in entries {
                let resolvedPath = entry.path.map {
                    resolveMarketplaceEntryPath($0, marketplacePath: path)
                }
                observations.append(CompatibilityPluginObservation(
                    id: "codex-marketplace-file|\(surface.toolID.rawValue)|\(surface.id)|\(entry.name)|\(entry.path ?? "")",
                    toolID: surface.toolID,
                    pluginID: entry.name.contains("@") ? entry.name : "\(entry.name)@\(marketplace)",
                    name: entry.name,
                    marketplace: marketplace,
                    version: entry.version,
                    scope: surface.scope,
                    installMethod: .codexMarketplaceFile,
                    installPath: resolvedPath,
                    sourcePath: path,
                    enabled: nil,
                    components: [],
                    summary: entry.detail ?? "Declared in \(surface.label.lowercased())",
                    requiresRestartAfterWrite: true
                ))
            }
        }
        return observations
    }

    private static func claudeInstalledPluginObservation(
        _ plugin: ClaudeInstalledPlugin
    ) -> CompatibilityPluginObservation {
        let components = claudePluginComponents(installPath: plugin.installPath)
        let parts = pluginIDParts(plugin.id)
        return CompatibilityPluginObservation(
            id: "claude-installed|\(plugin.scope)|\(plugin.id)|\(plugin.installPath)",
            toolID: .claudeCode,
            pluginID: plugin.id,
            name: parts.name,
            marketplace: parts.marketplace,
            version: plugin.version,
            scope: claudePluginScope(plugin.scope),
            installMethod: .claudeInstalledInventory,
            installPath: plugin.installPath,
            sourcePath: nil,
            enabled: plugin.enabled,
            components: components,
            summary: pluginObservationSummary(method: .claudeInstalledInventory, enabled: plugin.enabled, components: components),
            requiresRestartAfterWrite: true
        )
    }

    private static func claudeSettingsPluginObservations(
        from matrix: [CompatibilityMatrixEntry],
        installedIDs: Set<String>
    ) -> PluginRead {
        var observations: [CompatibilityPluginObservation] = []
        var issues: [CompatibilityIssue] = []
        for surface in matrix where surface.toolID == .claudeCode && surface.kind == .settings {
            guard let path = surface.path,
                  let root = settingsDictionary(for: surface, path: path) else { continue }
            if let enabledPlugins = root["enabledPlugins"] as? [String: Any] {
                for pluginID in enabledPlugins.keys.sorted() {
                    guard !installedIDs.contains(pluginID) else { continue }
                    let enabled = boolSettingValue(enabledPlugins[pluginID])
                    let parts = pluginIDParts(pluginID)
                    observations.append(CompatibilityPluginObservation(
                        id: "claude-settings|\(surface.id)|\(pluginID)",
                        toolID: .claudeCode,
                        pluginID: pluginID,
                        name: parts.name,
                        marketplace: parts.marketplace,
                        version: nil,
                        scope: surface.scope,
                        installMethod: .claudeSettings,
                        installPath: nil,
                        sourcePath: path,
                        enabled: enabled,
                        components: [],
                        summary: enabled == false ? "Disabled in Claude settings" : "Enabled in Claude settings but not present in installed plugin inventory",
                        requiresRestartAfterWrite: true
                    ))
                    if enabled != false {
                        issues.append(configuredPluginMissingIssue(
                            pluginID: pluginID,
                            toolID: .claudeCode,
                            sourcePath: path,
                            surface: surface,
                            owner: "Claude Code"
                        ))
                    }
                }
            }
            if let rawMarketplaces = root["extraKnownMarketplaces"] {
                for entry in claudeKnownMarketplaceEntries(from: rawMarketplaces) {
                    observations.append(CompatibilityPluginObservation(
                        id: "claude-known-marketplace|\(surface.id)|\(entry.name)|\(entry.path ?? entry.detail ?? "")",
                        toolID: .claudeCode,
                        pluginID: "marketplace:\(entry.name)",
                        name: "\(entry.name) marketplace",
                        marketplace: entry.name,
                        version: entry.version,
                        scope: surface.scope,
                        installMethod: .claudeKnownMarketplace,
                        installPath: entry.path,
                        sourcePath: path,
                        enabled: nil,
                        components: entry.detail.map { [$0] } ?? ["source"],
                        summary: entry.path.map { "Known marketplace source: \($0)" } ?? "Known marketplace source configured",
                        requiresRestartAfterWrite: true
                    ))
                }
            }
        }
        return PluginRead(plugins: observations, issues: issues)
    }

    private static func claudeSkillsDirectoryPluginObservations(
        claudeHome: String,
        installedIDs: Set<String>
    ) -> [CompatibilityPluginObservation] {
        let skillsRoot = (claudeHome as NSString).appendingPathComponent("skills")
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: skillsRoot) else { return [] }
        return entries.sorted().compactMap { entry -> CompatibilityPluginObservation? in
            guard !entry.hasPrefix(".") else { return nil }
            let pluginRoot = (skillsRoot as NSString).appendingPathComponent(entry)
            let manifestPath = (pluginRoot as NSString).appendingPathComponent(".claude-plugin/plugin.json")
            guard fileExists(manifestPath) else { return nil }
            let name = manifestPluginName(path: manifestPath, fallback: entry)
            let pluginID = "\(name)@skills-dir"
            guard !installedIDs.contains(pluginID) else { return nil }
            let components = claudePluginComponents(installPath: pluginRoot)
            return CompatibilityPluginObservation(
                id: "claude-skills-dir|\(pluginID)|\(pluginRoot)",
                toolID: .claudeCode,
                pluginID: pluginID,
                name: name,
                marketplace: "skills-dir",
                version: manifestPluginVersion(path: manifestPath),
                scope: .global,
                installMethod: .claudeSkillsDirectory,
                installPath: expandedPath(pluginRoot),
                sourcePath: manifestPath,
                enabled: true,
                components: components,
                summary: pluginObservationSummary(method: .claudeSkillsDirectory, enabled: true, components: components),
                requiresRestartAfterWrite: true
            )
        }
    }

    private static func claudeMarketplaceDirectoryPluginObservations(
        claudeHome: String,
        installedIDs: Set<String>
    ) -> [CompatibilityPluginObservation] {
        let marketplacesRoot = (claudeHome as NSString).appendingPathComponent("plugins/marketplaces")
        let manifestPaths = pluginManifestPaths(
            under: marketplacesRoot,
            markerDirectory: ".claude-plugin",
            maxDepth: 4
        )
        return manifestPaths.compactMap { manifestPath -> CompatibilityPluginObservation? in
            let pluginRoot = URL(fileURLWithPath: manifestPath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .path
            let name = manifestPluginName(path: manifestPath, fallback: URL(fileURLWithPath: pluginRoot).lastPathComponent)
            let marketplace = claudeMarketplaceName(pluginRoot: pluginRoot, marketplacesRoot: marketplacesRoot)
            let pluginID = "\(name)@\(marketplace)"
            guard !installedIDs.contains(pluginID) else { return nil }
            let components = claudePluginComponents(installPath: pluginRoot)
            return CompatibilityPluginObservation(
                id: "claude-marketplace-dir|\(pluginID)|\(pluginRoot)",
                toolID: .claudeCode,
                pluginID: pluginID,
                name: name,
                marketplace: marketplace,
                version: manifestPluginVersion(path: manifestPath),
                scope: .global,
                installMethod: .claudeMarketplaceDirectory,
                installPath: expandedPath(pluginRoot),
                sourcePath: manifestPath,
                enabled: nil,
                components: components,
                summary: pluginObservationSummary(method: .claudeMarketplaceDirectory, enabled: nil, components: components),
                requiresRestartAfterWrite: true
            )
        }
    }

    private static func configuredPluginMissingIssue(
        pluginID: String,
        toolID: CompatibilityToolID,
        sourcePath: String,
        surface: CompatibilityMatrixEntry?,
        owner: String
    ) -> CompatibilityIssue {
        CompatibilityIssue(
            id: UUID(),
            code: .configMissing,
            severity: .warning,
            toolID: toolID,
            surfaceID: surface?.id,
            title: "\(owner) plugin configured but not installed",
            detail: "\(pluginID) is enabled in \(tilde(sourcePath)), but Project Hub could not find a matching installed plugin manifest in the local plugin cache/inventory.",
            path: sourcePath,
            subjectPath: pluginID,
            fixHint: "Install or update \(pluginID) with the target tool's plugin command or marketplace UI, or remove the stale enabled plugin setting.",
            metadata: ["pluginID": pluginID]
        )
    }

    private static func pluginObservationSummary(
        method: CompatibilityPluginInstallMethod,
        enabled: Bool?,
        components: [String]
    ) -> String {
        var parts: [String] = [method.label]
        if let enabled {
            parts.append(enabled ? "enabled" : "disabled")
        }
        if !components.isEmpty {
            parts.append(components.joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }

    private static func codexPluginComponents(installPath: String) -> [String] {
        let manifestPath = (installPath as NSString).appendingPathComponent(".codex-plugin/plugin.json")
        let manifest = readJSONDictionary(at: manifestPath) ?? [:]
        var components: [String] = []
        if manifest["mcpServers"] != nil || fileExists((installPath as NSString).appendingPathComponent(".mcp.json")) {
            components.append("MCP")
        }
        if manifest["skills"] != nil || directoryExists((installPath as NSString).appendingPathComponent("skills")) {
            components.append("skills")
        }
        if manifest["hooks"] != nil || fileExists((installPath as NSString).appendingPathComponent("hooks/hooks.json")) {
            components.append("hooks")
        }
        if manifest["apps"] != nil || fileExists((installPath as NSString).appendingPathComponent(".app.json")) {
            components.append("apps")
        }
        if manifest["interface"] != nil { components.append("interface") }
        return uniqueStringsPreservingOrder(components)
    }

    private static func claudePluginComponents(installPath: String) -> [String] {
        let manifestPath = (installPath as NSString).appendingPathComponent(".claude-plugin/plugin.json")
        let manifest = readJSONDictionary(at: manifestPath) ?? [:]
        var components: [String] = []
        if manifest["mcpServers"] != nil || fileExists((installPath as NSString).appendingPathComponent(".mcp.json")) {
            components.append("MCP")
        }
        if manifest["skills"] != nil || directoryExists((installPath as NSString).appendingPathComponent("skills")) || fileExists((installPath as NSString).appendingPathComponent("SKILL.md")) {
            components.append("skills")
        }
        if manifest["commands"] != nil || directoryExists((installPath as NSString).appendingPathComponent("commands")) {
            components.append("commands")
        }
        if manifest["agents"] != nil || directoryExists((installPath as NSString).appendingPathComponent("agents")) {
            components.append("agents")
        }
        if manifest["hooks"] != nil || directoryExists((installPath as NSString).appendingPathComponent("hooks")) {
            components.append("hooks")
        }
        if manifest["lspServers"] != nil || fileExists((installPath as NSString).appendingPathComponent(".lsp.json")) {
            components.append("LSP")
        }
        return uniqueStringsPreservingOrder(components)
    }

    private static func marketplacePluginEntries(from root: [String: Any]) -> [MarketplacePluginEntry] {
        if let entries = root["plugins"] as? [[String: Any]] {
            return entries.enumerated().compactMap { index, entry in
                let name = stringFromAny(entry["name"])
                    ?? stringFromAny(entry["id"])
                    ?? stringFromAny(entry["plugin"])
                    ?? "plugin-\(index + 1)"
                return MarketplacePluginEntry(
                    name: name,
                    path: stringFromAny(entry["path"]) ?? stringFromAny(entry["source"]),
                    version: stringFromAny(entry["version"]),
                    detail: stringFromAny(entry["description"])
                )
            }
        }
        if let entries = root["plugins"] as? [Any] {
            return entries.enumerated().compactMap { index, raw in
                if let name = raw as? String {
                    return MarketplacePluginEntry(name: name, path: nil, version: nil, detail: nil)
                }
                if let entry = raw as? [String: Any] {
                    let name = stringFromAny(entry["name"])
                        ?? stringFromAny(entry["id"])
                        ?? "plugin-\(index + 1)"
                    return MarketplacePluginEntry(
                        name: name,
                        path: stringFromAny(entry["path"]) ?? stringFromAny(entry["source"]),
                        version: stringFromAny(entry["version"]),
                        detail: stringFromAny(entry["description"])
                    )
                }
                return nil
            }
        }
        if let entries = root["plugins"] as? [String: Any] {
            return entries.keys.sorted().map { name in
                let raw = entries[name]
                if let entry = raw as? [String: Any] {
                    return MarketplacePluginEntry(
                        name: name,
                        path: stringFromAny(entry["path"]) ?? stringFromAny(entry["source"]),
                        version: stringFromAny(entry["version"]),
                        detail: stringFromAny(entry["description"])
                    )
                }
                return MarketplacePluginEntry(name: name, path: stringFromAny(raw), version: nil, detail: nil)
            }
        }
        return []
    }

    private static func claudeKnownMarketplaceEntries(from raw: Any) -> [MarketplacePluginEntry] {
        if let dictionary = raw as? [String: Any] {
            return dictionary.keys.sorted().map { name in
                let value = dictionary[name]
                if let entry = value as? [String: Any] {
                    return MarketplacePluginEntry(
                        name: name,
                        path: marketplaceSourcePath(from: entry),
                        version: nil,
                        detail: stringFromAny(entry["type"]) ?? marketplaceSourceKind(from: entry)
                    )
                }
                return MarketplacePluginEntry(name: name, path: stringFromAny(value), version: nil, detail: nil)
            }
        }
        if let entries = raw as? [[String: Any]] {
            return entries.enumerated().map { index, entry in
                let name = stringFromAny(entry["name"])
                    ?? stringFromAny(entry["id"])
                    ?? stringFromAny(entry["marketplace"])
                    ?? "marketplace-\(index + 1)"
                return MarketplacePluginEntry(
                    name: name,
                    path: marketplaceSourcePath(from: entry),
                    version: nil,
                    detail: stringFromAny(entry["type"]) ?? marketplaceSourceKind(from: entry)
                )
            }
        }
        if let entries = raw as? [Any] {
            return entries.enumerated().compactMap { index, value in
                if let string = value as? String {
                    return MarketplacePluginEntry(name: "marketplace-\(index + 1)", path: string, version: nil, detail: nil)
                }
                if let entry = value as? [String: Any] {
                    let name = stringFromAny(entry["name"])
                        ?? stringFromAny(entry["id"])
                        ?? "marketplace-\(index + 1)"
                    return MarketplacePluginEntry(
                        name: name,
                        path: marketplaceSourcePath(from: entry),
                        version: nil,
                        detail: stringFromAny(entry["type"]) ?? marketplaceSourceKind(from: entry)
                    )
                }
                return nil
            }
        }
        return []
    }

    private static func marketplaceSourcePath(from entry: [String: Any]) -> String? {
        for key in ["source", "url", "repo", "repository", "path", "directory", "file", "npm", "git", "github", "hostPattern"] {
            if let value = stringFromAny(entry[key]), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func marketplaceSourceKind(from entry: [String: Any]) -> String? {
        for key in ["github", "git", "directory", "url", "npm", "file", "hostPattern", "settings"] where entry[key] != nil {
            return key
        }
        return nil
    }

    private static func settingsDictionary(for surface: CompatibilityMatrixEntry, path: String) -> [String: Any]? {
        switch surface.format {
        case .json, .jsonc:
            return readJSONDictionary(at: path)
        case .plist:
            return readPlistFile(path)
        default:
            return nil
        }
    }

    private static func codexMarketplaceName(from surface: CompatibilityMatrixEntry) -> String {
        guard isCodexPluginMarketplaceSurface(surface) else { return "marketplace" }
        let pieces = surface.id.dropFirst(codexPluginMarketplaceSurfacePrefix.count)
            .split(separator: "|", maxSplits: 1)
            .map(String.init)
        return pieces.first ?? "marketplace"
    }

    private static func resolveMarketplaceEntryPath(_ rawPath: String, marketplacePath: String) -> String {
        let expanded = (rawPath as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded).standardizedFileURL.path
        }
        return URL(fileURLWithPath: marketplacePath)
            .deletingLastPathComponent()
            .appendingPathComponent(rawPath)
            .standardizedFileURL
            .path
    }

    private static func pluginIDParts(_ pluginID: String) -> (name: String, marketplace: String?) {
        guard let at = pluginID.lastIndex(of: "@") else { return (pluginID, nil) }
        return (
            String(pluginID[..<at]),
            String(pluginID[pluginID.index(after: at)...])
        )
    }

    private static func manifestPluginName(path: String, fallback: String) -> String {
        guard let manifest = readJSONDictionary(at: path) else { return fallback }
        return stringFromAny(manifest["name"])
            ?? stringFromAny(manifest["id"])
            ?? fallback
    }

    private static func manifestPluginVersion(path: String) -> String? {
        guard let manifest = readJSONDictionary(at: path) else { return nil }
        return stringFromAny(manifest["version"])
    }

    private static func pluginManifestPaths(
        under root: String,
        markerDirectory: String,
        maxDepth: Int
    ) -> [String] {
        let fm = FileManager.default
        var paths: [String] = []

        func scan(_ directory: String, depth: Int) {
            guard depth <= maxDepth, directoryExists(directory) else { return }
            let manifestPath = ((directory as NSString).appendingPathComponent(markerDirectory) as NSString)
                .appendingPathComponent("plugin.json")
            if fileExists(manifestPath) {
                paths.append(manifestPath)
            }
            guard depth < maxDepth,
                  let entries = try? fm.contentsOfDirectory(atPath: directory) else { return }
            for entry in entries.sorted() where !entry.hasPrefix(".") {
                let child = (directory as NSString).appendingPathComponent(entry)
                guard directoryExists(child) else { continue }
                scan(child, depth: depth + 1)
            }
        }

        scan(root, depth: 0)
        return paths.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private static func claudeMarketplaceName(pluginRoot: String, marketplacesRoot: String) -> String {
        let relative = URL(fileURLWithPath: pluginRoot).path
            .replacingOccurrences(of: "\(URL(fileURLWithPath: marketplacesRoot).path)/", with: "")
        let pieces = relative.split(separator: "/").map(String.init)
        if pieces.count >= 2 { return pieces[0] }
        return pieces.first ?? "local"
    }

    private static func stringFromAny(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private static func codexInstalledPlugins(
        codexHome: String,
        toolID: CompatibilityToolID,
        codexProfileSelection: CodexProfileSelection?
    ) -> [CodexInstalledPlugin] {
        let configPath = (codexHome as NSString).appendingPathComponent("config.toml")
        var pluginStates: [String: Bool] = [:]
        if let raw = try? String(contentsOfFile: configPath, encoding: .utf8) {
            let document = parseSettingsTOMLDocument(raw)
            pluginStates.merge(codexConfiguredPluginStates(document)) { _, new in new }
        }
        if toolID == .codexCLI,
           let activeProfile = codexActiveProfileSelection(
            codexHome: codexHome,
            selection: codexProfileSelection,
            allowDefaultConfig: true
           ),
           let profilePath = codexProfileConfigPath(codexHome: codexHome, profileName: activeProfile.name),
           let raw = try? String(contentsOfFile: profilePath, encoding: .utf8) {
            let document = parseSettingsTOMLDocument(raw)
            pluginStates.merge(codexConfiguredPluginStates(document)) { _, new in new }
        }
        guard !pluginStates.isEmpty else { return [] }
        let cacheRoot = ((codexHome as NSString).appendingPathComponent("plugins/cache") as NSString)
            .expandingTildeInPath
        let fm = FileManager.default

        var installed: [CodexInstalledPlugin] = []
        for pluginID in pluginStates.keys.sorted() {
            guard let parsed = codexPluginIDParts(pluginID) else { continue }
            let marketplaceRoot = (cacheRoot as NSString).appendingPathComponent(parsed.marketplace)
            let pluginCacheRoot = (marketplaceRoot as NSString).appendingPathComponent(parsed.name)
            guard let versions = try? fm.contentsOfDirectory(atPath: pluginCacheRoot) else { continue }
            for version in versions.sorted() where !version.hasPrefix(".") {
                let installPath = (pluginCacheRoot as NSString).appendingPathComponent(version)
                let manifestPath = (installPath as NSString).appendingPathComponent(".codex-plugin/plugin.json")
                guard fileExists(manifestPath) else { continue }
                installed.append(.init(
                    id: pluginID,
                    installPath: expandedPath(installPath),
                    version: version,
                    enabled: pluginStates[pluginID] ?? true
                ))
            }
        }
        return installed
    }

    private static func codexConfiguredPluginStates(_ document: SettingsTOMLDocument) -> [String: Bool] {
        var states: [String: Bool] = [:]
        for (section, values) in document.sectionValues {
            let segments = tomlSectionSegments(section)
            guard segments.count >= 2, segments[0] == "plugins" else { continue }
            if states[segments[1]] == nil {
                states[segments[1]] = true
            }
            if segments.count == 2, let enabled = boolSettingValue(values["enabled"]) {
                states[segments[1]] = enabled
            }
        }
        return states
    }

    private static func codexPluginIDParts(_ pluginID: String) -> (name: String, marketplace: String)? {
        guard let at = pluginID.lastIndex(of: "@") else { return nil }
        let name = String(pluginID[..<at])
        let marketplace = String(pluginID[pluginID.index(after: at)...])
        guard !name.isEmpty, !marketplace.isEmpty else { return nil }
        return (name, marketplace)
    }

    private static func claudeInstalledPlugins(claudeHome: String, projectRoot: String?) -> [ClaudeInstalledPlugin] {
        let installedPluginsPath = "\(claudeHome)/plugins/installed_plugins.json"
        guard let root = readJSONDictionary(at: installedPluginsPath),
              let plugins = root["plugins"] as? [String: Any] else {
            return []
        }

        let normalizedProjectRoot = projectRoot.map(Project.canonicalize)
        var installed: [ClaudeInstalledPlugin] = []
        for pluginID in plugins.keys.sorted() {
            for install in pluginInstallDictionaries(plugins[pluginID]) {
                let scopeString = (install["scope"] as? String)?.lowercased() ?? "user"
                guard claudePluginInstallApplies(scope: scopeString, install: install, projectRoot: normalizedProjectRoot),
                      let rawInstallPath = install["installPath"] as? String,
                      !rawInstallPath.isEmpty else {
                    continue
                }
                let installPath = URL(fileURLWithPath: (rawInstallPath as NSString).expandingTildeInPath)
                    .standardizedFileURL
                    .path
                let enabled = claudePluginEnabledState(
                    pluginID: pluginID,
                    scope: scopeString,
                    claudeHome: claudeHome,
                    projectRoot: normalizedProjectRoot
                ) ?? true
                let version = (install["version"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                installed.append(ClaudeInstalledPlugin(
                    id: pluginID,
                    scope: scopeString,
                    installPath: installPath,
                    version: version,
                    enabled: enabled
                ))
            }
        }
        return installed
    }

    private static func pluginInstallDictionaries(_ value: Any?) -> [[String: Any]] {
        if let dictionaries = value as? [[String: Any]] {
            return dictionaries
        }
        if let array = value as? [Any] {
            return array.compactMap { $0 as? [String: Any] }
        }
        return []
    }

    private static func claudePluginInstallApplies(scope: String, install: [String: Any], projectRoot: String?) -> Bool {
        switch scope {
        case "user", "global", "managed":
            return true
        case "project", "local":
            guard let projectRoot,
                  let rawProjectPath = install["projectPath"] as? String,
                  !rawProjectPath.isEmpty else {
                return false
            }
            return expandedPath(rawProjectPath) == projectRoot
        default:
            return true
        }
    }

    private static func claudePluginScope(_ scope: String) -> CompatibilityScope {
        switch scope {
        case "project":
            return .project
        case "local":
            return .localProjectUser
        default:
            return .global
        }
    }

    private static func claudePluginSkillRoots(installPath: String) -> [String] {
        let fm = FileManager.default
        var roots: [String] = []
        let defaultSkills = (installPath as NSString).appendingPathComponent("skills")
        if directoryExists(defaultSkills) || fileExists((defaultSkills as NSString).appendingPathComponent("SKILL.md")) {
            roots.append(defaultSkills)
        }

        for relativePath in claudePluginManifestSkillPaths(installPath: installPath) {
            guard let resolved = resolveClaudePluginPath(relativePath, installPath: installPath),
                  fm.fileExists(atPath: resolved) else {
                continue
            }
            roots.append(resolved)
        }

        let rootSkill = (installPath as NSString).appendingPathComponent("SKILL.md")
        if roots.isEmpty && fileExists(rootSkill) {
            roots.append(installPath)
        }

        var seen = Set<String>()
        return roots
            .map(expandedPath)
            .filter { seen.insert($0).inserted }
    }

    private static func claudePluginManifestSkillPaths(installPath: String) -> [String] {
        let manifestPath = (installPath as NSString)
            .appendingPathComponent(".claude-plugin/plugin.json")
        guard let manifest = readJSONDictionary(at: manifestPath) else { return [] }
        return stringArray(manifest["skills"])
    }

    private static func claudePluginMCPConfigPaths(installPath: String) -> [String] {
        var paths: [String] = []
        let mcpPath = (installPath as NSString).appendingPathComponent(".mcp.json")
        if fileExists(mcpPath) {
            paths.append(mcpPath)
        }
        let manifestPath = (installPath as NSString).appendingPathComponent(".claude-plugin/plugin.json")
        if let manifest = readJSONDictionary(at: manifestPath),
           manifest["mcpServers"] is [String: Any] {
            paths.append(manifestPath)
        }
        var seen = Set<String>()
        return paths
            .map(expandedPath)
            .filter { seen.insert($0).inserted }
    }

    private static func codexPluginMCPConfigPaths(installPath: String) -> [String] {
        var paths: [String] = []
        let manifestPath = (installPath as NSString)
            .appendingPathComponent(".codex-plugin/plugin.json")
        if let manifest = readJSONDictionary(at: manifestPath),
           manifest.keys.contains("mcpServers") {
            for relativePath in stringArrayOrSingle(manifest["mcpServers"]) {
                guard let resolved = resolveCodexPluginPath(relativePath, installPath: installPath),
                      fileExists(resolved) else {
                    continue
                }
                paths.append(resolved)
            }
        }

        if paths.isEmpty,
           let manifest = readJSONDictionary(at: manifestPath),
           !manifest.keys.contains("mcpServers") {
            let defaultPath = (installPath as NSString).appendingPathComponent(".mcp.json")
            if fileExists(defaultPath) {
                paths.append(defaultPath)
            }
        }

        var seen = Set<String>()
        return paths
            .map(expandedPath)
            .filter { seen.insert($0).inserted }
    }

    private static func codexPluginSkillRoots(installPath: String) -> [String] {
        var roots: [String] = []
        let manifestPath = (installPath as NSString)
            .appendingPathComponent(".codex-plugin/plugin.json")
        if let manifest = readJSONDictionary(at: manifestPath),
           manifest.keys.contains("skills") {
            for relativePath in stringArrayOrSingle(manifest["skills"]) {
                guard let resolved = resolveCodexPluginPath(relativePath, installPath: installPath),
                      directoryExists(resolved) || fileExists((resolved as NSString).appendingPathComponent("SKILL.md")) else {
                    continue
                }
                roots.append(resolved)
            }
        } else {
            let defaultSkills = (installPath as NSString).appendingPathComponent("skills")
            if directoryExists(defaultSkills) || fileExists((defaultSkills as NSString).appendingPathComponent("SKILL.md")) {
                roots.append(defaultSkills)
            }
        }

        let rootSkill = (installPath as NSString).appendingPathComponent("SKILL.md")
        if roots.isEmpty && fileExists(rootSkill) {
            roots.append(installPath)
        }

        var seen = Set<String>()
        return roots
            .map(expandedPath)
            .filter { seen.insert($0).inserted }
    }

    private static func resolveClaudePluginPath(_ rawPath: String, installPath: String) -> String? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("./") || trimmed == "." else { return nil }
        return URL(fileURLWithPath: installPath)
            .appendingPathComponent(trimmed)
            .standardizedFileURL
            .path
    }

    private static func resolveCodexPluginPath(_ rawPath: String, installPath: String) -> String? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("./") || trimmed == "." else { return nil }
        let resolved = URL(fileURLWithPath: installPath)
            .appendingPathComponent(trimmed)
            .standardizedFileURL
            .path
        guard pathIsInside(resolved, root: installPath) else { return nil }
        return resolved
    }

    private static func pathIsInside(_ path: String, root: String) -> Bool {
        let canonicalPath = expandedPath(path)
        let canonicalRoot = expandedPath(root)
        return canonicalPath == canonicalRoot || canonicalPath.hasPrefix("\(canonicalRoot)/")
    }

    private static func claudePluginEnabledState(
        pluginID: String,
        scope: String,
        claudeHome: String,
        projectRoot: String?
    ) -> Bool? {
        let settingsPath: String?
        switch scope {
        case "project":
            settingsPath = projectRoot.map { "\($0)/.claude/settings.json" }
        case "local":
            settingsPath = projectRoot.map { "\($0)/.claude/settings.local.json" }
        default:
            settingsPath = "\(claudeHome)/settings.json"
        }
        guard let settingsPath,
              let settings = readJSONDictionary(at: settingsPath),
              let enabledPlugins = settings["enabledPlugins"] as? [String: Any],
              let value = enabledPlugins[pluginID] else {
            return nil
        }
        return boolSettingValue(value)
    }

    private static func isClaudePluginSkillSurface(_ surface: CompatibilityMatrixEntry) -> Bool {
        surface.id.hasPrefix(claudePluginSkillSurfacePrefix)
    }

    private static func claudePluginSkillSurfaceEnabled(_ surface: CompatibilityMatrixEntry) -> Bool {
        !surface.id.contains("|disabled|")
    }

    private static func claudePluginMCPSurfaceEnabled(_ surface: CompatibilityMatrixEntry) -> Bool {
        !surface.id.contains("|disabled|")
    }

    private static func claudePluginID(from surface: CompatibilityMatrixEntry) -> String? {
        guard isClaudePluginSkillSurface(surface) else { return nil }
        let pieces = surface.id.dropFirst(claudePluginSkillSurfacePrefix.count)
            .split(separator: "|", maxSplits: 2)
            .map(String.init)
        return pieces.first
    }

    private static func claudePluginNamespace(from surface: CompatibilityMatrixEntry) -> String? {
        claudePluginID(from: surface)?
            .split(separator: "@", maxSplits: 1)
            .first
            .map(String.init)
    }

    private static func isClaudePluginMCPSurface(_ surface: CompatibilityMatrixEntry) -> Bool {
        surface.id.hasPrefix(claudePluginMCPSurfacePrefix)
    }

    private static func isCodexPluginMCPSurface(_ surface: CompatibilityMatrixEntry) -> Bool {
        surface.id.hasPrefix(codexPluginMCPSurfacePrefix)
    }

    private static func isCodexPluginSkillSurface(_ surface: CompatibilityMatrixEntry) -> Bool {
        surface.id.hasPrefix(codexPluginSkillSurfacePrefix)
    }

    private static func codexPluginSkillSurfaceEnabled(_ surface: CompatibilityMatrixEntry) -> Bool {
        !surface.id.contains("|disabled|")
    }

    private static func codexPluginID(fromSkillSurface surface: CompatibilityMatrixEntry) -> String? {
        guard isCodexPluginSkillSurface(surface) else { return nil }
        let pieces = surface.id.dropFirst(codexPluginSkillSurfacePrefix.count)
            .split(separator: "|", maxSplits: 3)
            .map(String.init)
        return pieces.first
    }

    private static func codexPluginNamespace(fromSkillSurface surface: CompatibilityMatrixEntry) -> String? {
        codexPluginID(fromSkillSurface: surface)?
            .split(separator: "@", maxSplits: 1)
            .first
            .map(String.init)
    }

    private static func isCodexPluginManifestSurface(_ surface: CompatibilityMatrixEntry) -> Bool {
        surface.id.hasPrefix(codexPluginManifestSurfacePrefix)
    }

    private static func isCodexPluginMarketplaceSurface(_ surface: CompatibilityMatrixEntry) -> Bool {
        surface.id.hasPrefix(codexPluginMarketplaceSurfacePrefix)
    }

    private struct CodexPluginMCPSurfaceMetadata {
        let pluginID: String
        let enabled: Bool
        let projectRoot: String?
    }

    private static func codexPluginMCPMetadata(from surface: CompatibilityMatrixEntry) -> CodexPluginMCPSurfaceMetadata? {
        guard isCodexPluginMCPSurface(surface) else { return nil }
        let pieces = surface.id.dropFirst(codexPluginMCPSurfacePrefix.count)
            .split(separator: "|", maxSplits: 4, omittingEmptySubsequences: false)
            .map(String.init)
        guard pieces.count >= 4 else { return nil }
        return CodexPluginMCPSurfaceMetadata(
            pluginID: pieces[0],
            enabled: pieces[1] != "disabled",
            projectRoot: pieces[3] == "__none__" ? nil : pieces[3]
        )
    }

    private struct CodexPluginMCPPolicyState {
        let enabled: Bool
        let path: String
        let profileName: String?
        let profileSource: CodexProfileSelection.Source?

        var scopeLabel: String {
            if let profileName {
                switch profileSource {
                case .cliRuntimeOverride:
                    return "runtime profile \(profileName)"
                case .defaultConfig:
                    return "default profile \(profileName)"
                case .none:
                    return "profile \(profileName)"
                }
            }
            return "top-level policy"
        }
    }

    private struct CodexPluginMCPPolicyResolution {
        let effective: [String: CodexPluginMCPPolicyState]
        let candidates: [String: [CodexPluginMCPPolicyState]]
    }

    private static func codexPluginDisabledMCPServers(
        pluginID: String,
        projectRoot: String?,
        toolID: CompatibilityToolID,
        codexProfileSelection: CodexProfileSelection?
    ) -> Set<String> {
        Set(codexPluginMCPServerPolicyStates(
            pluginID: pluginID,
            projectRoot: projectRoot,
            toolID: toolID,
            codexProfileSelection: codexProfileSelection
        )
            .filter { $0.value.enabled == false }
            .map(\.key))
    }

    private static func codexPluginDisabledMCPServerPolicyPath(
        surface: CompatibilityMatrixEntry,
        serverName: String
    ) -> String? {
        codexPluginDisabledMCPServerPolicyState(
            surface: surface,
            serverName: serverName,
            codexProfileSelection: nil
        )?.path
    }

    private static func codexPluginDisabledMCPServerPolicyState(
        surface: CompatibilityMatrixEntry,
        serverName: String,
        codexProfileSelection: CodexProfileSelection?
    ) -> CodexPluginMCPPolicyState? {
        guard let metadata = codexPluginMCPMetadata(from: surface),
              metadata.enabled else { return nil }
        return codexPluginMCPServerPolicyStates(
            pluginID: metadata.pluginID,
            projectRoot: metadata.projectRoot,
            toolID: surface.toolID,
            codexProfileSelection: codexProfileSelection
        )[serverName].flatMap { $0.enabled == false ? $0 : nil }
    }

    private static func codexPluginMCPServerPolicyStates(
        pluginID: String,
        projectRoot: String?,
        toolID: CompatibilityToolID,
        codexProfileSelection: CodexProfileSelection?
    ) -> [String: CodexPluginMCPPolicyState] {
        codexPluginMCPServerPolicyResolution(
            pluginID: pluginID,
            projectRoot: projectRoot,
            toolID: toolID,
            codexProfileSelection: codexProfileSelection
        ).effective
    }

    private static func codexPluginMCPServerPolicyResolution(
        pluginID: String,
        projectRoot: String?,
        toolID: CompatibilityToolID,
        codexProfileSelection: CodexProfileSelection?
    ) -> CodexPluginMCPPolicyResolution {
        let codexHome = ProjectHubPaths.codexHome(home: NSHomeDirectory())
        struct PolicyLayer {
            let path: String
            let topLevelProfile: CodexProfileSelection?
            let allowInlineProfiles: Bool
        }
        let globalConfigPath = (codexHome as NSString).appendingPathComponent("config.toml")
        var configPaths = [
            PolicyLayer(path: globalConfigPath, topLevelProfile: nil, allowInlineProfiles: true)
        ]
        if toolID == .codexCLI,
           let selectedProfile = codexEffectiveProfile(
            in: parseSettingsTOMLDocument((try? String(contentsOfFile: globalConfigPath, encoding: .utf8)) ?? ""),
            toolID: toolID,
            selection: codexProfileSelection
           ),
           let profilePath = codexProfileConfigPath(codexHome: codexHome, profileName: selectedProfile.name) {
            configPaths.append(PolicyLayer(path: profilePath, topLevelProfile: selectedProfile, allowInlineProfiles: false))
        }
        var selectedProfileStates: [String: CodexPluginMCPPolicyState] = [:]
        if let projectRoot {
            let trust = ConfigWriter.codexProjectTrustLevel(
                globalConfigPath: globalConfigPath,
                projectRoot: projectRoot
            )
            if trust == "trusted" {
                configPaths.append(PolicyLayer(
                    path: (projectRoot as NSString).appendingPathComponent(".codex/config.toml"),
                    topLevelProfile: nil,
                    allowInlineProfiles: false
                ))
            }
        }

        var states: [String: CodexPluginMCPPolicyState] = [:]
        var candidates: [String: [CodexPluginMCPPolicyState]] = [:]
        for (index, layer) in configPaths.enumerated() {
            guard let raw = try? String(contentsOfFile: layer.path, encoding: .utf8) else { continue }
            let document = parseSettingsTOMLDocument(raw)
            let activeProfile = layer.allowInlineProfiles
                ? codexEffectiveProfile(in: document, toolID: toolID, selection: codexProfileSelection)
                : nil
            var layerStates: [String: CodexPluginMCPPolicyState] = [:]
            var activeProfileStates: [String: CodexPluginMCPPolicyState] = [:]
            for (section, values) in document.sectionValues {
                let segments = tomlSectionSegments(section)
                if segments.count == 4,
                   segments[0] == "plugins",
                   segments[1] == pluginID,
                   segments[2] == "mcp_servers",
                   let enabled = boolSettingValue(values["enabled"]) {
                    layerStates[segments[3]] = CodexPluginMCPPolicyState(
                        enabled: enabled,
                        path: layer.path,
                        profileName: layer.topLevelProfile?.name,
                        profileSource: layer.topLevelProfile?.source
                    )
                } else if let activeProfile,
                          segments.count == 6,
                          segments[0] == "profiles",
                          segments[1] == activeProfile.name,
                          segments[2] == "plugins",
                          segments[3] == pluginID,
                          segments[4] == "mcp_servers",
                          let enabled = boolSettingValue(values["enabled"]) {
                    activeProfileStates[segments[5]] = CodexPluginMCPPolicyState(
                        enabled: enabled,
                        path: layer.path,
                        profileName: activeProfile.name,
                        profileSource: activeProfile.source
                    )
                }
            }
            for (server, state) in activeProfileStates {
                layerStates[server] = state
            }
            if index == 0 {
                selectedProfileStates = activeProfileStates
            }
            for (server, state) in layerStates {
                states[server] = state
                candidates[server, default: []].append(state)
            }
        }
        for (server, state) in selectedProfileStates {
            states[server] = state
            candidates[server, default: []].append(state)
        }
        return CodexPluginMCPPolicyResolution(effective: states, candidates: candidates)
    }

    private static func codexPluginMCPPolicyShadowIssue(
        surface: CompatibilityMatrixEntry,
        serverName: String,
        codexProfileSelection: CodexProfileSelection?
    ) -> CompatibilityIssue? {
        guard let metadata = codexPluginMCPMetadata(from: surface),
              metadata.enabled else { return nil }
        let resolution = codexPluginMCPServerPolicyResolution(
            pluginID: metadata.pluginID,
            projectRoot: metadata.projectRoot,
            toolID: surface.toolID,
            codexProfileSelection: codexProfileSelection
        )
        guard let effective = resolution.effective[serverName],
              let candidates = resolution.candidates[serverName],
              Set(candidates.map(\.enabled)).count > 1,
              let shadowed = candidates.last(where: {
                $0.path != effective.path
                    || $0.profileName != effective.profileName
                    || $0.profileSource != effective.profileSource
            }) else { return nil }

        let effectiveState = effective.enabled ? "enables" : "disables"
        let shadowedState = shadowed.enabled ? "enables" : "disables"
        return issue(
            .projectSettingsShadowed,
            .warning,
            surface,
            "Codex plugin MCP policy shadowed",
            "\"\(serverName)\" has conflicting Codex plugin MCP policy. The effective \(effective.scopeLabel) in \(tilde(effective.path)) \(effectiveState) the server, while a lower-precedence \(shadowed.scopeLabel) in \(tilde(shadowed.path)) \(shadowedState) it.",
            "Remove the shadowed enabled policy if it is stale, or keep both layers only when the override is intentional.",
            subjectPath: shadowed.path,
            metadata: codexPluginMCPPolicyMetadata(shadowed)
        )
    }

    private static func codexPluginMCPPolicyMetadata(_ state: CodexPluginMCPPolicyState) -> [String: String] {
        var metadata: [String: String] = [:]
        if let profileName = state.profileName {
            metadata["codexPluginPolicyProfileName"] = profileName
        }
        if let profileSource = state.profileSource {
            metadata["codexPluginPolicyProfileSource"] = profileSource.rawValue
        }
        return metadata
    }

    private static func codexEffectiveProfile(
        in document: SettingsTOMLDocument,
        toolID: CompatibilityToolID,
        selection: CodexProfileSelection?
    ) -> CodexProfileSelection? {
        if toolID == .codexCLI,
           let selection,
           selection.source == .cliRuntimeOverride {
            return selection
        }
        return stringSetting("profile", in: document).map {
            CodexProfileSelection(name: $0, source: .defaultConfig)
        }
    }

    private static func claudePluginRootForMCPConfig(_ path: String) -> String {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        if url.lastPathComponent == "plugin.json",
           url.deletingLastPathComponent().lastPathComponent == ".claude-plugin" {
            return url.deletingLastPathComponent().deletingLastPathComponent().path
        }
        return url.deletingLastPathComponent().path
    }

    private static func codexPluginRootForMCPConfig(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.deletingLastPathComponent().path
    }

    private static func replaceClaudePluginPlaceholders(in value: Any, pluginRoot: String) -> Any {
        if let string = value as? String {
            return string
                .replacingOccurrences(of: "${CLAUDE_PLUGIN_ROOT}", with: pluginRoot)
                .replacingOccurrences(of: "$CLAUDE_PLUGIN_ROOT", with: pluginRoot)
        }
        if let array = value as? [Any] {
            return array.map { replaceClaudePluginPlaceholders(in: $0, pluginRoot: pluginRoot) }
        }
        if let dict = value as? [String: Any] {
            return dict.mapValues { replaceClaudePluginPlaceholders(in: $0, pluginRoot: pluginRoot) }
        }
        return value
    }

    private static func resolveClaudeAdditionalDirectory(
        _ rawPath: String,
        surface: CompatibilityMatrixEntry,
        projectRoot: String?
    ) -> String? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let expanded = (trimmed as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded).standardizedFileURL.path
        }
        let base: String
        if surface.scope == .project || surface.scope == .localProjectUser {
            base = projectRoot ?? (surface.path.map { (($0 as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent } ?? NSHomeDirectory())
        } else if let settingsPath = surface.path {
            base = (settingsPath as NSString).deletingLastPathComponent
        } else {
            base = projectRoot ?? NSHomeDirectory()
        }
        return URL(fileURLWithPath: base)
            .appendingPathComponent(expanded)
            .standardizedFileURL
            .path
    }

    private static func codexRepositoryInstructionSurfaces(
        start: String,
        fallbackFilenames: [String],
        toolID: CompatibilityToolID
    ) -> [CompatibilityMatrixEntry] {
        let repoRoot = nearestRepositoryRoot(from: start) ?? start
        let startURL = URL(fileURLWithPath: expandedPath(start))
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let stopURL = URL(fileURLWithPath: Project.canonicalize(repoRoot))
        var directories: [URL] = []
        var current = startURL

        while true {
            directories.append(current)
            if current.path == stopURL.path { break }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }

        let rootToWorkingDirectory = directories.reversed()
        let filenames = uniqueStringsPreservingOrder(["AGENTS.override.md", "AGENTS.md"] + fallbackFilenames)
        let toolSlug = toolID == .codexCLI ? "cli" : "desktop"

        return rootToWorkingDirectory.enumerated().flatMap { directoryIndex, directory in
            filenames.enumerated().map { filenameIndex, filename in
                let isRoot = directory.path == stopURL.path
                let filenameKind: String
                if filename == "AGENTS.override.md" {
                    filenameKind = "override"
                } else if filename == "AGENTS.md" {
                    filenameKind = "standard"
                } else {
                    filenameKind = "fallback"
                }
                let labelPrefix = toolID == .codexCLI ? "Codex CLI" : "Codex Desktop"
                let location = isRoot ? "repository" : "nested"
                let note: String
                switch filenameKind {
                case "override":
                    note = "Highest-precedence Codex instruction file for this directory; it shadows AGENTS.md and configured fallbacks at the same level."
                case "standard":
                    note = "Codex instruction file for this directory; used when AGENTS.override.md is absent or empty."
                default:
                    note = "Configured Codex fallback instruction filename from project_doc_fallback_filenames; used only when AGENTS.override.md and AGENTS.md are absent or empty at this level."
                }

                return CompatibilityMatrixEntry(
                    id: "codex-\(toolSlug)-project-context|\(directory.path)|\(filename)",
                    toolID: toolID,
                    kind: .context,
                    scope: .project,
                    label: "\(labelPrefix) \(location) \(filenameKind) instructions",
                    path: directory.appendingPathComponent(filename).path,
                    format: .markdown,
                    fileControlled: true,
                    canWriteSafely: false,
                    writeMethod: .file,
                    requiresRestartAfterWrite: false,
                    supportsDisable: false,
                    supportsOAuth: false,
                    supportsEnvExpansion: false,
                    precedence: 20 + (directoryIndex * 10) + filenameIndex,
                    note: note
                )
            }
        }
    }

    private static func nearestRepositoryRoot(from start: String) -> String? {
        var current = URL(fileURLWithPath: expandedPath(start))
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let fm = FileManager.default
        let markers = projectRootMarkers()
        var markerRoot: String?
        while true {
            if fm.fileExists(atPath: current.appendingPathComponent(".git").path) {
                return current.path
            }
            if isMeaningfulProjectRoot(current.path),
               hasProjectRootMarker(at: current.path, markers: markers) {
                markerRoot = current.path
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { return markerRoot }
            current = parent
        }
    }

    private static func projectRootMarkers() -> [String] {
        let builtIn = [
            "Package.swift",
            "package.json",
            "pyproject.toml",
            "Cargo.toml",
            "go.mod",
            "AGENTS.md",
            "CLAUDE.md",
            ".mcp.json",
            ".codex/config.toml",
            ".agents/skills",
            ".claude/settings.json",
            ".claude/launch.json",
            ".claude/skills"
        ]
        return uniqueStringsPreservingOrder(builtIn + codexProjectRootMarkers())
    }

    private static func codexProjectRootMarkers() -> [String] {
        let codexHome = ProjectHubPaths.codexHome(home: NSHomeDirectory())
        let configPath = "\(codexHome)/config.toml"
        guard let raw = try? String(contentsOfFile: configPath, encoding: .utf8) else { return [] }
        let document = parseSettingsTOMLDocument(raw)
        guard let value = document.topLevelRawValues["project_root_markers"],
              let markers = parseTOMLStringArrayLiteral(value) else { return [] }
        return markers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter(isSafeProjectRootMarker)
    }

    private static func hasProjectRootMarker(at path: String, markers: [String]) -> Bool {
        markers.contains {
            FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent($0))
        }
    }

    private static func isSafeProjectRootMarker(_ value: String) -> Bool {
        !value.isEmpty
            && value != "."
            && value != ".."
            && !value.hasPrefix("/")
            && !value.contains("..")
            && !value.contains("\\")
    }

    private static func isMeaningfulProjectRoot(_ path: String) -> Bool {
        let home = Project.canonicalize(NSHomeDirectory())
        let broadPaths: Set<String> = [
            "/",
            home,
            (home as NSString).appendingPathComponent("Desktop"),
            (home as NSString).appendingPathComponent("Documents"),
            (home as NSString).appendingPathComponent("Downloads"),
            (home as NSString).appendingPathComponent("Library")
        ]
        return !broadPaths.contains(Project.canonicalize(path))
    }

    // MARK: - MCP reading

    private struct ServerRead {
        var servers: [CompatibilityServerObservation]
        var issues: [CompatibilityIssue]
    }

    private static func readServers(
        from surface: CompatibilityMatrixEntry,
        codexProfileSelection: CodexProfileSelection?
    ) -> ServerRead {
        guard let path = surface.path else {
            return ServerRead(servers: [], issues: [
                issue(.serverRuntimeManaged, .info, surface, "Runtime-managed surface", "\(surface.label) is managed by the app/account runtime and has no local file to scan.", nil)
            ])
        }

        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else {
            return ServerRead(servers: [], issues: [
                issue(.configMissing, .info, surface, "No config found", "No \(surface.label) config exists at this path.", "Create it only when the user chooses this target scope.")
            ])
        }

        switch surface.format {
        case .json, .jsonc:
            if isCodexPluginMCPSurface(surface) {
                return readCodexPluginMCPServers(
                    surface: surface,
                    path: path,
                    codexProfileSelection: codexProfileSelection
                )
            }
            return readJSONServers(surface: surface, path: path)
        case .toml:
            return readTOMLServers(surface: surface, path: path)
        case .plist:
            return ServerRead(servers: [], issues: [
                issue(.configUnsupportedShape, .info, surface, "Settings-only surface", "\(surface.label) is a preference/settings file, not an MCP server list.", nil)
            ])
        case .markdown:
            return ServerRead(servers: [], issues: [
                issue(.configUnsupportedShape, .info, surface, "Context-only surface", "\(surface.label) is a project instruction file, not an MCP server list.", nil)
            ])
        case .directory:
            if surface.id == "claude-desktop-dxt" {
                return readClaudeDesktopExtensions(surface: surface, path: path)
            }
            return ServerRead(servers: [], issues: [])
        case .keychain, .accountRuntime, .unknown:
            return ServerRead(servers: [], issues: [
                issue(.configUnsupportedShape, .info, surface, "Unsupported scan surface", "\(surface.label) is not a directly parseable MCP config file.", nil)
            ])
        }
    }

    private static func readClaudeDesktopExtensions(surface: CompatibilityMatrixEntry, path: String) -> ServerRead {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else {
            return ServerRead(servers: [], issues: [
                issue(.configUnsupportedShape, .warning, surface, "Could not read extensions", "Project Hub could not list Claude Desktop extensions at \(tilde(path)).", nil)
            ])
        }

        var servers: [CompatibilityServerObservation] = []
        var issues: [CompatibilityIssue] = []

        for entry in entries.sorted() where !entry.hasPrefix(".") {
            let extensionDir = (path as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: extensionDir, isDirectory: &isDir), isDir.boolValue else { continue }

            guard let manifestPath = claudeDesktopExtensionManifestPath(in: extensionDir) else {
                issues.append(issue(.configMissing, .warning, surface, "Extension missing manifest", "\(entry) is installed in Claude Extensions but has no manifest.json.", "Reinstall or remove this extension through Claude Desktop Settings > Extensions."))
                continue
            }

            guard let manifest = readJSONFile(manifestPath) else {
                issues.append(issue(.configInvalidJSON, .error, surface, "Invalid extension manifest", "\(entry) has a manifest.json Project Hub could not parse.", "Reinstall this extension through Claude Desktop Settings > Extensions."))
                continue
            }

            let settings = claudeDesktopExtensionSettings(extensionID: entry)
            guard let config = claudeDesktopExtensionMCPConfig(manifest: manifest, extensionDir: extensionDir, settings: settings) else {
                issues.append(issue(.configUnsupportedShape, .info, surface, "Extension has no local MCP config", "\(extensionDisplayName(manifest, fallback: entry)) is installed, but its manifest does not expose a server.mcp_config object.", "Manage this extension from Claude Desktop Settings > Extensions."))
                continue
            }

            var enriched = config
            enriched["__extension_dir"] = extensionDir
            enriched["__extension_version"] = manifest["version"] as? String ?? ""
            enriched["__extension_tools"] = (manifest["tools"] as? [Any])?.count ?? 0

            let name = extensionDisplayName(manifest, fallback: entry)
            let disabled = (settings?["isEnabled"] as? Bool).map { !$0 }
            servers.append(observation(name: name, config: enriched, surface: surface, path: manifestPath, disabled: disabled))

            let missingConfig = extensionMissingRequiredUserConfig(manifest, settings: settings)
            if !missingConfig.isEmpty {
                issues.append(issue(.serverRuntimeManaged, .info, surface, "Extension may need configuration", "\(name) declares required user_config fields that are not visible in Claude Desktop's local extension settings: \(missingConfig.joined(separator: ", ")). Project Hub can inspect the package, but Claude Desktop owns those values.", "Open Claude Desktop Settings > Extensions to fill or confirm the required extension fields."))
            }

            if extensionSignatureStatus(extensionDir) == "unsigned" {
                issues.append(issue(.serverHealthUnknown, .info, surface, "Unsigned desktop extension", "\(name) is installed as an unsigned desktop extension.", "Review the extension source and permissions in Claude Desktop before enabling sensitive tools."))
            }
        }

        if servers.isEmpty && issues.isEmpty {
            issues.append(issue(.configMissing, .info, surface, "No desktop extensions installed", "Claude Desktop's extension directory exists, but Project Hub did not find any installed extensions with MCP manifests.", "Install MCPB/DXT extensions through Claude Desktop when you want them available there."))
        }

        return ServerRead(servers: servers, issues: issues)
    }

    private static func claudeDesktopExtensionManifestPath(in extensionDir: String) -> String? {
        let primary = (extensionDir as NSString).appendingPathComponent("manifest.json")
        if FileManager.default.fileExists(atPath: primary) { return primary }
        let bundled = (extensionDir as NSString).appendingPathComponent("manifest.mcpb.json")
        if FileManager.default.fileExists(atPath: bundled) { return bundled }
        return nil
    }

    private static func readJSONFile(_ path: String) -> [String: Any]? {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8),
              let data = ConfigWriter.stripJsonComments(raw).data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return root
    }

    private static func claudeDesktopExtensionMCPConfig(
        manifest: [String: Any],
        extensionDir: String,
        settings: [String: Any]?
    ) -> [String: Any]? {
        guard let server = manifest["server"] as? [String: Any] else { return nil }
        if let rawConfig = server["mcp_config"] as? [String: Any] {
            var config = rawConfig
            config = replaceExtensionPlaceholders(
                in: config,
                extensionDir: extensionDir,
                manifest: manifest,
                settings: settings
            ) as? [String: Any] ?? config
            if config["type"] == nil { config["type"] = "stdio" }
            return config
        }

        guard let type = (server["type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              type == "uv",
              let entryPoint = (server["entry_point"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !entryPoint.isEmpty else { return nil }

        var config: [String: Any] = [
            "type": "stdio",
            "command": "uv",
            "args": [entryPoint],
            "__extension_runtime": "uv",
            "__extension_runtime_managed": true
        ]
        config = replaceExtensionPlaceholders(
            in: config,
            extensionDir: extensionDir,
            manifest: manifest,
            settings: settings
        ) as? [String: Any] ?? config
        return config
    }

    private static func replaceExtensionPlaceholders(
        in value: Any,
        extensionDir: String,
        manifest: [String: Any],
        settings: [String: Any]?
    ) -> Any {
        if let string = value as? String {
            return replaceExtensionPlaceholders(
                in: string,
                extensionDir: extensionDir,
                manifest: manifest,
                settings: settings
            )
        }
        if let array = value as? [Any] {
            return array.flatMap { item -> [Any] in
                if let string = item as? String,
                   let replacement = exactUserConfigPlaceholderValue(in: string, manifest: manifest, settings: settings) {
                    if let array = replacement as? [Any] { return array.map(stringifyExtensionUserConfigValue) }
                    return [stringifyExtensionUserConfigValue(replacement)]
                }
                return [
                    replaceExtensionPlaceholders(
                        in: item,
                        extensionDir: extensionDir,
                        manifest: manifest,
                        settings: settings
                    )
                ]
            }
        }
        if let dict = value as? [String: Any] {
            return dict.mapValues {
                replaceExtensionPlaceholders(
                    in: $0,
                    extensionDir: extensionDir,
                    manifest: manifest,
                    settings: settings
                )
            }
        }
        return value
    }

    private static func replaceExtensionPlaceholders(
        in string: String,
        extensionDir: String,
        manifest: [String: Any],
        settings: [String: Any]?
    ) -> String {
        var replaced = string.replacingOccurrences(of: "${__dirname}", with: extensionDir)
        guard let userConfig = manifest["user_config"] as? [String: Any] else { return replaced }
        for key in userConfig.keys.sorted() {
            guard let value = extensionUserConfigValue(key: key, manifest: manifest, settings: settings) else { continue }
            replaced = replaced.replacingOccurrences(
                of: "${user_config.\(key)}",
                with: stringifyExtensionUserConfigValue(value)
            )
        }
        return replaced
    }

    private static func exactUserConfigPlaceholderValue(
        in string: String,
        manifest: [String: Any],
        settings: [String: Any]?
    ) -> Any? {
        guard string.hasPrefix("${user_config."),
              string.hasSuffix("}") else { return nil }
        let start = string.index(string.startIndex, offsetBy: "${user_config.".count)
        let key = String(string[start..<string.index(before: string.endIndex)])
        return extensionUserConfigValue(key: key, manifest: manifest, settings: settings)
    }

    private static func extensionUserConfigValue(
        key: String,
        manifest: [String: Any],
        settings: [String: Any]?
    ) -> Any? {
        if let configured = settings?["userConfig"] as? [String: Any],
           let value = configured[key] {
            return value
        }
        guard let definitions = manifest["user_config"] as? [String: Any],
              let definition = definitions[key] as? [String: Any],
              let value = definition["default"] else {
            return nil
        }
        if let array = value as? [Any], array.isEmpty {
            return nil
        }
        if let string = value as? String, string.isEmpty {
            return nil
        }
        return value
    }

    private static func stringifyExtensionUserConfigValue(_ value: Any) -> String {
        if let string = value as? String { return string }
        if let strings = value as? [String] { return strings.joined(separator: ",") }
        if let array = value as? [Any] {
            return array.map(stringifyExtensionUserConfigValue).joined(separator: ",")
        }
        if let number = value as? NSNumber { return number.stringValue }
        return "\(value)"
    }

    private static func extensionDisplayName(_ manifest: [String: Any], fallback: String) -> String {
        let display = manifest["display_name"] as? String
        let name = manifest["name"] as? String
        return [display, name, fallback]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? fallback
    }

    private static func claudeDesktopExtensionSettings(extensionID: String) -> [String: Any]? {
        let path = (claudeDesktopApplicationSupportDirectory() as NSString)
            .appendingPathComponent("Claude Extensions Settings/\(extensionID).json")
        return readJSONFile(path)
    }

    private static func extensionMissingRequiredUserConfig(_ manifest: [String: Any], settings: [String: Any]?) -> [String] {
        guard let userConfig = manifest["user_config"] as? [String: Any] else { return [] }
        let configured = settings?["userConfig"] as? [String: Any] ?? [:]
        var missing: [String] = []
        for (key, value) in userConfig {
            guard let config = value as? [String: Any],
                  (config["required"] as? Bool) == true else { continue }
            if configured[key] != nil { continue }
            if let defaultArray = config["default"] as? [Any], !defaultArray.isEmpty { continue }
            if let defaultString = config["default"] as? String, !defaultString.isEmpty { continue }
            if config["default"] is Bool || config["default"] is NSNumber { continue }
            missing.append(key)
        }
        return missing.sorted()
    }

    private static func extensionSignatureStatus(_ extensionDir: String) -> String? {
        let metadataPath = (extensionDir as NSString).appendingPathComponent("_update_metadata.json")
        guard let metadata = readJSONFile(metadataPath),
              let signature = metadata["signatureInfo"] as? [String: Any] else { return nil }
        return signature["status"] as? String
    }

    private static func readJSONServers(surface: CompatibilityMatrixEntry, path: String) -> ServerRead {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else {
            return ServerRead(servers: [], issues: [issue(.configUnsupportedShape, .warning, surface, "Could not read config", "Project Hub could not read this file.", nil)])
        }

        let stripped = ConfigWriter.stripJsonComments(raw)
        guard let data = stripped.data(using: .utf8),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ServerRead(servers: [], issues: [issue(.configInvalidJSON, .error, surface, "Invalid JSON", "This config could not be parsed as JSON/JSONC.", "Open the file and fix JSON syntax before applying automated changes.")])
        }

        if isClaudePluginMCPSurface(surface),
           let pluginRoot = surface.path.map(claudePluginRootForMCPConfig) {
            root = replaceClaudePluginPlaceholders(in: root, pluginRoot: pluginRoot) as? [String: Any] ?? root
        }

        if surface.id.hasPrefix("claude-code-local-mcp") {
            return readClaudeCodeLocalServers(surface: surface, path: path, root: root)
        }

        var servers: [CompatibilityServerObservation] = []
        var issues: [CompatibilityIssue] = []
        if let enabled = root["mcpServers"] as? [String: Any] {
            let forcedDisabled: Bool? = isClaudePluginMCPSurface(surface) && !claudePluginMCPSurfaceEnabled(surface) ? true : nil
            if surface.id == "claude-code-project-mcp" {
                let approval = claudeCodeProjectMCPApprovalState(configPath: path)
                servers += observations(from: enabled, surface: surface, path: path, disabledNames: approval.disabled)
            } else {
                servers += observations(from: enabled, surface: surface, path: path, disabled: forcedDisabled)
            }
            if surface.id.hasPrefix("claude-code-managed-mcp"), enabled.isEmpty {
                issues.append(issue(
                    .settingsManagedRequirement,
                    .warning,
                    surface,
                    "Claude Code MCP disabled by managed policy",
                    "\(surface.label) defines an empty mcpServers map, so Claude Code loads no user, project, plugin, or connector MCP servers on this machine.",
                    "Treat MCP as administrator-controlled until managed-mcp.json is changed or removed."
                ))
            }
        } else if surface.kind == .mcp {
            return ServerRead(servers: [], issues: [issue(.configUnsupportedShape, .warning, surface, "No mcpServers object", "The file exists but does not contain an mcpServers object.", "Confirm whether this is the correct config file for this tool/scope.")])
        }
        if let disabled = root["mcpServers_disabled"] as? [String: Any] {
            servers += observations(from: disabled, surface: surface, path: path, disabled: true)
        }

        return ServerRead(servers: servers, issues: issues)
    }

    private static func readCodexPluginMCPServers(
        surface: CompatibilityMatrixEntry,
        path: String,
        codexProfileSelection: CodexProfileSelection?
    ) -> ServerRead {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else {
            return ServerRead(servers: [], issues: [issue(.configUnsupportedShape, .warning, surface, "Could not read plugin MCP config", "Project Hub could not read this Codex plugin MCP file.", nil)])
        }

        let stripped = ConfigWriter.stripJsonComments(raw)
        guard let data = stripped.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ServerRead(servers: [], issues: [issue(.configInvalidJSON, .error, surface, "Invalid plugin MCP JSON", "This Codex plugin MCP file could not be parsed as JSON/JSONC.", "Reinstall or update the plugin, then restart Codex.")])
        }

        guard let serverMap = codexPluginMCPServerMap(root) else {
            return ServerRead(servers: [], issues: [issue(.configUnsupportedShape, .warning, surface, "No plugin MCP servers", "This Codex plugin MCP file does not contain mcpServers, mcp_servers, or a direct server map.", "Confirm the plugin's .codex-plugin/plugin.json mcpServers path points to the right file.")])
        }

        let metadata = codexPluginMCPMetadata(from: surface)
        let disabledNames = metadata.map {
            codexPluginDisabledMCPServers(
                pluginID: $0.pluginID,
                projectRoot: $0.projectRoot,
                toolID: surface.toolID,
                codexProfileSelection: codexProfileSelection
            )
        } ?? []
        let pluginDisabled = metadata?.enabled == false
        let pluginRoot = codexPluginRootForMCPConfig(path)
        let resolvedMap = serverMap.mapValues {
            resolveCodexPluginMCPConfig($0, pluginRoot: pluginRoot) as? [String: Any] ?? $0
        }

        return ServerRead(
            servers: resolvedMap.compactMap { name, config in
                observation(
                    name: name,
                    config: config,
                    surface: surface,
                    path: path,
                    disabled: pluginDisabled || disabledNames.contains(name) ? true : nil
                )
            },
            issues: []
        )
    }

    private static func codexPluginMCPServerMap(_ root: [String: Any]) -> [String: [String: Any]]? {
        if let servers = root["mcpServers"] as? [String: Any] {
            return serverConfigMap(servers)
        }
        if let servers = root["mcp_servers"] as? [String: Any] {
            return serverConfigMap(servers)
        }
        return serverConfigMap(root)
    }

    private static func serverConfigMap(_ value: [String: Any]) -> [String: [String: Any]]? {
        var servers: [String: [String: Any]] = [:]
        for (name, config) in value {
            guard let config = config as? [String: Any],
                  config["command"] != nil || config["url"] != nil || config["type"] != nil else {
                return nil
            }
            servers[name] = config
        }
        return servers.isEmpty ? nil : servers
    }

    private static func resolveCodexPluginMCPConfig(_ value: Any, pluginRoot: String) -> Any {
        if let string = value as? String {
            if string == "." { return pluginRoot }
            if string.hasPrefix("./") {
                return URL(fileURLWithPath: pluginRoot)
                    .appendingPathComponent(string)
                    .standardizedFileURL
                    .path
            }
            return string.replacingOccurrences(of: "${CODEX_PLUGIN_ROOT}", with: pluginRoot)
        }
        if let array = value as? [Any] {
            return array.map { resolveCodexPluginMCPConfig($0, pluginRoot: pluginRoot) }
        }
        if let dict = value as? [String: Any] {
            return dict.mapValues { resolveCodexPluginMCPConfig($0, pluginRoot: pluginRoot) }
        }
        return value
    }

    private static func claudeCodeProjectMCPApprovalState(configPath: String) -> MCPReader.ClaudeProjectMCPApprovalState {
        let projectRoot = (configPath as NSString).deletingLastPathComponent
        return MCPReader.claudeCodeProjectMCPApprovalState(projectPath: projectRoot)
    }

    private static func readClaudeCodeLocalServers(surface: CompatibilityMatrixEntry, path: String, root: [String: Any]) -> ServerRead {
        guard let projectRoot = claudeLocalProjectRoot(from: surface) else {
            return ServerRead(servers: [], issues: [
                issue(.serverHealthUnknown, .info, surface, "Pick a project to inspect local Claude MCP", "Claude Code local-scope MCP servers are stored per project inside ~/.claude.json.", "Select a project, then run Scan to inspect its private Claude Code MCP state.")
            ])
        }

        guard let projectState = claudeProjectState(projectRoot: projectRoot, root: root) else {
            return ServerRead(servers: [], issues: [])
        }

        var servers: [CompatibilityServerObservation] = []
        let disabledServerNames = Set(stringArray(projectState["disabledMcpServers"]))
        if let enabled = projectState["mcpServers"] as? [String: Any] {
            servers += observations(from: enabled, surface: surface, path: path, disabledNames: disabledServerNames)
        }
        if let disabled = projectState["mcpServers_disabled"] as? [String: Any] {
            servers += observations(from: disabled, surface: surface, path: path, disabled: true)
        }
        return ServerRead(servers: servers, issues: [])
    }

    private static func claudeProjectState(from surface: CompatibilityMatrixEntry, root: [String: Any]) -> [String: Any]? {
        guard let projectRoot = claudeLocalProjectRoot(from: surface) else {
            return nil
        }
        return claudeProjectState(projectRoot: projectRoot, root: root)
    }

    private static func claudeProjectState(projectRoot: String, root: [String: Any]) -> [String: Any]? {
        guard let projects = root["projects"] as? [String: Any] else { return nil }
        if let projectState = projects[projectRoot] as? [String: Any] {
            return projectState
        }
        let canonicalRoot = canonicalFilePath(projectRoot)
        if let canonicalMatch = projects.first(where: { key, _ in
            canonicalFilePath(key) == canonicalRoot
        })?.value as? [String: Any] {
            return canonicalMatch
        }
        let foldedRoot = canonicalRoot.lowercased()
        return projects.first { key, _ in
            canonicalFilePath(key).lowercased() == foldedRoot
        }?.value as? [String: Any]
    }

    private static func readTOMLServers(surface: CompatibilityMatrixEntry, path: String) -> ServerRead {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else {
            return ServerRead(servers: [], issues: [issue(.configUnsupportedShape, .warning, surface, "Could not read config", "Project Hub could not read this TOML file.", nil)])
        }
        let parsed = parseMCPServersTOML(raw)
        if parsed.invalid {
            return ServerRead(servers: [], issues: [issue(.configInvalidTOML, .error, surface, "Invalid TOML", "This config has MCP sections Project Hub could not parse safely.", "Fix TOML syntax before applying automated changes.")])
        }
        return ServerRead(servers: observations(from: parsed.servers, surface: surface, path: path, disabled: nil), issues: [])
    }

    private static func observations(
        from dict: [String: Any],
        surface: CompatibilityMatrixEntry,
        path: String,
        disabled forcedDisabled: Bool?
    ) -> [CompatibilityServerObservation] {
        dict.compactMap { name, value in
            guard let cfg = value as? [String: Any] else { return nil }
            return observation(name: name, config: cfg, surface: surface, path: path, disabled: forcedDisabled)
        }
    }

    private static func observations(
        from dict: [String: Any],
        surface: CompatibilityMatrixEntry,
        path: String,
        disabledNames: Set<String>
    ) -> [CompatibilityServerObservation] {
        dict.compactMap { name, value in
            guard let cfg = value as? [String: Any] else { return nil }
            return observation(
                name: name,
                config: cfg,
                surface: surface,
                path: path,
                disabled: disabledNames.contains(name) ? true : nil
            )
        }
    }

    private static func observation(
        name: String,
        config: [String: Any],
        surface: CompatibilityMatrixEntry,
        path: String,
        disabled forcedDisabled: Bool?
    ) -> CompatibilityServerObservation {
        let launch = MCPLaunchNormalizer.metadata(command: config["command"], args: stringArray(config["args"]))
        let command = launch.command
        let args = launch.args
        let cwd = normalizedCWD(config["cwd"] ?? config["workingDirectory"] ?? config["working_directory"])
        let url = config["url"] as? String
        let type = (config["type"] as? String) ?? (url == nil ? "stdio" : "http")
        let disabled = forcedDisabled ?? ((config["enabled"] as? Bool) == false || (config["disabled"] as? Bool) == true)
        var detail = url ?? ([command] + args.map { Optional($0) }).compactMap { $0 }.joined(separator: " ")
        if let cwd {
            detail += " (cwd: \(cwd))"
        }
        if boolValue(config["sandboxEnabled"] ?? config["sandbox_enabled"]) == true {
            detail += " (sandboxed)"
        }
        if config["dev"] != nil {
            detail += " (dev)"
        }
        let enabledTools = stringArray(config["enabledTools"] ?? config["enabled_tools"])
        let alwaysAllow = stringArray(config["alwaysAllow"] ?? config["always_allow"])
        let disabledTools = stringArray(config["disabledTools"] ?? config["disabled_tools"])
        let watchPaths = stringArray(config["watchPaths"] ?? config["watch_paths"])
        if !enabledTools.isEmpty {
            detail += " (enabled tools: \(enabledTools.count))"
        }
        if !alwaysAllow.isEmpty {
            detail += " (auto-allow: \(alwaysAllow.count))"
        }
        if !disabledTools.isEmpty {
            detail += " (disabled tools: \(disabledTools.count))"
        }
        if let approvalMode = config["defaultToolApprovalMode"] as? String ?? config["default_tools_approval_mode"] as? String {
            detail += " (approval: \(approvalMode))"
        }
        let toolApprovals = toolApprovalModes(from: config)
        if !toolApprovals.isEmpty {
            detail += " (tool approvals: \(toolApprovals.count))"
        }
        if !watchPaths.isEmpty {
            detail += " (watch: \(watchPaths.count))"
        }
        var issueCodes: [CompatibilityIssueCode] = []
        if disabled { issueCodes.append(.serverDisabled) }
        if command == nil && url == nil && !isCodexProjectMCPSurface(surface) {
            issueCodes.append(.serverMissingLaunchTarget)
        }

        return CompatibilityServerObservation(
            id: "\(surface.id):\(name)",
            toolID: surface.toolID,
            surfaceID: surface.id,
            surfaceLabel: surface.label,
            name: name,
            transport: type,
            detail: detail,
            path: path,
            scope: surface.scope,
            disabled: disabled,
            startupTimeoutSeconds: codexStartupTimeoutSeconds(from: config),
            toolTimeoutSeconds: codexNumber(config["tool_timeout_sec"]) ?? codexNumber(config["timeout"]),
            fingerprint: fingerprint(config),
            health: disabled ? .disabled : .unknown,
            issueCodes: issueCodes
        )
    }

    // MARK: - Server inspection

    private static func inspectServer(
        _ server: CompatibilityServerObservation,
        surface: CompatibilityMatrixEntry?,
        matrix: [CompatibilityMatrixEntry],
        claudeMCPPolicy: ClaudeMCPPolicy,
        codexProfileSelection: CodexProfileSelection?
    ) -> [CompatibilityIssue] {
        guard let surface else { return [] }
        var issues: [CompatibilityIssue] = []
        if server.disabled {
            if let policyState = codexPluginDisabledMCPServerPolicyState(
                surface: surface,
                serverName: server.name,
                codexProfileSelection: codexProfileSelection
            ) {
                let profileCopy = policyState.profileName.map { profileName in
                    policyState.profileSource == .cliRuntimeOverride
                        ? " by the runtime profile \(profileName)"
                        : " by the active default profile \(profileName)"
                } ?? ""
                issues.append(issue(
                    .serverDisabled,
                    .info,
                    surface,
                    "Server disabled",
                    "\"\(server.name)\" is disabled\(profileCopy) by Codex plugin MCP policy in \(tilde(policyState.path)).",
                    "Preview enabling this server in the Codex config layer that disabled it.",
                    subjectPath: policyState.path,
                    metadata: codexPluginMCPPolicyMetadata(policyState)
                ))
            } else {
                issues.append(issue(.serverDisabled, .info, surface, "Server disabled", "\"\(server.name)\" is configured but disabled.", "Enable it only if this server should be available in \(surface.toolID.label)."))
            }
        }
        if let shadowIssue = codexPluginMCPPolicyShadowIssue(
            surface: surface,
            serverName: server.name,
            codexProfileSelection: codexProfileSelection
        ) {
            issues.append(shadowIssue)
        }
        if surface.id == "claude-code-project-mcp", !server.disabled,
           let path = surface.path {
            let approval = claudeCodeProjectMCPApprovalState(configPath: path)
            if !approval.approveAll && !approval.enabled.contains(server.name) {
                issues.append(issue(
                    .serverHealthUnknown,
                    .info,
                    surface,
                    "Claude project MCP approval not recorded",
                    "\"\(server.name)\" is defined in project .mcp.json, but Project Hub did not find it in enabledMcpjsonServers or enableAllProjectMcpServers for this project. Claude Code may prompt before loading it.",
                    "Open the project in Claude Code and review the project MCP prompt or /mcp before relying on this server.",
                    subjectPath: server.name
                ))
            }
        }
        if surface.toolID == .claudeCode,
           server.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "workspace" {
            issues.append(issue(
                .serverReservedName,
                .error,
                surface,
                "Reserved MCP server name",
                "Claude Code reserves the MCP server name \"workspace\" and skips configured servers with that name.",
                "Rename this MCP server before relying on it in Claude Code.",
                subjectPath: server.name
            ))
        }

        guard let config = readServerConfig(server, surface: surface, matrix: matrix) else {
            if !server.disabled {
                issues.append(issue(.serverHealthUnknown, .warning, surface, "Health unknown", "Project Hub could not re-read \"\(server.name)\" for deeper checks.", nil))
            }
            return issues
        }

        if let policyIssue = claudeMCPPolicyIssue(for: server, surface: surface, config: config, policy: claudeMCPPolicy) {
            issues.append(policyIssue)
            return issues
        }

        if surface.id == "claude-desktop-dxt" {
            let command = launchCommand(from: config).command
            let url = config["url"] as? String
            if (command?.isEmpty ?? true) && url == nil {
                issues.append(issue(.serverMissingLaunchTarget, .error, surface, "Missing extension launch target", "\"\(server.name)\" has no command or url in its MCPB/DXT manifest.", "Reinstall or remove this extension through Claude Desktop Settings > Extensions."))
            } else if !server.disabled {
                issues.append(issue(.serverRuntimeManaged, .info, surface, "Extension runtime is app-managed", "\"\(server.name)\" is an MCPB/DXT extension. Project Hub parsed the manifest, but Claude Desktop owns runtime resolution, user config, credentials, and restart behavior.", "Open Claude Desktop Settings > Extensions or check logs under ~/Library/Logs/Claude to verify this extension."))
            }
            if !server.disabled {
                issues.append(contentsOf: inspectClaudeDesktopLog(server, surface: surface))
            }
            return issues
        }

        let transport = server.transport.lowercased()
        if !isSupportedMCPTransport(transport, toolID: surface.toolID) {
            issues.append(issue(.serverUnsupportedTransport, .error, surface, "Unsupported transport", "\"\(server.name)\" uses transport \"\(server.transport)\".", "Use stdio, http, streamable-http, sse, or streamable_http where the target tool supports it."))
        }
        if surface.id == "claude-desktop-json-mcp", transport != "stdio" {
            issues.append(issue(.serverUnsupportedTransport, .error, surface, "Remote server in Claude Desktop JSON", "Claude Desktop does not connect to remote MCP servers configured directly through claude_desktop_config.json.", "Move remote servers to Claude Desktop Settings > Connectors; keep claude_desktop_config.json for local stdio servers."))
        }

        let launch = MCPLaunchNormalizer.metadata(command: config["command"], args: stringArray(config["args"]))
        let inputVariables = inputVariableReferences(in: config)
        let resolvedCwd = normalizedCWD(config["cwd"] ?? config["workingDirectory"] ?? config["working_directory"])
            .flatMap { resolvedCWD($0, configPath: surface.path) }
        if let cwd = normalizedCWD(config["cwd"] ?? config["workingDirectory"] ?? config["working_directory"]),
           cwdNeedsMissingDirectoryWarning(cwd, configPath: surface.path) {
            issues.append(issue(
                .serverPathMissing,
                .error,
                surface,
                "Working directory not found",
                "\"\(server.name)\" declares cwd \(cwd), but Project Hub could not resolve it to an existing directory.",
                "Create the directory or update the MCP cwd/working-directory setting before verifying this server."
            ))
        }
        if let command = launch.command, !command.isEmpty {
            let missingCommandVars = missingRequiredEnvExpansionNames(in: command)
            let commandInputVariables = inputVariableReferences(in: command)
            if missingCommandVars.isEmpty, commandInputVariables.isEmpty, !commandExists(expandEnvRefs(command), cwd: resolvedCwd) {
                if surface.id == "claude-desktop-dxt" {
                    issues.append(issue(.serverRuntimeManaged, .info, surface, "Extension runtime is app-managed", "\"\(server.name)\" launches through \"\(command)\", which may be provided by Claude Desktop's extension runtime rather than Project Hub's shell PATH.", "Verify this extension from Claude Desktop Settings > Extensions."))
                } else {
                    let expandedCommand = expandEnvRefs(command)
                    issues.append(issue(.serverCommandMissing, .error, surface, "Command not found", "\"\(server.name)\" launches \"\(expandedCommand)\", but that command was not found on PATH or at an absolute path.", "Install the runtime/package manager or change the config path."))
                }
            }
        } else if config["url"] == nil {
            issues.append(issue(.serverMissingLaunchTarget, .error, surface, "Missing command or URL", "\"\(server.name)\" has neither command nor url.", "Add a local command or remote MCP URL."))
        }

        let missingDockerPathVars = dockerMissingPathEnvVars(command: launch.command, args: launch.args)
        for missing in missingDockerPathVars {
            issues.append(issue(
                .serverEnvMissing,
                .error,
                surface,
                "Missing Docker path variable",
                "\"\(server.name)\" references Docker --env-file or mount path variable \(missing), but it is not set in the current environment.",
                "Set the environment variable used by the Docker path before verifying this MCP server."
            ))
        }
        let missingDockerEnvFiles = dockerMissingEnvFiles(command: launch.command, args: launch.args, cwd: resolvedCwd, configPath: surface.path)
        for path in missingDockerEnvFiles {
            issues.append(issue(
                .serverEnvMissing,
                .error,
                surface,
                "Missing Docker env file",
                "\"\(server.name)\" references Docker --env-file \(path), but Project Hub could not find a readable file there.",
                "Create the env file or update the Docker --env-file path before verifying this MCP server."
            ))
        }
        let missingDockerMounts = dockerMissingMountPaths(command: launch.command, args: launch.args, cwd: resolvedCwd, configPath: surface.path)
        for path in missingDockerMounts {
            issues.append(issue(
                .serverPathMissing,
                .error,
                surface,
                "Missing Docker mount path",
                "\"\(server.name)\" mounts host path \(path), but Project Hub could not find it.",
                "Create the host path or update the Docker volume/bind mount before verifying this MCP server."
            ))
        }

        let envFile = normalizedEnvFile(config["envFile"] ?? config["env_file"])
        let missingEnvFilePathVars = envFile.map(missingRequiredEnvExpansionNames(in:)) ?? []
        for missing in missingEnvironmentVariables(in: config, excludingEnvFileReferences: envFile != nil)
            where !missingDockerPathVars.contains(missing) {
            issues.append(issue(.serverEnvMissing, .error, surface, "Missing environment variable", "\"\(server.name)\" references \(missing), but it is not set in the current environment.", "Add the variable in the target app's launch environment or replace it with a secure configured value."))
        }
        issues.append(contentsOf: codexLiteralEnvTemplateIssues(in: config, serverName: server.name, surface: surface))
        if !missingEnvFilePathVars.isEmpty {
            issues.append(issue(
                .serverEnvMissing,
                .error,
                surface,
                "Missing envFile path variable",
                "\"\(server.name)\" references envFile \(envFile ?? "") but the path variable \(missingEnvFilePathVars.joined(separator: ", ")) is not set.",
                "Set the environment variable used by envFile before launching the target app, or replace envFile with an explicit path."
            ))
        } else if let envFile {
            let title = envFileNeedsMissingFileWarning(envFile, configPath: surface.path) ? "Missing MCP env file" : "MCP env file requires conversion"
            issues.append(issue(
                .serverEnvMissing,
                .warning,
                surface,
                title,
                "\"\(server.name)\" references envFile \(envFile). VS Code can load this file, but Claude/Codex MCP configs do not share that app-specific env-file behavior.",
                "Create the env file for the owning app or convert required values into environment variables/header mappings supported by the target Claude/Codex surface before copying this config."
            ))
        }
        if boolValue(config["sandboxEnabled"] ?? config["sandbox_enabled"]) == true || config["sandbox"] != nil {
            let summary = configSummary(config["sandbox"]).map { " Sandbox: \($0)." } ?? ""
            issues.append(issue(
                .serverRuntimeManaged,
                .warning,
                surface,
                "VS Code MCP sandbox is app-specific",
                "\"\(server.name)\" declares VS Code MCP sandbox settings.\(summary) Claude and Codex MCP configs do not share VS Code's sandbox enforcement or auto-approved tool confirmation behavior.",
                "Keep this server in VS Code for sandboxed execution, or recreate equivalent restrictions using the target tool's own permissions before copying it."
            ))
        }
        if let dev = configSummary(config["dev"]) {
            issues.append(issue(
                .serverRuntimeManaged,
                .info,
                surface,
                "VS Code MCP dev mode is app-specific",
                "\"\(server.name)\" declares VS Code MCP dev mode \(dev), which controls VS Code restart/watch/debug behavior and is not a portable Claude/Codex MCP setting.",
                "Use VS Code for that development workflow, or configure restart/debug behavior manually in the target tool."
            ))
        }
        let alwaysAllow = stringArray(config["alwaysAllow"] ?? config["always_allow"])
        let disabledTools = stringArray(config["disabledTools"] ?? config["disabled_tools"])
        let watchPaths = stringArray(config["watchPaths"] ?? config["watch_paths"])
        if (!alwaysAllow.isEmpty || !disabledTools.isEmpty || !watchPaths.isEmpty || config["timeout"] != nil)
            && !isCodexMCPSurface(surface) {
            var details: [String] = []
            if !alwaysAllow.isEmpty { details.append("alwaysAllow: \(alwaysAllow.joined(separator: ", "))") }
            if !disabledTools.isEmpty { details.append("disabledTools: \(disabledTools.joined(separator: ", "))") }
            if !watchPaths.isEmpty { details.append("watchPaths: \(watchPaths.joined(separator: ", "))") }
            if let timeout = codexNumber(config["timeout"]) { details.append("timeout: \(Int(timeout))s") }
            issues.append(issue(
                .serverRuntimeManaged,
                .warning,
                surface,
                "Roo MCP tool controls are app-specific",
                "\"\(server.name)\" declares Roo Code MCP runtime/tool-control settings\(details.isEmpty ? "." : ": \(details.joined(separator: "; ")).") These settings affect Roo approval, tool visibility, restart watching, or network timeout and are not portable Claude/Codex MCP semantics.",
                "Keep these controls in Roo, or recreate equivalent restrictions with the target tool's own approval, permission, or timeout settings before copying this server."
            ))
        }
        if !inputVariables.isEmpty {
            issues.append(issue(
                .serverAuthMissing,
                .warning,
                surface,
                "Input variable prompt required",
                "\"\(server.name)\" references input variables: \(inputVariables.joined(separator: ", ")). These are prompt-backed app inputs, not normal environment variables.",
                "Open the owning app so it can prompt for the values, or replace them with environment-backed values supported by Claude/Codex before copying this config across tools."
            ))
        }

        if let helper = normalizedHeadersHelper(config["headersHelper"] as? String) {
            issues.append(issue(
                .serverAuthRuntimeManaged,
                .info,
                surface,
                "Auth managed by Claude Code headersHelper",
                "\"\(server.name)\" uses Claude Code headersHelper for runtime authentication.",
                "Project Hub does not execute arbitrary helper commands. Verify this server in Claude Code /mcp. Helper: \(helper)"
            ))
        }
        if let oauth = oauthConfig(config["oauth"]) {
            let keys = oauth.keys.sorted().joined(separator: ", ")
            issues.append(issue(
                .serverAuthRuntimeManaged,
                .info,
                surface,
                "Auth managed by target tool OAuth",
                "\"\(server.name)\" declares app-owned OAuth metadata\(keys.isEmpty ? "." : ": \(keys).")",
                "Project Hub preserves this OAuth configuration but does not complete browser login itself. Verify the server in the target tool's MCP panel."
            ))
        }

        if let authIssue = missingAuthIssue(in: config, serverName: server.name, surface: surface) {
            issues.append(authIssue)
        }

        if surface.toolID == .claudeDesktop && !server.disabled {
            issues.append(contentsOf: inspectClaudeDesktopLog(server, surface: surface))
        }

        if surface.id == "claude-desktop-dxt" && !server.disabled && issues.isEmpty {
            issues.append(issue(.serverRuntimeManaged, .info, surface, "Extension health is app-managed", "\"\(server.name)\" parsed cleanly as a Claude Desktop extension. Project Hub does not launch Desktop-managed extensions directly.", "Verify this extension from Claude Desktop Settings > Extensions, then rescan."))
            return issues
        }

        if !server.disabled && issues.isEmpty {
            issues.append(issue(.serverHealthUnknown, .info, surface, "Handshake not yet verified", "\"\(server.name)\" parsed cleanly, but Project Hub has not performed an MCP initialize/tools handshake yet.", "Run a live health check before marking this server working."))
        }

        return issues
    }

    private enum ClaudeMCPPolicyRuleKind {
        case name(String)
        case url(String)
        case command([String])
    }

    private struct ClaudeMCPPolicyRule {
        let kind: ClaudeMCPPolicyRuleKind
        let sourcePath: String
    }

    private struct ClaudeMCPPolicy {
        var managedMCPActive = false
        var managedMCPPaths: [String] = []
        var allowlistDefined = false
        var allowRules: [ClaudeMCPPolicyRule] = []
        var denyRules: [ClaudeMCPPolicyRule] = []
    }

    private static func claudeCodeMCPPolicy(from matrix: [CompatibilityMatrixEntry]) -> ClaudeMCPPolicy {
        var policy = ClaudeMCPPolicy()
        var allAllowRules: [ClaudeMCPPolicyRule] = []
        var managedAllowRules: [ClaudeMCPPolicyRule] = []
        var allAllowlistDefined = false
        var managedAllowlistDefined = false
        var managedOnlyAllowlist = false
        let activeManagedSettingSources = activeClaudeCodeManagedSettingsSources(in: matrix)

        for surface in matrix where surface.toolID == .claudeCode {
            guard let path = surface.path else { continue }
            if surface.kind == .mcp,
               surface.id.hasPrefix("claude-code-managed-mcp"),
               FileManager.default.fileExists(atPath: path),
               let root = readJSONDictionary(at: path),
               root["mcpServers"] is [String: Any] {
                policy.managedMCPActive = true
                policy.managedMCPPaths.append(path)
            }

            guard surface.kind == .settings,
                  let root = claudeCodeSettingsDictionary(for: surface) else {
                continue
            }
            guard !surface.id.hasPrefix("claude-code-local-project-state") else {
                continue
            }

            let managedSource = activeManagedSettingSources.contains(surface.id)
            let allow = claudeMCPPolicyRules(root["allowedMcpServers"], sourcePath: path)
            if allow.defined {
                allAllowlistDefined = true
                allAllowRules.append(contentsOf: allow.rules)
                if managedSource {
                    managedAllowlistDefined = true
                    managedAllowRules.append(contentsOf: allow.rules)
                }
            }
            let deny = claudeMCPPolicyRules(root["deniedMcpServers"], sourcePath: path)
            policy.denyRules.append(contentsOf: deny.rules)
            if managedSource, boolSetting("allowManagedMcpServersOnly", in: root) == true {
                managedOnlyAllowlist = true
            }
        }

        policy.managedMCPPaths = uniqueStringsPreservingOrder(policy.managedMCPPaths)
        if managedOnlyAllowlist {
            policy.allowlistDefined = managedAllowlistDefined
            policy.allowRules = managedAllowRules
        } else {
            policy.allowlistDefined = allAllowlistDefined
            policy.allowRules = allAllowRules
        }
        return policy
    }

    private static func activeClaudeCodeManagedSettingsSources(in matrix: [CompatibilityMatrixEntry]) -> Set<String> {
        let existingServerManagedSources = matrix
            .filter { isClaudeCodeServerManagedSettingsSurface($0) && claudeCodeSettingsDictionary(for: $0)?.isEmpty == false }
            .map(\.id)
        if !existingServerManagedSources.isEmpty {
            return Set(existingServerManagedSources)
        }

        let existingPlistSources = matrix
            .filter { isClaudeCodeManagedPreferencesSurface($0) && claudeCodeSettingsDictionary(for: $0)?.isEmpty == false }
            .map(\.id)
        if !existingPlistSources.isEmpty {
            return Set(existingPlistSources)
        }

        return Set(matrix
            .filter { isClaudeCodeManagedSettingsFileSurface($0) && claudeCodeSettingsDictionary(for: $0)?.isEmpty == false }
            .map(\.id))
    }

    private static func claudeCodeSettingsDictionary(for surface: CompatibilityMatrixEntry) -> [String: Any]? {
        guard surface.toolID == .claudeCode,
              surface.kind == .settings,
              let path = surface.path else {
            return nil
        }
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        if surface.id.hasPrefix("claude-code-local-project-state") {
            guard let root = readJSONDictionary(at: path) else { return nil }
            return claudeProjectState(from: surface, root: root)
        }

        switch surface.format {
        case .json, .jsonc:
            return readJSONDictionary(at: path)
        case .plist:
            return readPlistFile(path)
        default:
            return nil
        }
    }

    private static func isClaudeCodeManagedSettingsSurface(_ surface: CompatibilityMatrixEntry) -> Bool {
        isClaudeCodeServerManagedSettingsSurface(surface)
            || isClaudeCodeManagedSettingsFileSurface(surface)
            || isClaudeCodeManagedPreferencesSurface(surface)
    }

    private static func isClaudeCodeServerManagedSettingsSurface(_ surface: CompatibilityMatrixEntry) -> Bool {
        surface.id == "claude-code-server-managed-settings"
    }

    private static func isClaudeCodeManagedSettingsFileSurface(_ surface: CompatibilityMatrixEntry) -> Bool {
        surface.id.hasPrefix("claude-code-managed-settings")
    }

    private static func isClaudeCodeManagedPreferencesSurface(_ surface: CompatibilityMatrixEntry) -> Bool {
        surface.id.hasPrefix("claude-code-managed-policy")
    }

    private static func claudeMCPPolicyIssue(
        for server: CompatibilityServerObservation,
        surface: CompatibilityMatrixEntry,
        config: [String: Any],
        policy: ClaudeMCPPolicy
    ) -> CompatibilityIssue? {
        guard surface.toolID == .claudeCode, surface.kind == .mcp else { return nil }

        if let denyRule = policy.denyRules.first(where: { claudeMCPPolicyRule($0, matches: server, config: config) }) {
            return issue(
                .serverDisabled,
                .warning,
                surface,
                "Claude MCP blocked by denylist",
                "\"\(server.name)\" matches deniedMcpServers from \(tilde(denyRule.sourcePath)). Claude Code blocks denylisted MCP servers even when another allowlist also matches.",
                "Remove or change the denylist entry in the owning settings file before offering enable or health fixes.",
                subjectPath: server.name
            )
        }

        if policy.managedMCPActive && !surface.id.hasPrefix("claude-code-managed-mcp") {
            let source = policy.managedMCPPaths.first.map(tilde) ?? "managed-mcp.json"
            return issue(
                .serverDisabled,
                .warning,
                surface,
                "Claude MCP blocked by managed MCP",
                "\"\(server.name)\" is configured outside the active managed MCP file at \(source). When managed-mcp.json is present, Claude Code loads only administrator-managed MCP servers.",
                "Treat this server as unavailable in Claude Code until managed-mcp.json is changed or removed.",
                subjectPath: server.name
            )
        }

        guard policy.allowlistDefined else { return nil }
        if claudeMCPPolicyAllows(server: server, config: config, policy: policy) {
            return nil
        }
        return issue(
            .serverDisabled,
            .warning,
            surface,
            "Claude MCP blocked by allowlist",
            "\"\(server.name)\" does not match the effective allowedMcpServers policy. Claude Code silently omits previously configured servers that no longer pass MCP policy.",
            "Add a matching serverUrl or exact serverCommand entry to the effective allowlist, or remove the allowlist restriction.",
            subjectPath: server.name
        )
    }

    private static func claudeMCPPolicyAllows(
        server: CompatibilityServerObservation,
        config: [String: Any],
        policy: ClaudeMCPPolicy
    ) -> Bool {
        let transport = server.transport.lowercased()
        let remote = (config["url"] as? String) != nil || isRemoteMCPTransport(transport)
        if remote {
            let urlRules = policy.allowRules.filter {
                if case .url = $0.kind { return true }
                return false
            }
            if !urlRules.isEmpty {
                return urlRules.contains { claudeMCPPolicyRule($0, matches: server, config: config) }
            }
        } else {
            let commandRules = policy.allowRules.filter {
                if case .command = $0.kind { return true }
                return false
            }
            if !commandRules.isEmpty {
                return commandRules.contains { claudeMCPPolicyRule($0, matches: server, config: config) }
            }
        }

        return policy.allowRules.contains { rule in
            guard case .name = rule.kind else { return false }
            return claudeMCPPolicyRule(rule, matches: server, config: config)
        }
    }

    private static func isSupportedMCPTransport(_ transport: String, toolID: CompatibilityToolID? = nil) -> Bool {
        switch transport.lowercased() {
        case "stdio", "http", "https", "remote", "sse", "streamable_http", "streamable-http", "streamablehttp":
            return true
        case "ws":
            return toolID == .claudeCode
        default:
            return false
        }
    }

    private static func isRemoteMCPTransport(_ transport: String) -> Bool {
        switch transport.lowercased() {
        case "http", "https", "remote", "sse", "streamable_http", "streamable-http", "streamablehttp", "ws":
            return true
        default:
            return false
        }
    }

    private static func claudeMCPPolicyRule(
        _ rule: ClaudeMCPPolicyRule,
        matches server: CompatibilityServerObservation,
        config: [String: Any]
    ) -> Bool {
        switch rule.kind {
        case .name(let name):
            return server.name == name
        case .url(let pattern):
            guard let url = config["url"] as? String else { return false }
            return claudeMCPURL(url, matches: pattern)
        case .command(let expected):
            guard !expected.isEmpty else { return false }
            let launch = launchCommand(from: config)
            return ([launch.command].compactMap { $0 } + launch.args) == expected
        }
    }

    private static func claudeMCPPolicyRules(_ value: Any?, sourcePath: String) -> (defined: Bool, rules: [ClaudeMCPPolicyRule]) {
        guard let value else { return (false, []) }
        guard let entries = value as? [Any] else {
            return (true, [])
        }
        let rules = entries.compactMap { entry -> ClaudeMCPPolicyRule? in
            if let name = entry as? String, !name.isEmpty {
                return ClaudeMCPPolicyRule(kind: .name(name), sourcePath: sourcePath)
            }
            guard let object = entry as? [String: Any], object.count == 1 else { return nil }
            if let name = object["serverName"] as? String, !name.isEmpty {
                return ClaudeMCPPolicyRule(kind: .name(name), sourcePath: sourcePath)
            }
            if let url = object["serverUrl"] as? String, !url.isEmpty {
                return ClaudeMCPPolicyRule(kind: .url(url), sourcePath: sourcePath)
            }
            if let command = object["serverCommand"] as? [String], !command.isEmpty {
                return ClaudeMCPPolicyRule(kind: .command(command), sourcePath: sourcePath)
            }
            if let command = object["serverCommand"] as? [Any] {
                let parts = command.compactMap { $0 as? String }
                return parts.isEmpty ? nil : ClaudeMCPPolicyRule(kind: .command(parts), sourcePath: sourcePath)
            }
            if let command = object["serverCommand"] as? String, !command.isEmpty {
                let parts = shellSplit(command)
                return parts.isEmpty ? nil : ClaudeMCPPolicyRule(kind: .command(parts), sourcePath: sourcePath)
            }
            return nil
        }
        return (true, rules)
    }

    private static func claudeLocalProjectPolicyEvidenceKeys(in root: [String: Any]) -> [String] {
        let knownRuntimeKeys = Set([
            "additionalDirectories",
            "allowedTools",
            "disabledMcpServers",
            "disabledMcpjsonServers",
            "dontCrawlDirectory",
            "enableAllProjectMcpServers",
            "enabledMcpjsonServers",
            "hasClaudeMdExternalIncludesApproved",
            "hasClaudeMdExternalIncludesWarningShown",
            "hasTrustDialogAccepted",
            "ignorePatterns",
            "lastSessionId",
            "lastSessionModified",
            "mcpContextUris",
            "mcpServers",
            "mcpServers_disabled",
            "permissions"
        ])
        var matches: [String] = []

        func visit(_ value: Any, path: String, depth: Int) {
            guard depth <= 3 else { return }
            if let dict = value as? [String: Any] {
                for key in dict.keys.sorted() {
                    let childPath = path.isEmpty ? key : "\(path).\(key)"
                    if path.isEmpty, knownRuntimeKeys.contains(key) {
                        if key == "permissions", let permissions = dict[key] as? [String: Any] {
                            visit(permissions, path: childPath, depth: depth + 1)
                        }
                        continue
                    }
                    if claudeLocalProjectStateKeyLooksPolicyRelated(key) {
                        matches.append(childPath)
                    }
                    if let child = dict[key] {
                        visit(child, path: childPath, depth: depth + 1)
                    }
                }
            } else if let array = value as? [Any] {
                for item in array {
                    visit(item, path: path, depth: depth + 1)
                }
            }
        }

        visit(root, path: "", depth: 0)
        return uniqueStringsPreservingOrder(matches)
    }

    private static func claudeLocalProjectStateKeyLooksPolicyRelated(_ key: String) -> Bool {
        let lower = key.lowercased()
        if [
            "allowedmcpservers",
            "deniedmcpservers",
            "allowmanagedmcpserversonly",
            "allowmanagedpermissionrulesonly",
            "strictpluginonlycustomization"
        ].contains(lower) {
            return true
        }
        if lower.contains("policy") || lower.contains("managed") || lower.contains("enterprise") {
            return true
        }
        if lower.hasPrefix("org") || lower.contains("organization") {
            return true
        }
        if lower.hasPrefix("account") && (lower.contains("control") || lower.contains("restriction") || lower.contains("managed")) {
            return true
        }
        return false
    }

    private static func claudeMCPURL(_ url: String, matches pattern: String) -> Bool {
        let normalizedURL = normalizedClaudeMCPPolicyURL(url)
        let normalizedPattern = normalizedClaudeMCPPolicyURL(pattern)
        guard !normalizedURL.isEmpty, !normalizedPattern.isEmpty else { return false }

        if normalizedPattern.contains("*") {
            let escaped = NSRegularExpression.escapedPattern(for: normalizedPattern)
                .replacingOccurrences(of: "\\*", with: ".*")
            guard let regex = try? NSRegularExpression(pattern: "^\(escaped)$") else { return false }
            let range = NSRange(location: 0, length: (normalizedURL as NSString).length)
            return regex.firstMatch(in: normalizedURL, range: range) != nil
        }

        guard let patternComponents = URLComponents(string: normalizedPattern),
              let urlComponents = URLComponents(string: normalizedURL) else {
            return normalizedURL == normalizedPattern
        }

        guard patternComponents.scheme == urlComponents.scheme,
              normalizedHost(patternComponents.host) == normalizedHost(urlComponents.host),
              patternComponents.port == urlComponents.port else {
            return false
        }
        if patternComponents.path.isEmpty {
            return true
        }
        return patternComponents.path == urlComponents.path
            && (patternComponents.query ?? "") == (urlComponents.query ?? "")
    }

    private static func normalizedClaudeMCPPolicyURL(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed) else {
            return trimmed
        }
        components.scheme = components.scheme?.lowercased()
        components.host = normalizedHost(components.host)
        return components.string ?? trimmed
    }

    private static func normalizedHost(_ host: String?) -> String? {
        host?.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
    }

    private static func readServerConfig(
        _ server: CompatibilityServerObservation,
        surface: CompatibilityMatrixEntry,
        matrix: [CompatibilityMatrixEntry]? = nil
    ) -> [String: Any]? {
        guard let path = surface.path else { return nil }
        switch surface.format {
        case .json, .jsonc:
            guard let raw = try? String(contentsOfFile: path, encoding: .utf8),
                  let data = ConfigWriter.stripJsonComments(raw).data(using: .utf8),
                  var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            if isCodexPluginMCPSurface(surface),
               let serverMap = codexPluginMCPServerMap(root),
               let config = serverMap[server.name] {
                let pluginRoot = codexPluginRootForMCPConfig(path)
                return resolveCodexPluginMCPConfig(config, pluginRoot: pluginRoot) as? [String: Any] ?? config
            }
            if isClaudePluginMCPSurface(surface),
               let pluginRoot = surface.path.map(claudePluginRootForMCPConfig) {
                root = replaceClaudePluginPlaceholders(in: root, pluginRoot: pluginRoot) as? [String: Any] ?? root
            }
            if surface.id.hasPrefix("claude-code-local-mcp"),
               let projectRoot = claudeLocalProjectRoot(from: surface),
               let projectState = claudeProjectState(projectRoot: projectRoot, root: root) {
                let key = server.disabled ? "mcpServers_disabled" : "mcpServers"
                if let config = (projectState[key] as? [String: Any])?[server.name] as? [String: Any] {
                    return config
                }
                return (projectState["mcpServers"] as? [String: Any])?[server.name] as? [String: Any]
            }
            if server.disabled,
               let disabledConfig = (root["mcpServers_disabled"] as? [String: Any])?[server.name] as? [String: Any] {
                return disabledConfig
            }
            return (root["mcpServers"] as? [String: Any])?[server.name] as? [String: Any]
        case .toml:
            if isCodexProjectMCPLayer(server),
               let matrix,
               let merged = effectiveCodexProjectMCPConfig(
                serverName: server.name,
                toolID: server.toolID,
                through: surface,
                matrix: matrix
               ) {
                return merged
            }
            return parseMCPServersTOML((try? String(contentsOfFile: path, encoding: .utf8)) ?? "").servers[server.name]
        case .directory:
            guard surface.id == "claude-desktop-dxt" else { return nil }
            let extensionDir: String
            if (server.path as NSString).lastPathComponent == "manifest.json" || (server.path as NSString).lastPathComponent == "manifest.mcpb.json" {
                extensionDir = (server.path as NSString).deletingLastPathComponent
            } else {
                extensionDir = server.path
            }
            guard let manifestPath = claudeDesktopExtensionManifestPath(in: extensionDir) else { return nil }
            guard let manifest = readJSONFile(manifestPath) else { return nil }
            let extensionID = URL(fileURLWithPath: extensionDir).lastPathComponent
            return claudeDesktopExtensionMCPConfig(
                manifest: manifest,
                extensionDir: extensionDir,
                settings: claudeDesktopExtensionSettings(extensionID: extensionID)
            )
        case .plist:
            return nil
        default:
            return nil
        }
    }

    private static func effectiveCodexProjectMCPConfig(
        serverName: String,
        toolID: CompatibilityToolID,
        through surface: CompatibilityMatrixEntry,
        matrix: [CompatibilityMatrixEntry]
    ) -> [String: Any]? {
        let layers = matrix
            .filter {
                $0.toolID == toolID
                    && $0.kind == .mcp
                    && $0.scope == .project
                    && $0.path?.hasSuffix("/.codex/config.toml") == true
                    && $0.precedence <= surface.precedence
            }
            .sorted {
                if $0.precedence != $1.precedence { return $0.precedence < $1.precedence }
                return ($0.path ?? "").localizedCaseInsensitiveCompare($1.path ?? "") == .orderedAscending
            }

        var merged: [String: Any] = [:]
        for layer in layers {
            guard let path = layer.path,
                  let config = parseMCPServersTOML((try? String(contentsOfFile: path, encoding: .utf8)) ?? "")
                    .servers[serverName] else {
                continue
            }
            merged = mergeCodexProjectMCPConfig(merged, overriding: config)
        }
        return merged.isEmpty ? nil : merged
    }

    private static func mergeCodexProjectMCPConfig(
        _ base: [String: Any],
        overriding overlay: [String: Any]
    ) -> [String: Any] {
        var merged = base
        for (key, value) in overlay {
            if let baseDict = merged[key] as? [String: Any],
               let overlayDict = value as? [String: Any] {
                merged[key] = mergeCodexProjectMCPConfig(baseDict, overriding: overlayDict)
            } else {
                merged[key] = value
            }
        }
        return merged
    }

    static func healthEntry(
        for server: CompatibilityServerObservation,
        matrix: [CompatibilityMatrixEntry]
    ) -> ServerEntry? {
        guard let surface = matrix.first(where: { $0.id == server.surfaceID }),
              let config = readServerConfig(server, surface: surface, matrix: matrix) else { return nil }
        if surface.id == "claude-desktop-dxt" { return nil }
        return serverEntry(from: config, server: server, surface: surface, readOnly: false)
    }

    private static func mcpInventoryRow(
        for server: CompatibilityServerObservation,
        surface: CompatibilityMatrixEntry,
        matrix: [CompatibilityMatrixEntry]
    ) -> CompatibilityMCPInventoryRow? {
        guard let appToolID = appToolID(for: server.toolID),
              let config = readServerConfig(server, surface: surface, matrix: matrix) else {
            return nil
        }
        let entry = serverEntry(from: config, server: server, surface: surface, readOnly: true)
        return CompatibilityMCPInventoryRow(
            appToolID: appToolID,
            toolID: server.toolID,
            surfaceID: surface.id,
            surfaceLabel: surface.label,
            scope: surface.scope,
            path: surface.path,
            canWriteSafely: surface.canWriteSafely,
            writeMethod: surface.writeMethod,
            server: entry
        )
    }

    private static func appToolID(for toolID: CompatibilityToolID) -> String? {
        switch toolID {
        case .claudeCode: return "claude-code"
        case .claudeDesktop: return "claude-desktop"
        case .codexCLI, .codexDesktop: return "codex"
        }
    }

    private static func serverEntry(
        from config: [String: Any],
        server: CompatibilityServerObservation,
        surface: CompatibilityMatrixEntry,
        readOnly: Bool
    ) -> ServerEntry {
        let launch = MCPLaunchNormalizer.metadata(command: config["command"], args: stringArray(config["args"]))
        let command = launch.command
        let args = launch.args
        let url = config["url"] as? String
        var env = stringDict(config["env"])
        env.merge(launch.env) { current, _ in current }
        var headers = stringDict(config["headers"])
        headers.merge(stringDict(config["http_headers"])) { _, new in new }
        for (header, envName) in stringDict(config["env_http_headers"]) {
            headers[header] = "${\(envName)}"
        }
        let transport: String
        if let type = config["type"] as? String { transport = type }
        else if url != nil { transport = "http" }
        else { transport = "stdio" }
        return ServerEntry(
            name: server.name,
            transport: transport,
            command: command,
            args: args,
            cwd: normalizedCWD(config["cwd"] ?? config["workingDirectory"] ?? config["working_directory"]),
            url: url,
            env: env,
            headers: headers,
            headersHelper: config["headersHelper"] as? String,
            oauth: oauthMetadata(config["oauth"]),
            bearerTokenEnvVar: config["bearer_token_env_var"] as? String,
            envVars: codexLocalEnvVars(config["env_vars"]),
            envFile: normalizedEnvFile(config["envFile"] ?? config["env_file"]) ?? launch.envFile,
            sandboxEnabled: boolValue(config["sandboxEnabled"] ?? config["sandbox_enabled"]),
            sandboxSummary: configSummary(config["sandbox"]),
            devSummary: configSummary(config["dev"]),
            enabledTools: stringArray(config["enabledTools"] ?? config["enabled_tools"]),
            alwaysAllowTools: stringArray(config["alwaysAllow"] ?? config["always_allow"]),
            disabledTools: stringArray(config["disabledTools"] ?? config["disabled_tools"]),
            defaultToolApprovalMode: config["defaultToolApprovalMode"] as? String ?? config["default_tools_approval_mode"] as? String,
            toolApprovalModes: toolApprovalModes(from: config),
            watchPaths: stringArray(config["watchPaths"] ?? config["watch_paths"]),
            serverTimeoutSeconds: codexNumber(config["timeout"]),
            startupTimeoutSeconds: codexStartupTimeoutSeconds(from: config) ?? server.startupTimeoutSeconds,
            toolTimeoutSeconds: codexNumber(config["tool_timeout_sec"]) ?? codexNumber(config["timeout"]) ?? server.toolTimeoutSeconds,
            sourcePath: server.path,
            sourceLabel: surface.label,
            isReadOnly: readOnly,
            readOnlyReason: readOnly
                ? "Scanned from \(surface.label). This compatibility surface is read-only in the MCP manager; use the Compatibility tab or the owning app/config to change it."
                : nil,
            isDisabled: server.disabled
        )
    }

    private static func healthState(for server: CompatibilityServerObservation, issueCodes: [CompatibilityIssueCode]) -> CompatibilityHealthState {
        if server.disabled || issueCodes.contains(.serverDisabled) { return .disabled }
        if issueCodes.contains(.serverConflictDifferentConfig) || issueCodes.contains(.serverShadowedByProjectLayer) { return .conflict }
        if issueCodes.contains(.serverAuthExpired) { return .authExpired }
        if issueCodes.contains(.serverAuthMissing) || issueCodes.contains(.serverOAuthNeeded) || issueCodes.contains(.serverEnvMissing) { return .needsAuth }
        if issueCodes.contains(.serverCommandMissing) || issueCodes.contains(.serverMissingLaunchTarget) || issueCodes.contains(.serverPathMissing) || issueCodes.contains(.serverUnsupportedTransport) || issueCodes.contains(.serverReservedName) { return .broken }
        if issueCodes.contains(.serverNeedsRestart) { return .needsRestart }
        return .unknown
    }

    private static func detectConflicts(in servers: inout [CompatibilityServerObservation]) -> [CompatibilityIssue] {
        let groups = Dictionary(grouping: servers) { "\($0.toolID.rawValue):\($0.name)" }
        var issues: [CompatibilityIssue] = []

        for (_, group) in groups where group.count > 1 {
            if let shadowing = codexProjectLayerShadowingIssue(in: group, servers: &servers) {
                issues.append(contentsOf: shadowing)
                continue
            }

            let fingerprints = Set(group.map(\.fingerprint))
            guard fingerprints.count > 1 else {
                for server in group {
                    if let index = servers.firstIndex(where: { $0.id == server.id }) {
                        servers[index].issueCodes.append(.serverDuplicateName)
                    }
                }
                continue
            }

            for server in group {
                if let index = servers.firstIndex(where: { $0.id == server.id }) {
                    servers[index].issueCodes.append(.serverConflictDifferentConfig)
                    servers[index].health = .conflict
                }
            }
            if let first = group.first {
                issues.append(CompatibilityIssue(
                    id: UUID(),
                    code: .serverConflictDifferentConfig,
                    severity: .warning,
                    toolID: first.toolID,
                    surfaceID: nil,
                    title: "Conflicting MCP server definitions",
                    detail: "\"\(first.name)\" exists in multiple \(first.toolID.label) scopes with different configurations. Precedence decides which one wins.",
                    path: first.path,
                    subjectPath: nil,
                    fixHint: "Show each definition, then let the user rename, remove, copy, or intentionally override."
                ))
            }
        }

        return issues
    }

    private static func codexProjectLayerShadowingIssue(
        in group: [CompatibilityServerObservation],
        servers: inout [CompatibilityServerObservation]
    ) -> [CompatibilityIssue]? {
        guard group.count > 1,
              group.allSatisfy({ isCodexProjectMCPLayer($0) }) else { return nil }

        let sorted = group.sorted { lhs, rhs in
            let lhsDepth = codexProjectConfigDepth(lhs.path)
            let rhsDepth = codexProjectConfigDepth(rhs.path)
            if lhsDepth != rhsDepth { return lhsDepth < rhsDepth }
            return lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
        }
        var issues: [CompatibilityIssue] = []
        for (index, server) in sorted.enumerated().dropLast() {
            let serverConfig = flattenedConfigLeaves(codexProjectLayerMCPConfig(server))
            let deeper = sorted.dropFirst(index + 1)
            let deeperOverrides = deeper.compactMap { deeperServer -> (server: CompatibilityServerObservation, keys: [String])? in
                let deeperConfig = flattenedConfigLeaves(codexProjectLayerMCPConfig(deeperServer))
                let overlapping = serverConfig.keys
                    .filter { key in
                        guard let lhs = serverConfig[key],
                               let rhs = deeperConfig[key],
                              "\(lhs)" != "\(rhs)" else { return false }
                        return true
                    }
                    .sorted()
                guard !overlapping.isEmpty else { return nil }
                return (deeperServer, overlapping)
            }
            guard let closestOverride = deeperOverrides.last else { continue }

            if let index = servers.firstIndex(where: { $0.id == server.id }) {
                servers[index].issueCodes.append(.serverShadowedByProjectLayer)
                servers[index].health = .conflict
            }

            issues.append(CompatibilityIssue(
                id: UUID(),
                code: .serverShadowedByProjectLayer,
                severity: .warning,
                toolID: server.toolID,
                surfaceID: server.surfaceID,
                title: "Codex MCP server keys shadowed by closer project layer",
                detail: "\"\(server.name)\" defines \(closestOverride.keys.joined(separator: ", ")) in \(tilde(server.path)), but a closer project layer at \(tilde(closestOverride.server.path)) overrides those key values for this selected path.",
                path: server.path,
                subjectPath: closestOverride.server.path,
                fixHint: "Keep both layers only if the nested folder intentionally overrides these MCP server keys."
            ))
        }

        return issues
    }

    private static func flattenedConfigLeaves(_ config: [String: Any]) -> [String: String] {
        flattenedConfigLeaves(config, prefix: nil)
    }

    private static func flattenedConfigLeaves(_ value: Any, prefix: String?) -> [String: String] {
        if let dict = value as? [String: Any] {
            if dict.isEmpty, let prefix {
                return [prefix: canonicalString(dict)]
            }

            var leaves: [String: String] = [:]
            for key in dict.keys.sorted() {
                let childPrefix = prefix.map { "\($0).\(key)" } ?? key
                leaves.merge(flattenedConfigLeaves(dict[key] ?? "", prefix: childPrefix)) { _, new in new }
            }
            return leaves
        }

        guard let prefix else { return [:] }
        return [prefix: canonicalString(value)]
    }

    private static func codexProjectLayerMCPConfig(_ server: CompatibilityServerObservation) -> [String: Any] {
        parseMCPServersTOML((try? String(contentsOfFile: server.path, encoding: .utf8)) ?? "")
            .servers[server.name] ?? [:]
    }

    private static func isCodexProjectMCPLayer(_ server: CompatibilityServerObservation) -> Bool {
        (server.toolID == .codexCLI || server.toolID == .codexDesktop)
            && server.scope == .project
            && (server.surfaceID.hasPrefix("codex-cli-project-mcp")
                || server.surfaceID.hasPrefix("codex-desktop-project-mcp"))
            && server.path.hasSuffix("/.codex/config.toml")
    }

    private static func isCodexProjectMCPSurface(_ surface: CompatibilityMatrixEntry) -> Bool {
        (surface.toolID == .codexCLI || surface.toolID == .codexDesktop)
            && surface.kind == .mcp
            && surface.scope == .project
            && (surface.id.hasPrefix("codex-cli-project-mcp")
                || surface.id.hasPrefix("codex-desktop-project-mcp"))
            && surface.path?.hasSuffix("/.codex/config.toml") == true
    }

    private static func isCodexMCPSurface(_ surface: CompatibilityMatrixEntry) -> Bool {
        (surface.toolID == .codexCLI || surface.toolID == .codexDesktop)
            && surface.kind == .mcp
    }

    private static func codexProjectConfigDepth(_ path: String) -> Int {
        let configDir = (path as NSString).deletingLastPathComponent
        let layerRoot = (configDir as NSString).deletingLastPathComponent
        return layerRoot.split(separator: "/").count
    }

    // MARK: - Settings and auth

    private struct SettingsRead {
        var settings: [CompatibilitySettingsObservation]
        var issues: [CompatibilityIssue]
    }

    private static func readSettings(
        from surface: CompatibilityMatrixEntry,
        projectRoot: String?,
        codexProfileSelection: CodexProfileSelection?
    ) -> SettingsRead {
        if surface.id == "claude-code-server-managed-settings", surface.path == nil {
            return SettingsRead(settings: [], issues: [
                issue(
                    .settingsManagedRequirement,
                    .info,
                    surface,
                    "Claude Code server-managed settings are runtime-delivered",
                    "Claude Code can receive managed settings from Claude.ai Admin Settings and cache them in remote-settings.json under the active Claude home.",
                    "Open Claude Code /status and look for Enterprise managed settings (remote). Project Hub treats this cache as read-only administrator/runtime evidence."
                )
            ])
        }
        guard let path = surface.path else { return SettingsRead(settings: [], issues: []) }
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else {
            guard isCodexConfiguredInstructionFileSurface(surface) else {
                return SettingsRead(settings: [], issues: [])
            }
            let metadata = codexConfiguredInstructionFileMetadata(from: surface)
            return SettingsRead(settings: [], issues: [
                issue(
                    .configMissing,
                    .warning,
                    surface,
                    "Codex model instructions file missing",
                    "\(surface.label) points to \(tilde(path)), but Project Hub could not find that file.",
                    "Create the referenced file, update model_instructions_file, or remove the override and use AGENTS.md for normal guidance.",
                    subjectPath: metadata["codexInstructionFileKey"],
                    metadata: metadata
                )
            ])
        }

        switch surface.format {
        case .json, .jsonc:
            guard let raw = try? String(contentsOfFile: path, encoding: .utf8),
                  let data = ConfigWriter.stripJsonComments(raw).data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return SettingsRead(settings: [], issues: [
                    issue(.configInvalidJSON, .error, surface, "Invalid settings JSON", "This settings file could not be parsed as JSON/JSONC.", "Fix JSON syntax before Project Hub offers settings changes.")
                ])
            }
            if surface.id.hasPrefix("claude-code-local-project-state") {
                guard let projectState = claudeProjectState(from: surface, root: root) else {
                    return SettingsRead(settings: [], issues: [])
                }
                let keys = projectState.keys.sorted()
                return SettingsRead(
                    settings: [settingsObservation(surface: surface, path: path, keys: keys, summary: claudeLocalProjectStateSummary(projectState))],
                    issues: inspectClaudeSettings(projectState, surface: surface)
                )
            }
            if isCodexPluginManifestSurface(surface) {
                let keys = root.keys.sorted()
                return SettingsRead(
                    settings: [settingsObservation(surface: surface, path: path, keys: keys, summary: codexPluginManifestSummary(root))],
                    issues: inspectCodexPluginManifest(root, surface: surface, path: path)
                )
            }
            if isCodexPluginMarketplaceSurface(surface) {
                let keys = root.keys.sorted()
                return SettingsRead(
                    settings: [settingsObservation(surface: surface, path: path, keys: keys, summary: codexPluginMarketplaceSummary(root))],
                    issues: inspectCodexPluginMarketplace(root, surface: surface)
                )
            }
            let keys = root.keys.sorted()
            var issues = inspectClaudeSettings(root, surface: surface)
            issues.append(contentsOf: inspectClaudeLocalSettingsIgnore(surface: surface))
            return SettingsRead(
                settings: [settingsObservation(surface: surface, path: path, keys: keys, summary: jsonSettingsSummary(keys: keys, surface: surface))],
                issues: issues
            )
        case .toml:
            guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else {
                return SettingsRead(settings: [], issues: [
                    issue(.configUnsupportedShape, .warning, surface, "Could not read settings", "Project Hub could not read this TOML file.", nil)
                ])
            }
            let document = parseSettingsTOMLDocument(raw)
            let keys = codexSettingsKeys(from: document, projectRoot: projectRoot)
            let issues = inspectCodexSettings(
                document,
                surface: surface,
                path: path,
                projectRoot: projectRoot,
                codexProfileSelection: codexProfileSelection
            )
            return SettingsRead(
                settings: [settingsObservation(surface: surface, path: path, keys: keys, summary: tomlSettingsSummary(document, surface: surface, projectRoot: projectRoot))],
                issues: issues
            )
        case .plist:
            guard let root = readPlistFile(path) else {
                let owner: String
                switch surface.toolID {
                case .claudeCode: owner = "Claude Code"
                case .codexDesktop: owner = "Codex Desktop"
                default: owner = "Claude Desktop"
                }
                return SettingsRead(settings: [], issues: [
                    issue(.configUnsupportedShape, .warning, surface, "Invalid preferences plist", "Project Hub could not parse this preferences file as a property-list dictionary.", "Recreate this policy through MDM or \(owner)'s app UI, then scan again.")
                ])
            }
            let keys = root.keys.sorted()
            let issues = surface.toolID == .claudeCode
                ? inspectClaudeSettings(root, surface: surface)
                : inspectClaudeDesktopPolicy(root, surface: surface)
            return SettingsRead(
                settings: [settingsObservation(surface: surface, path: path, keys: keys, summary: plistSettingsSummary(root, surface: surface))],
                issues: issues
            )
        case .markdown:
            guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else {
                return SettingsRead(settings: [], issues: [
                    issue(.configUnsupportedShape, .warning, surface, "Could not read project instructions", "Project Hub could not read this Markdown instruction file.", nil)
                ])
            }
            let headings = markdownHeadings(in: raw)
            let claudeHome = claudeHomeDirectory()
            var issues = inspectClaudeMarkdownContext(
                raw,
                surface: surface,
                path: path,
                projectRoot: projectRoot,
                claudeHome: claudeHome
            )
            if surface.kind == .context && raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let emptyDetail = surface.toolID == .claudeCode
                    ? "\(tilde(path)) exists but contains no usable guidance. Claude Code may receive no project-specific instructions from this file."
                    : "\(tilde(path)) exists but contains no usable guidance. Codex skips empty instruction files."
                issues.append(issue(
                    .contextEmpty,
                    .info,
                    surface,
                    "Instruction file is empty",
                    emptyDetail,
                    "Remove the empty file or add guidance so the target tool can load it."
                ))
            }
            if surface.kind == .context,
               surface.scope == .project,
               [CompatibilityToolID.codexCLI, .codexDesktop].contains(surface.toolID) {
                let codexHome = ProjectHubPaths.codexHome(home: NSHomeDirectory())
                let instructionConfig = codexInstructionConfig(
                    codexHome: codexHome,
                    projectRoot: projectRoot,
                    selectedPath: path,
                    codexProfileSelection: codexProfileSelection,
                    includeProfileFile: surface.toolID == .codexCLI,
                    toolIDs: [surface.toolID]
                )
                let byteCount = raw.utf8.count
                if instructionConfig.projectDocsDisabled {
                    issues.append(issue(
                        .settingsSessionReloadRequired,
                        .info,
                        surface,
                        "Codex project instructions disabled",
                        "\(surface.label) exists, but effective project_doc_max_bytes is 0. Codex will not load project instruction files until this config changes.",
                        "Raise project_doc_max_bytes in the effective Codex config if this guidance should load.",
                        subjectPath: "project_doc_max_bytes",
                        metadata: codexProjectDocMaxBytesMetadata(instructionConfig.projectDocMaxBytesSource)
                    ))
                } else if byteCount > instructionConfig.maxBytes {
                    issues.append(issue(
                        .contextTooLarge,
                        .warning,
                        surface,
                        "Instruction file exceeds Codex limit",
                        "\(tilde(path)) is \(byteCount) bytes, above project_doc_max_bytes (\(instructionConfig.maxBytes)). Codex may truncate or skip later project guidance.",
                        "Raise project_doc_max_bytes in Codex config or split guidance into smaller directory-specific files."
                    ))
                }
            }
            return SettingsRead(
                settings: [settingsObservation(surface: surface, path: path, keys: markdownContextKeys(raw, surface: surface, headings: headings), summary: markdownContextSummary(raw, surface: surface, headings: headings))],
                issues: issues
            )
        case .directory:
            guard let entries = try? fm.contentsOfDirectory(atPath: path) else {
                return SettingsRead(settings: [], issues: [
                    issue(.configUnsupportedShape, .warning, surface, "Could not read settings directory", "Project Hub could not list this settings directory.", nil)
                ])
            }
            let visible = entries
                .filter { !$0.hasPrefix(".") }
                .sorted()
            return SettingsRead(
                settings: [settingsObservation(surface: surface, path: path, keys: visible, summary: directorySettingsSummary(visible, surface: surface))],
                issues: []
            )
        default:
            return SettingsRead(settings: [], issues: [])
        }
    }

    private static func codexPluginManifestSummary(_ root: [String: Any]) -> String {
        var parts: [String] = []
        if root["mcpServers"] != nil { parts.append("MCP bundle") }
        if root["skills"] != nil { parts.append("skills") }
        if root["apps"] != nil { parts.append("apps") }
        if root["hooks"] != nil { parts.append("hooks") }
        if root["interface"] != nil { parts.append("interface metadata") }
        return parts.isEmpty ? "\(root.keys.count) manifest key\(root.keys.count == 1 ? "" : "s")" : parts.joined(separator: ", ")
    }

    private static func codexPluginMarketplaceSummary(_ root: [String: Any]) -> String {
        if let plugins = root["plugins"] as? [Any] {
            return "\(plugins.count) plugin entr\(plugins.count == 1 ? "y" : "ies")"
        }
        if let plugins = root["plugins"] as? [String: Any] {
            return "\(plugins.count) plugin entr\(plugins.count == 1 ? "y" : "ies")"
        }
        if let marketplaces = root["marketplaces"] as? [Any] {
            return "\(marketplaces.count) marketplace entr\(marketplaces.count == 1 ? "y" : "ies")"
        }
        return "\(root.keys.count) marketplace key\(root.keys.count == 1 ? "" : "s")"
    }

    private static func inspectCodexPluginMarketplace(
        _ root: [String: Any],
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        if root.keys.isEmpty {
            return [issue(
                .configUnsupportedShape,
                .info,
                surface,
                "Empty plugin marketplace",
                "\(surface.label) exists but contains no visible marketplace keys.",
                "Leave it empty if this project does not publish Codex plugins, or add plugin entries through the documented marketplace format."
            )]
        }
        return []
    }

    private static func inspectCodexPluginManifest(
        _ root: [String: Any],
        surface: CompatibilityMatrixEntry,
        path: String
    ) -> [CompatibilityIssue] {
        let pluginRoot = URL(fileURLWithPath: path)
            .standardizedFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        var issues: [CompatibilityIssue] = []

        if root.keys.contains("skills") {
            let rawSkillPaths = stringArrayOrSingle(root["skills"])
            if rawSkillPaths.isEmpty {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex plugin skill path",
                    "\(surface.label) sets skills as \(jsonValueDescription(root["skills"])), but Codex expects a relative path string such as \"./skills\".",
                    "Update the plugin manifest so skills points to a directory inside the plugin root.",
                    subjectPath: "skills"
                ))
            }
            for rawPath in rawSkillPaths {
                let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
                if !(trimmed == "." || trimmed.hasPrefix("./")) {
                    issues.append(issue(
                        .configUnsupportedShape,
                        .warning,
                        surface,
                        "Invalid Codex plugin skill path",
                        "\(surface.label) sets skills to \"\(trimmed)\", but Codex plugin component paths must start with ./ and be relative to the plugin root.",
                        "Move plugin skills inside the plugin root and reference them with a ./ path.",
                        subjectPath: "skills"
                    ))
                    continue
                }

                let resolved = URL(fileURLWithPath: pluginRoot)
                    .appendingPathComponent(trimmed)
                    .standardizedFileURL
                    .path
                guard pathIsInside(resolved, root: pluginRoot) else {
                    issues.append(issue(
                        .configUnsupportedShape,
                        .warning,
                        surface,
                        "Codex plugin skill path leaves plugin root",
                        "\(surface.label) points skills at \"\(trimmed)\", which resolves outside the installed plugin root.",
                        "Keep plugin skills inside the plugin root before installing the plugin.",
                        subjectPath: "skills"
                    ))
                    continue
                }

                if !directoryExists(resolved) && !fileExists((resolved as NSString).appendingPathComponent("SKILL.md")) {
                    issues.append(issue(
                        .configMissing,
                        .warning,
                        surface,
                        "Codex plugin skill folder missing",
                        "\(surface.label) points skills at \(tilde(resolved)), but that folder is missing from the installed plugin cache.",
                        "Reinstall or update the plugin, then restart Codex.",
                        subjectPath: "skills"
                    ))
                }
            }
        }

        guard root.keys.contains("mcpServers") else { return issues }
        let rawPaths = stringArrayOrSingle(root["mcpServers"])
        guard !rawPaths.isEmpty else {
            issues.append(issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Invalid Codex plugin MCP path",
                "\(surface.label) sets mcpServers as \(jsonValueDescription(root["mcpServers"])), but Codex expects a relative path string such as \"./.mcp.json\".",
                "Update the plugin manifest so mcpServers points to an .mcp.json file inside the plugin root.",
                subjectPath: "mcpServers"
            ))
            return issues
        }

        for rawPath in rawPaths {
            let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !(trimmed == "." || trimmed.hasPrefix("./")) {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex plugin MCP path",
                    "\(surface.label) sets mcpServers to \"\(trimmed)\", but Codex plugin component paths must start with ./ and be relative to the plugin root.",
                    "Move the MCP config inside the plugin root and reference it with a ./ path.",
                    subjectPath: "mcpServers"
                ))
                continue
            }

            let resolved = URL(fileURLWithPath: pluginRoot)
                .appendingPathComponent(trimmed)
                .standardizedFileURL
                .path
            guard pathIsInside(resolved, root: pluginRoot) else {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Codex plugin MCP path leaves plugin root",
                    "\(surface.label) points mcpServers at \"\(trimmed)\", which resolves outside the installed plugin root.",
                    "Keep plugin MCP config files inside the plugin root before installing the plugin.",
                    subjectPath: "mcpServers"
                ))
                continue
            }

            if !fileExists(resolved) {
                issues.append(issue(
                    .configMissing,
                    .warning,
                    surface,
                    "Codex plugin MCP file missing",
                    "\(surface.label) points mcpServers at \(tilde(resolved)), but that file is missing from the installed plugin cache.",
                    "Reinstall or update the plugin, then restart Codex.",
                    subjectPath: "mcpServers"
                ))
            }
        }
        return issues
    }

    private static func isCodexConfiguredInstructionFileSurface(_ surface: CompatibilityMatrixEntry) -> Bool {
        (surface.toolID == .codexCLI || surface.toolID == .codexDesktop)
            && surface.kind == .context
            && surface.id.contains("-model-instructions|")
    }

    private static func codexConfiguredInstructionFileMetadata(from surface: CompatibilityMatrixEntry) -> [String: String] {
        guard isCodexConfiguredInstructionFileSurface(surface) else { return [:] }
        let parts = surface.id.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3 else { return [:] }
        let key = String(parts[1])
        let configPath = String(parts[2])
        guard key == "model_instructions_file" || key == "experimental_instructions_file" else { return [:] }
        return [
            "codexInstructionFileKey": key,
            "codexInstructionFileConfigPath": configPath,
            "codexInstructionFileScope": surface.scope.rawValue
        ]
    }

    private static func detectCodexInstructionShadowing(in matrix: [CompatibilityMatrixEntry]) -> [CompatibilityIssue] {
        let contextSurfaces = matrix.filter { $0.kind == .context }
        guard !contextSurfaces.isEmpty else { return [] }

        let claudeContexts = contextSurfaces.filter {
            $0.toolID == .claudeCode
                && ($0.scope == .project || $0.scope == .localProjectUser)
        }
        let primaryClaude = claudeContexts.first { $0.id == "claude-code-project-context" } ?? claudeContexts.first
        let codexProjectContexts = contextSurfaces.filter { $0.toolID == .codexCLI && $0.scope == .project }
        guard let primaryClaude else { return [] }

        let hasClaude = claudeContexts.contains { instructionFileIsNonEmpty($0.path) }
        let hasCodex = codexProjectContexts.contains { instructionFileIsNonEmpty($0.path) }
        var issues: [CompatibilityIssue] = []

        if hasClaude && !hasCodex {
            let claudePath = claudeContexts.first(where: { instructionFileIsNonEmpty($0.path) })?.path
            let representativeCodex = codexProjectContexts.first {
                $0.path.map { ($0 as NSString).lastPathComponent } == "AGENTS.md"
            } ?? codexProjectContexts.first ?? primaryClaude
            issues.append(
                issue(
                    .configMissing,
                    .info,
                    representativeCodex,
                    "Codex project instructions missing",
                    "CLAUDE.md exists, but no non-empty Codex project instruction file was found. Codex CLI/Desktop will not automatically receive the same project instructions.",
                    "Preview creating or linking a Codex instruction file before assuming Claude and Codex sessions share project context.",
                    subjectPath: claudePath
                )
            )
        }

        if hasCodex {
            let codexByDirectory = Dictionary(grouping: codexProjectContexts) { surface -> String in
                guard let path = surface.path else { return surface.id }
                return instructionDirectory(for: path, toolID: surface.toolID)
            }
            for (directory, codexGroup) in codexByDirectory {
                guard let activeCodex = codexGroup
                    .filter({ instructionFileIsNonEmpty($0.path) })
                    .sorted(by: codexInstructionPrecedence)
                    .first,
                    let codexPath = activeCodex.path else {
                    continue
                }

                guard let claude = activeClaudeInstruction(in: claudeContexts, directory: directory),
                      let claudePath = claude.path else {
                    let targetClaude = claudeInstructionCandidate(in: claudeContexts, directory: directory) ?? primaryClaude
                    issues.append(issue(
                        .configMissing,
                        .info,
                        targetClaude,
                        "Claude project instructions missing",
                        "\(tilde(codexPath)) exists, but no non-empty Claude instruction file was found for the same directory. Claude Code will not automatically receive this selected-path Codex guidance.",
                        "Preview creating same-directory Claude project instructions before assuming Claude and Codex sessions share project context.",
                        subjectPath: codexPath
                    ))
                    continue
                }

                guard let claudeRaw = try? String(contentsOfFile: claudePath, encoding: .utf8),
                      let codexRaw = try? String(contentsOfFile: codexPath, encoding: .utf8),
                      !claudeImportsInstruction(claudeRaw, sourcePath: codexPath, from: claudePath),
                      claudeRaw.trimmingCharacters(in: .whitespacesAndNewlines) != codexRaw.trimmingCharacters(in: .whitespacesAndNewlines) else {
                    continue
                }

                let sourceName = (codexPath as NSString).lastPathComponent
                let targetName = (claudePath as NSString).lastPathComponent
                issues.append(issue(
                    .contextDiverged,
                    .warning,
                    claude,
                    "Project instructions differ",
                    "\(tilde(claudePath)) and \(tilde(codexPath)) are both non-empty, but Claude Code will not read \(sourceName) unless \(targetName) imports it.",
                    "Preview adding an @\(sourceName) import to \(targetName) where safe, or manually merge the active Claude and Codex guidance.",
                    subjectPath: codexPath
                ))
            }
        }

        let codexContexts = contextSurfaces.filter { $0.toolID == .codexCLI }
        let grouped = Dictionary(grouping: codexContexts) { surface -> String in
            guard let path = surface.path else { return surface.id }
            return (path as NSString).deletingLastPathComponent
        }

        for (_, group) in grouped {
            let present = group
                .filter { instructionFileIsNonEmpty($0.path) }
                .sorted { lhs, rhs in
                    let lhsRank = codexInstructionRank(path: lhs.path)
                    let rhsRank = codexInstructionRank(path: rhs.path)
                    if lhsRank != rhsRank { return lhsRank < rhsRank }
                    return lhs.precedence < rhs.precedence
                }
            guard present.count > 1, let winner = present.first, let winnerPath = winner.path else { continue }
            let shadowed = present.dropFirst().compactMap(\.path).map(tilde)
            issues.append(issue(
                .projectSettingsShadowed,
                .info,
                winner,
                "Codex instruction files shadowed",
                "\(tilde(winnerPath)) is the first non-empty instruction file for this directory. Codex ignores \(shadowed.joined(separator: ", ")) at the same level.",
                "Move guidance into the active file or remove the shadowed file to avoid stale instructions."
            ))
        }

        return issues
    }

    private static func instructionFileIsNonEmpty(_ path: String?) -> Bool {
        guard let path,
              FileManager.default.fileExists(atPath: path),
              let raw = try? String(contentsOfFile: path, encoding: .utf8) else {
            return false
        }
        return !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func activeClaudeInstruction(
        in surfaces: [CompatibilityMatrixEntry],
        directory: String
    ) -> CompatibilityMatrixEntry? {
        surfaces
            .filter {
                guard let path = $0.path else { return false }
                return instructionDirectory(for: path, toolID: $0.toolID) == directory
                    && instructionFileIsNonEmpty(path)
            }
            .sorted { lhs, rhs in
                let lhsRank = claudeInstructionRank(path: lhs.path)
                let rhsRank = claudeInstructionRank(path: rhs.path)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.precedence < rhs.precedence
            }
            .first
    }

    private static func claudeInstructionCandidate(
        in surfaces: [CompatibilityMatrixEntry],
        directory: String
    ) -> CompatibilityMatrixEntry? {
        surfaces
            .filter {
                guard let path = $0.path else { return false }
                return instructionDirectory(for: path, toolID: $0.toolID) == directory
            }
            .sorted { lhs, rhs in
                let lhsRank = claudeInstructionRank(path: lhs.path)
                let rhsRank = claudeInstructionRank(path: rhs.path)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.precedence < rhs.precedence
            }
            .first
    }

    private static func instructionDirectory(for path: String, toolID: CompatibilityToolID) -> String {
        if toolID == .claudeCode,
           (path as NSString).lastPathComponent == "CLAUDE.md",
           ((path as NSString).deletingLastPathComponent as NSString).lastPathComponent == ".claude" {
            return (((path as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent)
        }
        return (path as NSString).deletingLastPathComponent
    }

    private static func claudeInstructionRank(path: String?) -> Int {
        guard let path else { return Int.max }
        let filename = (path as NSString).lastPathComponent
        if filename == "CLAUDE.md" {
            let directory = (path as NSString).deletingLastPathComponent
            return (directory as NSString).lastPathComponent == ".claude" ? 1 : 0
        }
        if filename == "CLAUDE.local.md" { return 2 }
        return 3
    }

    private static func codexInstructionRank(path: String?) -> Int {
        guard let filename = path.map({ ($0 as NSString).lastPathComponent }) else { return Int.max }
        if filename == "AGENTS.override.md" { return 0 }
        if filename == "AGENTS.md" { return 1 }
        return 2
    }

    private static func codexInstructionPrecedence(_ lhs: CompatibilityMatrixEntry, _ rhs: CompatibilityMatrixEntry) -> Bool {
        let lhsRank = codexInstructionRank(path: lhs.path)
        let rhsRank = codexInstructionRank(path: rhs.path)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        return lhs.precedence < rhs.precedence
    }

    private static func claudeImportsInstruction(_ claudeRaw: String, sourcePath: String, from claudePath: String) -> Bool {
        let sourceURL = URL(fileURLWithPath: sourcePath).standardizedFileURL
        let claudeDirectory = URL(fileURLWithPath: claudePath).deletingLastPathComponent()
        return claudeImportTokens(in: claudeRaw).contains { token in
            resolveClaudeImport(token, from: claudeDirectory).standardizedFileURL.path == sourceURL.path
        }
    }

    private static func inspectClaudeMarkdownContext(
        _ raw: String,
        surface: CompatibilityMatrixEntry,
        path: String,
        projectRoot: String?,
        claudeHome: String
    ) -> [CompatibilityIssue] {
        guard surface.toolID == .claudeCode,
              surface.kind == .context else {
            return []
        }

        var issues = inspectClaudeImports(
            raw,
            surface: surface,
            importingPath: path,
            projectRoot: projectRoot,
            claudeHome: claudeHome,
            visited: Set([canonicalFilePath(path)]),
            depth: 0
        )

        if surface.id.contains("rule") {
            let rule = claudeRuleMetadata(in: raw)
            if rule.invalidPaths {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Claude rule paths",
                    "\(tilde(path)) has paths frontmatter, but Project Hub could not read any non-empty glob patterns from it.",
                    "Use YAML frontmatter such as paths: with one or more string glob patterns.",
                    subjectPath: "paths"
                ))
            }
        }

        return issues
    }

    private static func inspectClaudeImports(
        _ raw: String,
        surface: CompatibilityMatrixEntry,
        importingPath: String,
        projectRoot: String?,
        claudeHome: String,
        visited: Set<String>,
        depth: Int
    ) -> [CompatibilityIssue] {
        let importingDirectory = URL(fileURLWithPath: importingPath).deletingLastPathComponent()
        var issues: [CompatibilityIssue] = []

        for token in claudeImportTokens(in: raw) {
            let resolved = resolveClaudeImport(token, from: importingDirectory).standardizedFileURL
            let targetPath = resolved.path
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: targetPath, isDirectory: &isDirectory) else {
                issues.append(issue(
                    .configMissing,
                    .warning,
                    surface,
                    "Claude import target missing",
                    "\(tilde(importingPath)) imports @\(token), but \(tilde(targetPath)) does not exist.",
                    "Create the imported file, fix the @ import path, or remove the stale import.",
                    subjectPath: targetPath
                ))
                continue
            }

            if isDirectory.boolValue {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Claude import points to directory",
                    "\(tilde(importingPath)) imports @\(token), but \(tilde(targetPath)) is a directory rather than a Markdown/context file.",
                    "Import a specific file instead of a directory.",
                    subjectPath: targetPath
                ))
                continue
            }

            if depth + 1 > 5 {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Claude import depth exceeds limit",
                    "\(tilde(importingPath)) imports \(tilde(targetPath)), but Claude Code only expands recursive imports up to five hops.",
                    "Flatten the import chain or move the required guidance closer to the root CLAUDE.md/rule file.",
                    subjectPath: targetPath
                ))
                continue
            }

            let canonical = canonicalFilePath(targetPath)
            if visited.contains(canonical) {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Claude import cycle",
                    "\(tilde(importingPath)) imports \(tilde(targetPath)), which is already in this Claude import chain.",
                    "Break the cycle so Claude Code can expand the imported guidance predictably.",
                    subjectPath: targetPath
                ))
                continue
            }

            if claudeImportRequiresExternalApproval(targetPath, projectRoot: projectRoot, claudeHome: claudeHome) {
                issues.append(claudeExternalImportApprovalIssue(
                    surface: surface,
                    importingPath: importingPath,
                    targetPath: targetPath,
                    projectRoot: projectRoot
                ))
                continue
            }

            guard let importedRaw = try? String(contentsOfFile: targetPath, encoding: .utf8) else {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Could not read Claude import",
                    "Project Hub could not read imported Claude context file \(tilde(targetPath)).",
                    "Fix file permissions or remove the import.",
                    subjectPath: targetPath
                ))
                continue
            }

            var nextVisited = visited
            nextVisited.insert(canonical)
            issues.append(contentsOf: inspectClaudeImports(
                importedRaw,
                surface: surface,
                importingPath: targetPath,
                projectRoot: projectRoot,
                claudeHome: claudeHome,
                visited: nextVisited,
                depth: depth + 1
            ))
        }

        return issues
    }

    private static func claudeImportTokens(in text: String) -> [String] {
        var tokens: [String] = []
        var inFence = false

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence.toggle()
                continue
            }
            if inFence { continue }

            for part in line.split(whereSeparator: { $0 == " " || $0 == "\t" }) {
                guard let at = part.firstIndex(of: "@") else { continue }
                if at != part.startIndex {
                    let previous = part[part.index(before: at)]
                    if previous.isLetter || previous.isNumber || previous == "_" || previous == "-" {
                        continue
                    }
                }
                var token = String(part[part.index(after: at)...])
                token = token.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n,;)]}>'\"`"))
                guard !token.isEmpty,
                      !token.contains("@") else { continue }
                tokens.append(token)
            }
        }

        return uniqueStringsPreservingOrder(tokens)
    }

    private static func canonicalFilePath(_ path: String) -> String {
        URL(fileURLWithPath: path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    private static func claudeImportRequiresExternalApproval(
        _ targetPath: String,
        projectRoot: String?,
        claudeHome: String
    ) -> Bool {
        let target = canonicalFilePath(targetPath)
        let allowedRoots = [projectRoot, Optional(claudeHome)]
            .compactMap { $0 }
            .map(canonicalFilePath)
        guard !allowedRoots.isEmpty else { return false }
        return !allowedRoots.contains { root in
            target == root || target.hasPrefix(root + "/")
        }
    }

    private static func claudeExternalImportApprovalIssue(
        surface: CompatibilityMatrixEntry,
        importingPath: String,
        targetPath: String,
        projectRoot: String?
    ) -> CompatibilityIssue {
        let evidence = claudeExternalImportApprovalEvidence(projectRoot: projectRoot)
        let title: String
        let detail: String
        let fixHint: String
        switch evidence {
        case .approved:
            title = "Claude external import approval recorded locally"
            detail = "\(tilde(importingPath)) imports external file \(tilde(targetPath)). Local Claude project state records external-import approval, but Project Hub still cannot prove the current Claude session loaded this file."
            fixHint = "Use /memory, /context, or an InstructionsLoaded hook to verify live context before relying on this imported guidance."
        case .notApproved:
            title = "Claude external import may be unapproved"
            detail = "\(tilde(importingPath)) imports external file \(tilde(targetPath)). Local Claude project state has shown the external-import warning but does not record approval, so Claude may keep this import disabled."
            fixHint = "Open the project in Claude Code and review /memory, /context, or the approval prompt before relying on this imported guidance."
        case .none:
            title = "Claude external import approval unknown"
            detail = "\(tilde(importingPath)) imports external file \(tilde(targetPath)). Claude Code prompts the first time a project uses external imports, but Project Hub cannot read an official approval source for this import."
            fixHint = "Open the project in Claude Code and check /memory, /context, or the approval prompt before relying on this imported guidance."
        }
        return issue(
            .contextExternalImportApprovalUnknown,
            .info,
            surface,
            title,
            detail,
            fixHint,
            subjectPath: targetPath
        )
    }

    private enum ClaudeExternalImportApprovalEvidence {
        case approved
        case notApproved
    }

    private static func claudeExternalImportApprovalEvidence(projectRoot: String?) -> ClaudeExternalImportApprovalEvidence? {
        guard let projectRoot,
              let root = readJSONDictionary(at: claudeCodeJSONPath()),
              let state = claudeProjectState(
                from: CompatibilityMatrixEntry(
                    id: "claude-code-local-project-state|\(projectRoot)",
                    toolID: .claudeCode,
                    kind: .settings,
                    scope: .localProjectUser,
                    label: "Claude Code local project state",
                    path: claudeCodeJSONPath(),
                    format: .jsonc,
                    fileControlled: false,
                    canWriteSafely: false,
                    writeMethod: .unsupported,
                    requiresRestartAfterWrite: false,
                    supportsDisable: false,
                    supportsOAuth: false,
                    supportsEnvExpansion: false,
                    precedence: 32,
                    note: ""
                ),
                root: root
              ) else {
            return nil
        }
        if boolSetting("hasClaudeMdExternalIncludesApproved", in: state) == true {
            return .approved
        }
        if boolSetting("hasClaudeMdExternalIncludesWarningShown", in: state) == true {
            return .notApproved
        }
        return nil
    }

    private static func resolveClaudeImport(_ token: String, from directory: URL) -> URL {
        if token.hasPrefix("~") {
            return URL(fileURLWithPath: (token as NSString).expandingTildeInPath)
        }
        if token.hasPrefix("/") {
            return URL(fileURLWithPath: token)
        }
        return directory.appendingPathComponent(token)
    }

    private static func markdownHeadings(in text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("#") else { return nil }
                let title = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
                return title.isEmpty ? nil : title
            }
            .prefix(8)
            .map { String($0) }
    }

    private static func markdownContextKeys(
        _ text: String,
        surface: CompatibilityMatrixEntry,
        headings: [String]
    ) -> [String] {
        var keys = headings
        if surface.toolID == .claudeCode,
           surface.id.contains("rule") {
            let metadata = claudeRuleMetadata(in: text)
            if metadata.hasPaths {
                let paths = metadata.paths.isEmpty ? ["paths"] : metadata.paths.map { "paths: \($0)" }
                keys.append(contentsOf: paths)
            } else {
                keys.append("unconditional rule")
            }
        }
        let imports = claudeImportTokens(in: text).map { "@\($0)" }
        keys.append(contentsOf: imports)
        return Array(keys.prefix(12))
    }

    private static func markdownContextSummary(
        _ text: String,
        surface: CompatibilityMatrixEntry,
        headings: [String]
    ) -> String {
        if surface.toolID == .claudeCode,
           surface.id.contains("rule") {
            let metadata = claudeRuleMetadata(in: text)
            if metadata.hasPaths {
                return metadata.paths.isEmpty
                    ? "Path-scoped Claude rule with invalid paths frontmatter"
                    : "Path-scoped Claude rule: \(metadata.paths.prefix(3).joined(separator: ", "))"
            }
            return "Unconditional Claude rule loaded with project/user instructions"
        }
        let imports = claudeImportTokens(in: text)
        if !imports.isEmpty {
            return "Imports: \(imports.prefix(3).map { "@\($0)" }.joined(separator: ", "))"
        }
        let nonEmptyLines = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
        if !headings.isEmpty {
            return "Headings: \(headings.prefix(3).joined(separator: ", "))"
        }
        return "\(nonEmptyLines) non-empty instruction line\(nonEmptyLines == 1 ? "" : "s")"
    }

    private static func claudeRuleMetadata(in text: String) -> (hasPaths: Bool, paths: [String], invalidPaths: Bool) {
        guard let frontmatter = SkillReader.parseFrontmatter(text),
              let rawPaths = frontmatter["paths"]?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return (false, [], false)
        }
        let paths = parseSimpleYAMLStringList(rawPaths)
        return (true, paths, paths.isEmpty)
    }

    private static func parseSimpleYAMLStringList(_ raw: String) -> [String] {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return [] }
        if value.count >= 2,
           (value.hasPrefix("\"") && value.hasSuffix("\""))
            || (value.hasPrefix("'") && value.hasSuffix("'")) {
            return [String(value.dropFirst().dropLast())].filter { !$0.isEmpty }
        }
        if value.hasPrefix("[") && value.hasSuffix("]") {
            value = String(value.dropFirst().dropLast())
            return value
                .split(separator: ",")
                .map { unquoteYAMLScalar(String($0)) }
                .filter { !$0.isEmpty }
        }
        if value.hasPrefix("- ") {
            return value
                .components(separatedBy: .newlines)
                .compactMap { line -> String? in
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.hasPrefix("- ") else { return nil }
                    return unquoteYAMLScalar(String(trimmed.dropFirst(2)))
                }
                .filter { !$0.isEmpty }
        }
        if value.contains("\n") {
            return value
                .components(separatedBy: .newlines)
                .compactMap { line -> String? in
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.hasPrefix("- ") else { return nil }
                    return unquoteYAMLScalar(String(trimmed.dropFirst(2)))
                }
                .filter { !$0.isEmpty }
        }
        return value.contains(":") ? [] : [unquoteYAMLScalar(value)].filter { !$0.isEmpty }
    }

    private static func unquoteYAMLScalar(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count >= 2,
           (value.hasPrefix("\"") && value.hasSuffix("\""))
            || (value.hasPrefix("'") && value.hasSuffix("'")) {
            return String(value.dropFirst().dropLast())
        }
        return value
    }

    private static func readPlistFile(_ path: String) -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        var format = PropertyListSerialization.PropertyListFormat.binary
        guard let root = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: &format
        ) as? [String: Any] else {
            return nil
        }
        return root
    }

    private static func inspectClaudeDesktopPolicy(_ root: [String: Any], surface: CompatibilityMatrixEntry) -> [CompatibilityIssue] {
        guard surface.toolID == .claudeDesktop else { return [] }
        var issues: [CompatibilityIssue] = []

        func appendDisabled(_ key: String, title: String, detail: String, hint: String) {
            guard boolSetting(key, in: root) == false else { return }
            issues.append(issue(.settingsManagedRequirement, .warning, surface, title, detail, hint))
        }

        appendDisabled(
            "isLocalDevMcpEnabled",
            title: "Claude Desktop local MCP disabled by policy",
            detail: "\(surface.label) sets isLocalDevMcpEnabled to false, so users cannot add their own local MCP server processes from Settings > Developer.",
            hint: "Treat Claude Desktop local MCP as admin-managed for this machine. Use managed MCP servers or ask the administrator to enable local MCP."
        )
        appendDisabled(
            "isDesktopExtensionEnabled",
            title: "Claude Desktop extensions disabled by policy",
            detail: "\(surface.label) sets isDesktopExtensionEnabled to false, so local .mcpb desktop extensions cannot be installed by users.",
            hint: "Use admin-provisioned connectors/extensions or ask the administrator to enable desktop extensions."
        )
        appendDisabled(
            "isDesktopExtensionDirectoryEnabled",
            title: "Claude Desktop extension directory disabled",
            detail: "\(surface.label) sets isDesktopExtensionDirectoryEnabled to false, so the extension directory is hidden from the Connectors UI.",
            hint: "Keep extension discovery read-only in Project Hub and direct users to the configured admin channel."
        )
        appendDisabled(
            "isDxtDirectoryEnabled",
            title: "Claude Desktop extension directory disabled",
            detail: "\(surface.label) sets isDxtDirectoryEnabled to false, so the legacy desktop-extension directory control is disabled.",
            hint: "Keep extension discovery read-only in Project Hub and direct users to the configured admin channel."
        )
        appendDisabled(
            "isClaudeCodeForDesktopEnabled",
            title: "Claude Code in Desktop disabled by policy",
            detail: "\(surface.label) sets isClaudeCodeForDesktopEnabled to false, so the Desktop Code surface may be unavailable.",
            hint: "Show Codex/Claude Code CLI settings separately and do not offer Desktop Code fixes on this machine."
        )
        appendDisabled(
            "secureVmFeaturesEnabled",
            title: "Claude Desktop VM features disabled by policy",
            detail: "\(surface.label) sets secureVmFeaturesEnabled to false, which can disable Cowork/VM-backed Desktop features.",
            hint: "Treat affected Desktop project/session settings as unavailable until policy changes."
        )

        if boolSetting("isDesktopExtensionSignatureRequired", in: root) == true {
            issues.append(issue(
                .settingsManagedRequirement,
                .info,
                surface,
                "Desktop extension signatures required",
                "\(surface.label) requires signed desktop extensions. Unsigned local .mcpb packages will be rejected by Claude Desktop.",
                "Flag unsigned installed extensions and prefer signed/admin-provisioned packages."
            ))
        }

        if hasManagedMCPServers(in: root) {
            issues.append(issue(
                .settingsManagedRequirement,
                .info,
                surface,
                "Managed MCP servers configured",
                "\(surface.label) contains managedMcpServers, so at least one Claude Desktop MCP/connector is admin-provisioned.",
                "Show these as policy-controlled and avoid offering user-file edits for them."
            ))
        }

        return issues
    }

    private static func inspectClaudeSettings(_ root: [String: Any], surface: CompatibilityMatrixEntry) -> [CompatibilityIssue] {
        guard surface.toolID == .claudeCode else { return [] }
        var issues: [CompatibilityIssue] = []
        let enabled = Set(stringArray(root["enabledMcpjsonServers"]))
        let disabled = Set(stringArray(root["disabledMcpjsonServers"]))
        let overlap = enabled.intersection(disabled).sorted()
        if !overlap.isEmpty {
            issues.append(issue(
                .projectSettingsShadowed,
                .warning,
                surface,
                "Conflicting Claude MCP approvals",
                "The same project MCP server appears in both enabledMcpjsonServers and disabledMcpjsonServers: \(overlap.joined(separator: ", ")).",
                "Keep each server in only one approval list, then restart Claude Code."
            ))
        }

        let localProjectState = surface.id.hasPrefix("claude-code-local-project-state")
        if root["allowedMcpServers"] != nil, !localProjectState {
            issues.append(issue(
                .settingsManagedRequirement,
                surface.id.contains("managed") ? .info : .warning,
                surface,
                "Claude MCP allowlist configured",
                "\(surface.label) defines allowedMcpServers. Claude Code will only allow servers matching that policy when the setting is enforced from a managed source.",
                "Compare user/project MCP servers against the allowlist before offering fixes."
            ))
        }
        if root["deniedMcpServers"] != nil, !localProjectState {
            issues.append(issue(
                .settingsManagedRequirement,
                .warning,
                surface,
                "Claude MCP denylist configured",
                "\(surface.label) defines deniedMcpServers. Denied servers are blocked across MCP scopes, and the denylist takes precedence over any allowlist.",
                "Flag matching MCP servers as administrator-blocked and avoid offering enable fixes."
            ))
        }
        if (root["allowManagedMcpServersOnly"] as? Bool) == true, !localProjectState {
            issues.append(issue(
                .settingsManagedRequirement,
                .warning,
                surface,
                "Only managed Claude MCP allowlist applies",
                "\(surface.label) sets allowManagedMcpServersOnly, so Claude Code ignores user/project allowlist expansions and only honors managed allowedMcpServers.",
                "Treat non-managed MCP additions as blocked unless they match the managed allowlist."
            ))
        }
        if root["model"] != nil {
            issues.append(issue(
                .settingsSessionReloadRequired,
                .info,
                surface,
                "Claude model setting is session-scoped",
                "\(surface.label) defines model. Claude Code watches settings files, but model changes should be applied with /model in the current session or by starting a new session.",
                "After editing model, use Claude Code's /model command or restart the session, then run Scan again."
            ))
        }
        if root["outputStyle"] != nil {
            issues.append(issue(
                .settingsSessionReloadRequired,
                .info,
                surface,
                "Claude output style rebuilds with session context",
                "\(surface.label) defines outputStyle. Claude Code watches settings files, but outputStyle is part of the system prompt and is rebuilt on /clear or restart.",
                "After editing outputStyle, run /clear or restart Claude Code so the session prompt is rebuilt."
            ))
        }
        if hasClaudeInstructionsLoadedHook(root) {
            issues.append(issue(
                .serverHealthUnknown,
                .info,
                surface,
                "Claude InstructionsLoaded hook configured",
                "\(surface.label) defines an InstructionsLoaded hook. Claude Code can use it to observe which CLAUDE.md and .claude/rules files load, but static scanning cannot prove that the hook fired in the current session.",
                "Use /hooks, /context, /memory, or Claude Code's debug log to verify the live hook output.",
                subjectPath: "hooks.InstructionsLoaded"
            ))
        }
        if boolSetting("disableSkillShellExecution", in: root) == true {
            issues.append(issue(
                .settingsManagedRequirement,
                surface.id.contains("managed") ? .warning : .info,
                surface,
                "Claude skill shell execution disabled",
                "\(surface.label) sets disableSkillShellExecution, so inline shell blocks in user, project, plugin, or additional-directory skills are replaced instead of executed.",
                "Surface this as a skill runtime policy and avoid presenting shell-backed skill failures as broken installs."
            ))
        }
        if surface.id.hasPrefix("claude-code-local-project-state"),
           boolSetting("hasTrustDialogAccepted", in: root) == false {
            issues.append(issue(
                .projectTrustRequired,
                .info,
                surface,
                "Claude project trust not accepted locally",
                "\(surface.label) records hasTrustDialogAccepted as false. Claude Code may still prompt before fully trusting this project or its local state.",
                "Open the project in Claude Code and accept the trust prompt before relying on project-local MCP, skills, or memory evidence.",
                subjectPath: "hasTrustDialogAccepted"
            ))
        }
        if root["ignorePatterns"] != nil {
            let detail: String
            if surface.id.hasPrefix("claude-code-local-project-state") {
                detail = "\(surface.label) records ignorePatterns in private project state. Current Claude Code docs say permissions.deny replaces the deprecated ignorePatterns setting for hiding sensitive files."
            } else {
                detail = "\(surface.label) defines ignorePatterns, but current Claude Code docs say permissions.deny replaces that deprecated setting for hiding sensitive files."
            }
            issues.append(issue(
                .settingsDeprecatedValue,
                .warning,
                surface,
                "Deprecated Claude ignorePatterns recorded",
                detail,
                "Use permissions.deny in Claude settings for file exclusion policy, and treat this local-state value as runtime evidence only.",
                subjectPath: "ignorePatterns"
            ))
        }
        if surface.id.hasPrefix("claude-code-local-project-state"),
           boolSetting("dontCrawlDirectory", in: root) == true {
            issues.append(issue(
                .serverHealthUnknown,
                .info,
                surface,
                "Claude directory crawl disabled locally",
                "\(surface.label) records dontCrawlDirectory as true. Project Hub treats this as runtime-only evidence that Claude may avoid broad project crawling/indexing for this directory.",
                "Open the project in Claude Code and inspect project onboarding or context settings before assuming Claude has discovered the whole tree.",
                subjectPath: "dontCrawlDirectory"
            ))
        }
        if surface.id.hasPrefix("claude-code-local-project-state") {
            let policyKeys = claudeLocalProjectPolicyEvidenceKeys(in: root)
            if !policyKeys.isEmpty {
                let display = policyKeys.prefix(6).joined(separator: ", ")
                let suffix = policyKeys.count > 6 ? ", ..." : ""
                issues.append(issue(
                    .settingsManagedRequirement,
                    .info,
                    surface,
                    "Claude local project state contains policy-shaped fields",
                    "\(surface.label) includes private project-state fields that look policy-related: \(display)\(suffix). Official Claude Code docs describe ~/.claude.json as local MCP, trust, OAuth, and cache state, not the file-controlled policy source, so Project Hub is reporting these as read-only evidence.",
                    "Review this project in Claude Code and compare against ~/.claude/settings.json, .claude/settings.json, .claude/settings.local.json, and managed settings before applying fixes.",
                    subjectPath: policyKeys.joined(separator: ", ")
                ))
            }
        }
        if let overrides = root["skillOverrides"] {
            guard let dictionary = overrides as? [String: Any] else {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Claude skillOverrides shape",
                    "\(surface.label) defines skillOverrides, but Claude Code expects an object whose keys are skill names and whose values are visibility states.",
                    "Use values on, name-only, user-invocable-only, or off.",
                    subjectPath: "skillOverrides"
                ))
                return issues
            }
            let validStates = Set(["on", "name-only", "user-invocable-only", "off"])
            for (skillName, value) in dictionary {
                guard let state = value as? String,
                      validStates.contains(state) else {
                    issues.append(issue(
                        .configUnsupportedShape,
                        .warning,
                        surface,
                        "Invalid Claude skill override state",
                        "\(surface.label) sets skillOverrides.\(skillName) to \(jsonValueDescription(value)), but Claude Code supports only on, name-only, user-invocable-only, or off.",
                        "Choose one of Claude Code's documented skill visibility states.",
                        subjectPath: "skillOverrides.\(skillName)"
                    ))
                    continue
                }
            }
        }
        if let additionalDirectories = root["additionalDirectories"] {
            let directories = stringArray(additionalDirectories)
            if directories.isEmpty && !(additionalDirectories is [String]) {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Claude additionalDirectories shape",
                    "\(surface.label) defines additionalDirectories, but current Claude Code docs expect additional directories under permissions.additionalDirectories.",
                    "Move the array to permissions.additionalDirectories with absolute, ~/..., or project-relative directory paths.",
                    subjectPath: "additionalDirectories"
                ))
            } else if !directories.isEmpty && !claudeAdditionalDirectoryMemoryEnabled() {
                let detail: String
                if surface.id.hasPrefix("claude-code-local-project-state") {
                    detail = "\(surface.label) records runtime additional-directory evidence, but Claude Code does not load CLAUDE.md from those directories unless CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 is set for the session."
                } else {
                    detail = "\(surface.label) grants additional directory access, but Claude Code does not load CLAUDE.md from those directories unless CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 is set for the session."
                }
                issues.append(issue(
                    .serverHealthUnknown,
                    .info,
                    surface,
                    "Additional-directory Claude memory not enabled",
                    detail,
                    "Set CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 before launching Claude Code if those directories should contribute CLAUDE.md, .claude/CLAUDE.md, rules, and CLAUDE.local.md.",
                    subjectPath: "additionalDirectories"
                ))
            }
        }
        if let permissions = root["permissions"] as? [String: Any],
           let additionalDirectories = permissions["additionalDirectories"] {
            let directories = stringArray(additionalDirectories)
            if directories.isEmpty && !(additionalDirectories is [String]) {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Claude permissions.additionalDirectories shape",
                    "\(surface.label) defines permissions.additionalDirectories, but Claude Code expects an array of directory paths.",
                    "Use an array of absolute, ~/..., or project-relative directory paths.",
                    subjectPath: "permissions.additionalDirectories"
                ))
            } else if !directories.isEmpty && !claudeAdditionalDirectoryMemoryEnabled() {
                issues.append(issue(
                    .serverHealthUnknown,
                    .info,
                    surface,
                    "Additional-directory Claude memory not enabled",
                    "\(surface.label) grants additional directory access, but Claude Code does not load CLAUDE.md from those directories unless CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 is set for the session.",
                    "Set CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 before launching Claude Code if those directories should contribute CLAUDE.md, .claude/CLAUDE.md, rules, and CLAUDE.local.md.",
                    subjectPath: "permissions.additionalDirectories"
                ))
            }
        }
        if claudeStrictPluginOnlyLocksSkills(root) {
            issues.append(issue(
                .settingsManagedRequirement,
                surface.id.contains("managed") ? .warning : .info,
                surface,
                "Claude skills restricted to plugins or managed sources",
                "\(surface.label) sets strictPluginOnlyCustomization for skills, so Claude Code skips user and project skill directories and loads only plugin-provided or managed skills.",
                "Treat filesystem skills in ~/.claude/skills and project .claude/skills as policy-blocked unless the managed policy changes."
            ))
        }

        return issues
    }

    private static func hasClaudeInstructionsLoadedHook(_ root: [String: Any]) -> Bool {
        guard let hooks = root["hooks"] as? [String: Any] else { return false }
        return hooks["InstructionsLoaded"] != nil
    }

    private static func inspectClaudeLocalSettingsIgnore(surface: CompatibilityMatrixEntry) -> [CompatibilityIssue] {
        guard surface.id == "claude-code-project-local-settings",
              let path = surface.path else { return [] }
        let claudeDir = (path as NSString).deletingLastPathComponent
        let projectRoot = (claudeDir as NSString).deletingLastPathComponent
        guard FileManager.default.fileExists(atPath: (projectRoot as NSString).appendingPathComponent(".git")) else { return [] }
        let gitignorePath = (projectRoot as NSString).appendingPathComponent(".gitignore")
        let gitignore = (try? String(contentsOfFile: gitignorePath, encoding: .utf8)) ?? ""
        let lines = gitignore.components(separatedBy: CharacterSet.newlines).map {
            $0.trimmingCharacters(in: CharacterSet.whitespaces)
        }
        let ignored = lines.contains(".claude/settings.local.json")
            || lines.contains(".claude/settings.local.json*")
            || lines.contains(".claude/settings.local.*")
            || lines.contains("settings.local.json")
        guard !ignored else { return [] }
        return [
            issue(.projectLocalSettingsTracked, .warning, surface, "Local Claude settings not ignored", ".claude/settings.local.json is user-private project state, but this repo's .gitignore does not explicitly ignore it.", "Add .claude/settings.local.json to .gitignore before editing this file from Project Hub.")
        ]
    }

    private static func inspectCodexSettings(
        _ document: SettingsTOMLDocument,
        surface: CompatibilityMatrixEntry,
        path: String,
        projectRoot: String?,
        codexProfileSelection: CodexProfileSelection?
    ) -> [CompatibilityIssue] {
        var issues: [CompatibilityIssue] = []

        if surface.id == "codex-requirements" {
            let constrained = codexRequirementKeys(in: document)
            if !constrained.isEmpty {
                issues.append(issue(
                    .settingsManagedRequirement,
                    .info,
                    surface,
                    "Codex requirements enforced",
                    "This requirements.toml constrains: \(constrained.joined(separator: ", ")). Conflicting user or project values will be normalized by Codex.",
                    "Treat this as inspect-only policy. Offer changes in user/project config only when they satisfy these requirements."
                ))
            }
        }

        if surface.id.contains("managed") || surface.id.contains("admin") || surface.id == "codex-requirements" {
            let keys = codexSettingsKeys(from: document, projectRoot: projectRoot)
            if !keys.isEmpty {
                issues.append(issue(
                    .settingsManagedRequirement,
                    .info,
                    surface,
                    "Managed Codex config is read-only",
                    "\(surface.label) contains local policy/config keys but is not a safe Project Hub write target.",
                    "Show it as policy context and write only to supported user or project config scopes."
                ))
            }
        }

        if surface.scope == .project,
           surface.toolID == .codexCLI || surface.toolID == .codexDesktop {
            if let projectRoot {
                let codexHome = ProjectHubPaths.codexHome(home: NSHomeDirectory())
                let globalConfigPath = "\(codexHome)/config.toml"
                let trust = ConfigWriter.codexProjectTrustLevel(
                    globalConfigPath: globalConfigPath,
                    projectRoot: projectRoot
                )
                if trust != "trusted" {
                    let detail = trust == nil
                        ? "Codex only loads project-local .codex/config.toml for trusted projects, and no trusted [projects] entry was found for \(tilde(projectRoot))."
                        : "Codex only loads project-local .codex/config.toml for trusted projects, but the user config marks \(tilde(projectRoot)) as \(trust ?? "unknown")."
                    issues.append(issue(
                        .projectTrustRequired,
                        .warning,
                        surface,
                        "Codex project config may be ignored",
                        detail,
                        "Trust this project through Codex's official flow or preview adding trust_level = \"trusted\" to the user-level Codex config."
                    ))
                }
            }

            let ignored = ignoredCodexProjectKeys(in: document)
            if !ignored.isEmpty {
                issues.append(issue(
                    .projectSettingsIgnored,
                    .warning,
                    surface,
                    "Codex project settings ignored",
                    ".codex/config.toml contains keys Codex ignores in project-local config: \(ignored.joined(separator: ", ")).",
                    "Move machine-local provider, auth, notification, profile, and telemetry routing keys to the user-level Codex config."
                ))
            }
        }

        if document.topLevelKeys.contains("approval_policy") {
            if let approval = stringSetting("approval_policy", in: document) {
                if approval == "on-failure" {
                    issues.append(issue(
                        .settingsDeprecatedValue,
                        .warning,
                        surface,
                        "Deprecated Codex approval policy",
                        "\(surface.label) uses approval_policy = \"on-failure\", which Codex treats as deprecated.",
                        "Use on-request for interactive runs or never for non-interactive runs."
                    ))
                } else if !["untrusted", "on-request", "never"].contains(approval) {
                    issues.append(issue(
                        .configUnsupportedShape,
                        .warning,
                        surface,
                        "Unknown Codex approval policy",
                        "\(surface.label) uses approval_policy = \"\(approval)\", which Project Hub does not recognize as a supported string value.",
                        "Check the value before relying on this settings layer.",
                        subjectPath: "approval_policy"
                    ))
                }
            } else if document.topLevelValues["approval_policy"] is [String: Any] {
                // Granular approval tables are documented and validated in a later structured-settings pass.
            } else {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex approval_policy",
                    "\(surface.label) sets approval_policy as \(tomlValueDescription(document.topLevelValues["approval_policy"])), but Codex expects a string or granular approval table.",
                    "Use untrusted, on-request, never, or a documented granular approval table.",
                    subjectPath: "approval_policy"
                ))
            }
        }

        if document.topLevelKeys.contains("sandbox_mode") {
            if let sandbox = stringSetting("sandbox_mode", in: document) {
                if !["read-only", "workspace-write", "danger-full-access"].contains(sandbox) {
                    issues.append(issue(
                        .configUnsupportedShape,
                        .warning,
                        surface,
                        "Unknown Codex sandbox mode",
                        "\(surface.label) uses sandbox_mode = \"\(sandbox)\", which Project Hub does not recognize.",
                        "Use read-only, workspace-write, or danger-full-access unless the official Codex config reference adds a new value.",
                        subjectPath: "sandbox_mode"
                    ))
                }
            } else {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex sandbox_mode",
                    "\(surface.label) sets sandbox_mode as \(tomlValueDescription(document.topLevelValues["sandbox_mode"])), but Codex expects a string.",
                    "Use read-only, workspace-write, or danger-full-access.",
                    subjectPath: "sandbox_mode"
                ))
            }
        }

        if surface.toolID == .codexCLI || surface.toolID == .codexDesktop,
           surface.kind == .settings {
            issues.append(contentsOf: codexEnumSettingIssues(in: document, surface: surface))
            issues.append(contentsOf: codexStructuredSettingIssues(in: document, surface: surface))
            issues.append(contentsOf: codexPluginMCPPolicyIssues(
                in: document,
                surface: surface,
                codexProfileSelection: codexProfileSelection
            ))
        }

        if surface.toolID == .codexCLI || surface.toolID == .codexDesktop,
           surface.kind == .settings,
            document.topLevelKeys.contains("project_doc_max_bytes") {
            if let maxBytes = document.topLevelValues["project_doc_max_bytes"] as? Int {
                if maxBytes < 0 {
                    issues.append(issue(
                        .configUnsupportedShape,
                        .warning,
                        surface,
                        "Invalid Codex project_doc_max_bytes",
                        "\(surface.label) sets project_doc_max_bytes to \(maxBytes), but Codex expects a non-negative TOML integer.",
                        "Set project_doc_max_bytes to 0 to disable project docs or a positive integer such as 32768.",
                        subjectPath: "project_doc_max_bytes"
                    ))
                }
            } else {
                let valueDescription = tomlValueDescription(document.topLevelValues["project_doc_max_bytes"])
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex project_doc_max_bytes",
                    "\(surface.label) sets project_doc_max_bytes as \(valueDescription), but Codex expects a non-negative TOML integer.",
                    "Rewrite project_doc_max_bytes as an unquoted integer such as 32768.",
                    subjectPath: "project_doc_max_bytes"
                ))
            }
        }

        if surface.toolID == .codexCLI || surface.toolID == .codexDesktop,
           surface.kind == .settings {
            issues.append(contentsOf: codexInstructionFileSettingIssues(
                in: document,
                surface: surface,
                key: "model_instructions_file",
                deprecated: false
            ))
            issues.append(contentsOf: codexInstructionFileSettingIssues(
                in: document,
                surface: surface,
                key: "experimental_instructions_file",
                deprecated: true
            ))
        }

        if surface.toolID == .codexCLI || surface.toolID == .codexDesktop,
           surface.kind == .settings,
           document.topLevelKeys.contains("project_doc_fallback_filenames") {
            let raw = document.topLevelRawValues["project_doc_fallback_filenames"]
            if let raw, let values = parseTOMLStringArrayLiteral(raw) {
                let invalid = values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !isCodexFallbackFilename($0) }
                if !invalid.isEmpty {
                    issues.append(issue(
                        .configUnsupportedShape,
                        .warning,
                        surface,
                        "Invalid Codex fallback filenames",
                        "\(surface.label) includes project_doc_fallback_filenames entries that are not plain filenames: \(invalid.joined(separator: ", ")).",
                        "Keep only local filenames such as CLAUDE.md; remove empty values and path-like entries.",
                        subjectPath: "project_doc_fallback_filenames"
                    ))
                }
            } else {
                let valueDescription = tomlValueDescription(document.topLevelValues["project_doc_fallback_filenames"])
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex fallback filenames",
                    "\(surface.label) sets project_doc_fallback_filenames as \(valueDescription), but Codex expects an array of strings.",
                    "Rewrite project_doc_fallback_filenames as an array such as [\"CLAUDE.md\"].",
                    subjectPath: "project_doc_fallback_filenames"
                ))
            }
        }

        if surface.toolID == .codexCLI || surface.toolID == .codexDesktop,
           surface.kind == .settings,
           document.topLevelKeys.contains("project_root_markers") {
            let raw = document.topLevelRawValues["project_root_markers"]
            if let raw, let values = parseTOMLStringArrayLiteral(raw) {
                let invalid = values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !isSafeProjectRootMarker($0) }
                if !invalid.isEmpty {
                    issues.append(issue(
                        .configUnsupportedShape,
                        .warning,
                        surface,
                        "Invalid Codex project root markers",
                        "\(surface.label) includes project_root_markers entries that Project Hub cannot safely resolve: \(invalid.joined(separator: ", ")).",
                        "Keep only relative marker filenames or paths such as package.json or .project-root; remove empty, absolute, traversal, and backslash entries.",
                        subjectPath: "project_root_markers"
                    ))
                }
            } else {
                let valueDescription = tomlValueDescription(document.topLevelValues["project_root_markers"])
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex project root markers",
                    "\(surface.label) sets project_root_markers as \(valueDescription), but Codex expects an array of strings.",
                    "Rewrite project_root_markers as an array such as [\".git\", \"package.json\"].",
                    subjectPath: "project_root_markers"
                ))
            }
        }

        guard let projectRoot,
              surface.scope == .global,
              surface.toolID == .codexCLI || surface.toolID == .codexDesktop,
              let projectSection = codexProjectSection(in: document, projectRoot: projectRoot)
        else { return issues }

        let projectConfigPath = (projectRoot as NSString).appendingPathComponent(".codex/config.toml")
        guard FileManager.default.fileExists(atPath: projectConfigPath),
              let raw = try? String(contentsOfFile: projectConfigPath, encoding: .utf8) else { return issues }
        let projectDocument = parseSettingsTOMLDocument(raw)
        let overlap = projectSection.value.intersection(projectDocument.topLevelKeys)
            .filter { codexProjectSettingKeys.contains($0) }
            .sorted()
        guard !overlap.isEmpty else { return issues }

        issues.append(
            issue(
                .projectSettingsShadowed,
                .warning,
                surface,
                "Codex project settings overlap",
                "\(surface.label) has a [projects] entry for \(tilde(projectRoot)) and the project also has .codex/config.toml values for: \(overlap.joined(separator: ", ")).",
                "Decide whether these settings should live in the global per-project table or the checked-in project config, then remove the duplicate lower-precedence value."
            )
        )
        return issues
    }

    private static func settingsObservation(
        surface: CompatibilityMatrixEntry,
        path: String,
        keys: [String],
        summary: String
    ) -> CompatibilitySettingsObservation {
        CompatibilitySettingsObservation(
            id: surface.id,
            toolID: surface.toolID,
            surfaceID: surface.id,
            label: surface.label,
            path: path,
            scope: surface.scope,
            keys: keys,
            summary: summary,
            fileControlled: surface.fileControlled,
            canWriteSafely: surface.canWriteSafely,
            writeMethod: surface.writeMethod,
            requiresRestartAfterWrite: surface.requiresRestartAfterWrite,
            precedence: surface.precedence
        )
    }

    private static func tomlValueDescription(_ value: Any?) -> String {
        switch value {
        case let value as String:
            return "a string value (\(value))"
        case let value as Bool:
            return "a boolean value (\(value))"
        case let value as [String]:
            return "an array value (\(value.joined(separator: ", ")))"
        case let value as [Any]:
            return "an array value (\(value.map { "\($0)" }.joined(separator: ", ")))"
        case let value as [String: Any]:
            return "an inline table with keys \(value.keys.sorted().joined(separator: ", "))"
        case .some:
            return "an unsupported value"
        case .none:
            return "an empty or unreadable value"
        }
    }

    private static func jsonValueDescription(_ value: Any?) -> String {
        switch value {
        case let value as String:
            return "a string value (\(value))"
        case let value as Bool:
            return "a boolean value (\(value))"
        case let value as NSNumber:
            return "a numeric value (\(value))"
        case let value as [String]:
            return "an array value (\(value.joined(separator: ", ")))"
        case let value as [Any]:
            return "an array value (\(value.map { "\($0)" }.joined(separator: ", ")))"
        case let value as [String: Any]:
            return "an object with keys \(value.keys.sorted().joined(separator: ", "))"
        case .some:
            return "an unsupported value"
        case .none:
            return "an empty or unreadable value"
        }
    }

    private struct SettingsTOMLDocument {
        var topLevelKeys: Set<String>
        var sectionKeys: [String: Set<String>]
        var topLevelValues: [String: Any]
        var sectionValues: [String: [String: Any]]
        var topLevelRawValues: [String: String]
        var sectionRawValues: [String: [String: String]]
        var arrayTables: Set<String>
    }

    private static let codexProjectSettingKeys: Set<String> = [
        "model",
        "approval_policy",
        "sandbox_mode",
        "model_provider",
        "profile",
        "trust_level",
        "preferred_auth_method"
    ]

    private static let codexProjectIgnoredTopLevelKeys: Set<String> = [
        "openai_base_url",
        "chatgpt_base_url",
        "model_provider",
        "model_providers",
        "apps_mcp_product_sku",
        "notify",
        "profile",
        "profiles",
        "experimental_realtime_ws_base_url",
        "otel",
        "preferred_auth_method",
        "cli_auth_credentials_store",
        "mcp_oauth_credentials_store"
    ]

    private static let codexProjectIgnoredSectionRoots: [String] = [
        "model_providers",
        "profiles",
        "otel"
    ]

    private struct CodexEnumSettingSpec {
        let key: String
        let displayName: String
        let values: Set<String>
        let profileScoped: Bool
        let topLevelScoped: Bool
        let acceptsInlineTable: Bool
    }

    private static let codexEnumSettingSpecs: [CodexEnumSettingSpec] = [
        CodexEnumSettingSpec(
            key: "model_reasoning_effort",
            displayName: "model_reasoning_effort",
            values: ["minimal", "low", "medium", "high", "xhigh"],
            profileScoped: true,
            topLevelScoped: true,
            acceptsInlineTable: false
        ),
        CodexEnumSettingSpec(
            key: "model_reasoning_summary",
            displayName: "model_reasoning_summary",
            values: ["auto", "concise", "detailed", "none"],
            profileScoped: true,
            topLevelScoped: true,
            acceptsInlineTable: false
        ),
        CodexEnumSettingSpec(
            key: "model_verbosity",
            displayName: "model_verbosity",
            values: ["low", "medium", "high"],
            profileScoped: true,
            topLevelScoped: true,
            acceptsInlineTable: false
        ),
        CodexEnumSettingSpec(
            key: "oss_provider",
            displayName: "oss_provider",
            values: ["lmstudio", "ollama"],
            profileScoped: true,
            topLevelScoped: true,
            acceptsInlineTable: false
        ),
        CodexEnumSettingSpec(
            key: "approvals_reviewer",
            displayName: "approvals_reviewer",
            values: ["user", "auto_review"],
            profileScoped: true,
            topLevelScoped: true,
            acceptsInlineTable: false
        ),
        CodexEnumSettingSpec(
            key: "web_search",
            displayName: "web_search",
            values: ["disabled", "cached", "live"],
            profileScoped: true,
            topLevelScoped: true,
            acceptsInlineTable: false
        ),
        CodexEnumSettingSpec(
            key: "approval_policy",
            displayName: "approval_policy",
            values: ["untrusted", "on-request", "never"],
            profileScoped: true,
            topLevelScoped: false,
            acceptsInlineTable: true
        ),
        CodexEnumSettingSpec(
            key: "sandbox_mode",
            displayName: "sandbox_mode",
            values: ["read-only", "workspace-write", "danger-full-access"],
            profileScoped: true,
            topLevelScoped: false,
            acceptsInlineTable: false
        )
    ]

    private static func parseSettingsTOMLDocument(_ text: String) -> SettingsTOMLDocument {
        var topLevel = Set<String>()
        var sections: [String: Set<String>] = [:]
        var topLevelValues: [String: Any] = [:]
        var sectionValues: [String: [String: Any]] = [:]
        var topLevelRawValues: [String: String] = [:]
        var sectionRawValues: [String: [String: String]] = [:]
        var arrayTables = Set<String>()
        var currentSection: String?

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            if line.hasPrefix("[[") && line.hasSuffix("]]") {
                let rawSection = String(line.dropFirst(2).dropLast(2))
                let segments = tomlSectionSegments(rawSection)
                let section = segments.isEmpty ? rawSection : segments.joined(separator: ".")
                currentSection = section
                arrayTables.insert(section)
                if sections[section] == nil { sections[section] = [] }
                if sectionValues[section] == nil { sectionValues[section] = [:] }
                if sectionRawValues[section] == nil { sectionRawValues[section] = [:] }
                continue
            }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                let section = String(line.dropFirst().dropLast())
                currentSection = section
                if sections[section] == nil { sections[section] = [] }
                if sectionValues[section] == nil { sectionValues[section] = [:] }
                if sectionRawValues[section] == nil { sectionRawValues[section] = [:] }
                continue
            }

            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard !key.isEmpty else { continue }
            let rawValue = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            let value = parseTOMLValue(rawValue)

            if let currentSection {
                sections[currentSection, default: []].insert(key)
                sectionRawValues[currentSection, default: [:]][key] = rawValue
                if let value {
                    sectionValues[currentSection, default: [:]][key] = value
                }
            } else {
                topLevel.insert(key)
                topLevelRawValues[key] = rawValue
                if let value {
                    topLevelValues[key] = value
                }
            }
        }

        return SettingsTOMLDocument(
            topLevelKeys: topLevel,
            sectionKeys: sections,
            topLevelValues: topLevelValues,
            sectionValues: sectionValues,
            topLevelRawValues: topLevelRawValues,
            sectionRawValues: sectionRawValues,
            arrayTables: arrayTables
        )
    }

    private static func codexSettingsKeys(from document: SettingsTOMLDocument, projectRoot: String?) -> [String] {
        var keys = document.topLevelKeys
        for section in document.sectionKeys.keys {
            if let policy = codexPluginMCPPolicySection(section) {
                if policy.profileName != nil {
                    keys.insert("profiles")
                }
                keys.insert(policy.summaryKey)
                keys.formUnion(codexPluginMCPPolicyKeys(section: section, document: document))
            } else if section.hasPrefix("profiles.") {
                keys.insert("profiles")
            } else if section.hasPrefix("model_providers.") {
                keys.insert("model_providers")
            } else if codexProjectPath(fromSection: section) != nil {
                keys.insert("projects")
            } else if section.hasPrefix("mcp_servers.") {
                keys.insert("mcp_servers")
            } else {
                keys.insert(section)
            }
        }
        if document.arrayTables.contains("skills.config") {
            keys.insert("skills.config")
        }
        if let projectRoot,
           let projectSection = codexProjectSection(in: document, projectRoot: projectRoot) {
            for key in projectSection.value {
                keys.insert("projects.\(key)")
            }
        }
        return keys.sorted()
    }

    private static func isCodexPluginMCPPolicySection(_ section: String) -> Bool {
        codexPluginMCPPolicySection(section) != nil
    }

    private struct CodexPluginMCPPolicySection {
        let profileName: String?
        let relativeSegments: [String]

        var summaryKey: String {
            if let profileName {
                return "profiles.\(profileName).plugins.mcp_servers"
            }
            return "plugins.mcp_servers"
        }

        var keyPrefix: String {
            if let profileName {
                return "profiles.\(profileName)."
            }
            return ""
        }
    }

    private static func codexPluginMCPPolicySection(_ section: String) -> CodexPluginMCPPolicySection? {
        let segments = tomlSectionSegments(section)
        if segments.count >= 3,
           segments[0] == "plugins",
           segments[2] == "mcp_servers" {
            return CodexPluginMCPPolicySection(profileName: nil, relativeSegments: segments)
        }
        if segments.count >= 5,
           segments[0] == "profiles",
           !segments[1].isEmpty,
           segments[2] == "plugins",
           segments[4] == "mcp_servers" {
            return CodexPluginMCPPolicySection(
                profileName: segments[1],
                relativeSegments: Array(segments.dropFirst(2))
            )
        }
        return nil
    }

    private static func codexPluginMCPPolicyKeys(
        section: String,
        document: SettingsTOMLDocument
    ) -> Set<String> {
        guard let policy = codexPluginMCPPolicySection(section) else { return [] }
        let segments = policy.relativeSegments
        guard segments.count >= 4,
              segments[0] == "plugins",
              segments[2] == "mcp_servers" else {
            return []
        }

        var keys: Set<String> = []
        let pluginID = segments[1]
        let serverName = segments[3]
        if segments.count == 4 {
            for key in document.sectionKeys[section] ?? [] {
                keys.insert("\(policy.keyPrefix)plugins.\(pluginID).mcp_servers.\(serverName).\(key)")
            }
        } else if segments.count == 6, segments[4] == "tools" {
            for key in document.sectionKeys[section] ?? [] {
                keys.insert("\(policy.keyPrefix)plugins.\(pluginID).mcp_servers.\(serverName).tools.\(segments[5]).\(key)")
            }
        }
        return keys
    }

    private static let codexPluginMCPApprovalModes: Set<String> = ["auto", "prompt", "approve"]

    private static func codexPluginMCPPolicyIssues(
        in document: SettingsTOMLDocument,
        surface: CompatibilityMatrixEntry,
        codexProfileSelection: CodexProfileSelection?
    ) -> [CompatibilityIssue] {
        var issues: [CompatibilityIssue] = []
        let activeProfile = codexEffectiveProfile(
            in: document,
            toolID: surface.toolID,
            selection: codexProfileSelection
        )?.name
        for section in document.sectionKeys.keys.sorted() {
            guard let policy = codexPluginMCPPolicySection(section) else { continue }
            let segments = policy.relativeSegments

            let keys = document.sectionKeys[section] ?? []
            let values = document.sectionValues[section] ?? [:]
            let rawValues = document.sectionRawValues[section] ?? [:]

            if segments.count == 3 {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex plugin MCP policy section",
                    "\(surface.label) has [\(section)], but Codex plugin MCP policy sections must name a server.",
                    policy.profileName == nil
                        ? "Use [plugins.<plugin>.mcp_servers.<server>] for server policy."
                        : "Use [profiles.<name>.plugins.<plugin>.mcp_servers.<server>] for profile-scoped server policy.",
                    subjectPath: section
                ))
                continue
            }

            if segments.count == 4 {
                let allowed: Set<String> = [
                    "enabled",
                    "default_tools_approval_mode",
                    "enabled_tools",
                    "disabled_tools"
                ]
                for key in keys.subtracting(allowed).sorted() {
                    issues.append(codexPluginMCPPolicyUnsupportedKeyIssue(
                        section: section,
                        key: key,
                        surface: surface,
                        expected: "enabled, default_tools_approval_mode, enabled_tools, or disabled_tools"
                    ))
                }
                if keys.contains("enabled"), !(values["enabled"] is Bool) {
                    issues.append(codexPluginMCPPolicyTypeIssue(
                        section: section,
                        key: "enabled",
                        value: values["enabled"],
                        surface: surface,
                        expected: "a boolean"
                    ))
                }
                if keys.contains("default_tools_approval_mode") {
                    codexPluginMCPApprovalModeIssue(
                        section: section,
                        key: "default_tools_approval_mode",
                        values: values,
                        surface: surface
                    ).map { issues.append($0) }
                }
                for key in ["enabled_tools", "disabled_tools"] where keys.contains(key) {
                    if rawValues[key].flatMap(parseTOMLStringArrayLiteral) == nil {
                        issues.append(codexPluginMCPPolicyTypeIssue(
                            section: section,
                            key: key,
                            value: values[key],
                            surface: surface,
                            expected: "an array of strings"
                        ))
                    }
                }
                if let profileName = policy.profileName,
                   profileName != activeProfile,
                   keys.contains("enabled"),
                   boolSettingValue(values["enabled"]) == false {
                    let defaultCopy = activeProfile.map { "The current default profile is \($0)." } ?? "No default profile is set."
                    issues.append(issue(
                        .settingsProfileScopedPolicy,
                        .info,
                        surface,
                        "Codex profile-scoped MCP policy is conditional",
                        "\(surface.label) disables plugin MCP server \(segments[3]) in profile \(profileName), but Codex only applies that profile policy when the session selects profile \(profileName). \(defaultCopy) Project Hub cannot observe one-off CLI `codex --profile \(profileName)` runs from this config scan, so the base plugin MCP server stays enabled in the current inventory.",
                        "If this policy should apply by default, set top-level profile = \"\(profileName)\". Otherwise treat it as profile-specific runtime policy for `codex --profile \(profileName)` sessions.",
                        subjectPath: "\(section).enabled"
                    ))
                }
            } else if segments.count == 5, segments[4] == "tools" {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex plugin tool policy section",
                    "\(surface.label) has [\(section)], but Codex plugin tool policy sections must name a tool.",
                    policy.profileName == nil
                        ? "Use [plugins.<plugin>.mcp_servers.<server>.tools.<tool>] for per-tool approval policy."
                        : "Use [profiles.<name>.plugins.<plugin>.mcp_servers.<server>.tools.<tool>] for profile-scoped per-tool approval policy.",
                    subjectPath: section
                ))
            } else if segments.count == 6, segments[4] == "tools" {
                let allowed: Set<String> = ["approval_mode"]
                for key in keys.subtracting(allowed).sorted() {
                    issues.append(codexPluginMCPPolicyUnsupportedKeyIssue(
                        section: section,
                        key: key,
                        surface: surface,
                        expected: "approval_mode"
                    ))
                }
                if keys.contains("approval_mode") {
                    codexPluginMCPApprovalModeIssue(
                        section: section,
                        key: "approval_mode",
                        values: values,
                        surface: surface
                    ).map { issues.append($0) }
                }
            } else {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex plugin MCP policy section",
                    "\(surface.label) has [\(section)], but Project Hub only recognizes documented plugin MCP server and tool policy sections.",
                    policy.profileName == nil
                        ? "Use [plugins.<plugin>.mcp_servers.<server>] or [plugins.<plugin>.mcp_servers.<server>.tools.<tool>]."
                        : "Use [profiles.<name>.plugins.<plugin>.mcp_servers.<server>] or [profiles.<name>.plugins.<plugin>.mcp_servers.<server>.tools.<tool>].",
                    subjectPath: section
                ))
            }
        }
        return issues
    }

    private static func codexPluginMCPApprovalModeIssue(
        section: String,
        key: String,
        values: [String: Any],
        surface: CompatibilityMatrixEntry
    ) -> CompatibilityIssue? {
        guard let value = values[key] as? String,
              codexPluginMCPApprovalModes.contains(value) else {
            return codexPluginMCPPolicyTypeIssue(
                section: section,
                key: key,
                value: values[key],
                surface: surface,
                expected: "auto, prompt, or approve"
            )
        }
        return nil
    }

    private static func codexPluginMCPPolicyUnsupportedKeyIssue(
        section: String,
        key: String,
        surface: CompatibilityMatrixEntry,
        expected: String
    ) -> CompatibilityIssue {
        issue(
            .configUnsupportedShape,
            .warning,
            surface,
            "Unknown Codex plugin MCP policy key",
            "\(surface.label) sets \(section).\(key), but documented Codex plugin MCP policy keys for this section are \(expected).",
            "Remove the unsupported key or verify it against the current Codex config reference before relying on it.",
            subjectPath: "\(section).\(key)",
            metadata: [
                "codexPluginMCPPolicySection": section,
                "codexPluginMCPPolicyKey": key,
                "codexPluginMCPPolicyRepair": "remove-section-key",
                "codexPluginMCPPolicyExpected": expected
            ]
        )
    }

    private static func codexPluginMCPPolicyTypeIssue(
        section: String,
        key: String,
        value: Any?,
        surface: CompatibilityMatrixEntry,
        expected: String
    ) -> CompatibilityIssue {
        issue(
            .configUnsupportedShape,
            .warning,
            surface,
            "Invalid Codex plugin MCP policy value",
            "\(surface.label) sets \(section).\(key) as \(tomlValueDescription(value)), but Codex expects \(expected).",
            "Rewrite the value using the documented Codex plugin MCP policy schema.",
            subjectPath: "\(section).\(key)",
            metadata: [
                "codexPluginMCPPolicySection": section,
                "codexPluginMCPPolicyKey": key,
                "codexPluginMCPPolicyRepair": "remove-section-key",
                "codexPluginMCPPolicyExpected": expected
            ]
        )
    }

    private static func codexProjectSection(
        in document: SettingsTOMLDocument,
        projectRoot: String
    ) -> (name: String, value: Set<String>)? {
        for (section, keys) in document.sectionKeys {
            if let project = codexProjectPath(fromSection: section),
               Project.canonicalize(project) == projectRoot {
                return (section, keys)
            }
        }
        return nil
    }

    private static func codexProjectPath(fromSection section: String) -> String? {
        let segments = tomlSectionSegments(section)
        guard segments.count == 2, segments[0] == "projects" else { return nil }
        return segments[1]
    }

    private static func ignoredCodexProjectKeys(in document: SettingsTOMLDocument) -> [String] {
        var ignored = document.topLevelKeys
            .intersection(codexProjectIgnoredTopLevelKeys)
            .sorted()

        for section in document.sectionKeys.keys.sorted() {
            if isCodexProjectIgnoredSection(section) {
                ignored.append(section)
            }
        }

        return ignored
    }

    private static func isCodexProjectIgnoredSection(_ section: String) -> Bool {
        codexProjectIgnoredSectionRoots.contains { root in
            section == root || section.hasPrefix("\(root).")
        }
    }

    private static func codexInstructionFileSettingIssues(
        in document: SettingsTOMLDocument,
        surface: CompatibilityMatrixEntry,
        key: String,
        deprecated: Bool
    ) -> [CompatibilityIssue] {
        guard document.topLevelKeys.contains(key) else { return [] }
        let raw = document.topLevelRawValues[key]
        let value = raw.flatMap {
            parseTOMLStringLiteral(splitTOMLValueAndComment($0).value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let valueDescription: String
        if let parsed = document.topLevelValues[key] {
            valueDescription = tomlValueDescription(parsed)
        } else if let raw {
            valueDescription = "raw value \(raw)"
        } else {
            valueDescription = "an empty or unreadable value"
        }
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Invalid Codex \(key)",
                "\(surface.label) sets \(key) as \(valueDescription), but Codex expects a non-empty string path.",
                "Rewrite \(key) as a string path or remove it and use AGENTS.md for project guidance.",
                subjectPath: key
            )]
        }
        guard deprecated else { return [] }
        return [issue(
            .settingsDeprecatedValue,
            .warning,
            surface,
            "Deprecated Codex experimental_instructions_file",
            "\(surface.label) uses experimental_instructions_file, which Codex now deprecates in favor of model_instructions_file.",
            "Rename experimental_instructions_file to model_instructions_file, or remove it and use AGENTS.md for normal project guidance.",
            subjectPath: key
        )]
    }

    private static func codexEnumSettingIssues(
        in document: SettingsTOMLDocument,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        var issues: [CompatibilityIssue] = []

        for spec in codexEnumSettingSpecs where spec.topLevelScoped {
            guard document.topLevelKeys.contains(spec.key) else { continue }
            if let value = document.topLevelValues[spec.key] as? String {
                guard !spec.values.contains(value) else { continue }
                issues.append(codexEnumSettingIssue(
                    spec: spec,
                    valueDescription: "\"\(value)\"",
                    subjectPath: spec.key,
                    surface: surface
                ))
            } else if spec.acceptsInlineTable,
                      document.topLevelValues[spec.key] is [String: Any] {
                continue
            } else {
                issues.append(codexEnumSettingIssue(
                    spec: spec,
                    valueDescription: tomlValueDescription(document.topLevelValues[spec.key]),
                    subjectPath: spec.key,
                    surface: surface
                ))
            }
        }

        for (section, values) in document.sectionValues where isCodexProfileRootSection(section) {
            for spec in codexEnumSettingSpecs where spec.profileScoped {
                guard document.sectionKeys[section]?.contains(spec.key) == true else { continue }
                let subjectPath = "\(section).\(spec.key)"
                if let value = values[spec.key] as? String {
                    guard !spec.values.contains(value) else { continue }
                    issues.append(codexEnumSettingIssue(
                        spec: spec,
                        valueDescription: "\"\(value)\"",
                        subjectPath: subjectPath,
                        surface: surface
                    ))
                } else if spec.acceptsInlineTable,
                          values[spec.key] is [String: Any] {
                    continue
                } else {
                    issues.append(codexEnumSettingIssue(
                        spec: spec,
                        valueDescription: tomlValueDescription(values[spec.key]),
                        subjectPath: subjectPath,
                        surface: surface
                    ))
                }
            }
        }

        for (section, values) in document.sectionValues where codexProjectPath(fromSection: section) != nil {
            guard document.sectionKeys[section]?.contains("trust_level") == true else { continue }
            let subjectPath = "\(section).trust_level"
            if let value = values["trust_level"] as? String {
                guard !["trusted", "untrusted"].contains(value) else { continue }
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex trust_level",
                    "\(surface.label) sets \(subjectPath) to \"\(value)\", but Codex documents trusted or untrusted.",
                    "Set trust_level to trusted or untrusted through Codex's official trust flow or edit the project override carefully.",
                    subjectPath: subjectPath
                ))
            } else {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex trust_level",
                    "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(values["trust_level"])), but Codex expects a string.",
                    "Set trust_level to trusted or untrusted through Codex's official trust flow or edit the project override carefully.",
                    subjectPath: subjectPath
                ))
            }
        }

        return issues
    }

    private static func isCodexProfileRootSection(_ section: String) -> Bool {
        guard section.hasPrefix("profiles.") else { return false }
        let remainder = String(section.dropFirst("profiles.".count))
        return !remainder.isEmpty && !remainder.contains(".")
    }

    private static func codexEnumSettingIssue(
        spec: CodexEnumSettingSpec,
        valueDescription: String,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> CompatibilityIssue {
        issue(
            .configUnsupportedShape,
            .warning,
            surface,
            "Invalid Codex \(spec.displayName)",
            "\(surface.label) sets \(subjectPath) to \(valueDescription), but Codex documents \(spec.values.sorted().joined(separator: ", ")).",
            "Remove the invalid value to let Codex use its default, or replace it with one of the documented values.",
            subjectPath: subjectPath
        )
    }

    private static func codexStructuredSettingIssues(
        in document: SettingsTOMLDocument,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        var issues: [CompatibilityIssue] = []
        issues.append(contentsOf: codexGranularApprovalIssues(in: document, surface: surface))
        issues.append(contentsOf: codexSandboxWorkspaceWriteIssues(in: document, surface: surface))
        issues.append(contentsOf: codexWebAndNetworkSettingIssues(in: document, surface: surface))
        issues.append(contentsOf: codexPermissionNetworkSettingIssues(in: document, surface: surface))
        issues.append(contentsOf: codexWorkspaceRootsSettingIssues(in: document, surface: surface))
        if surface.id == "codex-requirements" {
            issues.append(contentsOf: codexRequirementsFilesystemPermissionIssues(in: document, surface: surface))
            issues.append(contentsOf: codexMCPServerIdentitySettingIssues(in: document, surface: surface))
        } else {
            issues.append(contentsOf: codexNamedFilesystemPermissionSettingIssues(in: document, surface: surface))
        }
        return issues
    }

    private static let codexGranularApprovalKeys: Set<String> = [
        "sandbox_approval",
        "rules",
        "mcp_elicitations",
        "request_permissions",
        "skill_approval"
    ]

    private static func codexGranularApprovalIssues(
        in document: SettingsTOMLDocument,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        var issues: [CompatibilityIssue] = []

        if let approval = document.topLevelValues["approval_policy"] as? [String: Any] {
            issues.append(contentsOf: codexGranularApprovalTableIssues(
                approval["granular"],
                subjectPath: "approval_policy.granular",
                surface: surface
            ))
        }

        for key in document.topLevelKeys where key.hasPrefix("approval_policy.granular.") {
            let granularKey = String(key.dropFirst("approval_policy.granular.".count))
            issues.append(contentsOf: codexGranularApprovalKeyIssues(
                key: granularKey,
                value: document.topLevelValues[key],
                subjectPath: key,
                surface: surface
            ))
        }

        if let sectionKeys = document.sectionKeys["approval_policy.granular"] {
            for key in sectionKeys {
                issues.append(contentsOf: codexGranularApprovalKeyIssues(
                    key: key,
                    value: document.sectionValues["approval_policy.granular"]?[key],
                    subjectPath: "approval_policy.granular.\(key)",
                    surface: surface
                ))
            }
        }

        if document.sectionKeys["approval_policy"]?.contains("granular") == true {
            issues.append(contentsOf: codexGranularApprovalTableIssues(
                document.sectionValues["approval_policy"]?["granular"],
                subjectPath: "approval_policy.granular",
                surface: surface
            ))
        }

        for (section, values) in document.sectionValues where section.hasPrefix("profiles.") {
            if let approval = values["approval_policy"] as? [String: Any] {
                issues.append(contentsOf: codexGranularApprovalTableIssues(
                    approval["granular"],
                    subjectPath: "\(section).approval_policy.granular",
                    surface: surface
                ))
            }
        }

        for (section, keys) in document.sectionKeys where section.hasPrefix("profiles.") && section.hasSuffix(".approval_policy.granular") {
            for key in keys {
                issues.append(contentsOf: codexGranularApprovalKeyIssues(
                    key: key,
                    value: document.sectionValues[section]?[key],
                    subjectPath: "\(section).\(key)",
                    surface: surface
                ))
            }
        }

        for (section, values) in document.sectionValues where section.hasPrefix("profiles.") && section.hasSuffix(".approval_policy") {
            if document.sectionKeys[section]?.contains("granular") == true {
                issues.append(contentsOf: codexGranularApprovalTableIssues(
                    values["granular"],
                    subjectPath: "\(section).granular",
                    surface: surface
                ))
            }
        }

        return issues
    }

    private static func codexGranularApprovalTableIssues(
        _ value: Any?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        guard let table = value as? [String: Any] else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Invalid Codex granular approval policy",
                "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a table of boolean prompt controls.",
                "Use only boolean granular approval keys: \(codexGranularApprovalKeys.sorted().joined(separator: ", ")).",
                subjectPath: subjectPath
            )]
        }

        var issues: [CompatibilityIssue] = []
        for key in table.keys.sorted() {
            issues.append(contentsOf: codexGranularApprovalKeyIssues(
                key: key,
                value: table[key],
                subjectPath: "\(subjectPath).\(key)",
                surface: surface
            ))
        }
        return issues
    }

    private static func codexGranularApprovalKeyIssues(
        key: String,
        value: Any?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        guard codexGranularApprovalKeys.contains(key) else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Unknown Codex granular approval key",
                "\(surface.label) sets \(subjectPath), but Codex documents only \(codexGranularApprovalKeys.sorted().joined(separator: ", ")).",
                "Remove the unknown granular approval key or confirm it against the official Codex config reference.",
                subjectPath: subjectPath
            )]
        }
        guard !(value is Bool) else { return [] }
        return [issue(
            .configUnsupportedShape,
            .warning,
            surface,
            "Invalid Codex granular approval value",
            "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a boolean.",
            "Use true or false for each granular approval prompt control.",
            subjectPath: subjectPath
        )]
    }

    private static let codexSandboxWorkspaceWriteBoolKeys: Set<String> = [
        "exclude_slash_tmp",
        "exclude_tmpdir_env_var",
        "network_access"
    ]

    private static let codexSandboxWorkspaceWriteArrayKeys: Set<String> = [
        "writable_roots"
    ]

    private static func codexSandboxWorkspaceWriteIssues(
        in document: SettingsTOMLDocument,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        var issues: [CompatibilityIssue] = []
        let prefix = "sandbox_workspace_write."

        if document.topLevelKeys.contains("sandbox_workspace_write") {
            if let table = document.topLevelValues["sandbox_workspace_write"] as? [String: Any] {
                for key in table.keys.sorted() {
                    issues.append(contentsOf: codexSandboxWorkspaceWriteKeyIssues(
                        key: key,
                        value: table[key],
                        rawValue: nil,
                        subjectPath: "sandbox_workspace_write.\(key)",
                        surface: surface
                    ))
                }
            } else {
                issues.append(issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex sandbox_workspace_write",
                    "\(surface.label) sets sandbox_workspace_write as \(tomlValueDescription(document.topLevelValues["sandbox_workspace_write"])), but Codex expects a table of workspace-write options.",
                    "Use dotted sandbox_workspace_write keys, a [sandbox_workspace_write] table, or a valid inline table.",
                    subjectPath: "sandbox_workspace_write"
                ))
            }
        }

        for key in document.topLevelKeys where key.hasPrefix(prefix) {
            let setting = String(key.dropFirst(prefix.count))
            issues.append(contentsOf: codexSandboxWorkspaceWriteKeyIssues(
                key: setting,
                value: document.topLevelValues[key],
                rawValue: document.topLevelRawValues[key],
                subjectPath: key,
                surface: surface
            ))
        }

        if let sectionKeys = document.sectionKeys["sandbox_workspace_write"] {
            for key in sectionKeys {
                issues.append(contentsOf: codexSandboxWorkspaceWriteKeyIssues(
                    key: key,
                    value: document.sectionValues["sandbox_workspace_write"]?[key],
                    rawValue: document.sectionRawValues["sandbox_workspace_write"]?[key],
                    subjectPath: "sandbox_workspace_write.\(key)",
                    surface: surface
                ))
            }
        }

        for (section, values) in document.sectionValues where section.hasPrefix("profiles.") {
            if document.sectionKeys[section]?.contains("sandbox_workspace_write") == true {
                issues.append(contentsOf: codexSandboxWorkspaceWriteTableIssues(
                    values["sandbox_workspace_write"],
                    subjectPath: "\(section).sandbox_workspace_write",
                    surface: surface
                ))
            }

            for key in document.sectionKeys[section] ?? [] where key.hasPrefix(prefix) {
                let setting = String(key.dropFirst(prefix.count))
                issues.append(contentsOf: codexSandboxWorkspaceWriteKeyIssues(
                    key: setting,
                    value: values[key],
                    rawValue: document.sectionRawValues[section]?[key],
                    subjectPath: "\(section).\(key)",
                    surface: surface
                ))
            }
        }

        let profileSandboxMarker = ".sandbox_workspace_write."
        for key in document.topLevelKeys where key.hasPrefix("profiles.") && key.contains(profileSandboxMarker) {
            guard let markerRange = key.range(of: profileSandboxMarker) else { continue }
            let setting = String(key[markerRange.upperBound...])
            issues.append(contentsOf: codexSandboxWorkspaceWriteKeyIssues(
                key: setting,
                value: document.topLevelValues[key],
                rawValue: document.topLevelRawValues[key],
                subjectPath: key,
                surface: surface
            ))
        }

        for (section, keys) in document.sectionKeys where section.hasPrefix("profiles.") && section.hasSuffix(".sandbox_workspace_write") {
            for key in keys {
                issues.append(contentsOf: codexSandboxWorkspaceWriteKeyIssues(
                    key: key,
                    value: document.sectionValues[section]?[key],
                    rawValue: document.sectionRawValues[section]?[key],
                    subjectPath: "\(section).\(key)",
                    surface: surface
                ))
            }
        }

        return issues
    }

    private static func codexSandboxWorkspaceWriteTableIssues(
        _ value: Any?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        guard let table = value as? [String: Any] else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Invalid Codex sandbox_workspace_write",
                "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a table of workspace-write options.",
                "Use dotted sandbox_workspace_write keys, a [sandbox_workspace_write] table, or a valid inline table.",
                subjectPath: subjectPath
            )]
        }

        var issues: [CompatibilityIssue] = []
        for key in table.keys.sorted() {
            issues.append(contentsOf: codexSandboxWorkspaceWriteKeyIssues(
                key: key,
                value: table[key],
                rawValue: nil,
                subjectPath: "\(subjectPath).\(key)",
                surface: surface
            ))
        }
        return issues
    }

    private static func codexSandboxWorkspaceWriteKeyIssues(
        key: String,
        value: Any?,
        rawValue: String?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        if codexSandboxWorkspaceWriteBoolKeys.contains(key) {
            guard !(value is Bool) else { return [] }
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Invalid Codex sandbox workspace-write value",
                "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a boolean.",
                "Use true or false for sandbox_workspace_write.\(key).",
                subjectPath: subjectPath
            )]
        }

        if codexSandboxWorkspaceWriteArrayKeys.contains(key) {
            if let rawValue, parseTOMLStringArrayLiteral(rawValue) != nil {
                return []
            }
            if rawValue == nil,
               let values = value as? [Any],
               values.allSatisfy({ $0 is String }) {
                return []
            }
            if rawValue == nil,
               value is [String] {
                return []
            }
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Invalid Codex sandbox writable_roots",
                "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects an array of strings.",
                "Use writable_roots = [\"/absolute/path\"] or remove the malformed setting.",
                subjectPath: subjectPath
            )]
        }

        return [issue(
            .configUnsupportedShape,
            .warning,
            surface,
            "Unknown Codex sandbox workspace-write key",
            "\(surface.label) sets \(subjectPath), but Codex documents only \(codexSandboxWorkspaceWriteBoolKeys.union(codexSandboxWorkspaceWriteArrayKeys).sorted().joined(separator: ", ")).",
            "Remove the unknown sandbox_workspace_write key or confirm it against the official Codex config reference.",
            subjectPath: subjectPath
        )]
    }

    private static func codexWebAndNetworkSettingIssues(
        in document: SettingsTOMLDocument,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        var issues: [CompatibilityIssue] = []

        issues.append(contentsOf: codexToolsWebSearchIssues(in: document, surface: surface))
        issues.append(contentsOf: codexFeaturesNetworkProxyIssues(in: document, surface: surface))
        issues.append(contentsOf: codexFeatureBooleanIssues(in: document, surface: surface))

        return issues
    }

    private static let codexToolsWebSearchTopKeys: Set<String> = [
        "context_size",
        "allowed_domains",
        "location"
    ]

    private static let codexToolsWebSearchContextSizes: Set<String> = [
        "low",
        "medium",
        "high"
    ]

    private static let codexToolsWebSearchLocationKeys: Set<String> = [
        "country",
        "region",
        "city",
        "timezone"
    ]

    private static func codexToolsWebSearchIssues(
        in document: SettingsTOMLDocument,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        var issues: [CompatibilityIssue] = []

        if document.topLevelKeys.contains("tools.web_search") {
            issues.append(contentsOf: codexToolsWebSearchValueIssues(
                value: document.topLevelValues["tools.web_search"],
                rawValue: document.topLevelRawValues["tools.web_search"],
                subjectPath: "tools.web_search",
                surface: surface
            ))
        }

        for key in document.topLevelKeys where key.hasPrefix("tools.web_search.") {
            let setting = String(key.dropFirst("tools.web_search.".count))
            issues.append(contentsOf: codexToolsWebSearchKeyIssues(
                key: setting,
                value: document.topLevelValues[key],
                rawValue: document.topLevelRawValues[key],
                subjectPath: key,
                surface: surface
            ))
        }

        if document.sectionKeys["tools"]?.contains("web_search") == true {
            issues.append(contentsOf: codexToolsWebSearchValueIssues(
                value: document.sectionValues["tools"]?["web_search"],
                rawValue: document.sectionRawValues["tools"]?["web_search"],
                subjectPath: "tools.web_search",
                surface: surface
            ))
        }

        if let keys = document.sectionKeys["tools.web_search"] {
            for key in keys {
                issues.append(contentsOf: codexToolsWebSearchKeyIssues(
                    key: key,
                    value: document.sectionValues["tools.web_search"]?[key],
                    rawValue: document.sectionRawValues["tools.web_search"]?[key],
                    subjectPath: "tools.web_search.\(key)",
                    surface: surface
                ))
            }
        }

        if let keys = document.sectionKeys["tools.web_search.location"] {
            for key in keys {
                issues.append(contentsOf: codexToolsWebSearchLocationKeyIssues(
                    key: key,
                    value: document.sectionValues["tools.web_search.location"]?[key],
                    subjectPath: "tools.web_search.location.\(key)",
                    surface: surface
                ))
            }
        }

        for (section, values) in document.sectionValues where section.hasPrefix("profiles.") {
            if document.sectionKeys[section]?.contains("tools.web_search") == true {
                issues.append(contentsOf: codexToolsWebSearchValueIssues(
                    value: values["tools.web_search"],
                    rawValue: document.sectionRawValues[section]?["tools.web_search"],
                    subjectPath: "\(section).tools.web_search",
                    surface: surface
                ))
            }
        }

        for (section, values) in document.sectionValues where section.hasPrefix("profiles.") && section.hasSuffix(".tools") {
            if document.sectionKeys[section]?.contains("web_search") == true {
                issues.append(contentsOf: codexToolsWebSearchValueIssues(
                    value: values["web_search"],
                    rawValue: document.sectionRawValues[section]?["web_search"],
                    subjectPath: "\(section).web_search",
                    surface: surface
                ))
            }
        }

        for (section, keys) in document.sectionKeys where section.hasPrefix("profiles.") && section.hasSuffix(".tools.web_search") {
            for key in keys {
                issues.append(contentsOf: codexToolsWebSearchKeyIssues(
                    key: key,
                    value: document.sectionValues[section]?[key],
                    rawValue: document.sectionRawValues[section]?[key],
                    subjectPath: "\(section).\(key)",
                    surface: surface
                ))
            }
        }

        for (section, keys) in document.sectionKeys where section.hasPrefix("profiles.") && section.hasSuffix(".tools.web_search.location") {
            for key in keys {
                issues.append(contentsOf: codexToolsWebSearchLocationKeyIssues(
                    key: key,
                    value: document.sectionValues[section]?[key],
                    subjectPath: "\(section).\(key)",
                    surface: surface
                ))
            }
        }

        return issues
    }

    private static func codexToolsWebSearchValueIssues(
        value: Any?,
        rawValue: String?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        if value is Bool { return [] }
        if let table = value as? [String: Any] {
            var issues: [CompatibilityIssue] = []
            for key in table.keys.sorted() {
                issues.append(contentsOf: codexToolsWebSearchKeyIssues(
                    key: key,
                    value: table[key],
                    rawValue: nil,
                    subjectPath: "\(subjectPath).\(key)",
                    surface: surface
                ))
            }
            return issues
        }
        return [issue(
            .configUnsupportedShape,
            .warning,
            surface,
            "Invalid Codex tools.web_search",
            "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a boolean or web search options table.",
            "Use true, false, or a table with context_size, allowed_domains, and location.",
            subjectPath: subjectPath
        )]
    }

    private static func codexToolsWebSearchKeyIssues(
        key: String,
        value: Any?,
        rawValue: String?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        if key.hasPrefix("location.") {
            let locationKey = String(key.dropFirst("location.".count))
            return codexToolsWebSearchLocationKeyIssues(
                key: locationKey,
                value: value,
                subjectPath: subjectPath,
                surface: surface
            )
        }

        guard codexToolsWebSearchTopKeys.contains(key) else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Unknown Codex tools.web_search key",
                "\(surface.label) sets \(subjectPath), but Codex documents only \(codexToolsWebSearchTopKeys.sorted().joined(separator: ", ")).",
                "Remove the unknown tools.web_search key or confirm it against the official Codex config reference.",
                subjectPath: subjectPath
            )]
        }

        switch key {
        case "context_size":
            guard let value = value as? String,
                  codexToolsWebSearchContextSizes.contains(value) else {
                return [issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex web search context size",
                    "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects low, medium, or high.",
                    "Set context_size to low, medium, or high.",
                    subjectPath: subjectPath
                )]
            }
            return []
        case "allowed_domains":
            if let rawValue, parseTOMLStringArrayLiteral(rawValue) != nil {
                return []
            }
            if rawValue == nil,
               let values = value as? [Any],
               values.allSatisfy({ $0 is String }) {
                return []
            }
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Invalid Codex web search allowed domains",
                "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects an array of strings.",
                "Use allowed_domains = [\"example.com\"] or remove the malformed setting.",
                subjectPath: subjectPath
            )]
        case "location":
            guard let table = value as? [String: Any] else {
                return [issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex web search location",
                    "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a table.",
                    "Use a location table with country, region, city, and timezone string values.",
                    subjectPath: subjectPath
                )]
            }
            return table.keys.sorted().flatMap { locationKey in
                codexToolsWebSearchLocationKeyIssues(
                    key: locationKey,
                    value: table[locationKey],
                    subjectPath: "\(subjectPath).\(locationKey)",
                    surface: surface
                )
            }
        default:
            return []
        }
    }

    private static func codexToolsWebSearchLocationKeyIssues(
        key: String,
        value: Any?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        guard codexToolsWebSearchLocationKeys.contains(key) else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Unknown Codex web search location key",
                "\(surface.label) sets \(subjectPath), but Codex documents only \(codexToolsWebSearchLocationKeys.sorted().joined(separator: ", ")).",
                "Remove the unknown web search location key or confirm it against the official Codex config reference.",
                subjectPath: subjectPath
            )]
        }
        guard value is String else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Invalid Codex web search location value",
                "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a string.",
                "Use string values for web search location fields.",
                subjectPath: subjectPath
            )]
        }
        return []
    }

    private static let codexNetworkProxyBoolKeys: Set<String> = [
        "enabled",
        "allow_local_binding",
        "allow_upstream_proxy",
        "dangerously_allow_all_unix_sockets",
        "dangerously_allow_non_loopback_proxy",
        "enable_socks5",
        "enable_socks5_udp"
    ]

    private static let codexNetworkProxyStringKeys: Set<String> = [
        "proxy_url",
        "socks_url"
    ]

    private static let codexNetworkProxyTableKeys: Set<String> = [
        "domains",
        "unix_sockets"
    ]

    private static func codexFeaturesNetworkProxyIssues(
        in document: SettingsTOMLDocument,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        var issues: [CompatibilityIssue] = []
        let prefix = "features.network_proxy."

        if document.topLevelKeys.contains("features.network_proxy") {
            issues.append(contentsOf: codexNetworkProxyValueIssues(
                value: document.topLevelValues["features.network_proxy"],
                subjectPath: "features.network_proxy",
                surface: surface
            ))
        }

        for key in document.topLevelKeys where key.hasPrefix(prefix) {
            let setting = String(key.dropFirst(prefix.count))
            issues.append(contentsOf: codexNetworkProxyKeyIssues(
                key: setting,
                value: document.topLevelValues[key],
                subjectPath: key,
                surface: surface
            ))
        }

        if document.sectionKeys["features"]?.contains("network_proxy") == true {
            issues.append(contentsOf: codexNetworkProxyValueIssues(
                value: document.sectionValues["features"]?["network_proxy"],
                subjectPath: "features.network_proxy",
                surface: surface
            ))
        }

        if let keys = document.sectionKeys["features.network_proxy"] {
            for key in keys {
                issues.append(contentsOf: codexNetworkProxyKeyIssues(
                    key: key,
                    value: document.sectionValues["features.network_proxy"]?[key],
                    subjectPath: "features.network_proxy.\(key)",
                    surface: surface
                ))
            }
        }

        if let domains = document.sectionValues["features.network_proxy.domains"] {
            for key in domains.keys.sorted() {
                issues.append(contentsOf: codexNetworkPolicyMapEntryIssues(
                    value: domains[key],
                    allowed: ["allow", "deny"],
                    subjectPath: "features.network_proxy.domains.\(key)",
                    title: "Invalid Codex network proxy domain rule",
                    detailValues: "allow or deny",
                    surface: surface
                ))
            }
        }

        if let sockets = document.sectionValues["features.network_proxy.unix_sockets"] {
            for key in sockets.keys.sorted() {
                issues.append(contentsOf: codexNetworkPolicyMapEntryIssues(
                    value: sockets[key],
                    allowed: ["allow", "none"],
                    subjectPath: "features.network_proxy.unix_sockets.\(key)",
                    title: "Invalid Codex network proxy Unix socket rule",
                    detailValues: "allow or none",
                    surface: surface
                ))
            }
        }

        for (section, values) in document.sectionValues where section.hasPrefix("profiles.") {
            if document.sectionKeys[section]?.contains("features.network_proxy") == true {
                issues.append(contentsOf: codexNetworkProxyValueIssues(
                    value: values["features.network_proxy"],
                    subjectPath: "\(section).features.network_proxy",
                    surface: surface
                ))
            }
        }

        for (section, values) in document.sectionValues where section.hasPrefix("profiles.") && section.hasSuffix(".features") {
            if document.sectionKeys[section]?.contains("network_proxy") == true {
                issues.append(contentsOf: codexNetworkProxyValueIssues(
                    value: values["network_proxy"],
                    subjectPath: "\(section).network_proxy",
                    surface: surface
                ))
            }
        }

        for (section, keys) in document.sectionKeys where section.hasPrefix("profiles.") && section.hasSuffix(".features.network_proxy") {
            for key in keys {
                issues.append(contentsOf: codexNetworkProxyKeyIssues(
                    key: key,
                    value: document.sectionValues[section]?[key],
                    subjectPath: "\(section).\(key)",
                    surface: surface
                ))
            }
        }

        for (section, values) in document.sectionValues where section.hasPrefix("profiles.") && section.hasSuffix(".features.network_proxy.domains") {
            for key in values.keys.sorted() {
                issues.append(contentsOf: codexNetworkPolicyMapEntryIssues(
                    value: values[key],
                    allowed: ["allow", "deny"],
                    subjectPath: "\(section).\(key)",
                    title: "Invalid Codex network proxy domain rule",
                    detailValues: "allow or deny",
                    surface: surface
                ))
            }
        }

        for (section, values) in document.sectionValues where section.hasPrefix("profiles.") && section.hasSuffix(".features.network_proxy.unix_sockets") {
            for key in values.keys.sorted() {
                issues.append(contentsOf: codexNetworkPolicyMapEntryIssues(
                    value: values[key],
                    allowed: ["allow", "none"],
                    subjectPath: "\(section).\(key)",
                    title: "Invalid Codex network proxy Unix socket rule",
                    detailValues: "allow or none",
                    surface: surface
                ))
            }
        }

        return issues
    }

    private static func codexNetworkProxyValueIssues(
        value: Any?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        if value is Bool { return [] }
        if let table = value as? [String: Any] {
            return table.keys.sorted().flatMap { key in
                codexNetworkProxyKeyIssues(
                    key: key,
                    value: table[key],
                    subjectPath: "\(subjectPath).\(key)",
                    surface: surface
                )
            }
        }
        return [issue(
            .configUnsupportedShape,
            .warning,
            surface,
            "Invalid Codex features.network_proxy",
            "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a boolean or network proxy table.",
            "Use true, false, or a table of documented network proxy settings.",
            subjectPath: subjectPath
        )]
    }

    private static func codexNetworkProxyKeyIssues(
        key: String,
        value: Any?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        if key.hasPrefix("domains.") {
            return codexNetworkPolicyMapEntryIssues(
                value: value,
                allowed: ["allow", "deny"],
                subjectPath: subjectPath,
                title: "Invalid Codex network proxy domain rule",
                detailValues: "allow or deny",
                surface: surface
            )
        }
        if key.hasPrefix("unix_sockets.") {
            return codexNetworkPolicyMapEntryIssues(
                value: value,
                allowed: ["allow", "none"],
                subjectPath: subjectPath,
                title: "Invalid Codex network proxy Unix socket rule",
                detailValues: "allow or none",
                surface: surface
            )
        }

        if codexNetworkProxyBoolKeys.contains(key) {
            guard value is Bool else {
                return [issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex network proxy boolean",
                    "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a boolean.",
                    "Use true or false for features.network_proxy.\(key).",
                    subjectPath: subjectPath
                )]
            }
            return []
        }

        if key == "mode" {
            guard let value = value as? String,
                  ["limited", "full"].contains(value) else {
                return [issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex network proxy mode",
                    "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects limited or full.",
                    "Use mode = \"limited\" or mode = \"full\".",
                    subjectPath: subjectPath
                )]
            }
            return []
        }

        if codexNetworkProxyStringKeys.contains(key) {
            guard value is String else {
                return [issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex network proxy string",
                    "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a string.",
                    "Use a string URL for features.network_proxy.\(key).",
                    subjectPath: subjectPath
                )]
            }
            return []
        }

        if codexNetworkProxyTableKeys.contains(key) {
            guard let table = value as? [String: Any] else {
                return [issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex network proxy table",
                    "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a table.",
                    "Use a table of domain or Unix socket rules.",
                    subjectPath: subjectPath
                )]
            }
            let allowed: Set<String> = key == "domains" ? ["allow", "deny"] : ["allow", "none"]
            let detailValues = key == "domains" ? "allow or deny" : "allow or none"
            let title = key == "domains" ? "Invalid Codex network proxy domain rule" : "Invalid Codex network proxy Unix socket rule"
            return table.keys.sorted().flatMap { nestedKey in
                codexNetworkPolicyMapEntryIssues(
                    value: table[nestedKey],
                    allowed: allowed,
                    subjectPath: "\(subjectPath).\(nestedKey)",
                    title: title,
                    detailValues: detailValues,
                    surface: surface
                )
            }
        }

        let known = codexNetworkProxyBoolKeys
            .union(codexNetworkProxyStringKeys)
            .union(codexNetworkProxyTableKeys)
            .union(["mode"])
            .sorted()
        return [issue(
            .configUnsupportedShape,
            .warning,
            surface,
            "Unknown Codex network proxy key",
            "\(surface.label) sets \(subjectPath), but Codex documents only \(known.joined(separator: ", ")).",
            "Remove the unknown network proxy key or confirm it against the official Codex config reference.",
            subjectPath: subjectPath
        )]
    }

    private static func codexNetworkPolicyMapEntryIssues(
        value: Any?,
        allowed: Set<String>,
        subjectPath: String,
        title: String,
        detailValues: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        guard let value = value as? String,
              allowed.contains(value) else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                title,
                "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects \(detailValues).",
                "Use \(detailValues) for this network proxy rule.",
                subjectPath: subjectPath
            )]
        }
        return []
    }

    private static let codexFeatureBooleanKeys: Set<String> = [
        "web_search",
        "web_search_cached",
        "web_search_request",
        "unified_exec",
        "view_image_tool"
    ]

    private static func codexFeatureBooleanIssues(
        in document: SettingsTOMLDocument,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        var issues: [CompatibilityIssue] = []

        for key in codexFeatureBooleanKeys {
            let dottedKey = "features.\(key)"
            if document.topLevelKeys.contains(dottedKey),
               !(document.topLevelValues[dottedKey] is Bool) {
                issues.append(codexFeatureBooleanIssue(
                    subjectPath: dottedKey,
                    value: document.topLevelValues[dottedKey],
                    surface: surface
                ))
            }
            if document.sectionKeys["features"]?.contains(key) == true,
               !(document.sectionValues["features"]?[key] is Bool) {
                issues.append(codexFeatureBooleanIssue(
                    subjectPath: dottedKey,
                    value: document.sectionValues["features"]?[key],
                    surface: surface
                ))
            }
        }

        return issues
    }

    private static func codexFeatureBooleanIssue(
        subjectPath: String,
        value: Any?,
        surface: CompatibilityMatrixEntry
    ) -> CompatibilityIssue {
        issue(
            .configUnsupportedShape,
            .warning,
            surface,
            "Invalid Codex feature flag",
            "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a boolean.",
            "Use true or false for this feature flag.",
            subjectPath: subjectPath
        )
    }

    private static func codexPermissionNetworkSettingIssues(
        in document: SettingsTOMLDocument,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        var issues: [CompatibilityIssue] = []

        for key in document.topLevelKeys where key.hasPrefix("permissions.") {
            guard let parsed = codexPermissionNetworkKeyParts(key) else { continue }
            if parsed.setting == nil {
                issues.append(contentsOf: codexPermissionNetworkValueIssues(
                    value: document.topLevelValues[key],
                    subjectPath: key,
                    surface: surface
                ))
            } else if let setting = parsed.setting {
                issues.append(contentsOf: codexPermissionNetworkKeyIssues(
                    key: setting,
                    value: document.topLevelValues[key],
                    subjectPath: key,
                    surface: surface
                ))
            }
        }

        for (section, values) in document.sectionValues where section.hasPrefix("permissions.") {
            if document.sectionKeys[section]?.contains("network") == true {
                issues.append(contentsOf: codexPermissionNetworkValueIssues(
                    value: values["network"],
                    subjectPath: "\(section).network",
                    surface: surface
                ))
            }

            if !section.hasSuffix(".network") {
                for key in document.sectionKeys[section] ?? [] where key.hasPrefix("network.") {
                    let setting = String(key.dropFirst("network.".count))
                    issues.append(contentsOf: codexPermissionNetworkKeyIssues(
                        key: setting,
                        value: values[key],
                        subjectPath: "\(section).\(key)",
                        surface: surface
                    ))
                }
            }

            if section.hasSuffix(".network") {
                for key in document.sectionKeys[section] ?? [] {
                    issues.append(contentsOf: codexPermissionNetworkKeyIssues(
                        key: key,
                        value: values[key],
                        subjectPath: "\(section).\(key)",
                        surface: surface
                    ))
                }
            } else if section.hasSuffix(".network.domains") {
                for key in values.keys.sorted() {
                    issues.append(contentsOf: codexNetworkPolicyMapEntryIssues(
                        value: values[key],
                        allowed: ["allow", "deny"],
                        subjectPath: "\(section).\(key)",
                        title: "Invalid Codex permission network domain rule",
                        detailValues: "allow or deny",
                        surface: surface
                    ))
                }
            } else if section.hasSuffix(".network.unix_sockets") {
                for key in values.keys.sorted() {
                    issues.append(contentsOf: codexNetworkPolicyMapEntryIssues(
                        value: values[key],
                        allowed: ["allow", "none"],
                        subjectPath: "\(section).\(key)",
                        title: "Invalid Codex permission network Unix socket rule",
                        detailValues: "allow or none",
                        surface: surface
                    ))
                }
            }
        }

        return issues
    }

    private static func codexPermissionNetworkKeyParts(_ key: String) -> (name: String, setting: String?)? {
        let parts = key.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3,
              parts[0] == "permissions",
              !parts[1].isEmpty,
              parts[2] == "network" else { return nil }
        if parts.count == 3 {
            return (parts[1], nil)
        }
        let setting = parts.dropFirst(3).joined(separator: ".")
        return setting.isEmpty ? nil : (parts[1], setting)
    }

    private static func codexPermissionNetworkValueIssues(
        value: Any?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        guard let table = value as? [String: Any] else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Invalid Codex permission network",
                "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a table of named permission network settings.",
                "Use a [permissions.<name>.network] table or inline table with documented network policy keys.",
                subjectPath: subjectPath
            )]
        }
        return table.keys.sorted().flatMap { key in
            codexPermissionNetworkKeyIssues(
                key: key,
                value: table[key],
                subjectPath: "\(subjectPath).\(key)",
                surface: surface
            )
        }
    }

    private static func codexPermissionNetworkKeyIssues(
        key: String,
        value: Any?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        if key.hasPrefix("domains.") {
            return codexNetworkPolicyMapEntryIssues(
                value: value,
                allowed: ["allow", "deny"],
                subjectPath: subjectPath,
                title: "Invalid Codex permission network domain rule",
                detailValues: "allow or deny",
                surface: surface
            )
        }
        if key.hasPrefix("unix_sockets.") {
            return codexNetworkPolicyMapEntryIssues(
                value: value,
                allowed: ["allow", "none"],
                subjectPath: subjectPath,
                title: "Invalid Codex permission network Unix socket rule",
                detailValues: "allow or none",
                surface: surface
            )
        }

        if codexNetworkProxyBoolKeys.contains(key) {
            guard value is Bool else {
                return [issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex permission network boolean",
                    "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a boolean.",
                    "Use true or false for permissions.<name>.network.\(key).",
                    subjectPath: subjectPath
                )]
            }
            return []
        }

        if key == "mode" {
            guard let value = value as? String,
                  ["limited", "full"].contains(value) else {
                return [issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex permission network mode",
                    "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects limited or full.",
                    "Use mode = \"limited\" or mode = \"full\".",
                    subjectPath: subjectPath
                )]
            }
            return []
        }

        if codexNetworkProxyStringKeys.contains(key) {
            guard value is String else {
                return [issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex permission network string",
                    "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a string.",
                    "Use a string URL for permissions.<name>.network.\(key).",
                    subjectPath: subjectPath
                )]
            }
            return []
        }

        if codexNetworkProxyTableKeys.contains(key) {
            guard let table = value as? [String: Any] else {
                return [issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex permission network table",
                    "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a table.",
                    "Use a table of domain or Unix socket rules.",
                    subjectPath: subjectPath
                )]
            }
            let allowed: Set<String> = key == "domains" ? ["allow", "deny"] : ["allow", "none"]
            let detailValues = key == "domains" ? "allow or deny" : "allow or none"
            let title = key == "domains" ? "Invalid Codex permission network domain rule" : "Invalid Codex permission network Unix socket rule"
            return table.keys.sorted().flatMap { nestedKey in
                codexNetworkPolicyMapEntryIssues(
                    value: table[nestedKey],
                    allowed: allowed,
                    subjectPath: "\(subjectPath).\(nestedKey)",
                    title: title,
                    detailValues: detailValues,
                    surface: surface
                )
            }
        }

        let known = codexNetworkProxyBoolKeys
            .union(codexNetworkProxyStringKeys)
            .union(codexNetworkProxyTableKeys)
            .union(["mode"])
            .sorted()
        return [issue(
            .configUnsupportedShape,
            .warning,
            surface,
            "Unknown Codex permission network key",
            "\(surface.label) sets \(subjectPath), but Codex documents only \(known.joined(separator: ", ")).",
            "Remove the unknown permission network key or confirm it against the official Codex config reference.",
            subjectPath: subjectPath
        )]
    }

    private static func codexWorkspaceRootsSettingIssues(
        in document: SettingsTOMLDocument,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        var issues: [CompatibilityIssue] = []

        for key in document.topLevelKeys where key.hasPrefix("permissions.") {
            guard let parsed = codexWorkspaceRootsKeyParts(key) else { continue }
            if parsed.setting == nil {
                issues.append(contentsOf: codexWorkspaceRootsValueIssues(
                    value: document.topLevelValues[key],
                    subjectPath: key,
                    surface: surface
                ))
            } else if let setting = parsed.setting {
                issues.append(contentsOf: codexWorkspaceRootsKeyIssues(
                    key: setting,
                    value: document.topLevelValues[key],
                    subjectPath: key,
                    surface: surface
                ))
            }
        }

        for (section, values) in document.sectionValues where section.hasPrefix("permissions.") {
            if document.sectionKeys[section]?.contains("workspace_roots") == true {
                issues.append(contentsOf: codexWorkspaceRootsValueIssues(
                    value: values["workspace_roots"],
                    subjectPath: "\(section).workspace_roots",
                    surface: surface
                ))
            }

            if !section.hasSuffix(".workspace_roots") {
                for key in document.sectionKeys[section] ?? [] where key.hasPrefix("workspace_roots.") {
                    let setting = String(key.dropFirst("workspace_roots.".count))
                    issues.append(contentsOf: codexWorkspaceRootsKeyIssues(
                        key: setting,
                        value: values[key],
                        subjectPath: "\(section).\(key)",
                        surface: surface
                    ))
                }
            }

            if section.hasSuffix(".workspace_roots") {
                for key in document.sectionKeys[section] ?? [] {
                    issues.append(contentsOf: codexWorkspaceRootsKeyIssues(
                        key: key,
                        value: values[key],
                        subjectPath: "\(section).\(key)",
                        surface: surface
                    ))
                }
            }
        }

        return issues
    }

    private static func codexWorkspaceRootsKeyParts(_ key: String) -> (name: String, setting: String?)? {
        let parts = key.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3,
              parts[0] == "permissions",
              !parts[1].isEmpty,
              parts[2] == "workspace_roots" else { return nil }
        if parts.count == 3 {
            return (parts[1], nil)
        }
        let setting = parts.dropFirst(3).joined(separator: ".")
        return setting.isEmpty ? nil : (parts[1], setting)
    }

    private static func codexWorkspaceRootsValueIssues(
        value: Any?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        guard let table = value as? [String: Any] else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Invalid Codex workspace roots",
                "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a table of workspace-root paths.",
                "Use a [permissions.<name>.workspace_roots] table or inline table with boolean path entries.",
                subjectPath: subjectPath
            )]
        }
        return table.keys.sorted().flatMap { key in
            codexWorkspaceRootsKeyIssues(
                key: key,
                value: table[key],
                subjectPath: "\(subjectPath).\(key)",
                surface: surface
            )
        }
    }

    private static func codexWorkspaceRootsKeyIssues(
        key: String,
        value: Any?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        guard value is Bool else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Invalid Codex workspace root entry",
                "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a boolean.",
                "Use true or false for permissions.<name>.workspace_roots.\(key).",
                subjectPath: subjectPath
            )]
        }
        return []
    }

    private static let codexFilesystemPermissionValues: Set<String> = [
        "read",
        "write",
        "deny"
    ]

    private static func codexRequirementsFilesystemPermissionIssues(
        in document: SettingsTOMLDocument,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        var issues: [CompatibilityIssue] = []

        if document.topLevelKeys.contains("permissions.filesystem") {
            issues.append(contentsOf: codexFilesystemPermissionValueIssues(
                value: document.topLevelValues["permissions.filesystem"],
                rawValue: document.topLevelRawValues["permissions.filesystem"],
                subjectPath: "permissions.filesystem",
                surface: surface
            ))
        }

        for key in document.topLevelKeys where key.hasPrefix("permissions.filesystem.") {
            let setting = String(key.dropFirst("permissions.filesystem.".count))
            issues.append(contentsOf: codexFilesystemPermissionKeyIssues(
                key: setting,
                value: document.topLevelValues[key],
                rawValue: document.topLevelRawValues[key],
                subjectPath: key,
                surface: surface
            ))
        }

        if document.sectionKeys["permissions"]?.contains("filesystem") == true {
            issues.append(contentsOf: codexFilesystemPermissionValueIssues(
                value: document.sectionValues["permissions"]?["filesystem"],
                rawValue: document.sectionRawValues["permissions"]?["filesystem"],
                subjectPath: "permissions.filesystem",
                surface: surface
            ))
        }

        if let keys = document.sectionKeys["permissions.filesystem"] {
            for key in keys {
                issues.append(contentsOf: codexFilesystemPermissionKeyIssues(
                    key: key,
                    value: document.sectionValues["permissions.filesystem"]?[key],
                    rawValue: document.sectionRawValues["permissions.filesystem"]?[key],
                    subjectPath: "permissions.filesystem.\(key)",
                    surface: surface
                ))
            }
        }

        return issues
    }

    private static func codexNamedFilesystemPermissionSettingIssues(
        in document: SettingsTOMLDocument,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        var issues: [CompatibilityIssue] = []

        for key in document.topLevelKeys where key.hasPrefix("permissions.") {
            guard let parsed = codexNamedFilesystemPermissionKeyParts(key) else { continue }
            if parsed.setting == nil {
                issues.append(contentsOf: codexNamedFilesystemPermissionValueIssues(
                    value: document.topLevelValues[key],
                    subjectPath: key,
                    surface: surface
                ))
            } else if let setting = parsed.setting {
                issues.append(contentsOf: codexNamedFilesystemPermissionKeyIssues(
                    key: setting,
                    value: document.topLevelValues[key],
                    subjectPath: key,
                    surface: surface
                ))
            }
        }

        for (section, values) in document.sectionValues where section.hasPrefix("permissions.") {
            if document.sectionKeys[section]?.contains("filesystem") == true {
                issues.append(contentsOf: codexNamedFilesystemPermissionValueIssues(
                    value: values["filesystem"],
                    subjectPath: "\(section).filesystem",
                    surface: surface
                ))
            }

            if section.hasSuffix(".filesystem") {
                for key in document.sectionKeys[section] ?? [] {
                    issues.append(contentsOf: codexNamedFilesystemPermissionKeyIssues(
                        key: key,
                        value: values[key],
                        subjectPath: "\(section).\(key)",
                        surface: surface
                    ))
                }
            } else if section.hasSuffix(".filesystem.\":workspace_roots\"")
                        || section.hasSuffix(".filesystem.':workspace_roots'")
                        || section.hasSuffix(".filesystem.:workspace_roots") {
                for key in values.keys.sorted() {
                    issues.append(contentsOf: codexNamedFilesystemPermissionRuleIssues(
                        value: values[key],
                        subjectPath: "\(section).\(key)",
                        surface: surface
                    ))
                }
            }
        }

        return issues
    }

    private static func codexNamedFilesystemPermissionKeyParts(_ key: String) -> (name: String, setting: String?)? {
        let parts = key.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3,
              parts[0] == "permissions",
              !parts[1].isEmpty,
              parts[2] == "filesystem" else { return nil }
        if parts.count == 3 {
            return (parts[1], nil)
        }
        let setting = parts.dropFirst(3).joined(separator: ".")
        return setting.isEmpty ? nil : (parts[1], setting)
    }

    private static func codexNamedFilesystemPermissionValueIssues(
        value: Any?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        guard let table = value as? [String: Any] else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Invalid Codex named filesystem permissions",
                "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a table of named filesystem permission rules.",
                "Use a [permissions.<name>.filesystem] table or inline table with path rules and glob_scan_max_depth.",
                subjectPath: subjectPath
            )]
        }
        return table.keys.sorted().flatMap { key in
            codexNamedFilesystemPermissionKeyIssues(
                key: key,
                value: table[key],
                subjectPath: "\(subjectPath).\(key)",
                surface: surface
            )
        }
    }

    private static func codexNamedFilesystemPermissionKeyIssues(
        key: String,
        value: Any?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        if key == "glob_scan_max_depth" {
            guard let depth = value as? Int,
                  depth >= 1 else {
                return [issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex filesystem glob depth",
                    "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a positive integer.",
                    "Use an integer of at least 1 for glob_scan_max_depth or remove the malformed setting.",
                    subjectPath: subjectPath
                )]
            }
            return []
        }

        let workspaceRootsKeys = [
            "\":workspace_roots\"",
            "':workspace_roots'",
            ":workspace_roots"
        ]
        if workspaceRootsKeys.contains(key) {
            guard let table = value as? [String: Any] else {
                return [issue(
                    .configUnsupportedShape,
                    .warning,
                    surface,
                    "Invalid Codex workspace-root filesystem permissions",
                    "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a table of workspace-root filesystem rules.",
                    "Use a nested :workspace_roots table with read, write, or deny values.",
                    subjectPath: subjectPath
                )]
            }
            return table.keys.sorted().flatMap { nestedKey in
                codexNamedFilesystemPermissionRuleIssues(
                    value: table[nestedKey],
                    subjectPath: "\(subjectPath).\(nestedKey)",
                    surface: surface
                )
            }
        }

        if key.hasPrefix("\":workspace_roots\".")
            || key.hasPrefix("':workspace_roots'.")
            || key.hasPrefix(":workspace_roots.") {
            return codexNamedFilesystemPermissionRuleIssues(
                value: value,
                subjectPath: subjectPath,
                surface: surface
            )
        }

        return codexNamedFilesystemPermissionRuleIssues(
            value: value,
            subjectPath: subjectPath,
            surface: surface
        )
    }

    private static func codexNamedFilesystemPermissionRuleIssues(
        value: Any?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        guard let value = value as? String,
              codexFilesystemPermissionValues.contains(value) else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Invalid Codex filesystem permission rule",
                "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects read, write, or deny.",
                "Use read, write, or deny for named filesystem permission rules.",
                subjectPath: subjectPath
            )]
        }
        return []
    }

    private static func codexFilesystemPermissionValueIssues(
        value: Any?,
        rawValue: String?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        guard let table = value as? [String: Any] else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Invalid Codex filesystem permissions",
                "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a table with deny_read.",
                "Use permissions.filesystem.deny_read = [\"/path/or/glob\"] or a [permissions.filesystem] table.",
                subjectPath: subjectPath
            )]
        }

        return table.keys.sorted().flatMap { key in
            codexFilesystemPermissionKeyIssues(
                key: key,
                value: table[key],
                rawValue: nil,
                subjectPath: "\(subjectPath).\(key)",
                surface: surface
            )
        }
    }

    private static func codexFilesystemPermissionKeyIssues(
        key: String,
        value: Any?,
        rawValue: String?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        guard key == "deny_read" else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Unknown Codex filesystem permission key",
                "\(surface.label) sets \(subjectPath), but Codex documents only permissions.filesystem.deny_read.",
                "Remove the unknown filesystem permission key or confirm it against the official Codex config reference.",
                subjectPath: subjectPath
            )]
        }

        if let rawValue, parseTOMLStringArrayLiteral(rawValue) != nil {
            return []
        }
        if rawValue == nil,
           let values = value as? [Any],
           values.allSatisfy({ $0 is String }) {
            return []
        }
        if rawValue == nil,
           value is [String] {
            return []
        }

        return [issue(
            .configUnsupportedShape,
            .warning,
            surface,
            "Invalid Codex filesystem deny_read",
            "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects an array of string paths or globs.",
            "Use deny_read = [\"/absolute/path\", \"**/secret.env\"] or remove the malformed setting.",
            subjectPath: subjectPath
        )]
    }

    private static func codexMCPServerIdentitySettingIssues(
        in document: SettingsTOMLDocument,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        var issues: [CompatibilityIssue] = []
        var dottedIdentityValues: [String: [String: Any?]] = [:]

        for key in document.topLevelKeys where key.hasPrefix("mcp_servers.") {
            guard let parsed = codexMCPServerIdentityKeyParts(key) else { continue }
            if let setting = parsed.setting {
                dottedIdentityValues[parsed.baseSubjectPath, default: [:]][setting] = document.topLevelValues[key]
                issues.append(contentsOf: codexMCPServerIdentityKeyIssues(
                    key: setting,
                    value: document.topLevelValues[key],
                    subjectPath: key,
                    surface: surface
                ))
            } else {
                issues.append(contentsOf: codexMCPServerIdentityValueIssues(
                    value: document.topLevelValues[key],
                    subjectPath: key,
                    surface: surface
                ))
            }
        }

        for baseSubjectPath in dottedIdentityValues.keys.sorted() {
            issues.append(contentsOf: codexMCPServerIdentityExclusivityIssues(
                values: dottedIdentityValues[baseSubjectPath] ?? [:],
                subjectPath: baseSubjectPath,
                surface: surface
            ))
        }

        for (section, values) in document.sectionValues where section.hasPrefix("mcp_servers.") {
            if document.sectionKeys[section]?.contains("identity") == true {
                issues.append(contentsOf: codexMCPServerIdentityValueIssues(
                    value: values["identity"],
                    subjectPath: "\(section).identity",
                    surface: surface
                ))
            }

            if section.hasSuffix(".identity") {
                var tableValues: [String: Any?] = [:]
                for key in document.sectionKeys[section] ?? [] {
                    tableValues[key] = values[key]
                    issues.append(contentsOf: codexMCPServerIdentityKeyIssues(
                        key: key,
                        value: values[key],
                        subjectPath: "\(section).\(key)",
                        surface: surface
                    ))
                }
                issues.append(contentsOf: codexMCPServerIdentityExclusivityIssues(
                    values: tableValues,
                    subjectPath: section,
                    surface: surface
                ))
            }
        }

        return issues
    }

    private static func codexMCPServerIdentityKeyParts(_ key: String) -> (baseSubjectPath: String, setting: String?)? {
        let parts = key.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3,
              parts[0] == "mcp_servers",
              !parts[1].isEmpty,
              parts[2] == "identity" else { return nil }
        let base = parts.prefix(3).joined(separator: ".")
        if parts.count == 3 { return (base, nil) }
        let setting = parts.dropFirst(3).joined(separator: ".")
        return setting.isEmpty ? nil : (base, setting)
    }

    private static func codexMCPServerIdentityValueIssues(
        value: Any?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        guard let table = value as? [String: Any] else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Invalid Codex MCP identity",
                "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects an identity table.",
                "Use an identity table with exactly one of command or url.",
                subjectPath: subjectPath
            )]
        }

        var values: [String: Any?] = [:]
        var issues = table.keys.sorted().flatMap { key -> [CompatibilityIssue] in
            values[key] = table[key]
            return codexMCPServerIdentityKeyIssues(
                key: key,
                value: table[key],
                subjectPath: "\(subjectPath).\(key)",
                surface: surface
            )
        }
        issues.append(contentsOf: codexMCPServerIdentityExclusivityIssues(
            values: values,
            subjectPath: subjectPath,
            surface: surface
        ))
        return issues
    }

    private static func codexMCPServerIdentityKeyIssues(
        key: String,
        value: Any?,
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        guard key == "command" || key == "url" else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Unknown Codex MCP identity key",
                "\(surface.label) sets \(subjectPath), but Codex documents only command and url identity keys.",
                "Remove the unknown MCP identity key or confirm it against the official Codex config reference.",
                subjectPath: subjectPath
            )]
        }

        guard value is String else {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Invalid Codex MCP identity value",
                "\(surface.label) sets \(subjectPath) as \(tomlValueDescription(value)), but Codex expects a string.",
                "Use command = \"...\" for stdio MCP servers or url = \"https://...\" for streamable HTTP MCP servers.",
                subjectPath: subjectPath
            )]
        }
        return []
    }

    private static func codexMCPServerIdentityExclusivityIssues(
        values: [String: Any?],
        subjectPath: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        let hasCommand = values.keys.contains("command")
        let hasURL = values.keys.contains("url")
        if hasCommand && hasURL {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Conflicting Codex MCP identity",
                "\(surface.label) sets both \(subjectPath).command and \(subjectPath).url, but Codex documents exactly one identity type per MCP server.",
                "Keep command for stdio MCP servers or url for streamable HTTP MCP servers, not both.",
                subjectPath: subjectPath
            )]
        }
        if !hasCommand && !hasURL {
            return [issue(
                .configUnsupportedShape,
                .warning,
                surface,
                "Incomplete Codex MCP identity",
                "\(surface.label) sets \(subjectPath), but Codex requires either command or url for an MCP identity rule.",
                "Add command for stdio MCP servers or url for streamable HTTP MCP servers.",
                subjectPath: subjectPath
            )]
        }
        return []
    }

    private static func codexRequirementKeys(in document: SettingsTOMLDocument) -> [String] {
        let topLevel = document.topLevelKeys.filter {
            $0.hasPrefix("allowed_") || $0 == "enforce_residency"
        }
        var keys = Set(topLevel)
        if document.sectionKeys.keys.contains("features") { keys.insert("features") }
        if document.sectionKeys.keys.contains("rules") { keys.insert("rules") }
        if document.sectionKeys.keys.contains("hooks") { keys.insert("hooks") }
        if document.sectionKeys.keys.contains("experimental_network") { keys.insert("experimental_network") }
        if document.arrayTables.contains("remote_sandbox_config") { keys.insert("remote_sandbox_config") }
        if document.arrayTables.contains("mcp_servers") { keys.insert("mcp_servers") }
        return keys.sorted()
    }

    private static func stringSetting(_ key: String, in document: SettingsTOMLDocument) -> String? {
        document.topLevelValues[key] as? String
    }

    private static func jsonSettingsSummary(keys: [String], surface: CompatibilityMatrixEntry) -> String {
        if surface.toolID == .claudeCode {
            var parts: [String] = []
            if keys.contains("permissions") { parts.append("permissions") }
            if keys.contains("env") { parts.append("env") }
            if keys.contains("enableAllProjectMcpServers")
                || keys.contains("enabledMcpjsonServers")
                || keys.contains("disabledMcpjsonServers") {
                parts.append("project MCP approvals")
            }
            if keys.contains("apiKeyHelper") || keys.contains("forceLoginMethod") {
                parts.append("auth policy")
            }
            if keys.contains("forceRemoteSettingsRefresh") {
                parts.append("remote settings fail-closed")
            }
            if keys.contains("skillOverrides") {
                parts.append("skill overrides")
            }
            if keys.contains("disableSkillShellExecution") {
                parts.append("skill shell policy")
            }
            return parts.isEmpty ? "\(keys.count) settings key\(keys.count == 1 ? "" : "s")" : parts.joined(separator: ", ")
        }
        if surface.id == "claude-desktop-project-launch" {
            var parts: [String] = []
            if keys.contains("configurations") { parts.append("preview configurations") }
            if keys.contains("autoVerify") { parts.append("auto verify") }
            if keys.contains("version") { parts.append("versioned launch file") }
            return parts.isEmpty ? "\(keys.count) launch key\(keys.count == 1 ? "" : "s")" : parts.joined(separator: ", ")
        }
        return "\(keys.count) settings key\(keys.count == 1 ? "" : "s")"
    }

    private static func claudeLocalProjectStateSummary(_ state: [String: Any]) -> String {
        var parts: [String] = []
        if state["hasTrustDialogAccepted"] != nil {
            parts.append("trust prompt state")
        }
        if state["hasClaudeMdExternalIncludesApproved"] != nil
            || state["hasClaudeMdExternalIncludesWarningShown"] != nil {
            parts.append("external import prompt state")
        }
        if state["enabledMcpjsonServers"] != nil || state["disabledMcpjsonServers"] != nil {
            parts.append("project MCP approval choices")
        }
        if state["mcpContextUris"] != nil {
            parts.append("MCP context URIs")
        }
        if state["additionalDirectories"] != nil
            || (state["permissions"] as? [String: Any])?["additionalDirectories"] != nil {
            parts.append("runtime additional directories")
        }
        if state["ignorePatterns"] != nil {
            parts.append("deprecated ignore patterns")
        }
        if boolSetting("dontCrawlDirectory", in: state) == true {
            parts.append("directory crawl disabled")
        }
        if !claudeLocalProjectPolicyEvidenceKeys(in: state).isEmpty {
            parts.append("policy-shaped private state")
        }
        if state["lastSessionId"] != nil || state["lastSessionModified"] != nil {
            parts.append("session metrics")
        }
        return parts.isEmpty ? "\(state.keys.count) runtime key\(state.keys.count == 1 ? "" : "s")" : parts.joined(separator: ", ")
    }

    private static func plistSettingsSummary(_ root: [String: Any], surface: CompatibilityMatrixEntry) -> String {
        if surface.toolID == .claudeCode {
            return jsonSettingsSummary(keys: root.keys.sorted(), surface: surface)
        }

        if surface.toolID == .codexDesktop {
            var parts: [String] = []
            if root.keys.contains("SUAutomaticallyUpdate") || root.keys.contains("SUEnableAutomaticChecks") {
                parts.append("update preferences")
            }
            if root.keys.contains("AppleTextDirection") || root.keys.contains("NSForceRightToLeftWritingDirection") {
                parts.append("macOS UI preferences")
            }
            if root.keys.contains("NSOSLastRootDirectory") || root.keys.contains("NSOSPLastRootDirectory") {
                parts.append("open-panel state")
            }
            return parts.isEmpty ? "\(root.keys.count) app preference key\(root.keys.count == 1 ? "" : "s")" : parts.joined(separator: ", ")
        }

        var parts: [String] = []
        let disabledKeys: [(String, String)] = [
            ("isLocalDevMcpEnabled", "local MCP off"),
            ("isDesktopExtensionEnabled", "extensions off"),
            ("isDesktopExtensionDirectoryEnabled", "directory off"),
            ("isDxtDirectoryEnabled", "legacy directory off"),
            ("isClaudeCodeForDesktopEnabled", "Desktop Code off"),
            ("secureVmFeaturesEnabled", "VM features off")
        ]
        for (key, label) in disabledKeys where boolSetting(key, in: root) == false {
            parts.append(label)
        }
        if boolSetting("isDesktopExtensionSignatureRequired", in: root) == true {
            parts.append("signatures required")
        }
        if hasManagedMCPServers(in: root) {
            parts.append("managed MCP servers")
        }
        if parts.isEmpty {
            return "\(root.keys.count) preference key\(root.keys.count == 1 ? "" : "s")"
        }
        return parts.joined(separator: ", ")
    }

    private static func boolSetting(_ key: String, in root: [String: Any]) -> Bool? {
        boolSettingValue(root[key])
    }

    private static func boolSettingValue(_ value: Any?) -> Bool? {
        guard let value else { return nil }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        return nil
    }

    private static func readJSONDictionary(at path: String) -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: path),
              let raw = try? String(contentsOfFile: path, encoding: .utf8),
              let data = ConfigWriter.stripJsonComments(raw).data(using: .utf8) else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func fileExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    private static func directoryExists(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    private static func hasManagedMCPServers(in root: [String: Any]) -> Bool {
        if let array = root["managedMcpServers"] as? [Any] {
            return !array.isEmpty
        }
        if let dict = root["managedMcpServers"] as? [String: Any] {
            return !dict.isEmpty
        }
        if let string = root["managedMcpServers"] as? String {
            return !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }

    private static func directorySettingsSummary(_ entries: [String], surface: CompatibilityMatrixEntry) -> String {
        if surface.id == "codex-desktop-application-support" {
            var parts: [String] = []
            if entries.contains("Preferences") { parts.append("Chromium preferences") }
            if entries.contains("Session Storage") { parts.append("session storage") }
            if entries.contains("browser-sidebar-local-servers.json") { parts.append("browser sidebar servers") }
            if entries.contains("Partitions") { parts.append("browser partitions") }
            if entries.contains("Cache") || entries.contains("GPUCache") { parts.append("caches") }
            return parts.isEmpty ? "\(entries.count) app-state item\(entries.count == 1 ? "" : "s")" : parts.joined(separator: ", ")
        }
        return "\(entries.count) visible director\(entries.count == 1 ? "y/file" : "ies/files")"
    }

    private static func tomlSettingsSummary(
        _ document: SettingsTOMLDocument,
        surface: CompatibilityMatrixEntry,
        projectRoot: String?
    ) -> String {
        var parts: [String] = []
        let top = document.topLevelKeys.intersection(codexProjectSettingKeys).sorted()
        if !top.isEmpty { parts.append(top.joined(separator: ", ")) }
        let profileCount = document.sectionKeys.keys.filter { $0.hasPrefix("profiles.") }.count
        if profileCount > 0 { parts.append("\(profileCount) profile\(profileCount == 1 ? "" : "s")") }
        let projectCount = document.sectionKeys.keys.filter { codexProjectPath(fromSection: $0) != nil }.count
        if projectCount > 0 { parts.append("\(projectCount) project override\(projectCount == 1 ? "" : "s")") }
        let pluginPolicyCount = Set(document.sectionKeys.keys.compactMap { section -> String? in
            guard let policy = codexPluginMCPPolicySection(section),
                  policy.relativeSegments.count >= 4 else {
                return nil
            }
            let segments = policy.relativeSegments
            let profilePrefix = policy.profileName.map { "profiles.\($0)." } ?? ""
            return "\(profilePrefix)\(segments[1]).\(segments[3])"
        }).count
        if pluginPolicyCount > 0 {
            parts.append("\(pluginPolicyCount) plugin MCP polic\(pluginPolicyCount == 1 ? "y" : "ies")")
        }
        if document.arrayTables.contains("skills.config") { parts.append("skill overrides") }
        if let projectRoot,
           let section = codexProjectSection(in: document, projectRoot: projectRoot),
           !section.value.isEmpty {
            parts.append("current project: \(section.value.sorted().joined(separator: ", "))")
        }
        return parts.isEmpty ? "\(surface.format.rawValue.uppercased()) config present" : parts.joined(separator: ", ")
    }

    private enum ClaudeCodeAuthStatusProbe {
        case authenticated
        case signedOut(String)
        case unavailable
    }

    private struct ClaudeCodeAuthEnvironmentEvidence {
        enum State: Equatable {
            case present
            case missingValue
        }

        let state: State
        let title: String
        let detail: String
        let fixHint: String
        let source: String
    }

    private struct CodexAuthEnvironmentEvidence {
        enum State: Equatable {
            case present
            case missingValue
        }

        let state: State
        let title: String
        let detail: String
        let fixHint: String
        let source: String
    }

    private static func readAuth(from surface: CompatibilityMatrixEntry) -> [CompatibilityIssue] {
        if surface.toolID == .claudeCode {
            return readClaudeCodeAuth(from: surface)
        }
        guard let path = surface.path else {
            return [issue(.serverAuthRuntimeManaged, .info, surface, "Runtime-managed authentication", "\(surface.label) is managed by the app/runtime.", "Use the owning app or account login flow; Project Hub will not read or write runtime secrets.")]
        }
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else {
            let stores = codexCredentialStores(forAuthPath: path)
            if let environmentEvidence = codexAuthEnvironmentEvidence(),
               environmentEvidence.state == .missingValue {
                return [issue(
                    .serverAuthMissing,
                    .warning,
                    surface,
                    environmentEvidence.title,
                    environmentEvidence.detail,
                    environmentEvidence.fixHint,
                    metadata: ["source": environmentEvidence.source]
                )]
            }
            if let stores = codexCredentialStores(forAuthPath: path) {
                switch stores.cli {
                case "keyring":
                    return [issue(.authCredentialStore, .info, surface, "Codex auth may be in keychain", "No auth.json exists at \(tilde(path)), but cli_auth_credentials_store is set to keyring.", "Verify by asking Codex to show login status; Project Hub should not read OS keychain secrets.")]
                case "auto":
                    return [issue(.authCredentialStore, .info, surface, "Codex auth may be in credential store", "No auth.json exists at \(tilde(path)), but cli_auth_credentials_store is auto, so Codex may use the OS credential store.", "Verify through Codex's official login/status flow before prompting the user to sign in again.")]
                default:
                    break
                }
            }
            if let environmentEvidence = codexAuthEnvironmentEvidence() {
                switch environmentEvidence.state {
                case .present:
                    return [issue(
                        .authCredentialStore,
                        .info,
                        surface,
                        environmentEvidence.title,
                        environmentEvidence.detail,
                        environmentEvidence.fixHint,
                        metadata: ["source": environmentEvidence.source]
                    )]
                case .missingValue:
                    return [issue(
                        .serverAuthMissing,
                        .warning,
                        surface,
                        environmentEvidence.title,
                        environmentEvidence.detail,
                        environmentEvidence.fixHint,
                        metadata: ["source": environmentEvidence.source]
                    )]
                }
            }
            var missingIssues: [CompatibilityIssue] = []
            if let stores {
                switch stores.mcpOAuth {
                case "keyring":
                    missingIssues.append(issue(.authCredentialStore, .info, surface, "Codex MCP OAuth may be in keychain", "No auth.json exists at \(tilde(path)), but mcp_oauth_credentials_store is set to keyring for browser-login MCP credentials. This does not prove main Codex login.", "Verify MCP login with Codex's official MCP OAuth flow; Project Hub should not read OS keychain secrets."))
                case "auto":
                    missingIssues.append(issue(.authCredentialStore, .info, surface, "Codex MCP OAuth may be in credential store", "No auth.json exists at \(tilde(path)), but mcp_oauth_credentials_store is auto, so Codex may use the OS credential store for browser-login MCP credentials. This does not prove main Codex login.", "Verify MCP login with Codex's official MCP OAuth flow before prompting the user to sign in again."))
                default:
                    break
                }
            }
            missingIssues.append(issue(.serverAuthMissing, .warning, surface, "Authentication not found", "No auth file exists at \(tilde(path)).", "Sign in with the target tool's official login flow, then scan again."))
            return missingIssues
        }
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8),
              let data = ConfigWriter.stripJsonComments(raw).data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else {
            return [issue(.configInvalidJSON, .error, surface, "Invalid auth JSON", "Project Hub could not parse this auth file.", "Use the target tool's logout/login flow to refresh credentials.")]
        }
        if let credentialPath = placeholderCredentialPath(in: root) {
            return [issue(
                .serverAuthMissing,
                .warning,
                surface,
                "Authentication credential is empty",
                "This auth file exists, but \(credentialPath) is empty or still a placeholder. Project Hub did not display the credential value.",
                "Refresh authentication with the target tool's official login flow."
            )]
        }
        if containsExpiredTimestamp(root) {
            return [issue(.serverAuthExpired, .warning, surface, "Authentication may be expired", "This auth file contains an expiration timestamp in the past.", "Refresh authentication with the target tool's login command.")]
        }
        if credentialEvidencePath(in: root) == nil {
            return [issue(
                .serverAuthMissing,
                .warning,
                surface,
                "Authentication credential not found",
                "This auth file exists, but Project Hub found no recognizable token/API-key credential fields. Project Hub did not display any credential values.",
                "Refresh authentication with the target tool's official login flow."
            )]
        }
        return []
    }

    private static func claudeCodeAuthStatus() -> ClaudeCodeAuthStatusProbe {
        let env = ProcessInfo.processInfo.environment
        if runningUnderXCTest && env["PROJECTHUB_CLAUDE_COMMAND_PATH"] == nil {
            return .unavailable
        }
        guard let commandPath = claudeCodeCommandPath() else { return .unavailable }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: commandPath)
        process.arguments = ["auth", "status"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        let group = DispatchGroup()
        group.enter()
        process.terminationHandler = { _ in group.leave() }

        do {
            try process.run()
            if group.wait(timeout: .now() + 5) == .timedOut {
                process.terminate()
                return .unavailable
            }
        } catch {
            return .unavailable
        }

        switch process.terminationStatus {
        case 0:
            return .authenticated
        case 1:
            return .signedOut("Claude CLI reported that Claude Code is not authenticated. Project Hub did not read or display any credential values.")
        default:
            return .unavailable
        }
    }

    private static var runningUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    private static func claudeCodeCommandPath() -> String? {
        let env = ProcessInfo.processInfo.environment
        if let configured = env["PROJECTHUB_CLAUDE_COMMAND_PATH"] {
            let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if trimmed.contains("/") {
                let expanded = (trimmed as NSString).expandingTildeInPath
                return FileManager.default.isExecutableFile(atPath: expanded) ? expanded : nil
            }
            return executablePath(named: trimmed)
        }
        return executablePath(named: "claude")
    }

    private static func executablePath(named command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let path, !path.isEmpty else { return nil }
            return path
        } catch {
            return nil
        }
    }

    private static func readClaudeCodeAuth(from surface: CompatibilityMatrixEntry) -> [CompatibilityIssue] {
        switch claudeCodeAuthStatus() {
        case .authenticated:
            return []
        case .signedOut(let detail):
            return [issue(
                .serverAuthMissing,
                .warning,
                surface,
                "Claude Code login required",
                detail,
                "Run `claude auth login`, then scan again."
            )]
        case .unavailable:
            break
        }

        if let environmentEvidence = claudeCodeAuthEnvironmentEvidence(includeLongLivedOAuth: false) {
            switch environmentEvidence.state {
            case .present:
                return [issue(
                    .authCredentialStore,
                    .info,
                    surface,
                    environmentEvidence.title,
                    environmentEvidence.detail,
                    environmentEvidence.fixHint,
                    metadata: ["source": environmentEvidence.source]
                )]
            case .missingValue:
                return [issue(
                    .serverAuthMissing,
                    .warning,
                    surface,
                    environmentEvidence.title,
                    environmentEvidence.detail,
                    environmentEvidence.fixHint,
                    metadata: ["source": environmentEvidence.source]
                )]
            }
        }

        if let helperPath = claudeCodeAPIKeyHelperPath() {
            return [issue(
                .authCredentialStore,
                .info,
                surface,
                "Claude Code API key helper configured",
                "Claude CLI auth status was not available, but apiKeyHelper is configured in \(tilde(helperPath)). Project Hub did not execute the helper or read its output.",
                "Verify Claude Code auth with `claude auth status`; Project Hub treats helper output as runtime-managed."
            )]
        }

        if let environmentEvidence = claudeCodeAuthEnvironmentEvidence(includeLongLivedOAuth: true) {
            switch environmentEvidence.state {
            case .present:
                return [issue(
                    .authCredentialStore,
                    .info,
                    surface,
                    environmentEvidence.title,
                    environmentEvidence.detail,
                    environmentEvidence.fixHint,
                    metadata: ["source": environmentEvidence.source]
                )]
            case .missingValue:
                return [issue(
                    .serverAuthMissing,
                    .warning,
                    surface,
                    environmentEvidence.title,
                    environmentEvidence.detail,
                    environmentEvidence.fixHint,
                    metadata: ["source": environmentEvidence.source]
                )]
            }
        }

        guard let path = surface.path else {
            return [issue(.serverAuthRuntimeManaged, .info, surface, "Runtime-managed authentication", "\(surface.label) is managed by Claude Code, the OS credential store, and the Claude account login flow.", "Use `claude auth status` or `claude auth login`; Project Hub will not read or write runtime secrets.")]
        }

        guard FileManager.default.fileExists(atPath: path) else {
            return [issue(
                .serverHealthUnknown,
                .info,
                surface,
                "Claude Code auth status unavailable",
                "Project Hub could not run `claude auth status`, and no legacy auth-shaped evidence exists at \(tilde(path)). Claude Code may still be authenticated through the OS credential store.",
                "Run `claude auth status` or sign in with `claude auth login`, then scan again."
            )]
        }

        guard let raw = try? String(contentsOfFile: path, encoding: .utf8),
              let data = ConfigWriter.stripJsonComments(raw).data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else {
            return [issue(.configInvalidJSON, .error, surface, "Invalid Claude Code state JSON", "Project Hub could not parse this Claude Code state file while looking for legacy auth evidence.", "Use Claude Code's official logout/login flow if authentication is broken.")]
        }
        return readClaudeCodeAuthEvidence(root: root, path: path, surface: surface)
    }

    private static func claudeCodeAuthEnvironmentEvidence(includeLongLivedOAuth: Bool) -> ClaudeCodeAuthEnvironmentEvidence? {
        let env = ProcessInfo.processInfo.environment
        for flag in [
            "CLAUDE_CODE_USE_ANTHROPIC_AWS",
            "CLAUDE_CODE_USE_BEDROCK",
            "CLAUDE_CODE_USE_FOUNDRY",
            "CLAUDE_CODE_USE_MANTLE",
            "CLAUDE_CODE_USE_VERTEX"
        ] where environmentFlagEnabled(env[flag]) {
            return .init(
                state: .present,
                title: "Claude Code cloud-provider auth requested",
                detail: "\(flag) is enabled in Project Hub's environment. Claude Code gives cloud-provider credentials highest precedence; Project Hub did not inspect provider credential values.",
                fixHint: "Verify the provider credentials in the shell where Claude Code runs, then use `claude auth status` for a definitive status.",
                source: flag
            )
        }
        for key in ["ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_API_KEY"] {
            if let evidence = claudeCodeCredentialEnvironmentEvidence(
                key,
                title: key == "ANTHROPIC_AUTH_TOKEN" ? "Claude Code auth token in environment" : "Claude Code API key in environment",
                validDetail: "\(key) is present in Project Hub's environment. Claude Code gives this environment credential precedence over apiKeyHelper and browser login. Project Hub did not display the credential value.",
                missingTitle: "Claude Code environment credential is empty",
                missingDetail: "\(key) is set but empty or placeholder-like. Claude Code may try this higher-precedence credential instead of lower-precedence login credentials.",
                fixHint: "Unset or refresh \(key), then verify with `claude auth status`."
            ) {
                return evidence
            }
        }
        if includeLongLivedOAuth,
           let evidence = claudeCodeCredentialEnvironmentEvidence(
            "CLAUDE_CODE_OAUTH_TOKEN",
            title: "Claude Code OAuth token in environment",
            validDetail: "CLAUDE_CODE_OAUTH_TOKEN is present in Project Hub's environment. Claude Code can use this long-lived OAuth token for CI/scripts when browser login is unavailable. Project Hub did not display the token value.",
            missingTitle: "Claude Code OAuth token is empty",
            missingDetail: "CLAUDE_CODE_OAUTH_TOKEN is set but empty or placeholder-like.",
            fixHint: "Unset or refresh CLAUDE_CODE_OAUTH_TOKEN, then verify with `claude auth status`."
        ) {
            return evidence
        }
        return nil
    }

    private static func claudeCodeCredentialEnvironmentEvidence(
        _ key: String,
        title: String,
        validDetail: String,
        missingTitle: String,
        missingDetail: String,
        fixHint: String
    ) -> ClaudeCodeAuthEnvironmentEvidence? {
        guard let value = ProcessInfo.processInfo.environment[key] else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || looksLikeCredentialPlaceholder(trimmed) {
            return .init(state: .missingValue, title: missingTitle, detail: missingDetail, fixHint: fixHint, source: key)
        }
        return .init(state: .present, title: title, detail: validDetail, fixHint: fixHint, source: key)
    }

    private static func environmentFlagEnabled(_ value: String?) -> Bool {
        guard let value else { return false }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        return !["0", "false", "no", "off"].contains(normalized)
    }

    private static func codexAuthEnvironmentEvidence() -> CodexAuthEnvironmentEvidence? {
        if let evidence = codexCredentialEnvironmentEvidence(
            "CODEX_ACCESS_TOKEN",
            title: "Codex access token available for login",
            validDetail: "CODEX_ACCESS_TOKEN is present in Project Hub's environment, but no auth.json file exists. Codex can read this token through `codex login --with-access-token`; Project Hub did not display the token value.",
            missingTitle: "Codex environment credential is empty",
            missingDetail: "CODEX_ACCESS_TOKEN is set but empty or placeholder-like. Project Hub did not display the credential value.",
            fixHint: "Refresh or unset CODEX_ACCESS_TOKEN, then sign in with `codex login --with-access-token` if you want Codex to store it."
        ) {
            return evidence
        }
        if let evidence = codexCredentialEnvironmentEvidence(
            "OPENAI_API_KEY",
            title: "OpenAI API key available for Codex login",
            validDetail: "OPENAI_API_KEY is present in Project Hub's environment, but no auth.json file exists. Codex can read this key through `codex login --with-api-key`; Project Hub did not display the key value.",
            missingTitle: "Codex environment credential is empty",
            missingDetail: "OPENAI_API_KEY is set but empty or placeholder-like. Project Hub did not display the credential value.",
            fixHint: "Refresh or unset OPENAI_API_KEY, then sign in with `codex login --with-api-key` if you want Codex to store it."
        ) {
            return evidence
        }
        return nil
    }

    private static func codexCredentialEnvironmentEvidence(
        _ key: String,
        title: String,
        validDetail: String,
        missingTitle: String,
        missingDetail: String,
        fixHint: String
    ) -> CodexAuthEnvironmentEvidence? {
        guard let value = ProcessInfo.processInfo.environment[key] else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || looksLikeCredentialPlaceholder(trimmed) {
            return .init(state: .missingValue, title: missingTitle, detail: missingDetail, fixHint: fixHint, source: key)
        }
        return .init(state: .present, title: title, detail: validDetail, fixHint: fixHint, source: key)
    }

    private static func readClaudeCodeAuthEvidence(
        root: Any,
        path: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        let subtrees = claudeCodeAuthSubtrees(in: root)
        for subtree in subtrees {
            if let credentialPath = placeholderCredentialPath(in: subtree.value) {
                return [issue(
                    .serverAuthMissing,
                    .warning,
                    surface,
                    "Claude Code auth credential is empty",
                    "\(tilde(path)) exists, but \(subtree.keyPath).\(credentialPath) is empty or still a placeholder. Project Hub did not display the credential value.",
                    "Refresh authentication with Claude Code's official login flow."
                )]
            }
        }
        if subtrees.contains(where: { containsExpiredTimestamp($0.value) }) {
            return [issue(.serverAuthExpired, .warning, surface, "Claude Code authentication may be expired", "An auth/session subtree in \(tilde(path)) contains an expiration timestamp in the past.", "Refresh authentication with Claude Code's official login flow.")]
        }
        if subtrees.contains(where: { credentialEvidencePath(in: $0.value) != nil }) {
            return []
        }
        if let helperPath = claudeCodeAPIKeyHelperPath() {
            return [issue(
                .authCredentialStore,
                .info,
                surface,
                "Claude Code API key helper configured",
                "\(tilde(path)) has no recognizable OAuth/session token evidence, but apiKeyHelper is configured in \(tilde(helperPath)). Project Hub did not execute the helper or read its output.",
                "Verify Claude Code auth with its official login/status flow; Project Hub treats helper output as runtime-managed."
            )]
        }
        return [issue(
            .serverHealthUnknown,
            .info,
            surface,
            "Claude Code auth evidence not found",
            "\(tilde(path)) exists, but Project Hub found no recognizable OAuth/session/API-key evidence in its auth-shaped fields. The file may contain only MCP, cache, or project state, and Claude Code may still be authenticated through the OS credential store.",
            "Verify with `claude auth status`; sign in with `claude auth login` if Claude reports that authentication is missing."
        )]
    }

    private static func claudeCodeAuthSubtrees(in root: Any) -> [(keyPath: String, value: Any)] {
        guard let dict = root as? [String: Any] else { return [] }
        return dict.keys.sorted().compactMap { key in
            guard let value = dict[key],
                  isClaudeCodeAuthTopLevelKey(key) else { return nil }
            return (key, value)
        }
    }

    private static func isClaudeCodeAuthTopLevelKey(_ key: String) -> Bool {
        let normalized = key
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
        return normalized.contains("oauth")
            || normalized.contains("auth")
            || normalized.contains("session")
            || normalized.contains("token")
            || normalized.contains("apikey")
            || normalized.contains("credential")
    }

    private static func claudeCodeAPIKeyHelperPath() -> String? {
        let claudeHome = claudeHomeDirectory()
        for path in ["\(claudeHome)/settings.json"] {
            guard let raw = try? String(contentsOfFile: path, encoding: .utf8),
                  let data = ConfigWriter.stripJsonComments(raw).data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let helper = root["apiKeyHelper"] as? String,
                  !helper.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            return path
        }
        return nil
    }

    private static func codexCredentialStores(forAuthPath path: String) -> (cli: String?, mcpOAuth: String?)? {
        let authURL = URL(fileURLWithPath: path)
        let configPath = authURL.deletingLastPathComponent().appendingPathComponent("config.toml").path
        guard let raw = try? String(contentsOfFile: configPath, encoding: .utf8) else { return nil }
        let document = parseSettingsTOMLDocument(raw)
        return (
            stringSetting("cli_auth_credentials_store", in: document),
            stringSetting("mcp_oauth_credentials_store", in: document)
        )
    }

    // MARK: - Skills

    private struct SkillRead {
        var skills: [CompatibilitySkillObservation]
        var issues: [CompatibilityIssue]
    }

    private struct SkillOverride {
        let path: String
        let enabled: Bool
        let toolID: CompatibilityToolID
        let source: CompatibilityMatrixEntry
    }

    private struct ClaudeSkillOverride {
        let state: String
        let source: CompatibilityMatrixEntry
        let priority: Int
    }

    private struct ClaudeSkillPolicies {
        var overridesByName: [String: ClaudeSkillOverride]
        var shellExecutionDisabled: Bool
        var strictPluginOnlySkills: Bool
        var skillPermissionRules: [String: [String]]
    }

    private static func readSkills(from matrix: [CompatibilityMatrixEntry], servers: [CompatibilityServerObservation]) -> SkillRead {
        var observations: [CompatibilitySkillObservation] = []
        var issues: [CompatibilityIssue] = []
        let skillSurfaces = matrix.filter { $0.kind == .skills }
        let overrides = readCodexSkillOverrides(from: matrix)
        let claudePolicies = readClaudeSkillPolicies(from: matrix)
        let overrideBySkillMD = overrides.reduce(into: [String: SkillOverride]()) { partial, override in
            partial["\(override.toolID.rawValue):\(canonicalFilePath(override.path))"] = override
        }
        let availableMCPServersByTool = servers.reduce(into: [CompatibilityToolID: [ServerEntry]]()) { partial, server in
            guard serverCanSatisfySkillDependency(server),
                  let entry = healthEntry(for: server, matrix: matrix),
                  !entry.isDisabled else { return }
            partial[server.toolID, default: []].append(entry)
        }

        for surface in skillSurfaces {
            guard let root = surface.path else { continue }
            let fm = FileManager.default
            let directSkillMD = (root as NSString).appendingPathComponent("SKILL.md")
            let candidateDirectories: [(entry: String, dir: String)]
            if fm.fileExists(atPath: directSkillMD) {
                candidateDirectories = [(((root as NSString).lastPathComponent), root)]
            } else if let entries = try? fm.contentsOfDirectory(atPath: root) {
                candidateDirectories = entries.sorted().compactMap { entry in
                    let dir = (root as NSString).appendingPathComponent(entry)
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else { return nil }
                    return (entry, dir)
                }
            } else {
                continue
            }
            for candidate in candidateDirectories {
                let entry = candidate.entry
                let dir = candidate.dir
                let skillMD = (dir as NSString).appendingPathComponent("SKILL.md")
                guard fm.fileExists(atPath: skillMD) else {
                    issues.append(issue(.skillMissingSkillMD, .warning, surface, "Skill missing SKILL.md", "\(entry) is a folder in a skill root but has no SKILL.md.", "Remove the folder or add a valid SKILL.md."))
                    continue
                }
                let parsed = SkillReader.parse(at: skillMD)
                if parsed == nil {
                    issues.append(issue(.skillInvalidFrontmatter, .warning, surface, "Invalid skill frontmatter", "\(entry) has a SKILL.md but Project Hub could not parse its frontmatter.", "Fix the YAML frontmatter and ensure a name/description are present."))
                }
                let bareName = parsed?.name ?? entry
                let name: String
                if let namespace = claudePluginNamespace(from: surface),
                   !bareName.contains(":") {
                    name = "\(namespace):\(bareName)"
                } else if let namespace = codexPluginNamespace(fromSkillSurface: surface),
                          !bareName.contains(":") {
                    name = "\(namespace):\(bareName)"
                } else {
                    name = bareName
                }
                let version = skillVersion(at: skillMD)
                let override = overrideBySkillMD["\(surface.toolID.rawValue):\(canonicalFilePath(skillMD))"]
                let claudeOverride = surface.toolID == .claudeCode
                    ? claudePolicies.overridesByName[name] ?? claudePolicies.overridesByName[bareName]
                    : nil
                let metadata = SkillReader.parseOpenAIMetadata(at: dir)
                let claudeMetadata = SkillReader.parseClaudeMetadata(at: dir)
                let mcpDependencySpecs = metadata?.toolDependencies
                    .filter { $0.type.lowercased() == "mcp" }
                    ?? []
                let mcpDependencies = mcpDependencySpecs.map(\.value)
                let availableIn = availability(for: surface)
                if surface.toolID == .claudeCode, claudePolicies.strictPluginOnlySkills, !isClaudePluginSkillSurface(surface) {
                    issues.append(issue(
                        .skillDisabled,
                        .warning,
                        surface,
                        "Claude filesystem skill blocked by managed policy",
                        "\(name) is installed at \(tilde(skillMD)), but managed strictPluginOnlyCustomization locks skills to plugin-provided or managed sources.",
                        "Move this skill into an approved plugin/managed source or ask the administrator to relax strictPluginOnlyCustomization.",
                        subjectPath: skillMD
                    ))
                }
                if isClaudePluginSkillSurface(surface), !claudePluginSkillSurfaceEnabled(surface) {
                    issues.append(issue(
                        .skillDisabled,
                        .info,
                        surface,
                        "Claude plugin skill disabled",
                        "\(name) is installed at \(tilde(skillMD)), but the plugin is disabled for this scope.",
                        "Enable \(claudePluginID(from: surface) ?? "the plugin") with Claude Code plugin settings when these skills should be available.",
                        subjectPath: skillMD
                    ))
                }
                if isCodexPluginSkillSurface(surface), !codexPluginSkillSurfaceEnabled(surface) {
                    issues.append(issue(
                        .skillDisabled,
                        .info,
                        surface,
                        "Codex plugin skill disabled",
                        "\(name) is installed at \(tilde(skillMD)), but the Codex plugin is disabled in the active plugin configuration.",
                        "Enable \(codexPluginID(fromSkillSurface: surface) ?? "the plugin") in Codex plugin config, then restart Codex when these skills should be available.",
                        subjectPath: skillMD
                    ))
                }
                if let claudeOverride {
                    switch claudeOverride.state {
                    case "off":
                        issues.append(issue(
                            .skillDisabled,
                            .info,
                            claudeOverride.source,
                            "Claude skill disabled",
                            "\(name) is installed at \(tilde(skillMD)), but \(claudeOverride.source.label) sets skillOverrides.\(name) to off, hiding it from Claude and the slash menu.",
                            "Remove the override or set it to on when this skill should be available.",
                            subjectPath: skillMD
                        ))
                    case "name-only":
                        issues.append(issue(
                            .skillVisibilityLimited,
                            .info,
                            claudeOverride.source,
                            "Claude skill context collapsed",
                            "\(name) is installed at \(tilde(skillMD)), but \(claudeOverride.source.label) sets skillOverrides.\(name) to name-only, so Claude sees only the skill name.",
                            "Keep this intentionally for low-context skills, or set the override to on to expose the description.",
                            subjectPath: skillMD
                        ))
                    case "user-invocable-only":
                        issues.append(issue(
                            .skillVisibilityLimited,
                            .info,
                            claudeOverride.source,
                            "Claude skill hidden from model",
                            "\(name) is installed at \(tilde(skillMD)), but \(claudeOverride.source.label) sets skillOverrides.\(name) to user-invocable-only, so Claude cannot discover it automatically.",
                            "Keep this for user-driven commands, or set the override to on to let Claude discover it.",
                            subjectPath: skillMD
                        ))
                    default:
                        break
                    }
                }
                if override?.enabled == false {
                    issues.append(issue(.skillDisabled, .info, override?.source ?? surface, "Skill disabled", "\(name) at \(tilde(skillMD)) is present on disk but disabled by Codex skill configuration.", "Enable it in [[skills.config]] or leave it disabled intentionally.", subjectPath: skillMD))
                }
                let pluginEnabledOverride: Bool? = isCodexPluginSkillSurface(surface)
                    ? codexPluginSkillSurfaceEnabled(surface)
                    : nil
                for dependency in mcpDependencySpecs where !dependency.value.isEmpty {
                    let dependencyVisible = availableIn.contains { tool in
                        mcpDependency(dependency, isSatisfiedBy: availableMCPServersByTool[tool, default: []])
                    }
                    guard !dependencyVisible else { continue }
                    let dependencyDetail = mcpDependencyDetail(dependency)
                    issues.append(issue(
                        .skillMissingDependency,
                        .warning,
                        surface,
                        "Skill MCP dependency missing",
                        "\(name) declares an OpenAI skill metadata dependency on MCP server \(dependencyDetail), but Project Hub did not find that server in the compatible MCP inventory.",
                        "Install or enable the \(dependency.value) MCP server for \(availableIn.map(\.label).joined(separator: " or ")), or update agents/openai.yaml if the dependency name, transport, or URL changed.",
                        subjectPath: (dir as NSString).appendingPathComponent("agents/openai.yaml")
                    ))
                }
                observations.append(CompatibilitySkillObservation(
                    id: "\(surface.id):\(canonicalFilePath(dir))",
                    toolID: surface.toolID,
                    surfaceID: surface.id,
                    name: name,
                    path: dir,
                    scope: surface.scope,
                    description: parsed?.description ?? "",
                    version: version,
                    parseOK: parsed != nil,
                    enabledOverride: override?.enabled ?? pluginEnabledOverride,
                    availableIn: availableIn,
                    displayName: metadata?.displayName,
                    shortDescription: metadata?.shortDescription,
                    iconSmall: metadata?.iconSmall,
                    iconLarge: metadata?.iconLarge,
                    brandColor: metadata?.brandColor,
                    defaultPrompt: metadata?.defaultPrompt,
                    allowImplicitInvocation: metadata?.allowImplicitInvocation,
                    mcpDependencies: mcpDependencies,
                    claudeWhenToUse: claudeMetadata?.whenToUse,
                    claudeAllowedTools: claudeMetadata?.allowedTools ?? [],
                    claudeDisableModelInvocation: claudeMetadata?.disableModelInvocation,
                    claudeUserInvocable: claudeMetadata?.userInvocable,
                    claudeArgumentHint: claudeMetadata?.argumentHint,
                    claudeArguments: claudeMetadata?.arguments ?? [],
                    claudeModel: claudeMetadata?.model,
                    claudeEffort: claudeMetadata?.effort,
                    claudeContext: claudeMetadata?.context,
                    claudeAgent: claudeMetadata?.agent,
                    claudePaths: claudeMetadata?.paths ?? [],
                    claudeShell: claudeMetadata?.shell,
                    claudeHooks: claudeMetadata?.hooks,
                    claudeOverrideState: claudeOverride?.state,
                    claudeOverrideSource: claudeOverride.map { "\($0.source.label) (\(tilde($0.source.path ?? "")))" },
                    claudeShellExecutionDisabled: surface.toolID == .claudeCode && claudePolicies.shellExecutionDisabled,
                    claudeSkillPermissionRules: surface.toolID == .claudeCode
                        ? uniqueStringsPreservingOrder((claudePolicies.skillPermissionRules["*"] ?? []) + (claudePolicies.skillPermissionRules[name] ?? []) + (claudePolicies.skillPermissionRules[bareName] ?? []))
                        : []
                ))
            }
        }

        let observedSkillMDs = Set(observations.map { canonicalFilePath(($0.path as NSString).appendingPathComponent("SKILL.md")) })
        for override in overrides where !observedSkillMDs.contains(canonicalFilePath(override.path)) {
            issues.append(issue(.skillMissingSkillMD, .warning, override.source, "Skill override points at missing SKILL.md", "\(tilde(override.path)) is referenced by [[skills.config]] but was not found in any scanned skill root.", "Remove or update the stale skill override in config.toml."))
        }

        let groups = Dictionary(grouping: observations) { "\($0.toolID.rawValue):\($0.name)" }
        for (_, group) in groups where group.count > 1 {
            let paths = group.map(\.path).joined(separator: "\n")
            issues.append(CompatibilityIssue(
                id: UUID(),
                code: .skillDuplicateName,
                severity: .warning,
                toolID: group.first?.toolID,
                surfaceID: nil,
                title: "Duplicate skill name",
                detail: "\"\(group.first?.name ?? "skill")\" is installed in multiple \(group.first?.toolID.label ?? "tool") skill roots.\n\(paths)",
                path: group.first?.path,
                subjectPath: nil,
                fixHint: "Show every copy and let the user choose the canonical version."
            ))
        }

        let versionGroups = Dictionary(grouping: observations.filter { $0.version != nil }) { "\($0.toolID.rawValue):\($0.name)" }
        for (_, group) in versionGroups {
            let versions = Set(group.compactMap(\.version))
            guard versions.count > 1 else { continue }
            let detail = group
                .map { skill in
                    "\(skill.version ?? "unknown") — \(tilde(skill.path))"
                }
                .joined(separator: "\n")
            issues.append(CompatibilityIssue(
                id: UUID(),
                code: .skillVersionConflict,
                severity: .warning,
                toolID: group.first?.toolID,
                surfaceID: nil,
                title: "Skill version conflict",
                detail: "\"\(group.first?.name ?? "skill")\" has multiple installed versions for \(group.first?.toolID.label ?? "this tool").\n\(detail)",
                path: group.first?.path,
                subjectPath: nil,
                fixHint: "Choose the copy that should win for this app/scope and remove or update the older copy."
            ))
        }

        return SkillRead(
            skills: observations.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            issues: issues
        )
    }

    private static func serverCanSatisfySkillDependency(_ server: CompatibilityServerObservation) -> Bool {
        guard !server.disabled, server.health != .disabled, server.health != .broken else { return false }
        let incompatibleCodes: Set<CompatibilityIssueCode> = [
            .serverDisabled,
            .serverMissingLaunchTarget,
            .serverUnsupportedTransport,
            .serverCommandMissing,
            .serverReservedName
        ]
        return incompatibleCodes.isDisjoint(with: Set(server.issueCodes))
    }

    private static func mcpDependency(
        _ dependency: SkillReader.OpenAIMetadata.ToolDependency,
        isSatisfiedBy servers: [ServerEntry]
    ) -> Bool {
        if let dependencyURL = normalizedMCPURL(dependency.url) {
            return servers.contains { server in
                normalizedMCPURL(server.url) == dependencyURL
                    && mcpTransport(dependency.transport, matches: server.transport)
            }
        }

        return servers.contains { server in
            server.name == dependency.value
                && mcpTransport(dependency.transport, matches: server.transport)
        }
    }

    private static func mcpDependencyDetail(_ dependency: SkillReader.OpenAIMetadata.ToolDependency) -> String {
        var parts = ["\"\(dependency.value)\""]
        if let transport = dependency.transport, !transport.isEmpty {
            parts.append("transport \(transport)")
        }
        if let url = dependency.url, !url.isEmpty {
            parts.append("URL \(url)")
        }
        return parts.joined(separator: " with ")
    }

    private static func mcpTransport(_ dependencyTransport: String?, matches serverTransport: String) -> Bool {
        guard let dependencyTransport = normalizedMCPTransport(dependencyTransport) else { return true }
        return normalizedMCPTransport(serverTransport) == dependencyTransport
    }

    private static func normalizedMCPURL(_ raw: String?) -> String? {
        guard let raw,
              var components = URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = components.scheme?.lowercased(),
              ["http", "https", "ws", "wss"].contains(scheme),
              components.host != nil else { return nil }

        components.scheme = scheme
        components.host = components.host?.lowercased()
        components.fragment = nil

        var path = components.percentEncodedPath
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        components.percentEncodedPath = path == "/" ? "" : path

        return components.string
    }

    private static func normalizedMCPTransport(_ raw: String?) -> String? {
        guard let raw else { return nil }
        switch raw.lowercased().replacingOccurrences(of: "-", with: "_") {
        case "stdio", "local":
            return "stdio"
        case "sse":
            return "sse"
        case "http", "https", "remote", "streamable_http", "streamablehttp":
            return "http"
        case "ws", "wss":
            return "ws"
        default:
            return nil
        }
    }

    private static func readClaudeSkillPolicies(from matrix: [CompatibilityMatrixEntry]) -> ClaudeSkillPolicies {
        var overrides: [String: ClaudeSkillOverride] = [:]
        var shellDisabled: (enabled: Bool, priority: Int)?
        var strictPluginOnly: (enabled: Bool, priority: Int)?
        var permissionRules: [String: [String]] = [:]
        let validStates = Set(["on", "name-only", "user-invocable-only", "off"])

        for surface in matrix where surface.toolID == .claudeCode && surface.kind == .settings {
            guard let path = surface.path,
                  FileManager.default.fileExists(atPath: path),
                  let raw = try? String(contentsOfFile: path, encoding: .utf8),
                  let data = ConfigWriter.stripJsonComments(raw).data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            let priority = claudeSettingsPolicyPriority(surface)
            if let disabled = boolSetting("disableSkillShellExecution", in: root),
               shellDisabled == nil || priority > (shellDisabled?.priority ?? Int.min) {
                shellDisabled = (disabled, priority)
            }
            if surface.id.contains("managed-settings") {
                let locksSkills = claudeStrictPluginOnlyLocksSkills(root)
                if strictPluginOnly == nil || priority > (strictPluginOnly?.priority ?? Int.min) {
                    strictPluginOnly = (locksSkills, priority)
                }
            }
            if let dictionary = root["skillOverrides"] as? [String: Any] {
                for (skillName, value) in dictionary {
                    guard let state = value as? String,
                          validStates.contains(state),
                          overrides[skillName] == nil || priority > (overrides[skillName]?.priority ?? Int.min) else {
                        continue
                    }
                    overrides[skillName] = ClaudeSkillOverride(
                        state: state,
                        source: surface,
                        priority: priority
                    )
                }
            }
            for rule in claudeSkillPermissionRules(in: root) {
                for skillName in rule.appliesToSkillNames {
                    permissionRules[skillName, default: []].append("\(rule.mode): \(rule.raw)")
                }
            }
        }

        return ClaudeSkillPolicies(
            overridesByName: overrides,
            shellExecutionDisabled: shellDisabled?.enabled == true,
            strictPluginOnlySkills: strictPluginOnly?.enabled == true,
            skillPermissionRules: permissionRules
        )
    }

    private static func claudeStrictPluginOnlyLocksSkills(_ root: [String: Any]) -> Bool {
        if let bool = root["strictPluginOnlyCustomization"] as? Bool {
            return bool
        }
        if let strings = root["strictPluginOnlyCustomization"] as? [String] {
            return strings.contains("skills")
        }
        if let array = root["strictPluginOnlyCustomization"] as? [Any] {
            return array.contains { ($0 as? String) == "skills" }
        }
        return false
    }

    private struct ClaudeSkillPermissionRule {
        let mode: String
        let raw: String
        let appliesToSkillNames: [String]
    }

    private static func claudeSkillPermissionRules(in root: [String: Any]) -> [ClaudeSkillPermissionRule] {
        guard let permissions = root["permissions"] as? [String: Any] else { return [] }
        var rules: [ClaudeSkillPermissionRule] = []
        for mode in ["allow", "ask", "deny"] {
            for raw in stringArray(permissions[mode]) {
                guard raw == "Skill" || raw.hasPrefix("Skill(") else { continue }
                let names = claudeSkillNames(fromPermissionRule: raw)
                rules.append(ClaudeSkillPermissionRule(mode: mode, raw: raw, appliesToSkillNames: names))
            }
        }
        return rules
    }

    private static func claudeSkillNames(fromPermissionRule raw: String) -> [String] {
        guard raw.hasPrefix("Skill("),
              let open = raw.firstIndex(of: "("),
              let close = raw.lastIndex(of: ")"),
              close > open else {
            return raw == "Skill" ? ["*"] : []
        }
        let inner = raw[raw.index(after: open)..<close]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !inner.isEmpty else { return [] }
        let name = inner.components(separatedBy: .whitespaces)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? [] : [name]
    }

    private static func claudeSettingsPolicyPriority(_ surface: CompatibilityMatrixEntry) -> Int {
        if surface.id.contains("managed-settings") { return 1_000 + surface.precedence }
        switch surface.scope {
        case .localProjectUser:
            return 900 + surface.precedence
        case .project:
            return 800 + surface.precedence
        case .global:
            return 700 + surface.precedence
        default:
            return surface.precedence
        }
    }

    private static func skillVersion(at skillMD: String) -> String? {
        guard let content = try? String(contentsOfFile: skillMD, encoding: .utf8),
              let frontmatter = SkillReader.parseFrontmatter(content) else {
            return nil
        }
        for key in ["version", "skill_version", "skillVersion"] {
            if let version = frontmatter[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !version.isEmpty {
                return version
            }
        }
        return nil
    }

    private static func availability(for surface: CompatibilityMatrixEntry) -> [CompatibilityToolID] {
        switch surface.toolID {
        case .claudeCode:
            return [.claudeCode]
        case .codexCLI:
            return [.codexCLI, .codexDesktop]
        case .codexDesktop:
            return [.codexDesktop, .codexCLI]
        case .claudeDesktop:
            return [.claudeDesktop]
        }
    }

    private static func skillSupportObservations(from matrix: [CompatibilityMatrixEntry]) -> [CompatibilitySkillSupportObservation] {
        let skillSurfaces = matrix.filter { $0.kind == .skills }

        func roots(for tool: CompatibilityToolID, scope: CompatibilityScope? = nil) -> [String] {
            skillSurfaces
                .filter { surface in
                    surface.toolID == tool && (scope == nil || surface.scope == scope)
                }
                .compactMap(\.path)
                .sorted()
        }

        var observations: [CompatibilitySkillSupportObservation] = []
        let claudeCodeRoots = roots(for: .claudeCode)
        observations.append(CompatibilitySkillSupportObservation(
            id: "skill-support-claude-code",
            toolID: .claudeCode,
            state: claudeCodeRoots.isEmpty ? .unknown : .supported,
            scope: .project,
            roots: claudeCodeRoots,
            summary: claudeCodeRoots.isEmpty ? "No Claude Code skill roots in this scan" : "Claude Code filesystem and plugin skills supported",
            detail: "Claude Code uses personal, project, nested, runtime additional-directory, and plugin-managed skill roots. Existing filesystem skill directories are live-watched; creating a top-level skills directory after session start can still require restarting Claude Code. Managed strictPluginOnlyCustomization blocks filesystem skill roots but still allows plugin-provided or managed skills.",
            requiresRestartAfterWrite: false
        ))

        observations.append(CompatibilitySkillSupportObservation(
            id: "skill-support-claude-desktop",
            toolID: .claudeDesktop,
            state: .appManaged,
            scope: .global,
            roots: [],
            summary: "No verified local Claude Desktop skill root",
            detail: "Claude Desktop/Claude.ai skills are account or app managed. Project Hub treats them as unavailable for local filesystem writes until an official local Desktop skill root is detected.",
            requiresRestartAfterWrite: false
        ))

        let codexCLIRoots = roots(for: .codexCLI)
        observations.append(CompatibilitySkillSupportObservation(
            id: "skill-support-codex-cli",
            toolID: .codexCLI,
            state: codexCLIRoots.isEmpty ? .unknown : .supported,
            scope: .project,
            roots: codexCLIRoots,
            summary: codexCLIRoots.isEmpty ? "No Codex CLI skill roots in this scan" : "Codex CLI filesystem skills supported",
            detail: "Codex CLI uses user, admin, and repository .agents/skills roots. Project Hub scans installed skills and [[skills.config]] overrides for disabled or stale entries.",
            requiresRestartAfterWrite: true
        ))

        let codexDesktopRoots = roots(for: .codexDesktop)
        observations.append(CompatibilitySkillSupportObservation(
            id: "skill-support-codex-desktop",
            toolID: .codexDesktop,
            state: codexDesktopRoots.isEmpty ? .unknown : .shared,
            scope: .project,
            roots: codexDesktopRoots,
            summary: codexDesktopRoots.isEmpty ? "No Codex Desktop skill roots in this scan" : "Codex Desktop shares Codex filesystem skills",
            detail: "Codex Desktop app sessions share the Codex skill model with user-authored ~/.agents/skills, admin /etc/codex/skills, managed local evidence under CODEX_HOME, and project .agents/skills roots.",
            requiresRestartAfterWrite: true
        ))

        return observations
    }

    private static func readCodexSkillOverrides(from matrix: [CompatibilityMatrixEntry]) -> [SkillOverride] {
        let surfaces = matrix
            .filter { $0.kind == .settings && ($0.toolID == .codexCLI || $0.toolID == .codexDesktop) && $0.format == .toml }

        var overrides: [SkillOverride] = []
        var seen = Set<String>()
        for surface in surfaces {
            guard let path = surface.path,
                  let raw = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            let seenKey = "\(surface.toolID.rawValue):\(canonicalFilePath(path))"
            guard seen.insert(seenKey).inserted else { continue }
            for item in parseCodexSkillConfigTOML(raw) {
                let skillMD = resolveCodexSkillOverridePath(item.path, configPath: path)
                overrides.append(SkillOverride(path: skillMD, enabled: item.enabled, toolID: surface.toolID, source: surface))
            }
        }
        return overrides
    }

    private static func resolveCodexSkillOverridePath(_ rawPath: String, configPath: String) -> String {
        let expanded = (rawPath as NSString).expandingTildeInPath
        let absolute = expanded.hasPrefix("/")
            ? expanded
            : ((configPath as NSString).deletingLastPathComponent as NSString).appendingPathComponent(expanded)
        if (absolute as NSString).lastPathComponent == "SKILL.md" {
            return absolute
        }
        return (absolute as NSString).appendingPathComponent("SKILL.md")
    }

    // MARK: - Low-level helpers

    private static func issue(
        _ code: CompatibilityIssueCode,
        _ severity: CompatibilityIssueSeverity,
        _ surface: CompatibilityMatrixEntry,
        _ title: String,
        _ detail: String,
        _ fixHint: String?,
        subjectPath: String? = nil,
        metadata: [String: String] = [:]
    ) -> CompatibilityIssue {
        CompatibilityIssue(
            id: UUID(),
            code: code,
            severity: severity,
            toolID: surface.toolID,
            surfaceID: surface.id,
            title: title,
            detail: detail,
            path: surface.path,
            subjectPath: subjectPath,
            fixHint: fixHint,
            metadata: metadata
        )
    }

    private static func commandExists(_ command: String, cwd: String? = nil) -> Bool {
        if command.contains("/") {
            let expanded = (command as NSString).expandingTildeInPath
            let path: String
            if expanded.hasPrefix("/") {
                path = expanded
            } else if let cwd, !cwd.contains("${") {
                path = URL(fileURLWithPath: expanded, relativeTo: URL(fileURLWithPath: cwd))
                    .standardizedFileURL
                    .path
            } else {
                path = expanded
            }
            return FileManager.default.isExecutableFile(atPath: path)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func launchCommand(from config: [String: Any]) -> (command: String?, args: [String]) {
        let explicitArgs = stringArray(config["args"])
        if let commandParts = config["command"] as? [String], !commandParts.isEmpty {
            let args = explicitArgs.isEmpty ? Array(commandParts.dropFirst()) : explicitArgs
            return normalizedLaunchCommand(command: commandParts[0], args: args)
        }
        if let commandParts = config["command"] as? [Any] {
            let strings = commandParts.compactMap { $0 as? String }
            if !strings.isEmpty {
                let args = explicitArgs.isEmpty ? Array(strings.dropFirst()) : explicitArgs
                return normalizedLaunchCommand(command: strings[0], args: args)
            }
        }
        guard let rawCommand = config["command"] as? String else {
            return (nil, explicitArgs)
        }
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, explicitArgs) }
        if explicitArgs.isEmpty {
            let tokens = shellSplit(trimmed)
            if tokens.count > 1, shouldSplitCommandString(firstToken: tokens[0]) {
                return normalizedLaunchCommand(command: tokens[0], args: Array(tokens.dropFirst()))
            }
        }
        return normalizedLaunchCommand(command: trimmed, args: explicitArgs)
    }

    private static func normalizedLaunchCommand(command: String, args: [String]) -> (command: String?, args: [String]) {
        let tokens = expandEnvSplitString([command] + args)
        guard tokens.count > 1, isEnvCommand(tokens[0]) else {
            return (command, args)
        }
        var index = 1
        while index < tokens.count {
            let token = tokens[index]
            if token == "-i" || token == "--ignore-environment" {
                index += 1
                continue
            }
            if token == "-u" || token == "--unset" {
                index += 2
                continue
            }
            if token.hasPrefix("-u"), token.count > 2 {
                index += 1
                continue
            }
            if token.hasPrefix("-") { return (command, args) }
            if envAssignment(token) != nil {
                index += 1
                continue
            }
            if isEnvName(token),
               index + 1 < tokens.count,
               commandStarters.contains(URL(fileURLWithPath: tokens[index + 1]).lastPathComponent.lowercased()) {
                index += 1
                continue
            }
            break
        }
        guard index < tokens.count else { return (command, args) }
        return (tokens[index], Array(tokens.dropFirst(index + 1)))
    }

    private static func expandEnvSplitString(_ tokens: [String]) -> [String] {
        guard tokens.count >= 3, isEnvCommand(tokens[0]) else { return tokens }
        var out: [String] = [tokens[0]]
        var index = 1
        while index < tokens.count {
            let token = tokens[index]
            if (token == "-S" || token == "--split-string"), index + 1 < tokens.count {
                out.append(contentsOf: shellSplit(tokens[index + 1]))
                index += 2
                continue
            }
            if token.hasPrefix("--split-string=") {
                out.append(contentsOf: shellSplit(String(token.dropFirst("--split-string=".count))))
                index += 1
                continue
            }
            out.append(token)
            index += 1
        }
        return out
    }

    private static func isEnvCommand(_ token: String) -> Bool {
        URL(fileURLWithPath: token).lastPathComponent.lowercased() == "env"
    }

    private static func envAssignment(_ token: String) -> (key: String, value: String)? {
        guard let eq = token.firstIndex(of: "="), eq > token.startIndex else { return nil }
        let key = String(token[..<eq])
        guard isEnvName(key) else { return nil }
        return (key, String(token[token.index(after: eq)...]))
    }

    private static func isEnvName(_ value: String) -> Bool {
        guard let first = value.unicodeScalars.first,
              CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_").contains(first) else {
            return false
        }
        return value.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_").contains($0)
        }
    }

    private static func shouldSplitCommandString(firstToken: String) -> Bool {
        let lower = URL(fileURLWithPath: firstToken).lastPathComponent.lowercased()
        return commandStarters.contains(lower)
    }

    private static let commandStarters: Set<String> = [
        "env", "npx", "npm", "pnpm", "yarn", "bunx", "bun",
        "uvx", "uv", "python", "python3", "pipx",
        "docker", "node", "deno", "brew", "cargo", "go"
    ]

    private static func shellSplit(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escapeNext = false

        for ch in input {
            if escapeNext {
                current.append(ch)
                escapeNext = false
                continue
            }
            if ch == "\\" && !inSingle {
                escapeNext = true
                continue
            }
            if ch == "'" && !inDouble {
                inSingle.toggle()
                continue
            }
            if ch == "\"" && !inSingle {
                inDouble.toggle()
                continue
            }
            if ch.isWhitespace && !inSingle && !inDouble {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                continue
            }
            current.append(ch)
        }

        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }

    private static func missingEnvironmentVariables(in config: [String: Any], excludingEnvFileReferences: Bool = false) -> [String] {
        var config = config
        if excludingEnvFileReferences {
            config.removeValue(forKey: "envFile")
            config.removeValue(forKey: "env_file")
        }
        var names = Set<String>()
        collectEnvReferences(in: config, into: &names)
        for name in codexLocalEnvVars(config["env_vars"]) where isEnvironmentVariableName(name) {
            names.insert(name)
        }
        for name in stringDict(config["env_http_headers"]).values where isEnvironmentVariableName(name) {
            names.insert(name)
        }
        let launch = launchCommand(from: config)
        names.formUnion(dockerEnvFlagVars(command: launch.command, args: launch.args))
        return names
            .filter { ProcessInfo.processInfo.environment[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true }
            .sorted()
    }

    private static func dockerEnvFlagVars(command: String?, args: [String]) -> Set<String> {
        guard let command,
              URL(fileURLWithPath: command).lastPathComponent.lowercased() == "docker" else { return [] }
        var names = Set<String>()
        var index = 0
        while index < args.count {
            let token = args[index]
            if token == "-e" || token == "--env" {
                index += 1
                if index < args.count {
                    recordDockerEnvFlag(args[index], into: &names)
                }
            } else if token.hasPrefix("--env=") {
                recordDockerEnvFlag(String(token.dropFirst("--env=".count)), into: &names)
            } else if token.hasPrefix("-e"), token.count > 2 {
                recordDockerEnvFlag(String(token.dropFirst(2)), into: &names)
            }
            index += 1
        }
        return names
    }

    private static func dockerMissingPathEnvVars(command: String?, args: [String]) -> [String] {
        guard let command,
              URL(fileURLWithPath: command).lastPathComponent.lowercased() == "docker" else { return [] }
        return Array(Set((dockerEnvFileArgs(in: args) + dockerHostMountArgs(in: args)).flatMap(requiredEnvExpansionNames(in:))))
            .filter { ProcessInfo.processInfo.environment[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true }
            .sorted()
    }

    private static func recordDockerEnvFlag(_ raw: String, into names: inout Set<String>) {
        if let eq = raw.firstIndex(of: "="), eq > raw.startIndex {
            names.formUnion(requiredEnvExpansionNames(in: String(raw[raw.index(after: eq)...])))
            return
        }
        if isEnvironmentVariableName(raw) {
            names.insert(raw)
        }
    }

    private static func dockerMissingEnvFiles(command: String?, args: [String], cwd: String?, configPath: String?) -> [String] {
        guard let command,
              URL(fileURLWithPath: command).lastPathComponent.lowercased() == "docker" else { return [] }
        return dockerEnvFileArgs(in: args)
            .filter { missingRequiredEnvExpansionNames(in: $0).isEmpty && inputVariableReferences(in: $0).isEmpty }
            .map { resolveDockerHostPath($0, cwd: cwd, configPath: configPath) }
            .filter { path in
                var isDirectory: ObjCBool = false
                return !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) || isDirectory.boolValue
            }
            .sorted()
    }

    private static func dockerEnvFileArgs(in args: [String]) -> [String] {
        var paths: [String] = []
        var index = 0
        while index < args.count {
            let token = args[index]
            if token == "--env-file" {
                index += 1
                if index < args.count { paths.append(args[index]) }
            } else if token.hasPrefix("--env-file=") {
                paths.append(String(token.dropFirst("--env-file=".count)))
            }
            index += 1
        }
        return paths.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func dockerMissingMountPaths(command: String?, args: [String], cwd: String?, configPath: String?) -> [String] {
        guard let command,
              URL(fileURLWithPath: command).lastPathComponent.lowercased() == "docker" else { return [] }
        return dockerHostMountArgs(in: args)
            .filter { missingRequiredEnvExpansionNames(in: $0).isEmpty && inputVariableReferences(in: $0).isEmpty }
            .map { resolveDockerHostPath($0, cwd: cwd, configPath: configPath) }
            .filter { !FileManager.default.fileExists(atPath: $0) }
            .sorted()
    }

    private static func dockerHostMountArgs(in args: [String]) -> [String] {
        var paths: [String] = []
        var index = 0
        while index < args.count {
            let token = args[index]
            if token == "-v" || token == "--volume" {
                index += 1
                if index < args.count { recordDockerVolumeMount(args[index], into: &paths) }
            } else if token.hasPrefix("--volume=") {
                recordDockerVolumeMount(String(token.dropFirst("--volume=".count)), into: &paths)
            } else if token == "--mount" {
                index += 1
                if index < args.count { recordDockerStructuredMount(args[index], into: &paths) }
            } else if token.hasPrefix("--mount=") {
                recordDockerStructuredMount(String(token.dropFirst("--mount=".count)), into: &paths)
            }
            index += 1
        }
        return paths
    }

    private static func recordDockerVolumeMount(_ raw: String, into paths: inout [String]) {
        guard let colon = raw.firstIndex(of: ":") else { return }
        recordDockerHostPathCandidate(String(raw[..<colon]), treatPlainAsRelative: false, into: &paths)
    }

    private static func recordDockerStructuredMount(_ raw: String, into paths: inout [String]) {
        var fields: [String: String] = [:]
        for field in raw.split(separator: ",") {
            guard let eq = field.firstIndex(of: "=") else { continue }
            let key = field[..<eq].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = field[field.index(after: eq)...].trimmingCharacters(in: .whitespacesAndNewlines)
            fields[key] = value
        }
        let mountType = fields["type"]?.lowercased()
        if let mountType, mountType != "bind" { return }
        if let source = fields["source"] ?? fields["src"] {
            recordDockerHostPathCandidate(source, treatPlainAsRelative: mountType == "bind", into: &paths)
        }
    }

    private static func recordDockerHostPathCandidate(_ raw: String, treatPlainAsRelative: Bool, into paths: inout [String]) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        guard treatPlainAsRelative || value.hasPrefix("/") || value.hasPrefix("~/") || value.hasPrefix("./") || value.hasPrefix("../") || value.contains("${") else { return }
        paths.append(value)
    }

    private static func resolveDockerHostPath(_ raw: String, cwd: String?, configPath: String?) -> String {
        let base = cwd ?? configPath.map(workspaceDirectory(forConfigPath:))
        var value = raw
        value = expandPathPlaceholders(value, base: base)
        value = expandEnvRefs(value)
        let expanded = (value as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded).standardizedFileURL.path
        }
        if let base {
            return URL(fileURLWithPath: expanded, relativeTo: URL(fileURLWithPath: base))
                .standardizedFileURL
                .path
        }
        return URL(fileURLWithPath: expanded).standardizedFileURL.path
    }

    private static func missingRequiredEnvExpansionNames(in value: String) -> [String] {
        requiredEnvExpansionNames(in: value)
            .filter { ProcessInfo.processInfo.environment[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true }
            .sorted()
    }

    private static func inputVariableReferences(in value: Any) -> [String] {
        var refs = Set<String>()
        collectInputVariableReferences(in: value, into: &refs)
        return refs.sorted()
    }

    private static func normalizedEnvFile(_ raw: Any?) -> String? {
        let string = raw as? String ?? raw.map { "\($0)" }
        let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedCWD(_ raw: Any?) -> String? {
        let string = raw as? String ?? raw.map { "\($0)" }
        let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func cwdNeedsMissingDirectoryWarning(_ raw: String, configPath: String?) -> Bool {
        guard let configPath else { return false }
        let resolved = resolveWorkspaceRelativePath(raw, configPath: configPath)
        guard !resolved.contains("${") else { return false }
        var isDirectory: ObjCBool = false
        return !FileManager.default.fileExists(atPath: resolved, isDirectory: &isDirectory) || !isDirectory.boolValue
    }

    private static func resolvedCWD(_ raw: String, configPath: String?) -> String? {
        guard let configPath else { return nil }
        return resolveWorkspaceRelativePath(raw, configPath: configPath)
    }

    private static func envFileNeedsMissingFileWarning(_ raw: String, configPath: String?) -> Bool {
        guard let configPath else { return false }
        let resolved = resolveWorkspaceRelativePath(raw, configPath: configPath)
        guard !resolved.contains("${") else { return false }
        var isDirectory: ObjCBool = false
        return !FileManager.default.fileExists(atPath: resolved, isDirectory: &isDirectory) || isDirectory.boolValue
    }

    private static func resolveWorkspaceRelativePath(_ raw: String, configPath: String) -> String {
        let workspaceDirectory = workspaceDirectory(forConfigPath: configPath)
        var value = raw
        value = expandPathPlaceholders(value, base: workspaceDirectory)
        value = expandEnvRefs(value)
        let expanded = (value as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded).standardizedFileURL.path
        }
        return URL(fileURLWithPath: expanded, relativeTo: URL(fileURLWithPath: workspaceDirectory))
            .standardizedFileURL
            .path
    }

    private static func expandPathPlaceholders(_ raw: String, base: String?) -> String {
        var value = raw.replacingOccurrences(
            of: "${userHome}",
            with: FileManager.default.homeDirectoryForCurrentUser.path
        )
        if let base {
            value = value.replacingOccurrences(of: "${workspaceFolder}", with: base)
            value = value.replacingOccurrences(of: "${workspaceFolderBasename}", with: (base as NSString).lastPathComponent)
        }
        return value
    }

    private static func workspaceDirectory(forConfigPath configPath: String) -> String {
        let directory = (configPath as NSString).deletingLastPathComponent
        let name = (directory as NSString).lastPathComponent
        if [".vscode", ".cursor", ".roo", ".claude", ".codex"].contains(name) {
            return (directory as NSString).deletingLastPathComponent
        }
        return directory
    }

    private static func collectInputVariableReferences(in value: Any, into refs: inout Set<String>) {
        if let string = value as? String {
            let pattern = #"\$\{input:([^}]+)\}"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return }
            let ns = string as NSString
            for match in regex.matches(in: string, range: NSRange(location: 0, length: ns.length)) {
                let raw = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !raw.isEmpty {
                    refs.insert(raw)
                }
            }
        } else if let dict = value as? [String: Any] {
            for nested in dict.values { collectInputVariableReferences(in: nested, into: &refs) }
        } else if let array = value as? [Any] {
            for nested in array { collectInputVariableReferences(in: nested, into: &refs) }
        }
    }

    private static func requiredEnvExpansionNames(in value: String) -> [String] {
        envExpansionTemplateNames(in: value, includeFallbacks: false)
    }

    private static func envExpansionTemplateNames(in value: String, includeFallbacks: Bool) -> [String] {
        let ns = value as NSString
        let patterns = [
            #"\$\{env:([A-Za-z_][A-Za-z0-9_]*)(?::-[^}]*)?\}"#,
            #"\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-[^}]*)?\}"#
        ]
        var names: [String] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: value, range: NSRange(location: 0, length: ns.length)) {
                let raw = ns.substring(with: match.range(at: 0))
                guard includeFallbacks || !raw.contains(":-") else { continue }
                let name = ns.substring(with: match.range(at: 1))
                if !isWorkspacePlaceholderName(name) {
                    names.append(name)
                }
            }
        }
        return Array(Set(names)).sorted()
    }

    private static func expandEnvRefs(_ value: String) -> String {
        var result = expandEnvRefs(
            value,
            pattern: #"\$\{env:([A-Za-z_][A-Za-z0-9_]*)(?::-(.*?))?\}"#
        )
        result = expandEnvRefs(
            result,
            pattern: #"\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-(.*?))?\}"#
        )
        return result
    }

    private static func expandEnvRefs(_ value: String, pattern: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        var result = value
        let ns = value as NSString
        let matches = regex.matches(in: value, range: NSRange(location: 0, length: ns.length)).reversed()
        for match in matches {
            let raw = ns.substring(with: match.range(at: 0))
            let name = ns.substring(with: match.range(at: 1))
            let fallback = match.range(at: 2).location != NSNotFound ? ns.substring(with: match.range(at: 2)) : ""
            let replacement: String
            if let envValue = ProcessInfo.processInfo.environment[name] {
                replacement = envValue
            } else if match.range(at: 2).location != NSNotFound {
                replacement = fallback
            } else if isWorkspacePlaceholderName(name) {
                replacement = raw
            } else {
                replacement = ""
            }
            if let range = Range(match.range(at: 0), in: result) {
                result.replaceSubrange(range, with: replacement)
            }
        }
        return result
    }

    private static func collectEnvReferences(in value: Any, into names: inout Set<String>) {
        if let string = value as? String {
            for name in requiredEnvExpansionNames(in: string) {
                names.insert(name)
            }
        } else if let dict = value as? [String: Any] {
            for nested in dict.values { collectEnvReferences(in: nested, into: &names) }
        } else if let array = value as? [Any] {
            for nested in array { collectEnvReferences(in: nested, into: &names) }
        }
    }

    private static func isWorkspacePlaceholderName(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized == "workspaceFolder"
            || normalized == "workspaceFolderBasename"
            || normalized == "userHome"
    }

    private static func isEnvironmentVariableName(_ value: String) -> Bool {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        return name.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) != nil
    }

    private static func codexLiteralEnvTemplateIssues(
        in config: [String: Any],
        serverName: String,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        guard surface.kind == .mcp,
              surface.toolID == .codexCLI || surface.toolID == .codexDesktop else { return [] }

        var issues: [CompatibilityIssue] = []
        for (key, value) in stringDict(config["env"]).sorted(by: { $0.key < $1.key }) {
            let refs = envExpansionTemplateNames(in: value, includeFallbacks: true)
            guard !refs.isEmpty else { continue }
            issues.append(issue(
                .serverEnvMissing,
                .warning,
                surface,
                "Codex env template is literal",
                "\"\(serverName)\" sets env.\(key) to \(value), but Codex MCP env values are literal strings; \(refs.joined(separator: ", ")) will not be substituted by the Codex config loader.",
                "Use env_vars when the MCP server can read the same environment variable name, or replace this with an explicit value/wrapper script when the variable must be renamed."
            ))
        }

        let headers = stringDict(config["http_headers"]).merging(stringDict(config["headers"])) { current, _ in current }
        for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
            let refs = envExpansionTemplateNames(in: value, includeFallbacks: true)
            guard !refs.isEmpty else { continue }
            issues.append(issue(
                .serverEnvMissing,
                .warning,
                surface,
                "Codex header template is literal",
                "\"\(serverName)\" sets header \(key) to \(value), but Codex MCP http_headers values are literal strings; \(refs.joined(separator: ", ")) will not be substituted by the Codex config loader.",
                "Move environment-backed HTTP headers to env_http_headers, or use bearer_token_env_var for bearer-token auth when supported by the server."
            ))
        }

        return issues
    }

    private static func missingAuthIssue(in config: [String: Any], serverName: String, surface: CompatibilityMatrixEntry) -> CompatibilityIssue? {
        if normalizedHeadersHelper(config["headersHelper"] as? String) != nil {
            return nil
        }

        if let envVar = config["bearer_token_env_var"] as? String, !envVar.isEmpty,
           ProcessInfo.processInfo.environment[envVar]?.isEmpty ?? true {
            return issue(.serverAuthMissing, .error, surface, "Missing bearer token", "\"\(serverName)\" expects token environment variable \(envVar), but it is not set.", "Set \(envVar) before launching the target app or authenticate with the tool's MCP login flow.")
        }

        let env = config["env"] as? [String: Any] ?? [:]
        for (key, value) in env {
            let upper = key.uppercased()
            guard upper.contains("TOKEN") || upper.contains("API_KEY") || upper.contains("SECRET") || upper.contains("PASSWORD") else { continue }
            let text = "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty || looksLikeCredentialPlaceholder(text) {
                return issue(.serverAuthMissing, .error, surface, "Missing credential", "\"\(serverName)\" has placeholder or empty credential \(key).", "Enter the credential through a safe auth flow or environment variable.")
            }
        }

        let headers = stringDict(config["headers"]).merging(stringDict(config["http_headers"])) { current, _ in current }
        for (key, value) in headers where looksLikeCredentialCarrier(key) || looksLikeCredentialPlaceholder(value) {
            let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty || looksLikeCredentialPlaceholder(text) {
                return issue(.serverAuthMissing, .error, surface, "Missing header credential", "\"\(serverName)\" has a placeholder or empty credential in header \(key).", "Complete OAuth/login or configure this header through a secure environment variable.")
            }
        }

        if let oauthProvider = hostedOAuthMCPProvider(in: config),
           headers.isEmpty,
           stringDict(config["env_http_headers"]).isEmpty,
           (config["bearer_token_env_var"] as? String)?.isEmpty ?? true,
           oauthConfig(config["oauth"]) == nil {
            return issue(
                .serverOAuthNeeded,
                .warning,
                surface,
                "Hosted MCP OAuth required",
                "\"\(serverName)\" points at \(oauthProvider)'s hosted MCP endpoint, which uses browser/OAuth login by default.",
                "Use the target tool's MCP login flow, then restart or verify the connection. For CI-only use, configure an environment-backed Authorization header instead."
            )
        }

        let args = stringArray(config["args"])
        for (index, arg) in args.enumerated() {
            if looksLikeCredentialArgumentPlaceholder(arg) {
                return issue(.serverAuthMissing, .error, surface, "Missing launch credential", "\"\(serverName)\" has a placeholder credential in its launch arguments.", "Replace placeholder arguments with an environment-backed credential or use the target tool's auth flow.")
            }
            if looksLikeCredentialFlag(arg),
               index + 1 < args.count,
               looksLikeCredentialPlaceholder(args[index + 1]) {
                return issue(.serverAuthMissing, .error, surface, "Missing launch credential", "\"\(serverName)\" has a placeholder value after \(arg).", "Replace placeholder arguments with an environment-backed credential or use the target tool's auth flow.")
            }
        }

        if let scopes = oauthScopes(in: config), !scopes.isEmpty, surface.supportsOAuth, oauthConfig(config["oauth"]) == nil {
            return issue(.serverOAuthNeeded, .warning, surface, "OAuth may be required", "\"\(serverName)\" declares OAuth scopes: \(scopes.joined(separator: ", ")).", "Offer the tool-specific login action and verify after the browser flow completes.")
        }

        return nil
    }

    private static func oauthConfig(_ value: Any?) -> [String: Any]? {
        guard let dict = value as? [String: Any],
              dict.contains(where: { key, value in
                  let text = "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)
                  return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      && !isOAuthHintOnlyKey(key)
                      && !text.isEmpty
                      && !looksLikeCredentialPlaceholder(text)
              }) else {
            return nil
        }
        return dict
    }

    private static func oauthMetadata(_ value: Any?) -> [String: String] {
        guard let dict = oauthConfig(value) else { return [:] }
        return Dictionary(uniqueKeysWithValues: dict.compactMap { key, value in
            let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedValue = "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedKey.isEmpty,
                  !normalizedValue.isEmpty,
                  !looksLikeCredentialPlaceholder(normalizedValue) else { return nil }
            return (normalizedKey, normalizedValue)
        })
    }

    private static func isOAuthHintOnlyKey(_ key: String) -> Bool {
        let normalized = key
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
        return normalized == "callbackport"
            || normalized == "callbackurl"
            || normalized == "redirecturi"
            || normalized == "scopes"
            || normalized == "scope"
    }

    private static func oauthScopes(in config: [String: Any]) -> [String]? {
        if let scopes = config["scopes"] as? [String], !scopes.isEmpty {
            return scopes
        }
        guard let oauth = config["oauth"] as? [String: Any] else { return nil }
        if let scopes = oauth["scopes"] as? [String], !scopes.isEmpty {
            return scopes
        }
        if let scalar = oauth["scopes"] as? String {
            let scopes = scalar
                .split { $0 == "," || $0 == " " || $0 == "\t" || $0 == "\n" }
                .map(String.init)
                .filter { !$0.isEmpty }
            return scopes.isEmpty ? nil : scopes
        }
        return nil
    }

    private static func normalizedHeadersHelper(_ value: String?) -> String? {
        guard let helper = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !helper.isEmpty else { return nil }
        return helper
    }

    private static func looksLikeCredentialCarrier(_ key: String) -> Bool {
        let upper = key.uppercased()
        return upper.contains("AUTH")
            || upper.contains("TOKEN")
            || upper.contains("API_KEY")
            || upper.contains("SECRET")
            || upper.contains("PASSWORD")
    }

    private static func hostedOAuthMCPProvider(in config: [String: Any]) -> String? {
        guard let urlString = config["url"] as? String,
              let url = URL(string: urlString),
              let host = url.host?.lowercased() else { return nil }
        let transport = (config["type"] as? String)?.lowercased()
        guard transport == nil || ["http", "https", "remote", "streamable_http", "streamable-http", "streamablehttp"].contains(transport ?? "") else {
            return nil
        }
        if host == "mcp.supabase.com" { return "Supabase" }
        if host == "api.githubcopilot.com" { return "GitHub" }
        if host == "mcp.notion.com" { return "Notion" }
        if host == "mcp.atlassian.com" { return "Atlassian" }
        return nil
    }

    private static func looksLikeCredentialFlag(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.contains("token")
            || lower.contains("api-key")
            || lower.contains("apikey")
            || lower.contains("secret")
            || lower.contains("password")
    }

    private static func looksLikeCredentialPlaceholder(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = trimmed.uppercased()
        return trimmed.isEmpty
            || upper.contains("YOUR_")
            || upper.contains("YOUR-")
            || upper.contains("REPLACE_ME")
            || upper.contains("<TOKEN>")
            || upper.contains("<API")
            || upper.contains("...")
            || upper == "TOKEN"
            || upper == "API_KEY"
            || upper == "SECRET"
            || upper == "PASSWORD"
    }

    private static func looksLikeCredentialArgumentPlaceholder(_ value: String) -> Bool {
        let upper = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return looksLikeCredentialPlaceholder(value)
            && (upper.contains("TOKEN")
                || upper.contains("API")
                || upper.contains("SECRET")
                || upper.contains("PASSWORD")
                || upper.contains("KEY")
                || upper.contains("YOUR_")
                || upper.contains("REPLACE_ME")
                || upper.contains("<"))
    }

    private struct ClaudeDesktopLogFinding {
        let code: CompatibilityIssueCode
        let severity: CompatibilityIssueSeverity
        let title: String
        let detail: String
        let fixHint: String
    }

    private static func inspectClaudeDesktopLog(
        _ server: CompatibilityServerObservation,
        surface: CompatibilityMatrixEntry
    ) -> [CompatibilityIssue] {
        guard surface.toolID == .claudeDesktop,
              let logPath = claudeDesktopLogPath(for: server.name),
              let finding = claudeDesktopLogFinding(path: logPath) else { return [] }

        return [
            CompatibilityIssue(
                id: UUID(),
                code: finding.code,
                severity: finding.severity,
                toolID: surface.toolID,
                surfaceID: surface.id,
                title: finding.title,
                detail: "\(finding.detail) Log: \(tilde(logPath)).",
                path: logPath,
                subjectPath: server.path,
                fixHint: finding.fixHint
            )
        ]
    }

    private static func claudeDesktopLogPath(for serverName: String) -> String? {
        let logsDir = claudeDesktopLogsDirectory()
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: logsDir) else { return nil }
        let wanted = normalizedLogName(serverName)
        let candidates = entries.compactMap { entry -> (path: String, modified: Date)? in
            guard entry.hasPrefix("mcp-server-"), entry.hasSuffix(".log") else { return nil }
            let rawName = String(entry.dropFirst("mcp-server-".count).dropLast(".log".count))
            guard rawName.localizedCaseInsensitiveCompare(serverName) == .orderedSame
                    || normalizedLogName(rawName) == wanted else { return nil }
            let path = (logsDir as NSString).appendingPathComponent(entry)
            let modified = (try? fm.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? .distantPast
            return (path, modified)
        }
        return candidates.sorted { $0.modified > $1.modified }.first?.path
    }

    private static func claudeDesktopLogsDirectory() -> String {
        if let override = ProcessInfo.processInfo.environment["PROJECTHUB_CLAUDE_DESKTOP_LOGS_DIR"],
           !override.isEmpty {
            return (override as NSString).expandingTildeInPath
        }
        return (NSHomeDirectory() as NSString).appendingPathComponent("Library/Logs/Claude")
    }

    private static func normalizedLogName(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func claudeDesktopLogFinding(path: String) -> ClaudeDesktopLogFinding? {
        let fm = FileManager.default
        guard let modified = try? fm.attributesOfItem(atPath: path)[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) < 14 * 24 * 60 * 60,
              let tail = readTail(path: path, maxBytes: 64 * 1024)
        else { return nil }

        let lines = tail.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        for line in lines.reversed() {
            let lower = line.lowercased()
            if isClaudeDesktopLogSuccess(lower) {
                return nil
            }
            if isExpiredAuthSignal(lower) {
                return ClaudeDesktopLogFinding(
                    code: .serverAuthExpired,
                    severity: .warning,
                    title: "Claude Desktop log indicates auth expired",
                    detail: "The latest recent MCP log signal suggests the server's login or token expired. \(redactedLogExcerpt(line))",
                    fixHint: "Refresh the vendor login/OAuth token in Claude Desktop, restart Claude Desktop if needed, then rescan."
                )
            }
            if lower.contains("please authorize")
                || lower.contains("authentication required")
                || lower.contains("waiting for authorization")
                || lower.contains("unauthorized")
                || lower.contains("invalid_token")
                || lower.contains("access token")
                || lower.contains("api key")
                || lower.contains(" 401")
                || lower.contains(" 403") {
                return ClaudeDesktopLogFinding(
                    code: .serverOAuthNeeded,
                    severity: .warning,
                    title: "Claude Desktop log indicates auth is needed",
                    detail: "The latest recent MCP log signal suggests the server needs login or credentials. \(redactedLogExcerpt(line))",
                    fixHint: "Open Claude Desktop and complete the connector or browser OAuth flow, then rescan."
                )
            }
            if lower.contains("enoent")
                || lower.contains("command not found")
                || lower.contains("no such file or directory")
                || lower.contains("cannot find module")
                || lower.contains("module_not_found") {
                return ClaudeDesktopLogFinding(
                    code: .serverCommandMissing,
                    severity: .error,
                    title: "Claude Desktop log indicates a missing runtime",
                    detail: "The latest recent MCP log signal suggests the server command, module, or path cannot be found. \(redactedLogExcerpt(line))",
                    fixHint: "Install the missing runtime/package or update the MCP command path, then restart Claude Desktop."
                )
            }
            if lower.contains("request timed out")
                || lower.contains("mcp error -32001")
                || lower.contains("timed out") {
                return ClaudeDesktopLogFinding(
                    code: .serverHealthUnknown,
                    severity: .warning,
                    title: "Claude Desktop log shows MCP timeout",
                    detail: "The latest recent MCP log signal shows a timeout while Claude Desktop was communicating with this server. \(redactedLogExcerpt(line))",
                    fixHint: "Check the server's auth state and startup latency from Claude Desktop, then retry after the server responds normally."
                )
            }
            if lower.contains("internal server error")
                || lower.contains("code: 500")
                || lower.contains("http 500")
                || lower.contains("streamablehttperror") {
                return ClaudeDesktopLogFinding(
                    code: .serverHealthUnknown,
                    severity: .warning,
                    title: "Claude Desktop log shows remote server error",
                    detail: "The latest recent MCP log signal shows an upstream or remote MCP error. \(redactedLogExcerpt(line))",
                    fixHint: "Retry after checking the remote MCP service status, credentials, and endpoint URL."
                )
            }
            if lower.contains("initialize error")
                || lower.contains("tools/list error")
                || lower.contains("invalid_request")
                || lower.contains("unsupported protocol") {
                return ClaudeDesktopLogFinding(
                    code: .serverHealthUnknown,
                    severity: .warning,
                    title: "Claude Desktop log shows MCP protocol trouble",
                    detail: "The latest recent MCP log signal suggests initialize or tools/list did not complete cleanly. \(redactedLogExcerpt(line))",
                    fixHint: "Check the server's MCP protocol support and update the package or endpoint if needed."
                )
            }
        }
        return nil
    }

    private static func isExpiredAuthSignal(_ lowercasedLine: String) -> Bool {
        let explicitSignals = [
            "invalid_grant",
            "reauth",
            "re-auth",
            "relogin",
            "re-login",
            "sign in again",
            "login again"
        ]
        if explicitSignals.contains(where: lowercasedLine.contains) {
            return true
        }
        guard lowercasedLine.contains("expired") else { return false }
        let authWords = ["token", "credential", "auth", "oauth", "login", "session"]
        return authWords.contains(where: lowercasedLine.contains)
    }

    private static func isClaudeDesktopLogSuccess(_ lowercasedLine: String) -> Bool {
        lowercasedLine.contains("server started and connected successfully")
            || (lowercasedLine.contains("message from server") && lowercasedLine.contains("\"result\""))
            || lowercasedLine.contains("\"method\":\"tools/list\"")
    }

    private static func readTail(path: String, maxBytes: UInt64) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let end = (try? handle.seekToEnd()) ?? 0
        let offset = end > maxBytes ? end - maxBytes : 0
        try? handle.seek(toOffset: offset)
        let data = handle.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private static func redactedLogExcerpt(_ line: String) -> String {
        var text = line
        text = text.replacingOccurrences(
            of: #"https?://\S+"#,
            with: "<url>",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
            with: "<email>",
            options: [.regularExpression, .caseInsensitive]
        )
        text = text.replacingOccurrences(
            of: #"(token|secret|api[_-]?key|client[_-]?secret)=\S+"#,
            with: "$1=<redacted>",
            options: [.regularExpression, .caseInsensitive]
        )
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 180 {
            return "Recent line: \(trimmed.prefix(180))..."
        }
        return "Recent line: \(trimmed)"
    }

    private static func claudeLocalProjectRoot(from surface: CompatibilityMatrixEntry) -> String? {
        let pieces = surface.id.split(separator: "|", maxSplits: 1).map(String.init)
        guard pieces.count == 2 else { return nil }
        return pieces[1]
    }

    private static func stringArray(_ value: Any?) -> [String] {
        if let strings = value as? [String] { return strings }
        if let any = value as? [Any] {
            return any.compactMap { $0 as? String }
        }
        return []
    }

    private static func stringArrayOrSingle(_ value: Any?) -> [String] {
        if let string = value as? String { return [string] }
        return stringArray(value)
    }

    private static func toolApprovalModes(from config: [String: Any]) -> [String: String] {
        var modes: [String: String] = [:]
        if let tools = config["tools"] as? [String: Any] {
            for (tool, raw) in tools {
                if let dict = raw as? [String: Any],
                   let mode = dict["approval_mode"] as? String ?? dict["approvalMode"] as? String {
                    modes[tool] = mode
                }
            }
        }
        for (key, raw) in config where key.hasPrefix("tools.") {
            let parts = key.split(separator: ".").map(String.init)
            if parts.count == 2,
               let dict = raw as? [String: Any],
               let mode = dict["approval_mode"] as? String ?? dict["approvalMode"] as? String {
                modes[parts[1]] = mode
            } else if parts.count >= 3,
                      parts.last == "approval_mode" || parts.last == "approvalMode",
                      let mode = raw as? String {
                modes[parts.dropFirst().dropLast().joined(separator: ".")] = mode
            }
        }
        if let flat = config["toolApprovalModes"] as? [String: String] {
            modes.merge(flat) { _, new in new }
        }
        return modes.filter { !$0.key.isEmpty && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func codexLocalEnvVars(_ value: Any?) -> [String] {
        if let strings = value as? [String] { return strings }
        if let any = value as? [Any] {
            return any.compactMap { item in
                if let string = item as? String { return string }
                if let entry = item as? [String: Any],
                   let name = entry["name"] as? String,
                   (entry["source"] as? String ?? "local") == "local" {
                    return name
                }
                return nil
            }
        }
        return []
    }

    private static func codexStartupTimeoutSeconds(from config: [String: Any]) -> TimeInterval? {
        if let seconds = codexNumber(config["startup_timeout_sec"]) {
            return seconds
        }
        if let milliseconds = codexNumber(config["startup_timeout_ms"]) {
            return milliseconds / 1_000
        }
        return nil
    }

    private static func codexNumber(_ value: Any?) -> TimeInterval? {
        if let double = value as? Double, double > 0 { return double }
        if let int = value as? Int, int > 0 { return TimeInterval(int) }
        if let string = value as? String {
            let normalized = string
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "_", with: "")
            if let double = Double(normalized), double > 0 {
                return double
            }
        }
        return nil
    }

    private static func stringDict(_ value: Any?) -> [String: String] {
        guard let dict = value as? [String: Any] else { return [:] }
        return Dictionary(uniqueKeysWithValues: dict.map { ($0.key, "\($0.value)") })
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let bool = value as? Bool { return bool }
        if let string = value as? String {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        return nil
    }

    private static func configSummary(_ value: Any?) -> String? {
        switch value {
        case let dict as [String: Any]:
            let keys = dict.keys.sorted()
            return keys.isEmpty ? "{}" : "{\(keys.joined(separator: ", "))}"
        case let array as [Any]:
            return "[\(array.count) values]"
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let bool as Bool:
            return bool ? "true" : "false"
        case let number as NSNumber:
            return "\(number)"
        case .some(let raw):
            return "\(raw)"
        case .none:
            return nil
        }
    }

    private static func containsExpiredTimestamp(_ value: Any) -> Bool {
        if let dict = value as? [String: Any] {
            for (key, nested) in dict {
                let lower = key.lowercased()
                if lower.contains("expires") || lower.contains("expiration") || lower == "exp" {
                    if !isRelativeExpirationDurationKey(key),
                       timestampIsPast(nested) {
                        return true
                    }
                }
                if containsExpiredTimestamp(nested) { return true }
            }
        } else if let array = value as? [Any] {
            return array.contains(where: containsExpiredTimestamp)
        }
        return false
    }

    private static func placeholderCredentialPath(in value: Any, path: [String] = []) -> String? {
        if let dict = value as? [String: Any] {
            for key in dict.keys.sorted() {
                guard let nested = dict[key] else { continue }
                let nextPath = path + [key]
                if isCredentialFieldName(key),
                   let string = nested as? String,
                   looksLikeCredentialPlaceholder(string) {
                    return nextPath.joined(separator: ".")
                }
                if let match = placeholderCredentialPath(in: nested, path: nextPath) {
                    return match
                }
            }
        } else if let array = value as? [Any] {
            for (index, nested) in array.enumerated() {
                if let match = placeholderCredentialPath(in: nested, path: path + ["[\(index)]"]) {
                    return match
                }
            }
        }
        return nil
    }

    private static func credentialEvidencePath(in value: Any, path: [String] = []) -> String? {
        if let dict = value as? [String: Any] {
            for key in dict.keys.sorted() {
                guard let nested = dict[key] else { continue }
                let nextPath = path + [key]
                if isAuthEvidenceFieldName(key),
                   valueLooksCredentialLike(nested) {
                    return nextPath.joined(separator: ".")
                }
                if let match = credentialEvidencePath(in: nested, path: nextPath) {
                    return match
                }
            }
        } else if let array = value as? [Any] {
            for (index, nested) in array.enumerated() {
                if let match = credentialEvidencePath(in: nested, path: path + ["[\(index)]"]) {
                    return match
                }
            }
        }
        return nil
    }

    private static func isRelativeExpirationDurationKey(_ key: String) -> Bool {
        let normalized = key
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
        return normalized == "expiresin" || normalized.hasSuffix("expiresin")
    }

    private static func isCredentialFieldName(_ key: String) -> Bool {
        let normalized = key
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
        return normalized.contains("token")
            || normalized.contains("apikey")
            || normalized.contains("secret")
            || normalized.contains("password")
            || normalized.contains("credential")
            || normalized.contains("authorization")
            || normalized.contains("bearer")
    }

    private static func isAuthEvidenceFieldName(_ key: String) -> Bool {
        let normalized = key
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
        return isCredentialFieldName(key)
            || normalized.contains("oauth")
            || normalized.contains("session")
            || normalized == "claudeai"
    }

    private static func valueLooksCredentialLike(_ value: Any) -> Bool {
        if let string = value as? String {
            return !looksLikeCredentialPlaceholder(string)
        }
        if value is NSNumber || value is Bool {
            return true
        }
        return false
    }

    private static func timestampIsPast(_ value: Any) -> Bool {
        let now = Date()
        if let seconds = value as? TimeInterval {
            let normalized = seconds > 9_999_999_999 ? seconds / 1000 : seconds
            return Date(timeIntervalSince1970: normalized) < now
        }
        if let int = value as? Int {
            return timestampIsPast(TimeInterval(int))
        }
        if let string = value as? String {
            if let number = TimeInterval(string) {
                return timestampIsPast(number)
            }
            let iso = ISO8601DateFormatter()
            if let date = iso.date(from: string) {
                return date < now
            }
        }
        return false
    }

    private static func fingerprint(_ config: [String: Any]) -> String {
        canonicalString(config)
    }

    private static func canonicalString(_ value: Any) -> String {
        if let dict = value as? [String: Any] {
            return "{" + dict.keys.sorted().map { "\($0):\(canonicalString(dict[$0] ?? ""))" }.joined(separator: ",") + "}"
        }
        if let array = value as? [Any] {
            return "[" + array.map(canonicalString).joined(separator: ",") + "]"
        }
        return "\(value)"
    }
}

// MARK: - Lightweight TOML reader for Codex MCP sections

private func parseMCPServersTOML(_ text: String) -> (servers: [String: [String: Any]], invalid: Bool) {
    var result: [String: [String: Any]] = [:]
    var currentName: String?
    var currentSubtable: String?
    var invalid = false

    func ensureServer(_ name: String) {
        if result[name] == nil { result[name] = [:] }
    }

    let lines = text.components(separatedBy: .newlines)
    var index = 0
    while index < lines.count {
        let rawLine = lines[index]
        index += 1
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") { continue }

        if line.hasPrefix("[") {
            currentName = nil
            currentSubtable = nil
            let sectionLine = splitTOMLValueAndComment(line).value
                .trimmingCharacters(in: .whitespaces)
            guard sectionLine.hasSuffix("]"), !sectionLine.hasPrefix("[[") else { continue }
            let inner = String(sectionLine.dropFirst().dropLast())
            let segments = tomlSectionSegments(inner)
            guard segments.first == "mcp_servers" else { continue }
            guard segments.count >= 2, !segments[1].isEmpty else {
                invalid = true
                continue
            }
            currentName = segments[1]
            currentSubtable = segments.count > 2 ? segments.dropFirst(2).joined(separator: ".") : nil
            ensureServer(currentName!)
            continue
        }

        guard let name = currentName else { continue }
        guard let eq = line.firstIndex(of: "=") else {
            invalid = true
            continue
        }

        let key = line[..<eq].trimmingCharacters(in: .whitespaces)
        var rawValue = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
        while tomlValueStartsCollection(rawValue),
              !tomlCollectionIsComplete(rawValue),
              index < lines.count {
            rawValue += "\n" + lines[index].trimmingCharacters(in: .whitespaces)
            index += 1
        }
        guard let value = parseTOMLValue(rawValue) else {
            invalid = true
            continue
        }

        if let subtable = currentSubtable {
            var nested = result[name]?[subtable] as? [String: Any] ?? [:]
            nested[key] = value
            result[name]?[subtable] = nested
        } else {
            result[name]?[key] = value
        }
    }

    return (result, invalid)
}

private func tomlSectionSegments(_ section: String) -> [String] {
    var segments: [String] = []
    var current = ""
    var inSingle = false
    var inDouble = false
    var escaped = false

    func appendSegment() {
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            segments.append(parseTOMLStringLiteral(trimmed) ?? trimmed)
        }
        current = ""
    }

    for ch in section {
        if escaped {
            current.append(ch)
            escaped = false
            continue
        }
        if inDouble && ch == "\\" {
            current.append(ch)
            escaped = true
            continue
        }
        if ch == "\"", !inSingle {
            current.append(ch)
            inDouble.toggle()
            continue
        }
        if ch == "'", !inDouble {
            current.append(ch)
            inSingle.toggle()
            continue
        }
        if ch == ".", !inSingle, !inDouble {
            appendSegment()
        } else {
            current.append(ch)
        }
    }
    appendSegment()
    return segments
}

private func tomlValueStartsCollection(_ raw: String) -> Bool {
    let value = splitTOMLValueAndComment(raw).value.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.hasPrefix("[") || value.hasPrefix("{")
}

private func tomlCollectionIsComplete(_ raw: String) -> Bool {
    var inSingle = false
    var inDouble = false
    var escaped = false
    var bracketDepth = 0
    var braceDepth = 0

    for ch in splitTOMLValueAndComment(raw).value {
        if escaped {
            escaped = false
            continue
        }
        if inDouble && ch == "\\" {
            escaped = true
            continue
        }
        if ch == "\"", !inSingle {
            inDouble.toggle()
            continue
        }
        if ch == "'", !inDouble {
            inSingle.toggle()
            continue
        }
        guard !inSingle, !inDouble else { continue }
        if ch == "[" { bracketDepth += 1 }
        if ch == "]", bracketDepth > 0 { bracketDepth -= 1 }
        if ch == "{" { braceDepth += 1 }
        if ch == "}", braceDepth > 0 { braceDepth -= 1 }
    }

    return bracketDepth == 0 && braceDepth == 0 && !inSingle && !inDouble
}

private func parseCodexSkillConfigTOML(_ text: String) -> [(path: String, enabled: Bool)] {
    var result: [(path: String, enabled: Bool)] = []
    var current: [String: Any]?

    func flush() {
        guard let item = current,
              let path = item["path"] as? String,
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            current = nil
            return
        }
        result.append((path: path, enabled: (item["enabled"] as? Bool) ?? true))
        current = nil
    }

    for rawLine in text.components(separatedBy: .newlines) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") { continue }

        if line.hasPrefix("[[") {
            flush()
            current = isCodexSkillConfigArrayTable(line) ? [:] : nil
            continue
        }

        guard current != nil, let eq = line.firstIndex(of: "=") else { continue }
        let key = line[..<eq].trimmingCharacters(in: .whitespaces)
        let rawValue = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
        if key == "path", let value = parseTOMLValue(rawValue) as? String {
            current?["path"] = value
        } else if key == "enabled", let value = parseTOMLValue(rawValue) as? Bool {
            current?["enabled"] = value
        }
    }
    flush()

    return result
}

private func isCodexSkillConfigArrayTable(_ line: String) -> Bool {
    let sectionLine = splitTOMLValueAndComment(line).value
        .trimmingCharacters(in: .whitespaces)
    guard sectionLine.hasPrefix("[["),
          sectionLine.hasSuffix("]]") else { return false }
    let inner = String(sectionLine.dropFirst(2).dropLast(2))
    return tomlSectionSegments(inner) == ["skills", "config"]
}

private func parseTOMLValue(_ raw: String) -> Any? {
    let valueAndComment = splitTOMLValueAndComment(raw)
    let trimmed = valueAndComment.value.trimmingCharacters(in: .whitespaces)
    if trimmed == "true" { return true }
    if trimmed == "false" { return false }
    if let int = parseTOMLIntLiteral(trimmed) { return int }
    if let double = Double(trimmed.replacingOccurrences(of: "_", with: "")), double.isFinite {
        return double
    }
    if let string = parseTOMLStringLiteral(trimmed) { return string }
    if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
        let inner = trimmed.dropFirst().dropLast()
        if inner.trimmingCharacters(in: .whitespaces).isEmpty { return [Any]() }
        return splitTOMLArray(String(inner)).map { item -> Any in
            let trimmedItem = item.trimmingCharacters(in: .whitespaces)
            return parseTOMLValue(trimmedItem) ?? trimmedItem
        }
    }
    if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
        return parseTOMLInlineTable(String(trimmed))
    }
    if !trimmed.isEmpty { return trimmed }
    return nil
}

private func parseTOMLStringArrayLiteral(_ raw: String) -> [String]? {
    let valueAndComment = splitTOMLValueAndComment(raw)
    let trimmed = valueAndComment.value.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("["),
          trimmed.hasSuffix("]") else { return nil }
    let inner = String(trimmed.dropFirst().dropLast())
    if inner.trimmingCharacters(in: .whitespaces).isEmpty { return [] }
    var values: [String] = []
    for item in splitTOMLArray(inner) {
        guard let value = parseTOMLStringLiteral(item.trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        values.append(value)
    }
    return values
}

private func splitTOMLValueAndComment(_ text: String) -> (value: String, comment: String) {
    var inSingle = false
    var inDouble = false
    var escaped = false
    for (offset, char) in text.enumerated() {
        if escaped {
            escaped = false
            continue
        }
        if inDouble && char == "\\" {
            escaped = true
            continue
        }
        if char == "\"" && !inSingle {
            inDouble.toggle()
            continue
        }
        if char == "'" && !inDouble {
            inSingle.toggle()
            continue
        }
        if char == "#" && !inSingle && !inDouble {
            let index = text.index(text.startIndex, offsetBy: offset)
            return (String(text[..<index]), String(text[index...]))
        }
    }
    return (text, "")
}

private func parseTOMLStringLiteral(_ text: String) -> String? {
    if text.hasPrefix("\""), text.hasSuffix("\""), text.count >= 2 {
        var value = ""
        var escaped = false
        for char in text.dropFirst().dropLast() {
            if escaped {
                switch char {
                case "n": value.append("\n")
                case "t": value.append("\t")
                case "\"": value.append("\"")
                case "\\": value.append("\\")
                default: value.append(char)
                }
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else {
                value.append(char)
            }
        }
        return escaped ? nil : value
    }
    if text.hasPrefix("'"), text.hasSuffix("'"), text.count >= 2 {
        return String(text.dropFirst().dropLast())
    }
    return nil
}

private func parseTOMLIntLiteral(_ text: String) -> Int? {
    let normalized = text
        .trimmingCharacters(in: .whitespaces)
        .replacingOccurrences(of: "_", with: "")
    guard !normalized.isEmpty else { return nil }
    return Int(normalized)
}

private func parseTOMLInlineTable(_ raw: String) -> [String: Any] {
    let inner = String(raw.dropFirst().dropLast())
    var out: [String: Any] = [:]
    for item in splitTOMLArray(inner) {
        guard let eq = item.firstIndex(of: "=") else { continue }
        let key = item[..<eq]
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        let rawValue = item[item.index(after: eq)...].trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, let value = parseTOMLValue(rawValue) else { continue }
        out[key] = value
    }
    return out
}

private func splitTOMLArray(_ text: String) -> [String] {
    var items: [String] = []
    var current = ""
    var inSingle = false
    var inDouble = false
    var squareDepth = 0
    var braceDepth = 0

    for ch in text {
        if ch == "'", !inDouble { inSingle.toggle(); current.append(ch); continue }
        if ch == "\"", !inSingle { inDouble.toggle(); current.append(ch); continue }
        if !inSingle, !inDouble {
            if ch == "[" {
                squareDepth += 1
                current.append(ch)
                continue
            }
            if ch == "]", squareDepth > 0 {
                squareDepth -= 1
                current.append(ch)
                continue
            }
            if ch == "{" {
                braceDepth += 1
                current.append(ch)
                continue
            }
            if ch == "}", braceDepth > 0 {
                braceDepth -= 1
                current.append(ch)
                continue
            }
        }
        if ch == ",", !inSingle, !inDouble, squareDepth == 0, braceDepth == 0 {
            items.append(current)
            current = ""
            continue
        }
        current.append(ch)
    }
    if !current.isEmpty { items.append(current) }
    return items
}
