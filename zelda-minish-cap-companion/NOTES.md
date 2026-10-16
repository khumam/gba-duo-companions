# The Legend of Zelda: The Minish Cap companion — build notes

Sources: the [zeldaret/tmc](https://github.com/zeldaret/tmc) decompilation
(`include/save.h`, `include/player.h`, `include/item.h`, `include/area.h`,
`linker.ld`, `src/gameUtils.c`, `src/itemUtils.c`) and samurai goroh's code guide,
http://www.erick.guillen.com.mx/Codes/GBA%20The%20Legend%20of%20Zelda%20Minish%20Cap.txt.

- **One struct.** Everything the save file holds is `gSave` at `0x02002A40`, the
  same address in the US, EU and JP builds (`linker.ld` puts it outside the
  version `#if`s). The guide's addresses all land on its fields: rupees
  `0x02002B00` = gSave + 0xA8 (stats) + 0x18, A/B items `0x02002AF4/5`, bottles
  `0x02002AF6-9`. No Harvest Moon-style "stages".
- **Not loaded yet.** On the title screen and file select `gSave` holds leftovers,
  so `update()` returns `ready = false` until the file is initialized, not invalid,
  and has 3-20 whole hearts.
- **Inventory** is 2 bits per item id from gSave + 0xF2 (`GetInventoryValue`);
  non-zero = owned.
- **Dungeon items** bits are 1 = map, 2 = compass, 4 = big key (`HasDungeonMap`,
  `HasDungeonCompass`, `HasDungeonBigKey`); the guide agrees. Dungeon ids 1-6 are
  the `LVn_CLEAR` global flags (flag n + 1). Id 6 = Dark Hyrule Castle is a guess.
- **Location** reads `gRoomControls.area` (`0x03000BF4`); "you are here" uses
  `gArea.dungeon_idx` (`0x02033A93`) when the area has keys.

Not checked on a device yet:

- **Kinstone bag.** The decomp puts the counts at `0x02002B6B` (types[19] then
  amounts[19]); the guide says `0x02002B6A`. The script follows the decomp. The
  colour of each piece id past the gold ones (6E-75) is the usual split
  (3 red, 2 blue, 3 green) and isn't confirmed; each card shows its raw id.
- **File name** is read as ASCII; the game may use its own character table.
- **Figurines** count the set bits of gSave + 0xD0 (36 bytes).
