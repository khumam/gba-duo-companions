#!/usr/bin/env python3
"""Writes layout.json for the Aria of Sorrow companion 0.2.0 (design: .idea/plans/aos-design in the app repo).
A command column on the left (STATUS, SOUL SET, EQUIP, ITEM USE, MAP) that mirrors the game's own list, and on every page the same pattern:
sockets on top, one list, one inspector with the one big button. Enemy data and Buttons stay as pages reached from STATUS (title row).
The pages carried over from 0.1.x (enemy, enemyDetail, config) come from art/v1_layout.py unchanged apart from losing their bottom nav.
    python3 art/layout.py"""
import json, os, sys
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import v1_layout as v1          # the 0.1.x module: builds its pages when imported (does not write unless run as a script)


def box(cls, ch=(), **kw):      return {"type": "box", "class": cls, "children": list(ch), **kw}
def text(cls, t, **kw):         return {"type": "text", "class": cls, "text": t, **kw}
def img(cls, src, **kw):        return {"type": "image", "class": cls, "src": src, **kw}
def button(cls, on, ch, **kw):  return {"type": "button", "class": cls, "onClick": on, "children": list(ch), **kw}
def lst(cls, items, tpl, **kw): return {"type": "list", "class": cls, "items": items, "template": tpl, **kw}
def bar(cls, v, mx, **kw):      return {"type": "bar", "class": cls, "value": v, "maxKey": mx, **kw}


def title(t, extra=()):
    return box("ptitle", [box("title", [img("tplate", "asset:game/title.png"), text("ttext", t)]), box("grow"), *extra])


def pg(name, kids, extra_cls=""):
    return box(f"npg npg-{name} {extra_cls}".strip(), kids)


cursor = lambda: img("ncur", "asset:game/glove.png", visibleIf="$sel")


def inspector(pic, name, desc, extra=None, btn=(), chips=None):
    return box("ninfo", [
        box("ninfo-top", [pic, box("ninfo-t", [text("ninfo-name", name), text("ninfo-desc", desc), *([text("ninfo-extra", extra)] if extra else [])])]),
        *([chips] if chips else []),
        box("ninfo-foot", [text("ninfo-note", "{note}"), box("grow"), *btn]),
    ])


def act(label, on, can, done_label, done):
    return [button("nbtn", on, [text("nbtn-t", label)], visibleIf=can), box("nbtn nbtn-done", [text("nbtn-t", done_label)], visibleIf=done)]


# ---- STATUS ------------------------------------------------------------------------------------------------------------------------
stat = lambda lab, key, cls="": box("nstat", [text("nlab " + cls, lab), text("nval", "{st.%s}" % key)])
status = pg("status", [
    title("STATUS", [button("nmini", [{"navigate": "enemy"}], [text("nmini-t", "BOOK")]), button("nmini", [{"navigate": "config"}], [text("nmini-t", "KEYS")])]),
    box("nwin nhero", [
        img("nport", "asset:game/portrait-soma.png"),
        box("nhero-r", [
            box("namerow", [text("nname", "SOMA"), text("nlv", "LV.{st.level}"), box("grow"),
                            text("ngood", "GOOD")]),
            box("nbarrow", [text("nlab hp-l", "HP"), bar("hpbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"}), text("nnum", "{st.hpText}")]),
            box("nbarrow", [text("nlab mp-l", "MP"), bar("mpbar", "$st.mp", "$st.maxMp"), text("nnum", "{st.mpText}")]),
            box("healrow", [text("nheal", "{heal.name}"),
                            box("grow"),
                            button("nbtn nbtn-s", [{"call": "quickHeal"}], [text("nbtn-t", "HEAL")], visibleIf="$heal.can"),
                            box("nbtn nbtn-s nbtn-done", [text("nbtn-t", "HEAL")], visibleIf="$heal.full"),
                            box("nbtn nbtn-s nbtn-done", [text("nbtn-t", "HEAL")], visibleIf="$heal.none")]),
        ]),
    ]),
    box("nrow2", [box("nbig att", [text("nlab att-l", "ATT"), text("nbig-v", "{st.att}")]), box("nbig def", [text("nlab def-l", "DEF"), text("nbig-v", "{st.def}")])]),
    box("nrow4", [stat("STR", "str"), stat("CON", "con"), stat("INT", "int"), stat("LCK", "lck")]),
    box("nwin expw", [text("nlab", "EXP"), bar("expbar", "$st.expIn", "$st.expSpan"), box("expn", [text("nnum", "{st.exp}"), text("nnext", "+{st.next}")])]),
    box("nrow3", [box("nchip", [text("nlab", "TIME"), text("nchip-v", "{st.time}")]),
                  box("nchip", [text("nlab", "RATE"), text("nchip-v", "{st.rate}")]),
                  box("nchip", [text("nlab gold-l", "GOLD"), text("nchip-v gold", "{st.gold}")])]),
])

# ---- SOUL SET (four sockets: bullet, guardian, enchant, ability) -------------------------------------------------------------------------
soul = pg("soul", [
    title("SOUL SET"),
    lst("nsocks", "$soulTabs", button("nsock", [{"set": {"soulCat": "{c}", "soul": -1, "abil": -1}}],
                                      [img("nsock-orb", "$big"), text("nsock-b", "{badge}")], classIf={"on": "$sel"})),
    box("nlist-win", [
        lst("nlist", "$soulList", button("nrow", [{"set": {"soul": "{id}"}}],
                                         [cursor(), img("norb", "$orb"), text("nrow-n", "{name}"), box("grow"),
                                          text("nrow-set", "SET", visibleIf="$equipped"), text("nrow-c", "{count}")],
                                         classIf={"sel": "$sel", "eqd": "$equipped"}), visibleIf="$notAbil"),
        lst("nlist", "$abilList", button("nrow", [{"set": {"abil": "{i}"}}, {"call": "toggleAbility", "args": ["{i}"]}],
                                         [cursor(), img("norb", "$orb"), text("nrow-n", "{name}"), box("grow"),
                                          box("npill on", [text("npill-t", "ON")], visibleIf="$on"),
                                          box("npill off", [text("npill-t", "OFF")], visibleIf="$off")],
                                         classIf={"sel": "$sel", "locked": "$locked"}), visibleIf="$isAbil"),
    ]),
    box("ninfo-wrap", [inspector(img("ninfo-ic", "asset:game/orbbig-red.png"), "{soulPick.name}", "{soulPick.desc}", "{soulPick.from}",
                                 btn=act("SET", [{"call": "setSoul", "args": ["{soulPick.cat}", "{soulPick.id}"]}], "$soulPick.canSet", "IN USE", "$soulPick.isSet"),
                                 chips=box("nchips", [box("nchip2", [text("nlab att-l", "ATT"), text("nval", "{sw.att.v}", classIf={"up": "$sw.att.up", "down": "$sw.att.down"})]),
                                                      box("nchip2", [text("nlab def-l", "DEF"), text("nval", "{sw.def.v}", classIf={"up": "$sw.def.up", "down": "$sw.def.down"})]),
                                                      box("nchip2", [text("nlab", "MP"), text("nval", "{soulPick.costN}")], visibleIf="$soulPick.hasCost")]))],
        visibleIf="$notAbil"),
    box("ninfo-wrap", [inspector(img("ninfo-ic", "asset:game/orbbig-grey.png"), "{abilPick.name}", "{abilPick.desc}")], visibleIf="$isAbil"),
])

# ---- EQUIP ----------------------------------------------------------------------------------------------------------------------------------
sw = lambda lab, key, cls="": box("nchip2", [text("nlab " + cls, lab), text("nval", "{sw.%s.v}" % key, classIf={"up": "$sw.%s.up" % key, "down": "$sw.%s.down" % key})])
equip = pg("equip", [
    title("EQUIP"),
    lst("nsocks", "$eqSlots", button("nsock", [{"set": {"eqSlot": "{i}", "eqItem": -1}}], [img("nsock-ic", "$icon")], classIf={"on": "$sel"})),
    box("nlist-win", [
        lst("nlist", "$eqList", button("nrow", [{"set": {"eqItem": "{idx}"}}],
                                       [cursor(), img("nicon", "$icon"), text("nrow-n", "{name}"), box("grow"), text("nrow-c", "{count}")], classIf={"sel": "$sel"})),
        text("nempty", "Nothing to change to.", visibleIf="$eqEmpty"),
    ]),
    box("ninfo-wrap", [inspector(img("ninfo-ic ic", "$eqPick.icon"), "{eqPick.name}", "{eqPick.desc}", "{eqPick.stats}",
                                 btn=[*act("EQUIP", [{"call": "equip", "args": ["{eqPick.slot}", "{eqPick.idx}"]}], "$eqPick.canSet", "WORN", "$eqPick.isSet"),
                                      box("nbtn nbtn-done", [text("nbtn-t", "NOT OWNED")], visibleIf="$eqPick.notOwned")],
                                 chips=box("nchips", [sw("ATT", "att", "att-l"), sw("DEF", "def", "def-l"), sw("STR", "str"), sw("CON", "con"), sw("INT", "int"), sw("LCK", "lck")]))]),
])

# ---- ITEM USE -----------------------------------------------------------------------------------------------------------------------------
items = pg("items", [
    title("ITEM USE"),
    box("nwin bars", [
        box("nbarrow", [text("nlab hp-l", "HP"), bar("hpbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"}), text("nnum", "{st.hpText}")]),
        box("nbarrow", [text("nlab mp-l", "MP"), bar("mpbar", "$st.mp", "$st.maxMp"), text("nnum", "{st.mpText}")]),
    ]),
    box("ntabs", [button("ntab", [{"set": {"itemTab": "use", "item": -1}}], [text("ntab-t", "ITEMS")], classIf={"on": "$itemUseTab"}),
                  button("ntab", [{"set": {"itemTab": "key", "item": -1}}], [text("ntab-t", "KEY ITEMS")], classIf={"on": "$itemKeyTab"}), box("grow"),
                  text("ncount", "{itemCount}")]),
    box("nlist-win", [
        lst("nlist", "$itemList", button("nrow", [{"set": {"item": "{i}"}}],
                                         [cursor(), img("nicon", "$icon"), text("nrow-n", "{name}"), box("grow"), text("nrow-c", "{count}")], classIf={"sel": "$sel"})),
        text("nempty", "No items here.", visibleIf="$itemEmpty"),
    ]),
    box("ninfo-wrap", [inspector(img("ninfo-ic ic", "$itemPick.icon"), "{itemPick.name}", "{itemPick.desc}", "{itemPick.effect}",
                                 btn=[*act("USE", [{"call": "useItem", "args": ["{itemPick.i}"]}], "$itemPick.canUse", "FULL", "$itemPick.full"),
                                      box("nbtn nbtn-done", [text("nbtn-t", "NOT OWNED")], visibleIf="$itemPick.notOwned")])]),
])

# ---- MAP (the game's SELECT map, with Soma on it) ---------------------------------------------------------------------------------------------
cmap = pg("map", [
    title("MAP"),
    box("nwin mapwin", [box("mapbox", [lst("ml m-fill", "$mapFill", text("mt", "{t}")), lst("ml m-save", "$mapSave", text("mt", "{t}")), lst("ml m-warp", "$mapWarp", text("mt", "{t}")),
                                       lst("ml m-walls", "$mapWalls", text("mt", "{t}")), lst("ml m-doors", "$mapDoors", text("mt", "{t}")),
                                       box("me", [box("me-in", [])], bindStyle={"left": "{me.left}", "top": "{me.top}"}, visibleIf="$me.on")])]),
    box("nwin mapfoot", [img("norb", "asset:game/orb-red.png"), text("mrate", "{st.rate}"), box("grow"), text("nlab", "YOU"), text("nmini-v", "{meText}"), box("grow"),
                         text("nlab", "ROOMS"), text("mcell", "{mapCells}")]),
])

# ---- carried over: enemy list, enemy page, buttons (their own title + body, no bottom nav) ---------------------------------------------------
def gameart(obj):
    s = json.dumps(obj)
    for a, b in (("asset:ui/title.png", "asset:game/title.png"), ("asset:ui/orbbig-", "asset:game/orbbig-"), ("asset:ui/key-", "asset:game/key-"),
                 ("asset:ui/vortex.png", "asset:game/portrait-soma.png")):
        s = s.replace(a, b)
    return json.loads(s)


def carry(p):
    kids = p["children"][:2]
    p = dict(p); p["children"] = kids
    p["class"] = p["class"] + " carried"
    # the carried 0.1.x pages use the game's art as well
    return gameart(p)


pages = [("status", status), ("soul", soul), ("equip", equip), ("items", items), ("map", cmap),
         ("enemy", carry(v1.enemy)), ("enemyDetail", carry(v1.enemy_detail)), ("config", carry(v1.config))]
tab = lambda name, icon, flag, cls: button("ctab", [{"navigate": name}], [img("ctab-ic " + cls, icon)], classIf={"on": "$" + flag})
root = box("main", [
    box("waiting", [gameart(v1.waiting)], visibleIf="$waiting"),
    box("ready", [
        box("shell", [
            box("cmd", [tab("status", "asset:game/portrait-soma.png", "onStatus", "c-status"), tab("soul", "asset:game/orb-red.png", "onSoul", "c-soul"),
                        tab("equip", "asset:game/w-25.png", "onEquip", "c-equip"), tab("items", "asset:game/i-0.png", "onItems", "c-items"),
                        tab("map", "asset:ui/tab-map.png", "onMap", "c-map")]),
            box("nmain", [{"type": "pages", "class": "stage", "initial": "status", "pages": [{"name": n, "child": c} for n, c in pages]}]),
        ]),
        button("toast", [{"set": {"toastHide": "{toast.id}", "soulCat": "{toast.cat}", "soul": "{toast.soul}", "abil": "{toast.abil}", "enemy": "{toast.enemy}"}},
                         {"navigate": "{toast.page}"}],
               [img("toast-orb", "$toast.orb"), box("toast-t", [text("toast-title", "{toast.title}", bindStyle={"color": "{toast.hex}"}),
                                                                 text("toast-name", "{toast.name}"), text("toast-sub", "{toast.sub}")]),
                button("toast-x", [{"set": {"toastHide": "{toast.id}"}}], [text("toast-x-t", "X")])], visibleIf="$toastOn"),
    ], visibleIf="$ready"),
], id="screen")

if __name__ == "__main__":
    json.dump(root, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
    print("ok", len(json.dumps(root)))
