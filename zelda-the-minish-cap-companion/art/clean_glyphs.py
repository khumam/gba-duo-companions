#!/usr/bin/env python3
"""Tab glyphs of the clean (slate) style: flat one-colour category icons, drawn smooth at 4x and reduced to the exact device size
(24 dp = 55 px on the Thor, CSS image-rendering: auto). on = white, off = grey.   python3 art/clean_glyphs.py"""
import math, os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui")
PX, K = 55, 8


def glyph(kind, c):
    s = PX * K
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    u = s / 48.0
    P = lambda x, y: (x * u, y * u)
    w = lambda n: int(n * u)
    if kind == "items":      # a sword
        d.polygon([P(8, 40), P(34, 14), P(40, 8), P(38, 16), P(12, 42)], fill=c)
        d.line([P(9, 28), P(20, 39)], fill=c, width=w(5)); d.line([P(5, 43), P(12, 36)], fill=c, width=w(5))
    elif kind == "kinstone":  # a split medallion
        d.ellipse([P(5, 6), P(43, 42)], outline=c, width=w(4.5))
        d.line([P(22, 6), P(29, 18), P(19, 28), P(26, 42)], fill=c, width=w(4.5))
    elif kind == "map":       # a folded map
        d.polygon([P(4, 12), P(16, 8), P(32, 12), P(44, 8), P(44, 36), P(32, 40), P(16, 36), P(4, 40)], outline=c, width=w(4.5))
        d.line([P(16, 8), P(16, 36)], fill=c, width=w(4)); d.line([P(32, 12), P(32, 40)], fill=c, width=w(4))
    elif kind == "quest":     # the triforce
        for (x, y) in ((24, 5), (13, 24), (35, 24)):
            d.polygon([P(x, y), P(x + 11, y + 19), P(x - 11, y + 19)], fill=c)
    else:                     # options: a cog
        cx, cy = 24 * u, 24 * u
        for t in range(8):
            a = t * math.pi / 4
            d.line([(cx + 11 * u * math.cos(a), cy + 11 * u * math.sin(a)), (cx + 21 * u * math.cos(a), cy + 21 * u * math.sin(a))], fill=c, width=w(8))
        d.ellipse([cx - 14 * u, cy - 14 * u, cx + 14 * u, cy + 14 * u], fill=c)
        d.ellipse([cx - 6 * u, cy - 6 * u, cx + 6 * u, cy + 6 * u], fill=(0, 0, 0, 0))
    return im.resize((PX, PX), Image.LANCZOS)


for kind in ("map", "items", "kinstone", "quest", "options"):
    glyph(kind, (255, 255, 255, 255)).save(os.path.join(OUT, "cg-%s-on.png" % kind))
    glyph(kind, (120, 124, 116, 255)).save(os.path.join(OUT, "cg-%s-off.png" % kind))
print("ok")
