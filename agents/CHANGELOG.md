# Changelog — agents

All notable changes to this tier are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

## [Unreleased]

## [2026-06-18] · Codex

### Added
- Added explicit status-menu commands to open the full Project Hub dashboard or the compact panel.

### Changed
- Promoted Project Hub to a desktop-first app shell: launch, Dock reopen, and menu-bar left click now open the full dashboard window, while the menu bar remains as a companion control.
- Removed the release bundle's `LSUIElement` menu-bar-agent flag so installed builds behave as normal macOS desktop apps.

### Fixed
- Fixed status-menu Quit targeting so Quit is handled by `NSApp` while app-specific menu actions remain on the app delegate.

## [2026-06-18] · Codex

### Added
- Added first-class Compatibility plugin inventory for Codex CLI/Desktop and Claude Code, covering Codex cache/config/marketplace evidence plus Claude installed inventory/settings/known-marketplace/skills-dir/marketplace-directory evidence.
- Added a Plugins section to the Compatibility UI and clipboard report with install method, state, version, components, path, and source.

### Fixed
- Added warnings for enabled Codex/Claude plugins that are configured in local settings but missing from the installed cache/inventory.
- Rebuilt and reinstalled `/Applications/ProjectHub.app` from the current release bundle, then removed the generated repo-local app artifact so `/Applications` remains the only installed app location.

## [2026-06-18] · Codex

### Changed
- Tightened project discovery so auto-discovery only accepts existing coding-project roots with evidence, skips protected Desktop/Documents/Downloads paths unless explicitly added, hides worktrees outside the primary list, and de-dupes case variants such as `active` vs `Active`.
- Added saved-project sanitation on load so old false positives like tool homes, workspace containers, and top-level generic storage folders are removed from persisted Project Hub state.
- Guarded global Skills install-count refresh so opening the Skills tab does not background-walk protected storage folders.

### Fixed
- Fixed false discovered rows such as `~/.codex`, broad `Active` workspace roots, Codex transcript/session folders, and generic non-project folders.
- Fixed the Project Hub Desktop permission prompt path by avoiding protected-storage probes during background discovery and Skills aggregate refresh.

## [2026-06-18] · Codex

### Added
- Added hidden Git worktree handling in project discovery, including collapsed Projects-tab access to related worktrees without showing them as normal projects.

### Changed
- Moved global skill install counts out of SwiftUI card rendering and into a cached background refresh in `SkillStore`.
- Made Compatibility scans explicit and single-flight, with tab/input changes invalidating stale reports instead of auto-running expensive scans.

### Fixed
- Fixed the Skills-tab non-responsive path caused by scanning every tracked project from the SwiftUI body when global skills rendered.
- Fixed Compatibility scan freezes caused by overlapping scan requests and repeated main-thread issue dedupe/canonicalization during result summary rendering.
- Rebuilt and reinstalled the patched release app at `/Applications/ProjectHub.app`, leaving only one Project Hub app bundle in `/Applications`.

## [2026-06-18] · Codex

### Fixed
- Built a fresh release `ProjectHub.app`, installed it to `/Applications/ProjectHub.app`, verified the app bundle signature, and confirmed `/Applications` contains only one Project Hub app bundle.

## [2026-06-18] · Codex

### Added
- Restored and merged the recovered Compatibility branch into active `main`, including the Compatibility scanner/view, MCP health and import coverage, Codex plugin/profile surfaces, and regression coverage that had lived only in the recovered worktree.
- Added Claude Code additional-directory skill roots to Compatibility skill-support surfaces and restored read-only adjacent editor project MCP visibility for Cursor, VS Code, and Roo config files.

### Changed
- Moved Compatibility scanning off the SwiftUI main path with a busy/request state, and made XCTest auth probing deterministic when no fake Claude command is supplied.
- Replaced project-root canonicalization hotspots with file-path canonicalization in Compatibility and Codex trust helpers.
- Preserved active checkout dirty Live Mode work while merging the recovered branch into `main`.

### Fixed
- Fixed the recovered branch's full-suite failures in adjacent MCP detection, read-only editor project MCP discovery, headers helper expectations, and additional-directory skill inventory.
- Verified the recovered branch and active checkout with `swift build`, focused seam tests, full `swift test` (564 tests), and `git diff --check`.

## [2026-05-22] · Codex

### Added
- Added Project Hub protocol canon for this worktree.
- Added Claude/Codex compatibility scanning, matrix display, MCP health summaries, and a project Health tab.
- Added support for MCP auth/restart/disabled/unknown health states and imported Codex bearer token env metadata.
- Added a global MCP Verify action with stdio JSON-RPC initialize probes and remote HTTP/SSE endpoint probes.
- Added Claude Code managed MCP and Codex admin/managed MCP surfaces to the compatibility scanner.
- Added previewed file fixes for writable MCP findings, including enabling disabled servers and removing broken registrations.
- Added a previewed Claude settings repair for conflicting `enabledMcpjsonServers` / `disabledMcpjsonServers` approvals.
- Added a previewed Codex settings repair that removes stale `[[skills.config]]` entries pointing at missing `SKILL.md` files.
- Added a previewed Codex skill enable repair for installed skills disabled through `[[skills.config]]`.
- Added target-scope filtering in the Compatibility tab for all, global, project, CLI, and desktop surfaces.
- Added experimental read-only Claude Desktop MCPB/DXT extension manifest scanning with disabled/config-needed classification.
- Added MCPB/DXT archive manifest preview and Claude Desktop installer handoff in the MCP import flow.
- Added Codex project trust detection with a previewed user-config trust repair.
- Added a previewed cleanup for duplicate Codex project settings when user-level `[projects]` overrides and checked-in `.codex/config.toml` overlap.

### Changed
- Updated Codex skill discovery to prefer `~/.agents/skills` while showing `~/.codex/skills` as managed/legacy.
- Expanded settings/global UI with compatibility matrix context for Claude Code, Claude Desktop, Codex CLI, and Codex Desktop.
- Updated Codex config/auth/managed skill discovery to respect `CODEX_HOME` where applicable.
- Classified Claude project approval overlaps as conflicts instead of generic broken findings.
- Updated compatibility issue-sheet copy to explain previewed file fixes, backups, and what Project Hub will not touch.
- Added settings observations for Claude and Codex config files so project settings checks can report file-controlled keys.
- Hardened Codex skill override handling so folder paths and `SKILL.md` paths resolve to the same exact target before offering fixes.
- Marked Claude Desktop extension runtime, credentials, and live health as app-managed rather than launching extension internals from Project Hub.
- Changed remote archive URL handling to ask users to download locally before validation instead of treating binary archives as JSON configs.

### Fixed
- Removed an unnecessary empty-config write before deleting project-scoped MCP servers.
