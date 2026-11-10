// Writes layout.json for the Oracle of Ages pack, laid in brick: two brick pillars and a brick-rimmed window for the
// page between them. The pillars carry everything else: rupees and the B item on the left, hearts and the A item on the
// right, and under the A and B buttons upright slabs, one per page (three on the left, two on the right with the era
// plate below them), so every page is one tap away and the window takes the whole height.
//
//   node art/layout.mjs

import fs from "node:fs";

const box = (cls, children, extra = {}) => ({ type: "box", class: cls, children, ...extra });
const text = (cls, t, extra = {}) => ({ type: "text", class: cls, text: t, ...extra });
const img = (cls, src, extra = {}) => ({ type: "image", class: cls, src, ...extra });
const list = (cls, items, template, extra = {}) => ({ type: "list", class: cls, items, template, ...extra });
const button = (cls, onClick, children, extra = {}) => ({ type: "button", class: cls, onClick, children, ...extra });
const ui = (n) => `asset:ui/${n}.png`;

// ---- pillars: rupees and hearts on plates, the B and A items on round buttons ---------------------------------

const equip = (letter, key) =>
  box(`equip equip-${letter.toLowerCase()}`, [
    box("disc", [img("equip-icon", `$hud.${key}Icon`), text("equip-key", letter)]),
    text("equip-name", `{hud.${key}Name}`),
    text("equip-level", `{hud.${key}Level}`),
  ]);
const rail = (side, children) => box(`rail rail-${side}`, children);
const rupeePlate = box("plate plate-gold", [img("plate-icon plate-rupee", ui("rupee")), text("plate-num", "{rupees}")]);
const heartPlate = box("plate plate-pink", [img("plate-icon plate-heart", ui("heart-full")), text("plate-num plate-hearts", "{status.hearts}")]);

// ---- the nav: one upright slab per page on the pillars ---------------------------------------------------------

const TABS = [["items", "ITEMS", "navItems"], ["map", "MAP", "navMap"], ["seeds", "SEEDS", "navSeeds"], ["rings", "RINGS", "navRings"], ["status", "STATUS", "navStatus"]];
const tab = ([page, label, flag]) =>
  button("vslab", [{ navigate: page }], [text("vslab-label", label)], { classIf: { on: `$${flag}` } });
const eraPlate = box("plate plate-dark", [text("era-plate-label", "ERA"), text("era-plate-text", "{map.era}")]);
const rim = (part) => box(`rim rim-${part}`, []);
const page = (name, content) => ({
  name,
  child: box(`page page-${name}`, [
    box("window", [box("panel", [content]), rim("t"), rim("b"), rim("l"), rim("r"), rim("tl"), rim("tr"), rim("bl"), rim("br")]),
  ]),
});

// ---- ITEMS: the 16 inventory slots in the game's order ---------------------------------------------------------

const items = box("body body-items", [
  list("slots", "$slots", box("cell", [
    box("cell-top", [text("tag", "{tag}"), img("cicon", "$icon")]),
    text("clevel", "{level}"),
  ], { classIf: { empty: "$empty" } })),
]);

// ---- MAP: the overworld of the current era, rooms Link hasn't visited dimmed -------------------------------------

const map = box("body body-map", [
  box("map-stack", [
    img("map-img", ui("map-present"), { visibleIf: "$map.present" }),
    img("map-img", ui("map-past"), { visibleIf: "$map.past" }),
    list("map-rows", "$map.rows", list("map-row", "$cells", box("mcell", [], { classIf: { unseen: "$unseen", here: "$here" } }))),
    box("era-badge", [text("era-text", "{map.era}")]),
  ]),
]);

// ---- SEEDS: the satchel, then the other supplies -----------------------------------------------------------------

const seeds = box("body body-seeds", [
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

// ---- RINGS: worn ring and ring box on the left, the 64 rings on the right -------------------------------------------

const rings = box("body body-rings", [
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

// ---- STATUS: hearts, the eight essences by name, and where Link is -------------------------------------------------

const status = box("body body-status", [
  box("life", [
    box("life-top", [
      text("life-value", "{status.hearts}"),
      list("pieces", "$status.pieces", img("piece", "$src")),
    ]),
    list("life-hearts", "$status.lifeHearts", img("lheart", "$src")),
  ]),
  box("ess-head", [text("title", "ESSENCES"), box("fill", []), text("title count", "{status.essenceCount} / 8")]),
  list("essences", "$status.essences", box("ess", [img("essence", "$src"), text("ess-name", "{name}")], { classIf: { on: "$on" } })),
  list("facts", "$status.facts", box("fact", [text("fact-value", "{value}"), text("fact-label", "{label}")])),
]);

const pages = { type: "pages", state: "page", initial: "items", pages: [
  page("items", items), page("map", map), page("seeds", seeds), page("rings", rings), page("status", status),
] };

const layout = box("screen", [
  box("waiting", [box("wait", [text("wait-title", "ORACLE OF AGES"), text("wait-sub", "{waitSub}")])], { visibleIf: "$waiting" }),
  box("shell", [
    box("pages-wrap", [pages]),
    box("pillar pillar-l", []),
    box("pillar pillar-r", []),
    rail("l", [rupeePlate, equip("B", "b"), box("tabs", TABS.slice(0, 3).map(tab))]),
    rail("r", [heartPlate, equip("A", "a"), box("tabs", TABS.slice(3).map(tab)), eraPlate]),
  ], { visibleIf: "$ready" }),
], { id: "screen" });

fs.writeFileSync(new URL("../layout.json", import.meta.url), JSON.stringify(layout, null, 2) + "\n");
console.log("wrote layout.json");
