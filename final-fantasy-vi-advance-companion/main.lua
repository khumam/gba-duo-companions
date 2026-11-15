-- Final Fantasy VI Advance (USA, BZ6E) companion.
-- The game keeps the SNES layout in EWRAM (0x02000000 + the SNES WRAM offset): character structs at +0x1600,
-- party bytes at +0x1850, gil/time/steps at +0x1860. The sorted inventory is at 0x02039010 (ids) / 0x02039130 (quantities).
-- Found with a headless mGBA run on the real ROM; see NOTES.md.

local GAME   = "BZ6E"
local CHAR   = 0x02001600   -- 37 bytes per character, indexed by actor id
local PARTY  = 0x02001850   -- one byte per actor: bits 0-2 party number, bits 3-4 position in the party
local GIL    = 0x02001860
local INV_ID = 0x02039010
local INV_QT = 0x02039130
local CONFIG = 0x020202EC   -- the live Config settings: mode, speed, messages, command, ATB, reequip, cursor, dash
local ESPERS = 0x02001A69   -- owned Espers, one bit each (id order)
local SPELLS = 0x02001A6E   -- 54 bytes per actor: 0xFF = learned, otherwise the percentage learned
local NAMES  = pack.require("item_names")
-- the techniques: learned flags in the SNES layout (one bit each), and the names the game shows
local BUSHIDO, BLITZ, LORE, RAGE, DANCE = 0x02001CF7, 0x02001D28, 0x02001D29, 0x02001D2C, 0x02001D4C
local RAGE_NAMES = 0x08722C94   -- ROM: enemy names, 8 characters each in enemy-id order (the game shows longer names than these); Gau's rages are enemy ids
local TECH = {
  { name = "Bushido", cmd = 7, addr = BUSHIDO, n = 8, names = { "Fang", "Sky", "Tiger", "Flurry", "Dragon", "Eclipse", "Tempest", "Oblivion" } },
  { name = "Blitz", cmd = 10, addr = BLITZ, n = 8, names = { "Raging Fist", "Aura Cannon", "Meteor Strike", "Rising Phoenix", "Chakra", "Razor Gale", "Soul Spiral", "Phantom Rush" } },
  { name = "Lore", cmd = 12, addr = LORE, n = 24, names = { "Doom", "Roulette", "Tsunami", "Aqua Breath", "Aero", "1000 Needles", "Mighty Guard", "Revenge Blast", "White Wind",
      "Lv. 5 Death", "Lv. 4 Flare", "Lv. 3 Confuse", "Reflect ???", "Lv. ? Holy", "Traveler", "Force Field", "Dischord", "Bad Breath", "Transfusion", "Rippler",
      "Stone", "Quasar", "Grand Delta", "Self-Destruct" } },
  { name = "Rage", cmd = 16, addr = RAGE, n = 255 },
  { name = "Dance", cmd = 19, addr = DANCE, n = 8, names = { "Wind Rhapsody", "Forest Nocturne", "Desert Lullaby", "Love Serenade", "Earth Blues", "Water Harmony", "Twilight Requiem", "Snowman Rondo" } },
}
-- ROM tables (US build): item properties, the characters' own Defense / Evasion, and the EXP curve
local ITEMS      = 0x0862CC64   -- 30 bytes per item: +0 class (low nibble: 1 weapon), +9 HP / MP bonus flags, +16 / +17 stat bonuses (signed nibbles), +20 Defense (weapon: power), +21 Magic Defense, +26 Evasion / Magic Evasion in tens
local ACTOR_BASE = 0x0862ACB7   -- 22 bytes per actor: Defense, Magic Defense, Evasion, Magic Evasion before gear
local EXP_TABLE  = 0x0862ABC8   -- u16 per level: the EXP needed for the next level, divided by 8; the totals add up

local CLASS = { [0] = "Magitek Elite", "Adventurer", "Samurai", "Assassin", "Machinist", "Monk", "Rune Knight", "Blue Mage",
  "Pictomancer", "Gambler", "Moogle", "Feral Youth", "Mime", "Yeti", "General", "Ghost" }
local FALLBACK = { [0] = "Terra", "Locke", "Cyan", "Shadow", "Edgar", "Sabin", "Celes", "Strago", "Relm", "Setzer", "Mog", "Gau",
  "Gogo", "Umaro", "Leo", "Kefka" }
local COMMAND = { [0] = "Attack", "Items", "Magic", "Morph", "Revert", "Steal", "Mug", "Bushido", "Throw", "Tools", "Blitz", "Runic",
  "Lore", "Sketch", "Control", "Slot", "Rage", "Leap", "Mimic", "Dance", "Row", "Defend", "Jump", "Dualcast", "Gil Toss",
  "Summon", "Pray" }
local EXT = { "Apocalypse", "Zwill Crossbow", "Zanmato", "Oborozuki", "Longinus", "Godhand", "Save the Queen", "Stardust Rod",
  "Angel Brush", "Final Trump", "Gungnir", "Dueling Mask", "Scorpion Tail", "Bone Wrist", "Excalipoor" }

-- HP and MP sit at odd addresses; mem.u16 reads the aligned halfword there, so read two bytes
local function u16(a) return mem.u8(a) | (mem.u8(a + 1) << 8) end
local function u24(a) return mem.u8(a) | (mem.u8(a + 1) << 8) | (mem.u8(a + 2) << 16) end

-- the game's letters: A-Z = 0x20.., a-z = 0x3A.., digits 0x54..
local function text(a, n)
  local t = {}
  for i = 0, n - 1 do
    local b = mem.u8(a + i)
    if b == 0 or b == 0xFF then break end
    if b >= 0x20 and b <= 0x39 then t[#t + 1] = string.char(65 + b - 0x20)
    elseif b >= 0x3A and b <= 0x53 then t[#t + 1] = string.char(97 + b - 0x3A)
    elseif b >= 0x54 and b <= 0x5D then t[#t + 1] = string.char(48 + b - 0x54)
    else return nil end
  end
  return table.concat(t)
end

local function itemName(id, gear)
  if id == 0xFF then return "" end
  if gear and id >= 0xE7 then return EXT[id - 0xE6] or "" end   -- GBA-only gear takes the ids from 0xE7 in the gear slots
  return NAMES[id] or ""
end

local SLOTS = { "Right Hand", "Left Hand", "Head", "Body", "Relic", "Relic" }
local ESPER = { [0] = "Ramuh", "Ifrit", "Shiva", "Siren", "Midgardsormr", "Catoblepas", "Maduin", "Bismarck", "Cait Sith", "Quetzalli",
  "Valigarmanda", "Odin", "Raiden", "Bahamut", "Alexander", "Crusader", "Ragnarok", "Kirin", "Zona Seeker", "Carbuncle", "Phantom",
  "Seraph", "Golem", "Unicorn", "Fenrir", "Lakshmi", "Phoenix", "Leviathan", "Cactuar", "Diabolos", "Gilgamesh" }
local SPELL = { [0] = "Fire", "Blizzard", "Thunder", "Poison", "Drain", "Fira", "Blizzara", "Thundara", "Bio", "Firaga", "Blizzaga",
  "Thundaga", "Break", "Death", "Holy", "Flare", "Gravity", "Graviga", "Banish", "Meteor", "Ultima", "Quake", "Tornado", "Meltdown",
  "Libra", "Slow", "Rasp", "Silence", "Protect", "Sleep", "Confuse", "Haste", "Stop", "Berserk", "Float", "Imp", "Reflect", "Shell",
  "Vanish", "Hastega", "Slowga", "Osmose", "Teleport", "Quick", "Dispel", "Cure", "Cura", "Curaga", "Raise", "Arise", "Poisona",
  "Esuna", "Regen", "Rerise" }
-- Config rows: label, option texts (the byte is the option's index)
local CONF = {
  { "Battle Mode", { "Active", "Wait" } }, { "Battle Speed", { "1", "2", "3", "4", "5", "6" } },
  { "Battle Messages", { "1", "2", "3", "4", "5", "6" } }, { "Command Settings", { "Standard", "Shortcut" } },
  { "ATB Gauge", { "On", "Off" } }, { "Reequip", { "Optimize", "Remove All" } },
  { "Cursor Position", { "Reset", "Remember" } }, { "Auto-Dash", { "On", "Off" } } }

-- Items that can be used from the menu, with the effects the game gives them (measured on the game's own Use menu)
local USE = {
  [232] = { hp = 50 }, [233] = { hp = 250 }, [234] = { hp = 9999 },
  [235] = { mp = 50 }, [236] = { mp = 150 }, [237] = { mp = 9999 },
  [238] = { hp = 9999, mp = 9999 }, [246] = { hp = 9999, mp = 9999 },
  [247] = { hp = 9999, mp = 9999, party = true },     -- Tent: the whole party
}

-- a signed nibble: bit 3 is the sign, bits 0-2 the size
local function nib(n) if n & 8 ~= 0 then return -(n & 7) end return n & 7 end
local HP_FLAG = { { 0x08, 50 }, { 0x04, 25 }, { 0x10, 12.5 } }   -- bonus flags in item byte +9, biggest first; only the biggest applies
local MP_FLAG = { { 0x40, 50 }, { 0x20, 25 }, { 0x80, 12.5 } }

-- what a character's gear adds (the game's menu calculates this; it isn't stored)
local function gearOf(a)
  local g = { str = 0, spd = 0, sta = 0, mag = 0, eva = 0, mev = 0, def = 0, mdef = 0, atk = 26, hp = 0, mp = 0 }
  for slot = 0, 5 do
    local id = mem.u8(a + 31 + slot)
    if id ~= 0xFF then
      local rec = ITEMS + 30 * ((id >= 0xE7) and (id + 25) or id)   -- the GBA-only gear takes the ids from 0xE7 up
      local weapon = (mem.u8(rec) & 15) == 1
      local b16, b17, b26, flags = mem.u8(rec + 16), mem.u8(rec + 17), mem.u8(rec + 26), mem.u8(rec + 9)
      g.spd, g.str = g.spd + nib(b16 >> 4), g.str + nib(b16 & 15)
      g.mag, g.sta = g.mag + nib(b17 >> 4), g.sta + nib(b17 & 15)
      g.eva, g.mev = g.eva + (b26 & 15) * 10, g.mev + (b26 >> 4) * 10
      if weapon then
        if slot == 0 then
          if id == 36 then g.atkOdd = true            -- Impartis: the game shows a small, character-dependent number that isn't in the item table
          else g.atk = mem.u8(rec + 20) + 16 end   -- weapon power + 16, capped at 255
        end
      else
        g.def, g.mdef = g.def + mem.u8(rec + 20), g.mdef + mem.u8(rec + 21)
      end
      for _, f in ipairs(HP_FLAG) do if flags & f[1] ~= 0 then g.hp = math.max(g.hp, f[2]); break end end
      for _, f in ipairs(MP_FLAG) do if flags & f[1] ~= 0 then g.mp = math.max(g.mp, f[2]); break end end
    end
  end
  return g
end

-- the maximum HP and MP: the struct holds the base; gear adds the biggest percentage (the game caps them at 9999 and 999)
local function maxes(a, g)
  g = g or gearOf(a)
  return math.min(9999, math.floor((u16(a + 11) & 0x3FFF) * (1 + g.hp / 100))), math.min(999, math.floor((u16(a + 15) & 0x3FFF) * (1 + g.mp / 100)))
end

-- the EXP still needed for the next level
local function expToNext(level, exp)
  if level >= 99 then return 0 end
  local sum = 0
  for j = 0, level - 1 do sum = sum + mem.u8(EXP_TABLE + 2 * j) + (mem.u8(EXP_TABLE + 2 * j + 1) << 8) end
  return math.max(0, sum * 8 - exp)
end

-- an enemy's short name from the ROM table (the game's letters, 0xFF is a space)
local function enemyName(id)
  local t = {}
  for i = 0, 7 do
    local b = mem.u8(RAGE_NAMES + 8 * id + i)
    if b >= 0x20 and b <= 0x39 then t[#t + 1] = string.char(65 + b - 0x20)
    elseif b >= 0x3A and b <= 0x53 then t[#t + 1] = string.char(97 + b - 0x3A)
    elseif b >= 0x54 and b <= 0x5D then t[#t + 1] = string.char(48 + b - 0x54)
    elseif b == 0xFF then t[#t + 1] = " "
    elseif b == 0x63 or b == 0xF4 then t[#t + 1] = "'"
    elseif b == 0x62 then t[#t + 1] = "-"
    else t[#t + 1] = "" end
  end
  return (table.concat(t):gsub("%s+$", ""))
end

local function learned(k, i) return (mem.u8(TECH[k].addr + (i >> 3)) >> (i & 7)) & 1 == 1 end
local techCache = {}
local function techName(k, i)
  local t = TECH[k]
  if t.names then return t.names[i + 1] end
  local c = techCache[i]
  if not c then c = enemyName(i); techCache[i] = c end
  return c
end

local function member(actor)
  local a = CHAR + 37 * actor
  if mem.u8(a) ~= actor then return nil end
  local level = mem.u8(a + 8)
  if level < 1 or level > 99 then return nil end
  local g = gearOf(a)
  local maxHp, maxMp = maxes(a, g)
  local hp, mp = u16(a + 9), u16(a + 13)
  local base = ACTOR_BASE + 22 * actor
  local function cap(v) return math.max(0, math.min(255, v)) end
  local cmds, cmdIds = {}, {}
  for i = 0, 3 do
    local c = mem.u8(a + 22 + i)
    if c ~= 0xFF then cmds[#cmds + 1] = COMMAND[c] or "?"; cmdIds[c] = true end
  end
  local equip, relics = {}, {}
  for i = 0, 3 do equip[#equip + 1] = { label = SLOTS[i + 1], item = itemName(mem.u8(a + 31 + i), true) } end
  local esperId = mem.u8(a + 30)
  local esperName = ESPER[esperId] or "None"
  relics[1] = { label = "Relic", item = itemName(mem.u8(a + 35), true) }
  relics[2] = { label = "Relic", item = itemName(mem.u8(a + 36), true) }
  relics[3] = { label = "Esper", item = esperName }
  local spells = {}
  for i = 0, 53 do if actor < 12 and mem.u8(SPELLS + 54 * actor + i) == 0xFF then spells[#spells + 1] = { name = SPELL[i] } end end
  return {
    actor = actor, name = text(a + 2, 6) or FALLBACK[actor], class = CLASS[actor] or "",
    level = level, hp = hp, maxHp = maxHp, mp = mp, maxMp = maxMp, exp = u24(a + 17),
    vigor = cap(mem.u8(a + 26) + g.str), speed = cap(mem.u8(a + 27) + g.spd), stamina = cap(mem.u8(a + 28) + g.sta), magic = cap(mem.u8(a + 29) + g.mag),
    attack = math.min(255, g.atk), attackText = g.atkOdd and "?" or tostring(math.min(255, g.atk)), defense = cap(mem.u8(base) + g.def), mdefense = cap(mem.u8(base + 1) + g.mdef),
    evasion = cap(mem.u8(base + 2) + g.eva), mevasion = cap(mem.u8(base + 3) + g.mev), expNext = expToNext(level, u24(a + 17)),
    cmdIds = cmdIds, commands = table.concat(cmds, ", "), equip = equip, relics = relics, esper = esperName, esperId = esperId, spells = spells, spellCount = #spells, face = "asset:gfx/p" .. actor .. ".png",
  }
end

function update(ui)
  if mem.read(0x080000AC, 4) ~= GAME then return { ready = false, waiting = true } end
  -- the party: actors flagged for party 1, in their party order
  local order = {}
  for actor = 0, 15 do
    local b = mem.u8(PARTY + actor)
    if b ~= 0 and b ~= 0xFF and (b & 7) == 1 then order[#order + 1] = { actor = actor, pos = (b >> 3) & 3 } end
  end
  table.sort(order, function(x, y) return x.pos < y.pos end)
  local party = {}
  for _, o in ipairs(order) do
    local m = member(o.actor)
    if m then party[#party + 1] = m end
  end
  if #party == 0 then return { ready = false, waiting = true } end

  local who = tonumber(ui.who) or party[1].actor
  local sel = party[1]
  for _, m in ipairs(party) do if m.actor == who then sel = m end end
  local roster = {}
  for i, m in ipairs(party) do roster[i] = { actor = m.actor, name = m.name, sel = (m.actor == sel.actor) } end

  local items, chosen = {}, tonumber(ui.item)
  for slot = 0, 239 do
    local id = mem.u8(INV_ID + slot)
    if id == 0xFF then break end
    local q = mem.u8(INV_QT + slot)
    if q > 0 then items[#items + 1] = { slot = slot, id = id, name = NAMES[id] or "?", qty = q, sel = (slot == chosen) } end
  end
  local selItem = { name = "", qty = 0 }
  for _, it in ipairs(items) do if it.slot == chosen then selItem = it end end
  if selItem.name == "" and #items > 0 then selItem = items[1]; items[1].sel = true end

  -- espers: owned ones, mine = the selected character wears it, taken = someone else does
  local worn = {}
  for _, m in ipairs(party) do worn[m.esperId] = m.actor end
  for actor = 0, 15 do
    local b = mem.u8(CHAR + 37 * actor + 30)
    if worn[b] == nil and mem.u8(CHAR + 37 * actor) == actor and (mem.u8(PARTY + actor) & 7) == 0 and b < 31 then worn[b] = actor end
  end
  local espers, bits = {}, mem.u8(ESPERS) | (mem.u8(ESPERS + 1) << 8) | (mem.u8(ESPERS + 2) << 16) | (mem.u8(ESPERS + 3) << 24)
  for id = 0, 30 do
    if (bits >> id) & 1 == 1 then
      espers[#espers + 1] = { name = ESPER[id], mine = (id == sel.esperId), taken = (worn[id] ~= nil and worn[id] ~= sel.actor) }
    end
  end

  -- techniques: the lists are shared by everyone; a kind is dimmed when the selected character has no such command
  local kinds, techs = {}, {}
  local pickKind = tonumber(ui.sk)
  if not pickKind then
    pickKind = 1
    for k, t in ipairs(TECH) do if sel.cmdIds[t.cmd] then pickKind = k; break end end
  end
  for k, t in ipairs(TECH) do
    local count = 0
    for i = 0, t.n - 1 do if learned(k, i) then count = count + 1 end end
    kinds[k] = { k = k, name = t.name .. " " .. count, on = (k == pickKind), off = not sel.cmdIds[t.cmd] }
    if k == pickKind then
      for i = 0, t.n - 1 do
        if learned(k, i) then
          local nm = techName(k, i)
          if nm and nm ~= "" then techs[#techs + 1] = { name = nm } end
        end
      end
    end
  end

  local conf = {}
  for r, row in ipairs(CONF) do
    local cur, opts = mem.u8(CONFIG + r - 1), {}
    for k, txt in ipairs(row[2]) do opts[k] = { row = r - 1, val = k - 1, text = txt, sel = (cur == k - 1) } end
    conf[r] = { label = row[1], six = #row[2] == 6, opts = opts }
  end

  local marked = tonumber(ui.swap) or -1
  for _, m in ipairs(party) do m.marked = (m.actor == marked) end

  local detail = { slot = selItem.slot or -1, name = selItem.name, prompt = selItem.name, sub = "", single = false, party = false, none = true }
  local eff = selItem.id and USE[selItem.id]
  if eff then
    detail.none = false
    if eff.party then detail.party, detail.prompt, detail.sub = true, "Use " .. selItem.name .. "?", "Restores the whole party."
    else detail.single, detail.prompt, detail.sub = true, "Use " .. selItem.name, "Who should use it?" end
  else detail.sub = "It can't be used here." end

  return {
    combat = (tonumber(ui.sp) == 1), notCombat = (tonumber(ui.sp) ~= 1),
    ready = true, waiting = false, party = party, tabs = roster, detail = detail, sel = sel, equip = sel.equip, relics = sel.relics,
    kinds = kinds, techs = techs, noTechs = #techs == 0, techKind = TECH[pickKind].name,
    face = sel.face, espers = espers, spells = sel.spells, config = conf,
    formationHint = marked >= 0 and "Tap another member to swap" or "Tap two members to swap their places",
    items = items, noItems = #items == 0, selItem = selItem,
    time = string.format("%d:%02d", mem.u8(GIL + 3), mem.u8(GIL + 4)),
    steps = u24(GIL + 6), gil = u24(GIL),
  }
end

actions = {}

-- Config: tap an option to set it
function actions.setConfig(row, val)
  row, val = tonumber(row), tonumber(val)
  if not row or not val or row < 0 or row > 7 or not CONF[row + 1] or val < 0 or val >= #CONF[row + 1][2] then return end
  mem.write8(CONFIG + row, val)
end

-- Formation: tap one member, then another, to swap their places in the party
function actions.pick(actor)
  actor = tonumber(actor)
  if not actor then return end
  local first = tonumber(ui.swap)
  if not first or first < 0 then return { set = { swap = actor } } end
  if first ~= actor then
    local pa, pb = mem.u8(PARTY + first), mem.u8(PARTY + actor)
    if pa ~= 0 and pb ~= 0 and (pa & 7) == (pb & 7) then
      mem.write8(PARTY + first, (pa & ~0x18) | (pb & 0x18))
      mem.write8(PARTY + actor, (pb & ~0x18) | (pa & 0x18))
    end
  end
  return { set = { swap = -1 } }
end

-- Items: restore HP / MP like the game's own Use menu, then take one item (and close the gap when the last is used)
local function heal(actor, e)
  local a = CHAR + 37 * actor
  local maxHp, maxMp = maxes(a)
  local hp = u16(a + 9)
  if hp == 0 then return false end                      -- the fallen need a Phoenix Down
  local mp = u16(a + 13)
  if e.hp then hp = math.min(maxHp, hp + e.hp) end
  if e.mp then mp = math.min(maxMp, mp + e.mp) end
  mem.write8(a + 9, hp & 255); mem.write8(a + 10, hp >> 8)
  mem.write8(a + 13, mp & 255); mem.write8(a + 14, mp >> 8)
  return true
end

function actions.useItem(slot, actor)
  slot, actor = tonumber(slot), tonumber(actor)
  if not slot or slot < 0 or slot > 239 then return end
  local e = USE[mem.u8(INV_ID + slot)]
  local qty = mem.u8(INV_QT + slot)
  if not e or qty == 0 then return end
  local used = false
  if e.party then
    for a = 0, 15 do
      local b = mem.u8(PARTY + a)
      if b ~= 0 and b ~= 0xFF and (b & 7) == 1 and heal(a, e) then used = true end
    end
  else
    if not actor or actor < 0 or actor > 15 then return end
    local b = mem.u8(PARTY + actor)
    if b == 0 or b == 0xFF then return end
    used = heal(actor, e)
  end
  if not used then return end
  if qty > 1 then mem.write8(INV_QT + slot, qty - 1); return end
  for i = slot, 238 do                                   -- the last one: shift the list up
    mem.write8(INV_ID + i, mem.u8(INV_ID + i + 1))
    mem.write8(INV_QT + i, mem.u8(INV_QT + i + 1))
  end
  mem.write8(INV_ID + 239, 0xFF); mem.write8(INV_QT + 239, 0)
end
