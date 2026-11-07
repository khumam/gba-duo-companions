---
title: Layout and widgets
description: The widgets in layout.json and how they bind to the values your script returns.
---

`layout.json` is a single widget, usually a `column` or `box`, with more widgets
nested inside. Each widget has a `type` and the fields listed below. Structure goes
here, the look goes in [CSS](/docs/styling), and the data comes from your
[Lua script](/docs/lua).

## Binding to data

Every tick, the table your `update()` returns becomes the **snapshot**. Widgets read
from it in two ways:

- **`$path`**: a value, in fields like `items`, `value`, `visibleIf` and `src`.
  `"items": "$party"`
- **`{path}`**: text, filled into a string. `"text": "{name} Lv{level}"`

Paths can reach into nested tables and arrays: `trainer.name`, `party[0].hp`.
A missing value is empty text (or false). Whole numbers print without a decimal point.

Inside a `list` template, a path looks in the current item first, then the whole
snapshot. `{@index}` is the item's position, counting from 0.

Two keys are always there: `_frameCounter` (frames emulated so far) and, if
`update()` failed, `_scriptError` with the error message.

### What counts as true

`visibleIf` and `classIf` treat a value as **false** if it is missing, `false`, `0`,
an empty string, or an empty list or table. Everything else is true.

```json
{ "type": "text", "text": "Low HP!", "visibleIf": "$lowHp" }
```

## Fields every widget takes

| Field | Purpose | Example |
| --- | --- | --- |
| `visibleIf` | Show only while a value is true | `"visibleIf": "$inBattle"` |
| `id` | `#id` selector | `"id": "hp-panel"` |
| `class` | `.class` selectors, space-separated | `"class": "card party"` |
| `style` | Inline CSS (object or string); beats stylesheet rules | `"style": "padding: 8px"` |
| `classIf` | Adds a class while a value is true | `"classIf": { "low": "$hpLow" }` |
| `bindStyle` | CSS values from data, re-applied each tick | `"bindStyle": { "--type": "{typeColor}" }` |
| `onClick` | What a tap does | `"onClick": { "navigate": "detail" }` (see [Taps and pages](/docs/pages)) |

## Containers

### `column` and `row`

Lay out `children` vertically or horizontally (flexbox).

```json
{ "type": "row", "class": "stats", "children": [
  { "type": "text", "text": "ATK {attack}" },
  { "type": "text", "text": "DEF {defense}" }
] }
```

### `box`

A styled container. Use `children` (a flex column by default) or the older
`child` form, which frames a single widget and layers it like a stack. A `box` can
also be empty, for shapes drawn purely with CSS.

```json
{ "type": "box", "class": "card", "children": [ ... ] }
```

### `list`

Repeats `template` once for each entry of an array in the snapshot.

| Field | |
| --- | --- |
| `items` | `$path` to an array |
| `template` | The widget drawn for each item |
| `empty` | Text shown when the array is empty |

```json
{ "type": "list", "class": "party", "items": "$party", "empty": "No Pokémon yet",
  "template": { "type": "row", "class": "mon", "children": [
    { "type": "image", "src": "$icon" },
    { "type": "text", "text": "{name}" },
    { "type": "bar", "value": "$hp", "maxKey": "$maxHp" }
  ] } }
```

### `tabs`

A tab strip with one page per tab. Players tap a tab to switch.

```json
{ "type": "tabs", "tabs": [
  { "title": "Party", "child": { ... } },
  { "title": "Bag", "child": { ... } }
] }
```

Style it with `tabs > tab-bar > tab`, `tab:active` for the selected tab, and
`tabs > tab-content`.

### `pages`

Shows one of several screens at a time, switched by taps or by your script. Pages are
covered in [Taps and pages](/docs/pages).

## Content

### `text`

```json
{ "type": "text", "class": "name", "text": "{name} Lv{level}" }
```

`text` supports `{path}` placeholders. Style it with CSS. The older `size`, `color`,
`bold` and `font` fields still work; `font` names a font file in the pack's
`assets/` folder.

### `bar`

A progress bar, such as HP or experience.

| Field | |
| --- | --- |
| `value` | `$path` to the current value |
| `maxKey` | `$path` to the maximum, or |
| `max` | a fixed maximum (default `1`) |
| `label` | Text drawn over the bar, with `{path}` placeholders |

```json
{ "type": "bar", "value": "$hp", "maxKey": "$maxHp", "label": "{hp}/{maxHp}" }
```

Style the parts with `bar > fill` (its width follows value/max) and `bar > label`.

### `image`

| `src` | Loads |
| --- | --- |
| `"asset:img/heart.png"` | A file in the pack's `assets/` folder |
| `"$icon"` | Whatever key the snapshot holds: an `asset:` path, or a `gfx:` key from [`gfx.decode`](/docs/lua#gfxdecode) |

Images are drawn with `image-rendering: pixelated` by default, so pixel art stays sharp.

### `button`

A tappable box with a label, styled and with pressed feedback out of the box.

```json
{ "type": "button", "text": "‹ Back", "onClick": "back" }
```

### `spacer`

Empty space. `size` sets it in px (default 8).

## A full example

From GBA Duo's examples, a classic layout without CSS:

```json
{
  "type": "column", "gap": 8,
  "children": [
    { "type": "text", "text": "{trainer}", "size": 18, "bold": true, "color": "#FFCB05" },
    { "type": "row", "gap": 6, "children": [
      { "type": "text", "text": "Money:" },
      { "type": "text", "text": "{money}", "color": "#8BC34A" }
    ]},
    { "type": "box", "padding": 8, "background": "#1C2133", "cornerRadius": 8,
      "borderColor": "#3B4CCA", "borderWidth": 2,
      "child": { "type": "list", "items": "$party", "template":
        { "type": "column", "gap": 2, "children": [
          { "type": "text", "text": "{name} Lv{level}" },
          { "type": "bar", "value": "$hp", "maxKey": "$maxHp", "height": 6 },
          { "type": "spacer", "size": 4 }
        ]}
      }
    },
    { "type": "text", "text": "Badges: {badges}", "visibleIf": "$badges" }
  ]
}
```

And the data it expects:

```json
{
  "trainer": "Red",
  "money": 3175,
  "badges": 2,
  "party": [
    { "name": "Charmeleon", "level": 22, "hp": 61, "maxHp": 68 },
    { "name": "Pidgeotto", "level": 19, "hp": 12, "maxHp": 55 }
  ]
}
```
