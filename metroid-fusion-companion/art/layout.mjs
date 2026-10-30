// Writes layout.json for the Fusion companion: the game's own pause screen, rebuilt for the
// second screen. Every page repeats the frame (top bar with the L / R tabs and the sector plate,
// the energy / missile / power bomb counters, the message strip), so edit it here, not by hand:
//
//   node art/layout.mjs
//
// Like the game, the pages cycle with the two tabs: the left tab goes to the page before, the
// right tab to the page after.

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
  ["arms", "ARMS"],
  ["sectors", "SECTORS"],
  ["mission", "MISSION"],
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

const banner = (label, extra = "", end = true) =>
  box(`banner ${extra}`.trim(), [text("banner-text", label), grow(), ...(end ? [img("banner-end", ui("banner-end"))] : [])]);

// Counters like the game's header: a green label bar over a dark value tray.
const counter = (cls, icon, label, value, extra = []) =>
  box(`counter ${cls}`, [
    box("counter-head", [img("counter-icon", ui(icon)), text("counter-label", label), grow(), ...extra]),
    box("counter-tray", [text("counter-num", value)]),
  ]);

const hud = box("hud", [
  counter("counter-energy", "ic-tank", "ENERGY", "{energy}", [
    list("tanks", "$tanks", box("tank", [], { classIf: { full: "$full" } })),
  ]),
  counter("counter-missile", "ic-missile", "MISSILE", "{missiles}"),
  counter("counter-bomb", "ic-pbomb", "P-BOMB", "{bombs}"),
]);

const strip = (msg) => box("strip", [text("strip-text", msg)]);

// ---- map page: the area map, then the four security hatches -----------------------------
// main.lua draws an 18 x 9 cell window of the game's own map, centred on Samus.

const hatch = box("hatch", [
  img("hatch-icon", "$icon"),
  text("hatch-name", "{name}"),
  grow(),
  text("hatch-state", "{state}"),
], { classIf: { open: "$open" } });

const mapPage = box("content content-map", [
  box("banner", [
    text("banner-text", "{map.title}"),
    grow(),
    text("banner-text banner-room", "{map.room}"),
    img("banner-end", ui("banner-end")),
  ]),
  box("map-frame", [
    box("map-pan", [
      img("map-img", "$map.image"),
      box("map-dim", []),
      box("samus-anchor", [img("crosshair", ui("crosshair"))], {
        bindStyle: { left: "{map.x}px", top: "{map.y}px" },
        visibleIf: "$map.onMap",
      }),
    ], { visibleIf: "$map.has" }),
    box("map-empty", [text("map-empty-text", "{map.status}")], { visibleIf: "$map.none" }),
  ]),
  list("hatches", "$hatches", hatch),
]);

// ---- status page: Samus in the middle, readouts either side -----------------------------

const fact = box("fact", [text("fact-label", "{label}"), text("fact-value", "{value}")]);

const statusPage = box("content content-status", [
  list("facts", "$status.left", fact),
  img("samus", "$status.samus", { visibleIf: "$status.hasSamus" }),
  box("samus-missing", [text("map-empty-text", "US ROM only")], { visibleIf: "$status.noSamus" }),
  list("facts", "$status.right", fact),
]);

// ---- arms page: every upgrade, lit when Samus has it ---------------------------------------

const toggle = box("toggle", [
  img("node-img", ui("node-on"), { visibleIf: "$on" }),
  img("node-img", ui("node-off"), { visibleIf: "$off" }),
  text("toggle-name", "{name}"),
], { classIf: { on: "$on", off: "$off" } });

const group = (label, items) => [banner(label), list("toggles", items, toggle)];

const armsPage = box("content content-arms", [
  box("col", [...group("BEAM", "$arms.beam"), ...group("MISSILE", "$arms.missile"), ...group("BOMB", "$arms.bomb")]),
  box("col", [
    ...group("SUIT", "$arms.suit"),
    ...group("MISC.", "$arms.misc"),
    box("stat", [text("stat-label", "UPGRADES"), grow(), text("stat-num", "{arms.count}")]),
  ]),
]);

// ---- sectors page: one save-slot style row per sector --------------------------------------

const sectorsPage = box("content content-sectors", [
  list("sector-list", "$sectors", box("sector-row", [
    box("hex", [text("hex-letter", "{tag}")], { classIf: { here: "$here" } }),
    text("sector-name", "{name}"),
    text("sector-code", "{code}"),
    bar("sector-bar", "$pct"),
    text("sector-pct", "{pctText}"),
    img("node-img", ui("node-on"), { visibleIf: "$mapped" }),
    img("node-img", ui("node-off"), { visibleIf: "$unmapped" }),
  ], { classIf: { here: "$here" } })),
]);

// ---- mission page: bosses, security levels, story progress -----------------------------------

const missionPage = box("content content-mission", [
  box("col col-boss", [
    banner("BOSSES"),
    list("rows", "$mission.bosses", box("row", [
      img("node-img", ui("node-on"), { visibleIf: "$done" }),
      img("node-img", ui("node-off"), { visibleIf: "$alive" }),
      text("row-name", "{name}"),
    ], { classIf: { done: "$done", alive: "$alive" } })),
    banner("NEXT"),
    box("next", [text("next-text", "{mission.next}")]),
  ]),
  box("col col-progress", [
    banner("PROGRESS"),
    box("progress", [
      text("progress-num", "{mission.pct}"),
      bar("progress-bar", "$mission.frac"),
    ]),
    banner("SECURITY"),
    list("rows", "$mission.security", box("row", [
      img("row-door", "$icon"),
      text("row-name", "{name}"),
      grow(),
      text("row-state", "{state}"),
    ], { classIf: { done: "$open", alive: "$locked" } })),
  ]),
]);

// ---- screen ----------------------------------------------------------------------------------

const page = (i, name, content, msg) => ({
  name,
  child: box(`page page-${name}`, [topbar(i), hud, content, strip(msg)]),
});

const layout = box("screen-root", [
  box("waiting", [
    box("page page-waiting", [
      box("topbar", []),
      box("boot", [
        box("boot-logo", [img("logo-img", "$logo")], { visibleIf: "$hasLogo" }),
        box("boot-plate", [text("boot-title", "{waitTitle}")], { visibleIf: "$noLogo" }),
        text("boot-sub", "{waitSub}"),
      ]),
      box("strip", [text("strip-text", "Waiting for a loaded save.")]),
    ]),
  ], { visibleIf: "$waiting" }),
  box("shell", [
    {
      type: "pages",
      pages: [
        page(0, "map", mapPage, "{map.status}"),
        page(1, "status", statusPage, "{status.msg}"),
        page(2, "arms", armsPage, "{arms.msg}"),
        page(3, "sectors", sectorsPage, "{sectorsMsg}"),
        page(4, "mission", missionPage, "{mission.msg}"),
      ],
    },
  ], { visibleIf: "$ready" }),
], { id: "screen" });

fs.writeFileSync(new URL("../layout.json", import.meta.url), JSON.stringify(layout, null, 2) + "\n");
console.log("ok");
