#!/usr/bin/env python3
"""Writes layout.json: Aria of Sorrow's pause menu, simplified. Same colours, art and data as before (originals: art/orig/), but each page is
a title plaque, ONE scrolling body of plain bands and rows, and the left / right plates fixed at the bottom. No absolutely placed labels
and no drawn window frames: the body flows, so text never overlaps and long lists simply scroll.
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


PAGES = [("status", "Status"), ("soul", "Soul Set"), ("equip", "Equip"), ("items", "Item Use"),
         ("ability", "Ability"), ("enemy", "Enemy"), ("config", "Config"), ("map", "Map")]


def nav(i):
    prev, nxt = PAGES[(i - 1) % len(PAGES)], PAGES[(i + 1) % len(PAGES)]
    pips = [img("pip" + (" on" if k == i else ""), "asset:ui/orb-red.png" if k == i else "asset:ui/pip.png") for k in range(len(PAGES))]
    return box("nav", [
        button("nbtn", [{"navigate": prev[0]}], [img("nplate", "asset:ui/nav-l.png"), text("nb nb-l", prev[1].upper())]),
        box("nmid", [img("nplate-m", "asset:ui/nav-mid.png"), text("ntitle", PAGES[i][1].upper()), box("pips", pips)]),
        button("nbtn", [{"navigate": nxt[0]}], [img("nplate", "asset:ui/nav-r.png"), text("nb nb-r", nxt[1].upper())]),
    ])


def title(t):
    return box("title", [img("tplate", "asset:ui/title.png"), text("ttext", t)])


def page(name, body, i=None, head=None, cls=""):
    kids = [head if head is not None else title(PAGES[i][1].upper())]
    kids.append(box("body", body))
    kids.append(nav(i))
    return box(f"page page-{name} {cls}".strip(), kids)


# ---- shared pieces ------------------------------------------------------------------------------
def pair(label, value, cls="", lab_cls=""):
    return box("pair", [text("lab " + lab_cls, label), text("num " + cls, value)])


def stat_pair(label, key, lab_cls=""):
    return box("pair", [text("lab " + lab_cls, label),
                        text("num", "{sw.%s.v}" % key, classIf={"up": "$sw.%s.up" % key, "down": "$sw.%s.down" % key})])


def stat_strip():
    # the ATT / DEF / STR / CON / INT / LCK strip the Soul Set and Equip screens share (shows the change when a pick is previewed)
    return box("panel", [
        box("strip-row", [stat_pair("ATT", "att", "att-l"), stat_pair("DEF", "def", "def-l"), stat_pair("STR", "str")]),
        box("strip-row", [stat_pair("CON", "con"), stat_pair("INT", "int"), stat_pair("LCK", "lck")]),
        text("lab after", "AFTER CHANGE", visibleIf="$cmpOn"),
    ])


def desc_panel(icon_src=None, cost=None, name="", desc="", extra=None, btn=None):
    lead = []
    if cost:
        lead = [box("dcost", [text("cost", cost[0]), text("cost-u", cost[1])])]
    if icon_src:
        lead = [img("dicon", icon_src)]
    kids = [box("dtop", [*lead, box("dtitle", [text("dname", name), *([text("dextra", extra)] if extra else [])]), *(btn or [])]),
            text("dtext", desc), text("note", "{note}")]
    return box("panel desc", kids)


def act_button(label, on, can, done_label, done):
    return [button("abtn", on, [text("abtn-t", label)], visibleIf=can),
            box("abtn abtn-done", [text("abtn-t", done_label)], visibleIf=done)]


def band(header, count, items, tpl, empty=None, header_kids=None):
    out = [box("bandhead", [*(header_kids or [text("bh-t", header)]), box("grow", []), text("bh-n", count)]),
           box("band", [lst("blist", items, tpl)])]
    if empty:
        out.append(text("band-empty", empty[0], visibleIf=empty[1]))
    return out


cursor = lambda: img("cur", "asset:ui/cursor.png", visibleIf="$sel")

# ---- status -------------------------------------------------------------------------------------
status = page("status", [
    box("hero", [
        box("vwrap", [img("vortex", "asset:ui/vortex.png"), img("vorb vorb-1", "$orb1"), img("vorb vorb-2", "$orb2"), img("vorb vorb-3", "$orb3")]),
        box("hero-in", [
            box("namerow", [text("soma", "SOMA"), text("lv-l", "LV."), text("lv", "{st.level}"), box("grow", []),
                            button("hbtn", [{"call": "quickHeal"}], [img("hbtn-i", "asset:ui/ic-potion.png"), text("hbtn-t", "HEAL")], visibleIf="$heal.can"),
                            box("hbtn hbtn-off", [text("hbtn-t", "HEAL")], visibleIf="$heal.full"),
                            box("hbtn hbtn-off", [text("hbtn-t", "HEAL")], visibleIf="$heal.none")]),
            box("barrow", [text("lab", "HP"), bar("hpbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"}), text("num bn", "{st.hpText}")]),
            box("barrow", [text("lab", "MP"), bar("mpbar", "$st.mp", "$st.maxMp"), text("num bn", "{st.mpText}")]),
            text("hname", "{heal.name}"),
        ]),
    ]),
    box("panel", [
        box("strip-row", [pair("STR", "{st.str}"), pair("CON", "{st.con}"), pair("INT", "{st.int}")]),
        box("strip-row", [pair("LCK", "{st.lck}"), pair("ATT", "{st.att}", lab_cls="att-l"), pair("DEF", "{st.def}", lab_cls="def-l")]),
        text("lab", "STATUS / GOOD"),
    ]),
    box("panel", [
        box("strip-row", [pair("EXP", "{st.exp}"), pair("NEXT", "{st.next}")]),
        bar("expbar", "$st.expIn", "$st.expSpan"),
    ]),
    box("strip-row wide", [
        box("panel half", [pair("SOULS", "{st.souls}"), pair("RATE", "{st.soulRate}")]),
        box("panel half", [pair("TIME", "{st.time}"), pair("RATE", "{st.rate}"), pair("GOLD", "{st.gold}", "gold", "gold-l")]),
    ]),
    box("panel", [text("lab", "EQUIPMENT"),
                  lst("glist", "$gear", button("grow2", [{"set": {"eqSlot": "{i}", "eqItem": -1}}, {"navigate": "equip"}],
                                               [img("gicon", "$icon"), text("gname", "{name}")], classIf={"none": "$none"}))]),
    box("panel", [text("lab", "SOULS"),
                  lst("slist", "$souls", button("grow2", [{"set": {"soulCat": "{i}", "soul": -1}}, {"navigate": "soul"}],
                                               [img("sorb", "$orb"), text("gname", "{name}")], classIf={"none": "$off"}))]),
    text("lab", "MENU"),
    lst("mlist", "$menu", button("mbtn", [{"navigate": "{page}"}], [text("mtext", "{label}")])),
], 0)

# ---- soul set ----------------------------------------------------------------------------------
soul = page("soul", [
    lst("sotabs", "$soulTabs", button("sotab", [{"set": {"soulCat": "{c}", "soul": -1}}],
                                      [img("sotab-orb", "$orb"), box("sotab-t", [text("sotab-l", "{label}"), text("sotab-n", "{name}")])],
                                      classIf={"sel": "$sel"}, bindStyle={"--c": "{hex}"})),
    stat_strip(),
    *band("{soulCatName}", "{soulOwned}", "$soulList",
          button("cell", [{"set": {"soul": "{id}"}}],
                 [cursor(), img("corb", "$orb"), text("cname", "{name}"), text("ccount", "{count}")],
                 classIf={"sel": "$sel", "eqd": "$equipped"})),
    desc_panel(cost=("{soulPick.costN}", "{soulPick.costU}"), name="{soulPick.name}", desc="{soulPick.desc}", extra="{soulPick.from}",
               btn=act_button("SET", [{"call": "setSoul", "args": ["{soulPick.cat}", "{soulPick.id}"]}], "$soulPick.canSet", "IN USE", "$soulPick.isSet")),
], 1)

# ---- equip -------------------------------------------------------------------------------------
equip = page("equip", [
    lst("eqslots", "$eqSlots", button("eqslot", [{"set": {"eqSlot": "{i}", "eqItem": -1}}],
                                      [cursor(), text("eqs-l", "{label}"), img("eqs-i", "$icon"), text("eqs-n", "{name}")], classIf={"sel": "$sel"})),
    stat_strip(),
    *band("{eqSlotName}", "{eqCount}", "$eqList",
          button("cell", [{"set": {"eqItem": "{idx}"}}],
                 [cursor(), img("cicon", "$icon"), text("cname", "{name}"), text("ccount", "{count}")], classIf={"sel": "$sel"}),
          empty=("Nothing to change to.", "$eqEmpty")),
    desc_panel(icon_src="$eqPick.icon", name="{eqPick.name}", desc="{eqPick.desc}", extra="{eqPick.stats}",
               btn=[*act_button("EQUIP", [{"call": "equip", "args": ["{eqPick.slot}", "{eqPick.idx}"]}], "$eqPick.canSet", "WORN", "$eqPick.isSet"),
                    box("abtn abtn-done", [text("abtn-t", "NOT OWNED")], visibleIf="$eqPick.notOwned")]),
], 2)

# ---- item use ----------------------------------------------------------------------------------
items = page("items", [
    box("panel", [
        box("barrow", [text("lab", "HP"), bar("hpbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"}), text("num bn", "{st.hpText}")]),
        box("barrow", [text("lab", "MP"), bar("mpbar", "$st.mp", "$st.maxMp"), text("num bn", "{st.mpText}")]),
        text("lab", "STATUS / GOOD"),
    ]),
    *band("", "{itemCount}", "$itemList",
          button("cell", [{"set": {"item": "{i}"}}],
                 [cursor(), img("cicon", "$icon"), text("cname", "{name}"), text("ccount", "{count}")], classIf={"sel": "$sel"}),
          empty=("No items here.", "$itemEmpty"),
          header_kids=[button("itab", [{"set": {"itemTab": "use", "item": -1}}], [text("itab-t", "ITEMS")], classIf={"sel": "$itemUseTab"}),
                       button("itab", [{"set": {"itemTab": "key", "item": -1}}], [text("itab-t", "KEY ITEMS")], classIf={"sel": "$itemKeyTab"})]),
    desc_panel(icon_src="$itemPick.icon", name="{itemPick.name}", desc="{itemPick.desc}", extra="{itemPick.effect}",
               btn=[*act_button("USE", [{"call": "useItem", "args": ["{itemPick.i}"]}], "$itemPick.canUse", "FULL", "$itemPick.full"),
                    box("abtn abtn-done", [text("abtn-t", "NOT OWNED")], visibleIf="$itemPick.notOwned")]),
], 3)

# ---- ability -----------------------------------------------------------------------------------
ability = page("ability", [
    box("bandhead", [text("bh-t", "ABILITY SOULS"), box("grow", []), text("bh-n", "{abilOwned}")]),
    box("band tall", [lst("alist", "$abilList", button("acell", [{"set": {"abil": "{i}"}}, {"call": "toggleAbility", "args": ["{i}"]}],
                                                       [cursor(), img("aorb", "$orb"), text("aname", "{name}"),
                                                        box("pill on", [text("pill-t", "ON")], visibleIf="$on"),
                                                        box("pill off", [text("pill-t", "OFF")], visibleIf="$off")],
                                                       classIf={"sel": "$sel", "locked": "$locked"}))]),
    text("hint", "Tap a soul to switch it on or off."),
    desc_panel(icon_src="asset:ui/orbbig-grey.png", name="{abilPick.name}", desc="{abilPick.desc}"),
], 4)

# ---- enemy list --------------------------------------------------------------------------------
enemy = page("enemy", [
    box("paper", [
        box("bookhead", [text("bk-h", "ENEMY DATA"), box("grow", []), text("bk-lab", "SEEN"), text("bk-val", "{enemySeen}"),
                         text("bk-lab", "SOUL"), text("bk-val", "{st.soulRate}")]),
        lst("elist", "$enemyRows", button("erow", [{"set": {"enemy": "{k}"}}, {"navigate": "enemyDetail"}],
                                          [text("eno", "{no}"), text("ename", "{name}")], classIf={"unseen": "$unseen"})),
        box("pager", [button("pgbtn", [{"set": {"epage": "{epagePrev}"}}], [img("key-i", "asset:ui/key-L.png"), text("pg-t", "PREV")]),
                      text("pg-n", "{epageText}"),
                      button("pgbtn", [{"set": {"epage": "{epageNext}"}}], [text("pg-t", "NEXT"), img("key-i", "asset:ui/key-R.png")])]),
        text("bk-tip", "Tap an enemy to open its page."),
    ]),
], 5)

enemy_detail = page("enemyDetail", [
    box("paper", [
        box("bookhead", [text("bk-h", "NO. {ed.no}"), box("grow", [])]),
        box("edtop", [
            box("edframe", [img("ed-frame", "asset:ui/book-frame.png"), img("ed-orb", "$ed.orbBig")]),
            box("edinfo", [
                text("ed-name", "{ed.name}"),
                box("pairline", [text("bk-lab", "HP"), text("ed-v", "{ed.hp}"), text("bk-lab", "EXP"), text("ed-v", "{ed.exp}")]),
                box("pairline", [text("bk-lab", "SOUL"), img("ed-sorb", "$ed.orb"),
                                 button("ed-link", [{"set": {"soulCat": "{ed.soulLink.cat}", "soul": "{ed.soulLink.soul}", "abil": "{ed.soulLink.abil}"}},
                                                    {"navigate": "{ed.soulLink.page}"}],
                                        [text("ed-soul", "{ed.soul}", classIf={"owned": "$ed.soulOwned"})], classIf={"dead": "$ed.unseen"}),
                                 text("ed-check", "OWNED", visibleIf="$ed.soulOwned")]),
            ]),
        ]),
        box("pairline", [text("bk-lab w", "TOLERANCE"), lst("eltags", "$ed.tol", img("el", "$icon")), text("ed-none", "---", visibleIf="$ed.noTol")]),
        box("pairline", [text("bk-lab w", "WEAKNESS"), lst("eltags", "$ed.weak", img("el", "$icon")), text("ed-none", "---", visibleIf="$ed.noWeak")]),
        box("pairline", [text("bk-lab w", "DROP"),
                         button("ed-link", [{"set": {"eqSlot": "{ed.l1.eqSlot}", "eqItem": "{ed.l1.eqItem}", "item": "{ed.l1.item}", "itemTab": "{ed.l1.itemTab}"}},
                                            {"navigate": "{ed.l1.page}"}], [text("ed-drop", "{ed.drop1}")], visibleIf="$ed.l1.ok"),
                         text("ed-drop", "{ed.drop1}", visibleIf="$ed.l1.off"),
                         button("ed-link", [{"set": {"eqSlot": "{ed.l2.eqSlot}", "eqItem": "{ed.l2.eqItem}", "item": "{ed.l2.item}", "itemTab": "{ed.l2.itemTab}"}},
                                            {"navigate": "{ed.l2.page}"}], [text("ed-drop", "{ed.drop2}")], visibleIf="$ed.l2.ok"),
                         text("ed-drop", "{ed.drop2}", visibleIf="$ed.l2.off")]),
        text("ed-desc", "{ed.desc}"),
        text("bk-tip", "Tap the soul or a drop to open it."),
        box("pager", [button("pgbtn", [{"set": {"enemy": "{ed.prev}"}}], [text("pg-t", "< NO. {ed.prevNo}")]),
                      button("pgbtn", [{"set": {"epage": "{ed.page}"}}, {"navigate": "enemy"}], [text("pg-t", "LIST")]),
                      button("pgbtn", [{"set": {"enemy": "{ed.next}"}}], [text("pg-t", "NO. {ed.nextNo} >")])]),
    ]),
], 5, head=title("ENEMY DATA"))

# ---- config ------------------------------------------------------------------------------------
config = page("config", [
    box("panel", [lst("cfglist", "$cfgRows", box("crow", [
        text("clab", "{label}"), box("grow", []),
        button("carr", [{"call": "cycleKey", "args": ["{row}", -1]}], [text("carr-t", "<")]),
        img("ckey", "$keyImg"),
        button("carr", [{"call": "cycleKey", "args": ["{row}", 1]}], [text("carr-t", ">")]),
    ]))]),
    text("cfg-clash", "The control settings are conflicting.", visibleIf="$cfgClash"),
    box("btnrow", [button("obtn", [{"call": "defaultKeys"}], [text("abtn-t", "DEFAULT")]),
                   button("perm", [{"call": "writePermission"}], [text("perm-t", "GAME CHANGES: {_writePermLabel}")])]),
    desc_panel(icon_src="asset:ui/orbbig-blue.png", name="Buttons", desc="Tap the arrows to change a button. Two actions never share one: they swap.",
               extra="Needs Settings > Packs can change games."),
], 6)

# ---- map (the game's SELECT map) ---------------------------------------------------------------
cmap = page("map", [
    box("bookhead plain", [text("lab", "RATE"), text("mrate", "{st.rate}"), box("grow", []), text("lab", "ROOMS"), text("mcell", "{mapCells}")]),
    box("mapfield", [box("mapbox", [lst("maprows", "$mapRuns", box("run", [box("run-in", [])], bindStyle={"left": "{x}", "top": "{y}", "width": "{w}"}))])]),
], 7)

# ---- waiting -----------------------------------------------------------------------------------
waiting = box("page page-waiting", [
    img("w-vortex", "asset:ui/vortex.png"), img("w-orb", "asset:ui/orbbig-red.png"),
    text("w-1", "ARIA OF SORROW"), text("w-2", "COMPANION"),
    text("w-3", "Load a save to see Soma's souls."),
    text("w-4", "This pack reads the USA cartridge (A2CE).", visibleIf="$wrongRom"),
])

body = [("status", status), ("soul", soul), ("equip", equip), ("items", items), ("ability", ability),
        ("enemy", enemy), ("enemyDetail", enemy_detail), ("config", config), ("map", cmap)]
root = box("main", [
    box("waiting", [waiting], visibleIf="$waiting"),
    box("ready", [{"type": "pages", "class": "stage", "initial": "status",
                   "pages": [{"name": n, "child": c} for n, c in body]},
                  button("toast", [{"set": {"toastHide": "{toast.id}", "soulCat": "{toast.cat}", "soul": "{toast.soul}",
                                            "abil": "{toast.abil}", "enemy": "{toast.enemy}"}}, {"navigate": "{toast.page}"}],
                         [img("toast-orb", "$toast.orb"), box("toast-t", [text("toast-title", "{toast.title}", bindStyle={"color": "{toast.hex}"}),
                                                                           text("toast-name", "{toast.name}"), text("toast-sub", "{toast.sub}")]),
                          button("toast-x", [{"set": {"toastHide": "{toast.id}"}}], [text("toast-x-t", "X")])],
                         visibleIf="$toastOn")], visibleIf="$ready")], id="screen")

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    json.dump(root, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
    print("ok", len(json.dumps(root)))
