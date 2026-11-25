#!/usr/bin/env python3
"""0.4.0 frame piece in the game's own shape: the green title plaque with its dithered tail (art pixels, saved at 5 device px).
    python3 art/hod_ui.py"""
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui")
W, H, K = 110, 18, 5
G, G2, G3, HI = (0, 173, 0, 255), (0, 140, 0, 255), (0, 80, 0, 255), (64, 208, 64, 255)
im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
body = 78
for y in range(H):
    for x in range(body): im.putpixel((x, y), HI if y == 0 else (G2 if y == H - 1 else G))
    for x in range(body, W):                                   # the dithered tail, thinning out to the right
        t = (x - body) / (W - body)
        if (x + y) % 2 == 0 and ((x // 2 + y) % 3 != 0 or t < 0.5) and t < 1 - abs(y - H / 2) / H * 0.6:
            im.putpixel((x, y), G2 if t < 0.5 else G3)
im.resize((W * K, H * K), Image.NEAREST).save(os.path.join(OUT, "plaque.png"))
print("ok")
