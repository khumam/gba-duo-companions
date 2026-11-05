-- The NPCs, trainers, items and doors of the current map (Emerald 1.0), read from the map's
-- event table in the ROM (gMapHeader.events). Used by game.lua (Wide view markers). The game only keeps the objects near the camera alive, so this table is the
-- only place that knows about the rest. An object whose flag is set (an item taken, an NPC gone) is left out.
local M = {}

local MAP_OFFSET = 7                -- the border around a map in the game's grid
local SAVEBLOCK1_PTR = 0x03005D8C   -- gSaveBlock1Ptr
local FLAGS_OFFSET = 0x1270         -- SaveBlock1.flags
local FLAG_COUNT = 0x960            -- flag ids below this live in that array (the rest are temporary)
local GFX_ITEM_BALL = 59            -- OBJ_EVENT_GFX_ITEM_BALL

M.NPC, M.TRAINER, M.ITEM = 1, 2, 3

-- The sprite of an object, from the ROM: gObjectEventGraphicsInfoPointers (the ids below 240, Emerald 1.0) points at
-- an ObjectEventGraphicsInfo { tileTag, paletteTag1, paletteTag2, size, width, height, ..., images @0x1C }, whose
-- first SpriteFrameImage is the object facing the player; the palette is found by its tag in
-- sObjectEventSpritePalettes. Anything that does not look right (another ROM, an unused graphics id) has no
-- sprite and is left out: only real sprites are drawn.
local GRAPHICS_INFO_TABLE, GRAPHICS_INFO_COUNT = 0x08505620, 240
local SPRITE_PALETTES, SPRITE_PALETTE_COUNT = 0x0850BBC8, 35
local SIZES = { [8] = true, [16] = true, [32] = true, [48] = true, [64] = true }

local eventsAt = 0
local entities = {}                 -- { x, y (grid pixel of the tile's middle), kind, flag }

local function isRom(p) return p >= 0x08000000 and p < 0x0A000000 end

local function spriteOf(gfx)
  if gfx >= GRAPHICS_INFO_COUNT then return nil end
  local info = mem.u32(GRAPHICS_INFO_TABLE + gfx * 4)
  if not isRom(info) then return nil end
  local tag, w, h = mem.u16(info + 2), mem.u16(info + 8), mem.u16(info + 10)
  local images = mem.u32(info + 0x1C)
  if not (SIZES[w] and SIZES[h] and isRom(images)) then return nil end
  local tiles, size = mem.u32(images), mem.u32(images + 4)
  if not isRom(tiles) or size ~= w * h // 2 then return nil end
  for i = 0, SPRITE_PALETTE_COUNT - 1 do
    local entry = SPRITE_PALETTES + i * 8
    if mem.u16(entry + 4) == tag then
      local palette = mem.u32(entry)
      if isRom(palette) then return { tiles = tiles, palette = palette, w = w, h = h } end
      return nil
    end
  end
  return nil
end

local function load(events)
  entities, eventsAt = {}, events
  if not isRom(events) then return end
  local objects = mem.u8(events)
  local objectTable = mem.u32(events + 4)
  if objects <= 64 and isRom(objectTable) then
    for i = 0, objects - 1 do
      local t = objectTable + i * 0x18
      local kind = M.NPC
      if mem.u8(t + 1) == GFX_ITEM_BALL then kind = M.ITEM elseif mem.u16(t + 0xC) ~= 0 then kind = M.TRAINER end
      local sprite = spriteOf(mem.u8(t + 1))
      if sprite then
        entities[#entities + 1] = {
          x = (mem.s16(t + 4) + MAP_OFFSET) * 16 + 8, y = (mem.s16(t + 6) + MAP_OFFSET) * 16 + 8,
          kind = kind, flag = mem.u16(t + 0x14), sprite = sprite,
        }
      end
    end
  end
end

local function flagSet(flags, id)
  if flags == 0 or id == 0 or id >= FLAG_COUNT then return false end
  return (mem.u8(flags + (id >> 3)) >> (id & 7)) & 1 == 1
end

-- The entities of the map [events] points at whose grid pixel lies in x0..x1, y0..y1 and whose flag is
-- not set, at most [limit] of them, each the wide() marker fields of its sprite (tiles, palette, w, h) with
-- x, y at its top-left: standing on the tile, its bottom edge on the tile's bottom.
function M.within(events, x0, x1, y0, y1, limit)
  if events ~= eventsAt then load(events) end
  local sb1 = mem.u32(SAVEBLOCK1_PTR)
  local flags = (sb1 >= 0x02000000 and sb1 < 0x02040000) and sb1 + FLAGS_OFFSET or 0
  local out = {}
  for _, e in ipairs(entities) do
    if e.x >= x0 and e.x <= x1 and e.y >= y0 and e.y <= y1 and not flagSet(flags, e.flag) then
      local sp = e.sprite
      out[#out + 1] = { x = e.x - sp.w // 2, y = e.y + 8 - sp.h, kind = e.kind, tiles = sp.tiles, palette = sp.palette, w = sp.w, h = sp.h }
      if #out >= limit then break end
    end
  end
  return out
end

return M
