# 0.4.0 (2026-11-24): the game's own pause screens, re-laid for touch
Design: `.idea/plans/cv-design2/cotm-*.png`. Source: `art/layout.py`, `art/style.src.css`, `art/cotm_ui.py` (arrow plates
`ui/plate-on|off.png` and capsule ends `ui/cap-l|r-12|16|20.png`, drawn in the game's shapes at 5 device px per art px). Old source: `art/v2/`.
- Navy gradient field with white rules, the slanted striped header tab, the pause menu's arrow plates as the page nav (red-orange = open)
  and as the action buttons, values in capsule frames, the DSS page shows both card rows like the game (tap a card in either row), the
  combo text in the game's wide monospace (Press Start 2P, `assets/fonts`, OFL).
- Readability: labels Silkscreen 7 ap / 0.7 ap tracking, names and numbers Jersey 11-12 ap, message text Press Start 6 ap on 9 ap lines.
- `main.lua`: one nav flag (`onConfig`).

# 0.3.0 (2026-11-24): map like the game, pixel kit, one size per control
- **Map**: the game's own map: `mapdata.lua` read off the Select map screen (BG0, 4 px per cell, blue fill / white walls / door gaps / red save / yellow warp on black; 980 cells, 20 save, 5 warp rooms; image cell (x, y) = explored bit (x, y + 1) at `0x02025420`), drawn by `gamemap.lua` with `assets/fonts/HodMap.ttf` (one glyph per cell, 6.9376 px = 4 game px x 4 device px). The player marker waits for the origin bytes (they read 0 until the first room change after a load).
- **Pixel kit**: see the Aria notes; tokens in `art/pixel.json`, originals in `art/v2/`.

# 0.2.0 layout (design: `.idea/plans/cotm-design/` in the app repo)

A command column of five tabs (STATUS, DSS, GEAR, ITEMS, MAP) in the game's arrow-plate colours, then sockets, a list or card grid, and one
inspector with the one big button on every page. Magic items fold into STATUS (a found / missing strip), the Card page into DSS (pick a socket,
then a card), config behind KEYS. The 0.1.x files are in `art/v1/`.

## Game art (cut from the game, `assets/game/`)
Nathan's portrait (Status screen), the 20 DSS cards (Card screen, 56 x 92, plus 28 x 46 thumbnails) and the eight Magic Item pictures (Magic Item
screen, 48 x 64, plus 24 x 32). Cut headlessly from the emulator's screenshots. Items, equipment and the map tab have no pictures in the game, so
those icons are the original pixel art from 0.1.x (`assets/ui/ic-*.png`, `tab-map.png`).

## Player position on the map (found 2026-11-24, Lv 71 save)
| Address | What |
|---|---|
| `0x020274B4` / `B5` | u8 origin cell (x, y) of the room Nathan is in (kept for the next room too: `B6/B7`) |
| `0x02000036` / `0x0200003A` | u16 Nathan's position inside the room, pixels (x, y) |

Cell = (origin x + px // 256, origin y + ceil(py / 256)). Checked against the game itself: clearing the explored-map bits in RAM makes the game
re-mark exactly the cell Nathan stands in, and the formula matched all 66 samples (36 + 30, several rooms, x 16-23, y 39-40).
**Known gap:** the origin bytes read 0,0 right after loading a save and only fill in at the first room change; until then the marker is hidden
(`YOU --` is not shown, the marker just waits). The room table is at ROM `0x000DBBDC` (u8 x, y per room, e.g. 14,36 / 17,37 / 20,38) but the
current room's index is not in RAM at load, so it was not used. Only y rows 39-40 were sampled: check other floors on the device.

# Castlevania: Circle of the Moon companion: notes

USA cartridge only (`AAME`). Started 2026-11-21. Version 0.1.0, **not yet checked on a device**.

## Pages

The pause menu, cycled by the left / right plates: Status (the pause screen; menu tabs, the DSS combo and gear are
tappable), DSS, Item, Card, Magic Item, Config, plus Map (the explored castle, the game's Select map).

Taps that change the game (need **Settings > Packs can change games**):

| Tap | Writes |
|---|---|
| DSS: tap an action and an attribute card, SET | the two card bytes (owned cards only) |
| Item: EQUIP (or Unequip) | the slot byte, the bag counts (new -1, old +1: worn gear is not counted) and the running stat totals |
| Item: USE / Status: HEAL | HP, MP or Hearts (amount read from the item's own help text) and the count - 1 |
| Config: < > / DEFAULT | the four button words; a clash swaps |

Live alerts: CARD GET, MAGIC ITEM, LEVEL UP banners (tap opens the page; X hides; 6 s).

Checked in the headless emulator with the user's Lv 71 save: after the pack's writes (Leather Armor on, Mercury +
Serpent set, HP healed) the game's own Status, Item and DSS screens showed STR 875 / DEF 905 / INT 875 / LCK 875,
Leather Armor worn with 96 left, Mercury + Serpent at 2 / ATTACK, full HP.

## Text

The game's text uses its own glyph numbers (ordered by letter frequency: 0x28 e, 0x29 a, 0x2A t ...). The table in
`main.lua` (CHARS) was worked out from the item / enemy / help strings; controls: 0x1D-0x1F take one parameter byte,
0x09 / 0x0A / 0x01-0x03 break lines, 0x06 / 0x07 are quote marks. The DSS button hints `[v >(<) ^ + Attack]` are the
game's arrow glyphs 0x59-0x5E. Unknown so far: Q, X, digits 6 7 9, '?', ':'.

## ROM (USA)

| Address | What |
|---|---|
| `0x086707D8` | 1270 u32 string pointers. 36-179 enemies, 180 Unequip, 183-222 gear (equipment id = string - 182), 223-236 items, 291-315 areas, 317-325 magic items (322 Map), 381-388 their help, 390 "No effect.", 391 + action*10 + attribute = combo text, 514 + id = gear / item help, 570-589 "Received X Card" (attributes then actions), 591-610 card text |
| `0x080E0970` | s16 STR DEF INT LCK per equipment id 1-40 (8 bytes). Double Grips: 0; wearing two adds +75 to all four |
| `0x080E0734` | u32 total EXP to leave level L |
| DSS costs | not found as a table: `COST` in main.lua was read off the game's DSS screen for all 100 pairs |

## RAM (EWRAM). The game plays on the first copy; its pause menu edits a second copy (+0x22A4) and copies it back.

| Address | What |
|---|---|
| `0x020253F8` | u32 play time, frames |
| `0x02025420` | explored map, 42 rows x 8 bytes, low bit first; 980 cells = 100.0% (the game does not store the rate) |
| `0x0202562E` | u16 HP, `+4` max HP, `+8` MP, `+C` max MP, `+E` Hearts, `+10` max Hearts |
| `0x02025644` | 4 groups (STR DEF INT LCK) of 4 u16: base, +gear, +cards, final |
| `0x02025664` | level, `0x02025668` u32 EXP |
| `0x0202566C` / `6D` | DSS attribute / action card, 1-based (Salamander..Black Dog, Mercury..Pluto) |
| `0x0202566E` / `6F` / `70` | body / arm R / arm L (equipment id, 0 = none; 1-22 body, 23-40 arm) |
| `0x02025674` | 20 card flags: attributes 0-9, then actions 0-9 |
| `0x020256EC` | count per equipment / item id (0-54) |
| `0x02025724` | u16 Attack, Jump, Special Move, DSS buttons (A 1, B 2, R 0x100, L 0x200) |
| `0x0202572F` | magic item flags (Dash Boots, Double, Tackle, Kick Boots, Heavy Ring, Map, Cleansing, Roc Wing, Last Key) |

## Not done

- Device check. Player marker on the map (room coordinates not found), save / warp rooms on the map.
- Whether DSS is switched on (L in the field): no reliable flag found, the pack says to press DSS in the game.
- Status ailments (STATUS/GOOD fixed), Antidote / Cure Curse can't be used from the pack, enemy list (not in the game's
  pause menu).
- EU / JP releases.
