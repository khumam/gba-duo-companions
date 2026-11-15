#!/usr/bin/env python3
"""Writes layout.json: every page of the FFVI pause menu (Party, Items, Abilities, Equip, Relics, Status, Formation, Config)
for the second screen, joined by left / right buttons that cycle through them. Edit here, not by hand:
    python3 art/layout.py"""
import json, os

def box(cls, ch=(), **kw):   return {"type": "box", "class": cls, "children": list(ch), **kw}
def text(cls, t, **kw):      return {"type": "text", "class": cls, "text": t, **kw}
def img(cls, src, **kw):     return {"type": "image", "class": cls, "src": src, **kw}
def button(cls, on, ch, **kw): return {"type": "button", "class": cls, "onClick": on, "children": list(ch), **kw}
def lst(cls, items, tpl, **kw): return {"type": "list", "class": cls, "items": items, "template": tpl, **kw}
win = lambda w, h, cls: img(f"win {cls}", f"asset:ui/win-{w}x{h}.png")

# the loop the left / right buttons cycle through; Status is not in it (it opens from Party only)
PAGES = [("party", "Party"), ("items", "Items"), ("abilities", "Abilities"), ("skills", "Skills"), ("equip", "Equip"),
         ("relics", "Relics"), ("formation", "Formation"), ("config", "Config")]
def nav(i, title=None, prev=None, nxt=None):
    prev = prev or PAGES[(i - 1) % len(PAGES)]
    nxt = nxt or PAGES[(i + 1) % len(PAGES)]
    return [win(76, 26, "w-nl"), win(80, 26, "w-nt"), win(76, 26, "w-nr"),
            button("nbtn nbtn-l", [{"navigate": prev[0]}], [text("nb nb-l", "< " + prev[1])]),
            text("ntitle", title or PAGES[i][1]),
            button("nbtn nbtn-r", [{"navigate": nxt[0]}], [text("nb nb-r", nxt[1] + " >")])]

# the party tabs on the character pages (tap a name to look at that character)
def tabs():
    return [win(240, 20, "w-head"),
            lst("tabs", "$tabs", button("tab", [{"set": {"who": "{actor}"}}], [text("tab-t", "{name}")], classIf={"sel": "$sel"}))]

def head(title):
    return [win(240, 20, "w-head"), text("head-title", title)]

# ---- party ----------------------------------------------------------------------------------
def member_row(on):
    return button("mem", on, [
        img("mface", "$face"), text("mname", "{name}"), text("mclass", "{class}"),
        text("lab mlv-l", "LV"), text("num mlv", "{level}"),
        text("lab mhp-l", "HP"), text("num mhp", "{hp}/{maxHp}"),
        text("lab mmp-l", "MP"), text("num mmp", "{mp}/{maxMp}")], classIf={"marked": "$marked"})

party = box("page page-party", [
    win(240, 156, "w-party"),
    lst("members", "$party", member_row([{"set": {"who": "{actor}"}}, {"navigate": "status"}])),
    win(240, 22, "w-info"),
    text("lab i-time-l", "Time"), text("num i-time", "{time}"),
    text("lab i-steps-l", "Steps"), text("num i-steps", "{steps}"),
    text("lab i-gil-l", "Gil"), text("num i-gil", "{gil}"),
    *nav(0)])

# ---- items ----------------------------------------------------------------------------------
items = box("page page-items", [
    *head("Items"), win(240, 134, "w-list"),
    lst("itemlist", "$items", button("icell", [{"set": {"item": "{slot}", "popup": True}}], [
        text("iname", "{name}"), text("iqty", ": {qty}")], classIf={"sel": "$sel"})),
    text("empty", "No items", visibleIf="$noItems"),
    win(240, 22, "w-info"),
    text("sel-name", "{selItem.name}"), text("lab sel-qty", "x {selItem.qty}", visibleIf="$items"),
    *nav(1),
    box("poplayer", [
        button("dim", [{"set": {"popup": False}}], []),
        win(200, 86, "w-pop"),
        text("pop-q", "{detail.prompt}"), text("lab pop-sub", "{detail.sub}"),
        lst("targets", "$tabs", button("tgt", [{"call": "useItem", "args": ["{detail.slot}", "{actor}"], "set": {"popup": False}}],
                                       [text("tgt-t", "{name}")]), visibleIf="$detail.single"),
        button("pbtn pbtn-yes", [{"call": "useItem", "args": ["{detail.slot}", -1], "set": {"popup": False}}], [text("pbtn-t", "Yes")], visibleIf="$detail.party"),
        button("pbtn pbtn-no", [{"set": {"popup": False}}], [text("pbtn-t", "No")], visibleIf="$detail.party"),
        button("pbtn pbtn-cancel", [{"set": {"popup": False}}], [text("pbtn-t", "Cancel")], visibleIf="$detail.single"),
        button("pbtn pbtn-ok", [{"set": {"popup": False}}], [text("pbtn-t", "OK")], visibleIf="$detail.none"),
    ], visibleIf="$ui.popup")])

# ---- abilities ------------------------------------------------------------------------------
abilities = box("page page-abilities", [
    *tabs(), win(240, 68, "w-esper"),
    text("lab esper-l", "Esper"), text("esper-n", "{sel.esper}"),
    lst("espers", "$espers", text("cell", "{name}", classIf={"mine": "$mine", "taken": "$taken"})),
    win(240, 88, "w-magic"),
    text("lab magic-l", "Magic"), text("magic-n", "{sel.spellCount} learned"),
    lst("spells", "$spells", text("cell", "{name}")),
    *nav(2)])

# ---- skills: Bushido, Blitz, Lore, Rage and Dance ------------------------------------------------
skills = box("page page-skills", [
    *tabs(), win(240, 22, "w-kind"),
    lst("kinds", "$kinds", button("kind", [{"set": {"sk": "{k}"}}], [text("kind-t", "{name}")], classIf={"sel": "$on", "off": "$off"})),
    win(240, 134, "w-slist"),
    lst("sklist", "$techs", text("scell", "{name}")),
    text("sk-empty", "Nothing learned yet", visibleIf="$noTechs"),
    *nav(3)])

# ---- equip / relics / status (shared stat window) --------------------------------------------
def stats(vis=None):
    v = {"visibleIf": vis} if vis else {}
    items = [win(240, 86, "w-stats"),
        text("lab st-ex-l", "EXP"), text("num st-ex", "{sel.exp}"),
        text("lab st-lv-l", "LV"), text("num st-lv", "{sel.level}"),
        text("lab st-hp-l", "HP"), text("num st-hp", "{sel.hp}/{sel.maxHp}"),
        text("lab st-mp-l", "MP"), text("num st-mp", "{sel.mp}/{sel.maxMp}"),
        text("lab st-str-l", "Strength"), text("num st-str", "{sel.vigor}"),
        text("lab st-spd-l", "Speed"), text("num st-spd", "{sel.speed}"),
        text("lab st-sta-l", "Stamina"), text("num st-sta", "{sel.stamina}"),
        text("lab st-mag-l", "Magic"), text("num st-mag", "{sel.magic}"),
        text("lab st-cmd-l", "Commands"), text("cmds", "{sel.commands}")]
    if not vis: return items
    # the window itself stays; the rows on top are shown or hidden
    return items[:1] + [dict(x, **v) for x in items[1:]]

def stats_combat():
    # the second view of the Status page: what the gear and the character add up to in a fight
    v = {"visibleIf": "$combat"}
    return [text("lab sc-a-l", "Attack", **v), text("num sc-a", "{sel.attackText}", **v),
            text("lab sc-d-l", "Defense", **v), text("num sc-d", "{sel.defense}", **v),
            text("lab sc-e-l", "Evasion", **v), text("num sc-e", "{sel.evasion}%", **v),
            text("lab sc-md-l", "Mag Defense", **v), text("num sc-md", "{sel.mdefense}", **v),
            text("lab sc-me-l", "Mag Evasion", **v), text("num sc-me", "{sel.mevasion}%", **v),
            text("lab sc-n-l", "Next LV", **v), text("num sc-n", "{sel.expNext}", **v)]

equip = box("page page-equip", [
    *tabs(), win(240, 70, "w-top"),
    lst("slots", "$equip", box("slot", [text("lab slot-l", "{label}"), text("slot-n", "{item}")])),
    img("eface", "$face"), *stats(), *nav(4)])

relics = box("page page-relics", [
    *tabs(), win(240, 70, "w-top"),
    lst("slots", "$relics", box("slot", [text("lab slot-l", "{label}"), text("slot-n", "{item}")])),
    img("eface", "$face"), *stats(), *nav(5)])

status = box("page page-status", [
    *tabs(), win(240, 70, "w-top"),
    img("sface", "$face"), text("sname", "{sel.name}"), text("sclass", "{sel.class}"),
    text("lab sa-l", "Esper"), text("sa-n", "{sel.esper}"),
    text("lab sb-l", "Spells"), text("sb-n", "{sel.spellCount} learned"),
    *stats("$notCombat"), *stats_combat(),
    button("combat-btn", [{"set": {"sp": 1}}], [text("combat-t", "Combat >")], visibleIf="$notCombat"),
    button("combat-btn", [{"set": {"sp": 0}}], [text("combat-t", "< Stats")], visibleIf="$combat"),
    *nav(0, title="Status", prev=("party", "Party"), nxt=("equip", "Equip"))])

# ---- formation ------------------------------------------------------------------------------
formation = box("page page-formation", [
    win(240, 20, "w-head"), text("lab form-hint", "{formationHint}"),
    win(240, 158, "w-form"),
    lst("fmembers", "$party", member_row([{"call": "pick", "args": ["{actor}"]}])),
    *nav(6)])

# ---- config ---------------------------------------------------------------------------------
config = box("page page-config", [
    *head("Config"), win(240, 158, "w-conf"),
    lst("crows", "$config", box("crow", [
        text("lab clab", "{label}"),
        lst("copts", "$opts", button("copt", [{"call": "setConfig", "args": ["{row}", "{val}"]}], [text("copt-t", "{text}")],
                                       classIf={"sel": "$sel"}), classIf={})], classIf={"six": "$six"})),
    *nav(7)])

waiting = box("page page-waiting", [
    win(240, 208, "w-wait"),
    text("wt-1", "FINAL FANTASY VI"), text("wt-2", "ADVANCE"), text("wt-3", "Load a game to see your party")])
body = [("party", party), ("items", items), ("abilities", abilities), ("skills", skills), ("equip", equip),
        ("relics", relics), ("status", status), ("formation", formation), ("config", config)]
root = box("main", [
    box("waiting", [waiting], visibleIf="$waiting"),
    box("ready", [{"type": "pages", "class": "stage", "initial": "party",
                   "pages": [{"name": n, "child": c} for n, c in body]}], visibleIf="$ready")], id="screen")
here = os.path.dirname(os.path.abspath(__file__))
json.dump(root, open(os.path.join(here, "..", "layout.json"), "w"), indent=1)
print("ok", len(json.dumps(root)))
