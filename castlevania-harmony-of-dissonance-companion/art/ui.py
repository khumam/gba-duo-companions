#!/usr/bin/env python3
"""Draws the pack's art into assets/ui: the royal-blue backdrop, the green title tab, silver nav plates, the
Belmont crest, spell books, relic and item icons, button glyphs. Original pixel art in the palette sampled from the
game's pause menu (art/ref); item sprites shared with the Aria of Sorrow pack's art kit. 1 art px = 1 px.

    python3 art/ui.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "ui")
os.makedirs(OUT, exist_ok=True)
sys.path.insert(0, os.path.join(HERE, "..", "..", "castlevania-aria-of-sorrow-companion", "art"))
import ui as aos  # noqa: E402  (icon rows and palette)

aos.OUT = OUT


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


ROYAL, ROYAL2, ROYAL3, NIGHT = C("#0000b5"), C("#0000a5"), C("#00008c"), C("#000052")
GREEN, GREEN_HI, GREEN_DK = C("#008c00"), C("#00ad00"), C("#006300")
SILVER, WHITE, BLACK = C("#d6d6d6"), C("#ffffff"), C("#000000")
CLEAR = (0, 0, 0, 0)


def new(w, h, fill=CLEAR):
    return Image.new("RGBA", (w, h), fill)


def save(im, name):
    im.save(os.path.join(OUT, name))


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


def background(w, h, name):
    # the menu's royal blue with black bands top and bottom, as the game fades it
    im = new(w, h)
    px = im.load()
    for y in range(h):
        t = y / (h - 1)
        if t < 0.08:
            c = lerp(BLACK, ROYAL, t / 0.08)
        elif t > 0.9:
            c = lerp(ROYAL, NIGHT, (t - 0.9) / 0.1)
        else:
            c = ROYAL
        for x in range(w):
            px[x, y] = c
    save(im, name)


def green_tab(w, h, name):
    # the green title tab: two greens with a dither that fades out to the right, light top edge
    im = new(w, h)
    px = im.load()
    for y in range(h):
        for x in range(w):
            fade = x / w
            if fade > 0.72 and (x + y) % 2 == 0 and fade > 0.72 + 0.28 * ((y % 3) / 3):
                continue
            c = GREEN_HI if y < h // 2 else GREEN
            if y == 0:
                c = lerp(GREEN_HI, WHITE, 0.35)
            if y == h - 1:
                c = GREEN_DK
            px[x, y] = c
    save(im, name)


def plate(w, h, name, top, bot, border=SILVER, arrow=None):
    im = new(w, h)
    d = ImageDraw.Draw(im)
    for y in range(h):
        d.line([(0, y), (w - 1, y)], fill=lerp(top, bot, y / max(1, h - 1)))
    d.rectangle([0, 0, w - 1, h - 1], outline=border)
    d.line([(1, 1), (w - 2, 1)], fill=lerp(top, WHITE, 0.3))
    if arrow:
        cy = h // 2
        for k in range(6):
            for j in range(-k, k + 1):
                x = (6 + k) if arrow == "l" else (w - 7 - k)
                im.putpixel((x, cy + j), WHITE if abs(j) < k else SILVER)
    save(im, name)


def hand(name):
    # the pointing-hand cursor, white with a dark outline
    rows = [
        "...kkkkkk.....",
        "..kwwwwwwkkkk.",
        "kkwwwwwwwwwwwk",
        "kwwwwwwwkkkkk.",
        "kwwwwwwwk.....",
        "kwwwwwwk......",
        ".kkkkkk.......",
    ]
    aos.sprite(rows, {"k": C("#202040"), "w": WHITE}, name)


def crest(w, h, name):
    # stands in for Juste's portrait: a Belmont cross with a coiled whip on red, framed in silver
    im = new(w, h)
    d = ImageDraw.Draw(im)
    for y in range(h):
        d.line([(0, y), (w - 1, y)], fill=lerp(C("#802020"), C("#300808"), y / h))
    d.rectangle([0, 0, w - 1, h - 1], outline=SILVER)
    d.rectangle([1, 1, w - 2, h - 2], outline=C("#606060"))
    cx, cy = w // 2, h // 2 - 2
    gold, gold_dk = C("#f0d060"), C("#a07818")
    d.rectangle([cx - 2, cy - 16, cx + 2, cy + 18], fill=gold)
    d.rectangle([cx - 12, cy - 7, cx + 12, cy - 3], fill=gold)
    d.line([(cx + 2, cy - 16), (cx + 2, cy + 18)], fill=gold_dk)
    for t in range(0, 360, 12):
        a = math.radians(t)
        r = 13 + 3 * math.sin(a * 3)
        x, y = cx + r * math.cos(a), cy + 6 + r * 0.55 * math.sin(a)
        d.point((x, y), fill=C("#c89058"))
    save(im, name)


BOOK_COL = ["#e03020", "#40a0ff", "#f0d020", "#40c060", "#a060e0"]   # fire, ice, bolt, wind, summoning


def book(k, w, h, name):
    im = new(w, h)
    d = ImageDraw.Draw(im)
    if k is None:
        col, dk = C("#404868"), C("#202438")
    else:
        col = C(BOOK_COL[k])
        dk = lerp(col, BLACK, 0.5)
    d.rectangle([1, 0, w - 1, h - 1], fill=col)
    d.rectangle([0, 1, 2, h - 1], fill=dk)
    d.rectangle([1, 0, w - 1, h - 1], outline=dk)
    for y in range(2, h - 2, max(2, h // 8)):
        d.point((w - 2, y), fill=WHITE)
    cx, cy, r = (w + 2) / 2, h / 2, min(w, h) * 0.22
    if k is not None:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=WHITE)
        d.ellipse([cx - r * 0.4, cy - r * 0.4, cx + r * 0.4, cy + r * 0.4], fill=lerp(col, WHITE, 0.6))
    save(im, name)


RELIC = {   # 16x16 relic sprites
    0: "lizard", 1: "feather", 2: "wing", 3: "orb", 4: "journal", 5: "tome", 6: "eye", 7: "heart", 8: "rib", 9: "nail", 10: "fang", 11: "ring",
}


def relic(k, off, name):
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    a, b = (C("#f0d060"), C("#a07818"))
    if k == 0:
        d.line([(3, 12), (8, 8), (12, 9), (14, 5)], fill=C("#60c060"), width=2)
        d.point((14, 4), fill=WHITE)
    elif k == 1:
        d.line([(3, 13), (12, 3)], fill=WHITE)
        for i in range(4):
            d.line([(5 + i * 2, 11 - i * 2), (9 + i * 2, 12 - i * 2)], fill=C("#a0e0ff"))
    elif k == 2:
        d.polygon([(2, 10), (8, 3), (14, 4), (10, 8), (13, 11), (6, 12)], fill=C("#f0f0f0"), outline=C("#8080a0"))
    elif k == 3:
        d.ellipse([3, 3, 12, 12], fill=C("#8040e0"), outline=C("#d0b0ff"))
        d.point((5, 5), fill=WHITE)
    elif k in (4, 5):
        d.rectangle([3, 2, 12, 13], fill=C("#60a060") if k == 4 else C("#a04040"), outline=b)
        d.line([(5, 5), (10, 5)], fill=a)
        d.line([(5, 8), (10, 8)], fill=a)
    elif k == 6:
        d.ellipse([2, 5, 13, 10], fill=WHITE, outline=C("#802020"))
        d.ellipse([6, 5, 9, 10], fill=C("#c02020"))
    elif k == 7:
        d.polygon([(8, 13), (2, 6), (5, 3), (8, 5), (11, 3), (14, 6)], fill=C("#d02040"))
    elif k == 8:
        for i in range(4):
            d.arc([3, 2 + i * 3, 13, 8 + i * 3], 180, 360, fill=C("#e8e0c8"))
    elif k == 9:
        d.polygon([(7, 2), (10, 2), (9, 13), (8, 13)], fill=C("#e8e0c8"), outline=C("#908870"))
    elif k == 10:
        d.polygon([(4, 3), (12, 3), (8, 14)], fill=C("#f8f0e0"), outline=C("#908870"))
    elif k == 11:
        d.ellipse([3, 5, 12, 13], outline=a, width=2)
        d.polygon([(7, 1), (9, 1), (10, 4), (6, 4)], fill=C("#d02040"))
    if off:
        px = im.load()
        for y in range(16):
            for x in range(16):
                p = px[x, y]
                if p[3]:
                    g = int(sum(p[:3]) / 3 * 0.35)
                    px[x, y] = (g, g, g + 40, 255)
    save(im, name)


GOODS_ICON = {
    "goods": ["............", "............", "...yyyyyy...", "..y......y..", ".y..rrrr..y.", ".y.r....r.y.", ".y.r....r.y.", ".y..rrrr..y.", "..y......y..", "...yyyyyy...", "............", "............"],
    "head": ["............", "....ssss....", "...swwwws...", "..swwwwwws..", "..swmmmmws..", "..sm....ms..", "..sm....ms..", "..ss....ss..", "............", "............", "............", "............"],
    "hands": ["............", "..t.t.t.....", "..t.t.t.t...", "..tttttttt..", "..tttttttt..", "..tttttttt..", "...tttttt...", "...tttttt...", "...bbbbbb...", "............", "............", "............"],
    "feet": ["............", "....ttt.....", "....ttt.....", "....ttt.....", "....ttt.....", "....tttt....", "....ttttttt.", "....ttttttt.", "....bbbbbbb.", "............", "............", "............"],
    "back": ["....rrrr....", "...rrrrrr...", "..rrrrrrrr..", "..rrrrrrrr..", ".rrrrrrrrrr.", ".rrrrrrrrrr.", ".rrrrrrrrrr.", "rrrrrrrrrrrr", "rRrRrRrRrRrR", "............", "............", "............"],
    "arms": ["............", "............", "..ssssssss..", ".s........s.", "s..........s", "s..........s", ".s........s.", "..ssssssss..", "............", "............", "............", "............"],
    "neck": ["............", "s..........s", ".s........s.", "..s......s..", "...s....s...", "....s..s....", ".....cc.....", "....cwwc....", "....cccc....", ".....cc.....", "............", "............"],
    "finger": ["............", ".....cc.....", "....cwwc....", ".....cc.....", "....y..y....", "...y....y...", "...y....y...", "...y....y...", "....y..y....", ".....yy.....", "............", "............"],
    "cure": ["....kkkk....", "....tTTt....", ".....ww.....", ".....sw.....", "....swws....", "...sweeew...", "..sweeeees..", "..seeeeeEs..", "..seeeeeEs..", "..seeeeEEs..", "...sEEEEs...", "....ssss...."],
    "map": ["............", ".tttttttttt.", ".tyyyyyyyyt.", ".tyRyyyyyyt.", ".tyRRRyyyyt.", ".tyyyRyyyyt.", ".tyyyRRRyyt.", ".tyyyyyyRyt.", ".tyyyyyyyyt.", ".tttttttttt.", "............", "............"],
    "card": ["............", "..wwwwwwww..", "..wRRRRRRw..", "..wRwwwwRw..", "..wRwRRwRw..", "..wRwRRwRw..", "..wRwwwwRw..", "..wRRRRRRw..", "..wwwwwwww..", "............", "............", "............"],
    "jewel": ["............", "............", "...cccccc...", "..cwwccccc..", ".cccccccccc.", "..cccccccc..", "...cccccc...", "....cccc....", ".....cc.....", "............", "............", "............"],
    "whip": ["............", ".......ttt..", "......t...t.", "......t...t.", ".......t.t..", "........t...", ".......t....", "......b.....", ".....bb.....", "....bb......", "...bb.......", "............"],
}


if __name__ == "__main__":
    background(248, 216, "bg.png")
    green_tab(120, 14, "title.png")
    plate(72, 24, "nav-l.png", C("#2020d0"), C("#000070"), arrow="l")
    plate(72, 24, "nav-r.png", C("#2020d0"), C("#000070"), arrow="r")
    plate(96, 24, "nav-mid.png", GREEN_HI, GREEN_DK)
    plate(40, 13, "btn.png", GREEN_HI, GREEN_DK)
    plate(40, 13, "btn-off.png", C("#303878"), C("#181c40"))
    hand("hand.png")
    crest(48, 56, "crest.png")
    for k in range(5):
        book(k, 12, 16, f"book-{k}.png")
        book(k, 24, 32, f"bookbig-{k}.png")
    book(None, 12, 16, "book-none.png")
    book(None, 24, 32, "bookbig-none.png")
    for k in RELIC:
        relic(k, False, f"rl-{k}.png")
        relic(k, True, f"rl-{k}-off.png")
    pal = dict(aos.IP)
    pal.update({"c": C("#80d8ff"), "e": C("#70e070"), "E": C("#208030")})
    for k in ("potion", "mana", "food", "key", "armor", "none"):
        aos.sprite(aos.ICONS[k], pal, f"ic-{k}.png")
    for k, rows in GOODS_ICON.items():
        aos.sprite(rows, pal, f"ic-{k}.png")
    for k in "ABLR":
        aos.key_glyph(k, f"key-{k}.png")
    for on in (False, True):
        im = new(5, 5)
        d = ImageDraw.Draw(im)
        if on:
            d.ellipse([0, 0, 4, 4], fill=C("#40ff40"))
        else:
            d.ellipse([0, 0, 4, 4], outline=SILVER)
        save(im, "pip-on.png" if on else "pip.png")
    print("ok")
