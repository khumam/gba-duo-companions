#!/usr/bin/env python3
"""Cuts the portrait tabs and menu icons out of the game's own frames (art/ref/*.ppm, 240x160 emulator screenshots).

  PYTHONPATH=<dir with pillow> python3 art/crop.py

goods.ppm       Goods menu, Lucas selected: portraits + key tab (x 7..115, y 3..22)
bar-goods.ppm   top menu with Goods selected: the other four icons (grey, unselected)
bar-equip.ppm   same with Equip selected: the Goods icon, unselected
"""
from PIL import Image
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "ui")
os.makedirs(OUT, exist_ok=True)


def load(n):
    return Image.open(os.path.join(HERE, "ref", n)).convert("RGB")


def bbox_nonblack(im, x0, x1, y0=0, y1=30):
    xs, ys = [], []
    for y in range(y0, y1):
        for x in range(x0, x1 + 1):
            if im.getpixel((x, y)) != (0, 0, 0):
                xs.append(x)
                ys.append(y)
    return (min(xs), min(ys), max(xs) + 1, max(ys) + 1)


goods = load("goods.ppm")
# Lucas is the selected tab here: swap the 2px orange ring for the black outline the other tabs have
lucas = goods.crop((7, 2, 29, 24)).copy()
for y in range(lucas.height):
    for x in range(lucas.width):
        if lucas.getpixel((x, y)) == (255, 148, 16):
            lucas.putpixel((x, y), (0, 0, 0))
lucas = lucas.crop((1, 1, 21, 21))
lucas.save(os.path.join(OUT, "p-lucas.png"))
for name, box in {"kumatora": (30, 3, 50, 23), "duster": (52, 3, 72, 23), "boney": (74, 3, 94, 23), "key": (96, 3, 116, 23)}.items():
    goods.crop(box).save(os.path.join(OUT, f"p-{name}.png"))

bg, be = load("bar-goods.ppm"), load("bar-equip.ppm")
icons = {
    "goods": (be, 7, 20),
    "equip": (bg, 28, 41),
    "psi": (bg, 49, 62),
    "status": (bg, 70, 83),
    "sleep": (bg, 91, 104),
}
for name, (im, x0, x1) in icons.items():
    b = bbox_nonblack(im, x0, x1, 0, 24)
    im.crop(b).save(os.path.join(OUT, f"i-{name}.png"))
    print(name, b)

# dashed window divider tile (1 x 4 art px: 2 white, 2 clear) and a 1px white pixel
dash = Image.new("RGBA", (1, 4), (0, 0, 0, 0))
dash.putpixel((0, 0), (255, 255, 251, 255))
dash.putpixel((0, 1), (255, 255, 251, 255))
dash.save(os.path.join(OUT, "dash.png"))
