#!/usr/bin/env python3
"""Finds a game's text in a ROM when it isn't ASCII.

    python3 -I skill/tools/harness/textfind.py ROM "Leather Armor" [--width 1|2] [--mode pattern|relative]

pattern  (default) letters that repeat in the word must repeat in the ROM and different letters must differ, whatever
         their codes are. Works for any one-code-per-letter table, even one sorted by letter frequency
         (Circle of the Moon) or by font order. Prints the offset and the letter -> code map it implies.
relative codes keep the alphabet's spacing (b = a + 1 ...), the common case for ASCII-shifted tables.

Widths: 1 for byte text, 2 for 16-bit text (Harmony of Dissonance stores u16 characters). Then decode around the hit
with the map, fill gaps from words you can guess, and look for the u32 pointer table (search the ROM for 0x08000000 +
the string's offset, also a few bytes earlier: strings often carry a header).
"""
import argparse
import struct

ap = argparse.ArgumentParser()
ap.add_argument("rom")
ap.add_argument("word")
ap.add_argument("--width", type=int, default=1)
ap.add_argument("--mode", default="pattern")
ap.add_argument("--max", type=int, default=8)
a = ap.parse_args()
rom = open(a.rom, "rb").read()
vals = rom if a.width == 1 else [struct.unpack_from("<H", rom, i)[0] for i in range(0, len(rom) - 1, 2)]
n = len(a.word)
hits = 0
for i in range(len(vals) - n):
    if a.mode == "relative":
        if all(vals[i + k + 1] - vals[i + k] == ord(a.word[k + 1]) - ord(a.word[k]) for k in range(n - 1)):
            print("%X shift %d" % (i * a.width, vals[i] - ord(a.word[0])))
            hits += 1
    else:
        m, r, ok = {}, {}, True
        for k, ch in enumerate(a.word):
            v = vals[i + k]
            if ch in m:
                if m[ch] != v:
                    ok = False
                    break
            elif v in r:
                ok = False
                break
            else:
                m[ch], r[v] = v, ch
        if ok:
            print("%X" % (i * a.width), {k: hex(v) for k, v in m.items()})
            hits += 1
    if hits >= a.max:
        break
if not hits:
    print("no hit")
