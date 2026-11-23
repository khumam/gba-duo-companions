# Mega Man Battle Network (USA, AREE) companion: notes

v0.1.0, started 2026-11-22. Built with the skill's harness from `~/Downloads/rom/Mega Man Battle Network (USA).gba` and a late save (LV 100, 30-chip folder).
**Not device-tested** (previews with the real engine, and writes replayed in the headless harness only).

Pages follow the PET menu: Folder, Library, MegaMan, Email, Items, Network (`art/ref/menu*.png` are the reference screens; Save and Return are not pages). Look: slate title bar, parchment list with
stripes, orange note frame, green cursor, `#4A5A63 / #313939 / #FFF7CE / #EF8452 / #21AD10` sampled from the game.

## RAM (EWRAM)
| What | Address | Notes |
|---|---|---|
| Zenny | `0x02000284` u32 | |
| Folder | `0x020001C0`, 30 x (id u8, code u8) | code 0 = A ... 25 = Z |
| Library / sack | `0x020002CF + id` u8 | `0xFF` = never seen (Library lists the others; count = sack copies). Checked: Library #61 = Drain2 |
| MegaMan HP | `0x0200022C` u16 | what the MegaMan page shows |
| ATTACK / RAPID / CHARGE | `0x02000224..226` u8, 0-4 (5 pips) | writes checked on the game's screen |
| Armor | `0x02000227` u8 | 0 none, 2 Heat, 3 Aqua, 4 Wood (1 and 5 draw garbage) |
| Received mail order | `0x02001FA0` u8 ids, oldest first, `0x40` = empty (the Email list shows it newest first) | ids 0-32 |
| Key items | `0x020002D0 + id` u8 count (1 = owned, charge items hold their charges: IceBlock 4) | ids 0-63 are the Items screen; ids 64+ are HP memories / armors, not listed |
| Battles W / L | `0x020003E6` / `0x020003E4` u16 | link battles only, found by filling bytes and reading the Network screen |
| Network "Chips" | not stored: sum over 200 sack records at `0x020004B0 + 16 k` of `id + 5 counts` (bytes 0-5) | matches 7820 on the save; checked per record by zeroing it |
| LV (display) | not stored | the game shows `64 + 3 x (attack + rapid + charge)` capped at 100 in every test; HP did not change it. Base 64 may depend on something not found |

## ROM
| What | Address |
|---|---|
| Chip names | u16 offsets at `0x0869D57C` (256, offset from the table), `0xE7` ends a name |
| Descriptions | same shape at `0x0869E310`; `0xE8` = line break, `0xE5 xx` = punctuation (00 `!`, 02 `?`, 09 `&`, 0A `'`, 12/16 `:`, 14 `,`, 18 `/`, 1D `(`, 1E `)`, 3D `=`) |
| Charset | space 00, digits 01-0A, `A` 5F...`Z` 78, `a` 79...`z` 92, `-` 5E |
| Chip data | `0x08007D7C + 28 x id`: +0 u16 attack, +4 icon ptr (16x16 4bpp), +8 picture ptr (64x56, 8x7 tiles), +12 palette ptr, +16..20 five codes |
| Library order | the Library screen builds it in RAM at `0x02015000` (177 ids); copied into `main.lua` (`ORDER`); its source in the ROM not found (probably LZ77) |
| Mail | header table u16 at ROM `0x087A7F48` ("Sender    Subject", sender 10 chars), bodies at `0x087A83C8` (u16 offsets, ids 0-32 align). Body = script: `F2 xx` starts text, `EB` ends a page, `E9` 2 / `ED` 3 / `F3` `FA` 1 argument bytes, `FB 00 00 00` = player name, other `E4-FF` pages (rewards) are skipped |
| Key item text | names u16 table at ROM `0x0869FD50`, descriptions at `0x086A0118` (prefix `FC 0C F5 00 EC 00 00 F2 02`, ends `EA FF`); `E5 2C` = `@`, `E5 0B`/`0C` = `(` `)`; charge items end `(charges left:N)` with a live N |
| Punctuation fixed | `E5 16` is `.` (not `:`), `E5 36` is `:`, `E5 03` is a quote mark; checked against the Email and Items screens |

## Interactive
Tap a Folder row: card with picture, attack, description. Tap a **code pill** to change that slot's code (only the chip's own five codes). Tap a Library row for its card and sack count.
Email: tap a mail, flip its pages with the arrow buttons (the game shows 3 lines per page). Items: tap an item for its text. Network: Trade / Battle rows need a link cable, tapping one only shows the game's purpose; Chips and the W/L record are live.
MegaMan page: tap a pip to set ATTACK / RAPID / CHARGE, tap an armor to wear it. All writes go through `memory-write`.

## Open
- Stars after names in the Library (rarity), chip element icon.
- Mail read marks (not shown by the game), writing key items (counts) and the W/L record (not offered: story flags).
- Real max HP (the page shows current HP), HP memories.
- Folder editing from the sack (code of sack chips not known), battle page.
- LV formula, see above.
