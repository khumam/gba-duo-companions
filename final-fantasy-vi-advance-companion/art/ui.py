#!/usr/bin/env python3
"""Draws the FFVI menu windows (blue gradient, grey double frame, rounded corners) into assets/ui,
one PNG per size used by the layout (1 art px = 1 px; the CSS scales it 5 device px). Original art.

    python3 art/ui.py
"""
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui")
os.makedirs(OUT, exist_ok=True)
C = lambda h: tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)
TOP, BOT = (41, 41, 132), (18, 17, 57)            # window gradient, sampled from the game
RING = [C("#4e5656"), C("#c2d8d8"), C("#7c7b7b"), C("#272d2d")]   # outer dark, light, mid, inner dark

def window(w, h):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0)); px = im.load()
    def inside(x, y, inset):
        # rounded rectangle, corner radius 3 shrinking with the inset
        if x < inset or y < inset or x >= w - inset or y >= h - inset: return False
        r = max(0, 3 - inset)
        cx = min(x - inset, w - 1 - inset - x); cy = min(y - inset, h - 1 - inset - y)
        return not (cx < r and cy < r and (r - cx) + (r - cy) > r + (1 if r > 1 else 0))
    for y in range(h):
        t = y / max(1, h - 1)
        grad = tuple(int(TOP[i] + (BOT[i] - TOP[i]) * t) for i in range(3)) + (255,)
        for x in range(w):
            if not inside(x, y, 0): continue
            c = grad
            for k in range(4):
                if inside(x, y, k): continue
                c = RING[k]; break
            else:
                c = grad
            # the ring is the first inset level that does NOT contain the pixel
            level = 0
            while level < 4 and inside(x, y, level): level += 1
            px[x, y] = RING[level - 1] if level < 4 and level > 0 and not inside(x, y, level) else grad
    return im

SIZES = [(240, 156), (240, 22), (240, 20), (240, 134), (240, 158), (240, 70), (240, 86), (240, 68), (240, 88), (76, 26), (80, 26), (240, 208), (200, 86)]
if __name__ == "__main__":
    for w, h in SIZES:
        window(w, h).save(os.path.join(OUT, f"win-{w}x{h}.png"))
    print("ok")
