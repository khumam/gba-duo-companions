# GBADuo Companion Simulator — Design

**Goal:** A local SvelteKit app that renders a companion pack's `layout.json`
exactly as the Android app's `WidgetRenderer` would, so companion themes can
be designed and previewed without pushing to the physical device every time.

**Non-goals:** Lua/mGBA execution in-browser (preview data is static JSON
instead); a GUI property editor (layout is still hand-authored JSON, the
simulator only renders + live-reloads); pack zip export/import (still done
via the Android app's existing "Import pack..." flow); deployment anywhere
beyond `localhost` — this is a local dev tool only.

## Architecture

```
gbaduo-companions/
  packs/                              (existing — pack source folders)
    firered-companion-source/
      manifest.json
      layout.json
      main.lua
      species_names.lua
      item_names.lua
      preview-data.json               (new, this project — see below)
  simulator/                          (new SvelteKit app)
    src/lib/renderer/
      widget-types.js
      parse-layout.js
      render-widget.js
      binding.js
    src/routes/
      +page.svelte
      +page.server.ts
    package.json, svelte.config.js, vite.config.js, etc.
```

The simulator is a standalone SvelteKit app (`npm create svelte` scaffold,
Node adapter for local dev only — no deployment target). It reads pack
folders directly off disk via SvelteKit server `load` functions (Node
`fs`), so there's no browser file-picker permission flow to deal with.

## `src/lib/renderer/` — the JS port

A deliberately literal, file-by-file port of the Android companion
renderer, so the two stay comparable side-by-side:

| Android (Kotlin) | Simulator (JS) | Responsibility |
|---|---|---|
| `Layout.kt`'s `Widget` sealed class | `widget-types.js` | Plain JS object shapes for each widget type (`column`, `row`, `tabs`, `text`, `bar`, `image`, `spacer`, `list`, `box`) |
| `Layout.kt`'s `LayoutParser` | `parse-layout.js` | JSON → widget tree. Same required-field errors as the Kotlin parser (e.g. `box` needs `child`, `list` needs `template`) |
| `Binding.kt` | `binding.js` | Dot/bracket path resolution, `{interpolation}` in text, `ScopedValues(item, index, root)` for list templates, `@index`, `isTruthy`/`asList` |
| `WidgetRenderer.kt` | `render-widget.js` | Widget tree → DOM. One function per widget type, same structure/order as the Kotlin `when` block |

**Rendering fidelity specifics:**
- Canvas is a fixed `1080px × 1240px` container (the Thor's real companion
  display resolute) — not responsive, matches the physical screen exactly.
- `box` → `div` with `border-radius`/`background-color`/`border` CSS,
  1:1 with `GradientDrawable`'s fill/corner-radius/stroke.
- `column`/`row` → flex `div`s (`flex-direction: column`/`row`), gaps via
  a spacer `div` matching the Kotlin renderer's own gap-via-spacer-view
  approach (not CSS `gap`, to stay literally parallel).
- `text` → `div`/`span`; a pack's custom `font` (`.ttf` in
  `assets/fonts/`) is loaded via a generated `@font-face` pointing at the
  file served from the pack folder.
- `bar` → a `div` progress track + filled `div` inner bar sized by
  percentage, mirroring `ProgressBar`'s `max`/`progress`.
- `image` → `<img>` for `asset:`-prefixed sources (served from the pack's
  `assets/` folder); `gfx:`-prefixed and dynamic `$`-bound sources are
  **not renderable in the simulator** (no mGBA/ROM access) — rendered as a
  labeled placeholder box instead, so layout/spacing is still visible even
  though the actual decoded sprite isn't.
- The Thor's companion display reports `density 369dpi` (confirmed via
  `adb shell dumpsys display`), i.e. an Android density factor of
  `369 / 160 = 2.30625` — the same multiplier `WidgetRenderer.kt`'s
  `px(dpValue) = (dpValue * dp).toInt()` uses. `render-widget.js` ports
  this exactly: a `DEVICE_DENSITY = 2.30625` constant and a matching
  `px(dpValue) = Math.round(dpValue * DEVICE_DENSITY)` helper, so a pack's
  `width: 340` (meant as 340dp) renders at the same real pixel size in
  the simulator as it would on the physical second screen.

**Parity discipline (process, not code):** `render-widget.js` is a manual
port with no shared compiler — it will drift from `WidgetRenderer.kt` over
time unless both are updated together. Standing rule going forward: any
future change to `WidgetRenderer.kt`'s widget rendering must land with the
matching `render-widget.js` change. This is a documented discipline, not an
enforced one (no cross-repo CI link between `gbaduo` and
`gbaduo-companions`).

## `preview-data.json`

Each pack folder may include an optional `preview-data.json`, shaped
exactly like a real companion snapshot:

```json
{
  "party": [
    { "name": "BULBASAUR", "level": 5, "hp": 20, "maxHp": 20, "status": "" }
  ],
  "bag": {
    "items": [{ "name": "Potion", "count": 3 }],
    "keyItems": [], "balls": [], "tmHm": [], "berries": []
  },
  "trainer": { "money": 3000, "badges": 0, "playTime": "0:03:56" },
  "_frameCounter": 1234
}
```

The simulator binds the layout against this exactly like the real engine
binds against `CompanionSnapshot`. Missing `preview-data.json` → the
binding context is an empty object, so `{bindings}` resolve to empty
strings (same graceful-degradation behavior as a pack with no script
loaded on-device) rather than throwing.

## Pack picker + live reload

`+page.svelte` has a `<select>` populated from `+page.server.ts`'s
server-side `fs.readdirSync('../packs')` (every subfolder is a pack
candidate). Selecting a pack loads its `manifest.json`/`layout.json`/
`preview-data.json` and renders it.

Live reload: since `layout.json`/`preview-data.json` are read via a
server `load` function (not statically imported), Vite's HMR doesn't
automatically pick up their edits. The page polls a small
`+server.ts` endpoint every 500ms for the selected pack's file
modification times; if either changed, it refetches and re-renders.
Simple, good enough for a local design-iteration loop — no file-watcher
library needed.

## Testing

- **Unit tests** (Vitest, since this is a Vite/SvelteKit project) for
  `parse-layout.js` — same test cases as `LayoutTest.kt` (parses each
  widget type, `box` requires `child`, `list` requires `template`, unknown
  type throws) — proves the JS parser accepts/rejects the same inputs as
  the Kotlin one.
- **Unit tests** for `binding.js` — same cases as `BindingTest.kt` (dot
  paths, array indices, `ScopedValues` item-then-root fallback, `@index`).
- **Manual visual verification**: load `firered-companion-source` (once it
  has a `preview-data.json` and a box/bento layout from the next round) in
  the simulator, confirm it visually matches a real on-device screenshot
  taken earlier in this project.
