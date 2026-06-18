# DESIGN.md — Project Hub
> Native macOS app — follows macOS HIG. No custom CSS tokens.
> For the marketing site design system, see active/mcpbolt-landing/DESIGN.md.

---

## Design Approach

Project Hub is a native SwiftUI + AppKit app. It follows the macOS Human Interface Guidelines rather than a custom design system. This means:

- Light/dark mode comes from `NSApp.effectiveAppearance` — never hardcode colors
- Use semantic SwiftUI colors: `.primary`, `.secondary`, `.background`, `.windowBackground`, etc.
- Follow macOS spacing conventions (8pt grid; standard Apple control sizing)
- The desktop window is the primary surface; the popover remains fixed at **480×680 pt** as a compact secondary panel.

---

## App Structure

**Desktop window:**
- Primary app surface on launch, Dock reopen, and menu-bar left click
- Large resizable `NSWindow`, with macOS full-screen support
- Tabs: Projects / Skills / MCP / Compat / Settings

**Popover (480×680):**
- Secondary compact panel from the menu bar
- Same root content, with the expand control visible
- Designed for quick use, not the default full workflow

**Project Detail:**
- Sub-tabs: Skills / Agents / MCP / Rules / Hooks / CLAUDE.md
- Sheet presentations for create/edit flows

**Live Mode (floating NSPanel):**
- `BeaconView` — 48×48 draggable circle, always-on-top
- Sidebar panel slides in from beacon position
- Never steals focus (`canBecomeKey: false`)

---

## Color Guidelines

- **Accent color:** Use system blue (`.accentColor`) unless overriding — don't introduce a custom brand color in the native app
- **Status indicators:** Use system green/yellow/red semantic colors
- **Card backgrounds:** `Color(.windowBackgroundColor)` or `Color(.controlBackgroundColor)`
- **Borders:** `Color(.separatorColor)` — adapts to light/dark automatically

---

## SwiftUI Conventions (match existing code)

- Row height: 44–52pt
- Section padding: 12pt horizontal
- Icon size in rows: 20–24pt
- Sheet max height: `presentationDetents([.medium, .large])`
- Monospaced text for file paths, server names: `.font(.system(.caption, design: .monospaced))`

---

## Do's and Don'ts

**Do:**
- Use `@Environment(\.colorScheme)` to adapt if needed
- Use `List` with `.listStyle(.sidebar)` for project/skill lists (matches macOS convention)
- Use `Label` for icon+text rows (automatic dark-mode icon handling)

**Don't:**
- Don't hardcode hex colors — always use semantic SwiftUI colors
- Don't set fixed heights on text — let Dynamic Type work
- Don't use `UIColor` — this is AppKit/SwiftUI, use `NSColor` or `Color`
- Don't build custom tab bars that don't match the existing pattern

---

## Live Mode Visual Rules

- Beacon ring: progress arc from 0–360° representing context fill (green→yellow→orange→red as usage climbs)
- Cyan glow when Claude Code is frontmost window
- Panel background: match system popover background
- Toggle switches for skills/MCP: standard SwiftUI `Toggle` with `.toggleStyle(.switch)`
