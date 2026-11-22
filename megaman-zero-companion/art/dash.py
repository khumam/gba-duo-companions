#!/usr/bin/env python3
"""Small art for the dashboard: grid tile (the game's brown pause grid), page chevrons, Zero's portrait
(cut from the old status picture in art/old/)."""
from PIL import Image, ImageDraw
BG, LINE, PEACH, DK = (22, 12, 11), (55, 34, 29), (232, 168, 131), (141, 95, 78)

t = Image.new("RGB", (8, 8), BG)
d = ImageDraw.Draw(t)
d.line([(0, 7), (7, 7)], fill=LINE); d.line([(7, 0), (7, 7)], fill=LINE)
t.save("assets/ui/grid.png")

def chev(flip):
    rows = ["...X", "..XX", ".XXX", "XXXX", ".XXX", "..XX", "...X"] if flip else ["X...", "XX..", "XXX.", "XXXX", "XXX.", "XX..", "X..."]
    im = Image.new("RGBA", (4, 7))
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c == "X": im.putpixel((x, y), (22, 12, 11, 255))
    return im
chev(True).save("assets/ui/chev-l.png"); chev(False).save("assets/ui/chev-r.png")

src = Image.open("art/old/status.png").convert("RGB")
src.crop((0, 0, 52, 32)).save("assets/ui/zero.png")
