-- Castlevania: Harmony of Dissonance (USA, ACHE) companion.
-- Names and descriptions are read from the player's ROM (the game's 16-bit text, decoded below); numbers from RAM.
-- Addresses and how they were found are in NOTES.md.

local CODE = "ACHE"

-- ROM
local STR_PTRS = 0x08495498    -- 709 u32 pointers; each string: u16 header, then u16 characters

-- string ids
local S_USE_FIRST, S_USE_LAST = 60, 87        -- items, keys, maps, hint cards, jewels
local S_WHIP_FIRST = 88                       -- 9 whip tips (88-96)
local S_ARMOR_FIRST = 97                      -- body armor 97-138, goods 139-224 (one equipment index: id - 97)
local S_BOOK_FIRST = 225                      -- 5 spell books
local S_RELIC_FIRST = 230                     -- 12 relics
local DESC_OFF = 213                          -- description = name id + 213

-- RAM (EWRAM)
local R_FRAMES = 0x02000088    -- u32 play time, frames
local R_LIVE = 0x0201854E      -- u16 HP, MP, then STR DEF INT LCK totals
local R = 0x02018760           -- the save slot block
local O = {
  level = 0x1C, book = 0x1F,   -- spell book set, 1-based (0 none)
  body = 0x20, goods = 0x21, whip = 0x24,   -- 0xFF = empty; body / goods = id - 97, whip = id - 88
  maxHp = 0x26, maxMp = 0x28, maxHeart = 0x2A, base = 0x2C, heart = 0x34,
  exp = 0x38, gold = 0x3C,
  items = 0x40,                -- count per id 60-87
  whipBits = 0x5C,             -- u16, bit k = whip tip 88 + k owned
  equip = 0x5E,                -- count per id 97-224 (worn ones not counted)
  books = 0xDE,                -- bit k = spell book k owned
  relics = 0xDF, relicsOn = 0xE1,   -- u16 bits: owned, switched on
  config = 0xEC,               -- u16 Attack, Jump, Dash Left, Dash Right
}
local BLOCK_N = 0xF4

-- what each healing item does, measured in the game (HP 1, use one, read HP)
local HEAL = {
  [60] = { "hp", 70 }, [61] = { "hp", 150 }, [62] = { "hp", 9999 }, [63] = { "mp", 20 }, [64] = { "mp", 100 },
  [65] = { "hp", 100 }, [66] = { "hp", 200 },
}
local KEYS = { { v = 0x0001, t = "A" }, { v = 0x0002, t = "B" }, { v = 0x0200, t = "L" }, { v = 0x0100, t = "R" } }
local CONFIG_ROWS = { { label = "ATTACK", off = 0 }, { label = "JUMP", off = 2 }, { label = "DASH LEFT", off = 4 }, { label = "DASH RIGHT", off = 6 } }
local CONFIG_DEFAULT = { [0] = 0x0002, [2] = 0x0001, [4] = 0x0200, [6] = 0x0100 }

-- the slot word the game prints for a goods item, by its place in the list
local function goodsKind(id)
  if id <= 142 then return "GOODS" elseif id <= 172 then return "HEAD" elseif id <= 181 then return "HANDS"
  elseif id <= 193 then return "FEET" elseif id <= 200 then return "BACK" elseif id <= 205 then return "ARMS"
  elseif id <= 215 then return "NECK" end
  return "FINGER"
end

local D, romOk = nil, false

-- ---------------------------------------------------------------------------------------------
-- the game's text: u16 characters
local PUNCT = {
  [0x8540] = " ", [0x8541] = ",", [0x8542] = ".", [0x8543] = "!", [0x8544] = ":", [0x8547] = "I", [0x8562] = "'",
  [0x8563] = "(", [0x8564] = ")", [0x8565] = "$", [0x817C] = "-", [0x817B] = "+", [0x815E] = "/", [0x8148] = "?",
  [0x8149] = "!", [0x8167] = "\"", [0x8168] = "\"", [0x8146] = ":", [0x8144] = ".", [0x8143] = ",",
}
local function ch(v)
  if v >= 0x8260 and v <= 0x8279 then return string.char(65 + v - 0x8260) end
  if v >= 0x8548 and v <= 0x8561 then return string.char(97 + v - 0x8548) end
  if v >= 0x824F and v <= 0x8258 then return string.char(48 + v - 0x824F) end
  if v >= 0x8281 and v <= 0x829A then return string.char(97 + v - 0x8281) end
  if PUNCT[v] then return PUNCT[v] end
  if v >= 0xF000 then return " " end
  return ""
end

local function rstr(id)
  local p = mem.u32(STR_PTRS + id * 4)
  if p < 0x08000000 or p >= 0x0A000000 then return "" end
  local raw = mem.read(p + 2, 240)
  local out = {}
  for i = 1, #raw - 1, 2 do
    local v = raw:byte(i) | (raw:byte(i + 1) << 8)
    if v == 0 or v == 0xF00A or v == 0xFFFF then break end
    out[#out + 1] = ch(v)
  end
  local s = table.concat(out):gsub("%s+", " ")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function buildData()
  D = { name = {}, desc = {} }
  for id = 60, 241 do D.name[id] = rstr(id); D.desc[id] = rstr(id + DESC_OFF) end
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
local function nextExp(level) return math.min(499999, 60 * level * (level + 1)) end   -- read off the game for 11 levels

local function icon(id)
  if id >= 60 and id <= 66 then return (id == 63 or id == 64) and "asset:ui/ic-mana.png" or ((id == 65 or id == 66) and "asset:ui/ic-food.png" or "asset:ui/ic-potion.png") end
  if id <= 69 then return "asset:ui/ic-cure.png" end
  if id <= 72 then return "asset:ui/ic-key.png" end
  if id <= 75 then return "asset:ui/ic-map.png" end
  if id <= 81 then return "asset:ui/ic-card.png" end
  if id <= 87 then return "asset:ui/ic-jewel.png" end
  if id <= 96 then return "asset:ui/ic-whip.png" end
  if id <= 138 then return "asset:ui/ic-armor.png" end
  local k = goodsKind(id)
  return "asset:ui/ic-" .. k:lower() .. ".png"
end

-- ---------------------------------------------------------------------------------------------
local MENU = {
  { label = "EQUIP", page = "equip", hint = "Change equipped items." },
  { label = "ITEMS", page = "items", hint = "Examine or use items." },
  { label = "SPELLBOOK", page = "book", hint = "Select Spell Book." },
  { label = "RELICS", page = "relics", hint = "Switch Magic Item effects on and off." },
  { label = "KEY CONFIG.", page = "config", hint = "Change button configuration." },
}

local function status(out)
  local secs = mem.u32(R_FRAMES) // 60
  local level = b8(O.level)
  local exp = b32(O.exp)
  local hp, mp = mem.u16(R_LIVE), mem.u16(R_LIVE + 2)
  local need = nextExp(level)
  out.st = {
    level = tostring(level), exp = tostring(exp), next = tostring(math.max(0, need - exp)),
    expIn = math.min(exp, need), expSpan = math.max(1, need),
    time = string.format("%d:%02d:%02d", secs // 3600, (secs // 60) % 60, secs % 60), gold = tostring(b32(O.gold)),
    hp = hp, maxHp = b16(O.maxHp), mp = mp, maxMp = b16(O.maxMp), heart = b16(O.heart), maxHeart = b16(O.maxHeart),
    hpText = hp .. "/" .. b16(O.maxHp), mpText = mp .. "/" .. b16(O.maxMp), heartText = b16(O.heart) .. "/" .. b16(O.maxHeart),
    lowHp = hp * 4 <= b16(O.maxHp),
    str = mem.u16(R_LIVE + 4), def = mem.u16(R_LIVE + 6), int = mem.u16(R_LIVE + 8), lck = mem.u16(R_LIVE + 10),
  }
  local book = b8(O.book)
  out.bookNow = { on = book >= 1 and book <= 5, name = (book >= 1 and book <= 5) and D.name[S_BOOK_FIRST + book - 1] or "",
                  img = (book >= 1 and book <= 5) and ("asset:game/book-" .. (book - 1) .. ".png") or "asset:ui/book-none.png" }
  out.menu = MENU
end

local function slotsView()
  local out = {}
  local w = b8(O.whip)
  out[1] = { label = "WHIP", name = w <= 8 and D.name[S_WHIP_FIRST + w] or "---", none = w > 8, id = w <= 8 and (S_WHIP_FIRST + w) or -1 }
  local b = b8(O.body)
  out[2] = { label = "BODY", name = b <= 41 and D.name[S_ARMOR_FIRST + b] or "---", none = b > 41, id = b <= 41 and (S_ARMOR_FIRST + b) or -1 }
  for k = 0, 2 do
    local g = b8(O.goods + k)
    local id = (g >= 42 and g <= 127) and (S_ARMOR_FIRST + g) or -1
    out[3 + k] = { label = id > 0 and goodsKind(id) or "GOODS", name = id > 0 and D.name[id] or "---", none = id < 0, id = id }
  end
  for i, s in ipairs(out) do s.i = i; s.icon = s.id > 0 and icon(s.id) or "asset:ui/ic-none.png" end
  return out
end

local function pageEquip(out, ui)
  local slot = clampInt(ui.eqSlot or 1, 1, 5)
  local slots = slotsView()
  for i, s in ipairs(slots) do s.sel = i == slot end
  out.eqSlots = slots
  local list = {}
  if slot == 1 then
    local bits = b16(O.whipBits)
    for k = 0, 8 do
      if (bits >> k) & 1 == 1 then list[#list + 1] = { id = S_WHIP_FIRST + k, name = D.name[S_WHIP_FIRST + k], count = "", icon = icon(S_WHIP_FIRST + k) } end
    end
  else
    local lo, hi = 97, 138
    if slot >= 3 then lo, hi = 139, 224 end
    for id = lo, hi do
      local n = b8(O.equip + id - 97)
      if n > 0 then list[#list + 1] = { id = id, name = D.name[id], count = tostring(n), icon = icon(id) } end
    end
  end
  local pick = tonumber(ui.eqId) or -1
  for _, e in ipairs(list) do e.sel = e.id == pick end
  out.eqList = list
  out.eqEmpty = #list == 0
  local id = pick > 0 and pick or slots[slot].id
  out.eqPick = { name = id > 0 and D.name[id] or "---", desc = id > 0 and D.desc[id] or "Nothing equipped.", icon = id > 0 and icon(id) or "asset:ui/ic-none.png",
                 kind = id > 138 and goodsKind(id) or (id > 96 and "BODY" or (id > 0 and "WHIP" or "")) }
end

local function pageItems(out, ui)
  local list = {}
  local pick = tonumber(ui.item) or -1
  local key = ui.itemTab == "key"
  for id = S_USE_FIRST, S_USE_LAST do
    local n = b8(O.items + id - 60)
    if n > 0 and ((id >= 70) == key) then list[#list + 1] = { id = id, name = D.name[id], count = string.format("%02d", n), sel = pick == id, icon = icon(id) } end
  end
  out.itemList, out.itemEmpty, out.itemKeyTab, out.itemUseTab = list, #list == 0, key, not key
  if pick >= 60 and pick <= 87 then
    local h = HEAL[pick]
    local have = b8(O.items + pick - 60)
    local hp, mp = mem.u16(R_LIVE), mem.u16(R_LIVE + 2)
    local room = h and ((h[1] == "hp" and hp < b16(O.maxHp)) or (h[1] == "mp" and mp < b16(O.maxMp)))
    out.ipick = { name = D.name[pick], desc = D.desc[pick], icon = icon(pick), id = pick,
                  effect = h and (h[2] >= 9999 and "HP full" or (h[1]:upper() .. " +" .. h[2])) or "",
                  canUse = h ~= nil and have > 0 and room, full = h ~= nil and have > 0 and not room }
  else
    out.ipick = { name = "", desc = "Examine or use items.", icon = "asset:ui/ic-none.png", id = -1, effect = "", canUse = false, full = false }
  end
end

local function pageBook(out, ui)
  local bits, set = b8(O.books), b8(O.book)
  local list = {}
  for k = 0, 4 do
    local have = (bits >> k) & 1 == 1
    list[k + 1] = { k = k + 1, name = have and D.name[S_BOOK_FIRST + k] or "??????????", have = have, locked = not have, set = set == k + 1,
                    img = have and ("asset:game/book-" .. k .. ".png") or "asset:ui/book-none.png" }
  end
  out.bookList = list
  local pick = clampInt(ui.book or (set >= 1 and set or 1), 1, 5)
  local have = (bits >> (pick - 1)) & 1 == 1
  out.bookPick = { name = have and D.name[S_BOOK_FIRST + pick - 1] or "??????????", desc = have and D.desc[S_BOOK_FIRST + pick - 1] or "??????????",
                   k = pick, canSet = have and set ~= pick, isSet = have and set == pick, img = have and ("asset:game/book-" .. (pick - 1) .. ".png") or "asset:ui/book-none.png" }
end

local function pageRelics(out, ui)
  local own, on = b16(O.relics), b16(O.relicsOn)
  local list = {}
  for k = 0, 11 do
    local have = (own >> k) & 1 == 1
    list[k + 1] = { k = k, name = have and D.name[S_RELIC_FIRST + k] or "??????????", have = have, locked = not have,
                    on = have and (on >> k) & 1 == 1, off = have and (on >> k) & 1 == 0, sel = tonumber(ui.relic) == k, icon = "asset:ui/rl-" .. k .. (have and "" or "-off") .. ".png" }
  end
  out.relicList = list
  local p = tonumber(ui.relic)
  if p and p >= 0 and p <= 11 and (own >> p) & 1 == 1 then
    out.relicPick = { name = D.name[S_RELIC_FIRST + p], desc = D.desc[S_RELIC_FIRST + p] }
  else
    out.relicPick = { name = "", desc = p and "Not found yet." or "Tap a relic to switch it on or off." }
  end
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

-- the explored castle: 64 x 42 cells. Each row is 8 bytes (Castle A word, Castle B word, low bit = left);
-- the left 32 columns are at R_MAP_L, the right 32 at R_MAP_R (36 rows). 674 cells per castle = 100%.
local R_MAP_L, R_MAP_R, MAP_TOTAL = 0x02000094, 0x020001E4, 674
local CELL, AP = 3.1, 2.168

local function mapWord(castle, col32half, row)
  local base = col32half == 0 and R_MAP_L or R_MAP_R
  if col32half == 1 and row >= 36 then return 0 end
  return mem.u32(base + row * 8 + castle * 4)
end

local function castleCount(castle)
  local n = 0
  for half = 0, 1 do
    for r = 0, 41 do
      local v = mapWord(castle, half, r)
      while v > 0 do n = n + (v & 1); v = v >> 1 end
    end
  end
  return n
end

local function pct(n) return math.floor(n * 1000 / MAP_TOTAL) end   -- tenths, truncated like the game

local GM, MAPDATA = pack.require("gamemap"), pack.require("mapdata")
local CELLPX = 6.0704   -- 7/8 of the 6.9376 cell (14 device px) so the 60 cropped columns fit the frame; one font glyph per cell
local EXPLORED = 0x0200008C   -- two blocks of 2560 bits: map columns 0-31, then 32-63; in each 64-bit row bits 0-31 = castle A, 32-63 = castle B
local mapSig, mapBuilt = {}, {}
local function pageMap(out, ui)
  local castle = clampInt(ui.castle or 0, 0, 1)
  local function words(y) return mem.u32(EXPLORED + y * 8 + castle * 4), mem.u32(EXPLORED + 320 + y * 8 + castle * 4) end
  local sig = GM.signature(MAPDATA, words)
  if sig ~= mapSig[castle] or not mapBuilt[castle] then mapBuilt[castle], mapSig[castle] = GM.build(MAPDATA, words), sig end
  local mb = mapBuilt[castle]
  out.mapFill, out.mapSave, out.mapWarp, out.mapWalls, out.mapDoors = mb.fill, mb.save, mb.warp, mb.walls, mb.doors
  out.mapB = castle == 1
  -- Juste's room: the game keeps it at 0x02000070 (bit 0 = castle B, bits 1-7 = map x) and +1 (map y)
  local pos = mem.u8(0x02000070)
  local cx, cy, cb = pos >> 1, mem.u8(0x02000071), pos & 1
  local on = cb == castle and cx >= 1 and cx <= 59 and cy >= 5 and cy <= 35
  local mx0, my0, mx1, my1 = GM.bounds(MAPDATA)
  on = on and cx >= mx0 and cx <= mx1 and cy >= my0 and cy <= my1   -- the drawn window is cropped to the rooms (gamemap.bounds)
  out.me = { on = on, left = string.format("%.2fpx", (cx - mx0 + 0.5) * CELLPX - 4 * 2.168), top = string.format("%.2fpx", (cy - my0 + 0.5) * CELLPX - 4 * 2.168) }
  out.meText = on and string.format("%d,%d", cx, cy) or "--"
  local na, nb = castleCount(0), castleCount(1)
  local a, b = pct(na), pct(nb)
  out.map = { a = string.format("%.1f%%", a / 10), b = string.format("%.1f%%", b / 10), total = string.format("%.1f%%", pct(na + nb) / 10),
              isA = castle == 0, isB = castle == 1, name = castle == 0 and "Castle A" or "Castle B", empty = false }
end

-- live alerts: a relic or spell book found, a level gained
local prev, tick, toast = nil, 0, nil
local function watch(out, ui)
  tick = tick + 1
  local now = { relics = b16(O.relics), books = b8(O.books), level = b8(O.level), maxHp = b16(O.maxHp) }
  if prev and now.level >= prev.level and now.level - prev.level <= 3 then
    local found, n = nil, 0
    for k = 0, 11 do
      if (now.relics >> k) & 1 == 1 and (prev.relics >> k) & 1 == 0 then
        n = n + 1
        found = { title = "RELIC", name = D.name[S_RELIC_FIRST + k], sub = D.desc[S_RELIC_FIRST + k], img = "asset:ui/rl-" .. k .. ".png", page = "relics", relic = k, book = -1 }
      end
    end
    for k = 0, 4 do
      if (now.books >> k) & 1 == 1 and (prev.books >> k) & 1 == 0 then
        n = n + 1
        found = { title = "SPELL BOOK", name = D.name[S_BOOK_FIRST + k], sub = D.desc[S_BOOK_FIRST + k], img = "asset:game/book-" .. k .. ".png", page = "book", relic = -1, book = k + 1 }
      end
    end
    if now.level > prev.level then
      n = n + 1
      found = { title = "LEVEL UP", name = "LEVEL " .. now.level, sub = "Max HP " .. prev.maxHp .. " > " .. now.maxHp, img = "asset:game/portrait-juste.png", page = "status", relic = -1, book = -1 }
    end
    if found and n <= 3 then found.id = tick; found.untilTick = tick + 24; toast = found end
  end
  prev = now
  out.toastOn = toast ~= nil and tick < toast.untilTick and (tonumber(ui.toastHide) or -1) ~= toast.id
  out.toast = toast or { id = 0, title = "", name = "", sub = "", img = "asset:game/portrait-juste.png", page = "status", relic = -1, book = -1 }
end

function update(ui)
  if not romOk then
    return { ready = false, waiting = true, maxim = false, wrongRom = mem.u32(0x08000000) ~= 0 and mem.read(0x080000AC, 4) ~= CODE }
  end
  B = mem.read(R, BLOCK_N)
  local level, maxHp = b8(O.level), b16(O.maxHp)
  if maxHp == 0 or maxHp > 9999 or mem.u32(R_FRAMES) == 0 or level < 1 or level > 99 then
    return { ready = false, waiting = true, wrongRom = false, maxim = maxHp > 0 and maxHp <= 9999 and level == 0 }
  end
  local out = { ready = true, waiting = false }
  status(out)
  -- quick heal: the cheapest healing item that fills the gap, else the strongest
  local hp, mx = out.st.hp, out.st.maxHp
  local cover, big = nil, nil
  if hp < mx then
    for id, h in pairs(HEAL) do
      if h[1] == "hp" and b8(O.items + id - 60) > 0 then
        if h[2] >= mx - hp then if not cover or h[2] < HEAL[cover][2] then cover = id end
        elseif not big or h[2] > HEAL[big][2] then big = id end
      end
    end
  end
  local best = cover or big
  out.heal = { can = best ~= nil, off = best == nil, id = best or -1,
               name = best and (D.name[best] .. " x" .. b8(O.items + best - 60)) or (hp >= mx and "HP full" or "No potions") }
  out.slots = slotsView()
  local page = ui.page or "status"
  if page == "equip" then pageEquip(out, ui)
  elseif page == "items" then pageItems(out, ui)
  elseif page == "book" then pageBook(out, ui)
  elseif page == "relics" then pageRelics(out, ui)
  elseif page == "config" then pageConfig(out)
  elseif page == "map" then pageMap(out, ui) end
  out.onStatus, out.onEquip, out.onItems, out.onBook, out.onRelics, out.onMap = page == "status", page == "equip", page == "items", page == "book", page == "relics", page == "map"
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
  local lv = b8(O.level)
  return lv >= 1 and lv <= 99 and mem.u32(R_FRAMES) > 0
end
local function fail(why) return { set = { note = "Not changed: " .. tostring(why or "refused") } } end

function actions.useItem(id)
  id = clampInt(id, 60, 87)
  if not inGame() then return end
  local h = HEAL[id]
  local n = b8(O.items + id - 60)
  if not h or n == 0 then return end
  local addr, max = R_LIVE, b16(O.maxHp)
  if h[1] == "mp" then addr, max = R_LIVE + 2, b16(O.maxMp) end
  local cur = mem.u16(addr)
  if cur >= max then return { set = { note = "Already full." } } end
  local ok, why = mem.write16(addr, math.min(max, cur + h[2]))
  if not ok then return fail(why) end
  ok, why = mem.write8(R + O.items + id - 60, n - 1)
  if not ok then return fail(why) end
  return { set = { note = D.name[id] .. " was used." } }
end

function actions.quickHeal(id)
  id = tonumber(id) or -1
  if id < 60 then return { set = { note = "No healing items." } } end
  return actions.useItem(id)
end

function actions.setBook(k)
  k = clampInt(k, 1, 5)
  if not inGame() or (b8(O.books) >> (k - 1)) & 1 == 0 then return end
  local ok, why = mem.write8(R + O.book, k)
  if not ok then return fail(why) end
  return { set = { note = D.name[S_BOOK_FIRST + k - 1] .. " set." } }
end

function actions.toggleRelic(k)
  k = clampInt(k, 0, 11)
  if not inGame() or (b16(O.relics) >> k) & 1 == 0 then return end
  -- the switch word sits at an odd address: write the one byte that holds this relic's bit
  local off = O.relicsOn + (k >> 3)
  local ok, why = mem.write8(R + off, b8(off) ~ (1 << (k & 7)))
  if not ok then return fail(why) end
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
  return { set = { note = "Default settings restored." } }
end
