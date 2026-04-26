import SwiftUI
import AppKit

// MARK: - Hooks viewer (v0.4)

struct HooksView: View {
    let project: Project

    @State private var hooks: [HookEntry] = []

    // Group by tool name in a stable order
    private let toolOrder = ["Claude Code", "Codex", "Cursor"]

    private var groupedHooks: [(tool: String, entries: [HookEntry])] {
        toolOrder.compactMap { tool in
            let items = hooks.filter { $0.tool == tool }
            return items.isEmpty ? nil : (tool: tool, entries: items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if hooks.isEmpty {
                emptyState
            } else {
                hooksList
            }
            Divider()
            footer
        }
        .onAppear { hooks = HooksReader.hooks(for: project.path) }
    }

    // MARK: - Hooks list

    private var hooksList: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(groupedHooks, id: \.tool) { group in
                    toolSection(group.tool, entries: group.entries)
                }
            }
            .padding(12)
        }
    }

    private func toolSection(_ tool: String, entries: [HookEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: toolIcon(tool))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(toolTint(tool))
                Text(tool)
                    .font(.system(size: 12, weight: .bold))
                countBadge(entries.count, color: toolTint(tool))
                Spacer()
            }
            .padding(.horizontal, 2)

            // Rows
            ForEach(entries) { entry in
                hookRow(entry)
            }
        }
    }

    private func hookRow(_ entry: HookEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Event badge
            Text(entry.event)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(eventColor(entry.event))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(eventColor(entry.event).opacity(0.12))
                .clipShape(Capsule())
                .fixedSize()

            // Command (monospaced, truncated)
            VStack(alignment: .leading, spacing: 3) {
                if let matcher = entry.matcher, !matcher.isEmpty {
                    Text("matcher: \(matcher)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Text(entry.command)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                // Scope pill
                scopePill(entry.scope)

                // Copy button
                Button(action: { copyToClipboard(entry.command) }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Copy command")
            }
        }
        .padding(9)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No hooks configured")
                .font(.system(size: 14, weight: .semibold))
            Text("No hooks found for this project\nor in global tool configs.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text("Hooks are read-only here. Edit settings.json to change them.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sub-components

    private func countBadge(_ count: Int, color: Color) -> some View {
        Text("\(count)")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func scopePill(_ scope: String) -> some View {
        let isProject = scope == "project"
        return Text(scope)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(isProject ? .blue : .secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(isProject ? Color.blue.opacity(0.10) : Color.secondary.opacity(0.10))
            .clipShape(Capsule())
    }

    // MARK: - Color / icon helpers

    private func eventColor(_ event: String) -> Color {
        let e = event.lowercased()
        if e == "pretooluse" || e == "beforeshellexecution" || e == "beforemcpexecution" {
            return .orange
        }
        if e == "posttooluse" { return .green }
        if e == "stop" { return .red }
        if e == "userpromptsubmit" || e == "beforesubmitprompt" { return .blue }
        if e == "sessionstart" { return .purple }
        return .secondary
    }

    private func toolIcon(_ tool: String) -> String {
        switch tool {
        case "Claude Code": return "c.circle.fill"
        case "Codex":       return "chevron.left.forwardslash.chevron.right"
        case "Cursor":      return "cursorarrow"
        default:            return "wrench.fill"
        }
    }

    private func toolTint(_ tool: String) -> Color {
        switch tool {
        case "Claude Code": return .orange
        case "Codex":       return .blue
        case "Cursor":      return .purple
        default:            return .secondary
        }
    }

    // MARK: - Clipboard

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
