#!/usr/bin/env python3
"""Draws the three page pictures (248 x 216 art pixels, shown at 5 device px per art px) in the look of the game's
pause windows: brown grid, chamfered peach frames, metal name plates, black slots joined by connector lines, the
green MAIN tab and the angled L / R page tabs. Zero's portrait is cut from art/old/status.png (Capcom graphic).
Live text/gauges are laid over these by style.src.css."""
from PIL import Image, ImageDraw

W, H = 248, 216
BG, GRID = (22, 12, 11), (55, 34, 29)
PL, P, PD, PDD = (241, 204, 173), (232, 168, 131), (141, 95, 78), (92, 62, 51)
BLACK, METAL, METAL_D, NAVY = (0, 0, 0), (161, 168, 169), (121, 121, 119), (32, 37, 54)
GREEN, GREEN_D, GREEN_L = (92, 196, 84), (45, 107, 44), (150, 232, 140)


def poly(d, x0, y0, x1, y1, cut, fill):
    """Rectangle (x1, y1 exclusive) with chamfered corners; cut = (tl, tr, br, bl) sizes."""
    tl, tr, br, bl = cut
    pts = [(x0 + tl, y0), (x1 - tr, y0), (x1, y0 + tr), (x1, y1 - br), (x1 - br, y1), (x0 + bl, y1), (x0, y1 - bl), (x0, y0 + tl)]
    d.polygon([(a, b) if False else (a - (1 if a == x1 else 0), b - (1 if b == y1 else 0)) for a, b in pts], fill=fill)


def panel(d, x0, y0, x1, y1, cut=(0, 0, 0, 0), inner=BLACK, rims=(PDD, P, PD)):
    """Peach window: dark outline, light peach body, brown inner rim, then `inner`."""
    c = cut
    poly(d, x0, y0, x1, y1, c, rims[0])
    poly(d, x0 + 1, y0 + 1, x1 - 1, y1 - 1, tuple(max(v - 1, 0) for v in c), PL)
    poly(d, x0 + 2, y0 + 2, x1 - 2, y1 - 2, tuple(max(v - 2, 0) for v in c), rims[2])
    poly(d, x0 + 3, y0 + 3, x1 - 3, y1 - 3, tuple(max(v - 3, 0) for v in c), inner)


def slot(d, x0, y0, x1, y1):
    d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=PDD)
    d.rectangle([x0 + 1, y0 + 1, x1 - 2, y1 - 2], fill=PD)
    d.rectangle([x0 + 2, y0 + 2, x1 - 3, y1 - 3], fill=BLACK)
    for (a, b) in [(x0, y0), (x1 - 1, y0), (x0, y1 - 1), (x1 - 1, y1 - 1)]: d.point((a, b), fill=BG)


def plate(d, x0, y0, x1, y1, cut=(0, 0, 0, 0)):
    poly(d, x0, y0, x1, y1, cut, NAVY)
    poly(d, x0 + 1, y0 + 1, x1 - 1, y1 - 1, tuple(max(v - 1, 0) for v in cut), METAL)
    poly(d, x0 + 2, y0 + 2, x1 - 2, y1 - 2, tuple(max(v - 2, 0) for v in cut), METAL_D)
    poly(d, x0 + 3, y0 + 3, x1 - 3, y1 - 3, tuple(max(v - 3, 0) for v in cut), NAVY)


def tab(d, x0, y0, x1, y1, green=False, cut=3):
    c = (cut, cut, 0, 0)
    poly(d, x0, y0, x1, y1, c, GREEN_D if green else PDD)
    poly(d, x0 + 1, y0 + 1, x1 - 1, y1, tuple(max(v - 1, 0) for v in c), GREEN_L if green else PL)
    poly(d, x0 + 2, y0 + 2, x1 - 2, y1, tuple(max(v - 2, 0) for v in c), GREEN if green else P)


def line(d, x0, y0, x1, y1):
    d.rectangle([x0, y0, x1, y1], fill=PD)


def canvas():
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    for x in range(7, W, 8): d.line([(x, 0), (x, H)], fill=GRID)
    for y in range(7, H, 8): d.line([(0, y), (W, y)], fill=GRID)
    return im, d


def page_bar(d, active):
    """The game's bottom: L / R page tabs above a black message window."""
    for side in ("l", "r"):
        x0, x1 = (0, 94) if side == "l" else (154, W)
        c = (0, 8, 0, 0) if side == "l" else (8, 0, 0, 0)
        poly(d, x0, 166, x1, 184, c, PDD)
        poly(d, x0 + 1, 167, x1 - 1, 184, tuple(max(v - 1, 0) for v in c), PL)
        poly(d, x0 + 2, 168, x1 - 2, 184, tuple(max(v - 2, 0) for v in c), P)
        poly(d, x0 + 3, 172, x1 - 3, 184, tuple(max(v - 3, 0) for v in c), PD)
    panel(d, 0, 184, W, H, (0, 0, 0, 0), BLACK)


def life_window(d, y=44):
    tab(d, 6, y - 10, 44, y + 2)
    panel(d, 2, y, W - 2, y + 24, (3, 3, 3, 3))


def header_status(im, d):
    portrait = Image.open("art/old/status.png").convert("RGB").crop((0, 0, 52, 32))
    d.rectangle([0, 0, 59, 39], fill=NAVY); d.rectangle([1, 1, 58, 38], fill=METAL)
    d.rectangle([2, 2, 57, 37], fill=BLACK)
    im.paste(portrait, (4, 4))
    plate(d, 62, 2, 114, 15, (0, 3, 0, 0)); plate(d, 116, 2, 138, 15)
    plate(d, 62, 17, 138, 30, (0, 0, 0, 3))
    panel(d, 142, 0, W, 42, (0, 0, 0, 10), BLACK)


def status():
    im, d = canvas(); header_status(im, d)
    # the game's in-stage HUD, as a left column: Lv badge + recessed life gauge
    d.rectangle([4, 46, 37, 62], fill=METAL); d.rectangle([5, 47, 36, 61], fill=BLACK)
    d.rectangle([4, 64, 37, 164], fill=METAL_D); d.rectangle([5, 65, 36, 163], fill=METAL); d.rectangle([8, 67, 33, 161], fill=BLACK)
    # main weapon row: tab, icon box, name slot
    tab(d, 44, 49, 80, 61, green=True)
    slot(d, 84, 46, 108, 66); slot(d, 112, 48, 182, 64)
    # sub weapon slots
    for k in range(4): slot(d, 44, 76 + k * 20, 134, 92 + k * 20)
    line(d, 40, 70, 41, 160)
    panel(d, 140, 72, 246, 164, (3, 3, 3, 3))       # LIFE + THIS RUN readout
    page_bar(d, "status")
    return im


def elves():
    im, d = canvas()
    tab(d, 6, 0, 60, 16)
    panel(d, 2, 12, 120, 164, (3, 3, 3, 3), BLACK)
    for i in range(7): slot(d, 10, 20 + i * 20, 112, 36 + i * 20)
    tab(d, 128, 0, 184, 16, green=True)
    panel(d, 124, 12, W - 2, 164, (3, 3, 3, 3), BLACK)
    page_bar(d, "elves")
    return im


def option():
    im, d = canvas()
    for (x0, y0, x1, y1, title) in [(2, 14, 122, 92, 0), (126, 14, 246, 92, 0), (2, 106, 122, 164, 0), (126, 106, 246, 164, 0)]:
        tab(d, x0 + 4, y0 - 10, x0 + 52, y0 + 3)
        panel(d, x0, y0, x1, y1, (3, 3, 3, 3), BLACK)
    page_bar(d, "option")
    return im


for name, fn in (("status", status), ("elf", elves), ("option", option)):
    fn().save(f"assets/ui/{name}.png")
