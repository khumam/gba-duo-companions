#!/usr/bin/env python3
"""The WORLD view of the Map page: assets/ui/hoenn.png (the layout's file name, copied from the Emerald pack), redrawn as an
original schematic of Monomyth's region: one square per cell of a 28 x 15 grid, drawn from the ROM's region map entries only
(ROM 0x08A166B0, 8 bytes each: name pointer, then x, y, w, h in cells). No picture is copied from the game.
  python3 art/world-map.py "Pokemon Monomyth.gba"
"""
import struct, sys, zlib

TABLE, COLS, ROWS, CELL = 0x08A166B0 - 0x08000000, 28, 15, 10

def name(rom, p):
    out = ""
    for c in rom[p - 0x08000000:p - 0x08000000 + 24]:
        if c == 0xFF: break
        out += chr(65 + c - 0xBB) if 0xBB <= c <= 0xD4 else chr(97 + c - 0xD5) if 0xD5 <= c <= 0xEE else " " if c == 0 else "?"
    return out

rom = open(sys.argv[1], "rb").read()
W, H = COLS * CELL, ROWS * CELL
px = [[(156, 213, 255) if ((x // CELL + y // CELL) % 2 == 0) else (164, 220, 255) for x in range(W)] for y in range(H)]

def fill(cx, cy, w, h, col, edge=None):
    for y in range(cy * CELL, min(H, (cy + h) * CELL)):
        for x in range(cx * CELL, min(W, (cx + w) * CELL)):
            on_edge = x % CELL in (0, CELL - 1) or y % CELL in (0, CELL - 1)
            px[y][x] = edge if (edge and on_edge) else col

# routes first (paths), then the other places, then towns and cities on top
sections = []
for i in range(256):
    p, = struct.unpack("<I", rom[TABLE + 8 * i:TABLE + 8 * i + 4])
    x, y, w, h = rom[TABLE + 8 * i + 4:TABLE + 8 * i + 8]
    if 0x08000000 <= p < 0x0A000000 and w and h and x < COLS and y < ROWS:
        sections.append((i, name(rom, p), x, y, w, h))
for i, n, x, y, w, h in sections:
    if n.startswith("Route"): fill(x, y, w, h, (238, 189, 57), (214, 160, 36))
for i, n, x, y, w, h in sections:
    if not n.startswith("Route") and i > 12: fill(x, y, w, h, (120, 150, 110), (88, 116, 80))
for i, n, x, y, w, h in sections:
    if i <= 12: fill(x, y, w, h, (57, 172, 8), (214, 64, 56))

def chunk(t, d):
    c = struct.pack(">I", len(d)) + t + d
    return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
raw = b"".join(b"\x00" + bytes(v for p in row for v in p) for row in px)
open("assets/ui/hoenn.png", "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
    + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
print("sections", len(sections))
