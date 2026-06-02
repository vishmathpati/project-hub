import XCTest
@testable import ProjectHub

final class CompatibilityReportMarkdownTests: XCTestCase {
    func testFindingReportHeaderIncludesApplicabilityColumns() {
        XCTAssertEqual(CompatibilityView.findingReportHeaderColumns, [
            "Severity",
            "State",
            "Tool",
            "Surface",
            "Scope",
            "Runtime",
            "Owner",
            "Write",
            "After fix",
            "Finding",
            "Subject",
            "Evidence path"
        ])
    }

    func testFindingReportValuesIncludeSurfaceScopeRuntimeWriteAndRestartContext() {
        let surface = matrixEntry(
            toolID: .codexCLI,
            scope: .global,
            label: "Codex global config",
            path: "/Users/example/.codex/config.toml",
            canWriteSafely: true,
            writeMethod: .file,
            requiresRestartAfterWrite: true
        )
        let issue = CompatibilityIssue(
            id: UUID(),
            code: .settingsProfileScopedPolicy,
            severity: .warning,
            toolID: .codexCLI,
            surfaceID: surface.id,
            title: "Profile policy is conditional",
            detail: "This policy only applies to one runtime profile.",
            path: "/Users/example/.codex/config.toml",
            subjectPath: "profiles.work.plugins.docs.mcp_servers.search.enabled",
            fixHint: nil,
            metadata: ["codexPluginPolicyProfileName": "work"]
        )

        let values = CompatibilityView.findingReportValues(
            for: issue,
            surface: surface,
            evidencePath: issue.path,
            shortPath: { $0.replacingOccurrences(of: "/Users/example", with: "~") },
            stateLabel: { $0.label }
        )
        let row = Dictionary(uniqueKeysWithValues: zip(CompatibilityView.findingReportHeaderColumns, values))

        XCTAssertEqual(row["Surface"], "Codex global config")
        XCTAssertEqual(row["Scope"], "Global")
        XCTAssertEqual(row["Runtime"], "Codex CLI - codex --profile work")
        XCTAssertEqual(row["Owner"], "~/.codex/config.toml")
        XCTAssertEqual(row["Write"], "Preview write")
        XCTAssertEqual(row["After fix"], "Restart required")
        XCTAssertEqual(row["Evidence path"], "~/.codex/config.toml")
    }

    private func matrixEntry(
        toolID: CompatibilityToolID,
        scope: CompatibilityScope,
        label: String,
        path: String?,
        canWriteSafely: Bool,
        writeMethod: CompatibilityWriteMethod,
        requiresRestartAfterWrite: Bool
    ) -> CompatibilityMatrixEntry {
        CompatibilityMatrixEntry(
            id: "surface-\(toolID.rawValue)-\(label)",
            toolID: toolID,
            kind: .settings,
            scope: scope,
            label: label,
            path: path,
            format: .toml,
            fileControlled: path != nil,
            canWriteSafely: canWriteSafely,
            writeMethod: writeMethod,
            requiresRestartAfterWrite: requiresRestartAfterWrite,
            supportsDisable: false,
            supportsOAuth: false,
            supportsEnvExpansion: false,
            precedence: 10,
            note: "Test surface"
        )
    }
}
