#!/usr/bin/env python3
"""Cuts the 64 ring icons out of art/reference/rings.bmp (a sheet of the game's ring sprites:
8 x 8 cells of 16 x 16 px starting at (16, 16), rows A-H, columns 1-8, in ring-id order; see
rings.txt) into assets/ui/ring-<id>.png at 10 device px per game pixel (160 px).

  python3 art/crop-rings.py
"""
import os
from PIL import Image

here = os.path.dirname(__file__)
sheet = Image.open(os.path.join(here, "reference", "rings.bmp")).convert("RGB")
OUT = os.path.join(here, "..", "assets", "ui")
SCALE = 10
X0, Y0, CELL = 16, 16, 16

def clear(p):  # the sheet's magenta background
    return p[0] > 235 and p[1] < 20 and p[2] > 225

clipped = []
for ring in range(64):
    cx, cy = X0 + (ring % 8) * CELL, Y0 + (ring // 8) * CELL
    cell = sheet.crop((cx, cy, cx + CELL, cy + CELL))
    icon = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    for y in range(CELL):
        for x in range(CELL):
            p = cell.getpixel((x, y))
            if not clear(p): icon.putpixel((x, y), p + (255,))
    box = icon.getbbox()
    if box and (box[0] == 0 or box[1] == 0 or box[2] == CELL or box[3] == CELL): clipped.append(ring)
    icon.resize((CELL * SCALE, CELL * SCALE), Image.NEAREST).save(os.path.join(OUT, f"ring-{ring}.png"))
print("wrote 64 ring icons; touching the cell edge:", clipped or "none")
