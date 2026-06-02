import XCTest
@testable import ProjectHub

final class CompatibilityFilterTests: XCTestCase {
    func testScopeFilterSeparatesProjectAndGlobalScopes() {
        XCTAssertTrue(CompatibilityScopeFilter.allSupported.includes(scope: .project))
        XCTAssertTrue(CompatibilityScopeFilter.allSupported.includes(scope: .global))

        XCTAssertTrue(CompatibilityScopeFilter.project.includes(scope: .project))
        XCTAssertTrue(CompatibilityScopeFilter.project.includes(scope: .localProjectUser))
        XCTAssertFalse(CompatibilityScopeFilter.project.includes(scope: .global))
        XCTAssertFalse(CompatibilityScopeFilter.project.includes(scope: .desktopApp))

        XCTAssertTrue(CompatibilityScopeFilter.global.includes(scope: .global))
        XCTAssertFalse(CompatibilityScopeFilter.global.includes(scope: .project))
        XCTAssertFalse(CompatibilityScopeFilter.global.includes(scope: .localProjectUser))
    }

    func testRuntimeFilterSeparatesCliAndDesktopTools() {
        XCTAssertTrue(CompatibilityRuntimeFilter.all.includes(toolID: .claudeCode, scope: .project))
        XCTAssertTrue(CompatibilityRuntimeFilter.all.includes(toolID: .claudeDesktop, scope: .desktopApp))

        XCTAssertTrue(CompatibilityRuntimeFilter.cli.includes(toolID: .claudeCode, scope: .project))
        XCTAssertTrue(CompatibilityRuntimeFilter.cli.includes(toolID: .codexCLI, scope: .global))
        XCTAssertFalse(CompatibilityRuntimeFilter.cli.includes(toolID: .claudeDesktop, scope: .global))
        XCTAssertFalse(CompatibilityRuntimeFilter.cli.includes(toolID: .codexDesktop, scope: .global))

        XCTAssertTrue(CompatibilityRuntimeFilter.desktop.includes(toolID: .claudeDesktop, scope: .global))
        XCTAssertTrue(CompatibilityRuntimeFilter.desktop.includes(toolID: .codexDesktop, scope: .project))
        XCTAssertTrue(CompatibilityRuntimeFilter.desktop.includes(toolID: .claudeCode, scope: .desktopApp))
        XCTAssertFalse(CompatibilityRuntimeFilter.desktop.includes(toolID: .claudeCode, scope: .project))
        XCTAssertFalse(CompatibilityRuntimeFilter.desktop.includes(toolID: .codexCLI, scope: .global))
    }
}
