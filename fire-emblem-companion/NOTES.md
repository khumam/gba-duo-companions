# Fire Emblem (GBA, Europe AE7Y) companion: notes

Built 2026-11-21 from the player's save (`~/Downloads/rom/fire-emblem.34825.sav`, Hector's tale, Ch. 31x) with the skill's
harness. Not device-tested yet. Only the European cartridge (`AE7Y`); the US one (`AE7E`) has other ROM addresses.

## Pages (left / right plates, like the game's `< title > n/3`)

Units (army list, 12 per page, mini portraits; undeployed units dimmed as in Pick Units) -> Personal data 1/3 ->
Items 2/3 -> Weapon & support 3/3 -> Supply (convoy, tabs per weapon type) -> Status (chapter, objective, turn, funds,
player / enemy, leader, play time). Reference screens: `art/ref/game-*.png`.

Interactive (memory-write): tap a unit card -> its stat pages; up / down steps through units; on Items tap a row then
**Equip** (moves it to the top, as the game does), **Use** (Vulnerary +10 / Elixir full HP, uses -1, removed at 0),
**Supply** (to the convoy); on Supply tap an item then **Give to <unit>** (convoy gap closed). All four were replayed
in the emulator and checked on the game's own unit screens (art/ref is before; harness shots in the session).
Live banner: LEVEL UP! / JOINED THE ARMY (diffed per character id, first read ignored).

No spoilers: support partners not yet in the army show as `?????????`.

## The save (important)

The player's .sav had every chapter slot marked empty in the SRAM directory (0x64, 7 x 16-byte entries, kind 0xFF)
while the chapter data was intact. Rebuilt in a scratch copy only (original untouched):
`{u32 magic 0x11217, u16 0x200A, u8 kind 0, u8 0, u16 offset, u16 size 0xD8C, u32 checksum}` for slots at 0x3F2C,
0x4CB8, 0x5A44. Checksum = (xor of u16s << 16) | (sum of u16s & 0xFFFF). Header 0x00-0x5F, its u16 checksum
(sum + xor) at 0x60. Suspends: 0xD4 / 0x2000 (0x1F2C, magic 0x20509), arena block 0x67D0 (magic 0x20112, kind 2).

## RAM

| What | Where |
|---|---|
| Player units | 0x0202BD50, 0x48 each, 62 slots (enemies 0x0202CEC0, 50) |
| unit +0 char ptr, +4 class ptr, +8 Lv, +9 Exp (255 = --), +0xB index, +0xC state (0x4 dead, 0x8 not deployed, 0x1 hidden) | |
| +0x10 x, +0x11 y, +0x12 max HP, +0x13 HP, +0x14 Str, +0x15 Skl, +0x16 Spd, +0x17 Def, +0x18 Res, +0x19 Lck | |
| +0x1A Con bonus, +0x1B rescued unit index, +0x1D Move bonus, +0x1E items 5 x u16 (id, uses << 8) | |
| +0x28 weapon ranks: sword lance axe bow staff anima light dark (E 1, D 31, C 71, B 121, A 181, S 251) | |
| +0x30 status (low nibble), +0x32 support points, one per partner (C 81, B 161, A 241) | |
| Chapter data 0x0202BBF8 | +0 play time (frames), +8 funds, +0xE chapter, +0x10 turn, +0x1B mode (1 Lyn, 2 Eliwood, 3 Hector), +0x20 tactician name |
| Convoy 0x0203A720 | 100 x u16, packed from the start |
| Battle struct 0x0203A3F0 | unit copy, then +0x5A Atk, +0x5C Def, +0x5E AS, +0x60 Hit, +0x62 Avoid, +0x66 Crit, +0x68 Dodge; valid for the unit on the game's stat screen (the pack uses it when the char ptr and items match, else base formulas) |

## ROM (Europe)

| What | Where |
|---|---|
| Text: Huffman tree base 0x08C34E30, root via 0x08C3979C, table 0x08C397A0 (English; Spanish +4810, Italian +9620) | decoder at 0x6C0 (ARM): LSB first, leaf = bit 31, two chars per leaf when the high byte is set; 0x01 newline, 0x1F ignored |
| Characters 0x08CA3EC8, 0x34 each | +0 name, +4 id, +5 class, +6 portrait u16, +9 affinity (1 Fire .. 7 Anima), +0x13 Con (s8), +0x1C growths, +0x28 abilities (0x4000 female), +0x2C support data (7 partners, 7 start values, 7 growth, count at +0x15) |
| Classes (pointer from the unit) | +0 name, +0x11 Con, +0x12 Move, +0x13.. caps HP Str Skl Spd Def Res, +0x28 abilities (0x1 mounted, 0x40 +15 crit) |
| Items 0x08CA92DC, 0x24 each | +0 name, +7 type, +8 attr (1 weapon, 2 magic, 4 staff, 8 unbreakable), +0x14 uses, +0x15 Mt, +0x16 Hit, +0x17 Wt, +0x18 Crt, +0x19 range (min << 4 / max), +0x1A cost per use, +0x1C rank, +0x1D icon |
| Item icons 0x081E5190, 0x80 each (2 x 2 tiles) | palette 0x081EB190 for items; 0x081EB1B0 for weapon-type (0x70 + type) and affinity (0x79 + affinity) symbols |
| Portraits 0x08D5D634, 0x1C each | main sheet (LZ77, 256 x 32), mini (LZ77, 32 x 32), palette; face = 6 blocks of the sheet (art/layout.py BLOCKS) |
| Chapters 0x08D612B0, 0x98 each | +0x70 title (Eliwood mode), +0x72 title (Hector mode), +0x8C objective, +0x8E short goal |

Aid: mounted (25 - Con, female 20 - Con), else Con - 1. Con = class + char (s8) + unit bonus.

## Open

- Device check; US / Japanese releases; Spanish / Italian text when the game runs in those languages.
- Support / tactician bonuses for units the game hasn't put in its battle struct (shown "Before support bonuses").
- B / W / L battle record (the game's Personal data footer) not mapped.
- A map page (the chapter map with unit positions) would be a good next page.
