// Pixel art for the Oracle of Ages companion: the subscreen's brick frame and small item
// icons, original drawings in the game's palette. Every sprite is rows of palette characters
// written as a PNG with each art pixel SCALE device px wide (7 px = 3.035dp = 1u, see style.css).
//
//   node art/ages-os.mjs        writes assets/ui/*.png

import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import { fileURLToPath } from "node:url";

const OUT = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "assets", "ui");
const SCALE = 7;
fs.mkdirSync(OUT, { recursive: true });

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
const png = (w, h, rgba) => {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]);
};

// The subscreen's palette (sampled from the game's menu) plus colours for the icons.
const PAL = {
  k: "#251C27", d: "#452F48", w: "#FFFFFB", m: "#98596F", M: "#A9637B",
  g: "#4C9A3C", G: "#2F6B2D", y: "#E8B63C", Y: "#B5832B", b: "#4A7FD0", B: "#2A4A94",
  r: "#D0453F", R: "#8E2A2F", s: "#B7BFC6", S: "#6A737C", n: "#9A6A33", N: "#5E3D1C",
  o: "#E58A3A", p: "#F2A0B0", c: "#6BC9D6", v: "#8A5FC9", V: "#52368A", e: "#E5E5E2",
};
const hex = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));

const write = (name, rows, scale = SCALE) => {
  const h = rows.length, w = rows[0].length;
  const W = w * scale, H = h * scale;
  const buf = Buffer.alloc(W * H * 4);
  rows.forEach((row, y) => {
    if (row.length !== w) throw new Error(`${name}: row ${y} is ${row.length} wide, expected ${w}`);
    [...row].forEach((ch, x) => {
      if (ch === ".") return;
      if (!PAL[ch]) throw new Error(`${name}: unknown colour ${ch}`);
      const [r, g, b] = hex(PAL[ch]);
      for (let dy = 0; dy < scale; dy++) for (let dx = 0; dx < scale; dx++) {
        const o = ((y * scale + dy) * W + x * scale + dx) * 4;
        buf[o] = r; buf[o + 1] = g; buf[o + 2] = b; buf[o + 3] = 255;
      }
    });
  });
  fs.writeFileSync(path.join(OUT, `${name}.png`), png(W, H, buf));
};

// ---- the brick frame: an 8x8 side brick and an 8x4 top/bottom brick ----------------------------

write("brick-v", [
  "dddd",
  "wwwk",
  "wMMk",
  "wMMk",
  "wMMk",
  "wMMk",
  "wMMk",
  "kkkk",
]);
write("brick-fill", [
  "dwwwwwwk",
  "wMMMMMMk",
  "wMMMMMMk",
  "wMMMMMMk",
  "wMMMMMMk",
  "wMMMMMMk",
  "wMMMMMMk",
  "kkkkkkkk",
]);
write("brick-h", [
  "wwwwwwwk",
  "wMMMMMMk",
  "kkkkkkkk",
]);

// ---- 8x8 icons ---------------------------------------------------------------------------------

const ICONS = {
  unknown: [".kkkkkk.", "kwwwwwwk", "kwwkkwwk", "kwwwkwwk", "kwwkkwwk", "kwwwwwwk", "kwwkkwwk", ".kkkkkk."],
  ring: ["..kkkk..", ".kyyyyk.", "ky.vv.yk", "ky....yk", "ky....yk", "ky....yk", ".kyyyyk.", "..kkkk.."],
  "heart-full": [".kk..kk.", "krrkkrrk", "krwrrrrk", "krrrrrrk", ".krrrrk.", "..krrk..", "...kk...", "........"],
  "heart-half": [".kk..kk.", "krrkkeek", "krwreeek", "krrreeek", ".krreek.", "..kreek.", "...kk...", "........"],
  "heart-empty": [".kk..kk.", "keekkeek", "keeeeeek", "keeeeeek", ".keeeek.", "..keek..", "...kk...", "........"],
  piece: [".kk.....", "krrk....", "krwrk...", "krrrrk..", ".krrrrk.", "..krrrk.", "...krk..", "....k..."],
  "essence-on": ["...yy...", "..yyyy..", ".yywwyy.", "yyywyyyy", ".yyyyyY.", "..yyyY..", "...yY...", "........"],
  "essence-off": ["...kk...", "..keek..", ".keeeek.", "keeeeeek", ".keeeek.", "..keek..", "...kk...", "........"],
  blank: ["........", "........", "........", "........", "........", "........", "........", "........"],
};
// What the game doesn't give us: the unknown-item mark, ring, hearts and essence gems. Hearts and heart
// pieces draw at 7 px per art pixel (24.28dp), essences at 14 (48.56dp), the rest at 10 (34.69dp).
// The item, seed and rupee icons are the game's own: art/render-icons.py and art/grab-icon.py.
for (const [name, rows] of Object.entries(ICONS)) write(name, rows, /^(heart|piece)/.test(name) ? SCALE : /^essence/.test(name) ? 14 : 10);
console.log("wrote", 2 + Object.keys(ICONS).length, "sprites to", path.relative(process.cwd(), OUT));
