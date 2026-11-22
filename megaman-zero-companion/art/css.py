#!/usr/bin/env python3
"""style.css = art/style.src.css + art/pos.src.css (written by layout.py) with `<n>ap` (art pixels) expanded.
1 ap = 2.168 dp = 5 device px on the Thor; the page art is 248 x 216 ap."""
import re
src = open("art/style.src.css").read() + "\n" + open("art/pos.src.css").read()
def conv(m):
    v = float(m.group(1)) * 2.168
    return ("%.2f" % v).rstrip("0").rstrip(".") + "px"
open("style.css", "w").write(re.sub(r"(-?\d+(?:\.\d+)?)ap\b", conv, src))
