"""Centre the item and seed icons in their frames.

The icons were cut from the game as 16 x 16 frames (160 px: 10 px per art pixel) with 8-pixel-wide art in the left half
(and the 8 x 8 seeds in the top-left corner), which looks off-centre once the frame is laid out in a slot. This moves
such art to the middle of its frame. Run: python3 art/center-icons.py  (needs Pillow; safe to run twice: art already
past the left half is left alone).
"""
from pathlib import Path
from PIL import Image

UI = Path(__file__).resolve().parent.parent / "assets" / "ui"
NAMES = "bombchu bombs boomerang bracelet cane feather hook satchel shield shooter shovel sword seed-ember seed-gale seed-mystery seed-pegasus seed-scent".split()
for name in NAMES:
    path = UI / f"{name}.png"
    im = Image.open(path).convert("RGBA")
    if im.size != (160, 160):
        continue
    x0, y0, x1, y1 = im.getbbox()
    dx = 40 if x1 <= 80 else 0
    dy = 40 if y1 <= 80 else 0
    if not (dx or dy):
        continue
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, (dx, dy))
    out.save(path)
    print("centred", name, (dx, dy))
