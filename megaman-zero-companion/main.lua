-- Mega Man Zero (USA, AZCE) memory map. No decompilation exists, so every address here was
-- found by experiment (see NOTES.md). Anything not found yet is shown as "--".

-- Zero's entity struct sits in a static EWRAM pool. +0x0C holds a vtable pointer that is the
-- same whenever the slot really is Zero, which doubles as the "a stage is running" check.
local ENTITY = 0x0202B600
-- +0x0C is a per-state vtable (idle 0x085980E4, walk 0x08598110, jump 0x08598470, ...): every one lies in this ROM range
local VT_LO, VT_HI = 0x08598000, 0x0859A000
local HP = ENTITY + 0x2C            -- u8, 16 = full at rank F
local MAX_HP = 16

-- Save-data fields (found by writing values into RAM in the headless harness and watching the pause screen, see NOTES.md)
local LIVES = 0x0202A5D0         -- u8
local GAME_FRAMES = 0x0202A5D8   -- u32, 60 per second while a stage runs, stops in the pause menu
local CRYSTALS = 0x0202B79E      -- u16
local RANK = 0x0202B718          -- u8: 0 F, 1 E, 2 D, 3 C, 4 B, 5 A, 6 S
local MAIN_WEAPON = 0x0202B72A   -- u8: icon index in the pause screen (0 = Z-Buster, 1 = Z-Saber)
local RANKS = { [0] = "F", "E", "D", "C", "B", "A", "S" }
local WEAPONS = { [0] = "Z-BUSTER", "Z-SABER" }

local function playTime(frames)
  local s = math.floor(frames / 60)
  return string.format("%d:%02d'%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
end

local function gameCode()
  return string.char(mem.u8(0x080000AC), mem.u8(0x080000AD), mem.u8(0x080000AE), mem.u8(0x080000AF))
end

-- The link check can fail for a tick or two (stage changes, cutscenes). Only a cold start shows the waiting
-- page; after that the last values stay up, marked OFFLINE, so the dashboard never flashes away mid-game.
local GRACE = 12                 -- ticks (4 per second) of failed checks before a stage counts as over
local missed = GRACE + 1
local seen = false               -- has a stage been linked since this script loaded?
local last = nil
local run = { ticks = 0, hits = 0, lowest = MAX_HP, lost = 0, prev = nil }

local function clock(ticks)
  local s = math.floor(ticks / 4)
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function linked()
  return gameCode() == "AZCE" and (function(v) return v >= VT_LO and v < VT_HI end)(mem.u32(ENTITY + 0x0C))
end

function update()
  if linked() then
    if missed > GRACE then run = { ticks = 0, hits = 0, lowest = MAX_HP, lost = 0, prev = nil } end
    missed = 0
    seen = true
    local hp = math.min(mem.u8(HP), MAX_HP)
    run.ticks = run.ticks + 1
    if run.prev and hp < run.prev then run.hits = run.hits + 1; run.lost = run.lost + (run.prev - hp) end
    run.prev = hp
    if hp < run.lowest then run.lowest = hp end

    local cells = {}
    for i = 1, MAX_HP do cells[i] = { full = i <= hp } end
    local low = hp <= 4
    local cellsV = {}
    for i = 1, MAX_HP do cellsV[i] = { full = (MAX_HP - i + 1) <= hp } end
    local wid = mem.u8(MAIN_WEAPON)
    last = {
      waiting = false, ready = true, link = "LIVE",
      hp = hp, hpNow = tostring(hp), hpMax = tostring(MAX_HP), hpPct = hp / MAX_HP,
      hpText = hp .. "/" .. MAX_HP, hpCells = cells, hpCellsV = cellsV, notBuster = wid ~= 0, notSaber = wid ~= 1, low = low,
      state = low and "DANGER" or (hp < MAX_HP and "HURT" or "FULL"),
      runTime = clock(run.ticks), hits = tostring(run.hits), lowest = run.lowest .. "/" .. MAX_HP, lost = tostring(run.lost),
      lives = tostring(math.min(mem.u8(LIVES), 99)), rank = RANKS[mem.u8(RANK)] or "-", rankName = RANKS[mem.u8(RANK)] or "-",
      crystals = tostring(mem.u16(CRYSTALS)), playTime = playTime(mem.u32(GAME_FRAMES)),
      mainWeapon = WEAPONS[mem.u8(MAIN_WEAPON)] or ("WEAPON " .. mem.u8(MAIN_WEAPON)),
      slot1 = "---", slot2 = "---", slot3 = "---", slot4 = "---",
      message = low and "Zero is in danger!" or "Your main weapon.",
      elf1 = "EMPTY", elf2 = "EMPTY", elf3 = "EMPTY", elf4 = "EMPTY", elf5 = "EMPTY", elf6 = "EMPTY", elf7 = "EMPTY",
      elfTitle = "--", elfHint = "Elf data not read yet.", elfDesc = "Cyber-elf data is not read yet.",
    }
    return last
  end

  missed = missed + 1
  if seen and last then
    last.link = "OFFLINE"
    last.message = "Waiting for the stage..."
    return last
  end
  return { waiting = true, ready = false }
end
