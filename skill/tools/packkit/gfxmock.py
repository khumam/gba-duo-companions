#!/usr/bin/env python3
"""Renders the gfx.decode calls recorded by run.lua ("gfxmock:decode?..." keys) from the ROM into PNGs and rewrites
the preview JSON to point at them, so preview-pack.sh shows the game's real portraits / icons.

    python3 -I skill/tools/packkit/gfxmock.py ROM PACK_DIR/preview-data.json

PNGs go to PACK_DIR/assets/_preview/ (`asset:` paths resolve under assets/); keep it out of the release zip. Only `decode` is drawn (4bpp tiles
row by row, colour 0 transparent, optional LZ77); other gfx calls are left as they are.
"""
import hashlib
import json
import os
import struct
import sys

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "harness"))
from lz77 import lz77  # noqa: E402

rom = open(sys.argv[1], "rb").read()
path = sys.argv[2]
pack = os.path.dirname(os.path.abspath(path))
outdir = os.path.join(pack, "assets", "_preview")
os.makedirs(outdir, exist_ok=True)
R = lambda a: a - 0x08000000  # noqa: E731
done = {}


def decode(args):
    tiles, pal = int(args["tiles"]), int(args["palette"])
    w, h = int(args["width"]), int(args["height"])
    data = lz77(rom, R(tiles), 0x100000) if args.get("lz77") == "1" else rom[R(tiles):R(tiles) + w * h // 2]
    cols = []
    for i in range(16):
        c = struct.unpack_from("<H", rom, R(pal) + 2 * i)[0]
        cols.append(((c & 31) * 255 // 31, ((c >> 5) & 31) * 255 // 31, ((c >> 10) & 31) * 255 // 31, 255))
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    tw = w // 8
    for t in range(min(len(data or b"") // 32, tw * (h // 8))):
        for y in range(8):
            for x in range(8):
                v = (data[t * 32 + y * 4 + x // 2] >> ((x & 1) * 4)) & 15
                if v:
                    px[(t % tw) * 8 + x, (t // tw) * 8 + y] = cols[v]
    return im


def fix(v):
    if isinstance(v, dict):
        return {k: fix(x) for k, x in v.items()}
    if isinstance(v, list):
        return [fix(x) for x in v]
    if isinstance(v, str) and v.startswith("gfxmock:decode?"):
        if v not in done:
            args = dict(kv.split("=", 1) for kv in v.split("?", 1)[1].split("&") if kv)
            name = hashlib.md5(v.encode()).hexdigest()[:12] + ".png"
            try:
                decode(args).save(os.path.join(outdir, name))
                done[v] = "asset:_preview/" + name
            except Exception as e:  # noqa: BLE001
                print("skip", v, e)
                done[v] = v
        return done[v]
    return v


data = json.load(open(path))
json.dump(fix(data), open(path, "w"), indent=1)
print(f"{len(done)} images -> {outdir}")
