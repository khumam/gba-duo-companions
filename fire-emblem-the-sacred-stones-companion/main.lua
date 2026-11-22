-- Fire Emblem: The Sacred Stones (GBA, USA BE8E) companion: the game's own unit screen (Personal data / Items / Weapon
-- and support level, 1/3 .. 3/3), the army list, the convoy (Supply) and the chapter Status, joined by left / right
-- plates. Names, portraits, mini portraits and item icons are read from the player's ROM at run time.
-- RAM / ROM map and how it was found: NOTES.md.

local CODE = "BE8E"
actions = actions or {}

-- RAM
local UNITS, USTRIDE, NBLUE = 0x0202BE4C, 0x48, 62
local RED, NRED = 0x0202CFBC, 50
local CHAP = 0x0202BCF0          -- +0 play time (frames), +8 funds, +0xE chapter, +0x10 turn, +0x1B mode (2 Eirika, 3 Ephraim)
local CONVOY, NCONVOY = 0x0203A81C, 100
local BATTLE = 0x0203A4EC        -- the battle struct the game fills for the unit on its stat screen / forecast

-- ROM (USA)
local HBASE, HROOTP, TEXT = 0x0815A72C, 0x0815D488, 0x0815D48C
local CHARS, ITEMS = 0x08803D30, 0x08809B10
local PORTRAITS = 0x088ACBC4
local ICONS, ICONPAL, SYMPAL = 0x085926F4, 0x085996F4, 0x08599714   -- items / weapon-type + affinity symbols
local CHAPTERS, CHSTRIDE = 0x088B0890, 0x94

local HIDDEN = "?????????"
local WTYPES = { "Sword", "Lance", "Axe", "Bow", "Staff", "Anima", "Light", "Dark" }
local AFF = { "Fire", "Thunder", "Wind", "Ice", "Dark", "Light", "Anima" }
local COND = { [0] = "---", "Poison", "Sleep", "Silence", "Berserk", "Attack", "Defense", "Critical", "Avoid",
               "Sick", "Recover", "Petrify", "Stone" }

local function rom(a) return a >= 0x08000000 and a < 0x09000000 end

-- ---------------------------------------------------------------- text (the game's Huffman-coded strings)
local ROOT
local tcache = {}
local function text(id, oneLine)
  local key = id * 2 + (oneLine and 1 or 0)
  if tcache[key] then return tcache[key] end
  local p = mem.u32(TEXT + id * 4) & 0x7FFFFFFF
  local out, node, n, done = {}, ROOT, 0, false
  local function put(c)
    if c == 1 then out[#out + 1] = oneLine and " " or "\n"
    elseif c >= 0x20 and c < 0x80 then out[#out + 1] = string.char(c)
    elseif c >= 0x80 then out[#out + 1] = utf8.char(c) end
  end
  while not done and n < 400 do
    local b = mem.u8(p); p = p + 1; n = n + 1
    for k = 0, 7 do
      local off = ((b >> k) & 1) == 1 and mem.u16(node + 2) or mem.u16(node)
      node = HBASE + off * 4
      local v = mem.u32(node)
      if v & 0x80000000 ~= 0 then
        local c = v & 0xFFFF
        if c & 0xFF00 ~= 0 then put(c & 0xFF); put(c >> 8)
        elseif c == 0 then done = true; break
        else put(c) end
        node = ROOT
      end
    end
  end
  local s = table.concat(out):gsub("^%s+", ""):gsub("%s+$", "")
  tcache[key] = s
  return s
end

-- ---------------------------------------------------------------- items
local icache = {}
local function item(id)
  if icache[id] then return icache[id] end
  local r = ITEMS + id * 0x24
  local attr = mem.u32(r + 8)
  local rng = mem.u8(r + 0x19)
  local it = {
    id = id, name = text(mem.u16(r)), type = mem.u8(r + 7), attr = attr,
    weapon = attr & 1 ~= 0, staff = attr & 4 ~= 0, unbreakable = attr & 8 ~= 0,
    uses = mem.u8(r + 0x14), mt = mem.u8(r + 0x15), hit = mem.u8(r + 0x16), wt = mem.u8(r + 0x17),
    crit = mem.u8(r + 0x18), rmin = rng >> 4, rmax = rng & 15, rank = mem.u8(r + 0x1C), icon = mem.u8(r + 0x1D),
  }
  it.rng = (it.rmin == it.rmax) and tostring(it.rmin) or (it.rmin .. "-" .. it.rmax)
  icache[id] = it
  return it
end

local function icon(n)
  return gfx.decode({ tiles = ICONS + n * 0x80, palette = (n >= 0x70 and n < 0x84) and SYMPAL or ICONPAL, width = 16, height = 16 })
end

local function rankLetter(v)
  if v == 0 then return "-" elseif v < 31 then return "E" elseif v < 71 then return "D" elseif v < 121 then return "C"
  elseif v < 181 then return "B" elseif v < 251 then return "A" else return "S" end
end
local RANKS = { 1, 31, 71, 121, 181, 251 }
local function rankBar(v)        -- progress to the next letter, 0..100
  if v == 0 then return 0 end
  if v >= 251 then return 100 end
  for i = 1, #RANKS - 1 do
    if v < RANKS[i + 1] then return math.floor((v - RANKS[i]) * 100 / (RANKS[i + 1] - RANKS[i])) end
  end
  return 100
end

-- ---------------------------------------------------------------- portraits
local function portrait(pid)
  if pid == 0 then return nil end
  local e = PORTRAITS + pid * 0x1C
  local main, mini, pal = mem.u32(e), mem.u32(e + 4), mem.u32(e + 8)
  if not (rom(main) and rom(pal)) then return nil end
  local p = {}
  local lz = mem.u8(main) == 0x10
  local ok, k = pcall(gfx.decode, { tiles = lz and main or main + 4, palette = pal, width = 256, height = 32, lz77 = lz })
  p.sheet = ok and k or nil
  if rom(mini) then
    local ok2, k2 = pcall(gfx.decode, { tiles = mini, palette = pal, width = 32, height = 32, lz77 = mem.u8(mini) == 0x10 })
    p.mini = ok2 and k2 or nil
  end
  return p
end

-- ---------------------------------------------------------------- units
local function s8(v) return v >= 128 and v - 256 or v end

local function readUnit(a)
  local pc = mem.u32(a)
  if not rom(pc) then return nil end
  local st = mem.u32(a + 0xC)
  if st & 0x4 ~= 0 then return nil end           -- dead
  local pk = mem.u32(a + 4)
  local u = { addr = a, pc = pc, pk = pk, state = st, deployed = st & 0xC == 0 }
  u.cid = mem.u8(pc + 4)
  u.name = text(mem.u16(pc))
  u.cls = rom(pk) and text(mem.u16(pk)) or "?"
  u.lv, u.exp = mem.u8(a + 8), mem.u8(a + 9)
  u.mhp, u.hp = mem.u8(a + 0x12), mem.u8(a + 0x13)
  u.str, u.skl, u.spd = mem.u8(a + 0x14), mem.u8(a + 0x15), mem.u8(a + 0x16)
  u.def, u.res, u.lck = mem.u8(a + 0x17), mem.u8(a + 0x18), mem.u8(a + 0x19)
  u.con = (rom(pk) and mem.u8(pk + 0x11) or 0) + s8(mem.u8(pc + 0x13)) + s8(mem.u8(a + 0x1A))
  u.movBase = rom(pk) and mem.u8(pk + 0x12) or 0
  u.movBonus = s8(mem.u8(a + 0x1D))
  u.rescue = mem.u8(a + 0x1B)
  u.cond = mem.u8(a + 0x30) & 0x0F
  u.aff = mem.u8(pc + 9)
  u.pid = mem.u16(pc + 6)
  u.ab = (rom(pk) and mem.u32(pk + 0x28) or 0) | mem.u32(pc + 0x28)
  u.caps = rom(pk) and { mem.u8(pk + 0x13), mem.u8(pk + 0x14), mem.u8(pk + 0x15), mem.u8(pk + 0x16), mem.u8(pk + 0x17),
                         mem.u8(pk + 0x18) } or { 60, 20, 20, 20, 20, 20 }
  u.items = {}
  for s = 0, 4 do
    local v = mem.u16(a + 0x1E + s * 2)
    if v & 0xFF ~= 0 then u.items[#u.items + 1] = { id = v & 0xFF, left = v >> 8, slot = s } end
  end
  u.ranks = {}
  for i = 0, 7 do u.ranks[i + 1] = mem.u8(a + 0x28 + i) end
  return u
end

local function army()
  local list = {}
  for k = 0, NBLUE - 1 do
    local u = readUnit(UNITS + k * USTRIDE)
    if u then u.k = #list + 1; list[#list + 1] = u end
  end
  return list
end

-- first weapon this unit can wield = the equipped one (the game marks it E)
local function equipped(u)
  for _, s in ipairs(u.items) do
    local it = item(s.id)
    if it.weapon and it.type <= 7 and u.ranks[it.type + 1] >= it.rank and u.ranks[it.type + 1] > 0 then return s, it end
  end
  return nil
end

local function battleStats(u)
  local s, w = equipped(u)
  local as = u.spd - math.max(0, (w and w.wt or 0) - u.con)
  local crit = math.floor(u.skl / 2) + (w and w.crit or 0) + ((u.ab & 0x40) ~= 0 and 15 or 0)
  local r = {
    atk = w and (u.str + w.mt) or "--", hit = w and (u.skl * 2 + math.floor(u.lck / 2) + w.hit) or "--",
    avoid = as * 2 + u.lck, crit = w and crit or "--", rng = w and w.rng or "--", fromGame = false,
  }
  -- the game's own numbers (with support and tactician bonuses) when it has this unit in its battle struct
  if mem.u32(BATTLE) == u.pc and w and mem.u16(BATTLE + 0x1E) == mem.u16(u.addr + 0x1E) then
    r.atk, r.hit, r.avoid, r.crit = mem.s16(BATTLE + 0x5A), mem.s16(BATTLE + 0x60), mem.s16(BATTLE + 0x62), mem.s16(BATTLE + 0x66)
    r.fromGame = true
  end
  return r
end

local function aid(u)
  if u.ab & 1 ~= 0 then return ((u.ab & 0x4000) ~= 0 and 20 or 25) - u.con end
  return u.con - 1
end

-- ---------------------------------------------------------------- live alerts
local seenLv, seenCid, primed = {}, {}, false
local toast, tick, toastId = nil, 0, 0

local function watch(list)
  local news
  for _, u in ipairs(list) do
    local old = seenLv[u.cid]
    if primed then
      if old == nil then news = { title = "JOINED THE ARMY", name = u.name, sub = u.cls, k = u.k, pid = u.pid }
      elseif u.lv > old and u.lv - old <= 2 then
        news = { title = "LEVEL UP!", name = u.name, sub = "LV " .. old .. " > " .. u.lv, k = u.k, pid = u.pid }
      end
    end
    seenLv[u.cid] = u.lv
  end
  primed = true
  if news then toastId = toastId + 1; news.id = toastId; news.untilTick = tick + 24; toast = news end
end

-- ---------------------------------------------------------------- pages
local function clamp(v, lo, hi) v = tonumber(v) or lo; if v < lo then return lo elseif v > hi then return hi end return v end

local function unitRow(u, sel)
  local p = portrait(u.pid)
  return { k = u.k, name = u.name, lv = "LV " .. u.lv, hp = u.hp .. "/" .. u.mhp, mini = p and p.mini or "",
           hasMini = p and p.mini ~= nil, sel = u.k == sel, off = not u.deployed }
end

local function head(u, out)
  local p = portrait(u.pid) or {}
  out.u = { name = u.name, cls = u.cls, lv = tostring(u.lv), exp = u.exp == 255 and "--" or string.format("%02d", u.exp),
            hp = u.hp .. "/" .. u.mhp, sheet = p.sheet or "", hasSheet = p.sheet ~= nil,
            pos = u.k .. " / ", k = u.k }
end

local STATROWS = { { "Str", "str", 2 }, { "Skill", "skl", 3 }, { "Spd", "spd", 4 }, { "Luck", "lck", 0 },
                   { "Def", "def", 5 }, { "Res", "res", 6 } }

local function personal(u, list)
  local rows = {}
  for _, r in ipairs(STATROWS) do
    local v = u[r[2]]
    local cap = r[3] == 0 and 30 or u.caps[r[3]]
    rows[#rows + 1] = { label = r[1], value = tostring(v), pct = string.format("%d%%", math.min(100, math.floor(v * 100 / math.max(cap, 1)))),
                        max = v >= cap }
  end
  local trv = "---"
  if u.rescue ~= 0 then
    for _, o in ipairs(list) do if mem.u8(o.addr + 0xB) == u.rescue then trv = o.name end end
  end
  return {
    rows = rows,
    move = tostring(u.movBase), moveBonus = u.movBonus > 0 and ("+" .. u.movBonus) or "", con = tostring(u.con),
    aid = tostring(aid(u)), trv = trv, affin = AFF[u.aff] or "---", affIcon = u.aff > 0 and icon(0x79 + u.aff) or "",
    hasAff = u.aff > 0 and u.aff <= 7, cond = COND[u.cond] or "---",
  }
end

local function itemsPage(u, ui)
  local s, w = equipped(u)
  local rows = {}
  local sel = clamp(ui.slot, 0, 4)
  for i, e in ipairs(u.items) do
    local it = item(e.id)
    local healer = it.name == "Vulnerary" or it.name == "Elixir"
    rows[#rows + 1] = { slot = e.slot, name = it.name, icon = icon(it.icon),
                        uses = it.unbreakable and "--" or (e.left .. "/" .. it.uses), eq = s ~= nil and s.slot == e.slot,
                        sel = e.slot == sel, canEquip = it.weapon and not (s and s.slot == e.slot) and it.type <= 7 and u.ranks[it.type + 1] >= it.rank,
                        canUse = healer and u.hp < u.mhp }
  end
  local b = battleStats(u)
  local selRow
  for _, r in ipairs(rows) do if r.sel then selRow = r end end
  return {
    rows = rows, empty = #rows == 0, full = #u.items >= 5,
    atk = tostring(b.atk), hit = tostring(b.hit), avoid = tostring(b.avoid), crit = tostring(b.crit), rng = tostring(b.rng),
    source = b.fromGame and "As the game shows" or "Before support bonuses",
    selName = selRow and selRow.name or "Tap an item", hasSel = selRow ~= nil, selSlot = selRow and selRow.slot or -1,
    canEquip = selRow ~= nil and selRow.canEquip, canUse = selRow ~= nil and selRow.canUse,
  }
end

local function weaponsPage(u, list)
  local ranks = {}
  for n, i in ipairs({ 1, 3, 2, 4, 5, 6, 7, 8 }) do   -- the game's order: Sword Axe / Lance Bow, then staff and magic
    ranks[n] = { icon = icon(0x6F + i), letter = rankLetter(u.ranks[i]), pct = rankBar(u.ranks[i]) .. "%",
                 has = u.ranks[i] > 0, none = u.ranks[i] == 0, s = u.ranks[i] >= 251 }
  end
  local sups = {}
  local sp = mem.u32(u.pc + 0x2C)
  if rom(sp) then
    local n = math.min(mem.u8(sp + 0x15), 7)
    local inArmy = {}
    for _, o in ipairs(list) do inArmy[o.cid] = o end
    for i = 0, n - 1 do
      local cid = mem.u8(sp + i)
      local pts = mem.u8(u.addr + 0x32 + i)
      local partner = inArmy[cid]
      local lvl = pts >= 241 and "A" or pts >= 161 and "B" or pts >= 81 and "C" or "-"
      local nextAt = pts >= 241 and 241 or pts >= 161 and 241 or pts >= 81 and 161 or 81
      local base = pts >= 161 and 161 or pts >= 81 and 81 or 0
      local paff = partner and partner.aff or 0
      sups[#sups + 1] = {
        name = partner and partner.name or HIDDEN, level = lvl, known = partner ~= nil, unknown = partner == nil,
        pct = (pts >= 241 and 100 or math.floor((pts - base) * 100 / (nextAt - base))) .. "%",
        aff = (paff > 0 and paff <= 7) and icon(0x79 + paff) or "", hasAff = paff > 0 and paff <= 7, got = lvl ~= "-",
      }
    end
  end
  return { ranks = ranks, sups = sups, noSup = #sups == 0 }
end

local TABS = { "All", "Sword", "Lance", "Axe", "Bow", "Staff", "Anima", "Light", "Dark", "Item" }
local PERPAGE = 12

local function supplyPage(ui, u)
  local tab = clamp(ui.tab, 1, #TABS)
  local all, n = {}, 0
  for i = 0, NCONVOY - 1 do
    local v = mem.u16(CONVOY + i * 2)
    if v & 0xFF == 0 then break end
    n = n + 1
    local it = item(v & 0xFF)
    local t = it.type <= 7 and it.type + 2 or 10
    if tab == 1 or t == tab then
      all[#all + 1] = { ci = i, name = it.name, icon = icon(it.icon), uses = it.unbreakable and "--" or ((v >> 8) .. "/" .. it.uses) }
    end
  end
  local pages = math.max(1, math.ceil(#all / PERPAGE))
  local pg = clamp(ui.cpage, 1, pages)
  local rows = {}
  local sel = tonumber(ui.cv) or -1
  local selName
  for i = (pg - 1) * PERPAGE + 1, math.min(#all, pg * PERPAGE) do
    local r = all[i]; r.sel = r.ci == sel
    if r.sel then selName = r.name end
    rows[#rows + 1] = r
  end
  local tabs = {}
  for i, t in ipairs(TABS) do
    tabs[i] = { i = i, sel = i == tab, icon = (i >= 2 and i <= 9) and icon(0x6E + i) or "", hasIcon = i >= 2 and i <= 9,
                noIcon = not (i >= 2 and i <= 9), label = t }
  end
  return { rows = rows, tabs = tabs, tabName = TABS[tab], count = n .. "/" .. NCONVOY, page = pg .. "/" .. pages,
           prev = math.max(1, pg - 1), next = math.min(pages, pg + 1), empty = #rows == 0,
           selName = selName or "Tap an item to give it", selCi = sel, canGive = selName ~= nil and u ~= nil and #u.items < 5,
           unitName = u and u.name or "", unitFull = u ~= nil and #u.items >= 5 }
end

local function statusPage(list)
  local chap = mem.u8(CHAP + 0xE)
  local mode = mem.u8(CHAP + 0x1B)
  local ce = CHAPTERS + chap * CHSTRIDE
  local title = text(mem.u16(ce + (mode == 3 and 0x72 or 0x70)))
  local goal = text(mem.u16(ce + 0x88))
  local player, enemy = 0, 0
  for _, u in ipairs(list) do if u.deployed then player = player + 1 end end
  for k = 0, NRED - 1 do
    local a = RED + k * USTRIDE
    if rom(mem.u32(a)) and mem.u32(a + 0xC) & 0xD == 0 then enemy = enemy + 1 end
  end
  local t = mem.u32(CHAP) // 60
  -- the route's lord leads (class ability 0x10000000 / 0x20000000 / 0x40000000 = mode 2 / 3 / 1)
  local lordBit = ({ [1] = 0x40000000, [2] = 0x10000000, [3] = 0x20000000 })[mode] or 0
  local lead = list[1]
  for _, u in ipairs(list) do if lordBit ~= 0 and (u.ab & lordBit) ~= 0 then lead = u; break end end
  local lp = lead and portrait(lead.pid) or {}
  return {
    title = title, goal = goal, turn = tostring(math.max(1, mem.u16(CHAP + 0x10))), funds = tostring(mem.u32(CHAP + 8)),
    player = tostring(player), enemy = tostring(enemy),
    time = string.format("%d:%02d:%02d", t // 3600, (t // 60) % 60, t % 60),
    mode = mode == 3 and "Ephraim's route" or mode == 2 and "Eirika's route" or "Prologue",
    lead = lead and lead.name or "", leadLv = lead and tostring(lead.lv) or "", leadHp = lead and (lead.hp .. "/" .. lead.mhp) or "",
    leadMini = lp.mini or "", hasLead = lp.mini ~= nil,
    army = tostring(#list),
  }
end

-- ---------------------------------------------------------------- update
function init()
  ROOT = mem.u32(HROOTP)
end

function update(ui)
  tick = tick + 1
  if mem.read(0x080000AC, 4) ~= CODE then
    return { ready = false, waiting = true, wrongRom = mem.u32(0x08000000) ~= 0 }
  end
  local list = army()
  if #list == 0 then return { ready = false, waiting = true, wrongRom = false } end
  watch(list)

  local sel = clamp(ui.unit, 1, #list)
  local u = list[sel]
  local out = { ready = true, waiting = false }
  out.note = ui.note or ""
  out.hasNote = out.note ~= ""
  head(u, out)
  out.u.pos = sel .. " / " .. #list
  out.prevUnit = sel > 1 and sel - 1 or #list
  out.nextUnit = sel < #list and sel + 1 or 1

  -- army list, 16 per page like the game's paged unit list
  local per = 12
  local pages = math.max(1, math.ceil(#list / per))
  local up = clamp(ui.upage or math.ceil(sel / per), 1, pages)
  local rows = {}
  for i = (up - 1) * per + 1, math.min(#list, up * per) do rows[#rows + 1] = unitRow(list[i], sel) end
  out.army = { rows = rows, page = up .. "/" .. pages, prev = up > 1 and up - 1 or pages, next = up < pages and up + 1 or 1,
               count = #list .. " units" }

  out.pd = personal(u, list)
  out.it = itemsPage(u, ui)
  out.wp = weaponsPage(u, list)
  out.sup = supplyPage(ui, u)
  out.st = statusPage(list)

  local on = toast ~= nil and tick < toast.untilTick and (tonumber(ui.toastHide) or -1) ~= toast.id
  out.toastOn = on
  local tp = toast and portrait(toast.pid) or {}
  out.toast = toast and { id = toast.id, title = toast.title, name = toast.name, sub = toast.sub, k = toast.k,
                          mini = tp.mini or "", hasMini = tp.mini ~= nil }
              or { id = 0, title = "", name = "", sub = "", k = 1, mini = "", hasMini = false }
  return out
end

-- ---------------------------------------------------------------- actions (memory-write, from taps only)
local function writeItems(u, entries)
  local bytes = {}
  for s = 1, 5 do
    local e = entries[s]
    local v = e and (e.id | (e.left << 8)) or 0
    bytes[#bytes + 1] = string.char(v & 0xFF, v >> 8)
  end
  return mem.write(u.addr + 0x1E, table.concat(bytes))
end

local function result(ok, why, okText)
  if ok then return { set = { note = okText } } end
  return { set = { note = "Not changed: " .. tostring(why or "refused") } }
end

local function pick(k)
  local list = army()
  return list[clamp(k, 1, #list)]
end

-- Equip: the game equips by moving the weapon to the top of the list.
function actions.equip(k, slot)
  local u = pick(k)
  if not u then return end
  local entries, chosen = {}, nil
  for _, e in ipairs(u.items) do if e.slot == tonumber(slot) then chosen = e else entries[#entries + 1] = e end end
  if not chosen then return { set = { note = "No item there." } } end
  table.insert(entries, 1, chosen)
  local ok, why = writeItems(u, entries)
  return { set = { note = ok and (u.name .. " equipped " .. item(chosen.id).name .. ".") or ("Not changed: " .. tostring(why)),
                   slot = 0 } }
end

-- Use a Vulnerary (+10 HP) or an Elixir (full HP), as the Item command does.
function actions.use(k, slot)
  local u = pick(k)
  if not u then return end
  local entries, target = {}, nil
  for _, e in ipairs(u.items) do entries[#entries + 1] = { id = e.id, left = e.left, slot = e.slot }; if e.slot == tonumber(slot) then target = entries[#entries] end end
  if not target then return { set = { note = "No item there." } } end
  local it = item(target.id)
  if it.name ~= "Vulnerary" and it.name ~= "Elixir" then return { set = { note = it.name .. " can't be used here." } } end
  if u.hp >= u.mhp then return { set = { note = u.name .. "'s HP is full." } } end
  local heal = it.name == "Elixir" and u.mhp or 10
  local hp = math.min(u.mhp, u.hp + heal)
  target.left = target.left - 1
  if target.left <= 0 then
    for i, e in ipairs(entries) do if e == target then table.remove(entries, i); break end end
  end
  local ok, why = mem.write8(u.addr + 0x13, hp)
  if ok then ok, why = writeItems(u, entries) end
  return result(ok, why, u.name .. " recovered " .. (hp - u.hp) .. " HP.")
end

-- Store: send the item to the convoy (Supply), the way Merlinus takes it.
function actions.store(k, slot)
  local u = pick(k)
  if not u then return end
  local free
  for i = 0, NCONVOY - 1 do if mem.u16(CONVOY + i * 2) & 0xFF == 0 then free = i; break end end
  if not free then return { set = { note = "The convoy is full." } } end
  local entries, moved = {}, nil
  for _, e in ipairs(u.items) do if e.slot == tonumber(slot) then moved = e else entries[#entries + 1] = e end end
  if not moved then return { set = { note = "No item there." } } end
  local ok, why = mem.write16(CONVOY + free * 2, moved.id | (moved.left << 8))
  if ok then ok, why = writeItems(u, entries) end
  return { set = { note = ok and (item(moved.id).name .. " sent to the convoy.") or ("Not changed: " .. tostring(why)), slot = -1 } }
end

-- Give: take an item out of the convoy for the selected unit.
function actions.give(k, ci)
  local u = pick(k)
  if not u then return end
  ci = tonumber(ci) or -1
  if #u.items >= 5 then return { set = { note = u.name .. " can't carry more." } } end
  local v = mem.u16(CONVOY + ci * 2)
  if ci < 0 or v & 0xFF == 0 then return { set = { note = "Pick an item first." } } end
  local entries = {}
  for _, e in ipairs(u.items) do entries[#entries + 1] = e end
  entries[#entries + 1] = { id = v & 0xFF, left = v >> 8 }
  local ok, why = writeItems(u, entries)
  if ok then
    -- close the gap in the convoy
    local rest = {}
    for i = ci + 1, NCONVOY - 1 do
      local w = mem.u16(CONVOY + i * 2)
      if w & 0xFF == 0 then break end
      rest[#rest + 1] = string.char(w & 0xFF, w >> 8)
    end
    rest[#rest + 1] = "\0\0"
    local blob = table.concat(rest)
    local pos = 0
    while ok and pos < #blob do
      local chunk = blob:sub(pos + 1, pos + 64)
      ok, why = mem.write(CONVOY + ci * 2 + pos, chunk)
      pos = pos + #chunk
    end
  end
  return { set = { note = ok and (u.name .. " received " .. item(v & 0xFF).name .. ".") or ("Not changed: " .. tostring(why)), cv = -1 } }
end
