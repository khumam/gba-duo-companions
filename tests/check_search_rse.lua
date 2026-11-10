-- Checks the Pokedex search of Emerald, Ruby and Sapphire against fake RAM (names are written into the ROM
-- tables the pack reads them from). Run: lua tests/check_search_rse.lua
local root = (arg[0]:match("^(.*)/tests/") or ".")
local PACKS = {
  { "pokemon-emerald-companion", 0x45455042, false },
  { "pokemon-ruby-companion", 0x45565841, true },
  { "pokemon-sapphire-companion", 0x45505841, true },
}

for _, cfg in ipairs(PACKS) do
  local name, code, fixed = cfg[1], cfg[2], cfg[3]
  local dir = root .. "/" .. name
  local f = assert(io.open(dir .. "/main.lua")); local src = f:read("a"); f:close()
  local function const(n) return assert(tonumber(src:match("local " .. n .. " = (0x%x+)")), n) end
  local function pocketAt(key) return tonumber(src:match(key .. " = { (0x%x+),")) end

  local ram, modules = {}, {}
  local function put(addr, value, size)
    for i = 0, (size or 1) - 1 do ram[addr + i] = (value >> (8 * i)) & 255 end
  end
  local function putText(addr, text)                       -- Gen 3 text: A-Z, space, end
    for i = 1, #text do
      local c = text:byte(i)
      put(addr + i - 1, c == 32 and 0 or (0xBB + c - 65))
    end
    put(addr + #text, 0xFF)
  end
  mem = {}
  function mem.u8(addr) return ram[addr] or 0 end
  function mem.u16(addr) return mem.u8(addr) | (mem.u8(addr + 1) << 8) end
  function mem.u32(addr) return mem.u16(addr) | (mem.u16(addr + 2) << 16) end
  gfx = { tilemap = function() return "rom-map" end, sprite = function() return "gfx" end }
  log = function() end
  pack = { require = function(module)
    if not modules[module] then modules[module] = assert(loadfile(dir .. "/" .. module .. ".lua"))() end
    return modules[module]
  end }
  actions = {}
  ui = {}
  assert(loadfile(dir .. "/main.lua"))()

  put(0x080000AC, code, 4); put(0x080000BC, 0)
  local sb1, sb2
  if fixed then
    sb1, sb2 = const("SAVEBLOCK1_ADDR"), const("SAVEBLOCK2_ADDR")
    put(const("PLAYER_AVATAR_ADDR") + 5, 0)
    put(const("OBJECT_EVENTS_ADDR"), 1)                    -- the player's object event is active
  else
    sb1, sb2 = 0x02001000, 0x02005000
    put(const("SAVEBLOCK1_PTR_ADDR"), sb1, 4); put(const("SAVEBLOCK2_PTR_ADDR"), sb2, 4)
    put(const("PLAYER_OBJECT_ADDR"), 1)
  end
  put(const("MAP_HEADER_ADDR"), 0x08500000, 4)
  put(const("PARTY_COUNT_ADDR"), 0)
  put(sb2, 0xBB)                                           -- a player name: a save is loaded

  -- seen / owned: Treecko 252, Mudkip 258, Marshtomp 259; caught Mudkip
  local function bit(base, n) local a = base + (n - 1) // 8; put(a, mem.u8(a) | (1 << ((n - 1) % 8))) end
  for _, n in ipairs({ 252, 258, 259 }) do bit(sb2 + 0x5C, n) end
  bit(sb2 + 0x28, 258)
  local game = pack.require("game_data")
  local internal = {}
  for i, n in pairs(game.national) do internal[n] = i end
  local SPECIES = const("SPECIES_NAMES")
  putText(SPECIES + internal[252] * 11, "TREECKO"); putText(SPECIES + internal[258] * 11, "MUDKIP"); putText(SPECIES + internal[259] * 11, "MARSHTOMP")


  ui = {}
  local out = update(ui)
  assert(out.ready, name .. ": must be ready")
  assert(out.dex.notSearching and not out.dex.searching and #out.dex.entries == 24)

  ui = { dexQuery = "MU" }
  out = update(ui)
  assert(out.dex.searching and #out.dex.entries == 1 and out.dex.entries[1].no == "258" and out.dex.found == "1 MATCH", name .. ": mu finds Mudkip")
  assert(out.dex.sel.no == "258" and out.dex.entries[1].sel, "the selection moves to the match")
  ui = { dexQuery = "m" }
  out = update(ui)
  assert(#out.dex.entries == 2 and out.dex.entries[1].no == "258" and out.dex.entries[2].no == "259", name .. ": m finds Mudkip and Marshtomp")
  ui = { dexQuery = "25" }
  out = update(ui)
  assert(out.dex.entries[1].no == "025" and #out.dex.entries == 11, "25 prefix-matches 25 and 250-259, unseen included")
  ui = { dexQuery = "259" }
  out = update(ui)
  assert(#out.dex.entries == 1 and out.dex.entries[1].no == "259")
  ui = { dexQuery = "rayquaza" }
  out = update(ui)
  assert(#out.dex.entries == 0 and out.dex.noMatch, "unseen names never match")
  ui = {}
  assert(update(ui).dex.notSearching and #update(ui).dex.entries == 24, "clearing the query brings the page back")

  print("PASS: " .. name .. " Pokedex search")
end
