import XCTest
@testable import ProjectHub

final class HooksReaderTests: XCTestCase {
    func testCodexHooksUseResolvedCodexHomeAndInlineConfigHooks() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ProjectHubHooks-\(UUID().uuidString)", isDirectory: true)
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try fm.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try fm.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try """
        {
          "hooks": {
            "Stop": [
              { "hooks": [{ "type": "command", "command": "/bin/echo json-global" }] }
            ]
          }
        }
        """.write(to: codexHome.appendingPathComponent("hooks.json"), atomically: true, encoding: .utf8)

        try """
        [[hooks.PreToolUse]]
        matcher = "^Bash$"

        [[hooks.PreToolUse.hooks]]
        type = "command"
        command = "/bin/echo toml-global"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let hooks = HooksReader.hooks(for: project.path).filter { $0.tool == "Codex" }
            XCTAssertTrue(hooks.contains {
                $0.event == "Stop" && $0.command == "/bin/echo json-global" && $0.scope == "global"
            })
            XCTAssertTrue(hooks.contains {
                $0.event == "PreToolUse"
                    && $0.matcher == "^Bash$"
                    && $0.command == "/bin/echo toml-global"
                    && $0.scope == "global"
            })
        }
    }

    func testCodexProjectHooksOnlyLoadWhenProjectIsTrusted() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ProjectHubProjectHooks-\(UUID().uuidString)", isDirectory: true)
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let projectCodex = project.appendingPathComponent(".codex", isDirectory: true)
        try fm.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try fm.createDirectory(at: projectCodex, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try """
        [[hooks.SessionStart]]
        [[hooks.SessionStart.hooks]]
        type = "command"
        command = "/bin/echo project-start"
        """.write(to: projectCodex.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            var hooks = HooksReader.hooks(for: project.path).filter { $0.tool == "Codex" }
            XCTAssertFalse(hooks.contains { $0.command == "/bin/echo project-start" })

            try """
            [projects.\(tomlString(project.path))]
            trust_level = "trusted"
            """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

            hooks = HooksReader.hooks(for: project.path).filter { $0.tool == "Codex" }
            XCTAssertTrue(hooks.contains {
                $0.event == "SessionStart"
                    && $0.command == "/bin/echo project-start"
                    && $0.scope == "project"
            })
        }
    }

    private func withCodexHome(_ path: String, run: () throws -> Void) rethrows {
        let key = "CODEX_HOME"
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

    private func tomlString(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}
