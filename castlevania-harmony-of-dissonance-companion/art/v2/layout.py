#!/usr/bin/env python3
"""Writes layout.json for the Harmony of Dissonance companion 0.2.0 (design: .idea/plans/hod-design in the app repo).
Green-plaque tabs on the left (STATUS, EQUIP, ITEMS, BOOK, RELICS, MAP), the game's INFORMATION bar as the inspector, relics as an icon grid.
Juste's portrait and the five spell book emblems are the game's own (cut from its Status screen).
    python3 art/layout.py"""
import json, os, sys
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import v1_layout as v1


def box(cls, ch=(), **kw):      return {"type": "box", "class": cls, "children": list(ch), **kw}
def text(cls, t, **kw):         return {"type": "text", "class": cls, "text": t, **kw}
def img(cls, src, **kw):        return {"type": "image", "class": cls, "src": src, **kw}
def button(cls, on, ch, **kw):  return {"type": "button", "class": cls, "onClick": on, "children": list(ch), **kw}
def lst(cls, items, tpl, **kw): return {"type": "list", "class": cls, "items": items, "template": tpl, **kw}
def bar(cls, v, mx, **kw):      return {"type": "bar", "class": cls, "value": v, "maxKey": mx, **kw}


def title(t, extra=()):
    return box("ptitle", [box("title", [img("tplate", "asset:ui/title.png"), text("ttext", t)]), box("grow"), *extra])


def pg(name, kids): return box(f"npg npg-{name}", kids)


def act(label, on, can, done_label, done):
    return [button("nbtn", on, [text("nbtn-t", label)], visibleIf=can), box("nbtn nbtn-done", [text("nbtn-t", done_label)], visibleIf=done)]


def information(pic, name, desc, extra=None, btn=()):
    return box("ninfo", [text("ninfo-tag", "INFORMATION"),
                         box("ninfo-top", [pic, box("ninfo-t", [text("ninfo-name", name), text("ninfo-desc", desc), *([text("ninfo-extra", extra)] if extra else [])])]),
                         box("ninfo-foot", [text("ninfo-note", "{note}"), box("grow"), *btn])])


barrow = lambda lab, cls, b, v: box("nbarrow", [text("nlab " + cls, lab), b, text("nnum", v)])
stat = lambda lab, key: box("nstat", [text("nlab", lab), text("nval", "{st.%s}" % key)])

# ---- STATUS ---------------------------------------------------------------------------------------------------------------------------------
status = pg("status", [
    title("Juste Belmont", [button("nmini", [{"navigate": "config"}], [text("nmini-t", "KEYS")])]),
    box("nwin nhero", [
        img("nport", "asset:game/portrait-juste.png"),
        box("nhero-r", [
            box("namerow", [text("nlab", "LEVEL"), text("nlv", "{st.level}"), box("grow"),
                            button("nbook", [{"navigate": "book"}], [img("nbook-img", "$bookNow.img")])]),
            barrow("HP", "hp-l", bar("hpbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"}), "{st.hpText}"),
            barrow("MP", "mp-l", bar("mpbar", "$st.mp", "$st.maxMp"), "{st.mpText}"),
            barrow("HEART", "ht-l", bar("htbar", "$st.heart", "$st.maxHeart"), "{st.heartText}"),
            box("healrow", [text("nheal", "{heal.name}"), box("grow"),
                            button("nbtn nbtn-s", [{"call": "quickHeal", "args": ["{heal.id}"]}], [text("nbtn-t", "HEAL")], visibleIf="$heal.can"),
                            box("nbtn nbtn-s nbtn-done", [text("nbtn-t", "HEAL")], visibleIf="$heal.off")]),
        ]),
    ]),
    box("nrow4", [stat("STR", "str"), stat("DEF", "def"), stat("INT", "int"), stat("LCK", "lck")]),
    box("nwin expw", [box("expl", [text("nlab", "EXP"), text("nnum", "{st.exp}")]), bar("expbar", "$st.expIn", "$st.expSpan"), box("expl r", [text("nlab", "NEXT"), text("nnext", "{st.next}")])]),
    box("nrow3", [box("nchip", [text("nlab", "GOLD"), text("nchip-v gold", "{st.gold}")]), box("nchip", [text("nlab", "TIME"), text("nchip-v", "{st.time}")])]),
])

# ---- EQUIP ----------------------------------------------------------------------------------------------------------------------------------
equip = pg("equip", [
    title("Equip"),
    lst("nsocks", "$eqSlots", button("nsock", [{"set": {"eqSlot": "{i}", "eqId": -1}}], [img("nsock-ic", "$icon")], classIf={"on": "$sel", "none": "$none"})),
    box("nlist-win", [lst("nlist", "$eqList", button("nrow", [{"set": {"eqId": "{id}"}}], [img("nicon", "$icon"), text("nrow-n", "{name}"), box("grow"), text("nrow-c", "{count}")], classIf={"sel": "$sel"})),
                      text("nempty", "---", visibleIf="$eqEmpty")]),
    box("nrow4 stats", [stat("STR", "str"), stat("DEF", "def"), stat("INT", "int"), stat("LCK", "lck")]),
    information(img("ninfo-ic ic", "$eqPick.icon"), "{eqPick.name}", "{eqPick.desc}", "Change gear in the game's Equip menu: it works out the stats there."),
])

# ---- ITEMS ----------------------------------------------------------------------------------------------------------------------------------
items = pg("items", [
    title("Items"),
    box("nwin bars", [barrow("HP", "hp-l", bar("hpbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"}), "{st.hpText}"),
                      barrow("MP", "mp-l", bar("mpbar", "$st.mp", "$st.maxMp"), "{st.mpText}"),
                      barrow("HEART", "ht-l", bar("htbar", "$st.heart", "$st.maxHeart"), "{st.heartText}")]),
    box("ntabs", [button("ntab", [{"set": {"itemTab": "use", "item": -1}}], [text("ntab-t", "ITEMS")], classIf={"on": "$itemUseTab"}),
                  button("ntab", [{"set": {"itemTab": "key", "item": -1}}], [text("ntab-t", "KEY ITEMS")], classIf={"on": "$itemKeyTab"})]),
    box("nlist-win", [lst("nlist", "$itemList", button("nrow", [{"set": {"item": "{id}"}}], [img("nicon", "$icon"), text("nrow-n", "{name}"), box("grow"), text("nrow-c", "{count}")], classIf={"sel": "$sel"})),
                      text("nempty", "---", visibleIf="$itemEmpty")]),
    information(img("ninfo-ic ic", "$ipick.icon"), "{ipick.name}", "{ipick.desc}", "{ipick.effect}",
                btn=act("USE", [{"call": "useItem", "args": ["{ipick.id}"]}], "$ipick.canUse", "FULL", "$ipick.full")),
])

# ---- SPELL BOOK -----------------------------------------------------------------------------------------------------------------------------
book = pg("book", [
    title("Spell Book"),
    lst("nsocks5", "$bookList", button("bsock", [{"set": {"book": "{k}"}}], [img("bsock-img", "$img"), box("bset", [text("bset-t", "SET")], visibleIf="$set")],
                                      classIf={"on": "$set", "locked": "$locked"})),
    box("nlist-win", [lst("nlist", "$bookList", button("nrow", [{"set": {"book": "{k}"}}], [img("nicon", "$img"), text("nrow-n", "{name}"), box("grow"),
                                                                                          text("nrow-set", "SET", visibleIf="$set")], classIf={"locked": "$locked"}))]),
    information(img("ninfo-ic ic2", "$bookPick.img"), "{bookPick.name}", "{bookPick.desc}", "Cast with a subweapon. Turn it on in the game.",
                btn=act("SET", [{"call": "setBook", "args": ["{bookPick.k}"]}], "$bookPick.canSet", "IN USE", "$bookPick.isSet")),
])

# ---- RELICS (an icon grid: they are recognisable, so no labels under them) -----------------------------------------------------------------------
relics = pg("relics", [
    title("Relics"),
    box("nlist-win relwin", [lst("rgrid", "$relicList", button("rel", [{"set": {"relic": "{k}"}}, {"call": "toggleRelic", "args": ["{k}"]}],
                                                              [img("rel-img", "$icon"), box("rel-on", [], visibleIf="$on"), box("rel-off", [], visibleIf="$off")],
                                                              classIf={"locked": "$locked", "sel": "$sel"}))]),
    information(img("ninfo-ic ic", "asset:ui/ic-goods.png"), "{relicPick.name}", "{relicPick.desc}"),
])

# ---- MAP (with Juste on it) ----------------------------------------------------------------------------------------------------------------------
cmap = pg("map", [
    title("Map"),
    box("ntabs", [button("ntab", [{"set": {"castle": 0}}], [text("ntab-t", "CASTLE A  {map.a}")], classIf={"on": "$map.isA"}),
                  button("ntab", [{"set": {"castle": 1}}], [text("ntab-t", "CASTLE B  {map.b}")], classIf={"on": "$map.isB"})]),
    box("nwin mapwin", [box("mapbox", [lst("ml m-fill", "$mapFill", text("mt", "{t}")), lst("ml m-save", "$mapSave", text("mt", "{t}")), lst("ml m-warp", "$mapWarp", text("mt", "{t}")),
                                       lst("ml m-walls", "$mapWalls", text("mt", "{t}")),
                                       box("me", [box("me-in", [])], bindStyle={"left": "{me.left}", "top": "{me.top}"}, visibleIf="$me.on")], classIf={"b": "$mapB"}),
                        text("map-empty", "Nothing explored in this castle yet.", visibleIf="$map.empty")]),
    box("nwin mapfoot", [text("nlab", "TOTAL"), text("mrate", "{map.total}"), box("grow"), text("nlab", "YOU"), text("mrate", "{meText}")]),
])


def carry(p):
    p = dict(p); p["children"] = p["children"][:2]; p["class"] += " carried"; return p


pages = [("status", status), ("equip", equip), ("items", items), ("book", book), ("relics", relics), ("map", cmap), ("config", carry(v1.config))]
tab = lambda name, src, flag, cls: button("ctab", [{"navigate": name}], [img("ctab-ic " + cls, src)], classIf={"on": "$" + flag})
root = box("main", [
    box("waiting", [v1.waiting], visibleIf="$waiting"),
    box("ready", [
        box("shell", [
            box("cmd", [tab("status", "asset:game/portrait-juste.png", "onStatus", "c-status"), tab("equip", "asset:ui/ic-armor.png", "onEquip", "c-equip"),
                        tab("items", "asset:ui/ic-potion.png", "onItems", "c-items"), tab("book", "asset:game/book-0.png", "onBook", "c-book"),
                        tab("relics", "asset:ui/rl-1.png", "onRelics", "c-relics"), tab("map", "asset:ui/ic-map.png", "onMap", "c-map")]),
            box("nmain", [{"type": "pages", "class": "stage", "initial": "status", "pages": [{"name": n, "child": c} for n, c in pages]}]),
        ]),
        button("toast", [{"set": {"toastHide": "{toast.id}", "relic": "{toast.relic}", "book": "{toast.book}"}}, {"navigate": "{toast.page}"}],
               [img("toast-img", "$toast.img"), box("toast-t", [text("toast-title", "{toast.title}"), text("toast-name", "{toast.name}"), text("toast-sub", "{toast.sub}")]),
                button("toast-x", [{"set": {"toastHide": "{toast.id}"}}], [text("toast-x-t", "X")])], visibleIf="$toastOn"),
    ], visibleIf="$ready"),
], id="screen")

if __name__ == "__main__":
    json.dump(root, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
    print("ok", len(json.dumps(root)))
