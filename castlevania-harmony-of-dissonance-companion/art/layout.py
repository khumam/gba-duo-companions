#!/usr/bin/env python3
"""Writes layout.json for the Harmony of Dissonance companion 0.4.0 (design: .idea/plans/cv-design2 in the app repo, hod-*.png).
The game's pause screens re-laid for a touch screen:
  * the banded royal-blue field, the green gothic title plaque with its dithered tail (ui/plaque.png, Jacquard 24),
  * the game's word menu on the left with the white glove (game/hand), each word on its own white rule,
  * the relics list with the green ON / OFF pills, the equipment rows (WHIP, BODY, GOODS) on rules,
  * the INFORMATION bar at the bottom: the page's one text zone and its action.
Same data as before (main.lua only gained the config nav flag). The 0.2/0.3 source is in art/v2/.
    python3 art/hod_ui.py && python3 art/layout.py && python3 art/css.py"""
import json, os

here = os.path.dirname(os.path.abspath(__file__))


def box(cls, ch=(), **kw):      return {"type": "box", "class": cls, "children": list(ch), **kw}
def text(cls, t, **kw):         return {"type": "text", "class": cls, "text": t, **kw}
def img(cls, src, **kw):        return {"type": "image", "class": cls, "src": src, **kw}
def button(cls, on, ch, **kw):  return {"type": "button", "class": cls, "onClick": on, "children": list(ch), **kw}
def lst(cls, items, tpl, **kw): return {"type": "list", "class": cls, "items": items, "template": tpl, **kw}
def bar(cls, v, mx, **kw):      return {"type": "bar", "class": cls, "value": v, "maxKey": mx, **kw}


HAND = "asset:ui/hand.png"
grow = lambda: box("grow")


def plaque(t, extra=()):
    return box("phead", [box("plaque", [img("plaque-img", "asset:ui/plaque.png"), text("plaque-t", t)]), grow(), *extra])


def info(kids, actions=()):
    """the INFORMATION bar"""
    return box("info", [box("info-head", [text("info-tag", "INFORMATION"), box("info-rule")]),
                        box("info-row", [box("info-body", kids), box("info-act", list(actions))])])


def gbtn(label, on, **kw):
    return button("gbtn", on, [text("gbtn-t", label)], **kw)


def act(label, on, can, done_label, done):
    return [gbtn(label, on, visibleIf=can), box("gbtn off", [text("gbtn-t", done_label)], visibleIf=done)]


barrow = lambda lab, cls, b, v: box("barrow", [text("lab " + cls, lab), b, text("num bar-n", v)])


def dots(lab, key):
    """the game's dotted leader: LABEL ........ value"""
    return box("dline", [text("lab", lab), box("leader"), text("num", "{st.%s}" % key)])


hand_row = lambda on, kids, **kw: button("hrow", on, [box("hand-w", [img("hand", HAND, visibleIf="$sel")]), *kids], **kw)

# ---- STATUS ------------------------------------------------------------------------------------------------------------------------
status = box("page page-status", [
    plaque("Juste Belmont"),
    box("top", [
        img("port", "asset:game/portrait-juste.png"),
        button("bookbtn", [{"navigate": "book"}], [img("book-img", "$bookNow.img")]),
        box("lvl", [box("dline", [text("lab", "LEVEL"), grow(), text("num big", "{st.level}")]),
                    box("dline", [text("lab", "EXP"), grow(), text("num", "{st.exp}")]),
                    box("dline", [text("lab", "NEXT"), grow(), text("num", "{st.next}")]),
                    box("dline", [text("lab", "GOLD"), grow(), text("num gold", "{st.gold}")]),
                    box("dline", [text("lab", "TIME"), grow(), text("num", "{st.time}")])]),
    ]),
    box("mid", [
        box("bars", [barrow("HP", "hp-l", bar("hpbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"}), "{st.hpText}"),
                     barrow("MP", "mp-l", bar("mpbar", "$st.mp", "$st.maxMp"), "{st.mpText}"),
                     barrow("HEART", "ht-l", bar("htbar", "$st.heart", "$st.maxHeart"), "{st.heartText}")]),
        box("dots", [dots("STR", "str"), dots("DEF", "def"), dots("INT", "int"), dots("LCK", "lck")]),
    ]),
    info([text("info-t", "{heal.name}")],
         [gbtn("HEAL", [{"call": "quickHeal", "args": ["{heal.id}"]}], visibleIf="$heal.can"), box("gbtn off", [text("gbtn-t", "HEAL")], visibleIf="$heal.off")]),
])

# ---- EQUIP: the slot rows on rules (WHIP first, like the game), the stats, the choices ------------------------------------------------
equip = box("page page-equip", [
    plaque("Equip"),
    lst("socks", "$eqSlots", button("sock", [{"set": {"eqSlot": "{i}", "eqId": -1}}], [img("sock-ic", "$icon"), text("lab sock-l", "{label}")],
                                    classIf={"sel": "$sel", "none": "$none"})),
    box("slotname", [img("hand", HAND), text("slot-n", "{eqPick.name}")]),
    box("rule"),
    box("list-w", [lst("glist", "$eqList", hand_row([{"set": {"eqId": "{id}"}}], [img("gicon", "$icon"), text("gname", "{name}"), grow(), text("gnum", "{count}")],
                                                    classIf={"sel": "$sel"})),
                   text("empty", "---", visibleIf="$eqEmpty")]),
    box("statrow", [box("kv", [text("lab", "STR"), text("num", "{st.str}")]), box("kv", [text("lab", "DEF"), text("num", "{st.def}")]),
                    box("kv", [text("lab", "INT"), text("num", "{st.int}")]), box("kv", [text("lab", "LCK"), text("num", "{st.lck}")])]),
    info([box("irow", [img("info-ic", "$eqPick.icon"), box("info-txt", [text("info-name", "{eqPick.name}"), text("info-t", "{eqPick.desc}"),
                                                                       text("info-x", "Change gear in the game's Equip menu.")])])]),
])

# ---- ITEMS ------------------------------------------------------------------------------------------------------------------------
items = box("page page-items", [
    plaque("Items"),
    box("bars wide", [barrow("HP", "hp-l", bar("hpbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"}), "{st.hpText}"),
                      barrow("MP", "mp-l", bar("mpbar", "$st.mp", "$st.maxMp"), "{st.mpText}"),
                      barrow("HEART", "ht-l", bar("htbar", "$st.heart", "$st.maxHeart"), "{st.heartText}")]),
    box("tabs", [button("tab", [{"set": {"itemTab": "use", "item": -1}}], [text("lab tab-t", "ITEMS")], classIf={"on": "$itemUseTab"}),
                 button("tab", [{"set": {"itemTab": "key", "item": -1}}], [text("lab tab-t", "KEY ITEMS")], classIf={"on": "$itemKeyTab"})]),
    box("rule"),
    box("list-w", [lst("glist", "$itemList", hand_row([{"set": {"item": "{id}"}}], [img("gicon", "$icon"), text("gname", "{name}"), grow(), text("gnum", "{count}")],
                                                      classIf={"sel": "$sel"})),
                   text("empty", "---", visibleIf="$itemEmpty")]),
    info([box("irow", [img("info-ic", "$ipick.icon"), box("info-txt", [text("info-name", "{ipick.name}"), text("info-t", "{ipick.desc}"), text("info-x", "{ipick.effect}")])])],
         act("USE", [{"call": "useItem", "args": ["{ipick.id}"]}], "$ipick.canUse", "FULL", "$ipick.full")),
])

# ---- SPELL BOOK: the five books as the game's list, the emblem in the bar ----------------------------------------------------------
book = box("page page-book", [
    plaque("Spell Book"),
    box("list-w", [lst("blist", "$bookList", button("hrow brow", [{"set": {"book": "{k}"}}], [
        box("hand-w", [img("hand", HAND, visibleIf="$set")]), img("bicon", "$img"), text("gname", "{name}"), grow(),
        box("pill on", [text("pill-t", "SET")], visibleIf="$set")], classIf={"locked": "$locked"}))]),
    info([box("irow", [img("info-ic", "$bookPick.img"), box("info-txt", [text("info-name", "{bookPick.name}"), text("info-t", "{bookPick.desc}"),
                                                                        text("info-x", "Cast with a subweapon.")])])],
         act("SET", [{"call": "setBook", "args": ["{bookPick.k}"]}], "$bookPick.canSet", "IN USE", "$bookPick.isSet")),
])

# ---- RELICS: the boxed list with the ON / OFF pills ---------------------------------------------------------------------------------
relics = box("page page-relics", [
    plaque("Relics"),
    box("relbox", [lst("rlist", "$relicList", hand_row([{"set": {"relic": "{k}"}}, {"call": "toggleRelic", "args": ["{k}"]}], [
        img("ricon", "$icon"), text("gname", "{name}"), grow(),
        box("pills", [box("pill on", [text("pill-t", "ON")], classIf={"lit": "$on"}), box("pill off", [text("pill-t", "OFF")], classIf={"lit": "$off"})], visibleIf="$have"),
    ], classIf={"locked": "$locked", "sel": "$sel"}))]),
    info([box("irow", [img("info-ic", "asset:ui/ic-goods.png"), box("info-txt", [text("info-name", "{relicPick.name}"), text("info-t", "{relicPick.desc}")])])]),
])

# ---- MAP ------------------------------------------------------------------------------------------------------------------------
cmap = box("page page-map", [
    plaque("Castle Map"),
    box("mapwrap", [
        box("mapwin", [box("mapbox", [lst("ml m-fill", "$mapFill", text("mt", "{t}")), lst("ml m-save", "$mapSave", text("mt", "{t}")),
                                  lst("ml m-warp", "$mapWarp", text("mt", "{t}")), lst("ml m-walls", "$mapWalls", text("mt", "{t}")),
                                  box("me", [box("me-in")], bindStyle={"left": "{me.left}", "top": "{me.top}"}, visibleIf="$me.on")], classIf={"b": "$mapB"})], zoom={"min": 1, "max": 4, "state": "mapZoom"}),
        # pinch / drag the map, or the - / + keys on its corner (app 1.0.3+; older apps show it at 1x)
        box("zoom-ctl", [button("zoom-key", {"zoom": "out", "state": "mapZoom"}, [text("zoom-key-t", "-")]),
                         button("zoom-key", {"zoom": "in", "state": "mapZoom"}, [text("zoom-key-t", "+")])])]),
    box("tabs", [button("tab", [{"set": {"castle": 0}}], [text("lab tab-t", "CASTLE A  {map.a}")], classIf={"on": "$map.isA"}),
                 button("tab", [{"set": {"castle": 1}}], [text("lab tab-t", "CASTLE B  {map.b}")], classIf={"on": "$map.isB"})]),
    info([box("dline", [text("lab", "TOTAL"), text("num", "{map.total}"), grow(), text("lab", "YOU"), text("num", "{meText}")])]),
])

# ---- KEY CONFIG -----------------------------------------------------------------------------------------------------------------
config = box("page page-config", [
    plaque("Key Config."),
    lst("cfglist", "$cfgRows", box("crow", [
        text("lab clab", "{label}"), grow(),
        button("carr", [{"call": "cycleKey", "args": ["{row}", -1]}], [text("carr-t", "<")]),
        box("ckey-w", [img("ckey", "$keyImg")]),
        button("carr", [{"call": "cycleKey", "args": ["{row}", 1]}], [text("carr-t", ">")]),
    ])),
    text("clash", "Control settings are conflicting.", visibleIf="$cfgClash"),
    info([text("info-t", "Pressing SELECT will reset the system settings. Two actions never share a button."), text("info-x", "Game changes: {_writePermLabel}")],
         [gbtn("DEFAULT", [{"call": "defaultKeys"}]), gbtn("ALLOW", [{"call": "writePermission"}])]),
])

# ---- shell: the game's word menu ---------------------------------------------------------------------------------------------------------
NAV = [("status", "STATUS", "onStatus"), ("equip", "EQUIP", "onEquip"), ("items", "ITEMS", "onItems"), ("book", "SPELLBOOK", "onBook"),
       ("relics", "RELICS", "onRelics"), ("map", "MAP", "onMap"), ("config", "KEYCONFIG", "onConfig")]
navrow = lambda p, label, flag: button("nrow", [{"navigate": p}], [box("hand-w", [img("hand", HAND, visibleIf="$" + flag)]), text("nrow-t", label)],
                                       classIf={"on": "$" + flag})
pages = [("status", status), ("equip", equip), ("items", items), ("book", book), ("relics", relics), ("map", cmap), ("config", config)]
waiting = box("wait", [img("wait-img", "asset:game/portrait-juste.png"), text("wait-1", "Harmony of Dissonance"), text("wait-2", "COMPANION"),
                       text("wait-3", "Load a save to see Juste's relics."), text("wait-4", "This pack reads the USA cartridge (ACHE).", visibleIf="$wrongRom")])
root = box("main", [
    box("waiting", [waiting], visibleIf="$waiting"),
    box("ready", [
        box("shell", [box("nav", [*[navrow(*n) for n in NAV]]),
                      box("stage-w", [{"type": "pages", "class": "stage", "initial": "status", "pages": [{"name": n, "child": c} for n, c in pages]}])]),
        button("toast", [{"set": {"toastHide": "{toast.id}", "relic": "{toast.relic}", "book": "{toast.book}"}}, {"navigate": "{toast.page}"}],
               [img("toast-img", "$toast.img"), box("toast-t", [text("toast-title", "{toast.title}"), text("toast-name", "{toast.name}"), text("toast-sub", "{toast.sub}")]),
                button("toast-x", [{"set": {"toastHide": "{toast.id}"}}], [text("toast-x-t", "X")])], visibleIf="$toastOn"),
    ], visibleIf="$ready"),
], id="screen")

if __name__ == "__main__":
    json.dump(root, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
    print("ok", len(json.dumps(root)))
