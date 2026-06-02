import Foundation

// MARK: - Parses pasted MCP server JSON into a preview list.

struct ImportCredentialRequirement: Equatable {
    enum Kind: String, Equatable {
        case env
        case header
        case urlVariable
    }

    let kind: Kind
    let name: String
    let envName: String?
    let placeholder: String?
    let required: Bool
    let secret: Bool
    let description: String?
    let source: String
}

struct ParsedServer: Identifiable {
    let id = UUID()
    var name: String            // user-editable
    let config: [String: Any]
    var credentialRequirements: [ImportCredentialRequirement] = []

    var kindLabel: String {
        if config["url"] is String { return "Remote" }
        if let command = config["command"] as? String {
            switch command {
            case "npx", "npm", "pnpm", "yarn", "bunx", "bun":
                return "npm"
            case "uvx", "uv", "python", "python3", "pipx":
                return "Python"
            case "docker":
                return "Docker"
            default:
                break
            }
        }
        return "Local"
    }

    var preview: String {
        if let url = config["url"] as? String { return url }
        let cmd  = (config["command"] as? String) ?? ""
        let args = (config["args"]    as? [String]) ?? []
        return ([cmd] + args).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
}

struct DesktopExtensionArchivePreview: Identifiable {
    let id = UUID()
    let filePath: String
    let manifestPath: String
    let name: String
    let displayName: String
    let version: String?
    let description: String?
    let author: String?
    let commandPreview: String?
    let toolNames: [String]
    let requiredUserConfig: [String]
}

struct SourceArchiveImportPreview: Identifiable {
    let id = UUID()
    let filePath: String
    let sourcePath: String
    let servers: [ParsedServer]
    let scannedPaths: [String]
    var choices: [ParsedImportChoice] = []
    var interactiveInstaller: InteractiveInstallerCandidate? = nil
}

struct ParsedImportChoice: Identifiable {
    let id = UUID()
    let label: String
    let source: String
    let rawText: String
    let servers: [ParsedServer]
    var archiveURL: URL? = nil
    var archiveSHA256: String? = nil
}

struct InteractiveInstallerCandidate: Equatable {
    let rawCommand: String
    let source: String
    let runtime: String
    let detectedTool: String?
    let summary: String
}

struct GitHubContentCandidate: Equatable {
    let url: URL
    let path: String
    let note: String
}

struct GitHubContentFetch: Equatable {
    let candidates: [GitHubContentCandidate]
    var discoveries: [GitHubContentDiscovery] = []
    var registryLookup: GitHubRegistryLookup?
}

struct GitHubContentDiscovery: Equatable {
    let url: URL
    let owner: String
    let repo: String
    let ref: String
    let prefix: String
}

struct GitHubRegistryLookup: Equatable {
    let owner: String
    let repo: String
    let allowAnySubfolder: Bool
    let acceptableSubfolders: [String]
    let firstPageURL: URL
}

struct GitHubRegistryPageRequest: Equatable {
    let lookup: GitHubRegistryLookup
    let url: URL
    let page: Int
    let cursor: String?
}

struct GitHubContentFetchAttempt {
    let candidate: GitHubContentCandidate
    let fetchedText: String?
    let parseErrorDescription: String?
    let fetchErrorDescription: String?
}

struct GitHubContentResolution {
    let matchedCandidate: GitHubContentCandidate?
    let servers: [ParsedServer]
    let lastFetchedText: String
    let lastFetchedCandidate: GitHubContentCandidate?
    let attempts: [GitHubContentFetchAttempt]
    var importChoices: [ParsedImportChoice] = []
    var interactiveInstaller: InteractiveInstallerCandidate? = nil

    var didFindParseableConfig: Bool { matchedCandidate != nil && !servers.isEmpty }
    var needsUserChoice: Bool { matchedCandidate != nil && servers.isEmpty && !importChoices.isEmpty }
    var needsInteractiveInstallerHandoff: Bool { matchedCandidate != nil && servers.isEmpty && interactiveInstaller != nil }
    var attemptedPaths: [String] { attempts.map(\.candidate.path) }
    var fetchedPaths: [String] { attempts.compactMap { $0.fetchedText == nil ? nil : $0.candidate.path } }
}

enum ImportParseError: Error, LocalizedError {
    case emptyInput
    case notJson
    case notAnObject
    case noServersFound
    case noCommandOrUrl
    case wizardCommand
    case githubRepository
    case remoteConfigDocument
    case archiveReference
    case archiveUnsupported
    case archiveUnreadable
    case archiveMissingManifest
    case archiveInvalidManifest
    case archiveNotDesktopExtensionManifest
    case archiveNoImportableConfig

    var errorDescription: String? {
        switch self {
        case .emptyInput:       return "Paste an MCP server config to get started."
        case .notJson:          return "Doesn't look like JSON, a URL, or an MCP command. Paste a config block, endpoint URL, or install command from the README."
        case .notAnObject:      return "Expected a JSON object (starting with {)."
        case .noServersFound:   return "Couldn't find any servers in that config."
        case .noCommandOrUrl:   return "Server is missing both \"command\" and \"url\"."
        case .wizardCommand:    return "This is a wizard installer. Run it in your terminal so you can answer prompts, then refresh Project Hub."
        case .githubRepository: return "This looks like a GitHub repository. Use From URL to fetch server.json, MCP config files, or README snippets, or paste the repository's JSON snippet or command block."
        case .remoteConfigDocument: return "This looks like a config document URL. Use From URL to fetch and parse it, or paste the fetched JSON/TOML snippet directly."
        case .archiveReference: return "This looks like an archive download. Use From URL for direct archive links, or download it locally and choose the archive so Project Hub can inspect extension manifests, mcp.json files, or README snippets."
        case .archiveUnsupported: return "Project Hub can inspect local .mcpb, .dxt, .zip, .tar.gz, and .tgz archives."
        case .archiveUnreadable: return "Project Hub couldn't read that archive."
        case .archiveMissingManifest: return "That archive doesn't contain a manifest.json or manifest.mcpb.json file."
        case .archiveInvalidManifest: return "The archive manifest could not be parsed or is missing required MCPB/DXT fields."
        case .archiveNotDesktopExtensionManifest: return "That archive's manifest is not a Claude Desktop MCPB/DXT extension manifest."
        case .archiveNoImportableConfig: return "Project Hub did not find a server.json, mcp.json, mcp-fetch.json, .codex/config.toml, or README install snippet it could safely preview in that archive."
        }
    }
}

enum ImportParser {

    static func localArchiveURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "<>\"' \n\t"))
        guard !trimmed.isEmpty else { return nil }

        let url: URL
        if let parsed = URL(string: trimmed), parsed.scheme == "file" {
            url = parsed
        } else if trimmed.hasPrefix("~") || trimmed.hasPrefix("/") {
            url = URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
        } else {
            return nil
        }

        guard isSupportedLocalArchive(url.path) else { return nil }
        return url
    }

    static func previewDesktopExtensionArchive(at url: URL) -> Result<DesktopExtensionArchivePreview, ImportParseError> {
        guard isSupportedDesktopExtensionArchive(url.path) else { return .failure(.archiveUnsupported) }
        guard FileManager.default.fileExists(atPath: url.path) else { return .failure(.archiveUnreadable) }
        guard let entries = unzipList(url.path) else { return .failure(.archiveUnreadable) }
        let strictExtensionArchive = isStrictDesktopExtensionArchive(url.path)
        guard let manifestEntry = entries.first(where: { entry in
            let last = (entry as NSString).lastPathComponent
            return last == "manifest.json" || last == "manifest.mcpb.json"
        }) else {
            return .failure(.archiveMissingManifest)
        }
        guard let manifestText = unzipEntry(archivePath: url.path, entryPath: manifestEntry),
              let data = ConfigWriter.stripJsonComments(manifestText).data(using: .utf8),
              let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(strictExtensionArchive ? .archiveInvalidManifest : .archiveNotDesktopExtensionManifest)
        }

        guard desktopExtensionManifestIsValid(manifest) else {
            let error: ImportParseError = strictExtensionArchive || desktopExtensionManifestDeclaresIdentity(manifest)
                ? .archiveInvalidManifest
                : .archiveNotDesktopExtensionManifest
            return .failure(error)
        }

        let name = stringValue(manifest["name"]) ?? url.deletingPathExtension().lastPathComponent
        let displayName = stringValue(manifest["display_name"]) ?? name
        let version = stringValue(manifest["version"])
        let description = stringValue(manifest["description"])
        let author = authorName(manifest["author"])
        let commandPreview = desktopExtensionCommandPreview(manifest)
        let toolNames = desktopExtensionToolNames(manifest)
        let requiredUserConfig = desktopExtensionRequiredUserConfig(manifest)

        return .success(DesktopExtensionArchivePreview(
            filePath: url.path,
            manifestPath: manifestEntry,
            name: cleanName(name),
            displayName: displayName,
            version: version,
            description: description,
            author: author,
            commandPreview: commandPreview,
            toolNames: toolNames,
            requiredUserConfig: requiredUserConfig
        ))
    }

    static func previewSourceArchive(at url: URL) -> Result<SourceArchiveImportPreview, ImportParseError> {
        guard isSupportedSourceArchive(url.path) else { return .failure(.archiveUnsupported) }
        guard FileManager.default.fileExists(atPath: url.path) else { return .failure(.archiveUnreadable) }
        guard let entries = archiveList(url.path) else { return .failure(.archiveUnreadable) }

        var scannedPaths: [String] = []
        var choices: [ParsedImportChoice] = []
        var installerCandidate: (entryPath: String, installer: InteractiveInstallerCandidate)?
        var seenChoices = Set<String>()
        for entry in sourceArchiveCandidateEntries(entries).prefix(64) {
            guard let text = archiveEntryText(archivePath: url.path, entryPath: entry) else { continue }
            let sample = text.count > 250_000 ? String(text.prefix(250_000)) : text
            scannedPaths.append(entry)
            let entryChoices = archiveImportChoices(from: sample, entryPath: entry)
            if installerCandidate == nil,
               let installer = interactiveInstaller(from: sample) {
                installerCandidate = (entry, installer)
            }
            for choice in entryChoices {
                guard seenChoices.insert(importChoiceSignature(choice.servers)).inserted else { continue }
                choices.append(choice)
            }
        }

        if let first = choices.first {
            return .success(SourceArchiveImportPreview(
                filePath: url.path,
                sourcePath: archiveChoiceSourcePath(first.source),
                servers: first.servers,
                scannedPaths: scannedPaths,
                choices: choices,
                interactiveInstaller: installerCandidate?.installer
            ))
        }

        if let installerCandidate {
            return .success(SourceArchiveImportPreview(
                filePath: url.path,
                sourcePath: installerCandidate.entryPath,
                servers: [],
                scannedPaths: scannedPaths,
                choices: [],
                interactiveInstaller: installerCandidate.installer
            ))
        }

        return .failure(.archiveNoImportableConfig)
    }

    static func githubContentFetch(from raw: String) -> GitHubContentFetch? {
        guard let url = parseURL(raw) else { return nil }

        if let rawFetch = githubRawContentFetch(url: url) {
            return rawFetch
        }

        guard url.host?.lowercased() == "github.com" else { return nil }

        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 2 else { return nil }
        let owner = parts[0]
        let repo = parts[1].replacingOccurrences(of: ".git", with: "")

        if parts.count >= 5, ["blob", "raw"].contains(parts[2]) {
            let refAndPath = Array(parts.dropFirst(3))
            return GitHubContentFetch(candidates: githubBlobCandidates(owner: owner, repo: repo, refAndPath: refAndPath))
        }

        if parts.count == 2 {
            return GitHubContentFetch(
                candidates: githubRepositoryCandidates(owner: owner, repo: repo, ref: "HEAD", prefix: ""),
                discoveries: githubRepositoryDiscoveries(owner: owner, repo: repo, ref: "HEAD", prefix: ""),
                registryLookup: githubRegistryLookup(owner: owner, repo: repo, allowAnySubfolder: true, prefixes: [])
            )
        }

        if parts.count >= 4, ["tree", "src"].contains(parts[2]) {
            let refAndPrefix = Array(parts.dropFirst(3))
            return GitHubContentFetch(
                candidates: githubTreeCandidates(owner: owner, repo: repo, refAndPrefix: refAndPrefix),
                discoveries: githubTreeDiscoveries(owner: owner, repo: repo, refAndPrefix: refAndPrefix),
                registryLookup: githubTreeRegistryLookup(owner: owner, repo: repo, refAndPrefix: refAndPrefix)
            )
        }

        return nil
    }

    private static func githubRawContentFetch(url: URL) -> GitHubContentFetch? {
        guard url.host?.lowercased() == "raw.githubusercontent.com" else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 4 else { return nil }
        let owner = parts[0]
        let repo = parts[1].replacingOccurrences(of: ".git", with: "")
        let candidates = githubBlobCandidates(owner: owner, repo: repo, refAndPath: Array(parts.dropFirst(2)))
            .filter { githubRawContentPathIsImportable($0.path) }
        guard let first = candidates.first else { return nil }
        let primary = GitHubContentCandidate(
            url: url,
            path: first.path,
            note: first.note
        )
        return GitHubContentFetch(candidates: deduplicatedGitHubCandidates([primary] + candidates.dropFirst()))
    }

    private static func githubRawContentPathIsImportable(_ path: String) -> Bool {
        let lower = path.lowercased()
        let last = URL(fileURLWithPath: lower).lastPathComponent
        return last == "server.json"
            || isMCPConfigDocumentFilename(last)
            || lower == ".codex/config.toml"
            || lower.hasSuffix("/.codex/config.toml")
            || last == "claude_desktop_config.json"
            || last == "claude-desktop-config.json"
            || lower.hasSuffix("/.cursor/mcp.json")
            || lower.hasSuffix("/.vscode/mcp.json")
            || lower.hasSuffix("/.roo/mcp.json")
            || last == "readme.md"
            || last == "readme.markdown"
    }

    static func githubRepositoryCandidates(owner: String, repo: String, ref: String, prefix: String, useContentsAPI: Bool = false) -> [GitHubContentCandidate] {
        let normalizedPrefix = prefix
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        let filenames = [
            "server.json",
            "mcp.json",
            "mcp-fetch.json",
            ".mcp.json",
            "mcp_settings.json",
            "cline_mcp_settings.json",
            ".codex/config.toml",
            "claude_desktop_config.json",
            "claude-desktop-config.json",
            ".cursor/mcp.json",
            ".vscode/mcp.json",
            ".roo/mcp.json",
            "README.md",
            "README.markdown"
        ]
        return filenames.compactMap { filename in
            let path = normalizedPrefix.isEmpty ? filename : "\(normalizedPrefix)/\(filename)"
            let url = useContentsAPI
                ? githubContentsAPIURL(owner: owner, repo: repo, ref: ref, path: path)
                : githubRawURL(owner: owner, repo: repo, ref: ref, path: path)
            guard let url else { return nil }
            return GitHubContentCandidate(
                url: url,
                path: path,
                note: githubSourceNote(owner: owner, repo: repo, ref: ref, path: path)
            )
        }
    }

    private static func githubRepositoryDiscoveries(owner: String, repo: String, ref: String, prefix: String) -> [GitHubContentDiscovery] {
        guard let url = githubTreeAPIURL(owner: owner, repo: repo, ref: ref) else { return [] }
        return [GitHubContentDiscovery(
            url: url,
            owner: owner,
            repo: repo,
            ref: ref,
            prefix: prefix
        )]
    }

    private static func githubTreeCandidates(owner: String, repo: String, refAndPrefix: [String]) -> [GitHubContentCandidate] {
        refPrefixSplits(refAndPrefix, allowEmptyPath: true).enumerated().flatMap { index, split in
            githubRepositoryCandidates(
                owner: owner,
                repo: repo,
                ref: split.ref,
                prefix: split.path,
                useContentsAPI: index > 0
            )
        }
    }

    private static func githubTreeDiscoveries(owner: String, repo: String, refAndPrefix: [String]) -> [GitHubContentDiscovery] {
        refPrefixSplits(refAndPrefix, allowEmptyPath: true).compactMap { split in
            githubRepositoryDiscoveries(owner: owner, repo: repo, ref: split.ref, prefix: split.path).first
        }
    }

    private static func githubBlobCandidates(owner: String, repo: String, refAndPath: [String]) -> [GitHubContentCandidate] {
        refPrefixSplits(refAndPath, allowEmptyPath: false).enumerated().compactMap { index, split in
            guard !split.path.isEmpty else { return nil }
            let url = index == 0
                ? githubRawURL(owner: owner, repo: repo, ref: split.ref, path: split.path)
                : githubContentsAPIURL(owner: owner, repo: repo, ref: split.ref, path: split.path)
            guard let url else { return nil }
            return GitHubContentCandidate(
                url: url,
                path: split.path,
                note: githubSourceNote(owner: owner, repo: repo, ref: split.ref, path: split.path)
            )
        }
    }

    private static func refPrefixSplits(_ segments: [String], allowEmptyPath: Bool) -> [(ref: String, path: String)] {
        guard !segments.isEmpty else { return [] }
        let maxRefSegmentCount = allowEmptyPath ? segments.count : max(segments.count - 1, 1)
        guard maxRefSegmentCount >= 1 else { return [] }
        return (1...maxRefSegmentCount).map { refSegmentCount in
            let ref = segments.prefix(refSegmentCount).joined(separator: "/")
            let path = segments.dropFirst(refSegmentCount).joined(separator: "/")
            return (ref: ref, path: path)
        }
    }

    private static func githubRawURL(owner: String, repo: String, ref: String, path: String) -> URL? {
        URL(string: "https://raw.githubusercontent.com/\(owner)/\(repo)/\(ref)/\(path)")
    }

    private static func githubContentsAPIURL(owner: String, repo: String, ref: String, path: String) -> URL? {
        let encodedPath = path
            .split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
        var queryAllowed = CharacterSet.urlQueryAllowed
        queryAllowed.remove(charactersIn: "&+=?/")
        guard let encodedRef = ref.addingPercentEncoding(withAllowedCharacters: queryAllowed) else { return nil }
        return URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(encodedPath)?ref=\(encodedRef)")
    }

    private static func githubTreeAPIURL(owner: String, repo: String, ref: String) -> URL? {
        var pathAllowed = CharacterSet.urlPathAllowed
        pathAllowed.remove(charactersIn: "/")
        guard let encodedRef = ref.addingPercentEncoding(withAllowedCharacters: pathAllowed) else { return nil }
        return URL(string: "https://api.github.com/repos/\(owner)/\(repo)/git/trees/\(encodedRef)?recursive=1")
    }

    private static func githubSourceNote(owner: String, repo: String, ref: String, path: String) -> String {
        "Read \(owner)/\(repo)/\(path) from GitHub at \(ref)."
    }

    private static func githubRegistryLookup(owner: String, repo: String, allowAnySubfolder: Bool, prefixes: [String]) -> GitHubRegistryLookup? {
        guard let url = githubRegistryPageURL(cursor: nil) else { return nil }
        return GitHubRegistryLookup(
            owner: owner,
            repo: repo,
            allowAnySubfolder: allowAnySubfolder,
            acceptableSubfolders: deduplicatedNormalizedPaths(prefixes),
            firstPageURL: url
        )
    }

    private static func githubTreeRegistryLookup(owner: String, repo: String, refAndPrefix: [String]) -> GitHubRegistryLookup? {
        let prefixes = refPrefixSplits(refAndPrefix, allowEmptyPath: true)
            .map(\.path)
            .filter { !$0.isEmpty }
        guard !prefixes.isEmpty else { return nil }
        return githubRegistryLookup(owner: owner, repo: repo, allowAnySubfolder: false, prefixes: prefixes)
    }

    private static func githubRegistryPageURL(cursor: String?) -> URL? {
        var components = URLComponents(string: "https://registry.modelcontextprotocol.io/v0.1/servers")
        var items = [
            URLQueryItem(name: "version", value: "latest"),
            URLQueryItem(name: "limit", value: "100")
        ]
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components?.queryItems = items
        return components?.url
    }

    private static func deduplicatedNormalizedPaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        return paths.map(normalizedPath).filter { path in
            !path.isEmpty && seen.insert(path).inserted
        }
    }

    private static func normalizedPath(_ path: String) -> String {
        path.split(separator: "/").map(String.init).filter { !$0.isEmpty }.joined(separator: "/")
    }

    static func resolveGitHubContent(
        _ fetch: GitHubContentFetch,
        fetchText: (GitHubContentCandidate) async throws -> String,
        fetchDiscoveryText: ((GitHubContentDiscovery) async throws -> String)? = nil,
        fetchRegistryText: ((GitHubRegistryPageRequest) async throws -> String)? = nil
    ) async -> GitHubContentResolution {
        var attempts: [GitHubContentFetchAttempt] = []
        var lastText = ""
        var lastCandidate: GitHubContentCandidate?

        func attempt(_ candidate: GitHubContentCandidate) async -> GitHubContentResolution? {
            let text: String
            do {
                text = try await fetchText(candidate)
            } catch {
                attempts.append(GitHubContentFetchAttempt(
                    candidate: candidate,
                    fetchedText: nil,
                    parseErrorDescription: nil,
                    fetchErrorDescription: error.localizedDescription
                ))
                return nil
            }
            lastText = text
            lastCandidate = candidate
            let sample = text.count > 250_000 ? String(text.prefix(250_000)) : text
            let choices = registryManifestImportChoices(from: sample) ?? (isGitHubReadmeCandidate(candidate) ? importChoices(from: sample) : [])
            let installer = isGitHubReadmeCandidate(candidate)
                ? interactiveInstaller(from: sample)
                : nil
            if choices.count > 1 || choices.contains(where: { $0.archiveURL != nil || $0.servers.isEmpty }) {
                attempts.append(GitHubContentFetchAttempt(
                    candidate: candidate,
                    fetchedText: text,
                    parseErrorDescription: nil,
                    fetchErrorDescription: nil
                ))
                return GitHubContentResolution(
                    matchedCandidate: candidate,
                    servers: [],
                    lastFetchedText: text,
                    lastFetchedCandidate: candidate,
                    attempts: attempts,
                    importChoices: choices,
                    interactiveInstaller: installer
                )
            }
            if let installer, choices.isEmpty {
                attempts.append(GitHubContentFetchAttempt(
                    candidate: candidate,
                    fetchedText: text,
                    parseErrorDescription: nil,
                    fetchErrorDescription: nil
                ))
                return GitHubContentResolution(
                    matchedCandidate: candidate,
                    servers: [],
                    lastFetchedText: text,
                    lastFetchedCandidate: candidate,
                    attempts: attempts,
                    interactiveInstaller: installer
                )
            }
            let parsed = choices.first.map { Result<[ParsedServer], ImportParseError>.success($0.servers) } ?? parse(sample)
            switch parsed {
            case .success(let servers) where !servers.isEmpty:
                attempts.append(GitHubContentFetchAttempt(
                    candidate: candidate,
                    fetchedText: text,
                    parseErrorDescription: nil,
                    fetchErrorDescription: nil
                ))
                return GitHubContentResolution(
                    matchedCandidate: candidate,
                    servers: servers,
                    lastFetchedText: text,
                    lastFetchedCandidate: candidate,
                    attempts: attempts,
                    importChoices: choices,
                    interactiveInstaller: installer
                )
            case .success:
                attempts.append(GitHubContentFetchAttempt(
                    candidate: candidate,
                    fetchedText: text,
                    parseErrorDescription: "No servers found in that config.",
                    fetchErrorDescription: nil
                ))
            default:
                let parseErrorDescription: String?
                if case .failure(let error) = parsed {
                    parseErrorDescription = error.errorDescription
                } else {
                    parseErrorDescription = nil
                }
                attempts.append(GitHubContentFetchAttempt(
                    candidate: candidate,
                    fetchedText: text,
                    parseErrorDescription: parseErrorDescription,
                    fetchErrorDescription: nil
                ))
                return nil
            }
            return nil
        }

        let candidates = deduplicatedGitHubCandidates(fetch.candidates)
        let readmeIndex = candidates.firstIndex(where: isGitHubReadmeCandidate) ?? candidates.endIndex
        for candidate in candidates.prefix(upTo: readmeIndex) {
            if let resolution = await attempt(candidate) { return resolution }
        }

        if let fetchDiscoveryText {
            let discovered = await discoveredGitHubCandidates(fetch, fetchDiscoveryText: fetchDiscoveryText)
            for candidate in discovered {
                if let resolution = await attempt(candidate) { return resolution }
            }
        }

        if let lookup = fetch.registryLookup, let fetchRegistryText {
            let registry = await resolveGitHubRegistryLookup(lookup, fetchRegistryText: fetchRegistryText)
            attempts.append(contentsOf: registry.attempts)
            if let resolution = registry.resolution {
                return GitHubContentResolution(
                    matchedCandidate: resolution.matchedCandidate,
                    servers: resolution.servers,
                    lastFetchedText: resolution.lastFetchedText,
                    lastFetchedCandidate: resolution.lastFetchedCandidate,
                    attempts: attempts,
                    importChoices: resolution.importChoices,
                    interactiveInstaller: resolution.interactiveInstaller
                )
            }
        }

        for candidate in candidates.suffix(from: readmeIndex) {
            if let resolution = await attempt(candidate) { return resolution }
        }

        return GitHubContentResolution(
            matchedCandidate: nil,
            servers: [],
            lastFetchedText: lastText,
            lastFetchedCandidate: lastCandidate,
            attempts: attempts
        )
    }

    private struct GitHubRegistryLookupResolution {
        let resolution: GitHubContentResolution?
        let attempts: [GitHubContentFetchAttempt]
    }

    private struct GitHubRegistryMatch {
        let candidate: GitHubContentCandidate
        let rawManifestText: String
    }

    private struct GitHubRegistryPageResult {
        let matches: [GitHubRegistryMatch]
        let nextCursor: String?
    }

    private static func resolveGitHubRegistryLookup(
        _ lookup: GitHubRegistryLookup,
        fetchRegistryText: (GitHubRegistryPageRequest) async throws -> String
    ) async -> GitHubRegistryLookupResolution {
        var attempts: [GitHubContentFetchAttempt] = []
        var cursor: String?
        var page = 1
        let maxPages = 100
        var matches: [GitHubRegistryMatch] = []

        while page <= maxPages {
            guard let url = githubRegistryPageURL(cursor: cursor) else { break }
            let request = GitHubRegistryPageRequest(lookup: lookup, url: url, page: page, cursor: cursor)
            let marker = githubRegistryAttemptCandidate(url: url, page: page)
            let text: String
            do {
                text = try await fetchRegistryText(request)
            } catch {
                attempts.append(GitHubContentFetchAttempt(
                    candidate: marker,
                    fetchedText: nil,
                    parseErrorDescription: nil,
                    fetchErrorDescription: error.localizedDescription
                ))
                return GitHubRegistryLookupResolution(resolution: nil, attempts: attempts)
            }

            let pageResult = githubRegistryMatches(from: text, lookup: lookup)
            attempts.append(GitHubContentFetchAttempt(
                candidate: marker,
                fetchedText: nil,
                parseErrorDescription: pageResult.matches.isEmpty ? "No MCP Registry server matched this GitHub repository on page \(page)." : nil,
                fetchErrorDescription: nil
            ))

            matches.append(contentsOf: pageResult.matches)
            if matches.count > 1 {
                attempts.append(GitHubContentFetchAttempt(
                    candidate: marker,
                    fetchedText: nil,
                    parseErrorDescription: "MCP Registry returned multiple servers for this GitHub repository.",
                    fetchErrorDescription: nil
                ))
                return GitHubRegistryLookupResolution(resolution: nil, attempts: attempts)
            }

            guard let nextCursor = pageResult.nextCursor, !nextCursor.isEmpty else { break }
            cursor = nextCursor
            page += 1
        }

        if let match = matches.first {
            let choices = registryManifestImportChoices(from: match.rawManifestText) ?? []
            if choices.count > 1 {
                let matchAttempt = GitHubContentFetchAttempt(
                    candidate: match.candidate,
                    fetchedText: match.rawManifestText,
                    parseErrorDescription: nil,
                    fetchErrorDescription: nil
                )
                return GitHubRegistryLookupResolution(
                    resolution: GitHubContentResolution(
                        matchedCandidate: match.candidate,
                        servers: [],
                        lastFetchedText: match.rawManifestText,
                        lastFetchedCandidate: match.candidate,
                        attempts: [matchAttempt],
                        importChoices: choices
                    ),
                    attempts: attempts + [matchAttempt]
                )
            }

            let parsed = choices.first.map { Result<[ParsedServer], ImportParseError>.success($0.servers) } ?? parse(match.rawManifestText)
            switch parsed {
            case .success(let servers) where !servers.isEmpty:
                let matchAttempt = GitHubContentFetchAttempt(
                    candidate: match.candidate,
                    fetchedText: match.rawManifestText,
                    parseErrorDescription: nil,
                    fetchErrorDescription: nil
                )
                return GitHubRegistryLookupResolution(
                    resolution: GitHubContentResolution(
                        matchedCandidate: match.candidate,
                        servers: servers,
                        lastFetchedText: match.rawManifestText,
                        lastFetchedCandidate: match.candidate,
                        attempts: [matchAttempt],
                        importChoices: choices
                    ),
                    attempts: attempts + [matchAttempt]
                )
            case .success:
                attempts.append(GitHubContentFetchAttempt(
                    candidate: match.candidate,
                    fetchedText: match.rawManifestText,
                    parseErrorDescription: "No servers found in that MCP Registry manifest.",
                    fetchErrorDescription: nil
                ))
                return GitHubRegistryLookupResolution(resolution: nil, attempts: attempts)
            case .failure(let error):
                attempts.append(GitHubContentFetchAttempt(
                    candidate: match.candidate,
                    fetchedText: match.rawManifestText,
                    parseErrorDescription: error.errorDescription,
                    fetchErrorDescription: nil
                ))
                return GitHubRegistryLookupResolution(resolution: nil, attempts: attempts)
            }
        }

        return GitHubRegistryLookupResolution(resolution: nil, attempts: attempts)
    }

    private static func discoveredGitHubCandidates(
        _ fetch: GitHubContentFetch,
        fetchDiscoveryText: (GitHubContentDiscovery) async throws -> String
    ) async -> [GitHubContentCandidate] {
        var discovered: [GitHubContentCandidate] = []
        for discovery in fetch.discoveries {
            guard let text = try? await fetchDiscoveryText(discovery) else { continue }
            discovered.append(contentsOf: githubDiscoveredConfigCandidates(from: text, discovery: discovery))
        }
        return deduplicatedGitHubCandidates(discovered)
    }

    private static func githubRegistryAttemptCandidate(url: URL, page: Int) -> GitHubContentCandidate {
        GitHubContentCandidate(
            url: url,
            path: "MCP Registry page \(page)",
            note: "Checked MCP Registry page \(page)."
        )
    }

    private static func githubRegistryMatches(from raw: String, lookup: GitHubRegistryLookup) -> GitHubRegistryPageResult {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return GitHubRegistryPageResult(matches: [], nextCursor: nil)
        }
        let servers = obj["servers"] as? [[String: Any]] ?? []
        let metadata = obj["metadata"] as? [String: Any]
        let nextCursor = stringValue(metadata?["nextCursor"])

        let matches = servers.compactMap { wrapper -> GitHubRegistryMatch? in
            guard githubRegistryMetadataIsImportable(wrapper) else { return nil }
            let server = (wrapper["server"] as? [String: Any]) ?? wrapper
            guard githubRegistryServer(server, matches: lookup) else { return nil }
            guard let data = try? JSONSerialization.data(withJSONObject: server, options: [.prettyPrinted, .sortedKeys]),
                  let text = String(data: data, encoding: .utf8) else {
                return nil
            }
            let name = stringValue(server["name"]) ?? "registry-server"
            let subfolder = stringValue((server["repository"] as? [String: Any])?["subfolder"])
            let path = subfolder.map { "MCP Registry: \(name) (\($0))" } ?? "MCP Registry: \(name)"
            let note = subfolder.map {
                "Matched MCP Registry metadata for \(lookup.owner)/\(lookup.repo) in \($0)."
            } ?? "Matched MCP Registry metadata for \(lookup.owner)/\(lookup.repo)."
            return GitHubRegistryMatch(
                candidate: GitHubContentCandidate(url: lookup.firstPageURL, path: path, note: note),
                rawManifestText: text
            )
        }

        return GitHubRegistryPageResult(matches: matches, nextCursor: nextCursor)
    }

    private static func githubRegistryMetadataIsImportable(_ wrapper: [String: Any]) -> Bool {
        guard let meta = wrapper["_meta"] as? [String: Any],
              let official = meta["io.modelcontextprotocol.registry/official"] as? [String: Any] else {
            return true
        }
        if let status = stringValue(official["status"])?.lowercased(), status != "active" {
            return false
        }
        if let isLatest = official["isLatest"] as? Bool, !isLatest {
            return false
        }
        return true
    }

    private static func githubRegistryServer(_ server: [String: Any], matches lookup: GitHubRegistryLookup) -> Bool {
        guard let repository = server["repository"] as? [String: Any] else { return false }
        if let source = stringValue(repository["source"])?.lowercased(), source != "github" {
            return false
        }
        guard let url = stringValue(repository["url"]),
              let repoID = normalizedGitHubRepositoryID(from: url),
              repoID == "\(lookup.owner.lowercased())/\(lookup.repo.lowercased())" else {
            return false
        }
        guard !lookup.allowAnySubfolder else { return true }
        guard let subfolder = stringValue(repository["subfolder"]) else { return false }
        let normalizedSubfolder = normalizedPath(subfolder)
        return lookup.acceptableSubfolders.contains { candidate in
            candidate == normalizedSubfolder
                || candidate.hasPrefix("\(normalizedSubfolder)/")
                || normalizedSubfolder.hasPrefix("\(candidate)/")
        }
    }

    private static func normalizedGitHubRepositoryID(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.host?.lowercased() == "github.com" {
            let parts = url.path.split(separator: "/").map(String.init)
            guard parts.count >= 2 else { return nil }
            return "\(parts[0].lowercased())/\(parts[1].replacingOccurrences(of: ".git", with: "").lowercased())"
        }
        if trimmed.lowercased().hasPrefix("git@github.com:") {
            let path = String(trimmed.dropFirst("git@github.com:".count))
            let parts = path.split(separator: "/").map(String.init)
            guard parts.count >= 2 else { return nil }
            return "\(parts[0].lowercased())/\(parts[1].replacingOccurrences(of: ".git", with: "").lowercased())"
        }
        return nil
    }

    private static func githubDiscoveredConfigCandidates(from raw: String, discovery: GitHubContentDiscovery) -> [GitHubContentCandidate] {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = obj["tree"] as? [[String: Any]] else {
            return []
        }
        let normalizedPrefix = discovery.prefix
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        return entries.compactMap { entry in
            guard (entry["type"] as? String) == "blob",
                  let path = entry["path"] as? String,
                  path.contains("/"),
                  githubDiscoveredConfigScore(path) != nil else {
                return nil
            }
            guard normalizedPrefix.isEmpty || path == "\(normalizedPrefix)/server.json" || path.hasPrefix("\(normalizedPrefix)/") else {
                return nil
            }
            let depth = path.split(separator: "/").count
            guard depth <= 5 else { return nil }
            guard let url = githubContentsAPIURL(owner: discovery.owner, repo: discovery.repo, ref: discovery.ref, path: path) else { return nil }
            return GitHubContentCandidate(
                url: url,
                path: path,
                note: githubSourceNote(owner: discovery.owner, repo: discovery.repo, ref: discovery.ref, path: path)
            )
        }
        .sorted { left, right in
            let leftScore = githubDiscoveredConfigScore(left.path) ?? 999
            let rightScore = githubDiscoveredConfigScore(right.path) ?? 999
            if leftScore != rightScore { return leftScore < rightScore }
            return left.path.localizedCaseInsensitiveCompare(right.path) == .orderedAscending
        }
    }

    private static func githubDiscoveredConfigScore(_ path: String) -> Int? {
        let lower = path.lowercased()
        let last = URL(fileURLWithPath: lower).lastPathComponent
        if last == "server.json" { return 0 }
        if isMCPConfigDocumentFilename(last) { return 1 }
        if lower == ".codex/config.toml" || lower.hasSuffix("/.codex/config.toml") { return 2 }
        if last == "claude_desktop_config.json" || last == "claude-desktop-config.json" { return 2 }
        if lower.hasSuffix("/.cursor/mcp.json")
            || lower.hasSuffix("/.vscode/mcp.json")
            || lower.hasSuffix("/.roo/mcp.json") { return 3 }
        return nil
    }

    private static func deduplicatedGitHubCandidates(_ candidates: [GitHubContentCandidate]) -> [GitHubContentCandidate] {
        var seenURLs = Set<String>()
        return candidates.filter { candidate in
            seenURLs.insert(candidate.url.absoluteString).inserted
        }
    }

    private static func isGitHubReadmeCandidate(_ candidate: GitHubContentCandidate) -> Bool {
        let lower = candidate.path.lowercased()
        return lower == "readme.md"
            || lower == "readme.markdown"
            || lower.hasSuffix("/readme.md")
            || lower.hasSuffix("/readme.markdown")
    }

    static func parse(_ raw: String) -> Result<[ParsedServer], ImportParseError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .failure(.emptyInput) }

        if registryManifestImportChoices(from: trimmed) == nil,
           let firstChoice = importChoices(from: trimmed).first {
            return .success(firstChoice.servers)
        }

        if interactiveInstaller(from: trimmed) != nil {
            return .failure(.wizardCommand)
        }

        if looksLikeArchive(trimmed) || githubReleaseOrArchiveURL(from: trimmed) {
            return .failure(.archiveReference)
        }
        if githubContentFetch(from: trimmed) != nil {
            return .failure(.githubRepository)
        }
        if looksLikeRemoteConfigDocumentURL(trimmed) {
            return .failure(.remoteConfigDocument)
        }
        if looksLikeGitHubRepository(trimmed) {
            return .failure(.githubRepository)
        }

        for candidate in candidates(from: trimmed) {
            if let parsed = parseJSONCandidate(candidate) {
                return parsed
            }
        }

        return .failure(trimmed.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") ? .notAnObject : .notJson)
    }

    static func importChoices(from raw: String) -> [ParsedImportChoice] {
        var choices: [ParsedImportChoice] = []
        var seen = Set<String>()

        for candidate in candidates(from: raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
            if interactiveInstaller(from: candidate) != nil { continue }
            let parsedChoices = registryManifestImportChoices(from: candidate) ?? parseImportChoiceCandidate(candidate).map { [$0] } ?? []
            for parsed in parsedChoices {
                let signature = importChoiceSignature(parsed.servers)
                guard seen.insert(signature).inserted else { continue }
                choices.append(parsed)
            }
        }

        return choices
    }

    private static func archiveImportChoices(from raw: String, entryPath: String) -> [ParsedImportChoice] {
        importChoices(from: raw).map { choice in
            ParsedImportChoice(
                label: choice.label,
                source: "\(entryPath): \(choice.source)",
                rawText: choice.rawText,
                servers: choice.servers,
                archiveURL: choice.archiveURL,
                archiveSHA256: choice.archiveSHA256
            )
        }
    }

    private static func archiveChoiceSourcePath(_ source: String) -> String {
        guard let separator = source.range(of: ": ") else { return source }
        return String(source[..<separator.lowerBound])
    }

    private static func parseImportChoiceCandidate(_ candidate: String) -> ParsedImportChoice? {
        if let directURL = parseDirectURL(candidate) {
            return ParsedImportChoice(
                label: "Remote URL",
                source: compactChoiceSource(candidate),
                rawText: candidate,
                servers: [directURL]
            )
        }

        // Official Claude Code JSON import form:
        // `claude mcp add-json <name> '{"type":"stdio","command":"..."}'`.
        if let jsonServer = parseCliAddJSON(candidate) {
            return ParsedImportChoice(
                label: "MCP add-json command",
                source: compactChoiceSource(candidate),
                rawText: candidate,
                servers: [jsonServer]
            )
        }

        // CLI-style `claude mcp add ...` / `cursor mcp add ...` / `codex mcp add ...` etc.
        if let cliServer = parseCliAdd(candidate) {
            return ParsedImportChoice(
                label: "MCP add command",
                source: compactChoiceSource(candidate),
                rawText: candidate,
                servers: [cliServer]
            )
        }

        // Bare server launch commands from READMEs: `npx -y ...`, `uvx ...`, `docker run ...`.
        if let commandServer = parseBareCommand(candidate) {
            return ParsedImportChoice(
                label: "\(commandServer.kindLabel) command",
                source: compactChoiceSource(candidate),
                rawText: candidate,
                servers: [commandServer]
            )
        }

        // Codex config.toml snippets: `[mcp_servers.<name>]`.
        if let tomlResult = parseCodexTomlCandidate(candidate),
           case .success(let servers) = tomlResult,
           !servers.isEmpty {
            return ParsedImportChoice(
                label: servers.count == 1 ? "Codex TOML server" : "Codex TOML servers",
                source: compactChoiceSource(candidate),
                rawText: candidate,
                servers: servers
            )
        }

        if let jsonResult = parseJSONCandidate(candidate),
           case .success(let servers) = jsonResult,
           !servers.isEmpty {
            return ParsedImportChoice(
                label: servers.count == 1 ? "JSON server config" : "JSON server config",
                source: compactChoiceSource(candidate),
                rawText: candidate,
                servers: servers
            )
        }

        return nil
    }

    static func interactiveInstaller(from raw: String) -> InteractiveInstallerCandidate? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for candidate in candidates(from: trimmed) {
            let command = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isWizardCommand(command) else { continue }
            let tokens = shellSplit(command)
            let first = tokens.first?.lowercased() ?? ""
            let runtime: String
            switch first {
            case "npx", "npm", "pnpm", "yarn", "bunx", "bun", "px":
                runtime = "Node package installer"
            case "uvx", "uv", "pipx":
                runtime = "Python/uv installer"
            case "mcp":
                runtime = "MCP installer"
            default:
                runtime = "\(first) installer"
            }
            let detectedTool = detectedInstallerTool(in: tokens)
            let toolText = detectedTool.map { " for \($0)" } ?? ""
            return InteractiveInstallerCandidate(
                rawCommand: command,
                source: compactChoiceSource(command),
                runtime: runtime,
                detectedTool: detectedTool,
                summary: "Prompt-driven MCP installer\(toolText). Project Hub will not run it because it may ask questions and write tool config."
            )
        }
        return nil
    }

    private static func detectedInstallerTool(in tokens: [String]) -> String? {
        let lowered = tokens.map { $0.lowercased() }
        let known: [(token: String, label: String)] = [
            ("claude", "Claude"),
            ("codex", "Codex"),
            ("cursor", "Cursor"),
            ("vscode", "VS Code"),
            ("roo", "Roo")
        ]
        for item in known where lowered.contains(item.token) {
            return item.label
        }
        return nil
    }

    private static func importChoiceSignature(_ servers: [ParsedServer]) -> String {
        servers.map { server in
            let data = try? JSONSerialization.data(withJSONObject: server.config, options: [.sortedKeys])
            let config = data.flatMap { String(data: $0, encoding: .utf8) } ?? server.preview
            return "\(server.name)\u{1f}\(config)"
        }
        .joined(separator: "\u{1e}")
    }

    private static func compactChoiceSource(_ raw: String) -> String {
        let lines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let source = lines.first ?? raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.count <= 160 { return source }
        return "\(source.prefix(157))..."
    }

    private static func parseJSONCandidate(_ raw: String) -> Result<[ParsedServer], ImportParseError>? {
        let clean = ConfigWriter.stripJsonComments(raw.trimmingCharacters(in: .whitespacesAndNewlines))

        guard let data = clean.data(using: .utf8),
              let any = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        if let array = any as? [[String: Any]] {
            let parsed = serversFrom(array: array)
            return parsed.isEmpty ? .failure(.noServersFound) : .success(parsed)
        }

        guard let obj = any as? [String: Any] else {
            return .failure(.notAnObject)
        }

        if let registryServers = registryManifestServers(in: obj) {
            return registryServers.isEmpty ? .failure(.noServersFound) : .success(registryServers)
        }

        // Case 1: wrapped — Claude/Codex-style mcpServers, snake_case
        // mcp_servers, VS Code mcp.json servers, older tools maps, or nested
        // { "mcp": { "servers": ... } }.
        if let wrapped = wrappedServers(in: obj) {
            if wrapped.isEmpty { return .failure(.noServersFound) }
            return .success(wrapped)
        }

        for wrapperKey in ["server", "mcpServer"] {
            if let cfg = obj[wrapperKey] as? [String: Any] {
                let normalized = normalizeServerConfig(cfg)
                if isInstallableServer(normalized) {
                    let server = ParsedServer(
                        name: stringValue(cfg["name"]) ?? inferredName(from: normalized),
                        config: normalized
                    )
                    return .success(applyInputRequirements(to: [server], inputs: inputDefinitions(in: obj)))
                }
            }
        }

        // Case 2: directly a server config (has command or url at top)
        let normalized = normalizeServerConfig(obj)
        if isInstallableServer(normalized) {
            let server = ParsedServer(
                name: stringValue(obj["name"]) ?? inferredName(from: normalized),
                config: normalized
            )
            return .success(applyInputRequirements(to: [server], inputs: inputDefinitions(in: obj)))
        }

        // Case 3: dict of servers (each value is itself a config)
        let servers = serversFrom(dict: obj)
        if servers.isEmpty { return .failure(.noServersFound) }
        return .success(servers)
    }

    private struct MCPInputDefinition {
        let id: String
        let description: String?
        let required: Bool
        let secret: Bool
    }

    private static func wrappedServers(
        in obj: [String: Any],
        inheritedInputs: [String: MCPInputDefinition] = [:]
    ) -> [ParsedServer]? {
        let inputs = inheritedInputs.merging(inputDefinitions(in: obj)) { _, local in local }
        for wrapperKey in ["mcpServers", "mcp_servers", "servers", "context_servers", "contextServers", "tools"] {
            guard let value = obj[wrapperKey] else { continue }
            if let dict = value as? [String: Any] {
                return serversFrom(dict: dict, inputs: inputs)
            }
            if let array = value as? [[String: Any]] {
                return serversFrom(array: array, inputs: inputs)
            }
            return []
        }

        for nestedKey in ["mcp", "modelContextProtocol", "model_context_protocol"] {
            guard let nested = obj[nestedKey] as? [String: Any] else { continue }
            if let wrapped = wrappedServers(in: nested, inheritedInputs: inputs) {
                return wrapped
            }
            let parsed = serversFrom(dict: nested, inputs: inputs)
            if !parsed.isEmpty { return parsed }
        }

        return nil
    }

    private static func serversFrom(
        dict: [String: Any],
        inputs: [String: MCPInputDefinition] = [:]
    ) -> [ParsedServer] {
        var out: [ParsedServer] = []
        for (name, value) in dict {
            guard let cfg = value as? [String: Any] else { continue }
            let normalized = normalizeServerConfig(cfg)
            guard isInstallableServer(normalized) else { continue }
            out.append(ParsedServer(name: stringValue(cfg["name"]) ?? name, config: normalized))
        }
        return applyInputRequirements(to: out, inputs: inputs)
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private static func serversFrom(
        array: [[String: Any]],
        inputs: [String: MCPInputDefinition] = [:]
    ) -> [ParsedServer] {
        let parsed: [ParsedServer] = array.compactMap { cfg in
            let normalized = normalizeServerConfig(cfg)
            guard isInstallableServer(normalized) else { return nil }
            return ParsedServer(
                name: stringValue(cfg["name"]) ?? stringValue(cfg["id"]) ?? inferredName(from: normalized),
                config: normalized
            )
        }
        return applyInputRequirements(to: parsed, inputs: inputs)
    }

    private static func inputDefinitions(in obj: [String: Any]) -> [String: MCPInputDefinition] {
        guard let inputs = obj["inputs"] as? [[String: Any]] else { return [:] }
        var definitions: [String: MCPInputDefinition] = [:]
        for input in inputs {
            guard let id = stringValue(input["id"] ?? input["name"]) else { continue }
            definitions[id] = .init(
                id: id,
                description: stringValue(input["description"] ?? input["label"] ?? input["title"]),
                required: registryBool(input["required"] ?? input["isRequired"]) ?? true,
                secret: registryBool(input["password"] ?? input["secret"] ?? input["isSecret"]) ?? false
            )
        }
        return definitions
    }

    private static func applyInputRequirements(
        to servers: [ParsedServer],
        inputs: [String: MCPInputDefinition]
    ) -> [ParsedServer] {
        guard !inputs.isEmpty else { return servers }
        return servers.map { server in
            var copy = server
            copy.credentialRequirements.append(contentsOf: inputRequirements(for: server.config, inputs: inputs))
            return copy
        }
    }

    private static func inputRequirements(
        for config: [String: Any],
        inputs: [String: MCPInputDefinition]
    ) -> [ImportCredentialRequirement] {
        var requirements: [ImportCredentialRequirement] = []
        for (key, value) in stringDict(config["env"]).sorted(by: { $0.key < $1.key }) {
            for input in inputReferences(in: value, inputs: inputs) {
                requirements.append(inputRequirement(
                    kind: .env,
                    name: key,
                    placeholder: "${input:\(input.id)}",
                    input: input
                ))
            }
        }
        var headers = stringDict(config["headers"])
        headers.merge(stringDict(config["http_headers"])) { _, new in new }
        headers.merge(stringDict(config["request_headers"])) { _, new in new }
        for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
            for input in inputReferences(in: value, inputs: inputs) {
                requirements.append(inputRequirement(
                    kind: .header,
                    name: key,
                    placeholder: "${input:\(input.id)}",
                    input: input
                ))
            }
        }
        if let url = stringValue(config["url"]) {
            for input in inputReferences(in: url, inputs: inputs) {
                requirements.append(inputRequirement(
                    kind: .urlVariable,
                    name: input.id,
                    placeholder: "${input:\(input.id)}",
                    input: input
                ))
            }
        }
        return requirements
    }

    private static func inputRequirement(
        kind: ImportCredentialRequirement.Kind,
        name: String,
        placeholder: String,
        input: MCPInputDefinition
    ) -> ImportCredentialRequirement {
        .init(
            kind: kind,
            name: name,
            envName: nil,
            placeholder: placeholder,
            required: input.required,
            secret: input.secret,
            description: input.description,
            source: "mcp.json input \(input.id)"
        )
    }

    private static func inputReferences(
        in value: String,
        inputs: [String: MCPInputDefinition]
    ) -> [MCPInputDefinition] {
        let pattern = #"\$\{input:([^}]+)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = value as NSString
        var seen = Set<String>()
        return regex.matches(in: value, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            let raw = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let input = inputs[raw], seen.insert(raw).inserted else { return nil }
            return input
        }
    }

    // MARK: - MCP Registry server.json parser

    private struct RegistryManifestServerOption {
        let label: String
        let source: String
        var server: ParsedServer? = nil
        var archiveURL: URL? = nil
        var archiveSHA256: String? = nil
    }

    private static func registryManifestServers(in obj: [String: Any]) -> [ParsedServer]? {
        registryManifestOptions(in: obj).map { $0.compactMap(\.server) }
    }

    private static func registryManifestImportChoices(from raw: String) -> [ParsedImportChoice]? {
        let clean = ConfigWriter.stripJsonComments(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let data = clean.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let options = registryManifestOptions(in: obj) else {
            return nil
        }
        return options.map { option in
            ParsedImportChoice(
                label: option.label,
                source: option.source,
                rawText: raw,
                servers: option.server.map { [$0] } ?? [],
                archiveURL: option.archiveURL,
                archiveSHA256: option.archiveSHA256
            )
        }
    }

    private static func registryManifestOptions(in obj: [String: Any]) -> [RegistryManifestServerOption]? {
        guard obj["packages"] != nil || obj["remotes"] != nil else { return nil }
        let baseName = registryBaseName(from: obj)
        var options: [RegistryManifestServerOption] = []
        var usedNames = Set<String>()

        func append(
            label: String,
            source: String,
            name suffix: String?,
            config: [String: Any],
            credentialRequirements: [ImportCredentialRequirement] = []
        ) {
            let rawName = suffix.map { "\(baseName)-\($0)" } ?? baseName
            var name = cleanName(rawName)
            if usedNames.contains(name) {
                var counter = 2
                while usedNames.contains("\(name)-\(counter)") { counter += 1 }
                name = "\(name)-\(counter)"
            }
            usedNames.insert(name)
            options.append(RegistryManifestServerOption(
                label: label,
                source: source,
                server: ParsedServer(
                    name: name,
                    config: normalizeServerConfig(config),
                    credentialRequirements: credentialRequirements
                )
            ))
        }

        func appendArchive(label: String, source: String, archiveURL: URL, archiveSHA256: String?) {
            options.append(RegistryManifestServerOption(
                label: label,
                source: source,
                archiveURL: archiveURL,
                archiveSHA256: archiveSHA256
            ))
        }

        if let remotes = obj["remotes"] as? [[String: Any]] {
            for (index, remote) in remotes.enumerated() {
                guard let url = stringValue(remote["url"]) else { continue }
                let transport = normalizedTransport(stringValue(remote["type"]) ?? "streamable-http") ?? "http"
                let sourceTransport = transport == "sse" ? "SSE" : "HTTP"
                var config: [String: Any] = [
                    "type": transport,
                    "url": registryURLWithVariables(url, variables: remote["variables"] as? [String: Any])
                ]
                var credentialRequirements = registryURLVariableRequirements(
                    remote["variables"] as? [String: Any],
                    source: "registry remote URL variable"
                )
                let headers = registryKeyValueInputs(remote["headers"], placeholderPrefix: nil)
                if !headers.isEmpty { config["headers"] = headers }
                credentialRequirements.append(contentsOf: registryKeyValueRequirements(
                    remote["headers"],
                    kind: .header,
                    placeholderPrefix: nil,
                    source: "registry remote header"
                ))
                let suffix = remotes.count == 1 ? nil : (transport == "sse" ? "sse" : "http-\(index + 1)")
                append(
                    label: "Registry \(sourceTransport) remote",
                    source: "MCP Registry \(sourceTransport) remote: \(url)",
                    name: suffix,
                    config: config,
                    credentialRequirements: credentialRequirements
                )
            }
        }

        if let packages = obj["packages"] as? [[String: Any]] {
            for package in packages {
                let registryType = stringValue(package["registryType"])?.lowercased()
                let identifier = stringValue(package["identifier"]) ?? "package"
                if registryType == "mcpb",
                   let archiveURL = parseURL(identifier) {
                    appendArchive(
                        label: "Registry MCPB package",
                        source: "MCP Registry MCPB package: \(identifier)",
                        archiveURL: archiveURL,
                        archiveSHA256: stringValue(package["fileSha256"])
                    )
                    continue
                }
                guard let packageConfig = registryPackageConfig(package) else { continue }
                append(
                    label: registryPackageChoiceLabel(registryType),
                    source: registryPackageChoiceSource(registryType, identifier: identifier),
                    name: registryType,
                    config: packageConfig.config,
                    credentialRequirements: packageConfig.credentialRequirements
                )
            }
        }

        return options
    }

    private static func registryBaseName(from obj: [String: Any]) -> String {
        if let name = stringValue(obj["name"]) {
            return cleanName(String(name.split(separator: "/").last.map(String.init) ?? name))
        }
        if let title = stringValue(obj["title"]) {
            return cleanName(title)
        }
        return "registry-server"
    }

    private static func registryPackageConfig(_ package: [String: Any]) -> (config: [String: Any], credentialRequirements: [ImportCredentialRequirement])? {
        guard let registryType = stringValue(package["registryType"])?.lowercased(),
              let identifier = stringValue(package["identifier"]) else { return nil }

        if let transport = package["transport"] as? [String: Any],
           let transportType = normalizedTransport(stringValue(transport["type"])),
           transportType != "stdio",
           let url = stringValue(transport["url"]) {
            var config: [String: Any] = [
                "type": transportType,
                "url": registryURLWithVariables(url, variables: transport["variables"] as? [String: Any])
            ]
            var credentialRequirements = registryURLVariableRequirements(
                transport["variables"] as? [String: Any],
                source: "registry package URL variable"
            )
            let headers = registryKeyValueInputs(transport["headers"], placeholderPrefix: nil)
            if !headers.isEmpty { config["headers"] = headers }
            credentialRequirements.append(contentsOf: registryKeyValueRequirements(
                transport["headers"],
                kind: .header,
                placeholderPrefix: nil,
                source: "registry package header"
            ))
            return (config, credentialRequirements)
        }

        let env = registryKeyValueInputs(package["environmentVariables"], placeholderPrefix: nil)
        let envRequirements = registryKeyValueRequirements(
            package["environmentVariables"],
            kind: .env,
            placeholderPrefix: nil,
            source: "registry package environment variable"
        )
        let runtimeArgs = registryArguments(package["runtimeArguments"])
        let packageArgs = registryArguments(package["packageArguments"])

        var config: [String: Any]
        switch registryType {
        case "npm":
            config = [
                "command": "npx",
                "args": runtimeArgs + ["-y", identifier] + packageArgs
            ]
        case "pypi":
            config = [
                "command": "uvx",
                "args": runtimeArgs + [identifier] + packageArgs
            ]
        case "oci":
            var args = ["run", "-i", "--rm"] + runtimeArgs
            for key in env.keys.sorted() {
                args.append("--env")
                args.append(key)
            }
            args.append(identifier)
            args.append(contentsOf: packageArgs)
            config = ["command": "docker", "args": args]
        case "nuget":
            config = [
                "command": stringValue(package["runtimeHint"]) ?? "dnx",
                "args": runtimeArgs + [identifier] + packageArgs
            ]
        default:
            return nil
        }

        if !env.isEmpty { config["env"] = env }
        return (config, envRequirements)
    }

    private static func registryPackageChoiceLabel(_ registryType: String?) -> String {
        switch registryType {
        case "npm": return "Registry npm package"
        case "pypi": return "Registry PyPI package"
        case "oci": return "Registry Docker image"
        case "nuget": return "Registry NuGet package"
        default: return "Registry package"
        }
    }

    private static func registryPackageChoiceSource(_ registryType: String?, identifier: String) -> String {
        switch registryType {
        case "npm": return "MCP Registry npm package: \(identifier)"
        case "pypi": return "MCP Registry PyPI package: \(identifier)"
        case "oci": return "MCP Registry Docker image: \(identifier)"
        case "nuget": return "MCP Registry NuGet package: \(identifier)"
        default: return "MCP Registry package: \(identifier)"
        }
    }

    private static func registryKeyValueInputs(_ value: Any?, placeholderPrefix: String?) -> [String: String] {
        var out: [String: String] = [:]
        for (name, input) in registryKeyValueInputRecords(value) {
            out[name] = registryInputValue(input, fallbackName: placeholderPrefix.map { "\($0)_\(name)" } ?? name)
        }
        return out
    }

    private static func registryKeyValueRequirements(
        _ value: Any?,
        kind: ImportCredentialRequirement.Kind,
        placeholderPrefix: String?,
        source: String
    ) -> [ImportCredentialRequirement] {
        registryInputRecords(value).flatMap { record in
            let name = record.name
            let input = record.input
            let fallbackName = placeholderPrefix.map { "\($0)_\(name)" } ?? name
            let nested = registryInputVariableRequirements(
                input,
                kind: kind,
                name: name,
                fallbackName: fallbackName,
                source: source
            )
            if !nested.isEmpty { return nested }
            let placeholder = registryInputValue(input, fallbackName: fallbackName)
            guard let envName = registryPlaceholderEnvName(placeholder) else { return [] }
            return [.init(
                kind: kind,
                name: name,
                envName: envName,
                placeholder: placeholder,
                required: registryBool(input["isRequired"]) ?? false,
                secret: registryBool(input["isSecret"]) ?? false,
                description: stringValue(input["description"]),
                source: source
            )]
        }
    }

    private struct RegistryInputRecord {
        let name: String
        let input: [String: Any]
        let metadataBacked: Bool
    }

    private static func registryKeyValueInputRecords(_ value: Any?) -> [(name: String, input: [String: Any])] {
        registryInputRecords(value).map { (name: $0.name, input: $0.input) }
    }

    private static func registryInputRecords(_ value: Any?) -> [RegistryInputRecord] {
        if let inputs = value as? [[String: Any]] {
            return inputs.compactMap { input in
                guard let name = stringValue(input["name"]) else { return nil }
                return .init(name: name, input: input, metadataBacked: true)
            }
        }
        guard let map = value as? [String: Any] else { return [] }
        return map.keys.sorted().compactMap { name in
            let raw = map[name]
            if var input = raw as? [String: Any] {
                input["name"] = name
                return .init(name: name, input: input, metadataBacked: true)
            }
            if let scalar = stringValue(raw) {
                return .init(name: name, input: ["name": name, "value": scalar], metadataBacked: false)
            }
            return nil
        }
    }

    private static func registryURLVariableRequirements(
        _ variables: [String: Any]?,
        source: String
    ) -> [ImportCredentialRequirement] {
        registryInputRecords(variables).compactMap { record in
            let input = record.input
            let placeholder = registryInputValue(input, fallbackName: record.name)
            guard let envName = registryPlaceholderEnvName(placeholder) else { return nil }
            return .init(
                kind: .urlVariable,
                name: record.name,
                envName: envName,
                placeholder: placeholder,
                required: registryBool(input["isRequired"]) ?? false,
                secret: registryBool(input["isSecret"]) ?? false,
                description: stringValue(input["description"]),
                source: source
            )
        }
    }

    private static func registryArguments(_ value: Any?) -> [String] {
        guard let args = value as? [[String: Any]] else { return [] }
        var out: [String] = []
        for arg in args {
            let kind = stringValue(arg["type"])?.lowercased()
            if kind == "named", let name = stringValue(arg["name"]) {
                out.append(name)
                out.append(registryInputValue(arg, fallbackName: name))
            } else {
                out.append(registryInputValue(arg, fallbackName: stringValue(arg["valueHint"]) ?? "ARG"))
            }
        }
        return out
    }

    private static func registryInputValue(_ input: [String: Any], fallbackName: String) -> String {
        if let value = stringValue(input["value"]) {
            return registryValueWithVariables(value, variables: input["variables"] as? [String: Any])
        }
        if let value = stringValue(input["default"]) {
            return registryValueWithVariables(value, variables: input["variables"] as? [String: Any])
        }
        return "${\(registryEnvName(from: fallbackName))}"
    }

    private static func registryPlaceholderEnvName(_ value: String) -> String? {
        let pattern = #"\$\{([A-Za-z_][A-Za-z0-9_]*)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsValue = value as NSString
        let matches = regex.matches(in: value, range: NSRange(location: 0, length: nsValue.length))
        guard matches.count == 1,
              let match = matches.first,
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: value) else {
            return nil
        }
        return String(value[range])
    }

    private static func registryValueWithVariables(_ value: String, variables: [String: Any]?) -> String {
        var resolved = value
        for record in registryInputRecords(variables) {
            let variableValue = registryInputValue(record.input, fallbackName: record.name)
            resolved = resolved.replacingOccurrences(of: "{\(record.name)}", with: variableValue)
        }
        return resolved
    }

    private static func registryInputVariableRequirements(
        _ input: [String: Any],
        kind: ImportCredentialRequirement.Kind,
        name: String,
        fallbackName: String,
        source: String
    ) -> [ImportCredentialRequirement] {
        let records = registryInputRecords(input["variables"])
        guard !records.isEmpty else { return [] }
        return records.compactMap { record in
            let placeholder = registryInputValue(record.input, fallbackName: record.name)
            guard let envName = registryPlaceholderEnvName(placeholder) else { return nil }
            return .init(
                kind: kind,
                name: name,
                envName: envName,
                placeholder: placeholder,
                required: registryBool(record.input["isRequired"]) ?? registryBool(input["isRequired"]) ?? false,
                secret: registryBool(record.input["isSecret"]) ?? registryBool(input["isSecret"]) ?? false,
                description: stringValue(record.input["description"]) ?? stringValue(input["description"]),
                source: "\(source) nested variable"
            )
        }
    }

    private static func registryBool(_ value: Any?) -> Bool? {
        if let bool = value as? Bool { return bool }
        if let string = stringValue(value) {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        return nil
    }

    private static func registryURLWithVariables(_ url: String, variables: [String: Any]?) -> String {
        registryValueWithVariables(url, variables: variables)
    }

    private static func registryEnvName(from raw: String) -> String {
        let scalars = raw.uppercased().unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "_"
        }
        let joined = String(scalars)
            .split(separator: "_")
            .joined(separator: "_")
        return joined.isEmpty ? "MCP_VALUE" : joined
    }

    // MARK: - Codex TOML parser

    private static func parseCodexTomlCandidate(_ raw: String) -> Result<[ParsedServer], ImportParseError>? {
        let content = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard content.contains("mcp_servers") else { return nil }

        var servers: [String: [String: Any]] = [:]
        var currentName: String?
        var currentNested: String?

        let lines = content.components(separatedBy: .newlines)
        var index = 0
        while index < lines.count {
            let line = lines[index]
            index += 1

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let sectionLine = tomlValuePart(trimmed)

            if sectionLine.hasPrefix("[") && sectionLine.hasSuffix("]") && !sectionLine.hasPrefix("[[") {
                let section = String(sectionLine.dropFirst().dropLast())
                guard let parsed = parseCodexMCPServerSection(section) else {
                    currentName = nil
                    currentNested = nil
                    continue
                }
                currentName = parsed.name
                currentNested = parsed.nested
                if servers[parsed.name] == nil { servers[parsed.name] = [:] }
                continue
            }

            guard let currentName else { continue }
            guard let eqRange = trimmed.range(of: " = ") ?? trimmed.range(of: "=") else { continue }
            let key = String(trimmed[trimmed.startIndex..<eqRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            var rawValue = String(trimmed[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            while tomlValueStartsCollection(rawValue), !tomlCollectionIsComplete(rawValue), index < lines.count {
                rawValue += "\n" + lines[index].trimmingCharacters(in: .whitespaces)
                index += 1
            }

            let keyParts = splitTomlDottedKey(key)
            let normalizedKey = keyParts.joined(separator: ".")
            let value = normalizedKey == "env_vars" ? parseCodexEnvVars(rawValue) : parseTomlScalarValue(rawValue)

            if let currentNested {
                guard ["env", "headers", "http_headers", "env_http_headers"].contains(currentNested) else { continue }
                var nested = stringDict(servers[currentName]?[currentNested])
                nested[normalizedKey] = "\(value)"
                servers[currentName]?[currentNested] = nested
            } else if keyParts.count >= 2,
                      ["env", "headers", "http_headers", "env_http_headers"].contains(keyParts[0]) {
                let nestedName = keyParts[0]
                let nestedKey = keyParts.dropFirst().joined(separator: ".")
                var nested = stringDict(servers[currentName]?[nestedName])
                nested[nestedKey] = "\(value)"
                servers[currentName]?[nestedName] = nested
            } else {
                servers[currentName]?[normalizedKey] = value
            }
        }

        let parsed = servers.compactMap { name, props -> ParsedServer? in
            let normalized = normalizeCodexTomlServerConfig(props)
            guard isInstallableServer(normalized) else { return nil }
            return ParsedServer(name: name, config: normalized)
        }.sorted { $0.name.lowercased() < $1.name.lowercased() }

        return parsed.isEmpty ? .failure(.noServersFound) : .success(parsed)
    }

    private static func normalizeCodexTomlServerConfig(_ props: [String: Any]) -> [String: Any] {
        var config = props
        var headers = stringDict(config["headers"])
        headers.merge(stringDict(config["http_headers"])) { _, new in new }
        if let envHeaders = config["env_http_headers"] as? [String: String] {
            for (header, envName) in envHeaders {
                headers[header] = "${\(envName)}"
            }
        }
        if !headers.isEmpty { config["headers"] = headers }

        return normalizeServerConfig(config)
    }

    private static func parseCodexMCPServerSection(_ section: String) -> (name: String, nested: String?)? {
        let parts = splitTomlDottedKey(section)
        guard parts.count >= 2,
              parts[0] == "mcp_servers",
              !parts[1].isEmpty else { return nil }
        let nested = parts.count > 2 ? parts.dropFirst(2).joined(separator: ".") : nil
        return (parts[1], nested)
    }

    private static func parseCodexEnvVars(_ raw: String) -> [[String: String]] {
        let value = tomlValuePart(raw)
        guard value.hasPrefix("["), value.hasSuffix("]") else { return [] }
        let inner = String(value.dropFirst().dropLast())
        return splitTomlArray(inner).compactMap { item in
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            if let name = tomlStringLiteral(trimmed) {
                return ["name": name, "source": "local"]
            }
            if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
                let table = parseTomlInlineTable(trimmed)
                guard table["name"]?.isEmpty == false else { return nil }
                return table
            }
            return nil
        }
    }

    private static func parseTomlScalarValue(_ raw: String) -> Any {
        let value = tomlValuePart(raw)
        if value == "true" { return true }
        if value == "false" { return false }
        if value.hasPrefix("["), value.hasSuffix("]") {
            let inner = value.dropFirst().dropLast()
            return splitTomlArray(String(inner)).map {
                trimTomlQuotes($0.trimmingCharacters(in: .whitespaces))
            }.filter { !$0.isEmpty }
        }
        if value.hasPrefix("{"), value.hasSuffix("}") {
            return parseTomlInlineTable(value)
        }
        return trimTomlQuotes(value)
    }

    private static func parseTomlInlineTable(_ raw: String) -> [String: String] {
        let trimmed = tomlValuePart(raw)
        guard trimmed.hasPrefix("{"), trimmed.hasSuffix("}") else { return [:] }
        let inner = trimmed.dropFirst().dropLast()
        var out: [String: String] = [:]
        for pair in splitTomlArray(String(inner)) {
            guard let eq = pair.firstIndex(of: "=") else { continue }
            let key = pair[..<eq]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            let rawValue = String(pair[pair.index(after: eq)...])
            let value = "\(parseTomlScalarValue(rawValue))"
            if !key.isEmpty { out[key] = value }
        }
        return out
    }

    private static func tomlValuePart(_ raw: String) -> String {
        var inSingle = false
        var inDouble = false
        var escaped = false
        var inComment = false
        var out = ""

        for ch in raw {
            if inComment {
                if ch == "\n" {
                    inComment = false
                    out.append(ch)
                }
                continue
            }
            if escaped {
                out.append(ch)
                escaped = false
                continue
            }
            if inDouble && ch == "\\" {
                out.append(ch)
                escaped = true
                continue
            }
            if ch == "\"", !inSingle {
                inDouble.toggle()
                out.append(ch)
                continue
            }
            if ch == "'", !inDouble {
                inSingle.toggle()
                out.append(ch)
                continue
            }
            if ch == "#", !inSingle, !inDouble {
                inComment = true
                continue
            }
            out.append(ch)
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func tomlValueStartsCollection(_ raw: String) -> Bool {
        let value = tomlValuePart(raw)
        return value.hasPrefix("[") || value.hasPrefix("{")
    }

    private static func tomlCollectionIsComplete(_ raw: String) -> Bool {
        var inSingle = false
        var inDouble = false
        var escaped = false
        var bracketDepth = 0
        var braceDepth = 0

        for ch in tomlValuePart(raw) {
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

    private static func splitTomlArray(_ text: String) -> [String] {
        var items: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escaped = false
        var braceDepth = 0
        var bracketDepth = 0

        for ch in text {
            if escaped {
                current.append(ch)
                escaped = false
                continue
            }
            if inDouble && ch == "\\" {
                escaped = true
                current.append(ch)
                continue
            }
            if ch == "'", !inDouble { inSingle.toggle(); current.append(ch); continue }
            if ch == "\"", !inSingle { inDouble.toggle(); current.append(ch); continue }
            if !inSingle, !inDouble {
                if ch == "{" { braceDepth += 1 }
                if ch == "}", braceDepth > 0 { braceDepth -= 1 }
                if ch == "[" { bracketDepth += 1 }
                if ch == "]", bracketDepth > 0 { bracketDepth -= 1 }
                if ch == ",", braceDepth == 0, bracketDepth == 0 {
                    items.append(current)
                    current = ""
                    continue
                }
            }
            current.append(ch)
        }

        if !current.isEmpty { items.append(current) }
        return items
    }

    private static func splitTomlDottedKey(_ value: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escaped = false

        for ch in value {
            if escaped {
                current.append(ch)
                escaped = false
                continue
            }
            if inDouble && ch == "\\" {
                escaped = true
                current.append(ch)
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
            if ch == ".", !inSingle, !inDouble {
                parts.append(current)
                current = ""
                continue
            }
            current.append(ch)
        }

        parts.append(current)
        return parts.map { trimTomlQuotes($0.trimmingCharacters(in: .whitespaces)) }
    }

    private static func tomlStringLiteral(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2,
              (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\""))
                || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) else { return nil }
        return String(trimmed.dropFirst().dropLast())
    }

    private static func trimTomlQuotes(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 2,
           (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\""))
            || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    // MARK: - CLI command parser
    //
    // Parses `<tool> mcp add <name> [flags] <command | url> [args...]` where
    // <tool> is one of claude / cursor / codex / windsurf / gemini / zed (or omitted).
    //
    // Examples:
    //   claude mcp add context7 --transport http https://mcp.context7.com/mcp
    //   cursor mcp add filesystem --transport stdio npx -y @mcp/server-filesystem /tmp
    //   codex mcp add mytool -e API_KEY=abc npx -y my-mcp-server
    //   mcp add foo --transport sse https://example.com/sse -H Authorization=Bearer\ X
    //
    // Returns nil if the input doesn't look like an mcp-add command. Does NOT
    // throw on minor weirdness (we want JSON parsing to still get a crack at it).
    static func parseCliAddJSON(_ input: String) -> ParsedServer? {
        let tokens = shellSplit(input)
        if tokens.isEmpty { return nil }

        var i = 0
        let toolPrefixes: Set<String> = ["claude", "cursor", "codex", "windsurf", "gemini", "zed", "roo", "cline"]
        if i < tokens.count, toolPrefixes.contains(tokens[i].lowercased()) { i += 1 }

        guard i < tokens.count, tokens[i].lowercased() == "mcp" else { return nil }
        i += 1
        guard i < tokens.count, ["add-json", "addjson"].contains(tokens[i].lowercased()) else { return nil }
        i += 1

        var name: String?
        var jsonStart: Int?

        while i < tokens.count {
            let token = tokens[i]

            if ["--scope", "-s", "--timeout", "--transport"].contains(token), i + 1 < tokens.count {
                i += 2
                continue
            }
            if token.hasPrefix("--") || (token.hasPrefix("-") && token.count == 2) {
                i += 1
                continue
            }
            if name == nil {
                name = token
                i += 1
                continue
            }
            jsonStart = i
            break
        }

        guard let name,
              let jsonStart,
              jsonStart < tokens.count else { return nil }

        let jsonText = Array(tokens[jsonStart...]).joined(separator: " ")
        let candidate = firstJSONObject(in: jsonText) ?? jsonText
        guard let data = ConfigWriter.stripJsonComments(candidate).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let wrapped = wrappedServers(in: obj),
           wrapped.count == 1,
           let server = wrapped.first {
            return ParsedServer(name: name, config: server.config)
        }

        let normalized = normalizeServerConfig(obj)
        guard isInstallableServer(normalized) else { return nil }
        return ParsedServer(name: name, config: normalized)
    }

    static func parseCliAdd(_ input: String) -> ParsedServer? {
        let tokens = shellSplit(input)
        if tokens.isEmpty { return nil }

        var i = 0
        let toolPrefixes: Set<String> = ["claude", "cursor", "codex", "windsurf", "gemini", "zed", "roo", "cline"]
        if i < tokens.count, toolPrefixes.contains(tokens[i].lowercased()) { i += 1 }

        guard i < tokens.count, tokens[i].lowercased() == "mcp" else { return nil }
        i += 1
        guard i < tokens.count, tokens[i].lowercased() == "add" else { return nil }
        i += 1

        var name: String?
        var transport = "stdio"
        var env: [String: String] = [:]
        var headers: [String: String] = [:]
        var remoteURL: String?
        var bearerTokenEnvVar: String?
        var oauth: [String: Any] = [:]
        var launchTokens: [String] = []
        var launchStarted = false

        func splitLongOption(_ token: String) -> (name: String, inlineValue: String?) {
            guard token.hasPrefix("--"), let eq = token.firstIndex(of: "=") else {
                return (token, nil)
            }
            return (String(token[..<eq]), String(token[token.index(after: eq)...]))
        }

        func readFlagValue(_ inlineValue: String?) -> String? {
            if let inlineValue {
                i += 1
                return inlineValue
            }
            i += 1
            guard i < tokens.count else { return nil }
            let value = tokens[i]
            i += 1
            return value
        }

        func recordHeader(_ raw: String) {
            if let eq = raw.firstIndex(of: "="), eq > raw.startIndex {
                let key = String(raw[..<eq])
                let value = String(raw[raw.index(after: eq)...])
                headers[key] = value
            } else if let colon = raw.firstIndex(of: ":"), colon > raw.startIndex {
                let key = String(raw[..<colon])
                let value = String(raw[raw.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        func recordEnv(_ raw: String) {
            if let assignment = envAssignment(raw) {
                env[assignment.key] = assignment.value
            } else if isEnvName(raw) {
                env[raw] = "${\(raw)}"
            }
        }

        func parseRecognizedFlag(_ token: String) -> Bool {
            let parsed = splitLongOption(token)
            let option = parsed.name

            switch option {
            case "--transport", "-t":
                if let value = readFlagValue(parsed.inlineValue) {
                    transport = (value == "http" || value == "sse" || value == "stdio") ? value : "stdio"
                }
                return true
            case "--url":
                if let value = readFlagValue(parsed.inlineValue) {
                    transport = "http"
                    remoteURL = value
                }
                return true
            case "--bearer-token-env-var":
                if let value = readFlagValue(parsed.inlineValue) {
                    bearerTokenEnvVar = value
                }
                return true
            case "--env", "-e":
                if let value = readFlagValue(parsed.inlineValue) {
                    recordEnv(value)
                }
                return true
            case "--header", "-H":
                if let value = readFlagValue(parsed.inlineValue) {
                    recordHeader(value)
                }
                return true
            case "--name":
                if let value = readFlagValue(parsed.inlineValue), name == nil {
                    name = value
                }
                return true
            case "--scope", "-s", "--timeout", "--channels":
                _ = readFlagValue(parsed.inlineValue)
                return true
            case "--client-id":
                if let value = readFlagValue(parsed.inlineValue) {
                    oauth["clientId"] = value
                }
                return true
            case "--callback-port":
                if let value = readFlagValue(parsed.inlineValue) {
                    oauth["callbackPort"] = Int(value) ?? value
                }
                return true
            case "--auth-server-metadata-url":
                if let value = readFlagValue(parsed.inlineValue) {
                    oauth["authServerMetadataUrl"] = value
                }
                return true
            case "--scopes":
                if let value = readFlagValue(parsed.inlineValue) {
                    oauth["scopes"] = value
                }
                return true
            case "--client-secret":
                // Claude stores the secret through its credential flow/keychain, not in MCP JSON.
                i += 1
                return true
            default:
                return false
            }
        }

        while i < tokens.count {
            let tok = tokens[i]

            if tok == "--" {
                i += 1
                launchTokens = Array(tokens[i...])
                i = tokens.count
                continue
            }

            if (transport == "http" || transport == "sse" || !launchStarted),
               parseRecognizedFlag(tok) {
                continue
            }

            if name == nil {
                guard !tok.hasPrefix("-") else { return nil }
                name = tok
                i += 1
                continue
            }

            if remoteURL == nil, parseURL(tok) != nil {
                transport = transport == "sse" ? "sse" : "http"
                remoteURL = tok
                i += 1
                continue
            }

            if transport == "http" || transport == "sse" {
                if remoteURL == nil {
                    remoteURL = tok
                }
                i += 1
                continue
            }

            launchStarted = true
            launchTokens.append(tok)
            i += 1
        }

        guard let name else { return nil }
        if launchTokens.isEmpty && remoteURL == nil { return nil }

        var config: [String: Any] = [:]

        if transport == "http" || transport == "sse" {
            guard let url = remoteURL ?? launchTokens.first else { return nil }
            config["url"] = url
            if !headers.isEmpty { config["headers"] = headers }
            if let bearerTokenEnvVar { config["bearer_token_env_var"] = bearerTokenEnvVar }
            if !oauth.isEmpty { config["oauth"] = oauth }
            config["type"] = transport  // remote servers want an explicit type
        } else {
            guard let launch = normalizeLaunchTokens(launchTokens) else { return nil }
            config["command"] = launch.command
            if !launch.args.isEmpty { config["args"] = launch.args }
            env.merge(launch.env) { current, _ in current }
            if let envFile = launch.envFile { config["envFile"] = envFile }
        }

        if !env.isEmpty { config["env"] = env }

        return ParsedServer(name: name, config: config)
    }

    static func parseBareCommand(_ input: String) -> ParsedServer? {
        let tokens = shellSplit(input)
        guard let launch = normalizeLaunchTokens(tokens),
              commandStarters.contains(launch.command.lowercased()) else { return nil }
        if tokens.contains("mcp"), tokens.contains("add") { return nil }

        var config: [String: Any] = [
            "command": launch.command,
            "args": launch.args
        ]
        if !launch.env.isEmpty { config["env"] = launch.env }
        if let envFile = launch.envFile { config["envFile"] = envFile }
        return ParsedServer(name: inferredName(from: config), config: config)
    }

    /// Minimal shell tokenizer — handles single / double quoted strings and
    /// backslash escapes. Not POSIX complete, but plenty for `mcp add` pastes.
    static func shellSplit(_ input: String) -> [String] {
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
                inSingle.toggle(); continue
            }
            if ch == "\"" && !inSingle {
                inDouble.toggle(); continue
            }
            if ch.isWhitespace && !inSingle && !inDouble {
                if !current.isEmpty { tokens.append(current); current = "" }
                continue
            }
            current.append(ch)
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    // Returns true for prompt-driven `mcp add` installers hidden behind package runners.
    // Direct `mcp add` remains safe when it includes enough config for parseCliAdd.
    private static func isWizardCommand(_ input: String) -> Bool {
        let tokens = shellSplit(input)
        guard tokens.count >= 2 else { return false }
        let first = tokens[0].lowercased()
        if first == "mcp", tokens.count >= 2, tokens[1].lowercased() == "add" {
            return parseCliAdd(input) == nil
        }
        guard ["npx", "npm", "pnpm", "yarn", "bunx", "bun", "uvx", "uv", "pipx", "px"].contains(first) else { return false }
        // Look for "mcp add" anywhere after the package runner and runner flags.
        for i in 1..<max(1, tokens.count - 1) {
            if tokens[i].lowercased() == "mcp" && tokens[i + 1].lowercased() == "add" {
                return true
            }
        }
        return false
    }

    private static let commandStarters: Set<String> = [
        "npx", "npm", "pnpm", "yarn", "bunx", "bun",
        "uvx", "uv", "python", "python3", "pipx",
        "docker", "node", "deno", "brew", "cargo", "go"
    ]

    private static func normalizeLaunchTokens(_ rawTokens: [String]) -> (env: [String: String], envFile: String?, command: String, args: [String])? {
        let tokens = expandEnvSplitString(rawTokens)
        guard !tokens.isEmpty else { return nil }
        var index = 0
        var env: [String: String] = [:]
        var envFile: String?

        if isEnvCommand(tokens[index]) {
            index += 1
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
                if token.hasPrefix("-") { return nil }
                if let assignment = envAssignment(token) {
                    env[assignment.key] = assignment.value
                    index += 1
                    continue
                }
                if isEnvName(token),
                   index + 1 < tokens.count,
                   commandStarters.contains(URL(fileURLWithPath: tokens[index + 1]).lastPathComponent.lowercased()) {
                    env[token] = "${\(token)}"
                    index += 1
                    continue
                }
                break
            }
        } else {
            while index < tokens.count, let assignment = envAssignment(tokens[index]) {
                env[assignment.key] = assignment.value
                index += 1
            }
        }

        guard index < tokens.count else { return nil }
        let command = tokens[index]
        let args = Array(tokens.dropFirst(index + 1))
        if URL(fileURLWithPath: command).lastPathComponent.lowercased() == "docker" {
            env.merge(dockerEnvFlags(in: args)) { current, _ in current }
            envFile = dockerEnvFiles(in: args).first
        }
        return (env, envFile, command, args)
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
              first == "_" || CharacterSet.uppercaseLetters.contains(first) || CharacterSet.lowercaseLetters.contains(first) else {
            return false
        }
        return value.unicodeScalars.allSatisfy {
            $0 == "_" || CharacterSet.alphanumerics.contains($0)
        }
    }

    private static func dockerEnvFlags(in args: [String]) -> [String: String] {
        var env: [String: String] = [:]
        var index = 0
        while index < args.count {
            let token = args[index]
            if token == "-e" || token == "--env" {
                index += 1
                if index < args.count {
                    recordDockerEnv(args[index], into: &env)
                }
            } else if token.hasPrefix("--env=") {
                recordDockerEnv(String(token.dropFirst("--env=".count)), into: &env)
            } else if token.hasPrefix("-e"), token.count > 2 {
                recordDockerEnv(String(token.dropFirst(2)), into: &env)
            }
            index += 1
        }
        return env
    }

    private static func dockerEnvFiles(in args: [String]) -> [String] {
        var files: [String] = []
        var index = 0
        while index < args.count {
            let token = args[index]
            if token == "--env-file" {
                index += 1
                if index < args.count {
                    files.append(args[index])
                }
            } else if token.hasPrefix("--env-file=") {
                files.append(String(token.dropFirst("--env-file=".count)))
            }
            index += 1
        }
        return files.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func recordDockerEnv(_ raw: String, into env: inout [String: String]) {
        if let assignment = envAssignment(raw) {
            env[assignment.key] = assignment.value
        } else if isEnvName(raw) {
            env[raw] = "${\(raw)}"
        }
    }

    private static func isLaunchCommandCandidate(_ input: String) -> Bool {
        guard let launch = normalizeLaunchTokens(shellSplit(input)) else { return false }
        return shouldSplitCommandString(firstToken: launch.command)
    }

    private static func candidates(from raw: String) -> [String] {
        var out = [raw]
        out.append(contentsOf: fencedCodeBlocks(in: raw))

        let lines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            let cleaned = line
                .trimmingCharacters(in: CharacterSet(charactersIn: "$> "))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }
            if cleaned.contains("mcp add")
                || isLaunchCommandCandidate(cleaned)
                || parseURL(cleaned) != nil {
                out.append(cleaned)
            }
        }

        if let json = firstJSONObject(in: raw) {
            out.append(json)
        }

        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }
    }

    private static func fencedCodeBlocks(in raw: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"```[A-Za-z0-9_-]*\s*([\s\S]*?)```"#) else { return [] }
        let ns = raw as NSString
        return regex.matches(in: raw, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func firstJSONObject(in raw: String) -> String? {
        guard let start = raw.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        var index = start

        while index < raw.endIndex {
            let ch = raw[index]
            if escaped {
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else if ch == "\"" {
                inString.toggle()
            } else if !inString {
                if ch == "{" { depth += 1 }
                if ch == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(raw[start...index])
                    }
                }
            }
            index = raw.index(after: index)
        }
        return nil
    }

    private static func parseDirectURL(_ input: String) -> ParsedServer? {
        guard let url = parseURL(input) else { return nil }
        if githubContentFetch(from: input) != nil
            || looksLikeRemoteConfigDocumentURL(input)
            || looksLikeGitHubRepository(input)
            || looksLikeArchive(input)
            || githubReleaseOrArchiveURL(from: input) { return nil }
        let transport = url.path.lowercased().contains("sse") ? "sse" : "http"
        return ParsedServer(
            name: cleanName(url.host ?? "remote-mcp"),
            config: ["type": transport, "url": url.absoluteString]
        )
    }

    private static func parseURL(_ input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: CharacterSet(charactersIn: "<>\"' "))
        guard let url = URL(string: trimmed), ["http", "https"].contains(url.scheme ?? "") else { return nil }
        return url
    }

    private static func looksLikeRemoteConfigDocumentURL(_ input: String) -> Bool {
        guard let url = parseURL(input) else { return false }
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        let last = URL(fileURLWithPath: path).lastPathComponent

        if host == "gist.githubusercontent.com", path.contains("/raw") {
            return true
        }
        if host == "pastebin.com", path == "/raw" || path.hasPrefix("/raw/") || path.hasPrefix("/raw.php") {
            return true
        }

        return last == "server.json"
            || isMCPConfigDocumentFilename(last)
            || last == "claude_desktop_config.json"
            || last == "claude-desktop-config.json"
            || path == "/.codex/config.toml"
            || path.hasSuffix("/.codex/config.toml")
    }

    private static func looksLikeGitHubRepository(_ input: String) -> Bool {
        guard let url = parseURL(input), url.host?.lowercased() == "github.com" else { return false }
        let parts = url.path.split(separator: "/")
        guard parts.count >= 2 else { return false }
        return !url.path.contains("/raw/") && !url.path.contains("/releases/download/")
    }

    static func githubReleaseOrArchiveURL(from input: String) -> Bool {
        guard let url = parseURL(input), url.host?.lowercased() == "github.com" else { return false }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 3 else { return false }
        if parts[2] == "releases" { return true }
        if parts[2] == "archive" { return true }
        return false
    }

    private static func looksLikeArchive(_ input: String) -> Bool {
        let lower = input.lowercased()
        return [".zip", ".tar.gz", ".tgz", ".dxt", ".mcpb"].contains { lower.contains($0) }
    }

    private static func isSupportedDesktopExtensionArchive(_ path: String) -> Bool {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return ["mcpb", "dxt", "zip"].contains(ext)
    }

    private static func isStrictDesktopExtensionArchive(_ path: String) -> Bool {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return ext == "mcpb" || ext == "dxt"
    }

    private static func isSupportedSourceArchive(_ path: String) -> Bool {
        let lower = path.lowercased()
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return ext == "zip" || lower.hasSuffix(".tar.gz") || lower.hasSuffix(".tgz")
    }

    private static func isSupportedLocalArchive(_ path: String) -> Bool {
        isSupportedDesktopExtensionArchive(path) || isSupportedSourceArchive(path)
    }

    private static func archiveList(_ archivePath: String) -> [String]? {
        let lower = archivePath.lowercased()
        if lower.hasSuffix(".tar.gz") || lower.hasSuffix(".tgz") {
            guard let text = runProcess("/usr/bin/tar", ["-tf", archivePath]) else { return nil }
            let entries = text
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return entries.isEmpty ? nil : entries
        }
        return unzipList(archivePath)
    }

    private static func archiveEntryText(archivePath: String, entryPath: String) -> String? {
        let lower = archivePath.lowercased()
        if lower.hasSuffix(".tar.gz") || lower.hasSuffix(".tgz") {
            return runProcess("/usr/bin/tar", ["-xOf", archivePath, entryPath])
        }
        return unzipEntry(archivePath: archivePath, entryPath: entryPath)
    }

    private static func sourceArchiveCandidateEntries(_ entries: [String]) -> [String] {
        entries
            .filter { entry in
                let lower = entry.lowercased()
                guard !entry.hasSuffix("/") else { return false }
                guard !lower.contains("/__macosx/"),
                      !lower.hasPrefix("__macosx/"),
                      !lower.contains("/node_modules/"),
                      !lower.contains("/.git/"),
                      !lower.contains("/vendor/") else { return false }
                let last = URL(fileURLWithPath: lower).lastPathComponent
                guard !["package-lock.json", "pnpm-lock.yaml", "yarn.lock", "bun.lockb"].contains(last) else { return false }
                return sourceArchiveEntryScore(entry) != nil
            }
            .sorted { left, right in
                let leftScore = sourceArchiveEntryScore(left) ?? 999
                let rightScore = sourceArchiveEntryScore(right) ?? 999
                if leftScore != rightScore { return leftScore < rightScore }
                return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
            }
    }

    private static func sourceArchiveEntryScore(_ entry: String) -> Int? {
        let lower = entry.lowercased()
        let last = URL(fileURLWithPath: lower).lastPathComponent
        if last == "server.json" { return 0 }
        if isMCPConfigDocumentFilename(last) { return 1 }
        if lower == ".codex/config.toml" || lower.hasSuffix("/.codex/config.toml") { return 2 }
        if last == "claude_desktop_config.json" || last == "claude-desktop-config.json" { return 2 }
        if last == "README.md".lowercased() || last == "README.markdown".lowercased() { return 3 }
        if lower.contains("/docs/") || lower.contains("/examples/") {
            if last.hasPrefix("mcp") && (last.hasSuffix(".json") || last.hasSuffix(".jsonc")) { return 4 }
            if last.contains("install") || last.contains("setup") || last.contains("readme") { return 5 }
        }
        if last.hasSuffix(".md") || last.hasSuffix(".markdown") { return 6 }
        if last.hasSuffix(".json") || last.hasSuffix(".jsonc") { return 7 }
        if last.hasSuffix(".txt") { return 8 }
        return nil
    }

    private static func isMCPConfigDocumentFilename(_ lastPathComponent: String) -> Bool {
        [
            "mcp.json",
            "mcp-fetch.json",
            ".mcp.json",
            "mcp_settings.json",
            "cline_mcp_settings.json"
        ].contains(lastPathComponent.lowercased())
    }

    private static func unzipList(_ archivePath: String) -> [String]? {
        guard let text = runProcess("/usr/bin/unzip", ["-Z1", archivePath]) else { return nil }
        let entries = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return entries.isEmpty ? nil : entries
    }

    private static func unzipEntry(archivePath: String, entryPath: String) -> String? {
        runProcess("/usr/bin/unzip", ["-p", archivePath, entryPath])
    }

    private static func runProcess(_ executable: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private static func authorName(_ value: Any?) -> String? {
        if let author = stringValue(value) { return author }
        if let author = value as? [String: Any] { return stringValue(author["name"]) }
        return nil
    }

    private static func desktopExtensionManifestDeclaresIdentity(_ manifest: [String: Any]) -> Bool {
        stringValue(manifest["mcpb_version"]) != nil
            || stringValue(manifest["dxt_version"]) != nil
            || stringValue(manifest["manifest_version"]) != nil
            || ((manifest["server"] as? [String: Any])?["mcp_config"] as? [String: Any]) != nil
    }

    private static func desktopExtensionManifestIsValid(_ manifest: [String: Any]) -> Bool {
        guard desktopExtensionManifestDeclaresIdentity(manifest),
              stringValue(manifest["name"]) != nil,
              stringValue(manifest["version"]) != nil,
              stringValue(manifest["description"]) != nil,
              authorName(manifest["author"]) != nil,
              let server = manifest["server"] as? [String: Any],
              desktopExtensionServerHasLaunchConfig(server),
              desktopExtensionCommandPreview(manifest) != nil else {
            return false
        }
        return true
    }

    private static func desktopExtensionServerHasLaunchConfig(_ server: [String: Any]) -> Bool {
        if server["mcp_config"] is [String: Any] { return true }
        guard stringValue(server["type"])?.lowercased() == "uv" else { return false }
        return stringValue(server["entry_point"]) != nil
    }

    private static func desktopExtensionCommandPreview(_ manifest: [String: Any]) -> String? {
        guard let server = manifest["server"] as? [String: Any] else { return nil }
        guard let config = server["mcp_config"] as? [String: Any] else {
            guard stringValue(server["type"])?.lowercased() == "uv",
                  let entryPoint = stringValue(server["entry_point"]) else { return nil }
            return "uv \(entryPoint) (Claude Desktop managed)"
        }
        if let url = stringValue(config["url"]) { return url }
        guard let command = stringValue(config["command"]) else { return nil }
        let args = config["args"] as? [String] ?? []
        return ([command] + args).joined(separator: " ")
    }

    private static func desktopExtensionToolNames(_ manifest: [String: Any]) -> [String] {
        guard let tools = manifest["tools"] as? [[String: Any]] else { return [] }
        return tools.compactMap { stringValue($0["name"]) }.sorted()
    }

    private static func desktopExtensionRequiredUserConfig(_ manifest: [String: Any]) -> [String] {
        guard let userConfig = manifest["user_config"] as? [String: Any] else { return [] }
        return userConfig.compactMap { key, value in
            guard let config = value as? [String: Any],
                  (config["required"] as? Bool) == true else { return nil }
            return key
        }.sorted()
    }

    private static func normalizeServerConfig(_ config: [String: Any]) -> [String: Any] {
        var out = config
        if out["url"] == nil {
            for key in ["serverUrl", "server_url", "endpoint", "endpointUrl", "endpoint_url"] {
                if let url = stringValue(out[key]) {
                    out["url"] = url
                    break
                }
            }
        }
        if out["headers"] == nil, let headers = out["http_headers"] {
            out["headers"] = headers
        }
        if out["headers"] == nil, let headers = out["request_headers"] {
            out["headers"] = headers
        }
        if out["env"] == nil, let env = out["environment"] as? [String: Any] {
            out["env"] = env
        }
        if out["envFile"] == nil, let envFile = stringValue(out["env_file"]) {
            out["envFile"] = envFile
        }
        if out["sandboxEnabled"] == nil, let sandboxEnabled = out["sandbox_enabled"] {
            out["sandboxEnabled"] = sandboxEnabled
        }
        if out["alwaysAllow"] == nil, let alwaysAllow = out["always_allow"] {
            out["alwaysAllow"] = alwaysAllow
        }
        if out["disabledTools"] == nil, let disabledTools = out["disabled_tools"] {
            out["disabledTools"] = disabledTools
        }
        if out["enabledTools"] == nil, let enabledTools = out["enabled_tools"] {
            out["enabledTools"] = enabledTools
        }
        if out["defaultToolApprovalMode"] == nil, let mode = out["default_tools_approval_mode"] {
            out["defaultToolApprovalMode"] = mode
        }
        if out["watchPaths"] == nil, let watchPaths = out["watch_paths"] {
            out["watchPaths"] = watchPaths
        }
        if out["cwd"] == nil {
            for key in ["workingDirectory", "working_directory", "workingDir", "working_dir"] {
                if let cwd = stringValue(out[key]) {
                    out["cwd"] = cwd
                    break
                }
            }
        }
        if out["args"] == nil, let arguments = stringArray(out["arguments"]) {
            out["args"] = arguments
        }
        if let commandParts = stringArray(out["command"]), !commandParts.isEmpty {
            out["command"] = commandParts[0]
            if commandParts.count > 1, out["args"] == nil {
                out["args"] = Array(commandParts.dropFirst())
            }
        }
        if let command = stringValue(out["command"]),
           ((out["args"] as? [String])?.isEmpty ?? true) {
            let tokens = shellSplit(command)
            if let launch = normalizeLaunchTokens(tokens),
               shouldSplitCommandString(firstToken: launch.command) {
                out["command"] = launch.command
                out["args"] = launch.args
                if !launch.env.isEmpty {
                    var env = stringDict(out["env"])
                    env.merge(launch.env) { current, _ in current }
                    out["env"] = env
                }
                if out["envFile"] == nil, let envFile = launch.envFile {
                    out["envFile"] = envFile
                }
            }
        }
        enrichLaunchMetadata(in: &out)
        if out["command"] == nil, out["url"] == nil {
            if let package = packageName(in: out) {
                out["command"] = "npx"
                out["args"] = ["-y", package]
            } else if let uvPackage = pythonPackageName(in: out) {
                out["command"] = "uvx"
                out["args"] = [uvPackage]
            } else if let image = dockerImageName(in: out) {
                out["command"] = "docker"
                out["args"] = ["run", "-i", "--rm", image]
            }
        }
        if out["type"] == nil, out["url"] != nil {
            out["type"] = normalizedTransport(out["transport"] as? String) ?? "http"
        } else if let type = out["type"] as? String,
                  let normalizedType = normalizedTransport(type) {
            out["type"] = normalizedType
        }
        out.removeValue(forKey: "name")
        out.removeValue(forKey: "id")
        out.removeValue(forKey: "serverUrl")
        out.removeValue(forKey: "server_url")
        out.removeValue(forKey: "endpoint")
        out.removeValue(forKey: "endpointUrl")
        out.removeValue(forKey: "endpoint_url")
        out.removeValue(forKey: "environment")
        out.removeValue(forKey: "env_file")
        out.removeValue(forKey: "sandbox_enabled")
        out.removeValue(forKey: "always_allow")
        out.removeValue(forKey: "disabled_tools")
        out.removeValue(forKey: "enabled_tools")
        out.removeValue(forKey: "default_tools_approval_mode")
        out.removeValue(forKey: "watch_paths")
        out.removeValue(forKey: "workingDirectory")
        out.removeValue(forKey: "working_directory")
        out.removeValue(forKey: "workingDir")
        out.removeValue(forKey: "working_dir")
        out.removeValue(forKey: "arguments")
        return out
    }

    private static func enrichLaunchMetadata(in config: inout [String: Any]) {
        guard let command = stringValue(config["command"]) else { return }
        let args = stringArray(config["args"]) ?? []
        guard let launch = normalizeLaunchTokens([command] + args) else { return }

        config["command"] = launch.command
        config["args"] = launch.args
        if !launch.env.isEmpty {
            var env = stringDict(config["env"])
            env.merge(launch.env) { current, _ in current }
            config["env"] = env
        }
        if config["envFile"] == nil, let envFile = launch.envFile {
            config["envFile"] = envFile
        }
    }

    private static func isInstallableServer(_ config: [String: Any]) -> Bool {
        stringValue(config["command"]) != nil || stringValue(config["url"]) != nil
    }

    private static func normalizedTransport(_ raw: String?) -> String? {
        guard let raw else { return nil }
        switch raw.lowercased().replacingOccurrences(of: "-", with: "_") {
        case "stdio", "local":
            return "stdio"
        case "sse":
            return "sse"
        case "http", "https", "remote", "streamable_http", "streamablehttp":
            return "http"
        default:
            return nil
        }
    }

    private static func shouldSplitCommandString(firstToken: String) -> Bool {
        let lower = URL(fileURLWithPath: firstToken).lastPathComponent.lowercased()
        return commandStarters.contains(lower)
    }

    private static func packageName(in config: [String: Any]) -> String? {
        for key in ["package", "npmPackage", "npm_package", "packageName", "package_name"] {
            if let value = stringValue(config[key]),
               value.hasPrefix("@") || value.contains("/") || value.contains("mcp") {
                return value
            }
        }
        return nil
    }

    private static func pythonPackageName(in config: [String: Any]) -> String? {
        for key in ["pythonPackage", "python_package", "uvxPackage", "uvx_package"] {
            if let value = stringValue(config[key]) {
                return value
            }
        }
        return nil
    }

    private static func dockerImageName(in config: [String: Any]) -> String? {
        for key in ["dockerImage", "docker_image", "image"] {
            if let value = stringValue(config[key]),
               value.contains("/") || value.contains(":") {
                return value
            }
        }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let string = value as? String, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return string
    }

    private static func stringArray(_ value: Any?) -> [String]? {
        if let strings = value as? [String] { return strings }
        if let values = value as? [Any] {
            let strings = values.compactMap { stringValue($0) }
            return strings.count == values.count ? strings : nil
        }
        return nil
    }

    private static func stringDict(_ value: Any?) -> [String: String] {
        if let strings = value as? [String: String] { return strings }
        if let any = value as? [String: Any] {
            return Dictionary(uniqueKeysWithValues: any.map { ($0.key, "\($0.value)") })
        }
        return [:]
    }

    private static func inferredName(from config: [String: Any]) -> String {
        if let url = config["url"] as? String,
           let host = URL(string: url)?.host {
            return cleanName(host.replacingOccurrences(of: "mcp.", with: ""))
        }

        let command = config["command"] as? String ?? "server"
        let args = config["args"] as? [String] ?? []
        if command == "docker",
           let image = args.last(where: { !$0.hasPrefix("-") && $0.contains("/") || $0.contains(":") }) {
            return cleanName(image)
        }
        if let pkg = inferredRunnerPackage(command: command, args: args) {
            return cleanName(pkg)
        }
        if let pkg = args.first(where: { $0.contains("/") || $0.hasPrefix("@") || $0.contains("mcp") }) {
            return cleanName(pkg)
        }
        return cleanName(command)
    }

    private static func inferredRunnerPackage(command: String, args: [String]) -> String? {
        let runner = URL(fileURLWithPath: command).lastPathComponent.lowercased()
        switch runner {
        case "npx", "bunx", "uvx":
            return firstPackageLikeArgument(args)
        case "pnpm":
            guard args.first?.lowercased() == "dlx" else { return nil }
            return firstPackageLikeArgument(Array(args.dropFirst()))
        case "npm":
            guard let subcommand = args.first?.lowercased(),
                  ["exec", "x"].contains(subcommand) else { return nil }
            return firstPackageLikeArgument(Array(args.dropFirst()))
        case "pipx":
            guard args.first?.lowercased() == "run" else { return nil }
            return firstPackageLikeArgument(Array(args.dropFirst()))
        case "uv":
            guard args.first?.lowercased() == "run" else { return nil }
            if let withIndex = args.firstIndex(where: { $0 == "--with" || $0 == "--with-requirements" }),
               withIndex + 1 < args.count {
                return args[withIndex + 1]
            }
            return firstPackageLikeArgument(Array(args.dropFirst()))
        default:
            return nil
        }
    }

    private static func firstPackageLikeArgument(_ args: [String]) -> String? {
        var index = 0
        while index < args.count {
            let arg = args[index]
            if arg == "--" {
                index += 1
                continue
            }
            if arg.hasPrefix("--") {
                if optionConsumesNextValue(arg),
                   index + 1 < args.count {
                    index += 2
                } else {
                    index += 1
                }
                continue
            }
            if arg.hasPrefix("-") {
                index += 1
                continue
            }
            return arg
        }
        return nil
    }

    private static func optionConsumesNextValue(_ option: String) -> Bool {
        guard !option.contains("=") else { return false }
        return [
            "--cache",
            "--call",
            "--package",
            "--prefix",
            "--registry",
            "--script-shell",
            "--shell",
            "--tag",
            "--userconfig",
            "--workspace"
        ].contains(option)
    }

    /// Sanitizes a pasted name: lowercase, strip weird chars, collapse hyphens.
    static func cleanName(_ raw: String) -> String {
        let lowered = raw.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = Set<Character>("abcdefghijklmnopqrstuvwxyz0123456789-_")
        var result = ""
        var lastDash = false
        for ch in lowered {
            if allowed.contains(ch) {
                result.append(ch)
                lastDash = (ch == "-")
            } else if ch.isWhitespace || ch == "." || ch == "/" || ch == "@" {
                if !lastDash && !result.isEmpty {
                    result.append("-"); lastDash = true
                }
            }
        }
        // Trim leading/trailing dashes
        while result.hasPrefix("-") { result.removeFirst() }
        while result.hasSuffix("-") { result.removeLast() }
        return result.isEmpty ? "server" : result
    }
}
