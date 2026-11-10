"""Stat plates (rupees, kinstones) and nav buttons of the bezel.

Run: python3 art/chrome_buttons.py
  -> assets/ui/stat-plate-{l,r}.png   recessed grey plates, one chamfered corner (132 x 57 dp)
  -> assets/ui/nav-btn-{l,r}.png      raised light-blue buttons with a dark-blue border and a
                                      hard drop shadow (156 x 74 dp)
  -> assets/ui/round-ezlo.png, round-socket.png   64 dp circles with a raised outer bevel
Drawn at 4 px per dp, no antialiasing, to keep the pixel-art look.
"""
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

UI = Path(__file__).resolve().parent.parent / "assets" / "ui"
K = 4


def mask(size, poly, dx=0, dy=0):
    m = Image.new("L", (size[0] * K, size[1] * K), 0)
    ImageDraw.Draw(m).polygon([((x + dx) * K, (y + dy) * K) for x, y in poly], fill=255)
    return m


def shifted(m, dx, dy):
    out = Image.new("L", m.size, 0)
    out.paste(m, (dx * K, dy * K))
    return out


def minus(a, b):
    return ImageChops.subtract(a, b)


def solid(size, rgba):
    return Image.new("RGBA", (size[0] * K, size[1] * K), rgba)


def bevel_shape(size, poly, base, outline, light, dark, depth, edge, raised, ox=0, oy=0):
    """Fill `poly` with `base`, an `edge` dp outline, then a `depth` dp bevel just inside it."""
    img = Image.new("RGBA", (size[0] * K, size[1] * K), (0, 0, 0, 0))
    outer = mask(size, poly, ox, oy)
    img.paste(solid(size, outline), mask=outer)
    inner = ImageChops.multiply(outer, shifted(outer, 0, 0))
    # shrink the outline by `edge` dp: intersect the four shifted copies
    for dx, dy in ((edge, 0), (-edge, 0), (0, edge), (0, -edge)):
        inner = ImageChops.multiply(inner, shifted(outer, dx, dy))
    img.paste(solid(size, base), mask=inner)
    top_left = minus(inner, shifted(inner, depth, depth))
    bottom_right = minus(inner, shifted(inner, -depth, -depth))
    tl_col, br_col = (light, dark) if raised else (dark, light)
    img.paste(solid(size, tl_col), mask=top_left)
    img.paste(solid(size, br_col), mask=bottom_right)
    return img


def stat_plate():
    size = (132, 57)
    poly = [(0, 0), (132, 0), (132, 29), (92, 57), (0, 57)]
    img = bevel_shape(size, poly, (169, 169, 171, 255), (59, 59, 66, 255),
                      (236, 236, 238, 255), (112, 112, 118, 255), 3, 2, raised=False)
    img.save(UI / "stat-plate-l.png")
    img.transpose(Image.FLIP_LEFT_RIGHT).save(UI / "stat-plate-r.png")


def nav_button(left):
    size = (156, 74)
    poly = [(0, 0), (108, 0), (152, 36), (152, 70), (0, 70)]  # chamfer top-right
    if not left:
        poly = [(152 - x, y) for x, y in poly]                # chamfer top-left
    bx, sx = (4, 0) if left else (0, 4)                       # button / shadow x offset
    navy = (22, 40, 110, 255)
    img = Image.new("RGBA", (size[0] * K, size[1] * K), (0, 0, 0, 0))
    img.paste(solid(size, navy), mask=mask(size, poly, sx, 4))
    btn = bevel_shape(size, poly, (143, 205, 232, 255), navy, (214, 240, 250, 255),
                      (72, 146, 196, 255), 3, 3, raised=True, ox=bx)
    img.alpha_composite(btn)
    return img


def round_button(face, name):
    n = 64 * K
    c = n / 2
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = img.load()
    outline, light, dark = (59, 59, 66, 255), (252, 252, 255, 255), (96, 96, 104, 255)
    for y in range(n):
        for x in range(n):
            dx, dy = x + 0.5 - c, y + 0.5 - c
            r = (dx * dx + dy * dy) ** 0.5 / K
            if r > 32:
                continue
            if r > 30 or r > 24 and False:
                px[x, y] = outline
            elif r > 25:
                px[x, y] = light if dx + dy < 0 else dark
            elif r > 24:
                px[x, y] = outline
            else:
                px[x, y] = face
    img.save(UI / name)


round_button((249, 115, 22, 255), "round-ezlo.png")
round_button((216, 216, 220, 255), "round-socket.png")
nav_button(True).save(UI / "nav-btn-l.png")
nav_button(False).save(UI / "nav-btn-r.png")
stat_plate()
print("ok")
