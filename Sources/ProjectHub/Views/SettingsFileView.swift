import SwiftUI

// MARK: - settings.json deep editor

struct SettingsFileView: View {
    @State private var loaded: LoadedUserSettings?
    @State private var loadError: String?
    @State private var saveError: String?
    @State private var pending: (before: String, after: String)?
    @State private var allowText = ""
    @State private var denyText = ""
    @State private var askText = ""
    @State private var dirsText = ""
    @State private var modelText = ""
    @State private var cleanupText = ""
    @State private var approveAll = false
    @State private var enabledText = ""
    @State private var disabledText = ""
    @State private var styleText = ""
    @State private var statusSegments: Set<StatusLineSegment> = []
    @State private var statusSeparator = SettingsReader.statusLineSeparators[0]
    @State private var spinnerMode = "append"
    @State private var spinnerRows: [SpinnerVerb] = []
    @State private var newVerb = ""
    @State private var envText = ""

    private struct SpinnerVerb: Identifiable {
        let id = UUID()
        var text: String
        var enabled: Bool
    }

    var body: some View {
        VStack(spacing: 0) {
            if let err = loadError {
                errorState(err)
            } else if loaded != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: HubTheme.sectionGap) {
                        scopeBanner
                        if pending != nil { confirmCard }
                        permissionsSection
                        behaviourSection
                        uiSection
                        envSection
                        hooksSection
                    }
                    .padding(HubTheme.contentPadding)
                }
            } else {
                errorState("Loading settings.")
            }
            Divider()
            footer
        }
        .onAppear { reload() }
    }

    // MARK: - Sections

    /// Says which file this is, who it applies to, and what saving does. Without
    /// this the page is a grid of key names with no consequence attached.
    private var scopeBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("User settings, apply to every project on this Mac")
                .font(HubFont.rowPrimary)
                .foregroundStyle(HubTheme.text)
            Text("Saving backs the file up first, then writes it. If the file changed since you opened this page the save is refused rather than overwriting the newer version. Keys this page does not show are left exactly as they are.")
                .font(.system(size: 11))
                .foregroundStyle(HubTheme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
            if let path = loaded?.path {
                Text(path)
                    .font(HubFont.mono(10))
                    .foregroundStyle(HubTheme.textFaint)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HubTheme.cardPadding)
        .hubCard()
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading(title: "Permissions", trailing: { HubButton(title: "save", kind: .inlineAction) { stageWrite(kind: "permissions") } })
            sectionNote("What Claude Code may do without stopping to ask you. Rules are checked Deny, then Ask, then Allow, so a Deny rule always wins even if an Allow rule matches. A rule is written Tool(specifier), and a bare tool name allows the whole tool.")
            VStack(spacing: 10) {
                rowField("allow", help: "Actions that run without asking. Examples: Bash(npm run test:*), Read(~/.zshrc), WebFetch(domain:example.com). One rule per line.",
                         placeholder: "Bash(npm run test:*)", text: $allowText)
                rowField("deny", help: "Actions that are always blocked. Overrides allow and ask. Examples: WebFetch, Bash(curl:*).",
                         placeholder: "WebFetch", text: $denyText)
                rowField("ask", help: "Actions that always prompt you first, even when an allow rule would match. Examples: Bash(git push:*), Edit.",
                         placeholder: "Bash(git push:*)", text: $askText)
                rowField("additionalDirectories", help: "Folders outside this project that Claude Code may read. One path per line. Only needed when work spans repos.",
                         placeholder: "~/Documents/shared", text: $dirsText)
            }
            .padding(HubTheme.cardPadding)
            .hubCard()
        }
    }

    private var behaviourSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading(title: "Behaviour", trailing: { HubButton(title: "save", kind: .inlineAction) { stageWrite(kind: "behaviour") } })
            sectionNote("Defaults for every session you start, and which project MCP servers load without a prompt.")
            VStack(spacing: 10) {
                rowField("model", help: "Model new sessions use, for example claude-sonnet-5. Leave empty to use whatever your account defaults to.",
                         placeholder: "claude-sonnet-5", text: $modelText)
                rowField("cleanupPeriodDays", help: "Days chat transcripts are kept before Claude Code deletes them. Default 30. Lower means less history, not less disk.",
                         placeholder: "30", text: $cleanupText)
                rowField("enabledMcpjsonServers", help: "Project MCP servers approved to load without a prompt. Names must match the server names in that project's .mcp.json. One per line.",
                         placeholder: "docs", text: $enabledText)
                rowField("disabledMcpjsonServers", help: "Project MCP servers blocked from loading at all. Wins over the enabled list above. One per line.",
                         placeholder: "playwright", text: $disabledText)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("enableAllProjectMcpServers").font(HubFont.secondary).foregroundStyle(HubTheme.text)
                        Spacer(minLength: 12)
                        HubToggle(isOn: $approveAll)
                    }
                    Text("Approve every MCP server in every project automatically. Makes both lists above irrelevant, and means a server added by a repo you clone starts without you seeing it.")
                        .font(.system(size: 10)).foregroundStyle(HubTheme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(HubTheme.cardPadding)
            .hubCard()
        }
    }

    private var uiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading(title: "UI", trailing: { HubButton(title: "save", kind: .inlineAction) { stageWrite(kind: "ui") } })
            sectionNote("How Claude Code looks while it runs. These change your terminal display only, never what the agent is allowed to do.")
            VStack(alignment: .leading, spacing: 14) {
                statusLineBuilder
                rowField("outputStyle", help: "Named output style, for example Explanatory or Concise. Leave empty for the default.",
                         placeholder: "Explanatory", text: $styleText)
                spinnerEditor
            }
            .padding(HubTheme.cardPadding)
            .hubCard()
        }
    }

    /// Segment toggles plus the generated one-liner, previewed before it is written.
    private var statusLineBuilder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("statusLine").font(HubFont.machine).foregroundStyle(HubTheme.text)
            controlHelp("The command Claude Code runs after each reply to draw the line under the prompt. Switch a segment on to generate it; the one-liner runs with sh and needs jq on your PATH.")
            VStack(alignment: .leading, spacing: 7) {
                ForEach(StatusLineSegment.allCases) { segment in
                    HStack(alignment: .top, spacing: 8) {
                        HubToggle(isOn: segmentBinding(segment))
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(segment.title).font(HubFont.secondary).foregroundStyle(HubTheme.text)
                            controlHelp(segment.detail)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            HStack(spacing: 8) {
                Text("separator").font(HubFont.secondary).foregroundStyle(HubTheme.textMid)
                Picker("", selection: $statusSeparator) {
                    ForEach(SettingsReader.statusLineSeparators, id: \.self) { sep in
                        Text(sep.trimmingCharacters(in: .whitespaces)).tag(sep)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 150)
                controlHelp("Printed between the selected segments.")
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("generated command").font(HubFont.machine).foregroundStyle(HubTheme.textFaint)
                Text(generatedStatusLine.isEmpty ? "—" : generatedStatusLine)
                    .font(HubFont.machine)
                    .foregroundStyle(generatedStatusLine.isEmpty ? HubTheme.textFaint : HubTheme.text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HubTheme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(HubTheme.line.opacity(0.6), lineWidth: 0.5))
                controlHelp(statusLineNote)
                if let current = loaded?.model.ui.statusLine, current != generatedStatusLine {
                    Text("current: \(current)")
                        .font(HubFont.machine)
                        .foregroundStyle(HubTheme.textDim)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// The spinner words as rows — toggle, edit, reorder, delete — with what the
    /// working spinner will look like.
    private var spinnerEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("spinnerVerbs").font(HubFont.machine).foregroundStyle(HubTheme.text)
            controlHelp("The words Claude Code shows while it works. Edit a word in place, move it with the arrows, or switch it off to leave it out of the file.")
            HStack(spacing: 8) {
                Picker("", selection: $spinnerMode) {
                    ForEach(SettingsReader.spinnerModes, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 180)
                controlHelp(spinnerMode == "replace" ? "replace: only your words are shown." : "append: the built-in words stay and yours are added.")
                Spacer(minLength: 0)
            }
            LazyVStack(spacing: 5) {
                ForEach($spinnerRows) { $verb in
                    HStack(spacing: 6) {
                        HubToggle(isOn: $verb.enabled)
                        TextField("verb", text: $verb.text)
                            .textFieldStyle(.plain)
                            .font(HubFont.secondary)
                            .foregroundStyle(HubTheme.text)
                            .padding(.horizontal, 8)
                            .frame(height: 26)
                            .background(HubTheme.field)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(HubTheme.line.opacity(0.6), lineWidth: 0.5))
                        HubIconButton(systemImage: "chevron.up", help: "Move up") { moveVerb(verb.id, by: -1) }
                        HubIconButton(systemImage: "chevron.down", help: "Move down") { moveVerb(verb.id, by: 1) }
                        HubIconButton(systemImage: "trash", help: "Remove word") { removeVerb(verb.id) }
                    }
                }
            }
            HStack(spacing: 6) {
                TextField("new verb", text: $newVerb)
                    .textFieldStyle(.plain)
                    .font(HubFont.secondary)
                    .foregroundStyle(HubTheme.text)
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(HubTheme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(HubTheme.line.opacity(0.6), lineWidth: 0.5))
                    .onSubmit { addVerb() }
                HubButton(title: "add", kind: .inlineAction) { addVerb() }
            }
            HStack(spacing: 8) {
                Text("preview").font(HubFont.machine).foregroundStyle(HubTheme.textFaint)
                Text(spinnerPreview).font(HubFont.mono(12)).foregroundStyle(HubTheme.text)
                controlHelp(spinnerNote)
                Spacer(minLength: 0)
            }
        }
    }

    private var generatedStatusLine: String {
        SettingsReader.statusLineCommand(segments: statusSegments, separator: statusSeparator)
    }

    private func segmentBinding(_ segment: StatusLineSegment) -> Binding<Bool> {
        Binding(
            get: { statusSegments.contains(segment) },
            set: { on in
                if on { statusSegments.insert(segment) } else { statusSegments.remove(segment) }
            }
        )
    }

    /// What saving would do to statusLine, stated next to the preview.
    private var statusLineNote: String {
        let current = loaded?.model.ui.statusLine
        if generatedStatusLine.isEmpty {
            return current == nil
                ? "No segments on. Nothing is written until one is switched on."
                : "No segments on. The saved command is left as it is."
        }
        if generatedStatusLine == current { return "Matches the command already saved." }
        return current == nil
            ? "Save writes this command to statusLine."
            : "Save replaces the command already saved."
    }

    private var spinnerPreview: String {
        guard let first = spinnerRows.first(where: { $0.enabled }) else { return "✻ …" }
        return "✻ \(first.text)…"
    }

    private var spinnerNote: String {
        let on = spinnerRows.filter { $0.enabled }.count
        if spinnerRows.isEmpty { return "No words yet — Claude Code's built-in words are used." }
        if on == 0 { return "No words switched on — nothing of yours is shown." }
        return "\(on) of \(spinnerRows.count) written, cycled in this order."
    }

    private func addVerb() {
        let word = newVerb.trimmingCharacters(in: .whitespacesAndNewlines)
        newVerb = ""
        guard !word.isEmpty,
              !spinnerRows.contains(where: { $0.text.caseInsensitiveCompare(word) == .orderedSame })
        else { return }
        spinnerRows.append(SpinnerVerb(text: word, enabled: true))
    }

    private func moveVerb(_ id: UUID, by offset: Int) {
        guard let i = spinnerRows.firstIndex(where: { $0.id == id }) else { return }
        let j = i + offset
        guard spinnerRows.indices.contains(j) else { return }
        spinnerRows.swapAt(i, j)
    }

    private func removeVerb(_ id: UUID) {
        spinnerRows.removeAll { $0.id == id }
    }

    /// One line of plain language under a control.
    private func controlHelp(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(HubTheme.textFaint)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// One line of plain language per section, because a grid of key names teaches
    /// nothing about what changing them does.
    private func sectionNote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(HubTheme.textFaint)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var envSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading(title: "Environment", trailing: { HubButton(title: "save", kind: .inlineAction) { stageWrite(kind: "env") } })
            sectionNote("Variables set for every session Claude Code starts. One KEY=value per line. Useful for API tokens and proxy settings. These are visible to any command the agent runs, so do not put secrets here that you would not put in a shell profile.")
            TextEditor(text: $envText)
                .font(HubFont.machine)
                .frame(minHeight: 90)
                .padding(6)
                .background(HubTheme.field)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(HubTheme.line.opacity(0.6), lineWidth: 0.5))
                .padding(HubTheme.cardPadding)
                .hubCard()
        }
    }

    private var hooksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading("Hooks", count: loaded?.model.hookEvents.count)
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(loaded?.model.hookEvents ?? [], id: \.self) { event in
                    Text(event).font(HubFont.machine).foregroundStyle(HubTheme.textDim)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(HubTheme.raised)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(HubTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hubCard()
        }
    }

    private var confirmCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Confirm write").font(HubFont.rowPrimary).foregroundStyle(HubTheme.text)
            if let p = pending {
                Text("\(SettingsReader.settingsPath()) · \(p.after.components(separatedBy: "\n").count) lines after edit. Backup kept.").font(HubFont.machine).foregroundStyle(HubTheme.textDim).lineLimit(6)
            }
            HStack(spacing: 8) {
                HubButton(title: "Cancel", kind: .secondary) { pending = nil }
                HubButton(title: "Write", kind: .primary) { confirmWrite() }
            }
            if let err = saveError { Text(err).font(HubFont.caption).foregroundStyle(HubTheme.bad) }
        }
        .padding(HubTheme.cardPadding)
        .background(HubTheme.warnBg)
        .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: HubTheme.Radius.card).strokeBorder(HubTheme.warn, lineWidth: 1))
    }

    private var footer: some View {
        HStack {
            Image(systemName: "info.circle").font(.system(size: 10)).foregroundColor(.secondary)
            Text("Hooks are read-only. Writes back up settings.json first.").font(.system(size: 10)).foregroundColor(.secondary)
            Spacer(minLength: 8)
            HubButton(title: "Reload", kind: .inlineAction) { reload() }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 28)).foregroundColor(.secondary)
            Text("Settings unavailable").font(.system(size: 14, weight: .semibold))
            Text(message).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
            HubButton(title: "Retry", kind: .secondary) { reload() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private func rowField(_ key: String, help: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 10) {
                Text(key).font(HubFont.machine).foregroundStyle(HubTheme.text)
                    .frame(width: 190, alignment: .leading).lineLimit(1)
                TextField(placeholder, text: text).textFieldStyle(.plain).font(HubFont.secondary).foregroundStyle(HubTheme.text)
                    .padding(.horizontal, 8).frame(height: 26).background(HubTheme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(HubTheme.line.opacity(0.6), lineWidth: 0.5))
            }
            Text(help)
                .font(.system(size: 10))
                .foregroundStyle(HubTheme.textFaint)
                .padding(.leading, 200)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Data

    private func reload() {
        do {
            let l = try SettingsReader.load()
            loaded = l
            loadError = nil
            saveError = nil
            pending = nil
            allowText = l.model.permissions.allow.joined(separator: ", ")
            denyText = l.model.permissions.deny.joined(separator: ", ")
            askText = l.model.permissions.ask.joined(separator: ", ")
            dirsText = l.model.permissions.additionalDirectories.joined(separator: ", ")
            modelText = l.model.behaviour.model ?? ""
            cleanupText = l.model.behaviour.cleanupPeriodDays.map(String.init) ?? ""
            approveAll = l.model.behaviour.enableAllProjectMcpServers ?? false
            enabledText = l.model.behaviour.enabledMcpjsonServers.joined(separator: ", ")
            disabledText = l.model.behaviour.disabledMcpjsonServers.joined(separator: ", ")
            styleText = l.model.ui.outputStyle ?? ""
            if let cmd = l.model.ui.statusLine, let match = SettingsReader.statusLineSelection(matching: cmd) {
                statusSegments = match.segments
                statusSeparator = match.separator
            } else {
                statusSegments = []
                statusSeparator = SettingsReader.statusLineSeparators[0]
            }
            spinnerMode = l.model.ui.spinnerMode ?? "append"
            spinnerRows = l.model.ui.spinnerVerbs.map { SpinnerVerb(text: $0, enabled: true) }
            newVerb = ""
            envText = l.model.env.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
        } catch {
            loaded = nil
            loadError = error.localizedDescription
        }
    }

    private func split(_ s: String) -> [String] {
        s.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func stageWrite(kind: String) {
        guard let l = loaded else { return }
        var root = l.root
        switch kind {
        case "permissions":
            root = SettingsReader.rootWithPermissions(root, PermissionSection(allow: split(allowText), deny: split(denyText), ask: split(askText), additionalDirectories: split(dirsText)))
        case "behaviour":
            root = SettingsReader.rootWithBehaviour(root, BehaviourSection(model: modelText.isEmpty ? nil : modelText, cleanupPeriodDays: Int(cleanupText.trimmingCharacters(in: .whitespaces)), enableAllProjectMcpServers: approveAll, enabledMcpjsonServers: split(enabledText), disabledMcpjsonServers: split(disabledText)))
        case "ui":
            let loadedUI = l.model.ui
            let verbs = spinnerRows.filter { $0.enabled }.map { $0.text }
            let mode: String? = spinnerMode.isEmpty ? nil : spinnerMode
            let spinnerChanged = (mode ?? "append") != (loadedUI.spinnerMode ?? "append") || verbs != loadedUI.spinnerVerbs
            root = SettingsReader.rootWithUI(root, UISection(
                statusLine: generatedStatusLine.isEmpty ? loadedUI.statusLine : generatedStatusLine,
                outputStyle: styleText.isEmpty ? nil : styleText,
                spinnerMode: spinnerChanged ? mode : loadedUI.spinnerMode,
                spinnerVerbs: spinnerChanged ? verbs : loadedUI.spinnerVerbs))
        case "env":
            var env: [String: String] = [:]
            for line in envText.components(separatedBy: .newlines) {
                guard let eq = line.firstIndex(of: "=") else { continue }
                let k = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
                if k.isEmpty { continue }
                env[k] = String(line[line.index(after: eq)...])
            }
            root = SettingsReader.rootWithEnv(root, env)
        default:
            return
        }
        guard let after = SettingsReader.jsonText(for: root) else {
            saveError = "Could not encode settings as JSON. Nothing was written."
            return
        }
        guard after != l.text else { return }
        pending = (before: l.text, after: after)
        saveError = nil
    }

    private func confirmWrite() {
        guard let l = loaded, let p = pending else { return }
        do {
            try ConfigWriter.applyTextPreview(configPath: l.path, expectedBefore: p.before, approvedAfter: p.after)
            reload()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
