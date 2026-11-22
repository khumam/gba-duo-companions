#!/usr/bin/env python3
"""Draws the pack's art into assets/ui: the night-blue backdrop, cream outline frames with the game's chevron ends,
striped title / menu tabs, nav plates, 20 DSS cards (small and big), magic item icons, the moon emblem and
button glyphs. All original pixel art in the palette sampled from the game's pause menu (art/ref);
1 art px = 1 px, the CSS scales it (1ap = 2.168 px on the Thor).

    python3 art/ui.py      (layout.py also calls frame() / pill() for the sizes it uses)
"""
import math
import os
import random

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "ui")
os.makedirs(OUT, exist_ok=True)


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


CREAM = C("#efffef")
CREAM_DK = C("#9aa8c8")
NAVY = [C("#00087b"), C("#00006b"), C("#00005a"), C("#00004a"), C("#000039"), C("#000029"), C("#000018"), C("#000008"), C("#000000")]
TAB_HI, TAB, TAB_DK = C("#7384b5"), C("#4a5a9c"), C("#21318c")
RED_HI, RED, RED_DK = C("#f76b31"), C("#f73900"), C("#840800")
CLEAR = (0, 0, 0, 0)


def new(w, h, fill=CLEAR):
    return Image.new("RGBA", (w, h), fill)


def save(im, name):
    im.save(os.path.join(OUT, name))


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


# ---------------------------------------------------------------------------------------------
def background(w, h, name):
    # the pause menu's stepped night gradient: navy bands down to black, with faint stars
    rnd = random.Random(5)
    im = new(w, h)
    px = im.load()
    for y in range(h):
        band = min(len(NAVY) - 1, int(y / h * len(NAVY) * 1.15))
        for x in range(w):
            px[x, y] = NAVY[band]
    for _ in range(70):
        x, y = rnd.randrange(w), rnd.randrange(h)
        px[x, y] = lerp(px[x, y], CREAM, 0.35 if rnd.random() < 0.8 else 0.7)
    save(im, name)


def frame(w, h, name=None, cut=4, fill=None):
    # cream 1px outline, the top-right corner cut like the game's status windows; inside left clear (or filled)
    im = new(w, h)
    d = ImageDraw.Draw(im)
    pts = [(0, 0), (w - 1 - cut, 0), (w - 1, cut), (w - 1, h - 1), (0, h - 1)]
    if fill:
        d.polygon(pts, fill=fill)
    d.line(pts + [(0, 0)], fill=CREAM, width=1)
    save(im, name or f"fr-{w}x{h}.png")
    return im


def pill(w, h, name=None, left=True, fill=None):
    # the game's label pills: outline with a chevron on the right (and on the left unless it touches the edge)
    im = new(w, h)
    d = ImageDraw.Draw(im)
    m = h // 2
    c = min(m, 5)
    pts = [(c if left else 0, 0), (w - 1 - c, 0), (w - 1, m), (w - 1 - c, h - 1), (c if left else 0, h - 1)]
    if left:
        pts.append((0, m))
    if fill:
        d.polygon(pts, fill=fill)
    d.line(pts + [pts[0]], fill=CREAM, width=1)
    save(im, name or f"pl-{w}x{h}{'' if left else '-e'}.png")
    return im


def tab(w, h, name, top, mid, bot, stripes=True, chevron=True):
    # a striped tab: gradient fill, diagonal light stripes on the left third, cream edge, chevron end
    im = new(w, h)
    px = im.load()
    c = h // 2 if chevron else 0
    for y in range(h):
        t = y / max(1, h - 1)
        base = lerp(top, mid, t * 2) if t < 0.5 else lerp(mid, bot, (t - 0.5) * 2)
        right = w - 1 - (abs(y - (h - 1) / 2) * (c / max(1, (h - 1) / 2)) if chevron else 0)
        for x in range(w):
            if x > right:
                continue
            col = base
            if stripes and x < w * 0.38 and ((x + y) // 3) % 2 == 0:
                col = lerp(base, CREAM, 0.35 * (1 - x / (w * 0.38)))
            if y == 0 or y == h - 1 or x >= right - 0.9:
                col = CREAM
            px[x, y] = col
    save(im, name)


def nav_plate(w, h, name, side):
    im = new(w, h)
    d = ImageDraw.Draw(im)
    c = h // 2
    if side == "l":
        pts = [(c, 0), (w - 1, 0), (w - 1, h - 1), (c, h - 1), (0, c)]
    else:
        pts = [(0, 0), (w - 1 - c, 0), (w - 1, c), (w - 1 - c, h - 1), (0, h - 1)]
    d.polygon(pts, fill=NAVY[2])
    for y in range(1, h - 1):
        for x in range(w):
            if im.getpixel((x, y))[3]:
                im.putpixel((x, y), lerp(NAVY[0], NAVY[5], y / h))
    d.line(pts + [pts[0]], fill=CREAM, width=1)
    # red chevron arrow
    ah = h - 10
    for k in range(ah):
        dx = abs(k - (ah - 1) / 2)
        for j in range(3):
            x = int(6 + dx + j) if side == "l" else int(w - 7 - dx - j)
            im.putpixel((x, 5 + k), RED_HI if j == 0 else RED)
    save(im, name)


# ---------------------------------------------------------------------------------------------
# DSS cards: original designs, a symbol per planet god (action) and per beast (attribute)
CARD_COL = {
    0: ("#ff7a30", "#a01800"), 1: ("#9ad8ff", "#2050c0"), 2: ("#90e070", "#206020"), 3: ("#d8a060", "#603810"),
    4: ("#d0d0d8", "#585868"), 5: ("#d080f0", "#502078"), 6: ("#80f0d8", "#107060"), 7: ("#fff070", "#a07800"),
    8: ("#ffffff", "#a8a0c8"), 9: ("#6060a0", "#100828"),
    10: ("#80e8e0", "#106878"), 11: ("#ffb0d0", "#a03060"), 12: ("#ffd890", "#a06010"), 13: ("#ff7060", "#801010"),
    14: ("#e0e8ff", "#5060a0"), 15: ("#ffd040", "#c05000"), 16: ("#70a8ff", "#102878"), 17: ("#e8d0a0", "#806030"),
    18: ("#a0f0ff", "#2070a0"), 19: ("#b090e0", "#301050"),
}


def symbol(d, k, cx, cy, s, ink, hi):
    """Draw card k's emblem centred on (cx, cy) at size s (radius-ish) with ImageDraw primitives."""
    r = s
    if k == 0:   # Salamander: a flame
        d.polygon([(cx, cy - r), (cx + r * 0.7, cy + r * 0.2), (cx + r * 0.4, cy + r), (cx - r * 0.4, cy + r), (cx - r * 0.7, cy + r * 0.2)], fill=ink)
        d.polygon([(cx, cy - r * 0.3), (cx + r * 0.35, cy + r * 0.4), (cx, cy + r * 0.85), (cx - r * 0.35, cy + r * 0.4)], fill=hi)
    elif k == 1:  # Serpent: an ice crystal
        for a in range(3):
            t = a * math.pi / 3
            d.line([(cx - r * math.cos(t), cy - r * math.sin(t)), (cx + r * math.cos(t), cy + r * math.sin(t))], fill=ink, width=max(1, int(r / 4)))
        d.ellipse([cx - r * 0.25, cy - r * 0.25, cx + r * 0.25, cy + r * 0.25], fill=hi)
    elif k == 2:  # Mandragora: a leaf
        d.ellipse([cx - r * 0.5, cy - r, cx + r * 0.5, cy + r], fill=ink)
        d.line([(cx, cy - r), (cx, cy + r)], fill=hi, width=1)
    elif k == 3:  # Golem: a rock
        d.polygon([(cx - r, cy + r * 0.6), (cx - r * 0.6, cy - r * 0.5), (cx + r * 0.2, cy - r * 0.9), (cx + r, cy - r * 0.1), (cx + r * 0.7, cy + r * 0.8)], fill=ink)
        d.line([(cx - r * 0.3, cy - r * 0.2), (cx + r * 0.4, cy + r * 0.3)], fill=hi, width=1)
    elif k == 4:  # Cockatrice: a stone eye
        d.ellipse([cx - r, cy - r * 0.55, cx + r, cy + r * 0.55], fill=ink)
        d.ellipse([cx - r * 0.35, cy - r * 0.35, cx + r * 0.35, cy + r * 0.35], fill=hi)
    elif k == 5:  # Manticore: a poison drop
        d.polygon([(cx, cy - r), (cx + r * 0.7, cy + r * 0.3), (cx - r * 0.7, cy + r * 0.3)], fill=ink)
        d.ellipse([cx - r * 0.7, cy - r * 0.1, cx + r * 0.7, cy + r], fill=ink)
        d.ellipse([cx - r * 0.3, cy + r * 0.1, cx, cy + r * 0.4], fill=hi)
    elif k == 6:  # Griffin: a wing
        for i in range(4):
            d.line([(cx - r, cy + r * 0.6 - i * r * 0.45), (cx + r - i * r * 0.3, cy - r * 0.2 - i * r * 0.25)], fill=ink if i % 2 == 0 else hi, width=max(1, int(r / 4)))
    elif k == 7:  # Thunderbird: a bolt
        d.polygon([(cx + r * 0.2, cy - r), (cx - r * 0.6, cy + r * 0.1), (cx - r * 0.05, cy + r * 0.1), (cx - r * 0.3, cy + r), (cx + r * 0.6, cy - r * 0.15), (cx + r * 0.05, cy - r * 0.15)], fill=ink)
    elif k == 8:  # Unicorn: a horn and star
        d.polygon([(cx, cy - r), (cx + r * 0.3, cy + r), (cx - r * 0.3, cy + r)], fill=ink)
        for i in range(3):
            y = cy - r * 0.3 + i * r * 0.45
            d.line([(cx - r * 0.25, y), (cx + r * 0.25, y - r * 0.15)], fill=hi, width=1)
    elif k == 9:  # Black Dog: a dark moon
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ink)
        d.ellipse([cx - r * 0.4, cy - r * 1.05, cx + r * 1.2, cy + r * 0.6], fill=hi)
    elif k == 10:  # Mercury: winged circle
        d.ellipse([cx - r * 0.45, cy - r * 0.45, cx + r * 0.45, cy + r * 0.45], outline=ink, width=max(1, int(r / 5)))
        d.polygon([(cx - r * 0.5, cy), (cx - r, cy - r * 0.6), (cx - r * 0.7, cy)], fill=hi)
        d.polygon([(cx + r * 0.5, cy), (cx + r, cy - r * 0.6), (cx + r * 0.7, cy)], fill=hi)
    elif k == 11:  # Venus: circle and cross
        d.ellipse([cx - r * 0.55, cy - r, cx + r * 0.55, cy + r * 0.1], outline=ink, width=max(1, int(r / 5)))
        d.line([(cx, cy + r * 0.1), (cx, cy + r)], fill=ink, width=max(1, int(r / 5)))
        d.line([(cx - r * 0.4, cy + r * 0.55), (cx + r * 0.4, cy + r * 0.55)], fill=ink, width=max(1, int(r / 5)))
    elif k == 12:  # Jupiter: banded giant
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ink)
        for i in (-0.4, 0.05, 0.5):
            d.line([(cx - r * 0.9, cy + r * i), (cx + r * 0.9, cy + r * i)], fill=hi, width=max(1, int(r / 5)))
    elif k == 13:  # Mars: circle and arrow
        d.ellipse([cx - r * 0.7, cy - r * 0.3, cx + r * 0.3, cy + r * 0.7], outline=ink, width=max(1, int(r / 5)))
        d.line([(cx + r * 0.1, cy - r * 0.1), (cx + r * 0.8, cy - r * 0.8)], fill=ink, width=max(1, int(r / 5)))
        d.polygon([(cx + r * 0.9, cy - r * 0.9), (cx + r * 0.3, cy - r * 0.85), (cx + r * 0.85, cy - r * 0.3)], fill=ink)
    elif k == 14:  # Diana: crescent
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ink)
        d.ellipse([cx - r * 0.45, cy - r * 1.1, cx + r * 1.4, cy + r * 0.9], fill=hi)
    elif k == 15:  # Apollo: sun
        for i in range(8):
            t = i * math.pi / 4
            d.line([(cx, cy), (cx + r * math.cos(t), cy + r * math.sin(t))], fill=ink, width=max(1, int(r / 5)))
        d.ellipse([cx - r * 0.5, cy - r * 0.5, cx + r * 0.5, cy + r * 0.5], fill=hi)
    elif k == 16:  # Neptune: trident
        w = max(1, int(r / 5))
        d.line([(cx, cy - r), (cx, cy + r)], fill=ink, width=w)
        d.line([(cx - r * 0.6, cy - r * 0.2), (cx + r * 0.6, cy - r * 0.2)], fill=ink, width=w)
        d.line([(cx - r * 0.6, cy - r * 0.2), (cx - r * 0.6, cy - r)], fill=ink, width=w)
        d.line([(cx + r * 0.6, cy - r * 0.2), (cx + r * 0.6, cy - r)], fill=ink, width=w)
    elif k == 17:  # Saturn: ringed planet
        d.ellipse([cx - r * 0.6, cy - r * 0.6, cx + r * 0.6, cy + r * 0.6], fill=ink)
        d.ellipse([cx - r, cy - r * 0.25, cx + r, cy + r * 0.25], outline=hi, width=max(1, int(r / 6)))
    elif k == 18:  # Uranus: planet with a standing ring
        d.ellipse([cx - r * 0.6, cy - r * 0.6, cx + r * 0.6, cy + r * 0.6], fill=ink)
        d.ellipse([cx - r * 0.25, cy - r, cx + r * 0.25, cy + r], outline=hi, width=max(1, int(r / 6)))
    elif k == 19:  # Pluto: small world and orbit
        d.ellipse([cx - r, cy - r * 0.45, cx + r, cy + r * 0.45], outline=hi, width=1)
        d.ellipse([cx - r * 0.35, cy - r * 0.35, cx + r * 0.35, cy + r * 0.35], fill=ink)


def card(k, w, h, name):
    im = new(w, h)
    d = ImageDraw.Draw(im)
    if k is None:   # back: a moon crest on blue
        top, bot = C("#3040a0"), C("#101848")
    else:
        top, bot = C(CARD_COL[k][0]), C(CARD_COL[k][1])
    for y in range(h):
        d.line([(0, y), (w - 1, y)], fill=lerp(top, bot, y / max(1, h - 1)))
    d.rectangle([0, 0, w - 1, h - 1], outline=C("#d8d0b0"))
    if w > 20:
        d.rectangle([2, 2, w - 3, h - 3], outline=C("#806848"))
    cx, cy, s = (w - 1) / 2, (h - 1) / 2, min(w, h) * 0.32
    if k is None:
        d.ellipse([cx - s, cy - s, cx + s, cy + s], outline=CREAM, width=max(1, int(s / 6)))
        d.ellipse([cx - s * 0.45, cy - s * 0.45, cx + s * 0.45, cy + s * 0.45], fill=CREAM)
    else:
        ink = C("#201010") if k not in (9, 19) else C("#e0d0ff")
        hi = lerp(top, C("#ffffff"), 0.5)
        if k in (9, 14):
            hi = top
        symbol(d, k, cx, cy, s, ink, hi)
    save(im, name)


# ---------------------------------------------------------------------------------------------
# magic item icons (16 px), original
MAGIC = {
    0: ["................", "................", "......wwww......", ".....wbbbbw.....", ".....wbbbbw.....", ".....wbbbbw.....",
        ".....wbbbbw.....", ".....wbbbbww....", "..s..wbbbbbbw...", ".s...wbbbbbbbw..", "s....wbbbbbbbbw.", "..s..wwwwwwwwww.",
        "................", "................", "................", "................"],   # Dash Boots
    1: ["................", ".....cccc.......", "....cwwwwc......", "....cwccwc......", ".....cccc.......", "................",
        "......cccc......", ".....cwwwwc.....", ".....cwccwc.....", "......cccc......", "................", ".......cccc.....",
        "......cwwwwc....", "......cwccwc....", ".......cccc.....", "................"],   # Double (jumps)
    2: ["................", "................", "...........r....", "..........rr....", "..wwwwwwwwrrr...", "..wbbbbbbbbrrr..",
        "..wbbbbbbbbrrr..", "..wwwwwwwwrrr...", "..........rr....", "...........r....", "................", "................",
        "................", "................", "................", "................"],   # Tackle
    3: ["................", "................", "......wwww......", ".....wggggw.....", ".....wggggw.....", ".....wggggw.....",
        ".....wggggww....", ".....wgggggggw..", ".....wwwwwwwww..", "................", "...y........y...", "..y..........y..",
        "................", "................", "................", "................"],   # Kick Boots
    4: ["................", "................", ".....ssssss.....", "....s......s....", "...s........s...", "...s........s...",
        "...s........s...", "....s......s....", ".....ssssss.....", "......dddd......", ".....dddddd.....", ".....dddddd.....",
        "................", "................", "................", "................"],   # Heavy Ring
    5: ["................"] * 16,
    6: ["................", ".......y........", "......yyy.......", ".....y.y.y......", ".......y........", "....wwwwwww.....",
        "...wcccccccw....", "...wcccccccw....", "...wcccccccw....", "....wcccccw.....", ".....wwwww......", "................",
        "................", "................", "................", "................"],   # Cleansing
    7: ["................", "................", "..........w.....", "........wwww....", "......wwwww.....", "....wwwwww......",
        "..wwwwwww.......", "....wwwww.......", "......www.......", "................", "......rr........", ".....r..r.......",
        "................", "................", "................", "................"],   # Roc Wing
    8: ["................", "................", "....yyy.........", "...y...y........", "...y...y........", "....yyyyyyyyyy..",
        "............y...", "..........y.y...", "................", "................", "................", "................",
        "................", "................", "................", "................"],   # Last Key
}
MPAL = {"w": CREAM, "b": C("#6070c0"), "c": C("#80d0ff"), "r": RED_HI, "g": C("#60c060"), "y": C("#ffd040"), "s": C("#c8c8d8"), "d": C("#707088")}


def magic_icon(i, size, off, name):
    rows = MAGIC[i]
    im = new(16, 16)
    px = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != ".":
                c = MPAL[ch]
                if off:
                    g = int(sum(c[:3]) / 3 * 0.35)
                    c = (g, g, g + 30, 255)
                px[x, y] = c
    if size != 16:
        im = im.resize((size, size), Image.NEAREST)
    save(im, name)


def moon(w, h, name):
    # the status crest: a full moon ringed by a circle, bats across it
    im = new(w, h)
    d = ImageDraw.Draw(im)
    for y in range(h):
        d.line([(0, y), (w - 1, y)], fill=lerp(C("#300810"), C("#100008"), y / h))
    d.rectangle([0, 0, w - 1, h - 1], outline=CREAM)
    cx, cy, r = (w - 1) / 2, h * 0.45, min(w, h) * 0.32
    d.ellipse([cx - r - 4, cy - r - 4, cx + r + 4, cy + r + 4], outline=C("#d8c070"), width=1)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=C("#f8f0c8"))
    d.ellipse([cx - r * 0.5, cy - r * 0.2, cx - r * 0.1, cy + r * 0.2], fill=C("#e0d4a0"))
    d.ellipse([cx + r * 0.2, cy + r * 0.1, cx + r * 0.6, cy + r * 0.5], fill=C("#e0d4a0"))
    for bx, by in ((cx - r * 0.9, cy + r * 0.9), (cx + r * 0.7, cy - r * 0.9), (cx + r * 0.2, cy + r * 1.3)):
        d.polygon([(bx - 4, by), (bx - 1, by - 2), (bx, by), (bx + 1, by - 2), (bx + 4, by), (bx, by + 2)], fill=C("#100008"))
    save(im, name)


def key_glyph(letter, name):
    # the game's button glyph: a rounded cream box with the letter in navy
    glyph = {
        "A": ["..w..", ".w.w.", "w...w", "wwwww", "w...w"],
        "B": ["wwww.", "w...w", "wwww.", "w...w", "wwww."],
        "L": ["w....", "w....", "w....", "w....", "wwwww"],
        "R": ["wwww.", "w...w", "wwww.", "w..w.", "w...w"],
    }[letter]
    w = 13
    im = new(w, 9)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, w - 1, 8], radius=3, fill=NAVY[0], outline=CREAM)
    ox = (w - 5) // 2
    for y, r in enumerate(glyph):
        for x, ch in enumerate(r):
            if ch == "w":
                im.putpixel((ox + x, 2 + y), CREAM)
    save(im, name)


def pip(name, on):
    im = new(5, 5)
    d = ImageDraw.Draw(im)
    if on:
        d.polygon([(2, 0), (4, 2), (2, 4), (0, 2)], fill=RED_HI)
        im.putpixel((2, 1), C("#ffd0a0"))
    else:
        d.polygon([(2, 0), (4, 2), (2, 4), (0, 2)], outline=CREAM_DK)
    save(im, name)


if __name__ == "__main__":
    background(248, 216, "bg.png")
    tab(96, 14, "title.png", TAB_HI, TAB, TAB_DK)
    tab(64, 11, "menu.png", TAB_HI, TAB, TAB_DK)
    tab(64, 11, "menu-on.png", RED_HI, RED, RED_DK)
    tab(96, 24, "nav-mid.png", TAB_HI, TAB, TAB_DK, stripes=True, chevron=False)
    nav_plate(72, 24, "nav-l.png", "l")
    nav_plate(72, 24, "nav-r.png", "r")
    tab(40, 13, "btn.png", RED_HI, RED, RED_DK, stripes=False)
    tab(40, 13, "btn-off.png", C("#3a4270"), C("#262c50"), C("#151935"), stripes=False)
    for k in range(20):
        card(k, 11, 15, f"card-{k}.png")
        card(k, 40, 56, f"cardbig-{k}.png")
    card(None, 11, 15, "card-back.png")
    card(None, 40, 56, "cardbig-back.png")
    for i in MAGIC:
        magic_icon(i, 16, False, f"mg-{i}.png")
        magic_icon(i, 16, True, f"mg-{i}-off.png")
        magic_icon(i, 32, False, f"mgbig-{i}.png")
        magic_icon(i, 32, True, f"mgbig-{i}-off.png")
    moon(48, 56, "moon.png")
    for k in "ABLR":
        key_glyph(k, f"key-{k}.png")
    cell = new(4, 3, C("#2a40f0"))
    for x in range(4):
        cell.putpixel((x, 0), C("#8aa0ff"))
    save(cell, "cell.png")
    pip("pip.png", False)
    pip("pip-on.png", True)
    print("ok")
