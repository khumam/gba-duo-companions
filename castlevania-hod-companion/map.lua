-- map.lua : the MAP page — the game's castle map, redrawn from the ROM's map data and the save's explored bits.
-- Explored bits 0x0200008C: two blocks of 2560 bits (map columns 0–31, then 32–63); in each 64-bit row,
-- bits 0–31 = castle A, 32–63 = castle B. bit(c, x, y) = (x >= 32 ? 2560 : 0) + 64·y + 32·c + x mod 32.
-- Completion = explored bits / 674 (the game's A, B and A+B percentages, truncated to 0.1 %). Legit saves set
-- bits only on room tiles (0 elsewhere in 13 saves); the map draws room tiles only.
-- Map tiles 0x080DAD94 (u16, y·64+x): bit 15 save, 14 warp, 13 castle-B warp, 8–11 region.
-- Boundaries 0x080DC194 (4 bits per tile: even tile = high nibble, odd = low): bits 0–1 left, 2–3 top
-- (3 wall, 2 door, 1 secret = drawn as a wall). Drawn with assets/fonts/HodMap.ttf, one glyph per cell.
local H = pack.require("hod")
local A = H.A
local M = {}

local EXPLORED, ROOMS = 0x0200008C, 674
local META, LINES = 0x080DAD94, 0x080DC194
local X0, X1, Y0, Y1 = 1, 60, 5, 36            -- drawn window (rooms span x 1–59, y 5–35; +1 to close walls)

-- Static, read once: for each map row, only the cells that can draw something (a room tile, or the tile right of /
-- below one, which holds that room's right / bottom boundary), and the save and warp tiles.
local rows, marks
local function load()
  if rows then return end
  local roomAt = {}
  marks = {}
  for y = Y0, Y1 do
    for x = X0, X1 do
      local i = y * 64 + x
      if x <= 59 and y <= 35 then
        local t = mem.u16(META + 2 * i)
        if t ~= 0xFFFF then
          roomAt[i] = true
          if t & 0x8000 ~= 0 then marks[#marks + 1] = { x = x, y = y, save = true }
          elseif t & 0x6000 ~= 0 then marks[#marks + 1] = { x = x, y = y, save = false } end
        end
      end
    end
  end
  rows = {}
  for y = Y0, Y1 do
    local r = { xs = {}, room = {}, l = {}, t = {}, roomL = {}, roomU = {} }
    for x = X0, X1 do
      local i = y * 64 + x
      local isRoom, rl, ru = roomAt[i] or false, roomAt[i - 1] or false, roomAt[i - 64] or false
      if isRoom or rl or ru then
        local b = mem.u8(LINES + (i >> 1))
        local v = (i & 1 == 0) and (b >> 4) or (b & 15)
        local l, t = v & 3, (v >> 2) & 3
        if l == 1 then l = 3 end
        if t == 1 then t = 3 end
        local k = #r.xs + 1
        r.xs[k], r.room[k], r.l[k], r.t[k], r.roomL[k], r.roomU[k] = x, isRoom, l, t, rl, ru
      end
    end
    rows[y] = r
  end
end

local POP = {}
for v = 0, 255 do local n, t = 0, v; while t ~= 0 do n = n + (t & 1); t = t >> 1 end; POP[v] = n end
function M.count(c)
  local n = 0
  for blk = 0, 1 do
    for y = 0, 39 do
      local a = EXPLORED + blk * 320 + y * 8 + c * 4
      n = n + POP[mem.u8(a)] + POP[mem.u8(a + 1)] + POP[mem.u8(a + 2)] + POP[mem.u8(a + 3)]
    end
  end
  return n
end

local function pct(n) return string.format("%d.%d%%", n * 1000 // ROOMS // 10, n * 1000 // ROOMS % 10) end

local function signature(c)
  local s = c
  for blk = 0, 1 do
    for y = Y0, Y1 do s = (s * 31 + mem.u32(EXPLORED + blk * 320 + y * 8 + c * 4)) % 2147483647 end
  end
  return s
end

-- One 64-bit row of explored cells for castle c (bit x = column x).
local function rowBits(c, y)
  if y < 0 or y > 39 then return 0 end
  return mem.u32(EXPLORED + y * 8 + c * 4) | (mem.u32(EXPLORED + 320 + y * 8 + c * 4) << 32)
end

local LET, DOT, BLANK = {}, {}, {}             -- glyphs: boundary k, k blank cells "." / "A"
for k = 0, 15 do LET[k] = string.char(65 + k) end
for n = 0, 64 do DOT[n] = string.rep(".", n); BLANK[n] = string.rep("A", n) end

-- Rows are built from pieces (run of blanks + one glyph) and stop at their last glyph: ~10x cheaper than
-- one glyph per cell, so a rebuild stays far inside the app's 25 ms per update.
local function build(c)
  load()
  local fill, walls = {}, {}
  local prev = rowBits(c, Y0 - 1)
  local bits = {}
  for y = Y0, Y1 do
    local cur = y <= 35 and rowBits(c, y) or 0
    bits[y] = cur
    local r = rows[y]
    local xs, room, L, T, RL, RU = r.xs, r.room, r.l, r.t, r.roomL, r.roomU
    local fp, bp, fpos, bpos = {}, {}, X0, X0
    for k = 1, #xs do
      local x = xs[k]
      local e = room[k] and (cur >> x) & 1 == 1                 -- explored room (hacked saves set every bit)
      local g = ((e or (RL[k] and (cur >> (x - 1)) & 1 == 1)) and L[k] or 0) * 4
                + ((e or (RU[k] and (prev >> x) & 1 == 1)) and T[k] or 0)
      if g ~= 0 then bp[#bp + 1] = BLANK[x - bpos]; bp[#bp + 1] = LET[g]; bpos = x + 1 end
      if e then fp[#fp + 1] = DOT[x - fpos]; fp[#fp + 1] = "a"; fpos = x + 1 end
    end
    prev = cur
    fill[#fill + 1] = { t = #fp > 0 and table.concat(fp) or "." }
    walls[#walls + 1] = { t = #bp > 0 and table.concat(bp) or "A" }
  end
  local sp, wp = {}, {}                          -- save / warp rows: explored marks only
  for _, mk in ipairs(marks) do
    if (bits[mk.y] >> mk.x) & 1 == 1 then
      local t = mk.save and sp or wp
      local row = t[mk.y] or {}
      row[#row + 1] = mk.x
      t[mk.y] = row
    end
  end
  local function layer(t)
    local list = {}
    for y = Y0, Y1 do
      local xs = t[y]
      if xs then
        table.sort(xs)
        local p, pos = {}, X0
        for _, x in ipairs(xs) do p[#p + 1] = DOT[x - pos]; p[#p + 1] = "a"; pos = x + 1 end
        list[#list + 1] = { t = table.concat(p) }
      else
        list[#list + 1] = { t = "." }
      end
    end
    return list
  end
  return { fill = fill, save = layer(sp), warp = layer(wp), walls = walls }
end

local sig, built = {}, {}                        -- per castle, so A <-> B doesn't rebuild

local blink = 0
function M.page(out, ui)
  local pos = mem.u8(A.roomPos)
  local here = { c = pos & 1, x = pos >> 1, y = mem.u8(A.roomPos + 1) }
  local c = (ui.mc == "B" and 1) or (ui.mc == "A" and 0) or here.c
  local s = signature(c)
  if s ~= sig[c] or not built[c] then built[c], sig[c] = build(c), s end
  local b = built[c]
  out.mapFill, out.mapSave, out.mapWarp, out.mapWalls = b.fill, b.save, b.warp, b.walls
  out.mapB, out.mapA = c == 1, c == 0

  -- current room marker (blinks with the update tick, like the game's)
  blink = blink + 1
  local mark = {}
  local showMark = here.c == c and blink % 2 == 1 and here.x >= X0 and here.x <= 59 and here.y >= Y0 and here.y <= 35
  for y = Y0, Y1 do
    mark[#mark + 1] = { t = (showMark and y == here.y) and (string.rep(".", here.x - X0) .. "m") or "." }
  end
  out.mapMark = mark
  out.youHere = here.c == c

  local na, nb = M.count(0), M.count(1)
  out.pctA, out.pctB, out.pctAll = pct(na), pct(nb), pct(na + nb)
  out.roomsA, out.roomsB = na .. " rooms", nb .. " rooms"
  out.mapCastle = c == 1 and "CASTLE B" or "CASTLE A"
  local place = H.place()
  out.hereText = place and (place.area .. ", castle " .. (place.castleB and "B" or "A")) or "-"
end

load()                                           -- the ROM map data is read once, at pack load (load budget: 5M / 250 ms)
return M
