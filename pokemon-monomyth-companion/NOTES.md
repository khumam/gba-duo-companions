# Pokemon Monomyth companion (MONE, CRC32 8441C61B)

Read-only pack, v0.1.0. Monomyth is a Pokemon Emerald-based ROM hack; its RAM map differs from Emerald's.

## Design
The screens are the Emerald pack's own: `art/layout.emerald.json` is a verbatim copy of pokemon-emerald-companion/layout.json, `style.css` and `assets/ui|fonts|types` are copied too. `art/build.py` patches only what differs (boot text, 7 bag pockets, text-only map page, WIDE VIEW row removed) and writes layout.json. `main.lua` fills every field the Emerald pages read, from Monomyth's memory.
Map and options pages are now Emerald's own (see Map below). Stand-ins: Pokédex = species book (all 405 species, base stats/types/abilities; seen/caught flags not decoded); badges all locked (flags not found); battle page from the live battle structures (below), read only, no buttons; options page shows no Pokédex count (shows '--') and 0/8 badges.

## Scope
Started as a spoiler-safe pack (the ROM carries a developer message asking players not to datamine before playing through);
on 2026-11-14 the user explicitly dropped that limit, so the pack now reads species, types, moves, abilities, items and
descriptions like the Emerald pack. Keep it private: the developers also ask people to wait before sharing datamined findings.

## Pokemon data
- Substructs are Emerald's (24 orders by personality % 24) but the XOR key is derived, not pers^otid: function at ROM 0x08056C8E
  (`monKey` in main.lua; verified on two Pokemon). Checksum/validation function sits at 0x080567BC.
- Tables: species names 0x084E8BBC (11 B), move names 0x084E9D23 (13 B), ability names 0x084EE603 (13 B) + description pointers
  0x084EF0C8, move data 0x084F17E1 (16 B: effect, power, type, accuracy, pp, secondary chance), base stats 0x084F6DBC (24 B:
  6 stats, types +6/+7, catch +8, gender ratio +9, friendship +11, growth +12, abilities +20/+21), items 0x089F15D2 (32 B: name,
  description pointer +22, price +30), move description pointers 0x08AC02FC (index move-1).
- Growth byte: both checked Pokemon are Medium Slow and carry 2, so main.lua swaps 2 and 3 against Emerald's numbering (unverified for other rates).
- Sprites: pictures use a multi-mode compression the game decodes with the routine at ROM 0x08252A80 (Thumb; r0 = data pointer,
  r1 = destination, r2 = 0x0201C000 scratch; header byte0 & 15 = mode, modes seen 3 and 6). Rather than port it, `art/gen_sprites.py`
  runs that routine in the Unicorn ARM emulator (`art/emu.py`, needs a RAM dump of a running game for the heap, `pip install unicorn`)
  and writes `assets/pokemon/<species>.png` (64x64 indexed PNG, colour 0 transparent). FRONT pictures: table 0x0049F720 (8 B entries
  {ptr, 0x800, species}, species s at index s-1; the game uses base 0x0849F718 + 8*species); BACK pictures: 0x00487430. Palettes:
  table 0x004880D0 (species s at +8*s, {plain LZ77 ptr, species}); two palettes (species 37, 350) are shorter than 32 bytes, padded with zeros.
  405 sprites bundled (game art cut from the ROM: keep the pack private).
## Addresses (found in a headless run with a real save)
- gSaveBlock1Ptr 0x03001240, gSaveBlock2Ptr 0x03001244 (blocks move on every load: read the pointers).
- gPlayerParty 0x02025908 (count at 0x02025905), gEnemyParty 0x02025B60, 0x64 bytes per mon. Plain fields: nickname +8,
  status +0x50, level +0x54, HP +0x56, max HP +0x58, ATK/DEF/SPE/SPA/SPD +0x5A..+0x62.
- gMapHeader 0x02038210, region map section id at +0x14; names via the pointer table at ROM 0x08A166B0 (8 bytes per entry).
- SaveBlock2: name +0, trainer id u16 +0xA, play time h u16 +0xE, m +0x10, s +0x11, encryption key u32 +0x40.
- SaveBlock1: money u32 at +0x494 XOR key; bag slots from +0x564 (4 bytes: item id u16, quantity u16 XOR key low half).
  Pockets: the live table gBagPockets at 0x0203C18C (7 x { slot pointer, capacity }) in the game's order Items, Medicine,
  Poke Balls, TMs & HMs, Battle Items, Berries, Key Items (names at ROM 0xA9DE16). Item names ROM 0x089F15D2, 32 bytes per id.
- Party mon plain fields also give OT name (+0x14), trainer id (+4) and nature (personality % 25).
- Battle: two copies of gBattleTypeFlags at 0x02000E2C and 0x02001278 (0 outside battle; 8 in a trainer battle).

## Map page (2026-11-15)
- SaveBlock1: player tile (x, y s16) at +4, map location (group, number) at +8 (Emerald: +0 and +4; same +4 shift as the money field).
  gObjectEvents[0] (player) is at 0x02038280, coordinates +0x10/+0x12 (= tile + 7).
- Area picture: same structures as Emerald: gMapHeader 0x02038210 (layout pointer at +0: width, height, border +8, map +0xC, primary tileset +0x10,
  secondary +0x14; tileset metatiles at +0x0C), gBackupMapLayout 0x0203823C. Drawn by gfx.layers from VRAM.
  **Monomyth's metatiles are 24 bytes (triple layer: bottom, middle, top, 4 tile entries each; primary 512 metatiles = 0x3000 bytes), not Emerald's 16.** The first device screenshot showed the ground as light blue because the app read them as 16 bytes. The app's gfx.layers / wide world now has `metatileLayers = 3` (app/src/main/cpp/wide.c, script.c, wide.h, docs-packs/game-script.md; uncommitted in the app repo); the pack passes it. Needs an app build that has it (installed on the Thor 2026-11-15 as a debug build).
- Wild Pokemon: gWildMonHeaders ROM 0x089C2E58 (20 B entries, ends with group 0xFF at entry 211), same format and slot chances as Emerald
  (checked on Route 1 = group 0 num 12: Shope, Kernut, Caroot, Leonte). Map group arrays: group table ROM 0x0086EED8 (34 groups).
- World view: assets/ui/hoenn.png (name kept from Emerald) is drawn by `art/world-map.py` from the region entries (ROM 0x08A166B0: name pointer, x, y, w, h;
  index = mapsec; grid 28 x 15, Monomyth uses x 0..25, y 0..14). The player's spot follows how far across the map they are.

- Budget: an update may run 25 ms, and the map picture's pixels count against it. Walking moves the camera and redrew a 320-wide, 3-layer picture every step: update errors 'script exceeded its per-tick time limit' and the screen fell back to the waiting state. Now the picture is at most 240 px wide, redraws at most every 4 updates, wild table only read on the map page, bag every 8 updates (or on bag/options/battle pages), dex only on the dex page.

## Battle (found 2026-11-15 with the headless harness on the trainer-battle state)
- gBattleMons 0x0200013C, 0x38 bytes per battler (player 0, foe 1): species u16 +0, ability +2, types +3/+4, level +6, moves[4] u16 +0xC,
  atk/def/spe/spa/spd u16 +0x16..+0x1E, HP +0x20, max HP +0x22, stat stages[8] +0x30 (6 = neutral; index 1 atk, 2 def, 3 spe, 4 spa, 5 spd).
  PP is not in this struct (byte +0x2C changes with Scratch's PP but the rest is unexplained): PP is read from the party copy.
- gBattlerControllerFuncs[0] 0x020258EC: 0x08048549 = action menu (HandleInputChooseAction), 0x08048E69 = move menu. It keeps a stale value after a fight.
- gActionSelectionCursor 0x02025820 (0 FIGHT, 1 BAG, 2 POKEMON, 3 RUN), gMoveSelectionCursor 0x02025824.
- Battle detection: both battlers valid and each matches a Pokemon of the player / enemy party by species and level; the structure is cleared after the
  fight and never matched in 6 overworld dumps. The same struct serves wild fights; a wild fight was NOT tested (no grass found near the start).
- The two "gBattleTypeFlags" words (0x02000E2C / 0x02001278) read 8 in the trainer battle but are garbage in the overworld; only trusted while a fight is on (trainer: both equal, bit 3).
- gMain.inBattle not found (not needed).

## Open
- Wild battles untested (only the trainer flag seen). No inBattle flag found.
- Badges not verified (0 earned so far), map page, Wide view, nav docks/options page (Emerald has them).
- Device test on the Thor with the live game still to do.

## Tools
`art/layout.py` generates layout.json. `test-dump.lua` is the offline test (run it with the harness dumps).
