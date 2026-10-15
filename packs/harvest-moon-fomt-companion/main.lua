-- Harvest Moon: Friends of Mineral Town (GBA) memory map, from
-- https://datacrystal.tcrf.net/wiki/Harvest_Moon:_Friends_of_Mineral_Town/RAM_map
--
-- UNVERIFIED ON REAL HARDWARE: built from the wiki page alone, no access to
-- the actual ROM/save to confirm. Three specific assumptions, all easy to
-- flip here if testing shows them wrong -- see NOTES.md in this pack folder:
--
-- 1. Address "stage". The wiki documents two layouts: Stage 1 is immediately
--    after booting a fresh cart; Stage 2 (Stage 1 + 0x2834) is live once a
--    save is loaded and you're actually playing -- the normal case for
--    anyone using this companion. STAGE_OFFSET below picks Stage 2; set it
--    to 0 if Stage 1 turns out to be the one that's actually live.
-- 2. Affection max. The wiki gives the addresses but not the scale. FoMT's
--    10-heart display is widely documented elsewhere as 0-1000 (100/heart);
--    used only to size the heart bar below -- the raw number is always
--    shown too, so a wrong max never hides the real value.
-- 3. Weather byte meaning. The wiki doesn't give a code->condition mapping,
--    so the raw byte is shown as-is rather than guessing season/weather names.

local STAGE_OFFSET = 0x2834

local MONEY_ADDR = 0x02004080 + STAGE_OFFSET
local YEAR_ADDR = 0x020025E8 + STAGE_OFFSET
local DAY_ADDR = 0x020025E9 + STAGE_OFFSET
local HOUR_ADDR = 0x020025EA + STAGE_OFFSET
local MINUTE_ADDR = 0x020025EB + STAGE_OFFSET
local WEATHER_TODAY_ADDR = 0x020025E0 + STAGE_OFFSET
local WEATHER_TOMORROW_ADDR = 0x020025E4 + STAGE_OFFSET
local HORSE_MEDALS_ADDR = 0x020065AC + STAGE_OFFSET
local FRISBEE_RECORD_ADDR = 0x02004274 + STAGE_OFFSET

local AFFECTION_MAX = 1000
local BACHELORETTES = {
  { name = "Popuri", addr = 0x02004358 + STAGE_OFFSET },
  { name = "Mary", addr = 0x02004414 + STAGE_OFFSET },
  { name = "Karen", addr = 0x020044A4 + STAGE_OFFSET },
  { name = "Elli", addr = 0x020044D0 + STAGE_OFFSET },
  { name = "Ann", addr = 0x02004524 + STAGE_OFFSET },
  { name = "Harvest Goddess", addr = 0x020045A4 + STAGE_OFFSET },
}

function update()
  local loves = {}
  for _, b in ipairs(BACHELORETTES) do
    local raw = mem.u16(b.addr)
    local pct = raw / AFFECTION_MAX
    if pct > 1 then pct = 1 end
    if pct < 0 then pct = 0 end
    loves[#loves + 1] = { name = b.name, value = raw, pct = pct }
  end

  return {
    money = mem.u32(MONEY_ADDR),
    year = mem.u8(YEAR_ADDR),
    day = mem.u8(DAY_ADDR),
    time = string.format("%02d:%02d", mem.u8(HOUR_ADDR), mem.u8(MINUTE_ADDR)),
    weatherToday = mem.u8(WEATHER_TODAY_ADDR),
    weatherTomorrow = mem.u8(WEATHER_TOMORROW_ADDR),
    loves = loves,
    horseRaceMedals = mem.u16(HORSE_MEDALS_ADDR),
    frisbeeRecord = mem.u16(FRISBEE_RECORD_ADDR),
  }
end
