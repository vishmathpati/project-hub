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
