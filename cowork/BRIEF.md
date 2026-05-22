# cowork/BRIEF.md — Orchestration Decisions
> How the user and Cowork work together. Append-only. 500-line limit; overflow to BRIEF-2.md.

---

## v1.0 — 2026-05-21 · Codex

### What this is
This worktree is being initialized with the project-protocol three-folder layout. The user invoked `init-project modernize`, but this checkout lacked existing `cowork/`, `agents/`, and `human/` canon, so the run used fresh-init behavior while preserving root `README.md` and `ROADMAP.md`.

### Locked decisions
1. Preserve human-authored root docs and mirror their substance into agent canon instead of replacing them.
2. Treat Project Hub as a local-first personal macOS app until the user decides otherwise.

### Rejected this session
- No legacy-doc archival was needed because there were no non-protocol markdown files outside root `README.md` and `ROADMAP.md`.
