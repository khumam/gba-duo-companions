#!/usr/bin/env python3
"""Cuts one icon out of a full-screen capture of the Thor's main display (1920x1080 with the
GBC picture stretched to 160x144 game pixels: 12 px wide, 7 px tall each, 36 px letterbox on top).

  python3 art/grab-icon.py <capture.png> <name> <gx> <gy> <w> <h> [bg-hex ...]

Every game pixel is read back as the most common colour of its block (the LCD grid shader
dims some of it). Colours listed as bg become transparent. Writes assets/ui/<name>.png at 5
device px per game pixel, padded to a 16x16 canvas when smaller: 80 px, drawn at 34.69dp.
"""
import os, sys
from collections import Counter
from PIL import Image

cap, name, gx, gy, w, h = sys.argv[1], sys.argv[2], *map(int, sys.argv[3:7])
bgs = {tuple(int(b[i:i + 2], 16) for i in (0, 2, 4)) for b in sys.argv[7:]}
im = Image.open(cap).convert("RGB")

def game_px(x, y):
    x0, y0 = x * 12, 36 + y * 7
    c = Counter(im.getpixel((x0 + i, y0 + j)) for i in range(2, 10) for j in range(1, 6))
    return c.most_common(1)[0][0]

SCALE = 5
cw, ch = max(w, 16), max(h, 16)
ox, oy = (cw - w) // 2, (ch - h) // 2
out = Image.new("RGBA", (cw * SCALE, ch * SCALE), (0, 0, 0, 0))
for y in range(h):
    for x in range(w):
        c = game_px(gx + x, gy + y)
        if c in bgs: continue
        block = Image.new("RGBA", (SCALE, SCALE), c + (255,))
        out.paste(block, ((ox + x) * SCALE, (oy + y) * SCALE))
dest = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", name + ".png")
out.save(dest)
print("wrote", os.path.relpath(dest))
