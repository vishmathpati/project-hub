# agents/docs/INDEX.md

## Human Map

- Project: Project Hub is a personal macOS menu-bar app for managing local AI coding tool setup across projects.
- Stack: SwiftPM executable; SwiftUI + AppKit; macOS 14+; system SQLite3; no external package dependencies.
- Page/surface: Menu bar status item — opens the app popover, context menu, Dock behavior, and Live Mode entry.
- Page/surface: Projects tab — shows saved and discovered projects, lets the user add/remove/rename/touch projects.
- Page/surface: Skills tab — shows global skills and project-installed skills, installs/removes skill folders for Claude and Codex.
- Page/surface: Agents view — reads and manages Claude project agents in `.claude/agents`.
- Page/surface: MCP tab — reads global and project MCP configs, supports guarded writes/copies for supported formats.
- Page/surface: Settings tab — app-level settings and utility actions.
- Page/surface: Live Mode — floating beacon/window for active-context awareness.
- Feature: Project discovery — Projects tab — live.
- Feature: Skill install/remove — Skills tab — live.
- Feature: Agent management — Project detail / Agents view — live.
- Feature: Cursor rules viewing/editing — Project detail / Cursor rules view — live.
- Feature: MCP inspection and write/copy — MCP tab and sheets — live.
- Feature: Profile copying — Copy profile sheet — live.
- Feature: Live Mode — floating utility surface — in progress.

## Agent Dependency Index

- Data Model: `Project`, `DiscoveredProject`, `Skill`, `InstalledSkill`, `Agent`, `MCPServerInfo`, `ServerEntry`, `ToolSummary` in `Sources/ProjectHub/Models.swift`.
- Data Model: Saved projects live in UserDefaults key `projecthub.projects.v1`; schema is Codable `Project`.
- Data Model: Codex project discovery reads local `~/.codex/state_N.sqlite`; inspect `ProjectStore.fromCodexSqlite`.
- External Service: Claude Code local config — reads `~/.claude.json` and project `.mcp.json`; filesystem only.
- External Service: Codex local config — reads `~/.codex/config.toml`, `~/.codex/state_N.sqlite`, and project `.codex/config.toml`; filesystem/SQLite only.
- External Service: Cursor local config — reads project `.cursor/mcp.json` and rules; filesystem only.
- Key File: `Sources/ProjectHub/App.swift` — app delegate, status item, popover, Live Mode menu, dashboard expansion.
- Key File: `Sources/ProjectHub/Views/ContentView.swift` — tab shell and shared header gradient.
- Key File: `Sources/ProjectHub/Stores/ProjectStore.swift` — saved projects plus Claude/Codex/filesystem project discovery.
- Key File: `Sources/ProjectHub/Stores/SkillStore.swift` — global and project skill scanning/install/remove.
- Key File: `Sources/ProjectHub/Stores/AgentStore.swift` — project agent scanning and creation [VERIFY if editing].
- Key File: `Sources/ProjectHub/Stores/MCPStore.swift` — global MCP store, update/copy/remove/toggle actions.
- Key File: `Sources/ProjectHub/Core/FullConfigReader.swift` — reads all supported tool configs.
- Key File: `Sources/ProjectHub/Core/ConfigWriter.swift` — writes supported MCP configs with format translation and backups.
- Key File: `Sources/ProjectHub/LiveMode/ProjectWatcher.swift` — active project/tool tracking for Live Mode.
- Critical Function/Component: `ProjectStore.scan()` -> used by Projects tab, startup discovery, refresh action.
- Critical Function/Component: `ProjectStore.findProjects(excluding:)` -> used by project discovery and detected source merging.
- Critical Function/Component: `SkillStore.installedSkills(for:)` -> used by project detail skill state and install/remove decisions.
- Critical Function/Component: `MCPStore.copyServer(name:from:to:)` -> used by MCP copy workflows.
- Critical Function/Component: `ConfigWriter.writeServer(...)` -> used by MCP edits/copies; risky because it mutates user config files.
- Critical Function/Component: `ContentView.headerGrad` -> used across header, active tabs, CTAs, and sheets.
- Feature Dependency Map: project-discovery: `ProjectsView` -> `ProjectStore.scan()` -> `fromClaudeJson`/`fromCodexSqlite`/`fromFilesystem` -> local configs/filesystem; data: UserDefaults `projecthub.projects.v1`; guards: exclude broad home/system paths.
- Feature Dependency Map: skill-install-remove: `SkillsView` -> `SkillStore.install/remove` -> copies/removes `.claude/skills` and `.agents/skills`; data: skill folder with `SKILL.md`; guards: skip existing destination.
- Feature Dependency Map: agent-management: `AgentsView` -> `AgentStore` -> `.claude/agents/*.md`; data: markdown frontmatter/body; guards: preserve body and required metadata [VERIFY before edits].
- Feature Dependency Map: cursor-rules: `CursorRulesView` -> project `.cursorrules` / `.cursor/rules/`; data: rule markdown/text; guards: preserve existing user-authored rules.
- Feature Dependency Map: mcp-inspection: `GlobalMCPView`/`MCPView` -> `MCPStore` -> `ConfigReader.shared.readAllTools()`; data: tool config files; guards: hide unsupported/noisy tools where intended.
- Feature Dependency Map: mcp-write-copy: MCP sheets -> `MCPStore` -> `ConfigWriter`; data: JSON/TOML/YAML config shapes; guards: unsupported formats must surface manual action.
- Feature Dependency Map: profile-copy: `CopyProfileSheet` -> `ProfileCopier`; data: skills and agents folders; guards: avoid overwriting without explicit behavior [VERIFY].
- Feature Dependency Map: live-mode: `LiveModeView`/`BeaconView` -> `ProjectWatcher`; data: frontmost app and project context; guards: keep floating window behavior reversible.
- Guardrail: Never introduce remote sync or telemetry without a locked `agents/BRIEF.md` decision.
- Guardrail: Config writes must be explicit and recoverable where practical.
- Guardrail: Keep read-only support distinct from writable support in UI copy and state.
- Guardrail: Do not let views parse tool config formats directly; route through Core readers/writers.
- Guardrail: Run `swift build` after changing package, models, stores, views, AppKit lifecycle, or config writer code.
