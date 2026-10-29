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
local TOTAL_UPGRADES = 18 -- every row of the status windows, plus missiles and bombs

-- ---- The game's own art, drawn from the player's ROM (US build, AMTE) ------------------
-- bg.gfx.lz holds the pause screen's tiles; the tilemaps below are the map and status
-- screens. PALRAM rows 0-2 (minimap palette) and 3-15 (bg palette) are contiguous in the
-- ROM, so one palette address serves every tilemap entry's bank (decomp: pause_screen.c).
local TILES, PALETTE = 0x0856A254, 0x085657A8
local MAP_OUTLINE, MAP_STATUS = 0x085740FC, 0x085748AC
local FONT = "asset:font/"

local function crop(map, x, y, w, h)
  return gfx.tilemap{ tiles = TILES, map = map, palette = PALETTE, x = x, y = y, width = w * 8, height = h * 8, lz77 = true }
end

-- Status-screen windows (tile coords of the bottom half of sStatusScreenTilemap): the
-- title row, one row per upgrade, and the closing row. { name, status byte, bit }.
local WINDOWS = {
  { id = "beam", x = 1, w = 8, title = 21, footer = 27, rows = {
    { "CHARGE", BEAM_STATUS, 0x01 }, { "WIDE", BEAM_STATUS, 0x02 }, { "PLASMA", BEAM_STATUS, 0x04 },
    { "WAVE", BEAM_STATUS, 0x08 }, { "ICE", BEAM_STATUS, 0x10 } } },
  { id = "missile", x = 9, w = 8, title = 21, footer = 25, rows = {
    { "SUPER", WEAPONS_STATUS, 0x02 }, { "ICE", WEAPONS_STATUS, 0x04 }, { "DIFFUSION", WEAPONS_STATUS, 0x08 } } },
  { id = "suit", x = 19, w = 10, title = 21, footer = 24, rows = {
    { "VARIA", SUIT_STATUS, 0x10 }, { "GRAVITY", SUIT_STATUS, 0x20 } } },
  { id = "misc", x = 19, w = 10, title = 25, footer = 31, rows = {
    { "MORPH BALL", SUIT_STATUS, 0x40 }, { "HI-JUMP", SUIT_STATUS, 0x01 }, { "SPEED BOOSTER", SUIT_STATUS, 0x02 },
    { "SPACE JUMP", SUIT_STATUS, 0x04 }, { "SCREW ATTACK", SUIT_STATUS, 0x08 } } },
  { id = "bomb", x = 1, w = 10, title = 28, footer = 30, rows = { { "POWER", WEAPONS_STATUS, 0x20 } } },
}

local ART -- built once; false when this ROM isn't the US build or a draw failed

local function buildArt()
  local code = string.char(mem.u8(0x080000AC), mem.u8(0x080000AD), mem.u8(0x080000AE), mem.u8(0x080000AF))
  if code ~= "AMTE" then return false end
  local art = {
    header = crop(MAP_STATUS, 0, 0, 30, 5),
    center = crop(MAP_STATUS, 9, 5, 11, 15),
    frameL = crop(MAP_STATUS, 0, 5, 1, 15),
    frameR = crop(MAP_STATUS, 29, 5, 1, 15),
    outline = crop(MAP_OUTLINE, 0, 0, 30, 20),
    botbar = crop(MAP_OUTLINE, 0, 18, 30, 2),
    sideL = crop(MAP_STATUS, 0, 10, 1, 2),
    sideR = crop(MAP_STATUS, 29, 10, 1, 2),
    windows = {},
  }
  for _, w in ipairs(WINDOWS) do
    local rows = {}
    for i, r in ipairs(w.rows) do
      rows[i] = { key = crop(MAP_STATUS, w.x, w.title + i, w.w, 1), name = r[1], status = r[2], bit = r[3] }
    end
    art.windows[w.id] = { title = crop(MAP_STATUS, w.x, w.title, w.w, 1), rows = rows, footer = crop(MAP_STATUS, w.x, w.footer, w.w, 1) }
  end
  return art
end

local ok, built = pcall(buildArt)
ART = ok and built or false

-- ---- The game's font, as glyph images ---------------------------------------------------
-- variant "c" is the colour of a current amount, "m" of a maximum (palette rows 6 and 3).
local function glyphs(str, variant)
  local out = {}
  for ch in str:upper():gmatch(".") do
    local name
    if ch:match("[A-Z0-9]") then name = ch
    elseif ch == "/" then name = "slash"
    elseif ch == ":" then name = "semi"
    elseif ch == "." then name = "dot"
    elseif ch == ">" then name = "play" end
    out[#out + 1] = { src = FONT .. (name and (variant .. "-" .. name) or "space") .. ".png" }
  end
  return out
end

local function line(text, variant) return { g = glyphs(text, variant) } end

-- A number right-aligned in `cells` digit cells that cover the header's placeholder digits.
local function digits(value, cells, variant)
  local text = tostring(math.max(0, math.min(value, 10 ^ cells - 1)))
  local out = {}
  for i = 1, cells do
    local ch = text:sub(i - cells + #text, i - cells + #text)
    local blank = i <= cells - #text
    out[i] = { src = FONT .. (blank and "ob" or ("o" .. variant .. "-" .. ch)) .. ".png" }
  end
  return out
end

-- ---- The live minimap --------------------------------------------------------------------
-- gMinimapData_Visited (EWRAM 0x02034000) is the current area's 32x32 tilemap with the
-- explored/hidden flags the game keeps up to date; its tiles are sMinimapTilesGfx, raw in
-- the ROM. A gfx image is cached by its arguments, so each change of the map is drawn from
-- a different mirror of the same memory (EWRAM and the ROM repeat) to get a fresh key.
local MINIMAP_RAM, MINIMAP_TILES = 0x02034000, 0x08561FA8
local MINIMAP_X, MINIMAP_Y = 0x03000031, 0x03000032
local MAP_COLS, MAP_ROWS = 26, 15 -- tiles shown, the frame's window
local mapHash, mapVersion = nil, 0

local function minimap()
  local h = 0
  for i = 0, 1023 do h = (h * 31 + mem.u16(MINIMAP_RAM + i * 2)) & 0xFFFFFF end
  local mx, my = mem.u8(MINIMAP_X), mem.u8(MINIMAP_Y)
  local cx = math.max(0, math.min(32 - MAP_COLS, mx - MAP_COLS // 2))
  local cy = math.max(0, math.min(32 - MAP_ROWS, my - MAP_ROWS // 2))
  local sig = h * 4096 + cx * 64 + cy
  if sig ~= mapHash then mapHash, mapVersion = sig, mapVersion + 1 end
  local v = mapVersion % 144
  local rom = ({ 0x08000000, 0x0A000000, 0x0C000000 })
  local key = gfx.tilemap{
    tiles = MINIMAP_TILES - 0x08000000 + rom[v // 48 + 1],
    map = MINIMAP_RAM + (v % 16) * 0x40000,
    palette = PALETTE - 0x08000000 + rom[(v // 16) % 3 + 1],
    x = cx, y = cy, width = MAP_COLS * 8, height = MAP_ROWS * 8, opaque = true,
  }
  return key, mx - cx, my - cy
end

local function fraction(value, max)
  if max <= 0 then return 0 end
  return math.max(0, math.min(1, value / max))
end

-- ---- Sectors -------------------------------------------------------------------------
local SECTORS = {
  { "Main Deck", "DECK" }, { "Sector 1", "SRX" }, { "Sector 2", "TRO" }, { "Sector 3", "PYR" },
  { "Sector 4", "AQA" }, { "Sector 5", "ARC" }, { "Sector 6", "NOC" },
}

local function readSectorRows(area)
  local out = {}
  for i, s in ipairs(SECTORS) do
    local pct = math.min(100, mem.u8(SECTOR_PERCENT + i - 1))
    local row = (i - 1) // 3 + 1
    out[row] = out[row] or { text = "" }
    out[row].text = out[row].text .. string.format("%-4s%3d%s", s[2], pct, area == i - 1 and ">" or " ")
  end
  for i, r in ipairs(out) do out[i] = { g = glyphs(r.text, "c") } end
  return out
end

local function readSectors(area)
  local maps = mem.u8(DOWNLOADED_MAPS)
  local out = {}
  for i, s in ipairs(SECTORS) do
    local pct = math.min(100, mem.u8(SECTOR_PERCENT + i - 1))
    out[#out + 1] = {
      here = area == i - 1,
      mapped = (maps >> (i - 1)) & 1 == 1,
      pct = pct / 100,
      g = glyphs(string.format("%-4s%3d", s[2], pct), area == i - 1 and "c" or "m"),
      mark = glyphs((area == i - 1) and ">" or ((maps >> (i - 1)) & 1 == 1 and "M" or ""), area == i - 1 and "c" or "m"),
    }
  end
  return out
end

-- The status windows with each row lit or dimmed by what Samus has.
local function readWindows()
  local out, owned = {}, 0
  for id, w in pairs(ART.windows) do
    local rows = {}
    for i, r in ipairs(w.rows) do
      local has = mem.u8(r.status) & r.bit ~= 0
      if has then owned = owned + 1 end
      rows[i] = { src = r.key, owned = has }
    end
    out[id] = { title = w.title, footer = w.footer, rows = rows }
  end
  -- missiles, bombs and the beam's base level count as upgrades too
  for _, a in ipairs({ { WEAPONS_STATUS, 0x01 }, { WEAPONS_STATUS, 0x10 } }) do
    if mem.u8(a[1]) & a[2] ~= 0 then owned = owned + 1 end
  end
  return out, owned
end

function update()
  local maxEnergy = mem.u16(MAX_ENERGY)
  local validEnergy = maxEnergy >= STARTING_ENERGY and maxEnergy <= STARTING_ENERGY + 20 * TANK
    and (maxEnergy - STARTING_ENERGY) % TANK == 0
  if not LIVE_MODES[mem.u8(MAIN_GAME_MODE)] or not validEnergy or not ART then
    return {
      ready = false,
      waiting = true,
      wait = ART == false and { line("US ROM ONLY", "c"), line("AMTE", "m") }
        or { line("METROID FUSION", "c"), line("AWAITING SAVE", "m") },
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
  local sector = SECTORS[area + 1]
  local windows, owned = readWindows()
  local mapKey, markCol, markRow = minimap()
  local tanks = (maxEnergy - STARTING_ENERGY) // TANK
  local level = mem.u8(SECURITY_LEVEL)
  local t = IN_GAME_TIMER

  local hatches = {}
  for i = 1, 4 do
    local open = level ~= 0xFF and level >= i
    hatches[i] = { text = string.format("L%d %s", i, open and "OPEN" or "LOCK"), open = open }
  end

  return {
    ready = true,
    waiting = false,
    lowHealth = mem.u8(LOW_HEALTH) ~= 0,

    art = {
      header = ART.header, center = ART.center, frameL = ART.frameL, frameR = ART.frameR, outline = ART.outline,
      botbar = ART.botbar, sideL = ART.sideL, sideR = ART.sideR, map = mapKey,
    },
    markCol = markCol * 17.34,
    markRow = markRow * 17.34,

    energyNow = digits(energy, 4, "c"),
    energyMax = digits(maxEnergy, 4, "m"),
    missileNow = digits(hasMissiles and missiles or 0, 3, "c"),
    missileMax = digits(hasMissiles and maxMissiles or 0, 3, "m"),
    bombNow = digits(hasBombs and bombs or 0, 2, "c"),
    bombMax = digits(hasBombs and maxBombs or 0, 2, "m"),

    sectorName = glyphs(sector and sector[2] or "?", "c"),
    left = {
      line("SECTOR", "m"), line(sector and sector[2] or "?", "c"), line("", "m"),
      line("ROOM", "m"), line(tostring(mem.u8(CURRENT_ROOM)), "c"), line("", "m"),
      line("TIME", "m"), line(string.format("%d:%02d:%02d", mem.u8(t), mem.u8(t + 1), mem.u8(t + 2)), "c"),
    },
    right = {
      line("UPGRADES", "m"), line(string.format("%d/%d", owned, TOTAL_UPGRADES), "c"), line("", "m"),
      line("TANKS", "m"), line(tostring(tanks), "c"), line("", "m"),
      line("SECURITY", "m"), line("LEVEL " .. (level == 0xFF and "-" or tostring(level)), "c"),
    },
    hatchRows = {
      { g = glyphs(string.format("%-14s%s", hatches[1].text, hatches[2].text), hatches[1].open and "c" or "m") },
      { g = glyphs(string.format("%-14s%s", hatches[3].text, hatches[4].text), hatches[3].open and "c" or "m") },
    },
    armsInfo = {
      line("UPGRADES " .. owned .. "/" .. TOTAL_UPGRADES, "c"),
      line("ENERGY TANKS " .. tanks, "c"),
      line("SECTOR " .. (sector and sector[2] or "?") .. "  ROOM " .. mem.u8(CURRENT_ROOM), "m"),
    },

    windows = windows,
    sectorRows = readSectorRows(area),
    nav = { status = glyphs("STATUS", "c"), arms = glyphs("ARMS", "c"), map = glyphs("MAP", "c") },
  }
end
