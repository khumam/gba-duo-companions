local dir = arg[1]
local function slurp(p) local f = assert(io.open(p, "rb")); local s = f:read("a"); f:close(); return s end
local rom, dump = slurp(dir .. "/romx/Final Fantasy Tactics Advance (USA) (Virtual Console).gba"), slurp(dir .. "/a.bin")
local ewram = dump:sub(32769)
local function byte(a)
  if a >= 0x08000000 and a < 0x0A000000 then return rom:byte(a - 0x08000000 + 1) or 0 end
  if a >= 0x02000000 and a < 0x02040000 then return ewram:byte(a - 0x02000000 + 1) or 0 end
  return 0
end
mem = {
  u8 = byte, u16 = function(a) return byte(a) | (byte(a + 1) << 8) end,
  u32 = function(a) return byte(a) | (byte(a + 1) << 8) | (byte(a + 2) << 16) | (byte(a + 3) << 24) end,
  read = function(a, n) local t = {} for i = 0, n - 1 do t[#t + 1] = string.char(byte(a + i)) end return table.concat(t) end,
}

math.randomseed(tonumber(arg[3]) or 7)
local realu8 = mem.u8
local lo, hi = tonumber(arg[4]), tonumber(arg[5])
local noise = {}
mem.u8 = function(a)
  if a >= lo and a < hi then
    local v = noise[a]
    if v == nil then v = (math.random() < 0.35) and math.random(0, 255) or realu8(a); noise[a] = v end
    return v
  end
  return realu8(a)
end
mem.u16 = function(a) return mem.u8(a) | (mem.u8(a + 1) << 8) end
mem.u32 = function(a) return mem.u8(a) | (mem.u8(a + 1) << 8) | (mem.u8(a + 2) << 16) | (mem.u8(a + 3) << 24) end
dofile(arg[2])
local errs = {}
for i = 1, 60 do
  noise = {}
  local ok, r = pcall(update, { page = ({ "clan", "unit", "top", "compare", "jobs", "stats" })[i % 6 + 1], unit = tostring(math.random(0, 25)), race = tostring(math.random(0, 6)),
    stat = ({ "atk", "def", "pow", "res", "maxHp", "maxMp" })[math.random(1, 6)], cmpA = tostring(math.random(0, 25)), cmpB = tostring(math.random(0, 25)), job = tostring(math.random(2, 50)) })
  if not ok then errs[tostring(r)] = (errs[tostring(r)] or 0) + 1 end
end
local n = 0
for e, c in pairs(errs) do print("ERR x" .. c, e); n = n + 1 end
print("distinct errors", n)
