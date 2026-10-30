// Writes layout.json for the Oracle of Ages pack: the game's HUD strip on top (B and A items,
// rupees, hearts) and its subscreen below: a brick window with the pages in the panel and
// the tab names in the lower text strip, where the game prints item descriptions.
// 1u = one game pixel = 7 device px = 3.035dp (art/ages-os.mjs bakes the frame at that scale); the
// window itself fills the whole screen, and every page spreads out over the panel.
//
//   node art/layout.mjs

import fs from "node:fs";

const box = (cls, children, extra = {}) => ({ type: "box", class: cls, children, ...extra });
const text = (cls, t, extra = {}) => ({ type: "text", class: cls, text: t, ...extra });
const img = (cls, src, extra = {}) => ({ type: "image", class: cls, src, ...extra });
const list = (cls, items, template, extra = {}) => ({ type: "list", class: cls, items, template, ...extra });
const button = (cls, onClick, children, extra = {}) => ({ type: "button", class: cls, onClick, children, ...extra });
const ui = (n) => `asset:ui/${n}.png`;

// ---- HUD: B and A slots, rupees, hearts ---------------------------------------------------------

const slot = (letter, key) =>
  box(`hslot hslot-${letter.toLowerCase()}`, [
    text("hkey", letter),
    img("hicon", `$hud.${key}Icon`),
    box("hname-box", [text("hname", `{hud.${key}Name}`), text("hlevel", `{hud.${key}Level}`)]),
  ]);

const hud = box("hud", [
  slot("B", "b"),
  slot("A", "a"),
  box("hrupees", [img("hicon", ui("rupee")), text("hnum", "{rupees}")]),
  box("hhearts", [
    list("hrow", "$heartsTop", img("heart", "$src")),
    list("hrow", "$heartsBottom", img("heart", "$src")),
  ]),
]);

// ---- the window: bricks around a panel and a text strip ---------------------------------------------

// The frame is five strips that tile the brick art, so the window can take any width and height.
const frame = [
  box("band band-top", []), box("band band-mid", []), box("band band-bottom", []),
  box("col col-l", []), box("col col-r", []),
];

const TABS = [["items", "ITEMS", "navItems"], ["map", "MAP", "navMap"], ["seeds", "SEEDS", "navSeeds"], ["rings", "RINGS", "navRings"], ["status", "STATUS", "navStatus"]];
const nav = box("nav", TABS.map(([page, label, flag]) =>
  button("tab", [{ navigate: page }], [text("br", "["), text("tab-label", label), text("br", "]")], { classIf: { on: `$${flag}` } }),
));

// ---- ITEMS: the 16 inventory slots in the game's order, icons at 2x -----------------------------------

const items = box("page page-items", [
  list("slots", "$slots", box("cell", [
    box("cell-top", [text("tag", "{tag}"), img("cicon", "$icon")]),
    text("clevel", "{level}"),
  ], { classIf: { empty: "$empty" } })),
]);

// ---- MAP: the overworld of the current era, rooms Link hasn't visited dimmed -----------------------------

const map = box("page page-map", [
  box("map-fill", []),
  box("map-stack", [
    img("map-img", ui("map-present"), { visibleIf: "$map.present" }),
    img("map-img", ui("map-past"), { visibleIf: "$map.past" }),
    list("map-rows", "$map.rows", list("map-row", "$cells", box("mcell", [], { classIf: { unseen: "$unseen", here: "$here" } }))),
    box("era-badge", [text("era-text", "{map.era}")]),
  ]),
  box("map-fill", []),
]);

// ---- SEEDS: the satchel, then the other supplies --------------------------------------------------------

const seeds = box("page page-seeds", [
  list("seed-row", "$seeds", box("seed", [
    img("seed-icon", "$icon"),
    text("seed-count", "{count}"),
    text("seed-name", "{name}"),
    text("seed-tag", "{tag}"),
  ], { classIf: { picked: "$picked" } })),
  list("supply-row", "$supplies", box("supply", [
    img("supply-icon", "$icon"),
    box("supply-text", [text("supply-value", "{value}"), text("supply-label", "{label}")]),
  ])),
]);

// ---- RINGS: worn ring and ring box on the left, the 64 rings on the right ------------------------------------

const rings = box("page page-rings", [
  box("ring-side", [
    text("title", "WORN"),
    box("worn", [img("worn-icon", "$ring.wornIcon"), text("worn-name", "{ring.worn}")]),
    text("title", "RING BOX {ring.boxLevel}"),
    list("box-col", "$ring.box", box("box-slot", [img("box-icon", "$icon"), text("box-name", "{name}")], { classIf: { filled: "$filled" } })),
  ]),
  box("ring-grid", [
    text("title", "COLLECTION {ring.count} / 64"),
    list("dot-rows", "$ring.dotRows", list("dot-row", "$cells", box("dot", [img("dot-img", "$src")], { classIf: { on: "$on" } }))),
  ]),
]);

// ---- STATUS: hearts, essences and where Link is ----------------------------------------------------------------

const status = box("page page-status", [
  box("life", [
    text("life-value", "{status.hearts}"),
    list("life-hearts", "$status.lifeHearts", img("lheart", "$src")),
    list("pieces", "$status.pieces", img("piece", "$src")),
  ]),
  text("title", "ESSENCES {status.essenceCount} / 8"),
  list("essences", "$status.essences", img("essence", "$src")),
  list("facts", "$status.facts", box("fact", [text("fact-value", "{value}"), text("fact-label", "{label}")])),
]);

const pages = { type: "pages", state: "page", initial: "items", pages: [
  { name: "items", child: items }, { name: "map", child: map }, { name: "seeds", child: seeds },
  { name: "rings", child: rings }, { name: "status", child: status },
] };

const win = box("win", [
  box("panel-bg", []),
  box("strip-bg", []),
  ...frame,
  box("panel", [pages]),
  nav,
]);

const layout = box("screen", [
  box("waiting", [box("wait", [text("wait-title", "ORACLE OF AGES"), text("wait-sub", "{waitSub}")])], { visibleIf: "$waiting" }),
  box("shell", [hud, win], { visibleIf: "$ready" }),
], { id: "screen" });

fs.writeFileSync(new URL("../layout.json", import.meta.url), JSON.stringify(layout, null, 2) + "\n");
console.log("wrote layout.json");
