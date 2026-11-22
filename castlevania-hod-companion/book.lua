-- book.lua : the BOOK page — the game's Encyclopedia (enemies 0–99, No. = id + 1).
-- Killed bits 0x02018854 (bit = enemy id; the game lists only these). Drop names are known per enemy:
-- 0x02018864 bit id = drop 1, bit 128 + id = drop 2 (else the game shows "??????????").
local H = pack.require("hod")
local Battle = pack.require("battle")
local A = H.A
local M = {}

local COUNT = 100
local KNOWN = 0x02018864
local UNKNOWN = 0x253

local function bit(base, n) return mem.u8(base + (n >> 3)) & (1 << (n & 7)) ~= 0 end
local function two(n) return n < 10 and ("0" .. n) or tostring(n) end
local BOSS = {}
for _, i in ipairs({ 9, 17, 30, 31, 40, 46, 54, 55, 66, 67, 68, 73, 83, 84, 85, 86, 87, 96, 97, 98, 99 }) do BOSS[i] = true end

function M.killed(i) return bit(A.kills, i) end

function M.page(out, ui)
  local reveal = ui.rv == true or ui.rv == "true"
  local sel = tonumber(ui.bk) or -1
  local rows, n = {}, 0
  for i = 0, COUNT - 1 do
    local k = M.killed(i)
    if k then n = n + 1 end
    local show = k or reveal
    rows[#rows + 1] = { no = two(i + 1), name = show and Battle.name(i) or H.text(UNKNOWN), killed = k,
                        hidden = not k, boss = show and BOSS[i] or false, id = i, sel = i == sel }
  end
  out.bookRows = rows
  out.killCount = n .. "/" .. COUNT
  out.reveal, out.noReveal = reveal, not reveal

  -- the card (the game's Encyclopedia page)
  local c = { has = false }
  if sel >= 0 and sel < COUNT then
    local k = M.killed(sel)
    c.has, c.no, c.killed = true, two(sel + 1), k
    c.show = k or reveal
    c.locked = not c.show
    c.unmet = (not k) and reveal
    if c.show then
      local d = Battle.dna(sel)
      c.name, c.lv, c.hp, c.exp, c.atk = Battle.name(sel), tostring(d.lv), tostring(d.hp), tostring(d.exp), tostring(d.atk)
      c.res, c.weak = Battle.chips(d.res), Battle.chips(d.weak)
      c.hasRes, c.hasWeak, c.noRes, c.noWeak = #c.res > 0, #c.weak > 0, #c.res == 0, #c.weak == 0
      local drops = {}
      for j, x in ipairs(d.drops) do
        local known = bit(KNOWN, (j == 1 and 0 or 128) + sel)
        local text = Battle.dropText(x)
        drops[#drops + 1] = { text = text and (known and text or H.text(UNKNOWN)) or H.text(0x25D), q = text ~= nil and not known }
      end
      c.drops = drops
      c.boss = BOSS[sel] or false
    else
      c.name, c.lv, c.hp, c.exp, c.atk = H.text(UNKNOWN), "?", "?", "?", "?"
      c.res, c.weak, c.drops = {}, {}, {}
      c.hasRes, c.hasWeak, c.noRes, c.noWeak, c.boss = false, false, true, true, false
    end
  end
  out.card, out.noCard = c, not c.has
end

return M
