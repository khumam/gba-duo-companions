#!/usr/bin/env python3
"""Draws the pack's art into assets/ui: windows, plaques, nav plates, soul orbs, the soul vortex, element and gear
icons and the bestiary book. All original pixel art in the palette sampled from the game's pause menu
(art/ref/*.png); 1 art px = 1 px, the CSS scales it (1ap = 2.168 px on the Thor).

    python3 art/ui.py            (layout.py calls window() for every window size it uses)
"""
import math
import os
import random

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "ui")
os.makedirs(OUT, exist_ok=True)


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# palette sampled from the pause screen
BG = C("#180000")
BG2 = C("#100000")
BAND = C("#5a0000")
BAND_HI = C("#840000")
BAND_LO = C("#3a0000")
SIL_HI = C("#f0f0e8")
SIL = C("#d6d6ce")
SIL_MID = C("#a5a5a5")
SIL_LO = C("#636373")
SIL_DK = C("#30303c")
BLUE_HI = C("#7b7bff")
BLUE = C("#4a10ff")
BLUE_MID = C("#3100e7")
BLUE_DK = C("#2910a5")
BLUE_DEEP = C("#140a5a")
WHITE = C("#ffffff")
CLEAR = (0, 0, 0, 0)


def new(w, h, fill=CLEAR):
    return Image.new("RGBA", (w, h), fill)


def save(im, name):
    im.save(os.path.join(OUT, name))


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


# ---------------------------------------------------------------------------------------------
# windows: the game's thin silver line with cut corners on a near-black fill, a tick on the lower left
def window(w, h, fill=C("#1c0204"), name=None):
    im = new(w, h)
    px = im.load()
    for y in range(h):
        for x in range(w):
            # cut 2px corners
            cx = min(x, w - 1 - x)
            cy = min(y, h - 1 - y)
            if cx + cy < 2:
                continue
            edge = cx == 0 or cy == 0 or cx + cy == 2
            inner = cx == 1 or cy == 1 or cx + cy == 3
            if edge:
                # light on top/left, a touch darker bottom/right: reads as a bevel
                px[x, y] = SIL if (y < h / 2 or x < 3) else SIL_MID
            elif inner:
                px[x, y] = C("#0a0000")
            else:
                t = y / max(1, h - 1)
                px[x, y] = lerp(fill, C("#120000"), t * 0.6)
    # the little notch the game draws on the lower-left of its windows
    for i in range(3):
        if 2 + i < h:
            px[2, h - 4 - i] = SIL_MID
    save(im, name or f"win-{w}x{h}.png")
    return im


# ---------------------------------------------------------------------------------------------
# blue plaque with a silver frame; `wing` adds the swept silver flourish to the right (title plaques)
def plaque(w, h, wing=0, name="plaque.png", dark=False):
    im = new(w + wing, h)
    px = im.load()
    top, bot = (BLUE, BLUE_DEEP) if not dark else (C("#2a1040"), C("#0c0418"))
    for y in range(h):
        for x in range(w):
            cx = min(x, w - 1 - x)
            cy = min(y, h - 1 - y)
            if cx + cy < 1:
                continue
            if cx == 0 or cy == 0:
                px[x, y] = SIL_HI if y < h // 2 else SIL_MID
            elif cx == 1 or cy == 1:
                px[x, y] = SIL_LO
            else:
                t = (y - 2) / max(1, h - 5)
                c = lerp(top, bot, t)
                # a soft highlight band across the upper third
                if y == 3:
                    c = lerp(c, BLUE_HI, 0.45)
                px[x, y] = c
    if wing:
        # a swept silver wing: three tapering feathers, lit from the top
        for f in range(3):
            y0 = 2 + f * (h - 4) // 3
            length = wing - f * (wing // 5)
            for x in range(length):
                t = x / max(1, length - 1)
                thick = max(1, int(round((1 - t) * ((h - 4) // 3 + 1))))
                yy = y0 + int(round(t * t * (f - 1) * 3))
                for k in range(thick):
                    y = yy + k
                    if 0 <= y < h:
                        c = SIL_HI if k == 0 else (SIL if k < thick - 1 else SIL_LO)
                        if x % 5 == 4 and k > 0:
                            c = SIL_LO
                        px[w + x, y] = c
        # tie the wing to the plaque with a stud
        for y in range(h // 2 - 2, h // 2 + 2):
            for x in range(w - 2, w + 2):
                if 0 <= x < w + wing:
                    px[x, y] = SIL_HI if y < h // 2 else SIL_MID
    save(im, name)
    return im


# ---------------------------------------------------------------------------------------------
# soul orbs: a glowing sphere with a hot core, in the four soul colours, lit and dim
ORB = {
    "red": (C("#ff3030"), C("#ff9a8a"), C("#8a0010")),
    "blue": (C("#4060ff"), C("#a8c0ff"), C("#18107a")),
    "yellow": (C("#ffc018"), C("#fff0a0"), C("#8a5000")),
    "grey": (C("#a8a8b8"), C("#f0f0f8"), C("#44445a")),
}


def orb(color, size=12, off=False, name=None):
    base, hot, dark = ORB[color]
    if off:
        base, hot, dark = lerp(base, C("#2a1010"), 0.7), lerp(hot, C("#3a2020"), 0.7), lerp(dark, C("#100000"), 0.6)
    im = new(size, size)
    px = im.load()
    r = size / 2 - 0.5
    cx = cy = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy)
            if d > r + 0.35:
                continue
            # light from the upper left
            lx, ly = x - (cx - r * 0.35), y - (cy - r * 0.35)
            l = math.hypot(lx, ly) / (r * 1.6)
            c = lerp(hot, base, min(1, l * 1.4))
            if l > 0.75:
                c = lerp(base, dark, min(1, (l - 0.75) * 3))
            if d > r - 0.6:
                c = lerp(c, dark, 0.55)
            px[x, y] = c
    if not off:
        # the white glint
        gx, gy = int(cx - r * 0.35), int(cy - r * 0.35)
        px[gx, gy] = WHITE
    save(im, name or f"orb-{color}{'-off' if off else ''}.png")
    return im


def orb_none(size=12):
    im = new(size, size)
    px = im.load()
    r = size / 2 - 0.5
    c0 = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c0, y - c0)
            if r - 1.0 < d <= r + 0.3 and (x + y) % 2 == 0:
                px[x, y] = SIL_LO
    save(im, "orb-none.png")


# a big glowing orb with a halo for the hero spots
def orb_big(color, size=28, name=None):
    base, hot, dark = ORB[color]
    im = new(size, size)
    px = im.load()
    c0 = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c0, y - c0)
            if d < size * 0.26:
                l = math.hypot(x - (c0 - 2), y - (c0 - 2)) / (size * 0.3)
                px[x, y] = lerp(hot, base, min(1, l * 1.3))
            elif d < size / 2:
                a = int(200 * (1 - (d - size * 0.26) / (size / 2 - size * 0.26)) ** 2)
                if a > 8:
                    px[x, y] = base[:3] + (a,)
    px[int(c0 - 2), int(c0 - 2)] = WHITE
    save(im, name or f"orbbig-{color}.png")


# ---------------------------------------------------------------------------------------------
# the soul vortex: a deep blue swirl with motes; stands in for the game's portrait
def vortex(w, h, name, seed=7):
    rnd = random.Random(seed)
    im = new(w, h)
    px = im.load()
    cx, cy = (w - 1) / 2, (h - 1) / 2
    for y in range(h):
        for x in range(w):
            dx, dy = (x - cx) / (w / 2), (y - cy) / (h / 2)
            d = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            s = math.sin(a * 3 + d * 9.0)
            t = 0.5 + 0.5 * s
            c = lerp(BLUE_DEEP, BLUE_MID, t * (1.15 - min(1, d)))
            if s > 0.86 and d < 1.0:
                c = lerp(c, BLUE_HI, 0.55)
            px[x, y] = c
    for _ in range(int(w * h / 70)):
        x, y = rnd.randrange(w), rnd.randrange(h)
        px[x, y] = lerp(px[x, y], WHITE, 0.6)
    # frame: silver line with cut corners
    for y in range(h):
        for x in range(w):
            cxx, cyy = min(x, w - 1 - x), min(y, h - 1 - y)
            if cxx + cyy < 2:
                px[x, y] = CLEAR
            elif cxx == 0 or cyy == 0 or cxx + cyy == 2:
                px[x, y] = SIL if y < h / 2 else SIL_MID
    save(im, name)


# ---------------------------------------------------------------------------------------------
# nav plates: dark silver-framed plate; the arrow is a soul orb with a point
def nav_plate(w, h, name, side):
    im = new(w, h)
    px = im.load()
    for y in range(h):
        for x in range(w):
            cx, cy = min(x, w - 1 - x), min(y, h - 1 - y)
            if cx + cy < 3:
                continue
            if cx == 0 or cy == 0 or cx + cy == 3:
                px[x, y] = SIL_HI if y < h / 2 else SIL_MID
            elif cx == 1 or cy == 1 or cx + cy == 4:
                px[x, y] = SIL_DK
            else:
                t = (y - 2) / max(1, h - 4)
                px[x, y] = lerp(C("#4a0008"), C("#1a0002"), t)
                if y == 3:
                    px[x, y] = lerp(px[x, y], C("#b02030"), 0.5)
    # arrow: a red point pointing out of the plate
    ah = h - 10
    for k in range(ah // 2 + 1):
        for j in range(ah - 2 * k):
            y = 5 + k + j
            x = (6 + (ah // 2 - k)) if side == "l" else (w - 7 - (ah // 2 - k))
            if 0 <= y < h:
                px[x, y] = C("#ff5040") if j < (ah - 2 * k) // 2 else C("#c01828")
    save(im, name)


def pips(n, name):
    # page pips under the middle plaque; drawn as small orbs by CSS, this is the empty socket
    im = new(5, 5)
    px = im.load()
    for y in range(5):
        for x in range(5):
            if 1 <= x <= 3 and 1 <= y <= 3 and not (x in (1, 3) and y in (1, 3)):
                px[x, y] = SIL_LO
            elif (x, y) in ((2, 0), (0, 2), (4, 2), (2, 4)):
                px[x, y] = SIL_DK
    save(im, name)


# ---------------------------------------------------------------------------------------------
# icons from character rows: '.' clear, letters from a small palette
def sprite(rows, pal, name):
    h, w = len(rows), max(len(r) for r in rows)
    im = new(w, h)
    px = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != "." and ch != " ":
                px[x, y] = pal[ch]
    save(im, name)


IP = {  # icon palette
    "w": WHITE, "s": SIL, "m": SIL_MID, "d": SIL_LO, "k": C("#141018"),
    "g": C("#ffd860"), "o": C("#d89020"), "b": C("#8a5010"),
    "r": C("#ff4838"), "R": C("#a01820"), "p": C("#ff9aa0"),
    "c": C("#80d8ff"), "C": C("#2878d8"), "n": C("#183888"),
    "v": C("#c080ff"), "V": C("#6020a0"),
    "e": C("#70e070"), "E": C("#208030"),
    "t": C("#c89868"), "T": C("#805030"), "y": C("#fff0a0"),
}

ICONS = {
    "sword": [
        "..........ws",
        ".........wsm",
        "........wsm.",
        ".......wsm..",
        "......wsm...",
        ".....wsm....",
        "..o.wsm.....",
        "..oosm......",
        "...oo.......",
        "..bo.o......",
        ".bb...o.....",
        ".b..........",
    ],
    "greatsword": [
        ".........wss",
        "........wssm",
        ".......wssm.",
        "......wssm..",
        ".....wssm...",
        "....wssm....",
        ".o.wssm.....",
        ".oowsm......",
        "..ooo.......",
        ".bb.oo......",
        "bb...o......",
        "b...........",
    ],
    "katana": [
        "...........w",
        "..........ws",
        ".........wsm",
        "........wsm.",
        ".......wsm..",
        "......wsm...",
        ".....wsm....",
        "...g.sm.....",
        "....gg......",
        "...kk.g.....",
        "..kk........",
        ".kk.........",
    ],
    "hammer": [
        "......msss..",
        ".....mssssd.",
        "......mssd..",
        ".......sd...",
        "......bt....",
        ".....bt.....",
        "....bt......",
        "...bt.......",
        "..bt........",
        ".bt.........",
        "bt..........",
        "b...........",
    ],
    "axe": [
        "......wss...",
        ".....wsssm..",
        "....wsssmm..",
        "....wssbmd..",
        ".....mbtd...",
        "....bt......",
        "...bt.......",
        "..bt........",
        ".bt.........",
        "bt..........",
        "b...........",
        "............",
    ],
    "spear": [
        "..........w.",
        ".........wsw",
        "........wsm.",
        ".......osm..",
        "......oo....",
        ".....bt.....",
        "....bt......",
        "...bt.......",
        "..bt........",
        ".bt.........",
        "bt..........",
        "b...........",
    ],
    "fist": [
        "............",
        "...ss.ss....",
        "..swsswss...",
        "..smmsmms.s.",
        ".ssmmsmmssws",
        ".swwwwwwwsms",
        ".smmmmmmmms.",
        ".smmmmmmmms.",
        "..smmmmmmd..",
        "...dddddd...",
        "....tttt....",
        "....TTTT....",
    ],
    "gun": [
        "............",
        "............",
        ".wssssssssw.",
        ".smmmmmmmmsk",
        ".dddddmdddd.",
        "....kkm.....",
        "...kTTk.....",
        "...kTTk.....",
        "..kTTk......",
        "..kTTk......",
        "..kkk.......",
        "............",
    ],
    "armor": [
        "..ss....ss..",
        ".swms..smws.",
        ".smmsssmmms.",
        "..smmwwmms..",
        "..smmmmmms..",
        "..smmRRmms..",
        "..smRrrRms..",
        "..smmRRmms..",
        "..smmmmmms..",
        "...smmmms...",
        "...dssssd...",
        "............",
    ],
    "cloak": [
        "....gggg....",
        "...RgrrgR...",
        "..RRrrrrRR..",
        "..RrrrrrrR..",
        ".RRrrrrrrRR.",
        ".RrrrRRrrrR.",
        ".RrrRkkRrrR.",
        "RRrrRkkRrrRR",
        "RrrRkkkkRrrR",
        "RrRkkkkkkRrR",
        "RRkkkkkkkkRR",
        "............",
    ],
    "ring": [
        "....cCc.....",
        "...cwcCn....",
        "....CnC.....",
        "...g...g....",
        "..g.....g...",
        ".g.......o..",
        ".g.......o..",
        ".g.......o..",
        "..o.....o...",
        "...o...o....",
        "....ooo.....",
        "............",
    ],
    "charm": [
        "....ssss....",
        "...s....s...",
        "..s......s..",
        "..s......s..",
        "...s....s...",
        "....sggs....",
        "...gyyyyg...",
        "..gyrrrryo..",
        "..gyrrrryo..",
        "...gyrryo...",
        "....gyyo....",
        ".....oo.....",
    ],
    "potion": [
        "....kkkk....",
        "....tTTt....",
        ".....ww.....",
        ".....sw.....",
        "....swws....",
        "...swpppw...",
        "..swrrrrrs..",
        "..sprrrrRs..",
        "..srrrrrRs..",
        "..srrrrRRs..",
        "...sRRRRs...",
        "....ssss....",
    ],
    "mana": [
        "....kkkk....",
        "....tTTt....",
        ".....ww.....",
        ".....sw.....",
        "....swws....",
        "...swcccw...",
        "..swCCCCCs..",
        "..scCCCCns..",
        "..sCCCCCns..",
        "..sCCCCnns..",
        "...snnnns...",
        "....ssss....",
    ],
    "food": [
        "............",
        "......ppp...",
        ".....prrRp..",
        "....prrrrR..",
        "...prrrRrR..",
        "..prrrrrR...",
        ".wprrrRR....",
        "wwwRRR......",
        ".ww.........",
        "ww..........",
        "w...........",
        "............",
    ],
    "key": [
        "............",
        "...gggg.....",
        "..g.yy.g....",
        "..gy..yo....",
        "..gy..yo....",
        "...goob.....",
        "....go......",
        "....go......",
        "....gogg....",
        "....go......",
        "....gogo....",
        ".....b......",
    ],
    "none": [
        "............",
        "............",
        "............",
        "............",
        "............",
        "....dddd....",
        "............",
        "............",
        "............",
        "............",
        "............",
        "............",
    ],
}

# element icons (8x8), read like the bestiary's tolerance / weakness rows
ELEM = {
    "slash": [
        ".......w",
        "......ws",
        ".....wsm",
        "....wsm.",
        "o..wsm..",
        ".oosm...",
        ".bo.....",
        "b..o....",
    ],
    "fire": [
        "...r....",
        "...rr...",
        "..rrr.r.",
        ".rrgrrr.",
        ".rgygrr.",
        "rrgyygrr",
        ".rgyyg r",
        "..rrrr..",
    ],
    "water": [
        "...c....",
        "...c....",
        "..cCc...",
        "..cwC...",
        ".cwCCn..",
        ".cCCCn..",
        ".cCCnn..",
        "..nnn...",
    ],
    "thunder": [
        "....gg..",
        "...gy...",
        "..gy....",
        ".gyyyg..",
        "...gy...",
        "..gy....",
        ".gy.....",
        ".g......",
    ],
    "dark": [
        "...V....",
        ".V.V.V..",
        "..VkV...",
        "VVkkkVV.",
        "..VkV...",
        ".V.V.V..",
        "...V....",
        "........",
    ],
    "holy": [
        "...y....",
        ".y.y.y..",
        "..ywy...",
        "yywwwyy.",
        "..ywy...",
        ".y.y.y..",
        "...y....",
        "........",
    ],
    "poison": [
        "..eeee..",
        ".eEeeEe.",
        ".eEeeEe.",
        "..eeee..",
        "...ee...",
        "..e..e..",
        ".e.ee.e.",
        "........",
    ],
    "curse": [
        "..vvvv..",
        ".vwvvwv.",
        ".vkvvkv.",
        ".vvvvvv.",
        "..vVVv..",
        "..v.v.v.",
        "........",
        "........",
    ],
    "stone": [
        "........",
        "..dmmd..",
        ".dmssmd.",
        "dmswsmmd",
        "dmssmmmd",
        ".dmmmmd.",
        "..dddd..",
        "........",
    ],
}


# ---------------------------------------------------------------------------------------------
# the bestiary book: parchment with a leather edge and a stitched border
def book(w, h, name):
    rnd = random.Random(3)
    im = new(w, h)
    px = im.load()
    paper, paper_dk, ink = C("#f0dcc0"), C("#d8bc98"), C("#a07858")
    for y in range(h):
        for x in range(w):
            cx, cy = min(x, w - 1 - x), min(y, h - 1 - y)
            if cx + cy < 3:
                continue
            if cx <= 1 or cy <= 1 or cx + cy <= 4:
                px[x, y] = C("#5a3018") if (cx == 0 or cy == 0 or cx + cy == 3) else C("#8a5028")
                continue
            n = rnd.random()
            c = lerp(paper, paper_dk, 0.35 * n + 0.25 * (abs(x - w / 2) / (w / 2)) ** 3)
            if cx < 8 or cy < 8:
                c = lerp(c, paper_dk, 0.5)
            px[x, y] = c
    # stitched inner border
    for x in range(6, w - 6):
        if x % 3:
            px[x, 5] = ink
            px[x, h - 6] = ink
    for y in range(6, h - 6):
        if y % 3:
            px[5, y] = ink
            px[w - 6, y] = ink
    # page curl at the bottom right
    for k in range(6):
        for j in range(6 - k):
            px[w - 3 - k - j, h - 3 - k] = C("#c0a080")
    save(im, name)


def book_frame(w, h, name):
    # the dark plate behind an enemy entry's soul
    im = new(w, h)
    px = im.load()
    for y in range(h):
        for x in range(w):
            if x in (0, w - 1) or y in (0, h - 1):
                px[x, y] = WHITE
            elif x in (1, w - 2) or y in (1, h - 2):
                px[x, y] = C("#c0a080")
            else:
                t = y / h
                px[x, y] = lerp(C("#101040"), C("#04041a"), t)
    save(im, name)


def background(w, h, name):
    rnd = random.Random(11)
    im = new(w, h)
    px = im.load()
    for y in range(h):
        for x in range(w):
            t = y / h
            c = lerp(C("#200406"), C("#0c0000"), t)
            # faint gothic arches in the dark, like stone behind the menu
            ax = x % 62
            arch = abs(math.hypot(ax - 31, (y % 90) - 40) - 26) < 0.6 and (y % 90) < 40
            col = ax in (4, 58) and (y % 90) >= 40
            if arch or col:
                c = lerp(c, C("#3a1012"), 0.6)
            if rnd.random() < 0.015:
                c = lerp(c, C("#401418"), 0.5)
            px[x, y] = c
    save(im, name)


def exp_band(w, h, name):
    # the slanted blue EXP band from the pause screen
    im = new(w, h)
    px = im.load()
    for y in range(h):
        for x in range(w):
            if x < (h - 1 - y):
                continue
            t = x / w
            c = lerp(BLUE_DK, BLUE_MID, min(1, t * 1.6))
            if y == 0:
                c = lerp(c, BLUE_HI, 0.6)
            if y == h - 1:
                c = lerp(c, C("#0a0040"), 0.5)
            px[x, y] = c
    save(im, name)


def cursor(name):
    # a silver arrowhead pointing at the row, like the game's cursor
    rows = [
        "ss........",
        "swss......",
        "swwwss....",
        "swwwmmss..",
        "swwmmmmmd.",
        "smmmmddd..",
        "smmdd.....",
        "sdd.......",
    ]
    sprite(rows, {"s": SIL_LO, "w": WHITE, "m": SIL, "d": SIL_MID}, name)


def key_glyph(letter, name):
    # round white button with the letter, 9x9
    glyph = {
        "A": ["..w..", ".w.w.", "w...w", "wwwww", "w...w"],
        "B": ["wwww.", "w...w", "wwww.", "w...w", "wwww."],
        "L": ["w....", "w....", "w....", "w....", "wwwww"],
        "R": ["wwww.", "w...w", "wwww.", "w..w.", "w...w"],
    }[letter]
    im = new(9, 9)
    px = im.load()
    for y in range(9):
        for x in range(9):
            d = math.hypot(x - 4, y - 4)
            if d <= 4.3:
                px[x, y] = SIL_HI if d < 3.6 else SIL_MID
    for y, r in enumerate(glyph):
        for x, ch in enumerate(r):
            if ch == "w":
                px[2 + x, 2 + y] = C("#180000")
    save(im, name)


if __name__ == "__main__":
    background(248, 216, "bg.png")
    plaque(92, 15, wing=30, name="title.png")
    plaque(96, 24, name="nav-mid.png")
    nav_plate(72, 24, "nav-l.png", "l")
    nav_plate(72, 24, "nav-r.png", "r")
    plaque(40, 13, name="btn.png")
    plaque(40, 13, name="btn-off.png", dark=True)
    pips(7, "pip.png")
    for c in ORB:
        orb(c)
        orb(c, off=True)
        orb_big(c)
    orb_none()
    for c in ORB:
        orb(c, size=7, name=f"orbs-{c}.png")
        orb(c, size=7, off=True, name=f"orbs-{c}-off.png")
    vortex(52, 52, "vortex.png")
    vortex(40, 40, "vortex-s.png", seed=3)
    for k, rows in ICONS.items():
        sprite(rows, IP, f"ic-{k}.png")
    for k, rows in ELEM.items():
        sprite(rows, IP, f"el-{k}.png")
    book(240, 180, "book.png")
    book_frame(60, 52, "book-frame.png")
    exp_band(182, 18, "exp.png")
    cursor("cursor.png")
    for k in "ABLR":
        key_glyph(k, f"key-{k}.png")
    print("ok")
