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

local function readIcon(species)
  local iconPtr = mem.u32(ICON_TABLE_ADDR + species * 4)
  local paletteIdx = mem.u8(ICON_PALETTE_INDEX_ADDR + species)
  local paletteAddr = mem.u32(ICON_PALETTE_TABLE_ADDR + paletteIdx * 4)
  return gfx.decode({ tiles = iconPtr, palette = paletteAddr, width = 32, height = 32, bpp = 4, lz77 = false })
end

local function readParty()
  local count = mem.u8(PARTY_COUNT_ADDR)
  local party = {}
  for i = 0, count - 1 do
    local base = PARTY_ADDR + i * POKEMON_SIZE
    local personality = mem.u32(base)
    local otId = mem.u32(base + 0x04)
    local species = readSpecies(base, personality, otId)
    party[#party + 1] = {
      icon = readIcon(species),
      name = species_names[species] or ("#" .. species),
      level = mem.u8(base + 0x54),
      hp = mem.u16(base + 0x56),
      maxHp = mem.u16(base + 0x58),
      status = statusText(mem.u32(base + 0x50)),
    }
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

local TYPE_NAMES = { [0] = "Normal", "Fighting", "Flying", "Poison", "Ground", "Rock", "Bug", "Ghost", "Steel",
  "???", "Fire", "Water", "Grass", "Electric", "Psychic", "Ice", "Dragon", "Dark" }
local TYPE_COLORS = { [0] = "#C6C6A7", "#D67873", "#C6B7F5", "#C183C1", "#EBD69D", "#D1C17D", "#C6D16E", "#A292BC",
  "#D1D1E0", "#9DC1B7", "#F5AC78", "#9DB7F5", "#A7DB8D", "#FAE078", "#FA92B2", "#BCE6E6", "#A27DFA", "#A29288" }

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
  local types = {}
  local t1, t2 = mem.u8(base + 0x21), mem.u8(base + 0x22)
  for _, t in ipairs(t1 == t2 and { t1 } or { t1, t2 }) do
    types[#types + 1] = { name = TYPE_NAMES[t] or "?", color = TYPE_COLORS[t] or "#D1D1E0" }
  end
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
  return {
    side = side,
    foe = side == "FOE",
    name = species_names[species] or ("#" .. species),
    level = mem.u8(base + 0x2A),
    hp = mem.u16(base + 0x28),
    maxHp = mem.u16(base + 0x2C),
    status = statusText(mem.u32(base + 0x4C)),
    types = types,
    stats = stats,
  }
end

local function readBattle()
  local trainer = (mem.u32(BATTLE_TYPE_FLAGS_ADDR) & BATTLE_TYPE_TRAINER) ~= 0
  return {
    kind = trainer and "TRAINER BATTLE" or "WILD BATTLE",
    mons = { readBattleMon(0, "YOU"), readBattleMon(1, "FOE") },
  }
end

local wasInBattle = false

function update(ui)
  local sb1 = mem.u32(SAVEBLOCK1_PTR_ADDR)
  local sb2 = mem.u32(SAVEBLOCK2_PTR_ADDR)

  local encMoney = mem.u32(sb1 + MONEY_OFFSET)
  local encKey = mem.u32(sb2 + ENCRYPTION_KEY_OFFSET)
  local money = encMoney ~ encKey

  local badgeByte = mem.u8(sb1 + BADGE_BYTE_OFFSET)
  local badgeCount = 0
  for b = 0, 7 do
    if (badgeByte >> b) & 1 == 1 then badgeCount = badgeCount + 1 end
  end

  local hours = mem.u16(sb2 + PLAYTIME_HOURS_OFFSET)
  local minutes = mem.u8(sb2 + PLAYTIME_MINUTES_OFFSET)
  local seconds = mem.u8(sb2 + PLAYTIME_SECONDS_OFFSET)

  local out = {
    party = readParty(),
    bag = {
      items = readPocket(sb1, BAG_ITEMS_OFFSET, BAG_ITEMS_COUNT),
      keyItems = readPocket(sb1, BAG_KEYITEMS_OFFSET, BAG_KEYITEMS_COUNT),
      balls = readPocket(sb1, BAG_BALLS_OFFSET, BAG_BALLS_COUNT),
      tmHm = readPocket(sb1, BAG_TMHM_OFFSET, BAG_TMHM_COUNT),
      berries = readPocket(sb1, BAG_BERRIES_OFFSET, BAG_BERRIES_COUNT),
    },
    trainer = {
      money = money,
      badges = badgeCount,
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
