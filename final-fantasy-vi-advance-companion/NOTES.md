# Final Fantasy VI Advance companion: build notes

v0.2.0 (2026-11-13), US build (`BZ6E`, CRC32 D708F5AB) only. Seven pages in a loop, left / right buttons at the bottom cycle through them: Party, Items, Abilities, Equip, Relics, Formation, Config. Status is not in the loop: tap a party member on Party to open it (its buttons are `< Party` and `Equip >`); the name tabs on the character pages pick who. Items can be used (tap an item: pick who, or Yes / No for the Tent), Formation (tap two members to swap) and Config (tap an option) write to the game, so the manifest asks for `memory-write` (formatVersion 3).
Previewed with the app's engine; `main.lua` run against the real ROM + a RAM dump. **Not confirmed on the device yet**: the first device run
showed HP/MP as 46685/46628 because `mem.u16` on an odd address reads the aligned halfword; fixed (HP/MP read as two bytes) but not re-checked live.

## The look

The game's menu windows: blue gradient (#292984 -> #121139), grey double frame, rounded corners, white text with a 1 px shadow, cyan labels
(#00dee7). Windows are PNGs from `art/ui.py` (original), text is Jersey 10 at 10ap on the 248 x 216 art-pixel grid (1ap = 5 device px).
`art/layout.py` -> layout.json, `art/css.py` expands `ap` in `art/style.src.css`, `art/names.py` -> `item_names.lua`.
**Game art that ships:** the 16 character portraits `assets/gfx/p<actor>.png` (34 x 37, cut from the main menu's own frames, party edited in RAM
to show every actor). README credits + disclaimer say so.

## How the data was found (no decompilation used)

Headless mGBA (see the DBZ pack notes for building it; `rom.sav` next to the ROM is loaded). Boot to the title takes ~2400 frames of Start
presses; Load Game -> A -> A -> Up (to Yes) -> A. The game keeps the SNES layout in EWRAM (`0x02000000` + SNES WRAM offset):

| What | Address (US) | Notes |
|---|---|---|
| Characters | `0x02001600 + 37 * actor` | +0 actor id, +2..7 name (A-Z = 0x20, a-z = 0x3A), +8 level, +9 HP, +11 max HP, +13 MP, +15 max MP (u16 each, **odd addresses: read as two bytes**), +17 EXP (3 bytes), +22..25 commands, +26 vigor, +27 speed, +28 stamina, +29 magic, +30 esper, +31..36 right hand, left hand, head, body, relic 1, relic 2 |
| Party | `0x02001850 + actor` | bits 0-2 party number, bits 3-4 position; the menu order is the position |
| Gil / time / steps | `0x02001860` (3 bytes) / `+3` hours, `+4` minutes / `+6` (3 bytes) | |
| Inventory | ids `0x02039010`, quantities `0x02039130`, one byte per slot in menu order, `0xFF` ends the ids | always present, not only while a menu is open |
| Config | `0x020202EC`, 8 bytes | mode (0 Active, 1 Wait), speed index, messages index, command (0 Standard, 1 Shortcut), ATB (0 On, 1 Off), reequip (0 Optimize, 1 Remove All), cursor (0 Reset, 1 Remember), dash (0 On, 1 Off). Verified by writing it and reading the Config screen; the SNES copy at `0x02001D4D` is not what the screen reads. |
| Espers | owned bits `0x02001A69` (id order: Ramuh 0 ... Gilgamesh 30; names ROM `0x79C570`, 8 chars each); a character's esper is struct +30 | the menu greys an esper another character wears |
| Spells | `0x02001A6E + 54 * actor` for actors 0-11 (`0xFF` = learned, else % learned); the rest of the range overlaps other data | standard 54-spell order (names ROM `0x79BCD7`, 4-letter short forms only) |
| Item use | inventory arrays above, struct HP +9 / MP +13 | measured on the game's own Use menu (single item in the inventory, Locke at HP 100 / MP 10): Potion (id 232) +50 HP, Hi-Potion (233) +250 HP, X-Potion (234) full HP, Ether (235) +50 MP, Hi-Ether (236) +150 MP, X-Ether (237) full MP, Elixir (238) and Sleeping Bag (246) full HP + MP of one character, Tent (247) full HP + MP of the party; each takes one item. Megalixir is not usable from the menu. Not done: Phoenix Down, status cures (Holy Water, Antidote, Eye Drops, Gold Needle, Remedy), Green Cherry. |
| Formation | party byte bits 3-4 are the position; swapping two members swaps those bits | |
| Item names | ROM `0x0079A00E + 9 * id`: icon byte + 8 characters (short names) | full names for the cut-off ones are in `art/names.py` (matched by prefix); ids 256-270 are GBA-only gear (`Apocalypse` ...), used from id `0xE7` in gear slots |

Class titles (Rune Knight, Magitek Elite ...) are fixed per actor in `main.lua`.

## Stats with gear, Defense / Evasion, EXP to next, HP / MP maximum (found 2026-11-14, not released yet, verified on 4 of 4 party members)

Ground truth: the Status screen builds its numbers in a RAM buffer at `0x020011A0` while it is open (u16: Magic, Stamina, Speed, Strength at +0/+2/+4/+6,
Evasion % +8, Magic Evasion % +10; bytes: Attack right hand +12, left hand +13, Defense +26, Magic Defense +27). Probing every item id in a slot of the
harness save state and reading that buffer gave the item table:

| What | Address (US, ROM) | Notes |
|---|---|---|
| Item properties | `0x0862CC64`, 30 bytes per item | +0 class (low nibble 1 = weapon), +9 HP/MP bonus flags, +16 (Speed hi nibble, Strength lo), +17 (Magic hi, Stamina lo): signed nibbles (bit 3 = sign, bits 0-2 = size), +20 Defense (a weapon: its power), +21 Magic Defense (weapon: hit rate), +26 Evasion (lo nibble) / Magic Evasion (hi nibble) in tens. Gear ids from `0xE7` use index `id + 25` (the GBA-only items); the table ends near 279. |
| Character base Defense etc. | `0x0862ACB7`, 22 bytes per actor | Defense, Magic Defense, Evasion, Magic Evasion before gear (Celes 44 / 31 / 7 / 9) |
| EXP curve | `0x0862ABC8`, u16 per level | the EXP needed for the next level / 8; the total for level n+1 is 8 x the sum of the first n entries; EXP to next = that minus current EXP (17 of 17 levels checked) |

Formulas (all checked against the game): stat = base + sum of the gear bonuses; Defense / Magic Defense = character base + sum over non-weapons; Evasion / Magic Evasion = character base + sum over all gear;
Attack (right hand) = weapon power + 16, capped at 255, 26 bare-handed. HP / MP maximum = base x (1 + the biggest bonus): flag bits in item byte +9, HP `0x10` +12.5%, `0x04` +25%, `0x08` +50%; MP `0x80` +12.5%, `0x20` +25%, `0x40` +50%;
they do not stack (the largest wins); capped at 9999 / 999. Bit 14 of the raw max MP is not the bonus.
Menu keys in the harness for this game: Start opens the menu; the cursor is remembered between uses (Cursor Position = Remember), so count presses from a screenshot.
The Status page has a second view (tap "Combat >"): Attack, Defense, Evasion, Magic Defense, Magic Evasion, EXP to next. `test-device.lua` checks the numbers against `truth.lua`-style data.

## Skills page: Bushido, Blitz, Lore, Rage, Dance (found 2026-11-14)

Learned flags are the SNES ones at EWRAM `0x02000000 + offset`, one bit per technique in list order: Bushido `0x1CF7` (1 byte), Blitz `0x1D28` (1), Lore `0x1D29` (3 bytes), Rage `0x1D2C` (32 bytes; bit n = enemy id n), Dance `0x1D4C` (1).
They are shared by the whole party; the game greys a category when the character has no such command (Bushido 7, Blitz 10, Lore 12, Rage 16, Dance 19), the Skills page dims the tab the same way.
Names: the first four lists are the GBA names read off the game's own Abilities screens (the ROM only has 8-character cut-offs, e.g. `Raging F`); Rage uses the ROM enemy table at `0x08722C94`, 8 bytes per enemy id (Guard, Imperial, Templar ...).
Verified against the game: Lore learned bits `bb af 96` give exactly the 16 spells the game lists; Dance `df` leaves Water Harmony out as the game does. Item names ids 176 / 229 are `Silver Spectacles` / `Tintinnabulum`.
Descriptions (items, Blitz inputs and text) are compressed text and are not decoded.
Title screen on the device and in the harness: the app's FFVI save does not offer Load Game (A on the title starts a New Game); nothing is written until you save in the game.

## Not done / wrong on purpose

- ~~Displayed stats with gear, MP maximum, EXP to next level~~ **done** (below). Impartis (item 36, Imp-only) shows `?` for Attack: the game gives a small, character-dependent number (17 for Celes, 14 for Gogo) that isn't in the item table.
- Item names left short: `Silver S` (id 176), `Tintinna` (id 229). Item descriptions are compressed text (dictionary codes 0x1D/0x1E), not decoded.
- Rage names are the ROM's 8-character enemy names (`Imperial`, `Magna Ro`): the game shows longer ones that are not stored as plain text. Spell MP costs and descriptions are not shown. Save / Quicksave are not mirrored. Formation only reorders (the game's Formation does the same). Config writes are unverified in battle (the screen reflects them).
- Esper/relic effects and "Dualcast" command swap for Soul of Thamasa are not applied (Celes shows Magic where the game shows Dualcast).

## Build

```sh
python3 art/ui.py && python3 art/names.py "../ROMs/Final Fantasy VI Advance (USA).gba" && python3 art/layout.py && python3 art/css.py
skill/preview-pack.sh final-fantasy-vi-advance-companion --pages party,items,equip --no-tall
```
Zip for release: manifest.json layout.json style.css main.lua item_names.lua assets.
