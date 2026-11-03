# Pokemon Emerald companion (0.2.0 console redesign, not committed)

Live values for BPEE (US/EU Emerald 1.0) via `main.lua` + `game_data.lua`. Verified on the Thor with the user's
Mudkip state (ID, ability, nature, met place, stats, EXP, moves, contest chips all match the game).

- RAM: pret/pokeemerald addresses (party 0x020244EC, SaveBlock1/2 pointers 0x03005D8C/90, gBattleMons 0x02024084).
- ROM tables were located by matching text/structs in a real ROM (names, base stats, move data, descriptions,
  region map entries) and are read at runtime, so there are no name tables. Offsets are in main.lua.
- `game_data.lua` (`python3 art/build-data.py <emerald.gba>`): internal->national dex, TM/HM moves, contest category/effect.
- Layout: `node art/layout.mjs`. Art: `python3 art/ui.py`. Preview: `../skill/preview-pack.sh pokemon-emerald-companion --pages map,party,detail,options,battle,battle-detail`.

Open:
- Bag pocket offsets (items 0x560, key 0x5D8, balls 0x630, TM/HM 0x690, berries 0x790) are from pokeemerald but
  unverified: the test save has an empty bag.
- Battle page (gMain.inBattle, gBattleMons) never exercised on the device.
- Map image is an original placeholder; the marker comes from gRegionMapEntries (x,y,w,h on a 28x15 grid).
- WIDE: `game.lua` (ported from FireRed/LeafGreen: Emerald addresses, 512 primary metatiles; the OPTIONS page's WIDE VIEW button toggles it). Not yet verified on the Thor. SAVE was dropped: the engine has no pack-level save action.
- Summary left column (shape icons, gender) and status conditions are not shown.

## Console redesign (2026-11-02)
Dashboard look built from the game's menus: shared header band (page name + ring dots, clock, money, dex, 8 badge
gems), cream windows with lilac tabs, bag inspector (icon, ROM description, price), team strip, summary left column,
Skills with EV bars, Moves with power/accuracy/PP bars, Contest condition bars, trainer card with badges and dex bars,
battle with type-effectiveness chips. Regenerate: `python3 art/ui.py`, `node art/layout.mjs`, `python3 art/preview-data.py`,
`python3 art/build-data.py <emerald.gba>`. Unverified on device: battle pages, bag items, badge flags, item icons for
Emerald-only item ids (icons come from the LeafGreen set, by id).

## Breathing room + battle controls (0.3.0)
Spacing opened up (page padding/gaps 10dp, fewer elements per card, no sub-8px labels), tab labels centered
(`text-align: center` works on `tab`). Battle controls: manifest has `permissions: ["memory-write"]`; tapping
FIGHT/BAG/POKéMON/RUN writes gActionSelectionCursor (0x020244AC) and tapping a move writes gMoveSelectionCursor
(0x020244B0); the player presses A in the game (the game's arrow only redraws on the next D-pad press). Needs
Settings > Packs can change games + the per-pack prompt. NOT yet exercised in a real battle: addresses come from
a symbol file of a modified build, so confirm by opening a fight and watching `battle.act*` / `moves[].sel` follow
the in-game cursor, then tapping.

## Live area map + bigger Trainer card (0.4.0)
The Map page draws the area you're in from the game's own data (gBackupMapLayout + ROM metatiles + VRAM tiles/palettes) with
`gfx.layers`, only while the map page is open and the overworld is on screen; the pin is the player's tile. Needs the app
patch `gbaduo/.idea/plans/gfx-layers-single-grid.patch` (gfx.layers accepted only the multi-layer form; the Pokemon world is a single
grid, as wide() returns). Without it the call errors and the page shows "THE MAP DRAWS WHEN YOU ARE OUT IN THE GAME".
Trainer card: labels 11px, values 30px, icons 26px, badge icon on the BADGES row.

## Follow-cam map (0.5.0)
The picture is a fixed view (240-480 world px wide, the card's 1.93 shape, shown with object-fit: cover) that follows the player a tile
at a time and stops at the map's edges; a map smaller than the view is centred (its surroundings show). A new area is drawn quietly
until two draws agree (max 4), the old picture stays on screen meanwhile with the pin hidden, then it swaps once.

## Map flicker in big routes: the 25 ms per-call limit (0.5.1)
Route 103 (80x22 metatiles) drew a 480 px wide view; with the rest of update() that went past the engine's 25 ms per-call time limit,
so gfx.layers was cancelled ("script exceeded its per-tick time limit") some ticks and not others. The view is now at most 320 px wide
(about 53k px), bag/badges/dex are read every 8 ticks instead of every tick, and if a draw is ever cut off the view shrinks 48 px (floor 176).
Debug trick that found it: put the last render result on the card (map.note); script `log()` is capped per call, so lines go missing.

## Pokedex page (ring: Bag, Map, Pokemon, Pokedex, Options)
`dex` page between Pokemon and Options (RING in art/layout.mjs is now 5 long). 24 national numbers per page, `dexPage(delta)` /
`dexSelect(n)` actions keep the window and selection in Lua; update() reads them only while `ui.page == "dex"` (cached otherwise).
Seen/owned from SaveBlock2 bitmaps, entry text from gPokedexEntries (ROM 0x0856B5B0 + national * 0x20: category, height dm, weight hg,
description ptr), types/abilities/base stats from the species table. Category, size and description show only for OWNED mons; types,
abilities and stats for SEEN ones. Preview-checked and `luac -p` clean; NOT yet run on the Thor (the entry-table offsets were checked
against the ROM with Python only).
