#!/usr/bin/env python3
"""Writes layout.json. Pages: Farm (clock, gold, family), Pack, Barn (chickens / cattle / sheep / sprites tabs),
Maps (town / farm), Memo (shipped / fishing / records), bottom nav, animal + tool popups."""
import json, os
def box(cls, children=None, **kw):
    d = {"type": "box", "class": cls}; d.update(kw)
    if children is not None: d["children"] = children
    return d
def text(cls, t, **kw):
    d = {"type": "text", "class": cls, "text": t}; d.update(kw); return d
def row(cls, children, **kw):
    d = {"type": "row", "class": cls, "children": children}; d.update(kw); return d
def img(cls, src, **kw):
    d = {"type": "image", "class": cls, "src": src}; d.update(kw); return d
def bar(title, right=None):
    return box("bar", [text("bar-title", title)] + ([text("bar-right", right[0], visibleIf=right[1])] if right else []))
def btn(label, onClick, cls="btn"): return box(cls, [text("btn-t", label)], onClick=onClick)
def hearts(src="$heartRow", cls="hrow", **kw):
    d = {"type": "list", "class": cls, "items": src, "template": img("heart", "$src")}; d.update(kw); return d
def pills(key, default, items):
    return row("pills", [box("pill", [text("pill-t", label)], classIf={"on": flag}, onClick={"set": {key: val}}) for label, val, flag in items])

def animal_list(src, kind, icon):
    return {"type": "list", "class": "clist", "items": src, "template": box("win crow", [
        row("crow-top", [img("chick", "$icon"), text("cname", "{name}"), text("chealth", "{health}", classIf={"sick": "$sick"})]),
        hearts()], classIf={"sick": "$sick"}, onClick={"set": {"animal": "{idx}", "kind": kind, "note": ""}})}

def slot_grid(src):
    return {"type": "list", "class": "grid", "items": src, "template": box("slot", [
        img("slot-icon", "$icon"), text("slot-name", "{name}")],
        classIf={"empty": "$empty"}, onClick={"set": {"tool": "{name}"}})}

# ---------- Farm ----------
farm = box("page", [
    bar("{farm} Property", ("{season} {day}  {weekday}  {clock}", "$hasClock")),
    text("note", "Clock, family and weather are sample values (not live yet)", visibleIf="$isSample"),
    box("scroll", [
    row("topline", [
        box("win gold-win", [row("gold-row", [img("coin", "$coinIcon"), text("gold", "{gold}G")]),
                             text("dim", "{player}  -  {weather}", visibleIf="$hasClock")]),
        box("gold-col", [btn("+1000G", {"call": "addGold", "args": [1000]}), btn("+10000G", {"call": "addGold", "args": [10000]})])]),
    box("win", [text("sec", "Family"), {"type": "list", "class": "family", "items": "$family", "template": box("fam", [
        img("fam-icon", "$icon"),
        box("fam-main", [row("fam-top", [text("fam-name", "{name}"), text("fam-role", "{role}"),
                                          img("crown", "asset:ui/crown.png", visibleIf="$crown")]),
                         hearts(visibleIf="$hasHearts"),
                         {"type": "list", "class": "hrow", "items": "$berryRow", "visibleIf": "$hasBerries",
                          "template": img("berry", "$src")}])])}]),
    row("tiles", [
        box("win tile", [img("tile-icon", "asset:ui/barn.png"), text("tile-big", "{chickenCount} + {barnCount}"), text("tile-sm", "animals")],
            onClick={"navigate": "barn"}),
        box("win tile", [img("tile-icon", "asset:ui/crate.png"), text("tile-big", "{shipKinds}"), text("tile-sm", "kinds shipped")],
            onClick={"navigate": "memo"}),
        box("win tile alert-tile", [text("tile-big", "{sickCount}"), text("tile-sm", "sick - tap")], visibleIf="$hasSick",
            onClick={"navigate": "barn"})]),
    ]),
])

# ---------- Rucksack ----------
ruck = box("page", [
    bar("Rucksack"),
    box("scroll", [
        box("win", [text("sec", "Tools"), slot_grid("$tools")]),
        box("win", [text("sec", "Items"), slot_grid("$itemGrid"), text("dim", "Rucksack items: empty", visibleIf="$noItems")])]),
])

# ---------- Barn ----------
sprites = {"type": "list", "class": "clist", "items": "$sprites", "template": box("win crow", [
    row("crow-top", [img("chick", "$icon"), text("cname", "{name}"), text("chealth", "{state}")]),
    hearts(),
    row("bars", [text("bar-l", "{job}"),
                 {"type": "bar", "class": "meter", "value": "$b1", "max": 1},
                 {"type": "bar", "class": "meter m2", "value": "$b2", "max": 1},
                 {"type": "bar", "class": "meter m3", "value": "$b3", "max": 1}])])}
barn = box("page", [
    bar("Livestock"),
    text("note", "Sprites tab shows sample values (not live yet)", visibleIf="$tbSprites"),
    pills("barnTab", "chickens", [("Chickens", "chickens", "$tbChickens"), ("Cattle", "cattle", "$tbCattle"),
                                  ("Sheep", "sheep", "$tbSheep"), ("Sprites", "sprites", "$tbSprites")]),
    box("scroll", [
        box("tabbody", [animal_list("$chickens", "coop", "asset:ui/chicken.png")], visibleIf="$tbChickens"),
        box("tabbody", [animal_list("$cattle", "barn", "asset:ui/barn.png")], visibleIf="$tbCattle"),
        box("tabbody", [animal_list("$sheep", "barn", "asset:ui/barn.png")], visibleIf="$tbSheep"),
        box("tabbody", [sprites], visibleIf="$tbSprites")]),
])

# ---------- Maps ----------
maps = box("page", [
    bar("Maps"),
    text("note", "Marker positions are sample values (not live yet)", visibleIf="$isSample"),
    pills("mapTab", "town", [("Town", "town", "$mpTown"), ("Farm", "farm", "$mpFarm")]),
    box("tabbody", [
        box("win map-win", [box("map-view", [
            img("map-img", "asset:ui/map-world.png"),
            img("mk", "$mkDog", bindStyle={"left": "{dogX}%", "top": "{dogY}%"}),
            img("mk", "$mkHorse", bindStyle={"left": "{horseX}%", "top": "{horseY}%"}),
            img("mk mk-me", "$mkPlayer", bindStyle={"left": "{playerX}%", "top": "{playerY}%"})])]),
        box("win", [row("where", [img("chick", "asset:ui/pawn.png"), text("val", "{where}")])]),
        row("legend", [row("leg", [img("leg-i", "$mkPlayer"), text("leg-t", "You")]),
                       row("leg", [img("leg-i", "$mkDog"), text("leg-t", "Spunky")]),
                       row("leg", [img("leg-i", "$mkHorse"), text("leg-t", "Speedy")])])], visibleIf="$mpTown"),
    box("tabbody", [box("scroll", [box("win map-win", [box("farm-view", [
        img("farm-img", "asset:ui/map-farm.png"),
        img("mk mk-me", "$mkPlayer", bindStyle={"left": "{farmX}%", "top": "{farmY}%"})])])])], visibleIf="$mpFarm"),
])

# ---------- Memo ----------
def kv_row(): return box("win srow", [box("sname-col", [text("sname", "{name}")]), text("scount", "{value}")])
memo = box("page", [
    bar("Memo"),
    text("note", "Fishing and records are sample values (not live yet)", visibleIf="$tmOther"),
    pills("memoTab", "ship", [("Shipped", "ship", "$tmShip"), ("Fishing", "fish", "$tmFish"), ("Records", "rec", "$tmRec")]),
    text("dim pad", "Nothing shipped yet", visibleIf="$noShipped"),
    box("scroll", [
        box("tabbody", [{"type": "list", "class": "slist", "items": "$shipped", "template": box("win srow", [
            img("chick", "$icon"), box("sname-col", [text("sname", "{name}"), text("sgroup", "{group}")]), text("scount", "{count}")])}], visibleIf="$tmShip"),
        box("tabbody", [{"type": "list", "class": "slist", "items": "$fishing", "template": box("win srow", [
            img("chick", "asset:ui/fish.png"), box("sname-col", [text("sname", "{name}"), text("sgroup", "Largest {size}")]),
            text("scount", "{count}")])}], visibleIf="$tmFish"),
        box("tabbody", [
            box("win", [text("sec", "Mini-game records"), {"type": "list", "class": "slist", "items": "$records", "template": kv_row()}]),
            box("win", [text("sec", "Income / expenses"), {"type": "list", "class": "slist", "items": "$income", "template": kv_row()}])],
            visibleIf="$tmRec")]),
])

def navbtn(label, page, key, icon):
    return {"type": "button", "class": "nav-btn", "classIf": {"on": key}, "onClick": [{"navigate": page}],
            "children": [img("nav-i", icon), text("nav-text", label)]}

animal_sheet = box("sheet", [box("win pop", [
    text("pop-name", "{dName}"), text("val", "{dHealth}  -  {dHearts} hearts"),
    hearts("$dRow", "hrow big"),
    row("pop-btns", [btn("CURE", {"call": "heal", "args": ["{ui.kind}", "{ui.animal}"]}),
                     btn("MAX HEARTS", {"call": "maxHearts", "args": ["{ui.kind}", "{ui.animal}"]}),
                     btn("CLOSE", {"set": {"animal": False}})]),
    text("dim", "{ui.note}", visibleIf="$ui.note")])], visibleIf="$dName")
tool_sheet = box("sheet", [box("win pop", [text("pop-name", "{ui.tool}"), row("pop-btns", [btn("CLOSE", {"set": {"tool": False}})])])],
                 visibleIf="$ui.tool")

root = box("screen", [
    box("win waiting", [text("w-title", "Harvest Moon"), text("w-sub", "Friends of Mineral Town"), text("w-hint", "Load your farm to begin")],
        visibleIf="$waiting"),
    box("main", [
        {"type": "pages", "class": "stage", "state": "page", "initial": "farm", "pages": [
            {"name": "farm", "child": farm}, {"name": "ruck", "child": ruck}, {"name": "barn", "child": barn},
            {"name": "maps", "child": maps}, {"name": "memo", "child": memo}]},
        animal_sheet, tool_sheet,
        row("nav", [navbtn("Farm", "farm", "$navFarm", "asset:ui/coin.png"), navbtn("Pack", "ruck", "$navRuck", "asset:ui/tool.png"),
                    navbtn("Barn", "barn", "$navBarn", "asset:ui/chicken.png"), navbtn("Maps", "maps", "$navMaps", "asset:ui/pawn.png"),
                    navbtn("Memo", "memo", "$navMemo", "asset:ui/crate.png")])], visibleIf="$ready"),
])
def clean(o):
    if isinstance(o, dict): return {k: clean(v) for k, v in o.items() if v is not None and k != "class_extra"}
    if isinstance(o, list): return [clean(x) for x in o]
    return o
here = os.path.dirname(os.path.abspath(__file__))
json.dump(clean(root), open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
print("layout.json written")
