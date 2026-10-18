-- Item ids, from the Item enum in zeldaret/tmc include/item.h; they match
-- samurai goroh's code guide (A/B button items 00-1F, bottle contents 20-31).

local M = {}

-- What the A and B buttons can hold.
M.equip = {
  [0x01] = "Smith's Sword", [0x02] = "White Sword", [0x03] = "White Sword +2",
  [0x04] = "White Sword +3", [0x05] = "Sword", [0x06] = "Four Sword",
  [0x07] = "Bombs", [0x08] = "Remote Bombs", [0x09] = "Bow", [0x0A] = "Light Arrows",
  [0x0B] = "Boomerang", [0x0C] = "Magic Boomerang", [0x0D] = "Small Shield",
  [0x0E] = "Mirror Shield", [0x0F] = "Flame Lantern", [0x10] = "Flame Lantern",
  [0x11] = "Gust Jar", [0x12] = "Cane of Pacci", [0x13] = "Mole Mitts",
  [0x14] = "Roc's Cape", [0x15] = "Pegasus Boots", [0x16] = "Fire Rod",
  [0x17] = "Ocarina of Wind", [0x1B] = "Grab",
  [0x1C] = "Bottle", [0x1D] = "Bottle", [0x1E] = "Bottle", [0x1F] = "Bottle",
}

-- What a bottle holds (and the charm/picolyte that is active).
M.bottle = {
  [0x20] = "Empty", [0x21] = "Butter", [0x22] = "Lon Lon Milk", [0x23] = "Lon Lon Milk (1/2)",
  [0x24] = "Red Potion", [0x25] = "Blue Potion", [0x26] = "Water",
  [0x27] = "Mineral Water", [0x28] = "Fairy",
  [0x29] = "Red Picolyte", [0x2A] = "Orange Picolyte", [0x2B] = "Yellow Picolyte",
  [0x2C] = "Green Picolyte", [0x2D] = "Blue Picolyte", [0x2E] = "White Picolyte",
  [0x2F] = "Nayru's Charm", [0x30] = "Farore's Charm", [0x31] = "Din's Charm",
}

-- Inventory items worth listing, in the order the pause menu shows them.
-- Each sword/shield/boomerang/lantern upgrade has its own bit; the gear list
-- only shows the best one of each group.
M.gear = {
  { "Sword", { 0x06, "Four Sword" }, { 0x04, "White Sword +3" }, { 0x03, "White Sword +2" },
    { 0x02, "White Sword" }, { 0x01, "Smith's Sword" } },
  { "Shield", { 0x0E, "Mirror Shield" }, { 0x0D, "Small Shield" } },
  { "Bombs", { 0x08, "Remote Bombs" }, { 0x07, "Bombs" } },
  { "Bow", { 0x0A, "Light Arrows" }, { 0x09, "Bow" } },
  { "Boomerang", { 0x0C, "Magic Boomerang" }, { 0x0B, "Boomerang" } },
  { "Lantern", { 0x0F, "Flame Lantern" }, { 0x10, "Flame Lantern" } },
  { "Gust Jar", { 0x11, "Gust Jar" } },
  { "Cane", { 0x12, "Cane of Pacci" } },
  { "Mitts", { 0x13, "Mole Mitts" } },
  { "Cape", { 0x14, "Roc's Cape" } },
  { "Boots", { 0x15, "Pegasus Boots" } },
  { "Ocarina", { 0x17, "Ocarina of Wind" } },
  { "Grip Ring", { 0x44, "Grip Ring" } },
  { "Bracelets", { 0x45, "Power Bracelets" } },
  { "Flippers", { 0x46, "Flippers" } },
  { "Map", { 0x47, "Hyrule Map" } },
}

M.bottles = { 0x1C, 0x1D, 0x1E, 0x1F }

M.elements = {
  { 0x40, "Earth" }, { 0x41, "Fire" }, { 0x42, "Water" }, { 0x43, "Wind" },
}

-- Tiger scrolls, in the order the brothers teach them.
M.skills = {
  { 0x48, "Spin Attack" }, { 0x49, "Roll Attack" }, { 0x4A, "Dash Attack" },
  { 0x4B, "Rock Breaker" }, { 0x4C, "Sword Beam" }, { 0x4D, "Great Spin" },
  { 0x4E, "Down Thrust" }, { 0x4F, "Peril Beam" }, { 0x73, "Fast Spin" },
  { 0x74, "Fast Split" }, { 0x75, "Long Spin" },
}

M.quest = {
  { 0x36, "Dog Food" }, { 0x37, "Lon Lon Ranch Key" }, { 0x38, "Wake-Up Mushroom" },
  { 0x39, "Library Book 1" }, { 0x3A, "Library Book 2" }, { 0x3B, "Library Book 3" },
  { 0x3C, "Graveyard Key" }, { 0x3D, "Tingle Trophy" }, { 0x3E, "Carlov Medal" },
  { 0x5B, "Jabber Nut" }, { 0x70, "Arrow Butterfly" }, { 0x71, "Digging Butterfly" },
  { 0x72, "Swim Butterfly" },
}

-- Kinstone pieces in the bag. The guide confirms 6A-6C as the golden Castor
-- Wilds statue pieces; the rest of the colour split is the usual one for this
-- game (9 gold, 3 red, 2 blue, 3 green) and still needs checking on a device.
function M.kinstone(id)
  if id >= 0x65 and id <= 0x69 then return "Gold", "Cloud Tops" end
  if id >= 0x6A and id <= 0x6C then return "Gold", "Castor Wilds" end
  if id == 0x6D then return "Gold", "Veil Falls" end
  if id >= 0x6E and id <= 0x70 then return "Red", nil end
  if id >= 0x71 and id <= 0x72 then return "Blue", nil end
  if id >= 0x73 and id <= 0x75 then return "Green", nil end
  return "?", nil
end

-- Icons in assets/icons, keyed by the names above. Sprites from the Zelda Dungeon
-- wiki (https://www.zeldadungeon.net/wiki/The_Minish_Cap_Items). Names with no
-- entry have no icon there (Fire Rod, Grab, Butter): M.icon gives nil
-- and the layout should fall back to the name.
local ICON_DIR = "asset:icons/"

M.icons = {
  -- A/B items
  ["Smith's Sword"] = "smiths-sword", ["White Sword"] = "white-sword",
  ["White Sword +2"] = "white-sword-2", ["White Sword +3"] = "white-sword-3",
  ["Sword"] = "picori-blade", -- id 0x05; assumed to be the Picori Blade, unchecked
  ["Four Sword"] = "four-sword",
  ["Bombs"] = "bombs", ["Remote Bombs"] = "remote-bombs", ["Bow"] = "bow",
  ["Light Arrows"] = "light-arrows", ["Boomerang"] = "boomerang",
  ["Magic Boomerang"] = "magic-boomerang", ["Small Shield"] = "small-shield",
  ["Mirror Shield"] = "mirror-shield", ["Flame Lantern"] = "flame-lantern",
  ["Gust Jar"] = "gust-jar", ["Cane of Pacci"] = "cane-of-pacci", ["Mole Mitts"] = "mole-mitts",
  ["Roc's Cape"] = "rocs-cape", ["Pegasus Boots"] = "pegasus-boots",
  ["Ocarina of Wind"] = "ocarina-of-wind", ["Bottle"] = "bottle",

  -- Bottle contents, charms and picolytes
  ["Empty"] = "bottle", ["Lon Lon Milk"] = "lon-lon-milk",
  ["Lon Lon Milk (1/2)"] = "lon-lon-milk", -- no half-full icon; same as full
  ["Red Potion"] = "red-potion", ["Blue Potion"] = "blue-potion", ["Water"] = "water",
  ["Mineral Water"] = "mineral-water", ["Fairy"] = "fairy",
  ["Red Picolyte"] = "red-picolyte", ["Orange Picolyte"] = "orange-picolyte",
  ["Yellow Picolyte"] = "yellow-picolyte", ["Green Picolyte"] = "green-picolyte",
  ["Blue Picolyte"] = "blue-picolyte", ["White Picolyte"] = "white-picolyte",
  ["Nayru's Charm"] = "nayrus-charm", ["Farore's Charm"] = "farores-charm", ["Din's Charm"] = "dins-charm",

  -- Gear
  ["Grip Ring"] = "grip-ring", ["Power Bracelets"] = "power-bracelets", ["Flippers"] = "flippers",
  ["Hyrule Map"] = "dungeon-map", -- no Hyrule Map icon on the wiki; the dungeon map's

  -- Tiger Scrolls: the wiki has one scroll icon for all eleven
  ["Spin Attack"] = "tiger-scroll", ["Roll Attack"] = "tiger-scroll", ["Dash Attack"] = "tiger-scroll",
  ["Rock Breaker"] = "tiger-scroll", ["Sword Beam"] = "tiger-scroll", ["Great Spin"] = "tiger-scroll",
  ["Down Thrust"] = "tiger-scroll", ["Peril Beam"] = "tiger-scroll", ["Fast Spin"] = "tiger-scroll",
  ["Fast Split"] = "tiger-scroll", ["Long Spin"] = "tiger-scroll",

  -- Quest items
  ["Dog Food"] = "dog-food", ["Lon Lon Ranch Key"] = "spare-key", ["Wake-Up Mushroom"] = "wake-up-mushroom",
  -- Which library book is 1, 2 and 3 is assumed, unchecked
  ["Library Book 1"] = "book-hyrulean-bestiary", ["Library Book 2"] = "book-legend-of-the-picori",
  ["Library Book 3"] = "book-history-of-masks",
  ["Graveyard Key"] = "graveyard-key", ["Tingle Trophy"] = "tingle-trophy",
  ["Carlov Medal"] = "carlov-medal", ["Jabber Nut"] = "jabber-nut",
  -- One butterfly icon on the wiki for all three
  ["Arrow Butterfly"] = "butterfly", ["Digging Butterfly"] = "butterfly", ["Swim Butterfly"] = "butterfly",
}

function M.icon(name)
  local file = name and M.icons[name]
  return file and (ICON_DIR .. file .. ".png") or nil
end

-- Elements by their name in M.elements ("Earth" -> earth-element.png). Kept apart
-- from M.icons because "Water" there is the bottle content.
function M.elementIcon(name)
  return ICON_DIR .. name:lower() .. "-element.png"
end

function M.kinstoneIcon(color)
  if color == "?" then color = "Gold" end
  return ICON_DIR .. "kinstone-" .. color:lower() .. ".png"
end

-- Other icons the layout can use directly (asset:icons/<name>.png): small-key,
-- big-key, compass, dungeon-map, rupee, shell, heart-piece, heart-container,
-- figurines, bomb-bag, quiver, wallet, kinstone-bag, arrow.

return M
