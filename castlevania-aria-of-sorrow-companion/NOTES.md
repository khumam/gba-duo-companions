# Castlevania: Aria of Sorrow companion: notes

USA cartridge only (`A2CE`, v0). Started 2026-11-21. Version 0.1.0, **not yet checked on a device**.

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
- Status ailments (STATUS / GOOD is fixed text), current area name, player marker on the map, enemy sprites, the "recalculate" call.
- EU / JP releases.
