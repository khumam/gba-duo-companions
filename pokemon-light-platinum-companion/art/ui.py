# Emerald UI art: stripe tile, red chevrons, ball icon, nav dots. Run: python3 art/ui.py
from PIL import Image
import os
out = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")
os.makedirs(out, exist_ok=True)

def px(name, rows, pal):
    h, w = len(rows), len(rows[0])
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c in pal:
                im.putpixel((x, y), pal[c])
    im.save(os.path.join(out, name))

def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)

# Bag backdrop: two blue rows, two lilac rows.
t = Image.new("RGBA", (1, 4))
for y, c in enumerate(["#5088c0", "#5088c0", "#a890c8", "#a890c8"]):
    t.putpixel((0, y), rgb(c))
t.save(os.path.join(out, "stripe.png"))

pal = {"o": rgb("#3a1820"), "r": rgb("#d85868"), "h": rgb("#f09098")}
left = ["...oo", "..orr", ".orhr", "orhrr", "orhrr", ".orhr", "..orr", "...oo"]
left = [r.ljust(5, ".") for r in left]
px("chev-l.png", left, pal)
px("chev-r.png", [r[::-1] for r in left], pal)

ball = [
    "...oooooo...",
    "..orrrrrro..",
    ".orrhrrrrro.",
    "orrhrrrrrrro",
    "orrrrrrrrrro",
    "oooooxxooooo",
    "owwwwxxwwwwo",
    "owwwwwwwwwwo",
    ".owwwwwwwwo.",
    "..owwwwwwo..",
    "...oooooo...",
]
px("ball.png", ball, {"o": rgb("#202830"), "r": rgb("#e05048"), "h": rgb("#f89888"), "w": rgb("#f8f8f8"), "x": rgb("#202830")})

# HP-bar pip colours and dots are CSS; only these small icons need pixels.
arrow = ["x....", "xx...", "xxx..", "xxxx.", "xxx..", "xx...", "x...."]
px("cursor.png", arrow, {"x": rgb("#182020")})
print("ok")

# ---- console icons -------------------------------------------------------------------------
def bits(name, rows, pal, scale=1):
    px(name, rows, pal)

INK = rgb("#182020"); WHITE = rgb("#f8f8f8")
P = lambda **k: {a: rgb(b) for a, b in k.items()}

bits("clock.png", [
    "..oooo..", ".owwwwo.", "owwwdwwo", "owwwdwwo", "owwwddwo", "owwwwwwo", ".owwwwo.", "..oooo..",
], P(o="#202830", w="#f8f8f8", d="#202830"))
bits("coin.png", [
    "..oooo..", ".oyyyyo.", "oyyhyyyo", "oyhyyyyo", "oyyyyyko", "oyyyykyo", ".oyyyyo.", "..oooo..",
], P(o="#704810", y="#f0c828", h="#fff0a0", k="#c89010"))
bits("dex.png", [
    "oooooooo", "orrrrrro", "orwwwwro", "orwbbwro", "orwbbwro", "orwwwwro", "orrrrrro", "oooooooo",
], P(o="#202830", r="#d85048", w="#f8f8f8", b="#5088c0"))
bits("male.png", [
    "...xxxx", "....xxx", "..x..xx", ".xxx.x.", "xx.xx..", "x...x..", "xx.xx..", ".xxx...",
], P(x="#4890e0"))
bits("female.png", [
    "..xxx..", ".x...x.", ".x...x.", "..xxx..", "...x...", "..xxx..", "...x...", "...x...",
], P(x="#e86898"))
bits("pin.png", [
    "..oooo..", ".orrrro.", "orrwwrro", "orrwwrro", ".orrrro.", "..orro..", "...oo...", "........",
], P(o="#202830", r="#e05048", w="#f8f8f8"))

GEMS = [("stone", "#a8a8a8"), ("knuckle", "#e8a050"), ("dynamo", "#f0d848"), ("heat", "#d85048"),
        ("balance", "#d0d0e0"), ("feather", "#78a8e8"), ("mind", "#a878c8"), ("rain", "#5080c8")]
for i, (n, col) in enumerate(GEMS):
    bits(f"badge{i + 1}.png", [
        "..ooo..", ".oxxxo.", "oxhxxxo", "oxxxxxo", ".oxxxo.", "..oxo..", "...o...",
    ], P(o="#202830", x=col, h="#ffffff"))

# pocket icons (11 x 11)
bits("pk-items.png", [
    "....oo.....", "...oggo....", "....oo.....", "...oppo....", "..oppppo...", "..opwwpo...", "..opwwpo...", "..oppppo...", "...oooo....",
], P(o="#202830", g="#a8a8a8", p="#d86088", w="#f8d8e0"))
bits("pk-balls.png", [
    "...ooooo...", "..orrrrro..", ".orrhrrrro.", "ooooooooooo", "owwwwxwwwwo", ".owwwxwwwo.", "..owwwwwo..", "...ooooo...",
], P(o="#202830", r="#e05048", h="#f89888", w="#f8f8f8", x="#202830"))
bits("pk-tm.png", [
    "...ooooo...", "..oyyyyyo..", ".oyyoooyyo.", ".oyoyyyoyo.", ".oyoyxyoyo.", ".oyoyyyoyo.", ".oyyoooyyo.", "..oyyyyyo..", "...ooooo...",
], P(o="#202830", y="#78a8d8", x="#202830"))
bits("pk-berries.png", [
    "....gg.....", "...ogo.....", "..oooooo...", ".orrrrrro..", ".orhrrrro..", ".orrrrrro..", "..orrrro...", "...oooo....",
], P(o="#202830", g="#58a848", r="#d85868", h="#f8a0b0"))
bits("pk-key.png", [
    "..ooo......", ".oyyyo.....", "oyo.oyo....", "oyo.oyo....", ".oyyyo.....", "..oyo......", "..oyyo.....", "..oyo......", "..oyyo.....",
], P(o="#202830", y="#f0c828"))

# the bag, drawn (original): a green satchel, 40 x 40
bag = [
"..............oooooo..............",
"............ooggggggoo............",
"..........ooghhgggggggoo..........",
".........oghhgggggggggggo.........",
"........ogghgggggggggggggo........",
".......oggggggggwwggggggggo.......",
".......ogggggggwwwwgggggggo.......",
"......oggggggggwwwwggggggggo......",
"......ogggggggggwwgggggggggo......",
".....ogggggggggggggggggggggggo....",
".....oggddddddddddddddddddggggo...",
"....ogggddddddddddddddddddgggggo..",
"....oggdddddooooooooooddddddggggo.",
"....ogggdddodddddddddddodddddgggo.",
"....oggggddodddddddddddodddddgggo.",
"....ogggggddddddddddddddddddggggo.",
".....oggggggddddddddddddddgggggo..",
".....oggggggggggggggggggggggggo...",
"......ooggggggggggggggggggggoo....",
"........oooooooooooooooooooo......",
]
px("bag.png", bag, P(o="#202830", g="#58a048", h="#98d078", d="#387038", w="#e8e8e8"))

# tiles: olive scanlines (party), dotted lilac (header)
def tile(name, w, h, rows):
    im = Image.new("RGBA", (w, h))
    for y, c in enumerate(rows):
        for x in range(w):
            im.putpixel((x, y), rgb(c))
    im.save(os.path.join(out, name))
tile("scan.png", 1, 4, ["#908060", "#908060", "#887858", "#887858"])
tile("sea.png", 1, 6, ["#78a8e0", "#78a8e0", "#78a8e0", "#80b0e8", "#80b0e8", "#78a8e0"])
tile("scanlt.png", 4, 4, ["#e4e8e0", "#e4e8e0", "#d4d8d0", "#d4d8d0"])
tile("scan-party.png", 1, 4, ["#d8cea8", "#d8cea8", "#d0c69e", "#d0c69e"])
tile("dusk.png", 1, 4, ["#385060", "#385060", "#30485a", "#30485a"])

# Placeholder map (original, not the game's): one landmass spread over the 28 x 15 region grid, so the
# marker computed from gRegionMapEntries lands on land. Replace with the real Hoenn map later.
from PIL import ImageDraw
W, H = 140, 75  # 5 px per grid cell
m = Image.new("RGB", (W, H), rgb("#78a8e0")[:3])
d = ImageDraw.Draw(m)
for y in range(0, H, 5):
    d.line([(0, y), (W, y)], fill=rgb("#88b4e8")[:3])
land = rgb("#78b860")[:3]
d.polygon([(10, 12), (60, 5), (110, 10), (128, 28), (118, 50), (96, 66), (40, 70), (14, 60), (6, 36)], fill=land)
d.polygon([(120, 58), (134, 56), (136, 70), (124, 71)], fill=land)
d.polygon([(2, 66), (12, 64), (14, 73), (3, 73)], fill=land)
m.save(os.path.join(out, "map.png"))
