import XCTest
@testable import ProjectHub

final class ImportCredentialPlannerTests: XCTestCase {
    func testPlannerMergesMetadataEnvHeadersAndURLPlaceholders() {
        let server = ParsedServer(
            name: "analytics",
            config: [
                "url": "https://${TENANT_ID}.example.com/mcp?token=${API_TOKEN}",
                "headers": [
                    "X-API-Key": "${API_TOKEN}",
                    "X-Static": "static"
                ],
                "env": [
                    "API_TOKEN": "${API_TOKEN}",
                    "LOCAL_ONLY": "${LOCAL_ONLY}"
                ]
            ],
            credentialRequirements: [
                .init(
                    kind: .urlVariable,
                    name: "tenant_id",
                    envName: "TENANT_ID",
                    placeholder: "${TENANT_ID}",
                    required: true,
                    secret: false,
                    description: "Tenant slug",
                    source: "registry remote URL variable"
                )
            ]
        )

        let requirements = ImportCredentialPlanner.requirements(for: server)
        let hints = ImportCredentialPlanner.envHintNames(for: server)

        XCTAssertTrue(requirements.contains {
            $0.kind == .urlVariable
                && $0.name == "tenant_id"
                && $0.envName == "TENANT_ID"
                && $0.required
        })
        XCTAssertTrue(requirements.contains {
            $0.kind == .header
                && $0.name == "X-API-Key"
                && $0.envName == "API_TOKEN"
        })
        XCTAssertTrue(requirements.contains {
            $0.kind == .env
                && $0.name == "LOCAL_ONLY"
                && $0.envName == "LOCAL_ONLY"
        })
        XCTAssertEqual(hints, ["TENANT_ID", "API_TOKEN", "LOCAL_ONLY"])
        XCTAssertEqual(
            ImportCredentialPlanner.requirementSummary(for: server),
            "env API_TOKEN, LOCAL_ONLY / headers X-API-Key / URL values API_TOKEN, TENANT_ID"
        )
    }

    func testRequirementSummaryDedupesAndReturnsNilWhenEmpty() {
        let requirements: [ImportCredentialRequirement] = [
            .init(
                kind: .env,
                name: "LOCAL_ONLY",
                envName: "LOCAL_ONLY",
                placeholder: nil,
                required: false,
                secret: true,
                description: nil,
                source: "test"
            ),
            .init(
                kind: .env,
                name: "LOCAL_ONLY",
                envName: "LOCAL_ONLY",
                placeholder: nil,
                required: false,
                secret: true,
                description: nil,
                source: "duplicate"
            ),
            .init(
                kind: .header,
                name: "X-API-Key",
                envName: "API_TOKEN",
                placeholder: "${API_TOKEN}",
                required: true,
                secret: true,
                description: nil,
                source: "test"
            ),
            .init(
                kind: .urlVariable,
                name: "tenant_id",
                envName: "TENANT_ID",
                placeholder: "${TENANT_ID}",
                required: true,
                secret: false,
                description: nil,
                source: "test"
            )
        ]

        XCTAssertEqual(
            ImportCredentialPlanner.requirementSummary(for: requirements),
            "env LOCAL_ONLY / headers X-API-Key / URL values TENANT_ID"
        )
        XCTAssertNil(ImportCredentialPlanner.requirementSummary(for: []))
    }

    func testPlannerSkipsLiteralEnvDefaultsButKeepsPlaceholders() {
        let server = ParsedServer(
            name: "email",
            config: [
                "env": [
                    "EMAIL_API_KEY": "${EMAIL_API_KEY}",
                    "LOG_LEVEL": "debug",
                    "REGION": "us-east-1"
                ]
            ]
        )

        let requirements = ImportCredentialPlanner.requirements(for: server)
        let envRequirements = requirements.filter { $0.kind == .env }

        XCTAssertTrue(envRequirements.contains {
            $0.name == "EMAIL_API_KEY" && $0.envName == "EMAIL_API_KEY"
        })
        XCTAssertFalse(envRequirements.contains { $0.name == "LOG_LEVEL" })
        XCTAssertFalse(envRequirements.contains { $0.name == "REGION" })
        XCTAssertEqual(ImportCredentialPlanner.envHintNames(for: server), ["EMAIL_API_KEY"])
    }
}
