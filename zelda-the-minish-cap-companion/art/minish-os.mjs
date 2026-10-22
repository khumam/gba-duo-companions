// Original pixel art for the "Minish-OS (Picori Pedestal)" companion: leather,
// wood and brass materials, Ezlo, map markers, and the Hyrule map in two
// scales (Human and Minish). Every sprite is rows of palette characters,
// written as PNG at SCALE x with nearest-neighbour blocks. No dependencies.
// Item icons and the world map are the game's own, drawn at runtime from the
// player's ROM (rom_gfx.lua); this script draws only what the ROM doesn't give.
//
//   node art/minish-os.mjs            writes assets/ui/*.png
//   node art/minish-os.mjs --sheet    also writes /tmp/minish-os-sheet.png

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
  k: "#18181B", w: "#FFFFFF", p: "#FEF3C7", P: "#E9C98A",
  l: "#78350F", L: "#5A2609", m: "#9A4A16", d: "#3B1A06",
  y: "#EAB308", Y: "#A16207", h: "#FDE68A",
  g: "#22C55E", G: "#15803D", e: "#10B981",
  t: "#06B6D4", T: "#0E7490", b: "#3B82F6", B: "#1D4ED8",
  r: "#EF4444", R: "#991B1B", o: "#F97316", s: "#A8A29E", S: "#57534E", v: "#0F172A",
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
const field = (name, w, h, fn) => {
  // Evaluated once per pixel up front, so random grain stays the same at any scale.
  const px = [];
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) px.push(hex(fn(x, y)));
  return { name, w, h, px: (x, y) => px[y * w + x] };
};

// ---- tiles -------------------------------------------------------------------

let seed = 7;
const rnd = () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;

// ---- materials ----------------------------------------------------------------

// Leather: brown with a scatter of darker and lighter grain.
const leather = field("leather", 16, 16, () => {
  const n = rnd();
  return n < 0.12 ? "#6A2E0C" : n > 0.92 ? "#86400F" : "#78350F";
});
// Dark wood planks for the map frame: 16px planks with a seam and grain.
const wood = field("wood", 16, 16, (x, y) => {
  if (y === 7 || y === 15) return "#24110A";
  const n = rnd();
  return n < 0.15 ? "#3A1D0E" : n > 0.9 ? "#5A2F17" : "#4A2512";
});
// Parchment: cream with faint fibres.
const parchment = field("parchment", 16, 16, () => {
  const n = rnd();
  return n < 0.07 ? "#F5E4A8" : n > 0.95 ? "#FFF8DC" : "#FEF3C7";
});

const rivet = sprite("rivet", [
  "..kkkk..",
  ".kYyyYk.",
  "kYyhhyYk",
  "kyhwhyyk",
  "kyhhyyYk",
  "kYyyyYYk",
  ".kYYYYk.",
  "..kkkk..",
]);

// ---- map markers ---------------------------------------------------------------

const linkMark = sprite("mark-link", [
  "...kkkk...",
  "..kggggk..",
  ".kgggggGk.",
  "kggggggGGk",
  "kkkkkkkkkk",
  "kppkppkppk",
  "kpkkppkkpk",
  ".kppppppk.",
  "..kpppk...",
  "...kkk....",
]);
const portal = sprite("mark-portal", [
  "..kkkkkk..",
  ".kttttttk.",
  "ktTkkkkTtk",
  "ktkvvvvktk",
  "ktkvttvktk",
  "ktkvttvktk",
  "ktkvvvvktk",
  "ktTkkkkTtk",
  ".kttttttk.",
  "..kkkkkk..",
]);
const boss = sprite("mark-boss", [
  "kk......kk",
  "krk....krk",
  ".krkkkkrk.",
  "..krrrrk..",
  ".krwrrwrk.",
  ".krrrrrrk.",
  ".krkrrkrk.",
  "..krrrrk..",
  "...kkkk...",
  "..........",
]);

const check = sprite("check", [
  "......kk",
  ".....kgk",
  "kk..kgk.",
  "kgkkgk..",
  ".kggk...",
  "..kk....",
]);

// ---- leaves (pixel sprouts) -------------------------------------------------------------

/**
 * Chunky pixel sprout in the style of leafsample.png: flat green leaves, black
 * outline, a light highlight hugging the upper edge, a teal shadow hugging the
 * lower edge, a few darker flecks down the middle. No veins, no gradients.
 */
function sprout(name, w, h, specs) {
  const C = { k: "#1B1B1B", g: "#5B9E48", h: "#86D46E", G: "#4A8A3C", t: "#3E8C7A" };
  const geo = (x, y, s) => {
    const a = (s.a * Math.PI) / 180;
    const dx = x + 0.5 - s.bx, dy = y + 0.5 - s.by;
    const u = dx * Math.cos(a) + dy * Math.sin(a);
    const v = -dx * Math.sin(a) + dy * Math.cos(a);
    const half = u < 0 || u > s.L ? -1 : s.W * Math.pow(Math.sin((Math.PI * u) / s.L), 0.6);
    return { u, v, half };
  };
  const top = (x, y) => {
    let hit = -1;
    specs.forEach((s, i) => { const g = geo(x, y, s); if (g.half >= 0 && Math.abs(g.v) <= g.half) hit = i; });
    return hit;
  };
  return field(name, w, h, (x, y) => {
    const i = top(x, y);
    if (i < 0) return null;
    for (const [nx, ny] of [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]]) {
      const j = nx < 0 || ny < 0 || nx >= w || ny >= h ? -1 : top(nx, ny);
      if (j < i) return C.k;
    }
    const s = specs[i], g = geo(x, y, s);
    const edge = g.half - Math.abs(g.v);
    const upper = s.a < -90 ? g.v > 0 : g.v < 0; // the side facing the sky
    if (edge < 1.6) return upper ? C.h : C.t;
    if (Math.abs(g.v) < 0.7 && g.u > s.L * 0.35 && g.u < s.L * 0.8 && Math.floor(g.u) % 3 === 0) return C.G;
    return C.g;
  });
}
const mirror = (name, sp) => ({ name, w: sp.w, h: sp.h, px: (x, y) => sp.px(sp.w - 1 - x, y) });

// Plaque corners: the two-leaf sprout, opening up-left / up-right.
const SPROUT = [
  { bx: 9, by: 17, a: -128, L: 11, W: 3.4 },
  { bx: 9, by: 17, a: -50, L: 16, W: 4.4 },
];
const sprig = sprout("leaf-l", 22, 18, SPROUT);
const sprigR = mirror("leaf-r", sprig);
// Dock corners: a fuller sprout with a third leaf.
const bunch = sprout("leaves-big-l", 30, 24, [
  { bx: 14, by: 23, a: -140, L: 13, W: 3.6 },
  { bx: 14, by: 23, a: -95, L: 14, W: 3.6 },
  { bx: 14, by: 23, a: -45, L: 18, W: 4.6 },
]);
const bunchR = mirror("leaves-big-r", bunch);

// Backdrop: faint pixel sprouts scattered on the green, seamless 48px tile.
const canopy = (() => {
  const one = sprout("_canopy", 48, 48, [
    { bx: 10, by: 20, a: -142, L: 7, W: 2.2 }, { bx: 10, by: 20, a: -40, L: 10, W: 2.8 },
    { bx: 34, by: 42, a: -142, L: 7, W: 2.2 }, { bx: 34, by: 42, a: -40, L: 10, W: 2.8 },
  ]);
  const tone = { "1b1b1b": "#1A4330", "5b9e48": "#235640", "86d46e": "#2A6248", "4a8a3c": "#21503B", "3e8c7a": "#1F4C3A" };
  return field("canopy", 48, 48, (x, y) => {
    const c = one.px(x, y);
    if (!c[3]) return "#1E4A34";
    return tone[c.slice(0, 3).map((v) => v.toString(16).padStart(2, "0")).join("")] ?? "#1E4A34";
  });
})();

// ---- A / B gem discs ----------------------------------------------------------------------

// A faceted gem set in a notched gold bezel, lit from the top-left.
function gem(name, base) {
  const S = 34, c = (S - 1) / 2;
  const mixc = (a, b, t) => "#" + [1, 3, 5].map((i) => {
    const x = parseInt(a.slice(i, i + 2), 16), y = parseInt(b.slice(i, i + 2), 16);
    return Math.round(x + (y - x) * t).toString(16).padStart(2, "0");
  }).join("");
  return field(name, S, S, (x, y) => {
    const dx = x - c, dy = y - c, d = Math.hypot(dx, dy);
    if (d > 16.6) return null;
    if (d > 15.6) return "#18181B";
    const light = (-dx - dy) / (2 * 16); // +1 top-left .. -1 bottom-right
    if (d > 12.2) {
      // gold bezel with notches every 30 degrees
      const ang = Math.atan2(dy, dx);
      const notch = Math.abs(((ang / (Math.PI / 6)) % 1 + 1) % 1 - 0.5) < 0.08;
      if (notch) return "#8A5A0B";
      return light > 0.25 ? "#FDE68A" : light > -0.2 ? "#EAB308" : "#A16207";
    }
    if (d > 11.2) return "#5B2C06";
    // facets: 8 wedges alternating tone, plus radial falloff
    const ang = Math.atan2(dy, dx);
    const wedge = Math.floor(((ang + Math.PI) / (Math.PI / 4))) % 2;
    let col = mixc(base.mid, wedge ? base.lite : base.dark, 0.35);
    col = mixc(col, light > 0 ? base.lite : base.dark, Math.min(0.6, Math.abs(light) * 0.9));
    if (d < 4.5) col = mixc(col, base.lite, 0.35); // table facet
    // shine: crescent at top-left + sparkle
    if (dx < -2 && dy < -2 && d > 6.5 && d < 9) return "#FFFFFF";
    if (x === Math.round(c + 5) && y === Math.round(c - 6)) return "#FFFFFF";
    // dither for texture
    if ((x + y) % 2 === 0 && d > 7) col = mixc(col, base.dark, 0.12);
    return col;
  });
}
const gemA = gem("gem-a", { lite: "#FCA5A5", mid: "#DC2626", dark: "#7F1D1D" });
const gemB = gem("gem-b", { lite: "#93C5FD", mid: "#2563EB", dark: "#1E3A8A" });

// ---- frame materials ---------------------------------------------------------------

const bolt = sprite("bolt", [
  ".kkkk.",
  "kwsssk",
  "ksSsSk",
  "kssSsk",
  "ksSssk",
  ".kkkk.",
], { s: "#C7CDD4", S: "#6B7280" });
const triL = sprite("tri-left", [
  "...k",
  "..ky",
  ".kyy",
  "kyyy",
  "kyyy",
  ".kyy",
  "..ky",
  "...k",
]);
const triR = sprite("tri-right", [
  "k...",
  "yk..",
  "yyk.",
  "yyyk",
  "yyyk",
  "yyk.",
  "yk..",
  "k...",
]);

// Minish portal: a stone arch with a purple glow.
const door = sprite("mark-door", [
  "..kkkk..",
  ".kSSSSk.",
  "kSppppSk",
  "kSpvvpSk",
  "kSpvvpSk",
  "kSpvvpSk",
  "kSpvvpSk",
  "kkkkkkkk",
], { S: "#A8A29E", p: "#7C3AED", v: "#2E1065" });

// Green rupee for the header.
const rupee = sprite("rupee-green", [
  "...kk...",
  "..kghk..",
  ".kgghhk.",
  "kgGghhgk",
  "kgGghhgk",
  "kgGghhgk",
  "kgGghhgk",
  "kgGghhgk",
  ".kGGggk.",
  "..kGGk..",
  "...kk...",
], { h: "#BBF7D0" });

// ---- map ---------------------------------------------------------------------------

// The overworld laid out like the game's (original pixels, the game's geography),
// so Link's real overworld coordinates (main.lua: x/0xF90, y/0xC60) land on the
// right terrain. Mt. Crenel north-west, Hyrule Castle north, Lake Hylia
// north-east, Hyrule Town centre, Trilby Highlands west, Lon Lon Ranch east,
// Castor Wilds south-west, Minish Woods south-east. 24x22 tiles of 5px.
// T tree, , grass, . dirt, = path, M mountain, A snowy peak, r rocks,
// ~ water, C castle, B town roofs, S swamp, H hut.
const TERRAIN = [
  "AMMAMMr,,,,CCCC,,,,~~~~~",
  "MMAMMMr,,,,CCCC,,,~~~~~~",
  "MMMMMr,,,,,,==,,,,~~~~~~",
  "MMMMr.,TT,,,==,,,,,~~~~~",
  "rMMr..,TT,,,==,,,,,,~~~,",
  "rrr.===,,,,,==,,,,,,,,,,",
  ",,.=,,,,,,,,==,,,,,,,,,,",
  ",,,=,,TT,,,,==,,TT,,,,,,",
  ",,,=,,TT,,,BBBB,,,,,,H,,",
  ",,,=======BBBBB========,",
  ",,,,,,,,,,BBBBB,,,,,,H,,",
  ",TT,,,,,,,,,==,,,,,,,,,,",
  "TTTT,,,,,,,,==,,,,,,,TT,",
  ",TT,,,,,,,,,==,,,,,TTTTT",
  "SSS,,,,,,,,,==,,,,TTTTTT",
  "SSSS,,,,,,,,========TTTT",
  "SSSSS,,,,,,,,,,,,,,=TTTT",
  "SSSSS,,,,,,,,,,,,TT=TTTT",
  "rSSSS,,,,,,,,,,,TTT=TTTT",
  "rrSS,,,,,,,,,,,TTTT=TTTT",
  "rrr,,,,,,,,,,,TTTTTTTTTT",
  "rrrr,,,,,,,,,TTTTTTTTTTT",
];
TERRAIN.forEach((r, i) => { if (r.length !== 24) throw new Error(`TERRAIN row ${i} is ${r.length}`); });
const TP = {
  g: "#7CC24A", G: "#5FAE3A", d: "#D6B98A", D: "#C9A574", p: "#EAD9AE", P: "#D9C28E",
  t: "#3F8F3A", T: "#2D6B2C", u: "#5BAE4A", k: "#1F3D1E",
  m: "#A9876A", M: "#8B6A4E", w: "#F5F5F4", s: "#D6D3D1",
  r: "#B49A7C", R: "#8F7558", h: "#B45309", H: "#7C2D12", c: "#E7D3A8",
  b: "#3B82F6", B: "#60A5FA", q: "#D6D3D1", Q: "#78716C", o: "#DC2626",
  e: "#5B7A3A", E: "#466232", y: "#6B8E4E",
};
const TT = {
  ",": ["ggGgg", "gggGg", "Ggggg", "ggggG", "gGggg"],
  ".": ["ddDdd", "dddDd", "Ddddd", "ddddD", "dDddd"],
  "=": ["ppPpp", "ppppP", "Ppppp", "pppPp", "ppppp"],
  T: [",kTk,", "kTtTk", "Ttutt", "kTtTk", ",kTk,"],
  M: ["..m..", ".mMm.", "mMMMm", "MMmMM", "MMMMM"],
  A: ["..w..", ".wsw.", "mwsMm", "MMmMM", "MMMMM"],
  r: ["rRrrr", "rrrRr", "Rrrrr", "rrRrr", "rrrrR"],
  H: [",hhh,", "hhHhh", "HHHHH", "cHcHc", "ccccc"],
  "~": ["bbbbb", "bBbbb", "bbbbb", "bbbBb", "bbbbb"],
  C: ["qQqQq", "qqqqq", "qQQQq", "qQkQq", "qqqqq"],
  B: ["ooHoo", "oHHHo", "ccccc", "cHcHc", "ppppp"],
  S: ["eEeye", "EbEeE", "eEeyb", "yeEeE", "bEyEe"],
};
const terrain = field("map-terrain", 120, 110, (x, y) => {
  const t = TERRAIN[Math.floor(y / 5)][Math.floor(x / 5)];
  let ch = TT[t][y % 5][x % 5];
  if (ch === ",") ch = (x + y) % 3 ? "g" : "G";
  if (ch === ".") ch = (x * 7 + y) % 5 ? "d" : "D";
  return TP[ch];
});

// ---- original icons for what the ROM sprite tables don't give us ----------------
// (rom_gfx.lua draws every other item icon from the player's ROM.)

// Kinstone half: a jagged-edged half disc, one per colour.
const KIN = [
  "....kkkk........",
  "..kkcccckk......",
  ".kcchhcccck.....",
  ".kchhcccccck....",
  "kcchccccccck....",
  "kccccccccccck...",
  "kcccccccccDck...",
  "kccccccccDDk....",
  "kcccccccDDk.....",
  ".kcccccDDDk.....",
  ".kccccDDDk......",
  "..kkcDDDkk......",
  "....kkkk........",
];
const kinstone = (name, c, h, D) => sprite(name, KIN, { c, h, D });
const kinRed = kinstone("kinstone-red", "#EF4444", "#FCA5A5", "#991B1B");
const kinBlue = kinstone("kinstone-blue", "#3B82F6", "#BFDBFE", "#1D4ED8");
const kinGreen = kinstone("kinstone-green", "#22C55E", "#BBF7D0", "#15803D");
const kinGold = kinstone("kinstone-gold", "#EAB308", "#FEF08A", "#A16207");

// A little figure on a pedestal.
const figurine = sprite("figurine", [
  ".....kkk.....",
  "....kyyyk....",
  "....kyhyk....",
  ".....kyk.....",
  "...kkyyykk...",
  "..kyyyyyyyk..",
  "...kkyyykk...",
  ".....kyk.....",
  "....kyykk....",
  "...kYkkYk....",
  "..kkkkkkkkk..",
  "..kllllllLk..",
  "..kkkkkkkkk..",
]);

// A green pointed cap: stands in for Ezlo when the ROM can't give his sprite.
const cap = sprite("cap", [
  "..........kk....",
  ".........kck....",
  "........kcck....",
  ".......kcCck....",
  "......kccCk.....",
  ".....kcccCk.....",
  "....kchccCk.....",
  "...kchcccCCk....",
  "..kchccccCCk....",
  "..kcccccccCCk...",
  ".kccccccccCCk...",
  ".kcccccccccCCk..",
  "kkkkkkkkkkkkkkk.",
  "kbbbbbbbbbbbbbk.",
  ".kkkkkkkkkkkkk..",
], { c: "#22C55E", C: "#15803D", h: "#BBF7D0", b: "#F5E6B8" });

// A butterfly (the three Mysterious Shells butterflies share it).
const butterfly = sprite("butterfly", [
  ".kk.......kk.",
  "kttk.....kttk",
  "kthtk...kthtk",
  "ktttkk.kktttk",
  ".kttTkkkTttk.",
  "..kkTkdkTkk..",
  "..kttkdkttk..",
  ".kttTk.kTttk.",
  ".kttk...kttk.",
  "..kk.....kk..",
]);

// A folded map.
const hyruleMap = sprite("hyrule-map", [
  "kkkkkkkkkkkkk",
  "kpPpkpPpkpPpk",
  "kgpPkpgPkPpgk",
  "kpgpkgpgkpggk",
  "kPpgkbbpkgpPk",
  "kpPpkbbgkpPpk",
  "kgpgkpPpkgpgk",
  "kpPpkpgpkrrpk",
  "kPpgkPpPkrPgk",
  "kkkkkkkkkkkkk",
]);

// A nut (Jabber Nut).
const jabberNut = sprite("jabber-nut", [
  "....kkkk....",
  "..kkmmmmkk..",
  ".kmmhmmmmmk.",
  ".kmhmmmmmmk.",
  "kmmmmmmmmmLk",
  "kmmmmmmmmLLk",
  "kmmmmmmmLLLk",
  ".kmmmmmLLLk.",
  ".kLmmLLLLLk.",
  "..kkLLLLkk..",
  "....kkkk....",
]);

// Anything else with no icon: a parchment tag with a question mark.
const unknownIcon = sprite("item-unknown", [
  "kkkkkkkkkk",
  "kppppppppk",
  "kppkkkkppk",
  "kpkppppkpk",
  "kppppppkpk",
  "kppppkkppk",
  "kppppkpppk",
  "kppppppppk",
  "kppppkpppk",
  "kkkkkkkkkk",
]);

const all = [leather, wood, parchment, rivet, linkMark, portal, boss, check,
  sprig, sprigR, bunch, bunchR, canopy, gemA, gemB, bolt, triL, triR, door, rupee, terrain,
  kinRed, kinBlue, kinGreen, kinGold, figurine, butterfly, hyruleMap, jabberNut, unknownIcon, cap];
for (const sp of all) write(sp);
console.log(`wrote ${all.length} sprites to ${path.relative(process.cwd(), OUT)}`);

if (process.argv.includes("--sheet")) {
  const S = 4, gap = 8;
  const W = all.reduce((a, s) => a + s.w * S + gap, 0), H = Math.max(...all.map((s) => s.h)) * S;
  const buf = Buffer.alloc(W * H * 4);
  for (let i = 0; i < W * H; i++) buf.set([0x2e, 0x3a, 0x4a, 255], i * 4);
  let ox = 0;
  for (const sp of all) {
    for (let y = 0; y < sp.h * S; y++)
      for (let x = 0; x < sp.w * S; x++) {
        const c = sp.px(Math.floor(x / S), Math.floor(y / S));
        if (c[3]) buf.set(c, (y * W + ox + x) * 4);
      }
    ox += sp.w * S + gap;
  }
  fs.writeFileSync("/tmp/minish-os-sheet.png", png(W, H, buf));
  console.log("sheet: /tmp/minish-os-sheet.png");
}
