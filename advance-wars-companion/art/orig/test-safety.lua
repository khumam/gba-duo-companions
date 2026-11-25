local dir = arg[1]
local function slurp(p) local f = assert(io.open(p, "rb")); local s = f:read("a"); f:close(); return s end
local rom = slurp(dir .. "/romx/Advance Wars (USA) (Virtual Console).gba")
local dump = slurp(dir .. "/" .. arg[3])
local iw, ew = dump:sub(1, 32768), dump:sub(32769)
local function byte(a)
  if a >= 0x08000000 and a < 0x0A000000 then return rom:byte(a - 0x08000000 + 1) or 0 end
  if a >= 0x02000000 and a < 0x02040000 then return ew:byte(a - 0x02000000 + 1) or 0 end
  if a >= 0x03000000 and a < 0x03008000 then return iw:byte(a - 0x03000000 + 1) or 0 end
  return 0
end
mem = {
  u8 = byte, u16 = function(a) return byte(a) | (byte(a + 1) << 8) end,
  u32 = function(a) return byte(a) | (byte(a + 1) << 8) | (byte(a + 2) << 16) | (byte(a + 3) << 24) end,
  read = function(a, n) local t = {} for i = 0, n - 1 do t[#t + 1] = string.char(byte(a + i)) end return table.concat(t) end,
}
gfx = { layers = function(a) assert(a.layers[1].gridW == 19 and a.layers[1].gridH == 14, "dims"); return "gfx:test" end }
local realu16 = mem.u16
mem.u16 = function(a) if a == 0x0400000E then return 0x1F0B end return realu16(a) end
dofile(arg[2])

local good = update({ page = "map" })
print("first ok", good and good.ready, "day", good and good.day)
local realu32 = mem.u32
mem.u32 = function(a) error("simulated crash") end
local again = update({ page = "units", navpos = "left" })
print("after crash: still ready", again and again.ready, "day", again and again.day, "nav flags", again and again.dockL, again and again.posLeft)
