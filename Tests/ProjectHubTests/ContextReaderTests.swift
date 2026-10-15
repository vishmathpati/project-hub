import XCTest
@testable import ProjectHub

final class ContextReaderTests: XCTestCase {
    func testClaudeDeduplicatesStreamingUsageAndKeepsCacheSegmentsDisjoint() async throws {
        let fixture = try Fixture()
        try fixture.writeClaude([
            ["cwd": fixture.project.path, "sessionId": "claude-1", "timestamp": "2026-10-15T08:00:00Z"],
            Self.assistant(message: "m1", request: "r1", input: 10, write: 2, read: 3, output: 1, timestamp: "2026-10-15T08:00:01Z"),
            Self.assistant(message: "m1", request: "r1", input: 12, write: 4, read: 6, output: 2, timestamp: "2026-10-15T08:00:02Z"),
            Self.assistant(message: "m2", request: "r2", input: 5, write: 0, read: 7, output: 3, timestamp: "2026-10-15T08:00:03Z"),
        ])

        let page = try await fixture.read()
        let report = try XCTUnwrap(page.selected)
        XCTAssertEqual(report.session.key.provider, .claude)
        XCTAssertEqual(report.usage.cumulative, .init(freshInput: 17, cacheWrite: 4, cacheRead: 13, output: 5))
        XCTAssertEqual(report.usage.lastRequest, .init(freshInput: 5, cacheWrite: 0, cacheRead: 7, output: 3))
        XCTAssertFalse(report.coverage.issues.contains { $0.kind == .incompleteIdentity })
    }

    func testRealClaudeRowsMayRepeatCwdWithoutHidingUsageOrAttachments() async throws {
        let fixture = try Fixture()
        var usage = Self.assistant(message: "m", request: "r", input: 7, write: 2, read: 3, output: 1, timestamp: nil)
        usage["cwd"] = fixture.project.path
        usage["sessionId"] = "repeated-metadata"
        try fixture.writeClaude([
            ["cwd": fixture.project.path, "sessionId": "repeated-metadata"],
            usage,
            [
                "cwd": fixture.project.path,
                "sessionId": "repeated-metadata",
                "attachment": ["type": "skill_listing", "names": ["alpha"], "content": "- alpha: captured"],
            ],
        ])

        let page = try await fixture.read()
        XCTAssertEqual(page.selected?.usage.cumulative?.total, 13)
        XCTAssertEqual(page.selected?.contributions.first?.name, "alpha")
    }

    func testClaudeDeduplicatesCopiedAssistantRecordsByMessageIDWithoutRequestID() async throws {
        let fixture = try Fixture()
        var first = Self.assistant(message: "stable-message", request: "unused", input: 4, write: 1, read: 2, output: 1, timestamp: nil)
        var latest = Self.assistant(message: "stable-message", request: "unused", input: 9, write: 2, read: 3, output: 2, timestamp: nil)
        first.removeValue(forKey: "requestId")
        latest.removeValue(forKey: "requestId")
        try fixture.writeClaude([
            ["cwd": fixture.project.path, "sessionId": "message-fallback"],
            first,
            latest,
        ])

        let page = try await fixture.read()
        XCTAssertEqual(page.selected?.usage.cumulative, .init(freshInput: 9, cacheWrite: 2, cacheRead: 3, output: 2))
        XCTAssertFalse(page.selected?.coverage.issues.contains { $0.kind == .incompleteIdentity } ?? true)
    }

    func testNestedClaudeAgentLogGetsDistinctStableSessionIdentity() async throws {
        let fixture = try Fixture()
        try fixture.writeClaude([["cwd": fixture.project.path, "sessionId": "shared"]])
        let child = fixture.claudeSessionURL.deletingLastPathComponent()
            .appendingPathComponent("shared/subagents/agent-a.jsonl")
        try FileManager.default.createDirectory(at: child.deletingLastPathComponent(), withIntermediateDirectories: true)
        var childData = try Self.jsonLine(["cwd": fixture.project.path, "sessionId": "shared"])
        childData.append(try Self.jsonLine(Self.assistant(message: "agent", request: "r", input: 1, write: 0, read: 0, output: 1, timestamp: nil)))
        try childData.write(to: child)

        let page = try await ContextReader.read(
            projectPath: fixture.project.path,
            homes: .init(claude: fixture.claudeHome.path, codex: fixture.codexHome.path, user: fixture.root.path)
        )
        let matching = page.sessions.filter { $0.key.provider == .claude }
        XCTAssertEqual(matching.count, 2)
        XCTAssertEqual(Set(matching.map(\.key)).count, 2)
        XCTAssertEqual(matching.filter(\.isAgentSession).count, 1)
        XCTAssertTrue(matching.first(where: \.isAgentSession)?.key.id.contains(":agent:") == true)
    }

    func testAggregateCombinedTotalOverflowIsCoverageInsteadOfTrap() async throws {
        let fixture = try Fixture()
        try fixture.writeClaude([
            ["cwd": fixture.project.path, "sessionId": "overflow"],
            Self.assistant(message: "m1", request: "r1", input: 4_000_000_000_000_000_000, write: 0, read: 0, output: 4_000_000_000_000_000_000, timestamp: nil),
            Self.assistant(message: "m2", request: "r2", input: 1_000_000_000_000_000_000, write: 0, read: 0, output: 1_000_000_000_000_000_000, timestamp: nil),
        ])

        let page = try await fixture.read()
        XCTAssertNil(page.selected?.usage.cumulative)
        XCTAssertTrue(page.selected?.coverage.issues.contains { $0.kind == .invalidCounters } == true)
    }

    func testPartialUsageCannotReplacePriorValidClaudeOrCodexCounters() async throws {
        let fixture = try Fixture()
        try fixture.writeClaude([
            ["cwd": fixture.project.path, "sessionId": "partial-claude"],
            Self.assistant(message: "m", request: "r", input: 12, write: 1, read: 2, output: 3, timestamp: nil),
            ["type": "assistant", "requestId": "r", "message": ["id": "m", "usage": ["input_tokens": 99]]],
        ])
        try fixture.writeCodex([
            ["type": "session_meta", "payload": ["id": "partial-codex", "cwd": fixture.project.path]],
            Self.codexCount(totalInput: 40, cached: 10, output: 5, reasoning: 2, lastInput: 10, lastCached: 2, lastOutput: 1),
            ["type": "event_msg", "payload": ["info": ["total_token_usage": ["input_tokens": 999]]]],
        ])

        let claude = try await fixture.read()
        XCTAssertEqual(claude.selected?.usage.cumulative, .init(freshInput: 12, cacheWrite: 1, cacheRead: 2, output: 3))
        XCTAssertTrue(claude.selected?.coverage.issues.contains { $0.kind == .invalidCounters } == true)
        let codex = try await fixture.read(preferred: .codex)
        XCTAssertEqual(codex.selected?.usage.cumulative, .init(freshInput: 30, cacheWrite: 0, cacheRead: 10, output: 5))
        XCTAssertTrue(codex.selected?.coverage.issues.contains { $0.kind == .invalidCounters } == true)
    }

    func testMCPInstructionBlocksAreNotLabeledAsSchemas() async throws {
        let fixture = try Fixture()
        try fixture.writeClaude([
            ["cwd": fixture.project.path, "sessionId": "mcp-instructions"],
            ["attachment": [
                "type": "mcp_instructions_delta",
                "addedNames": ["docs"],
                "addedBlocks": ["Use this server for documentation."],
            ]],
        ])

        let page = try await fixture.read()
        let row = try XCTUnwrap(page.selected?.contributions.first(where: { $0.name == "docs" }))
        XCTAssertEqual(row.kind, .mcpInstructions)
    }

    func testMissingSessionIDKeepsStableFileIdentityAcrossRefreshes() async throws {
        let fixture = try Fixture()
        try fixture.writeClaude([["cwd": fixture.project.path]])
        let first = try await fixture.read()
        let second = try await fixture.read()
        XCTAssertEqual(first.selected?.session.key.id, "session")
        XCTAssertEqual(second.selected?.session.key, first.selected?.session.key)
    }

    func testAgentDeltaRemovesTypesAndInitialListingReplacesPriorCatalog() async throws {
        let fixture = try Fixture()
        try fixture.writeClaude([
            ["cwd": fixture.project.path, "sessionId": "agent-deltas"],
            ["attachment": ["type": "agent_listing_delta", "isInitial": true, "addedLines": ["- old: old agent", "- keep: kept agent"]]],
            ["attachment": ["type": "agent_listing_delta", "removedTypes": ["old"]]],
        ])
        let removed = try await fixture.read()
        XCTAssertEqual(removed.selected?.contributions.filter { $0.kind == .agent }.map(\.name), ["keep"])

        try fixture.writeClaude([
            ["cwd": fixture.project.path, "sessionId": "agent-deltas"],
            ["attachment": ["type": "agent_listing_delta", "addedLines": ["- old: old agent"]]],
            ["attachment": ["type": "agent_listing_delta", "isInitial": true, "addedLines": ["- new: new agent"]]],
        ])
        let replaced = try await fixture.read()
        XCTAssertEqual(replaced.selected?.contributions.filter { $0.kind == .agent }.map(\.name), ["new"])
    }

    func testCodexUsesLatestCumulativeAndSubtractsCachedInputOnce() async throws {
        let fixture = try Fixture()
        try fixture.writeCodex([
            ["type": "session_meta", "payload": ["id": "codex-1", "cwd": fixture.project.path, "timestamp": "2026-10-15T08:00:00Z"]],
            Self.codexCount(totalInput: 100, cached: 40, output: 20, reasoning: 8, lastInput: 30, lastCached: 10, lastOutput: 5),
            Self.codexCount(totalInput: 160, cached: 70, output: 35, reasoning: 12, lastInput: 60, lastCached: 30, lastOutput: 15),
        ])

        let page = try await fixture.read(preferred: .codex)
        let usage = try XCTUnwrap(page.selected?.usage)
        XCTAssertEqual(usage.cumulative, .init(freshInput: 90, cacheWrite: 0, cacheRead: 70, output: 35))
        XCTAssertEqual(usage.lastRequest, .init(freshInput: 30, cacheWrite: 0, cacheRead: 30, output: 15))
        XCTAssertEqual(usage.cumulative?.total, 195)
    }

    func testInvalidCodexCountersAndRegressionAreVisibleCoverage() async throws {
        let fixture = try Fixture()
        try fixture.writeCodex([
            ["type": "session_meta", "payload": ["id": "codex-invalid", "cwd": fixture.project.path]],
            Self.codexCount(totalInput: 100, cached: 20, output: 30, reasoning: 10, lastInput: 20, lastCached: 5, lastOutput: 2),
            Self.codexCount(totalInput: 80, cached: 90, output: 20, reasoning: 5, lastInput: 10, lastCached: 20, lastOutput: 2),
            Self.codexCount(totalInput: 70, cached: 10, output: 20, reasoning: 5, lastInput: 10, lastCached: 2, lastOutput: 2),
        ])

        let page = try await fixture.read(preferred: .codex)
        let issues = try XCTUnwrap(page.selected).coverage.issues
        XCTAssertTrue(issues.contains { $0.kind == .invalidCounters })
        XCTAssertTrue(issues.contains { $0.kind == .counterRegression })
        XCTAssertEqual(page.selected?.usage.cumulative, .init(freshInput: 60, cacheWrite: 0, cacheRead: 10, output: 20))
    }

    func testCapturedCatalogReplacementIsNotDoubleCountedAndCurrentPathIsCandidateOnly() async throws {
        let fixture = try Fixture()
        let skill = fixture.project.appendingPathComponent(".claude/skills/alpha/SKILL.md")
        try FileManager.default.createDirectory(at: skill.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "---\nname: alpha\ndescription: current\n---\nCurrent body".write(to: skill, atomically: true, encoding: .utf8)
        try fixture.writeClaude([
            ["cwd": fixture.project.path, "sessionId": "catalog"],
            ["attachment": ["type": "skill_listing", "names": ["alpha"], "content": "- alpha: old"]],
            ["attachment": ["type": "skill_listing", "names": ["alpha"], "content": "- alpha: replacement description"]],
        ])

        let page = try await fixture.read()
        let rows = try XCTUnwrap(page.selected).contributions.filter { $0.kind == .skill && $0.name == "alpha" }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].value, .reconstructed(8, method: "captured characters ÷ 4"))
        XCTAssertEqual(rows[0].evidenceBasis, .currentCandidate)
        XCTAssertEqual(rows[0].scope, .project)
        XCTAssertEqual(rows[0].sourcePath, skill.path)
    }

    func testSkillNamesKeepPluginNamespaceAndCaptureMultilineAndBareEntries() async throws {
        let fixture = try Fixture()
        try fixture.writeClaude([
            ["cwd": fixture.project.path, "sessionId": "skills"],
            ["attachment": [
                "type": "skill_listing",
                "names": ["plugin:review", "init"],
                "content": "- plugin:review: First line\n  continued detail\n- init",
            ]],
        ])

        let page = try await fixture.read()
        let contributions = try XCTUnwrap(page.selected).contributions
        let plugin = try XCTUnwrap(contributions.first(where: { $0.name == "plugin:review" }))
        XCTAssertEqual(plugin.owner, "plugin")
        XCTAssertEqual(plugin.value, .reconstructed(12, method: "captured characters ÷ 4"))
        XCTAssertNotNil(contributions.first(where: { $0.name == "init" }))
    }

    func testInstructionPathsRemainDistinctAndAncestorFileGetsAncestorScope() async throws {
        let fixture = try Fixture()
        let projectInstruction = fixture.project.appendingPathComponent("CLAUDE.md")
        let ancestorInstruction = fixture.root.appendingPathComponent("CLAUDE.md")
        try fixture.writeClaude([
            ["cwd": fixture.project.path, "sessionId": "instructions"],
            ["attachment": [
                "type": "instructions",
                "files": [
                    ["path": projectInstruction.path, "type": "project", "content": "project"],
                    ["path": ancestorInstruction.path, "type": "ancestor", "content": "ancestor"],
                ],
            ]],
        ])

        let page = try await fixture.read()
        let instructions = try XCTUnwrap(page.selected).contributions.filter { $0.kind == .instruction }
        XCTAssertEqual(instructions.count, 2)
        XCTAssertEqual(instructions.first(where: { $0.sourcePath == projectInstruction.path })?.scope, .project)
        XCTAssertEqual(instructions.first(where: { $0.sourcePath == ancestorInstruction.path })?.scope, .ancestor)
    }

    func testGlobalSettingsAndProjectMemoryUseApplicabilityScope() async throws {
        let fixture = try Fixture()
        let globalSettings = fixture.root.appendingPathComponent(".claude.json")
        let encoded = fixture.project.path.unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) ? String($0) : "-"
        }.joined()
        let memory = fixture.claudeHome.appendingPathComponent("projects/\(encoded)/memory/MEMORY.md")
        try fixture.writeClaude([
            ["cwd": fixture.project.path, "sessionId": "scope-specials"],
            ["attachment": [
                "type": "instructions",
                "files": [
                    ["path": globalSettings.path, "content": "global"],
                    ["path": memory.path, "content": "memory"],
                ],
            ]],
        ])

        let page = try await fixture.read()
        let rows = try XCTUnwrap(page.selected).contributions
        XCTAssertEqual(rows.first(where: { $0.sourcePath == globalSettings.path })?.scope, .global)
        XCTAssertEqual(rows.first(where: { $0.sourcePath == memory.path })?.scope, .project)
    }

    func testLatestPromptSnapshotReplacesSchemasAndDeferredCatalogIsExcluded() async throws {
        let fixture = try Fixture()
        try fixture.writeClaude([
            ["cwd": fixture.project.path, "sessionId": "tools"],
            ["attachment": [
                "type": "prompt_snapshot",
                "tools": [["name": "old", "description": "old", "schema": ["type": "object"]]],
            ]],
            ["attachment": ["type": "deferred_tools_delta", "addedLines": ["catalog_only: description"]]],
            ["attachment": [
                "type": "prompt_snapshot",
                "tools": [["name": "mcp__docs__search", "description": "latest", "schema": ["type": "object"]]],
            ]],
        ])

        let page = try await fixture.read()
        let contributions = try XCTUnwrap(page.selected).contributions
        XCTAssertNil(contributions.first(where: { $0.name == "old" }))
        XCTAssertNil(contributions.first(where: { $0.name == "catalog_only" }))
        let latest = try XCTUnwrap(contributions.first(where: { $0.name == "mcp__docs__search" }))
        XCTAssertEqual(latest.owner, "docs")
        XCTAssertEqual(latest.kind, .mcpSchema)
    }

    func testBooleanAndFractionalCountersAreRejected() async throws {
        let fixture = try Fixture()
        try fixture.writeClaude([
            ["cwd": fixture.project.path, "sessionId": "numeric"],
            [
                "type": "assistant", "requestId": "r", "message": [
                    "id": "m", "usage": [
                        "input_tokens": true,
                        "cache_creation_input_tokens": 0,
                        "cache_read_input_tokens": 0,
                        "output_tokens": 1.5,
                    ],
                ],
            ],
        ])

        let page = try await fixture.read()
        let report = try XCTUnwrap(page.selected)
        XCTAssertNil(report.usage.cumulative)
        XCTAssertTrue(report.coverage.issues.contains { $0.kind == .invalidCounters })
    }

    func testStreamsSelectedLogLargerThanEightMegabytes() async throws {
        let fixture = try Fixture()
        let file = fixture.claudeSessionURL
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        var data = try Self.jsonLine(["cwd": fixture.project.path, "sessionId": "large"])
        let padding = String(repeating: "x", count: 8_192)
        for _ in 0..<1_100 { data.append(try Self.jsonLine(["type": "noop", "padding": padding])) }
        data.append(try Self.jsonLine(Self.assistant(message: "m", request: "r", input: 9, write: 2, read: 4, output: 1, timestamp: nil)))
        try data.write(to: file)

        let page = try await fixture.read()
        let report = try XCTUnwrap(page.selected)
        XCTAssertGreaterThan(report.coverage.bytesRead, 8 * 1_024 * 1_024)
        XCTAssertEqual(report.usage.cumulative?.total, 16)
        XCTAssertTrue(report.coverage.isComplete)
    }

    func testBudgetAndOversizedRecordsAreNeverSilent() async throws {
        let fixture = try Fixture()
        try fixture.writeClaude([
            ["cwd": fixture.project.path, "sessionId": "bounded"],
            ["type": "noop", "padding": String(repeating: "x", count: 2_000)],
            Self.assistant(message: "m", request: "r", input: 1, write: 0, read: 0, output: 1, timestamp: nil),
        ])
        let budget = ContextScanBudget(maximumBytes: 1_200, maximumRecordBytes: 256, maximumSessions: 20)

        let page = try await fixture.read(budget: budget)
        let issues = try XCTUnwrap(page.selected).coverage.issues
        XCTAssertTrue(issues.contains { $0.kind == .oversizedRecord })
        XCTAssertTrue(issues.contains { $0.kind == .byteBudget })
        XCTAssertFalse(page.coverage.isComplete)
    }

    func testCancellationPropagatesToStreamingScan() async throws {
        let fixture = try Fixture()
        try fixture.writeClaude([["cwd": fixture.project.path, "sessionId": "cancelled"]])
        let task = Task {
            try await fixture.read()
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        }
    }

    private static func assistant(
        message: String,
        request: String,
        input: Int,
        write: Int,
        read: Int,
        output: Int,
        timestamp: String?
    ) -> [String: Any] {
        var row: [String: Any] = [
            "type": "assistant",
            "requestId": request,
            "message": [
                "id": message,
                "usage": [
                    "input_tokens": input,
                    "cache_creation_input_tokens": write,
                    "cache_read_input_tokens": read,
                    "output_tokens": output,
                ],
            ],
        ]
        if let timestamp { row["timestamp"] = timestamp }
        return row
    }

    private static func codexCount(
        totalInput: Int,
        cached: Int,
        output: Int,
        reasoning: Int,
        lastInput: Int,
        lastCached: Int,
        lastOutput: Int
    ) -> [String: Any] {
        [
            "type": "event_msg",
            "payload": [
                "type": "token_count",
                "info": [
                    "total_token_usage": [
                        "input_tokens": totalInput,
                        "cached_input_tokens": cached,
                        "output_tokens": output,
                        "reasoning_output_tokens": reasoning,
                    ],
                    "last_token_usage": [
                        "input_tokens": lastInput,
                        "cached_input_tokens": lastCached,
                        "output_tokens": lastOutput,
                    ],
                ],
            ],
        ]
    }

    private final class Fixture: Sendable {
        let root: URL
        let project: URL
        let claudeHome: URL
        let codexHome: URL

        var claudeSessionURL: URL {
            let encoded = project.path.unicodeScalars.map {
                CharacterSet.alphanumerics.contains($0) ? String($0) : "-"
            }.joined()
            return claudeHome.appendingPathComponent("projects/\(encoded)/session.jsonl")
        }
        var codexSessionURL: URL { codexHome.appendingPathComponent("sessions/2026/10/session.jsonl") }

        init() throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            project = root.appendingPathComponent("project with spaces", isDirectory: true)
            claudeHome = root.appendingPathComponent(".claude", isDirectory: true)
            codexHome = root.appendingPathComponent(".codex", isDirectory: true)
            try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        }

        deinit {
            try? FileManager.default.removeItem(at: root)
        }

        func writeClaude(_ rows: [[String: Any]]) throws {
            try write(rows, to: claudeSessionURL)
        }

        func writeCodex(_ rows: [[String: Any]]) throws {
            try write(rows, to: codexSessionURL)
        }

        func read(
            preferred: ContextProvider = .claude,
            budget: ContextScanBudget = .interactive
        ) async throws -> ContextPage {
            let initial = try await ContextReader.read(
                projectPath: project.path,
                homes: .init(claude: claudeHome.path, codex: codexHome.path, user: root.path),
                budget: budget
            )
            let key = initial.sessions.first(where: { $0.key.provider == preferred })?.key
            return try await ContextReader.read(
                projectPath: project.path,
                homes: .init(claude: claudeHome.path, codex: codexHome.path, user: root.path),
                selected: key,
                budget: budget
            )
        }

        private func write(_ rows: [[String: Any]], to url: URL) throws {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            var data = Data()
            for row in rows { data.append(try ContextReaderTests.jsonLine(row)) }
            try data.write(to: url)
        }
    }

    private static func jsonLine(_ object: [String: Any]) throws -> Data {
        var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        data.append(0x0A)
        return data
    }
}
