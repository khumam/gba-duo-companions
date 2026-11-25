#!/usr/bin/env python3
"""Writes layout.json: Circle of the Moon's pause menu, simplified. Same colours, art and data as before (originals: art/orig/), but each
page is a title tab, ONE scrolling body of plain panels and rows, and the left / right plates fixed at the bottom. Nothing is placed by
coordinates and no frame images are drawn, so text never overlaps and long lists simply scroll.
    python3 art/layout.py
"""
import json
import os


def box(cls, ch=(), **kw): return {"type": "box", "class": cls, "children": list(ch), **kw}
def text(cls, t, **kw): return {"type": "text", "class": cls, "text": t, **kw}
def img(cls, src, **kw): return {"type": "image", "class": cls, "src": src, **kw}
def button(cls, on, ch, **kw): return {"type": "button", "class": cls, "onClick": on, "children": list(ch), **kw}
def lst(cls, items, tpl, **kw): return {"type": "list", "class": cls, "items": items, "template": tpl, **kw}
def bar(cls, value, mx, **kw): return {"type": "bar", "class": cls, "value": value, "maxKey": mx, **kw}


PAGES = [("status", "Status"), ("dss", "DSS"), ("item", "Item"), ("card", "Card"), ("magic", "Magic Item"),
         ("config", "Config"), ("map", "Map")]


def nav(i):
    prev, nxt = PAGES[(i - 1) % len(PAGES)], PAGES[(i + 1) % len(PAGES)]
    pips = [img("pip", "asset:ui/pip-on.png" if k == i else "asset:ui/pip.png") for k in range(len(PAGES))]
    return box("nav", [
        button("nbtn", [{"navigate": prev[0]}], [img("nplate", "asset:ui/nav-l.png"), text("nb nb-l", prev[1].upper())]),
        box("nmid", [img("nplate-m", "asset:ui/nav-mid.png"), text("ntitle", PAGES[i][1].upper()), box("pips", pips)]),
        button("nbtn", [{"navigate": nxt[0]}], [img("nplate", "asset:ui/nav-r.png"), text("nb nb-r", nxt[1].upper())]),
    ])


def title(t):
    return box("title", [img("tplate", "asset:ui/title.png"), text("ttext", t)])


def page(name, body, i):
    return box(f"page page-{name}", [title(PAGES[i][1].upper()), box("body", body), nav(i)])


def panel(ch, cls=""): return box(("panel " + cls).strip(), ch)
def pair(label, value, cls=""): return box("pair", [text("lab", label), text("val " + cls, value)])
def barrow(label, value, b): return box("barrow", [text("lab", label), b, text("val bn", value)])
def note(): return text("note", "{note}")


def act_button(cls, label, on, can, done_label, done):
    return [button(f"abtn {cls}", on, [text("abtn-t", label)], visibleIf=can),
            box(f"abtn {cls} abtn-done", [text("abtn-t", done_label)], visibleIf=done)]


# ---- status: the pause screen ------------------------------------------------------------------
status = page("status", [
    box("hero", [
        box("moonwrap", [img("moon", "asset:ui/moon.png"), text("lab nathan", "NATHAN")]),
        box("hero-in", [
            box("namerow", [text("lab whip", "VAMPIREKILLER"), box("grow", []), text("lab lv-l", "LV"), text("val lv", "{st.level}")]),
            barrow("HP", "{st.hpText}", bar("hpbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"})),
            barrow("MP", "{st.mpText}", bar("mpbar", "$st.mp", "$st.maxMp")),
            barrow("HEART", "{st.heartText}", bar("htbar", "$st.heart", "$st.maxHeart")),
        ]),
    ]),
    panel([box("strip-row", [pair("STR", "{st.str}"), pair("DEF", "{st.def}")]),
           box("strip-row", [pair("INT", "{st.int}"), pair("LCK", "{st.lck}")]),
           text("lab", "STATUS/GOOD")]),
    box("strip-row wide", [panel([pair("TIME", "{st.time}"), pair("RATE", "{st.rate}")], "half"),
                           panel([pair("EXP", "{st.exp}"), pair("NEXT", "{st.next}"), bar("expbar", "$st.expIn", "$st.expSpan")], "half")]),
    button("dsspanel", [{"set": {"pickAttr": -1, "pickAct": -1}}, {"navigate": "dss"}], [
        box("dssrow", [img("now-c", "$dssNow.actImg"), img("now-c", "$dssNow.attrImg"),
                       box("dsstext", [text("now-a", "{dssNow.action}"), text("now-b", "+ {dssNow.attr}")]), box("grow", []),
                       text("now-cost", "{dssNow.costN} {dssNow.costU}")]),
        text("now-t", "{dssNow.text}")]),
    panel([text("lab", "EQUIPMENT"),
           lst("glist", "$gear", button("grow2", [{"set": {"itemTab": "{slot}", "itemId": -1}}, {"navigate": "item"}],
                                       [text("glab", "{label}"), text("gname", "{name}")], classIf={"none": "$none"}))]),
    box("healrow", [
        button("hbtn", [{"call": "quickHeal", "args": ["{heal.id}"]}], [text("abtn-t", "HEAL")], visibleIf="$heal.can"),
        box("hbtn abtn-done", [text("abtn-t", "HEAL")], visibleIf="$heal.off"), text("hname", "{heal.name}")]),
    text("lab", "MENU"),
    lst("menu", "$menu", button("mbtn", [{"navigate": "{page}"}], [text("mtab-t", "{label}")])),
], 0)

# ---- DSS ---------------------------------------------------------------------------------------
def card_row(cls, items, key):
    return lst(cls, items, button("crd", [{"set": {key: "{i}"}}], [img("crd-i", "$img")],
                                  classIf={"sel": "$sel", "set": "$set", "locked": "$locked"}))


dss = page("dss", [
    box("rowhead", [text("lab", "ACTION"), box("grow", []), text("pname", "{dssPick.action}")]),
    card_row("crow act", "$dssActs", "pickAct"),
    box("rowhead", [text("lab", "ATTRIBUTE"), box("grow", []), text("pname attr", "{dssPick.attr}")]),
    card_row("crow attr", "$dssAttrs", "pickAttr"),
    panel([box("dtop", [box("dcost", [text("cost-n", "{dssPick.costN}"), text("cost-u", "{dssPick.costU}")]), box("grow", []),
                        *act_button("dset", "SET", [{"call": "setDss", "args": ["{dssPick.attr1}", "{dssPick.act1}"]}], "$dssPick.canSet", "IN USE", "$dssPick.isSet")]),
           text("dtext", "{dssPick.text}"), note()]),
    text("tip", "Tap a card in each row, then SET. Press DSS in the game to use it."),
], 1)

# ---- item --------------------------------------------------------------------------------------
item = page("item", [
    lst("itabs", "$itemTabs", button("itab", [{"set": {"itemTab": "{i}", "itemId": -1}}], [
        text("itab-eqp", "EQP", visibleIf="$eqp"), text("itab-t", "{label}"), text("itab-n", "{name}")], classIf={"sel": "$sel"})),
    box("strip-row wide", [
        panel([pair("HP", "{st.hpText}"), pair("MP", "{st.mpText}"), pair("HEART", "{st.heartText}")], "half"),
        panel([*[box("pair", [text("lab", n.upper()), text("val", "{sw.%s.v}" % n),
                              text("val to", "> {sw.%s.to}" % n, visibleIf="$sw.%s.cmp" % n, classIf={"up": "$sw.%s.up" % n, "down": "$sw.%s.down" % n})])
                for n in ("str", "def", "int", "lck")],
               text("lab", "STATUS/GOOD")], "half")]),
    box("band", [lst("blist", "$itemList", button("cell", [{"set": {"itemId": "{id}"}}],
                                                  [text("cname", "{name}"), text("ccount", "{count}")], classIf={"sel": "$sel"}))]),
    text("band-empty", "Nothing here.", visibleIf="$itemEmpty"),
    panel([box("dtop", [text("iname", "{ipick.name}"), box("grow", []),
                        *act_button("iset", "EQUIP", [{"call": "equip", "args": ["{ipick.tab}", "{ipick.id}"]}], "$ipick.canSet", "WORN", "$ipick.isSet"),
                        *act_button("iuse", "USE", [{"call": "useItem", "args": ["{ipick.id}"]}], "$ipick.canUse", "FULL", "$ipick.full")]),
           text("dtext", "{ipick.desc}"), text("ibonus", "{ipick.bonus}"), note()]),
], 2)

# ---- card --------------------------------------------------------------------------------------
card = page("card", [
    text("lab", "ACTION"),
    lst("crow act", "$cardActs", button("crd", [{"set": {"card": "{k}"}}], [img("crd-i", "$img")], classIf={"sel": "$sel"})),
    text("lab", "ATTRIBUTE"),
    lst("crow attr", "$cardAttrs", button("crd", [{"set": {"card": "{k}"}}], [img("crd-i", "$img")], classIf={"sel": "$sel"})),
    panel([box("cardrow", [img("cbig", "$cardPick.img"),
                           box("cardinfo", [text("cname-t", "{cardPick.name}"), text("lab", "{cardPick.kind}"), text("ccount-t", "{cardCount}")])]),
           text("dtext", "{cardPick.desc}")]),
], 3)

# ---- magic item --------------------------------------------------------------------------------
magic = page("magic", [
    box("mgrid", [lst("mlist", "$magicList", button("mcell", [{"set": {"magic": "{i}"}}], [
        img("mc-i", "$icon"), text("mc-t", "{name}")], classIf={"sel": "$sel", "locked": "$locked"}))]),
    panel([box("dtop", [box("mpic", [img("mpic-i", "$magicPick.icon")]), text("mname", "{magicPick.name}")]), text("dtext", "{magicPick.desc}")]),
], 4)

# ---- config ------------------------------------------------------------------------------------
config = page("config", [
    panel([lst("cfglist", "$cfgRows", box("crow2", [
        text("clab", "{label}"), box("grow", []),
        button("carr", [{"call": "cycleKey", "args": ["{row}", -1]}], [text("carr-t", "<")]),
        img("ckey", "$keyImg"),
        button("carr", [{"call": "cycleKey", "args": ["{row}", 1]}], [text("carr-t", ">")]),
    ]))]),
    text("cfg-clash", "Buttons are duplicated", visibleIf="$cfgClash"),
    text("cfg-help", "Change button configuration"),
    box("btnrow", [button("obtn", [{"call": "defaultKeys"}], [text("abtn-t", "DEFAULT")]),
                   button("perm", [{"call": "writePermission"}], [text("perm-t", "GAME CHANGES: {_writePermLabel}")])]),
    note(),
], 5)

# ---- map ---------------------------------------------------------------------------------------
cmap = page("map", [
    box("rowhead", [text("lab", "RATE"), text("val mrate", "{st.rate}")]),
    box("mapfield", [box("mapbox", [lst("maprows", "$mapRuns", box("run", [box("run-in", [])], bindStyle={"left": "{x}", "top": "{y}", "width": "{w}"}))])]),
], 6)

# ---- waiting -----------------------------------------------------------------------------------
waiting = box("page page-waiting", [
    img("w-moon", "asset:ui/moon.png"),
    text("w-1", "CIRCLE OF THE MOON"), text("w-2", "COMPANION"),
    text("w-3", "Load a save to see Nathan's cards."),
    text("w-4", "This pack reads the USA cartridge (AAME).", visibleIf="$wrongRom"),
])

body = [("status", status), ("dss", dss), ("item", item), ("card", card), ("magic", magic), ("config", config), ("map", cmap)]
root = box("main", [
    box("waiting", [waiting], visibleIf="$waiting"),
    box("ready", [{"type": "pages", "class": "stage", "initial": "status", "pages": [{"name": n, "child": c} for n, c in body]},
                  button("toast", [{"set": {"toastHide": "{toast.id}", "card": "{toast.card}", "magic": "{toast.magic}"}}, {"navigate": "{toast.page}"}],
                         [img("toast-img", "$toast.img"), box("toast-t", [text("toast-title", "{toast.title}"), text("toast-name", "{toast.name}"), text("toast-sub", "{toast.sub}")]),
                          button("toast-x", [{"set": {"toastHide": "{toast.id}"}}], [text("toast-x-t", "X")])], visibleIf="$toastOn")],
        visibleIf="$ready")], id="screen")

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    json.dump(root, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
    print("ok", len(json.dumps(root)))
