# Harvest Moon: Friends of Mineral Town companion — build notes

Built from https://datacrystal.tcrf.net/wiki/Harvest_Moon:_Friends_of_Mineral_Town/RAM_map
alone. **Not verified against the real ROM/save** — I don't have it. Three
assumptions worth checking once you can test on real hardware, all isolated
to single, easy-to-edit spots:

1. **Game code.** `manifest.json`'s `match.gameCode` is `["BHFE"]`, my best
   recollection of the US cart code. If the companion never loads for your
   ROM, this is the first thing to check — `adb logcat` or the pack-mismatch
   message will show the actual code your ROM reports.

2. **Address "stage".** The wiki documents two address layouts: *Stage 1* is
   immediately after booting a fresh cart; *Stage 2* (Stage 1 + `0x2834`) is
   live once a save is loaded and you're actually playing — the normal case
   for anyone using a companion. `main.lua` defaults to Stage 2 via the
   `STAGE_OFFSET` constant at the top of the file. If every value reads as 0
   or garbage, set `STAGE_OFFSET = 0` and retest.

3. **Affection max.** The wiki gives the six bachelorette/Goddess addresses
   but not the point scale. FoMT's 10-heart display is commonly documented
   elsewhere as 0–1000 (100 per heart) — used in `main.lua` only to size the
   heart bar's fill fraction. The raw number is always shown next to the bar
   too (`{value} / 1000`), so if the real max is different, the bar will just
   look over/under-full while the number stays accurate.

4. **Weather byte.** No code→condition mapping was documented, so the raw
   byte is shown as-is (`Today: {weatherToday}`) rather than guessing season
   or weather names. Play a save, note which byte value corresponds to which
   real condition, and I can turn that into a proper label/icon mapping.

Also not implemented yet (real scope cuts, not oversights): farm/farmer name
decoding (stored as reversed 32-bit groups, not a simple string), shipping
history (61-item bitfield table), crop/animal state, house upgrades.
