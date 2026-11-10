#!/usr/bin/env python3
"""Tile a pack's preview screenshots into one labelled overview sheet.

  python3 skill/overview-sheet.py <screenshots-dir> [--out sheet.png] [--order a,b,c] [--cols 3] [--tile 420x366]

<screenshots-dir> holds PNGs named after the page (map.png, party.png, dex-search.png ...): the output of
preview-pack.sh, with `screen-` stripped off the names (see "Overview sheet" in SKILL.md). Each tile is the page's
screenshot shrunk to --tile, with the page name above it on a dark background. Pages missing from --order are
appended alphabetically; names in --order that have no file are skipped. Needs Pillow.
"""
import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument("dir")
parser.add_argument("--out", help="default: <dir>/../<dir name>-overview.png")
parser.add_argument("--order", default="map,party,detail,bag,dex,dex-search,trainer,options,battle,battle-detail")
parser.add_argument("--cols", type=int, default=3)
parser.add_argument("--tile", default="420x366", help="WxH of one tile (the Thor's screen is 1240x1080: keep the ratio)")
args = parser.parse_args()

src = Path(args.dir)
found = {p.stem: p for p in src.glob("*.png") if not p.stem.endswith("overview")}
names = [n for n in args.order.split(",") if n in found] + sorted(n for n in found if n not in args.order.split(","))
if not names:
    sys.exit(f"no PNGs in {src}")
tw, th = (int(v) for v in args.tile.lower().split("x"))
cols = min(args.cols, len(names))
rows = (len(names) + cols - 1) // cols
LABEL, GAP = 18, 8
sheet = Image.new("RGB", (cols * (tw + GAP) + GAP, rows * (th + LABEL + GAP) + GAP), (30, 30, 30))
draw = ImageDraw.Draw(sheet)
for i, name in enumerate(names):
    x, y = GAP + (i % cols) * (tw + GAP), GAP + (i // cols) * (th + LABEL + GAP)
    draw.text((x, y), name, fill=(255, 255, 255))
    sheet.paste(Image.open(found[name]).convert("RGB").resize((tw, th), Image.LANCZOS), (x, y + LABEL))
out = Path(args.out) if args.out else src.parent / f"{src.name}-overview.png"
sheet.save(out)
print(f"{out}  ({len(names)} pages: {', '.join(names)})")
