// Draws the Harvest Moon pack's art as SVG and renders it to PNG (GBADuo decodes
// bitmaps only). "The Mineral Town Almanac": a storybook farm whose backdrop
// follows the in-game season. Built on the enchanted-forest art kit's
// primitives (leaf, glow, seeded random, write) plus hills, trees, clouds,
// a barn and seasonal particles. Original art, nothing from the game.
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

// ---- primitives --------------------------------------------------------------

let uid = 0;
const id = (p) => `${p}${++uid}`;
const f = (n) => +n.toFixed(2);
let seed = 23;
const rnd = () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;

function mix(a, b, t) {
  const p = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
  const [x, y] = [p(a), p(b)];
  return "#" + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, "0")).join("");
}

function leaf(x, y, len, wid, angle, opt = {}) {
  const { from = "#4E9A3E", to = "#8FCB5A", rib = "rgba(255,255,255,0.4)", veins = false, opacity = 1, stroke = null } = opt;
  const g = id("lg");
  const L = len, W = wid;
  const blade = `M0,0 C${f(W)},${f(-L * 0.18)} ${f(W * 1.05)},${f(-L * 0.7)} 0,${f(-L)} C${f(-W * 1.05)},${f(-L * 0.7)} ${f(-W)},${f(-L * 0.18)} 0,0 Z`;
  let v = "";
  if (veins) for (let i = 1; i <= 4; i++) {
    const yy = -L * i / 5.2, s = W * 0.7;
    v += `<path d="M0,${f(yy)} L${f(s)},${f(yy - L * 0.1)} M0,${f(yy)} L${f(-s)},${f(yy - L * 0.1)}"/>`;
  }
  return `<defs><linearGradient id="${g}" x1="0" y1="1" x2="0.3" y2="0"><stop offset="0" stop-color="${from}"/><stop offset="1" stop-color="${to}"/></linearGradient></defs>` +
    `<g transform="translate(${f(x)},${f(y)}) rotate(${f(angle)})" opacity="${opacity}">` +
    `<path d="${blade}" fill="url(#${g})"${stroke ? ` stroke="${stroke}" stroke-width="0.6"` : ""}/>` +
    `<path d="M0,0 L0,${f(-L * 0.95)}" stroke="${rib}" stroke-width="${f(L * 0.03 + 0.2)}" stroke-linecap="round"/>` +
    (veins ? `<g stroke="${rib}" stroke-width="${f(L * 0.015 + 0.15)}" stroke-linecap="round">${v}</g>` : "") + `</g>`;
}

const glowDot = (x, y, r, color, o = 1) => {
  const g = id("gd");
  return `<defs><radialGradient id="${g}"><stop offset="0" stop-color="${color}" stop-opacity="${0.6 * o}"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></radialGradient></defs>` +
    `<circle cx="${f(x)}" cy="${f(y)}" r="${f(r * 4)}" fill="url(#${g})"/><circle cx="${f(x)}" cy="${f(y)}" r="${f(r)}" fill="${color}" opacity="${o}"/>`;
};

// five-petal flower
function flower(x, y, r, petal, center = "#FFD45A", o = 1) {
  let s = `<g transform="translate(${f(x)},${f(y)})" opacity="${o}">`;
  for (let i = 0; i < 5; i++) s += `<ellipse cx="0" cy="${f(-r * 0.62)}" rx="${f(r * 0.44)}" ry="${f(r * 0.62)}" fill="${petal}" transform="rotate(${i * 72})"/>`;
  return s + `<circle r="${f(r * 0.3)}" fill="${center}"/></g>`;
}

function cloud(x, y, s, color = "#FFFFFF", o = 0.95) {
  return `<g transform="translate(${f(x)},${f(y)}) scale(${f(s)})" opacity="${o}" fill="${color}">` +
    `<ellipse cx="0" cy="0" rx="22" ry="11"/><circle cx="-10" cy="-6" r="10"/><circle cx="6" cy="-10" r="13"/><circle cx="18" cy="-3" r="9"/></g>`;
}

// round-crowned tree: trunk + blobs of crown colour
function tree(x, y, s, crown, trunk = "#7A5232", extra = "") {
  let t = `<g transform="translate(${f(x)},${f(y)}) scale(${f(s)})">`;
  t += `<path d="M-3,0 L-2,-22 L2,-22 L3,0 Z" fill="${trunk}"/><path d="M0,-16 L-8,-24 M0,-19 L7,-27" stroke="${trunk}" stroke-width="2"/>`;
  const blobs = [[-12, -30, 12], [10, -32, 13], [0, -42, 15], [-4, -28, 11], [13, -24, 9]];
  blobs.forEach(([bx, by, br], i) => { t += `<circle cx="${bx}" cy="${by}" r="${br}" fill="${crown[i % crown.length]}"/>`; });
  return t + extra + `</g>`;
}

function pine(x, y, h, color = "#2F6B4A", snow = false) {
  let p = `<g transform="translate(${f(x)},${f(y)})"><rect x="-2" y="-6" width="4" height="8" fill="#6A4A30"/>`;
  for (let i = 0; i < 3; i++) {
    const w = h * (0.42 - i * 0.1), top = -h * (0.35 + i * 0.28), base = -h * (0.05 + i * 0.25);
    p += `<path d="M${f(-w)},${f(base)} L0,${f(top - h * 0.1)} L${f(w)},${f(base)} Z" fill="${color}"/>`;
    if (snow) p += `<path d="M${f(-w * 0.55)},${f(top + (base - top) * 0.45)} L0,${f(top - h * 0.1)} L${f(w * 0.55)},${f(top + (base - top) * 0.45)} Q0,${f(top + (base - top) * 0.3)} ${f(-w * 0.55)},${f(top + (base - top) * 0.45)} Z" fill="#FFFFFF"/>`;
  }
  return p + `</g>`;
}

function sunflower(x, y, h, s = 1) {
  let g = `<g transform="translate(${f(x)},${f(y)}) scale(${f(s)})">`;
  g += `<path d="M0,0 Q2,${-h * 0.5} 0,${-h}" stroke="#4E8A2E" stroke-width="2.4" fill="none"/>`;
  g += leaf(0, -h * 0.35, 12, 5, 55, { from: "#3F7A28", to: "#7CC14A" }) + leaf(0, -h * 0.55, 11, 4.5, -55, { from: "#3F7A28", to: "#7CC14A" });
  for (let i = 0; i < 12; i++) g += `<ellipse cx="0" cy="${-h - 7}" rx="2.6" ry="6" fill="${i % 2 ? "#FFC21E" : "#FFD84A"}" transform="rotate(${i * 30} 0 ${-h})"/>`;
  g += `<circle cx="0" cy="${-h}" r="5" fill="#7A4A1E"/><circle cx="-1.2" cy="${-h - 1.2}" r="1.6" fill="#A06A30"/>`;
  return g + `</g>`;
}

function snowflake(x, y, r, color = "#FFFFFF", o = 1) {
  let s = `<g transform="translate(${f(x)},${f(y)})" stroke="${color}" stroke-width="${f(r * 0.18)}" stroke-linecap="round" opacity="${o}">`;
  for (let i = 0; i < 6; i++) {
    s += `<g transform="rotate(${i * 60})"><path d="M0,0 L0,${f(-r)} M0,${f(-r * 0.55)} L${f(r * 0.25)},${f(-r * 0.75)} M0,${f(-r * 0.55)} L${f(-r * 0.25)},${f(-r * 0.75)}"/></g>`;
  }
  return s + `</g>`;
}

function barn(x, y, s) {
  return `<g transform="translate(${f(x)},${f(y)}) scale(${f(s)})">` +
    `<rect x="18" y="-26" width="9" height="26" fill="#D8D2C4"/><path d="M18,-26 Q22.5,-32 27,-26 Z" fill="#9AA0A8"/>` +
    `<path d="M-14,0 L-14,-16 L0,-26 L14,-16 L14,0 Z" fill="#C8433A"/>` +
    `<path d="M-16,-15 L0,-28 L16,-15" stroke="#FFF6E8" stroke-width="2" fill="none"/>` +
    `<rect x="-5" y="-11" width="10" height="11" fill="#FFF6E8"/><path d="M-5,-11 L5,0 M5,-11 L-5,0" stroke="#C8433A" stroke-width="1.2"/>` +
    `<rect x="-2" y="-21" width="4" height="4" fill="#FFF6E8"/></g>`;
}

function write(name, w, h, body, defs = "") {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><defs>${defs}</defs>${body}</svg>`;
  fs.writeFileSync(path.join(SVG_DIR, `${name}.svg`), svg);
  const png = new Resvg(svg, { fitTo: { mode: "width", value: Math.round(w * SCALE) } }).render().asPng();
  fs.writeFileSync(path.join(PNG_DIR, `${name}.png`), png);
  console.log(`${name}.png  ${w}x${h}dp  ${(png.length / 1024).toFixed(1)}kB`);
}

const grad = (gid, stops, vertical = true) =>
  `<linearGradient id="${gid}" x1="0" y1="0" x2="${vertical ? 0 : 1}" y2="${vertical ? 1 : 0}">` +
  stops.map(([o, c, a = 1]) => `<stop offset="${o}" stop-color="${c}" stop-opacity="${a}"/>`).join("") + `</linearGradient>`;

// ---- the four seasons --------------------------------------------------------

const W = 400, H = 460;
const SEASONS = {
  spring: { sky: ["#A9DAF5", "#D9EEF8", "#FCE6EE"], hills: ["#BEE3A0", "#9CD27C", "#7DBD60", "#62A84B"], sun: "#FFF4C8" },
  summer: { sky: ["#4FB2EE", "#9ED8F7", "#E2F6FF"], hills: ["#8FD06A", "#6FBD4E", "#55A83E", "#3F9332"], sun: "#FFF0A0" },
  fall:   { sky: ["#F2A86A", "#F8CB92", "#FCEBD0"], hills: ["#E2B36A", "#D2954A", "#B9773A", "#9A5E2E"], sun: "#FFE2A8" },
  winter: { sky: ["#8FA9D4", "#BCCDE8", "#E8EFF8"], hills: ["#FFFFFF", "#EEF3FA", "#DCE6F2", "#C8D6E8"], sun: "#FFFFFF" },
};

const hillPath = (base, amp, phase, freq) => {
  let d = `M0,${H}`;
  for (let x = 0; x <= W; x += 10) d += ` L${x},${f(base - Math.sin(x / W * Math.PI * freq + phase) * amp - Math.sin(x / 37 + phase) * amp * 0.12)}`;
  return d + ` L${W},${H} Z`;
};

for (const [season, c] of Object.entries(SEASONS)) {
  seed = 23 + season.length;
  let b = `<rect width="${W}" height="${H}" fill="url(#sky)"/>`;
  // sun with a soft halo
  b += `<circle cx="300" cy="86" r="70" fill="url(#halo)"/><circle cx="300" cy="86" r="26" fill="${c.sun}"/>`;
  // clouds
  const cloudTint = season === "winter" ? "#F4F7FC" : season === "fall" ? "#FFF3E2" : "#FFFFFF";
  b += cloud(70, 70, 1.3, cloudTint, 0.9) + cloud(210, 120, 0.9, cloudTint, 0.8) + cloud(350, 160, 1.1, cloudTint, 0.75);
  // far hill + farm
  b += `<path d="${hillPath(260, 26, 0.6, 1.4)}" fill="${c.hills[0]}"/>`;
  b += barn(300, 246, 1.25);
  b += `<g stroke="#9A7A55" stroke-width="1.2">${[0, 1, 2, 3, 4, 5].map((i) => `<path d="M${256 + i * 9},250 L${256 + i * 9},242"/>`).join("")}<path d="M254,244 L304,244 M254,247.5 L304,247.5"/></g>`;
  // mid hill with crop rows
  b += `<path d="${hillPath(310, 30, 2.2, 1.1)}" fill="${c.hills[1]}"/>`;
  b += `<g stroke="${mix(c.hills[1], "#000000", 0.18)}" stroke-width="2" opacity="0.5" stroke-linecap="round">`;
  for (let i = 0; i < 7; i++) b += `<path d="M${40 + i * 18},${330 + i * 2} Q${110 + i * 14},${312 + i * 3} ${180 + i * 10},${322 + i * 4}"/>`;
  b += `</g>`;
  // near hills
  b += `<path d="${hillPath(372, 22, 4.1, 1.7)}" fill="${c.hills[2]}"/>`;
  b += `<path d="${hillPath(420, 16, 1.3, 2.3)}" fill="${c.hills[3]}"/>`;

  if (season === "spring") {
    const blossom = ["#F9C5D8", "#F4A9C4", "#FCD9E6", "#F7B6CE", "#FBE3EC"];
    b += tree(38, 380, 2.2, blossom) + tree(372, 400, 1.8, blossom) + tree(150, 330, 0.9, blossom);
    for (let i = 0; i < 28; i++) b += flower(rnd() * W, 400 + rnd() * 55, 2.5 + rnd() * 2, ["#FFFFFF", "#FFE07A", "#F7A8C8", "#C9A8F0"][i % 4], "#FFD45A", 0.95);
    for (let i = 0; i < 40; i++) {
      const px = f(rnd() * W), py = f(rnd() * 360);
      b += `<ellipse cx="${px}" cy="${py}" rx="2.2" ry="1.3" fill="#F7B6CE" opacity="${f(0.5 + rnd() * 0.5)}" transform="rotate(${f(rnd() * 180)} ${px} ${py})"/>`;
    }
  }
  if (season === "summer") {
    const green = ["#4FA83E", "#62BA4A", "#3E9632", "#71C855", "#58B044"];
    b += tree(30, 380, 2.1, green) + tree(378, 396, 1.7, green);
    for (let i = 0; i < 9; i++) b += sunflower(90 + i * 26 + (rnd() - 0.5) * 8, H + 4, 46 + rnd() * 26, 0.95);
    for (let i = 0; i < 16; i++) b += glowDot(rnd() * W, 200 + rnd() * 200, 0.8, "#FFFFFF", 0.5);
  }
  if (season === "fall") {
    const amber = ["#E8822E", "#D9562A", "#F2A23A", "#C9452A", "#F5B84A"];
    b += tree(36, 382, 2.2, amber) + tree(370, 398, 1.8, amber) + tree(160, 330, 0.9, amber);
    for (let i = 0; i < 26; i++) b += leaf(rnd() * W, 60 + rnd() * 380, 7 + rnd() * 5, 3.4, rnd() * 360, { from: amber[i % 5], to: mix(amber[i % 5], "#FFE0A0", 0.4) });
    for (let i = 0; i < 14; i++) b += `<ellipse cx="${f(rnd() * W)}" cy="${f(430 + rnd() * 30)}" rx="5" ry="2" fill="${amber[i % 5]}" opacity="0.85"/>`;
  }
  if (season === "winter") {
    b += pine(40, 400, 110, "#2F6B4A", true) + pine(84, 410, 70, "#3A7A55", true) + pine(362, 404, 100, "#2F6B4A", true) + pine(150, 334, 40, "#4A8A62", true);
    for (let i = 0; i < 70; i++) b += `<circle cx="${f(rnd() * W)}" cy="${f(rnd() * H)}" r="${f(0.8 + rnd() * 1.8)}" fill="#FFFFFF" opacity="${f(0.55 + rnd() * 0.45)}"/>`;
    for (let i = 0; i < 8; i++) b += snowflake(rnd() * W, rnd() * 300, 3 + rnd() * 3, "#FFFFFF", 0.8);
  }
  write(`season-${season}`, W, H, b,
    grad("sky", [[0, c.sky[0]], [0.55, c.sky[1]], [1, c.sky[2]]]) +
    `<radialGradient id="halo"><stop offset="0.35" stop-color="${c.sun}" stop-opacity="0.8"/><stop offset="1" stop-color="${c.sun}" stop-opacity="0"/></radialGradient>`);
}

// Night: a star field that lies over the season (the stylesheet fades it in).
{
  let b = `<rect width="${W}" height="${H}" fill="url(#night)"/>`;
  seed = 99;
  for (let i = 0; i < 90; i++) b += `<circle cx="${f(rnd() * W)}" cy="${f(rnd() * 260)}" r="${f(0.4 + rnd() * 0.9)}" fill="#FFFFFF" opacity="${f(0.4 + rnd() * 0.6)}"/>`;
  for (let i = 0; i < 4; i++) b += glowDot(rnd() * W, rnd() * 220, 1.2, "#FFF6C8", 0.9);
  b += `<circle cx="300" cy="86" r="22" fill="#FFF6DA"/><circle cx="310" cy="80" r="20" fill="#24305E" opacity="0.92"/>`;
  for (let i = 0; i < 14; i++) b += glowDot(rnd() * W, 300 + rnd() * 150, 0.9, "#E8FF8A", 0.9);
  write("night-veil", W, H, b, grad("night", [[0, "#0E1640", 0.86], [0.6, "#1A2458", 0.6], [1, "#1A2458", 0.4]]));
}

// ---- wood: hanging tab signs and fence dividers --------------------------------

function sign(active) {
  const w = 84, h = 34;
  const g = active ? ["#F6D58E", "#E2B062"] : ["#B98552", "#8E5E34"];
  let b = `<path d="M22,0 L22,6 M62,0 L62,6" stroke="#7A5A3A" stroke-width="1.3"/>`;
  b += `<rect x="3" y="5" width="78" height="26" rx="8" fill="url(#wood)" stroke="${active ? "#A8742E" : "#5E3E22"}" stroke-width="1.4"/>`;
  b += `<g stroke="${active ? "#D8A256" : "#7E5430"}" stroke-width="0.8" fill="none" opacity="0.7"><path d="M10,12 Q30,10 44,13 T74,12"/><path d="M8,24 Q26,22 40,25 T76,24"/><ellipse cx="58" cy="18" rx="4" ry="1.8"/></g>`;
  b += `<circle cx="22" cy="9" r="1.6" fill="#5E4A3A"/><circle cx="62" cy="9" r="1.6" fill="#5E4A3A"/>`;
  if (active) b += leaf(76, 9, 9, 3, 40, { from: "#4E9A3E", to: "#9AD86A" }) + leaf(76, 9, 7, 2.6, 80, { from: "#4E9A3E", to: "#9AD86A" });
  return [w, h, b, grad("wood", [[0, g[0]], [1, g[1]]])];
}
write("sign", ...sign(false));
write("sign-active", ...sign(true));

function fence(mirror) {
  const w = 90, h = 18;
  let b = `<g transform="${mirror ? `translate(${w},0) scale(-1,1)` : ""}">`;
  b += `<path d="M4,7 L86,7 M4,12 L86,12" stroke="#B88A58" stroke-width="2.2" stroke-linecap="round"/>`;
  for (let i = 0; i < 5; i++) {
    const x = 10 + i * 18;
    b += `<path d="M${x - 2.5},16 L${x - 2.5},4 L${x},1.5 L${x + 2.5},4 L${x + 2.5},16 Z" fill="#D9B07A" stroke="#8E6438" stroke-width="0.8"/>`;
  }
  b += flower(86, 5, 4, "#FFFFFF", "#FFC83A");
  return [w, h, b + `</g>`];
}
write("fence-left", ...fence(false));
write("fence-right", ...fence(true));

// ---- seasonal corner sprigs ----------------------------------------------------

function corner(season) {
  const w = 56, h = 40;
  let b = "";
  const twig = `<path d="M3,37 C10,24 20,14 38,8" stroke="#8A6040" stroke-width="2" fill="none" stroke-linecap="round"/>`;
  if (season === "spring") {
    b += twig + leaf(14, 26, 12, 4, 40, { from: "#5EAA48", to: "#A6DC78" }) + leaf(24, 16, 10, 3.4, 110, { from: "#5EAA48", to: "#A6DC78" });
    b += flower(10, 31, 7, "#F7A8C8") + flower(28, 14, 6, "#FBD0E0") + flower(40, 8, 5, "#F7A8C8");
  }
  if (season === "summer") {
    b += twig.replace("#8A6040", "#4E8A2E") + leaf(16, 24, 13, 5, 50, { from: "#3F7A28", to: "#7CC14A" });
    for (let i = 0; i < 12; i++) b += `<ellipse cx="30" cy="5" rx="2.4" ry="5.6" fill="${i % 2 ? "#FFC21E" : "#FFD84A"}" transform="rotate(${i * 30} 30 12)"/>`;
    b += `<circle cx="30" cy="12" r="5" fill="#7A4A1E"/>`;
  }
  if (season === "fall") {
    b += twig;
    const maple = (x, y, s, col, rot) => `<g transform="translate(${x},${y}) rotate(${rot}) scale(${s})"><path d="M0,-10 L2.5,-4 L8,-6 L5,0 L9,3 L3,3 L2,9 L0,5 L-2,9 L-3,3 L-9,3 L-5,0 L-8,-6 L-2.5,-4 Z" fill="${col}" stroke="${mix(col, "#000000", 0.25)}" stroke-width="0.5"/></g>`;
    b += maple(12, 28, 1.2, "#E2582A", -20) + maple(28, 14, 1, "#F2A23A", 25) + maple(42, 8, 0.8, "#C9452A", 60);
    b += `<ellipse cx="20" cy="33" rx="3.2" ry="4" fill="#B07A3A"/><path d="M16.5,31 Q20,27.5 23.5,31 Z" fill="#6A4422"/>`;
  }
  if (season === "winter") {
    b += leaf(12, 32, 14, 5, 30, { from: "#2F6B3A", to: "#4E9A55", stroke: "#1E4A28" }) + leaf(14, 32, 13, 4.6, 75, { from: "#2F6B3A", to: "#4E9A55", stroke: "#1E4A28" });
    b += `<circle cx="16" cy="28" r="3" fill="#D8303A"/><circle cx="20" cy="31" r="2.6" fill="#E8404A"/><circle cx="12.5" cy="31.5" r="2.4" fill="#C8202A"/>`;
    b += snowflake(38, 12, 8, "#FFFFFF") + snowflake(38, 12, 8, "#9FB7DA", 0.5);
  }
  return [w, h, b];
}
for (const s of Object.keys(SEASONS)) {
  const [w, h, b] = corner(s);
  write(`corner-${s}`, w, h, b);
  write(`corner-${s}-r`, w, h, `<g transform="translate(${w},0) scale(-1,1)">${b}</g>`);
}

// ---- hearts in the seven love colours --------------------------------------------

const HEART = "M12,21 C5,15 1,11 1,6.5 C1,3.3 3.5,1 6.5,1 C8.8,1 10.6,2.3 12,4.3 C13.4,2.3 15.2,1 17.5,1 C20.5,1 23,3.3 23,6.5 C23,11 19,15 12,21 Z";
const LOVE = { black: "#5A4E48", purple: "#A98BD8", blue: "#6FA8DC", green: "#6DBB7C", yellow: "#E6B422", orange: "#EE9150", red: "#E8506F" };
for (const [name, col] of Object.entries(LOVE)) {
  write(`heart-${name}`, 24, 22,
    `<path d="${HEART}" fill="url(#hg)" stroke="${mix(col, "#000000", 0.35)}" stroke-width="1.2"/>` +
    `<path d="M5,5 C6.5,3.6 8.6,4 9.2,5.6" stroke="#FFFFFF" stroke-width="1.6" fill="none" stroke-linecap="round" opacity="0.85"/>`,
    grad("hg", [[0, mix(col, "#FFFFFF", 0.45)], [0.6, col], [1, mix(col, "#000000", 0.2)]]));
}

// ---- Harvest Sprites: a pointed hat in each sprite's colour --------------------------

const SPRITES = { chef: "#E04A3A", nappy: "#F08A2A", hoggy: "#E8C42A", timid: "#4EB04A", aqua: "#3A9AE0", bold: "#3A50B0", staid: "#8A4AC0" };
for (const [name, col] of Object.entries(SPRITES)) {
  let b = `<ellipse cx="16" cy="30" rx="9" ry="1.6" fill="#000" opacity="0.15"/>`;
  b += `<circle cx="16" cy="21" r="8" fill="#FFE2C4" stroke="#C8946A" stroke-width="0.8"/>`;
  b += `<circle cx="13" cy="21" r="1.1" fill="#3A2A1E"/><circle cx="19" cy="21" r="1.1" fill="#3A2A1E"/>`;
  b += `<ellipse cx="11" cy="24" rx="1.6" ry="1" fill="#F4A0A0" opacity="0.7"/><ellipse cx="21" cy="24" rx="1.6" ry="1" fill="#F4A0A0" opacity="0.7"/>`;
  b += `<path d="M6,17 Q16,11 26,17 Q22,8 24,2 Q14,4 9,12 Q7,14 6,17 Z" fill="url(#hat)" stroke="${mix(col, "#000000", 0.35)}" stroke-width="0.8"/>`;
  b += `<circle cx="24" cy="2.5" r="2.2" fill="#FFFFFF" stroke="${mix(col, "#000000", 0.2)}" stroke-width="0.5"/>`;
  b += `<path d="M7,16.5 Q16,11.5 25,16.5" stroke="#FFFFFF" stroke-width="1.4" fill="none" opacity="0.8"/>`;
  write(`sprite-${name}`, 32, 32, b, grad("hat", [[0, mix(col, "#FFFFFF", 0.3)], [1, col]]));
}

// ---- weather ---------------------------------------------------------------------

const sunIcon = (cx, cy, r) => `<circle cx="${cx}" cy="${cy}" r="${r}" fill="#FFC83A" stroke="#E89A1E" stroke-width="0.8"/>` +
  [0, 1, 2, 3, 4, 5, 6, 7].map((i) => `<path d="M${cx},${cy - r - 2} L${cx},${cy - r - 5.5}" stroke="#FFB21E" stroke-width="2" stroke-linecap="round" transform="rotate(${i * 45} ${cx} ${cy})"/>`).join("");
const cloudIcon = (col) => `<g fill="${col}"><ellipse cx="16" cy="19" rx="11" ry="6"/><circle cx="11" cy="16" r="5.5"/><circle cx="18" cy="13" r="7"/></g>`;
write("weather-sunny", 32, 32, sunIcon(16, 16, 7.5));
write("weather-rainy", 32, 32, cloudIcon("#B8C4D4") + [9, 15, 21].map((x) => `<path d="M${x},25 L${x - 2},30" stroke="#4A9AE8" stroke-width="2" stroke-linecap="round"/>`).join(""));
write("weather-snowy", 32, 32, cloudIcon("#D8E2EE") + snowflake(10, 27, 3, "#7AA8E0") + snowflake(20, 28, 3, "#7AA8E0"));
write("weather-stormy", 32, 32, cloudIcon("#7A8698") + `<path d="M17,20 L12,27 L16,27 L13,32 L21,24 L17,24 L20,20 Z" fill="#FFD23A" stroke="#C8901A" stroke-width="0.6"/>`);
write("weather-blizzard", 32, 32, cloudIcon("#A8B6C8") + `<path d="M4,24 Q12,21 20,24 T30,24 M6,28 Q14,25 22,28" stroke="#E8F2FF" stroke-width="1.6" fill="none" stroke-linecap="round"/>` + snowflake(26, 29, 2.6, "#7AA8E0"));
write("weather-unknown", 32, 32, cloudIcon("#C8C2B8") + `<text x="16" y="21" font-size="10" text-anchor="middle" fill="#6A5A4A" font-family="sans-serif" font-weight="bold">?</text>`);

// ---- farm icons --------------------------------------------------------------------

write("pouch", 28, 28, `<path d="M8,10 C3,14 3,25 14,25 C25,25 25,14 20,10 Z" fill="url(#pch)" stroke="#7A4A22" stroke-width="1"/>` +
  `<path d="M9,10 Q14,6 19,10" stroke="#7A4A22" stroke-width="1.6" fill="none"/><path d="M10,6 L14,9 L18,6" stroke="#C8943A" stroke-width="1.6" fill="none" stroke-linecap="round"/>` +
  `<circle cx="14" cy="18" r="4.4" fill="#FFD45A" stroke="#C8901A" stroke-width="0.8"/><text x="14" y="20.4" font-size="6" text-anchor="middle" fill="#9A6A12" font-family="sans-serif" font-weight="bold">G</text>`,
  grad("pch", [[0, "#D8A060"], [1, "#9A6438"]]));
write("clock", 28, 28, `<circle cx="14" cy="14" r="11" fill="#FFF8EA" stroke="#B8844A" stroke-width="2"/>` +
  `<path d="M14,7 L14,14 L19,17" stroke="#5A4030" stroke-width="1.8" fill="none" stroke-linecap="round"/><circle cx="14" cy="14" r="1.4" fill="#5A4030"/>` +
  `<path d="M14,4.5 L14,6 M23.5,14 L22,14 M14,23.5 L14,22 M4.5,14 L6,14" stroke="#B8844A" stroke-width="1.4"/>`);
write("calendar", 28, 28, `<rect x="4" y="6" width="20" height="18" rx="3" fill="#FFF8EA" stroke="#B8844A" stroke-width="1.4"/>` +
  `<rect x="4" y="6" width="20" height="6" rx="3" fill="#E8604A"/><path d="M9,4 L9,8 M19,4 L19,8" stroke="#5A4030" stroke-width="1.8" stroke-linecap="round"/>` +
  flower(14, 18, 4.4, "#F7A8C8"));
write("stamina", 28, 28, `<path d="M14,25 C6,19 3,15 3,10.5 C3,7 5.5,4.5 9,4.5 C11.2,4.5 12.8,5.8 14,7.6 C15.2,5.8 16.8,4.5 19,4.5 C22.5,4.5 25,7 25,10.5 C25,15 22,19 14,25 Z" fill="#7CC85A" stroke="#3F8A2E" stroke-width="1"/>` +
  leaf(14, 20, 9, 3.4, -20, { from: "#FFFFFF", to: "#E8FFD8", rib: "rgba(80,140,60,0.5)" }));
write("fatigue", 28, 28, `<path d="M14,4 C17.5,9.5 21,13.5 21,17.5 C21,21.5 17.9,24 14,24 C10.1,24 7,21.5 7,17.5 C7,13.5 10.5,9.5 14,4 Z" fill="url(#sw)" stroke="#4A88C8" stroke-width="1"/>` +
  `<path d="M11,15.5 C10.5,17.5 11,19.5 12.5,20.5" stroke="#FFFFFF" stroke-width="1.4" fill="none" stroke-linecap="round"/>`,
  grad("sw", [[0, "#D8EEFF"], [1, "#7AB8F0"]]));
write("medal", 28, 28, `<path d="M9,2 L13,12 M19,2 L15,12" stroke="#4A7AE0" stroke-width="3.4"/><path d="M9,2 L13,12" stroke="#E8504A" stroke-width="1.4"/>` +
  `<circle cx="14" cy="18" r="7.5" fill="#FFD45A" stroke="#C8901A" stroke-width="1"/><path d="M14,13.5 L15.4,16.6 L18.6,16.8 L16.2,18.9 L17,22 L14,20.3 L11,22 L11.8,18.9 L9.4,16.8 L12.6,16.6 Z" fill="#FFF2B8"/>`);
write("frisbee", 28, 28, `<ellipse cx="14" cy="16" rx="11" ry="5.5" fill="#E8604A" stroke="#A83A2A" stroke-width="1"/><ellipse cx="14" cy="14.5" rx="7.5" ry="3.2" fill="#F48A6A"/>` +
  `<path d="M6,9 Q9,6 12,8 M17,6 Q20,4 22,7" stroke="#B8844A" stroke-width="1.2" fill="none" stroke-linecap="round"/>`);

// tools: one icon per kind; the script maps tool names to a kind
const handle = (x1, y1, x2, y2) => `<path d="M${x1},${y1} L${x2},${y2}" stroke="#A8743E" stroke-width="2.6" stroke-linecap="round"/>`;
const steel = "#B8C2CC", steelLo = "#6A7684";
const TOOLS = {
  hoe: handle(6, 22, 18, 6) + `<path d="M16,4 L24,8 L22,12 L15,8 Z" fill="${steel}" stroke="${steelLo}" stroke-width="0.8"/>`,
  sickle: handle(7, 23, 12, 16) + `<path d="M12,16 C8,10 11,3 19,3 C24,3 26,7 25,10 C22,6 17,6 15,10 C14,12 14,14 12,16 Z" fill="${steel}" stroke="${steelLo}" stroke-width="0.8"/>`,
  axe: handle(7, 23, 19, 5) + `<path d="M15,4 C19,1 25,3 25,8 C25,12 21,14 18,12 Z" fill="${steel}" stroke="${steelLo}" stroke-width="0.8"/>`,
  hammer: handle(7, 23, 17, 9) + `<rect x="12" y="2" width="13" height="8" rx="1.5" fill="${steelLo}" transform="rotate(40 18 6)"/>`,
  can: `<path d="M6,10 L18,10 L18,23 L6,23 Z" fill="#6EB0E0" stroke="#3A7AB0" stroke-width="1"/><path d="M18,13 L25,7 L26,9 L19,16" fill="#6EB0E0" stroke="#3A7AB0" stroke-width="1"/><path d="M7,10 Q12,4 17,10" stroke="#3A7AB0" stroke-width="1.6" fill="none"/>` +
    `<path d="M26,8 L27.5,11 M25,9.5 L26.5,12.5" stroke="#7AC4F0" stroke-width="0.9"/>`,
  rod: `<path d="M5,24 L23,4" stroke="#A8743E" stroke-width="2" stroke-linecap="round"/><path d="M23,4 Q26,12 24,20" stroke="#6A6A6A" stroke-width="0.6" fill="none"/>` +
    `<circle cx="24" cy="21" r="2" fill="#E8504A"/><circle cx="8" cy="20" r="2.6" fill="none" stroke="#5A5A5A" stroke-width="1.2"/>`,
  milker: `<rect x="7" y="9" width="14" height="14" rx="3" fill="${steel}" stroke="${steelLo}" stroke-width="1"/><path d="M10,9 L10,4 M14,9 L14,3 M18,9 L18,4" stroke="#5A5A6A" stroke-width="1.8" stroke-linecap="round"/><rect x="9" y="14" width="10" height="5" rx="1" fill="#FFFFFF"/>`,
  brush: handle(6, 22, 14, 14) + `<rect x="12" y="4" width="13" height="7" rx="2" fill="#C88A4A" transform="rotate(-45 18 8)"/><path d="M15,15 L19,19 M17,13 L21,17 M19,11 L23,15" stroke="#5A3A1E" stroke-width="1.2"/>`,
  clippers: `<circle cx="8" cy="20" r="3.4" fill="none" stroke="#E8604A" stroke-width="2"/><circle cx="16" cy="22" r="3.4" fill="none" stroke="#E8604A" stroke-width="2"/>` +
    `<path d="M10,17.5 L22,4 M14.5,19 L24,7" stroke="${steelLo}" stroke-width="2.2" stroke-linecap="round"/>`,
  bell: `<path d="M8,20 C8,12 10,7 14,7 C18,7 20,12 20,20 Z" fill="#FFC83A" stroke="#C8901A" stroke-width="1"/><path d="M6,20 L22,20" stroke="#C8901A" stroke-width="2" stroke-linecap="round"/><circle cx="14" cy="22.5" r="2" fill="#C8901A"/><path d="M14,7 L14,4" stroke="#C8901A" stroke-width="1.6"/>`,
  seeds: `<path d="M7,9 L21,9 L22,24 L6,24 Z" fill="#E8D2A8" stroke="#A8844A" stroke-width="1"/><path d="M8,9 Q14,5 20,9" fill="#D8BE88"/>` +
    leaf(14, 21, 8, 3, -15, { from: "#4E9A3E", to: "#9AD86A" }) + `<circle cx="10" cy="14" r="1" fill="#8A6A3A"/><circle cx="18" cy="15" r="1" fill="#8A6A3A"/>`,
  tool: handle(7, 22, 21, 6) + `<circle cx="21" cy="6" r="4" fill="${steel}" stroke="${steelLo}" stroke-width="0.8"/>`,
  basket: `<path d="M5,12 L23,12 L20,24 L8,24 Z" fill="#C8904A" stroke="#8A5A28" stroke-width="1"/><path d="M8,12 Q14,2 20,12" stroke="#8A5A28" stroke-width="1.8" fill="none"/>` +
    `<path d="M7,16 L21,16 M8,20 L20,20" stroke="#8A5A28" stroke-width="0.8"/><circle cx="11" cy="11" r="3" fill="#E8504A"/><circle cx="17" cy="11" r="2.6" fill="#8ACB5A"/>`,
  crate: `<rect x="5" y="8" width="18" height="15" rx="1.5" fill="#D8A868" stroke="#8A5A28" stroke-width="1"/><path d="M5,13 L23,13 M5,18 L23,18 M5,8 L23,23" stroke="#8A5A28" stroke-width="0.9"/>`,
};
for (const [name, body] of Object.entries(TOOLS)) write(`tool-${name}`, 28, 28, body);

// ---- welcome sign for the waiting screen -------------------------------------------

{
  const Wd = 220, Hd = 200;
  let b = `<ellipse cx="110" cy="182" rx="90" ry="12" fill="#5E9A4A" opacity="0.5"/>`;
  b += `<rect x="104" y="96" width="12" height="88" rx="3" fill="url(#post)"/>`;
  b += `<g transform="rotate(-3 110 70)"><rect x="22" y="36" width="176" height="66" rx="14" fill="url(#board)" stroke="#6A4422" stroke-width="2.4"/>`;
  b += `<g stroke="#A8743E" stroke-width="1" fill="none" opacity="0.6"><path d="M34,52 Q80,48 120,53 T188,52"/><path d="M30,86 Q70,82 110,87 T190,85"/><ellipse cx="160" cy="68" rx="8" ry="3"/></g>`;
  b += `<circle cx="34" cy="46" r="2.4" fill="#5E4A3A"/><circle cx="186" cy="46" r="2.4" fill="#5E4A3A"/></g>`;
  // a turnip and flowers at the foot
  b += `<g transform="translate(150,178)"><path d="M0,0 C-10,-2 -12,-14 0,-18 C12,-14 10,-2 0,0 Z" fill="#F4F0F8" stroke="#B8A8C8" stroke-width="1"/>` +
    `<path d="M-8,-12 C-4,-17 4,-17 8,-12 C4,-15 -4,-15 -8,-12 Z" fill="#C878B8"/><path d="M0,1 L0,5" stroke="#B8A8C8" stroke-width="1"/>` +
    leaf(0, -17, 14, 4, -20, { from: "#3F8A2E", to: "#8ACB5A" }) + leaf(0, -17, 12, 3.6, 25, { from: "#3F8A2E", to: "#8ACB5A" }) + `</g>`;
  b += flower(60, 176, 7, "#F7A8C8") + flower(76, 182, 5, "#FFFFFF") + flower(176, 182, 5, "#FFE07A");
  b += leaf(88, 184, 16, 4, -25, { from: "#3F8A2E", to: "#8ACB5A" }) + leaf(92, 184, 14, 3.6, 15, { from: "#3F8A2E", to: "#8ACB5A" });
  b += leaf(126, 186, 15, 4, 20, { from: "#3F8A2E", to: "#8ACB5A" });
  // a butterfly
  b += `<g transform="translate(176,28) rotate(15)"><ellipse cx="-4" cy="-2" rx="5" ry="3.6" fill="#FFC83A"/><ellipse cx="4" cy="-2" rx="5" ry="3.6" fill="#FFC83A"/>` +
    `<ellipse cx="-3" cy="3" rx="3.4" ry="2.6" fill="#F7A8C8"/><ellipse cx="3" cy="3" rx="3.4" ry="2.6" fill="#F7A8C8"/><rect x="-0.6" y="-4" width="1.2" height="9" rx="0.6" fill="#5A4030"/></g>`;
  write("welcome-sign", Wd, Hd, b, grad("board", [[0, "#E2B470"], [1, "#B8844A"]]) + grad("post", [[0, "#A8743E"], [1, "#7A5028"]], false));
}
