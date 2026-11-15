-- The NPCs, trainers, items and doors of the current map, for the Wide / XL margins (used by game.lua). Two sources:
--  * LIVE: the game's own object events (gObjectEvents, same address as FireRed) and their sprites (gSprites
--    0x0202063C). The game only keeps the objects near the camera alive (the screen plus a margin of a couple of
--    tiles), but those really move: position and facing come straight from RAM. Unbound repointed its graphics
--    tables (CFRU), so the sprite is not looked up by graphics id: the live sprite itself names its frame table
--    (struct Sprite.images), its size is its OAM shape and size, and its colours are its live OBJ palette.
--  Objects beyond that (the game is not simulating them, and Unbound's graphics tables cannot be looked up by id, so
--  their sprites are unknown) get no marker at all: nothing is better than a placeholder diamond.
local M = {}

local SAVEBLOCK1_PTR = 0x03005008   -- gSaveBlock1Ptr
local OBJECT_EVENTS, OBJECT_COUNT, OBJECT_SIZE = 0x02036E38, 16, 0x24   -- gObjectEvents
local GSPRITES, SPRITE_SIZE = 0x0202063C, 0x44                          -- gSprites (struct Sprite, 0x44 bytes)
local OBJ_PALETTES = 0x05000200     -- the 16 sprite palettes of palette RAM, 32 bytes each
local BIT_INVISIBLE, BIT_IS_PLAYER = 1 << 13, 1 << 16                    -- ObjectEvent flag bits

M.NPC, M.TRAINER, M.ITEM = 1, 2, 3

-- OAM shape (0 square, 1 wide, 2 tall) and size -> pixels
local OAM_W = { [0] = { [0] = 8, 16, 32, 64 }, { [0] = 16, 32, 32, 64 }, { [0] = 8, 8, 16, 32 } }
local OAM_H = { [0] = { [0] = 8, 16, 32, 64 }, { [0] = 8, 8, 16, 32 }, { [0] = 16, 32, 32, 64 } }

local function isRom(p) return p >= 0x08000000 and p < 0x0A000000 end
local function s8(v) return v >= 128 and v - 256 or v end

-- The live objects: { x, y (the sprite's top-left, world pixels), kind, tiles, palette, w, h, hflip }, and the set of
-- local ids live in this map (so the ROM list can skip them). The sprite's position is its screen position plus the
-- camera offset; the player's sprite is always on screen, so its OAM entry says what the offset is. [worldX, worldY]
-- is the world pixel of the game frame's top-left corner.
local function live(worldX, worldY, location)
  local out, ids = {}, {}
  local playerId
  for i = 0, OBJECT_COUNT - 1 do
    local bits = mem.u32(OBJECT_EVENTS + i * OBJECT_SIZE)
    if bits & 1 == 1 and bits & BIT_IS_PLAYER ~= 0 then playerId = i break end
  end
  if not playerId then return out, ids end
  local ps = GSPRITES + mem.u8(OBJECT_EVENTS + playerId * OBJECT_SIZE + 4) * SPRITE_SIZE
  local offX = (mem.u16(ps + 2) & 0x1FF) - (mem.s16(ps + 0x20) + mem.s16(ps + 0x24) + s8(mem.u8(ps + 0x28)))
  local offY = (mem.u16(ps) & 0xFF) - (mem.s16(ps + 0x22) + mem.s16(ps + 0x26) + s8(mem.u8(ps + 0x29)))
  offX = (offX + 256) % 512 - 256                    -- the OAM x is 9 bits
  local group, num = mem.u8(location), mem.u8(location + 1)
  for i = 0, OBJECT_COUNT - 1 do
    local o = OBJECT_EVENTS + i * OBJECT_SIZE
    local bits = mem.u32(o)
    if bits & 1 == 1 and i ~= playerId and bits & BIT_IS_PLAYER == 0 then
      if mem.u8(o + 9) == num and mem.u8(o + 10) == group then ids[mem.u8(o + 8)] = true end
      if bits & BIT_INVISIBLE == 0 then
        local sprite = GSPRITES + mem.u8(o + 4) * SPRITE_SIZE
        local attr0, attr1, attr2 = mem.u16(sprite), mem.u16(sprite + 2), mem.u16(sprite + 4)
        local shape, size = attr0 >> 14, attr1 >> 14
        local w, h = OAM_W[shape] and OAM_W[shape][size], OAM_H[shape] and OAM_H[shape][size]
        local images = mem.u32(sprite + 0x0C)             -- SpriteFrameImage[]: { data*, size } per frame
        local facing = mem.u8(o + 0x18) & 0xF             -- 1 south, 2 north, 3 west, 4 east
        local frame = facing == 2 and 1 or (facing >= 3 and 2 or 0)
        local tiles = isRom(images) and mem.u32(images + frame * 8) or 0
        if w and h and isRom(tiles) and mem.u32(images + frame * 8 + 4) == w * h // 2 then
          out[#out + 1] = {
            x = worldX + mem.s16(sprite + 0x20) + mem.s16(sprite + 0x24) + s8(mem.u8(sprite + 0x28)) + offX,
            y = worldY + mem.s16(sprite + 0x22) + mem.s16(sprite + 0x26) + s8(mem.u8(sprite + 0x29)) + offY,
            kind = mem.u8(o + 7) ~= 0 and M.TRAINER or M.NPC, tiles = tiles, palette = OBJ_PALETTES + (attr2 >> 12) * 32,
            w = w, h = h, hflip = facing == 4 and 1 or 0,
          }
        end
      end
    end
  end
  return out, ids
end

-- The markers for the margins: the live objects, with their real sprites, at most [limit]. (The first argument and the
-- bounds are kept for game.lua's call; objects the game has not loaded get no marker.)
function M.within(_, _, _, _, _, limit, worldX, worldY)
  local sb1 = mem.u32(SAVEBLOCK1_PTR)
  local out = live(worldX, worldY, (sb1 >= 0x02000000 and sb1 < 0x02040000) and sb1 + 4 or 0)
  while #out > limit do out[#out] = nil end
  return out
end

return M
