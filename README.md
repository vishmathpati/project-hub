# Project Hub

Personal Mac menu-bar app to manage AI coding tools across all your projects.

## Features

- Auto-detect projects from Claude Code, Codex CLI, and filesystem
- Install/remove skills (SKILL.md) per project for Claude Code, Codex CLI
- Manage Claude sub-agents (.claude/agents/*.md) per project
- View MCP servers configured per project (Claude Code, Codex, Cursor)

## Build

```bash
swift build
swift run
```

## Tech

- SwiftUI + AppKit, macOS 14+
- No external dependencies

---

# README.md — File Map & Dependencies

> Open this whenever you're about to change a non-trivial file. Find that file below. Its "When this changes" line tells you which other files may need updating.

## File Catalog

### Root

- **CLAUDE.md** — always-loaded agent rules and folder map.
- **README.md** — project overview plus dependency map. When this changes: check `CLAUDE.md`, `agents/BRIEF.md`, and `agents/docs/INDEX.md`.
- **ROADMAP.md** — human-authored product roadmap. When this changes: mirror relevant direction into `agents/ROADMAP.md` and update `agents/STATUS.md`.
- **Package.swift** — SwiftPM package definition. When this changes: run `swift build` and update `agents/BRIEF.md` / `agents/docs/INDEX.md` if dependencies or platforms change.
- **build-app.sh** / **package.sh** — local build and packaging helpers. When these change: verify build output and update `agents/docs/INDEX.md` if the release path changes.

### `Sources/ProjectHub/`

- **App.swift** — app entry point, status item, popover, dashboard window wiring, and app lifecycle. When this changes: verify launch, status item, popover, and window expansion.
- **Models.swift** — shared data models for projects, skills, agents, MCP, and tool metadata. When this changes: check all stores and views using those model fields.
- **Stores/** — observable state and persistence for projects, skills, agents, and MCP. When this changes: verify the related tab and any writer or scanner behavior.
- **Core/** — readers, parsers, import logic, and config writers. When this changes: update dependency notes and verify the file formats touched.
- **Views/** — SwiftUI surfaces for tabs, detail views, sheets, and editors. When this changes: read `agents/DESIGN.md`, then verify the relevant tab in the app.
- **LiveMode/** — floating beacon/window and active-project watcher. When this changes: verify Live Mode launch, close, drag, and front-app tracking.

### `cowork/`

- **CLAUDE.md** — Cowork-specific discipline.
- **STATUS.md** — current orchestration state. No cascade.
- **BRIEF.md** — orchestration decisions. When this changes: `cowork/CLAUDE.md` may need updating.
- **WORKLOG.md** — live session log. Cleared by save-session.
- **CHANGELOG.md** — orchestration history. Never cleared.

### `agents/`

- **STATUS.md** — project state and next actions.
- **BRIEF.md** — product and architecture decisions. When this changes: update `agents/ROADMAP.md`, `agents/STATUS.md`, and `human/agenda.md` if direction changed.
- **ROADMAP.md** — agent-facing direction and phases. When this changes: update `agents/STATUS.md` and `human/agenda.md`.
- **BRAND.md** — product identity and audience. When this changes: check `agents/DESIGN.md`.
- **FUNDAMENTALS.md** — global design framework copied from the protocol plugin.
- **DESIGN.md** — project design tokens and UI rules. When this changes: pause UI work until tokens validate.
- **STRUCTURE.md** — source map and code organization. When this changes: update `agents/docs/INDEX.md` if dependencies moved.
- **DISCOVERIES.md** — append-only UI and implementation learnings.
- **WORKLOG.md** / **CHANGELOG.md** — project worklog and history.
- **docs/INDEX.md** — dependency map. Read before touching shared stores, config readers/writers, views, or Live Mode.
- **docs/detail/** — deep reference files when a feature exceeds the dependency map.

### `human/`

- **agenda.md** — daily steering file. Re-derive when `agents/ROADMAP.md` or `agents/BRIEF.md` changes.

## Cascade Summary

```text
agents/BRIEF.md -> agents/ROADMAP.md -> agents/STATUS.md -> human/agenda.md
```

If you change an upstream decision, check everything downstream before closing.
