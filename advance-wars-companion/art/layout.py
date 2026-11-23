#!/usr/bin/env python3
"""Writes layout.json for the Advance Wars companion: the game's own colours (purple sea, cream paper, red-orange bands) with a simpler layout,
each page is a title band over ONE paper panel (plain rows, a master / detail split) instead of many boxed cards.
The data bindings, actions and the movable navigation (dock / bar) are the original ones (art/orig/layout.json).
    python3 art/layout.py"""
import json, os
from PIL import Image

here = os.path.dirname(os.path.abspath(__file__))
orig = json.load(open(os.path.join(here, "orig", "layout.json")))


def box(cls, ch=(), **kw):      return {"type": "box", "class": cls, "children": list(ch), **kw}
def text(cls, t, **kw):         return {"type": "text", "class": cls, "text": t, **kw}
def img(cls, src, **kw):        return {"type": "image", "class": cls, "src": src, **kw}
def button(cls, on, ch, **kw):  return {"type": "button", "class": cls, "onClick": on, "children": list(ch), **kw}
def lst(cls, items, tpl, **kw): return {"type": "list", "class": cls, "items": items, "template": tpl, **kw}
def bar(cls, v, **kw):          return {"type": "bar", "class": cls, "value": v, "max": 1, **kw}


# ---- arrow icons (a typed < > is not an icon): a 4 x 7 pixel triangle with a 1 px outline, cream with an ink edge ---------------
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
for d in "lr":
    arrow(d, (255, 231, 231), (16, 8, 8), 6, os.path.join(here, "..", "assets", "ui", "arr-%s.png" % d))
    arrow(d, (132, 0, 16), (255, 231, 198), 6, os.path.join(here, "..", "assets", "ui", "arr-%s-dark.png" % d))
AL, AR, ALD = "asset:ui/arr-l.png", "asset:ui/arr-r.png", "asset:ui/arr-l-dark.png"


def head(title, right=None, extra=()):
    return box("head", [*extra, text("title", title), box("grow", []), *([text("hnote", right)] if right else [])])

def panel(cls, ch): return box("panel " + cls, ch)


# ---- home: the front --------------------------------------------------------------------------------------------------------------
home = box("page", [
    box("strip", [box("stat", [text("lab", "DAY"), text("val", "{day}")]),
                  box("stat grow", [text("lab", "TURN"), text("val", "{turnName}", bindStyle={"color": "{turnColor}"})]),
                  box("stat", [text("lab", "FUNDS"), text("val", "{funds}")])]),
    panel("fill", [
        lst("armies", "$armies", button("army", [{"set": {"army": "{n}"}}, {"navigate": "units"}], [
            box("flag", [], bindStyle={"background-color": "{color}"}),
            box("army-body", [text("army-name", "{name}"), text("army-sub", "{count} units     value {value}")]),
            text("turn-mark", "TURN", visibleIf="$mine"), img("go", ARD := "asset:ui/arr-r-dark.png")], classIf={"on": "$on"})),
        text("sub", "{sel.name}: unit types"),
        box("scroll", [lst("groups", "$groups", box("grp", [img("grp-ic", "$icon"), text("grp-n", "x{n}")]))]),
    ]),
])

# ---- units: a plain list ----------------------------------------------------------------------------------------------------------
units = box("page", [
    lst("tabs", "$armies", button("tabbtn", [{"set": {"army": "{n}"}}], [box("dot", [], bindStyle={"background-color": "{color}"}), text("tabt", "{name}")], classIf={"on": "$on"})),
    panel("fill", [
        box("cols", [text("c1", "UNIT"), box("grow", []), text("c2", "HP"), text("c3", "FUEL"), text("c4", "AT")]),
        lst("rows", "$units", button("row", [{"set": {"unit": "{n}"}}, {"navigate": "unit"}], [
            img("row-ic", "$icon"), text("row-name", "{name}"),
            box("meter", [text("meter-n", "{tens}"), bar("hp hpbar", "$hpPct")], classIf={"low": "$low"}),
            text("row-fuel", "{fuel}"), text("row-pos", "{x},{y}")])),
    ]),
])

# ---- unit -------------------------------------------------------------------------------------------------------------------------
cell = lambda label, value: box("cell", [text("lab", label), text("cell-v", value)])
unit = box("page", [
    head("{focus.name}", "at {focus.x},{focus.y}", extra=[button("back", [{"navigate": "units"}], [img("back-ic", AL), text("back-t", "Units")]), img("uic", "$focus.icon")]),
    panel("fill", [
        box("mrow", [text("lab w", "HP"), bar("hp hpbar big", "$focus.hpPct"), text("mval", "{focus.tens}")], classIf={"low": "$focus.low"}),
        box("mrow", [text("lab w", "FUEL"), bar("fuel fuelbar big", "$focus.fuelPct"), text("mval", "{focus.fuel} / {focus.maxFuel}")]),
        box("cells", [cell("MOVE", "{focus.move}"), cell("VISION", "{focus.vision}"), cell("RANGE", "{focus.range}"),
                      cell("AMMO", "{focus.ammo}"), cell("COST", "{focus.cost}"), cell("WORTH NOW", "{focus.worth}0")]),
    ]),
])

# ---- guide: list (master) and the picked unit (detail) -----------------------------------------------------------------------------
drow = lambda label, v: box("drow", [text("lab", label), box("grow", []), text("dval", v)])
guide = box("page", [
    head("Unit guide", "{gsel.name}"),
    box("split", [
        panel("list", [lst("rows", "$guide", button("row", [{"set": {"type": "{id}"}}], [
            img("row-ic", "$icon"), text("row-name", "{name}"), text("row-own", "x{owned}", visibleIf="$hasOwned"), text("row-cost", "{cost}")],
            classIf={"on": "$on", "can": "$afford"}))]),
        panel("detail", [
            box("dhead", [img("big-ic", "$gsel.icon"), box("dtitle", [text("dname", "{gsel.name}"), text("sub", "own {gsel.owned}")])]),
            drow("COST", "{gsel.cost}"), drow("MOVE", "{gsel.move}"), drow("VISION", "{gsel.vision}"),
            drow("RANGE", "{gsel.range}"), drow("AMMO", "{gsel.ammo}"), drow("FUEL", "{gsel.fuel}"),
            text("hint wrap", "{buyText}")]),
    ]),
])

# ---- map ---------------------------------------------------------------------------------------------------------------------------
mapnode = box("mapwrap", [
    img("mapbg", "$mapImg"),
    lst("mprops", "$mapProps", box("mp", [], bindStyle={"left": "{left}", "top": "{top}", "width": "{size}", "height": "{size}", "background-color": "{color}"}, classIf={"hq": "$hq"})),
    lst("munits", "$mapUnits", box("mu", [img("mui", "$icon")], bindStyle={"left": "{left}", "top": "{top}", "width": "{size}", "height": "{sizeH}"})),
], bindStyle={"width": "{mapW}", "height": "{mapH}"}, visibleIf="$hasMap")
map_ = box("page", [
    head("Map", "{mapNote}"),
    box("scroll", [
        box("mapbox", [mapnode, text("onsea wrap", "Open the map screen in the game to see it here.", visibleIf="$noMap")]),
        box("legend", [box("leg", [box("dot", [], bindStyle={"background-color": "{vsL.color}"}), text("legt", "{vsL.name}")]),
                       box("leg", [box("dot", [], bindStyle={"background-color": "{vsR.color}"}), text("legt", "{vsR.name}")])]),
    ]),
])

# ---- armies (versus) -------------------------------------------------------------------------------------------------------------
armies = box("page", [
    head("Armies", "day {day}"),
    panel("fill", [
        box("vshead", [box("vside", [box("dot", [], bindStyle={"background-color": "{vsL.color}"}), text("vname", "{vsL.name}")]),
                       box("vside r", [text("vname", "{vsR.name}"), box("dot", [], bindStyle={"background-color": "{vsR.color}"})])]),
        lst("rows", "$versus", box("vrow", [text("va", "{a}", classIf={"win": "$aWin"}), text("vl", "{label}"), text("vb", "{b}", classIf={"win": "$bWin"})])),
    ]),
])

# ---- log ---------------------------------------------------------------------------------------------------------------------------
log = box("page", [
    head("Log", "kept while the game runs"),
    panel("fill", [lst("rows", "$log", box("lrow", [text("ld", "Day {day}"), text("ll", "{line}"), text("lf", "{funds}")]))]),
])

# ---- options: where the navigation sits ------------------------------------------------------------------------------------------
opt = lambda label, hint, key, flag: button("choice", [{"set": {"navpos": key}}], [box("radio", []), box("ctext", [text("cname", label), text("hint", hint)])], classIf={"on": "$" + flag})
options = box("page", [
    head("Options", "where the page buttons sit"),
    panel("fill", [
        box("choices", [opt("Bottom", "A bar under the page", "bottom", "posBottom"), opt("Left", "A dock beside the page", "left", "posLeft"),
                        opt("Right", "A dock on the right", "right", "posRight"), opt("Split", "Half on each side", "split", "posSplit")]),
        text("hint wrap", "Side docks scroll when there are many pages. The bottom bar shows 5 buttons; use the arrows for the rest. Kept until the game is closed."),
    ]),
])

new_pages = {"home": home, "units": units, "unit": unit, "guide": guide, "map": map_, "armies": armies, "log": log, "options": options}

layout = json.loads(json.dumps(orig))
def walk(n):
    if isinstance(n, dict):
        if n.get("type") == "pages":
            n["pages"] = [{"name": p["name"], "child": new_pages[p["name"]]} for p in n["pages"]]
            return
        # the typed < > on the bottom bar's paging buttons become arrow icons
        if n.get("class") == "nav":
            pages = [b["onClick"][0]["navigate"] for b in n["children"] if b.get("class") == "nbtn"]
            cyc = lambda arrow, flag, cls: [button("narrow " + cls, [{"navigate": pg}], [img("nt-ic", arrow)], visibleIf="$%s%d" % (flag, i + 1)) for i, pg in enumerate(pages)]
            n["children"] = cyc(AL, "P", "cprev") + [box("ncur", [text("nt", "{navName}")])] + cyc(AR, "N", "cnext")
            return
        for v in n.values(): walk(v)
    elif isinstance(n, list):
        for x in n: walk(x)
walk(layout)
json.dump(layout, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
print("ok")
