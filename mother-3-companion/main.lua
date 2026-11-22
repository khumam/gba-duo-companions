-- Mother 3 (English fan translation v1.3, game code A3UJ) companion: Goods / Equip / PSI / Status.
-- Memory map and sources are in NOTES.md. Everything shown is read live from RAM; names, descriptions,
-- equipment bonuses, PSI costs and the EXP curve come from data.lua (generated from the ROM by art/extract.py).

local D = pack.require("data")
local ITEMS, PSI, EXP = D.items, D.psi, D.exp

local DP_ADDR     = 0x03006D68   -- u32 money (IWRAM mirror of the save block's 0x02004868)
local PARTY_ADDR  = 0x03006D72   -- 4 x u8, character record index + 1, in the game's menu order
local REC_BASE    = 0x0200417E   -- character record 0 (Flint); 0x6C bytes each
local REC_SIZE    = 0x6C

-- record layout (offsets from the record start; the name sits at +0)
--   +0x00 name, u16 per letter (ascii - 0x20, 0xFFFF ends it), at most 8 letters
--   +0x10 level u8   +0x12 EXP u32   +0x16 HP u16   +0x1A PP u16   +0x1E max HP u16   +0x22 max PP u16 (base)
--   +0x26 offense u8  +0x27 defense u8  +0x28 IQ u8  +0x29 speed u8   (equipment bonuses are added on top)
--   +0x32 equipment u8 x4: weapon, body, head, other   +0x3A inventory u8 x16 (0 = empty)

local SKILLS = { lucas = "PSI", kumatora = "PSI", duster = "Thief Tools", boney = "Sniff" }
local PORTRAITS = { lucas = "p-lucas", kumatora = "p-kumatora", duster = "p-duster", boney = "p-boney" }
local SLOT_NAMES = { "Weapon", "Body", "Head", "Other" }

local function readName(a)
  local s = {}
  for i = 0, 7 do
    local v = mem.u16(a + i * 2)
    if v == 0xFFFF or (v == 0 and i == 0) then break end
    if v >= 0x100 then return nil end
    s[#s + 1] = string.char(v + 0x20)
  end
  local n = table.concat(s)
  if #n == 0 then return nil end
  return n
end

local function item(id)
  return ITEMS[id] or ITEMS[0]
end

local function num(v, fallback)
  v = tonumber(v)
  if v == nil then return fallback end
  return v
end

local function party()
  local out = {}
  for i = 0, 3 do
    local v = mem.u8(PARTY_ADDR + i)
    if v >= 1 and v <= 12 then
      local rec = REC_BASE + REC_SIZE * (v - 1)
      local name = readName(rec)
      local level = mem.u8(rec + 0x10)
      if name and level >= 1 and level <= 99 then
        out[#out + 1] = { rec = rec, name = name }
      end
    end
  end
  return out
end

local function member(m)
  local rec = m.rec
  local key = string.lower(m.name)
  local eq = {}
  local bp = 0
  for k = 0, 3 do
    local id = mem.u8(rec + 0x32 + k)
    local it = item(id)
    eq[#eq + 1] = { slot = k, label = SLOT_NAMES[k + 1], id = id, name = id == 0 and "------" or it.n,
                    has = id ~= 0, none = id == 0, desc = id == 0 and "Nothing equipped." or (it.d or "") }
  end
  -- equipment bonuses come from the item descriptions ("Offense +100."): o, df, iq, sp, pp in data.lua
  local off, def, iq, spd = 0, 0, 0, 0
  for k = 0, 3 do
    local it = item(mem.u8(rec + 0x32 + k))
    off = off + (it.o or 0)
    def = def + (it.df or 0)
    iq = iq + (it.iq or 0)
    spd = spd + (it.sp or 0)
    bp = bp + (it.pp or 0)
  end
  local level = mem.u8(rec + 0x10)
  local exp = mem.u32(rec + 0x12)
  local nxt = EXP[level + 1]  -- EXP is 1-based: EXP[L+1] = total EXP needed to leave level L
  local pp = mem.u16(rec + 0x1A)
  local maxpp = mem.u16(rec + 0x22) + bp
  if pp > maxpp then maxpp = pp end
  local hp = mem.u16(rec + 0x16)
  local maxhp = mem.u16(rec + 0x1E)
  if hp > maxhp then maxhp = hp end
  return {
    name = m.name, key = key,
    portrait = PORTRAITS[key] and ("asset:ui/" .. PORTRAITS[key] .. ".png") or "",
    hasPortrait = PORTRAITS[key] ~= nil, noPortrait = PORTRAITS[key] == nil,
    initial = string.sub(m.name, 1, 1),
    skills = SKILLS[key] or "------",
    level = level, exp = exp,
    next = nxt and math.max(0, nxt - exp) or 0,
    hp = hp, maxhp = maxhp, pp = pp, maxpp = maxpp,
    hpPct = maxhp > 0 and hp / maxhp or 0,
    ppPct = maxpp > 0 and pp / maxpp or 0,
    hasPP = maxpp > 0,
    offense = mem.u8(rec + 0x26) + off,
    defense = mem.u8(rec + 0x27) + def,
    iq = mem.u8(rec + 0x28) + iq,
    speed = mem.u8(rec + 0x29) + spd,
    equip = eq,
    weapon = eq[1].name, body = eq[2].name, head = eq[3].name, other = eq[4].name,
    rec = rec,
  }
end

actions = {}

local function goods(m, selSlot, ui)
  local equipped = {}
  for k = 0, 3 do
    local id = mem.u8(m.rec + 0x32 + k)
    if id ~= 0 then equipped[id] = (equipped[id] or 0) + 1 end
  end
  local slots = {}
  local used = {}
  for s = 1, 16 do
    local id = mem.u8(m.rec + 0x3A + s - 1)
    local it = item(id)
    local isEq = false
    if id ~= 0 and (equipped[id] or 0) > (used[id] or 0) then
      isEq = true
      used[id] = (used[id] or 0) + 1
    end
    local hp = it.d and tonumber(string.match(it.d, "Restores (%d+) HP")) or nil
    local pp = it.d and tonumber(string.match(it.d, "Restores (%d+) PP")) or nil
    slots[s] = { slot = s, id = id, name = id == 0 and "" or it.n, has = id ~= 0, empty = id == 0, eq = isEq, noEq = not isEq,
                 desc = id == 0 and "" or (it.d or ""),
                 heal = (hp or pp) and { hp = hp or 0, pp = pp or 0 } or nil }
  end
  local first
  for s = 1, 16 do
    if slots[s].has then first = s break end
  end
  local sel = selSlot
  if not sel or sel < 1 or sel > 16 or not slots[sel].has then sel = first end
  local count = 0
  for s = 1, 16 do
    slots[s].on = (s == sel)
    if slots[s].has then count = count + 1 end
  end
  local cur = sel and slots[sel] or nil
  local usable = cur ~= nil and (cur.heal ~= nil)
  local mode = ui and ui.mode or ""
  return {
    rows = slots, count = count,
    canUse = usable, noUse = not usable,
    canMove = cur ~= nil and not cur.eq, noMove = not (cur ~= nil and not cur.eq),
    sheet = mode == "use" or mode == "give" or mode == "drop",
    sheetPick = mode == "use" or mode == "give",
    sheetUse = mode == "use", sheetGive = mode == "give", sheetDrop = mode == "drop",
    sheetTitle = mode == "use" and "On whom?" or mode == "give" and "Give to whom?"
                 or ("Drop " .. (cur and cur.name or "") .. "?"),
    note = ui and ui.msg or "", hasNote = ui ~= nil and ui.msg ~= nil and ui.msg ~= "", isEmpty = count == 0,
    desc = sel and slots[sel].desc or "", name = sel and slots[sel].name or "",
    hasSel = sel ~= nil,
  }
end

local psiRows = nil
local function psiList(selId)
  if not psiRows then
    psiRows = {}
    for i, p in ipairs(PSI) do
      psiRows[i] = { id = p.id, name = p.n, pp = p.pp, desc = p.d }
    end
  end
  local sel = selId
  local found = false
  for _, r in ipairs(psiRows) do if r.id == sel then found = true end end
  if not found then sel = psiRows[1].id end
  local desc, pp, name = "", 0, ""
  for _, r in ipairs(psiRows) do
    r.on = (r.id == sel)
    if r.on then desc = r.desc; pp = r.pp; name = r.name end
  end
  return { rows = psiRows, desc = desc, pp = pp, name = name, total = #psiRows }
end

function update(ui)
  local out = { ready = false, waiting = true }
  local ok, p = pcall(party)
  if not ok or #p == 0 then return out end

  local chIdx = num(ui.ch, 0)
  if chIdx < 0 or chIdx >= #p then chIdx = 0 end

  local chars, members = {}, {}
  for i, m in ipairs(p) do
    local c = member(m)
    members[i] = c
    chars[i] = { idx = i - 1, name = c.name, portrait = c.portrait, hasPortrait = c.hasPortrait, noPortrait = c.noPortrait,
                 initial = c.initial, on = (i - 1 == chIdx) }
  end
  local c = members[chIdx + 1]

  local eqSel = num(ui.eq, 0)
  if eqSel < 0 or eqSel > 3 then eqSel = 0 end
  for k = 1, 4 do c.equip[k].on = (k - 1 == eqSel) end

  out.ready = true
  out.waiting = false
  out.dp = tostring(mem.u32(DP_ADDR))
  out.chars = chars
  out.ch = chIdx
  out.c = c
  out.eqDesc = c.equip[eqSel + 1].desc
  out.eqName = c.equip[eqSel + 1].name
  out.goods = goods(c, num(ui.slot, nil), ui)
  out.targets = {}
  for i, mm in ipairs(members) do
    out.targets[i] = { idx = i - 1, name = mm.name, portrait = mm.portrait, hasPortrait = mm.hasPortrait, noPortrait = mm.noPortrait,
                       initial = mm.initial, hp = mm.hp, maxhp = mm.maxhp, pp = mm.pp, maxpp = mm.maxpp, hasPP = mm.hasPP }
  end
  out.giveTargets = {}
  for i, t in ipairs(out.targets) do
    if i - 1 ~= chIdx then out.giveTargets[#out.giveTargets + 1] = t end
  end
  out.psi = psiList(num(ui.psi, nil))
  out.ppLabel = c.hasPP and (c.pp .. "/" .. c.maxpp) or "0/0"
  return out
end


-- ---- actions: Use / Give / Drop (need the memory-write permission; each write happens only from a tap) ----

local function readInv(rec)
  local ids = {}
  for s = 1, 16 do ids[s] = mem.u8(rec + 0x3A + s - 1) end
  return ids
end

local function invBytes(ids)
  local t = {}
  for s = 1, 16 do t[s] = string.char(ids[s] or 0) end
  return table.concat(t)
end

local function removeSlot(ids, slot)
  table.remove(ids, slot)
  ids[16] = 0
  return ids
end

-- who is selected and what is in the selected slot; nil + a message when it can't be acted on
local function selection()
  local p = party()
  local ch = num(ui.ch, 0)
  local src = p[ch + 1]
  if not src then return nil, "Nobody there." end
  local slot = num(ui.slot, 0)
  local mm = member(src)
  local g = goods(mm, slot, nil)
  local row
  for _, r in ipairs(g.rows) do if r.on then row = r end end
  if not row then return nil, "Pick an item first." end
  return { p = p, src = src, mm = mm, row = row, slot = row.slot }
end

local function why(e)
  e = tostring(e)
  if string.find(e, "permission", 1, true) then
    return "Allow GAME CHANGES first (the button below), then try again."
  end
  return e
end

local function done(msg)
  return { set = { mode = "", msg = msg or "" } }
end

function actions.doUse(target)
  local sel, why = selection()
  if not sel then return done(why) end
  local heal = sel.row.heal
  if not heal then return done("Can't use that here.") end
  local dst = sel.p[num(target, -1) + 1]
  if not dst then return done("Nobody there.") end
  local t = member(dst)
  if t.hp <= 0 then return done(t.name .. " is down.") end
  local newHp = math.min(t.maxhp, t.hp + heal.hp)
  local newPp = math.min(t.maxpp, t.pp + heal.pp)
  if newHp == t.hp and newPp == t.pp then return done("It would have no effect on " .. t.name .. ".") end
  local ids = removeSlot(readInv(sel.src.rec), sel.slot)
  -- write last, after every check
  if newHp ~= t.hp then
    local ok, e = mem.write16(dst.rec + 0x16, newHp)
    if not ok then return done("Couldn't use it: " .. why(e)) end
  end
  if newPp ~= t.pp then
    local ok, e = mem.write16(dst.rec + 0x1A, newPp)
    if not ok then return done("Couldn't use it: " .. why(e)) end
  end
  local ok, e = mem.write(sel.src.rec + 0x3A, invBytes(ids))
  if not ok then return done("Couldn't use it: " .. why(e)) end
  return done(t.name .. " used " .. sel.row.name .. ".")
end

function actions.doGive(target)
  local sel, why = selection()
  if not sel then return done(why) end
  if sel.row.eq then return done("Unequip it first.") end
  local dst = sel.p[num(target, -1) + 1]
  if not dst or dst.rec == sel.src.rec then return done("Pick someone else.") end
  local dids = readInv(dst.rec)
  local free
  for s = 1, 16 do if dids[s] == 0 then free = s break end end
  if not free then return done(dst.name .. " can't carry any more.") end
  dids[free] = sel.row.id
  local sids = removeSlot(readInv(sel.src.rec), sel.slot)
  local ok, e = mem.write(dst.rec + 0x3A, invBytes(dids))
  if not ok then return done("Couldn't give it: " .. why(e)) end
  ok, e = mem.write(sel.src.rec + 0x3A, invBytes(sids))
  if not ok then return done("Couldn't give it: " .. why(e)) end
  return done(sel.src.name .. " gave " .. sel.row.name .. " to " .. dst.name .. ".")
end

function actions.doDrop()
  local sel, why = selection()
  if not sel then return done(why) end
  if sel.row.eq then return done("Unequip it first.") end
  local ok, e = mem.write(sel.src.rec + 0x3A, invBytes(removeSlot(readInv(sel.src.rec), sel.slot)))
  if not ok then return done("Couldn't drop it: " .. why(e)) end
  return done("Dropped " .. sel.row.name .. ".")
end
