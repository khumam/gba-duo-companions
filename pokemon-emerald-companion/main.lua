-- Pokemon Emerald (US, BPEE), companion pack. RAM addresses follow pret/pokeemerald; the ROM tables
-- (names, move data, descriptions, region map) were located by matching text and structs against a real
-- BPEE ROM and are read straight from it, so there are no name tables to maintain. update() returns the
-- shape the layout binds (art/layout.mjs).

local game = pack.require("game_data")

-- ---- RAM -------------------------------------------------------------------------------
local PARTY_COUNT_ADDR = 0x020244E9   -- gPlayerPartyCount
local PARTY_ADDR = 0x020244EC         -- gPlayerParty
local POKEMON_SIZE = 0x64
local SAVEBLOCK1_PTR_ADDR = 0x03005D8C
local SAVEBLOCK2_PTR_ADDR = 0x03005D90
local PLAYER_OBJECT_ADDR = 0x02037350 -- gObjectEvents[0]; bit 0 = active
local MAP_HEADER_ADDR = 0x02037318    -- gMapHeader
local MAPSEC_OFFSET, MAPTYPE_OFFSET = 0x14, 0x17

-- struct SaveBlock1
local POS_OFFSET = 0x00               -- Coords16 x, y
local MONEY_OFFSET = 0x0490           -- u32, XOR SaveBlock2's encryption key
local FLAGS_OFFSET = 0x1270           -- one bit per flag
local FLAG_BADGE01_GET = 0x867        -- ... through 0x86E
local BAG_POCKETS = { items = { 0x0560, 30 }, keyItems = { 0x05D8, 30 }, balls = { 0x0630, 16 },
  tmHm = { 0x0690, 64 }, berries = { 0x0790, 46 } }
-- struct SaveBlock2
local PLAYER_NAME_OFFSET, TRAINER_ID_OFFSET = 0x00, 0x0A
local PLAYTIME_HOURS_OFFSET, PLAYTIME_MINUTES_OFFSET = 0x0E, 0x10
local DEX_OWNED_OFFSET, DEX_SEEN_OFFSET = 0x28, 0x5C  -- bit n = national no. n+1
local ENCRYPTION_KEY_OFFSET = 0xAC

-- Battle: gBattleMons (struct BattlePokemon, 0x58 bytes per battler) and friends.
local BATTLE_MONS_ADDR = 0x02024084
local BATTLE_MON_SIZE = 0x58
local BATTLERS_COUNT_ADDR = 0x0202406C
local BATTLE_TYPE_FLAGS_ADDR = 0x02022FEC
local BATTLER_PARTY_INDEXES_ADDR = 0x0202406E -- gBattlerPartyIndexes[battler] (u16): which party slot is out
local ENEMY_PARTY_ADDR = 0x02024744          -- gEnemyParty
local MAIN_IN_BATTLE_ADDR = 0x030022C0 + 0x439 -- gMain.inBattle, bit 1
local BATTLE_TYPE_DOUBLE, BATTLE_TYPE_TRAINER = 0x01, 0x08
local MAX_SPECIES = 411
-- the battle controllers (battle_controller_player.c)
local BUFFER_A_ADDR = 0x02023064         -- gBattleBufferA[battler][0x200]: [0] = the command the controller is on
local BUFFER_B_ADDR = 0x02023864         -- gBattleBufferB[battler][0x200]: what the controller answers the engine
local EXEC_FLAGS_ADDR = 0x02024068       -- gBattleControllerExecFlags: bit n = battler n's controller is busy
local CONTROLLER_FUNCS_ADDR = 0x03005D60 -- gBattlerControllerFuncs[battler] (function pointers)
local CONTROLLER_CHOOSEACTION, CONTROLLER_CHOOSEMOVE, CONTROLLER_TWORETURNVALUES = 18, 20, 33
local B_ACTION_EXEC_SCRIPT = 10          -- "a move was chosen" reply of the move menu
local ACTION_CURSOR_ADDR = 0x020244AC    -- gActionSelectionCursor[battler]: 0 FIGHT, 1 BAG, 2 POKEMON, 3 RUN
local MOVE_CURSOR_ADDR = 0x020244B0      -- gMoveSelectionCursor[battler]: move slot 0-3

-- ---- ROM tables (US 1.0) ------------------------------------------------------------------
local SPECIES_NAMES = 0x083185C8      -- 11 bytes per species
local MOVE_NAMES = 0x0831977C         -- 13 bytes per move
local ABILITY_NAMES = 0x0831B6DB      -- 13 bytes per ability
local ABILITY_DESCS = 0x0831BAD4      -- pointer per ability
local BATTLE_MOVES = 0x0831C898       -- 12 bytes per move: effect, power, type, accuracy, pp, _, target
local BASE_STATS = 0x083203CC         -- 0x1C bytes per species
local ITEMS = 0x085839A0              -- 44 bytes per item: name[14], id, price(u16 @16), description ptr @20
local CONTEST_EFFECT_DESCS = 0x08587C50
local REGION_MAP_ENTRIES = 0x085A147C -- x, y, w, h, name pointer
local MOVE_DESCS = 0x0861C524         -- pointer per move, from move 1
local TM_FIRST_ITEM, HM_FIRST_ITEM, HM_LAST_ITEM = 289, 339, 346

-- ---- Text --------------------------------------------------------------------------------
local PUNCT = { [0xAB] = "!", [0xAC] = "?", [0xAD] = ".", [0xAE] = "-", [0xB4] = "'", [0xB8] = ",",
  [0xBA] = "/", [0x1B] = "é", [0xFE] = " ", [0xFA] = " ", [0xFB] = " " }
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
    -- a line break after a hyphen joins the word ("full-\nbody")
    if c == 0xFE and out[#out] == "-" then c = 0xFD end
    out[#out + 1] = decodeChar(c)
  end
  return table.concat(out)
end

-- ROM text never changes: read each string once.
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
local function moveDesc(id) return id > 0 and romPtr(MOVE_DESCS, id - 1, 100) or "" end

local function itemName(id)
  local name = rom(ITEMS + id * 44, 13)
  local tm = id >= TM_FIRST_ITEM and id < HM_FIRST_ITEM and id - TM_FIRST_ITEM
  local hm = id >= HM_FIRST_ITEM and id <= HM_LAST_ITEM and id - HM_FIRST_ITEM + 50
  local idx = tm or hm
  if idx then
    local move = game.tmhm[idx + 1]
    if move then return name .. " " .. moveName(move) end
  end
  return name
end
local function itemIcon(id)
  if id >= TM_FIRST_ITEM and id < HM_FIRST_ITEM then return "asset:items/tm.png", true end
  if id >= HM_FIRST_ITEM and id <= HM_LAST_ITEM then return "asset:items/hm.png", true end
  if game.itemIcons[id] then return "asset:items/" .. id .. ".png", true end
  return "", false
end

local lo16 = function(v) return v & 0xFFFF end
local hi16 = function(v) return (v >> 16) & 0xFFFF end
local byte = function(v, n) return (v >> (n * 8)) & 0xFF end

-- ---- Look-ups ------------------------------------------------------------------------------
local TYPES = { [0] = "normal", "fighting", "flying", "poison", "ground", "rock", "bug", "ghost", "steel",
  "unknown", "fire", "water", "grass", "electric", "psychic", "ice", "dragon", "dark" }
local NATURES = { [0] = "Hardy", "Lonely", "Brave", "Adamant", "Naughty", "Bold", "Docile", "Relaxed",
  "Impish", "Lax", "Timid", "Hasty", "Serious", "Jolly", "Naive", "Modest", "Mild", "Quiet", "Bashful",
  "Rash", "Calm", "Gentle", "Sassy", "Careful", "Quirky" }
-- Nature n raises stat n // 5 and lowers n % 5 (same = neutral), in this order:
local NATURE_STATS = { [0] = "ATTACK", "DEFENSE", "SPEED", "SP. ATK", "SP. DEF" }
local CONTEST = { [0] = { "COOL", "#D85040" }, { "BEAUTY", "#5088C0" }, { "CUTE", "#D85868" },
  { "SMART", "#58A868" }, { "TOUGH", "#E8A050" } }
local MAP_KINDS = { [0] = "-", "TOWN", "CITY", "ROUTE", "UNDERGROUND", "UNDERWATER", "OCEAN", "-", "INDOORS", "SECRET BASE" }
local BADGES = { "STONE", "KNUCKLE", "DYNAMO", "HEAT", "BALANCE", "FEATHER", "MIND", "RAIN" }

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

local function dexOf(speciesId) return game.national[speciesId] or 0 end
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
local function genderOf(personality, ratio)
  if ratio == 255 then return false, false end
  if ratio == 254 then return false, true end
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

-- Total EXP to reach level n for each growth rate (the formulas the game's tables are built from).
local function expAt(rate, n)
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
local function dress(mon)
  mon.hpPct, mon.hpHigh, mon.hpMid, mon.hpLow = bands(mon.hp, mon.maxHp)
  mon.fainted = mon.hp == 0
  return mon
end

-- ---- Pokemon substructs ----------------------------------------------------------------------
-- The 48 secure bytes hold four 12-byte substructs in one of 24 orders (personality % 24), XOR-ed with
-- personality ~ otId.
local ORDERS = {
  [0] = "GAEM", "GAME", "GEAM", "GEMA", "GMAE", "GMEA", "AGEM", "AGME", "AEGM", "AEMG", "AMGE", "AMEG",
  "EGAM", "EGMA", "EAGM", "EAMG", "EMGA", "EMAG", "MGAE", "MGEA", "MAGE", "MAEG", "MEGA", "MEAG",
}
local function substructs(base)
  local personality, otId = mem.u32(base), mem.u32(base + 0x04)
  local key = personality ~ otId
  local order = ORDERS[personality % 24]
  local out = {}
  for slot = 0, 3 do
    local words = {}
    for w = 0, 2 do words[w] = mem.u32(base + 0x20 + slot * 12 + w * 4) ~ key end
    out[order:sub(slot + 1, slot + 1)] = words
  end
  return out, personality, otId
end

-- Ribbons: five 3-bit contest ranks, then single-bit ribbons (champion, winning, victory, artist...).
local function ribbonCount(bits)
  local n = 0
  for i = 0, 4 do if (bits >> (i * 3)) & 7 ~= 0 then n = n + 1 end end
  for i = 15, 26 do if (bits >> i) & 1 == 1 then n = n + 1 end end
  return n
end

local function placeName(mapsec)
  if mapsec >= 213 then return "A DISTANT PLACE" end
  local entry = REGION_MAP_ENTRIES + mapsec * 8
  return romPtr(entry + 4, 0, 24), entry
end

local EMPTY_MOVE = { name = "-", type = "", power = "--", acc = "--", pp = "--", ppPct = 0, ppLow = false,
  has = false, desc = "", contest = "", contestColor = "#FFFFFF", cdesc = "", info = "" }

local function readMonAt(base, isLead)
  local sub, personality, otId = substructs(base)
  local speciesId = lo16(sub.G[0])
  local stats = BASE_STATS + speciesId * 0x1C
  local t1, t2 = mem.u8(stats + 6), mem.u8(stats + 7)
  local level = mem.u8(base + 0x54)
  local dex = dexOf(speciesId)
  local male, female = genderOf(personality, mem.u8(stats + 0x10))

  local heldItem = hi16(sub.G[0])
  local exp = sub.G[1]
  local ppBonuses = byte(sub.G[2], 0)
  local friendship = byte(sub.G[2], 1)
  local rate = mem.u8(stats + 0x13)
  local floor, ceil = expAt(rate, level), expAt(rate, math.min(100, level + 1))
  local expPct = level >= 100 and 1 or math.max(0, math.min(1, (exp - floor) / math.max(1, ceil - floor)))

  -- Ability: the species' first or second, by bit 31 of the Misc IV word.
  local ability = mem.u8(stats + 0x16 + ((sub.M[1] >> 31) & 1))
  if ability == 0 then ability = mem.u8(stats + 0x16) end

  -- Misc: location caught at, level caught at (origins bits 0-6), ribbons
  local metLocation = byte(sub.M[0], 1)
  local metLevel = (sub.M[0] >> 16) & 0x7F
  local metPlace = placeName(metLocation)
  if metPlace == "" then metPlace = "A DISTANT PLACE" end
  local ribbons = ribbonCount(sub.M[2])

  -- EVs and contest condition share a substruct.
  local ev = { byte(sub.E[0], 0), byte(sub.E[0], 1), byte(sub.E[0], 2), byte(sub.E[1], 0), byte(sub.E[1], 1), byte(sub.E[0], 3) }
  local cond = { byte(sub.E[1], 2), byte(sub.E[1], 3), byte(sub.E[2], 0), byte(sub.E[2], 1), byte(sub.E[2], 2) }
  local sheen = byte(sub.E[2], 3)

  local nature = personality % 25
  local up, down = NATURE_STATS[nature // 5], NATURE_STATS[nature % 5]
  if up == down then up, down = nil, nil end
  local hp, maxHp = mem.u16(base + 0x56), mem.u16(base + 0x58)
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
      local data = BATTLE_MOVES + id * 12
      local power, acc = mem.u8(data + 1), mem.u8(data + 3)
      local ppMax = mem.u8(data + 4)
      ppMax = ppMax + ppMax * ((ppBonuses >> (m * 2)) & 3) // 5
      local ppNow = byte(sub.A[2], m)
      local c = game.contest[id] or { 0, 0 }
      local label = CONTEST[c[2]] or CONTEST[0]
      moves[#moves + 1] = {
        name = moveName(id),
        type = "asset:types/" .. (TYPES[mem.u8(data + 2)] or "normal") .. ".png",
        power = power > 0 and tostring(power) or "--", acc = acc > 0 and tostring(acc) or "--",
        pp = ppNow .. "/" .. ppMax, ppPct = ppMax > 0 and ppNow / ppMax or 0, ppLow = ppMax > 0 and ppNow / ppMax <= 0.25,
        has = true, desc = moveDesc(id),
        contest = label[1], contestColor = label[2], cdesc = romPtr(CONTEST_EFFECT_DESCS, c[1], 80),
      }
    end
  end
  local firstDesc, firstContest = moves[1] and moves[1].desc or "", moves[1] and moves[1].cdesc or ""
  while #moves < 4 do moves[#moves + 1] = EMPTY_MOVE end

  local tag = statusTag(mem.u32(base + 0x50))
  local icon, hasIcon = "", false
  if heldItem ~= 0 then icon, hasIcon = itemIcon(heldItem) end
  return dress({
    name = readString(base + 0x08, 10),
    dex = string.format("%03d", dex),
    sprite = sprite(dex),
    level = level,
    hp = hp,
    maxHp = maxHp,
    lead = isLead,
    male = male, female = female,
    types = typeList(t1, t2),
    status = tag, hasStatus = tag ~= "",
    ot = readString(base + 0x14, 7),
    id = string.format("%05d", otId & 0xFFFF),
    ability = abilityName(ability),
    abilityText = romPtr(ABILITY_DESCS, ability, 60),
    nature = NATURES[nature]:upper(),
    metLevel = metLevel,
    metPlace = metPlace,
    item = heldItem ~= 0 and itemName(heldItem) or "NONE",
    hasHeld = hasIcon, heldIcon = icon,
    ribbon = ribbons == 0 and "NONE" or (ribbons .. (ribbons == 1 and " RIBBON" or " RIBBONS")),
    friendship = tostring(friendship), friendPct = friendship / 255,
    statRows = statRows,
    exp = tostring(exp),
    toNext = tostring(level >= 100 and 0 or math.max(0, ceil - exp)),
    expPct = expPct,
    moves = moves,
    moveDesc = firstDesc,
    contestDesc = firstContest,
    condition = condition, sheen = tostring(sheen), sheenPct = sheen / 255,
  })
end

local function readMon(slot) return readMonAt(PARTY_ADDR + slot * POKEMON_SIZE, slot == 0) end

local function readParty(count)
  local party = {}
  for i = 0, count - 1 do party[#party + 1] = readMon(i) end
  return party
end

local function readTeam(party)
  local hp, maxHp, levels = 0, 0, 0
  for _, m in ipairs(party) do hp, maxHp, levels = hp + m.hp, maxHp + m.maxHp, levels + m.level end
  local pct, high, mid, low = bands(hp, maxHp)
  return { hp = tostring(hp), maxHp = tostring(maxHp), hpPct = pct, hpHigh = high, hpMid = mid, hpLow = low,
    avg = tostring(#party > 0 and levels // #party or 0) }
end

-- ---- Bag ---------------------------------------------------------------------------------------
local function readPocket(sb1, sb2, pocket, showCount)
  local offset, slots = pocket[1], pocket[2]
  local key = mem.u32(sb2 + ENCRYPTION_KEY_OFFSET) & 0xFFFF
  local list, total = {}, 0
  for i = 0, slots - 1 do
    local addr = sb1 + offset + i * 4
    local id = mem.u16(addr)
    if id ~= 0 then
      local qty = mem.u16(addr + 2) ~ key
      local icon, hasIcon = itemIcon(id)
      list[#list + 1] = {
        name = itemName(id), count = showCount and ("x" .. qty) or "",
        icon = icon, hasIcon = hasIcon,
        desc = romPtr(ITEMS + id * 44 + 20, 0, 100),
        price = tostring(mem.u16(ITEMS + id * 44 + 16)),
      }
      total = total + qty
    end
  end
  return list, total
end

-- ---- Battle ------------------------------------------------------------------------------------
-- name, index in statStages[] (6 = neutral)
local BATTLE_STATS = { { "ATTACK", 1 }, { "DEFENSE", 2 }, { "SP. ATK", 4 }, { "SP. DEF", 5 }, { "SPEED", 3 } }

local function inBattle()
  if (mem.u8(MAIN_IN_BATTLE_ADDR) >> 1) & 1 == 0 then return false end
  if mem.u8(BATTLERS_COUNT_ADDR) < 2 then return false end
  local species = mem.u16(BATTLE_MONS_ADDR)
  return species > 0 and species <= MAX_SPECIES
end

local function readBattleMon(battler)
  local base = BATTLE_MONS_ADDR + battler * BATTLE_MON_SIZE
  local speciesId = mem.u16(base)
  local t1, t2 = mem.u8(base + 0x21), mem.u8(base + 0x22)
  local stats = {}
  for _, s in ipairs(BATTLE_STATS) do
    local stage = mem.u8(base + 0x18 + s[2]) - 6
    if stage ~= 0 then  -- only what changed; an empty list reads "STATS UNCHANGED"
      stats[#stats + 1] = { name = s[1], stage = stage > 0 and ("+" .. stage) or tostring(stage), up = stage > 0, down = stage < 0 }
    end
  end
  local male, female = genderOf(mem.u32(base + 0x48), mem.u8(BASE_STATS + speciesId * 0x1C + 0x10))
  local tag = statusTag(mem.u32(base + 0x4C))
  return dress({
    name = speciesName(speciesId),
    level = mem.u8(base + 0x2A),
    hp = mem.u16(base + 0x28),
    maxHp = mem.u16(base + 0x2C),
    sprite = sprite(dexOf(speciesId), battler == 0),
    types = typeList(t1, t2), t1 = t1, t2 = t2,
    male = male, female = female,
    status = tag, hasStatus = tag ~= "",
    stats = stats,
  })
end

local function readBattleMoves(battler, foe)
  local base = BATTLE_MONS_ADDR + battler * BATTLE_MON_SIZE
  local out, best, bestScore = {}, nil, 0
  local cursor = mem.u8(MOVE_CURSOR_ADDR)
  for m = 0, 3 do
    local id = mem.u16(base + 0x0C + m * 2)
    if id ~= 0 then
      local data = BATTLE_MOVES + id * 12
      local power, acc, mtype = mem.u8(data + 1), mem.u8(data + 3), mem.u8(data + 2)
      local eff = effectiveness(mtype, foe.t1, foe.t2)  -- 4 = neutral
      local label = power == 0 and "--" or (eff == 0 and "x0" or (eff == 4 and "x1" or (eff > 4 and ("x" .. (eff // 4)) or (eff == 2 and "x1/2" or "x1/4"))))
      local score = power * eff
      if score > bestScore then bestScore, best = score, moveName(id) .. " " .. label end
      out[#out + 1] = {
        name = moveName(id), pp = tostring(mem.u8(base + 0x24 + m)),
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

-- ---- Header / map -------------------------------------------------------------------------------
local function countBits(addr)
  local c = 0
  for i = 0, 48 do
    local b = mem.u8(addr + i)
    while b ~= 0 do c = c + (b & 1); b = b >> 1 end
  end
  return c
end

-- ---- Area map -------------------------------------------------------------------------------------
-- The map of the area you're in, drawn from the game's own data like the wide view does: the map the game keeps in
-- RAM (gBackupMapLayout), its metatile tables from the ROM layout, and the tile graphics and palettes from VRAM.
-- It's only drawn while the overworld is on screen (a menu or battle has other graphics in VRAM) and only while the
-- map page is open; a picture drawn earlier stays until the area changes.
local BACKUP_LAYOUT_ADDR = 0x03005DC0     -- gBackupMapLayout { s32 width; s32 height; u16 *map }
local MAP_OFFSET = 7                      -- the border around a map in the game's grid
local MAPGRID_UNDEFINED = 0x3FF
local NUM_METATILES_IN_PRIMARY = 512
local MAP_VIEW_ASPECT = 1.93              -- the card's shape: the picture is cut to it, so it fills the card like CSS `cover`
local MAP_VIEW_MIN_W, MAP_VIEW_MAX_W = 240, 320 -- world px the card shows across: a small map is zoomed in, a big one scrolls
local MAP_VIEW_FLOOR_W = 176              -- never shrink the view below this
-- A script call may run 25 ms, and drawing the picture counts. 320 x 166 px fits beside the rest of update(); if a call
-- is ever cut off (a slower moment, a busier map) the view shrinks a step instead of failing every time.
local MAP_SHRINK_STEP = 48
local MAP_SETTLE_TICKS = 3                -- between the draws of a new area (its tiles load a little late)
local MAP_SETTLE_MAX = 4                  -- draws before a new area is shown whatever it looks like (animated tiles never match)
local areaShot = { sig = nil, shown = nil, pending = nil, maxW = MAP_VIEW_MAX_W }

local function overworldOnScreen()
  local dispcnt = mem.u16(0x04000000)
  if dispcnt & 7 ~= 0 or dispcnt & 0x0600 ~= 0x0600 then return false end   -- mode 0, BG1 and BG2 on
  return (mem.u16(0x0400000A) >> 2) & 3 == 0 and (mem.u16(0x0400000C) >> 2) & 3 == 0   -- both read tiles from char block 0
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- A picture of the area around the player, cut to the card's shape. The view follows the player a tile at a
-- time and stops at the map's edges; a map smaller than the view is centred (its surroundings show around it).
local function areaPicture(draw)
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
  local px = mem.u16(PLAYER_OBJECT_ADDR + 0x10) * 16 + 8 - MAP_OFFSET * 16
  local py = mem.u16(PLAYER_OBJECT_ADDR + 0x12) * 16 + 8 - MAP_OFFSET * 16
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
      local key = render()
      if key then show(key) end
    end
  end

  local shown = areaShot.shown
  if not shown then return nil end
  -- the pin only while the picture on screen is this area
  local fx, fy = (px - shown.cx) / shown.viewW, (py - shown.cy) / shown.viewH
  local hasMe = shown.sig == sig and fx >= 0 and fx <= 1 and fy >= 0 and fy <= 1
  return { image = shown.image, ratio = shown.ratio, hasMe = hasMe,
    mx = string.format("%.2f%%", clamp(fx, 0, 1) * 100), my = string.format("%.2f%%", clamp(fy, 0, 1) * 100) }
end

local function readMap(sb1, draw)
  local mapsec = mem.u8(MAP_HEADER_ADDR + MAPSEC_OFFSET)
  local name = placeName(mapsec)
  if name == "" then name = "HOENN" end
  local kind = MAP_KINDS[mem.u8(MAP_HEADER_ADDR + MAPTYPE_OFFSET)] or "-"
  local out = { route = name, kind = kind, px = tostring(mem.u16(sb1 + POS_OFFSET)), py = tostring(mem.u16(sb1 + POS_OFFSET + 2)),
    live = false, off = true, hasMe = false, image = "", ratio = "1.0000", mx = "50%", my = "50%" }
  local pic = areaPicture(draw and overworldOnScreen())
  if pic then
    out.live, out.off = true, false
    out.image, out.ratio, out.mx, out.my, out.hasMe = pic.image, pic.ratio, pic.mx, pic.my, pic.hasMe
  end
  return out
end

local function withCommas(n)
  local s = tostring(n)
  while true do
    local r, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    s = r
    if k == 0 then break end
  end
  return s
end

-- -------------------------------------------------------------------------------------------------
local function inEwram(p) return p >= 0x02000000 and p < 0x02040000 end

actions = actions or {}

-- ---- Battle controls ---------------------------------------------------------------------------
-- Which menu the game is on: the player's controller (battler 0) is busy with a CHOOSEACTION or
-- CHOOSEMOVE command. This drives the page flow (action page -> move page -> back, every turn).
local function menuState()
  if mem.u32(EXEC_FLAGS_ADDR) & 1 == 0 then return "idle" end
  local cmd = mem.u8(BUFFER_A_ADDR)
  if cmd == CONTROLLER_CHOOSEACTION then return "action" end
  if cmd == CONTROLLER_CHOOSEMOVE then return "moves" end
  return "busy"
end

-- PlayerBufferRunCommand's address is learned from the game: whenever the player's controller is idle
-- its function pointer is exactly that. Needed to hand control back after a faked A press.
local runSeen, runCmd = {}, nil
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
-- No on-screen message any more: what happened goes to the log (adb logcat).
local function say(text) log("battle: " .. text) end

-- Tap an entry of the action menu (FIGHT / BAG / POKéMON / RUN): move the cursor, then press A.
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

-- Tap a move: move the cursor to it, then press A (singles only; a move that needs a target is left
-- to the game).
function actions.setMove(index)
  if not inBattle() then return say("NOT IN A BATTLE") end
  index = tonumber(index) or 0
  local id = mem.u16(BATTLE_MONS_ADDR + 0x0C + index * 2)
  if id == 0 then return say("NO MOVE IN THAT SLOT") end
  local ok, why = mem.write8(MOVE_CURSOR_ADDR, index)
  if not ok then return say("CAN'T CHANGE THE GAME: " .. tostring(why)) end
  local target = mem.u8(BATTLE_MOVES + id * 12 + 6)
  if menuState() ~= "moves" then
    return say("CURSOR ON " .. moveName(id) .. "  -  WAITING FOR THE MOVE MENU")
  end
  if mem.u32(BATTLE_TYPE_FLAGS_ADDR) & BATTLE_TYPE_DOUBLE ~= 0 or target & 0x02 ~= 0 then
    return say("CURSOR ON " .. moveName(id) .. "  -  PRESS A (IT NEEDS A TARGET)")
  end
  if mem.u8(BATTLE_MONS_ADDR + 0x24 + index) == 0 then return say(moveName(id) .. " HAS NO PP LEFT") end
  -- the target is the user for self-targeting moves, the opposing battler otherwise
  ok, why = pressA(B_ACTION_EXEC_SCRIPT, index, (target & 0x10 ~= 0) and 0 or 1)
  if not ok then return say("CURSOR ON " .. moveName(id) .. "  -  PRESS A (" .. tostring(why) .. ")") end
  return say(moveName(id))
end

-- Things that change rarely (badges, the Pokedex counts, the bag) are read every couple of seconds, not every tick:
-- a script call may only run 25 ms, and the map picture needs most of that.
local slow, slowAge = nil, 0
local function readSlow(sb1, sb2)
  local badges, badgeCount = {}, 0
  for i = 0, 7 do
    local flag = FLAG_BADGE01_GET + i
    local earned = (mem.u8(sb1 + FLAGS_OFFSET + flag // 8) >> (flag % 8)) & 1 == 1
    if earned then badgeCount = badgeCount + 1 end
    badges[#badges + 1] = { src = "asset:ui/badge" .. (i + 1) .. ".png", name = BADGES[i + 1], earned = earned, locked = not earned }
  end
  local seen, owned = countBits(sb2 + DEX_SEEN_OFFSET), countBits(sb2 + DEX_OWNED_OFFSET)

  local bag, bagTotal, used, ballCount, firstItem = {}, 0, 0, 0, nil
  for pocket, spec in pairs(BAG_POCKETS) do
    local list, total = readPocket(sb1, sb2, spec, pocket ~= "keyItems")
    bag[pocket] = list
    used = used + #list
    if pocket == "balls" then ballCount = total end
    if pocket ~= "keyItems" then bagTotal = bagTotal + total end
  end
  bag.total, bag.used, bag.capacity = tostring(bagTotal), tostring(used), "186"
  bag.hasAny, bag.isEmpty = used > 0, used == 0
  firstItem = bag.items[1]
  return { badges = badges, badgeCount = badgeCount, seen = seen, owned = owned, bag = bag, bagTotal = bagTotal, ballCount = ballCount, firstItem = firstItem }
end

-- ---- Pokedex ---------------------------------------------------------------------------------
-- struct PokedexEntry (0x20 bytes) per national no.: category[12], height (dm) @12, weight (hg) @14, description ptr @16.
local DEX_ENTRIES = 0x0856B5B0
local DEX_TOTAL, DEX_PAGE = 386, 24
local dexState = { start = 1, sel = 1 }
local dexOut = nil
local internalOf = nil
local function internalId(national)
  if not internalOf then
    internalOf = {}
    for internal, n in pairs(game.national) do
      if n > 0 then internalOf[n] = internal end
    end
  end
  return internalOf[national] or 0
end
local function dexBit(base, n) return (mem.u8(base + (n - 1) // 8) >> ((n - 1) % 8)) & 1 == 1 end
local function tenths(v) return (v // 10) .. "." .. (v % 10) end

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

local STAT_LABELS = { "HP", "ATTACK", "DEFENSE", "SP. ATK", "SP. DEF", "SPEED" }
local STAT_ORDER = { 0, 1, 2, 4, 5, 3 } -- base stat bytes are hp, atk, def, spe, spa, spd
local function readDex(sb2)
  local seenBase, ownBase = sb2 + DEX_SEEN_OFFSET, sb2 + DEX_OWNED_OFFSET
  local entries = {}
  local first = dexState.start
  local last = math.min(DEX_TOTAL, first + DEX_PAGE - 1)
  for n = first, last do
    local seen, own = dexBit(seenBase, n), dexBit(ownBase, n)
    entries[#entries + 1] = { num = n, no = string.format("%03d", n), name = seen and speciesName(internalId(n)) or "-----",
      sprite = seen and sprite(n) or "", seen = seen, unseen = not seen, own = own, sel = n == dexState.sel }
  end

  local n = dexState.sel
  local seen, own = dexBit(seenBase, n), dexBit(ownBase, n)
  local internal = internalId(n)
  local sel = { no = string.format("%03d", n), seen = seen, unseen = not seen, own = own,
    name = seen and speciesName(internal) or "-----", sprite = seen and sprite(n) or "",
    state = own and "OWNED" or (seen and "SEEN" or "NOT SEEN"),
    category = "", height = "--", weight = "--", abilities = "--", types = {}, stats = {},
    desc = seen and "CATCH THIS POKéMON TO FILL IN ITS ENTRY." or "YOU HAVEN'T SEEN THIS POKéMON YET." }
  if seen then
    local base = BASE_STATS + internal * 0x1C
    sel.types = typeList(mem.u8(base + 6), mem.u8(base + 7))
    for i, idx in ipairs(STAT_ORDER) do
      local v = mem.u8(base + idx)
      sel.stats[i] = { label = STAT_LABELS[i], value = tostring(v), pct = math.min(1, v / 150) }
    end
    local a1, a2 = mem.u8(base + 0x16), mem.u8(base + 0x17)
    sel.abilities = (a2 == 0 or a2 == a1) and abilityName(a1) or (abilityName(a1) .. " / " .. abilityName(a2))
  end
  if own then
    local entry = DEX_ENTRIES + n * 0x20
    sel.category = rom(entry, 11) .. " POKéMON"
    sel.height, sel.weight = tenths(mem.u16(entry + 12)) .. "m", tenths(mem.u16(entry + 14)) .. "kg"
    sel.desc = romPtr(entry + 16, 0, 220)
  end
  local pages = (DEX_TOTAL + DEX_PAGE - 1) // DEX_PAGE
  return { entries = entries, sel = sel, range = string.format("%03d-%03d", first, last),
    page = ((first - 1) // DEX_PAGE + 1) .. "/" .. pages }
end

local wasInBattle, wasReady, lastState = false, false, "idle"
local pageBeforeBattle = "party"

function update(ui)
  local currentPage = ui and ui.page
  -- BPEE 1.0 only (the one English Emerald release).
  if mem.u32(0x080000AC) ~= 0x45455042 then
    wasInBattle, wasReady, lastState = false, false, "idle"
    return { ready = false, waiting = true }
  end
  local sb1 = mem.u32(SAVEBLOCK1_PTR_ADDR)
  local sb2 = mem.u32(SAVEBLOCK2_PTR_ADDR)
  local partyCount = mem.u8(PARTY_COUNT_ADDR)
  -- In a game once the player's overworld object exists, not on the title screen or in the intro.
  local inGame = mem.u8(PLAYER_OBJECT_ADDR) & 1 == 1
  if inEwram(sb2) then
    -- SaveBlock2's player name is empty until a save is loaded.
    local first = mem.u8(sb2)
    if first == 0 or first == 0xFF then inGame = false end
  end
  -- The save's data is in memory from the moment the game boots, but the map only exists once the game
  -- has started (after Continue / New Game, or a loaded state): wait for it, so the title screen waits.
  local layout = mem.u32(MAP_HEADER_ADDR)
  if layout < 0x08000000 or layout >= 0x0A000000 then inGame = false end
  if not (inEwram(sb1) and inEwram(sb2)) or not inGame or partyCount > 6 then
    wasInBattle, wasReady, lastState = false, false, "idle"
    return { ready = false, waiting = true }
  end

  local key = mem.u32(sb2 + ENCRYPTION_KEY_OFFSET)
  local money = withCommas(mem.u32(sb1 + MONEY_OFFSET) ~ key)
  local time = string.format("%d:%02d", mem.u16(sb2 + PLAYTIME_HOURS_OFFSET), mem.u8(sb2 + PLAYTIME_MINUTES_OFFSET))

  slowAge = slowAge + 1
  if not slow or slowAge >= 8 or currentPage == "bag" or currentPage == "options" then
    slow, slowAge = readSlow(sb1, sb2), 0
  end
  local badges, badgeCount, seen, owned = slow.badges, slow.badgeCount, slow.seen, slow.owned
  local bag, bagTotal, ballCount, firstItem = slow.bag, slow.bagTotal, slow.ballCount, slow.firstItem

  local party = readParty(partyCount)
  local battling = inBattle()
  local map = readMap(sb1, currentPage == "map" and not battling)
  if currentPage == "dex" or not dexOut then dexOut = readDex(sb2) end

  if battling then learnRunCommand() end
  local state = battling and menuState() or "idle"
  local battle = { inBattle = battling, noBattle = not battling, balls = tostring(ballCount), bagText = bagTotal .. " ITEMS", best = "" }
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
    time = time, money = money,
    dexSeen = tostring(seen), dexCaught = tostring(owned), dexSeenPct = seen / 386, dexCaughtPct = owned / 386,
    badgeCount = tostring(badgeCount), badges = badges,
    trainer = { name = readString(sb2 + PLAYER_NAME_OFFSET, 7), id = string.format("%05d", mem.u16(sb2 + TRAINER_ID_OFFSET)) },
    map = map,
    partyCount = tostring(partyCount),
    party = party,
    team = readTeam(party),
    bag = bag,
    dex = dexOut,
    battle = battle,
  }

  -- UI changes only on a transition, so the player can still tap away. The battle pages follow the
  -- game's own menus: the battle page when a fight starts and whenever the action menu (FIGHT / BAG /
  -- POKéMON / RUN) comes up, the moves page while the move menu is open; the team page afterwards.
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
    local f = firstItem or { name = "", desc = "", icon = "", hasIcon = false, count = "", price = "" }
    uiOut.set = uiOut.set or {}
    uiOut.set.selName, uiOut.set.selDesc, uiOut.set.selIcon, uiOut.set.selHasIcon, uiOut.set.selQty, uiOut.set.selPrice =
      f.name, f.desc, f.icon, f.hasIcon, f.count, f.price
  end
  if next(uiOut) then out.ui = uiOut end
  wasInBattle, wasReady, lastState = battling, true, state
  return out
end
