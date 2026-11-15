# Mario & Luigi: Superstar Saga companion: build notes

v0.1.0 (2026-11-13), US build (`A88E`, CRC32 F87EA3C3, the Virtual Console dump). Pages: PASSPORTS / BROS. INFO / ITEMS (Items and Beans tabs), cycled by
left / right plates. Previewed with the app's engine; `main.lua` run against the real ROM and a RAM dump. Not yet confirmed on the device.

In the game SELECT opens this menu (START does nothing in the field). The menu has Items, Equipment, Bros. Info and Beanbean Map.

## The look

A leather suitcase, like the game's own menu: a leather case framed like the game menu (black outline, light tan edge, orange-brown band, rust leather tile, dark brown lip; no dashed stitching), a checkered sage lining, and the things lying in it
as flat shapes with a dark outline and a hard translucent shadow (no bevels): the red / green passport booklets with a thin ring spine, the cream notebook
with a ring spine and ruled lines, leather belts with a gold buckle (solid tan and dark edge lines, no dashes) across the four corners of the lining (absolute boxes `.belt`, `transform: rotate(+-45deg)`, as in the game menu), a blue felt pad for the item list and the info bar (leather-edged), leather straps for the nav. Small tiles in `assets/ui`
(`lining`, `leather`, `leather-d`, `fabric`, `paper`) are repeated with `background-size`; everything else is CSS. `layout.json` and `style.css` are written by hand
(flex layout, dp units; borders and gaps are whole art pixels of 2.168 dp). Dark ink numbers on light rows, yellow only on dark surfaces (contrast).
Pages, cycled by the nav: Passports, Bros. Info, Items (Items / Beans tabs), Battle. Tap a passport to open its Bros. Info; the two round portraits on Bros. Info switch brother.

**Battle page (layout only):** enemy cards (letter badge, HP bar, HP), the selected enemy's sheet (HP / POW / DEF / SPD + a hint), the two brothers with HP / BP bars,
the info bar. Tapping an enemy sets `ui.foe`, tapping a brother sets `ui.who`; Lua returns `inBattle` / `noBattle`, `foes[]` (idx, name, n, hp, maxHp, hpPct, sel, down),
`foe`, `whoMario` / `whoLuigi`, `battleText`. **`main.lua` does not read a battle yet** (enemy addresses not found): it always reports `noBattle`. `preview-data.json` has a sample fight.
Only the brothers' portraits are pictures (`assets/gfx`: `mario.png` / `luigi.png` 26 x 38 and `round_*.png` 66 x 72, cut from the game's own menu).
README credits + disclaimer cover those. Font: Jersey 10.

Gotchas: a `button` lays its children out as a centred row, so a card that is a button needs `flex-direction: column`; never name a class `sel` for a layout
element (the selected list row gets a `sel` class too); `mem.u32` on the level tables (addresses ending in 2) reads the wrong word on the device, so they are
read byte by byte.

## How the data was found (no decompilation)

Headless mGBA (see the DBZ notes; `rom.sav` beside the ROM). Boot: Start, A, A, A, A loads file 1; SELECT opens the menu; D moves between the four entries.

| What | Address (US) | Notes |
|---|---|---|
| Mario stat block | EWRAM `0x02004840` (live copy; Luigi `+0x3C`) | `+0x1C` EXP (u32, low 24 bits), `+0x26` HP, `+0x2A` max HP, `+0x2C` BP, `+0x30` max BP, `+0x34` POW, `+0x38` SPEED, `+0x3C` DEF, `+0x40` STACHE (u16). Found by writing markers into the fields and reading the menu. A mirror at `0x02001E90` is **not** what the menu reads; writing the header (`+0x00..0x1A`) of the live copy crashes the game. |
| Level / NEXT | ROM `0x083BAEB2` (Mario, entry 0 = level 2) and `0x083BB34A` (Luigi, entry 0 = level 1): 12-byte entries, EXP in the first 4 bytes | level = number of thresholds reached (+1 for Mario's table); NEXT = the next threshold - EXP. Matches 4530 and 2779. The other 8 bytes of an entry are the stat growth. |
| Coins | `0x020048E0` (u16) | |
| Play time | IWRAM `0x03000370`, frames at 60 / s | 4250574 = 19:40 |
| Items | `0x020048E2`, one quantity byte per item in the menu's order (Mushrooms, Super, Ultra, Max, Nuts ... Green Peppers, then the Blends) | shown when 1-99 (the game keeps 0 / 255 in unused slots) |
| Beans | `0x02004902`, four bytes (Woo, Hoo, Chuckle, Hee) | |
| Names / descriptions | ASCII in the ROM; item pointer table `0x083BB7F4` (name, description, 8 bytes each; in ROM order, not menu order), bean table `0x083BCCD4` | |

## Not done

- **Equipment** (pants / badge / accessory per brother, plus hammer, boots and gloves) and the **Beanbean Map** are not mirrored. The equipped ids were not found:
  the table indices (pants 23 / 21, badge 22, accessories 0 / 2) do not appear next to the stat block; the game only lets a brother wear his own gear, so the
  menu could not be used to change one and diff RAM.
- **Key Items** (Beanbean Map, Peasley's Rose, Beanbean Brooch, Membership Card, Winkle Card, Spangle, Secret Scroll) are not read.
- No equipment box on Bros. Info, and no location name.
- Blends (Woohoo ... Teeheespresso) are read from the item array but the live count of a freshly mixed blend is unverified.

## Build

Nothing to build: edit `layout.json` / `style.css` and preview with
`skill/preview-pack.sh mario-luigi-superstar-saga-companion --pages pass,info,items --no-tall`.
Zip for release: manifest.json layout.json style.css main.lua assets.


## Battle (read live; found 2026-11-13 by diffing device states of a Goomba fight and the opening Bowser fight)

The fight lives in 8 battler slots of 0x130 bytes; IWRAM 0x03003FA4 holds a pointer to each of them (8 pointers in a row),
because they sit at a different EWRAM address every battle (0x0200A56C for Mario in the Goomba fight, 0x0200A20C in the
Bowser fight) - never read a fixed address. Slots 0-5 are the enemies, 6 is Mario, 7 is Luigi; an empty slot is zeros
(Luigi's is empty in the Bowser fight). Inside a slot, from +0xF4:

| Offset | What |
|---|---|
| +0xF4 | header word: 0x0106 Mario, 0x0107 Luigi, 0x63nn an enemy (nn = its slot) |
| +0xF6 / +0xF8 | HP / max HP (bros and enemies; enemies checked: Goomba 4/4 -> 2/4 after Mario's hit, Bowser 5006) |
| +0xFC / +0xFE | BP / max BP (bros) |
| +0x102 / +0x104 / +0x106 / +0x108 | POW / DEF / SPEED / STACHE (bros; same numbers as the stat block) |
| +0xEC | an enemy's type id: Goomba 12, Bowser 85 |

The stat block at 0x02004840 only updates after the fight, so the battle slots give the live HP/BP.
**Detecting a battle:** the screen must be in the battle layout (BG0CNT 0x04000008 = 0x5A03 and BG2CNT 0x0400000C = 0x1E04,
the same in the Goomba and Bowser fights, different in the field and menus) and Mario's slot must be filled; the slots
are not cleared when the fight ends, so the screen is the end-of-fight signal.
**Enemy names are not mapped.** The ROM has an English enemy-name list (0x0021B380 on, Goomba first, Bowser the 66th) but the
battle ids do not match its order (Goomba 12 vs entry 0, Bowser 85 vs entry 65), so only the two ids seen are named;
other enemies show "Enemy #id". Enemy POW / DEF / SPEED are not read.
