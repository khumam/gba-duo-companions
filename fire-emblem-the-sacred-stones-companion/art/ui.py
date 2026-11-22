#!/usr/bin/env python3
"""Draws the pack's art into assets/ui: the red-brown stone floor behind The Sacred Stones' unit screen and the gold
page arrows of its headers. Original pixel art in the palette sampled from art/ref/*.png; 1 px = 1ap.

    python3 art/ui.py
"""
import os
import random

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "ui")
os.makedirs(OUT, exist_ok=True)


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# sampled from the Preparations / unit screens
LEAF = [C("#186b18"), C("#218421"), C("#299431"), C("#42a542"), C("#63b529"), C("#8cd631"), C("#108410"), C("#0c5a10")]
GOLD, GOLD_HI, GOLD_LO, INK = C("#f8d038"), C("#fff8a0"), C("#a87800"), C("#3a2a08")


STONE = [C("#422121"), C("#5a3931"), C("#6b4239"), C("#845242"), C("#8c5a4a"), C("#391c1c"), C("#a56b52")]


def backdrop(w=248, h=216, seed=8):
    """Diagonal stone tiles with soft mottling, like the floor behind the stat screen."""
    rnd = random.Random(seed)
    im = Image.new("RGBA", (w, h), STONE[0])
    px = im.load()
    T = 22
    for y in range(h):
        for x in range(w):
            u, v = (x + y) % T, (x - y) % T
            if u == 0 or v == 0:
                px[x, y] = STONE[5]
            elif u == 1 or v == 1:
                px[x, y] = STONE[3]
            else:
                tile = ((x + y) // T * 7 + (x - y) // T * 3) % 4
                px[x, y] = STONE[[1, 2, 1, 0][tile]]
    for _ in range(900):
        x, y = rnd.randrange(w), rnd.randrange(h)
        if px[x, y] not in (STONE[5], STONE[3]):
            px[x, y] = STONE[rnd.choice([2, 3, 4, 0])]
    im.save(os.path.join(OUT, "stone.png"))


def arrow(name, flip):
    # 7 x 11 gold chevron with a dark rim, like the "< Items >" arrows
    rows = ["...X...", "..XGX..", ".XGGX..", "XGGHX..", ".XGGX..", "..XGX..", "...X..."]
    rows = ["..X....", ".XGX...", "XGHGX..", "XGGHGX.", "XGGGGGX", "XGGHGX.", "XGHGX..", ".XGX...", "..X...."]
    im = Image.new("RGBA", (7, 9), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "X":
                px[x, y] = INK
            elif ch == "G":
                px[x, y] = GOLD
            elif ch == "H":
                px[x, y] = GOLD_HI
    if not flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    im.save(os.path.join(OUT, name))


if __name__ == "__main__":
    backdrop()
    arrow("arrow-r.png", True)
    arrow("arrow-l.png", False)
    print("ok", sorted(os.listdir(OUT)))
