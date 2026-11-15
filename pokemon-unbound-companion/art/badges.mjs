// Writes assets/badges/1-8.png: simple original badge icons for Unbound's eight gyms (Leaf, Darkness, Wings, Fall,
// Zap, Brawl, Swamp, Time), drawn as SVG and rendered 64x64 with @resvg/resvg-js.
//
//   npm i @resvg/resvg-js && node art/badges.mjs
import fs from "node:fs";
import { Resvg } from "@resvg/resvg-js";

const root = new URL("../", import.meta.url).pathname;
const O = "#20222A";
const frame = (fill, body) => `<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <circle cx="32" cy="32" r="29" fill="${fill}" stroke="${O}" stroke-width="4"/>
  ${body}</svg>`;
const BADGES = [
  // 1 Leaf: a green leaf with a vein
  frame("#CFEFB8", `<path d="M14 44 C14 22 30 12 50 14 C52 34 40 48 20 48 Z" fill="#58A860" stroke="${O}" stroke-width="3" stroke-linejoin="round"/><path d="M18 44 L42 22" stroke="${O}" stroke-width="3" fill="none"/>`),
  // 2 Darkness: a crescent on a dark plate
  frame("#4A4260", `<path d="M40 14 A19 19 0 1 0 40 50 A15 15 0 1 1 40 14 Z" fill="#E8E0F8" stroke="${O}" stroke-width="3" stroke-linejoin="round"/>`),
  // 3 Wings: two feathered wings
  frame("#CFE4F8", `<path d="M32 44 C20 44 10 34 8 20 C18 24 24 28 32 36 C40 28 46 24 56 20 C54 34 44 44 32 44 Z" fill="#FFFFFF" stroke="${O}" stroke-width="3" stroke-linejoin="round"/><path d="M32 36 L32 46" stroke="${O}" stroke-width="3"/>`),
  // 4 Fall: an autumn leaf
  frame("#F8DDB0", `<path d="M32 12 L38 24 L50 22 L44 34 L52 42 L38 42 L32 54 L26 42 L12 42 L20 34 L14 22 L26 24 Z" fill="#E0743C" stroke="${O}" stroke-width="3" stroke-linejoin="round"/>`),
  // 5 Zap: a lightning bolt
  frame("#FFF2B0", `<path d="M36 8 L16 36 L29 36 L24 56 L48 26 L34 26 Z" fill="#F8D030" stroke="${O}" stroke-width="3" stroke-linejoin="round"/>`),
  // 6 Brawl: a fist-like star burst
  frame("#F4C0B8", `<path d="M32 10 L38 24 L54 26 L42 37 L46 53 L32 45 L18 53 L22 37 L10 26 L26 24 Z" fill="#D85860" stroke="${O}" stroke-width="3" stroke-linejoin="round"/>`),
  // 7 Swamp: a mud drop with ripples
  frame("#C8D8B0", `<path d="M32 10 C42 24 48 32 48 40 A16 16 0 0 1 16 40 C16 32 22 24 32 10 Z" fill="#6A8A48" stroke="${O}" stroke-width="3" stroke-linejoin="round"/><path d="M24 42 Q32 48 40 42" stroke="${O}" stroke-width="3" fill="none"/>`),
  // 8 Time: an hourglass
  frame("#D8D0F0", `<path d="M20 12 H44 M20 52 H44 M22 12 C22 28 30 28 32 32 C34 36 42 36 42 52 M42 12 C42 28 34 28 32 32 C30 36 22 36 22 52" fill="#F8E8A0" stroke="${O}" stroke-width="3.5" stroke-linejoin="round"/>`),
];
BADGES.forEach((svg, i) => fs.writeFileSync(`${root}assets/badges/${i + 1}.png`, new Resvg(svg).render().asPng()));
console.log("ok", BADGES.length);
