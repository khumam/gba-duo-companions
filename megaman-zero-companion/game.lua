-- Mega Man Zero (AZCE, US): the wide view. A stage is one grid of 16x16 px metatiles that the game keeps
-- in EWRAM and streams into BG1 as the camera moves; the metatile table is in the ROM. Found by tracing
-- the routine at ROM 0x0800507C (it copies grid rows into a VRAM shadow) with the headless harness
-- (art/mz-harness.c). No decompilation exists, so every address below was measured, see NOTES.md.
-- Reads only; the app checks that this matches what the game drew and hides the margins when not.
-- Contract: docs-packs/game-script.md in the app repo.
--
--   0x0200543C  u16 width in metatiles (480 on the first stage), then the grid at +4, u16 cells, row
--               stride = width. A stage is up to ~20 rows tall; rows past its end hold other data.
--   0x02005004  descriptor of BG1's layer: +0x0C ROM pointer to the metatile table (4 u16 tile
--               entries TL TR BL BR per id), +0x28 camera x (u32 px), +0x2C camera y.
--   0x0400000A  BG1CNT: the tile data's character base.

local MAP = 0x0200543C
local DESC = 0x02005004
local D_METATILES = 0x0C
local D_CAM_X = 0x28
local D_CAM_Y = 0x2C
local REG_BG1CNT = 0x0400000A
local REG_BG1HOFS = 0x04000014

-- Zero's entity (the same check main.lua uses): its vtable is only there while a stage is running.
local ENTITY = 0x0202B600
local VT_LO, VT_HI = 0x08598000, 0x0859A000   -- Zero's per-state vtables (idle, walk, jump, ...)

local DEBUG = false
local logged = 0

local function s32(v)
  if v >= 0x80000000 then return v - 0x100000000 end
  return v
end

-- The game moves its camera a frame before the hardware offset shows it; BG1HOFS is the camera x
-- modulo 512, so the difference (wrapped to -256..255) is how far the drawn frame is behind.
local function lag(camX)
  return ((camX - mem.u16(REG_BG1HOFS) + 256) % 512) - 256
end

-- Rows of the grid that belong to this stage: the bottom rows of the buffer hold other data, so count
-- up from the top while a row still has tiles in it (24 sample columns a row, cached by stage).
local heightFor, heightKey

local function gridHeight(width)
  local key = width * 65536 + mem.u16(MAP + 4 + 2 * (width * 3 + 31)) + mem.u16(MAP + 4 + 2 * (width * 12 + 200))
  if key == heightKey then return heightFor end
  local last = 0
  for row = 0, 31 do
    local used = 0
    for i = 0, 23 do
      if mem.u16(MAP + 4 + 2 * (row * width + i * (width // 24))) ~= 0 then used = used + 1 end
    end
    if used >= 4 then last = row + 1 end
  end
  heightKey, heightFor = key, math.max(last, 10)
  return heightFor
end

function wide(view)
  local vt = mem.u32(ENTITY + 0x0C)
  if vt < VT_LO or vt >= VT_HI then return nil end
  local width = mem.u16(MAP)
  if width < 16 or width > 1024 then return nil end
  local metatiles = mem.u32(DESC + D_METATILES)
  if metatiles < 0x08000000 or metatiles >= 0x0A000000 then return nil end

  local camX, camY = s32(mem.u32(DESC + D_CAM_X)), s32(mem.u32(DESC + D_CAM_Y))
  local x = camX - lag(camX)
  if DEBUG and view.match < 0.9 and logged < 400 then
    logged = logged + 1
    log("wide miss match=" .. string.format("%.2f", view.match) .. " cam=" .. camX .. "," .. camY .. " hofs=" .. mem.u16(REG_BG1HOFS))
  end
  return {
    x = x, y = camY,
    palette = 0x05000000,
    layers = {
      {
        grid = MAP + 4, stride = width, gridW = width, gridH = gridHeight(width),
        idMask = 0xFFF,
        metatiles = metatiles,
        tiles = 0x06000000 + ((mem.u16(REG_BG1CNT) >> 2) & 3) * 0x4000,
      },
    },
  }
end
