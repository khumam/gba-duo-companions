#!/usr/bin/env python3
"""Expands `<n>ap` (art pixels, 1ap = 2.168px = 5 device px on the Thor) in
art/style.src.css and writes style.css.   python3 art/css.py"""
import os
import re

here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, "style.src.css")).read()
AP = 2.168


def conv(m):
    v = float(m.group(1)) * AP
    return ("%.3f" % v).rstrip("0").rstrip(".") + "px" if v else "0"


out = re.sub(r"(-?\d+(?:\.\d+)?)ap\b", conv, src)
open(os.path.join(here, "..", "style.css"), "w").write(out)
print("ok")
