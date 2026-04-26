import SwiftUI

// MARK: - MCP sub-tab (read-only display)

struct MCPView: View {
    let project: Project

    private var claudeServers: [MCPServerInfo] { MCPReader.fromClaudeCode(project.path) }
    private var codexServers:  [MCPServerInfo] { MCPReader.fromCodex(project.path) }
    private var cursorServers: [MCPServerInfo] { MCPReader.fromCursor(project.path) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            let allEmpty = claudeServers.isEmpty && codexServers.isEmpty && cursorServers.isEmpty
            if allEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        if !claudeServers.isEmpty {
                            section(
                                source: .claudeCode,
                                servers: claudeServers
                            )
                        }
                        if !codexServers.isEmpty {
                            section(
                                source: .codex,
                                servers: codexServers
                            )
                        }
                        if !cursorServers.isEmpty {
                            section(
                                source: .cursor,
                                servers: cursorServers
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            let count = claudeServers.count + codexServers.count + cursorServers.count
            Text("\(count) MCP server\(count == 1 ? "" : "s") (read-only)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting(
                    [URL(fileURLWithPath: project.path)]
                )
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                    Text("Open in Finder")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Section per tool

    private func section(source: MCPConfigSource, servers: [MCPServerInfo]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(sourceColor(source).opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: sourceIcon(source))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(sourceColor(source))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(source.label)
                        .font(.system(size: 12, weight: .semibold))
                    Text(source.configRelativePath)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(servers.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(sourceColor(source))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(sourceColor(source).opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(10)

            Divider().opacity(0.5)

            VStack(spacing: 1) {
                ForEach(servers) { server in
                    serverRow(server, source: source)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(sourceColor(source).opacity(0.20), lineWidth: 1))
    }

    private func serverRow(_ server: MCPServerInfo, source: MCPConfigSource) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(sourceColor(source).opacity(0.6))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.system(size: 12, weight: .semibold))
                if !server.detail.isEmpty {
                    Text(server.detail)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 26))
                .foregroundColor(.secondary)
            Text("No MCP servers configured")
                .font(.system(size: 14, weight: .semibold))
            Text("Add servers via your AI tool's CLI:\n`claude mcp add --scope project …`")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    // MARK: - Helpers

    private func sourceColor(_ source: MCPConfigSource) -> Color {
        switch source {
        case .claudeCode: return .orange
        case .codex:      return .purple
        case .cursor:     return .blue
        }
    }

    private func sourceIcon(_ source: MCPConfigSource) -> String {
        switch source {
        case .claudeCode: return "terminal.fill"
        case .codex:      return "sparkles"
        case .cursor:     return "cursorarrow.rays"
        }
    }
}
