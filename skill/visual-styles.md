# Visual styles: how the three packs look and how to build them

Screenshots live in each pack's `screenshoots/`. All three share one idea: **copy the
game's own UI chrome**, then add only what a second screen needs (a persistent nav, big
numbers, state colours).

## Style anatomy (what every pack defines)

| Layer | What to decide | Where |
|---|---|---|
| Tokens | 8–25 `:root` variables sampled from the game | top of `style.css` |
| Canvas | `#screen` background (flat, texture or stripes), padding 0–8 px, optional bezel | `#screen` |
| Frame | border width/colour, radius, shadow (hard offset, never blur) | `.panel`, `.card`, `.hero` |
| Title tab | where the panel title sits (tab on the border, plaque, underline) | `.panel-title`, `.plaque` |
| Row | list row with 1px top/bottom lines, selection highlight | `.item-row`, `.stat-row` |
| Gauge | `bar` height, track colour, per-state fill via `accent-color` or `bar.x > fill` | `bar`, `.hp` |
| Nav | where, how selected looks, pressed state | `.dock-btn`, `.nav-btn`, `.tab` |
| Type | label face, number face, sizes, shadow | `@font-face`, `.num` |
| Imagery | which assets, which scale | see `sprites-and-assets.md` |

## Pokémon FireRed minimal — "the game's Bag window"

Palette (sampled from the Bag screen): striped teal ground `#64B2A5`, cream panels
`#FFFFD3`, tan frame `#F0CF80`, grey outline `#6B6B6B`, orange accent `#D28F56`, blue
footer/dock `#3579C0` (hi `#4FAAD9`, lo `#215170`). Bars: `--ok-bar #99FCB4`, `--warn-bar
#F8E070`, `--bad-bar #F8A090`.

- **Canvas:** `background-image: url(assets/ui/ground.png)` tiled at `5.2px` ⇒ the
  game's scanline stripes; padding 6.
- **Frame:** 2px grey outline, radius 3, tan fill; panel title as white pixel text on a
  tan tab with a 4px orange underline (`.panel-tab`).
- **Nav:** a right column, 96 px, six blue buttons with 2px dark border and lighter top
  edge; the open page turns tan with a grey border (`.dock-btn.on`). Variants: the
  non-minimal packs have hazard stripes, hard 4px shadows, a colour per tab, and either
  a bottom row (`pokemon-firered-companion`) or column (`-v-`).
- **Type:** Jersey 10 at 22 px body, 18 px numbers (the game's 8×8 pixel font at ~1.3×),
  text-shadow `1px 1px 0`. Declared as two family names on one file.
- **Imagery:** strategy A (PokeAPI sprites) + C1 (UI glyphs, radar map). Type labels as
  PNG pills, HP bars with three colour states (`hpHigh/Mid/Low` booleans from Lua).
- **Layout:** header bar (location pill left, clock+coins right) + page + dock column.
  Panels in `display: grid` (`.trainer-cols { grid-template-columns: 1fr 1fr }`),
  party as a `list` of cards, detail page opened by tap.

## Zelda: Minish Cap — "Minish-OS", crafted materials

Palette: forest `#1F4A34`, charcoal bezel `#2A2D31`, leather `#78350F`, wood `#3A2312`
(edge `#2B1408`), parchment `#FEF3C7`, copper/brass/gold `#EAB308`, steel `#A3AAB3`,
ink `#18181B`; accents `--link-green #22C55E`, `--ezlo-teal #06B6D4`, kinstone red/blue/green.

- **Canvas:** `#screen` = green canopy texture, 4px charcoal bezel, 14px radius.
- **Header:** stitched leather strip (`leather.png` 16px tile + dashed inner border
  `2px dashed #D9A066`) holding resource counters (pack-drawn rupee/kinstone icons) and
  an orange Ezlo button with the ROM's Ezlo sprite.
- **Panels:** wood-grain interior (`wood.png`), 3px dark wood border, **plaque** title
  centred on the top edge (`.plaque-row { position:absolute; top:0 }`) with leaf sprites
  pinned to its ends; copper rivet images in corners and edges (`.rivet-*`, absolute).
- **Cards:** parchment texture with a brown border for content; tan `.slot` squares for
  item icons (`:pressed` nudges by 1px, count badge absolute bottom-right).
- **Equip rings:** `gem-a/b.png` as `background-image` behind a ROM icon, letter badge
  A/B as a red/blue circle (`display:stack` + absolute).
- **Nav:** wooden "command dock" at the bottom with steel frames and rivets; the open tab
  is gold (`linear-gradient(#FDE68A,#EAB308,#A16207)` + `box-shadow: 0 0 8px #FDE047`).
- **Type:** Jersey 10 for labels, Press Start 2P for numbers (`.num` 12/14), hard
  `2px 2px 0` shadows; 7.5 px counts, 16–23 px labels.
- **Imagery:** the richest mix: B for all game icons + map + Link + hearts + Ezlo + logo,
  C1 for materials. **188 `image` widgets** (vs 28 in Pokémon, 0 in Golden Sun).
- **Behaviour in layout:** WORLD / DUNGEON tabs with `classIf`, Ezlo hint bubble
  (`position:absolute; top:62px; right:0; z-index:10`) toggled by `visibleIf`.

## Golden Sun — "the save-list window", pure CSS

Palette sampled from the Continue screen: black ground, white window frame, steel-blue
body shaded `#1D4951 → #296188 → #3A82B8` (top to bottom), pink selection `#AD86A3 →
#DC9FBC`, blue title tab `#0000F4` with cyan highlight `#5FE0F0`, text white on black
shadow, muted `#A9D2EE`, gold `#F8D060`, HP `#A5E36B`, PP `#6FC3FF`. Element colours:
Venus `#C98B3C`, Mercury `#4AA3E0`, Mars `#E5584B`, Jupiter `#B58CE0`.

- **Window:** one gradient + `3px solid #fff` + radius 3 + `box-shadow: 0 2px 0 #525252`;
  reused for `.panel .hero .boot .nav`.
- **Title tab:** small caps in Silkscreen on a blue gradient chip with 2px white border,
  pulled onto the panel's top border with `margin: -10px 0 4px 6px`.
- **Rows:** 1px light line under 1px dark line (`border-top #3A82B8`, `border-bottom
  #1D4951`) reproduces the game's etched list; selected row = pink gradient.
- **Gauges:** `bar` 8px high, black 1px border, per-state fill (`bar.hp > fill`,
  `bar.hp.low > fill`) with `classIf`.
- **Roster:** cards down the left, selected = white border + pink gradient, KO'd =
  `opacity .55`. Tap sets `ui.member`.
- **Nav:** one bar at the bottom with three equal buttons; open = pink gradient.
- **Imagery:** none. Portrait = framed square + initial letter coloured by element
  (`bindStyle {"--c": "{color}"}`); items = coloured squares. Cheapest option; upgrade
  path is strategy B.

## Reusable style recipes

**Hard shadow depth (no blur):** `box-shadow: 0 2px 0 #525252;` / `2px 2px 0 #18181B`;
`:pressed` removes it and translates `2px 2px` to look like a physical key.

**Etched list rows:** `border-top: 1px solid <light>; border-bottom: 1px solid <dark>;`

**Selection highlight:** gradient in the game's selection colour on `.on`, text white;
not selected = muted colour. Drive with `classIf: {on: "$active"}`.

**State classes:** `.low` (red fill), `.down` (opacity .55), `.locked`/`.missing` (opacity
.25–.45), `.owned` (gold border). Lua provides the booleans.

**Gauge states:** `bar.hp > fill { background: green } bar.hp.low > fill { background: red }`
or `accent-color` on the bar with transition `width 400ms ease-out`.

**Title chips / pills:** `padding 0 10px; border-bottom: 4px solid <accent>` (Pokémon),
blue gradient chip on the border (Golden Sun), plaque with leaf ends (Zelda).

**Panel grids:** `display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px` for
bento/stat cards; `flex: 1; min-height: 0` on scrolling regions.

**Per-item colour:** `"bindStyle": {"--c": "{color}"}` + `background: var(--c)`.

**Pixel font:** body 22–26 px for Jersey 10, 10–13 px for Silkscreen/Press Start 2P,
`white-space: nowrap`, `text-shadow: 1px 1px 0 #000` for contrast on blue/green.

## Choosing a style for a new game

1. If the game has a clear menu skin (most GBA RPGs): follow Golden Sun/Pokémon: sample
   colours, rebuild one window in CSS, start with strategy C3, add A/B for sprites.
2. If the game's identity is a *material* (wood, metal, parchment, tech HUD): follow
   Zelda: draw 4–6 tileable textures with C1, build panels on top, ROM-draw game icons.
3. If the game is ornate/fantasy with no pixel UI: the forest system
   (`theme-forest.css`, `art-kit-forest.mjs`) re-themed per game (FireRed's first
   skin swapped leaves for flames).
4. Keep nav styling consistent with the game's selection style, and make the open page
   obvious at a glance (colour inversion beats an underline).

## The forest system (kept for reference)

Dark lit forest at Minish scale: moss-glass plaques with gold rims (`rgba(9,34,24,.82)`,
14px radius, 1px gold), parchment hero plaque with leaf-cut corners
(`border-radius: 22px 6px 22px 6px`), leaf sprigs pinned to corners, gold vine titles,
Uncial Antiqua / Cinzel Decorative / Alegreya Sans, palette night `#06180F`, gold
`#E8BE55` / hi `#FFE9A3` / deep `#9C6F1C`, text `#F3EBD3`. Its images are smooth SVG
renders (`image-rendering: auto`), unlike the pixel packs above. Static TTFs only
(weight axis of variable fonts isn't honoured). Snippets: `layout-snippets.md`.
