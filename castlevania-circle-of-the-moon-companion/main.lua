-- Castlevania: Circle of the Moon (USA, AAME) companion.
-- Names and descriptions are read from the player's ROM (the game's own text, decoded with CHARS below); numbers from RAM.
-- Addresses and table layouts are in NOTES.md.

local CODE = "AAME"

-- ROM (USA)
local STR_PTRS  = 0x086707D8   -- u32 pointers to 0-terminated strings (1270)
local GEAR_STAT = 0x080E0970   -- s16 STR, DEF, INT, LCK per equipment id (8 bytes)
local EXP_TABLE = 0x080E0734   -- u32 total EXP to leave level L (index L)

-- string ids
local S_EQUIP, S_EQUIP_D = 182, 514          -- + id (1-54); 180 = "Unequip"
local S_MAGIC, S_MAGIC_D = 317, 381          -- magic items 0-8 (5 is the Map, no text)
local S_COMBO = 391                          -- + action * 10 + attribute; 390 = "No effect."
local S_CARD_GET, S_CARD_D = 570, 591        -- attributes 0-9 then actions 0-9

-- RAM (EWRAM). The game plays on this copy; its pause menu edits a second copy (+0x22A4) and copies it back.
local R_FRAMES = 0x020253F8   -- u32 play time in frames
local R_MAP    = 0x02025420   -- explored map: 42 rows x 8 bytes, bit c of row r (low bit first)
local MAP_TOTAL = 980         -- cells lit at 100.0%
local R = 0x0202562E          -- block start (HP)
local O = {
  hp = 0x00, maxHp = 0x04, mp = 0x08, maxMp = 0x0C, heart = 0x0E, maxHeart = 0x10,
  stats = 0x16,                -- 4 groups (STR DEF INT LCK) of 4 u16: base, +gear, +cards, final
  level = 0x36, exp = 0x3A,
  attr = 0x3E, action = 0x3F,  -- DSS cards set, 1-based, 0 = none
  body = 0x40, armR = 0x41, armL = 0x42,
  cards = 0x46,                -- 20 owned flags: attributes 0-9, then actions 0-9
  count = 0xBE,                -- one count per equipment / item id (0-54); worn gear is not counted
  config = 0xF6,               -- u16 Attack, Jump, Special Move, DSS (GBA key bits)
  magic = 0x101,               -- 9 owned flags
}
local BLOCK_N = 0x110

local ATTR_NAMES, ACTION_NAMES = {}, {}
-- the 100 combinations' MP cost, read off the game's DSS screen: [action][attribute] = { n, unit }
local A, T, U, S = "ATTACK", "TIME", "USE", "SHOT"
local COST = {
  [0] = { {6,A},{2,A},{6,A},{8,A},{6,A},{6,A},{10,A},{10,A},{20,A},{40,A} },
  [1] = { {4,T},{4,T},{4,T},{16,T},{2,T},{2,T},{4,T},{16,T},{8,T},{8,T} },
  [2] = { {4,T},{4,T},{0,U},{4,T},{8,T},{4,T},{4,T},{4,T},{8,T},{8,T} },
  [3] = { {8,A},{4,A},{10,A},{4,A},{12,A},{8,A},{16,A},{16,A},{32,A},{32,A} },
  [4] = { {32,A},{64,A},{96,A},{16,A},{16,A},{16,A},{128,A},{12,A},{48,A},{32,A} },
  [5] = { {20,U},{20,U},{40,U},{30,U},{60,U},{10,U},{60,U},{80,U},{80,U},{120,U} },
  [6] = { {0,U},{3,T},{0,U},{0,U},{0,U},{0,U},{0,U},{0,U},{0,U},{3,T} },
  [7] = { {4,S},{4,A},{4,S},{4,A},{6,S},{8,A},{8,S},{16,A},{32,S},{4,S} },
  [8] = { {160,U},{120,U},{100,U},{100,U},{200,U},{80,U},{100,U},{200,U},{100,U},{100,U} },
  [9] = { {4,T},{4,T},{4,T},{8,T},{6,T},{5,U},{4,T},{4,T},{20,T},{5,T} },
}
-- the game's text: glyph number -> character (worked out from the item, enemy and help strings)
local CHARS = {
  [0x26]=" ", [0x27]=" ", [0x28]="e", [0x29]="a", [0x2A]="t", [0x2B]="o", [0x2C]="r", [0x2D]="i", [0x2E]="n", [0x2F]="s",
  [0x30]="l", [0x31]="h", [0x32]="d", [0x33]="c", [0x34]="u", [0x35]=".", [0x36]="m", [0x37]="w", [0x38]="p", [0x39]="g",
  [0x3A]="f", [0x3B]="y", [0x3C]="b", [0x3D]="k", [0x3E]="A", [0x3F]="v", [0x40]="H", [0x41]="S", [0x42]="M", [0x43]="I",
  [0x44]="C", [0x45]="D", [0x46]="R", [0x47]="T", [0x49]="W", [0x4A]="!", [0x4B]="P", [0x4C]=",", [0x4D]="B", [0x4E]="E",
  [0x4F]="G", [0x50]="+", [0x51]="'", [0x52]="N", [0x53]="Y", [0x54]="(", [0x55]=")", [0x56]="F", [0x57]="x", [0x58]="-",
  [0x59]="[", [0x5A]="]", [0x5B]=">", [0x5C]="<", [0x5D]="^", [0x5E]="v", [0x5F]="L", [0x60]="U", [0x61]="q", [0x62]="j",
  [0x63]="2", [0x64]="0", [0x65]="z", [0x66]="K", [0x67]="O", [0x68]="%", [0x69]="5", [0x6A]="1", [0x6B]="J", [0x6C]="3",
  [0x6D]="x", [0x6E]="V", [0x6F]="Z", [0x71]="4", [0x72]="8", [0x73]="+",
}
local KEYS = { { v = 0x0001, t = "A" }, { v = 0x0002, t = "B" }, { v = 0x0200, t = "L" }, { v = 0x0100, t = "R" } }
local CONFIG_ROWS = { { label = "ATTACK", off = 0 }, { label = "JUMP", off = 2 }, { label = "SPECIAL MOVE", off = 4 }, { label = "DSS", off = 6 } }
local CONFIG_DEFAULT = { [0] = 0x0002, [2] = 0x0001, [4] = 0x0100, [6] = 0x0200 }
local MAGIC_SHOWN = { 0, 1, 2, 3, 4, 6, 7, 8 }   -- the game's Magic Item page leaves out the Map
local STAT_NAMES = { "str", "def", "int", "lck" }

local D, romOk = nil, false

-- ---------------------------------------------------------------------------------------------
-- ROM text
local function decode(raw)
  local out, i = {}, 1
  while i <= #raw do
    local c = raw:byte(i)
    if c == 0x1D or c == 0x1E or c == 0x1F then i = i + 1          -- two-byte control codes
    elseif c == 0x09 or c == 0x0A or c == 0x01 or c == 0x02 or c == 0x03 then out[#out + 1] = " "
    elseif c == 0x06 or c == 0x07 then out[#out + 1] = "\""
    elseif CHARS[c] then out[#out + 1] = CHARS[c] end
    i = i + 1
  end
  local s = table.concat(out):gsub("%s+", " ")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function rstr(id)
  local p = mem.u32(STR_PTRS + id * 4)
  if p < 0x08000000 or p >= 0x0A000000 then return "" end
  local raw = mem.read(p, 200)
  local e = raw:find("\0", 1, true)
  if e then raw = raw:sub(1, e - 1) end
  return decode(raw)
end

local function bonusText(st)
  local parts = {}
  for k, n in ipairs({ "STR", "DEF", "INT", "LCK" }) do
    local v = st[k]
    if v ~= 0 then parts[#parts + 1] = n .. (v > 0 and "+" or "") .. v end
  end
  return table.concat(parts, "  ")
end

local function buildData()
  D = { equip = {}, magic = {}, cards = {}, combo = {} }
  for id = 1, 54 do
    local e = { name = rstr(S_EQUIP + id), desc = rstr(S_EQUIP_D + id), stats = { 0, 0, 0, 0 } }
    if id <= 40 then
      for k = 1, 4 do e.stats[k] = mem.s16(GEAR_STAT + id * 8 + (k - 1) * 2) end
      e.kind = id <= 22 and "body" or "arm"
      e.bonus = bonusText(e.stats)
      if id == 23 then e.bonus = "All +75 with both hands" end
    else
      e.kind = "use"
      local n, what = e.desc:match("Recover (%d+)%%? (%a+)")
      local all, what2 = e.desc:match("Recover (all) (%a+)")
      if e.desc:find("%%") then e.mpPct = tonumber(n) end
      if all then n, what = 9999, what2 end
      if what == "HP" then e.heal = "hp" elseif what == "MP" then e.heal = "mp" elseif what == "Hearts" then e.heal = "heart" end
      e.amount = tonumber(n)
    end
    D.equip[id] = e
  end
  D.equip[0] = { name = rstr(180), desc = rstr(S_EQUIP_D), stats = { 0, 0, 0, 0 }, kind = "none", bonus = "" }
  for i = 0, 8 do D.magic[i] = { name = rstr(S_MAGIC + i), desc = i == 5 and "" or rstr(S_MAGIC_D + (i > 5 and i - 1 or i)) } end
  for k = 0, 19 do
    local got = rstr(S_CARD_GET + k)          -- 'Received "Salamander" Card'
    local name = got:match("\"(.-)\"") or ("Card " .. (k + 1))
    D.cards[k] = { name = name, desc = rstr(S_CARD_D + k) }
    if k < 10 then ATTR_NAMES[k] = name else ACTION_NAMES[k - 10] = name end
  end
  D.noEffect = rstr(S_COMBO - 1)
  for a = 0, 9 do for t = 0, 9 do D.combo[a * 10 + t] = rstr(S_COMBO + a * 10 + t) end end
end

function init()
  romOk = mem.read(0x080000AC, 4) == CODE
  if romOk then buildData() end
end

-- ---------------------------------------------------------------------------------------------
local B = ""
local function b8(o) return B:byte(o + 1) or 0 end
local function b16(o) return b8(o) | (b8(o + 1) << 8) end
local function b32(o) return b16(o) | (b16(o + 2) << 16) end
local function clampInt(v, lo, hi) v = tonumber(v) or lo; if v < lo then return lo end; if v > hi then return hi end; return math.floor(v) end
local function keyText(v) for _, k in ipairs(KEYS) do if k.v == v then return k.t end end return "?" end
local function stat(s, k) return b16(O.stats + s * 8 + k * 2) end   -- s 0-3, k 0 base .. 3 final
local function owned(card) return b8(O.cards + card) ~= 0 end       -- 0-9 attributes, 10-19 actions

local function cardImg(k, have)          -- the game's own card art (cut from its Card screen); unowned cards are dimmed by the layout
  return "asset:game/cardt-" .. k .. ".png"
end

local function comboOf(attr1, act1)  -- 1-based as in RAM; returns text, cost n, cost unit
  if attr1 < 1 or act1 < 1 then return D.noEffect, "", "" end
  local c = COST[act1 - 1][attr1]
  return D.combo[(act1 - 1) * 10 + attr1 - 1], tostring(c[1]), "/" .. c[2]
end

-- totals with gear `ids` worn instead of the current ones: the sum of the table rows (+75 each for both Double Grips)
local function gearSum(body, r, l)
  local s = { 0, 0, 0, 0 }
  for _, id in ipairs({ body, r, l }) do
    local e = (id >= 1 and id <= 40) and D.equip[id] or nil
    if e then for k = 1, 4 do s[k] = s[k] + e.stats[k] end end
  end
  if r == 23 and l == 23 then for k = 1, 4 do s[k] = s[k] + 75 end end   -- the pair adds 75 (the game: 885 -> 810 taking one off)
  return s
end

-- ---------------------------------------------------------------------------------------------
-- pages
local MENU = {
  { label = "DSS", page = "dss", hint = "Dual Set-up System settings" },
  { label = "ITEM", page = "item", hint = "Use or equip items" },
  { label = "CARD", page = "card", hint = "Examine DSS cards" },
  { label = "MAGIC ITEM", page = "magic", hint = "Examine Magic items" },
  { label = "CONFIG", page = "config", hint = "Change button configuration" },
  { label = "MAP", page = "map", hint = "The castle map" },
}

local function status(out)
  local secs = mem.u32(R_FRAMES) // 60
  local level = b16(O.level)
  local exp = b32(O.exp)
  local nxt = level >= 99 and exp or mem.u32(EXP_TABLE + level * 4)
  local base = level <= 1 and 0 or mem.u32(EXP_TABLE + (level - 1) * 4)
  local lit = 0
  local map = mem.read(R_MAP, 42 * 8)
  for i = 1, #map do local v = map:byte(i); while v > 0 do lit = lit + (v & 1); v = v >> 1 end end
  out.st = {
    level = tostring(level), hp = b16(O.hp), maxHp = b16(O.maxHp), mp = b16(O.mp), maxMp = b16(O.maxMp),
    heart = b16(O.heart), maxHeart = b16(O.maxHeart),
    hpText = b16(O.hp) .. "/" .. b16(O.maxHp), mpText = b16(O.mp) .. "/" .. b16(O.maxMp), heartText = b16(O.heart) .. "/" .. b16(O.maxHeart),
    lowHp = b16(O.hp) * 4 <= b16(O.maxHp),
    str = stat(0, 3), def = stat(1, 3), int = stat(2, 3), lck = stat(3, 3),
    exp = tostring(exp), next = tostring(math.max(0, nxt - exp)),
    expIn = math.max(0, exp - base), expSpan = math.max(1, nxt - base),
    time = string.format("%02d:%02d:%02d", secs // 3600, (secs // 60) % 60, secs % 60),
    rate = string.format("%.1f%%", math.min(1000, lit * 1000 // MAP_TOTAL) / 10),
  }
  local attr, act = b8(O.attr), b8(O.action)
  local text, n, u = comboOf(attr, act)
  out.dssNow = {
    action = act >= 1 and ACTION_NAMES[act - 1]:upper() or "---", attr = attr >= 1 and ATTR_NAMES[attr - 1]:upper() or "---",
    actImg = act >= 1 and ("asset:game/card-" .. (10 + act - 1) .. ".png") or "asset:ui/card-back.png", attrImg = attr >= 1 and ("asset:game/card-" .. (attr - 1) .. ".png") or "asset:ui/card-back.png",
    text = text, costN = n, costU = u, on = attr >= 1 and act >= 1,
  }
  local function gear(label, id, slot)
    local e = id >= 1 and D.equip[id] or nil
    return { label = label, name = e and e.name or "---", none = e == nil, slot = slot }
  end
  out.mg = {}
  for i = 0, 8 do
    local have = b8(O.magic + i) ~= 0
    out.mg[i + 1] = { i = i, have = have, locked = not have, img = (i == 5) and "asset:ui/tab-map.png" or ("asset:game/mgt-" .. i .. ".png") }
  end
  local nm = 0
  for i = 0, 8 do if b8(O.magic + i) ~= 0 then nm = nm + 1 end end
  out.mgCount = nm .. "/9"
  out.gear = { gear("BODY", b8(O.body), 1), gear("ARM R", b8(O.armR), 2), gear("ARM L", b8(O.armL), 3) }
  out.menu = {}
  for i, m in ipairs(MENU) do out.menu[i] = { label = m.label, page = m.page, hint = m.hint } end
end

local function pageDss(out, ui)
  local attr, act = b8(O.attr), b8(O.action)
  local pa = tonumber(ui.pickAttr) or -1
  local pc = tonumber(ui.pickAct) or -1
  pa = pa < 0 and attr or clampInt(pa, 0, 10)
  pc = pc < 0 and act or clampInt(pc, 0, 10)
  local acts, attrs = {}, {}
  for k = 0, 9 do
    acts[k + 1] = { i = k + 1, img = cardImg(10 + k, owned(10 + k)), have = owned(10 + k), locked = not owned(10 + k), set = act == k + 1, sel = pc == k + 1 }
    attrs[k + 1] = { i = k + 1, img = cardImg(k, owned(k)), have = owned(k), locked = not owned(k), set = attr == k + 1, sel = pa == k + 1 }
  end
  out.dssActs, out.dssAttrs = acts, attrs
  out.kindAct = (tonumber(ui.dssKind) or 1) ~= 2
  out.kindAttr = not out.kindAct
  local text, n, u = comboOf(pa, pc)
  out.dssPick = {
    action = pc >= 1 and ACTION_NAMES[pc - 1]:upper() or "---", attr = pa >= 1 and ATTR_NAMES[pa - 1]:upper() or "---",
    text = text, costN = n, costU = u, attr1 = pa, act1 = pc,
    actImg = pc >= 1 and ("asset:game/card-" .. (10 + pc - 1) .. ".png") or "asset:ui/card-back.png", attrImg = pa >= 1 and ("asset:game/card-" .. (pa - 1) .. ".png") or "asset:ui/card-back.png",
    canSet = pa >= 1 and pc >= 1 and owned(pa - 1) and owned(10 + pc - 1) and (pa ~= attr or pc ~= act),
    isSet = pa == attr and pc == act and pa >= 1,
  }
end

local SLOTS = { { key = "body", off = O.body, label = "BODY" }, { key = "armR", off = O.armR, label = "ARM R" }, { key = "armL", off = O.armL, label = "ARM L" } }

local function pageItem(out, ui)
  local tab = clampInt(ui.itemTab or 1, 1, 4)     -- 1 body, 2 arm R, 3 arm L, 4 use
  out.itemTabs = {}
  for i = 1, 4 do
    local slot = SLOTS[i]
    local id = slot and b8(slot.off) or 0
    out.itemTabs[i] = { i = i, sel = i == tab, eqp = i <= 3, use = i == 4, label = slot and slot.label or "USE", icon = (i == 1) and "asset:ui/ic-armor.png" or "asset:ui/ic-fist.png",
                        name = slot and (id >= 1 and D.equip[id].name or "---") or "" }
  end
  local pick = tonumber(ui.itemId) or -1
  local list = {}
  if tab <= 3 then
    list[1] = { id = 0, name = D.equip[0].name, count = "", sel = pick == 0 }
    local want = tab == 1 and "body" or "arm"
    for id = 1, 40 do
      local n = b8(O.count + id)
      if D.equip[id].kind == want and n > 0 then list[#list + 1] = { id = id, name = D.equip[id].name, count = tostring(n), sel = pick == id } end
    end
  else
    for id = 41, 54 do
      local n = b8(O.count + id)
      if n > 0 then list[#list + 1] = { id = id, name = D.equip[id].name, count = tostring(n), sel = pick == id } end
    end
  end
  out.itemList = list
  out.itemEmpty = #list == 0
  -- stats and the game's before -> after arrows
  local cur = { b8(O.body), b8(O.armR), b8(O.armL) }
  local now = { stat(0, 3), stat(1, 3), stat(2, 3), stat(3, 3) }
  local after = nil
  out.ipick = { name = "", desc = "Use or equip items", bonus = "", id = -1, tab = tab, canSet = false, isSet = false, canUse = false, full = false }
  if pick >= 0 and pick <= 54 and (pick == 0 or b8(O.count + pick) > 0 or (tab <= 3 and cur[tab] == pick)) then
    local e = D.equip[pick]
    out.ipick = { name = e.name, desc = e.desc, bonus = e.bonus or "", id = pick, tab = tab, canSet = false, isSet = false, canUse = false, full = false }
    if tab <= 3 then
      local ok = (pick == 0) or (e.kind == (tab == 1 and "body" or "arm"))
      out.ipick.isSet = cur[tab] == pick
      out.ipick.canSet = ok and not out.ipick.isSet and (pick == 0 and cur[tab] ~= 0 or pick ~= 0)
      if out.ipick.canSet then
        local new = { cur[1], cur[2], cur[3] }
        new[tab] = pick
        local a, b = gearSum(cur[1], cur[2], cur[3]), gearSum(new[1], new[2], new[3])
        after = {}
        for k = 1, 4 do after[k] = math.max(0, now[k] + b[k] - a[k]) end
      end
    else
      local have = e.heal == "hp" and b16(O.hp) < b16(O.maxHp) or e.heal == "mp" and b16(O.mp) < b16(O.maxMp) or e.heal == "heart" and b16(O.heart) < b16(O.maxHeart)
      out.ipick.canUse = e.heal ~= nil and have
      out.ipick.full = e.heal ~= nil and not have
    end
  end
  out.sw = {}
  for k = 1, 4 do
    local v = after and after[k] or now[k]
    out.sw[STAT_NAMES[k]] = { v = tostring(now[k]), to = after and tostring(v) or "", up = after ~= nil and v > now[k], down = after ~= nil and v < now[k], cmp = after ~= nil }
  end
end

local function pageCard(out, ui)
  local pick = clampInt(ui.card or 10, 0, 19)
  local acts, attrs = {}, {}
  for k = 0, 9 do
    acts[k + 1] = { k = 10 + k, img = cardImg(10 + k, owned(10 + k)), sel = pick == 10 + k }
    attrs[k + 1] = { k = k, img = cardImg(k, owned(k)), sel = pick == k }
  end
  out.cardActs, out.cardAttrs = acts, attrs
  local have = owned(pick)
  out.cardPick = { name = have and D.cards[pick].name:upper() or "????????", desc = have and D.cards[pick].desc or "You have not found this card yet.",
                   img = have and ("asset:ui/cardbig-" .. pick .. ".png") or "asset:ui/cardbig-back.png", kind = pick < 10 and "ATTRIBUTE" or "ACTION" }
  local n = 0
  for k = 0, 19 do if owned(k) then n = n + 1 end end
  out.cardCount = n .. " / 20"
end

local function pageMagic(out, ui)
  local pick = clampInt(ui.magic or 0, 0, 8)
  local list = {}
  for _, i in ipairs(MAGIC_SHOWN) do
    local have = b8(O.magic + i) ~= 0
    list[#list + 1] = { i = i, name = have and D.magic[i].name or "??????????", have = have, locked = not have, sel = pick == i,
                        icon = "asset:ui/mg-" .. i .. (have and "" or "-off") .. ".png" }
  end
  out.magicList = list
  local have = b8(O.magic + pick) ~= 0
  out.magicPick = { name = have and D.magic[pick].name or "", desc = have and D.magic[pick].desc or "Not found yet.",
                    icon = "asset:ui/mgbig-" .. pick .. (have and "" or "-off") .. ".png" }
end

local function pageConfig(out)
  local rows, seen, clash = {}, {}, false
  for i, r in ipairs(CONFIG_ROWS) do
    local v = b16(O.config + r.off)
    local k = keyText(v)
    rows[i] = { row = i, label = r.label, key = k, keyImg = "asset:ui/key-" .. (k == "?" and "A" or k) .. ".png" }
    if seen[v] then clash = true end
    seen[v] = true
  end
  out.cfgRows, out.cfgClash = rows, clash
end

-- the explored map, drawn like the game's own (gamemap.lua + mapdata.lua): one font glyph per cell, 6.9376 px = 4 game px x 4 device px
local GM, MAPDATA = pack.require("gamemap"), pack.require("mapdata")
local CELLPX = 6.9376
local mapSig, mapBuilt
local function mapWords(r) return mem.u32(R_MAP + r * 8), mem.u32(R_MAP + r * 8 + 4) end
local function pageMap(out)
  local sig = GM.signature(MAPDATA, mapWords)
  if sig ~= mapSig or not mapBuilt then mapBuilt, mapSig = GM.build(MAPDATA, mapWords), sig end
  out.mapFill, out.mapSave, out.mapWarp, out.mapWalls, out.mapDoors = mapBuilt.fill, mapBuilt.save, mapBuilt.warp, mapBuilt.walls, mapBuilt.doors
  -- Soma's cell. The room's origin cell is kept at 0x020274B4 (x) / B5 (y); Soma's position inside the room is in pixels at 0x02000036 (x) / 3A (y);
  -- a cell is 256 px wide (x: origin + px // 256) and, measured against the game re-marking the cell he stands in, y = origin + ceil(py / 256).
  local ox, oy = mem.u8(0x020274B4), mem.u8(0x020274B5)
  local px, py = mem.u16(0x02000036), mem.u16(0x0200003A)
  local cx, cy = ox + px // 256, oy + (py + 255) // 256
  local on = (ox > 0 or oy > 0) and ox < 64 and oy < 42 and px < 4096 and py < 2048 and cx < 64 and cy < 42
  out.me = { on = on, left = string.format("%.2fpx", (cx + 0.5) * CELLPX - 5 * 2.168), top = string.format("%.2fpx", (cy + 0.5) * CELLPX - 5 * 2.168) }
  out.meText = on and string.format("%d,%d", cx, cy) or "--"
end

-- ---------------------------------------------------------------------------------------------
-- live alerts: a card found, a magic item found, a level gained
local prev, tick, toast = nil, 0, nil
local function watch(out, ui)
  tick = tick + 1
  local now = { cards = B:sub(O.cards + 1, O.cards + 20), magic = B:sub(O.magic + 1, O.magic + 9), level = b16(O.level), maxHp = b16(O.maxHp) }
  if prev and now.level >= prev.level and now.level - prev.level <= 3 then
    local found, n = nil, 0
    for k = 0, 19 do
      if now.cards:byte(k + 1) ~= 0 and prev.cards:byte(k + 1) == 0 then
        n = n + 1
        found = { title = "CARD GET", name = D.cards[k].name, sub = D.cards[k].desc, img = "asset:game/cardt-" .. k .. ".png", page = "dss", card = k, magic = -1 }
      end
    end
    for i = 0, 8 do
      if now.magic:byte(i + 1) ~= 0 and prev.magic:byte(i + 1) == 0 then
        n = n + 1
        found = { title = "MAGIC ITEM", name = D.magic[i].name, sub = D.magic[i].desc, img = (i == 5) and "asset:ui/tab-map.png" or ("asset:game/mgt-" .. i .. ".png"), page = "status", card = -1, magic = i }
      end
    end
    if now.level > prev.level then
      n = n + 1
      found = { title = "LEVEL UP", name = "LV " .. now.level, sub = "Max HP " .. prev.maxHp .. " > " .. now.maxHp, img = "asset:game/portrait-nathan.png", page = "status", card = -1, magic = -1 }
    end
    if found and n <= 3 then found.id = tick; found.untilTick = tick + 24; toast = found end
  end
  prev = now
  out.toastOn = toast ~= nil and tick < toast.untilTick and (tonumber(ui.toastHide) or -1) ~= toast.id
  out.toast = toast or { id = 0, title = "", name = "", sub = "", img = "asset:game/portrait-nathan.png", page = "status", card = -1, magic = -1 }
end

function update(ui)
  if not romOk then
    return { ready = false, waiting = true, wrongRom = mem.u32(0x08000000) ~= 0 and mem.read(0x080000AC, 4) ~= CODE }
  end
  B = mem.read(R, BLOCK_N)
  local level, maxHp = b16(O.level), b16(O.maxHp)
  if level < 1 or level > 99 or maxHp == 0 or maxHp > 9999 or mem.u32(R_FRAMES) == 0 then
    return { ready = false, waiting = true, wrongRom = false }
  end
  local out = { ready = true, waiting = false }
  status(out)
  local hp, mx = b16(O.hp), b16(O.maxHp)
  local best = nil
  if hp < mx then
    for id = 41, 54 do
      local e = D.equip[id]
      if e.heal == "hp" and b8(O.count + id) > 0 then
        if not best or (e.amount >= mx - hp and (D.equip[best].amount < mx - hp or e.amount < D.equip[best].amount))
           or (D.equip[best].amount < mx - hp and e.amount > D.equip[best].amount) then best = id end
      end
    end
  end
  out.heal = { can = best ~= nil, off = best == nil, name = best and (D.equip[best].name .. " x" .. b8(O.count + best)) or (hp >= mx and "HP full" or "No potions"), id = best or -1 }
  local page = ui.page or "status"
  if page == "dss" then pageDss(out, ui)
  elseif page == "gear" then local u2 = setmetatable({ itemTab = clampInt(ui.itemTab or 1, 1, 3) }, { __index = ui }); pageItem(out, u2); out.itemTabs[4] = nil
  elseif page == "items" then local u2 = setmetatable({ itemTab = 4 }, { __index = ui }); pageItem(out, u2)
  elseif page == "card" then pageCard(out, ui)
  elseif page == "magic" then pageMagic(out, ui)
  elseif page == "config" then pageConfig(out)
  elseif page == "map" then pageMap(out) end
  out.onStatus, out.onDss, out.onGear, out.onItems, out.onMap = page == "status", page == "dss" or page == "card", page == "gear", page == "items", page == "map"
  out.onConfig = page == "config"
  out.note = ui.note or ""
  watch(out, ui)
  return out
end

-- ---------------------------------------------------------------------------------------------
-- taps that change the game (Settings > Packs can change games)
actions = {}

local function inGame()
  if not romOk then return false end
  B = mem.read(R, BLOCK_N)
  local lv = b16(O.level)
  return lv >= 1 and lv <= 99 and mem.u32(R_FRAMES) > 0
end
local function fail(why) return { set = { note = "Not changed: " .. tostring(why or "refused") } } end

function actions.setDss(attr1, act1)
  attr1, act1 = clampInt(attr1, 1, 10), clampInt(act1, 1, 10)
  if not inGame() or not owned(attr1 - 1) or not owned(10 + act1 - 1) then return end
  local ok, why = mem.write8(R + O.attr, attr1)
  if not ok then return fail(why) end
  ok, why = mem.write8(R + O.action, act1)
  if not ok then return fail(why) end
  return { set = { note = ACTION_NAMES[act1 - 1] .. " + " .. ATTR_NAMES[attr1 - 1] .. " set. Press DSS in the game." } }
end

-- wear `id` (0 = take off) in slot tab 1-3; the bag gives one up and takes the old one back, the totals follow at once
function actions.equip(tab, id)
  tab, id = clampInt(tab, 1, 3), clampInt(id, 0, 40)
  if not inGame() then return end
  local slot = SLOTS[tab]
  local old = b8(slot.off)
  if old == id then return end
  if id ~= 0 then
    if D.equip[id].kind ~= (tab == 1 and "body" or "arm") or b8(O.count + id) == 0 then return end
  end
  local cur = { b8(O.body), b8(O.armR), b8(O.armL) }
  local new = { cur[1], cur[2], cur[3] }
  new[tab] = id
  local a, b = gearSum(cur[1], cur[2], cur[3]), gearSum(new[1], new[2], new[3])
  local ok, why = mem.write8(R + slot.off, id)
  if not ok then return fail(why) end
  if id ~= 0 then mem.write8(R + O.count + id, b8(O.count + id) - 1) end
  if old ~= 0 then mem.write8(R + O.count + old, math.min(255, b8(O.count + old) + 1)) end
  for s = 0, 3 do
    for k = 1, 3 do   -- every running total after the base
      local v = stat(s, k) + b[s + 1] - a[s + 1]
      mem.write16(R + O.stats + s * 8 + k * 2, math.max(0, math.min(9999, v)))
    end
  end
  return { set = { note = (id == 0 and "Removed." or (D.equip[id].name .. " equipped.")) } }
end

function actions.useItem(id)
  id = clampInt(id, 41, 54)
  if not inGame() then return end
  local e = D.equip[id]
  local n = b8(O.count + id)
  if n == 0 or not e.heal then return end
  local cur, max
  if e.heal == "hp" then cur, max = O.hp, O.maxHp elseif e.heal == "mp" then cur, max = O.mp, O.maxMp else cur, max = O.heart, O.maxHeart end
  local v, m = b16(cur), b16(max)
  if v >= m then return { set = { note = "Already full." } } end
  local add = e.amount or 0
  if e.mpPct then add = math.ceil(m * e.mpPct / 100) end
  local ok, why = mem.write16(R + cur, math.min(m, v + add))
  if not ok then return fail(why) end
  ok, why = mem.write8(R + O.count + id, n - 1)
  if not ok then return fail(why) end
  return { set = { note = e.name .. " used." } }
end

function actions.quickHeal(id)
  id = tonumber(id) or -1
  if id < 41 then return { set = { note = "No healing items." } } end
  return actions.useItem(id)
end

function actions.cycleKey(row, dir)
  row, dir = clampInt(row, 1, 4), clampInt(dir, -1, 1)
  if not inGame() then return end
  local off = CONFIG_ROWS[row].off
  local cur = b16(O.config + off)
  local at = 1
  for k, v in ipairs(KEYS) do if v.v == cur then at = k end end
  local want = KEYS[(at - 1 + dir) % #KEYS + 1].v
  for _, r in ipairs(CONFIG_ROWS) do
    if r.off ~= off and b16(O.config + r.off) == want then
      local ok, why = mem.write16(R + O.config + r.off, cur)
      if not ok then return fail(why) end
    end
  end
  local ok, why = mem.write16(R + O.config + off, want)
  if not ok then return fail(why) end
end

function actions.defaultKeys()
  if not inGame() then return end
  for off, v in pairs(CONFIG_DEFAULT) do
    local ok, why = mem.write16(R + O.config + off, v)
    if not ok then return fail(why) end
  end
  return { set = { note = "Default buttons restored." } }
end
