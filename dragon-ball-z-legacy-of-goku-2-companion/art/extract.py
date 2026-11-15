#!/usr/bin/env python3
"""Cuts the game's own character portraits and item pictures out of clean 240x160 frames
(grabbed from a headless mGBA run, see NOTES.md) into assets/gfx.

    python3 art/extract.py <frames dir>

<frames dir> holds port0..4.ppm (status page, one per character), it00..it44.ppm (the
items page walked slot by slot with every slot filled) and empty.ppm (items page, no items).
These PNGs are the game's artwork (Bird Studios / Webfoot / Atari); see the repo README.
"""
import os, sys
from PIL import Image

src = sys.argv[1]
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "gfx")
os.makedirs(out, exist_ok=True)
ld = lambda n: Image.open(os.path.join(src, n + ".ppm")).convert("RGB")

# portraits: the framed picture on the status page
for i in range(5):
    ld(f"port{i}").crop((160, 36, 224, 99)).save(os.path.join(out, f"p{i}.png"))

# items: row geometry on the items page (3 rows, 28 px apart)
ROW_Y = [40, 68, 96]
ICON = (47, 39, 65, 59)        # x0, y0, x1, y1 relative to row 0 (y shifts per row)
BIG = (150, 34, 200, 74)
empty = ld("empty")
def sel_row(im):
    """row whose name text is orange (selected)"""
    best, bi = -1, 0
    for r, y in enumerate(ROW_Y):
        n = 0
        for yy in range(y - 4, y + 18):
            for xx in range(66, 140):
                p = im.getpixel((xx, yy))
                if p[0] > 230 and 140 < p[1] < 200 and p[2] < 60: n += 1
        if n > best: best, bi = n, r
    return bi
def clean(big):
    """The shadow under a picture is black over striped rows, so keying leaves every other row empty: fill those,
    then drop specks (stray text from the description) that are not part of the main picture."""
    px = big.load(); W, H = big.size
    for y in range(1, H - 1):
        for x in range(W):
            if px[x, y][3] == 0 and px[x, y - 1][3] and px[x, y + 1][3] and px[x, y - 1][:3] == (0, 0, 0) and px[x, y + 1][:3] == (0, 0, 0):
                px[x, y] = (0, 0, 0, 255)
    seen = {}; comps = []
    for y in range(H):
        for x in range(W):
            if px[x, y][3] and (x, y) not in seen:
                stack, comp = [(x, y)], []
                seen[(x, y)] = 1
                while stack:
                    cx, cy = stack.pop(); comp.append((cx, cy))
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            nx, ny = cx + dx, cy + dy
                            if 0 <= nx < W and 0 <= ny < H and px[nx, ny][3] and (nx, ny) not in seen:
                                seen[(nx, ny)] = 1; stack.append((nx, ny))
                comps.append(comp)
    if comps:
        top = max(len(c) for c in comps)
        for c in comps:
            if len(c) < top * 0.15:
                for (x, y) in c: px[x, y] = (0, 0, 0, 0)

icons = {}
for n in range(45):
    im = ld(f"it{n:02d}")
    s = sel_row(im)
    for r, y in enumerate(ROW_Y):
        slot = n + (r - s)
        if r != s and 0 <= slot < 45 and slot not in icons:
            icons[slot] = im.crop((ICON[0], y - 1, ICON[2], y + 19))
    # big picture with the striped panel keyed out against the empty page
    big = Image.new("RGBA", (BIG[2] - BIG[0], BIG[3] - BIG[1]))
    a, b = im.crop(BIG), empty.crop(BIG)
    for y in range(big.height):
        for x in range(big.width):
            big.putpixel((x, y), a.getpixel((x, y)) + (0,) if a.getpixel((x, y)) == b.getpixel((x, y)) else a.getpixel((x, y)) + (255,))
    clean(big)
    big.save(os.path.join(out, f"b{n}.png"))
for slot, ic in icons.items():
    ic.save(os.path.join(out, f"i{slot}.png"))
print(len(icons), "icons")
