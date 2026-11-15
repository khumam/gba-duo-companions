#!/usr/bin/env python3
"""Builds layout.json for the Monomyth pack from the Emerald pack's own layout (art/layout.emerald.json, a verbatim copy of
pokemon-emerald-companion/layout.json), changing only what Monomyth's data differs on. Run from the pack folder:
  python3 -I art/build.py
Patches: boot text; 7 bag pockets instead of 5; the WIDE VIEW setting button removed (the pack has no game script)."""
import copy, json

def box(cls, kids=None, **kw):
    d = {"type": "box", "class": cls, "children": kids or []}; d.update(kw); return d
def text(cls, t, **kw):
    d = {"type": "text", "class": cls, "text": t}; d.update(kw); return d

lay = json.load(open("art/layout.emerald.json"))

def walk(n, fn):
    if isinstance(n, dict):
        fn(n)
        for v in n.values(): walk(v, fn)
    elif isinstance(n, list):
        for v in n: walk(v, fn)

# boot screen
def boot(n):
    if n.get("class") == "boot-sub": n["text"] = "MONOMYTH VERSION"
walk(lay, boot)

shell = [c for c in lay["children"] if c.get("class") == "shell"][0]
pages = {p["name"]: p["child"] for p in [c for c in shell["children"] if c.get("type") == "pages"][0]["pages"]}

# bag: seven pockets in the game's order
POCKETS = [("ITEM", "items"), ("MED", "medicine"), ("BALL", "balls"), ("TM", "tmHm"), ("BTL", "battle"), ("BRY", "berries"), ("KEY", "keyItems")]
def bag_tabs(n):
    if n.get("type") == "tabs" and n.get("class") == "pockets":
        tpl = n["tabs"][0]["child"]
        tabs = []
        for title, key in POCKETS:
            t = copy.deepcopy(tpl); t["items"] = "$bag." + key
            tabs.append({"title": title, "child": t})
        n["tabs"] = tabs
walk(pages["bag"], bag_tabs)

# options: drop the WIDE VIEW button (the pack has no game script); only that button, not its containers
def is_wide(n):
    return isinstance(n, dict) and n.get("type") == "button" and "wideView" in json.dumps(n.get("onClick"))
def nowide(n):
    if isinstance(n.get("children"), list):
        n["children"] = [c for c in n["children"] if not is_wide(c)]
walk(pages["options"], nowide)

json.dump(lay, open("layout.json", "w"), indent=2); open("layout.json", "a").write("\n")
print("ok")
