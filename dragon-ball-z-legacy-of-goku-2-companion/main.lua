-- Dragon Ball Z: The Legacy of Goku II (USA, ALFE) companion.
-- Addresses were found with a headless mGBA run on the real ROM and a save at East District 439;
-- see NOTES.md for how, and for what is still open (techniques, options).

local GAME      = "ALFE"
local CHARS     = 0x03000E9C   -- six character structs, 0x1C bytes apart (Gohan, Piccolo, Vegeta, Trunks, Goku, Hercule)
local STRIDE    = 0x1C
local INV       = 0x03000FBC   -- inventory: one byte per slot, 45 slots
local QDONE     = 0x03000F9A   -- finished quests, one bit per quest, most significant bit first
local ITAB      = 0x080E2930   -- item table: name ptr, description ptr per entry
local QTAB      = 0x086D68E8   -- quest table: 16 bytes per entry (text ptr, kind, ...)
local EXPT      = 0x081D9830   -- experience needed for level n, u32 at EXPT + 4n
local NQUEST    = 42
local FLAGS     = 0x03000F44   -- event flags, one bit each, least significant bit first: flag id n is bit (n & 7) of byte n >> 3 here
local QUEST_TEXTS = 43         -- quest texts; the start / end records of text t are in table entry t - 1 (the table is shifted by one)
local NSLOT     = 45
local ROSTER    = { "Gohan", "Piccolo", "Vegeta", "Trunks", "Goku" }
-- techniques: each character has a melee and two energy techniques, the name / description pointers sit in tables of five (one per
-- character, in roster order) in the ROM. Byte +0x14 of the character struct unlocks them: bit 2 the melee, bit 3 the first energy, bit 4 the second.
local TECH = {
  { kind = "melee",  bit = 2, names = 0x080E2AB4, descs = 0x080E2AC8, lockName = 0x080E2AA0, lockDesc = 0x080E2AA4 },
  { kind = "energy", bit = 3, names = 0x080E2ADC, descs = 0x080E2AF0, lockName = 0x080E2AA8, lockDesc = 0x080E2AAC },
  { kind = "energy", bit = 4, names = 0x080E2B04, descs = 0x080E2B18, lockName = 0x080E2AA8, lockDesc = 0x080E2AAC },
}

-- inventory slot -> item table entry (slot 0 is the world-map capsule, which the table keeps last;
-- table entry 15, the Senzu Bean, has no slot, entry 44 is that capsule, 45 the Dragon Radar)
local function entry(slot)
  if slot == 0 then return 44 end
  if slot <= 15 then return slot - 1 end
  if slot <= 43 then return slot end
  return 45
end

-- stack limits shown as n/max (other items are single and show no count)
local function stackMax(e)
  if e <= 8 then return 99 end
  if e == 16 then return 25 end
  if e == 20 then return 99 end
  if e == 27 then return 7 end
  if e == 42 then return 3 end
  return 1
end

-- a quest's start and end are small expressions in the ROM: terms 00 <id> 02 13 (flag <id> is clear) and 00 <id> 02 15 (the item
-- <id> is not owned: inventory slot id - 1 is empty), joined by 04 (or) / 05 (and), ended by 11; 00 00 11 is always true.
-- 01 84 54 is one extra term whose flag is bit 0x12a. A quest is active when its start is true and its end is false.
local exprCache = {}
local function expr(p)
  if p < 0x08000000 or p >= 0x0A000000 then return nil end
  local e = exprCache[p]
  if e ~= nil then return e end
  local toks, i, ok = {}, 0, true
  while i < 64 do
    local b0 = mem.u8(p + i)
    if b0 == 0x00 and mem.u8(p + i + 1) == 0x00 and mem.u8(p + i + 2) == 0x11 and #toks == 0 then toks[1] = { k = "t" }; break
    elseif b0 == 0x00 and mem.u8(p + i + 2) == 0x02 then toks[#toks + 1] = { k = "f", id = mem.u8(p + i + 1), op = mem.u8(p + i + 3) }; i = i + 4
    elseif b0 == 0x01 and mem.u8(p + i + 3) == 0x02 then
      local id = (mem.u8(p + i + 1) << 8) | mem.u8(p + i + 2)
      toks[#toks + 1] = { k = "f", id = (id == 0x8454) and 0x12A or id, op = mem.u8(p + i + 4) }; i = i + 5
    elseif b0 == 0x04 or b0 == 0x05 then toks[#toks + 1] = { k = "o", op = b0 }; i = i + 1
    elseif b0 == 0x11 then break
    else ok = false; break end
  end
  e = ok and toks or false
  exprCache[p] = e
  return e
end

local function evalExpr(toks)
  if not toks then return nil end
  local st = {}
  for _, t in ipairs(toks) do
    if t.k == "t" then st[#st + 1] = true
    elseif t.k == "f" then
      if t.op == 0x15 then st[#st + 1] = (mem.u8(INV + t.id - 1) == 0)
      else st[#st + 1] = (((mem.u8(FLAGS + (t.id >> 3)) >> (t.id & 7)) & 1) == 0) end
    else
      local b, a = table.remove(st), table.remove(st)
      if a == nil or b == nil then return nil end
      st[#st + 1] = (t.op == 4) and (a or b) or (a and b)
    end
  end
  return st[#st]
end

local cache = {}
local function str(p)
  if p < 0x08000000 or p >= 0x0A000000 then return "" end
  local s = cache[p]
  if s then return s end
  local t = {}
  for i = 0, 140 do
    local b = mem.u8(p + i)
    if b == 0 then break end
    t[#t + 1] = string.char(b)
  end
  s = table.concat(t)
  cache[p] = s
  return s
end

local lv
local function levelOf(exp)
  if not lv then
    lv = {}
    local prev = -1
    for n = 1, 90 do
      local t = mem.u32(EXPT + 4 * n)
      if n > 2 and t <= prev then break end
      lv[n] = t
      prev = t
    end
  end
  local L = 1
  for n = 2, #lv do
    if lv[n] <= exp then L = n else break end
  end
  return L, lv[L + 1]
end

local function pct(v, m)
  if m <= 0 then return 0 end
  local p = v / m
  if p > 1 then p = 1 end
  if p < 0 then p = 0 end
  return p
end

-- capsules: slots 1-9 = STR / POW / END, +1 / +3 / +5 each; the stat byte sits at +0x0B / +0x0D / +0x0F
local STAT_OFF = { 0x0B, 0x0D, 0x0F }
local STAT_UP  = { 1, 3, 5 }
local function capsule(slot)
  if slot < 1 or slot > 9 then return nil end
  return (slot - 1) // 3 + 1, STAT_UP[(slot - 1) % 3 + 1]
end

-- the techniques of character i: name, description, locked
local function techniques(i, a)
  local flags, out = mem.u8(a + 0x14), {}
  for k, t in ipairs(TECH) do
    local locked = (flags >> t.bit) & 1 == 0
    local np, dp = t.names + 4 * (i - 1), t.descs + 4 * (i - 1)
    if locked then np, dp = t.lockName, t.lockDesc end
    out[k] = { name = str(mem.u32(np)), desc = str(mem.u32(dp)), locked = locked }
  end
  return out
end

local function member(i)
  local a = CHARS + STRIDE * (i - 1)
  local hp, mhp, ep, mep = mem.u16(a), mem.u16(a + 2), mem.u16(a + 4), mem.u16(a + 6)
  if mhp == 0 or mhp > 9999 or mep > 9999 then return nil end
  if mem.u8(a + 0x14) & 1 == 0 then return nil end      -- bit 0 of byte +0x14: the character has joined the party
  local exp = mem.u32(a + 0x10)
  local L, nextAt = levelOf(exp)
  local s, p, e = mem.u8(a + 0x0B), mem.u8(a + 0x0D), mem.u8(a + 0x0F)
  return {
    idx = i, name = ROSTER[i],
    level = L, hp = hp, maxHp = mhp, hpPct = pct(hp, mhp), ep = ep, maxEp = mep, epPct = pct(ep, mep),
    str = s, pow = p, end_ = e, strPct = pct(s, 100), powPct = pct(p, 100), endPct = pct(e, 100),
    exp = exp, next = nextAt and (nextAt - exp) or 0,
    portrait = "asset:gfx/p" .. (i - 1) .. ".png",
    techs = techniques(i, a),
  }
end

function update(ui)
  if mem.read(0x080000AC, 4) ~= GAME then
    return { ready = false, waiting = true }
  end
  -- (the title and file-select screens leave default values in RAM, but nobody has the joined flag there, so the party stays empty)
  local party = {}
  for i = 1, 5 do
    local m = member(i)
    if m then party[#party + 1] = m end
  end
  if #party == 0 then return { ready = false, waiting = true } end

  -- status: selected character
  local who = tonumber(ui.who) or party[1].idx
  local pos = 1
  for k, m in ipairs(party) do if m.idx == who then pos = k end end
  local cur = party[pos]
  local roster = {}
  for k, m in ipairs(party) do
    roster[k] = { idx = m.idx, name = string.upper(m.name), sel = (k == pos) }
  end
  local prevWho = party[(pos - 2) % #party + 1].idx
  local nextWho = party[pos % #party + 1].idx

  -- items
  local items, owned = {}, {}
  for slot = 0, NSLOT - 1 do
    local n = mem.u8(INV + slot)
    if n > 0 then
      local e = entry(slot)
      local mx = stackMax(e)
      items[#items + 1] = {
        slot = slot, name = str(mem.u32(ITAB + 8 * e)),
        count = n .. "/" .. mx, hasCount = mx > 1,
        icon = "asset:gfx/i" .. slot .. ".png",
      }
      owned[#owned + 1] = slot
    end
  end
  local selItem = tonumber(ui.item)
  local ipos = 0
  for k, it in ipairs(items) do if it.slot == selItem then ipos = k end end
  if ipos == 0 and #items > 0 then ipos = 1 end
  local detail = { name = "", desc = "", big = "" }
  local prevItem, nextItem = 0, 0
  if ipos > 0 then
    local it = items[ipos]
    local e = entry(it.slot)
    local desc = str(mem.u32(ITAB + 8 * e + 4))
    detail = { slot = it.slot, name = it.name, desc = desc, big = "asset:gfx/b" .. it.slot .. ".png",
               prompt = it.name, sub = desc, canUse = false, noUse = true }
    local kind = capsule(it.slot)
    if kind then
      local cur_stat = mem.u8(CHARS + STRIDE * (cur.idx - 1) + STAT_OFF[kind])
      if cur_stat < 100 then
        detail.prompt = "Use " .. it.name .. "?"
        detail.sub = "on " .. cur.name
        detail.canUse, detail.noUse = true, false
      else
        detail.sub = cur.name .. " is already at 100"
      end
    end
    prevItem = items[(ipos - 2) % #items + 1].slot
    nextItem = items[ipos % #items + 1].slot
    for k, row in ipairs(items) do row.sel = (k == ipos) end
  end

  -- status: tv 0 shows the stat bars, 1-3 step through the character's techniques (down arrow, like the game)
  local tv = math.max(0, math.min(3, tonumber(ui.tv) or 0))
  local tech = (tv > 0) and cur.techs[tv] or { name = "", desc = "", locked = false }

  -- journal: the active quests, as the game's Quests tab lists them
  local KIND = { [0] = "main", "side", "other" }
  local active = {}
  for t = 0, QUEST_TEXTS - 1 do
    local rec = QTAB + 16 * (t - 1)
    local sx, ex = expr(mem.u32(rec + 8)), expr(mem.u32(rec + 12))
    if sx and ex and evalExpr(sx) and not evalExpr(ex) then
      local text = str(mem.u32(QTAB + 16 * t))
      local kind = KIND[mem.u32(rec + 4)] or "other"
      if text ~= "" then active[#active + 1] = { text = text, kind = kind, main = kind == "main", side = kind == "side", other = kind == "other" } end
    end
  end
  local showDone = tonumber(ui.jv) == 1

  -- journal: finished quests
  local done = {}
  for q = 0, NQUEST - 1 do
    local byte = mem.u8(QDONE + (q >> 3))
    if (byte >> (7 - (q & 7))) & 1 == 1 then
      done[#done + 1] = { text = str(mem.u32(QTAB + 16 * q)) }
    end
  end

  return {
    ready = true, waiting = false,
    member = cur, party = party, roster = roster, prevWho = prevWho, nextWho = nextWho, multi = #party > 1,
    items = items, detail = detail, noItems = #items == 0, prevItem = prevItem, nextItem = nextItem, multiItems = #items > 1,
    showStats = tv == 0, showTech = tv > 0, tech = tech, techNo = string.format("%d/3", tv),
    prevTv = math.max(tv - 1, 0), nextTv = math.min(tv + 1, 3), canDown = tv < 3, canUp = tv > 0,
    done = done, noDone = #done == 0, active = active, noActive = #active == 0,
    jActive = not showDone, jDone = showDone, jvNext = showDone and 0 or 1,
    showNoActive = (#active == 0) and not showDone, showNoDone = (#done == 0) and showDone, jTitle = showDone and "FINISHED" or "QUESTS", jSwitch = showDone and "ACTIVE" or "FINISHED",
  }
end

actions = {}

-- Use a stat capsule on a character, like the game's own "Use STR Cap. +1?" popup:
-- the stat byte goes up (capped at 100) and one capsule leaves the inventory.
function actions.use(slot, who)
  slot, who = tonumber(slot), tonumber(who)
  if not slot or not who or who < 1 or who > 5 then return end
  local kind, amount = capsule(slot)
  if not kind then return end
  local count = mem.u8(INV + slot)
  local a = CHARS + STRIDE * (who - 1) + STAT_OFF[kind]
  local v = mem.u8(a)
  if count == 0 or v >= 100 then return end
  mem.write8(a, math.min(100, v + amount))
  mem.write8(INV + slot, count - 1)
end
