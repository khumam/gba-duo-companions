---
title: Settings
description: Remap the controller, tune how the picture looks, find covers, keep your saves in a folder you choose, earn RetroAchievements, and decide whether packs can change your games.
---

Tap the **gear (⚙)** button in the library to open **Settings**. Everything here works
with the controller too: move with the D-pad, pick with A, go back with B.

## Controller

**Settings › Controller** has two pages. These are the defaults:

| Thor      | Game                |
| --------- | ------------------- |
| D-pad     | D-pad               |
| A / B     | A / B               |
| L1 / R1   | L / R               |
| Start     | Start               |
| Select    | Select              |
| R2 (hold) | Fast-forward        |
| L2        | Quick menu          |
| BACK      | Quick menu (always) |

- **Button mapping** lists every game button and the Thor button that presses it. Pick a
  row, press a button, done. A button used elsewhere swaps places with it. **Reset to
  default** restores the table above.
- **Hotkeys** has seven actions: open the quick menu, fast-forward (hold or toggle),
  quick save state, quick load state, next and previous save slot, and exit game. Each
  is one button, or the **hotkey button** plus a button. The hotkey button is none by
  default. While you hold it nothing reaches the game; a button it shares with a game
  button reaches the game when you let go. Exiting asks you first.
- BACK always opens the quick menu, so you can't lock yourself out.

## Picture

These apply to every game. Shader and color correction can also be set for one game
(see [Game settings](#game-settings)).

- **Shader**: the default look, on the Shader page: the built-in shaders and the [libretro](https://github.com/libretro/slang-shaders) library (browse its folders, download one, use it). Library shaders need OpenGL ES 3.0 or newer; a few heavy ones may not run on every device, and then the page says why and the previous shader stays on. Press and hold a downloaded shader (or Y) to remove it.
- **Color correction**: Off, **GBA screen** or **Game Boy Color screen**, so colors look
  like the real handheld's screen instead of a flat monitor.
- **Aspect ratio**: Original, 4:3, 16:9, or Stretch to screen.
- **Tilt-shift blur**: Off, Light or Strong blur at the top and bottom of the picture.
  Also in the quick menu.
- **Integer scaling**: On draws exact pixels at a smaller size; Off fills the screen.
  Also in the quick menu.
- **Performance overlay**: Off, FPS, or FPS + CPU over the game.

## Game settings

In the library, press **X** on a game (or open its game settings) for the settings of
that one game:

- **Shader** and **Color correction**: follow the defaults above, or pick one for this game.
- **Cover**: find one on SteamGridDB, use an image from your artwork folder, remove it,
  or **Reset to automatic** so a scrape can set it again.

Wide view is a per-game setting too, switched from the companion screen:
see [Wide view](/docs/wide-view).

## Scraping covers

**Settings › Scraping** finds a cover for each game's cartridge in the library.

1. Under **Providers**, set up where covers come from. A scrape tries them from the top.
   - **Artwork folder**: a folder you choose, read only. Images are matched by ROM
     name, title, game code or checksum. Screenshots and logos are skipped.
   - **SteamGridDB**: needs a free API key (steamgriddb.com › Profile › Preferences ›
     API). Only game titles are sent.
2. Tap **Scrape library**. It skips games that already have a cover, and games whose cover
   you removed. **Replace existing covers** changes that.
3. **Remove all covers** clears them again; your artwork folder and SteamGridDB aren't touched.

## Save folder

Every game's saves live in GBA Duo's private storage, one folder per game:

```txt
<platform>/<Title> [<code>-<CRC32>]/
    game.sav          the game's own save
    states/slotN.ss   save states
    pack.json         the companion pack picked for it
```

Folders are named by the ROM's checksum, so a game finds its saves wherever the ROM
file is and whatever it's called.

**Settings › Save folder** keeps a copy of all of them in a folder you pick: the SD
card, or a folder another app syncs.

- Games still play from the private copy. It's copied to the folder after each in-game
  save and save state, on pause and on quit.
- Newer saves already in the folder, say from another device, are taken in when a
  game starts.
- The first time, every save is copied over and checked before the folder is used. If
  any copy fails, nothing changes.
- If a save changed in both places, the newer one is kept and the other is saved next
  to it as `game.sav.conflict-<time>`. Nothing is overwritten silently.
- If the folder can't be reached (SD card out), the game plays from the private copy
  and the folder catches up once it's back.
- Companion packs and the ROM list stay private.

**To back up**, copy the folder. **To move to another device**, copy it there and pick
it as the save folder. **Stop using folder** leaves the folder and the saves in it as
they are.

## RetroAchievements

Earn [RetroAchievements](https://retroachievements.org) while you play.

1. Open **Settings › RetroAchievements**.
2. Log in with your retroachievements.org account.
3. Start a game. A summary shows how many of its achievements you've unlocked, and
   each new unlock pops up over the game.

- Unlocks still count as **softcore** for now: RetroAchievements has to approve GBA Duo
  before hardcore points are recorded.
- **Hardcore mode** (in the same screen) is a switch you can already use. With it on, a game
  you start has no save or load state, no fast-forward, and no pack writing to the game's
  memory (packs still load, but any change they try is blocked and they show as read-only).
  It applies from the next game you start.
- GBA Duo keeps the login token RetroAchievements gives it, never your password.
- It only goes online while you're logged in: to identify each game you start and
  record your unlocks. If the connection drops, unlocks are sent later.

## Packs can change games

Some companion packs can change a game's memory when you tap them, for example to
equip an item without opening the menu. This is **off** until you turn on
**Settings › Packs can change games**.

When it's on:

- The first time a pack is about to change a game, GBA Duo asks, naming the pack and
  the game. Your answer is kept for that pack and game.
- If the pack is updated or replaced, it asks again.
- A save state is made just before the first change. **Load state › Before pack
  changes** takes you back.
- Packs only change the game from your taps, a few bytes at a time, and only the
  game's work RAM: never the ROM or your save file directly.

In the pack picker, packs that can do this are marked "can modify the game". A bad
change can crash a game or spoil a save, so only allow packs you trust.

Pack makers: see [Changing the game](/docs/pages#changing-the-game).

## Check for updates

**Settings › About › Check for updates** asks GitHub for the newest release. If there is one,
tap **Download and install**; Android may ask once to let GBA Duo install apps. It installs over
the old version, so your saves stay. GBA Duo only checks when you tap the button.

## Also in Settings

- **ROM folders**: where your games come from. See [Add your games](/docs/games).
- **About**: version, licenses and credits.
