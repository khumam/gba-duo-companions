-- Breath of Fire (USA, ABFE) companion: main.lua
-- Names come from the player's ROM at runtime (the game's own name tables); portraits are
-- drawn from the ROM's menu portrait sheet. Addresses and how each was checked: NOTES.md.

local GAME_CODE = mem.read(0x080000AC, 4)

local A = {
  ABFE = {
    inGame   = 0x03000843, -- u8: 3 in a game (new or loaded), 0 on title / file select / naming / intro
    gold     = 0x0202DBF0, -- u32
    bag      = 0x0202DDD4, bagSlots = 64, -- 64 x (id u8, kind<<4 | count); ends where mapId starts
    vitalCount = 0x0202E06A, vital = 0x0202E06C, vitalSlots = 14, -- VITL list: n x (id u8, 01)
    vault = 0x0202DE92, vaultSlots = 124, -- item store: same pairs as the bag (list code 0x080600A8)
    bank  = 0x0202DBEC, -- u32 'In Bank' balance (bank screen 0x08060960 prints it beside gold)
    gobiSkills = 0x08150AC0, -- 4 x 12: name[8], X flag, ?, AP, 0 (Ebb EbbX Eco EcoX)
    fusions    = 0x08150AF0, -- 4 x 16: name[8], ?, ?, AP, ... (Shin Debo Doof Puka)
    digName    = 0x0814BDAE, -- 'Dig' (Mogu); its AP (5) is set in code, read off the SPEL screen
    weaponData = 0x08220B00, armorData = 0x0821F680, -- 16-byte records: +4 kind, +8 equip mask, +11 ATK/DEF
    messages = 0x08117DD4, -- message pointer table (item detail lines live here)
    roster   = 0x0202DBF4, -- 8 x 0x3C character records (saved form)
    rosterId = 0x0202DE8A, -- 8 x u8: character id in each roster slot (0xFF none)
    order    = 0x0202E0C6, -- 8 x u8: character ids in the menu's order (first 4 = active)
    live     = 0x03002B98, -- 4 x 0x124: live records of roster slots 0-3 (same first 0x3C bytes)
    flags    = 0x0202E00E, -- event flags, bit (n & 7) of byte n >> 3
    expTable = 0x081E3ED4, -- 3-byte EXP for the next level, 98 per character id
    inBattle = 0x03000AFC, -- u8: 1 during a battle
    mapId    = 0x0202DE54, -- u16 current map (0 = world map)
    mapPlace = 0x0814BF53, -- u8 per map id: index into the place-name table
    placeNames = 0x0814F114, placeCount = 64,
    night    = 0x0202DE5A, -- u8: 1 at night
    spellNames = 0x08150468, spellCount = 80,
    spellHelp  = 0x0814ED6C, spellHelpCount = 88,
    spellIcons = 0x081011E2,   -- u8 icon index per spell id
    spellPool  = 0x082D262E,   -- [count, ids...] for Bo, Nina, Bleu, Ox, then 0xFF
    spellLevels = { [2] = 0x082D385D, [7] = 0x082D3875 },   -- learn levels (Nina, Bleu); Bo and Ox know theirs from the start
    dragons  = 0x08150A30, -- 9 x 16-byte records (name 8 B); form k is learned when event flag 20 + k is set
    monsterNames = 0x0814E47C, monsterCount = 128,
    monsters = 0x082D169B,  -- 31-byte records: +6 max HP u16, +10 Lv, +12 ATK/2, +13 DEF/2, +14 AGI
    enemies  = 0x03003508, -- 8 x 0x124 battle records (name 8 B, +0x0A lv, +0x0C max HP, +0x0E HP, +0x78 monster id)
    -- ROM name tables: u32 pointers to 0-terminated strings
    itemNames   = 0x0814F530, itemCount   = 128,
    weaponNames = 0x0814F9D0, weaponCount = 96,
    armorNames  = 0x0814FF50, armorCount  = 142,
    -- menu portrait sheet: 4bpp, 32 tiles per row; portrait = 4x4 tiles at (block R, column c)
    portraitTiles = 0x08240068,
    -- 8x8 icons: per-kind byte tables give an icon index; icon i = tile (i % 32) of row (i // 32)
    -- in the sheet below (rows 0x400 apart, as the game copies it to OBJ VRAM tile 960)
    iconTiles   = 0x0823EE68, iconPal = 0x0814BAD4,
    iconWeapon  = 0x08100F74, iconArmor = 0x08100FD4, iconItem = 0x08101062,
  },
}
local M = A[GAME_CODE]

-- Portraits by character id: { tile row, column } in the sheet; palette = 0x081505A8 + 32 * id.
-- Nina switches to her later portrait (row 8, col 7, palette 11) once event flag 0x1D is set,
-- exactly as the game's own routine at 0x08067CD4 does.
local PAL0 = 0x081505A8
local PORTRAIT = {
  [0] = { 4, 4 }, [1] = { 4, 5 }, [2] = { 4, 6 }, [3] = { 4, 7 },
  [4] = { 5, 0 }, [5] = { 5, 1 }, [6] = { 5, 2 }, [7] = { 5, 3 },
  [8] = { 8, 4 }, [9] = { 8, 4 },
}
local CHAR_NAMES = { [0] = "Ryu", "Bo", "Nina", "Ox", "Gobi", "Karn", "Mogu", "Bleu" }

------------------------------------------------------------------------------
-- Text (the game's own encoding)
------------------------------------------------------------------------------
local function glyph(b)
  if b >= 0x2A and b <= 0x43 then return string.char(b + 0x17) end -- A-Z
  if b >= 0x48 and b <= 0x61 then return string.char(b + 0x19) end -- a-z
  if b >= 0x20 and b <= 0x29 then return string.char(b + 0x10) end -- 0-9
  if b == 0x02 or b == 0x03 then return " " end
  if b == 0xEF then return "." end
  if b == 0xF0 then return "-" end
  if b == 0x46 then return "?" end
  if b == 0x45 then return "!" end
  return ""
end

local function decode(raw)
  local out = {}
  for i = 1, #raw do
    local b = raw:byte(i)
    if b == 0 then break end
    out[#out + 1] = glyph(b)
  end
  return table.concat(out)
end

-- Item detail lines: message index per item id, read off the game's own VITL
-- details screen for every id (NOTES.md, P10). Rods (79-82) only show a name variable: left out.
local ITEM_MSG = { [8]=1536, [9]=1536, [10]=1606, [11]=1555, [12]=1634, [13]=1538, [14]=1543, [15]=1552, [16]=1592, [17]=1592, [18]=1593, [19]=1624, [20]=1638, [21]=1638, [22]=1638, [23]=1638, [24]=1638, [25]=1536, [26]=1596, [27]=1606, [28]=1595, [29]=1605, [30]=1624, [31]=1595, [32]=1697, [33]=1697, [34]=1697, [35]=1697, [36]=1697, [37]=1595, [38]=1697, [39]=1603, [40]=1600, [41]=1601, [42]=1598, [43]=1624, [44]=1547, [45]=1603, [46]=1545, [47]=1624, [48]=1700, [49]=1597, [50]=1610, [51]=1612, [52]=1614, [53]=1624, [54]=1624, [55]=1624, [56]=1624, [57]=1607, [58]=1624, [59]=1625, [60]=1706, [61]=1627, [62]=1628, [63]=1624, [64]=1624, [65]=1630, [66]=1632, [67]=1545, [68]=1545, [69]=1633, [70]=1707, [71]=1536, [72]=1606, [73]=1536, [74]=1617, [75]=1639, [76]=1639, [77]=1639, [78]=1640, [83]=1599, [84]=1643, [85]=1647, [86]=1624, [87]=1649, [88]=1650, [89]=1651, [90]=1652, [91]=1653, [92]=1654, [93]=1602, [94]=1684, [95]=1685, [96]=1779, [97]=1686, [98]=1698, [99]=1699, [100]=1616, [101]=1644, [102]=1603, [103]=1679, [104]=1626, [105]=1629, [106]=1545, [107]=1648, [108]=1545, [109]=1687, [110]=1688, [111]=1689, [112]=1624, [113]=1646, [114]=1778, [115]=1536, [116]=1789, [117]=1646, [118]=1646, [119]=1646, [120]=1555, [121]=1778, [122]=1536, [123]=1606, [124]=1538, [125]=1543, [126]=1552, [127]=1555 }

-- Message text: extra codes beyond names. 0x62 ' 0x63 , 0x65 " 0x67 & 0xF7 . ; 0x09 page;
-- 0x0A n = place name n.
local MSG_CHAR = { [0x62] = "'", [0x63] = ",", [0x65] = '"', [0x67] = "&", [0x09] = " ", [0xF7] = "." }
local placeByIndex  -- set once place names are loaded
local function msgText(idx)
  if not idx then return nil end
  local ptr = mem.u32(M.messages + 4 * idx)
  if ptr < 0x08000000 or ptr >= 0x08400000 then return nil end
  local raw = mem.read(ptr, 160)
  local out, i = {}, 1
  while i <= #raw do
    local b = raw:byte(i)
    if b == 0 then break end
    if b == 0x0A then
      out[#out + 1] = placeByIndex and placeByIndex(raw:byte(i + 1)) or ""
      i = i + 1
    elseif MSG_CHAR[b] then out[#out + 1] = MSG_CHAR[b]
    else out[#out + 1] = glyph(b) end
    i = i + 1
  end
  local t = table.concat(out):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
  return t ~= "" and t or nil
end

local function romString(ptr, n)
  if ptr < 0x08000000 or ptr >= 0x08400000 then return nil end
  return decode(mem.read(ptr, n or 16))
end

-- Name tables are read once at load (a few thousand bytes).
local NAMES = {}
local DRAGON_AP = {}
local function loadTable(base, count, len)
  local t = {}
  for i = 0, count - 1 do t[i] = romString(mem.u32(base + 4 * i), len) or "" end
  return t
end
if M then
  NAMES.item   = loadTable(M.itemNames, M.itemCount)
  NAMES.weapon = loadTable(M.weaponNames, M.weaponCount)
  NAMES.armor  = loadTable(M.armorNames, M.armorCount)
  NAMES.place  = loadTable(M.placeNames, M.placeCount)
  NAMES.monster = loadTable(M.monsterNames, M.monsterCount)
  NAMES.spell = loadTable(M.spellNames, M.spellCount)
  NAMES.spellHelp = loadTable(M.spellHelp, M.spellHelpCount, 48)
  NAMES.dragon, DRAGON_AP = {}, {}
  for k = 0, 8 do
    NAMES.dragon[k] = decode(mem.read(M.dragons + 16 * k, 8))
    DRAGON_AP[k] = mem.u8(M.dragons + 16 * k + 10)   -- AP the SPEL screen shows (SnoDr 7 ... GldDgn 40)
  end
  placeByIndex = function(n) return NAMES.place[n] or "" end
end

-- Second byte of a bag slot / gear slot: kind in the high nibble, count in the low nibble.
local KIND = { [0] = "item", [1] = "weapon", [2] = "armor" }
local ICON_TABLE = {}
if M then ICON_TABLE = { [0] = M.iconItem, [1] = M.iconWeapon, [2] = M.iconArmor } end

local iconCache = {}
local function icon(id, kindNibble)
  local t = ICON_TABLE[kindNibble]
  if not t then return nil end
  local i = mem.u8(t + id)
  if i == 0 then return nil end
  local key = iconCache[i]
  if key then return key end
  local ok, img = pcall(gfx.decode, { tiles = M.iconTiles + (i // 32) * 0x400 + (i % 32) * 32,
                                      palette = M.iconPal, width = 8, height = 8 })
  if ok and img then iconCache[i] = img; return img end
  return nil
end

-- Equipment data (weapons 96, armor 142 records of 16 bytes): +11 = ATK (weapon) or DEF (armor);
-- +8 = who may equip it, bit (7 - character id) CLEAR = allowed; armor +4: 0x44 body, 0x48 shield, 0x42 helm,
-- 0x41 accessory. Checked against every equipped piece in every save (NOTES.md, P11b).
local ARMOR_KIND = { [0x44] = "armor", [0x48] = "shield", [0x42] = "helmet", [0x41] = "accessory" }
local function gearInfo(id, kindNibble)
  local base = kindNibble == 1 and M.weaponData or (kindNibble == 2 and M.armorData) or nil
  if not base then return nil end
  local rec = mem.read(base + 16 * id, 12)
  local who = {}
  local mask = rec:byte(9)
  for c = 0, 7 do if (mask >> (7 - c)) & 1 == 0 then who[#who + 1] = CHAR_NAMES[c] end end
  return { power = rec:byte(12), weapon = kindNibble == 1,
           kind = kindNibble == 1 and "weapon" or (ARMOR_KIND[rec:byte(5)] or "armor"),
           who = #who == 8 and "everyone" or (#who == 0 and "nobody" or table.concat(who, ", ")) }
end
local function powerText(g)
  if not g or g.power == 0 then return "" end
  return (g.weapon and "ATK " or "DEF ") .. g.power
end

local function gearName(id, b)
  if b & 0x0F == 0 then return nil end
  local t = NAMES[KIND[b >> 4] or ""]
  local n = t and t[id]
  if not n or n == "" or n == "Dummy" then return nil end
  return n
end

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------
local function commas(n)
  local s = tostring(math.floor(n))
  return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function pct(v, m)
  if not m or m <= 0 then return 0 end
  local p = v / m
  if p < 0 then p = 0 elseif p > 1 then p = 1 end
  return p
end

local function flag(n)
  return (mem.u8(M.flags + (n >> 3)) >> (n & 7)) & 1 == 1
end

local function portrait(id)
  local p, pal = PORTRAIT[id], id
  if not p then return nil end
  if id == 2 and flag(0x1D) then p, pal = { 8, 7 }, 11 end
  local ok, img = pcall(function()
    local base = p[1] * 32 + p[2] * 4
    local parts = {}
    for r = 0, 3 do
      parts[#parts + 1] = { x = 0, y = r * 8, w = 32, h = 8, tile = base + r * 32, bank = 0 }
    end
    return gfx.sprite{ tiles = M.portraitTiles, palette = PAL0 + 32 * pal, width = 32, height = 32, parts = parts }
  end)
  if ok then return img end
  return nil
end

local function expNext(id, lv)
  if id > 7 or lv < 1 or lv > 98 then return nil end
  local a = M.expTable + (id * 98 + lv - 1) * 3
  return mem.u8(a) | (mem.u8(a + 1) << 8) | (mem.u8(a + 2) << 16)
end

------------------------------------------------------------------------------
-- Characters
------------------------------------------------------------------------------
local SLOT_LABELS = { "WPN", "SHD", "ARM", "HLM", "ETC", "ETC" }
local SLOT_OFFS   = { 0x2A, 0x2C, 0x2E, 0x30, 0x04, 0x06 }

local function readMember(base, id)
  local raw = mem.read(base, 0x3C)
  local function u8(o) return raw:byte(o + 1) end
  local function u16(o) return raw:byte(o + 1) | (raw:byte(o + 2) << 8) end
  local function u32(o) return u16(o) | (u16(o + 2) << 16) end

  local m = { id = id }
  local fl = u8(0x08)
  m.away = fl & 0x40 ~= 0     -- not with the party (the menu hides it)
  m.fused = fl & 0x10 ~= 0    -- fused into Karn
  m.fusing = fl & 0x20 ~= 0   -- Karn while fused
  m.dragon = fl & 0x08 ~= 0   -- Ryu transformed (battle)
  local st = u8(0x09)         -- status: the field menu labels 0x10 Crs, 0x20 Psn, 0x40 Zom, 0x80 Stun
  local tags = {}
  if st & 0x80 ~= 0 then tags[#tags + 1] = "STUN" end
  if st & 0x20 ~= 0 then tags[#tags + 1] = "PSN" end
  if st & 0x40 ~= 0 then tags[#tags + 1] = "ZOM" end
  if st & 0x10 ~= 0 then tags[#tags + 1] = "CRS" end
  m.status = table.concat(tags, " ")
  m.hasStatus = #tags > 0
  m.name = decode(raw:sub(1, 4))
  if m.name == "" then m.name = CHAR_NAMES[id] or "-" end
  m.lv = u8(0x0A)
  m.maxHp, m.hp = u16(0x0C), u16(0x0E)
  m.maxAp, m.ap = u16(0x10), u16(0x12)
  m.exp = u32(0x14)
  m.hpPct = pct(m.hp, m.maxHp)
  m.apPct = pct(m.ap, m.maxAp)
  m.low = m.maxHp > 0 and m.hp * 4 <= m.maxHp and m.hp > 0
  m.ko = m.maxHp > 0 and m.hp == 0
  m.hasAp = m.maxAp > 0
  m.hpText = m.hp .. "/" .. m.maxHp
  m.apText = m.ap .. "/" .. m.maxAp
  m.expText = commas(m.exp)
  m.lvText = m.fusing and "FUSE" or tostring(m.lv)
  local nx = expNext(id, m.lv)
  m.hasNext = nx ~= nil and not m.fusing
  m.nextTotal = nx and commas(nx) or "-"
  if m.fusing or id > 7 then m.nextText = "-"            -- fused Karn, guests: no table
  elseif nx then m.nextText = commas(math.max(0, nx - m.exp))
  else m.nextText = "MAX" end
  m.expPct = nx and pct(m.exp, nx) or 1

  local function v(x) return tostring(x) end
  m.stats = {
    { label = "STR",  value = v(u8(0x18)) },
    { label = "VIG",  value = v(u8(0x19)) },
    { label = "AGI",  value = v(u8(0x1B)) },
    { label = "WIS",  value = v(u8(0x1A)) },
    { label = "LUCK", value = v(u8(0x1D)) },
  }
  local atk, def = u16(0x1E), u16(0x20)
  local calc = atk > 0 or def > 0   -- derived stats are 0 until the game works them out
  local function dv(x) return calc and v(x) or "-" end
  m.derived = {
    { label = "ATTACK",  value = dv(atk) },
    { label = "DEFENSE", value = dv(def) },
    { label = "ACTIVE",  value = dv(u8(0x23)) },
    { label = "INTLGCE", value = dv(u8(0x22)) },
    { label = "FATE",    value = dv(u8(0x24)) },
    { label = "MAG DEF", value = dv(u8(0x1C)) },
  }
  m.quick = {
    { label = "ATK", value = dv(atk) },
    { label = "DEF", value = dv(def) },
    { label = "AGI", value = v(u8(0x1B)) },
    { label = "ACT", value = dv(u8(0x23)) },
  }

  m.gear = {}
  for i = 1, 6 do
    local o = SLOT_OFFS[i]
    local gid, gb = u8(o), u8(o + 1)
    local n = gearName(gid, gb)
    local ic = n and icon(gid, gb >> 4)
    local pw = n and powerText(gearInfo(gid, gb >> 4)) or ""
    m.gear[i] = { slot = SLOT_LABELS[i], name = n or "-", empty = n == nil, icon = ic, hasIcon = ic ~= nil,
                  power = pw, hasPower = pw ~= "", pnum = pw:gsub("^%u+ ", "") }
  end
  m.weapon = m.gear[1].name
  m.weaponIcon, m.hasWeaponIcon = m.gear[1].icon, m.gear[1].hasIcon

  m.portrait = portrait(id)
  m.hasPortrait = m.portrait ~= nil
  m.noPortrait = not m.hasPortrait
  m.initial = m.name:sub(1, 1)
  m.dim = m.fused or m.ko
  return m
end

-- The party in the menu's order: first four are the active party, the rest wait in reserve.
local function readParty()
  local slotOf = {}
  local ids = mem.read(M.rosterId, 8)
  for k = 0, 7 do
    local c = ids:byte(k + 1)
    if c ~= 0xFF and slotOf[c] == nil then slotOf[c] = k end
  end
  local order = mem.read(M.order, 8)
  local active, reserve = {}, {}
  for i = 0, 7 do
    local c = order:byte(i + 1)
    local k = c ~= 0xFF and slotOf[c] or nil
    if k then
      local base = k < 4 and (M.live + k * 0x124) or (M.roster + k * 0x3C)
      local m = readMember(base, c)
      if not m.away and m.maxHp > 0 then
        if i < 4 then active[#active + 1] = m else reserve[#reserve + 1] = m end
      end
    end
  end
  return active, reserve
end

------------------------------------------------------------------------------
-- Battle
------------------------------------------------------------------------------
local MON_ID_BY_NAME = nil
local function monsterIdByName(n)
  if not MON_ID_BY_NAME then
    MON_ID_BY_NAME = {}
    for id = 0, M.monsterCount - 1 do
      local nm = NAMES.monster[id]
      if nm and MON_ID_BY_NAME[nm] == nil then MON_ID_BY_NAME[nm] = id end
    end
  end
  return MON_ID_BY_NAME[n]
end

local function monsterStats(id)
  local a = M.monsters + id * 31
  local raw = mem.read(a, 16)
  return { hp = raw:byte(7) | (raw:byte(8) << 8), lv = raw:byte(11),
           atk = raw:byte(13) * 2, def = raw:byte(14) * 2, agi = raw:byte(15) }
end

local function readEnemies()
  local list, alive = {}, 0
  for j = 0, 7 do
    local base = M.enemies + j * 0x124
    local maxHp = mem.u16(base + 0x0C)
    if maxHp > 0 and maxHp < 65535 then
      local hp = mem.u16(base + 0x0E)
      local e = { name = decode(mem.read(base, 8)), lv = mem.u8(base + 0x0A), id = mem.u8(base + 0x78),
                  hp = hp, maxHp = maxHp, hpText = hp .. "/" .. maxHp, hpPct = pct(hp, maxHp),
                  dead = hp == 0 }
      if e.name == "" then e.name = "?" end
      if e.id == 0 or NAMES.monster[e.id] ~= e.name then   -- id byte not filled in yet
        e.id = monsterIdByName(e.name) or e.id
      end
      local ms = monsterStats(e.id)
      e.atk, e.def, e.agi = tostring(ms.atk), tostring(ms.def), tostring(ms.agi)
      e.low = hp > 0 and hp * 4 <= maxHp
      if not e.dead then alive = alive + 1 end
      list[#list + 1] = e
    end
  end
  return list, alive
end

-- Session memory (packs have no storage): the last battle and what it paid out.
local B = { active = false, ticks = 0, endTicks = 0, gold0 = 0, exp0 = {}, last = nil, seen = {} }

local function partyExp(active)
  local t = {}
  for _, m in ipairs(active) do t[m.id] = m.exp end
  return t
end

------------------------------------------------------------------------------
-- Magic: the game's own spell lists (pool + learn levels), checked against every SPEL screen
------------------------------------------------------------------------------
local SPELLBOOK = {}       -- [char id] = { ids = {...}, levels = {...} | nil }
if M then
  local order = { 1, 2, 7, 3 }   -- Bo, Nina, Bleu, Ox
  local raw = mem.read(M.spellPool, 0x48)
  local i, k = 1, 1
  while k <= #order and raw:byte(i) and raw:byte(i) ~= 0xFF do
    local n = raw:byte(i)
    local ids = {}
    for j = 1, n do ids[j] = raw:byte(i + j) end
    local lv = nil
    local la = M.spellLevels[order[k]]
    if la then
      local lraw = mem.read(la, n)
      lv = {}
      for j = 1, n do lv[j] = lraw:byte(j) end
    end
    SPELLBOOK[order[k]] = { ids = ids, levels = lv }
    i, k = i + 1 + n, k + 1
  end
end

local function spellIcon(i)
  local key = "s" .. i
  if iconCache[key] then return iconCache[key] end
  local ok, img = pcall(gfx.decode, { tiles = M.iconTiles + (i // 32) * 0x400 + (i % 32) * 32,
                                      palette = M.iconPal, width = 8, height = 8 })
  if ok and img then iconCache[key] = img; return img end
  return nil
end

local function clean(t) return (t or ""):gsub("%.$", "") end

-- Karn (5), Gobi (4) and Mogu (6) use SPEL too; all entries showed in every save that has them.
-- help = index into the spell help table (Shin 82, Debo 83, Doof 84, Puka 85; Gobi 54-57; Dig 80).
local ABILITIES
local function loadAbilities()
  if ABILITIES then return end
  ABILITIES = { [4] = {}, [5] = {}, [6] = {} }
  local g = mem.read(M.gobiSkills, 48)
  for k = 0, 3 do
    local ic = spellIcon(mem.u8(M.spellIcons + 54 + k))
    ABILITIES[4][k + 1] = { name = decode(g:sub(12 * k + 1, 12 * k + 8)), ap = g:byte(12 * k + 11),
                            help = 54 + k, icon = ic }
  end
  local f = mem.read(M.fusions, 64)
  for k = 0, 3 do
    ABILITIES[5][k + 1] = { name = decode(f:sub(16 * k + 1, 16 * k + 8)), ap = f:byte(16 * k + 11),
                            help = 82 + k, icon = spellIcon(17) }
  end
  ABILITIES[6][1] = { name = decode(mem.read(M.digName, 4)), ap = 5, help = 80, icon = spellIcon(17) }
end

local function spellList(m)
  loadAbilities()
  local list, known = {}, 0
  if m.id == 0 then
    for k = 0, 8 do
      local has = flag(20 + k)
      if has then known = known + 1 end
      local ic = spellIcon(17)
      list[#list + 1] = { name = has and NAMES.dragon[k] or "???", locked = not has, lvText = has and "" or "SHRINE",
                          hasLv = not has, icon = ic, hasIcon = ic ~= nil,
                          help = has and (clean(NAMES.spellHelp[81]) .. ", " .. DRAGON_AP[k] .. " AP")
                                      or "Not learned yet: found at a dragon shrine" }
    end
    return list, known
  end
  local extra = ABILITIES[m.id]
  if extra then
    for _, a in ipairs(extra) do
      list[#list + 1] = { name = a.name, locked = false, hasLv = false, lvText = "",
                          icon = a.icon, hasIcon = a.icon ~= nil,
                          help = clean(NAMES.spellHelp[a.help]) .. ", " .. a.ap .. " AP" }
    end
    return list, #list
  end
  local book = SPELLBOOK[m.id]
  if not book then return nil, 0 end
  for j, id in ipairs(book.ids) do
    local need = book.levels and book.levels[j] or 0
    local has = m.lv >= need
    if has then known = known + 1 end
    local ic = spellIcon(mem.u8(M.spellIcons + id))
    list[#list + 1] = { name = NAMES.spell[id] or "?", locked = not has, hasLv = need > 1,
                        lvText = "LV " .. need, icon = ic, hasIcon = ic ~= nil,
                        help = clean(NAMES.spellHelp[id]) }
  end
  return list, known
end

------------------------------------------------------------------------------
-- Place and journey
------------------------------------------------------------------------------
local function currentPlace()
  local id = mem.u16(M.mapId)
  if id == 0 then return "World Map", true end
  if id > 520 then return "-", false end
  local p = mem.u8(M.mapPlace + id)
  local n = NAMES.place[p]
  if not n or n == "" or n:find("?") then return "-", false end
  return n, false
end

local FISH = { 71, 72, 73, 74, 75, 76, 77, 78 }     -- Srdine .. Puffer
local RODS = { 79, 80, 81, 82, 83 }

local function bagCounts()
  local raw = mem.read(M.bag, 2 * M.bagSlots)
  local c = {}
  for i = 0, M.bagSlots - 1 do
    local id, b = raw:byte(2 * i + 1), raw:byte(2 * i + 2)
    if b >> 4 == 0 and b & 0x0F > 0 then c[id] = (c[id] or 0) + (b & 0x0F) end
  end
  return c
end

------------------------------------------------------------------------------
-- Book (monsters met this session; packs have no storage)
------------------------------------------------------------------------------
local BOOK = {}   -- [monster id] = { met = n, lv, maxHp }

local KIND_LABEL = { [0] = "ITEM", [1] = "WEAPON", [2] = "ARMOR" }
local LIST_FITS = 27      -- bag/vault cells visible at once (9 rows x 3); more scroll

local function readBag(base, slots, idx0)
  base, slots, idx0 = base or M.bag, slots or M.bagSlots, idx0 or 0
  local raw = mem.read(base, 2 * slots)
  local list, used, kinds = {}, 0, { [0] = 0, 0, 0 }
  for i = 0, slots - 1 do
    local id, b = raw:byte(2 * i + 1), raw:byte(2 * i + 2)
    local n = gearName(id, b)
    if n then
      used = used + 1
      local k = b >> 4
      kinds[k] = (kinds[k] or 0) + 1
      local ic = icon(id, k)
      list[#list + 1] = { name = n, count = "x" .. (b & 0x0F), icon = ic, hasIcon = ic ~= nil,
                          kind = KIND_LABEL[k] or "", gear = k ~= 0, id = id, k = k, idx = idx0 + #list }
    end
  end
  return list, used, kinds
end

-- Vital items (the game's VITL list): kept apart from the bag.
local function readVital()
  local n = math.min(mem.u16(M.vitalCount), M.vitalSlots)
  local raw = mem.read(M.vital, 2 * M.vitalSlots)
  local list = {}
  for i = 0, n - 1 do
    local id = raw:byte(2 * i + 1)
    local name = NAMES.item[id]
    if name and name ~= "" and name ~= "Dummy" then
      local ic = icon(id, 0)
      list[#list + 1] = { name = name, icon = ic, hasIcon = ic ~= nil, id = id, idx = 100 + #list, k = 0 }
    end
  end
  return list
end

local function waiting(out, text)
  out.waiting, out.ready, out.waitingText = true, false, text
  return out
end

function update(ui)
  local out = { ready = false, waiting = true }
  out.navParty = ui.page == "party"
  out.navGear = ui.page == "gear"
  out.navItems = ui.page == "items"
  out.navBattle = ui.page == "battle"
  out.navBook = ui.page == "book"
  out.navJourney = ui.page == "journey"
  out.navMagic = ui.page == "magic"

  if not M then return waiting(out, "This pack supports the US release (ABFE) only.") end
  if mem.u8(M.inGame) == 0 then return waiting(out, "Start or continue a game.") end

  local active, reserve = readParty()
  if #active == 0 then return waiting(out, "Start or continue a game.") end
  out.waiting, out.ready = false, true

  out.gold = commas(mem.u32(M.gold))
  local place, world = currentPlace()
  out.place = place
  out.isNight = mem.u8(M.night) == 1
  out.isDay = not out.isNight
  out.timeText = out.isNight and "NIGHT" or "DAY"

  local all = {}
  local slots = {}
  for i = 1, 4 do
    local m = active[i]
    if m then
      all[#all + 1] = m
      m.index, m.filled, m.open = #all - 1, true, false
      slots[i] = m
    else
      slots[i] = { index = -1, filled = false, open = true }
    end
  end
  for _, m in ipairs(reserve) do
    all[#all + 1] = m
    m.index = #all - 1
  end
  out.party = slots
  out.reserve = reserve
  out.hasReserve = #reserve > 0
  out.partyCount = #all .. (#all == 1 and " MEMBER" or " MEMBERS")
  out.members = all

  -- Battle: open the page on the first tick of a fight, go back a moment after it ends.
  local fighting = mem.u8(M.inBattle) == 1
  local gold = mem.u32(M.gold)
  if fighting and not B.active then
    B.active, B.ticks, B.gold0, B.exp0 = true, 0, gold, partyExp(active)
    B.returnTo = ui.page ~= "battle"
    out.ui = { navigate = "battle" }
  elseif not fighting and B.active then
    B.active, B.endTicks = false, 0
  end
  if fighting then B.ticks = B.ticks + 1 end
  if not fighting and B.last and B.endTicks >= 0 then
    B.endTicks = B.endTicks + 1
    if B.endTicks == 10 then
      if B.returnTo and ui.page == "battle" then out.ui = { back = true } end
      B.endTicks = -1
    end
  end
  out.fighting = fighting
  out.notFighting = not fighting
  if fighting or ui.page == "battle" then
    local foes, alive = {}, 0
    if fighting then
      foes, alive = readEnemies()
      if B.ticks == 1 then
        local once = {}
        for _, e in ipairs(foes) do
          local b = BOOK[e.id] or { met = 0 }
          if not once[e.id] then b.met = b.met + 1; once[e.id] = true end
          b.lv, b.maxHp = e.lv, e.maxHp
          BOOK[e.id] = b
        end
      end
      for _, e in ipairs(foes) do
        if not BOOK[e.id] then BOOK[e.id] = { met = 1, lv = e.lv, maxHp = e.maxHp } end
      end
      local gainGold = gold - B.gold0
      local gainExp = 0
      local now = partyExp(active)
      for id, x in pairs(now) do if B.exp0[id] and x > B.exp0[id] then gainExp = math.max(gainExp, x - B.exp0[id]) end end
      local partyUp = false
      for _, m in ipairs(active) do if m.hp > 0 then partyUp = true end end
      B.last = { foes = foes, gold = gainGold, exp = gainExp, won = alive == 0 and #foes > 0, lost = not partyUp }
      out.foeCount = #foes .. (#foes == 1 and " ENEMY" or " ENEMIES")
    end
    local L = B.last
    out.hasLast = L ~= nil
    out.foes = L and L.foes or {}
    local many = #out.foes > 4                       -- compact rows (no stat line) for 5+ enemies
    for _, e in ipairs(out.foes) do e.showStats = not many end
    out.foesMore = #out.foes > 6
    out.foesMoreText = "SCROLL FOR ALL " .. #out.foes
    out.foesLeft = alive .. " LEFT"
    out.won = L ~= nil and L.won
    out.lost = L ~= nil and L.lost and not L.won
    out.escaped = L ~= nil and not fighting and not L.won and not L.lost
    out.resultText = (L and L.won) and "WON" or ((L and L.lost) and "DEFEAT" or "ESCAPED")
    out.showResult = L ~= nil and (L.won or not fighting)
    out.spoils = L ~= nil and (L.gold > 0 or L.exp > 0)
    out.spoilGold = L and ("+" .. commas(L.gold) .. "G") or ""
    out.spoilExp = L and ("+" .. commas(L.exp) .. " EXP") or ""
    out.noBattle = not fighting and L == nil
    out.battleParty = active
  end

  if ui.page == "magic" then
    local casters = {}
    for _, m in ipairs(all) do
      local l = spellList(m)
      if l then casters[#casters + 1] = m end
    end
    local pick = tonumber(ui.mag) or 0
    if pick < 0 or pick >= #casters then pick = 0 end
    local chips = {}
    for i, m in ipairs(casters) do
      chips[i] = { idx = i - 1, name = m.name, portrait = m.portrait, hasPortrait = m.hasPortrait,
                   on = (i - 1) == pick, off = (i - 1) ~= pick }
    end
    out.casters = chips
    out.noCasters = #casters == 0
    local m = casters[pick + 1]
    if m then
      local l, known = spellList(m)
      for j, sp in ipairs(l) do sp.idx = j - 1 end
      local sel = tonumber(ui.sp)
      for j, sp in ipairs(l) do sp.sel = sel == j - 1 end
      out.spells = l
      out.magName, out.magLv = m.name, "LV " .. m.lvText
      out.magCount = known .. "/" .. #l
      out.magTitle = m.id == 0 and "DRAGON FORMS" or "SPELLS"
      local sp = sel and l[sel + 1]
      out.spellHelp = sp and (sp.name .. ": " .. sp.help) or "Tap a spell to read what it does."
    end
  end

  if ui.page == "journey" then
    out.onWorld = world
    out.areaKind = world and "OUTDOORS" or "AREA"
    local dr, got = {}, 0
    for k = 0, 8 do
      local has = flag(20 + k)
      if has then got = got + 1 end
      dr[#dr + 1] = { name = has and NAMES.dragon[k] or "???", locked = not has }
    end
    out.dragons, out.dragonCount = dr, got .. "/9"
    local dic
    do
      local ok, img = pcall(gfx.decode, { tiles = M.iconTiles + 17 * 32, palette = M.iconPal, width = 8, height = 8 })
      dic = ok and img or nil
    end
    local ryuChip = 0                                  -- Ryu's chip on the MAGIC tab (guests have none)
    for _, m in ipairs(all) do if m.id == 0 then break end; if m.id <= 7 then ryuChip = ryuChip + 1 end end
    for k, d in ipairs(dr) do d.icon, d.hasIcon, d.k, d.ryuChip = dic, dic ~= nil, k - 1, ryuChip end
    local idxOf, memOf = {}, {}
    for _, m in ipairs(all) do idxOf[m.id], memOf[m.id] = m.index, m end
    local joined, crew = 0, {}
    local ids = mem.read(M.rosterId, 8)
    local have = {}
    for k = 0, 7 do local c = ids:byte(k + 1); if c < 8 then have[c] = true end end
    for id = 0, 7 do
      if have[id] then joined = joined + 1 end
      local img = have[id] and portrait(id) or nil
      local mm = memOf[id]
      local where = not have[id] and "" or (not mm and "AWAY" or (mm.fused and "FUSED"
                    or (mm.index < 4 and "PARTY" or "RESERVE")))
      crew[#crew + 1] = { name = have[id] and (mm and mm.name or CHAR_NAMES[id]) or "???", locked = not have[id],
                          portrait = img, hasPortrait = img ~= nil, index = idxOf[id] or -1,
                          lv = mm and (mm.fusing and "FUSION" or ("LV " .. mm.lv)) or "", where = where,
                          hasWhere = where ~= "" }
    end
    out.crew, out.crewCount = crew, joined .. "/8"
    local bc = bagCounts()
    local fish, nf = {}, 0
    for _, id in ipairs(FISH) do
      local n = bc[id] or 0
      nf = nf + n
      local ic2 = icon(id, 0)
      fish[#fish + 1] = { name = NAMES.item[id] or "?", count = "x" .. n, none = n == 0, icon = ic2, hasIcon = ic2 ~= nil }
    end
    local rods = {}
    for _, id in ipairs(RODS) do if (bc[id] or 0) > 0 then rods[#rods + 1] = NAMES.item[id] end end
    out.fish, out.fishTotal = fish, tostring(nf)
    out.rods = #rods > 0 and table.concat(rods, "  ") or "No rod yet"
  end

  if ui.page == "book" then
    local reveal = ui.reveal == true or ui.reveal == 1 or ui.reveal == "1"
    local list, met = {}, 0
    for id = 0, M.monsterCount - 1 do
      local n = NAMES.monster[id]
      if n and n ~= "" and n ~= "Dummy" then
        local b = BOOK[id]
        if b then met = met + 1 end
        local show = b ~= nil or reveal
        list[#list + 1] = { id = id, num = string.format("%03d", id), name = show and n or "???",
                            met = b ~= nil, unmet = b == nil, hidden = not show }
      end
    end
    out.book, out.bookMet, out.bookTotal = list, met .. "/" .. #list, tostring(#list)
    out.revealOn, out.revealOff = reveal, not reveal
  end

  if ui.page == "items" then
    local view = tonumber(ui.store) or 0          -- 0 bag, 1 vault, 2 vital
    if view < 0 or view > 2 then view = 0 end
    local list, used, kinds, slots
    if view == 1 then
      list, used, kinds = readBag(M.vault, M.vaultSlots, 200)
      slots = M.vaultSlots
    elseif view == 2 then
      list = readVital()
      used, kinds = #list, { [0] = #list, 0, 0 }
    else
      list, used, kinds = readBag()
      slots = M.bagSlots
    end
    out.viewBag, out.viewVault, out.viewVital = view == 0, view == 1, view == 2
    out.showKinds = view ~= 2
    out.bank = commas(mem.u32(M.bank))
    local pick = tonumber(ui.it)
    local hit
    for _, c in ipairs(list) do
      c.sel = c.idx == pick
      if c.sel then hit = c end
      c.hasCount = c.count ~= nil
    end
    out.bag = list
    out.bagEmpty = used == 0
    out.emptyText = ({ [0] = "The bag is empty.", "Nothing in the vault.", "No vital items yet." })[view]
    out.bagUsed = slots and (used .. "/" .. slots) or (used .. (used == 1 and " ITEM" or " ITEMS"))
    out.bagItems, out.bagWeapons, out.bagArmor = tostring(kinds[0]), tostring(kinds[1]), tostring(kinds[2])
    out.bagMore = #list > LIST_FITS
    out.moreText = "SCROLL FOR ALL " .. #list
    local text
    if hit then
      if hit.gear then
        local g = gearInfo(hit.id, hit.k)
        local pw = powerText(g)
        text = hit.name .. ": " .. (g and g.kind or "gear") .. (pw ~= "" and (", " .. pw) or "")
               .. ". Can equip: " .. (g and g.who or "-") .. "."
      else
        text = hit.name .. ": " .. (msgText(ITEM_MSG[hit.id]) or "No details in the game.")
      end
    end
    out.itemHelp = text or "Tap an item to read the game's own details line."
  end

  -- Monster popup (Book cells and battle enemies set ui.mon); shown on any page.
  do
    local reveal = ui.reveal == true or ui.reveal == 1 or ui.reveal == "1"
    local sid = tonumber(ui.mon)
    local b = sid and BOOK[sid]
    out.monOpen = sid ~= nil and sid >= 0 and sid < M.monsterCount and (b ~= nil or reveal) and NAMES.monster[sid] ~= nil
    if out.monOpen then
      local ms = monsterStats(sid)
      out.mon = { name = NAMES.monster[sid], num = string.format("%03d", sid),
                  lv = tostring(ms.lv), hp = commas(ms.hp), atk = tostring(ms.atk), def = tostring(ms.def),
                  agi = tostring(ms.agi), met = b and tostring(b.met) or "0", seen = b ~= nil, notSeen = b == nil }
    else
      out.mon = { name = "-", num = "", lv = "-", hp = "-", atk = "-", def = "-", agi = "-", met = "0" }
    end
  end

  -- Detail popup for the tapped member (ui.sel is set by the card's onClick).
  local sel = tonumber(ui.sel)
  local d = sel and sel >= 0 and all[sel + 1]
  out.detailOpen = d ~= nil and d ~= false
  out.detail = d or { name = "-", stats = {}, derived = {}, gear = {} }
  return out
end
