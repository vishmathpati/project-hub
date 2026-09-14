import SwiftUI
import AppKit

// MARK: - Commands sub-tab (inside ProjectDetailView)

struct CommandsView: View {
    let project: Project
    @Binding var reloadTick: Int

    @State private var projectCommands: [SlashCommand] = []
    @State private var globalCommands: [SlashCommand] = []
    @State private var showNewCommandSheet: Bool = false
    @State private var selectedCommand: SlashCommand? = nil
    @State private var deletingCommand: SlashCommand? = nil
    @State private var confirmDelete: Bool = false
    @State private var lastError: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            commandBar
            Divider()
            if projectCommands.isEmpty && globalCommands.isEmpty {
                emptyState
            } else {
                commandList
            }
        }
        .task(id: "\(project.path)#\(reloadTick)") {
            let projectPath = project.path
            let loaded = await Task.detached(priority: .utility) {
                (
                    project: CommandsReader.commands(for: projectPath),
                    global: CommandsReader.globalCommands()
                )
            }.value
            projectCommands = loaded.project
            globalCommands = loaded.global
        }
        .sheet(isPresented: $showNewCommandSheet) {
            NewCommandSheet(projectPath: project.path) {
                reloadTick &+= 1
            }
        }
        .sheet(item: $selectedCommand) { command in
            CommandDetailSheet(command: command, projectPath: project.path) {
                reloadTick &+= 1
            }
        }
        .alert("Delete \"/\(deletingCommand?.name ?? "")\"?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) { deletingCommand = nil }
            Button("Delete", role: .destructive) {
                if let command = deletingCommand {
                    do {
                        try CommandsReader.delete(command, from: project.path)
                        reloadTick &+= 1
                    } catch {
                        lastError = error.localizedDescription
                    }
                    deletingCommand = nil
                }
            }
        } message: {
            Text("This deletes the .md file from .claude/commands/. This action cannot be undone.")
        }
        .alert("Couldn't delete command", isPresented: Binding(
            get: { lastError != nil },
            set: { if !$0 { lastError = nil } }
        )) {
            Button("OK", role: .cancel) { lastError = nil }
        } message: {
            Text(lastError ?? "")
        }
    }

    // MARK: - Command bar

    private var commandBar: some View {
        HStack(spacing: 8) {
            Text("\(projectCommands.count) command\(projectCommands.count == 1 ? "" : "s")")
                .font(HubFont.machine)
                .foregroundStyle(HubTheme.textDim)
            Spacer()
            HubButton(title: "New Command", kind: .primary, systemImage: "plus.circle.fill") {
                showNewCommandSheet = true
            }
        }
        .padding(.horizontal, HubTheme.contentPadding)
        .padding(.vertical, 10)
    }

    // MARK: - Command list

    private var commandList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(projectCommands) { command in
                    commandRow(command)
                }
                if !globalCommands.isEmpty {
                    globalSection
                }
            }
            .padding(.horizontal, HubTheme.contentPadding)
            .padding(.vertical, 10)
        }
    }

    private func commandRow(_ command: SlashCommand) -> some View {
        Button(action: { selectedCommand = command }) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: HubTheme.Radius.tileLarge)
                        .fill(HubTheme.accent.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: "slash.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HubTheme.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("/\(command.name)")
                            .font(HubFont.mono(12, .semibold))
                            .foregroundStyle(HubTheme.text)
                            .lineLimit(1)
                        if !command.argumentHint.isEmpty {
                            badge(command.argumentHint)
                        }
                    }
                    if !command.description.isEmpty {
                        Text(command.description)
                            .font(HubFont.caption)
                            .foregroundStyle(HubTheme.textMid)
                            .lineLimit(2)
                    }
                    if !command.allowedTools.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(command.allowedTools, id: \.self) { tool in
                                    Text(tool)
                                        .font(HubFont.mono(9, .medium))
                                        .foregroundStyle(HubTheme.textDim)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(HubTheme.stroke.opacity(0.3))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 8)

                Button(action: {
                    deletingCommand = command
                    confirmDelete = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(HubTheme.bad.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Delete command")
            }
            .padding(10)
            .background(HubTheme.raised)
            .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: HubTheme.Radius.card)
                .stroke(HubTheme.line.opacity(0.4), lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Global commands (read-only)

    private var globalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HubSectionHeading("Global commands", count: globalCommands.count)
                .padding(.top, 8)
            ForEach(globalCommands) { command in
                globalCommandRow(command)
            }
        }
    }

    private func globalCommandRow(_ command: SlashCommand) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: HubTheme.Radius.tileLarge)
                    .fill(HubTheme.stroke.opacity(0.3))
                    .frame(width: 34, height: 34)
                Image(systemName: "slash.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HubTheme.textFaint)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("/\(command.name)")
                        .font(HubFont.mono(12, .semibold))
                        .foregroundStyle(HubTheme.textMid)
                        .lineLimit(1)
                    badge(command.scope.rawValue)
                }
                if !command.description.isEmpty {
                    Text(command.description)
                        .font(HubFont.caption)
                        .foregroundStyle(HubTheme.textDim)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(10)
        .background(HubTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: HubTheme.Radius.card)
            .stroke(HubTheme.line.opacity(0.4), lineWidth: 0.5))
        .help("Read-only · lives in ~/.claude/commands")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "slash.circle")
                .font(.system(size: 26))
                .foregroundStyle(HubTheme.textFaint)
            Text("No commands yet")
                .font(HubFont.sectionTitle)
                .foregroundStyle(HubTheme.text)
            Text("No .md files in .claude/commands/ or ~/.claude/commands.")
                .font(HubFont.caption)
                .foregroundStyle(HubTheme.textDim)
                .multilineTextAlignment(.center)
            HubButton(title: "New Command", kind: .primary, systemImage: "plus.circle.fill") {
                showNewCommandSheet = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    // MARK: - Helpers

    private func badge(_ label: String) -> some View {
        Text(label)
            .font(HubFont.mono(9))
            .foregroundStyle(HubTheme.textFaint)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 3)
                .strokeBorder(HubTheme.stroke, lineWidth: 1))
    }
}

// MARK: - New Command Sheet

struct NewCommandSheet: View {
    let projectPath: String
    let onCreated: () -> Void

    @Environment(\.dismiss) var dismiss

    @State private var name:         String = ""
    @State private var description:  String = ""
    @State private var argumentHint: String = ""
    @State private var allowedTools: String = ""
    @State private var model:        String = ""
    @State private var bodyText:     String = ""
    @State private var saveError:    String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("New Command")
                    .font(HubFont.sans(16, .bold))
                    .foregroundStyle(HubTheme.text)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(HubTheme.textDim)
                }
                .buttonStyle(.plain)
            }

            CommandField(label: "Name", placeholder: "e.g. git:commit", text: $name)
            CommandField(label: "Description", placeholder: "When is this command useful?", text: $description)
            CommandField(label: "Argument hint", placeholder: "[branch]", text: $argumentHint)
            CommandField(label: "Allowed tools", placeholder: "Bash(git status:*), Read", text: $allowedTools)
            CommandField(label: "Model", placeholder: "inherit", text: $model)

            CommandPromptEditor(text: $bodyText)

            Spacer()

            HStack {
                HubButton(title: "Cancel", kind: .secondary) { dismiss() }
                Spacer()
                HubButton(title: "Create Command", kind: .primary) { create() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440, height: 560)
        .alert("Couldn't create command", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private func create() {
        do {
            try CommandsReader.create(
                name: name.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                argumentHint: argumentHint.trimmingCharacters(in: .whitespaces),
                allowedTools: CommandsReader.allowedTools(from: allowedTools),
                model: model.trimmingCharacters(in: .whitespaces),
                body: bodyText,
                in: projectPath
            )
            onCreated()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

// MARK: - Command Detail Sheet

struct CommandDetailSheet: View {
    let command: SlashCommand
    let projectPath: String
    let onSaved: () -> Void

    @Environment(\.dismiss) var dismiss

    @State private var isEditing:        Bool = false
    @State private var descriptionText:  String = ""
    @State private var argumentHintText: String = ""
    @State private var allowedToolsText: String = ""
    @State private var modelText:        String = ""
    @State private var bodyText:         String = ""
    @State private var saveError:        String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("/\(command.name)")
                        .font(HubFont.mono(15, .bold))
                        .foregroundStyle(HubTheme.textStrong)
                    Text("Project · .claude/commands")
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textDim)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(HubTheme.textDim)
                }
                .buttonStyle(.plain)
            }

            if isEditing {
                editForm
            } else {
                readOnlyBody
            }

            Divider()
            actions
        }
        .padding(20)
        .frame(width: 460, height: 520)
        .onAppear(perform: loadFields)
        .alert("Couldn't save command", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private var readOnlyBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !command.description.isEmpty {
                Text(command.description)
                    .font(HubFont.body)
                    .foregroundStyle(HubTheme.textMid)
            }
            if !command.argumentHint.isEmpty {
                metaRow("Argument hint", command.argumentHint)
            }
            if !command.allowedTools.isEmpty {
                metaRow("Allowed tools", command.allowedTools.joined(separator: ", "))
            }
            if !command.model.isEmpty {
                metaRow("Model", command.model)
            }

            Divider()

            Text("Prompt")
                .font(HubFont.sans(11, .semibold))
                .foregroundStyle(HubTheme.textDim)
            ScrollView {
                Text(command.body.isEmpty ? "(empty)" : command.body)
                    .font(HubFont.mono(11))
                    .foregroundStyle(HubTheme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 200)
            .background(HubTheme.field)
            .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.tileLarge))
        }
    }

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            CommandField(label: "Description", placeholder: "When is this command useful?", text: $descriptionText)
            CommandField(label: "Argument hint", placeholder: "[branch]", text: $argumentHintText)
            CommandField(label: "Allowed tools", placeholder: "Bash(git status:*), Read", text: $allowedToolsText)
            CommandField(label: "Model", placeholder: "inherit", text: $modelText)
            CommandPromptEditor(text: $bodyText)
        }
    }

    private var actions: some View {
        HStack {
            HubButton(title: "Open in Finder", kind: .secondary) {
                NSWorkspace.shared.activateFileViewerSelecting(
                    [URL(fileURLWithPath: command.filePath)]
                )
            }
            Spacer()
            if isEditing {
                HubButton(title: "Cancel", kind: .secondary) { cancelEditing() }
                HubButton(title: "Save", kind: .primary) { save() }
            } else {
                HubButton(title: "Edit", kind: .secondary) { isEditing = true }
                HubButton(title: "Done", kind: .primary) { dismiss() }
            }
        }
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(HubFont.sans(11, .semibold))
                .foregroundStyle(HubTheme.textDim)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(HubFont.machineLarge)
                .foregroundStyle(HubTheme.text)
                .textSelection(.enabled)
        }
    }

    private func loadFields() {
        descriptionText = command.description
        argumentHintText = command.argumentHint
        allowedToolsText = command.allowedTools.joined(separator: ", ")
        modelText = command.model
        bodyText = command.body
    }

    private func cancelEditing() {
        loadFields()
        isEditing = false
    }

    private func save() {
        let edited = SlashCommand(
            name:         command.name,
            description:  descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            argumentHint: argumentHintText.trimmingCharacters(in: .whitespacesAndNewlines),
            allowedTools: CommandsReader.allowedTools(from: allowedToolsText),
            model:        modelText.trimmingCharacters(in: .whitespacesAndNewlines),
            body:         bodyText,
            filePath:     command.filePath,
            scope:        command.scope
        )
        do {
            try CommandsReader.update(edited, in: projectPath)
            onSaved()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

// MARK: - Form pieces

private struct CommandField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(HubFont.sans(11, .semibold))
                .foregroundStyle(HubTheme.textDim)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

private struct CommandPromptEditor: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Prompt")
                .font(HubFont.sans(11, .semibold))
                .foregroundStyle(HubTheme.textDim)
            TextEditor(text: $text)
                .font(HubFont.mono(11))
                .scrollContentBackground(.hidden)
                .frame(height: 140)
                .background(HubTheme.field)
                .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.tileLarge))
                .overlay(RoundedRectangle(cornerRadius: HubTheme.Radius.tileLarge)
                    .strokeBorder(HubTheme.line, lineWidth: 1))
        }
    }
}
