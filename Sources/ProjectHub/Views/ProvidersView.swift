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
            HubPageHeader(
                title: "Providers",
                subtitle: "\(installed.count) of \(rows.count) installed on this Mac",
                actions: { headerActions }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: HubTheme.sectionGap) {
                    HubPageNote(
                        text: "A provider is an app that reads config out of your folders. This page is where you see what each one is currently reading, and push the same setup into another one."
                    )

                    HStack(spacing: 10) {
                        MetricTile(value: "\(totalAssets(.skill))", label: "skills")
                        MetricTile(value: "\(totalAssets(.mcp))",   label: "servers")
                        MetricTile(value: "\(totalAssets(.plugin))", label: "plugins")
                    }

                    if !installed.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HubSectionHeading("Installed", count: installed.count)
                            VStack(spacing: 8) {
                                ForEach(installed) { row in providerCard(row) }
                            }
                        }
                    }

                    if !notInstalled.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HubSectionHeading("Not installed", count: notInstalled.count)
                            VStack(spacing: 8) {
                                ForEach(notInstalled) { row in providerCard(row) }
                            }
                        }
                    }
                }
                .padding(HubTheme.contentPadding)
            }
        }
        .background(HubTheme.bg)
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
                    .font(HubFont.sans(13, .semibold))
                    .foregroundStyle(HubTheme.textStrong)
                TextField("skill-name", text: $newSkillName)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 8) {
                    Spacer()
                    HubButton(title: "Cancel", kind: .secondary) { creatingForProvider = nil }
                    HubButton(title: "Create", kind: .primary) {
                        if let provider = creatingForProvider,
                           let path = skillStore.createSkill(named: newSkillName, providerID: provider, projectPath: selectedProject?.path) {
                            creatingForProvider = nil
                            newSkillName = ""
                            editingSkillPath = path
                            reload()
                        }
                    }
                }
            }
            .padding(16)
            .frame(width: 360)
            .background(HubTheme.bg)
        }
    }

    private var installed: [ProviderSnapshot] { rows.filter(\.detected) }
    private var notInstalled: [ProviderSnapshot] { rows.filter { !$0.detected } }

    private func totalAssets(_ kind: ProviderAsset.Kind) -> Int {
        var seen = Set<String>()
        for row in rows {
            for asset in row.assets where asset.kind == kind {
                seen.insert(asset.name.lowercased())
            }
        }
        return seen.count
    }

    private func assetCount(_ row: ProviderSnapshot, _ kind: ProviderAsset.Kind) -> Int {
        row.assets.filter { $0.kind == kind }.count
    }

    @ViewBuilder
    private var headerActions: some View {
        Menu {
            Button("Global only") { selectedProjectPath = "" }
            ForEach(projectStore.projects) { project in
                Button(project.displayName) { selectedProjectPath = project.path }
            }
        } label: {
            Text("scope: \(selectedProject?.displayName ?? "global") ▾")
                .font(HubFont.mono(10))
                .foregroundStyle(HubTheme.textMid)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()

        if let status {
            Text(status)
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.textDim)
                .lineLimit(1)
        }

        HubButton(title: "Rescan", kind: .secondary) { reload() }

        Menu {
            ForEach(copyTargets, id: \.self) { toolID in
                Button(ToolPalette.label(for: toolID)) { copySkills(to: toolID) }
            }
        } label: {
            Text("Copy skills to…")
                .font(HubFont.sans(12, .semibold))
                .foregroundStyle(HubTheme.onAccent)
                .padding(.horizontal, 11)
                .frame(height: HubTheme.buttonHeight)
                .background(HubTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.control))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: - Provider card (§3 — 28pt tile, brand colour confined to the tile)

    private func providerCard(_ row: ProviderSnapshot) -> some View {
        let expanded = expandedID == row.id

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ProviderTile(toolID: row.id, size: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name)
                        .font(HubFont.sans(13, .semibold))
                        .foregroundStyle(HubTheme.textStrong)
                    Text(shortPath(row.globalHome))
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textDim)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 12)

                Text("\(assetCount(row, .skill)) skills")
                    .font(HubFont.machine)
                    .foregroundStyle(HubTheme.textDim)
                Text("\(assetCount(row, .mcp)) mcp")
                    .font(HubFont.machine)
                    .foregroundStyle(HubTheme.textDim)

                if row.detected {
                    HubButton(title: expanded ? "hide" : "manage", kind: .accentInline) {
                        expandedID = expanded ? nil : row.id
                    }
                } else {
                    Text("not installed")
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textFaint)
                }
            }
            .padding(.horizontal, HubTheme.cardPadding)
            .frame(minHeight: 56)

            if expanded {
                Rectangle().fill(HubTheme.hairline).frame(height: 1)
                controls(for: row)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(row.detected ? 1 : 0.55)
        .hubCard()
        .animation(HubTheme.disclosureAnimation, value: expanded)
    }

    private func controls(for row: ProviderSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                HubButton(title: "New skill", kind: .secondary) {
                    newSkillName = ""
                    creatingForProvider = row.id
                }
                if let file = defaultInstruction(for: row), selectedProject != nil {
                    HubButton(title: "New \(file)", kind: .secondary) { createInstruction(file) }
                }
                Spacer(minLength: 8)
                HubButton(title: "reveal", kind: .inlineAction) { reveal(row.globalHome) }
                if let projectPath = row.projectPaths.first {
                    HubButton(title: "project files", kind: .inlineAction) { reveal(projectPath) }
                }
            }
            assetGroup(title: "Skills", assets: row.assets.filter { $0.kind == .skill }, row: row)
            assetGroup(title: "MCP", assets: row.assets.filter { $0.kind == .mcp }, row: row)
            assetGroup(title: "Instructions", assets: row.assets.filter { $0.kind == .instruction }, row: row)
            assetGroup(title: "Agents", assets: row.assets.filter { $0.kind == .agent }, row: row)
            assetGroup(title: "Hooks", assets: row.assets.filter { $0.kind == .hook }, row: row)
            assetGroup(title: "Plugins", assets: row.assets.filter { $0.kind == .plugin }, row: row)
        }
        .padding(HubTheme.cardPadding)
    }

    private func assetGroup(title: String, assets: [ProviderAsset], row: ProviderSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading(title, count: assets.isEmpty ? nil : assets.count)
            if assets.isEmpty {
                Text("None found")
                    .font(HubFont.secondary)
                    .foregroundStyle(HubTheme.textFaint)
            } else {
                ForEach(assets.prefix(12)) { asset in
                    HStack(spacing: 10) {
                        StatusLabel(
                            status: asset.enabled ? .ok : .neutral,
                            text: asset.name,
                            font: HubFont.sans(12.5)
                        )
                        Text(asset.scope)
                            .font(HubFont.machine)
                            .foregroundStyle(HubTheme.textFaint)
                        Spacer(minLength: 8)
                        HubButton(title: "open", kind: .inlineAction) { reveal(asset.path) }
                        if asset.kind == .skill {
                            HubButton(title: "edit", kind: .inlineAction) { editingSkillPath = asset.path }
                        }
                        if asset.kind == .mcp {
                            HubButton(title: asset.enabled ? "disable" : "enable", kind: .inlineAction) {
                                toggleMCP(asset, providerID: row.id)
                            }
                        }
                        if asset.kind == .skill, selectedProject != nil {
                            HubButton(title: "copy to project", kind: .accentInline) {
                                copySkill(asset, from: row)
                            }
                        }
                        if asset.kind == .mcp {
                            Menu("copy") {
                                ForEach(copyTargets.filter { $0 != row.id }, id: \.self) { toolID in
                                    Button(ToolPalette.label(for: toolID)) {
                                        copyMCP(asset, from: row.id, to: toolID)
                                    }
                                }
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .fixedSize()
                            .font(HubFont.mono(10))
                        }
                    }
                    .frame(minHeight: 24)
                }
                if assets.count > 12 {
                    Text("+\(assets.count - 12) more")
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textFaint)
                }
            }
        }
    }

    /// Copy every skill in the library into one provider's skill directories for
    /// the selected project. This is the "push the same setup into another one"
    /// action in the toolbar (§3b).
    private func copySkills(to toolID: String) {
        guard let project = selectedProject else {
            status = "Pick a project scope first"
            return
        }
        guard let spec = ProviderCatalog.specs().first(where: { $0.id == toolID }) else { return }
        let fm = FileManager.default
        var copied = 0
        for relative in spec.projectSkillDirs {
            let baseDir = (project.path as NSString).appendingPathComponent(relative)
            for group in SkillStore.deduplicatedGlobalSkills(skillStore.globalSkills) {
                guard let skill = group.skills.first else { continue }
                let destination = (baseDir as NSString).appendingPathComponent(skill.name)
                guard !fm.fileExists(atPath: destination) else { continue }
                do {
                    try fm.createDirectory(atPath: baseDir, withIntermediateDirectories: true)
                    try fm.copyItem(atPath: skill.path, toPath: destination)
                    copied += 1
                } catch {
                    continue
                }
            }
        }
        status = copied == 0
            ? "\(ToolPalette.label(for: toolID)) already has these skills"
            : "Copied \(copied) skill\(copied == 1 ? "" : "s") to \(ToolPalette.label(for: toolID))"
        reload()
    }

    private func shortPath(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
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
