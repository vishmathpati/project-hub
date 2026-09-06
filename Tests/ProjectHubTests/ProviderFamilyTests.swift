import XCTest
@testable import ProjectHub

final class ProviderFamilyTests: XCTestCase {
    func testClaudeCodeAndDesktopShareAFamily() {
        XCTAssertEqual(ProviderFamily.groupID(for: "claude-code"), "claude")
        XCTAssertEqual(ProviderFamily.groupID(for: "claude-desktop"), "claude")
        XCTAssertEqual(ProviderFamily.displayName(for: "claude"), "Claude")
        XCTAssertEqual(ProviderFamily.memberLabel(for: "claude-code"), "Code")
        XCTAssertEqual(ProviderFamily.memberLabel(for: "claude-desktop"), "Desktop")
    }

    func testOtherProvidersStayUngrouped() {
        XCTAssertEqual(ProviderFamily.groupID(for: "cursor"), "cursor")
        XCTAssertEqual(ProviderFamily.displayName(for: "cursor"), "Cursor")
    }

    func testGroupedKeepsClaudeMembersTogether() {
        struct Item { let id: String }
        let grouped = ProviderFamily.grouped(
            [Item(id: "claude-code"), Item(id: "cursor"), Item(id: "claude-desktop")],
            id: \.id
        )
        XCTAssertEqual(grouped.map(\.id), ["claude", "cursor"])
        XCTAssertEqual(grouped[0].items.map(\.id), ["claude-code", "claude-desktop"])
    }

    func testUniqueTileIDsCollapseClaude() {
        XCTAssertEqual(
            ProviderFamily.uniqueTileIDs(from: ["claude-code", "claude-desktop", "cursor"]),
            ["claude-code", "cursor"]
        )
    }
}
