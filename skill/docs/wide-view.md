---
title: Wide view
description: Paint more of the game's world beside the picture, for packs that support it.
---

**Wide view** draws the game's own 240x160 picture in the middle of a wider one and
paints the world beside it, read from the game's memory. On a wide screen you see the
cliffs, rivers and rooms the game keeps just off-screen, instead of black bars.

## Turn it on

Wide view is per game and is switched from the **companion screen**, not the quick menu:
tap the pack's **WIDE** (or **Wide**) button. Each tap steps through **OFF**, **ON** (wider)
and **XL** (taller as well, so the world also shows above and below a smaller picture). A game
remembers its choice.

If the pack has no Wide view, tapping it says so.

## Which games

A pack has to describe the game's world, so it only works where a pack does:

| Game | Pack | Needs GBA Duo |
| --- | --- | --- |
| Pokémon FireRed and LeafGreen (US) | all FireRed and LeafGreen packs | v0.1.9 |
| The Legend of Zelda: The Minish Cap | Minish Cap companion | v0.1.10 |
| Golden Sun (US) | Golden Sun companion | v0.1.11 |
| Pokémon Emerald (US) | Emerald companion | v0.1.12 |

Packs are made against one release of a game, so a different region or a ROM hack may not
line up. When that happens nothing breaks: the margins just stay black.

## What you'll see

- The margins show **the map**: ground, water, walls, roofs. People and monsters aren't
  part of it, so they don't appear out there; they pop in when they walk onto the real picture.
  A pack can add small **markers** on top of the margins: in FireRed and LeafGreen, white
  dots for people, red for trainers, yellow for items and cyan for doors, hidden once an item
  is picked up or a trainer is beaten.
- Menus, battles and screens the pack doesn't describe keep black margins.
- GBA Duo checks every frame that the pack's description matches what the game drew. If it
  stops matching, for example while the game fades or changes screen, the margins hide
  after a moment and come back once it matches again. A wrong guess looks like "no wide
  view", never like garbage.
- Wide view costs a few percent of one CPU core.

## Ambient (COLOR)

Some packs also have an **Ambient** button, often labelled **COLOR**. It gives the picture a
fuller look: a colour grade, softly darkened edges, and light that knows what is in front of
what, so sprites throw soft shadows, edges facing the sun catch light and clouds drift over open
ground. The pack sets the look and can change it by place, for example indoors or in a cave. It is
per game, like Wide view, and shows **N/A** when the pack has no look. Needs GBA Duo v0.1.12.

Pack makers: see [game.lua, Wide view and Ambient](/docs/game-script).
