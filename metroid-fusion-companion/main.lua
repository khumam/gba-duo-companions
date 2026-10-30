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
local MINIMAP_X = 0x03000031        -- gMinimapX / gMinimapY: Samus's cell on the area map
local MINIMAP_Y = 0x03000032
local IN_GAME_TIMER = 0x03000138    -- gInGameTimer: hours, minutes, seconds, frames
local EVENT_COUNTER = 0x03000B87    -- gEventCounter: the story step, 0 .. 109 (EventSet in the US ROM stores it here)
local MAIN_GAME_MODE = 0x03000BDE   -- gMainGameMode, see LIVE_MODES

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

-- ---- Globals (EWRAM) ------------------------------------------------------------
local MINIMAP_RAM = 0x02034000      -- gMinimapData_Visited: 32 x 32 u16 map entries of the current area

-- GAME_MODE_IN_GAME, _MAP_SCREEN (pause), _CUTSCENE and _SA_X_CLOSE_UP all have a
-- loaded save behind them; the title, file select, demos and credits don't.
local LIVE_MODES = { [1] = true, [3] = true, [4] = true, [5] = true }

local STARTING_ENERGY, TANK = 99, 100
local MAX_TANKS = 20
local TOTAL_UPGRADES = 18 -- every row of the arms page, plus missiles and bombs
local TOTAL_EVENTS = 109

-- ---- The game's own art, drawn from the player's ROM (US build, AMTE) ------------------
-- bg.gfx.lz holds the pause screen's tiles; the tilemaps are the status screen and the title logo.
-- PALRAM rows 0-2 (minimap palette) and 3-15 (bg palette) are contiguous in the ROM, so one palette
-- address serves every tilemap entry's bank (decomp: pause_screen.c).
local TILES, PALETTE = 0x0856A254, 0x085657A8
local MAP_STATUS = 0x085748AC
local MINIMAP_TILES = 0x08561FA8
-- The title screen's logo (decomp: sTitleScreenLogoGfx / TileTable / Pal): 32x32 tilemap, logo in tiles 1-28 x 1-14.
local LOGO_TILES, LOGO_MAP, LOGO_PAL = 0x08593274, 0x085963B8, 0x08596D0C

local ART -- built once; false when this ROM isn't the US build or a draw failed

local function buildArt()
  local code = string.char(mem.u8(0x080000AC), mem.u8(0x080000AD), mem.u8(0x080000AE), mem.u8(0x080000AF))
  if code ~= "AMTE" then return false end
  return {
    -- Samus on her grid, from the status screen's tilemap (11 x 15 tiles)
    samus = gfx.tilemap{ tiles = TILES, map = MAP_STATUS, palette = PALETTE, x = 9, y = 5, width = 88, height = 120, lz77 = true },
    logo = gfx.tilemap{ tiles = LOGO_TILES, map = LOGO_MAP, palette = LOGO_PAL, x = 1, y = 1, width = 28 * 8, height = 14 * 8, lz77 = true },
  }
end

local ok, built = pcall(buildArt)
ART = ok and built or false

-- ---- The live minimap --------------------------------------------------------------------
-- gMinimapData_Visited is the current area's 32x32 tilemap with the explored / hidden flags the game
-- keeps up to date; its tiles are sMinimapTilesGfx, raw in the ROM. The map page shows a window of it
-- centred on Samus, each map pixel 8 device px (3.4688dp) wide. A gfx image is cached by its
-- arguments, not its contents, so when the map changes it's read through the next 256 KB EWRAM mirror:
-- same memory, new cache key.
local MAP_COLS, MAP_ROWS = 18, 9
local PX = 3.4688
local mapSeen, mapVersion = nil, 0

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function liveMap()
  local seen = mem.read(MINIMAP_RAM, 2048)
  if seen ~= mapSeen then mapSeen = seen; mapVersion = mapVersion + 1 end
  local sx, sy = mem.u8(MINIMAP_X), mem.u8(MINIMAP_Y)
  local onMap = sx < 32 and sy < 32
  local x0 = clamp((onMap and sx or 16) - MAP_COLS // 2, 0, 32 - MAP_COLS)
  local y0 = clamp((onMap and sy or 8) - MAP_ROWS // 2, 0, 32 - MAP_ROWS)
  local ok2, key = pcall(gfx.tilemap, {
    tiles = MINIMAP_TILES, palette = PALETTE, map = MINIMAP_RAM + (mapVersion % 64) * 0x40000,
    x = x0, y = y0, width = MAP_COLS * 8, height = MAP_ROWS * 8, opaque = true,
  })
  if not ok2 then return nil end
  return { image = key, onMap = onMap, x = ((sx - x0) * 8 + 4) * PX, y = ((sy - y0) * 8 + 4) * PX }
end

-- ---- Sectors -------------------------------------------------------------------------
-- { plate name, sector code, badge letter }
local SECTORS = {
  { "MAIN DECK", "DECK", "D" }, { "SECTOR 1", "SRX", "1" }, { "SECTOR 2", "TRO", "2" }, { "SECTOR 3", "PYR", "3" },
  { "SECTOR 4", "AQA", "4" }, { "SECTOR 5", "ARC", "5" }, { "SECTOR 6", "NOC", "6" },
}

-- ---- Arms ----------------------------------------------------------------------------
-- { name, status byte, bit } per group, in the game's order
local ARMS = {
  beam = { { "CHARGE", BEAM_STATUS, 0x01 }, { "WIDE", BEAM_STATUS, 0x02 }, { "PLASMA", BEAM_STATUS, 0x04 },
    { "WAVE", BEAM_STATUS, 0x08 }, { "ICE", BEAM_STATUS, 0x10 } },
  missile = { { "SUPER", WEAPONS_STATUS, 0x02 }, { "ICE", WEAPONS_STATUS, 0x04 }, { "DIFFUSION", WEAPONS_STATUS, 0x08 } },
  bomb = { { "POWER", WEAPONS_STATUS, 0x20 } },
  suit = { { "VARIA", SUIT_STATUS, 0x10 }, { "GRAVITY", SUIT_STATUS, 0x20 } },
  misc = { { "MORPH BALL", SUIT_STATUS, 0x40 }, { "HI-JUMP", SUIT_STATUS, 0x01 }, { "SPEED BOOSTER", SUIT_STATUS, 0x02 },
    { "SPACE JUMP", SUIT_STATUS, 0x04 }, { "SCREW ATTACK", SUIT_STATUS, 0x08 } },
}

local function armRows(group)
  local out, owned = {}, 0
  for i, r in ipairs(group) do
    local has = mem.u8(r[2]) & r[3] ~= 0
    if has then owned = owned + 1 end
    out[i] = { name = r[1], on = has, off = not has }
  end
  return out, owned
end

-- ---- The mission -----------------------------------------------------------------------
-- gEventCounter steps through include/constants/event.h in the metroidret/mf decomp; EventSet(n)
-- stores n when event n happens, so "counter >= n" means it has. Bosses are read from the events they
-- hand over: Arachnus drops the Charge Beam, Serris the Speed Booster, Yakuza the Space Jump, Nightmare
-- the Gravity Suit; B.O.X., SA-X and the Omega Metroid have events of their own.
local BOSSES = {
  { "ARACHNUS", 15 }, { "SERRIS", 29 }, { "B.O.X.", 40 }, { "YAKUZA", 73 },
  { "NIGHTMARE", 81 }, { "SA-X", 102 }, { "OMEGA METROID", 108 },
}

-- Milestones the game announces, for the "next" line: { event, what happens }
local MILESTONES = {
  { 7, "MISSILE DATA" }, { 10, "MORPH BALL" }, { 15, "CHARGE BEAM" }, { 19, "SECURITY LEVEL 1" },
  { 22, "BOMB DATA" }, { 25, "HI-JUMP" }, { 29, "SPEED BOOSTER" }, { 35, "SECURITY LEVEL 2" },
  { 38, "SUPER MISSILE DATA" }, { 40, "B.O.X. DEFEATED" }, { 51, "VARIA SUIT" }, { 55, "SECURITY LEVEL 3" },
  { 58, "ICE MISSILE DATA" }, { 60, "WIDE BEAM" }, { 66, "POWER BOMB DATA" }, { 73, "SPACE JUMP" },
  { 78, "PLASMA BEAM" }, { 81, "GRAVITY SUIT" }, { 83, "SECURITY LEVEL 4" }, { 86, "DIFFUSION MISSILE DATA" },
  { 91, "WAVE BEAM" }, { 96, "SCREW ATTACK" }, { 102, "SA-X DEFEATED" }, { 107, "ICE BEAM" },
  { 108, "OMEGA METROID DEFEATED" },
}

local function nextMilestone(counter)
  for _, m in ipairs(MILESTONES) do
    if m[1] > counter then return m[2] end
  end
  return "ESCAPE THE STATION"
end

local function hatchRows(level)
  local rows = {}
  for i = 1, 4 do
    local open = level ~= 0xFF and level >= i
    rows[i] = {
      name = "L" .. i, icon = "asset:ui/door-" .. i .. ".png", open = open, locked = not open,
      state = open and "OPEN" or "LOCK",
    }
  end
  return rows
end

-- ---- update ----------------------------------------------------------------------------

function update()
  local maxEnergy = mem.u16(MAX_ENERGY)
  local validEnergy = maxEnergy >= STARTING_ENERGY and maxEnergy <= STARTING_ENERGY + MAX_TANKS * TANK
    and (maxEnergy - STARTING_ENERGY) % TANK == 0
  if not LIVE_MODES[mem.u8(MAIN_GAME_MODE)] or not validEnergy or not ART then
    local noRom = ART == false
    return {
      ready = false,
      waiting = true,
      logo = ART and ART.logo or "",
      hasLogo = ART ~= false,
      noLogo = ART == false,
      waitTitle = noRom and "US ROM ONLY" or "",
      waitSub = noRom and "Needs game code AMTE." or "Load a save to wake the visor.",
    }
  end

  local energy = math.min(mem.u16(ENERGY), maxEnergy)
  local weapons = mem.u8(WEAPONS_STATUS)
  local hasMissiles = weapons & 0x01 ~= 0
  -- the game draws the power bomb counters only with both bombs and power bombs
  local hasBombs = weapons & 0x30 == 0x30
  local missiles, maxMissiles = mem.u16(MISSILES), mem.u16(MAX_MISSILES)
  local bombs, maxBombs = mem.u8(POWER_BOMBS), mem.u8(MAX_POWER_BOMBS)
  local area = mem.u8(CURRENT_AREA)
  local sector = SECTORS[area + 1] or { "UNKNOWN", "?", "?" }
  local owned = 0
  local arms = { msg = "" }
  for id, group in pairs(ARMS) do
    local rows, n = armRows(group)
    arms[id] = rows
    owned = owned + n
  end
  -- missiles and bombs count as upgrades too
  for _, a in ipairs({ { WEAPONS_STATUS, 0x01 }, { WEAPONS_STATUS, 0x10 } }) do
    if mem.u8(a[1]) & a[2] ~= 0 then owned = owned + 1 end
  end
  arms.count = owned .. " / " .. TOTAL_UPGRADES
  arms.msg = string.format("%d of %d upgrades found.", owned, TOTAL_UPGRADES)

  local tanks = (maxEnergy - STARTING_ENERGY) // TANK
  local fullTanks = energy // TANK
  local tankRows = {}
  for i = 1, tanks do tankRows[i] = { full = i <= fullTanks } end

  local level = mem.u8(SECURITY_LEVEL)
  local t = IN_GAME_TIMER
  local time = string.format("%d:%02d:%02d", mem.u8(t), mem.u8(t + 1), mem.u8(t + 2))
  local room = mem.u8(CURRENT_ROOM)
  local pct = math.min(100, mem.u8(SECTOR_PERCENT + area))
  local maps = mem.u8(DOWNLOADED_MAPS)
  local mapCount = 0
  local sectors = {}
  for i, s in ipairs(SECTORS) do
    local p = math.min(100, mem.u8(SECTOR_PERCENT + i - 1))
    local mapped = (maps >> (i - 1)) & 1 == 1
    if mapped then mapCount = mapCount + 1 end
    sectors[i] = {
      name = s[1], code = s[2], tag = s[3], pct = p / 100, pctText = p .. "%",
      here = area == i - 1, mapped = mapped, unmapped = not mapped,
    }
  end

  local counter = mem.u8(EVENT_COUNTER)
  local bosses, bossesDown = {}, 0
  for i, b in ipairs(BOSSES) do
    local done = counter >= b[2]
    if done then bossesDown = bossesDown + 1 end
    bosses[i] = { name = b[1], done = done, alive = not done }
  end
  local security = hatchRows(level)
  for _, h in ipairs(security) do h.name = "LEVEL " .. h.name:sub(2) end
  local progress = math.min(1, counter / TOTAL_EVENTS)

  local live = liveMap()
  local suit = mem.u8(SUIT_STATUS)
  local suitName = suit & 0x20 ~= 0 and "GRAVITY" or (suit & 0x10 ~= 0 and "VARIA" or "BASE SUIT")

  return {
    ready = true,
    waiting = false,
    sector = sector[1],
    energy = string.format("%d/%d", energy, maxEnergy),
    tanks = tankRows,
    missiles = string.format("%d/%d", hasMissiles and missiles or 0, hasMissiles and maxMissiles or 0),
    bombs = string.format("%d/%d", hasBombs and bombs or 0, hasBombs and maxBombs or 0),

    map = {
      has = live ~= nil,
      none = live == nil,
      image = live and live.image or "",
      onMap = live ~= nil and live.onMap,
      x = live and live.x or 0,
      y = live and live.y or 0,
      title = string.format("%s %d%%", sector[2], pct),
      room = string.format("ROOM %d", room),
      status = live and string.format("%s, room %d.", sector[1]:lower():gsub("^%l", string.upper), room) or "No area map available.",
    },
    hatches = hatchRows(level),

    status = {
      samus = ART.samus,
      hasSamus = true,
      noSamus = false,
      left = {
        { label = "LOCATION", value = sector[1] },
        { label = "ROOM", value = tostring(room) },
        { label = "TIME", value = time },
        { label = "COMPLETE", value = pct .. "%" },
        { label = "MAPS", value = mapCount .. " / 7" },
      },
      right = {
        { label = "UPGRADES", value = owned .. " / " .. TOTAL_UPGRADES },
        { label = "TANKS", value = tanks .. " / " .. MAX_TANKS },
        { label = "SECURITY", value = level == 0xFF and "NONE" or ("LEVEL " .. level) },
        { label = "MISSION", value = math.floor(progress * 100) .. "%" },
        { label = "SUIT", value = suitName },
      },
      msg = string.format("Mission time %s.", time),
    },
    arms = arms,
    sectors = sectors,
    sectorsMsg = string.format("%d of 7 sector maps downloaded.", mapCount),
    mission = {
      bosses = bosses,
      security = security,
      pct = math.floor(progress * 100) .. "%",
      frac = progress,
      next = nextMilestone(counter),
      msg = string.format("%d of %d bosses down. Story step %d of %d.", bossesDown, #BOSSES, counter, TOTAL_EVENTS),
    },
  }
end
