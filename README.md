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
