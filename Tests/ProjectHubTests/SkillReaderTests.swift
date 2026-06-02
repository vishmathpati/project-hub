import XCTest
@testable import ProjectHub

final class SkillReaderTests: XCTestCase {
    func testParsesClaudeMetadataFromSkillFrontmatter() throws {
        let root = try makeTempDirectory()
        let skill = root.appendingPathComponent("deploy-helper", isDirectory: true)
        try FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)
        try """
        ---
        name: deploy-helper
        description: Deploys safely.
        when_to_use: Use before production deploys.
        allowed-tools:
          - Read
          - Bash(git status)
        disable-model-invocation: true
        user-invocable: false
        argument-hint: "[environment]"
        arguments: [environment, release]
        model: sonnet
        effort: high
        context: fork
        agent: release
        paths:
          - "scripts/**"
          - "deploy/**"
        shell: bash
        hooks:
          before:
            - command: ./scripts/check.sh
        ---

        Deploy carefully.
        """.write(to: skill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let metadata = try XCTUnwrap(SkillReader.parseClaudeMetadata(at: skill.path))

        XCTAssertEqual(metadata.whenToUse, "Use before production deploys.")
        XCTAssertEqual(metadata.allowedTools, ["Read", "Bash(git status)"])
        XCTAssertEqual(metadata.disableModelInvocation, true)
        XCTAssertEqual(metadata.userInvocable, false)
        XCTAssertEqual(metadata.argumentHint, "[environment]")
        XCTAssertEqual(metadata.arguments, ["environment", "release"])
        XCTAssertEqual(metadata.model, "sonnet")
        XCTAssertEqual(metadata.effort, "high")
        XCTAssertEqual(metadata.context, "fork")
        XCTAssertEqual(metadata.agent, "release")
        XCTAssertEqual(metadata.paths, ["scripts/**", "deploy/**"])
        XCTAssertEqual(metadata.shell, "bash")
        XCTAssertTrue(metadata.hooks?.contains("command: ./scripts/check.sh") == true)
    }

    func testParsesOpenAIMetadata() throws {
        let root = try makeTempDirectory()
        let skill = root.appendingPathComponent("docs-skill", isDirectory: true)
        let agents = skill.appendingPathComponent("agents", isDirectory: true)
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
        try """
        interface:
          display_name: "Docs Skill"
          short_description: "Searches internal docs."
          icon_small: "./assets/small-logo.svg"
          icon_large: "./assets/large-logo.png"
          brand_color: "#3B82F6"
          default_prompt: "Search the docs for this API."
        policy:
          allow_implicit_invocation: false
        dependencies:
          tools:
            - type: "mcp"
              value: "openaiDeveloperDocs"
              description: "OpenAI Docs MCP server"
              transport: "streamable_http"
              url: "https://developers.openai.com/mcp"
        """.write(to: agents.appendingPathComponent("openai.yaml"), atomically: true, encoding: .utf8)

        let metadata = try XCTUnwrap(SkillReader.parseOpenAIMetadata(at: skill.path))

        XCTAssertEqual(metadata.displayName, "Docs Skill")
        XCTAssertEqual(metadata.shortDescription, "Searches internal docs.")
        XCTAssertEqual(metadata.iconSmall, "./assets/small-logo.svg")
        XCTAssertEqual(metadata.iconLarge, "./assets/large-logo.png")
        XCTAssertEqual(metadata.brandColor, "#3B82F6")
        XCTAssertEqual(metadata.defaultPrompt, "Search the docs for this API.")
        XCTAssertEqual(metadata.allowImplicitInvocation, false)
        XCTAssertEqual(metadata.toolDependencies.count, 1)
        XCTAssertEqual(metadata.toolDependencies.first?.type, "mcp")
        XCTAssertEqual(metadata.toolDependencies.first?.value, "openaiDeveloperDocs")
        XCTAssertEqual(metadata.toolDependencies.first?.transport, "streamable_http")
        XCTAssertEqual(metadata.toolDependencies.first?.url, "https://developers.openai.com/mcp")
    }

    private func makeTempDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubSkillReaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }
}
