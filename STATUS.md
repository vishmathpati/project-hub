# Status — Project Hub
> Last updated: 2026-06-19 · Codex

## Current State

Project Hub is desktop-first: launch, Dock reopen, and menu-bar left click open a redesigned full dashboard window with sidebar navigation, toolbar summaries, a split Projects workspace, and desktop project-detail navigation. The menu bar item remains for quick actions and compact-panel access.

## Health

- ✅ Working: desktop app shell, menu bar companion, redesigned Projects workspace, Skills, MCP, Compatibility, Agents, Hooks, CLAUDE.md editor, Cursor Rules, Profile copy
- ✅ Verified: installed `/Applications/ProjectHub.app` shows the redesigned desktop layout; `swift build`, `swift test` (583 tests), `git diff --check`, release build, code signing, and `/Applications` bundle check passed
- ⚠️ Unknown: Live Mode (BeaconView, ContextEstimator, ProjectWatcher) — in source, needs verification
- 🔴 Broken: (none known)
- 🔒 Blocked: (none)

## Needs CEO Input

- Is Live Mode shippable or still in-progress?
- What version number is Project Hub at? (not yet versioned)
- What comes after Live Mode in the roadmap?
- When does Project Hub get its own landing page?

## Recent Sessions (rolling — keep last 5)

- 2026-06-19 · Codex: redesigned the full desktop UI so it no longer looks like a stretched menu-bar panel; installed and verified `/Applications/ProjectHub.app`.
- 2026-06-18 · Codex: promoted Project Hub from menu-bar-first to desktop-first app shell with compact menu-bar panel retained.
- 2026-05-05 · Claude Code: init-project — project separated from mcpbolt repo, full protocol suite created

## Next Actions

1. Put the detached-worktree UI redesign onto an explicit branch or apply it to the main checkout before git sync
2. Run app, test Live Mode panel (BeaconView + context tracking)
3. Update ROADMAP.md — all v0.1–v0.5 features are already shipped, add Live Mode + post-launch direction
4. Decide the Project Hub version number and landing page timing
