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
