# Project Hub Roadmap

Shipped history (v0.1–v0.5) is at the bottom. The list below is the current build. This is the only progress list.

## Current build

### 1. Fast scan
- [x] Stop walking the whole project to find skills
- [x] Save the last Compat / Plugins scan
- [x] Let a worktree be added as its own project
- [x] Split the remaining scanner so each page reads only its own files

### 2. Instruction files
- [x] Edit `AGENTS.md` in the project
- [x] Edit `CLAUDE.md`, `.claude/CLAUDE.md`, and `CLAUDE.local.md`
- [x] Edit `GEMINI.md` if it exists

### 3. Features already in the code, not on screen
- [x] Put Cursor Rules back on the project page
- [x] Scan Cursor skills
- [x] Show Cursor, VS Code, OpenCode, and Zed on the main MCP page

### 4. New primary providers
- [x] Antigravity (Google)
- [x] Pi — skills, extensions, MCP only if the MCP extension is installed
- [x] Command Code
- [x] Grok CLI
- [x] Providers page with per-provider controls

### 5. Copy
- [x] Copy one skill to another project
- [x] Copy one skill Claude ↔ Codex

### 6. Usage
- [x] Local token usage from files already on disk (Claude, Codex, Pi, Command Code)

### 7. Secondary providers
Only if the same reader already covers them. No extra work.

---

## Already shipped

### v0.1
- Projects: auto-detect from Claude Code, Codex CLI, filesystem
- Skills: install/remove SKILL.md per project
- Agents: Claude `.claude/agents/*.md`
- MCP: read-only project files

### v0.2
- In-app skill editing
- Cursor rules reader
- Create skills
- Filter skills by source

### v0.3
- Copy profile (skills / agents / MCP) across projects

### v0.4
- Hooks viewer (read-only)

### v0.5
- CLAUDE.md editor with templates
