# STATUS.md
> Last updated: 2026-06-18 · Codex

## Current State

Project Hub is a local macOS menu-bar app for scanning projects and managing AI coding tool configuration. The active checkout has the recovered Compatibility work plus the current freeze fixes and hidden-worktree discovery polish.

## Working

- Projects: discovery from Claude Code state, Codex state/config, and filesystem roots, with Git worktrees hidden from the normal project list behind a collapsed disclosure.
- Skills: global and per-project skill inventory, including Claude/Codex origins and plugin/read-only evidence, with global install counts cached off the main render path.
- MCP: global/project config display, import/copy/edit, health checks, Compatibility-backed inventory, and previewed safe writes through `ConfigWriter`.
- Compatibility: explicit single-flight scan/explain/fix/verify workflow for Claude Code, Claude Desktop, Codex CLI, and Codex Desktop, with recovered adjacent editor MCP visibility retained as read-only evidence.
- Live Mode: active dirty checkout still contains preserved Live Mode work from before the recovery merge.

## Health

- ✅ Recovered branch merged into active `main`.
- ✅ Active checkout validation passed after hidden-worktree, Skills, and Compatibility fixes: `swift build`, focused regression tests, full `swift test` (568 tests), and `git diff --check`.
- ✅ Fresh release `ProjectHub.app` is installed at `/Applications/ProjectHub.app`; `/Applications` contains only that one Project Hub app bundle.
- ✅ Expanded-window UI proof passed for hidden worktrees and Skills tab before the final reinstall; Compatibility idle/open behavior was also verified before the final rendering patch.
- ⚠️ Post-install Compatibility scan UI proof needs the expanded app window reopened; the installed patched process is idle and the CPU freeze path is fixed in code/tests.
- ⚠️ Active checkout intentionally still has preserved unstaged/untracked local work plus safety stash `stash@{0}`.
- ⚠️ Canon drift to reconcile: root docs still say local-only/no network and Claude/Codex-only, while merged Compatibility includes live remote MCP Verify behavior and read-only Cursor/VS Code/Roo project MCP visibility.
- 🔴 Broken: none known after validation.

## Recent Sessions

- 2026-06-18 · Codex — Hid discovered Git worktrees behind a Projects-tab disclosure, fixed Skills-tab and Compatibility-scan freeze paths, rebuilt the installed app, and validated `swift build`, `swift test` (568 tests), and `git diff --check`.
- 2026-06-18 · Codex — Built a fresh release `ProjectHub.app`, installed it to `/Applications`, verified codesigning, and confirmed only one Project Hub app bundle exists in `/Applications`.
- 2026-06-18 · Codex — Merged recovered Compatibility branch into active `main`, preserved dirty Live Mode/root-doc work, resolved conflicts, and validated the active checkout.
- 2026-06-18 · Codex — Finished recovered branch failures in adjacent MCP detection, read-only editor project MCP discovery, additional-directory skills, and headers helper expectations.
- 2026-05-31 · Codex — Reset active product scope to Claude Code, Claude Desktop, Codex CLI, and Codex Desktop, with legacy/editor work ignored unless it leaks into active surfaces.

## Pending Human Input

- Reopen/expand `/Applications/ProjectHub.app` on the MacBook display for one final post-install Compatibility scan click-through.
- Decide whether to update root product canon to accept live remote MCP Verify and read-only editor-adjacent visibility, or trim those behaviors in a follow-up.
- Decide when to commit or discard the preserved active dirty Live Mode/root-doc work and whether to drop `stash@{0}`.

## Next Actions

1. Run the final expanded-window Compatibility scan proof on the installed app.
2. Review the preserved unstaged/untracked active checkout changes separately from this fix.
3. Reconcile root `BRIEF.md` / `docs/INDEX.md` policy with the merged Compatibility behavior.
4. Push `main` only after deciding how to handle preserved local dirty work and canon drift.
