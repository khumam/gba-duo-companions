-- items.lua : the ITEMS page (views ITEMS / KEY ITEMS / WHIP / ARMOR + detail card).
-- Selection is ui.tip (a description text id), shared with the INFORMATION bar.
local H = pack.require("hod")
local A = H.A
local M = {}

local UNKNOWN = 0x253          -- the game's "??????????"
local USE = {}                 -- consumables shown in ITEMS: 0-9 and the jewels 22-27
for i = 0, 9 do USE[#USE + 1] = i end
for i = 22, 27 do USE[#USE + 1] = i end
local KEYS = {}                -- keys 10-12, castle maps 13-15, hint cards 16-21
for i = 10, 21 do KEYS[#KEYS + 1] = i end
local FILTERS = { { "BODY", { [2] = true } }, { "HEAD", { [3] = true } },
                  { "HANDS", { [1] = true } }, { "LEGS", { [4] = true, [12] = true } }, { "GOODS", { [0] = true } } }
local VISIBLE = 22             -- rows that fit without scrolling (2 columns)

local function two(n) return n < 10 and ("0" .. n) or tostring(n) end
local function signed(v) return v > 0 and ("+" .. v) or tostring(v) end

local function cell(kind, i, tip, opts)
  local key = H.icon(kind, i)
  local c = { name = H.name(kind, i), icon = key or "", hasIcon = key ~= nil, tip = H.descId(kind, i),
              owned = true, missing = false, count = "", hasCount = false, equipped = false }
  c.sel = c.tip == tip
  for k, v in pairs(opts or {}) do c[k] = v end
  return c
end

local function locked()
  return { name = H.text(UNKNOWN), icon = "", hasIcon = false, tip = -1, owned = false, missing = true,
           count = "", hasCount = false, equipped = false, sel = false }
end

-- ---- detail card -------------------------------------------------------------------------
local function detail(out, tip)
  local d = { has = false }
  local g = (tonumber(tip) or -1) - 0xF7
  local kind, i
  for k, L in pairs(H.LIST) do
    if g >= L.base and g < L.base + L.n then kind, i = k, g - L.base end
  end
  if not kind or kind == "book" or kind == "relic" or kind == "furn" then out.det = d; return end
  d.has, d.name = true, H.name(kind, i)
  local key = H.icon(kind, i)
  d.icon, d.hasIcon = key or "", key ~= nil
  local lines, chips = {}, {}
  if kind == "cons" then
    local t, n = H.consType(i), H.consAmount(i)
    d.kindText = t == 4 and "KEY ITEM" or "ITEM"
    if t == 0 then lines[#lines + 1] = { label = "HP", value = n >= 999 and "ALL" or ("+" .. n) } end
    if t == 1 then lines[#lines + 1] = { label = "MP", value = n >= 999 and "ALL" or ("+" .. n) } end
    if t == 2 then chips[#chips + 1] = { text = "CURES " .. (n == 1 and "POISON" or n == 2 and "CURSE" or "STATUS") } end
    lines[#lines + 1] = { label = "OWNED", value = two(mem.u8(A.items + i)) }
  elseif kind == "whip" then
    d.kindText = "WHIP"
    local b = H.bonus("whip", i)
    for k = 1, 4 do if b[k] ~= 0 then lines[#lines + 1] = { label = ({ "STR", "DEF", "INT", "LCK" })[k], value = signed(b[k]) } end end
    local e = H.bits("whip", i)
    for k = 1, 4 do if e & (1 << (k - 1)) ~= 0 then chips[#chips + 1] = { text = H.ELEMENT[k]:upper() } end end
    if mem.u8(A.weapon) == i then chips[#chips + 1] = { text = "EQUIPPED", eq = true } end
  elseif kind == "armor" then
    d.kindText = H.SLOT[H.armorType(i)] or "ARMOR"
    local b = H.bonus("armor", i)
    for k = 1, 4 do if b[k] ~= 0 then lines[#lines + 1] = { label = ({ "STR", "DEF", "INT", "LCK" })[k], value = signed(b[k]) } end end
    local worn = 0
    for s = 0, 3 do if mem.u8(A.armor + s) == i then worn = worn + 1 end end
    local r = H.bits("armor", i)
    for k = 1, 7 do if r & (1 << (k - 1)) ~= 0 then chips[#chips + 1] = { text = "RESIST " .. H.RESIST[k]:upper() } end end
    lines[#lines + 1] = { label = "OWNED", value = two(mem.u8(A.armorOwned + i) + worn) }
    if worn > 0 then chips[#chips + 1] = { text = "EQUIPPED", eq = true } end
  end
  for _, c in ipairs(chips) do c.eq = c.eq or false end
  d.lines, d.chips, d.hasLines, d.hasChips = lines, chips, #lines > 0, #chips > 0
  out.det = d
end

-- ---- page ----------------------------------------------------------------------------------
function M.page(out, ui)
  local tip = tonumber(ui.tip) or -1
  local view = ui.iv or "items"
  out.ivItems, out.ivKeys, out.ivWhip, out.ivArmor = view == "items", view == "keys", view == "whip", view == "armor"
  local rows = {}

  if view == "items" then
    for _, i in ipairs(USE) do
      local n = mem.u8(A.items + i)
      if n > 0 then rows[#rows + 1] = cell("cons", i, tip, { count = two(n), hasCount = true }) end
    end
    out.viewCount = #rows .. (#rows == 1 and " KIND" or " KINDS")
    out.emptyText = "No items. Potions, food and jewels you pick up appear here."
  elseif view == "keys" then
    local n = 0
    for _, i in ipairs(KEYS) do
      if mem.u8(A.items + i) > 0 then rows[#rows + 1] = cell("cons", i, tip); n = n + 1
      else rows[#rows + 1] = locked() end
    end
    out.viewCount = n .. "/" .. #KEYS
    out.emptyText = ""
  elseif view == "whip" then
    local bits, n = mem.u16(A.weapons), 0
    local eq = mem.u8(A.weapon)
    for i = 0, H.LIST.whip.n - 1 do
      if bits & (1 << i) ~= 0 then rows[#rows + 1] = cell("whip", i, tip, { equipped = eq == i }); n = n + 1
      else rows[#rows + 1] = locked() end
    end
    out.viewCount = n .. "/" .. H.LIST.whip.n
    out.emptyText = ""
  else
    local af = ui.af or "BODY"
    local want
    for _, f in ipairs(FILTERS) do if f[1] == af then want = f[2] end end
    local worn = {}
    for s = 0, 3 do local id = mem.u8(A.armor + s); if id < 128 then worn[id] = (worn[id] or 0) + 1 end end
    local pieces = 0
    for i = 0, H.LIST.armor.n - 1 do
      local spare = mem.u8(A.armorOwned + i)
      local total = spare + (worn[i] or 0)
      if total > 0 then
        pieces = pieces + total
        if not want or want[H.armorType(i)] then
          rows[#rows + 1] = cell("armor", i, tip, { count = spare > 0 and two(spare) or "", hasCount = spare > 0,
                                                    equipped = worn[i] ~= nil })
        end
      end
    end
    local chips = {}
    local per = {}
    for id = 0, H.LIST.armor.n - 1 do
      if mem.u8(A.armorOwned + id) > 0 or worn[id] then
        for _, f in ipairs(FILTERS) do if f[2][H.armorType(id)] then per[f[1]] = (per[f[1]] or 0) + 1 end end
      end
    end
    for _, f in ipairs(FILTERS) do chips[#chips + 1] = { label = f[1], on = f[1] == af, n = tostring(per[f[1]] or 0) } end
    out.armorFilters = chips
    out.viewCount = pieces .. (pieces == 1 and " PIECE" or " PIECES")
    out.emptyText = "No " .. af:lower() .. " armor yet."
  end

  out.rows, out.listEmpty = rows, #rows == 0
  out.moreCue = #rows > VISIBLE
  out.moreText = "SCROLL FOR " .. math.max(0, #rows - VISIBLE) .. " MORE"
  detail(out, tip)
end

return M
