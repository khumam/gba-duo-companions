"""Light stone panel texture and the pale-leaf yellow field.

Run: python3 art/stone_tiles.py -> assets/ui/stone-light.png, canopy.png

stone-light.png comes from art/stone-source.jpeg: a crop, lightened and mirrored 2 x 2 so it
tiles seamlessly (shown at 80 dp), then pixelated. canopy.png is the Items menu's yellow with a few pale
leaf clusters, drawn on a 4 px grid.
"""
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageOps

HERE = Path(__file__).resolve().parent
UI = HERE.parent / "assets" / "ui"
TILE = 400


def stone():
    src = Image.open(HERE / "stone-source.jpeg").convert("L").crop((150, 100, 350, 300))
    src = ImageOps.autocontrast(src, cutoff=1)
    half = src.resize((TILE // 2, TILE // 2), Image.LANCZOS)
    out = Image.new("L", (TILE, TILE))
    out.paste(half, (0, 0))
    out.paste(half.transpose(Image.FLIP_LEFT_RIGHT), (TILE // 2, 0))
    out.paste(half.transpose(Image.FLIP_TOP_BOTTOM), (0, TILE // 2))
    out.paste(half.transpose(Image.ROTATE_180), (TILE // 2, TILE // 2))
    # chunky pixels (40 x 40 cells, 2 dp each) in three grey steps: light warm grey, rough grain
    cells = out.resize((TILE // 10, TILE // 10), Image.BOX)
    cells = ImageOps.autocontrast(cells, cutoff=2).point(lambda v: min(2, v * 3 // 256) * 255 // 2)
    lo, hi = (180, 178, 180), (204, 201, 202)
    return ImageOps.colorize(cells, lo, hi).resize((TILE, TILE), Image.NEAREST)


def canopy():
    base, leaf = (203, 213, 128), (217, 225, 152)
    img = Image.new("RGB", (192, 192), base)
    d = ImageDraw.Draw(img)
    rnd = random.Random(3)
    for cx, cy in [(40, 40), (140, 30), (96, 112), (30, 150), (160, 160)]:
        for _ in range(3):  # a cluster of leaves
            ox, oy = cx + rnd.randint(-14, 14), cy + rnd.randint(-10, 10)
            w, h = rnd.randint(14, 22), rnd.randint(22, 32)
            d.ellipse((ox - w, oy - h, ox + w, oy + h), fill=leaf)
    small = img.resize((48, 48), Image.NEAREST).resize((192, 192), Image.NEAREST)  # chunky edges
    return small


stone().save(UI / "stone-light.png")
canopy().save(UI / "canopy.png")
print("ok")
