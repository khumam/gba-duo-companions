-- FireRed (BPRE, 1.0 addresses): the wide view. Describes the overworld around the player so
-- GBADuo can paint the margins beside the game's own 240x160 frame. Reads only; the app checks
-- every frame that this description matches what the game drew, and hides the margins when not.
-- Contract: docs-packs/game-script.md in the app repo.

local MAP_HEADER = 0x02036DFC       -- gMapHeader (its first word points at the ROM MapLayout)
local PLAYER_OBJ = 0x02036E38       -- gObjectEvents[0]
local COORDS = 0x10                 -- currentCoords: tile x, y (map coordinates + MAP_OFFSET)
local BACKUP_LAYOUT = 0x03005040    -- gBackupMapLayout { s32 width; s32 height; u16 *map }
local REG_BG1HOFS = 0x04000014      -- the overworld's BGs all scroll together
local REG_BG1VOFS = 0x04000016

local MAP_OFFSET = 7                -- the border around a map in the game's grid
local MAPGRID_UNDEFINED = 0x3FF     -- a grid cell outside the map: the border block shows instead
local NUM_METATILES_IN_PRIMARY = 640

-- Where the player stands on the 240x160 screen: tile column 7, tile row 4.5 (the 16x32 sprite).
local PLAYER_SCREEN_X = 112
local PLAYER_SCREEN_Y = 72

-- The BG scroll registers only say where the screen sits inside the game's 256 px tilemap ring,
-- not where in the world. So the origin is anchored while the player stands still (the camera sits
-- exactly on their tile) and then followed frame by frame from the scroll deltas.
--
-- Crossing from one map into the next keeps that going: the game then rebases the tile
-- coordinates (the current and the previous tile, by the same whole number of tiles) while the
-- scroll carries on smoothly. The camera is always between the player's previous and current
-- tile, so the whole-tile rebase is recovered from where they now are.
local STILL_FRAMES = 6
local PREV_COORDS = 0x14            -- previousCoords, right after currentCoords
local DEBUG = false
local anchored, worldX, worldY = false, 0, 0
local lastLayout, lastPx, lastPy, lastH, lastV, still = 0, -1, -1, 0, 0, 0
local logged = 0

local function delta(now, before)
  return ((now - before + 128) % 256) - 128
end

local function tiles(px, qx)         -- the camera's most likely world position within the player's step
  return (px + qx) * 8
end

local function round(x)
  return math.floor(x + 0.5)
end

local function track(layout)
  local px = mem.u16(PLAYER_OBJ + COORDS)
  local py = mem.u16(PLAYER_OBJ + COORDS + 2)
  local qx = mem.u16(PLAYER_OBJ + PREV_COORDS)
  local qy = mem.u16(PLAYER_OBJ + PREV_COORDS + 2)
  local h = mem.u16(REG_BG1HOFS) % 256
  local v = mem.u16(REG_BG1VOFS) % 256
  if anchored then
    worldX = worldX + delta(h, lastH)
    worldY = worldY + delta(v, lastV)
    if layout ~= lastLayout then
      local midX = tiles(px, qx) - PLAYER_SCREEN_X
      local midY = tiles(py, qy) - PLAYER_SCREEN_Y
      worldX = worldX + 16 * round((midX - worldX) / 16)
      worldY = worldY + 16 * round((midY - worldY) / 16)
    end
  end
  if DEBUG and layout ~= lastLayout then
    log(string.format("MAPCHANGE layout=%08X tile=%d,%d prev=%d,%d scroll=%d,%d world=%d,%d", layout, px, py, qx, qy, h, v, worldX, worldY))
  end
  lastLayout = layout
  if px == lastPx and py == lastPy and h == lastH and v == lastV then
    still = still + 1
    if still >= STILL_FRAMES then
      anchored = true
      worldX = px * 16 - PLAYER_SCREEN_X
      worldY = py * 16 - PLAYER_SCREEN_Y
    end
  else
    still = 0
  end
  lastPx, lastPy, lastH, lastV = px, py, h, v
  return px, py, h, v
end

function wide(view)
  local layout = mem.u32(MAP_HEADER)
  if layout < 0x08000000 or layout >= 0x0A000000 then return nil end
  local gridW = mem.u32(BACKUP_LAYOUT)
  local gridH = mem.u32(BACKUP_LAYOUT + 4)
  local grid = mem.u32(BACKUP_LAYOUT + 8)
  if gridW < 1 or gridW > 1024 or gridH < 1 or gridH > 1024 or grid < 0x02000000 or grid >= 0x02040000 then return nil end
  local primary = mem.u32(layout + 0x10)
  local secondary = mem.u32(layout + 0x14)
  if primary < 0x08000000 or secondary < 0x08000000 then return nil end

  local px, py, h, v = track(layout)
  if not anchored then return nil end
  if DEBUG and view.match < 0.9 and logged < 600 then
    logged = logged + 1
    log(string.format("LOW match=%.3f x=%d y=%d tile=%d,%d scroll=%d,%d", view.match, worldX, worldY, px, py, h, v))
  end
  return {
    x = worldX, y = worldY,
    grid = grid, gridW = gridW, gridH = gridH, idMask = 0x3FF,
    border = mem.u32(layout + 8), borderW = mem.u8(layout + 0x18), borderH = mem.u8(layout + 0x19),
    borderShift = MAP_OFFSET, undefinedId = MAPGRID_UNDEFINED,
    metatiles = mem.u32(primary + 0x0C), metatiles2 = mem.u32(secondary + 0x0C),
    split = NUM_METATILES_IN_PRIMARY,
    tiles = 0x06000000, palette = 0x05000000,
  }
end
