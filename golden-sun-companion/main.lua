-- Golden Sun (GBA) memory map, from the gsdata RAM map
-- https://gsdata.fandom.com/wiki/RAM_Map (written for The Lost Age)
-- Checked on a Golden Sun ROM (AGSI): the save block starts at 0x02000000 with the
-- same layout, but the party blocks begin at 0x02000500, 0x20 lower than in TLA.
local item_names = pack.require("item_names")
local djinn_names = pack.require("djinn_names")
local psynergy_names = pack.require("psynergy_names")

-- ---- Save block (EWRAM) ---------------------------------------------------------
local COINS = 0x02000014      -- u32
local PC_ORDER = 0x0200001C   -- one byte per party slot, 0xFF ends the list
local PC_BASE = 0x02000500     -- first character block
local PC_SIZE = 0x14C

-- Offsets inside a character block
local NAME = 0x00             -- 12 bytes ASCII
local LEVEL = 0x0F            -- u8, not checked on a device yet
local MAX_HP, MAX_PP = 0x34, 0x36
local HP, PP = 0x38, 0x3A
local ATK, DEF, AGI, LCK = 0x3C, 0x3E, 0x40, 0x42
local ELEMENTS = 0x48         -- Venus, Mercury, Mars, Jupiter: power u16, resist u16
local ITEMS = 0xD8            -- u16 each: 0x1FF id, 0x200 equipped, 0x400 broken, 0xF800 qty
local ITEM_SLOTS = 15
local SPELLS = 0x58           -- u32 each, 0 ends the list; low 15 bits are the Psynergy id
local SPELL_SLOTS = 32
local EXP = 0x124             -- u32, not checked on a device yet

-- ---- Area map (the same RAM map game.lua's wide view reads) ----------------------
local MAP_GRID = 0x02010000      -- 128 x 128 u32 cells, the BG1..BG3 layers side by side
local MAP_METATILES = 0x02020000 -- 4 u16 tile entries per metatile id
local MAP_SHADOW = 0x03001AD0    -- the BG scroll the game shows next: x, y as u16 per BG, from BG0
local LEADER = 0x02030EC4        -- the party leader's actor: x (16.16) at +0, z at +4, y at +8; screen y = y - z
local MAP_SCALE = 2           -- 2 map px to a picture px
local MAP_PIC_W, MAP_PIC_H = 256, 184 -- the picture: 512 x 368 map px, the card's shape (shown scaled up to fill it)
local MAP_REDRAW = 12            -- ticks between redraws of an unchanged view (the tiles load a little late)

local mapShot = { sig = nil, image = nil, age = 0 }

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function areaMap()
  local dispcnt = mem.u16(0x04000000)
  if dispcnt & 7 ~= 0 or dispcnt & 0x0E00 ~= 0x0E00 then return nil end
  local bg = {}
  for n = 1, 3 do
    local control = mem.u16(0x04000008 + n * 2)
    if control & 0x80 ~= 0 or (control >> 14) ~= 0 then return nil end
    bg[n] = { n = n, priority = control & 3, tiles = 0x06000000 + ((control >> 2) & 3) * 0x4000,
              hx = mem.u16(MAP_SHADOW + n * 4), hy = mem.u16(MAP_SHADOW + n * 4 + 2) }
  end
  local width = bg[2].hx - bg[3].hx
  if width < 16 or width % 16 ~= 0 or width > 16 * 128 // 3 then return nil end
  if bg[1].hx - bg[2].hx ~= width or bg[1].hy ~= bg[3].hy or bg[2].hy ~= bg[3].hy then return nil end
  local cols = width // 16

  -- the ground layer fills a whole area with its own metatile past the map's end: the map is the rows
  -- above the last one that is mostly something else
  local function cell(r, c) return mem.u32(MAP_GRID + (r * 128 + c) * 4) & 0xFFF end
  local filler = cell(127, 0)
  local rows = 0
  for r = 127, 0, -1 do
    local other = 0
    for c = 0, cols - 1 do if cell(r, c) ~= filler then other = other + 1 end end
    if other * 2 >= cols then rows = r + 1 break end
  end
  if rows < 10 then return nil end
  local mapW, mapH = cols * 16, rows * 16

  -- our character: the party leader's actor, in the same pixels as the map
  local px = mem.u16(LEADER + 2)
  local py = mem.u16(LEADER + 10) - mem.u16(LEADER + 6) - 16

  -- the view follows him a tile at a time and stops at the map's edges (a map smaller than the view is centred)
  local viewW, viewH = MAP_PIC_W * MAP_SCALE, MAP_PIC_H * MAP_SCALE
  local x0 = mapW <= viewW and (mapW - viewW) // 2 or clamp((px - viewW // 2) // 16 * 16, 0, mapW - viewW)
  local y0 = mapH <= viewH and (mapH - viewH) // 2 or clamp((py - viewH // 2) // 16 * 16, 0, mapH - viewH)

  local sig = table.concat({ cols, rows, filler, x0, y0, cell(0, 0), cell(rows // 2, cols // 2), cell(rows - 1, cols - 1) }, ":")
  mapShot.age = mapShot.age + 1
  if sig ~= mapShot.sig or not mapShot.image or mapShot.age >= MAP_REDRAW then
    local layers = {}
    for n = 3, 1, -1 do
      layers[#layers + 1] = { grid = MAP_GRID + (3 - n) * cols * 4, stride = 128, cellBytes = 4, gridW = cols, gridH = 128,
                              idMask = 0xFFF, metatiles = MAP_METATILES, tiles = bg[n].tiles, priority = bg[n].priority, n = n }
    end
    table.sort(layers, function(a, b)
      if a.priority ~= b.priority then return a.priority > b.priority end
      return a.n > b.n
    end)
    mapShot.image = gfx.layers{ x = x0, y = y0, width = MAP_PIC_W, height = MAP_PIC_H, scale = MAP_SCALE,
                                palette = 0x05000000, layers = layers }
    mapShot.sig, mapShot.age = sig, 0
  end

  local fx, fy = (px - x0) / viewW, (py - y0) / viewH
  return {
    image = mapShot.image, ratio = string.format("%.4f", MAP_PIC_W / MAP_PIC_H),
    inside = fx >= 0 and fx <= 1 and fy >= 0 and fy <= 1,
    mx = string.format("%.2f%%", fx * 100), my = string.format("%.2f%%", fy * 100),
  }
end

local ELEMENT_INFO = {
  { "Venus", "#C98B3C" }, { "Mercury", "#4AA3E0" }, { "Mars", "#E5584B" }, { "Jupiter", "#B58CE0" },
}

-- Face art cropped from the game's own status screen; only the members seen so far.
local PORTRAITS = {
  Isaac = "asset:img/portrait-isaac.png",
  Garet = "asset:img/portrait-garet.png",
  Ivan = "asset:img/portrait-ivan.png",
  Mia = "asset:img/portrait-mia.png",
  Jenna = "asset:img/portrait-jenna.png",
}

local function readName(base)
  local raw = mem.read(base + NAME, 12)
  local stop = raw:find("\0", 1, true)
  if stop then raw = raw:sub(1, stop - 1) end
  return raw
end

local function validName(name)
  return #name >= 2 and name:match("^[%w%s%-']+$") ~= nil
end

local function readElements(base)
  local list, best, bestPower = {}, 1, -1
  for i = 1, 4 do
    local power = mem.u16(base + ELEMENTS + (i - 1) * 4)
    local resist = mem.u16(base + ELEMENTS + (i - 1) * 4 + 2)
    list[i] = { name = ELEMENT_INFO[i][1], color = ELEMENT_INFO[i][2], power = power, resist = resist }
    if power > bestPower then best, bestPower = i, power end
  end
  return list, ELEMENT_INFO[best][1]
end

local function readItems(base, selected)
  local items = {}
  for slot = 0, ITEM_SLOTS - 1 do
    local word = mem.u16(base + ITEMS + slot * 2)
    local id = word & 0x1FF
    if id ~= 0 then
      local qty = ((word >> 11) & 0x1F) + 1 -- stored as count - 1 (Isaac's 3 Herbs read 2)
      items[#items + 1] = {
        name = item_names[id] or string.format("Item %02X", id),
        id = string.format("%02X", id),
        icon = string.format("asset:img/items/%03x.png", id), hasIcon = item_names[id] ~= nil,
        qty = qty > 1 and ("×" .. qty) or "",
        equipped = (word & 0x200) ~= 0,
        broken = (word & 0x400) ~= 0,
        selected = (#items) == selected,
      }
    end
  end
  return items
end

local function readSpells(base)
  local spells = {}
  for slot = 0, SPELL_SLOTS - 1 do
    local word = mem.u32(base + SPELLS + slot * 4)
    if word == 0 then break end
    local id = word & 0x7FFF
    local info = psynergy_names[id]
    spells[#spells + 1] = {
      name = info and info[1] or ("Psynergy " .. id), pp = info and tostring(info[2]) or "—",
      icon = string.format("asset:img/psy/%03d.png", id), hasIcon = info ~= nil,
    }
  end
  return spells
end

local function fraction(value, max)
  if max <= 0 then return 0 end
  return math.min(1, value / max)
end

-- The order list is only valid once a save is loaded: unique slots, ended by 0xFF
-- (or four members). Before that (title, intro) the bytes are all 0 and repeat.
local function readParty()
  local party, seen, ended = {}, {}, false
  for slot = 0, 3 do
    local index = mem.u8(PC_ORDER + slot)
    if index == 0xFF then ended = true break end
    if index >= 8 or seen[index] then return {} end
    seen[index] = true
    local base = PC_BASE + index * PC_SIZE
    local name = readName(base)
    if not validName(name) then return {} end
    party[#party + 1] = { index = index, base = base, name = name }
  end
  if not ended and #party < 4 then return {} end
  return party
end

function update(ui)
  local party = readParty()
  local page = ui.page or "party"
  local out = {
    ready = false, waiting = true,
    navParty = page == "party", navDjinn = page == "djinn", navPsynergy = page == "psynergy", navMaps = page == "maps",
  }
  if #party == 0 then return out end

  local sel = math.min(tonumber(ui.member) or 0, #party - 1)
  local members = {}
  for i, p in ipairs(party) do
    local elements, adept = readElements(p.base)
    local mmax = mem.u16(p.base + MAX_HP)
    local mhp = math.min(mem.u16(p.base + HP), mmax)
    members[i] = {
      name = p.name, active = (i - 1) == sel, adept = adept, color = elements[1].color,
      level = mem.u8(p.base + LEVEL), hp = mhp, maxHp = mmax,
      low = mhp > 0 and mhp * 4 <= mmax, down = mhp == 0,
    }
    for _, e in ipairs(elements) do if e.name == adept then members[i].color = e.color end end
  end

  local p = party[sel + 1]
  local b = p.base
  local maxHp, maxPp = mem.u16(b + MAX_HP), mem.u16(b + MAX_PP)
  if maxHp == 0 or maxHp > 9999 then return out end
  local hp, pp = math.min(mem.u16(b + HP), maxHp), math.min(mem.u16(b + PP), maxPp)
  local elements, adept = readElements(b)
  local itemSel = tonumber(ui.item) or 0
  local items = readItems(b, itemSel)
  local current = items[itemSel + 1] or items[1] or { name = "—", id = "—", qty = "", equipped = false, broken = false }

  out.ready, out.waiting = true, false
  out.members = members
  out.coins = mem.u32(COINS)
  out.m = {
    name = p.name,
    initial = p.name:sub(1, 1):upper(),
    portrait = PORTRAITS[p.name], hasPortrait = PORTRAITS[p.name] ~= nil, noPortrait = PORTRAITS[p.name] == nil,
    color = members[sel + 1].color,
    level = mem.u8(b + LEVEL),
    adept = adept,
    sub = adept .. " Adept",
    hp = hp, maxHp = maxHp, hpPct = fraction(hp, maxHp),
    pp = pp, maxPp = maxPp, ppPct = fraction(pp, maxPp),
    exp = mem.u32(b + EXP),
    atk = mem.u16(b + ATK), def = mem.u16(b + DEF), agi = mem.u16(b + AGI), lck = mem.u8(b + LCK),
    elements = elements,
    items = items,
    spells = readSpells(b),
    low = hp > 0 and hp * 4 <= maxHp,
    down = hp == 0,
  }
  out.item = {
    name = current.name, id = current.id,
    qty = current.qty ~= "" and current.qty or "×1",
    equipped = current.equipped and "Yes" or "No",
    broken = current.broken and "Yes" or "No",
    slot = tostring(itemSel + 1),
  }
  out.djinnCols = djinn_names
  out.map = { on = false, off = true, hasMe = false }
  if page == "maps" then
    local ok, area = pcall(areaMap)
    if ok and area then
      out.map = { on = true, off = false, hasMe = area.inside, image = area.image, ratio = area.ratio, mx = area.mx, my = area.my }
    end
  end
  return out
end
