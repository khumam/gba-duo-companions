// Writes assets/types/<type>.png in the Unbound menu's type-tag look: a flat coloured block, a pale top edge,
// a darker bottom edge and a white pixel-font label with a dark outline. Drawn at 3x (96 x 36); the stylesheet
// shows them at 48 x 18 dp.
//
//   npm i @resvg/resvg-js && node art/type-pills.mjs

import fs from "node:fs";
import { Resvg } from "@resvg/resvg-js";

const root = new URL("../", import.meta.url).pathname;
const TYPES = {
  normal: "#A6A6A2", fire: "#D85860", water: "#5A8CD8", grass: "#58A860", electric: "#D8B830",
  ice: "#68C0D0", fighting: "#814A49", poison: "#9058B0", ground: "#B89050", flying: "#8098D8",
  psychic: "#E0708C", bug: "#98B030", rock: "#A89860", ghost: "#7058A8", dragon: "#6058D0",
  dark: "#605048", steel: "#8CA0B0", fairy: "#E898C8", unknown: "#989898",
};
const shade = (hex, f) => "#" + [1, 3, 5].map((i) => Math.max(0, Math.min(255, Math.round(parseInt(hex.slice(i, i + 2), 16) * f))).toString(16).padStart(2, "0")).join("");

for (const [name, color] of Object.entries(TYPES)) {
  const label = name === "unknown" ? "???" : name === "fighting" ? "FIGHT" : name.toUpperCase();
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="96" height="36" viewBox="0 0 96 36">
    <rect x="0" y="0" width="96" height="36" fill="${color}"/>
    <rect x="0" y="0" width="96" height="3" fill="${shade(color, 1.25)}"/>
    <rect x="0" y="33" width="96" height="3" fill="${shade(color, 0.7)}"/>
    <text x="48" y="27" text-anchor="middle" font-family="Jersey 10" font-size="30" letter-spacing="1" fill="#FFFFFF" stroke="#20222A" stroke-width="4" paint-order="stroke" stroke-linejoin="round">${label}</text>
  </svg>`;
  const png = new Resvg(svg, {
    font: { fontFiles: [`${root}assets/fonts/Jersey10-Regular.ttf`], loadSystemFonts: false, defaultFontFamily: "Jersey 10" },
  }).render().asPng();
  fs.writeFileSync(`${root}assets/types/${name}.png`, png);
}
console.log("ok", Object.keys(TYPES).length);
