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

## 2.0.0 — pause-menu redesign

Checked on the AYN Thor (EU ROM, early save):

- **Map position.** `gRoomTransition.player_status` (IWRAM `0x030010A0` + `0x0C`):
  `overworld_map_x/_y` at `0x030010C0/C2`, the spot the pause menu draws Link at
  (`pauseMenu.c`: `x * 160 / 0xF90`, `(y << 7) / 0xC60`), so the world map spans
  0..0xF90 x 0..0xC60. Minish Woods read 3442, 3072. It reads 0, 0 on the title and
  file select (`onMap` = false hides the marker), and only changes on a room change,
  not while walking inside one. `dungeon_map_x/_y` (`0x030010BC/BE`) is returned but
  not drawn yet.
- **Map hints.** `gSave.map_hints` (`0x02002A60`, u16): one bit per destination Ezlo
  marks on the pause map; hint #0 was set. Where each bit points comes from a ROM table
  (`gUnk_08128F58` in the US build), not found in the EU ROM yet, and what each hint
  means isn't documented.
- **Item icons** (`assets/icons`, mapped in `item_names.lua`): from the Zelda Dungeon
  wiki. None there for Fire Rod, Grab or Butter; Hyrule Map uses the dungeon map's icon;
  the tiger scrolls share one icon, and so do the three butterflies. Item 0x05 ("Sword")
  as the Picori Blade and the order of the three library books are guesses.
- **Taps.** Gear and quest items set `ui.itemName`; `main.lua` marks the match
  `selected` through the global `ui`.

Images: `assets/img/map-placeholder-6.png` is built from `map-placeholder.png` by
`art/map_placeholder.py` (run it again after editing the placeholder).

## 3.0.0, Minish-OS redesign

`main.lua` keeps every address above and returns the new layout's shape (see
`preview-data.json`). Checked on the AYN Thor (EU ROM, early save, Minish Village):
rupees 4/100, A = Small Shield, B = Smith's Sword, 0 kinstones, no dungeons cleared,
Link's marker in Minish Woods.

- **Map art follows the game's geography** (`art/minish-os.mjs`, `TERRAIN`), so the
  overworld position (x / 0xF90, y / 0xC60) lands on the right terrain. Dungeon marks
  and the MINISH view's portals are placed by hand on that art, not read from RAM.
- **Ezlo's hint** is generated from what the script reads (health, bombs, dungeon,
  next uncleared dungeon); the game keeps Ezlo's real lines in ROM text.
- **Kinstone alert** (`kinstone.ready`) stays off: no RAM flag for "an NPC nearby can
  fuse" has been found yet.
- **Engine:** write `flex: 1`, not `flex: 1 1 0`. The engine's `flex` shorthand
  rejects a unitless 0 basis and drops the whole declaration (browsers accept it).
- **Live position.** `overworld_map_x/y` only refreshes on a room change
  (`gameUtils.c` `UpdatePlayerMapCoords` copies `gPlayerEntity` x/y into it, overworld
  areas only). In an overworld area (`gArea.areaMetadata` bit 0, `AR_IS_OVERWORLD`) Link's
  entity position is already in the pause map's units, so `main.lua` reads
  `gPlayerEntity` (IWRAM `0x03001160`, x/y high halves at `+0x2E`/`+0x32`) live there and
  falls back to the stored spot elsewhere. Checked on the Thor that the address tracks Link
  (Minish Village, area flags 0x00: 520,992 -> 555,872 after walking up and right). In Minish
  Woods (an overworld area) the map tracks him live: walking north moved him from
  3890,3071 to 3900,2902.
- **World map from the ROM.** The MAP panel shows the game's own pause-screen world map,
  built at runtime from the player's ROM with `gfx.tilemap` (app feature), so the pack
  ships none of it. Found by saving a state on the pause map screen: BG1 (char base
  0x0000, screen base 0xE000, palette banks 6-12) holds the whole map, every region, and
  its tiles, tilemap and palettes are stored raw in the ROM. EU (BZMP) addresses: tiles
  `0x08931DB0`, tilemap `0x08935DB0` (32 wide, the map is cells 5-24 x 1-16 = 160 x 128),
  palette banks 6-12 at `0x085B39D0`. Rebuilt from the ROM it matches the pause screen
  pixel for pixel; checked on the Thor. US/JP addresses come from the zeldaret/tmc
  decompilation (gGfx_94_0, gGfx_94_1, gPalette_2224; `assets/gfx.json` lists the US
  address and EU/JP offsets) and are in `rom_gfx.lua`; not checked on a US/JP ROM. An
  unknown release (or a hack with a new game code) falls back to the drawn map
  (`assets/ui/map-terrain.png`).
- Dungeon markers were moved to match the game's map (they were placed for the drawn one).
- **Item icons from the ROM.** Every item, quest item, element, tiger scroll, charm,
  bottle and gear icon is the pause screen's own sprite, drawn at runtime with
  `gfx.sprite` (app feature) in `rom_gfx.lua`. Item id -> `gSpriteAnimations_322[id]` ->
  frame -> `gSpriteFrames_322[frame]` first tile in `gSprite_082E68F4`, plus the frame's
  object list in `gFrameObjLists` (sprite 0x141 EU, 0x142 US/JP). Palette bank: absolute
  `high >> 4` when the object's flags bit 0 is set, else `3 + (high >> 4)` (the pause
  menu's base). The ammo counter object (flags 0x40 at -1,-4, tile 0) is skipped. All 75
  icons rebuilt from the EU ROM matched a reference render of the same data; on the Thor
  they match the pause screen.
- **Heart piece.** The Quest Status container, one 32x32 sprite per 0-3 pieces at
  `gGfx_91_2 + 0xC00 + pieces * 0x200`, palette `gPalette_2219` bank 0. Found on the EU
  screen at 2/4.
- **Still the pack's own art** (`assets/ui`, drawn in `art/minish-os.mjs`): kinstone pieces
  (their sprites use palettes set up at runtime per fusion), figurines, butterflies,
  Hyrule Map, Jabber Nut (no icon in the pause sprite table), and `item-unknown.png` for a
  known item on an unknown release.
- `gfx.*` is called every tick (cheap: the app caches by arguments); `rom_gfx.lua` only
  keeps the arguments, so an image the app dropped from its cache is drawn again.
- **Ezlo and the title logo from the ROM.** Ezlo (header button, hint bubble) is the
  EzloCap sprite (sprite 11 in `gSpritePtrs`, EU `0x08002A5C`), frame 44, over
  `gSprite_Link` with Link's OBJ palette (gPalette_0 + 14 * 32, bank 6 in a state saved
  while Ezlo talked). The waiting screen's logo is the title screen's 14 logo sprites
  (fixedTypeGfx_511-513, gPalette_3419/3421/3423); rebuilt from the EU ROM it matches a
  state saved on the title screen. JP has the Japanese logo, so it, and any unknown
  release, shows a "THE MINISH CAP" text title; Ezlo falls back to `assets/ui/cap.png`.
  `assets/img` is no longer used by the pack.

## Dungeon tab (WORLD / DUNGEON)

In a dungeon (`gArea.areaMetadata` bit 1) the MAP panel shows WORLD / DUNGEON tabs and opens
on DUNGEON. Not checked on a device yet (no save inside a dungeon); the script ran against the
EU ROM with faked RAM, and the icons were rebuilt from that ROM.

- **Dungeon items.** Per dungeon id: `gSave.dungeonKeys` (`0x02002E9C`, small keys held) and
  `gSave.dungeonItems` (`0x02002EAC`): bit 0 map, bit 1 compass, bit 2 big key
  (`gameUtils.c` `HasDungeonMap/Compass/BigKey`; save.h's comment lists the bits wrongly).
- **Floors.** `gDungeonFloorMetadatas` (common.c, hard-coded in `main.lua`): floor count, top
  floor's number, boss floor's number, where 3 = 1F, 4 = 2F, 2 = B1. Link's floor row is
  `dungeon_map_y >> 11` (`0x030010BE`, 0 = top floor). With the compass the boss's floor is
  marked until the dungeon is cleared, like the pause menu (which also hides it in Dark Hyrule
  Castle after a local flag; the pack doesn't).
- **Icons.** The item sprite table only has placeholder swords for 0x50-0x53. The dungeon map
  page draws them with sprite 0x143 (EU, 0x144 US/JP) over `fixedTypeGfx_521` (EU
  `0x085C2470`, US `0x085C2F60`, JP `0x085C2C00` inferred from the hearts' JP offset), palette
  banks 4 (map), 0 (compass), the big key's own 1; the small key uses 4.
- **Tab memory.** The layout can't compare values, so the WORLD tab stores the current visit
  number in `ui.mapWorldAt` and `main.lua` shows WORLD only while that matches. Each new
  dungeon entry bumps the visit, so it opens on DUNGEON again.
- **The dungeon map itself isn't drawn.** Unlike the world map it isn't stored in the ROM as a
  picture: the pause menu paints it into RAM (`gDungeonMap`, `0x0201AEE0`) from per-room 2-bit
  masks (`gMapData` + `DungeonLayout.mapDataOffset`), room positions (`gAreaRoomHeaders`) and
  visited flags, and gameplay reuses that buffer. Drawing it needs an app call that takes
  pixels from the script (e.g. `gfx.bitmap`).
- **Link's marker** (world map, dungeon floor list, quest page) is the pause world map's own
  head sprite: DrawDirect sprite 0x1FA (EU) frame 0x59, OBJ tile 0x240 (the object's high byte
  adds 0x200), which the map screen's gfx group 93 fills from `gGfx_94_3` + 0x800 (EU
  `0x08936CB0`, US `0x08939EE0`, JP `0x08939B80` inferred). Coloured with Link's palette
  (gPalette_0 + 14 * 32). The pause palette tables put a placeholder (magenta) palette in OBJ
  bank 7, so the colours here are picked, not read from the screen; check on the device.
