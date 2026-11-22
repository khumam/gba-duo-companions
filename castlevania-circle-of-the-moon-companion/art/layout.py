#!/usr/bin/env python3
"""Writes layout.json: Circle of the Moon's pause menu (Status, DSS, Item, Card, Magic Item, Config) plus the castle
Map, joined by left / right plates. Draws every frame / pill size it uses (art/ui.py). Edit here, not layout.json:
    python3 art/layout.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ui  # noqa: E402


def box(cls, ch=(), **kw): return {"type": "box", "class": cls, "children": list(ch), **kw}
def text(cls, t, **kw): return {"type": "text", "class": cls, "text": t, **kw}
def img(cls, src, **kw): return {"type": "image", "class": cls, "src": src, **kw}
def button(cls, on, ch, **kw): return {"type": "button", "class": cls, "onClick": on, "children": list(ch), **kw}
def lst(cls, items, tpl, **kw): return {"type": "list", "class": cls, "items": items, "template": tpl, **kw}
def bar(cls, value, mx, **kw): return {"type": "bar", "class": cls, "value": value, "maxKey": mx, **kw}


DONE = set()


def fr(w, h, cls):
    if ("f", w, h) not in DONE:
        DONE.add(("f", w, h))
        ui.frame(w, h)
    return img(f"win {cls}", f"asset:ui/fr-{w}x{h}.png")


def pl(w, h, cls, left=True):
    if ("p", w, h, left) not in DONE:
        DONE.add(("p", w, h, left))
        ui.pill(w, h, left=left)
    return img(f"win {cls}", f"asset:ui/pl-{w}x{h}{'' if left else '-e'}.png")


PAGES = [("status", "Status"), ("dss", "DSS"), ("item", "Item"), ("card", "Card"), ("magic", "Magic Item"),
         ("config", "Config"), ("map", "Map")]


def nav(i):
    prev, nxt = PAGES[(i - 1) % len(PAGES)], PAGES[(i + 1) % len(PAGES)]
    pips = [img("pip", "asset:ui/pip-on.png" if k == i else "asset:ui/pip.png") for k in range(len(PAGES))]
    return [
        button("nbtn nbtn-l", [{"navigate": prev[0]}], [img("nplate", "asset:ui/nav-l.png"), text("nb nb-l", prev[1].upper())]),
        box("nmid", [img("nplate-m", "asset:ui/nav-mid.png"), text("ntitle", PAGES[i][1].upper()), box("pips", pips)]),
        button("nbtn nbtn-r", [{"navigate": nxt[0]}], [img("nplate", "asset:ui/nav-r.png"), text("nb nb-r", nxt[1].upper())]),
    ]


def title(t):
    return [img("tplate", "asset:ui/title.png"), text("ttext", t)]


def page(name, children, i=None):
    kids = [img("bg", "asset:ui/bg.png")] + children
    if i is not None:
        kids += nav(i)
    return box(f"page page-{name}", kids)


def act_button(cls, label, on, can, done_label, done):
    return [button(f"abtn {cls}", on, [img("abtn-p", "asset:ui/btn.png"), text("abtn-t", label)], visibleIf=can),
            box(f"abtn {cls} abtn-done", [img("abtn-p", "asset:ui/btn-off.png"), text("abtn-t", done_label)], visibleIf=done)]


def note():
    return text("note", "{note}")


# ---- status: the pause screen ------------------------------------------------------------------
status = page("status", [
    pl(108, 11, "p-whip", left=False), text("lab whip", "VAMPIREKILLER"),
    pl(110, 11, "p-time"), text("lab time-l", "TIME"), text("val time", "{st.time}"),
    pl(68, 11, "p-lv", left=False), text("lab lv-l", "LV"), text("val lv", "{st.level}"),
    pl(110, 11, "p-rate"), text("lab rate-l", "RATE"), text("val rate", "{st.rate}"),
    fr(72, 40, "f-stats"),
    text("lab s1", "STR"), text("val s1v", "{st.str}"),
    text("lab s2", "DEF"), text("val s2v", "{st.def}"),
    text("lab s3", "INT"), text("val s3v", "{st.int}"),
    text("lab s4", "LCK"), text("val s4v", "{st.lck}"),
    pl(72, 11, "p-good", left=False), text("lab good", "STATUS/GOOD"),
    img("moon", "asset:ui/moon.png"), text("lab nathan", "NATHAN"),
    fr(110, 44, "f-hp"),
    text("lab hp-l", "HP"), text("val hp", "{st.hpText}"), bar("hpbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"}),
    text("lab mp-l", "MP"), text("val mp", "{st.mpText}"), bar("mpbar", "$st.mp", "$st.maxMp"),
    text("lab ht-l", "HEART"), text("val ht", "{st.heartText}"), bar("htbar", "$st.heart", "$st.maxHeart"),
    fr(110, 28, "f-exp"),
    text("lab ex-l", "EXP"), text("val ex", "{st.exp}"), text("lab nx-l", "NEXT"), text("val nx", "{st.next}"),
    bar("expbar", "$st.expIn", "$st.expSpan"),
    # the menu tabs open their page
    lst("menu", "$menu", button("mtab", [{"navigate": "{page}"}], [img("mtab-p", "asset:ui/menu.png"), text("mtab-t", "{label}")])),
    # current DSS + gear, tappable
    fr(174, 48, "f-now"),
    button("dsstap", [{"set": {"pickAttr": -1, "pickAct": -1}}, {"navigate": "dss"}], [
        img("now-c1", "$dssNow.actImg"), img("now-c2", "$dssNow.attrImg"),
        text("now-a", "{dssNow.action}"), text("now-b", "+ {dssNow.attr}"),
        text("now-cost", "{dssNow.costN} {dssNow.costU}"), text("now-t", "{dssNow.text}")]),
    lst("glist", "$gear", button("grow", [{"set": {"itemTab": "{slot}", "itemId": -1}}, {"navigate": "item"}],
                                [text("glab", "{label}"), text("gname", "{name}")], classIf={"none": "$none"})),
    button("hbtn", [{"call": "quickHeal", "args": ["{heal.id}"]}], [img("abtn-p", "asset:ui/btn.png"), text("abtn-t", "HEAL")], visibleIf="$heal.can"),
    box("hbtn abtn-done", [img("abtn-p", "asset:ui/btn-off.png"), text("abtn-t", "HEAL")], visibleIf="$heal.off"),
    text("hname", "{heal.name}"),
], 0)

# ---- DSS ---------------------------------------------------------------------------------------
def card_row(cls, items, key, label_t):
    return lst(cls, items, button("crd", [{"set": {key: "{i}"}}], [img("crd-i", "$img")],
                                 classIf={"sel": "$sel", "set": "$set", "locked": "$locked"}))


dss = page("dss", [
    *title("DSS"),
    text("lab rowlab rl-act", "ACTION"), text("lab rowlab rl-attr", "ATTRIBUTE"),
    pl(66, 11, "p-act", left=False), text("lab pname pn-act", "{dssPick.action}"),
    pl(66, 11, "p-attr", left=False), text("lab pname pn-attr", "{dssPick.attr}"),
    card_row("crow cr-act", "$dssActs", "pickAct", ""),
    card_row("crow cr-attr", "$dssAttrs", "pickAttr", ""),
    box("rule", []),
    pl(44, 20, "p-cost"), text("cost-n", "{dssPick.costN}"), text("cost-u", "{dssPick.costU}"),
    text("dtext", "{dssPick.text}"),
    *act_button("dset", "SET", [{"call": "setDss", "args": ["{dssPick.attr1}", "{dssPick.act1}"]}], "$dssPick.canSet", "IN USE", "$dssPick.isSet"),
    text("lab tip", "Tap a card in each row, then SET. Press DSS in the game to use it."),
    note(),
], 1)

# ---- item --------------------------------------------------------------------------------------
item = page("item", [
    *title("ITEM"),
    lst("itabs", "$itemTabs", button("itab", [{"set": {"itemTab": "{i}", "itemId": -1}}], [
        img("itab-p", "asset:ui/menu.png"),
        img("itab-on", "asset:ui/menu-on.png", visibleIf="$sel"),
        text("itab-eqp", "EQP", visibleIf="$eqp"), text("itab-t", "{label}"), text("itab-n", "{name}")], classIf={"sel": "$sel"})),
    fr(108, 30, "f-ihp"),
    text("lab ih-l", "HP"), text("val ih", "{st.hpText}"),
    text("lab im-l", "MP"), text("val im", "{st.mpText}"),
    text("lab it-l", "HEART"), text("val it", "{st.heartText}"),
    fr(108, 40, "f-ist"),
    *[x for k, n in enumerate(["str", "def", "int", "lck"]) for x in (
        text(f"lab is{k}", n.upper()), text(f"val is{k}v", "{sw.%s.v}" % n),
        text(f"val is{k}t", "> {sw.%s.to}" % n, visibleIf="$sw.%s.cmp" % n, classIf={"up": "$sw.%s.up" % n, "down": "$sw.%s.down" % n}))],
    pl(72, 11, "p-igood"), text("lab igood", "STATUS/GOOD"),
    box("band", [lst("blist", "$itemList", button("cell", [{"set": {"itemId": "{id}"}}],
                                                  [text("cname", "{name}"), text("ccount", "{count}")], classIf={"sel": "$sel"}))]),
    text("band-empty", "Nothing here.", visibleIf="$itemEmpty"),
    box("rule rule-i", []),
    text("iname", "{ipick.name}"), text("idesc", "{ipick.desc}"), text("ibonus", "{ipick.bonus}"),
    *act_button("iset", "EQUIP", [{"call": "equip", "args": ["{ipick.tab}", "{ipick.id}"]}], "$ipick.canSet", "WORN", "$ipick.isSet"),
    *act_button("iuse", "USE", [{"call": "useItem", "args": ["{ipick.id}"]}], "$ipick.canUse", "FULL", "$ipick.full"),
    note(),
], 2)

# ---- card --------------------------------------------------------------------------------------
card = page("card", [
    *title("CARD"),
    text("lab rowlab rl-act2", "ACTION"), text("lab rowlab rl-attr2", "ATTRIBUTE"),
    lst("crow cr-act2", "$cardActs", button("crd", [{"set": {"card": "{k}"}}], [img("crd-i", "$img")], classIf={"sel": "$sel"})),
    lst("crow cr-attr2", "$cardAttrs", button("crd", [{"set": {"card": "{k}"}}], [img("crd-i", "$img")], classIf={"sel": "$sel"})),
    fr(132, 70, "f-cards"),
    pl(82, 11, "p-cname"), text("lab cname-t", "{cardPick.name}"),
    img("cbig", "$cardPick.img"),
    text("lab ckind", "{cardPick.kind}"), text("ccount-t", "{cardCount}"),
    box("rule rule-c", []),
    text("cdesc", "{cardPick.desc}"),
], 3)

# ---- magic item --------------------------------------------------------------------------------
magic = page("magic", [
    *title("MAGIC ITEM"),
    lst("mlist", "$magicList", button("mcell", [{"set": {"magic": "{i}"}}], [
        img("mc-p", "asset:ui/pl-100x13.png"), img("mc-i", "$icon"), text("mc-t", "{name}")], classIf={"sel": "$sel", "locked": "$locked"})),
    box("rule rule-m", []),
    box("mpic", [img("mpic-i", "$magicPick.icon")]),
    text("mname", "{magicPick.name}"), text("mdesc", "{magicPick.desc}"),
], 4)
ui.pill(100, 13)

# ---- config ------------------------------------------------------------------------------------
config = page("config", [
    *title("CONFIG"),
    lst("cfglist", "$cfgRows", box("crow2", [
        img("cf-p", "asset:ui/pl-80x13.png"), text("clab", "{label}"),
        button("carr carr-l", [{"call": "cycleKey", "args": ["{row}", -1]}], [text("carr-t", "<")]),
        img("ckey", "$keyImg"),
        button("carr carr-r", [{"call": "cycleKey", "args": ["{row}", 1]}], [text("carr-t", ">")]),
    ])),
    text("cfg-clash", "Buttons are duplicated", visibleIf="$cfgClash"),
    box("rule rule-cf", []),
    text("cfg-help", "Change button configuration"),
    button("obtn", [{"call": "defaultKeys"}], [img("abtn-p", "asset:ui/btn.png"), text("abtn-t", "DEFAULT")]),
    button("perm", [{"call": "writePermission"}], [text("perm-t", "GAME CHANGES: {_writePermLabel}")]),
    note(),
], 5)
ui.pill(80, 13)

# ---- map ---------------------------------------------------------------------------------------
cmap = page("map", [
    *title("MAP"),
    pl(70, 11, "p-mrate"), text("lab mrate-l", "RATE"), text("val mrate", "{st.rate}"),
    box("mapbox", [lst("maprows", "$mapRuns", box("run", [box("run-in", [])], bindStyle={"left": "{x}", "top": "{y}", "width": "{w}"}))]),
], 6)

# ---- waiting -----------------------------------------------------------------------------------
waiting = page("waiting", [
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
                         [img("toast-img", "$toast.img"), text("toast-title", "{toast.title}"), text("toast-name", "{toast.name}"),
                          text("toast-sub", "{toast.sub}"),
                          button("toast-x", [{"set": {"toastHide": "{toast.id}"}}], [text("toast-x-t", "X")])], visibleIf="$toastOn")],
        visibleIf="$ready")], id="screen")

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    json.dump(root, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
    print("ok", len(json.dumps(root)), sorted(DONE))
