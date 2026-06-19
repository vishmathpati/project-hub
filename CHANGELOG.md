# Changelog

All notable changes to Project Hub are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

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
