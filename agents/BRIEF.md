# agents/BRIEF.md — Project Decisions
> What we're building and why. Append-only. New version block per change.

---

## v1.0 — 2026-05-21 · Codex

### What We're Building
Project Hub is a personal macOS menu-bar app that gives the user one local control surface for AI coding projects: discovered project folders, project-scoped skills, Claude sub-agents, Cursor rules, MCP server configuration, and Live Mode context.

### Tech Stack — Chosen

| Technology | Why |
|------------|-----|
| SwiftPM executable | Simple local build with no Xcode project required. |
| SwiftUI | Native macOS UI for popover, dashboard, tabs, and sheets. |
| AppKit interop | Needed for status item, popover, windows, menus, panels, and Dock/status behavior. |
| SQLite3 | Reads Codex local state without adding package dependencies. |
| UserDefaults and filesystem reads | Keeps the app local-first and dependency-light. |

### Tech Stack — Rejected

| Technology | Why rejected |
|------------|--------------|
| External backend | Out of scope for a personal local configuration tool. |
| Web app shell | Would weaken native menu-bar and local filesystem integration. |
| Package dependencies | Current app intentionally avoids third-party dependencies. |

### Architecture Decisions

1. Keep all discovery and configuration inspection local to the user's machine.
2. Support project-scoped skills for both Claude (`.claude/skills`) and Codex (`.agents/skills`).
3. Treat TOML/YAML support carefully; unsupported writes should be explicit rather than silently lossy.
4. Use AppKit where SwiftUI does not cover menu-bar, popover, floating window, and launch behaviors cleanly.

### Scope — In / Out

**In:** Local project discovery, skill install/remove, agent viewing/creation, Cursor rules viewing/editing, MCP config read/write where supported, profile copying, Live Mode context.

**Out:** Cloud sync, team accounts, remote execution, marketplace publishing, silent automation across unrelated projects.

### Open Questions

1. [VERIFY] Should profile export/import stay local ZIP-only, or eventually support a shared catalog?
2. [VERIFY] Should Codex TOML editing be fully first-class everywhere, or stay guarded behind preview/backup behavior?
3. [VERIFY] Should Live Mode remain Claude-frontmost focused, or generalize to Codex/other AI tools?
