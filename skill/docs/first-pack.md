---
title: Your first pack
description: Build a companion pack from an empty folder and run it on your device.
---

A pack is a folder. The layout says what's on screen, the stylesheet says how it
looks, and the Lua script reads the game's memory and hands the layout its values.

```txt
my-pack/
  manifest.json       id, name, version, which games it's for, update rate
  layout.json         the screen: boxes, text, images, bars, lists, tabs, pages, buttons
  style.css           real CSS: flex and grid, colors, borders, shadows, fonts, transitions
  main.lua            update() reads the game's memory and returns the values to show
  preview-data.json   sample values for the simulator (not used on the device)
  assets/             fonts and images
```

Only `manifest.json` and `layout.json` are required.

## 1. The manifest

`manifest.json` names the pack and says which games it's for.

```json
{
  "id": "my-firered-pack",
  "name": "My FireRed pack",
  "version": "1.0.0",
  "author": "you",
  "formatVersion": 2,
  "match": { "gameCode": ["BPRE"] },
  "tickHz": 4,
  "layout": "layout.json",
  "styles": ["style.css"],
  "script": "main.lua"
}
```

| Field | Default | |
| --- | --- | --- |
| `id` | (required) | Lowercase letters, digits and `-`, up to 64 characters. Unique per pack. |
| `name` | the `id` | Shown in the pack menu. |
| `version`, `author` | `0.0.0`, empty | For people; GBA Duo doesn't compare versions. |
| `formatVersion` | (required) | `1` to `4`. Use `2`; it's needed for `styles`. `3` adds `permissions`, `4` adds `gameScript`. |
| `match.gameCode` | (required) | The 4-letter codes from the ROM header, e.g. `BPRE` for FireRed (US). |
| `match.crc32` | any | Optional ROM checksums (hex strings) to narrow the match to exact dumps. |
| `tickHz` | `4` | How many times per second `update()` runs, 1 to 30. |
| `layout` | `layout.json` | The layout file. |
| `styles` | none | Stylesheets, applied in order after the built-in styles. |
| `script` | none | The Lua script. |
| `permissions` | none | Needs `formatVersion` 3. `["memory-write"]` lets taps [change the game](/docs/pages#changing-the-game). |
| `gameScript` | none | Needs `formatVersion` 4. A second script that runs against the game every frame, mostly for [Wide view](/docs/game-script). |

Finding a game code: it's the 4 bytes at `0xAC` in a GBA ROM header. Most ROM tools
and databases (No-Intro, the mGBA ROM info panel) list it.

## 2. The script

`main.lua` defines `update()`. GBA Duo calls it `tickHz` times a second, and
whatever table it returns becomes the data the layout shows.

```lua
-- Pokémon FireRed (US). Money is stored XOR'd with a key.
local SAVE_BLOCK_1 = 0x03005008   -- pointer to SaveBlock1
local SAVE_BLOCK_2 = 0x0300500C   -- pointer to SaveBlock2

local function inEwram(addr)
  return addr >= 0x02000000 and addr < 0x02040000
end

function update(ui)
  local sb1 = mem.u32(SAVE_BLOCK_1)
  local sb2 = mem.u32(SAVE_BLOCK_2)
  -- On the title screen there's no save loaded yet.
  if not (inEwram(sb1) and inEwram(sb2)) then
    return { ready = false, waiting = true }
  end

  local key = mem.u32(sb2 + 0xF20)
  local money = mem.u32(sb1 + 0x290) ~ key

  return {
    ready = true,
    money = money,
    hours = mem.u16(sb2 + 0x0E),
    minutes = mem.u8(sb2 + 0x10),
  }
end
```

Memory addresses come from the game's community research: RAM maps on
[Data Crystal](https://datacrystal.tcrf.net), decompilation projects such as
[pret](https://github.com/pret), and existing tools. The
[Lua API](/docs/lua) lists everything a script can call.

## 3. The layout

`layout.json` is a tree of widgets. `{name}` in text, and `$name` in other fields,
read from the table `update()` returned.

```json
{
  "type": "column",
  "class": "screen",
  "children": [
    { "type": "text", "class": "title", "text": "Trainer" },
    { "type": "text", "text": "Waiting for a save…", "visibleIf": "$waiting" },
    {
      "type": "box",
      "class": "card",
      "visibleIf": "$ready",
      "children": [
        { "type": "text", "class": "money", "text": "₽{money}" },
        { "type": "text", "text": "Played {hours}h {minutes}m" }
      ]
    }
  ]
}
```

`visibleIf` shows a widget only while a value is truthy, so the card appears once a
save is loaded. See [Layout and widgets](/docs/layout) for every widget.

## 4. The stylesheet

```css
:root   { background: #1b1530; color: #f1eefb; }
.screen { padding: 16px; gap: 12px; }
.title  { font-size: 20px; font-weight: 700; color: #f3c234; }
.card   { padding: 12px; gap: 4px; border: 2px solid #5b4b95; border-radius: 8px; background: #241a45; }
.money  { font-size: 28px; font-weight: 700; }
```

It's real CSS with flexbox and grid, minus a few browser features. See
[Styling with CSS](/docs/styling).

## 5. Preview it in the browser

Open the [companion simulator](/simulator), click **Open pack folder…** and pick your
pack. It renders the pack the way the app does. Edit `layout.json`, `style.css` and
`preview-data.json` side by side and the preview updates as you type. In Chrome and
Edge, edits save straight back to your files; other browsers open the folder read-only.

The simulator doesn't run `main.lua`, so it shows the values in `preview-data.json`
instead: a JSON object shaped like what `update()` returns.

```json
{ "ready": true, "money": 3175, "hours": 12, "minutes": 48 }
```

No pack yet? Pick **Blank starter pack** in the simulator: it's the pack from this page.
You can also run the simulator locally from its
[repo](https://github.com/khumam/gba-duo-companion-simulator).

## 6. Run it on the device

1. Zip the **contents** of the pack folder, so `manifest.json` sits at the root of
   the zip, not inside a `my-pack/` folder.
2. Copy the zip to your device.
3. In GBA Duo, tap **⋮** next to the game, then **Import pack…**, and pick the zip.

```sh
cd my-pack && zip -r ../my-pack.zip . -x '.*'
```

Importing a pack with the same `id` again replaces it, so you can iterate by
re-zipping and re-importing.

## When something's wrong

Connect the device with USB debugging on and watch the logs:

```sh
adb logcat -s GBADuoPack Companion PackStyles EmuThread
```

- `GBADuoPack`: your script's `log()` messages.
- `Companion`, `PackStyles`: CSS rules and properties that were skipped, and why.
- `EmuThread`: script errors.

If `update()` throws, the layout gets the error message as `_scriptError`, so you can
show it on screen while developing:

```json
{ "type": "text", "text": "{_scriptError}", "visibleIf": "$_scriptError" }
```

For complete, real-world packs, read the
[gba-duo-companions](https://github.com/khumam/gba-duo-companions) source.
