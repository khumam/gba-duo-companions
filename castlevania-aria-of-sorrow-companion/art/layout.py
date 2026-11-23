#!/usr/bin/env python3
"""Writes layout.json: Aria of Sorrow's pause menu (Status, Soul Set, Equip, Item Use, Ability, Enemy, Config) for the
second screen, joined by left / right plates that cycle through the pages, plus an enemy entry page. Also draws every
window size it uses (art/ui.py). Edit here, not layout.json:
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


SIZES = set()


def win(w, h, cls):
    """A window PNG of exactly w x h art px, placed by the CSS class."""
    if (w, h) not in SIZES:
        SIZES.add((w, h))
        ui.window(w, h)
    return img(f"win {cls}", f"asset:ui/win-{w}x{h}.png")


PAGES = [("status", "Status"), ("soul", "Soul Set"), ("equip", "Equip"), ("items", "Item Use"),
         ("ability", "Ability"), ("enemy", "Enemy"), ("config", "Config"), ("map", "Map")]


def nav(i):
    prev, nxt = PAGES[(i - 1) % len(PAGES)], PAGES[(i + 1) % len(PAGES)]
    pips = [img("pip" + (" on" if k == i else ""), "asset:ui/orb-red.png" if k == i else "asset:ui/pip.png") for k in range(len(PAGES))]
    return [
        button("nbtn nbtn-l", [{"navigate": prev[0]}], [img("nplate", "asset:ui/nav-l.png"), text("nb nb-l", prev[1].upper())]),
        box("nmid", [img("nplate-m", "asset:ui/nav-mid.png"), text("ntitle", PAGES[i][1].upper()), box("pips", pips)]),
        button("nbtn nbtn-r", [{"navigate": nxt[0]}], [img("nplate", "asset:ui/nav-r.png"), text("nb nb-r", nxt[1].upper())]),
    ]


def title(t):
    return [img("tplate", "asset:ui/title.png"), text("ttext", t)]


def page(name, children, i=None, extra_cls="", scroll=False):
    kids = [img("bg", "asset:ui/bg.png")] + children
    if scroll:      # taller than the screen: the content scrolls above the bottom plates, which stay put
        kids = [box("pscroll", [box("pcanvas", kids)])]
    if i is not None:
        kids += nav(i)
    return box(f"page page-{name} {extra_cls}".strip(), kids)


# ---- shared pieces ------------------------------------------------------------------------------
def stat_window(top=18, h=44):
    # the ATT / DEF / STR / CON / INT / LCK window the Soul Set and Equip screens share
    def v(cls, key):
        return text(f"num {cls}", "{sw.%s.v}" % key, classIf={"up": "$sw.%s.up" % key, "down": "$sw.%s.down" % key})
    return [win(92, h, "w-stats"),
            text("lab att-l sw1", "ATT"), v("sw1v", "att"),
            text("lab def-l sw2", "DEF"), v("sw2v", "def"),
            text("lab sw3", "STR"), v("sw3v", "str"),
            text("lab sw4", "CON"), v("sw4v", "con"),
            text("lab sw5", "INT"), v("sw5v", "int"),
            text("lab sw6", "LCK"), v("sw6v", "lck"),
            text("lab sw-after", "AFTER", visibleIf="$cmpOn")]


def desc_window(icon_src=None, cost=None, name="", desc="", extra=None, btn=None):
    kids = [win(240, 48, "w-desc")]
    if cost:
        kids += [win(34, 26, "w-cost"), text("cost", cost[0]), text("cost-u", cost[1])]
    if icon_src:
        kids += [win(34, 26, "w-cost"), img("dicon", icon_src)]
    kids += [text("dname", name), text("dtext", desc)]
    if extra:
        kids += [text("dextra", extra)]
    if btn:
        kids += btn
    kids += [text("note", "{note}")]
    return kids


def act_button(label, on, can, done_label, done):
    return [button("abtn", on, [img("abtn-p", "asset:ui/btn.png"), text("abtn-t", label)], visibleIf=can),
            box("abtn abtn-done", [img("abtn-p", "asset:ui/btn-off.png"), text("abtn-t", done_label)], visibleIf=done)]


def band(header, count, items, tpl, empty=None, header_kids=None):
    kids = [box("bandhead", header_kids or [text("bh-t", header)]), text("bh-n", count),
            box("band", [lst("blist", items, tpl)])]
    if empty:
        kids.append(text("band-empty", empty[0], visibleIf=empty[1]))
    return kids


# ---- status -------------------------------------------------------------------------------------
status = page("status", [
    img("vortex", "asset:ui/vortex.png"),
    img("vorb vorb-1", "$orb1"), img("vorb vorb-2", "$orb2"), img("vorb vorb-3", "$orb3"),
    text("soma", "SOMA"),
    text("lv-l", "LV."), text("lv", "{st.level}"),
    button("hbtn", [{"call": "quickHeal"}], [img("hbtn-p", "asset:ui/btn.png"), img("hbtn-i", "asset:ui/ic-potion.png"), text("hbtn-t", "HEAL")],
           visibleIf="$heal.can"),
    box("hbtn hbtn-off", [img("hbtn-p", "asset:ui/btn-off.png"), text("hbtn-t", "HEAL")], visibleIf="$heal.full"),
    box("hbtn hbtn-off", [img("hbtn-p", "asset:ui/btn-off.png"), text("hbtn-t", "HEAL")], visibleIf="$heal.none"),
    text("hname", "{heal.name}"),
    win(184, 66, "w-st"),
    text("lab hp-l", "HP"), text("num hp-v", "{st.hpText}"), bar("hpbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"}),
    text("lab mp-l", "MP"), text("num mp-v", "{st.mpText}"), bar("mpbar", "$st.mp", "$st.maxMp"),
    text("lab s1", "STR"), text("num s1v", "{st.str}"),
    text("lab s2", "CON"), text("num s2v", "{st.con}"),
    text("lab s3", "INT"), text("num s3v", "{st.int}"),
    text("lab s4", "LCK"), text("num s4v", "{st.lck}"),
    text("lab att-l s5", "ATT"), text("num s5v", "{st.att}"),
    text("lab def-l s6", "DEF"), text("num s6v", "{st.def}"),
    text("lab st-good", "STATUS / GOOD"),
    win(88, 34, "w-souls"),
    text("lab so-l", "SOULS"), text("num so-v", "{st.souls}"), text("lab so-r", "RATE"), text("num so-rv", "{st.soulRate}"),
    win(94, 34, "w-info"),
    text("lab i1", "TIME"), text("num i1v", "{st.time}"),
    text("lab i2", "RATE"), text("num i2v", "{st.rate}"),
    text("lab gold-l i3", "GOLD"), text("num gold i3v", "{st.gold}"),
    img("expband", "asset:ui/exp.png"),
    text("lab ex-l", "EXP"), text("num ex-v", "{st.exp}"),
    text("lab nx-l", "NEXT"), text("num nx-v", "{st.next}"),
    bar("expbar", "$st.expIn", "$st.expSpan"),
    # the pause menu: every entry opens its page
    box("menu", [lst("mlist", "$menu", button("mbtn", [{"navigate": "{page}"}], [text("mtext", "{label}")]))]),
    win(166, 52, "w-eq"),
    text("lab eqh", "EQUIPMENT"), text("lab soh", "SOULS"),
    lst("glist", "$gear", button("grow", [{"set": {"eqSlot": "{i}", "eqItem": -1}}, {"navigate": "equip"}],
                                [img("gicon", "$icon"), text("gname", "{name}")], classIf={"none": "$none"})),
    lst("slist", "$souls", button("srow", [{"set": {"soulCat": "{i}", "soul": -1}}, {"navigate": "soul"}],
                                 [img("sorb", "$orb"), text("sname", "{name}")], classIf={"none": "$off"})),
], 0, scroll=True)

# ---- soul set ----------------------------------------------------------------------------------
soul = page("soul", [
    *title("SOUL SET"),
    img("vortex-s", "asset:ui/vortex-s.png"),
    lst("sotabs", "$soulTabs", button("sotab", [{"set": {"soulCat": "{c}", "soul": -1}}],
                                      [img("sotab-orb", "$orb"), text("sotab-l", "{label}"), text("sotab-n", "{name}"), box("sotab-u", [])],
                                      classIf={"sel": "$sel"}, bindStyle={"--c": "{hex}"})),
    img("sobig", "$soulBig"),
    *stat_window(h=56),
    *band("{soulCatName}", "{soulOwned}", "$soulList",
          button("cell", [{"set": {"soul": "{id}"}}],
                 [img("cur", "asset:ui/cursor.png", visibleIf="$sel"), img("corb", "$orb"), text("cname", "{name}"), text("ccount", "{count}")],
                 classIf={"sel": "$sel", "eqd": "$equipped"})),
    *desc_window(cost=("{soulPick.costN}", "{soulPick.costU}"), name="{soulPick.name}", desc="{soulPick.desc}", extra="{soulPick.from}",
                 btn=act_button("SET", [{"call": "setSoul", "args": ["{soulPick.cat}", "{soulPick.id}"]}], "$soulPick.canSet",
                                "IN USE", "$soulPick.isSet")),
], 1, scroll=True)

# ---- equip -------------------------------------------------------------------------------------
equip = page("equip", [
    *title("EQUIP"),
    win(146, 56, "w-slots"),
    lst("eqslots", "$eqSlots", button("eqslot", [{"set": {"eqSlot": "{i}", "eqItem": -1}}],
                                      [img("cur", "asset:ui/cursor.png", visibleIf="$sel"), text("eqs-l", "{label}"),
                                       img("eqs-i", "$icon"), text("eqs-n", "{name}")], classIf={"sel": "$sel"})),
    *stat_window(h=56),
    *band("{eqSlotName}", "{eqCount}", "$eqList",
          button("cell", [{"set": {"eqItem": "{idx}"}}],
                 [img("cur", "asset:ui/cursor.png", visibleIf="$sel"), img("cicon", "$icon"), text("cname", "{name}"), text("ccount", "{count}")],
                 classIf={"sel": "$sel"}),
          empty=("Nothing to change to.", "$eqEmpty")),
    *desc_window(icon_src="$eqPick.icon", name="{eqPick.name}", desc="{eqPick.desc}", extra="{eqPick.stats}",
                 btn=act_button("EQUIP", [{"call": "equip", "args": ["{eqPick.slot}", "{eqPick.idx}"]}], "$eqPick.canSet",
                                "WORN", "$eqPick.isSet")),
    box("abtn abtn-done", [img("abtn-p", "asset:ui/btn-off.png"), text("abtn-t", "NOT OWNED")], visibleIf="$eqPick.notOwned"),
], 2, scroll=True)

# ---- item use ----------------------------------------------------------------------------------
items = page("items", [
    *title("ITEM USE"),
    win(240, 48, "w-hpmp"),
    text("lab ih-l", "HP"), text("num ih-v", "{st.hpText}"), bar("hpbar ihbar", "$st.hp", "$st.maxHp", classIf={"low": "$st.lowHp"}),
    text("lab im-l", "MP"), text("num im-v", "{st.mpText}"), bar("mpbar imbar", "$st.mp", "$st.maxMp"),
    text("lab ist", "STATUS / GOOD"),
    *band("", "{itemCount}", "$itemList",
          button("cell", [{"set": {"item": "{i}"}}],
                 [img("cur", "asset:ui/cursor.png", visibleIf="$sel"), img("cicon", "$icon"), text("cname", "{name}"), text("ccount", "{count}")],
                 classIf={"sel": "$sel"}),
          empty=("No items here.", "$itemEmpty"),
          header_kids=[button("itab", [{"set": {"itemTab": "use", "item": -1}}], [text("itab-t", "ITEMS")], classIf={"sel": "$itemUseTab"}),
                       button("itab", [{"set": {"itemTab": "key", "item": -1}}], [text("itab-t", "KEY ITEMS")], classIf={"sel": "$itemKeyTab"})]),
    *desc_window(icon_src="$itemPick.icon", name="{itemPick.name}", desc="{itemPick.desc}", extra="{itemPick.effect}",
                 btn=act_button("USE", [{"call": "useItem", "args": ["{itemPick.i}"]}], "$itemPick.canUse",
                                "FULL", "$itemPick.full")),
    box("abtn abtn-done", [img("abtn-p", "asset:ui/btn-off.png"), text("abtn-t", "NOT OWNED")], visibleIf="$itemPick.notOwned"),
], 3, scroll=True)

# ---- ability -----------------------------------------------------------------------------------
ability = page("ability", [
    *title("ABILITY"),
    win(240, 112, "w-abil"),
    text("lab ab-h", "ABILITY SOULS  {abilOwned}"),
    lst("alist", "$abilList", button("acell", [{"set": {"abil": "{i}"}}, {"call": "toggleAbility", "args": ["{i}"]}],
                                     [img("cur", "asset:ui/cursor.png", visibleIf="$sel"), img("aorb", "$orb"), text("aname", "{name}"),
                                      box("pill on", [text("pill-t", "ON")], visibleIf="$on"),
                                      box("pill off", [text("pill-t", "OFF")], visibleIf="$off")],
                                     classIf={"sel": "$sel", "locked": "$locked"})),
    text("lab ab-tip", "Tap a soul to switch it on or off."),
    *desc_window(icon_src="asset:ui/orbbig-grey.png", name="{abilPick.name}", desc="{abilPick.desc}"),
], 4, scroll=True)

# ---- enemy list --------------------------------------------------------------------------------
enemy = page("enemy", [
    img("book", "asset:ui/book.png"),
    text("bk-h", "ENEMY DATA"),
    lst("elist", "$enemyRows", button("erow", [{"set": {"enemy": "{k}"}}, {"navigate": "enemyDetail"}],
                                      [text("eno", "{no}"), text("ename", "{name}")], classIf={"unseen": "$unseen"})),
    text("bk-lab bk-seen-l", "SEEN"), text("bk-val bk-seen", "{enemySeen}"),
    text("bk-lab bk-soul-l", "SOUL"), text("bk-val bk-soul", "{st.soulRate}"),
    button("pgbtn pg-l", [{"set": {"epage": "{epagePrev}"}}], [img("key-i", "asset:ui/key-L.png"), text("pg-t", "PREV")]),
    text("pg-n", "{epageText}"),
    button("pgbtn pg-r", [{"set": {"epage": "{epageNext}"}}], [text("pg-t", "NEXT"), img("key-i", "asset:ui/key-R.png")]),
    text("bk-tip", "Tap an enemy to open its page."),
], 5)

enemy_detail = page("enemyDetail", [
    img("book", "asset:ui/book.png"),
    text("bk-no", "NO. {ed.no}"),
    img("ed-frame", "asset:ui/book-frame.png"), img("ed-orb", "$ed.orbBig"),
    text("ed-name", "{ed.name}"),
    text("bk-lab ed-hp-l", "HP"), text("ed-hp", "{ed.hp}"),
    text("bk-lab ed-exp-l", "EXP"), text("ed-exp", "{ed.exp}"),
    text("bk-lab ed-soul-l", "SOUL"), img("ed-sorb", "$ed.orb"),
    button("ed-link ed-soul-b", [{"set": {"soulCat": "{ed.soulLink.cat}", "soul": "{ed.soulLink.soul}", "abil": "{ed.soulLink.abil}"}},
                                  {"navigate": "{ed.soulLink.page}"}],
           [text("ed-soul", "{ed.soul}", classIf={"owned": "$ed.soulOwned"})], classIf={"dead": "$ed.unseen"}),
    text("ed-check", "OWNED", visibleIf="$ed.soulOwned"),
    text("bk-lab ed-tol-l", "TOLERANCE"),
    lst("ed-tol", "$ed.tol", img("el", "$icon")), text("ed-none ed-tol-n", "---", visibleIf="$ed.noTol"),
    text("bk-lab ed-weak-l", "WEAKNESS"),
    lst("ed-weak", "$ed.weak", img("el", "$icon")), text("ed-none ed-weak-n", "---", visibleIf="$ed.noWeak"),
    text("bk-lab ed-drop-l", "DROP"),
    button("ed-link ed-d1", [{"set": {"eqSlot": "{ed.l1.eqSlot}", "eqItem": "{ed.l1.eqItem}", "item": "{ed.l1.item}", "itemTab": "{ed.l1.itemTab}"}},
                             {"navigate": "{ed.l1.page}"}], [text("ed-drop", "{ed.drop1}")], visibleIf="$ed.l1.ok"),
    text("ed-drop ed-d1t", "{ed.drop1}", visibleIf="$ed.l1.off"),
    button("ed-link ed-d2", [{"set": {"eqSlot": "{ed.l2.eqSlot}", "eqItem": "{ed.l2.eqItem}", "item": "{ed.l2.item}", "itemTab": "{ed.l2.itemTab}"}},
                             {"navigate": "{ed.l2.page}"}], [text("ed-drop", "{ed.drop2}")], visibleIf="$ed.l2.ok"),
    text("ed-drop ed-d2t", "{ed.drop2}", visibleIf="$ed.l2.off"),
    text("bk-tip ed-tip", "Tap the soul or a drop to open it."),
    text("ed-desc", "{ed.desc}"),
    button("pgbtn pg-l", [{"set": {"enemy": "{ed.prev}"}}], [text("pg-t", "< NO. {ed.prevNo}")]),
    button("pgbtn pg-c", [{"set": {"epage": "{ed.page}"}}, {"navigate": "enemy"}], [text("pg-t", "LIST")]),
    button("pgbtn pg-r", [{"set": {"enemy": "{ed.next}"}}], [text("pg-t", "NO. {ed.nextNo} >")]),
], 5)

# ---- config ------------------------------------------------------------------------------------
config = page("config", [
    *title("CONFIG"),
    win(240, 92, "w-cfg"),
    lst("cfglist", "$cfgRows", box("crow", [
        text("clab", "{label}"),
        button("carr carr-l", [{"call": "cycleKey", "args": ["{row}", -1]}], [text("carr-t", "<")]),
        img("ckey", "$keyImg"),
        button("carr carr-r", [{"call": "cycleKey", "args": ["{row}", 1]}], [text("carr-t", ">")]),
    ])),
    text("cfg-clash", "The control settings are conflicting.", visibleIf="$cfgClash"),
    button("obtn o-def", [{"call": "defaultKeys"}], [img("abtn-p", "asset:ui/btn.png"), text("abtn-t", "DEFAULT")]),
    button("perm", [{"call": "writePermission"}], [text("perm-t", "GAME CHANGES: {_writePermLabel}")]),
    *desc_window(icon_src="asset:ui/orbbig-blue.png", name="Buttons", desc="Tap the arrows to change a button. Two actions never share one: they swap.",
                 extra="Needs Settings > Packs can change games."),
], 6)

# ---- map (the game's SELECT map) ---------------------------------------------------------------
cmap = page("map", [
    *title("MAP"),
    text("lab mrate-l", "RATE"), text("mrate", "{st.rate}"),
    text("lab mcell-l", "ROOMS"), text("mcell", "{mapCells}"),
    box("mapbox", [lst("maprows", "$mapRuns", box("run", [box("run-in", [])], bindStyle={"left": "{x}", "top": "{y}", "width": "{w}"}))]),
], 7)

# ---- waiting -----------------------------------------------------------------------------------
waiting = page("waiting", [
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
                         [img("toast-orb", "$toast.orb"), text("toast-title", "{toast.title}", bindStyle={"color": "{toast.hex}"}),
                          text("toast-name", "{toast.name}"), text("toast-sub", "{toast.sub}"),
                          button("toast-x", [{"set": {"toastHide": "{toast.id}"}}], [text("toast-x-t", "X")])],
                         visibleIf="$toastOn")], visibleIf="$ready")], id="screen")

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    json.dump(root, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
    print("ok", len(json.dumps(root)), "windows", sorted(SIZES))
