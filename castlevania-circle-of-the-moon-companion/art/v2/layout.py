#!/usr/bin/env python3
"""Writes layout.json for the Circle of the Moon companion 0.2.0 (design: .idea/plans/cotm-design in the app repo).
A command column on the left (STATUS, DSS, GEAR, ITEMS, MAP) in the game's arrow-plate style, then on each page: sockets, one list / grid, an
inspector with the one big button. Art is the game's own wherever it has any: Nathan's portrait, the 20 DSS cards, the Magic Item pictures.
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


def inspector(pic, name, desc, extra=None, btn=(), chips=None):
    return box("ninfo", [box("ninfo-top", [pic, box("ninfo-t", [text("ninfo-name", name), text("ninfo-desc", desc), *([text("ninfo-extra", extra)] if extra else [])])]),
                         *([chips] if chips else []), box("ninfo-foot", [text("ninfo-note", "{note}"), box("grow"), *btn])])


barrow = lambda lab, cls, b, v: box("nbarrow", [text("nlab " + cls, lab), b, text("nnum", v)])
stat = lambda lab, key: box("nstat", [text("nlab", lab), text("nval", "{st.%s}" % key)])

# ---- STATUS ---------------------------------------------------------------------------------------------------------------------------------
status = pg("status", [
    title("STATUS", [text("ntime", "{st.time}"), button("nmini", [{"navigate": "config"}], [text("nmini-t", "KEYS")])]),
    box("nwin nhero", [
        img("nport", "asset:game/portrait-nathan.png"),
        box("nhero-r", [
            box("namerow", [text("nname", "NATHAN"), box("grow"), text("nlv", "LV {st.level}")]),
            barrow("HP", "hp-l", bar("hpbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"}), "{st.hpText}"),
            barrow("MP", "mp-l", bar("mpbar", "$st.mp", "$st.maxMp"), "{st.mpText}"),
            barrow("HEART", "ht-l", bar("htbar", "$st.heart", "$st.maxHeart"), "{st.heartText}"),
            box("healrow", [text("nheal", "{heal.name}"), box("grow"),
                            button("nbtn nbtn-s", [{"call": "quickHeal", "args": ["{heal.id}"]}], [text("nbtn-t", "HEAL")], visibleIf="$heal.can"),
                            box("nbtn nbtn-s nbtn-done", [text("nbtn-t", "HEAL")], visibleIf="$heal.off")]),
        ]),
    ]),
    box("nrow4", [stat("STR", "str"), stat("DEF", "def"), stat("INT", "int"), stat("LCK", "lck")]),
    box("nwin expw", [text("nlab", "EXP"), bar("expbar", "$st.expIn", "$st.expSpan"), box("expn", [text("nnum", "{st.exp}"), text("nnext", "+{st.next}")])]),
    box("nwin mgw", [box("mghead", [text("nlab", "MAGIC ITEM"), box("grow"), text("nnum", "{mgCount}")]),
                     lst("mgrow", "$mg", box("mgcell", [img("mgimg", "$img")], classIf={"locked": "$locked"}))]),
])

# ---- DSS (the Action x Attribute cards) --------------------------------------------------------------------------------------------------------
dss = pg("dss", [
    title("DSS"),
    box("nsocks2", [
        button("dsock", [{"set": {"dssKind": 1}}], [img("dsock-img", "$dssPick.actImg"), box("dsock-t", [text("nlab", "ACTION"), text("dsock-n", "{dssPick.action}")])], classIf={"on": "$kindAct"}),
        button("dsock", [{"set": {"dssKind": 2}}], [img("dsock-img", "$dssPick.attrImg"), box("dsock-t", [text("nlab", "ATTRIB."), text("dsock-n", "{dssPick.attr}")])], classIf={"on": "$kindAttr"}),
    ]),
    box("nlist-win cardwin", [
        lst("cgrid", "$dssActs", button("cd", [{"set": {"pickAct": "{i}"}}], [img("cd-img", "$img")], classIf={"sel": "$sel", "locked": "$locked", "set": "$set"}), visibleIf="$kindAct"),
        lst("cgrid", "$dssAttrs", button("cd", [{"set": {"pickAttr": "{i}"}}], [img("cd-img", "$img")], classIf={"sel": "$sel", "locked": "$locked", "set": "$set"}), visibleIf="$kindAttr"),
    ]),
    box("ninfo-wrap", [inspector(img("ninfo-ic dic", "asset:game/card-19.png"), "{dssPick.attr} / {dssPick.action}", "{dssPick.text}", None,
                                 btn=[text("ninfo-extra", "{dssPick.costN}{dssPick.costU}"), *act("SET", [{"call": "setDss", "args": ["{dssPick.attr1}", "{dssPick.act1}"]}], "$dssPick.canSet", "IN USE", "$dssPick.isSet")])]),
])

# ---- GEAR ----------------------------------------------------------------------------------------------------------------------------------------
sw = lambda n: box("nchip2", [text("nlab", n.upper()), text("nval", "{sw.%s.v}" % n),
                              text("nval to", "> {sw.%s.to}" % n, visibleIf="$sw.%s.cmp" % n, classIf={"up": "$sw.%s.up" % n, "down": "$sw.%s.down" % n})])
gear = pg("gear", [
    title("EQUIP"),
    lst("nsocks", "$itemTabs", button("nsock", [{"set": {"itemTab": "{i}", "itemId": -1}}], [img("nsock-ic", "$icon"), text("nsock-l", "{label}")], classIf={"on": "$sel"})),
    box("nlist-win", [lst("nlist", "$itemList", button("nrow", [{"set": {"itemId": "{id}"}}], [text("nrow-n", "{name}"), box("grow"), text("nrow-c", "{count}")], classIf={"sel": "$sel"})),
                      text("nempty", "Nothing to equip.", visibleIf="$itemEmpty")]),
    box("ninfo-wrap", [inspector(img("ninfo-ic ic", "asset:ui/ic-armor.png"), "{ipick.name}", "{ipick.desc}", "{ipick.bonus}",
                                 btn=act("EQUIP", [{"call": "equip", "args": ["{ipick.tab}", "{ipick.id}"]}], "$ipick.canSet", "WORN", "$ipick.isSet"),
                                 chips=box("nchips", [sw("str"), sw("def"), sw("int"), sw("lck")]))]),
])

# ---- ITEMS ---------------------------------------------------------------------------------------------------------------------------------------
items = pg("items", [
    title("ITEM USE"),
    box("nwin bars", [barrow("HP", "hp-l", bar("hpbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"}), "{st.hpText}"),
                      barrow("MP", "mp-l", bar("mpbar", "$st.mp", "$st.maxMp"), "{st.mpText}"),
                      barrow("HEART", "ht-l", bar("htbar", "$st.heart", "$st.maxHeart"), "{st.heartText}")]),
    box("nlist-win", [lst("nlist", "$itemList", button("nrow", [{"set": {"itemId": "{id}"}}], [img("nicon", "asset:ui/ic-potion.png"), text("nrow-n", "{name}"), box("grow"), text("nrow-c", "{count}")], classIf={"sel": "$sel"})),
                      text("nempty", "No items.", visibleIf="$itemEmpty")]),
    box("ninfo-wrap", [inspector(img("ninfo-ic ic", "asset:ui/ic-potion.png"), "{ipick.name}", "{ipick.desc}", "{ipick.bonus}",
                                 btn=act("USE", [{"call": "useItem", "args": ["{ipick.id}"]}], "$ipick.canUse", "FULL", "$ipick.full"))]),
])

# ---- MAP (with Nathan on it) -----------------------------------------------------------------------------------------------------------------------
cmap = pg("map", [
    title("MAP"),
    box("nwin mapwin", [box("mapbox", [lst("ml m-fill", "$mapFill", text("mt", "{t}")), lst("ml m-save", "$mapSave", text("mt", "{t}")), lst("ml m-warp", "$mapWarp", text("mt", "{t}")),
                                       lst("ml m-walls", "$mapWalls", text("mt", "{t}")),
                                       box("me", [box("me-in", [])], bindStyle={"left": "{me.left}", "top": "{me.top}"}, visibleIf="$me.on")])]),
    box("nwin mapfoot", [text("nlab", "RATE"), text("mrate", "{st.rate}"), box("grow"), text("nlab", "YOU"), text("mrate", "{meText}")]),
])


def carry(p):
    p = dict(p); p["children"] = p["children"][:2]; p["class"] += " carried"; return p


pages = [("status", status), ("dss", dss), ("gear", gear), ("items", items), ("map", cmap), ("config", carry(v1.config))]
tab = lambda name, src, flag, cls: button("ctab", [{"navigate": name}], [img("ctab-ic " + cls, src)], classIf={"on": "$" + flag})
root = box("main", [
    box("waiting", [v1.waiting], visibleIf="$waiting"),
    box("ready", [
        box("shell", [
            box("cmd", [tab("status", "asset:game/portrait-nathan.png", "onStatus", "c-status"), tab("dss", "asset:game/card-4.png", "onDss", "c-dss"),
                        tab("gear", "asset:ui/ic-armor.png", "onGear", "c-gear"), tab("items", "asset:ui/ic-potion.png", "onItems", "c-items"),
                        tab("map", "asset:ui/tab-map.png", "onMap", "c-map")]),
            box("nmain", [{"type": "pages", "class": "stage", "initial": "status", "pages": [{"name": n, "child": c} for n, c in pages]}]),
        ]),
        button("toast", [{"set": {"toastHide": "{toast.id}", "card": "{toast.card}", "magic": "{toast.magic}"}}, {"navigate": "{toast.page}"}],
               [img("toast-img", "$toast.img"), box("toast-t", [text("toast-title", "{toast.title}"), text("toast-name", "{toast.name}"), text("toast-sub", "{toast.sub}")]),
                button("toast-x", [{"set": {"toastHide": "{toast.id}"}}], [text("toast-x-t", "X")])], visibleIf="$toastOn"),
    ], visibleIf="$ready"),
], id="screen")

if __name__ == "__main__":
    json.dump(root, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
    print("ok", len(json.dumps(root)))
