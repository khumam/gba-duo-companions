#!/usr/bin/env python3
"""Extracts the game's pause-screen font (A-Z, 0-9 and a few signs) from a US Metroid
Fusion ROM into assets/font/<variant>-<glyph>.png (8x8, native pixels).

  python3 art/rom-font.py "Metroid Fusion (USA).gba"

The frames, windows and tabs are NOT extracted: main.lua draws those from the player's
ROM at runtime (gfx.tilemap). Only the font is shipped, because gfx.* can't draw one
glyph from a compressed sheet. ROM offsets: bg.gfx.lz 0x56A254 (tiles 96-121 = A-Z,
128-137 = 0-9), palettes 0x5657A8 (3 rows) + 0x565808 (13 rows) = PALRAM rows 0-15.
"""
import os, struct, sys
from PIL import Image

rom = open(sys.argv[1], "rb").read()
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "font")
os.makedirs(OUT, exist_ok=True)

def lz77(off):
    size = int.from_bytes(rom[off + 1:off + 4], "little")
    out, p = bytearray(), off + 4
    while len(out) < size:
        flags = rom[p]; p += 1
        for i in range(8):
            if len(out) >= size: break
            if flags & (0x80 >> i):
                b0, b1 = rom[p], rom[p + 1]; p += 2
                ln, disp = (b0 >> 4) + 3, ((b0 & 15) << 8 | b1) + 1
                for _ in range(ln): out.append(out[-disp])
            else:
                out.append(rom[p]); p += 1
    return bytes(out)

def pal(row):
    v = struct.unpack_from("<H", rom, 0x5657A8 + row * 32 + 0)[0]
    return [tuple(((struct.unpack_from("<H", rom, 0x5657A8 + row * 32 + i * 2)[0] >> s) & 31) * 255 // 31 for s in (0, 5, 10)) for i in range(16)]

gfx = lz77(0x56A254)
GLYPHS = {chr(65 + i): 96 + i for i in range(26)}
GLYPHS.update({str(i): 128 + i for i in range(10)})
GLYPHS.update({"play": 122, "semi": 123, "dot": 126, "slash": 127, "blank": 138 + 100})  # blank filled below
del GLYPHS["blank"]
VARIANTS = {"c": 6, "m": 3}  # PALRAM rows the game draws numbers in: current / max (StatusScreenDrawNumber)
NAVY = (0x20, 0x20, 0x4A, 255)  # the status screen's bar and body backdrop

def tile(t, row, bg=None):
    colours = pal(row)
    im = Image.new("RGBA", (8, 8), bg or (0, 0, 0, 0))
    for y in range(8):
        for x in range(8):
            o = t * 32 + y * 4 + x // 2
            c = gfx[o] >> 4 if x & 1 else gfx[o] & 15
            if c == 14 and bg is None: continue  # index 14 is the navy backdrop; letters keep only strokes
            if c: im.putpixel((x, y), colours[c] + (255,))
    return im

for var, row in VARIANTS.items():
    for name, t in GLYPHS.items():
        tile(t, row).save(os.path.join(OUT, f"{var}-{name}.png"))
for var, row in VARIANTS.items():  # opaque digits that cover the placeholder numbers of the status header
    for d in range(10):
        tile(128 + d, row, NAVY).save(os.path.join(OUT, f"o{var}-{d}.png"))
Image.new("RGBA", (8, 8), NAVY).save(os.path.join(OUT, "ob.png"))
Image.new("RGBA", (8, 8), (0, 0, 0, 0)).save(os.path.join(OUT, "space.png"))
print("wrote", len(GLYPHS) * len(VARIANTS), "glyphs to", os.path.relpath(OUT))
