import XCTest
@testable import ProjectHub

final class ConfigWriterCodexPluginPolicyTests: XCTestCase {
    func testPreviewSetCodexPluginMCPServerEnabledCreatesMissingDisablePolicy() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent("config.toml")
        try """
        model = "gpt-5"
        """.write(to: config, atomically: true, encoding: .utf8)

        let preview = try XCTUnwrap(ConfigWriter.previewSetCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web-search",
            enabled: false
        ))

        XCTAssertTrue(preview.after.contains(#"[plugins."docs@openai-curated".mcp_servers.web-search]"#))
        XCTAssertTrue(preview.after.contains("enabled = false"))
        XCTAssertNil(ConfigWriter.previewSetCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web-search",
            enabled: true
        ))
    }

    func testSetCodexPluginMCPServerEnabledWritesBackupAndPreservesPolicyKeys() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent("config.toml")
        try """
        [plugins."docs@openai-curated".mcp_servers."web-search"]
        enabled = false
        enabled_tools = ["query"]

        [plugins."docs@openai-curated".mcp_servers."web-search".tools.query]
        approval_mode = "prompt"
        """.write(to: config, atomically: true, encoding: .utf8)

        try ConfigWriter.setCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web-search",
            enabled: true
        )

        let updated = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(updated.contains("enabled = false"))
        XCTAssertTrue(updated.contains(#"enabled_tools = ["query"]"#))
        XCTAssertTrue(updated.contains(#"approval_mode = "prompt""#))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).contains {
            $0.hasPrefix("config.toml.bak.")
        })
    }

    func testSetCodexPluginMCPServerEnabledUpdatesExistingPolicy() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent("config.toml")
        try """
        [plugins."docs@openai-curated".mcp_servers.web]
        enabled = true
        """.write(to: config, atomically: true, encoding: .utf8)

        try ConfigWriter.setCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web",
            enabled: false
        )

        let updated = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(updated.contains("enabled = false"))
        XCTAssertFalse(updated.contains("enabled = true"))
    }

    func testSetCodexPluginMCPServerEnabledRemovesExplicitEnabledTruePolicy() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent("config.toml")
        try """
        [plugins."docs@openai-curated".mcp_servers.web]
        enabled = true
        default_tools_approval_mode = "prompt"
        """.write(to: config, atomically: true, encoding: .utf8)

        let preview = try XCTUnwrap(ConfigWriter.previewSetCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web",
            enabled: true
        ))
        XCTAssertFalse(preview.after.contains("enabled = true"))
        XCTAssertTrue(preview.after.contains(#"default_tools_approval_mode = "prompt""#))

        try ConfigWriter.setCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web",
            enabled: true
        )

        let updated = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(updated.contains("enabled = true"))
        XCTAssertTrue(updated.contains(#"default_tools_approval_mode = "prompt""#))
    }

    func testSetCodexPluginMCPServerEnabledRefusesStalePreview() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent("config.toml")
        try """
        [plugins."docs@openai-curated".mcp_servers.web]
        enabled = false
        default_tools_approval_mode = "prompt"
        """.write(to: config, atomically: true, encoding: .utf8)

        let preview = try XCTUnwrap(ConfigWriter.previewSetCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web",
            enabled: true
        ))
        try """
        [plugins."docs@openai-curated".mcp_servers.web]
        enabled = false
        default_tools_approval_mode = "approve"
        """.write(to: config, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try ConfigWriter.setCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web",
            enabled: true,
            expectedBefore: preview.before
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("changed after preview"))
        }

        let updated = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(updated.contains("enabled = false"))
        XCTAssertTrue(updated.contains(#"default_tools_approval_mode = "approve""#))
    }

    func testApplyCodexPluginMCPServerEnabledPreviewWritesApprovedAfterWhenUnchanged() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent("config.toml")
        try """
        [plugins."docs@openai-curated".mcp_servers.web]
        enabled = false
        enabled_tools = ["query"]
        """.write(to: config, atomically: true, encoding: .utf8)

        let preview = try XCTUnwrap(ConfigWriter.previewSetCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web",
            enabled: true
        ))

        try ConfigWriter.applyCodexPluginMCPServerEnabledPreview(
            configPath: config.path,
            expectedBefore: preview.before,
            approvedAfter: preview.after
        )

        let updated = try String(contentsOf: config, encoding: .utf8)
        XCTAssertEqual(updated, preview.after)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).contains {
            $0.hasPrefix("config.toml.bak.")
        })
    }

    func testSetCodexPluginMCPServerEnabledUsesActiveProfilePolicyWhenEnabling() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent("config.toml")
        try """
        profile = "work"

        [plugins."docs@openai-curated".mcp_servers.web]
        default_tools_approval_mode = "prompt"

        [profiles.work.plugins."docs@openai-curated".mcp_servers.web]
        enabled = false
        enabled_tools = ["query"]
        """.write(to: config, atomically: true, encoding: .utf8)

        let preview = try XCTUnwrap(ConfigWriter.previewSetCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web",
            enabled: true
        ))
        XCTAssertTrue(preview.before.contains("[profiles.work.plugins"))
        XCTAssertFalse(preview.after.contains("enabled = false"))
        XCTAssertTrue(preview.after.contains(#"enabled_tools = ["query"]"#))

        try ConfigWriter.setCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web",
            enabled: true
        )

        let updated = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(updated.contains("enabled = false"))
        XCTAssertTrue(updated.contains(#"default_tools_approval_mode = "prompt""#))
        XCTAssertTrue(updated.contains(#"enabled_tools = ["query"]"#))
    }

    func testSetCodexPluginMCPServerEnabledUsesTopLevelPolicyInProfileFile() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let config = codexHome.appendingPathComponent("work.config.toml")
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try """
        [plugins."docs@openai-curated".mcp_servers.web]
        enabled = false
        enabled_tools = ["query"]
        """.write(to: config, atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let preview = try XCTUnwrap(ConfigWriter.previewSetCodexPluginMCPServerEnabled(
                configPath: config.path,
                pluginID: "docs@openai-curated",
                serverName: "web",
                enabled: true,
                profileName: "work"
            ))
            XCTAssertTrue(preview.after.contains(#"[plugins."docs@openai-curated".mcp_servers.web]"#))
            XCTAssertFalse(preview.after.contains("[profiles.work.plugins"))
            XCTAssertFalse(preview.after.contains("enabled = false"))
            XCTAssertTrue(preview.after.contains(#"enabled_tools = ["query"]"#))
        }
    }

    func testSetCodexPluginMCPServerEnabledPrefersActiveProfileDisableOverTopLevelDisable() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent("config.toml")
        try """
        profile = "work"

        [plugins."docs@openai-curated".mcp_servers.web]
        enabled = false
        default_tools_approval_mode = "prompt"

        [profiles.work.plugins."docs@openai-curated".mcp_servers.web]
        enabled = false
        enabled_tools = ["query"]
        """.write(to: config, atomically: true, encoding: .utf8)

        let preview = try XCTUnwrap(ConfigWriter.previewSetCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web",
            enabled: true
        ))

        XCTAssertTrue(preview.after.contains(#"[plugins."docs@openai-curated".mcp_servers.web]"#))
        XCTAssertTrue(preview.after.contains("default_tools_approval_mode = \"prompt\""))
        XCTAssertTrue(preview.after.contains("[profiles.work.plugins"))
        XCTAssertTrue(preview.after.contains(#"enabled_tools = ["query"]"#))
        XCTAssertFalse(preview.after.contains("enabled = false"))
        XCTAssertFalse(preview.after.contains("[profiles.work.plugins.\"docs@openai-curated\".mcp_servers.web]\nenabled = false"))

        try ConfigWriter.setCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web",
            enabled: true
        )

        let updated = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(updated.contains("default_tools_approval_mode = \"prompt\""))
        XCTAssertTrue(updated.contains(#"enabled_tools = ["query"]"#))
        XCTAssertFalse(updated.contains("enabled = false"))
        XCTAssertFalse(updated.contains("[profiles.work.plugins.\"docs@openai-curated\".mcp_servers.web]\nenabled = false"))
    }

    func testSetCodexPluginMCPServerEnabledInfersProfilesInGlobalCodexHomeConfig() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        let config = codexHome.appendingPathComponent("config.toml")
        try """
        profile = "work"

        [plugins."docs@openai-curated".mcp_servers.web]
        enabled = false
        default_tools_approval_mode = "prompt"

        [profiles.work.plugins."docs@openai-curated".mcp_servers.web]
        enabled = false
        enabled_tools = ["query"]
        """.write(to: config, atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let preview = try XCTUnwrap(ConfigWriter.previewSetCodexPluginMCPServerEnabled(
                configPath: config.path,
                pluginID: "docs@openai-curated",
                serverName: "web",
                enabled: true
            ))
            XCTAssertTrue(preview.after.contains(#"[plugins."docs@openai-curated".mcp_servers.web]"#))
            XCTAssertTrue(preview.after.contains("default_tools_approval_mode = \"prompt\""))
            XCTAssertTrue(preview.after.contains("[profiles.work.plugins"))
            XCTAssertTrue(preview.after.contains(#"enabled_tools = ["query"]"#))
            XCTAssertFalse(preview.after.contains("enabled = false"))

            try ConfigWriter.setCodexPluginMCPServerEnabled(
                configPath: config.path,
                pluginID: "docs@openai-curated",
                serverName: "web",
                enabled: true
            )
        }

        let updated = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(updated.contains("default_tools_approval_mode = \"prompt\""))
        XCTAssertTrue(updated.contains(#"enabled_tools = ["query"]"#))
        XCTAssertFalse(updated.contains("enabled = false"))
        XCTAssertFalse(updated.contains("[profiles.work.plugins.\"docs@openai-curated\".mcp_servers.web]\nenabled = false"))
    }

    func testSetCodexPluginMCPServerEnabledDoesNotInferProfilesInProjectConfig() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent(".codex/config.toml")
        try FileManager.default.createDirectory(at: config.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        profile = "work"

        [plugins."docs@openai-curated".mcp_servers.web]
        enabled = false
        default_tools_approval_mode = "prompt"

        [profiles.work.plugins."docs@openai-curated".mcp_servers.web]
        enabled = false
        enabled_tools = ["query"]
        """.write(to: config, atomically: true, encoding: .utf8)

        try ConfigWriter.setCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web",
            enabled: true
        )

        let updated = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(updated.contains("default_tools_approval_mode = \"prompt\""))
        XCTAssertTrue(updated.contains(#"enabled_tools = ["query"]"#))
        XCTAssertTrue(updated.contains("[profiles.work.plugins.\"docs@openai-curated\".mcp_servers.web]\nenabled = false"))
        XCTAssertFalse(updated.contains("[plugins.\"docs@openai-curated\".mcp_servers.web]\nenabled = false"))
    }

    func testSetCodexPluginMCPServerEnabledDoesNotInferProfilesInProjectConfigWhenTopLevelHasNoEnabledPolicy() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent(".codex/config.toml")
        try FileManager.default.createDirectory(at: config.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        profile = "work"

        [plugins."docs@openai-curated".mcp_servers.web]
        default_tools_approval_mode = "prompt"

        [profiles.work.plugins."docs@openai-curated".mcp_servers.web]
        enabled = false
        enabled_tools = ["query"]
        """.write(to: config, atomically: true, encoding: .utf8)

        let preview = ConfigWriter.previewSetCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web",
            enabled: true
        )
        XCTAssertNil(preview)

        try ConfigWriter.setCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web",
            enabled: true
        )

        let updated = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(updated.contains("default_tools_approval_mode = \"prompt\""))
        XCTAssertTrue(updated.contains(#"enabled_tools = ["query"]"#))
        XCTAssertTrue(updated.contains("[profiles.work.plugins.\"docs@openai-curated\".mcp_servers.web]\nenabled = false"))
    }

    func testSetCodexPluginMCPServerEnabledEditsSingleQuotedDisablePolicy() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent("config.toml")
        try """
        [plugins.'docs@openai-curated'.mcp_servers.'web.search']
        enabled = false
        default_tools_approval_mode = "prompt"
        """.write(to: config, atomically: true, encoding: .utf8)

        let preview = try XCTUnwrap(ConfigWriter.previewSetCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web.search",
            enabled: true
        ))

        XCTAssertFalse(preview.after.contains("enabled = false"))
        XCTAssertTrue(preview.after.contains(#"default_tools_approval_mode = "prompt""#))
        XCTAssertEqual(preview.after.components(separatedBy: "[plugins.").count - 1, 1)

        try ConfigWriter.setCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web.search",
            enabled: true
        )

        let updated = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(updated.contains("enabled = false"))
        XCTAssertTrue(updated.contains("[plugins.'docs@openai-curated'.mcp_servers.'web.search']"))
        XCTAssertFalse(updated.contains(#"[plugins."docs@openai-curated".mcp_servers."web.search"]"#))
    }

    func testSetCodexPluginMCPServerEnabledUpdatesSingleQuotedPolicy() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent("config.toml")
        try """
        [plugins.'docs@openai-curated'.mcp_servers.'web.search']
        enabled = true
        """.write(to: config, atomically: true, encoding: .utf8)

        try ConfigWriter.setCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web.search",
            enabled: false
        )

        let updated = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(updated.contains("enabled = false"))
        XCTAssertFalse(updated.contains("enabled = true"))
        XCTAssertEqual(updated.components(separatedBy: "[plugins.").count - 1, 1)
        XCTAssertFalse(updated.contains(#"[plugins."docs@openai-curated".mcp_servers."web.search"]"#))
    }

    func testSetCodexPluginMCPServerEnabledEditsSingleQuotedProfilePolicy() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent("config.toml")
        try """
        [profiles.'work.profile'.plugins.'docs@openai-curated'.mcp_servers.'web.search']
        enabled = false
        enabled_tools = ["query"]
        """.write(to: config, atomically: true, encoding: .utf8)

        let preview = try XCTUnwrap(ConfigWriter.previewSetCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web.search",
            enabled: true,
            profileName: "work.profile"
        ))

        XCTAssertFalse(preview.after.contains("enabled = false"))
        XCTAssertTrue(preview.after.contains(#"enabled_tools = ["query"]"#))
        XCTAssertEqual(preview.after.components(separatedBy: "[profiles.").count - 1, 1)

        try ConfigWriter.setCodexPluginMCPServerEnabled(
            configPath: config.path,
            pluginID: "docs@openai-curated",
            serverName: "web.search",
            enabled: true,
            profileName: "work.profile"
        )

        let updated = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(updated.contains("enabled = false"))
        XCTAssertTrue(updated.contains("[profiles.'work.profile'.plugins.'docs@openai-curated'.mcp_servers.'web.search']"))
        XCTAssertFalse(updated.contains(#"[profiles."work.profile".plugins."docs@openai-curated".mcp_servers."web.search"]"#))
    }

    private func makeTempDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubConfigWriterCodexPluginPolicyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }

    private func withCodexHome(_ path: String, run: () throws -> Void) rethrows {
        let previous = getenv("CODEX_HOME").map { String(cString: $0) }
        setenv("CODEX_HOME", path, 1)
        defer {
            if let previous {
                setenv("CODEX_HOME", previous, 1)
            } else {
                unsetenv("CODEX_HOME")
            }
        }
        try run()
    }
}
