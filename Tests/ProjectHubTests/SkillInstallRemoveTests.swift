import XCTest
@testable import ProjectHub

/// Round-trips a skill through install and remove. The memo in
/// SkillInventoryReader caches parsed roots, so these two operations are the ones
/// most likely to regress into "nothing happens".
@MainActor
final class SkillInstallRemoveTests: XCTestCase {

    private func makeDir(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func writeSkill(named name: String, under root: URL) throws -> URL {
        let dir = root.appendingPathComponent(name, isDirectory: true)
        try makeDir(dir)
        try """
        ---
        name: \(name)
        description: test skill \(name)
        ---
        # \(name)
        """.write(to: dir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        return dir
    }

    func testInstallThenRemoveRoundTrip() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("SkillInstallRemove-\(UUID().uuidString)")
        let source = root.appendingPathComponent("source/skills", isDirectory: true)
        let project = root.appendingPathComponent("project", isDirectory: true)
        try makeDir(source)
        try makeDir(project)
        defer { try? fm.removeItem(at: root) }

        let sourceDir = try writeSkill(named: "round-trip", under: source)

        // Baseline: the project owns no skills of its own. It still reports the
        // global plugin and user-level skills reached by the walk-up, which is
        // exactly why a project's page looks full before anything is installed.
        SkillInventoryReader.invalidateCaches()
        let baseline = SkillInventoryReader.installedSkills(for: project.path)
        XCTAssertNil(baseline.first { $0.name == "round-trip" },
                     "the project should not report a skill that was never installed")
        XCTAssertTrue(
            baseline.allSatisfy { !$0.canRemove } || baseline.allSatisfy { $0.scopeLabel == "Parent" },
            "everything on an untouched project should be parent scope, so nothing is removable yet"
        )

        // ADD
        let store = SkillStore()
        store.install(
            skill: Skill(name: "round-trip", description: "test skill round-trip",
                         triggers: [], source: .claudeGlobal, path: sourceDir.path),
            to: project.path
        )

        let installedPath = project.appendingPathComponent(".claude/skills/round-trip/SKILL.md").path
        XCTAssertTrue(fm.fileExists(atPath: installedPath), "install should copy SKILL.md into the project")

        SkillInventoryReader.invalidateCaches()
        let afterInstall = SkillInventoryReader.installedSkills(for: project.path)
        let added = try XCTUnwrap(afterInstall.first { $0.name == "round-trip" },
                                  "the installed skill should be discoverable")
        XCTAssertTrue(added.canRemove, "a project-scope skill should be removable")

        // REMOVE
        store.remove(skill: added, from: project.path)
        XCTAssertFalse(fm.fileExists(atPath: installedPath), "remove should delete the copied skill directory")

        SkillInventoryReader.invalidateCaches()
        XCTAssertNil(
            SkillInventoryReader.installedSkills(for: project.path).first { $0.name == "round-trip" },
            "the removed skill should no longer be discoverable"
        )
    }

    /// The memo must not serve a stale root after a skill appears in it.
    func testMemoDoesNotHideNewlyAddedSkill() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("SkillMemoStamp-\(UUID().uuidString)")
        let project = root.appendingPathComponent("project", isDirectory: true)
        let skillsRoot = project.appendingPathComponent(".claude/skills", isDirectory: true)
        try makeDir(project)
        defer { try? fm.removeItem(at: root) }

        // Warm the memo while the project has no skills.
        _ = SkillInventoryReader.installedSkills(for: project.path)

        // Add one WITHOUT calling invalidateCaches, so only the stamp can catch it.
        try makeDir(skillsRoot)
        _ = try writeSkill(named: "appeared", under: skillsRoot)

        let afterAdd = SkillInventoryReader.installedSkills(for: project.path)
        XCTAssertNotNil(
            afterAdd.first { $0.name == "appeared" },
            "the directory stamp must invalidate the memo when a skill directory appears"
        )
    }

    /// Installs are links now, so the removal guard has to delete the link and
    /// leave the canonical skill alone. Getting this wrong erases the user's real
    /// skill out of ~/.agents/skills for every project pointing at it.
    func testRemovingALinkedSkillLeavesTheOriginalAlone() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("SkillSymlink-\(UUID().uuidString)")
        let source = root.appendingPathComponent("canonical/skills", isDirectory: true)
        let project = root.appendingPathComponent("project", isDirectory: true)
        try makeDir(source)
        try makeDir(project)
        defer { try? fm.removeItem(at: root) }

        let sourceDir = try writeSkill(named: "linked", under: source)
        let sourceFile = sourceDir.appendingPathComponent("SKILL.md").path

        let store = SkillStore()
        store.install(
            skill: Skill(name: "linked", description: "test skill linked",
                         triggers: [], source: .claudeGlobal, path: sourceDir.path),
            to: project.path
        )

        let installedDir = project.appendingPathComponent(".claude/skills/linked").path
        XCTAssertTrue(fm.fileExists(atPath: installedDir), "install should place an entry in the project")

        let isLink = (try? fm.destinationOfSymbolicLink(atPath: installedDir)) != nil
        XCTAssertTrue(isLink, "install should link rather than duplicate, so the skill is stored once")
        XCTAssertTrue(fm.fileExists(atPath: sourceFile), "the canonical skill must still exist after install")

        SkillInventoryReader.invalidateCaches()
        let installed = SkillInventoryReader.installedSkills(for: project.path)
        let entry = try XCTUnwrap(installed.first { $0.name == "linked" },
                                  "a linked skill should be discoverable")
        XCTAssertEqual(entry.scopeLabel, "Project", "a link inside the project should count as project scope")
        XCTAssertTrue(entry.canRemove, "a link inside the project should be removable")

        store.remove(skill: entry, from: project.path)

        XCTAssertFalse(fm.fileExists(atPath: installedDir), "remove should delete the link")
        XCTAssertTrue(fm.fileExists(atPath: sourceFile),
                      "remove must NOT delete the canonical skill the link pointed at")

        SkillInventoryReader.invalidateCaches()
        XCTAssertNil(SkillInventoryReader.installedSkills(for: project.path).first { $0.path == installedDir },
                     "the removed link should no longer be reported")
    }
    func testInvalidateReloadsAProjectThatWasAlreadyLoaded() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("SkillInvalidate-\(UUID().uuidString)")
        let project = root.appendingPathComponent("project", isDirectory: true)
        try makeDir(project)
        defer { try? fm.removeItem(at: root) }

        let store = SkillStore()
        await store.loadInstalledSkills(for: project.path)
        let before = try XCTUnwrap(store.cachedInstalledSkills(for: project.path),
                                   "the project should be loaded")
        XCTAssertNil(before.first { $0.name == "arrived" })

        let skillsRoot = project.appendingPathComponent(".claude/skills", isDirectory: true)
        try makeDir(skillsRoot)
        _ = try writeSkill(named: "arrived", under: skillsRoot)

        store.invalidateInstalledSkills(for: project.path)
        try await Task.sleep(for: .milliseconds(400))

        let reloaded = store.cachedInstalledSkills(for: project.path)
        XCTAssertNotNil(reloaded, "the project should be reloaded after invalidation, not dropped")
        XCTAssertEqual(reloaded?.first { $0.name == "arrived" }?.name, "arrived",
                       "the newly added skill should appear after invalidation")
    }
}
