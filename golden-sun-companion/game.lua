-- Golden Sun (AGSE, USA/Europe): the wide view. The game keeps the whole decoded map of the current
-- area in RAM and streams it into three 32x32 BG maps as the camera moves, so GBADuo can paint the
-- margins beside the 240x160 frame from the same data. Reads only; the app checks every frame that
-- this matches what the game drew and hides the margins when not. Contract: docs-packs/game-script.md
-- in the app repo.
--
-- Found by tracing the game's own column writer (ROM 0x0800FF54): a 128x128 grid of u32 cells at
-- GRID (cell & 0xFFF = metatile id, 16x16 px), and a table at METATILES with 4 u16 tile entries per
-- id (TL, TR, BL, BR). The three BG layers (BG3 ground, BG2 objects, BG1 roofs and tree tops) sit side
-- by side in that grid, one block of columns each; a layer's BG scroll is its block's start in pixels
-- plus the camera, so the blocks' starts are the differences of the scroll values. The game keeps
-- the scroll it will show next in SHADOW (BGnHOFS, BGnVOFS as u16, per BG from BG0) and copies it to
-- the hardware every frame, so the hardware registers lag it by a frame while the camera moves.
-- Verified on the US ROM only (the other languages are probably the same but untested).

local GRID = 0x02010000         -- 128 x 128 u32 cells
local METATILES = 0x02020000    -- 4 u16 per metatile id
local SHADOW = 0x03001AD0       -- the BG scroll the game will show next, 4 bytes per BG
local REG_DISPCNT = 0x04000000
local REG_BGCNT = 0x04000008    -- BGnCNT, 2 bytes per BG
local REG_BGHOFS = 0x04000010   -- BGnHOFS, BGnVOFS, 4 bytes per BG
local N = 128
local DEBUG = false
local logged = 0

-- The scroll is the camera in pixels modulo the 256 px BG; the hardware offset minus the value the
-- game wrote, wrapped to -128..127, is how far the drawn frame is behind it.
local function lag(hw, game)
  return ((hw - game + 128) % 256) - 128
end

function wide(view)
  local dispcnt = mem.u16(REG_DISPCNT)
  -- tile mode, and the three map layers (BG1..BG3) all on
  if dispcnt & 7 ~= 0 or dispcnt & 0x0E00 ~= 0x0E00 then return nil end

  local bg = {}
  for n = 1, 3 do
    local control = mem.u16(REG_BGCNT + n * 2)
    -- 4 bits a pixel, 32x32 tiles: what the game's map writer produces
    if control & 0x80 ~= 0 or (control >> 14) ~= 0 then return nil end
    bg[n] = {
      n = n,
      priority = control & 3,
      tiles = 0x06000000 + ((control >> 2) & 3) * 0x4000,
      hx = mem.u16(SHADOW + n * 4), hy = mem.u16(SHADOW + n * 4 + 2),
    }
  end

  -- block starts: BG3 first, then BG2, then BG1, each as far to the right as its scroll says
  local base = bg[3]
  local width = bg[2].hx - base.hx          -- pixels in one block
  if width < 16 or width % 16 ~= 0 or width > 16 * N // 3 then return nil end
  local cols = width // 16
  if bg[1].hx - bg[2].hx ~= width then return nil end
  if bg[1].hy ~= base.hy or bg[2].hy ~= base.hy then return nil end

  local layers = {}
  for n = 3, 1, -1 do
    local start = (3 - n) * cols
    layers[#layers + 1] = {
      grid = GRID + start * 4, stride = N, cellBytes = 4,
      gridW = cols, gridH = N,
      idMask = 0xFFF, metatiles = METATILES, tiles = bg[n].tiles,
      priority = bg[n].priority, n = n,
    }
  end
  -- bottom first: a larger priority number is drawn below; on a tie the higher BG number is below
  table.sort(layers, function(a, b)
    if a.priority ~= b.priority then return a.priority > b.priority end
    return a.n > b.n
  end)

  local x = base.hx + lag(mem.u16(REG_BGHOFS + 3 * 4), base.hx)
  local y = base.hy + lag(mem.u16(REG_BGHOFS + 3 * 4 + 2), base.hy)
  if DEBUG and view.match < 0.9 and logged < 600 then
    logged = logged + 1
    log(string.format("LOW match=%.3f x=%d y=%d cols=%d", view.match, x, y, cols))
  end
  return { x = x, y = y, palette = 0x05000000, layers = layers }
end
