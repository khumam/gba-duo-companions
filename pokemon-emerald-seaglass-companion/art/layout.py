#!/usr/bin/env python3
"""Builds layout.json for the Seaglass companion.

Run it from anywhere:  python art/layout.py      (it writes ../layout.json next to this folder)

The layout is a widget tree the app renders; the Lua script (main.lua) supplies every value. Nothing
here computes data, it only says where things sit and which key each text/bar/list reads:

  {"type": "text", "class": "mon-name", "text": "{name}"}     a value from the script's return table
  {"type": "list", "items": "$party", "template": {...}}      one template per row, {field} = row field
  {"type": "bar",  "value": "$hpPct", "max": 1}               width = value / max, classIf colours it
  {"type": "tabs", ...}  /  {"type": "pages", ...}              the bag's pockets and the page ring

Pages, in ring order: party, detail, bag, dex, card, diag.
"""
import json
import os

def box(cls, children, **extra):
    """A flex container; extra kwargs pass through (visibleIf, onClick, bindStyle ...)."""
    d = {"type": "box", "class": cls, "children": children}
    d.update(extra)
    return d

def text(cls, t, **extra):
    """A single line of text; {} in the string is a binding, @index is the row's position in a list."""
    d = {"type": "text", "class": cls, "text": t}
    d.update(extra)
    return d

def img(cls, src, **extra):
    """An image: asset:... for a shipped PNG, $key for a value main.lua returns (a decoded ROM sprite)."""
    d = {"type": "image", "class": cls, "src": src}
    d.update(extra)
    return d

def lst(cls, items, template, **extra):
    """Repeats one template per entry of the $list main.lua returns."""
    d = {"type": "list", "class": cls, "items": items, "template": template}
    d.update(extra)
    return d

def win(cls, title, body, chip=None):
    """A game window: a title tab on the frame's top edge, an optional chip on the right, then the body."""
    top = [box("wtab", [text("wtab-text", title)])]
    if chip:
        top.append(box("grow", []))
        top.append(chip)
    return box(f"win {cls}", [box("wtop", top), box("wbody", body)])

def chip(t, cls=""):
    """A small rounded label, used for counts and abilities."""
    return box(f"chip {cls}".strip(), [text("chip-text", t)])

def bar(cls, value, maxv=1, **extra):
    """A gauge; classIf (mid/low) maps to CSS classes so the fill can change colour."""
    d = {"type": "bar", "class": cls, "value": value, "max": maxv}
    d.update(extra)
    return d

grow = box("grow", [])
UI = "asset:ui/"

# ---------------------------------------------------------------- chrome
RING = [("party", "POK\u00c9MON"), ("bag", "BAG"), ("dex", "SPECIES"), ("card", "TRAINER"), ("diag", "DIAG")]

def header(title, active, with_gems=True):
    """The top band every page shares: page title, five dots, clock, money, badge gems."""
    kids = [
        text("hdr-name", title),
        box("hdr-dots", [box(f"dot{' on' if i == active else ''}", []) for i in range(len(RING))]),
    ]
    tail = [
        box("hstat", [img("hicon", UI + "clock.png"), text("hval", "{time}")]),
        box("hstat", [img("hicon", UI + "coin.png"), text("hval", "{money}")]),
    ]
    if with_gems:
        tail.append(lst("gems", "$badges", img("gem", "$src", classIf={"off": "$locked"})))
    return box("hdr", [box("hdr-title", kids), box("hdr-tail", tail)])

def nav(to, label, side):
    """One side of the bottom bar: an arrow plus the page it goes to."""
    kids = []
    if side == "l":
        kids.append(img("chev", UI + "chev-l.png"))
    kids.append(text("bar-label", label))
    if side == "r":
        kids.append(img("chev", UI + "chev-r.png"))
    return {"type": "button", "class": f"bar-btn bar-{side}", "onClick": [{"navigate": to}], "children": kids}

def ring(i, mid=None):
    prev = RING[(i - 1) % len(RING)]
    nxt = RING[(i + 1) % len(RING)]
    return box("bar", [nav(prev[0], prev[1], "l"),
                       box("bar-mid", [text("bar-title", mid or RING[i][1])]),
                       nav(nxt[0], nxt[1], "r")])

def back():
    return box("bar", [{"type": "button", "class": "bar-btn bar-full", "onClick": "back",
                        "children": [text("bar-label", "BACK TO TEAM")]}])

def type_row(path):
    return lst("type-row", f"${path}", box("tchip", [text("tchip-text", "{label}")],
                                           bindStyle={"--c": "{color}"}))

def hp_bar(path):
    return bar("hp", f"${path}hpPct", classIf={"mid": f"${path}hpMid", "low": f"${path}hpLow"})

def hp_bar_plain(path, mid, low):
    return bar("hp", f"${path}hpPct", classIf={"mid": f"${mid}", "low": f"${low}"})

# ---------------------------------------------------------------- 1. party
mon_row = box("mon-row", [
    box("slot", [img("sprite", "$sprite")]),
    text("mon-name", "{name}"),
    text("lv", "Lv{level}"),
    img("gender", UI + "male.png", visibleIf="$male"),
    img("gender", UI + "female.png", visibleIf="$female"),
    box("status", [text("status-text", "{status}")], visibleIf="$hasStatus"),
    type_row("types"),
    grow,
    text("hp-num", "{hpText}"),
    hp_bar(""),
    text("row-go", ">"),
], onClick=[{"set": {"detailIndex": "{idx}"}}, {"navigate": "detail"}])

party_page = box("page page-party", [
    header("POK\u00c9MON", 0),
    box("team-strip", [
        text("team-k", "TEAM HP"),
        bar("hp team-bar", "$team.hpPct", classIf={"mid": "$team.hpMid", "low": "$team.hpLow"}),
        text("team-v", "{team.hp}/{team.maxHp}"),
        chip("{partyCount}/{partyMax}", "chip-sea"),
        chip("AVG Lv{team.avg}", "chip-cream"),
    ]),
    win("list-win", "YOUR TEAM", [
        lst("mon-list", "$party", mon_row, visibleIf="$hasParty"),
        box("empty", [text("empty-t", "NO POK\u00c9MON YET"),
                      text("empty-s", "YOUR TEAM SHOWS UP HERE ONCE YOU HAVE ONE")], visibleIf="$noParty"),
    ], chip("{partyCount} IN PARTY", "chip-cream")),
    ring(0),
])

# ---------------------------------------------------------------- 2. detail
detail_top = box("detail-top", [
    box("portrait", [img("sprite-xl", "$detail.sprite")]),
    box("detail-id", [
        box("name-row", [
            text("mon-name big", "{detail.name}"),
            text("lv", "Lv{detail.level}"),
            img("gender", UI + "male.png", visibleIf="$detail.male"),
            img("gender", UI + "female.png", visibleIf="$detail.female"),
            box("status", [text("status-text", "{detail.status}")], visibleIf="$detail.hasStatus"),
        ]),
        box("name-row", [type_row("detail.types"), grow, text("dexno", "No.{detail.dexno}")]),
        box("name-row", [bar("hp", "$detail.hpPct", classIf={"mid": "$detail.hpMid", "low": "$detail.hpLow"}),
                         text("hp-num", "{detail.hpText}")]),
        box("name-row", [
            chip("ABILITY {detail.ability}", "chip-sea"),
            chip("{detail.nature}", "chip-cream"),
            chip("ITEM {detail.heldItem}", "chip-cream"),
            grow,
            text("foot-dim", "{detail.height} {detail.weight}"),
        ]),
    ]),
])

stat_row = box("stat-row", [
    text("stat-k", "{label}"),
    bar("stat-bar", "$pct", classIf={"low": "$low"}),
    text("stat-v", "{value}"),
    text("stat-ev", "{ev}"),
])

move_row = box("move-row", [
    box("tchip wide", [text("tchip-text", "{label}")], bindStyle={"--c": "{color}"}),
    box("move-main", [
        box("name-row", [text("move-name", "{name}"), grow,
                         text("move-x", "{power}/{acc}")]),
        box("name-row", [
            bar("pp-bar", "$ppPct", classIf={"low": "$ppLow"}),
            text("move-pp", "{pp}"),
        ]),
    ]),
])

detail_page = box("page page-detail", [
    header("SUMMARY", 0, with_gems=False),
    box("detail-body", [
        detail_top,
        box("detail-cols", [
            win("stat-win", "STATS", [lst("stat-list", "$detail.stats", stat_row),
                                       text("dex-text", "{detail.dexText}")]),
            win("move-win", "MOVES", [lst("move-list", "$detail.moves", move_row)]),
        ]),
    ]),
    back(),
])

# ---------------------------------------------------------------- 3. bag
def pocket_items(path):
    return lst("item-list", f"$bag.{path}", box("item-row", [
        text("item-name", "{name}"),
        grow,
        text("item-count", "{count}"),
    ], onClick=[{"set": {"selName": "{name}", "selDesc": "{desc}", "selCount": "{count}"}}]))

def pocket(title, path):
    return {"title": title, "child": pocket_items(path)}

bag_page = box("page page-bag", [
    header("BAG", 1),
    box("bag-grid", [
        win("list-win", "POCKETS", [{
            "type": "tabs", "class": "pockets", "tabs": [
                pocket("ITEMS", "items"), pocket("KEY", "keyItems"),
                pocket("BALLS", "balls"), pocket("TM/HM", "tmHm"),
            ],
        }], chip("{bagTotal} TOTAL", "chip-sea")),
        win("insp-win", "ITEM", [
            box("insp-body", [
                box("name-row", [text("insp-name", "{bag.sel.name}"), grow,
                                 text("item-count", "{bag.sel.count}")]),
                box("insp-desc", [text("insp-text", "{bag.sel.desc}")]),
            ], visibleIf="$bag.hasSel"),
            box("empty", [text("empty-t", "TAP AN ITEM"),
                          text("empty-s", "{bag.used} OF {bag.capacity} SLOTS USED")], visibleIf="$bag.noSel"),
        ]),
    ]),
    ring(1),
])

# ---------------------------------------------------------------- 4. dex
dex_row = box("dex-row", [
    box("slot s", [img("sprite", "$sprite")]),
    text("dexno", "{no}"),
    text("dex-name", "{name}"),
    grow,
    text("row-go", ">"),
], onClick=[{"set": {"dexSel": "{species}"}}])

dex_page = box("page page-dex", [
    header("SPECIES", 2, with_gems=False),
    box("dex-grid", [
        win("dex-list-win", "SEAGLASS DEX", [
            box("pager", [
                {"type": "button", "class": "pg-btn", "onClick": [{"call": "dexPrev"}],
                 "children": [text("pg-t", "<")]},
                text("pager-range", "{dex.range}"),
                {"type": "button", "class": "pg-btn", "onClick": [{"call": "dexNext"}],
                 "children": [text("pg-t", ">")]},
            ]),
            lst("dex-list", "$dex.entries", dex_row),
        ]),
        win("dex-info-win", "ENTRY", [
            box("dex-head", [
                box("slot", [img("sprite-xl", "$dex.sel.sprite")]),
                box("dex-head-t", [
                    box("name-row", [text("dexno", "No.{dex.sel.no}"), text("mon-name", "{dex.sel.name}")]),
                    box("name-row", [type_row("dex.sel.types")]),
                    text("dex-cat", "{dex.sel.category}"),
                    text("dex-dim", "{dex.sel.height}  {dex.sel.weight}  BST {dex.sel.total}"),
                ]),
            ]),
            box("dex-stats", [lst("stat-list mini", "$dex.sel.stats", box("stat-row", [
                text("stat-k", "{label}"), bar("stat-bar", "$pct"), text("stat-v", "{value}")]))]),
            text("dex-abil", "ABILITY: {dex.sel.abilities}"),
            box("dex-desc", [text("dex-text", "{dex.sel.desc}")]),
        ]),
    ]),
    ring(2),
])

# ---------------------------------------------------------------- 5. trainer card
card_page = box("page page-card", [
    header("TRAINER", 3),
    box("card-grid", [
        win("id-win", "TRAINER CARD", [
            box("name-row", [
                text("mon-name big", "{trainer.name}"),
                img("gender", UI + "male.png", visibleIf="$trainer.male"),
                img("gender", UI + "female.png", visibleIf="$trainer.female"),
            ]),
            box("id-rows", [
                box("irow", [text("ikey", "ID No."), grow, text("ival", "{trainer.id}")]),
                box("irow", [text("ikey", "MONEY"), grow, text("ival", "¥{money}")]),
                box("irow", [text("ikey", "COINS"), grow, text("ival", "{coins}")]),
                box("irow", [text("ikey", "PLAY TIME"), grow, text("ival", "{time}")]),
                box("irow", [text("ikey", "TEAM"), grow, text("ival", "{partyCount}/{partyMax}")]),
                box("irow", [text("ikey", "BAG"), grow, text("ival", "{bag.used}/{bag.capacity}")]),
            ]),
        ]),
        win("badge-win", "BADGES", [
            lst("badge-grid", "$badges", box("badge", [img("badge-img", "$src")],
                                            classIf={"locked": "$locked"})),
            box("name-row", [text("badge-k", "EARNED"), grow, text("badge-v", "{badgeCount}/8")]),
            box("badge-rule", []),
            text("badge-note", "BADGES COME FROM THE GAME'S OWN FLAG BITS"),
        ]),
    ]),
    win("card-team-win", "TEAM", [
        lst("card-team", "$party", box("mini-mon", [
            box("slot xs", [img("sprite", "$sprite")]),
            text("mini-name", "{name}"),
            text("mini-lv", "L{level}"),
        ])),
    ]),
    ring(3),
])

# ---------------------------------------------------------------- 6. diag
diag_page = box("page page-diag", [
    header("DIAGNOSTICS", 4, with_gems=False),
    win("diag-win", "WHAT THE PACK FOUND", [
        lst("diag-list", "$diag.lines", box("irow", [
            text("ikey", "{k}"), grow, text("ival", "{v}"),
        ])),
        box("diag-note", [text("diag-note-t",
            "IF A VALUE HERE LOOKS WRONG, SEND THIS PAGE TO THE PACK AUTHOR.")]),
    ]),
    ring(4),
])

pages_widget = {"type": "pages", "initial": "party", "pages": [
    {"name": "party", "child": party_page},
    {"name": "detail", "child": detail_page},
    {"name": "bag", "child": bag_page},
    {"name": "dex", "child": dex_page},
    {"name": "card", "child": card_page},
    {"name": "diag", "child": diag_page},
]}

root = box("screen", [
    box("waiting", [
        box("boot", [
            img("boot-ball", UI + "pk-balls.png"),
            text("boot-title", "SEAGLASS"),
            text("boot-sub", "{waitNote}"),
            text("boot-dim", "GBA DUO COMPANION · v0.1.0"),
        ]),
    ], visibleIf="$waiting"),
    box("shell", [pages_widget], visibleIf="$ready"),
])

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "layout.json")
with open(OUT, "w", encoding="utf-8") as f:
    json.dump(root, f, indent=1, ensure_ascii=False)
print("layout.json written:", len(json.dumps(root)), "bytes")
