import XCTest
@testable import ProjectHub

final class ImportParserJSONTests: XCTestCase {
    func testHomebrewCommandStringIsSplitForOfficialMCPConfig() throws {
        let raw = """
        {
          "mcpServers": {
            "Homebrew": {
              "command": "brew mcp-server"
            }
          }
        }
        """

        let servers = try ImportParser.parse(raw).get()
        let server = try XCTUnwrap(servers.first { $0.name == "Homebrew" })

        XCTAssertEqual(server.config["command"] as? String, "brew")
        XCTAssertEqual(server.config["args"] as? [String], ["mcp-server"])
    }

    func testRustAndGoCommandStringsAreSplitForSourceMCPConfigs() throws {
        let raw = """
        {
          "mcpServers": {
            "crates": {
              "command": "cargo run --release",
              "cwd": "/path/to/crates-mcp"
            },
            "go-tools": {
              "command": "go run ./cmd/server"
            }
          }
        }
        """

        let servers = try ImportParser.parse(raw).get()
        let crates = try XCTUnwrap(servers.first { $0.name == "crates" })
        let goTools = try XCTUnwrap(servers.first { $0.name == "go-tools" })

        XCTAssertEqual(crates.config["command"] as? String, "cargo")
        XCTAssertEqual(crates.config["args"] as? [String], ["run", "--release"])
        XCTAssertEqual(goTools.config["command"] as? String, "go")
        XCTAssertEqual(goTools.config["args"] as? [String], ["run", "./cmd/server"])
    }

    func testDockerCommandArrayEnvFileIsPreservedAndNormalized() throws {
        let raw = """
        {
          "mcpServers": {
            "dockerized": {
              "command": ["docker", "run", "--env-file", ".env.mcp", "--env", "API_TOKEN", "ghcr.io/example/mcp:latest"]
            }
          }
        }
        """

        let servers = try ImportParser.parse(raw).get()
        let server = try XCTUnwrap(servers.first { $0.name == "dockerized" })

        XCTAssertEqual(server.config["command"] as? String, "docker")
        XCTAssertEqual(server.config["args"] as? [String], ["run", "--env-file", ".env.mcp", "--env", "API_TOKEN", "ghcr.io/example/mcp:latest"])
        XCTAssertEqual(server.config["envFile"] as? String, ".env.mcp")
        XCTAssertEqual((server.config["env"] as? [String: String])?["API_TOKEN"], "${API_TOKEN}")
    }

    func testEnvWrappedDockerCommandArrayIsUnwrappedAndPreservesMetadata() throws {
        let raw = """
        {
          "mcpServers": {
            "dockerized": {
              "command": ["/usr/bin/env", "API_TOKEN", "docker", "run", "--env-file", ".env.mcp", "--env", "SERVICE_TOKEN", "ghcr.io/example/mcp:latest"]
            }
          }
        }
        """

        let servers = try ImportParser.parse(raw).get()
        let server = try XCTUnwrap(servers.first { $0.name == "dockerized" })

        XCTAssertEqual(server.config["command"] as? String, "docker")
        XCTAssertEqual(server.config["args"] as? [String], ["run", "--env-file", ".env.mcp", "--env", "SERVICE_TOKEN", "ghcr.io/example/mcp:latest"])
        XCTAssertEqual(server.config["envFile"] as? String, ".env.mcp")
        XCTAssertEqual((server.config["env"] as? [String: String])?["API_TOKEN"], "${API_TOKEN}")
        XCTAssertEqual((server.config["env"] as? [String: String])?["SERVICE_TOKEN"], "${SERVICE_TOKEN}")
    }

    func testEnvWrappedCommandWithArgsIsUnwrapped() throws {
        let raw = """
        {
          "mcpServers": {
            "docs": {
              "command": "/usr/bin/env",
              "args": ["API_TOKEN=secret", "npx", "-y", "@example/docs"]
            }
          }
        }
        """

        let servers = try ImportParser.parse(raw).get()
        let server = try XCTUnwrap(servers.first { $0.name == "docs" })

        XCTAssertEqual(server.config["command"] as? String, "npx")
        XCTAssertEqual(server.config["args"] as? [String], ["-y", "@example/docs"])
        XCTAssertEqual(server.config["env"] as? [String: String], ["API_TOKEN": "secret"])
    }

    func testEnvSplitStringCommandWithArgsIsUnwrapped() throws {
        let raw = """
        {
          "mcpServers": {
            "docs": {
              "command": "/usr/bin/env",
              "args": ["-S", "API_TOKEN=secret npx -y @example/docs"]
            }
          }
        }
        """

        let servers = try ImportParser.parse(raw).get()
        let server = try XCTUnwrap(servers.first { $0.name == "docs" })

        XCTAssertEqual(server.config["command"] as? String, "npx")
        XCTAssertEqual(server.config["args"] as? [String], ["-y", "@example/docs"])
        XCTAssertEqual(server.config["env"] as? [String: String], ["API_TOKEN": "secret"])
    }

    func testDockerCommandWithArgsEnvFileIsPreservedAndNormalized() throws {
        let raw = """
        {
          "mcpServers": {
            "dockerized": {
              "command": "docker",
              "args": ["run", "--env-file=.env.local", "-eSERVICE_TOKEN", "ghcr.io/example/mcp:latest"]
            }
          }
        }
        """

        let servers = try ImportParser.parse(raw).get()
        let server = try XCTUnwrap(servers.first { $0.name == "dockerized" })

        XCTAssertEqual(server.config["command"] as? String, "docker")
        XCTAssertEqual(server.config["envFile"] as? String, ".env.local")
        XCTAssertEqual((server.config["env"] as? [String: String])?["SERVICE_TOKEN"], "${SERVICE_TOKEN}")
    }

    func testVSCodeEnvFileIsPreservedAndNormalized() throws {
        let raw = """
        {
          "inputs": [
            { "type": "promptString", "id": "token", "password": true }
          ],
          "servers": {
            "docs": {
              "command": "npx",
              "args": ["-y", "@example/docs"],
              "workingDirectory": "${workspaceFolder}/tools",
              "env_file": "${workspaceFolder}/.env",
              "sandbox_enabled": true,
              "always_allow": ["search"],
              "disabled_tools": ["write"],
              "watch_paths": ["src/server.ts"],
              "timeout": 120,
              "sandbox": {
                "filesystem": { "allowWrite": ["${workspaceFolder}"] },
                "network": { "allowedDomains": ["api.example.com"] }
              },
              "dev": {
                "watch": "src/**/*.ts",
                "debug": { "type": "node" }
              }
            }
          }
        }
        """

        let servers = try ImportParser.parse(raw).get()
        let server = try XCTUnwrap(servers.first { $0.name == "docs" })

        XCTAssertEqual(server.config["envFile"] as? String, "${workspaceFolder}/.env")
        XCTAssertEqual(server.config["cwd"] as? String, "${workspaceFolder}/tools")
        XCTAssertEqual(server.config["sandboxEnabled"] as? Bool, true)
        XCTAssertEqual(server.config["alwaysAllow"] as? [String], ["search"])
        XCTAssertEqual(server.config["disabledTools"] as? [String], ["write"])
        XCTAssertEqual(server.config["watchPaths"] as? [String], ["src/server.ts"])
        XCTAssertEqual(server.config["timeout"] as? Int, 120)
        XCTAssertNotNil(server.config["sandbox"] as? [String: Any])
        XCTAssertNotNil(server.config["dev"] as? [String: Any])
        XCTAssertNil(server.config["env_file"])
        XCTAssertNil(server.config["sandbox_enabled"])
        XCTAssertNil(server.config["always_allow"])
        XCTAssertNil(server.config["disabled_tools"])
        XCTAssertNil(server.config["watch_paths"])
        XCTAssertNil(server.config["workingDirectory"])
    }

    func testVSCodeInputsBecomeImportCredentialRequirements() throws {
        let raw = """
        {
          "inputs": [
            {
              "type": "promptString",
              "id": "token",
              "description": "API token",
              "password": true
            },
            {
              "type": "promptString",
              "id": "tenant",
              "description": "Tenant slug"
            }
          ],
          "servers": {
            "docs": {
              "url": "https://${input:tenant}.example.com/mcp",
              "type": "http",
              "headers": {
                "Authorization": "Bearer ${input:token}"
              },
              "env": {
                "API_TOKEN": "${input:token}",
                "LOG_LEVEL": "debug"
              }
            }
          }
        }
        """

        let servers = try ImportParser.parse(raw).get()
        let server = try XCTUnwrap(servers.first { $0.name == "docs" })

        XCTAssertTrue(server.credentialRequirements.contains {
            $0.kind == .env
                && $0.name == "API_TOKEN"
                && $0.placeholder == "${input:token}"
                && $0.secret
                && $0.description == "API token"
        })
        XCTAssertTrue(server.credentialRequirements.contains {
            $0.kind == .header
                && $0.name == "Authorization"
                && $0.placeholder == "${input:token}"
                && $0.secret
        })
        XCTAssertTrue(server.credentialRequirements.contains {
            $0.kind == .urlVariable
                && $0.name == "tenant"
                && $0.placeholder == "${input:tenant}"
                && !$0.secret
                && $0.description == "Tenant slug"
        })
        XCTAssertFalse(server.credentialRequirements.contains {
            $0.kind == .env && $0.name == "LOG_LEVEL"
        })
    }
}
