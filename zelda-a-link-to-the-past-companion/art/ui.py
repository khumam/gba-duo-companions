#!/usr/bin/env python3
"""Draws the pack's own art into assets/ui: hearts, heart-piece quarters, crystals, the dungeon map / compass / big
key marks and the nav plates, in the palette of the GBA item screen (art/ref). Item icons (assets/icons) were cut
from the game's own item screen in the emulator.   python3 art/ui.py
"""
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui")
os.makedirs(OUT, exist_ok=True)


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


GREEN, RED, YELLOW, WHITE, GREY, BLUE, BLACK = C("#31ef39"), C("#ef0000"), C("#ffd600"), C("#ffffff"), C("#94949c"), C("#6b9cff"), C("#000000")
CLEAR = (0, 0, 0, 0)


def sprite(rows, pal, name):
    h, w = len(rows), max(len(r) for r in rows)
    im = Image.new("RGBA", (w, h), CLEAR)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != ".":
                im.putpixel((x, y), pal[ch])
    im.save(os.path.join(OUT, name))


HEART = [
    ".kk.kk.",
    "krrkrrk",
    "krwrrrk",
    "krrrrrk",
    ".krrrk.",
    "..krk..",
    "...k...",
]


def hearts():
    pal = {"k": BLACK, "r": RED, "w": WHITE}
    sprite(HEART, pal, "heart-full.png")
    half = [r[:4] + r[4:].replace("r", "e").replace("w", "e") for r in HEART]
    sprite(half, dict(pal, e=C("#3a1010")), "heart-half.png")
    sprite([r.replace("r", "e").replace("w", "e") for r in HEART], dict(pal, e=C("#3a1010")), "heart-empty.png")


def pieces():
    # the equipment panel's heart outline, filled one quarter per piece
    big = [
        "..wwww..wwww..",
        ".w....ww....w.",
        "w............w",
        "w............w",
        "w............w",
        ".w..........w.",
        "..w........w..",
        "...w......w...",
        "....w....w....",
        ".....w..w.....",
        "......ww......",
    ]
    for n in range(4):
        im = Image.new("RGBA", (14, 11), CLEAR)
        for y, r in enumerate(big):
            inside = [x for x, ch in enumerate(r) if ch == "w"]
            lo, hi = (min(inside), max(inside)) if inside else (0, -1)
            for x in range(14):
                if r[x] == "w":
                    im.putpixel((x, y), WHITE)
                elif lo < x < hi:
                    q = (0 if x < 7 else 1) + (0 if y < 5 else 2)   # top-left, top-right, bottom-left, bottom-right
                    order = [0, 1, 3, 2]
                    if order.index(q) < n:
                        im.putpixel((x, y), RED)
        im.save(os.path.join(OUT, f"piece-{n}.png"))


def crystal(name, lit):
    rows = [
        "...k...",
        "..kck..",
        ".kcwck.",
        "kccwcck",
        ".kccck.",
        "..kck..",
        "...k...",
    ]
    pal = {"k": C("#202040") if lit else C("#303030"), "c": C("#d070ff") if lit else GREY, "w": WHITE if lit else C("#c0c0c8")}
    sprite(rows, pal, name)


def marks():
    sprite(["kkkkkkk", "kyyyyyk", "kyryyyk", "kyrryyk", "kyyyryk", "kyyyyyk", "kkkkkkk"], {"k": C("#806020"), "y": C("#f8e0a0"), "r": RED}, "map.png")
    sprite([".kkkkk.", "kwwrwwk", "kwwrwwk", "kwwkwwk", "kwwbwwk", "kwwbwwk", ".kkkkk."], {"k": C("#806020"), "w": WHITE, "r": RED, "b": BLUE}, "compass.png")
    sprite([".yyy...", "y...y..", "y...y..", ".yyy...", "..y....", "..yyy..", "..y.y.."], {"y": YELLOW}, "bigkey.png")
    sprite([".ddd...", "d...d..", "d...d..", ".ddd...", "..d....", "..ddd..", "..d.d.."], {"d": C("#404048")}, "bigkey-off.png")
    sprite(["kkkkkkk", "kdddddk", "kdddddk", "kdddddk", "kdddddk", "kdddddk", "kkkkkkk"], {"k": C("#303030"), "d": C("#181818")}, "map-off.png")
    sprite([".kkkkk.", "kdddddk", "kdddddk", "kdddddk", "kdddddk", "kdddddk", ".kkkkk."], {"k": C("#303030"), "d": C("#181818")}, "compass-off.png")


def nav_plate(w, h, name, side=None, border=GREEN):
    im = Image.new("RGBA", (w, h), BLACK)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=3, outline=border, width=2)
    d.line([(2, 2), (w - 4, 2)], fill=WHITE)
    if side:
        cy = h // 2
        for k in range(5):
            for j in range(-k, k + 1):
                x = (6 + k) if side == "l" else (w - 7 - k)
                im.putpixel((x, cy + j), border)
    im.save(os.path.join(OUT, name))


if __name__ == "__main__":
    hearts()
    pieces()
    crystal("crystal.png", True)
    crystal("crystal-off.png", False)
    marks()
    nav_plate(72, 24, "nav-l.png", "l")
    nav_plate(72, 24, "nav-r.png", "r")
    nav_plate(96, 24, "nav-mid.png", None, YELLOW)
    print("ok")
