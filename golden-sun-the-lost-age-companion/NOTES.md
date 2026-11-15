# Golden Sun: The Lost Age companion: build notes

Cloned from `golden-sun-companion` 0.4.0 (2026-11-08). Game code `AGFE` (US/Europe).

## Checked (against a Lost Age save from the Thor, `GOLDEN_SUN_B [AGFE-726BB764]`)

- Save/EWRAM header is 0x10 bytes; the party order list (0x0200001C), coins (0x02000014) are where Golden Sun has them.
- Character blocks start at **0x02000520** (Isaac), 0x14C apart, 8 slots: Isaac, Garet, Ivan, Mia, Felix, Jenna, Sheba, Piers.
  Every field offset inside a block (level, HP/PP, stats, elements, items, spells, djinn, EXP) decodes sanely.
- Djinn bit order per element keeps Golden Sun's first seven (Isaac held Flint/Granite/Quartz, Gust/Kite).

## Not checked yet

- Name tables (`item_names`, `psynergy_names`, `djinn_names`) are still Golden Sun's; Lost Age has 18 Djinn per element,
  more items and more Psynergy. Unknown ids show "Item XX" / "Psynergy N".
- `game.lua` addresses (map grid, BG scroll shadow, actors, leader handler) are Golden Sun's; the app hides the margins
  when they don't match the game's picture. The Maps page reads `LEADER` (0x02030EC4) in `main.lua`.
- Portraits exist for Isaac, Garet, Ivan, Mia, Jenna only.
