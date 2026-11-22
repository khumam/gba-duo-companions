-- battle.lua : the BATTLE page — Juste (or Maxim) and the enemies in the room, from entity memory.
-- Entities 0x02000418 + 0x80·k; enemy = valid enemy id at +0x3E with 1 <= HP (+0x3C) <= the DNA max HP.
-- Enemy DNA 0x080C7E38, 0x24 bytes: +8 drop1, +9 drop1 type, +A drop2, +B drop2 type, +C HP, +E EXP, +10 Lv,
-- +12/+13 drop chances, +14 ATK, +20 tolerance bits, +21 weakness bits (Fire Ice Thunder Wind).
local H = pack.require("hod")
local A = H.A
local M = {}

local ENT, ENT_SIZE, FIRST, LAST = 0x02000418, 0x80, 0x10, 0xCF
local DNA, DNA_SIZE = 0x080C7E38, 0x24
local ELEMENTS = { "FIRE", "ICE", "THUNDER", "WIND" }
-- Bosses (enemy ids; +125 = the stronger copies): Giant Bat … Dracula Wraith. Talos 119 is the intro chase.
local BOSS = {}
for _, i in ipairs({ 9, 17, 30, 31, 40, 46, 54, 55, 66, 67, 68, 73, 83, 84, 85, 86, 87, 96, 97, 98, 99 }) do
  BOSS[i], BOSS[i + 125] = true, true
end
M.TIP = 3000                                   -- tip ids 3000 + DNA index (book, boss)
M.TIP_FOE = 10000                              -- 10000 + slot·256 + DNA index (one enemy in the room)

function M.dna(i)
  local a = DNA + DNA_SIZE * i
  return { hp = mem.u16(a + 0xC), exp = mem.u16(a + 0xE), lv = mem.u8(a + 0x10), atk = mem.u16(a + 0x14),
           res = mem.u8(a + 0x20), weak = mem.u8(a + 0x21),
           drops = { { id = mem.u8(a + 8), kind = mem.u8(a + 9), chance = mem.u8(a + 0x12) },
                     { id = mem.u8(a + 10), kind = mem.u8(a + 11), chance = mem.u8(a + 0x13) } } }
end

local valid = {}
function M.name(i)
  local n = H.text(H.T.enemy + i % 125)
  return n
end
local function isEnemy(i)
  local v = valid[i]
  if v == nil then
    local n = M.name(i)
    v = n ~= "NULL" and n ~= "" and n ~= "???"
    valid[i] = v
  end
  return v
end

function M.chips(mask)
  local out = {}
  for k = 1, 4 do if mask & (1 << (k - 1)) ~= 0 then out[#out + 1] = { text = ELEMENTS[k] } end end
  return out
end

-- Live enemies: { slot, id, hp, max, boss }
function M.scan()
  local list, boss = {}, nil
  for k = FIRST, LAST do
    local e = ENT + ENT_SIZE * k
    if mem.u32(e) ~= 0 then
      local id, hp = mem.u8(e + 0x3E), mem.u16(e + 0x3C)
      if id < 250 and hp > 0 and isEnemy(id) then
        local max = mem.u16(DNA + DNA_SIZE * id + 0xC)
        if hp <= max then
          local f = { slot = k, id = id, hp = hp, max = max, boss = BOSS[id] or false }
          list[#list + 1] = f
          if f.boss and not boss then boss = f end
        end
      end
    end
  end
  return list, boss
end

-- Drops in the game's words: money tiers are the menu texts 0x249.. ("$1", "$5", …).
local KIND = { [3] = "cons", [4] = "whip", [5] = "armor", [6] = "book", [7] = "relic", [8] = "furn" }
function M.dropText(d)
  if d.kind == 1 then return H.text(0x249 + d.id) end
  local kind = KIND[d.kind]
  if kind and d.id < H.LIST[kind].n then return H.name(kind, d.id) end
  return nil
end

function M.tipText(tip)
  local i = tip >= M.TIP_FOE and (tip - M.TIP_FOE) % 256 or tip - M.TIP
  local d = M.dna(i)
  local parts = { M.name(i) .. ": Lv " .. d.lv, "HP " .. d.hp, "ATK " .. d.atk, "EXP " .. d.exp }
  local drops = {}
  for _, x in ipairs(d.drops) do local s = M.dropText(x); if s then drops[#drops + 1] = s end end
  if #drops > 0 then parts[#parts + 1] = "drops " .. table.concat(drops, ", ") end
  return table.concat(parts, " · ") .. "."
end

-- ---- auto open / close + result ----------------------------------------------------------
local opened, lastBoss, flagsAtStart, result, resultTicks = false, nil, 0, nil, 0
local RESULT_TICKS = 24                        -- ~6 s at tickHz 4

function M.reset() opened, lastBoss, result, resultTicks = false, nil, nil, 0 end

function M.page(out, ui, chr)
  local tip = tonumber(ui.tip) or -1
  local list, boss = M.scan()
  local flags = mem.u32(A.bossFlags)

  -- edges
  if boss then
    if not opened then
      opened, flagsAtStart, result = true, flags, nil
      if ui.page ~= "battle" then out.ui = { navigate = "battle" } end
    end
    lastBoss = boss
  elseif opened then
    opened = false
    if lastBoss and flags & ~flagsAtStart ~= 0 then        -- a boss death bit was set: the boss fell
      local d = M.dna(lastBoss.id)
      result = { name = M.name(lastBoss.id), exp = d.exp }
      resultTicks = RESULT_TICKS
    elseif ui.page == "battle" then
      out.ui = { back = true }
    end
    lastBoss = nil
  end
  if result then
    resultTicks = resultTicks - 1
    if resultTicks <= 0 then
      result = nil
      if ui.page == "battle" then out.ui = { back = true } end
    end
  end

  -- boss card
  out.hasBoss = boss ~= nil
  if boss then
    local d = M.dna(boss.id)
    out.boss = { name = M.name(boss.id), lv = tostring(d.lv), hp = boss.hp .. "/" .. boss.max,
                 hpPct = boss.hp / boss.max, low = boss.hp * 4 <= boss.max, atk = tostring(d.atk),
                 exp = tostring(d.exp), weak = M.chips(d.weak), res = M.chips(d.res),
                 tip = M.TIP + boss.id, sel = M.TIP + boss.id == tip,
                 book = boss.id % 125, inBook = boss.id % 125 < 100 }
    out.boss.hasWeak, out.boss.hasRes = #out.boss.weak > 0, #out.boss.res > 0
  else
    out.boss = { name = "-", lv = "-", hp = "-", hpPct = 0, low = false, atk = "-", exp = "-", weak = {}, res = {},
                 hasWeak = false, hasRes = false, tip = -1, sel = false, book = -1, inBook = false }
  end
  out.hasResult = result ~= nil
  out.resultName = result and result.name or "-"
  out.resultExp = result and ("+" .. result.exp .. " EXP") or "-"

  -- other enemies
  local rows = {}
  for _, f in ipairs(list) do
    if not (boss and f.slot == boss.slot) then
      local d = M.dna(f.id)
      local w = M.chips(d.weak)
      local t = M.TIP_FOE + f.slot * 256 + f.id
      rows[#rows + 1] = { name = M.name(f.id), lv = "Lv" .. d.lv, hp = f.hp .. "/" .. f.max, hpPct = f.hp / f.max,
                          low = f.hp * 4 <= f.max, weak = w, hasWeak = #w > 0, tip = t, sel = t == tip }
    end
  end
  out.foes, out.hasFoes, out.noFoes = rows, #rows > 0, #rows == 0
  out.foeCount = tostring(#rows)
  out.foeHead = boss and "BESIDE THE BOSS" or "IN THIS ROOM"
  out.noFoesText = boss and "Only the boss." or "No enemies in this room."
end

return M
