import XCTest
@testable import ProjectHub

final class ConfigWriterCredentialUpdateTests: XCTestCase {
    func testCodexRemoteCredentialUpdateWritesLiteralHeadersAndURLValues() throws {
        let codexHome = try makeTempDirectory()
        let configURL = codexHome.appendingPathComponent("config.toml")
        try FileManager.default.createDirectory(
            at: codexHome,
            withIntermediateDirectories: true
        )
        try """
        [mcp_servers.analytics]
        url = "https://${TENANT_ID}.example.com/mcp"
        http_headers = { X-Static = "still" }
        env_http_headers = { X-API-Key = "X_API_KEY" }
        """.write(to: configURL, atomically: true, encoding: .utf8)

        try withEnv("CODEX_HOME", codexHome.path) {
            try ConfigWriter.updateServerCredentials(
                toolID: "codex",
                name: "analytics",
                values: [
                    "TENANT_ID": "acme",
                    "X_API_KEY": "secret"
                ],
                requirements: [
                    .init(
                        kind: .urlVariable,
                        name: "tenant_id",
                        envName: "TENANT_ID",
                        placeholder: "${TENANT_ID}",
                        required: true,
                        secret: false,
                        description: "Tenant slug",
                        source: "test"
                    ),
                    .init(
                        kind: .header,
                        name: "X-API-Key",
                        envName: "X_API_KEY",
                        placeholder: "${X_API_KEY}",
                        required: true,
                        secret: true,
                        description: nil,
                        source: "test"
                    )
                ]
            )
        }

        let raw = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(raw.contains(#"url = "https://acme.example.com/mcp""#))
        XCTAssertTrue(raw.contains(#"http_headers = { X-API-Key = "secret", X-Static = "still" }"#))
        XCTAssertFalse(raw.contains("env_http_headers"))
    }

    func testCodexRemoteCredentialUpdatePreservesHeaderTemplates() throws {
        let codexHome = try makeTempDirectory()
        let configURL = codexHome.appendingPathComponent("config.toml")
        try FileManager.default.createDirectory(
            at: codexHome,
            withIntermediateDirectories: true
        )
        try """
        [mcp_servers.analytics]
        url = "https://analytics.example.com/mcp"
        http_headers = { Authorization = "Bearer ${API_TOKEN}" }
        """.write(to: configURL, atomically: true, encoding: .utf8)

        try withEnv("CODEX_HOME", codexHome.path) {
            try ConfigWriter.updateServerCredentials(
                toolID: "codex",
                name: "analytics",
                values: ["API_TOKEN": "secret"],
                requirements: [
                    .init(
                        kind: .header,
                        name: "Authorization",
                        envName: "API_TOKEN",
                        placeholder: "${API_TOKEN}",
                        required: true,
                        secret: true,
                        description: nil,
                        source: "test"
                    )
                ]
            )
        }

        let raw = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(raw.contains(#"http_headers = { Authorization = "Bearer secret" }"#))
    }

    func testCodexRemoteCredentialUpdatePreservesInputHeaderTemplates() throws {
        let codexHome = try makeTempDirectory()
        let configURL = codexHome.appendingPathComponent("config.toml")
        try FileManager.default.createDirectory(
            at: codexHome,
            withIntermediateDirectories: true
        )
        try """
        [mcp_servers.analytics]
        url = "https://analytics.example.com/mcp"
        http_headers = { Authorization = "Bearer ${input:token}" }
        """.write(to: configURL, atomically: true, encoding: .utf8)

        try withEnv("CODEX_HOME", codexHome.path) {
            try ConfigWriter.updateServerCredentials(
                toolID: "codex",
                name: "analytics",
                values: ["Authorization": "secret"],
                requirements: [
                    .init(
                        kind: .header,
                        name: "Authorization",
                        envName: nil,
                        placeholder: "${input:token}",
                        required: true,
                        secret: true,
                        description: nil,
                        source: "test"
                    )
                ]
            )
        }

        let raw = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(raw.contains(#"http_headers = { Authorization = "Bearer secret" }"#))
    }

    private func withEnv(_ key: String, _ value: String, run: () throws -> Void) rethrows {
        let previous = getenv(key).map { String(cString: $0) }
        setenv(key, value, 1)
        defer {
            if let previous {
                setenv(key, previous, 1)
            } else {
                unsetenv(key)
            }
        }
        try run()
    }

    private func makeTempDirectory() throws -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let url = base.appendingPathComponent("projecthub-config-writer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
