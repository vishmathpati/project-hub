import SwiftUI

// MARK: - Named config profiles

struct ProfilesView: View {
    @EnvironmentObject var skillStore: SkillStore
    @EnvironmentObject var mcpStore: MCPStore

    @State private var profiles: [HubProfile] = []
    @State private var isLoading = true
    @State private var showSaveSheet = false
    @State private var pendingRestore: HubProfile?
    @State private var pendingDelete: HubProfile?
    @State private var pendingRename: HubProfile?
    @State private var renameText = ""
    @State private var report: ProfileRestoreReport?
    @State private var actionError: String?

    private static let savedFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            HubPageHeader(
                title: "Profiles",
                subtitle: subtitle,
                actions: { headerActions }
            )
            if isLoading {
                loadingView
            } else if profiles.isEmpty {
                emptyState
            } else {
                profileList
            }
        }
        .background(HubTheme.bg)
        .task { await reload() }
        .sheet(isPresented: $showSaveSheet) {
            SaveProfileSheet(existingNames: profiles.map(\.name)) { name in
                await save(name: name)
            }
        }
        .alert("Restore \"\(pendingRestore?.name ?? "")\"?", isPresented: Binding(
            get: { pendingRestore != nil },
            set: { if !$0 { pendingRestore = nil } }
        )) {
            Button("Restore") {
                if let profile = pendingRestore { restore(profile) }
                pendingRestore = nil
            }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: {
            Text("Adds back anything missing from this profile. Nothing is removed — entries it does not list, and entries already present, stay as they are. Hooks are recorded only; Project Hub does not write hook config.")
        }
        .alert("Restore finished", isPresented: Binding(
            get: { report != nil },
            set: { if !$0 { report = nil } }
        )) {
            Button("OK", role: .cancel) { report = nil }
        } message: {
            Text(reportMessage)
        }
        .alert("Delete \"\(pendingDelete?.name ?? "")\"?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let profile = pendingDelete { delete(profile) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Removes the saved profile only. Nothing on disk is touched.")
        }
        .alert("Rename profile", isPresented: Binding(
            get: { pendingRename != nil },
            set: { if !$0 { pendingRename = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let profile = pendingRename { rename(profile, to: renameText) }
                pendingRename = nil
            }
            Button("Cancel", role: .cancel) { pendingRename = nil }
        } message: {
            Text("Choose a new name for \"\(pendingRename?.name ?? "")\".")
        }
        .alert("Couldn't update profiles", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    // MARK: - Header

    private var subtitle: String {
        if isLoading { return "Reading saved profiles" }
        if profiles.isEmpty { return "Snapshot the global setup, then switch back to it in one click" }
        return "\(profiles.count) saved set\(profiles.count == 1 ? "" : "s") · global scope"
    }

    @ViewBuilder
    private var headerActions: some View {
        HubButton(title: "Save current as…", kind: .primary, systemImage: "plus.circle.fill") {
            showSaveSheet = true
        }
    }

    // MARK: - List

    private var profileList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                    if index > 0 { HubRowSeparator() }
                    profileRow(profile)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func profileRow(_ profile: HubProfile) -> some View {
        HubListRow(
            status: .neutral,
            name: profile.name,
            caption: "saved \(Self.savedFormatter.localizedString(for: profile.savedAt, relativeTo: Date())) · \(profile.scope)"
        ) { active in
            if active {
                HStack(spacing: 6) {
                    HubButton(title: "restore", kind: .inlineAction) { pendingRestore = profile }
                    Menu {
                        Button("Rename…") {
                            renameText = profile.name
                            pendingRename = profile
                        }
                        Divider()
                        Button(role: .destructive) { pendingDelete = profile } label: {
                            Text("Delete profile")
                        }
                    } label: {
                        Text("···")
                            .font(HubFont.mono(10))
                            .foregroundStyle(HubTheme.textMid)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            } else {
                HubRowCounts(counts: [
                    (profile.skills.count == 0 ? nil : profile.skills.count, "skl"),
                    (profile.agents.count == 0 ? nil : profile.agents.count, "agt"),
                    (profile.mcpServers.count == 0 ? nil : profile.mcpServers.count, "mcp"),
                    (profile.hooks.count == 0 ? nil : profile.hooks.count, "hok"),
                    (profile.commands.count == 0 ? nil : profile.commands.count, "cmd"),
                ])
            }
        }
    }

    // MARK: - Empty / loading

    private var loadingView: some View {
        VStack {
            ProgressView()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 26))
                .foregroundStyle(HubTheme.textFaint)
            Text("No profiles yet")
                .font(HubFont.sectionTitle)
                .foregroundStyle(HubTheme.text)
            Text("Save the current global setup — skills, agents, MCP servers, hooks and commands — then switch back to it in one click.")
                .font(HubFont.caption)
                .foregroundStyle(HubTheme.textDim)
                .multilineTextAlignment(.center)
            HubButton(title: "Save current as…", kind: .primary, systemImage: "plus.circle.fill") {
                showSaveSheet = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    // MARK: - Actions

    private func reload() async {
        let loaded = await Task.detached(priority: .utility) {
            ProfileStore.list()
        }.value
        await MainActor.run {
            profiles = loaded
            isLoading = false
        }
    }

    private func save(name: String) async {
        let next = await Task.detached(priority: .userInitiated) {
            _ = ProfileStore.save(name: name)
            return ProfileStore.list()
        }.value
        await MainActor.run { profiles = next }
    }

    private func delete(_ profile: HubProfile) {
        Task.detached(priority: .utility) {
            ProfileStore.delete(name: profile.name)
            let next = ProfileStore.list()
            await MainActor.run { profiles = next }
        }
    }

    private func rename(_ profile: HubProfile, to newName: String) {
        Task.detached(priority: .utility) {
            let ok = ProfileStore.rename(from: profile.name, to: newName)
            let next = ProfileStore.list()
            await MainActor.run {
                profiles = next
                if !ok { actionError = "Couldn't rename \"\(profile.name)\". Pick a name that is not already used." }
            }
        }
    }

    private func restore(_ profile: HubProfile) {
        Task.detached(priority: .userInitiated) {
            let result = ProfileStore.restore(profile)
            await MainActor.run {
                report = result
                skillStore.refresh()
                mcpStore.refresh()
            }
        }
    }

    private var reportMessage: String {
        guard let report else { return "" }
        var parts = [
            "Applied \(report.applied) entr\(report.applied == 1 ? "y" : "ies")",
            "left \(report.skipped) already present",
        ]
        if !report.errors.isEmpty {
            parts.append("\(report.errors.count) could not be applied")
        }
        var message = parts.joined(separator: " · ")
        if !report.errors.isEmpty {
            message += "\n" + report.errors.prefix(3).joined(separator: "\n")
        }
        return message
    }
}

// MARK: - Save sheet

private struct SaveProfileSheet: View {
    let existingNames: [String]
    let onSave: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var saving = false

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var replacesExisting: Bool {
        !trimmed.isEmpty && existingNames.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save current setup as…")
                .font(HubFont.sans(15, .bold))
                .foregroundStyle(HubTheme.textStrong)

            Text("Captures the global skills, agents, MCP servers, hooks and commands on this Mac.")
                .font(HubFont.caption)
                .foregroundStyle(HubTheme.textDim)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(HubFont.body)

            if replacesExisting {
                Text("A profile named \"\(trimmed)\" already exists. Saving replaces it.")
                    .font(HubFont.caption)
                    .foregroundStyle(HubTheme.warn)
            }

            HStack {
                HubButton(title: "Cancel", kind: .secondary) { dismiss() }
                Spacer()
                HubButton(title: saving ? "Saving…" : "Save", kind: .primary) {
                    saving = true
                    Task {
                        await onSave(trimmed)
                        dismiss()
                    }
                }
                .disabled(trimmed.isEmpty || saving)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
