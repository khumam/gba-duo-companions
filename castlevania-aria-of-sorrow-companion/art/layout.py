#!/usr/bin/env python3
"""Writes layout.json for the Aria of Sorrow companion 0.4.0 (design: .idea/plans/cv-design2 in the app repo, aos-*.png).
The game's own pause screen, re-laid for a touch screen:
  * left: the game's command panel (dark red, Soma's portrait, LV, the page words, the white glove on the open page),
  * top: the silver scroll plaque with the page name,
  * thin white outlined boxes for data, list rows on full-width dark-red bands (two columns), the quill-cornered message box
    at the bottom that holds the page's text and its one action.
Same data as 0.2.x/0.3.x (main.lua only gained two nav flags). The 0.2/0.3 source is in art/v2/.
    python3 art/layout.py && python3 art/css.py"""
import json, os

here = os.path.dirname(os.path.abspath(__file__))


def box(cls, ch=(), **kw):      return {"type": "box", "class": cls, "children": list(ch), **kw}
def text(cls, t, **kw):         return {"type": "text", "class": cls, "text": t, **kw}
def img(cls, src, **kw):        return {"type": "image", "class": cls, "src": src, **kw}
def button(cls, on, ch, **kw):  return {"type": "button", "class": cls, "onClick": on, "children": list(ch), **kw}
def lst(cls, items, tpl, **kw): return {"type": "list", "class": cls, "items": items, "template": tpl, **kw}
def bar(cls, v, mx, **kw):      return {"type": "bar", "class": cls, "value": v, "maxKey": mx, **kw}


GLOVE = "asset:game/glove.png"
grow = lambda: box("grow")


def plaque(t, extra=()):
    return box("phead", [box("plaque", [img("plaque-img", "asset:game/title.png"), text("plaque-t", t)]), grow(), *extra])


def obox(cls, ch, **kw):
    return box("obox " + cls, ch, **kw)


def message(kids, actions=()):
    """the quill-cornered message box: the page's one text zone and its action"""
    return box("msg", [box("quill-dots"), box("quill-hook"), box("msg-body", kids), box("msg-act", list(actions))])


def act(label, on, can, done_label, done):
    return [button("abtn", on, [text("abtn-t", label)], visibleIf=can), box("abtn off", [text("abtn-t", done_label)], visibleIf=done)]


def glove_row(on, kids, **kw):
    """a list row on the red band: the glove marks the picked one"""
    return button("brow", on, [box("bglove-w", [img("bglove", GLOVE, visibleIf="$sel")]), *kids], **kw)


# ---- STATUS ------------------------------------------------------------------------------------------------------------------------
statline = lambda lab, key: box("sline", [text("lab", lab), grow(), text("num", "{st.%s}" % key)])
status = box("page page-status", [
    plaque("STATUS"),
    obox("hp", [
        box("barrow", [text("lab hp-l", "HP"), bar("hpbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"}), text("num bar-n", "{st.hpText}")]),
        box("barrow", [text("lab mp-l", "MP"), bar("mpbar", "$st.mp", "$st.maxMp"), text("num bar-n", "{st.mpText}")]),
        box("sline", [text("lab", "STATUS /"), text("lab good", "GOOD")]),
    ]),
    obox("stats", [
        box("stats-l", [statline("STR", "str"), statline("CON", "con"), statline("INT", "int"), statline("LCK", "lck")]),
        box("stats-r", [box("bigline", [text("lab att-l", "ATT"), grow(), text("big", "{st.att}")]),
                        box("bigline", [text("lab def-l", "DEF"), grow(), text("big", "{st.def}")])]),
    ]),
    box("exp", [box("exp-l", [text("lab", "EXP"), text("lab", "NEXT")]), grow(), box("exp-r", [text("num", "{st.exp}"), text("num", "{st.next}")])]),
    obox("trg", [box("trg-c", [text("lab", "TIME"), text("num", "{st.time}")]),
                 box("trg-c", [text("lab", "RATE"), text("num", "{st.rate}")]),
                 box("trg-c", [text("lab gold-l", "GOLD"), text("num gold", "{st.gold}")])]),
    message([text("msg-t", "{heal.name}")],
            [button("abtn", [{"call": "quickHeal"}], [text("abtn-t", "HEAL")], visibleIf="$heal.can"),
             box("abtn off", [text("abtn-t", "HEAL")], visibleIf="$heal.full"),
             box("abtn off", [text("abtn-t", "HEAL")], visibleIf="$heal.none")]),
])

# ---- SOUL SET: the four sockets (bullet, guardian, enchant, ability), the red band, the message box --------------------------------------
sw = lambda lab, key, cls="": box("chip", [text("lab " + cls, lab), text("num", "{sw.%s.v}" % key, classIf={"up": "$sw.%s.up" % key, "down": "$sw.%s.down" % key})])
soul = box("page", [
    plaque("SOUL SET"),
    lst("socks", "$soulTabs", button("sock", [{"set": {"soulCat": "{c}", "soul": -1, "abil": -1}}],
                                     [img("sock-orb", "$big"), text("sock-n", "{badge}")], classIf={"on": "$sel"})),
    box("band", [
        lst("blist", "$soulList", glove_row([{"set": {"soul": "{id}"}}],
                                            [img("borb", "$orb"), text("bname", "{name}"), grow(), text("lab bset", "SET", visibleIf="$equipped"), text("bnum", "{count}")],
                                            classIf={"sel": "$sel", "eqd": "$equipped"}), visibleIf="$notAbil"),
        lst("blist", "$abilList", glove_row([{"set": {"abil": "{i}"}}, {"call": "toggleAbility", "args": ["{i}"]}],
                                            [img("borb", "$orb"), text("bname", "{name}"), grow(),
                                             box("pill on", [text("pill-t", "ON")], visibleIf="$on"), box("pill off", [text("pill-t", "OFF")], visibleIf="$off")],
                                            classIf={"sel": "$sel", "locked": "$locked"}), visibleIf="$isAbil"),
    ]),
    box("msgwrap", [message([
        box("mrow", [box("cost", [text("cost-n", "{soulPick.costN}"), text("cost-u", "USE")], visibleIf="$soulPick.hasCost"),
                     box("mtext", [text("msg-name", "{soulPick.name}"), text("msg-t", "{soulPick.desc}"), text("msg-x", "{soulPick.from}")])]),
        box("chips", [sw("ATT", "att", "att-l"), sw("DEF", "def", "def-l")]),
    ], act("SET", [{"call": "setSoul", "args": ["{soulPick.cat}", "{soulPick.id}"]}], "$soulPick.canSet", "IN USE", "$soulPick.isSet"))], visibleIf="$notAbil"),
    box("msgwrap", [message([box("mtext", [text("msg-name", "{abilPick.name}"), text("msg-t", "{abilPick.desc}")])])], visibleIf="$isAbil"),
])

# ---- EQUIP ----------------------------------------------------------------------------------------------------------------------------------
equip = box("page page-equip", [
    plaque("EQUIP"),
    lst("socks", "$eqSlots", button("sock", [{"set": {"eqSlot": "{i}", "eqItem": -1}}],
                                    [img("sock-ic", "$icon"), text("lab sock-l", "{label}")], classIf={"on": "$sel"})),
    box("band", [
        lst("blist", "$eqList", glove_row([{"set": {"eqItem": "{idx}"}}], [img("bicon", "$icon"), text("bname", "{name}"), grow(), text("bnum", "{count}")],
                                          classIf={"sel": "$sel"})),
        text("empty", "Nothing to change to.", visibleIf="$eqEmpty"),
    ]),
    message([
        box("mrow", [img("micon", "$eqPick.icon"), box("mtext", [text("msg-name", "{eqPick.name}"), text("msg-t", "{eqPick.desc}"), text("msg-x", "{eqPick.stats}")])]),
        box("chips", [sw("ATT", "att", "att-l"), sw("DEF", "def", "def-l"), sw("STR", "str"), sw("CON", "con"), sw("INT", "int"), sw("LCK", "lck")]),
    ], [*act("EQUIP", [{"call": "equip", "args": ["{eqPick.slot}", "{eqPick.idx}"]}], "$eqPick.canSet", "WORN", "$eqPick.isSet"),
        box("abtn off", [text("abtn-t", "NONE")], visibleIf="$eqPick.notOwned")]),
])

# ---- ITEM USE -----------------------------------------------------------------------------------------------------------------------------
items = box("page", [
    plaque("ITEM USE"),
    obox("hp", [
        box("barrow", [text("lab hp-l", "HP"), bar("hpbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"}), text("num bar-n", "{st.hpText}")]),
        box("barrow", [text("lab mp-l", "MP"), bar("mpbar", "$st.mp", "$st.maxMp"), text("num bar-n", "{st.mpText}")]),
    ]),
    box("tabs", [button("tab", [{"set": {"itemTab": "use", "item": -1}}], [text("lab tab-t", "ITEMS")], classIf={"on": "$itemUseTab"}),
                 button("tab", [{"set": {"itemTab": "key", "item": -1}}], [text("lab tab-t", "KEY ITEMS")], classIf={"on": "$itemKeyTab"}),
                 grow(), text("count", "{itemCount}")]),
    box("band", [
        lst("blist", "$itemList", glove_row([{"set": {"item": "{i}"}}], [img("bicon", "$icon"), text("bname", "{name}"), grow(), text("bnum", "{count}")],
                                            classIf={"sel": "$sel"})),
        text("empty", "No items here.", visibleIf="$itemEmpty"),
    ]),
    message([box("mrow", [img("micon", "$itemPick.icon"), box("mtext", [text("msg-name", "{itemPick.name}"), text("msg-t", "{itemPick.desc}"),
                                                                       text("msg-x", "{itemPick.effect}")])])],
            [*act("USE", [{"call": "useItem", "args": ["{itemPick.i}"]}], "$itemPick.canUse", "FULL", "$itemPick.full"),
             box("abtn off", [text("abtn-t", "NONE")], visibleIf="$itemPick.notOwned")]),
])

# ---- MAP: the game's SELECT map with Soma on it -----------------------------------------------------------------------------------------
cmap = box("page", [
    plaque("MAP", [text("num map-rate", "{st.rate}")]),
    box("mapwrap", [
        box("mapwin", [box("mapbox", [lst("ml m-fill", "$mapFill", text("mt", "{t}")), lst("ml m-save", "$mapSave", text("mt", "{t}")),
                                  lst("ml m-warp", "$mapWarp", text("mt", "{t}")), lst("ml m-walls", "$mapWalls", text("mt", "{t}")),
                                  lst("ml m-doors", "$mapDoors", text("mt", "{t}")),
                                  box("me", [box("me-in")], bindStyle={"left": "{me.left}", "top": "{me.top}"}, visibleIf="$me.on")])], zoom={"min": 1, "max": 4, "state": "mapZoom"}),
        # pinch / drag the map, or the - / + keys on its corner (app 1.0.3+; older apps show it at 1x)
        box("zoom-ctl", [button("zoom-key", {"zoom": "out", "state": "mapZoom"}, [text("zoom-key-t", "-")]),
                         button("zoom-key", {"zoom": "in", "state": "mapZoom"}, [text("zoom-key-t", "+")])])]),
    obox("mapfoot", [text("lab", "YOU"), text("num", "{meText}"), grow(), text("lab", "ROOMS"), text("num gold", "{mapCells}")]),
])

# ---- ENEMY DATA: the parchment book --------------------------------------------------------------------------------------------------
enemy = box("page", [
    plaque("ENEMY"),
    box("paper", [
        box("bookhead", [text("bk-h", "ENEMY DATA")]),
        box("bookhead2", [text("bk-lab", "SEEN"), text("bk-val", "{enemySeen}"), grow(), text("bk-lab", "SOUL"), text("bk-val", "{st.soulRate}")]),
        lst("elist", "$enemyRows", button("erow", [{"set": {"enemy": "{k}"}}, {"navigate": "enemyDetail"}],
                                          [text("eno", "{no}"), text("ename", "{name}")], classIf={"unseen": "$unseen"})),
        grow(),
        box("pager", [button("pgbtn", [{"set": {"epage": "{epagePrev}"}}], [img("key-i", "asset:game/key-L.png"), text("pg-t", "PREV")]),
                      text("pg-n", "{epageText}"),
                      button("pgbtn", [{"set": {"epage": "{epageNext}"}}], [text("pg-t", "NEXT"), img("key-i", "asset:game/key-R.png")])]),
    ]),
])

enemy_detail = box("page", [
    plaque("ENEMY"),
    box("paper", [
        box("bookhead", [text("bk-h", "NO. {ed.no}"), grow(), text("ed-name", "{ed.name}")]),
        box("edtop", [
            box("edframe", [img("ed-frame", "asset:ui/book-frame.png"), img("ed-orb", "$ed.orbBig")]),
            box("edinfo", [
                box("pairline", [text("bk-lab", "HP"), text("ed-v", "{ed.hp}"), text("bk-lab", "EXP"), text("ed-v", "{ed.exp}")]),
                box("pairline", [text("bk-lab", "SOUL"), img("ed-sorb", "$ed.orb"),
                                 button("ed-link", [{"set": {"soulCat": "{ed.soulLink.cat}", "soul": "{ed.soulLink.soul}", "abil": "{ed.soulLink.abil}"}},
                                                    {"navigate": "{ed.soulLink.page}"}],
                                        [text("ed-soul", "{ed.soul}", classIf={"owned": "$ed.soulOwned"})], classIf={"dead": "$ed.unseen"})]),
                box("pairline", [text("bk-lab", "TOL"), lst("eltags", "$ed.tol", img("el", "$icon")), text("ed-none", "---", visibleIf="$ed.noTol")]),
                box("pairline", [text("bk-lab", "WEAK"), lst("eltags", "$ed.weak", img("el", "$icon")), text("ed-none", "---", visibleIf="$ed.noWeak")]),
                box("pairline", [text("bk-lab", "DROP"),
                                 button("ed-link", [{"set": {"eqSlot": "{ed.l1.eqSlot}", "eqItem": "{ed.l1.eqItem}", "item": "{ed.l1.item}", "itemTab": "{ed.l1.itemTab}"}},
                                                    {"navigate": "{ed.l1.page}"}], [text("ed-drop", "{ed.drop1}")], visibleIf="$ed.l1.ok"),
                                 text("ed-drop", "{ed.drop1}", visibleIf="$ed.l1.off"),
                                 button("ed-link", [{"set": {"eqSlot": "{ed.l2.eqSlot}", "eqItem": "{ed.l2.eqItem}", "item": "{ed.l2.item}", "itemTab": "{ed.l2.itemTab}"}},
                                                    {"navigate": "{ed.l2.page}"}], [text("ed-drop", "{ed.drop2}")], visibleIf="$ed.l2.ok"),
                                 text("ed-drop", "{ed.drop2}", visibleIf="$ed.l2.off")]),
            ]),
        ]),
        text("ed-desc", "{ed.desc}"),
        grow(),
        box("pager", [button("pgbtn", [{"set": {"enemy": "{ed.prev}"}}], [text("pg-t", "< NO. {ed.prevNo}")]),
                      button("pgbtn", [{"set": {"epage": "{ed.page}"}}, {"navigate": "enemy"}], [text("pg-t", "LIST")]),
                      button("pgbtn", [{"set": {"enemy": "{ed.next}"}}], [text("pg-t", "NO. {ed.nextNo} >")])]),
    ]),
])

# ---- CONFIG: the game's button screen -----------------------------------------------------------------------------------------------------
config = box("page", [
    plaque("CONFIG"),
    obox("cfg", [lst("cfglist", "$cfgRows", box("crow", [
        text("lab clab", "{label}"), grow(),
        button("carr", [{"call": "cycleKey", "args": ["{row}", -1]}], [text("carr-t", "<")]),
        box("ckey-w", [img("ckey", "$keyImg")]),
        button("carr", [{"call": "cycleKey", "args": ["{row}", 1]}], [text("carr-t", ">")]),
    ]))]),
    text("clash", "The control settings are conflicting.", visibleIf="$cfgClash"),
    message([box("mtext", [text("msg-t", "Tap the arrows to change a button. Two actions never share one: they swap."),
                           text("msg-x", "Game changes: {_writePermLabel}")])],
            [button("abtn", [{"call": "defaultKeys"}], [text("abtn-t", "DEFAULT")]), button("abtn", [{"call": "writePermission"}], [text("abtn-t", "ALLOW")])]),
])

# ---- shell: the command panel ----------------------------------------------------------------------------------------------------------------
NAV = [("status", "STATUS", "onStatus"), ("soul", "SOUL SET", "onSoul"), ("equip", "EQUIP", "onEquip"), ("items", "ITEM USE", "onItems"),
       ("map", "MAP", "onMap"), ("enemy", "ENEMY", "onEnemy"), ("config", "CONFIG", "onConfig")]
navrow = lambda p, label, flag: button("nrow", [{"navigate": p}], [box("nglove-w", [img("nglove", GLOVE, visibleIf="$" + flag)]), text("nrow-t", label)],
                                       classIf={"on": "$" + flag})
command = box("cmd", [
    box("cmd-top", [img("cmd-port", "asset:game/portrait-soma.png"), text("cmd-lv", "LV.{st.level}")]),
    *[navrow(*n) for n in NAV],
])

pages = [("status", status), ("soul", soul), ("equip", equip), ("items", items), ("map", cmap), ("enemy", enemy), ("enemyDetail", enemy_detail), ("config", config)]
waiting = box("wait", [img("wait-orb", "asset:game/orbbig-red.png"), text("wait-1", "ARIA OF SORROW"), text("wait-2", "COMPANION"),
                       text("wait-3", "Load a save to see Soma's souls."), text("wait-4", "This pack reads the USA cartridge (A2CE).", visibleIf="$wrongRom")])
root = box("main", [
    box("waiting", [waiting], visibleIf="$waiting"),
    box("ready", [
        box("shell", [command, box("stage-w", [{"type": "pages", "class": "stage", "initial": "status", "pages": [{"name": n, "child": c} for n, c in pages]}])]),
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
