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
Most packs need GBADuo **v0.1.3** or newer; the Metroid and Oracle of Ages packs need **v0.1.8**.

## Packs

Each pack is a folder; the zip name is `<pack>-<version>.zip` on the
[latest release](https://github.com/khumam/gba-duo-companions/releases/latest).

### Pokémon

| Pack | Game | Game codes | Pages | Version | Notes |
|---|---|---|---|---|---|
| [`pokemon-firered-companion`](pokemon-firered-companion) | Pokémon FireRed | `BPRE` | Map, Party, Bag, Dex, Card, Battle | 2.0.0 | *Pocket-OS*: a chunky handheld interface with hazard-striped headers. The Town Map is read from your ROM; the Battle page opens by itself when a battle starts. |
| [`pokemon-firered-v-companion`](pokemon-firered-v-companion) | Pokémon FireRed | `BPRE` | Map, Party, Bag, Dex, Card, Battle | 1.0.0 | Same pages with a vertical dock on the right. |
| [`pokemon-firered-minimal-companion`](pokemon-firered-minimal-companion) | Pokémon FireRed | `BPRE` | Map, Party, Bag, Dex, Card, Battle | 1.0.0 | Calm one-colour skin in soft red: flat fills, no shadows, a text-only dock. |
| [`pokemon-leafgreen-companion`](pokemon-leafgreen-companion) | Pokémon LeafGreen | `BPGE` | Map, Party, Bag, Dex, Card, Battle | 1.0.0 | The FireRed pack for LeafGreen, with horizontal navigation. |
| [`pokemon-leafgreen-v-companion`](pokemon-leafgreen-v-companion) | Pokémon LeafGreen | `BPGE` | Map, Party, Bag, Dex, Card, Battle | 1.0.0 | Same pages with a vertical dock on the right. |
| [`pokemon-leafgreen-minimal-companion`](pokemon-leafgreen-minimal-companion) | Pokémon LeafGreen | `BPGE` | Map, Party, Bag, Dex, Card, Battle | 1.0.0 | Calm one-colour skin in soft green. |

### Metroid

| Pack | Game | Game codes | Pages | Version | Notes |
|---|---|---|---|---|---|
| [`metroid-zero-mission-companion`](metroid-zero-mission-companion) | Metroid: Zero Mission | `BMXE` `BMXP` `BMXJ` | Map, Status, Sectors, Log | 1.0.0 | The game's pause screen. Your explored map centered on Samus, her suit with the beams and gear you own (tap one to switch it on or off), area progress, boss targets and recovered tanks. Needs **GBADuo v0.1.8** and, for the switches, **Settings > Packs can change games**. See [NOTES](metroid-zero-mission-companion/NOTES.md). |
| [`metroid-fusion-companion`](metroid-fusion-companion) | Metroid Fusion | `AMTE` `AMTP` `AMTJ` | Map, Status, Arms, Sectors, Mission | 2.0.0 | The game's pause screen. Live map, Samus on her grid, every upgrade, sector progress, bosses, security hatches and your next objective. Game art is drawn from the US ROM; other regions show a text-only waiting screen. Needs **GBADuo v0.1.8**. See [NOTES](metroid-fusion-companion/NOTES.md). |

### Zelda

| Pack | Game | Game codes | Pages | Version | Notes |
|---|---|---|---|---|---|
| [`zelda-minish-cap-companion`](zelda-the-minish-cap-companion) | The Minish Cap | `BZME` `BZMP` `BZMJ` | Map, Items, Kinstone, Quest | 3.0.1 | *Minish-OS*: wood and leather panels with stone item sockets. The world map, item icons, Link and the title logo are drawn from your ROM. Tap Ezlo for a hint. See [NOTES](zelda-the-minish-cap-companion/NOTES.md). |
| [`zelda-oracle-of-ages-companion`](zelda-oracle-of-ages-companion) | Oracle of Ages | `CGB-AZ8E` `CGB-AZ8P` `CGB-AZ8J` | Items, Map, Seeds, Rings, Status | 0.1.0 | Early version in the game's own subscreen style. Era maps that dim unvisited rooms, seeds, all 64 rings, hearts and essences. Needs **GBADuo v0.1.8**. See [NOTES](zelda-oracle-of-ages-companion/NOTES.md). |

### Other games

| Pack | Game | Game codes | Pages | Version | Notes |
|---|---|---|---|---|---|
| [`harvest-moon-fomt-companion`](harvest-moon-fomt-companion) | Harvest Moon: Friends of Mineral Town | `A4NP` `BHFE` | Farm, Bag, Love, Sprites | 1.1.0 | *The Mineral Town Almanac*: a storybook farm whose backdrop follows the season and turns to a starry sky at night. Checked on the EU cart. See [NOTES](harvest-moon-fomt-companion/NOTES.md). |
| [`golden-sun-companion`](golden-sun-companion) | Golden Sun | `AGSE` `AGSP` `AGSJ` `AGSI` | Party, Djinn, Psynergy | 0.1.0 | Early preview in the game's blue window style. Item names, Djinn ownership and Psynergy aren't mapped yet. |

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
- [`skill/`](skill) - how the packs are built and styled, and where their sprites come from
  (shipped PNGs, the player's ROM at runtime, or art drawn in code), plus the forest art kit
  and a preview renderer, packaged as a Claude Code skill (`skill/SKILL.md`).

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
`art/` holds the scripts that build a pack's images (and their sources); it stays out
of the zip, along with `screenshoots/`, `NOTES.md` and `preview-data.json`.

```sh
cd my-pack && zip -rX ../my-pack-1.0.0.zip . -x '*.DS_Store' 'art/*' 'screenshoots/*' 'preview/*' NOTES.md preview-data.json
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
- Metroid Fusion: [Data Crystal's RAM map](https://datacrystal.tcrf.net/wiki/Metroid_Fusion/RAM_map)
  and the [metroidret](https://github.com/metroidret/mf) mf decompilation.
- Metroid: Zero Mission: [Data Crystal's RAM map](https://datacrystal.tcrf.net/wiki/Metroid_Zero_Mission:RAM_map)
  and the [metroidret](https://github.com/metroidret/mzm) mzm decompilation (RAM layout, event flags and the
  ROM offsets of the title logo and map tiles).
- Oracle of Ages: the [oracles-disasm](https://github.com/Stewmath/oracles-disasm) disassembly
  (memory map, rooms, tilesets and item sprites). The 64 ring icons are cut from a community
  sprite sheet of the game's rings.
- Fonts: [Jersey 10](https://fonts.google.com/specimen/Jersey+10),
  [Press Start 2P](https://fonts.google.com/specimen/Press+Start+2P),
  [Silkscreen](https://fonts.google.com/specimen/Silkscreen),
  [Bungee](https://fonts.google.com/specimen/Bungee),
  [Barlow Semi Condensed](https://fonts.google.com/specimen/Barlow+Semi+Condensed),
  [Sniglet](https://fonts.google.com/specimen/Sniglet), [Mali](https://fonts.google.com/specimen/Mali),
  [Uncial Antiqua](https://fonts.google.com/specimen/Uncial+Antiqua),
  [Cinzel Decorative](https://fonts.google.com/specimen/Cinzel+Decorative),
  [Alegreya Sans](https://fonts.google.com/specimen/Alegreya+Sans),
  [Audiowide](https://fonts.google.com/specimen/Audiowide) and
  [Chakra Petch](https://fonts.google.com/specimen/Chakra+Petch), under the SIL Open Font License 1.1.
- The Minish Cap pack's font: "TLOZ Minish Cap/A Link to the Past/Four Sword" by
  David Fens ([FontStruct](https://fontstruct.com/fontstructions/show/875429)), under the
  FontStruct Non-Commercial License.
- Art: the packs' interfaces are original, drawn in code by each pack's `art/` scripts.
  The FireRed pack's Pokémon, item, type and badge sprites come from the
  [PokeAPI sprites](https://github.com/PokeAPI/sprites) repository; they belong to
  Nintendo, Game Freak and Creatures. Its Town Map, and all of the Minish Cap pack's game
  graphics, are read from the player's own ROM at runtime and not included. The Metroid
  Fusion pack draws its Samus, map and logo from your ROM and ships no game graphics. The Zero
  Mission pack draws its logo and map from your ROM too, but ships two small images of Samus's
  suit cut from the game's status screen (`art/samus.py`). The Oracle of Ages pack ships its item,
  seed, ring and map graphics, which come from the game's own data.

</details>

## Disclaimer

These packs are fan-made, not affiliated with or endorsed by Nintendo, Game Freak,
Creatures, The Pokémon Company or Marvelous. Pokémon, Harvest Moon, The Legend of Zelda, Metroid and all related
names are trademarks of their respective owners. No games are included: use your own
legally dumped ROMs. The FireRed pack includes Pokémon, item, type and badge sprites for
a non-commercial fan project; they remain the property of Nintendo, Game Freak and
Creatures and will be removed on request. The Oracle of Ages pack likewise includes the
game's item, seed, ring and map graphics for a non-commercial fan project; they remain the
property of Nintendo and will be removed on request. The Zero Mission pack likewise includes two small images of Samus's suit from the game's status
screen; they remain the property of Nintendo and will be removed on request. The Minish Cap and
Metroid Fusion packs include none of the game's graphics: they draw them from your ROM.
