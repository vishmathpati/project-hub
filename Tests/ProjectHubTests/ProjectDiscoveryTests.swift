import XCTest
@testable import ProjectHub

final class ProjectDiscoveryTests: XCTestCase {
    func testDiscoveryDoesNotPromoteMissingCodexWorktreeToCodexHome() throws {
        let home = try makeTempDirectory()
        let codexHome = home.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try "# global Codex instructions\n"
            .write(to: codexHome.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        let missingWorktree = codexHome.appendingPathComponent("worktrees/4659/projecthub", isDirectory: true)

        XCTAssertNil(ProjectStore.canonicalDiscoveryPath(missingWorktree.path, fm: FileManager.default))
        XCTAssertNil(ProjectStore.makeDiscoveredProject(
            rawPath: missingWorktree.path,
            source: .codexCLI,
            excluding: [],
            fm: FileManager.default,
            home: home.path
        ))
    }

    func testDiscoveryIgnoresToolHomeEvenWithToolMarkers() throws {
        let home = try makeTempDirectory()
        let codexHome = home.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try "# global Codex instructions\n"
            .write(to: codexHome.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        XCTAssertTrue(ProjectStore.isIgnoredDiscoveryRoot(codexHome.path, home: home.path))
        XCTAssertNil(ProjectStore.makeDiscoveredProject(
            rawPath: codexHome.path,
            source: .codexCLI,
            excluding: [],
            fm: FileManager.default,
            home: home.path
        ))
    }

    func testDiscoveryIgnoresWorkspaceContainerRoots() throws {
        let home = try makeTempDirectory()
        let active = home.appendingPathComponent("Arel OS/Projects/Active", isDirectory: true)
        try FileManager.default.createDirectory(at: active.appendingPathComponent(".codex", isDirectory: true), withIntermediateDirectories: true)
        try "# workspace instructions\n"
            .write(to: active.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)

        XCTAssertTrue(ProjectStore.isIgnoredDiscoveryRoot(active.path, home: home.path))
        XCTAssertNil(ProjectStore.makeDiscoveredProject(
            rawPath: active.path,
            source: .codexCLI,
            excluding: [],
            fm: FileManager.default,
            home: home.path
        ))
    }

    func testDiscoveryIgnoresCodexTranscriptFoldersWithoutProjectEvidence() throws {
        let home = try makeTempDirectory()
        let transcript = home.appendingPathComponent("Documents/Codex/2026-06-03/actually-the-problem-is-i-was", isDirectory: true)
        try FileManager.default.createDirectory(at: transcript.appendingPathComponent("outputs", isDirectory: true), withIntermediateDirectories: true)

        XCTAssertNil(ProjectStore.makeDiscoveredProject(
            rawPath: transcript.path,
            source: .codexCLI,
            excluding: [],
            fm: FileManager.default,
            home: home.path
        ))
    }

    func testDiscoveryKeepsRealProjectUnderWorkspaceContainer() throws {
        let home = try makeTempDirectory()
        let project = home.appendingPathComponent("Arel OS/Projects/Active/projecthub", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try "// swift-tools-version: 5.9\n"
            .write(to: project.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        let discovered = try XCTUnwrap(ProjectStore.makeDiscoveredProject(
            rawPath: project.path,
            source: .filesystem,
            excluding: [],
            fm: FileManager.default,
            home: home.path
        ))

        XCTAssertEqual(discovered.path, canonicalFilePath(project.path))
        XCTAssertEqual(discovered.displayName, "projecthub")
    }

    func testDiscoveryIgnoresGenericGitOnlyContainerName() throws {
        let home = try makeTempDirectory()
        let code = home.appendingPathComponent("Desktop/Code", isDirectory: true)
        try FileManager.default.createDirectory(at: code.appendingPathComponent(".git", isDirectory: true), withIntermediateDirectories: true)

        XCTAssertNil(ProjectStore.makeDiscoveredProject(
            rawPath: code.path,
            source: .claudeCode,
            excluding: [],
            fm: FileManager.default,
            home: home.path
        ))
    }

    func testDiscoveryKeepsGenericNamedFolderWithProjectMarkers() throws {
        let home = try makeTempDirectory()
        let code = home.appendingPathComponent("Projects/Code", isDirectory: true)
        try FileManager.default.createDirectory(at: code.appendingPathComponent(".git", isDirectory: true), withIntermediateDirectories: true)
        try "{}\n"
            .write(to: code.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

        XCTAssertNotNil(ProjectStore.makeDiscoveredProject(
            rawPath: code.path,
            source: .claudeCode,
            excluding: [],
            fm: FileManager.default,
            home: home.path
        ))
    }

    func testDiscoverySkipsProtectedUserStorageBeforeProjectProbe() throws {
        let home = try makeTempDirectory()
        let project = home.appendingPathComponent("Desktop/projecthub", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try "// swift-tools-version: 5.9\n"
            .write(to: project.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        XCTAssertNil(ProjectStore.makeDiscoveredProject(
            rawPath: project.path,
            source: .claudeCode,
            excluding: [],
            fm: FileManager.default,
            home: home.path
        ))
    }

    func testGitWorktreeInfoDetectsLinkedWorktree() throws {
        let root = try makeTempDirectory()
        let main = root.appendingPathComponent("main-repo", isDirectory: true)
        let worktree = root.appendingPathComponent("main-repo-feature", isDirectory: true)
        let gitDir = main.appendingPathComponent(".git/worktrees/main-repo-feature", isDirectory: true)
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)
        try "gitdir: \(gitDir.path)\n"
            .write(to: worktree.appendingPathComponent(".git"), atomically: true, encoding: .utf8)

        let info = try XCTUnwrap(ProjectStore.worktreeInfo(at: worktree.path, fm: FileManager.default))

        XCTAssertEqual(info.gitDir, canonicalFilePath(gitDir.path))
        XCTAssertEqual(info.mainRepositoryPath, canonicalFilePath(main.path))
        XCTAssertEqual(info.mainRepositoryName, "main-repo")
    }

    func testGitFileForSubmoduleIsNotTreatedAsWorktree() throws {
        let root = try makeTempDirectory()
        let submodule = root.appendingPathComponent("submodule", isDirectory: true)
        try FileManager.default.createDirectory(at: submodule, withIntermediateDirectories: true)
        try "gitdir: ../.git/modules/submodule\n"
            .write(to: submodule.appendingPathComponent(".git"), atomically: true, encoding: .utf8)

        XCTAssertNil(ProjectStore.worktreeInfo(at: submodule.path, fm: FileManager.default))
    }

    func testDiscoveryMergeSeparatesWorktreesFromMainProjectList() throws {
        let root = try makeTempDirectory()
        let main = root.appendingPathComponent("projecthub", isDirectory: true)
        let worktree = root.appendingPathComponent("projecthub-feature", isDirectory: true)
        let gitDir = main.appendingPathComponent(".git/worktrees/projecthub-feature", isDirectory: true)
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: main.appendingPathComponent(".git", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)
        try "gitdir: \(gitDir.path)\n"
            .write(to: worktree.appendingPathComponent(".git"), atomically: true, encoding: .utf8)

        let mainProject = DiscoveredProject(
            id: UUID(),
            path: canonicalFilePath(main.path),
            displayName: "projecthub",
            hasGit: true,
            detectedTools: ["codex"],
            sources: [.filesystem],
            worktreeInfo: nil
        )
        let worktreeProject = DiscoveredProject(
            id: UUID(),
            path: canonicalFilePath(worktree.path),
            displayName: "projecthub-feature",
            hasGit: true,
            detectedTools: ["codex"],
            sources: [.codexCLI],
            worktreeInfo: try XCTUnwrap(ProjectStore.worktreeInfo(at: worktree.path, fm: FileManager.default))
        )

        let result = ProjectStore.mergeDiscoveryCandidates([worktreeProject, mainProject])

        XCTAssertEqual(result.projects.map(\.path), [canonicalFilePath(main.path)])
        XCTAssertEqual(result.hiddenWorktrees.map(\.path), [canonicalFilePath(worktree.path)])
        XCTAssertEqual(result.hiddenWorktrees.first?.sources, [.codexCLI])
    }

    func testDiscoveryDedupeTreatsCaseVariantsAsSamePath() throws {
        let upper = DiscoveredProject(
            id: UUID(),
            path: "/Users/example/Arel OS/Projects/Active/projecthub",
            displayName: "projecthub",
            hasGit: true,
            detectedTools: ["codex"],
            sources: [.filesystem],
            worktreeInfo: nil
        )
        let lower = DiscoveredProject(
            id: UUID(),
            path: "/Users/example/Arel OS/Projects/active/projecthub",
            displayName: "projecthub",
            hasGit: true,
            detectedTools: ["claude-code"],
            sources: [.claudeCode],
            worktreeInfo: nil
        )

        let result = ProjectStore.mergeDiscoveryCandidates([upper, lower])

        XCTAssertEqual(result.projects.count, 1)
        XCTAssertEqual(result.projects.first?.sources, [.filesystem, .claudeCode])
        XCTAssertEqual(result.projects.first?.detectedTools, ["claude-code", "codex"])
    }

    func testDiscoveryExclusionTreatsCaseVariantsAsSamePath() throws {
        let home = try makeTempDirectory()
        let project = home.appendingPathComponent("Arel OS/Projects/Active/projecthub", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try "// swift-tools-version: 5.9\n"
            .write(to: project.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        let existing = ProjectStore.discoveryDedupKey(
            home.appendingPathComponent("Arel OS/Projects/active/projecthub", isDirectory: true).path
        )

        XCTAssertNil(ProjectStore.makeDiscoveredProject(
            rawPath: project.path,
            source: .codexCLI,
            excluding: [existing],
            fm: FileManager.default,
            home: home.path
        ))
    }

    func testSavedProjectSanitizerDropsOldFalsePositiveRows() throws {
        let home = try makeTempDirectory()
        let now = Date()
        let projects = [
            Project(
                id: UUID(),
                path: home.appendingPathComponent(".codex", isDirectory: true).path,
                displayName: ".codex",
                addedAt: now,
                lastOpenedAt: now
            ),
            Project(
                id: UUID(),
                path: home.appendingPathComponent("Arel OS/Projects/Active", isDirectory: true).path,
                displayName: "Active",
                addedAt: now,
                lastOpenedAt: now
            ),
            Project(
                id: UUID(),
                path: home.appendingPathComponent("Desktop/Code", isDirectory: true).path,
                displayName: "Code",
                addedAt: now,
                lastOpenedAt: now
            ),
            Project(
                id: UUID(),
                path: home.appendingPathComponent("Arel OS/Projects/Active/projecthub", isDirectory: true).path,
                displayName: "projecthub",
                addedAt: now,
                lastOpenedAt: now
            )
        ]

        let sanitized = ProjectStore.sanitizeSavedProjects(projects, home: home.path)

        XCTAssertEqual(sanitized.map(\.displayName), ["projecthub"])
    }

    func testSavedProjectSanitizerDedupeTreatsCaseVariantsAsSamePath() throws {
        let home = try makeTempDirectory()
        let now = Date()
        let upper = Project(
            id: UUID(),
            path: home.appendingPathComponent("Arel OS/Projects/Active/projecthub", isDirectory: true).path,
            displayName: "projecthub",
            addedAt: now,
            lastOpenedAt: now
        )
        let lower = Project(
            id: UUID(),
            path: home.appendingPathComponent("Arel OS/Projects/active/projecthub", isDirectory: true).path,
            displayName: "projecthub duplicate",
            addedAt: now,
            lastOpenedAt: now.addingTimeInterval(-10)
        )

        let sanitized = ProjectStore.sanitizeSavedProjects([upper, lower], home: home.path)

        XCTAssertEqual(sanitized.count, 1)
        XCTAssertEqual(sanitized.first?.displayName, "projecthub")
    }

    private func canonicalFilePath(_ path: String) -> String {
        URL(fileURLWithPath: path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubProjectDiscoveryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
