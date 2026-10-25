-- The game's own Town Map, drawn at runtime from the player's ROM (gfx.tilemap), so
-- the pack ships none of Nintendo's art for it, and where the player is on it.
--
-- From the pret/pokefirered decompilation (src/region_map.c); the addresses were found
-- in a LeafGreen (USA) v1.0 ROM by unpacking each LZ77 block and comparing it with
-- FireRed's verified Town Map and the decompilation's files:
-- * Tiles: sRegionMap_Gfx (region_map.4bpp.lz), palette sRegionMap_Pal (5 banks).
-- * Maps: sKanto_Tilemap and the three Sevii Islands maps (*.bin.lz), each one GBA
--   screen of 30 x 20 tiles (240 x 160 px). The Town Map draws them as BG0.
-- * A map section's cell (x, y) on the 22 x 15 grid sits at screen px (8x + 32, 8y + 32)
--   (region_map.c draws the player icon centred at 8x + 36).
--
-- The picture is tiles 3-23 x 3-19 of that screen: every place on all four maps, with a
-- tile of sea around it, leaving out the "switch map" button in the corner (cells 20-22 x
-- 12-14; no place reaches them).

local M = {}

local RELEASES = {
  -- LeafGreen (USA) v1.0 (BPGE, version 0); matched against its ROM and FireRed's
  -- decompressed tiles, palette and map layouts.
  ["BPGE0"] = {
    tiles = 0x083EF458, palette = 0x083EF118,
    maps = { [0] = 0x083F06D8, 0x083F0938, 0x083F0A48, 0x083F0B2C },
  },
}

M.REGIONS = { [0] = "KANTO", "SEVII 1-2-3", "SEVII 4-5", "SEVII 6-7" }

-- The picture: screen tiles X0.. x Y0.., W x H px.
local X0, Y0, W, H = 3, 3, 168, 136

local release
local function current()
  if release ~= nil then return release or nil end
  local code = {}
  for i = 0, 3 do code[#code + 1] = string.char(mem.u8(0x080000AC + i)) end
  release = RELEASES[table.concat(code) .. mem.u8(0x080000BC)] or false
  return release or nil
end

-- gfx.tilemap is called on every request, not once: the app keeps a limited number of
-- images and redraws a dropped one only when it's asked for again (cheap: it caches by
-- the arguments).
local args = {}
--- The Town Map of [region] (0 Kanto, 1-3 Sevii) as an image key; nil on an unknown release.
function M.image(region)
  local r = current()
  if not r or not r.maps[region] then return nil end
  if not args[region] then
    args[region] = {
      tiles = r.tiles, palette = r.palette, map = r.maps[region], lz77 = true,
      stride = 30, x = X0, y = Y0, width = W, height = H, opaque = true,
    }
  end
  local ok, key = pcall(gfx.tilemap, args[region])
  if ok then return key end
  log("town map: " .. tostring(key))
  return nil
end

--- Where a point of [cell] is, as % of the picture: [fx], [fy] (0-1) across the cell.
function M.place(cell, fx, fy)
  local function pct(px, size) return math.floor(px * 1000 / size + 0.5) / 10 end
  local x = 8 * (cell.x + cell.w * fx) + 32 - X0 * 8
  local y = 8 * (cell.y + cell.h * fy) + 32 - Y0 * 8
  return pct(x, W), pct(y, H)
end

return M
