#!/usr/bin/env python3
"""Writes layout.json for the Circle of the Moon companion 0.4.0 (design: .idea/plans/cv-design2 in the app repo, cotm-*.png).
The game's pause screens re-laid for a touch screen:
  * the navy gradient field with white rules, the slanted striped header tab (ui/title.png),
  * the pause menu's arrow plates as the page nav (red-orange = open), the same plates as the action buttons,
  * values in the game's capsule frames (angled ends: ui/cap-*.png), the DSS screen's two card rows,
  * the game's wide monospace message text (Press Start 2P).
Same data as before (main.lua only gained the config nav flag). The 0.2/0.3 source is in art/v2/.
    python3 art/cotm_ui.py && python3 art/layout.py && python3 art/css.py"""
import json, os

here = os.path.dirname(os.path.abspath(__file__))


def box(cls, ch=(), **kw):      return {"type": "box", "class": cls, "children": list(ch), **kw}
def text(cls, t, **kw):         return {"type": "text", "class": cls, "text": t, **kw}
def img(cls, src, **kw):        return {"type": "image", "class": cls, "src": src, **kw}
def button(cls, on, ch, **kw):  return {"type": "button", "class": cls, "onClick": on, "children": list(ch), **kw}
def lst(cls, items, tpl, **kw): return {"type": "list", "class": cls, "items": items, "template": tpl, **kw}
def bar(cls, v, mx, **kw):      return {"type": "bar", "class": cls, "value": v, "maxKey": mx, **kw}


grow = lambda: box("grow")


def header(t, extra=()):
    return box("phead", [box("tab", [img("tab-img", "asset:ui/title.png"), text("tab-t", t)]), grow(), *extra])


def cap(h, kids, cls=""):
    """the game's capsule frame: angled ends (images) around a top / bottom rule"""
    return box(f"cap cap{h} {cls}".strip(), [img(f"capl capi{h}", f"asset:ui/cap-l-{h}.png"), box("cap-mid", kids), img(f"capr capi{h}", f"asset:ui/cap-r-{h}.png")])


def plate(label, on, **kw):
    """an arrow plate used as a button"""
    return button("pbtn", on, [img("pbtn-img", "asset:ui/plate-on.png"), text("pbtn-t", label)], **kw)


def plate_off(label, **kw):
    return box("pbtn off", [img("pbtn-img", "asset:ui/plate-off.png"), text("pbtn-t", label)], **kw)


def act(label, on, can, done_label, done):
    return [plate(label, on, visibleIf=can), plate_off(done_label, visibleIf=done)]


def message(kids, actions=()):
    return box("msg", [box("msg-body", kids), box("msg-act", list(actions))])


rule = lambda: box("rule")
barrow = lambda lab, cls, b, v: box("barrow", [text("lab " + cls, lab), b, text("num bar-n", v)])
kv = lambda lab, v, cls="": box("kv", [text("lab", lab), grow(), text("num " + cls, v)])

# ---- STATUS ------------------------------------------------------------------------------------------------------------------------
status = box("page page-status", [
    header("STATUS"),
    box("hero", [
        box("port-w", [img("port", "asset:game/portrait-nathan.png"), text("lab port-n", "NATHAN")]),
        box("hero-r", [
            cap(12, [text("lab", "LV"), grow(), text("num", "{st.level}")]),
            cap(12, [text("lab", "TIME"), grow(), text("num", "{st.time}")]),
            cap(12, [text("lab", "RATE"), grow(), text("num", "{st.rate}")]),
            box("frame bars", [barrow("HP", "hp-l", bar("hpbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"}), "{st.hpText}"),
                               barrow("MP", "mp-l", bar("mpbar", "$st.mp", "$st.maxMp"), "{st.mpText}"),
                               barrow("HEART", "ht-l", bar("htbar", "$st.heart", "$st.maxHeart"), "{st.heartText}")]),
        ]),
    ]),
    box("row2", [
        box("frame stats", [kv("STR", "{st.str}"), kv("DEF", "{st.def}"), kv("INT", "{st.int}"), kv("LCK", "{st.lck}")]),
        box("col", [box("frame expf", [kv("EXP", "{st.exp}"), kv("NEXT", "{st.next}", "hot")]), cap(12, [text("lab", "STATUS / GOOD")], "center")]),
    ]),
    rule(),
    box("mg", [box("mg-head", [text("lab", "MAGIC ITEM"), grow(), text("num", "{mgCount}")]),
               lst("mg-row", "$mg", box("mg-cell", [img("mg-img", "$img")], classIf={"locked": "$locked"}))]),
    message([text("msg-t", "{heal.name}")],
            [plate("HEAL", [{"call": "quickHeal", "args": ["{heal.id}"]}], visibleIf="$heal.can"), plate_off("HEAL", visibleIf="$heal.off")]),
])

# ---- DSS: the two card rows, the chosen pair, the combo ---------------------------------------------------------------------------------
card = lambda key: button("cd", [{"set": {key: "{i}"}}], [img("cd-img", "$img")], classIf={"sel": "$sel", "locked": "$locked", "set": "$set"})
dss = box("page page-dss", [
    header("DSS"),
    text("lab row-l", "ACTION"),
    lst("cards", "$dssActs", card("pickAct")),
    text("lab row-l", "ATTRIBUTE"),
    lst("cards", "$dssAttrs", card("pickAttr")),
    box("pair", [cap(16, [text("lab pair-t", "{dssPick.action}")], "center"), cap(16, [text("lab pair-t", "{dssPick.attr}")], "center")]),
    rule(),
    message([box("mrow", [box("cost", [text("cost-n", "{dssPick.costN}"), text("cost-u", "{dssPick.costU}")]), text("msg-mono", "{dssPick.text}")])],
            act("SET", [{"call": "setDss", "args": ["{dssPick.attr1}", "{dssPick.act1}"]}], "$dssPick.canSet", "IN USE", "$dssPick.isSet")),
])

# ---- EQUIP: the game's EQP plates, the stat frame, the two-column list -----------------------------------------------------------------
sw = lambda n: box("kv", [text("lab", n.upper()), grow(), text("num", "{sw.%s.v}" % n),
                          text("num to", ">{sw.%s.to}" % n, visibleIf="$sw.%s.cmp" % n, classIf={"up": "$sw.%s.up" % n, "down": "$sw.%s.down" % n})])
gear = box("page page-gear", [
    header("EQUIP"),
    box("eqtop", [
        lst("eqp", "$itemTabs", button("eqrow", [{"set": {"itemTab": "{i}", "itemId": -1}}], [
            box("eqplate", [img("eqplate-img", "asset:ui/plate-off.png"), img("eqplate-img", "asset:ui/plate-on.png", visibleIf="$sel"),
                            text("eqp-l", "EQP"), text("eqp-s", "{label}")]),
            text("eq-name", "{name}")])),
        box("frame stats", [sw("str"), sw("def"), sw("int"), sw("lck")]),
    ]),
    rule(),
    box("list-w", [lst("ilist", "$itemList", button("irow", [{"set": {"itemId": "{id}"}}], [text("iname", "{name}"), grow(), text("inum", "{count}")], classIf={"sel": "$sel"})),
                   text("empty", "Nothing to equip.", visibleIf="$itemEmpty")]),
    rule(),
    message([text("msg-mono", "{ipick.desc}"), text("msg-x", "{ipick.bonus}")],
            act("EQUIP", [{"call": "equip", "args": ["{ipick.tab}", "{ipick.id}"]}], "$ipick.canSet", "WORN", "$ipick.isSet")),
])

# ---- ITEM USE ---------------------------------------------------------------------------------------------------------------------------
items = box("page page-items", [
    header("ITEM"),
    box("frame bars", [barrow("HP", "hp-l", bar("hpbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"}), "{st.hpText}"),
                       barrow("MP", "mp-l", bar("mpbar", "$st.mp", "$st.maxMp"), "{st.mpText}"),
                       barrow("HEART", "ht-l", bar("htbar", "$st.heart", "$st.maxHeart"), "{st.heartText}")]),
    rule(),
    box("list-w", [lst("ilist", "$itemList", button("irow", [{"set": {"itemId": "{id}"}}],
                                                    [img("iicon", "asset:ui/ic-potion.png"), text("iname", "{name}"), grow(), text("inum", "{count}")], classIf={"sel": "$sel"})),
                   text("empty", "No items.", visibleIf="$itemEmpty")]),
    rule(),
    message([text("msg-mono", "{ipick.desc}"), text("msg-x", "{ipick.bonus}")],
            act("USE", [{"call": "useItem", "args": ["{ipick.id}"]}], "$ipick.canUse", "FULL", "$ipick.full")),
])

# ---- MAP --------------------------------------------------------------------------------------------------------------------------------
cmap = box("page", [
    header("MAP"),
    box("mapwin", [box("mapbox", [lst("ml m-fill", "$mapFill", text("mt", "{t}")), lst("ml m-save", "$mapSave", text("mt", "{t}")),
                                  lst("ml m-warp", "$mapWarp", text("mt", "{t}")), lst("ml m-walls", "$mapWalls", text("mt", "{t}")),
                                  box("me", [box("me-in")], bindStyle={"left": "{me.left}", "top": "{me.top}"}, visibleIf="$me.on")])]),
    rule(),
    box("mapfoot", [text("lab", "RATE"), text("num", "{st.rate}"), grow(), text("lab", "YOU"), text("num", "{meText}")]),
])

# ---- CONFIG: capsule labels, arrows, the button icons ----------------------------------------------------------------------------------
config = box("page", [
    header("CONFIG"),
    lst("cfglist", "$cfgRows", box("crow", [
        cap(16, [text("lab clab", "{label}")], "center clab-w"), grow(),
        button("carr", [{"call": "cycleKey", "args": ["{row}", -1]}], [text("carr-t", "<")]),
        box("ckey-w", [img("ckey", "$keyImg")]),
        button("carr", [{"call": "cycleKey", "args": ["{row}", 1]}], [text("carr-t", ">")]),
    ])),
    text("clash", "Buttons are duplicated.", visibleIf="$cfgClash"),
    rule(),
    message([text("msg-mono", "Change button configuration."), text("msg-x", "Game changes: {_writePermLabel}")],
            [plate("DEFAULT", [{"call": "defaultKeys"}]), plate("ALLOW", [{"call": "writePermission"}])]),
])

# ---- shell ------------------------------------------------------------------------------------------------------------------------------
NAV = [("status", "STATUS", "onStatus"), ("dss", "DSS", "onDss"), ("gear", "EQUIP", "onGear"), ("items", "ITEM", "onItems"),
       ("map", "MAP", "onMap"), ("config", "CONFIG", "onConfig")]
navplate = lambda p, label, flag: button("nplate", [{"navigate": p}], [img("nplate-img", "asset:ui/plate-off.png"),
                                                                     img("nplate-img", "asset:ui/plate-on.png", visibleIf="$" + flag), text("nplate-t", label)])
pages = [("status", status), ("dss", dss), ("gear", gear), ("items", items), ("map", cmap), ("config", config)]
waiting = box("wait", [img("wait-img", "asset:game/portrait-nathan.png"), text("wait-1", "CIRCLE OF THE MOON"), text("wait-2", "COMPANION"),
                       text("wait-3", "Load a save to see Nathan's cards."), text("wait-4", "This pack reads the USA cartridge (AAME).", visibleIf="$wrongRom")])
root = box("main", [
    box("waiting", [waiting], visibleIf="$waiting"),
    box("ready", [
        box("shell", [box("nav", [*[navplate(*n) for n in NAV]]),
                      box("stage-w", [{"type": "pages", "class": "stage", "initial": "status", "pages": [{"name": n, "child": c} for n, c in pages]}])]),
        button("toast", [{"set": {"toastHide": "{toast.id}", "card": "{toast.card}", "magic": "{toast.magic}"}}, {"navigate": "{toast.page}"}],
               [img("toast-img", "$toast.img"), box("toast-t", [text("toast-title", "{toast.title}"), text("toast-name", "{toast.name}"), text("toast-sub", "{toast.sub}")]),
                button("toast-x", [{"set": {"toastHide": "{toast.id}"}}], [text("toast-x-t", "X")])], visibleIf="$toastOn"),
    ], visibleIf="$ready"),
], id="screen")

if __name__ == "__main__":
    json.dump(root, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
    print("ok", len(json.dumps(root)))
