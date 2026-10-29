# Pack anatomy: how the packs are built

Compared packs: **Pokémon FireRed minimal** (`pokemon-firered-minimal-companion`, same
engine as the other five Pokémon variants), **Zelda: The Minish Cap**
(`zelda-the-minish-cap-companion`), **Golden Sun** (`golden-sun-companion`, v0.1.0).

## Folder layout

```
<pack>/
  manifest.json        id, name, version, formatVersion 2, match.gameCode[], tickHz 4, layout/styles/script
  layout.json          widget tree (one root box id="screen")
  style.css            tokens, @font-face, rules
  main.lua             update(ui) -> table of values for the layout
  *_names.lua          lookup tables (species, items, areas, djinn), loaded with pack.require("x")
  game_data.lua        bulky static data (FireRed: 1383 lines of species/moves/encounters)
  rom_gfx.lua          (Zelda) ROM-drawn images, per-release address table
  town_map.lua         (Pokémon) ROM-drawn Town Map
  preview-data.json    sample return value of update(), for the simulator only
  assets/fonts|ui|...  shipped fonts and PNGs
  art/                 build scripts + sources (excluded from the release zip)
  screenshoots/        device screenshots (excluded)
  NOTES.md             what's verified on the device, addresses, sources (excluded)
```

`manifest.json` matches by 4-letter `gameCode` (Zelda lists `BZME/BZMP/BZMJ`, Golden Sun
`AGSE/AGSP/AGSJ/AGSI`), `tickHz: 4` for all three. `values: {}` is unused.

## The contract: Lua returns, layout binds

```
mem.u8/u16/u32/read  ──▶ update(ui) ──▶ returned table ──▶ {binding} / "$path" / visibleIf / classIf / bindStyle
                           ▲                                   │
                           └── ui.<key> (set by onClick) ◀─────┘
```

- `update(ui)` is called `tickHz` times a second. `ui` carries page name (`ui.page`) and
  anything `onClick { set = {...} }` stored (`ui.member`, `ui.item`).
- **Return display-ready data**, not raw RAM: formatted strings ("12,480"), booleans for
  every state the CSS needs (`low`, `down`, `locked`, `navParty`), percentages for bars
  (`hpPct` 0..1), colours as hex strings, and **asset keys for images**.
- Always return `ready` and `waiting`. Golden Sun validates the party (unique slots, ASCII
  names, sane max HP) before setting `ready`; Zelda requires an initialised save with
  3–20 hearts. Title screens leave garbage in RAM.
- The layout can't compare or compute. If a tab should open "on DUNGEON when in a
  dungeon", Lua stores a visit counter in `ui` and returns the boolean.
- Lists: `{"type":"list","items":"$members","template":{...}}`; inside the template
  `{field}` / `"$field"` refer to the item, `{@index}` to its position (used for
  `onClick set member`).
- Game switches pages itself: return `ui = { navigate = "battle" }` once on the edge
  (FireRed opens BATTLE when a fight starts).

Typical `update()` shape (Golden Sun): read party → build `members[]` → build the selected
member's `m`, `item`, `elements[]` → `out.ready/out.waiting` → `out.navX` booleans for the
nav's `classIf`.

## Layout skeleton shared by all three

```
box#screen
├─ box.waiting  visibleIf=$waiting        (title + "load a save")
└─ box.main     visibleIf=$ready
   ├─ (header: location/time/money | rupees/kinstones/Ezlo)   — Pokémon, Zelda
   ├─ pages.stage  state=page initial=<first>
   │    ├─ page "map"   → panels in flex/grid
   │    ├─ page "party" → list + detail
   │    └─ …
   └─ nav / dock: one `button` per page, onClick [{navigate: page}], `.on` marks current
```

| | Pokémon minimal | Zelda | Golden Sun |
|---|---|---|---|
| Pages | map, party, detail, bag, dex, trainer, battle | map, items, kinstone, quest | party, djinn, psynergy |
| Widget mix (counts) | box 253, text 147, button 44, list 17, image 28, bar 8 | box 156, **image 188**, text 75, button 19 | box 52, text 42, list 4, bar 3, **0 images** |
| Nav | right-hand dock (vertical) — `-v` / default variants: bottom/horizontal | bottom wooden command dock | bottom tab bar, pink bar = current |
| Header | location pill + clock + coin | rupees, kinstones, Ezlo button | none (hero window per page) |
| Detail pages | `detail` page opened by tapping a party card | tap an item → `ui.itemName` → shows its name | tap member → `ui.member`; tap item → `ui.item` |
| CSS size | 855 lines | 644 | 163 |
| Layout built by | `art/layout.mjs` (generates JSON; dock repeated per page) | `art/layout.mjs` | hand-written |
| Fonts | Jersey 10 (twice, as "Barlow"/"BarlowBold") | Jersey 10 + Press Start 2P (numbers) | Jersey 10 + Silkscreen 700 (tabs) |

Pokémon variants on one data layer: `pokemon-firered|leafgreen` (horizontal),
`-v-` (vertical nav), `-minimal-` (calm skin). Same `main.lua`, `layout` generated with a
different dock and a different `style.css`. When making a second skin, copy `main.lua`
and `game_data.lua` untouched and only fork layout + CSS.

## Build pipeline per pack

1. **Data:** decompilation / RAM maps → addresses in `main.lua`; names in `*_names.lua`.
   Region-specific addresses behind a per-game-code table.
2. **Images** (see `sprites-and-assets.md`):
   - `node art/fetch-sprites.mjs` (Pokémon: downloads PokeAPI sprites into `assets/`), or
   - `node art/<name>-os.mjs` (Zelda, Pokémon UI: pixel art from palette-character rows →
     PNG at `SCALE`× with nearest-neighbour, zero dependencies, `--sheet` makes a
     contact sheet), or
   - `node art/build.mjs` (SVG → PNG with `@resvg/resvg-js`, the forest/ornate packs), or
   - nothing (Golden Sun: CSS only; Zelda: ROM at runtime).
3. **Layout:** `node art/layout.mjs` writes `layout.json` when pages share chrome.
4. **Style:** one `style.css` with `:root` tokens → fonts → canvas → header → panels →
   per-page sections → nav → states.
5. **Preview data:** `preview-data.json` mirrors `update()`'s return so the simulator
   shows every page (include every state: low HP, locked, empty list).
6. **Verify:** `preview-pack.sh` (real engine, on the Mac; see `SKILL.md`) → device; write findings
   in `NOTES.md` with *what was checked on a device and what wasn't*.
7. **Release:** bump `manifest.version`, zip contents (manifest at zip root), exclude `art/`,
   `screenshoots/`, `NOTES.md`, `preview-data.json`; ship name `<id>-<version>.zip`.

## Sizing facts used everywhere

- Screen 1240 × 1080 px at 2.30625 px/dp ⇒ ~538 × 468 dp; 1 device px = 0.4336 dp.
- Packs scale reference designs (3DS 320×240 guide, GBA 240×160) by ~1.5× to ~2.25×.
- `#screen { width:100%; height:100% }` plus a `padding` of 6–8 px as the bezel.
- Typical frame: border 2–3 px, radius 3 px (Pokémon, Golden Sun) or 6–14 px (Zelda);
  box-shadow as a hard offset, e.g. `2px 2px 0 #18181B`, not a blur.
