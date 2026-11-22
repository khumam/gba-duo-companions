#!/usr/bin/env python3
"""Writes layout.json: The Sacred Stones' unit screen (Personal data 1/3, Items 2/3, Weapon and support level 3/3), the
army list, the convoy (Supply) and the chapter Status, joined by left / right plates.
Edit here, not layout.json:   python3 art/layout.py
"""
import json
import os


def box(cls, ch=(), **kw): return {"type": "box", "class": cls, "children": list(ch), **kw}
def text(cls, t, **kw): return {"type": "text", "class": cls, "text": t, **kw}
def img(cls, src, **kw): return {"type": "image", "class": cls, "src": src, **kw}
def button(cls, on, ch, **kw): return {"type": "button", "class": cls, "onClick": on, "children": list(ch), **kw}
def lst(cls, items, tpl, **kw): return {"type": "list", "class": cls, "items": items, "template": tpl, **kw}


PAGES = [("units", "Units"), ("personal", "Personal"), ("items", "Items"), ("weapons", "Weapons"),
         ("supply", "Supply"), ("status", "Status")]


def nav(i):
    prev, nxt = PAGES[(i - 1) % len(PAGES)], PAGES[(i + 1) % len(PAGES)]
    return [
        button("nbtn nbtn-l", [{"navigate": prev[0]}], [img("narrow narrow-l", "asset:ui/arrow-l.png"), text("nb", prev[1])]),
        box("nmid", [text("ntitle", PAGES[i][1]),
                     box("pips", [box("pip" + (" on" if k == i else ""), []) for k in range(len(PAGES))])]),
        button("nbtn nbtn-r", [{"navigate": nxt[0]}], [text("nb", nxt[1]), img("narrow narrow-r", "asset:ui/arrow-r.png")]),
    ]


def page(name, children, i):
    return box(f"page page-{name}", [img("leaves", "asset:ui/stone.png")] + children + nav(i))


# The portrait: six blocks of the ROM's 256 x 32 sheet make the 96 x 80 face (as the game's stat screen draws it).
BLOCKS = [("a", 0, 0, 64, 32, 16, 0), ("b", 64, 0, 64, 32, 16, 32), ("c", 128, 0, 32, 16, 16, 64),
          ("d", 128, 16, 32, 16, 48, 64), ("e", 160, 0, 16, 32, 0, 48), ("f", 176, 0, 16, 32, 80, 48)]


def portrait_css():
    out = []
    for n, sx, sy, w, h, dx, dy in BLOCKS:
        out.append(f".clip-{n} {{ left: {dx}ap; top: {dy}ap; width: {w}ap; height: {h}ap; }} "
                   f".sheet-{n} {{ left: -{sx}ap; top: -{sy}ap; }}")
    return "\n".join(out)


def left_column():
    face = box("pbg", [box(f"clip clip-{n}", [img(f"sheet sheet-{n}", "$u.sheet")]) for n, *_ in BLOCKS],
               visibleIf="$u.hasSheet")
    return [
        box("pframe", [box("pbg-fill", []), face, text("pname", "{u.name}")]),
        box("lvbox", [
            text("lv-cls", "{u.cls}"),
            text("lv-l lv-l1", "LV"), text("lv-v lv-v1", "{u.lv}"), text("lv-l lv-l2", "E"), text("lv-v lv-v2", "{u.exp}"),
            text("lv-l lv-l3", "HP"), text("lv-v lv-v3", "{u.hp}"),
        ]),
        button("ubtn ubtn-p", [{"set": {"unit": "{prevUnit}", "slot": -1}}], [text("ubtn-t", "^")]),
        text("upos", "{u.pos}"),
        button("ubtn ubtn-n", [{"set": {"unit": "{nextUnit}", "slot": -1}}], [text("ubtn-t", "v")]),
    ]


def header(title, num, prev, nxt):
    return [
        button("harrow harrow-l", [{"navigate": prev}], [img("harrow-i", "asset:ui/arrow-l.png")]),
        text("htitle" + (" long" if len(title) > 14 else ""), title),
        button("harrow harrow-r", [{"navigate": nxt}], [img("harrow-i", "asset:ui/arrow-r.png")]),
        text("hnum", num),
    ]


def note():
    return box("note", [text("note-t", "{note}")], visibleIf="$hasNote")


# ---------------------------------------------------------------- pages
units = page("units", [
    box("plate plate-units", [text("plate-t", "Units"), text("plate-c", "{army.count}")]),
    button("pg pg-l", [{"set": {"upage": "{army.prev}"}}], [img("pg-i", "asset:ui/arrow-l.png")]),
    text("pg-n", "{army.page}"),
    button("pg pg-r", [{"set": {"upage": "{army.next}"}}], [img("pg-i", "asset:ui/arrow-r.png")]),
    box("win win-units", []),
    lst("ugrid", "$army.rows", button("ucard", [{"set": {"unit": "{k}", "slot": -1}}, {"navigate": "personal"}], [
        box("umug", [img("umug-i", "$mini", visibleIf="$hasMini")]),
        text("uname", "{name}"), text("ulv", "{lv}"), text("uhp", "HP {hp}"),
    ], classIf={"sel": "$sel", "off": "$off"})),
], 0)

personal = page("personal", left_column() + header("Personal data", "1/3", "weapons", "items") + [
    box("win win-right", []),
    lst("srows", "$pd.rows", box("srow", [
        text("s-l", "{label}"), box("s-bar", [box("s-fill", [], bindStyle={"width": "{pct}"})]),
        text("s-v", "{value}", classIf={"max": "$max"}),
    ])),
    text("r-l r1", "Move"), text("r-v r1", "{pd.move}"), text("r-b r1", "{pd.moveBonus}"),
    text("r-l r2", "Con"), text("r-v r2", "{pd.con}"),
    text("r-l r3", "Aid"), text("r-v r3", "{pd.aid}"),
    text("r-l r4", "Trv"), text("r-v r4 small", "{pd.trv}"),
    text("r-l r5", "Affin"), img("r-icon r5", "$pd.affIcon", visibleIf="$pd.hasAff"),
    text("r-l r6", "Cond"), text("r-v r6 small", "{pd.cond}"),
], 1)

items = page("items", left_column() + header("Items", "2/3", "personal", "weapons") + [
    box("win win-right", []),
    lst("irows", "$it.rows", button("irow", [{"set": {"slot": "{slot}"}}], [
        img("i-icon", "$icon"), text("i-name", "{name}"), text("i-uses", "{uses}"), text("i-eq", "E", visibleIf="$eq"),
    ], classIf={"sel": "$sel"})),
    text("i-empty", "No items.", visibleIf="$it.empty"),
    box("eqbox", [
        text("eq-h", "Equipment"),
        text("eq-l e1", "Rng"), text("eq-v e1", "{it.rng}"),
        text("eq-l e2", "Atk"), text("eq-v e2", "{it.atk}"),
        text("eq-l e3", "Crit"), text("eq-v e3", "{it.crit}"),
        text("eq-l e4", "Hit"), text("eq-v e4", "{it.hit}"),
        text("eq-l e5", "Avoid"), text("eq-v e5", "{it.avoid}"),
        text("eq-src", "{it.source}"),
    ]),
    box("acts", [
        text("act-n", "{it.selName}"),
        button("abtn", [{"call": "equip", "args": ["{u.k}", "{it.selSlot}"]}], [text("abtn-t", "Equip")], visibleIf="$it.canEquip"),
        button("abtn", [{"call": "use", "args": ["{u.k}", "{it.selSlot}"]}], [text("abtn-t", "Use")], visibleIf="$it.canUse"),
        button("abtn", [{"call": "store", "args": ["{u.k}", "{it.selSlot}"]}], [text("abtn-t", "Supply")], visibleIf="$it.hasSel"),
    ]),
    note(),
], 2)

weapons = page("weapons", left_column() + header("Weapon & support", "3/3", "items", "personal") + [
    box("win win-right", []),
    lst("wgrid", "$wp.ranks", box("wcell", [
        img("w-icon", "$icon"), box("w-bar", [box("w-fill", [], bindStyle={"width": "{pct}"})]),
        text("w-l", "{letter}", classIf={"s": "$s"}),
    ], classIf={"none": "$none"})),
    box("wline", []),
    lst("suplist", "$wp.sups", box("sup", [
        img("sup-a", "$aff", visibleIf="$hasAff"), text("sup-n", "{name}"),
        box("sup-bar", [box("sup-fill", [], bindStyle={"width": "{pct}"})]), text("sup-l", "{level}"),
    ], classIf={"got": "$got", "unknown": "$unknown"})),
    text("sup-none", "No support partners.", visibleIf="$wp.noSup"),
], 3)

supply = page("supply", [
    lst("tabs", "$sup.tabs", button("tab", [{"set": {"tab": "{i}", "cpage": 1, "cv": -1}}], [
        img("tab-i", "$icon", visibleIf="$hasIcon"), text("tab-t", "{label}", visibleIf="$noIcon"),
    ], classIf={"sel": "$sel"})),
    box("plate plate-sup", [text("plate-t", "{sup.tabName}"), text("plate-c", "{sup.count}")]),
    box("win win-sup", []),
    lst("cgrid", "$sup.rows", button("crow", [{"set": {"cv": "{ci}"}}], [
        img("c-icon", "$icon"), text("c-name", "{name}"), text("c-uses", "{uses}"),
    ], classIf={"sel": "$sel"})),
    text("c-empty", "Nothing here.", visibleIf="$sup.empty"),
    button("pg pg-cl", [{"set": {"cpage": "{sup.prev}"}}], [img("pg-i", "asset:ui/arrow-l.png")]),
    text("pg-cn", "{sup.page}"),
    button("pg pg-cr", [{"set": {"cpage": "{sup.next}"}}], [img("pg-i", "asset:ui/arrow-r.png")]),
    box("acts acts-sup", [
        text("act-n", "{sup.selName}"),
        button("abtn wide", [{"call": "give", "args": ["{u.k}", "{sup.selCi}"]}], [text("abtn-t", "Give to {sup.unitName}")],
               visibleIf="$sup.canGive"),
        text("act-full", "{sup.unitName} is full", visibleIf="$sup.unitFull"),
    ]),
    note(),
], 4)

status = page("status", [
    box("plate plate-st", [text("st-title", "{st.title}")]),
    box("st-left", []),
    box("st-goal", [text("st-goal-h", "Objective"), text("st-goal-t", "{st.goal}")]),
    text("st-k st-k1", "Turn"), text("st-v st-v1", "{st.turn}"),
    text("st-k st-k2", "Funds"), text("st-v st-v2", "{st.funds}G"),
    box("st-side st-player", [text("st-side-h", "PLAYER"), text("st-side-v", "{st.player}")]),
    box("st-side st-enemy", [text("st-side-h", "ENEMY"), text("st-side-v", "{st.enemy}")]),
    box("st-lead", [
        box("st-mug", [img("st-mug-i", "$st.leadMini", visibleIf="$st.hasLead")]),
        text("st-lname", "{st.lead}"),
        text("st-ll st-ll1", "LV"), text("st-lv st-lv1", "{st.leadLv}"),
        text("st-ll st-ll2", "HP"), text("st-lv st-lv2", "{st.leadHp}"),
    ]),
    box("st-time", [text("st-time-h", "PLAY TIME"), text("st-time-v", "{st.time}")]),
    text("st-mode", "{st.mode}  -  {st.army} units"),
], 5)

waiting = box("page page-waiting", [
    img("leaves", "asset:ui/stone.png"),
    box("wbox", [text("w-1", "THE SACRED STONES"), text("w-2", "Fire Emblem companion"),
                 text("w-3", "Load a chapter to see your army."),
                 text("w-4", "This pack reads the USA cartridge (BE8E).", visibleIf="$wrongRom")]),
])

body = [(n, p) for n, p in zip([p[0] for p in PAGES], [units, personal, items, weapons, supply, status])]
root = box("main", [
    box("waiting", [waiting], visibleIf="$waiting"),
    box("ready", [
        {"type": "pages", "class": "stage", "initial": "personal", "pages": [{"name": n, "child": c} for n, c in body]},
        button("toast", [{"set": {"toastHide": "{toast.id}", "unit": "{toast.k}", "slot": -1}}, {"navigate": "personal"}], [
            box("toast-mug", [img("toast-mug-i", "$toast.mini", visibleIf="$toast.hasMini")]),
            text("toast-title", "{toast.title}"), text("toast-name", "{toast.name}"), text("toast-sub", "{toast.sub}"),
        ], visibleIf="$toastOn"),
    ], visibleIf="$ready"),
], id="screen")

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    json.dump(root, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
    # portrait block offsets are generated into the stylesheet between the markers
    p = os.path.join(here, "style.src.css")
    s = open(p).read()
    a, b = "/* portrait:begin */", "/* portrait:end */"
    if a in s and b in s:
        s = s[:s.index(a) + len(a)] + "\n" + portrait_css() + "\n" + s[s.index(b):]
        open(p, "w").write(s)
    print("ok", len(json.dumps(root)))
