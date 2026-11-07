# Interactive packs, game.lua and responsive CSS

What turns a static stats screen into a companion people keep looking at. The engine docs are
the contract (`docs/pages.md`, `docs/styling.md`, `docs/game-script.md`, `docs/lua.md` in this skill);
this file is the design advice and the patterns that worked in the Minish Cap, FireRed, Emerald
and Golden Sun packs. Read it before adding anything beyond a read-only display.

## The "good pack" checklist

A pack feels finished when it has most of these:

| Quality | What it means in practice |
|---|---|
| **Looks like the game** | Frame, fonts and palette sampled from one of the game's own screens (`visual-styles.md`) |
| **Art from the ROM** | Icons, maps and logos drawn at runtime with `gfx.*`, with drawn fallbacks (`sprites-and-assets.md`) |
| **Every tap does something** | No dead-looking tile: it opens a detail page, a popup, or equips |
| **Press feedback** | `:pressed` on everything tappable (a 1–2 px nudge, as the physical-button look) |
| **Living data** | Bars animate (`transition: width 400ms`), the map marker moves, the game can open a page by itself (battle) |
| **Settings page** | WIDE, COLOR and (if it writes) GAME CHANGES pills, wired to the reserved actions below |
| **Adapts to the screen** | `@media`, `clamp()`, `repeat(auto-fill, minmax())`: works on the Thor, a phone's second display and the main screen |
| **States are designed** | waiting, empty list, locked, low HP, unknown release, write refused |

## Interaction patterns

### 1. Tap a tile, open a detail page

```json
{ "type": "list", "items": "$party", "template": { "type": "row", "class": "mon",
  "onClick": [ { "set": { "selected": "{@index}" } }, { "navigate": "detail" } ],
  "children": [ { "type": "text", "text": "{name}" } ] } }
```

A detail `pages` entry has a `‹ Back` button (`"onClick": "back"`). Lua fills `detail` only when
`ui.page == "detail"` (`ui.selected` is 0-based, Lua tables are 1-based). A tap triggers an
immediate `update(ui)`, so the page fills almost instantly, even with the game paused.

### 2. Popup / bottom sheet without a page

Store one key and gate the popup on it. The Minish Cap equip menu:

```json
{ "type": "box", "class": "slot", "onClick": { "set": { "menu": "{id}", "menuName": "{name}", "menuIcon": "{icon}" } } }
{ "type": "box", "class": "equip-menu", "visibleIf": "$ui.menu", "children": [ ... ] }
{ "type": "box", "class": "menu-btn", "onClick": { "call": "equip", "args": ["A", "{ui.menu}"] } }
{ "type": "box", "class": "menu-btn", "onClick": { "set": { "menu": "" } } }
```

Style the popup `position: absolute; inset: 0` over a dimmed `rgba()` backdrop (give the parent
`position: relative`), and close it on both the backdrop tap and CANCEL.

### 3. Tab that remembers or resets

The layout can't compare values, so Lua decides and returns a boolean. Minish Cap stores a visit
counter in `ui` (`ui.mapWorldAt`) and returns `showWorld`; each new dungeon entry bumps it, so the
map opens on DUNGEON again. Same trick for "open on the page that matches where the player is".

### 4. The game switches the page

Return `out.ui = { navigate = "battle" }` once, on the edge of the change, and `{ back = true }`
when it ends. Returning it every tick locks the player onto that page.

### 5. Feedback after an action

Actions return `{ set = { ... } }`; show it as a toast: `picked`/`pick` keys, a `.toast` box with
`visibleIf: "$ui.picked"` and a short message ("B > BOOMERANG", or "CAN'T CHANGE: <why>").
Always surface a refused write instead of failing silently.

### 6. Selected / pressed / locked styling

```css
.slot            { transition: transform 60ms linear, border-color 120ms ease-out; }
.slot:pressed    { transform: translate(1px, 1px); border-color: var(--gold); }
.slot.selected   { border-color: var(--gold); box-shadow: 0 0 0 2px var(--gold-dim); }
.slot.locked     { opacity: .35; }
```

`transition` works on `opacity`, `color`, `background-color`, `transform`, `width`, `height`.
No `@keyframes`: for motion, animate a bar's `width`, swap a class from Lua (`classIf`), or
bake frames into an image.

## Reserved actions (the app handles them, your Lua is not involved)

Call them with `onClick: { "call": "<name>", "args": [...] }`. Every snapshot carries the matching
state, so the pill can show it.

| Action | Args | State in the snapshot |
|---|---|---|
| `wideView` | `"on"`, `"extra"` (XL), `"off"`, `"toggle"` (default: off → wide → XL → off) | `_wide`, `_wideMode` (0/1/2), `_wideLabel` (`ON`/`XL`/`OFF`/`N/A`) |
| `ambientView` | `"on"`, `"off"`, `"toggle"` | `_ambient`, `_ambientLabel` (`ON`/`OFF`/`N/A`) |
| `writePermission` | none: asks the player again | `_writePerm`, `_writePermLabel` (`ALLOWED`/`DENIED`/`NOT ASKED`/`OFF`/`N/A`) |

```json
{ "type": "box", "class": "opt", "classIf": { "on": "$_wide" },
  "onClick": { "call": "wideView", "args": ["toggle"] },
  "children": [ { "type": "text", "text": "WIDE {_wideLabel}" } ] }
```

Put them on a small **settings** area (a header pill or a last page). A pack with `wide()` that has
no WIDE pill, or `ambient()` with no COLOR pill, hides its best feature: the feature has no menu
entry in the app.

## game.lua: making the picture itself better

`manifest.json` needs `"formatVersion": 4` and `"gameScript": "game.lua"`. It runs in its own sandbox
(same `mem`, `gfx`, `lz77`, `log`, `pack.require`); a broken script never touches the companion
screen. Each hook gets 100,000 instructions and 2 ms; five errors in a row switch the script off
until the next game start.

| Hook | Runs | Use |
|---|---|---|
| `init()` | once | state, read-only |
| `frame(view)` | every emulated frame | optional RAM writes (needs `memory-write`) |
| `wide(view)` | every frame, only while Wide view is on | describe the world for the margins |
| `ambient()` | 4×/s, only while Ambient is on | colour grade and light |

### Wide view (WIDE / XL)

`wide()` returns the world around the game's 240×160 frame: `x, y` (world pixel of the screen's
top-left), then either one grid (`grid, gridW, gridH, idMask, metatiles, tiles, palette, border…`,
the Pokémon games) or `layers = { bottom, …, top }` (Minish Cap, Golden Sun). Return `nil` for
battle, menus or an unknown map: the margins stay black. The app compares the predicted edge columns
(and, in XL, rows) with what the emulator drew, hides the margins below 85% for four frames and brings
them back after four good ones, so a wrong world looks like "no wide view", not garbage.

Design rules:

- **Calibrate with `view.match`** (0–1). Log frames below 0.9 behind a `DEBUG` flag
  (`adb logcat -s GBADuoPack`). Camera lag while walking and sprites on the edge columns are the
  usual culprits (Minish Cap adds the BG-register lag to the camera).
- **Markers** make the margins useful: up to 64 `{x, y, kind}` (1 NPC white, 2 enemy red, 3 item
  yellow, 4 door cyan), or real sprites with `tiles`, `palette`, `w`, `h`, `hflip`. Draw the actual
  sprite when the OAM data is findable (Minish Cap walks the entity array); keep diamonds as the
  fallback only for Golden Sun-style off-screen actors. Never gate on a flag that is 0 off screen.
- **Hide the HUD over the picture** when the margins repeat it: write the game's HUD-hide flag from
  `frame()` only while `wide()` ran in the last few frames, and restore it when the view stops
  (Minish Cap: `gHUD.hideFlags`).
- **Only describe what is the world.** The player, NPCs and the game's own blends (cloud shadows,
  fades) are not in the margins; the seam check tolerates ~40 per channel for those blends.
- **Check every release.** Keep a per-game-code address table; return `nil` for an unknown one.

### Ambient (COLOR): the pack's look

`ambient()` returns a table (or `nil`/`false` for the plain picture). Every field is optional and the
default changes nothing:

`saturation, contrast, brightness` (1) · `tint {r,g,b}` · `vignette, vignetteColor` · `sunX` (-1…1) ·
`sunSlope` · `shadow, shadowLength, shadowColor` · `rim, rimColor` · `crease` · `bloom` · `haze` ·
`clouds, cloudSize, cloudSpeed`

Guidelines that made packs look good instead of muddy:

- **Light grade for bright games.** Minish Cap: saturation 1.06, contrast 1.05, a neutral grey
  vignette 0.22. Heavy tints fight the game's own palette.
- **Top-down games:** `sunX = 0` (shadows fall straight down), `shadow ≈ 0.5`, `rim ≈ 0.3` in a warm
  colour. Side-views: lean the sun.
- **Follow the place.** Return another table indoors, in caves and at night (no clouds, shorter and
  warmer shadows). Read an area flag; put the tables in `ambient.lua` and hand them over with
  `ambient = pack.require("ambient").ambient`.
- Clouds are cloud *shadows* in `shadowColor` over the ground, pinned to the map as the camera moves.
  Use them only under an open sky; keep `clouds` ≤ 0.35.
- Ambient only works with the GBA layer probe (shadows, rim, crease, haze, clouds); on GB/GBC only
  `shadow` works, from dark outlines.

### Writing the game (memory-write)

Only when it makes the companion *interactive*: equip an item, set a flag, hide a HUD. Rules enforced
by the app, not by you:

- `formatVersion` 3+ and `"permissions": ["memory-write"]`; off until **Settings > Packs can change games**;
  the player is asked once per pack and game (a restore state is saved first).
- Writes only run inside an `onClick` action (or `frame()` for the HUD-style case), only to RAM
  (EWRAM `0x02000000–0x0203FFFF`, IWRAM `0x03000000–0x03007FFF`; GB WRAM/HRAM), ≤ 64 bytes per call
  and 256 per tap (`frame()`: 256 per frame).
- `mem.write8/16/32/write` return `true` or `false, reason`: **show the reason** (pattern 5).

Design it safely: check a "safe to act" condition first, write last after every check, validate the
id against your own name table, swap rather than duplicate (equipping an item the other button holds
swaps them, like the game's `ForceEquipItem`), and add the `writePermission` pill so the player can
revisit the answer.

## Responsive CSS (fit any screen)

The companion screen is ~538×468 dp on the Thor but can be a portrait phone display or the main
screen. Measured on the companion screen itself.

```css
.items  { display: grid; grid-template-columns: repeat(auto-fill, minmax(96px, 1fr)); gap: 8px; }
.title  { font-size: clamp(14px, 4vw, 22px); }
.card   { width: calc(100% - 24px); padding: max(8px, 2vw); }

@media (orientation: portrait)   { .main { flex-direction: column; } .dock { flex-direction: row; } }
@media (max-width: 400px)        { .party { grid-template-columns: 1fr; } }
@media (400px <= width < 700px)  { .header { gap: 4px; } }
```

- `min()`/`max()`/`clamp()` can't mix `%` with px (the declaration is dropped); use `calc()` for that.
- One `auto-fill`/`auto-fit` per track list; tracks need a fixed size (`minmax(96px, 1fr)`).
- A dock that is vertical on landscape and a bottom row on portrait is the cheapest big win.
- Keep text as `px`: the engine scales font-size in sp with the system text size.
- Test with `preview-pack.sh` (Thor size) plus a second run at another size when you use `@media`.

## Performance and limits

- `update()`: 1M instructions, 25 ms per call (`mem.read` bytes and drawn `gfx.*` pixels count).
  Compute only what the open page needs (`ui.page`), cache name lookups, keep `tickHz` at 4.
- Images ≤ 256×256 (`gfx.layers` ≤ 512×512); ~96 cached. Call `gfx.*` every tick with the same args.
- Script memory 16 MB; load-time work 5M instructions / 250 ms.
- Errors are logged (`adb logcat -s Companion PackStyles EmuThread GBADuoScript GBADuoCore`).

## Lessons from Golden Sun and Pokémon Emerald

Worked examples to copy from (`golden-sun-companion/`, `pokemon-emerald-companion/`).

### Wide view: calibrating a world

- **Single grid (Emerald, FireRed).** The BG scroll registers only say where the screen sits inside
  the game's 256 px ring, not where in the world. Anchor the origin while the player stands still
  (`STILL_FRAMES = 6`, camera exactly on their tile), then follow the scroll deltas. On a map change
  the game rebases the tile coordinates by whole tiles while the scroll carries on: recover the
  rebase from the player's current and previous tile (`PREV_COORDS`). Return `nil` until anchored.
- **Border and edges.** `border`/`borderW`/`borderH` repeat outside the map, `undefinedId` marks cells
  that use the border, `overscan` limits how far it repeats (Emerald: 120 px) so the margins don't run
  into infinity.
- **Three layers in one grid (Golden Sun).** One 128×128 u32 grid holds BG3/BG2/BG1 side by side;
  each layer's `grid` starts at its block of columns and all share `x, y`. The blocks' starts are the
  differences of the BG scroll values. The game's shadow scroll copy leads the hardware registers by a
  frame, so add the lag while the camera moves or the margins flicker to black.
- **Markers from the game's actor/entity array.** Emerald reads the map's NPC/trainer/item/door
  events from the ROM event table (hidden once their save flag is set); Golden Sun walks the actor
  array. Never cache a sprite's tile and draw it later: the game reuses OBJ tile slots, so a remembered
  tile shows another actor's pixels. Draw a real sprite only when the game's own OAM has an entry at
  the predicted spot (it supplies size, palette, flip; accept rotation/scale-mode entries); otherwise
  draw nothing.
- Say in `NOTES.md` which releases are checked; US-only is fine if unknown releases return `nil`.

### Ambient: decide the place cheaply

`ambient()` runs 4×/s with a 2 ms budget, so classify the place with one or two reads:

- **Emerald:** `gMapHeader.mapType` → outdoors (town/city/route/ocean) vs inside (indoor, underground,
  secret base), anything else gets the grade only.
- **Golden Sun:** no map type, so detect "in the world" from `DISPCNT` (mode 0 with BG1–3 on) and
  whether the three BG scrolls are one layer-width apart (wrapped in `pcall`); inside = mode 0 but not
  the world; battles and cut scenes get the grade only.
- Build `OUTDOORS`, `INSIDE` and `GRADE` once at load and return the table, never a fresh one per call.
- Per-game tuning: Emerald `saturation 1.08`, `clouds 0.35`, `cloudSize 180`; Golden Sun (softer, muted)
  `saturation 1.1`, `contrast 1.06`, `clouds 0.3`, `cloudSize 220`; Minish Cap `saturation 1.06`.

### Interactive without a keyboard: Emerald's battle and dex

- **Battle controls** write the game's cursor (`gActionSelectionCursor`, `gMoveSelectionCursor`) from
  `actions.setAction(i)` / `setMove(i)`; the player still presses A in the game. Safer than a trigger
  write: the companion proposes, the player commits. Needs `memory-write`, the Settings switch and the
  prompt; confirm the addresses by watching `battle.act*` follow the in-game cursor before shipping.
- **Paged lists keep their window in Lua** (`actions.dexPage(delta)`, `dexSelect(n)`): 24 entries a
  page instead of 386, and `update()` reads the dex only while `ui.page == "dex"`, caching otherwise.
- **Gate expensive reads** by page and by tick (`bag/badges/dex every 8 ticks`; the map only while the
  map page is open and the overworld is on screen).
- **Live picture with `gfx.layers`**: size the view to the budget. Emerald's 480 px map exceeded the
  25 ms per-call limit on big routes and flickered; it now draws ≤ 320 px (~53k px), shrinks 48 px
  (floor 176) whenever a draw is cut off, and keeps the old picture until two draws agree. Show a
  friendly placeholder text when the call errors.
- **Debug trick:** `log()` is capped per call, so put the last render result on the card
  (`map.note`) to see what the script sees on the device.

### Visual structure that tested well

- **Console look from the game's menus** (Emerald): a shared header band (page name + ring dots,
  clock, money, dex count, badge gems), cream windows with lilac tabs, a team strip, and detail pages
  one tap away. Generate the repeated chrome with `art/layout.mjs`.
- **Breathing room:** page padding and gaps ~10 dp, fewer elements per card, no labels under 8 px.
  Trainer-card scale that read well on the Thor: labels 11 px, values 30 px, icons 26 px.
- **Pill / tab labels:** `text-align: center` works on `tab`.
- **Tiny packs can still delight:** Golden Sun reaches an attractive result with CSS only (0 images):
  blue window frames, a pink bar for the current tab, Djinn/Psynergy icons from the ROM.

### Read the game's own data, don't type it

Emerald reads names, base stats, move data, descriptions and region-map entries from the ROM at
runtime (offsets found by matching text/structs in a real ROM) and ships only what can't be read
(`game_data.lua`: national dex mapping, TM/HM, contest data, built by `art/build-data.py`). Less to
maintain, no copyright baggage, and it follows the player's language.
