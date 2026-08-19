# Status — Project Hub
> Last updated: 2026-08-18 · Claude Code

## Current State

The approved Claude Design system (project `181de825`, screens 2a + 3a–3h) is implemented across the app: dark-first token set in `HubTheme.swift`, provider-tile identity in `ToolPalette.swift`, a shared component library in `Views/HubComponents.swift`, and a grouped captioned rail replacing the eight flat tabs. `Compat` is now `Checks`. Repo `DESIGN.md` holds the approved canon.

Project Hub is desktop-first: launch, Dock reopen, and menu-bar left click open a redesigned full dashboard window with sidebar navigation, toolbar summaries, a split Projects workspace, and desktop project-detail navigation. The menu bar item remains for quick actions and compact-panel access.

The top-level Skills page is now a deduped capability index with expandable global/project skill evidence, and Plugins has its own sidebar destination for bundle/component inventory.
Plugin scan results now stay visible when navigating away from Plugins and returning within the active window.

## Health

- ✅ Working: desktop app shell, menu bar companion, redesigned Projects workspace, deduped Skills, Plugins inventory, MCP, Compatibility, Agents, Hooks, CLAUDE.md editor, Cursor Rules, Profile copy
- ✅ Verified: full `swift test` is green (598 tests, 0 failures) and the redesigned release build is installed at `/Applications/ProjectHub.app`; main is pushed at the Skills/Plugins merge commit; installed `/Applications/ProjectHub.app` includes the plugin-scan persistence fix; current checkout passes `swift build`, focused plugin tests, full `swift test` baseline (586 tests), `git diff --check`, clean release build, code signing, and `/Applications` single-bundle check
- ⚠️ Unknown: Live Mode (BeaconView, ContextEstimator, ProjectWatcher) — in source, needs verification
- 🔧 In progress: Live Mode still needs a manual pass. Current-build roadmap except secondary providers is in `/Applications/ProjectHub.app`.
- 🔴 Broken: (none known)
- ⚠️ Build note: `/Applications/Xcode.app` has an unaccepted licence, so a bare `swift build` fails. Build with `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build`, or run `sudo xcodebuild -license accept` once to fix the default toolchain.
- 🔒 Blocked: (none)

## Needs CEO Input

- Is Live Mode shippable or still in-progress?
- What version number is Project Hub at? (not yet versioned)
- What comes after Live Mode in the roadmap?
- When does Project Hub get its own landing page?

## Recent Sessions (rolling — keep last 5)

- 2026-08-18 · Claude Code: imported the approved Claude Design project and implemented every page in it (2a, 3a–3h). Builds clean against the Xcode Beta toolchain.
- 2026-08-18 · Grok: finished current-build roadmap except secondary providers. Providers create/edit/enable, Usage remaining bars, MCP/Settings no longer run CompatibilityScanner on tab open. Reinstalled `/Applications/ProjectHub.app`.
- 2026-06-19 · Codex: redesigned Skills into a deduped expandable capability index and added a separate Plugins inventory tab.
- 2026-06-19 · Codex: fixed Plugins scan results resetting after navigation and rebuilt `/Applications/ProjectHub.app`.
- 2026-06-19 · Codex: committed, pushed, merged, and rebuilt the Skills/Plugins redesign into `/Applications/ProjectHub.app` with no duplicate installed bundles.
- 2026-06-19 · Codex: redesigned the full desktop UI so it no longer looks like a stretched menu-bar panel; installed and verified `/Applications/ProjectHub.app`.
- 2026-06-18 · Codex: promoted Project Hub from menu-bar-first to desktop-first app shell with compact menu-bar panel retained.

## Next Actions

1. Visually check screens 2a and 3a–3h against `Project Hub Redesign.dc.html`
2. Decide whether `.mcp.json` should show one row (Claude Code wins, current) or one row carrying both Claude Code and Command Code tiles
3. Confirm Providers Controls create/edit/enable on a real project
2. Confirm Usage remaining bars for Claude/Codex
3. Live Mode still needs a manual pass
4. Decide the Project Hub version number and landing page timing
