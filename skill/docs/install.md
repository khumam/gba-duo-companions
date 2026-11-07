---
title: Install the APK
description: Download GBA Duo and install it on your dual-screen Android handheld.
---

GBA Duo isn't on the Play Store. You install it from an APK file published on
[GitHub releases](https://github.com/khumam/gba-duo/releases/latest). It's free,
and it stays offline unless you log in to RetroAchievements.

## On the device

1. On your handheld, open the
   [latest release](https://github.com/khumam/gba-duo/releases/latest) in a browser.
2. Under **Assets**, download `gbaduo-<version>.apk`.
3. Open the downloaded file. If Android asks, allow your browser or file manager to
   **install unknown apps**, then go back and tap **Install**.
4. Open **GBADuo** from your app drawer.

> Android only asks for "install unknown apps" permission once per app (your browser
> or file manager), not once per APK.

## From a computer with adb

If you have [adb](https://developer.android.com/tools/adb) set up and USB debugging
turned on:

```sh
adb install gbaduo-v0.1.11.apk
```

Use `adb install -r` to replace an installed version.

## Updating

GBA Duo doesn't check for updates. Download the newer APK from the
[releases page](https://github.com/khumam/gba-duo/releases) and install it over the
old one. **Your saves, save states and packs stay.**

## Which screen?

Open GBA Duo on either screen. The game plays on the screen you opened it on, and
the companion takes the other one. On the AYN Thor that's usually the game on the top
screen and the companion on the bottom.

## Privacy

GBA Duo has no ads or analytics and needs no sign-up. It only goes online if you log in
to [RetroAchievements](/docs/settings#retroachievements), to identify the game you start
and record your unlocks. Your games, saves and packs stay on your device, unless you pick
a [save folder](/docs/settings#save-folder) that syncs somewhere.

Next: [Add your games](/docs/games).
