import SwiftUI
import AppKit

// MARK: - CLAUDE.md editor (v0.5)

struct ClaudeMdView: View {
    let project: Project

    @State private var content: String = ""
    @State private var savedContent: String = ""
    @State private var hasFile: Bool = false
    @State private var isDirty: Bool = false
    @State private var showTemplatePicker: Bool = false
    @State private var saveError: String? = nil

    private var wordCount: Int {
        content.split { $0.isWhitespace }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            if !hasFile {
                createPrompt
            } else {
                editorArea
            }
            Divider()
            bottomBar
        }
        .onAppear { loadFile() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            // File path label
            HStack(spacing: 5) {
                Image(systemName: hasFile ? "doc.text.fill" : "doc.badge.plus")
                    .font(.system(size: 11))
                    .foregroundColor(hasFile ? .primary : .secondary)
                Text(hasFile ? "CLAUDE.md" : "No CLAUDE.md")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(hasFile ? .primary : .secondary)
            }

            Spacer()

            // Templates button
            Button(action: { showTemplatePicker = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.badge.gearshape")
                        .font(.system(size: 11))
                    Text("Templates")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showTemplatePicker) {
                templatePickerPopover
            }

            // Save button
            Button(action: saveFile) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Save")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(isDirty ? .white : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isDirty ? AnyShapeStyle(ContentView.headerGrad) : AnyShapeStyle(Color(NSColor.controlBackgroundColor)))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: isDirty ? 0 : 0.5)
                )
            }
            .buttonStyle(.plain)
            .disabled(!isDirty)
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    // MARK: - Create prompt (no CLAUDE.md yet)

    private var createPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No CLAUDE.md found")
                .font(.system(size: 14, weight: .semibold))
            Text("CLAUDE.md gives Claude Code project-specific instructions.\nChoose a template to get started.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                ForEach(ClaudeMdReader.templates, id: \.name) { template in
                    Button(action: { applyTemplate(template) }) {
                        VStack(spacing: 5) {
                            Image(systemName: templateIcon(template.name))
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                            Text(template.name)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .frame(width: 72, height: 64)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - Editor

    private var editorArea: some View {
        TextEditor(text: $content)
            .font(.system(size: 12, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(Color(NSColor.textBackgroundColor))
            .onChange(of: content) { newValue in
                isDirty = newValue != savedContent
            }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Text("\(wordCount) word\(wordCount == 1 ? "" : "s")")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            if let err = saveError {
                Text(err)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .lineLimit(1)
            }

            Spacer()

            if isDirty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 5, height: 5)
                    Text("Unsaved changes")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.10))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    // MARK: - Template picker popover

    private var templatePickerPopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Choose a template")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            Divider()

            ForEach(ClaudeMdReader.templates, id: \.name) { template in
                Button(action: { applyTemplate(template); showTemplatePicker = false }) {
                    HStack(spacing: 8) {
                        Image(systemName: templateIcon(template.name))
                            .font(.system(size: 13))
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text(template.name)
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Divider()
                .padding(.bottom, 4)
        }
        .frame(width: 200)
    }

    // MARK: - Helpers

    private func loadFile() {
        hasFile = ClaudeMdReader.exists(at: project.path)
        let text = ClaudeMdReader.read(from: project.path) ?? ""
        content = text
        savedContent = text
        isDirty = false
        saveError = nil
    }

    private func saveFile() {
        do {
            try ClaudeMdReader.write(content, to: project.path)
            savedContent = content
            hasFile = true
            isDirty = false
            saveError = nil
        } catch {
            saveError = "Save failed: \(error.localizedDescription)"
        }
    }

    private func applyTemplate(_ template: (name: String, content: String)) {
        content = template.content
        isDirty = true
        hasFile = true      // we'll create the file on first save
    }

    private func templateIcon(_ name: String) -> String {
        switch name {
        case "Blank":   return "doc"
        case "Minimal": return "doc.text"
        case "Full":    return "doc.richtext"
        default:        return "doc"
        }
    }
}
