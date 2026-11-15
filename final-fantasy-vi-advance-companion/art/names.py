#!/usr/bin/env python3
"""Writes item_names.lua: item id -> name. The ROM keeps an 8-character short name per item
(9-byte entries at 0x79A00E, icon byte + 8 chars, id n at 0x79A00E + 9n; the game's letters are A-Z = 0x20, a-z = 0x3A).
Where the short name is cut off, the full name is filled in from the list below (matched by prefix).

    python3 art/names.py "<ROM path>"
"""
import os, re, sys

rom = open(sys.argv[1], "rb").read()
BASE, N = 0x79A00E, 271

def dec(b):
    o = ""
    for x in b:
        if 0x20 <= x <= 0x39: o += chr(65 + x - 0x20)
        elif 0x3A <= x <= 0x53: o += chr(97 + x - 0x3A)
        elif x == 0x60: o += "-"
        elif 0x54 <= x <= 0x5D: o += str(x - 0x54)
        elif x == 0xFF: o += " "
        else: o += " "
    return o.rstrip()

short = [dec(rom[BASE + 9 * i + 1:BASE + 9 * i + 9]) for i in range(N)]

FULL = """Dagger|Mythril Knife|Main Gauche|Air Knife|Thief's Knife|Assassin's Dagger|Man-Eater|Swordbreaker|Gladius|Valiant Knife
Mythril Sword|Great Sword|Rune Blade|Flametongue|Icebrand|Thunder Blade|Bastard Sword|Stoneblade|Blood Sword|Enhancer
Crystal Sword|Falchion|Soul Sabre|Organyx|Excalibur|Zantetsuken|Lightbringer|Ragnarok|Ultima Weapon|Mythril Spear
Trident|Heavy Lance|Partisan|Holy Lance|Golden Spear|Radiant Lance|Impartisan|Kunai|Kodachi|Sakura
Sasuke|Ichigeki|Kagenui|Ashura|Kotetsu|Kiku-ichimonji|Kazekiri|Murasame|Masamune|Murakumo
Mutsunokami|Healing Rod|Mythril Rod|Flame Rod|Ice Rod|Thunder Rod|Poison Rod|Holy Rod|Gravity Rod|Punisher
Magus Rod|Chocobo Brush|Da Vinci Brush|Magical Brush|Rainbow Brush|Shuriken|Fuma Shuriken|Pinwheel|Chain Flail|Moonring
Morning Star|Boomerang|Rising Sun|Hawkeye|Bone Club|Sniper|Wing Edge|Cards|Darts|Death Tarot
Viper Darts|Dice|Fixed Dice|Metal Knuckle|Mythril Claws|Kaiser Knuckle|Venom Claws|Burning Fist|Dragon Claws|Tigerfangs
Buckler|Heavy Shield|Mythril Shield|Golden Shield|Aegis Shield|Diamond Shield|Flame Shield|Ice Shield|Thunder Shield|Crystal Shield
Genji Shield|Tortoise Shield|Cursed Shield|Paladin Shield|Force Shield|Leather Hat|Hairband|Plumed Hat|Beret|Magus Hat
Bandana|Iron Helmet|Hypno Crown|Priest's Miter|Green Beret|Twist Headband|Mythril Helm|Tiara|Golden Helm|Tiger Mask
Red Cap|Mystery Veil|Circlet|Royal Crown|Diamond Helm|Black Cowl|Crystal Helm|Oath Veil|Cat-Ear Hood|Genji Helmet
Thornlet|Saucer|Leather Armor|Cotton Robe|Kenpo Gi|Iron Armor|Silk Robe|Mythril Vest|Ninja Gear|White Dress
Mythril Mail|Gaia Gear|Mirage Vest|Golden Armor|Power Sash|Luminous Robe|Diamond Vest|Red Jacket|Force Armor|Diamond Armor
Black Garb|Magus Robe|Crystal Mail|Regal Gown|Genji Armor|Reed Cloak|Minerva Bustier|Tabby Suit|Chocobo Suit|Moogle Suit
Nutkin Suit|Behemoth Suit|Snow Scarf|Noiseblaster|Bioblaster|Flash|Chainsaw|Debilitator|Drill|Air Anchor
Autocrossbow|Flame Scroll|Water Scroll|Lightning Scroll|Invisibility Scroll|Shadow Scroll""".replace("\n", "|").split("|")
EXTRA = ["Star Pendant", "Peace Ring", "Amulet", "White Cape", "Jeweled Ring", "Fairy Ring", "Barrier Ring", "Mythril Glove",
         "Protect Ring", "Hermes Sandals", "Reflect Ring", "Angel Wings", "Angel Ring", "Knight's Crest", "Dragoon Boots",
         "Zephyr Cape", "Princess Ring", "Cursed Ring", "Earring", "Gigas Glove", "Blizzard Orb", "Berserker Ring", "Thief Bracer",
         "Guard Bracelet", "Hero's Ring", "Ribbon", "Muscle Belt", "Crystal Orb", "Gold Hairpin", "Celestriad", "Brigand Glove",
         "Gauntlet", "Genji Glove", "Hyper Wrist", "Master's Scroll", "Prayer Beads", "Black Belt", "Fake Mustache",
         "Soul of Thamasa", "Dragon Horn", "Merit Award", "Memento Ring", "Safety Bit", "Lich Ring", "Molulu's Charm",
         "Ward Bangle", "Miracle Shoes", "Alarm Earring", "Gale Hairpin", "Sniper Eye", "Growth Egg", "Tintinabar", "Sprint Shoes",
         "Rename Card", "Potion", "Hi-Potion", "X-Potion", "Ether", "Hi-Ether", "X-Ether", "Elixir", "Megalixir", "Phoenix Down",
         "Holy Water", "Antidote", "Eye Drops", "Gold Needle", "Remedy", "Sleeping Bag", "Tent", "Green Cherry", "Magicite Shard",
         "Super Ball", "Echo Screen", "Smoke Bomb", "Teleport Stone", "Dried Meat", "Unarmed",
         "Apocalypse", "Zwill Crossbow", "Zanmato", "Oborozuki", "Longinus", "Godhand", "Save the Queen", "Stardust Rod",
         "Angel Brush", "Final Trump", "Gungnir", "Dueling Mask", "Scorpion Tail", "Bone Wrist", "Excalipoor",
         "Silver Spectacles", "Tintinnabulum"]   # the last two read off the game's Relics screen
norm = lambda s: re.sub(r"[^a-z0-9]", "", s.lower())
names = []
for i, s in enumerate(short):
    full = FULL[i] if i < len(FULL) and norm(FULL[i]).startswith(norm(s)[:6]) else None
    if not full:
        c = [e for e in EXTRA if norm(e).startswith(norm(s))]
        full = c[0] if len(c) >= 1 else s
    names.append(full)
here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(here, "..", "item_names.lua"), "w") as f:
    f.write("-- item id -> name (ids 0-255 are the inventory ids; 256-270 are the GBA-only gear)\nreturn {\n")
    for i, n in enumerate(names):
        f.write('  [%d] = "%s",\n' % (i, n.replace('"', '\\"')))
    f.write("}\n")
bad = [(i, short[i], names[i]) for i in range(N) if names[i] == short[i] and len(short[i]) >= 8]
print(len(names), "names;", len(bad), "left short:", bad[:40])
