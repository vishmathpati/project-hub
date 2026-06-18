import XCTest
@testable import ProjectHub

final class CompatibilityContextSettingsTests: XCTestCase {
    func testDifferingClaudeAndAgentsInstructionsReportOneDivergence() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        let claudePath = project.appendingPathComponent("CLAUDE.md")
        let agentsPath = project.appendingPathComponent("AGENTS.md")
        try "# Claude project guidance\n".write(to: claudePath, atomically: true, encoding: .utf8)
        try "# Shared Codex guidance\n".write(to: agentsPath, atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let divergences = report.issues.filter { $0.code == .contextDiverged }

            XCTAssertEqual(divergences.count, 1)
            XCTAssertEqual(divergences.first?.path, claudePath.path)
            XCTAssertEqual(divergences.first?.subjectPath, agentsPath.path)
        }
    }

    func testIdenticalClaudeAndAgentsInstructionsDoNotReportDivergence() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        let shared = "# Shared project guidance\n"
        try shared.write(to: project.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try shared.write(to: project.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)

            XCTAssertFalse(report.issues.contains { $0.code == .contextDiverged })
        }
    }

    func testClaudeImportingAgentsInstructionsDoesNotReportDivergence() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        @AGENTS.md

        ## Claude Code
        Use plan mode for risky changes.
        """.write(to: project.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try "# Shared Codex guidance\n".write(to: project.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)

            XCTAssertFalse(report.issues.contains { $0.code == .contextDiverged })
        }
    }

    func testAgentsOverrideReportsActiveOverrideDivergenceWithoutBlamingInactiveAgents() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try "# Claude project guidance\n".write(to: project.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try "# Inactive AGENTS guidance\n".write(to: project.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)
        try "# Active override guidance\n".write(to: project.appendingPathComponent("AGENTS.override.md"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let divergences = report.issues.filter { $0.code == .contextDiverged }

            XCTAssertEqual(divergences.count, 1)
            XCTAssertEqual(divergences.first?.path, project.appendingPathComponent("CLAUDE.md").path)
            XCTAssertEqual(divergences.first?.subjectPath, project.appendingPathComponent("AGENTS.override.md").path)
            XCTAssertTrue(divergences.first?.detail.contains("AGENTS.override.md") == true)
            XCTAssertTrue(divergences.first?.fixHint?.contains("@AGENTS.override.md") == true)
            XCTAssertFalse(divergences.first?.detail.contains("Inactive AGENTS") == true)
        }
    }

    func testClaudeImportingAgentsOverrideDoesNotReportDivergence() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        @AGENTS.override.md

        ## Claude Code
        Use plan mode for risky changes.
        """.write(to: project.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try "# Inactive AGENTS guidance\n".write(to: project.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)
        try "# Active override guidance\n".write(to: project.appendingPathComponent("AGENTS.override.md"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)

            XCTAssertFalse(report.issues.contains { $0.code == .contextDiverged })
        }
    }

    func testProjectDocMaxBytesParsesCommentedTomlInteger() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        project_doc_max_bytes = 4_096 # intentionally small for test
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try String(repeating: "A", count: 5_000)
            .write(to: project.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        let previous = getenv("CODEX_HOME").map { String(cString: $0) }
        setenv("CODEX_HOME", codexHome.path, 1)
        addTeardownBlock {
            if let previous {
                setenv("CODEX_HOME", previous, 1)
            } else {
                unsetenv("CODEX_HOME")
            }
        }

        let report = CompatibilityScanner.scan(projectRoot: project.path)
        let oversized = report.issues.filter { $0.code == .contextTooLarge }

        XCTAssertFalse(oversized.isEmpty)
        XCTAssertTrue(oversized.contains { $0.detail.contains("above project_doc_max_bytes (4096)") })
    }

    func testInvalidProjectDocMaxBytesShapeIsReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        project_doc_max_bytes = "65536" # invalid because Codex expects an integer
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try "# Project guidance\n".write(to: project.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        let previous = getenv("CODEX_HOME").map { String(cString: $0) }
        setenv("CODEX_HOME", codexHome.path, 1)
        addTeardownBlock {
            if let previous {
                setenv("CODEX_HOME", previous, 1)
            } else {
                unsetenv("CODEX_HOME")
            }
        }

        let report = CompatibilityScanner.scan(projectRoot: project.path)
        let invalidLimit = report.issues.filter {
            $0.code == .configUnsupportedShape && $0.title == "Invalid Codex project_doc_max_bytes"
        }

        XCTAssertEqual(Set(invalidLimit.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
        XCTAssertTrue(invalidLimit.allSatisfy { $0.subjectPath == "project_doc_max_bytes" })
    }

    func testValidFallbackFilenameProvidesCodexProjectInstructions() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        project_doc_fallback_filenames = ["CLAUDE.md"]
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try "# Shared project guidance\n".write(to: project.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let fallbackPaths = Set(report.matrix.filter {
                ($0.toolID == .codexCLI || $0.toolID == .codexDesktop)
                    && $0.kind == .context
                    && $0.path == project.appendingPathComponent("CLAUDE.md").path
            }.map(\.toolID))

            XCTAssertEqual(fallbackPaths, [.codexCLI, .codexDesktop])
            XCTAssertFalse(report.issues.contains { $0.title == "Codex project instructions missing" })
        }
    }

    func testInvalidFallbackFilenamesAreReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        project_doc_fallback_filenames = ["CLAUDE.md", "../CLAUDE.md", "nested/AGENTS.md", "foo\\\\bar.md", ".", "..", ""]
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let invalidFallbacks = report.issues.filter {
                $0.code == .configUnsupportedShape && $0.title == "Invalid Codex fallback filenames"
            }

            XCTAssertEqual(Set(invalidFallbacks.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(invalidFallbacks.allSatisfy { $0.subjectPath == "project_doc_fallback_filenames" })
            XCTAssertTrue(report.matrix.contains {
                $0.toolID == .codexCLI
                    && $0.kind == .context
                    && $0.path == project.appendingPathComponent("CLAUDE.md").path
            })
            XCTAssertFalse(report.matrix.contains {
                $0.path == project.appendingPathComponent("nested/AGENTS.md").path
            })
        }
    }

    func testMalformedFallbackFilenameShapeIsReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        project_doc_fallback_filenames = "CLAUDE.md"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let invalidFallbacks = report.issues.filter {
                $0.code == .configUnsupportedShape && $0.title == "Invalid Codex fallback filenames"
            }

            XCTAssertEqual(Set(invalidFallbacks.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(invalidFallbacks.allSatisfy { $0.subjectPath == "project_doc_fallback_filenames" })
        }
    }

    func testTrustedProjectFallbackFilenameOverridesGlobalFallback() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".codex"), withIntermediateDirectories: true)

        try """
        project_doc_fallback_filenames = ["CLAUDE.md"]

        [projects."\(project.path)"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try """
        project_doc_fallback_filenames = ["PROJECT.md"]
        """.write(to: project.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)
        try "# Claude fallback\n".write(to: project.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try "# Project fallback\n".write(to: project.appendingPathComponent("PROJECT.md"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let codexContextPaths = Set(report.matrix.filter {
                $0.toolID == .codexCLI && $0.kind == .context
            }.compactMap(\.path))

            XCTAssertTrue(codexContextPaths.contains(project.appendingPathComponent("PROJECT.md").path))
            XCTAssertFalse(codexContextPaths.contains(project.appendingPathComponent("CLAUDE.md").path))
        }
    }

    func testUntrustedProjectFallbackDoesNotOverrideGlobalFallback() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".codex"), withIntermediateDirectories: true)

        try """
        project_doc_fallback_filenames = ["CLAUDE.md"]
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try """
        project_doc_fallback_filenames = ["PROJECT.md"]
        """.write(to: project.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)
        try "# Claude fallback\n".write(to: project.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try "# Project fallback\n".write(to: project.appendingPathComponent("PROJECT.md"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let codexContextPaths = Set(report.matrix.filter {
                $0.toolID == .codexCLI && $0.kind == .context
            }.compactMap(\.path))

            XCTAssertTrue(codexContextPaths.contains(project.appendingPathComponent("CLAUDE.md").path))
            XCTAssertFalse(codexContextPaths.contains(project.appendingPathComponent("PROJECT.md").path))
        }
    }

    func testNestedTrustedProjectFallbackUsesSelectedSubdirectoryLayer() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested.appendingPathComponent(".codex"), withIntermediateDirectories: true)

        try """
        [projects."\(project.path)"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try """
        project_doc_fallback_filenames = ["ROOT.md"]
        """.write(to: project.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)
        try """
        project_doc_fallback_filenames = ["FEATURE.md"]
        """.write(to: nested.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)
        try "# Root fallback\n".write(to: project.appendingPathComponent("ROOT.md"), atomically: true, encoding: .utf8)
        try "# Feature fallback\n".write(to: nested.appendingPathComponent("FEATURE.md"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: nested.path)
            let codexContextPaths = Set(report.matrix.filter {
                $0.toolID == .codexCLI && $0.kind == .context
            }.compactMap(\.path))

            XCTAssertTrue(codexContextPaths.contains(nested.appendingPathComponent("FEATURE.md").path))
            XCTAssertFalse(codexContextPaths.contains(project.appendingPathComponent("ROOT.md").path))
        }
    }

    func testTrustedProjectDocMaxBytesOverridesGlobalLimit() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".codex"), withIntermediateDirectories: true)

        try """
        project_doc_max_bytes = 4

        [projects."\(project.path)"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try """
        project_doc_max_bytes = 65536
        """.write(to: project.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)
        try String(repeating: "A", count: 5_000)
            .write(to: project.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)

            XCTAssertFalse(report.issues.contains { $0.code == .contextTooLarge })
        }
    }

    func testProjectDocMaxBytesZeroDisablesCodexProjectInstructions() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".codex"), withIntermediateDirectories: true)

        try """
        [projects."\(project.path)"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try """
        project_doc_max_bytes = 0
        """.write(to: project.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)
        try "# Project guidance\n".write(to: project.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let disabled = report.issues.filter {
                $0.code == .settingsSessionReloadRequired
                    && $0.title == "Codex project instructions disabled"
            }

            XCTAssertEqual(Set(disabled.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(disabled.allSatisfy { $0.path == project.appendingPathComponent("AGENTS.md").path })
            XCTAssertTrue(disabled.allSatisfy { $0.subjectPath == "project_doc_max_bytes" })
            XCTAssertTrue(disabled.allSatisfy {
                $0.metadata["codexProjectDocMaxBytesConfigPath"] == project.appendingPathComponent(".codex/config.toml").path
            })
            XCTAssertTrue(disabled.allSatisfy { $0.metadata["codexProjectDocMaxBytesScope"] == "project" })
            XCTAssertFalse(report.issues.contains {
                $0.code == .configUnsupportedShape
                    && $0.title == "Invalid Codex project_doc_max_bytes"
            })
        }
    }

    func testGlobalProjectDocMaxBytesZeroCarriesConfigSource() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        project_doc_max_bytes = 0
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try "# Project guidance\n".write(to: project.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let disabled = report.issues.filter {
                $0.code == .settingsSessionReloadRequired
                    && $0.title == "Codex project instructions disabled"
            }

            XCTAssertEqual(Set(disabled.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(disabled.allSatisfy {
                $0.metadata["codexProjectDocMaxBytesConfigPath"] == codexHome.appendingPathComponent("config.toml").path
            })
            XCTAssertTrue(disabled.allSatisfy { $0.metadata["codexProjectDocMaxBytesScope"] == "global" })
        }
    }

    func testModelInstructionsFileSurfacesResolveRelativeToConfigLayer() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested.appendingPathComponent(".codex"), withIntermediateDirectories: true)

        try """
        [projects."\(project.path)"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try """
        model_instructions_file = "root-instructions.md"
        """.write(to: project.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)
        try """
        model_instructions_file = "nested-instructions.md"
        """.write(to: nested.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)
        try "# Nested model instructions\n".write(to: nested.appendingPathComponent(".codex/nested-instructions.md"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: nested.path)
            let expected = nested.appendingPathComponent(".codex/nested-instructions.md").path
            let codexModelInstructionPaths = Set(report.matrix.filter {
                ($0.toolID == .codexCLI || $0.toolID == .codexDesktop)
                    && $0.kind == .context
                    && $0.label.contains("model instructions")
            }.compactMap(\.path))

            XCTAssertEqual(codexModelInstructionPaths, [expected])
        }
    }

    func testRuntimeProfileFileInstructionSettingsLayerForCLIOnly() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".git"), withIntermediateDirectories: true)

        try """
        project_doc_fallback_filenames = ["GLOBAL.md"]
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try """
        model_instructions_file = "profile-instructions.md"
        project_doc_fallback_filenames = ["PROFILE.md"]
        """.write(to: codexHome.appendingPathComponent("work.config.toml"), atomically: true, encoding: .utf8)
        try "# Profile model instructions\n".write(to: codexHome.appendingPathComponent("profile-instructions.md"), atomically: true, encoding: .utf8)
        try "# Profile fallback\n".write(to: project.appendingPathComponent("PROFILE.md"), atomically: true, encoding: .utf8)
        try "# Global fallback\n".write(to: project.appendingPathComponent("GLOBAL.md"), atomically: true, encoding: .utf8)

        try withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(
                projectRoot: project.path,
                codexProfileSelection: try XCTUnwrap(CodexProfileSelection.cliRuntimeOverride("work"))
            )
            let cliPaths = Set(report.matrix.filter {
                $0.toolID == .codexCLI && $0.kind == .context
            }.compactMap(\.path).map(canonicalFilePath))
            let desktopPaths = Set(report.matrix.filter {
                $0.toolID == .codexDesktop && $0.kind == .context
            }.compactMap(\.path).map(canonicalFilePath))
            let profileInstructions = canonicalFilePath(codexHome.appendingPathComponent("profile-instructions.md").path)
            let profileFallback = canonicalFilePath(project.appendingPathComponent("PROFILE.md").path)
            let globalFallback = canonicalFilePath(project.appendingPathComponent("GLOBAL.md").path)

            XCTAssertTrue(cliPaths.contains(profileInstructions))
            XCTAssertTrue(cliPaths.contains(profileFallback))
            XCTAssertFalse(cliPaths.contains(globalFallback))
            XCTAssertFalse(desktopPaths.contains(profileInstructions))
            XCTAssertFalse(desktopPaths.contains(profileFallback))
            XCTAssertTrue(desktopPaths.contains(globalFallback))
        }
    }

    func testMissingModelInstructionsFileIsReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        model_instructions_file = "missing-instructions.md"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let missing = report.issues.filter {
                $0.code == .configMissing && $0.title == "Codex model instructions file missing"
            }

            XCTAssertEqual(Set(missing.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(missing.allSatisfy {
                $0.path == codexHome.appendingPathComponent("missing-instructions.md").path
            })
            XCTAssertTrue(missing.allSatisfy { $0.subjectPath == "model_instructions_file" })
            XCTAssertTrue(missing.allSatisfy {
                $0.metadata["codexInstructionFileKey"] == "model_instructions_file"
            })
            XCTAssertTrue(missing.allSatisfy {
                $0.metadata["codexInstructionFileConfigPath"] == codexHome.appendingPathComponent("config.toml").path
            })
            XCTAssertTrue(missing.allSatisfy {
                $0.metadata["codexInstructionFileScope"] == "global"
            })
            XCTAssertTrue(missing.allSatisfy { $0.severity == .warning })
        }
    }

    func testProjectModelInstructionsFileMissingCarriesOwningConfig() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let projectCodex = project.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectCodex, withIntermediateDirectories: true)

        try """
        [projects."\(project.path)"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try """
        model_instructions_file = "missing-project-instructions.md"
        """.write(to: projectCodex.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let missing = report.issues.filter {
                $0.code == .configMissing && $0.title == "Codex model instructions file missing"
            }

            XCTAssertEqual(Set(missing.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(missing.allSatisfy {
                $0.path == projectCodex.appendingPathComponent("missing-project-instructions.md").path
            })
            XCTAssertTrue(missing.allSatisfy { $0.subjectPath == "model_instructions_file" })
            XCTAssertTrue(missing.allSatisfy {
                $0.metadata["codexInstructionFileConfigPath"] == projectCodex.appendingPathComponent("config.toml").path
            })
            XCTAssertTrue(missing.allSatisfy {
                $0.metadata["codexInstructionFileScope"] == "project"
            })
        }
    }

    func testMissingExperimentalInstructionsFileCarriesDeprecatedKey() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        experimental_instructions_file = "missing-legacy.md"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let missing = report.issues.filter {
                $0.code == .configMissing && $0.title == "Codex model instructions file missing"
            }

            XCTAssertEqual(Set(missing.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(missing.allSatisfy {
                $0.path == codexHome.appendingPathComponent("missing-legacy.md").path
            })
            XCTAssertTrue(missing.allSatisfy { $0.subjectPath == "experimental_instructions_file" })
            XCTAssertTrue(missing.allSatisfy {
                $0.metadata["codexInstructionFileKey"] == "experimental_instructions_file"
            })
            XCTAssertTrue(missing.allSatisfy {
                $0.metadata["codexInstructionFileConfigPath"] == codexHome.appendingPathComponent("config.toml").path
            })
        }
    }

    func testInvalidAndDeprecatedCodexInstructionFileSettingsAreReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        model_instructions_file = ["bad.md"]
        experimental_instructions_file = "legacy.md"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let invalid = report.issues.filter {
                $0.code == .configUnsupportedShape && $0.title == "Invalid Codex model_instructions_file"
            }
            let deprecated = report.issues.filter {
                $0.code == .settingsDeprecatedValue && $0.title == "Deprecated Codex experimental_instructions_file"
            }

            XCTAssertEqual(Set(invalid.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(invalid.allSatisfy { $0.subjectPath == "model_instructions_file" })
            XCTAssertEqual(Set(deprecated.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(deprecated.allSatisfy { $0.subjectPath == "experimental_instructions_file" })
        }
    }

    func testCodexProjectRootMarkersBoundInstructionSurfaces() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("marker-root", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        try """
        project_root_markers = ["projecthub.toml"]
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try "".write(to: project.appendingPathComponent("projecthub.toml"), atomically: true, encoding: .utf8)
        try "# Root Codex guidance\n".write(to: project.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: nested.path)
            XCTAssertTrue(report.matrix.contains {
                $0.toolID == .codexCLI
                    && $0.kind == .context
                    && $0.path == project.appendingPathComponent("AGENTS.md").path
            })
            XCTAssertTrue(report.matrix.contains {
                $0.toolID == .codexDesktop
                    && $0.kind == .context
                    && $0.path == project.appendingPathComponent("AGENTS.md").path
            })
        }
    }

    func testSelectedSubdirectoryIncludesNestedClaudeAndCodexInstructionSurfaces() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        try "# Root Claude guidance\n".write(to: project.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try "# Alternate Claude guidance\n".write(to: project.appendingPathComponent(".claude/CLAUDE.md"), atomically: true, encoding: .utf8)
        try "# Nested Claude local guidance\n".write(to: nested.appendingPathComponent("CLAUDE.local.md"), atomically: true, encoding: .utf8)
        try "# Nested Codex guidance\n".write(to: nested.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: nested.path)
            let contextPaths = Set(report.matrix
                .filter { $0.kind == .context }
                .compactMap(\.path))

            XCTAssertTrue(contextPaths.contains(project.appendingPathComponent("CLAUDE.md").path))
            XCTAssertTrue(contextPaths.contains(project.appendingPathComponent(".claude/CLAUDE.md").path))
            XCTAssertTrue(contextPaths.contains(nested.appendingPathComponent("CLAUDE.local.md").path))
            XCTAssertTrue(contextPaths.contains(nested.appendingPathComponent("AGENTS.md").path))
        }
    }

    func testNestedCodexOverrideWithoutSameDirectoryClaudeReportsMissingClaudeInstructions() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        let rootClaude = project.appendingPathComponent("CLAUDE.md")
        let nestedClaude = nested.appendingPathComponent("CLAUDE.md")
        let nestedOverride = nested.appendingPathComponent("AGENTS.override.md")
        try "# Root Claude guidance\n".write(to: rootClaude, atomically: true, encoding: .utf8)
        try "# Nested Codex override guidance\n".write(to: nestedOverride, atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: nested.path)
            let missing = report.issues.filter {
                $0.code == .configMissing && $0.title == "Claude project instructions missing"
            }

            XCTAssertEqual(missing.count, 1)
            XCTAssertEqual(missing.first?.path, nestedClaude.path)
            XCTAssertEqual(missing.first?.subjectPath, nestedOverride.path)
            XCTAssertTrue(missing.first?.detail.contains("same directory") == true)
        }
    }

    func testRootDotClaudeInstructionsParticipateInDivergence() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)

        let dotClaude = project.appendingPathComponent(".claude/CLAUDE.md")
        let agents = project.appendingPathComponent("AGENTS.md")
        try "# Alternate Claude guidance\n".write(to: dotClaude, atomically: true, encoding: .utf8)
        try "# Shared Codex guidance\n".write(to: agents, atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let divergence = report.issues.first { $0.code == .contextDiverged }

            XCTAssertEqual(divergence?.path, dotClaude.path)
            XCTAssertEqual(divergence?.subjectPath, agents.path)
        }
    }

    func testRootDotClaudeMatchingAgentsDoesNotReportDivergenceOrMissingClaude() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)

        let shared = "# Shared guidance\n"
        try shared.write(to: project.appendingPathComponent(".claude/CLAUDE.md"), atomically: true, encoding: .utf8)
        try shared.write(to: project.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)

            XCTAssertFalse(report.issues.contains { $0.code == .contextDiverged })
            XCTAssertFalse(report.issues.contains {
                $0.code == .configMissing && $0.title == "Claude project instructions missing"
            })
        }
    }

    func testClaudeProjectAndUserRulesAreDiscoveredAsContext() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let claudeHome = codexHome.appendingPathComponent("isolated-claude-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude/rules/api"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeHome.appendingPathComponent("rules"), withIntermediateDirectories: true)

        let projectRule = project.appendingPathComponent(".claude/rules/api/testing.md")
        let userRule = claudeHome.appendingPathComponent("rules/preferences.md")
        try """
        ---
        paths:
          - "Sources/**/*.swift"
        ---

        # API testing
        Use fixture-backed tests.
        """.write(to: projectRule, atomically: true, encoding: .utf8)
        try "# Personal workflow\nPrefer focused tests first.\n".write(to: userRule, atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let contextSettings = report.settings.filter { $0.toolID == .claudeCode }

            XCTAssertTrue(contextSettings.contains {
                canonicalFilePath($0.path) == canonicalFilePath(projectRule.path)
                    && $0.summary.contains("Path-scoped Claude rule")
                    && $0.keys.contains("paths: Sources/**/*.swift")
            })
            XCTAssertTrue(contextSettings.contains {
                canonicalFilePath($0.path) == canonicalFilePath(userRule.path)
                    && $0.scope == .global
                    && $0.summary.contains("Unconditional Claude rule")
            })
        }
    }

    func testClaudeMissingImportTargetIsReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude/rules"), withIntermediateDirectories: true)

        let claude = project.appendingPathComponent("CLAUDE.md")
        let missing = project.appendingPathComponent(".claude/rules/missing.md")
        try "See @.claude/rules/missing.md for more rules.\n".write(to: claude, atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let issue = report.issues.first {
                $0.code == .configMissing && $0.title == "Claude import target missing"
            }

            XCTAssertEqual(issue?.path, claude.path)
            XCTAssertEqual(issue?.subjectPath, missing.path)
        }
    }

    func testClaudeNestedImportsResolveRelativeToImporter() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let rules = project.appendingPathComponent(".claude/rules", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rules, withIntermediateDirectories: true)

        try "@.claude/rules/index.md\n".write(to: project.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try "@shared.md\n".write(to: rules.appendingPathComponent("index.md"), atomically: true, encoding: .utf8)
        try "# Shared rule\n".write(to: rules.appendingPathComponent("shared.md"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)

            XCTAssertFalse(report.issues.contains {
                $0.title == "Claude import target missing" || $0.title == "Claude import cycle"
            })
        }
    }

    func testClaudeRuleInvalidPathsAndImportCycleAreReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let rules = project.appendingPathComponent(".claude/rules", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rules, withIntermediateDirectories: true)

        let cyclic = rules.appendingPathComponent("cyclic.md")
        try """
        ---
        paths:
        ---

        @cyclic.md
        """.write(to: cyclic, atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)

            XCTAssertTrue(report.issues.contains {
                $0.code == .configUnsupportedShape
                    && $0.title == "Invalid Claude rule paths"
                    && $0.path.map(canonicalFilePath) == canonicalFilePath(cyclic.path)
            })
            XCTAssertTrue(report.issues.contains {
                $0.code == .configUnsupportedShape
                    && $0.title == "Claude import cycle"
                    && $0.subjectPath.map(canonicalFilePath) == canonicalFilePath(cyclic.path)
            })
        }
    }

    func testClaudeMdExcludesHideProjectClaudeAndRuleSurfaces() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let rules = project.appendingPathComponent(".claude/rules", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rules, withIntermediateDirectories: true)

        let claude = project.appendingPathComponent("CLAUDE.md")
        let rule = rules.appendingPathComponent("team.md")
        try "# Team guidance\n".write(to: claude, atomically: true, encoding: .utf8)
        try "# Team rule\n".write(to: rule, atomically: true, encoding: .utf8)
        try """
        {
          "claudeMdExcludes": [
            "\(project.path)/CLAUDE.md",
            "\(project.path)/.claude/rules/**"
          ]
        }
        """.write(to: project.appendingPathComponent(".claude/settings.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let contextPaths = Set(report.settings.filter { $0.toolID == .claudeCode }.map { canonicalFilePath($0.path) })

            XCTAssertFalse(contextPaths.contains(canonicalFilePath(claude.path)))
            XCTAssertFalse(contextPaths.contains(canonicalFilePath(rule.path)))
            XCTAssertTrue(report.settings.contains {
                $0.surfaceID == "claude-code-project-settings"
                    && $0.keys.contains("claudeMdExcludes")
            })
        }
    }

    func testClaudeAdditionalDirectoriesAddContextWhenMemoryEnvEnabled() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let shared = project.appendingPathComponent("shared-work", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: shared.appendingPathComponent(".claude/rules"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)

        let sharedClaude = shared.appendingPathComponent("CLAUDE.md")
        let sharedRule = shared.appendingPathComponent(".claude/rules/shared.md")
        try "# Shared Claude guidance\n".write(to: sharedClaude, atomically: true, encoding: .utf8)
        try "# Shared rule\n".write(to: sharedRule, atomically: true, encoding: .utf8)
        try """
        {
          "permissions": {
            "additionalDirectories": ["shared-work"]
          }
        }
        """.write(to: project.appendingPathComponent(".claude/settings.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            withAdditionalDirectoryMemoryEnv("1") {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let contextPaths = Set(report.settings.filter { $0.toolID == .claudeCode }.map { canonicalFilePath($0.path) })

                XCTAssertTrue(contextPaths.contains(canonicalFilePath(sharedClaude.path)))
                XCTAssertTrue(contextPaths.contains(canonicalFilePath(sharedRule.path)))
                XCTAssertFalse(report.issues.contains { $0.title == "Additional-directory Claude memory not enabled" })
            }
        }
    }

    func testClaudeAdditionalDirectoryContextIsNotSurfacedWithoutMemoryEnv() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let shared = project.appendingPathComponent("shared-work", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)

        let sharedClaude = shared.appendingPathComponent("CLAUDE.md")
        try "# Shared Claude guidance\n".write(to: sharedClaude, atomically: true, encoding: .utf8)
        try """
        {
          "permissions": {
            "additionalDirectories": ["shared-work"]
          }
        }
        """.write(to: project.appendingPathComponent(".claude/settings.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            withAdditionalDirectoryMemoryEnv(nil) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let contextPaths = Set(report.settings.filter { $0.toolID == .claudeCode }.map { canonicalFilePath($0.path) })

                XCTAssertFalse(contextPaths.contains(canonicalFilePath(sharedClaude.path)))
                XCTAssertTrue(report.issues.contains {
                    $0.code == .serverHealthUnknown
                        && $0.title == "Additional-directory Claude memory not enabled"
                        && $0.subjectPath == "permissions.additionalDirectories"
                })
            }
        }
    }

    func testClaudeLocalProjectStateAdditionalDirectoryIsRuntimeEvidence() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let claudeJSON = root.appendingPathComponent("claude.json")
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let shared = project.appendingPathComponent("shared-work", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: shared.appendingPathComponent(".claude/skills/runtime-skill"), withIntermediateDirectories: true)
        try "# Shared Claude guidance\n".write(to: shared.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try "# Runtime skill\n".write(to: shared.appendingPathComponent(".claude/skills/runtime-skill/SKILL.md"), atomically: true, encoding: .utf8)
        try """
        {
          "projects": {
            "\(project.path)": {
              "additionalDirectories": ["shared-work"]
            }
          }
        }
        """.write(to: claudeJSON, atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            withClaudeJSONPath(claudeJSON.path) {
                withAdditionalDirectoryMemoryEnv(nil) {
                    let report = CompatibilityScanner.scan(projectRoot: project.path)
                    let contextPaths = Set(report.settings.filter { $0.toolID == .claudeCode }.map { canonicalFilePath($0.path) })
                    let skillPaths = Set(report.skillSupport.filter { $0.toolID == .claudeCode }.flatMap(\.roots).map(canonicalFilePath))
                    let localState = report.settings.first { $0.surfaceID.hasPrefix("claude-code-local-project-state") }

                    XCTAssertEqual(localState?.fileControlled, false)
                    XCTAssertTrue(localState?.summary.contains("runtime additional directories") == true)
                    XCTAssertFalse(contextPaths.contains(canonicalFilePath(shared.appendingPathComponent("CLAUDE.md").path)))
                    XCTAssertTrue(skillPaths.contains(canonicalFilePath(shared.appendingPathComponent(".claude/skills").path)))
                    XCTAssertTrue(report.issues.contains {
                        $0.code == .serverHealthUnknown
                            && $0.title == "Additional-directory Claude memory not enabled"
                            && $0.subjectPath == "additionalDirectories"
                    })
                }
            }
        }
    }

    func testClaudeLocalProjectStateUsesCanonicalPathFallbackForRuntimeEvidence() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let claudeJSON = root.appendingPathComponent("claude.json")
        let realParent = root.appendingPathComponent("Real", isDirectory: true)
        let project = realParent.appendingPathComponent("repo", isDirectory: true)
        let aliasParent = root.appendingPathComponent("Alias", isDirectory: true)
        let aliasProject = aliasParent.appendingPathComponent("repo", isDirectory: true)
        let shared = project.appendingPathComponent("shared-work", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: aliasParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: aliasProject, withDestinationURL: project)
        try """
        {
          "projects": {
            "\(aliasProject.path)": {
              "additionalDirectories": ["shared-work"],
              "hasClaudeMdExternalIncludesApproved": true,
              "hasClaudeMdExternalIncludesWarningShown": true,
              "enabledMcpjsonServers": ["docs"],
              "disabledMcpjsonServers": ["old-docs"]
            }
          }
        }
        """.write(to: claudeJSON, atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            withClaudeJSONPath(claudeJSON.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let localState = report.settings.first { $0.surfaceID.hasPrefix("claude-code-local-project-state") }
                let skillRoots = Set(report.skillSupport.filter { $0.toolID == .claudeCode }.flatMap(\.roots).map(canonicalFilePath))

                XCTAssertTrue(localState?.summary.contains("runtime additional directories") == true)
                XCTAssertTrue(localState?.summary.contains("external import prompt state") == true)
                XCTAssertTrue(localState?.summary.contains("project MCP approval choices") == true)
                XCTAssertTrue(skillRoots.contains(canonicalFilePath(shared.appendingPathComponent(".claude/skills").path)))
            }
        }
    }

    func testClaudeLocalProjectStateHiddenRuntimeFieldsAreReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let claudeJSON = root.appendingPathComponent("claude.json")
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "projects": {
            "\(project.path)": {
              "hasTrustDialogAccepted": false,
              "ignorePatterns": ["secrets/**"],
              "dontCrawlDirectory": true,
              "lastSessionId": "session-123"
            }
          }
        }
        """.write(to: claudeJSON, atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            withClaudeJSONPath(claudeJSON.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let localState = report.settings.first { $0.surfaceID.hasPrefix("claude-code-local-project-state") }
                let localStateIssues = report.issues.filter { $0.surfaceID?.hasPrefix("claude-code-local-project-state") == true }

                XCTAssertTrue(localState?.summary.contains("trust prompt state") == true)
                XCTAssertTrue(localState?.summary.contains("deprecated ignore patterns") == true)
                XCTAssertTrue(localState?.summary.contains("directory crawl disabled") == true)
                XCTAssertTrue(localState?.summary.contains("session metrics") == true)
                XCTAssertTrue(localStateIssues.contains {
                    $0.code == .projectTrustRequired
                        && $0.title == "Claude project trust not accepted locally"
                        && $0.subjectPath == "hasTrustDialogAccepted"
                })
                XCTAssertTrue(localStateIssues.contains {
                    $0.code == .settingsDeprecatedValue
                        && $0.title == "Deprecated Claude ignorePatterns recorded"
                        && $0.subjectPath == "ignorePatterns"
                })
                XCTAssertTrue(localStateIssues.contains {
                    $0.code == .serverHealthUnknown
                        && $0.title == "Claude directory crawl disabled locally"
                        && $0.subjectPath == "dontCrawlDirectory"
                })
            }
        }
    }

    func testClaudeLocalProjectStatePolicyShapedFieldsAreReadOnlyEvidence() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let claudeJSON = root.appendingPathComponent("claude.json")
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try """
        {
          "projects": {
            "\(project.path)": {
              "allowedMcpServers": [
                { "serverName": "secret-server-name" }
              ],
              "deniedMcpServers": [
                { "serverName": "docs" }
              ],
              "allowManagedMcpServersOnly": true,
              "orgPolicySnapshot": {
                "policyId": "policy-secret-value"
              },
              "managedAccountControls": {
                "enterpriseMode": true
              }
            }
          }
        }
        """.write(to: claudeJSON, atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            withClaudeJSONPath(claudeJSON.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let localState = report.settings.first { $0.surfaceID.hasPrefix("claude-code-local-project-state") }
                let policyIssue = report.issues.first {
                    $0.code == .settingsManagedRequirement
                        && $0.surfaceID?.hasPrefix("claude-code-local-project-state") == true
                        && $0.title == "Claude local project state contains policy-shaped fields"
                }

                XCTAssertTrue(localState?.summary.contains("policy-shaped private state") == true)
                XCTAssertEqual(policyIssue?.severity, .info)
                XCTAssertTrue(policyIssue?.subjectPath?.contains("allowedMcpServers") == true)
                XCTAssertTrue(policyIssue?.subjectPath?.contains("deniedMcpServers") == true)
                XCTAssertTrue(policyIssue?.subjectPath?.contains("allowManagedMcpServersOnly") == true)
                XCTAssertTrue(policyIssue?.subjectPath?.contains("orgPolicySnapshot") == true)
                XCTAssertTrue(policyIssue?.subjectPath?.contains("managedAccountControls") == true)
                XCTAssertFalse(policyIssue?.detail.contains("secret-server-name") == true)
                XCTAssertFalse(policyIssue?.detail.contains("policy-secret-value") == true)
                XCTAssertFalse(report.issues.contains {
                    $0.surfaceID?.hasPrefix("claude-code-local-project-state") == true
                        && $0.title == "Claude MCP allowlist configured"
                })
                XCTAssertFalse(report.issues.contains {
                    $0.surfaceID?.hasPrefix("claude-code-local-project-state") == true
                        && $0.title == "Claude MCP denylist configured"
                })
                XCTAssertFalse(report.issues.contains {
                    $0.surfaceID?.hasPrefix("claude-code-local-project-state") == true
                        && $0.title == "Only managed Claude MCP allowlist applies"
                })
            }
        }
    }

    func testClaudeSettingsAdditionalDirectoryWinsOverRuntimeStateEvidence() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let claudeJSON = root.appendingPathComponent("claude.json")
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let shared = project.appendingPathComponent("shared-work", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        try "# Shared Claude guidance\n".write(to: shared.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try """
        {
          "permissions": {
            "additionalDirectories": ["shared-work"]
          }
        }
        """.write(to: project.appendingPathComponent(".claude/settings.json"), atomically: true, encoding: .utf8)
        try """
        {
          "projects": {
            "\(project.path)": {
              "additionalDirectories": ["shared-work"]
            }
          }
        }
        """.write(to: claudeJSON, atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            withClaudeJSONPath(claudeJSON.path) {
                withAdditionalDirectoryMemoryEnv("1") {
                    let report = CompatibilityScanner.scan(projectRoot: project.path)
                    let sharedContextSurfaces = report.matrix.filter {
                        $0.toolID == .claudeCode
                            && $0.kind == .context
                            && $0.path == shared.appendingPathComponent("CLAUDE.md").path
                    }

                    XCTAssertEqual(sharedContextSurfaces.count, 1)
                    XCTAssertTrue(sharedContextSurfaces.first?.note.contains("Source: Claude Code project settings") == true)
                }
            }
        }
    }

    func testClaudeExternalImportApprovalStateIsUnknownAndNotReadRecursively() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let external = root.appendingPathComponent("outside/shared.md")
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: external.deletingLastPathComponent(), withIntermediateDirectories: true)

        try "See @\(external.path)\n".write(to: project.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try "External guidance imports @missing.md\n".write(to: external, atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)

            XCTAssertTrue(report.issues.contains {
                $0.code == .contextExternalImportApprovalUnknown
                    && $0.title == "Claude external import approval unknown"
                    && $0.subjectPath.map(canonicalFilePath) == canonicalFilePath(external.path)
            })
            XCTAssertFalse(report.issues.contains {
                $0.title == "Claude import target missing"
                    && $0.subjectPath?.hasSuffix("missing.md") == true
            })
        }
    }

    func testClaudeExternalImportLocalApprovalEvidenceIsReportedButNotReadRecursively() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let claudeJSON = root.appendingPathComponent("claude.json")
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let external = root.appendingPathComponent("outside/shared.md")
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: external.deletingLastPathComponent(), withIntermediateDirectories: true)

        try "See @\(external.path)\n".write(to: project.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try "External guidance imports @missing.md\n".write(to: external, atomically: true, encoding: .utf8)
        try """
        {
          "projects": {
            "\(project.path)": {
              "hasClaudeMdExternalIncludesApproved": true,
              "hasClaudeMdExternalIncludesWarningShown": true
            }
          }
        }
        """.write(to: claudeJSON, atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            withClaudeJSONPath(claudeJSON.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)

                XCTAssertTrue(report.issues.contains {
                    $0.code == .contextExternalImportApprovalUnknown
                        && $0.title == "Claude external import approval recorded locally"
                        && $0.subjectPath.map(canonicalFilePath) == canonicalFilePath(external.path)
                })
                XCTAssertFalse(report.issues.contains {
                    $0.title == "Claude import target missing"
                        && $0.subjectPath?.hasSuffix("missing.md") == true
                })
            }
        }
    }

    func testClaudeInstructionsLoadedHookIsReportedAsRuntimeVisibility() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let claudeDir = project.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        try """
        {
          "hooks": {
            "InstructionsLoaded": [
              {
                "hooks": [
                  {
                    "type": "command",
                    "command": "echo loaded"
                  }
                ]
              }
            ]
          }
        }
        """.write(to: claudeDir.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)

            XCTAssertTrue(report.issues.contains {
                $0.code == .serverHealthUnknown
                    && $0.title == "Claude InstructionsLoaded hook configured"
                    && $0.subjectPath == "hooks.InstructionsLoaded"
            })
            XCTAssertTrue(report.settings.contains {
                $0.surfaceID == "claude-code-project-settings"
                    && $0.keys.contains("hooks")
            })
        }
    }

    func testConfiguredFallbackInstructionReportsDivergenceAndImportTarget() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        project_doc_fallback_filenames = ["CONTRIBUTING.md"]
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try "# Claude project guidance\n".write(to: project.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try "# Shared fallback guidance\n".write(to: project.appendingPathComponent("CONTRIBUTING.md"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let divergence = report.issues.first { $0.code == .contextDiverged }

            XCTAssertEqual(divergence?.path, project.appendingPathComponent("CLAUDE.md").path)
            XCTAssertEqual(divergence?.subjectPath, project.appendingPathComponent("CONTRIBUTING.md").path)
            XCTAssertTrue(divergence?.fixHint?.contains("@CONTRIBUTING.md") == true)
        }
    }

    func testInvalidProjectRootMarkersAreReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "".write(to: project.appendingPathComponent("projecthub.toml"), atomically: true, encoding: .utf8)

        try """
        project_root_markers = ["projecthub.toml", "../shared.marker", "/tmp/project.marker", "foo\\\\bar", ".", "..", ""]
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: nested.path)
            let invalidMarkers = report.issues.filter {
                $0.code == .configUnsupportedShape && $0.title == "Invalid Codex project root markers"
            }

            XCTAssertEqual(Set(invalidMarkers.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(invalidMarkers.allSatisfy { $0.subjectPath == "project_root_markers" })
            XCTAssertTrue(report.matrix.contains {
                $0.toolID == .codexCLI
                    && $0.kind == .context
                    && $0.path == project.appendingPathComponent("AGENTS.md").path
            })
        }
    }

    func testMixedTypeProjectRootMarkersShapeIsReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "".write(to: project.appendingPathComponent("projecthub.toml"), atomically: true, encoding: .utf8)

        try """
        project_root_markers = ["projecthub.toml", 123]
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: nested.path)
            let invalidMarkers = report.issues.filter {
                $0.code == .configUnsupportedShape && $0.title == "Invalid Codex project root markers"
            }

            XCTAssertEqual(Set(invalidMarkers.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(invalidMarkers.allSatisfy { $0.subjectPath == "project_root_markers" })
            XCTAssertFalse(report.matrix.contains {
                $0.path == project.appendingPathComponent("AGENTS.md").path
            })
        }
    }

    func testMalformedProjectRootMarkersShapeIsReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        project_root_markers = "projecthub.toml"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let invalidMarkers = report.issues.filter {
                $0.code == .configUnsupportedShape && $0.title == "Invalid Codex project root markers"
            }

            XCTAssertEqual(Set(invalidMarkers.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(invalidMarkers.allSatisfy { $0.subjectPath == "project_root_markers" })
        }
    }

    func testInvalidCodexEnumSettingsAreReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        model_reasoning_effort = "extreme"
        model_reasoning_summary = true
        model_verbosity = "chatty"
        oss_provider = "vllm"
        approvals_reviewer = "nobody"

        [profiles.fast]
        sandbox_mode = "loose"
        approval_policy = "auto"
        model_reasoning_effort = "none"

        [projects."\(project.path)"]
        trust_level = "maybe"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let invalid = report.issues.filter {
                $0.code == .configUnsupportedShape
                    && $0.title.hasPrefix("Invalid Codex ")
            }
            let subjectPaths = Set(invalid.compactMap(\.subjectPath))

            XCTAssertEqual(Set(invalid.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(subjectPaths.contains("model_reasoning_effort"))
            XCTAssertTrue(subjectPaths.contains("model_reasoning_summary"))
            XCTAssertTrue(subjectPaths.contains("model_verbosity"))
            XCTAssertTrue(subjectPaths.contains("oss_provider"))
            XCTAssertTrue(subjectPaths.contains("approvals_reviewer"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.sandbox_mode"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.approval_policy"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.model_reasoning_effort"))
            XCTAssertTrue(subjectPaths.contains("projects.\"\(project.path)\".trust_level"))
        }
    }

    func testCodexQuotedRootProjectSectionTrustIsReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo.with.dot", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        ["projects"."\(project.path)"]
        trust_level = "maybe"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let invalid = report.issues.filter {
                $0.code == .configUnsupportedShape
                    && $0.title == "Invalid Codex trust_level"
            }

            XCTAssertEqual(Set(invalid.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(invalid.contains {
                $0.subjectPath == "\"projects\".\"\(project.path)\".trust_level"
            })
        }
    }

    func testCodexProjectConfigReportsIgnoredParentSections() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let codexProject = project.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexProject, withIntermediateDirectories: true)

        try """
        [projects."\(project.path)"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        try """
        apps_mcp_product_sku = "team"
        model_provider = "local"
        otel = "enabled"

        [profiles]
        default = "fast"

        [model_providers]
        default = "local"

        [otel]
        exporter = "otlp"
        """.write(to: codexProject.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let ignored = report.issues.filter {
                $0.code == .projectSettingsIgnored
                    && $0.title == "Codex project settings ignored"
            }
            let details = ignored.map(\.detail).joined(separator: "\n")

            XCTAssertEqual(Set(ignored.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(details.contains("apps_mcp_product_sku"))
            XCTAssertTrue(details.contains("model_provider"))
            XCTAssertTrue(details.contains("otel"))
            XCTAssertTrue(details.contains("profiles"))
            XCTAssertTrue(details.contains("model_providers"))
        }
    }

    func testNestedCodexProjectConfigLayerReportsIgnoredSettings() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested.appendingPathComponent(".codex"), withIntermediateDirectories: true)

        try """
        [projects."\(project.path)"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        try """
        [profiles]
        default = "fast"
        """.write(to: nested.appendingPathComponent(".codex/config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: nested.path)
            let nestedPath = nested.appendingPathComponent(".codex/config.toml").path
            let ignored = report.issues.filter {
                $0.code == .projectSettingsIgnored
                    && $0.path == nestedPath
            }

            XCTAssertEqual(report.projectRoot, project.path)
            XCTAssertEqual(Set(ignored.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(ignored.allSatisfy { $0.detail.contains("profiles") })
        }
    }

    func testCodexProjectConfigWithoutTrustedProjectEntryReportsTrustRequired() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let codexProject = project.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexProject, withIntermediateDirectories: true)

        try """
        model = "gpt-5-codex"
        """.write(to: codexProject.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let trust = report.issues.filter { $0.code == .projectTrustRequired }

            XCTAssertEqual(Set(trust.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(trust.allSatisfy { $0.state == .unknown })
        }
    }

    func testTrustedCodexProjectConfigDoesNotReportTrustRequired() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let codexProject = project.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexProject, withIntermediateDirectories: true)

        try """
        [projects."\(project.path)"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        try """
        model = "gpt-5-codex"
        """.write(to: codexProject.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)

            XCTAssertFalse(report.issues.contains { $0.code == .projectTrustRequired })
        }
    }

    func testMalformedTopLevelCodexApprovalAndSandboxShapesAreReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        approval_policy = []
        sandbox_mode = true
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let invalidApproval = report.issues.filter {
                $0.code == .configUnsupportedShape
                    && $0.title == "Invalid Codex approval_policy"
            }
            let invalidSandbox = report.issues.filter {
                $0.code == .configUnsupportedShape
                    && $0.title == "Invalid Codex sandbox_mode"
            }

            XCTAssertEqual(Set(invalidApproval.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(invalidApproval.allSatisfy { $0.subjectPath == "approval_policy" })
            XCTAssertEqual(Set(invalidSandbox.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(invalidSandbox.allSatisfy { $0.subjectPath == "sandbox_mode" })
        }
    }

    func testInvalidCodexStructuredSecuritySettingsAreReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        approval_policy = { granular = { sandbox_approval = "yes", rules = true, unknown_prompt = false } }
        approval_policy.granular.mcp_elicitations = "prompt"
        sandbox_workspace_write.network_access = "yes"
        sandbox_workspace_write.writable_roots = ["/tmp/shared", 123]
        sandbox_workspace_write.extra = true

        [approval_policy.granular]
        request_permissions = "sometimes"

        [sandbox_workspace_write]
        exclude_slash_tmp = "no"
        exclude_tmpdir_env_var = true
        writable_roots = ["/tmp/also-ok", false]

        [profiles.fast]
        approval_policy = { granular = { skill_approval = "ask" } }
        sandbox_workspace_write = { network_access = "ask", stale = true }
        sandbox_workspace_write.exclude_slash_tmp = "sometimes"

        [profiles.fast.sandbox_workspace_write]
        writable_roots = ["/tmp/profile-ok", 42]
        extra_profile = true
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let invalid = report.issues.filter { $0.code == .configUnsupportedShape }
            let subjectPaths = Set(invalid.compactMap(\.subjectPath))

            XCTAssertEqual(Set(invalid.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(subjectPaths.contains("approval_policy.granular.sandbox_approval"))
            XCTAssertTrue(subjectPaths.contains("approval_policy.granular.unknown_prompt"))
            XCTAssertTrue(subjectPaths.contains("approval_policy.granular.mcp_elicitations"))
            XCTAssertTrue(subjectPaths.contains("approval_policy.granular.request_permissions"))
            XCTAssertTrue(subjectPaths.contains("sandbox_workspace_write.network_access"))
            XCTAssertTrue(subjectPaths.contains("sandbox_workspace_write.writable_roots"))
            XCTAssertTrue(subjectPaths.contains("sandbox_workspace_write.extra"))
            XCTAssertTrue(subjectPaths.contains("sandbox_workspace_write.exclude_slash_tmp"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.approval_policy.granular.skill_approval"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.sandbox_workspace_write.network_access"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.sandbox_workspace_write.stale"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.sandbox_workspace_write.exclude_slash_tmp"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.sandbox_workspace_write.writable_roots"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.sandbox_workspace_write.extra_profile"))
        }
    }

    func testInlineSandboxWorkspaceWriteAndProfileGranularSectionsAreReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        sandbox_workspace_write = { network_access = "yes", writable_roots = ["/tmp/shared", 123], stale = true }

        [profiles.fast.approval_policy.granular]
        skill_approval = "ask"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let invalid = report.issues.filter { $0.code == .configUnsupportedShape }
            let subjectPaths = Set(invalid.compactMap(\.subjectPath))

            XCTAssertEqual(Set(invalid.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(subjectPaths.contains("sandbox_workspace_write.network_access"))
            XCTAssertTrue(subjectPaths.contains("sandbox_workspace_write.writable_roots"))
            XCTAssertTrue(subjectPaths.contains("sandbox_workspace_write.stale"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.approval_policy.granular.skill_approval"))
        }
    }

    func testMalformedSandboxWorkspaceWriteScalarIsReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        sandbox_workspace_write = true
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let invalidSandbox = report.issues.filter {
                $0.code == .configUnsupportedShape
                    && $0.title == "Invalid Codex sandbox_workspace_write"
            }

            XCTAssertEqual(Set(invalidSandbox.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(invalidSandbox.allSatisfy { $0.subjectPath == "sandbox_workspace_write" })
        }
    }

    func testValidCodexStructuredSecuritySettingsAreNotReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        approval_policy = { granular = { sandbox_approval = true, rules = false } }
        approval_policy.granular.mcp_elicitations = true
        sandbox_workspace_write.network_access = true
        sandbox_workspace_write.writable_roots = ["/tmp/shared", "/Users/example/project"]

        [approval_policy.granular]
        request_permissions = true
        skill_approval = false

        [sandbox_workspace_write]
        exclude_slash_tmp = false
        exclude_tmpdir_env_var = true

        [profiles.fast]
        approval_policy = { granular = { skill_approval = true } }
        sandbox_workspace_write = { network_access = true, writable_roots = ["/tmp/profile-inline"] }

        [profiles.slow.sandbox_workspace_write]
        exclude_slash_tmp = true
        exclude_tmpdir_env_var = false
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let structuredIssues = report.issues.filter {
                $0.code == .configUnsupportedShape
                    && ($0.subjectPath?.contains("approval_policy.granular") == true
                        || $0.subjectPath?.contains("sandbox_workspace_write") == true)
            }

            XCTAssertTrue(
                structuredIssues.isEmpty,
                structuredIssues.map { "\($0.title): \($0.subjectPath ?? "nil") - \($0.detail)" }.joined(separator: "\n")
            )
        }
    }

    func testValidInlineSandboxWorkspaceWriteIsNotReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        sandbox_workspace_write = { exclude_slash_tmp = false, network_access = true, writable_roots = ["/tmp/inline"] }
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)

            XCTAssertFalse(report.issues.contains {
                $0.code == .configUnsupportedShape
                    && $0.subjectPath?.contains("sandbox_workspace_write") == true
            })
        }
    }

    func testInvalidCodexWebAndNetworkSettingsAreReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        web_search = "online"
        tools.web_search = "yes"
        tools.web_search.context_size = "giant"
        tools.web_search.allowed_domains = ["example.com", 123]
        tools.web_search.extra = true
        features.web_search = "yes"
        features.network_proxy = "enabled"
        features.network_proxy.enabled = "yes"
        features.network_proxy.mode = "open"
        features.network_proxy.extra = true
        features.network_proxy.domains."*.example.com" = "maybe"

        [features.network_proxy.domains]
        "blocked.example.com" = "maybe"

        [profiles.fast]
        web_search = "fresh"

        [tools.web_search.location]
        country = 123
        planet = "Mars"

        [features.network_proxy.unix_sockets]
        "/tmp/codex.sock" = "deny"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let invalid = report.issues.filter { $0.code == .configUnsupportedShape }
            let subjectPaths = Set(invalid.compactMap(\.subjectPath))

            XCTAssertEqual(Set(invalid.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(subjectPaths.contains("web_search"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.web_search"))
            XCTAssertTrue(subjectPaths.contains("tools.web_search"))
            XCTAssertTrue(subjectPaths.contains("tools.web_search.context_size"))
            XCTAssertTrue(subjectPaths.contains("tools.web_search.allowed_domains"))
            XCTAssertTrue(subjectPaths.contains("tools.web_search.extra"))
            XCTAssertTrue(subjectPaths.contains("tools.web_search.location.country"))
            XCTAssertTrue(subjectPaths.contains("tools.web_search.location.planet"))
            XCTAssertTrue(subjectPaths.contains("features.web_search"))
            XCTAssertTrue(subjectPaths.contains("features.network_proxy"))
            XCTAssertTrue(subjectPaths.contains("features.network_proxy.enabled"))
            XCTAssertTrue(subjectPaths.contains("features.network_proxy.mode"))
            XCTAssertTrue(subjectPaths.contains("features.network_proxy.extra"))
            XCTAssertTrue(subjectPaths.contains { $0.contains("features.network_proxy.domains.") && $0.contains("example.com") })
            XCTAssertTrue(subjectPaths.contains("features.network_proxy.unix_sockets./tmp/codex.sock"))
            XCTAssertTrue(invalid.contains {
                $0.title == "Invalid Codex network proxy domain rule"
                    && $0.subjectPath == "features.network_proxy.domains.blocked.example.com"
            })
            XCTAssertTrue(invalid.contains {
                $0.title == "Invalid Codex network proxy Unix socket rule"
                    && $0.subjectPath == "features.network_proxy.unix_sockets./tmp/codex.sock"
            })
        }
    }

    func testInlineCodexWebAndNetworkUnknownKeysAreReportedAtTopLevelAndProfile() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        tools.web_search = { context_size = "high", extra = true }
        features.network_proxy = { enabled = true, stale = false }

        [profiles.fast]
        tools.web_search = { context_size = "low", surprise = true }
        features.network_proxy = { enabled = true, legacy = true }
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let invalid = report.issues.filter { $0.code == .configUnsupportedShape }
            let subjectPaths = Set(invalid.compactMap(\.subjectPath))

            XCTAssertEqual(Set(invalid.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(subjectPaths.contains("tools.web_search.extra"))
            XCTAssertTrue(subjectPaths.contains("features.network_proxy.stale"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.tools.web_search.surprise"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.features.network_proxy.legacy"))
        }
    }

    func testMalformedDirectCodexWebAndNetworkValuesAreReportedInExactAndProfileParentSections() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        [tools]
        web_search = "yes"

        [features]
        network_proxy = "enabled"

        [profiles.fast]
        tools.web_search = "yes"
        features.network_proxy = "enabled"

        [profiles.fast.tools]
        web_search = "yes"

        [profiles.fast.features]
        network_proxy = "enabled"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let invalid = report.issues.filter { $0.code == .configUnsupportedShape }
            let titlesBySubject = Dictionary(grouping: invalid, by: { $0.subjectPath ?? "" })
                .mapValues { Set($0.map(\.title)) }

            XCTAssertEqual(Set(invalid.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(titlesBySubject["tools.web_search"]?.contains("Invalid Codex tools.web_search") == true)
            XCTAssertTrue(titlesBySubject["features.network_proxy"]?.contains("Invalid Codex features.network_proxy") == true)
            XCTAssertTrue(titlesBySubject["profiles.fast.tools.web_search"]?.contains("Invalid Codex tools.web_search") == true)
            XCTAssertTrue(titlesBySubject["profiles.fast.features.network_proxy"]?.contains("Invalid Codex features.network_proxy") == true)
        }
    }

    func testValidCodexWebAndNetworkSettingsAreNotReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        web_search = "live"
        tools.web_search = { context_size = "high", allowed_domains = ["example.com"], location = { country = "US", timezone = "America/New_York" } }
        features.web_search = true
        features.network_proxy = { enabled = true, mode = "limited", proxy_url = "http://127.0.0.1:1234", domains = { "*.example.com" = "allow" }, unix_sockets = { "/tmp/codex.sock" = "none" } }

        [profiles.fast]
        web_search = "cached"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let webNetworkIssues = report.issues.filter {
                $0.code == .configUnsupportedShape
                    && ($0.subjectPath?.contains("web_search") == true
                        || $0.subjectPath?.contains("network_proxy") == true)
            }

            XCTAssertTrue(
                webNetworkIssues.isEmpty,
                webNetworkIssues.map { "\($0.title): \($0.subjectPath ?? "nil") - \($0.detail)" }.joined(separator: "\n")
            )
        }
    }

    func testValidCodexWebAndNetworkSectionSettingsAreNotReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        [tools.web_search]
        context_size = "medium"
        allowed_domains = ["example.com", "docs.example.com"]

        [tools.web_search.location]
        country = "US"
        region = "CA"
        city = "San Francisco"
        timezone = "America/Los_Angeles"

        [features.network_proxy]
        enabled = true
        mode = "full"
        allow_local_binding = false
        proxy_url = "http://127.0.0.1:1234"
        socks_url = "socks5://127.0.0.1:1080"

        [features.network_proxy.domains]
        "*.example.com" = "allow"
        "blocked.example.com" = "deny"

        [features.network_proxy.unix_sockets]
        "/tmp/codex.sock" = "allow"
        "/tmp/old.sock" = "none"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let webNetworkIssues = report.issues.filter {
                $0.code == .configUnsupportedShape
                    && ($0.subjectPath?.contains("web_search") == true
                        || $0.subjectPath?.contains("network_proxy") == true)
            }

            XCTAssertTrue(
                webNetworkIssues.isEmpty,
                webNetworkIssues.map { "\($0.title): \($0.subjectPath ?? "nil") - \($0.detail)" }.joined(separator: "\n")
            )
        }
    }

    func testProfileScopedCodexWebAndNetworkSettingsAreReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        [profiles.fast.tools]
        web_search = "yes"

        [profiles.fast.tools.web_search]
        context_size = "giant"
        surprise = true

        [profiles.fast.tools.web_search.location]
        timezone = true
        planet = "Mars"

        [profiles.fast.features.network_proxy]
        enabled = "yes"
        mode = "open"
        surprise = true

        [profiles.fast.features.network_proxy.domains]
        "*.example.com" = "maybe"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let invalid = report.issues.filter { $0.code == .configUnsupportedShape }
            let subjectPaths = Set(invalid.compactMap(\.subjectPath))

            XCTAssertEqual(Set(invalid.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(subjectPaths.contains("profiles.fast.tools.web_search"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.tools.web_search.context_size"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.tools.web_search.surprise"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.tools.web_search.location.timezone"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.tools.web_search.location.planet"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.features.network_proxy.enabled"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.features.network_proxy.mode"))
            XCTAssertTrue(subjectPaths.contains("profiles.fast.features.network_proxy.surprise"))
            XCTAssertTrue(subjectPaths.contains { $0.contains("profiles.fast.features.network_proxy.domains.") && $0.contains("example.com") })
        }
    }

    func testValidProfileScopedCodexWebAndNetworkSettingsAreNotReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        [profiles.fast.tools]
        web_search = { context_size = "low", allowed_domains = ["example.com"] }

        [profiles.fast.tools.web_search.location]
        country = "US"
        timezone = "America/New_York"

        [profiles.fast.features.network_proxy]
        enabled = true
        mode = "limited"
        proxy_url = "http://127.0.0.1:1234"

        [profiles.fast.features.network_proxy.domains]
        "*.example.com" = "allow"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let webNetworkIssues = report.issues.filter {
                $0.code == .configUnsupportedShape
                    && ($0.subjectPath?.contains("web_search") == true
                        || $0.subjectPath?.contains("network_proxy") == true)
            }

            XCTAssertTrue(
                webNetworkIssues.isEmpty,
                webNetworkIssues.map { "\($0.title): \($0.subjectPath ?? "nil") - \($0.detail)" }.joined(separator: "\n")
            )
        }
    }

    func testInvalidCodexPermissionNetworkSettingsAreReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        permissions.local.network.enabled = "yes"
        permissions.local.network.mode = "open"
        permissions.local.network.stale = true
        permissions.local.network.domains."*.example.com" = "maybe"
        permissions.networking.network.enabled = "yes"

        [permissions.ci]
        network = true

        [permissions.parent]
        network.old = true

        [permissions.inline]
        network = { enabled = "yes", mode = "open", proxy_url = 123, domains = { "*.example.com" = "maybe" }, unix_sockets = { "/tmp/codex.sock" = "deny" } }

        [permissions.dev.network]
        allow_local_binding = "yes"
        proxy_url = 123
        domains = "example.com"
        unknown = true

        [permissions.dev.network.domains]
        "blocked.example.com" = "maybe"

        [permissions.dev.network.unix_sockets]
        "/tmp/codex.sock" = "deny"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let invalid = report.issues.filter { $0.code == .configUnsupportedShape }
            let subjectPaths = Set(invalid.compactMap(\.subjectPath))

            XCTAssertEqual(Set(invalid.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(subjectPaths.contains("permissions.local.network.enabled"))
            XCTAssertTrue(subjectPaths.contains("permissions.local.network.mode"))
            XCTAssertTrue(subjectPaths.contains("permissions.local.network.stale"))
            XCTAssertTrue(subjectPaths.contains { $0.contains("permissions.local.network.domains.") && $0.contains("example.com") })
            XCTAssertTrue(subjectPaths.contains("permissions.networking.network.enabled"))
            XCTAssertTrue(subjectPaths.contains("permissions.ci.network"))
            XCTAssertTrue(subjectPaths.contains("permissions.parent.network.old"))
            XCTAssertTrue(subjectPaths.contains("permissions.inline.network.enabled"))
            XCTAssertTrue(subjectPaths.contains("permissions.inline.network.mode"))
            XCTAssertTrue(subjectPaths.contains("permissions.inline.network.proxy_url"))
            XCTAssertTrue(subjectPaths.contains { $0.contains("permissions.inline.network.domains.") && $0.contains("example.com") })
            XCTAssertTrue(subjectPaths.contains("permissions.inline.network.unix_sockets./tmp/codex.sock"))
            XCTAssertTrue(subjectPaths.contains("permissions.dev.network.allow_local_binding"))
            XCTAssertTrue(subjectPaths.contains("permissions.dev.network.proxy_url"))
            XCTAssertTrue(subjectPaths.contains("permissions.dev.network.domains"))
            XCTAssertTrue(subjectPaths.contains("permissions.dev.network.unknown"))
            XCTAssertTrue(subjectPaths.contains("permissions.dev.network.domains.blocked.example.com"))
            XCTAssertTrue(subjectPaths.contains("permissions.dev.network.unix_sockets./tmp/codex.sock"))
            XCTAssertTrue(invalid.contains {
                $0.title == "Invalid Codex permission network domain rule"
                    && $0.subjectPath == "permissions.dev.network.domains.blocked.example.com"
            })
            XCTAssertTrue(invalid.contains {
                $0.title == "Invalid Codex permission network Unix socket rule"
                    && $0.subjectPath == "permissions.dev.network.unix_sockets./tmp/codex.sock"
            })
        }
    }

    func testValidCodexPermissionNetworkSettingsAreNotReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        permissions.local.network = { enabled = true, mode = "limited", domains = { "*.example.com" = "allow" }, unix_sockets = { "/tmp/codex.sock" = "none" } }
        permissions.local.network.allow_upstream_proxy = false

        [permissions.dev.network]
        enabled = true
        mode = "full"
        allow_local_binding = true
        proxy_url = "http://127.0.0.1:1234"
        socks_url = "socks5://127.0.0.1:1080"

        [permissions.dev.network.domains]
        "*.example.com" = "allow"
        "blocked.example.com" = "deny"

        [permissions.dev.network.unix_sockets]
        "/tmp/codex.sock" = "allow"
        "/tmp/old.sock" = "none"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let permissionIssues = report.issues.filter {
                $0.code == .configUnsupportedShape
                    && $0.subjectPath?.contains("permissions.") == true
                    && $0.subjectPath?.contains(".network") == true
            }

            XCTAssertTrue(
                permissionIssues.isEmpty,
                permissionIssues.map { "\($0.title): \($0.subjectPath ?? "nil") - \($0.detail)" }.joined(separator: "\n")
            )
        }
    }

    func testInvalidCodexWorkspaceRootsSettingsAreReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        permissions.project-edit.workspace_roots = true
        permissions.project-edit.workspace_roots."/tmp/repo" = "yes"

        [permissions.inline]
        workspace_roots = { "/tmp/a" = "yes", "/tmp/b" = true }

        [permissions.parent]
        workspace_roots."/tmp/other" = "no"

        [permissions.dev.workspace_roots]
        "/tmp/repo" = "yes"
        "/tmp/off" = false
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let invalid = report.issues.filter {
                $0.code == .configUnsupportedShape
                    && ($0.subjectPath?.contains("workspace_roots") == true)
            }
            let subjectPaths = Set(invalid.compactMap(\.subjectPath))

            XCTAssertEqual(Set(invalid.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(subjectPaths.contains("permissions.project-edit.workspace_roots"))
            XCTAssertTrue(subjectPaths.contains { $0.contains("permissions.project-edit.workspace_roots") && $0.contains("/tmp/repo") })
            XCTAssertTrue(subjectPaths.contains("permissions.inline.workspace_roots./tmp/a"))
            XCTAssertTrue(subjectPaths.contains { $0.contains("permissions.parent.workspace_roots") && $0.contains("/tmp/other") })
            XCTAssertTrue(subjectPaths.contains { $0.contains("permissions.dev.workspace_roots") && $0.contains("/tmp/repo") })
            XCTAssertFalse(subjectPaths.contains { $0.contains("/tmp/off") })
            XCTAssertFalse(subjectPaths.contains { $0.contains("/tmp/b") })
        }
    }

    func testValidCodexWorkspaceRootsSettingsAreNotReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        permissions.inline.workspace_roots = { "/tmp/a" = true, "/tmp/b" = false }

        [permissions.parent]
        workspace_roots."/tmp/other" = true

        [permissions.dev.workspace_roots]
        "/tmp/repo" = true
        "/tmp/off" = false
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let workspaceRootIssues = report.issues.filter {
                $0.code == .configUnsupportedShape
                    && ($0.subjectPath?.contains("workspace_roots") == true)
            }

            XCTAssertTrue(
                workspaceRootIssues.isEmpty,
                workspaceRootIssues.map { "\($0.title): \($0.subjectPath ?? "nil") - \($0.detail)" }.joined(separator: "\n")
            )
        }
    }

    func testInvalidCodexNamedFilesystemPermissionSettingsAreReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        permissions.project-edit.filesystem = true
        permissions.project-edit.filesystem.glob_scan_max_depth = "deep"
        permissions.zero.filesystem.glob_scan_max_depth = 0
        permissions.project-edit.filesystem.":workspace_roots"."." = "allow"

        [permissions.inline]
        filesystem = { ":minimal" = "read", "~/Documents" = "block", ":workspace_roots" = { "." = "edit" } }

        [permissions.dev.filesystem]
        ":minimal" = "read"
        "~/Documents" = "block"
        glob_scan_max_depth = "deep"

        [permissions.zero-section.filesystem]
        glob_scan_max_depth = 0

        [permissions.dev.filesystem.":workspace_roots"]
        "." = "edit"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let invalid = report.issues.filter { $0.code == .configUnsupportedShape }
            let subjectPaths = Set(invalid.compactMap(\.subjectPath))
            let invalidFilesystemRuleSubjects = Set(
                invalid
                    .filter { $0.title == "Invalid Codex filesystem permission rule" }
                    .compactMap(\.subjectPath)
            )

            XCTAssertEqual(Set(invalid.compactMap(\.toolID)), [.codexCLI, .codexDesktop])
            XCTAssertTrue(subjectPaths.contains("permissions.project-edit.filesystem"))
            XCTAssertTrue(subjectPaths.contains("permissions.project-edit.filesystem.glob_scan_max_depth"))
            XCTAssertTrue(subjectPaths.contains("permissions.zero.filesystem.glob_scan_max_depth"))
            XCTAssertTrue(subjectPaths.contains { $0.contains("permissions.project-edit.filesystem") && $0.contains(":workspace_roots") && $0.contains(".") })
            XCTAssertTrue(subjectPaths.contains("permissions.inline.filesystem.~/Documents"))
            XCTAssertTrue(subjectPaths.contains("permissions.inline.filesystem.:workspace_roots.."))
            XCTAssertTrue(subjectPaths.contains("permissions.dev.filesystem.~/Documents"))
            XCTAssertTrue(subjectPaths.contains("permissions.dev.filesystem.glob_scan_max_depth"))
            XCTAssertTrue(subjectPaths.contains("permissions.zero-section.filesystem.glob_scan_max_depth"))
            XCTAssertTrue(subjectPaths.contains { $0.contains("permissions.dev.filesystem") && $0.contains(":workspace_roots") && $0.contains(".") })
            XCTAssertTrue(invalidFilesystemRuleSubjects.contains("permissions.inline.filesystem.~/Documents"))
            XCTAssertTrue(invalidFilesystemRuleSubjects.contains("permissions.dev.filesystem.~/Documents"))
            XCTAssertTrue(invalidFilesystemRuleSubjects.contains { $0.contains("permissions.project-edit.filesystem") && $0.contains(":workspace_roots") && $0.contains(".") })
            XCTAssertTrue(invalidFilesystemRuleSubjects.contains { $0.contains("permissions.dev.filesystem") && $0.contains(":workspace_roots") && $0.contains(".") })
        }
    }

    func testValidCodexNamedFilesystemPermissionSettingsAreNotReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        default_permissions = "project-edit"
        permissions.inline.filesystem = { ":minimal" = "read", "~/Documents" = "deny", glob_scan_max_depth = 3, ":workspace_roots" = { "." = "write", "**/*.env" = "deny" } }

        [permissions.project-edit.filesystem]
        ":minimal" = "read"
        "~/Documents" = "deny"
        "~/Documents/codex" = "write"
        glob_scan_max_depth = 1

        [permissions.deep.filesystem]
        glob_scan_max_depth = 3

        [permissions.project-edit.filesystem.":workspace_roots"]
        "." = "write"
        "**/*.env" = "deny"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let filesystemIssues = report.issues.filter {
                $0.code == .configUnsupportedShape
                    && $0.subjectPath?.contains(".filesystem") == true
            }

            XCTAssertTrue(
                filesystemIssues.isEmpty,
                filesystemIssues.map { "\($0.title): \($0.subjectPath ?? "nil") - \($0.detail)" }.joined(separator: "\n")
            )
        }
    }

    func testInvalidCodexRequirementsFilesystemAndMCPIdentitySettingsAreReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let requirements = root.appendingPathComponent("requirements.toml")
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try "".write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        try """
        permissions.filesystem.deny_read = "~/.ssh"

        [permissions.filesystem]
        read_only = true

        [mcp_servers.context7.identity]
        command = "npx"
        url = "https://example.com/mcp"
        args = ["-y", "@upstash/context7-mcp"]

        [mcp_servers.bad.identity]
        bearer_token_env_var = "TOKEN"

        [mcp_servers.scalar]
        identity = true
        """.write(to: requirements, atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            withCodexRequirementsPath(requirements.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let invalid = report.issues.filter {
                    $0.code == .configUnsupportedShape
                        && $0.surfaceID == "codex-requirements"
                }
                let subjectPaths = Set(invalid.compactMap(\.subjectPath))
                let titlesBySubject = Dictionary(grouping: invalid, by: { $0.subjectPath ?? "" })
                    .mapValues { Set($0.map(\.title)) }

                XCTAssertEqual(Set(invalid.compactMap(\.toolID)), [.codexCLI])
                XCTAssertTrue(titlesBySubject["permissions.filesystem.deny_read"]?.contains("Invalid Codex filesystem deny_read") == true)
                XCTAssertTrue(subjectPaths.contains("permissions.filesystem.deny_read"))
                XCTAssertTrue(titlesBySubject["permissions.filesystem.read_only"]?.contains("Unknown Codex filesystem permission key") == true)
                XCTAssertTrue(subjectPaths.contains("permissions.filesystem.read_only"))
                XCTAssertTrue(titlesBySubject["mcp_servers.context7.identity"]?.contains("Conflicting Codex MCP identity") == true)
                XCTAssertTrue(subjectPaths.contains("mcp_servers.context7.identity"))
                XCTAssertTrue(titlesBySubject["mcp_servers.context7.identity.args"]?.contains("Unknown Codex MCP identity key") == true)
                XCTAssertTrue(subjectPaths.contains("mcp_servers.context7.identity.args"))
                XCTAssertTrue(titlesBySubject["mcp_servers.bad.identity"]?.contains("Incomplete Codex MCP identity") == true)
                XCTAssertTrue(subjectPaths.contains("mcp_servers.bad.identity"))
                XCTAssertTrue(titlesBySubject["mcp_servers.bad.identity.bearer_token_env_var"]?.contains("Unknown Codex MCP identity key") == true)
                XCTAssertTrue(subjectPaths.contains("mcp_servers.bad.identity.bearer_token_env_var"))
                XCTAssertTrue(titlesBySubject["mcp_servers.scalar.identity"]?.contains("Invalid Codex MCP identity") == true)
                XCTAssertTrue(subjectPaths.contains("mcp_servers.scalar.identity"))
            }
        }
    }

    func testValidCodexRequirementsFilesystemAndMCPIdentitySettingsAreNotReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let requirements = root.appendingPathComponent("requirements.toml")
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try "".write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        try """
        [permissions.filesystem]
        deny_read = ["~/.ssh", "**/*.env"]

        [mcp_servers.context7.identity]
        command = "npx"

        [mcp_servers.figma.identity]
        url = "https://mcp.figma.com/mcp"
        """.write(to: requirements, atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            withCodexRequirementsPath(requirements.path) {
                let report = CompatibilityScanner.scan(projectRoot: project.path)
                let requirementsIssues = report.issues.filter {
                    $0.code == .configUnsupportedShape
                        && $0.surfaceID == "codex-requirements"
                        && ($0.subjectPath?.contains("permissions.filesystem") == true
                            || $0.subjectPath?.contains(".identity") == true)
                }

                XCTAssertTrue(
                    requirementsIssues.isEmpty,
                    requirementsIssues.map { "\($0.title): \($0.subjectPath ?? "nil") - \($0.detail)" }.joined(separator: "\n")
                )
            }
        }
    }

    func testValidCodexEnumSettingsAreNotReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try """
        model_reasoning_effort = "xhigh"
        model_reasoning_summary = "concise"
        model_verbosity = "high"
        oss_provider = "ollama"
        approvals_reviewer = "auto_review"

        [profiles.fast]
        sandbox_mode = "workspace-write"
        approval_policy = "never"
        model_reasoning_effort = "minimal"

        [projects."\(project.path)"]
        trust_level = "trusted"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)

            XCTAssertFalse(report.issues.contains {
                $0.code == .configUnsupportedShape
                    && $0.title.hasPrefix("Invalid Codex ")
                    && ($0.subjectPath?.contains("model_reasoning") == true
                        || $0.subjectPath?.contains("model_verbosity") == true
                        || $0.subjectPath?.contains("oss_provider") == true
                        || $0.subjectPath?.contains("approvals_reviewer") == true
                        || $0.subjectPath?.contains("profiles.fast") == true
                        || $0.subjectPath?.contains("trust_level") == true)
            })
        }
    }

    func testClaudeCodeSettingsReloadByDefaultButSessionScopedKeysAreReported() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        let claudeDir = project.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        try """
        {
          "model": "opus",
          "outputStyle": "Explanatory",
          "permissions": {
            "allow": ["Bash(swift test)"]
          }
        }
        """.write(to: claudeDir.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let settingsPath = claudeDir.appendingPathComponent("settings.json").path
            let setting = report.settings.first { $0.surfaceID == "claude-code-project-settings" }
            let reloadIssues = report.issues.filter {
                $0.code == .settingsSessionReloadRequired
                    && $0.path == settingsPath
            }

            XCTAssertEqual(setting?.requiresRestartAfterWrite, false)
            XCTAssertEqual(Set(reloadIssues.map(\.state)), [.needsRestart])
            XCTAssertTrue(reloadIssues.contains { $0.title == "Claude model setting is session-scoped" })
            XCTAssertTrue(reloadIssues.contains { $0.title == "Claude output style rebuilds with session context" })
        }
    }

    func testClaudeCodeUserGlobalConfigSurfaceReadsClaudeJSONTopLevelKeys() throws {
        let root = try makeTempDirectory()
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let project = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let claudeJSON = codexHome.appendingPathComponent("isolated-claude.json")
        try """
        {
          "autoConnectIde": true,
          "worktree": {
            "enabled": true
          },
          "mcpServers": {
            "user-docs": {
              "command": "npx",
              "args": ["docs"]
            }
          },
          "projects": {
            "\(project.path)": {
              "allowedTools": ["Read"],
              "mcpServers": {
                "local-docs": {
                  "command": "uvx",
                  "args": ["local-docs"]
                }
              }
            }
          }
        }
        """.write(to: claudeJSON, atomically: true, encoding: .utf8)

        withCodexHome(codexHome.path) {
            let report = CompatibilityScanner.scan(projectRoot: project.path)
            let globalConfig = report.settings.first {
                $0.surfaceID == "claude-code-user-global-config"
            }

            XCTAssertEqual(globalConfig?.path, claudeJSON.path)
            XCTAssertEqual(globalConfig?.fileControlled, false)
            XCTAssertEqual(globalConfig?.canWriteSafely, false)
            XCTAssertTrue(globalConfig?.keys.contains("autoConnectIde") == true)
            XCTAssertTrue(globalConfig?.keys.contains("worktree") == true)
            XCTAssertTrue(report.servers.contains {
                $0.toolID == .claudeCode && $0.name == "user-docs"
            })
            XCTAssertTrue(report.servers.contains {
                $0.toolID == .claudeCode && $0.name == "local-docs"
            })
            XCTAssertTrue(report.settings.contains {
                $0.surfaceID.hasPrefix("claude-code-local-project-state")
            })
        }
    }

    private func withCodexHome(_ path: String, run: () throws -> Void) rethrows {
        let previous = getenv("CODEX_HOME").map { String(cString: $0) }
        let previousClaudeHome = getenv("PROJECTHUB_CLAUDE_HOME").map { String(cString: $0) }
        let previousClaudeJSONPath = getenv("PROJECTHUB_CLAUDE_JSON_PATH").map { String(cString: $0) }
        let previousClaudeConfigDir = getenv("CLAUDE_CONFIG_DIR").map { String(cString: $0) }
        let isolatedClaudeHome = (path as NSString).appendingPathComponent("isolated-claude-home")
        let isolatedClaudeJSONPath = (path as NSString).appendingPathComponent("isolated-claude.json")
        setenv("CODEX_HOME", path, 1)
        setenv("PROJECTHUB_CLAUDE_HOME", isolatedClaudeHome, 1)
        setenv("PROJECTHUB_CLAUDE_JSON_PATH", isolatedClaudeJSONPath, 1)
        setenv("CLAUDE_CONFIG_DIR", isolatedClaudeHome, 1)
        defer {
            if let previous {
                setenv("CODEX_HOME", previous, 1)
            } else {
                unsetenv("CODEX_HOME")
            }
            if let previousClaudeHome {
                setenv("PROJECTHUB_CLAUDE_HOME", previousClaudeHome, 1)
            } else {
                unsetenv("PROJECTHUB_CLAUDE_HOME")
            }
            if let previousClaudeJSONPath {
                setenv("PROJECTHUB_CLAUDE_JSON_PATH", previousClaudeJSONPath, 1)
            } else {
                unsetenv("PROJECTHUB_CLAUDE_JSON_PATH")
            }
            if let previousClaudeConfigDir {
                setenv("CLAUDE_CONFIG_DIR", previousClaudeConfigDir, 1)
            } else {
                unsetenv("CLAUDE_CONFIG_DIR")
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

    private func withAdditionalDirectoryMemoryEnv(_ value: String?, run: () throws -> Void) rethrows {
        let key = "CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD"
        let previous = getenv(key).map { String(cString: $0) }
        if let value {
            setenv(key, value, 1)
        } else {
            unsetenv(key)
        }
        defer {
            if let previous {
                setenv(key, previous, 1)
            } else {
                unsetenv(key)
            }
        }
        try run()
    }

    private func withClaudeJSONPath(_ path: String, run: () throws -> Void) rethrows {
        let key = "PROJECTHUB_CLAUDE_JSON_PATH"
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

    private func withCodexRequirementsPath(_ path: String, run: () throws -> Void) rethrows {
        let previous = getenv("PROJECTHUB_CODEX_REQUIREMENTS_PATH").map { String(cString: $0) }
        setenv("PROJECTHUB_CODEX_REQUIREMENTS_PATH", path, 1)
        defer {
            if let previous {
                setenv("PROJECTHUB_CODEX_REQUIREMENTS_PATH", previous, 1)
            } else {
                unsetenv("PROJECTHUB_CODEX_REQUIREMENTS_PATH")
            }
        }
        try run()
    }

    private func makeTempDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubCompatibilityContextSettingsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }
}
