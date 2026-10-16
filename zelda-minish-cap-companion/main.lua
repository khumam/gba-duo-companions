-- The Legend of Zelda: The Minish Cap (GBA) memory map, from the zeldaret/tmc
-- decompilation (include/save.h, include/player.h, linker.ld):
-- https://github.com/zeldaret/tmc
-- and samurai goroh's code guide, which agrees with it:
-- http://www.erick.guillen.com.mx/Codes/GBA%20The%20Legend%20of%20Zelda%20Minish%20Cap.txt
--
-- Everything the save file holds lives in one struct, gSave, at a fixed
-- address in every release (US, EU and JP share the EWRAM layout).

local item_names = pack.require("item_names")
local area_names = pack.require("area_names")

local SAVE = 0x02002A40

-- ---- Save header -------------------------------------------------------------
local SAVE_INVALID = SAVE + 0x000
local SAVE_INITIALIZED = SAVE + 0x001
local ENEMIES_KILLED = SAVE + 0x050  -- u32
local FILE_NAME, FILE_NAME_LEN = SAVE + 0x080, 6

-- ---- Stats (gSave + 0xA8) ----------------------------------------------------
local STATS = SAVE + 0x0A8
local WALLET_TYPE = STATS + 0x00
local HEART_PIECES = STATS + 0x01
local HEALTH = STATS + 0x02      -- 8 per heart, 2 per quarter
local MAX_HEALTH = STATS + 0x03
local BOMBS = STATS + 0x04
local ARROWS = STATS + 0x05
local BOMB_BAG_TYPE = STATS + 0x06
local QUIVER_TYPE = STATS + 0x07
local CHARM = STATS + 0x0A       -- bottle item id of the active charm, 0 = none
local PICOLYTE = STATS + 0x0B    -- bottle item id of the active picolyte, 0 = none
local EQUIPPED_A = STATS + 0x0C
local EQUIPPED_B = STATS + 0x0D
local BOTTLES = STATS + 0x0E     -- 4 bytes, bottle contents
local RUPEES = STATS + 0x18      -- u16
local SHELLS = STATS + 0x1A      -- u16
local CHARM_TIMER = STATS + 0x1C -- u16, frames
local PICOLYTE_TIMER = STATS + 0x1E

-- Indexed by the *Type bytes above (itemUtils.c).
local WALLET_SIZES = { [0] = 100, 300, 500, 999 }
local BOMB_BAG_SIZES = { [0] = 10, 30, 50, 99 }
local QUIVER_SIZES = { [0] = 30, 50, 70, 99 }

-- ---- Collections ---------------------------------------------------------------
local FIGURINES, FIGURINE_BYTES, FIGURINE_TOTAL = SAVE + 0x0D0, 36, 136
local INVENTORY = SAVE + 0x0F2   -- 2 bits per item id
local KINSTONES = SAVE + 0x114
local FUSED_COUNT = KINSTONES + 0x03
local BAG_TYPES = KINSTONES + 0x04
local BAG_AMOUNTS = KINSTONES + 0x17
local BAG_SLOTS = 18             -- the game only fills 0x12 of the 19
local FUSION_TOTAL = 100

-- ---- Flags and dungeons --------------------------------------------------------
local GLOBAL_FLAGS = SAVE + 0x25C  -- bit n = global flag n
local DUNGEON_KEYS = SAVE + 0x45C  -- indexed by dungeon id
local DUNGEON_ITEMS = SAVE + 0x46C -- 1 = map, 2 = compass, 4 = big key

-- Dungeon ids are the LVn of the LVn_CLEAR global flags (flag n + 1).
local DUNGEONS = {
  { 1, "Deepwood Shrine", "Earth Element" },
  { 2, "Cave of Flames", "Fire Element" },
  { 3, "Fortress of Winds", "Ocarina of Wind" },
  { 4, "Temple of Droplets", "Water Element" },
  { 5, "Palace of Winds", "Wind Element" },
  { 6, "Dark Hyrule Castle", "Vaati" },
}

-- ---- Where Link is -------------------------------------------------------------
local ROOM_AREA = 0x03000BF4      -- gRoomControls.area (IWRAM)
local AREA_DUNGEON_IDX = 0x02033A93 -- gArea.dungeon_idx
local AREA_FLAGS = 0x02033A90       -- gArea.areaMetadata, 2 = area has keys

-- -----------------------------------------------------------------------------

local function hasItem(id)
  return (mem.u8(INVENTORY + id // 4) >> ((id % 4) * 2)) & 3 ~= 0
end

local function flag(n)
  return (mem.u8(GLOBAL_FLAGS + n // 8) >> (n % 8)) & 1 == 1
end

local function popcount(addr, bytes)
  local n = 0
  for i = 0, bytes - 1 do
    local b = mem.u8(addr + i)
    while b ~= 0 do
      n = n + (b & 1)
      b = b >> 1
    end
  end
  return n
end

local function fraction(value, max)
  if max <= 0 then return 0 end
  return math.max(0, math.min(1, value / max))
end

local IMG = "asset:img/"

-- 8 health per heart, 2 per quarter: 27 -> "3¼".
local QUARTERS = { [0] = "", "¼", "½", "¾" }
local function hearts(health)
  return tostring(health // 8) .. QUARTERS[(health % 8) // 2]
end

-- One entry per heart container, each drawn with 0-4 quarters filled.
local function heartRow(health, maxHealth)
  local row = {}
  for i = 0, maxHealth // 8 - 1 do
    local quarters = math.max(0, math.min(8, health - i * 8)) // 2
    row[#row + 1] = { src = IMG .. "heart-" .. quarters .. ".png" }
  end
  return row
end

local function equipName(id)
  if id == 0 then return "Nothing" end
  return item_names.equip[id] or string.format("Item #%02X", id)
end

local function bottleName(id)
  return item_names.bottle[id] or string.format("Item #%02X", id)
end

local function fileName()
  local chars = {}
  for i = 0, FILE_NAME_LEN - 1 do
    local c = mem.u8(FILE_NAME + i)
    if c == 0 then break end
    if c >= 0x20 and c < 0x7F then chars[#chars + 1] = string.char(c) end
  end
  return #chars > 0 and table.concat(chars) or "Link"
end

-- A loaded file is initialized, not marked invalid, and has 3-20 hearts.
-- Before that (title screen, file select) the struct holds leftovers.
local function saveLoaded()
  local maxHealth = mem.u8(MAX_HEALTH)
  return mem.u8(SAVE_INITIALIZED) == 1 and mem.u8(SAVE_INVALID) == 0
    and maxHealth >= 24 and maxHealth <= 160 and maxHealth % 8 == 0
end

-- ---- Link --------------------------------------------------------------------

local function readBuff(itemAddr, timerAddr)
  local id = mem.u8(itemAddr)
  if id == 0 then return nil end
  local seconds = mem.u16(timerAddr) // 60
  return string.format("%s · %d:%02d", bottleName(id), seconds // 60, seconds % 60)
end

local function readBottles()
  local bottles = {}
  for i, slot in ipairs(item_names.bottles) do
    if hasItem(slot) then
      local id = mem.u8(BOTTLES + i - 1)
      bottles[#bottles + 1] = { name = bottleName(id), empty = id == 0x20 }
    end
  end
  return bottles
end

local function readLocation()
  local area = mem.u8(ROOM_AREA)
  return area_names[area] or string.format("Area %02X", area)
end

-- ---- Items -------------------------------------------------------------------

local function readGear()
  local gear = {}
  for _, group in ipairs(item_names.gear) do
    for i = 2, #group do
      if hasItem(group[i][1]) then
        gear[#gear + 1] = { name = group[i][2] }
        break
      end
    end
  end
  return gear
end

local function readOwned(list)
  local out = {}
  for _, entry in ipairs(list) do
    out[#out + 1] = { name = entry[2], owned = hasItem(entry[1]) }
  end
  return out
end

local function readElements()
  local out = readOwned(item_names.elements)
  for _, e in ipairs(out) do
    e.src = IMG .. (e.owned and "element-" .. e.name:lower() or "element-empty") .. ".png"
  end
  return out
end

local function countOwned(list)
  local n = 0
  for _, entry in ipairs(list) do
    if entry.owned then n = n + 1 end
  end
  return n
end

local function readQuest()
  local out = {}
  for _, entry in ipairs(item_names.quest) do
    if hasItem(entry[1]) then out[#out + 1] = { name = entry[2] } end
  end
  return out
end

-- ---- Kinstones ---------------------------------------------------------------

local function readBag()
  local pieces, total = {}, 0
  for i = 0, BAG_SLOTS - 1 do
    local id = mem.u8(BAG_TYPES + i)
    local amount = mem.u8(BAG_AMOUNTS + i)
    if id ~= 0 and amount > 0 then
      local color, place = item_names.kinstone(id)
      pieces[#pieces + 1] = {
        color = color,
        src = IMG .. "kinstone-" .. (color == "?" and "gold" or color:lower()) .. ".png",
        isGold = color == "Gold",
        isRed = color == "Red",
        isBlue = color == "Blue",
        isGreen = color == "Green",
        name = place or string.format("%s piece", color),
        id = string.format("#%02X", id),
        amount = amount,
      }
      total = total + amount
    end
  end
  return pieces, total
end

-- ---- Dungeons ----------------------------------------------------------------

local function readDungeons(currentIdx)
  local out = {}
  for _, d in ipairs(DUNGEONS) do
    local idx = d[1]
    local items = mem.u8(DUNGEON_ITEMS + idx)
    out[#out + 1] = {
      name = d[2],
      prize = d[3],
      cleared = flag(idx + 1),
      here = idx == currentIdx,
      keys = mem.u8(DUNGEON_KEYS + idx),
      map = items & 1 ~= 0,
      compass = items & 2 ~= 0,
      bigKey = items & 4 ~= 0,
    }
  end
  return out
end

-- -----------------------------------------------------------------------------

function update()
  if not saveLoaded() then
    return { ready = false, waiting = true }
  end

  local health, maxHealth = mem.u8(HEALTH), mem.u8(MAX_HEALTH)
  local rupees, walletMax = mem.u16(RUPEES), WALLET_SIZES[mem.u8(WALLET_TYPE)] or 999
  local bombs, bombMax = mem.u8(BOMBS), BOMB_BAG_SIZES[mem.u8(BOMB_BAG_TYPE)] or 99
  local arrows, arrowMax = mem.u8(ARROWS), QUIVER_SIZES[mem.u8(QUIVER_TYPE)] or 99
  local hasBombs = hasItem(0x07) or hasItem(0x08)
  local hasBow = hasItem(0x09) or hasItem(0x0A)

  local elements = readElements()
  local skills = readOwned(item_names.skills)
  local pieces, pieceTotal = readBag()
  local fused = mem.u8(FUSED_COUNT)
  local figurines = popcount(FIGURINES, FIGURINE_BYTES)

  local inKeyArea = (mem.u8(AREA_FLAGS) >> 1) & 1 == 1
  local dungeonIdx = inKeyArea and mem.u8(AREA_DUNGEON_IDX) or -1

  return {
    ready = true,
    waiting = false,
    name = fileName(),
    location = readLocation(),

    hearts = hearts(health),
    heartRow = heartRow(health, maxHealth),
    maxHearts = maxHealth // 8,
    healthPct = fraction(health, maxHealth),
    lowHealth = health <= 8,
    heartPieces = mem.u8(HEART_PIECES),

    rupees = rupees,
    walletMax = walletMax,
    rupeePct = fraction(rupees, walletMax),
    shells = mem.u16(SHELLS),

    hasBombs = hasBombs,
    bombs = bombs,
    bombMax = bombMax,
    bombPct = fraction(bombs, bombMax),
    hasBow = hasBow,
    arrows = arrows,
    arrowMax = arrowMax,
    arrowPct = fraction(arrows, arrowMax),

    buttonA = equipName(mem.u8(EQUIPPED_A)),
    buttonB = equipName(mem.u8(EQUIPPED_B)),
    bottles = readBottles(),
    charm = readBuff(CHARM, CHARM_TIMER) or "None",
    picolyte = readBuff(PICOLYTE, PICOLYTE_TIMER) or "None",

    gear = readGear(),
    elements = elements,
    elementCount = countOwned(elements),
    skills = skills,
    skillCount = countOwned(skills),
    skillTotal = #skills,
    quest = readQuest(),

    pieces = pieces,
    pieceTotal = pieceTotal,
    fused = fused,
    fusionTotal = FUSION_TOTAL,
    fusedPct = fraction(fused, FUSION_TOTAL),

    dungeons = readDungeons(dungeonIdx),
    figurines = figurines,
    figurineTotal = FIGURINE_TOTAL,
    figurinePct = fraction(figurines, FIGURINE_TOTAL),
    enemiesKilled = mem.u32(ENEMIES_KILLED),
  }
end
