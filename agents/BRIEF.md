# BRIEF.md

## Product Intent

Project Hub helps one person manage AI coding tool setup across many local projects without manually remembering each tool's config files.

## Major Decisions

- Use a local macOS app, not a cloud dashboard.
- Prefer direct file inspection and safe writes over opaque installer flows.
- Explain compatibility by app and scope because Claude Code, Claude Desktop, Codex CLI, and Codex Desktop do not share one configuration model.
- Treat MCP servers, skills, project settings, and health as one workflow instead of separate chores.

## Rejected Options

- Do not rely only on interactive installer commands. Some are useful, but Project Hub should not automate prompt-driven setup unless the user drives it.
- Do not flatten all tools into a single fake config model. Preserve tool-specific scope and reload behavior.

---

## v1.1 — 2026-05-22 13:01 · Codex

Added the compatibility workflow as a first-class product direction: scan, explain, fix, verify. The implementation should keep Claude Desktop Chat separate from Claude Desktop Code/Claude Code, and Codex user-authored skills should use `~/.agents/skills` while `~/.codex/skills` is treated as managed/legacy local evidence.

Rejected silent installer automation for `.mcpb`, remote connectors, and prompt-driven MCP setup commands until a user-driven flow is designed.

---

## v1.2 — 2026-06-18 17:20 · Codex

Recovered Compatibility work was accepted as a preservation merge into active `main` after the deleted-worktree audit. The merge priority was code health and recoverability: fix broken/incomplete implementation, preserve the active dirty checkout, and keep feature drift visible rather than discarding validated work.

Known drift remains to reconcile in canon: the recovered branch includes live MCP Verify/network behavior and read-only editor-adjacent project MCP visibility while the root product docs still describe a stricter local-only, Claude/Codex-only policy. Rejected dropping those paths during recovery because the user explicitly approved merging feature drift as long as the code is not broken.

---

## v1.3 — 2026-06-18 20:46 · Codex

Project discovery now treats Git worktrees as related metadata rather than normal projects: worktrees remain inspectable from a collapsed Projects-tab disclosure, but they do not pollute the primary project or discovered-project lists.

Skills and Compatibility views should not run broad filesystem scans from SwiftUI rendering or tab-change events. Global skill install counts are cached through a background store refresh, and Compatibility scans are explicit, single-flight user actions.

---

## v1.4 — 2026-06-18 21:38 · Codex

Project discovery now requires an existing coding-project root with direct evidence before surfacing a folder from Claude/Codex history or filesystem roots. Tool homes, broad workspace folders, transient Codex session folders, top-level generic storage folders, protected Desktop/Documents/Downloads paths, and case-variant duplicates are rejected or sanitized out of saved state.

Background refresh paths must not trigger macOS protected-storage prompts. Skills global install counts skip protected storage and stale false-positive projects; explicit user-added protected projects can still be inspected through direct project actions.

---

## v1.5 — 2026-06-18 22:15 · Codex

Compatibility now treats plugins as first-class local evidence rather than only incidental MCP or skill rows. Codex plugin detection covers installed cache manifests, enabled/disabled plugin config, configured marketplace sources, and personal/project marketplace files. Claude Code plugin detection covers installed plugin inventory, enabledPlugins settings, extraKnownMarketplaces, skills-dir plugins, and marketplace-directory manifests.

Rejected installer automation for this slice. Project Hub reports plugin state and missing enabled plugins, but plugin-owned files and marketplace installs remain read-only and must be changed through Codex or Claude Code's own plugin flows.
