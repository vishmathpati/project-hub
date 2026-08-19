import SwiftUI
import AppKit
import UniformTypeIdentifiers
import CryptoKit

// MARK: - Import flow: paste → preview → pick apps → done

struct MCPImportSheet: View {
    @EnvironmentObject var mcpStore: MCPStore
    let onClose: () -> Void

    enum Stage { case paste, archive, choices, preview, done }
    enum Source: String, CaseIterable { case paste = "Paste"; case url = "From URL" }
    enum ImportTargetPreset: String, CaseIterable, Identifiable {
        case allSupported
        case cli
        case desktop
        case project

        var id: String { rawValue }

        var label: String {
            switch self {
            case .allSupported: return "All"
            case .cli: return "CLI"
            case .desktop: return "Desktop"
            case .project: return "Project"
            }
        }

        var icon: String {
            switch self {
            case .allSupported: return "sparkles"
            case .cli: return "terminal"
            case .desktop: return "macwindow"
            case .project: return "folder"
            }
        }
    }

    @State private var stage: Stage = .paste
    @State private var source: Source = .paste
    @State private var rawText: String = ""
    @State private var remoteURL: String = ""
    @State private var fetchingURL = false
    @State private var fetchRequestID = UUID()
    @State private var fetchedSourceNote: String?
    @State private var servers: [ParsedServer] = []
    @State private var importChoices: [ParsedImportChoice] = []
    @State private var interactiveInstaller: InteractiveInstallerCandidate?
    @State private var archivePreview: DesktopExtensionArchivePreview?
    @State private var selectedTools: Set<String> = []
    @State private var parseError: String?
    @State private var importResults: [ImportResult] = []

    // Project scope
    @State private var useProjectScope: Bool = false
    @State private var projectRoot: String? = nil
    @State private var importTargetPreset: ImportTargetPreset = .allSupported

    // Diff preview
    @State private var showingDiff: Bool = true

    struct ImportResult: Identifiable {
        let id = UUID()
        let serverName: String
        let toolID: String
        let toolLabel: String
        let scope: ConfigScope
        let projectRoot: String?
        let configPath: String?
        let success: Bool
        let message: String?
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Group {
                switch stage {
                case .paste:   pasteView
                case .archive: archiveView
                case .choices: choicesView
                case .preview: previewView
                case .done:    doneView
                }
            }
        }
        .frame(width: 460)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Cancel")

            Text(stageTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Text(stageHint)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.60))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(HubTheme.accent)
    }

    private var stageTitle: String {
        switch stage {
        case .paste:   return "Import MCP Server"
        case .archive: return "Review Desktop Extension"
        case .choices: return "Choose Import Source"
        case .preview: return servers.count == 1 ? "Review & Install" : "Review \(servers.count) Servers"
        case .done:    return "Done"
        }
    }

    private var stageHint: String {
        switch stage {
        case .paste:   return "Step 1 of 3"
        case .archive: return "Claude Desktop handoff"
        case .choices: return "Import options"
        case .preview: return "Step 2 of 3"
        case .done:    return "Step 3 of 3"
        }
    }

    // MARK: - Paste view

    private var pasteView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Source segmented picker
            Picker("", selection: $source) {
                ForEach(Source.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if source == .paste {
                Text("Paste a config, URL, or install command")
                    .font(.system(size: 12, weight: .semibold))

                Text("Project Hub can read JSON snippets, README code blocks, local or remote source archives, direct hosted MCP URLs, npx/uvx/python/docker commands, and tool-specific mcp add commands. MCPB/DXT archives open in Claude Desktop for install review.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $rawText)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(6)
                        .background(HubTheme.field)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(HubTheme.line.opacity(0.6), lineWidth: 0.5)
                        )
                        .frame(height: 200)

                    if rawText.isEmpty {
                        Text(placeholderJSON)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(12)
                            .allowsHitTesting(false)
                    }
                }

                HStack(spacing: 6) {
                    Button(action: chooseArchive) {
                        HStack(spacing: 4) {
                            Image(systemName: "shippingbox")
                            Text("Choose Archive")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(HubTheme.accent)

                    Button(action: chooseJSONConfig) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.badge.gearshape")
                            Text("Choose JSON")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(HubTheme.accent)

                    Text("Reads source archives for mcp.json, mcp-fetch.json, and README snippets. MCPB/DXT or extension ZIP files open in Claude Desktop for review.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Paste a URL to an MCP config, README, or archive")
                    .font(.system(size: 12, weight: .semibold))
                Text("Raw GitHub, gist, pastebin, mcp.json, mcp-fetch.json, GitHub blob links, or GitHub repositories with server.json, MCP config files, or README snippets.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    TextField("https://gist.githubusercontent.com/\u{2026}/raw/mcp.json", text: $remoteURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                    if fetchingURL {
                        ProgressView().scaleEffect(0.55)
                    }
                }

                if let fetchedSourceNote {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc")
                            .foregroundColor(.secondary)
                        Text(fetchedSourceNote)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }

                if !rawText.isEmpty {
                    ScrollView {
                        Text(rawText)
                            .font(.system(size: 10, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 140)
                    .background(HubTheme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(HubTheme.line.opacity(0.6), lineWidth: 0.5)
                    )
                }
            }

            if let err = parseError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            if let interactiveInstaller {
                interactiveInstallerCard(interactiveInstaller)
            }

            HStack {
                if source == .paste {
                    Button(action: pasteFromClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                            Text("Paste from clipboard")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(HubTheme.accent)
                } else {
                    Button(action: fetchFromURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                            Text("Fetch")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(HubTheme.accent)
                    .disabled(remoteURL.trimmingCharacters(in: .whitespaces).isEmpty || fetchingURL)
                }

                Spacer()

                Button(action: parse) {
                    HStack(spacing: 4) {
                        Text("Next")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(HubTheme.onAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(HubTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .opacity(rawText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .disabled(rawText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(14)
        .onChange(of: source) { _, _ in
            fetchRequestID = UUID()
            fetchingURL = false
            rawText = ""
            fetchedSourceNote = nil
            parseError = nil
            servers = []
            importChoices = []
            interactiveInstaller = nil
            archivePreview = nil
            selectedTools = []
        }
        .onChange(of: remoteURL) { _, _ in
            guard source == .url else { return }
            fetchRequestID = UUID()
            fetchingURL = false
            rawText = ""
            fetchedSourceNote = nil
            parseError = nil
            servers = []
            importChoices = []
            interactiveInstaller = nil
            archivePreview = nil
            selectedTools = []
        }
    }

    private func interactiveInstallerCard(_ installer: InteractiveInstallerCandidate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Prompt-driven installer")
                        .font(.system(size: 12, weight: .semibold))
                    Text(installer.summary)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            Text(installer.rawCommand)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(4)
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HubTheme.field)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(HubTheme.line.opacity(0.45), lineWidth: 0.5))

            HStack(spacing: 8) {
                Text(installer.runtime)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.10))
                    .clipShape(Capsule())
                Spacer()
                Button(action: { copyInteractiveInstallerCommand(installer.rawCommand) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy command")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(HubTheme.accent)
                Button(action: { mcpStore.refresh() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh after run")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(HubTheme.accent)
            }

            Text("Run the command yourself, finish any prompts, then refresh Project Hub. Project Hub does not execute prompt-driven installers or write their target files automatically.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(9)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.18), lineWidth: 1))
    }

    private func fetchFromURL() {
        let trimmed = remoteURL.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed), ["http", "https"].contains(url.scheme ?? "") else {
            fetchedSourceNote = nil
            parseError = "Enter a valid http(s) URL."
            return
        }
        let lowerPath = url.path.lowercased()
        if ["mcpb", "dxt", "zip"].contains(url.pathExtension.lowercased())
            || lowerPath.hasSuffix(".tar.gz")
            || lowerPath.hasSuffix(".tgz")
            || githubDirectArchiveURL(url) {
            parseError = nil
            rawText = ""
            servers = []
            importChoices = []
            interactiveInstaller = nil
            selectedTools = []
            archivePreview = nil
            fetchedSourceNote = "Downloading archive for local preview..."
            fetchingURL = true
            let requestID = UUID()
            fetchRequestID = requestID
            Task {
                do {
                    try await fetchRemoteArchive(url, requestID: requestID)
                } catch {
                    await MainActor.run {
                        guard fetchRequestID == requestID else { return }
                        parseError = "Archive fetch failed: \(error.localizedDescription)"
                        fetchingURL = false
                    }
                }
            }
            return
        }
        if ImportParser.githubReleaseOrArchiveURL(from: trimmed) {
            fetchedSourceNote = nil
            parseError = "Open the release asset or source archive download URL directly. Project Hub can inspect remote .zip, .tar.gz, .tgz, .mcpb, and .dxt downloads, but not a GitHub release page."
            return
        }
        let githubFetch = ImportParser.githubContentFetch(from: trimmed)

        parseError = nil
        rawText = ""
        servers = []
        importChoices = []
        interactiveInstaller = nil
        selectedTools = []
        archivePreview = nil
        fetchedSourceNote = githubFetch == nil ? nil : "Preparing GitHub MCP candidates..."
        fetchingURL = true
        let requestID = UUID()
        fetchRequestID = requestID
        Task {
            do {
                if let githubFetch {
                    try await fetchGitHubCandidates(githubFetch, requestID: requestID)
                } else {
                    try await fetchSingleURL(url, requestID: requestID)
                }
            } catch {
                await MainActor.run {
                    guard fetchRequestID == requestID else { return }
                    parseError = "Fetch failed: \(error.localizedDescription)"
                    fetchingURL = false
                }
            }
        }
    }

    private func fetchSingleURL(_ url: URL, requestID: UUID) async throws {
        let fetched = try await fetchText(from: url)
        let choices = ImportParser.importChoices(from: fetched)
        let installer = ImportParser.interactiveInstaller(from: fetched)
        await MainActor.run {
            guard fetchRequestID == requestID else { return }
            rawText = fetched
            if choices.count > 1 {
                interactiveInstaller = installer
                importChoices = choices
                fetchedSourceNote = "Found multiple import options in \(url.lastPathComponent.isEmpty ? "the fetched URL" : url.lastPathComponent). Choose one to preview."
                parseError = nil
                servers = []
                archivePreview = nil
                selectedTools = []
                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                    stage = .choices
                }
            } else if let choice = choices.first {
                importChoices = choices
                interactiveInstaller = installer
                fetchedSourceNote = "\(choice.label) from \(url.lastPathComponent.isEmpty ? "the fetched URL" : url.lastPathComponent)."
                selectImportChoice(choice)
            } else if let installer {
                interactiveInstaller = installer
                fetchedSourceNote = "Found a prompt-driven installer in \(url.lastPathComponent.isEmpty ? "the fetched URL" : url.lastPathComponent)."
                parseError = nil
                servers = []
                importChoices = []
                archivePreview = nil
                selectedTools = []
            }
            fetchingURL = false
        }
    }

    private func fetchRemoteArchive(_ url: URL, requestID: UUID) async throws {
        let localURL = try await downloadRemoteArchive(from: url)
        await MainActor.run {
            guard fetchRequestID == requestID else { return }
            fetchedSourceNote = "Downloaded \(localURL.lastPathComponent). Inspecting archive..."
            fetchingURL = false
            previewLocalArchive(localURL)
        }
    }

    private func fetchGitHubCandidates(_ fetch: GitHubContentFetch, requestID: UUID) async throws {
        let resolution = await ImportParser.resolveGitHubContent(
            fetch,
            fetchText: { candidate in
                await MainActor.run {
                    guard fetchRequestID == requestID else { return }
                    fetchedSourceNote = "Trying \(candidate.path) from GitHub..."
                }
                return try await fetchText(from: candidate.url)
            },
            fetchDiscoveryText: { discovery in
                await MainActor.run {
                    guard fetchRequestID == requestID else { return }
                    fetchedSourceNote = "Checking GitHub repository tree for nested MCP config files..."
                }
                return try await fetchRawText(from: discovery.url)
            },
            fetchRegistryText: { request in
                await MainActor.run {
                    guard fetchRequestID == requestID else { return }
                    fetchedSourceNote = "Checking MCP Registry for this GitHub repository..."
                }
                return try await fetchRawText(from: request.url)
            }
        )

        await MainActor.run {
            guard fetchRequestID == requestID else { return }
            fetchingURL = false
            if resolution.didFindParseableConfig {
                rawText = resolution.lastFetchedText
                fetchedSourceNote = resolution.matchedCandidate?.note
                applyParsedServers(
                    resolution.servers,
                    choices: resolution.importChoices,
                    secondaryInstaller: resolution.interactiveInstaller
                )
            } else if resolution.needsUserChoice {
                rawText = resolution.lastFetchedText
                interactiveInstaller = resolution.interactiveInstaller
                importChoices = resolution.importChoices
                fetchedSourceNote = "Found multiple import options in \(resolution.lastFetchedCandidate?.path ?? "README"). Choose one to preview."
                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                    stage = .choices
                }
            } else if resolution.needsInteractiveInstallerHandoff,
                      let installer = resolution.interactiveInstaller {
                rawText = resolution.lastFetchedText
                interactiveInstaller = installer
                fetchedSourceNote = "Found a prompt-driven installer in \(resolution.lastFetchedCandidate?.path ?? "README")."
                parseError = nil
                servers = []
                importChoices = []
                archivePreview = nil
                selectedTools = []
            } else if resolution.lastFetchedText.isEmpty {
                rawText = ""
                fetchedSourceNote = nil
                interactiveInstaller = nil
                parseError = "Could not fetch GitHub MCP config candidates or match this repository in the MCP Registry: \(resolution.attemptedPaths.joined(separator: ", ")). Paste a raw config URL or install snippet instead."
            } else {
                rawText = resolution.lastFetchedText
                fetchedSourceNote = nil
                interactiveInstaller = nil
                let path = resolution.lastFetchedCandidate?.path ?? "the last GitHub candidate"
                parseError = "Fetched \(path), but Project Hub could not find an MCP server config or install command in it."
            }
        }
    }

    private func fetchText(from url: URL) async throws -> String {
        let text = try await fetchRawText(from: url)
        if url.host?.lowercased() == "api.github.com",
           url.path.contains("/contents/") {
            guard let data = text.data(using: .utf8) else {
                throw URLError(.cannotDecodeContentData)
            }
            return try decodeGitHubContentsResponse(data)
        }
        return text
    }

    private func fetchRawText(from url: URL) async throws -> String {
        var req = URLRequest(url: url, timeoutInterval: 8.0)
        req.setValue("text/plain, application/json;q=0.9, */*;q=0.5", forHTTPHeaderField: "Accept")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func downloadRemoteArchive(from url: URL, expectedSHA256: String? = nil) async throws -> URL {
        let maxBytes = 80 * 1024 * 1024
        var req = URLRequest(url: url, timeoutInterval: 30.0)
        req.setValue("application/octet-stream, application/zip;q=0.9, application/gzip;q=0.8, */*;q=0.5", forHTTPHeaderField: "Accept")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        if data.count > maxBytes {
            throw URLError(.dataLengthExceedsMaximum)
        }
        if let expectedSHA256,
           !expectedSHA256.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let expected = expectedSHA256.lowercased().filter { $0.isHexDigit }
            let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard expected == actual else { throw URLError(.cannotDecodeContentData) }
        }

        let fm = FileManager.default
        let dir = fm.temporaryDirectory
            .appendingPathComponent("ProjectHubRemoteArchives", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = safeArchiveFilename(from: url)
        let destination = dir.appendingPathComponent("\(UUID().uuidString)-\(filename)")
        try data.write(to: destination, options: .atomic)
        return destination
    }

    private func safeArchiveFilename(from url: URL) -> String {
        let raw = url.lastPathComponent.isEmpty ? "archive.zip" : url.lastPathComponent
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let cleaned = String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
            .trimmingCharacters(in: CharacterSet(charactersIn: ".-"))
        let fallback = cleaned.isEmpty ? "archive.zip" : cleaned
        let lowerPath = url.path.lowercased()
        if lowerPath.hasSuffix(".tar.gz"), !fallback.lowercased().hasSuffix(".tar.gz") {
            return fallback + ".tar.gz"
        }
        if lowerPath.hasSuffix(".tgz"), !fallback.lowercased().hasSuffix(".tgz") {
            return fallback + ".tgz"
        }
        if ["mcpb", "dxt", "zip"].contains(url.pathExtension.lowercased()),
           !fallback.lowercased().hasSuffix("." + url.pathExtension.lowercased()) {
            return fallback + "." + url.pathExtension.lowercased()
        }
        return fallback
    }

    private func githubDirectArchiveURL(_ url: URL) -> Bool {
        guard url.host?.lowercased() == "github.com" else { return false }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 3 else { return false }
        if parts[2] == "archive" { return true }
        return parts[2] == "releases"
            && parts.count >= 5
            && parts[3] == "download"
    }

    private func decodeGitHubContentsResponse(_ data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let encoding = json["encoding"] as? String,
              encoding.lowercased() == "base64",
              let content = json["content"] as? String else {
            throw URLError(.cannotDecodeContentData)
        }
        let compact = content
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        guard let decoded = Data(base64Encoded: compact),
              let text = String(data: decoded, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return text
    }

    private let placeholderJSON = """
    Choose an mcp.json or mcp-fetch.json file, or paste:

    claude mcp add supabase -- npx -y @supabase/mcp-server

    or

    {
      "mcpServers": {
        "supabase": {
          "command": "npx",
          "args": ["-y", "@supabase/mcp-server"]
        }
      }
    }
    """

    // MARK: - Choice view

    private var choicesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fetchedSourceNote {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundColor(.blue)
                    Text(fetchedSourceNote)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(8)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(choicesAreRegistryMethods ? "Choose install method" : "Choose import source")
                    .font(.system(size: 12, weight: .semibold))
                Text(choicesAreRegistryMethods ? "This Registry manifest offers alternative ways to use the same server. Pick one method to preview before Project Hub writes config." : "Project Hub found more than one safe import option. Preview one option before writing anything.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(importChoices) { choice in
                        Button(action: { selectImportChoice(choice) }) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: choice.archiveURL == nil ? iconName(for: choice.servers.first?.kindLabel ?? "Local") : "archivebox")
                                    .font(.system(size: 13))
                                    .foregroundColor(HubTheme.accent)
                                    .frame(width: 28, height: 28)
                                    .background(HubTheme.accent.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 7))

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(choice.label)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.primary)
                                        if choice.servers.count > 1 {
                                            Text("\(choice.servers.count) servers")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Text(choice.source)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                    if let summary = choiceRequirementSummary(choice) {
                                        Text(summary)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .background(HubTheme.raised)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(HubTheme.line.opacity(0.55), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 300)

            if let interactiveInstaller {
                interactiveInstallerCard(interactiveInstaller)
            }

            Spacer()
            Divider()

            HStack {
                Button(action: { stage = .paste }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(14)
        .frame(minHeight: 360)
    }

    private var choicesAreRegistryMethods: Bool {
        !importChoices.isEmpty && importChoices.allSatisfy { $0.label.hasPrefix("Registry ") }
    }

    private func choiceRequirementSummary(_ choice: ParsedImportChoice) -> String? {
        if let archiveURL = choice.archiveURL {
            var bits = ["Claude Desktop extension archive"]
            if choice.archiveSHA256 != nil { bits.append("SHA-256 verified on download") }
            bits.append(URL(fileURLWithPath: archiveURL.path).lastPathComponent.isEmpty ? archiveURL.absoluteString : URL(fileURLWithPath: archiveURL.path).lastPathComponent)
            return bits.joined(separator: " / ")
        }

        var requirements: [String] = []
        for server in choice.servers {
            if (server.config["command"] as? String) == "docker" {
                requirements.append("Docker runtime")
            }
            if let credentialSummary = ImportCredentialPlanner.requirementSummary(for: server) {
                requirements.append(credentialSummary)
            }
        }

        guard !requirements.isEmpty else { return nil }
        var seen = Set<String>()
        let unique = requirements.filter { seen.insert($0).inserted }
        return "Needs: \(unique.joined(separator: " / "))"
    }

    private func placeholderNames(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\$\{([A-Za-z_][A-Za-z0-9_]*)\}"#) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return ns.substring(with: match.range(at: 1))
        }
    }

    // MARK: - Archive view

    private var archiveView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let archivePreview {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "shippingbox.fill")
                            .foregroundColor(HubTheme.accent)
                            .font(.system(size: 26))
                            .frame(width: 34)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(archivePreview.displayName)
                                .font(.system(size: 15, weight: .bold))
                            HStack(spacing: 8) {
                                if let version = archivePreview.version {
                                    Text("v\(version)")
                                }
                                if let author = archivePreview.author {
                                    Text(author)
                                }
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                    if let description = archivePreview.description {
                        Text(description)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 7) {
                    archiveFactRow("File", archivePreview.filePath)
                    archiveFactRow("Manifest", archivePreview.manifestPath)
                    if let command = archivePreview.commandPreview {
                        archiveFactRow("Launch", command)
                    }
                    if !archivePreview.requiredUserConfig.isEmpty {
                        archiveFactRow("Required config", archivePreview.requiredUserConfig.joined(separator: ", "))
                    }
                    if !archivePreview.toolNames.isEmpty {
                        archiveFactRow("Tools", archivePreview.toolNames.prefix(8).joined(separator: ", ") + (archivePreview.toolNames.count > 8 ? "…" : ""))
                    }
                }

                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Project Hub will not unpack this archive or write Claude Desktop extension state. Open the archive with Claude Desktop's MCPB/DXT installer, where the user can review permissions and finish installation.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }

            Spacer()

            Divider()

            HStack {
                Button(action: {
                    archivePreview = nil
                    stage = .paste
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button(action: openDesktopExtensionArchive) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 11))
                        Text("Open archive")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(HubTheme.onAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(HubTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .opacity(archivePreview == nil ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .disabled(archivePreview == nil)
            }
        }
        .padding(14)
        .frame(minHeight: 360)
    }

    private func archiveFactRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }

    // MARK: - Preview view

    private var previewView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let fetchedSourceNote {
                        HStack(alignment: .top, spacing: 7) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(.blue)
                                .font(.system(size: 12))
                            Text(fetchedSourceNote)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }

                    if let interactiveInstaller {
                        interactiveInstallerCard(interactiveInstaller)
                    }

                    // Servers section
                    sectionLabel("Server\(servers.count == 1 ? "" : "s") to import")

                    VStack(spacing: 6) {
                        ForEach($servers) { $server in
                            ServerPreviewRow(server: $server)
                        }
                    }

                    Divider().padding(.vertical, 2)

                    // Scope picker — shown before the app list
                    sectionLabel("Install to")
                    targetPresetRow
                    HStack(spacing: 6) {
                        Button(action: { applyTargetPreset(.allSupported) }) {
                            HStack(spacing: 5) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 11))
                                Text("Global")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .foregroundColor(!useProjectScope ? .white : .primary)
                            .background(!useProjectScope ? HubTheme.accent : HubTheme.raised)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)

                        Button(action: { applyTargetPreset(.project) }) {
                            HStack(spacing: 5) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 11))
                                Text(useProjectScope && projectRoot != nil
                                    ? URL(fileURLWithPath: projectRoot!).lastPathComponent
                                    : "Add to project")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .foregroundColor(useProjectScope ? .white : .primary)
                            .background(useProjectScope ? HubTheme.accent : HubTheme.raised)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(3)
                    .background(HubTheme.bg.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                    if useProjectScope {
                        VStack(alignment: .leading, spacing: 4) {
                            if let root = projectRoot {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 11))
                                    Text(root)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Button("Change…", action: pickProjectRoot)
                                        .buttonStyle(.plain)
                                        .font(.system(size: 11))
                                        .foregroundColor(HubTheme.accent)
                                }
                            } else {
                                Text("Choose a project folder before importing.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                            }
                            Text("Global-only apps are disabled in Project mode so imports write only under this project.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    if MCPImportScopePlanner.containsRemoteMCP(servers) {
                        HStack(alignment: .top, spacing: 7) {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.blue)
                            Text("Claude Desktop remote MCP uses Settings > Connectors. Project Hub will not write hosted/remote MCP URLs into claude_desktop_config.json.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }

                    Divider().padding(.vertical, 2)

                    // Tool picker section
                    HStack {
                        sectionLabel("Selected app configs")
                        Spacer()
                        Button(action: toggleSelectAll) {
                            Text(allSelected ? "Deselect all" : "Select all")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(HubTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 4) {
                        ForEach(mcpStore.detectedTools) { tool in
                            let eligible = toolIsEligible(tool.toolID)
                            ToolPickerRow(
                                tool: tool,
                                selected: selectedTools.contains(tool.toolID),
                                supported: eligible,
                                note: toolSupportNote(tool.toolID),
                                onToggle: { toggle(tool.toolID) }
                            )
                        }
                    }

                    Divider().padding(.vertical, 2)

                    // Diff preview toggle
                    HStack {
                        sectionLabel("Preview")
                        Spacer()
                        Button(action: { showingDiff.toggle() }) {
                            HStack(spacing: 3) {
                                Image(systemName: showingDiff ? "eye.slash" : "eye")
                                Text(showingDiff ? "Hide diff" : "Show diff")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(HubTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    if showingDiff {
                        DiffPreviewBlock(
                            servers: servers,
                            selectedTools: Array(selectedTools),
                            scope: useProjectScope ? .project : .user,
                            projectRoot: useProjectScope ? projectRoot : nil
                        )
                    }
                }
                .padding(14)
            }
            .frame(maxHeight: 400)

            Divider()

            // Footer
            HStack {
                Button(action: { stage = .paste }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Text("\(selectedTools.count) app\(selectedTools.count == 1 ? "" : "s") selected")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Button(action: runImport) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 11))
                        Text("Import")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(HubTheme.onAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(HubTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .opacity(canImport ? 1 : 0.4)
                }
                .buttonStyle(.plain)
                .disabled(!canImport)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private var targetPresetRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(ImportTargetPreset.allCases) { preset in
                    targetPresetButton(preset)
                }
            }
            Text(targetPresetSummary)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func targetPresetButton(_ preset: ImportTargetPreset) -> some View {
        let active = importTargetPreset == preset
        return Button {
            applyTargetPreset(preset)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: preset.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(preset.label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(active ? .white : .secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(active ? HubTheme.accent : HubTheme.raised)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var targetPresetSummary: String {
        switch importTargetPreset {
        case .allSupported:
            return "Selects supported Claude Code, Claude Desktop, and Codex targets that Project Hub can write safely."
        case .cli:
            return "Targets writable CLI config. Codex global MCP is writable; Claude Code global MCP is a Claude CLI handoff."
        case .desktop:
            return "Targets Claude Desktop and Codex Desktop global configs. Hosted Claude Desktop MCPs still use Connectors."
        case .project:
            return "Targets per-project Claude Code and Codex config files under the selected folder."
        }
    }

    private var canImport: Bool {
        MCPImportScopePlanner.canImport(
            selectedTools: selectedTools,
            useProjectScope: useProjectScope,
            projectRoot: projectRoot,
            serverNames: servers.map(\.name),
            servers: servers
        )
    }

    private var allSelected: Bool {
        let supported = eligibleToolIDs
        return !supported.isEmpty && Set(supported).isSubset(of: selectedTools)
    }

    private var eligibleToolIDs: [String] {
        MCPImportScopePlanner.eligibleToolIDs(
            mcpStore.detectedTools.map(\.toolID),
            useProjectScope: useProjectScope,
            servers: servers
        )
    }

    private func toolIsEligible(_ toolID: String) -> Bool {
        MCPImportScopePlanner.toolIsEligible(toolID, useProjectScope: useProjectScope, servers: servers)
    }

    private func toolSupportNote(_ toolID: String) -> String? {
        MCPImportScopePlanner.toolSupportNote(toolID, useProjectScope: useProjectScope, servers: servers)
    }

    private func applyTargetPreset(_ preset: ImportTargetPreset) {
        importTargetPreset = preset
        switch preset {
        case .allSupported:
            useProjectScope = false
            selectedTools = writablePrimaryTargets(["claude-code", "claude-desktop", "codex"])
        case .cli:
            useProjectScope = false
            selectedTools = writablePrimaryTargets(["claude-code", "codex"])
        case .desktop:
            useProjectScope = false
            selectedTools = writablePrimaryTargets(["claude-desktop", "codex"])
        case .project:
            useProjectScope = true
            if projectRoot == nil {
                pickProjectRoot()
            }
            selectedTools = writablePrimaryTargets(["claude-code", "codex"])
        }
    }

    private func writablePrimaryTargets(_ orderedIDs: [String]) -> Set<String> {
        let detected = Set(mcpStore.detectedTools.map(\.toolID))
        return Set(orderedIDs.filter { detected.contains($0) && toolIsEligible($0) })
    }

    // MARK: - Done view

    private var doneView: some View {
        let wins    = importResults.filter { $0.success }
        let failures = importResults.filter { !$0.success }

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Summary banner
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(failures.isEmpty ? Color.green.opacity(0.18) : Color.orange.opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: failures.isEmpty ? "checkmark" : "exclamationmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(failures.isEmpty ? .green : .orange)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(failures.isEmpty ? "Config written" : "Written with follow-up")
                            .font(.system(size: 13, weight: .semibold))
                        Text("\(wins.count) succeeded · \(failures.count) failed")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                if !wins.isEmpty {
                    sectionLabel("Installed")
                    VStack(spacing: 3) {
                        ForEach(wins) { r in
                            resultRow(r, color: .green, icon: "checkmark.circle.fill")
                        }
                    }
                }

                if !failures.isEmpty {
                    sectionLabel("Failed")
                    VStack(spacing: 3) {
                        ForEach(failures) { r in
                            resultRow(r, color: .orange, icon: "exclamationmark.triangle.fill")
                        }
                    }
                }

                // Per-server "next steps" cards
                if !wins.isEmpty {
                    sectionLabel("Next steps")
                    VStack(spacing: 8) {
                        ForEach(uniqueServerNames(wins), id: \.self) { name in
                            NextStepsCard(
                                serverName: name,
                                installedTools: installedToolsForServer(name: name, wins: wins),
                                credentialRequirements: credentialRequirements(for: name),
                                refresh: { mcpStore.refresh() }
                            )
                        }
                    }
                }

                Text("Restart or reload affected desktop apps, or start a fresh CLI session, then run Scan and Verify.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)

                HStack {
                    Spacer()
                    Button(action: { mcpStore.refresh(); onClose() }) {
                        Text("Done")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(HubTheme.onAccent)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 7)
                            .background(HubTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            }
            .padding(14)
        }
    }

    private func resultRow(_ r: ImportResult, color: Color, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 11))
            Text(r.serverName)
                .font(.system(size: 12, weight: .medium))
            Text("→")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(r.toolLabel)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            if let msg = r.message, !r.success {
                Text("— \(msg)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    // MARK: - Section label helper

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.secondary)
            .tracking(0.4)
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        if let str = NSPasteboard.general.string(forType: .string) {
            rawText = str
            fetchedSourceNote = nil
            parseError = nil
            servers = []
            importChoices = []
            interactiveInstaller = nil
            archivePreview = nil
            selectedTools = []
        }
    }

    private func chooseArchive() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = ["mcpb", "dxt", "zip", "tgz", "gz"].compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK, let url = panel.url {
            resetImportPreviewState()
            previewLocalArchive(url)
        }
    }

    private func chooseJSONConfig() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = "mcp.json"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                resetImportPreviewState()
                rawText = try String(contentsOf: url, encoding: .utf8)
                source = .paste
                fetchedSourceNote = nil
                parseError = nil
                parse()
            } catch {
                parseError = "Could not read \(url.lastPathComponent): \(error.localizedDescription)"
            }
        }
    }

    private func parse() {
        parseError = nil
        importChoices = []
        interactiveInstaller = nil
        archivePreview = nil
        if let archiveURL = ImportParser.localArchiveURL(from: rawText) {
            previewLocalArchive(archiveURL)
            return
        }
        if let installer = ImportParser.interactiveInstaller(from: rawText),
           ImportParser.importChoices(from: rawText).isEmpty {
            interactiveInstaller = installer
            fetchedSourceNote = "Prompt-driven installer detected."
            return
        }
        let choices = ImportParser.importChoices(from: rawText)
        let installer = ImportParser.interactiveInstaller(from: rawText)
        if choices.count > 1 {
            importChoices = choices
            interactiveInstaller = installer
            fetchedSourceNote = "Found multiple import options. Choose one to preview."
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                stage = .choices
            }
            return
        }
        if let choice = choices.first {
            importChoices = choices
            interactiveInstaller = installer
            fetchedSourceNote = choice.label
            selectImportChoice(choice)
            return
        }
        switch ImportParser.parse(rawText) {
        case .success(let parsed):
            applyParsedServers(parsed)
        case .failure(let err):
            fetchedSourceNote = nil
            parseError = err.errorDescription
        }
    }

    private func selectImportChoice(_ choice: ParsedImportChoice) {
        let installer = interactiveInstaller
        rawText = choice.rawText
        fetchedSourceNote = "\(choice.label) from \(choice.source)."
        if let archiveURL = choice.archiveURL {
            downloadArchiveChoice(choice, archiveURL: archiveURL)
            return
        }
        applyParsedServers(choice.servers, choices: importChoices, secondaryInstaller: installer)
    }

    private func downloadArchiveChoice(_ choice: ParsedImportChoice, archiveURL: URL) {
        parseError = nil
        servers = []
        selectedTools = []
        archivePreview = nil
        fetchingURL = true
        fetchedSourceNote = "Downloading \(choice.label) for local preview..."
        let requestID = UUID()
        fetchRequestID = requestID
        Task {
            do {
                let localURL = try await downloadRemoteArchive(from: archiveURL, expectedSHA256: choice.archiveSHA256)
                await MainActor.run {
                    guard fetchRequestID == requestID else { return }
                    fetchingURL = false
                    fetchedSourceNote = "Downloaded \(localURL.lastPathComponent). Inspecting archive..."
                    previewLocalArchive(localURL)
                }
            } catch {
                await MainActor.run {
                    guard fetchRequestID == requestID else { return }
                    fetchingURL = false
                    parseError = "Archive fetch failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func previewLocalArchive(_ url: URL) {
        let lowerPath = url.path.lowercased()
        let ext = url.pathExtension.lowercased()
        if ext == "mcpb" || ext == "dxt" {
            previewDesktopExtensionArchive(url)
            return
        }
        if lowerPath.hasSuffix(".tar.gz") || lowerPath.hasSuffix(".tgz") {
            previewSourceArchive(url)
            return
        }

        switch ImportParser.previewDesktopExtensionArchive(at: url) {
        case .success(let preview):
            archivePreview = preview
            servers = []
            importChoices = []
            selectedTools = []
            fetchedSourceNote = nil
            rawText = ""
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                stage = .archive
            }
        case .failure(let error):
            switch error {
            case .archiveMissingManifest, .archiveNotDesktopExtensionManifest:
                previewSourceArchive(url)
            default:
                parseError = error.errorDescription
                return
            }
        }
    }

    private func previewDesktopExtensionArchive(_ url: URL) {
        parseError = nil
        switch ImportParser.previewDesktopExtensionArchive(at: url) {
        case .success(let preview):
            archivePreview = preview
            servers = []
            importChoices = []
            selectedTools = []
            fetchedSourceNote = nil
            rawText = ""
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                stage = .archive
            }
        case .failure(let error):
            resetImportPreviewState()
            parseError = error.errorDescription
        }
    }

    private func previewSourceArchive(_ url: URL) {
        parseError = nil
        archivePreview = nil
        switch ImportParser.previewSourceArchive(at: url) {
        case .success(let preview):
            let archiveName = URL(fileURLWithPath: preview.filePath).lastPathComponent
            if preview.choices.count > 1 || preview.choices.first?.archiveURL != nil {
                rawText = preview.choices.first?.rawText ?? ""
                importChoices = preview.choices
                interactiveInstaller = preview.interactiveInstaller
                fetchedSourceNote = preview.choices.count > 1
                    ? "Found multiple import options in \(archiveName). Choose one to preview."
                    : "Found a registry archive handoff in \(archiveName). Preview it before opening the installer."
                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                    stage = .choices
                }
            } else if let installer = preview.interactiveInstaller {
                rawText = ""
                servers = []
                importChoices = []
                selectedTools = []
                archivePreview = nil
                interactiveInstaller = installer
                fetchedSourceNote = "Found a prompt-driven installer in \(preview.sourcePath) from \(archiveName)."
            } else {
                fetchedSourceNote = "Read \(preview.sourcePath) from \(archiveName)."
                applyParsedServers(
                    preview.servers,
                    choices: preview.choices,
                    secondaryInstaller: preview.interactiveInstaller
                )
            }
        case .failure(let error):
            resetImportPreviewState()
            parseError = error.errorDescription
        }
    }

    private func resetImportPreviewState() {
        archivePreview = nil
        servers = []
        importChoices = []
        interactiveInstaller = nil
        selectedTools = []
        fetchedSourceNote = nil
        rawText = ""
        parseError = nil
    }

    private func copyInteractiveInstallerCommand(_ command: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }

    private func applyParsedServers(
        _ parsed: [ParsedServer],
        choices: [ParsedImportChoice] = [],
        secondaryInstaller: InteractiveInstallerCandidate? = nil
    ) {
        if parsed.isEmpty {
            parseError = "No servers found in that JSON."
            return
        }
        interactiveInstaller = secondaryInstaller
        importChoices = choices
        servers = parsed.map {
            var server = $0
            server.name = ImportParser.cleanName(server.name)
            if server.name.isEmpty { server.name = "server" }
            return server
        }
        applyTargetPreset(.allSupported)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            stage = .preview
        }
    }

    private func iconName(for label: String) -> String {
        switch label {
        case "Remote": return "globe"
        case "Docker": return "shippingbox"
        case "Python": return "terminal"
        case "npm": return "cube.box"
        default: return "desktopcomputer"
        }
    }

    private func openDesktopExtensionArchive() {
        guard let archivePreview else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: archivePreview.filePath))
    }

    private func toggle(_ id: String) {
        guard toolIsEligible(id) else { return }
        if selectedTools.contains(id) { selectedTools.remove(id) }
        else                          { selectedTools.insert(id) }
    }

    private func toggleSelectAll() {
        let supported = eligibleToolIDs
        if allSelected {
            supported.forEach { selectedTools.remove($0) }
        } else {
            supported.forEach { selectedTools.insert($0) }
        }
    }

    private func pruneIneligibleSelections() {
        selectedTools = selectedTools.filter(toolIsEligible)
    }

    private func runImport() {
        guard canImport else { return }
        importResults = []
        let toolLookup = Dictionary(uniqueKeysWithValues:
            mcpStore.detectedTools.map { ($0.toolID, $0.label) })

        let scope: ConfigScope = useProjectScope ? .project : .user
        let root = scope == .project ? projectRoot : nil

        let batch = servers.map { (name: $0.name, config: $0.config) }
        for toolID in selectedTools {
            let label = toolLookup[toolID] ?? toolID
            let suffix = scope == .project ? " (project)" : ""
            let path = ConfigWriter.previewPath(toolID: toolID, scope: scope, projectRoot: root)

            guard let path else {
                appendImportResults(
                    success: false,
                    toolID: toolID,
                    toolLabel: label + suffix,
                    scope: scope,
                    projectRoot: root,
                    configPath: nil,
                    message: "No writable config path for this target."
                )
                continue
            }

            guard let preview = ConfigWriter.previewWriteBatch(
                toolID: toolID,
                scope: scope,
                projectRoot: root,
                servers: batch
            ) else {
                appendImportResults(
                    success: false,
                    toolID: toolID,
                    toolLabel: label + suffix,
                    scope: scope,
                    projectRoot: root,
                    configPath: path,
                    message: "Could not build an approved preview for this target."
                )
                continue
            }

            do {
                try ConfigWriter.applyTextPreview(
                    configPath: path,
                    expectedBefore: preview.before,
                    approvedAfter: preview.after
                )
                appendImportResults(
                    success: true,
                    toolID: toolID,
                    toolLabel: label + suffix,
                    scope: scope,
                    projectRoot: root,
                    configPath: path,
                    message: nil
                )
            } catch {
                appendImportResults(
                    success: false,
                    toolID: toolID,
                    toolLabel: label + suffix,
                    scope: scope,
                    projectRoot: root,
                    configPath: path,
                    message: error.localizedDescription
                )
            }
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            stage = .done
        }
    }

    private func appendImportResults(
        success: Bool,
        toolID: String,
        toolLabel: String,
        scope: ConfigScope,
        projectRoot: String?,
        configPath: String?,
        message: String?
    ) {
        for server in servers {
            importResults.append(.init(
                serverName: server.name,
                toolID: toolID,
                toolLabel: toolLabel,
                scope: scope,
                projectRoot: projectRoot,
                configPath: configPath,
                success: success,
                message: message
            ))
        }
    }

    private func pickProjectRoot() {
        let panel = NSOpenPanel()
        panel.title = "Choose a project folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            projectRoot = url.path
        }
    }

    // MARK: - Helpers for the "Next steps" section

    private func uniqueServerNames(_ results: [ImportResult]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for r in results where seen.insert(r.serverName).inserted {
            ordered.append(r.serverName)
        }
        return ordered
    }

    private func installedToolsForServer(name: String, wins: [ImportResult]) -> [NextStepsCard.InstalledTool] {
        wins
            .filter { $0.serverName == name }
            .compactMap { r -> NextStepsCard.InstalledTool? in
                guard let path = r.configPath
                    ?? ConfigWriter.previewPath(toolID: r.toolID, scope: r.scope, projectRoot: r.projectRoot)
                else { return nil }
                return .init(
                    id: "\(r.toolID)|\(r.scope.rawValue)|\(r.projectRoot ?? "")",
                    toolID: r.toolID,
                    toolLabel: r.toolLabel,
                    path: path,
                    scope: r.scope,
                    projectRoot: r.projectRoot
                )
            }
    }

    private func credentialRequirements(for name: String) -> [ImportCredentialRequirement] {
        guard let server = servers.first(where: { $0.name == name }) else {
            return []
        }
        return ImportCredentialPlanner.requirements(for: server)
    }
}

// MARK: - Preview row (server with editable name)

private struct ServerPreviewRow: View {
    @Binding var server: ParsedServer

    var body: some View {
        HStack(spacing: 10) {
            // Kind chip
            VStack {
                Image(systemName: iconName(for: server.kindLabel))
                    .font(.system(size: 13))
                    .foregroundColor(HubTheme.accent)
            }
            .frame(width: 28, height: 28)
            .background(HubTheme.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                TextField("Server name", text: $server.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))

                Text(server.kindLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)

                if let credentialSummary = ImportCredentialPlanner.requirementSummary(for: server) {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("Needs: \(credentialSummary)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(HubTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(HubTheme.line.opacity(0.55), lineWidth: 0.5)
        )
    }

    private func iconName(for label: String) -> String {
        switch label {
        case "Remote": return "globe"
        case "Docker": return "shippingbox"
        case "Python": return "terminal"
        case "npm": return "cube.box"
        default: return "desktopcomputer"
        }
    }
}

// MARK: - Tool picker row

private struct ToolPickerRow: View {
    let tool: ToolSummary
    let selected: Bool
    let supported: Bool
    let note: String?
    let onToggle: () -> Void

    var body: some View {
        let c = ToolPalette.color(for: tool.toolID)

        Button(action: { if supported { onToggle() } }) {
            HStack(spacing: 10) {
                // Icon tile — real app icon when installed, SF Symbol fallback
                Group {
                    if let appImg = ToolPalette.appImage(for: tool.toolID) {
                        Image(nsImage: appImg)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(c.opacity(0.14))
                                .frame(width: 26, height: 26)
                            Image(systemName: ToolPalette.icon(for: tool.toolID))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(c)
                        }
                    }
                }

                Text(tool.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(supported ? .primary : .secondary)

                if let note {
                    Text("— \(note)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }

                Spacer()

                if supported {
                    Image(systemName: selected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14))
                        .foregroundColor(selected ? c : .secondary.opacity(0.5))
                } else {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.secondary.opacity(0.4))
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selected ? c.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .disabled(!supported)
        .opacity(supported ? 1 : 0.6)
    }
}
