# CLAUDE.md — Project Hub

> Always loaded by every agent. Rules, folder map, and project boundaries.

## What This Is

Project Hub is a personal macOS menu-bar app for managing AI coding tools across local projects. It discovers projects from Claude Code, Codex CLI, and the filesystem; manages skills and agents per project; and reads or writes supported MCP server configuration for AI tools.

## Coding Standards

1. Think before coding. State assumptions, surface tradeoffs, and ask when unclear.
2. Keep changes surgical. Touch only the files needed for the task and match existing SwiftUI/AppKit style.
3. Preserve local-first behavior. Do not introduce remote services, accounts, telemetry, or cloud dependencies without an explicit decision in `agents/BRIEF.md`.
4. Verify before closing. For code changes, run `swift build`; for UI behavior, exercise the relevant macOS surface when practical.

## Who Reads What

- Human reads `human/agenda.md` to know what to do next.
- Cowork reads `cowork/CLAUDE.md`, then the rest of `cowork/` and `agents/` as needed.
- Codex / Claude Code read the agent canon files in `agents/`.

## Non-Negotiable Rules

1. Read `README.md` before non-trivial edits and check the cascade notes.
2. Lock product or architecture decisions in `agents/BRIEF.md` before spreading them across code.
3. Keep root files lean; put deep references in `agents/docs/`.
4. Do not silently overwrite protocol canon. Preserve existing user-authored content unless the user asks for a rewrite.
5. For SwiftUI UI changes, read `agents/DESIGN.md` and `agents/FUNDAMENTALS.md` first.
6. Commit and push only when the user asks for publication or closeout.

## Folder Map

- `cowork/` — orchestration tier. Session discipline, status, worklog, and changelog.
- `agents/` — project canon. Product decisions, design system, roadmap, status, and dependency map.
- `human/` — user-facing steering. Daily agenda and next work.
- `Sources/ProjectHub/` — SwiftPM executable source for the macOS app.

## Pre-Task Classification

Before code changes, classify the work:

1. NEW standalone feature
2. ADDITION to existing feature
3. UI CHANGE
4. BUG FIX

Then check `agents/docs/INDEX.md` for related dependencies before editing.

## Extended Context

- `agents/docs/INDEX.md` — feature and dependency map. Read before changing project discovery, skills, agents, MCP config, Live Mode, or SwiftUI shell behavior.
- `agents/STRUCTURE.md` — codebase surface and convention map. Read before adding or moving views, stores, or shared helpers.
