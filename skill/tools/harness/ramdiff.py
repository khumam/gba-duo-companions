#!/usr/bin/env python3
"""Compares RAM dumps (play.py dump:NAME) to find what changed between game states, and prints memory around an
address. The quickest way to map a value: change one thing in the game (equip, use, move the cursor), dump before
and after, diff. To be sure, write the candidate back with play.py wr: and screenshot the game's own screen.

    python3 -I skill/tools/harness/ramdiff.py diff a.bin b.bin [--max-value 40] [--from 0x02000000 --to 0x02040000]
    python3 -I skill/tools/harness/ramdiff.py diff3 a.bin b.bin c.bin      # changed a->b and changed back b->c
    python3 -I skill/tools/harness/ramdiff.py hex a.bin 0x0201327A [--len 0x100]
    python3 -I skill/tools/harness/ramdiff.py find a.bin u16:1484 u32:2932607 bytes:cc053205

Dumps hold IWRAM (0x03000000, 32 KB) then EWRAM (0x02000000, 256 KB). For values the game shows, search the dump
for them (find); a save file's block often sits in RAM byte for byte (find bytes: a 16-byte run from the .sav).
"""
import argparse
import struct


def addr(i):
    return 0x03000000 + i if i < 0x8000 else 0x02000000 + i - 0x8000


def off(a):
    return a - 0x03000000 if a >= 0x03000000 else a - 0x02000000 + 0x8000


ap = argparse.ArgumentParser()
ap.add_argument("cmd")
ap.add_argument("args", nargs="+")
ap.add_argument("--max-value", type=int, default=255)
ap.add_argument("--from", dest="lo", default="0x02000000")
ap.add_argument("--to", dest="hi", default="0x03008000")
ap.add_argument("--len", default="0x80")
a = ap.parse_args()
lo, hi = int(a.lo, 0), int(a.hi, 0)


def inrange(i):
    x = addr(i)
    return lo <= x < hi


if a.cmd in ("diff", "diff3"):
    ds = [open(f, "rb").read() for f in a.args]
    for i in range(len(ds[0])):
        if not inrange(i):
            continue
        vals = [d[i] for d in ds]
        if max(vals) > a.max_value:
            continue
        if a.cmd == "diff" and vals[0] != vals[1]:
            print("%08X %d -> %d" % (addr(i), vals[0], vals[1]))
        if a.cmd == "diff3" and vals[0] != vals[1] and vals[2] == vals[0]:
            print("%08X %d -> %d -> %d" % (addr(i), *vals))
elif a.cmd == "hex":
    d = open(a.args[0], "rb").read()
    start, n = int(a.args[1], 0), int(a.len, 0)
    for x in range(start, start + n, 16):
        print("%08X " % x + d[off(x):off(x) + 16].hex(" "))
elif a.cmd == "find":
    d = open(a.args[0], "rb").read()
    for q in a.args[1:]:
        kind, val = q.split(":", 1)
        pat = {"u8": lambda v: struct.pack("<B", int(v, 0)), "u16": lambda v: struct.pack("<H", int(v, 0)),
               "u32": lambda v: struct.pack("<I", int(v, 0)), "bytes": bytes.fromhex}[kind](val)
        i, hits = -1, []
        while len(hits) < 16:
            i = d.find(pat, i + 1)
            if i < 0:
                break
            if inrange(i):
                hits.append("%08X" % addr(i))
        print(q, hits)
