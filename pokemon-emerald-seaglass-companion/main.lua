-- Pokemon Emerald Seaglass (BPEE, v3.0) companion pack.
--
-- Seaglass is built on pokeemerald-expansion: the Pokemon, move and item tables are repacked and the
-- game code is still BPEE, so the Emerald pack's addresses read garbage. The ROM tables below were found
-- against the v3.0 ROM (CRC32 14465a33, SHA-1 b9f4d332...) and are checked at load: if they don't decode,
-- the screen says so instead of showing wrong numbers.
--
-- The save-block pointers live in IWRAM at build-specific addresses, so they are found at runtime: every
-- IWRAM word that points into EWRAM is a candidate, and the right one is proven by decrypting its party
-- (vanilla mon crypto: key = personality ^ otId, order = personality % 24, checksum over 24 u16). The live
-- party is a separate array elsewhere in EWRAM, found the same way and preferred over SaveBlock1's copy,
-- which only matches the last save.
--
-- File map, top to bottom:
--   ROM tables      the four address blocks below, and the Gen 3 text decoder
--   look-ups        cached name/stat readers for species, moves, items and abilities
--   sprites         gfx.decode of the front pic + palette, with a graceful fallback
--   monAt           decrypts one 100-byte party struct and validates its checksum
--   save blocks     the IWRAM pointer scan, SaveBlock1/2 validation, live-party scan
--   bag, badges     pocket walk and flag bits
--   page builders   the flat tables the layout binds to (no formatting in CSS)
--   update(ui)      one tick: everything above, turned into one return value

local GAME = "BPEE"

-- ---- ROM tables (Seaglass v3.0) ----------------------------------------------------------
local SPECIES_NAME1   = 0x088F087C  -- gSpeciesInfo[1].speciesName; the struct starts 0x2C earlier
local SPECIES_STRIDE  = 0xD0
local SPECIES_BASE    = SPECIES_NAME1 - 0x2C
local MOVE_INFO1      = 0x086D2A18   -- gMovesInfo[1]: name ptr +0, desc ptr +4, packed data +0x0A, pp +0x0E
local MOVE_STRIDE     = 0x38
local ITEM_NAME0      = 0x0867E77C   -- gItemsInfo[i].name (inline, 14 bytes) at +i*0x54
local ITEM_STRIDE     = 0x54
local ITEM_DESC_SHIFT = 0x08         -- description pointer sits 8 bytes before the name
local ABILITY_NAME0   = 0x086E15B0
local ABILITY_STRIDE  = 0x1C

-- ---- SaveBlock1 (verified against a real Seaglass 3.0 save) ------------------------------
local SB1_PARTY_COUNT = 0x234
local SB1_PARTY       = 0x238
local SB1_MONEY       = 0x490
local SB1_COINS       = 0x494
local SB1_FLAGS       = 0x1270
local SB1_SIZE        = 0x3E00
-- Seaglass reshaped the bag: 80 items, 40 key items, 20 balls, 46 TMs/HMs. That is 186 slots and
-- they sit shoulder to shoulder from 0x560 to 0x848, which is how the boundaries below were confirmed
-- (an item, a key item, a ball and a TM each land exactly on the first slot of their pocket).
local BAG_POCKETS = {
  { key = "items",    label = "ITEMS",    offset = 0x560, slots = 80, count = true },
  { key = "balls",    label = "BALLS",    offset = 0x740, slots = 20, count = true },
  { key = "tmHm",     label = "TM/HM",    offset = 0x790, slots = 46, count = true },
  { key = "keyItems", label = "KEY",      offset = 0x6A0, slots = 40, count = false },
}
-- SaveBlock2
local SB2_NAME = 0x00
local SB2_TRAINER_ID = 0x0A
local SB2_HOURS, SB2_MINUTES = 0x0E, 0x10
local SB2_KEY = 0xAC

local MON_SIZE = 0x64
local PARTY_MAX = 6
local NUM_SPECIES = 386
local FLAG_BADGE01 = 0x867

-- ---- look-up tables ----------------------------------------------------------------------
-- Type ids are the classic Gen 3 order shifted by one (expansion adds TYPE_NONE = 0), and 19 = Fairy.
local TYPES = {
  [0] = { "???", "#68A090" },
  { "NORMAL", "#A8A878" }, { "FIGHTING", "#C03028" }, { "FLYING", "#A890F0" }, { "POISON", "#A040A0" },
  { "GROUND", "#E0C068" }, { "ROCK", "#B8A038" }, { "BUG", "#A8B820" }, { "GHOST", "#705898" },
  { "STEEL", "#B8B8D0" }, { "???", "#68A090" }, { "FIRE", "#F08030" }, { "WATER", "#6890F0" },
  { "GRASS", "#78C850" }, { "ELECTRIC", "#F8D030" }, { "PSYCHIC", "#F85888" }, { "ICE", "#98D8D8" },
  { "DRAGON", "#7038F8" }, { "DARK", "#705848" }, { "FAIRY", "#EE99AC" },
}
local NATURES = { "HARDY", "LONELY", "BRAVE", "ADAMANT", "NAUGHTY", "BOLD", "DOCILE", "RELAXED",
  "IMPISH", "LAX", "TIMID", "HASTY", "SERIOUS", "JOLLY", "NAIVE", "MODEST", "MILD", "QUIET",
  "BASHFUL", "RASH", "CALM", "GENTLE", "SASSY", "CAREFUL", "QUIRKY" }
local ORDERS = { "GAEM", "GAME", "GEAM", "GEMA", "GMAE", "GMEA", "AGEM", "AGME", "AEGM", "AEMG",
  "AMGE", "AMEG", "EGAM", "EGMA", "EAGM", "EAMG", "EMGA", "EMAG", "MGAE", "MGEA", "MAGE", "MAEG",
  "MEGA", "MEAG" }
local STAT_LABELS = { "HP", "ATTACK", "DEFENSE", "SP. ATK", "SP. DEF", "SPEED" }
local STAT_ORDER = { 1, 2, 3, 5, 6, 4 }   -- display order HP, Atk, Def, SpA, SpD, Spe into stored HP, Atk, Def, Spe, SpA, SpD

-- ---- state -----------------------------------------------------------------------------
local S = { sb1 = nil, sb2 = nil, partyAddr = nil, partySource = "NONE", romOk = nil,
  spriteMode = "?", scanChunk = 0, found = false, lastMoney = nil }

-- ---- text ------------------------------------------------------------------------------
local CHR = { [0x00] = " ", [0xAE] = "-", [0xAD] = ".", [0xBA] = "/", [0xAB] = "!", [0xAC] = "?",
  [0xB4] = "'", [0x1B] = "\195\169", [0xFE] = " ", [0xB0] = "\194\183" }

-- The Gen 3 charmap: 0xA1-0xAA digits, 0xBB-0xD4 A-Z, 0xD5-0xEE a-z, plus the few punctuation codes in
-- CHR. Unknown codes become an empty string, so one stray byte cannot break a whole name.
local function decodeChar(c)
  if c >= 0xA1 and c <= 0xAA then return string.char(48 + c - 0xA1) end
  if c >= 0xBB and c <= 0xD4 then return string.char(65 + c - 0xBB) end
  if c >= 0xD5 and c <= 0xEE then return string.char(97 + c - 0xD5) end
  return CHR[c] or ""
end

-- Names and descriptions end with 0xFF. maxLen only stops a runaway read when a pointer is wrong.
local function readString(addr, maxLen)
  local out = {}
  for i = 0, maxLen - 1 do
    local c = mem.u8(addr + i)
    if c == 0xFF then break end
    out[#out + 1] = decodeChar(c)
  end
  return table.concat(out)
end

-- ROM strings are read once and kept: the same species/move/item name is asked for on every tick.
local romText = {}
local function rom(addr, len)
  local s = romText[addr]
  if not s then
    s = readString(addr, len)
    romText[addr] = s
  end
  return s
end

-- Name pointers come straight out of ROM tables, so they are checked before use: anything outside the
-- cart's 0x08000000-0x09FFFFFF window means the table offset is wrong and the caller shows nothing.
local function romPtr(tableAddr, index, maxLen)
  local p = mem.u32(tableAddr + index * 4)
  if p < 0x08000000 or p >= 0x0A000000 then return "" end
  return rom(p, maxLen)
end

local function speciesName(sp) return rom(SPECIES_NAME1 + (sp - 1) * SPECIES_STRIDE, 11) end
local function moveName(id)
  local p = mem.u32(MOVE_INFO1 + (id - 1) * MOVE_STRIDE)
  if p < 0x08000000 or p >= 0x0A000000 then return "MOVE " .. id end
  return rom(p, 14)
end
local function moveDesc(id)
  local p = mem.u32(MOVE_INFO1 + (id - 1) * MOVE_STRIDE + 4)
  if p < 0x08000000 or p >= 0x0A000000 then return "" end
  return rom(p, 100)
end
local function itemName(id)
  if id == 0 then return "" end
  local n = rom(ITEM_NAME0 + id * ITEM_STRIDE, 14)
  if n == "" then return "ITEM " .. id end
  return n
end
local function itemDesc(id)
  local p = mem.u32(ITEM_NAME0 + id * ITEM_STRIDE - ITEM_DESC_SHIFT)
  if p < 0x08000000 or p >= 0x0A000000 then return "" end
  return rom(p, 120)
end
local function abilityName(id)
  if id == 0 then return "-" end
  local n = rom(ABILITY_NAME0 + id * ABILITY_STRIDE, 14)
  if n == "" then return "ABILITY " .. id end
  return n
end

-- ---- species ----------------------------------------------------------------------------
-- One gSpeciesInfo entry, decoded once per species and cached. Offsets are the Seaglass v3.0 layout;
-- stats are stored HP, Atk, Def, Spe, SpA, SpD (STAT_ORDER maps them to the order the page shows).
local speciesCache = {}
local function species(sp)
  local c = speciesCache[sp]
  if c then return c end
  local b = SPECIES_BASE + (sp - 1) * SPECIES_STRIDE
  local stats = { mem.u8(b), mem.u8(b + 1), mem.u8(b + 2), mem.u8(b + 4), mem.u8(b + 5), mem.u8(b + 3) }
  local info = {
    name = speciesName(sp),
    stats = stats,
    t1 = mem.u8(b + 6),
    t2 = mem.u8(b + 7),
    gender = mem.u8(b + 0x12),
    growth = mem.u8(b + 0x15),
    abilities = { mem.u16(b + 0x18), mem.u16(b + 0x1A) },
    category = rom(b + 0x1F, 13),
    height = mem.u16(b + 0x3E),
    weight = mem.u16(b + 0x40),
    descPtr = mem.u32(b + 0x4C),
    front = mem.u32(b + 0x58),
    pal = mem.u32(b + 0x68),
  }
  speciesCache[sp] = info
  return info
end

local function dexDesc(sp)
  local info = species(sp)
  local p = info.descPtr
  if p < 0x08000000 or p >= 0x0A000000 then return "" end
  return rom(p, 220)
end

-- Gender ratio: 0 is always male, 254 always female, 255 genderless; otherwise female when the low
-- byte of the personality value is below the ratio.
local function maleFemale(sp, pv)
  local r = species(sp).gender
  if r == 255 then return false, false end
  if r == 254 then return false, true end
  if r == 0 then return true, false end
  if (pv & 0xFF) < r then return false, true end
  return true, false
end

-- Monotypes repeat the same id in both fields, so the duplicate is dropped and the layout draws one chip.
local function typeList(t1, t2)
  local out = {}
  local a = TYPES[t1] or TYPES[0]
  out[1] = { label = a[1], color = a[2] }
  if t2 and t2 ~= t1 then
    local b = TYPES[t2] or TYPES[0]
    out[2] = { label = b[1], color = b[2] }
  end
  return out
end

-- ---- sprites (drawn from the player's ROM; nothing is shipped) ---------------------------
local spriteCache = {}
local function sprite(sp)
  if sp < 1 or sp > NUM_SPECIES then return "" end
  local c = spriteCache[sp]
  if c ~= nil then return c end
  local info = species(sp)
  local ok, key = pcall(gfx.decode, {
    tiles = info.front, palette = info.pal, width = 64, height = 64, lz77 = true,
  })
  if ok and key then
    spriteCache[sp] = key
    S.spriteMode = "ROM"
    return key
  end
  spriteCache[sp] = ""
  S.spriteMode = "FALLBACK"
  if not S.spriteError then S.spriteError = tostring(key) end
  return ""
end

-- ---- Pokemon ------------------------------------------------------------------------------
local function monAt(base)
  if base < 0x02000000 or base >= 0x02040000 then return nil end
  local pv, otid = mem.u32(base), mem.u32(base + 4)
  local key = pv ~ otid                 -- every encrypted field below is XORed with this
  local stored = mem.u16(base + 0x1C)
  local sum = 0
  local sub = {}
  for slot = 0, 3 do
    local w = {}
    for i = 0, 2 do
      local v = mem.u32(base + 0x20 + slot * 12 + i * 4) ~ key
      w[i] = v
      sum = sum + (v & 0xFFFF) + (v >> 16)
    end
    sub[slot] = w
  end
  -- The 48 encrypted bytes are four 12-byte substructs; their checksum is the sum of every u16 in them.
  -- A bad sum means this address is not a Pokémon, which is how the RAM scans below reject junk.
  if (sum & 0xFFFF) ~= stored then return nil end

  -- personality % 24 picks the substruct order; ORDERS spells those out (G growth, A attacks, E EVs, M misc).
  local order = ORDERS[pv % 24 + 1]
  local byLetter = {}
  for slot = 0, 3 do byLetter[order:sub(slot + 1, slot + 1)] = sub[slot] end
  local G, A, E, M = byLetter.G, byLetter.A, byLetter.E, byLetter.M
  if not (G and A and E and M) then return nil end

  local sp = G[0] & 0x7FF
  if sp < 1 or sp > NUM_SPECIES then return nil end
  local info = species(sp)
  if info.name == "" then return nil end

  local level = mem.u8(base + 0x54)
  if level < 1 or level > 100 then return nil end
  local hp, maxHp = mem.u16(base + 0x56), mem.u16(base + 0x58)
  if maxHp == 0 or hp > maxHp or maxHp > 999 then return nil end

  local ppBonus = G[2] & 0xFF
  local ivWord = M[1]
  -- Four move ids (11 bits each), their current PP, and the PP-bonus bits that raise each max.
  local moves = {}
  for m = 0, 3 do
    local id = m < 2 and (A[0] >> (m * 16)) & 0xFFFF or (A[1] >> ((m - 2) * 16)) & 0xFFFF
    id = id & 0x7FF
    local ppNow = (A[2] >> (m * 8)) & 0xFF
    if id ~= 0 then
      local md = MOVE_INFO1 + (id - 1) * MOVE_STRIDE
      local w = mem.u32(md + 0x0A)
      local maxPP = mem.u8(md + 0x0E)
      local bonus = (ppBonus >> (m * 2)) & 3
      maxPP = maxPP + maxPP * bonus // 5
      moves[#moves + 1] = {
        name = moveName(id),
        label = (TYPES[w & 0x1F] or TYPES[0])[1],
        color = (TYPES[w & 0x1F] or TYPES[0])[2],
        power = ((w >> 9) & 0x7F) * 4,
        acc = (w >> 16) & 0xFF,
        pp = ppNow, maxPP = maxPP,
        ppPct = maxPP > 0 and ppNow / maxPP or 0,
        ppLow = maxPP > 0 and ppNow / maxPP <= 0.25,
        desc = moveDesc(id),
      }
    end
  end

  local evs = {}
  for i = 0, 5 do evs[i] = (E[1] >> (i * 8)) & 0xFF end
  local male, female = maleFemale(sp, pv)

  return {
    species = sp, pv = pv, level = level, hp = hp, maxHp = maxHp,
    hpPct = maxHp > 0 and hp / maxHp or 0,
    atk = mem.u16(base + 0x5A), def = mem.u16(base + 0x5C), spe = mem.u16(base + 0x5E),
    spa = mem.u16(base + 0x60), spd = mem.u16(base + 0x62),
    status = mem.u32(base + 0x50),
    ivs = { ivWord & 31, (ivWord >> 5) & 31, (ivWord >> 10) & 31, (ivWord >> 20) & 31,
      (ivWord >> 25) & 31, (ivWord >> 15) & 31 },
    evs = evs,
    abilitySlot = (ivWord >> 31) & 1,
    friendship = (G[2] >> 8) & 0xFF,
    exp = G[1],
    heldItem = itemName(G[0] >> 16 & 0x3FF),
    moves = moves,
    male = male, female = female,
    nature = NATURES[pv % 25 + 1],
  }
end

-- Up to six mons; the first invalid slot ends the party (the game keeps the count elsewhere).
local function partyAt(base)
  local out = {}
  for i = 0, PARTY_MAX - 1 do
    local m = monAt(base + i * MON_SIZE)
    if not m then break end
    out[#out + 1] = m
  end
  return out
end

-- Status is a bitfield; the first set bit is the one worth showing.
local function statusTag(st)
  if st & 0x07 ~= 0 then return "SLP" end
  if st & 0x08 ~= 0 then return "PSN" end
  if st & 0x10 ~= 0 then return "BRN" end
  if st & 0x20 ~= 0 then return "FRZ" end
  if st & 0x40 ~= 0 then return "PAR" end
  if st & 0x80 ~= 0 then return "TOX" end
  return ""
end

-- HP fraction plus the three class flags the stylesheet colours the bars with.
local function bands(hp, maxHp)
  local pct = maxHp > 0 and hp / maxHp or 0
  return pct, pct > 0.5, pct <= 0.5 and pct > 0.2, pct <= 0.2
end

-- 53224 -> "53,224", for the header and the trainer card.
local function withCommas(n)
  local s = tostring(n)
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  if out:sub(1, 1) == "," then out = out:sub(2) end
  return out
end

-- ---- SaveBlock discovery -----------------------------------------------------------------
local function wordAt(s, i)   -- 1-based byte index into a mem.read string
  local a, b, c, d = s:byte(i, i + 3)
  if not a then return 0 end
  return a + b * 256 + c * 65536 + d * 16777216
end

-- SaveBlock1 is proven by its party: every mon in it must decrypt and pass its checksum. With an empty
-- party there is nothing to check, so two always-sane header fields stand in.
local function validSave1(p)
  if p < 0x02000000 or p >= 0x02040000 then return false end
  local count = mem.u8(p + SB1_PARTY_COUNT)
  if count > PARTY_MAX then return false end
  if count > 0 then
    for i = 0, count - 1 do
      if not monAt(p + SB1_PARTY + i * MON_SIZE) then return false end
    end
    return true
  end
  local group = mem.u8(p + 4)
  local layoutId = mem.u16(p + 0x32)
  return group < 64 and layoutId < 4096
end

-- SaveBlock2 is proven by the trainer name being text, the gender byte, a sane clock, and money that
-- lands under 10 million once XORed with the key stored in this block.
local function validSave2(q, sb1)
  if q < 0x02000000 or q >= 0x02040000 then return false end
  local first = mem.u8(q)
  if first == 0 or first == 0xFF then return false end
  if mem.u8(q + 8) > 1 then return false end
  if mem.u16(q + SB2_HOURS) > 2000 then return false end
  local key = mem.u32(q + SB2_KEY)
  local money = mem.u32(sb1 + SB1_MONEY) ~ key
  if money > 9999999 then return false end
  return true
end

-- Every word of IWRAM that points into EWRAM is a candidate; the first pair that validates wins.
local function findBlocks()
  local iwram = mem.read(0x03000000, 0x8000)
  if not iwram then return false end
  local cands, seen = {}, {}
  for i = 1, #iwram - 3, 4 do
    local v = wordAt(iwram, i)
    if v >= 0x02000000 and v < 0x02040000 and not seen[v] then
      seen[v] = true
      cands[#cands + 1] = v
    end
  end
  for _, p in ipairs(cands) do
    if validSave1(p) then
      for _, q in ipairs(cands) do
        if q ~= p and validSave2(q, p) then
          S.sb1, S.sb2 = p, q
          S.partyAddr = nil
          S.partySource = "SCANNING"
          S.scanChunk = 0
          return true
        end
      end
    end
  end
  return false
end

-- Re-checked every tick: a different save (or a soft reset) invalidates the addresses cached last tick.
local function blocksStillValid()
  if not S.sb1 or not S.sb2 then return false end
  local count = mem.u8(S.sb1 + SB1_PARTY_COUNT)
  if count > PARTY_MAX then return false end
  if count > 0 and not monAt(S.sb1 + SB1_PARTY) then return false end
  return validSave2(S.sb2, S.sb1)
end

-- The live party is a separate EWRAM array; SaveBlock1's copy only matches the last save. One 64 KB
-- slice per update keeps the call inside the 25 ms budget.
local function scanParty()
  if not S.sb1 then return end
  local lead = monAt(S.sb1 + SB1_PARTY)
  if not lead then return end
  if S.scanChunk > 3 then
    S.partySource = S.partyAddr and "LIVE" or "SAVE BLOCK"
    return
  end
  local base = 0x02000000 + S.scanChunk * 0x10000
  local chunk = mem.read(base, 0x10000)
  S.scanChunk = S.scanChunk + 1
  if not chunk then return end
  local i = 1
  while i <= #chunk - MON_SIZE do
    local a = base + i - 1
    if a % 4 == 0 and not (a >= S.sb1 and a < S.sb1 + SB1_SIZE) then
      local lv = chunk:byte(i + 0x54)
      if lv and lv >= 1 and lv <= 100 and lv == lead.level then
        local m = monAt(a)
        if m and m.species == lead.species then
          -- A party starts at its first mon, so the slot before it must not be a valid mon. That rejects
          -- SaveBlock1's copy of the party and any match in the middle of an array.
          local prevBase = a - MON_SIZE
          local prevOk = prevBase >= base and monAt(prevBase) ~= nil
          if not prevOk then
            S.partyAddr = a
            S.partySource = "LIVE"
            return
          end
        end
      end
    end
    i = i + 4
  end
end

local function currentParty()
  if S.partyAddr and monAt(S.partyAddr) then return partyAt(S.partyAddr) end
  if S.sb1 then return partyAt(S.sb1 + SB1_PARTY) end
  return {}
end

-- ---- bag ------------------------------------------------------------------------------------
local function readBag()
  local key = mem.u32(S.sb2 + SB2_KEY) & 0xFFFF
  local bag, used, total = {}, 0, 0
  for _, p in ipairs(BAG_POCKETS) do
    local list = {}
    for i = 0, p.slots - 1 do
      local a = S.sb1 + p.offset + i * 4
      local id = mem.u16(a)
      if id ~= 0 then                      -- 0 marks an empty slot, it is not item 0
        local qty = mem.u16(a + 2) ~ key   -- quantities are XORed with the low half of the save key
        if qty > 0 then
          list[#list + 1] = { name = itemName(id), count = p.count and ("x" .. qty) or "", desc = itemDesc(id) }
          used = used + 1
          if p.count then total = total + qty end
        end
      end
    end
    bag[p.key] = list
  end
  bag.used, bag.total = used, total
  bag.capacity = 186
  bag.isEmpty = used == 0
  bag.first = bag.items[1]
  return bag
end

-- ---- badges ---------------------------------------------------------------------------------
-- Badges are bits in SaveBlock1's flag array: flag N is bit N % 8 of byte N // 8.
local function readBadges()
  local out, count = {}, 0
  for i = 0, 7 do
    local flag = FLAG_BADGE01 + i
    local on = (mem.u8(S.sb1 + SB1_FLAGS + flag // 8) >> (flag % 8)) & 1 == 1
    if on then count = count + 1 end
    out[#out + 1] = { src = "asset:ui/badge" .. (i + 1) .. ".png", locked = not on }
  end
  return out, count
end

-- ---- party rows -----------------------------------------------------------------------------
-- One party row, already formatted: the layout binds these values and computes nothing.
local function monRow(m, idx)
  local pct, high, mid, low = bands(m.hp, m.maxHp)
  local tag = statusTag(m.status)
  local info = species(m.species)
  return {
    idx = tostring(idx), species = tostring(m.species),
    name = info.name, level = tostring(m.level),
    dexno = string.format("%03d", m.species),
    sprite = sprite(m.species),
    types = typeList(info.t1, info.t2),
    hpPct = pct, hpHigh = high, hpMid = mid, hpLow = low,
    hpText = m.hp .. "/" .. m.maxHp,
    status = tag, hasStatus = tag ~= "",
    male = m.male, female = m.female,
    heldItem = m.heldItem ~= "" and m.heldItem or "-",
    itemNone = m.heldItem == "",
  }
end

-- The Detail page: six stat rows (value, EV, base) and four move slots, padded with dashes so the layout
-- always has exactly four rows to draw.
local function detailOf(m)
  if not m then return { empty = true } end
  local info = species(m.species)
  local stats = {}
  local values = { m.hp, m.atk, m.def, m.spa, m.spd, m.spe }
  local evOrder = { 0, 1, 2, 4, 5, 3 }
  for i, idx in ipairs(STAT_ORDER) do
    local base = info.stats[idx]
    stats[i] = {
      label = STAT_LABELS[i], value = tostring(values[i]),
      pct = math.min(1, values[i] / 300),
      ev = tostring(m.evs[evOrder[i]]),
      base = tostring(base),
    }
  end
  local moves = {}
  for i = 1, 4 do
    local mv = m.moves[i]
    if mv then
      moves[#moves + 1] = {
        name = mv.name, label = mv.label, color = mv.color,
        power = mv.power > 0 and tostring(mv.power) or "--",
        acc = mv.acc > 0 and tostring(mv.acc) or "--",
        pp = mv.pp .. "/" .. mv.maxPP, ppPct = mv.ppPct, ppLow = mv.ppLow,
      }
    else
      moves[#moves + 1] = { name = "-", label = "-", color = "#68A090", power = "--", acc = "--",
        pp = "--", ppPct = 0, ppLow = false }
    end
  end
  return {
    empty = false,
    name = info.name, level = tostring(m.level), dexno = string.format("%03d", m.species),
    sprite = sprite(m.species), types = typeList(info.t1, info.t2),
    male = m.male, female = m.female,
    hpText = m.hp .. "/" .. m.maxHp,
    hpPct = m.hp / m.maxHp, hpHigh = m.hp / m.maxHp > 0.5,
    hpMid = m.hp / m.maxHp <= 0.5 and m.hp / m.maxHp > 0.2,
    hpLow = m.hp / m.maxHp <= 0.2,
    status = statusTag(m.status), hasStatus = statusTag(m.status) ~= "",
    stats = stats, moves = moves,
    ability = abilityName(info.abilities[m.abilitySlot + 1]),
    nature = m.nature,
    heldItem = m.heldItem ~= "" and m.heldItem or "-",
    exp = tostring(m.exp),
    category = info.category ~= "" and (info.category:upper() .. " POK\195\169MON") or "-",
    height = string.format("%d.%dm", info.height // 10, info.height % 10),
    weight = string.format("%d.%dkg", info.weight // 10, info.weight % 10),
    dexText = dexDesc(m.species),
    friendship = tostring(m.friendship),
  }
end

-- ---- dex browser -----------------------------------------------------------------------------
local DEX_PAGE = 6
local dexStart = 1
local dexSel = 1
actions = actions or {}

local function clampSel(n)
  n = tonumber(n)
  if not n or n < 1 then n = 1 end
  if n > NUM_SPECIES then n = NUM_SPECIES end
  return math.floor(n)
end

local function dexTurn(delta)
  local pages = (NUM_SPECIES + DEX_PAGE - 1) // DEX_PAGE
  local page = ((dexStart - 1) // DEX_PAGE + delta) % pages
  dexStart = page * DEX_PAGE + 1
end

-- Taps from layout.json land on actions.*; each only changes state, and update() rebuilds the page.
function actions.dexNext() dexTurn(1) end
function actions.dexPrev() dexTurn(-1) end

function actions.dexSelect(n) dexSel = clampSel(n) end

-- The Dex page is a browser over all 386 species, six per page. There are no seen/caught flags: Seaglass
-- moved them somewhere unconfirmed, and a made-up list would be worse than none. Tapping a row shows it.
local function readDex()
  local entries = {}
  local last = math.min(NUM_SPECIES, dexStart + DEX_PAGE - 1)
  for sp = dexStart, last do
    local info = species(sp)
    entries[#entries + 1] = {
      no = string.format("%03d", sp), species = tostring(sp),
      name = info.name, sprite = sprite(sp),
      types = typeList(info.t1, info.t2),
    }
  end
  local sp = dexSel
  local info = species(sp)
  local stats = {}
  for i, idx in ipairs(STAT_ORDER) do
    stats[i] = { label = STAT_LABELS[i], value = tostring(info.stats[idx]),
      pct = math.min(1, info.stats[idx] / 150) }
  end
  local abil = abilityName(info.abilities[1])
  if info.abilities[2] ~= 0 and info.abilities[2] ~= info.abilities[1] then
    abil = abil .. " / " .. abilityName(info.abilities[2])
  end
  return {
    entries = entries,
    range = string.format("%03d-%03d", dexStart, last),
    sel = {
      no = string.format("%03d", sp), name = info.name, sprite = sprite(sp),
      types = typeList(info.t1, info.t2), stats = stats,
      abilities = abil,
      category = info.category ~= "" and (info.category:upper() .. " POK\195\169MON") or "-",
      height = string.format("%d.%dm", info.height // 10, info.height % 10),
      weight = string.format("%d.%dkg", info.weight // 10, info.weight % 10),
      desc = dexDesc(sp),
      total = tostring(info.stats[1] + info.stats[2] + info.stats[3] + info.stats[4] + info.stats[5] + info.stats[6]),
    },
  }
end

-- ---- update ------------------------------------------------------------------------------------
local function waiting(reason)
  return { ready = false, waiting = true, waitNote = reason or "WAITING FOR A SAVE" }
end

-- Called tickHz times a second. Order matters: prove the ROM tables, find and re-validate the save
-- blocks, look for the live party, then build every page's data at once (the layout only binds values).
function update(ui)
  local code = mem.read(0x080000AC, 4)
  if code ~= GAME then return waiting("THIS PACK IS FOR POK\195\169MON EMERALD SEAGLASS") end
  if S.romOk == nil then
    S.romOk = speciesName(1) == "Bulbasaur" and speciesName(2) == "Ivysaur"
      and moveName(1) == "Pound" and itemName(1) ~= ""
  end
  if not S.romOk then return waiting("THIS SEAGLASS BUILD ISN'T MAPPED YET") end

  if not blocksStillValid() then
    S.sb1, S.sb2, S.partyAddr, S.partySource = nil, nil, nil, "NONE"
    if not findBlocks() then return waiting("NO SAVE LOADED YET") end
  end
  if not S.partyAddr then scanParty() end

  local key = mem.u32(S.sb2 + SB2_KEY)
  local money = mem.u32(S.sb1 + SB1_MONEY) ~ key
  local coins = mem.u16(S.sb1 + SB1_COINS) ~ (key & 0xFFFF)
  local hours = mem.u16(S.sb2 + SB2_HOURS)
  local minutes = mem.u8(S.sb2 + SB2_MINUTES)
  local badges, badgeCount = readBadges()
  local bag = readBag()
  bag.hasSel = ui ~= nil and ui.selName ~= nil and ui.selName ~= ""
  bag.noSel = not bag.hasSel
  bag.sel = {
    name = (ui and ui.selName) or "",
    desc = (ui and ui.selDesc) or "",
    count = (ui and ui.selCount) or "",
  }

  local party = currentParty()
  local rows, hp, maxHp, levels = {}, 0, 0, 0
  for i, m in ipairs(party) do
    rows[#rows + 1] = monRow(m, i)
    hp, maxHp, levels = hp + m.hp, maxHp + m.maxHp, levels + m.level
  end
  local pct, high, mid, low = bands(hp, maxHp)

  dexSel = clampSel((ui and ui.dexSel) or dexSel)

  local detailIndex = tonumber(ui and ui.detailIndex) or 1
  if detailIndex < 1 or detailIndex > #party then detailIndex = 1 end

  local out = {
    ready = true, waiting = false, waitNote = "NO SAVE LOADED YET",
    time = string.format("%d:%02d", hours, minutes),
    money = withCommas(money),
    coins = tostring(coins),
    trainer = {
      name = readString(S.sb2 + SB2_NAME, 7),
      id = string.format("%05d", mem.u16(S.sb2 + SB2_TRAINER_ID)),
      male = mem.u8(S.sb2 + 8) == 0,
      female = mem.u8(S.sb2 + 8) == 1,
    },
    badges = badges, badgeCount = tostring(badgeCount),
    party = rows,
    partyCount = tostring(#party),
    partyMax = tostring(PARTY_MAX),
    hasParty = #party > 0,
    noParty = #party == 0,
    team = { hp = tostring(hp), maxHp = tostring(maxHp), hpPct = pct, hpHigh = high,
      hpMid = mid, hpLow = low, avg = tostring(#party > 0 and levels // #party or 0) },
    detail = detailOf(party[detailIndex]),
    bag = bag,
    bagTotal = tostring(bag.total),
    dex = readDex(),
    diag = {
      rom = "BPEE / SEAGLASS v3.0",
      tables = "SPECIES, MOVES, ITEMS OK",
      sb1 = string.format("%08X", S.sb1),
      sb2 = string.format("%08X", S.sb2),
      partyAddr = S.partyAddr and string.format("%08X", S.partyAddr) or "-",
      partySource = S.partySource,
      sprite = S.spriteMode == "?" and "NOT DRAWN YET" or S.spriteMode,
      spriteError = S.spriteError or "-",
      money = tostring(money),
      lines = {
        { k = "SAVEBLOCK 1", v = string.format("%08X", S.sb1) },
        { k = "SAVEBLOCK 2", v = string.format("%08X", S.sb2) },
        { k = "PARTY SOURCE", v = S.partySource },
        { k = "LIVE PARTY", v = S.partyAddr and string.format("%08X", S.partyAddr) or "-" },
        { k = "PARTY", v = #party .. "/" .. PARTY_MAX },
        { k = "BAG SLOTS", v = tostring(bag.used) },
        { k = "SPRITES", v = S.spriteMode },
        { k = "SPRITE ERR", v = tostring(S.spriteError or "-") },
        { k = "BADGES", v = tostring(badgeCount) .. "/8" },
      },
    },
  }
  return out
end
