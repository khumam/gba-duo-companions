-- Summon Night: Swordcraft Story (USA, AB4E) companion: main.lua  v0.3
-- Names and descriptions are read from the player's ROM at runtime (Shift-JIS, full-width
-- Latin). Battle sprites are drawn live from the game's sprite memory. Addresses: NOTES.md.

local GAME_CODE = mem.read(0x080000AC, 4)

local A = {
  AB4E = {
    money     = 0x0200000C, -- u32
    playtime  = 0x02000010, -- u32 frames
    hero      = 0x02002000, -- name[0x1C], +1C maxHp, +1E hp, +20 lv, +28/30/38 ATK/DEF/AGL x4, +40 exp, +44 next,
                            -- +48/49/4A weapon index in slots 1-3 (0xFF = empty), +4C accessory item index
    beast     = 0x02002100, -- +04 name, +20 exp, +24 next, +28 lv
    bag       = 0x0200221A, -- u8 count per item index (items 61+; the gear part overlaps the weapon counts)
    bagFirst  = 61,
    gear      = 0x020022A5, -- u8 count per accessory at gear + item record (1..60: rings, bracelets, shoes, necklaces)
    gearLast  = 60,
    events    = 0x020022E2, -- u8 per event item (non-zero = held), right after the accessories
    eventTable = 0x081F3F2C, -- ROM, 41 x 0x74: name[0x22], +22 kind (icon = kind + 87), +24 text[0x50]
    eventCount = 41,         -- hero +0x4C holds the worn accessory as record - 1 (0xFF none)
    recipes   = 0x0200217D, -- Technique list: 5 bytes per weapon type (sword, axe, spear, knuckle, drill), bit = id - the
                            -- type's first id; matched the game's List > Technique on three saves
    bestiary  = 0x02002196, -- Bestiary: bit b = enemy record 4 + b; b 0..76 are the game's 77 entries (List > Bestiary)
    tec       = 0x0200204D, -- hero +0x4D + weapon id: u8 TEC (technique) per weapon, as Status / Technique show it
    weaponCount = 0x020021A1, -- u8 count per weapon record index
    weapons   = 0x081E87D8, -- ROM weapon table, 0x90-byte records
    weaponTotal = 182,      -- 182 = "H Weapon" and beyond are unused
    mystic    = 0x02002314, -- u16 Mystic Ore material (not the bag item of the same name)
    mats      = { thunder = 0x02002312, fire = 0x0200230C, water = 0x0200230E, wind = 0x02002310 }, -- u16
    place     = 0x0200231A, -- place text, 8197 between the lines
    enemyRec  = 0x02002400, -- pointer to the current enemy's ROM record (0x40 bytes)
    enemies   = 0x081F7E68, -- ROM enemy table, 0x40-byte records: name[0x1E], +1E lv, +20 hp,
                            -- +22 atk, +24 def, +32 exp, +34 money
    items     = 0x081EF6FC, -- ROM item table, 0x84-byte records
    itemCount = 142,
    battleOn  = 0x0300002C, -- u8: 1 in a battle (results screen included); 0 on title, menus and field (field may reuse it: 0x40)
    battle    = 0x03000718, -- battle actor records, 0x1BC apart; +0..+2 = the actor's three weapon ids (0xFF empty,
                            -- 0xB6 = none for foes), +3 = 0, +0x10 hp, +0x14 max (u32)
    actorSize = 0x1BC,
  },
}
local M = A[GAME_CODE]

------------------------------------------------------------------------------
-- Text
------------------------------------------------------------------------------
local PUNCT = {
  [0x8140] = " ", [0x8141] = ",", [0x8143] = ",", [0x8144] = ".", [0x8145] = "-",
  [0x8146] = ":", [0x8147] = ";", [0x8148] = "?", [0x8149] = "!", [0x815B] = "-",
  [0x815C] = "-", [0x815D] = "-", [0x815E] = "/", [0x8160] = "~", [0x8163] = "...",
  [0x8165] = "'", [0x8166] = "'", [0x8167] = '"', [0x8168] = '"', [0x8169] = "(",
  [0x816A] = ")", [0x816D] = "[", [0x816E] = "]", [0x817B] = "+", [0x817C] = "-",
  [0x817E] = "x", [0x8181] = "=", [0x8183] = "<", [0x8184] = ">", [0x818F] = "$",
  [0x8193] = "%", [0x8194] = "#", [0x8195] = "&", [0x8196] = "*", [0x8197] = "\n",
  [0x819A] = "*", [0x819B] = "o",
}

local function sjis(addr, maxBytes)
  local raw = mem.read(addr, maxBytes)
  local out, i, n = {}, 1, #raw
  while i <= n do
    local b = raw:byte(i)
    if b == 0 then break end
    if b < 0x80 then
      out[#out + 1] = string.char(b); i = i + 1
    else
      local c = b * 256 + (raw:byte(i + 1) or 0)
      if c >= 0x824F and c <= 0x8258 then out[#out + 1] = string.char(c - 0x824F + 48)
      elseif c >= 0x8260 and c <= 0x8279 then out[#out + 1] = string.char(c - 0x8260 + 65)
      elseif c >= 0x8281 and c <= 0x829A then out[#out + 1] = string.char(c - 0x8281 + 97)
      else out[#out + 1] = PUNCT[c] or "" end
      i = i + 2
    end
  end
  return table.concat(out)
end

local function commas(n)
  local s = tostring(math.floor(n))
  return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function clock(frames)
  local s = math.floor(frames / 60)
  return string.format("%d:%02d:%02d", s // 3600, (s // 60) % 60, s % 60)
end

local function pct(a, b) return (b and b > 0) and math.max(0, math.min(1, a / b)) or 0 end

------------------------------------------------------------------------------
-- ROM item table, decoded once
------------------------------------------------------------------------------
local ELEMENTS = { "thunder", "fire", "water", "wind" }
-- The game draws each item's 12x12 icon from a ROM icon bank: icon number = kind + 87
-- (checked in the ITEM menu). The shipped PNGs are those icons, named i<number>.png.
local HAVE_ICON = {}
for _, n in ipairs({ 87, 88, 89, 90, 91, 92, 93, 94, 95, 112, 113, 114, 115, 117, 126, 127, 128, 129, 130,
                     131, 132, 133, 134, 135, 136, 137, 138, 139, 150, 151 }) do HAVE_ICON[n] = true end
local function iconFor(kind)
  local n = kind + 87
  return HAVE_ICON[n] and ("asset:img/icons/i" .. n .. ".png") or "asset:img/icons/i127.png"
end

local function category(kind)
  if kind >= 0x19 and kind <= 0x1C then return "gear", "EQUIP" end
  if kind == 0x1E then return "key", "KEY" end
  if kind == 0x27 or kind == 0x28 or kind == 0x29 then return "ore", "SMELT" end
  return "use", "USE"
end

local ITEMS, MYSTIC
local function loadItems()
  if ITEMS or not M then return end
  ITEMS = {}
  for i = 0, M.itemCount - 1 do
    local rec = M.items + i * 0x84
    local kind = mem.u8(rec + 0x22)
    local cls, tag = category(kind)
    local y = mem.read(rec + 0x30, 4)
    local it = { name = sjis(rec, 0x22), cls = cls, tag = tag, icon = iconFor(kind), price = mem.u32(rec + 0x28), rec = rec,
                 yield = { y:byte(1), y:byte(2), y:byte(3), y:byte(4) } }
    ITEMS[i] = it
    if it.name == "Mystic Ore" then MYSTIC = i end
  end
end

------------------------------------------------------------------------------
-- ROM weapon table, decoded once
--   +22 type (0 sword, 1 axe, 2 spear, 3 knuckle, 4 drill), +23 element (0 none, 1 fire,
--   2 water, 3 wind, 4 thunder), +25 1 = upgraded form, +2A..2D recipe thunder/fire/water/wind,
--   +30 upgrades into (index), +32 ATK, +33 DEF, +34 AGL (s8), +35 DUR, +3A price u16, +42 text
------------------------------------------------------------------------------
local WTYPE = { [0] = "SWORD", "AXE", "SPEAR", "KNUCKLE", "DRILL" }
local WELEM = { [0] = "", "FIRE", "WATER", "WIND", "THUNDER" }
local WREC = { "thunder", "fire", "water", "wind" }
local WEAPONS
-- Each weapon type has two unused "O Weapon" / "P Weapon" records (ids 26-27, 61-62, 99-100, 134-135, 170-171):
-- 172 real weapons. The Technique bits count real weapons only, so TYPE_REAL[t] lists them in order.
local TYPE_REAL, REAL_TOTAL = {}, 0
local function loadWeapons()
  if WEAPONS or not M then return end
  WEAPONS = {}
  for i = 0, M.weaponTotal - 1 do
    local r = M.weapons + i * 0x90
    local name = sjis(r, 0x22)
    if name ~= "" then
      local t = mem.u8(r + 0x22)
      local dummy = name == "O Weapon" or name == "P Weapon"   -- only edited saves hold these
      local agl = mem.u8(r + 0x34); if agl >= 0x80 then agl = agl - 256 end
      local need = mem.read(r + 0x2A, 4)
      if not dummy and t <= 4 then
        TYPE_REAL[t] = TYPE_REAL[t] or {}
        TYPE_REAL[t][#TYPE_REAL[t] + 1] = i
        REAL_TOTAL = REAL_TOTAL + 1
      end
      WEAPONS[i] = { name = name, type = t, dummy = dummy, typeName = WTYPE[t] or "", elem = WELEM[mem.u8(r + 0x23)] or "",
                     upgraded = mem.u8(r + 0x25) == 1, into = mem.u8(r + 0x30),
                     atk = mem.u8(r + 0x32), def = mem.u8(r + 0x33), agl = agl, dur = mem.u8(r + 0x35),
                     price = mem.u16(r + 0x3A), rec = r,
                     need = { need:byte(1), need:byte(2), need:byte(3), need:byte(4) },
                     icon = "asset:img/icons/i" .. (87 + math.min(t, 4)) .. ".png" }
    end
  end
end

local function weaponText(i)
  local w = WEAPONS and WEAPONS[i]
  return w and (sjis(w.rec + 0x42, 0x4E):gsub("\n", " ")) or ""
end

local function readWeapons(sel, matsHave)
  loadWeapons()
  local counts = mem.read(M.weaponCount, M.weaponTotal)
  local recipes = mem.read(M.recipes, 25)
  local tec = mem.read(M.tec, M.weaponTotal)
  local slots = mem.read(M.hero + 0x48, 3)
  local equipped, isOn = {}, {}
  for k = 1, 3 do
    local idx = slots:byte(k)
    local w = idx ~= 0xFF and WEAPONS[idx]
    equipped[k] = { slot = tostring(k), has = w and true or false, empty = not w,
                    name = w and w.name or "Empty", icon = w and w.icon or "",
                    stats = w and string.format("ATK %d  DEF %d  DUR %d  TEC %d", w.atk, w.def, w.dur,
                                                tec:byte(idx + 1)) or "" }
    if w then isOn[idx] = true end
  end
  loadItems()
  local acc = mem.u8(M.hero + 0x4C)
  local a = acc ~= 0xFF and ITEMS[acc + 1]
  equipped[4] = { slot = "A", has = a and true or false, empty = not a, name = a and a.name or "No accessory",
                  icon = a and a.icon or "", stats = a and "ACCESSORY" or "" }
  local list, total, forged = {}, 0, 0
  for i = 0, M.weaponTotal - 1 do
    local w, n = WEAPONS[i], counts:byte(i + 1)
    if w and n > 0 then
      total = total + n
      list[#list + 1] = { id = i, name = w.name, icon = w.icon, count = "x" .. n, elem = w.elem,
                          hasElem = w.elem ~= "", atk = w.atk, def = w.def, agl = w.agl, dur = w.dur,
                          tec = tec:byte(i + 1), on = isOn[i] == true, selected = sel == i }
    end
  end
  -- recipes learned: the game's own Technique list
  for t = 0, 4 do
    for bit = 0, #(TYPE_REAL[t] or {}) - 1 do
      local byte = recipes:byte(t * 5 + bit // 8 + 1) or 0
      if (byte >> (bit % 8)) & 1 == 1 then forged = forged + 1 end
    end
  end
  local pick
  local w = sel and WEAPONS[sel]
  if w then
    local need, can = {}, true
    for k = 1, 4 do
      local key = WREC[k]
      if w.need[k] > 0 then
        local ok = (matsHave[key] or 0) >= w.need[k]
        can = can and ok
        need[#need + 1] = { icon = "asset:img/mat-" .. key .. ".png", need = w.need[k],
                            have = matsHave[key] or 0, ok = ok, short = not ok }
      end
    end
    local into = w.into ~= 0 and WEAPONS[w.into] and not w.upgraded and WEAPONS[w.into]
    pick = { name = w.name, icon = w.icon, desc = weaponText(sel), typeName = w.typeName, elem = w.elem,
             hasElem = w.elem ~= "", atk = w.atk, def = w.def, agl = w.agl, dur = w.dur,
             price = w.price > 0 and (commas(w.price) .. " b") or "-", need = need, canForge = can,
             cantForge = not can, into = into and into.name or "", hasInto = into and true or false }
  end
  return { list = list, empty = #list == 0, total = total, equipped = equipped, pick = pick,
           kinds = #list, recipes = forged, realTotal = REAL_TOTAL }
end

local EVENTS
local function readEvents()
  if not EVENTS then
    EVENTS = {}
    for i = 0, M.eventCount - 1 do
      local r = M.eventTable + i * 0x74
      EVENTS[i] = { name = sjis(r, 0x22), icon = "asset:img/icons/i" .. (mem.u16(r + 0x22) + 87) .. ".png",
                    desc = (sjis(r + 0x24, 0x50):gsub("\n", " ")) }
    end
  end
  local held = mem.read(M.events, M.eventCount)
  local list = {}
  for i = 0, M.eventCount - 1 do
    local e = EVENTS[i]
    if held:byte(i + 1) ~= 0 and e.name ~= "" then
      list[#list + 1] = { name = e.name, icon = e.icon, desc = e.desc }
    end
  end
  return list
end

-- Journey: progress that the key items and collections already tell, without naming what is still ahead
local KEY_LADDER = { 3, 8, 15, 22, 23 }          -- Labyrinth Key 1-5
local NOTICES    = { 4, 5, 6, 7, 24, 25 }         -- Match Notice 1-6
local function readJourney(weaponKinds, weaponTotal)
  local held = mem.read(M.events, M.eventCount)
  local function ladder(ids, label)
    local out, n = {}, 0
    for k, id in ipairs(ids) do
      local has = held:byte(id + 1) ~= 0
      if has then n = k end
      out[#out + 1] = { n = tostring(k), has = has, no = not has }
    end
    -- a later key implies the earlier ones were held, even if handed back
    for k = 1, n do out[k].has, out[k].no = true, false end
    return out, n
  end
  local keys, keyN = ladder(KEY_LADDER)
  local notices, noticeN = ladder(NOTICES)
  local gear = mem.read(M.gear, M.gearLast + 1)
  local acc = 0
  local worn = mem.u8(M.hero + 0x4C)
  for i = 1, M.gearLast do
    if gear:byte(i + 1) ~= 0 or (worn ~= 0xFF and worn + 1 == i) then acc = acc + 1 end
  end
  local keyItems = 0
  for i = 1, M.eventCount do if held:byte(i) ~= 0 then keyItems = keyItems + 1 end end
  return {
    keyIcon = EVENTS and EVENTS[3].icon or "", noticeIcon = EVENTS and EVENTS[4].icon or "",
    keys = keys, keyN = keyN, keyPct = keyN / #KEY_LADDER,
    notices = notices, noticeN = noticeN, noticePct = noticeN / #NOTICES,
    weapons = weaponKinds, accessories = acc, keyItems = keyItems,
    weaponTotal = weaponTotal, weaponsPct = weaponKinds / math.max(1, weaponTotal), accPct = acc / 60, keyPct2 = keyItems / M.eventCount,
  }
end

local function describe(i)
  local it = ITEMS and ITEMS[i]
  return it and (sjis(it.rec + 0x34, 0x50):gsub("\n", " ")) or ""
end

------------------------------------------------------------------------------
-- Readers
------------------------------------------------------------------------------
-- Hero +0x1A: 0 Cleru, 1 Pratty (the player picks one at New Game). Poking it in a Cleru save turned the game's
-- own Status portrait into Pratty's; the four real saves sent in by players read 0 (Edgar) and 1 (Rukia, Pratty).
local function readHero()
  local h = M.hero
  local female = mem.u8(h + 0x1A) == 1
  -- the game shows HP capped at 9999 (an edited save read 10424/10424 and showed 9999/9999)
  local hp, maxHp, lv = math.min(mem.u16(h + 0x1E), 9999), math.min(mem.u16(h + 0x1C), 9999), mem.u16(h + 0x20)
  local exp, nxt = mem.u32(h + 0x40), mem.u32(h + 0x44)
  local function row(label, off)
    return { label = label, v0 = mem.u16(h + off), v1 = mem.u16(h + off + 2),
             v2 = mem.u16(h + off + 4), v3 = mem.u16(h + off + 6) }
  end
  return {
    name = (sjis(h, 0x1C):gsub("^%?+$", "???")), lv = lv, hp = hp, maxHp = maxHp,
    hpPct = pct(hp, maxHp), low = maxHp > 0 and hp * 4 <= maxHp,
    exp = commas(exp), next = commas(nxt), expPct = pct(exp, exp + nxt),
    stats = { row("ATK", 0x28), row("DEF", 0x30), row("AGL", 0x38) },
    portrait = female and "asset:img/pratty-status.png" or "asset:img/cleru-status.png",
    who = female and "PRATTY" or "CLERU",
  }
end

-- Guardian beast kind: beast +0x1E (0 Zantek, 1 Rasho, 2 Sugar, 3 Kutty, 4 Kuhyra), checked by poking it
-- and watching the game's own Status portrait change.
local BEAST_ART = { [0] = "zantek", "rasho", "sugar", "kutty", "kuhyra" }
local function readBeast()
  local b = M.beast
  local k = mem.u8(b + 0x1E)                    -- 0xFF until the beast is chosen in the story
  local kind = BEAST_ART[k] or "zantek"
  local exp, nxt = mem.u32(b + 0x20), mem.u32(b + 0x24)
  return { name = sjis(b + 4, 0x18), lv = mem.u16(b + 0x28),
           exp = commas(exp), next = commas(nxt), expPct = pct(exp, exp + nxt),
           portrait = "asset:img/" .. kind .. "-status.png", chosen = BEAST_ART[k] ~= nil }
end

local function readPlace()
  local s = sjis(M.place, 0x40)
  local a, b = s:match("^([^\n]*)\n?(.*)$")
  -- the game glues the floor onto the building ("Home1F"): give it a space
  local function floor(t) return ((t or ""):gsub("(%l)(B?%dF)$", "%1 %2")) end
  return floor(a or s), floor(b)
end

local function readBag(sel)
  loadItems()
  local counts = mem.read(M.bag, M.itemCount)
  local list, smelt, total = {}, {}, { 0, 0, 0, 0 }
  local gear = mem.read(M.gear, M.gearLast + 1)
  local worn = mem.u8(M.hero + 0x4C)
  worn = worn ~= 0xFF and worn + 1 or -1
  for i = 1, M.gearLast do
    local n = gear:byte(i + 1)
    local it = ITEMS[i]
    if it and it.name ~= "" and (n > 0 or worn == i) then
      list[#list + 1] = { id = i, name = it.name, count = n, qty = n > 0 and ("x" .. n) or "", tag = worn == i and "WORN" or it.tag, cls = it.cls,
                          icon = it.icon, selected = (sel == i), worn = worn == i }
    end
  end
  for i = M.bagFirst, M.itemCount - 1 do
    local n = counts:byte(i + 1)
    local it = ITEMS[i]
    if n > 0 and it and it.name ~= "" and it.cls ~= "key" then
      list[#list + 1] = { id = i, name = it.name, count = n, qty = "x" .. n, tag = it.tag, cls = it.cls,
                          icon = it.icon, selected = (sel == i) }
      local y = it.yield
      if y[1] + y[2] + y[3] + y[4] > 0 then
        local row = { id = i, name = it.name, count = n, icon = it.icon }
        for k = 1, 4 do
          row[ELEMENTS[k]] = y[k] > 0 and ("+" .. y[k] * n) or "-"
          total[k] = total[k] + y[k] * n
        end
        smelt[#smelt + 1] = row
      end
    end
  end
  return list, smelt, total, counts
end

------------------------------------------------------------------------------
-- Battle: live sprites from OAM + sprite VRAM
------------------------------------------------------------------------------
local OBJ_SIZE = {
  [0] = { [0] = { 8, 8 }, { 16, 16 }, { 32, 32 }, { 64, 64 } },
  [1] = { [0] = { 16, 8 }, { 32, 8 }, { 32, 16 }, { 64, 32 } },
  [2] = { [0] = { 8, 16 }, { 8, 32 }, { 16, 32 }, { 32, 64 } },
}

-- Banks 1-3 are Cleru, 4 and up are enemies, 0 is shadows/effects.
-- One enemy at a time: the lowest palette bank in 4..13 (14/15 are hit effects).
local function enemyBank()
  local oam = mem.read(0x07000000, 128 * 8)
  local best
  for i = 0, 127 do
    local a0 = oam:byte(i * 8 + 1) | oam:byte(i * 8 + 2) << 8
    local bank = oam:byte(i * 8 + 6) >> 4
    if (a0 >> 8) & 3 ~= 2 and bank >= 4 and bank <= 13 and (not best or bank < best) then best = bank end
  end
  return best
end

local function liveSprite(want, salt)
  local oam = mem.read(0x07000000, 128 * 8)
  local parts, x0, y0, x1, y1 = {}, 999, 999, -999, -999
  for i = 0, 127 do
    local a0 = oam:byte(i * 8 + 1) | oam:byte(i * 8 + 2) << 8
    local a1 = oam:byte(i * 8 + 3) | oam:byte(i * 8 + 4) << 8
    local a2 = oam:byte(i * 8 + 5) | oam:byte(i * 8 + 6) << 8
    local mode = (a0 >> 8) & 3
    local bank = a2 >> 12
    if mode ~= 2 and (a0 >> 10) & 3 ~= 2 and want(bank, mode) and #parts < 31 then
      local shape, size = a0 >> 14, a1 >> 14
      local dim = OBJ_SIZE[shape] and OBJ_SIZE[shape][size]
      if dim then
        local x, y = a1 & 0x1FF, a0 & 0xFF
        if x >= 256 then x = x - 512 end
        if y >= 160 then y = y - 256 end
        local aff = mode ~= 0
        parts[#parts + 1] = { x = x, y = y, w = dim[1], h = dim[2], tile = a2 & 0x3FF, bank = bank,
                              hflip = (not aff) and (a1 & 0x1000) ~= 0, vflip = (not aff) and (a1 & 0x2000) ~= 0 }
        x0, y0 = math.min(x0, x), math.min(y0, y)
        x1, y1 = math.max(x1, x + dim[1]), math.max(y1, y + dim[2])
      end
    end
  end
  if #parts == 0 then return nil end
  local w, h = math.min(256, x1 - x0), math.min(256, y1 - y0)
  for _, p in ipairs(parts) do p.x, p.y = p.x - x0, p.y - y0 end
  -- Off-canvas marker: makes the image key unique per enemy, so a new foe in the
  -- same sprite slot never shows the last one's picture.
  local mx = w + 8 + (salt % 40)
  if mx <= 248 then parts[#parts + 1] = { x = mx, y = 0, w = 8, h = 8, tile = 0, bank = 0 } end
  local ok, img = pcall(gfx.sprite, { tiles = 0x06010000, palette = 0x05000200,
                                      width = w, height = h, parts = parts })
  return ok and img or nil, w, h
end

------------------------------------------------------------------------------
-- Enemy book: the ROM's monster table, plus what this session has seen
------------------------------------------------------------------------------
-- Drops: enemy record +0x36 / +0x3A hold two drop ids (+0x38 / +0x3C a rate, 5 everywhere).
-- 139..280 are item records (id - 139): five slime fights gave Bottomless Cup (137) three times, the id 0x114 = 276.
-- 281..465 are weapons (id - 281), read from the same pattern; larger ids are left out.
local function dropsOf(r)
  loadItems(); loadWeapons()
  local out = {}
  for _, o in ipairs({ 0x36, 0x3A }) do
    local id = mem.u16(r + o)
    if id >= 139 and id < 139 + M.itemCount then
      local it = ITEMS[id - 139]
      if it and it.name ~= "" then out[#out + 1] = { name = it.name, icon = it.icon } end
    elseif id >= 281 and id < 281 + M.weaponTotal then
      local w = WEAPONS and WEAPONS[id - 281]
      if w then out[#out + 1] = { name = w.name, icon = w.icon } end
    end
  end
  return out
end

local BOOK_RANGES = { { 4, 80, "MONSTER" }, { 94, 109, "BOSS" } }
local BOOK

local function loadBook()
  if BOOK or not M then return end
  BOOK = {}
  local seen = {}
  for _, rg in ipairs(BOOK_RANGES) do
    for i = rg[1], rg[2] do
      local r = M.enemies + i * 0x40
      local name = sjis(r, 0x1E)
      if name ~= "" and not seen[name] then
        seen[name] = true
        BOOK[#BOOK + 1] = { idx = i, name = name, kind = rg[3], boss = rg[3] == "BOSS",
                            lv = mem.u16(r + 0x1E), hp = mem.u16(r + 0x20), atk = mem.u16(r + 0x22),
                            def = mem.u16(r + 0x24), exp = mem.u16(r + 0x32), money = mem.u16(r + 0x34),
                            drops = dropsOf(r) }
      end
    end
  end
end

local function sortBook()
  table.sort(BOOK, function(a, b) if a.lv ~= b.lv then return a.lv < b.lv end return a.idx < b.idx end)
end

local function enemyIndex(rec)
  if not M or rec < M.enemies then return nil end
  local d = rec - M.enemies
  if d % 0x40 ~= 0 then return nil end
  return d // 0x40
end

-- Monsters: the game's own Bestiary flags (in the save, so they carry over between sessions). The Bestiary
-- has 77 entries, enemy records 4..80 in ROM order; bit b of M.bestiary is record 4 + b. Checked against the
-- game's List > Bestiary on two saves (entries 1-15 of a mid-game save, all 77 of a cleared one).
-- Bosses are not in the Bestiary: they stay "???" until REVEAL ALL, except the one you are fighting.
local BESTIARY_SIZE = 77
local function readBook(filter, sel, current, spoil)
  if not BOOK then loadBook(); sortBook() end
  local seen = mem.read(M.bestiary, 10)
  local function inBestiary(idx)
    local b = idx - 4
    if b < 0 or b >= BESTIARY_SIZE then return false end
    return ((seen:byte(b // 8 + 1) or 0) >> (b % 8)) & 1 == 1
  end
  local list, known, pick = {}, 0, nil
  local wantBoss = filter == "boss"
  for _, e in ipairs(BOOK) do
    local met = not e.boss and inBestiary(e.idx)
    if met then known = known + 1 end
    local open = met or current == e.idx
    local hide = not spoil and not open
    if e.boss == wantBoss then
      list[#list + 1] = { id = e.idx, name = hide and "???" or e.name, lv = e.lv, hp = hide and "?" or e.hp,
                          atk = hide and "?" or e.atk, def = hide and "?" or e.def, exp = hide and "?" or e.exp,
                          money = hide and "?" or e.money, met = met, now = current == e.idx,
                          selected = sel == e.idx, hidden = hide }
    end
    if sel == e.idx and not hide then
      pick = { name = e.name, kind = e.kind, lv = e.lv, hp = commas(e.hp), atk = e.atk, def = e.def,
               exp = commas(e.exp), money = commas(e.money) .. " b", drops = e.drops, hasDrops = #e.drops > 0 }
    end
  end
  return { list = list, pick = pick, known = known, total = BESTIARY_SIZE,
           monsters = not wantBoss, bosses = wantBoss, spoil = spoil, noSpoil = not spoil }
end

-- A battle actor record looks like this: three weapon ids (each a weapon, 0xB6 "none" or 0xFF empty), a zero,
-- then hp <= max at +0x10/+0x14. Up to 0.9.3 the check was "+1..+3 = FF FF 00", which only held while slots 2
-- and 3 were empty: a hero carrying three weapons (every save past the start) never got a Battle page.
local function actorOk(r, cap)
  if mem.u8(r + 3) ~= 0 then return false end
  for k = 0, 2 do
    local w = mem.u8(r + k)
    if w > 0xB6 and w ~= 0xFF then return false end
  end
  local hp, mx = mem.u32(r + 0x10), mem.u32(r + 0x14)
  return mx > 0 and mx <= cap and hp <= mx
end

local function battleOn()
  return mem.u8(M.battleOn) == 1 and actorOk(M.battle, 0xFFFF)
end

local function readBattle()
  local P = M.battle
  if not battleOn() then return nil end
  local hp, maxHp = math.min(mem.u32(P + 0x10), 9999), math.min(mem.u32(P + 0x14), 9999)
  local b = { hp = hp, maxHp = maxHp, hpPct = pct(hp, maxHp), low = hp * 4 <= maxHp }

  -- Weapon wear: player +0x22/+0x24/+0x26 = durability x10 for slots 1-3, +0x28/+0x2A/+0x2C = max x10
  loadWeapons()
  local wear, breaking = {}, false
  local slots = mem.read(M.hero + 0x48, 3)
  for k = 0, 2 do
    local mx = mem.u16(P + 0x28 + k * 2)
    if mx > 0 and mx < 0x8000 then
      local cur = math.min(mem.u16(P + 0x22 + k * 2), mx)
      local w = WEAPONS and WEAPONS[slots:byte(k + 1)]
      local low = cur * 4 <= mx
      breaking = breaking or low
      wear[#wear + 1] = { slot = tostring(k + 1), name = w and w.name or ("Slot " .. (k + 1)),
                          icon = w and w.icon or "", hasIcon = w and true or false,
                          cur = cur // 10, max = mx // 10, pct = pct(cur, mx), low = low }
    end
  end
  b.wear, b.hasWear, b.noWear, b.breaking = wear, #wear > 0, #wear == 0, breaking

  -- foes: actor records after the player's
  local foes, alive = {}, 0
  for k = 1, 3 do
    local r = P + k * M.actorSize
    if actorOk(r, 99999) then
      local ehp, emax = mem.u32(r + 0x10), mem.u32(r + 0x14)
      do
        foes[#foes + 1] = { hp = ehp, maxHp = emax, hpPct = pct(ehp, emax), down = ehp == 0 }
        if ehp > 0 then alive = alive + 1 end
      end
    end
  end

  -- the enemy kind, from its ROM record
  local rec = mem.u32(M.enemyRec)
  local salt = 0
  if rec >= 0x08000000 and rec < 0x08800000 then
    salt = (rec >> 6) & 0xFFFF
    b.enemyIdx = enemyIndex(rec)
    b.enemy = {
      name = sjis(rec, 0x1E), lv = mem.u16(rec + 0x1E),
      atk = mem.u16(rec + 0x22), def = mem.u16(rec + 0x24),
      exp = mem.u16(rec + 0x32), money = mem.u16(rec + 0x34),
    }
    local d = dropsOf(rec)
    b.drop = d[1] and d[1].name or ""
    b.dropIcon = d[1] and d[1].icon or ""
    b.hasDrop = d[1] ~= nil
  else
    b.enemy = { name = "Enemy", lv = 0, atk = 0, def = 0, exp = 0, money = 0 }
  end
  b.foe = foes[1] or { hp = 0, maxHp = 0, hpPct = 0, down = true }
  b.foeCount = #foes
  b.won = #foes > 0 and alive == 0
  b.fighting = not b.won
  b.manyFoes = #foes > 1
  b.foesLeft = alive .. " of " .. #foes .. " left"

  -- Integer device-pixel scale (1 device px = 0.4336 dp on the Thor), as big as fits a
  -- ~150 dp stage, at most 6x.
  local function dp(n, h) local k = math.max(2, math.min(6, math.floor(150 / ((h or 32) * 0.4336)))); return string.format("%.2f", (n or 32) * k * 0.4336) end
  local eb = enemyBank()
  local okE, eImg, ew, eh = pcall(liveSprite, function(bank) return bank == eb end, salt)
  -- Cleru without his weapon: the weapon is a rotated (affine) sprite that can't be drawn turned,
  -- so it is left out and shown as an icon badge beside him instead.
  local okP, pImg, pw, ph = pcall(liveSprite, function(bank, mode) return bank >= 1 and bank <= 3 and mode == 0 end, 1)
  b.enemyW, b.enemyH = dp(ew, eh), dp(eh, eh)
  b.heroW, b.heroH = dp(pw or 64, ph or 64), dp(ph or 64, ph or 64)
  b.enemySprite = okE and eImg or ""
  b.heroSprite = okP and pImg or ""
  b.hasEnemySprite = okE and eImg ~= nil
  b.hasHeroSprite = okP and pImg ~= nil
  return b
end

------------------------------------------------------------------------------
-- update()
------------------------------------------------------------------------------
local wasInBattle = false

function update(ui)
  local page = ui.page or "status"
  local out = { ready = false, waiting = true }
  for _, p in ipairs({ "status", "battle", "weapon", "craft", "bag", "book", "beast", "journey" }) do
    out["nav_" .. p] = page == p
  end
  if not M then
    out.waitingText = "This pack reads the USA release (AB4E)"
    return out
  end

  local hero = readHero()
  if mem.u8(M.hero) < 0x81 or hero.name == "" or hero.maxHp == 0 or hero.lv < 1 or hero.lv > 99 then
    out.waitingText = "Load a save to begin"
    wasInBattle = false
    return out
  end
  out.ready, out.waiting = true, false

  out.hero = hero
  out.beast = readBeast()
  out.hasBeast, out.noBeast = out.beast.chosen, not out.beast.chosen
  out.money = commas(mem.u32(M.money))
  out.time = clock(mem.u32(M.playtime))
  out.place, out.area = readPlace()

  -- bag + craft
  local sel = tonumber(ui.pick)
  local bag, smelt, total, counts = readBag(sel)
  out.bag, out.bagEmpty = bag, #bag == 0
  out.smelt, out.smeltEmpty = smelt, #smelt == 0
  local mats = {}
  for k = 1, 4 do
    local have = mem.u16(M.mats[ELEMENTS[k]])
    mats[#mats + 1] = { key = ELEMENTS[k], label = ELEMENTS[k]:upper(), count = have,
                        plus = total[k] > 0 and ("+" .. total[k] .. " in bag") or "-",
                        icon = "asset:img/mat-" .. ELEMENTS[k] .. ".png",
                        pct = pct(have, 99) }
  end
  out.mats = mats
  local have = {}
  for k = 1, 4 do have[ELEMENTS[k]] = mats[k].count end
  out.events = readEvents()
  out.eventsEmpty = #out.events == 0
  out.bagKey = ui.bagTab == "key"
  out.bagMain = not out.bagKey
  local wsel = tonumber(ui.wpick)
  out.weapons = readWeapons(wsel, have)
  out.journey = readJourney(out.weapons.recipes, out.weapons.realTotal)
  out.wpick = out.weapons.pick
  out.mystic = mem.u16(M.mystic)
  if sel and ITEMS and ITEMS[sel] then
    local it = ITEMS[sel]
    local yl = {}
    for k = 1, 4 do if it.yield[k] > 0 then yl[#yl + 1] = ELEMENTS[k] .. " +" .. it.yield[k] end end
    out.pick = { name = it.name, tag = it.tag, cls = it.cls, desc = describe(sel), icon = it.icon,
                 price = it.price > 0 and (commas(it.price) .. " b") or "-",
                 smelt = #yl > 0 and table.concat(yl, "  ") or "", canSmelt = #yl > 0 }
  end

  -- battle
  local battle = readBattle()
  out.book = readBook(ui.bookTab == "boss" and "boss" or "monster", tonumber(ui.epick),
                      battle and battle.enemyIdx, tostring(ui.spoil) == "1", hero.lv)
  out.epick = out.book.pick
  out.journey.known, out.journey.knownTotal = out.book.known, out.book.total
  out.journey.knownPct = out.book.known / math.max(1, out.book.total)
  out.logBook = ui.logTab == "book"
  out.logMain = not out.logBook
  local inBattle = battle ~= nil
  out.inBattle = inBattle
  out.battle = battle or { fighting = false }
  out.noBattle = not inBattle
  if inBattle and not wasInBattle then
    out.ui = { navigate = "battle" }
  elseif wasInBattle and not inBattle and page == "battle" then
    out.ui = { back = true }
  end
  wasInBattle = inBattle
  return out
end

actions = {}
