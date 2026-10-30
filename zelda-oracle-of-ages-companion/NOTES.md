# Zelda: Oracle of Ages companion — build notes

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
