#!/usr/bin/env python3
"""Readability pass: writes PACK/readability.css (tracking and line height for every text rule) and lists it in manifest.json "styles"
after the pack's own stylesheet, so the pack's sources are never touched and the pass survives their rebuilds (run it again after a
style change).

    python3 skill/tools/packkit/readability.py PACK [PACK ...]          # --dry prints what it would write

For every rule of PACK/style.css (inside @media blocks too) that sets a font-size and no letter-spacing, it adds a letter-spacing made
from the font's own needs and the rule's size; for every multi-line text rule (white-space: normal or line-clamp) with no line height,
or one under 1.1 x the size, it adds one. Rules that already set letter-spacing (hand-tuned, or map glyph fonts that must stay at 0)
are left alone, and so are ellipsis slots (text-overflow: ellipsis), whose width was chosen so names just fit. The font is the rule's own font-family, else the pack's default (#screen / root / page / text rules).

Tracking (fraction of the font size, at least 0.4 px, at most 2 px):
  Silkscreen 0.08   (wide pixel capitals: captions need air)       Press Start 2P 0.06
  Jersey 10  0.04   (narrow: letters touch at small sizes)         Jacquard / Nunito / others 0.02
Line height: Jersey 1.15, Silkscreen 1.4, Press Start 1.5, others 1.3. Sizes of 30 px and more get half the tracking.
"""
import json, os, re, sys

TRACK = {"silk": 0.08, "press": 0.06, "jersey": 0.04, "jacquard": 0.02, "sans": 0.02}
LEAD = {"silk": 1.4, "press": 1.5, "jersey": 1.15, "jacquard": 1.2, "sans": 1.3}
SKIP_FONTS = ("hodmap", "map")                         # glyph fonts drawn cell by cell


def kind_of(fontfile):
    f = fontfile.lower()
    if "silkscreen" in f: return "silk"
    if "pressstart" in f: return "press"
    if "jersey" in f: return "jersey"
    if "jacquard" in f: return "jacquard"
    if any(s in f for s in SKIP_FONTS): return "skip"
    return "sans"


def blocks(css):
    """yield (media, selector, body) for every plain rule; media is the enclosing @media prelude or None"""
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    i, n = 0, len(css)
    while i < n:
        j = css.find("{", i)
        if j < 0: break
        pre = css[i:j].strip()
        if pre.startswith("@media"):
            depth, k = 1, j + 1
            while k < n and depth:
                depth += {"{": 1, "}": -1}.get(css[k], 0); k += 1
            for _, sel, body in blocks(css[j + 1:k - 1]): yield pre, sel, body
            i = k
            continue
        k = css.find("}", j)
        if k < 0: break
        yield None, pre, css[j + 1:k]
        i = k + 1


def props(body):
    out = {}
    for decl in body.split(";"):
        if ":" in decl:
            a, b = decl.split(":", 1); out[a.strip().lower()] = b.strip()
    return out


def px(v):
    m = re.match(r"^(-?\d+(?:\.\d+)?)(px)?$", (v or "").strip())
    return float(m.group(1)) if m else None


def run(pack, dry=False):
    css = open(os.path.join(pack, "style.css")).read()
    fams = {}                                              # family name -> font kind
    for m in re.finditer(r"@font-face\s*\{([^}]*)\}", css):
        p = props(m.group(1))
        fam = p.get("font-family", "").strip("\"' ")
        src = re.search(r"url\(\s*[\"']?([^\"')]+)", p.get("src", ""))
        if fam and src: fams[fam.lower()] = kind_of(src.group(1))

    def kind(value):
        for name in (value or "").split(","):
            name = name.strip().strip("\"'").lower()
            if name in fams: return fams[name]
        return None

    rules = list(blocks(re.sub(r"@font-face\s*\{[^}]*\}", "", css)))
    default, clean_default = "jersey", None
    for media, sel, body in rules:                         # the pack's default face, and the clean tree's (Minish Cap / Ages)
        p = props(body)
        k = kind(p.get("font-family"))
        if not k or media: continue
        sels = [s.strip() for s in sel.split(",")]
        if any(s in ("#screen", "text", ".root", ".page", ".main", "body", ".bezel", ".shell") for s in sels): default = k
        if any(s == ".c-root" for s in sels): clean_default = k

    out, n_track, n_lead = [], 0, 0
    for media, sel, body in rules:
        p = props(body)
        size = px(p.get("font-size"))
        if size is None or size <= 0: continue
        k = kind(p.get("font-family")) or (clean_default if sel.strip().startswith(".c-") and clean_default else default)
        if k == "skip": continue
        add = []
        tight = p.get("text-overflow", "") == "ellipsis"      # a slot sized to cut long names: extra tracking would only cut more
        if "letter-spacing" not in p and not tight:
            t = TRACK[k] * size * (0.5 if size >= 30 else 1)
            t = max(0.4, min(2.0, t))
            add.append("letter-spacing: %.2fpx" % t); n_track += 1
        multi = p.get("white-space", "") == "normal" or "line-clamp" in p
        lh = p.get("line-height")
        lhv = px(lh) if lh else None
        if lh and lhv is None:
            try: lhv = float(lh) * size                       # unitless multiplier
            except ValueError: lhv = None
        if multi and (lh is None or (lhv is not None and lhv < 1.1 * size)):
            add.append("line-height: %.1fpx" % (LEAD[k] * size)); n_lead += 1
        if add:
            rule = "%s { %s; }" % (sel, "; ".join(add))
            out.append((media, rule))

    text = ["/* readability.css: written by skill/tools/packkit/readability.py from style.css. Do not edit by hand: run the tool again.",
            "   Adds tracking (and line height for wrapped text) by font and size; rules that set letter-spacing themselves are left alone. */"]
    for media in [None] + sorted({m for m, _ in out if m}):
        part = [r for m, r in out if m == media]
        if not part: continue
        if media: text.append("%s {" % media); text += ["  " + r for r in part]; text.append("}")
        else: text += part
    if dry:
        print("\n".join(text)); return n_track, n_lead
    open(os.path.join(pack, "readability.css"), "w").write("\n".join(text) + "\n")
    mpath = os.path.join(pack, "manifest.json")
    raw = open(mpath).read(); man = json.loads(raw)
    st = man.get("styles", ["style.css"])
    if "readability.css" not in st:
        st = [s for s in st] + ["readability.css"]
        # keep the manifest's own formatting: rewrite only the styles array
        new = re.sub(r'"styles"\s*:\s*\[[^\]]*\]', '"styles": ' + json.dumps(st), raw, count=1)
        if new == raw: man["styles"] = st; new = json.dumps(man, indent=2) + "\n"
        open(mpath, "w").write(new)
    return n_track, n_lead


if __name__ == "__main__":
    dry = "--dry" in sys.argv
    for pack in [a for a in sys.argv[1:] if not a.startswith("--")]:
        t, l = run(pack.rstrip("/"), dry)
        if not dry: print("%-45s tracking %3d rules, line height %3d rules" % (os.path.basename(pack.rstrip("/")), t, l))
