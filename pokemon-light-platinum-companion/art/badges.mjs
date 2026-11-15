// Writes assets/ui/badge1-8.png: simple original icons for Light Platinum's first eight badges (flags 0x807-0x80E:
// Plain, Green, Sea, Ghost, Earth, Energy, Glacier, Claw), drawn as SVG and rendered 64x64 with @resvg/resvg-js.
//
//   npm i @resvg/resvg-js && node art/badges.mjs
import fs from "node:fs";
import { Resvg } from "@resvg/resvg-js";

const root = new URL("../", import.meta.url).pathname;
const O = "#2A2030";
const frame = (fill, body) => `<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <circle cx="32" cy="32" r="29" fill="${fill}" stroke="${O}" stroke-width="4"/>${body}</svg>`;
const S = (d, fill, extra = "") => `<path d="${d}" fill="${fill}" stroke="${O}" stroke-width="3" stroke-linejoin="round" ${extra}/>`;
const BADGES = [
  frame("#F0ECE0", `<circle cx="32" cy="32" r="14" fill="#C8C4B8" stroke="${O}" stroke-width="3"/><circle cx="32" cy="32" r="5" fill="#F8F4EC" stroke="${O}" stroke-width="2"/>`), // Plain
  frame("#CFEFB8", S("M14 44 C14 22 30 12 50 14 C52 34 40 48 20 48 Z", "#58A860") + `<path d="M18 44 L42 22" stroke="${O}" stroke-width="3" fill="none"/>`), // Green
  frame("#CFE4F8", S("M10 38 Q18 28 26 38 T42 38 T56 38 L56 50 L10 50 Z", "#5A8CD8") + S("M10 28 Q18 18 26 28 T42 28 T56 28", "none")), // Sea
  frame("#D8CCF0", S("M18 50 L18 28 C18 16 46 16 46 28 L46 50 L40 44 L32 50 L24 44 Z", "#F4F0FF") + `<circle cx="26" cy="30" r="3" fill="${O}"/><circle cx="38" cy="30" r="3" fill="${O}"/>`), // Ghost
  frame("#E8D8B8", S("M8 50 L24 24 L32 36 L42 18 L58 50 Z", "#A8804C")), // Earth
  frame("#FFF2B0", S("M36 8 L16 36 L29 36 L24 56 L48 26 L34 26 Z", "#F8D030")), // Energy
  frame("#D8F0F8", S("M32 8 L40 24 L56 32 L40 40 L32 56 L24 40 L8 32 L24 24 Z", "#9AE0F0")), // Glacier
  frame("#F4C0B8", S("M16 50 C14 34 20 20 30 12 C30 24 34 28 40 28 C42 34 40 44 34 50 Z", "#D85860") + `<path d="M26 44 L34 24" stroke="${O}" stroke-width="3" fill="none"/>`), // Claw
];
BADGES.forEach((svg, i) => fs.writeFileSync(`${root}assets/ui/badge${i + 1}.png`, new Resvg(svg).render().asPng()));
console.log("ok", BADGES.length);
