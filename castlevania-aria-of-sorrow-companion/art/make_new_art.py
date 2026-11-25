#!/usr/bin/env python3
"""Small extra art for the 0.2.0 layout: the map tab glyph."""
import os
from PIL import Image, ImageDraw
here = os.path.dirname(os.path.abspath(__file__))
m = Image.new("RGBA", (14, 12), (0, 0, 0, 0)); d = ImageDraw.Draw(m)
d.rectangle([0, 0, 13, 11], fill=(0, 0, 231)); d.rectangle([1, 1, 12, 10], fill=(41, 0, 123))
for (a, b, c, e) in ((2, 2, 5, 4), (7, 2, 11, 4), (2, 6, 4, 9), (6, 6, 11, 9)): d.rectangle([a, b, c, e], outline=(0, 206, 206))
m.save(os.path.join(here, "..", "assets", "ui", "tab-map.png"))
print("ok")
