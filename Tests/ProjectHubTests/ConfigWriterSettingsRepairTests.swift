import XCTest
@testable import ProjectHub

final class ConfigWriterSettingsRepairTests: XCTestCase {
    func testCodexPreviewWritePreservesEnvHeadersAndEnvVars() throws {
        let root = try makeTempDirectory()
        try withCodexHome(root.path) {
            let preview = try XCTUnwrap(ConfigWriter.previewWrite(
                toolID: "codex",
                scope: .user,
                projectRoot: nil,
                name: "github",
                config: [
                    "url": "https://api.githubcopilot.com/mcp/",
                    "bearer_token_env_var": "GITHUB_TOKEN",
                    "headers": [
                        "X-Static": "yes",
                        "Authorization": "${GITHUB_TOKEN}"
                    ],
                    "env_http_headers": [
                        "Authorization": "GITHUB_TOKEN"
                    ],
                    "startup_timeout_sec": 12.5,
                    "tool_timeout_sec": 70
                ]
            ))

            XCTAssertTrue(preview.after.contains("[mcp_servers.github]"))
            XCTAssertTrue(preview.after.contains("bearer_token_env_var = \"GITHUB_TOKEN\""))
            XCTAssertTrue(preview.after.contains("startup_timeout_sec = 12.5"))
            XCTAssertTrue(preview.after.contains("tool_timeout_sec = 70"))
            XCTAssertTrue(preview.after.contains("http_headers = { X-Static = \"yes\" }"))
            XCTAssertTrue(preview.after.contains("env_http_headers = { Authorization = \"GITHUB_TOKEN\" }"))
        }
    }

    func testCodexPreviewWriteInfersEnvHTTPHeadersFromPlaceholders() throws {
        let root = try makeTempDirectory()
        try withCodexHome(root.path) {
            let preview = try XCTUnwrap(ConfigWriter.previewWrite(
                toolID: "codex",
                scope: .user,
                projectRoot: nil,
                name: "registry-remote",
                config: [
                    "url": "https://analytics.example.com/mcp",
                    "headers": [
                        "Authorization": "Bearer ${API_TOKEN}",
                        "X-API-Key": "${X_API_KEY}",
                        "X-Input": "${input:token}",
                        "X-Static": "yes"
                    ]
                ]
            ))

            XCTAssertTrue(preview.after.contains("[mcp_servers.registry-remote]"))
            XCTAssertTrue(preview.after.contains("bearer_token_env_var = \"API_TOKEN\""))
            XCTAssertTrue(preview.after.contains("http_headers = { X-Input = \"${input:token}\", X-Static = \"yes\" }"))
            XCTAssertTrue(preview.after.contains("env_http_headers = { X-API-Key = \"X_API_KEY\" }"))
            XCTAssertFalse(preview.after.contains("Authorization = \"Bearer ${API_TOKEN}\""))
            XCTAssertFalse(preview.after.contains("X-API-Key = \"${X_API_KEY}\""))
        }
    }

    func testCodexPreviewWritePreservesLocalEnvVars() throws {
        let root = try makeTempDirectory()
        try withCodexHome(root.path) {
            let preview = try XCTUnwrap(ConfigWriter.previewWrite(
                toolID: "codex",
                scope: .user,
                projectRoot: nil,
                name: "context7",
                config: [
                    "command": "npx",
                    "args": ["-y", "@upstash/context7-mcp"],
                    "env_vars": [
                        ["name": "LOCAL_TOKEN", "source": "local"],
                        ["name": "REMOTE_TOKEN", "source": "remote"]
                    ]
                ]
            ))

            XCTAssertTrue(preview.after.contains("[mcp_servers.context7]"))
            XCTAssertTrue(preview.after.contains("env_vars = [\"LOCAL_TOKEN\", { name = \"REMOTE_TOKEN\", source = \"remote\" }]"))
        }
    }

    func testCodexPreviewWriteQuotesDottedMCPServerNames() throws {
        let root = try makeTempDirectory()
        try withCodexHome(root.path) {
            let preview = try XCTUnwrap(ConfigWriter.previewWrite(
                toolID: "codex",
                scope: .user,
                projectRoot: nil,
                name: "github.docs",
                config: [
                    "command": "npx",
                    "args": ["-y", "@modelcontextprotocol/server-github"]
                ]
            ))

            XCTAssertTrue(preview.after.contains(#"[mcp_servers."github.docs"]"#))
            XCTAssertFalse(preview.after.contains("[mcp_servers.github.docs]"))
        }
    }

    func testCodexToggleEditsSingleQuotedDottedMCPServerInPlace() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent("config.toml")
        try """
        [mcp_servers.'github.docs']
        enabled = false
        command = 'npx'

        [mcp_servers.'github.docs'.env]
        GITHUB_TOKEN = "${GITHUB_TOKEN}"
        """.write(to: config, atomically: true, encoding: .utf8)

        try withCodexHome(root.path) {
            let preview = try XCTUnwrap(ConfigWriter.previewSetServerEnabled(
                toolID: "codex",
                scope: .user,
                projectRoot: nil,
                name: "github.docs",
                enabled: true
            ))

            XCTAssertFalse(preview.after.contains("enabled = false"))
            XCTAssertTrue(preview.after.contains("[mcp_servers.'github.docs']"))
            XCTAssertTrue(preview.after.contains("[mcp_servers.'github.docs'.env]"))
            XCTAssertFalse(preview.after.contains("env = {"))
            XCTAssertEqual(preview.after.components(separatedBy: "[mcp_servers.").count - 1, 2)

            try ConfigWriter.setServerEnabled(
                toolID: "codex",
                scope: .user,
                projectRoot: nil,
                name: "github.docs",
                enabled: true
            )
        }

        let updated = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(updated.contains("enabled = false"))
        XCTAssertTrue(updated.contains("[mcp_servers.'github.docs']"))
        XCTAssertTrue(updated.contains("[mcp_servers.'github.docs'.env]"))
        XCTAssertFalse(updated.contains("env = {"))
        XCTAssertFalse(updated.contains("[mcp_servers.github.docs]"))
        XCTAssertEqual(updated.components(separatedBy: "[mcp_servers.").count - 1, 2)
    }

    func testCodexTogglePreservesNestedTOMLShapeAndComments() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent("config.toml")
        try """
        [mcp_servers.'github.docs'] # copied from vendor
        # keep this nearby
        command = 'npx'
        custom_key = 'keep'
        enabled = true # explicit while testing

        [mcp_servers.'github.docs'.env]
        GITHUB_TOKEN = "${GITHUB_TOKEN}"
        """.write(to: config, atomically: true, encoding: .utf8)

        try withCodexHome(root.path) {
            let preview = try XCTUnwrap(ConfigWriter.previewSetServerEnabled(
                toolID: "codex",
                scope: .user,
                projectRoot: nil,
                name: "github.docs",
                enabled: false
            ))

            XCTAssertTrue(preview.after.contains("[mcp_servers.'github.docs'] # copied from vendor"))
            XCTAssertTrue(preview.after.contains("# keep this nearby"))
            XCTAssertTrue(preview.after.contains("custom_key = 'keep'"))
            XCTAssertTrue(preview.after.contains("enabled = false # explicit while testing"))
            XCTAssertTrue(preview.after.contains("[mcp_servers.'github.docs'.env]"))
            XCTAssertFalse(preview.after.contains("env = {"))
            XCTAssertEqual(preview.after.components(separatedBy: "[mcp_servers.").count - 1, 2)

            try ConfigWriter.setServerEnabled(
                toolID: "codex",
                scope: .user,
                projectRoot: nil,
                name: "github.docs",
                enabled: false
            )
        }

        let updated = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(updated.contains("[mcp_servers.'github.docs'] # copied from vendor"))
        XCTAssertTrue(updated.contains("enabled = false # explicit while testing"))
        XCTAssertTrue(updated.contains("[mcp_servers.'github.docs'.env]"))
        XCTAssertFalse(updated.contains("env = {"))
        XCTAssertEqual(updated.components(separatedBy: "[mcp_servers.").count - 1, 2)
    }

    func testCodexTogglePreservesNestedRemoteHeaderTables() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent("config.toml")
        try """
        [mcp_servers.remote]
        url = "https://example.com/mcp"

        [mcp_servers.remote.headers]
        X_STATIC = "yes"

        [mcp_servers.remote.env_http_headers]
        Authorization = "API_TOKEN"
        """.write(to: config, atomically: true, encoding: .utf8)

        try withCodexHome(root.path) {
            let preview = try XCTUnwrap(ConfigWriter.previewSetServerEnabled(
                toolID: "codex",
                scope: .user,
                projectRoot: nil,
                name: "remote",
                enabled: false
            ))

            XCTAssertTrue(preview.after.contains("[mcp_servers.remote]\nurl = \"https://example.com/mcp\"\nenabled = false"))
            XCTAssertTrue(preview.after.contains("[mcp_servers.remote.headers]"))
            XCTAssertTrue(preview.after.contains("[mcp_servers.remote.env_http_headers]"))
            XCTAssertFalse(preview.after.contains("http_headers = {"))
            XCTAssertFalse(preview.after.contains("env_http_headers = {"))

            try ConfigWriter.setServerEnabled(
                toolID: "codex",
                scope: .user,
                projectRoot: nil,
                name: "remote",
                enabled: false
            )
        }

        let updated = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(updated.contains("[mcp_servers.remote.headers]"))
        XCTAssertTrue(updated.contains("[mcp_servers.remote.env_http_headers]"))
        XCTAssertFalse(updated.contains("http_headers = {"))
        XCTAssertFalse(updated.contains("env_http_headers = {"))
    }

    func testCodexRemoveDeletesQuotedDottedMCPServerAndNestedSections() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent("config.toml")
        try """
        [mcp_servers.'github.docs']
        command = "npx"

        [mcp_servers.'github.docs'.env]
        GITHUB_TOKEN = "${GITHUB_TOKEN}"

        [mcp_servers.keep]
        command = "uvx"
        """.write(to: config, atomically: true, encoding: .utf8)

        try withCodexHome(root.path) {
            let preview = try XCTUnwrap(ConfigWriter.previewRemoveServer(
                toolID: "codex",
                scope: .user,
                projectRoot: nil,
                name: "github.docs"
            ))

            XCTAssertFalse(preview.after.contains("github.docs"))
            XCTAssertTrue(preview.after.contains("[mcp_servers.keep]\ncommand = \"uvx\""))

            try ConfigWriter.removeServer(
                toolID: "codex",
                scope: .user,
                projectRoot: nil,
                name: "github.docs"
            )
        }

        let updated = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(updated.contains("github.docs"))
        XCTAssertTrue(updated.contains("[mcp_servers.keep]\ncommand = \"uvx\""))
    }

    func testReadsTopLevelTOMLStringSettingBeforeSections() throws {
        let config = try makeTempConfig("""
        # Codex settings
        sandbox_mode = "sandbox-plus" # stale value

        [profiles.safe]
        sandbox_mode = "read-only"
        """)

        XCTAssertEqual(
            ConfigWriter.topLevelTOMLStringSetting(configPath: config.path, key: "sandbox_mode"),
            "sandbox-plus"
        )
    }

    func testReplacesUnknownSandboxModeWithoutTouchingProfiles() throws {
        let config = try makeTempConfig("""
        model = "gpt-5-codex"
        sandbox_mode = "sandbox-plus" # stale value

        [profiles.safe]
        sandbox_mode = "read-only"
        """)

        let preview = ConfigWriter.previewReplaceTopLevelTOMLStringSetting(
            configPath: config.path,
            key: "sandbox_mode",
            from: "sandbox-plus",
            to: "workspace-write"
        )

        XCTAssertNotNil(preview)
        XCTAssertTrue(preview?.after.contains("sandbox_mode = \"workspace-write\" # stale value") == true)
        XCTAssertTrue(preview?.after.contains("[profiles.safe]\nsandbox_mode = \"read-only\"") == true)

        try ConfigWriter.replaceTopLevelTOMLStringSetting(
            configPath: config.path,
            key: "sandbox_mode",
            from: "sandbox-plus",
            to: "workspace-write"
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(written.contains("sandbox_mode = \"workspace-write\" # stale value"))
        XCTAssertTrue(written.contains("[profiles.safe]\nsandbox_mode = \"read-only\""))
    }

    func testReplacesUnknownApprovalPolicyWithoutTouchingProfiles() throws {
        let config = try makeTempConfig("""
        approval_policy = "auto-edit" # legacy local value

        [profiles.batch]
        approval_policy = "never"
        """)

        XCTAssertEqual(
            ConfigWriter.topLevelTOMLStringSetting(configPath: config.path, key: "approval_policy"),
            "auto-edit"
        )

        let preview = ConfigWriter.previewReplaceTopLevelTOMLStringSetting(
            configPath: config.path,
            key: "approval_policy",
            from: "auto-edit",
            to: "on-request"
        )

        XCTAssertNotNil(preview)
        XCTAssertTrue(preview?.after.contains("approval_policy = \"on-request\" # legacy local value") == true)
        XCTAssertTrue(preview?.after.contains("[profiles.batch]\napproval_policy = \"never\"") == true)

        try ConfigWriter.replaceTopLevelTOMLStringSetting(
            configPath: config.path,
            key: "approval_policy",
            from: "auto-edit",
            to: "on-request"
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(written.contains("approval_policy = \"on-request\" # legacy local value"))
        XCTAssertTrue(written.contains("[profiles.batch]\napproval_policy = \"never\""))
    }

    func testRenamesDeprecatedCodexInstructionFileSetting() throws {
        let config = try makeTempConfig("""
        model = "gpt-5-codex"
        experimental_instructions_file = "legacy.md" # old key

        [profiles.safe]
        experimental_instructions_file = "profile-legacy.md"
        """)

        let preview = ConfigWriter.previewMigrateDeprecatedCodexInstructionFile(configPath: config.path)

        XCTAssertEqual(preview?.value, "legacy.md")
        XCTAssertEqual(preview?.migrated, true)
        XCTAssertTrue(preview?.after.contains("model_instructions_file = \"legacy.md\" # old key") == true)
        XCTAssertTrue(preview?.after.contains("[profiles.safe]\nexperimental_instructions_file = \"profile-legacy.md\"") == true)

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(preview?.before),
            approvedAfter: try XCTUnwrap(preview?.after)
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(written.contains("model_instructions_file = \"legacy.md\" # old key"))
        XCTAssertFalse(written.contains("\nexperimental_instructions_file = \"legacy.md\""))
        XCTAssertTrue(written.contains("[profiles.safe]\nexperimental_instructions_file = \"profile-legacy.md\""))
    }

    func testRemovesDeprecatedCodexInstructionFileWhenReplacementExists() throws {
        let config = try makeTempConfig("""
        model_instructions_file = "current.md"
        experimental_instructions_file = "legacy.md" # old duplicate

        [profiles.safe]
        experimental_instructions_file = "profile-legacy.md"
        """)

        let preview = ConfigWriter.previewMigrateDeprecatedCodexInstructionFile(configPath: config.path)

        XCTAssertEqual(preview?.value, "legacy.md")
        XCTAssertEqual(preview?.migrated, false)
        XCTAssertTrue(preview?.after.contains("model_instructions_file = \"current.md\"") == true)
        XCTAssertFalse(preview?.after.contains("experimental_instructions_file = \"legacy.md\"") == true)
        XCTAssertTrue(preview?.after.contains("[profiles.safe]\nexperimental_instructions_file = \"profile-legacy.md\"") == true)
    }

    func testDeprecatedCodexInstructionFilePreviewRefusesStaleApply() throws {
        let config = try makeTempConfig("""
        experimental_instructions_file = "legacy.md"
        """)
        let preview = try XCTUnwrap(ConfigWriter.previewMigrateDeprecatedCodexInstructionFile(configPath: config.path))
        let changed = """
        experimental_instructions_file = "changed.md"
        """
        try changed.write(to: config, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: preview.before,
            approvedAfter: preview.after
        ))
        XCTAssertEqual(try String(contentsOf: config, encoding: .utf8), changed)
    }

    func testDeprecatedCodexInstructionFileMigrationReturnsNilForInvalidOrEmptyValue() throws {
        let invalid = try makeTempConfig("""
        experimental_instructions_file = ["legacy.md"]
        """)
        let empty = try makeTempConfig("""
        experimental_instructions_file = "   "
        """)

        XCTAssertNil(ConfigWriter.previewMigrateDeprecatedCodexInstructionFile(configPath: invalid.path))
        XCTAssertNil(ConfigWriter.previewMigrateDeprecatedCodexInstructionFile(configPath: empty.path))
    }

    func testRemovesOnlyTopLevelCodexInstructionFileOverride() throws {
        let config = try makeTempConfig("""
        model_instructions_file = "missing.md"

        [profiles.safe]
        model_instructions_file = "profile.md"
        """)

        let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["model_instructions_file"]
        )

        XCTAssertTrue(preview?.removed.contains("model_instructions_file") == true)
        XCTAssertFalse(preview?.after.contains("model_instructions_file = \"missing.md\"") == true)
        XCTAssertTrue(preview?.after.contains("[profiles.safe]\nmodel_instructions_file = \"profile.md\"") == true)

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(preview?.before),
            approvedAfter: try XCTUnwrap(preview?.after)
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("model_instructions_file = \"missing.md\""))
        XCTAssertTrue(written.contains("[profiles.safe]\nmodel_instructions_file = \"profile.md\""))
    }

    func testRemovesOnlyTopLevelDeprecatedCodexInstructionFileOverride() throws {
        let config = try makeTempConfig("""
        experimental_instructions_file = "missing.md"

        [profiles.safe]
        experimental_instructions_file = "profile.md"
        """)

        let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["experimental_instructions_file"]
        )

        XCTAssertTrue(preview?.removed.contains("experimental_instructions_file") == true)
        XCTAssertFalse(preview?.after.contains("experimental_instructions_file = \"missing.md\"") == true)
        XCTAssertTrue(preview?.after.contains("[profiles.safe]\nexperimental_instructions_file = \"profile.md\"") == true)
    }

    func testRemovesInvalidTopLevelCodexEnumWithoutTouchingProfiles() throws {
        let config = try makeTempConfig("""
        model = "gpt-5-codex"
        model_reasoning_effort = "maximum" # invalid local value
        model_verbosity = "chatty"

        [profiles.deep]
        model_reasoning_effort = "xhigh"
        model_verbosity = "high"
        """)

        let preview = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["model_reasoning_effort", "model_verbosity"]
        )

        XCTAssertEqual(preview?.removed, ["model_reasoning_effort", "model_verbosity"])
        XCTAssertFalse(preview?.after.contains("model_reasoning_effort = \"maximum\"") == true)
        XCTAssertFalse(preview?.after.contains("model_verbosity = \"chatty\"") == true)
        XCTAssertTrue(preview?.after.contains("[profiles.deep]\nmodel_reasoning_effort = \"xhigh\"\nmodel_verbosity = \"high\"") == true)

        try ConfigWriter.removeTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["model_reasoning_effort", "model_verbosity"]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("model_reasoning_effort = \"maximum\""))
        XCTAssertFalse(written.contains("model_verbosity = \"chatty\""))
        XCTAssertTrue(written.contains("[profiles.deep]\nmodel_reasoning_effort = \"xhigh\"\nmodel_verbosity = \"high\""))
    }

    func testRemovesProfileCodexEnumWithoutTouchingTopLevelOrSiblingProfiles() throws {
        let config = try makeTempConfig("""
        model_reasoning_effort = "high"

        [profiles.deep]
        model_reasoning_effort = "maximum" # invalid profile value
        model_verbosity = "chatty"

        [profiles.fast]
        model_reasoning_effort = "minimal"
        model_verbosity = "low"
        """)

        let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.deep",
            keys: ["model_reasoning_effort", "model_verbosity"]
        )

        XCTAssertEqual(preview?.removed, ["model_reasoning_effort", "model_verbosity"])
        XCTAssertTrue(preview?.after.contains("model_reasoning_effort = \"high\"") == true)
        XCTAssertFalse(preview?.after.contains("model_reasoning_effort = \"maximum\"") == true)
        XCTAssertFalse(preview?.after.contains("model_verbosity = \"chatty\"") == true)
        XCTAssertTrue(preview?.after.contains("[profiles.fast]\nmodel_reasoning_effort = \"minimal\"\nmodel_verbosity = \"low\"") == true)

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.deep",
            keys: ["model_reasoning_effort", "model_verbosity"]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(written.contains("model_reasoning_effort = \"high\""))
        XCTAssertFalse(written.contains("model_reasoning_effort = \"maximum\""))
        XCTAssertFalse(written.contains("model_verbosity = \"chatty\""))
        XCTAssertTrue(written.contains("[profiles.fast]\nmodel_reasoning_effort = \"minimal\"\nmodel_verbosity = \"low\""))
    }

    func testRemovesProjectTrustWithoutTouchingSiblingProjects() throws {
        let config = try makeTempConfig("""
        [projects."/tmp/repo.with.dot"]
        trust_level = "maybe" # invalid project trust
        model = "gpt-5-codex"

        [projects."/tmp/other"]
        trust_level = "trusted"
        """)

        let preview = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: #"projects."/tmp/repo.with.dot""#,
            keys: ["trust_level"]
        )

        XCTAssertEqual(preview?.removed, ["trust_level"])
        XCTAssertFalse(preview?.after.contains("trust_level = \"maybe\"") == true)
        XCTAssertTrue(preview?.after.contains("[projects.\"/tmp/repo.with.dot\"]\nmodel = \"gpt-5-codex\"") == true)
        XCTAssertTrue(preview?.after.contains("[projects.\"/tmp/other\"]\ntrust_level = \"trusted\"") == true)

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: #"projects."/tmp/repo.with.dot""#,
            keys: ["trust_level"]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("trust_level = \"maybe\""))
        XCTAssertTrue(written.contains("[projects.\"/tmp/repo.with.dot\"]\nmodel = \"gpt-5-codex\""))
        XCTAssertTrue(written.contains("[projects.\"/tmp/other\"]\ntrust_level = \"trusted\""))
    }

    func testPreviewSetCodexProjectTrustUpdatesQuotedRootProjectTable() throws {
        let config = try makeTempConfig("""
        ["projects"."/tmp/repo.with.dot"]
        model = "gpt-5-codex"
        trust_level = "untrusted"
        """)

        let preview = ConfigWriter.previewSetCodexProjectTrust(
            globalConfigPath: config.path,
            projectRoot: "/tmp/repo.with.dot",
            trusted: true
        )

        XCTAssertTrue(preview?.after.contains("[\"projects\".\"/tmp/repo.with.dot\"]\nmodel = \"gpt-5-codex\"\ntrust_level = \"trusted\"") == true)
        XCTAssertFalse(preview?.after.contains("[projects.\"/tmp/repo.with.dot\"]") == true)

        try ConfigWriter.setCodexProjectTrust(
            globalConfigPath: config.path,
            projectRoot: "/tmp/repo.with.dot",
            trusted: true
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(written.contains("[\"projects\".\"/tmp/repo.with.dot\"]\nmodel = \"gpt-5-codex\"\ntrust_level = \"trusted\""))
        XCTAssertFalse(written.contains("[projects.\"/tmp/repo.with.dot\"]"))
    }

    func testRemovesIgnoredCodexProjectParentSections() throws {
        let config = try makeTempConfig("""
        model_provider = "local"
        profiles = "fast"
        otel = "enabled"

        [profiles]
        default = "fast"

        [profiles.fast]
        model = "gpt-5-codex"

        [model_providers]
        default = "local"

        [otel]
        exporter = "otlp"

        [otel.exporter]
        endpoint = "http://localhost:4317"

        [mcp_servers.keep]
        command = "npx"
        """)

        let preview = ConfigWriter.previewRemoveIgnoredCodexProjectSettings(configPath: config.path)

        XCTAssertEqual(
            Set(preview?.removed ?? []),
            ["model_provider", "profiles", "otel", "profiles.fast", "model_providers", "otel.exporter"]
        )
        XCTAssertFalse(preview?.after.contains("model_provider = \"local\"") == true)
        XCTAssertFalse(preview?.after.contains("profiles = \"fast\"") == true)
        XCTAssertFalse(preview?.after.contains("otel = \"enabled\"") == true)
        XCTAssertFalse(preview?.after.contains("[profiles]") == true)
        XCTAssertFalse(preview?.after.contains("[profiles.fast]") == true)
        XCTAssertFalse(preview?.after.contains("[model_providers]") == true)
        XCTAssertFalse(preview?.after.contains("[otel]") == true)
        XCTAssertFalse(preview?.after.contains("[otel.exporter]") == true)
        XCTAssertTrue(preview?.after.contains("[mcp_servers.keep]\ncommand = \"npx\"") == true)
    }

    func testRemovesUnknownGranularApprovalKeysWithoutTouchingKnownKeys() throws {
        let config = try makeTempConfig("""
        approval_policy.granular.unknown_prompt = false
        approval_policy.granular.rules = true

        [approval_policy.granular]
        request_permissions = true
        stale_prompt = false

        [profiles.fast.approval_policy.granular]
        skill_approval = true
        surprise = false
        """)

        let topLevel = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["approval_policy.granular.unknown_prompt"]
        )
        XCTAssertEqual(topLevel?.removed, ["approval_policy.granular.unknown_prompt"])

        try ConfigWriter.removeTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["approval_policy.granular.unknown_prompt"]
        )

        let section = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "approval_policy.granular",
            keys: ["stale_prompt"]
        )
        XCTAssertEqual(section?.removed, ["stale_prompt"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "approval_policy.granular",
            keys: ["stale_prompt"]
        )

        let profile = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast.approval_policy.granular",
            keys: ["surprise"]
        )
        XCTAssertEqual(profile?.removed, ["surprise"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast.approval_policy.granular",
            keys: ["surprise"]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("unknown_prompt"))
        XCTAssertFalse(written.contains("stale_prompt"))
        XCTAssertFalse(written.contains("surprise"))
        XCTAssertTrue(written.contains("approval_policy.granular.rules = true"))
        XCTAssertTrue(written.contains("request_permissions = true"))
        XCTAssertTrue(written.contains("skill_approval = true"))
    }

    func testRemovesUnknownSandboxWorkspaceWriteKeysWithoutTouchingKnownKeys() throws {
        let config = try makeTempConfig("""
        sandbox_workspace_write.extra = true
        sandbox_workspace_write.network_access = false
        profiles.fast.sandbox_workspace_write.unknown = true

        [sandbox_workspace_write]
        exclude_slash_tmp = true
        stale = false

        [profiles.fast]
        sandbox_workspace_write.extra = true

        [profiles.fast.sandbox_workspace_write]
        network_access = true
        stale_profile = false
        """)

        let topLevel = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["sandbox_workspace_write.extra"]
        )
        XCTAssertEqual(topLevel?.removed, ["sandbox_workspace_write.extra"])

        try ConfigWriter.removeTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["sandbox_workspace_write.extra"]
        )

        let section = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "sandbox_workspace_write",
            keys: ["stale"]
        )
        XCTAssertEqual(section?.removed, ["stale"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "sandbox_workspace_write",
            keys: ["stale"]
        )

        let topLevelProfile = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["profiles.fast.sandbox_workspace_write.unknown"]
        )
        XCTAssertEqual(topLevelProfile?.removed, ["profiles.fast.sandbox_workspace_write.unknown"])

        try ConfigWriter.removeTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["profiles.fast.sandbox_workspace_write.unknown"]
        )

        let profileParent = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast",
            keys: ["sandbox_workspace_write.extra"]
        )
        XCTAssertEqual(profileParent?.removed, ["sandbox_workspace_write.extra"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast",
            keys: ["sandbox_workspace_write.extra"]
        )

        let profileSection = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast.sandbox_workspace_write",
            keys: ["stale_profile"]
        )
        XCTAssertEqual(profileSection?.removed, ["stale_profile"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast.sandbox_workspace_write",
            keys: ["stale_profile"]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("sandbox_workspace_write.extra"))
        XCTAssertFalse(written.contains("stale = false"))
        XCTAssertFalse(written.contains("sandbox_workspace_write.unknown"))
        XCTAssertFalse(written.contains("stale_profile"))
        XCTAssertTrue(written.contains("sandbox_workspace_write.network_access = false"))
        XCTAssertTrue(written.contains("exclude_slash_tmp = true"))
        XCTAssertTrue(written.contains("[profiles.fast.sandbox_workspace_write]\nnetwork_access = true"))
    }

    func testRemovesInlineSandboxWorkspaceWriteKeysWithoutTouchingKnownPairs() throws {
        let config = try makeTempConfig("""
        sandbox_workspace_write = { writable_roots = ["/tmp/a", "/tmp/b"], stale = true, network_access = false } # local note

        [profiles.fast]
        model = "gpt-5-codex"
        sandbox_workspace_write = { network_access = true, "stale-key" = false }

        [profiles.slow]
        sandbox_workspace_write = { network_access = true, stale = true }
        """)

        let topLevel = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "sandbox_workspace_write",
            keys: ["stale"]
        )
        XCTAssertEqual(topLevel?.removed, ["stale"])
        XCTAssertTrue(topLevel?.after.contains(#"sandbox_workspace_write = { writable_roots = ["/tmp/a", "/tmp/b"], network_access = false } # local note"#) == true)

        try ConfigWriter.removeInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "sandbox_workspace_write",
            keys: ["stale"]
        )

        let profile = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: "profiles.fast",
            assignmentKey: "sandbox_workspace_write",
            keys: ["stale-key"]
        )
        XCTAssertEqual(profile?.removed, ["stale-key"])
        XCTAssertTrue(profile?.after.contains("[profiles.fast]\nmodel = \"gpt-5-codex\"\nsandbox_workspace_write = { network_access = true }") == true)
        XCTAssertTrue(profile?.after.contains("[profiles.slow]\nsandbox_workspace_write = { network_access = true, stale = true }") == true)

        try ConfigWriter.removeInlineTOMLTableKeys(
            configPath: config.path,
            section: "profiles.fast",
            assignmentKey: "sandbox_workspace_write",
            keys: ["stale-key"]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("stale-key"))
        XCTAssertTrue(written.contains(#"sandbox_workspace_write = { writable_roots = ["/tmp/a", "/tmp/b"], network_access = false } # local note"#))
        XCTAssertTrue(written.contains("[profiles.fast]\nmodel = \"gpt-5-codex\"\nsandbox_workspace_write = { network_access = true }"))
        XCTAssertTrue(written.contains("[profiles.slow]\nsandbox_workspace_write = { network_access = true, stale = true }"))
    }

    func testInlineSandboxWorkspaceWriteRemovalSkipsAmbiguousOrEmptyResults() throws {
        let config = try makeTempConfig("""
        sandbox_workspace_write = { stale = true }

        [profiles.fast]
        sandbox_workspace_write = {
          network_access = true,
          stale = true
        }
        """)

        let emptyResult = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "sandbox_workspace_write",
            keys: ["stale"]
        )
        XCTAssertNil(emptyResult)

        let multiline = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: "profiles.fast",
            assignmentKey: "sandbox_workspace_write",
            keys: ["stale"]
        )
        XCTAssertNil(multiline)
    }

    func testRemovesInlineWebSearchKeysWithoutTouchingKnownPairs() throws {
        let config = try makeTempConfig("""
        tools.web_search = { context_size = "high", extra = true, allowed_domains = ["example.com"] } # web note

        [profiles.fast]
        tools.web_search = { context_size = "low", surprise = false, allowed_domains = ["docs.example.com"] }

        [profiles.fast.tools]
        web_search = { context_size = "medium", stale = true }

        [profiles.slow]
        tools.web_search = { context_size = "medium", surprise = true }
        """)

        let topLevel = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "tools.web_search",
            keys: ["extra"]
        )
        XCTAssertEqual(topLevel?.removed, ["extra"])
        XCTAssertTrue(topLevel?.after.contains(#"tools.web_search = { context_size = "high", allowed_domains = ["example.com"] } # web note"#) == true)

        try ConfigWriter.removeInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "tools.web_search",
            keys: ["extra"]
        )

        let profile = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: "profiles.fast",
            assignmentKey: "tools.web_search",
            keys: ["surprise"]
        )
        XCTAssertEqual(profile?.removed, ["surprise"])
        XCTAssertTrue(profile?.after.contains("[profiles.fast]\ntools.web_search = { context_size = \"low\", allowed_domains = [\"docs.example.com\"] }") == true)
        XCTAssertTrue(profile?.after.contains("[profiles.slow]\ntools.web_search = { context_size = \"medium\", surprise = true }") == true)

        try ConfigWriter.removeInlineTOMLTableKeys(
            configPath: config.path,
            section: "profiles.fast",
            assignmentKey: "tools.web_search",
            keys: ["surprise"]
        )

        let profileTools = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: "profiles.fast.tools",
            assignmentKey: "web_search",
            keys: ["stale"]
        )
        XCTAssertEqual(profileTools?.removed, ["stale"])

        try ConfigWriter.removeInlineTOMLTableKeys(
            configPath: config.path,
            section: "profiles.fast.tools",
            assignmentKey: "web_search",
            keys: ["stale"]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("extra = true"))
        XCTAssertFalse(written.contains("surprise = false"))
        XCTAssertFalse(written.contains("stale = true"))
        XCTAssertTrue(written.contains(#"tools.web_search = { context_size = "high", allowed_domains = ["example.com"] } # web note"#))
        XCTAssertTrue(written.contains("[profiles.fast]\ntools.web_search = { context_size = \"low\", allowed_domains = [\"docs.example.com\"] }"))
        XCTAssertTrue(written.contains("[profiles.fast.tools]\nweb_search = { context_size = \"medium\" }"))
        XCTAssertTrue(written.contains("[profiles.slow]\ntools.web_search = { context_size = \"medium\", surprise = true }"))
    }

    func testRemovesInlineNetworkProxyKeysWithoutTouchingKnownPairs() throws {
        let config = try makeTempConfig("""
        features.network_proxy = { enabled = true, stale = false, mode = "limited", domains = { "*.example.com" = "allow" } } # proxy note

        [profiles.fast]
        features.network_proxy = { enabled = true, legacy = true, mode = "full" }

        [profiles.fast.features]
        network_proxy = { proxy_url = "http://127.0.0.1:1234", old = true }

        [profiles.slow]
        features.network_proxy = { enabled = true, legacy = true }
        """)

        let topLevel = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "features.network_proxy",
            keys: ["stale"]
        )
        XCTAssertEqual(topLevel?.removed, ["stale"])
        XCTAssertTrue(topLevel?.after.contains(#"features.network_proxy = { enabled = true, mode = "limited", domains = { "*.example.com" = "allow" } } # proxy note"#) == true)

        try ConfigWriter.removeInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "features.network_proxy",
            keys: ["stale"]
        )

        let profile = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: "profiles.fast",
            assignmentKey: "features.network_proxy",
            keys: ["legacy"]
        )
        XCTAssertEqual(profile?.removed, ["legacy"])
        XCTAssertTrue(profile?.after.contains("[profiles.fast]\nfeatures.network_proxy = { enabled = true, mode = \"full\" }") == true)

        try ConfigWriter.removeInlineTOMLTableKeys(
            configPath: config.path,
            section: "profiles.fast",
            assignmentKey: "features.network_proxy",
            keys: ["legacy"]
        )

        let profileFeatures = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: "profiles.fast.features",
            assignmentKey: "network_proxy",
            keys: ["old"]
        )
        XCTAssertEqual(profileFeatures?.removed, ["old"])

        try ConfigWriter.removeInlineTOMLTableKeys(
            configPath: config.path,
            section: "profiles.fast.features",
            assignmentKey: "network_proxy",
            keys: ["old"]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("stale = false"))
        XCTAssertFalse(written.contains("legacy = true, mode = \"full\""))
        XCTAssertFalse(written.contains("old = true"))
        XCTAssertTrue(written.contains(#"features.network_proxy = { enabled = true, mode = "limited", domains = { "*.example.com" = "allow" } } # proxy note"#))
        XCTAssertTrue(written.contains("[profiles.fast]\nfeatures.network_proxy = { enabled = true, mode = \"full\" }"))
        XCTAssertTrue(written.contains("[profiles.fast.features]\nnetwork_proxy = { proxy_url = \"http://127.0.0.1:1234\" }"))
        XCTAssertTrue(written.contains("[profiles.slow]\nfeatures.network_proxy = { enabled = true, legacy = true }"))
    }

    func testInlineWebAndNetworkCleanupSkipsAmbiguousOrEmptyResults() throws {
        let config = try makeTempConfig("""
        tools.web_search = { extra = true }
        features.network_proxy = { stale = false }

        [profiles.fast]
        tools.web_search = {
          context_size = "high",
          extra = true
        }
        features.network_proxy = {
          enabled = true,
          stale = true
        }
        """)

        XCTAssertNil(ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "tools.web_search",
            keys: ["extra"]
        ))
        XCTAssertNil(ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "features.network_proxy",
            keys: ["stale"]
        ))
        XCTAssertNil(ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: "profiles.fast",
            assignmentKey: "tools.web_search",
            keys: ["extra"]
        ))
        XCTAssertNil(ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: "profiles.fast",
            assignmentKey: "features.network_proxy",
            keys: ["stale"]
        ))
    }

    func testRemovesMalformedDirectTopLevelAndExactSectionWebNetworkAssignmentsWithoutPrefixMatching() throws {
        let config = try makeTempConfig("""
        tools.web_search = "yes" # malformed scalar
        tools.web_search.context_size = "low"
        features.network_proxy = "enabled" # malformed scalar
        features.network_proxy.enabled = true

        [tools]
        web_search = "yes"
        web_search.context_size = "medium"

        [features]
        network_proxy = "enabled"
        network_proxy.enabled = true
        """)

        let topLevel = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["tools.web_search", "features.network_proxy"]
        )
        XCTAssertEqual(Set(topLevel?.removed ?? []), Set(["tools.web_search", "features.network_proxy"]))
        XCTAssertTrue(topLevel?.after.contains("tools.web_search.context_size = \"low\"") == true)
        XCTAssertTrue(topLevel?.after.contains("features.network_proxy.enabled = true") == true)

        try ConfigWriter.removeTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["tools.web_search", "features.network_proxy"]
        )

        let toolsSection = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "tools",
            keys: ["web_search"]
        )
        XCTAssertEqual(toolsSection?.removed, ["web_search"])
        XCTAssertTrue(toolsSection?.after.contains("[tools]\nweb_search.context_size = \"medium\"") == true)

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "tools",
            keys: ["web_search"]
        )

        let featuresSection = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "features",
            keys: ["network_proxy"]
        )
        XCTAssertEqual(featuresSection?.removed, ["network_proxy"])
        XCTAssertTrue(featuresSection?.after.contains("[features]\nnetwork_proxy.enabled = true") == true)

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "features",
            keys: ["network_proxy"]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("tools.web_search = \"yes\""))
        XCTAssertFalse(written.contains("features.network_proxy = \"enabled\""))
        XCTAssertFalse(written.contains("\nweb_search = \"yes\""))
        XCTAssertFalse(written.contains("\nnetwork_proxy = \"enabled\""))
        XCTAssertTrue(written.contains("tools.web_search.context_size = \"low\""))
        XCTAssertTrue(written.contains("features.network_proxy.enabled = true"))
        XCTAssertTrue(written.contains("[tools]\nweb_search.context_size = \"medium\""))
        XCTAssertTrue(written.contains("[features]\nnetwork_proxy.enabled = true"))
    }

    func testRemovesMalformedDirectProfileWebNetworkAssignmentsWithoutTouchingSiblings() throws {
        let config = try makeTempConfig("""
        [profiles.fast]
        tools.web_search = "yes"
        tools.web_search.context_size = "high"
        features.network_proxy = "enabled"
        features.network_proxy.enabled = true

        [profiles.fast.tools]
        web_search = "yes"
        web_search.context_size = "low"

        [profiles.fast.features]
        network_proxy = "enabled"
        network_proxy.enabled = true

        [profiles.slow]
        tools.web_search = "yes"
        features.network_proxy = "enabled"
        """)

        let profile = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast",
            keys: ["tools.web_search", "features.network_proxy"]
        )
        XCTAssertEqual(Set(profile?.removed ?? []), Set(["tools.web_search", "features.network_proxy"]))
        XCTAssertTrue(profile?.after.contains("[profiles.fast]\ntools.web_search.context_size = \"high\"\nfeatures.network_proxy.enabled = true") == true)
        XCTAssertTrue(profile?.after.contains("[profiles.slow]\ntools.web_search = \"yes\"\nfeatures.network_proxy = \"enabled\"") == true)

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast",
            keys: ["tools.web_search", "features.network_proxy"]
        )

        let tools = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast.tools",
            keys: ["web_search"]
        )
        XCTAssertEqual(tools?.removed, ["web_search"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast.tools",
            keys: ["web_search"]
        )

        let features = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast.features",
            keys: ["network_proxy"]
        )
        XCTAssertEqual(features?.removed, ["network_proxy"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast.features",
            keys: ["network_proxy"]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("[profiles.fast]\ntools.web_search = \"yes\""))
        XCTAssertFalse(written.contains("[profiles.fast.tools]\nweb_search = \"yes\""))
        XCTAssertFalse(written.contains("[profiles.fast.features]\nnetwork_proxy = \"enabled\""))
        XCTAssertTrue(written.contains("[profiles.fast]\ntools.web_search.context_size = \"high\"\nfeatures.network_proxy.enabled = true"))
        XCTAssertTrue(written.contains("[profiles.fast.tools]\nweb_search.context_size = \"low\""))
        XCTAssertTrue(written.contains("[profiles.fast.features]\nnetwork_proxy.enabled = true"))
        XCTAssertTrue(written.contains("[profiles.slow]\ntools.web_search = \"yes\"\nfeatures.network_proxy = \"enabled\""))
    }

    func testRemovesUnknownWebSearchKeysWithoutTouchingKnownKeys() throws {
        let config = try makeTempConfig("""
        tools.web_search.extra = true
        tools.web_search.context_size = "low"
        tools.web_search.location.planet = "Mars"
        profiles.fast.tools.web_search.unknown = true
        profiles.fast.tools.web_search.location.planet = "Mars"

        [tools.web_search]
        allowed_domains = ["example.com"]
        stale = true
        location.region = "CA"

        [tools.web_search.location]
        country = "US"
        moon = "Europa"

        [profiles.fast.tools.web_search]
        context_size = "high"
        surprise = false
        location.city = "San Francisco"

        [profiles.fast.tools.web_search.location]
        timezone = "America/Los_Angeles"
        galaxy = "Milky Way"
        """)

        let topLevel = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: config.path,
            keys: [
                "tools.web_search.extra",
                "tools.web_search.location.planet",
                "profiles.fast.tools.web_search.unknown",
                "profiles.fast.tools.web_search.location.planet"
            ]
        )
        XCTAssertEqual(
            Set(topLevel?.removed ?? []),
            Set([
                "tools.web_search.extra",
                "tools.web_search.location.planet",
                "profiles.fast.tools.web_search.unknown",
                "profiles.fast.tools.web_search.location.planet"
            ])
        )

        try ConfigWriter.removeTopLevelTOMLKeys(
            configPath: config.path,
            keys: [
                "tools.web_search.extra",
                "tools.web_search.location.planet",
                "profiles.fast.tools.web_search.unknown",
                "profiles.fast.tools.web_search.location.planet"
            ]
        )

        let webSection = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "tools.web_search",
            keys: ["stale", "location.region"]
        )
        XCTAssertEqual(Set(webSection?.removed ?? []), Set(["stale", "location.region"]))

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "tools.web_search",
            keys: ["stale", "location.region"]
        )

        let locationSection = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "tools.web_search.location",
            keys: ["moon"]
        )
        XCTAssertEqual(locationSection?.removed, ["moon"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "tools.web_search.location",
            keys: ["moon"]
        )

        let profileWebSection = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast.tools.web_search",
            keys: ["surprise", "location.city"]
        )
        XCTAssertEqual(Set(profileWebSection?.removed ?? []), Set(["surprise", "location.city"]))

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast.tools.web_search",
            keys: ["surprise", "location.city"]
        )

        let profileLocationSection = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast.tools.web_search.location",
            keys: ["galaxy"]
        )
        XCTAssertEqual(profileLocationSection?.removed, ["galaxy"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast.tools.web_search.location",
            keys: ["galaxy"]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("extra = true"))
        XCTAssertFalse(written.contains("planet"))
        XCTAssertFalse(written.contains("stale = true"))
        XCTAssertFalse(written.contains("location.region"))
        XCTAssertFalse(written.contains("moon"))
        XCTAssertFalse(written.contains("unknown = true"))
        XCTAssertFalse(written.contains("surprise"))
        XCTAssertFalse(written.contains("location.city"))
        XCTAssertFalse(written.contains("galaxy"))
        XCTAssertTrue(written.contains("tools.web_search.context_size = \"low\""))
        XCTAssertTrue(written.contains("allowed_domains = [\"example.com\"]"))
        XCTAssertTrue(written.contains("[tools.web_search.location]\ncountry = \"US\""))
        XCTAssertTrue(written.contains("[profiles.fast.tools.web_search]\ncontext_size = \"high\""))
        XCTAssertTrue(written.contains("[profiles.fast.tools.web_search.location]\ntimezone = \"America/Los_Angeles\""))
    }

    func testRemovesUnknownNetworkProxyKeysWithoutTouchingKnownKeys() throws {
        let config = try makeTempConfig("""
        features.network_proxy.enabled = true
        features.network_proxy.stale = false
        profiles.fast.features.network_proxy.legacy = true

        [features.network_proxy]
        mode = "limited"
        mystery = true

        [features.network_proxy.domains]
        "*.example.com" = "allow"

        [profiles.fast.features]
        network_proxy.old = true

        [profiles.fast.features.network_proxy]
        proxy_url = "http://127.0.0.1:1234"
        surprise = true

        [profiles.fast.features.network_proxy.domains]
        "*.example.com" = "allow"
        """)

        let topLevel = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: config.path,
            keys: [
                "features.network_proxy.stale",
                "profiles.fast.features.network_proxy.legacy"
            ]
        )
        XCTAssertEqual(
            Set(topLevel?.removed ?? []),
            Set([
                "features.network_proxy.stale",
                "profiles.fast.features.network_proxy.legacy"
            ])
        )

        try ConfigWriter.removeTopLevelTOMLKeys(
            configPath: config.path,
            keys: [
                "features.network_proxy.stale",
                "profiles.fast.features.network_proxy.legacy"
            ]
        )

        let section = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "features.network_proxy",
            keys: ["mystery"]
        )
        XCTAssertEqual(section?.removed, ["mystery"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "features.network_proxy",
            keys: ["mystery"]
        )

        let profileParent = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast.features",
            keys: ["network_proxy.old"]
        )
        XCTAssertEqual(profileParent?.removed, ["network_proxy.old"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast.features",
            keys: ["network_proxy.old"]
        )

        let profileSection = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast.features.network_proxy",
            keys: ["surprise"]
        )
        XCTAssertEqual(profileSection?.removed, ["surprise"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.fast.features.network_proxy",
            keys: ["surprise"]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("stale = false"))
        XCTAssertFalse(written.contains("legacy = true"))
        XCTAssertFalse(written.contains("mystery = true"))
        XCTAssertFalse(written.contains("network_proxy.old"))
        XCTAssertFalse(written.contains("surprise = true"))
        XCTAssertTrue(written.contains("features.network_proxy.enabled = true"))
        XCTAssertTrue(written.contains("[features.network_proxy]\nmode = \"limited\""))
        XCTAssertTrue(written.contains("[features.network_proxy.domains]\n\"*.example.com\" = \"allow\""))
        XCTAssertTrue(written.contains("[profiles.fast.features.network_proxy]\nproxy_url = \"http://127.0.0.1:1234\""))
        XCTAssertTrue(written.contains("[profiles.fast.features.network_proxy.domains]\n\"*.example.com\" = \"allow\""))
    }

    func testRemovesInvalidNetworkProxyRuleMapEntriesWithoutTouchingValidRules() throws {
        let config = try makeTempConfig("""
        features.network_proxy = { domains = { "nested.bad.example.com" = "maybe", "nested.ok.example.com" = "allow" }, unix_sockets = { "/tmp/nested-bad.sock" = "deny", "/tmp/nested-ok.sock" = "none" } }

        [features.network_proxy.domains]
        "section.bad.example.com" = "maybe"
        "section.ok.example.com" = "allow"

        [features.network_proxy.unix_sockets]
        "/tmp/section-bad.sock" = "deny"
        "/tmp/section-ok.sock" = "none"

        [features.network_proxy]
        domains = { "inline.bad.example.com" = "maybe", "inline.ok.example.com" = "allow" }
        unix_sockets = { "/tmp/inline-bad.sock" = "deny", "/tmp/inline-ok.sock" = "none" }
        domains."dotted.bad.example.com" = "maybe"
        """)

        let sectionDomain = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "features.network_proxy.domains",
            keys: ["section.bad.example.com"]
        )
        XCTAssertEqual(sectionDomain?.removed, ["section.bad.example.com"])

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(sectionDomain?.before),
            approvedAfter: try XCTUnwrap(sectionDomain?.after)
        )

        let sectionSocket = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "features.network_proxy.unix_sockets",
            keys: ["/tmp/section-bad.sock"]
        )
        XCTAssertEqual(sectionSocket?.removed, ["/tmp/section-bad.sock"])

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(sectionSocket?.before),
            approvedAfter: try XCTUnwrap(sectionSocket?.after)
        )

        let inlineDomain = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: "features.network_proxy",
            assignmentKey: "domains",
            keys: ["inline.bad.example.com"]
        )
        XCTAssertEqual(inlineDomain?.removed, ["inline.bad.example.com"])

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(inlineDomain?.before),
            approvedAfter: try XCTUnwrap(inlineDomain?.after)
        )

        let inlineSocket = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: "features.network_proxy",
            assignmentKey: "unix_sockets",
            keys: ["/tmp/inline-bad.sock"]
        )
        XCTAssertEqual(inlineSocket?.removed, ["/tmp/inline-bad.sock"])

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(inlineSocket?.before),
            approvedAfter: try XCTUnwrap(inlineSocket?.after)
        )

        let parentDotted = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "features.network_proxy",
            keys: ["domains.dotted.bad.example.com", #"domains."dotted.bad.example.com""#]
        )
        XCTAssertEqual(parentDotted?.removed, [#"domains."dotted.bad.example.com""#])

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(parentDotted?.before),
            approvedAfter: try XCTUnwrap(parentDotted?.after)
        )

        let nestedDomain = ConfigWriter.previewRemoveNestedInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "features.network_proxy",
            tableKey: "domains",
            keys: ["nested.bad.example.com"]
        )
        XCTAssertEqual(nestedDomain?.removed, ["nested.bad.example.com"])

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(nestedDomain?.before),
            approvedAfter: try XCTUnwrap(nestedDomain?.after)
        )

        let nestedSocket = ConfigWriter.previewRemoveNestedInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "features.network_proxy",
            tableKey: "unix_sockets",
            keys: ["/tmp/nested-bad.sock"]
        )
        XCTAssertEqual(nestedSocket?.removed, ["/tmp/nested-bad.sock"])

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(nestedSocket?.before),
            approvedAfter: try XCTUnwrap(nestedSocket?.after)
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("bad.example.com"))
        XCTAssertFalse(written.contains("bad.sock"))
        XCTAssertTrue(written.contains("\"nested.ok.example.com\" = \"allow\""))
        XCTAssertTrue(written.contains("\"section.ok.example.com\" = \"allow\""))
        XCTAssertTrue(written.contains("\"inline.ok.example.com\" = \"allow\""))
        XCTAssertTrue(written.contains("\"/tmp/nested-ok.sock\" = \"none\""))
        XCTAssertTrue(written.contains("\"/tmp/section-ok.sock\" = \"none\""))
        XCTAssertTrue(written.contains("\"/tmp/inline-ok.sock\" = \"none\""))
    }

    func testInvalidNetworkProxyRuleMapPreviewRefusesStaleApply() throws {
        let config = try makeTempConfig("""
        features.network_proxy = { domains = { "bad.example.com" = "maybe", "ok.example.com" = "allow" } }
        """)

        let preview = try XCTUnwrap(ConfigWriter.previewRemoveNestedInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "features.network_proxy",
            tableKey: "domains",
            keys: ["bad.example.com"]
        ))

        try """
        features.network_proxy = { domains = { "bad.example.com" = "maybe", "ok.example.com" = "allow" }, enabled = true }
        """.write(to: config, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: preview.before,
            approvedAfter: preview.after
        ))
    }

    func testRemovesUnknownPermissionNetworkKeysWithoutTouchingKnownKeys() throws {
        let config = try makeTempConfig("""
        permissions.local.network.enabled = true
        permissions.local.network.stale = false

        [permissions.parent]
        network.old = true

        [permissions.dev.network]
        mode = "limited"
        unknown = true

        [permissions.dev.network.domains]
        "*.example.com" = "allow"
        """)

        let topLevel = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["permissions.local.network.stale"]
        )
        XCTAssertEqual(topLevel?.removed, ["permissions.local.network.stale"])

        try ConfigWriter.removeTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["permissions.local.network.stale"]
        )

        let parent = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.parent",
            keys: ["network.old"]
        )
        XCTAssertEqual(parent?.removed, ["network.old"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.parent",
            keys: ["network.old"]
        )

        let section = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.dev.network",
            keys: ["unknown"]
        )
        XCTAssertEqual(section?.removed, ["unknown"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.dev.network",
            keys: ["unknown"]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("stale = false"))
        XCTAssertFalse(written.contains("network.old"))
        XCTAssertFalse(written.contains("unknown = true"))
        XCTAssertTrue(written.contains("permissions.local.network.enabled = true"))
        XCTAssertTrue(written.contains("[permissions.dev.network]\nmode = \"limited\""))
        XCTAssertTrue(written.contains("[permissions.dev.network.domains]\n\"*.example.com\" = \"allow\""))
    }

    func testRemovesInvalidPermissionNetworkRuleMapEntriesWithoutTouchingValidRules() throws {
        let config = try makeTempConfig("""
        permissions.inline.network = { domains = { "nested.bad.example.com" = "maybe", "nested.ok.example.com" = "allow" }, unix_sockets = { "/tmp/nested-bad.sock" = "deny", "/tmp/nested-ok.sock" = "none" } }

        [permissions.section.network.domains]
        "section.bad.example.com" = "maybe"
        "section.ok.example.com" = "allow"

        [permissions.section.network.unix_sockets]
        "/tmp/section-bad.sock" = "deny"
        "/tmp/section-ok.sock" = "none"

        [permissions.parent.network]
        domains = { "inline.bad.example.com" = "maybe", "inline.ok.example.com" = "allow" }
        unix_sockets = { "/tmp/inline-bad.sock" = "deny", "/tmp/inline-ok.sock" = "none" }
        domains."dotted.bad.example.com" = "maybe"

        [permissions.nested]
        network = { domains = { "parent.bad.example.com" = "maybe", "parent.ok.example.com" = "allow" }, unix_sockets = { "/tmp/parent-bad.sock" = "deny", "/tmp/parent-ok.sock" = "none" } }
        """)

        let sectionDomain = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.section.network.domains",
            keys: ["section.bad.example.com"]
        )
        XCTAssertEqual(sectionDomain?.removed, ["section.bad.example.com"])

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(sectionDomain?.before),
            approvedAfter: try XCTUnwrap(sectionDomain?.after)
        )

        let sectionSocket = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.section.network.unix_sockets",
            keys: ["/tmp/section-bad.sock"]
        )
        XCTAssertEqual(sectionSocket?.removed, ["/tmp/section-bad.sock"])

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(sectionSocket?.before),
            approvedAfter: try XCTUnwrap(sectionSocket?.after)
        )

        let inlineDomain = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: "permissions.parent.network",
            assignmentKey: "domains",
            keys: ["inline.bad.example.com"]
        )
        XCTAssertEqual(inlineDomain?.removed, ["inline.bad.example.com"])

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(inlineDomain?.before),
            approvedAfter: try XCTUnwrap(inlineDomain?.after)
        )

        let inlineSocket = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: "permissions.parent.network",
            assignmentKey: "unix_sockets",
            keys: ["/tmp/inline-bad.sock"]
        )
        XCTAssertEqual(inlineSocket?.removed, ["/tmp/inline-bad.sock"])

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(inlineSocket?.before),
            approvedAfter: try XCTUnwrap(inlineSocket?.after)
        )

        let parentDotted = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.parent.network",
            keys: ["domains.dotted.bad.example.com", #"domains."dotted.bad.example.com""#]
        )
        XCTAssertEqual(parentDotted?.removed, [#"domains."dotted.bad.example.com""#])

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(parentDotted?.before),
            approvedAfter: try XCTUnwrap(parentDotted?.after)
        )

        let nestedTopLevel = ConfigWriter.previewRemoveNestedInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "permissions.inline.network",
            tableKey: "domains",
            keys: ["nested.bad.example.com"]
        )
        XCTAssertEqual(nestedTopLevel?.removed, ["nested.bad.example.com"])

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(nestedTopLevel?.before),
            approvedAfter: try XCTUnwrap(nestedTopLevel?.after)
        )

        let nestedTopLevelSocket = ConfigWriter.previewRemoveNestedInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "permissions.inline.network",
            tableKey: "unix_sockets",
            keys: ["/tmp/nested-bad.sock"]
        )
        XCTAssertEqual(nestedTopLevelSocket?.removed, ["/tmp/nested-bad.sock"])

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(nestedTopLevelSocket?.before),
            approvedAfter: try XCTUnwrap(nestedTopLevelSocket?.after)
        )

        let nestedSectionDomain = ConfigWriter.previewRemoveNestedInlineTOMLTableKeys(
            configPath: config.path,
            section: "permissions.nested",
            assignmentKey: "network",
            tableKey: "domains",
            keys: ["parent.bad.example.com"]
        )
        XCTAssertEqual(nestedSectionDomain?.removed, ["parent.bad.example.com"])

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(nestedSectionDomain?.before),
            approvedAfter: try XCTUnwrap(nestedSectionDomain?.after)
        )

        let nestedSectionSocket = ConfigWriter.previewRemoveNestedInlineTOMLTableKeys(
            configPath: config.path,
            section: "permissions.nested",
            assignmentKey: "network",
            tableKey: "unix_sockets",
            keys: ["/tmp/parent-bad.sock"]
        )
        XCTAssertEqual(nestedSectionSocket?.removed, ["/tmp/parent-bad.sock"])

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(nestedSectionSocket?.before),
            approvedAfter: try XCTUnwrap(nestedSectionSocket?.after)
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("bad.example.com"))
        XCTAssertFalse(written.contains("bad.sock"))
        XCTAssertTrue(written.contains("\"nested.ok.example.com\" = \"allow\""))
        XCTAssertTrue(written.contains("\"section.ok.example.com\" = \"allow\""))
        XCTAssertTrue(written.contains("\"inline.ok.example.com\" = \"allow\""))
        XCTAssertTrue(written.contains("\"parent.ok.example.com\" = \"allow\""))
        XCTAssertTrue(written.contains("\"/tmp/nested-ok.sock\" = \"none\""))
        XCTAssertTrue(written.contains("\"/tmp/section-ok.sock\" = \"none\""))
        XCTAssertTrue(written.contains("\"/tmp/inline-ok.sock\" = \"none\""))
        XCTAssertTrue(written.contains("\"/tmp/parent-ok.sock\" = \"none\""))
    }

    func testRemovesMalformedPermissionNetworkAssignmentsWithoutPrefixMatching() throws {
        let config = try makeTempConfig("""
        permissions.local.network = "yes"
        permissions.local.network.enabled = true
        permissions.bad.network.enabled = "yes"
        permissions.bad.network.mode = "open"

        [permissions.parent]
        network = "enabled"
        network.enabled = true

        [permissions.parentDotted]
        network.proxy_url = 123
        network.socks_url = 456
        network.allow_local_binding = true

        [permissions.dev.network]
        enabled = "yes"
        mode = "open"
        proxy_url = 123
        domains = "example.com"
        allow_upstream_proxy = true

        [permissions.dev.network.domains]
        "*.example.com" = "allow"
        """)

        let wholeTopLevel = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["permissions.local.network"]
        )
        XCTAssertEqual(wholeTopLevel?.removed, ["permissions.local.network"])

        try ConfigWriter.removeTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["permissions.local.network"]
        )

        let topLevel = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["permissions.bad.network.enabled", "permissions.bad.network.mode"]
        )
        XCTAssertEqual(topLevel?.removed, ["permissions.bad.network.enabled", "permissions.bad.network.mode"])

        try ConfigWriter.removeTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["permissions.bad.network.enabled", "permissions.bad.network.mode"]
        )

        let parent = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.parent",
            keys: ["network"]
        )
        XCTAssertEqual(parent?.removed, ["network"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.parent",
            keys: ["network"]
        )

        let parentDotted = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.parentDotted",
            keys: ["network.proxy_url", "network.socks_url"]
        )
        XCTAssertEqual(parentDotted?.removed, ["network.proxy_url", "network.socks_url"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.parentDotted",
            keys: ["network.proxy_url", "network.socks_url"]
        )

        let section = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.dev.network",
            keys: ["enabled", "mode", "proxy_url"]
        )
        XCTAssertEqual(section?.removed, ["enabled", "mode", "proxy_url"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.dev.network",
            keys: ["enabled", "mode", "proxy_url"]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("permissions.local.network = \"yes\""))
        XCTAssertFalse(written.contains("permissions.bad.network.enabled"))
        XCTAssertFalse(written.contains("permissions.bad.network.mode"))
        XCTAssertFalse(written.contains("\nnetwork = \"enabled\""))
        XCTAssertFalse(written.contains("network.proxy_url"))
        XCTAssertFalse(written.contains("network.socks_url"))
        XCTAssertFalse(written.contains("\nenabled = \"yes\""))
        XCTAssertFalse(written.contains("\nmode = \"open\""))
        XCTAssertFalse(written.contains("\nproxy_url = 123"))
        XCTAssertTrue(written.contains("permissions.local.network.enabled = true"))
        XCTAssertTrue(written.contains("[permissions.parent]\nnetwork.enabled = true"))
        XCTAssertTrue(written.contains("network.allow_local_binding = true"))
        XCTAssertTrue(written.contains("[permissions.dev.network]\ndomains = \"example.com\""))
        XCTAssertTrue(written.contains("allow_upstream_proxy = true"))
        XCTAssertTrue(written.contains("[permissions.dev.network.domains]\n\"*.example.com\" = \"allow\""))
    }

    func testRemovesInlinePermissionNetworkValuesOnlyWhenSafe() throws {
        let config = try makeTempConfig("""
        permissions.inline.network = { enabled = "yes", mode = "limited" }

        [permissions.parent]
        network = { proxy_url = 123, mode = "full" }
        """)

        let topLevel = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "permissions.inline.network",
            keys: ["enabled"]
        )
        XCTAssertEqual(topLevel?.removed, ["enabled"])

        try ConfigWriter.removeInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "permissions.inline.network",
            keys: ["enabled"]
        )

        let parent = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: "permissions.parent",
            assignmentKey: "network",
            keys: ["proxy_url"]
        )
        XCTAssertEqual(parent?.removed, ["proxy_url"])

        try ConfigWriter.removeInlineTOMLTableKeys(
            configPath: config.path,
            section: "permissions.parent",
            assignmentKey: "network",
            keys: ["proxy_url"]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(written.contains("permissions.inline.network = { mode = \"limited\" }"))
        XCTAssertTrue(written.contains("network = { mode = \"full\" }"))
        XCTAssertFalse(written.contains("enabled = \"yes\""))
        XCTAssertFalse(written.contains("proxy_url = 123"))
    }

    func testRemovesInvalidFilesystemGlobDepthWithoutTouchingRules() throws {
        let config = try makeTempConfig("""
        permissions.project-edit.filesystem.glob_scan_max_depth = "deep"
        permissions.project-edit.filesystem.":minimal" = "read"

        [permissions.dev.filesystem]
        glob_scan_max_depth = "wide"
        "~/Documents" = "deny"

        [permissions.dev.filesystem.":workspace_roots"]
        "." = "write"
        """)

        let topLevel = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["permissions.project-edit.filesystem.glob_scan_max_depth"]
        )
        XCTAssertEqual(topLevel?.removed, ["permissions.project-edit.filesystem.glob_scan_max_depth"])

        try ConfigWriter.removeTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["permissions.project-edit.filesystem.glob_scan_max_depth"]
        )

        let section = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.dev.filesystem",
            keys: ["glob_scan_max_depth"]
        )
        XCTAssertEqual(section?.removed, ["glob_scan_max_depth"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.dev.filesystem",
            keys: ["glob_scan_max_depth"]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("glob_scan_max_depth"))
        XCTAssertTrue(written.contains("permissions.project-edit.filesystem.\":minimal\" = \"read\""))
        XCTAssertTrue(written.contains("[permissions.dev.filesystem]\n\"~/Documents\" = \"deny\""))
        XCTAssertTrue(written.contains("[permissions.dev.filesystem.\":workspace_roots\"]\n\".\" = \"write\""))
    }

    func testRemovesInvalidFilesystemPermissionRulesWithoutTouchingValidRules() throws {
        let config = try makeTempConfig(#"""
        permissions.project-edit.filesystem.":workspace_roots"."." = "allow"
        permissions.project-edit.filesystem.":minimal" = "read"

        permissions.inline.filesystem = { ":minimal" = "read", "~/Documents" = "block", ":workspace_roots" = { "." = "edit", "**/*.env" = "deny" } }

        [permissions.dev.filesystem]
        ":minimal" = "read"
        "~/Documents" = "block"

        [permissions.dev.filesystem.":workspace_roots"]
        "." = "edit"
        "**/*.env" = "deny"
        """#)

        let topLevel = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: config.path,
            keys: [#"permissions.project-edit.filesystem.":workspace_roots".".""#]
        )
        XCTAssertEqual(topLevel?.removed, [#"permissions.project-edit.filesystem.":workspace_roots".".""#])

        try ConfigWriter.removeTopLevelTOMLKeys(
            configPath: config.path,
            keys: [#"permissions.project-edit.filesystem.":workspace_roots".".""#]
        )

        let inline = ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "permissions.inline.filesystem",
            keys: ["~/Documents"]
        )
        XCTAssertEqual(inline?.removed, ["~/Documents"])

        try ConfigWriter.removeInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "permissions.inline.filesystem",
            keys: ["~/Documents"]
        )

        let nestedInline = ConfigWriter.previewRemoveNestedInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "permissions.inline.filesystem",
            tableKey: ":workspace_roots",
            keys: ["."]
        )
        XCTAssertEqual(nestedInline?.removed, ["."])

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: try XCTUnwrap(nestedInline?.before),
            approvedAfter: try XCTUnwrap(nestedInline?.after)
        )

        let section = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.dev.filesystem",
            keys: ["~/Documents"]
        )
        XCTAssertEqual(section?.removed, ["~/Documents"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.dev.filesystem",
            keys: ["~/Documents"]
        )

        let workspaceSection = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: #"permissions.dev.filesystem.":workspace_roots""#,
            keys: ["."]
        )
        XCTAssertEqual(workspaceSection?.removed, ["."])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: #"permissions.dev.filesystem.":workspace_roots""#,
            keys: ["."]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains(#""block""#))
        XCTAssertFalse(written.contains(#""edit""#))
        XCTAssertFalse(written.contains(#""allow""#))
        XCTAssertTrue(written.contains(#"permissions.project-edit.filesystem.":minimal" = "read""#))
        XCTAssertTrue(written.contains(#"permissions.inline.filesystem = { ":minimal" = "read", ":workspace_roots" = { "**/*.env" = "deny" } }"#))
        XCTAssertTrue(written.contains(#"[permissions.dev.filesystem]"#))
        XCTAssertTrue(written.contains(#"":minimal" = "read""#))
        XCTAssertTrue(written.contains(#"[permissions.dev.filesystem.":workspace_roots"]"#))
        XCTAssertTrue(written.contains(#""**/*.env" = "deny""#))
    }

    func testNestedInlineFilesystemRuleRemovalRequiresValidNestedSibling() throws {
        let config = try makeTempConfig(#"""
        [permissions.inline]
        filesystem = { ":minimal" = "read", ":workspace_roots" = { "." = "edit" } }
        """#)

        XCTAssertNil(ConfigWriter.previewRemoveNestedInlineTOMLTableKeys(
            configPath: config.path,
            section: "permissions.inline",
            assignmentKey: "filesystem",
            tableKey: ":workspace_roots",
            keys: ["."]
        ))
    }

    func testRemovesInvalidWorkspaceRootEntriesWithoutTouchingValidEntries() throws {
        let config = try makeTempConfig("""
        permissions.local.workspace_roots."/tmp/bad" = "yes"
        permissions.local.workspace_roots."/tmp/good" = true

        [permissions.parent]
        workspace_roots."/tmp/old" = "no"
        workspace_roots."/tmp/live" = false

        [permissions.dev.workspace_roots]
        "/tmp/repo" = "yes"
        "/tmp/off" = false
        """ )

        let topLevel = ConfigWriter.previewRemoveTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["permissions.local.workspace_roots.\"/tmp/bad"]
        )
        XCTAssertEqual(topLevel?.removed, ["permissions.local.workspace_roots.\"/tmp/bad"])

        try ConfigWriter.removeTopLevelTOMLKeys(
            configPath: config.path,
            keys: ["permissions.local.workspace_roots.\"/tmp/bad"]
        )

        let parent = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.parent",
            keys: ["workspace_roots.\"/tmp/old"]
        )
        XCTAssertEqual(parent?.removed, ["workspace_roots.\"/tmp/old"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.parent",
            keys: ["workspace_roots.\"/tmp/old"]
        )

        let section = ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.dev.workspace_roots",
            keys: ["/tmp/repo"]
        )
        XCTAssertEqual(section?.removed, ["/tmp/repo"])

        try ConfigWriter.removeTOMLSectionKeys(
            configPath: config.path,
            section: "permissions.dev.workspace_roots",
            keys: ["/tmp/repo"]
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertFalse(written.contains("/tmp/bad"))
        XCTAssertFalse(written.contains("/tmp/old"))
        XCTAssertFalse(written.contains("/tmp/repo\" = \"yes\""))
        XCTAssertTrue(written.contains("permissions.local.workspace_roots.\"/tmp/good\" = true"))
        XCTAssertTrue(written.contains("workspace_roots.\"/tmp/live\" = false"))
        XCTAssertTrue(written.contains("[permissions.dev.workspace_roots]\n\"/tmp/off\" = false"))
    }

    func testUpsertsProjectDocMaxBytesBeforeSections() throws {
        let config = try makeTempConfig("""
        model = "gpt-5-codex"

        [profiles.default]
        model = "gpt-5-codex"
        """)

        let preview = ConfigWriter.previewUpsertTopLevelTOMLIntSetting(
            configPath: config.path,
            key: "project_doc_max_bytes",
            value: 65_536
        )

        XCTAssertNotNil(preview)
        XCTAssertTrue(preview?.after.contains("model = \"gpt-5-codex\"\nproject_doc_max_bytes = 65536\n\n[profiles.default]") == true)

        try ConfigWriter.upsertTopLevelTOMLIntSetting(
            configPath: config.path,
            key: "project_doc_max_bytes",
            value: 65_536
        )

        let written = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(written.contains("project_doc_max_bytes = 65536"))
        XCTAssertTrue(written.contains("[profiles.default]\nmodel = \"gpt-5-codex\""))
    }

    func testReplacesProjectDocMaxBytesPreservingComment() throws {
        let config = try makeTempConfig("""
        project_doc_max_bytes = 32768 # current default

        [profiles.default]
        project_doc_max_bytes = 4096
        """)

        let preview = ConfigWriter.previewUpsertTopLevelTOMLIntSetting(
            configPath: config.path,
            key: "project_doc_max_bytes",
            value: 98_304
        )

        XCTAssertNotNil(preview)
        XCTAssertTrue(preview?.after.contains("project_doc_max_bytes = 98304 # current default") == true)
        XCTAssertTrue(preview?.after.contains("[profiles.default]\nproject_doc_max_bytes = 4096") == true)
    }

    func testProjectDocMaxBytesRecognizesTomlIntegerSeparators() throws {
        let config = try makeTempConfig("""
        project_doc_max_bytes = +65_536 # already high enough
        """)

        let preview = ConfigWriter.previewUpsertTopLevelTOMLIntSetting(
            configPath: config.path,
            key: "project_doc_max_bytes",
            value: 65_536
        )

        XCTAssertNil(preview)
    }

    func testReplacesStringProjectDocMaxBytesWithInteger() throws {
        let config = try makeTempConfig("""
        project_doc_max_bytes = "65536" # accidentally quoted

        [profiles.default]
        project_doc_max_bytes = "4096"
        """)

        let preview = ConfigWriter.previewUpsertTopLevelTOMLIntSetting(
            configPath: config.path,
            key: "project_doc_max_bytes",
            value: 32_768
        )

        XCTAssertNotNil(preview)
        XCTAssertTrue(preview?.after.contains("project_doc_max_bytes = 32768 # accidentally quoted") == true)
        XCTAssertTrue(preview?.after.contains("[profiles.default]\nproject_doc_max_bytes = \"4096\"") == true)
    }

    func testReplacesFallbackFilenamesArrayPreservingComment() throws {
        let config = try makeTempConfig("""
        project_doc_fallback_filenames = ["CLAUDE.md", "../bad.md"] # keep local only

        [profiles.default]
        project_doc_fallback_filenames = ["PROFILE.md"]
        """)

        XCTAssertEqual(
            ConfigWriter.topLevelTOMLStringArraySetting(
                configPath: config.path,
                key: "project_doc_fallback_filenames"
            ),
            ["CLAUDE.md", "../bad.md"]
        )

        let preview = ConfigWriter.previewUpsertTopLevelTOMLStringArraySetting(
            configPath: config.path,
            key: "project_doc_fallback_filenames",
            values: ["CLAUDE.md"]
        )

        XCTAssertNotNil(preview)
        XCTAssertTrue(preview?.after.contains("project_doc_fallback_filenames = [\"CLAUDE.md\"] # keep local only") == true)
        XCTAssertTrue(preview?.after.contains("[profiles.default]\nproject_doc_fallback_filenames = [\"PROFILE.md\"]") == true)
    }

    func testWrapsScalarFallbackFilenameAsArray() throws {
        let config = try makeTempConfig("""
        project_doc_fallback_filenames = "CLAUDE.md" # accidentally scalar
        """)

        let preview = ConfigWriter.previewUpsertTopLevelTOMLStringArraySetting(
            configPath: config.path,
            key: "project_doc_fallback_filenames",
            values: ["CLAUDE.md"]
        )

        XCTAssertNotNil(preview)
        XCTAssertTrue(preview?.after.contains("project_doc_fallback_filenames = [\"CLAUDE.md\"] # accidentally scalar") == true)
        XCTAssertNil(ConfigWriter.topLevelTOMLStringArraySetting(
            configPath: config.path,
            key: "project_doc_fallback_filenames"
        ))
    }

    func testCleanFallbackFilenamesReturnsNilWhenAlreadyClean() throws {
        let config = try makeTempConfig("""
        project_doc_fallback_filenames = ["CLAUDE.md", "CONTRIBUTING.md"]
        """)

        let preview = ConfigWriter.previewUpsertTopLevelTOMLStringArraySetting(
            configPath: config.path,
            key: "project_doc_fallback_filenames",
            values: ["CLAUDE.md", "CONTRIBUTING.md"]
        )

        XCTAssertNil(preview)
    }

    func testReplacesProjectRootMarkersArrayPreservingComment() throws {
        let config = try makeTempConfig("""
        project_root_markers = ["projecthub.toml", "../bad.marker"] # keep safe only

        [profiles.default]
        project_root_markers = ["PROFILE.marker"]
        """)

        let preview = ConfigWriter.previewUpsertTopLevelTOMLStringArraySetting(
            configPath: config.path,
            key: "project_root_markers",
            values: ["projecthub.toml"]
        )

        XCTAssertNotNil(preview)
        XCTAssertTrue(preview?.after.contains("project_root_markers = [\"projecthub.toml\"] # keep safe only") == true)
        XCTAssertTrue(preview?.after.contains("[profiles.default]\nproject_root_markers = [\"PROFILE.marker\"]") == true)
    }

    func testWrapsScalarProjectRootMarkerAsArray() throws {
        let config = try makeTempConfig("""
        project_root_markers = "projecthub.toml" # accidentally scalar
        """)

        let preview = ConfigWriter.previewUpsertTopLevelTOMLStringArraySetting(
            configPath: config.path,
            key: "project_root_markers",
            values: ["projecthub.toml"]
        )

        XCTAssertNotNil(preview)
        XCTAssertTrue(preview?.after.contains("project_root_markers = [\"projecthub.toml\"] # accidentally scalar") == true)
    }

    func testCleanProjectRootMarkersReturnsNilWhenAlreadyClean() throws {
        let config = try makeTempConfig("""
        project_root_markers = ["projecthub.toml", ".project-root"]
        """)

        let preview = ConfigWriter.previewUpsertTopLevelTOMLStringArraySetting(
            configPath: config.path,
            key: "project_root_markers",
            values: ["projecthub.toml", ".project-root"]
        )

        XCTAssertNil(preview)
    }

    func testCreatesMissingCodexConfigForProjectDocMaxBytes() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent("missing/config.toml")

        let preview = ConfigWriter.previewUpsertTopLevelTOMLIntSetting(
            configPath: config.path,
            key: "project_doc_max_bytes",
            value: 65_536
        )

        XCTAssertEqual(preview?.before, "")
        XCTAssertEqual(preview?.after, "project_doc_max_bytes = 65536\n")

        try ConfigWriter.upsertTopLevelTOMLIntSetting(
            configPath: config.path,
            key: "project_doc_max_bytes",
            value: 65_536
        )

        XCTAssertEqual(
            try String(contentsOf: config, encoding: .utf8),
            "project_doc_max_bytes = 65536\n"
        )
    }

    func testWritesTextFileOnlyWhenEmpty() throws {
        let root = try makeTempDirectory()
        let file = root.appendingPathComponent("AGENTS.md")
        try "   \n".write(to: file, atomically: true, encoding: .utf8)

        let preview = ConfigWriter.previewWriteTextFileIfEmpty(
            path: file.path,
            content: "# Guidance\n"
        )

        XCTAssertEqual(preview?.before, "   \n")
        XCTAssertEqual(preview?.after, "# Guidance\n")

        try ConfigWriter.writeTextFileIfEmpty(path: file.path, content: "# Guidance\n")

        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "# Guidance\n")
    }

    func testRefusesToOverwriteNonEmptyTextFile() throws {
        let root = try makeTempDirectory()
        let file = root.appendingPathComponent("CLAUDE.md")
        try "# Existing\n".write(to: file, atomically: true, encoding: .utf8)

        XCTAssertNil(ConfigWriter.previewWriteTextFileIfEmpty(
            path: file.path,
            content: "# Replacement\n"
        ))

        XCTAssertThrowsError(try ConfigWriter.writeTextFileIfEmpty(
            path: file.path,
            content: "# Replacement\n"
        ))
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "# Existing\n")
    }

    func testMergesTextFileOnlyWhenPreviewedContentStillMatches() throws {
        let root = try makeTempDirectory()
        let file = root.appendingPathComponent("CLAUDE.md")
        let existing = "# Claude guidance\n"
        let merged = "@AGENTS.md\n\n# Claude guidance\n"
        try existing.write(to: file, atomically: true, encoding: .utf8)

        let preview = ConfigWriter.previewMergeTextFile(
            path: file.path,
            expectedBefore: existing,
            mergedContent: merged
        )

        XCTAssertEqual(preview?.before, existing)
        XCTAssertEqual(preview?.after, merged)

        try ConfigWriter.mergeTextFile(
            path: file.path,
            expectedBefore: existing,
            mergedContent: merged
        )

        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), merged)
        let backups = try FileManager.default.contentsOfDirectory(atPath: root.path)
            .filter { $0.hasPrefix("CLAUDE.md.bak.") }
        XCTAssertEqual(backups.count, 1)
    }

    func testMergeTextFileRefusesWhenFileChangedAfterPreview() throws {
        let root = try makeTempDirectory()
        let file = root.appendingPathComponent("CLAUDE.md")
        let existing = "# Claude guidance\n"
        try existing.write(to: file, atomically: true, encoding: .utf8)

        XCTAssertNotNil(ConfigWriter.previewMergeTextFile(
            path: file.path,
            expectedBefore: existing,
            mergedContent: "@AGENTS.md\n\n# Claude guidance\n"
        ))

        try "# User changed this\n".write(to: file, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try ConfigWriter.mergeTextFile(
            path: file.path,
            expectedBefore: existing,
            mergedContent: "@AGENTS.md\n\n# Claude guidance\n"
        ))
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "# User changed this\n")
    }

    func testApplyTOMLPreviewWritesExactApprovedContent() throws {
        let config = try makeTempConfig("""
        [profiles.bad]
        sandbox_mode = "experimental"
        approval_policy = "never"
        """)

        let preview = try XCTUnwrap(ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.bad",
            keys: ["sandbox_mode"]
        ))

        try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: preview.before,
            approvedAfter: preview.after
        )

        XCTAssertEqual(try String(contentsOf: config, encoding: .utf8), preview.after)
        XCTAssertFalse(preview.after.contains("sandbox_mode"))
        XCTAssertTrue(preview.after.contains("approval_policy = \"never\""))
    }

    func testApplyTOMLPreviewRefusesSectionRemovalWhenFileChangedAfterPreview() throws {
        let config = try makeTempConfig("""
        [profiles.bad]
        sandbox_mode = "experimental"
        approval_policy = "never"
        """)

        let preview = try XCTUnwrap(ConfigWriter.previewRemoveTOMLSectionKeys(
            configPath: config.path,
            section: "profiles.bad",
            keys: ["sandbox_mode"]
        ))
        let changed = """
        [profiles.bad]
        sandbox_mode = "experimental"
        approval_policy = "on-request"
        """
        try changed.write(to: config, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: preview.before,
            approvedAfter: preview.after
        ))
        XCTAssertEqual(try String(contentsOf: config, encoding: .utf8), changed)
    }

    func testApplyTOMLPreviewRefusesInlineTableRemovalWhenFileChangedAfterPreview() throws {
        let config = try makeTempConfig("""
        sandbox_workspace_write = { network_access = true, writable_roots = ["/tmp"] }
        model = "gpt-5"
        """)

        let preview = try XCTUnwrap(ConfigWriter.previewRemoveInlineTOMLTableKeys(
            configPath: config.path,
            section: nil,
            assignmentKey: "sandbox_workspace_write",
            keys: ["network_access"]
        ))
        let changed = """
        sandbox_workspace_write = { network_access = false, writable_roots = ["/tmp"] }
        model = "gpt-5"
        """
        try changed.write(to: config, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try ConfigWriter.applyTOMLPreview(
            configPath: config.path,
            expectedBefore: preview.before,
            approvedAfter: preview.after
        ))
        XCTAssertEqual(try String(contentsOf: config, encoding: .utf8), changed)
    }

    func testApplyTextPreviewWritesExactJSONMCPEnablePreview() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent(".mcp.json")
        try """
        {
          "mcpServers_disabled": {
            "docs": { "command": "npx", "args": ["-y", "@example/docs"] }
          }
        }
        """.write(to: config, atomically: true, encoding: .utf8)

        let preview = try XCTUnwrap(ConfigWriter.previewSetServerEnabled(
            toolID: "claude-code",
            scope: .project,
            projectRoot: root.path,
            name: "docs",
            enabled: true
        ))

        try ConfigWriter.applyTextPreview(
            configPath: config.path,
            expectedBefore: preview.before,
            approvedAfter: preview.after
        )

        XCTAssertEqual(try String(contentsOf: config, encoding: .utf8), preview.after)
        XCTAssertTrue(preview.after.contains(#""mcpServers""#))
        XCTAssertFalse(preview.after.contains("mcpServers_disabled"))
    }

    func testApplyTextPreviewRefusesJSONMCPRemovalWhenFileChangedAfterPreview() throws {
        let root = try makeTempDirectory()
        let config = root.appendingPathComponent(".mcp.json")
        let original = """
        {
          "mcpServers": {
            "broken": { "command": "/missing" },
            "keep": { "command": "/bin/echo" }
          }
        }
        """
        try original.write(to: config, atomically: true, encoding: .utf8)

        let preview = try XCTUnwrap(ConfigWriter.previewRemoveServer(
            toolID: "claude-code",
            scope: .project,
            projectRoot: root.path,
            name: "broken"
        ))
        let changed = """
        {
          "mcpServers": {
            "broken": { "command": "/other-missing" },
            "keep": { "command": "/bin/echo" }
          }
        }
        """
        try changed.write(to: config, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try ConfigWriter.applyTextPreview(
            configPath: config.path,
            expectedBefore: preview.before,
            approvedAfter: preview.after
        ))
        XCTAssertEqual(try String(contentsOf: config, encoding: .utf8), changed)
    }

    func testApplyTextPreviewWritesExactCodexMCPEnablePreview() throws {
        let root = try makeTempDirectory()
        let codexDir = root.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexDir, withIntermediateDirectories: true)
        let config = codexDir.appendingPathComponent("config.toml")
        try """
        [mcp_servers.docs]
        command = "npx"
        args = ["-y", "@example/docs"]
        enabled = false
        """.write(to: config, atomically: true, encoding: .utf8)

        let preview = try XCTUnwrap(ConfigWriter.previewSetServerEnabled(
            toolID: "codex",
            scope: .project,
            projectRoot: root.path,
            name: "docs",
            enabled: true
        ))

        try ConfigWriter.applyTextPreview(
            configPath: config.path,
            expectedBefore: preview.before,
            approvedAfter: preview.after
        )

        XCTAssertEqual(try String(contentsOf: config, encoding: .utf8), preview.after)
        XCTAssertFalse(preview.after.contains("enabled = false"))
    }

    func testApplyTextPreviewRefusesCodexMCPRemovalWhenFileChangedAfterPreview() throws {
        let root = try makeTempDirectory()
        let codexDir = root.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexDir, withIntermediateDirectories: true)
        let config = codexDir.appendingPathComponent("config.toml")
        let original = """
        [mcp_servers.broken]
        command = "/missing"

        [mcp_servers.keep]
        command = "/bin/echo"
        """
        try original.write(to: config, atomically: true, encoding: .utf8)

        let preview = try XCTUnwrap(ConfigWriter.previewRemoveServer(
            toolID: "codex",
            scope: .project,
            projectRoot: root.path,
            name: "broken"
        ))
        let changed = """
        [mcp_servers.broken]
        command = "/other-missing"

        [mcp_servers.keep]
        command = "/bin/echo"
        """
        try changed.write(to: config, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try ConfigWriter.applyTextPreview(
            configPath: config.path,
            expectedBefore: preview.before,
            approvedAfter: preview.after
        ))
        XCTAssertEqual(try String(contentsOf: config, encoding: .utf8), changed)
    }

    private func makeTempConfig(_ text: String) throws -> URL {
        let root = try makeTempDirectory()
        let path = root.appendingPathComponent("config.toml")
        try text.write(to: path, atomically: true, encoding: .utf8)
        return path
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

    private func makeTempDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubConfigWriterSettingsRepairTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }
}
