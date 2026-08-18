import SwiftUI
import AppKit

struct ProvidersView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @EnvironmentObject var skillStore: SkillStore
    @EnvironmentObject var mcpStore: MCPStore

    @State private var rows: [ProviderSnapshot] = []
    @State private var expandedID: String?
    @State private var selectedProjectPath: String = ""
    @State private var status: String?
    @State private var loading = false
    @State private var editingSkillPath: String?
    @State private var creatingForProvider: String?
    @State private var newSkillName = ""

    private var selectedProject: Project? {
        projectStore.projects.first { $0.path == selectedProjectPath }
    }

    private var copyTargets: [String] {
        ["claude-code", "codex", "cursor", "vscode", "opencode", "antigravity", "pi", "command-code", "grok"]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(rows) { row in
                        providerCard(row)
                    }
                }
                .padding(16)
            }
        }
        .onAppear {
            if selectedProjectPath.isEmpty {
                selectedProjectPath = projectStore.projects.max(by: { $0.lastOpenedAt < $1.lastOpenedAt })?.path ?? ""
            }
            if rows.isEmpty { reload() }
        }
        .onChange(of: selectedProjectPath) { _, _ in reload() }
        .onChange(of: projectStore.projects.count) { _, _ in reload() }
        .sheet(item: Binding(
            get: { editingSkillPath.map { IdentifiablePath(path: $0) } },
            set: { editingSkillPath = $0?.path }
        )) { item in
            SkillEditorSheet(skillPath: item.path) { reload() }
                .frame(width: 520, height: 560)
        }
        .sheet(isPresented: Binding(
            get: { creatingForProvider != nil },
            set: { if !$0 { creatingForProvider = nil } }
        )) {
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: "New skill")
                    .font(.system(size: 14, weight: .semibold))
                TextField("skill-name", text: $newSkillName)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancel") { creatingForProvider = nil }
                    Button("Create") {
                        if let provider = creatingForProvider,
                           let path = skillStore.createSkill(named: newSkillName, providerID: provider, projectPath: selectedProject?.path) {
                            creatingForProvider = nil
                            newSkillName = ""
                            editingSkillPath = path
                            reload()
                        }
                    }
                    .disabled(newSkillName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(16)
            .frame(width: 360)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("\(rows.filter(\.detected).count) of \(rows.count) found")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Picker("Project", selection: $selectedProjectPath) {
                Text("Global only").tag("")
                ForEach(projectStore.projects) { project in
                    Text(project.displayName).tag(project.path)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 220)
            if let status {
                Text(status)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if loading {
                ProgressView()
                    .controlSize(.small)
            }
            Button("Refresh") { reload() }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .disabled(loading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func providerCard(_ row: ProviderSnapshot) -> some View {
        let color = ToolPalette.color(for: row.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: ToolPalette.icon(for: row.id))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.name)
                        .font(.system(size: 14, weight: .semibold))
                    Text(row.detected ? "Found on this Mac" : "Not installed")
                        .font(.system(size: 11))
                        .foregroundColor(row.detected ? .secondary : .orange)
                }
                Spacer()
                Button("Open files") { reveal(row.globalHome) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!FileManager.default.fileExists(atPath: row.globalHome))
                if let projectPath = row.projectPaths.first {
                    Button("Project files") { reveal(projectPath) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                Button(expandedID == row.id ? String("Hide") : String("Controls")) {
                    expandedID = expandedID == row.id ? nil : row.id
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            HStack(spacing: 6) {
                ForEach(row.features) { feature in
                    Text("\(feature.name) \(feature.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(feature.count == 0 ? .secondary : .primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.7))
                        .clipShape(Capsule())
                }
            }

            if expandedID == row.id {
                controls(for: row)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
        )
    }

    private func controls(for row: ProviderSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Button(String("New skill")) {
                    newSkillName = ""
                    creatingForProvider = row.id
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                if let file = defaultInstruction(for: row), selectedProject != nil {
                    Button("New \(file)") { createInstruction(file) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            assetGroup(title: "Skills", assets: row.assets.filter { $0.kind == .skill }, row: row)
            assetGroup(title: "MCP", assets: row.assets.filter { $0.kind == .mcp }, row: row)
            assetGroup(title: "Instructions", assets: row.assets.filter { $0.kind == .instruction }, row: row)
            assetGroup(title: "Agents", assets: row.assets.filter { $0.kind == .agent }, row: row)
            assetGroup(title: "Hooks", assets: row.assets.filter { $0.kind == .hook }, row: row)
            assetGroup(title: "Plugins", assets: row.assets.filter { $0.kind == .plugin }, row: row)
        }
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func assetGroup(title: String, assets: [ProviderAsset], row: ProviderSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            if assets.isEmpty {
                Text("None found")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                ForEach(assets.prefix(12)) { asset in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(asset.enabled ? Color.green.opacity(0.8) : Color.secondary.opacity(0.45))
                            .frame(width: 6, height: 6)
                        Text(asset.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Text(asset.scope)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Open") { reveal(asset.path) }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                        if asset.kind == .skill {
                            Button("Edit") { editingSkillPath = asset.path }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        if asset.kind == .mcp {
                            Button(asset.enabled ? "Disable" : "Enable") {
                                toggleMCP(asset, providerID: row.id)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                        }
                        if asset.kind == .skill, selectedProject != nil {
                            Button("Copy to project") {
                                copySkill(asset, from: row)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                        }
                        if asset.kind == .mcp {
                            Menu("Copy") {
                                ForEach(copyTargets.filter { $0 != row.id }, id: \.self) { toolID in
                                    Button(ALL_TOOL_META.first { $0.id == toolID }?.label ?? toolID) {
                                        copyMCP(asset, from: row.id, to: toolID)
                                    }
                                }
                            }
                            .font(.system(size: 11, weight: .semibold))
                        }
                    }
                }
                if assets.count > 12 {
                    Text("+\(assets.count - 12) more")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func copySkill(_ asset: ProviderAsset, from row: ProviderSnapshot) {
        guard let project = selectedProject else { return }
        let source: SkillSource
        switch row.id {
        case "claude-code": source = .claudeGlobal
        case "codex": source = .codexGlobal
        case "cursor": source = .cursorGlobal
        default: source = .providerGlobal
        }
        skillStore.copy(
            Skill(name: asset.name, description: "", triggers: [], source: source, path: asset.path),
            to: project.path
        )
        status = "Copied \(asset.name) to \(project.displayName)"
        reload()
    }

    private func toggleMCP(_ asset: ProviderAsset, providerID: String) {
        let scope: ConfigScope = asset.scope == "project" ? .project : .user
        let result = mcpStore.toggleServerDisabled(
            toolID: providerID,
            scope: scope,
            projectRoot: selectedProject?.path,
            name: asset.name,
            currently: !asset.enabled
        )
        status = result.ok ? "\(asset.enabled ? "Disabled" : "Enabled") \(asset.name)" : (result.error ?? "Toggle failed")
        reload()
    }

    private func defaultInstruction(for row: ProviderSnapshot) -> String? {
        switch row.id {
        case "claude-code": return "CLAUDE.md"
        case "codex", "cursor", "opencode", "zed", "pi", "command-code", "antigravity", "vscode", "grok": return "AGENTS.md"
        default: return nil
        }
    }

    private func createInstruction(_ name: String) {
        guard let project = selectedProject else { return }
        let doc = InstructionDocument(relativePath: name, title: name)
        if !InstructionFileReader.exists(doc, in: project.path) {
            try? InstructionFileReader.write("# \(name)\n\n", doc, to: project.path)
        }
        reveal(doc.absolutePath(in: project.path))
        reload()
    }

    private func copyMCP(_ asset: ProviderAsset, from sourceID: String, to targetID: String) {
        let result = mcpStore.copyServer(name: asset.name, from: sourceID, to: [targetID])
        if result.failures.isEmpty {
            status = "Copied \(asset.name) to \(targetID)"
        } else {
            status = result.failures.first?.message ?? "Copy failed"
        }
        reload()
    }

    private func reload() {
        let projectPath = selectedProject?.path
        loading = true
        Task.detached(priority: .utility) {
            let result = ProviderCatalog.snapshots(projectPath: projectPath)
            await MainActor.run {
                rows = result
                loading = false
            }
        }
    }

    private func reveal(_ path: String) {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }
}

private struct IdentifiablePath: Identifiable {
    var id: String { path }
    let path: String
}
