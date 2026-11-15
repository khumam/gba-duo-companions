log = function(m) print("   LOG", m) end
local dir = arg[1]
local function slurp(p) local f = assert(io.open(p, "rb")); local s = f:read("a"); f:close(); return s end
local rom = slurp(dir .. "/romx/Advance Wars (USA) (Virtual Console).gba")
local iw, ew
local function load(p) local d = slurp(dir .. "/" .. p); iw, ew = d:sub(1, 32768), d:sub(32769) end
local function byte(a)
  if a >= 0x08000000 and a < 0x0A000000 then return rom:byte(a - 0x08000000 + 1) or 0 end
  if a >= 0x02000000 and a < 0x02040000 then return ew:byte(a - 0x02000000 + 1) or 0 end
  if a >= 0x03000000 and a < 0x03008000 then return iw:byte(a - 0x03000000 + 1) or 0 end
  return 0
end
mem = { u8 = byte, u16 = function(a) if a == 0x0400000E then return 0x1F0B end return byte(a) | (byte(a + 1) << 8) end,
  u32 = function(a) return byte(a) | (byte(a + 1) << 8) | (byte(a + 2) << 16) | (byte(a + 3) << 24) end,
  read = function(a, n) local t = {} for i = 0, n - 1 do t[#t + 1] = string.char(byte(a + i)) end return table.concat(t) end }
local draws = 0
gfx = { layers = function(a) draws = draws + 1; return "gfx:img" .. draws end }
dofile(arg[2])
local function step(label, path, times)
  load(path)
  local r
  for _ = 1, times do r = update({ page = "map" }) end
  print(string.format("%-28s ready=%s hasMap=%s img=%s units=%d props=%d draws=%d", label, tostring(r and r.ready), tostring(r and r.hasMap), tostring(r and r.mapImg), r and #r.mapUnits or -1, r and #r.mapProps or -1, draws))
end
step("map shown (d0)", "mv/d0.bin", 3)
step("unit selected (d1)", "mv/d1.bin", 3)
step("cursor moved (d2)", "mv/d2.bin", 3)
step("placed / menu (d3)", "mv/d3.bin", 3)
step("after (d4)", "mv/d4.bin", 3)
step("settled (d5)", "mv/d5.bin", 3)
step("back to map (d0)", "mv/d0.bin", 3)
