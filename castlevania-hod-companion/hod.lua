-- hod.lua : Castlevania: Harmony of Dissonance (US, ACHE) memory map and readers.
-- Every address here is checked against the game's own screens; evidence in NOTES.md.
local M = {}

M.CODE = "ACHE"

M.A = {
  -- game
  gameState  = 0x0200000C, -- u8: 0 Konami, 1 title, 2 file menu/name entry, 3 in game, 7 game over, 0x0A prologue, 0x0C logo
  roomPos    = 0x02000070, -- u8 bit0 = castle B, bits1-7 = map X; +1 = map Y
  playTime   = 0x02000088, -- u32 frames (header, live)
  pctX10     = 0x02000082, -- u16 completion ×10 (header)
  bossFlags  = 0x02000358, -- u32 boss death bits (bit n = boss n)
  -- player (live)
  character  = 0x020184F8, -- u32: 0 Juste, 1 Simon, 2 Maxim
  status     = 0x0201852E, -- u16: 1 poison, 2 curse, 4 petrify
  hp         = 0x0201854E, -- u16
  mp         = 0x02018550, -- u16
  stats      = 0x02018552, -- 4 × u16: STR DEF INT LCK (with equipment)
  level      = 0x0201877C, -- u8
  subweapon  = 0x0201877E, -- u8: 0 none, 1 knife .. 7 shuriken
  spell      = 0x0201877F, -- u8: bits0-6 book (1 fire..5 summon), bit7 on
  armor      = 0x02018780, -- 4 × u8: body, goods, hands, legs (0xFF none)
  weapon     = 0x02018784, -- u8 whip attachment (0xFF none)
  maxHp      = 0x02018786, -- u16
  maxMp      = 0x02018788, -- u16
  maxHearts  = 0x0201878A, -- u16
  baseStats  = 0x0201878C, -- 4 × u16 STR DEF INT LCK without equipment
  hearts     = 0x02018794, -- u16
  exp        = 0x02018798, -- u32
  gold       = 0x0201879C, -- u32 (live; 0x02000084 is the header copy)
  items      = 0x020187A0, -- 28 × u8 counts (consumables, maps, hint cards, jewels)
  weapons    = 0x020187BC, -- u16 owned bits, 9 whip attachments
  armorOwned = 0x020187BE, -- 128 × u8 counts
  booksOwned = 0x0201883E, -- u8 bits, 5 spellbooks
  relicsOwned= 0x0201883F, -- u16 bits (unaligned), 12 relics
  relicsOn   = 0x02018841, -- u16 bits (unaligned)
  furniture  = 0x02018843, -- u32 bits (unaligned), 31 collectibles
  kills      = 0x02018854, -- enemy killed bits (bestiary)
}

-- ROM
M.R = {
  text      = 0x08495500, -- u32 pointers, 0x2AB strings (halfword Shift-JIS, end F00A)
  lowerMap  = 0x080C5508, -- 4-byte entries: halfword >= 0x8540 -> Shift-JIS
  mapMeta   = 0x080DAD94, -- 64×40 u16 tiles: 15 save, 14 warp, 13 B-warp, 8-11 region, 6-7 map item
}

-- text ids
M.T = { char = 0x00, item = 0x22, weapon = 0x3E, armor = 0x47, book = 0xC7, relic = 0xCC,
        furniture = 0xD8, desc = 0xF7, enemy = 0x1CC }

-- Area names: the game draws them as pictures (no text entries); region index from the map tile.
M.AREAS = { "Entrance", "Marble Corridor", "Shrine of the Apostates", "Castle Top Floor", "Skeleton Cave",
  "Luminous Cavern", "Aqueduct of Dragons", "Sky Walkway", "Clock Tower", "Castle Treasury",
  "Room of Illusion", "The Wailing Way", "Chapel of Dissonance" }

-- Shift-JIS fullwidth -> ASCII for the characters the game's English text uses.
local PUNCT = { [0x8140] = " ", [0x8141] = ",", [0x8142] = ".", [0x8143] = ",", [0x8144] = ".",
  [0x8146] = ":", [0x8147] = ";", [0x8148] = "?", [0x8149] = "!", [0x815B] = "-", [0x815C] = "-",
  [0x815D] = "-", [0x815E] = "/", [0x8165] = "'", [0x8166] = "'", [0x8167] = "\"", [0x8168] = "\"",
  [0x8169] = "(", [0x816A] = ")", [0x817B] = "+", [0x817C] = "-", [0x8181] = "=", [0x8190] = "$",
  [0x8193] = "%", [0x8195] = "&", [0x8196] = "*", [0x8197] = "@", [0x8175] = "\"", [0x8176] = "\"",
  [0x8163] = "...", [0x8160] = "~" }

local function sjis(h)
  if h >= 0x824F and h <= 0x8258 then return string.char(h - 0x824F + 48) end
  if h >= 0x8260 and h <= 0x8279 then return string.char(h - 0x8260 + 65) end
  if h >= 0x8281 and h <= 0x829A then return string.char(h - 0x8281 + 97) end
  return PUNCT[h] or ""
end

local cache = {}
-- text(id) -> plain string; "\n" for line breaks; control codes dropped.
function M.text(id)
  local s = cache[id]
  if s then return s end
  local p = mem.u32(M.R.text + 4 * id) + 2
  local out, n, multi = {}, 0, false
  while n < 200 do
    local h = mem.u16(p); p = p + 2; n = n + 1
    if h == 0xF00A then break end
    if multi then multi = false
    elseif h & 0xFF00 == 0xF000 then
      local c = h & 0xFF
      if c == 1 or c == 2 or c == 3 or c == 7 or c == 8 then multi = true
      elseif c == 6 then out[#out + 1] = "\n" end
    elseif h >= 0x8540 then out[#out + 1] = sjis(mem.u16(M.R.lowerMap + (h - 0x8540) * 4))
    elseif h >= 0x8140 then out[#out + 1] = sjis(h) end
  end
  s = table.concat(out):gsub("%s+$", "")
  cache[id] = s
  return s
end

-- Area at the player's room: region index (bits 8-11) of the map tile.
function M.place()
  local b = mem.u8(M.A.roomPos)
  local x, y, castleB = b >> 1, mem.u8(M.A.roomPos + 1), (b & 1) == 1
  if x >= 64 or y >= 40 then return nil end
  local t = mem.u16(M.R.mapMeta + 2 * (y * 64 + x))
  if t == 0xFFFF then return nil end
  return { area = M.AREAS[((t >> 8) & 15) + 1], castleB = castleB, x = x, y = y,
           save = (t & 0x8000) ~= 0, warp = (t & 0x4000) ~= 0 }
end

-- EXP needed for the next level: 60·L·(L+1) − EXP (fits the STATUS screen at Lv 1, 27, 45, 50).
function M.next(level, exp)
  if level >= 99 then return nil end
  return 60 * level * (level + 1) - exp
end

-- Share of the way from this level to the next (0..1).
function M.expPct(level, exp)
  if level >= 99 then return 1 end
  local from = 60 * (level - 1) * level
  return math.max(0, math.min(1, (exp - from) / (120 * level)))
end

-- ---- items -------------------------------------------------------------------------
-- Item records (ROM): u16 id, u16 icon (low byte = icon+1, high byte = palette bank), then per kind:
-- whip +6 STR DEF INT LCK (s8); armor +4 type, +6 STR DEF INT LCK (s8), +10 resistances. Global item
-- order = text order: 28 consumables, 9 whip attachments, 128 armor, 5 books, 12 relics, 31 furniture.
M.LIST = {
  cons  = { at = 0x084B24A4, size = 12, n = 28,  base = 0 },
  whip  = { at = 0x084B25F4, size = 12, n = 9,   base = 28 },
  armor = { at = 0x084B2660, size = 12, n = 128, base = 37 },
  book  = { at = 0x084B2C60, size = 4,  n = 5,   base = 165 },
  relic = { at = 0x084B2C74, size = 4,  n = 12,  base = 170 },
  furn  = { at = 0x084B2CA4, size = 4,  n = 31,  base = 182 },
}

-- Equip-screen label per armor type (+4): the game names a slot after the piece in it.
M.SLOT = { [0] = "GOODS", [1] = "HANDS", [2] = "BODY", [3] = "HEAD", [4] = "LEGS", [12] = "LEGS" }
function M.armorType(i) return mem.u8(M.LIST.armor.at + 12 * i + 4) end
-- Resistance bits of armor (+10) and element bits of whip attachments (+10).
M.RESIST = { "Poison", "Curse", "Stone", "Fire", "Ice", "Thunder", "Wind" }
M.ELEMENT = { "Fire", "Ice", "Thunder", "Wind" }
function M.bits(kind, i) local L = M.LIST[kind]; return mem.u16(L.at + L.size * i + 10) end
-- Consumable record: +4 type (0 HP, 1 MP, 2 cure, 3 invincible, 4 key item), +6 u16 amount.
function M.consType(i) return mem.u8(M.LIST.cons.at + 12 * i + 4) end
function M.consAmount(i) return mem.u16(M.LIST.cons.at + 12 * i + 6) end

function M.name(kind, i) return M.text(0x22 + M.LIST[kind].base + i) end
function M.descId(kind, i) return 0xF7 + M.LIST[kind].base + i end

-- 16x16 item icon: four 128x128 icon pages (0x2004 bytes apart: 4-byte header + 0x2000), laid out 2D
-- (16 tiles per row, 8 icons per row: icon k at tile 32*(k%64 div 8) + 2*(k mod 8), second row +16 tiles);
-- palette list 0x08124104 (+4), 32 bytes per bank. Checked against the Items menu's info-bar icon (OAM).
local ICON_PAGES, ICON_PAL = 0x080E8A08, 0x08124108
function M.iconAt(field)
  local k = (field & 0xFF) - 1
  if k < 0 then return nil end
  local j = k % 64
  local ok, key = pcall(gfx.sprite, {
    tiles = ICON_PAGES + (k // 64) * 0x2004 + 32 * (32 * (j // 8) + 2 * (j % 8)),
    palette = ICON_PAL + 32 * (field >> 8), width = 16, height = 16,
    parts = { { x = 0, y = 0, w = 16, h = 8, tile = 0, bank = 0 }, { x = 0, y = 8, w = 16, h = 8, tile = 16, bank = 0 } } })
  return ok and key or nil
end
function M.icon(kind, i)
  local L = M.LIST[kind]
  return M.iconAt(mem.u16(L.at + L.size * i + 2))
end

-- Signed stat bonuses STR DEF INT LCK of a whip attachment or armor piece.
function M.bonus(kind, i)
  local L = M.LIST[kind]
  local a, out = L.at + L.size * i + 6, {}
  for k = 0, 3 do out[k + 1] = mem.s8(a + k) end
  return out
end

-- ---- subweapons ----------------------------------------------------------------------
-- Names are not in the text list (the game uses these words in the armor descriptions).
M.SUBWEAPONS = { "Knife", "Axe", "Cross", "Holy Water", "Holy Book", "Sacred Fist", "Shuriken" }
-- HUD icons: 16x16 in the icon pages, 2D (16 tiles per row, 0x200 bytes), palette bank 1.
local SUB_ICON = { 0x080EC64C, 0x080EC6CC, 0x080EC60C, 0x080EC68C, 0x080EC70C, 0x080EC3CC, 0x080ECA10 }
function M.subIcon(n)
  local t = SUB_ICON[n]
  if not t then return nil end
  local ok, key = pcall(gfx.sprite, { tiles = t, palette = 0x08124128, width = 16, height = 16,
    parts = { { x = 0, y = 0, w = 16, h = 8, tile = 0, bank = 0 }, { x = 0, y = 8, w = 16, h = 8, tile = 16, bank = 0 } } })
  return ok and key or nil
end
-- Subweapon list 0x080E2308, 0xC bytes: +0 max at once, +1 heart cost.
function M.subHearts(n) return mem.u8(0x080E2308 + 0xC * n + 1) end

-- ---- player sprites (standing frame in a save room, raw 2D sheets: 16 tiles per row) ----------
local SPRITES = {
  [0] = { tiles = 0x0811CFF0, palette = 0x08124108, width = 16, height = 40,
          parts = { { x = 5, y = 0, w = 8, h = 8, tile = 79, bank = 0 },
                    { x = 0, y = 8, w = 16, h = 8, tile = 0, bank = 0 }, { x = 0, y = 16, w = 16, h = 8, tile = 16, bank = 0 },
                    { x = 0, y = 24, w = 16, h = 8, tile = 32, bank = 0 }, { x = 0, y = 32, w = 16, h = 8, tile = 48, bank = 0 } } },
  [2] = { tiles = 0x080F1418, palette = 0x081260F8, width = 24, height = 40,
          parts = { { x = 0, y = 0, w = 16, h = 8, tile = 0, bank = 0 }, { x = 0, y = 8, w = 16, h = 8, tile = 16, bank = 0 },
                    { x = 0, y = 16, w = 16, h = 8, tile = 32, bank = 0 }, { x = 0, y = 24, w = 16, h = 8, tile = 48, bank = 0 },
                    { x = 16, y = 16, w = 8, h = 8, tile = 9, bank = 0 }, { x = 16, y = 24, w = 8, h = 8, tile = 25, bank = 0 },
                    { x = 0, y = 32, w = 16, h = 8, tile = 22, bank = 0 }, { x = 16, y = 32, w = 8, h = 8, tile = 41, bank = 0 } } },
}
function M.sprite(character)
  local s = SPRITES[character]
  if not s then return nil end
  local ok, key = pcall(gfx.sprite, s)
  return ok and key or nil
end

return M
