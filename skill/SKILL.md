---
name: gbaduo-companion-pack-design
description: Use when creating, restyling or reviewing any GBADuo companion pack (manifest.json, layout.json, style.css, main.lua, assets) for a GBA/GBC game — choosing a visual style, building the screen layout, or deciding where sprites and icons come from (shipped PNGs, the player's ROM at runtime via gfx.*, or art drawn in code). Distilled from the Pokémon FireRed/LeafGreen, Zelda Minish Cap and Golden Sun packs.
---

# GBADuo Companion Pack Design

## Overview

A pack is a screen description for the Thor's second display (~538 × 468 dp, landscape).
`layout.json` is structure, `style.css` is look, `main.lua` reads game memory and returns
the values to show, `assets/` holds fonts and images. This skill is the general method;
it was derived by reading three finished packs side by side.

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
| `layout-snippets.md` | Writing `layout.json`: skeleton, hero plaque, stat plaque, icon rows, owned/locked |
| `theme-forest.css`, `art-kit-forest.mjs` | The ornate fantasy-forest design system (parchment/gold/moss, SVG→PNG art kit) |
| `preview-pack.sh`, `PreviewRender.kt` | Render every page with the app's real engine on this Mac (no device), then analyse the PNGs |

Engine details (selectors, properties, units) live in the repo skill
`.claude/skills/styling-the-companion-screen` and the app's `docs-packs/*.md`; don't
duplicate them here.

## Workflow

1. **Pick the reference screen.** Screenshot a menu from the game. Sample 6–10 colours
   and note frame, title tab, selection highlight, font feel. Write them as `:root` tokens.
2. **Decide the sprite strategy per asset class** (`sprites-and-assets.md`): shipped
   third-party PNGs, ROM-drawn at runtime, or original art drawn in code. Mixing is normal.
3. **Find the memory map** (decompilation / Data Crystal) and verify addresses on a ROM
   per region. Return only display-ready values from `update()`, including asset keys.
4. **Skeleton:** `#screen` → waiting box (`visibleIf $waiting`) + ready content
   (`visibleIf $ready`) → `pages` with one page per tab + a nav (dock / tab row).
5. **Style in `style.css`** with tokens; legacy widget keys are only shorthand.
6. **Preview on the Mac** with the app's real engine (see "Previewing" below), look at
   every page, fix, repeat. The device is only for the final check (and ROM-drawn art).
7. **Release:** bump `version`, zip without `art/`, `screenshoots/`, `NOTES.md`,
   `preview-data.json` (see repo README, "Releasing packs").

## Previewing without the device

`skill/preview-pack.sh <pack-dir>` runs the **actual** `gbaduo` engine (CssParser,
StyleResolver, CompanionTree, CompanionScreen) under Robolectric at the Thor's size
(1240 × 1080 px, 369 dpi = 538 × 468 dp; renders 1079 px tall from dp rounding), so layout, fonts, CSS
and sprites look the way they do on the device. Needs JDK 17 and the app repo at
`../gbaduo` (or `--app DIR` / `$GBADUO_APP_DIR`); ~25 s after the first run. It copies
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
| No `@keyframes`, filters, radial gradients, pseudo-elements, multiple shadows | bake into PNG, one `box-shadow` |
| Absolute-positioned ornaments land on the wrong box | parent needs `position: relative` |
| Layout can't compare values | compute booleans/strings in Lua (`navParty`, `hasWild`, `low`) |
| `gfx.*` result gone after cache eviction | call it every tick; keep only the args in Lua |
| 8-digit hex in CSS | CSS order `#rrggbbaa`, not Android `#aarrggbb` |

## Common mistakes

- Copying the forest theme onto a game that doesn't look like a forest. The forest
  system (`theme-forest.css`) is one example; the method is "sample the game's UI".
- Shipping third-party sprites when the ROM can draw them (legal risk, bigger zip).
  Prefer `gfx.*` when the addresses are findable; ship PNGs only when they aren't
  (FireRed's PokeAPI sprites are the existing exception, credited in the README).
- Guessing addresses for another region. EU/US/JP differ; keep a per-game-code table
  and fall back to drawn art for unknown codes.
- Writing `layout.json` by hand when it repeats (dock on every page): generate it from
  `art/layout.mjs`, as the Pokémon packs do.
