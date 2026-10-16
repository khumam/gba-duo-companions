local species_names = pack.require("species_names")
local item_names = pack.require("item_names")

-- gPlayerPartyCount / gPlayerParty: live EWRAM globals (not SaveBlock1's
-- save-file copy), per include/pokemon.h's extern declarations.
local PARTY_COUNT_ADDR = 0x02024029
local PARTY_ADDR = 0x02024284
local POKEMON_SIZE = 0x64

local SAVEBLOCK1_PTR_ADDR = 0x03005008
local SAVEBLOCK2_PTR_ADDR = 0x0300500C

-- struct SaveBlock1 offsets (include/global.h, source-annotated)
local MONEY_OFFSET = 0x0290
local BAG_ITEMS_OFFSET, BAG_ITEMS_COUNT = 0x0310, 42
local BAG_KEYITEMS_OFFSET, BAG_KEYITEMS_COUNT = 0x03B8, 30
local BAG_BALLS_OFFSET, BAG_BALLS_COUNT = 0x0430, 13
local BAG_TMHM_OFFSET, BAG_TMHM_COUNT = 0x0464, 58
local BAG_BERRIES_OFFSET, BAG_BERRIES_COUNT = 0x054C, 43
local BADGE_BYTE_OFFSET = 0x0FE4

-- struct SaveBlock2 offsets (include/global.h, source-annotated)
local PLAYTIME_HOURS_OFFSET = 0x0E
local PLAYTIME_MINUTES_OFFSET = 0x10
local PLAYTIME_SECONDS_OFFSET = 0x11
local ENCRYPTION_KEY_OFFSET = 0xF20

-- Icon sprite tables (ROM, FireRed US rev0 — community-sourced; palette
-- table address is known wrong for this ROM, see plan doc's post-build
-- notes. Icons currently decode to a blank image, not a crash.)
local ICON_TABLE_ADDR = 0x083D37A0
local ICON_PALETTE_INDEX_ADDR = 0x083D3E80
local ICON_PALETTE_TABLE_ADDR = 0x083D4038

-- Which physical substruct slot (0-3) holds the Growth substruct (species),
-- indexed by personality % 24. See pokefirered's substruct shuffling scheme.
local PHYS_OF_GROWTH = {
  [0]=0, [1]=0, [2]=0, [3]=0, [4]=0, [5]=0,
  [6]=1, [7]=1, [8]=2, [9]=3, [10]=2, [11]=3,
  [12]=1, [13]=1, [14]=2, [15]=3, [16]=2, [17]=3,
  [18]=1, [19]=1, [20]=2, [21]=3, [22]=2, [23]=3,
}

local function readSpecies(base, personality, otId)
  local key = personality ~ otId
  local physSlot = PHYS_OF_GROWTH[personality % 24]
  local word0 = mem.u32(base + 0x20 + physSlot * 12) ~ key
  return word0 & 0xFFFF
end

local function statusText(status)
  if status & 0x7 ~= 0 then return "Asleep" end
  if status & 0x8 ~= 0 then return "Poisoned" end
  if status & 0x10 ~= 0 then return "Burned" end
  if status & 0x20 ~= 0 then return "Frozen" end
  if status & 0x40 ~= 0 then return "Paralyzed" end
  if status & 0x80 ~= 0 then return "Badly Poisoned" end
  return ""
end

-- Short status tags for the chips, with the colour each one wears.
local STATUS_TAGS = {
  Asleep = { "SLP", "#8C8CA8" }, Poisoned = { "PSN", "#A33EA1" }, Burned = { "BRN", "#E2552A" },
  Frozen = { "FRZ", "#5AB8D8" }, Paralyzed = { "PAR", "#D8B42A" }, ["Badly Poisoned"] = { "TOX", "#7A1F78" },
}

local IMG = "asset:img/"

-- gBaseStats (FireRed US 1.0): 0x1C bytes per species, type 1 and 2 at +6/+7.
local BASE_STATS_ADDR = 0x08254784
local BASE_STATS_SIZE = 0x1C
local TYPE_KEYS = { [0] = "normal", "fighting", "flying", "poison", "ground", "rock", "bug", "ghost", "steel",
  "unknown", "fire", "water", "grass", "electric", "psychic", "ice", "dragon", "dark" }

-- HP colour bands as the game draws them: over half green, over a fifth amber.
local function hpBands(hp, maxHp)
  local pct = maxHp > 0 and hp / maxHp or 0
  return pct, pct > 0.5, pct <= 0.5 and pct > 0.2, pct <= 0.2
end

local function decorate(mon, status)
  local tag = STATUS_TAGS[status]
  mon.hpPct, mon.hpHigh, mon.hpMid, mon.hpLow = hpBands(mon.hp, mon.maxHp)
  mon.fainted = mon.hp == 0
  mon.hasStatus = tag ~= nil and not mon.fainted
  mon.statusTag = mon.fainted and "FNT" or (tag and tag[1] or "")
  mon.statusColor = tag and tag[2] or "#555"
  return mon
end

local function readIcon(species)
  local iconPtr = mem.u32(ICON_TABLE_ADDR + species * 4)
  local paletteIdx = mem.u8(ICON_PALETTE_INDEX_ADDR + species)
  local paletteAddr = mem.u32(ICON_PALETTE_TABLE_ADDR + paletteIdx * 4)
  return gfx.decode({ tiles = iconPtr, palette = paletteAddr, width = 32, height = 32, bpp = 4, lz77 = false })
end

-- Defined further down with the battle data; party cards use the same colours.
local TYPE_NAMES, TYPE_COLORS

local function typeList(t1, t2)
  local types = {}
  for _, t in ipairs(t1 == t2 and { t1 } or { t1, t2 }) do
    types[#types + 1] = { name = TYPE_NAMES[t] or "?", color = TYPE_COLORS[t] or "#D1D1E0" }
  end
  return types
end

local function orbFor(t)
  return IMG .. "orb-" .. (TYPE_KEYS[t] or "normal") .. ".png"
end

local function readParty()
  local count = mem.u8(PARTY_COUNT_ADDR)
  local party = {}
  if count > 6 then return party end
  for i = 0, count - 1 do
    local base = PARTY_ADDR + i * POKEMON_SIZE
    local personality = mem.u32(base)
    local otId = mem.u32(base + 0x04)
    local species = readSpecies(base, personality, otId)
    local stats = BASE_STATS_ADDR + species * BASE_STATS_SIZE
    local t1, t2 = mem.u8(stats + 6), mem.u8(stats + 7)
    local status = statusText(mem.u32(base + 0x50))
    party[#party + 1] = decorate({
      icon = readIcon(species),
      orb = orbFor(t1),
      types = typeList(t1, t2),
      lead = i == 0,
      slot = i + 1,
      name = species_names[species] or ("#" .. species),
      level = mem.u8(base + 0x54),
      hp = mem.u16(base + 0x56),
      maxHp = mem.u16(base + 0x58),
      status = status,
    }, status)
  end
  return party
end

local function itemDisplayName(itemId)
  local name = item_names[itemId]
  if name then return name end
  if itemId >= 289 and itemId <= 338 then return string.format("TM%02d", itemId - 288) end
  if itemId >= 339 and itemId <= 346 then return string.format("HM%02d", itemId - 338) end
  return "Item #" .. itemId
end

local function readPocket(sb1, offset, count)
  local list = {}
  for i = 0, count - 1 do
    local slotAddr = sb1 + offset + i * 4
    local itemId = mem.u16(slotAddr)
    if itemId ~= 0 then
      local qty = mem.u16(slotAddr + 2)
      list[#list + 1] = { name = itemDisplayName(itemId), count = qty }
    end
  end
  return list
end

-- ---- Battle -------------------------------------------------------------------
-- FireRed US v1.0 addresses, from the Ironmon-Tracker's verified FireRed v1.0 table
-- (its `pstats` matches our PARTY_ADDR above). gBattleMons holds the live in-battle
-- copy of each battler (struct BattlePokemon, 0x58 bytes): stats with stat stages
-- applied by the battle engine, current HP, status. Battler 0 = yours, 1 = the foe.
local BATTLE_MONS_ADDR = 0x02023BE4
local BATTLE_MON_SIZE = 0x58
local BATTLERS_COUNT_ADDR = 0x02023BCC
-- 0 while a battle is on; 1 won, 2 lost, 4 ran, 7 caught. Not cleared afterwards.
local BATTLE_OUTCOME_ADDR = 0x02023E8A
local BATTLE_TYPE_FLAGS_ADDR = 0x02022B4C
local BATTLE_MAIN_FUNC_ADDR = 0x03004F84
local RETURN_FROM_BATTLE_TO_OVERWORLD = 0x08015B59
local BATTLE_TYPE_TRAINER = 0x08
local MAX_SPECIES = 411

TYPE_NAMES = { [0] = "Normal", "Fighting", "Flying", "Poison", "Ground", "Rock", "Bug", "Ghost", "Steel",
  "???", "Fire", "Water", "Grass", "Electric", "Psychic", "Ice", "Dragon", "Dark" }
TYPE_COLORS = { [0] = "#A8A77A", "#C22E28", "#A98FF3", "#A33EA1", "#E2BF65", "#B6A136", "#A6B91A", "#735797",
  "#B7B7CE", "#68A090", "#EE8130", "#6390F0", "#7AC74C", "#F7D02C", "#F95587", "#96D9D6", "#6F35FC", "#705746" }

-- Display stats: name, offset in BattlePokemon, index in its statStages[] (6 = neutral).
local BATTLE_STATS = {
  { "ATK", 0x02, 1 }, { "DEF", 0x04, 2 }, { "SP.ATK", 0x08, 4 }, { "SP.DEF", 0x0A, 5 }, { "SPEED", 0x06, 3 },
}

local function inBattle()
  if mem.u8(BATTLE_OUTCOME_ADDR) ~= 0 then return false end
  if mem.u8(BATTLERS_COUNT_ADDR) < 2 then return false end
  local mainFunc = mem.u32(BATTLE_MAIN_FUNC_ADDR)
  if mainFunc == 0 or mainFunc == RETURN_FROM_BATTLE_TO_OVERWORLD then return false end
  local species = mem.u16(BATTLE_MONS_ADDR)
  return species > 0 and species <= MAX_SPECIES
end

local function readBattleMon(battler, side)
  local base = BATTLE_MONS_ADDR + battler * BATTLE_MON_SIZE
  local species = mem.u16(base)
  local t1, t2 = mem.u8(base + 0x21), mem.u8(base + 0x22)
  local types = typeList(t1, t2)
  local stats = {}
  for _, s in ipairs(BATTLE_STATS) do
    local stage = mem.u8(base + 0x18 + s[3]) - 6
    stats[#stats + 1] = {
      name = s[1],
      value = mem.u16(base + s[2]),
      stage = stage > 0 and ("+" .. stage) or (stage < 0 and tostring(stage) or ""),
      up = stage > 0,
      down = stage < 0,
    }
  end
  local status = statusText(mem.u32(base + 0x4C))
  return decorate({
    side = side,
    foe = side == "FOE",
    orb = orbFor(t1),
    name = species_names[species] or ("#" .. species),
    level = mem.u8(base + 0x2A),
    hp = mem.u16(base + 0x28),
    maxHp = mem.u16(base + 0x2C),
    status = status,
    types = types,
    stats = stats,
  }, status)
end

local function readBattle()
  local trainer = (mem.u32(BATTLE_TYPE_FLAGS_ADDR) & BATTLE_TYPE_TRAINER) ~= 0
  return {
    kind = trainer and "TRAINER BATTLE" or "WILD BATTLE",
    mons = { readBattleMon(0, "YOU"), readBattleMon(1, "FOE") },
  }
end

-- ---- Trainer card ---------------------------------------------------------------
-- struct SaveBlock2: playerName[8] at 0x00 (game charset, 0xFF ends it),
-- playerTrainerId[4] at 0x0A (low half = the ID on the card), and the Pokedex
-- at 0x18 with owned[52] at +0x10 and seen[52] at +0x44 (bit n = dex no. n+1).
local PLAYER_NAME_OFFSET, PLAYER_NAME_LEN = 0x00, 7
local TRAINER_ID_OFFSET = 0x0A
local DEX_OWNED_OFFSET = 0x28
local DEX_SEEN_OFFSET = 0x5C
local KANTO_DEX = 151

local BADGES = { "Boulder", "Cascade", "Thunder", "Rainbow", "Soul", "Marsh", "Volcano", "Earth" }

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

local function countBits(addr, bits)
  local n = 0
  for i = 0, bits - 1 do
    if (mem.u8(addr + i // 8) >> (i % 8)) & 1 == 1 then n = n + 1 end
  end
  return n
end

local function withCommas(n)
  local s = tostring(n)
  while true do
    local k
    s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
    if k == 0 then return s end
  end
end

local function inEwram(p) return p >= 0x02000000 and p < 0x02040000 end

local wasInBattle = false

function update(ui)
  local sb1 = mem.u32(SAVEBLOCK1_PTR_ADDR)
  local sb2 = mem.u32(SAVEBLOCK2_PTR_ADDR)
  local partyCount = mem.u8(PARTY_COUNT_ADDR)
  -- Before a save is loaded (title, intro) there's no party and no save blocks.
  if not (inEwram(sb1) and inEwram(sb2)) or partyCount == 0 or partyCount > 6 then
    wasInBattle = false
    return { ready = false, waiting = true }
  end

  local encMoney = mem.u32(sb1 + MONEY_OFFSET)
  local encKey = mem.u32(sb2 + ENCRYPTION_KEY_OFFSET)
  local money = encMoney ~ encKey

  local badgeByte = mem.u8(sb1 + BADGE_BYTE_OFFSET)
  local badgeCount = 0
  local badges = {}
  for b = 0, 7 do
    local earned = (badgeByte >> b) & 1 == 1
    if earned then badgeCount = badgeCount + 1 end
    badges[#badges + 1] = {
      name = BADGES[b + 1],
      earned = earned,
      src = IMG .. "badge-" .. (b + 1) .. (earned and "" or "-empty") .. ".png",
    }
  end

  local hours = mem.u16(sb2 + PLAYTIME_HOURS_OFFSET)
  local minutes = mem.u8(sb2 + PLAYTIME_MINUTES_OFFSET)
  local seconds = mem.u8(sb2 + PLAYTIME_SECONDS_OFFSET)

  local bag = {
    items = readPocket(sb1, BAG_ITEMS_OFFSET, BAG_ITEMS_COUNT),
    keyItems = readPocket(sb1, BAG_KEYITEMS_OFFSET, BAG_KEYITEMS_COUNT),
    balls = readPocket(sb1, BAG_BALLS_OFFSET, BAG_BALLS_COUNT),
    tmHm = readPocket(sb1, BAG_TMHM_OFFSET, BAG_TMHM_COUNT),
    berries = readPocket(sb1, BAG_BERRIES_OFFSET, BAG_BERRIES_COUNT),
  }
  for _, pocket in ipairs({ "items", "keyItems", "balls", "tmHm", "berries" }) do
    bag[pocket .. "Count"] = #bag[pocket]
  end

  local caught = countBits(sb2 + DEX_OWNED_OFFSET, KANTO_DEX)
  local seen = countBits(sb2 + DEX_SEEN_OFFSET, KANTO_DEX)

  local out = {
    ready = true,
    waiting = false,
    party = readParty(),
    partyCount = partyCount,
    bag = bag,
    trainer = {
      name = readName(sb2 + PLAYER_NAME_OFFSET, PLAYER_NAME_LEN),
      id = string.format("%05d", mem.u16(sb2 + TRAINER_ID_OFFSET)),
      money = money,
      moneyText = withCommas(money),
      badges = badgeCount,
      badgeList = badges,
      badgePct = badgeCount / 8,
      caught = caught,
      seen = seen,
      dexTotal = KANTO_DEX,
      caughtPct = caught / KANTO_DEX,
      seenPct = seen / KANTO_DEX,
      playTime = string.format("%d:%02d:%02d", hours, minutes, seconds),
    },
  }

  -- Open the battle page when a battle starts and go back when it ends — only on the
  -- change, so the player can still tap away from it mid-battle.
  local battling = inBattle()
  if battling then out.battle = readBattle() end
  if battling and not wasInBattle then
    out.ui = { navigate = "battle" }
  elseif wasInBattle and not battling then
    out.ui = { back = true }
  end
  wasInBattle = battling
  return out
end
