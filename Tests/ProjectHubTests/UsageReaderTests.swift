import XCTest
@testable import ProjectHub

final class UsageReaderTests: XCTestCase {
    func testParsesClaudeAndCodexUsageShapes() {
        let claude: [String: Any] = [
            "usage": ["input_tokens": 10, "output_tokens": 4]
        ]
        XCTAssertEqual(UsageReader.tokens(in: claude).total, 14)

        let wrapped: [String: Any] = [
            "type": "event_msg",
            "payload": [
                "info": [
                    "last_token_usage": [
                        "input_tokens": 100,
                        "output_tokens": 20,
                        "total_tokens": 120
                    ],
                    "total_token_usage": [
                        "input_tokens": 32245,
                        "output_tokens": 244,
                        "total_tokens": 32489
                    ]
                ]
            ]
        ]
        XCTAssertEqual(UsageReader.tokens(in: wrapped).last, 120)
        XCTAssertEqual(UsageReader.tokens(in: wrapped).total, 32489)
    }

    func testClaudeUsageWindowsMapOfficialKeys() {
        let body: [String: Any] = [
            "five_hour": ["utilization": 23.5, "resets_at": 1738425600],
            "seven_day": ["used_percentage": 41.2, "resets_at": "2026-07-03T06:59:59Z"],
            "limits": [[
                "kind": "weekly_scoped",
                "percent": 94,
                "scope": ["model": ["display_name": "Fable"]]
            ]]
        ]
        let windows = ClaudeUsageClient.windows(from: body)
        XCTAssertEqual(windows.map(\.title), ["5-hour", "Weekly", "Weekly Fable"])
        XCTAssertEqual(windows[0].usedPercent, 23.5)
        XCTAssertEqual(windows[1].usedPercent, 41.2)
        XCTAssertEqual(windows[2].usedPercent, 94)
        XCTAssertEqual(windows[0].remainingPercent, 76.5, accuracy: 0.01)
    }

    func testPricesClaudeUsageWithoutNetwork() {
        let bag: [String: Any] = [
            "input_tokens": 1_000_000,
            "output_tokens": 1_000_000,
            "cache_creation_input_tokens": 0,
            "cache_read_input_tokens": 0,
        ]
        let priced = UsageReader.priced(bag, model: "claude-sonnet-4", explicitCost: nil)
        XCTAssertEqual(priced.tokens, 2_000_000)
        XCTAssertEqual(priced.cost, 18.0, accuracy: 0.01)
    }

    func testUsesExplicitCostUSDWhenPresent() {
        let bag: [String: Any] = ["input_tokens": 10, "output_tokens": 4]
        let priced = UsageReader.priced(bag, model: "claude-opus-5", explicitCost: 1.25)
        XCTAssertEqual(priced.cost, 1.25, accuracy: 0.001)
        XCTAssertEqual(priced.tokens, 14)
    }
}
