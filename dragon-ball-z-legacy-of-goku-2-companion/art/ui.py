#!/usr/bin/env python3
"""Draws the window chrome of the Legacy of Goku II companion into assets/ui.

The look is the game's own pause menu (art/ref/*.png): sky-blue folder window with a
notched tab, black/purple striped inner panel, orange nav rule with the shoulder
buttons, grey arrow keys, red / green / rainbow-segment bars. Everything here is
original pixel art in the game's palette (1 art pixel = 1 px in the PNG; the CSS
scales it by 5 device px). The portraits and item pictures are NOT drawn here: they
come from art/extract.py.

    python3 art/ui.py
"""
import os, random
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "ui")
os.makedirs(OUT, exist_ok=True)

def C(h):
    h = h.lstrip("#"); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)

BLUE = C("6bb5de"); HL1 = C("b5deef"); HL2 = C("8cc6e7"); SH1 = C("5294b5"); SH3 = C("294252")
BLACK = C("000000"); STRIPE = C("421842")
OR_D = C("ce6300"); OR_M = C("ffbd00"); OR_L = C("d66b4a")
SCREEN_W, SCREEN_H = 248, 216

def save(im, name):
    im.save(os.path.join(OUT, name + ".png"))

# ---- starfield -------------------------------------------------------------------------------
def starfield():
    rnd = random.Random(7)
    pal = [C(x) for x in ("632163", "6b296b", "7b317b", "8c318c", "9c399c", "a539a5")]
    # low-res value noise, upscaled with nearest, so the clouds are chunky like the game's
    gw, gh = 33, 29
    g = [[rnd.random() for _ in range(gw)] for _ in range(gh)]
    im = Image.new("RGBA", (SCREEN_W, SCREEN_H))
    px = im.load()
    for y in range(SCREEN_H):
        for x in range(SCREEN_W):
            fx, fy = x / 8.0, y / 8.0
            x0, y0 = int(fx), int(fy); tx, ty = fx - x0, fy - y0
            a = g[y0][x0] * (1 - tx) + g[y0][x0 + 1] * tx
            b = g[y0 + 1][x0] * (1 - tx) + g[y0 + 1][x0 + 1] * tx
            v = a * (1 - ty) + b * ty
            v += rnd.uniform(-.06, .06)
            i = max(0, min(len(pal) - 1, int(v * len(pal) * 1.15 - .1)))
            px[x, y] = pal[i]
    d = ImageDraw.Draw(im)
    for _ in range(95):
        x, y = rnd.randrange(SCREEN_W), rnd.randrange(SCREEN_H)
        d.point((x, y), fill=rnd.choice([C("f0c8f0"), C("d652d6"), C("ffffff"), C("c652c6")]))
        if rnd.random() < .15:
            d.point((x + 1, y), fill=C("d652d6"))
    return im

# ---- the folder window -------------------------------------------------------------------------
WIN_W, WIN_H = 232, 166
TAB_TOP, BODY_TOP, BODY_BOT = 2, 20, 162

def window_mask():
    m = Image.new("L", (WIN_W, WIN_H), 0)
    d = ImageDraw.Draw(m)
    d.rectangle([0, BODY_TOP, WIN_W - 4, BODY_BOT], fill=255)
    d.polygon([(8, BODY_TOP), (26, TAB_TOP), (94, TAB_TOP), (112, BODY_TOP)], fill=255)
    for (x, y) in ((0, BODY_TOP), (WIN_W - 4, BODY_TOP), (0, BODY_BOT), (WIN_W - 4, BODY_BOT)):
        d.point((x, y), fill=0)
    return m

def window(list_style):
    m = window_mask(); mp = m.load()
    W, H = m.size
    def inside(x, y): return 0 <= x < W and 0 <= y < H and mp[x, y] > 0
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0)); px = im.load()
    # ghost page tabs behind the tab (decor, like the game's stacked tabs)
    gd = ImageDraw.Draw(im)
    for i, col in enumerate(("5a8cce", "4252b5", "4a399c", "5a297b")):
        x0 = 98 + i * 17
        gd.polygon([(x0, TAB_TOP + 6), (x0 + 16, TAB_TOP + 6), (x0 + 28, BODY_TOP), (x0 + 12, BODY_TOP)], fill=C(col))
    # black drop shadow (3 px right and down)
    for y in range(H):
        for x in range(W):
            if not inside(x, y) and any(inside(x - k, y - k) or inside(x - k, y) or inside(x, y - k) for k in (1, 2, 3)):
                px[x, y] = BLACK
    for y in range(H):
        for x in range(W):
            if not inside(x, y): continue
            c = BLUE
            if not inside(x, y - 1) or not inside(x - 1, y): c = HL1
            elif not inside(x, y - 2) or not inside(x - 2, y): c = HL2
            if not inside(x + 1, y) or not inside(x, y + 1): c = SH3
            elif not inside(x + 2, y) or not inside(x, y + 2): c = SH1
            px[x, y] = c
    if list_style:
        x0, y0, x1, y1 = 8, 28, WIN_W - 12, BODY_BOT - 8   # inner panel
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                px[x, y] = BLACK if (y - y0) % 2 == 0 else STRIPE
        for x in range(x0 - 2, x1 + 3):                       # inset: dark top/left, light bottom/right
            px[x, y0 - 2] = SH1; px[x, y0 - 1] = SH3
            px[x, y1 + 1] = SH1; px[x, y1 + 2] = HL1
        for y in range(y0 - 2, y1 + 3):
            px[x0 - 2, y] = SH1; px[x0 - 1, y] = SH3
            px[x1 + 1, y] = SH1; px[x1 + 2, y] = HL1
        px[x1 + 2, y0 - 2] = SH1; px[x0 - 2, y1 + 2] = SH1
        # a faint lighter band, the watermark the game has behind its lists
        for y in range(y0 + 2, y1 - 1):
            for x in range(x0 + 60 + (y - y0) // 3, x0 + 118 + (y - y0) // 3):
                if x <= x1 and (y - y0) % 2 == 1: px[x, y] = C("361436")
    return im

# ---- nav rule ---------------------------------------------------------------------------------
def navbar():
    im = Image.new("RGBA", (SCREEN_W, 40), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    top, bot = 6, 20          # y of the left/right rule and of the dipped middle
    xs = [(0, 66, top), (66, 80, None), (80, 168, bot), (168, 182, None), (182, SCREEN_W, top)]
    def band(y, col):
        pass
    def hline(x0, x1, y):
        d.rectangle([x0, y + 3, x1, y + 3], fill=BLACK)
        d.rectangle([x0, y, x1, y], fill=OR_D); d.rectangle([x0, y + 1, x1, y + 1], fill=OR_M); d.rectangle([x0, y + 2, x1, y + 2], fill=OR_L)
    hline(0, 76, top)
    hline(90, 158, bot)
    hline(172, SCREEN_W - 1, top)
    # diagonals (45 degrees, 22 px drop)
    for i in range(0, bot - top + 1):
        for (x, ax) in ((76 + i, 1), (172 - i, -1)):
            d.point((x, top + i + 3), fill=BLACK)
            d.point((x, top + i), fill=OR_D); d.point((x, top + i + 1), fill=OR_M); d.point((x, top + i + 2), fill=OR_L)
            d.point((x + ax, top + i + 1), fill=OR_M); d.point((x + ax, top + i + 2), fill=OR_M)
    return im

# ---- buttons ----------------------------------------------------------------------------------
def arrow_btn(direction, on):
    w, h = (16, 14) if direction in "lr" else (14, 16)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0)); px = im.load(); d = ImageDraw.Draw(im)
    if on: hi, lt, bd, lo, dk = C("ffffff"), C("cecece"), C("b5b5b5"), C("a5a5a5"), C("8c8c8c")
    else:  hi, lt, bd, lo, dk = C("7b7b7b"), C("636363"), C("525252"), C("464646"), C("393939")
    d.rectangle([0, 0, w - 2, h - 2], fill=bd)
    d.rectangle([0, 0, w - 2, 1], fill=hi); d.rectangle([0, 0, 1, h - 2], fill=hi)
    d.rectangle([2, 2, w - 3, 2], fill=lt)
    d.rectangle([0, h - 3, w - 2, h - 2], fill=lo); d.rectangle([w - 3, 0, w - 2, h - 2], fill=lo)
    d.rectangle([w - 1, 1, w - 1, h - 1], fill=BLACK); d.rectangle([1, h - 1, w - 1, h - 1], fill=BLACK)
    cx, cy = (w - 1) // 2, (h - 1) // 2
    tri = {"l": [(cx + 3, cy - 4), (cx + 3, cy + 4), (cx - 3, cy)], "r": [(cx - 3, cy - 4), (cx - 3, cy + 4), (cx + 3, cy)],
           "u": [(cx - 4, cy + 3), (cx + 4, cy + 3), (cx, cy - 3)], "d": [(cx - 4, cy - 3), (cx + 4, cy - 3), (cx, cy + 3)]}[direction]
    d.polygon(tri, fill=lo if on else dk, outline=dk if on else C("2e2e2e"))
    return im

def shoulder(left):
    """Nav button: a grey plate whose right edge follows the slant of the nav rule; the label sits on it."""
    W, H = 90, 27
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    pts = [(2, 4), (6, 0), (72, 0), (86, 14), (86, 22), (82, 24), (6, 24), (2, 20)]
    d.polygon([(x + 2, y + 2) for x, y in pts], fill=BLACK)
    d.polygon(pts, fill=C("b5b5b5"))
    d.line([(6, 0), (72, 0), (86, 14)], fill=C("ffffff"), width=1)
    d.line([(2, 4), (6, 1)], fill=C("ffffff")); d.line([(2, 4), (2, 20)], fill=C("ffffff"))
    d.line([(6, 1), (71, 1)], fill=C("cecece"))
    d.line([(2, 21), (6, 24), (82, 24), (86, 22), (86, 14)], fill=C("8c8c8c"), width=1)
    d.line([(6, 23), (82, 23)], fill=C("a5a5a5"))
    return im if left else im.transpose(Image.FLIP_LEFT_RIGHT)

# ---- icons ------------------------------------------------------------------------------------
STAR = ["......#......", "......#......", ".....###.....", ".....###.....", "#############", ".###########.", "..#########..",
        "...#######...", "...#######...", "..####.####..", "..###...###..", ".###.....###.", ".#.........#."]
def star(fill, lite, edge):
    im = Image.new("RGBA", (13, 13), (0, 0, 0, 0)); px = im.load()
    for y, row in enumerate(STAR):
        for x, ch in enumerate(row):
            if ch == "#": px[x, y] = fill if (x + y) % 5 else lite
    for y in range(13):
        for x in range(13):
            if px[x, y][3] == 0 and any(0 <= x + dx < 13 and 0 <= y + dy < 13 and px[x + dx, y + dy][3] and px[x + dx, y + dy] != edge
                                        for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1))):
                px[x, y] = edge
    return im

def check():
    im = Image.new("RGBA", (14, 14), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rectangle([0, 3, 11, 13], fill=C("ffffff"), outline=C("8c8c8c"))
    d.line([(2, 8), (5, 12), (13, 0)], fill=C("e0405a"), width=2)
    return im

# ---- segmented bars ---------------------------------------------------------------------------
SEG = ["ff0800", "ff0800", "ff3900", "ff4a00", "ff4a00", "ff7300", "ff9c00", "ff9c00", "ffbd00", "ffde00", "ffe700", "fff700",
       "ffff00", "ffff00", "ffff00", "ceff00", "ceff00", "94ff08", "94ff08", "6bff08", "6bff08", "6bff08", "6bff08", "6bff08", "6bff08"]
def seg_bar(on):
    im = Image.new("RGBA", (75, 8), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    for i, col in enumerate(SEG):
        c = C(col) if on else C("4f7c97")
        d.rectangle([i * 3, 0, i * 3 + 1, 7], fill=c)
    return im

# ---- popup ("USE <item>?") --------------------------------------------------------------------
def popup(w=164, h=74):
    m = Image.new("L", (w, h), 0); md = ImageDraw.Draw(m)
    md.rectangle([0, 0, w - 4, h - 4], fill=255)
    for (x, y) in ((0, 0), (w - 4, 0), (0, h - 4), (w - 4, h - 4)):
        md.point((x, y), fill=0); md.point((x + (1 if x == 0 else -1), y), fill=0); md.point((x, y + (1 if y == 0 else -1)), fill=0)
    mp = m.load()
    inside = lambda x, y: 0 <= x < w and 0 <= y < h and mp[x, y] > 0
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0)); px = im.load()
    for y in range(h):
        for x in range(w):
            if not inside(x, y) and any(inside(x - k, y - k) or inside(x - k, y) or inside(x, y - k) for k in (1, 2, 3)):
                px[x, y] = BLACK
    for y in range(h):
        for x in range(w):
            if not inside(x, y): continue
            c = BLUE
            if not inside(x, y - 1) or not inside(x - 1, y): c = HL1
            elif not inside(x, y - 2) or not inside(x - 2, y): c = HL2
            if not inside(x + 1, y) or not inside(x, y + 1): c = SH3
            elif not inside(x + 2, y) or not inside(x, y + 2): c = SH1
            px[x, y] = c
    return im

def round_btn(on=True):
    im = Image.new("RGBA", (17, 17), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.ellipse([2, 2, 16, 16], fill=BLACK)
    d.ellipse([0, 0, 14, 14], fill=C("8c8c8c"))
    d.ellipse([0, 0, 13, 13], fill=C("b5b5b5"))
    d.ellipse([2, 2, 12, 12], fill=C("cecece"))
    d.arc([0, 0, 13, 13], 200, 290, fill=C("ffffff"))
    return im

if __name__ == "__main__":
    save(popup(164, 80), "popup"); save(round_btn(), "round")
    save(starfield(), "bg")
    save(window(False), "win-plain"); save(window(True), "win-list")
    save(navbar(), "navbar")
    for dr in "lrud":
        save(arrow_btn(dr, True), f"arrow-{dr}-on"); save(arrow_btn(dr, False), f"arrow-{dr}-off")
    save(shoulder(True), "shoulder-l"); save(shoulder(False), "shoulder-r")
    save(star(C("ffe040"), C("ffffff"), C("a86000")), "star-gold")
    save(star(C("e0e0e8"), C("ffffff"), C("707078")), "star-silver")
    save(star(C("b07050"), C("e0a070"), C("503020")), "star-bronze")
    save(check(), "check")
    save(seg_bar(True), "seg-on"); save(seg_bar(False), "seg-off")
    print("ok")
