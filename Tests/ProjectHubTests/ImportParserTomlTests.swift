import XCTest
@testable import ProjectHub

final class ImportParserTomlTests: XCTestCase {
    func testCodexTOMLParsesStdioAndRemoteServers() throws {
        let servers = try parsed("""
        [mcp_servers.context7]
        command = "npx"
        args = ["-y", "@upstash/context7-mcp"]
        env_vars = ["CONTEXT7_API_KEY", { name = "REMOTE_CONTEXT", source = "remote" }]

        [mcp_servers.context7.env]
        CONTEXT7_API_KEY = "${CONTEXT7_API_KEY}"

        [mcp_servers.supabase]
        url = "https://mcp.supabase.com/mcp"
        bearer_token_env_var = "SUPABASE_ACCESS_TOKEN"
        http_headers = { "X-Static" = "yes" }

        [mcp_servers.supabase.env_http_headers]
        Authorization = "SUPABASE_ACCESS_TOKEN"
        """)

        let context7 = try XCTUnwrap(servers.first { $0.name == "context7" })
        XCTAssertEqual(context7.config["command"] as? String, "npx")
        XCTAssertEqual(context7.config["args"] as? [String], ["-y", "@upstash/context7-mcp"])
        XCTAssertEqual(context7.config["env"] as? [String: String], ["CONTEXT7_API_KEY": "${CONTEXT7_API_KEY}"])
        XCTAssertEqual(context7.config["env_vars"] as? [[String: String]], [
            ["name": "CONTEXT7_API_KEY", "source": "local"],
            ["name": "REMOTE_CONTEXT", "source": "remote"]
        ])

        let supabase = try XCTUnwrap(servers.first { $0.name == "supabase" })
        XCTAssertEqual(supabase.config["type"] as? String, "http")
        XCTAssertEqual(supabase.config["url"] as? String, "https://mcp.supabase.com/mcp")
        XCTAssertEqual(supabase.config["bearer_token_env_var"] as? String, "SUPABASE_ACCESS_TOKEN")
        XCTAssertEqual(supabase.config["env_http_headers"] as? [String: String], ["Authorization": "SUPABASE_ACCESS_TOKEN"])
        XCTAssertEqual((supabase.config["headers"] as? [String: String])?["X-Static"], "yes")
        XCTAssertEqual((supabase.config["headers"] as? [String: String])?["Authorization"], "${SUPABASE_ACCESS_TOKEN}")
    }

    func testCodexTOMLParsesQuotedNamesMultilineArraysAndDottedKeys() throws {
        let servers = try parsed("""
        [mcp_servers."github.docs"] # copied from config.toml
        command = "npx"
        args = [
          "-y",
          "@modelcontextprotocol/server-github",
          "--label=a,b",
        ]
        env.GITHUB_PERSONAL_ACCESS_TOKEN = "${GITHUB_PERSONAL_ACCESS_TOKEN}"
        enabled = false
        """)

        let server = try XCTUnwrap(servers.first)
        XCTAssertEqual(server.name, "github.docs")
        XCTAssertEqual(server.config["command"] as? String, "npx")
        XCTAssertEqual(
            server.config["args"] as? [String],
            ["-y", "@modelcontextprotocol/server-github", "--label=a,b"]
        )
        XCTAssertEqual(server.config["env"] as? [String: String], [
            "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}"
        ])
        XCTAssertEqual(server.config["enabled"] as? Bool, false)
    }

    func testCodexTOMLParsesQuotedRootAndServerName() throws {
        let servers = try parsed("""
        ["mcp_servers"."github.docs"]
        command = "npx"
        args = ["-y", "@example/docs-mcp"]
        """)

        let server = try XCTUnwrap(servers.first)
        XCTAssertEqual(server.name, "github.docs")
        XCTAssertEqual(server.config["command"] as? String, "npx")
        XCTAssertEqual(server.config["args"] as? [String], ["-y", "@example/docs-mcp"])
    }

    private func parsed(_ raw: String) throws -> [ParsedServer] {
        switch ImportParser.parse(raw) {
        case .success(let servers):
            return servers
        case .failure(let error):
            XCTFail("Expected parse success, got \(error)")
            throw error
        }
    }
}
