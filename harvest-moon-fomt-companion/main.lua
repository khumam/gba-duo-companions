-- Harvest Moon: Friends of Mineral Town (GBA) memory map, from
-- https://datacrystal.tcrf.net/wiki/Harvest_Moon:_Friends_of_Mineral_Town/RAM_map
-- and samurai goroh's code guide (the source that page cites):
-- http://www.erick.guillen.com.mx/Codes/GBA%20Harvest%20Moon%20FoMT.txt
--
-- Every address below is a "Stage 1" address. The game keeps its data there
-- unless it was started by loading the in-game (battery) save, in which case it
-- all lives 0x2834 higher ("Stage 2"). Save states keep whichever stage the
-- session started in, so the stage is detected on every update -- see
-- detectStage().

local item_names = pack.require("item_names")

local STAGE_2_OFFSET = 0x2834
local stageOffset = 0
local function at(stage1) return stage1 + stageOffset end

local MONEY_ADDR = 0x02004080
local WEATHER_TODAY_ADDR = 0x020025E0
local WEATHER_TOMORROW_ADDR = 0x020025E4
local YEAR_ADDR = 0x020025E8
local DAY_ADDR = 0x020025E9
local HOUR_ADDR = 0x020025EA
local HORSE_MEDALS_ADDR = 0x020065AC
local FRISBEE_RECORD_ADDR = 0x02004274

-- ---- Farmer ------------------------------------------------------------------
-- Stamina counts down from 0x7D, fatigue up to 0x64; the guide notes +0x80 reads
-- the same, so the top bit is masked off.
local STAMINA_ADDR = 0x020041F5
local FATIGUE_ADDR = 0x020041F6
local STAMINA_MAX = 0x7D
local FATIGUE_MAX = 0x64

-- ---- Rucksack ----------------------------------------------------------------
-- In-hand tool: tool id, then a state byte (1 while held).
-- Tool slots: 2 bytes each, tool id then a state byte (0 = empty slot).
-- Item slots / in-hand item: 4 bytes; byte 0 = category (0 = food, the fridge
-- table; 1 = goods, the cabinet table), byte 1 = id, byte 2 = 0 for an empty slot.
local HAND_ITEM_ADDR = 0x02004204
local HAND_TOOL_ADDR = 0x0200420C
local BAG_ITEMS_ADDR, BAG_ITEM_SIZE, BAG_ITEM_SLOTS = 0x02004214, 4, 8
local BAG_TOOLS_ADDR, BAG_TOOL_SIZE, BAG_TOOL_SLOTS = 0x02004238, 2, 8
local MAX_TOOL_ID = 0x50

-- Set true to log the raw bytes this script is least sure about
-- (adb logcat -s GBADuoPack).
local DEBUG_BYTES = false

-- Scores how much a stage looks like live game data. Year, date and clock have
-- tight ranges, so zeroed RAM (year 0) and the 0xBF fill the game leaves
-- elsewhere both fail. Gold and the in-hand tool alone weren't enough: the
-- empty-hand byte is 0x51 with state 0, and zeroed RAM reads as 0 gold.
local function stageScore(offset)
  local score = 0
  local year = mem.u8(YEAR_ADDR + offset)
  if year >= 1 and year <= 99 then score = score + 2 end
  local dayByte = mem.u8(DAY_ADDR + offset)
  if dayByte < 0x80 and (dayByte >> 2) <= 29 then score = score + 1 end
  local t = mem.u16(HOUR_ADDR + offset)
  if (t & 0x1F) <= 23 and ((t >> 5) & 0x3F) <= 59 then score = score + 1 end
  if mem.u32(MONEY_ADDR + offset) <= 999999 then score = score + 1 end
  if mem.u8(HAND_TOOL_ADDR + 1 + offset) <= 1 then score = score + 1 end
  return score
end

-- Stage 1 unless Stage 2 clearly scores higher. Checked on the EU cart: a game
-- continued from the battery save and one loaded from a save state both kept
-- their data at the Stage 1 addresses.
local function detectStage()
  if stageScore(STAGE_2_OFFSET) > stageScore(0) then return STAGE_2_OFFSET end
  return 0
end

local function toolName(id)
  return item_names.tools[id] or string.format("Tool #%02X", id)
end

local function itemName(category, id)
  local names = category == 0 and item_names.food or item_names.goods
  return names[id] or string.format("Item #%02X:%02X", category, id)
end

local function readItem(addr)
  if mem.u8(addr + 2) == 0 then return nil end
  local category, id = mem.u8(addr), mem.u8(addr + 1)
  if category > 1 then return nil end
  return itemName(category, id)
end

local function readTool(addr)
  local id = mem.u8(addr)
  if mem.u8(addr + 1) == 0 or id > MAX_TOOL_ID then return nil end
  return toolName(id), id
end

-- Tool ids come in blocks of eight upgrades (sickle 00-07, hoe 08-0F, ...),
-- then seeds and the animal tools; each block gets one icon.
local IMG = "asset:img/"
local TOOL_BLOCKS = { "sickle", "hoe", "axe", "hammer", "can", "rod" }
local TOOL_SINGLES = { [0x46] = "brush", [0x47] = "milker", [0x48] = "clippers", [0x49] = "bell" }

local function toolIcon(id)
  local kind = TOOL_BLOCKS[id // 8 + 1]
  if id >= 0x30 then kind = (id >= 0x32 and id <= 0x45) and "seeds" or TOOL_SINGLES[id] or "tool" end
  return IMG .. "tool-" .. kind .. ".png"
end

local function readBag()
  local handTool, handId = readTool(at(HAND_TOOL_ADDR))
  -- The held tool isn't in a rucksack slot, but the in-game rucksack lists it,
  -- so it leads the list here too.
  local tools, items = {}, {}
  if handTool then tools[1] = { name = handTool, held = true, icon = toolIcon(handId) } end
  for i = 0, BAG_TOOL_SLOTS - 1 do
    local name, id = readTool(at(BAG_TOOLS_ADDR) + i * BAG_TOOL_SIZE)
    if name then tools[#tools + 1] = { name = name, held = false, icon = toolIcon(id) } end
  end
  for i = 0, BAG_ITEM_SLOTS - 1 do
    local addr = at(BAG_ITEMS_ADDR) + i * BAG_ITEM_SIZE
    local name = readItem(addr)
    if name then
      items[#items + 1] = { name = name, icon = IMG .. (mem.u8(addr) == 0 and "tool-basket" or "tool-crate") .. ".png" }
    end
  end
  return {
    handTool = handTool or "Nothing",
    handIcon = handId and toolIcon(handId) or IMG .. "tool-tool.png",
    handItem = readItem(at(HAND_ITEM_ADDR)) or "Nothing",
    tools = tools,
    items = items,
    toolCount = #tools,
    itemCount = #items,
  }
end

local function hexBytes(addr, n)
  local t = {}
  for i = 0, n - 1 do t[#t + 1] = string.format("%02X", mem.u8(addr + i)) end
  return table.concat(t, " ")
end

-- ---- Date & time -----------------------------------------------------------
-- 0x020025E8 year; 0x020025E9 bits 0-1 season, bits 2-6 day of the season - 1;
-- 0x020025EA u16 bits 0-4 hour, bits 5-10 minute. (The guide lists the last two
-- as separate hour/minute bytes; on the device they're one bitfield.)
local SEASONS = { [0] = "Spring", "Summer", "Fall", "Winter" }

local function readDate()
  local dayByte = mem.u8(at(DAY_ADDR))
  return SEASONS[dayByte & 0x3], (dayByte >> 2) + 1
end

local function readTime()
  local t = mem.u16(at(HOUR_ADDR))
  return string.format("%02d:%02d", t & 0x1F, (t >> 5) & 0x3F)
end

-- ---- Affection ---------------------------------------------------------------
-- Bachelorettes (and the Goddess): u16, 0-65535, one heart colour per 10,000.
local GIRL_MAX = 65535
local HEART_STEP = 10000
local HEARTS = { "Black", "Purple", "Blue", "Green", "Yellow", "Orange", "Red" }
local HEART_COLORS = { "#6B5E57", "#A98BD8", "#6FA8DC", "#6DBB7C", "#D9A520", "#EE9150", "#E8718F" }
local BACHELORETTES = {
  { "Popuri", 0x02004358 }, { "Mary", 0x02004414 }, { "Karen", 0x020044A4 },
  { "Elli", 0x020044D0 }, { "Ann", 0x02004524 }, { "Harvest Goddess", 0x020045A4 },
}

-- Everyone else: one byte, 0-255.
local FRIEND_MAX = 255
local VILLAGERS = {
  { "Lillia", 0x02004324 }, { "Rick", 0x02004338 }, { "Barley", 0x02004364 }, { "May", 0x02004378 },
  { "Saibara", 0x0200438C }, { "Gray", 0x020043A4 }, { "Duke", 0x020043B8 }, { "Manna", 0x020043CC },
  { "Basil", 0x020043E0 }, { "Anna", 0x020043F4 }, { "Thomas", 0x02004420 }, { "Harris", 0x02004434 },
  { "Ellen", 0x02004448 }, { "Stu", 0x0200445C }, { "Jeff", 0x02004470 }, { "Sasha", 0x02004484 },
  { "Doctor", 0x020044B0 }, { "Carter", 0x020044DC }, { "Cliff", 0x020044F0 }, { "Doug", 0x02004504 },
  { "Kai", 0x02004530 }, { "Gotz", 0x02004544 }, { "Zack", 0x0200455C }, { "Won", 0x02004570 },
  { "Lou", 0x020045C4 }, { "Lu", 0x020045DC },
}

local function readLoves()
  local loves = {}
  for _, g in ipairs(BACHELORETTES) do
    local raw = mem.u16(at(g[2]))
    local heart = math.min(raw // HEART_STEP, #HEARTS - 1)
    loves[#loves + 1] = {
      name = g[1],
      value = raw,
      heart = HEARTS[heart + 1] .. " heart",
      heartColor = HEART_COLORS[heart + 1],
      heartIcon = IMG .. "heart-" .. HEARTS[heart + 1]:lower() .. ".png",
      pct = raw / GIRL_MAX,
    }
  end
  return loves
end

local function readFriends()
  local friends = {}
  for _, v in ipairs(VILLAGERS) do
    local raw = mem.u8(at(v[2]))
    friends[#friends + 1] = { name = v[1], value = raw, pct = raw / FRIEND_MAX }
  end
  return friends
end

-- ---- Harvest Sprites ---------------------------------------------------------
-- From each sprite's affection byte: +0x0C/+0x0D/+0x0E work experience
-- (harvesting, watering, animal care; 0-255) and +0x12 the job byte: low two
-- bits = job (3 = none), the next three = days left.
local XP_MAX = 255
local JOBS = { [0] = "Harvesting", "Watering", "Animal care" }
local SPRITES = {
  { "Staid", 0x020045F0 }, { "Nappy", 0x02004614 }, { "Bold", 0x02004638 }, { "Chef", 0x0200465C },
  { "Aqua", 0x02004680 }, { "Hoggy", 0x020046A4 }, { "Timid", 0x020046C8 },
}
local XP_KINDS = { { "HARVEST", 0x0C }, { "WATER", 0x0D }, { "ANIMALS", 0x0E } }

local function readSprites()
  local sprites = {}
  for _, s in ipairs(SPRITES) do
    local base = at(s[2])
    local jobByte = mem.u8(base + 0x12)
    local kind, days = jobByte & 0x3, (jobByte >> 2) & 0x7
    local working = kind ~= 3 and days > 0
    local xp = {}
    for _, k in ipairs(XP_KINDS) do
      local value = mem.u8(base + k[2])
      xp[#xp + 1] = { name = k[1], value = value, pct = value / XP_MAX }
    end
    local friendship = mem.u8(base)
    sprites[#sprites + 1] = {
      name = s[1],
      hat = IMG .. "sprite-" .. s[1]:lower() .. ".png",
      friendship = friendship,
      friendPct = friendship / FRIEND_MAX,
      job = working and string.format("%s · %d day%s", JOBS[kind], days, days == 1 and "" or "s") or "Free",
      working = working,
      xp = xp,
    }
  end
  return sprites
end

-- -----------------------------------------------------------------------------

local function fraction(value, max)
  return math.max(0, math.min(1, value / max))
end

-- Weather byte, from the code guide's "Set the Weather": 0 sunny, 1 rainy,
-- 2 snowy, 3 stormy and 4 blizzard (both keep you indoors).
local WEATHER = { [0] = "sunny", "rainy", "snowy", "stormy", "blizzard" }

local function weather(byte)
  local key = WEATHER[byte]
  return {
    name = key and (key:sub(1, 1):upper() .. key:sub(2)) or string.format("Weather #%d", byte),
    icon = IMG .. "weather-" .. (key or "unknown") .. ".png",
  }
end

local tick = 0

function update()
  stageOffset = detectStage()
  -- On the title screen neither stage holds a real date yet: empty RAM reads
  -- year 0, the title's leftovers read years like 180 or 220 (see stageScore).
  local year = mem.u8(at(YEAR_ADDR))
  if year < 1 or year > 99 or stageScore(stageOffset) < 4 then
    return { ready = false, waiting = true }
  end
  local season, day = readDate()
  local hour = mem.u16(at(HOUR_ADDR)) & 0x1F
  local stamina = mem.u8(at(STAMINA_ADDR)) & 0x7F
  local fatigue = mem.u8(at(FATIGUE_ADDR)) & 0x7F

  if DEBUG_BYTES then
    tick = tick + 1
    if tick % 8 == 0 then
      log(string.format("HM stage %d | date %s | hand item %s | hand tool %s", stageOffset == 0 and 1 or 2,
        hexBytes(at(WEATHER_TODAY_ADDR), 12), hexBytes(at(HAND_ITEM_ADDR), 4), hexBytes(at(HAND_TOOL_ADDR), 2)))
      log("HM bag items " .. hexBytes(at(BAG_ITEMS_ADDR), 32) .. " | tools " .. hexBytes(at(BAG_TOOLS_ADDR), 16))
    end
  end

  local seasonKey = season:lower()
  local money = mem.u32(at(MONEY_ADDR))
  local moneyText = tostring(money):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
  return {
    ready = true,
    waiting = false,
    money = money,
    moneyText = moneyText,
    year = mem.u8(at(YEAR_ADDR)),
    season = season,
    seasonKey = seasonKey,
    isSpring = seasonKey == "spring",
    isSummer = seasonKey == "summer",
    isFall = seasonKey == "fall",
    isWinter = seasonKey == "winter",
    corner = IMG .. "corner-" .. seasonKey .. ".png",
    cornerR = IMG .. "corner-" .. seasonKey .. "-r.png",
    -- Evening glow from 17:00, the night sky from 19:00 until 6:00.
    isDusk = hour >= 17 and hour < 19,
    isNight = hour >= 19 or hour < 6,
    day = day,
    time = readTime(),
    weatherToday = mem.u8(at(WEATHER_TODAY_ADDR)),
    weatherTomorrow = mem.u8(at(WEATHER_TOMORROW_ADDR)),
    today = weather(mem.u8(at(WEATHER_TODAY_ADDR))),
    tomorrow = weather(mem.u8(at(WEATHER_TOMORROW_ADDR))),
    horseRaceMedals = mem.u16(at(HORSE_MEDALS_ADDR)),
    frisbeeRecord = mem.u16(at(FRISBEE_RECORD_ADDR)),
    stamina = stamina,
    staminaPct = fraction(stamina, STAMINA_MAX),
    fatigue = fatigue,
    fatiguePct = fraction(fatigue, FATIGUE_MAX),
    bag = readBag(),
    loves = readLoves(),
    friends = readFriends(),
    sprites = readSprites(),
  }
end
