# STATUS.md
> Last updated: 2026-06-18 · Codex

## Current State

Project Hub is a local macOS menu-bar app for scanning projects and managing AI coding tool configuration.

The recovered Compatibility worktree has been merged into active `main`. The active checkout is ahead of `origin/main` by the recovered snapshot, the recovered finish commit, and the merge commit.

## Working

- Projects: discovery from Claude Code state, Codex state/config, and filesystem roots.
- Skills: global and per-project skill inventory, including Claude/Codex origins and plugin/read-only evidence.
- MCP: global/project config display, import/copy/edit, health checks, Compatibility-backed inventory, and previewed safe writes through `ConfigWriter`.
- Compatibility: scan/explain/fix/verify workflow for Claude Code, Claude Desktop, Codex CLI, and Codex Desktop, with recovered adjacent editor MCP visibility retained as read-only evidence.
- Live Mode: active dirty checkout still contains preserved Live Mode work from before the recovery merge.

## Health

- ✅ Recovered branch merged into active `main`.
- ✅ Recovered checkout validation passed: `swift build`, full `swift test` (564 tests), and `git diff --check`.
- ✅ Active checkout validation passed after merge/conflict resolution: `swift build`, focused seam tests, full `swift test` (564 tests), and `git diff --check`.
- ✅ Fresh release `ProjectHub.app` is installed at `/Applications/ProjectHub.app`; `/Applications` contains only that one Project Hub app bundle.
- ⚠️ Active checkout intentionally still has preserved unstaged/untracked local work plus safety stash `stash@{0}`.
- ⚠️ Canon drift to reconcile: root docs still say local-only/no network and Claude/Codex-only, while merged Compatibility includes live remote MCP Verify behavior and read-only Cursor/VS Code/Roo project MCP visibility.
- 🔴 Broken: none known after validation.

## Recent Sessions

- 2026-06-18 · Codex — Built a fresh release `ProjectHub.app`, installed it to `/Applications`, verified codesigning, and confirmed only one Project Hub app bundle exists in `/Applications`.
- 2026-06-18 · Codex — Merged recovered Compatibility branch into active `main`, preserved dirty Live Mode/root-doc work, resolved conflicts, and validated the active checkout.
- 2026-06-18 · Codex — Finished recovered branch failures in adjacent MCP detection, read-only editor project MCP discovery, additional-directory skills, and headers helper expectations.
- 2026-05-31 · Codex — Reset active product scope to Claude Code, Claude Desktop, Codex CLI, and Codex Desktop, with legacy/editor work ignored unless it leaks into active surfaces.
- 2026-05-31 · Codex — Hardened Compatibility-backed MCP inventory, profile-file Codex behavior, MCP import/copy stale guards, and Claude/Codex-only UI scope.

## Pending Human Input

- Decide whether to update root product canon to accept live remote MCP Verify and read-only editor-adjacent visibility, or trim those behaviors in a follow-up.
- Decide when to commit or discard the preserved active dirty Live Mode/root-doc work and whether to drop `stash@{0}`.

## Next Actions

1. Review the preserved unstaged/untracked active checkout changes separately from the recovered merge.
2. Reconcile root `BRIEF.md` / `docs/INDEX.md` policy with the merged Compatibility behavior.
3. Test `/Applications/ProjectHub.app` manually for Compatibility and Live Mode panel behavior.
4. Push `main` only after deciding how to handle the preserved local dirty work and canon drift.
