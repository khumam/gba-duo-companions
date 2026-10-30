#!/usr/bin/env python3
"""Pixel art for the Zero Mission companion, drawn in the look of the game's own
pause screens (art/ref/*): steel frame, lavender plates, mint banners, teal and
olive grids. All original art, sampled colours only; no game graphics.

  python3 art/pause.py            writes assets/ui/*.png
  python3 art/pause.py --sheet    also writes art/sheet.png (contact sheet)

One art pixel (AP) = 5 device px = 2.168dp on the Thor's second screen (1240x1080 px,
248 x 216 AP), so every sprite is saved at 5x and sized in CSS as AP * 2.168px.
"""
import os
import sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "ui")
OLD_MAP = os.path.join(HERE, "ref", "map-brinstar-v1.png")
S = 5
os.makedirs(OUT, exist_ok=True)

# ---- palette (sampled from the pause screens) ---------------------------------------
K = "#000000"
INK = "#0a1008"
BG = "#14252c"; GRID = "#263b32"; GRID_HI = "#37584d"
OBG = "#212921"; OGRID = "#085b10"
MINT = "#86bc90"; MINT_L = "#bfe1c9"; TEAL = "#578c87"; TEAL_D = "#37584d"; TEAL_DD = "#1d3a3a"
LAV = "#d39ad6"; LAV_L = "#ecc4ee"; LAV_D = "#8d5f9e"; LAV_DD = "#3d2a4a"
TAN = "#ebd389"; TAN_D = "#b8964a"; TAN_DD = "#7a5a2c"
W = "#f0f0ed"; ST2 = "#a9afa4"; ST3 = "#7f867b"; ST4 = "#4f554b"; ST5 = "#232921"
BLUE = "#387ec8"; BLUE_D = "#1f4a80"
ROSE = "#d9566a"; ROSE_D = "#8a2a42"; PINK = "#d070b0"
OLIVE = "#bec87e"; OLIVE_D = "#7b8346"
ORANGE = "#e8a060"; ROOM = "#727270"


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


def poly(im, pts, c):
    ImageDraw.Draw(im).polygon(pts, fill=px(c))


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

# ---- backdrops -----------------------------------------------------------------------


def grid_tile(bg, line, hi=None):
    im = new(8, 8)
    rect(im, 0, 0, 8, 8, bg)
    for i in range(8):
        dot(im, i, 0, line)
        dot(im, 0, i, line)
    if hi:
        dot(im, 0, 0, hi)
    return im


save("bg-teal", grid_tile(BG, GRID, GRID_HI))

# ---- top frame: tapered steel bar with a notch for the sector plate -----------------------

bar = new(248, 22)
# steel body, 14 rows tall at the edges, dropping to 21 around the plate (45 degree bevels)
for x in range(248):
    d = min(abs(x - 124), 62)
    depth = 21 if d <= 34 else max(13, 21 - (d - 34))
    for y in range(depth):
        dot(bar, x, y, ST5)
    for y in range(1, max(1, depth - 5)):
        dot(bar, x, y, ST4)
    dot(bar, x, 0, ST3)
    dot(bar, x, 1, ST2)
    dot(bar, x, depth - 1, K)
    dot(bar, x, depth - 2, ST5)
# plate socket
rect(bar, 84, 0, 164, 20, K)
rect(bar, 85, 0, 163, 19, ST4)
rect(bar, 86, 0, 162, 18, ST3)
rect(bar, 87, 0, 161, 17, ST5)
save("topbar", bar)

# tabs: lavender plate, diagonal cut on the inner end, key cap on the outer end
def tab(right):
    w, h = 77, 15
    im = new(w, h)
    body = new(w, h)
    rect(body, 0, 0, w, h, LAV_DD)
    rect(body, 1, 1, w - 1, h - 1, LAV)
    rect(body, 1, 1, w - 1, 2, LAV_L)
    rect(body, 1, h - 3, w - 1, h - 1, LAV_D)
    rect(body, 1, h - 2, w - 1, h - 1, LAV_DD)
    # inner end bevel
    for i in range(h):
        for x in range(w - 1 - i if not right else 0, w if not right else i + 1):
            pass
    mask = new(w, h)
    for y in range(h):
        cut = max(0, y - 3)
        for x in range(w):
            inside = x < w - 1 - cut if not right else x > cut
            if inside:
                dot(mask, x, y, W)
    for y in range(h):
        for x in range(w):
            if mask.getpixel((x, y))[3]:
                im.putpixel((x, y), body.getpixel((x, y)))
    # key cap at the outer end
    kx = 1 if not right else w - 14
    rect(im, kx, 1, kx + 13, h - 1, K)
    rect(im, kx + 1, 2, kx + 12, h - 2, ST3)
    rect(im, kx + 2, 3, kx + 11, h - 3, ST5)
    return im


save("tab-l", tab(False))
save("tab-r", tab(True))

# sector plate (centre): double steel rim round a lavender face
plate = new(72, 19)
rect(plate, 0, 0, 72, 19, K)
rect(plate, 1, 0, 71, 18, ST3)
rect(plate, 2, 0, 70, 17, ST5)
rect(plate, 3, 0, 69, 16, LAV_DD)
rect(plate, 4, 0, 68, 15, LAV)
rect(plate, 4, 0, 68, 1, LAV_L)
rect(plate, 4, 12, 68, 15, LAV_D)
save("plate", plate)

# bottom message strip: black with steel chamfers at the corners
strip = new(248, 25)
rect(strip, 0, 0, 248, 25, K)
for i in range(8):
    rect(strip, i, 0, i + 1, 8 - i, ST3 if i % 2 == 0 else ST4)
    rect(strip, 247 - i, 0, 248 - i, 8 - i, ST3 if i % 2 == 0 else ST4)
rect(strip, 8, 0, 240, 1, ST4)
rect(strip, 8, 1, 240, 2, ST5)
save("strip", strip)

# ---- icons ---------------------------------------------------------------------------

save("cube", bitmap([
    "...KKKKKK...",
    "..KBBBBBBK..",
    ".KBBMMMMBBK.",
    "KBMMMMMMMMBK",
    "KBMOOOOOOMBK",
    "KBMOOOOOOMBK",
    "KBMOOOOOOMBK",
    "KBMOOOOOOMBK",
    "KBMOOOOOOMBK",
    ".KBMOOOOMBK.",
    "..KBBBBBBK..",
    "...KKKKKK...",
], {"K": K, "B": BLUE, "M": MINT_L, "O": ORANGE}))

save("ic-missile", bitmap([
    "..KKKKKK....",
    ".KWWRRRRKK..",
    "KWWRRRRRRRK.",
    "KRRRRRRRRRRK",
    "KRRRRRRRRRRK",
    "KDDRRRRRRRK.",
    ".KDDDDDDKK..",
    "..KKKKKK....",
], {"K": K, "W": W, "R": ROSE, "D": ROSE_D}))

save("ic-super", bitmap([
    "..KKKKKK....",
    ".KWWGGGGKK..",
    "KWWGGGGGGGK.",
    "KGGGGGGGGGGK",
    "KGGGGGGGGGGK",
    "KDDGGGGGGGK.",
    ".KDDDDDDKK..",
    "..KKKKKK....",
], {"K": K, "W": W, "G": MINT, "D": TEAL_D}))

save("ic-pbomb", bitmap([
    "..KKKK..",
    ".KOOOOK.",
    "KOTTOOOK",
    "KOTOOOOK",
    "KOOOOOOK",
    "KOOOOEOK",
    ".KOEEEK.",
    "..KKKK..",
], {"K": K, "O": TAN, "T": W, "E": TAN_D}))

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
], {"K": INK, "W": W}))

save("ic-clock", bitmap([
    "..KKKKK..",
    ".KWWWWWK.",
    "KWWWKWWWK",
    "KWWWKWWWK",
    "KWWWKKKWK",
    "KWWWWWWWK",
    ".KWWWWWK.",
    "..KKKKK..",
], {"K": INK, "W": MINT_L}))

# toggle nodes (suit/beam armory)
def node(kind):
    im = new(9, 9)
    rect(im, 0, 0, 9, 9, INK)
    if kind == "on":
        rect(im, 1, 1, 8, 8, MINT_L)
        rect(im, 2, 2, 7, 7, MINT)
        for x, y in [(2, 4), (3, 5), (4, 6), (5, 5), (6, 4), (6, 3), (6, 2)]:
            dot(im, x, y, INK)
    elif kind == "off":
        rect(im, 1, 1, 8, 8, TEAL)
        rect(im, 2, 2, 7, 7, TEAL_DD)
    else:
        rect(im, 1, 1, 8, 8, TEAL_D)
        rect(im, 2, 2, 7, 7, INK)
        for i in range(2, 7):
            dot(im, i, 8 - i, TEAL)
    return im


save("node-on", node("on"))
save("node-off", node("off"))
save("node-lock", node("lock"))

# hex slot badge (the Samus Data A/B/C hexagons); the letter is text on top
def hexbadge(face, rim, hi):
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


save("hex-on", hexbadge(ROSE, MINT, MINT_L))
save("hex-off", hexbadge(TEAL_DD, OLIVE_D, OLIVE))
save("hex-here", hexbadge(BLUE, MINT, MINT_L))

# banner end cap: the stepped notch at the right of a mint banner
save("banner-end", bitmap([
    "KKKKKK....",
    "KMMMMKK...",
    "KMMMMMKK..",
    "KMMMMMMMK.",
    "KTTTTTTTTK",
], {"K": INK, "M": MINT, "T": TEAL}))

# key cap for L / R hints inside the tabs is drawn in the tab art; map A-button badge:
save("btn-a", bitmap([
    "..KKKKKK..",
    ".KWWWWWWK.",
    "KWWWWWWWWK",
    "KWWWWWWWWK",
    "KWWWWWWWWK",
    "KWWWWWWWWK",
    "KWWWWWWWWK",
    ".KWWWWWWK.",
    "..KKKKKK..",
], {"K": TEAL_D, "W": ST5}))

# ---- Samus suit silhouette + hex lattice ----------------------------------------------

def lattice():
    w, h = 62, 92
    im = new(w, h)
    cols = [PINK, "#b8629c", "#92508c", "#6a4074", "#44304f"]
    d = ImageDraw.Draw(im)
    for c in range(-1, 6):
        x0 = c * 15 + 1
        for r in range(-1, 9):
            y0 = r * 12 + (6 if c % 2 else 0) + 4
            cx, cy = x0 + 10, y0 + 6
            t = ((cx - w / 2) ** 2 / 900 + (cy - h / 2) ** 2 / 2300)
            col = cols[min(4, int(t * 3))]
            pts = [(x0 + 5, y0), (x0 + 15, y0), (x0 + 20, y0 + 6), (x0 + 15, y0 + 12), (x0 + 5, y0 + 12), (x0, y0 + 6)]
            d.line(pts + [pts[0]], fill=px(col), width=1)
    return im


save("lattice", lattice())




def ring():
    """A you-are-here ring: tan band with an ink edge on both sides, readable on any tile colour."""
    n = 15
    im = new(n, n)
    c = (n - 1) / 2
    for y in range(n):
        for x in range(n):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if 6.5 <= d < 7.6 or 4.5 <= d < 5.5:
                dot(im, x, y, INK)
            elif 5.5 <= d < 6.5:
                dot(im, x, y, TAN)
    return im


save("crosshair", ring())

if "--sheet" in sys.argv:
    pad, x, y, rowh = 6, 6, 6, 0
    sheet = Image.new("RGBA", (1100, 900), px(BG))
    for name, im in SHEET:
        big = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
        if x + big.width + pad > sheet.width:
            x, y, rowh = 6, y + rowh + pad, 0
        sheet.alpha_composite(big, (x, y))
        x += big.width + pad
        rowh = max(rowh, big.height)
    sheet.save(os.path.join(HERE, "sheet.png"))
print("ok", len(SHEET), "sprites")
