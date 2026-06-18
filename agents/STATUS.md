# STATUS.md
> Last updated: 2026-06-19 · Codex

## Current State

Project Hub is a local macOS desktop app with a menu bar companion for scanning projects and managing AI coding tool configuration. The installed app now has a desktop-native visual shell with sidebar navigation, toolbar summaries, a split Projects workspace, and desktop project-detail navigation.

## Working

- Projects: discovery from Claude Code state, Codex state/config, and filesystem roots, with Git worktrees hidden from the normal project list behind a collapsed disclosure; tool homes, transcript folders, broad workspace roots, protected storage, and stale saved false positives are filtered.
- App shell: launch, Dock reopen, and menu-bar left click open the full dashboard window; the desktop window uses sidebar/toolbar layout, while the menu bar still offers quick actions and explicit compact-panel access.
- Skills: global and per-project skill inventory, including Claude/Codex origins and plugin/read-only evidence, with global install counts cached off the main render path and protected storage skipped during background aggregate refresh.
- MCP: global/project config display, import/copy/edit, health checks, Compatibility-backed inventory, and previewed safe writes through `ConfigWriter`.
- Compatibility: explicit single-flight scan/explain/fix/verify workflow for Claude Code, Claude Desktop, Codex CLI, and Codex Desktop, with first-class Codex/Claude plugin inventory and recovered adjacent editor MCP visibility retained as read-only evidence.
- Live Mode: active dirty checkout still contains preserved Live Mode work from before the recovery merge.

## Health

- ✅ Recovered branch merged into active `main`.
- ✅ Desktop visual redesign validation passed: local + installed app screenshots, release build/codesign, `/Applications` install, `swift build`, full `swift test` (583 tests), and `git diff --check`.
- ✅ Desktop-first app shell validation passed: `swift build`, full `swift test` (583 tests), `git diff --check`, release app build/codesign, `/Applications` install, and launch smoke test.
- ✅ Active checkout validation passed after discovery/privacy, hidden-worktree, Skills, Compatibility, and plugin detection fixes: `swift build`, focused regression tests, full `swift test` baseline (581 tests), focused `CompatibilityPluginMCPTests`, and `git diff --check`.
- ✅ Fresh release `ProjectHub.app` is installed at `/Applications/ProjectHub.app`; `/Applications` contains only that one Project Hub app bundle.
- ✅ Saved Project Hub state migrated away the stale `~/Desktop/Code` row; only the real saved `mcp converter` row remains.
- ✅ Post-install Project Hub relaunch did not re-show the Project Hub Desktop permission prompt after dismissal; a separate Codex privacy prompt is currently blocking further visual click-through.
- ⚠️ Git sync not completed in this detached worktree; commit/merge needs an explicit branch or main-checkout handoff.
- ⚠️ Active checkout intentionally still has preserved unstaged/untracked local work plus safety stash `stash@{0}`.
- ⚠️ Canon drift to reconcile: root docs still say local-only/no network and Claude/Codex-only, while merged Compatibility includes live remote MCP Verify behavior and read-only Cursor/VS Code/Roo project MCP visibility.
- 🔴 Broken: none known after validation.

## Recent Sessions

- 2026-06-19 · Codex — Redesigned the desktop UI into a sidebar/toolbar app shell with split Projects workspace, installed `/Applications/ProjectHub.app`, captured visual proof, and validated `swift test` (583 tests).
- 2026-06-18 · Codex — Promoted Project Hub to a desktop-first app shell while keeping the menu bar companion and compact panel.
- 2026-06-18 · Codex — Added first-class Codex/Claude Code plugin detection to Compatibility, surfaced plugin rows in the UI/report, rebuilt `/Applications/ProjectHub.app`, and verified build/focused tests.
- 2026-06-18 · Codex — Tightened discovery to reject tool/session/workspace/protected-storage false positives, cleaned stale saved project rows, prevented Skills background storage prompts, rebuilt `/Applications/ProjectHub.app`, and validated full `swift test` (581 tests).
- 2026-06-18 · Codex — Hid discovered Git worktrees behind a Projects-tab disclosure, fixed Skills-tab and Compatibility-scan freeze paths, rebuilt the installed app, and validated `swift build`, `swift test` (568 tests), and `git diff --check`.

## Pending Human Input

- Decide whether to update root product canon to accept live remote MCP Verify and read-only editor-adjacent visibility, or trim those behaviors in a follow-up.
- Decide when to commit/merge this detached-worktree UI redesign and how to handle preserved active dirty Live Mode/root-doc work plus `stash@{0}`.

## Next Actions

1. Put this detached-worktree UI redesign onto an explicit branch or apply it to the main checkout before git sync.
2. Review the preserved unstaged/untracked active checkout changes separately from this fix.
3. Reconcile root `BRIEF.md` / `docs/INDEX.md` policy with the merged Compatibility behavior.
4. Push `main` only after deciding how to handle preserved local dirty work and canon drift.
