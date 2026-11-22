#!/usr/bin/env python3
"""Tiles screenshots into one contact sheet (to look at many frames at once).

    python3 -I skill/tools/harness/sheet.py OUT.png a.png b.png ... [--cols 3] [--crop x,y,w,h] [--scale 2]

--crop takes GBA pixels (240 x 160) and is applied to every frame before tiling.
"""
import argparse

from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("out")
ap.add_argument("frames", nargs="+")
ap.add_argument("--cols", type=int, default=3)
ap.add_argument("--crop")
ap.add_argument("--scale", type=int, default=2)
a = ap.parse_args()
tiles = []
for f in a.frames:
    im = Image.open(f).convert("RGB").resize((240, 160), Image.NEAREST)
    if a.crop:
        x, y, w, h = map(int, a.crop.split(","))
        im = im.crop((x, y, x + w, y + h))
    tiles.append(im.resize((im.width * a.scale, im.height * a.scale), Image.NEAREST))
W, H = tiles[0].size
cols = min(a.cols, len(tiles))
rows = (len(tiles) + cols - 1) // cols
sheet = Image.new("RGB", (cols * (W + 6) - 6, rows * (H + 6) - 6), (255, 0, 255))
for i, t in enumerate(tiles):
    sheet.paste(t, ((i % cols) * (W + 6), (i // cols) * (H + 6)))
sheet.save(a.out)
print(a.out, sheet.size)
