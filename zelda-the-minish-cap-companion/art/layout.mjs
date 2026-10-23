// Writes layout.json for the "Minish-OS (Picori Pedestal)" design: green
// backdrop, stitched leather header, copper-riveted panels crowned with leafy
// title plaques, and a steel-framed wooden command dock. The dock is repeated
// on every page (the open tab carries `.on`), so edit it here:
//
//   node art/layout.mjs

import fs from "node:fs";

const box = (cls, children, extra = {}) => ({ type: "box", class: cls, children, ...extra });
const text = (cls, t, extra = {}) => ({ type: "text", class: cls, text: t, ...extra });
const img = (cls, src, extra = {}) => ({ type: "image", class: cls, src, ...extra });
const button = (cls, onClick, children) => ({ type: "button", class: cls, onClick, children });
const list = (cls, items, template, extra = {}) => ({ type: "list", class: cls, items, template, ...extra });
const bar = (cls, value) => ({ type: "bar", class: cls, value, max: 1 });
const ui = (n) => `asset:ui/${n}.png`;
// Icons come from main.lua (`icons.*`): drawn from the player's ROM, or the pack's own art.
const ICON_KEYS = {
  "kinstone-red": "kinstoneRed", "kinstone-blue": "kinstoneBlue", "kinstone-green": "kinstoneGreen",
  "kinstone-gold": "kinstoneGold", figurines: "figurines", "tiger-scroll": "tigerScroll",
  "heart-piece": "heartPiece", shell: "shell", bombs: "bombs", quiver: "quiver", "farores-charm": "charm",
};
const icon = (n) => {
  if (!ICON_KEYS[n]) throw new Error(`no icon key for ${n}`);
  return `$icons.${ICON_KEYS[n]}`;
};
const grow = () => box("grow", []);

// ---- header -----------------------------------------------------------------------

// The stitching is the inner box's own dashed border (an overlay would eat taps).
const header = box("header", [box("header-in", [
  box("hgroup", [img("hicon hicon-rupee", ui("rupee-green")), text("num rupees", "{rupees}"), text("num of", " / {walletMax}")]),
  box("hgroup", [img("hicon", icon("kinstone-red")), text("num kin", "{kinstones}")]),
  grow(),
  button("ezlo-btn", [{ set: { hint: true } }], [img("ezlo", "$ezlo")]),
])]);

const hint = box(
  "bubble",
  [
    img("bubble-ezlo", "$ezlo"),
    box("bubble-body", [
      text("bubble-name", "EZLO"),
      text("bubble-text", "{ezloHint}"),
      text("bubble-close", "TAP TO CLOSE"),
    ]),
  ],
  { visibleIf: "$ui.hint", onClick: [{ set: { hint: false } }] },
);

// ---- dock -------------------------------------------------------------------------

const TABS = [
  ["map", "MAP"],
  ["items", "ITEMS"],
  ["kinstone", "KINSTONE"],
  ["quest", "QUEST"],
];
const bolts = ["tl", "tr", "bl", "br"].map((c) => img(`bolt bolt-${c}`, ui("bolt")));
const dock = (active) =>
  box("dock", [
    img("dock-leaves dock-leaves-l", ui("leaves-big-l")),
    img("dock-leaves dock-leaves-r", ui("leaves-big-r")),
    box(
      "tabs",
      TABS.map(([page, label]) =>
        button(`tab tab-${page}${page === active ? " on" : ""}`, [{ navigate: page }], [
          box("tab-plank", [text("tab-label", `[${label}]`)]),
          ...bolts,
          ...(page === "kinstone" ? [img("tab-alert", icon("kinstone-red"), { visibleIf: "$kinstone.ready" })] : []),
        ]),
      ),
    ),
  ]);

// ---- panels -----------------------------------------------------------------------

// Copper-riveted frame with a leaf-crowned title plaque riding its top edge.
// Rivets sit symmetrically on the copper rim (corners + side and bottom midpoints).
const RIVETS = ["tl", "tr", "bl", "br", "ml", "mr", "bm"];
const panel = (cls, title, inner) =>
  box(`panel ${cls}`, [
    box("panel-frame", [box("panel-inner", inner), ...RIVETS.map((r) => img(`rivet rivet-${r}`, ui("rivet")))]),
    box("plaque-row", [
      box("plaque", [
        img("plaque-leaf plaque-leaf-l", ui("leaf-l")),
        text("plaque-text", title),
        img("plaque-leaf plaque-leaf-r", ui("leaf-r")),
      ]),
    ]),
  ]);
const card = (cls, title, body) =>
  box(`card ${cls}`, [...(title ? [text("card-title", title)] : []), ...body]);

// An item slot; tapping copies it into $ui.pick*.
const pick = [{ set: { pick: "{name}", pickIcon: "{icon}", picked: true } }];
const slot = (cls = "") =>
  box(
    `slot ${cls}`.trim(),
    [
      img("slot-icon", "$icon", { visibleIf: "$owned" }),
      box("slot-count", [text("num count", "{count}")], { visibleIf: "$hasCount" }),
    ],
    { classIf: { empty: "$empty" }, onClick: pick },
  );
const picked = (cls = "") =>
  box(
    `picked ${cls}`.trim(),
    [img("picked-icon", "$ui.pickIcon"), text("picked-name", "{ui.pick}")],
    { visibleIf: "$ui.picked" },
  );

// ---- map page ---------------------------------------------------------------------------

const equip = (key, path) =>
  box(`equip equip-${key.toLowerCase()}`, [
    box("equip-ring", [img("equip-icon", `$${path}.icon`), box("equip-badge", [text("equip-key", key)])]),
    text("equip-name", `{${path}.name}`),
  ]);

const mapTab = (label, worldAt, on) => ({
  type: "button",
  class: "map-tab",
  onClick: [{ set: { mapWorldAt: worldAt } }],
  classIf: { on },
  children: [text("map-tab-label", label)],
});

// The dungeon you're in: its floors (Link's, and the boss's once you have the compass),
// then the map, compass and big key (dimmed until found) and the small keys, drawn
// with the pause menu's own sprites.
const dungeonView = box(
  "dmap",
  [
    box("dmap-head", [text("dmap-name", "{dungeon.name}")]),
    box("dmap-body", [
      list(
        "dmap-floors",
        "$dungeon.floors",
        box(
          "dfloor",
          [
            box("dfloor-mark", [img("dfloor-link", "$icons.linkHead", { visibleIf: "$here" })]),
            text("num dfloor-name", "{name}"),
            box("dfloor-mark", [img("dfloor-boss", ui("mark-boss"), { visibleIf: "$boss" })]),
          ],
          { classIf: { here: "$here" } },
        ),
      ),
      box("dmap-items", [
        list(
          "ditem-row",
          "$dungeon.items",
          box("ditem", [box("ditem-slot", [img("ditem-icon", "$icon")]), text("ditem-name", "{name}")], {
            classIf: { missing: "$missing" },
          }),
        ),
        box("dkeys", [img("dkey-icon", "$dungeon.keyIcon"), text("num dkey-num", "{dungeon.keys}")]),
      ]),
    ]),
  ],
  { visibleIf: "$map.showDungeon" },
);

const mapPage = box("content cols-map", [
  panel("map-panel", "HYRULE MAP", [
    // In a dungeon: WORLD / DUNGEON. WORLD keeps the visit it was tapped in, so the
    // next dungeon opens on DUNGEON again (main.lua readDungeonMap).
    box("map-tabs", [
      mapTab("WORLD", "{map.visit}", "$map.showWorld"),
      mapTab("DUNGEON", "", "$map.showDungeon"),
    ], { visibleIf: "$map.inDungeon" }),
    box("map-view", [
      // The game's own world map, built from the player's ROM by main.lua (or the drawn fallback).
      img("map-img", "$map.image"),
      img("mark mark-link", "$icons.linkHead", { bindStyle: { left: "{map.linkX}%", top: "{map.linkY}%" } }),
      dungeonView,
    ]),
    box("map-tag", [text("map-tag-text", "{location}")]),
  ]),
  panel("items-panel", "LINK", [
    box("equips", [equip("A", "equipA"), equip("B", "equipB")]),
    // Link and his hearts, as the game draws them (rom_gfx.lua), following his health:
    // Link on top, the hearts centred under him, wrapping onto more rows; a leaf in each corner.
    card("link-card", null, [
      img("link-leaf link-leaf-tl", ui("leaf-r")),
      img("link-leaf link-leaf-tr", ui("leaf-l")),
      img("link-leaf link-leaf-bl", ui("leaf-l")),
      img("link-leaf link-leaf-br", ui("leaf-r")),
      img("link-sprite", "$link.sprite"),
      list("hearts", "$link.hearts", img("heart", "$src"), { visibleIf: "$link.hasHearts" }),
    ]),
  ]),
]);

// ---- items page -------------------------------------------------------------------------

const gearRow = (iconName, name, val, pct, cls) =>
  box(`gear-row ${cls}`, [
    img("gear-icon", icon(iconName)),
    box("gear-main", [
      box("gear-top", [text("gear-name", name), grow(), text("num gear-val", val)]),
      ...(pct ? [bar("gear-bar", pct)] : []),
    ]),
  ]);
const itemsPage = box("content cols-items", [
  panel("bag-panel", "ITEM POUCH", [card("pouch-card", null, [box("card-head", [text("card-title", "TAP AN ITEM"), picked()]), list("item-grid", "$items", slot("slot-s"))])]),
  panel("gear-panel", "GEAR", [
    gearRow("bombs", "BOMBS", "{gear.bombs}/{gear.bombMax}", "$gear.bombPct", "red"),
    gearRow("quiver", "ARROWS", "{gear.arrows}/{gear.arrowMax}", "$gear.arrowPct", "blue"),
    gearRow("farores-charm", "CHARM", "{gear.charmTime}", null, ""),
    gearRow("shell", "SHELLS", "{gear.shells}", null, ""),
    gearRow("heart-piece", "PIECES", "{gear.heartPieces}", null, ""),
  ]),
]);

// ---- kinstone page ----------------------------------------------------------------------

const kinstonePage = box("content cols-kin", [
  panel("fusion-bag", "FUSION BAG", [
    card("piece-card", null, [
      list(
        "piece-grid",
        "$kinstone.pieces",
        box(
          "piece",
          [
            img("piece-icon", "$icon"),
            box("piece-text", [
              text("piece-name", "{name}"),
              box("piece-foot", [text("num piece-id", "{id}"), grow(), text("num piece-amt", "{amount}")]),
            ]),
          ],
          { classIf: { red: "$isRed", blue: "$isBlue", green: "$isGreen", gold: "$isGold" } },
        ),
        { empty: "NO KINSTONE PIECES YET" },
      ),
    ]),
  ]),
  panel("fuse-panel", "FUSION", [
    box("fuse-count", [text("num fuse-num", "{kinstone.fused}"), text("num fuse-of", "/{kinstone.fusionTotal}")]),
    bar("fuse-bar", "$kinstone.fusedPct"),
    box("tally", [
      box("tally-cell", [img("tally-icon", icon("kinstone-red")), text("num tally-num", "{kinstone.red}")]),
      box("tally-cell", [img("tally-icon", icon("kinstone-blue")), text("num tally-num", "{kinstone.blue}")]),
      box("tally-cell", [img("tally-icon", icon("kinstone-green")), text("num tally-num", "{kinstone.green}")]),
      box("tally-cell", [img("tally-icon", icon("kinstone-gold")), text("num tally-num", "{kinstone.gold}")]),
    ]),
    grow(),
    box("alert", [img("alert-icon", icon("kinstone-red")), text("alert-text", "{kinstone.readyHint}")], {
      visibleIf: "$kinstone.ready",
    }),
  ]),
]);

// ---- quest page -------------------------------------------------------------------------

const questPage = box("content cols-quest", [
  panel("quest-panel", "ELEMENTS", [
    list(
      "element-row",
      "$quest.elements",
      box("element", [img("element-icon", "$icon"), text("element-name", "{name}")], {
        classIf: { owned: "$owned", locked: "$locked" },
      }),
    ),
    card("dungeon-card", "DUNGEONS", [
      list(
        "dungeon-list",
        "$quest.dungeons",
        box(
          "dungeon",
          [
            box("dg-mark", [
              img("dg-check", ui("check"), { visibleIf: "$cleared" }),
              img("dg-here", "$icons.linkHead", { visibleIf: "$here" }),
            ]),
            text("dg-name", "{name}"),
          ],
          { classIf: { cleared: "$cleared", here: "$here" } },
        ),
      ),
    ]),
  ]),
  panel("side-panel", "SIDE QUESTS", [
    list(
      "side-list",
      "$quest.side",
      box("side", [img("side-icon", "$icon"), text("side-name", "{name}"), grow(), text("side-done", "DONE", { visibleIf: "$done" })], {
        classIf: { done: "$done" },
      }),
      { empty: "NO ERRANDS RIGHT NOW" },
    ),
    grow(),
    box("stats", [
      box("stat", [img("stat-icon", icon("figurines")), text("num stat-val", "{quest.figurines}")]),
      box("stat", [img("stat-icon", icon("tiger-scroll")), text("num stat-val", "{quest.skills}")]),
      box("stat", [img("stat-icon", icon("heart-piece")), text("num stat-val", "{quest.heartPieces}")]),
      box("stat", [img("stat-icon", icon("shell")), text("num stat-val", "{quest.shells}")]),
    ]),
  ]),
]);

const page = (name, content) => ({ name, child: box(`page page-${name}`, [content, dock(name)]) });

const layout = box(
  "bezel",
  [
    box("waiting", [
      box("boot", [
        img("boot-emblem", "$logo", { visibleIf: "$hasLogo" }),
        text("boot-title", "THE MINISH CAP", { visibleIf: "$noLogo" }),
        box("boot-pill", [text("boot-pill-text", "GBADUO COMPANION PACK")]),
      ]),
    ], { visibleIf: "$waiting" }),
    box("shell", [
      header,
      // The real engine only stretches a stack child when the stack's size is
      // definite, so the pages get a flex-sized wrapper and explicit 100% sizes.
      box("pages-wrap", [{
        type: "pages",
        class: "pages",
        pages: [page("map", mapPage), page("items", itemsPage), page("kinstone", kinstonePage), page("quest", questPage)],
      }]),
      hint,
    ], { visibleIf: "$ready" }),
  ],
  { id: "screen" },
);

fs.writeFileSync(new URL("../layout.json", import.meta.url), JSON.stringify(layout, null, 2) + "\n");
console.log("ok");
