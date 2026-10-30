-- Metroid: Zero Mission (GBA) memory map. Addresses are from Data Crystal's RAM map
-- (https://datacrystal.tcrf.net/wiki/Metroid_Zero_Mission:RAM_map) and the metroidret/mzm
-- decompilation (include/structs/samus.h struct Equipment, include/constants/*.h),
-- checked on a running European Virtual Console build (BMXP): the IWRAM globals are at
-- the same addresses in the US (BMXE) and EU builds.
-- https://github.com/metroidret/mzm

-- ---- Globals (IWRAM) -------------------------------------------------------------
local CURRENT_AREA = 0x03000054     -- 0 Brinstar, 1 Kraid, 2 Norfair, 3 Ridley, 4 Tourian, 5 Crateria, 6 Chozodia
local CURRENT_ROOM = 0x03000055
local AREA_PERCENT = 0x03000063     -- 7 bytes, one per area, in the order above
local IN_GAME_TIMER = 0x03000150    -- gInGameTimer: hours, minutes, seconds, frames
local GAME_MODE = 0x03000C70        -- gMainGameMode (s16), see LIVE_MODES
local MINIMAP_X = 0x03000059        -- gMinimapX / gMinimapY: Samus's cell on the area map (0xFF between areas)
local MINIMAP_Y = 0x0300005A

-- ---- Globals (EWRAM, decomp include/structs/minimap.h and include/event.h) ---------------
local MAP_VISITED = 0x02034000      -- gDecompressedMinimapVisitedTiles: 32 x 32 u16 map entries of the current area
local EVENTS = 0x02037E00           -- gEventsTriggered: 8 u32, bit n = event n (include/constants/event.h)

-- struct Equipment gEquipment
local EQUIPMENT = 0x03001530
local MAX_ENERGY = EQUIPMENT + 0x0       -- u16
local MAX_MISSILES = EQUIPMENT + 0x2     -- u16
local MAX_SUPERS = EQUIPMENT + 0x4
local MAX_POWER_BOMBS = EQUIPMENT + 0x5
local ENERGY = EQUIPMENT + 0x6           -- u16
local MISSILES = EQUIPMENT + 0x8         -- u16
local SUPERS = EQUIPMENT + 0xA
local POWER_BOMBS = EQUIPMENT + 0xB
local BEAM_OWNED = EQUIPMENT + 0xC       -- BBF_*
local BEAM_ACTIVE = EQUIPMENT + 0xD
local SUIT_OWNED = EQUIPMENT + 0xE       -- SMF_*
local SUIT_ACTIVE = EQUIPMENT + 0xF
local SUIT_TYPE = EQUIPMENT + 0x12       -- 0 power suit, 1 fully powered, 2 suitless

-- GM_INGAME, GM_MAP_SCREEN (pause), GM_CHOZODIA_ESCAPE, GM_TOURIAN_ESCAPE and GM_CUTSCENE
-- all have a loaded save behind them; the intro, title, file select and demos don't.
local LIVE_MODES = { [4] = true, [5] = true, [7] = true, [9] = true, [10] = true }

local STARTING_ENERGY, ENERGY_TANK = 99, 100
local MAX_TANKS = { energy = 12, missile = 50, super = 10, pbomb = 9 }

local SECTORS = {
  { "BRINSTAR", "B" }, { "KRAID", "K" }, { "NORFAIR", "N" }, { "RIDLEY", "R" },
  { "TOURIAN", "T" }, { "CRATERIA", "C" }, { "CHOZODIA", "Z" },
}

-- Armory rows: { id, name, owned byte, active byte, bit }. The bomb row lives in the beam
-- bytes (bit 7).
local BEAMS = {
  { "long", "LONG", BEAM_OWNED, BEAM_ACTIVE, 0x01 },
  { "charge", "CHARGE", BEAM_OWNED, BEAM_ACTIVE, 0x10 },
  { "ice", "ICE", BEAM_OWNED, BEAM_ACTIVE, 0x02 },
  { "wave", "WAVE", BEAM_OWNED, BEAM_ACTIVE, 0x04 },
  { "plasma", "PLASMA", BEAM_OWNED, BEAM_ACTIVE, 0x08 },
}
local GEAR = {
  { "varia", "VARIA", SUIT_OWNED, SUIT_ACTIVE, 0x10 },
  { "gravity", "GRAVITY", SUIT_OWNED, SUIT_ACTIVE, 0x20 },
  { "morph", "MORPH", SUIT_OWNED, SUIT_ACTIVE, 0x40 },
  { "bomb", "BOMB", BEAM_OWNED, BEAM_ACTIVE, 0x80 },
  { "hi-jump", "HI-JUMP", SUIT_OWNED, SUIT_ACTIVE, 0x01 },
  { "speed", "SPEED", SUIT_OWNED, SUIT_ACTIVE, 0x02 },
  { "space", "SPACE", SUIT_OWNED, SUIT_ACTIVE, 0x04 },
  { "screw", "SCREW", SUIT_OWNED, SUIT_ACTIVE, 0x08 },
  { "p.grip", "P.GRIP", SUIT_OWNED, SUIT_ACTIVE, 0x80 },
  { "p.bomb", "P.BOMB" }, -- owned with the first power bomb tank; not switchable
}
local SWITCH = {}
for _, rows in ipairs({ BEAMS, GEAR }) do
  for _, r in ipairs(rows) do SWITCH[r[1]] = r end
end

-- Bosses: { name, event }. A boss counts as down once its kill event is set.
local BOSSES = {
  { "DEOREM", 27 }, { "ACID WORM", 28 }, { "KRAID", 30 }, { "IMAGO", 35 },
  { "RIDLEY", 37 }, { "CROCOMIRE", 40 }, { "MOTHER BRAIN", 39 }, { "MECHA RIDLEY", 74 },
}

-- ---- The title logo, drawn from the player's ROM -----------------------------------
-- (decomp: menus/title_screen/title.gfx.lz + title.tt + palette.pal, 32x32 tilemap, the logo
-- sits in tile rows 5-12). Palette row 5 is the lavender one the title cycles through.
-- ROM offsets per release from the decomp's database.json (menus/pause_screen/minimap_tiles.gfx and
-- .pal are the area map's tiles and palette, drawn live from the map RAM below).
local LOGOS = {
  BMXE = { tiles = 0x084470E0, map = 0x0844E27C, pal = 0x08446D68, mapTiles = 0x0840E0C4, mapPal = 0x08411360 },
  BMXP = { tiles = 0x084520A4, map = 0x08459D04, pal = 0x08451D0C, mapTiles = 0x0840EEF8, mapPal = 0x08412194 },
  BMXJ = { tiles = 0x0844713C, map = 0x0844E2D8, pal = 0x08446DC4, mapTiles = 0x0840E120, mapPal = 0x084113BC },
}

-- Tile row 5 also holds the (R) mark in columns 28-29, which uses another palette bank than the
-- logo. So the logo is two images stacked: that row cut short, and rows 6-11 full width.
local function gameCode()
  return string.char(mem.u8(0x080000AC), mem.u8(0x080000AD), mem.u8(0x080000AE), mem.u8(0x080000AF))
end

local logo -- { top, body } image keys, built once; false when this release isn't known or a draw failed

local function buildLogo()
  local a = LOGOS[gameCode()]
  if not a then return false end
  local pal = a.pal + 5 * 32
  local ok, top = pcall(gfx.tilemap, { tiles = a.tiles, map = a.map, palette = pal, x = 0, y = 5, width = 224, height = 8, lz77 = true })
  if not ok then return false end
  local ok2, body = pcall(gfx.tilemap, { tiles = a.tiles, map = a.map, palette = pal, x = 0, y = 6, width = 240, height = 48, lz77 = true })
  if not ok2 then return false end
  return { top = top, body = body }
end

-- ---- The area map ------------------------------------------------------------------------
-- The game keeps the current area's map as 32 x 32 tile entries in EWRAM (explored rooms already
-- carry their colour bank). The map page shows a MAP_COLS x MAP_ROWS window of it, centred on Samus,
-- drawn with the game's own map tiles from ROM, each map pixel 8 device px (3.4688dp) wide.
-- gfx images are cached by their arguments, not their contents, so when the map changes it's read
-- through the next 256 KB EWRAM mirror: same memory, new cache key.
local MAP_COLS, MAP_ROWS = 18, 10
local PX = 3.4688
local mapSeen, mapVersion = nil, 0

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function liveMap()
  local a = LOGOS[gameCode()]
  if not a then return nil end
  local seen = mem.read(MAP_VISITED, 2048)
  if seen ~= mapSeen then mapSeen = seen; mapVersion = mapVersion + 1 end
  local sx, sy = mem.u8(MINIMAP_X), mem.u8(MINIMAP_Y)
  local onMap = sx < 32 and sy < 32
  local x0 = clamp((onMap and sx or 16) - MAP_COLS // 2, 0, 32 - MAP_COLS)
  local y0 = clamp((onMap and sy or 8) - MAP_ROWS // 2, 0, 32 - MAP_ROWS)
  local ok, key = pcall(gfx.tilemap, {
    tiles = a.mapTiles, palette = a.mapPal, map = MAP_VISITED + (mapVersion % 64) * 0x40000,
    x = x0, y = y0, width = MAP_COLS * 8, height = MAP_ROWS * 8, lz77 = false,
  })
  if not ok then return nil end
  return {
    image = key, onMap = onMap,
    x = ((sx - x0) * 8 + 4) * PX, y = ((sy - y0) * 8 + 4) * PX,
  }
end

-- ---- helpers -------------------------------------------------------------------------

local function bossRows()
  local rows, down = {}, 0
  for i, b in ipairs(BOSSES) do
    local event = b[2]
    local word = EVENTS + (event // 32) * 4
    local bits = mem.u8(word) | mem.u8(word + 1) << 8 | mem.u8(word + 2) << 16 | mem.u8(word + 3) << 24
    local done = bits & (1 << (event % 32)) ~= 0
    if done then down = down + 1 end
    rows[i] = { name = b[1], done = done, alive = not done }
  end
  return rows, down
end

local function clock()
  local t = IN_GAME_TIMER
  return string.format("%d:%02d:%02d", mem.u8(t), mem.u8(t + 1), mem.u8(t + 2))
end

local function switchRows(rows)
  local out, active = {}, 0
  for _, r in ipairs(rows) do
    local id, name, ownedAddr, activeAddr, bit = r[1], r[2], r[3], r[4], r[5]
    local has, on
    if ownedAddr then
      has = mem.u8(ownedAddr) & bit ~= 0
      on = has and mem.u8(activeAddr) & bit ~= 0
    else
      has = mem.u8(MAX_POWER_BOMBS) > 0
      on = has
    end
    if on then active = active + 1 end
    out[#out + 1] = { id = id, name = name, on = on, off = has and not on, locked = not has }
  end
  return out, active
end

local function itemRow(name, got, max, icon, kind)
  got = math.min(got, max)
  return { name = name, got = got, max = max, pct = got / max, icon = icon, [kind] = true }
end

-- ---- update ----------------------------------------------------------------------------

function update()
  if logo == nil then logo = buildLogo() end
  local mode = mem.u16(GAME_MODE)
  if not LIVE_MODES[mode] then
    return {
      waiting = true, ready = false,
      logoTop = logo and logo.top or "", logo = logo and logo.body or "",
      hasLogo = logo ~= false, noLogo = logo == false,
    }
  end

  local maxEnergy = mem.u16(MAX_ENERGY)
  local energy = math.min(mem.u16(ENERGY), maxEnergy)
  local fullTanks = energy // ENERGY_TANK
  local tanks = {}
  for i = 1, MAX_TANKS.energy do tanks[i] = { full = i <= fullTanks } end

  local maxMissiles, maxSupers, maxBombs = mem.u16(MAX_MISSILES), mem.u8(MAX_SUPERS), mem.u8(MAX_POWER_BOMBS)
  local area = mem.u8(CURRENT_AREA)
  local sector = SECTORS[area + 1] or { "UNKNOWN", "?" }

  local beams, beamsOn = switchRows(BEAMS)
  local gear, gearOn = switchRows(GEAR)

  local sectors = {}
  for i, s in ipairs(SECTORS) do
    local pct = math.min(mem.u8(AREA_PERCENT + i - 1), 100)
    sectors[i] = { name = s[1], tag = s[2], pct = pct / 100, pctText = pct .. "%", here = (i - 1) == area }
  end

  local energyTanks = math.max(0, (maxEnergy - STARTING_ENERGY) // ENERGY_TANK)
  local missileTanks, superTanks, bombTanks = maxMissiles // 5, maxSupers // 2, maxBombs // 2
  local gotItems = math.min(energyTanks, MAX_TANKS.energy) + math.min(missileTanks, MAX_TANKS.missile)
    + math.min(superTanks, MAX_TANKS.super) + math.min(bombTanks, MAX_TANKS.pbomb)
  local allItems = MAX_TANKS.energy + MAX_TANKS.missile + MAX_TANKS.super + MAX_TANKS.pbomb

  local room = string.format("%02d", mem.u8(CURRENT_ROOM))
  local live = liveMap()
  local bosses, bossesDown = bossRows()
  local time = clock()

  return {
    waiting = false,
    ready = true,
    sector = sector[1],
    energy = string.format("%d", energy),
    tanks = tanks,
    missiles = string.format("%03d", mem.u16(MISSILES)),
    supers = string.format("%02d", mem.u8(SUPERS)),
    pbombs = string.format("%02d", mem.u8(POWER_BOMBS)),
    missilesMax = string.format("%03d", maxMissiles),
    supersMax = string.format("%02d", maxSupers),
    pbombsMax = string.format("%02d", maxBombs),

    map = {
      has = live ~= nil,
      none = live == nil,
      image = live and live.image or "",
      onMap = live ~= nil and live.onMap,
      x = live and live.x or 0,
      y = live and live.y or 0,
      items = string.format("%s %d%%", sector[1], math.min(mem.u8(AREA_PERCENT + area), 100)),
      coords = "ROOM " .. room,
      status = live and string.format("%s, room %s.", sector[1], room) or "No area map for this game release yet.",
    },
    armory = {
      -- the game's own Samus figure (art/samus.py); the fully powered suit has its own art
      suit = mem.u8(SUIT_TYPE) == 1 and "asset:ui/samus-full.png" or "asset:ui/samus-power.png",
      beams = beams,
      gear = gear,
      status = string.format("%d of 15 systems online", beamsOn + gearOn),
    },
    sectors = sectors,
    log = {
      bosses = bosses,
      bossCount = string.format("%d/%d", bossesDown, #BOSSES),
      items = {
        itemRow("E-TANKS", energyTanks, MAX_TANKS.energy, "asset:ui/cube.png", "tank"),
        itemRow("MISSILES", missileTanks, MAX_TANKS.missile, "asset:ui/ic-missile.png", "missile"),
        itemRow("SUPERS", superTanks, MAX_TANKS.super, "asset:ui/ic-super.png", "super"),
        itemRow("P-BOMBS", bombTanks, MAX_TANKS.pbomb, "asset:ui/ic-pbomb.png", "pbomb"),
      },
      completion = string.format("%d%%", gotItems * 100 // allItems),
      time = time,
      status = string.format("%d of %d targets down, %d of %d tank upgrades found.", bossesDown, #BOSSES, gotItems, allItems),
    },
  }
end

-- ---- actions -----------------------------------------------------------------------------

actions = {}

-- Tapping a beam or suit row switches it on or off, the way the game's own status screen does:
-- it flips the item's bit in the "active" byte. Only while playing or paused, and only for items
-- Samus owns.
function actions.toggle(id)
  local r = SWITCH[id]
  local mode = mem.u16(GAME_MODE)
  if not r or not r[3] or (mode ~= 4 and mode ~= 5) then return end
  local owned, active, bit = r[3], r[4], r[5]
  if mem.u8(owned) & bit == 0 then return end
  mem.write8(active, mem.u8(active) ~ bit)
end
