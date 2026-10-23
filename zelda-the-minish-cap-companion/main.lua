-- The Legend of Zelda: The Minish Cap (GBA), Minish-OS companion.
--
-- Memory map from the zeldaret/tmc decompilation (include/save.h,
-- include/player.h, include/item.h, include/area.h, linker.ld):
-- https://github.com/zeldaret/tmc
-- and samurai goroh's code guide, which agrees with it:
-- http://www.erick.guillen.com.mx/Codes/GBA%20The%20Legend%20of%20Zelda%20Minish%20Cap.txt
--
-- Everything the save file holds lives in one struct, gSave, at the same
-- address in the US, EU and JP builds. update() returns the shape the layout
-- binds (see preview-data.json).

local item_names = pack.require("item_names")
local area_names = pack.require("area_names")

local SAVE = 0x02002A40

-- ---- Save header -------------------------------------------------------------
local SAVE_INVALID = SAVE + 0x000
local SAVE_INITIALIZED = SAVE + 0x001

-- ---- Stats (gSave + 0xA8) ----------------------------------------------------
local STATS = SAVE + 0x0A8
local WALLET_TYPE = STATS + 0x00
local HEART_PIECES = STATS + 0x01  -- pieces towards the next container, 0-3
local HEALTH = STATS + 0x02        -- 8 per heart
local MAX_HEALTH = STATS + 0x03
local BOMBS = STATS + 0x04
local ARROWS = STATS + 0x05
local BOMB_BAG_TYPE = STATS + 0x06
local QUIVER_TYPE = STATS + 0x07
local CHARM = STATS + 0x0A         -- bottle item id of the active charm, 0 = none
local EQUIPPED_A = STATS + 0x0C
local EQUIPPED_B = STATS + 0x0D
local BOTTLES = STATS + 0x0E       -- 4 bytes, bottle contents
local RUPEES = STATS + 0x18        -- u16
local SHELLS = STATS + 0x1A        -- u16
local CHARM_TIMER = STATS + 0x1C   -- u16, frames

-- Indexed by the *Type bytes above (itemUtils.c).
local WALLET_SIZES = { [0] = 100, 300, 500, 999 }
local BOMB_BAG_SIZES = { [0] = 10, 30, 50, 99 }
local QUIVER_SIZES = { [0] = 30, 50, 70, 99 }

-- ---- Collections ---------------------------------------------------------------
local FIGURINES, FIGURINE_BYTES, FIGURINE_TOTAL = SAVE + 0x0D0, 36, 136
local INVENTORY = SAVE + 0x0F2     -- 2 bits per item id
local KINSTONES = SAVE + 0x114
local FUSED_COUNT = KINSTONES + 0x03
local BAG_TYPES = KINSTONES + 0x04
local BAG_AMOUNTS = KINSTONES + 0x17
local BAG_SLOTS = 18               -- the game only fills 0x12 of the 19
local FUSION_TOTAL = 100

-- ---- Flags and dungeons --------------------------------------------------------
local GLOBAL_FLAGS = SAVE + 0x25C  -- bit n = global flag n
-- Per dungeon id (save.h): small keys held, and the dungeon items (gameUtils.c
-- HasDungeonMap/Compass/BigKey: bit 0 map, bit 1 compass, bit 2 big key).
local DUNGEON_KEYS = SAVE + 0x45C
local DUNGEON_ITEMS = SAVE + 0x46C

-- ---- Where Link is -------------------------------------------------------------
local ROOM_AREA = 0x03000BF4        -- gRoomControls.area (IWRAM)
local AREA_DUNGEON_IDX = 0x02033A93 -- gArea.dungeon_idx
local AREA_FLAGS = 0x02033A90       -- gArea.areaMetadata, 2 = area has keys

-- gRoomTransition.player_status (IWRAM 0x030010A0 + 0x0C, room.h): where the
-- pause menu draws Link. Overworld units span 0..0xF90 x 0..0xC60
-- (pauseMenu.c); the spot is kept while Link is indoors or in a dungeon, and
-- reads 0,0 on the title screen and file select.
local PLAYER_STATUS = 0x030010A0 + 0x0C
local OVERWORLD_MAP_X, OVERWORLD_MAP_Y = PLAYER_STATUS + 0x14, PLAYER_STATUS + 0x16
-- In a dungeon: Link's spot on the dungeon map; y >> 11 is the floor row, 0 = the
-- top floor (common.c sub_0801DB94).
local DUNGEON_MAP_Y = PLAYER_STATUS + 0x12
local WORLD_W, WORLD_H = 0xF90, 0xC60

-- That spot is only refreshed on a room change (gameUtils.c UpdatePlayerMapCoords
-- copies Link's position into it). In an overworld area Link's own position is
-- already in those units, so while he's outdoors read it live: gPlayerEntity
-- (IWRAM 0x03001160), x and y are Q16.16 at +0x2C / +0x30, pixels in the high half.
-- gArea.areaMetadata bit 0 = AR_IS_OVERWORLD (area.h).
local PLAYER_X, PLAYER_Y = 0x03001160 + 0x2E, 0x03001160 + 0x32

local function linkWorldPos()
  if mem.u8(AREA_FLAGS) & 1 == 1 then
    local x, y = mem.u16(PLAYER_X), mem.u16(PLAYER_Y)
    if x > 0 and x < WORLD_W and y > 0 and y < WORLD_H then return x, y, true end
  end
  return mem.u16(OVERWORLD_MAP_X), mem.u16(OVERWORLD_MAP_Y), false
end

-- ---- The world map --------------------------------------------------------------
-- The pause screen's world map, drawn at runtime from the player's own ROM
-- (rom_gfx.lua). 160 x 128 px, the same rectangle the pause menu draws Link on
-- (pauseMenu.c: x * 160 / 0xF90 + 40), so Link's world position maps straight onto
-- it. An unknown release falls back to the pack's drawn map.
local rom_gfx = pack.require("rom_gfx")
local FALLBACK_MAP = "asset:ui/map-terrain.png"

-- Where each dungeon sits on that map, in %.

-- Dungeon ids are the LVn of the LVn_CLEAR global flags (flag n + 1).
local DUNGEONS = {
  { 1, "Deepwood Shrine", "Minish Woods" },
  { 2, "Cave of Flames", "Mt. Crenel" },
  { 3, "Fortress of Winds", "the Wind Ruins" },
  { 4, "Temple of Droplets", "Lake Hylia" },
  { 5, "Palace of Winds", "the Cloud Tops" },
  { 6, "Dark Hyrule Castle", "Hyrule Castle" },
}

-- gDungeonFloorMetadatas (common.c), per dungeon id: floor count, the top floor's
-- number and the boss's floor number. Floor numbers: 3 = 1F, 4 = 2F, 2 = B1, 1 = B2.
local FLOORS = {
  [0] = { 1, 2, 2 }, { 3, 3, 3 }, { 4, 3, 0 }, { 3, 5, 5 }, { 3, 2, 2 }, { 5, 7, 7 }, { 5, 5, 5 },
}

local POUCH_SLOTS = 20   -- the ITEMS page grid (5 x 4)

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

-- 0..1 -> a CSS percentage with two decimals, kept 6% inside the edges so a
-- marker centred on it isn't clipped by the map frame.
local function pct(f)
  return math.floor(math.max(0.06, math.min(0.94, f)) * 10000 + 0.5) / 100
end

local function pad3(n)
  return string.format("%03d", n)
end

-- A loaded file is initialized, not marked invalid, and has 3-20 hearts.
-- Before that (title screen, file select) the struct holds leftovers.
local function saveLoaded()
  local maxHealth = mem.u8(MAX_HEALTH)
  return mem.u8(SAVE_INITIALIZED) == 1 and mem.u8(SAVE_INVALID) == 0
    and maxHealth >= 24 and maxHealth <= 160 and maxHealth % 8 == 0
end

-- ---- Slots ---------------------------------------------------------------------
-- Every grid cell the layout draws: an item, or an empty well.

local EMPTY = { name = "", icon = "", count = "", hasCount = false, owned = false, empty = true }

local function slot(name, count)
  local icon = item_names.icon(name)
  if not icon then return nil end -- nothing to draw (Fire Rod, Grab, Butter)
  return {
    name = name:upper(),
    icon = icon,
    count = count and ("x" .. count) or "",
    hasCount = count ~= nil,
    owned = true,
    empty = false,
  }
end

local function padded(list, size)
  local out = {}
  for i = 1, size do out[i] = list[i] or EMPTY end
  return out
end

local function equipSlot(addr)
  local id = mem.u8(addr)
  local name = item_names.equip[id]
  if not name then return { name = "NONE", icon = "" } end
  return { name = name:upper(), icon = item_names.icon(name) or "" }
end

-- The best owned item of every gear group, in pause-menu order, then the
-- bottles. Bombs and arrows carry their counts.
local function readGear(bombs, arrows)
  local all = {}
  for _, group in ipairs(item_names.gear) do
    for i = 2, #group do
      local id, name = group[i][1], group[i][2]
      if hasItem(id) then
        local count = (group[1] == "Bombs" and bombs) or (group[1] == "Bow" and arrows) or nil
        local s = slot(name, count)
        if s then all[#all + 1] = s end
        break
      end
    end
  end
  for i, bottleId in ipairs(item_names.bottles) do
    if hasItem(bottleId) then
      local name = item_names.bottle[mem.u8(BOTTLES + i - 1)] or "Empty"
      all[#all + 1] = slot(name == "Empty" and "Bottle" or name) or slot("Bottle")
    end
  end
  return padded(all, POUCH_SLOTS)
end

-- ---- Kinstones -------------------------------------------------------------------

local function readKinstones()
  local pieces, total = {}, 0
  local byColor = { Red = 0, Blue = 0, Green = 0, Gold = 0 }
  for i = 0, BAG_SLOTS - 1 do
    local id, amount = mem.u8(BAG_TYPES + i), mem.u8(BAG_AMOUNTS + i)
    if id ~= 0 and amount > 0 then
      local color, place = item_names.kinstone(id)
      if color == "?" then color = "Gold" end
      pieces[#pieces + 1] = {
        name = place or (color .. " Piece"),
        color = color:upper(),
        id = string.format("#%02X", id),
        amount = "x" .. amount,
        icon = item_names.kinstoneIcon(color),
        isRed = color == "Red", isBlue = color == "Blue",
        isGreen = color == "Green", isGold = color == "Gold",
      }
      total = total + amount
      byColor[color] = byColor[color] + amount
    end
  end
  return pieces, total, byColor
end

-- ---- Quest -------------------------------------------------------------------------

local function readElements()
  local out = {}
  for _, e in ipairs(item_names.elements) do
    local owned = hasItem(e[1])
    out[#out + 1] = { name = e[2]:upper(), icon = item_names.elementIcon(e[2]), owned = owned, locked = not owned }
  end
  return out
end

local function countOwned(list)
  local n = 0
  for _, entry in ipairs(list) do
    if hasItem(entry[1]) then n = n + 1 end
  end
  return n
end

-- Quest items Link carries right now. The game takes each one away when its
-- errand is done, so everything listed is still open.
local function readSideQuests()
  local out = {}
  for _, entry in ipairs(item_names.quest) do
    if hasItem(entry[1]) then
      out[#out + 1] = { name = entry[2], icon = item_names.icon(entry[2]) or "", done = false }
    end
  end
  return out
end

local function readDungeons(currentIdx)
  local list, nextUp = {}, nil
  for _, d in ipairs(DUNGEONS) do
    local idx, name = d[1], d[2]
    local cleared, here = flag(idx + 1), idx == currentIdx
    list[#list + 1] = { name = name, cleared = cleared, here = here, todo = not cleared and not here }
    if not cleared then nextUp = nextUp or d end
  end
  return list, nextUp
end

-- ---- The dungeon map panel ------------------------------------------------------------
-- In a dungeon the MAP panel gets WORLD / DUNGEON tabs and opens on DUNGEON. The WORLD
-- tab stores the visit it was tapped in (ui.mapWorldAt), so entering a dungeon again
-- opens on DUNGEON.

local function floorName(n)
  if n >= 3 then return (n - 2) .. "F" end
  return "B" .. (3 - n)
end

local visit, visitIdx = 0, nil

local function readDungeonMap(ui, inDungeon, idx, location)
  if not inDungeon then
    visitIdx = nil
    return { inDungeon = false, showWorld = true, showDungeon = false, visit = visit }
  end
  if idx ~= visitIdx then visit, visitIdx = visit + 1, idx end
  local showWorld = ui ~= nil and tonumber(ui.mapWorldAt) == visit

  local bits, keys = mem.u8(DUNGEON_ITEMS + idx), mem.u8(DUNGEON_KEYS + idx)
  local hasMap, hasCompass, hasBigKey = bits & 1 ~= 0, bits & 2 ~= 0, bits & 4 ~= 0

  local meta = FLOORS[idx] or { 1, 3, 3 }
  local count, top, bossFloor = meta[1], meta[2], meta[3]
  local row = math.min(mem.u16(DUNGEON_MAP_Y) >> 11, count - 1)
  local cleared = idx >= 1 and flag(idx + 1)
  local floors = {}
  for i = 0, count - 1 do
    local n = top - i
    floors[#floors + 1] = {
      name = floorName(n),
      here = i == row,
      -- The compass shows the boss's floor until the boss is beaten, as in the game.
      boss = hasCompass and not cleared and n == bossFloor,
    }
  end

  local function item(kind, name, owned)
    return { name = name, icon = rom_gfx.dungeonItem(kind) or "", owned = owned, missing = not owned }
  end

  local entry = nil
  for _, d in ipairs(DUNGEONS) do
    if d[1] == idx then entry = d end
  end
  return {
    inDungeon = true,
    showWorld = showWorld,
    showDungeon = not showWorld,
    visit = visit,
    name = (entry and entry[2] or location):upper(),
    floor = floorName(top - row),
    floors = floors,
    items = {
      item("map", "MAP", hasMap),
      item("compass", "COMPASS", hasCompass),
      item("bigKey", "BIG KEY", hasBigKey),
    },
    keys = "x" .. keys,
    keyIcon = rom_gfx.dungeonItem("smallKey") or "",
  }
end

-- ---- Link and his hearts ---------------------------------------------------------------
-- 8 health per heart, drawn in quarters like the game's HUD (rom_gfx.heart: 0 empty
-- .. 4 full). Without the ROM's art (unknown release) the hearts are left out.

local function readLink(health)
  local containers = mem.u8(MAX_HEALTH) // 8
  local hearts = {}
  for i = 0, containers - 1 do
    local quarters = math.max(0, math.min(4, (health - i * 8) // 2))
    hearts[#hearts + 1] = { src = rom_gfx.heart(quarters) or "" }
  end
  return {
    sprite = rom_gfx.link() or "asset:ui/mark-link.png",
    hearts = hearts,
    hasHearts = rom_gfx.heart(4) ~= nil,
  }
end

-- ---- Ezlo's hint -------------------------------------------------------------------
-- The game keeps Ezlo's lines in ROM text, not RAM, so this is the companion's
-- own advice from what it can read: health, ammo, then the next dungeon.

local function ezloHint(health, bombs, hasBombs, inDungeon, nextUp)
  if health <= 8 then
    return "Link, you're nearly out of hearts! Find a fairy, or drink a potion if you have one."
  end
  if hasBombs and bombs == 0 then
    return "Your bomb bag is empty. Cut some grass or smash pots, bombs turn up all over Hyrule."
  end
  if inDungeon then
    return "Keep an eye out for small keys. Every locked door in here has one somewhere."
  end
  if nextUp then
    return string.format("Next up: the %s, in %s. Let's get going!", nextUp[2], nextUp[3])
  end
  return "We've cleared every dungeon. Vaati won't know what hit him!"
end

-- -----------------------------------------------------------------------------

function update(ui)
  if not saveLoaded() then
    local logo = rom_gfx.titleLogo()
    return { ready = false, waiting = true, logo = logo or "", hasLogo = logo ~= nil, noLogo = logo == nil }
  end

  local health = mem.u8(HEALTH)
  local rupees, walletMax = mem.u16(RUPEES), WALLET_SIZES[mem.u8(WALLET_TYPE)] or 999
  local bombs, bombMax = mem.u8(BOMBS), BOMB_BAG_SIZES[mem.u8(BOMB_BAG_TYPE)] or 99
  local arrows, arrowMax = mem.u8(ARROWS), QUIVER_SIZES[mem.u8(QUIVER_TYPE)] or 99
  local hasBombs = hasItem(0x07) or hasItem(0x08)
  local hasBow = hasItem(0x09) or hasItem(0x0A)

  local items = readGear(hasBombs and bombs or nil, hasBow and arrows or nil)
  local pieces, pieceTotal, byColor = readKinstones()
  local fused = mem.u8(FUSED_COUNT)

  local inDungeon = (mem.u8(AREA_FLAGS) >> 1) & 1 == 1
  local dungeonIdx = mem.u8(AREA_DUNGEON_IDX)
  local dungeons, nextUp = readDungeons(inDungeon and dungeonIdx or -1)

  local area = mem.u8(ROOM_AREA)
  local location = area_names[area] or string.format("Area %02X", area)
  local dungeonMap = readDungeonMap(ui, inDungeon and dungeonIdx < 16, dungeonIdx, location)

  local worldX, worldY = linkWorldPos()

  local charmId = mem.u8(CHARM)
  local charmName = charmId ~= 0 and item_names.bottle[charmId] or nil
  local charmSeconds = mem.u16(CHARM_TIMER) // 60

  return {
    ready = true,
    waiting = false,
    ezlo = rom_gfx.ezlo() or "asset:ui/cap.png",

    rupees = tostring(rupees),
    walletMax = tostring(walletMax),
    kinstones = "x" .. pieceTotal,
    location = location,
    ezloHint = ezloHint(health, bombs, hasBombs, inDungeon, nextUp),

    map = {
      image = rom_gfx.worldMap() or FALLBACK_MAP,
      linkX = pct(fraction(worldX, WORLD_W)),
      linkY = pct(fraction(worldY, WORLD_H)),
      inDungeon = dungeonMap.inDungeon,
      showWorld = dungeonMap.showWorld,
      showDungeon = dungeonMap.showDungeon,
      visit = dungeonMap.visit,
    },
    dungeon = dungeonMap,
    link = readLink(health),

    equipA = equipSlot(EQUIPPED_A),
    equipB = equipSlot(EQUIPPED_B),
    items = items,

    gear = {
      bombs = tostring(bombs), bombMax = tostring(bombMax), bombPct = fraction(bombs, bombMax),
      arrows = tostring(arrows), arrowMax = tostring(arrowMax), arrowPct = fraction(arrows, arrowMax),
      shells = tostring(mem.u16(SHELLS)),
      heartPieces = mem.u8(HEART_PIECES) .. "/4",
      charm = charmName and charmName:upper() or "NONE",
      charmIcon = charmName and item_names.icon(charmName) or "",
      charmTime = charmName and string.format("%d:%02d", charmSeconds // 60, charmSeconds % 60) or "--:--",
    },

    kinstone = {
      fused = pad3(fused),
      fusionTotal = tostring(FUSION_TOTAL),
      fusedPct = fraction(fused, FUSION_TOTAL),
      pieces = pieces,
      red = tostring(byColor.Red), blue = tostring(byColor.Blue),
      green = tostring(byColor.Green), gold = tostring(byColor.Gold),
      -- No RAM flag for "an NPC nearby can fuse" has been found yet.
      ready = false,
      readyHint = "",
    },

    -- Fixed icons the layout shows (header, tallies, gear and quest stats).
    icons = {
      kinstoneRed = item_names.kinstoneIcon("Red"),
      kinstoneBlue = item_names.kinstoneIcon("Blue"),
      kinstoneGreen = item_names.kinstoneIcon("Green"),
      kinstoneGold = item_names.kinstoneIcon("Gold"),
      linkHead = rom_gfx.linkHead() or "asset:ui/mark-link.png",
      figurines = "asset:ui/figurine.png",
      tigerScroll = item_names.icon("Spin Attack") or "",
      heartPiece = rom_gfx.heartPiece(mem.u8(HEART_PIECES)) or "",
      shell = item_names.icon("Shells") or "",
      bombs = item_names.icon("Bombs") or "",
      quiver = item_names.icon("Quiver") or "",
      charm = (charmName and item_names.icon(charmName)) or item_names.icon("Farore's Charm") or "",
    },

    quest = {
      elements = readElements(),
      dungeons = dungeons,
      side = readSideQuests(),
      figurines = popcount(FIGURINES, FIGURINE_BYTES) .. "/" .. FIGURINE_TOTAL,
      skills = countOwned(item_names.skills) .. "/" .. #item_names.skills,
      heartPieces = mem.u8(HEART_PIECES) .. "/4",
      shells = tostring(mem.u16(SHELLS)),
    },
  }
end
