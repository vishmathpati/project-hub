# DESIGN.md

## Design Direction

Native macOS utility: compact, scannable, and operational. The app should make complex configuration feel inspectable rather than magical.

## Visual Rules

- Prefer dense lists, status badges, segmented controls, and preview panels.
- Use SF Symbols for actions and statuses.
- Keep card radius at 8px or below except existing app chrome where already established.
- Avoid decorative gradients beyond the existing header treatment.
- Text must fit inside compact menu-bar and expanded-window widths.

## Status Language

- Working
- Broken
- Needs auth
- Needs restart
- Disabled
- Unknown

## Core Workflow

1. Scan selected project and global tool state.
2. Explain findings with source file paths and affected app/scope.
3. Preview safe fixes.
4. Apply with backups.
5. Verify and show remaining manual actions.
