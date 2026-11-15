# Pokemon Unbound companion: what is mapped

Game: Pokemon Unbound 2.1.1 (BPRE, CRC d8900587), a FireRed ROM hack on CFRU. Checked against a saved state of the
player's own save (Pokemon League, party Absol / Gallade / Greninja / Tapu Lele, all Lv 100) and the ROM.

## RAM (same as FireRed unless noted)

| What | Address | Checked |
|---|---|---|
| Party count / party | 0x02024029 / 0x02024284, 100 bytes each | yes: names, levels, HP |
| Party Pokemon data | +0x20, **plain** (no XOR), fixed order Growth, Attacks, EVs, Misc | yes: species 376/528/766/1003, moves and PP match the game's Moves page |
| SaveBlock1 / SaveBlock2 pointers | 0x03005008 / 0x0300500C | yes |
| Money | SB1 + 0x290, key 0 (no XOR needed) | yes: 999,997,299 |
| Trainer name, ID, play time | SB2 + 0x00, 0x0A, 0x0E (hours, minutes) | yes: Kadhem, 48855, 999:59 |
| Badges | SB1 + 0xFE4 (8 flags) | yes: 0xFF at the Pokemon League |
| Bag | **EWRAM, not SB1**: Items 0x0203BB20 x450, Key 0x0203C228 x75, Balls 0x0203C354 x50, TMs 0x0203C41C x128, Berries 0x0203C61C x75; { u16 item, u16 qty }, qty plain | yes: Key Items matches the game (TM Case, Berry Pouch, ADM, ...) |
| Map header / player object | 0x02036DFC / 0x02036E38 | yes: map section, layout 31x34, coordinates |
| Map section -> name | 0x58 + index into the pointer table at ROM 0x3F1CAC | name matches the Pokemon League |

## ROM tables (the pointer table after the header, read by art/extract-unbound.py)

species names 0x144 (11 bytes, species ids 1-1293), move names 0x148 (13), base stats 0x1BC (0x1C each, read live),
ability names 0x1C0 (17), items 0x1C8 (0x2C each), battle moves 0x1CC (12 each; Hypnosis accuracy 60 is right here, the
table at ROM 0x900000 is an unused FireRed copy). National dex numbers: u16 table at ROM 0x1A41FEC (species - 1).
Species ids 1-251 and 277-411 are the Gen 3 order; Gen 4+ come after (Gallade is 528, dex 475).

## Wide / XL view (game.lua + entities.lua)

game.lua is FireRed's wide view (Unbound keeps its map header, player object, backup map layout and metatile counts,
all checked) without the Ambient look. entities.lua gives the margins their NPC and trainer markers:
- **Live objects** from gObjectEvents (0x02036E38, 16 x 0x24) and gSprites (**0x0202063C**, found by matching the NPCs'
  sprite positions against their tiles: 8 of 8 in the Pokemon Center). Unbound repointed its graphics tables, so the
  sprite is read from the live sprite itself: its frame table (Sprite.images), its size from the OAM shape / size
  (Unbound's NPCs are 32x32) and its colours from the live OBJ palette (0x05000200 + bank * 32). The frame follows the
  facing (south / north / west, east is the west frame flipped).
- **Objects beyond the loaded area** get no marker: the game is not simulating them, and their sprites cannot be
  looked up (Unbound repointed its graphics tables), so a placeholder is not drawn either. (The ROM event table parses
  fine, 0x18-byte layout, if sprites are ever resolved.)

## The white dot at the screen's corner

A 16x16 white round sprite (dark outline) that Unbound's own code keeps at screen pixel (8,8), drawn above everything,
in every map I looked at (League courtyard, an ice cave, the Pokemon Center). In gSprites it is the sprite whose
template is ROM 0x09FB32A0 (callback 0x09EB9C1B, both in the hack's added ROM area); I do not know what it is for.
game.lua hides it only while the Wide view is showing (struct Sprite byte 0x3E bit 2 = invisible, written from frame(),
needs the memory-write permission) and shows it again when Wide stops. Checked offline with a state saved on the device.

## Hint for the Pokedex flags

The game's Continue screen shows **Pokedex 809** for this save. A search for a 905-bit array with exactly 809 set bits
found nothing outside SaveBlock1's 0xFF-filled bag area, so the flags are stored in some other shape.

## Not mapped / not verified

- **Pokedex**: the dex flags are not at FireRed's SB2 offsets and I did not find them; the Dex page is removed.
- **Hidden abilities**: ability is read as base ability 1 or 2 (IV word bit 31). CFRU also has hidden abilities; where
  that flag lives is not found, so a hidden-ability mon may show its normal ability.
- **Battle** (gBattleMons 0x02023BE4, buffers, cursors): read-only and **not yet checked in a live battle**. The battle
  buttons are off because they write the engine's controller state at FireRed's addresses.
- **Badge names and art**: generic "BADGE 1-8" (Unbound's gyms are not Kanto's).
- Wide view (game.lua) is FireRed's and untouched.
- No memory-write permission: the pack never changes the game.

## Offline check

`lua` harness (scratchpad lh/run.lua) runs main.lua against a state file and the ROM and dumps update()'s table.
