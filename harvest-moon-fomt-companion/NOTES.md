# Harvest Moon: Friends of Mineral Town companion — build notes

Sources: https://datacrystal.tcrf.net/wiki/Harvest_Moon:_Friends_of_Mineral_Town/RAM_map
and the code guide it cites,
http://www.erick.guillen.com.mx/Codes/GBA%20Harvest%20Moon%20FoMT.txt (rucksack,
held tool, stamina, villager/sprite affection, sprite work experience, item ids).

Checked on the Thor with the European cart (`A4NP`), from a save state:

- **Stage.** The guide's addresses are "Stage 1"; after loading the in-game
  (battery) save everything moves up by `0x2834` ("Stage 2"). Save states keep
  the stage the session started in. `detectStage()` in `main.lua` scores both
  stages on year, date, clock, gold and held-tool state every update and keeps
  Stage 1 unless Stage 2 scores higher. On the EU cart, continuing from the
  battery save *and* loading a save state both kept the data at the Stage 1
  addresses (one copy of the gold in all of EWRAM, nothing at +0x2834). Stage 2
  hasn't been seen on a device yet.
- **Empty hand** is tool byte `0x51` with state `0`, so the tool id alone can't
  tell a valid stage from garbage. The old check rejected Stage 1 whenever the
  hand was empty.
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
- **Weather** byte per the guide's "Set the Weather": 0 sunny, 1 rainy, 2 snowy,
  3 stormy, 4 blizzard (its Stage 2 address, `0x02004E14`, matches the +0x2834
  model). Anything else shows as "Weather #n".
- **Not loaded yet:** `update()` returns `ready = false` (the welcome sign) unless
  the year is 1-99 and the stage scores at least 4. Empty RAM scores 4 with year 0,
  the title screen's leftovers read years like 180/220, so the year check matters.
- **Design** ("The Mineral Town Almanac"): the backdrop follows the season
  (`classIf` on `#screen`), a dusk tint shows 17:00-18:59 and a night sky
  19:00-5:59. Art is drawn in `art/build.mjs`; tool icons map by id block.

Set `DEBUG_BYTES = true` in `main.lua` to log the raw rucksack/date bytes
(`adb logcat -s GBADuoPack`).
