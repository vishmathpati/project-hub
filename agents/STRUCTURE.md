# STRUCTURE.md

## Stack

- SwiftPM package: `ProjectHub`
- Executable target: `Sources/ProjectHub`
- UI: SwiftUI with AppKit integration
- Persistence: UserDefaults for Project Hub's project list; tool config files on disk for external tools
- SQLite: linked for reading Codex state

## Source Map

- `App.swift`: app entry and environment store wiring.
- `AppActions.swift`: app menu actions and launch-at-login behavior.
- `Models.swift`: shared Skill, Agent, MCP, tool summary models.
- `Core/`: readers, config writer, import parser, profile copier, hook/rules/CLAUDE readers.
- `Stores/`: `ProjectStore`, `SkillStore`, `MCPStore`, `AgentStore`.
- `Views/`: tab and detail views for projects, skills, agents, MCP, settings, and sheets.
- `LiveMode/`: live project watching/context UI.

## Shared Components

- `ContentView.headerGrad` is used by many buttons and headers.
- `ToolPalette` maps tool IDs to labels, icons, and colors.
- `ConfigWriter` is the write boundary for MCP config changes.
- `ConfigReader` and `MCPReader` are read boundaries for global/project MCP configs.
- `SkillReader` parses `SKILL.md` frontmatter and is shared by global and project skill views.

## Current Feature Ownership

- Project detection: `Stores/ProjectStore.swift`
- MCP detection and global state: `Core/FullConfigReader.swift`, `Core/MCPReader.swift`, `Stores/MCPStore.swift`
- MCP import/write/copy: `Core/ImportParser.swift`, `Core/ConfigWriter.swift`, `Views/MCPImportSheet.swift`, `Views/MCPCopyToAppsSheet.swift`
- Skills: `Core/SkillReader.swift`, `Stores/SkillStore.swift`, `Views/SkillsView.swift`
- Project details: `Views/ProjectDetailView.swift`
- Settings: `Views/SettingsView.swift`

## Change Guidance

- Prefer extending existing readers/stores before adding new persistence.
- Keep writes behind `ConfigWriter`.
- Add new UI as compact operational panels, not marketing sections.
