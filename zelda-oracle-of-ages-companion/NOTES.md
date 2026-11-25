# 0.2.0 (2026-11-24): a Clean style with themes, next to the brick one

- **Switch:** the brick look is unchanged and still the default. A LOOK / CLEAN plate at the bottom of the left pillar opens the clean
  style; its Options page has STYLE (Brick / Clean) and THEME (Present / Past / Night). UI state only, so every launch starts as Brick.
- **Clean layout** = the Minish Cap pack's slate (top bar, a 347.1 dp master of 65.42 dp cells in 5 columns, one inspector holding the
  text), in the game's own identity taken from `art/reference/` (the pause screen): the off-white panel as the surface, brick mauve
  hairlines, the peach HUD strip as the top bar carrying B [ ] / A [ ], rupees and hearts like the game's HUD, the game's [ ] bracket
  cursor as the selection, the game's item icons as the tabs, Press Start 2P + Jersey 10. Pink is the one accent (active page, the
  inspector line, the explored meter).
- **Pages:** Items (16 slots padded to 5 x 4, B / A cards), Map (era map, unseen rooms shaded, Link's room, explored meter), Seeds
  (tall pouches, S = the satchel's seed, supplies), Rings (all 64, tap for the name, worn ring and ring box in the inspector), Status
  (hearts, pieces, the eight essences, explored / song / room), Options.
- **Files:** `art/clean.mjs` (layout, page names citems ... coptions, they share the brick pages' `page` state so the switch also
  sets the page), `art/clean.src.css`; `style.css` is now generated: `python3 art/build_css.py && node art/layout.mjs`
  (brick source in `art/style.brick.css`). `art/clean_glyphs.py` draws the map and options tab glyphs. `main.lua` adds the style /
  theme flags and clean-only fields at its end (`ringList`, selections, `explored`, ...).
- Previews: `lua art/make_preview_data.lua PAGE OUT.json "style=clean,theme=past,..."` (third argument = extra ui keys).
  Not checked on a device yet.

# Zelda: Oracle of Ages companion — build notes

## Brick redesign on the Minish Cap frame (not versioned yet, not checked on a device)

- **Frame:** two brick pillars and a brick-rimmed window with the pause screen's off-white panel. Everything else lives on the
  pillars: rupees and the B item on the left, hearts and the A item on the right, and under A and B one upright brick slab per
  page (three on the left, two on the right with an ERA plate below), so all five pages are one tap away and the window takes
  the full height (this is what sets it apart from the Minish Cap pack, which has a bottom nav). The label is turned 90 degrees.
  The game's own HUD strip is gone. Art: `python3 art/brick_ui.py` (reuses the Minish Cap pack's `art/stone_ui.py` helpers, so
  that pack's folder must sit next to this one). Layout: `node art/layout.mjs`.
- **Icons:** the item and seed icons sat in the left half (or top-left corner) of their 16 x 16 frames, off-centre in any slot;
  `python3 art/center-icons.py` moves them to the middle. Icons are shown at whole device-pixel steps (27.75, 34.69, 55.5dp).
- **Status page:** the era moved to the ERA plate, so the third fact is EXPLORED (rooms seen in this era, of 196). The eight essences now carry names (Eternal Spirit, Ancient Wood, Echoing Howl, Burning Flame, Sacred Soil,
  Lonely Peak, Rolling Sea, Falling Star). The bit order is assumed to be the dungeon order; unverified on a save.
- **Fonts:** Jersey 10 for labels, Press Start 2P for numbers; Silkscreen is gone.
- **Previews:** `lua art/make_preview_data.lua [page [out.json]]` runs `update()` on fake RAM for `preview-pack.sh --data`.
- **Not done:** drag and drop for A / B (needs the memory-write permission and an `equip` action), dungeon keys and maps,
  ring names on tap. The original look is in `art/backup-before-brick-redesign.tar.gz`.

Sources: the [oracles-disasm](https://github.com/Stewmath/oracles-disasm) project's `include/wram.s`
(each Ages address is the first of the two it lists; the second is Seasons) and
`constants/common/{treasure,rings}.s` for item and ring ids.

Checked on a Thor (European `CGB-AZ8P`, new file, 2026-10-30): max health/health ($C6AA/$C6AB, quarter
hearts), max bombs ($C6B1), ring box ($C6C6, five 0xFF), active ring ($C6CB), treasure flags ($C69A) and
the active group ($CC2D) read as the file should.

Also checked (early field state): B ($C688) and the inventory list ($C68A): the sword sits there only while
it is not on B or A, so the pack lists the B and A items first.

Not checked yet: the item ids in `ITEMS` beyond the sword, seeds, satchel selection,
rings obtained ($C616), essences ($C6BF), harp song, rupees (BCD at $C6AD), heart pieces.

Look: the pause subscreen (mauve brick window, off-white panel, bracket cursor) around the pages, the
peach HUD strip on top. `node art/layout.mjs` writes `layout.json`; `node art/ages-os.mjs` draws the
placeholder icons. Real icons are cut from a capture of the game with
`python3 art/grab-icon.py <capture.png> <name> <gx> <gy> <w> <h> [bg-hex ...]` (sword and rupee so far;
the rest are still my own 8x8 drawings). `art/reference/` holds the captures the look came from.

Map: `art/render-map.py <oracles-disasm checkout>` draws the two overworlds (`assets/ui/map-present.png`,
`map-past.png`, 14 x 14 rooms of 56 x 45 px) from the disassembly's room layouts, tileset mappings, gfx
headers, tile art and palettes (the layout group comes from the tileset's byte 6, bg palettes 0-1 from
PALH_0a, the LCD colour mix mGBA uses). The companion dims rooms whose visited flag (bit 4 of
$C700 + room present, $C800 + room past) is clear. GBC games can't draw ROM graphics at runtime (gfx.* is
GBA only), so these PNGs ship in the pack. Not checked on the device yet.

Rings: the 64 icons are cut from `art/reference/rings.bmp` (a sheet of the game's ring sprites, names in
`rings.txt`) by `python3 art/crop-rings.py`. Reading gfx_rings.png and map_rings.bin from the disassembly
(an earlier try, since removed) got the layout right but not the colours.
