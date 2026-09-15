import SwiftUI

// MARK: - Agents sub-tab (inside ProjectDetailView)

struct AgentsView: View {
    let project: Project
    @Binding var reloadTick: Int

    @EnvironmentObject var agentStore: AgentStore
    @State private var showNewAgentSheet: Bool = false
    @State private var selectedAgent: Agent? = nil
    @State private var deletingAgentName: String? = nil
    @State private var confirmDelete: Bool = false
    @State private var searchText: String = ""

    private var isFiltering: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var agents: [Agent] {
        let all = agentStore.agents(for: project.path)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.name.lowercased().contains(query)
            || $0.description.lowercased().contains(query)
            || $0.model.lowercased().contains(query)
            || $0.tools.contains { $0.lowercased().contains(query) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            agentBar
            Divider()
            if agents.isEmpty {
                emptyState
            } else {
                agentList
            }
        }
        .task(id: "\(project.path)#\(reloadTick)") {
            await agentStore.load(for: project.path)
        }
        .sheet(isPresented: $showNewAgentSheet) {
            NewAgentSheet(projectPath: project.path) {
                reloadTick &+= 1
            }
        }
        .sheet(item: $selectedAgent) { agent in
            AgentDetailSheet(agent: agent)
        }
        .alert("Delete \"\(deletingAgentName ?? "")\"?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) { deletingAgentName = nil }
            Button("Delete", role: .destructive) {
                if let name = deletingAgentName {
                    agentStore.delete(agentName: name, from: project.path)
                    reloadTick &+= 1
                    deletingAgentName = nil
                }
            }
        } message: {
            Text("This deletes the .md file from .claude/agents/. This action cannot be undone.")
        }
        .alert("Couldn't update agent", isPresented: Binding(
            get: { agentStore.lastError != nil },
            set: { if !$0 { agentStore.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { agentStore.lastError = nil }
        } message: {
            Text(agentStore.lastError ?? "")
        }
    }

    // MARK: - Agent bar

    private var agentBar: some View {
        let total = agentStore.agents(for: project.path).count
        return HStack {
            Text(isFiltering
                ? "\(agents.count) of \(total) agent\(total == 1 ? "" : "s")"
                : "\(agents.count) agent\(agents.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            HubSearchField(text: $searchText, placeholder: "Filter agents", shortcut: nil)
                .frame(width: 200)
            Button(action: { showNewAgentSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("New Agent")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(HubTheme.onAccent)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(HubTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Agent list

    private var agentList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(agents) { agent in
                    agentRow(agent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func agentRow(_ agent: Agent) -> some View {
        Button(action: { selectedAgent = agent }) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(modelColor(agent.model).opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: "person.fill.viewfinder")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(modelColor(agent.model))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(agent.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        modelBadge(agent.model)
                    }
                    if !agent.description.isEmpty {
                        Text(agent.description)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    if !agent.tools.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(agent.tools, id: \.self) { tool in
                                    Text(tool)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.10))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                Spacer()

                Button(action: {
                    deletingAgentName = agent.name
                    confirmDelete = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Delete agent")
            }
            .padding(10)
            .background(HubTheme.raised)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(HubTheme.line.opacity(0.4), lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.fill.viewfinder")
                .font(.system(size: 26))
                .foregroundColor(.secondary)
            if agentStore.agents(for: project.path).isEmpty {
                Text("No agents yet")
                    .font(.system(size: 14, weight: .semibold))
                Text("Create a Claude sub-agent for this project.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                newAgentCTA
            } else {
                Text("No agents match your filter")
                    .font(.system(size: 14, weight: .semibold))
                Text("Try a different search, or clear the filter.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                clearFilterCTA
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private var newAgentCTA: some View {
        Button(action: { showNewAgentSheet = true }) {
            HStack(spacing: 5) {
                Image(systemName: "plus.circle.fill")
                Text("New Agent")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(HubTheme.onAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(HubTheme.accent)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var clearFilterCTA: some View {
        Button(action: { searchText = "" }) {
            HStack(spacing: 5) {
                Image(systemName: "xmark.circle")
                Text("Clear filter")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(HubTheme.onAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(HubTheme.accent)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func modelColor(_ model: String) -> Color {
        let m = model.lowercased()
        if m.contains("haiku")  { return .green }
        if m.contains("sonnet") { return .blue }
        if m.contains("opus")   { return .purple }
        return .orange
    }

    private func modelBadge(_ model: String) -> some View {
        let (label, color): (String, Color) = {
            let m = model.lowercased()
            if m.contains("haiku")  { return ("haiku",  .green) }
            if m.contains("sonnet") { return ("sonnet", .blue) }
            if m.contains("opus")   { return ("opus",   .purple) }
            return (model, .orange)
        }()
        return Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - New Agent Sheet

struct NewAgentSheet: View {
    let projectPath: String
    let onCreated: () -> Void

    @EnvironmentObject var agentStore: AgentStore
    @Environment(\.dismiss) var dismiss

    @State private var name:        String = ""
    @State private var description: String = ""
    @State private var model:       String = "haiku"
    @State private var selectedTools: Set<String> = []

    private let availableTools = [
        "Bash", "Edit", "Glob", "Grep", "Read", "Write",
        "WebFetch", "WebSearch", "TodoRead", "TodoWrite",
        "Task", "LS", "MultiEdit"
    ]

    private let models = ["haiku", "sonnet", "opus"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("New Agent")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Name").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                TextField("e.g. codebase-analyzer", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Description").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                TextField("When should Claude use this agent?", text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            // Model
            VStack(alignment: .leading, spacing: 4) {
                Text("Model").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                Picker("Model", selection: $model) {
                    ForEach(models, id: \.self) { m in
                        Text(m.capitalized).tag(m)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Tools
            VStack(alignment: .leading, spacing: 6) {
                Text("Tools").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
                    ForEach(availableTools, id: \.self) { tool in
                        Toggle(isOn: Binding(
                            get: { selectedTools.contains(tool) },
                            set: { on in
                                if on { selectedTools.insert(tool) }
                                else  { selectedTools.remove(tool) }
                            }
                        )) {
                            Text(tool).font(.system(size: 11))
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }

            Spacer()

            // Actions
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button("Create Agent") {
                    let template = AgentTemplate(
                        name:        name.trimmingCharacters(in: .whitespaces),
                        description: description.trimmingCharacters(in: .whitespaces),
                        model:       model,
                        tools:       selectedTools.sorted()
                    )
                    agentStore.create(agent: template, in: projectPath)
                    onCreated()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(20)
        .frame(width: 420, height: 500)
    }
}

// MARK: - Agent Detail Sheet

struct AgentDetailSheet: View {
    let agent: Agent
    @Environment(\.dismiss) var dismiss

    @State private var isEditing: Bool = false
    @State private var descriptionText: String = ""
    @State private var modelText: String = ""
    @State private var toolsText: String = ""
    @State private var bodyText: String = ""
    @State private var saveError: String? = nil
    @State private var showingPreview: Bool = false
    @State private var previewBefore: String = ""
    @State private var previewAfter: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                        .font(.system(size: 16, weight: .bold))
                    Text(agent.model)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if !agent.description.isEmpty {
                Text(agent.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            if isEditing {
                editForm
            } else if !agent.tools.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tools").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                    Text(agent.tools.joined(separator: ", "))
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                }
            }

            Divider()

            if isEditing {
                TextEditor(text: $bodyText)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 140)
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(HubTheme.line.opacity(0.5), lineWidth: 0.5))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Prompt").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                    ScrollView {
                        Text(agent.body.isEmpty ? "(empty)" : agent.body)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 200)
                    .background(HubTheme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            HStack {
                Spacer()
                Button("Open in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        [URL(fileURLWithPath: agent.filePath)]
                    )
                }
                if isEditing {
                    Button("Cancel") { cancelEditing() }
                    Button("Review diff") { stagePreview() }
                        .keyboardShortcut(.return, modifiers: .command)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Edit") { beginEditing() }
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
        .padding(20)
        .frame(width: 440, height: 520)
        .sheet(isPresented: $showingPreview) {
            MarkdownDiffSheet(
                title: "Review changes to \(agent.name)",
                filePath: agent.filePath,
                before: previewBefore,
                after: previewAfter,
                onConfirm: {
                    showingPreview = false
                    save(expectedBefore: previewBefore)
                }
            )
        }
        .alert("Couldn't save agent", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Description").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                TextField("When should Claude use this agent?", text: $descriptionText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Model").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                TextField("sonnet", text: $modelText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Tools, comma-separated").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                TextField("Bash, Read, Edit", text: $toolsText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }
        }
    }

    private func beginEditing() {
        descriptionText = agent.description
        modelText = agent.model
        toolsText = agent.tools.joined(separator: ", ")
        bodyText = agent.body
        saveError = nil
        isEditing = true
    }

    private func cancelEditing() {
        showingPreview = false
        isEditing = false
    }

    private func editedAgent() -> Agent {
        Agent(
            name: agent.name,
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            model: modelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "sonnet" : modelText.trimmingCharacters(in: .whitespacesAndNewlines),
            tools: toolsText.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            filePath: agent.filePath,
            body: bodyText
        )
    }

    private func stagePreview() {
        saveError = nil
        guard let current = AgentReader.currentText(at: agent.filePath) else {
            saveError = "Could not read \(agent.filePath). It may have been moved or deleted."
            return
        }
        let after = AgentReader.renderedDocument(for: editedAgent())
        guard after != current else {
            saveError = "No changes to review."
            return
        }
        previewBefore = current
        previewAfter = after
        showingPreview = true
    }

    private func save(expectedBefore: String?) {
        do {
            let projectPath = ((agent.filePath as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent
            try AgentReader.update(editedAgent(), in: projectPath, expectedBefore: expectedBefore)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
