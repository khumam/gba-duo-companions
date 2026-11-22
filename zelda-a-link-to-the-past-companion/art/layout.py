#!/usr/bin/env python3
"""Writes layout.json: A Link to the Past's item screen (Items), Link's status and the dungeons, joined by left /
right plates. Edit here, not layout.json:   python3 art/layout.py
"""
import json
import os


def box(cls, ch=(), **kw): return {"type": "box", "class": cls, "children": list(ch), **kw}
def text(cls, t, **kw): return {"type": "text", "class": cls, "text": t, **kw}
def img(cls, src, **kw): return {"type": "image", "class": cls, "src": src, **kw}
def button(cls, on, ch, **kw): return {"type": "button", "class": cls, "onClick": on, "children": list(ch), **kw}
def lst(cls, items, tpl, **kw): return {"type": "list", "class": cls, "items": items, "template": tpl, **kw}
def bar(cls, value, mx, **kw): return {"type": "bar", "class": cls, "value": value, "maxKey": mx, **kw}


PAGES = [("items", "Items"), ("status", "Status"), ("dungeons", "Dungeons"), ("map", "Map")]


def nav(i):
    prev, nxt = PAGES[(i - 1) % len(PAGES)], PAGES[(i + 1) % len(PAGES)]
    return [
        button("nbtn nbtn-l", [{"navigate": prev[0]}], [img("nplate", "asset:ui/nav-l.png"), text("nb nb-l", prev[1].upper())]),
        box("nmid", [img("nplate-m", "asset:ui/nav-mid.png"), text("ntitle", PAGES[i][1].upper()),
                     box("pips", [box("pip" + (" on" if k == i else ""), []) for k in range(len(PAGES))])]),
        button("nbtn nbtn-r", [{"navigate": nxt[0]}], [img("nplate", "asset:ui/nav-r.png"), text("nb nb-r", nxt[1].upper())]),
    ]


def panel(cls, label, color):
    return [box(f"panel {cls} {color}", []), text(f"plabel {cls}-l", label)]


def page(name, children, i):
    return box(f"page page-{name}", children + nav(i))


items = page("items", [
    *panel("p-item", "ITEM", "green"), text("letter letter-a", "A"),
    lst("grid", "$grid", button("cell", [{"set": {"cell": "{k}"}}],
                                [box("bracket", [], visibleIf="$sel"), img("cicon", "$img", visibleIf="$have"), text("ccount", "{count}")],
                                classIf={"sel": "$sel"})),
    *panel("p-sel", "", "green"), img("sel-i", "$sel.img", visibleIf="$sel.has"), text("sel-n", "{sel.name}"),
    *panel("p-pend", "PENDANTS", "yellow"),
    img("pend pend-0", "$pend0"), img("pend pend-1", "$pend1"), img("pend pend-2", "$pend2"),
    text("cry-n", "CRYSTALS {crystalCount}", visibleIf="$anyCrystal"),
    *panel("p-do", "DO", "red"), text("letter letter-r", "R"),
    text("do-w do-1", "TALK"), text("do-w do-2", "READ"), text("do-w do-3", "PULL"), text("do-w do-4", "{lift}"),
    lst("dorow", "$doRow", button("dcell", [{"set": {"cell": "{cell}"}}],
                                 [img("dicon", "$img", visibleIf="$have")], classIf={"none": "$none"})),
    *panel("p-eq", "EQUIPMENT", "yellow"),
    img("eqi eq-sw", "$eq.sword", visibleIf="$eq.hasSword"), img("eqi eq-sh", "$eq.shield", visibleIf="$eq.hasShield"), img("eqi eq-ml", "$eq.mail"),
    box("eq-dots", []), img("eq-piece", "$eq.pieceImg"), text("eq-cont", "x{st.containers}"),
    box("info", [text("info-n", "{sel.name}"), text("info-t", "{sel.what}")]),
], 0)

status = page("status", [
    *panel("p-life", "LIFE", "red"),
    lst("hearts", "$st.hearts", img("heart", "$img")), text("st-hp", "{st.hpText}"),
    *panel("p-magic", "MAGIC", "green"), bar("mbar", "$st.magic", "$st.magicMax"), text("st-mp", "{st.magicText}"), text("st-mu", "{st.magicUse}"),
    *panel("p-bag", "CARRY", "yellow"),
    img("ci ci-1", "asset:icons/bombs.png"), text("cl cl-1", "BOMBS"), text("cv cv-1", "{st.bombs} / {st.bombsMax}"),
    img("ci ci-2", "asset:icons/bow-2.png"), text("cl cl-2", "ARROWS"), text("cv cv-2", "{st.arrows} / {st.arrowsMax}"),
    box("rupee ci-3", []), text("cl cl-3", "RUPEES"), text("cv cv-3", "{st.rupees}"),
    img("ci ci-4", "asset:ui/piece-3.png"), text("cl cl-4", "HEART PIECES"), text("cv cv-4", "{st.pieces}"),
    text("cl cl-5", "KEYS HERE"), text("cv cv-5", "{st.keys}"),
    *panel("p-gear", "EQUIPMENT", "yellow"),
    img("gi gi-1", "$eq.sword", visibleIf="$eq.hasSword"), text("gn gn-1", "{eq.swordName}"),
    img("gi gi-2", "$eq.shield", visibleIf="$eq.hasShield"), text("gn gn-2", "{eq.shieldName}"),
    img("gi gi-3", "$eq.mail"), text("gn gn-3", "{eq.mailName}"),
], 1)

dungeons = page("dungeons", [
    *panel("p-dun", "DUNGEONS", "green"),
    text("dh dh-m", "MAP"), text("dh dh-c", "COMP"), text("dh dh-k", "KEY"),
    lst("dlist", "$dungeons", box("drow", [
        text("dname", "{name}"),
        img("dm", "asset:ui/map.png", visibleIf="$map"), img("dm", "asset:ui/map-off.png", visibleIf="$noMap"),
        img("dc", "asset:ui/compass.png", visibleIf="$comp"), img("dc", "asset:ui/compass-off.png", visibleIf="$noComp"),
        img("dk", "asset:ui/bigkey.png", visibleIf="$key"), img("dk", "asset:ui/bigkey-off.png", visibleIf="$noKey"),
        img("dr", "$reward", visibleIf="$hasReward"),
    ], classIf={"dark": "$dark", "done": "$done"})),
    text("dtally", "{dungeonTally}"),
], 2)

world = page("map", [
    *panel("p-map", "LIGHT WORLD", "green"),
    box("mapwin", [img("mapimg", "asset:map/light-world.png"),
                   img("marker", "asset:ui/marker.png", bindStyle={"left": "{map.x}", "top": "{map.y}"}, visibleIf="$map.known")]),
    text("map-where", "{map.where}"),
], 3)

waiting = box("page page-waiting", [
    text("w-1", "A LINK TO THE PAST"), text("w-2", "COMPANION"),
    text("w-3", "Load a file to see Link's items."),
    text("w-4", "This pack reads the USA cartridge (AZLE).", visibleIf="$wrongRom"),
])

body = [("items", items), ("status", status), ("dungeons", dungeons), ("map", world)]
root = box("main", [
    box("waiting", [waiting], visibleIf="$waiting"),
    box("ready", [{"type": "pages", "class": "stage", "initial": "items", "pages": [{"name": n, "child": c} for n, c in body]}], visibleIf="$ready"),
], id="screen")

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    json.dump(root, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
    print("ok", len(json.dumps(root)))
