# DESIGN.md — Project Hub

> Replaces the previous HIG-only version. Project Hub is a native SwiftUI + AppKit app
> with its own visual identity: dark-first, dense, keyboard-forward. It follows macOS
> **behaviour** (windowing, menus, focus, keyboard, accessibility) while owning its own
> **surface** (colour, type, spacing, chrome).
>
> Reference mock: `Project Hub Redesign.dc.html` — screen 2a is Projects, 3a–3h are the rest.
> Source of truth: Claude Design project `181de825-496c-4e69-a6b6-91ad20cb8f6a`.

---

## 1. Principles

1. **The sidebar says what it is for.** Destinations are grouped by intent, and each group
   carries a one-line caption. A user should never have to click a tab to learn what it does.
2. **Problems come to you.** Anything broken surfaces above the list it belongs to, with the
   fix attached to the line. Never make a colour on a row the only signal.
3. **Colour carries identity, not decoration.** One accent owns every action and selection.
   Brand colour is spent only on the provider tile. Green and red only ever mean health.
4. **Monospace is for machine text.** Paths, commands, counts, keys, config filenames.
   Never for prose.
5. **Density over emptiness.** Rows, not cards, for anything you scan. Cards only where an
   item genuinely needs its own object boundary (provider, plugin, usage quota).

---

## 2. Colour

Dark is the designed appearance. Light mode is derived (§2.5), not separately designed.
All tokens live in `HubTheme.swift`.

### 2.1 Neutrals

| Token | Hex | Use |
|---|---|---|
| `bg` | `#0A0B0C` | Window background, content pane |
| `panelBg` | `#0D0E10` | Sidebar, inspector, table headers, footers |
| `raised` | `#0F1113` | Cards, grouped rows, metric tiles |
| `field` | `#131416` | Search fields, inputs |
| `line` | `#1C1E21` | Structural borders, pane dividers |
| `hairline` | `#17191C` | Row separators inside a list |
| `stroke` | `#23262A` | Secondary button borders |
| `text` | `#E6E7E9` | Body |
| `textStrong` | `#F2F3F5` | Titles, selected row label |
| `textMid` | `#9AA0A8` | Inactive nav labels, secondary body |
| `textDim` | `#7A8089` | Captions, counts |
| `textFaint` | `#5E636B` | Footer hints, placeholder, absent values |

Minimum contrast: **4.5:1** for anything under 14px, **3:1** for 14px and above. `#5E636B`
on `#0A0B0C` is the floor and is reserved for genuinely tertiary text (keyboard hints, em
dashes for absent values). Do not go below it.

### 2.2 Accent

| Token | Hex | Use |
|---|---|---|
| `accent` | `#FF7A29` | Primary buttons, selected nav, selection bar, links, key numbers |
| `onAccent` | `#17100A` | Text and glyphs on an accent fill |
| `accentBg` | `#1C1309` | Selected nav row, accent-tinted callout |
| `accentBorder` | `#3D2412` | Border on accent-tinted surfaces |
| `accentText` | `#C9A98E` | Body text inside an accent-tinted callout |

One accent element per region. If two things on screen are orange, one of them is wrong.

### 2.3 Status

| Token | Hex | Meaning |
|---|---|---|
| `ok` | `#5FC98A` | Healthy, in sync, working |
| `warn` | `#E0A44B` | Worth a look, no data loss |
| `bad` | `#F2565B` | Failing, auth expired, missing on disk |
| `badBg` / `badBorder` | `#120D0E` / `#3E1D21` | Attention strips and danger cards |
| `warnBg` | `#2B1418` | Count badge in the rail |

Status colour appears as a 6pt dot plus a word. Never a dot alone — colour is not the label.
Use `StatusLabel`, not a bare `StatusDot`, anywhere state is communicated.

### 2.4 Provider brand colour

Brand colour is **confined to the provider tile**. The row, its text, its badges and its
buttons stay neutral. This is what lets ten providers sit on one screen without noise.

Values live in `ToolPalette.brands`. Tile foreground is the brand colour lifted for contrast
on dark; tile background is the same hue at very low lightness.

| Provider | id | Mark | Tile fg | Tile bg |
|---|---|---|---|---|
| Claude Code | `claude-code` | CC | `#D06A6A` | `#2A1616` |
| Codex | `codex` | Cx | `#4FD187` | `#12251A` |
| Cursor | `cursor` | Cu | `#A985F8` | `#1E1830` |
| VS Code | `vscode` | VS | `#4A9BEA` | `#10202F` |
| Zed | `zed` | Ze | `#A96BF0` | `#1E1630` |
| opencode | `opencode` | Oc | `#EFA84D` | `#2A1F10` |
| Antigravity | `antigravity` | Ag | `#7CA0F8` | `#161E30` |
| Pi | `pi` | Pi | `#4FA8CC` | `#10222A` |
| Command Code | `command-code` | Cm | `#EE8055` | `#2A1A12` |
| Grok CLI | `grok` | Gk | `#B8C2D6` | `#1D2029` |

### 2.5 Light mode

Derive, do not redesign. Invert the neutral ramp, keep `accent` and the status hues
unchanged, and darken each tile foreground to hold 4.5:1 on a light tile background.
Dark is the reference; if the two disagree, dark wins.

---

## 3. The provider tile

The single most repeated component in the app. **Wherever a provider is named, its tile
precedes the name.** Rows, inspectors, MCP groups, skill availability, settings paths,
usage cards, findings. Implemented as `ProviderTile` in `Views/HubComponents.swift`.

- **Real logo first.** `ToolPalette.appImage(for:)` reads `CFBundleIconFile` from the
  installed `.app`. That image fills the tile.
- **Monogram fallback** when the app is not installed or has no readable icon. Two
  characters, from `ToolPalette.mark(for:)`.
- **Never** an SF Symbol in the tile. Symbols were the old identity; they read as generic.
- Sizes: **17pt** inline in rows and lists, **28pt** on provider and usage cards. No others.

`ToolPalette` provides `mark(for:)`, `label(for:)`, `tileForeground(for:)`,
`tileBackground(for:)`. The existing `icon(for:)` SF Symbol map stays only for menu items
and toolbar affordances, never for identity.

---

## 4. Type

Two families, resolved by `HubFont`. IBM Plex when installed, system faces otherwise —
the fallback is acceptable, not an error.

| Role | Font | Fallback |
|---|---|---|
| UI | IBM Plex Sans | `.system(design: .default)` |
| Machine text | IBM Plex Mono | `.system(design: .monospaced)` |

### Scale

| Role | Size | Weight | Family |
|---|---|---|---|
| Window title / page title | 13 | semibold | sans |
| Section title in content | 13 | semibold | sans |
| Row primary (selected) | 13 | semibold | sans |
| Row primary | 13 | medium | sans |
| Nav item | 13 | regular / medium when selected | sans |
| Body, descriptions | 12.5 | regular | sans |
| Secondary body, captions | 12 | regular | sans |
| Row caption, helper | 11.5 | regular | sans |
| Sidebar group caption | 11 | regular | sans |
| Path, command, count, key | 10–11 | regular | mono |
| Group heading | 9 | semibold, `.kerning(1.1)`, uppercase | mono |
| Provider monogram | 8–9 | bold | mono |
| Big number (metric tile) | 26 | regular | mono |
| Big number (inspector) | 20 | regular | mono |

Numbers are **always monospaced**, including counts in the rail. Never let a count reflow
when it ticks from 9 to 10.

---

## 5. Layout

### 5.1 Window shell

```
┌────────────┬─────────────────────────────┬──────────────┐
│ rail 232   │ content                     │ inspector    │
│            ├─────────────────────────────┤ 328–340      │
│            │ toolbar 44                  │              │
│            │ …                           │              │
│            │ footer 28                   │              │
└────────────┴─────────────────────────────┴──────────────┘
```

- Minimum window: **1100 × 720**. Design target: **1240 × 820**.
- Rail: fixed **232pt**, not resizable.
- Inspector: **328pt** on Projects, **340pt** elsewhere; collapsible, remembers state.
- Toolbar row: **44pt**, `panelBg`, bottom `line` — `HubPageHeader`.
- Footer hint bar: **28pt**, `panelBg`, top `line`, mono 10, `textFaint` — `FooterHintBar`.

### 5.2 Spacing

8pt grid, with 4pt allowed for inline gaps.

| Context | Value |
|---|---|
| Content pane padding | 16pt horizontal, 16pt top |
| Card padding | 14–16pt |
| Row padding | 11–12pt vertical, 16pt horizontal |
| Inline gap between related elements | 8–12pt |
| Gap between grouped controls | 6–8pt |
| Section heading to first row | 8pt |
| Between sections | 18–20pt |

### 5.3 Radii

| Element | Radius |
|---|---|
| Window | 12 |
| Card, panel, table container | 9–10 |
| Button, field, nav row | 6–7 |
| Provider tile | 4 (17pt) / 6 (28pt) |
| Count badge | capsule |

### 5.4 Row heights

- List row: **44–48pt** (two lines: name + path/caption).
- Table row: **44pt**. Table header: **32–38pt**.
- Nav row: **32pt**.
- Toolbar button: **26pt**. Primary button: **26–28pt**.

Minimum hit target 26pt; anything smaller gets an expanded `.contentShape` (`hubHitTarget`).

---

## 6. Navigation

Eight flat tabs became three captioned groups. **Same destinations, reordered by intent.**

```
WORKSPACE          The folders you work in
  Projects                             12

CAPABILITIES       What your agents can do
  Skills                               38
  Plugins                               6
  MCP servers                          21
  Providers                            10

HEALTH             Is anything wrong, and what it costs
  Checks                                2   ← badge, bad-tinted when > 0
  Usage                                62%

─────────────────────────────────────────
  Settings
```

- `Compat` is renamed **Checks**. The old name described the scan; the new one describes
  the question the user is asking.
- Group heading: mono 9 semibold uppercase, `#868C95`. Caption: sans 11, `#7A8089`.
  **These captions are the point of the redesign — do not dim them further.**
- Selected row: `accentBg` fill, `accent` label, **2pt inset leading bar** in `accent`.
- Every nav row carries a trailing count in mono 10. `Checks` carries a capsule badge in
  `warnBg`/`bad` when non-zero, and a plain count when zero.
- Search field sits above the first group. `⌘K` opens command search over projects, skills,
  servers and providers.

### Project detail

Breadcrumb back to Projects in the toolbar, seven sections in a 186pt sub-rail:
**Health · Skills · Agents · MCP servers · Hooks · Instructions · Rules**. `Health` is the
landing section and answers "is this folder set up correctly" before offering anything to edit.

---

## 7. Components

All shared components live in `Views/HubComponents.swift`.

### 7.1 Attention strip — `AttentionStrip`

Above the list it concerns, not inside it. Container `badBg` on `badBorder`, radius 9.
Header line: 6pt `bad` dot, "N things need you" in `bad` semibold 12, and a mono hint on the
right explaining that the fix does not require leaving the page.

Each item: title 12.5 with the subject in semibold, a mono 10 evidence line
(`textDim`), then a dismissive secondary action and one **accent primary action**.

Rule: **an attention item without an inline action does not belong in the strip.** Put it
in Checks instead.

### 7.2 List row — `HubListRow`

```
● name  [tile][tile][tile]              7 skl  4 mcp  2 agt
  ~/dev/projecthub · 12 min ago
```

- 6pt status dot, flush left.
- Name 13. Provider tiles inline, 17pt, 5pt gaps.
- Mono 10 second line: path, then `·`, then relative time.
- Right side: mono 10 counts, or — on hover/selection — inline actions as mono 10 pills
  with a `stroke` border. Counts and actions occupy the same slot; actions replace counts.
- Selected: `#0F1413` fill plus 2pt inset `accent` leading bar.
- Missing on disk: `opacity 0.55`, grey dot, no counts.

### 7.3 Data table — `HubTableHeader` + `HubTableColumn`

Header row `panelBg`, mono 9 semibold uppercase `#6B7078`, fixed column widths, sortable
column marked with `↓`. Body rows 44pt separated by `hairline` (`HubRowSeparator`). Numeric
columns right-aligned and monospaced. Absent value is `AbsentValue` — an em dash in
`#5C5750`, never blank, never zero.

### 7.4 Section heading — `HubSectionHeading`

Mono 9 semibold uppercase `#868C95`, count in mono 9 `#5E636B`, then a 1px `hairline` rule
filling the remaining width, then an optional accent action on the right ("track all").

### 7.5 Buttons — `HubButton`, `HubIconButton`

| Kind | Fill | Text | Border |
|---|---|---|---|
| `.primary` | `accent` | `onAccent`, 12 semibold | none |
| `.secondary` | none | `#C9CDD3`, 12 | `stroke` |
| `.inlineAction` | none | `#C9CDD3`, mono 10 | `stroke` |
| `.accentInline` ("track", "install") | none | `accent`, mono 10 | `accentBorder` |
| `.destructive` | none | `bad`, 12 | `badBorder` |

One primary per toolbar. One primary per attention item. Never two side by side.

### 7.6 Metric tile — `MetricTile`

`raised` on `line`, radius 9, 14×16 padding. Mono 26 number, sans 12 `textMid` label beneath.
Number takes `accent` only when it is the count of actionable things; `ok`/`bad` when it is a
health count; otherwise plain `text`.

### 7.7 Quota bar — `QuotaBar`

Label 11.5 `textMid`, right-aligned mono 11.5 percentage in the threshold colour, mono 10.5
reset note. Track 5pt `line`, fill in threshold colour. Thresholds: `< 70` ok, `70–89` warn,
`≥ 90` bad. **Quota before cost, always** — cost is a mono 11 note in the card header.

### 7.8 Toggle — `HubToggle`

34 × 19 capsule. On: `accent` track, `onAccent` knob. Off: `stroke` track, `textFaint` knob.

---

## 9. Keyboard

Every list is arrow-navigable and every screen shows its keys in the footer bar. Footer
hints are declared per destination on `HubDestination.footerHints`.

| Key | Action |
|---|---|
| `⌘K` | Command search |
| `↑` `↓` | Move selection |
| `⏎` | Open / drill in |
| `T` | Track discovered project |
| `I` | Install skill or plugin |
| `E` | Edit |
| `V` | Verify MCP server |
| `F` / `D` | Fix finding / preview diff |
| `⌘R` | Rescan |
| `⌘1`–`⌘7` | Project detail sections |
| `⌘⌫` | Remove |

---

## 10. Motion

Restrained. Motion confirms an action; it never announces one.

- Selection and hover: **120ms** ease-out on background only (`HubTheme.selectionAnimation`).
- Section expand/collapse: **180ms** ease-in-out (`HubTheme.disclosureAnimation`).
- Refresh spinner: 0.8s linear repeat, `accent` while scanning.
- Beacon usage ring: 0.5s ease-out on value change.
- No spring on navigation. No cross-fade between tabs. No animated numbers.

---

## 11. Live Mode

Unchanged in behaviour; retuned to this palette.

- Beacon body `panelBg`, 48pt, drop shadow `black 0.6 / r6 / y3`.
- Usage ring: same ok → warn → bad ramp as §2.3, 3.5pt round cap.
- Frontmost-app glow keeps its cyan pulse — it is the one place cyan appears, and it means
  "Claude Code has focus", not a brand.
- Panel background `panelBg`, `line` border, same rail typography.

---

## 12. Do and do not

**Do**

- Put a provider tile beside every provider name.
- Give every group of destinations a caption.
- Give every failing thing an inline fix, or move it to Checks.
- Right-align and monospace every number.
- Show the keyboard shortcut in the footer of every screen.

**Do not**

- Do not use gradient fills. `ContentView.headerGrad` is removed.
- Do not tint a row, badge, or button with a provider's brand colour. Tile only.
- Do not use an SF Symbol as a provider's identity.
- Do not use more than one accent element per region.
- Do not use a colour as the only carrier of meaning — pair every dot with a word.
- Do not introduce a fourth status colour.
- Do not add a card where a row would do.

---

## 13. Files this affects

| File | Change |
|---|---|
| `HubTheme.swift` | Token set (§2), type scale (§4), metrics (§5), motion (§10) |
| `ToolPalette.swift` | `brands`, `mark`, `label`, `tileForeground`, `tileBackground`; keeps `appImage` |
| `Views/HubComponents.swift` | New. Every shared component in §7, plus `ProviderTile` (§3) |
| `Views/ContentView.swift` | Grouped captioned rail (§6); `headerGrad`, `tabBar`, `statPill` deleted |
| `Views/ProjectsView.swift` | Attention strip, new row (§7.2), action-led inspector, `ProjectFacts` |
| `Views/ProjectDetailView.swift` | Seven-section sub-rail, Health landing with the provider table |
| `Views/ProvidersView.swift` | 28pt tile cards, installed / not installed split |
| `Views/SkillsView.swift` | Library rows with provider-visibility tiles |
| `Views/PluginsView.swift` | Bundles grouped by provider, components listed before install |
| `Views/GlobalMCPView.swift` | Grouped by provider, health strip, inline sign-in |
| `Views/CompatibilityView.swift` | Renamed Checks; metric tiles, next-step card, findings with fixes |
| `Views/UsageView.swift` | Quota-first cards, metered section, other-providers list |
| `Views/SettingsView.swift` | Grouped cards; skill paths and provider homes carry tiles |
| `LiveMode/BeaconView.swift` | Palette + three-colour usage ramp (§11) |
