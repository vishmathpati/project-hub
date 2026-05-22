# agents/ROADMAP.md — Direction & Phases
> Owner: Vish + Cowork. Agents execute against this; do not edit unless authorized.

## Direction

Project Hub should become the local control panel for AI coding tool setup across projects: discover projects, inspect what each tool can see, install skills/agents/rules, and copy known-good setups without leaving the Mac app.

## Out of Scope

- Cloud accounts or team sync unless explicitly approved.
- Background mutation of project configs without preview or recovery.
- Replacing the user's existing AI tools; Project Hub organizes and configures them.

## Phases / Acts

### Act 1 — Current Local Control Surface

Goal: Keep the existing menu-bar app stable while it discovers projects and exposes Projects, Skills, MCP, and Settings tabs.

Output: Reliable local project list, skill list, agent list, MCP summary, and basic config inspection.

Done criteria: `swift build` passes and the status item/popover/dashboard open with expected tabs.

Status: In progress.

### Act 2 — In-App Skill Editing + Cursor Rules

Goal: Edit SKILL.md content in-app, show Cursor project rules in a dedicated surface, scaffold new skills, and filter by source.

Output: Skill editor and Cursor rules workflow with safe save behavior.

Done criteria: Users can create/edit skill and rule files without corrupting frontmatter or losing existing content.

Status: Planned.

### Act 3 — Config Profiles

Goal: Copy skill and agent bundles between projects and export profiles as local ZIPs.

Output: Named local bundles that can be stamped onto another project.

Done criteria: Copy/preview paths are clear, idempotent, and reversible where possible.

Status: Planned.

### Act 4 — Hooks Viewer

Goal: Read Claude Code and Codex hook settings and surface enabled/disabled state.

Output: Hooks tab or section with read-only inspection first, then guarded toggles.

Done criteria: Reads real hook files and writes only with preview/backup.

Status: Planned.

### Act 5 — CLAUDE.md Editor

Goal: Provide per-project and global CLAUDE.md viewing/editing with templates and diff view.

Output: Safe markdown editor for instruction files.

Done criteria: Edits preserve existing content, show diff, and support rollback.

Status: Planned.
