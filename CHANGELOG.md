# Changelog

All notable changes to Project Hub are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [2026-06-19] · Codex

### Changed
- Redesigned the primary Project Hub desktop window with sidebar navigation, toolbar summaries/actions, a split Projects workspace, and desktop project-detail navigation while preserving the compact menu-bar panel.

### Fixed
- Built and installed the redesigned `/Applications/ProjectHub.app`, verified the app bundle signature, confirmed `/Applications` contains only one ProjectHub app bundle, captured installed-app visual proof, and passed full `swift test` plus `git diff --check`.

## [2026-05-05] · Claude Code

### Added
- Project separated from mcpbolt monorepo into standalone git repo at active/projecthub/
- Full project protocol suite: CLAUDE.md, STATUS.md, BRAND.md, BRIEF.md, FUNDAMENTALS.md, DESIGN.md, DISCOVERIES.md, docs/INDEX.md, .gitignore
