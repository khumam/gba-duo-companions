// Pixel art for the "Pocket-OS" FireRed companion: header glyphs,
// the radar map and the LCD/hazard tiles. Every sprite is
// a bitmap drawn as rows of palette characters, written out as PNG at SCALE x
// (nearest-neighbour blocks, so the art stays crisp however the engine scales
// it). No dependencies: the PNG encoder is the ~30 lines below.
//
//   node art/pocket-os.mjs            writes assets/ui/*.png
//   node art/pocket-os.mjs --sheet    also writes /tmp/pocket-os-sheet.png

import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(here, "..", "assets", "ui");
const SCALE = 4;
fs.mkdirSync(OUT, { recursive: true });

// ---- PNG -------------------------------------------------------------------

const CRC = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
const crc32 = (buf) => {
  let c = 0xffffffff;
  for (const b of buf) c = CRC[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};
const chunk = (type, data) => {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
};
function png(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr),
    chunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

// ---- bitmaps -----------------------------------------------------------------

const hex = (h) => {
  if (h == null) return [0, 0, 0, 0];
  const v = h.replace("#", "");
  return [0, 2, 4, 6].map((i) => (i === 6 ? (v.length === 8 ? parseInt(v.slice(6), 16) : 255) : parseInt(v.slice(i, i + 2), 16)));
};

// Base palette shared by every sprite; a sprite can add or override keys.
const P = {
  ".": null,
  k: "#000000", w: "#FFFFFF", s: "#D1D5DB", d: "#6B7280", c: "#1F2937",
  r: "#FF3B30", R: "#B3261E", y: "#FFCC00", Y: "#C99A00", o: "#FF9500", O: "#B86800",
  g: "#34C759", G: "#1E8A3A", b: "#007AFF", B: "#0050B0", p: "#5856D6", n: "#8A5A2B",
  t: "#F2B04A", l: "#7FD0FF", m: "#E8E0CC",
};

/** A sprite: rows of equal-length strings. Returns {w, h, px(x,y)->rgba}. */
function sprite(name, rows, extra = {}) {
  const pal = { ...P, ...extra };
  const w = rows[0].length;
  rows.forEach((r, i) => {
    if (r.length !== w) throw new Error(`${name}: row ${i} is ${r.length} wide, expected ${w}`);
    for (const ch of r) if (!(ch in pal)) throw new Error(`${name}: unknown colour '${ch}'`);
  });
  return { name, w, h: rows.length, px: (x, y) => hex(pal[rows[y][x]]) };
}

function write(sp, scale = SCALE) {
  const W = sp.w * scale, H = sp.h * scale;
  const buf = Buffer.alloc(W * H * 4);
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      const c = sp.px(Math.floor(x / scale), Math.floor(y / scale));
      buf.set(c, (y * W + x) * 4);
    }
  fs.writeFileSync(path.join(OUT, `${sp.name}.png`), png(W, H, buf));
  return sp;
}

/** A sprite computed per pixel. */
const field = (name, w, h, fn) => ({ name, w, h, px: (x, y) => hex(fn(x, y)) });

// ---- tiles -------------------------------------------------------------------

// LCD matrix: 3x3 cell, 1px darker line over the pine canvas.
const lcd = field("lcd", 3, 3, (x, y) => (x === 0 || y === 0 ? "#0C1D19" : "#10241F"));
// Header stripes: 45-degree pine/deep-leaf bands, 6px wide on a 12px period.
const hazard = field("hazard", 12, 12, (x, y) => ((x + y) % 12 < 6 ? "#06120E" : "#5FA03E"));

// ---- header + misc glyphs ------------------------------------------------------

const glyphs = [
  sprite("ic-sun", [
    "...k..k...",
    "..kyk.ky..".replace("ky..", "kyk."),
    "...kkkk...",
    "kkkyyyykkk",
    ".kyywyyyk.",
    ".kyyyyyyk.",
    "kkkyyyykkk",
    "...kkkk...",
    "..kyk.kyk.".slice(0, 10),
    "...k..k...",
  ]),
  sprite("ic-clock", [
    "..kkkk..",
    ".kwwwwk.",
    "kwwkwwwk",
    "kwwkwwwk",
    "kwwkkkwk",
    "kwwwwwwk",
    ".kwwwwk.",
    "..kkkk..",
  ]),
  sprite("ic-signal", [
    "......kk",
    "......kg",
    "....kkkg",
    "....kgkg",
    "..kkkgkg",
    "..kgkgkg",
    "kkkgkgkg",
    "kgkgkgkg",
  ]),
  sprite("ic-coin", [
    "..kkkk..",
    ".kyyyyk.",
    "kyywwyYk",
    "kyywyyYk",
    "kyywyyYk",
    "kyyyyyYk",
    ".kYYYYk.",
    "..kkkk..",
  ]),
  sprite("ic-lock", [
    "..kkkk..",
    ".kk..kk.",
    ".k....k.",
    "kkkkkkkk",
    "kddddddk",
    "kdddkddk",
    "kddddddk",
    "kkkkkkkk",
  ]),
  sprite("ic-pin", [
    ".kkkk.",
    "krrrrk",
    "krwwrk",
    "krwwrk",
    "krrrrk",
    ".kkkk.",
  ]),
  sprite("ic-you", [
    "..kkkk..",
    ".kwwwwk.",
    "kwwrrwwk",
    "kwrrrrwk",
    "kwrrrrwk",
    "kwwrrwwk",
    ".kwwwwk.",
    "..kkkk..",
  ]),
  sprite("arrow-down", [
    "kkkkkkkkk",
    "kyyyyyyyk",
    ".kyyyyyk.",
    "..kyyyk..",
    "...kyk...",
    "....k....",
  ]),
];

// ---- radar map -----------------------------------------------------------------

// Route 1 north of Pallet Town, as a 24x18 grid of 5px tiles. Original layout.
const MAP = [
  "TTTTTTTT====TTTTTTTT",
  "TTTTTTTT====TTTTTTTT",
  "TT,,,,,,====,,,,,,TT",
  "TT,TT,,,====,,,TT,TT",
  "T,,TT,,,====,,,TT,,T",
  "T,,,,,,,====,,,,,,,T",
  "T,,,,,,=======,,,,,T",
  "T,,,,,,=======,,TT,T",
  "TT,TT,,====,,,,,TT,T",
  "TT,TT,,====,,,,,,,,T",
  "T,,,,,,=========,,TT",
  "T,,,,,,,,,,,,,==,,TT",
  "T,TT,,,,,,,,,,==,,,T",
  "T,TT,,,=========,,,T",
  "T,,,,,,====,,,,,,,,T",
  "T,,HH,,====,,,,HH,,T",
  "T,,hh,,====,,,,hh,,T",
  "T,,,,,,====,,,,,,,,T",
  "T,,,,,~~~~~~~,,,,,,T",
  "SSS,,~~~~~~~~~~,,SSS",
  "~~SSS~~~~~~~~~~~SS~~",
  "~~~~~~~~~~~~~~~~~~~~",
];
const TILE = {
  ",": ["GGGGG", "GgGGG", "GGGGG", "GGGgG", "GGGGG"],
  T: ["kTTTk", "TTtTT", "TtTTT", "TTTtT", "kTnTk"],
  "=": ["ppppp", "ppppp", "ppPpp", "ppppp", "ppppp"],
  "~": ["wwwww", "wWwww", "wwwww", "wwwWw", "wwwww"],
  S: ["sssss", "ssSss", "sssss", "sssSs", "sssss"],
  H: ["kkkkk", "krrrk", "rrrrr", "RRRRR", "kkkkk"],
  h: ["mmmmm", "mkmkm", "mmmmm", "mmkmm", "kkkkk"],
};
const mapPal = {
  G: "#34C759", g: "#5BD97A", T: "#1E8A3A", t: "#2FAF55", k: "#0B3D1C", n: "#5A3A1A",
  p: "#F2B04A", P: "#D9952E", w: "#2E86F0", W: "#7FC4FF", s: "#F5DE9A", S: "#E2C474",
  r: "#FF3B30", R: "#B3261E", m: "#F3F4F6",
};
const radar = field("radar", MAP[0].length * 5, MAP.length * 5, (x, y) => {
  const t = MAP[Math.floor(y / 5)][Math.floor(x / 5)];
  const ch = TILE[t][y % 5][x % 5];
  if (ch === ".") return mapPal.G;
  return mapPal[ch];
});

// Crosshair: a ring with four ticks, cream with a black outline.
const cross = field("crosshair", 25, 25, (x, y) => {
  const cx = 12, cy = 12;
  const d = Math.hypot(x - cx, y - cy);
  const ring = d >= 8 && d < 10;
  const ringEdge = (d >= 7 && d < 8) || (d >= 10 && d < 11);
  const tickV = Math.abs(x - cx) <= 1 && (y <= 5 || y >= 19);
  const tickH = Math.abs(y - cy) <= 1 && (x <= 5 || x >= 19);
  const tickEdgeV = Math.abs(x - cx) === 2 && (y <= 6 || y >= 18);
  const tickEdgeH = Math.abs(y - cy) === 2 && (x <= 6 || x >= 18);
  if (ring || tickV || tickH) return "#E8E0CC";
  if (ringEdge || tickEdgeV || tickEdgeH || (Math.abs(x - cx) <= 2 && (y === 0 || y === 24)) || (Math.abs(y - cy) <= 2 && (x === 0 || x === 24)))
    return "#000000";
  return null;
});

// ---- write -----------------------------------------------------------------------

const all = [lcd, hazard, ...glyphs, radar, cross];
for (const sp of all) write(sp);
console.log(`wrote ${all.length} sprites to ${path.relative(process.cwd(), OUT)}`);

if (process.argv.includes("--sheet")) {
  // Contact sheet on slate, for eyeballing.
  const S = 6, pad = 4, cols = 8;
  const cells = all.filter((s) => s.w <= 25);
  const cw = 26, rows = Math.ceil(cells.length / cols);
  const W = cols * (cw + pad) * S, H = rows * (cw + pad) * S + radar.h * 3;
  const buf = Buffer.alloc(W * H * 4);
  for (let i = 0; i < W * H; i++) buf.set([0x1a, 0x3a, 0x36, 255], i * 4);
  const blit = (sp, ox, oy, s) => {
    for (let y = 0; y < sp.h * s; y++)
      for (let x = 0; x < sp.w * s; x++) {
        const c = sp.px(Math.floor(x / s), Math.floor(y / s));
        if (c[3] && ox + x < W && oy + y < H) buf.set(c, ((oy + y) * W + ox + x) * 4);
      }
  };
  cells.forEach((sp, i) => blit(sp, (i % cols) * (cw + pad) * S, Math.floor(i / cols) * (cw + pad) * S, S));
  blit(radar, 0, rows * (cw + pad) * S, 3);
  fs.writeFileSync("/tmp/pocket-os-sheet.png", png(W, H, buf));
  console.log("sheet: /tmp/pocket-os-sheet.png");
}
