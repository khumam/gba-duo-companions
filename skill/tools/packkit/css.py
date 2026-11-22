#!/usr/bin/env python3
"""Expands `<n>ap` (art pixels) in a pack's art/style.src.css into px and writes style.css.

    python3 skill/tools/packkit/css.py PACK_DIR [--ap 2.168]

1ap = 2.168 px = 5 device pixels on the Thor (538 dp wide = 248 ap). Design the pack on a 248 x 216 ap grid
(nav plates at the bottom from 190ap) and size images in whole ap per image pixel so pixel art stays crisp.
Packs that predate this keep their own art/css.py copy; both do the same thing.
"""
import argparse
import os
import re

ap = argparse.ArgumentParser()
ap.add_argument("pack")
ap.add_argument("--ap", type=float, default=2.168)
a = ap.parse_args()
src = open(os.path.join(a.pack, "art", "style.src.css")).read()


def conv(m):
    v = float(m.group(1)) * a.ap
    return ("%.3f" % v).rstrip("0").rstrip(".") + "px" if v else "0"


open(os.path.join(a.pack, "style.css"), "w").write(re.sub(r"(-?\d+(?:\.\d+)?)ap\b", conv, src))
print("ok", os.path.join(a.pack, "style.css"))
