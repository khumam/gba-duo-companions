#!/usr/bin/env python3
"""Draws the pack's art into assets/ui: the leafy green backdrop of the game's preparation / status screens and the
gold page arrows of its unit screen. Original pixel art in the palette sampled from art/ref/*.png; 1 px = 1ap.

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


def backdrop(w=248, h=216, seed=7):
    rnd = random.Random(seed)
    im = Image.new("RGBA", (w, h), LEAF[1])
    px = im.load()
    # soft diagonal bands like the painted leaves, then leaf blobs
    for y in range(h):
        for x in range(w):
            v = ((x + y * 2) // 23 + (x - y) // 31) % 4
            px[x, y] = LEAF[[1, 2, 1, 0][v]]
    for _ in range(420):
        cx, cy = rnd.randrange(w), rnd.randrange(h)
        r = rnd.randrange(3, 9)
        col = LEAF[rnd.choice([2, 3, 3, 4, 0, 6])]
        for y in range(-r, r + 1):
            for x in range(-r * 2, r * 2 + 1):
                if (x / 2) ** 2 + y * y <= r * r and 0 <= cx + x < w and 0 <= cy + y < h:
                    px[cx + x, cy + y] = col
        # highlight vein
        for t in range(r):
            if 0 <= cx + t < w and 0 <= cy - t // 2 < h:
                px[cx + t, cy - t // 2] = LEAF[5] if col in (LEAF[3], LEAF[4]) else LEAF[3]
    im.save(os.path.join(OUT, "leaves.png"))


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
