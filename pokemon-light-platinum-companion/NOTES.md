# Pokemon Light Platinum companion: what is mapped

Game: Pokemon Light Platinum (AXVE, CRC 4b04b0c7), a Ruby ROM hack. Checked by running the game headless with the
player's own save (Throh, Charmander Lv14, Central City Pokemon Center) and reading its RAM and the ROM.

## Same as Ruby (verified)

Every RAM address of the Ruby pack holds in Light Platinum, and each also appears as a literal in the hack's code
(hundreds of references): gPlayerParty 0x03004360, gEnemyParty 0x030045C0, SaveBlock1 0x02025734, SaveBlock2 0x02024EA4,
gMapHeader 0x0202E828, gObjectEvents 0x030048A0, gBackupMapLayout 0x03004870, gBattleMons 0x02024A80, the battle
buffers, flags, cursors and controller pointers. The bag pockets keep Ruby's sizes (20 / 20 / 16 / 64 / 46; gBagPockets
at ROM 0x3C1618). Checked against the game's own screens: the Skills page (HP 38/38, ATK 18, DEF 17, SP.ATK 25,
SP.DEF 23, SPEED 24, EXP 1729, next level 306, item MOOMOO MILK, ribbon NONE), the Items page (RARE CANDY x99, x99, x99,
x1) and the Trainer Card (ID 14377, money 1724, play time 4:04).

ROM tables at Ruby's addresses are also unchanged: species names 0x1F716C, move names 0x1F8320 (354 moves, none added),
ability names 0x1FA248 (77), battle moves 0x1FB12C, base stats 0x1FEC18, items 0x3C5564, move descriptions, Pokedex
entries 0x3B1858 (1-386 only), national table 0x1FC516.

## Changed in Light Platinum

- **Species**: 411 in the same list. Gen 4/5 Pokemon sit at ids 252-276 (Turtwig ... Virizion) and replace some Hoenn
  slots (385 is Cofagrigus, 386 Stunky, 411 Reshiram). The game's own national number for them is 387-411
  (`game.national`); the real dex number is found by name (`game.official`) and the shipped sprites use that:
  Black/White sprites for 387-646 were added (`art/fetch-gen45-sprites.sh`).
- **Wild encounters**: gWildMonHeaders moved to **ROM 0x08ACED20** (123 records, same 20-byte layout; Ruby's 0x0839D454
  is not it). Checked on a cave map: Zubat / Onix / Bronzor / Rhyhorn with their chances and levels.
- **Badges**: the first eight use flags 0x807-0x80E (the Trainer Card draws 8 slots) and are Plain, Green, Sea, Ghost,
  Earth, Energy, Glacier, Claw (from the gym scripts). Icons are drawn (`art/badges.mjs`).

## Wide / XL markers are live (entities.lua)

The markers in the Wide and XL margins now come from two places. **Live**: the game's object events
(gObjectEvents 0x030048A0, 16 x 0x24 bytes: bit 0 active, bit 13 invisible, bit 16 player; +4 sprite id, +5 graphics id,
+7 trainer type, +8 local id, +0x18 low nibble facing) and their sprites (gSprites 0x02020004, 0x44 bytes: pos1 @0x20,
pos2 @0x24, centerToCornerVec @0x28). Their position is pixel exact, so walking NPCs move, and the sprite frame follows
the facing (south / north / west, east is the west frame flipped). The camera offset is learned each frame from the
player's own OAM entry. The game only keeps the objects near the camera alive (screen plus a couple of tiles), so
**beyond that** the markers still come from the map's event table in the ROM (where each object starts), minus any
object that is live. Checked on the Pokemon Center: the four NPCs come out at tiles (10,15), (17,13) facing east,
(11,12) and (14,10), the same as their RAM coordinates. Not yet seen on the device.

## Not mapped / not verified

- **Second badge set** (Mineral, Sky, Force, Ruby, Strong, Purple, Illusion, Iron): flags 0x1800-0x1807, beyond Ruby's flag
  array. Where the game stores them is not found, so they are not shown.
- **Pokedex entry text** exists only for 1-386; Light Platinum's extra Pokemon (387-411) show types and stats but no text,
  and a Hoenn slot it replaced keeps the old entry's text.
- **Battle** pages were not checked in a live fight (the addresses are verified by the code references only).
- The pack is not yet tried on the device.

## Offline check

`lp/run.lua` in the scratchpad runs main.lua against a headless-emulator memory dump and the ROM.
