import XCTest
import AppKit
@testable import ProjectHub

final class ProjectWorkspacePresentationTests: XCTestCase {
    func testProjectSectionRawValuesPreserveShortcutsAndOverviewDefault() {
        XCTAssertEqual(ProjectDetailView.ProjectSection.health.shortcutNumber, 1)
        XCTAssertEqual(ProjectDetailView.ProjectSection.skills.shortcutNumber, 2)
        XCTAssertEqual(ProjectDetailView.ProjectSection.overview.shortcutNumber, 9)
        XCTAssertEqual(ProjectDetailView.ProjectSection.displayOrder.first, .overview)
        XCTAssertEqual(ProjectDetailView.ProjectSection.shortcutSection(for: "1"), .health)
        XCTAssertEqual(ProjectDetailView.ProjectSection.shortcutSection(for: "2"), .skills)
        XCTAssertEqual(ProjectDetailView.ProjectSection.shortcutSection(for: "9"), .overview)
        XCTAssertNil(ProjectDetailView.ProjectSection.shortcutSection(for: "0"))
        XCTAssertNil(ProjectDetailView.ProjectSection.shortcutSection(for: "10"))
        XCTAssertTrue(ProjectDetailView.ProjectSection.acceptsShortcut(modifierFlags: [.command, .capsLock]))
        XCTAssertTrue(ProjectDetailView.ProjectSection.acceptsShortcut(modifierFlags: [.command, .numericPad]))
        XCTAssertFalse(ProjectDetailView.ProjectSection.acceptsShortcut(modifierFlags: [.command, .shift]))
    }

    func testGroupingCombinesNamesButRetainsExactMixedScopeOrigins() throws {
        let projectPath = "/tmp/work/project"
        let project = skill(name: "Review", path: projectPath + "/.claude/skills/review", scope: "Project", source: "Claude", claude: true)
        let global = skill(name: "review", path: "/tmp/home/.codex/skills/review", scope: "Parent", source: "Codex", codex: true)

        let groups = ProjectSkillGroup.groups(
            from: [global, project],
            projectPath: projectPath,
            globalRoots: ["/tmp/home/.codex/skills"]
        )
        let group = try XCTUnwrap(groups.first)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(group.originDetails.count, 2)
        XCTAssertEqual(group.originDetails.map(\.scope), [.project, .global])
        XCTAssertEqual(Set(group.origins.map(\.path)), Set([project.path, global.path]))
    }

    func testParentLabelUsesKnownGlobalRootBeforeAncestorFallback() {
        let global = skill(name: "Global", path: "/tmp/home/.claude/skills/global", scope: "Parent", source: "Claude", claude: true)
        let ancestor = skill(name: "Ancestor", path: "/tmp/work/.claude/skills/ancestor", scope: "Parent", source: "Claude", claude: true)
        let additional = skill(
            name: "Additional",
            path: "/shared/tooling/.claude/skills/additional",
            scope: "Parent",
            source: "Claude Code additional-directory skills",
            claude: true
        )

        XCTAssertEqual(
            ProjectSkillGroup.classify(global, projectPath: "/tmp/work/project", globalRoots: ["/tmp/home/.claude/skills"]),
            .global
        )
        XCTAssertEqual(
            ProjectSkillGroup.classify(ancestor, projectPath: "/tmp/work/project", globalRoots: ["/tmp/home/.claude/skills"]),
            .ancestor
        )
        XCTAssertEqual(
            ProjectSkillGroup.classify(additional, projectPath: "/tmp/work/project", globalRoots: ["/tmp/home/.claude/skills"]),
            .unknown("Additional folder")
        )
    }

    func testUnknownScopeStaysUnknownAndPluginProvenanceIsManaged() {
        let unknown = skill(name: "Odd", path: "/outside/odd", scope: "Workspace export", source: "Other")
        let plugin = skill(name: "Managed", path: "/etc/codex/skills/managed", scope: "Parent", source: "Codex admin", codex: true)

        XCTAssertEqual(ProjectSkillGroup.classify(unknown, projectPath: "/tmp/project", globalRoots: []), .unknown("Workspace export"))
        XCTAssertEqual(ProjectSkillGroup.classify(plugin, projectPath: "/tmp/project", globalRoots: ["/etc/codex/skills"]), .managed)
    }

    func testLibraryInstalledIndexExcludesGlobalAvailabilityAndPreservesProviderIdentity() {
        let projectPath = "/tmp/work/project"
        let global = skill(name: "shared", path: "/tmp/home/.claude/skills/shared", scope: "Parent", source: "Claude", claude: true)
        let installed = skill(name: "local", path: projectPath + "/.claude/skills/local", scope: "Project", source: "Claude", claude: true)
        let exact = ProjectSkillGroup.projectInstalledOrigins(
            from: [global, installed],
            projectPath: projectPath,
            globalRoots: ["/tmp/home/.claude/skills"]
        )
        let index = SkillStore.nameIndex(exact)

        XCTAssertFalse(index.contains(Skill(name: "shared", description: "", triggers: [], source: .claudeGlobal, path: global.path)))
        XCTAssertTrue(index.contains(Skill(name: "local", description: "", triggers: [], source: .claudeGlobal, path: installed.path)))
        XCTAssertFalse(index.contains(Skill(name: "local", description: "", triggers: [], source: .codexGlobal, path: installed.path)))
    }

    func testGlobalOnlySourceMergesAsReadOnlyAvailability() throws {
        let global = globalSkill(name: "available", path: "/tmp/home/.claude/skills/available", source: .claudeGlobal)
        let groups = ProjectSkillGroup.mergedGroups(
            installed: [],
            globalSkills: [global],
            projectPath: "/tmp/work/project",
            globalRoots: ["/tmp/home/.claude/skills"]
        )
        let group = try XCTUnwrap(groups.first)
        let origin = try XCTUnwrap(group.originDetails.first)

        XCTAssertEqual(origin.scope, .global)
        XCTAssertEqual(origin.availability, .available)
        XCTAssertFalse(origin.canEdit)
        XCTAssertFalse(origin.canRemove)
        XCTAssertFalse(group.hasInstalledOrigin)
        XCTAssertEqual(group.availabilityLabel, "available")
    }

    func testMergeKeepsSameNameProjectAndGlobalOrigins() throws {
        let projectPath = "/tmp/work/project"
        let local = skill(
            name: "shared",
            path: projectPath + "/.claude/skills/shared",
            scope: "Project",
            source: "Claude",
            claude: true
        )
        let global = globalSkill(name: "Shared", path: "/tmp/home/.claude/skills/shared", source: .claudeGlobal)
        let group = try XCTUnwrap(ProjectSkillGroup.mergedGroups(
            installed: [local],
            globalSkills: [global],
            projectPath: projectPath,
            globalRoots: ["/tmp/home/.claude/skills"]
        ).first)

        XCTAssertEqual(group.originDetails.map(\.scope), [.project, .global])
        XCTAssertEqual(group.originDetails.map(\.availability), [.installed, .available])
        XCTAssertTrue(group.hasInstalledOrigin)
    }

    func testMergeDeduplicatesExactGlobalPathAndProvider() throws {
        let path = "/tmp/home/.claude/skills/once"
        let scannedGlobal = skill(name: "once", path: path, scope: "Parent", source: "Claude global", claude: true)
        let libraryGlobal = globalSkill(name: "once", path: path, source: .claudeGlobal)
        let group = try XCTUnwrap(ProjectSkillGroup.mergedGroups(
            installed: [scannedGlobal],
            globalSkills: [libraryGlobal],
            projectPath: "/tmp/work/project",
            globalRoots: ["/tmp/home/.claude/skills"]
        ).first)

        XCTAssertEqual(group.originDetails.count, 1)
        XCTAssertEqual(group.originDetails.first?.availability, .available)
        XCTAssertEqual(group.originDetails.first?.scope, .global)
    }

    func testMergePreservesDistinctCaseSensitiveSourcePaths() throws {
        let upper = globalSkill(name: "same", path: "/tmp/home/.claude/skills/Same", source: .claudeGlobal)
        let lower = globalSkill(name: "same", path: "/tmp/home/.claude/skills/same", source: .claudeGlobal)
        let group = try XCTUnwrap(ProjectSkillGroup.mergedGroups(
            installed: [],
            globalSkills: [upper, lower],
            projectPath: "/tmp/work/project",
            globalRoots: ["/tmp/home/.claude/skills"]
        ).first)

        XCTAssertEqual(Set(group.originDetails.map { $0.installed.path }), Set([upper.path, lower.path]))
    }

    func testGlobalOnlyAvailabilityDoesNotEnterProjectInstalledNameIndex() throws {
        let global = globalSkill(name: "available", path: "/tmp/home/.claude/skills/available", source: .claudeGlobal)
        let group = try XCTUnwrap(ProjectSkillGroup.mergedGroups(
            installed: [],
            globalSkills: [global],
            projectPath: "/tmp/work/project",
            globalRoots: ["/tmp/home/.claude/skills"]
        ).first)
        let projectOnly = ProjectSkillGroup.projectInstalledOrigins(
            from: group.origins,
            projectPath: "/tmp/work/project",
            globalRoots: ["/tmp/home/.claude/skills"]
        )
        let index = SkillStore.nameIndex(projectOnly)

        XCTAssertTrue(projectOnly.isEmpty)
        XCTAssertFalse(index.contains(global))
    }

    private func skill(
        name: String,
        path: String,
        scope: String,
        source: String,
        claude: Bool = false,
        codex: Bool = false
    ) -> InstalledSkill {
        InstalledSkill(
            originID: path,
            name: name,
            description: "Description",
            claudePath: claude ? path : nil,
            codexPath: codex ? path : nil,
            path: path,
            skillMDPath: path + "/SKILL.md",
            sourceLabel: source,
            scopeLabel: scope,
            toolLabels: [source],
            state: .active,
            version: nil,
            diagnostics: [],
            canEdit: true,
            canRemove: true,
            readOnlyReason: nil
        )
    }

    private func globalSkill(name: String, path: String, source: SkillSource) -> Skill {
        Skill(name: name, description: "Description", triggers: [], source: source, path: path)
    }
}

final class ContextOpportunityTests: XCTestCase {
    func testPartialCoverageAlwaysTakesPriority() {
        let issue = ContextCoverageIssue(kind: .byteBudget, source: "/log", detail: "Stopped early")
        let page = makePage(
            contributions: [contribution(kind: .mcpSchema, amount: 20)],
            defaults: [defaultSkill()],
            issues: [issue]
        )
        guard case .finishScan = ContextOpportunity.choose(from: page) else {
            return XCTFail("Expected coverage review to take priority")
        }
    }

    func testCapturedMCPSchemasTakePriorityWithEvidenceTotal() {
        let page = makePage(contributions: [
            contribution(name: "one", kind: .mcpSchema, amount: 12),
            contribution(name: "two", kind: .mcpSchema, amount: 8),
            contribution(name: "instruction", kind: .instruction, amount: 100),
        ])
        guard case .reviewCapturedTools(let count, let estimate, _) = ContextOpportunity.choose(from: page) else {
            return XCTFail("Expected captured MCP review")
        }
        XCTAssertEqual(count, 2)
        XCTAssertEqual(estimate, 20)
    }

    func testCapturedSetupFallbackWorksWithoutMCPSchemas() {
        let page = makePage(contributions: [
            contribution(name: "tool", kind: .toolSchema, amount: 30),
            contribution(name: "agent", kind: .agent, amount: 10),
        ])
        guard case .reviewCapturedSetup(let count, let estimate, _) = ContextOpportunity.choose(from: page) else {
            return XCTFail("Expected captured setup review")
        }
        XCTAssertEqual(count, 2)
        XCTAssertEqual(estimate, 40)
    }

    func testCapturedOpportunityUsesContributionTimeInsteadOfScanTime() {
        let capturedAt = Date(timeIntervalSince1970: 50)
        let laterCapturedAt = Date(timeIntervalSince1970: 75)
        let scannedAt = Date(timeIntervalSince1970: 500)
        let page = makePage(
            contributions: [
                contribution(name: "first", kind: .toolSchema, amount: 10, observedAt: capturedAt),
                contribution(name: "latest", kind: .agent, amount: 10, observedAt: laterCapturedAt),
            ],
            scannedAt: scannedAt
        )
        guard case .reviewCapturedSetup(_, _, let evidenceAt) = ContextOpportunity.choose(from: page) else {
            return XCTFail("Expected captured setup review")
        }
        XCTAssertEqual(evidenceAt, laterCapturedAt)
        XCTAssertNotEqual(evidenceAt, scannedAt)
    }

    func testCurrentGlobalSkillsAreFallbackAvailabilityNotSavings() {
        let page = makePage(contributions: [], defaults: [defaultSkill(), defaultSkill(name: "second")])
        XCTAssertEqual(ContextOpportunity.choose(from: page), .reviewDefaults(globalSkillCount: 2))
    }

    func testNoEvidenceFallsBackToSessionInspection() {
        XCTAssertEqual(ContextOpportunity.choose(from: makePage(contributions: [])), .inspectSession)
    }

    private func makePage(
        contributions: [ContextContribution],
        defaults: [ContextDefaultComponent] = [],
        issues: [ContextCoverageIssue] = [],
        scannedAt: Date = Date(timeIntervalSince1970: 100)
    ) -> ContextPage {
        let date = scannedAt
        let key = ContextSessionKey(provider: .claude, home: "/tmp/home", id: "session")
        let session = ContextSessionSummary(
            key: key,
            projectPath: "/tmp/project",
            sourcePath: "/tmp/session.jsonl",
            lastEventAt: date,
            fileModifiedAt: date,
            isAgentSession: false
        )
        let coverage = ContextCoverage(bytesRead: 10, bytesDiscovered: 10, issues: issues)
        let report = ContextSessionReport(
            session: session,
            usage: .init(cumulative: nil, lastRequest: nil),
            contributions: contributions,
            observedAt: date,
            coverage: coverage
        )
        return ContextPage(
            sessions: [session],
            selected: report,
            defaults: .init(components: defaults, observedAt: date),
            coverage: coverage,
            scannedAt: date
        )
    }

    private func contribution(
        name: String = "schema",
        kind: ContextContributionKind,
        amount: Int64,
        observedAt: Date = Date(timeIntervalSince1970: 100)
    ) -> ContextContribution {
        ContextContribution(
            id: name,
            name: name,
            kind: kind,
            owner: nil,
            value: .reconstructed(amount, method: "fixture"),
            scope: .project,
            sourcePath: nil,
            evidenceBasis: .recorded,
            sourceNote: nil,
            observedAt: observedAt
        )
    }

    private func defaultSkill(name: String = "skill") -> ContextDefaultComponent {
        ContextDefaultComponent(
            id: name,
            provider: .claude,
            name: name,
            kind: .skill,
            scope: .global,
            sourcePath: "/tmp/" + name,
            projection: .unknown("fixture"),
            canMakeUserInvocableOnly: false
        )
    }
}
