# Sample values that mirror what main.lua returns, for the Mac preview. Run: python3 art/preview-data.py
import json, os
T = lambda n: {"name": n.upper(), "src": f"asset:types/{n}.png"}
def bands(hp, mx):
    p = hp / mx
    return dict(hpPct=round(p, 3), hpHigh=p > .5, hpMid=.2 < p <= .5, hpLow=p <= .2, fainted=hp == 0)
def mv(name, ty, power, acc, pp, mx, desc, contest, ccol, cdesc):
    p = pp / mx
    return dict(name=name, type=f"asset:types/{ty}.png", power=power, acc=acc, pp=f"{pp}/{mx}", ppPct=round(p, 3), ppLow=p <= .25,
                has=True, desc=desc, contest=contest, contestColor=ccol, cdesc=cdesc, info=f"PWR {power}  ACC {acc}")
EMPTY = dict(name="-", type="", power="--", acc="--", pp="--", ppPct=0, ppLow=False, has=False, desc="", contest="", contestColor="#ffffff", cdesc="", info="")
def stats(vals, evs, up=None, down=None):
    names = ["HP", "ATTACK", "DEFENSE", "SP. ATK", "SP. DEF", "SPEED"]
    return [dict(label=n, value=str(v), pct=round(min(1, v / 120), 3), up=n == up, down=n == down, ev=f"EV {e}") for n, v, e in zip(names, vals, evs)]
def cond(c, b, cu, s, t):
    cols = ["#d85040", "#5088c0", "#d85868", "#58a868", "#e8a050"]
    return [dict(label=l, pct=round(v / 255, 3), value=str(v), color=c) for l, v, c in zip(["COOL", "BEAUTY", "CUTE", "SMART", "TOUGH"], [c, b, cu, s, t], cols)]
def mon(dex, name, lv, hp, mx, types, lead=False, male=True, ability="TORRENT", at="Ups WATER moves in a pinch.", item="NONE", held="", status="", nature="NAUGHTY", moves=None, sv=(20, 13, 11, 10, 9, 9)):
    d = dict(name=name, level=lv, dex="%03d" % dex, sprite=f"asset:pokemon/{dex}.png", types=[T(t) for t in types], hp=hp, maxHp=mx, lead=lead,
             male=male, female=not male, ot="Kira", id="22447", ability=ability, abilityText=at, nature=nature, metLevel=lv, metPlace="ROUTE 101",
             item=item, hasHeld=bool(held), heldIcon=held, hasStatus=bool(status), status=status, expPct=0.42, toNext="27", exp="152", friendship="70",
             ribbon="NONE", friendPct=round(70/255,3), statRows=stats((mx,) + sv[1:], (0, 1, 0, 0, 0, 0), up="ATTACK", down="SP. ATK"),
             condition=cond(40, 25, 60, 10, 35), sheen="0", sheenPct=0, **bands(hp, mx))
    d["moves"] = (moves or []) + [EMPTY] * (4 - len(moves or []))
    d["moveDesc"] = d["moves"][0]["desc"]; d["contestDesc"] = d["moves"][0]["cdesc"]
    return d
MOVES = [mv("TACKLE", "normal", 35, 95, 35, 35, "Charges the foe with a full-body tackle.", "TOUGH", "#e8a050", "A highly appealing move."),
         mv("GROWL", "normal", "--", 100, 40, 40, "Growls cutely to reduce the foe's ATTACK.", "CUTE", "#d85868", "Excites the audience."),
         mv("MUD-SLAP", "ground", 20, 100, 8, 10, "Hurls mud in the foe's face to lower its accuracy.", "SMART", "#58a868", "Startles the others."),
         mv("WATER GUN", "water", 40, 100, 25, 25, "Squirts water to attack the foe.", "BEAUTY", "#5088c0", "Appeals with water.")]
party = [
    mon(258, "MUDKIP", 12, 31, 36, ["water"], True, moves=MOVES, item="ORAN BERRY", held="asset:items/139.png", sv=(36, 22, 18, 16, 16, 15)),
    mon(263, "ZIGZAGOON", 9, 12, 29, ["normal"], male=False, ability="PICKUP", at="May pick up items.", moves=MOVES[:2], nature="JOLLY", sv=(29, 14, 12, 8, 9, 15)),
    mon(261, "POOCHYENA", 8, 4, 27, ["dark"], ability="RUN AWAY", at="Makes escaping easier.", status="PSN", moves=MOVES[:3], sv=(27, 15, 9, 8, 9, 11)),
    mon(265, "WURMPLE", 5, 0, 20, ["bug"], male=False, ability="SHIELD DUST", at="Prevents added effects.", moves=MOVES[:1], sv=(20, 9, 8, 6, 6, 6)),
    mon(276, "TAILLOW", 10, 33, 33, ["normal", "flying"], ability="GUTS", at="Boosts ATTACK if suffering.", item="POTION", held="asset:items/13.png", moves=MOVES, sv=(33, 18, 12, 12, 11, 22)),
    mon(280, "RALTS", 7, 17, 21, ["psychic"], male=False, ability="SYNCHRONIZE", at="Passes on status problems.", moves=MOVES[:2], sv=(21, 8, 8, 14, 12, 10)),
]
tot = sum(p["hp"] for p in party); mx = sum(p["maxHp"] for p in party)
it = lambda n, c, ic, desc, price: dict(name=n, count=c, icon=f"asset:items/{ic}.png", hasIcon=True, desc=desc, price=price)
bag = dict(
    items=[it("POTION", "x5", 13, "Restores the HP of one POKéMON by 20 points.", "300"), it("ANTIDOTE", "x2", 14, "Heals one POKéMON of its poisoning.", "100"),
           it("REPEL", "x3", 86, "Repels weak wild POKéMON for 100 steps.", "350"), it("ESCAPE ROPE", "x1", 85, "Use to escape instantly from a cave or dungeon.", "550"),
           it("SUPER POTION", "x4", 22, "Restores the HP of one POKéMON by 50 points.", "700"), it("AWAKENING", "x1", 17, "Wakes up one sleeping POKéMON.", "250")],
    balls=[it("POKé BALL", "x12", 4, "A tool used for catching wild POKéMON.", "200"), it("GREAT BALL", "x3", 3, "A good, high-performance BALL.", "600")],
    tmHm=[it("TM01 FOCUS PUNCH", "x1", 0, "Powerful, but may flinch.", "3000"), it("HM01 CUT", "x1", 0, "Cuts down thin trees.", "0")],
    berries=[it("ORAN BERRY", "x6", 139, "Restores 10 HP when held.", "20"), it("CHERI BERRY", "x2", 133, "Heals paralysis when held.", "20")],
    keyItems=[dict(it("BIKE", "", 0, "A folding bike that lets you travel faster.", "0"), hasIcon=False)], total="24", used="12", capacity="186", hasAny=True, isEmpty=False)
for k in ("tmHm",): 
    for x in bag[k]: x["icon"] = "asset:items/tm.png"
youmon = dict(party[0]); youmon["sprite"] = "asset:pokemon/back/258.png"
foe = mon(261, "POOCHYENA", 3, 12, 15, ["dark"], status="", moves=[])
foe["sprite"] = "asset:pokemon/261.png"
st = lambda a: [dict(name=n, stage=s, up=s.startswith("+"), down=s.startswith("-")) for n, s in a]
youmon["stats"] = st([("ATTACK", "+1")]); foe["stats"] = st([("DEFENSE", "-1"), ("SPEED", "-2")])
bm = []
for m, eff, cls in zip(MOVES, ["x1", "--", "x1/2", "x2"], ["", "", "nve", "se"]):
    q = dict(m); q.update(pp=m["pp"].split("/")[0], sel=m["name"]=="WATER GUN", eff=eff, se=cls == "se", nve=cls == "nve", imm=False, info=m["info"]); bm.append(q)
ents = [dict(num=n, no="%03d" % n, name=nm, sprite=f"asset:pokemon/{n}.png", seen=True, unseen=False, own=n in (258, 261, 263), sel=n == 258) for n, nm in [(252, "TREECKO"), (253, "GROVYLE"), (254, "SCEPTILE"), (255, "TORCHIC"), (256, "COMBUSKEN"), (257, "BLAZIKEN"), (258, "MUDKIP"), (259, "MARSHTOMP"), (260, "SWAMPERT"), (261, "POOCHYENA")]]
ents += [dict(num=n, no="%03d" % n, name="-----", sprite="", seen=False, unseen=True, own=False, sel=False) for n in range(262, 276)]
dexd = dict(entries=ents, range="252-275", page="11/17", searching=False, notSearching=True, noMatch=False, found="0 MATCHES", sel=dict(no="258", seen=True, unseen=False, own=True, name="MUDKIP", sprite="asset:pokemon/258.png", state="OWNED",
            category="MUD FISH POKéMON", height="0.4m", weight="7.6kg", abilities="TORRENT", types=[T("water")],
            desc="The fin on MUDKIP's head acts as highly sensitive radar. Using this fin to sense movements of water and air, this POKéMON can determine what is taking place around it without using its eyes.",
            stats=[dict(label=l, value=str(v), pct=round(min(1, v / 150), 3)) for l, v in zip(["HP", "ATTACK", "DEFENSE", "SP. ATK", "SP. DEF", "SPEED"], [50, 70, 50, 50, 50, 40])]))
d = dict(ready=True, waiting=False, time="12:41", money="3,000", dexSeen="5", dexCaught="3", dexSeenPct=round(5/386,3), dexCaughtPct=round(3/386,3), badgeCount="3", _wideLabel="OFF",
         badges=[dict(src=f"asset:ui/badge{i + 1}.png", locked=i >= 3, earned=i < 3, name=n) for i, n in enumerate(["STONE", "KNUCKLE", "DYNAMO", "HEAT", "BALANCE", "FEATHER", "MIND", "RAIN"])],
         trainer=dict(name="KIRA", id="22447"), partyCount="6", party=party,
         team=dict(hp=str(tot), maxHp=str(mx), hpPct=round(tot / mx, 3), hpHigh=tot / mx > .5, hpMid=.2 < tot / mx <= .5, hpLow=tot / mx <= .2, avg="8"),
         bag=bag, dex=dexd, map=dict(image="asset:ui/map.png", route="LITTLEROOT TOWN", kind="TOWN", px="9", py="8", live=True, off=False, hasMe=True, ratio="1.9300", mx="40.00%", my="55.00%"),
         battle=dict(inBattle=True, noBattle=False, balls="12", bagText="24 ITEMS", runText="OK", best="BEST: WATER GUN x2", bestName="BEST: WATER GUN", actFight=True, actBag=False, actMon=False, actRun=False, you=youmon, foe=foe, youMon=party[0], foeMon=mon(261, "POOCHYENA", 3, 12, 15, ["dark"], moves=MOVES[:2], ability="RUN AWAY", at="Makes escaping easier."), moves=bm),
         ui={"set": {k: party[0][k] for k in ["name", "level", "dex", "sprite", "types", "hp", "maxHp", "hpPct", "hpHigh", "hpMid", "hpLow", "male", "female", "ot", "id", "ability", "abilityText", "nature", "metLevel", "metPlace", "toNext", "expPct", "item", "ribbon", "heldIcon", "hasHeld", "friendPct", "statRows", "exp", "friendship", "moves", "moveDesc", "contestDesc", "condition", "sheen", "sheenPct", "status", "hasStatus"]} | dict(selName="POTION", selDesc="Restores the HP of one POKéMON by 20 points.", selIcon="asset:items/13.png", selHasIcon=True, selQty="x5", selPrice="300")})
json.dump(d, open(os.path.join(os.path.dirname(__file__), "..", "preview-data.json"), "w"), indent=1, ensure_ascii=False)
print("ok")
