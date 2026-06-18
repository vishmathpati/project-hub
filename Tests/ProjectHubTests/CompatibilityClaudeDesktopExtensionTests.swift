import XCTest
@testable import ProjectHub

final class CompatibilityClaudeDesktopExtensionTests: XCTestCase {
    func testClaudeDesktopRecentLogAuthFindingIsReportedAndRedacted() throws {
        let root = try makeTempDirectory()
        let support = root.appendingPathComponent("ClaudeSupport", isDirectory: true)
        let logs = root.appendingPathComponent("ClaudeLogs", isDirectory: true)
        try writeClaudeDesktopConfig(support: support, serverName: "Supabase")
        try writeClaudeDesktopLog(
            logs: logs,
            serverName: "supabase",
            content: "Unauthorized api_key=secret123 for user admin@example.com at https://example.com/mcp\n"
        )

        try withClaudeDesktopSupport(support.path) {
            try withClaudeDesktopLogs(logs.path) {
                let report = CompatibilityScanner.scan(projectRoot: root.path)
                let issue = try XCTUnwrap(report.issues.first {
                    $0.title == "Claude Desktop log indicates auth is needed"
                })

                XCTAssertEqual(issue.code, .serverOAuthNeeded)
                XCTAssertTrue(issue.detail.contains("api_key=<redacted>"), issue.detail)
                XCTAssertTrue(issue.detail.contains("<email>"), issue.detail)
                XCTAssertTrue(issue.detail.contains("<url>"), issue.detail)
                XCTAssertFalse(issue.detail.contains("secret123"), issue.detail)
                XCTAssertFalse(issue.detail.contains("admin@example.com"), issue.detail)
            }
        }
    }

    func testClaudeDesktopRecentLogExpiredAuthFindingIsReportedAndRedacted() throws {
        let root = try makeTempDirectory()
        let support = root.appendingPathComponent("ClaudeSupport", isDirectory: true)
        let logs = root.appendingPathComponent("ClaudeLogs", isDirectory: true)
        try writeClaudeDesktopConfig(support: support, serverName: "Supabase")
        try writeClaudeDesktopLog(
            logs: logs,
            serverName: "supabase",
            content: "Token has expired token=oldsecret for user admin@example.com at https://example.com/mcp\n"
        )

        try withClaudeDesktopSupport(support.path) {
            try withClaudeDesktopLogs(logs.path) {
                let report = CompatibilityScanner.scan(projectRoot: root.path)
                let issue = try XCTUnwrap(report.issues.first {
                    $0.title == "Claude Desktop log indicates auth expired"
                })
                let server = try XCTUnwrap(report.servers.first { $0.name == "Supabase" })

                XCTAssertEqual(issue.code, .serverAuthExpired)
                XCTAssertEqual(issue.state, .authExpired)
                XCTAssertEqual(server.health, .authExpired)
                XCTAssertTrue(issue.detail.contains("token=<redacted>"), issue.detail)
                XCTAssertTrue(issue.detail.contains("<email>"), issue.detail)
                XCTAssertTrue(issue.detail.contains("<url>"), issue.detail)
                XCTAssertFalse(issue.detail.contains("oldsecret"), issue.detail)
            }
        }
    }

    func testClaudeDesktopRecentLogMissingRuntimeAndTimeoutAreReported() throws {
        let root = try makeTempDirectory()
        let support = root.appendingPathComponent("ClaudeSupport", isDirectory: true)
        let logs = root.appendingPathComponent("ClaudeLogs", isDirectory: true)
        try writeClaudeDesktopConfig(support: support, serverName: "Filesystem")
        try writeClaudeDesktopConfig(support: support, serverName: "Slow Server")
        try writeClaudeDesktopLog(logs: logs, serverName: "filesystem", content: "Error: command not found: uvx\n")
        try writeClaudeDesktopLog(logs: logs, serverName: "slow-server", content: "Request timed out while waiting for tools/list\n")

        withClaudeDesktopSupport(support.path) {
            withClaudeDesktopLogs(logs.path) {
                let report = CompatibilityScanner.scan(projectRoot: root.path)

                XCTAssertTrue(report.issues.contains {
                    $0.code == .serverCommandMissing
                        && $0.title == "Claude Desktop log indicates a missing runtime"
                })
                XCTAssertTrue(report.issues.contains {
                    $0.code == .serverHealthUnknown
                        && $0.title == "Claude Desktop log shows MCP timeout"
                })
            }
        }
    }

    func testClaudeDesktopRecentSuccessSuppressesOlderLogError() throws {
        let root = try makeTempDirectory()
        let support = root.appendingPathComponent("ClaudeSupport", isDirectory: true)
        let logs = root.appendingPathComponent("ClaudeLogs", isDirectory: true)
        try writeClaudeDesktopConfig(support: support, serverName: "Healthy")
        try writeClaudeDesktopLog(
            logs: logs,
            serverName: "healthy",
            content: """
            Unauthorized token=oldsecret
            Server started and connected successfully
            """
        )

        withClaudeDesktopSupport(support.path) {
            withClaudeDesktopLogs(logs.path) {
                let report = CompatibilityScanner.scan(projectRoot: root.path)

                XCTAssertFalse(report.issues.contains {
                    $0.title == "Claude Desktop log indicates auth is needed"
                })
            }
        }
    }

    func testClaudeDesktopStaleLogIsIgnored() throws {
        let root = try makeTempDirectory()
        let support = root.appendingPathComponent("ClaudeSupport", isDirectory: true)
        let logs = root.appendingPathComponent("ClaudeLogs", isDirectory: true)
        let log = try writeClaudeDesktopLog(logs: logs, serverName: "old-server", content: "Unauthorized token=oldsecret\n")
        try writeClaudeDesktopConfig(support: support, serverName: "Old Server")
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-15 * 24 * 60 * 60)],
            ofItemAtPath: log.path
        )

        withClaudeDesktopSupport(support.path) {
            withClaudeDesktopLogs(logs.path) {
                let report = CompatibilityScanner.scan(projectRoot: root.path)

                XCTAssertFalse(report.issues.contains {
                    $0.title == "Claude Desktop log indicates auth is needed"
                })
            }
        }
    }

    func testDesktopExtensionUserConfigPlaceholdersUseExtensionSettings() throws {
        let root = try makeTempDirectory()
        let support = root.appendingPathComponent("ClaudeSupport", isDirectory: true)
        let extensionID = "ant.dir.test.filesystem"
        let extensionDir = support
            .appendingPathComponent("Claude Extensions/\(extensionID)", isDirectory: true)
        let settingsDir = support.appendingPathComponent("Claude Extensions Settings", isDirectory: true)
        try FileManager.default.createDirectory(at: extensionDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: settingsDir, withIntermediateDirectories: true)
        try """
        {
          "display_name": "Filesystem Test",
          "user_config": {
            "allowed_directories": {
              "type": "directory",
              "multiple": true,
              "required": true,
              "default": []
            }
          },
          "server": {
            "mcp_config": {
              "command": "/bin/echo",
              "args": [
                "${__dirname}/server.js",
                "${user_config.allowed_directories}"
              ]
            }
          }
        }
        """.write(to: extensionDir.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
        try """
        {
          "isEnabled": true,
          "userConfig": {
            "allowed_directories": ["/tmp/alpha", "/tmp/beta"]
          }
        }
        """.write(to: settingsDir.appendingPathComponent("\(extensionID).json"), atomically: true, encoding: .utf8)

        try withClaudeDesktopSupport(support.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let server = try XCTUnwrap(report.servers.first { $0.name == "Filesystem Test" })

            XCTAssertEqual(server.detail, "/bin/echo \(extensionDir.path)/server.js /tmp/alpha /tmp/beta")
            XCTAssertFalse(report.issues.contains {
                $0.title == "Extension may need configuration"
                    && $0.detail.contains("allowed_directories")
            })
        }
    }

    func testDesktopExtensionUserConfigDefaultsAreSubstituted() throws {
        let root = try makeTempDirectory()
        let support = root.appendingPathComponent("ClaudeSupport", isDirectory: true)
        let extensionID = "ant.dir.test.pdf"
        let extensionDir = support
            .appendingPathComponent("Claude Extensions/\(extensionID)", isDirectory: true)
        try FileManager.default.createDirectory(at: extensionDir, withIntermediateDirectories: true)
        try """
        {
          "display_name": "PDF Test",
          "user_config": {
            "download_directory": {
              "type": "directory",
              "required": false,
              "default": "${HOME}/Downloads"
            }
          },
          "server": {
            "mcp_config": {
              "command": "/bin/echo",
              "args": ["${user_config.download_directory}"]
            }
          }
        }
        """.write(to: extensionDir.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)

        try withClaudeDesktopSupport(support.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let server = try XCTUnwrap(report.servers.first { $0.name == "PDF Test" })

            XCTAssertEqual(server.detail, "/bin/echo ${HOME}/Downloads")
            XCTAssertFalse(server.detail.contains("user_config.download_directory"))
        }
    }

    func testDesktopExtensionMissingRequiredUserConfigIsReported() throws {
        let root = try makeTempDirectory()
        let support = root.appendingPathComponent("ClaudeSupport", isDirectory: true)
        let extensionID = "ant.dir.test.needs-config"
        let extensionDir = support
            .appendingPathComponent("Claude Extensions/\(extensionID)", isDirectory: true)
        try FileManager.default.createDirectory(at: extensionDir, withIntermediateDirectories: true)
        try """
        {
          "display_name": "Needs Config",
          "user_config": {
            "api_key": {
              "type": "string",
              "required": true
            }
          },
          "server": {
            "mcp_config": {
              "command": "/bin/echo",
              "env": {
                "API_KEY": "${user_config.api_key}"
              }
            }
          }
        }
        """.write(to: extensionDir.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)

        withClaudeDesktopSupport(support.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)

            XCTAssertTrue(report.issues.contains {
                $0.title == "Extension may need configuration"
                    && $0.detail.contains("api_key")
            })
        }
    }

    func testDesktopExtensionUVWithoutMCPConfigIsReportedAsAppManagedAndChecksRequiredUserConfig() throws {
        let root = try makeTempDirectory()
        let support = root.appendingPathComponent("ClaudeSupport", isDirectory: true)
        let extensionID = "ant.dir.test.uv-managed"
        let extensionDir = support
            .appendingPathComponent("Claude Extensions/\(extensionID)", isDirectory: true)
        try FileManager.default.createDirectory(at: extensionDir, withIntermediateDirectories: true)
        try """
        {
          "manifest_version": "0.4",
          "name": "uv-managed-extension",
          "display_name": "UV Managed",
          "version": "1.0.0",
          "description": "A UV host-managed desktop extension",
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
        """.write(to: extensionDir.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)

        withClaudeDesktopSupport(support.path) {
            let report = CompatibilityScanner.scan(projectRoot: root.path)
            let server = report.servers.first { $0.name == "UV Managed" }

            XCTAssertEqual(server?.detail, "uv src/server.py")
            XCTAssertTrue(report.issues.contains {
                $0.title == "Extension runtime is app-managed"
                    && $0.detail.contains("UV Managed")
            })
            XCTAssertTrue(report.issues.contains {
                $0.title == "Extension may need configuration"
                    && $0.detail.contains("api_key")
            })
            XCTAssertFalse(report.issues.contains {
                $0.title == "Extension has no local MCP config"
                    && $0.detail.contains("UV Managed")
            })
        }
    }

    private func withClaudeDesktopSupport(_ path: String, run: () throws -> Void) rethrows {
        let root = URL(fileURLWithPath: path).deletingLastPathComponent()
        try withEnvValues([
            "PROJECTHUB_CLAUDE_DESKTOP_SUPPORT_DIR": path,
            "CODEX_HOME": root.appendingPathComponent("isolated-codex-home", isDirectory: true).path,
            "PROJECTHUB_CLAUDE_HOME": root.appendingPathComponent("isolated-claude-home", isDirectory: true).path,
            "PROJECTHUB_CLAUDE_JSON_PATH": root.appendingPathComponent("isolated-claude.json").path,
            "PROJECTHUB_CLAUDE_CODE_MANAGED_DIR": root.appendingPathComponent("isolated-managed", isDirectory: true).path,
            "PROJECTHUB_CODEX_REQUIREMENTS_PATH": root.appendingPathComponent("isolated-requirements.toml").path
        ], run: run)
    }

    private func withClaudeDesktopLogs(_ path: String, run: () throws -> Void) rethrows {
        try withEnvValues(["PROJECTHUB_CLAUDE_DESKTOP_LOGS_DIR": path], run: run)
    }

    private func withEnvValues(_ values: [String: String], run: () throws -> Void) rethrows {
        let previous = Dictionary(uniqueKeysWithValues: values.keys.map { key in
            (key, getenv(key).map { String(cString: $0) })
        })
        for (key, value) in values {
            setenv(key, value, 1)
        }
        defer {
            for key in values.keys {
                let value = previous[key] ?? nil
                if let value {
                    setenv(key, value, 1)
                } else {
                    unsetenv(key)
                }
            }
        }
        try run()
    }

    private func writeClaudeDesktopConfig(support: URL, serverName: String) throws {
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let path = support.appendingPathComponent("claude_desktop_config.json")
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: path),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = existing
        }
        var servers = root["mcpServers"] as? [String: Any] ?? [:]
        servers[serverName] = [
            "command": "/bin/echo",
            "args": []
        ]
        root["mcpServers"] = servers
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: path, options: .atomic)
    }

    @discardableResult
    private func writeClaudeDesktopLog(logs: URL, serverName: String, content: String) throws -> URL {
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let path = logs.appendingPathComponent("mcp-server-\(serverName).log")
        try content.write(to: path, atomically: true, encoding: .utf8)
        return path
    }

    private func makeTempDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubCompatibilityClaudeDesktopExtensionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }
}
