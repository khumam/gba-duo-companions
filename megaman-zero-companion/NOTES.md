# Mega Man Zero companion: build notes

v0.1.0 (2026-11-01), US build (AZCE) only. Live: Zero's life (EWRAM 0x0202B62C, full = 16). Everything else
shows a placeholder until its address is found (lives, rank, crystals, play time, weapons, elves).

## The look (0.4.0)

The game's pause windows redrawn crisply: `art/game_ui.py` (Pillow) paints the three page pictures at 248 x 216 art px
(brown grid, chamfered peach frames, metal name plates, black slots joined by connector lines, green MAIN tab, angled
L / R tabs); `art/layout.py` puts live text at art-pixel positions (writes layout.json + art/pos.src.css);
`art/css.py` expands `Nap` (1 ap = 2.168 dp) into style.css from `art/style.src.css`. Zero's portrait is the only Capcom
graphic (cut from `art/old/status.png`). The L / R tabs along the bottom are buttons (prev / next page).
THIS RUN (time, hits, lowest life) is computed in main.lua from the HP byte.

## Memory

`main.lua` checks the game code and that the entity at 0x0202B600 has vtable 0x085980E4 (a stage is running)
before showing anything. Found with the headless harness `art/mz-harness.c` (see memory notes); no
decompilation exists for Mega Man Zero and the online cheat codes are encrypted.

## To do

- Lives, rank letter, code name, crystals, play time, weapons (MAIN/SUB/EX slots), elves: find addresses
  (an in-game save makes `game.sav` match the RAM copy of the save data).
- Wide view (`game.lua`): needs the stage tilemap located in RAM.
- Re-check on device: the offline grace, and whether the vtable check drops at a boss/cutscene.
