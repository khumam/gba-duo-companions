// ENCHANTED FOREST ART KIT — copy to <pack>/art/build.mjs (art-kit-forest.mjs here).
//
// Keep: the primitives (leaf, fern, vine, glowDot, write, rnd) and the shared
// ornaments (forest, tab-leaf(-active), sprig-left/right, vine-left/right,
// garland, seal, firefly, acorn, emblem). Replace: the game icons (hearts,
// rupee, shell, bomb, arrow, bottle, kinstones, elements, keys) with the new
// game's own — draw originals, never trace game sprites.
//
// Sizes passed to write() are in dp; PNGs are rendered at SCALE (3x) so they
// stay sharp on the Thor. Seeded random keeps output identical between builds.
//
import { Resvg } from "@resvg/resvg-js";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const SVG_DIR = path.join(here, "svg");
const PNG_DIR = path.join(here, "..", "assets", "img");
const SCALE = 3;
fs.mkdirSync(SVG_DIR, { recursive: true });
fs.mkdirSync(PNG_DIR, { recursive: true });

const C = {
  night: "#06180F", canopy: "#0C2F22", deep: "#123F2C", moss: "#1E5A3A",
  leaf: "#3F8F4E", fresh: "#6DBA5A", lime: "#B5DC6E", glow: "#F2F7B0",
  gold: "#E8BE55", goldHi: "#FFE9A3", goldDeep: "#9C6F1C",
  parchment: "#F4EBD0", ink: "#2A2216", heart: "#E2363F", heartHi: "#FF8A8A",
};

// ---- primitives --------------------------------------------------------------

let uid = 0;
const id = (p) => `${p}${++uid}`;

const f = (n) => +n.toFixed(2);

// Leaf blade from (x, y) pointing at `angle` degrees (0 = up), `len` long.
function leaf(x, y, len, wid, angle, opt = {}) {
  const { from = C.leaf, to = C.fresh, rib = "rgba(255,255,255,0.35)", veins = true,
    opacity = 1, curl = 0, stroke = null } = opt;
  const g = id("lg");
  const L = len, W = wid, k = curl * L;
  const blade = `M0,0 C${f(W)},${f(-L * 0.18)} ${f(W * 1.05 + k)},${f(-L * 0.7)} ${f(k)},${f(-L)} ` +
    `C${f(-W * 1.05 + k)},${f(-L * 0.7)} ${f(-W)},${f(-L * 0.18)} 0,0 Z`;
  let v = "";
  if (veins) {
    for (let i = 1; i <= 5; i++) {
      const t = i / 6.2, yy = -L * t, xx = k * t * t;
      const span = W * Math.sin(Math.PI * Math.min(1, t * 1.15)) * 0.85;
      v += `<path d="M${f(xx)},${f(yy)} Q${f(xx + span * 0.6)},${f(yy - L * 0.05)} ${f(xx + span)},${f(yy - L * 0.12)}"/>`;
      v += `<path d="M${f(xx)},${f(yy)} Q${f(xx - span * 0.6)},${f(yy - L * 0.05)} ${f(xx - span)},${f(yy - L * 0.12)}"/>`;
    }
  }
  return `<defs><linearGradient id="${g}" x1="0" y1="1" x2="0.3" y2="0">` +
    `<stop offset="0" stop-color="${from}"/><stop offset="1" stop-color="${to}"/></linearGradient></defs>` +
    `<g transform="translate(${f(x)},${f(y)}) rotate(${f(angle)})" opacity="${opacity}">` +
    `<path d="${blade}" fill="url(#${g})"${stroke ? ` stroke="${stroke}" stroke-width="${f(L * 0.012 + 0.3)}"` : ""}/>` +
    `<path d="M0,0 Q${f(k * 0.5)},${f(-L * 0.5)} ${f(k)},${f(-L * 0.97)}" stroke="${rib}" stroke-width="${f(L * 0.025 + 0.2)}" fill="none" stroke-linecap="round"/>` +
    (veins ? `<g stroke="${rib}" stroke-width="${f(L * 0.012 + 0.15)}" fill="none" opacity="0.7" stroke-linecap="round">${v}</g>` : "") +
    `</g>`;
}

// Fern frond: leaflets along a quadratic spine from (x, y), shrinking to the tip.
function fern(x, y, len, angle, bend, opt = {}) {
  const { pairs = 14, size = 0.22, from = C.moss, to = C.leaf, opacity = 1, rib } = opt;
  let out = `<g transform="translate(${f(x)},${f(y)}) rotate(${f(angle)})" opacity="${opacity}">`;
  const cx = bend * len, cy = -len * 0.55, ex = bend * len * 0.6, ey = -len;
  const pt = (t) => [
    (1 - t) ** 2 * 0 + 2 * (1 - t) * t * cx + t * t * ex,
    (1 - t) ** 2 * 0 + 2 * (1 - t) * t * cy + t * t * ey,
  ];
  out += `<path d="M0,0 Q${f(cx)},${f(cy)} ${f(ex)},${f(ey)}" stroke="${from}" stroke-width="${f(len * 0.012 + 0.5)}" fill="none" stroke-linecap="round"/>`;
  for (let i = 0; i < pairs; i++) {
    const t = 0.08 + (i / pairs) * 0.9;
    const [px, py] = pt(t);
    const [qx, qy] = pt(Math.min(1, t + 0.01));
    const dir = Math.atan2(qx - px, -(qy - py)) * 180 / Math.PI;
    const s = len * size * (1 - t * 0.75);
    out += leaf(px, py, s, s * 0.32, dir - 62, { from, to, veins: false, rib: rib ?? "rgba(255,255,255,0.18)" });
    out += leaf(px, py, s, s * 0.32, dir + 62, { from, to, veins: false, rib: rib ?? "rgba(255,255,255,0.18)" });
  }
  out += leaf(ex, ey, len * size * 0.4, len * size * 0.13, Math.atan2(ex - cx, -(ey - cy)) * 180 / Math.PI, { from, to, veins: false });
  return out + `</g>`;
}

// Curling vine tendril: a spiral-ish curve with small leaves along it.
function vine(points, opt = {}) {
  const { color = C.gold, width = 1.2, leaves = [], opacity = 1 } = opt;
  let d = `M${points[0][0]},${points[0][1]}`;
  for (let i = 1; i < points.length; i++) {
    const p = points[i];
    d += p.length === 4 ? ` Q${p[0]},${p[1]} ${p[2]},${p[3]}` : ` L${p[0]},${p[1]}`;
  }
  let out = `<g opacity="${opacity}"><path d="${d}" stroke="${color}" stroke-width="${width}" fill="none" stroke-linecap="round"/>`;
  for (const l of leaves) out += leaf(...l);
  return out + `</g>`;
}

const glowDot = (x, y, r, color = C.glow, o = 1) => {
  const g = id("gd");
  return `<defs><radialGradient id="${g}"><stop offset="0" stop-color="${color}" stop-opacity="${0.55 * o}"/>` +
    `<stop offset="1" stop-color="${color}" stop-opacity="0"/></radialGradient></defs>` +
    `<circle cx="${f(x)}" cy="${f(y)}" r="${f(r * 4.5)}" fill="url(#${g})"/>` +
    `<circle cx="${f(x)}" cy="${f(y)}" r="${f(r)}" fill="${color}" opacity="${o}"/>`;
};

// Seeded random so the art is the same every build.
let seed = 7;
const rnd = () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;

function write(name, w, h, body, defs = "") {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">` +
    `<defs>${defs}</defs>${body}</svg>`;
  fs.writeFileSync(path.join(SVG_DIR, `${name}.svg`), svg);
  const png = new Resvg(svg, { fitTo: { mode: "width", value: Math.round(w * SCALE) } }).render().asPng();
  fs.writeFileSync(path.join(PNG_DIR, `${name}.png`), png);
  console.log(`${name}.png  ${w}x${h}dp  ${(png.length / 1024).toFixed(1)}kB`);
}

// ---- background: the forest floor seen from Minish height --------------------

{
  const W = 400, H = 460;
  let b = `<rect width="${W}" height="${H}" fill="url(#sky)"/>`;
  // shafts of light through the canopy
  for (const [x, w, o] of [[40, 70, 0.07], [150, 40, 0.05], [250, 90, 0.06], [330, 30, 0.04]]) {
    b += `<polygon points="${x},0 ${x + w},0 ${x + w + 160},${H} ${x + 110},${H}" fill="url(#shaft)" opacity="${o * 1.6}"/>`;
  }
  // far layer: huge soft leaves
  b += `<g opacity="0.55">`;
  b += leaf(-30, 300, 260, 70, 38, { from: "#0A271C", to: "#113626", veins: false, rib: "rgba(255,255,255,0.04)" });
  b += leaf(430, 260, 240, 64, -42, { from: "#0A271C", to: "#123A29", veins: false, rib: "rgba(255,255,255,0.04)" });
  b += leaf(200, 520, 300, 90, 4, { from: "#09231A", to: "#0F3124", veins: false, rib: "rgba(255,255,255,0.04)" });
  b += `</g>`;
  // mid layer: ferns from the edges
  b += fern(-10, 470, 300, 20, 0.28, { from: "#0F3A28", to: "#17503A", opacity: 0.9 });
  b += fern(410, 480, 320, -24, -0.3, { from: "#0F3A28", to: "#17503A", opacity: 0.9 });
  b += fern(-20, 200, 200, 70, 0.3, { from: "#0F3626", to: "#164A34", opacity: 0.7, pairs: 11 });
  b += fern(420, 150, 190, -75, -0.3, { from: "#0F3626", to: "#164A34", opacity: 0.7, pairs: 11 });
  // near layer: the giant leaf over the top corners, veins lit
  b += leaf(-18, -30, 190, 62, 128, { from: "#1B5A38", to: "#2F7D46", rib: "rgba(214,240,160,0.35)", curl: 0.08 });
  b += leaf(418, -26, 170, 56, -132, { from: "#1B5A38", to: "#2F7D46", rib: "rgba(214,240,160,0.35)", curl: -0.08 });
  b += leaf(60, -20, 110, 30, 165, { from: "#164B30", to: "#2A6E40", rib: "rgba(214,240,160,0.25)" });
  b += leaf(345, -22, 100, 28, -168, { from: "#164B30", to: "#2A6E40", rib: "rgba(214,240,160,0.25)" });
  // grass blades along the floor
  for (let i = 0; i < 46; i++) {
    const x = (i / 45) * W + (rnd() - 0.5) * 10;
    const len = 30 + rnd() * 60;
    b += leaf(x, H + 4, len, 3 + rnd() * 3, (rnd() - 0.5) * 30, {
      from: "#0B2C1D", to: i % 3 ? "#1C5A36" : "#2A7445", veins: false, rib: "rgba(255,255,255,0.08)", curl: (rnd() - 0.5) * 0.3,
    });
  }
  // fireflies and spores
  for (let i = 0; i < 26; i++) b += glowDot(rnd() * W, 40 + rnd() * (H - 80), 0.8 + rnd() * 1.1, i % 4 ? C.glow : "#C6F08A", 0.6 + rnd() * 0.4);
  for (let i = 0; i < 70; i++) b += `<circle cx="${f(rnd() * W)}" cy="${f(rnd() * H)}" r="${f(0.3 + rnd() * 0.5)}" fill="#E8F5C8" opacity="${f(0.12 + rnd() * 0.2)}"/>`;
  // vignette top and bottom so the tabs and the floor read
  b += `<rect width="${W}" height="${H}" fill="url(#vig)"/>`;
  write("forest", W, H, b,
    `<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0B2A1F"/>` +
    `<stop offset="0.45" stop-color="${C.canopy}"/><stop offset="1" stop-color="${C.night}"/></linearGradient>` +
    `<linearGradient id="shaft" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF6C8"/>` +
    `<stop offset="1" stop-color="#FFF6C8" stop-opacity="0"/></linearGradient>` +
    `<linearGradient id="vig" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity="0.35"/>` +
    `<stop offset="0.15" stop-color="#000" stop-opacity="0"/><stop offset="0.85" stop-color="#000" stop-opacity="0"/>` +
    `<stop offset="1" stop-color="#000" stop-opacity="0.45"/></linearGradient>`);
}

// ---- tabs: a leaf each, lit gold when selected --------------------------------

for (const [name, from, to, rib, edge] of [
  ["tab-leaf", "#1D5A3A", "#2E7C4A", "rgba(214,240,160,0.4)", "#0B2A1C"],
  ["tab-leaf-active", "#C48A22", "#F5D27A", "rgba(255,250,220,0.8)", "#7A5414"],
]) {
  const W = 110, H = 38;
  let b = `<g transform="translate(${W / 2},${H / 2}) rotate(90)">`;
  b += leaf(0, 52, 104, 17, 0, { from, to, rib, stroke: edge });
  b += `</g>`;
  write(name, W, H, b);
}

// ---- corner sprigs and vine dividers -----------------------------------------

function sprig(mirror) {
  const W = 70, H = 46;
  let b = `<g transform="${mirror ? `translate(${W},0) scale(-1,1)` : ""}">`;
  b += vine([[4, 40], [10, 10, 34, 8], [50, 7, 58, 16], [62, 24, 54, 26], [48, 26, 50, 20]], { color: C.gold, width: 1.4 });
  b += leaf(6, 40, 34, 10, 20, { from: "#2C7442", to: C.fresh, rib: "rgba(255,255,255,0.45)", stroke: "#164428" });
  b += leaf(8, 40, 28, 8, 62, { from: "#2C7442", to: C.lime, rib: "rgba(255,255,255,0.45)", stroke: "#164428" });
  b += leaf(26, 10, 18, 6, 70, { from: "#B98423", to: C.goldHi, rib: "rgba(255,255,255,0.5)", veins: false });
  b += leaf(40, 8, 15, 5, 120, { from: "#2C7442", to: C.lime, rib: "rgba(255,255,255,0.4)", veins: false });
  b += `<circle cx="22" cy="25" r="3.2" fill="url(#berry)"/><circle cx="17" cy="30" r="2.4" fill="url(#berry)"/>`;
  b += `</g>`;
  return [W, H, b, `<radialGradient id="berry" cx="0.35" cy="0.35"><stop offset="0" stop-color="#FFE9A3"/><stop offset="1" stop-color="#C0391B"/></radialGradient>`];
}
write("sprig-left", ...sprig(false));
write("sprig-right", ...sprig(true));

function divider(mirror) {
  const W = 120, H = 18;
  let b = `<g transform="${mirror ? `translate(${W},0) scale(-1,1)` : ""}">`;
  b += `<path d="M2,9 C30,3 60,15 116,9" stroke="url(#fade)" stroke-width="1.3" fill="none" stroke-linecap="round"/>`;
  for (let i = 0; i < 6; i++) {
    const x = 30 + i * 15, up = i % 2 === 0;
    b += leaf(x, 9 + (up ? -1 : 1), 9 - i * 0.4 + 3, 2.8, up ? -40 : -140 + 180, { from: "#B98423", to: C.goldHi, veins: false, rib: "rgba(255,255,255,0.5)" });
  }
  b += `<path d="M116,9 m-3,0 a3,3 0 1,0 6,0 a3,3 0 1,0 -6,0" fill="${C.gold}"/>`;
  b += `</g>`;
  return [W, H, b, `<linearGradient id="fade"><stop offset="0" stop-color="${C.gold}" stop-opacity="0"/><stop offset="1" stop-color="${C.gold}"/></linearGradient>`];
}
write("vine-left", ...divider(false));
write("vine-right", ...divider(true));

// Under the hero card: a garland that hangs from the tab bar.
{
  const W = 360, H = 30;
  let b = `<path d="M0,6 Q90,30 180,14 T360,6" stroke="${C.gold}" stroke-width="1.2" fill="none" opacity="0.8"/>`;
  for (let i = 0; i < 24; i++) {
    const t = i / 23, x = t * 360;
    const y = 6 + Math.sin(t * Math.PI * 2) * -4 + Math.sin(t * Math.PI) * 12;
    b += leaf(x, y, 9 + (i % 3) * 2, 3, (i % 2 ? 150 : 210) + (rnd() - 0.5) * 30,
      { from: i % 5 === 0 ? "#B98423" : "#2C7442", to: i % 5 === 0 ? C.goldHi : C.lime, veins: false, rib: "rgba(255,255,255,0.4)" });
  }
  write("garland", W, H, b);
}

// ---- hearts --------------------------------------------------------------------

const HEART = "M12,21 C5,15 1,11 1,6.5 C1,3.3 3.5,1 6.5,1 C8.8,1 10.6,2.3 12,4.3 C13.4,2.3 15.2,1 17.5,1 C20.5,1 23,3.3 23,6.5 C23,11 19,15 12,21 Z";
// Zelda-style quarters: bottom-left, top-left, top-right, bottom-right.
const QUAD = ["M0,11 H12 V24 H0 Z", "M0,0 H12 V11 H0 Z", "M12,0 H24 V11 H12 Z", "M12,11 H24 V24 H12 Z"];
for (let q = 0; q <= 4; q++) {
  const name = ["heart-0", "heart-1", "heart-2", "heart-3", "heart-4"][q];
  let b = `<path d="${HEART}" fill="#3A1418" stroke="#120607" stroke-width="1.6"/>`;
  if (q > 0) {
    b += `<clipPath id="c${q}"><path d="${QUAD.slice(0, q).join(" ")}"/></clipPath>`;
    b += `<g clip-path="url(#c${q})"><path d="${HEART}" fill="url(#hr)"/>` +
      `<path d="M5,4.5 C6.5,3.5 8.5,4 9,5.5" stroke="#FFE1E1" stroke-width="1.6" fill="none" stroke-linecap="round" opacity="0.9"/></g>`;
  }
  b += `<path d="${HEART}" fill="none" stroke="${C.goldHi}" stroke-width="0.7" opacity="0.65"/>`;
  write(name, 24, 22, b, `<linearGradient id="hr" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${C.heartHi}"/><stop offset="0.5" stop-color="${C.heart}"/><stop offset="1" stop-color="#8F1520"/></linearGradient>`);
}

// ---- treasure icons ------------------------------------------------------------

const facetGem = (name, top, mid, low, w = 20, h = 30) => {
  const p = `M${w / 2},1 L${w - 2},${h * 0.28} L${w - 2},${h * 0.72} L${w / 2},${h - 1} L2,${h * 0.72} L2,${h * 0.28} Z`;
  let b = `<path d="${p}" fill="${mid}" stroke="#0B2216" stroke-width="1.2" stroke-linejoin="round"/>`;
  b += `<path d="M${w / 2},${h * 0.2} L${w * 0.72},${h * 0.34} L${w * 0.72},${h * 0.66} L${w / 2},${h * 0.8} L${w * 0.28},${h * 0.66} L${w * 0.28},${h * 0.34} Z" fill="${top}"/>`;
  b += `<path d="M${w / 2},1 L${w / 2},${h * 0.2} M${w - 2},${h * 0.28} L${w * 0.72},${h * 0.34} M${w - 2},${h * 0.72} L${w * 0.72},${h * 0.66} M${w / 2},${h - 1} L${w / 2},${h * 0.8} M2,${h * 0.72} L${w * 0.28},${h * 0.66} M2,${h * 0.28} L${w * 0.28},${h * 0.34}" stroke="${low}" stroke-width="0.8"/>`;
  b += `<path d="M${w * 0.36},${h * 0.3} L${w * 0.5},${h * 0.24} L${w * 0.5},${h * 0.42} Z" fill="#fff" opacity="0.75"/>`;
  write(name, w, h, b);
};
facetGem("rupee", "#8EF2A6", "#2FB860", "#14612F");

{ // spiral seashell
  let b = `<path d="M3,22 C2,12 9,3 17,4 C24,5 26,13 22,18 C19,22 13,22 11,18 C9,14 13,11 16,13" fill="url(#sh)" stroke="#6B3A45" stroke-width="1.2" stroke-linecap="round"/>`;
  b += `<path d="M3,22 C9,24 17,24 23,20" fill="none" stroke="#6B3A45" stroke-width="1.2" stroke-linecap="round"/>`;
  b += `<path d="M8,10 L13,20 M12,6 L15,18 M18,5 L17,16" stroke="#B9707F" stroke-width="0.8" opacity="0.8"/>`;
  write("shell", 26, 26, b, `<linearGradient id="sh" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFF1E8"/><stop offset="1" stop-color="#E7A3B4"/></linearGradient>`);
}

{ // bomb
  let b = `<circle cx="12" cy="15" r="9" fill="url(#bm)" stroke="#0B1020" stroke-width="1.2"/>`;
  b += `<rect x="9.5" y="4.5" width="5" height="3.5" rx="1" fill="#59647A" stroke="#0B1020" stroke-width="0.9"/>`;
  b += `<path d="M12,4.5 Q13,1 17,2" stroke="#C9A36A" stroke-width="1.3" fill="none"/>`;
  b += glowDot(17.5, 2, 1.2, "#FFD45C");
  b += `<ellipse cx="8.5" cy="11.5" rx="2.6" ry="1.6" fill="#fff" opacity="0.45" transform="rotate(-30 8.5 11.5)"/>`;
  write("bomb", 24, 26, b, `<radialGradient id="bm" cx="0.35" cy="0.35"><stop offset="0" stop-color="#5E7BB0"/><stop offset="1" stop-color="#18213A"/></radialGradient>`);
}

{ // arrow with leaf fletching
  let b = `<path d="M4,22 L20,6" stroke="#8C5A2B" stroke-width="2" stroke-linecap="round"/>`;
  b += `<path d="M20,6 L14,7.5 L22,2 L18.5,10 Z" fill="#D9E2E8" stroke="#3C4650" stroke-width="0.8" stroke-linejoin="round"/>`;
  b += leaf(5.5, 20.5, 8, 2.6, -110, { from: "#2C7442", to: C.lime, veins: false });
  b += leaf(5.5, 20.5, 8, 2.6, -160, { from: "#2C7442", to: C.lime, veins: false });
  write("arrow", 24, 24, b);
}

{ // glass bottle
  let b = `<path d="M9,2 H15 V7 C19,9 21,12 21,16 C21,21 17,24 12,24 C7,24 3,21 3,16 C3,12 5,9 9,7 Z" fill="rgba(200,235,255,0.35)" stroke="#D8F0FF" stroke-width="1.2"/>`;
  b += `<path d="M5,16 C5,20 8,22.5 12,22.5 C16,22.5 19,20 19,16 Z" fill="#6EC6E8" opacity="0.8"/>`;
  b += `<rect x="8.5" y="0.8" width="7" height="3" rx="1" fill="#A3713A"/>`;
  b += `<path d="M7,11 C6,13 6,15 6.5,16" stroke="#fff" stroke-width="1.2" fill="none" opacity="0.8" stroke-linecap="round"/>`;
  write("bottle", 24, 26, b);
}

// ---- kinstone halves -----------------------------------------------------------

for (const [color, light, dark] of [
  ["gold", "#FFF0B0", "#B5841E"], ["red", "#FFB3A8", "#B02A2A"],
  ["blue", "#B8D4FF", "#2950B3"], ["green", "#C8F0A8", "#2C8A3C"],
]) {
  // left half of a medallion, split down a zigzag
  const zig = "M20,2 L16,8 L22,13 L15,19 L21,25 L17,31 L20,38";
  let b = `<path d="${zig} A18,18 0 0,1 20,2 Z" fill="url(#k)" stroke="#20160A" stroke-width="1.2" stroke-linejoin="round"/>`;
  b += `<path d="M14,10 C8,12 7,20 11,24 C14,27 17,24 15,21" fill="none" stroke="${light}" stroke-width="1.6" stroke-linecap="round" opacity="0.9"/>`;
  b += `<circle cx="9" cy="14" r="1.2" fill="${light}"/>`;
  b += `<path d="M8,6 C5,9 4,12 4.5,15" stroke="#fff" stroke-width="1.4" fill="none" opacity="0.6" stroke-linecap="round"/>`;
  write(`kinstone-${color}`, 24, 40, b, `<linearGradient id="k" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${light}"/><stop offset="0.55" stop-color="${dark}"/><stop offset="1" stop-color="#1C140A"/></linearGradient>`);
}

// ---- elements: gems in a leaf socket -------------------------------------------

function socket(inner) {
  let b = "";
  for (let i = 0; i < 6; i++) {
    b += leaf(24, 24, 22, 6.5, i * 60 + 30, { from: "#1E5A3A", to: "#4E9A55", veins: false, rib: "rgba(255,255,255,0.25)", stroke: "#0B2A1C" });
  }
  b += `<circle cx="24" cy="24" r="13" fill="url(#rim)" stroke="#5E400F" stroke-width="1"/>`;
  b += `<circle cx="24" cy="24" r="10.5" fill="#10241A"/>`;
  return b + inner;
}
const RIM = `<linearGradient id="rim" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${C.goldHi}"/><stop offset="1" stop-color="${C.goldDeep}"/></linearGradient>`;
const ELEMENTS = {
  earth: ["#E7D79A", "#8AA23A", "#3E5A1C", `<path d="M24,16 C29,20 29,27 24,31 C19,27 19,20 24,16 Z M24,18 V30" fill="#E8F5C0" stroke="#3E5A1C" stroke-width="0.8" opacity="0.9"/>`],
  fire: ["#FFE08A", "#F26A21", "#7A1A0C", `<path d="M24,31 C19,30 18,25 21,21 C21,24 23,24 23,24 C22,20 24,17 27,15 C26,19 30,21 29,26 C29,29 27,31 24,31 Z" fill="#FFF0B8" opacity="0.92"/>`],
  water: ["#C8F0FF", "#2F8FE0", "#0C2E6B", `<path d="M24,15 C27,20 30,23 30,26 C30,29.5 27.3,32 24,32 C20.7,32 18,29.5 18,26 C18,23 21,20 24,15 Z" fill="#E8FAFF" opacity="0.9"/>`],
  wind: ["#E9FFF4", "#62C9A8", "#1C5A4C", `<path d="M16,21 H27 C30,21 30,17 27.5,17 M16,25 H30 C33,25 33,29.5 30,29.5 M18,28.5 H24" stroke="#F4FFFA" stroke-width="1.6" fill="none" stroke-linecap="round"/>`],
};
for (const [name, [hi, mid, lo, glyph]] of Object.entries(ELEMENTS)) {
  const gem = `<circle cx="24" cy="24" r="10" fill="url(#gem)"/>${glyph}<ellipse cx="20.5" cy="19.5" rx="3" ry="1.8" fill="#fff" opacity="0.55" transform="rotate(-35 20.5 19.5)"/>`;
  write(`element-${name}`, 48, 48, socket(gem), RIM + `<radialGradient id="gem" cx="0.38" cy="0.35"><stop offset="0" stop-color="${hi}"/><stop offset="0.55" stop-color="${mid}"/><stop offset="1" stop-color="${lo}"/></radialGradient>`);
}
write("element-empty", 48, 48, socket(`<circle cx="24" cy="24" r="4" fill="#1E3A2A"/>`), RIM);

// ---- dungeon treasures ---------------------------------------------------------

const GOLD_GRAD = `<linearGradient id="gg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${C.goldHi}"/><stop offset="1" stop-color="${C.goldDeep}"/></linearGradient>`;
write("key", 22, 22, `<circle cx="7" cy="7" r="4.6" fill="none" stroke="url(#gg)" stroke-width="2.4"/>` +
  `<path d="M10.5,10.5 L19,19 M15.5,15.5 L18,13 M17.5,17.5 L20,15" stroke="url(#gg)" stroke-width="2.4" stroke-linecap="round"/>`, GOLD_GRAD);
write("big-key", 22, 22, `<path d="M7,1.5 L10.5,4 L10.5,8 L7,10.5 L3.5,8 L3.5,4 Z" fill="url(#gg)" stroke="#5E400F" stroke-width="0.8"/>` +
  `<circle cx="7" cy="6" r="1.6" fill="#C0391B"/>` +
  `<path d="M9.5,9.5 L19.5,19.5 M14,14 L17.5,10.5 M17,17 L20.5,13.5 M15.5,12.5 L18,15" stroke="url(#gg)" stroke-width="2.6" stroke-linecap="round"/>`, GOLD_GRAD);
write("map", 22, 22, `<path d="M2,4 L8,2 L14,4 L20,2 V18 L14,20 L8,18 L2,20 Z" fill="#F1E0B0" stroke="#7A5A2A" stroke-width="1" stroke-linejoin="round"/>` +
  `<path d="M8,2 V18 M14,4 V20" stroke="#C4A86A" stroke-width="0.8"/>` +
  `<path d="M4,13 C7,9 10,14 13,10 C15,8 17,9 18,7" stroke="#C0391B" stroke-width="1.1" fill="none" stroke-dasharray="1.6 1.2"/>`);
write("compass", 22, 22, `<circle cx="11" cy="11" r="9" fill="url(#gg)" stroke="#5E400F" stroke-width="0.9"/>` +
  `<circle cx="11" cy="11" r="6.6" fill="#F4EBD0"/>` +
  `<path d="M11,5 L13,11 L11,17 L9,11 Z" fill="#C0391B"/><path d="M11,11 L13,11 L11,17 L9,11 Z" fill="#3A3A48"/>`, GOLD_GRAD);

// cleared seal: a laurel of gold leaves
{
  let b = "";
  for (let i = 0; i < 9; i++) {
    const a = (-140 + i * 17) * Math.PI / 180;
    b += leaf(20 + Math.cos(a) * 13, 20 + Math.sin(a) * 13, 8, 2.8, (a * 180 / Math.PI) + 90 - 35, { from: "#B98423", to: C.goldHi, veins: false });
    const a2 = (-40 - i * 17) * Math.PI / 180;
    b += leaf(20 + Math.cos(a2) * 13, 20 + Math.sin(a2) * 13, 8, 2.8, (a2 * 180 / Math.PI) + 90 + 35, { from: "#B98423", to: C.goldHi, veins: false });
  }
  b += `<path d="M14,20 L18.5,24.5 L27,15" stroke="${C.goldHi}" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
  write("seal", 40, 40, b);
}

// "you are here": a firefly lantern
write("firefly", 24, 24, glowDot(12, 12, 3.4, C.glow) + `<circle cx="12" cy="12" r="2" fill="#fff"/>`);

// A/B button: an acorn cap holding the letter
{
  let b = `<circle cx="17" cy="19" r="13" fill="url(#ac)" stroke="#3A230C" stroke-width="1.4"/>`;
  b += `<path d="M4,15 C6,6 28,6 30,15 C26,12 8,12 4,15 Z" fill="#6E4A22" stroke="#3A230C" stroke-width="1.2"/>`;
  b += `<path d="M8,11 L10,13 M12,9.5 L13.5,12 M17,9 L17,11.5 M22,9.5 L20.5,12 M26,11 L24,13" stroke="#9C7340" stroke-width="1"/>`;
  b += `<path d="M17,6 C17,3 19,2 21,2" stroke="#3A230C" stroke-width="1.6" fill="none" stroke-linecap="round"/>`;
  b += leaf(20, 3, 9, 3, 60, { from: "#2C7442", to: C.lime, veins: false });
  write("acorn", 34, 34, b, `<linearGradient id="ac" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#E9B866"/><stop offset="1" stop-color="#9C5E22"/></linearGradient>`);
}

// ---- waiting screen emblem: a leaf wreath around the four elements --------------

{
  const W = 220, R = 82;
  let b = glowDot(110, 110, 12, "#E9F5A0", 0.35);
  // two wreath branches meeting at the bottom, every leaf following the ring
  b += `<circle cx="110" cy="110" r="${R}" fill="none" stroke="#5E400F" stroke-width="2"/>`;
  b += `<circle cx="110" cy="110" r="${R}" fill="none" stroke="${C.gold}" stroke-width="1"/>`;
  for (const side of [1, -1]) {
    for (let i = 0; i < 16; i++) {
      const deg = 90 + side * (18 + i * 9.6);           // walk up from the bottom
      const a = deg * Math.PI / 180;
      const out = i % 2 ? 1 : -1;
      const r = R + out * 3;
      const tangent = deg + (side > 0 ? 0 : 180);       // point along the ring, towards the top
      const s = 24 - i * 0.55;
      const gold = i % 4 === 2;
      b += leaf(110 + Math.cos(a) * r, 110 + Math.sin(a) * r, s, s * 0.3,
        tangent + out * 32 * side,
        { from: gold ? "#B98423" : "#1E5A3A", to: gold ? C.goldHi : C.fresh, rib: "rgba(255,255,255,0.4)", stroke: "#0B2A1C" });
    }
  }
  b += `<circle cx="110" cy="${110 + R}" r="5" fill="url(#gg)" stroke="#5E400F" stroke-width="1"/>`;
  b += `<circle cx="110" cy="110" r="${R - 14}" fill="none" stroke="${C.gold}" stroke-width="1.2" opacity="0.8"/>`;
  b += `<circle cx="110" cy="110" r="${R - 20}" fill="none" stroke="${C.gold}" stroke-width="0.6" opacity="0.5" stroke-dasharray="2 4"/>`;
  const orb = (x, y, hi, mid, lo) => {
    const g = id("eo");
    return `<defs><radialGradient id="${g}" cx="0.38" cy="0.35"><stop offset="0" stop-color="${hi}"/><stop offset="0.6" stop-color="${mid}"/><stop offset="1" stop-color="${lo}"/></radialGradient></defs>` +
      glowDot(x, y, 4, mid, 0.5) + `<circle cx="${x}" cy="${y}" r="9" fill="url(#${g})" stroke="${C.goldDeep}" stroke-width="1"/>`;
  };
  b += orb(110, 66, ...ELEMENTS.earth.slice(0, 3)) + orb(154, 110, ...ELEMENTS.fire.slice(0, 3)) +
    orb(110, 154, ...ELEMENTS.water.slice(0, 3)) + orb(66, 110, ...ELEMENTS.wind.slice(0, 3));
  // a sword planted in the middle
  b += `<path d="M110,82 L113,88 L113,120 L110,124 L107,120 L107,88 Z" fill="url(#blade)" stroke="#2A3440" stroke-width="0.8"/>`;
  b += `<path d="M110,90 V118" stroke="#C9D6E2" stroke-width="0.8"/>`;
  b += `<path d="M99,120 C104,117 116,117 121,120 L119,124 C114,122 106,122 101,124 Z" fill="url(#gg)" stroke="#5E400F" stroke-width="0.8"/>`;
  b += `<rect x="108" y="123" width="4" height="10" rx="1.5" fill="#5A3A8A"/>`;
  b += `<circle cx="110" cy="135" r="2.8" fill="url(#gg)" stroke="#5E400F" stroke-width="0.6"/>`;
  for (let i = 0; i < 10; i++) b += glowDot(110 + (rnd() - 0.5) * 150, 110 + (rnd() - 0.5) * 150, 0.9 + rnd(), C.glow, 0.8);
  write("emblem", W, W, b, GOLD_GRAD + `<linearGradient id="blade" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#F4FAFF"/><stop offset="1" stop-color="#8FA3B8"/></linearGradient>`);
}
