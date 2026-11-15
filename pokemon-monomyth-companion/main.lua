-- Pokemon Monomyth (MONE) companion pack. The screens are the Pokemon Emerald pack's own (layout and style copied from it);
-- the data comes from Monomyth's memory: a rebuilt Emerald with its own addresses (found with a headless run on the real ROM
-- and the player's save, see NOTES.md). Structures inside the save blocks and the Pokemon are Emerald's, except that a
-- Pokemon's encryption key is derived from its personality and trainer id by a mixing function instead of a plain XOR.
-- Read only: no battle controls, no map picture, no wild table yet (see NOTES.md).

local GAME = "MONE"

-- ---- RAM -------------------------------------------------------------------------------
local SAVEBLOCK1_PTR = 0x03001240      -- the blocks move on every load: always read the pointers
local SAVEBLOCK2_PTR = 0x03001244
local PARTY_ADDR = 0x02025908          -- gPlayerParty
local ENEMY_PARTY_ADDR = 0x02025B60    -- gEnemyParty, right after the player's
local POKEMON_SIZE = 0x64
local MAP_HEADER_ADDR = 0x02038210     -- gMapHeader (+0x14 the region map section, +0x17 map type like Emerald)
local BATTLE_FLAGS_A = 0x02000E2C      -- two copies of gBattleTypeFlags, both 0 outside battle; a trainer battle sets 8
local BATTLE_FLAGS_B = 0x02001278

-- SaveBlock2: name +0, trainer id u16 +0xA, play time +0xE; the encryption key sits at +0x40 (Emerald: +0xAC).
-- SaveBlock1: money u32 at +0x494 XOR the key (Emerald: +0x490).
local MONEY_OFFSET = 0x0494
local ENCRYPTION_KEY_OFFSET = 0x40
local BAG_POCKET_TABLE = 0x0203C18C    -- gBagPockets: 7 x { u32 slot pointer, u32 capacity }, in the game's pocket order
local POCKET_KEYS = { "items", "medicine", "balls", "tmHm", "battle", "berries", "keyItems" }

-- ---- ROM tables (ROM addresses) -----------------------------------------------------------
local SPECIES_NAMES = 0x084E8BBC       -- 11 bytes per species
local MOVE_NAMES = 0x084E9D23          -- 13 bytes per move
local ABILITY_NAMES = 0x084EE603       -- 13 bytes per ability
local ABILITY_DESCS = 0x084EF0C8       -- pointer per ability
local BATTLE_MOVES = 0x084F17E1        -- 16 bytes per move: effect, power, type, accuracy, pp, secondary chance...
local BASE_STATS = 0x084F6DBC          -- 24 bytes per species: 6 stats, 2 types, catch, gender ratio at +9, friendship +11, growth +12, abilities +20/+21
local ITEMS = 0x089F15D2               -- 32 bytes per item: name[14], description pointer at +22, price u16 at +30
local MOVE_DESCS = 0x08AC02FC          -- pointer per move, from move 1
local SECTION_NAMES = 0x08A166B0       -- 8 bytes per region map section: the name pointer sits in the second half of each entry
local SPECIES_COUNT = 405              -- species with a name (sprites exist for all of them)

-- ---- text ------------------------------------------------------------------------------
local PUNCT = { [0xAB] = "!", [0xAC] = "?", [0xAD] = ".", [0xAE] = "-", [0xB4] = "'", [0xB8] = ",",
  [0xBA] = "/", [0x1B] = "é", [0xFE] = " ", [0xFA] = " ", [0xFB] = " ", [0x5B] = "%", [0xF1] = "/", [0xA8] = "&" }
local function decodeChar(c)
  if c == 0x00 then return " " end
  if c >= 0xA1 and c <= 0xAA then return string.char(48 + c - 0xA1) end
  if c >= 0xBB and c <= 0xD4 then return string.char(65 + c - 0xBB) end
  if c >= 0xD5 and c <= 0xEE then return string.char(97 + c - 0xD5) end
  return PUNCT[c] or ""
end
local function readString(addr, maxLen)
  local out = {}
  for i = 0, maxLen - 1 do
    local c = mem.u8(addr + i)
    if c == 0xFF then break end
    if c == 0xFE and out[#out] == "-" then c = 0xFD end
    out[#out + 1] = decodeChar(c)
  end
  return (table.concat(out):gsub("%s+$", ""))
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

local function speciesName(id) return rom(SPECIES_NAMES + id * 11, 10) end
local function moveName(id) return rom(MOVE_NAMES + id * 13, 12) end
local function abilityName(id) return rom(ABILITY_NAMES + id * 13, 12) end
local function moveDesc(id) return id > 0 and romPtr(MOVE_DESCS, id - 1, 120) or "" end

local function itemName(id)
  if id == 0 then return "" end
  local n = rom(ITEMS + 32 * id, 14):gsub("é(%u)", "é %1")
  return (n ~= "") and n or ("ITEM " .. id)
end
local function itemDesc(id) return romPtr(ITEMS + 32 * id + 22, 0, 120) end
local function itemPrice(id) return mem.u16(ITEMS + 32 * id + 30) end

local function sectionName(id)
  local p = mem.u32(SECTION_NAMES + 8 * id)
  if p < 0x08000000 or p >= 0x0A000000 then return "" end
  return rom(p, 24)
end

local function withCommas(n)
  local s = tostring(n)
  while true do
    local k
    s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    if k == 0 then break end
  end
  return s
end

local lo16 = function(v) return v & 0xFFFF end
local hi16 = function(v) return (v >> 16) & 0xFFFF end
local byte = function(v, n) return (v >> (n * 8)) & 0xFF end
local function inEwram(p) return p >= 0x02000000 and p < 0x02040000 end

-- ---- look-ups ------------------------------------------------------------------------------
local TYPES = { [0] = "normal", "fighting", "flying", "poison", "ground", "rock", "bug", "ghost", "steel",
  "unknown", "fire", "water", "grass", "electric", "psychic", "ice", "dragon", "dark" }
local NATURES = { [0] = "Hardy", "Lonely", "Brave", "Adamant", "Naughty", "Bold", "Docile", "Relaxed",
  "Impish", "Lax", "Timid", "Hasty", "Serious", "Jolly", "Naive", "Modest", "Mild", "Quiet", "Bashful",
  "Rash", "Calm", "Gentle", "Sassy", "Careful", "Quirky" }
local NATURE_STATS = { [0] = "ATTACK", "DEFENSE", "SPEED", "SP. ATK", "SP. DEF" }
local CONTEST = { [0] = { "COOL", "#D85040" }, { "BEAUTY", "#5088C0" }, { "CUTE", "#D85868" },
  { "SMART", "#58A868" }, { "TOUGH", "#E8A050" } }
local MAP_KINDS = { [0] = "-", "TOWN", "CITY", "ROUTE", "UNDERGROUND", "UNDERWATER", "OCEAN", "-", "INDOORS", "SECRET BASE" }
local BADGES = { "BADGE 1", "BADGE 2", "BADGE 3", "BADGE 4", "BADGE 5", "BADGE 6", "BADGE 7", "BADGE 8" }

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
-- the multiplier x4 (so neutral = 4, super effective = 8, double super = 16, half = 2, quarter = 1, immune = 0)
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

local function sprite(species, back)
  if species <= 0 then return "" end
  return "asset:pokemon/" .. (back and "back/" or "") .. species .. ".png"
end
local function typeList(t1, t2)
  local out = {}
  for _, t in ipairs(t1 == t2 and { t1 } or { t1, t2 }) do
    local key = TYPES[t] or "unknown"
    out[#out + 1] = { name = key:upper(), src = "asset:types/" .. key .. ".png" }
  end
  return out
end
local function genderOf(personality, ratio)
  if ratio == 0xFF then return false, false end
  if ratio == 0xFE then return false, true end
  if ratio == 0 then return true, false end
  local female = (personality & 0xFF) < ratio
  return not female, female
end

local function statusTag(bits)
  if bits & 0x7 ~= 0 then return "SLP" end
  if bits & 0x8 ~= 0 then return "PSN" end
  if bits & 0x10 ~= 0 then return "BRN" end
  if bits & 0x20 ~= 0 then return "FRZ" end
  if bits & 0x40 ~= 0 then return "PAR" end
  if bits & 0x80 ~= 0 then return "TOX" end
  return ""
end

-- Total EXP to reach level n for each growth rate. Monomyth's growth byte numbers the rates in its own order:
-- the two Pokemon checked (both Medium Slow) carry 2, so 2 and 3 are swapped against Emerald's numbering.
local GROWTH = { [0] = 0, 1, 3, 2, 4, 5 }
local function expAt(rate, n)
  rate = GROWTH[rate] or 0
  if n <= 1 then return 0 end
  local n3 = n * n * n
  if rate == 1 then
    if n <= 50 then return n3 * (100 - n) // 50 end
    if n <= 68 then return n3 * (150 - n) // 100 end
    if n <= 98 then return n3 * ((1911 - 10 * n) // 3) // 500 end
    return n3 * (160 - n) // 100
  elseif rate == 2 then
    if n <= 15 then return n3 * ((n + 1) // 3 + 24) // 50 end
    if n <= 36 then return n3 * (n + 14) // 50 end
    return n3 * (n // 2 + 32) // 50
  elseif rate == 3 then
    return math.max(0, 6 * n3 // 5 - 15 * n * n + 100 * n - 140)
  elseif rate == 4 then
    return 4 * n3 // 5
  elseif rate == 5 then
    return 5 * n3 // 4
  end
  return n3
end

local function bands(hp, maxHp)
  local pct = maxHp > 0 and hp / maxHp or 0
  return pct, pct > 0.5, pct <= 0.5 and pct > 0.2, pct <= 0.2
end

-- ---- Pokemon substructs ----------------------------------------------------------------------
-- The 48 secure bytes hold four 12-byte substructs in one of 24 orders (personality % 24), XOR-ed with a key that
-- Monomyth derives from personality and trainer id (the function at ROM 0x08056C8E).
local MASK = 0xFFFFFFFF
local function ror(x, n) n = n % 32; return ((x >> n) | (x << (32 - n))) & MASK end
local function monKey(p, o)
  local r5 = (o + ror(0x690 ~ p, 7)) & MASK
  r5 = (r5 + ror(p, 11)) & MASK
  local r0 = 0x5A000000 ~ o
  r5 = ror(r5, 13)
  r0 = ror(r0 ~ r5, 17)
  r5 = (p + r0) & MASK
  return r5 ~ ror(o, 5)
end
local ORDERS = {
  [0] = "GAEM", "GAME", "GEAM", "GEMA", "GMAE", "GMEA", "AGEM", "AGME", "AEGM", "AEMG", "AMGE", "AMEG",
  "EGAM", "EGMA", "EAGM", "EAMG", "EMGA", "EMAG", "MGAE", "MGEA", "MAGE", "MAEG", "MEGA", "MEAG",
}
local function substructs(base)
  local personality, otId = mem.u32(base), mem.u32(base + 0x04)
  local key = monKey(personality, otId)
  local order = ORDERS[personality % 24]
  local out = {}
  for slot = 0, 3 do
    local words = {}
    for w = 0, 2 do words[w] = mem.u32(base + 0x20 + slot * 12 + w * 4) ~ key end
    out[order:sub(slot + 1, slot + 1)] = words
  end
  return out, personality, otId
end

local function ribbonCount(bits)
  local n = 0
  for i = 0, 4 do if (bits >> (i * 3)) & 7 ~= 0 then n = n + 1 end end
  for i = 15, 26 do if (bits >> i) & 1 == 1 then n = n + 1 end end
  return n
end

local EMPTY_MOVE = { name = "-", type = "", power = "--", acc = "--", pp = "--", ppPct = 0, ppLow = false,
  has = false, desc = "", contest = "", contestColor = "#FFFFFF", cdesc = "", info = "" }

local function readMonAt(base, isLead)
  local personality, otId = mem.u32(base), mem.u32(base + 4)
  local level, hp, maxHp = mem.u8(base + 0x54), mem.u16(base + 0x56), mem.u16(base + 0x58)
  if personality == 0 or level < 1 or level > 100 or maxHp == 0 or maxHp > 999 or hp > maxHp then return nil end
  local sub = substructs(base)
  local speciesId = lo16(sub.G[0])
  if speciesId == 0 or speciesId > SPECIES_COUNT then return nil end
  local stats = BASE_STATS + speciesId * 24
  local t1, t2 = mem.u8(stats + 6), mem.u8(stats + 7)
  local male, female = genderOf(personality, mem.u8(stats + 9))

  local heldItem = hi16(sub.G[0])
  local exp = sub.G[1]
  local ppBonuses = byte(sub.G[2], 0)
  local friendship = byte(sub.G[2], 1)
  local rate = mem.u8(stats + 12)
  local floor, ceil = expAt(rate, level), expAt(rate, math.min(100, level + 1))
  local expPct = level >= 100 and 1 or math.max(0, math.min(1, (exp - floor) / math.max(1, ceil - floor)))

  -- Ability: the species' first or second, by bit 31 of the Misc IV word.
  local ability = mem.u8(stats + 20 + ((sub.M[1] >> 31) & 1))
  if ability == 0 then ability = mem.u8(stats + 20) end

  local metLocation = byte(sub.M[0], 1)
  local metLevel = (sub.M[0] >> 16) & 0x7F
  local metPlace = sectionName(metLocation)
  if metPlace == "" then metPlace = "A DISTANT PLACE" end
  local ribbons = ribbonCount(sub.M[2])

  local ev = { byte(sub.E[0], 0), byte(sub.E[0], 1), byte(sub.E[0], 2), byte(sub.E[1], 0), byte(sub.E[1], 1), byte(sub.E[0], 3) }
  local cond = { byte(sub.E[1], 2), byte(sub.E[1], 3), byte(sub.E[2], 0), byte(sub.E[2], 1), byte(sub.E[2], 2) }
  local sheen = byte(sub.E[2], 3)

  local nature = personality % 25
  local up, down = NATURE_STATS[nature // 5], NATURE_STATS[nature % 5]
  if up == down then up, down = nil, nil end
  local raw = {
    { "HP", maxHp }, { "ATTACK", mem.u16(base + 0x5A) }, { "DEFENSE", mem.u16(base + 0x5C) },
    { "SP. ATK", mem.u16(base + 0x60) }, { "SP. DEF", mem.u16(base + 0x62) }, { "SPEED", mem.u16(base + 0x5E) },
  }
  local top = 60
  for _, s in ipairs(raw) do top = math.max(top, s[2]) end
  local statRows = {}
  for i, s in ipairs(raw) do
    statRows[#statRows + 1] = {
      label = s[1], value = tostring(s[2]), pct = s[2] / (top * 1.1), ev = "EV " .. ev[i],
      up = s[1] == up, down = s[1] == down,
    }
  end
  local condition = {}
  for i = 0, 4 do
    condition[#condition + 1] = { label = CONTEST[i][1], pct = cond[i + 1] / 255, value = tostring(cond[i + 1]), color = CONTEST[i][2] }
  end

  local moves = {}
  for m = 0, 3 do
    local pair = m < 2 and sub.A[0] or sub.A[1]
    local id = (m % 2 == 0) and lo16(pair) or hi16(pair)
    if id ~= 0 then
      local data = BATTLE_MOVES + id * 16
      local power, acc = mem.u8(data + 1), mem.u8(data + 3)
      local ppMax = mem.u8(data + 4)
      ppMax = ppMax + ppMax * ((ppBonuses >> (m * 2)) & 3) // 5
      local ppNow = byte(sub.A[2], m)
      moves[#moves + 1] = {
        name = moveName(id), id = id, mtype = mem.u8(data + 2),
        type = "asset:types/" .. (TYPES[mem.u8(data + 2)] or "normal") .. ".png",
        power = power > 0 and tostring(power) or "--", acc = acc > 0 and tostring(acc) or "--", rawPower = power, rawAcc = acc,
        pp = ppNow .. "/" .. ppMax, ppNow = ppNow, ppPct = ppMax > 0 and ppNow / ppMax or 0, ppLow = ppMax > 0 and ppNow / ppMax <= 0.25,
        has = true, desc = moveDesc(id), contest = "-", contestColor = "#FFFFFF", cdesc = "",
      }
    end
  end
  local firstDesc = moves[1] and moves[1].desc or ""
  while #moves < 4 do moves[#moves + 1] = EMPTY_MOVE end

  local tag = statusTag(mem.u32(base + 0x50))
  local pct, high, mid, low = bands(hp, maxHp)
  local nick, species = readString(base + 0x08, 10), speciesName(speciesId)
  return {
    name = (nick ~= "") and nick or species, species = species, speciesId = speciesId,
    dex = string.format("%03d", speciesId), sprite = sprite(speciesId),
    level = level, hp = hp, maxHp = maxHp, lead = isLead,
    hpPct = pct, hpHigh = high, hpMid = mid, hpLow = low, fainted = hp == 0,
    male = male, female = female, types = typeList(t1, t2), t1 = t1, t2 = t2,
    status = tag, hasStatus = tag ~= "",
    ot = readString(base + 0x14, 7), id = string.format("%05d", otId & 0xFFFF),
    ability = abilityName(ability), abilityText = romPtr(ABILITY_DESCS, ability, 80),
    nature = NATURES[nature]:upper(), metLevel = metLevel, metPlace = metPlace,
    item = heldItem ~= 0 and itemName(heldItem) or "NONE", hasHeld = false, heldIcon = "",
    ribbon = ribbons == 0 and "NONE" or (ribbons .. (ribbons == 1 and " RIBBON" or " RIBBONS")),
    friendship = tostring(friendship), friendPct = friendship / 255,
    statRows = statRows, exp = tostring(exp),
    toNext = tostring(level >= 100 and 0 or math.max(0, ceil - exp)), expPct = expPct,
    condition = condition, sheen = tostring(sheen), sheenPct = sheen / 255,
    moves = moves, moveDesc = firstDesc, contestDesc = "",
    atk = raw[2][2], def = raw[3][2], spa = raw[4][2], spd = raw[5][2], spe = raw[6][2],
  }
end

local function readParty()
  local out = {}
  for i = 0, 5 do
    local m = readMonAt(PARTY_ADDR + POKEMON_SIZE * i, i == 0)
    if m then out[#out + 1] = m end
  end
  return out
end
local function readEnemy()
  local out = {}
  for i = 0, 5 do
    local m = readMonAt(ENEMY_PARTY_ADDR + POKEMON_SIZE * i, false)
    if m then out[#out + 1] = m end
  end
  return out
end

local function teamSummary(party)
  local hp, maxHp, levels = 0, 0, 0
  for _, m in ipairs(party) do hp, maxHp, levels = hp + m.hp, maxHp + m.maxHp, levels + m.level end
  local pct, high, mid, low = bands(hp, maxHp)
  return { hp = tostring(hp), maxHp = tostring(maxHp), hpPct = pct, hpHigh = high, hpMid = mid, hpLow = low,
    avg = tostring(#party > 0 and levels // #party or 0) }
end

-- ---- Bag ---------------------------------------------------------------------------------------
local function readPocket(entry, key, showCount)
  local ptr, cap = mem.u32(entry), mem.u32(entry + 4)
  local list, total = {}, 0
  if not inEwram(ptr) or cap == 0 or cap > 200 then return list, total end
  for i = 0, cap - 1 do
    local id = mem.u16(ptr + 4 * i)
    local qty = mem.u16(ptr + 4 * i + 2) ~ (key & 0xFFFF)
    if id ~= 0 and id < 1000 and qty > 0 and qty < 1000 then
      list[#list + 1] = {
        name = itemName(id), count = showCount and ("x" .. qty) or "", icon = "", hasIcon = false,
        desc = itemDesc(id), price = tostring(itemPrice(id)),
      }
      total = total + qty
    end
  end
  return list, total
end

local function readBag(key)
  local bag, used, bagTotal, ballCount, capacity = {}, 0, 0, 0, 0
  for i, k in ipairs(POCKET_KEYS) do
    local entry = BAG_POCKET_TABLE + 8 * (i - 1)
    local list, total = readPocket(entry, key, k ~= "keyItems")
    bag[k] = list
    used = used + #list
    capacity = capacity + math.min(200, mem.u32(entry + 4))
    if k == "balls" then ballCount = total end
    if k ~= "keyItems" then bagTotal = bagTotal + total end
  end
  bag.total, bag.used, bag.capacity = tostring(bagTotal), tostring(used), tostring(capacity)
  bag.hasAny, bag.isEmpty = used > 0, used == 0
  return bag, bagTotal, ballCount
end

-- ---- Area map ---------------------------------------------------------------------------------------
-- The map of the area you're in, drawn from the game's own data like the wide view does: the map the game keeps in
-- RAM (gBackupMapLayout), its metatile tables from the ROM layout, and the tile graphics and palettes from VRAM.
-- It's only drawn while the overworld is on screen (a menu or battle has other graphics in VRAM) and only while the
-- map page is open; a picture drawn earlier stays until the area changes. Same structures as Emerald's.
-- SaveBlock1: pos (x, y as s16, the player's tile) at +4, location (map group, map number) at +8 (Emerald: +0 and +4).
local POS_OFFSET, LOCATION_OFFSET = 0x04, 0x08
local BACKUP_LAYOUT_ADDR = 0x0203823C     -- gBackupMapLayout { s32 width; s32 height; u16 *map }
local MAP_OFFSET = 7                      -- the border around a map in the game's grid
local MAPGRID_UNDEFINED = 0x3FF
local NUM_METATILES_IN_PRIMARY = 512
local MAP_VIEW_ASPECT = 1.93              -- the card's shape: the picture is cut to it, so it fills the card like CSS `cover`
local MAP_VIEW_MIN_W, MAP_VIEW_MAX_W = 208, 240 -- world px the card shows across: a small map is zoomed in, a big one scrolls (three layers cost more than Emerald's two)
local MAP_VIEW_FLOOR_W = 160              -- never shrink the view below this
-- A script call may run 25 ms, and drawing the picture counts: if a call is cut off the view shrinks a step.
local MAP_SHRINK_STEP = 48
local MAP_SETTLE_TICKS = 3                -- between the draws of a new area (its tiles load a little late)
local MAP_REDRAW_TICKS = 4               -- the picture follows the player at most this often (a draw is most of an update's time budget)
local MAP_SETTLE_MAX = 4                  -- draws before a new area is shown whatever it looks like (animated tiles never match)
local areaShot = { sig = nil, shown = nil, pending = nil, maxW = MAP_VIEW_MAX_W, cool = 0 }

local function overworldOnScreen()
  local dispcnt = mem.u16(0x04000000)
  if dispcnt & 7 ~= 0 or dispcnt & 0x0600 ~= 0x0600 then return false end   -- mode 0, BG1 and BG2 on
  return (mem.u16(0x0400000A) >> 2) & 3 == 0 and (mem.u16(0x0400000C) >> 2) & 3 == 0   -- both read tiles from char block 0
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function areaPicture(draw, sb1)
  local layout = mem.u32(MAP_HEADER_ADDR)
  if layout < 0x08000000 or layout >= 0x0A000000 then return nil end
  local w, h = mem.u32(layout), mem.u32(layout + 4)
  local gridW, gridH, grid = mem.u32(BACKUP_LAYOUT_ADDR), mem.u32(BACKUP_LAYOUT_ADDR + 4), mem.u32(BACKUP_LAYOUT_ADDR + 8)
  local primary, secondary = mem.u32(layout + 0x10), mem.u32(layout + 0x14)
  if w < 1 or h < 1 or w > 256 or h > 256 or gridW < w or gridH < h or gridW > 1024 or gridH > 1024 then return nil end
  if grid < 0x02000000 or grid >= 0x02040000 or primary < 0x08000000 or secondary < 0x08000000 then return nil end

  local mapW, mapH = w * 16, h * 16
  local viewW = math.max(MAP_VIEW_FLOOR_W, math.min(clamp(mapW, MAP_VIEW_MIN_W, MAP_VIEW_MAX_W), areaShot.maxW))
  local viewH = math.floor(viewW / MAP_VIEW_ASPECT + 0.5)
  -- the player, in map pixels (the tile's middle)
  local px = mem.u16(sb1 + POS_OFFSET) * 16 + 8
  local py = mem.u16(sb1 + POS_OFFSET + 2) * 16 + 8
  local function camera(p, view, size)
    if size <= view then return (size - view) // 2 end
    return clamp((p - view // 2) // 16 * 16, 0, size - view)
  end
  local cx, cy = camera(px, viewW, mapW), camera(py, viewH, mapH)

  local sig = layout .. ":" .. grid .. ":" .. w .. "x" .. h
  local camSig = sig .. ":" .. viewW .. ":" .. cx .. ":" .. cy
  if sig ~= areaShot.sig then
    areaShot.sig, areaShot.pending = sig, { draws = 0, wait = MAP_SETTLE_TICKS, last = nil }
  end

  local function render()
    local ok, key = pcall(gfx.layers, {
      x = MAP_OFFSET * 16 + cx, y = MAP_OFFSET * 16 + cy, width = viewW, height = viewH, scale = 1,
      grid = grid, gridW = gridW, gridH = gridH, idMask = 0x3FF,
      border = mem.u32(layout + 8), borderW = 2, borderH = 2,
      borderShift = MAP_OFFSET, undefinedId = MAPGRID_UNDEFINED,
      metatiles = mem.u32(primary + 0x0C), metatiles2 = mem.u32(secondary + 0x0C), split = NUM_METATILES_IN_PRIMARY,
      metatileLayers = 3,                   -- Monomyth's metatiles are 24 bytes: bottom, middle and top layer (needs an app with metatileLayers)
      tiles = 0x06000000, palette = 0x05000000,
    })
    if ok then return key end
    if tostring(key):find("time limit") then areaShot.maxW = math.max(MAP_VIEW_FLOOR_W, viewW - MAP_SHRINK_STEP) end
    return nil
  end
  local function show(key)
    areaShot.shown = { image = key, sig = sig, camSig = camSig, cx = cx, cy = cy, viewW = viewW, viewH = viewH,
      ratio = string.format("%.4f", viewW / viewH) }
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
      areaShot.cool = areaShot.cool - 1
      if not areaShot.shown or areaShot.cool <= 0 then
        areaShot.cool = MAP_REDRAW_TICKS
        local key = render()
        if key then show(key) end
      end
    end
  end

  local shown = areaShot.shown
  if not shown then return nil end
  local fx, fy = (px - shown.cx) / shown.viewW, (py - shown.cy) / shown.viewH
  local hasMe = shown.sig == sig and fx >= 0 and fx <= 1 and fy >= 0 and fy <= 1
  return { image = shown.image, ratio = shown.ratio, hasMe = hasMe,
    mx = string.format("%.2f%%", clamp(fx, 0, 1) * 100), my = string.format("%.2f%%", clamp(fy, 0, 1) * 100) }
end

-- ---- Wild Pokemon ----------------------------------------------------------------------------------------
-- gWildMonHeaders (ROM 0x089C2E58): 20 bytes per map { mapGroup, mapNum, pad[2], land, water, rockSmash, fishing } (pointers to
-- { rate, pad, mons }), ended by mapGroup 0xFF. Each mon is { minLevel, maxLevel, species u16 }. The slot chances are
-- the game's encounter rates; fishing's 10 slots are three rods. Same format as Emerald's.
local WILD_HEADERS_ADDR = 0x089C2E58
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
    for i = 0, 300 do
      local e = WILD_HEADERS_ADDR + i * 20
      local g = mem.u8(e)
      if g == 0xFF then break end
      if g == group and mem.u8(e + 1) == num then wildHeaderCache[id] = e break end
    end
  end
  return wildHeaderCache[id] or nil
end

actions = actions or {}
local wildChoice -- the method key the player picked (actions.nextWild)
local wildAvailable = {}

--- The method tag: show the map's next encounter method.
function actions.nextWild()
  if #wildAvailable < 2 then return end
  local at = 1
  for i, a in ipairs(wildAvailable) do if a.m.key == wildChoice then at = i end end
  wildChoice = wildAvailable[at % #wildAvailable + 1].m.key
end

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
    if species > 0 and species <= SPECIES_COUNT then
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
  end
  table.sort(order, function(a, b) return a.chance > b.chance end)
  local list = {}
  for _, e in ipairs(order) do
    list[#list + 1] = {
      sprite = sprite(e.species), name = speciesName(e.species),
      level = e.min == e.max and ("Lv" .. e.min) or ("Lv" .. e.min .. "-" .. e.max),
      chance = e.chance .. "%",
    }
  end
  return { method = pick.m.label, mons = list }
end

-- The WORLD view is assets/ui/hoenn.png (art/world-map.py): one square per cell of a 28 x 15 grid. A map section is a
-- rectangle of those cells (entries at SECTION_NAMES: name pointer, then x, y, w, h); the player's spot inside it follows
-- how far across the current map they are.
local WORLD_COLS, WORLD_ROWS = 28, 15
local OUTDOORS = { [1] = true, [2] = true, [3] = true, [6] = true }

local function readMap(sb1, draw, mode, withWild)
  local mapsec = mem.u8(MAP_HEADER_ADDR + 0x14)
  local name = sectionName(mapsec)
  if name == "" then name = "MONOMYTH" end
  local mapType = mem.u8(MAP_HEADER_ADDR + 0x17)
  local showTown = mode ~= "world"
  local wild = withWild and readWild(sb1) or nil
  local out = { route = name, kind = MAP_KINDS[mapType] or "-",
    px = tostring(mem.u16(sb1 + POS_OFFSET)), py = tostring(mem.u16(sb1 + POS_OFFSET + 2)),
    showTown = showTown, showWorld = not showTown,
    live = false, off = showTown, hasMe = false, image = "", ratio = "1.0000", mx = "50%", my = "50%",
    hasWorldMe = false, wx = "50%", wy = "50%",
    wild = wild and wild.mons or {}, wildMethod = wild and wild.method or "", hasWild = wild ~= nil, noWild = wild == nil }
  if showTown then
    local pic = areaPicture(draw and overworldOnScreen(), sb1)
    if pic then
      out.live, out.off = true, false
      out.image, out.ratio, out.mx, out.my, out.hasMe = pic.image, pic.ratio, pic.mx, pic.my, pic.hasMe
    end
  else
    local entry = SECTION_NAMES + 8 * mapsec
    local layout = mem.u32(MAP_HEADER_ADDR)
    local mw, mh = 0, 0
    if layout >= 0x02000000 and layout < 0x0A000000 then mw, mh = mem.u32(layout), mem.u32(layout + 4) end
    local function across(v, size)
      if size <= 0 or size > 1000 then return 0.5 end
      return clamp((v + 0.5) / size, 0, 1)
    end
    local ex, ey, ew, eh = mem.u8(entry + 4), mem.u8(entry + 5), math.max(1, mem.u8(entry + 6)), math.max(1, mem.u8(entry + 7))
    local outdoors = OUTDOORS[mapType]
    local fx = outdoors and across(mem.u16(sb1 + POS_OFFSET), mw) or 0.5
    local fy = outdoors and across(mem.u16(sb1 + POS_OFFSET + 2), mh) or 0.5
    out.hasWorldMe = ew > 0 and (ex + ey) > 0 and ex < WORLD_COLS and ey < WORLD_ROWS and mem.u8(entry + 6) > 0
    out.wx = string.format("%.2f%%", (ex + ew * fx) / WORLD_COLS * 100)
    out.wy = string.format("%.2f%%", (ey + eh * fy) / WORLD_ROWS * 100)
  end
  return out
end

-- ---- Pokedex: a species book (Monomyth's own seen/caught flags are not decoded) -------------------------
-- Every species is listed with its sprite, types, abilities and base stats.
local DEX_TOTAL, DEX_PAGE = SPECIES_COUNT, 24
local dexState = { start = 1, sel = 1 }
actions = actions or {}
function actions.dexPage(delta)
  local pages = (DEX_TOTAL + DEX_PAGE - 1) // DEX_PAGE
  local page = ((dexState.start - 1) // DEX_PAGE + (tonumber(delta) or 0)) % pages
  dexState.start = page * DEX_PAGE + 1
  dexState.sel = dexState.start
end
function actions.dexSelect(n)
  n = tonumber(n)
  if n and n >= 1 and n <= DEX_TOTAL then dexState.sel = n end
end
function actions.setAction() end   -- no battle controls in this pack
function actions.setMove() end

local function normQuery(q)
  q = tostring(q or ""):lower()
  q = q:gsub("^%s+", "")
  q = q:gsub("%s+$", "")
  return q
end

local STAT_LABELS = { "HP", "ATTACK", "DEFENSE", "SP. ATK", "SP. DEF", "SPEED" }
local STAT_ORDER = { 0, 1, 2, 4, 5, 3 } -- base stat bytes are hp, atk, def, spe, spa, spd
local function readDex(ui)
  local entries = {}
  local first = dexState.start
  local last = math.min(DEX_TOTAL, first + DEX_PAGE - 1)
  for n = first, last do
    entries[#entries + 1] = { num = n, no = string.format("%03d", n), name = speciesName(n), sprite = sprite(n),
      seen = true, unseen = false, own = true, sel = n == dexState.sel }
  end
  local query = normQuery(ui and ui.dexQuery)
  local searching = query ~= ""
  local found = 0
  if searching then
    entries = {}
    local firstMatch, selIsMatch = nil, false
    for n = 1, DEX_TOTAL do
      local nm = speciesName(n)
      local hit = (nm:lower():find(query, 1, true) ~= nil) or (query:match("^%d+$") ~= nil and tostring(n):sub(1, #query) == query)
      if hit and found < 40 then
        found = found + 1
        firstMatch = firstMatch or n
        if n == dexState.sel then selIsMatch = true end
        entries[#entries + 1] = { num = n, no = string.format("%03d", n), name = nm, sprite = sprite(n),
          seen = true, unseen = false, own = true, sel = false }
      end
    end
    if firstMatch and not selIsMatch then dexState.sel = firstMatch end
    for _, e in ipairs(entries) do e.sel = e.num == dexState.sel end
  end
  local n = dexState.sel
  local base = BASE_STATS + n * 24
  local sel = { no = string.format("%03d", n), seen = true, unseen = false, own = true,
    name = speciesName(n), sprite = sprite(n), state = "LISTED",
    category = "", height = "--", weight = "--", abilities = "--", types = typeList(mem.u8(base + 6), mem.u8(base + 7)), stats = {},
    desc = "" }
  for i, idx in ipairs(STAT_ORDER) do
    local v = mem.u8(base + idx)
    sel.stats[i] = { label = STAT_LABELS[i], value = tostring(v), pct = math.min(1, v / 150) }
  end
  local a1, a2 = mem.u8(base + 20), mem.u8(base + 21)
  sel.abilities = (a2 == 0 or a2 == a1) and abilityName(a1) or (abilityName(a1) .. " / " .. abilityName(a2))
  sel.desc = romPtr(ABILITY_DESCS, a1, 100)
  local pages = (DEX_TOTAL + DEX_PAGE - 1) // DEX_PAGE
  return { entries = entries, sel = sel, range = string.format("%03d-%03d", first, last),
    page = ((first - 1) // DEX_PAGE + 1) .. "/" .. pages,
    searching = searching, notSearching = not searching, noMatch = searching and found == 0,
    found = found .. (found == 1 and " MATCH" or " MATCHES") }
end

-- ---- Battle: gBattleMons, 0x38 bytes per battler -----------------------------------------------------
-- +0 species u16, +2 ability, +3/+4 types, +6 level, +0xC moves[4] u16, +0x16 atk def spe spa spd (u16), +0x20 hp, +0x22 max hp,
-- +0x30 stat stages[8] (6 = neutral). The structure is cleared once the battle is over; it is the same for wild and trainer fights.
local BATTLE_MONS = 0x0200013C
local BATTLE_MON_SIZE = 0x38
local CONTROLLER_FUNCS = 0x020258EC    -- gBattlerControllerFuncs[battler]; battler 0 is the player
local FUNC_CHOOSE_ACTION, FUNC_CHOOSE_MOVE = 0x08048549, 0x08048E69
local ACTION_CURSOR_ADDR = 0x02025820  -- gActionSelectionCursor[0]: 0 FIGHT, 1 BAG, 2 POKEMON, 3 RUN
local MOVE_CURSOR_ADDR = 0x02025824    -- gMoveSelectionCursor[0]

-- name, index in the stat stages
local BATTLE_STATS = { { "ATTACK", 1 }, { "DEFENSE", 2 }, { "SP. ATK", 4 }, { "SP. DEF", 5 }, { "SPEED", 3 } }

-- the battler's slot in the given party, found by species and level (a live battle mon is a copy of it)
local function partySlot(list, species, level)
  for i, m in ipairs(list) do
    if m.speciesId == species and m.level == level then return i, m end
  end
end

local function liveBattler(battler)
  local base = BATTLE_MONS + battler * BATTLE_MON_SIZE
  local species, level = mem.u16(base), mem.u8(base + 6)
  local hp, maxHp = mem.u16(base + 0x20), mem.u16(base + 0x22)
  if species < 1 or species > SPECIES_COUNT or level < 1 or level > 100 or maxHp < 1 or maxHp > 999 or hp > maxHp then return nil end
  return base, species, level, hp, maxHp
end

local function battleCard(base, mon, back)
  local species, level = mem.u16(base), mem.u8(base + 6)
  local hp, maxHp = mem.u16(base + 0x20), mem.u16(base + 0x22)
  local pct, high, mid, low = bands(hp, maxHp)
  local t1, t2 = mem.u8(base + 3), mem.u8(base + 4)
  local stats = {}
  for _, st in ipairs(BATTLE_STATS) do
    local stage = mem.u8(base + 0x30 + st[2]) - 6
    if stage ~= 0 and stage >= -6 and stage <= 6 then   -- only what changed; an empty list reads "STATS UNCHANGED"
      stats[#stats + 1] = { name = st[1], stage = stage > 0 and ("+" .. stage) or tostring(stage), up = stage > 0, down = stage < 0 }
    end
  end
  return { name = mon.name, level = level, hp = hp, maxHp = maxHp, hpPct = pct, hpHigh = high, hpMid = mid, hpLow = low,
    fainted = hp == 0, sprite = sprite(species, back), types = typeList(t1, t2), t1 = t1, t2 = t2,
    male = mon.male, female = mon.female, status = mon.status, hasStatus = mon.hasStatus, stats = stats }
end

-- your four moves as the battle sees them (PP from the party copy), judged against the foe's types
local function battleMoves(base, you, foe)
  local out, best, bestScore, bestMove, bestShort = {}, nil, 0, nil, nil
  local cursor = mem.u8(MOVE_CURSOR_ADDR)
  for m = 0, 3 do
    local id = mem.u16(base + 0x0C + m * 2)
    if id ~= 0 then
      local data = BATTLE_MOVES + id * 16
      local power, acc, mtype = mem.u8(data + 1), mem.u8(data + 3), mem.u8(data + 2)
      local eff = effectiveness(mtype, foe.t1, foe.t2)  -- 4 = neutral
      local label = power == 0 and "--" or (eff == 0 and "x0" or (eff == 4 and "x1" or (eff > 4 and ("x" .. (eff // 4)) or (eff == 2 and "x1/2" or "x1/4"))))
      local score = power * eff
      if score > bestScore then bestScore, best, bestMove, bestShort = score, moveName(id) .. " " .. label, m, moveName(id) end
      local pp = "--"
      for _, pm in ipairs(you.moves) do if pm.id == id then pp = tostring(pm.ppNow) end end
      out[#out + 1] = { name = moveName(id), pp = pp, type = "asset:types/" .. (TYPES[mtype] or "normal") .. ".png", has = true,
        info = "PWR " .. (power > 0 and power or "--") .. "  ACC " .. (acc > 0 and acc or "--"), eff = label,
        se = power > 0 and eff > 4, nve = power > 0 and eff < 4 and eff > 0, imm = power > 0 and eff == 0, sel = m == cursor }
    else
      out[#out + 1] = { name = "-", pp = "--", type = "", has = false, info = "", eff = "", se = false, nve = false, imm = false, sel = false }
    end
  end
  for i, mv in ipairs(out) do mv.best = mv.has and bestMove == i - 1 end
  return out, best and ("BEST: " .. best) or "PICK A MOVE", bestShort and ("BEST: " .. bestShort) or "PICK A MOVE"
end

-- Which menu the player's controller is on: the action menu (FIGHT / BAG / POKEMON / RUN), the move menu, or neither.
local function menuState()
  local f = mem.u32(CONTROLLER_FUNCS)
  if f == FUNC_CHOOSE_ACTION then return "action" end
  if f == FUNC_CHOOSE_MOVE then return "moves" end
  return "idle"
end

local slow, slowAge = nil, 0         -- the bag, re-read every 8 updates or when a page shows it
local dexOut, lastDexQuery = nil, nil
local wasInBattle, wasReady, lastState = false, false, "idle"
local pageBeforeBattle = "party"

local function navBase(ui)
  local currentPage = ui and ui.page
  if mem.read(0x080000AC, 4) ~= GAME then
    wasInBattle, wasReady, lastState = false, false, "idle"
    return { ready = false, waiting = true }
  end
  local sb1, sb2 = mem.u32(SAVEBLOCK1_PTR), mem.u32(SAVEBLOCK2_PTR)
  if not (inEwram(sb1) and inEwram(sb2)) then
    wasInBattle, wasReady, lastState = false, false, "idle"
    return { ready = false, waiting = true }
  end
  local first = mem.u8(sb2)   -- the player name is empty until a save is loaded
  local layout = mem.u32(MAP_HEADER_ADDR)   -- the map exists only once the game has started (title screen: no)
  if first == 0 or first == 0xFF or layout < 0x08000000 or layout >= 0x0A000000 then
    wasInBattle, wasReady, lastState = false, false, "idle"
    return { ready = false, waiting = true }
  end

  local key = mem.u32(sb2 + ENCRYPTION_KEY_OFFSET)
  local money = withCommas(mem.u32(sb1 + MONEY_OFFSET) ~ key)
  local time = string.format("%d:%02d", mem.u16(sb2 + 0xE), mem.u8(sb2 + 0x10))
  local party = readParty()
  slowAge = slowAge + 1
  if not slow or slowAge >= 8 or currentPage == "bag" or currentPage == "options" or currentPage == "battle" then
    local b, t, c = readBag(key)
    slow, slowAge = { bag = b, total = t, balls = c }, 0
  end
  local bag, bagTotal, ballCount = slow.bag, slow.total, slow.balls
  local badges = {}
  for i = 1, 8 do badges[i] = { src = "asset:ui/badge" .. i .. ".png", name = BADGES[i], earned = false, locked = true } end

  -- A fight is on when both live battlers are valid and match a Pokemon of the two parties (the structure is cleared afterwards).
  local battling, yBase, fBase, youMon, foeMon = false, nil, nil, nil, nil
  local yb, ysp, ylv = liveBattler(0)
  local fb, fsp, flv = liveBattler(1)
  if yb and fb then
    local foes = readEnemy()
    local _, ym = partySlot(party, ysp, ylv)
    local _, fm = partySlot(foes, fsp, flv)
    if ym and fm then battling, yBase, fBase, youMon, foeMon = true, yb, fb, ym, fm end
  end
  local state = battling and menuState() or "idle"

  local battle = { inBattle = battling, noBattle = not battling, balls = tostring(ballCount), bagText = bagTotal .. " ITEMS", best = "",
    actFight = false, actBag = false, actMon = false, actRun = false, runText = "OK" }
  if battling then
    battle.you, battle.foe = battleCard(yBase, youMon, true), battleCard(fBase, foeMon, false)
    battle.youMon, battle.foeMon = youMon, foeMon
    battle.moves, battle.best, battle.bestName = battleMoves(yBase, youMon, foeMon)
    -- both copies of gBattleTypeFlags read 8 in a trainer battle (wild battles carry no flag)
    local fa, fb2 = mem.u32(BATTLE_FLAGS_A), mem.u32(BATTLE_FLAGS_B)
    battle.runText = (fa == fb2 and fa & 8 ~= 0) and "NO" or "OK"
    local act = mem.u8(ACTION_CURSOR_ADDR)
    battle.actFight, battle.actBag, battle.actMon, battle.actRun = act == 0, act == 1, act == 2, act == 3
  end

  local mapView = (ui and ui.mapView) == "world" and "world" or "town"
  local dexQuery = normQuery(ui and ui.dexQuery)
  if currentPage == "dex" or not dexOut or dexQuery ~= lastDexQuery then
    dexOut = readDex(ui)
    lastDexQuery = dexQuery
  end
  local out = {
    ready = true, waiting = false, time = time, money = money,
    dexSeen = "--", dexCaught = "--", dexSeenPct = 0, dexCaughtPct = 0,
    badgeCount = "0", badges = badges,
    trainer = { name = readString(sb2, 7), id = string.format("%05d", mem.u16(sb2 + 0xA)) },
    map = readMap(sb1, currentPage == "map" and mapView == "town" and not battling, mapView, currentPage == "map"),
    partyCount = tostring(#party), party = party, team = teamSummary(party),
    bag = bag, dex = dexOut, battle = battle,
  }

  -- the battle page when a fight starts and whenever the action menu comes up, the moves page while the move menu is open,
  -- the page before the fight afterwards
  local uiOut = {}
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
  if page then uiOut.navigate = page end
  if not wasReady then
    local f = bag.items[1] or bag.medicine[1] or { name = "", desc = "", icon = "", hasIcon = false, count = "", price = "" }
    uiOut.set = { selName = f.name, selDesc = f.desc, selIcon = f.icon, selHasIcon = f.hasIcon, selQty = f.count, selPrice = f.price }
  end
  if next(uiOut) then out.ui = uiOut end
  wasInBattle, wasReady, lastState = battling, true, state
  return out
end

-- >>> nav placement
-- where the page buttons sit: bottom (the ring bar), left, right or split (side docks). The settings row BUTTONS cycles it.
local NAV = { { "map", "MAP" }, { "party", "POKéMON" }, { "dex", "POKéDEX" }, { "options", "OPTIONS" }, { "bag", "BAG" } }
local NAV_ALIAS = { detail = "party", ["battle-detail"] = "battle" }
local NAV_MODES = { "bottom", "left", "right", "split" }
local navMode = 1
actions = actions or {}
function actions.cycleNav() navMode = navMode % #NAV_MODES + 1 end
local function navState(ui)
  local pos = NAV_MODES[navMode]
  local cur = ui.page or NAV[1][1]
  cur = NAV_ALIAS[cur] or cur
  local out = { posBottom = (pos == "bottom"), posSplit = (pos == "split"), navLabel = string.upper(pos) }
  local half = (#NAV + 1) // 2
  local left, right = 0, 0
  for i, n in ipairs(NAV) do
    out["on" .. i] = (n[1] == cur)
    local l = (pos == "left") or (pos == "split" and i <= half)
    local r = (pos == "right") or (pos == "split" and i > half)
    out["L" .. i], out["R" .. i] = l, r
    if l then left = left + 1 end
    if r then right = right + 1 end
  end
  out.dockL, out.dockR = left > 0, right > 0
  return out
end
local navLastGood
function update(ui)
  local ok, r = pcall(navBase, ui)
  if ok then navLastGood = r else
    if log then log("update error: " .. tostring(r)) end
    r = navLastGood
  end
  if r and r.ready then for key, v in pairs(navState(ui or {})) do r[key] = v end end
  return r
end
-- <<< nav placement
