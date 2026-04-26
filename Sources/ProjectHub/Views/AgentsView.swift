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

    private var agents: [Agent] {
        let _ = reloadTick  // trigger re-eval
        return agentStore.agents(for: project.path)
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
    }

    // MARK: - Agent bar

    private var agentBar: some View {
        HStack {
            Text("\(agents.count) agent\(agents.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Button(action: { showNewAgentSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("New Agent")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(ContentView.headerGrad)
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
            VStack(spacing: 6) {
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
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5))
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
            Text("No agents yet")
                .font(.system(size: 14, weight: .semibold))
            Text("Create a Claude sub-agent for this project.")
                .font(.caption)
                .foregroundColor(.secondary)
            Button(action: { showNewAgentSheet = true }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle.fill")
                    Text("New Agent")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(ContentView.headerGrad)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
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

            if !agent.tools.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tools").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                    Text(agent.tools.joined(separator: ", "))
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                }
            }

            Divider()

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
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            HStack {
                Spacer()
                Button("Open in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        [URL(fileURLWithPath: agent.filePath)]
                    )
                }
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(20)
        .frame(width: 440, height: 420)
    }
}
