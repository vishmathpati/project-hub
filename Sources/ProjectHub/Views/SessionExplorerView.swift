import SwiftUI

struct SessionExplorerView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @State private var selectedProjectID: UUID?
    @State private var sessions: [SessionExplorerSession] = []
    @State private var selectedPath: String?
    @State private var entries: [SessionExplorerEntry] = []
    @State private var loadingSessions = false
    @State private var loadingTranscript = false
    private static let timeFormat: DateFormatter = {
        let format = DateFormatter()
        format.dateFormat = "d MMM HH:mm"
        return format
    }()
    private var selectedProject: Project? {
        if let id = selectedProjectID, let found = projectStore.projects.first(where: { $0.id == id }) { return found }
        return projectStore.projects.first
    }
    private var frequencies: [SessionExplorerToolFrequency] {
        SessionExplorerReader.toolFrequencies(for: entries)
    }
    var body: some View {
        VStack(spacing: 0) {
            HubPageHeader(title: "Sessions", subtitle: selectedProject?.displayName, actions: { headerActions })
            HSplitView {
                sessionPane.frame(minWidth: 240, idealWidth: 300)
                transcriptPane.frame(minWidth: 320)
            }
        }
        .background(HubTheme.bg)
        .onAppear { if selectedProjectID == nil { selectedProjectID = projectStore.projects.first?.id } }
        .task(id: selectedProject?.path) { await loadSessions() }
        .task(id: selectedPath) { await loadTranscript() }
    }
    @ViewBuilder
    private var headerActions: some View {
        Menu {
            ForEach(projectStore.projects) { project in Button(project.displayName) { selectedProjectID = project.id } }
        } label: {
            Text("for: \(selectedProject?.displayName ?? "—") ▾").font(HubFont.mono(10)).foregroundStyle(HubTheme.textMid)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        HubButton(title: loadingSessions ? "Loading" : "Reload", kind: .primary) { Task { await loadSessions() } }.disabled(loadingSessions || selectedProject == nil)
    }
    private var sessionPane: some View {
        VStack(spacing: 0) {
            HubSectionHeading("Sessions", count: sessions.isEmpty ? nil : sessions.count).padding(.horizontal, HubTheme.contentPadding).padding(.vertical, 8)
            if loadingSessions && sessions.isEmpty {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sessions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 24)).foregroundStyle(HubTheme.textDim)
                    Text("No sessions yet").font(HubFont.sans(13, .semibold)).foregroundStyle(HubTheme.textStrong)
                    Text("No Claude Code session logs for this project.").font(HubFont.caption).foregroundStyle(HubTheme.textDim).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                            if index > 0 { HubRowSeparator() }
                            sessionRow(session)
                        }
                    }
                }
            }
        }
    }
    private func sessionRow(_ session: SessionExplorerSession) -> some View {
        Button { selectedPath = session.path } label: {
            HStack(alignment: .top, spacing: 10) {
                StatusDot(status: .neutral)
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title).font(HubFont.rowPrimary).foregroundStyle(HubTheme.text).lineLimit(1).truncationMode(.middle)
                    Text(sessionMeta(session)).font(HubFont.machine).foregroundStyle(HubTheme.textDim).lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(session.messageCount) msg").font(HubFont.machine).foregroundStyle(HubTheme.textMid)
                    Text(money(session.cost)).font(HubFont.machine).foregroundStyle(HubTheme.textFaint)
                }
            }
            .padding(.horizontal, HubTheme.contentPadding).frame(minHeight: HubTheme.listRowHeight)
            .background(selectedPath == session.path ? HubTheme.rowSelected : .clear).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
    private var transcriptPane: some View {
        VStack(spacing: 0) {
            if selectedPath == nil {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text").font(.system(size: 24)).foregroundStyle(HubTheme.textDim)
                    Text("Select a session").font(HubFont.sans(13, .semibold)).foregroundStyle(HubTheme.textStrong)
                    Text("Pick a session on the left to read its transcript.").font(HubFont.caption).foregroundStyle(HubTheme.textDim).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30)
            } else if loadingTranscript && entries.isEmpty {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if entries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text").font(.system(size: 24)).foregroundStyle(HubTheme.textDim)
                    Text("Empty transcript").font(HubFont.sans(13, .semibold)).foregroundStyle(HubTheme.textStrong)
                    Text("This session log has no readable messages.").font(HubFont.caption).foregroundStyle(HubTheme.textDim).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if !frequencies.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 5) {
                                    ForEach(frequencies) { item in
                                        Text(verbatim: "\(item.name) ×\(item.count)").font(HubFont.mono(9, .medium)).foregroundStyle(HubTheme.textMid).padding(.horizontal, 6).padding(.vertical, 3).background(HubTheme.field).clipShape(Capsule())
                                    }
                                }
                            }.padding(.horizontal, HubTheme.contentPadding).padding(.top, 10)
                        }
                        ForEach(entries) { entry in transcriptRow(entry) }
                    }.padding(.bottom, 12)
                }
            }
        }
    }
    private func transcriptRow(_ entry: SessionExplorerEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                roleBadge(entry.role, toolName: entry.toolName)
                if let date = entry.timestamp { Text(Self.timeFormat.string(from: date)).font(HubFont.machine).foregroundStyle(HubTheme.textFaint) }
                Spacer(minLength: 8)
                if let tokens = entry.tokens { Text("\(tokens) tok").font(HubFont.machine).foregroundStyle(HubTheme.textDim) }
            }
            if !entry.text.isEmpty {
                Text(verbatim: entry.text).font(HubFont.body).foregroundStyle(HubTheme.text).lineLimit(12).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10).hubCard().padding(.horizontal, HubTheme.contentPadding)
    }
    private func roleBadge(_ role: SessionExplorerRole, toolName: String?) -> some View {
        let label = toolName.map { "tool · \($0)" } ?? role.rawValue
        return Text(verbatim: label).font(HubFont.mono(9, .bold)).foregroundStyle(badgeColor(role)).padding(.horizontal, 6).padding(.vertical, 2).background(badgeColor(role).opacity(0.12)).clipShape(Capsule()).lineLimit(1)
    }
    private func badgeColor(_ role: SessionExplorerRole) -> Color {
        switch role { case .user: return .blue; case .assistant: return .orange; case .tool: return .green; case .system: return .secondary }
    }
    private func sessionMeta(_ session: SessionExplorerSession) -> String {
        var parts: [String] = []
        if let last = session.lastAt { parts.append(Self.timeFormat.string(from: last)) }
        parts.append("\(session.tokenTotal.formatted()) tok")
        return parts.joined(separator: " · ")
    }
    private func money(_ value: Double) -> String {
        if value <= 0 { return "$0.00" }
        if value < 0.01 { return "<$0.01" }
        return value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }
    private func loadSessions() async {
        guard let path = selectedProject?.path else { sessions = []; return }
        loadingSessions = true
        let result = await Task.detached(priority: .utility) { SessionExplorerReader.sessions(forProjectPath: path) }.value
        sessions = result
        if let selected = selectedPath, !result.contains(where: { $0.path == selected }) { selectedPath = nil; entries = [] }
        loadingSessions = false
    }
    private func loadTranscript() async {
        guard let path = selectedPath else { entries = []; return }
        loadingTranscript = true
        entries = await Task.detached(priority: .utility) { SessionExplorerReader.transcript(forSessionPath: path) }.value
        loadingTranscript = false
    }
}
