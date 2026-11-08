// Downloads the FireRed/LeafGreen game graphics the pack shows, from the
// PokeAPI sprites repo (https://github.com/PokeAPI/sprites):
//
//   assets/pokemon/<dex>.png        front sprites, national dex 1-386 (64x64)
//   assets/pokemon/back/<dex>.png   back sprites (the player's side in battle)
//   assets/types/<type>.png         FRLG type labels (32x12)
//   assets/badges/<1-8>.png         Kanto gym badges, Boulder..Earth
//   assets/dock/<page>.png         dock button icons (item icons, see DOCK)
//   assets/items/<item id>.png      bag icons, keyed by the ids in item_names.lua
//                                   (tm.png / hm.png cover every TM and HM)
//
// The graphics belong to Nintendo / Game Freak / Creatures.
//
//   node art/fetch-sprites.mjs

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const ASSETS = path.join(here, "..", "assets");
const RAW = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites";
const FRLG = `${RAW}/pokemon/versions/generation-iii/firered-leafgreen`;

// PokeAPI type ids; 10001 is "???".
const TYPES = {
  normal: 1, fighting: 2, flying: 3, poison: 4, ground: 5, rock: 6, bug: 7, ghost: 8, steel: 9,
  fire: 10, water: 11, grass: 12, electric: 13, psychic: 14, ice: 15, dragon: 16, dark: 17, unknown: 10001,
};

// Item names whose PokeAPI file name isn't just the slugged name.
const ITEM_SLUG = {
  "Parlyz Heal": "paralyze-heal", "S.S. Ticket": "ss-ticket", "Poke Ball": "poke-ball",
  "Poke Doll": "poke-doll", "Poke Flute": "poke-flute", "TwistedSpoon": "twisted-spoon",
  "BlackGlasses": "black-glasses", "SilverPowder": "silver-powder", "DeepSeaTooth": "deep-sea-tooth",
  "DeepSeaScale": "deep-sea-scale", "NeverMeltIce": "never-melt-ice", "BrightPowder": "bright-powder",
  "King's Rock": "kings-rock", "Thunderstone": "thunder-stone", "HP Up": "hp-up", "PP Up": "pp-up",
  "PP Max": "pp-max", "X Defend": "x-defense", "X Special": "x-sp-atk", "Exp. Share": "exp-share",
  "Up-Grade": "up-grade", "Itemfinder": "gen3/itemfinder", "Fame Checker": "fame-checker", "Tea": "tea", "Powder Jar": "powder-jar",
};
const slug = (name) =>
  ITEM_SLUG[name] ??
  name.toLowerCase().replace(/é/g, "e").replace(/['.]/g, "").replace(/\s+/g, "-");

async function get(url, file) {
  if (fs.existsSync(file)) return true;
  const res = await fetch(url);
  if (!res.ok) return false;
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, Buffer.from(await res.arrayBuffer()));
  return true;
}

/** Runs the jobs a few at a time; returns the labels of the ones that failed. */
async function run(jobs, width = 12) {
  const missed = [];
  let next = 0;
  await Promise.all(
    Array.from({ length: width }, async () => {
      while (next < jobs.length) {
        const [label, url, file] = jobs[next++];
        if (!(await get(url, file))) missed.push(label);
      }
    }),
  );
  return missed;
}

const jobs = [];
for (let dex = 1; dex <= 386; dex++) {
  jobs.push([`#${dex}`, `${FRLG}/${dex}.png`, path.join(ASSETS, "pokemon", `${dex}.png`)]);
  jobs.push([`#${dex} back`, `${FRLG}/back/${dex}.png`, path.join(ASSETS, "pokemon", "back", `${dex}.png`)]);
}
for (const [name, id] of Object.entries(TYPES))
  jobs.push([`type ${name}`, `${RAW}/types/generation-iii/firered-leafgreen/${id}.png`, path.join(ASSETS, "types", `${name}.png`)]);
for (let i = 1; i <= 8; i++) jobs.push([`badge ${i}`, `${RAW}/badges/${i}.png`, path.join(ASSETS, "badges", `${i}.png`)]);

const itemLua = fs.readFileSync(path.join(here, "..", "item_names.lua"), "utf8");
for (const [, id, name] of itemLua.matchAll(/\[(\d+)\]\s*=\s*"([^"]+)"/g)) {
  if (name.startsWith("??")) continue;
  jobs.push([`item ${id} ${name}`, `${RAW}/items/${slug(name)}.png`, path.join(ASSETS, "items", `${id}.png`)]);
}
// FRLG key items past item_names.lua's range (pokefirered include/constants/items.h).
const FRLG_KEY_ITEMS = {
  349: "oaks-parcel", 350: "poke-flute", 351: "secret-key", 352: "bike-voucher", 353: "gold-teeth",
  354: "old-amber", 355: "card-key", 356: "lift-key", 357: "helix-fossil", 358: "dome-fossil",
  359: "silph-scope", 360: "bicycle", 361: "town-map", 362: "vs-seeker", 363: "fame-checker",
  364: "tm-case", 365: "berry-pouch", 366: "teachy-tv", 367: "tri-pass", 368: "rainbow-pass",
  369: "tea", 370: "mystic-ticket", 371: "aurora-ticket", 372: "powder-jar", 373: "ruby", 374: "sapphire",
};
for (const [id, name] of Object.entries(FRLG_KEY_ITEMS))
  jobs.push([`item ${id} ${name}`, `${RAW}/items/${name}.png`, path.join(ASSETS, "items", `${id}.png`)]);
jobs.push(["tm", `${RAW}/items/tm-normal.png`, path.join(ASSETS, "items", "tm.png")]);
jobs.push(["hm", `${RAW}/items/hm-normal.png`, path.join(ASSETS, "items", "hm.png")]);

// Dock buttons. PokeAPI has no Pokedex, Bag or Trainer Card icon, so these are
// the closest items: the Poke Radar for the dex, the Explorer Kit backpack for
// the bag, the Card Key for the trainer card, the VS Seeker for battles.
const DOCK = {
  map: "town-map", party: "poke-ball", bag: "explorer-kit",
  dex: "poke-radar", trainer: "card-key", battle: "vs-seeker",
};
for (const [page, item] of Object.entries(DOCK))
  jobs.push([`dock ${page}`, `${RAW}/items/${item}.png`, path.join(ASSETS, "dock", `${page}.png`)]);

const missed = await run(jobs);
console.log(`${jobs.length - missed.length}/${jobs.length} files`);
if (missed.length) console.log(`not on PokeAPI: ${missed.join(", ")}`);
