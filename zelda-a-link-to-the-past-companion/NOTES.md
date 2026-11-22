# A Link to the Past (GBA) companion: notes

USA cartridge (`AZLE`), v0.1.0, 2026-11-21, read-only (formatVersion 2), not device-tested. The user's save (an EU
.sav, early game: Boomerang, Lamp, 4 hearts) loads on the US ROM.

Pages: Items (the GBA item screen: grid, picked item, pendants, DO row, equipment; tap an item for a line about it),
Status (hearts, magic, bombs / arrows with upgrades, rupees, heart pieces, keys, sword / shield / mail),
Map (the Light World picture from the game's L map screen: its affine BG2 texture, 64x64 8bpp tiles at VRAM
0xC000, cut to 352 px; Link's dot from IWRAM 0x03003838 / 0x0300383C (overworld px), indoors flag 0x0300389E keeps the
last outdoor spot; px / 12.8 + (97.6, 114.4) on the texture, checked at the Sanctuary and at the castle's north-east
corner against the game's own map), Dungeons (map / compass / big key per dungeon, pendant or crystal; Dark World names stay hidden until something from
that dungeon is found).

## RAM (EWRAM 0x02002320, the save block)

+0x00..0x17 the item grid in screen order (Bow 1-4, Boomerang 1-2, Hookshot, Bombs = count, Mushroom 1 / Powder 2,
Bottle 1, Fire Rod, Ice Rod, Bombos, Ether, Quake, Bottle 2, Lamp, Hammer, Flute 2-3, Net, Book, Bottle 3, Shovel,
Somaria, Byrna, Cape, Mirror 1-2, Bottle 4; bottles 1 Mushroom, 2 empty, 3 red, 4 green, 5 blue, 6 fairy, 7 bee,
8 good bee). +0x18 gloves 1-2, +0x19 boots, +0x1A flippers, +0x1B moon pearl, +0x1D sword 1-4, +0x1E shield 1-3,
+0x1F mail 0-2. From +0x20 the SNES layout ($7EF360..): u16 rupees, +0x24 / 0x26 / 0x28 u16 compass / big key / map
(bit 14 Hyrule Castle, 13 Eastern, 12 Desert, 11 Castle Tower, 10 Swamp, 9 Darkness, 8 Mire, 7 Skull, 6 Ice, 5 Hera,
4 Thieves, 3 Turtle Rock, 2 Ganon's Tower), +0x2B heart pieces, +0x2C max HP (x8), +0x2D HP, +0x2E magic (128),
+0x2F keys, +0x30 / 0x31 bomb / arrow upgrades, +0x34 pendants (bit 0 red, 1 blue, 2 green), +0x37 arrows,
+0x3A crystals, +0x3B magic use. Item bytes checked one by one on the game's item screen.

## Art

assets/icons: cut from the game's item screen in the emulator (the item graphics are LZ77 at ROM 0x27D658 and the
icons use flipped tiles, which gfx.decode / gfx.sprite can't draw from compressed data). Same choice as the Minish
Cap pack. assets/ui: the pack's own hearts, pieces, crystals, dungeon marks, nav plates.

## Not done

Device check; the equipped A-button item (not found); the Dark World map (world flag not found yet); small keys per dungeon;
Four Swords; EU / JP releases.
