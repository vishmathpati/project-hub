import XCTest
@testable import ProjectHub

final class ImportParserArchiveTests: XCTestCase {
    func testMCPBDesktopExtensionArchivePreviewsManifest() throws {
        let archive = try makeArchive(extension: "mcpb") { root in
            try writeDesktopExtensionManifest(in: root)
        }

        let preview = try XCTUnwrap(try ImportParser.previewDesktopExtensionArchive(at: archive).get())
        XCTAssertEqual(preview.name, "demo-extension")
        XCTAssertEqual(preview.displayName, "Demo Extension")
        XCTAssertEqual(preview.version, "1.0.0")
        XCTAssertEqual(preview.author, "Example")
        XCTAssertTrue(preview.manifestPath.lowercased().hasSuffix("manifest.json"))
        XCTAssertEqual(preview.commandPreview, "node ${__dirname}/server/index.js")
        XCTAssertEqual(preview.toolNames, ["search_files"])
        XCTAssertEqual(preview.requiredUserConfig, ["api_key"])
    }

    func testMCPBDesktopExtensionArchiveRejectsMissingMCPConfig() throws {
        let archive = try makeArchive(extension: "mcpb") { root in
            let manifest = root.appendingPathComponent("manifest.json")
            try """
            {
              "mcpb_version": "0.1",
              "name": "broken-extension",
              "version": "1.0.0",
              "description": "Missing launch config",
              "author": { "name": "Example" },
              "server": {
                "type": "node",
                "entry_point": "server/index.js"
              }
            }
            """.write(to: manifest, atomically: true, encoding: .utf8)
        }

        switch ImportParser.previewDesktopExtensionArchive(at: archive) {
        case .success(let preview):
            XCTFail("Expected invalid MCPB manifest, got \(preview)")
        case .failure(let error):
            XCTAssertEqual(error.errorDescription, ImportParseError.archiveInvalidManifest.errorDescription)
        }
    }

    func testMCPBDesktopExtensionArchiveAllowsUVWithoutMCPConfig() throws {
        let archive = try makeArchive(extension: "mcpb") { root in
            let manifest = root.appendingPathComponent("manifest.json")
            try """
            {
              "manifest_version": "0.4",
              "name": "uv-extension",
              "display_name": "UV Extension",
              "version": "1.0.0",
              "description": "Host-managed UV extension",
              "author": { "name": "Example" },
              "server": {
                "type": "uv",
                "entry_point": "src/server.py"
              },
              "user_config": {
                "api_key": {
                  "type": "string",
                  "required": true
                }
              }
            }
            """.write(to: manifest, atomically: true, encoding: .utf8)
        }

        let preview = try XCTUnwrap(try ImportParser.previewDesktopExtensionArchive(at: archive).get())

        XCTAssertEqual(preview.name, "uv-extension")
        XCTAssertEqual(preview.displayName, "UV Extension")
        XCTAssertEqual(preview.commandPreview, "uv src/server.py (Claude Desktop managed)")
        XCTAssertEqual(preview.requiredUserConfig, ["api_key"])
    }

    func testZipWithNonExtensionManifestFallsBackToSourceArchive() throws {
        let archive = try makeArchive(extension: "zip") { root in
            let manifest = root.appendingPathComponent("manifest.json")
            try """
            {
              "name": "ordinary-node-package",
              "private": true,
              "scripts": { "start": "node index.js" }
            }
            """.write(to: manifest, atomically: true, encoding: .utf8)
            try writeReadme(in: root)
        }

        switch ImportParser.previewDesktopExtensionArchive(at: archive) {
        case .success(let preview):
            XCTFail("Expected non-extension manifest to fall through, got \(preview)")
        case .failure(let error):
            XCTAssertEqual(error.errorDescription, ImportParseError.archiveNotDesktopExtensionManifest.errorDescription)
        }

        let preview = try XCTUnwrap(try ImportParser.previewSourceArchive(at: archive).get())
        XCTAssertEqual(preview.servers.first?.name, "example-server")
        XCTAssertTrue(preview.sourcePath.lowercased().hasSuffix("readme.md"))
    }

    func testZipWithMalformedNonExtensionManifestFallsBackToSourceArchive() throws {
        let archive = try makeArchive(extension: "zip") { root in
            try "{ this is not json".write(to: root.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
            try writeReadme(in: root)
        }

        switch ImportParser.previewDesktopExtensionArchive(at: archive) {
        case .success(let preview):
            XCTFail("Expected malformed generic manifest to fall through, got \(preview)")
        case .failure(let error):
            XCTAssertEqual(error.errorDescription, ImportParseError.archiveNotDesktopExtensionManifest.errorDescription)
        }

        let preview = try XCTUnwrap(try ImportParser.previewSourceArchive(at: archive).get())
        XCTAssertEqual(preview.servers.first?.config["command"] as? String, "npx")
    }

    func testZipSourceArchiveFindsReadmeMCPConfig() throws {
        let archive = try makeArchive(extension: "zip") { root in
            try writeReadme(in: root)
        }

        let preview = try XCTUnwrap(try ImportParser.previewSourceArchive(at: archive).get())
        XCTAssertEqual(preview.servers.count, 1)
        XCTAssertEqual(preview.servers[0].name, "example-server")
        XCTAssertTrue(preview.sourcePath.lowercased().hasSuffix("readme.md"))
        XCTAssertEqual(preview.choices.count, 1)
        XCTAssertTrue(preview.choices[0].source.lowercased().contains("readme.md"))
        XCTAssertEqual(preview.servers[0].config["command"] as? String, "npx")
        XCTAssertEqual(preview.servers[0].config["args"] as? [String], ["-y", "@example/mcp-server"])
    }

    func testTarGzSourceArchiveFindsMCPJson() throws {
        let archive = try makeArchive(extension: "tar.gz") { root in
            let config = root.appendingPathComponent("mcp.json")
            try """
            {
              "mcpServers": {
                "archive-server": {
                  "command": "uvx",
                  "args": ["archive-mcp"]
                }
              }
            }
            """.write(to: config, atomically: true, encoding: .utf8)
        }

        let preview = try XCTUnwrap(try ImportParser.previewSourceArchive(at: archive).get())
        XCTAssertEqual(preview.servers.count, 1)
        XCTAssertEqual(preview.servers[0].name, "archive-server")
        XCTAssertTrue(preview.sourcePath.lowercased().hasSuffix("mcp.json"))
        XCTAssertEqual(preview.choices.count, 1)
        XCTAssertEqual(preview.servers[0].config["command"] as? String, "uvx")
        XCTAssertEqual(preview.servers[0].config["args"] as? [String], ["archive-mcp"])
    }

    func testSourceArchivePrefersRegistryServerJson() throws {
        let archive = try makeArchive(extension: "zip") { root in
            try writeReadme(in: root)
            let registry = root.appendingPathComponent("server.json")
            try """
            {
              "name": "io.github.username/archive-registry-mcp",
              "packages": [
                {
                  "registryType": "npm",
                  "identifier": "@example/archive-registry-mcp",
                  "transport": { "type": "stdio" }
                }
              ]
            }
            """.write(to: registry, atomically: true, encoding: .utf8)
        }

        let preview = try XCTUnwrap(try ImportParser.previewSourceArchive(at: archive).get())
        XCTAssertEqual(preview.servers.count, 1)
        XCTAssertTrue(preview.sourcePath.lowercased().hasSuffix("server.json"))
        XCTAssertEqual(preview.choices.count, 2)
        XCTAssertTrue(preview.choices[0].source.lowercased().contains("server.json"))
        XCTAssertTrue(preview.choices[1].source.lowercased().contains("readme.md"))
        XCTAssertEqual(preview.servers[0].name, "archive-registry-mcp-npm")
        XCTAssertEqual(preview.servers[0].config["command"] as? String, "npx")
        XCTAssertEqual(preview.servers[0].config["args"] as? [String], ["-y", "@example/archive-registry-mcp"])
    }

    func testSourceArchiveRegistryServerJsonCanExposeMCPBHandoff() throws {
        let archive = try makeArchive(extension: "zip") { root in
            let registry = root.appendingPathComponent("server.json")
            try """
            {
              "name": "io.github.example/archive-desktop-tools",
              "packages": [
                {
                  "registryType": "mcpb",
                  "identifier": "https://github.com/example/archive-desktop-tools/releases/download/v1.0.0/archive-desktop-tools.mcpb",
                  "fileSha256": "deadbeef"
                }
              ]
            }
            """.write(to: registry, atomically: true, encoding: .utf8)
        }

        let preview = try XCTUnwrap(try ImportParser.previewSourceArchive(at: archive).get())
        XCTAssertEqual(preview.servers.count, 0)
        XCTAssertTrue(preview.sourcePath.lowercased().hasSuffix("server.json"))
        XCTAssertEqual(preview.choices.count, 1)
        XCTAssertEqual(preview.choices[0].label, "Registry MCPB package")
        XCTAssertEqual(preview.choices[0].archiveURL?.lastPathComponent, "archive-desktop-tools.mcpb")
        XCTAssertEqual(preview.choices[0].archiveSHA256, "deadbeef")
    }

    func testSourceArchiveCollectsMultipleReadmeChoices() throws {
        let archive = try makeArchive(extension: "zip") { root in
            let readme = root.appendingPathComponent("README.md")
            try """
            # Example MCP Server

            ```bash
            npx -y @example/mcp-server
            ```

            ```bash
            docker run -i --rm ghcr.io/example/mcp-server
            ```
            """.write(to: readme, atomically: true, encoding: .utf8)
        }

        let preview = try XCTUnwrap(try ImportParser.previewSourceArchive(at: archive).get())
        XCTAssertEqual(preview.choices.count, 2)
        XCTAssertEqual(preview.choices.map(\.label), ["npm command", "Docker command"])
        XCTAssertEqual(preview.servers.first?.config["command"] as? String, "npx")
        XCTAssertTrue(preview.choices.allSatisfy { $0.source.lowercased().contains("readme.md") })
    }

    func testSourceArchiveCollectsMultipleConfigFileChoices() throws {
        let archive = try makeArchive(extension: "zip") { root in
            let mcpConfig = root.appendingPathComponent("mcp.json")
            try """
            {
              "mcpServers": {
                "npm-server": {
                  "command": "npx",
                  "args": ["-y", "@example/npm-server"]
                }
              }
            }
            """.write(to: mcpConfig, atomically: true, encoding: .utf8)

            let fetchConfig = root.appendingPathComponent("mcp-fetch.json")
            try """
            {
              "mcpServers": {
                "python-server": {
                  "command": "uvx",
                  "args": ["example-python-server"]
                }
              }
            }
            """.write(to: fetchConfig, atomically: true, encoding: .utf8)
        }

        let preview = try XCTUnwrap(try ImportParser.previewSourceArchive(at: archive).get())
        XCTAssertEqual(preview.choices.count, 2)
        XCTAssertTrue(preview.choices.map(\.source).contains { $0.lowercased().contains("mcp.json") })
        XCTAssertTrue(preview.choices.map(\.source).contains { $0.lowercased().contains("mcp-fetch.json") })
        XCTAssertEqual(Set(preview.choices.flatMap { $0.servers.map(\.name) }), ["npm-server", "python-server"])
    }

    func testSourceArchiveFindsVendorMCPSettingsConfig() throws {
        let archive = try makeArchive(extension: "zip") { root in
            let config = root.appendingPathComponent("mcp_settings.json")
            try """
            {
              "mcpServers": {
                "roo-server": {
                  "command": "npx",
                  "args": ["-y", "@example/roo-server"]
                }
              }
            }
            """.write(to: config, atomically: true, encoding: .utf8)
        }

        let preview = try XCTUnwrap(try ImportParser.previewSourceArchive(at: archive).get())
        XCTAssertEqual(preview.servers.first?.name, "roo-server")
        XCTAssertEqual(preview.servers.first?.config["command"] as? String, "npx")
    }

    func testSourceArchiveFindsCodexConfigToml() throws {
        let archive = try makeArchive(extension: "zip") { root in
            let codexDir = root.appendingPathComponent(".codex", isDirectory: true)
            try FileManager.default.createDirectory(at: codexDir, withIntermediateDirectories: true)
            try """
            [mcp_servers.docs]
            command = "npx"
            args = ["-y", "@example/docs-mcp"]
            """.write(to: codexDir.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        }

        let preview = try XCTUnwrap(try ImportParser.previewSourceArchive(at: archive).get())
        XCTAssertEqual(preview.choices.count, 1)
        XCTAssertTrue(preview.choices.first?.source.lowercased().contains(".codex/config.toml") == true)
        XCTAssertEqual(preview.choices.first?.servers.first?.name, "docs")
        XCTAssertEqual(preview.choices.first?.servers.first?.config["command"] as? String, "npx")
    }

    func testSourceArchiveFindsCodexConfigTomlAfterManyInvalidConfigCandidates() throws {
        let archive = try makeArchive(extension: "zip") { root in
            for index in 0..<17 {
                let invalidDir = root.appendingPathComponent(String(format: "invalid-%02d", index), isDirectory: true)
                try FileManager.default.createDirectory(at: invalidDir, withIntermediateDirectories: true)
                try #"{"name":"not importable"}"#
                    .write(to: invalidDir.appendingPathComponent("server.json"), atomically: true, encoding: .utf8)
            }

            let codexDir = root.appendingPathComponent(".codex", isDirectory: true)
            try FileManager.default.createDirectory(at: codexDir, withIntermediateDirectories: true)
            try """
            ["mcp_servers"."late.docs"]
            command = "npx"
            args = ["-y", "@example/late-docs-mcp"]
            """.write(to: codexDir.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        }

        let preview = try XCTUnwrap(try ImportParser.previewSourceArchive(at: archive).get())
        XCTAssertTrue(preview.scannedPaths.count > 16)
        XCTAssertTrue(preview.choices.first?.source.lowercased().contains(".codex/config.toml") == true)
        XCTAssertEqual(preview.choices.first?.servers.first?.name, "late.docs")
    }

    func testSourceArchiveRegistryManifestAlternativesBecomeChoices() throws {
        let archive = try makeArchive(extension: "zip") { root in
            let registry = root.appendingPathComponent("server.json")
            try """
            {
              "name": "io.github.acme/demo",
              "remotes": [
                { "type": "streamable-http", "url": "https://demo.example.com/mcp" }
              ],
              "packages": [
                {
                  "registryType": "npm",
                  "identifier": "@acme/demo",
                  "transport": { "type": "stdio" }
                }
              ]
            }
            """.write(to: registry, atomically: true, encoding: .utf8)
        }

        let preview = try XCTUnwrap(try ImportParser.previewSourceArchive(at: archive).get())
        XCTAssertEqual(preview.choices.map(\.label), ["Registry HTTP remote", "Registry npm package"])
        XCTAssertTrue(preview.choices.allSatisfy { $0.source.lowercased().contains("server.json") })
        XCTAssertEqual(preview.choices[0].servers[0].config["url"] as? String, "https://demo.example.com/mcp")
        XCTAssertEqual(preview.choices[1].servers[0].config["command"] as? String, "npx")
    }

    func testSourceArchiveDeduplicatesRepeatedChoicesAcrossFiles() throws {
        let archive = try makeArchive(extension: "zip") { root in
            try writeReadme(in: root)
            let docs = root.appendingPathComponent("docs", isDirectory: true)
            try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
            try writeReadme(in: docs)
        }

        let preview = try XCTUnwrap(try ImportParser.previewSourceArchive(at: archive).get())
        XCTAssertEqual(preview.choices.count, 1)
        XCTAssertEqual(preview.servers.first?.name, "example-server")
    }

    func testSourceArchiveKeepsWizardHandoffAlongsideSafeChoices() throws {
        let archive = try makeArchive(extension: "zip") { root in
            try """
            # Mixed installer README

            ```bash
            npx -y @acme/server
            ```

            ```bash
            docker run -i --rm ghcr.io/acme/server
            ```

            ```bash
            npx @posthog/wizard mcp add
            ```
            """.write(to: root.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        }

        let preview = try XCTUnwrap(try ImportParser.previewSourceArchive(at: archive).get())
        XCTAssertEqual(preview.choices.map(\.label), ["npm command", "Docker command"])
        XCTAssertEqual(preview.servers.first?.config["command"] as? String, "npx")
        XCTAssertEqual(preview.interactiveInstaller?.rawCommand, "npx @posthog/wizard mcp add")
    }

    func testSourceArchiveReturnsInteractiveInstallerHandoffFromReadme() throws {
        let archive = try makeArchive(extension: "zip") { root in
            try """
            # PostHog MCP

            ```bash
            npx @posthog/wizard mcp add
            ```
            """.write(to: root.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        }

        let preview = try XCTUnwrap(try ImportParser.previewSourceArchive(at: archive).get())
        XCTAssertEqual(preview.sourcePath, "sample-server/README.md")
        XCTAssertTrue(preview.servers.isEmpty)
        XCTAssertTrue(preview.choices.isEmpty)
        XCTAssertEqual(preview.interactiveInstaller?.rawCommand, "npx @posthog/wizard mcp add")
        XCTAssertEqual(preview.interactiveInstaller?.runtime, "Node package installer")
    }

    private func makeArchive(extension archiveExtension: String, populate: (URL) throws -> Void) throws -> URL {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubImportParserArchiveTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: temp)
        }

        let root = temp.appendingPathComponent("sample-server", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try populate(root)

        let archive = temp.appendingPathComponent("sample-server.\(archiveExtension)")
        if ["zip", "mcpb", "dxt"].contains(archiveExtension) {
            try run("/usr/bin/zip", ["-qr", archive.path, "sample-server"], in: temp)
        } else {
            try run("/usr/bin/tar", ["-czf", archive.path, "sample-server"], in: temp)
        }
        return archive
    }

    private func writeReadme(in root: URL) throws {
        let readme = root.appendingPathComponent("README.md")
        try """
        # Example MCP Server

        ```json
        {
          "mcpServers": {
            "example-server": {
              "command": "npx",
              "args": ["-y", "@example/mcp-server"]
            }
          }
        }
        ```
        """.write(to: readme, atomically: true, encoding: .utf8)
    }

    private func writeDesktopExtensionManifest(in root: URL) throws {
        try """
        {
          "mcpb_version": "0.1",
          "name": "demo-extension",
          "display_name": "Demo Extension",
          "version": "1.0.0",
          "description": "A demo desktop extension",
          "author": { "name": "Example" },
          "server": {
            "type": "node",
            "entry_point": "server/index.js",
            "mcp_config": {
              "command": "node",
              "args": ["${__dirname}/server/index.js"],
              "env": {
                "API_KEY": "${user_config.api_key}"
              }
            }
          },
          "user_config": {
            "api_key": {
              "type": "string",
              "title": "API Key",
              "required": true,
              "sensitive": true
            },
            "base_url": {
              "type": "string",
              "title": "Base URL"
            }
          },
          "tools": [
            { "name": "search_files", "description": "Search files" }
          ]
        }
        """.write(to: root.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
    }

    private func run(_ executable: String, _ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }
}
