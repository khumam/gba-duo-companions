#!/usr/bin/env python3
"""Writes layout.json for the Advance Wars companion 0.3.0 (design: .idea/plans/aw-design2 in the app repo, aw-*.png).
The game's own intel screens, re-laid for touch:
  * peach paper windows with lighter row bands, an ink border on a grey-green bevel, the caption on the top edge (BATTLE INTEL, UNIT ...),
  * the game's map menu (icon + word, the white glove) as the page nav on the right edge, the DAY plate under it on every page,
  * INTEL = Battle Intel (one row per army) + Deployment (tug-of-war bars), UNIT = the Unit table + a unit dossier with yellow damage
    bars, TERRAIN = the terrain tiles + the field's dark info panel, MAP = the live minimap + one row per army.
The 0.2 source is in art/v2/.   python3 art/layout.py && python3 ../skill/tools/packkit/css.py ."""
import json, os
here = os.path.dirname(os.path.abspath(__file__))


def box(cls, ch=(), **kw):      return {"type": "box", "class": cls, "children": list(ch), **kw}
def text(cls, t, **kw):         return {"type": "text", "class": cls, "text": t, **kw}
def img(cls, src, **kw):        return {"type": "image", "class": cls, "src": src, **kw}
def button(cls, on, ch, **kw):  return {"type": "button", "class": cls, "onClick": on, "children": list(ch), **kw}
def lst(cls, items, tpl, **kw): return {"type": "list", "class": cls, "items": items, "template": tpl, **kw}


grow = lambda: box("grow")
GLOVE = "asset:ui/hand.png"
COIN = "asset:icons/ui/coin.png"


def window(cls, cap, kids, **kw):
    """the game's window: paper inside an ink line on a grey-green bevel, its caption on the top edge"""
    return box("win " + cls, [box("cap", [text("cap-t", cap)]) if cap else box("cap-none"), box("win-in", kids)], **kw)


# ---- INTEL --------------------------------------------------------------------------------------------------------------------------------
army = lambda who: box("arow", [
    box("glove-w", [img("glove", GLOVE, visibleIf="$%s.turn" % who)]),
    img("emblem", "$%s.crate" % who),
    text("aname", "{%s.name}" % who), grow(),
    text("anum", "{%s.n}" % who), text("anum wide", "{%s.valueTxt}" % who), text("anum", "{%s.p}" % who),
], classIf={"turn": "$%s.turn" % who})
intel = box("page", [
    window("bintel", "BATTLE INTEL", [
        box("thead", [grow(), box("th", [img("th-ic", "asset:icons/ui/units.png")]), box("th wide", [img("th-ic", COIN)]), box("th", [img("th-ic", "asset:terrain/city.png")])]),
        box("rule"),
        army("chipL"), army("chipR"),
    ]),
    window("deploy grow", "DEPLOYMENT", [
        lst("bars", "$bars", box("tug", [
            img("tug-ic", "$icon"),
            text("tug-n", "{a}"),
            box("track", [box("tug-a", [], bindStyle={"width": "{aw}"}), box("tug-b")]),
            text("tug-n foe", "{b}"),
        ])),
    ]),
])

# ---- UNIT: the table (two columns) and the dossier of the picked unit ------------------------------------------------------------------
units = box("page", [
    window("utable", "UNIT", [
        box("thead", [img("th-ic", "asset:icons/ui/type.png"), grow(), img("th-ic", COIN), grow(), img("th-ic", "asset:icons/ui/units.png")]),
        box("rule"),
        lst("ulist", "$tiles", button("urow", [{"set": {"type": "{id}"}}], [
            box("glove-w", [img("glove", GLOVE, visibleIf="$on")]),
            img("u-ic", "$icon"),
            box("u-t", [text("u-name", "{name}"), text("u-cost", "{cost}", classIf={"poor": "$poor"})]),
            text("u-own", "{ownedTxt}", visibleIf="$hasOwned"),
        ], classIf={"on": "$on"})),
    ]),
    window("dossier grow", "UNIT DOSSIER", [
        box("dtop", [
            box("dwell", [img("d-big", "$pickIcon")]),
            box("dhead", [
                box("dname-row", [text("d-name", "{pickName}"), grow(), img("d-coin", COIN), text("d-cost", "{pickCost}", classIf={"poor": "$pickPoor"})]),
                box("dstats", [box("ds", [text("ds-l", "Move"), text("ds-v", "{pickMove}")]), box("ds", [text("ds-l", "Vision"), text("ds-v", "{pickVision}")]),
                               box("ds", [text("ds-l", "Fuel"), text("ds-v", "{pickFuel}")]), box("ds", [text("ds-l", "Ammo"), text("ds-v", "{pickAmmo}")]),
                               box("ds", [text("ds-l", "Range"), text("ds-v", "{pickRange}")])]),
            ]),
        ]),
        box("rule"),
        lst("dmg", "$dmg", box("drow", [img("dm-ic", "$icon"), box("dtrack", [box("dfill", [], bindStyle={"width": "{w}"}, classIf={"best": "$best"})]),
                                        text("dm-n", "{txt}", classIf={"none": "$none"})])),
    ]),
])

# ---- TERRAIN: the tiles, and the field's dark info panel for the picked one ---------------------------------------------------------------
terrain = box("page", [
    window("tgrid", "TERRAIN INTEL", [
        lst("tiles", "$terr", button("ttile", [{"set": {"terr": "{id}"}}], [img("t-img", "$img")], classIf={"on": "$on"})),
    ]),
    box("panel grow", [
        box("ptop", [img("p-tile", "$terrImg"), box("p-t", [text("p-name", "{terrName}"),
                                                            box("p-def", [img("p-defl", "asset:game/def.png"), lst("starrow", "$stars", img("star", "$src")),
                                                                          text("p-defn", "{defN}")])])]),
        box("prule"),
        text("p-lab", "Move cost"),
        lst("costs", "$costs", box("cost", [img("c-ic", "$icon"), text("c-n", "{txt}")], classIf={"blocked": "$blocked"})),
    ]),
])

# ---- MAP: the live minimap and one row per army -----------------------------------------------------------------------------------------
mapnode = box("mapwrap", [
    img("mapbg", "$mapImg"),
    lst("mprops", "$mapProps", box("mp", [], bindStyle={"left": "{left}", "top": "{top}", "width": "{size}", "height": "{size}", "background-color": "{color}"}, classIf={"hq": "$hq"})),
    lst("munits", "$mapUnits", box("mu", [img("mui", "$icon")], bindStyle={"left": "{left}", "top": "{top}", "width": "{size}", "height": "{sizeH}"})),
    box("view", [], bindStyle={"left": "{view.left}", "top": "{view.top}", "width": "{view.width}", "height": "{view.height}"}, visibleIf="$hasView"),
], bindStyle={"width": "{mapW}", "height": "{mapH}"}, visibleIf="$hasMap")
mrow = lambda who: box("mrow", [img("emblem", "$%s.crate" % who), img("m-ic", "$%s.icon" % who), text("m-n", "{%s.n}" % who),
                                img("m-ic", "asset:terrain/city.png"), text("m-n", "{%s.p}" % who)], classIf={"turn": "$%s.turn" % who})
map_ = box("page", [
    # pinch / drag the map, or the - / + keys on its corner (app 1.0.3+; older apps show it at 1x)
    window("mapwin grow", "MAP", [box("mapzw", [
        box("mapwell", [mapnode, text("nomap", "Open the map screen in the game.", visibleIf="$noMap")], zoom={"min": 1, "max": 4, "state": "mapZoom"}),
        box("zoom-ctl", [button("zoom-key", {"zoom": "out", "state": "mapZoom"}, [text("zoom-key-t", "-")]),
                         button("zoom-key", {"zoom": "in", "state": "mapZoom"}, [text("zoom-key-t", "+")])], visibleIf="$hasMap")])]),
    box("mrows", [mrow("chipL"), mrow("chipR")]),
])

# ---- shell: the map menu (nav) and the DAY plate ----------------------------------------------------------------------------------------
NAV = [("field", "Intel", "asset:icons/ui/menu-intel-c.png", "onField"), ("units", "Unit", "asset:icons/ui/menu-unit-c.png", "onUnits"),
       ("terrain", "Terrain", "asset:terrain/mountain.png", "onTerrain"), ("map", "Map", "asset:ui/tab-map.png", "onMap")]
navrow = lambda p, label, src, flag: button("nrow", [{"navigate": p}], [box("nglove-w", [img("glove", GLOVE, visibleIf="$" + flag)]),
                                                                       img("n-ic n-" + p, src), text("n-t", label)], classIf={"on": "$" + flag})
side = box("side", [
    window("menu", "MENU", [*[navrow(*n) for n in NAV]]),
    window("day grow", None, [
        box("day-top", [img("emblem", "$crate"), text("day-l", "Day"), grow(), text("day-n", "{day}")]),
        box("rule"),
        grow(),
        box("day-funds", [img("d-coin", COIN), grow(), text("funds", "{funds}")]),
        text("income", "+{income} / day", visibleIf="$hasIncome"),
    ]),
])

pages = [("field", intel), ("units", units), ("terrain", terrain), ("map", map_)]
layout = box("main", [
    box("waiting", [box("wait", [text("w1", "ADVANCE WARS"), text("w2", "Load a battle to begin."), text("w3", "The intel appears when a day is under way.")])],
        visibleIf="$waiting"),
    box("ready", [
        box("stage-w", [{"type": "pages", "class": "stage", "state": "page", "initial": "field", "pages": [{"name": n, "child": c} for n, c in pages]}]),
        side,
    ], visibleIf="$ready"),
], id="screen", bindStyle={"--acc": "{accent}", "--pill": "{pill}", "--foe": "{foeAcc}"})
json.dump(layout, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
print("ok")
