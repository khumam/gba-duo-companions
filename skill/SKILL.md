---
name: gbaduo-companion-pack-design
description: Use when creating, restyling or reviewing any GBADuo companion pack (manifest.json, layout.json, style.css, main.lua, assets) for a GBA/GBC game — choosing a visual style, building the screen layout, making it interactive (tap-to-detail, popups, equip, settings pills), adding Wide view / Ambient / markers through game.lua, fitting any screen size, or deciding where sprites and icons come from (shipped PNGs, the player's ROM at runtime via gfx.*, or art drawn in code). Distilled from the Pokémon, Zelda Minish Cap, Golden Sun and Mega Man Zero packs and the app's current engine docs.
---

# GBADuo Companion Pack Design

## Overview

A pack is a screen description for the Thor's second display (~538 × 468 dp, landscape).
`layout.json` is structure, `style.css` is look, `main.lua` reads game memory and returns
the values to show, `game.lua` (optional) improves the game's own picture (Wide view, Ambient
colour, HUD hiding), `assets/` holds fonts and images. This skill is the general method; it was
derived by reading the finished packs side by side and tracks the engine docs
(the GBA Duo app repo's `docs-packs/*.md`, the source of truth when they disagree).

**A good pack is attractive, interactive and alive**: it looks like the game's own menu, every tile
answers a tap, the numbers move, and the picture beside it can be widened and graded by the pack.
Aim for all three, not just a read-only stat sheet.

**Core principle: take the look from the game itself.** Every good pack copies one
screen of its game (FireRed's Bag window, Golden Sun's save list, Minish Cap's pause
menu) and rebuilds it in CSS. The sprites then come from the same source, so UI and art
agree. Generic "dark dashboard" packs read as foreign next to the game.

## Files in this skill (all one level, read as needed)

| File | Read it when |
|---|---|
| `pack-anatomy.md` | Starting a pack: folder layout, manifest, the Lua → layout contract, build pipeline, per-pack comparison |
| `sprites-and-assets.md` | Deciding where every image comes from and how to size/style it (the three strategies, CSS recipes, `gfx.*` API, fallbacks) |
| `visual-styles.md` | Picking or analysing a look: palettes, fonts, frames, nav, per-game style recipes |
| `layout-snippets.md` | Writing `layout.json`: skeleton, hero plaque, stat plaque, icon rows, owned/locked, settings pills, tap-to-popup |
| `interactive-and-game-script.md` | Making it interactive and alive: detail pages, popups, equip, reserved actions (WIDE / COLOR / permission), `game.lua` (`wide`, `ambient`, markers, HUD), memory writes, responsive CSS, limits, plus lessons from the Golden Sun and Emerald packs |
| `docs-site-and-simulator.md` | The public docs page map, the browser simulator vs `preview-pack.sh`, and details the docs state that are easy to miss (snapshot built-ins, sandbox, `values`, hardcore mode, version gates) |
| `docs/*.md` | A copy of the public GBA Duo docs, bundled in this skill: `first-pack`, `layout`, `styling`, `pages`, `lua`, `game-script`, `wide-view`, `settings`, `install`, `games`, `import-packs`, `index`. The full engine reference; read the one matching the feature, don't load all |
| `theme-forest.css`, `art-kit-forest.mjs` | The ornate fantasy-forest design system (parchment/gold/moss, SVG→PNG art kit) |
| `preview-pack.sh`, `PreviewRender.kt` | Render every page with the app's real engine on this Mac (no device), then analyse the PNGs |
| `overview-sheet.py` | Tile a pack's screenshots into one labelled overview PNG (how to make it: "Overview sheet" below) |

Engine details (selectors, properties, units, script limits) are in `docs/` (a bundled copy of the public docs; see
`docs-site-and-simulator.md` for the page map) and in the GBA Duo app repo's
`docs-packs/`; read them when a
property or hook isn't covered here, and don't duplicate them.

## Workflow

1. **Pick the reference screen.** Screenshot a menu from the game. Sample 6–10 colours
   and note frame, title tab, selection highlight, font feel. Write them as `:root` tokens.
2. **Decide the sprite strategy per asset class** (`sprites-and-assets.md`): shipped
   third-party PNGs, ROM-drawn at runtime, or original art drawn in code. Mixing is normal.
3. **Find the memory map** (decompilation / Data Crystal) and verify addresses on a ROM
   per region. Return only display-ready values from `update()`, including asset keys.
4. **Skeleton:** `#screen` → waiting box (`visibleIf $waiting`) + ready content
   (`visibleIf $ready`) → `pages` with one page per tab + a nav (dock / tab row).
5. **Style in `style.css`** with tokens; legacy widget keys are only shorthand. Add `:pressed`
   feedback, bar `transition`s and `@media` rules from the start, not as a last polish.
6. **Make it interactive** (`interactive-and-game-script.md`): tap a tile → detail page or popup,
   the game opens pages by itself (battle), a settings area with WIDE / COLOR (and GAME CHANGES when
   the pack writes). Every tappable thing needs a visible pressed and selected state.
7. **Improve the picture** when the game allows it: `game.lua` with `wide()` (world + markers),
   `ambient()` (a light grade that follows the place), optional HUD hiding. `formatVersion` 4.
8. **Preview**: the browser simulator (`/simulator`, live, no setup) while designing, then on the Mac
   with the app's real engine (see "Previewing" below), look at
   every page, fix, repeat. The device is only for the final check (ROM-drawn art, Wide/Ambient,
   writes: the preview can't show them).
9. **Release:** bump `version`, zip without `art/`, `screenshoots/`, `NOTES.md`,
   `preview-data.json` (see repo README, "Releasing packs"); set the catalog's `minAppVersion`
   for any feature newer than the pack's oldest target.

## Previewing without the device

`skill/preview-pack.sh <pack-dir>` runs the **actual** `gbaduo` engine (CssParser,
StyleResolver, CompanionTree, CompanionScreen) under Robolectric at the Thor's size
(1240 × 1080 px, 369 dpi = 538 × 468 dp; renders 1079 px tall from dp rounding), so layout, fonts, CSS
and sprites look the way they do on the device. Needs JDK 17 and a checkout of the
[GBA Duo app repo](https://github.com/khumam/gba-duo) (`--app DIR` or `$GBADUO_APP_DIR`; the script's default is a sibling folder named `gbaduo`); ~25 s after the first run. It copies
`PreviewRender.kt` into the app's tests for the run and deletes it again (app repo stays clean).

```sh
skill/preview-pack.sh golden-sun-companion                       # → golden-sun-companion/preview/
skill/preview-pack.sh pokemon-firered-minimal-companion --pages battle,detail --no-tall
skill/preview-pack.sh zelda-the-minish-cap-companion --nav dock --data preview-data.json --out /tmp/z
```

| Output | Meaning |
|---|---|
| `screen-<n>.png` | Page after clicking nav button *n*, at device size |
| `screen-<page>.png` | `--pages` entries: pages the script opens itself (battle, detail), shown with the same data |
| `tall-<n>.png` | Same on a 538 × 1400 dp canvas: shows overflow and what is clipped |
| `report.txt` | CSS / layout / tree / `ui` warnings, nav button count, image sizes |

Rules for a faithful preview:

- `preview-data.json` must mirror `update()`'s return, **including every state** you style
  (low HP, locked, empty list, selected row). Use a second file (`--data`) per state.
- The nav is auto-detected as the biggest group of tappable siblings; pass `--nav <class>`
  when that guesses wrong (report.txt shows the count: Golden Sun 3, Zelda 4, FireRed 6).
- `gfx:` images (ROM-drawn) can't render without a ROM: put `asset:` fallbacks in the preview
  data (Zelda then shows its `?` placeholders) and verify those on the device.
- Fonts and `asset:` images come from the pack folder, so this also catches 404ing `@font-face`
  paths and a wrong `src`.
- Keep `preview/` out of the release zip (`-x 'preview/*'`).

### Overview sheet (all pages on one image)

For a review, give the person one sheet per pack instead of a pile of PNGs: every page as a labelled tile in a
grid, 3 across, page name above each tile. `skill/overview-sheet.py` makes it.

1. Render the pages you want. `--pages` takes the page names from the layout (`pages` widget), and the nav
   auto-detect can miss, so list them. Render `--no-tall` unless you need the tall shots:
   `skill/preview-pack.sh <pack> --out /tmp/<pack> --no-tall --pages map,party,detail,bag,dex,battle`
2. Copy the PNGs into one folder named after the page, dropping `screen-`, skipping the numbered ones the kit
   writes for the pager (`screen-0.png` ...): `screen-dex.png` becomes `shots/dex.png`.
3. A state the kit can't reach by navigation (a typed search, a hint bubble, a popup) is a second render with a
   copy of the data file: put the state in the data (the entries that match, `searching: true`) and set the UI keys
   with `"ui": {"set": {"dexQuery": "mu"}}`, then `--data <that file> --pages dex` and save it as `dex-search.png`.
   Note `ui` in a data file must be the `{"set": {...}}` form, or the page renders empty.
4. `python3 skill/overview-sheet.py shots --out shots-overview.png`. Options: `--order a,b,c` (tile order,
   default map, party, detail, bag, dex, dex-search, trainer, options, battle, battle-detail; pages not listed
   are added alphabetically), `--cols 3`, `--tile 420x366` (keep the Thor's 1240:1080 ratio).

Read the sheet before handing it over: a blank tile means the data file lacks what that page binds, not that the
pack is broken (this caught an empty Summary page once). When removing the scratch renders, guard the variables
(`rm -rf "${S:?}/${p:?}"`): Claude Code blocks an `rm -rf $VAR` that could expand to `/`.

### Analysing the render (checklist)

Open each PNG (Read tool, or compare with the Thor screenshot in `screenshoots/`) and check:

1. Warnings: `report.txt` empty of `WARN`. Unknown property/value = silent no-op on device.
2. Clipping and overflow at the bottom/right edges; compare `screen-*` to `tall-*`.
3. Text: not wrapped or truncated, readable contrast, font actually loaded (not the fallback).
4. Sprites: crisp (integer scale), centred in slots, no stretched aspect ratio.
5. States: selected nav item, locked/owned, low HP, empty list each look intentional.
6. Spacing consistent across pages (same padding, gaps, header height).
7. Fidelity to the reference game screen: put them side by side.

## Design rules that held across all packs

- **Attractive first glance.** One focal hero per page (the map, the party leader, the equipped
  items), a consistent frame/header height, and a clear accent colour for "current"/"owned".
- **Every tile is tappable or obviously not.** If it looks like a button it opens something
  (detail page, popup, equip) and has a `:pressed` style; static info uses a flat style.
- **Offer the app's features.** If the pack has `wide()` it needs a WIDE pill; with `ambient()`,
  a COLOR pill; with `memory-write`, a GAME CHANGES pill (reserved actions, no Lua needed).
- **Adapt to the screen.** Grids with `repeat(auto-fill, minmax())`, sizes with `clamp()`, and an
  `@media (orientation: portrait)` rule for the nav. Don't hard-code 538 px.
- **One screen, 3–7 pages.** A persistent nav (bottom tab bar, right-side dock, or header
  tabs) switches pages; each page is one job (party, bag, map, quest).
- **Waiting screen first.** `ready=false` until the save is loaded (title screens hold
  garbage in RAM). Show game title + short line, never an empty screen.
- **Show what's missing.** Locked/unowned items stay visible at 0.25–0.55 opacity or as
  an empty socket; owned ones get colour or a gold rim.
- **Numbers distinct from labels:** a second font/weight, colour, or a text-shadow.
- **Tokens, not literals.** Declare colours in `:root`; per-item colours via
  `bindStyle: {"--c": "{color}"}` and `var(--c)` in CSS.
- **State as classes.** `classIf` for `on`, `low`, `down`, `locked`, `selected`;
  never rebuild structure per state.
- **Pixel fonts need size boost** (~1.3× vs a regular face) and `white-space: nowrap`.
- **Sprites are pixel art:** `image { image-rendering: pixelated }` and sized in whole
  device pixels (see `sprites-and-assets.md`). Smooth art (SVG-rendered) opts out with
  `image-rendering: auto`.
- **Fonts:** one `.ttf` per `@font-face`, path relative to the pack root. Reused so far:
  Jersey 10 (all three packs), Press Start 2P, Silkscreen. Declaring one file under two
  family names is the cheap way to get a "bold" slot.

## Engine gotchas seen in these packs

| Gotcha | Fix |
|---|---|
| `flex: 1 1 0` drops the whole declaration | write `flex: 1` |
| `background-size: 100% 100%` falls back to bitmap size | fixed px size, or `cover`/`contain` |
| `background-color` plus a gradient on `.hero` etc. | gradient goes in `background` / `background-image`; colour is the fallback |
| `button` ignores a `text` attribute | give it a `text` child |
| No `@keyframes`, filters, radial gradients, pseudo-elements, multiple shadows/backgrounds | bake into PNG, one `box-shadow`; move things with `transition` + a class from `classIf` |
| `min(50%, 300px)` drops the declaration (can't mix `%` and px) | `calc()` or `clamp()` with px, or `min(50%, 80%)` |
| `padding` in `%`, `grid-template-areas`, sibling combinators, attribute selectors | not supported: use px/`gap`, row-major grid, extra classes |
| A tap on a hidden / `opacity: 0` box falls through | intended; fade popups with `opacity` + `pointer-events` |
| Writes work only inside an `onClick` action (or `frame()` for HUD-style hooks) | do the write in `actions.*`; `update()` can't write |
| A wrong `wide()` world just hides the margins | log `view.match` behind a `DEBUG` flag; calibrate camera lag |
| Absolute-positioned ornaments land on the wrong box | parent needs `position: relative` |
| Layout can't compare values | compute booleans/strings in Lua (`navParty`, `hasWild`, `low`) |
| `gfx.*` result gone after cache eviction | call it every tick; keep only the args in Lua |
| 8-digit hex in CSS | CSS order `#rrggbbaa`, not Android `#aarrggbb` |
| `gameScript` / `memory-write` need newer manifests | `formatVersion` 4 for `gameScript`, 3 for `permissions`; older apps refuse the pack |

## Common mistakes

- Copying the forest theme onto a game that doesn't look like a forest. The forest
  system (`theme-forest.css`) is one example; the method is "sample the game's UI".
- Shipping third-party sprites when the ROM can draw them (legal risk, bigger zip).
  Prefer `gfx.*` when the addresses are findable; ship PNGs only when they aren't
  (FireRed's PokeAPI sprites are the existing exception, credited in the README).
- Guessing addresses for another region. EU/US/JP differ; keep a per-game-code table
  and fall back to drawn art for unknown codes.
- A read-only pack with no detail pages, popups or settings: the player sees numbers they could
  read in the game. Add at least one tap-through and the WIDE/COLOR pills if the pack supports them.
- Adding `wide()` / `ambient()` but no button for it (the app has no menu entry for them).
- Heavy `ambient()` grades (strong tint, vignette > 0.4) that fight the game's palette.
- Writing `layout.json` by hand when it repeats (dock on every page): generate it from
  `art/layout.mjs`, as the Pokémon packs do.
