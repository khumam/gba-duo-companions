---
title: Styling with CSS
description: Style the companion with real CSS, including selectors, properties and how they differ from a browser.
---

The companion screen is drawn natively, but styled with real CSS syntax:
**structure in `layout.json`, look in `style.css`, logic in Lua.** Anything a pack
doesn't style keeps the built-in look.

## Setup

List your stylesheets in `manifest.json`. This needs `formatVersion: 2`. They're
applied in order, after GBA Duo's built-in styles.

```json
{
  "formatVersion": 2,
  "layout": "layout.json",
  "styles": ["style.css"],
  "script": "main.lua"
}
```

`url(...)` in a stylesheet resolves relative to that stylesheet. In a widget's inline
`style` it resolves relative to the pack folder. Paths can't leave the pack: `../`
outside it, absolute paths and `http://` are ignored.

## Hooking widgets to CSS

Give widgets an `id` or `class` in the layout, then select them. `classIf` and
`bindStyle` let the data drive the style:

```json
{
  "type": "list", "class": "party", "items": "$party",
  "template": {
    "type": "box", "class": "mon", "classIf": { "fainted": "$fainted" },
    "bindStyle": { "--type": "{typeColor}" },
    "children": [
      { "type": "image", "class": "sprite", "src": "$sprite" },
      { "type": "text", "class": "name", "text": "{name}" },
      { "type": "bar", "value": "$hp", "maxKey": "$maxHp", "label": "{hp}/{maxHp}" }
    ]
  }
}
```

```css
:root        { --accent: #e63946; --panel: #1d1f2b; background: #0b0c10; }
@font-face   { font-family: "Pixel"; src: url("fonts/Pixel.ttf"); }

.party       { display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px; padding: 12px; }
.mon         { gap: 4px; padding: 8px; align-items: center;
               background: var(--panel); border: 1px solid var(--type, #2e3245);
               border-radius: 10px; box-shadow: 0 2px 6px rgba(0, 0, 0, .5); }
.mon.fainted { opacity: .4; }
.mon:nth-child(odd) { background: #22263a; }
.sprite      { width: 64px; height: 64px; }
.name        { font-family: "Pixel"; text-transform: uppercase; }
bar          { width: 100%; height: 6px; border-radius: 3px; overflow: hidden; background: #333; }
bar > fill   { background: linear-gradient(90deg, var(--accent), #ffb703); transition: width 300ms ease-out; }
bar > label  { font-size: 9px; }
```

## Element names

Widget types work as element selectors, along with the parts GBA Duo generates:

| Element | What it is |
| --- | --- |
| `column`, `row`, `box`, `list`, `tabs`, `pages`, `button`, `text`, `bar`, `image`, `spacer` | Widgets |
| `bar > fill`, `bar > label` | A bar's fill (width = value/max) and its label |
| `tabs > tab-bar > tab` | The tab strip and each tab; the selected one matches `tab:active` |
| `tabs > tab-content` | The area showing the selected tab |
| `list > empty` | A list's `empty` text |
| `button > text.label` | A button's `text` |

Each part also has a class of the same name, so `.fill` and `.tab` work too.

## Selectors

| Supported | Notes |
| --- | --- |
| `type`, `*`, `.class`, `#id`, compounds (`.mon.fainted`) | |
| Descendant `A B` and child `A > B` | |
| `:root`, `:empty`, `:first-child`, `:last-child`, `:nth-child()`, `:nth-last-child()` | `odd`, `even`, `3`, `2n+1`, `-n+3` |
| `:pressed`, `:active`, `:disabled` | `:pressed` = held down; `:active` = the selected tab |

The cascade, from weakest to strongest: built-in styles, then pack stylesheets (by
specificity, then source order), then inline `style`, then `bindStyle`. `!important`
is ignored.

Not supported: sibling combinators (`+`, `~`), attribute selectors, pseudo-elements,
`@import`, `@supports` and `@container`. Those rules are skipped with a warning.
`@media` works: see [Fitting any screen](#fitting-any-screen).

## Properties

Units: `px` (Android dp; unitless numbers are px), `%`, `em`, `rem`, `vw`, `vh`,
`vmin`, `vmax`, and `calc()`, `min()`, `max()`, `clamp()`. Colors: `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`, `rgb()`/`rgba()`,
`hsl()`/`hsla()`, named colors, `transparent` and `currentcolor`. Custom properties
(`--x`) and `var(--x, fallback)` work anywhere.

| Group | Properties |
| --- | --- |
| Layout mode | `display: flex \| grid \| stack \| block \| none` |
| Flexbox | `flex-direction`, `flex-wrap`, `flex-flow`, `justify-content`, `align-items`, `align-self`, `align-content`, `flex`, `flex-grow`, `flex-shrink`, `flex-basis`, `order`, `gap`, `row-gap`, `column-gap` |
| Grid | `grid-template-columns`, `grid-template-rows` (`px`, `%`, `fr`, `auto`, `repeat(n, …)`, `repeat(auto-fill \| auto-fit, …)`, `minmax(min, max)`), `grid-column`, `grid-row` (`span n`, `n`, `n / m`, `n / span m`), `justify-items`, `justify-self`, `place-items`, `place-self` |
| Positioning | `position: static \| relative \| absolute`, `top`, `right`, `bottom`, `left`, `inset`, `z-index` |
| Box | `width`, `height`, `min-*`, `max-*`, `aspect-ratio`, `margin` (incl. `auto`), `padding`, `box-sizing` |
| Background | `background`, `background-color`, `background-image` (`url()`, `linear-gradient()`), `background-size`, `background-position`, `background-repeat` |
| Border | `border`, `border-{top,right,bottom,left}`, `border-width/style/color`, `border-radius`; styles `solid`, `dashed`, `dotted` |
| Effects | `opacity`, `box-shadow` (first shadow, no `inset`), `transform` (`translate`, `scale`, `rotate`), `transform-origin`, `overflow: hidden \| auto \| scroll`, `visibility`, `pointer-events` (`auto`, `none`) |
| Transitions | `transition` for `opacity`, `color`, `background-color`, `transform`, `width`, `height` |
| Text | `color`, `font-family` (+ `@font-face`), `font-size`, `font-weight`, `font-style`, `letter-spacing`, `line-height`, `text-align`, `text-transform`, `text-shadow`, `text-decoration`, `white-space`, `text-overflow`, `line-clamp` |
| Images | `object-fit`, `image-rendering: pixelated` (the default for `image`) |
| Bars | `accent-color` colors a bar's fill (or style `bar > fill` directly) |

A box only takes taps while it can be seen. Boxes at `visibility: hidden`, at `opacity: 0`
(or inside a box at `opacity: 0`) and at `pointer-events: none` let taps fall through to whatever
is underneath. The check uses the target value, so a box fading out stops taking taps as soon as its
class changes. `pointer-events` inherits, so a child can set `pointer-events: auto` to take taps
inside a `none` parent.

`display: stack` is specific to GBA Duo: children are layered on top of each other at
the top-left, like Android's FrameLayout. Use `place-items` to center or stretch them.

`overflow: auto` or `scroll` makes a box scroll **vertically** when its content is
taller than the box: give it a fixed or `max-height`. Horizontal scrolling isn't
supported yet.

## Fitting any screen

The companion screen isn't always the same size. The Thor's bottom screen is about
538 × 468, while a phone's second display, or the main screen when the game is on the
bottom one, can be much larger or portrait. Everything here is measured on the
**companion screen itself**, in CSS px, not the whole device.

### `@media`

```css
.party { display: grid; grid-template-columns: 1fr 1fr; }

@media (max-width: 400px) {
  .party { grid-template-columns: 1fr; }
}

@media (orientation: portrait) and (min-height: 700px) {
  .header { font-size: 22px; }
}
```

- Features: `width`, `height`, `min-`/`max-width`, `min-`/`max-height`, `orientation`
  (`portrait`, `landscape`), `aspect-ratio`, `min-`/`max-aspect-ratio`, and range
  syntax: `(width >= 400px)`, `(400px <= width < 600px)`.
- `and`, comma lists (match any), `not`, `only`, and the media types `all` and
  `screen`. `@media` blocks can nest.
- Lengths are px, or `em`/`rem` (14px each, like a browser's default).
- Rules inside a matching block join the cascade like any other rule (specificity,
  then source order), and switch on and off by themselves when the screen changes size.
- A condition with anything else (`hover`, `resolution`, `or`, `%`) skips the whole
  block with a warning.

### `calc()`, `min()`, `max()`, `clamp()`

```css
.card    { width: calc(100% - 24px); }
.title   { font-size: clamp(14px, 4vw, 22px); }
.content { padding: max(8px, 2vw); }
```

- `+` and `-` need spaces around them (`calc(100% - 24px)`), as in CSS.
- `*` and `/` take a plain number on one side (`calc(2 * 10px)`, `calc(100% / 3)`).
- `%` works in `calc()` for sizes, margins and offsets. `min()`, `max()` and `clamp()`
  can't compare `%` with px yet: `min(50%, 300px)` is dropped with a warning, while
  `min(50%, 80%)` and anything without `%` work.
- A negative result for padding, border widths, gaps, radii or font sizes becomes 0,
  as in CSS.

### Grids that pick their column count

```css
.items {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
  gap: 8px;
}
```

- `repeat(auto-fill, …)` makes as many columns as fit the container's width (at least
  one). The tracks inside need a fixed size: `120px`, or `minmax(120px, …)`.
- `repeat(auto-fit, …)` does the same but drops the columns no item uses, so a short
  list stretches across the row instead of leaving empty columns.
- `minmax(min, max)` keeps a track at least `min` wide. With `1fr` as the max it
  shares the leftover space like `1fr` does.
- One `auto-fill`/`auto-fit` per track list.

## Differences from browsers

- `font-size` is in sp, so the system text-size setting scales text.
- `box-sizing` defaults to `border-box`.
- `min-width` and `min-height: auto` mean 0 (no min-content sizing). Baseline
  alignment acts like `start`. `padding` doesn't take `%`.
- Grid uses row-major auto-placement; there's no `grid-template-areas`.
- Not supported (skipped with a warning): `@keyframes`/`animation`, `filter`,
  radial gradients, multiple backgrounds or shadows.

## Debugging

Every skipped rule, unknown property or invalid value is logged:

```sh
adb logcat -s Companion PackStyles
```
