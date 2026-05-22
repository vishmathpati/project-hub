# agents/STRUCTURE.md
> Per-project structural map. Read before adding, moving, or refactoring UI surfaces or shared helpers.

---

## Surfaces Present

| Surface | Present | Path | Tech |
|---------|---------|------|------|
| Menu bar app | yes | `Sources/ProjectHub/App.swift` | SwiftUI + AppKit |
| Popover app shell | yes | `Sources/ProjectHub/Views/ContentView.swift` | SwiftUI |
| Dashboard window | yes | `Sources/ProjectHub/DashboardWindow.swift`, `Sources/ProjectHub/Views/` | SwiftUI + AppKit |
| Live Mode | yes | `Sources/ProjectHub/LiveMode/` | SwiftUI + AppKit |
| Marketing website | no | n/a | n/a |
| Backend/API | no | n/a | n/a |

---

## Component Locations

| Tier | Path | Notes |
|------|------|-------|
| App shell | `Sources/ProjectHub/App.swift`, `DashboardWindow.swift`, `Views/ContentView.swift` | Launch, status item, popover, tab shell, dashboard window |
| Feature views | `Sources/ProjectHub/Views/` | Projects, Skills, Agents, MCP, Settings, sheets, editors |
| Live Mode views | `Sources/ProjectHub/LiveMode/` | Beacon, floating window, watcher |
| Stores | `Sources/ProjectHub/Stores/` | ObservableObject state and user actions |
| Core readers/writers | `Sources/ProjectHub/Core/` | Config readers, parsers, writers, profile copy helpers |
| Models | `Sources/ProjectHub/Models.swift` | Shared structs/enums for every feature |

---

## Stack Per Surface

- **App runtime**: SwiftPM executable, macOS 14+, SwiftUI, AppKit.
- **Persistence**: UserDefaults for app project list; filesystem for tool configs; read-only SQLite3 for Codex state.
- **External dependencies**: No package dependencies; links against system `sqlite3`.

---

## Conventions Detected

- SwiftUI views are grouped by feature in `Views/`; sheets live beside their feature surface.
- Stores are `@MainActor ObservableObject` classes with file-backed scanning or mutation.
- Core readers/writers hide file-format details from view code.
- AppKit handles status item, popover, dashboard windows, panels, and Dock/status behavior.
- SF Symbols are the icon system.
- Current styling uses system colors, SF typography, and a shared `ContentView.headerGrad` accent treatment.

---

## Cross-Tier Import Rules

- Views may depend on stores and models, but should not parse config files directly.
- Stores may depend on Core readers/writers and Models.
- Core readers/writers should not import SwiftUI.
- Live Mode should stay isolated from the Projects/Skills/MCP feature stores unless a shared model is intentionally added.
- Config writes must remain previewable or recoverable where practical.
