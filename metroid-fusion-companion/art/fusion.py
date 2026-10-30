#!/usr/bin/env python3
"""Pixel art for the Fusion companion, drawn in the look of the game's own pause screens
(art/ref/*): silver frame, teal tabs, green plates and counter panels, cyan item banners, navy grid.
All original art, sampled colours only; no game graphics (the Samus figure, map and logo are drawn
from the player's ROM at runtime).

  python3 art/fusion.py            writes assets/ui/*.png
  python3 art/fusion.py --sheet    also writes art/sheet.png (contact sheet)

One art pixel (AP) = 5 device px = 2.168dp on the Thor's second screen (1240x1080 px, 248 x 216 AP),
so every sprite is saved at 5x and sized in CSS as AP * 2.168px.
"""
import os
import sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "ui")
S = 5
os.makedirs(OUT, exist_ok=True)

# ---- palette (sampled from the pause screens) ---------------------------------------
K = "#000000"
INK = "#0a1018"
NAVY = "#161f2c"; GRID = "#1d3050"; GRID_HI = "#2a4a78"
CYAN = "#8de4da"; CYAN_D = "#5c97a2"; BLUE = "#3e73a3"; BLUE_D = "#2b5e92"; BLUE_DD = "#1e4975"; BLUE_DDD = "#12233a"
GREEN = "#568351"; GREEN_L = "#84c980"; GREEN_D = "#314a2e"; GREEN_DD = "#1c2c1b"
SIL_HI = "#f0f0ed"; SIL = "#d3e2d8"; SIL_MID = "#b8c6bd"; SIL_LO = "#9daaa2"; SIL_DK = "#838380"; SIL_DDK = "#595958"; SIL_BLK = "#2d2d2c"
YELLOW = "#ebd48c"; YELLOW_D = "#b8964a"
MAG = "#b183c2"; MAG_D = "#7a5f8d"
RED = "#cc5c6d"; RED_D = "#7a2d3a"
ORANGE = "#e8a060"
L1 = "#58a8f0"; L2 = "#58c868"; L3 = "#f09838"; L4 = "#e8506a"


def px(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def rect(im, x0, y0, x1, y1, c):
    """Fill [x0,x1) x [y0,y1)."""
    ImageDraw.Draw(im).rectangle([x0, y0, x1 - 1, y1 - 1], fill=px(c))


def dot(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), px(c))


def bitmap(rows, pal):
    h, w = len(rows), max(len(r) for r in rows)
    im = new(w, h)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal:
                dot(im, x, y, pal[ch])
    return im


def save(name, im):
    im.resize((im.width * S, im.height * S), Image.NEAREST).save(os.path.join(OUT, name + ".png"))
    SHEET.append((name, im))


SHEET = []

# ---- backdrop: the dark navy grid of the pause screens ---------------------------------

tile = new(8, 8)
rect(tile, 0, 0, 8, 8, NAVY)
for i in range(8):
    dot(tile, i, 0, GRID)
    dot(tile, 0, i, GRID)
dot(tile, 0, 0, GRID_HI)
save("bg-navy", tile)

# ---- top frame: silver bar, studs, a socket for the sector plate -----------------------

bar = new(248, 22)
for x in range(248):
    d = min(abs(x - 124), 62)
    depth = 21 if d <= 34 else max(13, 21 - (d - 34))
    for y in range(depth):
        dot(bar, x, y, SIL_LO)
    for y in range(1, max(1, depth - 5)):
        dot(bar, x, y, SIL_MID)
    dot(bar, x, 0, SIL_HI)
    dot(bar, x, 1, SIL)
    dot(bar, x, depth - 1, SIL_BLK)
    dot(bar, x, depth - 2, SIL_DK)
# studs along the bar
for x in range(8, 84, 12):
    dot(bar, x, 6, SIL_DK); dot(bar, x + 1, 6, SIL_DK)
    dot(bar, x, 7, SIL_DDK); dot(bar, x + 1, 7, SIL_DDK)
for x in range(170, 240, 12):
    dot(bar, x, 6, SIL_DK); dot(bar, x + 1, 6, SIL_DK)
    dot(bar, x, 7, SIL_DDK); dot(bar, x + 1, 7, SIL_DDK)
# plate socket
rect(bar, 84, 0, 164, 20, SIL_BLK)
rect(bar, 85, 0, 163, 19, SIL_DDK)
rect(bar, 86, 0, 162, 18, SIL_DK)
rect(bar, 87, 0, 161, 17, SIL_BLK)
save("topbar", bar)


def tab(right):
    """Teal tab with a diagonal cut on its inner end and a silver key cap on the outer end."""
    w, h = 77, 15
    im = new(w, h)
    body = new(w, h)
    rect(body, 0, 0, w, h, BLUE_DDD)
    rect(body, 1, 1, w - 1, h - 1, BLUE_DD)
    rect(body, 1, 1, w - 1, 2, BLUE)
    rect(body, 1, h - 3, w - 1, h - 1, BLUE_DDD)
    for y in range(h):
        cut = max(0, y - 3)
        for x in range(w):
            inside = x < w - 1 - cut if not right else x > cut
            if inside:
                im.putpixel((x, y), body.getpixel((x, y)))
    kx = 1 if not right else w - 14
    rect(im, kx, 1, kx + 13, h - 1, SIL_BLK)
    rect(im, kx + 1, 2, kx + 12, h - 2, SIL_LO)
    rect(im, kx + 2, 3, kx + 11, h - 3, SIL_BLK)
    return im


save("tab-l", tab(False))
save("tab-r", tab(True))

# sector plate (centre): green face in a silver rim
plate = new(72, 19)
rect(plate, 0, 0, 72, 19, SIL_BLK)
rect(plate, 1, 0, 71, 18, SIL_MID)
rect(plate, 2, 0, 70, 17, SIL_DDK)
rect(plate, 3, 0, 69, 16, GREEN_DD)
rect(plate, 4, 0, 68, 15, GREEN)
rect(plate, 4, 0, 68, 1, GREEN_L)
rect(plate, 4, 12, 68, 15, GREEN_D)
save("plate", plate)

# bottom message strip: dark with a studded silver rim on top
strip = new(248, 25)
rect(strip, 0, 0, 248, 25, INK)
for i in range(8):
    rect(strip, i, 0, i + 1, 8 - i, SIL_LO if i % 2 == 0 else SIL_DK)
    rect(strip, 247 - i, 0, 248 - i, 8 - i, SIL_LO if i % 2 == 0 else SIL_DK)
rect(strip, 8, 0, 240, 1, SIL_MID)
rect(strip, 8, 1, 240, 2, SIL_DK)
for x in range(20, 230, 14):
    dot(strip, x, 0, SIL_DDK)
save("strip", strip)

# ---- icons ------------------------------------------------------------------------------

save("ic-tank", bitmap([
    "KKKKKKKK",
    "KOOOOOOK",
    "KOYYYYOK",
    "KOYRRYOK",
    "KOYRRYOK",
    "KOYYYYOK",
    "KOOOOOOK",
    "KKKKKKKK",
], {"K": INK, "O": ORANGE, "Y": YELLOW, "R": RED}))

save("ic-missile", bitmap([
    "..KKKKKK....",
    ".KWWMMMMKK..",
    "KWWMMMMMMMK.",
    "KMMMMMMMMMMK",
    "KMMMMMMMMMMK",
    "KDDMMMMMMMK.",
    ".KDDDDDDKK..",
    "..KKKKKK....",
], {"K": INK, "W": SIL_HI, "M": MAG, "D": MAG_D}))

save("ic-pbomb", bitmap([
    "..KKKK..",
    ".KMMMMK.",
    "KMWWMMMK",
    "KMWMMMMK",
    "KMMMMMMK",
    "KMMMMDMK",
    ".KMDDDK.",
    "..KKKK..",
], {"K": INK, "M": MAG, "W": SIL_HI, "D": MAG_D}))

save("ic-clock", bitmap([
    "..KKKKK..",
    ".KCCCCCK.",
    "KCCCKCCCK",
    "KCCCKCCCK",
    "KCCCKKKCK",
    "KCCCCCCCK",
    ".KCCCCCK.",
    "..KKKKK..",
], {"K": INK, "C": CYAN}))

save("ic-skull", bitmap([
    ".KKKKKKK.",
    "KWWWWWWWK",
    "KWWWWWWWK",
    "KWKKWKKWK",
    "KWKKWKKWK",
    "KWWWKWWWK",
    ".KWWWWWK.",
    ".KWKWKWK.",
    "..KKKKK..",
], {"K": INK, "W": SIL_HI}))


def door(color):
    """A hatch: a coloured door set in a frame, one per security level."""
    return bitmap([
        "KKKKKKKKK",
        "KSSSSSSSK",
        "KSCCCCCSK",
        "KSCWCCCSK",
        "KSCCCCCSK",
        "KSCCCCCSK",
        "KSSSSSSSK",
        "KKKKKKKKK",
    ], {"K": INK, "S": SIL_MID, "C": color, "W": SIL_HI})


for n, c in enumerate((L1, L2, L3, L4), 1):
    save("door-%d" % n, door(c))


def node(kind):
    im = new(9, 9)
    rect(im, 0, 0, 9, 9, INK)
    if kind == "on":
        rect(im, 1, 1, 8, 8, CYAN)
        rect(im, 2, 2, 7, 7, CYAN_D)
        for x, y in [(2, 4), (3, 5), (4, 6), (5, 5), (6, 4), (6, 3), (6, 2)]:
            dot(im, x, y, INK)
    elif kind == "off":
        rect(im, 1, 1, 8, 8, BLUE_DD)
        rect(im, 2, 2, 7, 7, BLUE_DDD)
    else:
        rect(im, 1, 1, 8, 8, BLUE_DDD)
        rect(im, 2, 2, 7, 7, INK)
        for i in range(2, 7):
            dot(im, i, 8 - i, BLUE_DD)
    return im


save("node-on", node("on"))
save("node-off", node("off"))
save("node-lock", node("lock"))


def badge(face, rim, hi):
    rows = [
        "...KKKKKKKK...",
        "..KRRRRRRRRK..",
        ".KRHHHHHHHHRK.",
        "KRHFFFFFFFFHRK",
        "KRHFFFFFFFFHRK",
        "KRHFFFFFFFFHRK",
        "KRHFFFFFFFFHRK",
        "KRHFFFFFFFFHRK",
        "KRHFFFFFFFFHRK",
        ".KRHFFFFFFHRK.",
        "..KRRRRRRRRK..",
        "...KKKKKKKK...",
    ]
    return bitmap(rows, {"K": INK, "R": rim, "H": hi, "F": face})


save("hex-off", badge(BLUE_DDD, BLUE_D, BLUE))
save("hex-on", badge(GREEN, GREEN_L, SIL_HI))

# banner end cap: the stepped notch at the right of a cyan banner
save("banner-end", bitmap([
    "KKKKKK....",
    "KCCCCKK...",
    "KCCCCCKK..",
    "KCCCCCCCK.",
    "KDDDDDDDDK",
], {"K": INK, "C": CYAN, "D": CYAN_D}))

# you-are-here ring
def ring():
    n = 15
    im = new(n, n)
    c = (n - 1) / 2
    for y in range(n):
        for x in range(n):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if 6.5 <= d < 7.6 or 4.5 <= d < 5.5:
                dot(im, x, y, INK)
            elif 5.5 <= d < 6.5:
                dot(im, x, y, YELLOW)
    return im


save("crosshair", ring())

if "--sheet" in sys.argv:
    pad, x, y, rowh = 6, 6, 6, 0
    sheet = Image.new("RGBA", (1100, 500), px(NAVY))
    for name, im in SHEET:
        big = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
        if x + big.width + pad > sheet.width:
            x, y, rowh = 6, y + rowh + pad, 0
        sheet.alpha_composite(big, (x, y))
        x += big.width + pad
        rowh = max(rowh, big.height)
    sheet.save(os.path.join(HERE, "sheet.png"))
print("ok", len(SHEET), "sprites")
