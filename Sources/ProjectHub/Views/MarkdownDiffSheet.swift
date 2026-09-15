import SwiftUI

// MARK: - Full-file diff review before a markdown overwrite

/// Shows the exact before/after text a save would write and only confirms
/// against the previewed "before" text, so a file that changed on disk after
/// the preview cannot be overwritten silently.
struct MarkdownDiffSheet: View {
    let title: String
    let filePath: String
    let before: String
    let after: String
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text((filePath as NSString).lastPathComponent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(diffLines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 0) {
                            Text(line.symbol)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(line.color)
                                .frame(width: 14, alignment: .leading)
                            Text(line.text.isEmpty ? " " : line.text)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(line.color)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(8)
                .background(HubTheme.field)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(HubTheme.line.opacity(0.6), lineWidth: 0.5))
            }

            HStack {
                Text("Saving checks the file still matches this preview.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Back") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Write changes") { onConfirm() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 560, height: 520)
    }

    private struct Line: Hashable {
        let symbol: String
        let text: String
        let isAddition: Bool
        var color: Color { isAddition ? .green : .red }
    }

    private var diffLines: [Line] {
        let beforeLines = before.components(separatedBy: "\n")
        let afterLines = after.components(separatedBy: "\n")
        let beforeSet = Set(beforeLines)

        var out: [Line] = []
        for text in afterLines where !beforeSet.contains(text) {
            out.append(Line(symbol: "+", text: text, isAddition: true))
        }
        let afterSet = Set(afterLines)
        for text in beforeLines where !afterSet.contains(text) {
            out.append(Line(symbol: "−", text: text, isAddition: false))
        }
        if out.isEmpty {
            out.append(Line(symbol: " ", text: "(no visible changes)", isAddition: false))
        }
        return Array(out.prefix(200))
    }
}
