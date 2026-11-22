#!/usr/bin/env python3
"""Writes layout.json: four ring pages (Goods, Equip, PSI, Status), each = header (character tabs + page
name + DP) / windows / bottom bar (previous page | this page | next page), like the Pokemon packs.

  python3 art/layout.py
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))


def box(cls, children=None, **kw):
    n = {"type": "box", "class": cls}
    if children is not None:
        n["children"] = children
    n.update(kw)
    return n


def text(cls, t, **kw):
    return {"type": "text", "class": cls, "text": t, **kw}


def img(cls, src, **kw):
    return {"type": "image", "class": cls, "src": src, **kw}


def lst(cls, items, template, **kw):
    return {"type": "list", "class": cls, "items": items, "template": template, **kw}


ui = lambda n: f"asset:ui/{n}.png"
grow = box("grow", [])
RING = [("goods", "Goods"), ("equip", "Equip"), ("psi", "PSI"), ("status", "Status")]

# ---- header ------------------------------------------------------------------------------------------
tab = {
    "type": "button", "class": "ctab", "classIf": {"on": "$on"},
    "onClick": [{"set": {"ch": "{idx}", "slot": 1, "eq": 0}}],
    "children": [
        img("ctab-img", "$portrait", visibleIf="$hasPortrait"),
        box("ctab-init", [text("ctab-init-t", "{initial}")], visibleIf="$noPortrait"),
    ],
}


def header(title):
    return box("hdr", [
        lst("ctabs", "$chars", tab),
        grow,
        box("hdr-right", [
            box("pill", [text("pill-t", title)]),
            box("dp", [text("dp-l", "DP"), text("dp-v", "{dp}")]),
        ]),
    ])


# ---- bottom bar ---------------------------------------------------------------------------------------
def nav(to, label, icon, side):
    return {
        "type": "button", "class": f"bar-btn bar-{side}", "onClick": [{"navigate": to}],
        "children": ([text("bar-chev", "<")] if side == "l" else []) + [
            img("bar-ico", ui("i-" + icon)), text("bar-label", label)
        ] + ([text("bar-chev", ">")] if side == "r" else []),
    }


def bar(i):
    p, pl = RING[(i - 1) % 4]
    n, nl = RING[(i + 1) % 4]
    return box("bar", [nav(p, pl, p, "l"), box("bar-mid", [text("bar-title", RING[i][1])]), nav(n, nl, n, "r")])


def page(i, body):
    name, title = RING[i]
    return {"name": name, "child": box(f"page page-{name}", [header(title), body, bar(i)])}


# ---- shared window pieces -----------------------------------------------------------------------------
def win(cls, children, **kw):
    return box(f"win {cls}", children, **kw)


def desc_win(name_expr, desc_expr, extra=None, visible=None):
    kids = []
    if extra:
        kids.append(extra)
    kids.append(box("desc-text", [text("desc-name", name_expr), text("desc-body", desc_expr)]))
    w = win("desc", kids)
    if visible:
        w["visibleIf"] = visible
    return w


def boxed(expr, cls=""):
    return box(f"num {cls}".strip(), [text("num-t", expr)])


# ---- 1. goods -----------------------------------------------------------------------------------------
good_row = box("grow-row", [
    box("cur", [], classIf={"on": "$on"}),
    box("badge", [text("badge-t", "E")], visibleIf="$eq"),
    box("badge-gap", [], visibleIf="$noEq"),
    text("li-name", "{name}"),
], classIf={"on": "$on", "empty": "$empty"}, onClick=[{"set": {"slot": "{slot}"}}])

def act(label, mode, off_flag):
    return {"type": "button", "class": "act", "classIf": {"off": off_flag},
            "onClick": [{"set": {"mode": mode, "msg": ""}}],
            "children": [text("act-t", label)]}


goods_desc = win("desc", [
    box("desc-text", [
        text("desc-name", "{goods.name}"),
        text("desc-body", "{goods.desc}"),
        text("desc-note", "{goods.note}", visibleIf="$goods.hasNote"),
    ]),
    box("acts-col", [
        box("acts", [act("Use", "use", "$goods.noUse"), act("Give", "give", "$goods.noMove"), act("Drop", "drop", "$goods.noMove")]),
        {"type": "box", "class": "perm", "classIf": {"on": "$_writePerm"}, "onClick": {"call": "writePermission"},
         "children": [text("perm-t", "GAME CHANGES {_writePermLabel}")]},
    ]),
], visibleIf="$goods.hasSel")


def target(call):
    return {
        "type": "button", "class": "target", "onClick": [{"call": call, "args": ["{idx}"]}],
        "children": [
            img("target-img", "$portrait", visibleIf="$hasPortrait"),
            box("ctab-init target-init", [text("ctab-init-t", "{initial}")], visibleIf="$noPortrait"),
            text("target-name", "{name}"),
            grow,
            text("target-hp", "{hp}/{maxhp}"),
        ],
    }


cancel = {"type": "button", "class": "dlg-btn", "onClick": [{"set": {"mode": ""}}], "children": [text("dlg-btn-t", "Cancel")]}
sheet = box("sheet", [
    box("dialog", onClick=[{"set": {"_keep": 1}}], children=[
        text("dlg-title", "{goods.sheetTitle}"),
        lst("targets", "$targets", target("doUse"), visibleIf="$goods.sheetUse"),
        lst("targets", "$giveTargets", target("doGive"), visibleIf="$goods.sheetGive"),
        box("dlg-row", [
            {"type": "button", "class": "dlg-btn", "onClick": [{"call": "doDrop"}], "children": [text("dlg-btn-t", "Yes")]},
            {"type": "button", "class": "dlg-btn", "onClick": [{"set": {"mode": ""}}], "children": [text("dlg-btn-t", "No")]},
        ], visibleIf="$goods.sheetDrop"),
        box("dlg-row", [cancel], visibleIf="$goods.sheetPick"),
    ]),
], visibleIf="$goods.sheet", onClick=[{"set": {"mode": ""}}])

goods_page = box("body", [
    win("list-win", [
        lst("grid-list", "$goods.rows", good_row, classIf={"locked": "$goods.sheet"}),
        box("empty-note", [text("empty-t", "No goods.")], visibleIf="$goods.isEmpty"),
    ]),
    goods_desc,
    sheet,
])

# ---- 2. equip -----------------------------------------------------------------------------------------
def srow(label, expr):
    return box("srow", [text("srow-l", label), grow, boxed(expr)])


equip_page = box("body", [
    box("equip-top", [
        win("stat-win", [
            text("name-line", "{c.name}"),
            srow("Level", "{c.level}"),
            srow("Max. HP", "{c.maxhp}"),
            srow("Max. PP", "{c.maxpp}"),
            srow("Offense", "{c.offense}"),
            srow("Defense", "{c.defense}"),
            srow("IQ", "{c.iq}"),
            srow("Speed", "{c.speed}"),
        ]),
        win("slot-win", [
            lst("slots", "$c.equip", box("slot", [
                box("cur", [], classIf={"on": "$on"}),
                box("slot-col", [text("slot-label", "{label}"), text("slot-item", "{name}", classIf={"none": "$none"})]),
            ], classIf={"on": "$on"}, onClick=[{"set": {"eq": "{slot}"}}])),
        ]),
    ]),
    desc_win("{eqName}", "{eqDesc}"),
])

# ---- 3. psi -------------------------------------------------------------------------------------------
psi_row = box("grow-row psi-row", [
    box("cur", [], classIf={"on": "$on"}),
    text("li-name", "{name}"),
    grow,
    boxed("{pp}"),
], classIf={"on": "$on"}, onClick=[{"set": {"psi": "{id}"}}])

psi_page = box("body", [
    win("list-win psi-win", [
        lst("grid-list", "$psi.rows", psi_row),
    ]),
    desc_win("{psi.name}", "{psi.desc}", extra=box("pp-chip", [
        text("pp-chip-l", "PP COST"), boxed("{psi.pp}"),
        text("pp-chip-l", "{c.name}"), boxed("{c.pp}/{c.maxpp}", "wide"),
    ])),
])

# ---- 4. status ----------------------------------------------------------------------------------------
def krow(label, expr, cls=""):
    return box("srow", [text("srow-l", label), grow, boxed(expr, cls)])


def trow(label, expr):
    return box("srow", [text("srow-l", label), box("trow-gap", []), text("trow-v", expr)])


status_page = box("body", [
    win("status-win", [
        text("name-line", "{c.name}"),
        box("status-cols", [
            box("scol", [
                krow("Level", "{c.level}"), krow("Offense", "{c.offense}"), krow("Defense", "{c.defense}"),
                krow("IQ", "{c.iq}"), krow("Speed", "{c.speed}"), krow("EXP", "{c.exp}", "wide"),
                krow("Next Level", "{c.next}", "wide"),
            ]),
            box("scol scol-r", [
                box("srow", [text("srow-l", "HP"), grow, boxed("{c.hp}/{c.maxhp}", "wide")]),
                box("srow", [text("srow-l", "PP"), grow, boxed("{c.pp}/{c.maxpp}", "wide")]),
                trow("Weapon", "{c.weapon}"), trow("Body", "{c.body}"), trow("Head", "{c.head}"),
                trow("Other", "{c.other}"), trow("Skills", "{c.skills}"),
            ]),
        ]),
    ]),
    win("desc gauges", [
        box("gauge", [text("gauge-l", "HP"), {"type": "bar", "class": "meter hp", "value": "$c.hpPct", "max": 1}, text("gauge-v", "{c.hp}")]),
        box("gauge", [text("gauge-l", "PP"), {"type": "bar", "class": "meter pp", "value": "$c.ppPct", "max": 1}, text("gauge-v", "{c.pp}")], visibleIf="$c.hasPP"),
    ]),
])

layout = box("screen-root", [
    box("waiting", [box("boot", [
        text("boot-title", "MOTHER 3"),
        text("boot-sub", "Load a save to begin"),
        text("boot-pill", "GBA DUO COMPANION PACK"),
    ])], classIf={"gone": "$ready"}),
    box("shell", [{
        "type": "pages", "initial": "goods",
        "pages": [page(0, goods_page), page(1, equip_page), page(2, psi_page), page(3, status_page)],
    }], classIf={"on": "$ready"}),
], id="screen")

json.dump(layout, open(os.path.join(HERE, "..", "layout.json"), "w"), indent=2)
print("ok")
