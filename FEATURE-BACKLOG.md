# FEATURE-BACKLOG.md — Project Hub

> Single source of truth for the competitor-parity programme.
> Derived from a study of the tools below. When one feature exists in several
> apps, the **Source** column names the app whose implementation we copy, and
> **Best-of** says why that one won.

## Apps studied

| App | What it is | Why it matters here |
|---|---|---|
| **CCTM** (`tylergraydev/claude-code-tool-manager`, 383★, Tauri) | Desktop manager for MCP, Commands, Skills, Sub-Agents, Hooks across 6 editors | Closest direct competitor. Broadest config surface. |
| **t3code** (`pingdotgg/t3code`, 22.6k★) | Agent harness control surface, 6 providers | Its skill manager and `usage-scan-cache` design are the reference. |
| **opcode** (~21k★, Tauri) | Session manager, custom agents, background runs, usage | Largest community; session UX reference. |
| **Claudia** | GUI toolkit: agents, sessions, usage analytics, MCP | Agent + session patterns. |
| **zeroone-manager** | MCP testing, AI-controllable via own MCP server | MCP verification UX. |
| **ccusage** (`ryoppippi/ccusage`) | Usage CLI, 18 sources | Canonical report shapes and block maths. |
| **CodeBurn** (`getagentseal/codeburn`) | 41 tools, local-first CLI/TUI/menubar | Waste scan, guard, doctor, yield. |
| **TokenBar** | Native Swift menubar, 25+ agents | Menubar quota presentation, charts. |
| **ClaudeBar** | Open Swift menubar | Thresholds, notifications, themes. |
| **ClaudeMeter** | Claude-only menubar | Pacing indicator, icon styles. |

Legend — **Pri**: P0 blocking value · P1 high · P2 useful · P3 polish.
**Status**: todo · doing · done · wontfix.

---

## A. Configuration surface

| # | Feature | Source | Best-of | Pri | Status |
|---|---|---|---|---|---|
| **A1** | **Commands**: read/write `.claude/commands/**/*.md`, recursive namespacing (`group:name`), frontmatter (`description`, `argument-hint`, `allowed-tools`, `model`) | CCTM | Only app that manages them | P0 | done |
| **A2** | **Profiles**: save/restore *named* config sets (skills+agents+MCP+hooks+commands), one-click switch | CCTM | CCTM's snapshot model beats our ad-hoc "Copy setup to…" | P0 | done |
| **A3** | **Browse / Search / Install**: one search over every skill on the machine, install into any project | t3code | t3code's cross-provider search + install flow, adapted local-only | P0 | done |
| **A4** | **Multi-editor sync**: write one MCP/skill definition to all enabled editors at once | CCTM | CCTM covers 6 editors; we already read all of them | P1 | done |
| A5 | **MCP Testing**: connect to a server and execute its tools in-app to prove config | CCTM, zeroone | CCTM's inline test panel | P1 | todo |
| **A6** | **Status Line Builder**: visual builder, 25+ segment types, themes, gallery | CCTM | Only app with a builder | P2 | done |
| **A7** | **Spinner Verbs**: edit/reorder Claude Code's working verbs, append or replace | CCTM | Only app that does it | P2 | done |
| **A8** | **settings.json deep editor**: permissions, spinner, statusline, env | CCTM | We read 36 KB but touch a fraction | P1 | done |
| A9 | **AI-controllable**: ship our own MCP server so an agent can manage configs | CCTM, zeroone | zeroone's tool surface is smaller and cleaner | P3 | todo |
| A10 | **Insights Viewer**: session quality + friction trends | CCTM | Needs `~/.claude/usage-data/`; detect and degrade | P3 | todo |
| **A11** | **Session Explorer**: browse sessions per project, transcript timeline, per-message tokens, tool-frequency chart | CCTM, opcode | opcode's session drilling is deeper | P1 | done |

## B. Usage and analytics

| # | Feature | Source | Best-of | Pri | Status |
|---|---|---|---|---|---|
| **B1** | Daily / weekly / monthly tables — In · Out · Cache-W · Cache-R · Total · $ as separate columns | ccusage | ccusage defines the columns | P0 | done |
| **B2** | Per-session table sorted by cost + last activity; lookup by session id | ccusage | ccusage | P1 | done |
| **B3** | **Per-model breakdown** with share | ccusage, TokenBar | ccusage's `--breakdown` sub-rows | P0 | done |
| **B4** | **Per-project breakdown** (Claude `cwd`) | ccusage `--instances` | ccusage's alias system | P0 | done |
| B5 | Cost modes: recorded `costUSD` vs computed vs both | ccusage | ccusage `--mode` | P1 | todo |
| **B6** | **Burn rate** (tok/min, $/hr) + projected block total | ccusage, CodeBurn | ccusage's block projection | P1 | done |
| **B7** | Token-limit gauge with green/yellow/red + ⚠️/🚨 | ccusage, ClaudeBar | ccusage's `--token-limit max` | P2 | done |
| B8 | Contribution heatmap, streaks, peak day | Codex `/usage`, TokenBar | TokenBar's 3D/2D toggle, minus the novelty | P2 | todo |
| B9 | Hourly-of-day rhythm | TokenBar | TokenBar | P3 | todo |
| **B10** | **Threshold notifications** (75%/90%) + reset alerts | ClaudeMeter, ClaudeBar | ClaudeMeter's defaults + pacing flame | P2 | done |
| B11 | **Budget guard**: soft warn, hard stop, stale-session nudge | CodeBurn | CodeBurn; it is the only one that acts | P2 | todo |
| B12 | **Waste scan**: config health A–F, paste-ready fixes, undo | CodeBurn | CodeBurn | P2 | todo |
| B13 | Yield: git-correlated Productive/Reverted/Abandoned | CodeBurn | CodeBurn | P3 | todo |
| **B14** | **Doctor**: probe every path, parse health, env overrides | CodeBurn | CodeBurn | P1 | done |
| B15 | Statusline one-liner (model, effort, costs, burn, context %) | ccusage | ccusage | P2 | todo |
| B16 | Model comparison: cost/call, cost/edit, cache-hit | CodeBurn | CodeBurn | P3 | todo |
| B17 | Task-category split (13 categories) | CodeBurn | CodeBurn | P3 | todo |
| B18 | Tool / shell / MCP usage ranking | CodeBurn, Claude `/usage` | CodeBurn | P3 | todo |
| B19 | Plan-value tracker: API-equiv $ vs subscription price | CodeBurn | CodeBurn | P2 | todo |
| **B20** | Date filters, Today/Week/Month, asc/desc, JSON/CSV export | ccusage | ccusage | P1 | done |
| B21 | Custom price overrides + model aliases + offline pricing table | ccusage | ccusage `ccusage.json` | P2 | todo |
| B22 | Multi-currency (cached FX table) | CodeBurn | CodeBurn, cached only — no live fetch | P3 | todo |

## C. Quality of life across every feature

| # | Feature | Source | Best-of | Pri | Status |
|---|---|---|---|---|---|
| C1 | Bulk operations: multi-select install/remove/enable across projects | CCTM, CC One | CCTM project-assign grid | P1 | todo |
| C2 | Undo for every destructive action (today only MCP configs) | CodeBurn `act undo` | CodeBurn's journaled undo | P1 | todo |
| C3 | Server-side of the app: keyboard shortcuts + command palette | opcode, CCTM | opcode | P2 | todo |
| C4 | Search/filter on every list (only Skills and MCP have it) | all | CCTM | P1 | todo |
| C5 | Diff preview before any overwrite | CCTM | CCTM | P1 | todo |
| C6 | Per-project health roll-up across skills/agents/MCP/hooks | CodeBurn grade | CodeBurn A–F | P2 | todo |
| C7 | Export/import an entire project setup as one file | CCTM profiles | CCTM | P2 | todo |
| **C8** | Stale-config detection: skills with missing files, dead MCP servers | CodeBurn | CodeBurn | P2 | done |
| C9 | Empty-state guidance everywhere | CCTM | CCTM | P2 | todo |
| C10 | Recent-activity feed across projects | CC One | CC One | P3 | todo |

## D. Already shipped this programme

| # | Feature | Notes |
|---|---|---|
| D1 | Full-screen default window | fix(ui) `59fd348` |
| D2 | Off-main project open, no first-frame disk read | fix(ui) `59fd348` |
| D3 | Stable Skills pane (no layout shift) | fix(ui) `59fd348` |
| D4 | Skill descriptions removed app-wide | perf(ui) `bcf14bc` |
| D5 | Checks scroll indexed (no per-frame scans) | perf(ui) `bcf14bc` |
| D6 | Usage scans cached per file (size+mtime), all events counted | perf(usage) `2907f40` |
| D7 | Symlink installs, one canonical copy | fix(skills) `91b6cff` |
| D8 | Installed vs inherited split in the project Skills list | fix(skills) `a0bab6c` |
| D9 | Codex plugin index read from `config.toml` (65→15 enabled) | perf(skills) `69d0c43` |
| D10 | Crashes and a data-loss path fixed (int trap, undo, broken pipe, hung probes) | fix `c605622` |

## E. Explicitly not doing

Requires network, an account, or a session token read from a cookie. All conflict
with BRAND.md ("No cloud / accounts / remote sync — local-only, full stop").

- Live provider quota bars for **Cursor** — no local quota file exists. Every Cursor tool reads a local token then calls `api2.cursor.sh` (Pane, TokenGauge, FreePeak). We report "no local quota" instead.
- Session-key/cookie import (ClaudeMeter) — unofficial, and a network call.
- Leaderboards and sync (ccclub, Viberank, CodeBurn `sync`/`share`).
- ClaudeBar's API/CLI-RPC probes for Bedrock, Kimi, Z.ai.
