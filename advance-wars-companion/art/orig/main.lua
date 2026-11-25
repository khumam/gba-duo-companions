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

local history = {}            -- one line per day seen in this session: units and funds
local CLASSES = { { "Foot", { [1] = 1, [2] = 1 } }, { "Vehicle", { [3] = 1, [5] = 1, [6] = 1, [7] = 1, [10] = 1, [11] = 1, [14] = 1, [15] = 1 } },
  { "Air", { [16] = 1, [17] = 1, [19] = 1, [20] = 1 } }, { "Sea", { [21] = 1, [22] = 1, [23] = 1, [24] = 1 } } }

local function baseUpdate(ui)
  if mem.read(0x080000AC, 4) ~= GAME then return { ready = false, waiting = true } end
  local day = mem.u32(DAY)
  if day < 1 or day > 999 then return { ready = false, waiting = true } end
  local turnBits, turn = mem.u32(TURN), 0
  while turnBits > 0x20 and turn < 3 do turnBits = turnBits >> 1; turn = turn + 1 end

  local armies = {}
  for n = 0, 3 do
    local list, value = army(n)
    if #list > 0 then
      armies[#armies + 1] = { n = n, name = ARMY_NAMES[n + 1], color = ARMY_COLORS[n + 1], count = #list, value = value, list = list, mine = (n == turn) }
    end
  end
  if #armies == 0 then return { ready = false, waiting = true } end

  local chosen = tonumber(ui.army) or armies[1].n
  local sel = armies[1]
  for _, a in ipairs(armies) do
    a.on = (a.n == chosen)
    if a.on then sel = a end
  end
  -- the unit types of the shown army, counted
  local counts, order = {}, {}
  for _, u in ipairs(sel.list) do
    local c = counts[u.id]
    if not c then c = { name = u.name, icon = u.icon, n = 0 }; counts[u.id] = c; order[#order + 1] = c end
    c.n = c.n + 1
  end

  local funds = mem.u32(FUNDS)
  local pos = tonumber(ui.unit) or 0
  local focus = sel.list[pos + 1] or sel.list[1]
  local have = {}
  for _, a in ipairs(armies) do
    if a.on then for _, u in ipairs(a.list) do have[u.id] = (have[u.id] or 0) + 1 end end
  end
  local guide, pickType = {}, tonumber(ui.type) or 1
  for id = 1, TYPES - 1 do
    local t = utype(id)
    if t then
      guide[#guide + 1] = { id = id, icon = iconOf(id, sel.n), name = t.name, cost = t.cost, move = t.move, vision = t.vision, fuel = t.fuel, ammo = (t.ammo > 0) and tostring(t.ammo) or "none",
        range = (t.rmax > 1 or t.rmin > 1) and string.format("%d-%d", t.rmin, t.rmax) or "1", afford = funds >= t.cost, owned = have[id] or 0,
        hasOwned = (have[id] or 0) > 0, on = (id == pickType) }
    end
  end
  table.sort(guide, function(p, q) if p.cost ~= q.cost then return p.cost < q.cost end return p.id < q.id end)
  local gsel = guide[1]
  for _, g in ipairs(guide) do if g.on then gsel = g end end
  local canBuy = 0
  for _, g in ipairs(guide) do if g.afford then canBuy = canBuy + 1 end end

  -- map: the terrain picture, and every unit's icon on it
  local mapImg, mw, mh = terrain(day)
  local mapUnits, mapSize, mapProps, propCount = {}, {}, {}, {}
  if mapImg then
    local s = math.min(500 / (mw * 16), 292 / (mh * 16))     -- dp per map pixel
    local cell = 16 * s
    mapSize = { w = string.format("%.1fpx", mw * cell), h = string.format("%.1fpx", mh * cell) }
    for y = 0, mh - 1 do                                    -- cities and HQs, by owner
      for x = 0, mw - 1 do
        local code = mem.u8(MAP_CODES + y * mw + x)
        local kind = code & 0x1F
        if kind == 6 or kind == 8 then
          local owner = code >> 5
          if owner <= 4 then
            local sz = cell * ((kind == 8) and 0.62 or 0.46)
            mapProps[#mapProps + 1] = { left = string.format("%.1fpx", x * cell + cell - sz - 1), top = string.format("%.1fpx", y * cell + cell - sz - 1),
              size = string.format("%.1fpx", sz), color = OWNER_COLORS[owner + 1], hq = kind == 8 }
            propCount[owner] = (propCount[owner] or 0) + 1
          end
        end
      end
    end
    for _, a in ipairs(armies) do
      for _, u in ipairs(a.list) do
        mapUnits[#mapUnits + 1] = { left = string.format("%.1fpx", (u.x - 1) * cell), top = string.format("%.1fpx", (u.y - 1) * cell),
          size = string.format("%.1fpx", cell), sizeH = string.format("%.1fpx", cell * 0.9), icon = u.icon }
      end
    end
  end

  -- armies: the first two side by side
  local L, R = armies[1], armies[2] or armies[1]
  local function profile(a)
    local hpSum, fuelSum = 0, 0
    local cls = { 0, 0, 0, 0 }
    for _, u in ipairs(a.list) do
      hpSum = hpSum + u.tens
      fuelSum = fuelSum + u.fuelPct
      for k, c in ipairs(CLASSES) do if c[2][u.id] then cls[k] = cls[k] + 1 end end
    end
    return { count = a.count, value = a.value, avgHp = string.format("%.1f", hpSum / a.count), avgFuel = string.format("%d%%", math.floor(fuelSum / a.count * 100 + 0.5)), cls = cls }
  end
  local pl, pr = profile(L), profile(R)
  local versus = {
    { label = "Units", a = pl.count, b = pr.count, aWin = pl.count > pr.count, bWin = pr.count > pl.count },
    { label = "Army value", a = pl.value, b = pr.value, aWin = pl.value > pr.value, bWin = pr.value > pl.value },
    { label = "Average HP", a = pl.avgHp, b = pr.avgHp, aWin = tonumber(pl.avgHp) > tonumber(pr.avgHp), bWin = tonumber(pr.avgHp) > tonumber(pl.avgHp) },
    { label = "Average fuel", a = pl.avgFuel, b = pr.avgFuel, aWin = false, bWin = false },
  }
  if next(propCount) then
    local a, b = propCount[L.n + 1] or 0, propCount[R.n + 1] or 0
    versus[#versus + 1] = { label = "Cities & HQ", a = a, b = b, aWin = a > b, bWin = b > a }
  end
  for k, c in ipairs(CLASSES) do
    versus[#versus + 1] = { label = c[1], a = pl.cls[k], b = pr.cls[k], aWin = pl.cls[k] > pr.cls[k], bWin = pr.cls[k] > pl.cls[k] }
  end

  -- log: a line per day
  local line = { day = day, o = armies[1].count, b = (armies[2] or armies[1]).count, funds = funds }
  if #history > 0 and history[#history].day == day then history[#history] = line else history[#history + 1] = line end
  while #history > 40 do table.remove(history, 1) end
  local log = {}
  for i = #history, 1, -1 do
    local h = history[i]
    log[#log + 1] = { day = h.day, line = string.format("%s %d  vs  %s %d", armies[1].name, h.o, (armies[2] or armies[1]).name, h.b), funds = h.funds }
  end

  return {
    mapImg = mapImg or "", noMap = (mapImg == nil), hasMap = (mapImg ~= nil), mapW = mapSize.w or "10px", mapH = mapSize.h or "10px", mapUnits = mapUnits, mapProps = mapProps, mapNote = mapImg and string.format("%d x %d", mw, mh) or "open the map screen", versus = versus, vsL = L, vsR = R, log = log, 
    onMap = (ui.page == "map"), onVs = (ui.page == "armies"), onLog = (ui.page == "log"),
    onFront = (ui.page == nil or ui.page == "home"), onUnits = (ui.page == "units" or ui.page == "unit"), onGuide = (ui.page == "guide"),
    focus = focus, guide = guide, gsel = gsel, gselAfford = gsel.afford, gselNot = not gsel.afford,
    buyText = string.format("Funds %d: you can afford %d of %d unit types", funds, canBuy, #guide),
    ready = true, waiting = false, day = day, funds = funds, turnName = ARMY_NAMES[turn + 1], turnColor = ARMY_COLORS[turn + 1],
    armies = armies, sel = sel, units = sel.list, groups = order, hasUnits = #sel.list > 0,
  }
end

-- the movable navigation: where the buttons sit is the UI key navpos (bottom, left, right, split), chosen on the Options page
local NAV = { { "FRONT", "home" }, { "UNITS", "units" }, { "MAP", "map" }, { "VS", "armies" }, { "GUIDE", "guide" }, { "LOG", "log" }, { "OPT", "options" } }
local NAV_ALIAS = { unit = "units" }
local NAV_WINDOW = 5          -- the bottom bar shows this many buttons; < > page through the rest. The side docks scroll.
local navOffset = 0
local navLastPage
actions = actions or {}
function actions.navShift(d) navOffset = navOffset + (tonumber(d) or 0) end
local function navState(ui)
  local pos = ui.navpos or "bottom"
  local cur = ui.page or "home"
  cur = NAV_ALIAS[cur] or cur
  local out = { posBottom = (pos == "bottom"), posLeft = (pos == "left"), posRight = (pos == "right"), posSplit = (pos == "split") }
  local curIdx = 1
  for i, n in ipairs(NAV) do if n[2] == cur then curIdx = i end end
  local maxOff = math.max(0, #NAV - NAV_WINDOW)
  if tostring(ui.page) ~= tostring(navLastPage) then          -- a new page: bring its button into view
    if curIdx <= navOffset then navOffset = curIdx - 1 elseif curIdx > navOffset + NAV_WINDOW then navOffset = curIdx - NAV_WINDOW end
    navLastPage = ui.page
  end
  navOffset = math.max(0, math.min(maxOff, navOffset))
  out.navMore, out.noPrev, out.noNext = #NAV > NAV_WINDOW, navOffset <= 0, navOffset >= maxOff
  local half = (#NAV + 1) // 2
  local left, right = 0, 0
  for i, n in ipairs(NAV) do
    out["on" .. i] = (n[2] == cur)
    out["B" .. i] = (i > navOffset and i <= navOffset + NAV_WINDOW)
    local l = (pos == "left") or (pos == "split" and i <= half)
    local r = (pos == "right") or (pos == "split" and i > half)
    out["L" .. i], out["R" .. i] = l, r
    if l then left = left + 1 end
    if r then right = right + 1 end
  end
  out.dockL, out.dockR = left > 0, right > 0
  -- the bottom bar cycles: < previous page | this page | next page >
  local pi, ni = (curIdx - 2) % #NAV + 1, curIdx % #NAV + 1
  out.navName = NAV[curIdx][1]
  for i = 1, #NAV do out["P" .. i], out["N" .. i] = (i == pi), (i == ni) end
  return out
end

local lastGood
function update(ui)
  local ok, r = pcall(baseUpdate, ui)
  if ok then lastGood = r else
    if log then log("update error: " .. tostring(r)) end       -- keep showing the last good screen instead of going blank
    r = lastGood
  end
  if r and r.ready then for k, v in pairs(navState(ui)) do r[k] = v end end
  return r
end
