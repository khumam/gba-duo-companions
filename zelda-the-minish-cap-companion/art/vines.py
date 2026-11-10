"""Pixel-art moss and hanging vines for the corners of the Minish Cap pack's screen.

Run: python3 art/vines.py   (needs Pillow)  ->  assets/ui/vine-tl.png, vine-tr.png, vine-bl.png, vine-br.png

Drawn on the same 2 dp grid as the stone (art/stone_ui.py), with the same moss greens, flat colours, a dark
outline and hard edges, then written 4x larger with nearest neighbour. No smoothing, no soft shadows.
Top corners: moss along the edge with a few thin vines hanging down. Bottom corners: moss mounds with
short vines climbing up the pillar.
"""
import random
from pathlib import Path
from PIL import Image

UI = Path(__file__).resolve().parent.parent / "assets" / "ui"
SCALE = 4
W, H = 48, 95            # art px (96 x 190 dp)


def hexc(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


OUTLINE = hexc("#1f3a14")
DARK = hexc("#3f6320")      # the stone's moss tones
MID = hexc("#5c8a2e")
LIGHT = hexc("#7fae3f")
BRIGHT = hexc("#a2cf5a")
STEM = hexc("#33501f")
STEM_LIT = hexc("#4e7a2a")


class Pix:
    def __init__(self):
        self.p = {}

    def set(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.p[(x, y)] = c

    def has(self, x, y):
        return (x, y) in self.p

    def outline(self):
        """A one-pixel dark outline round everything drawn so far (not over it)."""
        edge = []
        for (x, y) in list(self.p):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in self.p and 0 <= q[0] < W and 0 <= q[1] < H:
                    edge.append(q)
        for q in edge:
            self.p[q] = OUTLINE

    def save(self, name):
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        for (x, y), c in self.p.items():
            img.putpixel((x, y), (*c, 255))
        img.resize((W * SCALE, H * SCALE), Image.NEAREST).save(UI / name)


def leaf(px, x, y, dx, dy, rnd):
    """A 3-pixel leaf pointing (dx, dy): a dark base, a mid body and a lit tip."""
    px.set(x + dx, y + dy, DARK)
    px.set(x + 2 * dx, y + 2 * dy, MID)
    px.set(x + 2 * dx + dy, y + 2 * dy + dx, LIGHT)      # a little width at the end
    px.set(x + 3 * dx, y + 3 * dy, BRIGHT if rnd.random() < 0.6 else LIGHT)


def vine(px, x, y, length, rnd, direction=1, sway=0.35):
    """A thin vine walking downward (direction 1) or upward (-1), leaves left and right every few pixels."""
    side = 1
    for i in range(length):
        px.set(x, y, STEM_LIT if i % 4 == 1 else STEM)
        if i % 4 == 2 and i > 1:
            leaf(px, x, y, side, 0, rnd)
            side = -side
        if i % 7 == 5:                                   # a small leaf on the end of a short side shoot
            px.set(x + side, y, STEM)
            px.set(x + 2 * side, y, MID)
            px.set(x + 2 * side, y + direction, LIGHT)
        y += direction
        if rnd.random() < sway:
            x += rnd.choice((-1, 1))
    # a bud at the tip
    px.set(x, y, LIGHT)
    px.set(x, y + direction, BRIGHT)


def moss_blob(px, cx, cy, rx, ry, rnd, up=False):
    """A clump of moss in three greens, lighter toward the top-left like everything else, with a ragged edge."""
    cells = []
    for y in range(cy - ry - 1, cy + ry + 2):
        for x in range(cx - rx - 1, cx + rx + 2):
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d < 1.0 + rnd.uniform(-0.18, 0.12):
                cells.append((x, y, d))
    for x, y, d in cells:
        lit = ((cx - x) / rx + (cy - y) / ry) * 0.5          # + toward the top left
        tone = d * 0.7 - lit * 0.55 + rnd.uniform(-0.18, 0.18)
        c = BRIGHT if tone < -0.35 else LIGHT if tone < 0.05 else MID if tone < 0.5 else DARK
        px.set(x, y, c)
    # a few tufts sticking out of the top (or the bottom, hanging)
    step = -1 if up else 1
    for _ in range(max(2, rx // 2)):
        x = cx + rnd.randint(-rx, rx)
        y = cy + step * (ry - rnd.randint(0, 1))
        px.set(x, y + step, MID)
        if rnd.random() < 0.6:
            px.set(x, y + 2 * step, LIGHT)


def top_corner(mirror, seed):
    rnd = random.Random(seed)
    px = Pix()
    mx = (lambda x: W - 1 - x) if mirror else (lambda x: x)
    # a thin band of moss along the top edge
    for cx, cy, rx, ry in ((5, 0, 8, 3), (18, 0, 7, 3), (30, 0, 8, 3), (42, 0, 7, 3)):
        moss_blob(px, mx(cx), cy, rx, ry, rnd, up=False)
    px.outline()
    # seven long vines hang from it
    for x, length in ((3, 70), (10, 44), (17, 60), (24, 78), (31, 50), (38, 64), (45, 40)):
        vine(px, mx(x), 5, length, rnd, direction=1)
    return px


def bottom_corner(mirror, seed):
    rnd = random.Random(seed)
    px = Pix()
    mx = (lambda x: W - 1 - x) if mirror else (lambda x: x)
    # a low bank of moss along the bottom edge
    for cx, cy, rx, ry in ((6, H - 1, 9, 5), (20, H, 8, 4), (33, H - 1, 9, 5), (44, H, 7, 4)):
        moss_blob(px, mx(cx), cy, rx, ry, rnd, up=True)
    px.outline()
    # seven long vines climb the pillar
    for x, length in ((3, 62), (10, 40), (17, 54), (24, 70), (31, 46), (38, 66), (45, 36)):
        vine(px, mx(x), H - 7, length, rnd, direction=-1)
    return px


if __name__ == "__main__":
    UI.mkdir(parents=True, exist_ok=True)
    top_corner(False, 3).save("vine-tl.png")
    top_corner(True, 8).save("vine-tr.png")
    bottom_corner(False, 15).save("vine-bl.png")
    bottom_corner(True, 22).save("vine-br.png")
    print("ok")
