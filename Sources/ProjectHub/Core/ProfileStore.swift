import Foundation

// MARK: - Profile model

struct HubProfile: Codable, Identifiable {
    static let currentSchemaVersion = 1

    var id: String { name }
    var name: String
    let scope: String
    let savedAt: Date
    let skills: [SkillEntry]
    let agents: [FileEntry]
    let mcpServers: [MCPEntry]
    let hooks: [HookRecord]
    let commands: [FileEntry]

    struct SkillEntry: Codable {
        let name: String
        let path: String
        /// Set for a global entry that is a symlink, so a removed link can be rebuilt.
        let resolvedPath: String?
    }

    struct FileEntry: Codable {
        let name: String
        let path: String
        let content: String
    }

    struct MCPEntry: Codable {
        let toolID: String
        let name: String
        let config: Data
    }

    struct HookRecord: Codable {
        let tool: String
        let event: String
        let matcher: String?
        let command: String
    }
}

struct ProfileRestoreReport {
    let applied: Int
    let skipped: Int
    let errors: [String]
}

// MARK: - Profile store

enum ProfileStore {
    static let globalScope = "global"
    static var directoryOverride: URL?

    static func list() -> [HubProfile] {
        loadProfiles().sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    @discardableResult
    static func save(name: String) -> HubProfile? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let profile = capture(name: trimmed)
        var profiles = loadProfiles().filter { $0.name.caseInsensitiveCompare(trimmed) != .orderedSame }
        profiles.append(profile)
        write(profiles)
        return profile
    }

    static func delete(name: String) {
        write(loadProfiles().filter { $0.name != name })
    }

    @discardableResult
    static func rename(from: String, to: String) -> Bool {
        let trimmed = to.trimmingCharacters(in: .whitespacesAndNewlines)
        var profiles = loadProfiles()
        guard !trimmed.isEmpty,
              let index = profiles.firstIndex(where: { $0.name == from }),
              !profiles.contains(where: {
                  $0.name != from && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
              })
        else { return false }
        profiles[index].name = trimmed
        write(profiles)
        return true
    }

    /// Applying a profile only adds what is missing — entries it does not list,
    /// and entries already present, are left exactly as they are.
    static func restore(_ profile: HubProfile) -> ProfileRestoreReport {
        var applied = 0
        var skipped = 0
        var errors: [String] = []

        for entry in profile.skills {
            restoreSkill(entry, applied: &applied, skipped: &skipped, errors: &errors)
        }
        for entry in profile.agents {
            restoreFile(entry, label: "Agent", applied: &applied, skipped: &skipped, errors: &errors)
        }
        for entry in profile.commands {
            restoreFile(entry, label: "Command", applied: &applied, skipped: &skipped, errors: &errors)
        }
        restoreMCPServers(profile.mcpServers, applied: &applied, skipped: &skipped, errors: &errors)
        // Hooks stay recorded only: Project Hub reads hook config, it never writes it.

        return ProfileRestoreReport(applied: applied, skipped: skipped, errors: errors)
    }

    // MARK: - Capture

    private static func capture(name: String) -> HubProfile {
        HubProfile(
            name: name,
            scope: globalScope,
            savedAt: Date(),
            skills: captureSkills(),
            agents: captureAgents(),
            mcpServers: captureMCPServers(),
            hooks: captureHooks(),
            commands: captureCommands()
        )
    }

    private static func captureSkills() -> [HubProfile.SkillEntry] {
        let home = NSHomeDirectory()
        var seenDirectories = Set<String>()
        var seenSkills = Set<String>()
        var entries: [HubProfile.SkillEntry] = []

        for spec in ProviderCatalog.specs(home: home) {
            for directory in spec.globalSkillDirs where seenDirectories.insert(canonicalPath(directory)).inserted {
                for skill in SkillReader.scanSkillDir(directory, source: .providerGlobal) {
                    let resolved = canonicalPath(skill.path)
                    guard seenSkills.insert(resolved).inserted else { continue }
                    entries.append(HubProfile.SkillEntry(
                        name: skill.name,
                        path: skill.path,
                        resolvedPath: resolved == skill.path ? nil : resolved
                    ))
                }
            }
        }

        return entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func captureAgents() -> [HubProfile.FileEntry] {
        AgentReader.agents(for: NSHomeDirectory()).compactMap { agent in
            guard let content = try? String(contentsOfFile: agent.filePath, encoding: .utf8) else { return nil }
            return HubProfile.FileEntry(name: agent.name, path: agent.filePath, content: content)
        }
    }

    private static func captureCommands() -> [HubProfile.FileEntry] {
        CommandsReader.globalCommands().compactMap { command in
            guard let content = try? String(contentsOfFile: command.filePath, encoding: .utf8) else { return nil }
            return HubProfile.FileEntry(name: command.name, path: command.filePath, content: content)
        }
    }

    private static func captureHooks() -> [HubProfile.HookRecord] {
        var seen = Set<String>()
        return HooksReader.hooks(for: NSHomeDirectory())
            .filter { $0.scope == "global" }
            .compactMap { hook in
                let key = "\(hook.tool)\u{1f}\(hook.event)\u{1f}\(hook.matcher ?? "")\u{1f}\(hook.command)"
                guard seen.insert(key).inserted else { return nil }
                return HubProfile.HookRecord(
                    tool: hook.tool,
                    event: hook.event,
                    matcher: hook.matcher,
                    command: hook.command
                )
            }
    }

    private static func captureMCPServers() -> [HubProfile.MCPEntry] {
        var entries: [HubProfile.MCPEntry] = []
        for meta in ALL_TOOL_META {
            guard ToolSpecs.spec(for: meta.id) != nil else { continue }
            for (name, config) in ConfigWriter.readAllServers(toolID: meta.id, scope: .user, projectRoot: nil) {
                if (config["enabled"] as? Bool) == false { continue }
                guard let data = try? JSONSerialization.data(withJSONObject: config, options: [.sortedKeys]) else { continue }
                entries.append(HubProfile.MCPEntry(toolID: meta.id, name: name, config: data))
            }
        }
        return entries.sorted {
            $0.toolID == $1.toolID
                ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                : $0.toolID < $1.toolID
        }
    }

    // MARK: - Restore

    private static func restoreSkill(
        _ entry: HubProfile.SkillEntry,
        applied: inout Int,
        skipped: inout Int,
        errors: inout [String]
    ) {
        let fm = FileManager.default
        if fm.fileExists(atPath: entry.path) {
            skipped += 1
            return
        }
        guard let resolvedPath = entry.resolvedPath, fm.fileExists(atPath: resolvedPath) else {
            errors.append("Skill \(entry.name): saved origin is gone (\(entry.path))")
            return
        }
        do {
            try fm.createDirectory(
                atPath: (entry.path as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )
            if (try? fm.destinationOfSymbolicLink(atPath: entry.path)) != nil {
                try fm.removeItem(atPath: entry.path)
            }
            do {
                try fm.createSymbolicLink(atPath: entry.path, withDestinationPath: resolvedPath)
            } catch {
                try fm.copyItem(atPath: resolvedPath, toPath: entry.path)
            }
            applied += 1
        } catch {
            errors.append("Skill \(entry.name): \(error.localizedDescription)")
        }
    }

    private static func restoreFile(
        _ entry: HubProfile.FileEntry,
        label: String,
        applied: inout Int,
        skipped: inout Int,
        errors: inout [String]
    ) {
        if FileManager.default.fileExists(atPath: entry.path) {
            skipped += 1
            return
        }
        do {
            try ConfigWriter.writeTextFileIfMissing(path: entry.path, content: entry.content)
            applied += 1
        } catch {
            errors.append("\(label) \(entry.name): \(error.localizedDescription)")
        }
    }

    private static func restoreMCPServers(
        _ entries: [HubProfile.MCPEntry],
        applied: inout Int,
        skipped: inout Int,
        errors: inout [String]
    ) {
        let groups = Dictionary(grouping: entries, by: \.toolID).sorted { $0.key < $1.key }
        for (toolID, toolEntries) in groups {
            var existing: [String: ServerEntry] = [:]
            for entry in ConfigWriter.readAllServerEntries(toolID: toolID, scope: .user, projectRoot: nil) {
                existing[entry.name] = entry
            }

            for entry in toolEntries {
                guard let config = (try? JSONSerialization.jsonObject(with: entry.config)) as? [String: Any] else {
                    errors.append("MCP \(entry.name) (\(toolID)): saved config could not be read")
                    continue
                }
                if let current = existing[entry.name] {
                    if current.isDisabled {
                        do {
                            try ConfigWriter.setServerEnabled(
                                toolID: toolID,
                                scope: .user,
                                projectRoot: nil,
                                name: entry.name,
                                enabled: true
                            )
                        } catch {
                            errors.append("MCP \(entry.name) (\(toolID)): \(error.localizedDescription)")
                            continue
                        }
                    } else if let active = ConfigWriter.readServer(toolID: toolID, name: entry.name),
                              NSDictionary(dictionary: active).isEqual(to: config) {
                        skipped += 1
                        continue
                    }
                }
                do {
                    try ConfigWriter.writeServer(
                        toolID: toolID,
                        scope: .user,
                        projectRoot: nil,
                        name: entry.name,
                        config: config
                    )
                    applied += 1
                } catch {
                    errors.append("MCP \(entry.name) (\(toolID)): \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Persistence

    private struct ProfilesDocument: Codable {
        let schemaVersion: Int
        let profiles: [HubProfile]
    }

    private static var profilesURL: URL {
        profilesDirectory().appendingPathComponent("profiles.json")
    }

    private static func loadProfiles() -> [HubProfile] {
        guard let data = try? Data(contentsOf: profilesURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let document = try? decoder.decode(ProfilesDocument.self, from: data),
              document.schemaVersion == HubProfile.currentSchemaVersion
        else { return [] }
        return document.profiles
    }

    private static func write(_ profiles: [HubProfile]) {
        let url = profilesURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(ProfilesDocument(
            schemaVersion: HubProfile.currentSchemaVersion,
            profiles: profiles
        )) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func profilesDirectory() -> URL {
        if let directoryOverride { return directoryOverride }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("ProjectHub", isDirectory: true)
    }

    private static func canonicalPath(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }
}
