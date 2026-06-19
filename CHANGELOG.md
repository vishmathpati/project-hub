# Changelog

All notable changes to Project Hub are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [2026-06-19] · Codex

### Fixed
- Fixed the Plugins tab losing its successful scan result after leaving and returning to the tab by moving scan results into a ContentView-owned cache keyed by Global/project target, then rebuilt and reinstalled `/Applications/ProjectHub.app` with code signing and single-bundle verification.

## [2026-06-19] · Codex

### Fixed
- Merged the Skills/Plugins redesign branch into main, pushed main to GitHub, cleaned stale Swift build artifacts, rebuilt the release app, installed `/Applications/ProjectHub.app`, verified code signing, removed the repo-local staging bundle, and confirmed `/Applications` contains only one ProjectHub app bundle.

## [2026-06-19] · Codex

### Added
- Added a dedicated Plugins tab for Claude/Codex plugin bundle inventory, with explicit global/project scans, grouped plugin rows, component chips, state, paths, surfaces, and restart evidence.

### Changed
- Redesigned the top-level Skills tab into a deduped capability index with Global Skills and Project Skills tabs, expandable rows, origin evidence, and project availability/installed status instead of long descriptions in the list.

### Fixed
- Added focused skill grouping/project usage tests and verified the current checkout with `swift build`, focused skill/plugin tests, full `swift test` (586 tests), and `git diff --check`.

## [2026-06-19] · Codex

### Changed
- Redesigned the primary Project Hub desktop window with sidebar navigation, toolbar summaries/actions, a split Projects workspace, and desktop project-detail navigation while preserving the compact menu-bar panel.

### Fixed
- Built and installed the redesigned `/Applications/ProjectHub.app`, verified the app bundle signature, confirmed `/Applications` contains only one ProjectHub app bundle, captured installed-app visual proof, and passed full `swift test` plus `git diff --check`.

## [2026-05-05] · Claude Code

### Added
- Project separated from mcpbolt monorepo into standalone git repo at active/projecthub/
- Full project protocol suite: CLAUDE.md, STATUS.md, BRAND.md, BRIEF.md, FUNDAMENTALS.md, DESIGN.md, DISCOVERIES.md, docs/INDEX.md, .gitignore
