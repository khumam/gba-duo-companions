-- Pokemon FireRed (US 1.0, BPRE), Pocket-OS companion.
--
-- RAM layout from the pret/pokefirered decompilation (include/global.h,
-- include/pokemon.h, include/battle.h); battle addresses cross-checked with the
-- Ironmon-Tracker's FireRed v1.0 table. Names, moves, abilities and map
-- sections come from game_data.lua, generated from the same decompilation.
-- update() returns the shape the layout binds (see preview-data.json).

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
local BASE_STATS_ADDR = 0x08254784
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

local function readMonAt(base, isLead)
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
    lead = isLead,
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

local function readMon(slot) return readMonAt(PARTY_ADDR + slot * POKEMON_SIZE, slot == 0) end

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
    types = typeList(t1, t2), t1 = t1, t2 = t2,
    stats = stats,
  }, t1, mem.u32(base + 0x4C))
end

-- ---- Text ---------------------------------------------------------------------------------

local PUNCT = { [0xAB] = "!", [0xAC] = "?", [0xAD] = ".", [0xAE] = "-", [0xB4] = "'", [0xB8] = ",",
  [0xBA] = "/", [0x1B] = "é", [0xFE] = " ", [0xFA] = " ", [0xFB] = " " }
local function decodeChar(c)
  if c == 0x00 then return " " end
  if c >= 0xA1 and c <= 0xAA then return string.char(48 + c - 0xA1) end
  if c >= 0xBB and c <= 0xD4 then return string.char(65 + c - 0xBB) end
  if c >= 0xD5 and c <= 0xEE then return string.char(97 + c - 0xD5) end
  return PUNCT[c] or ""
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

-- Longer ROM text (Pokedex entries): a line break after a hyphen joins the word. ROM text never
-- changes, so each string is read once.
local function readString(addr, maxLen)
  local out = {}
  for i = 0, maxLen - 1 do
    local c = mem.u8(addr + i)
    if c == 0xFF then break end
    if c == 0xFE and out[#out] == "-" then c = 0xFD end
    out[#out + 1] = decodeChar(c)
  end
  return table.concat(out)
end
local romText = {}
local function rom(addr, maxLen)
  local s = romText[addr]
  if not s then s = readString(addr, maxLen); romText[addr] = s end
  return s
end
local function romPtr(tableAddr, index, maxLen)
  local p = mem.u32(tableAddr + index * 4)
  if p < 0x08000000 or p >= 0x0A000000 then return "" end
  return rom(p, maxLen)
end

local function withCommas(n)
  local s = tostring(n)
  while true do
    local k
    s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
    if k == 0 then return s end
  end
end

actions = actions or {}

-- ---- Pokedex ----------------------------------------------------------------------------
-- struct PokedexEntry (0x24 bytes) per national no.: category[12], height (dm) @12, weight (hg) @14,
-- description ptr @16 (gPokedexEntries, from pret's pokefirered symbol files).
local DEX_ENTRIES = 0x0844E850
local DEX_ENTRY_SIZE = 0x24
local DEX_PAGE = 24
local dexState = { start = 1, sel = 1 }

local internalOf
local function internalId(national)
  if not internalOf then
    internalOf = {}
    for internal, s in pairs(game.species) do
      if s.dex > 0 then internalOf[s.dex] = internal end
    end
  end
  return internalOf[national] or 0
end
local function dexBit(addr, n) -- n = national number, 1-based
  return (mem.u8(addr + (n - 1) // 8) >> ((n - 1) % 8)) & 1 == 1
end
local function tenths(v) return (v // 10) .. "." .. (v % 10) end

--- The pager's arrows: move the list a page, selecting its first entry.
function actions.dexPage(delta)
  local pages = (KANTO_DEX + DEX_PAGE - 1) // DEX_PAGE
  local page = ((dexState.start - 1) // DEX_PAGE + (tonumber(delta) or 0)) % pages
  dexState.start = page * DEX_PAGE + 1
  dexState.sel = dexState.start
end
--- Tap a row: show its entry on the right.
function actions.dexSelect(n)
  n = tonumber(n)
  if n and n >= 1 and n <= KANTO_DEX then dexState.sel = n end
end

local STAT_LABELS = { "HP", "ATTACK", "DEFENSE", "SP. ATK", "SP. DEF", "SPEED" }
local STAT_ORDER = { 0, 1, 2, 4, 5, 3 } -- base stat bytes are hp, atk, def, spe, spa, spd

local function readDex(sb2)
  local seenBase, ownBase = sb2 + DEX_SEEN_OFFSET, sb2 + DEX_OWNED_OFFSET
  local seen, caught, highest = 0, 0, 0
  for n = 1, KANTO_DEX do
    if dexBit(seenBase, n) then seen = seen + 1 end
    if dexBit(ownBase, n) then caught, highest = caught + 1, n end
  end
  local name = "-"
  if highest > 0 then name = speciesInfo(internalId(highest)).name end

  -- the page of the list and the selected entry
  local entries = {}
  local first = dexState.start
  local last = math.min(KANTO_DEX, first + DEX_PAGE - 1)
  for n = first, last do
    local s, o = dexBit(seenBase, n), dexBit(ownBase, n)
    entries[#entries + 1] = {
      num = n, no = string.format("%03d", n), name = s and speciesInfo(internalId(n)).name or "-----",
      sprite = s and sprite(n) or "", seen = s, unseen = not s, own = o, sel = n == dexState.sel,
    }
  end
  local n = dexState.sel
  local s, o = dexBit(seenBase, n), dexBit(ownBase, n)
  local internal = internalId(n)
  local sel = {
    no = string.format("%03d", n), seen = s, unseen = not s, own = o,
    name = s and speciesInfo(internal).name or "-----", sprite = s and sprite(n) or "",
    state = o and "OWNED" or (s and "SEEN" or "NOT SEEN"),
    category = "", height = "--", weight = "--", abilities = "--", types = {}, stats = {},
    desc = s and "CATCH THIS POKéMON TO FILL IN ITS ENTRY." or "YOU HAVEN'T SEEN THIS POKéMON YET.",
  }
  if s then
    local base = BASE_STATS_ADDR + internal * BASE_STATS_SIZE
    sel.types = typeList(mem.u8(base + 6), mem.u8(base + 7))
    for i, idx in ipairs(STAT_ORDER) do
      local v = mem.u8(base + idx)
      sel.stats[i] = { label = STAT_LABELS[i], value = tostring(v), pct = math.min(1, v / 150) }
    end
    local a1, a2 = mem.u8(base + 0x16), mem.u8(base + 0x17)
    local n1, n2 = game.abilities[a1] or "-", game.abilities[a2] or "-"
    sel.abilities = (a2 == 0 or a2 == a1) and n1 or (n1 .. " / " .. n2)
  end
  if o then
    local entry = DEX_ENTRIES + n * DEX_ENTRY_SIZE
    sel.category = rom(entry, 11) .. " POKéMON"
    sel.height, sel.weight = tenths(mem.u16(entry + 12)) .. "m", tenths(mem.u16(entry + 14)) .. "kg"
    sel.desc = romPtr(entry + 16, 0, 220)
  end
  local pages = (KANTO_DEX + DEX_PAGE - 1) // DEX_PAGE
  return {
    seen = string.format("%03d", seen),
    caught = string.format("%03d", caught),
    total = tostring(KANTO_DEX),
    seenPct = seen / KANTO_DEX,
    caughtPct = caught / KANTO_DEX,
    completion = math.floor(caught * 100 / KANTO_DEX) .. "%",
    last = { name = name, no = string.format("%03d", highest), sprite = sprite(highest) },
    entries = entries, sel = sel,
    range = string.format("%03d-%03d", first, last),
    page = ((first - 1) // DEX_PAGE + 1) .. "/" .. pages,
  }, caught
end

-- ---- Map ----------------------------------------------------------------------------------

-- ---- Wild Pokemon --------------------------------------------------------------------
-- gWildMonHeaders (ROM, FireRed v1.0): 20 bytes per map, { mapGroup, mapNum, pad,
-- land, water, rockSmash, fishing } (pointers to { rate, pad, mons }), ended by
-- mapGroup 0xFF. Each mon is { minLevel, maxLevel, species u16 }. The slot chances are
-- wild_encounters.json's encounter_rates; fishing's 10 slots are three rods.
-- The player's map is gSaveBlock1 location (+4 group, +5 number).
local WILD_HEADERS_ADDR = 0x083C9CB8
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


-- ---- Battle: moves, effectiveness and the controls ------------------------------------------
-- Addresses from pret's pokefirered / pokeleafgreen symbol files (v1.0): the controller buffers, the
-- busy flags, the menu cursors, gBattleMoves in ROM.
local BATTLE_MOVES_ADDR = 0x08250C04      -- 12 bytes per move: effect, power, type, accuracy, pp, _, target
local BUFFER_A_ADDR = 0x02022BC4       -- gBattleBufferA[battler][0x200]: [0] = the command the controller is on
local BUFFER_B_ADDR = 0x020233C4       -- gBattleBufferB[battler][0x200]: what the controller answers the engine
local EXEC_FLAGS_ADDR = 0x02023BC8     -- gBattleControllerExecFlags: bit n = battler n's controller is busy
local CONTROLLER_FUNCS_ADDR = 0x03004FE0 -- gBattlerControllerFuncs[battler] (function pointers)
local PLAYER_RUN_COMMAND = 0x0802E3B5  -- PlayerBufferRunCommand (thumb); also learned from the game below
local ACTION_CURSOR_ADDR = 0x02023FF8  -- gActionSelectionCursor[battler]: 0 FIGHT, 1 BAG, 2 POKEMON, 3 RUN
local MOVE_CURSOR_ADDR = 0x02023FFC    -- gMoveSelectionCursor[battler]: move slot 0-3
local BATTLE_TYPE_FLAGS_ADDR = 0x02022B4C
local BATTLER_PARTY_INDEXES_ADDR = 0x02023BCE
local ENEMY_PARTY_ADDR = 0x0202402C
local BATTLE_TYPE_DOUBLE, BATTLE_TYPE_TRAINER = 0x01, 0x08
local CONTROLLER_CHOOSEACTION, CONTROLLER_CHOOSEMOVE, CONTROLLER_TWORETURNVALUES = 18, 20, 33
local B_ACTION_EXEC_SCRIPT = 10        -- "a move was chosen" reply of the move menu

-- Gen III type chart: [attacking type] = { [defending type] = E2 (super effective), E1 (not very), 0 (immune) }
local E2, E1 = 4, 1
local CHART = {
  [0] = { [5] = E1, [8] = E1, [7] = 0 },
  [1] = { [0] = E2, [2] = E1, [3] = E1, [5] = E2, [6] = E1, [7] = 0, [8] = E2, [14] = E1, [15] = E2, [17] = E2 },
  [2] = { [1] = E2, [5] = E1, [6] = E2, [8] = E1, [12] = E2, [13] = E1 },
  [3] = { [3] = E1, [4] = E1, [5] = E1, [7] = E1, [8] = 0, [12] = E2 },
  [4] = { [2] = 0, [3] = E2, [5] = E2, [6] = E1, [8] = E2, [10] = E2, [12] = E1, [13] = E2 },
  [5] = { [1] = E1, [2] = E2, [4] = E1, [6] = E2, [8] = E1, [10] = E2, [15] = E2 },
  [6] = { [1] = E1, [2] = E1, [3] = E1, [7] = E1, [8] = E1, [10] = E1, [12] = E2, [14] = E2, [17] = E2 },
  [7] = { [0] = 0, [7] = E2, [8] = E1, [14] = E2, [17] = E1 },
  [8] = { [5] = E2, [8] = E1, [10] = E1, [11] = E1, [13] = E1, [15] = E2 },
  [10] = { [5] = E1, [6] = E2, [8] = E2, [10] = E1, [11] = E1, [12] = E2, [15] = E2, [16] = E1 },
  [11] = { [4] = E2, [5] = E2, [10] = E2, [11] = E1, [12] = E1, [16] = E1 },
  [12] = { [2] = E1, [3] = E1, [4] = E2, [5] = E2, [6] = E1, [8] = E1, [10] = E1, [11] = E2, [12] = E1, [16] = E1 },
  [13] = { [2] = E2, [4] = 0, [11] = E2, [12] = E1, [13] = E1, [16] = E1 },
  [14] = { [1] = E2, [3] = E2, [8] = E1, [14] = E1, [17] = 0 },
  [15] = { [2] = E2, [4] = E2, [8] = E1, [10] = E1, [11] = E1, [12] = E2, [15] = E1, [16] = E2 },
  [16] = { [8] = E1, [16] = E2 },
  [17] = { [1] = E1, [7] = E2, [8] = E1, [14] = E2, [17] = E1 },
}
-- the multiplier x4: neutral 4, super effective 8, double 16, half 2, quarter 1, immune 0
local function effectiveness(moveType, t1, t2)
  local row = CHART[moveType]
  local function one(def)
    local m = row and row[def]
    if m == nil then return 2 end
    if m == 0 then return 0 end
    return m == E2 and 4 or 1
  end
  local a = one(t1)
  local b = t2 ~= t1 and one(t2) or 2
  return a * b
end

local function battleMoveName(id) return (game.moves[id] or { name = "MOVE #" .. id }).name end

local function readBattleMoves(battler, foe)
  local base = BATTLE_MONS_ADDR + battler * BATTLE_MON_SIZE
  local out, best, bestScore = {}, nil, 0
  local cursor = mem.u8(MOVE_CURSOR_ADDR)
  for m = 0, 3 do
    local id = mem.u16(base + 0x0C + m * 2)
    if id ~= 0 then
      local data = BATTLE_MOVES_ADDR + id * 12
      local power, acc, mtype = mem.u8(data + 1), mem.u8(data + 3), mem.u8(data + 2)
      local eff = effectiveness(mtype, foe.t1, foe.t2)
      local label = power == 0 and "--" or (eff == 0 and "x0" or (eff == 4 and "x1" or (eff > 4 and ("x" .. (eff // 4)) or (eff == 2 and "x1/2" or "x1/4"))))
      local score = power * eff
      if score > bestScore then bestScore, best = score, battleMoveName(id) .. " " .. label end
      out[#out + 1] = {
        name = battleMoveName(id), pp = tostring(mem.u8(base + 0x24 + m)),
        type = "asset:types/" .. (TYPES[mtype] or "normal") .. ".png", has = true,
        info = "PWR " .. (power > 0 and power or "--") .. "  ACC " .. (acc > 0 and acc or "--"),
        eff = label, se = power > 0 and eff > 4, nve = power > 0 and eff < 4 and eff > 0, imm = power > 0 and eff == 0,
        sel = m == cursor,
      }
    else
      out[#out + 1] = { name = "-", pp = "--", type = "", has = false, info = "", eff = "", se = false, nve = false, imm = false, sel = false }
    end
  end
  return out, best and ("BEST: " .. best) or "PICK A MOVE"
end

-- Which menu the game is on: the player's controller (battler 0) is busy with a CHOOSEACTION or
-- CHOOSEMOVE command. This drives the page flow (action page -> move page -> back, every turn).
local function menuState()
  if mem.u32(EXEC_FLAGS_ADDR) & 1 == 0 then return "idle" end
  local cmd = mem.u8(BUFFER_A_ADDR)
  if cmd == CONTROLLER_CHOOSEACTION then return "action" end
  if cmd == CONTROLLER_CHOOSEMOVE then return "moves" end
  return "busy"
end

-- PlayerBufferRunCommand's address is also learned from the game: whenever the player's controller is
-- idle its function pointer is exactly that. Needed to hand control back after a faked A press.
local runSeen, runCmd = {}, PLAYER_RUN_COMMAND
local function learnRunCommand()
  if mem.u32(EXEC_FLAGS_ADDR) & 1 ~= 0 then return end
  local f = mem.u32(CONTROLLER_FUNCS_ADDR)
  if f >= 0x08000000 and f < 0x0A000000 and f & 1 == 1 then
    runSeen[f] = (runSeen[f] or 0) + 1
    if runSeen[f] >= 3 then runCmd = f end
  end
end

-- What pressing A does in the game's menus, done by hand: the controller answers the battle engine
-- (gBattleBufferB), hands control back to PlayerBufferRunCommand and clears its busy flag, exactly like
-- PlayerBufferExecCompleted. The engine then carries on as if A was pressed.
local function pressA(reply1, reply2, reply3)
  if not runCmd then return false, "THE GAME ISN'T READY YET, TRY AGAIN IN A MOMENT" end
  local flags = mem.u32(EXEC_FLAGS_ADDR)
  local ok, why = mem.write(BUFFER_B_ADDR, string.char(CONTROLLER_TWORETURNVALUES, reply1, reply2, reply3))
  if ok then ok, why = mem.write32(CONTROLLER_FUNCS_ADDR, runCmd) end
  if ok then ok, why = mem.write32(EXEC_FLAGS_ADDR, flags & ~1) end
  return ok, why
end

local ACTION_NAMES = { [0] = "FIGHT", "BAG", "POKéMON", "RUN" }
local function say(text) log("battle: " .. text) end

--- Tap an entry of the action menu (FIGHT / BAG / POKéMON / RUN): move the cursor, then press A.
function actions.setAction(index)
  if not inBattle() then return say("NOT IN A BATTLE") end
  index = tonumber(index) or 0
  local ok, why = mem.write8(ACTION_CURSOR_ADDR, index)
  if not ok then return say("CAN'T CHANGE THE GAME: " .. tostring(why)) end
  if menuState() ~= "action" or mem.u32(BATTLE_TYPE_FLAGS_ADDR) & BATTLE_TYPE_DOUBLE ~= 0 then
    return say("CURSOR ON " .. ACTION_NAMES[index] .. "  -  WAITING FOR YOUR TURN")
  end
  ok, why = pressA(index, 0, 0)
  if not ok then return say("CURSOR ON " .. ACTION_NAMES[index] .. "  -  PRESS A (" .. tostring(why) .. ")") end
  return say(ACTION_NAMES[index])
end

--- Tap a move: move the cursor to it, then press A (singles only; a move that needs a target is left
--- to the game).
function actions.setMove(index)
  if not inBattle() then return say("NOT IN A BATTLE") end
  index = tonumber(index) or 0
  local id = mem.u16(BATTLE_MONS_ADDR + 0x0C + index * 2)
  if id == 0 then return say("NO MOVE IN THAT SLOT") end
  local ok, why = mem.write8(MOVE_CURSOR_ADDR, index)
  if not ok then return say("CAN'T CHANGE THE GAME: " .. tostring(why)) end
  local target = mem.u8(BATTLE_MOVES_ADDR + id * 12 + 6)
  if menuState() ~= "moves" then
    return say("CURSOR ON " .. battleMoveName(id) .. "  -  WAITING FOR THE MOVE MENU")
  end
  if mem.u32(BATTLE_TYPE_FLAGS_ADDR) & BATTLE_TYPE_DOUBLE ~= 0 or target & 0x02 ~= 0 then
    return say("CURSOR ON " .. battleMoveName(id) .. "  -  PRESS A (IT NEEDS A TARGET)")
  end
  if mem.u8(BATTLE_MONS_ADDR + 0x24 + index) == 0 then return say(battleMoveName(id) .. " HAS NO PP LEFT") end
  -- the target is the user for self-targeting moves, the opposing battler otherwise
  ok, why = pressA(B_ACTION_EXEC_SCRIPT, index, (target & 0x10 ~= 0) and 0 or 1)
  if not ok then return say("CURSOR ON " .. battleMoveName(id) .. "  -  PRESS A (" .. tostring(why) .. ")") end
  return say(battleMoveName(id))
end

-- The radar is the game's own Town Map (town_map.lua), read from the ROM. The marker is
-- on the player's map section; outdoors it also moves across that section's cells as
-- the player crosses the map (Route 1 is two cells tall). Without the Town Map (an
-- unknown release) it falls back to the drawn radar, the player's tile on the current map.
local FALLBACK_RADAR = "asset:ui/radar.png"
local OUTDOORS = { [1] = true, [2] = true, [3] = true, [6] = true }

-- ---- Live area map: the TOWN view of the map page ----------------------------------------------
-- The area around the player, drawn from the game's own map data in RAM (gfx.layers), cut to the card's shape. The
-- view follows the player a tile at a time and stops at the map's edges; a map smaller than the view is centred. It
-- is drawn only while the map page shows it and the overworld is on screen; a picture drawn earlier stays until the
-- area changes. (The same approach as the Emerald pack's Map page; FireRed's VMap is gBackupMapLayout.)
local VMAP_ADDR = 0x03005040              -- VMap { s32 width; s32 height; u16 *map }
local GMAIN_ADDR = 0x030030F0             -- gMain; callback2 (+4) is CB2_Overworld while the player walks around
local CB2_OVERWORLD = 0x080565B5          -- CB2_Overworld (thumb)
local MAPGRID_UNDEFINED = 0x3FF
local NUM_METATILES_IN_PRIMARY = 640
local MAP_VIEW_ASPECT = 1.2335            -- the card's shape (280 x 227 dp): the picture fills it exactly
local MAP_VIEW_MIN_W, MAP_VIEW_MAX_W = 208, 288 -- world px the card shows across: a small map is zoomed in, a big one scrolls
local MAP_VIEW_FLOOR_W = 160              -- never shrink the view below this
-- A script call may run 25 ms and drawing the picture counts: if a call is ever cut off the view shrinks a step.
local MAP_SHRINK_STEP = 32
local MAP_SETTLE_TICKS = 3                -- between the draws of a new area (its tiles load a little late)
local MAP_SETTLE_MAX = 4                  -- draws before a new area is shown whatever it looks like (animated tiles never match)
local areaShot = { sig = nil, shown = nil, pending = nil, maxW = MAP_VIEW_MAX_W }

local function overworldOnScreen() return mem.u32(GMAIN_ADDR + 4) == CB2_OVERWORLD end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function areaPicture(draw)
  local layout = mem.u32(MAP_HEADER_ADDR)
  if layout < 0x08000000 or layout >= 0x0A000000 then return nil end
  local w, h = mem.u32(layout), mem.u32(layout + 4)
  local gridW, gridH, grid = mem.u32(VMAP_ADDR), mem.u32(VMAP_ADDR + 4), mem.u32(VMAP_ADDR + 8)
  local primary, secondary = mem.u32(layout + 0x10), mem.u32(layout + 0x14)
  if w < 1 or h < 1 or w > 256 or h > 256 or gridW < w or gridH < h or gridW > 1024 or gridH > 1024 then return nil end
  if grid < 0x02000000 or grid >= 0x02040000 or primary < 0x08000000 or secondary < 0x08000000 then return nil end

  local mapW, mapH = w * 16, h * 16
  local viewW = math.max(MAP_VIEW_FLOOR_W, math.min(clamp(mapW, MAP_VIEW_MIN_W, MAP_VIEW_MAX_W), areaShot.maxW))
  local viewH = math.floor(viewW / MAP_VIEW_ASPECT + 0.5)
  -- the player, in map pixels (the tile's middle)
  local px = mem.u16(PLAYER_OBJECT_ADDR + COORDS_OFFSET) * 16 + 8 - MAP_OFFSET * 16
  local py = mem.u16(PLAYER_OBJECT_ADDR + COORDS_OFFSET + 2) * 16 + 8 - MAP_OFFSET * 16
  local function camera(p, view, size)
    if size <= view then return (size - view) // 2 end
    return clamp((p - view // 2) // 16 * 16, 0, size - view)
  end
  local cx, cy = camera(px, viewW, mapW), camera(py, viewH, mapH)

  local sig = layout .. ":" .. grid .. ":" .. w .. "x" .. h
  local camSig = sig .. ":" .. viewW .. ":" .. cx .. ":" .. cy
  if sig ~= areaShot.sig then
    -- A new area: the picture on screen stays until the new one is ready, so nothing blinks while its tiles load.
    areaShot.sig, areaShot.pending = sig, { draws = 0, wait = MAP_SETTLE_TICKS, last = nil }
  end

  -- Draw it; nil when the call was cut off (then the view is made smaller for next time).
  local function render()
    local ok, key = pcall(gfx.layers, {
      x = MAP_OFFSET * 16 + cx, y = MAP_OFFSET * 16 + cy, width = viewW, height = viewH, scale = 1,
      grid = grid, gridW = gridW, gridH = gridH, idMask = 0x3FF,
      border = mem.u32(layout + 8), borderW = mem.u8(layout + 0x18), borderH = mem.u8(layout + 0x19),
      borderShift = MAP_OFFSET, undefinedId = MAPGRID_UNDEFINED,
      metatiles = mem.u32(primary + 0x0C), metatiles2 = mem.u32(secondary + 0x0C), split = NUM_METATILES_IN_PRIMARY,
      tiles = 0x06000000, palette = 0x05000000,
    })
    if ok then return key end
    if tostring(key):find("time limit") then areaShot.maxW = math.max(MAP_VIEW_FLOOR_W, viewW - MAP_SHRINK_STEP) end
    return nil
  end
  local function show(key)
    areaShot.shown = { image = key, sig = sig, camSig = camSig, cx = cx, cy = cy, viewW = viewW, viewH = viewH }
  end

  if draw then
    local pending = areaShot.pending
    if pending then
      pending.wait = pending.wait + 1
      if pending.wait >= MAP_SETTLE_TICKS then
        pending.wait = 0
        local key = render()
        if key then
          pending.draws = pending.draws + 1
          if key == pending.last or pending.draws >= MAP_SETTLE_MAX then show(key); areaShot.pending = nil
          else pending.last = key end
        end
      end
    elseif not areaShot.shown or areaShot.shown.camSig ~= camSig then
      local key = render()
      if key then show(key) end
    end
  end

  local shown = areaShot.shown
  if not shown then return nil end
  -- the pin only while the picture on screen is this area
  local fx, fy = (px - shown.cx) / shown.viewW, (py - shown.cy) / shown.viewH
  local hasMe = shown.sig == sig and fx >= 0 and fx <= 1 and fy >= 0 and fy <= 1
  return { image = shown.image, hasMe = hasMe,
    x = string.format("%.2f%%", clamp(fx, 0, 1) * 100), y = string.format("%.2f%%", clamp(fy, 0, 1) * 100) }
end

local function readMap(sb1, draw, mode)
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
  local showTown = mode ~= "world"
  local out = {
    showTown = showTown, showWorld = not showTown,
    town = place,
    wild = wild and wild.mons or {}, wildMethod = wild and wild.method or "",
    hasWild = wild ~= nil, noWild = wild == nil,
    pins = {},
    -- the TOWN view: the live area picture
    townLive = false, townOff = showTown, areaImage = "", areaX = "50%", areaY = "50%", areaHasMe = false,
    -- the WORLD view: the Town Map
    image = FALLBACK_RADAR, region = "KANTO", x = 50, y = 50, onMap = true,
  }
  if showTown then
    local pic = areaPicture(draw and overworldOnScreen())
    if pic then
      out.townLive, out.townOff = true, false
      out.areaImage, out.areaX, out.areaY, out.areaHasMe = pic.image, pic.x, pic.y, pic.hasMe
    end
  else
    local cell = game.mapCells[mapsec]
    local region = cell and cell.region or 0
    local image = town_map.image(region)
    local mx, my = 50, 50
    if image then
      if cell then
        local outdoors = OUTDOORS[mem.u8(MAP_HEADER_ADDR + MAPTYPE_OFFSET)]
        mx, my = town_map.place(cell, outdoors and across(x, w) or 0.5, outdoors and across(y, h) or 0.5)
      else
        out.onMap = false
      end
    else
      local function pct(v) return math.floor(math.max(0.06, math.min(0.94, v)) * 1000 + 0.5) / 10 end
      mx, my = pct(across(x, w)), pct(across(y, h))
    end
    out.image, out.region, out.x, out.y = image or FALLBACK_RADAR, image and town_map.REGIONS[region] or "KANTO", mx, my
  end
  return place, out
end

-- -----------------------------------------------------------------------------------------

local function inEwram(p) return p >= 0x02000000 and p < 0x02040000 end

local wasInBattle, lastState, pageBeforeBattle = false, "idle", "map"
local dexOut, dexCaught, dexAge = nil, 0, 0

function update(ui)
  local currentPage = ui and ui.page
  local sb1 = mem.u32(SAVEBLOCK1_PTR_ADDR)
  local sb2 = mem.u32(SAVEBLOCK2_PTR_ADDR)
  local partyCount = mem.u8(PARTY_COUNT_ADDR)
  -- In a game once the player's overworld object exists (gObjectEvents[0].active): not
  -- on the title screen or in Oak's intro, but from the bedroom on, Pokemon or not (a
  -- new game has none until Oak's lab).
  local inGame = mem.u8(PLAYER_OBJECT_ADDR) & 1 == 1
  if not (inEwram(sb1) and inEwram(sb2)) or not inGame or partyCount > 6 then
    wasInBattle, lastState = false, "idle"
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

  dexAge = dexAge + 1
  if not dexOut or currentPage == "dex" or dexAge >= 8 then dexOut, dexCaught = readDex(sb2); dexAge = 0 end
  local dex, caught = dexOut, dexCaught
  local mapView = (ui and ui.mapView) == "world" and "world" or "town"
  local place, map = readMap(sb1, currentPage == "map" and mapView == "town", mapView)

  local battling = inBattle()
  if battling then learnRunCommand() end
  local state = battling and menuState() or "idle"
  local battle = { inBattle = battling, noBattle = not battling, bagText = bagTotal .. " ITEMS", best = "" }
  if battling then
    battle.you = readBattleMon(0)
    battle.foe = readBattleMon(1)
    -- the full Pokemon pages (stats, moves, ...) behind the two cards
    local yi, fi = mem.u16(BATTLER_PARTY_INDEXES_ADDR), mem.u16(BATTLER_PARTY_INDEXES_ADDR + 2)
    if yi < 6 then battle.youMon = readMonAt(PARTY_ADDR + yi * POKEMON_SIZE, yi == 0) end
    if fi < 6 then battle.foeMon = readMonAt(ENEMY_PARTY_ADDR + fi * POKEMON_SIZE, false) end
    battle.moves, battle.best = readBattleMoves(0, battle.foe)
    battle.runText = (mem.u32(BATTLE_TYPE_FLAGS_ADDR) & BATTLE_TYPE_TRAINER ~= 0) and "NO" or "OK"
    local act = mem.u8(ACTION_CURSOR_ADDR)
    battle.actFight, battle.actBag, battle.actMon, battle.actRun = act == 0, act == 1, act == 2, act == 3
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

  -- UI changes only on a transition, so the player can still tap away. The battle pages follow the
  -- game's own menus: the battle page when a fight starts and whenever the action menu (FIGHT / BAG /
  -- POKéMON / RUN) comes up, the moves page while the move menu is open; the page the player was on
  -- afterwards.
  local page
  if battling then
    if not wasInBattle then
      page = "battle"
      if currentPage and currentPage ~= "battle" and currentPage ~= "battle-detail" then pageBeforeBattle = currentPage end
    end
    if state ~= lastState then
      if state == "action" then page = "battle" elseif state == "moves" then page = "battle-detail" end
    end
  elseif wasInBattle then
    page = pageBeforeBattle
  end
  if page then out.ui = { navigate = page } end
  wasInBattle, lastState = battling, state
  return out
end
