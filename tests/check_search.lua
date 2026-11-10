-- Checks the Pokedex search against fake RAM: what is typed in ui.dexQuery filters the list.
-- Run: lua tests/check_search.lua
local root = (arg[0]:match("^(.*)/tests/") or ".")

for _, pack_ in ipairs({ { "pokemon-firered-companion", 0x45525042 }, { "pokemon-leafgreen-companion", 0x45475042 } }) do
  local name = pack_[1]
  local dir = root .. "/" .. name
  local ram, modules = {}, {}
  local function put(addr, value, size)
    for i = 0, (size or 1) - 1 do ram[addr + i] = (value >> (8 * i)) & 255 end
  end
  mem = {}
  function mem.u8(addr) return ram[addr] or 0 end
  function mem.u16(addr) return mem.u8(addr) | (mem.u8(addr + 1) << 8) end
  function mem.u32(addr) return mem.u16(addr) | (mem.u16(addr + 2) << 16) end
  gfx = { tilemap = function() return "rom-map" end }
  log = function() end
  pack = { require = function(module)
    if not modules[module] then modules[module] = assert(loadfile(dir .. "/" .. module .. ".lua"))() end
    return modules[module]
  end }
  actions = {}
  ui = {}
  assert(loadfile(dir .. "/main.lua"))()

  put(0x080000AC, pack_[2], 4); put(0x080000BC, 0)   -- the game's ROM header: BPRE or BPGE, revision 0
  local sb1, sb2 = 0x02001000, 0x02005000
  put(0x03005008, sb1, 4); put(0x0300500C, sb2, 4)
  put(0x02036E38, 1)
  put(sb2, 0xBB); put(sb2 + 1, 0xFF)
  put(sb2 + 0x0A, 12345, 2); put(sb2 + 0x0E, 12, 2); put(sb2 + 0x10, 34)
  put(sb2 + 0xF20, 0x1234, 4)
  put(sb1 + 0x290, 3000 ~ 0x1234, 4)
  put(sb2 + 0x28, 1); put(sb2 + 0x5C, 3)
  put(0x02036DFC, 0x02009000, 4); put(0x02009000, 20, 4); put(0x02009004, 40, 4)
  put(sb1 + 4, 3); put(sb1 + 5, 19)
  put(0x02024029, 1)
  local mon = 0x02024284
  put(mon + 0x20, 1, 4); put(mon + 0x24, 135, 4); put(mon + 0x2C, 33, 4); put(mon + 0x34, 35, 4)
  put(mon + 0x54, 5); put(mon + 0x56, 19, 2); put(mon + 0x58, 20, 2)

  -- seen Charmander (4), Charmeleon (5) and Pikachu (25); caught Charmander
  local function seen(n) local a = sb2 + 0x5C + (n - 1) // 8; put(a, mem.u8(a) | (1 << ((n - 1) % 8))) end
  local function owned(n) local a = sb2 + 0x28 + (n - 1) // 8; put(a, mem.u8(a) | (1 << ((n - 1) % 8))) end
  for _, n in ipairs({ 4, 5, 25 }) do seen(n) end
  owned(4)

  -- no search: the page of 24 and the pager
  ui = {}
  local out = update(ui)
  assert(out.ready, "pack must be ready")
  assert(out.dex.notSearching and not out.dex.searching and #out.dex.entries == 24)

  -- a name: only seen species match, case-insensitively, and the selection moves to the first match
  ui = { dexQuery = "CHAR" }
  out = update(ui)
  assert(out.dex.searching and #out.dex.entries == 2, "char finds Charmander and Charmeleon")
  assert(out.dex.entries[1].no == "004" and out.dex.entries[2].no == "005")
  assert(out.dex.found == "2 MATCHES" and out.dex.sel.no == "004" and out.dex.entries[1].sel)
  -- a number
  ui = { dexQuery = "25" }
  out = update(ui)
  assert(#out.dex.entries == 1 and out.dex.entries[1].no == "025" and out.dex.found == "1 MATCH")
  -- unseen names are never matched (no spoilers), unseen numbers are
  ui = { dexQuery = "mewtwo" }
  out = update(ui)
  assert(#out.dex.entries == 0 and out.dex.noMatch)
  ui = { dexQuery = "  " }
  out = update(ui)
  assert(out.dex.notSearching, "blank is not a search")

  print("PASS: " .. name .. " Pokedex search")
end
