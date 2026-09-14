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

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading(title: "Permissions", trailing: { HubButton(title: "save", kind: .inlineAction) { stageWrite(kind: "permissions") } })
            VStack(spacing: 8) {
                rowField("allow", text: $allowText)
                rowField("deny", text: $denyText)
                rowField("ask", text: $askText)
                rowField("additionalDirectories", text: $dirsText)
            }
            .padding(HubTheme.cardPadding)
            .hubCard()
        }
    }

    private var behaviourSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading(title: "Behaviour", trailing: { HubButton(title: "save", kind: .inlineAction) { stageWrite(kind: "behaviour") } })
            VStack(spacing: 8) {
                rowField("model", text: $modelText)
                rowField("cleanupPeriodDays", text: $cleanupText)
                rowField("enabledMcpjsonServers", text: $enabledText)
                rowField("disabledMcpjsonServers", text: $disabledText)
                HStack {
                    Text("enableAllProjectMcpServers").font(HubFont.secondary).foregroundStyle(HubTheme.text)
                    Spacer(minLength: 12)
                    HubToggle(isOn: $approveAll)
                }
            }
            .padding(HubTheme.cardPadding)
            .hubCard()
        }
    }

    private var uiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading(title: "UI", trailing: { HubButton(title: "save", kind: .inlineAction) { stageWrite(kind: "ui") } })
            VStack(spacing: 8) {
                rowField("statusLine", text: $statusText)
                rowField("outputStyle", text: $styleText)
                rowField("spinner mode", text: $spinnerMode)
                rowField("spinner verbs", text: $spinnerText)
            }
            .padding(HubTheme.cardPadding)
            .hubCard()
        }
    }

    private var envSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionHeading(title: "Environment", trailing: { HubButton(title: "save", kind: .inlineAction) { stageWrite(kind: "env") } })
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

    private func rowField(_ key: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Text(key).font(HubFont.machine).foregroundStyle(HubTheme.textDim).frame(width: 190, alignment: .leading).lineLimit(1)
            TextField("—", text: text).textFieldStyle(.plain).font(HubFont.secondary).foregroundStyle(HubTheme.text)
                .padding(.horizontal, 8).frame(height: 26).background(HubTheme.field)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(HubTheme.line.opacity(0.6), lineWidth: 0.5))
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
