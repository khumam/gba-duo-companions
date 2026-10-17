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

Not checked on a device yet:

- Everything — no Metroid Fusion cart has been tested.
- **Downloaded maps:** read as bit n = area n; the wiki only lists the bit values.
- **EU/JP:** the decomp and the wiki describe the US build (`AMTE`); the pack also
  matches `AMTP` and `AMTJ` on the assumption IWRAM is laid out the same.
