-- Mario & Luigi: Superstar Saga (USA, A88E) companion.
-- Addresses found with a headless mGBA run on the real ROM and a save at Bowser's Castle; see NOTES.md.

local GAME   = "A88E"
local DEBUG  = false       -- true logs the foe ids and the item uses (adb logcat -s GBADuoPack)
local MARIO  = 0x02004840      -- live stat block, Luigi's is 0x3C bytes later
local STRIDE = 0x3C
local COINS  = 0x020048E0
local ITEMS  = 0x020048E2      -- one quantity byte per item, in the menu's order
local BEANS  = 0x02004902      -- Woo, Hoo, Chuckle, Hee
local TIME   = 0x03000370      -- play time in frames (60 per second)
local ITAB   = 0x083BB7F4      -- item name / description pointers, 8 bytes each (ROM order)
local BTAB   = 0x083BCCD4      -- bean name / description pointers
-- level thresholds: 12-byte entries, the EXP in the first four bytes; Mario's table starts at level 2, Luigi's at level 1
local EXPT   = { [0] = { 0x083BAEB2, 1 }, [1] = { 0x083BB34A, 0 } }

local ORDER = { "Mushrooms", "Super Mushrooms", "Ultra Mushrooms", "Max Mushrooms", "Nuts", "Super Nuts", "Ultra Nuts", "Max Nuts",
  "Syrup", "Super Syrup", "Ultra Syrup", "Max Syrup", "1-Up Mushrooms", "1-Up Supers", "Golden Mushrooms", "Refreshing Herbs",
  "Red Peppers", "Green Peppers", "Woohoo Blend", "Hoohoo Blend", "Chuckle Blend", "Teehee Blend", "Hoolumbian", "Chuckoccino",
  "Teeheespresso" }
local BEAN_NAMES = { "Woo Beans", "Hoo Beans", "Chuckle Beans", "Hee Beans" }

local cache = {}
local function str(p)
  if p < 0x08000000 or p >= 0x0A000000 then return "" end
  local s = cache[p]
  if s then return s end
  local t = {}
  for i = 0, 80 do
    local b = mem.u8(p + i)
    if b == 0 then break end
    t[#t + 1] = string.char(b)
  end
  s = table.concat(t); cache[p] = s; return s
end

-- descriptions by item name, read once from the ROM table (names there are in their own order)
local desc
local function describe(name)
  if not desc then
    desc = {}
    for i = 0, 24 do desc[str(mem.u32(ITAB + 8 * i))] = str(mem.u32(ITAB + 8 * i + 4)) end
  end
  return desc[name] or ""
end

local function u16(a) return mem.u16(a) end
-- the level tables are not 4-byte aligned (0x...2); the device's mem.u32 reads the aligned word there, so read bytes
local function u32b(a) return mem.u8(a) | (mem.u8(a + 1) << 8) | (mem.u8(a + 2) << 16) | (mem.u8(a + 3) << 24) end
local function levelOf(who, exp)
  local base, shift = EXPT[who][1], EXPT[who][2]
  local count, nextAt = 0, 0
  for k = 0, 98 do
    local t = u32b(base + 12 * k)
    if t <= exp and (k == 0 or t > u32b(base + 12 * (k - 1)) or t == 0) then count = count + 1
    else nextAt = t; break end
  end
  return count + shift, nextAt
end

local function bro(who, name)
  local a = MARIO + STRIDE * who
  local exp = mem.u32(a + 0x1C) & 0xFFFFFF
  local lv, nextAt = levelOf(who, exp)
  local hp, maxHp, bp, maxBp = u16(a + 0x26), u16(a + 0x2A), u16(a + 0x2C), u16(a + 0x30)
  return {
    name = name, level = lv, hp = hp, maxHp = maxHp, bp = bp, maxBp = maxBp,
    hpPct = (maxHp > 0) and math.min(1, hp / maxHp) or 0, bpPct = (maxBp > 0) and math.min(1, bp / maxBp) or 0,
    pow = u16(a + 0x34), speed = u16(a + 0x38), def = u16(a + 0x3C), stache = u16(a + 0x40),
    exp = exp, next = (nextAt > exp) and (nextAt - exp) or 0,
    face = "asset:gfx/" .. string.lower(name) .. ".png", round = "asset:gfx/round_" .. string.lower(name) .. ".png",
  }
end

-- ---- Battle ---------------------------------------------------------------------------------------
-- The game keeps the fight in 8 battler slots of 0x130 bytes (IWRAM 0x03003FA4 holds a pointer to each; they sit at a
-- different EWRAM address every battle, so the table is followed, never a fixed address). Slots 0-5 are the enemies,
-- 6 is Mario and 7 is Luigi (an empty slot is all zeros). Inside a slot, from +0xF4: a header word (0x0106 / 0x0107 for
-- the bros, 0x63nn for an enemy), then HP @+0xF6 and its maximum @+0xF8; for a bro also BP @+0xFC, max BP @+0xFE, POW
-- @+0x102, DEF @+0x104, SPEED @+0x106 and STACHE @+0x108. An enemy's type id is @+0xEC (Goomba 12, Bowser 85).
-- A battle is on while the screen is in the battle layout (the BG control registers) and Mario's slot is filled; the
-- slots are not cleared afterwards, which is why the screen is checked as well.
local wasBattle, pageBefore = false, "pass"
local BATTLERS = 0x03003FA4
local REG_BG0CNT, REG_BG2CNT = 0x04000008, 0x0400000C
local BATTLE_BG0, BATTLE_BG2 = 0x5A03, 0x1E04
local FOE_NAMES = { [12] = "Goomba", [85] = "Bowser" }       -- type ids seen so far; the rest show their number

-- The ROM's enemy table (found by matching Goomba id 12 -> HP 4 and Bowser id 85 -> HP 5006 at the same stride): 44 bytes
-- an entry from 0x08500A9C, indexed by the type id. u16 at +2 max HP (a boss has 5000 added), +20 POW, +22 DEF, +24 low byte
-- SPEED (the rest of that word is flags). Only the max HP is checked against a live fight; POW matches the slot (Goomba 19,
-- Bowser 28), DEF / SPEED are read as the table has them and are not confirmed against the game.
local ENEMY_TABLE, ENEMY_SIZE, ENEMY_COUNT = 0x08500A9C, 44, 189
local function foeStats(id, maxHp)
  if id >= ENEMY_COUNT then return nil end
  local e = ENEMY_TABLE + id * ENEMY_SIZE
  local tableHp = mem.u8(e + 2) | mem.u8(e + 3) << 8
  if tableHp ~= maxHp then return nil end
  return { pow = mem.u8(e + 20) | mem.u8(e + 21) << 8, def = mem.u8(e + 22) | mem.u8(e + 23) << 8, speed = mem.u8(e + 24) }
end

-- An enemy's name: the last u32 of the previous entry (the table's records sit one entry late) points at a record of
-- five pointers (one per language, English first), each into the ROM's name pointer table, whose entry points at the
-- string. Goomba 12 -> entry 11's record, Bowser 85 -> entry 84's; the Bowser fight's 86 / 87 / 88 all read Fawful.
local nameCache = {}
local function foeName(id)
  if nameCache[id] ~= nil then return nameCache[id] or nil end
  local name = false
  if id >= 1 and id < ENEMY_COUNT then
    local rec = mem.u32(ENEMY_TABLE + (id - 1) * ENEMY_SIZE + 40)
    if rec >= 0x08000000 and rec < 0x0A000000 then
      local slotPtr = mem.u32(rec)
      if slotPtr >= 0x08000000 and slotPtr < 0x0A000000 then
        local str = mem.u32(slotPtr)
        if str >= 0x08000000 and str < 0x0A000000 then
          local raw = mem.read(str, 24)
          local text = raw and raw:match("^[%w%s%.%-!']+")
          if text and #text >= 2 then name = text end
        end
      end
    end
  end
  nameCache[id] = name
  return name or nil
end

local function slot(i)
  local p = mem.u32(BATTLERS + 4 * i)
  if p >= 0x02000000 and p < 0x02040000 then return p end
  return nil
end

local function broSlot(i, mario, luigi)
  local b = slot(i)
  if not b then return nil end
  local hdr = mem.u16(b + 0xF4)
  -- the low byte is the slot (6 / 7); the high byte changes during a fight (1, 2, ...), so it is not compared
  if hdr & 0xFF ~= i or hdr >> 8 > 0x0F then return nil end
  local maxHp = u16(b + 0xF8)
  if maxHp == 0 or maxHp > 999 then return nil end
  return {
    hp = u16(b + 0xF6), maxHp = maxHp, bp = u16(b + 0xFC), maxBp = u16(b + 0xFE),
    pow = u16(b + 0x102), def = u16(b + 0x104), speed = u16(b + 0x106),
  }
end

-- nil when no fight is on, else { bros = { mario?, luigi? }, foes = { { slot, id, hp, maxHp }, ... } }
-- A few ticks of grace: the screen registers may change for a moment mid-fight (an attack's close-up, a transition), and
-- the fight is not over then, so the screen has to stay off the battle layout for GRACE ticks before the fight ends.
local GRACE, offTicks = 6, 0
local lastFoeLog = ""
local function readBattle()
  local mario = broSlot(6)
  if not mario then offTicks = 0; return nil end
  if mem.u16(REG_BG0CNT) == BATTLE_BG0 and mem.u16(REG_BG2CNT) == BATTLE_BG2 then offTicks = 0
  elseif wasBattle and offTicks < GRACE then offTicks = offTicks + 1
  else return nil end
  local foes = {}
  for i = 0, 5 do
    local b = slot(i)
    if b then
      local hdr = mem.u16(b + 0xF4)
      local hp, maxHp = u16(b + 0xF6), u16(b + 0xF8)
      if hdr ~= 0 and hdr & 0xFF == i and maxHp > 0 and maxHp <= 30000 and hp <= maxHp then
        foes[#foes + 1] = { slot = i, id = u16(b + 0xEC), hp = hp, maxHp = maxHp }
      end
    end
  end
  local seen = {}
  for _, f in ipairs(foes) do seen[#seen + 1] = string.format("slot%d id=%d hp=%d/%d", f.slot, f.id, f.hp, f.maxHp) end
  local line = table.concat(seen, ", ")
  if DEBUG and line ~= lastFoeLog then lastFoeLog = line; log("FOES " .. line) end   -- debug: pairs ids with the names seen on screen
  return { mario = mario, luigi = broSlot(7), foes = foes }
end

-- ---- Using an item from the Items page (needs memory-write) -------------------------------------------------------
-- Tap an item to select it, then tap Mario or Luigi to use it on them. Only the plain recovery items are done: what they
-- do is written here by name (the ROM's descriptions say the same), and only the stat block's HP / BP and the item's
-- quantity are written, never the block's header. Not during a fight: the fight keeps its own copy of HP / BP and the
-- stat block only catches up afterwards.
local ALL = 9999
local EFFECTS = {
  ["Mushrooms"] = { hp = 25 }, ["Super Mushrooms"] = { hp = 50 }, ["Ultra Mushrooms"] = { hp = 120 }, ["Max Mushrooms"] = { hp = ALL },
  ["Nuts"] = { hp = 20, both = true }, ["Super Nuts"] = { hp = 40, both = true }, ["Ultra Nuts"] = { hp = 100, both = true },
  ["Max Nuts"] = { hp = ALL, both = true },
  ["Syrup"] = { bp = 20 }, ["Super Syrup"] = { bp = 40 }, ["Ultra Syrup"] = { bp = 100 }, ["Max Syrup"] = { bp = ALL },
  ["Golden Mushrooms"] = { hp = ALL, bp = ALL },
  ["1-Up Mushrooms"] = { revive = 2 }, ["1-Up Supers"] = { revive = 1 },
}
local selectedItem = nil          -- the Items-page selection (menu index), nil: nothing picked
local lastTab = "items"
local useMsg, useMsgAt = nil, 0   -- the last result, shown in the info bar for a few seconds

local function say(text)
  useMsg, useMsgAt = text, mem.u32(TIME)
  if DEBUG then log("item: " .. text) end
end

local function statsOf(who)
  local a = MARIO + STRIDE * who
  local hp, maxHp, bp, maxBp = u16(a + 0x26), u16(a + 0x2A), u16(a + 0x2C), u16(a + 0x30)
  if maxHp == 0 or maxHp > 999 or maxBp > 999 or hp > maxHp or bp > maxBp then return nil end
  return { a = a, hp = hp, maxHp = maxHp, bp = bp, maxBp = maxBp }
end

actions = actions or {}
-- Tap an item to pick it, tap it again to put it back; nothing is picked to start with.
function actions.pickItem(idx)
  idx = tonumber(idx)
  if idx == nil then return end
  if selectedItem == idx then selectedItem = nil else selectedItem = idx end
end

function actions.useItem(whoName)
  local who = (whoName == "luigi") and 1 or 0
  local label = (who == 1) and "Luigi" or "Mario"
  if wasBattle then return say("Not during a battle") end
  if selectedItem == nil then return say("Pick an item first") end
  if selectedItem < 0 or selectedItem >= #ORDER then return say("Beans can't be used from here") end
  local name = ORDER[selectedItem + 1]
  local fx = EFFECTS[name]
  if not fx then return say(name .. " can't be used from here") end
  local qty = mem.u8(ITEMS + selectedItem)
  if qty < 1 or qty > 99 then return say("None left") end
  local targets = fx.both and { 0, 1 } or { who }
  local writes, parts = {}, {}
  for _, t in ipairs(targets) do
    local st = statsOf(t)
    if not st then return say("Stats not readable right now") end
    local who_ = (t == 1) and "Luigi" or "Mario"
    local hp, bp = st.hp, st.bp
    if fx.revive then
      if st.hp ~= 0 then return say(who_ .. " is not knocked out") end
      hp = (fx.revive == 1) and st.maxHp or math.max(1, st.maxHp // 2)
    else
      if st.hp == 0 and fx.hp then return say(who_ .. " is knocked out") end
      if fx.hp then hp = math.min(st.maxHp, st.hp + fx.hp) end
      if fx.bp then bp = math.min(st.maxBp, st.bp + fx.bp) end
    end
    if hp ~= st.hp then writes[#writes + 1] = { st.a + 0x26, hp }; parts[#parts + 1] = string.format("%s +%d HP", who_, hp - st.hp) end
    if bp ~= st.bp then writes[#writes + 1] = { st.a + 0x2C, bp }; parts[#parts + 1] = string.format("%s +%d BP", who_, bp - st.bp) end
  end
  if #writes == 0 then return say(label .. " is already full") end
  for _, w in ipairs(writes) do
    local ok, why = mem.write16(w[1], w[2])
    if not ok then return say("Can't change the game: " .. tostring(why)) end
  end
  local ok, why = mem.write8(ITEMS + selectedItem, qty - 1)    -- the item is used up last, once the rest went through
  if not ok then return say("Can't change the game: " .. tostring(why)) end
  return say(name .. ": " .. table.concat(parts, ", "))
end

function update(ui)
  if mem.read(0x080000AC, 4) ~= GAME then return { ready = false, waiting = true } end
  local mario, luigi = bro(0, "Mario"), bro(1, "Luigi")
  if mario.maxHp == 0 or mario.maxHp > 999 or luigi.maxHp == 0 or luigi.maxHp > 999 then return { ready = false, waiting = true } end

  -- the fight in progress, if any: live HP / BP for the bros everywhere, the foes for the battle page
  local battle = readBattle()
  local whoMario, foes, foe, battleText = true, {}, { name = "", hint = "", hp = 0, maxHp = 0, pow = "--", def = "--", speed = "--" }, "No battle right now"
  if battle then
    for who, b in pairs({ [mario] = battle.mario, [luigi] = battle.luigi }) do
      if b then
        who.hp, who.maxHp, who.bp, who.maxBp = b.hp, b.maxHp, b.bp, b.maxBp
        who.hpPct = math.min(1, b.hp / b.maxHp)
        who.bpPct = (b.maxBp > 0) and math.min(1, b.bp / b.maxBp) or 0
        who.pow, who.def, who.speed = b.pow, b.def, b.speed
      end
    end
    local chosen = tonumber(ui.foe)
    local pick
    for k, f in ipairs(battle.foes) do
      local name = foeName(f.id) or FOE_NAMES[f.id] or string.format("Enemy #%d", f.id)
      foes[#foes + 1] = {
        idx = f.slot, name = name, n = string.char(64 + k), hp = f.hp, maxHp = f.maxHp,
        hpPct = math.min(1, f.hp / f.maxHp), down = f.hp == 0, sel = false,
      }
      if chosen == f.slot or (not pick and f.hp > 0) then pick = foes[#foes] end
    end
    if not pick then pick = foes[1] end
    if pick then
      pick.sel = true
      local pickId
      for _, f in ipairs(battle.foes) do if f.slot == pick.idx then pickId = f.id end end
      local st = foeStats(pickId or 0xFFFF, pick.maxHp)
      foe = { name = (#foes > 1) and (pick.name .. " " .. pick.n) or pick.name, hint = (pickId and (foeName(pickId) or FOE_NAMES[pickId])) and "" or "Name not known yet",
        hp = pick.hp, maxHp = pick.maxHp, pow = st and st.pow or "--", def = st and st.def or "--", speed = st and st.speed or "--" }
    end
    whoMario = not (ui.who == "luigi" and battle.luigi)
    local w, wb = whoMario and "Mario" or "Luigi", whoMario and battle.mario or battle.luigi
    battleText = string.format("%s: HP %d/%d   BP %d/%d", w, wb.hp, wb.maxHp, wb.bp, wb.maxBp)
  end

  local frames = mem.u32(TIME)
  local items = {}
  for i = 0, #ORDER - 1 do
    local q = mem.u8(ITEMS + i)
    if q >= 1 and q <= 99 then items[#items + 1] = { idx = i, name = ORDER[i + 1], qty = q } end
  end
  local beans = {}
  for i = 0, 3 do
    local q = mem.u8(BEANS + i)
    if q >= 1 and q <= 99 then beans[#beans + 1] = { idx = 100 + i, name = BEAN_NAMES[i + 1], qty = q } end
  end
  local tab = ui.tab or "items"
  local list = (tab == "beans") and beans or items
  if tab ~= lastTab then selectedItem = nil; lastTab = tab end     -- the other tab starts with nothing picked
  local sel
  for _, it in ipairs(list) do if it.idx == selectedItem then sel = it end end
  if not sel then selectedItem = nil end                            -- a used-up item drops out of the list
  for _, it in ipairs(list) do it.sel = (sel ~= nil and it.idx == sel.idx) end
  local text = (#list > 0) and "Tap an item to select it, tap it again to put it back" or ""
  if sel then
    if tab == "beans" then
      for i = 0, 7 do
        if str(mem.u32(BTAB + 8 * i)) == sel.name then text = str(mem.u32(BTAB + 8 * i + 4)) end
      end
    else
      text = sel.name .. ": " .. describe(sel.name)
      if EFFECTS[sel.name] then          -- the bar is one line: the long hint only when it fits
        if #text <= 34 then text = text .. "  Tap Mario or Luigi to use."
        elseif #text <= 44 then text = text .. "  Tap a bro to use." end
      end
    end
  end
  if useMsg and frames >= useMsgAt and frames - useMsgAt < 300 then text = useMsg end   -- the last use, for 5 seconds

  local who = ui.bro or "mario"
  local out = {
    ready = true, waiting = false, mario = mario, luigi = luigi, sel = (who == "luigi") and luigi or mario,
    isMario = (who ~= "luigi"), isLuigi = (who == "luigi"),
    coins = u16(COINS), time = string.format("%d:%02d", frames // 216000, (frames // 3600) % 60),
    list = list, itemsTab = (tab ~= "beans"), beansTab = (tab == "beans"), selText = text, noList = #list == 0,
    inBattle = battle ~= nil, noBattle = battle == nil, foes = foes, foe = foe,
    whoMario = whoMario, whoLuigi = not whoMario, battleText = battleText,
  }
  -- the battle page opens by itself when a fight starts, and the page you were on comes back when it ends
  if battle and not wasBattle then
    if ui.page and ui.page ~= "battle" then pageBefore = ui.page end
    out.ui = { navigate = "battle" }
  elseif wasBattle and not battle then
    out.ui = { navigate = pageBefore }
  end
  wasBattle = battle ~= nil
  return out
end
