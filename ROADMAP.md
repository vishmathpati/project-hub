# Project Hub Roadmap

## v0.1 — Current

- Projects: auto-detect from Claude Code (.claude.json), Codex CLI (state.sqlite + config.toml), filesystem
- Skills: install/remove SKILL.md skills per project from global library
- Agents: manage .claude/agents/*.md sub-agents (create, view, delete) per project
- MCP: read-only display of .mcp.json / .codex/config.toml / .cursor/mcp.json per project

## v0.2 — In-app skill editing + Cursor rules

- Edit SKILL.md content in-app with a Tiptap-style or monospaced editor
- Show Cursor project rules (.cursorrules, .cursor/rules/) in a dedicated tab
- Create new skills from scratch (scaffold the SKILL.md frontmatter + body)
- Filter skills by source (Claude / Codex / Cursor)

## v0.3 — Config profiles (copy between projects)

- Copy all skills from one project to another in one click
- Copy all agents from one project to another
- "Profile" concept: named bundles of skills + agents that can be stamped onto any project
- Export profile as a ZIP for sharing

## v0.4 — Hooks viewer

- Read Claude Code hooks from .claude/settings.json and ~/.claude/settings.json
- Read Codex hooks (pre/post command) from .codex/config.toml
- Display each hook: event name, command, enabled/disabled state
- Toggle hooks on/off without leaving the app (writes back to settings file)

## v0.5 — CLAUDE.md editor

- Per-project CLAUDE.md editor with syntax highlighting
- Templates library: starter CLAUDE.md templates for common project types (Node, Python, Swift, Next.js, etc.)
- Global CLAUDE.md viewer (~/.claude/CLAUDE.md)
- Diff view: show what changed since last commit (git diff on CLAUDE.md)
