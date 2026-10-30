#!/usr/bin/env python3
"""Renders Oracle of Ages' two overworlds (Lynna present, Labrynna past) into PNGs from the game's
own data, as the oracles-disasm project stores it: room layouts, tileset mappings, gfx headers,
tile art (png) and palettes. Everything is read from a checkout of
https://github.com/Stewmath/oracles-disasm; nothing is read from a ROM.

  python3 art/render-map.py <oracles-disasm checkout> [--room-w 56 --room-h 45]

Writes assets/ui/map-present.png and map-past.png: 14 x 14 rooms, each room downscaled from its
160 x 128 px picture to room-w x room-h (a box filter, so the map reads as a picture, not noise).
"""
import os, re, struct, sys
from PIL import Image

root = sys.argv[1]
RW = int(sys.argv[sys.argv.index("--room-w") + 1]) if "--room-w" in sys.argv else 56
RH = int(sys.argv[sys.argv.index("--room-h") + 1]) if "--room-h" in sys.argv else 45
COLS, ROWS = 14, 14  # the overworld is 14 x 14 rooms; the rest of the 16 x 16 grid is unused
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")

def read(p): return open(os.path.join(root, p), encoding="utf-8", errors="replace").read()
def num(tok, names):
    tok = tok.strip()
    if tok.startswith("$"): return int(tok[1:], 16)
    if tok.isdigit(): return int(tok)
    return names[tok]

# ---- gfx headers (main and unique): list of (file, dest addr, bank, tiles, skip bytes) ------------
def parse_headers(path, start_macro):
    text = read(path)
    names, headers, cur = {}, {}, None
    for line in text.splitlines():
        line = line.split(";")[0].strip()
        m = re.match(rf"{start_macro}\s+(\$[0-9a-fA-F]+),\s*(\w+)", line)
        if m:
            idx = int(m.group(1)[1:], 16); names[m.group(2)] = idx; cur = headers[idx] = []; continue
        m = re.match(r"m_GfxHeader\s+(.*)", line)
        if m and cur is not None:
            cur.append([a.strip() for a in m.group(1).split(",")])
    return names, headers

gfx_names, gfx_headers = parse_headers("data/ages/gfxHeaders.s", "m_GfxHeaderStart")
uni_names, uni_headers = parse_headers("data/ages/uniqueGfxHeaders.s", "m_UniqueGfxHeaderStart")

# ---- palettes -------------------------------------------------------------------------------------
pal_data, label = {}, None
for line in read("data/ages/paletteData.s").splitlines():
    line = line.split(";")[0].strip()
    m = re.match(r"(\w+):", line)
    if m: label = m.group(1); pal_data[label] = []; continue
    m = re.match(r"m_RGB16\s+\$(\w+)\s+\$(\w+)\s+\$(\w+)", line)
    if m and label:
        r, g, b = (int(x, 16) for x in m.groups())
        # the LCD colour mix mGBA applies to GBC games, so the map matches the picture on screen
        r, g, b = (r * 26 + g * 4 + b * 2) // 32, (g * 24 + b * 8) // 32, (r * 6 + g * 4 + b * 22) // 32
        pal_data[label].append(((r * 255) // 31, (g * 255) // 31, (b * 255) // 31))

pal_names, pal_headers, cur = {}, {}, None
for line in read("data/ages/paletteHeaders.s").splitlines():
    line = line.split(";")[0].strip()
    m = re.match(r"m_PaletteHeaderStart\s+(\$\w+),\s*(\w+)", line)
    if m: idx = int(m.group(1)[1:], 16); pal_names[m.group(2)] = idx; cur = pal_headers[idx] = []; continue
    m = re.match(r"m_PaletteHeaderBg\s+(\d+),\s*(\d+),\s*(\w+)", line)
    if m and cur is not None: cur.append((int(m.group(1)), int(m.group(2)), m.group(3)))

# ---- tilesets: 8 bytes each ---------------------------------------------------------------------------
names = {}
names.update(gfx_names); names.update(uni_names); names.update(pal_names)
tilesets, cur = [], []
started = False
for line in read("data/ages/tilesets.s").splitlines():
    line = line.split(";")[0].strip()
    if line.startswith("tilesetData:"): started = True; continue
    if not started: continue
    if line.startswith(".db"):
        cur += [num(t, names) for t in line[3:].split(",")]
        if len(cur) >= 8: tilesets.append(cur[:8]); cur = cur[8:]
    elif line and not line.startswith("."): break

# ---- tile art -------------------------------------------------------------------------------------------
_png_cache = {}
def png_tiles(name):
    """A gfx png as a list of 8x8 tiles, each 64 colour indices (0-3)."""
    if name in _png_cache: return _png_cache[name]
    for d in ("gfx", "gfx_compressible"):
        p = os.path.join(root, d, "ages", name + ".png")
        if os.path.exists(p): break
        p = os.path.join(root, d, "common", name + ".png")
        if os.path.exists(p): break
    else:
        raise FileNotFoundError(name)
    im = Image.open(p)
    gray = im.convert("L")
    w, h = gray.size
    tiles = []
    for ty in range(h // 8):
        for tx in range(w // 8):
            t = []
            for y in range(8):
                for x in range(8):
                    v = gray.getpixel((tx * 8 + x, ty * 8 + y))
                    t.append(3 - round(v / 85))
            tiles.append(t)
    _png_cache[name] = tiles
    return tiles

def build_vram(gfx_idx, uni_idx):
    vram = {}  # (bank, tile#) -> 64 indices ; tile# counted from 0x8000
    for headers, idx in ((gfx_headers, gfx_idx), (uni_headers, uni_idx)):
        for entry in headers.get(idx, []):
            file = entry[0]
            dest = num(entry[1], {}) if entry[1].startswith("$") else None
            if dest is None: continue  # wram destinations
            bank, addr = dest & 0xF, dest & 0xFFF0
            tiles = png_tiles(file)
            skip = int(entry[3].replace("$", "0x"), 16 if "$" in entry[3] else 10) // 16 if len(entry) > 3 else 0
            count = (num(entry[2], {}) if len(entry) > 2 else len(tiles) - skip)
            for i in range(count):
                if skip + i < len(tiles):
                    vram[(bank, (addr - 0x8000) // 16 + i)] = tiles[skip + i]
    return vram

_map_cache = {}
def mappings(layout):
    if layout not in _map_cache:
        _map_cache[layout] = open(os.path.join(root, "tileset_layouts/ages", f"tilesetMappings{layout:02x}.bin"), "rb").read()
    return _map_cache[layout]

def palette_set(pal_idx):
    # bg palettes 0 and 1 come from the common header the game loads first (PALH_0a)
    pals = {0: pal_data["paletteData48e0"][0:4], 1: pal_data["paletteData48e0"][4:8]}
    for start, count, label in pal_headers.get(pal_idx, []):
        colours = pal_data[label]
        for i in range(count): pals[start + i] = colours[i * 4:(i + 1) * 4]
    return pals

_tileset_cache = {}
def tileset_render_data(ts):
    if ts not in _tileset_cache:
        b = tilesets[ts]
        _tileset_cache[ts] = (build_vram(b[3], b[2]), palette_set(b[4]), mappings(b[5]))
    return _tileset_cache[ts]

def render_room(group, room):
    ts_byte = open(os.path.join(root, f"rooms/ages/group{group}Tilesets.bin"), "rb").read()[room] & 0x7F
    vram, pals, maps = tileset_render_data(ts_byte)
    # the tileset names the layout group (present rooms use 0, past rooms 2)
    layout = open(os.path.join(root, f"rooms/ages/small/room{tilesets[ts_byte][6]:02x}{room:02x}.bin"), "rb").read()
    img = Image.new("RGB", (160, 128))
    px = img.load()
    for cy in range(8):
        for cx in range(10):
            meta = layout[cy * 10 + cx]
            for q in range(4):
                tile, attr = maps[meta * 8 + q], maps[meta * 8 + 4 + q]
                bank, pal = (attr >> 3) & 1, attr & 7
                # LCDC bit 4 clear: tiles 0x80-0xFF live at $8800, 0x00-0x7F at $9000
                idx = (0x800 + (tile - 0x80) * 16) // 16 if tile >= 0x80 else (0x1000 + tile * 16) // 16
                data = vram.get((bank, idx), [0] * 64)
                colours = pals.get(pal, [(255, 0, 255)] * 4)
                for y in range(8):
                    for x in range(8):
                        sx, sy = (7 - x) if attr & 0x20 else x, (7 - y) if attr & 0x40 else y
                        px[cx * 16 + (q & 1) * 8 + x, cy * 16 + (q >> 1) * 8 + y] = colours[data[sy * 8 + sx]]
    return img

for group, name in ((0, "present"), (1, "past")):
    sheet = Image.new("RGB", (COLS * RW, ROWS * RH))
    for room in [y * 16 + x for y in range(ROWS) for x in range(COLS)]:
        try:
            im = render_room(group, room).resize((RW, RH), Image.BOX)
        except Exception as e:
            print("room", group, hex(room), "failed:", e); continue
        sheet.paste(im, ((room & 15) * RW, (room >> 4) * RH))
    sheet.save(os.path.join(OUT, f"map-{name}.png"))
    print("wrote", name)
