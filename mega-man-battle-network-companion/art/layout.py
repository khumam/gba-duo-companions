#!/usr/bin/env python3
"""Writes layout.json for the MMBN companion (Folder, Library, MegaMan, Email, Items, Network pages) and the two arrow icons. python3 art/layout.py"""
import json, os
from PIL import Image

def box(cls, ch=(), **kw):     return {"type": "box", "class": cls, "children": list(ch), **kw}
def text(cls, t, **kw):        return {"type": "text", "class": cls, "text": t, **kw}
def img(cls, src, **kw):       return {"type": "image", "class": cls, "src": src, **kw}
def button(cls, on, ch, **kw): return {"type": "button", "class": cls, "onClick": on, "children": list(ch), **kw}
def lst(cls, items, tpl, **kw): return {"type": "list", "class": cls, "items": items, "template": tpl, **kw}

here = os.path.dirname(os.path.abspath(__file__))

# ---- pixel arrows (icons, not typed < >): a 4 x 7 triangle with a 1 px outline in the text's colour --------------------------
TRI = [1, 2, 3, 4, 3, 2, 1]
def arrow(d, fill, edge, scale, path):
    w, h = max(TRI), len(TRI)
    f = {(x, y) for y, n in enumerate(TRI) for x in range(n)}
    if d == "l": f = {(w - 1 - x, y) for x, y in f}
    W, H = w + 2, h + 2
    g = [[0] * W for _ in range(H)]
    for x, y in f: g[y + 1][x + 1] = 1
    for y in range(H):
        for x in range(W):
            if g[y][x] == 0 and any(0 <= x + dx < W and 0 <= y + dy < H and g[y + dy][x + dx] == 1
                                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1))):
                g[y][x] = 2
    im = Image.new("RGBA", (W * scale, H * scale), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(g):
        for x, v in enumerate(row):
            if v:
                c = fill if v == 1 else edge
                for yy in range(scale):
                    for xx in range(scale): px[x * scale + xx, y * scale + yy] = c + (255,)
    im.save(path)
os.makedirs(os.path.join(here, "..", "assets", "ui"), exist_ok=True)
arrow("l", (255, 247, 206), (41, 41, 41), 6, os.path.join(here, "..", "assets", "ui", "arr-l-fff7ce-292929.png"))
arrow("r", (255, 247, 206), (41, 41, 41), 6, os.path.join(here, "..", "assets", "ui", "arr-r-fff7ce-292929.png"))
AL, AR = "asset:ui/arr-l-fff7ce-292929.png", "asset:ui/arr-r-fff7ce-292929.png"

PAGES = [("folder", "Folder"), ("library", "Library"), ("megaman", "MegaMan"), ("email", "Email"), ("items", "Items"), ("network", "Network")]

def nav(i):
    prev, nxt = PAGES[(i - 1) % len(PAGES)], PAGES[(i + 1) % len(PAGES)]
    return box("nav", [
        button("nbtn nbtn-l", [{"navigate": prev[0]}], [box("arrrow", [img("nb arr arr-l", AL), text("nb", prev[1])])]),
        text("ntitle", PAGES[i][1]),
        button("nbtn nbtn-r", [{"navigate": nxt[0]}], [box("arrrow", [text("nb", nxt[1]), img("nb arr arr-r", AR)])])])

def head(title, count_label, count_expr, go=None):
    tab = (button("head-tab", [{"navigate": go}], [text("head-tab-t", count_label)]) if go
           else box("head-tab", [text("head-tab-t", count_label)]) if count_label else None)
    return box("head", [
        text("head-title", title),
        text("head-count", count_expr)] + ([tab] if tab else []) + [
        text("head-zenny", "{zenny}")])

# ---- folder ---------------------------------------------------------------------------------
folder_row = button("row", [{"set": {"slot": "{slot}"}}], [
    img("row-icon", "$icon"), text("row-name", "{name}"), box("row-dot", []), text("row-code", "{code}")],
    classIf={"sel": "$sel", "odd": "$odd"})

folder = box("page page-folder", [
    head("Folder", "sack", "30", go="library"),
    box("body", [
        box("card", [
            text("card-name", "{selChip.name}"),
            box("art-wrap", [img("art", "$selChip.art")]),
            box("card-bar", [text("card-code", "{selChip.code}"), box("card-dot", []),
                             text("card-atk", "{selChip.atkText}")]),
            box("desc", [text("desc-t", "{selChip.desc}")]),
            box("codes", [
                text("codes-l", "CODE"),
                lst("codes-list", "$selCodes", button("cpill", [{"call": "setCode", "args": ["{slot}", "{code}"]}],
                                                       [text("cpill-t", "{ch}")], classIf={"on": "$on"})) ])]),
        box("list-panel", [
            lst("rows", "$folder", folder_row)])]),
    nav(0)])

# ---- library --------------------------------------------------------------------------------
lib_row = button("row lrow", [{"set": {"lib": "{id}"}}], [
    text("lrow-no", "{no}"), text("row-name", "{name}"), text("lrow-own", "{ownedText}")],
    classIf={"sel": "$sel", "odd": "$odd"})

library = box("page page-library", [
    head("Library", "seen", "{libCount}"),
    box("body", [
        box("card", [
            text("card-name", "{libChip.name}"),
            box("art-wrap", [img("art", "$libChip.art")]),
            box("card-bar", [text("card-no", "No.{libChip.no}"), box("card-dot", []),
                             text("card-atk", "{libChip.atkText}")]),
            box("desc", [text("desc-t", "{libChip.desc}")]),
            box("codes", [text("codes-l", "CODES"), text("codes-v", "{libCodes}")]),
            box("owned", [text("owned-t", "In sack: {libChip.owned}")])]),
        box("list-panel", [lst("rows", "$library", lib_row)])]),
    nav(1)])

# ---- megaman --------------------------------------------------------------------------------
def stat_row():
    return box("stat", [
        text("stat-name", "{name}"),
        lst("pips", "$pips", button("pip", [{"call": "setStat", "args": ["{stat}", "{level}"]}], [],
                                    classIf={"on": "$on"}))])

megaman = box("page page-megaman", [
    box("mm-head", [text("mm-title", "MegaMan.exe"), text("mm-lv", "LV. {level}")]),
    box("mm-body", [
        box("mm-left", [
            box("plate hp-plate", [text("hp-l", "HP"), text("hp-v", "{hp}")]),
            box("plate zen-plate", [text("hp-l", "Zenny"), text("zen-v", "{zenny}")]),
            box("mm-hint", [text("hint-t", "Tap a pip to boost a feature, tap an armor to wear it.")])]),
        box("mm-right", [
            text("armor-l", "ARMOR"),
            lst("armors", "$armors", button("armor", [{"call": "setArmor", "args": ["{id}"]}],
                                             [box("armor-arrow", []), text("armor-t", "{name}")], classIf={"on": "$on"})),
            lst("stats", "$stats", stat_row())])]),
    nav(2)])

# ---- email ----------------------------------------------------------------------------------
mail_row = button("row mrow", [{"set": {"mail": "{id}", "mpage": "0"}}], [
    text("mrow-from", "{sender}"), text("mrow-sub", "{subject}")], classIf={"sel": "$sel", "odd": "$odd"})

email = box("page page-email", [
    head("Email", "", "{mailCount}"),
    box("body", [
        box("reader", [
            box("rd-bar", [text("rd-from", "{mail.sender}"), text("rd-sub", "{mail.subject}")]),
            box("rd-note", [text("rd-l", "{mail.l1}"), text("rd-l", "{mail.l2}"), text("rd-l", "{mail.l3}"), text("rd-l", "{mail.l4}"), box("rd-fill", []), img("rd-face", "asset:ui/mm-face.png")]),
            box("rd-pager", [
                button("rd-btn", [{"call": "mailStep", "args": [-1]}], [img("rd-arr arr arr-l", AL)], classIf={"off": "$mailFirst"}),
                text("rd-page", "{mail.pageText}"),
                button("rd-btn", [{"call": "mailStep", "args": [1]}], [img("rd-arr arr arr-r", AR)], classIf={"off": "$mailLast"})])]),
        box("list-panel", [lst("rows", "$mails", mail_row)])]),
    nav(3)])

# ---- items ----------------------------------------------------------------------------------
item_row = button("row irow", [{"set": {"item": "{id}"}}], [
    text("row-name", "{name}"), text("irow-n", "{countText}")], classIf={"sel": "$sel", "odd": "$odd"})

items = box("page page-items", [
    head("Items", "key", "{itemCount}"),
    box("body", [
        box("card", [
            text("card-name", "{item.name}"),
            box("it-kind", [text("it-kind-t", "{item.kind}"), text("it-count", "{item.countText}")]),
            box("desc it-desc", [text("desc-t", "{item.desc}")])]),
        box("list-panel", [lst("rows", "$items", item_row)])]),
    nav(4)])

# ---- network --------------------------------------------------------------------------------
net_row = button("row nrow", [{"set": {"net": "{i}"}}], [text("row-name", "{name}")], classIf={"sel": "$sel", "odd": "$odd"})

network = box("page page-network", [
    head("Network", "", ""),
    box("net-body", [
        box("net-top", [
            box("net-menu", [lst("net-rows", "$netRows", net_row)]),
            box("net-stats", [
                text("ns-l", "Chips:"), text("ns-v", "{chips}"),
                text("ns-l", "Battles"), box("ns-wl", [text("ns-w", "{wins}"), text("ns-sep", "W/"), text("ns-w", "{losses}")])])]),
        box("net-note", [img("net-face", "asset:ui/mm-face.png"), text("net-note-t", "{netNote}")])]),
    nav(5)])

waiting = box("waiting", [box("wait-card", [
    text("wait-title", "MEGA MAN"), text("wait-sub", "BATTLE NETWORK"), text("wait-line", "Load your save to jog Lan's PET")])],
    visibleIf="$waiting")

layout = box("", [waiting, {"type": "pages", "class": "stage", "visibleIf": "$ready", "state": "page", "initial": "folder",
    "pages": [{"name": n, "child": c} for n, c in (("folder", folder), ("library", library), ("megaman", megaman), ("email", email), ("items", items), ("network", network))]}], id="screen")
layout.pop("class")
json.dump(layout, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
print("ok")
