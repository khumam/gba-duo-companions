"""Corner pieces of the pause-menu bezel (notched stone plates with a light band).

Run: python3 art/frame_corners.py   -> assets/ui/corner-{tl,tr,bl,br}.png

Each piece is 160 x 80 dp drawn at 4 px per dp. The stone tile is assets/ui/stone-light.png
at 80 dp, so it lines up with the CSS-tiled side rails (80 dp wide, same tile phase).
"""
from pathlib import Path
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
UI = HERE.parent / "assets" / "ui"
K = 4          # px per dp
SS = 2         # supersample
W, H = 160, 80
EDGE, BAND = 3, 3  # dp: dark outline, copper band
DARK, COPPER = (59, 59, 66, 255), (216, 216, 220, 255)  # outline, light band

# Top-left piece; the first and last edges lie on the screen's top and left sides.
POLY = [(0, 0), (160, 0), (160, 40), (112, 76), (80, 76), (80, 80), (0, 80)]
# edge i runs POLY[i] -> POLY[i+1]; True = no outline (screen edge, or the seam where the rail continues)
ON_SCREEN = [True, False, False, False, False, True, True]


def inset(poly, flags, d):
    n = len(poly)
    lines = []
    for i in range(n):
        (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % n]
        dx, dy = x2 - x1, y2 - y1
        ln = (dx * dx + dy * dy) ** 0.5
        nx, ny = -dy / ln, dx / ln  # inward normal (polygon runs clockwise on screen)
        o = -60 if flags[i] else d
        lines.append(((x1 + nx * o, y1 + ny * o), (dx, dy)))
    out = []
    for i in range(n):
        (p, r), (q, s) = lines[i - 1], lines[i]
        den = r[0] * s[1] - r[1] * s[0]
        t = ((q[0] - p[0]) * s[1] - (q[1] - p[1]) * s[0]) / den
        out.append((p[0] + r[0] * t, p[1] + r[1] * t))
    return out


def shape_mask(poly):
    m = Image.new("L", (W * K * SS, H * K * SS), 0)
    ImageDraw.Draw(m).polygon([(x * K * SS, y * K * SS) for x, y in poly], fill=255)
    return m.resize((W * K, H * K), Image.LANCZOS)


def build():
    tile = Image.open(UI / "stone-light.png").convert("RGBA").resize((80 * K, 80 * K), Image.LANCZOS)
    leather = Image.new("RGBA", (W * K, H * K))
    for ty in range(0, H * K, tile.height):
        for tx in range(0, W * K, tile.width):
            leather.paste(tile, (tx, ty))
    img = Image.new("RGBA", (W * K, H * K), (0, 0, 0, 0))
    img.paste(Image.new("RGBA", img.size, DARK), mask=shape_mask(POLY))
    img.paste(Image.new("RGBA", img.size, COPPER), mask=shape_mask(inset(POLY, ON_SCREEN, EDGE)))
    img.paste(leather, mask=shape_mask(inset(POLY, ON_SCREEN, EDGE + BAND)))
    return img


tl = build()
tl.save(UI / "corner-tl.png")
tl.transpose(Image.FLIP_LEFT_RIGHT).save(UI / "corner-tr.png")
tl.transpose(Image.FLIP_TOP_BOTTOM).save(UI / "corner-bl.png")
tl.transpose(Image.ROTATE_180).save(UI / "corner-br.png")
print("ok")
