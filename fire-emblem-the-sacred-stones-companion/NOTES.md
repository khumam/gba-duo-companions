# Fire Emblem: The Sacred Stones (GBA, USA BE8E) companion: notes

Built 2026-11-21 from the player's save (`~/Downloads/rom/fire-emblem-the-sacred-stones.28618.sav`, Creature Campaign,
Ephraim's route, 43 units), cloned from `fire-emblem-companion` (FE7): same engine, same `main.lua` apart from the
address table, raw portraits and the chapter fields. Not device-tested. Only the USA cartridge (`BE8E`).

## Pages and interaction

As in the FE7 pack (see its NOTES.md): Units -> Personal data 1/3 -> Items 2/3 -> Weapon & support 3/3 -> Supply ->
Status, with Equip / Use / Supply / Give and LEVEL UP! / JOINED banners. The look follows FE8's own screens (art/ref):
rose parchment panel behind the portrait, stats on the red-brown stone floor (`art/ui.py` draws it), slate-blue
windows (`#6b8cad`), gold plates. The Status leader is the route's lord (class ability 0x10000000 Eirika /
0x20000000 Ephraim, picked by the mode byte), as on the game's Status screen.

Checked in the emulator (harness, Lagdou Ruins 1 preparations): Give (Elixir out of the convoy), Use (HP 20 -> 55,
Elixir 2/3), Supply (Bright Lance to the convoy, stock 46/100 after both moves) on the game's own unit and Supply
screens. Equip is the same code as FE7's (checked there); here checked offline only.

Harness path from the title (`base`): `w200 a w300 st w200 st w200 a w200 a w500 w300 st w300 a w800` = world map;
`a w400 st w300` = Preparations; one more `st` starts the map.

## RAM (USA)

| What | Where |
|---|---|
| Player units | 0x0202BE4C, 0x48 each, 62 slots; enemies 0x0202CFBC (50); same unit layout as FE7 (stats +0x12.., items +0x1E, ranks +0x28, supports +0x32) |
| Chapter data 0x0202BCF0 | +0 play time (frames), +8 funds, +0xE chapter, +0x10 turn, +0x1B mode (2 Eirika, 3 Ephraim) |
| Convoy 0x0203A81C | 100 x u16 (the Supply screen shows it sorted by type; RAM order is storage order) |
| Battle struct 0x0203A4EC | +0x5A Atk, +0x60 Hit, +0x62 Avoid, +0x66 Crit (Seth 32 / 146 / 63 / 23 as shown) |

## ROM (USA)

| What | Where |
|---|---|
| Text | Huffman tree 0x0815A72C, root via 0x0815D488, table 0x0815D48C (decoder literal pool next to the ARM routine at 0x6E4) |
| Characters 0x08803D30 (0x34), classes from the unit pointer (0x54), items 0x08809B10 (0x24) | same field layout as FE7 |
| Portraits 0x088ACBC4 (0x1C) | main sheet **raw** after a 4-byte header (`00 04 10 00`), so `tiles = main + 4`; mini LZ77; same six-block face as FE7 |
| Icons 0x085926F4 (0x80 each) | items palette 0x085996F4, weapon-type / affinity symbols (0x70..0x83) palette 0x08599714 |
| Chapters 0x088B0890, 0x94 each | +0x70 title (Eirika), +0x72 title (Ephraim), +0x88 objective, +0x8A short goal |

## Open

Device check; Europe / Japan releases; B / W / L record; the world map (FE8's overworld) as a page; Glen-style
equip check in the harness.
