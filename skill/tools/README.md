# Finding addresses: the memory tools

Two ways to find where a game keeps a value (HP, rupees, a menu cursor, a map, a scroll register), like Cheat Engine.

## 1. Live, from the pack: `log()` in `game.lua` / `main.lua`

Runs on the device, no harness. Read any bus address (`mem.u8/u16/u32`, display registers at `0x04000000`,
palette `0x05000000`, VRAM `0x06000000`, OAM `0x07000000`) and print it; see it with
`adb logcat -s GBADuoPack`. Scripts load at game start, so push the pack and reopen the game.

```lua
local DEBUG = true            -- turn off before release
local ticks = 0
function frame(view)          -- game.lua: runs every frame
  ticks = ticks + 1
  if DEBUG and ticks % 60 == 0 then
    local function io(a) return mem.u16(0x04000000 + a) end
    log(string.format("disp=%04X bld=%04X bg3cnt=%04X bg3=%d,%d", io(0), io(0x50), io(0x0E), io(0x1C), io(0x1E)))
  end
end
```

Display registers say which background does what: `DISPCNT` (0) bits 8-11 backgrounds on; `BGxCNT` (0x08 + 2x) priority,
character base `(c >> 2) & 3` * 0x4000, screenblock `(c >> 8) & 31` * 0x800; `BGxHOFS/VOFS` (0x10 + 4x, +2) scroll;
`BLDCNT` (0x50) and `BLDALPHA` (0x52) for blends (this is how the Minish Cap clouds were found).

## 2. Cheat Engine-style search: `gba-harness` + `ramsearch.py`

For values with no obvious neighbours. The harness runs the game headless on a Mac, loading a save state from the device
(`.ss`, in `GBADuoSaves/<system>/<game>/states/`: pull a copy, never write the user's slots).

Build (once; needs mGBA built as `libmgba.a`, see the memory notes on the headless harness):
`clang -O1 -I engine/mgba/include tools/gba-harness.c libmgba.a -framework CoreFoundation -lz -lm -lpthread -o gba-harness`

Commands on stdin: `load FILE.ss`, `keys HEX N` (hold keys N frames: A=1 B=2 SEL=4 START=8 RIGHT=10 LEFT=20 UP=40
DOWN=80 R=100 L=200), `run N`, `dump FILE` (IWRAM + EWRAM), `rd ADDR LEN` (log lines share stdout: keep the long hex lines), `io` (the 0x400 register bytes as the
bus reads them: write-only ones such as `BGxHOFS` read 0), `ioraw ADDR LEN` (the real register contents, scroll included),
`ppm FILE` (screenshot), `wr ADDR VALUE WIDTH`, and the tracing commands below. A `game.sav` / `rom.sav` next to the ROM is the
save (loading a state overwrites it with the state's own save: copy yours back before the next run).

The search, with HP as an example:

```sh
printf 'load a.ss\nrun 2\ndump a.bin\n' | ./gba-harness game.gba >/dev/null 2>&1       # HP is 120
python3 -I tools/ramsearch.py new s.json a.bin --width 2 --value 120
printf 'load a.ss\nkeys 0 1\nrun 300\ndump b.bin\n' | ./gba-harness game.gba >/dev/null 2>&1  # took damage: 115
python3 -I tools/ramsearch.py next s.json b.bin --is delta --delta -5
python3 -I tools/ramsearch.py show s.json
python3 -I tools/ramsearch.py near b.bin 0x03001000 --count 16     # the struct around a hit
```

`--is` takes `changed`, `same`, `up`, `down`, `equal` (with `--value`) and `delta` (with `--delta`). Alternate
`changed` and `same` rounds when the value is unknown. Check a hit on the live game with `log()` before trusting it,
and compare against the decompilation or ROM map when there is one (values move between ROM regions and versions).

## 3. Who writes it, and where does it come from: tracing

- `watch LO HI` counts every CPU store into `LO..HI` by program counter (`wdump` prints `PC addr count`, `watch 0 0` stops). A
  PC in ROM is the routine to disassemble; a PC of a BIOS address means a BIOS copy.
- `swi 1` logs BIOS calls with r0-r2 and lr (`swi 0` stops): no `CpuSet` / LZ77 call while a map streams means the game uses its own
  routines (and DMAs, which show in the log as `GBA DMA: Starting DMA n src -> dst (control:count)`; sort and count them to see which
  buffers feed which VRAM rows).
- Code that was copied to IWRAM at boot (a DMA from ROM into `0x03000000`) is disassembled from the ROM source address.
  Disassemble with capstone (`pip install --target DIR capstone`, run Python with `-I` and `sys.path.insert`).
- Port a packer in Python first, check it bit for bit against data the game keeps in RAM, then decode everything the ROM holds
  before trusting it. `dragon-ball-z-legacy-of-goku-2-companion/NOTES.md` has a full worked case.
- To test a `game.lua` without the device, take a snapshot (`dump`, `io`, `rd` of palette / VRAM / OAM, `ppm`) and run the real
  `script.c` + `wide.c` over a fake bus that serves the snapshot and the ROM (see the app repo's `app/src/test/native`).

## Generators for finished packs

Run from the `gbaduo-companions` folder with `python3 -I skill/tools/<name>`; each says what it does in its docstring.

| Script | Does |
|---|---|
| `navkit.py` | Movable navigation (bottom / left / right / split) and an Options page, for packs with their own tab row (FFTA, Advance Wars) |
| `navkit_pokemon.py` | The same for the Pokémon packs' ring bar: side docks and a NAV row in the settings, styled from each pack's own bar |
| `pixel_theme.py` | Draws the pixel-art backgrounds (flames, leaves, rock, waves, gems) for the five Pokémon packs |
| `apply_pixel_css.py PACK` | Squares the corners, flattens gradients and applies the pixel background to a Pokémon pack's `style.css` (run once; git has the original) |
