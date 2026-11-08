# The WORLD view of the Map page: assets/ui/hoenn.png, an original schematic of Hoenn with one square per cell of the
# region map's 28 x 15 grid. Run: python3 art/world-map.py <emerald.gba>   (USA 1.0)
#   - which cells are land, path or sea is read from the ROM's own region-map picture (an affine 8bpp background:
#     LZ77 tiles + a 64 x 64 tile map; its cell (x, y) sits at pixel (8 * (x + 1), 8 * (y + 2))); only those few bits
#     are kept, no picture is copied;
#   - the towns and cities are gRegionMapEntries 0-15 (x, y, w, h cells).
# The game draws the player's spot from the same entries, see readMap in main.lua.
import os, struct, sys
from PIL import Image, ImageDraw

PAL, GFX, TILEMAP, ENTRIES = 0x0859F73C, 0x0859F77C, 0x085A04E0, 0x085A147C   # ROM addresses (Emerald 1.0)
CELL = 10
BASE = 0x08000000


def lz77(d, o):
    size = struct.unpack_from("<I", d, o)[0] >> 8
    o += 4
    out = bytearray()
    while len(out) < size:
        flags = d[o]
        o += 1
        for i in range(8):
            if len(out) >= size:
                break
            if flags & (0x80 >> i):
                b1, b2 = d[o], d[o + 1]
                o += 2
                n, disp = (b1 >> 4) + 3, ((b1 & 0xF) << 8 | b2) + 1
                for _ in range(n):
                    out.append(out[-disp])
            else:
                out.append(d[o])
                o += 1
    return bytes(out[:size])


rom = open(sys.argv[1], "rb").read()
tiles, tmap = lz77(rom, GFX - BASE), lz77(rom, TILEMAP - BASE)


def pixel(x, y):  # palette index (the picture's colours start at 112)
    return tiles[tmap[(y // 8) * 64 + x // 8] * 64 + (y % 8) * 8 + x % 8] - 112


PATH, LAND, SEAROUTE = {15, 18, 19, 20, 21, 22, 23}, {10, 11, 12, 13, 14}, {4, 5, 6, 7, 8, 9}
img = Image.new("RGB", (28 * CELL, 15 * CELL), (156, 213, 255))
dr = ImageDraw.Draw(img)
for cy in range(15):
    for cx in range(28):
        n = {"land": 0, "path": 0, "sea": 0}
        for y in range(8):
            for x in range(8):
                p = pixel(8 * (cx + 1) + x, 8 * (cy + 2) + y)
                n["land" if p in LAND else "path" if p in PATH else "sea" if p in SEAROUTE else "none"] = n.get("land" if p in LAND else "path" if p in PATH else "sea" if p in SEAROUTE else "none", 0) + 1
        box = (cx * CELL, cy * CELL, cx * CELL + CELL - 1, cy * CELL + CELL - 1)
        dr.rectangle(box, fill=(156, 213, 255) if (cx + cy) % 2 == 0 else (164, 220, 255))
        if n["land"] + n["path"] >= 14:
            dr.rectangle(box, fill=(238, 189, 57) if n["path"] > n["land"] else ((57, 172, 8) if (cx + cy) % 2 == 0 else (66, 180, 14)))
        elif n["sea"] >= 18:
            dr.rectangle(box, fill=(74, 156, 230))
for i in range(16):
    e = ENTRIES + i * 8 - BASE
    x, y, w, h = rom[e], rom[e + 1], rom[e + 2], rom[e + 3]
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            dr.rectangle((xx * CELL + 1, yy * CELL + 1, xx * CELL + CELL - 2, yy * CELL + CELL - 2), fill=(255, 255, 255), outline=(200, 40, 24), width=2)
img.save(os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "hoenn.png"))
print("hoenn.png", img.size)
