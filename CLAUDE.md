# CLAUDE.md — Project Hub

## Coding Standards

**1. Think Before Coding** — Don't assume. Don't hide confusion. Surface tradeoffs.
**2. Simplicity First** — Minimum code that solves the problem. Nothing speculative.
**3. Surgical Changes** — Touch only what you must. Match existing style.
**4. Verify Before Closing** — Define what "done" looks like before touching code.

---

## What this is

**Project Hub** — native macOS menu bar app for managing AI coding tool configurations (skills, agents, MCP servers, hooks, CLAUDE.md, cursor rules) across every project in one place. Live Mode: floating panel showing real-time Claude Code context window usage and token counts.

This is a standalone Swift project. Related: `active/mcp/` (mcpbolt CLI), `active/mcpbolt-landing/` (marketing site).

## Tech stack

- Swift + SwiftUI + AppKit, macOS 14+
- No external dependencies (only system `sqlite3`)
- Build: `swift build`
- Run: `swift run`
- Source: `Sources/ProjectHub/`

## Guardrails — never build

- No cloud / accounts / remote sync — local-only, full stop
- No team features / SSO / enterprise tier
- No chat interface or AI inside the app
- No feature creep into generic launcher territory (not Raycast / Alfred)
- No Windows / web versions

## Reference files

- `ROADMAP.md` — Project Hub roadmap v0.1–v0.5 (note: source ahead of roadmap, see STATUS.md)

## Context files

- Read BRAND.md before any work — product identity and what NOT to build.
- Read BRIEF.md at session start — key decisions and why.
- Read docs/INDEX.md for the feature map and dependency index before touching any feature.

## Session rules

- Read STATUS.md before doing anything each session.
- Read docs/INDEX.md for feature map and dependency index.
- After every response with a change, bug, or decision — append one line to WORKLOG.md immediately.
- Run `/project-protocol:save-session` before closing every session.
