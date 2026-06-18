# Project Hub Dependency Index

## Features

### Project Discovery

- Owner: `Sources/ProjectHub/Stores/ProjectStore.swift`
- Reads: `~/.claude.json`, `~/.codex/state_*.sqlite`, `~/.codex/config.toml`, filesystem roots
- Shared with: project rows, project detail tabs, copy-to-project MCP sheet

### MCP Management

- Owner: `Sources/ProjectHub/Core/FullConfigReader.swift`, `Sources/ProjectHub/Core/MCPReader.swift`, `Sources/ProjectHub/Core/MCPHealthChecker.swift`, `Sources/ProjectHub/Core/ImportParser.swift`, `Sources/ProjectHub/Stores/MCPStore.swift`
- Writes: `Sources/ProjectHub/Core/ConfigWriter.swift`
- UI: `Sources/ProjectHub/Views/GlobalMCPView.swift`, `Sources/ProjectHub/Views/MCPView.swift`, `Sources/ProjectHub/Views/MCPImportSheet.swift`, `Sources/ProjectHub/Views/MCPCopyToAppsSheet.swift`, `Sources/ProjectHub/Views/MCPEditServerSheet.swift`
- Shared with: header MCP counts, project details, import/copy/edit flows

### Skill Management

- Owner: `Sources/ProjectHub/Core/SkillReader.swift`, `Sources/ProjectHub/Stores/SkillStore.swift`
- UI: `Sources/ProjectHub/Views/SkillsView.swift`, `Sources/ProjectHub/Views/SkillEditorSheet.swift`, `Sources/ProjectHub/Views/SettingsView.swift`
- Shared with: global skills tab and project skills tab

### Claude Agents

- Owner: `Sources/ProjectHub/Core/AgentReader.swift`, `Sources/ProjectHub/Stores/AgentStore.swift`
- UI: `Sources/ProjectHub/Views/AgentsView.swift`
- Shared with: project detail tabs only

### Rules, Hooks, and CLAUDE.md

- Owners: `CursorRulesReader.swift`, `HooksReader.swift`, `ClaudeMdReader.swift`
- UI: `CursorRulesView.swift`, `HooksView.swift`, `ClaudeMdView.swift`
- Shared with: project detail tabs only

## Critical Shared Components

- `Models.swift`: shared types; changes can affect multiple views.
- `ToolPalette.swift`: app/tool labeling and icon/color identity.
- `ContentView.headerGrad`: shared header/button styling.
- `ConfigWriter`: external config write safety boundary.

## Compatibility Expansion Entry

- Type: addition to existing MCP, Skills, and Project Discovery features plus UI change.
- Owner: `Sources/ProjectHub/Core/CompatibilityScanner.swift`
- UI: `Sources/ProjectHub/Views/CompatibilityView.swift`, `Sources/ProjectHub/Views/SettingsView.swift`
- Dependencies to check before edits: MCP Management, Skill Management, Project Discovery, Critical Shared Components.
