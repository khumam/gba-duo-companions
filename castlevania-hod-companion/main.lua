-- Castlevania: Harmony of Dissonance Companion — main.lua (v1.0: STATUS, ITEMS, MAGIC, MAP, BATTLE, BOOK, JOURNEY)
-- update(ui) returns display-ready values only; every address and table lives in hod.lua.
local H = pack.require("hod")
local Items = pack.require("items")
local Magic = pack.require("magic")
local Battle = pack.require("battle")
local Book = pack.require("book")
local Map = pack.require("map")
local Journey = pack.require("journey")
local A = H.A
local GAME_CODE = mem.read(0x080000AC, 4)

local PAGES = { "status", "items", "magic", "map", "battle", "book", "journey" }
local TITLES = { items = "Items", magic = "Spell Book", map = "Castle Map", battle = "Battle",
                 book = "Encyclopedia", journey = "Journey" }
local SOON = {}                        -- every page is built (v0.7)
local HINTS = { status = "Tap equipment, a relic, the subweapon or the spell book to read about it.",
                items = "Tap an item for its details. The pills switch lists; ARMOR has slot filters.",
                map = "The game's map from your save: explored rooms, save and warp rooms, and you (blinking). A and B switch castles.",
                book = "The game's Encyclopedia: defeated enemies, with drops you have found. Orange = boss. REVEAL shows the rest.",
                battle = "Enemies in this room with the game's own Lv, HP, ATK and weaknesses. A boss opens this page by itself. Tap one for EXP and drops.",
                journey = "Tap a boss or an item to read about it. WHERE shows the name and place of what you haven't found yet.",
                magic = "MP per cast for each spell book and subweapon. Gold = your current pair. Tap anything." }
local MAXIM_MAGIC = "Maxim Mode: no spell books or relics."
local MAXIM_HINT = "Tap the subweapon to read about it."
local STATS = { "STR", "DEF", "INT", "LCK" }
local STATUS = { [1] = "POISON", [2] = "CURSE", [4] = "STONE" }  -- the game's own status words

local function commas(n)
  local s = tostring(math.floor(n))
  return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function clock(frames)
  local s = math.min(frames // 60, 99 * 3600 + 59 * 60 + 59)
  return string.format("%d:%02d:%02d", s // 3600, (s // 60) % 60, s % 60)
end

local function frac(v, m) return m > 0 and math.max(0, math.min(1, v / m)) or 0 end

-- ---- vitals (STATUS and BATTLE) -------------------------------------------------------------
local function vitals(out, chr)
  local hp, maxHp = mem.u16(A.hp), mem.u16(A.maxHp)
  local mp, maxMp = mem.u16(A.mp), mem.u16(A.maxMp)
  local hearts, maxHearts = mem.u16(A.hearts), mem.u16(A.maxHearts)
  out.hp = hp .. "/" .. maxHp
  out.mp = mp .. "/" .. maxMp
  out.hearts = hearts .. "/" .. maxHearts
  out.hpPct, out.mpPct, out.heartPct = frac(hp, maxHp), frac(mp, maxMp), frac(hearts, maxHearts)
  out.hpLow = hp * 4 <= maxHp
  local st = mem.u16(A.status)
  local word = "GOOD"
  for bit, w in pairs(STATUS) do if st & bit ~= 0 then word = w end end
  out.status, out.statusBad = word, st & 7 ~= 0
  local sprite = H.sprite(chr)
  out.sprite, out.hasSprite, out.spriteWide = sprite or "", sprite ~= nil, chr == 2
  out.heroName = H.text(H.T.char + (chr == 2 and 1 or 0))
end

-- ---- status page ------------------------------------------------------------------------
local function statusPage(out, ui, chr)
  local maxim = chr == 2
  local lv, exp = mem.u8(A.level), mem.u32(A.exp)
  out.hasLevel, out.isMaxim = not maxim, maxim
  out.level, out.exp = tostring(lv), commas(exp)
  local nx = H.next(lv, exp)
  out.next = nx and commas(nx) or "-"
  out.expPct = H.expPct(lv, exp)

  local stats = {}
  for k = 1, 4 do stats[k] = { label = STATS[k], value = tostring(mem.u16(A.stats + 2 * (k - 1))) } end
  out.stats = stats

  local tip = ui.tip
  -- Equipment (Juste only: Maxim has no menu)
  local gear = {}
  if not maxim then
    local w = mem.u8(A.weapon)
    local whip = { slot = "WHIP", empty = w == 0xFF, tip = -1 }
    if w < H.LIST.whip.n then
      whip.name, whip.icon, whip.tip = H.name("whip", w), H.icon("whip", w), H.descId("whip", w)
    else
      whip.name = "---"
    end
    gear[1] = whip
    for s = 0, 3 do
      local id = mem.u8(A.armor + s)
      local g = { slot = s == 0 and "BODY" or "", empty = id == 0xFF, tip = -1 }
      if id < H.LIST.armor.n then
        g.slot = H.SLOT[H.armorType(id)] or ""
        g.name, g.icon, g.tip = H.name("armor", id), H.icon("armor", id), H.descId("armor", id)
      else
        g.name = "---"
      end
      gear[#gear + 1] = g
    end
  end
  for _, g in ipairs(gear) do
    g.hasIcon = g.icon ~= nil
    g.icon = g.icon or ""
    g.tappable = g.tip >= 0
    g.sel = g.tappable and g.tip == tip
    g.hasState, g.state, g.on = false, "-", false
  end
  out.gear, out.hasGear = gear, #gear > 0

  -- Subweapon and spell book
  local arms = {}
  local sw = mem.u8(A.subweapon)
  local sub = { slot = "SUB", hasState = false, state = "-", on = false, tip = -1 }
  if sw >= 1 and sw <= 7 then
    sub.name, sub.icon, sub.tip = H.SUBWEAPONS[sw], H.subIcon(sw), 1000 + sw
  else
    sub.name, sub.empty = "None", true
  end
  arms[1] = sub
  if not maxim then
    local sp = mem.u8(A.spell)
    local book = sp & 0x7F
    local bk = { slot = "BOOK", hasState = false, state = "-", on = false, tip = -1 }
    if book >= 1 and book <= 5 then
      bk.name, bk.icon, bk.tip = H.name("book", book - 1), H.icon("book", book - 1), H.descId("book", book - 1)
      bk.hasState, bk.on = true, sp & 0x80 ~= 0
      bk.state = bk.on and "ON" or "OFF"
    else
      bk.name, bk.empty = "None", true
    end
    arms[2] = bk
  end
  for _, g in ipairs(arms) do
    g.hasIcon = g.icon ~= nil
    g.icon = g.icon or ""
    g.empty = g.empty or false
    g.tappable = g.tip >= 0
    g.sel = g.tappable and g.tip == tip
  end
  out.arms = arms

  -- Relics: 12 sockets, owned ones with their icon, lit when switched ON (Relics screen)
  local owned = mem.u8(A.relicsOwned) | (mem.u8(A.relicsOwned + 1) << 8)
  local on = mem.u8(A.relicsOn) | (mem.u8(A.relicsOn + 1) << 8)
  local relics, n = {}, 0
  for i = 0, H.LIST.relic.n - 1 do
    local has = owned & (1 << i) ~= 0
    local r = { owned = has, missing = not has, on = has and on & (1 << i) ~= 0, icon = "", tip = -1, sel = false }
    if has then
      n = n + 1
      r.icon = H.icon("relic", i) or ""
      r.tip = H.descId("relic", i)
      r.sel = r.tip == tip
    end
    relics[#relics + 1] = r
  end
  out.relics, out.hasRelics = relics, not maxim
  out.relicCount = n .. "/" .. H.LIST.relic.n
end

-- The INFORMATION bar: the game's description for the tapped thing, else the page hint.
local function information(out, ui, page)
  local tip = tonumber(ui.tip) or -1
  out.info, out.hasInfoIcon, out.infoIcon = HINTS[page] or ("This page " .. (SOON[page] or ""):lower() .. "."), false, ""
  if page == "status" and out.isMaxim then out.info = MAXIM_HINT end
  if page == "magic" and out.isMaxim then out.info = MAXIM_MAGIC end
  if (tip >= Battle.TIP and tip < Battle.TIP + 250) or tip >= Battle.TIP_FOE then
    out.info = Battle.tipText(tip)
  elseif tip >= 2000 and tip < 2048 then
    local text, book, sub = Magic.spellText(tip)
    out.info = text or out.info
    if text then
      local key = sub > 0 and H.subIcon(sub) or H.icon("book", book - 1)
      if key then out.infoIcon, out.hasInfoIcon = key, true end
    end
  elseif tip >= 1000 and tip <= 1007 then
    local n = tip - 1000
    out.info = H.SUBWEAPONS[n] .. ": " .. H.subHearts(n) .. " heart" .. (H.subHearts(n) == 1 and "" or "s") .. " a throw."
    out.infoIcon, out.hasInfoIcon = H.subIcon(n) or "", true
  elseif tip >= 0xF7 and tip <= 0x1CB then
    out.info = H.text(tip - 0xF7 + 0x22) .. ": " .. H.text(tip):gsub("%s*\n%s*", " ")
    local g0 = tip - 0xF7 - H.LIST.book.base
    if g0 >= 0 and g0 < 5 and mem.u8(A.spell) == (0x80 | (g0 + 1)) then out.info = out.info .. " (ON)" end
    local g = tip - 0xF7
    for kind, L in pairs(H.LIST) do
      if g >= L.base and g < L.base + L.n then
        local key = H.icon(kind, g - L.base)
        if key then out.infoIcon, out.hasInfoIcon = key, true end
      end
    end
  end
end

function update(ui)
  local out = { ready = false, waiting = true, release = "Release " .. GAME_CODE }
  local page = ui.page or "status"
  for _, p in ipairs(PAGES) do out["nav" .. p:sub(1, 1):upper() .. p:sub(2)] = page == p end
  if GAME_CODE ~= H.CODE then
    out.waitingText = "This pack is for the US release (ACHE)."
    return out
  end
  local state = mem.u8(A.gameState)
  local hp, maxHp, lv = mem.u16(A.hp), mem.u16(A.maxHp), mem.u8(A.level)
  if state ~= 3 or maxHp == 0 or maxHp > 9999 or hp > maxHp or lv > 99 then
    out.waitingText = state == 7 and "Game over. Continue or load a save." or "Load a save to begin."
    Battle.reset()
    return out
  end
  out.ready, out.waiting = true, false
  local chr = mem.u32(A.character)

  -- header
  local place = H.place()
  out.area = place and place.area or "Dracula's Castle"
  out.hasCastle = place ~= nil
  out.castleB = place and place.castleB or false
  out.castle = out.castleB and "B" or "A"
  out.time = clock(mem.u32(A.playTime))
  out.gold = commas(mem.u32(A.gold)) .. "G"
  out.title = page == "status" and (chr == 2 and H.text(H.T.char + 1) or (H.text(H.T.char) .. " " .. H.text(H.T.char + 6)))
              or TITLES[page] or ""
  out.soonLine = SOON[page] or ""

  out.isMaxim = chr == 2
  if page == "status" or page == "battle" then vitals(out, chr) end
  if page == "status" then statusPage(out, ui, chr) end
  Battle.page(out, ui, chr)            -- every tick: a boss opens the BATTLE page by itself
  if page == "battle" then Magic.castNow(out) end
  if page == "book" then Book.page(out, ui) end
  if page == "map" then Map.page(out, ui) end
  if page == "journey" then Journey.page(out, ui, chr) end
  out.notMaxim = chr ~= 2
  if page == "magic" then Magic.page(out, ui) end
  if page == "items" then
    Items.page(out, ui)
    out.noDet = not out.det.has
  else
    out.det, out.noDet = { has = false }, true
  end
  information(out, ui, page)
  return out
end

actions = {}
