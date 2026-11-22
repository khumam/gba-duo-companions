# Pack tools: harness, memory search, build

Everything used to research and build the Castlevania, Zelda: A Link to the Past and later packs. Run from the
`gbaduo-companions` folder; Python scripts with `python3 -I`.

## 0. The toolkit at a glance

| Tool | Does |
|---|---|
| `harness/build.sh OUT` | Builds `gba-harness` (below) against the app repo's mGBA (`GBADUO_APP_DIR`, default `../gbaduo`) |
| `harness/play.py` | Plays the game headless from short steps (`st a w60 x5d hold:80:200 shot:pause dump:pause wr:0201327A=64:2 rd:... vram:items`), loading a `.sav` copy (the original is never written). Screenshots land as 3x PNGs |
| `harness/sheet.py` | Tiles many screenshots into one contact sheet (`--crop x,y,w,h` in GBA px) |
| `harness/ramdiff.py` | `diff` / `diff3` between dumps, `hex` around an address, `find` values (`u16:1484`, `bytes:cc053205`) |
| `harness/textfind.py` | Finds non-ASCII text: `pattern` search (repeated letters), 8- or 16-bit; `relative` for shifted tables |
| `harness/gfxfind.py` | Which ROM data the screen's tiles come from (raw or LZ77), draws VRAM banks, LZ77 blocks and 8bpp affine maps |
| `harness/lz77.py` | Strict GBA LZ77 decoder used by gfxfind (good for scanning a ROM) |
| `packkit/run.lua` | Runs a pack's `main.lua` offline over ROM + dump: print `update()`, write `preview-data.json` from a states list, call `actions` and list their writes (`--writes w.txt`, replay with `play.py ... @w.txt`) |
| `packkit/gfxmock.py ROM preview-data.json` | Draws the `gfx.decode` calls run.lua recorded into `assets/_preview/*.png` and points the preview data at them, so previews show the ROM's real portraits / icons (keep `assets/_preview` out of the zip) |
| `packkit/css.py PACK` | `art/style.src.css` (in `ap`) -> `style.css` |
| `packkit/overview.sh PACK pages` | Real-engine renders of the pages -> `overview/<pack-id>-overview.png` |

### A research session, step by step (what worked for every pack so far)

1. **Boot with the player's save.** `harness/build.sh /tmp/h/gba-harness`, then
   `play.py --harness ... --rom game.gba --save game.sav --out run w600 shot:t1 st w120 shot:t2 a w120 shot:t3`.
   Read the shots, add steps until the field shows, and keep that path in `base.steps` (`--base`).
   A save from another region usually loads; a save from a special mode (Maxim mode in HoD) may have no menus:
   start a new normal game in an empty slot and write the inventory in with `wr:` instead.
2. **Screenshot every menu screen** the companion will copy (each sub-menu, a few cursor positions, tabs, the map).
   Cursor positions carry over between sub-menus, and B twice may close the whole menu: one run per screen is safer.
   Copy the shots into the pack's `art/ref/`. These are the design reference: build the pack *like these screens*.
3. **Find the save block in RAM.** `ramdiff.py find run/pause.bin bytes:<16 bytes from the .sav>` (or values the
   menu shows: HP, gold, EXP). Most games keep the save block byte for byte in EWRAM; some keep two copies (Circle of
   the Moon plays on one and edits the other in its pause menu: write HP into each, pause, see which one shows).
4. **Map each value by changing it.** Equip / use / move in the menu, `dump:` before and after, `ramdiff.py diff`.
   Then prove it: `wr:` a new value and screenshot the game's own screen. For lists (items, cards, souls), fill a
   range with each byte's own offset+1 and read the counts off the menu: one run maps the whole array.
5. **Read names from the ROM.** ASCII: `grep`. Otherwise `textfind.py ROM "a long known name"` (pattern mode, try
   `--width 2`), decode around the hit, fill missing letters from words you can guess, find the u32 pointer table
   (pointers may aim a few bytes before the text: a header). Ship the decoding table, read the text at run time.
6. **Tables in the ROM** (stats, costs, EXP): search the ROM for a sequence of values you saw (stride search), or
   sample the value at several levels and fit a formula (Aria: 3L^3+20L^2+39L+22; HoD: 60L(L+1)). When a table
   can't be found, read every value off the game's screen and keep it in the pack (CotM's 100 DSS costs).
7. **Graphics.** `vram:` on the screen, `gfxfind.py ... find` and `banks`. Raw tiles: `gfx.sprite`/`gfx.decode`
   at run time. LZ77 without flips: `gfx.decode{lz77=true}`. LZ77 with flipped tiles (ALttP icons): cut 16x16 icons
   from screenshots and ship them (the user agreed to ship game icons for Zelda packs). Whole maps: an affine BG can
   be rendered flat from VRAM (`gfxfind.py affine`).
8. **Verify writes before the device.** `run.lua ... --act "equip(1, 25)"` lists the writes; replay them with
   `wr:` steps after `--base`, open the game's menus, screenshot. Only ship a write the game's own screen agrees with.
   16-bit writes to odd addresses land one byte early on the bus: write such words a byte at a time.

# Finding addresses: the memory tools (older notes)

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
