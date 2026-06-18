import XCTest
@testable import ProjectHub

final class MCPImportScopePlannerTests: XCTestCase {
    func testRemoteServersMakeClaudeDesktopConnectorOnly() {
        let servers = [
            ParsedServer(
                name: "supabase",
                config: [
                    "type": "http",
                    "url": "https://mcp.supabase.com/mcp"
                ]
            )
        ]

        XCTAssertFalse(MCPImportScopePlanner.toolIsEligible("claude-desktop", useProjectScope: false, servers: servers))
        XCTAssertEqual(MCPImportScopePlanner.toolSupportNote("claude-desktop", useProjectScope: false, servers: servers), "use Connectors")
        XCTAssertEqual(
            MCPImportScopePlanner.eligibleToolIDs(["claude-code", "claude-desktop", "codex"], useProjectScope: false, servers: servers),
            ["codex"]
        )
        XCTAssertFalse(MCPImportScopePlanner.canImport(
            selectedTools: ["claude-desktop"],
            useProjectScope: false,
            projectRoot: nil,
            serverNames: ["supabase"],
            servers: servers
        ))
    }

    func testStdioServersStillAllowClaudeDesktop() {
        let servers = [
            ParsedServer(
                name: "filesystem",
                config: [
                    "command": "npx",
                    "args": ["-y", "@modelcontextprotocol/server-filesystem"]
                ]
            )
        ]

        XCTAssertTrue(MCPImportScopePlanner.toolIsEligible("claude-desktop", useProjectScope: false, servers: servers))
        XCTAssertNil(MCPImportScopePlanner.toolSupportNote("claude-desktop", useProjectScope: false, servers: servers))
        XCTAssertFalse(MCPImportScopePlanner.toolIsEligible("claude-code", useProjectScope: false, servers: servers))
        XCTAssertEqual(MCPImportScopePlanner.toolSupportNote("claude-code", useProjectScope: false, servers: servers), "use Claude CLI")
    }

    func testProjectScopeAllowsClaudeCodeAndCodexOnly() {
        let servers = [
            ParsedServer(
                name: "filesystem",
                config: [
                    "command": "npx",
                    "args": ["-y", "@modelcontextprotocol/server-filesystem"]
                ]
            )
        ]

        XCTAssertTrue(MCPImportScopePlanner.toolIsEligible("claude-code", useProjectScope: true, servers: servers))
        XCTAssertTrue(MCPImportScopePlanner.toolIsEligible("codex", useProjectScope: true, servers: servers))
        XCTAssertFalse(MCPImportScopePlanner.toolIsEligible("claude-desktop", useProjectScope: true, servers: servers))
    }
}
