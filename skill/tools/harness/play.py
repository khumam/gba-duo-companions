#!/usr/bin/env python3
"""Plays a game headless from a list of short steps and saves screenshots, RAM dumps and reads.

    python3 -I skill/tools/harness/play.py --harness ./gba-harness --rom game.gba [--save game.sav] \\
        --out run/ [--base base.steps] STEP ...

The save is copied next to a scratch copy of the ROM for every run, so the harness (which writes the save back)
never touches the original. Steps (one word each):

    a b sel st u d l r R L   press a button (6 frames down, released, 40 frames to settle)
    x5d                      press a button 5 times (30 frames apart)
    hold:<hex>:<frames>      hold keys (e.g. hold:80:200 walks down for 200 frames; keys: A 1 B 2 SEL 4 ST 8
                             RIGHT 10 LEFT 20 UP 40 DOWN 80 R 100 L 200)
    w<N>                     wait N frames
    shot:<name>              screenshot -> OUT/<name>.png (3x, nearest)
    dump:<name>              IWRAM 32 KB + EWRAM 256 KB -> OUT/<name>.bin (EWRAM starts at offset 0x8000)
    wr:<addr>=<val>[:<width>]  write (hex; width 1/2/4 bytes)
    rd:<addr>:<len>          print bytes (hex) to stdout
    io                       print the display registers (ioraw 0x04000000, 96 bytes)
    vram:<name>              VRAM 96 KB + palette 1 KB + OAM 1 KB -> OUT/<name>.vram / .pal / .oam
    @file                    include steps from a file (whitespace separated; # comments)

Gotchas: a key passed to the raw `keys` command stays held for later `run`s, which is why every press here is
followed by a release. Title screens and intros differ per game: write a base.steps that reaches the field with the
save loaded, check it with one screenshot, and reuse it with --base.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

KEY = {"a": 1, "b": 2, "sel": 4, "st": 8, "r": 0x10, "l": 0x20, "u": 0x40, "d": 0x80, "R": 0x100, "L": 0x200}


def expand(words, base_dir):
    out = []
    for w in words:
        if w.startswith("@"):
            path = os.path.join(base_dir, w[1:]) if not os.path.isabs(w[1:]) else w[1:]
            text = open(path).read()
            lines = [ln.split("#", 1)[0] for ln in text.splitlines()]
            out += expand(" ".join(lines).split(), os.path.dirname(path))
        else:
            out.append(w)
    return out


def compile_steps(words, outdir):
    cmds, reads = [], []
    for s in words:
        if s in KEY:
            cmds += [f"keys {KEY[s]:x} 6", "keys 0 1", "run 40"]
        elif s.startswith("x") and s[1:].rstrip("abdlrsetuLR").isdigit():
            n = int("".join(ch for ch in s[1:] if ch.isdigit()))
            k = s[1 + len(str(n)):]
            cmds += [f"keys {KEY[k]:x} 6", "keys 0 1", "run 30"] * n
        elif s.startswith("hold:"):
            _, k, n = s.split(":")
            cmds += [f"keys {k} {int(n)}", "keys 0 1"]
        elif s.startswith("w") and s[1:].isdigit():
            cmds.append(f"run {s[1:]}")
        elif s.startswith("shot:"):
            cmds.append(f"ppm {os.path.join(outdir, s[5:])}.ppm")
        elif s.startswith("dump:"):
            cmds.append(f"dump {os.path.join(outdir, s[5:])}.bin")
        elif s.startswith("wr:"):
            a, v = s[3:].split("=")
            w = "1"
            if ":" in v:
                v, w = v.split(":")
            cmds.append(f"wr {a} {v} {w}")
        elif s.startswith("rd:"):
            _, a, n = s.split(":")
            cmds.append(f"rd {a} {n}")
            reads.append(s)
        elif s == "io":
            cmds.append("ioraw 04000000 96")
            reads.append(s)
        elif s.startswith("vram:"):
            name = os.path.join(outdir, s[5:])
            cmds += ["rd 06000000 98304", "rd 05000000 1024", "rd 07000000 1024"]
            reads.append(("vram", name))
        else:
            sys.exit(f"bad step: {s}")
    return cmds, reads


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--harness", required=True)
    ap.add_argument("--rom", required=True)
    ap.add_argument("--save")
    ap.add_argument("--out", default="run")
    ap.add_argument("--base", help="steps file run before the steps (e.g. title screen -> field)")
    ap.add_argument("steps", nargs="*")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    words = expand((["@" + a.base] if a.base else []) + a.steps, os.getcwd())
    cmds, reads = compile_steps(words, os.path.abspath(a.out))
    with tempfile.TemporaryDirectory() as tmp:
        rom = os.path.join(tmp, "game.gba")
        shutil.copyfile(a.rom, rom)
        if a.save:
            shutil.copyfile(a.save, os.path.join(tmp, "game.sav"))
        res = subprocess.run([os.path.abspath(a.harness), rom], input="\n".join(cmds) + "\n",
                             capture_output=True, text=True)
    # the harness logs to stdout too: keep the long hex lines our reads asked for
    hexes = [ln for ln in res.stdout.splitlines() if ln and all(c in "0123456789abcdef" for c in ln)]
    hi = 0
    for r in reads:
        if isinstance(r, tuple):
            vram, pal, oam = hexes[hi:hi + 3]
            hi += 3
            open(r[1] + ".vram", "wb").write(bytes.fromhex(vram))
            open(r[1] + ".pal", "wb").write(bytes.fromhex(pal))
            open(r[1] + ".oam", "wb").write(bytes.fromhex(oam))
        else:
            print(r, hexes[hi] if hi < len(hexes) else "?")
            hi += 1
    try:
        from PIL import Image
        for f in os.listdir(a.out):
            if f.endswith(".ppm"):
                p = os.path.join(a.out, f)
                Image.open(p).resize((720, 480), Image.NEAREST).save(p[:-4] + ".png")
                os.remove(p)
    except ImportError:
        print("(Pillow missing: screenshots left as .ppm)")


if __name__ == "__main__":
    main()
