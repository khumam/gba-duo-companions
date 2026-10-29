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

const glyph = () => img("g", "$src");
const row = (items) => list("line", items, glyph());                 // one text line from a glyph array
const lines = (cls, items) => list(cls, items, list("line", "$g", glyph())); // lines of such arrays

// ---- nav: plain rounded rectangles, at the bottom of every page ---------------------------------------------------

const TABS = [["status", "$nav.status"], ["arms", "$nav.arms"], ["map", "$nav.map"]];
const nav = (active) =>
  box("nav", TABS.map(([page, glyphs]) =>
    button(`tab${page === active ? " on" : ""}`, [{ navigate: page }], [row(glyphs)]),
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

const botbar = () => img("botbar", "$art.botbar");

// ---- STATUS ------------------------------------------------------------------------------

const status = box("stage", [
  header(),
  box("body", [
    img("frame", "$art.frameL"),
    lines("side side-left", "$left"),
    img("center", "$art.center"),
    lines("side side-right", "$right"),
    img("frame", "$art.frameR"),
  ]),
  box("info", [img("frame2", "$art.sideL"), lines("info-text", "$hatchRows"), img("frame2", "$art.sideR")]),
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
  lines("arms-info", "$armsInfo"),
  botbar(),
]);

// ---- MAP: the pause screen's frame around the live minimap -----------------------------------------

const map = box("stage", [
  box("map", [
    img("outline", "$art.outline"),
    img("minimap", "$art.map"),
    box("marker", [], { bindStyle: { "--mx": "{markCol}px", "--my": "{markRow}px" } }),
    list("plate", "$sectorName", glyph()),
  ]),
  lines("map-info", "$sectorRows"),
]);

// ---- screen --------------------------------------------------------------------------------------------

const page = (name, content) => ({ name, child: box(`page page-${name}`, [content, nav(name)]) });

const layout = box("screen", [
  box("waiting", [lines("wait", "$wait")], { visibleIf: "$waiting" }),
  box("shell", [{ type: "pages", pages: [page("status", status), page("arms", arms), page("map", map)] }], { visibleIf: "$ready" }),
], { id: "screen", classIf: { alert: "$lowHealth" } });

fs.writeFileSync(new URL("../layout.json", import.meta.url), JSON.stringify(layout, null, 2) + "\n");
console.log("wrote layout.json");
