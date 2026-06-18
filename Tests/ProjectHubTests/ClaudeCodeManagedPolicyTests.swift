import XCTest
@testable import ProjectHub

final class ClaudeCodeManagedPolicyTests: XCTestCase {
    func testManagedSettingsDropInsAndPolicyKeysAreScanned() throws {
        let root = try makeTempDirectory()
        let managed = root.appendingPathComponent("managed", isDirectory: true)
        let dropInDir = managed.appendingPathComponent("managed-settings.d", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: dropInDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        {
          "allowedMcpServers": ["github"],
          "deniedMcpServers": ["danger"],
          "allowManagedMcpServersOnly": true
        }
        """.write(to: managed.appendingPathComponent("managed-settings.json"), atomically: true, encoding: .utf8)
        try """
        {
          "allowedMcpServers": ["context7"]
        }
        """.write(to: dropInDir.appendingPathComponent("10-extra.json"), atomically: true, encoding: .utf8)

        withClaudeManagedDirectory(managed.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let managedSettingsPath = managed.appendingPathComponent("managed-settings.json").path
            let dropInPath = dropInDir.appendingPathComponent("10-extra.json").path

            XCTAssertTrue(report.matrix.contains {
                $0.id == "claude-code-managed-settings-macos"
                    && $0.path == managedSettingsPath
                    && $0.canWriteSafely == false
            })
            XCTAssertTrue(report.matrix.contains {
                $0.id.hasPrefix("claude-code-managed-settings-dropin|")
                    && $0.path == dropInPath
                    && $0.canWriteSafely == false
                    && $0.requiresRestartAfterWrite == false
            })
            XCTAssertTrue(report.settings.contains {
                $0.path == dropInPath
                    && $0.keys == ["allowedMcpServers"]
            })

            let managedIssues = report.issues.filter {
                $0.code == .settingsManagedRequirement
                    && ($0.path == managedSettingsPath || $0.path == dropInPath)
            }
            XCTAssertTrue(managedIssues.contains { $0.title == "Claude MCP allowlist configured" })
            XCTAssertTrue(managedIssues.contains { $0.title == "Claude MCP denylist configured" })
            XCTAssertTrue(managedIssues.contains { $0.title == "Only managed Claude MCP allowlist applies" })
        }
    }

    func testEmptyManagedMcpFileReportsAdministratorDisabledState() throws {
        let root = try makeTempDirectory()
        let managed = root.appendingPathComponent("managed", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: managed, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "mcpServers": {}
        }
        """.write(to: managed.appendingPathComponent("managed-mcp.json"), atomically: true, encoding: .utf8)

        withClaudeManagedDirectory(managed.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let managedMcpPath = managed.appendingPathComponent("managed-mcp.json").path
            let issues = report.issues.filter {
                $0.code == .settingsManagedRequirement
                    && $0.path == managedMcpPath
                    && $0.title == "Claude Code MCP disabled by managed policy"
            }

            XCTAssertFalse(issues.isEmpty)
            XCTAssertTrue(issues.allSatisfy { $0.fixHint?.contains("administrator-controlled") == true })
        }
    }

    func testDeniedMcpServerIsMarkedDisabled() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(
            at: project.appendingPathComponent(".claude", isDirectory: true),
            withIntermediateDirectories: true
        )
        try """
        {
          "mcpServers": {
            "danger": {
              "command": "/bin/echo",
              "args": ["ok"]
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)
        try """
        {
          "deniedMcpServers": [
            { "serverName": "danger" }
          ]
        }
        """.write(to: project.appendingPathComponent(".claude/settings.json"), atomically: true, encoding: .utf8)

        let report = CompatibilityScanner.scan(projectRoot: project.path)
        let server = try XCTUnwrap(report.servers.first {
            $0.surfaceID == "claude-code-project-mcp" && $0.name == "danger"
        })
        XCTAssertEqual(server.health, .disabled)
        XCTAssertTrue(server.issueCodes.contains(.serverDisabled))
        XCTAssertTrue(report.issues.contains {
            $0.code == .serverDisabled
                && $0.title == "Claude MCP blocked by denylist"
                && $0.subjectPath == "danger"
        })
    }

    func testMcpAllowlistRequiresExactCommandWhenCommandRulesExist() throws {
        let root = try makeTempDirectory()
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(
            at: project.appendingPathComponent(".claude", isDirectory: true),
            withIntermediateDirectories: true
        )
        try """
        {
          "mcpServers": {
            "approved": {
              "command": "/bin/echo",
              "args": ["ok"]
            },
            "blocked": {
              "command": "/bin/echo",
              "args": ["different"]
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)
        try """
        {
          "allowedMcpServers": [
            { "serverCommand": ["/bin/echo", "ok"] }
          ]
        }
        """.write(to: project.appendingPathComponent(".claude/settings.json"), atomically: true, encoding: .utf8)

        let report = CompatibilityScanner.scan(projectRoot: project.path)
        let approved = try XCTUnwrap(report.servers.first {
            $0.surfaceID == "claude-code-project-mcp" && $0.name == "approved"
        })
        let blocked = try XCTUnwrap(report.servers.first {
            $0.surfaceID == "claude-code-project-mcp" && $0.name == "blocked"
        })
        XCTAssertNotEqual(approved.health, .disabled)
        XCTAssertEqual(blocked.health, .disabled)
        XCTAssertTrue(report.issues.contains {
            $0.code == .serverDisabled
                && $0.title == "Claude MCP blocked by allowlist"
                && $0.subjectPath == "blocked"
        })
    }

    func testManagedOnlyMcpAllowlistIgnoresProjectAllowlistExpansion() throws {
        let root = try makeTempDirectory()
        let managed = root.appendingPathComponent("managed", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: managed, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: project.appendingPathComponent(".claude", isDirectory: true),
            withIntermediateDirectories: true
        )
        try """
        {
          "allowManagedMcpServersOnly": true,
          "allowedMcpServers": [
            { "serverName": "managed-approved" }
          ]
        }
        """.write(to: managed.appendingPathComponent("managed-settings.json"), atomically: true, encoding: .utf8)
        try """
        {
          "allowedMcpServers": [
            { "serverName": "project-added" }
          ]
        }
        """.write(to: project.appendingPathComponent(".claude/settings.json"), atomically: true, encoding: .utf8)
        try """
        {
          "mcpServers": {
            "managed-approved": {
              "command": "/bin/echo",
              "args": ["ok"]
            },
            "project-added": {
              "command": "/bin/echo",
              "args": ["ok"]
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        try withClaudeManagedDirectory(managed.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let managedApproved = try XCTUnwrap(report.servers.first {
                $0.surfaceID == "claude-code-project-mcp" && $0.name == "managed-approved"
            })
            let projectAdded = try XCTUnwrap(report.servers.first {
                $0.surfaceID == "claude-code-project-mcp" && $0.name == "project-added"
            })

            XCTAssertNotEqual(managedApproved.health, .disabled)
            XCTAssertEqual(projectAdded.health, .disabled)
            XCTAssertTrue(report.issues.contains {
                $0.code == .serverDisabled
                    && $0.title == "Claude MCP blocked by allowlist"
                    && $0.subjectPath == "project-added"
            })
        }
    }

    func testMacOSManagedPreferencesPolicyIsScannedAsClaudeCodePolicy() throws {
        let root = try makeTempDirectory()
        let managed = root.appendingPathComponent("managed", isDirectory: true)
        let managedPreferences = root.appendingPathComponent("managed-preferences", isDirectory: true)
        let userPreferences = managedPreferences.appendingPathComponent(NSUserName(), isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: managed, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: userPreferences, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: project.appendingPathComponent(".claude", isDirectory: true),
            withIntermediateDirectories: true
        )
        try """
        {
          "allowedMcpServers": [
            { "serverName": "file-approved" }
          ]
        }
        """.write(to: managed.appendingPathComponent("managed-settings.json"), atomically: true, encoding: .utf8)
        try writePlist(
            [
                "allowManagedMcpServersOnly": true,
                "allowedMcpServers": [
                    ["serverName": "mdm-approved"]
                ],
                "deniedMcpServers": [
                    ["serverName": "mdm-denied"]
                ]
            ],
            to: userPreferences.appendingPathComponent("com.anthropic.claudecode.plist")
        )
        try """
        {
          "mcpServers": {
            "mdm-approved": {
              "command": "/bin/echo",
              "args": ["ok"]
            },
            "file-approved": {
              "command": "/bin/echo",
              "args": ["ok"]
            },
            "mdm-denied": {
              "command": "/bin/echo",
              "args": ["ok"]
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withClaudeManagedDirectory(managed.path) {
            withManagedPreferencesDirectory(managedPreferences.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let mdmPath = userPreferences.appendingPathComponent("com.anthropic.claudecode.plist").path

                XCTAssertTrue(report.matrix.contains {
                    $0.id == "claude-code-managed-policy-user"
                        && $0.path == mdmPath
                        && $0.toolID == .claudeCode
                        && $0.canWriteSafely == false
                })
                XCTAssertTrue(report.settings.contains {
                    $0.path == mdmPath
                        && $0.keys.contains("allowManagedMcpServersOnly")
                        && $0.keys.contains("allowedMcpServers")
                        && $0.keys.contains("deniedMcpServers")
                })

                let mdmApproved = report.servers.first {
                    $0.surfaceID == "claude-code-project-mcp" && $0.name == "mdm-approved"
                }
                let fileApproved = report.servers.first {
                    $0.surfaceID == "claude-code-project-mcp" && $0.name == "file-approved"
                }
                let mdmDenied = report.servers.first {
                    $0.surfaceID == "claude-code-project-mcp" && $0.name == "mdm-denied"
                }

                XCTAssertNotEqual(mdmApproved?.health, .disabled)
                XCTAssertEqual(fileApproved?.health, .disabled)
                XCTAssertEqual(mdmDenied?.health, .disabled)
                XCTAssertTrue(report.issues.contains {
                    $0.code == .serverDisabled
                        && $0.title == "Claude MCP blocked by allowlist"
                        && $0.subjectPath == "file-approved"
                })
                XCTAssertTrue(report.issues.contains {
                    $0.code == .serverDisabled
                        && $0.title == "Claude MCP blocked by denylist"
                        && $0.subjectPath == "mdm-denied"
                })
            }
        }
    }

    func testServerManagedSettingsDocumentedCacheSurfaceIsReportedReadOnly() throws {
        let root = try makeTempDirectory()
        let claudeHome = root.appendingPathComponent("claude-home", isDirectory: true)
        let managed = root.appendingPathComponent("managed", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: managed, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let remoteSettings = claudeHome.appendingPathComponent("remote-settings.json").path

        withClaudeHome(claudeHome.path) {
            withClaudeManagedDirectory(managed.path) {
                withServerManagedSettingsPath(nil) {
                    let report = CompatibilityScanner.scan(projectRoot: project.path)

                    XCTAssertTrue(report.matrix.contains {
                        $0.id == "claude-code-server-managed-settings"
                            && $0.toolID == .claudeCode
                            && $0.path == remoteSettings
                            && $0.fileControlled == false
                            && $0.canWriteSafely == false
                            && $0.format == .jsonc
                    })
                    XCTAssertFalse(report.settings.contains {
                        $0.surfaceID == "claude-code-server-managed-settings"
                    })
                    XCTAssertFalse(report.issues.contains {
                        $0.surfaceID == "claude-code-server-managed-settings"
                            && $0.title == "Claude Code server-managed settings are runtime-delivered"
                    })
                }
            }
        }
    }

    func testServerManagedSettingsTakePrecedenceOverEndpointManagedSettings() throws {
        let root = try makeTempDirectory()
        let managed = root.appendingPathComponent("managed", isDirectory: true)
        let serverManaged = root.appendingPathComponent("remote-settings.json")
        let managedPreferences = root.appendingPathComponent("managed-preferences", isDirectory: true)
        let userPreferences = managedPreferences.appendingPathComponent(NSUserName(), isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: managed, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: userPreferences, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: project.appendingPathComponent(".claude", isDirectory: true),
            withIntermediateDirectories: true
        )
        try """
        {
          "allowedMcpServers": [
            { "serverName": "file-approved" }
          ]
        }
        """.write(to: managed.appendingPathComponent("managed-settings.json"), atomically: true, encoding: .utf8)
        try writePlist(
            [
                "allowedMcpServers": [
                    ["serverName": "mdm-approved"]
                ]
            ],
            to: userPreferences.appendingPathComponent("com.anthropic.claudecode.plist")
        )
        try """
        {
          "forceRemoteSettingsRefresh": true,
          "allowManagedMcpServersOnly": true,
          "allowedMcpServers": [
            { "serverName": "remote-approved" }
          ],
          "deniedMcpServers": [
            { "serverName": "remote-denied" }
          ]
        }
        """.write(to: serverManaged, atomically: true, encoding: .utf8)
        try """
        {
          "mcpServers": {
            "remote-approved": {
              "command": "/bin/echo",
              "args": ["ok"]
            },
            "mdm-approved": {
              "command": "/bin/echo",
              "args": ["ok"]
            },
            "file-approved": {
              "command": "/bin/echo",
              "args": ["ok"]
            },
            "remote-denied": {
              "command": "/bin/echo",
              "args": ["ok"]
            }
          }
        }
        """.write(to: project.appendingPathComponent(".mcp.json"), atomically: true, encoding: .utf8)

        withClaudeManagedDirectory(managed.path) {
            withManagedPreferencesDirectory(managedPreferences.path) {
                withServerManagedSettingsPath(serverManaged.path) {
                    let report = CompatibilityScanner.scan(projectRoot: project.path)

                    XCTAssertTrue(report.settings.contains {
                        $0.surfaceID == "claude-code-server-managed-settings"
                            && $0.path == serverManaged.path
                            && $0.summary.contains("remote settings fail-closed")
                            && $0.keys.contains("forceRemoteSettingsRefresh")
                    })
                    XCTAssertNotEqual(report.servers.first {
                        $0.surfaceID == "claude-code-project-mcp" && $0.name == "remote-approved"
                    }?.health, .disabled)
                    XCTAssertEqual(report.servers.first {
                        $0.surfaceID == "claude-code-project-mcp" && $0.name == "mdm-approved"
                    }?.health, .disabled)
                    XCTAssertEqual(report.servers.first {
                        $0.surfaceID == "claude-code-project-mcp" && $0.name == "file-approved"
                    }?.health, .disabled)
                    XCTAssertEqual(report.servers.first {
                        $0.surfaceID == "claude-code-project-mcp" && $0.name == "remote-denied"
                    }?.health, .disabled)
                    XCTAssertTrue(report.issues.contains {
                        $0.code == .serverDisabled
                            && $0.title == "Claude MCP blocked by allowlist"
                            && $0.subjectPath == "mdm-approved"
                    })
                    XCTAssertTrue(report.issues.contains {
                        $0.code == .serverDisabled
                            && $0.title == "Claude MCP blocked by allowlist"
                            && $0.subjectPath == "file-approved"
                    })
                    XCTAssertTrue(report.issues.contains {
                        $0.code == .serverDisabled
                            && $0.title == "Claude MCP blocked by denylist"
                            && $0.subjectPath == "remote-denied"
                    })
                }
            }
        }
    }

    private func withClaudeManagedDirectory(_ path: String, run: () throws -> Void) rethrows {
        let managedKey = "PROJECTHUB_CLAUDE_CODE_MANAGED_DIR"
        let preferencesKey = "PROJECTHUB_MANAGED_PREFERENCES_DIR"
        let previousManaged = getenv(managedKey).map { String(cString: $0) }
        let previousPreferences = getenv(preferencesKey).map { String(cString: $0) }
        let isolatedPreferences = URL(fileURLWithPath: path)
            .deletingLastPathComponent()
            .appendingPathComponent("managed-preferences-empty", isDirectory: true)
            .path
        setenv(managedKey, path, 1)
        setenv(preferencesKey, isolatedPreferences, 1)
        defer {
            if let previousManaged {
                setenv(managedKey, previousManaged, 1)
            } else {
                unsetenv(managedKey)
            }
            if let previousPreferences {
                setenv(preferencesKey, previousPreferences, 1)
            } else {
                unsetenv(preferencesKey)
            }
        }
        try run()
    }

    private func withServerManagedSettingsPath(_ path: String?, run: () throws -> Void) rethrows {
        let key = "PROJECTHUB_CLAUDE_CODE_SERVER_MANAGED_SETTINGS_PATH"
        let previous = getenv(key).map { String(cString: $0) }
        if let path {
            setenv(key, path, 1)
        } else {
            unsetenv(key)
        }
        defer {
            if let previous {
                setenv(key, previous, 1)
            } else {
                unsetenv(key)
            }
        }
        try run()
    }

    private func withClaudeHome(_ path: String, run: () throws -> Void) rethrows {
        let key = "PROJECTHUB_CLAUDE_HOME"
        let previous = getenv(key).map { String(cString: $0) }
        setenv(key, path, 1)
        defer {
            if let previous {
                setenv(key, previous, 1)
            } else {
                unsetenv(key)
            }
        }
        try run()
    }

    private func withManagedPreferencesDirectory(_ path: String, run: () throws -> Void) rethrows {
        let key = "PROJECTHUB_MANAGED_PREFERENCES_DIR"
        let previous = getenv(key).map { String(cString: $0) }
        setenv(key, path, 1)
        defer {
            if let previous {
                setenv(key, previous, 1)
            } else {
                unsetenv(key)
            }
        }
        try run()
    }

    private func writePlist(_ dictionary: [String: Any], to url: URL) throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: dictionary,
            format: .xml,
            options: 0
        )
        try data.write(to: url)
    }

    private func makeTempDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubClaudeCodeManagedPolicyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }
}
