#!/usr/bin/env python3
"""Cuts the game's own Samus out of a Zero Mission ROM: the golden suit figure on the pause screen's
status page (Power Suit and Fully Powered Suit) into assets/ui/samus-power.png and samus-full.png.

  python3 art/samus.py "Metroid - Zero Mission (Europe).gba"      (a US or EU ROM, already unzipped)

The figure is 7 sprite parts (decomp: src/data/menus/pause_screen_data.c, sMiscOam_Samus*SuitWireFrame)
whose tiles live in menus/pause_screen/tank_icons.gfx.lz (loaded at OBJ tile 0x180, 2D tile mapping,
32 tiles per row) and whose colours are the first row of samus_wireframe.pal. The graphics API can't
crop a compressed sprite sheet at runtime, so these two small PNGs ship in the pack (the rest of the
game's art is drawn from the player's ROM). ROM offsets are from the decomp's database.json.
"""
import os
import struct
import sys
from PIL import Image

OFFSETS = {  # game code -> (tank_icons.gfx.lz, samus_wireframe.pal)
    b"BMXE": (0x400E08, 0x3FD310),
    b"BMXP": (0x401AA0, 0x3FDF9C),
}
PARTS = {  # x, y, w, h, OBJ tile
    "power": [(0, 0, 32, 64, 0x2A6), (32, 0, 16, 32, 0x2AA), (32, 32, 16, 32, 0x32A), (0, 64, 32, 16, 0x25A),
              (32, 64, 16, 16, 0x25E), (0, 80, 32, 8, 0x29A), (32, 80, 16, 8, 0x29E)],
    "full": [(0, 0, 32, 64, 0x2A0), (32, 0, 16, 32, 0x2A4), (32, 32, 16, 32, 0x324), (0, 64, 32, 16, 0x3A0),
             (32, 64, 16, 16, 0x3A4), (0, 80, 32, 8, 0x294), (32, 80, 16, 8, 0x298)],
}
SCALE = 5  # 1 art px = 5 device px
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui")


def lz77(rom, off):
    size = rom[off + 1] | rom[off + 2] << 8 | rom[off + 3] << 16
    out, p = bytearray(), off + 4
    while len(out) < size:
        flags = rom[p]
        p += 1
        for bit in range(8):
            if len(out) >= size:
                break
            if flags & (0x80 >> bit):
                a, b = rom[p], rom[p + 1]
                p += 2
                disp = ((a & 15) << 8 | b) + 1
                for _ in range(3 + (a >> 4)):
                    out.append(out[-disp])
            else:
                out.append(rom[p])
                p += 1
    return bytes(out)


def main(path):
    rom = open(path, "rb").read()
    code = rom[0xAC:0xB0]
    if code not in OFFSETS:
        sys.exit("needs a US (BMXE) or EU (BMXP) ROM, got %r" % code)
    tiles_at, pal_at = OFFSETS[code]
    blk = lz77(rom, tiles_at)
    pal = [struct.unpack("<H", rom[pal_at + 2 * i:pal_at + 2 * i + 2])[0] for i in range(16)]
    rgb = lambda c: ((c & 31) * 255 // 31, (c >> 5 & 31) * 255 // 31, (c >> 10 & 31) * 255 // 31, 255)
    os.makedirs(OUT, exist_ok=True)
    for kind, parts in PARTS.items():
        im = Image.new("RGBA", (48, 88), (0, 0, 0, 0))
        for px, py, w, h, t in parts:
            t -= 0x180
            for ty in range(h // 8):
                for tx in range(w // 8):
                    tile = t + ty * 32 + tx
                    for y in range(8):
                        for x in range(8):
                            v = blk[tile * 32 + y * 4 + x // 2] >> (4 * (x & 1)) & 15
                            if v:
                                im.putpixel((px + tx * 8 + x, py + ty * 8 + y), rgb(pal[v]))
        im.resize((48 * SCALE, 88 * SCALE), Image.NEAREST).save(os.path.join(OUT, "samus-%s.png" % kind))
    print("ok", code)


if __name__ == "__main__":
    main(sys.argv[1])
