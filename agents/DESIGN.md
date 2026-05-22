---
version: alpha
name: "Project Hub"
colors:
  bg: "#F7F8FA"
  surface: "#FFFFFF"
  surface-2: "#EDF2F4"
  text: "#17202A"
  text-muted: "#5F6B76"
  border: "#D8DEE6"
  primary: "#087E8B"
  primary-hover: "#066875"
  success: "#176E49"
  warning: "#875700"
  error: "#C43D3D"
typography:
  display:
    fontFamily: "SF Pro Display"
    fontSize: "24px"
    fontWeight: "700"
  heading:
    fontFamily: "SF Pro Text"
    fontSize: "15px"
    fontWeight: "700"
  body:
    fontFamily: "SF Pro Text"
    fontSize: "13px"
    fontWeight: "400"
    lineHeight: "1.45"
  small:
    fontFamily: "SF Pro Text"
    fontSize: "11px"
    fontWeight: "500"
spacing:
  base: "4px"
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  xxl: "32px"
rounded:
  sm: "6px"
  md: "8px"
  lg: "12px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.surface}"
    rounded: "{rounded.sm}"
    padding: "{spacing.md}"
  button-primary-hover:
    backgroundColor: "{colors.primary-hover}"
    textColor: "{colors.surface}"
    rounded: "{rounded.sm}"
  button-secondary:
    backgroundColor: "transparent"
    textColor: "{colors.text}"
    rounded: "{rounded.sm}"
    padding: "{spacing.md}"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.sm}"
  separator:
    backgroundColor: "{colors.border}"
    textColor: "{colors.text}"
  card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.md}"
  window-background:
    backgroundColor: "{colors.bg}"
    textColor: "{colors.text}"
  elevated-row:
    backgroundColor: "{colors.surface-2}"
    textColor: "{colors.text}"
    rounded: "{rounded.md}"
  metadata:
    backgroundColor: "transparent"
    textColor: "{colors.text-muted}"
  status-success:
    backgroundColor: "{colors.success}"
    textColor: "{colors.surface}"
    rounded: "{rounded.sm}"
  status-warning:
    backgroundColor: "{colors.warning}"
    textColor: "{colors.surface}"
    rounded: "{rounded.sm}"
  status-error:
    backgroundColor: "{colors.error}"
    textColor: "{colors.surface}"
    rounded: "{rounded.sm}"
---

# DESIGN.md — Project Hub

> The brand layer. Specifies WHICH colors, fonts, and sizes this project uses.
> Universal craft rules live in `FUNDAMENTALS.md`.
> Read both before any UI work.

---

## Overview

Project Hub should feel like a native Mac utility: compact, calm, precise, and built for repeated operational use. The visual system should favor AppKit-native controls, modest graphite surfaces, restrained teal accents, and dense but readable information. It should not feel like a SaaS landing page or a decorative AI dashboard.

---

## Colors

### Roles

| Token | Where it appears | Notes |
|-------|------------------|-------|
| `--bg` | Window and popover backgrounds | Slightly warm macOS utility neutral |
| `--surface` | Cards, sheets, list rows | Clean foreground plane |
| `--surface-2` | Hover, selected-neutral, grouped panels | Subtle separation |
| `--text` | Main copy | High contrast |
| `--text-muted` | Labels, metadata, secondary details | Still readable at compact sizes |
| `--border` | Hairlines, separators, grouped rows | Keep light, never chunky |
| `--primary` | Selected state, primary action, active tool emphasis | Max 2 visible uses per screen |
| `--primary-hover` | Hover or pressed primary state | Derived darker teal |
| `--success` `--warning` `--error` | Status only | Never use as decoration |

### Swift Mapping

- `bg`: `NSColor.windowBackgroundColor` or tokenized equivalent for full surfaces.
- `surface`: `NSColor.controlBackgroundColor` / `NSColor.textBackgroundColor` depending on context.
- `border`: `NSColor.separatorColor` with low opacity.
- `primary`: app accent for active tabs, CTAs, and selected project/tool affordances.

### Accent Discipline

- At most 2 visible uses of primary per screen.
- Keep status colors semantic: detected/working, warning/manual action, destructive/error.
- Avoid decorative gradients except the existing compact header treatment; if expanded, document the exception first.

---

## Typography

Use SF Pro system typography. Compact operational panels use 11-15 px type with clear weight shifts rather than oversized headings. Monospaced text is allowed for file paths, config snippets, diffs, and tool identifiers only.

### Letter Spacing

| Context | Letter-spacing |
|---|---|
| Body 13-15 px | `0` |
| Small labels 10-12 px | `0.01em` to `0.02em` |
| UI labels and button text | `0.02em` |
| ALL CAPS | `0.06em` to `0.1em` |
| Headings 20 px+ | `0` |

### Pairing

Use SF Pro Text and SF Pro Display. Do not introduce a custom display font unless the whole Mac utility identity changes.

---

## Layout

4 px base. Scale: 4, 8, 12, 16, 24, 32, 48, 64. For compact popover work, prefer 8/12/16 spacing and avoid loose marketing-page rhythm.

---

## Elevation & Depth

| Token | Use |
|-------|-----|
| `--shadow-sm` | Subtle card or popover separation |
| `--shadow-md` | Floating sheets, menus, dashboard panels |

Prefer native macOS elevation and separators over heavy custom shadows.

---

## Shapes

| Token | Use |
|-------|-----|
| `--radius-sm` | Buttons, inputs, small chips |
| `--radius-md` | Cards, list rows, grouped panels |
| `--radius-lg` | Sheets, dialogs, larger panels |

No pill-shaped text buttons unless the control is a native chip, token, or status capsule.

---

## Components

- [x] Button
- [x] Card / grouped panel
- [x] Dialog / Modal / Sheet
- [x] Dropdown / Menu
- [x] Table/list rows
- [x] Tabs
- [x] Badge / status capsule
- [x] Text editor / monospaced config block
- [ ] Toast / transient feedback
- [ ] Tooltip standardization

New controls should extend existing SwiftUI view patterns in `Sources/ProjectHub/Views/` before creating a second visual language.

---

## Do's and Don'ts

Hard constraints. Any of these in a diff = stop and reconsider.

- Do use the primary color only for the most important selected state or action on a screen.
- Do use SF Symbols for icons.
- Do keep panels compact, scannable, and native to macOS.
- Do make read-only, writable, unsupported, and manual-action states visually distinct.
- Don't use indigo / violet hex codes (`#6366f1`, `#4f46e5`, `#7c3aed`, `#a855f7`).
- Don't use two-stop "trust" gradients on hero-like surfaces.
- Don't use emoji-as-icons inside buttons, headings, or feature lists.
- Don't use rounded cards with colored left-border accents.
- Don't invent metrics.
- Don't ship `lorem ipsum`, "feature one / two / three", or placeholder copy.
- Don't perform hidden destructive writes. Any config write needs preview, backup, or explicit reversibility.
- Don't create full-screen marketing composition for the app's primary surfaces.
- Don't blur read/write boundaries. A disabled or unsupported write path must say why.

---

## Extension Protocol

When a UI task needs a value that is not in this file:

1. Stop. Do not improvise a raw hex or arbitrary spacing value.
2. Propose the new token, related existing token, and reason.
3. Wait for explicit user confirmation.
4. Add the token here and in the Swift implementation point that consumes it.
5. Then use it.

The `design-check` skill enforces this on UI tasks.

---

## Agent Prompt Guide

When asked to design any Project Hub surface:

- Read this file first, then `FUNDAMENTALS.md`.
- Keep it dense, native, and operational.
- Use SF Symbols, not emoji, for icons.
- Reuse current view patterns before adding a new component.
- Surface any read/write safety ambiguity before writing code.
