-- Psynergy id (the low 15 bits of a character's spell word) -> name and PP cost. Read off the game's
-- Psynergy menu on a Thor (2026-10-31) by writing ids into a character's spell list. That menu only
-- lists spells usable outside battle. 2026-11-07: the battle-only ones were read off the battle Psynergy menu of
-- Isaac, Garet, Ivan and Mia (each menu lists a character's spells in the order of their spell words), matched
-- to the ids in a late-game save. 192 and 194 are class Psynergy (word 0x80C0 / 0x80C2). Ids nobody in that party
-- knows are still unmapped and show as "Psynergy N".
return {
  [3] = { "Quake", 4 }, [4] = { "Earthquake", 7 }, [5] = { "Quake Sphere", 15 }, [6] = { "Spire", 5 },
  [7] = { "Clay Spire", 13 }, [9] = { "Gaia", 7 }, [10] = { "Mother Gaia", 17 }, [192] = { "Ragnarok", 7 },
  [24] = { "Frost", 5 }, [25] = { "Tundra", 8 }, [26] = { "Glacier", 15 }, [27] = { "Ice", 5 }, [28] = { "Ice Horn", 11 },
  [45] = { "Flare", 4 }, [46] = { "Flare Wall", 7 }, [47] = { "Flare Storm", 12 }, [48] = { "Fire", 6 },
  [49] = { "Fireball", 12 }, [51] = { "Volcano", 6 }, [52] = { "Eruption", 14 }, [194] = { "Heat Wave", 6 },
  [69] = { "Ray", 6 }, [70] = { "Storm Ray", 10 }, [72] = { "Plasma", 8 }, [73] = { "Shine Plasma", 18 },
  [79] = { "Tornado", 14 }, [120] = { "Sleep", 5 }, [121] = { "Bind", 4 },
  [100] = { "Restore", 3 }, [102] = { "Impact", 7 }, [103] = { "High Impact", 12 },
  [106] = { "Guard", 3 }, [107] = { "Protect", 5 }, [108] = { "Impair", 4 }, [109] = { "Debilitate", 6 },
  [110] = { "Ward", 3 }, [111] = { "Resist", 5 },
  [12] = { "Growth", 4 }, [24] = { "Frost", 5 }, [33] = { "Douse", 5 }, [78] = { "Whirlwind", 5 },
  [90] = { "Cure", 3 }, [91] = { "Cure Well", 7 }, [92] = { "Potent Cure", 10 }, [93] = { "Ply", 4 },
  [94] = { "Ply Well", 8 }, [95] = { "Pure Ply", 12 }, [96] = { "Wish", 9 }, [97] = { "Wish Well", 13 },
  [98] = { "Pure Wish", 20 }, [99] = { "Cure Poison", 2 }, [101] = { "Revive", 15 },
  [140] = { "Move", 2 }, [141] = { "Mind Read", 1 }, [142] = { "Force", 2 }, [143] = { "Lift", 2 },
  [144] = { "Reveal", 1 }, [145] = { "Halt", 2 }, [146] = { "Cloak", 1 }, [147] = { "Carry", 2 },
  [148] = { "Catch", 1 }, [149] = { "Retreat", 6 }, [150] = { "Avoid", 5 }, [185] = { "Gale", 3 },
}
