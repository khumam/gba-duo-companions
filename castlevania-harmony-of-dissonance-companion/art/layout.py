#!/usr/bin/env python3
"""Writes layout.json: Harmony of Dissonance's pause menu (Status, Equip, Items, Spell Book, Relics, Key Config) for
the second screen, joined by left / right plates. Edit here, not layout.json:   python3 art/layout.py
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


def info(icon_src, name, desc, extra=None):
    kids = [box("rule rule-info", []), text("lab info-l", "INFORMATION"), img("info-i", icon_src), text("info-n", name), text("info-d", desc)]
    if extra:
        kids.append(text("info-x", extra))
    kids.append(text("note", "{note}"))
    return kids


def dots(cls, label, value):
    return [text(f"lab {cls}", label), box(f"dots {cls}d", []), text(f"val {cls}v", value)]


# ---- status ------------------------------------------------------------------------------------
status = page("status", [
    *title("Juste Belmont"),
    text("lab lv-l", "LEVEL"), text("val lv", "{st.level}"),
    text("lab ex-l", "EXP"), text("val ex", "{st.exp}"),
    text("lab nx-l", "NEXT"), text("val nx", "{st.next}"), bar("expbar", "$st.expIn", "$st.expSpan"),
    text("lab tm-l", "TIME"), text("val tm", "{st.time}"),
    text("lab gd-l", "GOLD"), text("val gd", "{st.gold}"),
    img("crest", "asset:ui/crest.png"),
    button("bookslot", [{"navigate": "book"}], [box("bk-frame", [img("bk-img", "$bookNow.img")]), text("lab bk-l", "SPELL"), text("lab bk-l2", "BOOK")]),
    lst("menu", "$menu", button("mrow", [{"navigate": "{page}"}], [text("mtext", "{label}")])),
    text("lab hp-l", "HP"), text("val hp", "{st.hpText}"),
    text("lab mp-l", "MP"), text("val mp", "{st.mpText}"),
    text("lab ht-l", "HEART"), text("val ht", "{st.heartText}"),
    *dots("s1", "STR", "{st.str}"), *dots("s2", "DEF", "{st.def}"), *dots("s3", "INT", "{st.int}"), *dots("s4", "LCK", "{st.lck}"),
    *dots("s5", "STATUS", "GOOD"),
    box("rule rule-eq", []), text("lab eq-h", "EQUIPMENT"),
    lst("slots", "$slots", button("srow", [{"set": {"eqSlot": "{i}", "eqId": -1}}, {"navigate": "equip"}],
                                  [text("slab", "{label}"), img("sic", "$icon"), text("sname", "{name}")], classIf={"none": "$none"})),
    button("hbtn", [{"call": "quickHeal", "args": ["{heal.id}"]}], [img("abtn-p", "asset:ui/btn.png"), text("abtn-t", "HEAL")], visibleIf="$heal.can"),
    box("hbtn abtn-done", [img("abtn-p", "asset:ui/btn-off.png"), text("abtn-t", "HEAL")], visibleIf="$heal.off"),
    text("hname", "{heal.name}"),
    text("note note-st", "{note}"),
], 0)

# ---- equip -------------------------------------------------------------------------------------
equip = page("equip", [
    *title("Equip"),
    lst("eslots", "$eqSlots", button("erow", [{"set": {"eqSlot": "{i}", "eqId": -1}}],
                                    [img("hand", "asset:ui/hand.png", visibleIf="$sel"), text("elab", "{label}"), img("eic", "$icon"), text("ename", "{name}")],
                                    classIf={"sel": "$sel", "none": "$none"})),
    box("rule rule-e1", []),
    text("lab e-s1", "STR"), text("val e-s1v", "{st.str}"), text("lab e-s2", "DEF"), text("val e-s2v", "{st.def}"),
    text("lab e-s3", "INT"), text("val e-s3v", "{st.int}"), text("lab e-s4", "LCK"), text("val e-s4v", "{st.lck}"),
    box("rule rule-e2", []),
    box("band", [lst("blist", "$eqList", button("cell", [{"set": {"eqId": "{id}"}}],
                                                [img("hand hand-c", "asset:ui/hand.png", visibleIf="$sel"), img("cic", "$icon"), text("cname", "{name}"), text("ccount", "{count}")],
                                                classIf={"sel": "$sel"}))]),
    text("band-empty", "---", visibleIf="$eqEmpty"),
    *info("$eqPick.icon", "{eqPick.name}", "{eqPick.desc}", "Change gear in the game's Equip menu: it works out the stats there."),
], 1)

# ---- items -------------------------------------------------------------------------------------
items = page("items", [
    *title("Items"),
    text("lab ih-l", "HP"), text("val ih", "{st.hpText}"),
    text("lab im-l", "MP"), text("val im", "{st.mpText}"),
    text("lab it-l", "HEART"), text("val it", "{st.heartText}"),
    *dots("ist", "STATUS", "GOOD"),
    button("itab itab-1", [{"set": {"itemTab": "use", "item": -1}}], [text("itab-t", "ITEMS")], classIf={"sel": "$itemUseTab"}),
    button("itab itab-2", [{"set": {"itemTab": "key", "item": -1}}], [text("itab-t", "KEY ITEMS")], classIf={"sel": "$itemKeyTab"}),
    box("rule rule-i", []),
    box("band band-i", [lst("blist", "$itemList", button("cell", [{"set": {"item": "{id}"}}],
                                                         [img("hand hand-c", "asset:ui/hand.png", visibleIf="$sel"), img("cic", "$icon"), text("cname", "{name}"), text("ccount", "{count}")],
                                                         classIf={"sel": "$sel"}))]),
    text("band-empty band-empty-i", "---", visibleIf="$itemEmpty"),
    *info("$ipick.icon", "{ipick.name}", "{ipick.desc}", "{ipick.effect}"),
    *act_button("iuse", "USE", [{"call": "useItem", "args": ["{ipick.id}"]}], "$ipick.canUse", "FULL", "$ipick.full"),
], 2)

# ---- spell book --------------------------------------------------------------------------------
book = page("book", [
    *title("Spell Book"),
    lst("books", "$bookList", button("brow", [{"set": {"book": "{k}"}}],
                                    [img("hand", "asset:ui/hand.png", visibleIf="$sel"), img("bimg", "$img"), text("bname", "{name}"),
                                     box("pill on", [text("pill-t", "SET")], visibleIf="$set")],
                                    classIf={"locked": "$locked"})),
    *info("$bookPick.img", "{bookPick.name}", "{bookPick.desc}", "Cast with a subweapon. Turn it on in the game."),
    *act_button("bset", "SET", [{"call": "setBook", "args": ["{bookPick.k}"]}], "$bookPick.canSet", "IN USE", "$bookPick.isSet"),
], 3)

# ---- relics ------------------------------------------------------------------------------------
relics = page("relics", [
    *title("Relics"),
    box("rbox", []),
    lst("rlist", "$relicList", button("rrow", [{"set": {"relic": "{k}"}}, {"call": "toggleRelic", "args": ["{k}"]}],
                                     [img("ric", "$icon"), text("rname", "{name}"),
                                      box("pill on", [text("pill-t", "ON")], visibleIf="$on"), box("pill off", [text("pill-t", "OFF")], visibleIf="$off")],
                                     classIf={"locked": "$locked", "sel": "$sel"})),
    *info("asset:ui/ic-goods.png", "{relicPick.name}", "{relicPick.desc}"),
], 4)

# ---- key config --------------------------------------------------------------------------------
config = page("config", [
    *title("Key Config."),
    lst("cfglist", "$cfgRows", box("crow2", [
        text("clab", "{label}"),
        button("carr carr-l", [{"call": "cycleKey", "args": ["{row}", -1]}], [text("carr-t", "<")]),
        img("ckey", "$keyImg"),
        button("carr carr-r", [{"call": "cycleKey", "args": ["{row}", 1]}], [text("carr-t", ">")]),
    ])),
    text("cfg-clash", "Control settings are conflicting.", visibleIf="$cfgClash"),
    button("obtn", [{"call": "defaultKeys"}], [img("abtn-p", "asset:ui/btn.png"), text("abtn-t", "DEFAULT")]),
    button("perm", [{"call": "writePermission"}], [text("perm-t", "GAME CHANGES: {_writePermLabel}")]),
    *info("asset:ui/key-A.png", "Key Config.", "Pressing SELECT will reset the system settings. Tap the arrows here; two actions never share a button."),
], 5)

# ---- map (the game's SELECT map) ---------------------------------------------------------------
cmap = page("map", [
    *title("Map"),
    button("ctab ctab-a", [{"set": {"castle": 0}}], [text("ctab-t", "CASTLE A  {map.a}")], classIf={"sel": "$map.isA"}),
    button("ctab ctab-b", [{"set": {"castle": 1}}], [text("ctab-t", "CASTLE B  {map.b}")], classIf={"sel": "$map.isB"}),
    text("lab mtot-l", "TOTAL"), text("val mtot", "{map.total}"),
    box("mapbox", [lst("maprows", "$mapRuns", box("run", [box("run-in", [])], bindStyle={"left": "{x}", "top": "{y}", "width": "{w}"}))]),
    text("map-empty", "Nothing explored in this castle yet.", visibleIf="$map.empty"),
], 6)

waiting = page("waiting", [
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
                         [img("toast-img", "$toast.img"), text("toast-title", "{toast.title}"), text("toast-name", "{toast.name}"),
                          text("toast-sub", "{toast.sub}"),
                          button("toast-x", [{"set": {"toastHide": "{toast.id}"}}], [text("toast-x-t", "X")])], visibleIf="$toastOn")],
        visibleIf="$ready")], id="screen")

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    json.dump(root, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
    print("ok", len(json.dumps(root)))
