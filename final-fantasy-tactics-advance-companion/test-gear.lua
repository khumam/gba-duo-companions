log = function() end
local dir = arg[1]
local function slurp(p) local f = assert(io.open(p, "rb")); local s = f:read("a"); f:close(); return s end
local rom, dump = slurp(dir .. "/romx/Final Fantasy Tactics Advance (USA) (Virtual Console).gba"), slurp(dir .. "/a.bin")
local ewram = dump:sub(32769)
local function byte(a)
  if a >= 0x08000000 and a < 0x0A000000 then return rom:byte(a - 0x08000000 + 1) or 0 end
  if a >= 0x02000000 and a < 0x02040000 then return ewram:byte(a - 0x02000000 + 1) or 0 end
  return 0
end
mem = { u8 = byte, u16 = function(a) return byte(a) | (byte(a + 1) << 8) end,
  u32 = function(a) return byte(a) | (byte(a + 1) << 8) | (byte(a + 2) << 16) | (byte(a + 3) << 24) end,
  read = function(a, n) local t = {} for i = 0, n - 1 do t[#t + 1] = string.char(byte(a + i)) end return table.concat(t) end }
dofile(arg[2])
local r = update({})
local byIdx = {}
for _, u in ipairs(r.units) do byIdx[u.idx] = u end
-- what the game's own status screens showed for these units (read from RAM while each screen was open)
local screens = { [0] = {589,587,374,459,155}, [9] = {502,460,339,340,160}, [18] = {445,489,392,444,174}, [7] = {338,382,461,508,134},
  [16] = {342,401,453,521,144}, [5] = {420,393,403,411,163}, [14] = {535,505,310,369,139}, [3] = {474,492,394,364,156},
  [12] = {411,450,396,472,141}, [11] = {440,390,361,382,183} }
local ok = 0
for idx, want in pairs(screens) do
  local u = byIdx[idx]
  local got = { u.atk, u.def, u.pow, u.res, u.speed }
  local same = true
  for k = 1, 5 do if got[k] ~= want[k] then same = false end end
  if same then ok = ok + 1 else print("MISMATCH unit", idx, u.name, table.concat(got, ","), "wanted", table.concat(want, ",")) end
end
print(ok .. " of 10 status screens reproduced")
local g = {}
for _, it in ipairs(byIdx[0].gear) do g[#g + 1] = it.name end
print("Marche:", table.concat(g, ", "))
print("gear slots filled, unit 5:", byIdx[5].gearCount, "(one slot holds id 0 = empty)")

-- Move, Jump, Evade as the game's own status screens showed them (scratch buffer 0x020344D8)
local mje = { [0] = {4,2,50}, [1] = {3,2,35}, [2] = {5,3,65}, [3] = {4,2,40}, [4] = {3,2,42}, [5] = {3,2,30}, [6] = {4,3,57}, [7] = {3,2,35}, [8] = {3,2,34}, [9] = {4,4,40}, [10] = {4,3,60}, [11] = {4,2,50}, [12] = {3,2,47}, [13] = {3,2,52}, [14] = {3,4,40}, [15] = {4,4,65}, [16] = {3,2,35}, [17] = {4,2,61}, [18] = {5,6,76}, [19] = {4,3,60} }
local mok = 0
for idx, want in pairs(mje) do
  local u = byIdx[idx]
  if u and u.move == want[1] and u.jump == want[2] and u.evade == want[3] then mok = mok + 1
  else print("MISMATCH move/jump/evade", idx, u and u.name, u and u.move, u and u.jump, u and u.evade, "wanted", want[1], want[2], want[3]) end
end
print(mok .. " of 20 Move/Jump/Evade reproduced")
print("Marche JP:", byIdx[0].jp, byIdx[0].jpText)
-- the equipped abilities (the Abilities screen for Marche showed: Battle Tech, Black Magic, Counter, Weapon Atk+, Combat Combo)
local ab = {}
for _, e in ipairs(byIdx[0].abil) do ab[#ab + 1] = e.name end
print("Marche abilities:", table.concat(ab, ", "))
