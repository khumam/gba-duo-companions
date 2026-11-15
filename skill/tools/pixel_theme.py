"""Pixel-art identity for the Pokemon companion packs: a background motif, an emblem per game.

Run: python3 -I skill/tools/pixel_theme.py        (needs Pillow; run from the gbaduo-companions folder)
  -> <pack>/assets/ui/px-bg.png      the screen's background tile (drawn on a 2 dp grid, written 4x larger)
  -> <pack>/assets/ui/px-emblem.png  a 16 x 16 art px emblem for the header (flame, leaf, ruby, sapphire, emerald)
  -> <pack>/assets/ui/px-gloss-*.png a hard-edged pixel shine per button size (and the rules in style.css, once)

Everything is drawn on a small grid and enlarged with nearest neighbour, so edges stay crisp. Each game gets its own
motif: FireRed rising flames, LeafGreen leaves, Ruby cracked lava rock, Sapphire waves, Emerald cut gems.
"""
import random
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]  # the gbaduo-companions folder (this file is in skill/tools/)
SCALE = 4


def hexc(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def shade(c, f):
    mix = (255, 255, 255) if f > 0 else (0, 0, 0)
    f = abs(f)
    return tuple(round(c[i] + (mix[i] - c[i]) * f) for i in range(3))


class Canvas:
    def __init__(self, w, h, base=None):
        self.w, self.h = w, h
        self.px = [[base for _ in range(w)] for _ in range(h)]

    def set(self, x, y, c):
        self.px[y % self.h][x % self.w] = c          # wraps, so every motif tiles

    def get(self, x, y):
        return self.px[y % self.h][x % self.w]

    def glyph(self, rows, ox, oy, palette):
        for dy, row in enumerate(rows):
            for dx, ch in enumerate(row):
                if ch in palette:
                    self.set(ox + dx, oy + dy, palette[ch])

    def save(self, path):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                c = self.px[y][x]
                if c is not None:
                    img.putpixel((x, y), tuple(c) if len(c) == 4 else (*c, 255))
        img.resize((self.w * SCALE, self.h * SCALE), Image.NEAREST).save(path)


# ---- glyphs -----------------------------------------------------------------------------------

FLAME = [
    "..o..",
    ".oro.",
    ".orro",
    "orryo",
    "orrywo",
    "orryyo",
    ".oooo.",
]
FLAME_BIG = [
    ".......o........",
    "......ooo.......",
    "......orro......",
    ".....orrro......",
    ".....orryoo.....",
    "....orrryyo.o...",
    "....orryyyoroo..",
    "...orrryywyyro..",
    "...orryywwyyro..",
    "..orrryywwwyrro.",
    "..orrryywwwyrro.",
    "..orrryywwwyrro.",
    "..orrrryywyyrro.",
    "...orrrryyyrrro.",
    "....oorrrrrrroo.",
    "......oooooooo..",
]
LEAF = [
    "......oo",
    "....oogo",
    "...oggGo",
    "..oggGgo",
    "..ogGggo",
    ".ogGggo.",
    "ogGgoo..",
    "oGoo....",
]
LEAF_BIG = [
    "................",
    "..........ooooo.",
    ".......ooogggggo",
    ".....oogggGggggo",
    "....ogggGggggggo",
    "...ogggGgggggggo",
    "...oggGgggggggo.",
    "..ogggGggggggo..",
    "..ogggGgggggo...",
    "..oggGggggoo....",
    ".oggGgggoo......",
    ".ogGgggo........",
    "ogGggo..........",
    "ooGoo...........",
    "oG..............",
    "o...............",
]
GEM = [
    ".....oooooo.....",
    "....ohhhhhho....",
    "...ohhhhhhhho...",
    "..ohhhmmmmhhho..",
    ".ohhmmmmmmmmhho.",
    ".ohmmmmmmmmmmdo.",
    ".ohmmmmmmmmmddo.",
    "..ommmmmmmmddo..",
    "..ommmmmmmmddo..",
    "...ommmmmmddo...",
    "...ommmmmmddo...",
    "....ommmmddo....",
    ".....ommddo.....",
    "......oddo......",
    ".......oo.......",
    "................",
]


def flame_palette(base):
    return {"o": hexc("#5a1408"), "r": hexc("#d8331a"), "y": hexc("#f58a1f"), "w": hexc("#ffe27a")}


# ---- emblems (16 x 16) --------------------------------------------------------------------------

def emblem(kind):
    c = Canvas(16, 16)
    if kind == "flame":
        c.glyph(FLAME_BIG, 0, 0, flame_palette(None))
    elif kind == "leaf":
        c.glyph(LEAF_BIG, 0, 0, {"o": hexc("#16380f"), "g": hexc("#4fa82a"), "G": hexc("#a8e060")})
    else:
        pal = {
            "ruby": ("#3a0508", "#ff7a80", "#e0202c", "#8a0814"),
            "sapphire": ("#0a1a40", "#9cc8ff", "#3a78e0", "#1a3c94"),
            "emerald": ("#05301f", "#9cffc4", "#20c878", "#0c7a48"),
        }[kind]
        c.glyph(GEM, 0, 0, {"o": hexc(pal[0]), "h": hexc(pal[1]), "m": hexc(pal[2]), "d": hexc(pal[3])})
        c.set(4, 3, (255, 255, 255))                 # a glint
        c.set(5, 3, (255, 255, 255))
        c.set(4, 4, (255, 255, 255))
    return c


# ---- background motifs ----------------------------------------------------------------------------

def bg_flames(base):
    t = Canvas(24, 24, base)
    dark, light = shade(base, -0.16), shade(base, 0.12)
    pal = {"o": dark, "r": shade(base, -0.04), "y": light, "w": shade(base, 0.22)}
    for ox, oy in ((2, 1), (14, 13)):
        t.glyph(FLAME, ox, oy, pal)
    # tiny embers
    for x, y in ((9, 6), (20, 4), (5, 17), (18, 21), (11, 12)):
        t.set(x, y, light)
    return t


def bg_leaves(base):
    t = Canvas(24, 24, base)
    pal = {"o": shade(base, -0.16), "g": shade(base, 0.03), "G": shade(base, 0.2)}
    for ox, oy in ((1, 2), (13, 13)):
        t.glyph(LEAF, ox, oy, pal)
    for x, y in ((10, 4), (20, 8), (6, 18), (18, 19)):
        t.set(x, y, shade(base, 0.10))
    return t


def bg_rock(base):
    rnd = random.Random(7)
    t = Canvas(32, 32, base)
    # darker and lighter plates
    for _ in range(14):
        cx, cy = rnd.randrange(32), rnd.randrange(32)
        rx, ry = rnd.randint(3, 6), rnd.randint(2, 4)
        tone = shade(base, rnd.choice((-0.12, 0.08)))
        for y in range(-ry, ry + 1):
            for x in range(-rx, rx + 1):
                if (x / rx) ** 2 + (y / ry) ** 2 <= 1:
                    t.set(cx + x, cy + y, tone)
    # lava cracks with a glow
    for _ in range(5):
        x, y = rnd.randrange(32), rnd.randrange(32)
        dx = rnd.choice((-1, 1))
        for i in range(rnd.randint(5, 9)):
            t.set(x, y, hexc("#ff7a1a"))
            t.set(x, y + 1, shade(base, -0.28))
            x += dx
            if rnd.random() < 0.5:
                y += 1
    for _ in range(6):
        t.set(rnd.randrange(32), rnd.randrange(32), hexc("#ffd060"))
    return t


def bg_waves(base):
    t = Canvas(32, 16, base)
    dark, crest, foam = shade(base, -0.10), shade(base, 0.10), shade(base, 0.32)
    for row, off in ((3, 0), (11, 16)):
        for x in range(32):
            p = (x + off) % 16
            y = row + (0 if p < 4 else 1 if p < 6 else 2 if p < 10 else 1 if p < 12 else 0)
            t.set(x, y, crest)
            t.set(x, y + 1, dark)
            if p in (4, 5, 9, 10):
                t.set(x, y - 1, foam)
    return t


def bg_gems(base):
    t = Canvas(24, 24, base)
    dark, light, glint = shade(base, -0.09), shade(base, 0.09), shade(base, 0.28)
    # a lattice of diamonds
    for i in range(24):
        t.set(i, i, dark)
        t.set(23 - i, i, dark)
        if i % 2 == 0:
            t.set(i, (i + 1) % 24, light)
            t.set(23 - i, (i + 1) % 24, light)
    for x, y in ((0, 0), (12, 12)):
        for d in range(-1, 2):
            t.set(x + d, y, glint)
            t.set(x, y + d, glint)
    return t


# ---- pixel gloss ----------------------------------------------------------------------------------
# A hard-edged shine for buttons: a lit diagonal band at the top left with one bright pixel line along its edge,
# a bright pixel row on top and a dark one underneath. No smooth gradient: every step is a whole art pixel.

GLOSS_FRLG = {
    ".bar-btn": (138, 46), ".wild-method": (176, 36), ".pockets tab": (92, 32), ".opt-btn": (220, 44),
    ".pg-btn": (46, 38), ".map-mode": (70, 24), ".tile": (126, 74), ".t-fight": (190, 74),
}
GLOSS_RSE = {
    ".bar-btn": (136, 44), ".pockets tab": (60, 26), ".dtabs tab": (74, 30), ".opt-btn": (176, 42), ".pg-btn": (46, 36),
    ".map-mode": (60, 20), ".wild-method": (150, 30), ".fight-btn": (190, 70), ".t-mon": (126, 70), ".t-bag": (126, 70),
    ".t-run": (126, 70),
}


def gloss(w_dp, h_dp):
    w, h = max(8, w_dp // 2), max(6, h_dp // 2)
    c = Canvas(w, h)
    c.px = [[None for _ in range(w)] for _ in range(h)]
    for y in range(h):
        edge = int((0.30 - 0.16 * y / h) * w)
        for x in range(w):
            if x < edge - 5:
                c.px[y][x] = (255, 255, 255, 78)             # the lit band
            elif x < edge - 3:
                c.px[y][x] = (255, 255, 255, 30)             # a darker gap
            elif x < edge - 1:
                c.px[y][x] = (255, 255, 255, 120)            # a thin second shine strip
            elif x == edge:
                c.px[y][x] = (255, 255, 255, 150)            # the bright edge line
    for x in range(w):                                   # a bright row on top, a dark one underneath
        c.px[0][x] = (255, 255, 255, 140)
        c.px[h - 1][x] = (0, 0, 0, 70)
        if h > 8:
            c.px[h - 2][x] = (0, 0, 0, 24)
    return c


def gloss_css(table):
    lines = ["", "/* ---- pixel gloss: a hard-edged shine on the buttons ------------------------------------------ */"]
    for sel, (w, h) in table.items():
        lines.append(f'{sel} {{ background-image: url("assets/ui/px-gloss-{w}x{h}.png"); background-size: {w}px {h}px; background-repeat: no-repeat; }}')
    return "\n".join(lines) + "\n"


def apply_gloss(pack, table):
    ui = ROOT / pack / "assets" / "ui"
    for w, h in table.values():
        gloss(w, h).save(ui / f"px-gloss-{w}x{h}.png")
    css = ROOT / pack / "style.css"
    s = css.read_text()
    if "pixel gloss" not in s:
        css.write_text(s + gloss_css(table))


THEMES = {
    "pokemon-firered-companion": ("flame", bg_flames, "#F46A44"),
    "pokemon-leafgreen-companion": ("leaf", bg_leaves, "#8FD43A"),
    "pokemon-ruby-companion": ("ruby", bg_rock, "#6f090b"),
    "pokemon-sapphire-companion": ("sapphire", bg_waves, "#283950"),
    "pokemon-emerald-companion": ("emerald", bg_gems, "#096f61"),
}

if __name__ == "__main__":
    for pack, (kind, bg, base) in THEMES.items():
        ui = ROOT / pack / "assets" / "ui"
        ui.mkdir(parents=True, exist_ok=True)
        bg(hexc(base)).save(ui / "px-bg.png")
        emblem(kind).save(ui / "px-emblem.png")
        apply_gloss(pack, GLOSS_FRLG if kind in ("flame", "leaf") else GLOSS_RSE)
        print(pack, "ok")
