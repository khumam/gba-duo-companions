#!/usr/bin/env python3
"""Draws the original pixel art the Advance Wars companion needs besides the game's own icons: terrain stand-in tiles,
DEF stars, the income house, army crates (the game's star crate recoloured per army) and a map-tab glyph.
    python3 art/ui.py"""
import os
from PIL import Image, ImageDraw

here = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(here, "..", "assets")
INK = (16, 8, 8)


def sv(im, *p):
    path = os.path.join(A, *p); os.makedirs(os.path.dirname(path), exist_ok=True); im.save(path)


# ---- army crates: the game's red star crate, hue-swapped per army ---------------------------------------------------------------------
base = Image.open(os.path.join(A, "icons/ui/flag-orange.png")).convert("RGBA")
r, g, b, a = base.split()
sv(base, "icons/ui/crate-orange.png")
sv(Image.merge("RGBA", (b, g, r, a)), "icons/ui/crate-blue.png")
sv(Image.merge("RGBA", (b, r, g, a)), "icons/ui/crate-green.png")
sv(Image.merge("RGBA", (r, r, b, a)).point(lambda v: v), "icons/ui/crate-yellow.png")

# ---- glyphs with an ink outline --------------------------------------------------------------------------------------------------------
STAR = ["...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", ".#...#."]
HOUSE = ["...##...", "..####..", ".######.", "########", ".#.##.#.", ".#.##.#.", ".######."]


def glyph(rows, fill):
    h, w = len(rows), len(rows[0])
    im = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0)); px = im.load()
    on = {(i, j) for j in range(h) for i in range(w) if rows[j][i] == "#"}
    for (i, j) in on:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if (i + dx, j + dy) not in on: px[i + dx + 1, j + dy + 1] = INK + (255,)
    for (i, j) in on: px[i + 1, j + 1] = fill + (255,)
    return im


sv(glyph(STAR, (247, 200, 24)), "ui/star-on.png")
sv(glyph(STAR, (110, 112, 140)), "ui/star-off.png")
sv(glyph(HOUSE, (255, 255, 255)), "ui/house.png")
sv(glyph(HOUSE, (150, 156, 176)), "ui/house-grey.png")
m = Image.new("RGBA", (18, 14), (0, 0, 0, 0)); d = ImageDraw.Draw(m)
d.rectangle([0, 0, 17, 13], fill=INK); d.rectangle([1, 1, 16, 12], fill=(238, 220, 170))
d.line([(6, 1), (6, 12)], fill=(200, 176, 120)); d.line([(12, 1), (12, 12)], fill=(200, 176, 120)); d.rectangle([8, 5, 10, 7], fill=(232, 84, 40))
sv(m, "ui/tab-map.png")


# ---- terrain stand-ins, 16 x 16 (the real tiles live in the ROM; these are drawn in code) -------------------------------------------
LIME, LIME2 = (198, 231, 49), (222, 239, 33)
SEA, SEA2 = (48, 104, 200), (110, 160, 240)


def tile(kind):
    t = Image.new("RGBA", (16, 16), LIME + (255,)); d = ImageDraw.Draw(t)
    def r(x, y, w, h, c): d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)
    def tufts():
        for (x, y) in ((2, 3), (11, 2), (6, 9), (13, 12), (3, 13)): r(x, y, 2, 1, LIME2)
    def sea():
        r(0, 0, 16, 16, SEA)
        for (x, y) in ((2, 3), (9, 2), (5, 9), (12, 8), (1, 13), (9, 13)): r(x, y, 3, 1, SEA2)
    if kind == "plain": tufts()
    elif kind == "road":
        r(0, 0, 16, 16, (214, 200, 150)); r(0, 0, 16, 1, (176, 158, 104)); r(0, 15, 16, 1, (176, 158, 104))
        for x in (1, 7, 13): r(x, 7, 3, 2, (255, 246, 214))
    elif kind == "wood":
        tufts()
        for (x, y) in ((1, 2), (8, 1), (4, 8), (10, 9)):
            r(x, y + 4, 5, 3, (28, 100, 56)); r(x + 1, y, 3, 5, (46, 140, 70)); r(x + 1, y + 1, 1, 2, (110, 200, 110)); r(x + 2, y + 7, 1, 2, (96, 64, 32))
    elif kind == "mountain":
        tufts()
        for (x, y, w) in ((0, 5, 10), (6, 2, 10)):
            for i in range(w // 2): r(x + i, y + 8 - i, w - 2 * i, 1, (214, 172, 84))
            r(x + w // 2 - 1, y + 2, 2, 2, (255, 236, 150)); r(x + w // 2, y + 4, w // 2, 4, (160, 118, 52))
    elif kind == "river": tufts(); r(5, 0, 6, 16, SEA); r(6, 3, 2, 1, SEA2); r(8, 9, 2, 1, SEA2)
    elif kind == "bridge":
        r(0, 0, 16, 16, SEA); r(0, 5, 16, 6, (214, 200, 150)); r(0, 5, 16, 1, (120, 90, 50)); r(0, 10, 16, 1, (120, 90, 50))
    elif kind == "shoal": r(0, 0, 16, 16, (234, 214, 150)); r(0, 9, 16, 7, SEA); r(0, 8, 16, 1, SEA2); r(3, 12, 3, 1, SEA2)
    elif kind == "sea": sea()
    elif kind == "reef":
        sea()
        for (x, y) in ((3, 4), (9, 8), (4, 11)): r(x, y, 4, 3, (84, 72, 62)); r(x, y, 2, 1, (150, 140, 120))
    else:
        if kind == "port": sea()
        else: r(0, 0, 16, 16, (186, 190, 196)); r(0, 14, 16, 2, (150, 150, 160))
        if kind == "city":
            for (x, y, w, h) in ((1, 5, 5, 10), (7, 2, 4, 13), (12, 7, 3, 8)):
                r(x, y, w, h, (150, 164, 190)); r(x, y, w, 1, (200, 210, 230))
                for yy in range(y + 2, y + h - 1, 3):
                    r(x + 1, yy, 1, 1, (250, 240, 160))
                    if w > 3: r(x + w - 2, yy, 1, 1, (250, 240, 160))
        elif kind == "hq":
            r(2, 6, 12, 9, (170, 176, 196)); r(2, 6, 12, 2, (210, 216, 232)); r(6, 11, 4, 4, (84, 90, 120)); r(8, 0, 1, 7, INK); r(9, 0, 5, 4, (232, 70, 40))
        elif kind == "base":
            r(1, 6, 14, 9, (120, 128, 150)); r(1, 6, 14, 2, (176, 184, 204)); r(4, 10, 8, 5, (60, 64, 90)); r(11, 1, 3, 6, (110, 110, 120)); r(11, 0, 3, 1, (210, 210, 220))
        elif kind == "airport":
            r(0, 7, 16, 3, (110, 112, 128))
            for x in (1, 6, 11): r(x, 8, 3, 1, (255, 255, 255))
            r(5, 2, 6, 2, (230, 236, 244)); r(7, 1, 2, 5, (230, 236, 244))
        elif kind == "port":
            r(0, 9, 16, 4, (120, 128, 150)); r(10, 2, 2, 8, (184, 184, 200)); r(6, 2, 6, 2, (184, 184, 200)); r(6, 4, 1, 4, INK)
    return t


for k in ("plain", "road", "wood", "mountain", "river", "bridge", "shoal", "sea", "reef", "city", "base", "airport", "port", "hq"):
    sv(tile(k), "terrain", k + ".png")
print("assets ok")
