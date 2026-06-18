import XCTest
@testable import ProjectHub

final class ImportParserGitHubURLTests: XCTestCase {
    func testGitHubRepositoryURLPrefersServerJSONBeforeReadme() throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/modelcontextprotocol/servers"))
        let urls = fetch.candidates.map { $0.url.absoluteString }

        XCTAssertEqual(urls.first, "https://raw.githubusercontent.com/modelcontextprotocol/servers/HEAD/server.json")
        XCTAssertTrue(urls.contains("https://raw.githubusercontent.com/modelcontextprotocol/servers/HEAD/mcp.json"))
        XCTAssertTrue(urls.contains("https://raw.githubusercontent.com/modelcontextprotocol/servers/HEAD/mcp-fetch.json"))
        XCTAssertTrue(urls.contains("https://raw.githubusercontent.com/modelcontextprotocol/servers/HEAD/mcp_settings.json"))
        XCTAssertTrue(urls.contains("https://raw.githubusercontent.com/modelcontextprotocol/servers/HEAD/cline_mcp_settings.json"))
        XCTAssertTrue(urls.contains("https://raw.githubusercontent.com/modelcontextprotocol/servers/HEAD/.codex/config.toml"))
        XCTAssertTrue(urls.contains("https://raw.githubusercontent.com/modelcontextprotocol/servers/HEAD/.cursor/mcp.json"))
        XCTAssertTrue(urls.contains("https://raw.githubusercontent.com/modelcontextprotocol/servers/HEAD/.vscode/mcp.json"))
        XCTAssertTrue(urls.contains("https://raw.githubusercontent.com/modelcontextprotocol/servers/HEAD/.roo/mcp.json"))
        XCTAssertTrue(urls.contains("https://raw.githubusercontent.com/modelcontextprotocol/servers/HEAD/README.md"))
        XCTAssertLessThan(
            try XCTUnwrap(urls.firstIndex(of: "https://raw.githubusercontent.com/modelcontextprotocol/servers/HEAD/server.json")),
            try XCTUnwrap(urls.firstIndex(of: "https://raw.githubusercontent.com/modelcontextprotocol/servers/HEAD/README.md"))
        )
        XCTAssertTrue(fetch.candidates[0].note.contains("server.json"))
        XCTAssertEqual(fetch.discoveries.first?.url.absoluteString, "https://api.github.com/repos/modelcontextprotocol/servers/git/trees/HEAD?recursive=1")
    }

    func testGitHubRepositoryURLStripsGitSuffix() throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo.git"))

        XCTAssertEqual(fetch.candidates.first?.url.absoluteString, "https://raw.githubusercontent.com/acme/demo/HEAD/server.json")
    }

    func testGitHubTreeSubdirectoryURLPreservesRefAndPrefix() throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo/tree/main/packages/github-mcp"))
        let paths = fetch.candidates.map(\.path)

        XCTAssertEqual(fetch.candidates.first?.url.absoluteString, "https://raw.githubusercontent.com/acme/demo/main/packages/github-mcp/server.json")
        XCTAssertEqual(paths.prefix(4), [
            "packages/github-mcp/server.json",
            "packages/github-mcp/mcp.json",
            "packages/github-mcp/mcp-fetch.json",
            "packages/github-mcp/.mcp.json"
        ])
        XCTAssertTrue(paths.contains("packages/github-mcp/mcp_settings.json"))
        XCTAssertTrue(paths.contains("packages/github-mcp/cline_mcp_settings.json"))
        XCTAssertTrue(paths.contains("packages/github-mcp/.codex/config.toml"))
        XCTAssertTrue(paths.contains("packages/github-mcp/.cursor/mcp.json"))
        XCTAssertTrue(paths.contains("packages/github-mcp/.vscode/mcp.json"))
        XCTAssertTrue(paths.contains("packages/github-mcp/.roo/mcp.json"))
        XCTAssertTrue(paths.contains("packages/github-mcp/README.md"))
        XCTAssertFalse(fetch.discoveries.isEmpty)
    }

    func testGitHubTreeURLIncludesSlashRefFallbackCandidates() throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo/tree/feature/foo/packages/github-mcp"))
        let urls = fetch.candidates.map { $0.url.absoluteString }
        let paths = fetch.candidates.map(\.path)

        XCTAssertEqual(fetch.candidates.first?.url.absoluteString, "https://raw.githubusercontent.com/acme/demo/feature/foo/packages/github-mcp/server.json")
        XCTAssertTrue(urls.contains("https://api.github.com/repos/acme/demo/contents/packages/github-mcp/server.json?ref=feature%2Ffoo"))
        XCTAssertTrue(urls.contains("https://api.github.com/repos/acme/demo/contents/packages/github-mcp/.codex/config.toml?ref=feature%2Ffoo"))
        XCTAssertTrue(paths.contains("foo/packages/github-mcp/server.json"))
        XCTAssertTrue(paths.contains("packages/github-mcp/server.json"))
        XCTAssertTrue(paths.contains("packages/github-mcp/.codex/config.toml"))
        XCTAssertEqual(Set(urls).count, urls.count)
        XCTAssertTrue(fetch.candidates.first?.note.contains("feature") == true)
    }

    func testGitHubBlobURLFetchesOnlyBlobPathCandidates() throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo/blob/main/examples/mcp.json"))

        XCTAssertEqual(fetch.candidates.first?.url.absoluteString, "https://raw.githubusercontent.com/acme/demo/main/examples/mcp.json")
        XCTAssertEqual(fetch.candidates[0].path, "examples/mcp.json")
        XCTAssertFalse(fetch.candidates.map(\.path).contains("server.json"))
        XCTAssertFalse(fetch.candidates.map(\.path).contains("README.md"))
        XCTAssertTrue(fetch.candidates[0].note.contains("main"))
    }

    func testGitHubRawRouteURLFetchesOnlyRawPathCandidates() throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo/raw/main/examples/mcp.json"))

        XCTAssertEqual(fetch.candidates.first?.url.absoluteString, "https://raw.githubusercontent.com/acme/demo/main/examples/mcp.json")
        XCTAssertEqual(fetch.candidates.first?.path, "examples/mcp.json")
        XCTAssertFalse(fetch.candidates.map(\.path).contains("server.json"))
        XCTAssertFalse(fetch.candidates.map(\.path).contains("README.md"))
        XCTAssertTrue(fetch.discoveries.isEmpty)
        XCTAssertNil(fetch.registryLookup)
    }

    func testGitHubBlobURLIncludesSlashRefFallbackCandidate() throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo/blob/feature/foo/examples/mcp.json"))
        let urls = fetch.candidates.map { $0.url.absoluteString }

        XCTAssertEqual(fetch.candidates.first?.url.absoluteString, "https://raw.githubusercontent.com/acme/demo/feature/foo/examples/mcp.json")
        XCTAssertTrue(urls.contains("https://api.github.com/repos/acme/demo/contents/examples/mcp.json?ref=feature%2Ffoo"))
        XCTAssertEqual(Set(urls).count, urls.count)
        XCTAssertTrue(fetch.candidates.contains { $0.path == "examples/mcp.json" && $0.note.contains("feature/foo") })
    }

    func testGitHubUnsupportedPathsFallBackToNormalURLHandling() {
        XCTAssertNil(ImportParser.githubContentFetch(from: "https://github.com/acme/demo/issues/1"))
        XCTAssertNil(ImportParser.githubContentFetch(from: "https://raw.githubusercontent.com/acme/demo/main/docs/notes.txt"))
        XCTAssertNil(ImportParser.githubContentFetch(from: "https://mcp.example.com/mcp"))
    }

    func testRawGitHubConfigURLCreatesSinglePrimaryCandidate() throws {
        let rawURL = "https://raw.githubusercontent.com/acme/demo/main/mcp.json"
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: rawURL))

        XCTAssertEqual(fetch.candidates.count, 1)
        XCTAssertEqual(fetch.candidates.first?.url.absoluteString, rawURL)
        XCTAssertEqual(fetch.candidates.first?.path, "mcp.json")
        XCTAssertTrue(fetch.candidates.first?.note.contains("acme/demo/mcp.json") == true)
        XCTAssertTrue(fetch.discoveries.isEmpty)
        XCTAssertNil(fetch.registryLookup)
    }

    func testRawGitHubCodexConfigURLCreatesCandidate() throws {
        let rawURL = "https://raw.githubusercontent.com/acme/demo/main/.codex/config.toml"
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: rawURL))

        XCTAssertEqual(fetch.candidates.first?.url.absoluteString, rawURL)
        XCTAssertEqual(fetch.candidates.first?.path, ".codex/config.toml")
        XCTAssertTrue(fetch.discoveries.isEmpty)
        XCTAssertNil(fetch.registryLookup)
    }

    func testRawGitHubSlashRefURLIncludesContentsAPIFallback() throws {
        let rawURL = "https://raw.githubusercontent.com/acme/demo/feature/foo/examples/mcp.json"
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: rawURL))
        let urls = fetch.candidates.map { $0.url.absoluteString }
        let paths = fetch.candidates.map(\.path)

        XCTAssertEqual(fetch.candidates.first?.url.absoluteString, rawURL)
        XCTAssertEqual(fetch.candidates.first?.path, "foo/examples/mcp.json")
        XCTAssertTrue(urls.contains("https://api.github.com/repos/acme/demo/contents/examples/mcp.json?ref=feature%2Ffoo"))
        XCTAssertTrue(paths.contains("examples/mcp.json"))
        XCTAssertEqual(Set(urls).count, urls.count)
        XCTAssertTrue(fetch.discoveries.isEmpty)
        XCTAssertNil(fetch.registryLookup)
    }

    func testGitHubReleaseURLsShowArchiveGuidanceInsteadOfRemoteServerImport() {
        for raw in [
            "https://github.com/acme/demo/releases/latest",
            "https://github.com/acme/demo/releases/tag/v1.2.3",
            "https://github.com/acme/demo/releases/download/v1/server",
            "https://github.com/acme/demo/archive/refs/tags/v1.2.3.zip"
        ] {
            switch ImportParser.parse(raw) {
            case .success(let servers):
                XCTFail("Expected archive guidance for \(raw), got \(servers)")
            case .failure(let error):
                XCTAssertEqual(error.errorDescription, ImportParseError.archiveReference.errorDescription)
            }
        }
    }

    func testPasteModeRawGitHubConfigURLShowsFromURLGuidance() {
        switch ImportParser.parse("https://raw.githubusercontent.com/acme/demo/main/mcp.json") {
        case .success(let servers):
            XCTFail("Expected GitHub raw URL guidance, got \(servers)")
        case .failure(let error):
            XCTAssertEqual(error.errorDescription, ImportParseError.githubRepository.errorDescription)
            XCTAssertTrue(error.errorDescription?.contains("Use From URL") == true)
        }
    }

    func testPasteModeRemoteConfigDocumentURLShowsFromURLGuidance() {
        for raw in [
            "https://gist.githubusercontent.com/acme/abc123/raw/mcp.json",
            "https://pastebin.com/raw/abc123",
            "https://example.com/mcp-fetch.json",
            "https://example.com/mcp_settings.json",
            "https://example.com/cline_mcp_settings.json",
            "https://example.com/.codex/config.toml"
        ] {
            switch ImportParser.parse(raw) {
            case .success(let servers):
                XCTFail("Expected config document URL guidance for \(raw), got \(servers)")
            case .failure(let error):
                XCTAssertEqual(error.errorDescription, ImportParseError.remoteConfigDocument.errorDescription)
                XCTAssertTrue(error.errorDescription?.contains("Use From URL") == true)
            }
        }
    }

    func testPasteModeHostedMCPEndpointStillImportsAsRemoteServer() throws {
        switch ImportParser.parse("https://mcp.example.com/mcp") {
        case .success(let servers):
            let server = try XCTUnwrap(servers.first)
            XCTAssertEqual(server.kindLabel, "Remote")
            XCTAssertEqual(server.config["type"] as? String, "http")
            XCTAssertEqual(server.config["url"] as? String, "https://mcp.example.com/mcp")
        case .failure(let error):
            XCTFail("Expected remote MCP endpoint import, got \(error)")
        }
    }

    func testPasteModeRepositoryURLShowsFromURLGuidance() {
        switch ImportParser.parse("https://github.com/acme/demo") {
        case .success(let servers):
            XCTFail("Expected GitHub repository guidance, got \(servers)")
        case .failure(let error):
            XCTAssertEqual(error.errorDescription, ImportParseError.githubRepository.errorDescription)
            XCTAssertTrue(error.errorDescription?.contains("Use From URL") == true)
            XCTAssertTrue(error.errorDescription?.contains("server.json") == true)
        }
    }

    func testGitHubResolverStopsAtFirstParseableCandidate() async {
        let fetch = GitHubContentFetch(candidates: [
            candidate("server.json"),
            candidate("mcp.json"),
            candidate("README.md")
        ])

        let resolution = await ImportParser.resolveGitHubContent(fetch) { candidate in
            switch candidate.path {
            case "server.json":
                return #"{"name":"not importable"}"#
            case "mcp.json":
                return """
                {
                  "mcpServers": {
                    "github": {
                      "command": "npx",
                      "args": ["-y", "@modelcontextprotocol/server-github"]
                    }
                  }
                }
                """
            default:
                XCTFail("Resolver should stop before README.md")
                return "# README"
            }
        }

        XCTAssertEqual(resolution.matchedCandidate?.path, "mcp.json")
        XCTAssertEqual(resolution.lastFetchedCandidate?.path, "mcp.json")
        XCTAssertTrue(resolution.didFindParseableConfig)
        XCTAssertEqual(resolution.attemptedPaths, ["server.json", "mcp.json"])
        XCTAssertEqual(resolution.fetchedPaths, ["server.json", "mcp.json"])
        XCTAssertEqual(resolution.attempts[0].parseErrorDescription, ImportParseError.noServersFound.errorDescription)
        XCTAssertEqual(resolution.servers.first?.name, "github")
    }

    func testRawGitHubConfigResolverParsesFetchedConfig() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://raw.githubusercontent.com/acme/demo/main/mcp.json"))

        let resolution = await ImportParser.resolveGitHubContent(fetch) { candidate in
            XCTAssertEqual(candidate.path, "mcp.json")
            return """
            {
              "mcpServers": {
                "github": {
                  "command": "npx",
                  "args": ["-y", "@modelcontextprotocol/server-github"]
                }
              }
            }
            """
        }

        XCTAssertTrue(resolution.didFindParseableConfig)
        XCTAssertEqual(resolution.matchedCandidate?.path, "mcp.json")
        XCTAssertEqual(resolution.servers.first?.name, "github")
    }

    func testGitHubResolverDoesNotDiscoverWhenDirectConfigParses() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo"))
        var discoveryCallCount = 0

        let resolution = await ImportParser.resolveGitHubContent(
            fetch,
            fetchText: { candidate in
                if candidate.path == "server.json" {
                    return """
                    {
                      "mcpServers": {
                        "direct": { "command": "npx", "args": ["-y", "@acme/direct"] }
                      }
                    }
                    """
                }
                throw URLError(.fileDoesNotExist)
            },
            fetchDiscoveryText: { _ in
                discoveryCallCount += 1
                return #"{"tree":[]}"#
            }
        )

        XCTAssertEqual(resolution.matchedCandidate?.path, "server.json")
        XCTAssertEqual(discoveryCallCount, 0)
    }

    func testGitHubResolverSkipsFetchMissesAndKeepsLastFetchedTextWhenNothingParses() async {
        let fetch = GitHubContentFetch(candidates: [
            candidate("server.json"),
            candidate("mcp.json"),
            candidate("README.md")
        ])

        let resolution = await ImportParser.resolveGitHubContent(fetch) { candidate in
            if candidate.path == "server.json" {
                throw URLError(.fileDoesNotExist)
            }
            if candidate.path == "mcp.json" {
                return #"{"name":"still not importable"}"#
            }
            return "# Install manually"
        }

        XCTAssertNil(resolution.matchedCandidate)
        XCTAssertEqual(resolution.lastFetchedCandidate?.path, "README.md")
        XCTAssertEqual(resolution.attemptedPaths, ["server.json", "mcp.json", "README.md"])
        XCTAssertEqual(resolution.fetchedPaths, ["mcp.json", "README.md"])
        XCTAssertNotNil(resolution.attempts[0].fetchErrorDescription)
        XCTAssertEqual(resolution.attempts[1].parseErrorDescription, ImportParseError.noServersFound.errorDescription)
        XCTAssertTrue(resolution.servers.isEmpty)
        XCTAssertEqual(resolution.lastFetchedText, "# Install manually")
    }

    func testGitHubResolverReportsAllAttemptedPathsWhenNothingFetches() async {
        let fetch = GitHubContentFetch(candidates: [
            candidate("server.json"),
            candidate("mcp.json")
        ])

        let resolution = await ImportParser.resolveGitHubContent(fetch) { _ in
            throw URLError(.badServerResponse)
        }

        XCTAssertNil(resolution.matchedCandidate)
        XCTAssertNil(resolution.lastFetchedCandidate)
        XCTAssertEqual(resolution.attemptedPaths, ["server.json", "mcp.json"])
        XCTAssertTrue(resolution.fetchedPaths.isEmpty)
        XCTAssertTrue(resolution.lastFetchedText.isEmpty)
        XCTAssertTrue(resolution.servers.isEmpty)
        XCTAssertTrue(resolution.attempts.allSatisfy { $0.fetchErrorDescription != nil })
    }

    func testGitHubResolverUsesReadmeAfterConfigCandidatesMiss() async {
        let fetch = GitHubContentFetch(candidates: [
            candidate("server.json"),
            candidate("mcp.json"),
            candidate("README.md")
        ])

        let resolution = await ImportParser.resolveGitHubContent(fetch) { candidate in
            if candidate.path != "README.md" {
                throw URLError(.fileDoesNotExist)
            }
            return """
            Install with:

            $ npx -y @modelcontextprotocol/server-github
            """
        }

        XCTAssertEqual(resolution.matchedCandidate?.path, "README.md")
        XCTAssertTrue(resolution.didFindParseableConfig)
        XCTAssertEqual(resolution.attemptedPaths, ["server.json", "mcp.json", "README.md"])
        XCTAssertEqual(resolution.fetchedPaths, ["README.md"])
        XCTAssertEqual(resolution.servers.first?.config["command"] as? String, "npx")
    }

    func testGitHubResolverReturnsInteractiveInstallerHandoffFromReadme() async {
        let fetch = GitHubContentFetch(candidates: [
            candidate("server.json"),
            candidate("mcp.json"),
            candidate("README.md")
        ])

        let resolution = await ImportParser.resolveGitHubContent(fetch) { candidate in
            if candidate.path != "README.md" {
                throw URLError(.fileDoesNotExist)
            }
            return """
            Install with:

            ```bash
            npx @posthog/wizard mcp add
            ```
            """
        }

        XCTAssertEqual(resolution.matchedCandidate?.path, "README.md")
        XCTAssertTrue(resolution.needsInteractiveInstallerHandoff)
        XCTAssertTrue(resolution.servers.isEmpty)
        XCTAssertTrue(resolution.importChoices.isEmpty)
        XCTAssertEqual(resolution.interactiveInstaller?.rawCommand, "npx @posthog/wizard mcp add")
        XCTAssertEqual(resolution.interactiveInstaller?.runtime, "Node package installer")
    }

    func testReadmeImportChoicesCollectMultipleSafeSnippets() {
        let choices = ImportParser.importChoices(from: """
        Install with npm:

        ```bash
        npx -y @acme/server
        ```

        Or use Python:

        ```bash
        uvx acme-server
        ```
        """)

        XCTAssertEqual(choices.count, 2)
        XCTAssertEqual(choices.map(\.label), ["npm command", "Python command"])
        XCTAssertEqual(choices[0].servers.first?.config["command"] as? String, "npx")
        XCTAssertEqual(choices[1].servers.first?.config["command"] as? String, "uvx")
        XCTAssertTrue(choices[0].rawText.contains("@acme/server"))
    }

    func testReadmeImportChoicesDeduplicateRepeatedSnippet() {
        let choices = ImportParser.importChoices(from: """
        ```bash
        npx -y @acme/server
        ```

        $ npx -y @acme/server
        """)

        XCTAssertEqual(choices.count, 1)
        XCTAssertEqual(choices.first?.servers.first?.config["command"] as? String, "npx")
    }

    func testGitHubResolverReturnsReadmeChoicesWhenMultipleSnippetsAreParseable() async {
        let fetch = GitHubContentFetch(candidates: [
            candidate("server.json"),
            candidate("README.md")
        ])

        let resolution = await ImportParser.resolveGitHubContent(fetch) { candidate in
            if candidate.path != "README.md" {
                throw URLError(.fileDoesNotExist)
            }
            return """
            ```bash
            npx -y @acme/server
            ```

            ```bash
            docker run -i --rm ghcr.io/acme/server
            ```
            """
        }

        XCTAssertFalse(resolution.didFindParseableConfig)
        XCTAssertTrue(resolution.needsUserChoice)
        XCTAssertEqual(resolution.matchedCandidate?.path, "README.md")
        XCTAssertEqual(resolution.importChoices.count, 2)
        XCTAssertEqual(resolution.importChoices.map(\.label), ["npm command", "Docker command"])
        XCTAssertTrue(resolution.servers.isEmpty)
    }

    func testGitHubResolverKeepsWizardHandoffAlongsideSafeReadmeChoices() async {
        let fetch = GitHubContentFetch(candidates: [
            candidate("server.json"),
            candidate("README.md")
        ])

        let resolution = await ImportParser.resolveGitHubContent(fetch) { candidate in
            if candidate.path != "README.md" {
                throw URLError(.fileDoesNotExist)
            }
            return """
            ```bash
            npx -y @acme/server
            ```

            ```bash
            docker run -i --rm ghcr.io/acme/server
            ```

            ```bash
            npx @posthog/wizard mcp add
            ```
            """
        }

        XCTAssertTrue(resolution.needsUserChoice)
        XCTAssertEqual(resolution.importChoices.count, 2)
        XCTAssertEqual(resolution.importChoices.map(\.label), ["npm command", "Docker command"])
        XCTAssertEqual(resolution.interactiveInstaller?.rawCommand, "npx @posthog/wizard mcp add")
    }

    func testRawGitHubReadmeResolverReturnsChoicesWhenMultipleSnippetsAreParseable() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://raw.githubusercontent.com/acme/demo/main/README.md"))

        let resolution = await ImportParser.resolveGitHubContent(fetch) { candidate in
            XCTAssertEqual(candidate.path, "README.md")
            return """
            ```bash
            npx -y @acme/server
            ```

            ```bash
            docker run -i --rm ghcr.io/acme/server
            ```
            """
        }

        XCTAssertFalse(resolution.didFindParseableConfig)
        XCTAssertTrue(resolution.needsUserChoice)
        XCTAssertEqual(resolution.matchedCandidate?.path, "README.md")
        XCTAssertEqual(resolution.importChoices.count, 2)
    }

    func testGitHubResolverInsertsDiscoveredServerJSONBeforeReadmeFallback() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo"))

        let resolution = await ImportParser.resolveGitHubContent(
            fetch,
            fetchText: { candidate in
                switch candidate.path {
                case "packages/github-mcp/server.json":
                    return """
                    {
                      "packages": [
                        {
                          "registryType": "npm",
                          "identifier": "@acme/github-mcp",
                          "version": "1.0.0",
                          "transport": { "type": "stdio" }
                        }
                      ]
                    }
                    """
                case "README.md":
                    XCTFail("Discovered server.json should parse before README.md")
                    return "$ npx -y @acme/fallback"
                default:
                    throw URLError(.fileDoesNotExist)
                }
            },
            fetchDiscoveryText: { _ in
                """
                {
                  "tree": [
                    { "path": "README.md", "type": "blob" },
                    { "path": "packages/github-mcp/server.json", "type": "blob" },
                    { "path": "examples/deep/path/too/far/server.json", "type": "blob" }
                  ]
                }
                """
            }
        )

        XCTAssertEqual(resolution.matchedCandidate?.path, "packages/github-mcp/server.json")
        XCTAssertTrue(resolution.attemptedPaths.contains("packages/github-mcp/server.json"))
        XCTAssertFalse(resolution.attemptedPaths.contains("README.md"))
        XCTAssertFalse(resolution.attemptedPaths.contains("examples/deep/path/too/far/server.json"))
        XCTAssertEqual(resolution.servers.first?.config["command"] as? String, "npx")
    }

    func testGitHubResolverDiscoversNestedMCPJsonBeforeReadmeFallback() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo"))

        let resolution = await ImportParser.resolveGitHubContent(
            fetch,
            fetchText: { candidate in
                switch candidate.path {
                case "packages/github-mcp/mcp.json":
                    return """
                    {
                      "mcpServers": {
                        "github": {
                          "command": "npx",
                          "args": ["-y", "@acme/github-mcp"]
                        }
                      }
                    }
                    """
                case "README.md":
                    XCTFail("Discovered mcp.json should parse before README.md")
                    return "$ npx -y @acme/fallback"
                default:
                    throw URLError(.fileDoesNotExist)
                }
            },
            fetchDiscoveryText: { _ in
                """
                {
                  "tree": [
                    { "path": "README.md", "type": "blob" },
                    { "path": "packages/github-mcp/mcp.json", "type": "blob" }
                  ]
                }
                """
            }
        )

        XCTAssertEqual(resolution.matchedCandidate?.path, "packages/github-mcp/mcp.json")
        XCTAssertTrue(resolution.attemptedPaths.contains("packages/github-mcp/mcp.json"))
        XCTAssertFalse(resolution.attemptedPaths.contains("README.md"))
        XCTAssertEqual(resolution.servers.first?.name, "github")
        XCTAssertEqual(resolution.servers.first?.config["command"] as? String, "npx")
    }

    func testGitHubResolverDiscoversNestedMCPFetchJson() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo"))

        let resolution = await ImportParser.resolveGitHubContent(
            fetch,
            fetchText: { candidate in
                switch candidate.path {
                case "examples/demo/mcp-fetch.json":
                    return """
                    {
                      "servers": {
                        "demo": {
                          "command": "uvx",
                          "args": ["acme-demo-mcp"]
                        }
                      }
                    }
                    """
                default:
                    throw URLError(.fileDoesNotExist)
                }
            },
            fetchDiscoveryText: { _ in
                """
                {
                  "tree": [
                    { "path": "examples/demo/mcp-fetch.json", "type": "blob" }
                  ]
                }
                """
            }
        )

        XCTAssertEqual(resolution.matchedCandidate?.path, "examples/demo/mcp-fetch.json")
        XCTAssertEqual(resolution.servers.first?.name, "demo")
        XCTAssertEqual(resolution.servers.first?.config["command"] as? String, "uvx")
    }

    func testGitHubResolverDiscoversNestedRooMCPJson() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo"))

        let resolution = await ImportParser.resolveGitHubContent(
            fetch,
            fetchText: { candidate in
                switch candidate.path {
                case "packages/roo-example/.roo/mcp.json":
                    return """
                    {
                      "mcpServers": {
                        "roo-docs": {
                          "url": "https://example.com/roo/mcp"
                        }
                      }
                    }
                    """
                default:
                    throw URLError(.fileDoesNotExist)
                }
            },
            fetchDiscoveryText: { _ in
                """
                {
                  "tree": [
                    { "path": "packages/roo-example/.roo/mcp.json", "type": "blob" }
                  ]
                }
                """
            }
        )

        XCTAssertEqual(resolution.matchedCandidate?.path, "packages/roo-example/.roo/mcp.json")
        XCTAssertEqual(resolution.servers.first?.name, "roo-docs")
        XCTAssertEqual(resolution.servers.first?.config["url"] as? String, "https://example.com/roo/mcp")
    }

    func testGitHubResolverDiscoversNestedCodexConfigTomlBeforeReadmeFallback() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo"))

        let resolution = await ImportParser.resolveGitHubContent(
            fetch,
            fetchText: { candidate in
                switch candidate.path {
                case "packages/codex-demo/.codex/config.toml":
                    return """
                    [mcp_servers.docs]
                    command = "npx"
                    args = ["-y", "@example/docs-mcp"]
                    """
                case "README.md":
                    XCTFail("Nested Codex config should parse before README fallback")
                    return "$ npx -y @example/readme-mcp"
                default:
                    throw URLError(.fileDoesNotExist)
                }
            },
            fetchDiscoveryText: { _ in
                """
                {
                  "tree": [
                    { "path": "README.md", "type": "blob" },
                    { "path": "packages/codex-demo/.codex/config.toml", "type": "blob" }
                  ]
                }
                """
            }
        )

        XCTAssertEqual(resolution.matchedCandidate?.path, "packages/codex-demo/.codex/config.toml")
        XCTAssertEqual(resolution.servers.first?.name, "docs")
        XCTAssertEqual(resolution.servers.first?.config["command"] as? String, "npx")
        XCTAssertEqual(resolution.servers.first?.config["args"] as? [String], ["-y", "@example/docs-mcp"])
    }

    func testGitHubTreeSubdirectoryDiscoveryKeepsPrefixBoundaryForMCPJson() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo/tree/main/packages/github-mcp"))

        let resolution = await ImportParser.resolveGitHubContent(
            fetch,
            fetchText: { candidate in
                switch candidate.path {
                case "packages/github-mcp/config/mcp.json":
                    return """
                    {
                      "mcpServers": {
                        "scoped": {
                          "command": "npx",
                          "args": ["-y", "@acme/scoped-mcp"]
                        }
                      }
                    }
                    """
                case "packages/other/mcp.json":
                    XCTFail("Discovery should not fetch configs outside the selected GitHub tree prefix")
                    throw URLError(.badURL)
                default:
                    throw URLError(.fileDoesNotExist)
                }
            },
            fetchDiscoveryText: { _ in
                """
                {
                  "tree": [
                    { "path": "packages/other/mcp.json", "type": "blob" },
                    { "path": "packages/github-mcp/config/mcp.json", "type": "blob" }
                  ]
                }
                """
            }
        )

        XCTAssertEqual(resolution.matchedCandidate?.path, "packages/github-mcp/config/mcp.json")
        XCTAssertTrue(resolution.attemptedPaths.contains("packages/github-mcp/config/mcp.json"))
        XCTAssertFalse(resolution.attemptedPaths.contains("packages/other/mcp.json"))
        XCTAssertEqual(resolution.servers.first?.name, "scoped")
    }

    func testGitHubRepositoryURLCreatesRegistryLookupButBlobDoesNot() throws {
        let repoFetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo"))
        XCTAssertNotNil(repoFetch.registryLookup)
        XCTAssertEqual(repoFetch.registryLookup?.owner, "acme")
        XCTAssertEqual(repoFetch.registryLookup?.repo, "demo")
        XCTAssertTrue(repoFetch.registryLookup?.allowAnySubfolder == true)
        XCTAssertEqual(repoFetch.registryLookup?.firstPageURL.absoluteString, "https://registry.modelcontextprotocol.io/v0.1/servers?version=latest&limit=100")

        let blobFetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo/blob/main/server.json"))
        XCTAssertNil(blobFetch.registryLookup)
    }

    func testGitHubResolverUsesRegistryMatchBeforeReadmeFallback() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo"))
        var registryCalls = 0

        let resolution = await ImportParser.resolveGitHubContent(
            fetch,
            fetchText: { candidate in
                if candidate.path == "README.md" {
                    XCTFail("Registry match should parse before README.md")
                    return "$ npx -y @acme/readme"
                }
                throw URLError(.fileDoesNotExist)
            },
            fetchDiscoveryText: { _ in #"{"tree":[]}"# },
            fetchRegistryText: { request in
                registryCalls += 1
                XCTAssertEqual(request.page, 1)
                return self.registryListResponse(repositoryURL: "https://github.com/acme/demo")
            }
        )

        XCTAssertEqual(registryCalls, 1)
        XCTAssertEqual(resolution.matchedCandidate?.path, "MCP Registry: io.github.acme/demo")
        XCTAssertEqual(resolution.matchedCandidate?.note, "Matched MCP Registry metadata for acme/demo.")
        XCTAssertEqual(resolution.servers.first?.name, "demo-npm")
        XCTAssertEqual(resolution.servers.first?.config["command"] as? String, "npx")
        XCTAssertTrue(resolution.attemptedPaths.contains("MCP Registry page 1"))
        XCTAssertFalse(resolution.attemptedPaths.contains("README.md"))
    }

    func testGitHubResolverDoesNotCallRegistryWhenDirectConfigParses() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo"))
        var registryCalls = 0

        let resolution = await ImportParser.resolveGitHubContent(
            fetch,
            fetchText: { candidate in
                if candidate.path == "server.json" {
                    return self.registryServerJSON(repositoryURL: "https://github.com/acme/demo")
                }
                throw URLError(.fileDoesNotExist)
            },
            fetchDiscoveryText: { _ in #"{"tree":[]}"# },
            fetchRegistryText: { _ in
                registryCalls += 1
                return #"{"servers":[]}"#
            }
        )

        XCTAssertEqual(resolution.matchedCandidate?.path, "server.json")
        XCTAssertEqual(registryCalls, 0)
    }

    func testGitHubResolverReturnsChoicesForDirectRegistryManifestAlternatives() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo"))

        let resolution = await ImportParser.resolveGitHubContent(
            fetch,
            fetchText: { candidate in
                if candidate.path == "server.json" {
                    return self.registryServerJSONWithRemoteAndPackage(repositoryURL: "https://github.com/acme/demo")
                }
                throw URLError(.fileDoesNotExist)
            },
            fetchDiscoveryText: { _ in #"{"tree":[]}"# },
            fetchRegistryText: { _ in
                XCTFail("Direct server.json alternatives should parse before registry lookup")
                return #"{"servers":[]}"#
            }
        )

        XCTAssertFalse(resolution.didFindParseableConfig)
        XCTAssertTrue(resolution.needsUserChoice)
        XCTAssertEqual(resolution.matchedCandidate?.path, "server.json")
        XCTAssertEqual(resolution.importChoices.map(\.label), ["Registry HTTP remote", "Registry npm package"])
        XCTAssertTrue(resolution.servers.isEmpty)
    }

    func testGitHubRegistryMatchWithAlternativesReturnsChoicesBeforeReadmeFallback() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo"))

        let resolution = await ImportParser.resolveGitHubContent(
            fetch,
            fetchText: { candidate in
                if candidate.path == "README.md" {
                    XCTFail("Registry choices should be offered before README.md")
                    return "$ npx -y @acme/readme"
                }
                throw URLError(.fileDoesNotExist)
            },
            fetchDiscoveryText: { _ in #"{"tree":[]}"# },
            fetchRegistryText: { _ in
                self.registryListResponse(
                    serverJSON: self.registryServerJSONWithRemoteAndPackage(repositoryURL: "https://github.com/acme/demo")
                )
            }
        )

        XCTAssertFalse(resolution.didFindParseableConfig)
        XCTAssertTrue(resolution.needsUserChoice)
        XCTAssertEqual(resolution.matchedCandidate?.path, "MCP Registry: io.github.acme/demo")
        XCTAssertEqual(resolution.importChoices.map(\.label), ["Registry HTTP remote", "Registry npm package"])
        XCTAssertTrue(resolution.attemptedPaths.contains("MCP Registry page 1"))
        XCTAssertFalse(resolution.attemptedPaths.contains("README.md"))
    }

    func testGitHubRegistryMissFallsThroughToReadme() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo"))

        let resolution = await ImportParser.resolveGitHubContent(
            fetch,
            fetchText: { candidate in
                if candidate.path == "README.md" {
                    return "$ npx -y @acme/readme"
                }
                throw URLError(.fileDoesNotExist)
            },
            fetchDiscoveryText: { _ in #"{"tree":[]}"# },
            fetchRegistryText: { _ in
                self.registryListResponse(repositoryURL: "https://github.com/other/demo")
            }
        )

        XCTAssertEqual(resolution.matchedCandidate?.path, "README.md")
        XCTAssertEqual(resolution.servers.first?.config["args"] as? [String], ["-y", "@acme/readme"])
        XCTAssertTrue(resolution.attemptedPaths.contains("MCP Registry page 1"))
    }

    func testGitHubRegistryFetchFailureFallsThroughToReadme() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo"))

        let resolution = await ImportParser.resolveGitHubContent(
            fetch,
            fetchText: { candidate in
                if candidate.path == "README.md" {
                    return "$ npx -y @acme/readme"
                }
                throw URLError(.fileDoesNotExist)
            },
            fetchDiscoveryText: { _ in #"{"tree":[]}"# },
            fetchRegistryText: { _ in throw URLError(.timedOut) }
        )

        XCTAssertEqual(resolution.matchedCandidate?.path, "README.md")
        XCTAssertTrue(resolution.attempts.contains { $0.candidate.path == "MCP Registry page 1" && $0.fetchErrorDescription != nil })
    }

    func testGitHubTreeRegistryLookupRequiresMatchingSubfolder() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo/tree/main/packages/github-mcp"))
        XCTAssertEqual(fetch.registryLookup?.acceptableSubfolders.first, "packages/github-mcp")

        let resolution = await ImportParser.resolveGitHubContent(
            fetch,
            fetchText: { candidate in
                if candidate.path == "README.md" {
                    XCTFail("Matching registry subfolder should parse before README.md")
                    return "$ npx -y @acme/readme"
                }
                throw URLError(.fileDoesNotExist)
            },
            fetchDiscoveryText: { _ in #"{"tree":[]}"# },
            fetchRegistryText: { _ in
                self.registryListResponse(repositoryURL: "https://github.com/acme/demo", subfolder: "packages/github-mcp")
            }
        )

        XCTAssertEqual(resolution.matchedCandidate?.path, "MCP Registry: io.github.acme/demo (packages/github-mcp)")
        XCTAssertEqual(resolution.matchedCandidate?.note, "Matched MCP Registry metadata for acme/demo in packages/github-mcp.")
    }

    func testGitHubTreeRegistryRejectsDifferentSubfolderAndFallsThroughToReadme() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo/tree/main/packages/github-mcp"))

        let resolution = await ImportParser.resolveGitHubContent(
            fetch,
            fetchText: { candidate in
                if candidate.path == "packages/github-mcp/README.md" {
                    return "$ npx -y @acme/readme"
                }
                throw URLError(.fileDoesNotExist)
            },
            fetchDiscoveryText: { _ in #"{"tree":[]}"# },
            fetchRegistryText: { _ in
                self.registryListResponse(repositoryURL: "https://github.com/acme/demo", subfolder: "packages/other")
            }
        )

        XCTAssertEqual(resolution.matchedCandidate?.path, "packages/github-mcp/README.md")
    }

    func testGitHubRegistryMultipleMatchesAreAmbiguousAndFallThroughToReadme() async throws {
        let fetch = try XCTUnwrap(ImportParser.githubContentFetch(from: "https://github.com/acme/demo"))

        let resolution = await ImportParser.resolveGitHubContent(
            fetch,
            fetchText: { candidate in
                if candidate.path == "README.md" {
                    return "$ npx -y @acme/readme"
                }
                throw URLError(.fileDoesNotExist)
            },
            fetchDiscoveryText: { _ in #"{"tree":[]}"# },
            fetchRegistryText: { _ in
                """
                {
                  "servers": [
                    { "server": \(self.registryServerJSON(repositoryURL: "https://github.com/acme/demo")) },
                    { "server": \(self.registryServerJSON(name: "io.github.acme/demo-two", repositoryURL: "https://github.com/acme/demo")) }
                  ],
                  "metadata": {}
                }
                """
            }
        )

        XCTAssertEqual(resolution.matchedCandidate?.path, "README.md")
        XCTAssertTrue(resolution.attempts.contains { $0.parseErrorDescription == "MCP Registry returned multiple servers for this GitHub repository." })
    }

    private func candidate(_ path: String) -> GitHubContentCandidate {
        GitHubContentCandidate(
            url: URL(string: "https://raw.githubusercontent.com/acme/demo/HEAD/\(path)")!,
            path: path,
            note: "Read acme/demo/\(path) from GitHub."
        )
    }

    private func registryListResponse(repositoryURL: String, subfolder: String? = nil) -> String {
        registryListResponse(serverJSON: registryServerJSON(repositoryURL: repositoryURL, subfolder: subfolder))
    }

    private func registryListResponse(serverJSON: String) -> String {
        """
        {
          "servers": [
            {
              "server": \(serverJSON),
              "_meta": {
                "io.modelcontextprotocol.registry/official": {
                  "status": "active",
                  "isLatest": true
                }
              }
            }
          ],
          "metadata": {}
        }
        """
    }

    private func registryServerJSON(name: String = "io.github.acme/demo", repositoryURL: String, subfolder: String? = nil) -> String {
        let subfolderJSON = subfolder.map { #", "subfolder": "\#($0)""# } ?? ""
        return """
        {
          "name": "\(name)",
          "repository": {
            "url": "\(repositoryURL)",
            "source": "github"\(subfolderJSON)
          },
          "version": "1.0.0",
          "packages": [
            {
              "registryType": "npm",
              "identifier": "@acme/demo",
              "version": "1.0.0",
              "transport": { "type": "stdio" }
            }
          ]
        }
        """
    }

    private func registryServerJSONWithRemoteAndPackage(repositoryURL: String) -> String {
        """
        {
          "name": "io.github.acme/demo",
          "repository": {
            "url": "\(repositoryURL)",
            "source": "github"
          },
          "version": "1.0.0",
          "remotes": [
            { "type": "streamable-http", "url": "https://demo.example.com/mcp" }
          ],
          "packages": [
            {
              "registryType": "npm",
              "identifier": "@acme/demo",
              "version": "1.0.0",
              "transport": { "type": "stdio" }
            }
          ]
        }
        """
    }
}
