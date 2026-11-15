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
mem = {
  u8 = byte, u16 = function(a) return byte(a) | (byte(a + 1) << 8) end,
  u32 = function(a) return byte(a) | (byte(a + 1) << 8) | (byte(a + 2) << 16) | (byte(a + 3) << 24) end,
  read = function(a, n) local t = {} for i = 0, n - 1 do t[#t + 1] = string.char(byte(a + i)) end return table.concat(t) end,
}
dofile(arg[2])
local r = update({})
print("sort",r.sortLabel,"avg",r.avgLevel,"tabs",#r.tabs,"jobs",#r.jobs)
for _, j in ipairs(r.jobs) do io.write(j.name,"(",j.race,",",j.n,") ") end print()
print(r.jsel.name, r.jsel.who)
for _, u in ipairs(r.units) do
  print(string.format("%2d %-10s %-12s %-7s Lv%d HP %d/%d MP %d/%d  atk %d def %d pow %d res %d", u.idx, u.name, u.job, u.race, u.level, u.hp, u.maxHp, u.mp, u.maxMp, u.atk, u.def, u.pow, u.res))
end

print("TOP",r.topName); for _, u in ipairs(r.top) do io.write(u.rank,".",u.name,"=",u.value," ") end print()
print("CMP",r.A.name,"vs",r.B.name); for _, x in ipairs(r.cmp) do io.write(x.label,":",x.a,"/",x.b,x.diff," ") end print()
for _, b in ipairs(r.raceBars) do io.write(b.name,b.n," ") end print()
for _, b in ipairs(r.levelBars) do io.write(b.name,"=",b.n," ") end print()
for _, b in ipairs(r.avg) do io.write(b.name,b.v," ") end print()
