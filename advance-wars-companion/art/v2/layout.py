#!/usr/bin/env python3
"""Writes layout.json for the Advance Wars companion (design: .idea/plans/aw-design in the app repo).
A peach folder on a slate table; four icon-only tabs on the right edge (FIELD, UNITS, TERRAIN, MAP); the accent is the army whose turn it is.
    python3 art/layout.py"""
import json, os
here = os.path.dirname(os.path.abspath(__file__))


def box(cls, ch=(), **kw):      return {"type": "box", "class": cls, "children": list(ch), **kw}
def text(cls, t, **kw):         return {"type": "text", "class": cls, "text": t, **kw}
def img(cls, src, **kw):        return {"type": "image", "class": cls, "src": src, **kw}
def button(cls, on, ch, **kw):  return {"type": "button", "class": cls, "onClick": on, "children": list(ch), **kw}
def lst(cls, items, tpl, **kw): return {"type": "list", "class": cls, "items": items, "template": tpl, **kw}


# ---- FIELD: the DAY plate, the funds, three tug-of-war bars (my army left, the other right) ----------------------------------------------
field = box("page", [
    box("plate", [
        box("plate-crate", [img("crate", "$crate")]),
        box("plate-body", [
            box("pill", [text("pill-day", "DAY"), box("grow"), text("pill-num", "{day}")]),
            box("nameplate", [text("name", "{turnName}")]),
        ]),
    ]),
    box("well funds", [
        img("coin", "asset:icons/ui/coin.png"),
        text("funds-num", "{funds}"),
        box("grow"),
        box("income", [img("house", "asset:terrain/city.png"), text("income-n", "+{income}")], visibleIf="$hasIncome"),
    ]),
    lst("bars", "$bars", box("well tug", [
        box("tug-a", [text("tug-n", "{a}")], bindStyle={"width": "{aw}"}),
        box("tug-b", [box("chip", [img("chip-ic", "$icon")]), box("grow"), text("tug-n", "{b}")]),
    ])),
])

# ---- UNITS: 5 x 4 sprite grid, the inspector below is the game's dark info panel ----------------------------------------------------------
units = box("page", [
    lst("grid", "$tiles", button("tile", [{"set": {"type": "{id}"}}], [
        img("tile-ic", "$icon"),
        text("own", "{owned}", visibleIf="$hasOwned"),
        box("dot", [], visibleIf="$afford"),
    ], classIf={"on": "$on", "poor": "$poor"})),
    box("info", [
        box("info-l", [
            text("info-name", "{pickName}"),
            box("info-sprite", [img("big", "$pickIcon")]),
            box("info-cost", [img("coin-s", "asset:icons/ui/coin.png"), text("cost-n", "{pickCost}")], classIf={"poor": "$pickPoor"}),
        ]),
        lst("dmg", "$dmg", box("drow", [
            img("d-ic", "$icon"),
            box("track", [box("fill", [], bindStyle={"width": "{w}"}, classIf={"best": "$best"})]),
            text("d-n", "{txt}", classIf={"none": "$none"}),
        ])),
    ]),
])

# ---- TERRAIN: tile grid; the inspector shows DEF stars and what each kind of unit pays to enter ------------------------------------------
terrain = box("page", [
    lst("grid t", "$terr", button("tile t", [{"set": {"terr": "{id}"}}], [img("tile-img", "$img")], classIf={"on": "$on"})),
    box("info col", [
        box("info-top", [
            img("big-tile", "$terrImg"),
            box("info-tname", [text("info-name", "{terrName}"),
                               box("stars", [img("def-ic", "asset:game/def.png"), text("def-n", "{defN}")])]),
        ]),
        lst("costs", "$costs", box("cost", [img("c-ic", "$icon"), text("c-n", "{txt}", classIf={"blocked": "$blocked"})], classIf={"blocked": "$blocked"})),
    ]),
])

# ---- MAP: the minimap, the box the top screen shows, and four chips ----------------------------------------------------------------------
mapnode = box("mapwrap", [
    img("mapbg", "$mapImg"),
    lst("mprops", "$mapProps", box("mp", [], bindStyle={"left": "{left}", "top": "{top}", "width": "{size}", "height": "{size}", "background-color": "{color}"}, classIf={"hq": "$hq"})),
    lst("munits", "$mapUnits", box("mu", [img("mui", "$icon")], bindStyle={"left": "{left}", "top": "{top}", "width": "{size}", "height": "{sizeH}"})),
    box("view", [], bindStyle={"left": "{view.left}", "top": "{view.top}", "width": "{view.width}", "height": "{view.height}"}, visibleIf="$hasView"),
], bindStyle={"width": "{mapW}", "height": "{mapH}"}, visibleIf="$hasMap")
chip = lambda who, icon, num: box("mchip", [box("mstripe", [], bindStyle={"background-color": "{%s.color}" % who}), img("mchip-ic", "$%s.%s" % (who, icon)), text("mchip-n", "{%s.%s}" % (who, num))])
map_ = box("page", [
    box("well mapwell", [mapnode, text("nomap", "Open the map screen in the game", visibleIf="$noMap")]),
    box("chips", [chip("chipL", "icon", "n"), chip("chipR", "icon", "n"), chip("chipL", "crate", "p"), chip("chipR", "crate", "p")]),
])

pages = [("field", field), ("units", units), ("terrain", terrain), ("map", map_)]
tab = lambda name, icon, flag: button("tab", [{"navigate": name}], [img("tab-ic " + name, icon)], classIf={"on": "$" + flag})
layout = box("main", [
    box("waiting", [box("wait", [text("w1", "ADVANCE WARS"), text("w2", "Load a battle to begin"), text("w3", "the field report appears when a day is under way")])], visibleIf="$waiting"),
    box("ready", [
        box("folder", [{"type": "pages", "class": "stage", "state": "page", "initial": "field", "pages": [{"name": n, "child": c} for n, c in pages]}]),
        box("dock", [tab("field", "$crate", "onField"), tab("units", "asset:icons/units/tank-orange.png", "onUnits"),
                     tab("terrain", "asset:terrain/mountain.png", "onTerrain"), tab("map", "asset:ui/tab-map.png", "onMap")]),
    ], visibleIf="$ready"),
], id="screen", bindStyle={"--acc": "{accent}", "--pill": "{pill}", "--foe": "{foeAcc}"})
json.dump(layout, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
print("ok")
