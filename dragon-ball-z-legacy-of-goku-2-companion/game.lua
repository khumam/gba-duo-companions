-- Dragon Ball Z: The Legacy of Goku II (ALFE, US): the wide view. Describes the map layers the game
-- keeps so GBADuo can paint the margins beside the 240x160 frame. Reads only; the app checks every frame
-- that this matches what the game drew and hides the margins when not. Contract:
-- docs-packs/game-script.md in the app repo (chunked 8bpp tilemap layers). Addresses and the packing
-- format are in NOTES.md.
--
-- The game (Webfoot's engine) draws each map layer as a 256x256 px torus of 32x32 tile entries
-- (BG1..BG3, 8bpp, screenblocks 29..31) but keeps the whole map in ROM as 256x256 px chunks, packed.
-- A layer object in EWRAM holds a 2x2 window of unpacked chunks; its descriptor in ROM holds the map's
-- size in chunks and a table of chunk pointers. GBADuo unpacks the chunks itself (chunkCodec = 1).

local ROM_CODE = 0x080000AC            -- "ALFE"
local LAYER_PTRS = 0x0300107C          -- u32 pointer to the layer object of BG0..BG3
local CAMERA_X = 0x03001094            -- s32, 22.10 fixed point: the screen's top-left in the game's world
local CAMERA_Y = 0x03001098
local LAYER_VTABLE = 0x08023868        -- first word of a map layer object
local L_DESC = 0x08                    -- u32: the layer's descriptor in ROM
local D_OFFX = 0x0C                    -- s32, 22.10: where the layer sits against the camera (BG1 64, BG2 128, BG3 192 px)
local D_OFFY = 0x10
local D_CHUNKS_W = 0x14                -- u8: map size in chunks
local D_CHUNKS_H = 0x15
local D_TABLE = 0x18                   -- u32 pointer per chunk (row-major), 0 = empty

local REG_DISPCNT = 0x04000000
local REG_BGCNT = 0x04000008           -- BG0CNT; BGnCNT follow every 2 bytes
local REG_BGOFS = 0x04000010           -- BG0HOFS, BG0VOFS; BGn follow every 4 bytes

local OAM = 0x07000000
local OBJ_TILES = 0x06010000           -- 1D mapping (DISPCNT bit 6), tile number * 32 bytes
local OBJ_PALETTE = 0x05000200
local MAX_MARKERS = 64
-- OAM sprite sizes by [shape][size]
local SPRITE_SIZES = {
  [0] = { { 8, 8 }, { 16, 16 }, { 32, 32 }, { 64, 64 } },
  [1] = { { 16, 8 }, { 32, 8 }, { 32, 16 }, { 64, 32 } },
  [2] = { { 8, 16 }, { 8, 32 }, { 16, 32 }, { 32, 64 } },
}

local function s32(v)
  if v >= 0x80000000 then return v - 0x100000000 end
  return v
end

-- The offset in 0..255 (wrapped to -128..127) of a scroll register from where the camera says the layer is:
-- the hardware registers trail the game's own variables by a frame while the camera moves, and they are what
-- the frame on screen was drawn with.
local function wrapped(reg, nominal)
  local d = (reg - nominal) & 255
  if d >= 128 then d = d - 256 end
  return nominal + d
end

local ready = false

function init()
  ready = mem.u32(ROM_CODE) == 0x45464C41
end

-- BG1..BG3 as the game has them now, bottom first: the lowest priority number is on top, and of equal ones the
-- lower BG number.
local function layers()
  local dispcnt = mem.u16(REG_DISPCNT)
  if dispcnt & 7 ~= 0 then return nil end        -- tile mode 0 only
  local found = {}
  for bg = 1, 3 do
    if dispcnt & (0x100 << bg) ~= 0 then
      local cnt = mem.u16(REG_BGCNT + bg * 2)
      local obj = mem.u32(LAYER_PTRS + bg * 4)
      if cnt & 0x80 == 0 or obj < 0x02000000 or obj >= 0x02040000 or mem.u32(obj) ~= LAYER_VTABLE then
        return nil                               -- a 4bpp background or no map layer: not the overworld
      end
      local desc = mem.u32(obj + L_DESC)
      if desc < 0x08000000 or desc >= 0x0A000000 then return nil end
      local w, h = mem.u8(desc + D_CHUNKS_W), mem.u8(desc + D_CHUNKS_H)
      if w < 1 or w > 64 or h < 1 or h > 64 then return nil end
      found[#found + 1] = {
        bg = bg, prio = cnt & 3, desc = desc, w = w, h = h,
        offX = s32(mem.u32(desc + D_OFFX)) >> 10,
        offY = s32(mem.u32(desc + D_OFFY)) >> 10,
        tiles = 0x06000000 + ((cnt >> 2) & 3) * 0x4000,
      }
    end
  end
  if #found == 0 then return nil end
  table.sort(found, function(a, b)
    if a.prio ~= b.prio then return a.prio > b.prio end
    return a.bg > b.bg
  end)
  return found
end

-- The game's own sprites that stick out of the 240x160 frame (the hardware cuts them there), whole, as
-- sprite markers: they carry on into the margins. Sprites inside the frame are the frame's. The game keeps
-- an off-screen sprite's tiles in OBJ VRAM only while the sprite is in OAM, so nothing farther out is known.
local function sprites(view, x, y)
  if mem.u16(REG_DISPCNT) & 0x1040 ~= 0x1040 then return nil end   -- sprites on, 1D mapping
  local right = view.width - view.left - 240
  local bottom = view.height - view.top - 160
  local out = {}
  for i = 127, 0, -1 do
    local a0 = mem.u16(OAM + i * 8)
    if a0 & 0x300 == 0 and (a0 >> 10) & 3 == 0 then          -- not affine, hidden, blended or a window
      local a1 = mem.u16(OAM + i * 8 + 2)
      local size = SPRITE_SIZES[a0 >> 14]
      if size then
        local dims = size[(a1 >> 14) + 1]
        local w, h = dims[1], dims[2]
        local sx = a1 & 511
        if sx >= 256 then sx = sx - 512 end
        local sy = a0 & 255
        if sy >= 192 then sy = sy - 256 end                    -- above the screen; 160..191 is below it
        local inside = sx >= 0 and sy >= 0 and sx + w <= 240 and sy + h <= 160
        local seen = sx + w > -view.left and sx < 240 + right and sy + h > -view.top and sy < 160 + bottom
        if seen and not inside and #out < MAX_MARKERS then
          local a2 = mem.u16(OAM + i * 8 + 4)
          local eight = a0 & 0x2000 ~= 0
          out[#out + 1] = {
            x = x + sx, y = y + sy, kind = 1, w = w, h = h,
            tiles = OBJ_TILES + (a2 & 0x3FF) * 32,
            palette = eight and OBJ_PALETTE or OBJ_PALETTE + (a2 >> 12) * 32,
            bpp = eight and 8 or 4,
            hflip = (a1 >> 12) & 1, vflip = (a1 >> 13) & 1,
          }
        end
      end
    end
  end
  return out
end

function wide(view)
  if not ready then return nil end
  local found = layers()
  if not found then return nil end
  local camX = s32(mem.u32(CAMERA_X)) >> 10
  local camY = s32(mem.u32(CAMERA_Y)) >> 10
  -- Where each layer is on screen, from its own scroll registers; the bottom layer names the world's origin.
  for _, l in ipairs(found) do
    l.posX = wrapped(mem.u16(REG_BGOFS + l.bg * 4), camX + l.offX)
    l.posY = wrapped(mem.u16(REG_BGOFS + l.bg * 4 + 2), camY + l.offY)
  end
  local x, y = found[1].posX - found[1].offX, found[1].posY - found[1].offY
  local out = {}
  for i, l in ipairs(found) do
    out[i] = {
      chunks = l.desc + D_TABLE, chunkW = l.w, chunkH = l.h, chunkCodec = 1,
      tiles = l.tiles, dx = l.posX - x, dy = l.posY - y,
    }
  end
  -- The map is where the ground layer has tiles (its chunk grid is padding, edge chunks half empty): the camera
  -- stops there, so must the wide picture, and a room smaller than the picture stays centred, black around it.
  out[1].trimBounds = 1
  return { x = x, y = y, palette = 0x05000000, layers = out, markers = sprites(view, x, y) }
end
