// Writes assets/types/<type>.png: a white pill with a type-coloured border and a dark
// Barlow Bold label. Drawn at 3x (96 x 36); the stylesheet shows them at 48 x 18 dp.
//
//   npm i @resvg/resvg-js && node art/type-pills.mjs

import fs from "node:fs";
import { Resvg } from "@resvg/resvg-js";

const root = new URL("../", import.meta.url).pathname;
const INK = "#2E2A2A";
const TYPES = {
  normal: "#A8A89A", fire: "#E8955A", water: "#6FA3DA", grass: "#7DBF6E", electric: "#E0BF3E",
  ice: "#7CC7D9", fighting: "#D9675F", poison: "#A87BC2", ground: "#C9A265", flying: "#8FA7E0",
  psychic: "#E07BA8", bug: "#A4C03F", rock: "#B5A06A", ghost: "#8573B5", dragon: "#7570DC",
  dark: "#7A6A62", steel: "#9FB2C2", unknown: "#B5B5B5",
};

for (const [name, color] of Object.entries(TYPES)) {
  const label = name === "unknown" ? "???" : name.toUpperCase();
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="96" height="36" viewBox="0 0 96 36">
    <rect x="1.5" y="1.5" width="93" height="33" rx="15" fill="#FFFFFF" stroke="${color}" stroke-width="3"/>
    <text x="48" y="25" text-anchor="middle" font-family="Barlow Semi Condensed" font-weight="700" font-size="21" letter-spacing="0.5" fill="${INK}">${label}</text>
  </svg>`;
  const png = new Resvg(svg, {
    font: { fontFiles: [`${root}assets/fonts/BarlowSemiCondensed-Bold.ttf`], loadSystemFonts: false, defaultFontFamily: "Barlow Semi Condensed" },
  }).render().asPng();
  fs.writeFileSync(`${root}assets/types/${name}.png`, png);
}
console.log("ok", Object.keys(TYPES).length);
