# Harvest Moon: Friends of Mineral Town (US, A4NE) companion - v0.1.0 (started 2026-11-22)

Pages: Farm, Pack (rucksack), Barn (chickens + cattle/sheep), Shipped (Memo). See "Update" at the end for the 2nd-pass addresses.

Status: partial. Two pages (Farm, Chickens). Offline run against the real RAM dump and the real-engine preview
are clean; NOT device-tested. Reference screenshots of the game's own menus are in art/ref/ (yellow dotted
paper windows, tan border, pixel font; menu tabs Diary, Rucksack, World Map, Farm Map, Earnings, Memo, Tutorial).

## How to reproduce
ROM + save from ~/Downloads/rom (harvest-moon-friends-of-mineral-town.3592.sav, gold 617271, spring 1).
art/base.steps: title -> Continue -> Data 1 -> Yes -> field. START opens the menu, R cycles tabs, A opens one;
Earnings and Memo pages scroll with R/L. Time does not pass indoors (go through the door at the bottom left).

## RAM (the save block sits byte for byte in EWRAM: RAM = 0x02004DE0 + save-file offset)
| What | Address | Proof |
|---|---|---|
| Farm name (16 B) | 0x02004E20 | RAM scan, matches sav 0x40 |
| Gold u32 | 0x020068B4 | written, Earnings screen shows it |
| Player name | 0x020069E4 | sav 0x1C04 |
| Chicken record i | 0x02005240 + 0x30*i (8 chickens in this save, verified by scrolling the game's list) | |
| +0x10 u16 | age / birthday, not decoded (written FF: 2yr Winter 16) | |
| +0x12 s16 | affection. hearts = count of {3,7,10,13,15,18,20,23,26,28,31} <= (value+32); fitted on 13 written values (E4=1, E8=2, EA=3, ED=4, F0=5, F4=7, F8=8, FA=9, FD=10, FF=11), thresholds between samples are guesses | writes + Earnings screen |
| +0x14 u8 | health, 0x1F healthy, 0xFF shows Sick | written |

Other things seen in the save, not wired up: livestock array stride 0x3C from 0x654 (cows and sheep interleaved,
Bessie, Wooly, Jennifer, Peppy, Moomoo, Baaba), dog Spunky at 0x1CA4, horse Speedy near 0x5C, villager table from
~0x1D30 (bit packed), a u32 table from 0x1AE8 (pairs 900 / total, per item, maybe shipping earnings).
ROM: item names + descriptions are ASCII at 0xE96B0-0xED000 (name stored twice, then description), 206 names.

## Not found yet
- Clock / date / season / weather (HUD): a byte diff over 6:00 -> 7:00 outdoors is too noisy. 0x020068B8 (=3) and
  0x020068BC (=1) are NOT the day (writing them did nothing to the HUD).
- Rucksack tool / item ids and counts, shipped counts (Memo "Number shipped"), villager hearts (wife Popuri has 12),
  stamina berries (Jack 4), fishing records, Harvest Sprites, cattle / sheep fields.
- Pages planned from the game's tabs: Rucksack (tools + items grid), Earnings (family + animals + sprites),
  Memo (shipped / fishing / records), World Map with the player marker.

## Writes (formatVersion 3, memory-write)
addGold(n) (capped 999999), heal(i), maxHearts(i). Gold write replayed in the harness (screen shows the new value).

## Update: rucksack, shipping, livestock (same day, all checked by writing values and screenshotting the game)
| What | Save offset (RAM = 0x02004DE0 + it) | Notes |
|---|---|---|
| Sickle slot | 0x1C60 u16 | tool id |
| Tools x8 | 0x1C8C u16 each | tool id = 0x100 + index in ROM table 0x080EAB0C (12 bytes per entry, name pointer first); ids 0x100-0x150 (seeds, brush, milker, bell, teleport stone, gems are tools) |
| Items x8 | 0x1C68, 4 bytes each | byte1 = item id (ROM table 0x080EDCD8, 16 bytes per entry, 171 entries, id >= 171 shows empty), byte0 bit0 = gift wrapped, other byte0 values (e.g. 0xE5 here) show a blank slot; counts do not exist (no stacking). The save's single item here is such a junk slot, so the rucksack items are empty |
| Shipped | 0x84 u32 x 103 | bit31 = seen (Memo hides unseen rows), low bits = count. Order is the Memo's own list (names in main.lua `SHIP_NAMES`, read off the game screen with all 103 flags forced on), NOT item id order. Entries from 103 on are other data |
| Livestock x8 | 0x654, 0x3C each | name12, +0x10 u16, +0x12 s16 affection (same hearts table as chickens), +0x14 health. Cow vs sheep: byte +0x30 is 01 / 03 mostly but not always (Baaba, Beeba) so species is not shown |
| Water can squares | byte 0x1C4B | 0x10 shows 32 squares, 0xFF shows 254 |
| Jack's berries | 0x1C48..0x1C4B | probe only: zeroing changes the apples on Earnings page 1, not decoded |
| Dog Spunky | name 0x1CA4, hearts bytes 0x1CB4 | hearts scale not decoded |
| Villager friendship | around 0x1D30-0x1DB0, bit packed | wife Popuri has 12 hearts; not decoded |

Probe method used: /tmp/hm/probe.py fills save chunks with 00/FF and image-diffs the game's menu screenshot; bisect 0x100 -> 4 bytes.

## Still open
World Map and Farm Map (no map / position address found, the screens are images drawn by the game), Earnings Harvest Sprites,
Memo Fishing and Other (records), villager hearts, Jack's berries, dog / horse hearts, the clock. Not device-tested.

## Design pass (2026-11-22): maps and the missing pages
Pages now: Farm (clock, gold, family), Pack, Barn (Chickens / Cattle / Sheep / Sprites tabs), Maps (Town / Farm), Memo (Shipped / Fishing / Records).
Everything marked `DESIGN` in main.lua is sample data (clock, family, sprites, fishing, records, income, map markers); addresses to find later.
**Map images**: the ROM has no raw or standard-LZ77 copy of them (scanned: only a few dozen tiles match, no LZ77 block). Both maps are tile layers in VRAM while the
menu screen is open, so assets/ui/map-world.png (240x104) and map-farm.png (512x352) were rendered from the VRAM dump of those screens (BG3 + BG2 for the town,
BG2 + BG1 + BG0 for the farm, `/tmp/hm/bgr.py`): no markers, no clock panel. The farm picture shows this save's fields at capture time, so it is a static backdrop.
Markers (you, Spunky, Speedy, farm position) are OAM sprites in the game; their screen xy can be read from OAM / the game's map code once found.
Display regs on the World Map: DISPCNT 0x7F40, BG0..3 CNT 1F4C 1C48 1D40 1E40; Farm Map: DISPCNT 0x1E40, BG0..2 CNT D440 D840 DC40 (512x512 each).
Shadow OAM lives at 0x02002820 (rebuilt every frame, writes to it or to real OAM did not stick).
Cattle/sheep split uses byte +0x30 (3 = sheep) and is wrong for Baaba/Beeba in this save.

## Game icons from the ROM (2026-11-22)
All icons are drawn at run time with `gfx.decode` from the player's ROM (US A4NE only; other releases fall back to the drawn PNGs in assets/ui). Nothing of the game's art is shipped
except the two map pictures (see above). `icons.lua` holds only ROM offsets (tile data + 16-colour palette), found by driving the game:
- tools: id 0x100-0x150, shown in the Rucksack BG1 tilemap (2x2 tiles, palette bank per slot) -> `art/tools/iconscan.py tools`
- items: id 0-170, 16x16 OBJ sprites in the Rucksack items panel -> `iconscan.py items`
- shipped list (Memo): the same icon bank, one run per entry with only that entry unlocked -> `shipscan.py`
- portraits: Earnings pages (Jack, Popuri, Spunky, Speedy, chicken, cow, sheep, sprites), heart (8x8 BG tile) and berry; map markers from the World Map OAM -> `pagespr.py`
No pointer table into the icon bank exists in the ROM (searched as absolute, relative and by item-table field), so the offsets are a lookup table of observed values; the item table's
third / tool table's middle field increases with the icon address but is not an index.
Still drawn by hand: crown, gift fallback, fish, nav-bar icons, empty heart (recoloured from the real heart). `art/build-overview.sh` rebuilds the overview (preview data uses `gfxmock`; keep `assets/_preview` out of the zip).
