-- Runs main.lua against the real ROM + a RAM dump and prints the active quests (the game's Quests tab showed: Collect the seven
-- Dragon Balls, Find the seven Missing Nameks ..., Train with Master Roshi, Retrieve the Bait ...).  usage: lua test-quests.lua DIR PACKDIR
log = function() end
local dir, packdir = arg[1], arg[2]
local function slurp(p) local f = assert(io.open(p, "rb")); local s = f:read("a"); f:close(); return s end
local rom, dump = slurp(dir .. "/romx/Dragon Ball Z - The Legacy of Goku II (USA).gba"), slurp(dir .. "/q.bin")
local iwram, ewram = dump:sub(1, 32768), dump:sub(32769, 32768 + 0x40000)
local function byte(a)
  if a >= 0x08000000 and a < 0x0A000000 then return rom:byte(a - 0x08000000 + 1) or 0 end
  if a >= 0x03000000 and a < 0x03008000 then return iwram:byte(a - 0x03000000 + 1) or 0 end
  if a >= 0x02000000 and a < 0x02040000 then return ewram:byte(a - 0x02000000 + 1) or 0 end
  return 0
end
mem = { u8 = byte, u16 = function(a) return byte(a) | (byte(a + 1) << 8) end,
  u32 = function(a) return byte(a) | (byte(a + 1) << 8) | (byte(a + 2) << 16) | (byte(a + 3) << 24) end,
  read = function(a, n) local t = {} for i = 0, n - 1 do t[#t + 1] = string.char(byte(a + i)) end return table.concat(t) end, write8 = function() end }
pack = { require = function(n) return dofile(packdir .. "/" .. n .. ".lua") end }
dofile(packdir .. "/main.lua")
local r = update({})
for _, q in ipairs(r.active) do print(q.kind, q.text) end
print(#r.active .. " active quests")
local names = {}
for _, m in ipairs(r.party or {}) do names[#names + 1] = m.name end
print("party:", table.concat(names, ", "))
for _, m in ipairs(r.party or {}) do
  local tn = {}
  for _, x in ipairs(m.techs) do tn[#tn + 1] = (x.locked and "[locked] " or "") .. x.name end
  print(m.name, table.concat(tn, " | "))
end
