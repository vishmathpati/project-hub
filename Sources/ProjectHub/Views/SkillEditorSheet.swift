import SwiftUI

// MARK: - Skill Editor Sheet
// Presented as a sheet when the user taps "Edit" on an installed skill row.
// Edits the SKILL.md file inside the skill directory in-place.

struct SkillEditorSheet: View {
    let skillPath: String     // full path to the skill DIRECTORY
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var triggersCSV: String = ""   // comma-separated in the text field
    @State private var bodyText: String = ""
    @State private var loadError: String? = nil
    @State private var saveError: String? = nil

    private var skillMdPath: String {
        (skillPath as NSString).appendingPathComponent("SKILL.md")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Edit Skill")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text((skillPath as NSString).lastPathComponent)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if let err = loadError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    Text("Could not load SKILL.md")
                        .font(.system(size: 13, weight: .semibold))
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // MARK: Frontmatter section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 10) {
                                fieldLabel("Name")
                                TextField("Skill name", text: $name)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12))

                                fieldLabel("Description")
                                TextEditor(text: $description)
                                    .font(.system(size: 12))
                                    .frame(minHeight: 60, maxHeight: 80)
                                    .overlay(RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5))

                                fieldLabel("Triggers (comma-separated)")
                                TextField("be careful, safety mode", text: $triggersCSV)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12))
                                Text("Slash commands that activate this skill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(4)
                        } label: {
                            Text("Frontmatter")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }

                        // MARK: Body section
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Body / Instructions")
                            TextEditor(text: $bodyText)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(minHeight: 200)
                                .overlay(RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5))
                        }
                    }
                    .padding(16)
                }
            }

            if let err = saveError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }

            Divider()

            // Footer buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(loadError != nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 520, height: 560)
        .onAppear { loadSkill() }
    }

    // MARK: - Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
    }

    // MARK: - Load

    private func loadSkill() {
        guard let content = try? String(contentsOfFile: skillMdPath, encoding: .utf8) else {
            loadError = "Cannot read \(skillMdPath)"
            return
        }

        if let fm = SkillReader.parseFrontmatter(content) {
            name        = fm["name"] ?? ((skillPath as NSString).lastPathComponent)
            description = fm["description"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // triggers are stored as a YAML list — re-parse directly from content
            triggersCSV = parseTriggers(from: content).joined(separator: ", ")
        } else {
            // No frontmatter — still let user edit body
            name = (skillPath as NSString).lastPathComponent
        }

        bodyText = stripFrontmatter(from: content)
    }

    // MARK: - Save

    private func save() {
        saveError = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let triggers    = triggersCSV
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Build YAML frontmatter
        var fm = "---\nname: \(trimmedName)\n"

        if trimmedDesc.isEmpty {
            fm += "description: \"\"\n"
        } else {
            // Multi-line block scalar
            let indented = trimmedDesc
                .components(separatedBy: "\n")
                .map { "  \($0)" }
                .joined(separator: "\n")
            fm += "description: |\n\(indented)\n"
        }

        if triggers.isEmpty {
            fm += "triggers: []\n"
        } else {
            fm += "triggers:\n"
            for t in triggers {
                fm += "  - \(t)\n"
            }
        }
        fm += "---"

        let trimmedBody = bodyText.trimmingCharacters(in: .newlines)
        let fullContent = trimmedBody.isEmpty ? fm : "\(fm)\n\n\(trimmedBody)"

        do {
            try fullContent.write(toFile: skillMdPath, atomically: true, encoding: .utf8)
            onSaved()
            dismiss()
        } catch {
            saveError = "Save failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Frontmatter helpers (mirrors AgentReader.stripFrontmatter)

    private func stripFrontmatter(from content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return content }

        var pastSecondDash = false
        var bodyLines: [String] = []
        var dashCount = 0

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                dashCount += 1
                if dashCount == 2 { pastSecondDash = true; continue }
            }
            if pastSecondDash { bodyLines.append(line) }
        }
        return bodyLines.joined(separator: "\n").trimmingCharacters(in: .newlines)
    }

    private func parseTriggers(from content: String) -> [String] {
        let lines = content.components(separatedBy: "\n")
        var inTriggers = false
        var triggers: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "triggers:" { inTriggers = true; continue }
            if inTriggers {
                if trimmed.hasPrefix("- ") {
                    triggers.append(String(trimmed.dropFirst(2))
                        .trimmingCharacters(in: .whitespacesAndNewlines))
                } else if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                    break
                }
            }
        }
        return triggers
    }
}
