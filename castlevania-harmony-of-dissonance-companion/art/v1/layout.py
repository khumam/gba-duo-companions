#!/usr/bin/env python3
"""Writes layout.json: Harmony of Dissonance's pause menu, simplified. Same blue / green / white identity, art and data as before
(originals: art/orig/), but each page is a green title band, ONE scrolling body of plain rows and panels, and the left / right plates fixed at
the bottom. Nothing is placed by coordinates, so nothing overlaps and long lists simply scroll.
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


PAGES = [("status", "Status"), ("equip", "Equip"), ("items", "Items"), ("book", "Spell Book"), ("relics", "Relics"), ("config", "Key Config"), ("map", "Map")]


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


def page(name, body, i, head=None):
    return box(f"page page-{name}", [head or title(PAGES[i][1]), box("body", body), nav(i)])


def panel(ch, cls=""): return box(("panel " + cls).strip(), ch)
def pair(label, value, cls=""): return box("pair", [text("lab", label), text("val " + cls, value)])
def hand(): return img("hand", "asset:ui/hand.png", visibleIf="$sel")


def act_button(cls, label, on, can, done_label, done):
    return [button(f"abtn {cls}", on, [text("abtn-t", label)], visibleIf=can),
            box(f"abtn {cls} abtn-done", [text("abtn-t", done_label)], visibleIf=done)]


def info(icon_src, name, desc, extra=None, btn=None):
    kids = [box("dtop", [img("info-i", icon_src), box("dtitle", [text("info-n", name)]), *(btn or [])]), text("info-d", desc)]
    if extra:
        kids.append(text("info-x", extra))
    kids.append(text("note", "{note}"))
    return panel(kids, "info")


# ---- status ------------------------------------------------------------------------------------
status = page("status", [
    box("hero", [
        box("crestwrap", [img("crest", "asset:ui/crest.png"),
                          button("bookslot", [{"navigate": "book"}], [box("bk-frame", [img("bk-img", "$bookNow.img")]), text("lab bk-l", "BOOK")])]),
        box("hero-in", [
            box("strip-row", [pair("LEVEL", "{st.level}"), pair("GOLD", "{st.gold}", "gold")]),
            pair("EXP", "{st.exp}"), pair("NEXT", "{st.next}"),
            bar("expbar", "$st.expIn", "$st.expSpan"),
            pair("TIME", "{st.time}"),
        ]),
    ]),
    panel([pair("HP", "{st.hpText}"), pair("MP", "{st.mpText}"), pair("HEART", "{st.heartText}")]),
    panel([box("strip-row", [pair("STR", "{st.str}"), pair("DEF", "{st.def}")]),
           box("strip-row", [pair("INT", "{st.int}"), pair("LCK", "{st.lck}")]),
           pair("STATUS", "GOOD")]),
    panel([text("lab", "EQUIPMENT"),
           lst("slots", "$slots", button("srow", [{"set": {"eqSlot": "{i}", "eqId": -1}}, {"navigate": "equip"}],
                                         [text("slab", "{label}"), img("sic", "$icon"), text("sname", "{name}")], classIf={"none": "$none"}))]),
    box("healrow", [
        button("hbtn", [{"call": "quickHeal", "args": ["{heal.id}"]}], [text("abtn-t", "HEAL")], visibleIf="$heal.can"),
        box("hbtn abtn-done", [text("abtn-t", "HEAL")], visibleIf="$heal.off"), text("hname", "{heal.name}")]),
    text("note", "{note}"),
    text("lab", "MENU"),
    lst("menu", "$menu", button("mrow", [{"navigate": "{page}"}], [text("mtext", "{label}")])),
], 0, head=title("Juste Belmont"))

# ---- equip -------------------------------------------------------------------------------------
equip = page("equip", [
    lst("eslots", "$eqSlots", button("erow", [{"set": {"eqSlot": "{i}", "eqId": -1}}],
                                    [hand(), text("elab", "{label}"), img("eic", "$icon"), text("ename", "{name}")],
                                    classIf={"sel": "$sel", "none": "$none"})),
    panel([box("strip-row", [pair("STR", "{st.str}"), pair("DEF", "{st.def}")]), box("strip-row", [pair("INT", "{st.int}"), pair("LCK", "{st.lck}")])]),
    box("band", [lst("blist", "$eqList", button("cell", [{"set": {"eqId": "{id}"}}],
                                                [hand(), img("cic", "$icon"), text("cname", "{name}"), text("ccount", "{count}")], classIf={"sel": "$sel"}))]),
    text("band-empty", "---", visibleIf="$eqEmpty"),
    info("$eqPick.icon", "{eqPick.name}", "{eqPick.desc}", "Change gear in the game's Equip menu: it works out the stats there."),
], 1)

# ---- items -------------------------------------------------------------------------------------
items = page("items", [
    panel([pair("HP", "{st.hpText}"), pair("MP", "{st.mpText}"), pair("HEART", "{st.heartText}"), pair("STATUS", "GOOD")]),
    box("tabs", [button("itab", [{"set": {"itemTab": "use", "item": -1}}], [text("itab-t", "ITEMS")], classIf={"sel": "$itemUseTab"}),
                 button("itab", [{"set": {"itemTab": "key", "item": -1}}], [text("itab-t", "KEY ITEMS")], classIf={"sel": "$itemKeyTab"})]),
    box("band", [lst("blist", "$itemList", button("cell", [{"set": {"item": "{id}"}}],
                                                  [hand(), img("cic", "$icon"), text("cname", "{name}"), text("ccount", "{count}")], classIf={"sel": "$sel"}))]),
    text("band-empty", "---", visibleIf="$itemEmpty"),
    info("$ipick.icon", "{ipick.name}", "{ipick.desc}", "{ipick.effect}",
         btn=act_button("iuse", "USE", [{"call": "useItem", "args": ["{ipick.id}"]}], "$ipick.canUse", "FULL", "$ipick.full")),
], 2)

# ---- spell book --------------------------------------------------------------------------------
book = page("book", [
    panel([lst("books", "$bookList", button("brow", [{"set": {"book": "{k}"}}],
                                           [hand(), img("bimg", "$img"), text("bname", "{name}"), box("grow", []),
                                            box("pill on", [text("pill-t", "SET")], visibleIf="$set")],
                                           classIf={"locked": "$locked"}))]),
    info("$bookPick.img", "{bookPick.name}", "{bookPick.desc}", "Cast with a subweapon. Turn it on in the game.",
         btn=act_button("bset", "SET", [{"call": "setBook", "args": ["{bookPick.k}"]}], "$bookPick.canSet", "IN USE", "$bookPick.isSet")),
], 3)

# ---- relics ------------------------------------------------------------------------------------
relics = page("relics", [
    panel([lst("rlist", "$relicList", button("rrow", [{"set": {"relic": "{k}"}}, {"call": "toggleRelic", "args": ["{k}"]}],
                                            [img("ric", "$icon"), text("rname", "{name}"), box("grow", []),
                                             box("pill on", [text("pill-t", "ON")], visibleIf="$on"), box("pill off", [text("pill-t", "OFF")], visibleIf="$off")],
                                            classIf={"locked": "$locked", "sel": "$sel"}))]),
    info("asset:ui/ic-goods.png", "{relicPick.name}", "{relicPick.desc}"),
], 4)

# ---- key config --------------------------------------------------------------------------------
config = page("config", [
    panel([lst("cfglist", "$cfgRows", box("crow2", [
        text("clab", "{label}"), box("grow", []),
        button("carr", [{"call": "cycleKey", "args": ["{row}", -1]}], [text("carr-t", "<")]),
        img("ckey", "$keyImg"),
        button("carr", [{"call": "cycleKey", "args": ["{row}", 1]}], [text("carr-t", ">")]),
    ]))]),
    text("cfg-clash", "Control settings are conflicting.", visibleIf="$cfgClash"),
    box("btnrow", [button("obtn", [{"call": "defaultKeys"}], [text("abtn-t", "DEFAULT")]),
                   button("perm", [{"call": "writePermission"}], [text("perm-t", "GAME CHANGES: {_writePermLabel}")])]),
    info("asset:ui/key-A.png", "Key Config.", "Pressing SELECT will reset the system settings. Tap the arrows here; two actions never share a button."),
], 5)

# ---- map (the game's SELECT map) ---------------------------------------------------------------
cmap = page("map", [
    box("tabs", [button("ctab", [{"set": {"castle": 0}}], [text("ctab-t", "CASTLE A  {map.a}")], classIf={"sel": "$map.isA"}),
                 button("ctab", [{"set": {"castle": 1}}], [text("ctab-t", "CASTLE B  {map.b}")], classIf={"sel": "$map.isB"}),
                 box("grow", []), text("lab", "TOTAL"), text("val", "{map.total}")]),
    box("mapfield", [box("mapbox", [lst("maprows", "$mapRuns", box("run", [box("run-in", [])], bindStyle={"left": "{x}", "top": "{y}", "width": "{w}"}))]),
                     text("map-empty", "Nothing explored in this castle yet.", visibleIf="$map.empty")]),
], 6)

waiting = box("page page-waiting", [
    img("w-crest", "asset:ui/crest.png"),
    text("w-1", "HARMONY OF DISSONANCE"), text("w-2", "COMPANION"),
    text("w-3", "Load Juste's game to see his status."),
    text("w-4", "Maxim mode has no pause menu: start a game as Juste.", visibleIf="$maxim"),
    text("w-4", "This pack reads the USA cartridge (ACHE).", visibleIf="$wrongRom"),
])

body = [("status", status), ("equip", equip), ("items", items), ("book", book), ("relics", relics), ("config", config), ("map", cmap)]
root = box("main", [
    box("waiting", [waiting], visibleIf="$waiting"),
    box("ready", [{"type": "pages", "class": "stage", "initial": "status", "pages": [{"name": n, "child": c} for n, c in body]},
                  button("toast", [{"set": {"toastHide": "{toast.id}", "relic": "{toast.relic}", "book": "{toast.book}"}}, {"navigate": "{toast.page}"}],
                         [img("toast-img", "$toast.img"), box("toast-t", [text("toast-title", "{toast.title}"), text("toast-name", "{toast.name}"), text("toast-sub", "{toast.sub}")]),
                          button("toast-x", [{"set": {"toastHide": "{toast.id}"}}], [text("toast-x-t", "X")])], visibleIf="$toastOn")],
        visibleIf="$ready")], id="screen")

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    json.dump(root, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
    print("ok", len(json.dumps(root)))
