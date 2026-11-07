# The public docs site and the browser simulator

GBA Duo's public site has `/docs`, `/packs` (the pack catalog) and `/simulator`. Its docs are plain
Markdown (frontmatter `title`, `description`), and a copy of every page is bundled in this skill's
`docs/` folder, so the skill works offline.

## Docs map (what lives where)

Every page is in `docs/<slug>.md` (the overview is `docs/index.md`). Links inside them are site paths
(`/docs/pages#...`); read them as the file of the same slug. The bundled copy can lag the live site.

| Slug | Page | Read it for |
|---|---|---|
| (index) | Overview | requirements: Android 11+, arm64, tested on the AYN Thor |
| `install` | Install the APK | player setup |
| `games` | Add your games | ROM folders |
| `import-packs` | Import companion packs | zip import, replacing a pack with the same `id` |
| `settings` | Settings | controller, picture, scraping, **save folder**, RetroAchievements, **Packs can change games**, hardcore mode |
| `wide-view` | Wide view | what players see, which games, app versions, Ambient (COLOR) |
| `first-pack` | Your first pack | manifest field table, a minimal script/layout/style, simulator, zip + import, debugging |
| `layout` | Layout and widgets | binding syntax, truthiness, every widget |
| `styling` | Styling with CSS | selectors, properties, `@media`, `calc()`, grids |
| `pages` | Taps and pages | `onClick`, UI state, `pages`, `actions`, `gfx`, writing the game |
| `lua` | Lua API | `mem.*`, `lz77`, `gfx.*`, `pack.require`, `log`, sandbox, no-script `values` |
| `game-script` | game.lua, Wide view and Ambient | hooks, `wide()` fields, `layers`, Ambient fields, reserved actions |

The GBA Duo app repo's `docs-packs/*.md` and the site pages carry the same contract; the site adds
the pack-maker walkthrough and the player-facing behaviour. When they disagree, the app repo wins.

When writing a pack's own README or catalog text, link the player-facing pages rather than
re-explaining: Wide view (`/docs/wide-view`), Settings (`/docs/settings`, for the write consent).

## The browser simulator (`/simulator`)

A second way to preview, next to `preview-pack.sh`:

| | `preview-pack.sh` | Browser simulator |
|---|---|---|
| Engine | the app's real Kotlin engine under Robolectric (exact) | the simulator's engine ported to the browser, synced from the app |
| Needs | JDK 17 + the app repo | a browser (Chrome/Edge to save edits back to disk) |
| Output | PNGs at the Thor's size (+ a tall overflow canvas), `report.txt` warnings | live preview that updates as you type |
| Best for | final checks, warnings, regression pictures, analysis | quick iteration on layout/CSS/`preview-data.json` |

Workflow: open `/simulator` → **Open pack folder…** → edit `layout.json`, `style.css` and
`preview-data.json` side by side. **Blank starter pack** is the pack from "Your first pack". Chrome
and Edge write edits straight back to the files; other browsers open the folder read-only. The
simulator doesn't run Lua: it shows `preview-data.json`, a JSON object shaped like what `update()`
returns, so keep it complete for every state (this is the same rule as for `preview-pack.sh`).
Its engine is a port of the app's, so it can lag a feature the app just got: trust `preview-pack.sh` and the
device when they disagree.

Use the simulator while designing, `preview-pack.sh` before releasing, the device for ROM-drawn art,
Wide view, Ambient and writes (none of which either preview can show).

## Facts the docs site states that are easy to miss

- **Snapshot built-ins:** `_frameCounter` (frames so far) and `_scriptError` (the message when
  `update()` threw). Show the error while developing:
  `{ "type": "text", "text": "{_scriptError}", "visibleIf": "$_scriptError" }`.
- **Truthiness:** `visibleIf`/`classIf` treat missing, `false`, `0`, `""` and empty lists/tables as false.
  Whole numbers print without a decimal point; a missing value is empty text.
- **List scope:** inside a `list` template a path looks in the item first, then the whole snapshot;
  `{@index}` counts from 0. Paths reach into tables and arrays: `trainer.name`, `party[0].hp`.
- **`init()`** runs once per game start with the bigger load budget (5M instructions, 250 ms): build
  ROM-derived tables there. Top-level locals keep their values between ticks.
- **Returned data:** strings, numbers, booleans and tables, up to 32 levels; keys 1..n become an array.
- **`mem.read(addr, n)`** returns ≤ 65,536 bytes (use `string.unpack("<I2I2", raw)`), each byte
  costs one instruction; reads return 0 with no game loaded. Readable: EWRAM, IWRAM, I/O, ROM.
- **Sandbox:** Lua 5.4 with `string`, `table`, `math`, `utf8`; `io`, `os`, `require`, `load*`, `dofile`,
  `print`, `collectgarbage` are gone. Use `pack.require(name)` (letters, digits, `_ - .`; no paths) and
  `log(msg)` (tag `GBADuoPack`). That's why packs are safe to share.
- **No-script packs:** `manifest.values` reads fixed addresses (`{ "addr", "type", "mask", "shift" }` or
  `{ "ptr", "offset", "type" }`); `update()` wins on the same key. Good for a first prototype.
- **`gfx.layers` with one grid** works too (Emerald's Map page). The key depends on the pixels, so a map
  that moves yields a new picture each call: redraw only when the view changes (Golden Sun follows the
  player a tile at a time). Put the player's marker on top with an absolutely positioned `box`.
- **Hardcore mode** (RetroAchievements) blocks pack writes; the pack still loads but shows as read-only.
  `_writePermLabel` reads `OFF` then. Write a refusal message for it.
- **Saves and states** are per game in private storage (`game.sav`, `states/slotN.ss`, `pack.json`),
  named by ROM checksum; the optional save folder mirrors them. A pack can't save for the player.
- **Debugging:** `adb logcat -s GBADuoPack Companion PackStyles EmuThread GBADuoScript GBADuoCore`.
- **Importing:** zip the *contents* so `manifest.json` is at the zip root
  (`cd my-pack && zip -r ../my-pack.zip . -x '.*'`); a pack with the same `id` is replaced. Exclude
  `art/`, `screenshoots/`, `NOTES.md`, `preview/` and `preview-data.json` from release zips.
- **Version gates (player-facing):** Wide view needs GBA Duo v0.1.9 (FireRed/LeafGreen), v0.1.10
  (Minish Cap), v0.1.11 (Golden Sun), v0.1.12 (Emerald). The site states Ambient needs v0.1.12; the
  packs README says v0.1.13 for the COLOR look. Check the app repo's release notes before promising a
  version in a pack's text, and set `minAppVersion` in the catalog accordingly.
- **Games without a world description** keep black margins; a different region or a ROM hack may not
  line up. Say which releases a pack was checked on in its README row and `NOTES.md`.

