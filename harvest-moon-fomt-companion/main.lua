-- Harvest Moon: Friends of Mineral Town (US, A4NE) companion. Memory map and open items: NOTES.md.
-- The game keeps its save block byte for byte in EWRAM: RAM address = SAVE + save-file offset.
-- Names come from the ROM's own tables at run time (nothing is shipped).

local ICONS       = pack.require("icons")
local US_ROM      = mem.read(0x080000AC, 4) == "A4NE"
local SAVE        = 0x02004DE0
local GOLD        = SAVE + 0x1AD4
local FARM_NAME   = SAVE + 0x40
local PLAYER_NAME = SAVE + 0x1C04
local SHIPPED     = SAVE + 0x84      -- u32 per item: bit31 = seen, low bits = count shipped
local SICKLE      = SAVE + 0x1C60    -- u16 tool id
local TOOLS       = SAVE + 0x1C8C    -- 8 x u16 tool id
local ITEMS       = SAVE + 0x1C68    -- 8 x 4 bytes, byte1 = item id (>= N_ITEMS: empty), byte0 bit0 = gift wrapped
local COOP        = SAVE + 0x460     -- chicken records, 0x30 each (name16, +0x10 age, +0x12 s16 affection, +0x14 health)
local BARN        = SAVE + 0x654     -- cow / sheep records, 0x3C each (same field offsets)
local TOOL_TABLE  = 0x080EAB0C       -- ROM, 12 bytes per tool id - 0x100, name pointer first
local ITEM_TABLE  = 0x080EDCD8       -- ROM, 16 bytes per item id, name pointer first
local N_ITEMS     = 171
local GOLD_CAP    = 999999

local HEART_AT = { 3, 7, 10, 13, 15, 18, 20, 23, 26, 28, 31 }
-- Memo "Number shipped" order (read off the game screen with every entry unlocked), index = position in the u32 array
local SHIP_NAMES = {
  "Turnip", "Potato", "Cucumber", "Cabbage", "Strawberry", "Tomato",
  "Corn", "Onion", "Pineapple", "Pumpkin", "Eggplant", "Carrot",
  "Sweet Potato", "Green Pepper", "Spinach", "Regular Egg", "Good Egg", "High Quality Egg",
  "Golden Egg", "P Egg", "X Egg", "Spa-Boiled Egg", "Mayonnaise (S)", "Mayonnaise (M)",
  "Mayonnaise (L)", "Mayonnaise (G)", "Mayonnaise (P)", "Mayonnaise (X)", "Milk (S)", "Milk (M)",
  "Milk (L)", "Milk (G)", "Milk (P)", "Milk (X)", "Cheese (S)", "Cheese (M)",
  "Cheese (L)", "Cheese (G)", "Cheese (P)", "Cheese (X)", "Apple", "SUGDW Apple",
  "HMSGB Apple", "AEPFE Apple", "Honey", "Bamboo Shoot", "Wild Grapes", "Mushroom",
  "Poisonous Mushroom", "Truffle", "Blue Grass", "Green Grass", "Red Grass", "Yellow Grass",
  "Orange Grass", "Purple Grass", "Indigo Grass", "Black Grass", "White Grass", "Chocolate",
  "Relax Tea Leaves", "Small Fish", "Medium Fish", "Large Fish", "Pirate Treasure", "Fossil of Fish",
  "Red Magic Grass", "Wool (S)", "Wool (M)", "Wool (L)", "Wool (G)", "Wool (P)",
  "Wool (X)", "Yarn (S)", "Yarn (M)", "Yarn (L)", "Yarn (G)", "Yarn (P)",
  "Yarn (X)", "Bracelet", "Necklace", "Earrings", "Broach", "Junk Ore",
  "Copper", "Silver", "Gold", "Mystrile", "Orichalc", "Adamantite",
  "Moon Stone", "Sand Rose", "Pink Diamond", "Alexandrite", "Mythic Stone", "Diamond",
  "Emerald", "Ruby", "Topaz", "Peridot", "Fluorite", "Agate",
  "Amethyst",
}
local N_SHIP = #SHIP_NAMES
local function shipGroup(i)
  if i < 15 then return "Crops" elseif i < 22 then return "Eggs" elseif i < 28 then return "Mayonnaise" elseif i < 34 then return "Milk" elseif i < 40 then return "Cheese" elseif i < 66 then return "Foraged" elseif i < 79 then return "Wool and yarn" elseif i < 83 then return "Jewelry" else return "Ores and gems" end
end

-- the game's own 16x16 icon from the ROM (falls back to the pack's drawn one on another release)
local function romIcon(entry, fallback)
  if not US_ROM or not entry then return fallback end
  local ok, key = pcall(gfx.decode, { tiles = ICONS.base + entry[1], palette = ICONS.base + entry[2], width = 16, height = 16 })
  if ok and key then return key end
  return fallback
end

local function romGfx(entry, size, fallback)
  if not US_ROM or not entry then return fallback end
  local ok, key = pcall(gfx.decode, { tiles = ICONS.base + entry[1], palette = ICONS.base + entry[2], width = size, height = size })
  if ok and key then return key end
  return fallback
end

local function cstr(a, n)
  local raw = mem.read(a, n or 16)
  local s = {}
  for i = 1, #raw do
    local c = raw:byte(i)
    if c == 0 or c == 13 then break end
    if c < 0x20 or c > 0x7E then return nil end
    s[#s + 1] = string.char(c)
  end
  if #s == 0 then return nil end
  return table.concat(s)
end

local nameCache = {}
local function romName(table_addr, stride, idx)
  local key = table_addr + idx * stride
  local n = nameCache[key]
  if n then return n end
  local p = mem.u32(key)
  if p < 0x08000000 or p >= 0x08800000 then return "?" end
  n = cstr(p, 32) or "?"
  nameCache[key] = n
  return n
end
local function toolName(id) return romName(TOOL_TABLE, 12, id - 0x100) end
local function itemName(id) return romName(ITEM_TABLE, 16, id) end

local function hearts(rec)
  local p = mem.s16(rec + 0x12) + 32
  local h = 0
  for _, t in ipairs(HEART_AT) do if p >= t then h = h + 1 end end
  return h
end

local function heartRow(n)
  local row = {}
  local full = romGfx(ICONS.heart, 8, "asset:ui/heart.png")
  for i = 1, 11 do row[i] = { src = (i <= n) and full or "asset:ui/heart-off.png" } end
  return row
end

local function animalList(base, size, count, kind, iconOf)
  local out = {}
  for i = 0, count - 1 do
    local rec = base + i * size
    local name = cstr(rec, 12)
    if not name or mem.u8(rec + 0x13) ~= 0xFF then break end
    local h = hearts(rec)
    local ok = mem.u8(rec + 0x14) >= 0x17
    out[#out + 1] = { kind = kind, idx = i, rec = rec, name = name, icon = iconOf(rec), hearts = h, heartRow = heartRow(h),
      health = ok and "Healthy" or "Sick", sick = not ok, max = h >= 11 }
  end
  return out
end

local function toolSlot(id, tag)
  if id < 0x100 or id > 0x150 then return { empty = true, name = "", short = "", icon = "asset:ui/crate.png", tag = tag } end
  local n = toolName(id)
  local kind = "tool"
  if id >= 0x130 and id <= 0x145 then kind = "seed" elseif id >= 0x14D then kind = "gem" end
  local icon = romIcon(ICONS.tools[id], (kind == "seed") and "asset:ui/seed.png" or (kind == "gem") and "asset:ui/gem.png" or "asset:ui/tool.png")
  return { empty = false, name = n, id = id, kind = kind, tag = tag, icon = icon,
    short = (n:gsub(" Seeds", "")):sub(1, 10) }
end

local function tools()
  local out = { toolSlot(mem.u16(SICKLE), "sickle") }
  for i = 0, 7 do out[#out + 1] = toolSlot(mem.u16(TOOLS + i * 2), "t" .. i) end
  return out
end

local function items()
  local out = {}
  local grid = {}
  for i = 0, 7 do
    local a = ITEMS + i * 4
    local id = mem.u8(a + 1)
    if id < N_ITEMS and (mem.u8(a) & 0xFE) == 0 then
      local n = itemName(id)
      local w = (mem.u8(a) & 1) == 1
      out[#out + 1] = { slot = i, id = id, name = w and (n .. " (gift)") or n, short = n:sub(1, 10), empty = false,
        icon = w and romIcon(ICONS.gift, "asset:ui/gift.png") or romIcon(ICONS.items[id], "asset:ui/item.png") }
    end
  end
  for i = 1, 8 do grid[i] = { empty = true, name = "", short = "", icon = "asset:ui/crate.png" } end
  for _, it in ipairs(out) do grid[it.slot + 1] = it end
  return out, grid
end

local function shipped()
  local out, total, kinds, seen = {}, 0, 0, 0
  for i = 0, N_SHIP - 1 do
    local v = mem.u32(SHIPPED + i * 4)
    local cnt = v & 0x7FFFFFFF
    if cnt > 99999 then cnt = 0 end
    if (v & 0x80000000) ~= 0 or cnt > 0 then
      seen = seen + 1
      if cnt > 0 then
        total = total + cnt
        kinds = kinds + 1
        out[#out + 1] = { name = SHIP_NAMES[i + 1], count = cnt, group = shipGroup(i), idx = i, icon = romIcon(ICONS.ship[i], "asset:ui/crate.png") }
      end
    end
  end
  return out, total, kinds, seen
end


-- ===== DESIGN SAMPLE DATA =====
-- Addresses for these are not mapped yet (see NOTES.md "Still open"); the values below only drive the layout.
-- Replace each block with real reads, then delete DESIGN.
local DESIGN = true

local function heartRowN(n, total)
  local row = {}
  local full = romGfx(ICONS.heart, 8, "asset:ui/heart.png")
  for i = 1, total do row[i] = { src = (i <= n) and full or "asset:ui/heart-off.png" } end
  return row
end

local function designData()
  return {
    hasClock = true, season = "Spring", day = 1, weekday = "Thu", clock = "6:00 AM", weather = "Sunny",
    family = {
      { name = "Jack", role = "You", berries = 4, berryRow = (function() local k = romGfx(ICONS.berry, 8, "asset:ui/apple.png"); return { {src=k},{src=k},{src=k},{src=k} } end)(), hasBerries = true, hasHearts = false, icon = romGfx(ICONS.jack, 16, "asset:ui/mk-player.png") },
      { name = "Popuri", role = "Wife", hasBerries = false, hasHearts = true, heartRow = heartRowN(12, 12), icon = romGfx(ICONS.popuri, 16, "asset:ui/chicken.png"), crown = false },
      { name = "Spunky", role = "Dog", hasBerries = false, hasHearts = true, heartRow = heartRowN(5, 11), icon = romGfx(ICONS.spunky, 16, "asset:ui/mk-dog.png") },
      { name = "Speedy", role = "Horse", hasBerries = false, hasHearts = true, heartRow = heartRowN(10, 11), icon = romGfx(ICONS.speedy, 16, "asset:ui/mk-horse.png"), crown = true },
    },
    sprites = {
      { name = "Staid", hearts = 1, heartRow = heartRowN(1, 11), job = "Work", b1 = 0.0, b2 = 0.0, b3 = 0.0, state = "N/A", icon = romGfx(ICONS.staid, 16, "asset:ui/sprite.png") },
      { name = "Nappy", hearts = 1, heartRow = heartRowN(1, 11), job = "Work", b1 = 0.0, b2 = 0.0, b3 = 0.0, state = "N/A", icon = romGfx(ICONS.nappy, 16, "asset:ui/sprite.png") },
      { name = "Bold", hearts = 9, heartRow = heartRowN(9, 11), job = "Work", b1 = 0.35, b2 = 0.0, b3 = 0.0, state = "Ready", icon = romGfx(ICONS.bold, 16, "asset:ui/sprite.png") },
    },
    fishing = {
      { name = "Message Bottle", size = "-", count = 1 }, { name = "Empty Can", size = "-", count = 4 },
      { name = "Branch", size = "-", count = 2 }, { name = "Small Fish", size = "18cm", count = 5 },
      { name = "Medium Fish", size = "34cm", count = 10 }, { name = "Large Fish", size = "52cm", count = 11 },
    },
    records = {
      { name = "Harvest", value = "8" }, { name = "Animal Husbandry", value = "8" },
      { name = "Watering", value = "8" }, { name = "Frisbee", value = "12m 1220cm" },
    },
    income = { { name = "Earned in one day", value = "9420400G" }, { name = "Spent in one day", value = "??????" } },
    where = "Town Cottage",
    mkPlayer = romGfx(ICONS.markPlayer, 16, "asset:ui/mk-player.png"), mkDog = romGfx(ICONS.markDog, 16, "asset:ui/mk-dog.png"),
    mkHorse = romGfx(ICONS.speedy, 16, "asset:ui/mk-horse.png"), coinIcon = romGfx(ICONS.coin, 16, "asset:ui/coin.png"),
    worldMarks = { player = { x = 30.5, y = 70 }, dog = { x = 38, y = 66 }, horse = { x = 35, y = 78 } },
    playerX = 30.5, playerY = 70, dogX = 38, dogY = 66, horseX = 35, horseY = 78,
    farmX = 22, farmY = 9,
  }
end

function update(ui)
  local farm, player = cstr(FARM_NAME), cstr(PLAYER_NAME)
  local gold = mem.u32(GOLD)
  if not farm or not player or gold > 99999999 then return { ready = false, waiting = true } end
  local page = ui.page or "farm"
  local chickIcon = romGfx(ICONS.chicken, 16, "asset:ui/chicken.png")
  local cowIcon = romGfx(ICONS.cow, 16, "asset:ui/barn.png")
  local sheepIcon = romGfx(ICONS.sheep, 16, "asset:ui/barn.png")
  local chickens = animalList(COOP, 0x30, 12, "Chicken", function() return chickIcon end)
  local barn = animalList(BARN, 0x3C, 12, "Cattle / Sheep", function(rec) return mem.u8(rec + 0x30) == 3 and sheepIcon or cowIcon end)
  local sick = 0
  for _, a in ipairs(chickens) do if a.sick then sick = sick + 1 end end
  for _, a in ipairs(barn) do if a.sick then sick = sick + 1 end end
  local ship, shipTotal, shipKinds, shipSeen = shipped()
  local it, itemGrid = items()
  local r = {
    ready = true, waiting = false, farm = farm, player = player, gold = gold,
    chickens = chickens, chickenCount = #chickens, barn = barn, barnCount = #barn,
    sickCount = sick, hasSick = sick > 0,
    tools = tools(), items = it, itemGrid = itemGrid, itemCount = #it, noItems = #it == 0,
    shipped = ship, shipTotal = shipTotal, shipKinds = shipKinds, shipSeen = shipSeen, shipAll = N_SHIP, noShipped = #ship == 0,
    navFarm = page == "farm", navRuck = page == "ruck", navBarn = page == "barn", navMaps = page == "maps", navMemo = page == "memo",
  }
  local cattle, sheep = {}, {}
  for _, a in ipairs(barn) do
    local t = mem.u8(a.rec + 0x30)
    if t == 3 then sheep[#sheep + 1] = a else cattle[#cattle + 1] = a end
  end
  r.cattle, r.sheep, r.cattleCount, r.sheepCount = cattle, sheep, #cattle, #sheep
  local bt, mt, st = ui.barnTab or "chickens", ui.memoTab or "ship", ui.mapTab or "town"
  r.tbChickens, r.tbCattle, r.tbSheep, r.tbSprites = bt == "chickens", bt == "cattle", bt == "sheep", bt == "sprites"
  r.tmShip, r.tmFish, r.tmRec = mt == "ship", mt == "fish", mt == "rec"
  r.mpTown, r.mpFarm = st == "town", st == "farm"
  if DESIGN then for k, v in pairs(designData()) do r[k] = v end end
  -- popups: animal detail
  if ui.tool and ui.tool ~= "" then r.tName = ui.tool end
  local sel = tonumber(ui.animal)
  if sel ~= nil then
    local list = (ui.kind == "barn") and barn or (ui.kind == "cattle") and cattle or (ui.kind == "sheep") and sheep or chickens
    local d = list[sel + 1]
    if d then
      r.dName, r.dHealth, r.dHearts, r.dRow, r.dSick, r.dKind = d.name, d.health, d.hearts, d.heartRow, d.sick, d.kind
    end
  end
  return r
end

actions = {}

local function animalRec(kind, i)
  i = tonumber(i)
  if i == nil then return nil end
  if kind == "barn" then return BARN + i * 0x3C end
  return COOP + i * 0x30
end

function actions.heal(kind, i)
  local rec = animalRec(kind, i)
  if not rec then return nil end
  local ok, why = mem.write8(rec + 0x14, 0x1F)
  if not ok then return { set = { note = "Couldn't heal: " .. tostring(why) } } end
  return { set = { note = "Healed" } }
end

function actions.maxHearts(kind, i)
  local rec = animalRec(kind, i)
  if not rec then return nil end
  local ok, why = mem.write8(rec + 0x12, 0xFF)
  if ok then ok, why = mem.write8(rec + 0x13, 0xFF) end
  if not ok then return { set = { note = "Couldn't change: " .. tostring(why) } } end
  return { set = { note = "Hearts maxed" } }
end

function actions.addGold(n)
  n = tonumber(n) or 0
  local ok, why = mem.write32(GOLD, math.min(GOLD_CAP, mem.u32(GOLD) + n))
  if not ok then return { set = { note = "Couldn't change: " .. tostring(why) } } end
  return nil
end
