#!/usr/bin/env python3
"""Writes layout.json (+ art/pos.src.css): the game's pause windows (STATUS, ELF LIST, OPTION) as dashboard pages.
Backgrounds are drawn by art/game_ui.py; every live value is a text/gauge placed at fixed art-pixel positions
(`at(...)` registers a class, pos.src.css holds the coordinates). The game's L / R tabs along the bottom are buttons."""
import json

PAGES = [("status", "STATUS"), ("elves", "ELF LIST"), ("option", "OPTION")]
POS = []


def at(x, y, w=None, h=None):
    name = "p%d_%d_%s_%s" % (x, y, w or 0, h or 0)
    css = ".%s { left: %dap; top: %dap;" % (name, x, y)
    if w: css += " width: %dap;" % w
    if h: css += " height: %dap;" % h
    rule = css + " }"
    if rule not in POS: POS.append(rule)
    return name


def text(cls, t, pos=None, **kw):
    return {"type": "text", "class": cls + (" " + at(*pos) if pos else ""), "text": t, **kw}
def box(cls, children=None, pos=None, **kw):
    return {"type": "box", "class": cls + (" " + at(*pos) if pos else ""), "children": children or [], **kw}


def nav(i):
    p, n = PAGES[(i - 1) % 3], PAGES[(i + 1) % 3]
    def btn(side, tgt, label):
        return {"type": "button", "class": "go go-" + side, "onClick": [{"navigate": tgt}],
                "children": [text("go-k", "L" if side == "l" else "R"), text("go-t", label)]}
    return [btn("l", p[0], p[1]), btn("r", n[0], n[1])]


def msg(t): return text("msg", t)


def status():
    cells = {"type": "list", "class": "vcells " + at(10, 69, 22, 90), "items": "$hpCellsV",
             "template": box("cell", classIf={"full": "$full"})}
    def slot(n): y = 76 + (n - 1) * 20; return [text("slot-no", str(n), (48, y + 5)), text("slot-name", "{slot%d}" % n, (58, y + 2))]
    def img(cls, src, pos, **kw): return {"type": "image", "class": cls + " " + at(*pos), "src": src, **kw}
    return [
        text("plate", "ZERO", (70, 4)), text("plate lives", "x{lives}", (120, 4)),
        text("plate lvl", "LEVEL {rankName}", (70, 19)),
        text("k", "CRYSTAL", (150, 6)), text("v r", "{crystals}", (150, 6, 90)),
        text("k", "PLAY TIME", (150, 22)), text("v r", "{playTime}", (150, 22, 90)),
        text("lv", "LV", (9, 50)), text("lv-r", "{rankName}", (24, 49)),
        cells,
        text("tab-t g", "MAIN", (51, 51)),
        img("wicon", "asset:ui/icon-buster.png", (88, 49, 16, 14), classIf={"gone": "$notBuster"}),
        img("wicon", "asset:ui/icon-saber.png", (88, 49, 16, 14), classIf={"gone": "$notSaber"}),
        text("slot-name main", "{mainWeapon}", (116, 49)),
        {"type": "button", "class": "wide-btn " + at(186, 47, 58, 18), "onClick": {"call": "wideView", "args": ["toggle"]},
         "children": [text("wide-text", "WIDE {_wideLabel}")]},
        *slot(1), *slot(2), *slot(3), *slot(4),
        text("rk", "LIFE", (148, 78)), text("life-big", "{hpNow}", (148, 85)), text("life-of", "/ {hpMax}", (172, 100)),
        text("rk-l", "TIME", (148, 122)), text("rk-v r", "{runTime}", (148, 119, 92)),
        text("rk-l", "HITS", (148, 136)), text("rk-v r", "{hits}", (148, 133, 92)),
        text("rk-l", "LOW", (148, 150)), text("rk-v r", "{lowest}", (148, 147, 92)),
    ]


def elves():
    rows = []
    for n in range(1, 8):
        y = 20 + (n - 1) * 20
        rows += [text("elf-no", str(n), (16, y + 5)), text("elf-name", "{elf%d}" % n, (30, y + 3))]
    return [text("tab-t", "ELF LIST", (11, 3)), *rows,
            text("tab-t g", "{elfTitle}", (133, 3)), text("elf-desc", "{elfDesc}", (132, 20, 108))]


def option():
    def blk(x, y, title, rows):
        out = [text("tab-t", title, (x + 9, y - 8))]
        for k, (a, b) in enumerate(rows):
            out += [text("o-k", a, (x + 8, y + 8 + k * 17)), text("o-v r", b, (x + 8, y + 8 + k * 17, 104))]
        return out
    A = [("MAIN WEAPON", "B BUTTON"), ("JUMP", "A BUTTON"), ("DASH", "L BUTTON"), ("SUB WEAPON", "R BUTTON")]
    B = [("MAIN WEAPON", "B BUTTON"), ("JUMP", "A BUTTON"), ("DASH", "R BUTTON"), ("SUB WEAPON", "L BUTTON")]
    return [*blk(2, 14, "TYPE A", A), *blk(126, 14, "TYPE B", B),
            *blk(2, 106, "SHOT A", [("B BUTTON", "MAIN"), ("R+B BUTTON", "SUB")]),
            *blk(126, 106, "SHOT B", [("B BUTTON", "SUB"), ("R+B BUTTON", "MAIN")])]


def page(i):
    name = PAGES[i][0]
    body = {"status": status, "elves": elves, "option": option}[name]()
    m = {"status": "{message}", "elves": "{elfHint}", "option": "Button layout."}[name]
    return {"name": name, "child": box("page page-" + name, [*body, msg(m), *nav(i)])}


layout = box("screen-root", [
    box("waiting", [box("page page-waiting", [
        {"type": "image", "class": "logo " + at(44, 30, 160, 63), "src": "asset:ui/logo.png"},
        text("wait-big", "WAITING FOR A STAGE", (0, 110, 248)),
        text("wait-small", "Start a mission to link up.", (0, 126, 248))])],
        classIf={"gone": "$ready"}),
    box("shell", [{"type": "pages", "class": "pages", "pages": [page(i) for i in range(3)]}], classIf={"on": "$ready"}),
])
layout["id"] = "screen"
json.dump(layout, open("layout.json", "w"), indent=1, ensure_ascii=False)
open("art/pos.src.css", "w").write("/* generated by layout.py */\n" + "\n".join(POS) + "\n")
