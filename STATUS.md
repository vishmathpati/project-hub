# Status — Project Hub
> Last updated: 2026-06-19 · Codex

## Current State

Project Hub is desktop-first: launch, Dock reopen, and menu-bar left click open a redesigned full dashboard window with sidebar navigation, toolbar summaries, a split Projects workspace, and desktop project-detail navigation. The menu bar item remains for quick actions and compact-panel access.

The top-level Skills page is now a deduped capability index with expandable global/project skill evidence, and Plugins has its own sidebar destination for bundle/component inventory.
Plugin scan results now stay visible when navigating away from Plugins and returning within the active window.

## Health

- ✅ Working: desktop app shell, menu bar companion, redesigned Projects workspace, deduped Skills, Plugins inventory, MCP, Compatibility, Agents, Hooks, CLAUDE.md editor, Cursor Rules, Profile copy
- ✅ Verified: main is pushed at the Skills/Plugins merge commit; installed `/Applications/ProjectHub.app` includes the plugin-scan persistence fix; current checkout passes `swift build`, focused plugin tests, full `swift test` baseline (586 tests), `git diff --check`, clean release build, code signing, and `/Applications` single-bundle check
- ⚠️ Unknown: Live Mode (BeaconView, ContextEstimator, ProjectWatcher) — in source, needs verification
- 🔴 Broken: (none known)
- 🔒 Blocked: (none)

## Needs CEO Input

- Is Live Mode shippable or still in-progress?
- What version number is Project Hub at? (not yet versioned)
- What comes after Live Mode in the roadmap?
- When does Project Hub get its own landing page?

## Recent Sessions (rolling — keep last 5)

- 2026-06-19 · Codex: redesigned Skills into a deduped expandable capability index and added a separate Plugins inventory tab.
- 2026-06-19 · Codex: fixed Plugins scan results resetting after navigation and rebuilt `/Applications/ProjectHub.app`.
- 2026-06-19 · Codex: committed, pushed, merged, and rebuilt the Skills/Plugins redesign into `/Applications/ProjectHub.app` with no duplicate installed bundles.
- 2026-06-19 · Codex: redesigned the full desktop UI so it no longer looks like a stretched menu-bar panel; installed and verified `/Applications/ProjectHub.app`.
- 2026-06-18 · Codex: promoted Project Hub from menu-bar-first to desktop-first app shell with compact menu-bar panel retained.

## Next Actions

1. Manually confirm the installed Plugins tab keeps scan results after switching away and back
2. Run app, test Live Mode panel (BeaconView + context tracking)
3. Update ROADMAP.md — all v0.1–v0.5 features are already shipped, add Live Mode + post-launch direction
4. Decide the Project Hub version number and landing page timing
