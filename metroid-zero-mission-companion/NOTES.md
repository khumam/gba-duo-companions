# Metroid: Zero Mission companion: build notes

Design stage (v2 look, 2026-10-30). `layout.json`, `style.css` and `assets/ui` are done and
previewed with the app's engine; `main.lua` is still a stub that only shows the waiting
screen. The shape `update()` must return is `preview-data.json`.

## The look

Rebuilt from the game's own pause screens (`art/ref/pause-map.png`, `pause-status.png`,
`samus-data.png`, taken on the Thor with tilt-shift off; `*-native.png` are downsampled to
the GBA's 240x160 for colour sampling): steel frame, lavender L/R tabs and sector plate,
teal grid (olive on the map page), mint banners, blue "equipped" bars, olive save-slot rules.
All art is original (no game graphics). v1, the "Zero-OS" cyber terminal, is in `art/v1/`.

Pages cycle like the game's L/R: map -> status -> sectors -> log. Each tab navigates to the
neighbour (see `PAGES` in `art/layout.mjs`).

## Build

- `python3 art/pause.py` draws every sprite into `assets/ui` (needs Pillow; `--sheet` writes
  `art/sheet.png`). `python3 art/css.py` expands `ap` units in `art/style.src.css` to
  `style.css`. `node art/layout.mjs` writes `layout.json`. Edit the sources, not the output.
- 1 art px (ap) = 5 device px = 2.168dp; the screen is 248 x 216 ap. Pixel fonts are 8 units
  tall, so `font-size: 8ap` = one font pixel per art pixel.
- Preview: `skill/preview-pack.sh metroid-zero-mission-companion --pages map,status,sectors,log
  --no-tall` (the nav isn't auto-detected with L/R tabs, so use `--pages`). Waiting state:
  `--data` with `{"waiting":true,"ready":false}`. Last renders are in `art/preview/`.

## State (2026-10-30)

`main.lua` is real and tested on the Thor (European VC build, BMXP, save A). Live: energy, ammo,
tanks, area, room, game time, owned/active beams and gear, per-area percentages, tank counts, boss
kills and the area map. Addresses: IWRAM from Data Crystal + the metroidret/mzm decomp (identical in
the US and EU builds, checked; JP assumed); EWRAM `gEventsTriggered` = 0x02037E00 (found from
`EventFunction`'s literal pool, ROM 0x080608BC in the US build, and confirmed: the same 32 bytes sit in
the save file) and the minimap arrays from `include/structs/minimap.h`.

- **Logo:** drawn from the player's ROM (`gfx.tilemap` on `title.gfx.lz` / `title.tt` / `palette.pal`),
  two stacked images so the (R) mark (another palette bank) is left out.
- **Map:** `gDecompressedMinimapVisitedTiles` (0x02034000, 32x32 u16 entries; explored rooms already have
  their colour bank) drawn with the ROM's `minimap_tiles.gfx` + `.pal`, an 18x10 cell window centred on
  Samus (`gMinimapX/Y` = 0x03000059/5A), each map pixel 8 device px (3.4688dp; the .map-frame/.map-pan
  sizes in the CSS are 144x80 px at that scale), under a banner with the area and room. `gfx.*` caches by arguments, not
  contents, so when the RAM changes it's read through the next 256 KB EWRAM mirror (same memory, new key).
- **Samus figure (ships in the pack):** `assets/ui/samus-power.png` / `samus-full.png` are the game's own
  status-screen suit art, cut out by `python3 art/samus.py <US or EU rom>` (7 sprite parts from
  `tank_icons.gfx.lz`, 2D tile mapping, palette row 0 of `samus_wireframe.pal`). The graphics API can't
  crop a compressed sprite sheet, so unlike the logo and map these two PNGs are Nintendo art inside the
  pack; mention them in the repo README's credits/disclaimer before a release. `main.lua` picks the full
  suit art when `gEquipment.suitType` (0x03001542) is 1.
- **Bosses:** kill events Deorem 27, Acid Worm 28, Kraid 30, Imago 35, Ridley 37, Mother Brain 39,
  Crocomire 40, Mecha Ridley 74 (decomp `constants/event.h`). Mapping not exercised on a real kill yet:
  save A is at 58 s, so all eight read as active.
- **Toggles:** `actions.toggle` flips the item's bit in the active byte (manifest asks `memory-write`,
  Settings > Packs can change games, per-pack consent dialog). Needs the player to answer the dialog.

Debug trick: a script error lands in the value `_scriptError`, not logcat. Push a temporary layout
with a text bound to `{dbg}` and have `update()` return `{ dbg = "..." }` to read RAM on the device.
The decomp's `database.json` has US/EU/JP ROM offsets for every data blob; function doc comments in
`src/*.c` give each function's ROM address (disassemble with capstone to read its RAM pointers).

## Still to do

- Tap a toggle after allowing writes and confirm the activation byte flips (and flips back).
- Bosses: confirm against a real kill (a later save).
- Preview needs images the app draws at runtime: copy sample PNGs into `assets/_preview/` for the run
  (map: `asset:_preview/map.png`; waiting: `art/preview-waiting.json`), delete them after; they must
  not ship.
