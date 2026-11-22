-- magic.lua : the MAGIC page — spell book × subweapon grid (MP costs from the ROM) and the 12 relics.
-- Spell list 0x080E29D4: 6 groups of 8 entries (0xC bytes): group = spell book (1 Fire … 5 Summoning),
-- slot = subweapon (0 none, 1 knife … 7 shuriken); +0 code (0 = no spell), +6 u16 MP, +8 u16 hearts.
local H = pack.require("hod")
local A = H.A
local M = {}

local SPELLS = 0x080E29D4
local COLS = { 1, 2, 3, 4, 5, 6, 0 }       -- Juste's subweapons, then "no subweapon" (shuriken is Maxim's)
local TIP_SPELL, TIP_BOOK = 2000, 0          -- tip ids: 2000 + book*8 + sub

local function spell(book, sub)
  local a = SPELLS + 0xC * (book * 8 + sub)
  if mem.u32(a) == 0 then return nil end
  return { mp = mem.u16(a + 6), hearts = mem.u16(a + 8) }
end

function M.spellText(tip)
  local book, sub = (tip - TIP_SPELL) // 8, (tip - TIP_SPELL) % 8
  local s = spell(book, sub)
  if not s then return nil end
  local who = H.name("book", book - 1) .. (sub == 0 and " with no subweapon" or (" + " .. H.SUBWEAPONS[sub]))
  local cost = s.mp > 0 and (s.mp .. " MP") or (s.hearts .. " hearts")
  return who .. ": a spell for " .. cost .. ".", book, sub
end

-- What the subweapon button does right now: out.castNow (+ icon of the subweapon).
function M.castNow(out)
  local owned = mem.u8(A.booksOwned)
  local sp = mem.u8(A.spell)
  local curBook, bookOn, curSub = sp & 0x7F, sp & 0x80 ~= 0, mem.u8(A.subweapon)
  if curBook >= 1 and curBook <= 5 and bookOn and owned & (1 << (curBook - 1)) ~= 0 then
    local s = spell(curBook, curSub)
    out.castNow = s and (H.name("book", curBook - 1) .. " + " .. (H.SUBWEAPONS[curSub] or "no subweapon") .. ": " .. s.mp .. " MP")
                  or (H.name("book", curBook - 1) .. " ON, no spell with this subweapon")
  elseif curSub >= 1 and curSub <= 7 then
    out.castNow = (mem.u32(A.character) == 2 and "Subweapon: " or "Book OFF: throws the ") .. H.SUBWEAPONS[curSub] ..
                  " (" .. H.subHearts(curSub) .. " hearts)"
  else
    out.castNow = "No subweapon and no spell book ON"
  end

  local key = curSub >= 1 and curSub <= 7 and H.subIcon(curSub) or nil
  out.castIcon, out.hasCastIcon = key or "", key ~= nil
end

function M.page(out, ui)
  local tip = tonumber(ui.tip) or -1
  local owned = mem.u8(A.booksOwned)
  local sp = mem.u8(A.spell)
  local curBook, bookOn, curSub = sp & 0x7F, sp & 0x80 ~= 0, mem.u8(A.subweapon)

  local heads = {}
  for _, s in ipairs(COLS) do
    local key = s > 0 and H.subIcon(s) or nil
    heads[#heads + 1] = { icon = key or "", hasIcon = key ~= nil, none = s == 0, cur = s == curSub }
  end
  out.spellHeads = heads

  local rows, nBooks = {}, 0
  for b = 1, 5 do
    local has = owned & (1 << (b - 1)) ~= 0
    if has then nBooks = nBooks + 1 end
    local r = { owned = has, missing = not has, on = has and b == curBook and bookOn,
                cur = has and b == curBook, tip = has and H.descId("book", b - 1) or -1 }
    r.name = has and H.name("book", b - 1) or H.text(0x253)
    local key = has and H.icon("book", b - 1) or nil
    r.icon, r.hasIcon = key or "", key ~= nil
    r.sel = has and r.tip == tip
    local cells = {}
    for _, s in ipairs(COLS) do
      local sv = has and spell(b, s) or nil
      local c = { has = sv ~= nil, none = sv == nil, tip = -1, text = "-", cur = false, sel = false, off = false }
      if sv then
        c.text = tostring(sv.mp > 0 and sv.mp or sv.hearts)
        c.tip = TIP_SPELL + b * 8 + s
        c.cur = b == curBook and s == curSub
        c.off = c.cur and not bookOn
        c.sel = c.tip == tip
      end
      cells[#cells + 1] = c
    end
    r.cells = cells
    rows[#rows + 1] = r
  end
  out.spellRows = rows
  out.bookCount = nBooks .. "/5"

  M.castNow(out)

  -- relics
  local ro = mem.u8(A.relicsOwned) | (mem.u8(A.relicsOwned + 1) << 8)
  local on = mem.u8(A.relicsOn) | (mem.u8(A.relicsOn + 1) << 8)
  local relics, n = {}, 0
  for i = 0, H.LIST.relic.n - 1 do
    local has = ro & (1 << i) ~= 0
    local r = { owned = has, missing = not has, on = has and on & (1 << i) ~= 0, tip = -1, sel = false,
                name = H.text(0x253), icon = "", hasIcon = false, vlad = i >= 6 }
    if has then
      n = n + 1
      r.name, r.tip = H.name("relic", i), H.descId("relic", i)
      local key = H.icon("relic", i)
      r.icon, r.hasIcon = key or "", key ~= nil
      r.sel = r.tip == tip
    end
    relics[#relics + 1] = r
  end
  out.relicRows = relics
  out.relicCount = n .. "/" .. H.LIST.relic.n
end

return M
