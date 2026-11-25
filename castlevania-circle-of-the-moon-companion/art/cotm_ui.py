#!/usr/bin/env python3
"""0.4.0 frame pieces in the game's own shapes (art pixels, saved at 5 device px each so they sit 1:1 on the Thor):
  plate-on / plate-off      the pause menu's arrow plates (red-orange open, blue closed), with the diagonal sheen at the left
  cap-l-H / cap-r-H         the ends of the game's capsule frames (white outline, angled ends) for H = 12, 16, 20 art px
    python3 art/cotm_ui.py"""
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui")
K = 5
WHITE = (239, 255, 239, 255)


def save(im, name): im.resize((im.width * K, im.height * K), Image.NEAREST).save(os.path.join(OUT, name + ".png"))


def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def plate(w, h, on):
    top, mid, bot = ((255, 156, 107), (247, 57, 0), (132, 8, 0)) if on else ((115, 132, 181), (33, 49, 140), (0, 8, 74))
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    tip = h // 2
    for y in range(h):
        c = lerp(top, mid, y / (h / 2)) if y < h / 2 else lerp(mid, bot, (y - h / 2) / (h / 2))
        inset = abs(y - (h - 1) / 2)
        right = w - 1 - int(inset)
        for x in range(1, right):
            px = c
            if x < w * 0.45 and (x + y) % 6 < 2: px = lerp(c[:3], (255, 255, 255), 0.28 * (1 - x / (w * 0.45)))   # the diagonal sheen
            im.putpixel((x, y), px)
        im.putpixel((right, y), WHITE)
    for x in range(0, w - tip): im.putpixel((x, 0), WHITE); im.putpixel((x, h - 1), WHITE)
    for y in range(h): im.putpixel((0, y), WHITE)
    return im


def caps(h):
    l = Image.new("RGBA", (4, h), (0, 0, 0, 0)); r = Image.new("RGBA", (4, h), (0, 0, 0, 0))
    for y in range(h):
        k = min(3, int(abs(y - (h - 1) / 2) * 6 / h))                    # the angled end: 3 px in at the top and bottom
        l.putpixel((k, y), WHITE); r.putpixel((3 - k, y), WHITE)
    for x in range(4):
        if x >= 3: l.putpixel((x, 0), WHITE); l.putpixel((x, h - 1), WHITE)
        if x <= 0: r.putpixel((x, 0), WHITE); r.putpixel((x, h - 1), WHITE)
    return l, r


save(plate(60, 20, True), "plate-on"); save(plate(60, 20, False), "plate-off")
for h in (12, 16, 20):
    l, r = caps(h); save(l, "cap-l-%d" % h); save(r, "cap-r-%d" % h)
print("ok")
