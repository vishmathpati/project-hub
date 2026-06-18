import XCTest
@testable import ProjectHub

final class ProjectDiscoveryTests: XCTestCase {
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
