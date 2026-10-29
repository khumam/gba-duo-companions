-- Run: lua tests/check_leafgreen.lua [path/to/BPGE-v1.0.gba]
local root = (arg[0]:match("^(.*)/tests/") or ".")
local rom
if arg[1] then
  local file = assert(io.open(arg[1], "rb"))
  rom = file:read("a")
  file:close()
  assert(rom:sub(0xAD, 0xB0) == "BPGE" and rom:byte(0xBD) == 0, "Expected BPGE v1.0")
end

for _, name in ipairs({ "pokemon-leafgreen-companion", "pokemon-leafgreen-v-companion", "pokemon-leafgreen-minimal-companion" }) do
  local dir = root .. "/" .. name
  local ram, modules, calls = {}, {}, 0
  local function put(addr, value, size)
    for i = 0, (size or 1) - 1 do ram[addr + i] = (value >> (8 * i)) & 255 end
  end
  mem = {}
  function mem.u8(addr)
    if ram[addr] ~= nil then return ram[addr] end
    if rom and addr >= 0x08000000 then return assert(rom:byte(addr - 0x08000000 + 1)) end
    return 0
  end
  function mem.u16(addr) return mem.u8(addr) | (mem.u8(addr + 1) << 8) end
  function mem.u32(addr) return mem.u16(addr) | (mem.u16(addr + 2) << 16) end
  put(0x080000AC, 0x45475042, 4)
  put(0x080000BC, 0)
  local maps = { [0] = 0x083F06D8, 0x083F0938, 0x083F0A48, 0x083F0B2C }
  local failGraphics = false
  gfx = { tilemap = function(a)
    calls = calls + 1
    assert(a.tiles == 0x083EF458 and a.palette == 0x083EF118)
    local found = false
    for _, addr in pairs(maps) do if a.map == addr then found = true end end
    assert(found and a.lz77 and a.stride == 30 and a.x == 3 and a.y == 3)
    assert(a.width == 168 and a.height == 136 and a.opaque)
    if rom then
      assert(mem.u8(a.tiles) == 0x10 and mem.u8(a.map) == 0x10)
      assert(mem.u32(a.tiles) >> 8 == 10240 and mem.u32(a.map) >> 8 == 1200)
    end
    if failGraphics then error("graphics unavailable") end
    return "rom-map:" .. a.map
  end }
  log = function() end
  pack = { require = function(module)
    if not modules[module] then modules[module] = assert(loadfile(dir .. "/" .. module .. ".lua"))() end
    return modules[module]
  end }
  actions = {}
  assert(loadfile(dir .. "/main.lua"))()
  assert(update().waiting, "Title screen must wait")
  local sb1, sb2 = 0x02001000, 0x02005000
  put(0x03005008, sb1, 4); put(0x0300500C, sb2, 4)
  put(0x02036E38, 1)
  put(sb2, 0xBB); put(sb2 + 1, 0xFF) -- Trainer A
  put(sb2 + 0x0A, 12345, 2); put(sb2 + 0x0E, 12, 2); put(sb2 + 0x10, 34)
  put(sb2 + 0xF20, 0x1234, 4)
  put(sb1 + 0x290, 3000 ~ 0x1234, 4)
  put(sb1 + 0xFE4, 3)
  put(sb1 + 0x310, 13, 2); put(sb1 + 0x312, 5 ~ 0x1234, 2)
  put(sb2 + 0x28, 1); put(sb2 + 0x5C, 3)
  local game = pack.require("game_data")
  local mapsec
  for id, cell in pairs(game.mapCells) do
    if game.mapsecs[id] == "ROUTE 1" then mapsec = id break end
  end
  assert(mapsec)
  put(0x02036DFC + 0x14, mapsec); put(0x02036DFC + 0x17, 3)
  put(0x02036DFC, 0x02009000, 4)
  put(0x02009000, 20, 4); put(0x02009004, 40, 4)
  put(0x02036E38 + 0x10, 17, 2); put(0x02036E38 + 0x12, 27, 2)
  put(sb1 + 4, 3); put(sb1 + 5, 19) -- Route 1
  put(0x02024029, 1)
  local mon = 0x02024284
  put(mon + 0x20, 1, 4); put(mon + 0x24, 135, 4) -- Bulbasaur, GAEM order, XOR key 0
  put(mon + 0x2C, 33, 4); put(mon + 0x34, 35, 4) -- Tackle, PP
  put(mon + 0x54, 5); put(mon + 0x56, 19, 2); put(mon + 0x58, 20, 2)
  if not rom then
    put(0x08254760 + 28 + 6, 12); put(0x08254760 + 28 + 7, 3)
    put(0x08254760 + 28 + 0x13, 3); put(0x08254760 + 28 + 0x16, 65)
    put(0x083C9AF4, 255)
  end
  local out = update()
  assert(out.ready and out.map.image == "rom-map:" .. maps[0])
  assert(out.location == "ROUTE 1" and out.map.onMap and out.map.x > 0 and out.map.x < 100)
  assert(out.party[1].name == "BULBASAUR" and out.party[1].ability == "OVERGROW")
  assert(out.party[1].types[1].name == "GRASS" and out.party[1].types[2].name == "POISON")
  assert(out.party[1].moves[1].name == "TACKLE")
  assert(out.trainer.name == "A" and out.trainer.id == "12345" and out.trainer.badges == "2/8")
  assert(out.money == "3,000" and out.time == "12:34")
  assert(out.bag.items[1].count == "x05" and out.dex.seen == "002" and out.dex.caught == "001")
  if rom then assert(out.map.hasWild and #out.map.wild > 0, "Route 1 must have ROM encounters") end
  for region = 0, 3 do assert(pack.require("town_map").image(region) == "rom-map:" .. maps[region]) end
  failGraphics = true
  assert(update().map.image == "asset:ui/radar.png", "Failed graphics must fall back")
  failGraphics = false
  put(0x02023BCC, 2); put(0x03004F84, 0x08010001, 4)
  for battler = 0, 1 do
    local base = 0x02023BE4 + battler * 0x58
    put(base, 1, 2); put(base + 0x28, 19, 2); put(base + 0x2C, 20, 2)
    put(base + 0x21, 12); put(base + 0x22, 3); put(base + 0x2A, 5)
  end
  out = update()
  assert(out.battle.inBattle and out.ui.navigate == "battle" and out.battle.you.name == "BULBASAUR")
  put(0x02023E8A, 1)
  assert(update().ui.back)
  local before = calls
  put(0x080000BC, 1)
  assert(update().waiting and calls == before, "Revision 1 must not read v1.0 data")
  put(0x080000BC, 0); put(0x080000AC, 0x45525042, 4)
  assert(update().waiting and calls == before, "FireRed must not read LeafGreen tables")
  modules.town_map = nil
  assert(pack.require("town_map").image(0) == nil, "Wrong ROM must not render a BPGE map")
  print("PASS: " .. name .. " ROM guard, map, party, bag, dex, trainer, wild, battle")
end
