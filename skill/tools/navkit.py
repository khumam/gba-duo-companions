#!/usr/bin/env python3
"""Adds a movable navigation to a pack and an Options page to choose where it sits.

Positions: bottom (a bar, wraps to a second row), left or right (a dock that scrolls), split (half the buttons on each side).
The buttons are static (a `navigate` action can't take a placeholder), shown or hidden by flags that main.lua sets from the UI key `navpos`.

  python3 -I skill/tools/navkit.py PACK_DIR --items "CLAN:clan,UNIT:unit,TOP:top" --alias unit=clan --theme ffta|aw

--alias maps a page that has no tab of its own to the tab to light up. The pack keeps its own `.nbtn` styles; this adds `.dock`, `.dbtn`,
`.opt*`. Run once per pack (it rewrites layout.json's #ready and appends Lua and CSS), then re-render the previews.
"""
import argparse, json, re, sys, os

THEMES = {
  "ffta": dict(btn="var(--olive)", edge="var(--olive-d)", on="var(--olive-l)", onedge="var(--yellow)", txt="var(--cream)", shadow="var(--olive-d)", onTxt="var(--olive-d)",
               panel="var(--navy)", panelEdge="#9cb6ff", ink="var(--cream)", sub="var(--cyan)", cardOn="var(--navy-l)", cardOnEdge="var(--yellow)", bar="var(--olive)", bg="var(--teal-d)"),
  "aw":   dict(btn="var(--red)", edge="var(--ink)", on="var(--paper)", onedge="var(--lime)", txt="#ffffff", shadow="var(--dark-red)", onTxt="var(--dark-red)",
               panel="var(--paper)", panelEdge="var(--ink)", ink="var(--ink)", sub="var(--dark-red)", cardOn="#fff4d6", cardOnEdge="var(--lime)", bar="var(--red)", bg="var(--sea)"),
}

def box(cls, children=None, **kw):
    d = {"type": "box", "class": cls, "children": children or []}; d.update(kw); return d
def text(cls, t, **kw):
    d = {"type": "text", "class": cls, "text": t}; d.update(kw); return d
def btn(cls, children, on, **kw):
    d = {"type": "button", "class": cls, "onClick": on, "children": children}; d.update(kw); return d

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pack"); ap.add_argument("--items", required=True); ap.add_argument("--alias", action="append", default=[]); ap.add_argument("--theme", required=True)
    a = ap.parse_args()
    th = THEMES[a.theme]
    items = [tuple(x.split(":")) for x in a.items.split(",")] + [("OPT", "options")]
    alias = dict(x.split("=") for x in a.alias)
    n = len(items)
    lay_path = os.path.join(a.pack, "layout.json")
    lay = json.load(open(lay_path))
    ready = [c for c in lay["children"] if c.get("visibleIf") == "$ready"][0]
    def find_pages(n):
        if isinstance(n, dict):
            if n.get("type") == "pages": return n
            for c in n.get("children", []):
                r = find_pages(c)
                if r: return r
        return None
    stage = find_pages(ready)
    if not any(p["name"] == "options" for p in stage["pages"]):
        def card(pos, label, diagram):
            return btn("ocard", [box("odiag " + diagram, [box("obar b1"), box("obar b2"), box("opage")]), text("olab", label)],
                       [{"set": {"navpos": pos}}], classIf={"on": "$pos" + pos.capitalize()})
        opts = box("page", [
            box("band", [text("ttl", "OPTIONS"), text("sum" if a.theme == "ffta" else "count", "where the page buttons sit")]),
            box("opanel", [
                text("oh", "Navigation buttons"),
                box("ocards", [card("bottom", "Bottom", "d-bottom"), card("left", "Left", "d-left"), card("right", "Right", "d-right"), card("split", "Split", "d-split")]),
                text("onote", "Side docks scroll when there are many pages. The bottom bar shows 5 buttons: use < > for the rest."),
                text("onote", "Kept until the game is closed."),
            ]),
        ])
        stage["pages"].append({"name": "options", "child": opts})
    first = stage["pages"][0]["name"]
    def navbtn(label, page, i, cls, flag=None):
        d = btn(cls, [text("nt" if cls == "nbtn" else "dt", label)], [{"navigate": page}], classIf={"on": "$on%d" % i})
        if flag: d["visibleIf"] = flag
        return d
    arrows = lambda sym, d, flag: btn("narrow", [text("nt", sym)], [{"call": "navShift", "args": [d]}], visibleIf="$navMore", classIf={"off": flag})
    bottom = box("nav", [arrows("<", -1, "$noPrev")] + [navbtn(l, p, i, "nbtn", "$B%d" % i) for i, (l, p) in enumerate(items, 1)] + [arrows(">", 1, "$noNext")], visibleIf="$posBottom")
    dockL = box("dock", [navbtn(l, p, i, "dbtn", "$L%d" % i) for i, (l, p) in enumerate(items, 1)], visibleIf="$dockL")
    dockR = box("dock", [navbtn(l, p, i, "dbtn", "$R%d" % i) for i, (l, p) in enumerate(items, 1)], visibleIf="$dockR")
    center = box("center", [stage, bottom])
    ready["children"] = [dockL, center, dockR]
    ready["class"] = "ready"
    json.dump(lay, open(lay_path, "w"), indent=1)

    # Lua: wrap update() so the nav flags ride along
    lp = os.path.join(a.pack, "main.lua")
    src = open(lp).read()
    if "navState" in src:       # re-applying: drop the old block and the update wrapper, then write them again
        src = src[:src.index("\n-- the movable navigation")]
        src = src.replace("local function baseUpdate(ui)", "function update(ui)", 1) if False else src
    if "baseUpdate" not in src:
        src = src.replace("function update(ui)", "local function baseUpdate(ui)", 1)
    if True:
        navs = ", ".join('{ "%s", "%s" }' % it for it in items)
        al = ", ".join('%s = "%s"' % kv for kv in alias.items())
        lua = f'''
-- the movable navigation: where the buttons sit is the UI key navpos (bottom, left, right, split), chosen on the Options page
local NAV = {{ {navs} }}
local NAV_ALIAS = {{ {al} }}
local NAV_WINDOW = 5          -- the bottom bar shows this many buttons; < > page through the rest. The side docks scroll.
local navOffset = 0
local navLastPage
actions = actions or {{}}
function actions.navShift(d) navOffset = navOffset + (tonumber(d) or 0) end
local function navState(ui)
  local pos = ui.navpos or "bottom"
  local cur = ui.page or "{first}"
  cur = NAV_ALIAS[cur] or cur
  local out = {{ posBottom = (pos == "bottom"), posLeft = (pos == "left"), posRight = (pos == "right"), posSplit = (pos == "split") }}
  local curIdx = 1
  for i, n in ipairs(NAV) do if n[2] == cur then curIdx = i end end
  local maxOff = math.max(0, #NAV - NAV_WINDOW)
  if tostring(ui.page) ~= tostring(navLastPage) then          -- a new page: bring its button into view
    if curIdx <= navOffset then navOffset = curIdx - 1 elseif curIdx > navOffset + NAV_WINDOW then navOffset = curIdx - NAV_WINDOW end
    navLastPage = ui.page
  end
  navOffset = math.max(0, math.min(maxOff, navOffset))
  out.navMore, out.noPrev, out.noNext = #NAV > NAV_WINDOW, navOffset <= 0, navOffset >= maxOff
  local half = (#NAV + 1) // 2
  local left, right = 0, 0
  for i, n in ipairs(NAV) do
    out["on" .. i] = (n[2] == cur)
    out["B" .. i] = (i > navOffset and i <= navOffset + NAV_WINDOW)
    local l = (pos == "left") or (pos == "split" and i <= half)
    local r = (pos == "right") or (pos == "split" and i > half)
    out["L" .. i], out["R" .. i] = l, r
    if l then left = left + 1 end
    if r then right = right + 1 end
  end
  out.dockL, out.dockR = left > 0, right > 0
  return out
end
'''
        src += lua + '''
local lastGood
function update(ui)
  local ok, r = pcall(baseUpdate, ui)
  if ok then lastGood = r else
    if log then log("update error: " .. tostring(r)) end       -- keep showing the last good screen instead of going blank
    r = lastGood
  end
  if r and r.ready then for k, v in pairs(navState(ui)) do r[k] = v end end
  return r
end
'''
        open(lp, "w").write(src)

    css = f'''
/* movable navigation: bottom bar (wraps), side docks (scroll), options page */
.ready {{ flex-direction: row; width: 100%; height: 100%; }}
.center {{ flex: 1; min-width: 0; height: 100%; }}
.nav {{ flex-direction: row; flex-wrap: wrap; height: auto; max-height: 76px; gap: 5px; padding: 0 8.672px 6px; }}
.nav .nbtn {{ flex: 1; min-width: 64px; }}
.dock {{ width: 92px; height: 100%; padding: 8.672px 5px 8.672px 8.672px; gap: 6px; overflow: auto; background-color: {th['bg']}; flex-shrink: 0; }}
.dbtn {{ width: 100%; height: 44px; flex-shrink: 0; padding: 0; margin: 0; justify-content: center; align-items: center; background-color: {th['btn']}; border: 2.168px solid {th['edge']}; border-radius: 6px; }}
.dbtn:pressed {{ background-color: {th['on']}; }}
.dbtn.on {{ background-color: {th['on']}; border-color: {th['onedge']}; }}
.dt {{ font-size: 19px; color: {th['txt']}; text-shadow: 2.168px 2.168px 0 {th['shadow']}; }}
.dbtn.on .dt {{ color: {th['onTxt']}; text-shadow: none; }}
.opanel {{ flex: 1; padding: 12px 14px; gap: 10px; background-color: {th['panel']}; border: 4.336px solid {th['panelEdge']}; border-radius: 8.672px; }}
.oh {{ font-size: 26px; color: {th['ink']}; }}
.ocards {{ display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; }}
.ocard {{ flex-direction: row; gap: 12px; height: 70px; padding: 8px 10px; margin: 0; justify-content: flex-start; align-items: center; background-color: transparent; border: 4.336px solid {th['panelEdge']}; border-radius: 8.672px; }}
.ocard.on {{ background-color: {th['cardOn']}; border-color: {th['cardOnEdge']}; }}
.ocard:pressed {{ opacity: 0.8; }}
.olab {{ font-size: 24px; color: {th['ink']}; }}
.onote {{ font-size: 17px; color: {th['sub']}; white-space: normal; }}
.odiag {{ width: 50px; height: 50px; position: relative; background-color: #00000040; border: 2.168px solid {th['panelEdge']}; border-radius: 4px; }}
.opage {{ position: absolute; left: 6px; right: 6px; top: 6px; bottom: 6px; background-color: #ffffff30; border-radius: 2px; }}
.obar {{ position: absolute; background-color: {th['bar']}; border-radius: 2px; }}
.d-bottom .b1 {{ left: 4px; right: 4px; bottom: 3px; height: 8px; }}
.d-bottom .b2 {{ width: 0; height: 0; }}
.d-bottom .opage {{ bottom: 14px; }}
.d-left .b1 {{ left: 3px; top: 4px; bottom: 4px; width: 9px; }}
.d-left .b2 {{ width: 0; height: 0; }}
.d-left .opage {{ left: 16px; }}
.d-right .b1 {{ right: 3px; top: 4px; bottom: 4px; width: 9px; }}
.d-right .b2 {{ width: 0; height: 0; }}
.d-right .opage {{ right: 16px; }}
.d-split .b1 {{ left: 3px; top: 4px; bottom: 4px; width: 9px; }}
.d-split .b2 {{ right: 3px; top: 4px; bottom: 4px; width: 9px; }}
.d-split .opage {{ left: 16px; right: 16px; }}
'''
    cp = os.path.join(a.pack, "style.css")
    old = open(cp).read()
    if "movable navigation" in old:
        i = old.index("\n/* movable navigation")
        j = old.index(".d-split .opage", i)
        j = old.index("}\n", j) + 2
        old = old[:i] + old[j:]
    open(cp, "w").write(old + css)
    print("ok", n, "buttons")

main()
