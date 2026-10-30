// Writes layout.json for the Fusion pack: the game's own status and map screens, drawn
// from the player's ROM by main.lua (gfx.tilemap), with the numbers and names set in the
// game's font. Every page is a nav plus a 24-tile-row stage, so it fills the Thor's screen.
//
//   node art/layout.mjs

import fs from "node:fs";

const box = (cls, children, extra = {}) => ({ type: "box", class: cls, children, ...extra });
const img = (cls, src, extra = {}) => ({ type: "image", class: cls, src, ...extra });
const list = (cls, items, template, extra = {}) => ({ type: "list", class: cls, items, template, ...extra });
const button = (cls, onClick, children, extra = {}) => ({ type: "button", class: cls, onClick, children, ...extra });

const text = (cls, t, extra = {}) => ({ type: "text", class: cls, text: t, ...extra });
const glyph = () => img("g", "$src");                                // the header's numbers stay in the game's own digits
// A label over a value, from { label, value } items.
const stats = (cls, items) => list(cls, items, box("stat", [text("stat-label", "{label}"), text("stat-value", "{value}")]));

// ---- nav: plain rounded rectangles, at the bottom of every page ---------------------------------------------------

const TABS = [["status", "STATUS"], ["arms", "ARMS"], ["map", "MAP"]];
const nav = (active) =>
  box("nav", TABS.map(([page, label]) =>
    button(`tab${page === active ? " on" : ""}`, [{ navigate: page }], [text("tab-label", label)]),
  ));

// ---- shared pieces ---------------------------------------------------------------------

// The status screen's header with the three counters filled in over its placeholder digits.
const header = () =>
  box("hdr", [
    img("header", "$art.header"),
    list("num n-energy-now", "$energyNow", glyph()),
    list("num n-energy-max", "$energyMax", glyph()),
    list("num n-missile-now", "$missileNow", glyph()),
    list("num n-missile-max", "$missileMax", glyph()),
    list("num n-bomb-now", "$bombNow", glyph()),
    list("num n-bomb-max", "$bombMax", glyph()),
  ]);

// The bottom bar: the lace goes on down both sides and the map frame's steel runs between.
const botbar = () => box("botbar", [img("frame2", "$art.sideL"), img("botmid", "$art.botmid"), img("frame2", "$art.sideR")]);

// The status lace for pages that have no body of their own, from under the header to the bottom bar.
const lace = (side) =>
  box(`lace lace-${side}`, [img("frame", `$art.frame${side === "l" ? "L" : "R"}`), img("frame2", `$art.side${side === "l" ? "L" : "R"}`)]);

// ---- STATUS ------------------------------------------------------------------------------

const status = box("stage", [
  header(),
  box("body", [
    img("frame", "$art.frameL"),
    stats("side side-left", "$left"),
    img("center", "$art.center"),
    stats("side side-right", "$right"),
    img("frame", "$art.frameR"),
  ]),
  box("info", [
    img("frame2", "$art.sideL"),
    list("info-text", "$hatches", box("hatch", [text("hatch-name", "{name}"), text("hatch-state", "{state}")], { classIf: { open: "$open" } })),
    img("frame2", "$art.sideR"),
  ]),
  botbar(),
]);

// ---- ARMS: the item windows, lit by what Samus has ----------------------------------------------

const win = (id) =>
  box(`win w-${id}`, [
    img("w-title", `$windows.${id}.title`),
    list("w-rows", `$windows.${id}.rows`, img("w-row", "$src", { classIf: { owned: "$owned" } })),
    img("w-foot", `$windows.${id}.footer`),
  ]);

const arms = box("stage", [
  header(),
  box("arms", ["beam", "missile", "suit", "misc", "bomb"].map(win)),
  lace("l"),
  lace("r"),
  botbar(),
]);

// ---- MAP: the pause screen's frame around the live minimap -----------------------------------------

const map = box("stage", [
  box("map", [
    img("outline", "$art.outline"),
    box("cover cover-l", []),
    box("cover cover-r", []),
    img("minimap", "$art.map"),
    box("marker", [], { bindStyle: { "--mx": "{markCol}px", "--my": "{markRow}px" } }),
    text("plate", "{sectorName}"),
  ]),
  list("map-info", "$sectorRows", box("sector", [
    text("sector-name", "{name}"),
    text("sector-pct", "{pct}"),
  ], { classIf: { here: "$here", mapped: "$mapped" } })),
]);

// ---- screen --------------------------------------------------------------------------------------------

const page = (name, content) => ({ name, child: box(`page page-${name}`, [content, nav(name)]) });

const layout = box("screen", [
  box("waiting", [box("wait", [
    img("wait-logo", "$waitLogo", { visibleIf: "$hasLogo" }),
    text("wait-title", "{waitTitle}", { visibleIf: "$noLogo" }),
    text("wait-sub", "{waitSub}"),
  ])], { visibleIf: "$waiting" }),
  box("shell", [{ type: "pages", pages: [page("status", status), page("arms", arms), page("map", map)] }], { visibleIf: "$ready" }),
], { id: "screen", classIf: { alert: "$lowHealth" } });

fs.writeFileSync(new URL("../layout.json", import.meta.url), JSON.stringify(layout, null, 2) + "\n");
console.log("wrote layout.json");
