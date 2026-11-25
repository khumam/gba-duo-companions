# 0.4.0 (2026-11-24): the game's own pause screens, re-laid for touch
Design: `.idea/plans/cv-design2/hod-*.png` (fresh full-size pause captures in its `ref/hod-menu-*.png`). Source: `art/layout.py`,
`art/style.src.css`, `art/hod_ui.py` (the green plaque with its dithered tail, `ui/plaque.png`). Old source: `art/v2/`.
- Banded royal-blue field, the green gothic plaque (Jacquard 24, `assets/fonts`, OFL), the game's word menu on the left with the glove,
  each word on a rule; equipment as five slot sockets (WHIP, BODY, GOODS x3) with the choices for the open slot; relics as the game's
  boxed list with the green ON / OFF pills; spell books as the game's list with SET; the INFORMATION bar holds all text and actions.
- The game's menus DO show icons for items, relics, whip tips and books in the INFORMATION bar (found in the new captures); the pack
  still uses its own relic / item icons, so cutting the game's is the next step.
- `main.lua`: one nav flag (`onConfig`).

# 0.3.0 (2026-11-24): map like the game, pixel kit, one size per control
- **Map**: redrawn like the community HoD pack's (credit: Ress): `mapdata.lua` is generated from the ROM (map tiles `0x080DAD94`, boundaries `0x080DC194`: 674 rooms, 14 save, 11 warp), `gamemap.lua` draws one `HodMap.ttf` glyph per cell; castle A `#5284bd`, castle B `#426310`, save red, warp yellow.
- **Fixed**: the explored bits are at `0x0200008C` (+ `0x140` for columns 32-63, 8-byte rows, castle B in the second u32). The 0.2.0 offsets (`0x02000094` / `0x020001E4`) were wrong: only 387 of 663 set bits fell on room cells; the new offsets put 663 of 690 (the Maxim save) on rooms. Juste's marker now uses the game's room position at `0x02000070` (bit 0 castle B, bits 1-7 x; `+1` y), the address the community pack uses (plausible on the Maxim save: castle B, room 30,21; other rooms not walked).
- **Pixel kit**: see the Aria notes; tokens in `art/pixel.json`, originals in `art/v2/`.

# 0.2.0 layout (design: `.idea/plans/hod-design/` in the app repo)

Green-plaque tabs on the left (STATUS, EQUIP, ITEMS, BOOK, RELICS, MAP), the game's INFORMATION bar as the inspector, relics as an icon grid
with a corner ON / OFF switch, key config behind KEYS. The 0.1.x files are in `art/v1/`.

## Game art (cut from the game, `assets/game/`)
Juste's portrait and the five spell book emblems (Status screen; the emblem changes with the set book, so each was captured with the set-book
byte written to 1-5). The relics, items and equipment have no pictures in the game's menus: those icons are the original pixel art from 0.1.x.

## Player position on the map (partly verified, read this)
| Address | What |
|---|---|
| `0x0200EDB9` / `BA` | u8 origin cell (x, y) of the room, as read in a new Juste game |
| `0x03007DFC` | u16 Juste's x position in the room, pixels |

Cell x = origin x + px // 256, y = origin y. Verified only in the first corridor of a new Juste game (x 1-6, y 22, against the game re-marking the
cell he stands in: clear the explored-map bits in RAM, run frames, read the marked bit). **Not verified:** other rooms and floors (a boss blocked
the harness after the first corridor), and the Maxim save (its bytes at `0x0200EDB9` hold other data; this pack waits there anyway: Maxim mode has no
pause menu). The marker is only drawn when the computed cell is lit in the castle on show, so a wrong guess hides it. **Check it in other rooms
on a real Juste game.**

# Castlevania: Harmony of Dissonance companion: notes

USA (`ACHE`). v0.1.0, 2026-11-21, not device-tested. The user's save is a Maxim-mode file (no pause menu), so the
screens and RAM were mapped on a new Juste game with inventory written into RAM; every write was replayed in the
emulator and checked on the game's own screens (HP/MP, item counts, spell book, relic switches, buttons).

Pages: Map (the game's SELECT map: Castle A / B tabs; 64 x 42 cells, 8-byte rows = Castle A u32 + Castle B u32, left 32 columns at 0x02000094, right 32 at 0x020001E4 (36 rows), 674 cells per castle = 100%, total rate from the combined count; checked against the game's map and 98.3% / 196.7% on the user's Maxim save), Status, Equip (read-only: the game redoes stats only in its own Equip menu), Items (USE, measured amounts:
Potion 70, High Potion 150, Elixir all, Mana Prism 20 MP, Big Mana Prism 100 MP, Drumstick 100, Turkey 200),
Spell Book (SET), Relics (tap ON/OFF), Key Config. Alerts: RELIC, SPELL BOOK, LEVEL UP.

ROM: text = u16 chars (A-Z 0x8260.., a-z 0x8548.., 0-9 0x824F.., space 0x8540, see PUNCT in main.lua); 709 string
pointers at 0x08495498, each string has a u16 header. Ids: items 60-87, whip tips 88-96, body 97-138, goods 139-224,
books 225-229, relics 230-241, furniture 242-272, description = id + 213, enemies 486-585. NEXT = 60*L*(L+1), max 499999.

RAM: frames 0x02000088; live HP/MP/STR/DEF/INT/LCK 0x0201854E; save block 0x02018760: +0x1C level, +0x1F spell
book set (1-based), +0x20 body, +0x21..23 goods (id-97, 0xFF none), +0x24 whip (id-88), +0x26 max HP, MP, hearts,
STR DEF INT LCK base, +0x34 hearts, +0x38 EXP, +0x3C gold, +0x40 counts ids 60-87, +0x5C whip-tip bits, +0x5E counts
ids 97-224, +0xDE book bits, +0xDF relic owned (u16, odd address), +0xE1 relic ON (u16, odd: write bytes), +0xEC buttons.

Not done: device check, equip writes (needs the stat table), Secret Info (enemy / furniture lists), player marker on the map, status
ailments, spell book ON/OFF, EU/JP.
