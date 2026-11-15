#!/usr/bin/env python3
"""Writes layout.json: the game's pause menu (Status / Items / Journal) for the second screen.
Every page repeats the chrome (window, tab bar, corner arrows), so edit here, not by hand:

    python3 art/layout.py
"""
import json, os

def box(cls, children=(), **kw):  return {"type": "box", "class": cls, "children": list(children), **kw}
def text(cls, t, **kw):          return {"type": "text", "class": cls, "text": t, **kw}
def img(cls, src, **kw):         return {"type": "image", "class": cls, "src": src, **kw}
def button(cls, on, children, **kw): return {"type": "button", "class": cls, "onClick": on, "children": list(children), **kw}
def lst(cls, items, tpl, **kw):  return {"type": "list", "class": cls, "items": items, "template": tpl, **kw}
def bar(cls, value, **kw):       return {"type": "bar", "class": cls, "value": value, "max": 1, **kw}
ui = lambda n: f"asset:ui/{n}.png"

# the menu cycles like the game's L / R: each page names its neighbours
PAGES = [("journal", "JOURNAL"), ("status", "STATUS"), ("items", "ITEMS"), ("options", "OPTIONS")]

def arrow(side, on_cond, action):
    """Corner arrow: a dim picture always, the lit one (and the tap) while the arrow is usable."""
    return box(f"corner corner-{side}", [
        img("arrow", ui(f"arrow-{side}-off")),
        button("arrow-btn", action, [img("arrow", ui(f"arrow-{side}-on"))], visibleIf=on_cond) if action else box("none"),
    ])

def chrome(i, title, corners):
    pn, pl = PAGES[(i - 1) % len(PAGES)]
    nn, nl = PAGES[(i + 1) % len(PAGES)]
    return [
        img("navbar", ui("navbar")),
        button("tab tab-l", [{"navigate": pn}], [img("shoulder", ui("shoulder-l")), text("tab-name tab-name-l", pl)]),
        text("nav-title", PAGES[i][1]),
        button("tab tab-r", [{"navigate": nn}], [img("shoulder", ui("shoulder-r")), text("tab-name tab-name-r", nl)]),
        *corners,
    ]

# ---- status -------------------------------------------------------------------------------
def stat_row(cls, label, value, pct, seg):
    return [
        text(f"lbl lbl-{cls}", label),
        bar(f"bar {'seg' if seg else 'solid'} bar-{cls}", pct),
        text(f"num num-{cls}", value),
    ]

def vis(nodes, flag):
    return [dict(n, visibleIf=flag) for n in nodes]

status = box("page page-status", [
    img("win", ui("win-plain")),
    text("who", "{member.name}", ),
    text("lvl", "LEVEL: {member.level}", visibleIf="$showStats"),
    *vis([
        *stat_row("hp", "HP", "{member.hp}/{member.maxHp}", "$member.hpPct", False),
        *stat_row("ep", "EP", "{member.ep}/{member.maxEp}", "$member.epPct", False),
        *stat_row("str", "STR", "{member.str}/100", "$member.strPct", True),
        *stat_row("pow", "POW", "{member.pow}/100", "$member.powPct", True),
        *stat_row("end", "END", "{member.end_}/100", "$member.endPct", True),
        img("portrait", "$member.portrait"),
        text("lbl lbl-exp", "EXP"), text("val val-exp", "{member.exp}"),
        text("lbl lbl-next", "NEXT"), text("val val-next", "{member.next}"),
    ], "$showStats"),
    text("tname", "{tech.name}", visibleIf="$showTech"),
    text("tcount", "{techNo}", visibleIf="$showTech"),
    text("tdesc", "{tech.desc}", visibleIf="$showTech"),
    box("side side-u", [img("arrow", ui("arrow-u-off")),
        button("arrow-btn", [{"set": {"tv": "{prevTv}"}}], [img("arrow", ui("arrow-u-on"))], visibleIf="$canUp")]),
    box("side side-d", [img("arrow", ui("arrow-d-off")),
        button("arrow-btn", [{"set": {"tv": "{nextTv}"}}], [img("arrow", ui("arrow-d-on"))], visibleIf="$canDown")]),
    lst("roster", "$roster", button("pick", [{"set": {"who": "{idx}"}}], [text("pick-name", "{name}")], classIf={"sel": "$sel"})),
    *chrome(1, "STATUS", [
        arrow("l", "$multi", [{"set": {"who": "{prevWho}"}}]) | {"class": "corner corner-l"},
        arrow("r", "$multi", [{"set": {"who": "{nextWho}"}}]) | {"class": "corner corner-r"},
    ]),
])

# ---- items --------------------------------------------------------------------------------
items = box("page page-items", [
    img("win", ui("win-list")),
    text("tab-title", "ITEMS"),
    box("side side-u", [img("arrow", ui("arrow-u-off")),
        button("arrow-btn", [{"set": {"item": "{prevItem}"}}], [img("arrow", ui("arrow-u-on"))], visibleIf="$multiItems")]),
    box("side side-d", [img("arrow", ui("arrow-d-off")),
        button("arrow-btn", [{"set": {"item": "{nextItem}"}}], [img("arrow", ui("arrow-d-on"))], visibleIf="$multiItems")]),
    lst("itemlist", "$items", button("irow", [{"set": {"item": "{slot}", "popup": True}}], [
        box("ic", [img("icon", "$icon")], classIf={"sel": "$sel"}),
        box("itxt", [text("iname", "{name}"), text("icount", "{count}", visibleIf="$hasCount")]),
    ], classIf={"sel": "$sel"})),
    img("big", "$detail.big", visibleIf="$items"),
    text("desc", "{detail.desc}"),
    text("empty", "INVENTORY IS EMPTY", visibleIf="$noItems"),
    box("poplayer", [
        button("dim", [{"set": {"popup": False}}], []),
        img("pop", ui("popup")),
        img("pop-big", "$detail.big"),
        text("pop-q", "{detail.prompt}"),
        text("pop-sub", "{detail.sub}"),
        button("pop-btn pop-no", [{"set": {"popup": False}}], [img("round", ui("round")), text("rl", "B"), text("pop-lbl", "NO")], visibleIf="$detail.canUse"),
        button("pop-btn pop-yes", [{"set": {"popup": False}, "call": "use", "args": ["{detail.slot}", "{member.idx}"]}],
               [img("round", ui("round")), text("rl", "A"), text("pop-lbl", "YES")], visibleIf="$detail.canUse"),
        button("pop-btn pop-ok", [{"set": {"popup": False}}], [img("round", ui("round")), text("rl", "A"), text("pop-lbl", "OK")], visibleIf="$detail.noUse"),
    ], visibleIf="$ui.popup"),
    *chrome(2, "ITEMS", [box("corner corner-l", [img("arrow", ui("arrow-l-off"))]), box("corner corner-r", [img("arrow", ui("arrow-r-off"))])]),
])

# ---- journal ------------------------------------------------------------------------------
journal = box("page page-journal", [
    img("win", ui("win-list")),
    text("tab-title tab-title-wide", "{jTitle}"),
    button("jswitch", [{"set": {"jv": "{jvNext}"}}], []),
    lst("qlist", "$active", box("qrow", [box("star", classIf={"main": "$main", "side": "$side", "other": "$other"}), text("qtext", "{text}")]), visibleIf="$jActive"),
    lst("qlist", "$done", box("qrow", [img("check", ui("check")), text("qtext", "{text}")]), visibleIf="$jDone"),
    text("empty", "NO ACTIVE QUESTS", visibleIf="$showNoActive"),
    text("empty", "NO QUESTS FINISHED YET", visibleIf="$showNoDone"),
    text("jhint", "TAP THE TITLE: {jSwitch}"),
    *chrome(0, "JOURNAL", [box("corner corner-l", [img("arrow", ui("arrow-l-off"))]), box("corner corner-r", [img("arrow", ui("arrow-r-off"))])]),
])

# ---- options ------------------------------------------------------------------------------
options = box("page page-options", [
    img("win", ui("win-list")),
    text("tab-title", "OPTIONS"),
    button("orow", [{"call": "wideView", "args": ["toggle"]}], [
        text("oname", "WIDE VIEW"),
        text("oval", "{_wideLabel}", classIf={"on": "$_wide"}),
    ]),
    text("ohint", "SHOWS THE MAP BEYOND THE GAME SCREEN"),
    text("ohint ohint-2", "TAP: OFF, WIDE, XL"),
    *chrome(3, "OPTIONS", [box("corner corner-l", [img("arrow", ui("arrow-l-off"))]), box("corner corner-r", [img("arrow", ui("arrow-r-off"))])]),
])

waiting = box("page page-waiting", [
    img("win", ui("win-plain")),
    text("who", "DRAGON BALL Z"),
    text("wait-1", "THE LEGACY OF GOKU II"),
    text("wait-2", "LOAD A GAME TO SEE YOUR PARTY"),
])

root = box("main", [
    box("waiting", [waiting], visibleIf="$waiting"),
    box("ready", [{"type": "pages", "class": "stage", "pages": [
        {"name": "journal", "child": journal},
        {"name": "status", "child": status},
        {"name": "items", "child": items},
        {"name": "options", "child": options},
    ], "initial": "status"}], visibleIf="$ready"),
], id="screen")

here = os.path.dirname(os.path.abspath(__file__))
json.dump(root, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
print("ok")
