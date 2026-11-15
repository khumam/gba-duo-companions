# Dragon Ball Z: The Legacy of Goku II companion: build notes

v0.1.0 (2026-11-13), US build (`ALFE`, CRC32 204142E1) only. Pages cycle like the game's L / R: JOURNAL <-> STATUS <-> ITEMS.
Not device-tested yet (previewed with the app's engine, and `main.lua` run against the real ROM + a RAM dump).

## The look

The game's own pause menu (reference frames in `art/ref/`, clean 240x160 grabs): sky-blue folder window with a notched tab,
black / purple striped inner panel, orange nav rule with the grey shoulder buttons, grey arrow keys, red / green / rainbow-segment
bars. 1 art px = 1 ap = 5 device px; the screen is 248 x 216 ap, everything is placed absolutely on that grid.
Chrome is drawn in code (`art/ui.py`, original pixel art in the game's palette); `art/layout.py` writes layout.json,
`art/css.py` expands `ap` units in `art/style.src.css`. Font: Silkscreen Regular (the game's text is 1 px strokes with a 1 px
black shadow to the right and below, which is exactly `text-shadow: 1ap 1ap 0`; Silkscreen *Bold* draws a broken "4").
The corner arrows pick the character (Status); the ▲▼ pick the item (Items).

**Game art that ships** (`assets/gfx`, cut by `art/extract.py` from the game's own screens): the 5 character portraits `p0..p4`,
45 item icons `i<slot>` and 45 large item pictures `b<slot>`. They are the game's artwork (Bird Studios / Webfoot / Atari).
README credits + disclaimer say so. The window chrome is original.

## How the data was found (no decompilation exists)

Headless mGBA harness (`megaman-zero-companion/art/mz-harness.c`, plus `mCoreAutoloadSave` so `rom.sav` loads) built against
`engine/mgba` with the Android SDK's cmake (`-DBUILD_QT=OFF -DBUILD_SDL=OFF -DUSE_*=OFF`, only `libmgba.a` needed). Key replay from
boot: START x4 (with ~90 frames between) lands in the status menu; R = next menu page, RIGHT = next character, DOWN = next item.
Dump IWRAM+EWRAM, search for the numbers on screen, repeat.

| What | Where (USA) | Notes |
|---|---|---|
| Character structs | IWRAM `0x03000E9C`, 0x1C apart: Gohan, Piccolo, Vegeta, Trunks, Goku, Hercule | +0 HP, +2 max HP, +4 EP, +6 max EP (u16), +0x0B STR, +0x0D POW, +0x0F END (u8, out of 100), +0x10 EXP (u32). A copy of the save is at EWRAM `0x0203E01C`. Hercule (slot 6) is a placeholder, not shown. |
| Level / NEXT | ROM `0x081D9830` + 4n = EXP needed for level n (n=1 is 0) | not stored: level = highest n with table[n] <= EXP, NEXT = table[level+1] - EXP. Matches Gohan L40 / 187863 and Trunks L33 / 17002. |
| Inventory | IWRAM `0x03000FBC`, 45 bytes (also EWRAM `0x0203E13C`) | slot 0 = the world-map Golden Cap, slots 1-15 = item table entries 0-14, slots 16-43 = entries 16-43, slot 44 = entry 45 (Dragon Radar). Entry 15 (Senzu Bean) has no slot. Entries 9-14 are placeholder names ("HealthBonusSmall"...) never owned. |
| Item table | ROM `0x080E2930`, name ptr + description ptr per entry | strings are plain ASCII, mixed case; the font is upper-case so CSS uppercases them |
| Finished quests | IWRAM `0x03000F9A`, one bit per quest, MSB first (also EWRAM `0x0203E11A`) | quest text: ROM table `0x086D68E8`, 16 bytes per entry (text ptr, kind 0 main / 1 side / 2 other, start-flag ptr, end-flag ptr), 42 entries + one more |

## Open

- The Options page (text speed / volume / sleep) and the world map are not mirrored.
- Live HP: the struct holds current HP at +0; confirm during a fight on the device.
- Not tested on the device. Import the zip (Settings > Packs) and check the font, the ▲▼ taps and scrolling of the long lists.

## Techniques (the game's Status > down arrow), found 2026-11-14

Each character has three entries: one melee and two energy techniques. ROM pointer tables of five (one per character, roster order Gohan, Piccolo, Vegeta, Trunks, Goku):
melee names `0x080E2AB4` / descriptions `0x080E2AC8`, first energy names `0x080E2ADC` / `0x080E2AF0`, second energy names `0x080E2B04` / `0x080E2B18`;
the locked placeholders are `0x080E2AA0` ("Special Melee Attack") and `0x080E2AA8` ("Special Energy Attack"), both with "This technique is not available yet" (`0x080E2AA4`, `0x080E2AAC`).
Unlock flags: byte +0x14 of the character struct, bit 2 = melee, bit 3 = first energy, bit 4 = second energy (bit 0 = joined, bit 6 is always set; bits 1 and 5 are set on every character in the real save and unused here).
Checked on all five characters of the real save and on the early save (Trunks, everything locked). Gohan's and Vegeta's melee (Super Kick and Two-Handed Smash by table order) are locked in the real save, so the game never showed their names.
On the Status page the up / down arrows step from the stat bars into the three techniques; the icon art of the techniques is not shipped.

## Active quests (the game's Quests tab), found 2026-11-14

Verified on 798 experiments (single flag / item / done-bit changes on the real save, read back from the game's own list, which sits in EWRAM
`0x0202D6CC` as 8-byte entries (quest text pointer + tag) while the Journal is open) and on an early save (only Trunks, "No quests outstanding").

- **The quest table is shifted by one.** The text of quest t is at `0x086D68E8 + 16t`, but its kind (0 main, 1 side, 2 other) and its start / end records are the fields of
  table entry t - 1 (entry -1, at `0x086D68D8`, serves quest 0). 43 texts (0-42); text 42 ("Retrieve the Bait ...") has no entry of its own.
- **Event flags** are one bit each, least significant bit first, starting at IWRAM `0x03000F44`: flag id n is bit (n & 7) of byte n >> 3 (not `0x03000F48`; an earlier note was off by 4 bytes).
- **Records** are small expressions in the ROM: term `00 <id> 02 13` = flag id is clear; term `00 <id> 02 15` = the item id is not owned (inventory slot id - 1 holds 0);
  terms are joined by `04` (or) and `05` (and), an expression ends with `11`; `00 00 11` is always true; `01 84 54` is a special term whose flag is `0x12A`.
  A quest is **active when its start is true and its end is false**. Finished quests are simply those whose end flag is set; the done bits (`0x03000F9A`) do not take part.
- **Who has joined:** bit 0 of byte +0x14 of a character struct. Characters that have not joined keep default stats (an early save shows only Trunks); the pack lists only joined ones.
  This also replaces the old "title screen defaults" guard, which hid early saves.
`test-quests.lua` runs the pack against a ROM + RAM dump and prints the active quests and the party.
The Journal page has two views: tap the title to switch between QUESTS (active, with a coloured dot for main / side / other) and FINISHED.

## Preview / build

```sh
python3 art/ui.py && python3 art/layout.py && python3 art/css.py
skill/preview-pack.sh dragon-ball-z-legacy-of-goku-2-companion --pages journal,status,items --no-tall
```
`art/extract.py <frames dir>` needs the headless frames (port0..4, it00..it44, empty); they are not kept in the repo.
Zip for release: everything except `art/`, `preview/`, `NOTES.md`, `preview-data.json`.

## Wide view (game.lua), found 2026-11-15

`game.lua` (manifest formatVersion 4, `gameScript`) paints the margins around the 240x160 frame. Needs an app with chunked 8bpp tilemap layers (`wide.c`, docs-packs/game-script.md).

- **How the game draws its map:** BG1..BG3 are 8bpp 256x256 px tori (BGnCNT 0x1d81 / 0x1e83 / 0x1f83: char base 0, screenblocks 29..31, mode 0; BG0 is HUD / leaves and has no map layer). The whole map stays in ROM as 256x256 px **chunks** (32x32 u16 tile entries, 2048 bytes), packed.
- **Layer objects** (EWRAM, 0x2030 bytes each: 0x28 header + four 0x800 chunk buffers): pointers in IWRAM `0x0300107C + 4 * bg`; word 0 = vtable `0x08023868`, +8 = descriptor in ROM, +0x1C..0x1F = ids of the four chunks it holds (a 2x2 window; the slot a chunk lands in changes, so read the ids), chunk buffers at +0x28 + slot * 0x800.
- **Descriptor** (ROM): +4 / +8 = 1024 (playable size in px), +0x0C / +0x10 = the layer's offset against the camera in 22.10 fixed point (BG1 64 px, BG2 128, BG3 192 in the first area), +0x14 / +0x15 = map size in chunks (5 x 5 there), +0x18 = u32 chunk pointers (row-major, id = cy * W + cx, 0 = empty).
- **Camera:** IWRAM `0x03001094` / `0x03001098` = s32 22.10 fixed point, the screen's top-left (integer copies at 0x0300109C / 0x030010A0, then the bottom-right at 0x030010A4 / A8). The BG scroll registers trail it by a frame while it moves (and round differently), and they are what the frame was drawn with, so `game.lua` takes each layer's position from its register (unwrapped against camera + offset) and names the world's origin from the bottom layer.
- **Chunk pointer 0x0869xxxx, header** u32 kind (always 1 here: 5315 of 5315 chunks), u32 size 0x800, then the packed stream.
- **The packer** is Webfoot's routine copied from ROM 0x087FD6BC to IWRAM 0x03000000 (ARM, dispatched through the Thumb stub at 0x080236A8). MSB-first bit stream of LE u32 words: `1` literal (r3 bits + base, defaults 8 and 0); `01` + gamma length: len 2 = repeat last distance with a new gamma length, otherwise `(len - 3) << shift | get(shift)` distance, gamma count, plus 3 / 2 / 1 / 0 / 4 for distances >= 0x10000 / 0x37FF / 0x27F / 0x80..0x27E / <= 0x7F; `000` + 7-bit distance + 2-bit length - 2; `0001` + 4 bits: 1 = zero byte, 2..15 = copy byte at that distance - 1, 0 = a control: `0` set literal bits (`1` = 8 bits base 0, `0` = 7 bits + 8-bit base) / `1` 256-byte raw blocks (a `1` bit after each continues); `0000000` + 2 bits: 0 = end, else set the distance shift to get(n + 3). Ported to Python (`wf.py` in the session scratch) and to C (`wide.c`, `pack_unpack`): verified bit for bit against the 12 chunks the game keeps in RAM and against all 5315 chunks in the ROM (C and Python agree).
- **Seam check on the real game** (headless snapshots at 5 places, XL 480x320): 88..96 % of the frame's background pixels reproduced exactly (the rest is Gohan, the HUD and BG0's leaves), seam match 0.94..1.0.
- Wide button: the grey `WIDE OFF / ON / XL` pill at the top of every page (the app handles `wideView` itself).

Not done: NPC / enemy markers (the actor lists are not mapped), BG0's leaves in the margins, other areas (interiors, the world map, battles) are untested: `wide()` returns nil unless BG1..BG3 are 8bpp layers with this engine's layer objects, and the app hides the margins when the frame does not match.

## Options page and margin sprites (2026-11-15)

- Pages now cycle JOURNAL, STATUS, ITEMS, OPTIONS (the WIDE pill is gone). OPTIONS holds the **WIDE VIEW** row: tap to step OFF, WIDE, XL (the app's reserved `wideView` action; `_wideLabel` shows the state).
- **Margin sprites:** `wide()` also returns `markers` read from OAM (0x07000000): every normal sprite (not affine, hidden, blended or window) that sticks out of the 240x160 frame is drawn whole in the margin, from its tiles in OBJ VRAM (0x06010000 + tile * 32; the game's sprites are 8bpp, 256-colour OBJ palette 0x05000200). Needs the app's `bpp` / `vflip` marker fields. The game puts a sprite in OAM only while it is on or near the screen and loads its tiles then, so nothing farther out can be drawn; the y of an OAM sprite is 8 bits, so 192..255 is read as above the screen and 160..191 as below it (a guess, unverified live).
- **Edge clamp:** the map is the bounding box of the ground layer's non-empty tiles (`trimBounds = 1` on the bottom layer; tile 0 is empty), not the descriptor's size: every descriptor in the ROM says 1024 x 1024 (+4 / +8), outdoors and indoors, so indoors that made the clamp pin the frame to the left of the picture. The ground tiles give the real extent (outdoors world 0..1024; rooms e.g. 256 x 160, 240 x 104, found by decoding every map in the ROM). Near an edge the wide picture stops scrolling and the frame slides toward it; a room smaller than the picture stays centred with black around it (margins outside the map are blanked). Checked on a faked corner camera outdoors (frame lands at 20,30); indoors only through the ROM survey and unit tests, not yet on the Thor.
