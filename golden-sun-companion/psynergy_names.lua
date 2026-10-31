-- Psynergy id (the low 15 bits of a character's spell word) -> name and PP cost. Read off the game's
-- Psynergy menu on a Thor (2026-10-31) by writing ids into a character's spell list. That menu only
-- lists spells usable outside battle, so battle-only spells are not mapped and show as "Psynergy N".
return {
  [12] = { "Growth", 4 }, [24] = { "Frost", 5 }, [33] = { "Douse", 5 }, [78] = { "Whirlwind", 5 },
  [90] = { "Cure", 3 }, [91] = { "Cure Well", 7 }, [92] = { "Potent Cure", 10 }, [93] = { "Ply", 4 },
  [94] = { "Ply Well", 8 }, [95] = { "Pure Ply", 12 }, [96] = { "Wish", 9 }, [97] = { "Wish Well", 13 },
  [98] = { "Pure Wish", 20 }, [99] = { "Cure Poison", 2 }, [101] = { "Revive", 15 },
  [140] = { "Move", 2 }, [141] = { "Mind Read", 1 }, [142] = { "Force", 2 }, [143] = { "Lift", 2 },
  [144] = { "Reveal", 1 }, [145] = { "Halt", 2 }, [146] = { "Cloak", 1 }, [147] = { "Carry", 2 },
  [148] = { "Catch", 1 }, [149] = { "Retreat", 6 }, [150] = { "Avoid", 5 }, [185] = { "Gale", 3 },
}
