// Writes layout.json for the "old stone" design (after the wireframe zeldaa6.png): two carved
// pillars with the rupee plate and Ezlo on the left and the kinstone plate with the A and B
// items on the right, a brick-framed window between them for the page, and three stone slabs
// under it: the previous page, this page's name, the next page. The two outer slabs walk the
// five pages as a loop, so each page carries its own trio.
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

// ---- frame: pillars, plates, Ezlo, A / B -------------------------------------------------

const pillar = (side) => box(`pillar pillar-${side}`, []);

const statLeft = box("plate plate-green", [
  img("hicon hicon-rupee", ui("rupee-green")),
  text("num rupees", "{rupees}"),
]);
const statRight = box("plate plate-red", [
  img("hicon", icon("kinstone-red")),
  text("num kin", "{kinstones}"),
]);

const ezlo = button("ezlo-btn", [{ set: { hint: true } }], [img("ezlo", "$ezlo")]);

const equip = (key, path) =>
  box(
    `equip equip-${key.toLowerCase()}`,
    [
      box("disc", [img("equip-icon", `$${path}.icon`), text("equip-key", key)]),
      text("equip-name", `{${path}.name}`),
    ],
    // an item dragged here from the ITEMS page goes on this button (main.lua actions.equip)
    { onDrop: { call: "equip", args: [key, "{drag}"] } },
  );

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

// ---- page chrome: the nav slabs ------------------------------------------------------------

const ORDER = ["map", "items", "kinstone", "quest", "options"];
const TITLES = { map: "MAPS", items: "ITEMS", kinstone: "KINSTONE", quest: "QUESTS", options: "OPTIONS" };

// The label's size follows its length so every name fills its slab: short names big, KINSTONE smaller.
const fit = (label) => (label.length <= 5 ? "f5" : label.length <= 7 ? "f7" : "f8");

const navSlab = (side, target) =>
  button(`slab slab-${side}`, [{ navigate: target }], [
    ...(side === "l" ? [img("slab-arrow slab-arrow-l", ui("stone-arrow-l"))] : []),
    text(`slab-label ${fit(TITLES[target])}`, TITLES[target]),
    ...(side === "r" ? [img("slab-arrow slab-arrow-r", ui("stone-arrow-r"))] : []),
    ...(target === "kinstone" ? [img(`slab-alert slab-alert-${side}`, icon("kinstone-red"), { visibleIf: "$kinstone.ready" })] : []),
  ]);
// The middle slab is the page's name, not a button.
const navBar = (name) => {
  const i = ORDER.indexOf(name);
  return box("nav", [
    navSlab("l", ORDER[(i + ORDER.length - 1) % ORDER.length]),
    box("slab slab-here", [text(`slab-label slab-label-here ${fit(TITLES[name])}`, TITLES[name])]),
    navSlab("r", ORDER[(i + 1) % ORDER.length]),
  ]);
};

// ---- panels -------------------------------------------------------------------------------

// Copper rim around a wooden inset.
const panel = (cls, inner) => box(`pframe ${cls}`, [box("pinner", inner)]);
const card = (cls, title, body) =>
  box(`card ${cls}`, [...(title ? [text("card-title", title)] : []), ...body]);

// An item slot: a tap shows the item's name. Items that can be equipped (`canEquip`, from main.lua) can also be
// held and dragged onto the A or B disc on the pillar.
const pick = [{ set: { pick: "{name}", pickIcon: "{icon}", picked: true } }];
const slot = (cls = "") =>
  box(
    `slot ${cls}`.trim(),
    [
      img("slot-icon", "$icon", { visibleIf: "$owned" }),
      box("slot-count", [text("num count", "{count}")], { visibleIf: "$hasCount" }),
    ],
    { classIf: { empty: "$empty", movable: "$canEquip" }, onClick: pick, drag: "{equipKey}", dragIf: "$canEquip" },
  );
const picked = (cls = "") =>
  box(
    `picked ${cls}`.trim(),
    [img("picked-icon", "$ui.pickIcon"), text("picked-name", "{ui.pick}")],
    { visibleIf: "$ui.picked" },
  );

// ---- map page -----------------------------------------------------------------------------

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

const mapPage = box("content", [
  panel("p-map", [
    // The place's name, and WORLD / DUNGEON while Link is in a dungeon (WORLD keeps the visit it was
    // tapped in, so the next dungeon opens on DUNGEON again: main.lua readDungeonMap).
    box("map-head", [
      box("map-tag", [text("map-tag-text", "{location}")]),
      box("map-tabs", [
        mapTab("WORLD", "{map.visit}", "$map.showWorld"),
        mapTab("DUNGEON", "", "$map.showDungeon"),
      ], { visibleIf: "$map.inDungeon" }),
    ]),
    box("map-view", [
      // The game's own world map, built from the player's ROM by main.lua (or the drawn fallback).
      img("map-img", "$map.image"),
      img("mark mark-link", "$icons.linkHead", { bindStyle: { left: "{map.linkX}%", top: "{map.linkY}%" } }),
      dungeonView,
    ]),
  ]),
  // Link and his hearts, as the game draws them (rom_gfx.lua): two rows of ten hold all twenty containers.
  panel("p-link", [
    box("link-row", [
      img("link-sprite", "$link.sprite"),
      list("hearts", "$link.hearts", img("heart", "$src"), { visibleIf: "$link.hasHearts" }),
    ]),
  ]),
]);

// ---- items page ---------------------------------------------------------------------------

// Gear is a strip: ammo with its bar, then the small counts. The icons say what each is.
const gearRow = (iconName, val, pct, cls) =>
  box(`gear-row ${cls}`, [
    img("gear-icon", icon(iconName)),
    box("gear-main", [text("num gear-val", val), ...(pct ? [bar("gear-bar", pct)] : [])]),
  ]);
const itemsPage = box("content", [
  panel("p-pouch", [
    box("pouch-head", [text("pouch-title", "DRAG TO A OR B"), picked()]),
    list("item-grid", "$items", slot("slot-s")),
  ]),
  panel("p-gear", [
    box("gear-grid", [
      gearRow("bombs", "{gear.bombs}/{gear.bombMax}", "$gear.bombPct", "red g3"),
      gearRow("quiver", "{gear.arrows}/{gear.arrowMax}", "$gear.arrowPct", "blue g3"),
      gearRow("farores-charm", "{gear.charmTime}", null, "g2"),
      gearRow("shell", "{gear.shells}", null, "g2"),
      gearRow("heart-piece", "{gear.heartPieces}", null, "g2"),
    ]),
  ]),
]);

// ---- kinstone page ------------------------------------------------------------------------

const kinstonePage = box("content", [
  panel("p-fusion", [
    box("alert", [img("alert-icon", icon("kinstone-red")), text("alert-text", "{kinstone.readyHint}")], {
      visibleIf: "$kinstone.ready",
    }),
    box("fuse-count", [text("fuse-label", "FUSED"), grow(), text("num fuse-num", "{kinstone.fused}"), text("num fuse-of", "/{kinstone.fusionTotal}")]),
    bar("fuse-bar", "$kinstone.fusedPct"),
    box("tally", [
      box("tally-cell", [img("tally-icon", icon("kinstone-red")), text("num tally-num", "{kinstone.red}")]),
      box("tally-cell", [img("tally-icon", icon("kinstone-blue")), text("num tally-num", "{kinstone.blue}")]),
      box("tally-cell", [img("tally-icon", icon("kinstone-green")), text("num tally-num", "{kinstone.green}")]),
      box("tally-cell", [img("tally-icon", icon("kinstone-gold")), text("num tally-num", "{kinstone.gold}")]),
    ]),
  ]),
  panel("p-pieces", [
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
]);

// ---- quest page ---------------------------------------------------------------------------

const questPage = box("content", [
  panel("p-quest", [
    box("quest-top", [
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
      box("quest-right", [
        list(
          "element-row",
          "$quest.elements",
          box("element", [img("element-icon", "$icon"), text("element-name", "{name}")], {
            classIf: { owned: "$owned", locked: "$locked" },
          }),
        ),
        box("stats", [
          box("stat", [img("stat-icon", icon("figurines")), text("num stat-val", "{quest.figurines}")]),
          box("stat", [img("stat-icon", icon("tiger-scroll")), text("num stat-val", "{quest.skills}")]),
        ]),
      ]),
    ]),
    text("side-caption", "SIDE QUESTS"),
    list(
      "side-list",
      "$quest.side",
      box("side", [img("side-icon", "$icon"), text("side-name", "{name}"), text("side-done", "DONE", { visibleIf: "$done" })], {
        classIf: { done: "$done" },
      }),
      { empty: "NO ERRANDS RIGHT NOW" },
    ),
  ]),
]);

// ---- options page -------------------------------------------------------------------------

// One switch per row; the app handles both calls itself (wideView steps off > on > XL, ambientView toggles).
const option = (title, desc, call, onKey, labelKey) =>
  button(
    "opt",
    call === "writePermission" ? { call } : { call, args: ["toggle"] },
    [
      box("opt-text", [text("opt-title", title), text("opt-desc", desc)]),
      box("opt-pill", [text("num opt-state", `{${labelKey}}`)], { classIf: { on: `$${onKey}` } }),
    ],
  );
const optionsPage = box("content", [
  panel("p-options", [
    box("opt-list", [
      option("WIDE VIEW", "Paint the world beyond the game's frame. Tap again for extra wide.", "wideView", "_wide", "_wideLabel"),
      option("COLOR AMBIENT", "A richer grade with soft shadows, sunlit edges and drifting clouds.", "ambientView", "_ambient", "_ambientLabel"),
      option("GAME CHANGES", "Lets this pack hide the game's own HUD and equip items. Tap to be asked again.", "writePermission", "_writePerm", "_writePermLabel"),
    ]),
  ]),
]);

// The window holds the page's content; the nav is its own strip under it.
const rim = (part) => box(`rim rim-${part}`, []);
const page = (name, content) => ({
  name,
  child: box(`page page-${name}`, [
    box("window", [rim("t"), rim("b"), rim("l"), rim("r"), rim("tl"), rim("tr"), rim("bl"), rim("br"), content]),
    navBar(name),
  ]),
});

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
      // The real engine only stretches a stack child when the stack's size is
      // definite, so the pages get a flex-sized wrapper and explicit 100% sizes.
      box("pages-wrap", [{
        type: "pages",
        class: "pages",
        pages: [page("map", mapPage), page("items", itemsPage), page("kinstone", kinstonePage), page("quest", questPage), page("options", optionsPage)],
      }]),
      pillar("l"),
      pillar("r"),
      // Ivy creeping in from the top and bottom edges, over the pillars but under the plates and buttons.
      img("vine vine-tl", ui("vine-tl")),
      img("vine vine-tr", ui("vine-tr")),
      img("vine vine-bl", ui("vine-bl")),
      img("vine vine-br", ui("vine-br")),
      box("rail rail-l", [statLeft, ezlo]),
      box("rail rail-r", [statRight, equip("A", "equipA"), equip("B", "equipB")]),
      hint,
    ], { visibleIf: "$ready" }),
  ],
  { id: "screen" },
);

fs.writeFileSync(new URL("../layout.json", import.meta.url), JSON.stringify(layout, null, 2) + "\n");
console.log("ok");
