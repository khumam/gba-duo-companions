log = function() end
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
update({}); local r = update({})
print("day", r.day, "funds", r.funds, "turn", r.turnName)
for _, a in ipairs(r.armies) do
  print(a.name, a.count, "units, value", a.value, a.mine and "(turn)" or "")
  for _, u in ipairs(a.list) do print(string.format("   %-9s hp %2d fuel %2d/%2d at %d,%d", u.name, u.tens, u.fuel, u.maxFuel, u.x, u.y)) end
end
print(r.buyText)
for _, g in ipairs(r.guide) do print(string.format("%-9s cost %5d mv %d vis %d rng %s ammo %s fuel %d afford %s owned %d", g.name, g.cost, g.move, g.vision, g.range, g.ammo, g.fuel, tostring(g.afford), g.owned)) end
print("focus", r.focus.name, r.focus.range, r.focus.worth)

for _, v in ipairs(r.versus) do io.write(v.label,":",v.a,"/",v.b," ") end print()
print(#r.log, r.log[1].line)
local r2 = update({ page = "log" }); local on = {}
for i = 1, 7 do on[#on + 1] = (r2["B" .. i] and "1" or "0") end
print("window at log:", table.concat(on), "more", r2.navMore, "noPrev", r2.noPrev, "noNext", r2.noNext)
actions.navShift(-1); local r3 = update({ page = "log" }); on = {}
for i = 1, 7 do on[#on + 1] = (r3["B" .. i] and "1" or "0") end
print("after shift left:", table.concat(on))
print("icons", r.units[1].icon, r.guide[1].icon, r.groups[1].icon, r.focus.icon)
print("map", r.mapImg, r.mapW, r.mapH, #r.mapUnits, r.mapUnits[1].left, r.mapUnits[1].top, r.mapUnits[1].size, r.hasMap)
local cnt = {}
for _, p in ipairs(r.mapProps) do cnt[p.color] = (cnt[p.color] or 0) + 1 end
for c, n in pairs(cnt) do io.write(c, "=", n, " ") end print("props", #r.mapProps)
for _, v in ipairs(r.versus) do if v.label == "Cities & HQ" then print("versus", v.a, v.b) end end
