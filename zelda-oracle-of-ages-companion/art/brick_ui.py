"""Brick chrome for the Oracle of Ages pack: the pillars, wall, window rim, plates, round buttons and nav slabs.

Run: python3 art/brick_ui.py   (needs Pillow)  ->  assets/ui/brick-*.png

The drawing helpers (raised bevels, the round buttons, the slabs, the plates) are the Minish Cap pack's stone_ui.py,
reused with the Ages palette; the pillars, wall and rim are laid brick by brick. Same rules: a 2 dp art pixel written
4x larger with nearest neighbour, lit from the top left.
"""
import importlib.util
import random
from pathlib import Path

HERE = Path(__file__).resolve().parent
UI = HERE.parent / "assets" / "ui"
spec = importlib.util.spec_from_file_location("stone_ui", HERE.parent.parent / "zelda-the-minish-cap-companion" / "art" / "stone_ui.py")
su = importlib.util.module_from_spec(spec)
spec.loader.exec_module(su)
su.UI = UI
hexc, shade, Art = su.hexc, su.shade, su.Art

ROSE = hexc("#98596F")       # the pause screen's mauve brick
WALL = hexc("#452F48")
DARK = hexc("#251C27")


def courses(w, h, bw, bh, base, seed, tones=0.08):
    """Running-bond bricks: each one a flat tone with a light top/left edge and a dark bottom/right edge, mortar between."""
    rnd = random.Random(seed)
    a = Art(w, h, shade(base, -0.62))
    for r in range(h // bh):
        off = (bw // 2) if r % 2 else 0
        for c in range(-1, w // bw + 2):
            x0, y0 = c * bw + off, r * bh
            tone = shade(base, rnd.uniform(-tones, tones))
            for y in range(y0 + 1, y0 + bh):
                for x in range(x0 + 1, x0 + bw):
                    a.set(x % w, y, tone)
            for x in range(x0 + 1, x0 + bw):
                a.set(x % w, y0 + 1, shade(tone, 0.24))
                a.set(x % w, y0 + bh - 1, shade(tone, -0.26))
            for y in range(y0 + 1, y0 + bh):
                a.set((x0 + 1) % w, y, shade(tone, 0.14))
                a.set((x0 + bw - 1) % w, y, shade(tone, -0.18))
    for y in range(h):
        for x in range(w):
            q = rnd.random()
            if q < 0.045:
                a.set(x, y, shade(a.get(x, y), -0.14))
            elif q < 0.075:
                a.set(x, y, shade(a.get(x, y), 0.10))
    return a


def pillar(side, seed):
    a = courses(36, 24, 18, 6, shade(ROSE, -0.04), seed, tones=0.07)
    for y in range(a.h):                                   # a dark outer edge and a lit inner edge
        for dx, c in ((0, shade(DARK, 0.0)), (1, shade(ROSE, -0.5))):
            a.set(dx if side == "l" else a.w - 1 - dx, y, c)
        a.set(a.w - 1 if side == "l" else 0, y, shade(DARK, 0.0))
        a.set(a.w - 2 if side == "l" else 1, y, shade(ROSE, 0.30))
    return a


def rim_bar(side, length, seed):
    horizontal = side in ("t", "b")
    a = courses(length, 6, 12, 3, shade(ROSE, 0.10), seed, tones=0.06) if horizontal else None
    if not horizontal:
        t = courses(length, 6, 12, 3, shade(ROSE, 0.10), seed, tones=0.06)
        a = Art(6, length)
        for y in range(length):
            for x in range(6):
                a.set(x, y, t.get(y, x))
    for i in range(length):                                # outline outside, a lit edge inside
        for depth, col in ((0, DARK), (5, shade(DARK, 0.1))):
            x, y = {"t": (i, depth), "b": (i, 5 - depth), "l": (depth, i), "r": (5 - depth, i)}[side]
            a.set(x, y, col)
    return a


def rim_corner(corner, seed):
    a = courses(8, 8, 8, 4, shade(ROSE, 0.10), seed, tones=0.04)
    cx, cy = (0 if corner[1] == "l" else 7), (0 if corner[0] == "t" else 7)
    for y in range(8):
        for x in range(8):
            if abs(x - cx) + abs(y - cy) < 2:
                a.px[y][x] = None
    for y in range(8):
        for x in range(8):
            if a.get(x, y) is not None and (x in (0, 7) or y in (0, 7)):
                a.set(x, y, DARK)
    return a


def build():
    UI.mkdir(parents=True, exist_ok=True)
    pillar("l", 3).save("brick-pillar-l.png")
    pillar("r", 5).save("brick-pillar-r.png")
    courses(32, 32, 16, 8, WALL, 9, tones=0.05).save("brick-wall.png")
    for side, seed in (("t", 21), ("b", 22), ("l", 23), ("r", 24)):
        rim_bar(side, 24, seed).save(f"brick-rim-{side}.png")
    for corner, seed in (("tl", 31), ("tr", 32), ("bl", 33), ("br", 34)):
        rim_corner(corner, seed).save(f"brick-rim-{corner}.png")

    su.plate(28, 30, hexc("#B5832B"), 3, with_moss=False).save("brick-plate-gold.png")
    su.plate(28, 30, hexc("#C8587A"), 5, with_moss=False).save("brick-plate-pink.png")
    su.disc(26, hexc("#B07A8C"), 7).save("brick-disc.png")
    su.disc(26, hexc("#B07A8C"), 7, pressed=True).save("brick-disc-down.png")
    su.badge(14, 5).save("brick-badge.png")
    # the nav buttons stand upright on the pillars: lit from the top left like everything else, not just turned on their side
    for name, colour, seed in (("side", "#A8687E", 41), ("here", "#C8587A", 43), ("down", "#8C4F66", 41)):
        su.slab(34, 40, hexc(colour), random.Random(seed), flat_bottom=False, cracks=2).save(f"brick-vslab-{name}.png")
    su.plate(28, 30, hexc("#6A4A70"), 9, with_moss=False).save("brick-plate-dark.png")
    print("ok")


if __name__ == "__main__":
    build()
