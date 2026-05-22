# FUNDAMENTALS.md — Craft Rules
> Global. Read before any UI work. Same content on every project.
> Brand-specific values (which colors, which fonts) live in `DESIGN.md`.
> This file is the craft layer: universal rules that apply regardless of brand.

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

```css
/* WRONG — hardcoded, invisible to your design system */
background: #1a1a1a;
border-radius: 12px;

/* CORRECT — named, inheritable, changeable in one place */
background: var(--surface);
border-radius: var(--radius-md);
```

When you see a component you want to add:
1. Does it use CSS variables or hardcoded values?
2. If CSS variables → import it, it inherits your tokens automatically. Nothing to do.
3. If hardcoded → find the 2–3 hardcoded values, replace with your tokens. Five minutes.

### The 3 types of "different" (when reusing a component)

- **Type 1 — Token difference**: component uses tokens, your values differ → your tokens override automatically. Nothing to do.
- **Type 2 — Missing token**: gradient, glow, or value the component needs that isn't in `DESIGN.md`. **STOP. Propose the new token to the user. Wait for explicit confirmation. Then add it to `DESIGN.md` AND `global.css` (or `DesignTokens.swift`). Do not improvise.**
- **Type 3 — Structural intention**: sharp corners vs rounded, dense vs spacious — decide once. Either update your whole token, or document as a named exception with a reason.

---

## The 7 Cardinal Sins (auto-stop)

These are the AI-slop tells. Each is a hard fail — flag in the diff, ask the user, fix before declaring done.

1. **Default Tailwind indigo as accent** — `#6366f1`, `#4f46e5`, `#4338ca`, `#3730a3`, `#8b5cf6`, `#7c3aed`, `#a855f7`. The brand's `DESIGN.md` provides `--primary`; use it. Indigo is the textbook AI tell.
2. **Two-stop "trust" gradient on the hero** — purple→blue, blue→cyan, indigo→pink. A flat surface + intentional type beats it every time.
3. **Emoji as feature icons** — `✨ 🚀 🎯 ⚡ 🔥 💡` inside `<h*>`, `<button>`, `<li>`, or `class*="icon"`. Use 1.6–1.8 px-stroke monoline SVG with `currentColor`.
4. **Sans-serif on display when the brand binds a serif** (or vice versa). Headings must use the display font from `DESIGN.md`, not a hardcoded `Inter` / `Roboto` / `system-ui`.
5. **Rounded card with a colored left-border accent** — the canonical "AI dashboard tile" shape. Drop either the radius or the left border.
6. **Invented metrics** — "10× faster", "99.9% uptime", "3× more productive". Either pull from a real source or use a labelled placeholder.
7. **Filler copy** — `lorem ipsum`, `feature one / two / three`, `placeholder text`, `sample content`. An empty section is a composition problem to solve, not a hole to fill with invented words.

---

## The 5 Required States

Every interactive surface — list, table, card, form, panel, search, dashboard — must render all five. Missing states are the loudest "AI-built UI" signal there is.

| State | Triggered when | Must contain |
|---|---|---|
| **Loading** | Data is in flight | Skeleton, spinner, or shell — plus a 15s "taking longer than expected" fallback |
| **Empty** | No records yet, or query returned nothing | Headline, plain explanation, primary CTA |
| **Error** | Fetch failed, server failure, validation rejection | Plain-language cause, recovery action, preserved user input |
| **Populated** | Data present, primary case | The state the design was actually drawn for |
| **Edge** | Extreme volume, long strings, missing optional fields, RTL or long-word content, partial network | Layout that does not break |

### Loading thresholds

Pick the indicator by expected duration, not by what's in the component library.

| Duration | Indicator |
|---|---|
| 0–300 ms | None. Render synchronously; users perceive no delay. |
| 300 ms – 2 s | Subtle spinner or skeleton. |
| 2 – 10 s | Skeleton matched to expected layout, or labelled spinner ("Loading…"). |
| 10 – 30 s | Determinate progress bar with cancel option. |
| 30 – 60 s | Progress bar with explicit cancel affordance. |
| 60 s+ | Stop animation. Show error with retry, cancel, or continue. |

Never leave a spinner running indefinitely. Start a timeout on every request.

### Error composition

Every error must answer three questions, in order:
1. **What happened** — "Your card was declined." Not "Something went wrong."
2. **Why, if knowable** — "Insufficient funds." Or "Network unreachable — check your connection."
3. **What the user can do** — A retry button, an alternative path, or a support link.

Preserve user input across the error. Never clear a form on submit failure.

### Empty state composition

Empty is not the absence of state. It is its own state with a job.
- **First-use empty** — illustration + headline + value sentence + primary CTA. The empty is the onboarding moment.
- **No-results empty** — echo the query, suggest alternatives, never a true blank.
- **Cleared empty** — celebratory phrasing, optional next action.
- **Error-as-empty** — never. An error is its own state.

---

## Craft Details

The implementation rules that separate "works" from "feels right." Most AI-generated UI misses these.

### Focus

- Use `:focus-visible`, not `:focus`. Keyboard-only ring, no ring on mouse click.
- **Never** bare `outline: none` without a replacement. That's a triple WCAG failure (1.4.11, 2.4.7, 2.4.13).
- Use `:focus-within` on compound controls (search input + icon, etc.) so the parent highlights when any child gets focus.

### Forms

- Correct `type`, `inputmode`, and `autocomplete` on every input. Mobile keyboards depend on it; password managers depend on it.
- Labels always. Never placeholder-as-label — placeholder disappears on input.
- Never block paste (`onPaste preventDefault`). Hostile and an accessibility violation.
- Validate on **blur**, not on first keystroke. After invalid, switch to re-validate on `input` so the error clears the moment input becomes valid.
- Preserve user input on error. Never clear a form on submit failure.
- Disable spellcheck on emails, codes, usernames, URLs: `spellcheck="false"`.

### Images

- Always set `width` and `height` — prevents cumulative layout shift.
- Above the fold: `fetchpriority="high"`. Below the fold: `loading="lazy"`.
- Meaningful images need `alt`. Decorative: `alt=""` or `aria-hidden="true"`.

### Touch and mobile

- AA touch target floor: **24×24 CSS px**. AAA / native expected: 44×44 (iOS) or 48×48 (Material).
- `touch-action: manipulation` removes the 300 ms tap delay.
- `overscroll-behavior: contain` on modals and drawers prevents scroll chaining.
- Avoid `autoFocus` on mobile — it opens the keyboard unexpectedly.

### Semantic HTML

- `<button>` for actions. `<a href>` for navigation. Never `<div onClick>` for either.
- One `<h1>` per page. Don't skip heading levels (`h1` → `h3` without `h2`).
- `<header>`, `<nav>`, `<main>`, `<aside>`, `<footer>` over `<div role="banner">`.
- Toast / status: `role="status" aria-live="polite"`. Critical error: `role="alert"`.

### URLs reflect state

- Filters, tabs, sort, pagination belong in the URL. Users expect to bookmark and share.
- Use proper `<Link>` / `<a href>` so Cmd-click and middle-click work.

### Performance

- Lists with 50+ items: virtualize (`virtua`, `react-window`) or `content-visibility: auto`.
- Avoid layout reads in render (`offsetHeight`, `getBoundingClientRect`) — use `ResizeObserver`.
- Preconnect to asset CDNs; preload critical fonts.
- No `transition: all` — performance killer and unpredictable.

### Loading-state timing (avoid flicker)

When you show a spinner or skeleton:

- **Show-delay 150–300 ms** — don't render the indicator instantly. If the request finishes in under 150 ms the user perceives no delay; rendering a spinner that flashes for 80 ms feels worse than no spinner.
- **Minimum visible window 300–500 ms** — once shown, the indicator must stay visible for at least 300 ms even if the request resolves immediately after. A spinner that appears and disappears in one frame reads as a layout glitch.
- React `<Suspense>` does this for you automatically. For other frameworks, gate the indicator with a timeout.

### Stable skeletons

Skeletons must mirror the final layout exactly — same element count, same approximate sizes, same grid positions. A skeleton that looks nothing like the final content causes layout shift on resolve, which feels like a hydration bug even when it isn't.

### Loading buttons preserve the label

A button in loading state shows an indicator AND keeps the original label. "Save" becomes "Save…" with a spinner — never replaced by just a spinner. Users need the label to remember which action is in flight.

### Tooltip timing

- First tooltip in a group has a delay (~500 ms hover) — prevents accidental tooltip storms.
- Subsequent peers in the same group have **no delay** — once the user has invoked one tooltip, they're committed to reading.
- Tooltips never fire on touch.

---

## Typography craft (small but visible)

These are the details that separate a polished UI from one that feels off without the user being able to say why.

### Use the ellipsis character

`…` (U+2026), not three periods `...`. Applies to:

- Menu items that open follow-ups: "Rename…", "Move to…"
- Loading / processing states: "Loading…", "Saving…", "Generating…"
- Placeholders ending in ellipsis: "Search projects…"

Three periods reads as casual typing; the ellipsis character reads as designed.

### Curly quotes, not straight quotes

`"like this"` and `'like this'`, not `"like this"` and `'like this'`. Straight quotes are a code-editor habit, not a typography choice.

### Non-breaking spaces for glued terms

Units and product names should never line-break in the middle:

- `10&nbsp;MB`, not `10 MB`
- `⌘&nbsp;+&nbsp;K`, not `⌘ + K`
- `Vercel&nbsp;SDK`, not `Vercel SDK`
- `Next.js&nbsp;16`, not `Next.js 16`

Use `&#x2060;` (word joiner) when you want zero-width glue — useful inside code identifiers.

### Anchored headings

Section headings that get deep-linked need `scroll-margin-top` equal to your fixed-header height — otherwise the anchor lands with the heading hidden behind the header.

```css
h2[id], h3[id], h4[id] { scroll-margin-top: 80px; }
```

### Tabular numbers in tables

Already covered in "Tabular numbers for comparisons" — restating to confirm: `font-variant-numeric: tabular-nums` on any column of numerals that should align by digit position.

---

## Browser-chrome integration

Two one-liners that make a dark UI look intentional instead of patched together.

### `color-scheme` on `<html>`

```css
html { color-scheme: dark light; }
/* Or, for a dark-only product: */
html.dark { color-scheme: dark; }
```

This tells the browser to render its native UI (scrollbars, form-control internals, autofill backgrounds) in the matching scheme. Without it, dark themes get light-mode scrollbars and autofill highlights, which read as broken.

### `theme-color` meta

```html
<meta name="theme-color" content="#0a0a0a" media="(prefers-color-scheme: dark)">
<meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)">
```

Aligns the mobile browser's address bar and the OS task-switcher card with the page background. The difference between this set and not is the difference between "feels like a polished app" and "feels like a website".

---

## Banned Words

If a word can be removed without changing meaning, it's dead. Replace with facts, numbers, scenarios, real outputs.

**Hype:** revolutionary, seamless, cutting-edge, best-in-class, next-generation, world-class, game-changing, disruptive, robust, state-of-the-art, groundbreaking, supercharge, elevate, unlock (metaphorical), harness, empower.

**Filler:** very, really, just, actually, basically, literally, simply, easily, highly, incredibly, extremely, absolutely.

**Corporate zombie:** leverage, synergy, ecosystem, paradigm, holistic, end-to-end, mission-critical, value proposition, stakeholder, thought leader, optimize (in marketing), streamline (without specifics).

**AI-slop openers:** "In today's fast-paced world...", "In an era of...", "Look no further", "Say goodbye to...", "Introducing the future of...", "Reimagine...", "Take your X to the next level", "Harness the power of...".

---

## Icon Discipline

- Treat icons as typography, not decoration. Functional, not ornamental.
- One library per product. No mixing Lucide + Heroicons + Phosphor.
- Default fill: `currentColor` so icons inherit text color and sync with themes automatically.
- Meaningful icons need **3:1 contrast** (WCAG non-text).
- Icon buttons need `aria-label` and a hit area of at least 44×44 CSS px on touch (32×32 on desktop is OK if the visual is smaller).
- Product UI: clean outline OR solid, **one** consistent set. Never duotone / gradient inside product UI; reserve those for marketing.

---

## Copy Rules

- Active voice. "Install the CLI" not "The CLI will be installed."
- Specific labels. "Save API key" not "Continue". "Create project" not "OK".
- Error messages include the fix. "Email must include @ and a domain" not "Invalid input".
- Numerals for counts. "8 deployments" not "eight."
- Second person. "Your account" not "My account."
- Empty states teach: "Projects will appear here. Create your first one." Not "No data."

---

## Quality Questions (ask before finishing any UI work)

1. **Does this decoration earn its place?** Is it rare enough to have impact? (90% plain / 10% decoration.)
2. **Is the visual hierarchy immediately clear?** Can someone tell in 2 seconds what's most important?
3. **Are all 5 required states present** for every interactive surface?
4. **Did I commit any of the 7 cardinal sins?**
5. **Did I improvise a token instead of stopping to propose it?**

If any answer is "no" or "yes I did" — fix the foundation before adding more.

---

## Pre-Ship Checklist (the audit-before-close skill runs this)

- [ ] No raw hex / px / font-family in component files — everything via tokens.
- [ ] No cardinal-sin patterns (indigo accent, two-stop gradients, emoji icons, hardcoded display font, AI-dashboard tile shape, invented metrics, filler copy).
- [ ] All 5 states rendered for every interactive surface.
- [ ] Focus rings present and visible (`:focus-visible`, never bare `outline: none`).
- [ ] Forms: labels, `autocomplete`, `type`, `inputmode` all set. Validation on blur, not keystroke. Paste not blocked.
- [ ] Images: `width` and `height` set, meaningful images have `alt`.
- [ ] Touch targets ≥ 24×24 CSS px (44×44 on touch for primary actions).
- [ ] Semantic HTML — no `<div onClick>` for what should be `<button>` or `<a>`.
- [ ] No banned words in shipped copy.
- [ ] One icon library, all icons use `currentColor`.
- [ ] Heading hierarchy clean — one h1, no skipped levels.
- [ ] URL reflects state (filters, tabs, pagination).

If any item fails: stop, flag, fix. Don't ship.
