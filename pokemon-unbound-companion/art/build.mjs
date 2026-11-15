// Draws the FireRed pack's art as SVG and renders it to PNG (GBADuo decodes
// bitmaps only). "Cinnabar Nightfire": a volcano at night, obsidian and molten
// bronze. Built on the enchanted-forest art kit's primitives (glow, seeded
// random, write) plus a layered flame. Original art, nothing from the game.
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

const C = {
  obsidian: "#100708", basalt: "#1E0F10", ash: "#F5E6D3",
  magma: "#C8261B", ember: "#FF6A1A", flame: "#FFA23A", gold: "#FFD27A", core: "#FFF4D6",
  bronze: "#C98A3B", bronzeHi: "#FFD9A0", bronzeDeep: "#6E4318",
};

const TYPES = {
  normal: "#A8A77A", fighting: "#C22E28", flying: "#A98FF3", poison: "#A33EA1", ground: "#E2BF65",
  rock: "#B6A136", bug: "#A6B91A", ghost: "#735797", steel: "#B7B7CE", unknown: "#68A090",
  fire: "#EE8130", water: "#6390F0", grass: "#7AC74C", electric: "#F7D02C", psychic: "#F95587",
  ice: "#96D9D6", dragon: "#6F35FC", dark: "#705746",
};

// ---- primitives --------------------------------------------------------------

let uid = 0;
const id = (p) => `${p}${++uid}`;
const f = (n) => +n.toFixed(2);

let seed = 11;
const rnd = () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;

// mix two #rrggbb colours, t = 0..1 towards b
function mix(a, b, t) {
  const p = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
  const [x, y] = [p(a), p(b)];
  return "#" + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, "0")).join("");
}

const glowDot = (x, y, r, color = C.gold, o = 1) => {
  const g = id("gd");
  return `<defs><radialGradient id="${g}"><stop offset="0" stop-color="${color}" stop-opacity="${0.6 * o}"/>` +
    `<stop offset="1" stop-color="${color}" stop-opacity="0"/></radialGradient></defs>` +
    `<circle cx="${f(x)}" cy="${f(y)}" r="${f(r * 4.5)}" fill="url(#${g})"/>` +
    `<circle cx="${f(x)}" cy="${f(y)}" r="${f(r)}" fill="${color}" opacity="${o}"/>`;
};

// One flame tongue standing on (x, y), `h` tall, `w` half-wide, leaning by
// `angle` degrees; `lick` > 0 curls the tip right, < 0 left. Three nested layers.
function flame(x, y, h, w, angle = 0, opt = {}) {
  const { lick = 1, opacity = 1, layers = [[C.magma, C.ember], [C.ember, C.flame], [C.gold, C.core]] } = opt;
  const s = lick >= 0 ? 1 : -1;
  const shape = (H, W) =>
    `M0,0 C${f(W * 0.95 * s)},0 ${f(W * 1.1 * s)},${f(-H * 0.35)} ${f(W * 0.5 * s)},${f(-H * 0.6)} ` +
    `C${f(W * 0.2 * s)},${f(-H * 0.74)} ${f(W * 0.45 * s)},${f(-H * 0.88)} ${f(W * 0.1 * s)},${f(-H)} ` +
    `C${f(-W * 0.25 * s)},${f(-H * 0.82)} ${f(-W * 0.6 * s)},${f(-H * 0.72)} ${f(-W * 0.78 * s)},${f(-H * 0.48)} ` +
    `C${f(-W * 1.08 * s)},${f(-H * 0.18)} ${f(-W * 0.8 * s)},0 0,0 Z`;
  let out = `<g transform="translate(${f(x)},${f(y)}) rotate(${f(angle)})" opacity="${opacity}">`;
  layers.forEach(([a, b], i) => {
    const k = [1, 0.7, 0.4][i];
    const g = id("fl");
    out += `<defs><linearGradient id="${g}" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="${b}"/>` +
      `<stop offset="1" stop-color="${a}"/></linearGradient></defs>` +
      `<path d="${shape(h * k, w * k)}" fill="url(#${g})" transform="translate(0,${f(-h * (1 - k) * 0.08)})"/>`;
  });
  return out + `</g>`;
}

const BLUR = (n) => `<filter id="blur${n}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${n}"/></filter>`;

function write(name, w, h, body, defs = "") {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">` +
    `<defs>${defs}</defs>${body}</svg>`;
  fs.writeFileSync(path.join(SVG_DIR, `${name}.svg`), svg);
  const png = new Resvg(svg, { fitTo: { mode: "width", value: Math.round(w * SCALE) } }).render().asPng();
  fs.writeFileSync(path.join(PNG_DIR, `${name}.png`), png);
  console.log(`${name}.png  ${w}x${h}dp  ${(png.length / 1024).toFixed(1)}kB`);
}

const BRONZE = `<linearGradient id="bz" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${C.bronzeHi}"/>` +
  `<stop offset="0.5" stop-color="${C.bronze}"/><stop offset="1" stop-color="${C.bronzeDeep}"/></linearGradient>`;

// ---- backdrop: Cinnabar's volcano at night -----------------------------------

{
  const W = 400, H = 460;
  let b = `<rect width="${W}" height="${H}" fill="url(#sky)"/>`;
  // stars and drifting ash high up
  for (let i = 0; i < 60; i++) b += `<circle cx="${f(rnd() * W)}" cy="${f(rnd() * 200)}" r="${f(0.3 + rnd() * 0.7)}" fill="#FFE8D0" opacity="${f(0.15 + rnd() * 0.4)}"/>`;
  // ember moon behind the smoke
  b += `<circle cx="318" cy="78" r="70" fill="url(#moonGlow)"/>`;
  b += `<circle cx="318" cy="78" r="40" fill="url(#moon)"/>`;
  b += `<g opacity="0.25" fill="#7A2A14"><circle cx="305" cy="70" r="7"/><circle cx="330" cy="92" r="5"/><circle cx="325" cy="62" r="3.5"/></g>`;
  // smoke plume from the crater, blurred
  b += `<g filter="url(#blur6)" opacity="0.55">`;
  for (let i = 0; i < 9; i++) {
    const t = i / 8;
    b += `<ellipse cx="${f(190 + t * 90 + Math.sin(t * 5) * 18)}" cy="${f(205 - t * 170)}" rx="${f(26 + t * 46)}" ry="${f(16 + t * 22)}" fill="${mix("#4A2622", "#2A1416", t)}"/>`;
  }
  b += `</g>`;
  // far ridge
  b += `<path d="M0,300 L40,282 L85,292 L130,268 L160,276 L${W},250 L${W},${H} L0,${H} Z" fill="#1A0B0C"/>`;
  // the volcano
  const slope = `M-20,${H} C30,380 70,322 112,276 C138,248 158,224 172,213 L186,206 L214,206 L228,213 C244,226 264,250 290,280 C328,322 368,384 420,${H}`;
  b += `<path d="${slope} Z" fill="url(#mountain)"/>`;
  // rock strata catching the glow
  for (let i = 0; i < 7; i++) {
    const y = 236 + i * 26, half = 30 + i * 22;
    b += `<path d="M${f(200 - half)},${y} Q200,${y - 8 + (i % 2) * 6} ${f(200 + half)},${y + 2}" stroke="#4A1E14" stroke-width="1" fill="none" opacity="${f(0.55 - i * 0.05)}"/>`;
  }
  // rim light along both slopes
  b += `<path d="${slope}" stroke="#FF7A2A" stroke-width="5" fill="none" opacity="0.35" filter="url(#blur3)"/>`;
  b += `<path d="${slope}" stroke="#FFB070" stroke-width="0.8" fill="none" opacity="0.55"/>`;
  // crater glow + lava rivers that branch and cool as they run down
  b += `<ellipse cx="200" cy="208" rx="50" ry="20" fill="url(#craterGlow)"/>`;
  const rivers = [
    ["M190,210 C182,232 166,250 156,272 C148,290 134,306 128,326", 2.2],
    ["M156,272 C164,290 160,306 168,322", 1.2],
    ["M210,210 C220,230 238,246 248,266 C256,282 270,296 276,318", 2],
    ["M248,266 C240,282 244,298 236,312", 1.1],
    ["M200,211 C203,236 196,258 202,284 C206,300 200,316 204,334", 1.4],
  ];
  b += `<g filter="url(#blur3)" opacity="0.85">${rivers.map(([d, w]) => `<path d="${d}" stroke="${C.ember}" stroke-width="${w * 3}" fill="none"/>`).join("")}</g>`;
  b += rivers.map(([d, w]) => `<path d="${d}" stroke="url(#lava)" stroke-width="${w}" fill="none" stroke-linecap="round"/>`).join("");
  // crater rim lip
  b += `<path d="M168,214 Q200,198 232,214" stroke="#FFB45A" stroke-width="1.4" fill="none" opacity="0.8"/>`;
  // flame wall along the floor
  b += `<rect x="0" y="${H - 120}" width="${W}" height="120" fill="url(#heat)"/>`;
  for (let i = 0; i < 34; i++) {
    const x = (i / 33) * W + (rnd() - 0.5) * 14;
    const h = 36 + rnd() * 78 * (0.6 + 0.4 * Math.abs(Math.sin(i * 0.7)));
    b += flame(x, H + 6, h, 10 + rnd() * 10, (rnd() - 0.5) * 16, { lick: rnd() > 0.5 ? 1 : -1, opacity: 0.55 + rnd() * 0.35 });
  }
  // rising embers, more near the fire
  for (let i = 0; i < 46; i++) {
    const y = 120 + Math.pow(rnd(), 0.6) * (H - 140);
    b += glowDot(rnd() * W, y, 0.6 + rnd() * 1.2, rnd() > 0.3 ? C.flame : C.gold, 0.5 + rnd() * 0.5);
  }
  b += `<rect width="${W}" height="${H}" fill="url(#vig)"/>`;
  write("nightfire", W, H, b, BLUR(6) + BLUR(3) +
    `<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0A0406"/>` +
    `<stop offset="0.5" stop-color="#1A090B"/><stop offset="1" stop-color="#2E0F0A"/></linearGradient>` +
    `<radialGradient id="moonGlow"><stop offset="0.5" stop-color="#FF8A3A" stop-opacity="0.35"/><stop offset="1" stop-color="#FF8A3A" stop-opacity="0"/></radialGradient>` +
    `<radialGradient id="moon" cx="0.4" cy="0.38"><stop offset="0" stop-color="#FFE2B0"/><stop offset="0.6" stop-color="#FF9A4A"/><stop offset="1" stop-color="#C2401E"/></radialGradient>` +
    `<linearGradient id="mountain" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4A1C14"/><stop offset="0.35" stop-color="#2A0F0C"/><stop offset="1" stop-color="#0E0506"/></linearGradient>` +
    `<radialGradient id="craterGlow"><stop offset="0" stop-color="#FFD27A" stop-opacity="0.95"/><stop offset="0.5" stop-color="#FF6A1A" stop-opacity="0.6"/><stop offset="1" stop-color="#FF6A1A" stop-opacity="0"/></radialGradient>` +
    `<linearGradient id="lava" x1="0" y1="210" x2="0" y2="340" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#FFF0B0"/><stop offset="0.45" stop-color="${C.flame}"/><stop offset="1" stop-color="${C.magma}" stop-opacity="0.2"/></linearGradient>` +
    `<linearGradient id="heat" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FF4A10" stop-opacity="0"/><stop offset="1" stop-color="#FF4A10" stop-opacity="0.35"/></linearGradient>` +
    `<linearGradient id="vig" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity="0.35"/>` +
    `<stop offset="0.14" stop-color="#000" stop-opacity="0"/><stop offset="0.8" stop-color="#000" stop-opacity="0"/>` +
    `<stop offset="1" stop-color="#000" stop-opacity="0.3"/></linearGradient>`);
}

// ---- tabs: obsidian plates; the selected one is molten with flame tips -------

function plate(active) {
  const W = 110, H = 38;
  const p = `M8,8 L102,8 L108,14 L108,32 L102,36 L8,36 L2,32 L2,14 Z`;
  let b = "";
  if (active) {
    for (let i = 0; i < 7; i++) b += flame(16 + i * 13, 11, 8 + (i % 3) * 3, 4, (i - 3) * 4, { lick: i % 2 ? 1 : -1 });
  }
  b += `<path d="${p}" fill="url(#pl)" stroke="${active ? "#FFE3A0" : C.bronze}" stroke-width="1.4"/>`;
  b += `<path d="M10,11 L100,11" stroke="${active ? "#FFF4D6" : "#5A3420"}" stroke-width="0.8" opacity="0.8"/>`;
  return [W, H, b, `<linearGradient id="pl" x1="0" y1="0" x2="0" y2="1">` +
    (active ? `<stop offset="0" stop-color="#FFC24A"/><stop offset="1" stop-color="#E2501A"/>`
      : `<stop offset="0" stop-color="#3A1C18"/><stop offset="1" stop-color="#170A0A"/>`) + `</linearGradient>`];
}
write("tab-plate", ...plate(false));
write("tab-plate-active", ...plate(true));

// ---- corner flares and ember dividers -----------------------------------------

function flare(mirror) {
  const W = 66, H = 46;
  let b = `<g transform="${mirror ? `translate(${W},0) scale(-1,1)` : ""}">`;
  b += `<path d="M4,42 C6,24 16,10 34,8 C46,7 54,14 52,22 C50,29 42,30 39,25 C37,21 41,18 44,20" stroke="url(#bz)" stroke-width="2" fill="none" stroke-linecap="round"/>`;
  b += flame(8, 44, 30, 9, 18, { lick: 1 });
  b += flame(18, 40, 20, 6, 48, { lick: -1, opacity: 0.95 });
  b += flame(30, 12, 12, 4, 70, { lick: 1, opacity: 0.9 });
  b += glowDot(46, 34, 1.2, C.gold) + glowDot(58, 14, 0.9, C.flame) + glowDot(24, 28, 0.8, C.gold);
  return [W, H, b + `</g>`, BRONZE];
}
write("flare-left", ...flare(false));
write("flare-right", ...flare(true));

function divider(mirror) {
  const W = 120, H = 18;
  let b = `<g transform="${mirror ? `translate(${W},0) scale(-1,1)` : ""}">`;
  b += `<path d="M2,10 L104,10" stroke="url(#fade)" stroke-width="1.3"/>`;
  for (let i = 0; i < 4; i++) {
    const x = 40 + i * 16;
    b += `<path d="M${x},7 L${x + 3},10 L${x},13 L${x - 3},10 Z" fill="${C.flame}" opacity="${0.5 + i * 0.15}"/>`;
  }
  b += flame(112, 15, 13, 5, 0, { lick: 1 });
  return [W, H, b + `</g>`, `<linearGradient id="fade"><stop offset="0" stop-color="${C.bronze}" stop-opacity="0"/><stop offset="1" stop-color="${C.gold}"/></linearGradient>`];
}
write("divider-left", ...divider(false));
write("divider-right", ...divider(true));

// ---- type orbs: a glossy capsule per type -------------------------------------

for (const [name, color] of Object.entries(TYPES)) {
  const hi = mix(color, "#FFFFFF", 0.55), lo = mix(color, "#000000", 0.55);
  let b = `<circle cx="20" cy="21" r="17.5" fill="#000" opacity="0.35" filter="url(#blur2)"/>`;
  b += `<circle cx="20" cy="20" r="17" fill="url(#body)" stroke="url(#bz)" stroke-width="1.4"/>`;
  b += `<path d="M3.2,20 A16.8,16.8 0 0,0 36.8,20 Z" fill="url(#lower)"/>`;
  b += `<rect x="3" y="18.4" width="34" height="3.2" fill="#1A0D0C"/>`;
  b += `<circle cx="20" cy="20" r="5.6" fill="#1A0D0C"/><circle cx="20" cy="20" r="3.8" fill="url(#btn)" stroke="${C.bronzeHi}" stroke-width="0.6"/>`;
  b += `<ellipse cx="13" cy="10.5" rx="6" ry="3.4" fill="#fff" opacity="0.6" transform="rotate(-30 13 10.5)"/>`;
  b += `<circle cx="27" cy="9" r="1.2" fill="#fff" opacity="0.7"/>`;
  write(`orb-${name}`, 40, 40, b, BLUR(2) + BRONZE +
    `<radialGradient id="body" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="${hi}"/><stop offset="0.55" stop-color="${color}"/><stop offset="1" stop-color="${lo}"/></radialGradient>` +
    `<linearGradient id="lower" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F7EEE4"/><stop offset="1" stop-color="#B9A79A"/></linearGradient>` +
    `<radialGradient id="btn" cx="0.4" cy="0.35"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="${hi}"/></radialGradient>`);
}

// ---- badges: eight medallions of my own, plus an empty socket each ------------

const RING = (inner) => `<circle cx="20" cy="21" r="18" fill="#000" opacity="0.35" filter="url(#blur2)"/>` +
  `<circle cx="20" cy="20" r="17.5" fill="url(#bz)"/><circle cx="20" cy="20" r="15" fill="#1C0E0C"/>` +
  `<circle cx="20" cy="20" r="15" fill="none" stroke="#5A3420" stroke-width="0.8"/>` + inner;
const BADGES = [
  // [name, glyph(fill), colours]
  ["boulder", (c) => `<path d="M14,12 L26,12 L30,17 L30,25 L26,29 L14,29 L10,25 L10,17 Z" fill="${c}"/><path d="M14,12 L20,20 L26,12 M10,25 L20,20 L30,25 M20,20 L20,29" stroke="#fff" stroke-opacity="0.35" stroke-width="0.8" fill="none"/>`, "#B8B2A8"],
  ["cascade", (c) => `<path d="M20,9 C24,15 28,19 28,24 C28,28.5 24.4,31 20,31 C15.6,31 12,28.5 12,24 C12,19 16,15 20,9 Z" fill="${c}"/><path d="M16.5,23 C16.5,26 18,27.5 20,28" stroke="#fff" stroke-width="1.2" fill="none" opacity="0.7"/>`, "#4FA3F7"],
  ["thunder", (c) => `<path d="M22,8 L13,22 L19,22 L16,32 L27,17 L21,17 L24,8 Z" fill="${c}" stroke="#7A4A08" stroke-width="0.8" stroke-linejoin="round"/>`, "#FFD23A"],
  ["rainbow", (c) => [0, 1, 2, 3, 4, 5].map((i) => `<ellipse cx="20" cy="13.5" rx="3.6" ry="6" fill="${["#FF6A6A", "#FFB04A", "#FFE24A", "#7AD06A", "#5AA8FF", "#B07AF0"][i]}" transform="rotate(${i * 60} 20 20)"/>`).join("") + `<circle cx="20" cy="20" r="3" fill="#FFF4D6"/>`, ""],
  ["soul", (c) => `<path d="M20,30 C13,24.5 10,21 10,17 C10,14 12.2,12 15,12 C17.2,12 18.8,13.3 20,15 C21.2,13.3 22.8,12 25,12 C27.8,12 30,14 30,17 C30,21 27,24.5 20,30 Z" fill="${c}"/><path d="M14.5,15.5 C15.5,14.8 16.8,15 17.4,16" stroke="#fff" stroke-width="1.2" fill="none" opacity="0.8"/>`, "#FF7AB8"],
  ["marsh", (c) => `<circle cx="20" cy="20" r="10" fill="${c}"/><circle cx="20" cy="20" r="6.5" fill="#1C0E0C"/><circle cx="20" cy="20" r="3.5" fill="${c}"/>`, "#F0C24A"],
  ["volcano", () => flame(20, 31, 22, 8, 0, { lick: 1 }), ""],
  ["earth", (c) => `<path d="M20,31 C20,24 20,18 20,14" stroke="#5A3A18" stroke-width="1.6"/><path d="M20,20 C13,20 10,15 11,10 C16,10 20,13 20,20 Z" fill="${c}"/><path d="M20,17 C26,17 30,13 29,8 C24,8 20,11 20,17 Z" fill="${mix("#6ACB5A", "#FFFFFF", 0.2)}"/>`, "#3FAA4A"],
];
BADGES.forEach(([name, glyph, color], i) => {
  write(`badge-${i + 1}`, 40, 40, RING(glyph(color || C.flame) + `<ellipse cx="14" cy="11" rx="5" ry="2.4" fill="#fff" opacity="0.18" transform="rotate(-30 14 11)"/>`), BLUR(2) + BRONZE);
  write(`badge-${i + 1}-empty`, 40, 40, RING(`<g opacity="0.16">${glyph("#C9B6A0").replace(/fill="#[0-9A-Fa-f]{6}"/g, 'fill="#C9B6A0"').replace(/url\(#fl\d+\)/g, "#C9B6A0")}</g>`), BLUR(2) + BRONZE);
});

// ---- small icons -----------------------------------------------------------------

write("coin", 24, 24, `<circle cx="12" cy="12" r="10" fill="url(#bz)" stroke="#5A3418" stroke-width="1"/>` +
  `<circle cx="12" cy="12" r="7.4" fill="none" stroke="#FFF0C8" stroke-width="0.7" opacity="0.7"/>` + flame(12, 17.5, 10, 3.6, 0, { lick: 1 }), BRONZE);
write("hourglass", 24, 24, `<path d="M6,3 H18 M6,21 H18" stroke="url(#bz)" stroke-width="2.4" stroke-linecap="round"/>` +
  `<path d="M7.5,4 C7.5,9 12,10.5 12,12 C12,13.5 7.5,15 7.5,20 H16.5 C16.5,15 12,13.5 12,12 C12,10.5 16.5,9 16.5,4 Z" fill="rgba(255,240,220,0.22)" stroke="#FFE3C0" stroke-width="0.9"/>` +
  `<path d="M9.5,19.5 C9.5,17 11,16.2 12,16.2 C13,16.2 14.5,17 14.5,19.5 Z M10,7 H14 L12,10 Z" fill="${C.flame}"/>`, BRONZE);
write("dex", 24, 24, `<rect x="4" y="2.5" width="16" height="19" rx="2.5" fill="url(#dx)" stroke="#4A0E0A" stroke-width="1"/>` +
  `<rect x="6.5" y="5" width="11" height="7" rx="1.2" fill="#2A3A44"/><rect x="7.5" y="6" width="9" height="5" rx="0.8" fill="#8FE0F0" opacity="0.85"/>` +
  `<circle cx="9" cy="16.5" r="1.8" fill="#FFD27A"/><path d="M13,15.5 H17 M13,17.8 H16" stroke="#FFE3C0" stroke-width="1" stroke-linecap="round"/>`,
  `<linearGradient id="dx" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F0503A"/><stop offset="1" stop-color="#9A1A12"/></linearGradient>`);
write("idcard", 24, 24, `<rect x="2.5" y="5" width="19" height="14" rx="2" fill="#F5E6D3" stroke="url(#bz)" stroke-width="1.3"/>` +
  `<circle cx="8.5" cy="11" r="2.6" fill="${C.ember}"/><path d="M5,16.5 C5.5,14.5 11.5,14.5 12,16.5" fill="${C.ember}"/>` +
  `<path d="M14,10 H19 M14,13 H18" stroke="#8C5A2B" stroke-width="1.1" stroke-linecap="round"/>`, BRONZE);
// bag pockets
write("pocket-items", 24, 24, `<path d="M9,3 H15 V7 C18.5,8.5 20,11.5 20,15 C20,19.5 16.4,22 12,22 C7.6,22 4,19.5 4,15 C4,11.5 5.5,8.5 9,7 Z" fill="rgba(255,240,230,0.28)" stroke="#FFE3D0" stroke-width="1.1"/>` +
  `<path d="M5.6,14.5 C5.6,18.5 8.5,20.4 12,20.4 C15.5,20.4 18.4,18.5 18.4,14.5 Z" fill="#B04ADF"/><rect x="8.5" y="1.5" width="7" height="3" rx="1" fill="url(#bz)"/>` +
  `<path d="M7.5,11 C7,12.5 7,13.5 7.4,14.5" stroke="#fff" stroke-width="1.1" fill="none" opacity="0.8"/>`, BRONZE);
write("pocket-key", 24, 24, `<circle cx="7.5" cy="8" r="4.6" fill="none" stroke="url(#bz)" stroke-width="2.6"/>` +
  `<path d="M11,11.5 L20,20.5 M16.5,17 L19,14.5 M18.5,19 L21,16.5" stroke="url(#bz)" stroke-width="2.6" stroke-linecap="round"/>`, BRONZE);
write("pocket-balls", 24, 24, `<circle cx="12" cy="12" r="9.5" fill="url(#rb)" stroke="#2A1210" stroke-width="1.1"/>` +
  `<path d="M2.6,12 A9.4,9.4 0 0,0 21.4,12 Z" fill="#F4ECE4"/><rect x="2.5" y="11" width="19" height="2" fill="#2A1210"/>` +
  `<circle cx="12" cy="12" r="3.2" fill="#2A1210"/><circle cx="12" cy="12" r="2" fill="#fff"/>` +
  `<ellipse cx="8" cy="6.5" rx="3" ry="1.6" fill="#fff" opacity="0.55" transform="rotate(-30 8 6.5)"/>`,
  `<radialGradient id="rb" cx="0.35" cy="0.3"><stop offset="0" stop-color="#FF9A7A"/><stop offset="1" stop-color="#C8261B"/></radialGradient>`);
write("pocket-tmhm", 24, 24, `<circle cx="12" cy="12" r="10" fill="url(#cd)" stroke="#3A2A50" stroke-width="0.9"/>` +
  `<circle cx="12" cy="12" r="3" fill="#1C0E0C" stroke="#E8E0FF" stroke-width="0.8"/>` +
  `<path d="M6,7 A8,8 0 0,1 12,4.5" stroke="#fff" stroke-width="1.4" fill="none" opacity="0.75" stroke-linecap="round"/>`,
  `<linearGradient id="cd" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#9AE0FF"/><stop offset="0.5" stop-color="#C79BFF"/><stop offset="1" stop-color="#FF9AC4"/></linearGradient>`);
write("pocket-berries", 24, 24, `<circle cx="9.5" cy="14.5" r="6" fill="url(#br)"/><circle cx="15.5" cy="15" r="5.4" fill="url(#br)"/>` +
  `<path d="M12,9 C12,6 14,4 17,3.5" stroke="#4A6A20" stroke-width="1.4" fill="none"/>` +
  `<path d="M14,5.5 C17,3 21,4 21,7 C18,8 15.5,7.5 14,5.5 Z" fill="#6ACB5A"/>` +
  `<circle cx="7.5" cy="12.5" r="1.3" fill="#fff" opacity="0.6"/><circle cx="14" cy="13" r="1.1" fill="#fff" opacity="0.6"/>`,
  `<radialGradient id="br" cx="0.35" cy="0.3"><stop offset="0" stop-color="#FF9AB0"/><stop offset="1" stop-color="#B0203A"/></radialGradient>`);

// ---- crests --------------------------------------------------------------------

// VS: a bronze diamond wreathed in flame
{
  let b = flame(14, 34, 22, 8, -40, { lick: -1 }) + flame(50, 34, 22, 8, 40, { lick: 1 }) + flame(32, 30, 30, 10, 0, { lick: 1 });
  b += `<path d="M32,6 L50,22 L32,38 L14,22 Z" fill="url(#vsd)" stroke="url(#bz)" stroke-width="2"/>`;
  b += `<path d="M32,10 L46,22 L32,34 L18,22 Z" fill="none" stroke="#FFE3A0" stroke-width="0.7" opacity="0.7"/>`;
  write("vs-crest", 64, 44, b, BRONZE + `<linearGradient id="vsd" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4A1A12"/><stop offset="1" stop-color="#160808"/></linearGradient>`);
}

// Waiting screen: a firebird rising inside a bronze ring
{
  const W = 220, cx = 110, cy = 112;
  let b = glowDot(cx, cy, 14, C.ember, 0.4);
  b += `<circle cx="${cx}" cy="${cy}" r="88" fill="none" stroke="url(#bz)" stroke-width="3"/>`;
  b += `<circle cx="${cx}" cy="${cy}" r="82" fill="none" stroke="${C.bronze}" stroke-width="0.8" stroke-dasharray="2 5" opacity="0.7"/>`;
  // ring of small flames
  for (let i = 0; i < 28; i++) {
    const a = (i / 28) * Math.PI * 2;
    b += flame(cx + Math.cos(a) * 90, cy + Math.sin(a) * 90, 12 + (i % 3) * 4, 4.5, a * 180 / Math.PI + 90, { lick: i % 2 ? 1 : -1, opacity: 0.9 });
  }
  // tail: three long flames sweeping down
  b += flame(cx, cy + 20, 60, 12, 180, { lick: 1 }) + flame(cx - 8, cy + 18, 50, 9, 160, { lick: -1 }) + flame(cx + 8, cy + 18, 50, 9, 200, { lick: 1 });
  // wings: fans of flame tongues
  for (const side of [-1, 1]) {
    for (let i = 0; i < 6; i++) {
      const ang = side * (38 + i * 13);
      const len = 64 - i * 6;
      b += flame(cx + side * 6, cy + 2, len, 9 - i * 0.6, ang, { lick: side, opacity: 0.95 });
    }
  }
  // body and head
  b += `<path d="M${cx},${cy - 36} C${cx + 12},${cy - 22} ${cx + 13},${cy + 8} ${cx},${cy + 26} C${cx - 13},${cy + 8} ${cx - 12},${cy - 22} ${cx},${cy - 36} Z" fill="url(#bird)"/>`;
  b += flame(cx, cy - 38, 22, 6, 0, { lick: 1 });
  b += `<path d="M${cx},${cy - 40} L${cx + 10},${cy - 36} L${cx},${cy - 33} Z" fill="${C.bronzeHi}"/>`;
  b += `<circle cx="${cx + 2}" cy="${cy - 39}" r="1.6" fill="#1C0E0C"/>`;
  for (let i = 0; i < 14; i++) b += glowDot(cx + (rnd() - 0.5) * 170, cy + (rnd() - 0.5) * 170, 0.8 + rnd(), C.gold, 0.8);
  write("firebird", W, W, b, BRONZE + `<linearGradient id="bird" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF4D6"/><stop offset="0.4" stop-color="${C.gold}"/><stop offset="1" stop-color="${C.ember}"/></linearGradient>`);
}
