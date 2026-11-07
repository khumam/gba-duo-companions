---
title: Add your games
description: Point GBA Duo at your ROM folders, open games from launchers, and learn the controls.
---

GBA Duo doesn't copy or move your games. It scans folders you choose and lists every
game it finds in your library.

**No games are included.** Use your own legally dumped ROMs.

## Add a ROM folder

1. Open GBA Duo and tap the **gear (⚙)** button in the library to open **Settings**.
2. Tap **ROM folders**, then **Add folder…**.
3. Pick the folder that holds your games and allow access.

Every `.gba`, `.gbc` and `.gb` file in the folder shows up in your library. Zipped
ROMs work too: a `.zip` holding one GBA, GBC or GB ROM appears in the library and
plays directly. A zipped game shares its saves and companion pack with the unzipped copy.

You can add as many folders as you like.

## Remove a folder

In **Settings › ROM folders**, remove a folder to take its games out of the library.
**Removing a folder never deletes its files.**

## Open games from a launcher

Frontends such as **ES-DE**, **Daijisho** and **Cocoon**, and file managers ("Open with"),
can start a game in GBA Duo directly. Picking another game replaces the one that's running.

- The game has to be inside one of your ROM folders. If it isn't, GBA Duo tells you to
  add its folder under **Settings › ROM folders**.
- For Cocoon, GBA Duo needs to be in its player catalog. For now you can import a
  custom platform with GBA Duo as the player.

## The library

Your games are listed with a **platform filter** that steps through All, GBA, GBC and GB
(platforms with no games are skipped) and a **List** or **Shelf** view. The filter is remembered.

## Controls

These are the defaults. Change any of them in **Settings › Controller**
(see [Settings](/docs/settings#controller)).

| AYN Thor  | Game                         |
| --------- | ---------------------------- |
| D-pad     | D-pad                        |
| A / B     | A / B                        |
| L1 / R1   | L / R                        |
| Start     | Start                        |
| Select    | Select                       |
| R2 (hold) | Fast-forward                 |
| L2        | Quick menu                   |
| BACK      | Quick menu (always)          |

A and B match the labels on the Thor's buttons. To swap them, use
**Settings › Controller › Button mapping**.

The controller keeps driving the game whichever screen has focus, so tapping the
companion never takes it away.

## The quick menu

Press **L2** or **BACK** while playing to open the menu:

- **Resume**
- **Save state** / **Load state**: 9 slots per game, each showing when it was saved.
  **Before pack changes** appears under Load state once a pack has
  [changed the game](/docs/settings#packs-can-change-games).
- **Fast-forward**: 2x, 3x or 4x, used while you hold R2.
- **Shader**: opens the Shader page for this game. It shows what is in use, the built-in shaders (Off, LCD Grid, Scanlines, Scale2x) and the [libretro](https://github.com/libretro/slang-shaders) shader library, which you browse by folder and download. Downloaded shaders work offline.
- **Tilt-shift**: Off, Light or Strong blur at the top and bottom of the picture.
- **Integer scaling**: On for exact pixels (a smaller picture), Off for a full-size one.
- **Quit**

Hotkeys can do most of this without opening the menu: see
[Settings › Controller](/docs/settings#controller).

In-game saves are kept per game, next to its save states. To keep a copy of them
somewhere else, like the SD card, set a [save folder](/docs/settings#save-folder).

Next: [Import companion packs](/docs/import-packs).
