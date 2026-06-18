# FUNDAMENTALS.md — Design Principles
> Global. Read before any UI work. Same content on every project.

---

## The 6 Levels (in order of importance)

Build in this order. Do not skip levels.

### Level 1 — Space

Consistent spacing is more important than any color, gradient, or animation.
Use a scale based on multiples of 4px: 4, 8, 12, 16, 24, 32, 48, 64.
Never mix arbitrary values. Random gaps make UIs feel amateurish even when the colors are good.

### Level 2 — Hierarchy

Every screen must answer: what do I look at first? Second? Third?
Hierarchy is created through size, weight, and color contrast — nothing else.
If everything is the same visual weight, the eye has nowhere to go.

### Level 3 — Color Foundation

For dark UIs, you need at least 4 distinct dark values:
- Page background (darkest)
- Card background (slightly lighter)
- Elevated card / hover state (slightly lighter again)
- Border (just barely visible)

Do not use the same dark value everywhere. Depth comes from these separations.
Accent/brand color is separate from these foundation levels.

### Level 4 — Typography

One font family. Two weights (regular + medium, or medium + semibold).
Maximum 5 size steps. Consistent line-height throughout.
Typography problems make everything else look worse — fix them early.

### Level 5 — Depth and Elevation

Use shadows, borders, or background-lightness to show z-axis hierarchy:
background → cards → elevated cards → modals → tooltips.
Elements should feel like they exist on different layers, not a flat plane.

### Level 6 — Decoration (last, earned, rare)

Gradients, glows, animations, blur effects, grain textures.
Only add decoration after Levels 1–5 are solid.
Decoration amplifies whatever is underneath — good foundation + decoration = premium, weak foundation + decoration = noise.

---

## The Ratio Rule

90% of the screen should be plain. 10% can have decoration.
Decoration earns its impact by being rare. One gradient in a sea of plain = striking. Gradients everywhere = wallpaper.
Vercel, Linear, and every premium product follow this ratio intentionally. Their plain moments create contrast for the moments that aren't.

---

## Motion Principles

1. **Purpose-driven only** — animation informs, it does not decorate
2. **Ease-out** for entering elements (feels like they arrived from somewhere)
3. **Ease-in** for exiting elements (feels like they're leaving)
4. **150–300ms** for most interactions (faster = snappy, slower = sluggish)

---

## The Token Rule

Every visual value must have a name. No exceptions.

For SwiftUI: use `Color` extensions, `ShapeStyle` tokens, or `ViewModifier` wrappers instead of hardcoded values.

```swift
// WRONG — hardcoded, invisible to your design system
.background(Color(hex: "#1a1a1a"))
.cornerRadius(12)

// CORRECT — named, reusable
.background(Color.cardBackground)
.cornerRadius(DesignTokens.cardRadius)
```

---

## Quality Questions (ask before finishing any UI work)

1. **Does this decoration earn its place?** Is it rare enough to have impact?
2. **Is the visual hierarchy immediately clear?** Can someone tell in 2 seconds what's most important?

If either answer is no, fix the foundation before adding more.
