# Project Hub Agent Guide

Project Hub is a local macOS menu-bar app for managing AI coding tool configuration across projects.

## Required Reading

Before changing code, read:

- `cowork/STATUS.md`
- `agents/STATUS.md`
- `agents/STRUCTURE.md`
- `agents/BRIEF.md`
- `agents/BRAND.md`
- `agents/docs/INDEX.md`

Before UI work, also read:

- `agents/FUNDAMENTALS.md`
- `agents/DESIGN.md`

## Stack

- SwiftPM executable target: `ProjectHub`
- SwiftUI + AppKit
- macOS 14+
- SQLite3 linked directly for Codex state discovery
- No external package dependencies

## Guardrails

- Keep changes local-first. Do not require cloud services for core workflows.
- Treat AI tool config files as user-owned. Preview writes, create backups, and avoid destructive changes.
- Prefer official tool behavior and verified local config evidence over assumptions.
- Preserve README.md and ROADMAP.md as human-facing project docs.
- Validate with `swift build` after code changes.

## File Map

- `Sources/ProjectHub/Models.swift` shared data models.
- `Sources/ProjectHub/Core/` file readers, parsers, and writers.
- `Sources/ProjectHub/Stores/` observable app state.
- `Sources/ProjectHub/Views/` SwiftUI surfaces.
- `agents/` agent-facing canon.
- `cowork/` session orchestration notes.
- `human/` user-facing steering notes.
