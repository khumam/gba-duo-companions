---
name: enchanted-forest-pack-design
description: Use when designing or restyling a GBADuo companion pack (layout.json, style.css, assets) and the user wants a fantasy, leafy, ornate, "stunning" or adventure-game look — Zelda-like, RPG, nature, fairy-tale — or asks for the Minish Cap style on another game.
---

# Enchanted Forest Pack Design

## Overview

A design system for GBADuo companion packs: a dark, lit forest seen from tiny
(Minish) scale, with moss-glass plaques rimmed in gold, a parchment "leaf" hero
plaque, leaf sprigs pinned to corners, gold vine section titles and painted icons.
Reference implementation: `zelda-minish-cap-companion/`.

**Core principle:** every ornament is original vector art, drawn in code from a few
primitives (leaf blade, fern, vine, glow), then rasterized to PNG. The engine
can't read SVG.

## Engine constraints (GBADuo companion CSS)

| Want | Reality | Do this |
|---|---|---|
| SVG images | `BitmapFactory` only | Draw SVG in `art/build.mjs`, render PNG at 3x |
| `background-size: 100% 100%` | `%` silently falls back to the bitmap's own size (density-dependent) | `cover`/`contain`, or fixed `px` box + same `px` size |
| Radial gradients, `filter`, `@keyframes`, pseudo-elements, multiple shadows | Unsupported | Bake glows/blur into PNGs; one `box-shadow` |
| Smooth images | `image` defaults to `pixelated` | `image-rendering: auto` on every art image |
| Overlays | `position: absolute` in a `position: relative` box; `display: stack` + `place-items` | Sprigs, seals, letter-on-acorn |
| Per-item icons | `"src": "$src"` with `asset:img/x.png` from Lua | Script returns the asset key |
| Variable fonts | Weight axis not honored | Ship static TTFs, one family name per weight |

## Building a pack in this style

1. Copy `theme.css` → pack `style.css`; keep the tokens, add game sections below.
2. Copy `art-kit.mjs` → pack `art/build.mjs`. Keep primitives + forest/tabs/sprigs/
   vines/emblem; replace the game icons (hearts, gems, items) with the new game's.
   Run: `npm i @resvg/resvg-js && node art/build.mjs` (writes `assets/img/*.png`).
3. Fonts in `assets/fonts/`: Uncial Antiqua (titles/names), Cinzel Decorative Bold
   (labels, tabs), Alegreya Sans Medium + Bold (body). All OFL, from google/fonts.
4. Build the layout from `layout-snippets.md`: waiting screen, leaf tabs, one hero
   plaque per tab, vine titles between sections, 2-column plaque grids.
5. Lua: return `ready`/`waiting`, and `src` fields for icons that change (heart
   quarters, owned/empty sockets, colour variants).
6. Render and look at every tab with `PreviewRender.kt` before the device.
7. Zip without `art/`, `NOTES.md`, `preview-data.json`; push to `/sdcard/Download`.

## Design rules

- Palette: night `#06180F`, glass `rgba(9,34,24,.82)`, gold `#E8BE55` / hi `#FFE9A3`
  / deep `#9C6F1C`, parchment `#F6EDCF`, text `#F3EBD3`. One gem colour per stat.
- Hero plaque = parchment, `border-radius: 22px 6px 22px 6px` (leaf cut), sprigs at
  both top corners. Everything else = glass plaque, 14px radius, 1px gold rim.
- Owned/locked: locked items at 0.22–0.55 opacity or an "empty socket" icon; owned
  turn gold. Never hide progress — show what's missing.
- Numbers in Alegreya Bold, coloured by their gem; labels in Cinzel, gold, 10px.
- Screen is 1240×1080 px landscape at 369 dpi (2.30625 px/dp) = ~538×468dp. 1 device px
  = 0.4336dp: for crisp pixel art, size in whole device px (e.g. 5px = 2.168dp).

## Common mistakes

- Text sits on the tab's top edge → tabs need `padding-top: 9px` on an 84×34 leaf.
- Leaves drawn on a white preview look fine but vanish on the dark forest — always
  review the contact sheet on `#123F2C` and on parchment.
- Glow dots with a big radius wash out a whole tile; keep emblem glow `r ≤ 12`.
- Wreath/radial leaf rings: orient leaves along the tangent, leave a gap at the
  join, or the bottom tangles.
- Gradle won't rerun the preview test after pack edits (inputs not tracked): use
  `--rerun`.
- `button` ignores a `"text"` attribute and renders blank — give it a `text` child.
- Pages other than the first (e.g. a battle page the script opens) only show up
  in previews if listed in `/tmp/pack-pages.txt`.
- The palette is a default, not a rule: keep the system (plaques, hero leaf-cut,
  corner ornaments, dividers, drawn icons) and re-theme per game — e.g. the
  FireRed pack swaps leaves for flames (`flame()` primitive in its art/build.mjs).
