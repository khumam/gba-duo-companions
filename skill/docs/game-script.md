---
title: game.lua, Wide view and Ambient
description: Run a script against the game every frame, describe the world so GBA Duo can paint it beside the picture, and give the picture a look with Ambient.
---

A pack's `main.lua` feeds the companion screen. A pack can also ship a **`game.lua`** that
runs against the game itself, every emulated frame, in its own Lua sandbox (its own globals,
budgets and errors: a broken `game.lua` never touches the companion screen).

```json
{
  "formatVersion": 4,
  "gameScript": "game.lua",
  ...
}
```

`gameScript` needs `formatVersion` 4 (older apps refuse the pack; set `minAppVersion` in the
catalog). The file must exist in the pack. It is part of the pack's fingerprint, so changing it
asks the player again before it may write.

## Hooks

All optional. The sandbox is the same as `main.lua`'s (`mem`, `gfx`, `lz77`, `log`,
`pack.require`).

| Hook | When | What it's for |
|---|---|---|
| `init()` | once, after load | set up state. Read-only. |
| `frame(view)` | after each emulated frame | read and, if allowed, write the game's RAM |
| `wide(view)` | after each emulated frame, only while **Wide view** is on | describe the world for the wide margins. Read-only. |
| `ambient()` | four times a second, only while **Ambient** is on | the look of the game: colour grade and light. Read-only. |

`view` is a table: `frame` (the frame counter, `frame()` only), `width` (the picture's width in
pixels), `height` (the picture's height), `left` and `top` (columns before and rows above the game's
own 240x160), and for `wide()` also `match` (0 to 1, how well last frame's world predicted the game's
edge pixels; handy while calibrating).

Each hook gets 100,000 Lua instructions and 2 ms per call. An error or an overrun skips that
frame's call (`adb logcat -s GBADuoScript GBADuoCore EmuThread`); five in a row switch `game.lua`
off until the next game start.

## Writing the game's memory from frame()

Same rules as actions (see [Changing the game](/docs/pages#changing-the-game)):
`"permissions": ["memory-write"]`, **Settings > Packs can change games**, and the player's answer
for this pack and game. Until they have answered, `frame()` runs with writes refused
(`mem.write8` and friends return `false` and a reason). The same RAM-only regions apply.
What differs: at most **256 bytes per frame**, and only the first write is logged.
`init()`, the top level and `wide()` can never write.

## wide(view): painting more of the world

Wide view draws the game's own 240x160 frame in the middle of a bigger picture and paints the margins
from what `wide()` describes. In **Wide** the picture is wider (up to 400 px, set from the screen) and
the margins are the sides. In **XL** it also grows taller (up to 480x320, the screen's shape), so the
frame sits in the middle at about two thirds size and the margins surround it: `view.top` rows above
and below, `view.left` columns each side. `x`, `y` stay the world pixel of the *frame's* top-left, so a
world that reads outside the frame needs nothing different for XL (it just gets asked for negative
rows). Beyond the map the margins are black or your border, as before. Return `nil` or `false`
for "no world right now" (battle, menu, unknown map): the margins stay black. Otherwise return a
table, every field an integer (bus addresses are plain numbers):

| Field | Meaning |
|---|---|
| `x`, `y` | world pixel of the screen's top-left |
| `grid`, `gridW`, `gridH` | the map: u16 cells, row-major, one 16x16 metatile each |
| `idMask` | metatile id = cell & `idMask` |
| `border`, `borderW`, `borderH` | block repeated outside the map |
| `borderShift` (optional, 0) | the block index of cell `c` is `(c - borderShift) mod size` |
| `undefinedId` (optional, none) | a cell with this id is outside the map: use the border |
| `finite` (optional, 0) | `1`: the grid is the whole world, like a layered world's: near its edge the wide picture stops scrolling and the game's frame moves toward the edge, so the margins never run past the grid, and what is outside it is black, not the border (a grid smaller than the picture stays still, the empty part split evenly). `0`: the border repeats forever |
| `overscan` (optional, 0) | with `finite` 0: `> 0` limits the repeating border to this many px beyond the defined cells. The wide picture stops scrolling there and the game's frame moves toward the edge; farther out is black. `0`: the border repeats without limit |
| `metatiles`, `metatiles2`, `split` | ids below `split` read from `metatiles`, the rest from `metatiles2` (16 bytes each) |
| `tiles` | 4bpp tile data, 32 bytes a tile (normally VRAM `0x06000000`) |
| `palette` | 16 banks of 16 BGR555 colours (normally `0x05000000`) |
| `markers` (optional) | up to 64 icons painted over the margins, never over the game's own frame: `{ x, y, kind }` with `x`, `y` a world pixel (same space as the world's `x`, `y`) and `kind` 1 NPC (white), 2 trainer or enemy (red), 3 item (yellow) or 4 door/warp (cyan), drawn as a diamond centred on `x`, `y`. Add `tiles`, `palette`, `w`, `h` (and optionally `hflip`) to draw a sprite instead: `tiles` and `palette` are bus addresses of 4bpp tile data in the GBA's 1D order and of 16 BGR555 colours (index 0 clear), `w` x `h` the size in pixels (multiples of 8, 8 to 64), and `x`, `y` the sprite's top-left. A sprite made of several OAM pieces is several markers. Works for single-grid and layered worlds. A bad entry or more than 64 is an error like any other bad field |

A metatile is 8 u16 tile entries: bottom layer TL, TR, BL, BR, then top layer TL, TR, BL, BR.
A tile entry: bits 0-9 tile, 10 h-flip, 11 v-flip, 12-15 palette bank. A pixel is the top
layer's if that is not colour 0, else the bottom layer's, else the backdrop.

### Several layers (`layers`)

A game whose map is separate grids (e.g. The Minish Cap, Golden Sun) returns `layers` instead of the
single-grid fields above: `{ x, y, palette, layers = { bottom, ..., top } }` (one to three tables,
bottom first). Each layer has its own grid, its own metatile table and its own tile data:

| Layer field | Meaning |
|---|---|
| `grid`, `stride`, `gridW`, `gridH` | cells, row-major, `stride` cells a row, `gridW` x `gridH` of them in use |
| `cellBytes` (optional, 2) | 2 for u16 cells, 4 for u32 cells (the id is the cell's low bits, see `idMask`) |
| `idMask` | metatile id = cell & `idMask` |
| `special` (optional, 0) | a u16 table: a u16 cell >= `0x4000` reads its id from `special[cell - 0x4000]` |
| `metatiles` | 4 u16 tile entries (TL, TR, BL, BR) per id, 8 bytes each |
| `tiles` | 4bpp tile data for this layer (its BG's character base) |

The top layer's pixel wins unless it is colour 0, then the bottom layer's, else the backdrop
(`palette` colour 0). Beyond the grids the margins are black. `x`, `y` are relative to the grids' origin.

The app checks your answer against the game: the 16 columns on the frame's edges (and, in XL, the 16 rows
on its top and bottom edges) are predicted and compared with what the emulator drew (a colour within about
40 per channel counts as the same, so the game's own shadows and fades don't hide the margins). Below 85% for four frames in a row the margins hide,
and they come back after four good ones. So a wrong world looks like "no wide view", not like
garbage. NPCs and the player are not part of the world, so they don't appear in the margins.

### Turning Wide view on and off

Wide view is a per-game setting the **player** switches from the pack's companion screen, so give
the layout a button. The app handles the reserved action `wideView` itself (your Lua is not
involved): `"args"` is `"on"` (wide), `"extra"` (XL), `"off"` or `"toggle"` (the default; steps off, wide,
XL, off). Every snapshot carries the state as built-in values: `_wide` (1 for wide or XL, else 0),
`_wideMode` (0 off, 1 wide, 2 XL) and `_wideLabel` (`ON`, `XL`, `OFF`, or `N/A` when the
pack has no `wide()`).

```json
{
  "type": "box", "class": "wide-pill",
  "onClick": { "call": "wideView", "args": ["toggle"] },
  "children": [ { "type": "text", "text": "WIDE {_wideLabel}" } ]
}
```

## ambient(): the look of the game

**Ambient** (kept per game, like Wide view) gives the picture the pack's own look. The app has the
effects; the numbers are the pack's, so a pack without `ambient()` gets no look at all (the button shows `N/A`).
`ambient()` returns a table, or `nil` / `false` for the plain picture here. Every field is optional and its default
changes nothing, so a field left out is an effect left off:

| Field | Default | What it does |
|---|---|---|
| `saturation`, `contrast`, `brightness` | 1 | the colour grade (0 to 3) |
| `tint` | `{ 1, 1, 1 }` | a multiplier per channel, `{ r, g, b }`, each 0 to 2 |
| `vignette`, `vignetteColor` | 0, `{ 0, 0, 0 }` | how far (0 to 1) the edges sink toward that multiplier |
| `sunSlope` | 0 | the top left this much brighter than the bottom right (-1 to 1) |
| `shadow`, `shadowLength`, `shadowColor` | 0, 8, `{ 1, 1, 1 }` | sprites throw shadows toward the bottom right, up to `shadowLength` game pixels (1 to 16); a full shadow multiplies the picture by `shadowColor` |
| `rim`, `rimColor` | 0, `{ 1, 1, 1 }` | light added on the edges that face the sun |
| `crease` | 0 | darkening where things meet the ground |
| `bloom` | 0 | bright pixels glow |
| `haze` | 0 | the backdrop sinks into a cool haze |
| `clouds`, `cloudSize`, `cloudSpeed` | 0, 150, 1 | cloud shadows (in `shadowColor`) drifting over the ground, `cloudSize` game pixels across (16 to 1024), pinned to the map as the camera moves |

The light (`shadow`, `rim`, `crease`, `haze`, `clouds`) knows what stands in front of what: on GBA the app follows
which of the game's own layers drew each pixel (sprites in front of the backgrounds, the backgrounds by priority). On
GB and GBC only `shadow` works, from dark outlines. The app asks again four times a second, so the look can follow the
place: return another table indoors, in a cave, at night. Keep it in a file of its own and let `game.lua` hand it over,
like `ambient = pack.require("ambient").ambient`; `pokemon-emerald-companion/ambient.lua` is the example (clouds only
under an open sky, read from the map's type).

### Turning Ambient on and off

Ambient has no switch in the app's menus: the pack offers it with a button, so a pack with `ambient()`
should have one. The app handles the reserved action `ambientView` itself: `"args"` is `"on"`, `"off"` or `"toggle"` (the default).
Every snapshot carries `_ambient` (1 or 0) and `_ambientLabel` (`ON`, `OFF`, or `N/A` when the pack has no `ambient()`).

```json
{
  "type": "box", "class": "wide-pill",
  "onClick": { "call": "ambientView", "args": ["toggle"] },
  "children": [ { "type": "text", "text": "COLOR {_ambientLabel}" } ]
}
```

`zelda-the-minish-cap-companion/game.lua` is the two-layer example (camera and room origin from
`gRoomControls`, layers from `gMapTop` / `gMapBottom`). `golden-sun-companion/game.lua` is the
three-layer one with u32 cells: one grid in EWRAM holds the three BG layers side by side, so each
layer's `grid` starts at its block of columns and all three share the same `x`, `y`. 

Markers: `pokemon-firered-companion/game.lua` reads the map's NPCs from the ROM event table, `zelda-the-minish-cap-companion/game.lua` walks the game's entity array and draws each enemy and NPC as its real sprite (the OAM piece list from the ROM's frame table, tiles live from OBJ VRAM), and `golden-sun-companion/game.lua` walks the actor array and draws a sprite only while the game has the actor on screen (it reuses its OBJ tile slots), a diamond otherwise.

`pokemon-firered-companion/game.lua` is a worked example (FireRed 1.0, also `markers`: the map's NPCs, trainers, items and doors read from the ROM event table, hidden once their save flag is set): it reads the map the
game keeps in RAM (`gBackupMapLayout`) and the tilesets from the ROM layout. It follows the camera
from the BG scroll registers (`mem.u16(0x04000014)`), anchored whenever the player stands still,
and keeps following across a map connection: the game rebases the tile coordinates there (the
player's current and previous tile, by the same whole number of tiles) while the scroll carries
on, so the script recovers the rebase from where the camera sits between those two tiles. Set
`DEBUG = true` at the top to log the frames where the prediction misses (`adb logcat -s GBADuoPack`).

## Drawing the live map on the companion screen

`gfx.layers{...}` (in `main.lua` too) draws the same layer description as a picture, so a pack
can show the player an area map: see [`gfx.layers`](/docs/lua#gfxlayers). Golden Sun's Maps
page uses it, with the player's marker placed on top by the layout.
