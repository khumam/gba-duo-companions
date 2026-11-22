-- The Legend of Zelda: A Link to the Past (GBA, USA AZLE) companion: the item screen, Link's status and the dungeons.
-- Reads the save block the GBA port keeps in EWRAM; addresses and how they were found are in NOTES.md.

local CODE = "AZLE"
local R = 0x02002320     -- save block: items in item-screen order, then the SNES layout from +0x20
local N = 0x40

-- the 24 item-screen cells, in grid order (row by row, 6 per row); { names by value, icon by value }
local function same(name, icon) return { names = { name }, icons = { icon }, any = true } end
local BOTTLE = {
  names = { "Mushroom", "Empty Bottle", "Red Potion", "Green Potion", "Blue Potion", "Fairy", "Bee", "Good Bee" },
  icons = { "bottle-1", "bottle-2", "bottle-3", "bottle-4", "bottle-5", "bottle-6", "bottle-7", "bottle-8" },
}
local GRID = {
  [0] = { names = { "Bow", "Bow & Arrows", "Silver Bow", "Bow & Silver Arrows" }, icons = { "bow-1", "bow-2", "bow-3", "bow-4" } },
  [1] = { names = { "Boomerang", "Magical Boomerang" }, icons = { "boomerang-1", "boomerang-2" } },
  [2] = same("Hookshot", "hookshot"),
  [3] = same("Bombs", "bombs"),
  [4] = { names = { "Mushroom", "Magic Powder" }, icons = { "mushroom", "powder" } },
  [5] = BOTTLE,
  [6] = same("Fire Rod", "fire-rod"), [7] = same("Ice Rod", "ice-rod"),
  [8] = same("Bombos Medallion", "bombos"), [9] = same("Ether Medallion", "ether"), [10] = same("Quake Medallion", "quake"),
  [11] = BOTTLE,
  [12] = same("Lamp", "lamp"), [13] = same("Magic Hammer", "hammer"),
  [14] = { names = { "Flute", "Flute", "Flute" }, icons = { "flute-2", "flute-2", "flute-3" } },
  [15] = same("Bug-Catching Net", "net"), [16] = same("Book of Mudora", "book"),
  [17] = BOTTLE,
  [18] = same("Shovel", "shovel"), [19] = same("Cane of Somaria", "somaria"), [20] = same("Cane of Byrna", "byrna"),
  [21] = same("Magic Cape", "cape"),
  [22] = { names = { "Magic Scroll", "Magic Mirror" }, icons = { "mirror-1", "mirror-2" } },
  [23] = BOTTLE,
}
-- one line on what each thing does (the pack's own words)
local WHAT = {
  ["Bow"] = "Fires arrows. Needs arrows to shoot.", ["Bow & Arrows"] = "Fires arrows at distant foes.",
  ["Silver Bow"] = "Fires silver arrows.", ["Bow & Silver Arrows"] = "Silver arrows: the bane of the King of Evil.",
  ["Boomerang"] = "Stuns enemies and fetches items.", ["Magical Boomerang"] = "Flies faster and farther.",
  ["Hookshot"] = "Pulls Link across gaps to what it grabs.", ["Bombs"] = "Blasts cracked walls and foes.",
  ["Mushroom"] = "A strange mushroom. Someone may want it.", ["Magic Powder"] = "Sprinkle it to change things.",
  ["Fire Rod"] = "Shoots fireballs and lights torches.", ["Ice Rod"] = "Freezes enemies solid.",
  ["Bombos Medallion"] = "Rains fire on every foe on screen.", ["Ether Medallion"] = "Freezes the whole screen.",
  ["Quake Medallion"] = "Shakes the ground and stuns foes.", ["Lamp"] = "Lights dark rooms and torches.",
  ["Magic Hammer"] = "Pounds pegs and heavy foes.", ["Flute"] = "Plays a tune. A bird may answer it.",
  ["Bug-Catching Net"] = "Catches bees and fairies.", ["Book of Mudora"] = "Reads the ancient Hylian texts.",
  ["Shovel"] = "Digs up buried things.", ["Cane of Somaria"] = "Makes a block appear.", ["Cane of Byrna"] = "Shields Link while it drains magic.",
  ["Magic Cape"] = "Makes Link invisible.", ["Magic Scroll"] = "Not usable yet.", ["Magic Mirror"] = "Warps back to the Light World.",
  ["Empty Bottle"] = "Holds potions, fairies or bees.", ["Red Potion"] = "Refills hearts.", ["Green Potion"] = "Refills magic.",
  ["Blue Potion"] = "Refills hearts and magic.", ["Fairy"] = "Revives Link when he falls.", ["Bee"] = "Lets loose a bee to fight.",
  ["Good Bee"] = "A golden bee that fights harder.",
  ["Pegasus Boots"] = "Dash with R. Breaks into things.", ["Power Glove"] = "Lifts light rocks.", ["Titan's Mitt"] = "Lifts heavy rocks.",
  ["Zora's Flippers"] = "Swim in deep water.", ["Moon Pearl"] = "Keeps Link's form in the Dark World.",
}
local SWORD = { "Fighter's Sword", "Master Sword", "Tempered Sword", "Golden Sword" }
local SHIELD = { "Fighter's Shield", "Fire Shield", "Mirror Shield" }
local MAIL = { [0] = "Green Clothes", "Blue Mail", "Red Mail" }

-- dungeons: { name, bit in the map / compass / big-key words, pendant or crystal (kind, bit), dark world }
local DUNGEONS = {
  { "Hyrule Castle", 14 }, { "Eastern Palace", 13, "pendant", 2 }, { "Desert Palace", 12, "pendant", 1 },
  { "Tower of Hera", 5, "pendant", 0 }, { "Castle Tower", 11 },
  { "Palace of Darkness", 9, "crystal", 1, true }, { "Swamp Palace", 10, "crystal", 4, true },
  { "Skull Woods", 7, "crystal", 6, true }, { "Thieves' Town", 4, "crystal", 5, true }, { "Ice Palace", 6, "crystal", 2, true },
  { "Misery Mire", 8, "crystal", 0, true }, { "Turtle Rock", 3, "crystal", 3, true }, { "Ganon's Tower", 2, nil, nil, true },
}
local HIDDEN = "?????????"
local PENDANT = { [0] = "red", [1] = "blue", [2] = "green" }

-- Link on the world map: overworld pixel coordinates (IWRAM), an indoors flag next to them; the map picture
-- (assets/map, the game's own map screen texture) is 352 px from texture (80, 96); world px / 12.8 + (97.6, 114.4)
-- lands on the texture (calibrated at the Sanctuary door, world 1880,1083)
local LINK_X, LINK_Y, INDOORS = 0x03003838, 0x0300383C, 0x0300389E
local MAP_AP = 0.5            -- art px per map px on the page
local AP = 2.168
local lastOut = nil

local romOk = false
function init() romOk = mem.read(0x080000AC, 4) == CODE end

local B = ""
local function b8(o) return B:byte(o + 1) or 0 end
local function b16(o) return b8(o) | (b8(o + 1) << 8) end
local function icon(n) return "asset:icons/" .. n .. ".png" end

local function itemCell(k)
  local v = b8(k)
  local g = GRID[k]
  if k == 3 then   -- bombs: the byte is the count
    if v == 0 then return { k = k, have = false, img = "", name = "" } end
    return { k = k, have = true, img = icon("bombs"), name = "Bombs", count = tostring(v) }
  end
  local idx = g.any and 1 or v
  if v == 0 or not g.names[idx] then return { k = k, have = false, img = "", name = "" } end
  return { k = k, have = true, img = icon(g.icons[idx]), name = g.names[idx] }
end

local function hearts(maxHp, hp)
  local out = {}
  local n = maxHp // 8
  for i = 1, n do
    local fill = hp - (i - 1) * 8
    out[i] = { img = fill >= 8 and "asset:ui/heart-full.png" or (fill >= 4 and "asset:ui/heart-half.png" or "asset:ui/heart-empty.png") }
  end
  return out
end

function update(ui)
  if not romOk then return { ready = false, waiting = true, wrongRom = mem.u32(0x08000000) ~= 0 } end
  B = mem.read(R, N)
  local maxHp, hp = b8(0x2C), b8(0x2D)
  if maxHp < 24 or maxHp > 160 or maxHp % 8 ~= 0 or hp > maxHp or b16(0x20) > 999 then
    return { ready = false, waiting = true, wrongRom = false }
  end
  local out = { ready = true, waiting = false }

  -- item grid
  local grid = {}
  for k = 0, 23 do grid[k + 1] = itemCell(k) end
  out.grid = grid
  -- the DO row
  local gl = b8(0x18)
  out.doRow = {
    { have = b8(0x19) > 0, img = icon("boots"), name = "Pegasus Boots" },
    { have = gl > 0, img = icon(gl >= 2 and "gloves-2" or "gloves-1"), name = gl >= 2 and "Titan's Mitt" or "Power Glove" },
    { have = b8(0x1A) > 0, img = icon("flippers"), name = "Zora's Flippers" },
    { have = b8(0x1B) > 0, img = icon("pearl"), name = "Moon Pearl" },
  }
  for i, d in ipairs(out.doRow) do d.i = i; d.cell = 99 + i; d.none = not d.have end
  out.lift = "LIFT." .. (gl + 1)
  -- equipment
  local sw, sh, ml = b8(0x1D), b8(0x1E), b8(0x1F)
  out.eq = {
    sword = sw >= 1 and sw <= 4 and icon("sword-" .. sw) or "", swordName = SWORD[sw] or "No sword", hasSword = sw >= 1 and sw <= 4,
    shield = sh >= 1 and sh <= 3 and icon("shield-" .. sh) or "", shieldName = SHIELD[sh] or "No shield", hasShield = sh >= 1 and sh <= 3,
    mail = icon("mail-" .. math.min(ml, 2)), mailName = MAIL[math.min(ml, 2)],
    pieces = b8(0x2B) % 4, pieceImg = "asset:ui/piece-" .. (b8(0x2B) % 4) .. ".png",
  }
  -- pendants / crystals
  local pend, cry = b8(0x34), b8(0x3A)
  out.pendants = {}
  for bit = 0, 2 do out.pendants[bit + 1] = { have = pend >> bit & 1 == 1, img = (pend >> bit & 1 == 1) and icon("pendant-" .. PENDANT[bit]) or icon("pendant-off") } end
  out.pend0, out.pend1, out.pend2 = out.pendants[1].img, out.pendants[2].img, out.pendants[3].img
  local nCry = 0
  for bit = 0, 6 do if cry >> bit & 1 == 1 then nCry = nCry + 1 end end
  out.crystalCount = nCry .. " / 7"
  out.anyCrystal = nCry > 0

  -- the picked cell
  local pick = tonumber(ui.cell) or -1
  local sel = { name = "", what = "Tap an item to read about it.", img = "", has = false }
  if pick >= 0 and pick <= 23 then
    local c = grid[pick + 1]
    if c.have then sel = { name = c.name, what = WHAT[c.name] or "", img = c.img, has = true } end
  elseif pick >= 100 and pick <= 103 then
    local d = out.doRow[pick - 99]
    if d.have then sel = { name = d.name, what = WHAT[d.name] or "", img = d.img, has = true } end
  end
  for i, c in ipairs(grid) do c.sel = (i - 1) == pick end
  out.sel = sel

  -- status
  local magicUse = b8(0x3B)
  local bombUp, arrowUp = b8(0x30), b8(0x31)
  out.st = {
    hearts = hearts(maxHp, hp), hp = hp / 8, maxHp = maxHp // 8,
    hpText = string.format("%g / %d", hp / 8, maxHp // 8),
    magic = b8(0x2E), magicMax = 128, magicText = math.floor(b8(0x2E) * 100 / 128) .. "%",
    magicUse = magicUse == 1 and "1/2 MAGIC" or (magicUse >= 2 and "1/4 MAGIC" or ""),
    rupees = string.format("%03d", b16(0x20)),
    bombs = string.format("%02d", b8(3)), bombsMax = tostring(10 + bombUp),
    arrows = string.format("%02d", b8(0x37)), arrowsMax = tostring(30 + arrowUp),
    pieces = (b8(0x2B) % 4) .. " / 4", containers = tostring(maxHp // 8),
    keys = b8(0x2F) == 0xFF and "--" or tostring(b8(0x2F)),
  }

  -- world map
  local indoors = mem.u8(INDOORS) ~= 0
  if not indoors then lastOut = { mem.u16(LINK_X), mem.u16(LINK_Y) } end
  local pos = lastOut
  out.map = { indoors = indoors, outdoors = not indoors, known = pos ~= nil,
              where = indoors and "Indoors: showing where Link went in." or "Overworld" }
  if pos then
    local mx = (pos[1] / 12.8 + 97.6 - 80) * MAP_AP - 3.5
    local my = (pos[2] / 12.8 + 114.4 - 96) * MAP_AP - 3.5
    out.map.x = string.format("%.2fpx", mx * AP)
    out.map.y = string.format("%.2fpx", my * AP)
  else
    out.map.x, out.map.y = "-100px", "-100px"
  end

  -- dungeons
  local mapW, compW, keyW = b16(0x28), b16(0x24), b16(0x26)
  local rows = {}
  for i, d in ipairs(DUNGEONS) do
    local bit = d[2]
    local hasMap, hasComp, hasKey = (mapW >> bit) & 1 == 1, (compW >> bit) & 1 == 1, (keyW >> bit) & 1 == 1
    local reward, rewardImg, done = nil, "", false
    if d[3] == "pendant" then
      done = (pend >> d[4]) & 1 == 1
      rewardImg = done and icon("pendant-" .. PENDANT[d[4]]) or icon("pendant-off")
    elseif d[3] == "crystal" then
      done = (cry >> d[4]) & 1 == 1
      rewardImg = done and "asset:ui/crystal.png" or "asset:ui/crystal-off.png"
    end
    local known = not d[5] or hasMap or hasComp or hasKey or done
    rows[i] = { name = known and d[1] or HIDDEN, dark = d[5] == true, map = hasMap, comp = hasComp, key = hasKey,
                noMap = not hasMap, noComp = not hasComp, noKey = not hasKey, reward = rewardImg, hasReward = rewardImg ~= "", done = done }
  end
  out.dungeons = rows
  out.dungeonTally = string.format("PENDANTS %d/3   CRYSTALS %d/7", (pend & 1) + (pend >> 1 & 1) + (pend >> 2 & 1), nCry)
  return out
end
