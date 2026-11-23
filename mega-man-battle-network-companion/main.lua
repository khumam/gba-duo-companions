-- Mega Man Battle Network (USA, AREE) companion. RAM and ROM map: NOTES.md
local ZENNY, HP, STAT, ARMOR = 0x02000284, 0x0200022C, 0x02000224, 0x02000227
local FOLDER, SACK = 0x020001C0, 0x020002CF
local MAILORD, MAILHDR, MAILBODY = 0x02001FA0, 0x087A7F48, 0x087A83C8      -- received order (u8 ids, 0x40 = empty), ROM tables
local ITEMCNT, ITEMNAMES, ITEMDESC = 0x020002D0, 0x0869FD50, 0x086A0118   -- key item counts (u8 per id), ROM tables
local PACK, WINS, LOSSES = 0x020004B0, 0x020003E6, 0x020003E4
local NAMES, DESCS, CHIPS = 0x0869D57C, 0x0869E310, 0x08007D7C
local ORDER = {0,1,2,3,14,15,10,11,12,13,7,8,9,4,5,6,30,32,33,25,27,26,136,16,17,18,19,20,21,22,23,24,28,29,31,43,37,38,39,58,59,60,133,134,135,127,128,129,44,45,46,112,113,114,40,41,42,49,50,51,121,122,123,55,64,65,52,34,145,67,68,69,70,71,72,73,74,76,79,80,82,83,88,97,98,99,91,92,93,124,125,126,139,140,141,105,106,107,61,62,63,115,116,117,142,94,95,108,109,110,111,118,119,100,101,102,137,138,103,147,130,131,132,146,85,86,87,84,160,161,162,163,164,165,166,167,168,172,173,174,175,176,177,178,179,180,181,182,183,187,188,189,196,197,198,190,191,192,157,158,159,169,170,171,184,185,186,193,194,195,148,149,150,151,152,153,199}
local ARMORS = { [0] = "Armor", [2] = "HeatArmr", [3] = "AquaArmr", [4] = "WoodArmr" }
local ARMOR_SEQ = { 0, 2, 3, 4 }
local STATS = { "ATTACK", "RAPID", "CHARGE" }
local PUNCT = { [0]="!", [2]="?", [3]="\"", [9]="&", [10]="'", [11]="(", [12]=")", [18]=":", [20]=", ", [22]=".", [24]="/", [29]="(", [30]=")", [44]="@", [54]=":", [61]="=" }

local function charOf(b)
  if b == 0 then return " " end
  if b >= 1 and b <= 10 then return tostring(b - 1) end
  if b == 0x5E then return "-" end
  if b >= 0x5F and b <= 0x78 then return string.char(65 + b - 0x5F) end
  if b >= 0x79 and b <= 0x92 then return string.char(97 + b - 0x79) end
  return nil
end

local nameCache, descCache = {}, {}
local function text(tbl, id, desc)
  local base = mem.u16(tbl + id * 2)
  local a, out = tbl + base, {}
  for _ = 1, 64 do
    local b = mem.u8(a)
    if b == 0xE7 then break end
    if b == 0xE5 then a = a + 1; out[#out + 1] = PUNCT[mem.u8(a)] or "?"
    elseif b == 0 then out[#out + 1] = " "
    elseif b >= 1 and b <= 10 then out[#out + 1] = tostring(b - 1)
    elseif b == 0x5E then out[#out + 1] = "-"
    elseif b >= 0x5F and b <= 0x78 then out[#out + 1] = string.char(65 + b - 0x5F)
    elseif b >= 0x79 and b <= 0x92 then out[#out + 1] = string.char(97 + b - 0x79)
    elseif b == 0xE8 then out[#out + 1] = " "
    else out[#out + 1] = "?" end
    a = a + 1
  end
  return table.concat(out)
end
local function nameOf(id)
  local n = nameCache[id]
  if not n then n = text(NAMES, id, false); nameCache[id] = n end
  return n
end
local function descOf(id)
  local d = descCache[id]
  if not d then d = text(DESCS, id, true); descCache[id] = d end
  return d
end
local function letter(code) if code == 26 then return "*" end return string.char(65 + (code % 26)) end

local function chipArt(id, big)
  local rec = CHIPS + 28 * id
  local tiles = mem.u32(rec + (big and 8 or 4))
  local pal = mem.u32(rec + 12)
  if tiles < 0x08000000 or tiles >= 0x0A000000 then return "" end
  local ok, img = pcall(gfx.decode, { tiles = tiles, palette = pal, width = big and 64 or 16, height = big and 56 or 16 })
  return ok and img or ""
end
local function codes(id)
  local rec, out = CHIPS + 28 * id, {}
  for i = 0, 4 do
    local c = mem.u8(rec + 16 + i)
    if c < 27 then out[#out + 1] = { code = c, ch = letter(c), idx = id } end
  end
  return out
end
local function stars(n) return string.rep("*", n) end

local function validFolder()
  local n = 0
  for i = 0, 29 do
    local id, c = mem.u8(FOLDER + 2 * i), mem.u8(FOLDER + 2 * i + 1)
    if id == 0 or id > 0xC7 or c > 26 then return false end
    n = n + 1
  end
  return n == 30
end

local function chipView(id, code)
  local atk = mem.u16(CHIPS + 28 * id)
  return { id = id, name = nameOf(id), code = letter(code), codeN = code, atk = atk, hasAtk = atk > 0 and atk < 1000,
           atkText = atk > 0 and atk < 1000 and tostring(atk) or "", icon = chipArt(id, false), art = chipArt(id, true),
           desc = descOf(id), no = string.format("%03d", id) }
end

function update(ui)
  local out = { ready = false, waiting = true }
  if not validFolder() then return out end
  local zenny = mem.u32(ZENNY)
  if zenny > 99999999 then return out end
  out.ready, out.waiting = true, false
  out.zenny = tostring(zenny) .. "Z"
  -- folder
  local rows, selSlot = {}, tonumber(ui.slot) or 0
  for i = 0, 29 do
    local v = chipView(mem.u8(FOLDER + 2 * i), mem.u8(FOLDER + 2 * i + 1))
    v.slot, v.sel = i, (i == selSlot)
    v.odd = (i % 2 == 1)
    rows[#rows + 1] = v
  end
  out.folder = rows
  out.selChip = rows[selSlot + 1]
  local cs = codes(rows[selSlot + 1].id)
  for _, c in ipairs(cs) do c.slot = selSlot; c.on = (c.code == rows[selSlot + 1].codeN) end
  out.selCodes = cs
  -- library
  local lib, seen = {}, 0
  local libSel = tonumber(ui.lib) or 1
  local selLib
  for _, id in ipairs(ORDER) do
    if id ~= 0 and mem.u8(SACK + id) ~= 0xFF then
      seen = seen + 1
      local owned = mem.u8(SACK + id)
      local e = { no = tostring(seen), id = id, name = nameOf(id), owned = owned, hasOwned = owned > 0,
                  ownedText = owned > 0 and ("x" .. owned) or "", sel = (id == libSel), odd = (seen % 2 == 0) }
      lib[#lib + 1] = e
      if id == libSel then selLib = e end
    end
  end
  if not selLib and lib[1] then selLib = lib[1]; selLib.sel = true end
  out.library, out.libCount = lib, seen
  if selLib then
    local v = chipView(selLib.id, 0)
    v.owned, v.no = selLib.owned, selLib.no
    v.codes = nil
    out.libChip = v
    local lc = codes(selLib.id)
    local s = {}
    for _, c in ipairs(lc) do s[#s + 1] = c.ch end
    out.libCodes = table.concat(s, " ")
  end
  -- MegaMan
  local hp = mem.u16(HP)
  out.hp = tostring(hp)
  local lv = {}
  local sum = 0
  for i = 0, 2 do
    local n = mem.u8(STAT + i)
    if n > 4 then n = 4 end
    sum = sum + n
    local pips = {}
    for p = 0, 4 do pips[#pips + 1] = { stat = i, level = p, on = (p <= n) } end
    lv[#lv + 1] = { name = STATS[i + 1], stat = i, pips = pips, value = n + 1 }
  end
  out.stats = lv
  out.level = tostring(math.min(100, 64 + 3 * sum))
  local a = mem.u8(ARMOR)
  out.armor = ARMORS[a] or "Armor"
  local armors = {}
  for _, n in ipairs(ARMOR_SEQ) do armors[#armors + 1] = { id = n, name = ARMORS[n], on = (n == a) } end
  out.armors = armors
  return out
end

actions = {}
function actions.setCode(slot, code)
  slot, code = tonumber(slot), tonumber(code)
  if not slot or slot < 0 or slot > 29 or not code or code < 0 or code > 26 then return end
  local id = mem.u8(FOLDER + 2 * slot)
  local rec = CHIPS + 28 * id
  for i = 0, 4 do
    if mem.u8(rec + 16 + i) == code then mem.write8(FOLDER + 2 * slot + 1, code); return end
  end
end
function actions.setStat(stat, level)
  stat, level = tonumber(stat), tonumber(level)
  if stat and stat >= 0 and stat <= 2 and level and level >= 0 and level <= 4 then mem.write8(STAT + stat, level) end
end
function actions.setArmor(n)
  n = tonumber(n)
  if ARMORS[n] then mem.write8(ARMOR, n) end
end

-- ---- Email ------------------------------------------------------------------------------------
local MARGS = { [0xE9] = 2, [0xED] = 3, [0xF2] = 1, [0xF3] = 1, [0xFA] = 1 }   -- script opcodes and their argument bytes
local mailCache, pageCache = {}, {}
local function mailHead(id)
  local m = mailCache[id]
  if m then return m end
  local t = text(MAILHDR, id, false)
  m = { sender = (t:sub(1, 10):gsub("%s+$", "")), subject = (t:sub(11):gsub("^%s+", "")) }
  mailCache[id] = m
  return m
end
local function mailPages(id)
  local p = pageCache[id]
  if p then return p end
  local first, last = MAILBODY + mem.u16(MAILBODY + id * 2), MAILBODY + mem.u16(MAILBODY + (id + 1) * 2)
  local pages, run, special, a = {}, {}, false, first
  local function finish()
    local s = table.concat(run):gsub("^%s+", ""):gsub("%s+$", "")
    if s ~= "" and not special then pages[#pages + 1] = s end
    run, special = {}, false
  end
  while a < last do
    local b = mem.u8(a)
    if b == 0xEB then finish(); a = a + 1
    elseif MARGS[b] then a = a + 1 + MARGS[b]
    elseif b == 0xE5 then
      local c = mem.u8(a + 1)
      if c ~= 3 then run[#run + 1] = PUNCT[c] or "?" end
      a = a + 2
    elseif b == 0xE8 then run[#run + 1] = "\n"; a = a + 1
    elseif b == 0xFB then
      if mem.u8(a + 1) == 0 and mem.u8(a + 2) == 0 and mem.u8(a + 3) == 0 then run[#run + 1] = "Lan"; a = a + 4
      else special = true; a = a + 1 end
    elseif b >= 0xE0 then special = true; a = a + 1
    else run[#run + 1] = charOf(b) or "?"; a = a + 1 end
  end
  finish()
  pageCache[id] = pages
  return pages
end
local function mailList()
  local ids = {}
  for i = 0, 39 do
    local id = mem.u8(MAILORD + i)
    if id == 0x40 or id > 32 then break end
    ids[#ids + 1] = id
  end
  return ids
end

-- ---- Items ------------------------------------------------------------------------------------
local CHARGE_ITEMS = { [1] = true, [9] = true, [10] = true, [11] = true, [12] = true, [13] = true }
local itemDescCache = {}
local function itemDesc(id)
  local d = itemDescCache[id]
  if d then return d end
  local a, out = ITEMDESC + mem.u16(ITEMDESC + id * 2), {}
  for _ = 1, 160 do
    local b = mem.u8(a)
    if b == 0xEA or b == 0xFF or b == 0x0B or b == 0xE7 then break end
    if b == 0xFC or b == 0xF5 or b == 0xF2 then a = a + 2
    elseif b == 0xEC then a = a + 3
    elseif b == 0xE5 then
      local c = mem.u8(a + 1)
      if c == 11 and CHARGE_ITEMS[id] then break end        -- "(charges left: N)": the number is live, written below
      out[#out + 1] = PUNCT[c] or "?"; a = a + 2
    elseif b == 0xE8 then out[#out + 1] = " "; a = a + 1
    elseif b >= 0xE0 then a = a + 1
    else out[#out + 1] = charOf(b) or "?"; a = a + 1 end
  end
  d = (table.concat(out):gsub("%s+$", ""))
  itemDescCache[id] = d
  return d
end
local function itemKind(name)
  local c = name:sub(1, 1)
  if c == "@" then return "Net address" end
  if c == "/" then return "Pass" end
  if name:find("Memo", 1, true) or name:find("memory", 1, true) then return "Memo" end
  return "Key item"
end

-- ---- Network ----------------------------------------------------------------------------------
local NET_ROWS = { "Trade", "Battle(test)", "Battle(real!)" }
local NET_NOTE = { "Trade chips with a friend. Needs a link cable.", "A practice battle with a friend. Needs a link cable.",
                   "A real battle, the loser gives up a chip. Needs a link cable." }
local function packTotal()
  local s = 0
  for i = 0, 199 do
    local a = PACK + 16 * i
    s = s + mem.u8(a)
    for k = 1, 5 do s = s + mem.u8(a + k) end
  end
  return s
end

local function lines(s)
  local t = {}
  for l in (s .. "\n"):gmatch("(.-)\n") do t[#t + 1] = l end
  return t
end

local mailNow = { pg = 0, n = 1 }          -- last page shown, for the pager buttons
local baseUpdate = update
function update(ui)
  local out = baseUpdate(ui)
  if not out.ready then return out end
  -- email
  local ids = mailList()
  local mails, selMail = {}, tonumber(ui.mail)
  local hasSel = false
  for n = #ids, 1, -1 do
    if ids[n] == selMail then hasSel = true end
  end
  if not hasSel then selMail = ids[#ids] end
  for n = #ids, 1, -1 do
    local id = ids[n]
    local h = mailHead(id)
    mails[#mails + 1] = { id = id, sender = h.sender, subject = h.subject, sel = (id == selMail), odd = (#mails % 2 == 1) }
  end
  out.mails, out.mailCount, out.hasMail, out.noMail = mails, tostring(#ids), #ids > 0, #ids == 0
  if selMail then
    local h, pages = mailHead(selMail), mailPages(selMail)
    local pg = math.max(0, math.min(#pages - 1, tonumber(ui.mpage) or 0))
    local ls = lines(pages[pg + 1] or "")
    out.mail = { sender = h.sender, subject = h.subject, l1 = ls[1] or "", l2 = ls[2] or "", l3 = ls[3] or "", l4 = ls[4] or "",
                 pageText = tostring(pg + 1) .. "/" .. tostring(math.max(1, #pages)) }
    out.mailPrev, out.mailNext = math.max(0, pg - 1), math.min(math.max(0, #pages - 1), pg + 1)
    mailNow.pg, mailNow.n = pg, #pages
    out.mailFirst, out.mailLast = pg == 0, pg >= #pages - 1
  else
    out.mail = { sender = "", subject = "", l1 = "No mail yet.", l2 = "", l3 = "", l4 = "", pageText = "" }
    out.mailPrev, out.mailNext, out.mailFirst, out.mailLast = 0, 0, true, true
  end
  -- items
  local items, selItem, count = {}, tonumber(ui.item), 0
  local owned = {}
  for id = 0, 63 do
    if mem.u8(ITEMCNT + id) > 0 and mem.u16(ITEMNAMES + id * 2) ~= 0 then
      local nm = text(ITEMNAMES, id, false)
      if nm:gsub("%s", "") ~= "" then owned[#owned + 1] = id end
    end
  end
  local hasItem = false
  for _, id in ipairs(owned) do if id == selItem then hasItem = true end end
  if not hasItem then selItem = owned[1] end
  for n, id in ipairs(owned) do
    local nm = nameCache[1000 + id]
    if not nm then nm = text(ITEMNAMES, id, false); nameCache[1000 + id] = nm end
    local c = mem.u8(ITEMCNT + id)
    items[#items + 1] = { id = id, name = nm, count = c, countText = CHARGE_ITEMS[id] and ("x" .. c) or "", sel = (id == selItem), odd = (n % 2 == 0) }
  end
  out.items, out.itemCount = items, tostring(#owned)
  if selItem then
    local nm = nameCache[1000 + selItem] or text(ITEMNAMES, selItem, false)
    local c = mem.u8(ITEMCNT + selItem)
    local d = itemDesc(selItem)
    if CHARGE_ITEMS[selItem] then d = d .. " (charges left:" .. c .. ")" end
    out.item = { name = nm, desc = d, kind = itemKind(nm), countText = CHARGE_ITEMS[selItem] and ("x" .. c) or "" }
  else
    out.item = { name = "", desc = "", kind = "", countText = "" }
  end
  -- network
  local sel = math.max(0, math.min(2, tonumber(ui.net) or 0))
  local rows = {}
  for i = 0, 2 do rows[#rows + 1] = { i = i, name = NET_ROWS[i + 1], sel = (i == sel), odd = (i % 2 == 1) } end
  out.netRows, out.netNote = rows, NET_NOTE[sel + 1]
  out.chips = tostring(packTotal())
  out.wins, out.losses = tostring(mem.u16(WINS)), tostring(mem.u16(LOSSES))
  return out
end

function actions.mailStep(d)
  d = tonumber(d) or 0
  local pg = math.max(0, math.min(mailNow.n - 1, mailNow.pg + d))
  return { set = { mpage = pg } }
end
