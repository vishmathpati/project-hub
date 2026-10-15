import Foundation

enum ContextOpportunity: Equatable, Sendable {
    case finishScan(reason: String)
    case reviewCapturedTools(count: Int, estimatedTokens: Int64?, observedAt: Date)
    case reviewCapturedSetup(count: Int, estimatedTokens: Int64?, observedAt: Date)
    case reviewDefaults(globalSkillCount: Int)
    case inspectSession

    static func choose(from page: ContextPage) -> ContextOpportunity {
        if !page.coverage.isComplete {
            return .finishScan(reason: "Some local session evidence has coverage notes.")
        }

        if let report = page.selected {
            let schemas = report.contributions.filter { $0.kind == .mcpSchema }
            if !schemas.isEmpty {
                return .reviewCapturedTools(
                    count: schemas.count,
                    estimatedTokens: estimatedTotal(schemas),
                    observedAt: latestCaptureDate(schemas)
                )
            }

            let setup = report.contributions.filter {
                switch $0.kind {
                case .toolSchema, .mcpInstructions, .instruction, .agent, .skill: true
                case .mcpSchema: false
                }
            }
            if !setup.isEmpty {
                return .reviewCapturedSetup(
                    count: setup.count,
                    estimatedTokens: estimatedTotal(setup),
                    observedAt: latestCaptureDate(setup)
                )
            }
        }

        let globalSkills = page.defaults.components.filter {
            $0.kind == .skill && $0.scope == .global
        }.count
        if globalSkills > 0 {
            return .reviewDefaults(globalSkillCount: globalSkills)
        }
        return .inspectSession
    }

    private static func estimatedTotal(_ rows: [ContextContribution]) -> Int64? {
        let amounts = rows.compactMap(\.value.amount)
        return amounts.isEmpty ? nil : amounts.reduce(0, +)
    }

    private static func latestCaptureDate(_ rows: [ContextContribution]) -> Date {
        rows.map(\.observedAt).max() ?? .distantPast
    }
}
