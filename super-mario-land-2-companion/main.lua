-- Super Mario Land 2: 6 Golden Coins (Game Boy) - companion pack for GBA Duo.
--
-- The game keeps its live state in cartridge RAM (0xA000-0xBFFF). Addresses come from
-- the GameShark / Game Genie codes in RetroArch's cheat database (libretro-database,
-- "Super Mario Land 2 - 6 Golden Coins (USA, Europe)"): a GameShark code 01VVLLHH
-- writes VV to address HHLL, so "Infinite Lives" 01052CA2 means lives are at 0xA22C.

-- ---- Addresses -----------------------------------------------------------------------
local POWER      = 0xA216  -- "Power Modifier"   010?16A2
local LIVES      = 0xA22C  -- "Infinite Lives"   01052CA2
local COINS_LOW  = 0xA262  -- coins, tens + units (BCD)   01??62A2
local COINS_HIGH = 0xA263  -- coins, hundreds             010?63A2
local LEVEL      = 0xA269  -- "Level Modifier"   01XX69A2
local STAR       = 0xA271  -- "Have Star Power"  01FF71A2
local POS        = 0xA227  -- Mario's X position, 16-bit: A227 low, A228 high (checked in an emulator)
local POS_Y      = 0xA229  -- Mario's Y position, 16-bit: A229 low, A22A high (checked in an emulator)
local MODE       = 0xFF9B  -- game mode: 12 world map, 4 level, 9 death, 26 file screen (emulator)

local SAVE_CURSOR = 0xFFC2 -- Mario's X on the save screen, see SAVES (emulator)

local MODE_TITLE, MODE_SAVE, MODE_MAP, MODE_LEVEL, MODE_DEATH, MODE_PAUSED = 1, 26, 12, 4, 9, 8
local CLEARED_BIT = 0x80   -- set in a level's flag once it is cleared (emulator)

-- The three save files. From `base`: coins tens+units (BCD), coins hundreds, levels cleared
-- (BCD), lives (BCD), and at +6 the signature 12 34 56 78. Bases 90 and E0 read from the user's
-- save; a new game has no signature, or a signature with nothing earned yet.
local SAVES = {
  { name = "SAVE A", base = 0xA040, cursor = 0x28 },
  { name = "SAVE B", base = 0xA090, cursor = 0x48 },
  { name = "SAVE C", base = 0xA0E0, cursor = 0x68 },
}
local SAVE_SIGNATURE = { 0x12, 0x34, 0x56, 0x78 }

-- Zones, with level IDs (A269) in course order. Each map spot was entered in an emulator to
-- read its ID. `flag` is the boss level's cleared flag: beating the boss gives the golden coin.
-- `clears` holds a cleared flag per level, secrets included. VERIFY: A84F, A850, A85E, A863,
-- A864, A854 and A855 are inferred from their neighbours, not tested by clearing those levels.
local ZONES = {
  { name = "Tree", flag = 0xA84D, ids = { 1, 2, 3, 4, 5 }, secrets = { 29 },
    clears = { 0xA849, 0xA84A, 0xA84B, 0xA84C, 0xA84D, 0xA86C } },
  { name = "Space", flag = 0xA859, ids = { 18, 19 }, secrets = { 28 },
    clears = { 0xA858, 0xA859, 0xA871 } },
  { name = "Macro", flag = 0xA856, ids = { 20, 21, 22, 23 }, secrets = { 30 },
    clears = { 0xA853, 0xA854, 0xA855, 0xA856, 0xA86B } },
  { name = "Pumpkin", flag = 0xA851, ids = { 6, 7, 8, 9 }, secrets = { 27, 31 },
    clears = { 0xA84E, 0xA84F, 0xA850, 0xA851, 0xA86E, 0xA86F } },
  { name = "Mario", flag = 0xA865, ids = { 10, 11, 12, 13 }, secrets = {},
    clears = { 0xA862, 0xA863, 0xA864, 0xA865 } },
  { name = "Turtle", flag = 0xA85F, ids = { 14, 15, 16 }, secrets = { 26 },
    clears = { 0xA85D, 0xA85E, 0xA85F, 0xA86D } },
}

-- Cleared flags of Gate, Bubble and Scenic. The current file's count is the sum of all flags,
-- because A042 always belongs to save A. Wario's Castle has no known flag, so it isn't counted.
local OTHER_CLEARS = { 0xA848, 0xA867, 0xA870 }

-- Levels outside the zones. 24 is Wario's Castle, entered from map spot 92.
local CASTLE = 24
local LEVEL_NAMES = {
  [0] = "GATE COURSE", [17] = "BUBBLE COURSE", [24] = "WARIO CASTLE", [25] = "SCENIC COURSE",
}
for _, z in ipairs(ZONES) do
  local prefix = z.name:upper() .. " ZONE-"
  for i, id in ipairs(z.ids) do LEVEL_NAMES[id] = prefix .. i end
  for i, id in ipairs(z.secrets) do LEVEL_NAMES[id] = prefix .. "S" .. i end
end

local POWER_NAMES = { [0] = "Small", [1] = "Super", [2] = "Bunny", [3] = "Fire" }
local POWER_ICONS = { [0] = "small", [1] = "super", [2] = "bunny", [3] = "fire" }

-- ---- Helpers -----------------------------------------------------------------------------
local function hex2(v) return string.format("%02X", v) end

-- Two-digit BCD (0x42 -> 42), or nil if the byte isn't valid BCD.
local function bcd(v)
  local hi, lo = v // 16, v % 16
  if hi > 9 or lo > 9 then return nil end
  return hi * 10 + lo
end

local tick = 0

-- ---- Position in the level --------------------------------------------------------------------
-- Checked in an emulator on this game: Mario's X position is 16-bit little-endian at
-- A227 (low) / A228 (high), in pixels. The level map sits in RAM at B000-CFFF as 32 rows
-- of 256 columns, one byte per 16-pixel block; the first level fills all 256 columns
-- and its goal was reached at position ~4056 (256 x 16 = 4096).
local MAP, MAP_COLS, MAP_ROWS = 0xB000, 256, 32
local levelLength = MAP_COLS * 16   -- pixels; re-measured every couple of seconds
local lastMeasure = -1000

local function position()
  return mem.u8(POS + 1) * 256 + mem.u8(POS)
end

-- Level length = last map column that holds anything but the background block.
-- Unused columns past the end of a short level are expected to be background.
local function measureLevel()
  local rows, counts = {}, {}
  for r = 0, MAP_ROWS - 1 do
    local s = mem.read(MAP + r * MAP_COLS, MAP_COLS)
    rows[r] = s
    for i = 1, #s do
      local b = s:byte(i)
      counts[b] = (counts[b] or 0) + 1
    end
  end
  local bg, best = 0, -1
  for b, n in pairs(counts) do
    if n > best then bg, best = b, n end
  end
  for c = MAP_COLS, 1, -1 do
    for r = 0, MAP_ROWS - 1 do
      if rows[r]:byte(c) ~= bg then
        levelLength = c * 16
        return
      end
    end
  end
  levelLength = MAP_COLS * 16
end

-- Wario's Castle doubles back through tubes, so X isn't progress there. The track follows the
-- route instead, in pixels along it, with the tube before the ball rooms (X 1742) as the end.
-- Measured from the user's tube readings and the emulator; the climbs are estimates.
local CASTLE_LENGTH = 5564
local CASTLE_START, CASTLE_TUBE_1, CASTLE_RETURN, CASTLE_STEPS, CASTLE_END = 2345, 3777, 2304, 285, 1742
local CASTLE_FLOOR_Y = 724  -- ground of the first hall
local CASTLE_UPPER_Y = 590  -- above this Mario has climbed out of the steps past the second hall
local CASTLE_MAX_X = 4096   -- X reads higher than this for a moment around the level's edges

local castleStage, castleBest = nil, 0

-- The stage for a position, for when Mario starts or restarts somewhere in the castle.
local function castleStageAt(x, y)
  if x >= CASTLE_TUBE_1 then return 2 end
  if x > CASTLE_RETURN then return 1 end
  if y < CASTLE_UPPER_Y then return 5 end
  if x >= CASTLE_STEPS then return 3 end
  return 4
end

-- Stages only go forward, one at a time: a high jump or a room sharing the same X can't skip ahead.
local function castleDistance(stage, x, y)
  if stage == 1 then return x - CASTLE_START end
  if stage == 2 then return 1432 + math.min(400, (CASTLE_FLOOR_Y - y) * 400 // 294) end
  if stage == 3 then return 1832 + CASTLE_RETURN - x end
  if stage == 4 then return 3851 + CASTLE_STEPS - x end
  return 4107 + x - CASTLE_STEPS
end

local function castlePercent(mode)
  if mode == MODE_DEATH or mode == MODE_MAP then
    castleStage, castleBest = nil, 0
  elseif mode == MODE_LEVEL then
    local x, y = position(), mem.u8(POS_Y + 1) * 256 + mem.u8(POS_Y)
    if x < CASTLE_MAX_X then
      if not castleStage then
        castleStage = castleStageAt(x, y)
      elseif castleStage == 1 and x >= CASTLE_TUBE_1
        or castleStage == 2 and x <= CASTLE_RETURN
        or castleStage == 3 and x < CASTLE_STEPS
        or castleStage == 4 and x >= CASTLE_STEPS and y < CASTLE_UPPER_Y then
        castleStage = castleStage + 1
      end
      castleBest = math.max(castleBest, castleDistance(castleStage, x, y))
    end
  end
  return math.min(100, castleBest * 100 // CASTLE_LENGTH)
end

function progressPercent(mode)
  if mem.u8(LEVEL) == CASTLE then return castlePercent(mode) end
  local p = math.floor(position() * 100 / math.max(levelLength, 1))
  if p > 100 then p = 100 end
  if p < 0 then p = 0 end
  return p
end

-- ---- Golden coins and zone progress ------------------------------------------------------------
local zoneState        -- last good read of the cleared flags
local home             -- the page that matches what the game is showing; nil until it reports one
local shownHome

local function isCleared(addr)
  return mem.u8(addr) & CLEARED_BIT ~= 0
end

local function readZones()
  local zones, got, cleared = {}, 0, 0
  for _, z in ipairs(ZONES) do
    local have = isCleared(z.flag)
    if have then got = got + 1 end
    local done = 0
    for _, addr in ipairs(z.clears) do
      if isCleared(addr) then done = done + 1 end
    end
    cleared = cleared + done
    zones[#zones + 1] = {
      name = z.name, got = have, missing = not have, initial = z.name:sub(1, 1),
      progress = done .. "/" .. #z.clears,
      coinIcon = "asset:icons/coin-" .. z.name:lower() .. ".png",
    }
  end
  for _, addr in ipairs(OTHER_CLEARS) do
    if isCleared(addr) then cleared = cleared + 1 end
  end
  return { zones = zones, got = got, cleared = cleared }
end

local function hasSignature(base)
  for i, v in ipairs(SAVE_SIGNATURE) do
    if mem.u8(base + 5 + i) ~= v then return false end
  end
  return true
end

local function readSaves()
  local saves, cursor = {}, mem.u8(SAVE_CURSOR)
  for _, s in ipairs(SAVES) do
    local cleared = bcd(mem.u8(s.base + 2)) or 0
    local coins = (bcd(mem.u8(s.base)) or 0) + mem.u8(s.base + 1) % 16 * 100
    local isNew = not hasSignature(s.base) or (cleared == 0 and coins == 0)
    saves[#saves + 1] = {
      name = s.name, isNew = isNew, used = not isNew, selected = cursor == s.cursor,
      cleared = string.format("%02d", cleared), coins = string.format("%03d", coins),
      lives = bcd(mem.u8(s.base + 3)) or 0,
    }
  end
  return saves
end

-- ---- update() ---------------------------------------------------------------------------------
function update(ui)
  ui = ui or {}
  tick = tick + 1
  if tick - lastMeasure >= 16 then -- every 2 s at 8 ticks per second
    pcall(measureLevel)
    lastMeasure = tick
  end

  local livesRaw = mem.u8(LIVES)
  local lives = bcd(livesRaw) or livesRaw

  local low, high = bcd(mem.u8(COINS_LOW)), mem.u8(COINS_HIGH) % 16
  local coins = low and string.format("%03d", high * 100 + low) or "?"

  local powerRaw = mem.u8(POWER)
  local power = POWER_NAMES[powerRaw] or ("? " .. hex2(powerRaw))

  local star = mem.u8(STAR) ~= 0

  -- If cartridge RAM reads back as all FF, the game has it switched off right now.
  local warning = ""
  local readable = not (livesRaw == 0xFF and mem.u8(COINS_LOW) == 0xFF and powerRaw == 0xFF)
  if not readable then
    warning = "Game memory not readable right now (title screen or loading?)"
  end

  -- FF would read as "cleared" for every flag, so keep the last good result instead.
  if readable or not zoneState then
    zoneState = readZones()
  end

  -- A level reached straight from the title is the game's demo, so the title stays up.
  local mode = mem.u8(MODE)
  if mode == MODE_TITLE then
    home = "title"
  elseif mode == MODE_SAVE then
    home = "save"
  elseif mode == MODE_MAP then
    home = "map"
  elseif (mode == MODE_LEVEL or mode == MODE_PAUSED) and home ~= "title" then
    home = "overview"
  end

  local progress = progressPercent(mode)

  local out = {
    zones = zoneState.zones,
    coinCount = zoneState.got,
    saves = home == "save" and readSaves() or {},
    lives = lives,
    coins = coins,
    powerLabel = power:upper(),
    star = star,
    progress = progress,
    markerLeft = progress .. "%",
    title = LEVEL_NAMES[mem.u8(LEVEL)] or string.format("LEVEL %02d", mem.u8(LEVEL)),
    powerIcon = "asset:icons/power-" .. (POWER_ICONS[powerRaw] or "unknown") .. ".png",
    cleared = string.format("%02d", zoneState.cleared),
    warning = warning,
  }

  -- Follow the game between its screens, once per change.
  local page = ui.page
  if home ~= shownHome then
    shownHome = home
    out.ui = { navigate = home }
    page = home
  end
  out.onTitle = page == "title"

  return out
end
