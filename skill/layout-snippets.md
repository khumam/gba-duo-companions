# Layout snippets (layout.json)

General patterns. The `asset:img/...` names come from the forest art kit; for a pixel pack use
your own `asset:ui/...` or a Lua-returned `"$src"` (see `sprites-and-assets.md`).
Pages + nav (the shape all packs use) is first below.

Classes come from `theme-forest.css`; images from `art-kit-forest.mjs`. Full example:
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

## Pages with a persistent nav (Pokémon dock, Zelda command dock, Golden Sun bar)

```json
{ "type": "box", "class": "main", "visibleIf": "$ready", "children": [
  { "type": "pages", "class": "stage", "state": "page", "initial": "party", "pages": [
    { "name": "party", "child": { "type": "box", "class": "page", "children": [ ] } },
    { "name": "bag",   "child": { "type": "box", "class": "page", "children": [ ] } }
  ]},
  { "type": "box", "class": "nav", "children": [
    { "type": "button", "class": "nav-btn", "classIf": { "on": "$navParty" },
      "onClick": [ { "navigate": "party" } ],
      "children": [ { "type": "text", "class": "nav-text", "text": "Party" } ] }
  ]}
]}
```

Lua returns `navParty = page == "party"` etc. (`ui.page` is the open page). If the nav repeats on
every page (Pokémon), generate the JSON from a script (`art/layout.mjs`) instead of pasting it.

## Selectable list + detail (roster, party, items)

```json
{ "type": "list", "class": "roster", "items": "$members", "template": {
  "type": "box", "class": "rcard", "classIf": { "on": "$active", "down": "$down" },
  "bindStyle": { "--c": "{color}" },
  "onClick": [ { "set": { "member": "{@index}", "item": 0 } } ],
  "children": [ { "type": "text", "class": "rcard-name", "text": "{name}" },
                { "type": "bar", "class": "hp mini", "classIf": { "low": "$low" }, "value": "$hpPct", "max": 1 } ] } }
```

## Sprite in a slot (Pokémon) and ROM-drawn icon (Zelda)

```json
{ "type": "box", "class": "sprite-slot sprite-s", "children": [
  { "type": "image", "class": "sprite", "src": "$sprite" } ] }

{ "type": "list", "class": "heart-row", "items": "$hearts",
  "template": { "type": "image", "class": "heart", "src": "$src" } }
```

`$sprite` / `$src` are `asset:...` or `gfx:...` keys returned by Lua.

## Overlay marker on a map image

```json
{ "type": "box", "class": "map-view", "children": [
  { "type": "image", "class": "map-img", "src": "$map.image" },
  { "type": "image", "class": "mark mark-link", "src": "$icons.linkHead",
    "bindStyle": { "left": "{map.linkX}%", "top": "{map.linkY}%" } } ] }
```

`.map-view { position: relative }`, `.mark { position: absolute }` (Zelda pack; `linkX/linkY` are 0-100 from Lua).
