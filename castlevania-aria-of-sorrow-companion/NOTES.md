# 0.4.0 (2026-11-24): the game's own pause screen, re-laid for touch
Design: `.idea/plans/cv-design2/aos-*.png` in the app repo (references in its `ref/`). Source: `art/layout.py`, `art/style.src.css`
(ap units, `python3 art/layout.py && python3 art/css.py`; the pixel kit is no longer applied; 0.2/0.3 source in `art/v2/`).
- Left: the game's dark-red command panel (Soma's portrait, LV, STATUS / SOUL SET / EQUIP / ITEM USE / MAP / ENEMY / CONFIG, the white
  glove on the open page). Top: the silver scroll plaque. Data in thin white outlined boxes, lists on full-width red bands in two columns
  with the glove on the picked row, the quill-cornered message box at the bottom holds the text and the one action.
- Readability: labels Silkscreen 7 ap with 0.6 ap tracking, nav / names / numbers Jersey 11-14 ap, a 1 ap drop shadow; every tap target
  is 20 ap (43 dp) or more; bands are sized to whole rows (4, or 3 on EQUIP).
- `main.lua`: two nav flags (`onEnemy`, `onConfig`). Enemy pages and the button config were rebuilt in the same frame (no carried 0.1 pages).

# 0.3.0 (2026-11-24): map like the game, pixel kit, one size per control
- **Map**: the game's own castle map, cell for cell. `mapdata.lua` was read off the game's map screen with every explored bit set (BG0 of the Select map, 4 px per cell: wall = 3 white pixels, door = cyan, save = red, warp = yellow; cells line up with the explored bits at `0x020000B4` / `0x020001F4`: 848 cells, 17 save, 8 warp rooms). `gamemap.lua` draws one `assets/fonts/HodMap.ttf` glyph per cell (font from the community HoD pack) in five layers (fill, save, warp, walls, doors); the explored bits decide what shows. Background `#29007b`, fill `#0000e6`, like the game.
- **Pixel kit** (`skill/tools/packkit/pixelkit.py`, tokens in `art/pixel.json`, originals in `art/v2/`): square corners, banded (3-tone) bars and buttons instead of smooth gradients, dithered 2-tone panels (`assets/ui/px-*.png`), hard 1 art-pixel shadows, every icon in an inset socket, one height for big buttons (20ap), one for small controls (14ap), one for list icons and rows. Re-run `python3 skill/tools/packkit/pixelkit.py PACK PACK/art/pixel.json && python3 art/css.py` after editing `art/v2/style.src.css`.

## Game art (cut from the game, `assets/game/`) - added 2026-11-24
Soma's portrait, the title banner (text painted out), the glove cursor, the A / B / L / R button icons, the soul orbs (the red / blue / yellow ones from
the Soul Set screen, the grey ability orb recoloured from the red), and **every weapon (59), body armor (25), accessory (20) and item (32) icon**.
Equipment icons were captured by writing each equipment byte and re-entering the Equip screen (the slot shows that item's icon); item icons by walking
the Item Use list with every count set to 1 (list is the item ids row by row, two columns). Still original art: the element icons on the enemy page,
the enemy picture frame, the empty-socket / pip placeholders and the map tab glyph (the game has no picture for them).

# 0.2.0 layout (design: `.idea/plans/aos-design/` in the app repo)

A command column on the left (STATUS, SOUL SET, EQUIP, ITEM USE, MAP) mirrors the game's own list; every page then follows one pattern:
sockets on top, one list, one inspector with the one big button. 0.1.x files (layout, style, Lua, data) are in `art/v1/`.

- **STATUS**: portrait, level, HP / MP, HEAL, big ATT / DEF, four base stats, EXP, time / rate / gold. BOOK and KEYS (title row) open the
  Enemy data pages and the button settings, which are the 0.1.x pages unchanged (no bottom nav; use the left column).
- **SOUL SET**: four sockets (bullet, guardian, enchant, ability). Ability souls are no longer a page: the fourth socket lists them with ON / OFF
  (tap toggles). The enemy drop line sits in the soul inspector as before.
- **EQUIP / ITEM USE**: same pattern; the AFTER values in the equip inspector are cyan up / red down.
- **MAP**: the explored castle plus **Soma's cell** (white square, red centre) and a YOU x,y read-out.
- Alerts (NEW SOUL, LEVEL UP, NEW ENEMY DATA) now sit over the sockets.
- Rebuild: `python3 art/make_new_art.py`, `python3 art/layout.py`, `python3 ../skill/tools/packkit/css.py .` (CSS in `art/style.src.css`, `ap` = 2.168 dp).

## Player position (found 2026-11-24 with the user's Lv 98 save)

| Address | What |
|---|---|
| `0x0200008C` | u8 whole map X of Soma's cell (29 in the save room, 28 in the corridor below it) |
| `0x03001A0D` / `0x03007CD1` | u8 X / Y offsets from the origin cell (28, 6); IWRAM, three copies of each in the dumps |

How: clearing the explored-map bits in RAM and running 90 frames makes the game mark exactly the cell Soma is in (29,6; 28,6; 28,7 ...), so
the marked cell is ground truth; the bytes above track it. **Caveat:** the Y offset is only proven over two rooms (rows 6 and 7), and the origin
(28, 6) is assumed to be global. The pack shows the marker only while `X - xOffset == 28`, so a different origin hides it rather than misplaces it.
Please check it in other areas on the device (walk to a far room, open MAP, compare with the game's blinking marker).

# Castlevania: Aria of Sorrow companion: notes

USA cartridge only (`A2CE`, v0). Started 2026-11-21. Version 0.2.0 layout, **not yet checked on a device**.

## What it shows

The pause menu, cycled by the left / right plates: Status (the pause screen, with tappable menu, equipment and
souls), Soul Set, Equip, Item Use, Ability, Enemy (bestiary book, 12 pages) + an enemy entry page, Config.

Taps that change the game (need **Settings > Packs can change games**):

| Tap | Writes |
|---|---|
| Soul Set: SET | the bullet / guardian / enchant slot byte |
| Equip: EQUIP | weapon / armor / accessory slot byte (only items you own, only the right slot kind) |
| Item Use: USE | HP or MP (healing items only, refused when full) and the item count - 1 |
| Ability: tap a soul | flips its bit in the ability switch byte |
| Config: < > / DEFAULT | the four button words; a clash is swapped away |

| Status: HEAL | uses the cheapest healing item that fills the gap (else the strongest) |

The game works out ATT / DEF / stat totals only when its pause menu opens. EQUIP therefore also writes the totals
itself with the game's own sums (ATT = STR + weapon/armor ATT, DEF = armor DEF + CON / 2, item stat bonuses; checked:
Claimh Solais gives 309 / 129 / 210 / 182 / 177, the game's numbers). Soul SET does not (enchant soul bonuses are not
mapped), so its totals refresh when the player pauses.

Live, without taps:

- **Alerts**: a banner over any page when a soul count rises (NEW SOUL / SOUL GET), the level rises (LEVEL UP), or a
  bestiary bit appears (NEW ENEMY DATA). Tap opens that soul / entry, X hides it, 6 s timeout. More than 3 changes in
  one tick (loading a save) only resets the comparison.
- **Equip preview**: picking gear shows the after-values in the stat window (cyan up, red down, AFTER tag).
- **Links**: an enemy entry's soul opens Soul Set / Ability on it, its drops open Equip / Item Use on them (an item
  you don't own shows NOT OWNED); Soul Set shows which seen enemies drop the soul.

## Sources

Every name, description and number is read from the player's ROM in `init()`; nothing from the game ships.
Art is original (`art/ui.py`), palette sampled from the game's menus (`art/ref/`).

## ROM (USA)

| Address | What |
|---|---|
| `0x08506BD8` | u32 string pointers (2855). Each string: 2 control bytes, then text; `0x06` newline, `0x0A` end, `0x0B..0x10` button pictures (Attack, Jump, Ability, Guardian, Up, Down) |
| strings | items 51-82, weapons 83-141, armor+accessories 142-186, souls 187-307, descriptions: items 308, weapons 340, armor 399, souls 444; enemies 565-677, enemy text 678-790 |
| `0x08505B38` | 32 items x 16: +4 id, +6 string, +8 price u32, +12 kind (0 HP, 1 MP %, 2 cure, 3 rotten, 4 key), +14 value |
| `0x08505D38` | 59 weapons x 28: +12 attack style (0 swing, 1 heavy, 2 thrust, 3 punch, 4 gun, 5 Valmanway), +14 ATT u16, +16..+19 STR CON INT LCK (s8) |
| `0x085063AC` | 45 armor + accessories x 20: +12 slot (0 body, 1 accessory; the capes are accessories), +14 ATT, +15 DEF, +16..+19 stats |
| `0x080E15A6` | bullet souls x 16: +8 MP (55 rows; the 56th bullet name, a second Cagnazzo, is unused) |
| `0x080E1938` | guardian souls x 12: +4 MP, +5 cost kind (1 = per second "/TIME") |
| `0x080E9644` | 113 enemies x 36: +8 / +10 drops (item id + 1), +12 HP, +14 MP, +16 EXP, +23 soul type, +24 soul id (1-based), +26 weak bits, +28 tolerance bits (slash, fire, water, thunder, dark, holy, poison, curse, stone) |
| EXP | total to reach level L+1 = 3L^3 + 20L^2 + 39L + 22 (no table; fits 12 levels read off the game) |

## RAM (EWRAM)

| Address | What |
|---|---|
| `0x020000A6` | u16 map rate in tenths of a percent |
| `0x020000AC` | u32 play time, frames (0 on the title screen) |
| `0x020000B4` / `0x020001F4` | explored map (Map page): 40 rows x 8 bytes (the row's u32 twice), low bit = left; columns 0-31 / 32-63; 848 cells = 100.0% (checked on the Lv 98 save against the game's map) |
| `0x020131EE` | u16 ATT, DEF, STR, CON, INT, LCK totals (written when the pause menu opens) |
| `0x02013268` | weapon (0-58) |
| `0x02013269/6A/6B` | bullet / guardian / enchant soul, 1-based, 0 = none |
| `0x0201326C` | body armor (index into the 45-row armor table) |
| `0x0201326D` | accessory (same table, slot kind 1) |
| `0x02013279` | level |
| `0x0201327A..80` | u16 HP, MP, max HP, max MP; then base STR, CON, INT, LCK |
| `0x0201328C` | u32 EXP; `0x02013290` u32 gold |
| `0x02013294` | 136 count bytes: items 0-31, weapons 32-90, armor 91-135 (the worn item is counted; the game's lists hide one) |
| souls | 4-bit counts, low nibble first: bullet `0x0201331C`, guardian `0x02013354`, enchant `0x0201336E`, ability `0x02013392` |
| `0x02013396` | ability switches, bit i = ability soul i |
| `0x02013398` | u16 buttons: Attack, Jump, Ability (`+4`), Guardian (`+6`); GBA key bits A 1, B 2, R 0x100, L 0x200 |
| `0x020133A0` | bestiary bits, bit k = enemy k+1 |

Soul rate = owned souls / 120 (the game's 99.1% with 119).

## Verified

- Headless mGBA with the user's Lv 98 save: every value above matched the game's own screens; every write was tested
  in the emulator (equip, souls, HP, ability bits, buttons, bestiary bits) and shown on the game's menus.
- `art/run.lua ROM DUMP` runs `main.lua` offline (also writes `preview-data.json` with `--preview`); action tests
  in the session scratchpad.
- `skill/preview-pack.sh` render: no warnings, all 8 pages.

## Not done

- Device check (writes through the app's permission flow, fonts at size, scrolling the band lists).
- Status ailments (STATUS / GOOD is fixed text), current area name, enemy sprites, the "recalculate" call.
- EU / JP releases.
