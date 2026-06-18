# BRIEF.md — Project Hub
> Distilled decisions. The why behind every call.
> 500-line limit — when reached, create BRIEF-2.md and add pointer here.

---

## v1.0 — 2026-05-05 · Claude Code (init-project session)

### What we're building

Project Hub: native macOS menu bar app for managing AI coding tool configurations across projects. Grew out of mcpbolt's "Projects tab" concept but expanded to cover skills, agents, hooks, CLAUDE.md, cursor rules, and Live Mode (real-time context monitoring).

Separated from the mcpbolt repo on 2026-05-05. Now a standalone project at `active/projecthub/`.

### Tech stack — chosen

| Technology | Why |
|------------|-----|
| Swift + SwiftUI + AppKit | Native macOS feel; no Electron overhead; macOS 14+ features available; no external deps |
| System sqlite3 | Codex project discovery reads Codex's SQLite state file — no ORM needed |

### Tech stack — rejected

| Technology | Why rejected |
|------------|-------------|
| Electron / Tauri | Not native; heavier runtime; competitor (CCTM) already does this |
| External Swift packages | No external deps = zero maintenance overhead, faster builds |

### Architecture decisions

- **Desktop-first app with menu bar companion** — Project Hub now opens the full desktop window by default because Projects, Skills, MCP, Compatibility, and Settings outgrew the compact menu-bar panel. The menu bar item remains for quick access and secondary compact-panel use.
- **Local filesystem reads only** — no network calls anywhere. All data lives on disk.
- **Three-source project discovery** — `.claude.json` + Codex SQLite + filesystem walk → most comprehensive project detection of any tool
- **ConfigWriter as the single MCP write abstraction** — all MCP edits go through ConfigWriter regardless of tool/scope. Handles backups automatically.
- **Live Mode via lsof + JSONL scan** — detects active Claude Code project without any API, by watching most-recently-modified session files and parsing CLI processes

### Separation from mcpbolt (2026-05-05)

Project Hub and mcpbolt were in the same repo (`active/mcp/`). Separated because:
- Different product identity (project management vs MCP installation)
- Different roadmaps and development cadence
- Reduces confusion for agents and contributors

### Current feature state (verified from source, 2026-05-05)

All roadmap features through v0.5 are live in source code:
- v0.1: Projects auto-discovery, Skills (per-project), Agents, MCP read-only ✅
- v0.2: In-app skill editing, Cursor rules ✅
- v0.3: Profile copy across projects ✅
- v0.4: Hooks viewer (read-only) ✅
- v0.5: CLAUDE.md editor with templates ✅
- Live Mode: BeaconView + ContextEstimator + ProjectWatcher — in source, verify shippable

### Scope — in

- Per-project: skills, agents, MCP configs, hooks, CLAUDE.md, cursor rules
- Global views: skills library, MCP server browser across all tools
- Live Mode: floating context window monitor
- Profile copy: stamp project configs onto other projects

### Scope — out (permanent)

- Cloud sync / team features / accounts
- MCP server installation for general users (that's mcpbolt)
- Chat interface / AI assistant inside the app
- Generic launcher features

### Open questions (2026-05-05)

- Is Live Mode feature-complete and shippable?
- What version number does Project Hub launch at?
- When does Project Hub get its own landing page / website?
- Pricing model for Project Hub? (separate $29 from mcpbolt, or bundled?)

---

## v1.1 — 2026-06-18 · Codex

Project Hub should be a full desktop app by default, not a menu-bar-only utility. The existing dashboard window becomes the primary launch/reopen/menu-bar-left-click surface, while the 480×680 popover remains available as a compact menu-bar panel for quick use.

Rejected keeping the app menu-bar-first because the product now has too many operational surfaces for a constrained popover: project discovery, Skills, MCP, Compatibility, Settings, and Live Mode.
