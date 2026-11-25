-- Castlevania: Aria of Sorrow (USA, A2CE) companion.
-- Every name, description and number comes from the player's ROM at load time (init) or from RAM each tick,
-- so the pack ships no game text. Addresses and table layouts are in NOTES.md.

local CODE = "A2CE"

-- ROM tables (USA 1.0)
local STR_PTRS   = 0x08506BD8   -- u32 pointers; each string starts with 2 control bytes, 0x06 = newline, 0x0A = end
local ITEM_ROWS  = 0x08505B38   -- 32 x 16 bytes: +6 string id, +8 price, +12 kind (0 HP,1 MP%,2 cure,3 rotten,4 key), +14 value
local WEAP_ROWS  = 0x08505D38   -- 59 x 28 bytes: +12 type, +14 ATT, +16 STR, +17 CON, +18 INT, +19 LCK
local ARMOR_ROWS = 0x085063AC   -- 45 x 20 bytes: +12 slot (0 body, 1 accessory), +14 ATT, +15 DEF, +16 STR .. +19 LCK
local BULLET_MP  = 0x080E15A6   -- 55 x 16 bytes, MP at +8
local GUARD_MP   = 0x080E1938   -- 24 x 12 bytes, +4 MP, +5 cost kind (1 = per second)
local ENEMY_ROWS = 0x080E9644   -- 113 x 36 bytes: +8/+10 drops (item+1), +12 HP, +16 EXP, +23 soul type, +24 soul id, +26 weak, +28 tolerance

-- string ids
local S_ITEM, S_WEAP, S_ARMOR, S_SOUL = 51, 83, 142, 187
local S_ITEM_D, S_WEAP_D, S_ARMOR_D, S_SOUL_D = 308, 340, 399, 444
local S_ENEMY, S_ENEMY_D = 565, 678

-- RAM (EWRAM)
local R_FRAMES = 0x020000AC     -- u32 play time in frames
local R_RATE   = 0x020000A6     -- u16 map rate, tenths of a percent
local R_TOTALS = 0x020131EE     -- u16 ATT, DEF, STR, CON, INT, LCK (worked out by the game when the pause menu opens)
local R_BLOCK  = 0x02013260     -- the save block: equipment, stats, inventory, souls, flags
local BLOCK_N  = 0x150
local O = {   -- offsets inside the block
  weapon = 0x08, bullet = 0x09, guardian = 0x0A, enchant = 0x0B, armor = 0x0C, accessory = 0x0D,
  level = 0x19, hp = 0x1A, mp = 0x1C, maxHp = 0x1E, maxMp = 0x20,
  exp = 0x2C, gold = 0x30, inv = 0x34,
  abilityOn = 0x136, config = 0x138, bestiary = 0x140,
}
local SOUL_BASE = { 0x0201331C, 0x02013354, 0x0201336E, 0x02013392 }   -- 4-bit counts, low nibble first
local CATS = {
  { key = "bullet",   name = "Bullet",   count = 55, first = 0,   color = "red",    hex = "#ff4838" },
  { key = "guardian", name = "Guardian", count = 24, first = 56,  color = "blue",   hex = "#7b8bff" },
  { key = "enchant",  name = "Enchant",  count = 35, first = 80,  color = "yellow", hex = "#ffd040" },
  { key = "ability",  name = "Ability",  count = 6,  first = 115, color = "grey",   hex = "#c8c8d8" },
}
local SOUL_TOTAL = 120   -- the bullet table's 56th slot is an unused second Cagnazzo
local ELEMENTS = { "slash", "fire", "water", "thunder", "dark", "holy", "poison", "curse", "stone" }
local ELEMENT_NAMES = { "Slash", "Fire", "Water", "Thunder", "Darkness", "Holy", "Poison", "Curse", "Stone" }
local KEYS = { { v = 0x0001, t = "A" }, { v = 0x0002, t = "B" }, { v = 0x0200, t = "L" }, { v = 0x0100, t = "R" } }
local CONFIG_ROWS = { { label = "ATTACK", off = 0 }, { label = "JUMP", off = 2 }, { label = "GUARDIAN", off = 6 }, { label = "ABILITY", off = 4 } }
local CONFIG_DEFAULT = { [0] = 0x0002, [2] = 0x0001, [4] = 0x0200, [6] = 0x0100 }   -- B, A, L, R

-- weapon art by the ROM's weapon type byte (+12): which icon to draw
-- (0 swing, 1 heavy swing, 2 thrust, 3 punch, 4 gun, 5 Valmanway); names pick the heavy and thrust kinds apart
local WEAPON_ICON = { [0] = "sword", [1] = "greatsword", [2] = "spear", [3] = "fist", [4] = "gun", [5] = "sword" }
local function weaponIcon(type, name)
  if name:find("Hammer") then return "hammer" end
  if name:find("Axe") or name:find("Sickle") then return "axe" end
  if name:find("Rifle") then return "gun" end
  if type == 2 and (name:find("Rapier") or name:find("Estoc") or name:find("Cutall")) then return "sword" end
  if type == 1 then
    for _, k in ipairs({ "Katana", "Osafune", "Onikiri", "Kunitsuna", "Yasutsuna", "Muramasa", "Bamboo" }) do
      if name:find(k) then return "katana" end
    end
  end
  return WEAPON_ICON[type] or "sword"
end

local D = nil          -- static data from the ROM
local romOk = false

-- ---------------------------------------------------------------------------------------------
-- ROM reading
local function rstr(id)
  local p = mem.u32(STR_PTRS + id * 4)
  if p < 0x08000000 or p >= 0x0A000000 then return "" end
  local raw = mem.read(p + 2, 160)
  local e = raw:find("\0", 1, true)
  if e then raw = raw:sub(1, e - 1) end
  -- 0x0B-0x10 are button pictures (Attack, Jump, Ability, Guardian, Up, Down): kept as markers, filled per tick
  local out = raw:gsub("\n", ""):gsub("\6", " "):gsub("[\11-\16]", function(c) return "\127" .. string.char(c:byte() + 54) end)
  out = out:gsub("[%z\1-\31]", ""):gsub("%s+", " ")
  return (out:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function itemName(gid)   -- 0..135 over items, weapons, armor+accessories
  if gid < 32 then return D.items[gid].name end
  if gid < 91 then return D.weapons[gid - 32].name end
  if gid < 136 then return D.armor[gid - 91].name end
  return "???"
end

local function bonusText(t)
  local parts = {}
  if (t.att or 0) > 0 then parts[#parts + 1] = "ATT " .. t.att end
  if (t.def or 0) > 0 then parts[#parts + 1] = "DEF " .. t.def end
  for _, k in ipairs({ "str", "con", "int", "lck" }) do
    local v = t[k] or 0
    if v ~= 0 then parts[#parts + 1] = k:upper() .. (v > 0 and "+" or "") .. v end
  end
  return table.concat(parts, "  ")
end

local function buildData()
  D = { items = {}, weapons = {}, armor = {}, souls = {}, enemies = {} }
  for i = 0, 31 do
    local r = ITEM_ROWS + i * 16
    D.items[i] = { name = rstr(S_ITEM + i), desc = rstr(S_ITEM_D + i), kind = mem.u16(r + 12), value = mem.u16(r + 14) }
  end
  for i = 0, 58 do
    local r = WEAP_ROWS + i * 28
    local w = { name = rstr(S_WEAP + i), desc = rstr(S_WEAP_D + i), type = mem.u8(r + 12), att = mem.u16(r + 14),
                str = mem.s8(r + 16), con = mem.s8(r + 17), int = mem.s8(r + 18), lck = mem.s8(r + 19) }
    w.icon = weaponIcon(w.type, w.name)
    w.stats = bonusText(w)
    D.weapons[i] = w
  end
  for i = 0, 44 do
    local r = ARMOR_ROWS + i * 20
    local a = { name = rstr(S_ARMOR + i), desc = rstr(S_ARMOR_D + i), slot = mem.u16(r + 12), att = mem.u8(r + 14), def = mem.u8(r + 15),
                str = mem.s8(r + 16), con = mem.s8(r + 17), int = mem.s8(r + 18), lck = mem.s8(r + 19) }
    if a.slot == 0 then a.icon = "armor"
    elseif i <= 27 then a.icon = "cloak"
    elseif a.name:find("Ring") then a.icon = "ring"
    else a.icon = "charm" end
    a.stats = bonusText(a)
    D.armor[i] = a
  end
  for c = 1, 4 do
    local cat = CATS[c]
    local list = {}
    for i = 0, cat.count - 1 do
      local s = { name = rstr(S_SOUL + cat.first + i), desc = rstr(S_SOUL_D + cat.first + i), cost = "" }
      if c == 1 and i < 55 then
        local mp = mem.u16(BULLET_MP + i * 16 + 8)
        if mp > 0 and mp < 1000 then s.cost, s.costN, s.costU = mp .. " MP", tostring(mp), "USE" end
      elseif c == 2 then
        local mp, kind = mem.u8(GUARD_MP + i * 12 + 4), mem.u8(GUARD_MP + i * 12 + 5)
        if mp > 0 then
          s.cost = kind == 1 and (mp .. " MP/s") or (mp .. " MP")
          s.costN, s.costU = tostring(mp), kind == 1 and "/TIME" or "USE"
        end
      end
      list[i] = s
    end
    D.souls[c] = list
  end
  for k = 0, 112 do
    local r = ENEMY_ROWS + k * 36
    local e = { name = rstr(S_ENEMY + k), desc = rstr(S_ENEMY_D + k), hp = mem.u16(r + 12), exp = mem.u16(r + 16),
                d1 = mem.u16(r + 8), d2 = mem.u16(r + 10), soulCat = mem.u8(r + 23), soulId = mem.u16(r + 24),
                weak = mem.u16(r + 26), tol = mem.u16(r + 28) }
    D.enemies[k] = e
  end
  -- drop names last: they need the item tables
  for k = 0, 112 do
    local e = D.enemies[k]
    e.drop1 = (e.d1 > 0 and e.d1 <= 136) and itemName(e.d1 - 1) or "---"
    e.drop2 = (e.d2 > 0 and e.d2 <= 136) and itemName(e.d2 - 1) or "---"
    if e.soulCat <= 3 and e.soulId >= 1 and e.soulId <= CATS[e.soulCat + 1].count then
      e.soulName = D.souls[e.soulCat + 1][e.soulId - 1].name
    else
      e.soulName = nil
    end
  end
  D.soulFrom, D.dropFrom = {}, {}
  for k = 0, 112 do
    local e = D.enemies[k]
    if e.soulName then
      local key = (e.soulCat + 1) * 1000 + e.soulId
      D.soulFrom[key] = D.soulFrom[key] or {}
      table.insert(D.soulFrom[key], k)
    end
    for _, d in ipairs({ e.d1, e.d2 }) do
      if d > 0 and d <= 136 then
        D.dropFrom[d - 1] = D.dropFrom[d - 1] or {}
        table.insert(D.dropFrom[d - 1], k)
      end
    end
  end
end

function init()
  romOk = mem.read(0x080000AC, 4) == CODE
  if romOk then buildData() end
end

-- ---------------------------------------------------------------------------------------------
-- helpers
local B = ""     -- this tick's copy of the save block
local function b8(o) return B:byte(o + 1) or 0 end
local function b16(o) return b8(o) | (b8(o + 1) << 8) end
local function b32(o) return b16(o) | (b16(o + 2) << 16) end

local function comma(n)
  local s = tostring(math.floor(n))
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (out:gsub("^,", ""))
end

local function expFor(level)   -- total EXP needed to reach level+1 (fits all 12 points read off the game)
  return 3 * level ^ 3 + 20 * level ^ 2 + 39 * level + 22
end

local function soulCount(c, i)
  local byte = mem.u8(SOUL_BASE[c] + (i >> 1))
  if i & 1 == 0 then return byte & 15 end
  return byte >> 4
end

local function clampInt(v, lo, hi)
  v = tonumber(v) or lo
  if v < lo then return lo end
  if v > hi then return hi end
  return math.floor(v)
end

local function elementList(bits)
  local out = {}
  for i = 1, 9 do
    if bits & (1 << (i - 1)) ~= 0 then out[#out + 1] = { icon = "asset:ui/el-" .. ELEMENTS[i] .. ".png", name = ELEMENT_NAMES[i] } end
  end
  return out
end

local function keyText(v)
  for _, k in ipairs(KEYS) do if k.v == v then return k.t end end
  return "?"
end

-- button pictures in descriptions, as the player's own buttons: \127 + 'A'.. ('A' Attack, 'B' Jump, 'C' Ability, 'D' Guardian, 'E' Up, 'F' Down)
local function fill(s)
  if not s or not s:find("\127", 1, true) then return s end
  local key = function(off) return keyText(b16(O.config + off)) end
  local map = { A = key(0), B = key(2), C = key(4), D = key(6), E = "Up", F = "Down" }
  return (s:gsub("\127(.)", function(c) return map[c] or "" end))
end

local function enemySeenAt(k) return mem.u8(0x020133A0 + (k >> 3)) & (1 << (k & 7)) ~= 0 end

-- "Bat, Giant Bat": the enemies in list ks the player has met, or "" (no spoilers)
local function seenNames(ks, max)
  local out = {}
  for _, k in ipairs(ks or {}) do
    if enemySeenAt(k) then out[#out + 1] = D.enemies[k].name end
    if #out >= (max or 2) then break end
  end
  return table.concat(out, ", ")
end

-- the data of what a slot holds now (nil = empty)
local function wornData(slot)
  if slot == "hand" then return D.weapons[b8(O.weapon)] end
  local v = b8(slot == "body" and O.armor or O.accessory)
  local a = v <= 44 and D.armor[v] or nil
  if a and a.slot == (slot == "body" and 0 or 1) then return a end
  return nil
end

-- what wearing `new` instead of `old` does to the totals: ATT = STR + weapon/armor ATT, DEF = armor DEF + CON / 2
-- (both hold on the game's own numbers: 232 = 203 + 29, 125 = 38 + 175 // 2)
local STAT_KEYS = { "att", "def", "str", "con", "int", "lck" }
local function afterSwap(tot, new, old)
  local function f(t, k) return t and (t[k] or 0) or 0 end
  local d = {}
  for _, k in ipairs(STAT_KEYS) do d[k] = f(new, k) - f(old, k) end
  local n = { str = tot.str + d.str, con = tot.con + d.con, int = tot.int + d.int, lck = tot.lck + d.lck }
  n.att = tot.att + d.att + d.str
  n.def = tot.def + d.def + (n.con // 2 - tot.con // 2)
  for _, k in ipairs(STAT_KEYS) do if n[k] < 0 then n[k] = 0 end end
  return n
end

local function statView(tot, n)
  local out = {}
  for _, k in ipairs(STAT_KEYS) do
    local v = n and n[k] or tot[k]
    out[k] = { v = tostring(v), up = n ~= nil and v > tot[k], down = n ~= nil and v < tot[k] }
  end
  return out
end

-- where a tap on an item goes: its Items tab or its Equip slot, with it picked
local function itemLinkRaw(gid)
  if gid < 0 or gid > 135 then return { ok = false, page = "status", eqSlot = 1, eqItem = -1, item = -1, itemTab = "use" } end
  if gid < 32 then return { ok = true, page = "items", eqSlot = 1, eqItem = -1, item = gid, itemTab = D.items[gid].kind == 4 and "key" or "use" } end
  if gid < 91 then return { ok = true, page = "equip", eqSlot = 1, eqItem = gid - 32, item = -1, itemTab = "use" } end
  local i = gid - 91
  return { ok = true, page = "equip", eqSlot = D.armor[i].slot == 0 and 2 or 3, eqItem = i, item = -1, itemTab = "use" }
end

-- the cheapest healing item that fills the gap, else the strongest one
local function itemLink(gid)
  local l = itemLinkRaw(gid)
  l.off = not l.ok
  return l
end

local function bestHeal(missing, count)
  local cover, big = nil, nil
  for i = 0, 31 do
    local it = D.items[i]
    if it.kind == 0 and count(i) > 0 then
      if it.value >= missing then
        if not cover or it.value < D.items[cover].value then cover = i end
      elseif not big or it.value > D.items[big].value then big = i end
    end
  end
  return cover or big
end

-- which entries an equipment slot lists: { gid, idx (value written to the slot byte), data }
local function slotEntries(slot)
  local out = {}
  if slot == "hand" then
    for i = 0, 58 do out[#out + 1] = { gid = 32 + i, idx = i, d = D.weapons[i] } end
  else
    local want = slot == "body" and 0 or 1
    for i = 0, 44 do
      if D.armor[i].slot == want then out[#out + 1] = { gid = 91 + i, idx = i, d = D.armor[i] } end
    end
  end
  return out
end

-- ---------------------------------------------------------------------------------------------
-- pages
local MENU = {
  { label = "SOUL SET",  page = "soul",    hint = "Change spirit's equipment." },
  { label = "EQUIP",     page = "equip",   hint = "Change weapons, armor and accessories." },
  { label = "ITEM USE",  page = "items",   hint = "View or use an item." },
  { label = "ABILITY",   page = "ability", hint = "Switch ability souls on and off." },
  { label = "ENEMY",     page = "enemy",   hint = "View the data of defeated enemies." },
  { label = "CONFIG",    page = "config",  hint = "Change the button configuration." },
}

local function equippedSummary(out)
  local w = b8(O.weapon)
  local a = b8(O.armor)
  local x = b8(O.accessory)
  local function gear(label, d, path)
    if d then return { label = label, name = d.name, icon = path, none = false } end
    return { label = label, name = "---", icon = "asset:ui/ic-none.png", none = true }
  end
  out.gear = {
    gear("HAND", D.weapons[w], "asset:game/w-" .. w .. ".png"),
    gear("BODY", (a <= 44 and D.armor[a].slot == 0) and D.armor[a] or nil, "asset:game/a-" .. a .. ".png"),
    gear("ACC.", (x <= 44 and D.armor[x].slot == 1) and D.armor[x] or nil, "asset:game/a-" .. x .. ".png"),
  }
  for i, g in ipairs(out.gear) do g.i = i end
  local sl = {}
  for c = 1, 3 do
    local id = b8(({ O.bullet, O.guardian, O.enchant })[c])
    local s = (id >= 1 and id <= CATS[c].count) and D.souls[c][id - 1] or nil
    sl[c] = { i = c, cat = CATS[c].key, name = s and s.name or "---", on = s ~= nil, off = s == nil, hex = CATS[c].hex,
              orb = s and ("asset:game/orb-" .. CATS[c].color .. ".png") or "asset:ui/orb-" .. CATS[c].color .. "-off.png" }
  end
  out.souls = sl
  out.orb1, out.orb2, out.orb3 = sl[1].orb, sl[2].orb, sl[3].orb
end

local pageAbility
local function pageSoul(out, ui)
  local cat = clampInt(ui.soulCat or 1, 1, 4)
  out.isAbil, out.notAbil = cat == 4, cat ~= 4
  out.soulTabs = {}
  for c = 1, 3 do
    local id = b8(({ O.bullet, O.guardian, O.enchant })[c])
    local s = (id >= 1 and id <= CATS[c].count) and D.souls[c][id - 1] or nil
    out.soulTabs[c] = { c = c, sel = c == cat, name = out.souls[c].name, label = CATS[c].name:upper(), key = CATS[c].key, hex = CATS[c].hex,
                        big = "asset:game/orbbig-" .. CATS[c].color .. ".png", badge = s and s.costN or "" }
  end
  local nAbil = 0
  for i = 0, 5 do if soulCount(4, i) > 0 then nAbil = nAbil + 1 end end
  out.soulTabs[4] = { c = 4, sel = cat == 4, name = "", label = "ABILITY", key = "ability", hex = CATS[4].hex, big = "asset:game/orbbig-grey.png", badge = nAbil .. "/6" }
  if cat == 4 then
    pageAbility(out, ui)
    out.soulList, out.soulOwned = {}, ""
    out.soulPick = { name = "", desc = "", from = "", cost = "", costN = "", costU = "", hasCost = false, id = -1, cat = 4, canSet = false, isSet = false }
    return
  end
  local slotOff = ({ O.bullet, O.guardian, O.enchant })[cat]
  local equipped = b8(slotOff)
  local pick = tonumber(ui.soul) or -1
  if pick < 0 then pick = equipped end
  pick = clampInt(pick, 0, CATS[cat].count)
  out.soulBig = "asset:game/orbbig-" .. CATS[cat].color .. ".png"
  local list = { { id = 0, name = "---", count = "", sel = pick == 0, equipped = equipped == 0, orb = "asset:ui/orb-none.png" } }
  local owned = 0
  for i = 0, CATS[cat].count - 1 do
    local n = soulCount(cat, i)
    if n > 0 then
      owned = owned + 1
      list[#list + 1] = { id = i + 1, name = D.souls[cat][i].name, count = tostring(n), sel = pick == i + 1,
                          equipped = equipped == i + 1, orb = "asset:game/orb-" .. CATS[cat].color .. ".png" }
    end
  end
  out.soulList = list
  out.soulOwned = owned .. " / " .. CATS[cat].count
  out.soulCatName = CATS[cat].name:upper() .. " SOULS"
  out.soulCatKey = CATS[cat].key
  if pick >= 1 and soulCount(cat, pick - 1) > 0 then
    local s = D.souls[cat][pick - 1]
    local from = seenNames(D.soulFrom[cat * 1000 + pick])
    out.soulPick = { name = s.name, desc = fill(s.desc), from = from ~= "" and ("From " .. from) or "", cost = s.cost, costN = s.costN or "--", costU = s.costU or (cat == 3 and "PASSIVE" or ""),
                     hasCost = s.cost ~= "", id = pick, cat = cat,
                     canSet = equipped ~= pick, isSet = equipped == pick }
  elseif pick == 0 then
    out.soulPick = { name = "---", desc = "Take the " .. CATS[cat].name:lower() .. " soul off.", from = "", cost = "", costN = "", costU = "", hasCost = false, id = 0, cat = cat,
                     canSet = equipped ~= 0, isSet = equipped == 0 }
  else
    out.soulPick = { name = "", desc = "Tap a soul to read it.", from = "", cost = "", costN = "", costU = "", hasCost = false, id = -1, cat = cat, canSet = false, isSet = false }
  end
end

local function pageEquip(out, ui)
  local slots = { "hand", "body", "acc" }
  local si = clampInt(ui.eqSlot or 1, 1, 3)
  local slot = slots[si]
  out.eqSlotName = ({ "WEAPONS", "ARMOR", "ACCESSORIES" })[si]
  local cur = ({ hand = b8(O.weapon), body = b8(O.armor), acc = b8(O.accessory) })[slot]
  out.eqSlots = {}
  for i, s in ipairs(slots) do out.eqSlots[i] = { i = i, sel = s == slot, label = out.gear[i].label, name = out.gear[i].name, icon = out.gear[i].icon } end
  local list = {}
  local pickIdx = tonumber(ui.eqItem) or -1
  for _, e in ipairs(slotEntries(slot)) do
    local n = b8(O.inv + e.gid)
    if e.idx == cur and n > 0 then n = n - 1 end   -- the game counts the worn one; its list does not show it
    if n > 0 then
      list[#list + 1] = { idx = e.idx, name = e.d.name, count = tostring(n), icon = "asset:game/" .. (slot == "hand" and "w-" or "a-") .. e.idx .. ".png",
                          sel = pickIdx == e.idx }
    end
  end
  out.eqList = list
  out.eqEmpty = #list == 0
  out.eqCount = #list .. " owned"
  local d = nil
  if pickIdx >= 0 then d = (slot == "hand") and D.weapons[pickIdx] or D.armor[pickIdx] end
  if d then
    local gid = (slot == "hand" and 32 or 91) + pickIdx
    local owned = b8(O.inv + gid) > 0
    local canSet = owned and cur ~= pickIdx
    out.eqPick = { name = d.name, desc = fill(d.desc), stats = d.stats, icon = "asset:game/" .. (slot == "hand" and "w-" or "a-") .. pickIdx .. ".png", idx = pickIdx, slot = slot,
                   canSet = canSet, isSet = cur == pickIdx, notOwned = not owned }
    if canSet then out.sw = statView(out.tot, afterSwap(out.tot, d, wornData(slot))); out.cmpOn = true end
  else
    local w = (slot == "hand") and D.weapons[cur] or ((cur <= 44) and D.armor[cur] or nil)
    out.eqPick = { name = w and w.name or "---", desc = w and w.desc or "Nothing equipped.", stats = w and w.stats or "",
                   icon = w and ("asset:game/" .. (slot == "hand" and "w-" or "a-") .. cur .. ".png") or "asset:ui/ic-none.png", idx = -1, slot = slot, canSet = false, isSet = w ~= nil, notOwned = false }
  end
end

local function pageItems(out, ui)
  local list = {}
  local hp, maxHp, mp, maxMp = b16(O.hp), b16(O.maxHp), b16(O.mp), b16(O.maxMp)
  local key = ui.itemTab == "key"
  for i = 0, 31 do
    local it = D.items[i]
    local n = b8(O.inv + i)
    if n > 0 and ((it.kind == 4) == key) then
      list[#list + 1] = { i = i, name = it.name, count = tostring(n), sel = (tonumber(ui.item) or -1) == i, icon = "asset:game/i-" .. i .. ".png" }
    end
  end
  out.itemList = list
  out.itemEmpty = #list == 0
  out.itemKeyTab = key
  out.itemUseTab = not key
  out.itemCount = #list .. (key and " key items" or " kinds")
  local ii = tonumber(ui.item) or -1
  local pick = ii >= 0 and D.items[ii] or nil
  if pick then
    local have = b8(O.inv + ii)
    local useful = have > 0 and ((pick.kind == 0 and hp < maxHp) or (pick.kind == 1 and mp < maxMp))
    local what = ""
    if pick.kind == 0 then what = pick.value >= 5000 and "HP full" or ("HP +" .. pick.value)
    elseif pick.kind == 1 then what = pick.value >= 100 and "MP full" or ("MP +" .. pick.value .. "%")
    elseif pick.kind == 2 then what = "Cure" end
    out.itemPick = { name = pick.name, desc = fill(pick.desc), effect = what, i = ii, canUse = useful, usable = pick.kind <= 1,
                     full = have > 0 and pick.kind <= 1 and not useful, notOwned = have == 0,
                     icon = "asset:game/i-" .. ii .. ".png" }
  else
    out.itemPick = { name = "", desc = "Tap an item to read it.", effect = "", i = -1, canUse = false, usable = false, full = false, notOwned = false, icon = "asset:ui/ic-none.png" }
  end
end

function pageAbility(out, ui)
  local bits = b8(O.abilityOn)
  local list = {}
  for i = 0, 5 do
    local owned = soulCount(4, i) > 0
    local s = D.souls[4][i]
    list[#list + 1] = { i = i, name = owned and s.name or "?????????", owned = owned, locked = not owned,
                        on = owned and (bits & (1 << i)) ~= 0, off = owned and (bits & (1 << i)) == 0, sel = ui.abil == i,
                        orb = owned and "asset:game/orb-grey.png" or "asset:ui/orb-none.png" }
  end
  out.abilList = list
  local n = 0
  for _, a in ipairs(list) do if a.owned then n = n + 1 end end
  out.abilOwned = n .. "/6"
  local p = ui.abil and list[ui.abil + 1]
  if p and p.owned then
    out.abilPick = { name = p.name, desc = fill(D.souls[4][ui.abil].desc) }
  else
    out.abilPick = { name = "", desc = p and "You have not found this soul yet." or "Tap a soul to switch it on or off." }
  end
end

local function enemySeen(k) return mem.u8(0x02013260 + O.bestiary + (k >> 3)) & (1 << (k & 7)) ~= 0 end

local function enemySoulOwned(e)
  if not e.soulName then return false end
  return soulCount(e.soulCat + 1, e.soulId - 1) > 0
end

local function pageEnemy(out, ui)
  local pg = clampInt(ui.epage or 0, 0, 11)
  local rows = {}
  for r = 0, 9 do
    local k = pg * 10 + r
    if k <= 112 then
      local seen = enemySeen(k)
      rows[#rows + 1] = { k = k, no = string.format("%02d", k + 1), name = seen and D.enemies[k].name or "?????????", seen = seen, unseen = not seen }
    end
  end
  out.enemyRows = rows
  out.epageText = string.format("%02d/12", pg + 1)
  out.epagePrev = (pg + 11) % 12
  out.epageNext = (pg + 1) % 12
  local seenN = 0
  for k = 0, 112 do if enemySeen(k) then seenN = seenN + 1 end end
  out.enemySeen = seenN .. " / 113"
end

local function pageEnemyDetail(out, ui)
  local k = clampInt(ui.enemy or 0, 0, 112)
  local e = D.enemies[k]
  local seen = enemySeen(k)
  out.ed = {
    no = string.format("%02d", k + 1), seen = seen, unseen = not seen,
    name = seen and e.name or "?????????", hp = seen and comma(e.hp) or "???", exp = seen and comma(e.exp) or "???",
    desc = seen and fill(e.desc) or "Defeat this enemy to read its entry.",
    drop1 = seen and e.drop1 or "???", drop2 = seen and e.drop2 or "???",
    weak = seen and elementList(e.weak) or {}, tol = seen and elementList(e.tol) or {},
    noWeak = seen and e.weak & 0x1FF == 0, noTol = seen and e.tol & 0x1FF == 0,
    soul = (seen and e.soulName) or "---", soulOwned = enemySoulOwned(e), hasSoul = e.soulName ~= nil,
    orb = e.soulName and ("asset:game/orb-" .. CATS[e.soulCat + 1].color .. ".png") or "asset:ui/pip.png",
    prev = (k + 112) % 113, next = (k + 1) % 113,
    prevNo = string.format("%02d", (k + 112) % 113 + 1), nextNo = string.format("%02d", (k + 1) % 113 + 1), page = k // 10,
    soulLink = e.soulName and { ok = true, page = "soul", cat = e.soulCat + 1, soul = e.soulId, abil = e.soulId - 1 }
               or { ok = false, page = "enemyDetail", cat = 1, soul = -1, abil = -1 },
    l1 = itemLink(seen and e.d1 - 1 or -1), l2 = itemLink(seen and e.d2 - 1 or -1),
    orbBig = e.soulName and ("asset:game/orbbig-" .. CATS[e.soulCat + 1].color .. ".png") or "asset:ui/orb-none.png",
  }
end

local function pageConfig(out)
  local rows = {}
  for i, r in ipairs(CONFIG_ROWS) do
    local k = keyText(b16(O.config + r.off))
    rows[i] = { row = i, label = r.label, key = k, keyImg = "asset:game/key-" .. (k == "?" and "A" or k) .. ".png" }
  end
  out.cfgRows = rows
  local seen, clash = {}, false
  for _, r in ipairs(CONFIG_ROWS) do
    local v = b16(O.config + r.off)
    if seen[v] then clash = true end
    seen[v] = true
  end
  out.cfgClash = clash
end

-- ---------------------------------------------------------------------------------------------
-- live alerts: a soul absorbed, a level gained, a new bestiary entry. Compared tick to tick; a big jump (loading a
-- save) only resets the memory.
local SOUL_SPAN = 0x02013398 - 0x0201331C
local prev = nil
local tick, toast = 0, nil
local function soulCountIn(bytes, c, i)
  local byte = bytes:byte(SOUL_BASE[c] - 0x0201331C + (i >> 1) + 1) or 0
  return (i & 1 == 0) and (byte & 15) or (byte >> 4)
end

local function watch(out, ui, level, maxHp)
  tick = tick + 1
  local now = { souls = mem.read(0x0201331C, SOUL_SPAN), level = level, seen = mem.read(0x020133A0, 15), maxHp = maxHp }
  if prev and prev.level <= level and level - prev.level <= 3 then
    local changes, found = 0, nil
    for c = 1, 4 do
      for i = 0, CATS[c].count - 1 do
        local a, b = soulCountIn(prev.souls, c, i), soulCountIn(now.souls, c, i)
        if b > a then
          changes = changes + 1
          local s = D.souls[c][i]
          found = { kind = "soul", title = a == 0 and "NEW SOUL" or "SOUL GET", name = s.name,
                    sub = a == 0 and fill(s.desc) or ("Now x" .. b .. "   " .. fill(s.desc)),
                    orb = "asset:game/orb-" .. CATS[c].color .. ".png", page = "soul",
                    cat = c, soul = i + 1, abil = i, enemy = -1, hex = CATS[c].hex }
        end
      end
    end
    for k = 0, 112 do
      local bit = 1 << (k & 7)
      if (now.seen:byte((k >> 3) + 1) & bit) ~= 0 and (prev.seen:byte((k >> 3) + 1) & bit) == 0 then
        changes = changes + 1
        found = found or { kind = "enemy", title = "NEW ENEMY DATA", name = D.enemies[k].name, sub = "Tap to read its entry.",
                           orb = "asset:game/orb-grey.png", page = "enemyDetail", cat = 1, soul = -1, abil = -1, enemy = k, hex = "#d6d6ce" }
      end
    end
    if level > prev.level then
      changes = changes + 1
      found = { kind = "level", title = "LEVEL UP", name = "LV " .. level, sub = "Max HP " .. prev.maxHp .. " > " .. maxHp,
                orb = "asset:game/orbbig-red.png", page = "status", cat = 1, soul = -1, abil = -1, enemy = -1, hex = "#ff7321" }
    end
    if found and changes <= 3 then
      found.id = tick
      found.untilTick = tick + 24   -- 6 s at 4 ticks a second
      toast = found
    end
  end
  prev = now
  local on = toast ~= nil and tick < toast.untilTick and (tonumber(ui.toastHide) or -1) ~= toast.id
  out.toastOn = on
  out.toast = toast or { id = 0, title = "", name = "", sub = "", orb = "asset:ui/pip.png", page = "status", cat = 1, soul = -1, abil = -1, enemy = -1, hex = "#ffffff" }
end

-- the explored castle (the game's SELECT map): 40 rows of 8 bytes, the row's u32 twice, low bit = left;
-- columns 0-31 at MAP_L, 32-63 at MAP_R. 848 cells at 100.0%.
local MAP_L, MAP_R = 0x020000B4, 0x020001F4
local GM, MAPDATA = pack.require("gamemap"), pack.require("mapdata")
local CELLPX = 6.9376   -- 4 game px x 4 device px, one font glyph per cell
local mapSig, mapBuilt
local function mapWords(r) return mem.u32(MAP_L + r * 8), mem.u32(MAP_R + r * 8) end
-- where Soma is: the game's own map cell. X is stored whole at 0x0200008C; the position it draws from is kept as offsets from a fixed origin
-- (0x03001A0D across, 0x03007CD1 down, origin cell 28,6: checked in 2 rooms, the game re-marks exactly that cell). Shown only while the
-- offsets and the whole X agree, so a wrong guess hides the marker instead of misplacing it.
local POS_X, POS_LX, POS_LY, ORG_X, ORG_Y = 0x0200008C, 0x03001A0D, 0x03007CD1, 28, 6

function pageMap(out)
  local sig = GM.signature(MAPDATA, mapWords)
  if sig ~= mapSig or not mapBuilt then mapBuilt, mapSig = GM.build(MAPDATA, mapWords), sig end
  out.mapFill, out.mapSave, out.mapWarp, out.mapWalls, out.mapDoors = mapBuilt.fill, mapBuilt.save, mapBuilt.warp, mapBuilt.walls, mapBuilt.doors
  local n = 0
  for r = 0, 39 do
    local lo, hi = mapWords(r)
    while lo ~= 0 do lo = lo & (lo - 1); n = n + 1 end
    while hi ~= 0 do hi = hi & (hi - 1); n = n + 1 end
  end
  out.mapCells = n .. " / 848"
  local cx, lx, ly = mem.u8(POS_X), mem.u8(POS_LX), mem.u8(POS_LY)
  local cy = ORG_Y + ly
  local on = lx < 40 and ly < 34 and cx - lx == ORG_X and cx < 64 and cy < 40
  local mx0, my0, mx1, my1 = GM.bounds(MAPDATA)
  on = on and cx >= mx0 and cx <= mx1 and cy >= my0 and cy <= my1   -- the drawn window is cropped to the rooms (gamemap.bounds)
  out.me = { on = on, left = string.format("%.2fpx", (cx - mx0 + 0.5) * CELLPX - 5 * 2.168), top = string.format("%.2fpx", (cy - my0 + 0.5) * CELLPX - 5 * 2.168) }
  out.meText = on and string.format("%d,%d", cx, cy) or "--"
end

function update(ui)
  if not romOk then
    return { ready = false, waiting = true, wrongRom = mem.u32(0x08000000) ~= 0 and mem.read(0x080000AC, 4) ~= CODE }
  end
  B = mem.read(R_BLOCK, BLOCK_N)
  local level, maxHp, frames = b8(O.level), b16(O.maxHp), mem.u32(R_FRAMES)
  if level < 1 or level > 99 or maxHp == 0 or maxHp > 9999 or frames == 0 then
    return { ready = false, waiting = true, wrongRom = false }
  end
  local out = { ready = true, waiting = false }
  local hp, mp, maxMp = b16(O.hp), b16(O.mp), b16(O.maxMp)
  local exp = b32(O.exp)
  local t = mem.read(R_TOTALS, 12)
  local att, def, str, con, int, lck = string.unpack("<I2I2I2I2I2I2", t)
  local base, nxt = level <= 1 and 0 or expFor(level - 1), expFor(level)
  local secs = frames // 60
  out.st = {
    level = string.format("%02d", level), hp = hp, maxHp = maxHp, mp = mp, maxMp = maxMp,
    hpText = hp .. "/" .. maxHp, mpText = mp .. "/" .. maxMp, lowHp = hp * 4 <= maxHp,
    att = att, def = def, str = str, con = con, int = int, lck = lck,
    time = string.format("%02d:%02d:%02d", secs // 3600, (secs // 60) % 60, secs % 60),
    rate = string.format("%.1f%%", mem.u16(R_RATE) / 10), gold = comma(b32(O.gold)),
    exp = comma(exp), next = level >= 99 and "---" or comma(math.max(0, nxt - exp)),
    expIn = level >= 99 and 1 or math.max(0, exp - base), expSpan = level >= 99 and 1 or math.max(1, nxt - base),
  }
  out.tot = { att = att, def = def, str = str, con = con, int = int, lck = lck }
  out.sw = statView(out.tot)
  out.cmpOn = false
  local hi = hp < maxHp and bestHeal(maxHp - hp, function(i) return b8(O.inv + i) end) or nil
  out.heal = { can = hi ~= nil, full = hp >= maxHp, none = hp < maxHp and hi == nil,
               name = hi and (D.items[hi].name .. " x" .. b8(O.inv + hi)) or (hp >= maxHp and "HP full" or "No potions") }
  local owned = 0
  for c = 1, 4 do for i = 0, CATS[c].count - 1 do if soulCount(c, i) > 0 then owned = owned + 1 end end end
  out.st.soulRate = string.format("%.1f%%", math.floor(owned * 1000 / SOUL_TOTAL) / 10)
  out.st.souls = owned .. "/" .. SOUL_TOTAL
  equippedSummary(out)
  out.menu = {}
  for i, m in ipairs(MENU) do out.menu[i] = { label = m.label, page = m.page, hint = m.hint, sel = ui.menuHint == i } end
  out.menuHint = MENU[clampInt(ui.menuHint or 1, 1, #MENU)].hint

  local page = ui.page or "status"
  if page == "soul" then pageSoul(out, ui)
  elseif page == "equip" then pageEquip(out, ui)
  elseif page == "items" then pageItems(out, ui)
  elseif page == "ability" then pageAbility(out, ui)
  elseif page == "enemy" then pageEnemy(out, ui)
  elseif page == "enemyDetail" then pageEnemyDetail(out, ui)
  elseif page == "config" then pageConfig(out)
  elseif page == "map" then pageMap(out) end
  out.onStatus, out.onSoul, out.onEquip, out.onItems, out.onMap = page == "status", page == "soul", page == "equip", page == "items", page == "map"
  out.onEnemy, out.onConfig = page == "enemy" or page == "enemyDetail", page == "config"
  out.note = ui.note or ""
  watch(out, ui, level, maxHp)
  return out
end

-- ---------------------------------------------------------------------------------------------
-- taps that change the game (need Settings > Packs can change games)
actions = {}

local function inGame()
  local lv = mem.u8(R_BLOCK + O.level)
  return romOk and lv >= 1 and lv <= 99 and mem.u32(R_FRAMES) > 0
end

local function result(ok, why, okText)
  if ok then return { set = { note = okText } } end
  return { set = { note = "Not changed: " .. tostring(why or "refused") } }
end

function actions.setSoul(cat, id)
  cat, id = clampInt(cat, 1, 3), clampInt(id, 0, 56)
  if not inGame() then return end
  if id > CATS[cat].count or (id > 0 and soulCount(cat, id - 1) == 0) then return end
  local ok, why = mem.write8(R_BLOCK + ({ O.bullet, O.guardian, O.enchant })[cat], id)
  return result(ok, why, "Soul set. Pause once to refresh ATT and DEF.")
end

function actions.equip(slot, idx)
  idx = clampInt(idx, 0, 58)
  if not inGame() then return end
  local off, gid
  if slot == "hand" then off, gid = O.weapon, 32 + idx
  else
    if idx > 44 then return end
    local want = slot == "body" and 0 or 1
    if D.armor[idx].slot ~= want then return end
    off, gid = (slot == "body") and O.armor or O.accessory, 91 + idx
  end
  if mem.u8(R_BLOCK + O.inv + gid) == 0 then return end
  B = mem.read(R_BLOCK, BLOCK_N)
  local old = wornData(slot)
  local new = slot == "hand" and D.weapons[idx] or D.armor[idx]
  local ok, why = mem.write8(R_BLOCK + off, idx)
  if not ok then return result(false, why) end
  -- the game redoes its totals only when its pause menu opens: do the same sums now so the new gear counts at once
  local t = { string.unpack("<I2I2I2I2I2I2", mem.read(R_TOTALS, 12)) }
  local tot = { att = t[1], def = t[2], str = t[3], con = t[4], int = t[5], lck = t[6] }
  local n = afterSwap(tot, new, old)
  for k, key in ipairs(STAT_KEYS) do
    if n[key] ~= tot[key] then mem.write16(R_TOTALS + (k - 1) * 2, n[key]) end
  end
  return { set = { note = new.name .. " equipped." } }
end

function actions.useItem(i)
  i = clampInt(i, 0, 31)
  if not inGame() then return end
  local it = D.items[i]
  local n = mem.u8(R_BLOCK + O.inv + i)
  if n == 0 or it.kind > 1 then return end
  local addr, maxAddr = R_BLOCK + O.hp, R_BLOCK + O.maxHp
  local add = it.value
  if it.kind == 1 then
    addr, maxAddr = R_BLOCK + O.mp, R_BLOCK + O.maxMp
    add = math.ceil(mem.u16(maxAddr) * it.value / 100)
  end
  local cur, max = mem.u16(addr), mem.u16(maxAddr)
  if cur >= max then return { set = { note = "Already full." } } end
  local ok, why = mem.write16(addr, math.min(max, cur + add))
  if not ok then return result(false, why) end
  ok, why = mem.write8(R_BLOCK + O.inv + i, n - 1)
  return result(ok, why, it.name .. " used.")
end

function actions.quickHeal()
  if not inGame() then return end
  B = mem.read(R_BLOCK, BLOCK_N)
  local hp, maxHp = b16(O.hp), b16(O.maxHp)
  if hp >= maxHp then return { set = { note = "HP is full." } } end
  local i = bestHeal(maxHp - hp, function(k) return b8(O.inv + k) end)
  if not i then return { set = { note = "No healing items." } } end
  return actions.useItem(i)
end

function actions.toggleAbility(i)
  i = clampInt(i, 0, 5)
  if not inGame() or soulCount(4, i) == 0 then return end
  local a = R_BLOCK + O.abilityOn
  local ok, why = mem.write8(a, mem.u8(a) ~ (1 << i))
  return result(ok, why, "")
end

-- step a control to the next / previous button; the action that had it takes the old one, so they never clash
function actions.cycleKey(row, dir)
  row, dir = clampInt(row, 1, 4), clampInt(dir, -1, 1)
  if not inGame() then return end
  local off = CONFIG_ROWS[row].off
  local cur = mem.u16(R_BLOCK + O.config + off)
  local at = 1
  for k, v in ipairs(KEYS) do if v.v == cur then at = k end end
  local want = KEYS[(at - 1 + dir) % #KEYS + 1].v
  for _, r in ipairs(CONFIG_ROWS) do
    if r.off ~= off and mem.u16(R_BLOCK + O.config + r.off) == want then
      local ok, why = mem.write16(R_BLOCK + O.config + r.off, cur)
      if not ok then return result(false, why) end
    end
  end
  local ok, why = mem.write16(R_BLOCK + O.config + off, want)
  return result(ok, why, "")
end

function actions.defaultKeys()
  if not inGame() then return end
  for off, v in pairs(CONFIG_DEFAULT) do
    local ok, why = mem.write16(R_BLOCK + O.config + off, v)
    if not ok then return result(false, why) end
  end
  return { set = { note = "Default settings restored." } }
end
