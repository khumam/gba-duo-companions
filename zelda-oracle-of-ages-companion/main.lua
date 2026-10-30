-- Zelda: Oracle of Ages (GBC) memory map, from the oracles-disasm project's include/wram.s
-- (https://github.com/Stewmath/oracles-disasm); each Ages address is the first of the two
-- the file gives, and was read back on a Thor with the European build (CGB-AZ8P).

-- ---- Save data (work RAM, $C6xx) -------------------------------------------------------------
local RINGS_OBTAINED = 0xC616   -- 8 bytes, one bit per ring
local DUNGEON_END = 0xC688
local INVENTORY_B, INVENTORY_A = 0xC688, 0xC689 -- treasure id on each button
local INVENTORY = 0xC68A        -- 16 slots, treasure ids in the subscreen's order
local HEALTH, MAX_HEALTH = 0xC6AA, 0xC6AB -- quarter hearts
local HEART_PIECES = 0xC6AC
local RUPEES = 0xC6AD           -- u16, BCD
local SHIELD_LEVEL, BOMBS, MAX_BOMBS, SWORD_LEVEL, BOMBCHUS = 0xC6AF, 0xC6B0, 0xC6B1, 0xC6B2, 0xC6B3
local SATCHEL_LEVEL = 0xC6B4
local HOOK_LEVEL, HARP_SONG, BRACELET_LEVEL = 0xC6B6, 0xC6B7, 0xC6B8
local SEEDS = 0xC6B9            -- ember, scent, pegasus, gale, mystery
local GASHA_SEEDS = 0xC6BE
local ESSENCES = 0xC6BF         -- bitset
local SATCHEL_SEED = 0xC6C4
local RING_BOX = 0xC6C6         -- 5 ring ids, 0xFF empty
local ACTIVE_RING, RING_BOX_LEVEL = 0xC6CB, 0xC6CC
local ACTIVE_GROUP, ACTIVE_ROOM = 0xCC2D, 0xCC30
local ROOM_FLAGS = { [0] = 0xC700, [1] = 0xC800 } -- present, past: one byte per room, bit 4 = visited
local lastGroup = 0

local ART = "asset:ui/"

local function bcd(v) return string.format("%X", v) end -- counts are stored as BCD: 0x16 shows as 16

local ITEMS = {
  [0x01] = { "SHIELD", "shield", "level", SHIELD_LEVEL },
  [0x03] = { "BOMBS", "bombs", "count", BOMBS, MAX_BOMBS },
  [0x04] = { "CANE", "cane" },
  [0x05] = { "SWORD", "sword", "level", SWORD_LEVEL },
  [0x06] = { "BOOMERANG", "boomerang" },
  [0x0A] = { "HOOK", "hook", "level", HOOK_LEVEL },
  [0x0C] = { "BIGGORON", "biggoron" },
  [0x0D] = { "BOMBCHU", "bombchu", "count", BOMBCHUS },
  [0x0E] = { "FLUTE", "flute" },
  [0x0F] = { "SHOOTER", "shooter" },
  [0x11] = { "HARP", "harp" },
  [0x15] = { "SHOVEL", "shovel" },
  [0x16] = { "BRACELET", "bracelet", "level", BRACELET_LEVEL },
  [0x17] = { "FEATHER", "feather" },
  [0x19] = { "SATCHEL", "satchel" },
}

local function itemInfo(id)
  local it = ITEMS[id]
  if not it then return { name = string.format("ITEM %02X", id), icon = ART .. "unknown.png", level = "" } end
  local level = ""
  if it[3] == "level" then level = "L-" .. mem.u8(it[4])
  elseif it[3] == "count" then level = it[5] and (bcd(mem.u8(it[4])) .. "/" .. bcd(mem.u8(it[5]))) or bcd(mem.u8(it[4])) end
  return { name = it[1], icon = ART .. it[2] .. ".png", level = level }
end

local RING_NAMES = {
  [0] = "FRIENDSHIP", "POWER L1", "POWER L2", "POWER L3", "ARMOR L1", "ARMOR L2", "ARMOR L3", "RED", "BLUE", "GREEN",
  "CURSED", "EXPERTS", "BLAST", "RANG L1", "GBA TIME", "MAPLES", "STEADFAST", "PEGASUS", "TOSS", "HEART L1",
  "HEART L2", "SWIMMERS", "CHARGE", "LIGHT L1", "LIGHT L2", "BOMBERS", "GREEN LUCK", "BLUE LUCK", "GOLD LUCK", "RED LUCK",
  "GREEN HOLY", "BLUE HOLY", "RED HOLY", "SNOWSHOE", "ROCS", "QUICKSAND", "RED JOY", "BLUE JOY", "GOLD JOY", "GREEN JOY",
  "DISCOVERY", "RANG L2", "OCTO", "MOBLIN", "LIKE LIKE", "SUBROSIAN", "FIRST GEN", "SPIN", "BOMBPROOF", "ENERGY",
  "DBL EDGED", "GBA NATURE", "SLAYERS", "RUPEE", "VICTORY", "SIGN", "100TH", "WHISP", "GASHA", "PEACE",
  "ZORA", "FIST", "WHIMSICAL", "PROTECTION",
}

local SEED_NAMES = {
  { "EMBER", "seed-ember" }, { "SCENT", "seed-scent" }, { "PEGASUS", "seed-pegasus" },
  { "GALE", "seed-gale" }, { "MYSTERY", "seed-mystery" },
}
local SONGS = { [1] = "ECHOES", [2] = "CURRENTS", [3] = "AGES" }

local lastEra = "PRESENT"


local function hearts(health, max)
  local top, bottom = {}, {}
  for i = 1, math.min(max // 4, 12) do
    local rem = health - (i - 1) * 4
    local name = rem >= 3 and "heart-full" or (rem >= 1 and "heart-half" or "heart-empty")
    local row = i <= 6 and top or bottom
    row[#row + 1] = { src = ART .. name .. ".png" }
  end
  return top, bottom
end

-- Items on B or A leave the inventory list (the subscreen shows their slot empty), so they come
-- first, tagged, followed by the stored items in the game's slot order.
local function slotsList(b, a)
  local out = {}
  local function add(id, tag)
    local info = itemInfo(id)
    out[#out + 1] = { empty = false, equipped = tag ~= "", tag = tag, name = info.name, level = info.level, icon = info.icon }
  end
  if b ~= 0 and b <= 0x1F then add(b, "B") end
  if a ~= 0 and a <= 0x1F and a ~= b then add(a, "A") end
  for i = 0, 15 do
    local id = mem.u8(INVENTORY + i)
    if id ~= 0 and id <= 0x1F and #out < 16 then add(id, "") end
  end
  while #out < 16 do
    out[#out + 1] = { empty = true, equipped = false, tag = "", name = "", level = "", icon = ART .. "blank.png" }
  end
  return out
end

local function ringInfo()
  local worn = mem.u8(ACTIVE_RING)
  local count, rows = 0, {}
  for r = 0, 63 do
    local on = (mem.u8(RINGS_OBTAINED + r // 8) >> (r % 8)) & 1 == 1
    if on then count = count + 1 end
    local row = r // 8 + 1
    rows[row] = rows[row] or { cells = {} }
    rows[row].cells[#rows[row].cells + 1] = { on = on, src = ART .. "ring-" .. r .. ".png" }
  end
  local box = {}
  for i = 0, 4 do
    local id = mem.u8(RING_BOX + i)
    local ok = id ~= 0xFF and id < 64
    box[#box + 1] = { filled = ok, name = ok and RING_NAMES[id] or "-", icon = ART .. (ok and ("ring-" .. id) or "blank") .. ".png" }
  end
  return {
    worn = worn == 0xFF and "NONE" or (RING_NAMES[worn & 0x3F] or "?") .. " RING",
    wornIcon = ART .. (worn == 0xFF and "blank" or ("ring-" .. (worn & 0x3F))) .. ".png",
    boxLevel = "L-" .. mem.u8(RING_BOX_LEVEL),
    box = box, count = count, dotRows = rows,
  }
end

function update(ui)
  local max, health = mem.u8(MAX_HEALTH), mem.u8(HEALTH)
  local page = ui and ui.page or "items"
  local out = {
    ready = false, waiting = true,
    waitSub = "GBADUO COMPANION PACK",
    navItems = page == "items", navMap = page == "map", navSeeds = page == "seeds", navRings = page == "rings", navStatus = page == "status",
  }
  if max < 12 or max > 64 or max % 4 ~= 0 or health > max then return out end

  local b, a = mem.u8(INVENTORY_B), mem.u8(INVENTORY_A)
  local bi = (b ~= 0 and b <= 0x1F) and itemInfo(b) or { name = "", level = "", icon = ART .. "blank.png" }
  local ai = (a ~= 0 and a <= 0x1F) and itemInfo(a) or { name = "", level = "", icon = ART .. "blank.png" }
  local top, bottom = hearts(health, max)

  local picked = mem.u8(SATCHEL_SEED) & 7
  local seeds = {}
  for i, s in ipairs(SEED_NAMES) do
    seeds[i] = { icon = ART .. s[2] .. ".png", name = s[1], count = bcd(mem.u8(SEEDS + i - 1)), picked = picked == i - 1, tag = picked == i - 1 and "IN SATCHEL" or "" }
  end

  local essences, essenceCount = {}, 0
  local bits = mem.u8(ESSENCES)
  for i = 0, 7 do
    local on = (bits >> i) & 1 == 1
    if on then essenceCount = essenceCount + 1 end
    essences[#essences + 1] = { src = ART .. (on and "essence-on" or "essence-off") .. ".png" }
  end

  local lifeHearts = {}
  for i = 1, math.min(max // 4, 16) do
    local rem = health - (i - 1) * 4
    local name = rem >= 3 and "heart-full" or (rem >= 1 and "heart-half" or "heart-empty")
    lifeHearts[i] = { src = ART .. name .. ".png" }
  end

  local pieces, have = {}, mem.u8(HEART_PIECES) & 3
  for i = 1, 4 do pieces[i] = { src = ART .. (i <= have and "piece" or "heart-empty") .. ".png" } end

  local group = mem.u8(ACTIVE_GROUP)
  if group == 0 or group == 1 then lastGroup = group end
  lastEra = lastGroup == 0 and "PRESENT" or "PAST"
  local room = mem.u8(ACTIVE_ROOM)
  local rows, seen = {}, 0
  for y = 0, 13 do -- the overworld is 14 x 14 rooms (id = y * 16 + x)
    local cells = {}
    for x = 0, 13 do
      local id = y * 16 + x
      local visited = (mem.u8(ROOM_FLAGS[lastGroup] + id) >> 4) & 1 == 1
      if visited then seen = seen + 1 end
      cells[x + 1] = { unseen = not visited, here = group == lastGroup and room == id }
    end
    rows[y + 1] = { cells = cells }
  end
  out.map = {
    rows = rows, era = lastEra, count = tostring(seen), room = string.format("%02X", room),
    present = lastGroup == 0, past = lastGroup == 1,
  }

  out.ready, out.waiting = true, false
  out.rupees = ("000" .. bcd(mem.u16(RUPEES))):sub(-3)
  out.hud = {
    bIcon = bi.icon, bName = bi.name, bLevel = bi.level,
    aIcon = ai.icon, aName = ai.name, aLevel = ai.level,
  }
  out.heartsTop, out.heartsBottom = top, bottom
  out.slots = slotsList(b, a)
  out.seeds = seeds
  out.supplies = {
    { icon = ART .. "bombs.png", label = "BOMBS", value = bcd(mem.u8(BOMBS)) .. "/" .. bcd(mem.u8(MAX_BOMBS)) },
    { icon = ART .. "bombchu.png", label = "BOMBCHUS", value = bcd(mem.u8(BOMBCHUS)) },
    { icon = ART .. "seed-mystery.png", label = "GASHA", value = bcd(mem.u8(GASHA_SEEDS)) },
  }
  out.ring = ringInfo()
  out.status = {
    hearts = string.format("%d/%d", (health + 3) // 4, max // 4),
    pieces = pieces, essences = essences, essenceCount = essenceCount, lifeHearts = lifeHearts,
    facts = {
      { label = "ERA", value = lastEra },
      { label = "SONG", value = SONGS[mem.u8(HARP_SONG)] or "-" },
      { label = "ROOM", value = string.format("%02X", mem.u8(ACTIVE_ROOM)) },
    },
  }
  return out
end
