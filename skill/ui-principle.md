---
name: dual-screen-companion-ui
description: Design and refactor Nintendo DS / 3DS-style dual-screen companion interfaces and game overlays. Eliminates cluttered "AI dashboard" layouts in favor of authentic, diegetic, tactile bottom-screen controls built for 0.2-second peripheral glances and thumb muscle memory.
---

# Dual-Screen Companion UI Skill

Use this skill whenever designing, auditing, or refactoring a second-screen companion UI, emulator touch overlay, or game HUD inspired by Nintendo DS, Nintendo 3DS, or minimalist diegetic game interfaces (e.g., *Ocarina of Time 3D*, *A Link Between Worlds*, *Castlevania: Dawn of Sorrow*, *Breath of the Wild*).

## Core Design Philosophy

A game companion screen is **not a web analytics dashboard**—it is a **tactile game controller**. Because the player's eyes stay locked on the primary screen 90% of the time, the companion screen must prioritize peripheral readability, spatial muscle memory, and physical button feel over dense information display.

---

## The 5 Non-Negotiable Rules

### 1. One Screen, One Job
* **80% Hero Widget Rule:** Dedicate at least 80% of the viewport to a single primary task (e.g., *either* an interactive Quick-Equip Grid *or* a Live Dungeon Map—never both fighting for space).
* **Chunky Edge Tabs:** Hide secondary modes behind 2–3 large, thumb-accessible tabs along the outer top or side edges, mirroring 3DS sub-screen navigation.
* **Intentional Dead Space:** Leave breathing room around the outer perimeter to act as a visual frame that draws the eye immediately to interactive targets.

### 2. Murder the Text Labels
* **Zero Labels Under Grid Icons:** Never place text labels (e.g., "Health Potion", "Hookshot", "Poké Ball") beneath recognizable item sprites.
* **Isolate Text to One Zone:** If item names or descriptions are needed, display them in *one* dedicated inspection pane or a temporary press-and-hold banner—never inside grid tiles.
* **Badges Over Sentences:** Replace verbose status strings (`"Equipped to Slot A"`, `"HP: 14 of 20"`) with compact corner badges (`A`, `B`, `L`, `R`, `14/20`).

### 3. One Unified Physical Surface (No Nested Cards)
* **Diegetic Container:** Frame the entire viewport as a single physical artifact from the target game's universe (e.g., weathered parchment, carved stone tablet, Pokédex bezel, dark Sheikah slate).
* **9-Slice Pixel Borders:** For retro/handheld themes, extract native frame corners at 1x resolution and render with `image-rendering: pixelated` and CSS `border-image` so corners stay razor-sharp.
* **Recessed Slots, Not Floating Cards:** Carve low-contrast recessed slots (`rgba(255, 255, 255, 0.03)`) into the unified surface. Never stack bordered cards inside bordered panels.

### 4. The 60 / 30 / 10 Contrast Budget
* **60% Quiet Surface:** Deep charcoal, dark navy, or muted ROM-sampled earth tone that recedes visually.
* **30% Subtle Structure:** Low-opacity hairline dividers, recessed slot wells, and dimmed/silhouette states for locked items (`35%–50%` opacity).
* **10% Active Signal:** **One** high-saturation accent color (electric cyan, 3DS gold, or crimson) reserved exclusively for the active cursor, equipped items, or critical alerts.

### 5. Fat-Thumb Ergonomics & Tactile Snap
* **3 to 5 Columns Max:** Keep interactive grids chunky (`3–5` columns wide) with generous internal padding (`10px–14px` around each sprite) so players never mis-tap mid-combat.
* **Outer Thumb Zones:** Place high-frequency interactive triggers along the outer left and right columns within natural thumb arc; reserve the center for passive telemetry.
* **Physical Travel & Pixel Cadence:** Give interactive tiles a `2px–3px` bottom bevel that physically depresses on `:active`. Use stepped transitions (`steps(2)`) for pixel-art interfaces or snappy `80ms–120ms` ease-out transitions for sleek vector slates.

---

## Anti-Patterns ("AI Slop" Checklist)

Reject and refactor any layout exhibiting these traits:
- [ ] **Information Dumps:** Displaying stats, inventories, maps, quest logs, and button hints all on one screen simultaneously.
- [ ] **Card-in-Card Nesting:** Wrapping every stat group in glowing borders, rounded SaaS cards, or heavy drop shadows.
- [ ] **Redundant Text:** Labeling self-explanatory game icons or writing full explanatory sentences in a HUD.
- [ ] **Equal-Weight Noise:** Giving inactive buttons bright borders, gradients, or neon glows so nothing stands out.
- [ ] **Tiny Touch Targets:** Cramming 7+ columns of tiny icons onto a touch viewport.

---

## Reference CSS Patterns

### Style A: Tactile 16-Bit / 3DS Handheld Frame
```css
:root {
  --surface-base: #1c1915;
  --slot-well: #2a241d;
  --slot-border: #4a3f33;
  --slot-shadow: #120f0c;
  --accent-active: #ffd84d; /* 3DS Selection Gold */
}

.companion-shell {
  image-rendering: pixelated;
  background-color: var(--surface-base);
  border: 12px solid transparent;
  border-image: url("assets/frame-9slice.png") 12 fill stretch;
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 10px;
  padding: 16px;
}

.tactile-slot {
  position: relative;
  aspect-ratio: 1 / 1;
  background: var(--slot-well);
  border: 2px solid var(--slot-border);
  box-shadow: 0 3px 0 var(--slot-shadow), inset 0 1px 0 rgba(255, 255, 255, 0.12);
  display: grid;
  place-items: center;
  padding: 12px;
  transition: transform 0.06s steps(2), box-shadow 0.06s steps(2);
}

.tactile-slot:active,
.tactile-slot.is-equipped {
  transform: translateY(2px);
  box-shadow: 0 1px 0 var(--slot-shadow);
  border-color: var(--accent-active);
}

.tactile-slot.is-locked img {
  filter: brightness(0) invert(0.25);
  opacity: 0.45;
}

.slot-badge {
  position: absolute;
  top: 4px;
  right: 4px;
  font-size: 11px;
  font-weight: 800;
  color: var(--surface-base);
  background: var(--accent-active);
  padding: 1px 4px;
}
```

### Style B: Techno-Minimalist Slate (Sheikah / BotW)
```css
:root {
  --bg-canvas: #0b0d0c;
  --slot-bg: rgba(255, 255, 255, 0.03);
  --border-muted: rgba(226, 222, 211, 0.22);
  --text-warm: #eae4d3;
  --accent-cyan: #3cd3fc;
}

.slate-layout {
  display: grid;
  grid-template-columns: 1.4fr 1fr;
  background: var(--bg-canvas);
  color: var(--text-warm);
  font-family: "Nunito Sans", system-ui, sans-serif;
  font-style: italic;
}

.slate-grid {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 8px;
  padding: 16px;
}

.slate-slot {
  aspect-ratio: 1 / 1;
  background: var(--slot-bg);
  border: 1px solid var(--border-muted);
  display: grid;
  place-items: center;
  padding: 10px;
  transition: transform 0.1s ease, border-color 0.1s ease;
}

.slate-slot.is-selected {
  border: 2px solid var(--accent-cyan);
  background: rgba(60, 211, 252, 0.08);
  box-shadow: 0 0 10px rgba(60, 211, 252, 0.45), inset 0 0 8px rgba(60, 211, 252, 0.25);
}

.slate-inspector {
  border-left: 2px solid var(--accent-cyan);
  padding: 20px;
}
```

---

## Agent Audit & Refactoring Workflow

When asked to review or simplify an existing companion UI:
1. **Identify the Primary Job:** State the single main action of the screen and move secondary widgets into 2–3 edge tabs.
2. **Purge Text & Nested Containers:** Strip all text labels from grid tiles and remove borders/shadows from inactive containers.
3. **Sample the Game's Diegetic Identity:** Match the background material, palette, and border framing to an authentic in-universe object from the target game.
4. **Enforce Grid Ergonomics:** Resize touch targets to a 3–5 column layout with clear `:active` tactile feedback and a strict 60/30/10 contrast budget.