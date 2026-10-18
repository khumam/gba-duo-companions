"""Grows map-placeholder.png so the map gets a GAP px margin inside it.

The frame art's corners and rim (B px deep) are kept pixel for pixel; only the
plain middle is extended. Writes assets/img/map-placeholder-<GAP>.png.

    python3 art/map_placeholder.py [gap]     # default 6
"""
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
GAP = int(sys.argv[1]) if len(sys.argv) > 1 else 6   # px between map edge and frame edge
MAP_W, MAP_H = 154, 124     # assets/icons/worldmap.png
B = 12                      # the frame art's corner depth (48x48 socket at 2x)

src = Image.open(ROOT / "assets/img/map-placeholder.png").convert("RGBA")
sw, sh = src.size
W, H = MAP_W + 2 * GAP, MAP_H + 2 * GAP
out = Image.new("RGBA", (W, H))

def stretch(region, box):
    """Fills box with a strip of the frame, repeated (it's plain or a 1px pattern)."""
    piece = src.crop(region); pw, ph = piece.size
    for y in range(box[1], box[3], ph):
        for x in range(box[0], box[2], pw):
            out.paste(piece.crop((0, 0, min(pw, box[2] - x), min(ph, box[3] - y))), (x, y))

# The rim has gaps and highlights along it, so repeating a long stretch would
# look dashed: each edge repeats one 1px slice taken where the rim is solid.
TOP_X, BOTTOM_X, SIDE_Y = 14, 24, 12
stretch((B, B, B + 1, B + 1), (B, B, W - B, H - B))                  # plain middle
stretch((TOP_X, 0, TOP_X + 1, B), (B, 0, W - B, B))                  # top
stretch((BOTTOM_X, sh - B, BOTTOM_X + 1, sh), (B, H - B, W - B, H))  # bottom
stretch((0, SIDE_Y, B, SIDE_Y + 1), (0, B, B, H - B))                # left
stretch((sw - B, SIDE_Y, sw, SIDE_Y + 1), (W - B, B, W, H - B))      # right
for (sx, sy), (dx, dy) in [((0, 0), (0, 0)), ((sw - B, 0), (W - B, 0)),
                           ((0, sh - B), (0, H - B)), ((sw - B, sh - B), (W - B, H - B))]:
    out.paste(src.crop((sx, sy, sx + B, sy + B)), (dx, dy))

name = f"map-placeholder-{GAP}.png"
out.save(ROOT / "assets/img" / name)
print(name, W, H)
