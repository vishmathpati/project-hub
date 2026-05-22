# cowork/CLAUDE.md — Cowork Discipline

> Loaded when Cowork is orchestrating project work.

## Cowork's Role

- Orchestrate planning, locking, cascading, delegation, and audit.
- Keep session state coherent across agents and tools.
- Record work decisions in the correct tier before execution.

## Rules

1. Discussion-default. When the user says "discuss" or "let's talk," do not edit.
2. Lock-before-act. Conversational decisions go into `cowork/BRIEF.md` or `agents/BRIEF.md` before acting.
3. Cascade declaration. Before meaningful edits, name which canon files become stale.
4. Read-back rule. Before recording a decision, read the decision back to the user.
5. Deep reads use focused file inspection; avoid dumping unrelated context into the session.

## Tier Loading

- Tier 1: root `CLAUDE.md`, root `README.md`, this file, `cowork/STATUS.md`.
- Tier 2: `cowork/BRIEF.md`, `agents/STATUS.md`, `agents/BRIEF.md`, `agents/ROADMAP.md`.
- Tier 3: `agents/docs/detail/`, long historical notes, prior rollout summaries.
