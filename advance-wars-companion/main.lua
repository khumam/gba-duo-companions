-- Advance Wars (USA, AWRE) companion: the day, funds and every army's units.
-- Addresses found with a headless mGBA run on the real ROM and a save state; see NOTES.md.

local GAME     = "AWRE"
local DAY      = 0x03004420     -- the day, a 32-bit counter
local TURN     = 0x03004424     -- whose turn it is: 0x20 Orange Star, 0x40 Blue Moon, 0x80, 0x100 ...
local FUNDS    = 0x0201AB9C     -- Orange Star's funds (32-bit)
local ARMIES   = 0x02019F40     -- the units of each army: 64 records of 12 bytes, 0x300 bytes per army
local ARMY_GAP = 0x300
local SLOTS    = 64
local UTAB     = 0x08283058     -- unit types in the ROM: 0x70 bytes per type id; name pointer first
local USIZE    = 0x70
local TYPES    = 32

local ARMY_NAMES  = { "Orange Star", "Blue Moon", "Green Earth", "Yellow Comet" }
local ARMY_COLORS = { "#f7a57b", "#7b9cff", "#6fd08a", "#f1d84a" }
local ARMY_SLUGS  = { "orange", "blue", "green", "yellow" }
-- the icons (assets/icons/units), by unit type id: cut from the game's own Unit list
local ICON = { [1] = "infantry", [2] = "mech", [3] = "md-tank", [5] = "tank", [6] = "recon", [7] = "apc", [10] = "artillery", [11] = "rockets",
  [14] = "anti-air", [15] = "missiles", [16] = "fighter", [17] = "bomber", [19] = "b-copter", [20] = "t-copter", [21] = "battleship",
  [22] = "cruiser", [23] = "lander", [24] = "sub" }
local function iconOf(id, n) return ICON[id] and ("asset:icons/units/" .. ICON[id] .. "-" .. ARMY_SLUGS[n + 1] .. ".png") or "" end

local cache = {}
local function str(p)
  if p < 0x08000000 or p >= 0x0A000000 then return "" end
  local s = cache[p]
  if s then return s end
  local t = {}
  for i = 0, 15 do
    local b = mem.u8(p + i)
    if b == 0 then break end
    t[#t + 1] = string.char(b)
  end
  s = table.concat(t); cache[p] = s; return s
end

-- a unit type by its id: { name, fuel, move, cost } (cost in funds), or nil for an id that is not a unit
local typeCache = {}
local function utype(id)
  if id < 1 or id >= TYPES then return nil end
  local t = typeCache[id]
  if t == nil then
    local a = UTAB + USIZE * id
    local name = str(mem.u32(a))
    if name == "" then t = false
    else
      local lo, hi = mem.u8(a + 0x10), mem.u8(a + 0x11)
      t = { id = id, name = name, fuel = mem.u8(a + 0x12), move = mem.u8(a + 0x0C), cost = mem.u16(a + 0x18) * 10,
        ammo = mem.u8(a + 0x0D), vision = mem.u8(a + 0x0E), rmin = lo, rmax = hi }
      if t.cost == 0 or t.fuel == 0 then t = false end      -- a name with no stats is not a unit
    end
    typeCache[id] = t
  end
  return t or nil
end

local function army(n)
  local base = ARMIES + ARMY_GAP * n
  local list, hpSum = {}, 0
  for s = 0, SLOTS - 1 do
    local a = base + 12 * s
    local ut = utype(mem.u8(a))
    local hp = mem.u8(a + 4) & 0x7F
    if ut and hp > 0 and hp <= 100 then
      list[#list + 1] = {
        id = mem.u8(a), n = #list, icon = iconOf(mem.u8(a), n), name = ut.name, move = ut.move, vision = ut.vision, ammo = (ut.ammo > 0) and tostring(ut.ammo) or "none",
        range = (ut.rmax > 1 or ut.rmin > 1) and string.format("%d-%d", ut.rmin, ut.rmax) or "1", x = mem.u8(a + 2) + 1, y = mem.u8(a + 3) + 1,
        tens = (hp + 9) // 10, hpPct = hp / 100, fuel = mem.u8(a + 6), maxFuel = ut.fuel,
        fuelPct = (ut.fuel > 0) and math.min(1, mem.u8(a + 6) / ut.fuel) or 0, cost = ut.cost, low = hp <= 30,
        worth = ut.cost * ((hp + 9) // 10) // 10, hp = hp,
      }
    end
  end
  table.sort(list, function(p, q) if p.id ~= q.id then return p.id < q.id end if p.y ~= q.y then return p.y < q.y end return p.x < q.x end)
  local value = 0
  for _, u in ipairs(list) do value = value + u.cost * u.tens // 10 end
  return list, value
end

-- the map: the terrain as the game draws it, from its own RAM grid and ROM tile table (drawn by the engine; no art shipped)
local MAP_DIMS   = 0x030036E0     -- width, height (bytes)
local MAP_GRID   = 0x02008014     -- one u16 metatile id per cell, row-major
local MAP_TABLE  = 0x080D1FC0     -- ROM: 4 u16 tile entries per id
local MAP_TILES  = 0x06008000     -- the terrain layer's tiles (BG3's character base): valid while the map screen is up
local MAP_CODES  = 0x02016C2A   -- one terrain code per cell: 6 city, 8 HQ (+0x20 per owner: 0x26 Orange, 0x46 Blue ...), 7 sea, 1 plain, 5 road ...
local OWNER_COLORS = { "#d9d9d9", "#f7a57b", "#7b9cff", "#6fd08a", "#f1d84a" }
local mapKey, mapW, mapH
local mapSig, mapDay, seenSig, seenCount, lastNote
local DEBUG = false
local function note(msg) if DEBUG and msg ~= lastNote then lastNote = msg; if log then log(msg) end end end
local function terrain(day)
  local w, h = mem.u8(MAP_DIMS), mem.u8(MAP_DIMS + 1)
  if w < 8 or w > 30 or h < 8 or h > 30 then return nil end
  local sig, zeros, bad = 0, 0, 0
  for i = 0, w * h - 1 do
    local v = mem.u16(MAP_GRID + 2 * i)
    sig = (sig * 31 + v) % 2147483647
    if v == 0 then zeros = zeros + 1 end
    if v > 0x1FF then bad = bad + 1 end
  end
  -- the grid must look like a map, and hold still for two updates, before the terrain is drawn: the game rewrites it while screens change
  local looksRight = (bad == 0) and (zeros * 20 < w * h)
  if sig == seenSig then seenCount = seenCount + 1 else seenSig, seenCount = sig, 1 end
  local want = (mapKey == nil or sig ~= mapSig or day ~= mapDay or w ~= mapW or h ~= mapH)
  if want and looksRight and seenCount >= 2 and mem.u16(0x0400000E) == 0x1F0B then
    local ok, key = pcall(gfx.layers, { x = 0, y = 0, width = w * 16, height = h * 16, palette = 0x05000000,
      layers = { { grid = MAP_GRID, cellBytes = 2, stride = w, gridW = w, gridH = h, idMask = 0x1FF, metatiles = MAP_TABLE, tiles = MAP_TILES } } })
    if ok and key then mapKey, mapW, mapH, mapSig, mapDay = key, w, h, sig, day; note(string.format("terrain drawn sig=%d zeros=%d", sig, zeros)) else note("terrain draw failed: " .. tostring(key)) end
  elseif want then
    note(string.format("terrain skipped: looksRight=%s zeros=%d bad=%d seen=%d bg3=%04X", tostring(looksRight), zeros, bad, seenCount, mem.u16(0x0400000E)))
  end
  if mapKey and mapW == w and mapH == h then return mapKey, w, h end
  return nil
end

-- ROM tables (all read at run time, nothing copied into the pack) --------------------------------------------------------------------
-- damage: two 24 x 24 byte tables, one row per attacker unit id, one column per defender id (minus 1). The first is the main gun, the second the
-- machine gun; the game uses the main gun while the unit has ammo and the number is not 0, so the best of the two is the damage at full HP.
local DMG_MAIN, DMG_MG, DMG_ROW = 0x08283B48, 0x08283D88, 24
local DEF_TAB  = 0x08284314     -- defence stars x 10, by terrain id
local MOVE_OFF = 0x4C           -- inside a unit record: move cost by terrain id (255 = cannot enter)
local function dmg(a, d)
  local o = (a - 1) * DMG_ROW + (d - 1)
  return math.max(mem.u8(DMG_MAIN + o), mem.u8(DMG_MG + o))
end
local TARGETS = { 1, 5, 3, 10, 19, 21 }                              -- infantry, tank, md tank, artillery, b copter, battleship
local TERR = { { 1, "Plain", "plain" }, { 5, "Road", "road" }, { 4, "Wood", "wood" }, { 3, "Mountain", "mountain" }, { 2, "River", "river" },
  { 12, "Bridge", "bridge" }, { 13, "Shoal", "shoal" }, { 7, "Sea", "sea" }, { 19, "Reef", "reef" }, { 6, "City", "city" },
  { 14, "Base", "base" }, { 10, "Airport", "airport" }, { 11, "Port", "port" }, { 8, "HQ", "hq" } }
local MOVERS = { { 1, "infantry" }, { 5, "tank" }, { 6, "recon" }, { 19, "b-copter" }, { 21, "battleship" } }   -- foot, tread, tire, air, sea
local INCOME_KINDS = { [6] = true, [8] = true, [10] = true, [11] = true, [14] = true }   -- city, HQ, airport, port, base: 1000 a day each

local ACC  = { "#e85428", "#3068d8", "#48b840", "#f8d018" }
local PILL = { "#de6b52", "#5882de", "#58b858", "#e8c820" }

local history = {}
local function props(w, h)         -- properties per owner (0 = neutral), from the game's own terrain codes
  local n = { [0] = 0, 0, 0, 0, 0 }
  if not w then return n end
  for i = 0, w * h - 1 do
    local code = mem.u8(MAP_CODES + i)
    if INCOME_KINDS[code & 0x1F] and (code >> 5) <= 4 then n[code >> 5] = n[code >> 5] + 1 end
  end
  return n
end

local function pct(v, max) return string.format("%d%%", math.max(0, math.min(100, math.floor(v * 100 / max + 0.5)))) end
local function px(v) return string.format("%.1fpx", v) end

local function baseUpdate(ui)
  if mem.read(0x080000AC, 4) ~= GAME then return { ready = false, waiting = true } end
  local day = mem.u32(DAY)
  if day < 1 or day > 999 then return { ready = false, waiting = true } end
  local turnBits, turn = mem.u32(TURN), 0
  while turnBits > 0x20 and turn < 3 do turnBits = turnBits >> 1; turn = turn + 1 end

  local armies = {}
  for n = 0, 3 do
    local list, value = army(n)
    if #list > 0 then armies[#armies + 1] = { n = n, count = #list, value = value, list = list } end
  end
  if #armies == 0 then return { ready = false, waiting = true } end
  local me = armies[1]
  for _, a in ipairs(armies) do if a.n == turn then me = a end end
  local foe = armies[1]
  if foe == me then foe = armies[2] or armies[1] end
  local funds = mem.u32(FUNDS)

  -- the map (needed for properties, cities and the minimap)
  local mw, mh = mem.u8(MAP_DIMS), mem.u8(MAP_DIMS + 1)
  if mw < 8 or mw > 30 or mh < 8 or mh > 30 then mw, mh = nil, nil end
  local pr = props(mw, mh)
  local income = (pr[me.n + 1] or 0) * 1000

  -- FIELD: three tug-of-war bars, my army (left) against the other
  local function bar(a, b, icon)
    local t = math.max(1, a + b)
    return { a = a, b = b, aw = pct(a, t), icon = icon }
  end
  local bars = { bar(me.count, foe.count, "asset:ui/chip-units.png"), bar(me.value // 1000, foe.value // 1000, "asset:ui/chip-coin.png"),
    bar(pr[me.n + 1] or 0, pr[foe.n + 1] or 0, "asset:terrain/city.png") }
  if me == foe then bars = {} end

  -- UNITS: every unit type as a tile; the picked one in the inspector
  local have = {}
  for _, u in ipairs(me.list) do have[u.id] = (have[u.id] or 0) + 1 end
  local pick = tonumber(ui.type) or 5
  if not utype(pick) then pick = 1 end
  local tiles, canBuy = {}, 0
  for id = 1, TYPES - 1 do
    local t = utype(id)
    if t then
      local afford = funds >= t.cost
      if afford then canBuy = canBuy + 1 end
      tiles[#tiles + 1] = { id = id, icon = iconOf(id, me.n), owned = have[id] or 0, hasOwned = (have[id] or 0) > 0, afford = afford, poor = not afford, on = (id == pick),
                            name = t.name, cost = t.cost, ownedTxt = "x" .. (have[id] or 0) }
    end
  end
  local pt = utype(pick)
  local foeSlug = (me.n == 1) and 0 or 1
  local dmgRows, best, bestV = {}, 0, 0
  for k, d in ipairs(TARGETS) do
    local v = dmg(pick, d)
    if v > bestV then best, bestV = k, v end
    dmgRows[k] = { icon = iconOf(d, foeSlug), v = v, txt = (v > 0) and tostring(v) or "-", w = pct(v, 120), none = v == 0 }
  end
  for k, r in ipairs(dmgRows) do r.best = (k == best) end
  local pickRange = (pt.rmax > 1 or pt.rmin > 1) and string.format("%d-%d", pt.rmin, pt.rmax) or "1"

  -- TERRAIN: tiles, the picked one with its DEF stars and the move cost of each kind of unit
  local tpick = tonumber(ui.terr) or 3
  local terr, tsel = {}, TERR[4]
  for _, t in ipairs(TERR) do
    local on = (t[1] == tpick)
    if on then tsel = t end
    terr[#terr + 1] = { id = t[1], img = "asset:terrain/" .. t[3] .. ".png", on = on }
  end
  local stars, nStars = {}, mem.u8(DEF_TAB + tsel[1]) // 10
  for i = 1, 4 do stars[i] = { src = (i <= nStars) and "asset:ui/star-on.png" or "asset:ui/star-off.png" } end
  local costs = {}
  for i, m in ipairs(MOVERS) do
    local c = mem.u8(UTAB + USIZE * m[1] + MOVE_OFF + tsel[1])
    local ok = c > 0 and c < 99
    costs[i] = { icon = iconOf(m[1], me.n), txt = ok and tostring(c) or "-", blocked = not ok }
  end

  -- MAP: the terrain picture, every unit on it, the properties by owner, and the box the top screen shows
  local mapImg, mw2, mh2 = terrain(day)
  local mapUnits, mapProps, mapSize = {}, {}, {}
  local viewBox, hasView = {}, false
  if mapImg then
    local s = math.min(336 / (mw2 * 16), 270 / (mh2 * 16))      -- dp per map pixel
    local cell = 16 * s
    mapSize = { w = px(mw2 * cell), h = px(mh2 * cell) }
    for y = 0, mh2 - 1 do
      for x = 0, mw2 - 1 do
        local code = mem.u8(MAP_CODES + y * mw2 + x)
        local kind = code & 0x1F
        if kind == 6 or kind == 8 then
          local owner = code >> 5
          if owner <= 4 then
            local sz = cell * ((kind == 8) and 0.62 or 0.46)
            mapProps[#mapProps + 1] = { left = px(x * cell + cell - sz - 1), top = px(y * cell + cell - sz - 1), size = px(sz), color = OWNER_COLORS[owner + 1], hq = kind == 8 }
          end
        end
      end
    end
    for _, a in ipairs(armies) do
      for _, u in ipairs(a.list) do
        mapUnits[#mapUnits + 1] = { left = px((u.x - 1) * cell), top = px((u.y - 1) * cell), size = px(cell), sizeH = px(cell * 0.9), icon = u.icon }
      end
    end
    -- the top screen shows 15 x 10 tiles; BG3's scroll says where (a map that fits shows no box)
    if mw2 > 15 or mh2 > 10 then
      local hx, vy = mem.u16(0x0400001C) & 0x1FF, mem.u16(0x0400001E) & 0x1FF
      viewBox = { left = px(hx / 16 * cell), top = px(vy / 16 * cell), width = px(15 * cell), height = px(10 * cell) }
      hasView = true
    end
  end

  -- remember the end of each day for the log (kept in memory while the game runs)
  local line = { day = day, o = me.count, b = foe.count, funds = funds }
  if #history > 0 and history[#history].day == day then history[#history] = line else history[#history + 1] = line end
  while #history > 40 do table.remove(history, 1) end

  local page = ui.page or "field"
  return {
    ready = true, waiting = false, day = day, funds = funds, income = income, hasIncome = income > 0,
    turnName = ARMY_NAMES[me.n + 1], accent = ACC[me.n + 1], foeAcc = ACC[foe.n + 1], pill = PILL[me.n + 1], crate = "asset:icons/ui/crate-" .. ARMY_SLUGS[me.n + 1] .. ".png",
    bars = bars, hasBars = #bars > 0,
    tiles = tiles, pickName = pt.name, pickIcon = iconOf(pick, me.n), pickCost = pt.cost, pickAfford = funds >= pt.cost, pickPoor = funds < pt.cost,
    pickMove = pt.move, pickVision = pt.vision, pickRange = pickRange, pickAmmo = (pt.ammo > 0) and tostring(pt.ammo) or "-", pickFuel = pt.fuel, pickOwned = have[pick] or 0,
    dmg = dmgRows, canBuy = canBuy,
    terr = terr, defN = tostring(nStars), terrName = tsel[2], terrImg = "asset:terrain/" .. tsel[3] .. ".png", stars = stars, costs = costs,
    mapImg = mapImg or "", noMap = (mapImg == nil), hasMap = (mapImg ~= nil), mapW = mapSize.w or "10px", mapH = mapSize.h or "10px",
    mapUnits = mapUnits, mapProps = mapProps, hasView = hasView, view = viewBox,
    chipL = { icon = iconOf(1, me.n), n = me.count, name = ARMY_NAMES[me.n + 1], value = me.value, valueTxt = string.format("%dk", me.value // 1000), turn = me == me, crate = "asset:icons/ui/crate-" .. ARMY_SLUGS[me.n + 1] .. ".png", p = pr[me.n + 1] or 0, color = ACC[me.n + 1] },
    chipR = { icon = iconOf(1, foe.n), n = foe.count, name = ARMY_NAMES[foe.n + 1], value = foe.value, valueTxt = string.format("%dk", foe.value // 1000), turn = foe == me, crate = "asset:icons/ui/crate-" .. ARMY_SLUGS[foe.n + 1] .. ".png", p = pr[foe.n + 1] or 0, color = ACC[foe.n + 1] },
    onField = (page == "field"), onUnits = (page == "units"), onTerrain = (page == "terrain"), onMap = (page == "map"),
  }
end

local lastGood
function update(ui)
  local ok, r = pcall(baseUpdate, ui)
  if ok then lastGood = r else
    if log then log("update error: " .. tostring(r)) end       -- keep showing the last good screen instead of going blank
    r = lastGood
  end
  return r
end
