import SwiftUI

// MARK: - CursorRulesView
// Sub-tab view for managing .cursor/rules/*.mdc files in a project.

struct CursorRulesView: View {
    let project: Project

    @State private var rules: [CursorRule] = []
    @State private var showingNewSheet = false
    @State private var editingRule: CursorRule? = nil
    @State private var deleteError: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if rules.isEmpty {
                emptyState
            } else {
                rulesList
            }
        }
        .onAppear { reload() }
        .sheet(isPresented: $showingNewSheet) {
            NewCursorRuleSheet(projectPath: project.path) {
                reload()
            }
        }
        .sheet(item: $editingRule) { rule in
            CursorRuleEditorSheet(rule: rule) {
                reload()
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("\(rules.count) rule\(rules.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            if let err = deleteError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            Spacer()
            Button(action: { showingNewSheet = true }) {
                Label("New Rule", systemImage: "plus")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Rules list

    private var rulesList: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(rules) { rule in
                    ruleRow(rule)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func ruleRow(_ rule: CursorRule) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                // Description
                Text(rule.description.isEmpty ? rule.filename : rule.description)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    // Globs pill
                    if !rule.globs.isEmpty {
                        Text(rule.globs)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.10))
                            .clipShape(Capsule())
                            .lineLimit(1)
                    } else {
                        Text("all files")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    // Always apply badge
                    if rule.alwaysApply {
                        Text("always apply")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.10))
                            .clipShape(Capsule())
                    }

                    // Filename label
                    Text(rule.filename)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Edit button
            Button(action: { editingRule = rule }) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Edit rule")

            // Delete button
            Button(action: { deleteRule(rule) }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Delete rule")
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5))
        .contentShape(Rectangle())
        .onTapGesture { editingRule = rule }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No Cursor rules")
                .font(.system(size: 14, weight: .semibold))
            Text("Rules in .cursor/rules/ tell Cursor how to\nbehave in this project.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(action: { showingNewSheet = true }) {
                Label("New Rule", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    // MARK: - Actions

    private func reload() {
        rules = CursorRulesReader.rules(for: project.path)
    }

    private func deleteRule(_ rule: CursorRule) {
        deleteError = nil
        do {
            try CursorRulesReader.delete(filename: rule.filename, from: project.path)
            reload()
        } catch {
            deleteError = "Delete failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - NewCursorRuleSheet

struct NewCursorRuleSheet: View {
    let projectPath: String
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var description: String = ""
    @State private var globs: String = ""
    @State private var alwaysApply: Bool = false
    @State private var bodyText: String = ""
    @State private var saveError: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text("New Cursor Rule")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    fieldGroup("Description") {
                        TextField("Use Bun instead of Node.js", text: $description)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                    }

                    fieldGroup("Globs") {
                        TextField("*.ts, *.tsx", text: $globs)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                        Text("Comma-separated glob patterns. Leave empty to apply to all files.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Toggle("Always Apply", isOn: $alwaysApply)
                        .font(.system(size: 12))

                    fieldGroup("Rule Instructions") {
                        TextEditor(text: $bodyText)
                            .font(.system(size: 12))
                            .frame(minHeight: 160)
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5))
                    }
                }
                .padding(16)
            }

            if let err = saveError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button("Create") { create() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 500, height: 520)
    }

    private func fieldGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            content()
        }
    }

    private func create() {
        saveError = nil
        do {
            try CursorRulesReader.create(
                description: description.trimmingCharacters(in: .whitespaces),
                globs: globs.trimmingCharacters(in: .whitespaces),
                alwaysApply: alwaysApply,
                body: bodyText,
                in: projectPath
            )
            onCreated()
            dismiss()
        } catch {
            saveError = "Create failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - CursorRuleEditorSheet

struct CursorRuleEditorSheet: View {
    let rule: CursorRule
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var description: String = ""
    @State private var globs: String = ""
    @State private var alwaysApply: Bool = false
    @State private var bodyText: String = ""
    @State private var saveError: String? = nil

    var bodyView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Cursor Rule")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(rule.filename)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    fieldGroup("Description") {
                        TextField("Use Bun instead of Node.js", text: $description)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                    }

                    fieldGroup("Globs") {
                        TextField("*.ts, *.tsx", text: $globs)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                        Text("Comma-separated glob patterns. Leave empty to apply to all files.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Toggle("Always Apply", isOn: $alwaysApply)
                        .font(.system(size: 12))

                    fieldGroup("Rule Instructions") {
                        TextEditor(text: $bodyText)
                            .font(.system(size: 12))
                            .frame(minHeight: 160)
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5))
                    }
                }
                .padding(16)
            }

            if let err = saveError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 500, height: 520)
    }

    var body: some View {
        bodyView
            .onAppear { populate() }
    }

    private func fieldGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            content()
        }
    }

    private func populate() {
        description = rule.description
        globs       = rule.globs
        alwaysApply = rule.alwaysApply
        bodyText    = rule.body
    }

    private func save() {
        saveError = nil
        do {
            try CursorRulesReader.update(
                rule: rule,
                description: description.trimmingCharacters(in: .whitespaces),
                globs: globs.trimmingCharacters(in: .whitespaces),
                alwaysApply: alwaysApply,
                body: bodyText
            )
            onSaved()
            dismiss()
        } catch {
            saveError = "Save failed: \(error.localizedDescription)"
        }
    }
}
