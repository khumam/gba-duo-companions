#!/usr/bin/env python3
"""The two clean-style tab glyphs the game has no icon for (map, options), in the pause screen's brick mauve so they read on
every theme's bar. Drawn smooth at 8x, reduced to 80 px (34.69 dp, like the item icons).   python3 art/clean_glyphs.py"""
import math, os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui")
PX, K, C = 80, 8, (152, 89, 111, 255)


def draw(kind):
    s = PX * K; im = Image.new("RGBA", (s, s), (0, 0, 0, 0)); d = ImageDraw.Draw(im); u = s / 48.0
    P = lambda x, y: (x * u, y * u); w = lambda n: int(n * u)
    if kind == "map":
        d.polygon([P(4, 12), P(16, 8), P(32, 12), P(44, 8), P(44, 36), P(32, 40), P(16, 36), P(4, 40)], outline=C, width=w(4.5))
        d.line([P(16, 8), P(16, 36)], fill=C, width=w(4)); d.line([P(32, 12), P(32, 40)], fill=C, width=w(4))
    else:
        cx = cy = 24 * u
        for t in range(8):
            a = t * math.pi / 4
            d.line([(cx + 11 * u * math.cos(a), cy + 11 * u * math.sin(a)), (cx + 21 * u * math.cos(a), cy + 21 * u * math.sin(a))], fill=C, width=w(8))
        d.ellipse([cx - 14 * u, cy - 14 * u, cx + 14 * u, cy + 14 * u], fill=C)
        d.ellipse([cx - 6 * u, cy - 6 * u, cx + 6 * u, cy + 6 * u], fill=(0, 0, 0, 0))
    return im.resize((PX, PX), Image.LANCZOS)


for k in ("map", "options"): draw(k).save(os.path.join(OUT, "cg-%s.png" % k))
print("ok")
