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
    navParty = page == "party", navDjinn = page == "djinn", navPsynergy = page == "psynergy",
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
  return out
end
