# Layout snippets (layout.json)

Classes come from `theme.css`; images from `art-kit.mjs`. Full example:
`zelda-minish-cap-companion/layout.json`.

## Screen skeleton: waiting screen + tabs

```json
{ "type": "box", "id": "screen", "children": [
  { "type": "box", "class": "waiting", "visibleIf": "$waiting", "children": [
    { "type": "image", "class": "emblem", "src": "asset:img/emblem.png" },
    { "type": "text", "class": "waiting-title", "text": "Game Title" },
    { "type": "image", "class": "waiting-garland", "src": "asset:img/garland.png" },
    { "type": "text", "class": "waiting-sub", "text": "Load a file to begin your adventure" }
  ]},
  { "type": "tabs", "visibleIf": "$ready", "tabs": [
    { "title": "Hero", "child": { "type": "box", "class": "tab-page", "children": [ ] } }
  ]}
]}
```

Max 4 tabs, short titles (≤ 9 letters at 10px Cinzel on an 84px leaf).

## Hero plaque with corner sprigs (first thing on every tab)

```json
{ "type": "box", "class": "plaque hero", "children": [
  { "type": "image", "class": "sprig sprig-l", "src": "asset:img/sprig-left.png" },
  { "type": "image", "class": "sprig sprig-r", "src": "asset:img/sprig-right.png" },
  { "type": "box", "class": "hero-foot", "children": [
    { "type": "text", "class": "hero-title", "text": "Elements" },
    { "type": "text", "class": "foot-text", "text": "{count} of 4" }
  ]}
]}
```

## Vine section title

```json
{ "type": "box", "class": "vine-title", "children": [
  { "type": "image", "class": "vine", "src": "asset:img/vine-left.png" },
  { "type": "text", "class": "vine-text", "text": "Treasury" },
  { "type": "image", "class": "vine", "src": "asset:img/vine-right.png" }
]}
```

## Stat plaque: icon, label, number, gauge

```json
{ "type": "box", "class": "plaque", "children": [
  { "type": "box", "class": "stat-head", "children": [
    { "type": "image", "class": "icon", "src": "asset:img/rupee.png" },
    { "type": "box", "class": "stat-col", "children": [
      { "type": "text", "class": "label", "text": "Rupees" },
      { "type": "text", "class": "num", "text": "{rupees}" }
    ]}
  ]},
  { "type": "bar", "value": "$rupeePct", "max": 1, "class": "gauge gold-gauge" },
  { "type": "text", "class": "fine", "text": "Wallet holds {walletMax}" }
]}
```

## Icon row driven by the script (hearts, sockets, colour variants)

Lua returns `{ src = "asset:img/heart-3.png" }` per entry.

```json
{ "type": "list", "class": "heart-row", "items": "$heartRow",
  "template": { "type": "image", "class": "heart", "src": "$src" } }
```

## Letter on a badge (display: stack)

```json
{ "type": "box", "class": "acorn", "children": [
  { "type": "image", "class": "acorn-img", "src": "asset:img/acorn.png" },
  { "type": "text", "class": "acorn-letter", "text": "A" }
]}
```

## Owned / locked

`.seal` and `.sprig` are `position: absolute` — keep them inside a `.plaque`
(the positioned parent), or they pin to the wrong box.

```json
{ "type": "text", "class": "leaf-chip locked", "classIf": { "owned": "$owned" }, "text": "{name}" }
{ "type": "image", "class": "icon dim", "classIf": { "owned": "$map" }, "src": "asset:img/map.png" }
{ "type": "image", "class": "seal", "visibleIf": "$cleared", "src": "asset:img/seal.png" }
```
