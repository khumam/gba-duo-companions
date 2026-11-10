"""Old-stone chrome for the Minish Cap pack: pillars with carved triangles, plates, round
buttons, the three nav slabs, the brick frame and the mossy wall.

Run: python3 art/stone_ui.py   (needs Pillow)  ->  assets/ui/stone-*.png

Everything is drawn on a small grid (1 art pixel = 2 dp) and written 4x larger with nearest
neighbour, so edges stay crisp whatever the engine does when it scales. Lit from the top left:
raised things have a light top/left edge and a dark bottom/right edge, carvings the reverse.
"""
import math
import random
from pathlib import Path
from PIL import Image

UI = Path(__file__).resolve().parent.parent / "assets" / "ui"
SCALE = 4


def hexc(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shade(c, f):
    """f > 0 lightens toward white, f < 0 darkens toward black."""
    return mix(c, (255, 255, 255), f) if f > 0 else mix(c, (0, 0, 0), -f)


class Art:
    def __init__(self, w, h, bg=None):
        self.w, self.h = w, h
        self.px = [[bg for _ in range(w)] for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            self.px[y][x] = c

    def get(self, x, y):
        return self.px[y][x] if 0 <= x < self.w and 0 <= y < self.h else None

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def save(self, name, tile=False):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                c = self.px[y][x]
                if c is not None:
                    img.putpixel((x, y), (*c, 255))
        img = img.resize((self.w * SCALE, self.h * SCALE), Image.NEAREST)
        img.save(UI / name)


def speckle(art, base, rnd, amount=0.5, x0=0, y0=0, x1=None, y1=None, region=None):
    """Weathered grain: scattered light and dark pixels over what is already base-coloured."""
    x1 = art.w - 1 if x1 is None else x1
    y1 = art.h - 1 if y1 is None else y1
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if art.get(x, y) != base:
                continue
            r = rnd.random()
            if r < 0.07 * amount:
                art.set(x, y, shade(base, -0.13))
            elif r < 0.12 * amount:
                art.set(x, y, shade(base, 0.10))
            elif r < 0.135 * amount:
                art.set(x, y, shade(base, -0.24))


def crack(art, rnd, x, y, length, dark, light=None, bounds=None):
    """A wandering crack: a dark line with a light pixel under it."""
    dx, dy = rnd.choice([(1, 1), (-1, 1), (1, 0), (0, 1)])
    for _ in range(length):
        if bounds and not (bounds[0] <= x <= bounds[2] and bounds[1] <= y <= bounds[3]):
            break
        art.set(x, y, dark)
        if light:
            art.set(x + 1, y + 1, light) if art.get(x + 1, y + 1) not in (dark,) else None
        r = rnd.random()
        if r < 0.18:
            dx = rnd.choice([-1, 1])
        x += dx if rnd.random() < 0.7 else 0
        y += dy if rnd.random() < 0.85 else 0


def moss(art, rnd, x, y, w, h, colors):
    """A mossy patch: a blob of greens, darkest at the edge."""
    for yy in range(y - h, y + h + 1):
        for xx in range(x - w, x + w + 1):
            d = ((xx - x) / max(w, 1)) ** 2 + ((yy - y) / max(h, 1)) ** 2
            if d < 1.0 and rnd.random() < 0.9 - d * 0.5 and art.get(xx, yy) is not None:
                art.set(xx, yy, colors[0] if d < 0.45 else colors[1] if d < 0.8 else colors[2])


MOSS = [hexc("#7fae3f"), hexc("#5c8a2e"), hexc("#3f6320")]


# ---- slab: a bevelled stone block with chamfered corners --------------------------------

def slab(w, h, base, rnd, chamfer=3, inset=None, cracks=2, flat_bottom=False):
    a = Art(w, h)
    dark_edge = shade(base, -0.62)
    light = shade(base, 0.38)
    shadow = shade(base, -0.36)

    def inside(x, y):
        cut = chamfer
        if x + y < cut or (w - 1 - x) + y < cut:
            return False
        if not flat_bottom and (x + (h - 1 - y) < cut or (w - 1 - x) + (h - 1 - y) < cut):
            return False
        return True

    for y in range(h):
        for x in range(w):
            if inside(x, y):
                a.set(x, y, base)
    # outline
    for y in range(h):
        for x in range(w):
            if a.get(x, y) is None:
                continue
            if any(a.get(x + dx, y + dy) is None and not (flat_bottom and y + dy >= h)
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                a.set(x, y, dark_edge)
    # raised bevel: light top/left, dark bottom/right (2 px)
    for t in (1, 2):
        for x in range(w):
            for y, c in ((t, light if t == 1 else shade(light, -0.1)), (h - 1 - t, shadow if t == 1 else shade(shadow, -0.1))):
                if a.get(x, y) == base:
                    a.set(x, y, c)
        for y in range(h):
            for x, c in ((t, light if t == 1 else shade(light, -0.1)), (w - 1 - t, shadow if t == 1 else shade(shadow, -0.1))):
                if a.get(x, y) == base:
                    a.set(x, y, c)
    speckle(a, base, rnd, 1.0)
    for _ in range(cracks):
        crack(a, rnd, rnd.randint(5, w - 6), rnd.randint(4, h - 8), rnd.randint(5, 9), shade(base, -0.45), shade(base, 0.2), (4, 4, w - 5, h - 4))
    if inset:
        x0, y0, x1, y1 = inset
        for x in range(x0, x1 + 1):
            a.set(x, y0, shade(base, -0.4))
            a.set(x, y1, light)
        for y in range(y0, y1 + 1):
            a.set(x0, y, shade(base, -0.4))
            a.set(x1, y, light)
    return a


def plate(w, h, base, seed, with_moss=True):
    rnd = random.Random(seed)
    a = slab(w, h, base, rnd, chamfer=3, inset=(5, 5, w - 6, h - 6), cracks=2)
    # the inset's floor is a touch darker, like a recessed panel
    for y in range(6, h - 6):
        for x in range(6, w - 6):
            c = a.get(x, y)
            if c is not None:
                a.set(x, y, shade(c, -0.1))
    if with_moss:
        moss(a, rnd, 7, h - 2, 5, 2, MOSS)
        moss(a, rnd, w - 6, 3, 3, 2, MOSS)
    return a


# ---- round button: a raised (or pressed) stone disc ------------------------------------

def disc(d, base, seed, pressed=False):
    rnd = random.Random(seed)
    a = Art(d, d)
    c = (d - 1) / 2
    dark_edge = shade(base, -0.72)
    light = shade(base, 0.34)
    shadow = shade(base, -0.44)
    for y in range(d):
        for x in range(d):
            r = math.hypot(x - c, y - c)
            if r > c + 0.4:
                continue
            ang = math.atan2(y - c, x - c)          # -pi..pi, 0 = right, +pi/2 = down
            lit = math.cos(ang - math.radians(225))  # 1 toward the top left
            if lit < 0 and not pressed or lit > 0 and pressed:
                lit_side = -1
            else:
                lit_side = 1
            if r > c - 0.9:
                a.set(x, y, dark_edge)
            elif r > c - 3.0:                       # the rim
                a.set(x, y, light if lit_side > 0 else shadow)
            elif r > c - 4.0:                       # a groove between rim and face
                a.set(x, y, shade(base, -0.5))
            else:                                   # the face
                face = shade(base, -0.08 if pressed else 0.08)
                a.set(x, y, face)
    # face grain and a crack
    for y in range(d):
        for x in range(d):
            if math.hypot(x - c, y - c) < c - 4.0:
                col = a.get(x, y)
                r = rnd.random()
                if r < 0.08:
                    a.set(x, y, shade(col, -0.14))
                elif r < 0.13:
                    a.set(x, y, shade(col, 0.1))
    crack(a, rnd, int(c + 3), int(c - 6), 5, shade(base, -0.45), None, (4, 4, d - 5, d - 5))
    return a


# ---- pillar tile: a carved column, repeated down the screen ----------------------------

def triangle(a, x, y, w, h, pointing, base):
    """A carved triangle: the inside is darker, the top/left edges lie in shadow and the bottom/right edges catch light."""
    if pointing == "r":
        pts = [(x, y), (x, y + h - 1), (x + w - 1, y + (h - 1) / 2)]
    else:
        pts = [(x + w - 1, y), (x + w - 1, y + h - 1), (x, y + (h - 1) / 2)]

    def inside(px, py):
        def sign(p1, p2, p3):
            return (p1[0] - p3[0]) * (p2[1] - p3[1]) - (p2[0] - p3[0]) * (p1[1] - p3[1])
        d1, d2, d3 = sign((px, py), pts[0], pts[1]), sign((px, py), pts[1], pts[2]), sign((px, py), pts[2], pts[0])
        neg = d1 < 0 or d2 < 0 or d3 < 0
        pos = d1 > 0 or d2 > 0 or d3 > 0
        return not (neg and pos)

    floor = shade(base, -0.34)
    rim_dark = shade(base, -0.62)
    rim_light = shade(base, 0.42)
    cells = {(px, py) for py in range(y - 1, y + h + 1) for px in range(x - 1, x + w + 1) if inside(px, py)}
    for px, py in cells:
        a.set(px, py, floor)
    for px, py in cells:
        # an edge pixel has a neighbour outside the shape
        if (px - 1, py) not in cells or (px, py - 1) not in cells:
            a.set(px, py, rim_dark)
    # light catches the outside lower/right edge
    for px, py in cells:
        for dx, dy in ((1, 0), (0, 1), (1, 1)):
            q = (px + dx, py + dy)
            if q not in cells and a.get(*q) == base:
                a.set(*q, rim_light)


def pillar(side, seed=11):
    w, h = 44, 60                        # 88 x 120 dp: four triangles
    rnd = random.Random(seed)
    base = hexc("#a9a99a")
    a = Art(w, h, base)
    # vertical edges: outer hairline pair, thick inner edge with its shade
    outer = 0 if side == "l" else w - 1
    step = 1 if side == "l" else -1
    inner = w - 1 if side == "l" else 0
    istep = -1 if side == "l" else 1
    for y in range(h):
        a.set(outer, y, shade(base, -0.55))
        a.set(outer + step, y, shade(base, 0.3))
        a.set(outer + 3 * step, y, shade(base, -0.18))
        a.set(inner, y, shade(base, -0.62))
        a.set(inner + istep, y, shade(base, -0.5))
        a.set(inner + 2 * istep, y, shade(base, -0.28))
        a.set(inner + 3 * istep, y, shade(base, 0.28))
    speckle(a, base, rnd, 0.7, 5, 0, w - 6, h - 1)
    # carved triangles: right, left, right, left, 15 art px apart, centred in the column
    for i in range(4):
        y = i * 15
        if i % 2 == 0:
            triangle(a, 14, y + 1, 16, 13, "r", base)
        else:
            triangle(a, 14, y + 1, 16, 13, "l", base)
    # cracks that stay inside the tile, away from the carvings' centre
    # cracks only in the margins beside the carvings
    for sx, sy, ln in ((6, 3, 10), (37, 31, 10), (7, 44, 8)):
        crack(a, rnd, sx, sy, ln, shade(base, -0.5), shade(base, 0.22), (5, 1, 11, h - 2) if sx < 20 else (33, 1, w - 6, h - 2))
    moss(a, rnd, 7 if side == "l" else w - 8, 55, 4, 2, MOSS)
    return a


# ---- frame and wall tiles ----------------------------------------------------------------

def bricks(w, h, brick_w, brick_h, base, seed, tones=0.10):
    """Running-bond bricks, a dark mortar line round each."""
    rnd = random.Random(seed)
    a = Art(w, h, shade(base, -0.55))
    rows = h // brick_h
    for r in range(rows):
        off = (brick_w // 2) if r % 2 else 0
        for c in range(-1, w // brick_w + 2):
            x0 = c * brick_w + off
            y0 = r * brick_h
            tone = shade(base, rnd.uniform(-tones, tones))
            for y in range(y0 + 1, y0 + brick_h):
                for x in range(x0 + 1, x0 + brick_w):
                    xx = x % w
                    a.set(xx, y, tone)
            for x in range(x0 + 1, x0 + brick_w):
                a.set(x % w, y0 + 1, shade(tone, 0.22))
            for y in range(y0 + 1, y0 + brick_h):
                a.set((x0 + 1) % w, y, shade(tone, 0.14))
            for x in range(x0 + 1, x0 + brick_w):
                a.set(x % w, y0 + brick_h - 1, shade(tone, -0.2))
    for y in range(h):
        for x in range(w):
            col = a.get(x, y)
            if rnd.random() < 0.05:
                a.set(x, y, shade(col, rnd.choice([-0.12, 0.1])))
    return a


def stone_texture(size, base, seed, spread=0.22, moss_tint=False, cracks=3):
    """Natural rock, no mortar lines: seamless low-frequency mottling in a few flat tone steps,
    grain, a couple of hairline cracks, and (optionally) green moss stains."""
    rnd = random.Random(seed)

    def field(n):
        small = Image.new("L", (n, n))
        for y in range(n):
            for x in range(n):
                small.putpixel((x, y), rnd.randint(0, 255))
        tiled = Image.new("L", (n * 3, n * 3))
        for ty in range(3):
            for tx in range(3):
                tiled.paste(small, (tx * n, ty * n))
        big = tiled.resize((size * 3, size * 3), Image.BICUBIC)
        return big.crop((size, size, size * 2, size * 2))

    coarse, mid, fine = field(3), field(6), field(12)
    mossy = field(4)
    a = Art(size, size)
    for y in range(size):
        for x in range(size):
            v = (coarse.getpixel((x, y)) * 0.5 + mid.getpixel((x, y)) * 0.3 + fine.getpixel((x, y)) * 0.2) / 255.0
            step = round((v - 0.5) * 6) / 6.0           # flat tone steps, like painted pixel art
            c = shade(base, step * spread * 2)
            if moss_tint and mossy.getpixel((x, y)) > 175 and fine.getpixel((x, y)) > 110:
                c = mix(c, hexc("#5d7d38"), 0.55)
            a.set(x, y, c)
    for y in range(size):
        for x in range(size):
            r = rnd.random()
            if r < 0.05:
                a.set(x, y, shade(a.get(x, y), -0.14))
            elif r < 0.09:
                a.set(x, y, shade(a.get(x, y), 0.10))
    for _ in range(cracks):
        crack(a, rnd, rnd.randint(4, size - 5), rnd.randint(2, size - 10), rnd.randint(7, 12), shade(base, -0.5), shade(base, 0.18), (3, 3, size - 4, size - 4))
    return a


def transpose(a):
    t = Art(a.h, a.w)
    for y in range(a.h):
        for x in range(a.w):
            t.px[x][y] = a.px[y][x]
    return t


def trim_v(seed=51):
    """The window's side trim: the pillar's carved triangles, small (7 x 24 art px = four of them)."""
    rnd = random.Random(seed)
    base = hexc("#a9a99a")
    a = Art(7, 24, base)
    speckle(a, base, rnd, 0.7)
    for i in range(4):
        triangle(a, 1, i * 6, 5, 5, "r" if i % 2 == 0 else "l", base)
    return a


# ---- the window's edge: a rounded, raised stone rim -----------------------------------------

FRAME_T = 6          # rim thickness in art px (12 dp)
FRAME_R = 8          # outer corner radius in art px (16 dp)
FRAME_BASE = hexc("#a9a99a")


def rim_pixel(idx, lit, rnd):
    """One pixel of the rim by its depth from the outer edge (0 = outline ... 5 = the groove next to the content).
    `lit` is +1 where the outward slope faces the light (top, left) and -1 where it faces away (bottom, right)."""
    base = FRAME_BASE
    if idx == 0:
        return hexc("#1b1d1a")
    if idx == 1:                                  # the outer slope
        return shade(base, 0.40 * lit) if lit != 0 else shade(base, 0.04)
    if idx == 2:                                  # the crown, brightest where the stone curves toward the light
        return shade(base, 0.12)
    if idx == 3:
        c = base
        r = rnd.random()
        return shade(c, -0.10) if r < 0.08 else shade(c, 0.08) if r < 0.14 else c
    if idx == 4:                                  # the inner slope faces the opposite way
        return shade(base, -0.40 * lit) if lit != 0 else shade(base, -0.08)
    return hexc("#2b2e29")                        # the groove


def frame_bar(side, length, seed):
    rnd = random.Random(seed)
    horizontal = side in ("t", "b")
    a = Art(length, FRAME_T) if horizontal else Art(FRAME_T, length)
    lit = 1 if side in ("t", "l") else -1
    for y in range(a.h):
        for x in range(a.w):
            depth = (y if side == "t" else FRAME_T - 1 - y) if horizontal else (x if side == "l" else FRAME_T - 1 - x)
            a.set(x, y, rim_pixel(depth, lit, rnd))
    return a


def frame_corner(corner, seed):
    """An 8 x 8 corner: the rim bent round a quarter circle, shaded by which way each pixel faces."""
    rnd = random.Random(seed)
    cx = FRAME_R if corner[1] == "l" else 0
    cy = FRAME_R if corner[0] == "t" else 0
    a = Art(FRAME_R, FRAME_R)
    for y in range(FRAME_R):
        for x in range(FRAME_R):
            dx, dy = (x + 0.5) - cx, (y + 0.5) - cy
            d = math.hypot(dx, dy)
            if d > FRAME_R or d < 2.0:
                continue
            idx = max(0, min(FRAME_T - 1, int(FRAME_R - d)))
            lit = (dx * -0.7071 + dy * -0.7071) / d     # outward normal . direction to the light
            a.set(x, y, rim_pixel(idx, 1 if lit > 0.35 else -1 if lit < -0.35 else 0, rnd))
    return a


SURFACES = {
    "darkstone": "#34342D", "parchment": "#FEF3C7", "cyan": "#4EB4C6", "dark": "#3B413A",
    "slot": "#A9A9AB", "slotempty": "#B2B2B5", "cyanpale": "#C9ECEC", "pale": "#EDEDEF",
    "navy": "#1E2A47", "navy2": "#33466F", "navy3": "#3A4A6B", "tan": "#D9B77E",
    "barbg": "#5E5E66", "tally": "#D8D8DC", "red": "#EF4444", "side": "#E4E4E8",
    "p-red": "#FECACA", "p-blue": "#BFDBFE", "p-green": "#A7F3D0", "p-gold": "#FDE68A",
}


def badge(d, seed):
    """A small round brown wooden stud for the A / B letters: dark outline, lit rim top left, shaded rim bottom right."""
    rnd = random.Random(seed)
    base = hexc("#7b4a27")
    a = Art(d, d)
    c = (d - 1) / 2
    for y in range(d):
        for x in range(d):
            r = math.hypot(x - c, y - c)
            if r > c + 0.3:
                continue
            lit = ((c - x) + (c - y)) / (2 * c)          # + toward the top left
            if r > c - 1.0:
                col = hexc("#1e1008")
            elif r > c - 2.2:
                col = shade(base, 0.36) if lit > 0.15 else shade(base, -0.42) if lit < -0.15 else shade(base, -0.05)
            else:
                col = shade(base, 0.04)
                q = rnd.random()
                if q < 0.12:
                    col = shade(base, -0.16)
                elif q < 0.2:
                    col = shade(base, 0.14)
            a.set(x, y, col)
    return a


def build():
    UI.mkdir(parents=True, exist_ok=True)
    pillar("l").save("stone-pillar-l.png")
    pillar("r", seed=23).save("stone-pillar-r.png")

    plate(36, 38, hexc("#5f9a3d"), 3).save("stone-plate-green.png")
    plate(36, 38, hexc("#b4463d"), 5).save("stone-plate-red.png")

    badge(14, 5).save("stone-badge.png")
    disc(30, hexc("#9d9d92"), 7).save("stone-disc.png")
    disc(30, hexc("#9d9d92"), 7, pressed=True).save("stone-disc-down.png")

    slab(54, 38, hexc("#3f8fe0"), random.Random(31), flat_bottom=True, cracks=3).save("stone-slab-blue.png")
    slab(54, 38, hexc("#8f62d8"), random.Random(37), flat_bottom=True, cracks=3).save("stone-slab-purple.png")
    slab(54, 38, hexc("#8cd0f2"), random.Random(41), flat_bottom=True, cracks=3).save("stone-slab-cyan.png")
    slab(54, 38, hexc("#3a74c0"), random.Random(31), flat_bottom=True, cracks=3).save("stone-slab-blue-down.png")
    slab(54, 38, hexc("#6aaed4"), random.Random(41), flat_bottom=True, cracks=3).save("stone-slab-cyan-down.png")

    # the window's frame and the wall behind everything: plain stone
    # the pillar's weathered stone without the carvings, for the cards and the window
    stone_texture(48, hexc("#a9a99a"), 14, spread=0.045, cracks=0).save("stone-card.png")
    for side, seed in (("t", 61), ("b", 62), ("l", 63), ("r", 64)):
        frame_bar(side, 24, seed).save(f"stone-rim-{side}.png")
    for corner, seed in (("tl", 71), ("tr", 72), ("bl", 73), ("br", 74)):
        frame_corner(corner, seed).save(f"stone-rim-{corner}.png")
    stone_texture(64, hexc("#4f564d"), 9, spread=0.13, moss_tint=True, cracks=2).save("stone-wall.png")

    # Every flat colour in the stylesheet gets the same colour in stone: a quiet speckle, no cracks.
    for i, (name, colour) in enumerate(SURFACES.items()):
        stone_texture(24, hexc(colour), 100 + i, spread=0.04, cracks=0).save(f"tex-{name}.png")

    # arrows for the prev / next slabs: flat dark navy triangles
    for name, d in (("stone-arrow-l.png", "l"), ("stone-arrow-r.png", "r")):
        a = Art(6, 9)
        for y in range(9):
            span = 5 - abs(y - 4) if False else 6 - abs(y - 4) * 6 // 5
            span = max(1, 6 - abs(y - 4) * 6 // 5 - (1 if abs(y - 4) == 4 else 0))
            for k in range(span):
                a.set(k if d == "r" else 5 - k, y, hexc("#1b1f6b"))
        a.save(name)
    print("ok")


if __name__ == "__main__":
    build()
