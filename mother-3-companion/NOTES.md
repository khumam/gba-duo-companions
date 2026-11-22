# Mother 3 companion (English fan translation v1.3, A3UJ, CRC 8A3BC5A8)

Read-only pack, v0.1.0, not released. Pages (ring, bottom bar prev | page | next, character tabs on top): Goods, Equip, PSI, Status.
Design = the game's own pause windows (screenshots: Goods/PSI/Equip/Status). Portraits/icons are cut from the game's frames by `art/crop.py`
(`art/ref/*.ppm` are 240x160 emulator frames); text/data come from the player's ROM via `art/extract.py` (`data.lua`). Layout: `art/layout.py`.
`lua art/preview.lua <state.ss>` runs main.lua on a save state and writes preview-data.json. Preview: `skill/preview-pack.sh mother-3-companion`.

## RAM (verified on the device, Chapter 8 save, 4 characters at level 58-59)
- Party: IWRAM `0x03006D72`, 4 x u8 = character record index + 1, in the game's menu order. DP (money): u32 `0x03006D68`.
- Character records: EWRAM `0x0200417E` + `0x6C * index` (index 0 Flint, 1 Lucas, 2 Duster, 3 Kumatora, 4 Boney, 5 Salsa ...).
  +0x00 name (u16 per letter = ascii - 0x20, 0xFFFF ends, max 8 letters), +0x10 level u8, +0x12 EXP u32, +0x16 HP u16, +0x1A PP u16,
  +0x1E max HP u16, +0x22 base max PP u16, +0x26 offense/+0x27 defense/+0x28 IQ/+0x29 speed (u8, WITHOUT equipment),
  +0x32 equipment u8 x4 (weapon, body, head, other), +0x3A inventory u8 x16 (item ids, 0 = empty; row-major in two columns).
- Shown offense/defense/IQ/speed = base + sum of equipment bonuses parsed from the item descriptions ("Offense +100."): matches all four characters.
- Next level = EXP table (ROM 0xCDABC: 99 u32 increments, cumulative sum[L] = EXP to leave level L) - EXP.
- Save-block mirror of the same data lives at 0x02004xxx; the IWRAM party/DP block is the live copy.

## ROM tables (text is u16 = ascii - 0x20, space = 0x40, 0xFFFF ends; 0xFFxx are control codes)
- Item names `0x1F8C404 + 0x2C * id`; item description = string (id + 71) of the pool at 0xCF9300 (strings split on 0xFFFF).
- PSI names `0x0D2902C + 0x28 * id` (greek = 0x3B..0x3E), PSI struct `0x0E18DC + 0x38 * id` (+0 PP cost, +0x20 u16 event-flag-like id), PSI description = string (2 + rank among non-EMPTY ids). ids 2-5 are shown as "PK Love" in game.

## Goods actions (v0.1.0, formatVersion 3, permission memory-write)
- Use / Give / Drop buttons under the list, "On whom?" / "Give to whom?" window, Drop asks Yes/No; GAME CHANGES pill (the app's `writePermission`) asks for consent.
- Write = rewrite the 16 inventory bytes at record+0x3A with the item removed and the rest shifted up (Give appends to the first free slot of the target).
  Checked in the emulator: writing those bytes makes the game's own Goods menu show the item gone, list compacted, E markers intact.
- Use only works for items whose description says "Restores N HP/PP": raises HP (record+0x16) / PP (+0x1A) up to the max and removes the item. Not verified on the device yet.
- Equipped items can't be given or dropped (unequip first). Do it from the field, not while the game's own Goods menu is open (it keeps its own list copy).
- Device test status: UI, dialog and the refusal path verified; the first real write needs the player to allow Settings > Packs can change games AND answer the app's prompt, which was never answered by the user.
- Gotchas: a box without onClick lets taps fall through to what is behind it (the dialog needs onClick); a stored consent answer lives in files/games/gba/<game>/consent.json.

## Open
- **PSI page is a guide** (all PSI, PP cost, description), not who has learned what: the per-character learned-PSI data was not found
  (not in the character record, no consistent event-flag array; the menu builds its list at 0x02021B40 as name pointers only while the PSI menu is open).
- Key items tab (the key icon in Goods) not read; max PP is `max(current, base)` (Lucas shows 262 while the base field says 212, +50 source unknown), so it is wrong when PP is below max.
- HP/max HP offsets assume +0x16 current, +0x1E max (identical values in the test save); check in a battle (odometer rolling) and with a wounded character.
- Battle, map, Flint/Salsa/Wess portraits (initial letter shown), item icons, DP/EXP odometer look, memos/sleep not done. Only tested on this one Chapter 8 save (Empire Porky Building).
- Needs the English translation ROM v1.3 (A3UJ); the Japanese original has a different layout.
