import SwiftUI

// MARK: - CopyProfileSheet

struct CopyProfileSheet: View {
    let targetProject: Project
    let allProjects: [Project]
    let onDone: () -> Void

    @EnvironmentObject var projectStore: ProjectStore
    @EnvironmentObject var skillStore: SkillStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedSourceID: UUID? = nil
    @State private var copySkills: Bool = true
    @State private var copyAgents: Bool = true
    @State private var copyRules: Bool = true
    @State private var copyMCP: Bool = false
    @State private var isRunning: Bool = false
    @State private var result: CopyResult? = nil

    // MARK: - Derived

    private var sourceCandidates: [Project] {
        allProjects.filter { $0.id != targetProject.id }
    }

    private var selectedSource: Project? {
        guard let id = selectedSourceID else { return nil }
        return sourceCandidates.first { $0.id == id }
    }

    private var preview: (skills: Int, agents: Int, rules: Int, mcp: Int) {
        guard let src = selectedSource else { return (0, 0, 0, 0) }
        return ProfileCopier.preview(from: src.path)
    }

    private var nothingSelected: Bool {
        !copySkills && !copyAgents && !copyRules && !copyMCP
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sourcePickerSection
                    if selectedSource != nil {
                        previewSection
                    }
                    whatToCopySection
                }
                .padding(16)
            }
            Divider()
            footerView
        }
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.cyan)
            Text("Copy Config Profile")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Source picker

    private var sourcePickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Source project", systemImage: "folder")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            if sourceCandidates.isEmpty {
                Text("No other projects available.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Picker("Source", selection: $selectedSourceID) {
                    Text("Choose a project…").tag(Optional<UUID>.none)
                    ForEach(sourceCandidates) { project in
                        Text(project.displayName)
                            .tag(Optional(project.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)

                if let src = selectedSource {
                    Text(src.path)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        let p = preview
        return VStack(alignment: .leading, spacing: 4) {
            Label("Available to copy", systemImage: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                previewChip(count: p.skills, label: "skill\(p.skills == 1 ? "" : "s")",       icon: "book.closed.fill",      color: .cyan)
                previewChip(count: p.agents, label: "agent\(p.agents == 1 ? "" : "s")",       icon: "person.fill",           color: .indigo)
                previewChip(count: p.rules,  label: "rule\(p.rules == 1 ? "" : "s")",         icon: "pencil.and.ruler.fill",  color: .orange)
                previewChip(count: p.mcp,    label: "MCP server\(p.mcp == 1 ? "" : "s")",    icon: "server.rack",            color: .green)
            }
        }
    }

    private func previewChip(count: Int, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
            Text("\(count) \(label)")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(count > 0 ? color : .secondary.opacity(0.6))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background((count > 0 ? color : Color.secondary).opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - What to copy

    private var whatToCopySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("What to copy", systemImage: "checklist")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                toggleRow(
                    isOn: $copySkills,
                    icon: "book.closed.fill",
                    color: .cyan,
                    title: "Skills",
                    subtitle: ".claude/skills and .agents/skills"
                )
                Divider().padding(.leading, 36)

                toggleRow(
                    isOn: $copyAgents,
                    icon: "person.fill",
                    color: .indigo,
                    title: "Agents",
                    subtitle: ".claude/agents/*.md files"
                )
                Divider().padding(.leading, 36)

                toggleRow(
                    isOn: $copyRules,
                    icon: "pencil.and.ruler.fill",
                    color: .orange,
                    title: "Cursor Rules",
                    subtitle: ".cursor/rules/*.mdc files"
                )
                Divider().padding(.leading, 36)

                mcpToggleRow
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
            )
        }
    }

    private func toggleRow(isOn: Binding<Bool>, icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var mcpToggleRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "server.rack")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.green)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text("MCP Servers")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                }
                Text("Includes API keys — .mcp.json, .cursor/mcp.json, .codex/config.toml")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $copyMCP)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Result summary

    @ViewBuilder
    private var resultSummaryView: some View {
        if let r = result {
            VStack(alignment: .leading, spacing: 8) {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.green)

                let parts = resultParts(from: r)
                if parts.isEmpty {
                    Text("Nothing new to copy — all items already exist in the target project.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    Text("Copied: " + parts.joined(separator: ", "))
                        .font(.system(size: 12))
                }

                if !r.errors.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Warnings:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                        ForEach(r.errors, id: \.self) { err in
                            Text("• \(err)")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func resultParts(from r: CopyResult) -> [String] {
        var parts: [String] = []
        if r.skillsCopied > 0 { parts.append("\(r.skillsCopied) skill\(r.skillsCopied == 1 ? "" : "s")") }
        if r.agentsCopied > 0 { parts.append("\(r.agentsCopied) agent\(r.agentsCopied == 1 ? "" : "s")") }
        if r.rulesCopied  > 0 { parts.append("\(r.rulesCopied) rule\(r.rulesCopied == 1 ? "" : "s")") }
        if r.mcpCopied    > 0 { parts.append("\(r.mcpCopied) MCP server\(r.mcpCopied == 1 ? "" : "s")") }
        return parts
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 10) {
            if result != nil {
                resultSummaryView
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }

            HStack(spacing: 8) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                if result != nil {
                    Button("Done") {
                        onDone()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                } else {
                    Button {
                        runCopy()
                    } label: {
                        if isRunning {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.mini)
                                    .scaleEffect(0.7)
                                Text("Copying…")
                            }
                        } else {
                            Text("Copy")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(selectedSource == nil || nothingSelected || isRunning)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Copy action

    private func runCopy() {
        guard let src = selectedSource else { return }
        isRunning = true

        let sourcePath = src.path
        let targetPath = targetProject.path
        let options = CopyOptions(
            skills:      copySkills,
            agents:      copyAgents,
            cursorRules: copyRules,
            mcpServers:  copyMCP
        )

        Task.detached(priority: .userInitiated) {
            let copyResult = ProfileCopier.copy(from: sourcePath, to: targetPath, options: options)
            await MainActor.run {
                self.result = copyResult
                self.isRunning = false
            }
        }
    }
}
