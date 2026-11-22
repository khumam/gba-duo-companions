# Castlevania: Harmony of Dissonance Companion

A companion screen for **Castlevania: Harmony of Dissonance** (GBA, US release `ACHE`) on the AYN Thor's
bottom screen. Made by Ress.

Styled after the game's pause menu. Every picture (Juste and Maxim, item, relic and subweapon icons)
and every name and description is read from your own ROM while you play; the pack ships no game art.

## Pages (v1.0)
- **Status**: Juste's level, EXP and NEXT, HP / MP / hearts, STR DEF INT LCK and status, the whip
  attachment and four armor pieces, subweapon and spell book (lamp = ON), and the 12 relics
  (lit = ON). Tap any of them for the game's own description in the INFORMATION bar.
  Maxim Mode gets its own view.
- **Items**: four lists like the game's menus — ITEMS (potions, food, jewels), KEY ITEMS (keys, castle
  maps, hint cards; missing ones as ??????????), WHIP (attachments, E = equipped) and ARMOR (by slot:
  BODY, HEAD, HANDS, LEGS, GOODS). Tap an entry for a detail card (HP/MP restored, STR/DEF/INT/LCK,
  resistances, elements, owned) and the game's description.
- **Magic**: every spell book × subweapon pair with its MP cost from the ROM (gold frame = the pair
  your subweapon button uses now, dashed = book switched OFF), the line "NOW: …" saying what you'll cast
  or throw, and all 12 relics (Dracula's parts in red) with their ON/OFF lamp. Tap for the game's text.
- **Battle**: Juste (or Maxim) with HP, MP and hearts, what the subweapon button does now, and every
  enemy in the room with its live HP bar, level and weakness. A boss gets its own card and opens this
  page by itself; when it falls you see "Defeated" and the EXP, then the page closes. Tap an enemy for
  ATK, EXP and drops; BOOK on the boss card opens its Encyclopedia page. The battle scene itself stays
  on the game's screen.
- **Book**: the game's Encyclopedia from your save — the 100 enemies, ?????????? until defeated, each
  page with LV, HP, ATK, EXP, tolerance, weakness and drop items (unfound drops stay ?????????? like in
  the game). Bosses are in orange. REVEAL shows the undefeated ones. Enemy pictures are not shown
  (see Known limitations).
- **Map**: the game's castle map redrawn from your save — explored rooms with their walls and doors,
  save rooms (red), warp rooms (yellow) and where you are (blinking). Switch between Castle A and B;
  the explored percentages match the game's map screen.
- **Journey**: the run at a glance — bosses beaten, relics (with Dracula's parts), spell books and furniture
  found, map % and enemies defeated. Each list says where things are (area and castle); WHERE shows the names
  and places of what you haven't found yet. Tap a boss for its stats, or an item for the game's description.

## Requirements
- US ROM only (game code ACHE). Other releases show a waiting screen.
- Made for the AYN Thor's bottom screen (1240 x 1080).
- GBA Duo v0.1.15 or newer. The pack only reads the game; it never changes it.

## Install
In your GBA Duo library, tap **⋮** next to the game, then **Companion pack › Import pack…** and pick
`castlevania-hod-companion-1.0.0.zip` (don't unzip it). Start the game: the companion shows on the other screen.

## Known limitations
- **No portraits or enemy pictures.** The game keeps them compressed with a small header the app's
  picture reader can't skip yet, so the STATUS and BATTLE pages show Juste's (or Maxim's) in-game
  sprite instead, and the Encyclopedia has no pictures.
- **No Wide view.** The game builds its rooms from 32 x 32 blocks; the app's Wide view only reads
  16 x 16 ones.
- **Boss Rush** isn't covered: it wasn't unlocked in any test save. The page should show the waiting
  screen or your character there; it has not been seen.

## Fonts
Jacquard 24, Jersey 10 and Silkscreen, all under the SIL Open Font License 1.1 (`assets/fonts/OFL.txt`).
`HodMap.ttf` (the map cells) is drawn by the pack's own script (`art/mapfont.py`).
