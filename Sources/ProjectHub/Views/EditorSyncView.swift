import SwiftUI

// MARK: - Sync one MCP server definition to every installed editor.

struct EditorSyncView: View {
    @EnvironmentObject var mcpStore: MCPStore
    let onClose: () -> Void

    @State private var selectedServer: String? = nil
    @State private var plan: [EditorSyncPlanItem] = []
    @State private var sourceConfig: [String: Any]? = nil
    @State private var results: [EditorSyncResult]? = nil
    @State private var errorMessage: String? = nil
    @State private var confirming = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let results {
                resultView(results)
            } else {
                content
                footer
            }
        }
        .alert("Sync to \(writeCount) editor\(writeCount == 1 ? "" : "s")?", isPresented: $confirming) {
            Button("Sync now") { run() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Each editor's global config is backed up, then written. A file that changed since this plan was built is refused.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text("Sync MCP server")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Text(selectedServer ?? "pick a server")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.60))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(HubTheme.accent)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            picker
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text(errorMessage).font(.system(size: 11))
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }

            if !plan.isEmpty {
                Divider()
                planSection
            }
        }
        .frame(maxHeight: 360)
    }

    // MARK: - Server picker

    private var picker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Server")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if mcpStore.allServerNames.isEmpty {
                Text("No MCP servers to sync yet.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                Menu {
                    ForEach(mcpStore.allServerNames, id: \.self) { name in
                        Button(name) { select(name) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "server.rack").font(.system(size: 11))
                        Text(selectedServer ?? "Pick a server…").font(.system(size: 12))
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
                    }
                    .foregroundColor(selectedServer == nil ? .secondary : HubTheme.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(selectedServer == nil ? Color.secondary.opacity(0.07) : HubTheme.accent.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
            }
        }
    }

    // MARK: - Plan

    private var planSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(plan.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { HubRowSeparator() }
                    planRow(item)
                }
            }
            .hubCard()
            .padding(14)
        }
    }

    private func planRow(_ item: EditorSyncPlanItem) -> some View {
        let (status, word) = editorState(item.state)
        let caption = planCaption(item)
        return HubListRow(
            status: status,
            name: item.label,
            providers: [item.toolID],
            caption: caption,
            isDimmed: !item.installed
        ) { _ in
            stateWord(word, status)
        }
        .help(caption)
    }

    private func planCaption(_ item: EditorSyncPlanItem) -> String {
        switch item.state {
        case .blocked(let reason): return reason
        case .notInstalled:        return "Not installed — not written"
        default:                   return item.path
        }
    }

    private func editorState(_ state: EditorSyncState) -> (status: HubStatus, word: String) {
        switch state {
        case .create:       return (.ok, "will add")
        case .update:       return (.warn, "will update")
        case .inSync:       return (.neutral, "up to date")
        case .blocked:      return (.warn, "not written")
        case .notInstalled: return (.neutral, "not installed")
        }
    }

    private func outcomeState(_ outcome: EditorSyncResult.Outcome) -> (status: HubStatus, word: String) {
        switch outcome {
        case .written:   return (.ok, "written")
        case .unchanged: return (.neutral, "up to date")
        case .skipped:   return (.neutral, "skipped")
        case .refused:   return (.warn, "not written")
        case .failed:    return (.bad, "failed")
        }
    }

    private func stateWord(_ text: String, _ status: HubStatus) -> some View {
        Text(text)
            .font(HubFont.machine)
            .foregroundStyle(status == .neutral ? HubTheme.textFaint : status.color)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            HubButton(title: "Cancel", kind: .secondary) { onClose() }

            Spacer()

            HubButton(title: writeCount == 0 ? "Nothing to sync" : "Sync to \(writeCount)", kind: .primary) {
                confirming = true
            }
            .disabled(writeCount == 0)
            .opacity(writeCount == 0 ? 0.4 : 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var writeCount: Int { plan.filter(\.needsWrite).count }

    // MARK: - Result

    private func resultView(_ results: [EditorSyncResult]) -> some View {
        let written = results.filter { $0.outcome == .written }.count
        let failed  = results.filter { $0.outcome == .failed }.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: failed == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(failed == 0 ? HubTheme.ok : HubTheme.warn)
                    .font(.system(size: 20))
                Text(resultSummary(written: written, failed: failed))
                    .font(.system(size: 12))
                Spacer()
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        if index > 0 { HubRowSeparator() }
                        resultRow(result)
                    }
                }
                .hubCard()
            }
            .frame(maxHeight: 280)

            HStack {
                Spacer()
                HubButton(title: "Done", kind: .primary) { onClose() }
            }
        }
        .padding(14)
    }

    private func resultSummary(written: Int, failed: Int) -> String {
        if written == 0 && failed == 0 {
            return "Nothing to write — every editor is up to date or skipped."
        }
        if failed == 0 {
            return "Synced to \(written) editor\(written == 1 ? "" : "s")."
        }
        return "Synced to \(written) editor\(written == 1 ? "" : "s"); \(failed) failed."
    }

    private func resultRow(_ result: EditorSyncResult) -> some View {
        let (status, word) = outcomeState(result.outcome)
        return HubListRow(
            status: status,
            name: result.label,
            providers: [result.toolID],
            caption: result.message
        ) { _ in
            stateWord(word, status)
        }
    }

    // MARK: - Actions

    private func select(_ name: String) {
        selectedServer = name
        results = nil
        sourceConfig = readSourceConfig(for: name)
        plan = sourceConfig.map { EditorSync.plan(server: name, config: $0, tools: mcpStore.detectedTools) } ?? []
        errorMessage = sourceConfig == nil ? "Project Hub could not read \"\(name)\" from a writable config." : nil
    }

    private func readSourceConfig(for name: String) -> [String: Any]? {
        for tool in mcpStore.detectedTools where tool.servers.contains(where: { $0.name == name && !$0.isReadOnly }) {
            if let config = ConfigWriter.readServer(toolID: tool.toolID, name: name) {
                return config
            }
        }
        return nil
    }

    private func run() {
        guard let server = selectedServer, let config = sourceConfig else { return }
        let applied = EditorSync.apply(server: server, config: config, plan: plan)
        if applied.contains(where: { $0.outcome == .written }) {
            mcpStore.refresh()
        }
        results = applied
    }
}
