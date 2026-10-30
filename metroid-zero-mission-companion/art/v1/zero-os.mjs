// Pixel art for the "Zero-OS" Metroid: Zero Mission companion: the visor's
// glyphs, toggle nodes, hazard/plate tiles and a placeholder area map. Every
// sprite is a bitmap drawn as rows of palette characters (or computed per
// pixel), written out as PNG at SCALE x with nearest-neighbour blocks, so the
// art stays crisp however the engine scales it. All original art; no game
// graphics. No dependencies: the PNG encoder is the ~30 lines below.
//
//   node art/zero-os.mjs            writes assets/ui/*.png
//   node art/zero-os.mjs --sheet    also writes /tmp/zero-os-sheet.png

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

// The guide's tokens, plus a few shades between them.
const P = {
  ".": null,
  k: "#000000", v: "#0B0E14", f: "#1B232E", h: "#2E3A4A", d: "#161E2E",
  c: "#00F0FF", C: "#0094A8", e: "#9FFBFF",
  y: "#FFE600", Y: "#B89A00",
  o: "#FF5500", O: "#A83400",
  m: "#FF0077", M: "#A0004C", p: "#FF7AB8",
  w: "#EDF2F7", s: "#8A97A8", S: "#56637A",
  g: "#3DDC84", G: "#1C8A4E",
};

/** A sprite: rows of equal-length strings. Returns {name, w, h, px(x,y)->rgba}. */
function sprite(name, rows, extra = {}) {
  const pal = { ...P, ...extra };
  const w = rows[0].length;
  rows.forEach((r, i) => {
    if (r.length !== w) throw new Error(`${name}: row ${i} is ${r.length} wide, expected ${w}`);
    for (const ch of r) if (!(ch in pal)) throw new Error(`${name}: unknown colour '${ch}'`);
  });
  return { name, w, h: rows.length, px: (x, y) => hex(pal[rows[y][x]]) };
}

/** A sprite computed per pixel (fn returns a colour string or null). */
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

// Hazard: 45-degree amber/black stripes, 6px wide on a 12px period.
const hazard = field("hazard", 12, 12, (x, y) => ((x + y) % 12 < 6 ? "#FFB800" : "#0B0E14"));

// Hull plate: void-black with faint circuit conduits and a node, 32x32, tiles seamlessly.
const plate = field("plate", 32, 32, (x, y) => {
  const trace = "#121A26", node = "#16303A";
  if ((x === 5 && y < 14) || (y === 13 && x >= 5 && x < 20) || (x === 19 && y >= 13) ) return trace;
  if ((y === 26 && x >= 24) || (y === 26 && x < 4) || (x === 27 && y < 6) || (y === 5 && x >= 27)) return trace;
  if (Math.abs(x - 19) <= 1 && Math.abs(y - 13) <= 1) return node;
  if (Math.abs(x - 5) <= 1 && Math.abs(y - 26) <= 1) return node;
  return "#0B0E14";
});

// Map viewport backdrop: one 8x8 GBA map cell, a 1px coordinate line on dark blue-grey.
const grid = field("grid", 8, 8, (x, y) => (x === 0 || y === 0 ? "#111A2B" : "#080C14"));

// ---- glyphs --------------------------------------------------------------------

const glyphs = [
  // A steel rivet with a highlight.
  sprite("rivet", [
    ".kkk.",
    "kswsk",
    "ksssk",
    "kSSSk",
    ".kkk.",
  ]),
  // A glowing corner node.
  sprite("node", [
    "..C..",
    ".CcC.",
    "CcecC",
    ".CcC.",
    "..C..",
  ]),
  // Missile: orange body, yellow warhead, fins.
  sprite("ic-missile", [
    "...........",
    "kk..kkkkk..",
    "kokkoooooyk",
    "kooooooooyy",
    "kokkOOOOOyk",
    "kk..kkkkk..",
    "...........",
  ]),
  // Super missile: magenta, fatter warhead.
  sprite("ic-super", [
    "..........k",
    "kk..kkkkkk.",
    "kmkkmmmmmpk",
    "kmmmmmmmmpp",
    "kmkkMMMMMpk",
    "kk..kkkkkk.",
    "..........k",
  ]),
  // Power bomb: a yellow orb with an orange core.
  sprite("ic-pbomb", [
    "..kkk..",
    ".kyyyk.",
    "kyyoyyk",
    "kyoooyk",
    "kyyoyYk",
    ".kyYYk.",
    "..kkk..",
  ]),
  // Antenna bars.
  sprite("ic-signal", [
    "......kk",
    "......kc",
    "....kkkc",
    "....kckc",
    "..kkkckc",
    "..kckckc",
    "kkkckckc",
    "kckckckc",
  ]),
  // Battery badge.
  sprite("ic-battery", [
    "kkkkkkkkk.",
    "kgggggggkk",
    "kgggggggkk",
    "kgggggggkk",
    "kkkkkkkkk.",
  ]),
  // Toggle nodes: equipped (checked box), owned but off (empty ring), not found (dim slot).
  sprite("node-on", [
    "kkkkkkkkk",
    "kccccccck",
    "kcccccvck",
    "kccccvvck",
    "kcvccvcck",
    "kcvvvvcck",
    "kccvvccck",
    "kccccccck",
    "kkkkkkkkk",
  ]),
  sprite("node-off", [
    "..kkkkk..",
    ".kccccck.",
    "kcCkkkCck",
    "kckvvvkck",
    "kckvvvkck",
    "kckvvvkck",
    "kcCkkkCck",
    ".kccccck.",
    "..kkkkk..",
  ]),
  sprite("node-lock", [
    "..kkkkk..",
    ".kSSSSSk.",
    "kSkkkkkSk",
    "kSkvvvkSk",
    "kSkSSSkSk",
    "kSkvvvkSk",
    "kSkkkkkSk",
    ".kSSSSSk.",
    "..kkkkk..",
  ]),
  // Samus on the map: an original power-suit helmet with a green visor.
  sprite("mk-samus", [
    "..kkkk..",
    ".kooook.",
    "kooyyook",
    "kogggGok",
    "koggGGok",
    "kOooooOk",
    ".kOkkOk.",
    "..k..k..",
  ]),
  // Target crosshair for the map: four cyan ticks around the cell.
  field("crosshair", 17, 17, (x, y) => {
    const c = 8;
    const ax = Math.abs(x - c), ay = Math.abs(y - c);
    const tick = (ax === 0 && ay >= 6) || (ay === 0 && ax >= 6);
    const edge = (ax === 1 && ay >= 5) || (ay === 1 && ax >= 5) || (ax === 0 && ay === 5) || (ay === 0 && ax === 5);
    const corner = (ax === 6 && ay >= 4 && ay <= 6) || (ay === 6 && ax >= 4 && ax <= 6);
    if (tick) return "#EDF2F7";
    if (corner) return "#00F0FF";
    if (edge) return "#000000";
    return null;
  }),
  // A white stylus hand, pointing up.
  sprite("hand", [
    "...kk.......",
    "..kwwk......",
    "..kwwk......",
    "..kwwk......",
    "..kwwkkkk...",
    "..kwwkwwkkk.",
    "kkkwwkwwkwwk",
    "kwkwwwwwwwwk",
    "kwwwwwwwwwwk",
    ".kwwwwwwwwsk",
    ".kwwwwwwwsk.",
    "..kwwwwwwsk.",
    "..kwwwwwssk.",
    "...kkkkkkk..",
  ]),
  // Map legend pieces at map scale.
  sprite("lg-save", [
    "kkkkkkkk",
    "kyyyyyyk",
    "kyykkkyk",
    "kykyyyyk",
    "kyykkyyk",
    "kyyyykyk",
    "kykkkyyk",
    "kkkkkkkk",
  ]),
  sprite("lg-boss", [
    "kkkkkkkk",
    "kMMMMMMk",
    "kMwwwwMk",
    "kwkwwkwk",
    "kwwwwwwk",
    "kMwkwkMk",
    "kMMMMMMk",
    "kkkkkkkk",
  ]),
  sprite("lg-item", [
    "kkkkkkkk",
    "kbbbbbbk",
    "kbbkkbbk",
    "kbkwwkbk",
    "kbkwwkbk",
    "kbbkkbbk",
    "kbbbbbbk",
    "kkkkkkkk",
  ], { b: "#1E3A8A" }),
  sprite("lg-door", [
    "kkkkkkkk",
    "kbbbbbmk",
    "kbbbbbmk",
    "kbbbbbmk",
    "kbbbbbmk",
    "kbbbbbmk",
    "kbbbbbmk",
    "kkkkkkkk",
  ], { b: "#1E3A8A" }),
  sprite("lg-hazard", [
    "kkkkkkkk",
    "kooooook",
    "korrrrok",
    "korrrrok",
    "korrrrok",
    "korrrrok",
    "kooooook",
    "kkkkkkkk",
  ], { r: "#4A1A0A" }),
  // Boss log marks.
  sprite("ic-skull", [
    "..kkkkk..",
    ".kwwwwwk.",
    "kwwwwwwwk",
    "kwkkwkkwk",
    "kwkkwkkwk",
    "kwwwkwwwk",
    ".kwkwkwk.",
    ".kwwwwwk.",
    "..kkkkk..",
  ]),
  sprite("ic-etank", [
    "kkkkkkkkk",
    "kyyyyyyyk",
    "kyhhhhhyk",
    "kyhwhhhyk",
    "kyhhhhhyk",
    "kyhhhhhyk",
    "kyyyyyyyk",
    "kkkkkkkkk",
  ]),
  sprite("ic-clock", [
    "..kkkkk..",
    ".kwwwwwk.",
    "kwwwkwwwk",
    "kwwwkwwwk",
    "kwwwkkkwk",
    "kwwwwwwwk",
    "kwwwwwwwk",
    ".kwwwwwk.",
    "..kkkkk..",
  ]),
  // Dock: full map, armory (arm cannon) and logbook (data pad).
  sprite("dock-map", [
    "kkkkkkkkkkkkkk",
    "kbbbbbbkbbbbbk",
    "kbbbbbbkbbbbbk",
    "kbbkkkkkbbybbk",
    "kbbk..kbbbbbbk",
    "kkkk..kkkkbkkk",
    "k.....kbbbbbbk",
    "k.....kbbmbbbk",
    "kkkkkkkbbbbbbk",
    "kbbbbbbbbbbbbk",
    "kbbbbbbbbbbbbk",
    "kkkkkkkkkkkkkk",
  ], { b: "#3B5BD0" }),
  sprite("dock-armory", [
    "......kkkkk...",
    "....kkooooOk..",
    "..kkooooooOOk.",
    "kkssssooooOOk.",
    "kcssssooooOOk.",
    "kcssssooooOOk.",
    "kkssssooooOOk.",
    "..kkooooooOOk.",
    "....kkooooOk..",
    "......kkkkk...",
  ]),
  sprite("dock-log", [
    "kkkkkkkkkkkk",
    "kssssssssssk",
    "kskkkkkkkksk",
    "kskccccccksk",
    "kskcvvvvvksk",
    "kskccccvvksk",
    "kskcvvvvvksk",
    "kskccvvvvksk",
    "kskkkkkkkksk",
    "ksssssyssssk",
    "kkkkkkkkkkkk",
  ]),
];

// ---- area map ------------------------------------------------------------------

// A placeholder Brinstar-like area, 36 x 22 map cells of 8x8 px (an original
// layout: shafts, corridors and rooms). main.lua will draw the real map from RAM;
// until then this is what the map modules show.
const MW = 36, MH = 22;
const cells = Array.from({ length: MH }, () => Array(MW).fill(" "));
const rect = (x0, y0, x1, y1, ch = "#") => {
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) cells[y][x] = ch;
};
rect(3, 2, 16, 2);           // top corridor
rect(3, 2, 3, 19);           // west shaft
rect(14, 1, 16, 4);          // tower room
rect(4, 4, 8, 5);            // start room
rect(3, 8, 29, 8);           // main corridor
rect(20, 3, 20, 16);         // middle shaft
rect(21, 3, 30, 4);          // north hall
rect(30, 3, 30, 12);         // east shaft
rect(20, 12, 33, 12);        // lower corridor
rect(31, 10, 33, 13, "B");   // boss chamber
rect(3, 16, 20, 16);         // acid run
rect(8, 16, 12, 16, "h");    // ... with a hazard stretch
rect(5, 18, 9, 19);          // bottom room
rect(3, 19, 14, 19);         // bottom corridor
rect(22, 15, 28, 17, ".");   // mapped, not visited
rect(15, 19, 28, 19, ".");
rect(10, 5, 12, 7);          // side room off the corridor
cells[4][25] = "S";          // save room
cells[13][3] = "S";
cells[1][15] = "o";          // items
cells[6][11] = "o";
cells[19][6] = "o";
cells[16][26] = "o";
cells[8][19] = "d";          // doors (on the cell's right edge)
cells[8][29] = "d";
cells[2][13] = "d";
cells[12][30] = "d";
cells[16][19] = "d";
cells[19][14] = "E";         // elevator down

const MAPC = {
  room: "#1E3A8A", line: "#14296A", wall: "#9DB4FF",
  dim: "#0F1D45", dimWall: "#3E5294",
  save: "#FFE600", ink: "#0B0E14",
  door: "#FF0077", hazard: "#FF5500", hazardFill: "#3A1606",
  boss: "#7A0038", bossMid: "#8C0042", bossHi: "#FF0077", item: "#EDF2F7", elev: "#00F0FF",
};
const at = (cx, cy) => (cx < 0 || cy < 0 || cx >= MW || cy >= MH ? " " : cells[cy][cx]);
const S_GLYPH = ["....", ".###", ".#..", "..#.", "...#", "###.".padEnd(4, ".")];
const areaMap = field("map-brinstar", MW * 8, MH * 8, (x, y) => {
  const cx = Math.floor(x / 8), cy = Math.floor(y / 8), ix = x % 8, iy = y % 8;
  const ch = at(cx, cy);
  if (ch === " ") return null;
  const dim = ch === ".";
  // Walls on every side that faces void.
  const wall =
    (ix === 0 && at(cx - 1, cy) === " ") || (ix === 7 && at(cx + 1, cy) === " ") ||
    (iy === 0 && at(cx, cy - 1) === " ") || (iy === 7 && at(cx, cy + 1) === " ");
  if (wall && ch === "B") return MAPC.bossHi;
  if (wall) return dim ? ((ix + iy) % 2 ? MAPC.dimWall : null) : MAPC.wall;
  if (ch === "S") {
    const gx = ix - 2, gy = iy - 1;
    if (gx >= 0 && gx < 4 && gy >= 0 && gy < 6 && S_GLYPH[gy][gx] === "#") return MAPC.ink;
    return MAPC.save;
  }
  if (ch === "B") return (cx + cy) % 2 ? MAPC.boss : MAPC.bossMid;
  if (ch === "h") {
    if (iy === 1 || iy === 6) return MAPC.hazard;
    return MAPC.hazardFill;
  }
  if (ch === "d" && ix >= 6 && iy >= 2 && iy <= 5) return MAPC.door;
  if (ch === "o" && ix >= 3 && ix <= 4 && iy >= 3 && iy <= 4) return MAPC.item;
  if (ch === "E" && ix >= 3 && ix <= 4 && iy >= 1 && iy <= 6) return MAPC.elev;
  if (ch === "E" && iy === 2 && (ix === 2 || ix === 5)) return MAPC.elev;
  if (ch === "E" && iy === 5 && (ix === 2 || ix === 5)) return MAPC.elev;
  if (ix === 0 || iy === 0) return dim ? MAPC.dim : MAPC.line;
  return dim ? MAPC.dim : MAPC.room;
});

// ---- write -----------------------------------------------------------------------

const all = [hazard, plate, grid, ...glyphs, areaMap];
for (const sp of all) write(sp);
console.log(`wrote ${all.length} sprites to ${path.relative(process.cwd(), OUT)}`);

if (process.argv.includes("--sheet")) {
  const S = 6, pad = 4, cols = 8, cw = 18;
  const cells2 = all.filter((s) => s.w <= cw && s.h <= cw);
  const rows = Math.ceil(cells2.length / cols);
  const W = Math.max(cols * (cw + pad) * S, areaMap.w * 3), H = rows * (cw + pad) * S + areaMap.h * 3;
  const buf = Buffer.alloc(W * H * 4);
  for (let i = 0; i < W * H; i++) buf.set([0x2e, 0x3a, 0x4a, 255], i * 4);
  const blit = (sp, ox, oy, s) => {
    for (let y = 0; y < sp.h * s; y++)
      for (let x = 0; x < sp.w * s; x++) {
        const c = sp.px(Math.floor(x / s), Math.floor(y / s));
        if (c[3] && ox + x < W && oy + y < H) buf.set(c, ((oy + y) * W + ox + x) * 4);
      }
  };
  cells2.forEach((sp, i) => blit(sp, (i % cols) * (cw + pad) * S, Math.floor(i / cols) * (cw + pad) * S, S));
  blit(areaMap, 0, rows * (cw + pad) * S, 3);
  fs.writeFileSync("/tmp/zero-os-sheet.png", png(W, H, buf));
  console.log("sheet: /tmp/zero-os-sheet.png");
}
