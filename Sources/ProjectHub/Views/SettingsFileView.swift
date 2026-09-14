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
    @State private var statusText = ""
    @State private var styleText = ""
    @State private var spinnerMode = ""
    @State private var spinnerText = ""
    @State private var envText = ""

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
            VStack(spacing: 10) {
                rowField("statusLine", help: "Shell command that draws the status line at the bottom. Runs after every reply, so a slow script slows every turn.",
                         placeholder: "/path/to/statusline.sh", text: $statusText)
                rowField("outputStyle", help: "Named output style, for example Explanatory or Concise. Leave empty for the default.",
                         placeholder: "Explanatory", text: $styleText)
                rowField("spinner mode", help: "append keeps the built-in words and adds yours. replace hides the built-in words and shows only yours.",
                         placeholder: "append", text: $spinnerMode)
                rowField("spinner verbs", help: "The words shown while Claude is working. Comma separated.",
                         placeholder: "Pondering, Scheming, Noodling", text: $spinnerText)
            }
            .padding(HubTheme.cardPadding)
            .hubCard()
        }
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
            statusText = l.model.ui.statusLine ?? ""
            styleText = l.model.ui.outputStyle ?? ""
            spinnerMode = l.model.ui.spinnerMode ?? ""
            spinnerText = l.model.ui.spinnerVerbs.joined(separator: ", ")
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
            root = SettingsReader.rootWithUI(root, UISection(statusLine: statusText.isEmpty ? nil : statusText, outputStyle: styleText.isEmpty ? nil : styleText, spinnerMode: spinnerMode.isEmpty ? nil : spinnerMode, spinnerVerbs: split(spinnerText)))
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
