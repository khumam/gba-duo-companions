# Harvest Moon: Friends of Mineral Town companion — build notes

Sources: https://datacrystal.tcrf.net/wiki/Harvest_Moon:_Friends_of_Mineral_Town/RAM_map
and the code guide it cites,
http://www.erick.guillen.com.mx/Codes/GBA%20Harvest%20Moon%20FoMT.txt (rucksack,
held tool, stamina, villager/sprite affection, sprite work experience, item ids).

Checked on the Thor with the European cart (`A4NP`), from a save state:

- **Stage.** The guide's addresses are "Stage 1"; after loading the in-game
  (battery) save everything moves up by `0x2834` ("Stage 2"). Save states keep
  the stage the session started in. `detectStage()` in `main.lua` picks the stage
  whose gold and held tool read as plausible values, every update. Stage 1 is
  verified; Stage 2 hasn't been seen on a device yet.
- **Verified:** gold, held tool, rucksack tools (the held tool is listed first),
  empty item rucksack, season/day, clock.
- **Date & time are bitfields**, not the separate bytes the guide lists:
  `0x020025E9` = season (bits 0-1) + day-1 (bits 2-6); `0x020025EA` u16 = hour
  (bits 0-4) + minute (bits 5-10).
- **Affection** for villagers and sprites is byte +8 of each person's 0x14-byte
  record (the guide's addresses). Values read 49-50 early in a game, which looks
  like a real starting value, but talking to Sasha didn't move hers right away —
  not yet confirmed that it rises when expected.
- **Bachelorette scale** follows the guide: u16, 0-65535, a new heart colour
  every 10,000. Not seen above 0 on the device yet.
- **Rucksack item slots** (4 bytes: category, id, non-zero when filled) were
  only seen empty. The guide documents the ids, not the empty-slot marker.
- **Weather** is still shown as the raw byte (0 = sunny per the guide).

Set `DEBUG_BYTES = true` in `main.lua` to log the raw rucksack/date bytes
(`adb logcat -s GBADuoPack`).
