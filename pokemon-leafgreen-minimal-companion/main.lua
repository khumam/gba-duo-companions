-- Pokemon LeafGreen (US 1.0, BPGE), Pocket-OS companion.
--
-- Shared RAM addresses were cross-checked against Ironmon-Tracker's LeafGreen v1.0
-- table. ROM tables and Town Map graphics were byte-matched against this BPGE ROM
-- and the pret/pokefirered decompilation. update() returns the shape the layout binds.

local game = pack.require("game_data")
local town_map = pack.require("town_map")

-- ---- RAM ------------------------------------------------------------------------
-- gPlayerPartyCount / gPlayerParty: the live party (not SaveBlock1's copy).
local PARTY_COUNT_ADDR = 0x02024029
local PARTY_ADDR = 0x02024284
local POKEMON_SIZE = 0x64

local SAVEBLOCK1_PTR_ADDR = 0x03005008
local SAVEBLOCK2_PTR_ADDR = 0x0300500C

-- struct SaveBlock1
local MONEY_OFFSET = 0x0290      -- u32, XOR SaveBlock2's encryption key
local BAG_POCKETS = {            -- offset, slots
  items = { 0x0310, 42 }, keyItems = { 0x03B8, 30 }, balls = { 0x0430, 13 },
  tmHm = { 0x0464, 58 }, berries = { 0x054C, 43 },
}
local BADGE_BYTE_OFFSET = 0x0FE4 -- flags FLAG_BADGE01..08, one bit each

-- struct SaveBlock2
local PLAYER_NAME_OFFSET, PLAYER_NAME_LEN = 0x00, 7
local TRAINER_ID_OFFSET = 0x0A
local PLAYTIME_HOURS_OFFSET = 0x0E
local PLAYTIME_MINUTES_OFFSET = 0x10
local DEX_OWNED_OFFSET = 0x28    -- pokedex.owned[52]: bit n = national no. n+1
local DEX_SEEN_OFFSET = 0x5C
local ENCRYPTION_KEY_OFFSET = 0xF20
local KANTO_DEX = 151

-- Where the player is: gMapHeader (its regionMapSectionId names the place, its
-- mapLayout gives the map's size) and the player's object event (object 0)
-- whose currentCoords carry a 7-tile border offset (MAP_OFFSET).
local MAP_HEADER_ADDR = 0x02036DFC
local MAPSEC_OFFSET = 0x14
local MAPTYPE_OFFSET = 0x17      -- MAP_TYPE_TOWN 1, MAP_TYPE_ROUTE 3 are outdoors
local PLAYER_OBJECT_ADDR = 0x02036E38
local COORDS_OFFSET = 0x10
local MAP_OFFSET = 7

-- gBaseStats in ROM: 0x1C bytes per species.
local BASE_STATS_ADDR = 0x08254760
local BASE_STATS_SIZE = 0x1C

-- ---- Pokemon substructs ---------------------------------------------------------
-- The 48 secure bytes hold four 12-byte substructs (Growth, Attacks, EVs, Misc)
-- in one of 24 orders picked by personality % 24, XOR-ed with
-- personality ~ otId (pokemon.c, GetSubstruct).
local ORDERS = {
  [0] = "GAEM", "GAME", "GEAM", "GEMA", "GMAE", "GMEA", "AGEM", "AGME", "AEGM", "AEMG", "AMGE", "AMEG",
  "EGAM", "EGMA", "EAGM", "EAMG", "EMGA", "EMAG", "MGAE", "MGEA", "MAGE", "MAEG", "MEGA", "MEAG",
}

-- Decrypted substruct words: sub.G[0..2], sub.A[...], sub.M[...].
local function substructs(base)
  local personality, otId = mem.u32(base), mem.u32(base + 0x04)
  local key = personality ~ otId
  local order = ORDERS[personality % 24]
  local out = {}
  for slot = 0, 3 do
    local letter = order:sub(slot + 1, slot + 1)
    local words = {}
    for w = 0, 2 do words[w] = mem.u32(base + 0x20 + slot * 12 + w * 4) ~ key end
    out[letter] = words
  end
  return out, personality
end

local lo16 = function(v) return v & 0xFFFF end
local hi16 = function(v) return (v >> 16) & 0xFFFF end
local byte = function(v, n) return (v >> (n * 8)) & 0xFF end

-- ---- Look-ups --------------------------------------------------------------------

local TYPES = { [0] = "normal", "fighting", "flying", "poison", "ground", "rock", "bug", "ghost", "steel",
  "unknown", "fire", "water", "grass", "electric", "psychic", "ice", "dragon", "dark" }

-- Card colour as in the game's party screen: the light-blue slot, red once fainted.
-- (The type tints of the earlier look are gone; the type chip still shows the type.)
local TONE = {}
local DEFAULT_TONE = "#91D4EC"
local FAINTED_TONE = "#F2A8A0"
local INK = "#FFFFFF"

local NATURES = { [0] = "Hardy", "Lonely", "Brave", "Adamant", "Naughty", "Bold", "Docile", "Relaxed",
  "Impish", "Lax", "Timid", "Hasty", "Serious", "Jolly", "Naive", "Modest", "Mild", "Quiet", "Bashful",
  "Rash", "Calm", "Gentle", "Sassy", "Careful", "Quirky" }
-- Nature n raises stat n // 5 and lowers n % 5 (same stat = neutral), in this order:
local NATURE_STATS = { [0] = "ATK", "DEF", "SPE", "SP.A", "SP.D" }

local STATUS = { -- name, chip colour (the text is always INK)
  SLP = "#8C9AAE", PSN = "#A878D0", BRN = "#E8683C", FRZ = "#58B8E0", PAR = "#D8B020", TOX = "#A878D0",
  FNT = "#D05A4E",
}
local function statusTag(status)
  if status & 0x7 ~= 0 then return "SLP" end
  if status & 0x8 ~= 0 then return "PSN" end
  if status & 0x10 ~= 0 then return "BRN" end
  if status & 0x20 ~= 0 then return "FRZ" end
  if status & 0x40 ~= 0 then return "PAR" end
  if status & 0x80 ~= 0 then return "TOX" end
  return ""
end

local function speciesInfo(id)
  return game.species[id] or { name = "#" .. id, dex = 0 }
end

local function sprite(dex, back)
  if dex <= 0 then return "" end
  return "asset:pokemon/" .. (back and "back/" or "") .. dex .. ".png"
end

local function typeList(t1, t2)
  local out = {}
  for _, t in ipairs(t1 == t2 and { t1 } or { t1, t2 }) do
    local key = TYPES[t] or "unknown"
    out[#out + 1] = { name = key:upper(), src = "asset:types/" .. key .. ".png" }
  end
  return out
end

local function itemName(id)
  local name = game.items[id]
  if name then return name end
  if id >= 289 and id <= 338 then return string.format("TM%02d", id - 288) end
  if id >= 339 and id <= 346 then return string.format("HM%02d", id - 338) end
  return "ITEM #" .. id
end

local function itemIcon(id)
  if id >= 289 and id <= 338 then return "asset:items/tm.png" end
  if id >= 339 and id <= 346 then return "asset:items/hm.png" end
  return "asset:items/" .. id .. ".png"
end

-- Total EXP to reach level n for each growth rate (pokemon.h GROWTH_*), the
-- formulas the game's experience tables are built from.
local function expAt(rate, n)
  if n <= 1 then return 0 end
  local n3 = n * n * n
  if rate == 1 then -- erratic
    if n <= 50 then return n3 * (100 - n) // 50 end
    if n <= 68 then return n3 * (150 - n) // 100 end
    if n <= 98 then return n3 * ((1911 - 10 * n) // 3) // 500 end
    return n3 * (160 - n) // 100
  elseif rate == 2 then -- fluctuating
    if n <= 15 then return n3 * ((n + 1) // 3 + 24) // 50 end
    if n <= 36 then return n3 * (n + 14) // 50 end
    return n3 * (n // 2 + 32) // 50
  elseif rate == 3 then -- medium slow
    return math.max(0, 6 * n3 // 5 - 15 * n * n + 100 * n - 140)
  elseif rate == 4 then -- fast
    return 4 * n3 // 5
  elseif rate == 5 then -- slow
    return 5 * n3 // 4
  end
  return n3 -- medium fast
end

local function hpBands(hp, maxHp)
  local pct = maxHp > 0 and hp / maxHp or 0
  return pct, pct > 0.5, pct <= 0.5 and pct > 0.2, pct <= 0.2
end

-- The colour, HP and status fields every card shares.
local function dress(mon, t1, statusBits)
  local key = TYPES[t1] or "normal"
  mon.hpPct, mon.hpHigh, mon.hpMid, mon.hpLow = hpBands(mon.hp, mon.maxHp)
  mon.fainted = mon.hp == 0
  local tag = mon.fainted and "FNT" or statusTag(statusBits)
  mon.status, mon.hasStatus = tag, tag ~= ""
  mon.statusColor = STATUS[tag] or "#8C9AAE"
  mon.statusInk = INK
  mon.tone = mon.fainted and FAINTED_TONE or (TONE[key] or DEFAULT_TONE)
  mon.ink = INK
  return mon
end

-- ---- Party ----------------------------------------------------------------------------

local function readMon(slot)
  local base = PARTY_ADDR + slot * POKEMON_SIZE
  local sub, personality = substructs(base)
  local speciesId = lo16(sub.G[0])
  local info = speciesInfo(speciesId)
  local stats = BASE_STATS_ADDR + speciesId * BASE_STATS_SIZE
  local t1, t2 = mem.u8(stats + 6), mem.u8(stats + 7)
  local level = mem.u8(base + 0x54)

  -- Growth: held item, EXP, PP Ups (2 bits per move)
  local heldItem = hi16(sub.G[0])
  local exp = sub.G[1]
  local ppBonuses = byte(sub.G[2], 0)
  local rate = mem.u8(stats + 0x13)
  local floor, ceil = expAt(rate, level), expAt(rate, math.min(100, level + 1))
  local expPct = level >= 100 and 1 or math.max(0, math.min(1, (exp - floor) / math.max(1, ceil - floor)))

  -- Ability: the species' first or second, by bit 31 of Misc's IV word.
  local abilityNum = (sub.M[1] >> 31) & 1
  local ability = mem.u8(stats + 0x16 + abilityNum)
  if ability == 0 then ability = mem.u8(stats + 0x16) end

  -- Nature and stats
  local nature = personality % 25
  local up, down = NATURE_STATS[nature // 5], NATURE_STATS[nature % 5]
  if up == down then up, down = nil, nil end
  local hp, maxHp = mem.u16(base + 0x56), mem.u16(base + 0x58)
  local raw = {
    { "HP", maxHp }, { "ATK", mem.u16(base + 0x5A) }, { "DEF", mem.u16(base + 0x5C) },
    { "SP.A", mem.u16(base + 0x60) }, { "SP.D", mem.u16(base + 0x62) }, { "SPE", mem.u16(base + 0x5E) },
  }
  local top = 1
  for _, s in ipairs(raw) do top = math.max(top, s[2]) end
  local statList = {}
  for _, s in ipairs(raw) do
    statList[#statList + 1] = {
      name = s[1],
      value = s[1] == "HP" and (hp .. "/" .. maxHp) or tostring(s[2]),
      pct = s[2] / top,
      up = s[1] == up,
      down = s[1] == down,
    }
  end

  -- Attacks: moves and their PP (max = base PP + 20% per PP Up)
  local moves = {}
  for m = 0, 3 do
    local id = m < 2 and (m == 0 and lo16(sub.A[0]) or hi16(sub.A[0])) or (m == 2 and lo16(sub.A[1]) or hi16(sub.A[1]))
    if id ~= 0 then
      local move = game.moves[id] or { name = "MOVE #" .. id, type = "unknown", pp = 0 }
      local bonus = (ppBonuses >> (m * 2)) & 3
      local maxPp = move.pp + move.pp * bonus // 5
      moves[#moves + 1] = {
        name = move.name,
        type = "asset:types/" .. move.type .. ".png",
        pp = byte(sub.A[2], m) .. "/" .. maxPp,
      }
    end
  end

  return dress({
    name = info.name,
    dex = string.format("%03d", info.dex),
    sprite = sprite(info.dex),
    level = level,
    hp = hp,
    maxHp = maxHp,
    lead = slot == 0,
    types = typeList(t1, t2),
    nature = NATURES[nature],
    ability = game.abilities[ability] or "-",
    hasItem = heldItem ~= 0,
    item = heldItem ~= 0 and itemName(heldItem) or "NONE",
    itemIcon = heldItem ~= 0 and itemIcon(heldItem) or "",
    toNext = tostring(level >= 100 and 0 or math.max(0, ceil - exp)),
    expPct = expPct,
    stats = statList,
    moves = moves,
  }, t1, mem.u32(base + 0x50))
end

local function readParty(count)
  local party = {}
  for i = 0, count - 1 do party[#party + 1] = readMon(i) end
  return party
end

-- ---- Bag --------------------------------------------------------------------------------

local function readPocket(sb1, pocket)
  local offset, slots = pocket[1], pocket[2]
  local key = mem.u32(mem.u32(SAVEBLOCK2_PTR_ADDR) + ENCRYPTION_KEY_OFFSET) & 0xFFFF
  local list, total = {}, 0
  for i = 0, slots - 1 do
    local addr = sb1 + offset + i * 4
    local id = mem.u16(addr)
    if id ~= 0 then
      -- Quantities are XOR-ed with the low half of the key (SetBagItemQuantity).
      local qty = mem.u16(addr + 2) ~ key
      list[#list + 1] = { name = itemName(id), count = string.format("x%02d", qty), icon = itemIcon(id) }
      total = total + qty
    end
  end
  return list, total
end

-- ---- Battle -----------------------------------------------------------------------------
-- gBattleMons: struct BattlePokemon (0x58 bytes) per battler, with stat stages.
local BATTLE_MONS_ADDR = 0x02023BE4
local BATTLE_MON_SIZE = 0x58
local BATTLERS_COUNT_ADDR = 0x02023BCC
local BATTLE_OUTCOME_ADDR = 0x02023E8A     -- 0 while a battle is on
local BATTLE_MAIN_FUNC_ADDR = 0x03004F84
local RETURN_FROM_BATTLE_TO_OVERWORLD = 0x08015B59
local MAX_SPECIES = 411

-- name, offset in BattlePokemon, index in statStages[] (6 = neutral)
local BATTLE_STATS = {
  { "ATK", 0x02, 1 }, { "DEF", 0x04, 2 }, { "SP.A", 0x08, 4 }, { "SP.D", 0x0A, 5 }, { "SPE", 0x06, 3 },
}

local function inBattle()
  if mem.u8(BATTLE_OUTCOME_ADDR) ~= 0 then return false end
  if mem.u8(BATTLERS_COUNT_ADDR) < 2 then return false end
  local mainFunc = mem.u32(BATTLE_MAIN_FUNC_ADDR)
  if mainFunc == 0 or mainFunc == RETURN_FROM_BATTLE_TO_OVERWORLD then return false end
  local species = mem.u16(BATTLE_MONS_ADDR)
  return species > 0 and species <= MAX_SPECIES
end

local function readBattleMon(battler)
  local base = BATTLE_MONS_ADDR + battler * BATTLE_MON_SIZE
  local info = speciesInfo(mem.u16(base))
  local t1, t2 = mem.u8(base + 0x21), mem.u8(base + 0x22)
  local stats = {}
  for _, s in ipairs(BATTLE_STATS) do
    local stage = mem.u8(base + 0x18 + s[3]) - 6
    stats[#stats + 1] = {
      name = s[1],
      value = string.format("%3d", mem.u16(base + s[2])),
      stage = stage > 0 and ("+" .. stage) or (stage < 0 and tostring(stage) or "±0"),
      up = stage > 0,
      down = stage < 0,
      flat = stage == 0,
    }
  end
  return dress({
    name = info.name,
    level = mem.u8(base + 0x2A),
    hp = mem.u16(base + 0x28),
    maxHp = mem.u16(base + 0x2C),
    lead = false,
    sprite = sprite(info.dex, battler == 0),
    types = typeList(t1, t2),
    stats = stats,
  }, t1, mem.u32(base + 0x4C))
end

-- ---- Text ---------------------------------------------------------------------------------

local function decodeChar(c)
  if c == 0x00 then return " " end
  if c >= 0xA1 and c <= 0xAA then return string.char(48 + c - 0xA1) end
  if c >= 0xBB and c <= 0xD4 then return string.char(65 + c - 0xBB) end
  if c >= 0xD5 and c <= 0xEE then return string.char(97 + c - 0xD5) end
  return ({ [0xAB] = "!", [0xAC] = "?", [0xAD] = ".", [0xAE] = "-", [0xB4] = "'" })[c] or ""
end

local function readName(addr, len)
  local out = {}
  for i = 0, len - 1 do
    local c = mem.u8(addr + i)
    if c == 0xFF then break end
    out[#out + 1] = decodeChar(c)
  end
  return table.concat(out)
end

local function withCommas(n)
  local s = tostring(n)
  while true do
    local k
    s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
    if k == 0 then return s end
  end
end

-- ---- Pokedex ----------------------------------------------------------------------------

local function dexBit(addr, n) -- n = national number, 1-based
  return (mem.u8(addr + (n - 1) // 8) >> ((n - 1) % 8)) & 1 == 1
end

local function readDex(sb2)
  local seen, caught, highest = 0, 0, 0
  for n = 1, KANTO_DEX do
    if dexBit(sb2 + DEX_SEEN_OFFSET, n) then seen = seen + 1 end
    if dexBit(sb2 + DEX_OWNED_OFFSET, n) then caught, highest = caught + 1, n end
  end
  local name = "-"
  for _, s in pairs(game.species) do
    if s.dex == highest then name = s.name break end
  end
  return {
    seen = string.format("%03d", seen),
    caught = string.format("%03d", caught),
    total = tostring(KANTO_DEX),
    seenPct = seen / KANTO_DEX,
    caughtPct = caught / KANTO_DEX,
    completion = math.floor(caught * 100 / KANTO_DEX) .. "%",
    last = { name = name, no = string.format("%03d", highest), sprite = sprite(highest) },
  }, caught
end

-- ---- Map ----------------------------------------------------------------------------------

-- ---- Wild Pokemon --------------------------------------------------------------------
-- gWildMonHeaders (ROM, LeafGreen v1.0): 20 bytes per map, { mapGroup, mapNum, pad,
-- land, water, rockSmash, fishing } (pointers to { rate, pad, mons }), ended by
-- mapGroup 0xFF. Each mon is { minLevel, maxLevel, species u16 }. The slot chances are
-- wild_encounters.json's encounter_rates; fishing's 10 slots are three rods.
-- The player's map is gSaveBlock1 location (+4 group, +5 number).
local WILD_HEADERS_ADDR = 0x083C9AF4
local LOCATION_OFFSET = 0x04
local WILD_METHODS = {
  { key = "land", label = "GRASS", field = 4, slots = { 20, 20, 10, 10, 10, 10, 5, 5, 4, 4, 1, 1 } },
  { key = "water", label = "SURF", field = 8, slots = { 60, 30, 5, 4, 1 } },
  { key = "rock", label = "ROCK", field = 12, slots = { 60, 30, 5, 4, 1 } },
  { key = "old", label = "OLD ROD", field = 16, slots = { 70, 30 } },
  { key = "good", label = "GOOD ROD", field = 16, first = 2, slots = { 60, 20, 20 } },
  { key = "super", label = "SUPER ROD", field = 16, first = 5, slots = { 40, 40, 15, 4, 1 } },
}

local wildHeaderCache = {}
local function wildHeader(group, num)
  local id = group * 256 + num
  if wildHeaderCache[id] == nil then
    wildHeaderCache[id] = false
    for i = 0, 255 do
      local e = WILD_HEADERS_ADDR + i * 20
      local g = mem.u8(e)
      if g == 0xFF then break end
      if g == group and mem.u8(e + 1) == num then wildHeaderCache[id] = e break end
    end
  end
  return wildHeaderCache[id] or nil
end

local wildChoice -- the method key the player picked (actions.nextWild)
local wildAvailable = {}

-- The current map's wild Pokemon for the picked method (or the first one it has).
local function readWild(sb1)
  local header = wildHeader(mem.u8(sb1 + LOCATION_OFFSET), mem.u8(sb1 + LOCATION_OFFSET + 1))
  wildAvailable = {}
  if not header then return nil end
  for _, m in ipairs(WILD_METHODS) do
    local info = mem.u32(header + m.field)
    if info >= 0x08000000 and info < 0x0A000000 then wildAvailable[#wildAvailable + 1] = { m = m, info = info } end
  end
  if #wildAvailable == 0 then return nil end
  local pick = wildAvailable[1]
  for _, a in ipairs(wildAvailable) do if a.m.key == wildChoice then pick = a end end

  local mons = mem.u32(pick.info + 4)
  local bySpecies, order = {}, {}
  for i, chance in ipairs(pick.m.slots) do
    local e = mons + ((pick.m.first or 0) + i - 1) * 4
    local species = mem.u16(e + 2)
    local entry = bySpecies[species]
    if not entry then
      entry = { species = species, min = 255, max = 0, chance = 0 }
      bySpecies[species] = entry
      order[#order + 1] = entry
    end
    entry.min = math.min(entry.min, mem.u8(e))
    entry.max = math.max(entry.max, mem.u8(e + 1))
    entry.chance = entry.chance + chance
  end
  table.sort(order, function(a, b) return a.chance > b.chance end)
  local list = {}
  for _, e in ipairs(order) do
    local sp = game.species[e.species]
    list[#list + 1] = {
      sprite = sprite(sp and sp.dex or 0), name = sp and sp.name or "?",
      level = e.min == e.max and ("Lv" .. e.min) or ("Lv" .. e.min .. "-" .. e.max),
      chance = e.chance .. "%",
    }
  end
  return { method = pick.m.label, mons = list }
end

actions = actions or {}
--- The method tag: show the map's next encounter method.
function actions.nextWild()
  if #wildAvailable < 2 then return end
  local at = 1
  for i, a in ipairs(wildAvailable) do if a.m.key == wildChoice then at = i end end
  wildChoice = wildAvailable[at % #wildAvailable + 1].m.key
end

-- The radar is the game's own Town Map (town_map.lua), read from the ROM. The marker is
-- on the player's map section; outdoors it also moves across that section's cells as
-- the player crosses the map (Route 1 is two cells tall). Without the Town Map (an
-- unknown release) it falls back to the drawn radar, the player's tile on the current map.
local FALLBACK_RADAR = "asset:ui/radar.png"
local OUTDOORS = { [1] = true, [2] = true, [3] = true, [6] = true }

local function readMap(sb1)
  local mapsec = mem.u8(MAP_HEADER_ADDR + MAPSEC_OFFSET)
  local place = game.mapsecs[mapsec] or "KANTO"
  local layout = mem.u32(MAP_HEADER_ADDR)
  local w, h = 0, 0
  if layout >= 0x02000000 and layout < 0x0A000000 then w, h = mem.u32(layout), mem.u32(layout + 4) end
  local x = mem.u16(PLAYER_OBJECT_ADDR + COORDS_OFFSET) - MAP_OFFSET
  local y = mem.u16(PLAYER_OBJECT_ADDR + COORDS_OFFSET + 2) - MAP_OFFSET
  -- How far across the map the player is, 0-1 (the middle when the size is unknown).
  local function across(v, size)
    if size <= 0 or size > 1000 then return 0.5 end
    return math.max(0, math.min(1, (v + 0.5) / size))
  end

  local wild = readWild(sb1)
  local cell = game.mapCells[mapsec]
  local region = cell and cell.region or 0
  local image = town_map.image(region)
  local mx, my, onMap = 50, 50, true
  if image then
    if cell then
      local outdoors = OUTDOORS[mem.u8(MAP_HEADER_ADDR + MAPTYPE_OFFSET)]
      mx, my = town_map.place(cell, outdoors and across(x, w) or 0.5, outdoors and across(y, h) or 0.5)
    else
      onMap = false
    end
  else
    local function pct(v) return math.floor(math.max(0.06, math.min(0.94, v)) * 1000 + 0.5) / 10 end
    mx, my = pct(across(x, w)), pct(across(y, h))
  end

  return place, {
    image = image or FALLBACK_RADAR,
    region = image and town_map.REGIONS[region] or "KANTO",
    x = mx, y = my, onMap = onMap,
    town = place,
    wild = wild and wild.mons or {}, wildMethod = wild and wild.method or "",
    hasWild = wild ~= nil, noWild = wild == nil,
    pins = {},
  }
end

-- -----------------------------------------------------------------------------------------

local function inEwram(p) return p >= 0x02000000 and p < 0x02040000 end

local wasInBattle = false

function update()
  -- ponytail: only BPGE v1.0 is verified; add a revision table before supporting v1.1.
  if mem.u32(0x080000AC) ~= 0x45475042 or mem.u8(0x080000BC) ~= 0 then
    wasInBattle = false
    return { ready = false, waiting = true }
  end
  local sb1 = mem.u32(SAVEBLOCK1_PTR_ADDR)
  local sb2 = mem.u32(SAVEBLOCK2_PTR_ADDR)
  local partyCount = mem.u8(PARTY_COUNT_ADDR)
  -- In a game once the player's overworld object exists (gObjectEvents[0].active): not
  -- on the title screen or in Oak's intro, but from the bedroom on, Pokemon or not (a
  -- new game has none until Oak's lab).
  local inGame = mem.u8(PLAYER_OBJECT_ADDR) & 1 == 1
  if not (inEwram(sb1) and inEwram(sb2)) or not inGame or partyCount > 6 then
    wasInBattle = false
    return { ready = false, waiting = true }
  end

  local money = mem.u32(sb1 + MONEY_OFFSET) ~ mem.u32(sb2 + ENCRYPTION_KEY_OFFSET)
  local hours = mem.u16(sb2 + PLAYTIME_HOURS_OFFSET)
  local minutes = mem.u8(sb2 + PLAYTIME_MINUTES_OFFSET)
  local playTime = string.format("%02d:%02d", hours, minutes)

  local badgeByte = mem.u8(sb1 + BADGE_BYTE_OFFSET)
  local badgeCount, badges = 0, {}
  local BADGES = { "BOULDER", "CASCADE", "THUNDER", "RAINBOW", "SOUL", "MARSH", "VOLCANO", "EARTH" }
  for b = 0, 7 do
    local earned = (badgeByte >> b) & 1 == 1
    if earned then badgeCount = badgeCount + 1 end
    badges[#badges + 1] = { name = BADGES[b + 1], earned = earned, locked = not earned, src = "asset:badges/" .. (b + 1) .. ".png" }
  end

  local bag, bagTotal = {}, 0
  for pocket, spec in pairs(BAG_POCKETS) do
    local list, total = readPocket(sb1, spec)
    bag[pocket], bagTotal = list, bagTotal + total
  end
  bag.total = tostring(bagTotal)

  local dex, caught = readDex(sb2)
  local place, map = readMap(sb1)

  local battling = inBattle()
  local battle = { inBattle = battling, noBattle = not battling }
  if battling then
    battle.you = readBattleMon(0)
    battle.foe = readBattleMon(1)
  end

  local out = {
    ready = true,
    waiting = false,
    location = place,
    time = playTime,
    money = withCommas(money),
    map = map,
    partyCount = tostring(partyCount),
    party = readParty(partyCount),
    bag = bag,
    dex = dex,
    trainer = {
      name = readName(sb2 + PLAYER_NAME_OFFSET, PLAYER_NAME_LEN),
      id = string.format("%05d", mem.u16(sb2 + TRAINER_ID_OFFSET)),
      money = withCommas(money),
      time = playTime,
      badges = badgeCount .. "/8",
      caught = string.format("%03d", caught),
      badgeList = badges,
    },
    battle = battle,
  }

  -- Open the battle page when a battle starts and go back when it ends: only
  -- on the change, so the player can still tap away from it mid-battle.
  if battling and not wasInBattle then
    out.ui = { navigate = "battle" }
  elseif wasInBattle and not battling then
    out.ui = { back = true }
  end
  wasInBattle = battling
  return out
end
