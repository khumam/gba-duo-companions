// Draws the Metroid Fusion pack's art as SVG and renders it to PNG (GBADuo
// decodes bitmaps only). "BSL Bio-Interface": the research station's HUD over
// SR388, with X parasites drifting past. Built on the enchanted-forest art
// kit's primitives (glow, seeded random, write) plus hex plates, holo brackets
// and wobbly X cells. Original art, nothing from the game.
//
//   npm i @resvg/resvg-js && node art/build.mjs
//
// Writes art/svg/*.svg and assets/img/*.png at SCALE x the size the stylesheet
// draws them.

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

const CYAN = "#4FE6FF", CYAN_LO = "#1A6A88", INK = "#06121E";

// ---- primitives --------------------------------------------------------------

let uid = 0;
const id = (p) => `${p}${++uid}`;
const f = (n) => +n.toFixed(2);
let seed = 41;
const rnd = () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;

function mix(a, b, t) {
  const p = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
  const [x, y] = [p(a), p(b)];
  return "#" + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, "0")).join("");
}

const glowDot = (x, y, r, color, o = 1) => {
  const g = id("gd");
  return `<defs><radialGradient id="${g}"><stop offset="0" stop-color="${color}" stop-opacity="${0.6 * o}"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></radialGradient></defs>` +
    `<circle cx="${f(x)}" cy="${f(y)}" r="${f(r * 4)}" fill="url(#${g})"/><circle cx="${f(x)}" cy="${f(y)}" r="${f(r)}" fill="${color}" opacity="${o}"/>`;
};

// A wobbly closed blob of radius r around (x, y): the X parasite's membrane.
function blobPath(x, y, r, wobble = 0.18, points = 9) {
  const pts = [];
  for (let i = 0; i < points; i++) {
    const a = (i / points) * Math.PI * 2;
    const rr = r * (1 + (rnd() - 0.5) * 2 * wobble);
    pts.push([x + Math.cos(a) * rr, y + Math.sin(a) * rr]);
  }
  let d = "";
  for (let i = 0; i < points; i++) {
    const p0 = pts[(i - 1 + points) % points], p1 = pts[i], p2 = pts[(i + 1) % points], p3 = pts[(i + 2) % points];
    const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6];
    const c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6];
    d += (i === 0 ? `M${f(p1[0])},${f(p1[1])}` : "") + ` C${f(c1[0])},${f(c1[1])} ${f(c2[0])},${f(c2[1])} ${f(p2[0])},${f(p2[1])}`;
  }
  return d + " Z";
}

// An X parasite: glowing gel, darker nucleus, a few organelles.
function xCell(x, y, r, color, o = 1) {
  const g = id("xg"), h = id("xh");
  let s = `<defs><radialGradient id="${g}" cx="0.4" cy="0.38"><stop offset="0" stop-color="${mix(color, "#FFFFFF", 0.6)}" stop-opacity="0.95"/>` +
    `<stop offset="0.6" stop-color="${color}" stop-opacity="0.8"/><stop offset="1" stop-color="${mix(color, "#000000", 0.3)}" stop-opacity="0.55"/></radialGradient>` +
    `<radialGradient id="${h}"><stop offset="0" stop-color="${color}" stop-opacity="0.5"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></radialGradient></defs>`;
  s += `<g opacity="${o}"><circle cx="${f(x)}" cy="${f(y)}" r="${f(r * 2.6)}" fill="url(#${h})"/>`;
  s += `<path d="${blobPath(x, y, r)}" fill="url(#${g})" stroke="${mix(color, "#FFFFFF", 0.4)}" stroke-width="${f(r * 0.06 + 0.3)}"/>`;
  s += `<path d="${blobPath(x + r * 0.08, y + r * 0.1, r * 0.42, 0.25, 7)}" fill="${mix(color, "#000000", 0.45)}" opacity="0.85"/>`;
  s += `<circle cx="${f(x + r * 0.05)}" cy="${f(y + r * 0.08)}" r="${f(r * 0.16)}" fill="${mix(color, "#FFFFFF", 0.5)}" opacity="0.8"/>`;
  for (let i = 0; i < 3; i++) s += `<circle cx="${f(x + (rnd() - 0.5) * r * 1.1)}" cy="${f(y + (rnd() - 0.5) * r * 1.1)}" r="${f(r * (0.06 + rnd() * 0.06))}" fill="#FFFFFF" opacity="0.6"/>`;
  s += `<ellipse cx="${f(x - r * 0.35)}" cy="${f(y - r * 0.4)}" rx="${f(r * 0.28)}" ry="${f(r * 0.14)}" fill="#FFFFFF" opacity="0.55" transform="rotate(-30 ${f(x - r * 0.35)} ${f(y - r * 0.4)})"/>`;
  return s + `</g>`;
}

const hexPoints = (cx, cy, r) => [0, 1, 2, 3, 4, 5].map((i) => {
  const a = Math.PI / 6 + i * Math.PI / 3;
  return `${f(cx + Math.cos(a) * r)},${f(cy + Math.sin(a) * r)}`;
}).join(" ");

const BLUR = (n) => `<filter id="blur${n}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${n}"/></filter>`;

function write(name, w, h, body, defs = "") {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><defs>${defs}</defs>${body}</svg>`;
  fs.writeFileSync(path.join(SVG_DIR, `${name}.svg`), svg);
  const png = new Resvg(svg, { fitTo: { mode: "width", value: Math.round(w * SCALE) } }).render().asPng();
  fs.writeFileSync(path.join(PNG_DIR, `${name}.png`), png);
  console.log(`${name}.png  ${w}x${h}dp  ${(png.length / 1024).toFixed(1)}kB`);
}

const grad = (gid, stops, x2 = 0, y2 = 1) =>
  `<linearGradient id="${gid}" x1="0" y1="0" x2="${x2}" y2="${y2}">` +
  stops.map(([o, c, a = 1]) => `<stop offset="${o}" stop-color="${c}" stop-opacity="${a}"/>`).join("") + `</linearGradient>`;

// ---- backdrop: BSL over SR388 ------------------------------------------------

{
  const W = 400, H = 460;
  let b = `<rect width="${W}" height="${H}" fill="url(#space)"/>`;
  // nebula wash
  b += `<g filter="url(#blur18)" opacity="0.5"><ellipse cx="90" cy="140" rx="120" ry="60" fill="#1A3A6A"/><ellipse cx="320" cy="230" rx="110" ry="50" fill="#3A1A5A"/><ellipse cx="200" cy="60" rx="90" ry="30" fill="#0E4A5A"/></g>`;
  // stars
  for (let i = 0; i < 130; i++) b += `<circle cx="${f(rnd() * W)}" cy="${f(rnd() * 340)}" r="${f(0.3 + rnd() * 0.8)}" fill="#E8F4FF" opacity="${f(0.25 + rnd() * 0.7)}"/>`;
  for (let i = 0; i < 6; i++) b += glowDot(rnd() * W, rnd() * 300, 0.9, "#BFE8FF", 0.9);
  // SR388: the planet's limb filling the bottom
  b += `<circle cx="200" cy="700" r="380" fill="url(#atmo)" filter="url(#blur8)"/>`;
  b += `<circle cx="200" cy="700" r="360" fill="url(#planet)"/>`;
  b += `<g opacity="0.35" fill="none" stroke="#6AC8A0" stroke-width="2">` +
    `<path d="M-20,380 Q120,352 260,360 T440,350"/><path d="M-20,410 Q100,392 240,398 T440,392" stroke-width="3" stroke="#2A6A50"/></g>`;
  b += `<g fill="#0A1A14" opacity="0.6"><ellipse cx="90" cy="400" rx="26" ry="6"/><ellipse cx="300" cy="420" rx="34" ry="7"/><ellipse cx="210" cy="375" rx="16" ry="4"/></g>`;
  b += `<circle cx="200" cy="700" r="360" fill="none" stroke="#7AF0D0" stroke-width="1.6" opacity="0.8"/>`;
  // the BSL station in orbit, top right
  b += `<g transform="translate(316,96) rotate(-14)">` +
    `<ellipse cx="0" cy="0" rx="46" ry="12" fill="none" stroke="#8FB0C8" stroke-width="3"/>` +
    `<ellipse cx="0" cy="0" rx="46" ry="12" fill="none" stroke="#C8E0F0" stroke-width="0.8"/>` +
    `<rect x="-5" y="-30" width="10" height="60" rx="3" fill="#6A88A0"/><rect x="-3" y="-30" width="3" height="60" fill="#A8C4D8"/>` +
    `<rect x="-14" y="-6" width="28" height="12" rx="3" fill="#7A98B0" stroke="#C8E0F0" stroke-width="0.6"/>` +
    `<rect x="-62" y="-3" width="14" height="6" fill="#3A5A7A"/><rect x="48" y="-3" width="14" height="6" fill="#3A5A7A"/>` +
    [-40, -20, 20, 40].map((x) => `<circle cx="${x}" cy="${x % 40 ? 11 : 8}" r="1" fill="#FFD84A"/>`).join("") +
    glowDot(0, -30, 1.4, "#FF5A5A") + glowDot(0, 30, 1.2, CYAN) + `</g>`;
  // X parasites drifting past
  const xs = [[60, 250, 13, "#E8F060"], [342, 300, 9, "#6AF08A"], [150, 190, 6, "#E8F060"], [262, 160, 5, "#FF6A6A"],
    [30, 120, 7, "#6AF08A"], [380, 200, 6, "#E8F060"], [228, 290, 4, "#4FE6FF"], [110, 310, 5, "#FF6A6A"]];
  for (const [x, y, r, c] of xs) b += xCell(x, y, r, c, 0.85);
  // hex grid + scanlines over everything, very faint
  let hex = "";
  for (let row = 0; row < 22; row++) for (let col = 0; col < 14; col++) {
    const cx = col * 30 + (row % 2) * 15, cy = row * 26;
    hex += `<polygon points="${hexPoints(cx, cy, 15)}"/>`;
  }
  b += `<g fill="none" stroke="#4FE6FF" stroke-width="0.4" opacity="0.07">${hex}</g>`;
  let scan = "";
  for (let y = 0; y < H; y += 3) scan += `<path d="M0,${y} L${W},${y}"/>`;
  b += `<g stroke="#000" stroke-width="0.8" opacity="0.12">${scan}</g>`;
  b += `<rect width="${W}" height="${H}" fill="url(#vig)"/>`;
  write("bsl-space", W, H, b, BLUR(18) + BLUR(8) +
    grad("space", [[0, "#02060E"], [0.5, "#061428"], [1, "#0A1C2E"]]) +
    `<radialGradient id="planet" cx="0.5" cy="0.08" r="0.9"><stop offset="0" stop-color="#3A6A54"/><stop offset="0.25" stop-color="#1E3A30"/><stop offset="1" stop-color="#08120E"/></radialGradient>` +
    `<radialGradient id="atmo"><stop offset="0.9" stop-color="#4FE6C8" stop-opacity="0.55"/><stop offset="1" stop-color="#4FE6C8" stop-opacity="0"/></radialGradient>` +
    grad("vig", [[0, "#000", 0.35], [0.14, "#000", 0], [0.86, "#000", 0], [1, "#000", 0.3]]));
}

// ---- tabs: holo plates ---------------------------------------------------------

function tab(active) {
  const W = 110, H = 36;
  const p = `M10,4 L100,4 L108,12 L108,32 L2,32 L2,12 Z`;
  let b = `<path d="${p}" fill="url(#tb)" stroke="${active ? "#BFF6FF" : CYAN_LO}" stroke-width="1.2"/>`;
  b += `<path d="M14,7 L60,7" stroke="${active ? "#FFFFFF" : CYAN}" stroke-width="1" opacity="${active ? 0.9 : 0.35}"/>`;
  b += `<path d="M96,28 L104,28 M98,25 L104,25" stroke="${active ? "#FFFFFF" : CYAN}" stroke-width="0.9" opacity="${active ? 0.8 : 0.4}"/>`;
  if (active) b += `<rect x="6" y="31" width="98" height="2.4" rx="1.2" fill="#FFFFFF" opacity="0.9"/>`;
  return [W, H, b, grad("tb", active ? [[0, "#5AE8FF"], [1, "#1A8AB8"]] : [[0, "#0E2A3E", 0.95], [1, "#061624", 0.95]])];
}
write("tab-holo", ...tab(false));
write("tab-holo-active", ...tab(true));

// ---- holo corner brackets and the scan divider --------------------------------

function bracket(mirror, color = CYAN) {
  const W = 34, H = 34;
  let b = `<g transform="${mirror ? `translate(${W},0) scale(-1,1)` : ""}">`;
  b += `<path d="M4,30 L4,8 L8,4 L30,4" stroke="${color}" stroke-width="2.4" fill="none" stroke-linecap="square"/>`;
  b += `<path d="M9,24 L9,11 L11,9 L24,9" stroke="${color}" stroke-width="0.8" fill="none" opacity="0.6"/>`;
  b += `<path d="M14,4 L14,1.5 M20,4 L20,1.5 M4,14 L1.5,14 M4,20 L1.5,20" stroke="${color}" stroke-width="1" opacity="0.8"/>`;
  b += glowDot(8, 8, 1.4, "#FFFFFF");
  return [W, H, b + `</g>`];
}
write("bracket-l", ...bracket(false));
write("bracket-r", ...bracket(true));
write("bracket-l-alert", ...bracket(false, "#FF5A5A"));
write("bracket-r-alert", ...bracket(true, "#FF5A5A"));

function divider(mirror) {
  const W = 110, H = 14;
  let b = `<g transform="${mirror ? `translate(${W},0) scale(-1,1)` : ""}">`;
  b += `<path d="M2,7 L92,7" stroke="url(#dv)" stroke-width="1.2"/>`;
  for (let i = 0; i < 4; i++) b += `<rect x="${40 + i * 12}" y="5" width="${3 + i}" height="4" fill="${CYAN}" opacity="${0.3 + i * 0.18}"/>`;
  b += `<polygon points="${hexPoints(102, 7, 5)}" fill="none" stroke="${CYAN}" stroke-width="1.2"/>` + glowDot(102, 7, 1.4, "#FFFFFF");
  return [W, H, b + `</g>`, grad("dv", [[0, CYAN, 0], [1, CYAN, 1]], 1, 0)];
}
write("scan-left", ...divider(false));
write("scan-right", ...divider(true));

// ---- energy tank cells ----------------------------------------------------------

write("tank-full", 16, 16, `<rect x="1.5" y="1.5" width="13" height="13" rx="2.5" fill="url(#tf)" stroke="#BFF6FF" stroke-width="1"/>` +
  `<rect x="3.5" y="3.5" width="5" height="2" rx="1" fill="#FFFFFF" opacity="0.8"/>`, grad("tf", [[0, "#9AF6FF"], [1, "#1AA8D8"]]));
write("tank-empty", 16, 16, `<rect x="1.5" y="1.5" width="13" height="13" rx="2.5" fill="#06121E" stroke="${CYAN_LO}" stroke-width="1"/>`);

// ---- ability glyphs on hex plates ----------------------------------------------

const CAT = { beam: "#4FE6FF", missile: "#FF9A3A", bomb: "#FF5AC8", suit: "#6AF08A" };
const G = {
  charge: (c) => `<circle cx="24" cy="24" r="9" fill="none" stroke="${c}" stroke-width="2"/><circle cx="24" cy="24" r="4.5" fill="${c}"/><path d="M24,10 L24,14 M24,34 L24,38 M10,24 L14,24 M34,24 L38,24" stroke="${c}" stroke-width="2" stroke-linecap="round"/>`,
  wide: (c) => [16, 24, 32].map((y) => `<path d="M12,${y} L36,${y}" stroke="${c}" stroke-width="3" stroke-linecap="round"/>`).join("") + `<path d="M32,13 L37,16 M32,35 L37,32" stroke="${c}" stroke-width="2" stroke-linecap="round"/>`,
  plasma: (c) => `<path d="M11,24 L17,18 L22,28 L27,18 L32,28 L37,24" stroke="${c}" stroke-width="2.8" fill="none" stroke-linejoin="round" stroke-linecap="round"/><circle cx="37" cy="24" r="2.5" fill="${c}"/>`,
  wave: (c) => `<path d="M10,24 C14,14 18,14 22,24 S30,34 34,24 S38,18 39,20" stroke="${c}" stroke-width="2.8" fill="none" stroke-linecap="round"/>`,
  icebeam: (c) => [0, 60, 120].map((a) => `<path d="M24,12 L24,36 M20,15 L24,19 L28,15 M20,33 L24,29 L28,33" stroke="${c}" stroke-width="2" fill="none" stroke-linecap="round" transform="rotate(${a} 24 24)"/>`).join(""),
  missile: (c) => `<path d="M24,10 C28,14 29,19 29,24 L29,32 L19,32 L19,24 C19,19 20,14 24,10 Z" fill="${c}"/><path d="M19,28 L15,35 L19,33 M29,28 L33,35 L29,33" fill="${c}"/><rect x="21" y="32" width="6" height="4" fill="${mix(c, "#FFFFFF", 0.4)}"/>`,
  super: (c) => G.missile(c) + `<path d="M15,20 L19,17 M33,20 L29,17" stroke="#FFFFFF" stroke-width="1.6" stroke-linecap="round"/><path d="M22,18 L24,15 L26,18" stroke="#FFFFFF" stroke-width="1.4" fill="none"/>`,
  icemissile: (c) => G.missile(c) + `<g transform="translate(31,13) scale(0.35)">${G.icebeam("#BFF6FF")}</g>`,
  diffusion: (c) => G.missile(c) + [0, 1, 2, 3, 4, 5].map((i) => { const a = i * Math.PI / 3; return `<circle cx="${f(24 + Math.cos(a) * 15)}" cy="${f(24 + Math.sin(a) * 15)}" r="1.6" fill="${c}"/>`; }).join(""),
  bomb: (c) => `<circle cx="24" cy="26" r="8" fill="${c}"/><circle cx="21" cy="23" r="2.2" fill="#FFFFFF" opacity="0.7"/><path d="M28,19 L32,14" stroke="${c}" stroke-width="2"/><circle cx="33" cy="13" r="2" fill="#FFF0A0"/>`,
  powerbomb: (c) => `<circle cx="24" cy="24" r="6" fill="${c}"/><circle cx="24" cy="24" r="10.5" fill="none" stroke="${c}" stroke-width="2"/><circle cx="24" cy="24" r="14.5" fill="none" stroke="${c}" stroke-width="1.2" stroke-dasharray="3 3"/>`,
  morph: (c) => `<circle cx="24" cy="24" r="10" fill="${c}"/><path d="M14,24 L34,24 M24,14 C29,18 29,30 24,34 M24,14 C19,18 19,30 24,34" stroke="${INK}" stroke-width="1.6" fill="none"/><circle cx="20" cy="19" r="2" fill="#FFFFFF" opacity="0.7"/>`,
  highjump: (c) => `<path d="M17,26 L17,34 L33,34 L33,31 L24,29 L24,26 Z" fill="${c}"/><path d="M24,22 L24,10 M19,15 L24,10 L29,15" stroke="${c}" stroke-width="2.6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`,
  speed: (c) => [0, 1, 2].map((i) => `<path d="M${12 + i * 8},14 L${21 + i * 8},24 L${12 + i * 8},34" stroke="${c}" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round" opacity="${0.5 + i * 0.25}"/>`).join(""),
  spacejump: (c) => `<path d="M14,32 C14,20 22,12 32,14" stroke="${c}" stroke-width="2.6" fill="none" stroke-linecap="round"/><path d="M34,16 C34,28 26,36 16,34" stroke="${c}" stroke-width="2.6" fill="none" stroke-linecap="round" opacity="0.6"/><circle cx="24" cy="24" r="3.4" fill="${c}"/>`,
  screw: (c) => [0, 120, 240].map((a) => `<path d="M24,24 C24,16 30,12 36,14 C32,16 30,20 30,24 Z" fill="${c}" transform="rotate(${a} 24 24)"/>`).join("") + `<circle cx="24" cy="24" r="3" fill="#FFFFFF"/>`,
  varia: (c) => `<path d="M12,18 C12,12 18,10 24,10 C30,10 36,12 36,18 L33,24 L24,22 L15,24 Z" fill="${c}"/><path d="M15,26 L24,24 L33,26 L30,36 L18,36 Z" fill="${mix(c, "#000000", 0.25)}"/><circle cx="24" cy="16" r="3" fill="#FFFFFF" opacity="0.7"/>`,
  gravity: (c) => `<path d="M16,20 C16,13 20,10 24,10 C28,10 32,13 32,20 L32,26 L16,26 Z" fill="${c}"/><rect x="18" y="17" width="12" height="5" rx="2" fill="${INK}"/><path d="M18,30 L24,37 L30,30" stroke="${c}" stroke-width="2.6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`,
};
const ABIL = { charge: "beam", wide: "beam", plasma: "beam", wave: "beam", icebeam: "beam", missile: "missile", super: "missile",
  icemissile: "missile", diffusion: "missile", bomb: "bomb", powerbomb: "bomb", morph: "suit", highjump: "suit", speed: "suit",
  spacejump: "suit", screw: "suit", varia: "suit", gravity: "suit" };
for (const [name, cat] of Object.entries(ABIL)) {
  const c = CAT[cat];
  const plate = (on) => `<polygon points="${hexPoints(24, 24, 22)}" fill="url(#pl)" stroke="${on ? c : "#20384A"}" stroke-width="${on ? 1.8 : 1.2}"/>` +
    `<polygon points="${hexPoints(24, 24, 18.5)}" fill="none" stroke="${on ? c : "#16283A"}" stroke-width="0.6" opacity="0.6"/>`;
  write(`ab-${name}`, 48, 48, `<circle cx="24" cy="24" r="22" fill="${c}" opacity="0.22" filter="url(#blur3)"/>` + plate(true) + G[name](mix(c, "#FFFFFF", 0.15)),
    BLUR(3) + grad("pl", [[0, mix(c, "#0A1E2E", 0.78)], [1, "#06121E"]]));
  const dim = G[name]("#24425A").replace(/#FFFFFF|#BFF6FF|#FFF0A0/g, "#24425A").replace(/fill="#[0-9A-Fa-f]{6}" opacity="0\.7"/g, 'fill="#24425A"');
  write(`ab-${name}-off`, 48, 48, plate(false) + `<g opacity="0.9">${dim}</g>`, grad("pl", [[0, "#0C1C2A"], [1, "#050E18"]]));
}

// ---- sector emblems --------------------------------------------------------------

const SECT = {
  deck: ["#9AB8D8", `<ellipse cx="20" cy="20" rx="10" ry="4" fill="none" stroke="#FFFFFF" stroke-width="1.6"/><rect x="18" y="11" width="4" height="18" rx="1.5" fill="#FFFFFF"/>`],
  srx: ["#D89A5A", `<path d="M9,28 L16,15 L20,21 L24,13 L31,28 Z" fill="#FFFFFF"/><path d="M16,15 L18,19 M24,13 L26,17" stroke="#D89A5A" stroke-width="1"/>`],
  tro: ["#4FD87A", `<path d="M20,30 C11,26 10,16 20,10 C30,16 29,26 20,30 Z" fill="#FFFFFF"/><path d="M20,29 L20,13 M20,20 L15,16 M20,24 L25,19" stroke="#4FD87A" stroke-width="1.2"/>`],
  pyr: ["#FF6A3A", `<path d="M20,31 C13,30 12,24 15,19 C15,23 18,23 18,23 C17,18 19,13 23,10 C22,15 28,18 27,24 C27,28 24,31 20,31 Z" fill="#FFFFFF"/>`],
  aqa: ["#3A9AFF", `<path d="M9,17 Q14,12 19,17 T29,17 T33,15 M9,24 Q14,19 19,24 T29,24 T33,22" stroke="#FFFFFF" stroke-width="2.4" fill="none" stroke-linecap="round"/>`],
  arc: ["#8FE8FF", [0, 60, 120].map((a) => `<path d="M20,10 L20,30 M17,13 L20,16 L23,13 M17,27 L20,24 L23,27" stroke="#FFFFFF" stroke-width="1.8" fill="none" stroke-linecap="round" transform="rotate(${a} 20 20)"/>`).join("")],
  noc: ["#A87AF0", `<path d="M24,10 A10,10 0 1,0 30,27 A8,8 0 1,1 24,10 Z" fill="#FFFFFF"/><circle cx="27" cy="14" r="1" fill="#FFFFFF"/><circle cx="31" cy="19" r="0.8" fill="#FFFFFF"/>`],
};
for (const [name, [c, glyph]] of Object.entries(SECT)) {
  write(`sector-${name}`, 40, 40,
    `<polygon points="${hexPoints(20, 20, 18.5)}" fill="url(#sg)" stroke="${mix(c, "#FFFFFF", 0.4)}" stroke-width="1.4"/>` +
    `<polygon points="${hexPoints(20, 20, 15)}" fill="none" stroke="#FFFFFF" stroke-width="0.6" opacity="0.4"/>` + glyph,
    grad("sg", [[0, c], [1, mix(c, "#000000", 0.55)]]));
}

// ---- status icons ------------------------------------------------------------------

write("icon-missile", 24, 24, `<g transform="translate(-12,-12)">${G.missile("#FF9A3A")}</g>`);
write("icon-powerbomb", 24, 24, `<g transform="translate(-12,-12)">${G.powerbomb("#FF5AC8")}</g>`);
write("icon-timer", 24, 24, `<circle cx="12" cy="13" r="8.5" fill="none" stroke="${CYAN}" stroke-width="1.8"/><path d="M12,8 L12,13 L15.5,15" stroke="#FFFFFF" stroke-width="1.6" fill="none" stroke-linecap="round"/><path d="M9.5,2.5 L14.5,2.5 M12,2.5 L12,4.5" stroke="${CYAN}" stroke-width="1.6" stroke-linecap="round"/>`);
write("icon-lock", 24, 24, `<rect x="5" y="10.5" width="14" height="10" rx="2" fill="none" stroke="${CYAN}" stroke-width="1.8"/><path d="M8.5,10.5 L8.5,7.5 C8.5,3 15.5,3 15.5,7.5 L15.5,8.5" stroke="${CYAN}" stroke-width="1.8" fill="none" stroke-linecap="round"/><circle cx="12" cy="15.5" r="1.6" fill="#FFFFFF"/>`);
write("icon-here", 24, 24, glowDot(12, 12, 3.2, "#FFD84A") + `<circle cx="12" cy="12" r="1.8" fill="#FFFFFF"/>`);
write("icon-map", 24, 24, `<path d="M3,6 L9,4 L15,6 L21,4 L21,18 L15,20 L9,18 L3,20 Z" fill="none" stroke="${CYAN}" stroke-width="1.6" stroke-linejoin="round"/><path d="M9,4 L9,18 M15,6 L15,20" stroke="${CYAN}" stroke-width="1"/>`);

// ---- waiting emblem: an X parasite held in a containment ring -------------------------

{
  const W = 220, c = 110;
  seed = 7;
  let b = `<circle cx="${c}" cy="${c}" r="96" fill="none" stroke="${CYAN}" stroke-width="1.4" opacity="0.8"/>`;
  b += `<circle cx="${c}" cy="${c}" r="88" fill="none" stroke="${CYAN}" stroke-width="5" stroke-dasharray="2 9" opacity="0.5"/>`;
  b += `<circle cx="${c}" cy="${c}" r="74" fill="none" stroke="${CYAN_LO}" stroke-width="1"/>`;
  for (let i = 0; i < 4; i++) {
    b += `<g transform="rotate(${i * 90 + 45} ${c} ${c})"><path d="M${c - 10},${c - 104} L${c},${c - 98} L${c + 10},${c - 104}" stroke="${CYAN}" stroke-width="2" fill="none"/></g>`;
  }
  for (let i = 0; i < 36; i++) {
    const a = (i / 36) * Math.PI * 2, r1 = 96, r2 = i % 3 ? 100 : 106;
    b += `<path d="M${f(c + Math.cos(a) * r1)},${f(c + Math.sin(a) * r1)} L${f(c + Math.cos(a) * r2)},${f(c + Math.sin(a) * r2)}" stroke="${CYAN}" stroke-width="1" opacity="0.7"/>`;
  }
  b += xCell(c, c, 42, "#E8F060");
  b += xCell(c + 58, c - 40, 7, "#6AF08A", 0.9) + xCell(c - 60, c + 44, 6, "#FF6A6A", 0.9);
  write("x-core", W, W, b);
}
