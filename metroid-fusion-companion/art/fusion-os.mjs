// Pixel art for the Metroid Fusion companion, drawn after the game's own map and
// status windows: navy grid field, lilac rooms, L1-L4 hatch icons. Every sprite is
// rows of palette characters (or computed per pixel), written as PNG at SCALE device
// px per art px with nearest-neighbour blocks. All original art, no game graphics.
//
//   node art/fusion-os.mjs            writes assets/ui/*.png
//   node art/fusion-os.mjs --sheet    also writes /tmp/fusion-os-sheet.png

import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(here, "..", "assets", "ui");
const SCALE = 3;
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
  return [0, 2, 4].map((i) => parseInt(v.slice(i, i + 2), 16)).concat(v.length === 8 ? parseInt(v.slice(6), 16) : 255);
};

// Sampled from the game's map screen.
const P = {
  ".": null,
  k: "#0A0F1F", n: "#101B36", N: "#1F4A8E",
  w: "#FFFFFF", s: "#C9D3D0", S: "#7E8E8C",
  l: "#E0A0E8", L: "#B07CC0", r: "#F05068", R: "#A02840",
  y: "#F8D060", Y: "#B08A20", c: "#F8E8B0",
  g: "#58E080", G: "#1E7A3C", D: "#0E2A1C",
  b: "#3FA8F0", B: "#1C5E9E", o: "#F0B070", O: "#A8683A",
  x: "#6E6E78", X: "#3C3C46",
};

function sprite(name, rows, extra = {}) {
  const pal = { ...P, ...extra };
  const w = rows[0].length;
  rows.forEach((r, i) => {
    if (r.length !== w) throw new Error(`${name}: row ${i} is ${r.length} wide, expected ${w}`);
    for (const ch of r) if (!(ch in pal)) throw new Error(`${name}: unknown colour '${ch}'`);
  });
  return { name, w, h: rows.length, px: (x, y) => hex(pal[rows[y][x]]) };
}
const field = (name, w, h, fn) => ({ name, w, h, px: (x, y) => hex(fn(x, y)) });

function write(sp, scale = SCALE) {
  const W = sp.w * scale, H = sp.h * scale;
  const buf = Buffer.alloc(W * H * 4);
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) buf.set(sp.px(Math.floor(x / scale), Math.floor(y / scale)), (y * W + x) * 4);
  fs.writeFileSync(path.join(OUT, `${sp.name}.png`), png(W, H, buf));
  return sp;
}

// ---- tiles -------------------------------------------------------------------

// The map field: navy cells split by 2px blue lines, 16x16 and seamless.
const grid = field("grid", 16, 16, (x, y) => {
  if (x === 0 || y === 0) return "#25539C";
  if (x === 1 || y === 1) return "#1A3A74";
  return "#101B36";
});

// Brushed metal for the frame, 8x8 and seamless: light bands with a faint scratch.
const metal = field("metal", 8, 8, (x, y) => {
  if (y === 0) return "#E4ECE9";
  if (y === 7) return "#9AA8A5";
  if ((x * 3 + y * 5) % 11 === 0) return "#B8C4C1";
  return "#CBD6D3";
});

// ---- glyphs --------------------------------------------------------------------

const glyphs = [
  // Energy tank: full is a lit yellow cell, empty a dark socket.
  sprite("tank-on", [
    "YYYYYYY",
    "Yyyyyyc",
    "Yyccyyc",
    "Yyccyyc",
    "Yyyyyyc",
    "YcccccY",
  ]),
  sprite("tank-off", [
    "SSSSSSS",
    "SkkkkkS",
    "SkkkkkS",
    "SkkkkkS",
    "SkkkkkS",
    "SSSSSSS",
  ]),
  // Hatch icons for the security levels: a door slab with a lock block at the right.
  ...[["1", "b", "B"], ["2", "g", "G"], ["3", "o", "O"], ["4", "r", "R"]].map(([n, hi, lo]) =>
    sprite(`hatch-${n}`, [
      "wwwwwwwwwwww",
      `w${hi}${hi}${hi}${hi}${hi}${hi}${hi}${hi}${hi}${hi}w`,
      `w${hi}${hi}${hi}${hi}${hi}${hi}${lo}${lo}${hi}${hi}w`,
      `w${lo}${lo}${lo}${lo}${lo}${lo}${lo}${lo}${lo}${lo}w`,
      "wwwwwwwwwwww",
    ])),
  // Map room cells: explored lilac, unexplored grey, both in the game's white outline.
  sprite("chip-on", [
    "wwwwww",
    "wllllw",
    "wllllw",
    "wllllw",
    "wllllw",
    "wwwwww",
  ]),
  sprite("chip-off", [
    "wwwwww",
    "wxxxxw",
    "wxxxxw",
    "wxxxxw",
    "wxxxxw",
    "wwwwww",
  ]),
  // Samus's marker on the map: a red ring around a yellow dot.
  sprite("here", [
    "..rrrrr..",
    ".rr...rr.",
    "rr.....rr",
    "r...y...r",
    "r..yyy..r",
    "r...y...r",
    "rr.....rr",
    ".rr...rr.",
    "..rrrrr..",
  ]),
  // Status LEDs for the ability rows.
  sprite("led-on", [
    ".GGG.",
    "Ggggg",
    "Ggwgg",
    "Ggggg",
    ".GGG.",
  ]),
  sprite("led-off", [
    ".XXX.",
    "XkkkX",
    "XkkkX",
    "XkkkX",
    ".XXX.",
  ]),
  // Downloaded-map marker: a small folded map.
  sprite("map-on", [
    "wwwwwwww",
    "wlLwlLlw",
    "wlLwlLlw",
    "wLlwLlLw",
    "wLlwLlLw",
    "wwwwwwww",
  ]),
  sprite("map-off", [
    "XXXXXXXX",
    "XkkXkkkX",
    "XkkXkkkX",
    "XkkXkkkX",
    "XkkXkkkX",
    "XXXXXXXX",
  ]),
  // Missile: cream body, red tip, grey fins.
  sprite("ic-missile", [
    "......rr.",
    "....rrrrr",
    "ssccccccr",
    "ssccccccr",
    "....rrrrr",
    "......rr.",
  ]),
  // Power bomb: a yellow sphere with a core.
  sprite("ic-pb", [
    "..YYYYY..",
    ".YyyyyyY.",
    "Yyyccccyy",
    "Yycwwwcyy",
    "Yycwwwcyy",
    "Yyyccccyy",
    ".YyyyyyY.",
    "..YYYYY..",
  ]),
  // Page-corner studs for the metal frame.
  sprite("stud", [
    ".SSS.",
    "Swwss",
    "SwsSS",
    "SssSS",
    ".SSS.",
  ]),
  // An X parasite for the waiting screen: a yellow blob around one eye.
  sprite("x-core", [
    "....YYYYY.......",
    "..YYyyyyyYY.....",
    ".Yyyyyyyyyyy.YY.",
    "Yyyyyccccyyyyyyy",
    "Yyyycwwwcyyyyyy.",
    "Yyyycwkkwcyyyyy.",
    "Yyyycwwwcyyyyyy.",
    "Yyyyyccccyyyyyy.",
    ".Yyyyyyyyyyyyy..",
    "..YYyyyyyyyYY...",
    "....YYYYYYY.....",
  ]),
];

// ---- write -----------------------------------------------------------------------

const all = [grid, metal, ...glyphs];
for (const sp of all) write(sp);
console.log(`wrote ${all.length} sprites to ${path.relative(process.cwd(), OUT)}`);

if (process.argv.includes("--sheet")) {
  const S = 8, pad = 3, cols = 6, cw = 16;
  const items = all.filter((s) => s.w <= cw && s.h <= cw);
  const rows = Math.ceil(items.length / cols);
  const W = cols * (cw + pad) * S, H = rows * (cw + pad) * S;
  const buf = Buffer.alloc(W * H * 4);
  for (let i = 0; i < W * H; i++) buf.set([0x10, 0x1b, 0x36, 255], i * 4);
  items.forEach((sp, i) => {
    const ox = (i % cols) * (cw + pad) * S, oy = Math.floor(i / cols) * (cw + pad) * S;
    for (let y = 0; y < sp.h * S; y++)
      for (let x = 0; x < sp.w * S; x++) {
        const c = sp.px(Math.floor(x / S), Math.floor(y / S));
        if (c[3]) buf.set(c, ((oy + y) * W + ox + x) * 4);
      }
  });
  fs.writeFileSync("/tmp/fusion-os-sheet.png", png(W, H, buf));
  console.log("sheet: /tmp/fusion-os-sheet.png");
}
