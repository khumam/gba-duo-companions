---
title: GBA Duo docs
description: Install GBA Duo, add your games, import companion packs, and build your own.
---

GBA Duo plays Game Boy Advance, Game Boy Color and Game Boy games on dual-screen
Android handhelds. The game runs on the screen you open the app on, and the other
screen shows a **companion**: a pack that reads the game's memory as you play and
shows what matters, like your party, your bag, or the map.

## Playing

New here? These three pages get you from download to playing with a companion:

1. [Install the APK](/docs/install): download GBA Duo and install it on your device.
2. [Add your games](/docs/games): point GBA Duo at the folders where you keep your ROMs.
3. [Import companion packs](/docs/import-packs): give a game its bottom-screen companion.

Then, in [Settings](/docs/settings): remap the controller, tune the picture, find covers,
keep your saves in a folder you choose, earn RetroAchievements, and decide whether packs may
change your games. For games whose pack supports it, [Wide view](/docs/wide-view) paints the
world around the picture (wider, or XL), and **Ambient** can give it a fuller look.

## Making packs

A pack is a folder of plain files: a layout, a stylesheet and a Lua script. If you
can write a little CSS and Lua, you can make one for your favorite game.

- [Your first pack](/docs/first-pack): from an empty folder to a pack running on your device.
- [Layout and widgets](/docs/layout): the building blocks in `layout.json` and how they bind to data.
- [Styling with CSS](/docs/styling): selectors, properties and how they differ from a browser.
- [Taps and pages](/docs/pages): buttons, detail pages and switching pages from the game.
- [Lua API](/docs/lua): reading memory, drawing the game's own graphics and live maps, and the script's sandbox.
- [game.lua, Wide view and Ambient](/docs/game-script): a script that runs against the game every frame, how to describe a world for the wide margins, and how to give the picture a look.

## Requirements

- A dual-screen Android device running **Android 11 or newer** (arm64). GBA Duo is made
  for and tested on the **AYN Thor**; other dual-screen devices should work but haven't been tested yet.
- Your own legally dumped ROMs. **No games, BIOS or game art are included.**
