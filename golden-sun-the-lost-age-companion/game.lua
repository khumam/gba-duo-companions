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

-- Markers for the wide margins: the NPCs and other actors of the area. The game keeps its actors in an array of
-- 0x70-byte structs from ACTORS (slot 0 is the party leader): handler pointer @0x00, sprite block pointer @0x50,
-- x @0x08, height @0x0C and y @0x10, each 16.16 with the world pixel in the high half (the same space as the BG
-- scroll; the picture's y is y - height). Found by comparing save states, checked against the leader's and
-- followers' OAM entries.
--
-- An actor's sprite block (IWRAM, 0x118 bytes, first block: flags @+4, OAM attribute 2 @+8) holds the tile its
-- picture uses while the game has it loaded. The game reuses its OBJ tile slots (two actors can share a tile
-- number) and the sprite art in the ROM is compressed, so a picture is only real while that actor is on screen:
-- the game's own OAM then has an entry with that tile at the spot the actor predicts, giving the real size,
-- palette, flip and where the picture sits around the actor. That is what an actor walking across the edge of
-- the frame gets in the margin; an actor entirely outside the frame draws nothing (no placeholder).
local ACTORS = 0x02030EBC
local ACTOR_SIZE = 0x70
local ACTOR_COUNT = 40
local A_HANDLER, A_X, A_Z, A_Y, A_SPRITE = 0x00, 0x08, 0x0C, 0x10, 0x50
local HANDLER_LEADER, HANDLER_FOLLOWER = 0x080135C0, 0x080135F0
local PLACEHOLDER_TILE = 260
local OBJ_TILES, OBJ_PALETTE, OAM = 0x06010000, 0x05000200, 0x07000000
local MATCH_PX = 12     -- how far the OAM entry may be from where the actor predicts it (the frame lags a little)
local MAX_MARKERS = 64

-- OAM shape (0 square, 1 wide, 2 tall) and size to pixels
local PIECE_W = { { 8, 16, 32, 64 }, { 16, 32, 32, 64 }, { 8, 8, 16, 32 } }
local PIECE_H = { { 8, 16, 32, 64 }, { 8, 8, 16, 32 }, { 16, 32, 32, 64 } }

-- The tile the game has set for the actor's sprite block at [p], or nil for a placeholder.
local function blockTile(p)
  if p < 0x03000000 or p >= 0x03007F00 then return nil end
  local flags, attr = mem.u32(p + 4), mem.u16(p + 8)
  if flags & 0x80000000 == 0 or flags == 0x80002000 then return nil end
  local tile = attr & 0x3FF
  if tile == PLACEHOLDER_TILE or tile < 0x100 then return nil end
  return tile
end

-- The game's OAM entries that touch the 240x160 screen: { tile, bank, x, y, w, h, hflip } in screen pixels:
-- regular sprites and the (not double-size) rotation/scale ones the game draws its actors with, whose flip
-- bits are a matrix number.
local function oamEntries()
  local list = {}
  for i = 0, 127 do
    local a0, a1, a2 = mem.u16(OAM + i * 8), mem.u16(OAM + i * 8 + 2), mem.u16(OAM + i * 8 + 4)
    local shape = a0 >> 14
    local mode = (a0 >> 8) & 3
    if (mode == 0 or mode == 1) and shape < 3 then
      local y, x = a0 & 255, a1 & 511
      if y >= 160 then y = y - 256 end
      if x >= 256 then x = x - 512 end
      local w, h = PIECE_W[shape + 1][(a1 >> 14) + 1], PIECE_H[shape + 1][(a1 >> 14) + 1]
      if x < 240 and x + w > 0 and y < 160 and y + h > 0 then
        list[#list + 1] = {
          tile = a2 & 0x3FF, bank = (a2 >> 12) & 0xF, x = x, y = y, w = w, h = h,
          hflip = mode == 0 and (a1 >> 12) & 1 or 0,
        }
      end
    end
  end
  return list
end

local function markers(view, worldX, worldY, mapW, mapH)
  local oam = oamEntries()
  local out = {}
  for i = 1, ACTOR_COUNT - 1 do
    local a = ACTORS + i * ACTOR_SIZE
    local handler = mem.u32(a + A_HANDLER)
    if handler >= 0x08000000 and handler < 0x0A000000 and handler ~= HANDLER_LEADER and handler ~= HANDLER_FOLLOWER then
      local x = mem.u32(a + A_X) >> 16
      local y = (mem.u32(a + A_Y) - mem.u32(a + A_Z)) // 65536
      if (x ~= 0 or y ~= 0) and x < mapW and y >= 0 and y < mapH
          and x >= worldX - view.width and x <= worldX + view.width
          and y >= worldY - view.height and y <= worldY + view.height then
        local marker = nil
        local tile = blockTile(mem.u32(a + A_SPRITE))
        if tile then
          for _, o in ipairs(oam) do
            if o.tile == tile and math.abs(o.x - (x - worldX - o.w // 2)) <= MATCH_PX
                and math.abs(o.y - (y - worldY - o.h + 2)) <= MATCH_PX + o.h // 2 then
              marker = {
                x = worldX + o.x, y = worldY + o.y, kind = 1, hflip = o.hflip,
                tiles = OBJ_TILES + tile * 32, palette = OBJ_PALETTE + o.bank * 32, w = o.w, h = o.h,
              }
              break
            end
          end
        end
        if marker then
          out[#out + 1] = marker
          if #out >= MAX_MARKERS then break end
        end
      end
    end
  end
  return out
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
  local ok, list = pcall(markers, view, x, y, cols * 16, N * 16)
  return { x = x, y = y, palette = 0x05000000, layers = layers, markers = ok and list or nil }
end

-- The look of the game while Ambient is on (ambient.lua).
ambient = pack.require("ambient").ambient
