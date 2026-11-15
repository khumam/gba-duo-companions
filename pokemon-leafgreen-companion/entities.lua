-- The NPCs, trainers, items and doors of the current map, for the Wide / XL margins (used by game.lua). Two sources:
--  * LIVE: the game's own object events (gObjectEvents) and their sprites (gSprites). The game only keeps the
--    objects near the camera alive (the screen plus a margin of a couple of tiles), but those really move: their
--    position, pixel by pixel, and the way they face come straight from RAM.
--  * the map's event table in the ROM (gMapHeader.events): where every object of the map starts. It is the only
--    place that knows about the rest, which the game is not simulating; an object whose flag is set (an item
--    taken, an NPC gone) is left out, and so is one that is live.
local M = {}

local MAP_OFFSET = 7                -- the border around a map in the game's grid
local SAVEBLOCK1_PTR = 0x03005008   -- gSaveBlock1Ptr
local FLAGS_OFFSET = 0xEE0          -- SaveBlock1.flags
local FLAG_COUNT = 0x900            -- flag ids below this live in that array (the rest are temporary)
local GFX_ITEM_BALL = 95            -- OBJ_EVENT_GFX_ITEM_BALL
local OBJECT_EVENTS, OBJECT_COUNT, OBJECT_SIZE = 0x02036E38, 16, 0x24   -- gObjectEvents
local GSPRITES, SPRITE_SIZE = 0x0202063C, 0x44                          -- gSprites (struct Sprite, 0x44 bytes)
local BIT_INVISIBLE, BIT_IS_PLAYER = 1 << 13, 1 << 16                    -- ObjectEvent flag bits

M.NPC, M.TRAINER, M.ITEM = 1, 2, 3

-- The sprite of an object, from the ROM: gObjectEventGraphicsInfoPointers (151 entries, FireRed 1.0) points at
-- an ObjectEventGraphicsInfo { tileTag, paletteTag1, paletteTag2, size, width, height, ..., images @0x1C }, whose
-- first SpriteFrameImage is the object facing the player; the palette is found by its tag in
-- sObjectEventSpritePalettes. Anything that does not look right (another ROM, an unused graphics id) has no
-- sprite and is left out: only real sprites are drawn.
-- LeafGreen 1.0 keeps both tables 0x20 bytes before FireRed's (checked: a live sprite's image table is the one this
-- table's entry names)
local GRAPHICS_INFO_TABLE, GRAPHICS_INFO_COUNT = 0x0839FD90, 151
local SPRITE_PALETTES, SPRITE_PALETTE_COUNT = 0x083A5138, 18
local SIZES = { [8] = true, [16] = true, [32] = true, [48] = true, [64] = true }

local eventsAt = 0
local entities = {}                 -- { x, y (grid pixel of the tile's middle), kind, flag }

local function isRom(p) return p >= 0x08000000 and p < 0x0A000000 end

local function spriteOf(gfx, frame)
  if gfx >= GRAPHICS_INFO_COUNT then return nil end
  local info = mem.u32(GRAPHICS_INFO_TABLE + gfx * 4)
  if not isRom(info) then return nil end
  local tag, w, h = mem.u16(info + 2), mem.u16(info + 8), mem.u16(info + 10)
  local images = mem.u32(info + 0x1C)
  if not (SIZES[w] and SIZES[h] and isRom(images)) then return nil end
  frame = frame or 0
  local tiles, size = mem.u32(images + frame * 8), mem.u32(images + frame * 8 + 4)
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

local liveSprites = {}              -- [gfx * 8 + frame] -> sprite or false: ROM data never changes
local function liveSprite(gfx, frame)
  local key = gfx * 8 + frame
  local sp = liveSprites[key]
  if sp == nil then
    sp = spriteOf(gfx, frame) or false
    liveSprites[key] = sp
  end
  return sp or nil
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
          kind = kind, flag = mem.u16(t + 0x14), sprite = sprite, localId = mem.u8(t),
        }
      end
    end
  end
end

local function flagSet(flags, id)
  if flags == 0 or id == 0 or id >= FLAG_COUNT then return false end
  return (mem.u8(flags + (id >> 3)) >> (id & 7)) & 1 == 1
end

local function s8(v) return v >= 128 and v - 256 or v end

-- The live objects: { x, y (the sprite's top-left, world pixels), kind, tiles, palette, w, h, hflip }, and the set
-- of local ids that are live in this map (so the ROM list can skip them). The sprite's own position is its screen
-- position plus the camera offset; the player's sprite is always on screen, so its OAM entry says what the offset
-- is. [worldX, worldY] is the world pixel of the game frame's top-left corner.
local function live(worldX, worldY, location)
  local out, ids = {}, {}
  local playerId
  for i = 0, OBJECT_COUNT - 1 do
    local o = OBJECT_EVENTS + i * OBJECT_SIZE
    local bits = mem.u32(o)
    if bits & 1 == 1 and bits & BIT_IS_PLAYER ~= 0 then playerId = i break end
  end
  if not playerId then return {}, {} end
  local playerObj = OBJECT_EVENTS + playerId * OBJECT_SIZE
  local ps = GSPRITES + mem.u8(playerObj + 4) * SPRITE_SIZE
  local offX = (mem.u16(ps + 2) & 0x1FF) - (mem.s16(ps + 0x20) + mem.s16(ps + 0x24) + s8(mem.u8(ps + 0x28)))
  local offY = (mem.u16(ps) & 0xFF) - (mem.s16(ps + 0x22) + mem.s16(ps + 0x26) + s8(mem.u8(ps + 0x29)))
  if offX > 256 then offX = offX - 512 end            -- the OAM x is 9 bits
  local group, num = mem.u8(location), mem.u8(location + 1)
  for i = 0, OBJECT_COUNT - 1 do
    local o = OBJECT_EVENTS + i * OBJECT_SIZE
    local bits = mem.u32(o)
    if bits & 1 == 1 and i ~= playerId and bits & BIT_IS_PLAYER == 0 then
      if mem.u8(o + 9) == num and mem.u8(o + 10) == group then ids[mem.u8(o + 8)] = true end
      if bits & BIT_INVISIBLE == 0 then
        local gfx = mem.u8(o + 5)
        local facing = mem.u8(o + 0x18) & 0xF            -- 1 south, 2 north, 3 west, 4 east
        local frame = facing == 2 and 1 or (facing >= 3 and 2 or 0)
        local sp = liveSprite(gfx, frame)
        if sp then
          local sprite = GSPRITES + mem.u8(o + 4) * SPRITE_SIZE
          local kind = M.NPC
          if gfx == GFX_ITEM_BALL then kind = M.ITEM elseif mem.u8(o + 7) ~= 0 then kind = M.TRAINER end
          out[#out + 1] = {
            x = worldX + mem.s16(sprite + 0x20) + mem.s16(sprite + 0x24) + s8(mem.u8(sprite + 0x28)) + offX,
            y = worldY + mem.s16(sprite + 0x22) + mem.s16(sprite + 0x26) + s8(mem.u8(sprite + 0x29)) + offY,
            kind = kind, tiles = sp.tiles, palette = sp.palette, w = sp.w, h = sp.h, hflip = facing == 4 and 1 or 0,
          }
        end
      end
    end
  end
  return out, ids
end

-- The markers for the margins: the live objects first, then the map's objects from the ROM table whose grid pixel
-- lies in x0..x1, y0..y1, whose flag is not set and that are not live, at most [limit] of them in all. Each is the
-- wide() marker fields of its sprite (tiles, palette, w, h) with x, y at its top-left: standing on the tile, its
-- bottom edge on the tile's bottom.
function M.within(events, x0, x1, y0, y1, limit, worldX, worldY)
  if events ~= eventsAt then load(events) end
  local flags = SAVEBLOCK1 + FLAGS_OFFSET
  local out, ids = live(worldX, worldY)
  while #out > limit do out[#out] = nil end
  for _, e in ipairs(entities) do
    if #out >= limit then break end
    if e.x >= x0 and e.x <= x1 and e.y >= y0 and e.y <= y1 and not ids[e.localId] and not flagSet(flags, e.flag) then
      local sp = e.sprite
      out[#out + 1] = { x = e.x - sp.w // 2, y = e.y + 8 - sp.h, kind = e.kind, tiles = sp.tiles, palette = sp.palette, w = sp.w, h = sp.h }
    end
  end
  return out
end

-- The markers for the margins: the live objects first, then the map's objects from the ROM table whose grid pixel
-- lies in x0..x1, y0..y1, whose flag is not set and that are not live, at most [limit] of them in all. Each is the
-- wide() marker fields of its sprite (tiles, palette, w, h) with x, y at its top-left: standing on the tile, its
-- bottom edge on the tile's bottom.
function M.within(events, x0, x1, y0, y1, limit, worldX, worldY)
  if events ~= eventsAt then load(events) end
  local sb1 = mem.u32(SAVEBLOCK1_PTR)
  local ok = sb1 >= 0x02000000 and sb1 < 0x02040000
  local flags = ok and sb1 + FLAGS_OFFSET or 0
  local out, ids = live(worldX, worldY, ok and sb1 + 4 or 0)
  while #out > limit do out[#out] = nil end
  for _, e in ipairs(entities) do
    if #out >= limit then break end
    if e.x >= x0 and e.x <= x1 and e.y >= y0 and e.y <= y1 and not ids[e.localId] and not flagSet(flags, e.flag) then
      local sp = e.sprite
      out[#out + 1] = { x = e.x - sp.w // 2, y = e.y + 8 - sp.h, kind = e.kind, tiles = sp.tiles, palette = sp.palette, w = sp.w, h = sp.h }
    end
  end
  return out
end

return M
