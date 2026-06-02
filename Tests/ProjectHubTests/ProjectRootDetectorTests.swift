import XCTest
@testable import ProjectHub

final class ProjectRootDetectorTests: XCTestCase {
    func testDetectsGitWorktreeFileBoundaryFromNestedFolder() throws {
        let root = try makeTempDirectory().appendingPathComponent("worktree", isDirectory: true)
        let nested = root.appendingPathComponent("Sources/App", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "gitdir: /tmp/example/.git/worktrees/worktree\n"
            .write(to: root.appendingPathComponent(".git"), atomically: true, encoding: .utf8)

        XCTAssertEqual(ProjectRootDetector.detect(from: nested.path), root.path)
    }

    func testDetectsCodexConfiguredProjectFromSelectedSubdirectory() throws {
        let temp = try makeTempDirectory()
        let codexHome = temp.appendingPathComponent("codex-home", isDirectory: true)
        let project = temp.appendingPathComponent("Project With Spaces", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        try """
        [projects."\(project.path.replacingOccurrences(of: "\"", with: "\\\""))"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        let previous = getenv("CODEX_HOME").map { String(cString: $0) }
        setenv("CODEX_HOME", codexHome.path, 1)
        addTeardownBlock {
            if let previous {
                setenv("CODEX_HOME", previous, 1)
            } else {
                unsetenv("CODEX_HOME")
            }
        }

        XCTAssertEqual(ProjectRootDetector.detect(from: nested.path), project.path)
    }

    func testDetectsCodexConfiguredProjectFromQuotedRootProjectTable() throws {
        let temp = try makeTempDirectory()
        let codexHome = temp.appendingPathComponent("codex-home", isDirectory: true)
        let project = temp.appendingPathComponent("repo.with.dot", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        try """
        ["projects"."\(project.path.replacingOccurrences(of: "\"", with: "\\\""))"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        let previous = getenv("CODEX_HOME").map { String(cString: $0) }
        setenv("CODEX_HOME", codexHome.path, 1)
        addTeardownBlock {
            if let previous {
                setenv("CODEX_HOME", previous, 1)
            } else {
                unsetenv("CODEX_HOME")
            }
        }

        XCTAssertEqual(ProjectRootDetector.detect(from: nested.path), project.path)
    }

    func testParsesCodexProjectRootsFromBothProjectTableSpellings() throws {
        let temp = try makeTempDirectory()
        let standard = temp.appendingPathComponent("standard-repo", isDirectory: true)
        let quoted = temp.appendingPathComponent("repo.with.dot", isDirectory: true)
        try FileManager.default.createDirectory(at: standard, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: quoted, withIntermediateDirectories: true)

        let content = """
        [projects."\(standard.path.replacingOccurrences(of: "\"", with: "\\\""))"]
        trust_level = "trusted"

        ["projects"."\(quoted.path.replacingOccurrences(of: "\"", with: "\\\""))"]
        trust_level = "trusted"
        """

        XCTAssertEqual(
            ProjectRootDetector.codexProjectRootPaths(in: content),
            [canonicalFilePath(standard.path), canonicalFilePath(quoted.path)]
        )
    }

    func testDetectsClaudeSkillsOnlyFolderAsProjectRoot() throws {
        let temp = try makeTempDirectory()
        let codexHome = temp.appendingPathComponent("codex-home", isDirectory: true)
        let project = temp.appendingPathComponent("skills-only", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        let skill = project.appendingPathComponent(".claude/skills/deploy", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)

        withCodexHome(codexHome.path) {
            XCTAssertEqual(ProjectRootDetector.detect(from: nested.path), project.path)
        }
    }

    func testDetectsCodexSkillsOnlyFolderAsProjectRoot() throws {
        let temp = try makeTempDirectory()
        let codexHome = temp.appendingPathComponent("codex-home", isDirectory: true)
        let project = temp.appendingPathComponent("codex-skills-only", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        let skill = project.appendingPathComponent(".agents/skills/docs", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)

        withCodexHome(codexHome.path) {
            XCTAssertEqual(ProjectRootDetector.detect(from: nested.path), project.path)
        }
    }

    func testUsesContainingDirectoryWhenSelectedPathIsAFile() throws {
        let root = try makeTempDirectory().appendingPathComponent("repo", isDirectory: true)
        let nested = root.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        let file = nested.appendingPathComponent("main.swift")
        try "print(\"hello\")\n".write(to: file, atomically: true, encoding: .utf8)

        XCTAssertEqual(ProjectRootDetector.detect(from: file.path), root.path)
    }

    func testIgnoresBroadConfiguredProjectRoots() throws {
        let temp = try makeTempDirectory()
        let codexHome = temp.appendingPathComponent("codex-home", isDirectory: true)
        let project = temp.appendingPathComponent("repo", isDirectory: true)
        let nested = project.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try """
        [projects."/"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        let previous = getenv("CODEX_HOME").map { String(cString: $0) }
        setenv("CODEX_HOME", codexHome.path, 1)
        addTeardownBlock {
            if let previous {
                setenv("CODEX_HOME", previous, 1)
            } else {
                unsetenv("CODEX_HOME")
            }
        }

        XCTAssertEqual(ProjectRootDetector.detect(from: nested.path), project.path)
    }

    func testParentCodexTrustDoesNotMaskNestedGitProject() throws {
        let temp = try makeTempDirectory()
        let codexHome = temp.appendingPathComponent("codex-home", isDirectory: true)
        let workspace = temp.appendingPathComponent("workspace", isDirectory: true)
        let project = workspace.appendingPathComponent("nested-repo", isDirectory: true)
        let nested = project.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try """
        [projects."\(workspace.path.replacingOccurrences(of: "\"", with: "\\\""))"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        let previous = getenv("CODEX_HOME").map { String(cString: $0) }
        setenv("CODEX_HOME", codexHome.path, 1)
        addTeardownBlock {
            if let previous {
                setenv("CODEX_HOME", previous, 1)
            } else {
                unsetenv("CODEX_HOME")
            }
        }

        XCTAssertEqual(ProjectRootDetector.detect(from: nested.path), project.path)
    }

    func testDetectsCodexProjectRootMarkers() throws {
        let temp = try makeTempDirectory()
        let codexHome = temp.appendingPathComponent("codex-home", isDirectory: true)
        let project = temp.appendingPathComponent("marker-root", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "".write(to: project.appendingPathComponent("projecthub.toml"), atomically: true, encoding: .utf8)
        try """
        project_root_markers = ["projecthub.toml"]
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            XCTAssertEqual(ProjectRootDetector.detect(from: nested.path), project.path)
        }
    }

    func testIgnoresUnsafeCodexProjectRootMarkers() throws {
        let temp = try makeTempDirectory()
        let codexHome = temp.appendingPathComponent("codex-home", isDirectory: true)
        let project = temp.appendingPathComponent("marker-root", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "".write(to: temp.appendingPathComponent("shared.marker"), atomically: true, encoding: .utf8)
        try """
        project_root_markers = ["../shared.marker", "/tmp/shared.marker", ".", "safe.marker"]
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            XCTAssertEqual(ProjectRootDetector.detect(from: nested.path), nested.path)
        }
    }

    func testCodexProjectRootMarkersDoNotBeatNestedGitBoundary() throws {
        let temp = try makeTempDirectory()
        let codexHome = temp.appendingPathComponent("codex-home", isDirectory: true)
        let workspace = temp.appendingPathComponent("workspace", isDirectory: true)
        let project = workspace.appendingPathComponent("repo", isDirectory: true)
        let nested = project.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try "".write(to: workspace.appendingPathComponent("workspace.marker"), atomically: true, encoding: .utf8)
        try """
        project_root_markers = ["workspace.marker"]
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            XCTAssertEqual(ProjectRootDetector.detect(from: nested.path), project.path)
        }
    }

    func testDetectsClaudeConfiguredProjectFromJSONOverride() throws {
        let temp = try makeTempDirectory()
        let project = temp.appendingPathComponent("claude-project", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        let claudeJSON = temp.appendingPathComponent("isolated-claude.json")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try """
        {
          "projects": {
            "\(project.path)": {}
          }
        }
        """.write(to: claudeJSON, atomically: true, encoding: .utf8)

        withEnv("PROJECTHUB_CLAUDE_JSON_PATH", claudeJSON.path) {
            XCTAssertEqual(ProjectRootDetector.detect(from: nested.path), project.path)
        }
    }

    func testDetectsVSCodeProjectMCPMarker() throws {
        let project = try makeTempDirectory().appendingPathComponent("vscode-mcp-root", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let marker = project.appendingPathComponent(".vscode/mcp.json")
        try FileManager.default.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #"{"servers":{}}"#.write(to: marker, atomically: true, encoding: .utf8)

        XCTAssertEqual(ProjectRootDetector.detect(from: nested.path), project.path)
    }

    func testDetectsRooProjectMCPMarker() throws {
        let project = try makeTempDirectory().appendingPathComponent("roo-mcp-root", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let marker = project.appendingPathComponent(".roo/mcp.json")
        try FileManager.default.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #"{"mcpServers":{}}"#.write(to: marker, atomically: true, encoding: .utf8)

        XCTAssertEqual(ProjectRootDetector.detect(from: nested.path), project.path)
    }

    func testConfiguredProjectRootStillBeatsMarkerFallback() throws {
        let temp = try makeTempDirectory()
        let codexHome = temp.appendingPathComponent("codex-home", isDirectory: true)
        let workspace = temp.appendingPathComponent("workspace", isDirectory: true)
        let nestedProject = workspace.appendingPathComponent("nested", isDirectory: true)
        let selected = nestedProject.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: selected, withIntermediateDirectories: true)
        try "".write(to: nestedProject.appendingPathComponent("nested.marker"), atomically: true, encoding: .utf8)
        try """
        project_root_markers = ["nested.marker"]

        [projects."\(workspace.path.replacingOccurrences(of: "\"", with: "\\\""))"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            XCTAssertEqual(ProjectRootDetector.detect(from: selected.path), workspace.path)
        }
    }

    func testCodexProjectRootMarkersIgnoreBroadRootMatches() throws {
        let temp = try makeTempDirectory()
        let codexHome = temp.appendingPathComponent("codex-home", isDirectory: true)
        let selected = temp.appendingPathComponent("folder/subfolder", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: selected, withIntermediateDirectories: true)
        try """
        project_root_markers = ["Users"]
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            XCTAssertEqual(ProjectRootDetector.detect(from: selected.path), selected.path)
        }
    }

    func testMalformedCodexProjectRootMarkersFallBackToSelectedDirectory() throws {
        let temp = try makeTempDirectory()
        let codexHome = temp.appendingPathComponent("codex-home", isDirectory: true)
        let project = temp.appendingPathComponent("marker-root", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "".write(to: project.appendingPathComponent("projecthub.toml"), atomically: true, encoding: .utf8)
        try """
        project_root_markers = "projecthub.toml"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            XCTAssertEqual(ProjectRootDetector.detect(from: nested.path), nested.path)
        }
    }

    func testMixedTypeCodexProjectRootMarkersFallBackToSelectedDirectory() throws {
        let temp = try makeTempDirectory()
        let codexHome = temp.appendingPathComponent("codex-home", isDirectory: true)
        let project = temp.appendingPathComponent("marker-root", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "".write(to: project.appendingPathComponent("projecthub.toml"), atomically: true, encoding: .utf8)
        try """
        project_root_markers = ["projecthub.toml", 123]
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            XCTAssertEqual(ProjectRootDetector.detect(from: nested.path), nested.path)
        }
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

    private func canonicalFilePath(_ path: String) -> String {
        URL(fileURLWithPath: path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubProjectRootDetectorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
