import XCTest
@testable import ProjectHub

final class ImportParserRegistryManifestTests: XCTestCase {
    func testRegistryNpmPackageBecomesNpxLaunch() throws {
        let server = try onlyParsed("""
        {
          "$schema": "https://static.modelcontextprotocol.io/schemas/2025-12-11/server.schema.json",
          "name": "io.github.username/email-integration-mcp",
          "title": "Email Integration",
          "version": "1.0.0",
          "packages": [
            {
              "registryType": "npm",
              "identifier": "@username/email-integration-mcp",
              "transport": { "type": "stdio" },
              "environmentVariables": [
                { "name": "EMAIL_API_KEY", "isRequired": true, "isSecret": true }
              ]
            }
          ]
        }
        """)

        XCTAssertEqual(server.name, "email-integration-mcp-npm")
        XCTAssertEqual(server.config["command"] as? String, "npx")
        XCTAssertEqual(server.config["args"] as? [String], ["-y", "@username/email-integration-mcp"])
        XCTAssertEqual(server.config["env"] as? [String: String], ["EMAIL_API_KEY": "${EMAIL_API_KEY}"])
    }

    func testRegistryPypiPackageBecomesUvxLaunch() throws {
        let server = try onlyParsed("""
        {
          "name": "io.github.username/database-query-mcp",
          "packages": [
            {
              "registryType": "pypi",
              "identifier": "database-query-mcp",
              "transport": { "type": "stdio" },
              "packageArguments": [
                { "type": "named", "name": "--profile", "default": "readonly" }
              ]
            }
          ]
        }
        """)

        XCTAssertEqual(server.name, "database-query-mcp-pypi")
        XCTAssertEqual(server.config["command"] as? String, "uvx")
        XCTAssertEqual(server.config["args"] as? [String], ["database-query-mcp", "--profile", "readonly"])
    }

    func testRegistryOciPackageBecomesDockerRunWithEnvFlags() throws {
        let server = try onlyParsed("""
        {
          "name": "io.github.username/kubernetes-manager-mcp",
          "packages": [
            {
              "registryType": "oci",
              "identifier": "ghcr.io/username/kubernetes-manager-mcp:1.0.0",
              "transport": { "type": "stdio" },
              "environmentVariables": [
                { "name": "KUBECONFIG", "isRequired": true }
              ]
            }
          ]
        }
        """)

        XCTAssertEqual(server.name, "kubernetes-manager-mcp-oci")
        XCTAssertEqual(server.config["command"] as? String, "docker")
        XCTAssertEqual(server.config["args"] as? [String], [
            "run",
            "-i",
            "--rm",
            "--env",
            "KUBECONFIG",
            "ghcr.io/username/kubernetes-manager-mcp:1.0.0"
        ])
        XCTAssertEqual(server.config["env"] as? [String: String], ["KUBECONFIG": "${KUBECONFIG}"])
    }

    func testRegistryRemoteManifestParsesHeadersAndURLVariables() throws {
        let server = try onlyParsed("""
        {
          "name": "com.example/acme-analytics",
          "remotes": [
            {
              "type": "streamable-http",
              "url": "https://{tenant_id}.analytics.example.com/mcp",
              "variables": {
                "tenant_id": { "isRequired": true }
              },
              "headers": [
                {
                  "name": "X-API-Key",
                  "description": "API key for authentication",
                  "isRequired": true,
                  "isSecret": true
                }
              ]
            }
          ]
        }
        """)

        XCTAssertEqual(server.name, "acme-analytics")
        XCTAssertEqual(server.config["type"] as? String, "http")
        XCTAssertEqual(server.config["url"] as? String, "https://${TENANT_ID}.analytics.example.com/mcp")
        XCTAssertEqual(server.config["headers"] as? [String: String], ["X-API-Key": "${X_API_KEY}"])
        XCTAssertNil(server.config["env_http_headers"])
        XCTAssertEqual(server.credentialRequirements.count, 2)
        XCTAssertTrue(server.credentialRequirements.contains {
            $0.kind == .urlVariable
                && $0.name == "tenant_id"
                && $0.envName == "TENANT_ID"
                && $0.required
        })
        XCTAssertTrue(server.credentialRequirements.contains {
            $0.kind == .header
                && $0.name == "X-API-Key"
                && $0.envName == "X_API_KEY"
                && $0.required
                && $0.secret
                && $0.description == "API key for authentication"
        })
    }

    func testRegistryRemoteManifestParsesScalarURLVariables() throws {
        let server = try onlyParsed("""
        {
          "name": "com.example/acme-analytics",
          "remotes": [
            {
              "type": "streamable-http",
              "url": "https://{region}.{tenant}.analytics.example.com/mcp",
              "variables": {
                "region": "us-east-1",
                "tenant": "${TENANT_ID}"
              }
            }
          ]
        }
        """)

        XCTAssertEqual(
            server.config["url"] as? String,
            "https://us-east-1.${TENANT_ID}.analytics.example.com/mcp"
        )
        XCTAssertEqual(server.credentialRequirements.count, 1)
        XCTAssertTrue(server.credentialRequirements.contains {
            $0.kind == .urlVariable
                && $0.name == "tenant"
                && $0.envName == "TENANT_ID"
        })
        XCTAssertFalse(server.credentialRequirements.contains {
            $0.kind == .urlVariable && $0.name == "region"
        })
    }

    func testRegistryRemoteManifestParsesObjectMapHeaders() throws {
        let server = try onlyParsed("""
        {
          "name": "com.example/acme-analytics",
          "remotes": [
            {
              "type": "streamable-http",
              "url": "https://analytics.example.com/mcp",
              "headers": {
                "X-API-Key": {
                  "description": "API key for authentication",
                  "isRequired": true,
                  "isSecret": true
                }
              }
            }
          ]
        }
        """)

        XCTAssertEqual(server.name, "acme-analytics")
        XCTAssertEqual(server.config["headers"] as? [String: String], ["X-API-Key": "${X_API_KEY}"])
        XCTAssertTrue(server.credentialRequirements.contains {
            $0.kind == .header
                && $0.name == "X-API-Key"
                && $0.envName == "X_API_KEY"
                && $0.required
                && $0.secret
                && $0.description == "API key for authentication"
                && $0.source == "registry remote header"
        })
    }

    func testRegistryPackageParsesObjectMapEnvironmentVariables() throws {
        let server = try onlyParsed("""
        {
          "name": "io.github.username/email-integration-mcp",
          "packages": [
            {
              "registryType": "npm",
              "identifier": "@username/email-integration-mcp",
              "transport": { "type": "stdio" },
              "environmentVariables": {
                "EMAIL_API_KEY": {
                  "description": "Email API key",
                  "isRequired": true,
                  "isSecret": true
                },
                "LOG_LEVEL": "debug"
              }
            }
          ]
        }
        """)

        XCTAssertEqual(server.name, "email-integration-mcp-npm")
        XCTAssertEqual(server.config["env"] as? [String: String], [
            "EMAIL_API_KEY": "${EMAIL_API_KEY}",
            "LOG_LEVEL": "debug"
        ])
        XCTAssertTrue(server.credentialRequirements.contains {
            $0.kind == .env
                && $0.name == "EMAIL_API_KEY"
                && $0.envName == "EMAIL_API_KEY"
                && $0.required
                && $0.secret
                && $0.description == "Email API key"
                && $0.source == "registry package environment variable"
        })
        XCTAssertFalse(server.credentialRequirements.contains {
            $0.kind == .env && $0.name == "LOG_LEVEL"
        })
    }

    func testRegistryPackageEnvironmentVariableValueTemplatesResolveNestedVariables() throws {
        let server = try onlyParsed("""
        {
          "name": "io.github.username/sample-weather-mcp",
          "packages": [
            {
              "registryType": "nuget",
              "identifier": "Username.SampleWeatherMcp",
              "transport": { "type": "stdio" },
              "packageArguments": [
                {
                  "type": "named",
                  "name": "--profile",
                  "value": "{profile}",
                  "variables": {
                    "profile": { "default": "readonly" }
                  }
                }
              ],
              "environmentVariables": [
                {
                  "name": "WEATHER_CHOICES",
                  "value": "{weather_choices}",
                  "variables": {
                    "weather_choices": {
                      "description": "Comma separated weather choices",
                      "isRequired": true,
                      "isSecret": false
                    }
                  }
                }
              ]
            }
          ]
        }
        """)

        XCTAssertEqual(server.name, "sample-weather-mcp-nuget")
        XCTAssertEqual(server.config["command"] as? String, "dnx")
        XCTAssertEqual(server.config["args"] as? [String], [
            "Username.SampleWeatherMcp",
            "--profile",
            "readonly"
        ])
        XCTAssertEqual(server.config["env"] as? [String: String], [
            "WEATHER_CHOICES": "${WEATHER_CHOICES}"
        ])
        XCTAssertTrue(server.credentialRequirements.contains {
            $0.kind == .env
                && $0.name == "WEATHER_CHOICES"
                && $0.envName == "WEATHER_CHOICES"
                && $0.required
                && !$0.secret
                && $0.description == "Comma separated weather choices"
                && $0.source == "registry package environment variable nested variable"
        })
    }

    func testRegistryManifestWithRemoteAndPackageReturnsBoth() throws {
        let raw = """
        {
          "name": "io.github.username/email-integration-mcp",
          "remotes": [
            { "type": "streamable-http", "url": "https://email.example.com/mcp" }
          ],
          "packages": [
            {
              "registryType": "npm",
              "identifier": "@example/email-integration-mcp",
              "transport": { "type": "stdio" }
            }
          ]
        }
        """

        switch ImportParser.parse(raw) {
        case .success(let servers):
            XCTAssertEqual(servers.map(\.name), ["email-integration-mcp", "email-integration-mcp-npm"])
            XCTAssertEqual(servers[0].config["url"] as? String, "https://email.example.com/mcp")
            if servers.indices.contains(1) {
                XCTAssertEqual(servers[1].config["command"] as? String, "npx")
            }
        case .failure(let error):
            XCTFail("Expected parse success, got \(error)")
        }

        let choices = ImportParser.importChoices(from: raw)
        XCTAssertEqual(choices.map(\.label), ["Registry HTTP remote", "Registry npm package"])
        XCTAssertEqual(choices.count, 2)
        XCTAssertEqual(choices[0].servers.count, 1)
        XCTAssertEqual(choices[0].servers[0].config["url"] as? String, "https://email.example.com/mcp")
        XCTAssertEqual(choices[1].servers.count, 1)
        XCTAssertEqual(choices[1].servers[0].config["command"] as? String, "npx")
        XCTAssertTrue(choices[0].source.contains("email.example.com"))
        XCTAssertTrue(choices[1].source.contains("@example/email-integration-mcp"))
    }

    func testRegistryManifestWithMultipleRemotesReturnsRemoteChoices() throws {
        let choices = ImportParser.importChoices(from: """
        {
          "name": "com.example/acme-analytics",
          "remotes": [
            { "type": "streamable-http", "url": "https://analytics.example.com/mcp" },
            { "type": "sse", "url": "https://analytics.example.com/sse" }
          ]
        }
        """)

        XCTAssertEqual(choices.map(\.label), ["Registry HTTP remote", "Registry SSE remote"])
        XCTAssertEqual(choices.map { $0.servers[0].name }, ["acme-analytics-http-1", "acme-analytics-sse"])
        XCTAssertEqual(choices[0].servers[0].config["type"] as? String, "http")
        XCTAssertEqual(choices[1].servers[0].config["type"] as? String, "sse")
        XCTAssertTrue(choices[0].source.contains("/mcp"))
        XCTAssertTrue(choices[1].source.contains("/sse"))
    }

    func testRegistryManifestWithSinglePackageStillHasOneChoice() throws {
        let raw = """
        {
          "name": "io.github.username/email-integration-mcp",
          "packages": [
            {
              "registryType": "npm",
              "identifier": "@username/email-integration-mcp",
              "transport": { "type": "stdio" }
            }
          ]
        }
        """

        let choices = ImportParser.importChoices(from: raw)
        XCTAssertEqual(choices.count, 1)
        XCTAssertEqual(choices[0].label, "Registry npm package")
        XCTAssertEqual(choices[0].servers[0].name, "email-integration-mcp-npm")
    }

    func testRegistryMCPBPackageBecomesArchiveHandoffChoice() throws {
        let raw = """
        {
          "name": "io.github.example/desktop-tools",
          "packages": [
            {
              "registryType": "mcpb",
              "identifier": "https://github.com/example/desktop-tools/releases/download/v1.0.0/desktop-tools.mcpb",
              "fileSha256": "abcdef123456"
            }
          ]
        }
        """

        let choices = ImportParser.importChoices(from: raw)
        XCTAssertEqual(choices.count, 1)
        XCTAssertEqual(choices[0].label, "Registry MCPB package")
        XCTAssertEqual(choices[0].servers.count, 0)
        XCTAssertEqual(choices[0].archiveURL?.absoluteString, "https://github.com/example/desktop-tools/releases/download/v1.0.0/desktop-tools.mcpb")
        XCTAssertEqual(choices[0].archiveSHA256, "abcdef123456")

        switch ImportParser.parse(raw) {
        case .success(let servers):
            XCTFail("MCPB registry packages should not become normal MCP server configs: \(servers)")
        case .failure(let error):
            XCTAssertEqual(error, .archiveReference)
        }
    }

    func testRegistryManifestWithRemoteAndMCPBReturnsBothChoices() throws {
        let choices = ImportParser.importChoices(from: """
        {
          "name": "io.github.example/hybrid-tools",
          "remotes": [
            { "type": "streamable-http", "url": "https://hybrid.example.com/mcp" }
          ],
          "packages": [
            {
              "registryType": "mcpb",
              "identifier": "https://github.com/example/hybrid-tools/releases/download/v1.0.0/hybrid-tools.mcpb",
              "fileSha256": "1234"
            }
          ]
        }
        """)

        XCTAssertEqual(choices.map(\.label), ["Registry HTTP remote", "Registry MCPB package"])
        XCTAssertEqual(choices[0].servers.first?.config["url"] as? String, "https://hybrid.example.com/mcp")
        XCTAssertNil(choices[0].archiveURL)
        XCTAssertEqual(choices[1].servers.count, 0)
        XCTAssertEqual(choices[1].archiveURL?.lastPathComponent, "hybrid-tools.mcpb")
        XCTAssertEqual(choices[1].archiveSHA256, "1234")
    }

    func testRegistryPackageWithHTTPTransportIsItsOwnChoice() throws {
        let choices = ImportParser.importChoices(from: """
        {
          "name": "ai.example/hybrid-container-mcp",
          "packages": [
            {
              "registryType": "oci",
              "identifier": "ghcr.io/example/hybrid-container-mcp:1.0.0",
              "transport": {
                "type": "streamable-http",
                "url": "https://{tenant}.example.com/mcp",
                "variables": {
                  "tenant": { "default": "team-a" }
                },
                "headers": [
                  { "name": "X-API-Key", "isRequired": true, "isSecret": true }
                ]
              }
            }
          ]
        }
        """)

        XCTAssertEqual(choices.count, 1)
        XCTAssertEqual(choices[0].label, "Registry Docker image")
        XCTAssertEqual(choices[0].source, "MCP Registry Docker image: ghcr.io/example/hybrid-container-mcp:1.0.0")
        XCTAssertEqual(choices[0].servers[0].config["type"] as? String, "http")
        XCTAssertEqual(choices[0].servers[0].config["url"] as? String, "https://team-a.example.com/mcp")
        XCTAssertEqual(choices[0].servers[0].config["headers"] as? [String: String], ["X-API-Key": "${X_API_KEY}"])
    }

    func testRegistryPackageHTTPTransportParsesScalarURLVariables() throws {
        let choices = ImportParser.importChoices(from: """
        {
          "name": "ai.example/hybrid-container-mcp",
          "packages": [
            {
              "registryType": "oci",
              "identifier": "ghcr.io/example/hybrid-container-mcp:1.0.0",
              "transport": {
                "type": "streamable-http",
                "url": "https://{region}.containers.example.com/mcp",
                "variables": {
                  "region": "us-east-1"
                }
              }
            }
          ]
        }
        """)

        XCTAssertEqual(choices.count, 1)
        XCTAssertEqual(choices[0].servers[0].config["type"] as? String, "http")
        XCTAssertEqual(
            choices[0].servers[0].config["url"] as? String,
            "https://us-east-1.containers.example.com/mcp"
        )
        XCTAssertFalse(choices[0].servers[0].credentialRequirements.contains {
            $0.kind == .urlVariable && $0.name == "region"
        })
    }

    private func onlyParsed(_ raw: String) throws -> ParsedServer {
        switch ImportParser.parse(raw) {
        case .success(let servers):
            XCTAssertEqual(servers.count, 1)
            return try XCTUnwrap(servers.first)
        case .failure(let error):
            XCTFail("Expected parse success, got \(error)")
            throw error
        }
    }
}
