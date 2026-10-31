-- The Minish Cap (BZM*, same RAM addresses in the US, EU and JP builds): the wide view. Describes
-- the two map layers the game keeps in RAM so GBADuo can paint the margins beside the 240x160 frame.
-- Reads only; the app checks every frame that this matches what the game drew and hides the margins
-- when not. Contract: docs-packs/game-script.md in the app repo.
--
-- Source: zeldaret/tmc (include/map.h, include/room.h, linker.ld). A room is up to 64x64 tiles of
-- 16x16 px in two layers (MapLayer): mapData (u16 tile index, row stride 64) and subTiles (4 u16
-- tile entries per tile index: TL, TR, BL, BR). Special cells (>= 0x4000) go through tileIndices.

local ROOM = 0x03000BF0           -- gRoomControls
local R_ORIGIN_X = 0x06           -- u16: where the room starts in the game's world
local R_ORIGIN_Y = 0x08
local R_SCROLL_X = 0x0A           -- s16: camera, in the same world
local R_SCROLL_Y = 0x0C
local R_WIDTH = 0x1E              -- u16: room size in pixels
local R_HEIGHT = 0x20

local MAP_TOP = 0x0200B650        -- gMapTop
local MAP_BOTTOM = 0x02025EB0     -- gMapBottom
local L_BG = 0x00                 -- BgSettings*: its first u16 is the BG control register
local L_DATA = 0x0004             -- mapData[64 * 64]
local L_INDICES = 0x6004          -- tileIndices[2048]
local L_SUBTILES = 0x7004         -- subTiles[2048 * 4]

local GSCREEN_BG0 = 0x03000F58    -- gScreen.bg0; BgSettings { control, xOffset, yOffset, ... } is 12 bytes
local REG_BG0HOFS = 0x04000010    -- BGnHOFS, BGnVOFS follow every 4 bytes

local STRIDE = 64
local DEBUG = false
local logged = 0

local function s16(v)
  if v >= 0x8000 then return v - 0x10000 end
  return v
end

local function layer(base)
  local bg = mem.u32(base + L_BG)
  if bg < 0x03000000 or bg >= 0x03008000 then return nil end
  local control = mem.u16(bg)
  return {
    grid = base + L_DATA, stride = STRIDE,
    idMask = 0x7FF, special = base + L_INDICES,
    metatiles = base + L_SUBTILES,
    tiles = 0x06000000 + ((control >> 2) & 3) * 0x4000,
  }
end

-- The game updates RAM (room scroll, gScreen.bgN) a frame before the hardware registers hold it, so
-- while the camera moves the picture trails the room scroll by a pixel or two. The BG offset is the
-- scroll modulo 16 (the map is redrawn a tile at a time), so the bottom layer's hardware offset minus
-- the value the game wrote, wrapped to -8..7, tells how far behind the drawn frame is.
local function lag(base)
  local bg = mem.u32(base + L_BG)
  local i = (bg - GSCREEN_BG0) // 12
  if i < 0 or i > 3 then return 0, 0 end
  local function d(hw, game) return ((hw - game + 8) % 16) - 8 end
  return d(mem.u16(REG_BG0HOFS + i * 4), mem.u16(bg + 2)), d(mem.u16(REG_BG0HOFS + i * 4 + 2), mem.u16(bg + 4))
end

function wide(view)
  local width = mem.u16(ROOM + R_WIDTH)
  local height = mem.u16(ROOM + R_HEIGHT)
  if width < 16 or height < 16 or width > 1024 or height > 1024 then return nil end
  local bottom = layer(MAP_BOTTOM)
  local top = layer(MAP_TOP)
  if not bottom or not top then return nil end
  bottom.gridW, bottom.gridH = width // 16, height // 16
  top.gridW, top.gridH = bottom.gridW, bottom.gridH

  local lx, ly = lag(MAP_BOTTOM)
  local x = s16(mem.u16(ROOM + R_SCROLL_X)) - mem.u16(ROOM + R_ORIGIN_X) + lx
  local y = s16(mem.u16(ROOM + R_SCROLL_Y)) - mem.u16(ROOM + R_ORIGIN_Y) + ly
  if DEBUG and view.match < 0.9 and logged < 600 then
    logged = logged + 1
    log(string.format("LOW match=%.3f x=%d y=%d lag=%d,%d room=%dx%d", view.match, x, y, lx, ly, width, height))
  end
  return { x = x, y = y, palette = 0x05000000, layers = { bottom, top } }
end
