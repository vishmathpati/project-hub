import Foundation

// MARK: - Plan and apply one MCP server definition across installed editors.

enum EditorSyncState {
    case notInstalled
    case create
    case update
    case inSync
    case blocked(String)
}

struct EditorSyncPlanItem: Identifiable {
    var id: String { toolID }
    let toolID: String
    let label: String
    let path: String
    let state: EditorSyncState

    var installed: Bool {
        if case .notInstalled = state { return false }
        return true
    }

    var needsWrite: Bool {
        switch state {
        case .create, .update: return true
        default:               return false
        }
    }
}

struct EditorSyncResult: Identifiable {
    enum Outcome: Equatable {
        case written
        case unchanged
        case skipped
        case refused
        case failed
    }

    var id: String { toolID }
    let toolID: String
    let label: String
    let outcome: Outcome
    let message: String
}

enum EditorSync {

    /// One row per editor the app reads. Installed editors are checked against
    /// this definition; the rest report as not installed and are never written.
    static func plan(
        server: String,
        config: [String: Any],
        tools: [ToolSummary]
    ) -> [EditorSyncPlanItem] {
        tools.compactMap { tool in
            guard ConfigWriter.supportsNativeWrite(toolID: tool.toolID),
                  let path = ConfigWriter.previewPath(toolID: tool.toolID, scope: .user, projectRoot: nil)
            else { return nil }

            guard tool.detected else {
                return EditorSyncPlanItem(toolID: tool.toolID, label: tool.label, path: path, state: .notInstalled)
            }
            if let blocker = ConfigWriter.nativeWriteBlocker(toolID: tool.toolID, scope: .user, name: server, config: config) {
                return EditorSyncPlanItem(toolID: tool.toolID, label: tool.label, path: path, state: .blocked(blocker))
            }
            guard let preview = ConfigWriter.previewWriteBatch(
                toolID: tool.toolID, scope: .user, projectRoot: nil,
                servers: [(name: server, config: config)]
            ) else {
                return EditorSyncPlanItem(toolID: tool.toolID, label: tool.label, path: path,
                                          state: .blocked("Project Hub could not build a preview for this file."))
            }

            let state: EditorSyncState
            if ConfigWriter.readServer(toolID: tool.toolID, name: server) == nil {
                state = .create
            } else if preview.before == preview.after {
                state = .inSync
            } else {
                state = .update
            }
            return EditorSyncPlanItem(toolID: tool.toolID, label: tool.label, path: path, state: state)
        }
    }

    /// Applies the plan row by row so every editor reports its own outcome.
    static func apply(
        server: String,
        config: [String: Any],
        plan: [EditorSyncPlanItem]
    ) -> [EditorSyncResult] {
        plan.map { item in
            switch item.state {
            case .notInstalled: return EditorSyncResult(toolID: item.toolID, label: item.label, outcome: .skipped, message: "Not installed — skipped")
            case .inSync:       return EditorSyncResult(toolID: item.toolID, label: item.label, outcome: .unchanged, message: "Already up to date")
            case .blocked(let reason): return EditorSyncResult(toolID: item.toolID, label: item.label, outcome: .refused, message: reason)
            case .create, .update:     return writeItem(server: server, config: config, item: item)
            }
        }
    }

    private static func writeItem(
        server: String,
        config: [String: Any],
        item: EditorSyncPlanItem
    ) -> EditorSyncResult {
        guard let preview = ConfigWriter.previewWriteBatch(
            toolID: item.toolID, scope: .user, projectRoot: nil,
            servers: [(name: server, config: config)]
        ) else {
            return EditorSyncResult(toolID: item.toolID, label: item.label,
                                    outcome: .failed, message: "Could not build a preview before writing.")
        }
        guard preview.before != preview.after else {
            return EditorSyncResult(toolID: item.toolID, label: item.label,
                                    outcome: .unchanged, message: "Already up to date")
        }
        do {
            try ConfigWriter.applyTextPreview(
                configPath: item.path,
                expectedBefore: preview.before,
                approvedAfter: preview.after
            )
            return EditorSyncResult(toolID: item.toolID, label: item.label,
                                    outcome: .written, message: "Written to \(item.path)")
        } catch {
            return EditorSyncResult(toolID: item.toolID, label: item.label,
                                    outcome: .failed, message: error.localizedDescription)
        }
    }
}
