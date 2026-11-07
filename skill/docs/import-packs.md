---
title: Import companion packs
description: Download a companion pack and give a game its second-screen companion.
---

A companion pack is what a game shows on the second screen. Each pack is made for
specific games, and each game remembers the pack you chose for it.

## Get a pack inside GBA Duo

The quickest way. In your library, tap **⋮** next to the game, then **Companion pack ›
Get from the web…**. GBA Duo lists the packs made for that game (and other versions of
it), downloads the one you pick and installs it. Packs already installed say
**installed**, newer ones say **update available**, and a pack that needs a newer
GBA Duo says so. Every download is checked against the pack list before it's installed.

## Or download a pack yourself

Packs live in the packs page,
[browse all packs](https://gbaduo.com/packs). On your device:

1. Open the [packs page](https://gbaduo.com/packs).
2. Download the `.zip` for your game. Don't unzip it.

Most packs need GBA Duo **v0.1.7** or newer. Each pack on the packs page says which
version it needs; Pokémon's **WIDE** button needs **v0.1.9**, Golden Sun's Maps page and
**WIDE** button need **v0.1.11**, and the **COLOR** look and Emerald need **v0.1.12**.

## Import it

If you downloaded the `.zip` yourself:

1. In your GBA Duo library, tap **⋮** next to the game.
2. Under **Companion pack**, tap **Import pack…** and pick the `.zip` you downloaded.
3. Start the game. The companion shows on the other screen.

To switch packs, or pick **None** to turn the companion off, use the same **⋮**
menu at any time.

Packs marked **can modify the game** can change the game's memory from a tap. They
only do it if you allow it: see [Packs can change games](/docs/settings#packs-can-change-games).

## Available packs

Please check at [packs page](https://gbaduo.com/packs)

Packs match games by the 4-letter game code in the ROM header, so a pack only shows
up for the regions it supports.

## The pack doesn't show up

- Check the game's region against the detail of each pack description.
- Make sure you imported the `.zip` itself, not a folder or a re-zipped folder.
  If you zip a pack yourself, `manifest.json` must be at the root of the zip.
- If import fails, GBA Duo shows "Could not import pack" with the reason.

Want a pack for another game?
[Open an issue](https://github.com/khumam/gba-duo-companions/issues), or
[make your own](/docs/first-pack).
