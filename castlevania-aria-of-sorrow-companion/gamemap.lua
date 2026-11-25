-- gamemap.lua : the game's own castle map, redrawn from the explored bits.
-- The map shape (cells, walls, doors, save and warp rooms) is `mapdata.lua`, read off the game's map screen with every cell lit;
-- the explored bits decide what shows. One HodMap glyph per map cell (assets/fonts/HodMap.ttf, from the community Harmony of Dissonance
-- pack): "a" fills a cell, "." is an empty cell, the letters A..P are the wall pieces (left * 4 + top, 0 none, 2 door, 3 wall), "m" a mark.
-- Layers are lists of text rows stacked in one box; each row stops at its last glyph so a rebuild stays cheap.
local M = {}

local LET, DOT, BLANK = {}, {}, {}
for k = 0, 15 do LET[k] = string.char(65 + k) end
for n = 0, 70 do DOT[n] = string.rep(".", n); BLANK[n] = string.rep("A", n) end

local function lit(lo, hi, x) if x < 32 then return (lo >> x) & 1 == 1 end return (hi >> (x - 32)) & 1 == 1 end

--- data: the mapdata table; words(y) -> lo, hi (cells 0-31, 32-63 of row y, low bit left). Returns the layer lists.
function M.build(data, words)
  local W, H = data.w, data.h
  local lo, hi = {}, {}
  for y = 0, H - 1 do lo[y], hi[y] = words(y) end
  lo[-1], hi[-1], lo[H], hi[H] = 0, 0, 0, 0
  local fill, save, warp, walls, doors = {}, {}, {}, {}, {}
  for y = 0, H do
    local gS, dS, rS, kS, rU = data.g[y + 1], data.d[y + 1], data.r[y + 1], data.k[y + 1], data.r[y]
    local fp, sp, wp, bp, dp = {}, {}, {}, {}, {}
    local fpos, spos, wpos, bpos, dpos = 0, 0, 0, 0, 0
    for x = 0, W do
      local room = rS:byte(x + 1) == 49
      local e = room and y < H and lit(lo[y], hi[y], x)
      local lv = x > 0 and rS:byte(x) == 49 and lit(lo[y] or 0, hi[y] or 0, x - 1) and y < H
      local uv = y > 0 and rU and rU:byte(x + 1) == 49 and lit(lo[y - 1], hi[y - 1], x)
      local showL, showT = e or lv, e or uv
      local gv, dv = gS:byte(x + 1) - 65, dS:byte(x + 1) - 65
      local g = ((showL and gv >> 2 or 0) << 2) | (showT and gv & 3 or 0)
      local d = ((showL and dv >> 2 or 0) << 2) | (showT and dv & 3 or 0)
      if g ~= 0 then bp[#bp + 1] = BLANK[x - bpos]; bp[#bp + 1] = LET[g]; bpos = x + 1 end
      if d ~= 0 then dp[#dp + 1] = BLANK[x - dpos]; dp[#dp + 1] = LET[d]; dpos = x + 1 end
      if e then
        fp[#fp + 1] = DOT[x - fpos]; fp[#fp + 1] = "a"; fpos = x + 1
        local k = kS:byte(x + 1)
        if k == 83 then sp[#sp + 1] = DOT[x - spos]; sp[#sp + 1] = "a"; spos = x + 1
        elseif k == 87 then wp[#wp + 1] = DOT[x - wpos]; wp[#wp + 1] = "a"; wpos = x + 1 end
      end
    end
    local function row(p, blank) return { t = #p > 0 and table.concat(p) or blank } end
    fill[#fill + 1], save[#save + 1], warp[#warp + 1] = row(fp, "."), row(sp, "."), row(wp, ".")
    walls[#walls + 1], doors[#doors + 1] = row(bp, "A"), row(dp, "A")
  end
  return { fill = fill, save = save, warp = warp, walls = walls, doors = doors }
end

--- a cheap signature of the explored rows, to skip rebuilding when nothing changed
function M.signature(data, words)
  local s = 0
  for y = 0, data.h - 1 do
    local a, b = words(y)
    s = (s * 31 + a) % 2147483647
    s = (s * 31 + b) % 2147483647
  end
  return s
end

return M
