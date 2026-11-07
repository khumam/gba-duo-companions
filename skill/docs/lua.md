---
title: Lua API
description: Everything a companion script can call, including memory reads and writes, drawing the game's graphics, modules and limits.
---

A pack's script is Lua 5.4, run by GBA Duo in a small sandbox. It reads the game's
memory and returns the values the layout shows.

## `update(ui)`

GBA Duo calls the global `update` function `tickHz` times a second (from the
manifest, 4 by default, up to 30). The table it returns becomes the snapshot the layout
binds to.

```lua
function update(ui)
  return {
    hp = mem.u16(0x02001234),
    party = { { name = "Red", level = 5 } },
  }
end
```

- `ui` is the [UI state](/docs/pages#ui-state): the shown page and any keys taps set.
  It's also available as the global `ui`.
- Return strings, numbers, booleans, and tables of them, nested up to 32 levels. A table
  with keys 1..n becomes an array (for `list`); other tables become objects.
- A `ui` entry in the returned table [changes pages](/docs/pages#changing-pages-from-update)
  instead of becoming data.
- If `update()` throws, the snapshot gets `_scriptError` with the message, and the
  error is logged under `EmuThread`.

Script-level code (outside functions) runs once when the pack loads. Use it for
constants and lookup tables; locals there keep their values between ticks.

## `init()`

An optional global `init` function runs once, right after the script loads, each time
a game starts. It gets the bigger loading budget (see [limits](#the-sandbox)), so it's
the place to build data tables from the ROM.

## Reading memory

All reads are little-endian, from the GBA's address space: EWRAM (`0x02000000`),
IWRAM (`0x03000000`), I/O, and the cartridge ROM (`0x08000000`).

| Function | Returns |
| --- | --- |
| `mem.u8(addr)`, `mem.s8(addr)` | Unsigned / signed 8-bit value |
| `mem.u16(addr)`, `mem.s16(addr)` | Unsigned / signed 16-bit value |
| `mem.u32(addr)`, `mem.s32(addr)` | Unsigned / signed 32-bit value |
| `mem.read(addr, n)` | `n` raw bytes as a Lua string (at most 65,536) |

Reads return 0 when no game is loaded.

Each byte `mem.read` returns counts as one instruction against the script's
[time limit](#the-sandbox), so reading big blocks every tick isn't free.

To change the game's memory, see [`mem.write*`](#writing-memory).

```lua
-- A pointer, then a field behind it
local sb1 = mem.u32(0x03005008)
local money = mem.u32(sb1 + 0x290)

-- A block of bytes, decoded with string.unpack
local raw = mem.read(sb1 + 0x310, 4)
local itemId, qty = string.unpack("<I2I2", raw)
```

## `lz77(addr)`

Decompresses GBA BIOS-style LZ77 data (type `0x10`) starting at `addr`, usually in ROM,
and returns it as a string. Output is limited to 1 MB; invalid data raises an error.

## Drawing the game's graphics

A pack can draw the game's own graphics on the companion screen, read from the
player's ROM at runtime, so the pack doesn't ship them. Each `gfx` function returns an
image key like `"gfx:1a2b3c4d"`: return it from `update()` and bind it as an `image`'s
`src`. Images are decoded once and cached, so calling them every tick with the same
arguments is cheap.

| Function | Draws |
| --- | --- |
| `gfx.decode{...}` | A sprite sheet: 4bpp tiles laid out row by row |
| `gfx.tilemap{...}` | A background: tiles placed by a tilemap, like the GBA draws it |
| `gfx.sprite{...}` | A sprite: 4bpp tile blocks (OBJ-style, 1D mapping) placed on a canvas |
| `gfx.layers{...}` | The game's live map, read from RAM: the same world [Wide view](/docs/game-script) describes (layers, or one grid as in the Pokémon games), as a picture |

### `gfx.decode`

```lua
-- Example addresses: find the real ones for your game
local icon = gfx.decode({
  tiles = 0x083D4294,   -- address of the tile data
  palette = 0x083D3740, -- address of a 16-color BGR555 palette
  width = 32,           -- multiples of 8, at most 256
  height = 32,
  lz77 = false,         -- true if the tile data is LZ77-compressed
})

return { icon = icon }  -- layout: { "type": "image", "src": "$icon" }
```

- Only `bpp = 4` is supported. Palette index 0 is transparent.

### `gfx.tilemap`

Maps, title screens and other backgrounds are tiles placed by a tilemap:

```lua
local map = gfx.tilemap({
  tiles = 0x08931DB0,        -- 4bpp tiles, 32 bytes each
  map = 0x08935DB0,          -- u16 entries: tile (bits 0-9), h-flip (10), v-flip (11), palette bank (12-15)
  palette = 0x085B3910,      -- palette bank 0; bank n is 32 bytes further
  stride = 32,               -- map entries per row (default 32, at most 256)
  x = 5, y = 1,              -- first map cell to draw (default 0, 0)
  width = 160, height = 128, -- in px, multiples of 8, at most 256
  opaque = true,             -- draw colour 0 too (default: transparent)
  lz77 = false,              -- true: tiles and map are both LZ77-compressed
})
```

### `gfx.sprite`

Characters and objects are built from blocks of tiles, the way the GBA draws sprites:

```lua
local sword = gfx.sprite({
  tiles = 0x082E5FE0,        -- tile 0; part.tile counts 32-byte tiles from here
  palette = 0x085A23D0,      -- palette bank 0
  width = 16, height = 16,   -- the canvas, at most 256
  parts = {                  -- 1 to 32; an earlier part is drawn over a later one
    { x = 0, y = 0, w = 16, h = 16, tile = 0x1A0, bank = 3, hflip = false, vflip = false },
  },
})
```

### `gfx.layers`

```lua
-- A live map: grids of metatiles in RAM, drawn the way Wide view draws them.
-- Unlike the others it reads RAM now, so the picture follows the game.
local area = gfx.layers({
  x = 0, y = 0,                  -- world pixel of the picture's top-left
  width = 192, height = 192,     -- px, at most 512 x 512
  scale = 2,                     -- map pixels per picture pixel, 1 to 8 (default 1)
  palette = 0x05000000,          -- 16 banks of 16 BGR555 colours
  layers = {                     -- bottom first, one to three
    { grid = 0x02001000, cellBytes = 4, stride = 64, gridW = 40, gridH = 40,
      idMask = 0xFFF, metatiles = 0x02009000, tiles = 0x06004000 },
  },
})
```

Each layer is described exactly as in [game.lua and Wide view](/docs/game-script#several-layers-layers). A single-grid world (the fields of a Pokémon `wide()`, without `layers`) works too, as in the Emerald pack's Map page.
Outside the grids the picture is transparent. The key depends on the pixels, so a map that
hasn't changed gives the same key and costs nothing to ask for again; a map that moves gives
a new picture each time, so redraw it only when the view changes (Golden Sun's Maps page
follows the player a tile at a time). Put a marker on top with a positioned `box` in the layout.

### Tips for ROM graphics

- Images are at most 256 x 256 px (512 x 512 for `gfx.layers`). Up to 96 are cached (fewer when they're large); one
  dropped from the cache is drawn again when asked for.
- Colour 0 is transparent, as on the GBA (`gfx.tilemap` can draw it with `opaque`).
- Each pixel drawn (not cached) counts as one instruction against the
  [time limit](#the-sandbox).
- Addresses differ between a game's releases. Check the game code (`mem.read(0x080000AC, 4)`)
  and keep a table of addresses per release.
- Call these inside `pcall` and fall back to the pack's own art on failure, so a
  release you don't know, or a ROM hack, still gets a page:

```lua
local ok, map = pcall(gfx.tilemap, MAP_ARGS[gameCode])
return { map = ok and map or "img/map.png" }
```

The [FireRed](https://github.com/khumam/gba-duo-companions/tree/main/pokemon-firered-companion)
pack (`town_map.lua`, the compressed Town Map) and the
[Minish Cap](https://github.com/khumam/gba-duo-companions/tree/main/zelda-the-minish-cap-companion)
pack (`rom_gfx.lua`: world map, item icons, Link and his hearts) are working examples. Golden Sun's Maps page is the `gfx.layers` one.

## `pack.require(name)`

Loads `<name>.lua` from the pack's folder, once, and returns what it returns. Use it to
split a pack into modules or ship data tables.

```lua
-- item_names.lua
return { [1] = "Master Ball", [2] = "Ultra Ball" }

-- main.lua
local ITEM_NAMES = pack.require("item_names")
```

Names may use letters, digits, `_`, `-` and `.`, with no path separators or `..`, so a
pack can only load its own files.

## `log(message)`

Writes to the Android log under the `GBADuoPack` tag:

```sh
adb logcat -s GBADuoPack
```

`print` is not available; use `log`.

## `actions`

Functions in the global `actions` table can be called from a tap with
`{ "call": "name" }`. See [Script actions](/docs/pages#script-actions).

## Writing memory

With the `memory-write` permission, actions run from a tap can change the game's RAM:

| Function | Writes |
| --- | --- |
| `mem.write8(addr, value)` | 1 byte (the low 8 bits of `value`) |
| `mem.write16(addr, value)` | 2 bytes, little-endian |
| `mem.write32(addr, value)` | 4 bytes, little-endian |
| `mem.write(addr, bytes)` | A Lua string of raw bytes, 1 to 64 |

Each returns `true`, or `false` and a reason when the write was refused. The rules
(only from a tap, only work RAM, the player's consent) are in
[Changing the game](/docs/pages#changing-the-game).

## The sandbox

| Available | Removed |
| --- | --- |
| Base functions, `string`, `table`, `math`, `utf8` | `io`, `os`, `require`, `load`, `loadfile`, `dofile`, `print`, `collectgarbage`, `string.dump` |

Limits that keep a buggy script from stalling the game:

| | Instructions | Time |
| --- | --- | --- |
| Each call (`update`, an action) | 1 million | 25 ms |
| Loading (the top level and `init()`) | 5 million | 250 ms |

- Work done for the script counts too: each byte `mem.read` returns, each byte `lz77`
  outputs and each pixel `gfx.*` draws costs one instruction.
- A call that runs over is stopped with an error (in `_scriptError` for `update`), and
  the screen keeps its last state. The next call starts fresh.
- **Memory:** 16 MB for the script.

The bundled packs use well under a tenth of this per tick, so the limits only stop a
script that's stuck.

A script can't touch files, the network or anything outside the game. That's why
packs are safe to share.

## Without a script

Very simple packs can skip Lua and read fixed addresses straight from the manifest
(the addresses below are examples):

```json
"values": {
  "money": { "addr": "0x02025A0C", "type": "u32" },
  "badges": { "addr": "0x02025B2C", "type": "u8", "mask": "0x0F" },
  "hp": { "ptr": "0x03005008", "offset": 36, "type": "u16" }
}
```

| Field | |
| --- | --- |
| `addr` | Address to read (hex string), or |
| `ptr` + `offset` | read a 32-bit pointer at `ptr`, then read at pointer + `offset` |
| `type` | `u8`, `s8`, `u16`, `s16`, `u32` or `s32` |
| `mask`, `shift` | Optional: AND with `mask` (hex), then shift right by `shift` |

When a pack has both, values from `update()` win on the same key.
