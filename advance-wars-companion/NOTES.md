# 0.3.0 (2026-11-24): the game's own intel screens, re-laid for touch
Design: `.idea/plans/aw-design2/aw-*.png` in the app repo; references in its `ref/` were captured from a Vs. Mode battle (the Field Training
tutorial locks the menus; harness recipe: intro, mode select, `u u` to Vs. Mode, then `a` x5 = Brace Range). Source: `art/layout.py`,
`art/style.src.css` (ap units, `python3 art/layout.py && python3 ../skill/tools/packkit/css.py .`); the 0.2 source is in `art/v2/`.
- Peach paper windows (row bands, ink line on the grey-green bevel, the caption on the top edge), the game's map menu as the nav on the
  right edge (glove on the open page), the DAY plate under it (day, funds, income). INTEL = Battle Intel (one row per army: units,
  army value, bases; the glove on whose turn) + Deployment tug bars; UNIT = the Unit table (two columns: sprite, name, cost, owned) +
  a unit dossier (cost, move, vision, fuel, ammo, range, yellow damage bars); TERRAIN = the tiles + the field's dark info panel (DEF
  stars, move cost per unit kind); MAP = the live minimap + one row per army.
- Readability: captions Silkscreen 7 ap / 0.8 ap tracking on an ink tab; names Jersey 12-16 ap with 0.3-0.5 ap tracking; small labels
  Jersey 10-11 ap in a muted brown; table headers are the game's own icons; taps 20 ap or more.
- `main.lua`: tiles carry `name`, `cost`, `ownedTxt`; chips carry `name`, `value`, `valueTxt`, `turn`; the minimap fits 336 x 270 dp.
- `assets/icons/ui/menu-intel-c.png`, `menu-unit-c.png`: the menu icons without the cursor sliver the first cut had.
- Not device-tested. Only Orange Star's funds are read (the address for the other armies is unknown), so Battle Intel shows army value.

# Advance Wars companion 0.2.0 (design: field console)

Art: unit sprites, coin, army crates, the DEF label and 8 terrain tiles are the game's own; the DAY plate and panels are CSS in the game's colours.

Redesigned from the game's own look (see `.idea/plans/aw-design/` in the app repo: real ROM captures, palette, concept renders).
Peach folder (dialog paper) on a slate table (menu panels), four icon-only edge tabs (FIELD, UNITS, TERRAIN, MAP), dark unit-info panel for
inspectors, ONE accent = the army whose turn it is (`--acc`, `--pill`, `--foe` set from Lua on `#screen`).
Old 0.1.x layout, style and tests: `art/orig/`.

## Read from the ROM at run time (USA Rev 1, AWRE) - verified against known Advance Wars values
| What | Where |
|---|---|
| Damage, main gun | `0x08283B48`, rows of 24 bytes by attacker unit id (row for id 1 first), column = defender id - 1 |
| Damage, machine gun | `0x08283D88`, same shape. Damage shown = max(main, MG) at full HP (the game uses the main gun while it has ammo and the value is not 0) |
| Defence stars x 10 | `0x08284314` + terrain id |
| Move cost | inside the unit record (`0x08283058` + 0x70 * id) at +0x4C + terrain id; 255 = cannot enter |
| Terrain ids | confirmed from a real map's codes: 1 plain, 3 mountain, 4 wood, 5 road, 6 city, 7 sea, 8 HQ. From the cost / defence tables: 2 river, 11 port, 13 shoal, 19 reef. **Inferred, not proven:** 10 airport, 12 bridge, 14 base (airport and base are interchangeable in every table) |

Checked: Tank vs inf 75 / tank 55 / md tank 15 / artillery 70, Md Tank 105 / 85 / 55, Sub vs ships 55, mountain 4 stars, wood 2, reef 1, tank blocked on river and mountain.

## Other addresses (from 0.1.x): day `0x03004420`, turn `0x03004424`, funds `0x0201AB9C` (Orange Star's only), unit records `0x02019F40`, map dims `0x030036E0`, terrain codes `0x02016C2A`.

## Not verified / open
- Income = properties (kinds 6, 8, 10, 11, 14) x 1000 for the turn army. Kinds 10 / 11 / 14 inferred (see above); the Field Training map has no properties to test with.
- The "top screen" box on MAP reads BG3 scroll (`0x0400001C/1E`); the Field Training map fits the screen, so a scrolling map is untested.
- Funds is only read for Orange Star (the one address known): the afford dots on UNITS are right on Orange's turn only.
- CO identity / power meter: address not found.
- Terrain tiles: plain, road, wood, mountain, river, bridge, city and HQ are the game's own, cut from screenshots of the Field Training maps
  (`assets/terrain/`; plain from the map's VRAM, via the ROM metatile table). Sea, reef, shoal, port, airport and base are still stand-in art drawn in
  code (`art/ui.py`): no lesson map shows them. The DEF number uses the game's own "Def" label (it has no stars: it prints a number).
- Not device-tested. Preview data (`preview-data.json`) is a mid-game mock built from the real ROM output plus made-up counts; `assets/_preview/` is preview-only (keep out of the zip).

## Rebuild
`python3 art/ui.py` (assets), `python3 art/layout.py` (layout.json), `python3 ../skill/tools/packkit/css.py .` (style.css from `art/style.src.css`).
