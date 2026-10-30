// Writes layout.json for the Zero Mission companion: the game's own pause screen,
// rebuilt for the second screen. Every page repeats the frame (top bar with the
// L / R tabs and the sector plate, the energy and ammo row, the message strip), so
// edit it here, not by hand:
//
//   node art/layout.mjs
//
// Like the game, the pages cycle with the two tabs: the left tab goes to the page
// before, the right tab to the page after.

import fs from "node:fs";

const box = (cls, children, extra = {}) => ({ type: "box", class: cls, children, ...extra });
const text = (cls, t, extra = {}) => ({ type: "text", class: cls, text: t, ...extra });
const img = (cls, src, extra = {}) => ({ type: "image", class: cls, src, ...extra });
const button = (cls, onClick, children, extra = {}) => ({ type: "button", class: cls, onClick, children, ...extra });
const list = (cls, items, template, extra = {}) => ({ type: "list", class: cls, items, template, ...extra });
const bar = (cls, value) => ({ type: "bar", class: cls, value, max: 1 });
const ui = (n) => `asset:ui/${n}.png`;
const grow = () => box("grow", []);

// ---- frame ------------------------------------------------------------------------

const PAGES = [
  ["map", "MAP"],
  ["status", "STATUS"],
  ["sectors", "SECTORS"],
  ["log", "LOG"],
];

const topbar = (i) => {
  const [prevPage, prev] = PAGES[(i + PAGES.length - 1) % PAGES.length];
  const [nextPage, next] = PAGES[(i + 1) % PAGES.length];
  return box("topbar", [
    button("tab tab-l", [{ navigate: prevPage }], [text("key key-l", "L"), text("tab-name", prev)]),
    box("plate", [text("plate-text", "{sector}")]),
    button("tab tab-r", [{ navigate: nextPage }], [text("key key-r", "R"), text("tab-name", next)]),
  ]);
};

const ammo = (cls, icon, value) =>
  box(`ammo ${cls}`, [img("ammo-icon", ui(icon)), text("ammo-num", value)]);

const banner = (label, extra = "", end = true) =>
  box(`banner ${extra}`.trim(), [text("banner-text", label), grow(), ...(end ? [img("banner-end", ui("banner-end"))] : [])]);

const hud = box("hud", [
  img("cube", ui("cube")),
  box("energy", [
    banner("ENERGY", "banner-energy", false),
    box("energy-tray", [text("energy-num", "{energy}")]),
  ]),
  list("tanks", "$tanks", box("tank", [], { classIf: { full: "$full" } })),
  grow(),
  ammo("ammo-m", "ic-missile", "{missiles}"),
  ammo("ammo-sm", "ic-super", "{supers}"),
  ammo("ammo-pb", "ic-pbomb", "{pbombs}"),
]);

const strip = (msg) => box("strip", [text("strip-text", msg)]);

// ---- map page: the area map is the hero, the way the game's map screen is ---------------
// main.lua draws an 18 x 10 cell window of the game's own map, centred on Samus.

const mapPage = box("content content-map", [
  box("banner", [
    text("banner-text", "{map.items}"),
    grow(),
    text("banner-text banner-room", "{map.coords}"),
    img("banner-end", ui("banner-end")),
  ]),
  box("map-frame", [
    box("map-pan", [
      img("map-img", "$map.image"),
      box("samus-anchor", [img("crosshair", ui("crosshair"))], {
        bindStyle: { left: "{map.x}px", top: "{map.y}px" },
        visibleIf: "$map.onMap",
      }),
    ], { visibleIf: "$map.has" }),
    box("map-empty", [text("map-empty-text", "{map.status}")], { visibleIf: "$map.none" }),
  ]),
]);

// ---- status page: suit art in the middle, beam on the left, suit and misc on the right ---

const toggle = box(
  "toggle",
  [
    img("node-img", ui("node-on"), { visibleIf: "$on" }),
    img("node-img", ui("node-off"), { visibleIf: "$off" }),
    img("node-img", ui("node-lock"), { visibleIf: "$locked" }),
    text("toggle-name", "{name}"),
  ],
  { classIf: { on: "$on", off: "$off", locked: "$locked" }, onClick: [{ call: "toggle", args: ["{id}"] }] },
);

const cap = (icon, value) => box("cap", [img(`cap-icon cap-${icon}`, ui(icon)), text("cap-num", value)]);

const statusPage = box("content content-status", [
  box("col col-beam", [
    banner("BEAM"),
    list("toggles", "$armory.beams", toggle),
    banner("MAX"),
    box("toggles", [
      cap("ic-missile", "{missilesMax}"),
      cap("ic-super", "{supersMax}"),
      cap("ic-pbomb", "{pbombsMax}"),
    ]),
  ]),
  box("suit-stage", [
    img("lattice", ui("lattice")),
    img("suit", "$armory.suit"),
    box("wire wire-lh", []),
    box("wire wire-lv", []),
    box("wire wire-rh", []),
    box("wire wire-rv", []),
  ]),
  box("col col-gear", [banner("SUIT / MISC."), list("toggles", "$armory.gear", toggle)]),
]);

// ---- sectors page: one save-slot style row per area ------------------------------------

const sectorsPage = box("content content-sectors", [
  list("sector-list", "$sectors", box("sector-row", [
    box("hex", [text("hex-letter", "{tag}")], { classIf: { here: "$here" } }),
    text("sector-name", "{name}"),
    bar("sector-bar", "$pct"),
    text("sector-pct", "{pctText}"),
  ], { classIf: { here: "$here" } })),
]);

// ---- log page: bosses on the left, recovered items and the clock on the right ----------

const logPage = box("content content-log", [
  box("col col-boss", [
    banner("TARGETS"),
    list("boss-list", "$log.bosses", box("boss", [
      img("node-img", ui("node-on"), { visibleIf: "$done" }),
      img("node-img", ui("node-off"), { visibleIf: "$alive" }),
      text("boss-name", "{name}"),
    ], { classIf: { done: "$done", alive: "$alive" } })),
  ]),
  box("col col-items", [
    banner("RECOVERED"),
    list("item-list", "$log.items", box("item", [
      box("item-head", [
        box("item-slot", [img("item-icon", "$icon")]),
        text("item-name", "{name}"),
        grow(),
        text("item-count", "{got}/{max}"),
      ]),
      bar("item-bar", "$pct"),
    ], { classIf: { "kind-tank": "$tank", "kind-missile": "$missile", "kind-super": "$super", "kind-pbomb": "$pbomb" } })),
    box("stat-row", [
      box("stat", [text("stat-label", "DONE"), text("stat-num", "{log.completion}")]),
      box("stat", [img("stat-icon", ui("ic-clock")), text("stat-num", "{log.time}")]),
    ]),
  ]),
]);

// ---- screen ------------------------------------------------------------------------------

const page = (i, name, content, msg) => ({
  name,
  child: box(`page page-${name}`, [topbar(i), hud, content, strip(msg)]),
});

const layout = box("screen-root", [
  box("waiting", [
    box("page page-waiting", [
      box("topbar", []),
      box("boot", [
        box("boot-logo", [img("logo-top", "$logoTop"), img("logo-body", "$logo")], { visibleIf: "$hasLogo" }),
        box("boot-plate", [text("boot-title", "ZERO MISSION")], { visibleIf: "$noLogo" }),
        text("boot-sub", "Load a save to wake the visor."),
      ]),
      box("strip", [text("strip-text", "Waiting for a loaded save.")]),
    ]),
  ], { visibleIf: "$waiting" }),
  box("shell", [
    {
      type: "pages",
      pages: [
        page(0, "map", mapPage, "{map.status}"),
        page(1, "status", statusPage, "{armory.status}"),
        page(2, "sectors", sectorsPage, "Tap the tabs at the top to change screens."),
        page(3, "log", logPage, "{log.status}"),
      ],
    },
  ], { visibleIf: "$ready" }),
], { id: "screen" });

fs.writeFileSync(new URL("../layout.json", import.meta.url), JSON.stringify(layout, null, 2) + "\n");
console.log("ok");
