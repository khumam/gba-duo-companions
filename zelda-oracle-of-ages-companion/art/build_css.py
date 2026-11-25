#!/usr/bin/env python3
"""style.css = art/style.brick.css + art/clean.src.css with every class prefixed c- and every custom property --c-, so the clean
style never touches the brick one.   python3 art/build_css.py && node art/layout.mjs
Edit the brick look in art/style.brick.css and the clean look in art/clean.src.css (style.css is generated)."""
import os, re

here = os.path.dirname(os.path.abspath(__file__))
brick = open(os.path.join(here, "style.brick.css")).read()
clean = open(os.path.join(here, "clean.src.css")).read()


def sel_fix(sel):
    out = []
    for one in sel.split(","):
        res = []
        for t in one.split():
            t = re.sub(r"\.([A-Za-z][\w-]*)", lambda m: m.group(0) if m.group(1).startswith("theme-") else ".c-" + m.group(1), t)
            res.append(".c-root" if t == ":root" else t)
        out.append(" ".join(res))
    return ", ".join(out)


def body_fix(b):
    b = re.sub(r"(?<![\w-])--([a-z][\w-]*)\s*:", lambda m: "--c-" + m.group(1) + ":", b)
    return re.sub(r"var\(--([a-z][\w-]*)", lambda m: "var(--c-" + m.group(1), b)


parts = re.split(r"(/\*.*?\*/)", clean, flags=re.S)
conv = "".join(p if p.startswith("/*") else re.sub(r"([^{}]+)\{([^{}]*)\}", lambda m: "\n%s {%s}" % (sel_fix(m.group(1).strip()), body_fix(m.group(2))) if m.group(1).strip() else m.group(0), p) for p in parts)
open(os.path.join(here, "..", "style.css"), "w").write(brick.rstrip() + "\n\n/* ======== clean style (art/clean.src.css, built by art/build_css.py) ======== */\n" + conv)
print("ok")
