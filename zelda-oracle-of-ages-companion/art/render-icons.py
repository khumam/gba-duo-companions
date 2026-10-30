#!/usr/bin/env python3
"""Draws the game's own item icons from the oracles-disasm checkout (sprite sheets + the treasure
display tables + the standard sprite palettes) into assets/ui/<name>.png, 160 px for 16x16
(10 device px per game pixel, 69.38dp; the HUD draws them at half size).

  python3 art/render-icons.py <oracles-disasm checkout> [--sheet out.png]
"""
import os, re, sys
from PIL import Image

root = sys.argv[1]
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")
SCALE = 10

def load_png(name):
    for d in ("gfx", "gfx_compressible"):
        for sub in ("ages", "common"):
            p = os.path.join(root, d, sub, name + ".png")
            if os.path.exists(p): return Image.open(p)
    raise FileNotFoundError(name)

def rgb(r, g, b):  # 5-bit channels, with the LCD colour mix mGBA applies to GBC games
    r, g, b = (r * 26 + g * 4 + b * 2) // 32, (g * 24 + b * 8) // 32, (r * 6 + g * 4 + b * 22) // 32
    return (r * 255 // 31, g * 255 // 31, b * 255 // 31)

# the six standard sprite palettes (attribute 0-5): colour 0 is transparent
text = open(os.path.join(root, "data/ages/paletteData.s")).read()
block = text.split("standardSpritePaletteData:")[1]
cols = [rgb(*(int(x, 16) for x in m)) for m in re.findall(r"m_RGB16 \$(\w+) \$(\w+) \$(\w+)", block)[:24]]
PALETTES = [cols[i * 4:(i + 1) * 4] for i in range(6)]

# sprite number (index & 0x7f) -> (sheet, column): the order the gfx header loads them in VRAM
SHEETS = [("spr_item_icons_1_spr", 0), ("spr_item_icons_2", 16), ("spr_item_icons_3", 32), ("spr_essences", 48),
          ("spr_quest_items_1", 64), ("spr_quest_items_2", 80), ("spr_quest_items_3", 96), ("spr_quest_items_4", 112)]

def sprite(idx, attr, invert):
    """One 8x16 sprite as RGBA (colour index 0 transparent)."""
    s = idx & 0x7F
    for name, first in reversed(SHEETS):
        if s >= first:
            sheet = load_png(name); col = s - first; break
    pal = PALETTES[attr & 7] if (attr & 7) < 6 else PALETTES[0]
    idx = [[0] * 8 for _ in range(16)]
    for y in range(16):
        for x in range(8):
            v = sheet.getpixel((col * 8 + x, y)) if col * 8 + 8 <= sheet.width else 255
            idx[y][x] = v if sheet.mode == "P" else (round(v / 85) if invert else 3 - round(v / 85))
    im = Image.new("RGBA", (8, 16), (0, 0, 0, 0))
    for y in range(16):
        for x in range(8):
            if idx[y][x]: im.putpixel((7 - x if attr & 0x20 else x, y), pal[idx[y][x]] + (255,))
    return im

def icon(left, right=None, invert=False):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    l = sprite(*left, invert); im.paste(l, (0, 0), l)
    if right and right[0]:
        r = sprite(*right, invert); im.paste(r, (8, 0), r)
    return im

ICONS = {
    "sword": ((0x90, 0),), "shield": ((0x93, 0),), "bombs": ((0x9E, 4),), "cane": ((0x97, 2),),
    "boomerang": ((0x9C, 5),), "biggoron": ((0xA1, 3), (0xA2, 3)), "bombchu": ((0xA0, 5),),
    "shooter": ((0x81, 5),), "flute": ((0x8B, 0), (0x8C, 0)), "harp": ((0xA3, 0), (0xA4, 0)),
    "shovel": ((0x9B, 4),), "bracelet": ((0x99, 5),), "feather": ((0x96, 4),), "satchel": ((0x80, 5),),
    "hook": ((0x9F, 4),), "seed-ember": ((0x83, 2),), "seed-scent": ((0x84, 3),), "seed-pegasus": ((0x85, 1),),
    "seed-gale": ((0x86, 1),), "seed-mystery": ((0x87, 0),),
}

def save(name, im):
    big = im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST)
    big.save(os.path.join(OUT, name + ".png"))

invert = "--invert" in sys.argv
sheet = Image.new("RGBA", (len(ICONS) * 20, 20), (237, 237, 233, 255))
for i, (name, parts) in enumerate(ICONS.items()):
    im = icon(parts[0], parts[1] if len(parts) > 1 else None, invert)
    if "--sheet" in sys.argv: sheet.paste(im, (i * 20 + 2, 2), im)
    else: save(name, im)
if "--sheet" in sys.argv:
    sheet.resize((sheet.width * 5, sheet.height * 5), Image.NEAREST).save(sys.argv[sys.argv.index("--sheet") + 1])
else:
    print("wrote", len(ICONS), "icons")
