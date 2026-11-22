#!/usr/bin/env python3
"""Where do the graphics on screen come from? Compares the tiles of a VRAM capture (play.py step vram:NAME) with the
ROM, raw and LZ77-compressed, and renders VRAM / tile blocks to PNG.

    python3 -I skill/tools/harness/gfxfind.py ROM NAME.vram find [--from 0x4000 --to 0x8000]
        tiles found raw, then the LZ77 blocks holding the most of them (ROM offset, size, matches)
    python3 -I skill/tools/harness/gfxfind.py ROM NAME.vram banks OUT.png
        the four 16 KB character banks as grey 4bpp sheets (tilemaps show up as stripes)
    python3 -I skill/tools/harness/gfxfind.py ROM NAME.vram lz OFFSET OUT.png
        decompress the LZ77 block at OFFSET and draw it as 4bpp tiles, 16 per row
    python3 -I skill/tools/harness/gfxfind.py ROM NAME.vram affine OUT.png --map 0xC000 --size 64
        an 8bpp affine background (one byte per map entry, 64 bytes per tile, char base 0) in its palette
        (NAME.pal): how the A Link to the Past world map was cut out whole

A pack can draw ROM graphics at run time with gfx.decode (tiles may be LZ77) or gfx.sprite (raw tiles, flips); when
the art is LZ77 *and* needs flipped tiles, neither works and the icons have to be cut from frames instead.
"""
import argparse
import os
import struct
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lz77 import lz77  # noqa: E402


def sheet4(data, cols=16):
    n = len(data) // 32
    im = Image.new("L", (cols * 8, max(1, (n + cols - 1) // cols) * 8))
    px = im.load()
    for t in range(n):
        for y in range(8):
            for x in range(8):
                b = data[t * 32 + y * 4 + x // 2]
                px[(t % cols) * 8 + x, (t // cols) * 8 + y] = ((b >> ((x & 1) * 4)) & 15) * 17
    return im


ap = argparse.ArgumentParser()
ap.add_argument("rom")
ap.add_argument("vram")
ap.add_argument("cmd")
ap.add_argument("args", nargs="*")
ap.add_argument("--from", dest="lo", default="0")
ap.add_argument("--to", dest="hi", default="0x10000")
ap.add_argument("--map", default="0xC000")
ap.add_argument("--size", type=int, default=64)
a = ap.parse_args()
rom = open(a.rom, "rb").read()
v = open(a.vram, "rb").read()

if a.cmd == "find":
    lo, hi = int(a.lo, 0), int(a.hi, 0)
    tiles = {v[t:t + 32] for t in range(lo, hi, 32) if len(set(v[t:t + 32])) >= 5}
    raw = sum(1 for t in tiles if rom.find(t) >= 0)
    print(f"{len(tiles)} distinct tiles, {raw} found raw in the ROM")
    best = []
    for off in range(0, len(rom) - 4, 4):
        if rom[off] != 0x10:
            continue
        d = lz77(rom, off, 0x20000)
        if not d:
            continue
        n = sum(1 for t in range(0, len(d), 32) if d[t:t + 32] in tiles)
        if n >= 6:
            best.append((n, off, len(d)))
    for n, off, size in sorted(best, reverse=True)[:12]:
        print("LZ77 at %X  %X bytes  %d matching tiles" % (off, size, n))
elif a.cmd == "banks":
    out = Image.new("L", (256, 4 * 128 + 24), 80)
    for k in range(4):
        out.paste(sheet4(v[k * 0x4000:(k + 1) * 0x4000], 32), (0, k * 136))
    out.resize((out.width * 2, out.height * 2), Image.NEAREST).save(a.args[0])
elif a.cmd == "lz":
    d = lz77(rom, int(a.args[0], 0), 0x40000)
    if not d:
        sys.exit("no LZ77 block there")
    im = sheet4(d)
    im.resize((im.width * 3, im.height * 3), Image.NEAREST).save(a.args[1])
    print(len(d), "bytes")
elif a.cmd == "affine":
    pal = open(a.vram[:-5] + ".pal", "rb").read()
    cols = []
    for i in range(256):
        c = struct.unpack_from("<H", pal, i * 2)[0]
        cols.append(((c & 31) * 255 // 31, ((c >> 5) & 31) * 255 // 31, ((c >> 10) & 31) * 255 // 31))
    n, base = a.size, int(a.map, 0)
    im = Image.new("RGB", (n * 8, n * 8))
    px = im.load()
    for ty in range(n):
        for tx in range(n):
            t = v[base + ty * n + tx]
            for y in range(8):
                for x in range(8):
                    px[tx * 8 + x, ty * 8 + y] = cols[v[t * 64 + y * 8 + x]]
    im.save(a.args[0])
else:
    sys.exit("commands: find, banks, lz, affine")
