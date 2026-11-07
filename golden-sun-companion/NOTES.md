# Golden Sun companion: build notes

## 0.4.0, margin markers (`game.lua`)

NPCs and other actors that straddle the frame's edge are drawn in the Wide view's margins.

- **Actors.** The game keeps them in EWRAM from `0x02030EBC`, `0x70` bytes each, slot 0 the party leader: handler pointer
  +0x00, x +0x08, height +0x0C, y +0x10 (16.16, world pixel in the high half, the same space as the BG scroll), sprite block
  pointer +0x50. The picture's y is `y - height`. Leader handler `0x080135C0`, followers `0x080135F0`; `0x08013240`,
  `0x0809FE10`, `0x0809FECC` are other actors (NPCs, but also objects and effects, which are not told apart yet).
- **Sprites only while on screen.** The sprite block (IWRAM, `0x118` bytes) holds the OAM attribute 2 (+8) of the actor's picture
  only while the game has it loaded, otherwise a placeholder (tile 260, flags `0x80002000`). The game reuses its OBJ tile
  slots (two actors shared tile 296), so a remembered tile later shows another actor's pixels, and the ROM art is compressed.
  So a real sprite is drawn only when the game's own OAM has an entry with that tile at the predicted spot (the picture's
  top-left is `(x - 16, y - height - 30)` on screen); it supplies size, palette and flip. Entirely off screen draws nothing (the diamond placeholders are gone).
  The game draws its actors in OAM rotation/scale mode (attribute 0 bit 8), so those entries must be accepted.
- **Checked** on the Thor and against save states: positions and OAM matches for the party and Vale NPCs. Not checked:
  interiors (no Wide view there), other language ROMs, which actors are NPCs versus objects. A test that went wrong: caching a
  picture and drawing it later produced garbled tiles.
- **To do.** Real sprites for actors that never touched the screen need the compressed sprite art decoded from the ROM.
