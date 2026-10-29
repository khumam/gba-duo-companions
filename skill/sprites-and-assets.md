# Sprites and assets in a companion

Every picture on the companion screen is an `image` widget (or a CSS `background-image`)
whose source is a bitmap. The engine decodes bitmaps only: **no SVG**. There are three
ways to get a bitmap, and the three reference packs each lean on a different one.

| Strategy | Pack | Where pixels come from | Cost |
|---|---|---|---|
| **A. Shipped sprite files** | Pokémon FireRed/LeafGreen | PNGs in `assets/` (PokeAPI gen-III sprites) | Zip size (387 files in `assets/pokemon`), third-party art in repo |
| **B. Drawn from the player's ROM at runtime** | Zelda Minish Cap, Pokémon Town Map | `gfx.sprite` / `gfx.tilemap` / `gfx.decode` in Lua | Needs verified addresses per region; pack ships no game art |
| **C. Original art** (code-drawn PNG or pure CSS) | Zelda UI chrome, Pokémon UI glyphs, Golden Sun | `art/*.mjs` → `assets/ui/*.png`, or CSS shapes | Your own time; always legal |

Most packs mix: B or A for *game* things (items, characters, maps), C for *interface*
things (frames, textures, icons, markers).

## What goes where (decision order)

1. **Interface chrome** (panels, textures, gems, rivets, leaves, header glyphs) → **C**.
2. **Game things** the ROM stores as plain tiles/sprites with findable addresses (item
   icons, hearts, maps, logos) → **B**. Zelda does all 75 item icons, the world map, Link,
   hearts, Ezlo and the title logo this way.
3. **Game things** that are hard to extract (hundreds of Pokémon, compressed/palette-swapped
   data) → **A**, credited, or **B** for a few (FireRed's Town Map is ROM-drawn, 386 mon
   sprites are PNGs).
4. **State colour/identity** with no real art (Golden Sun's elements, portraits) → **C in
   CSS**: coloured dots, a big initial letter in a framed square.

Always have a fallback: when `gfx.*` fails or the game code is unknown, return an
`asset:` path to drawn art (`rom_gfx.link() or "asset:ui/mark-link.png"`).

## How an image gets into the layout

```json
{ "type": "image", "class": "ic", "src": "asset:ui/ic-pin.png" }      // fixed file
{ "type": "image", "class": "sprite", "src": "$sprite" }               // key from Lua
{ "type": "image", "class": "link", "src": "$icons.linkHead" }         // nested path
```

Accepted `src` forms: `asset:<path under assets/>`, `gfx:<key>` (what `gfx.*` returns),
or `"$path"` resolved from the returned table (the value is itself `asset:...` or `gfx:...`).
Inside a `list` template `"$src"` / `"$sprite"` / `"$icon"` refer to the item's fields.

Lua returns the key, never a path to compute in the layout:

```lua
local function sprite(dex, back)                  -- Pokémon
  if dex <= 0 then return "" end
  return "asset:pokemon/" .. (back and "back/" or "") .. dex .. ".png"
end
types = { { name = "FIRE", src = "asset:types/fire.png" } }          -- list of images
badges[#badges+1] = { src = "asset:badges/" .. n .. ".png", earned = e, locked = not e }
hearts[#hearts+1] = { src = rom_gfx.heart(quarters) or "" }           -- Zelda, ROM-drawn
```

Empty string = nothing drawn; pair it with `visibleIf` / `classIf` so empty slots look
intentional (dimmed socket, dashed outline).

## Strategy A: shipped sprite sets (Pokémon)

`art/fetch-sprites.mjs` downloads once, skips files that exist, and keys everything by
**the id the game stores in RAM**, so Lua never needs a lookup table:

```
assets/pokemon/<dex>.png        front, 64×64, national dex
assets/pokemon/back/<dex>.png   back sprite (battle: the player's side)
assets/types/<type>.png         type label 32×12  (name → file)
assets/badges/<1-8>.png
assets/items/<item id>.png      keyed by the in-game item id; tm.png / hm.png shared
assets/dock/<page>.png          nav icons (borrowed item art)
```

Tips from that script: slug maps for irregular names, a hand list for IDs past the table,
concurrency 12, report names not found. Keep sprite and label sizes at their native size
and scale with CSS (see below).

CSS (Pokémon): sprites have transparent margins, so frame them in a smaller slot and let
the art spill over:

```css
image { image-rendering: pixelated; }
.sprite-slot { display: stack; place-items: center; flex-shrink: 0; }   /* box + image */
.sprite-s { width: 40px; height: 32px; }
.sprite-s .sprite { width: 52px; height: 52px; }   /* 64 px source, scaled down, overflows slot */
.sprite-l { width: 60px; height: 56px; } .sprite-l .sprite { width: 64px; height: 64px; }
.sprite-xl { width: 76px; height: 72px; } .sprite-xl .sprite { width: 80px; height: 80px; }
.type-img  { width: 48px; height: 18px; image-rendering: auto; }  /* label art: smooth ok */
.badge-img { width: 26px; height: 26px; image-rendering: auto; }
```

Rule of thumb: a 64×64 mon at 64–80 px is 1×–1.25× ⇒ fine; fractional scaling is OK if
the sprite is not dominated by single-pixel lines. Use a different slot size per context
(list row `s`, card `l`, detail `xl`, dex tile 64).

## Strategy B: ROM-drawn graphics (`gfx.*`)

API (app `docs-packs/companion-pages.md`, "Pictures from the game"). Each call returns an
image key; the result is cached by argument, so **call it every tick** and keep only the
arguments in Lua.

```lua
gfx.decode  { tiles=, palette=, width=, height=, lz77= }          -- one tile sheet
gfx.tilemap { tiles=, map=, palette=, stride=32, x=, y=, width=, height=, opaque=true, lz77= }
gfx.sprite  { tiles=, palette=, width=, height=, parts={ {x,y,w,h,tile,bank,hflip,vflip}, ... } }
```

- 4bpp tiles, 32 bytes each; palette bank *n* = 32 bytes after bank 0; colour 0 is
  transparent in sprites; images ≤ 256 × 256; ≤ 32 parts; 96 images cached.
- Budget: 1 M Lua instructions / 25 ms per update; every pixel drawn (uncached) costs one.
  Build argument tables once, lazily, cache `false` for "no art here".
- Wrap in `pcall`; log and return nil so the layout falls back.
- Identify the release first: `mem.u8(0x080000AC + i)` for 4 chars → table of addresses
  per game code. EU/US/JP all differ.

### Recipe: an icon from the game's own sprite table (Zelda `rom_gfx.lua`)

The game stores, per item id: animation → frame → object list → tiles + palette bank.
`frameArgs()` turns that into `gfx.sprite` args:

1. `anim = mem.u32(anims + id*4)`; reject if not in ROM (`0x08000000–0x0A000000`).
2. `frame = mem.u8(anim)` (0xFF = none); `firstTile = mem.u16(frames + frame*4 + 2)`.
3. Object list: count, then 5 bytes each `(x, y, flags, tile, high)`:
   - size from `flags >> 6` (shape) and `(flags >> 4) & 3` (size) → 8×8 … 64×64
   - flip bits in `flags & 4/8`; palette bank from `high >> 4` (+ a base if flags bit 0 clear)
4. Normalise positions by min x/y; canvas = max extent.
5. Skip objects the game fills at runtime (the ammo counter).

How the addresses were found: save a state on the game screen, read VRAM/OAM/palette
RAM for tile numbers and banks, then locate the matching bytes in the ROM; confirm
against a decompilation (zeldaret/tmc `gfx.json`/`assets.json` give US addresses and
EU/JP offsets) and check pixel-for-pixel. Document the evidence in `NOTES.md`.

### Recipe: a map or background (`gfx.tilemap`)

Zelda's world map = BG1 tiles + 32-wide tilemap + palette banks 6–12; cells 5..24 × 1..16
⇒ 160×128 px, `opaque=true`. FireRed's Town Map is LZ77 (`lz77=true`). Overlay markers
(crosshair, Link's head, pins) as absolutely-positioned children of a `position:
relative` wrapper, positioned by percentages from Lua (`x / 0xF90`, `y / 0xC60`).

### Recipe: a logo or large art from many sprites

List the OAM objects as `parts` with absolute `x,y` and consecutive tile numbers
(Zelda title logo: 14 parts, three palettes). If the logo differs per region (JP), return
nil for it and show a text title.

### Sizing ROM sprites

Source sizes are tiny (8, 16, 29×28, 32). Size in whole *device* pixels, then convert:
`dp = device_px × 0.4336`. Comments in `style.css` should record the ratio.

```css
.ditem-icon  { width: 20.81px; height: 20.81px; }  /* 16×16 at 3 device px per pixel */
.dkey-icon   { width: 10.41px; height: 20.81px; }  /* 8×16 at 3 device px */
.ezlo        { width: 25.15px; height: 24.28px; }  /* 29×28 at 2 device px */
.bubble-ezlo { width: 37.72px; height: 36.42px; }  /* 3 device px per pixel */
.link-sprite { width: 55.50px; height: 41.63px; }
.equip-icon  { width: 38px;    height: 38px; }
```

Integer device-px scaling keeps pixel art crisp; `image { image-rendering: pixelated }`
is the default and should stay for ROM art.

## Strategy C: original art

### C1. Pixel art as palette-character rows → PNG (`art/<name>-os.mjs`)

Used by Zelda (`minish-os.mjs`) and Pokémon (`pocket-os.mjs`): each sprite is rows of
characters mapped to colours, written to PNG at `SCALE`× (3–4) with nearest-neighbour
blocks, using a ~30-line zero-dependency PNG encoder. Textures tile (`leather`, `wood`,
`parchment`, `canopy`, `ground`); icons are 8–16 cells (`ic-pin`, `ic-clock`, `rupee`,
`gem-a/b`, `rivet`). Run `--sheet` for a contact sheet, and look at it on the real
background colour (leaves vanish on dark, white on light).

### C2. SVG → PNG (`art/build.mjs`, `@resvg/resvg-js`)

For smooth ornate art (forest vines, FireRed's flames, badges, type orbs). Draw in
`art/svg/*.svg`, rasterise at 3× to `assets/img`. Pair with `image-rendering: auto`.
Shared primitives in `art-kit-forest.mjs` (glow, seeded random, mix, leaf, vine); the
Pokémon minimal pack's `art/svg/` holds badge, orb, divider and pocket icons the same way.

### C3. CSS only (Golden Sun, v0.1.0)

No images at all: coloured dots for elements (`.elem-dot { width:14px; height:14px;
border-radius:7px; background:var(--c); border:2px solid #fff }`), a framed square with the
member's initial as the portrait, square item boxes, gradient window fills, `box-shadow:
0 2px 0` for depth. Fast and light; next step when art is needed is B (the game's Djinn
and item sprites are ROM data) rather than a hand-drawn set.

### Using textures

```css
#screen { background-color: var(--forest); background-image: url("assets/ui/canopy.png");
          background-size: 48px 48px; }                    /* tile: fixed px, not % */
.header { background-image: url("assets/ui/leather.png"); background-size: 16px 16px; }
.equip-a .equip-ring { background-image: url("assets/ui/gem-a.png"); background-size: 100% 100%; }
```

Prefer `background-size` in px matching a whole-pixel scale (Pokémon ground:
`5.2px 5.2px` = 12 device px). `100% 100%` is flaky: use fixed `px` boxes.

### Overlays and layered sprites

```css
.sprite-slot, .equip-ring { display: stack; place-items: center; }  /* image over frame */
.parent { position: relative; } .badge { position: absolute; left: 0; bottom: 0; }
```

- Letter-on-badge, icon-in-ring, count-on-icon: `display: stack` + `place-items`.
- Corner ornaments, markers, notification dots: `position: absolute` inside a
  `position: relative` parent.
- State: `.missing .icon { opacity: .25 }`, `.locked { opacity: .45 }`; "owned" gets a gold
  border or `classIf`.
- Per-item tint without new art: `bindStyle: {"--c": "{color}"}` on the container.

`preview-pack.sh` renders `asset:` images with the real decoder, so the sizing and crispness
of strategy A and C sprites can be judged on the Mac; `gfx:` keys need a ROM, so check those on the device.

## Sprite checklist before shipping

- [ ] Every image has an explicit `width`/`height` in CSS (size explicitly; don't rely on the bitmap's own size).
- [ ] `image-rendering` is right: pixelated for pixel art, `auto` for SVG-rendered.
- [ ] ROM-drawn images have a drawn/`""` fallback and are called every tick.
- [ ] Per-region address table keyed by game code; unknown code ⇒ fallback, not crash.
- [ ] Empty slot, unowned, and unknown-id states exist (`item-unknown.png`, `ic-lock`).
- [ ] Third-party art: credited in README and removable; or none shipped (preferred).
- [ ] Zip excludes `art/` sources; `assets/` holds only what the layout references.
