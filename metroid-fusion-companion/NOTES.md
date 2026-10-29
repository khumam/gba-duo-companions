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

Look: the game's own pause screens. `main.lua` draws them from the player's ROM with
`gfx.tilemap` (US build only, `AMTE`; other regions show "US ROM ONLY"):

- bg tiles `0x0856A254` (LZ77), palette `0x085657A8` (minimap rows 0-2 then bg rows 3-15,
  contiguous), status tilemap `0x085748AC`, map-screen frame `0x085740FC`.
- Item windows are cropped one row at a time from the status tilemap's lower half, and
  dimmed with opacity when the upgrade is missing.
- The minimap is `gMinimapData_Visited` (EWRAM `0x02034000`, 32x32 tilemap kept up to date
  by the game) drawn with the raw minimap tiles at ROM `0x08561FA8`. gfx images are cached
  by their arguments, so each change draws from another EWRAM/ROM mirror (144 keys cycle).
  It shows the current area only; Samus's cell is `gMinimapX/Y` (`0x03000031/32`).
- Text is set in the game's font as glyph PNGs (`assets/font`, from `art/rom-font.py`; the
  only game graphics the zip carries). Digit rows are opaque so they cover the placeholder
  numbers baked into the status tilemap.
- `node art/layout.mjs` writes `layout.json`. Previews can't render ROM art: use the device.
- Map colours are the raw palette (magenta/green/grey); the game blends them toward lilac.

Not checked on a device yet:

- **Ability bits, tanks, hatches 1-4:** needs a save past the first data rooms.
- **Downloaded maps:** read as bit n = area n; the wiki only lists the bit values.
- **EU/JP:** the decomp and the wiki describe the US build (`AMTE`); the pack also
  matches `AMTP` and `AMTJ` on the assumption IWRAM is laid out the same.
