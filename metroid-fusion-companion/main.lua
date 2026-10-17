-- Metroid Fusion (GBA) memory map, from Data Crystal's RAM map
-- https://datacrystal.tcrf.net/wiki/Metroid_Fusion/RAM_map
-- checked against the metroidret/mf decompilation (linker.ld puts these
-- globals in IWRAM; include/structs/samus.h has struct Equipment and
-- include/constants/samus.h its bit flags):
-- https://github.com/metroidret/mf

-- ---- Globals (IWRAM) -----------------------------------------------------------
local SECURITY_LEVEL = 0x0300001C   -- gSecurityHatchLevel: 0-4, 0xFF = no hatches
local CURRENT_AREA = 0x0300002C     -- gCurrentArea: 0 Main Deck, 1-6 Sectors 1-6
local CURRENT_ROOM = 0x0300002D
local SECTOR_PERCENT = 0x0300003B   -- 7 bytes: Main Deck, then Sectors 1-6
local IN_GAME_TIMER = 0x03000138    -- gInGameTimer: hours, minutes, seconds, frames
local MAIN_GAME_MODE = 0x03000BDE   -- gMainGameMode, see GAME_MODE_* below

-- struct Equipment gEquipment (0x10 bytes)
local EQUIPMENT = 0x03001310
local ENERGY = EQUIPMENT + 0x0         -- u16
local MAX_ENERGY = EQUIPMENT + 0x2     -- u16
local MISSILES = EQUIPMENT + 0x4       -- u16
local MAX_MISSILES = EQUIPMENT + 0x6   -- u16
local POWER_BOMBS = EQUIPMENT + 0x8
local MAX_POWER_BOMBS = EQUIPMENT + 0x9
local BEAM_STATUS = EQUIPMENT + 0xA    -- BF_*
local WEAPONS_STATUS = EQUIPMENT + 0xB -- MBF_*
local SUIT_STATUS = EQUIPMENT + 0xC    -- SMF_*
local DOWNLOADED_MAPS = EQUIPMENT + 0xE
local LOW_HEALTH = EQUIPMENT + 0xF

-- GAME_MODE_IN_GAME, _MAP_SCREEN (pause), _CUTSCENE and _SA_X_CLOSE_UP all have a
-- loaded save behind them; the title, file select, demos and credits don't.
local LIVE_MODES = { [1] = true, [3] = true, [4] = true, [5] = true }

local STARTING_ENERGY, TANK = 99, 100

local IMG = "asset:img/"

-- ---- Abilities: { name, status byte, bit, icon, category } ----------------------
local ABILITIES = {
  { "Charge Beam", BEAM_STATUS, 0x01, "charge", "beam" },
  { "Wide Beam", BEAM_STATUS, 0x02, "wide", "beam" },
  { "Plasma Beam", BEAM_STATUS, 0x04, "plasma", "beam" },
  { "Wave Beam", BEAM_STATUS, 0x08, "wave", "beam" },
  { "Ice Beam", BEAM_STATUS, 0x10, "icebeam", "beam" },
  { "Missiles", WEAPONS_STATUS, 0x01, "missile", "missile" },
  { "Super Missiles", WEAPONS_STATUS, 0x02, "super", "missile" },
  { "Ice Missiles", WEAPONS_STATUS, 0x04, "icemissile", "missile" },
  { "Diffusion", WEAPONS_STATUS, 0x08, "diffusion", "missile" },
  { "Bombs", WEAPONS_STATUS, 0x10, "bomb", "bomb" },
  { "Power Bombs", WEAPONS_STATUS, 0x20, "powerbomb", "bomb" },
  { "Morph Ball", SUIT_STATUS, 0x40, "morph", "suit" },
  { "High Jump", SUIT_STATUS, 0x01, "highjump", "suit" },
  { "Speed Booster", SUIT_STATUS, 0x02, "speed", "suit" },
  { "Space Jump", SUIT_STATUS, 0x04, "spacejump", "suit" },
  { "Screw Attack", SUIT_STATUS, 0x08, "screw", "suit" },
  { "Varia Suit", SUIT_STATUS, 0x10, "varia", "suit" },
  { "Gravity Suit", SUIT_STATUS, 0x20, "gravity", "suit" },
}

local CATEGORIES = {
  { "beam", "BEAMS" }, { "missile", "MISSILES" }, { "bomb", "BOMBS" }, { "suit", "SUIT & MOVES" },
}

-- ---- Sectors -------------------------------------------------------------------
local SECTORS = {
  { "Main Deck", "MAIN DECK", "deck" },
  { "Sector 1", "SRX", "srx" },
  { "Sector 2", "TRO", "tro" },
  { "Sector 3", "PYR", "pyr" },
  { "Sector 4", "AQA", "aqa" },
  { "Sector 5", "ARC", "arc" },
  { "Sector 6", "NOC", "noc" },
}

-- Security hatches: level n opens hatches of every colour up to n.
local SECURITY = {
  { "Blue", "#4FA8FF" }, { "Green", "#4FE08A" }, { "Yellow", "#FFD84A" }, { "Red", "#FF5A5A" },
}

local function fraction(value, max)
  if max <= 0 then return 0 end
  return math.max(0, math.min(1, value / max))
end

local function readAbilities()
  local groups, owned = {}, 0
  for _, cat in ipairs(CATEGORIES) do
    local items = {}
    for _, a in ipairs(ABILITIES) do
      if a[5] == cat[1] then
        local has = mem.u8(a[2]) & a[3] ~= 0
        if has then owned = owned + 1 end
        items[#items + 1] = {
          name = a[1],
          owned = has,
          icon = IMG .. "ab-" .. a[4] .. (has and "" or "-off") .. ".png",
        }
      end
    end
    groups[#groups + 1] = { title = cat[2], key = cat[1], items = items }
  end
  return groups, owned
end

local function readSectors(area)
  local maps = mem.u8(DOWNLOADED_MAPS)
  local out = {}
  for i, s in ipairs(SECTORS) do
    local pct = math.min(100, mem.u8(SECTOR_PERCENT + i - 1))
    out[#out + 1] = {
      name = s[1],
      code = s[2],
      emblem = IMG .. "sector-" .. s[3] .. ".png",
      percent = pct,
      pct = pct / 100,
      here = area == i - 1,
      -- bit n = area n (unverified on a device)
      mapped = (maps >> (i - 1)) & 1 == 1,
    }
  end
  return out
end

-- One cell per energy tank: full while energy covers it.
local function readTanks(energy, maxEnergy)
  local tanks = {}
  local count = (maxEnergy - STARTING_ENERGY) // TANK
  local full = energy // TANK
  for i = 1, count do
    tanks[#tanks + 1] = { full = i <= full, src = IMG .. (i <= full and "tank-full" or "tank-empty") .. ".png" }
  end
  return tanks, count
end

local function readSecurity()
  local level = mem.u8(SECURITY_LEVEL)
  local out = {}
  for i, s in ipairs(SECURITY) do
    local open = level ~= 0xFF and level >= i
    out[#out + 1] = { name = s[1], open = open, color = open and s[2] or "#2A3A48" }
  end
  return out, level == 0xFF and "Off" or ("Level " .. level)
end

function update()
  local maxEnergy = mem.u16(MAX_ENERGY)
  local validEnergy = maxEnergy >= STARTING_ENERGY and maxEnergy <= STARTING_ENERGY + 20 * TANK
    and (maxEnergy - STARTING_ENERGY) % TANK == 0
  if not LIVE_MODES[mem.u8(MAIN_GAME_MODE)] or not validEnergy then
    return { ready = false, waiting = true }
  end

  local energy = math.min(mem.u16(ENERGY), maxEnergy)
  local missiles, maxMissiles = mem.u16(MISSILES), mem.u16(MAX_MISSILES)
  local bombs, maxBombs = mem.u8(POWER_BOMBS), mem.u8(MAX_POWER_BOMBS)
  local area = mem.u8(CURRENT_AREA)
  local tanks, tankCount = readTanks(energy, maxEnergy)
  local abilities, owned = readAbilities()
  local security, securityText = readSecurity()
  local sector = SECTORS[area + 1]

  return {
    ready = true,
    waiting = false,

    energy = energy % TANK,
    energyRaw = energy,
    maxEnergy = maxEnergy,
    energyPct = fraction(energy, maxEnergy),
    tanks = tanks,
    tankCount = tankCount,
    fullTanks = energy // TANK,
    lowHealth = mem.u8(LOW_HEALTH) ~= 0,

    hasMissiles = maxMissiles > 0,
    missiles = missiles,
    maxMissiles = maxMissiles,
    missilePct = fraction(missiles, maxMissiles),
    hasBombs = maxBombs > 0,
    powerBombs = bombs,
    maxPowerBombs = maxBombs,
    bombPct = fraction(bombs, maxBombs),

    abilities = abilities,
    abilityCount = owned,
    abilityTotal = #ABILITIES,

    sector = sector and sector[1] or string.format("Area %d", area),
    sectorCode = sector and sector[2] or "???",
    sectorEmblem = IMG .. "sector-" .. (sector and sector[3] or "deck") .. ".png",
    room = mem.u8(CURRENT_ROOM),
    sectors = readSectors(area),

    security = security,
    securityText = securityText,

    time = string.format("%d:%02d:%02d", mem.u8(IN_GAME_TIMER), mem.u8(IN_GAME_TIMER + 1), mem.u8(IN_GAME_TIMER + 2)),
  }
end
