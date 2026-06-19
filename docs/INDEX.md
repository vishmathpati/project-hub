# docs/INDEX.md — Project Hub
> Two sections: human map + agent dependency index.
> Update Section 1 when views change. Update Section 2 when features/data/services change.

---

## Section 1 — Human Map

**Project:** Project Hub — native macOS desktop app with a menu bar companion for managing AI coding tool configs across projects.
**Stack:** Swift + SwiftUI + AppKit, macOS 14+. No external dependencies.
**Build:** `swift build` in project root. Run: `swift run`.

**Views:**

| View | What it shows | Features |
|------|--------------|---------|
| Dashboard window | Primary full desktop app window | Default launch/reopen/menu-bar-left-click surface, sidebar navigation, toolbar summary/actions, resizable, macOS full-screen capable |
| Popover (480×680) | Compact menu bar panel, 6 tabs | Secondary quick-access surface |
| Projects tab | Desktop split workspace for tracked + auto-discovered project folders, with compact stacked layout in the popover | Add, scan, rename, remove, open in Finder, drill in, inspect hidden worktrees |
| Skills tab (global) | Deduped global and project-local skill availability across Claude/Codex roots | Expand unique skills to inspect origins, tool support, project usage, and project-local sources without long list descriptions |
| Plugins tab | Claude/Codex plugin bundles and components | Explicit plugin scan, grouped plugin inventory, install evidence, state, component, path, and restart metadata |
| MCP tab (global) | All MCP servers across all 12 AI tools | Search, import, edit, copy between tools, enable/disable |
| Compat tab | MCP/plugins/skills/settings/auth/project compatibility diagnostics | Explicit single-flight scan, plugin inventory, filters, MCP verify, safe-fix previews |
| Settings tab | App preferences | Launch at login, etc. [VERIFY contents] |
| Project Detail | Per-project sub-tabs (6) | Skills, Agents, MCP, Rules, Hooks, CLAUDE.md |
| Live Mode panel | Floating always-on-top context monitor | Token usage ring, skill/MCP toggles, active project detection |

**Features:**

| Feature | View | Status |
|---------|------|--------|
| Desktop-first app shell with menu bar companion | AppDelegate / DashboardWindow / ContentView | live |
| Project auto-discovery (Claude, Codex, filesystem, hidden worktree bucket; protected storage skipped unless explicitly added) | Projects tab | live |
| Profile copy across projects | CopyProfileSheet | live |
| Deduped skill availability browser | Skills tab | live |
| Plugin bundle inventory | Plugins tab | live |
| Per-project skill install / remove / edit | ProjectDetail › Skills | live |
| Per-project Claude sub-agent create / delete | ProjectDetail › Agents | live |
| Global MCP server manager (12 tools) | MCP tab | live |
| Per-project MCP config view / edit | ProjectDetail › MCP | live |
| Per-project Cursor rules CRUD | ProjectDetail › Rules | live |
| Per-project hooks viewer (read-only) | ProjectDetail › Hooks | live |
| Per-project CLAUDE.md editor with templates | ProjectDetail › CLAUDE.md | live |
| Compatibility scan, plugin detection, and safe-fix preview | CompatibilityView | live |
| Live Mode context monitoring | LiveModeView / BeaconView | in-progress [VERIFY] |

---

## Section 2 — Agent Dependency Index

### Data Model

| Entity | File | Purpose |
|--------|------|---------|
| `Project` | Models.swift | User-added project: UUID, path, displayName, addedAt, lastOpenedAt — persisted to UserDefaults |
| `DiscoveredProject` | Stores/ProjectStore.swift | Auto-found project before user adds: path, sources set, detected tool IDs, optional worktree metadata |
| `Skill` | Models.swift | Global skill: name, description, triggers, source enum, directory path |
| `InstalledSkill` | Models.swift | Skill in a project: optional claude path + codex path |
| `SkillStore.GlobalSkillGroup` | SkillStore.swift | Deduped global skill group for top-level Skills UI, grouped case-insensitively by skill name |
| `SkillStore.ProjectSkillUsage` | SkillStore.swift | Ephemeral project usage row for expanded global skill details |
| `Agent` | Models.swift | Claude sub-agent: name, description, model, tools list, markdown body, file path |
| `MCPServerInfo` | Models.swift | Project-scoped server: source (claude-code/codex/cursor), name, detail string |
| `ServerEntry` | Models.swift | Global MCP server: transport, command/args or URL, disabled flag |
| `ToolSummary` | Models.swift | One AI tool's full server list |
| `HookEntry` | HooksView.swift | Hook: tool, event, command, matcher, scope — read-only |
| `CursorRule` | CursorRulesView.swift | .mdc rule: description, globs, alwaysApply, filename, body |
| `ContextSnapshot` | ContextEstimator.swift | Live Mode: full token estimate — ephemeral, never persisted |

**Persistence:** Only `[Project]` persists — `UserDefaults` key `projecthub.projects.v1`. Everything else reads live from filesystem.
Saved project rows are sanitized on load so old false positives such as tool homes, workspace containers, and top-level generic storage folders do not remain in the primary project list.

### External Services

| Service | What for | Access |
|---------|---------|--------|
| Claude Code session files | Live Mode real token counts | Filesystem: `~/.claude/projects/<encoded>/*.jsonl` |
| Claude Code config | Project discovery, global MCP list | Filesystem: `~/.claude.json` |
| Codex SQLite | Project discovery | Filesystem: `~/.codex/state_N.sqlite` — `SELECT cwd FROM threads` |
| Codex config TOML | Project detection, MCP | Filesystem: `~/.codex/config.toml` (regex-parsed) |
| macOS `lsof` | Live Mode active-project detection | Shell: `lsof -F pn -d cwd -c claude` — may be slow |

**No network calls.** All data is local filesystem only.

### Key Files

| File | Why it matters |
|------|---------------|
| `Core/ConfigWriter.swift` | ALL MCP writes go through here — handles all 12 tools, both scopes, backup rotation |
| `Stores/ProjectStore.swift` | Project persistence + 3-source discovery — all project-aware features depend on this |
| `LiveMode/ContextEstimator.swift` | Token counting for Live Mode — reads JSONL + skill dirs |
| `LiveMode/ProjectWatcher.swift` | Active Claude Code project detection — 2s poll, `lsof` cache |
| `Core/FullConfigReader.swift` | Reads ALL tool configs for global MCP tab — potentially slow |
| `Models.swift` | All shared data types — changes here break everything |

### Critical Functions / Components

| Function | File | Used by |
|----------|------|---------|
| `ProjectStore.scan()` | ProjectStore.swift | Projects tab, menu bar refresh, app open |
| `ProjectStore.detectedTools(at:)` | ProjectStore.swift | Project row badges, makeProject() |
| `SkillStore.deduplicatedGlobalSkills(_:)` | SkillStore.swift | Skills tab unique global skill rows |
| `SkillStore.projectUsages(forSkillNamed:globalSkills:projects:)` | SkillStore.swift | Expanded Skills tab project availability/installed evidence |
| `ConfigWriter.writeServer(toolID:scope:projectRoot:name:config:)` | ConfigWriter.swift | MCPStore, MCPEditServerSheet |
| `ConfigWriter.removeServer(toolID:scope:projectRoot:name:)` | ConfigWriter.swift | MCPView, GlobalMCPView, MCPStore |
| `ConfigWriter.disableServer / enableServer` | ConfigWriter.swift | MCPStore, LiveModeView |
| `SkillReader.scanSkillDir(_:source:)` | SkillReader.swift | SkillStore, ContextEstimator |
| `ContextEstimator.estimate(for:)` | ContextEstimator.swift | LiveModeView.refreshSnapshot |
| `ProjectWatcher.pollActiveProject()` | ProjectWatcher.swift | LiveModeView (onChange) |
| `ProfileCopier` (class) | Core/ProfileCopier.swift | CopyProfileSheet |

### Feature Dependency Map

```
desktop-app-shell:
  flow: ProjectHubApp/AppDelegate -> DashboardWindow -> ContentView desktop shell (sidebar + toolbar + feature content); status item remains as companion control
  data: shared ProjectStore, SkillStore, AgentStore, MCPStore instances injected into both desktop window and compact popover
  guards: default launch, Dock reopen, and menu-bar left click open the desktop window; compact popover remains explicit and secondary; desktop layout must not inherit the compact popover tab-strip as its primary navigation
  shared with: every top-level tab rendered by ContentView

projects-tab:
  flow: ProjectsView compact/desktop presentation → ProjectStore.scan() → [~/.claude.json, Codex SQLite, Codex config, filesystem walk]
  data: Project (UserDefaults), DiscoveredProject (ephemeral), hiddenWorktrees (ephemeral)
  guards: requires home dir access; Codex SQLite may not exist; only existing folders with project evidence qualify; ignore tool homes, transcript/session folders, and workspace containers; Git worktrees must stay out of the primary project/discovered lists and appear only in the collapsed worktree section

skills-global:
  flow: GlobalSkillsView → SkillStore.refresh() → SkillReader.scanSkillDir() → SkillStore.deduplicatedGlobalSkills() → expandable origin/project evidence
  data: Skill (in-memory), SkillStore.GlobalSkillGroup, SkillStore.ProjectSkillUsage
  guards: top-level rows are deduped by case-insensitive skill name; list rows do not show long descriptions; project usage scans only saved projects that ProjectStore marks safe for background inspection
  shared with: skills-per-project (installs), live-mode (token counts)

plugins-global:
  flow: PluginsView → explicit Scan button → CompatibilityScanner.scan(projectRoot:) → CompatibilityScanResult.plugins → grouped PluginInventoryGroup rows
  data: CompatibilityPluginObservation (ephemeral); no persisted plugin model
  guards: scan stays explicit and single-flight; last scan results are cached per global/project target for the active window so tab switching does not clear the inventory; plugin page is read-only inventory and must not duplicate CompatibilityScanner plugin detection logic
  shared with: compatibility (plugin evidence), skills-global (plugin-owned skills), mcp-global (plugin-owned MCP evidence)

mcp-global:
  flow: GlobalMCPView → MCPStore.refresh() → FullConfigReader → [all 12 tool config files]
  data: ToolSummary → [ServerEntry]
  guards: reads ~/Library/Application Support/ paths
  shared with: mcp-per-project (ConfigWriter), live-mode (enable/disable toggle)

compatibility:
  flow: CompatibilityView → explicit Scan button → CompatibilityScanner.scan() → [MCP, plugins, skills, settings, auth, project context]
  data: CompatibilityScanResult (ephemeral), including CompatibilityPluginObservation rows for Codex and Claude Code plugin evidence
  guards: no scan on tab open or input change; scans must stay single-flight to avoid overlapping filesystem/config scans
  plugin evidence: Codex cache/config/marketplace files/marketplace source config; Claude installed_plugins.json/enabledPlugins/extraKnownMarketplaces/skills-dir/marketplace directories
  shared with: MCP Management, Skill Management, Project Discovery, ConfigWriter

agents-per-project:
  flow: AgentsView → AgentReader.agents(at:) → <project>/.claude/agents/*.md
  data: Agent (frontmatter + body)
  shared with: (none)

hooks-per-project:
  flow: HooksView → HooksReader.hooks(for:) → [.claude/settings.json, .codex/config.toml, .cursor/settings.json]
  data: HookEntry (read-only — no writes)
  shared with: (none)

claude-md-per-project:
  flow: ClaudeMdView → ClaudeMdReader.read/write(at:) → <project>/CLAUDE.md
  guards: overwrites on save — no diff shown; user sees unsaved-changes indicator only

cursor-rules-per-project:
  flow: CursorRulesView → CursorRulesReader → <project>/.cursor/rules/*.mdc
  shared with: profile-copy (ProfileCopier)

live-mode:
  flow: LiveModeView → ProjectWatcher (2s poll) + lsof → ContextEstimator.estimate() → [~/.claude/projects/<enc>/*.jsonl, skill dirs, ~/.claude.json]
  data: ContextSnapshot (ephemeral)
  guards: lsof is slow; JSONL scan reads last assistant message backwards only
  shared with: mcp-global (ConfigWriter for toggle), skills (SkillReader)
  → consider docs/detail/live-mode.md if flow needs deeper docs
```

### Guardrails

1. **ConfigWriter is the only thing that writes MCP configs.** Never write config files directly from a view.
2. **ProjectStore is the source of truth for the project list.** Never read UserDefaults for projects directly.
3. **Live Mode must not block the main thread.** `ContextEstimator.estimate()` and `ProjectWatcher.pollActiveProject()` are async.
4. **All file reads are from user home directory.** Paths: `~/.claude/`, `~/.codex/`, `~/.cursor/`, `~/Library/Application Support/`. Do not deviate.
5. **No network calls.** If a new feature requires one, surface it to the user — it's a policy change.
6. **Compatibility scans are explicit and single-flight.** Opening the Compat tab or changing scan inputs must not launch overlapping full scans.
