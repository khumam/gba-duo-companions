-- Final Fantasy Tactics Advance (USA, AFXE) companion: the clan roster.
-- Addresses found with a headless mGBA run on the real ROM and a save state; see NOTES.md.

local GAME     = "AFXE"
local ROSTER   = 0x02000098     -- clan roster: 20 records of 0x108 bytes, the first field is the HP
local STRIDE   = 0x108
local COUNT    = 20
local JOBS     = 0x08521A14     -- job table in the ROM: 52 bytes per job id; byte 0 is the name number, byte 4 the race
local JOB_SIZE = 52
local NAMES    = 0x08526680     -- pointers to the names (jobs, items, ...), by name number
local ITEMS    = 0x0851D190     -- item table in the ROM: 32 bytes per item id; bytes 0-4 are the Atk, Def, Pow, Res and Speed it adds
local ITEM_SIZE = 32
local JOB_MOVE = 40            -- in a job's 52 bytes: Move, Jump, Evade (the items add to them: item bytes 6, 7, 5)
local NAMES2   = 0x085567F0     -- the second name table (767 entries): skill sets, abilities, combos
local SKILLSETS = 0x08527244    -- skill set id -> 4 bytes: u16 name number (in NAMES2), u16 other
local ABILITIES = 0x0851BB64    -- ability id -> 8 bytes: u16 name number, ..., byte 6 the kind (1 action, 2 reaction, 3 support, 5 combo), byte 7 the AP cost
local ABIL_BASE = { 0, 142, 219, 314, 399 }   -- a unit's reaction/support/combo byte is relative to its race's block in the ability table (Hume, Bangaa, Nu Mou, Viera, Moogle)
local EQUIP_SETS, EQUIP_REACT, EQUIP_SUPPORT, EQUIP_COMBO = { 0x1D, 0x1E }, 0x22, 0x23, 0x24   -- in a unit's record: what the Abilities screen shows
local LAWS = 0x08528F30        -- law table: 16 bytes per law id, byte 5 is the paired (Recommend) law; the name of law N is name number 625 + N
local LAW_NAME, LAW_MAX = 625, 82
local BATTLE_LAWS = 0x02003C34  -- the day's three laws: u16 law ids (Forbidden row, with its pair beside it)
local FOES = 0x02002FDC         -- the enemy units of a battle: records like the clan roster's, same 0x108 size
local FOE_COUNT = 8
local JP_OFF = 0xBE            -- in a unit's record: the u16 behind the JP on the status screen (shows the last two digits, a star from 100)
local ITEM_NAME = 123           -- the name number of an item is its id + 123
local ITEM_MAX  = 422           -- the highest item id that is equipment (the ids above it are other data)
local SLOTS     = 5             -- equipment slots in a unit's record (u16 item ids from +0x12; 0 is empty)

local RACES = { "Hume", "Bangaa", "Nu Mou", "Viera", "Moogle" }
local RACE_COLOR = { "#f2c14e", "#e2724a", "#9a8cf0", "#7fe08a", "#ff9fb8" }

-- The game's text: names start with 0x01 and use A = 0xB1, a = 0xCB; job names in the other font have no prefix and
-- use A = 0xB0, a = 0xCA, with 0x40 0x73 for the space. A 0 ends the text.
local function text(p)
  local first = mem.u8(p)
  local alt = first ~= 1
  local capA, smallA = alt and 0xB0 or 0xB1, alt and 0xCA or 0xCB
  local t, i = {}, (first == 1) and 1 or 0
  for _ = 1, 48 do        -- an ability name takes two bytes a letter
    local b = mem.u8(p + i)
    if b == 0 then break end
    if b >= smallA and b < smallA + 26 then t[#t + 1] = string.char(97 + b - smallA)
    elseif b >= capA and b < capA + 26 then t[#t + 1] = string.char(65 + b - capA)
    elseif b == 0xAF and not alt then t[#t + 1] = " "
    elseif b == 0x40 and mem.u8(p + i + 1) == 0x73 then t[#t + 1] = " "; i = i + 1
    elseif b == 0x40 and mem.u8(p + i + 1) == 0x3E then t[#t + 1] = " "; i = i + 2
    elseif b == 0xEE then t[#t + 1] = ":"
    elseif b == 0xFD then t[#t + 1] = "+"
    elseif b == 0xF1 then t[#t + 1] = "/"
    elseif b >= 0xA6 and (b <= 0xAE or (alt and b == 0xAF)) then t[#t + 1] = string.char(48 + b - 0xA6)
    elseif b == 0x81 then local n = mem.u8(p + i + 1); t[#t + 1] = (n == 3) and ">" or ((n == 2) and "<" or "?"); i = i + 1
    elseif b == 0xFF then t[#t + 1] = "-"
    elseif b == 0x80 then -- a prefix before a letter, skipped
    else t[#t + 1] = "?" end
    i = i + 1
  end
  return table.concat(t)
end

local function readable(p) return (p >= 0x02000000 and p < 0x02040000) or (p >= 0x08000000 and p < 0x0A000000) end

local jobCache = {}
local function job(id)
  local j = jobCache[id]
  if j then return j end
  local rec = JOBS + JOB_SIZE * id
  local p = mem.u32(NAMES + 4 * mem.u8(rec))
  local race = mem.u8(rec + 4)
  j = { name = (p >= 0x08000000 and p < 0x0A000000) and text(p) or "", race = race,
        move = mem.u8(rec + JOB_MOVE), jump = mem.u8(rec + JOB_MOVE + 1), evade = mem.u8(rec + JOB_MOVE + 2) }
  if j.name ~= "" then jobCache[id] = j end
  return j
end

-- a unit's equipment: { name, id } per filled slot, and what the items add to Atk, Def, Pow, Res and Speed
local itemNames = {}
local function itemName(id)
  local n = itemNames[id]
  if n then return n end
  local p = mem.u32(NAMES + 4 * (id + ITEM_NAME))
  n = (p >= 0x08000000 and p < 0x0A000000) and text(p) or ""
  if n ~= "" then itemNames[id] = n end
  return n
end

-- what a unit has equipped: two skill sets, a reaction, a support and a combo ability (0 = empty)
local abilNames = {}
local function nameAt(n)
  local p = mem.u32(NAMES2 + 4 * n)
  return (p >= 0x08000000 and p < 0x0A000000) and text(p) or ""
end
local function setName(id)
  local k = "s" .. id
  if abilNames[k] == nil then abilNames[k] = (id ~= 0) and nameAt(mem.u16(SKILLSETS + 4 * id)) or "" end
  return abilNames[k]
end
local function abilityName(id)
  local k = "a" .. id
  if abilNames[k] == nil then abilNames[k] = (id ~= 0) and nameAt(mem.u16(ABILITIES + 8 * id)) or "" end
  return abilNames[k]
end
local KIND_LABEL = { "SKILLS", "SKILLS", "REACTION", "SUPPORT", "COMBO" }
local function abilitiesOf(a, race)
  local list = {}
  for i, off in ipairs(EQUIP_SETS) do
    local id = mem.u8(a + off)
    list[#list + 1] = { kind = KIND_LABEL[i], name = setName(id), ap = "", has = id ~= 0 }
  end
  for i, off in ipairs({ EQUIP_REACT, EQUIP_SUPPORT, EQUIP_COMBO }) do
    local byte = mem.u8(a + off)
    local id = (byte ~= 0) and (byte + (ABIL_BASE[race] or 0)) or 0
    local ap = (id ~= 0) and mem.u8(ABILITIES + 8 * id + 7) or 0
    list[#list + 1] = { kind = KIND_LABEL[i + 2], name = abilityName(id), ap = (ap > 0) and (ap .. " AP") or "", has = id ~= 0 }
  end
  for _, e in ipairs(list) do if e.name == "" then e.name = "-" end end
  return list
end

local function gearOf(a)
  local add, list = { 0, 0, 0, 0, 0, 0, 0, 0 }, {}
  for k = 0, SLOTS - 1 do
    local id = mem.u16(a + 0x12 + 2 * k)
    if id ~= 0 and id <= ITEM_MAX then
      local rec = ITEMS + ITEM_SIZE * id
      for f = 1, 8 do add[f] = add[f] + mem.u8(rec + f - 1) end     -- 6 evade, 7 move, 8 jump
      list[#list + 1] = { name = itemName(id), id = id }
    end
  end
  return add, list
end

local function unitAt(a, i)
  local hp, maxHp, mp, maxMp = mem.u16(a), mem.u16(a + 2), mem.u16(a + 4), mem.u16(a + 6)
  local level = mem.u8(a - 0x0F)
  if maxHp == 0 or maxHp > 999 or hp > maxHp or maxMp > 999 or mp > maxMp or level < 1 or level > 99 then return nil end
  local np = mem.u32(a - 0x18)
  local name = readable(np) and text(np) or ""
  if name == "" then name = "Unit " .. (i + 1) end
  local jb = job(mem.u8(a - 0x11))
  local race = RACES[jb.race] or "?"
  local add, gear = gearOf(a)
  local function total(v, extra) return math.min(999, v + extra) end   -- the game shows at most 999
  return {
    idx = i, name = name, job = (jb.name ~= "") and jb.name or "?", race = race, raceColor = RACE_COLOR[jb.race] or "#cccccc",
    level = level, exp = mem.u8(a - 0x0E),
    hp = hp, maxHp = maxHp, hpPct = hp / maxHp, mp = mp, maxMp = maxMp, mpPct = (maxMp > 0) and (mp / maxMp) or 0,
    atk = total(mem.u16(a + 8), add[1]), def = total(mem.u16(a + 10), add[2]), pow = total(mem.u16(a + 12), add[3]), res = total(mem.u16(a + 14), add[4]),
    speed = total(mem.u16(a + 0xBA), add[5]), gear = gear,
    abil = abilitiesOf(a, jb.race),
    move = jb.move + add[7], jump = jb.jump + add[8], evade = jb.evade + add[6],
    jp = mem.u16(a + JP_OFF) % 100, jpText = string.format("%d%s", mem.u16(a + JP_OFF) % 100, (mem.u16(a + JP_OFF) >= 100) and " *" or ""), hasGear = #gear > 0, gearCount = #gear,
  }
end

local function unit(i) return unitAt(ROSTER + STRIDE * i, i) end

-- a law's name; 0 and the ids past the last law are empty
local function lawName(id)
  if id < 1 or id > LAW_MAX then return "-" end
  local p = mem.u32(NAMES + 4 * (LAW_NAME + id))
  local n = (p >= 0x08000000 and p < 0x0A000000) and text(p) or ""
  return (n ~= "") and n or "-"
end

-- the battle: the enemy units and the day's laws; empty when no battle is running
local function battleInfo()
  local foes = {}
  for i = 0, FOE_COUNT - 1 do
    local u = unitAt(FOES + STRIDE * i, i)
    if u then
      u.statLine = string.format("Atk %d  Def %d  Pow %d  Res %d  Spd %d", u.atk, u.def, u.pow, u.res, u.speed)
      u.moveLine = string.format("Mv %d  Jp %d  Ev %d", u.move, u.jump, u.evade)
      u.hpText = string.format("%d / %d", u.hp, u.maxHp)
      u.mpText = string.format("%d / %d", u.mp, u.maxMp)
      foes[#foes + 1] = u
    end
  end
  local laws = {}
  for k = 0, 2 do
    local id = mem.u16(BATTLE_LAWS + 2 * k)
    if id >= 1 and id <= LAW_MAX then
      local pair = mem.u8(LAWS + 16 * id + 5)
      laws[#laws + 1] = { forbid = lawName(id), rec = lawName(pair), id = id }
    end
  end
  return foes, laws
end

local SORTS = { { key = "lv", label = "Level" }, { key = "hp", label = "HP" }, { key = "mp", label = "MP" }, { key = "name", label = "Name" } }
local sortMode = 1
actions = actions or {}
function actions.cycleSort() sortMode = sortMode % #SORTS + 1 end

local function pct(v) return math.min(1, v / 700) end

-- the player jobs in the ROM's job table (race 1..5), by job id
local jobList
local function allJobs()
  if jobList then return jobList end
  jobList = {}
  for id = 2, 60 do
    local rec = JOBS + JOB_SIZE * id
    local race = mem.u8(rec + 4)
    if race >= 1 and race <= 5 then
      local j = job(id)
      if j.name ~= "" then jobList[#jobList + 1] = { id = id, name = j.name, race = RACES[race], raceNo = race, raceColor = RACE_COLOR[race] } end
    end
  end
  return jobList
end

local function baseUpdate(ui)
  if mem.read(0x080000AC, 4) ~= GAME then return { ready = false, waiting = true } end
  local all = {}
  for i = 0, COUNT - 1 do
    local u = unit(i)
    if u then all[#all + 1] = u end
  end
  if #all == 0 then return { ready = false, waiting = true } end

  -- the clan summary and the race filter
  local raceCount, lvSum = { 0, 0, 0, 0, 0 }, 0
  for _, u in ipairs(all) do
    lvSum = lvSum + u.level
    for r = 1, 5 do if RACES[r] == u.race then raceCount[r] = raceCount[r] + 1 end end
  end
  local filter = tonumber(ui.race) or 0
  local tabs = { { r = 0, name = "All", short = "All", n = #all, color = "#ffffef", on = (filter == 0) } }
  for r = 1, 5 do
    if raceCount[r] > 0 then tabs[#tabs + 1] = { r = r, name = RACES[r], short = (RACES[r] == "Nu Mou") and "Nu" or string.sub(RACES[r], 1, 3), n = raceCount[r], color = RACE_COLOR[r], on = (filter == r) } end
  end
  local units = {}
  for _, u in ipairs(all) do
    if filter == 0 or RACES[filter] == u.race then units[#units + 1] = u end
  end
  if #units == 0 then units = all; filter = 0 end
  local key = SORTS[sortMode].key
  table.sort(units, function(a, b)
    if key == "name" then return a.name < b.name end
    local av, bv = (key == "lv") and a.level or ((key == "hp") and a.maxHp or a.maxMp), (key == "lv") and b.level or ((key == "hp") and b.maxHp or b.maxMp)
    if av ~= bv then return av > bv end
    return a.idx < b.idx
  end)

  local chosen = tonumber(ui.unit) or units[1].idx
  local pos = 1
  for k, u in ipairs(units) do if u.idx == chosen then pos = k end end
  local sel = units[pos]
  for _, u in ipairs(units) do u.on = (u.idx == sel.idx) end
  sel.atkPct, sel.defPct, sel.powPct, sel.resPct, sel.spdPct = pct(sel.atk), pct(sel.def), pct(sel.pow), pct(sel.res), pct(sel.speed)

  -- the jobs: how many of the clan have each, and who
  local jobs, pickJob = {}, tonumber(ui.job)
  local owners = {}
  for _, u in ipairs(all) do local k = u.job .. "|" .. u.race; owners[k] = owners[k] or {}; table.insert(owners[k], u.name) end
  for _, j in ipairs(allJobs()) do
    local who = owners[j.name .. "|" .. j.race]
    jobs[#jobs + 1] = { id = j.id, name = j.name, race = j.race, raceColor = j.raceColor, n = who and #who or 0, has = who ~= nil,
      who = who and table.concat(who, ", ") or "nobody yet", on = (j.id == pickJob) }
  end
  local jsel = jobs[1]
  for _, j in ipairs(jobs) do if j.on then jsel = j end end
  jsel.on = true

  -- top: the clan ranked by one stat
  local STATS = { { k = "atk", n = "Atk" }, { k = "def", n = "Def" }, { k = "pow", n = "Pow" }, { k = "res", n = "Res" }, { k = "speed", n = "Spd" }, { k = "maxHp", n = "HP" }, { k = "maxMp", n = "MP" } }
  local statKey = ui.stat or "atk"
  local statTabs = {}
  for _, d in ipairs(STATS) do statTabs[#statTabs + 1] = { k = d.k, name = d.n, on = (d.k == statKey) } end
  local ranked = {}
  for _, u in ipairs(all) do ranked[#ranked + 1] = u end
  table.sort(ranked, function(a, b) if a[statKey] ~= b[statKey] then return a[statKey] > b[statKey] end return a.idx < b.idx end)
  local top, topMax = {}, ranked[1][statKey]
  for r = 1, math.min(8, #ranked) do
    local u = ranked[r]
    top[#top + 1] = { idx = u.idx, rank = r, name = u.name, job = u.job, race = u.race, raceColor = u.raceColor, value = u[statKey], pct = u[statKey] / topMax }
  end

  -- compare: two units side by side
  local function byIdx(i) for _, u in ipairs(all) do if u.idx == i then return u end end return all[1] end
  local ia, ib = tonumber(ui.cmpA) or all[1].idx, tonumber(ui.cmpB) or (all[2] or all[1]).idx
  local A, B = byIdx(ia), byIdx(ib)
  local function step(i, d) local p = 1 for k, u in ipairs(all) do if u.idx == i then p = k end end return all[(p - 1 + d) % #all + 1].idx end
  local rows = {}
  for _, d in ipairs({ { "Level", "level" }, { "HP", "maxHp" }, { "MP", "maxMp" }, { "Weapon Atk", "atk" }, { "Def", "def" }, { "Magic Pow", "pow" }, { "Res", "res" }, { "Speed", "speed" }, { "Move", "move" }, { "Jump", "jump" }, { "Evade", "evade" } }) do
    local a, b = A[d[2]], B[d[2]]
    rows[#rows + 1] = { label = d[1], a = a, b = b, aWin = a > b, bWin = b > a, diff = (a == b) and "=" or string.format("%+d", a - b) }
  end

  -- stats: the clan by race and by level
  local raceBars, levelBars = {}, {}
  for r = 1, 5 do
    if raceCount[r] > 0 then raceBars[#raceBars + 1] = { name = RACES[r], n = raceCount[r], pct = raceCount[r] / #all, color = RACE_COLOR[r] } end
  end
  local buckets, lo, hi = {}, 99, 0
  for _, u in ipairs(all) do buckets[u.level] = (buckets[u.level] or 0) + 1; lo = math.min(lo, u.level); hi = math.max(hi, u.level) end
  local most = 1
  for _, c in pairs(buckets) do most = math.max(most, c) end
  for lv = lo, hi do levelBars[#levelBars + 1] = { name = "Lv " .. lv, n = buckets[lv] or 0, pct = (buckets[lv] or 0) / most } end
  local sums = { atk = 0, def = 0, pow = 0, res = 0, speed = 0, maxHp = 0, maxMp = 0 }
  for _, u in ipairs(all) do for k in pairs(sums) do sums[k] = sums[k] + u[k] end end
  local avg = {}
  for _, d in ipairs(STATS) do avg[#avg + 1] = { name = d.n, v = sums[d.k] // #all, pct = pct(sums[d.k] // #all) } end

  local foes, laws = battleInfo()
  local inBattle = #foes > 0
  return {
    foes = foes, laws = laws, inBattle = inBattle, noBattle = not inBattle, hasLaws = #laws > 0,
    battleNote = inBattle and string.format("%d foes", #foes) or "no battle running",
    statTabs = statTabs, top = top, topName = ({ atk = "Weapon Atk", def = "Defence", pow = "Magic Pow", res = "Resistance", speed = "Speed", maxHp = "Max HP", maxMp = "Max MP" })[statKey],
    A = A, B = B, cmp = rows, prevA = step(A.idx, -1), nextA = step(A.idx, 1), prevB = step(B.idx, -1), nextB = step(B.idx, 1),
    raceBars = raceBars, levelBars = levelBars, avg = avg,
    onTop = (ui.page == "top"), onCmp = (ui.page == "compare"), onStats = (ui.page == "stats"), onBattle = (ui.page == "battle"),
    ready = true, waiting = false, units = units, count = #units, sel = sel, tabs = tabs, total = #all,
    sortLabel = SORTS[sortMode].label, avgLevel = string.format("%.1f", lvSum / #all),
    prevIdx = units[(pos - 2) % #units + 1].idx, nextIdx = units[pos % #units + 1].idx,
    place = string.format("%d / %d", pos, #units), jobs = jobs, jsel = jsel,
    onClan = (ui.page == nil or ui.page == "clan"), onUnit = (ui.page == "unit"), onJobs = (ui.page == "jobs"),
  }
end

-- the movable navigation: where the buttons sit is the UI key navpos (bottom, left, right, split), chosen on the Options page
local NAV = { { "CLAN", "clan" }, { "UNIT", "unit" }, { "SKILL", "skills" }, { "TOP", "top" }, { "VS", "compare" }, { "FOES", "battle" }, { "JOBS", "jobs" }, { "STATS", "stats" }, { "OPT", "options" } }
local NAV_ALIAS = {  }
local NAV_WINDOW = 5          -- the bottom bar shows this many buttons; < > page through the rest. The side docks scroll.
local navOffset = 0
local navLastPage
actions = actions or {}
function actions.navShift(d) navOffset = navOffset + (tonumber(d) or 0) end
local function navState(ui)
  local pos = ui.navpos or "bottom"
  local cur = ui.page or "clan"
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
