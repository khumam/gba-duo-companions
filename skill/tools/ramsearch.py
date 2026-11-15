#!/usr/bin/env python3
"""Cheat Engine-style search over RAM dumps, to find a game's addresses.

A dump is what `dump FILE` in gba-harness.c writes (or the device's states loaded in the harness): IWRAM (32 KB, bus
0x03000000) then EWRAM (256 KB, bus 0x02000000). Take a dump, change one thing in the game (spend a rupee, take
damage, open a menu), take another, and narrow the candidates down:

  ramsearch.py new   S.json DUMP --width 2 [--value 120]   start: every aligned address (or those equal to value)
  ramsearch.py next  S.json DUMP --is changed|same|up|down|equal|delta [--value N] [--delta N]
  ramsearch.py show  S.json [--limit 30]                   candidates left, as bus addresses with their last value
  ramsearch.py near  DUMP ADDR [--count 16] [--width 2]    the words around an address, for structs

Several rounds ("changed", "same", "changed", ...) leave a handful of addresses. Values are read little-endian,
unsigned; --width is 1, 2 or 4 bytes. Run `python3 -I ramsearch.py` from a folder of your own, never from one
holding untrusted files.
"""
import argparse, json, struct, sys

IWRAM, EWRAM = 0x03000000, 0x02000000
IW_SIZE, EW_SIZE = 0x8000, 0x40000

def load(path):
    data = open(path, 'rb').read()
    if len(data) != IW_SIZE + EW_SIZE:
        sys.exit(f"{path}: {len(data)} bytes, expected {IW_SIZE + EW_SIZE} (IWRAM + EWRAM dump)")
    return data

def bus(offset):
    return IWRAM + offset if offset < IW_SIZE else EWRAM + offset - IW_SIZE

def offset(addr):
    if IWRAM <= addr < IWRAM + IW_SIZE: return addr - IWRAM
    if EWRAM <= addr < EWRAM + EW_SIZE: return IW_SIZE + addr - EWRAM
    sys.exit(f"{addr:#x} is not in IWRAM/EWRAM")

FMT = {1: '<B', 2: '<H', 4: '<I'}

def value(data, off, width):
    return struct.unpack_from(FMT[width], data, off)[0]

def aligned(width):
    return range(0, IW_SIZE + EW_SIZE - width + 1, width)

def save(path, state):
    json.dump(state, open(path, 'w'))

def cmd_new(a):
    data = load(a.dump)
    cands = {}
    for off in aligned(a.width):
        v = value(data, off, a.width)
        if a.value is None or v == a.value: cands[off] = v
    save(a.state, {'width': a.width, 'cands': cands})
    print(f"{len(cands)} candidates")

def cmd_next(a):
    st = json.load(open(a.state)); width = st['width']; data = load(a.dump); keep = {}
    for off, old in st['cands'].items():
        off = int(off); v = value(data, off, width)
        ok = {'changed': v != old, 'same': v == old, 'up': v > old, 'down': v < old,
              'equal': v == a.value, 'delta': a.delta is not None and v - old == a.delta}[a.is_]
        if ok: keep[off] = v
    save(a.state, {'width': width, 'cands': keep})
    print(f"{len(keep)} candidates")

def cmd_show(a):
    st = json.load(open(a.state))
    for i, (off, v) in enumerate(sorted((int(o), v) for o, v in st['cands'].items())):
        if i >= a.limit: print('...'); break
        print(f"{bus(off):#010x}  {v} ({v:#x})")

def cmd_near(a):
    data = load(a.dump); base = offset(int(a.addr, 0))
    for i in range(a.count):
        off = base + i * a.width
        if off + a.width > len(data): break
        v = value(data, off, a.width)
        print(f"{bus(off):#010x}  {v} ({v:#x})")

def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest='cmd', required=True)
    n = sub.add_parser('new'); n.add_argument('state'); n.add_argument('dump'); n.add_argument('--width', type=int, choices=(1, 2, 4), default=2); n.add_argument('--value', type=lambda s: int(s, 0)); n.set_defaults(f=cmd_new)
    x = sub.add_parser('next'); x.add_argument('state'); x.add_argument('dump'); x.add_argument('--is', dest='is_', required=True, choices=('changed', 'same', 'up', 'down', 'equal', 'delta')); x.add_argument('--value', type=lambda s: int(s, 0)); x.add_argument('--delta', type=int); x.set_defaults(f=cmd_next)
    s = sub.add_parser('show'); s.add_argument('state'); s.add_argument('--limit', type=int, default=30); s.set_defaults(f=cmd_show)
    r = sub.add_parser('near'); r.add_argument('dump'); r.add_argument('addr'); r.add_argument('--count', type=int, default=16); r.add_argument('--width', type=int, choices=(1, 2, 4), default=2); r.set_defaults(f=cmd_near)
    a = p.parse_args(); a.f(a)

main()
