// Writes layout.json for the "Zero-OS" design: Samus's visor as a riveted,
// hazard-striped cyber terminal. The dock is repeated on every page (the open
// tab carries `.on`), so edit it here, not by hand:
//
//   node art/layout.mjs

import fs from "node:fs";

const box = (cls, children, extra = {}) => ({ type: "box", class: cls, children, ...extra });
const text = (cls, t, extra = {}) => ({ type: "text", class: cls, text: t, ...extra });
const img = (cls, src, extra = {}) => ({ type: "image", class: cls, src, ...extra });
const button = (cls, onClick, children, extra = {}) => ({ type: "button", class: cls, onClick, children, ...extra });
const list = (cls, items, template, extra = {}) => ({ type: "list", class: cls, items, template, ...extra });
const bar = (cls, value) => ({ type: "bar", class: cls, value, max: 1 });
const ui = (n) => `asset:ui/${n}.png`;
const grow = () => box("grow", []);

// ---- header ----------------------------------------------------------------------

// Each readout is a small label over a value, so five fit across the visor.
const ammo = (cls, icon, label, value, extra = {}) =>
  box(`ammo ${cls}`, [
    box("ammo-head", [img("ammo-icon", ui(icon)), text("ammo-label", label)]),
    text("num ammo-num", value),
  ], extra);

const header = box("header", [
  box("hazard-band", [box("band-cap", [text("band-text", "ZERO-OS // VISOR LINK")])]),
  box("header-body", [
    box("sector", [
      img("bracket-node node-l", ui("node")),
      text("sector-label", "SECTOR:"),
      text("sector-name", "{sector}"),
    ]),
    box("energy", [
      box("energy-read", [text("energy-label", "ENERGY"), text("num energy-num", "{energy}")]),
      box("battery", [
        list("tanks", "$tanks", box("tank", [], { classIf: { full: "$full" } })),
      ]),
    ]),
    ammo("ammo-m", "ic-missile", "M", "{missiles}/{missilesMax}"),
    ammo("ammo-sm", "ic-super", "S-M", "{supers}/{supersMax}"),
    ammo("ammo-pb", "ic-pbomb", "P-B", "{pbombs}/{pbombsMax}"),
    box("status-icons", [img("ic-signal", ui("ic-signal")), img("ic-battery", ui("ic-battery"))]),
  ]),
]);

// ---- dock --------------------------------------------------------------------------

const TABS = [
  ["map", "FULL MAP", "dock-map"],
  ["armory", "ARMORY", "dock-armory"],
  ["log", "LOGBOOK", "dock-log"],
];
const dock = (active) =>
  box("dock", [
    box("dock-title-row", [box("dock-rule", []), text("dock-title", "SUIT COMMAND DOCK"), box("dock-rule", [])]),
    box("dock-row", TABS.map(([page, label, icon]) =>
      button(`dock-btn dock-${page}${page === active ? " on" : ""}`, [{ navigate: page }], [
        box("dock-inner", [img("dock-icon", ui(icon)), text("dock-label", `[ ${label} ]`)]),
        ...(page === active
          ? [box("tap-badge", [text("tap-text", "TAP!")]), img("tap-hand", ui("hand"))]
          : []),
      ]),
    )),
  ]);

// ---- panels ------------------------------------------------------------------------

const RIVETS = ["tl", "tr", "bl", "br"];
const panel = (cls, title, body, chips = []) =>
  box(`panel ${cls}`, [
    box("banner", [img("banner-node", ui("node")), text("banner-text", title), grow(), ...chips]),
    box("panel-body", body),
    ...RIVETS.map((r) => img(`rivet rivet-${r}`, ui("rivet"))),
  ]);
const chip = (t, cls = "") => box(`chip ${cls}`.trim(), [text("chip-text", t)]);

// The area map: the image and its markers move together inside a clipped viewport
// (main.lua sets map.panX/panY to keep Samus in view; the engine has no drag).
const mapPan = (cls, pan) =>
  box(`map-pan ${cls}`.trim(), [
    img("map-img", "$map.image"),
    list("marks", "$map.marks", img("mark", "$icon", { bindStyle: { left: "{x}%", top: "{y}%" } })),
    box("samus-anchor", [img("crosshair", ui("crosshair")), img("samus", ui("mk-samus"))], {
      bindStyle: { left: "{map.x}%", top: "{map.y}%" },
      visibleIf: "$map.onMap",
    }),
  ], pan ? { bindStyle: { left: "{map.panX}px", top: "{map.panY}px" } } : {});

const pill = (t) => box("pill", [text("pill-text", t)]);

// ---- armory page (the guide's main screen) --------------------------------------------

const toggle = box(
  "toggle",
  [
    img("node-img node-on", ui("node-on"), { visibleIf: "$on" }),
    img("node-img", ui("node-off"), { visibleIf: "$off" }),
    img("node-img", ui("node-lock"), { visibleIf: "$locked" }),
    text("toggle-label", "{name}"),
  ],
  { classIf: { on: "$on", off: "$off", locked: "$locked" }, onClick: [{ call: "toggle", args: ["{id}"] }] },
);
const section = (t) => box("section", [text("section-text", t), box("section-rule", [])]);

const armoryPage = box("content cols-armory", [
  panel("map-panel", "INTERACTIVE MAP", [
    box("viewport", [
      mapPan("", true),
      box("coords", [text("coords-text", "{map.coords}")]),
      box("pills", [img("pill-hand", ui("hand")), box("pill-stack", [pill("STYLUS PAN MAP"), pill("TAP & DRAG")])]),
    ]),
  ], [chip("{map.area}", "chip-cyan")]),
  panel("armory-panel", "SUIT ARMORY MATRIX", [
    section("[BEAMS]"),
    list("toggle-grid", "$armory.beams", toggle),
    section("[SUIT / GEAR]"),
    list("toggle-grid", "$armory.gear", toggle),
    grow(),
    box("readout", [text("readout-caret", ">"), text("readout-text", "{armory.status}")]),
  ]),
]);

// ---- full map page --------------------------------------------------------------------

const legend = (icon, label) => box("legend-item", [img("legend-icon", ui(icon)), text("legend-text", label)]);
const mapPage = box("content cols-map", [
  panel("full-panel", "SECTOR MAP", [
    box("viewport viewport-full", [mapPan("pan-full", false)]),
    box("legend", [
      legend("lg-save", "SAVE"),
      legend("lg-door", "HATCH"),
      legend("lg-item", "ITEM"),
      legend("lg-hazard", "HAZARD"),
      legend("lg-boss", "BOSS"),
    ]),
    box("readout", [text("readout-caret", ">"), text("readout-text", "{map.status}")]),
  ], [chip("{map.items}", "chip-yellow")]),
  panel("sector-panel", "SECTORS", [
    list("sector-list", "$sectors", box("sector-row", [
      text("sector-row-name", "{name}"),
      box("sector-row-foot", [bar("sector-bar", "$pct"), text("num sector-pct", "{pctText}")]),
    ], { classIf: { here: "$here" } })),
  ]),
]);

// ---- logbook page ---------------------------------------------------------------------

const logPage = box("content cols-log", [
  panel("boss-panel", "TARGET LOG", [
    list("boss-list", "$log.bosses", box("boss", [
      img("boss-icon", ui("ic-skull")),
      text("boss-name", "{name}"),
      grow(),
      text("boss-area", "{area}"),
      box("boss-state", [text("boss-state-text", "{state}")]),
    ], { classIf: { done: "$done", alive: "$alive" } })),
  ], [chip("{log.bossCount}", "chip-magenta")]),
  box("log-side", [
    panel("item-panel", "ITEM RECOVERY", [
      list("item-list", "$log.items", box("item", [
        box("item-head", [img("item-icon", "$icon"), text("item-name", "{name}"), grow(), text("num item-count", "{got}/{max}")]),
        bar("item-bar", "$pct"),
      ], { classIf: { "kind-tank": "$tank", "kind-missile": "$missile", "kind-super": "$super", "kind-pbomb": "$pbomb" } })),
    ]),
    box("stat-row", [
      box("stat stat-pct", [text("stat-label", "COMPLETION"), text("num stat-num", "{log.completion}")]),
      box("stat stat-time", [box("stat-head", [img("stat-icon", ui("ic-clock")), text("stat-label", "MISSION TIME")]), text("num stat-num", "{log.time}")]),
    ]),
  ]),
]);

// ---- screen -----------------------------------------------------------------------------

const page = (name, content) => ({ name, child: box(`page page-${name}`, [content, dock(name)]) });

const layout = box("screen-root", [
  box("waiting", [
    box("boot", [
      box("boot-band", []),
      box("boot-body", [
        text("boot-title", "ZERO-OS"),
        text("boot-sub", "METROID: ZERO MISSION"),
        box("boot-pill", [text("boot-pill-text", "AWAITING SUIT SIGNAL...")]),
      ]),
      box("boot-band", []),
    ]),
  ], { visibleIf: "$waiting" }),
  box("shell", [
    header,
    {
      type: "pages",
      pages: [page("armory", armoryPage), page("map", mapPage), page("log", logPage)],
    },
  ], { visibleIf: "$ready" }),
], { id: "screen" });

fs.writeFileSync(new URL("../layout.json", import.meta.url), JSON.stringify(layout, null, 2) + "\n");
console.log("ok");
