---
name: gbaduo-companion-pack-design
description: Use when adding a companion for a new game (from the player's ROM and save: headless harness, screenshots of the game's menus, memory map, ROM text and tables), or when creating, restyling or reviewing any GBADuo companion pack (manifest.json, layout.json, style.css, main.lua, assets) for a GBA/GBC game — choosing a visual style, building the screen layout, making it interactive (tap-to-detail, popups, equip, settings pills), adding Wide view / Ambient / markers through game.lua (metatile, layered and chunked 8bpp worlds, map-edge clamp, margin sprites), fitting any screen size, or deciding where sprites and icons come from (shipped PNGs, the player's ROM at runtime via gfx.*, or art drawn in code). Distilled from the Pokémon, Zelda Minish Cap, Golden Sun and Mega Man Zero packs and the app's current engine docs.
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
| `tools/` | `README.md` first: the toolkit (harness/play.py, ramdiff, textfind, gfxfind, packkit/run.lua, css.py, overview.sh) and finding addresses (`log()`, `gba-harness.c`, `ramsearch.py`, store/DMA/BIOS tracing), and the generators run on finished packs: `navkit.py` / `navkit_pokemon.py` (movable nav + Options row), `pixel_theme.py` / `apply_pixel_css.py` (Pokémon pixel-art restyle) |

Engine details (selectors, properties, units, script limits) are in `docs/` (a bundled copy of the public docs; see
`docs-site-and-simulator.md` for the page map) and in the GBA Duo app repo's
`docs-packs/`; read them when a
property or hook isn't covered here, and don't duplicate them.

## Workflow (the recipe every new pack follows)

Tools for each step are in `tools/` (`tools/README.md`, section 0). The Castlevania trilogy, Zelda: A Link to the
Past, FFVI and Metroid packs are worked examples (each pack's `NOTES.md` lists its addresses and how they were found).

1. **Get the ROM and, ideally, a late-game save** from the player (they put them in `~/Downloads/rom`). Build the
   harness (`tools/harness/build.sh`), boot with the save (`tools/harness/play.py`) and write a `base.steps` that
   reaches the field. A late save shows every item, list and menu filled in; an early one leaves gaps you'll have
   to fill by writing RAM.
2. **Screenshot the game's own menu screens**, every page and sub-page, into `art/ref/`. The pack is built **like
   these screens**: same panels, same order, same colours, same labels and fonts as close as the bundled fonts get.
   Sample the palette from the frames (`:root` tokens). Put the reference next to your render before calling it done.
3. **Map the memory** (`tools/README.md` steps 3-6): the save block, every value the menus show, the ROM's name and
   stat tables, the EXP curve. Prove each address by writing it and screenshotting the game's screen.
4. **Pages = the game's menu pages, in the game's order**, cycled by left / right plates at the bottom
   (`< PREV | PAGE + pips | NEXT >`, like the Pokemon / FFVI packs), plus a page the game has elsewhere when it
   helps (the castle / world map from the SELECT or L map screen). Build `layout.json` from `art/layout.py`, CSS
   from `art/style.src.css` in `ap` units (248 x 216 grid, nav at 190ap; `tools/packkit/css.py`), art from
   `art/ui.py` (Pillow, original pixel art in the sampled palette, sized in whole ap per pixel).
5. **Make it interactive and alive** (the player asked for this on every pack):
   - every row is tappable and opens its detail or links to the page that owns it (an enemy's soul -> Soul Set);
   - taps that change the game where safe (`memory-write`, formatVersion 3): equip, set souls / cards / books,
     use healing items, toggle relics / abilities, rebind buttons, a quick HEAL; update the game's derived totals
     too when the game only recomputes them in its own menu, or say so on screen;
   - live alerts: a banner when a soul / card / relic / item is found or a level gained (diff the flags tick to tick,
     ignore big jumps from loading a save), tap to open it;
   - previews like the game's (before -> after stats when picking gear).
6. **No spoilers**: names of bosses not beaten, items / upgrades not found, Dark-World-style places not reached and
   "next objective" lines are shown as `?????????` (one fixed length) until earned. Read ROM text, never ship it.
7. **Verify** offline (`tools/packkit/run.lua`: `update()` per page, `--act` for writes), replay the writes in the
   harness and screenshot the game's screens, then `skill/preview-pack.sh` (no warnings) and look at every page next
   to `art/ref/`.
8. **Overview + notes**: `tools/packkit/overview.sh PACK pages` writes `overview/<pack-id>-overview.png` (repo
   convention); include alert / state variants as extra tiles. Write `NOTES.md` (ROM / RAM tables, what was checked
   where, what's not done). Not device-tested = say so.
9. **Release** (when the player asks): bump `version`, zip without `art/`, `screenshoots/`, `NOTES.md`,
   `preview-data.json`; add to `companions.json` and the README; set `minAppVersion` for newer features.

### Lessons from the 2026-11 packs (engine and tooling)

| Problem | Fix |
|---|---|
| `"$list.0.field"` (index in a binding path) shows nothing | return plain fields from Lua (`orb1`, `pend0`) |
| A box sized only by `bindStyle` height collapses (map cells drew as lines) | fixed `height` in CSS, or a child box that has the height; `left` / `top` / `width` from `bindStyle` work |
| An image placed inside a list ignores `bindStyle` left/top | use a `box` for positioned list items |
| Silkscreen has no `%` (shows `Z`), no arrows | put numbers with `%` in Jersey; write arrows as `v > < ^` |
| A text outside `.page` (an overlay banner) falls back to the system font | set `font-family` on the overlay itself |
| An image whose PNG size differs from its CSS box is letterboxed / offset | draw every frame PNG at exactly its CSS size (generate windows from layout.py) |
| `preview-pack.sh --data` with a relative path renders nothing | pass an absolute path |
| Preview data merged from several pages: a later page's defaults overwrite an earlier page's state | keep per-page keys distinct, or render that page from its own data file |
| 16-bit write to an odd address goes one byte early | write the bytes singly |
| Harness `keys` leaves the key held for later `run`s | always release (`keys 0 1`); `play.py` does it |
| Game recomputes stats only in its own menu | after a gear write also write the totals with the game's formula (checked against its arrows), else say "pause to refresh" or keep that page read-only |
| A worn item is / isn't counted in the bag | check per game (Aria counts it, CotM doesn't) before adjusting counts |
| The game ignores the player's save (title shows New Game only) | read the SRAM directory: slots may be marked empty while the data is intact (Fire Emblem); rebuild the entries + checksums in a scratch copy, never in the player's file |
| ROM-drawn icons have the wrong colours | one sheet can use several palettes (FE items vs weapon / affinity symbols): match an icon's on-screen colours to ROM palettes (fire-emblem NOTES.md) |
| Previews can't show `gfx:` images | `run.lua` records gfx calls, `packkit/gfxmock.py` draws them into `assets/_preview` |
| A face built from a sprite sheet (FE portraits) | `gfx.decode` the whole sheet, then show blocks of it in `overflow: hidden` boxes with negative offsets |

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
