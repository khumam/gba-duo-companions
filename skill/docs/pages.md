---
title: Taps and pages
description: Make the companion tappable, with detail pages, buttons, and pages the game opens by itself.
---

Any widget on the companion screen can react to a tap with `onClick`. A `pages` widget
shows one screen at a time, so a tap can open a detail page and a button can go back.
Your Lua script sees which page is open and what was tapped, so each page gets the data
it needs.

Taps never take the controller away from the game.

## A party list that opens a detail page

```json
{ "type": "pages", "pages": [
  { "name": "party", "child":
    { "type": "list", "items": "$party", "template":
      { "type": "row", "class": "mon",
        "onClick": [ { "set": { "selected": "{@index}" } }, { "navigate": "detail" } ],
        "children": [ { "type": "text", "text": "{name}" } ] } } },
  { "name": "detail", "child":
    { "type": "column", "children": [
      { "type": "button", "text": "‹ Back", "onClick": "back" },
      { "type": "text", "text": "{detail.name}" },
      { "type": "list", "class": "chips", "items": "$detail.weak", "template":
        { "type": "text", "class": "chip", "text": "{name} {label}" } }
    ] } }
] }
```

Tapping a row saves its position as `selected` and opens the `detail` page.
"‹ Back" returns to the party list. The script fills in `detail`, as shown in
[Feeding a page from Lua](#feeding-a-page-from-lua).

GBA Duo's [`party-css` example](https://github.com/khumam/gba-duo/tree/main/docs-packs/examples/party-css)
has a complete version: tap a party member for its stats, weaknesses and resistances.

## UI state

The screen keeps a small set of values called the **UI state**:

- which page each `pages` widget shows (`page` by default);
- anything a tap `set`s.

Layouts read it as `$ui.<key>` (for example `"{ui.selected}"` or
`"visibleIf": "$ui.showAll"`). The script reads it as `ui.<key>`. It starts empty,
apart from each `pages` widget's initial page, whenever a pack is loaded. Values are
strings, numbers or booleans.

## `onClick`

Every widget accepts `onClick`: one action, a list of actions, or `"back"`.

| Action | Does |
| --- | --- |
| `{ "set": { "selected": "{@index}" } }` | Sets UI keys. A value that is exactly one `{...}` keeps its type (`{@index}` stays a number); other strings are filled in as text. |
| `{ "navigate": "detail" }` | Shows that page and remembers the current one for `back`. |
| `{ "back": true }`, or `"back"` | Returns to the previous page (the initial page if there's no history). |
| `{ "call": "heal", "args": ["{@index}", "{name}"] }` | Runs `actions.heal(index, name)` in the pack's Lua ([below](#script-actions)). |

`{...}` placeholders resolve like everywhere else in a layout: in a list item, the
item's fields, then `@index`, then the whole snapshot; anywhere, `ui.*`.

One object can combine actions. They run in the order `set`, `navigate`/`back`,
`call`. A list runs in order. UI changes from a tap show at once; a `call` runs on the
next frame.

`"state"` picks which `pages` widget `navigate` and `back` drive (`page` by default):
`{ "navigate": "moves", "state": "tab2" }`.

While a widget with `onClick` is held down it matches `:pressed`, so you can style it:

```css
.mon:pressed { transform: scale(.97); }
```

## `pages`

```json
{ "type": "pages", "state": "page", "initial": "party", "pages": [
  { "name": "party", "child": { ... } },
  { "name": "detail", "child": { ... } }
] }
```

| Field | Default | |
| --- | --- | --- |
| `pages` | (required) | `name` + `child` for each page; names must be unique |
| `state` | `page` | The UI key holding the shown page's name |
| `initial` | the first page | Shown until something navigates; also where `back` ends |

- Only the shown page is laid out and drawn. Hidden pages stay bound to the data, so
  they're up to date when opened.
- A page name that doesn't exist shows the initial page.
- Several `pages` widgets can share a `state` or use their own.
- Selectors: `pages`, and `pages > *` for the page roots. Give pages a `class` or `id`
  to style them.

## `button`

```json
{ "type": "button", "text": "Heal all", "onClick": { "call": "healAll" } }
```

A box laid out as a centered row with default padding, a rounded background, and
`:pressed` feedback. `text` becomes a `text` child with the class `label`
(`button > .label`). `children` can add more, such as an icon. Any other widget with
`onClick` works too; `button` just comes styled.

## Feeding a page from Lua

`update()` receives the UI state, which is also the global `ui`. Use it to compute only
what the open page needs:

```lua
local typechart = pack.require("typechart")

function update(ui)
  local party = readParty()             -- your pack's own memory reading
  local out = { party = party }
  if ui.page == "detail" and ui.selected then
    local mon = party[ui.selected + 1]  -- @index counts from 0, Lua from 1
    if mon then
      local weak, resist, immune = typechart.matchups(mon.types)
      out.detail = {
        name = mon.name, level = mon.level, hp = mon.hp, maxHp = mon.maxHp,
        weak = weak, resist = resist, immune = immune,
      }
    end
  end
  return out
end
```

Where the data comes from is up to the pack:

- **Game RAM:** party stats, moves, HP.
- **ROM:** `mem.*` reads the cartridge too, for example species base stats.
- **Data files in the pack:** `.lua` modules loaded with `pack.require`, like a type
  chart, or notes from a guide whose license allows it.

A tap that changes the UI state triggers a fresh `update(ui)` right away, so a detail
page fills in almost instantly instead of waiting for the next tick. This also works
while the game is paused.

## Changing pages from `update()`

The game itself can switch pages, without a tap: return a `ui` entry from `update()`.
It holds UI actions in the same shape as an `onClick` (`set`, `navigate`, `back`; not
`call`) and runs right after the rest of the returned data is applied. For example,
open a battle page while a battle is on:

```lua
local wasInBattle = false

function update(ui)
  local inBattle = mem.u8(BATTLE_FLAG) ~= 0   -- whatever your game's flag is
  local out = { party = readParty() }
  if inBattle then out.battle = readBattle() end

  if inBattle and not wasInBattle then
    out.ui = { navigate = "battle" }          -- the battle just started
  elseif wasInBattle and not inBattle then
    out.ui = { back = true }                  -- it ended: back to the previous page
  end
  wasInBattle = inBattle
  return out
end
```

- Return `ui` only when something changes, as above, so players can still tap away
  while it lasts. Returning `{ navigate = "battle" }` every tick is harmless but sends
  them back to it each tick.
- `back` pops one page of history each time it's returned, so return it once.
- `ui` isn't passed to the layout as data: `$ui.*` is always the UI state.
- It takes effect at the next snapshot, so within one tick.

## Script actions

`{ "call": "name", "args": [...] }` runs `actions.name(...)` from the pack's script:

```lua
actions = {}

function actions.open(index)
  -- Decide in Lua which page to show.
  if index == 0 then return { navigate = "lead" } end
  return { set = { selected = index }, navigate = "detail" }
end
```

- **Arguments:** strings, numbers and booleans; anything else arrives as `nil`. At most 16.
- **Return value:** a table in the same shape as an `onClick` action (`set`,
  `navigate`, `back`), applied to the screen. Return nothing to leave the screen as it
  is. A returned `call` is ignored; call the Lua function directly.
- **Timing:** actions run on the emulator thread just before the next `update(ui)`,
  with the same [limits](/docs/lua#the-sandbox) as `update`: 1M instructions and 25 ms
  per call.
- **Errors:** an error or a missing function is logged (`adb logcat -s EmuThread`) and
  the screen stays as it was.

## Changing the game

An action can also write to the game's memory: equip an item from the companion
screen, or set a value without opening a menu. Reading needs nothing. Writing needs a
permission in the manifest, and the player's say-so.

```json
{
  "formatVersion": 3,
  "permissions": ["memory-write"]
}
```

```lua
function actions.equip(button, itemId)
  if mem.u8(SAFE_FLAG) == 1 then
    local ok, why = mem.write8(B_SLOT, itemId)
    if not ok then return { set = { message = "Couldn't equip: " .. why } } end
  end
end
```

The [write functions](/docs/lua#writing-memory) return `true`, or `false` and a reason,
so the pack can say why on the companion screen. Nothing is written when they return
`false`.

The checks live in the app, not in the pack's Lua, so a pack can't skip them:

- **Permission.** Without `"permissions": ["memory-write"]` (`formatVersion` 3) every
  write is refused. An unknown permission makes the manifest invalid.
- **Only from a tap.** Writes work only while an `onClick` action runs. `update()`,
  `init()` and the script's top level can't write, so a pack can't change the game on
  its own. A function saved during one tap can't write later.
- **Only RAM.** GBA EWRAM `0x02000000`-`0x0203FFFF` and IWRAM `0x03000000`-`0x03007FFF`;
  GB/GBC work RAM `0xC000`-`0xDFFF` and high RAM `0xFF80`-`0xFFFE`. ROM, I/O registers,
  video memory, the save and mirrors of RAM are refused. A write must fit inside one
  region.
- **Size.** At most 64 bytes per call and 256 bytes per tap.
- **The player.** Writing is off until the player turns on
  [Settings › Packs can change games](/docs/settings#packs-can-change-games). The first
  time a pack is about to change a game, GBA Duo asks; the answer is kept for that pack
  and game, and asked again if the pack's code changes. If they allow it, a save state is
  made just before.
- **Timing.** Writes happen on the emulator thread between frames, so they never race
  the emulator. The game sees them on its next frame.
- **Logged.** Every write is logged with its address and size: `adb logcat -s Companion`.

Writes don't roll back: if an action writes and then errors, what it wrote stays.
**Write last, after every check.**

Find real addresses before you write anything, and check a "safe to act" condition
first: a wrong write can crash the game or spoil the save. The app repo has a complete
example,
[`zelda-items`](https://github.com/khumam/gba-duo/tree/main/docs-packs/examples/zelda-items),
with notes on finding addresses.
