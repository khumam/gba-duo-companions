# Pokémon Emerald Seaglass companion: notes

v0.1.0, read-only (`permissions` is empty, nothing writes to RAM). Built for **Emerald Seaglass v3.0**
and matching that ROM only. Skeleton, page ring and font are adapted from
[`pokemon-emerald-companion`](https://github.com/khumam/gba-duo-companions) in the same repo.

## The build this pack matches

| | |
|---|---|
| header title | `POKEMON EMER` |
| game code | `BPEE` |
| CRC32 | `14465A33` |
| SHA-1 | `b9f4d332d30fc88c379f9e037f9eae3b2755ead4` |
| size | 16 MiB |

`manifest.json` matches `BPEE` **and** that CRC32, so another Seaglass release (v2.x, a translated
patch, a randomizer run) will not load it rather than showing wrong numbers. There is also a runtime
check of the tables themselves: if `species 1` is not `Bulbasaur`, `move 1` not `Pound` or the item
names are empty, the screen says `THIS SEAGLASS BUILD ISN'T MAPPED YET` instead of drawing garbage.

## What the pack reads

SaveBlock1 / SaveBlock2 are found at run time, not hard-coded: the pack scans IWRAM for aligned
EWRAM pointers, then validates each candidate by decrypting the party in SaveBlock1 (per-mon
checksum with that mon's own `personality ^ otId` key) and by checking SaveBlock2's name, gender,
hours and `money ^ encryptionKey`. Both blocks are re-validated every tick, so a save loaded after
the pack starts is picked up.

| data | where |
|---|---|
| party | SB1 + 0x234 (count), mons from 0x238, 100 bytes each |
| money | SB1 + 0x040 `^` SB2 + 0x0AC |
| coins | SB1 + 0x034 `^` (key & 0xFFFF) |
| play time | SB2 + 0x00E hours, +0x010 minutes |
| trainer | SB2 + 0x000 name, +0x00A id, +0x008 gender |
| bag | SB1 + 0x560 / 0x6A0 / 0x740 / 0x790 |

The live party is a separate EWRAM array, so the pack scans one 64 KB slice of EWRAM per tick for a
mon whose level and species match the save-block lead and whose checksum passes; until it finds one it
draws the save-block copy (`DIAG` page shows which one is in use). That is why HP on the party page
can move without saving.

### Seaglass reshaped the bag

Emerald's five pockets (30 / 30 / 16 / 64 / 46) are gone. Seaglass's bag is **80 items, 40 key items,
20 balls, 46 TMs/HMs**, in that order from 0x560, and the four pockets exactly fill the 186 slots to
0x848. That was confirmed against the save: the first key item, the first ball and the first TM each
land on the first slot of the next pocket. Berries are ordinary items here, so there is no berries
pocket.

### ROM tables (file offsets; the cart address is +0x08000000)

| | |
|---|---|
| species | `gSpeciesInfo[1].speciesName` at 0x8F087C, stride 0xD0, struct starts 0x2C earlier |
| | stats +0x00 (HP, Atk, Def, Spe, SpA, SpD), types +0x06/+0x07 (classic ids + 1, 19 = Fairy), catch rate +0x08, exp yield +0x0A, gender +0x12, friendship +0x14, growth +0x15, abilities +0x18, category +0x1F, name +0x2C, height +0x3E, weight +0x40, dex text ptr +0x4C, front pic +0x58, palette +0x68 |
| moves | `gMovesInfo[1]` at 0x6D2A18, stride 0x38: name ptr +0, description ptr +4, packed word +0x0A (`type = w & 0x1F`, `power = ((w >> 9) & 0x7F) * 4`, `accuracy = (w >> 16) & 0xFF`), PP +0x0E |
| items | `gItemsInfo[0].name` at 0x67E77C, stride 0x54, 14 inline name bytes, description pointer 8 bytes before the name |
| abilities | `gAbilitiesInfo[0].name` at 0x6E15B0, stride 0x1C |

Sprites are drawn from the ROM at run time: `gfx.decode{ tiles = front pic, palette = species palette,
width = 64, height = 64, lz77 = true }`. Both the front pic and the palette are LZ77-compressed in
this ROM (verified by decompressing them to PNG while building the pack).

## Pages

Party, Detail, Bag, Trainer, Dex, Diag, in a ring (the bottom bar steps through it). Battle and the
Wide/Map view are not in this version.

- **Dex is a browser, not a caught list.** Seaglass moved the Pokédex flags out of the vanilla
  offsets and none of the candidate locations could be confirmed against this save, so the page lists
  all 386 species 6 at a time with `</>` paging and a tap-selected entry panel (stats, abilities,
  category, height/weight, base stat total, ROM dex text). Guessing the flags would have produced a
  wrong "caught" list, which is worse than no list.
- **No item prices.** The price field in this build's item struct could not be located with
  confidence, so the bag inspector shows name, description and count only.
- GBC styling: cream windows with a heavy slate frame, a sea-green striped backdrop, coral accents,
  Jersey 10 for text; type chips are drawn in CSS from the ROM's type ids.

## Verified, and how

- `main.lua` parses as Lua 5.4 and **runs**: `tools/mock.js` executes `update()` under Lua 5.4
  (wasmoon) with the user's ROM and save mapped into memory (SaveBlock1 at 0x02025000, SaveBlock2 at
  0x02024000, a live-party copy at 0x02030000, decoy pointers in IWRAM). It finds both blocks, picks
  the live party, and returns the expected values for all six pages: six party members with correct
  names, levels, HP, types, natures, abilities, moves and PP; money 53,224; 17:50; trainer `Emerald`
  / 21260; bag 79 slots; dex pages and entry text.
- Sprite decoding was checked by dumping the same tiles and palettes to PNG (`tools/sprites.py`);
  the images are the real Seaglass front sprites.
- `layout.json` is generated by `art/layout.py`; every class it uses has a rule in `style.css`, and
  every screen was rendered to HTML (`tools/render.js`) at 538 x 468 dp with the real data: no
  container overflows, no broken images.

## Not verified

- **Nothing has been run on a GBA Duo.** The engine sandbox is simulated with the same `mem` /
  `gfx` surface, so instruction and time limits, the real `gfx.decode` behaviour and touch on the
  device are untested.
- `gfx.decode`'s `lz77` flag is documented for tile data only; that it also decompresses the
  palette is assumed. If it does not, sprites are skipped (`pcall`) and the party rows fall back to
  type chips, and the Diag page shows `SPRITE ERR`.
- The party scan assumes the live party sits within the first 256 KB of EWRAM and that its lead mon
  keeps the level and species it had at save time. If the lead levelled up, the scan waits for a
  matching mon; the save-block copy is drawn meanwhile.
- Badge flags (0x867-0x86E in the flag array) are carried over from Emerald and were checked only on
  a save with **no** badges, so the "earned" count is unconfirmed above zero.
- Item descriptions read at `name - 8` give correct text for every item sampled (Potions, TMs, key
  items), but the pointer was not verified for all 800+ entries.
