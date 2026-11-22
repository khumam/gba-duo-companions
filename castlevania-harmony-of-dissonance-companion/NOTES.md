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
