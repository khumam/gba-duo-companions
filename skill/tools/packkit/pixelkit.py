#!/usr/bin/env python3
"""Pixel kit: makes a pack's flat, smooth UI read as pixel art, and gives every control one size.

    python3 skill/tools/packkit/pixelkit.py PACK_DIR TOKENS.json

Reads PACK/art/style.src.css and writes it back (the first run keeps the original in PACK/art/v2/style.src.css):
  * every border-radius becomes 0 (square pixel corners; round corners are anti-aliased, not pixel art)
  * every smooth linear-gradient becomes hard-stop bands (the game's bars and buttons are 3-4 tone bands, not a blend)
  * a KIT block is appended: dithered 2-tone textures on panels (tiles in PACK/assets/ui/px-*.png, 1 art pixel = 5 device
    pixels), hard 1 art-pixel shadows, one size for every big button, one for every small control, one for list icons,
    and CSS sockets (inset frame + hard shadow) around every icon so it sits in the screen like an inventory slot.
Tokens (all colours #rrggbb): surf, surf2 (dither pair of the panels), well, well2 (list wells), cmd, cmd2 (command column), shadow, edge,
socket (icon socket fill), socket_edge, btn_hi / btn / btn_lo (button bands), on (selected accent), edge_w (panel border, ap).
"""
import json, os, re, shutil, sys
from PIL import Image

AP_DEVICE_PX = 5          # 1 art pixel = 5 device pixels on the Thor


def hexrgb(h): h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
def rgbhex(c): return "#%02x%02x%02x" % tuple(max(0, min(255, int(v))) for v in c)
def mix(a, b, t): return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def tile(path, a, b):
    """two-tone checker, one art pixel per square (the GBA dither): a 2x2 art pixel tile"""
    n = AP_DEVICE_PX
    im = Image.new("RGB", (2 * n, 2 * n))
    ca, cb = hexrgb(a), hexrgb(b)
    for y in range(2 * n):
        for x in range(2 * n):
            im.putpixel((x, y), ca if ((x // n) + (y // n)) % 2 == 0 else cb)
    im.save(path)


def bands(colors, direction):
    """hard-stop gradient, at least three bands"""
    cs = [hexrgb(c) for c in colors]
    if len(cs) == 2:
        cs = [cs[0], mix(cs[0], cs[1], .5), cs[1]]
    n = len(cs)
    stops = []
    for i, c in enumerate(cs):
        lo, hi = round(100 * i / n), round(100 * (i + 1) / n)
        stops += ["%s %d%%" % (rgbhex(c), lo), "%s %d%%" % (rgbhex(c), hi)]
    return "linear-gradient(to %s, %s)" % (direction, ", ".join(stops))


GRAD = re.compile(r"linear-gradient\(\s*to (bottom|right),\s*((?:#[0-9a-fA-F]{6}(?:\s+\d+%)?\s*,?\s*)+)\)")


def banded(m):
    cols = re.findall(r"#[0-9a-fA-F]{6}", m.group(2))
    if m.group(1) == "right":                       # a left-to-right blend on a bar: shade it top to bottom instead (light, mid, dark)
        cs = sorted(cols, key=lambda c: sum(hexrgb(c)), reverse=True)
        return bands([cs[0], cs[len(cs) // 2], cs[-1]], "bottom")
    return bands(cols, m.group(1))


def kit(t):
    cmd_rule = ('.cmd {{ background-image: url("assets/ui/px-cmd.png"); background-repeat: repeat; box-shadow: 1ap 1ap 0 %s; }}\n' % t['shadow']).replace('{{', '{').replace('}}', '}') if t.get('cmd') else ''
    return f"""

/* ================= PIXEL KIT (art/pixelkit.py in the packkit): dithered surfaces, hard shadows, one size per control, icon sockets ================= */
{cmd_rule}.nwin, .nbig, .nstat, .nchip, .ninfo, .dsock, .cardwin {{ background-image: url("assets/ui/px-surf.png"); background-repeat: repeat; box-shadow: 1ap 1ap 0 {t['shadow']}; }}
.nlist-win, .relwin {{ background-image: url("assets/ui/px-well.png"); background-repeat: repeat; box-shadow: 1ap 1ap 0 {t['shadow']}; }}
.nsock, .bsock, .rel {{ box-shadow: 1ap 1ap 0 {t['shadow']}; }}
.ctab {{ border: 1ap solid {t['edge']}; box-shadow: 1ap 1ap 0 {t['shadow']}; }}
.ctab.on {{ border: 1ap solid #ffffff; box-shadow: 1ap 1ap 0 {t['shadow']}; }}
.ctab-ic {{ width: 24ap; height: 24ap; }}
.ctab-ic.c-status, .ctab-ic.c-dss, .ctab-ic.c-soul, .ctab-ic.c-equip, .ctab-ic.c-gear, .ctab-ic.c-items, .ctab-ic.c-book, .ctab-ic.c-relics, .ctab-ic.c-map {{ width: 24ap; height: 24ap; }}

/* one size for every big button, one for every small control */
.nbtn {{ height: 20ap; min-width: 54ap; padding: 0 6ap; border: 2ap solid {t['btn_edge']}; background: {bands([t['btn_hi'], t['btn'], t['btn_lo']], 'bottom')}; box-shadow: 1ap 1ap 0 {t['shadow']}; }}
.nbtn.nbtn-done {{ background: {t['off']}; border-color: {t['off_edge']}; }}
.nbtn.nbtn-s, .nmini, .ntab, .npill {{ height: 14ap; min-width: 36ap; padding: 0 4ap; border: 1ap solid {t['btn_edge']}; box-shadow: 1ap 1ap 0 {t['shadow']}; }}
.nmini {{ background: {bands([t['btn_hi'], t['btn'], t['btn_lo']], 'bottom')}; }}
.ntab {{ background: {t['off']}; border-color: {t['off_edge']}; }}
.ntab.on {{ background: {bands([t['btn_hi'], t['btn'], t['btn_lo']], 'bottom')}; border-color: {t['btn_edge']}; }}
.nbtn-t, .nmini-t, .ntab-t, .npill-t {{ font-size: 8ap; }}
.nbtn-t {{ font-size: 9ap; }}
.carr, .obtn, .perm, .pgbtn, .mbtn {{ height: 20ap; box-shadow: 1ap 1ap 0 {t['shadow']}; }}

/* list icons: one size (14ap picture in a 20ap socket) */
.nicon, .norb {{ width: 18ap; height: 18ap; padding: 1ap; background-color: {t['socket']}; border: 1ap solid {t['socket_edge']}; box-shadow: 1ap 1ap 0 {t['shadow']}; }}
.nrow {{ height: 20ap; }}
.nsock-ic, .nsock-orb {{ padding: 2ap; background-color: {t['socket']}; border: 1ap solid {t['socket_edge']}; box-shadow: 1ap 1ap 0 {t['shadow']}; }}
.nsock-ic {{ width: 22ap; height: 22ap; }}
.nsock-orb {{ width: 28ap; height: 28ap; }}
.ninfo-ic, .ninfo-ic.ic, .ninfo-ic.ic2 {{ width: 28ap; height: 28ap; margin: 0; padding: 2ap; background-color: {t['socket']}; border: 1ap solid {t['socket_edge']}; box-shadow: 1ap 1ap 0 {t['shadow']}; }}
.rel-img, .bsock-img {{ padding: 1ap; }}
"""


def main(pack, tokens_path):
    t = json.load(open(tokens_path))
    css = os.path.join(pack, "art", "style.src.css")
    backup = os.path.join(pack, "art", "v2", "style.src.css")
    if not os.path.exists(backup):
        os.makedirs(os.path.dirname(backup), exist_ok=True)
        shutil.copy(css, backup)
    src = open(backup).read()                       # always rebuild from the pre-kit stylesheet
    src = re.sub(r"border-radius:\s*[-0-9.]+(?:ap|px)", "border-radius: 0", src)
    src = GRAD.sub(banded, src)
    src += kit(t)
    open(css, "w").write(src)
    ui = os.path.join(pack, "assets", "ui")
    tile(os.path.join(ui, "px-surf.png"), t["surf"], t["surf2"])
    tile(os.path.join(ui, "px-well.png"), t["well"], t["well2"])
    if t.get("cmd"): tile(os.path.join(ui, "px-cmd.png"), t["cmd"], t["cmd2"])
    print("pixelkit ok", pack)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
