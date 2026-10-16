<div align="center">

<img src="https://raw.githubusercontent.com/khumam/gba-duo/main/art/banner.png" alt="GBA Duo: play GBA, GBC and GB games with a companion on the bottom screen" width="100%">

<h3>Companion packs for GBADuo: what your game shows on the bottom screen.</h3>

<p>
  <a href="https://github.com/khumam/gba-duo-companions/releases/latest"><img src="https://img.shields.io/github/v/release/khumam/gba-duo-companions?label=packs&color=6c4ab6" alt="Latest packs release"></a>
  <a href="https://github.com/khumam/gba-duo/releases/latest"><img src="https://img.shields.io/github/v/release/khumam/gba-duo?label=app&color=e3a008" alt="Latest GBADuo release"></a>
</p>

<p>
  <strong><a href="https://github.com/khumam/gba-duo-companions/releases/latest">Download packs</a></strong>
  · <strong><a href="#packs">Packs</a></strong>
  · <strong><a href="#make-a-pack">Make a pack</a></strong>
  · <strong><a href="https://github.com/khumam/gba-duo">GBADuo app</a></strong>
  · <strong><a href="https://github.com/khumam/gba-duo-companion-simulator">Simulator</a></strong>
</p>

</div>

[GBADuo](https://github.com/khumam/gba-duo) plays Game Boy Advance, Game Boy Color
and Game Boy games on the top screen of a dual-screen handheld like the AYN Thor. The
bottom screen shows a **companion pack**: a layout, CSS and a Lua script that read the
game's memory as you play. This repo holds the packs, one folder each.

## Install a pack

1. Download the pack's `.zip` from the
   [latest release](https://github.com/khumam/gba-duo-companions/releases/latest) on the device.
2. In GBADuo, tap **⋮** next to the game, then **Import pack…**, and pick the zip.
3. Start the game. The companion shows on the bottom screen.

Each game remembers its pack; change it any time from the same **⋮** menu.
The packs need GBADuo **v0.1.3** or newer.

## Packs

### Pokémon FireRed — `pokemon-firered-companion`

For Pokémon FireRed (US, game code `BPRE`). Design: *Cinnabar Nightfire*, a volcano at
night behind obsidian and molten-bronze panels.

- **PARTY** - your team with a type-coloured orb, types, levels, HP bars that turn amber
  and red, and status tags; the lead Pokémon gets a molten frame.
- **BAG** - every pocket: items, key items, Poké Balls, TMs & HMs, berries.
- **TRAINER** - your trainer card (name, ID, money, play time), the eight badges, and
  Pokédex seen/caught.
- **BATTLE** - opens by itself when a battle starts and goes back when it ends: both
  Pokémon with their types, HP and live stats, with stat changes (+1, -2…) marked.

### Harvest Moon: Friends of Mineral Town — `harvest-moon-fomt-companion`

For Harvest Moon: Friends of Mineral Town (EU `A4NP`, US `BHFE`). Checked on the EU cart.
Design: *The Mineral Town Almanac*, a storybook farm whose backdrop follows the in-game
season and darkens to a starry sky at night.

- **FARM** - date and time, today's and tomorrow's weather, gold, the tool in your hand,
  stamina and fatigue, and records.
- **BAG** - your rucksack: tools (the one in your hand first) and items.
- **LOVE** - the bachelorettes with their heart colour, and every villager's friendship.
- **SPRITES** - each Harvest Sprite's friendship, today's job and work experience
  (harvesting, watering, animals).

See [`harvest-moon-fomt-companion/NOTES.md`](harvest-moon-fomt-companion/NOTES.md) for
what's verified on the device and what isn't yet.

### The Legend of Zelda: The Minish Cap — `zelda-minish-cap-companion`

For The Minish Cap (US `BZME`, EU `BZMP`, JP `BZMJ`). Design: *Enchanted forest*, the world
at Minish size, with leaf-framed plaques over a firefly-lit canopy.

- **LINK** - hearts and heart pieces, where you are, the A and B items, rupees and wallet,
  shells, bombs and arrows, bottles, and the active charm or picolyte with its time left.
- **ITEMS** - the four elements, your best gear, tiger scrolls learned and quest items.
- **KINSTONES** - pieces in the bag by colour, and fusions done out of 100.
- **DUNGEONS** - each dungeon's keys, map, compass and big key, which ones are cleared,
  and the one you're in.

See [`zelda-minish-cap-companion/NOTES.md`](zelda-minish-cap-companion/NOTES.md) for
what's verified on the device and what isn't yet.

Want a pack for another game? [Open an issue](https://github.com/khumam/gba-duo-companions/issues).

## Make a pack

A pack is a folder:

```
my-pack/
  manifest.json       id, name, version, which games it's for, update rate
  layout.json         the screen: boxes, text, images, bars, lists, tabs, pages, buttons
  style.css           real CSS: flex and grid, colors, borders, shadows, fonts, transitions
  main.lua            update() reads the game's memory and returns the values to show
  preview-data.json   sample values for the simulator (not used on the device)
  assets/             fonts and images
```

`manifest.json` matches games by `gameCode` (the 4-letter code in the ROM header) or by
`crc32`; `tickHz` is how often `update()` runs.

The guides live in the app repo:

- [Styling the companion](https://github.com/khumam/gba-duo/blob/main/docs-packs/companion-styling.md) - layout widgets, CSS selectors and properties, fonts.
- [Pages and buttons](https://github.com/khumam/gba-duo/blob/main/docs-packs/companion-pages.md) - `onClick`, pages, and switching pages from `update()`.
- [Examples](https://github.com/khumam/gba-duo/tree/main/docs-packs/examples).
- [`skill/enchanted-forest-pack-design`](skill/enchanted-forest-pack-design) - the design
  system behind these packs (art kit, base stylesheet, layout snippets, preview renderer),
  packaged as a Claude Code skill.

<details>
<summary><strong>Preview while you build</strong></summary>

The [companion simulator](https://github.com/khumam/gba-duo-companion-simulator) renders
a pack the way the app does. Open the pack's folder in it, edit `layout.json`,
`style.css` and `preview-data.json` side by side, and see the result straight away.
It doesn't run `main.lua`, so it shows the values in `preview-data.json`.

Then confirm on the device: zip the pack folder's contents (with `manifest.json` at the
root of the zip) and import it in GBADuo.

</details>

<details>
<summary><strong>Releasing packs</strong></summary>

Each release has one zip per pack, named `<pack-id>-<version>.zip`, with the pack's files
at the root of the zip. Bump `version` in the pack's `manifest.json` when it changes.
`art/` holds the SVG sources and the script that draws `assets/img/`; it stays out of the zip.

```sh
cd my-pack && zip -rX ../my-pack-1.0.0.zip . -x '*.DS_Store' 'art/*'
```

</details>

## Credits

<details>
<summary>Memory maps and fonts</summary>

- FireRed: the [pret](https://github.com/pret) pokefirered decompilation, and the
  Ironmon-Tracker's FireRed address table for battle data.
- Harvest Moon: [Data Crystal's RAM map](https://datacrystal.tcrf.net/wiki/Harvest_Moon:_Friends_of_Mineral_Town/RAM_map)
  and samurai goroh's code guide.
- The Minish Cap: the [zeldaret](https://github.com/zeldaret/tmc) tmc decompilation and
  samurai goroh's code guide.
- Fonts: [Silkscreen](https://fonts.google.com/specimen/Silkscreen),
  [Bungee](https://fonts.google.com/specimen/Bungee),
  [Barlow Semi Condensed](https://fonts.google.com/specimen/Barlow+Semi+Condensed),
  [Sniglet](https://fonts.google.com/specimen/Sniglet), [Mali](https://fonts.google.com/specimen/Mali),
  [Uncial Antiqua](https://fonts.google.com/specimen/Uncial+Antiqua),
  [Cinzel Decorative](https://fonts.google.com/specimen/Cinzel+Decorative) and
  [Alegreya Sans](https://fonts.google.com/specimen/Alegreya+Sans), under the SIL Open Font License 1.1.
- Art: every image in the packs is original, drawn in code by each pack's `art/build.mjs`.

</details>

## Disclaimer

These packs are fan-made, not affiliated with or endorsed by Nintendo, Game Freak,
Creatures, The Pokémon Company or Marvelous. Pokémon, Harvest Moon, The Legend of Zelda and all related
names are trademarks of their respective owners. No games or game art are included:
use your own legally dumped ROMs.
