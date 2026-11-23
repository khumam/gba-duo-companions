#!/usr/bin/env python3
"""Draws the five flat-style tab icons (16 x 16 pixel art shown at 4 px per pixel), on = triforce gold, off = muted moss.
    python3 art/icons.py"""
import math, os
from PIL import Image, ImageDraw

N, SS, SCALE = 16, 16, 4
COLORS = {"on": (232, 185, 35), "off": (139, 168, 148)}


def raster(fn):
    big = Image.new("L", (N * SS, N * SS), 0)
    fn(ImageDraw.Draw(big), SS)
    return big.resize((N, N), Image.BOX).point(lambda v: 255 if v >= 128 else 0)


def pin(d, s):
    d.ellipse([3.2 * s, 1 * s, 12.8 * s, 10.6 * s], fill=255)
    d.polygon([(4.2 * s, 8 * s), (11.8 * s, 8 * s), (8 * s, 15.2 * s)], fill=255)
    d.ellipse([6 * s, 3.6 * s, 10 * s, 7.6 * s], fill=0)


def bomb(d, s):
    d.ellipse([2 * s, 4.6 * s, 13 * s, 15.4 * s], fill=255)
    d.rectangle([6.2 * s, 2.6 * s, 9.2 * s, 5.6 * s], fill=255)
    d.line([(8.6 * s, 2.8 * s), (11 * s, 1 * s), (13.4 * s, 1.6 * s)], fill=255, width=int(1.5 * s))
    d.ellipse([4.2 * s, 7 * s, 6.4 * s, 9.2 * s], fill=0)


def kinstone(d, s):
    d.polygon([(8 * s, 1 * s), (14.6 * s, 6.2 * s), (8 * s, 15.2 * s), (1.4 * s, 6.2 * s)], fill=255)
    d.line([(8.4 * s, 1.4 * s), (7 * s, 5 * s), (9 * s, 8.4 * s), (7.4 * s, 12 * s)], fill=0, width=int(1.3 * s))


def triforce(d, s):
    d.polygon([(8 * s, 1 * s), (5 * s, 7 * s), (11 * s, 7 * s)], fill=255)
    d.polygon([(4.6 * s, 8 * s), (1.2 * s, 14.6 * s), (8 * s, 14.6 * s)], fill=255)
    d.polygon([(11.4 * s, 8 * s), (8 * s, 14.6 * s), (14.8 * s, 14.6 * s)], fill=255)


def gear(d, s):
    c = 8 * s
    for k in range(8):
        a = k * math.pi / 4
        ca, sa = math.cos(a), math.sin(a)
        w, r0, r1 = 1.9 * s, 4 * s, 7.6 * s
        d.polygon([(c + ca * r0 - sa * w, c + sa * r0 + ca * w), (c + ca * r1 - sa * w, c + sa * r1 + ca * w),
                   (c + ca * r1 + sa * w, c + sa * r1 - ca * w), (c + ca * r0 + sa * w, c + sa * r0 - ca * w)], fill=255)
    d.ellipse([c - 5.4 * s, c - 5.4 * s, c + 5.4 * s, c + 5.4 * s], fill=255)
    d.ellipse([c - 2.2 * s, c - 2.2 * s, c + 2.2 * s, c + 2.2 * s], fill=0)


ICONS = {"map": pin, "items": bomb, "kinstone": kinstone, "quest": triforce, "options": gear}
here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "..", "assets", "ui")
for name, fn in ICONS.items():
    mask = raster(fn).resize((N * SCALE, N * SCALE), Image.NEAREST)
    for state, rgb in COLORS.items():
        im = Image.new("RGBA", mask.size, rgb + (0,))
        im.putalpha(mask)
        im.save(os.path.join(out, "tab-%s-%s.png" % (name, state)))
print("ok")
