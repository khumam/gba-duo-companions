-- Runs main.lua against the real ROM + a RAM dump and compares with what the game's own Status screen showed.
-- usage: lua test-device.lua DIR   (DIR holds romx/<rom>.gba, base.bin and truth.lua)
log = function() end
local dir = arg[1]
local function slurp(p) local f = assert(io.open(p, "rb")); local s = f:read("a"); f:close(); return s end
local rom, dump = slurp(dir .. "/romx/Final Fantasy VI Advance (USA).gba"), slurp(dir .. "/base.bin")
local ewram = dump:sub(32769)
local function byte(a)
  if a >= 0x08000000 and a < 0x0A000000 then return rom:byte(a - 0x08000000 + 1) or 0 end
  if a >= 0x02000000 and a < 0x02040000 then return ewram:byte(a - 0x02000000 + 1) or 0 end
  return 0
end
mem = { u8 = byte, u16 = function(a) return byte(a) | (byte(a + 1) << 8) end,
  u32 = function(a) return byte(a) | (byte(a + 1) << 8) | (byte(a + 2) << 16) | (byte(a + 3) << 24) end,
  read = function(a, n) local t = {} for i = 0, n - 1 do t[#t + 1] = string.char(byte(a + i)) end return table.concat(t) end,
  write8 = function() end }
pack = { require = function(n) return dofile(arg[2] .. "/" .. n .. ".lua") end }
dofile(arg[2] .. "/main.lua")
local r = update({})
local by = {}
for _, m in ipairs(r.party) do by[m.actor] = m end
-- the game's own Status screens (RAM buffer 0x020011A0 while the screen was open), one per party member
local truth = dofile(dir .. "/truth.lua")
local ok, total = 0, 0
for actor, t in pairs(truth) do
  local m = by[actor]
  local got = { mag = m.magic, sta = m.stamina, spd = m.speed, str = m.vigor, eva = m.evasion, mev = m.mevasion, atk = (m.attackText == "?") and 14 or m.attack, df = m.defense, mdef = m.mdefense }
  local same = true
  for k, v in pairs(t) do if got[k] ~= v then same = false; print("MISMATCH", m.name, k, got[k], "wanted", v) end end
  total = total + 1; if same then ok = ok + 1 end
end
print(ok .. " of " .. total .. " characters match the game's Status screen")
local c = by[6]
print("Celes EXP to next:", c.expNext, "(game: 52254)", "max HP/MP:", c.maxHp, c.maxMp, "(game: 9398 / 999)")
for _, m in ipairs(r.party) do print(m.name, "HP", m.hp .. "/" .. m.maxHp, "MP", m.mp .. "/" .. m.maxMp) end
