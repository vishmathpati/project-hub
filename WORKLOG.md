# Worklog — cleared after each session.
[23:15] found_bug: swift build succeeds but emits Swift 6 concurrency warnings in ProjectStore/SkillStore/LiveModeWindow plus minor unused/deprecated warnings — P2
[23:28] found_bug: deleted-worktree audit found large recovered branch preserved at recover/projecthub-4659-2026-06-02 and building, but it is not merged into main — P2
[23:37] found_bug: review of recover/projecthub-4659-2026-06-02 found network-policy drift, synchronous Compatibility scan on main UI path, and full swift test hang/lock contention — P1/P2
[17:18] fixed: Merged recovered compatibility branch into main, reapplied active dirty state, resolved Live Mode conflicts, and preserved stashed CLAUDE.md content.
[17:18] fixed: Active checkout validation passed after merge: swift build, focused seam tests, full swift test, and git diff --check are clean.
[17:21] fixed: Completed agent save-session closeout locally with changelog/status/brief updates, cleared agents/WORKLOG.md, and committed the protocol-only closeout.
[19:34] fixed: Built fresh release ProjectHub.app, installed it to /Applications/ProjectHub.app, and verified only one Project Hub app bundle exists in /Applications.
[19:53] fixed: Added hidden Git worktree discovery metadata and a collapsed Projects-tab worktree disclosure so worktrees no longer pollute the normal project list.
[20:01] fixed: Project discovery/root validation passed, full swift test passed with 567 tests, and git diff --check remained clean after hidden worktree changes.
[20:07] decided: Treat Skills-tab storage prompt freeze as a skills-global bug fix affecting GlobalSkillsView -> SkillStore.refresh -> SkillReader.scanSkillDir; keep scope to nonblocking read/refresh behavior.
[20:09] found_bug: Skills tab computed per-skill project install counts by running SkillInventoryReader for every project inside SwiftUI card rendering, blocking the main thread and matching the macOS non-responsive freeze.
[20:10] fixed: Skills tab no longer runs project skill inventory scans inside SwiftUI card rendering; install counts are cached in SkillStore and computed on a detached utility task.
[20:10] fixed: Added SkillInventoryReader regression coverage proving global skill install counts scan each project once and count duplicate origins once per project.
[20:13] fixed: Rebuilt release ProjectHub.app, replaced /Applications/ProjectHub.app, and verified it is the only Project Hub bundle in /Applications with a valid code signature.
[20:13] fixed: Removed generated local ProjectHub.app/ProjectHub.zip artifacts after installing so only /Applications/ProjectHub.app remains as the runnable app bundle.
[20:15] found_bug: User reproduced another non-responsive freeze from the Compatibility scan path, especially after repeated Scan clicks.
[20:16] found_bug: Compatibility tab auto-ran full scans on open/input changes and refresh() had no in-flight guard, so repeated Scan/change events could stack expensive scans and freeze the app.
[20:18] fixed: Compatibility scans are now explicit and single-flight: no scan on tab open/input change, no overlapping refresh(), and the empty-state button shows scanning progress.
[20:18] fixed: Updated docs indexes with the Compat single-flight scan guardrail.
[20:30] found_bug: Compatibility scan result rendering called filteredIssues() from each summary tile; that repeatedly deduplicated/canonicalized issue paths on the main thread and caused the post-scan CPU freeze.
[20:32] fixed: Optimized Compatibility summary rendering by computing state counts once and removed Project.canonicalize from issue dedupe to avoid main-thread root detection during result layout.
[20:32] tried_failed: Stopped stale full swift test that was still running against the pre-Compatibility-rendering-fix build after the user interrupted to switch to MacBook-display UI testing.
[20:33] fixed: Compatibility rendering patch now compiles; focused Skill/ProjectDiscovery/Compatibility tests passed after removing the main-thread canonicalize loop.
[20:46] fixed: Full swift test passed with 568 tests, git diff --check passed, /Applications contains only /Applications/ProjectHub.app, and agents protocol closeout was updated for the worktree/Skills/Compatibility fixes.
[20:50] decided: Treat wrong entries like ~/.codex, broad Active folders, and transient Documents/Codex chat folders as a Project Discovery bug in ProjectStore.scan and ProjectsView verification scope.
[20:50] found_bug: Project discovery auto-canonicalizes weak CLI/history markers like .codex/config.toml or AGENTS.md into project rows, allowing tool-state and broad workspace folders to appear as coding projects — Sources/ProjectHub/Stores/ProjectStore.swift — P1
[20:57] fixed: Tightened ProjectStore discovery to require existing candidate paths, reject tool/session/workspace containers, and require project evidence while keeping real nested projects and hidden worktrees eligible.
[21:00] found_bug: Project discovery de-dupes paths case-sensitively, so the same macOS folder can appear twice as active/... and Active/... — Sources/ProjectHub/Stores/ProjectStore.swift — P2
[21:04] fixed: Added case-insensitive discovery de-dupe keys so existing/tracked project paths suppress discovered candidates with different casing.
[21:38] fixed: Tightened Project Hub discovery and saved-state cleanup to reject tool/session/workspace/protected-storage false positives, prevent Skills-tab background storage prompts, rebuild the installed app, and validate full `swift test` (581 tests).
[21:42] decided: Treat plugin detection as an addition to existing Compatibility, Skill Management, and MCP Management surfaces; cover Codex and Claude Code install methods without adding installer automation.
[22:15] fixed: Added first-class Compatibility plugin detection for Codex and Claude Code install modes, including cache/config/marketplace/settings/skills-dir evidence and missing-enabled-plugin warnings.
[22:15] fixed: Compatibility UI now shows a Plugins section and clipboard report table for plugin install method, state, version, components, path, and source.
[22:15] fixed: Backend verification passed with full `swift test` baseline, focused `CompatibilityPluginMCPTests`, `swift build`, and scoped `git diff --check`.
[22:15] tried_failed: Stopped Computer Use UI verification after Project Hub's menu-bar popover/window attachment timed out; user requested manual UI checklist instead of spending more time on automation.
[22:15] fixed: Removed generated repo-local ProjectHub.app artifact after installing; `/Applications` still contains only `/Applications/ProjectHub.app`.
[22:29] decided: Project Hub is now desktop-first with a menu bar companion because the product has outgrown the original compact popover.
[22:29] fixed: Launch, Dock reopen, and menu-bar left click now open the full dashboard window; compact popover remains explicit from the status menu — App.swift, DashboardWindow.swift, ContentView.swift, build-app.sh.
[22:29] fixed: Status-menu Quit now targets NSApp while other menu actions target the app delegate — App.swift.
[23:56] decided: Treat the requested redesign as a UI change to the existing desktop app shell; reuse ContentView/top-level feature views, avoid new product scope, and focus on desktop-window layout language.
[00:03] fixed: Redesigned the desktop app shell with sidebar navigation, toolbar summaries, split Projects workspace, desktop project-detail rail, and centered desktop window sizing; compact popover layout remains intact.
[00:03] fixed: Verified the redesign compiles with `swift build`; pre-existing Live Mode/ClaudeMdView warnings remain.
[00:08] fixed: Built release ProjectHub.app from this checkout, installed it to /Applications, verified code signing, confirmed only one ProjectHub app bundle in /Applications, and visually captured the installed desktop layout.
[00:16] fixed: Full regression gate passed with `swift test` (583 tests, 0 failures) and `git diff --check`.
