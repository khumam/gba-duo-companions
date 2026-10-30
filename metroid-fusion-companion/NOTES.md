# Metroid Fusion companion — build notes

Sources: [Data Crystal's RAM map](https://datacrystal.tcrf.net/wiki/Metroid_Fusion/RAM_map)
and the [metroidret/mf](https://github.com/metroidret/mf) decompilation, which agree:
`linker.ld` puts `gEquipment` at `0x03001310`, `gCurrentArea` at `0x0300002C`,
`gInGameTimer` at `0x03000138` and `gMainGameMode` at `0x03000BDE` (all IWRAM).

- **Equipment** is `struct Equipment` (`include/structs/samus.h`): energy, max energy,
  missiles, max missiles (u16 each), power bombs, max, then the beam (`BF_*`), weapon
  (`MBF_*`) and suit/move (`SMF_*`) bitfields from `include/constants/samus.h`,
  security level, downloaded maps and the low-health flag.
- **Energy** shows like the game: tanks = (max − 99) / 100, the big number is
  energy mod 100, a tank is full while energy covers it.
- **Not loaded yet:** `ready = false` unless the game mode is in-game, map screen,
  cutscene or SA-X close-up (1, 3, 4, 5 in `enum GameMode`) and max energy is
  99 + 100n.
- **Sectors:** area 0 Main Deck, 1-6 Sectors 1-6 (`enum Area`). The seven bytes from
  `0x0300003B` are each area's percentage, as the wiki lists them.

Checked on a Thor (US `AMTE`, early Main Deck save, 2026-10-29): energy and max energy,
missiles, mission time, area and room, security level 0 (matches the map screen's
L1-L4 LOCK) and the Main Deck percentage all read correctly.

## Look (v2, 2026-10-30)

Rebuilt like the Zero Mission pack from the game's own pause screens (`art/ref/*`, taken on the Thor
with tilt-shift off): silver frame, teal L / R tabs, green sector plate and counter panels, cyan item
banners, the blue "owned" bar, navy grid. Five pages that cycle with the tabs like the game's L / R:
MAP, STATUS, ARMS, SECTORS, MISSION. The old v1 (the game's baked tilemaps with glyph digits) is in `art/v1/`.

Build: `python3 art/fusion.py` draws the sprites into `assets/ui` (Pillow); `python3 art/css.py` expands
`ap` units in `art/style.src.css` to `style.css` (1ap = 2.168px = 5 device px, screen 248 x 216 ap);
`node art/layout.mjs` writes `layout.json`. Edit the sources, not the outputs.

Drawn from the player's ROM (US build, `AMTE` only; other regions get "US ROM ONLY") with `gfx.tilemap`,
so no Nintendo graphics ship: Samus on her grid (status tilemap `0x085748AC`, tiles 9-19 x 5-19), the title
logo, and the live area map. The map is `gMinimapData_Visited` (EWRAM `0x02034000`) with the raw minimap
tiles at ROM `0x08561FA8`: an 18x9 cell window centred on Samus (`gMinimapX/Y` = `0x03000031/32`), each map
pixel 8 device px. gfx images are cached by arguments, not contents, so a changed map is read through the
next 256 KB EWRAM mirror (same memory, new key). A navy overlay (`.map-dim`) tones the raw palette's
glaring blue toward the game's own colours (the game blends them at runtime).

Mission: `gEventCounter` = `0x03000B87` (found from `EventSet`, ROM `0x08074890`, and consistent on the
Thor: step 9 after the first data room, "next: Morph Ball"). Event numbers are the order of `enum Event` in
the decomp's `include/constants/event.h`; EventSet(n) stores n when event n happens, so counter >= n means
it has. Bosses are read from the events they hand over (Arachnus: Charge Beam 15, Serris: Speed Booster 29,
Yakuza: Space Jump 73, Nightmare: Gravity Suit 81) plus B.O.X. 40, SA-X 102, Omega Metroid 108. Those four
drop-based ones are inferred from the game's story, not read from a boss flag: check them on a later save.
Security levels come from `gSecurityHatchLevel` (0x0300001C); the "next" line walks `MILESTONES` in main.lua.

Checked on the Thor (US, early Main Deck save, 2026-10-30): all five pages with live values, the waiting
screen with the real logo, hatches L1-L4 locked (level 0), mission step 9 of 109.

Not checked on a device yet: boss rows and security levels past the first data rooms, downloaded-map flags
(read as bit n = area n), EU/JP (the decomp and the wiki describe the US build; the manifest also matches
`AMTP` and `AMTJ`, but the ROM art offsets are US only).
