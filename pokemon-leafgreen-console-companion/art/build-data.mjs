// Builds LeafGreen game_data.lua from shared FireRed/LeafGreen data in
// the pret/pokefirered decompilation:
//   species  internal id -> { name, dex }   (dex = national number, for sprites)
//   moves    id -> { name, type, pp }        (type = assets/types key)
//   abilities, items, mapsecs  id -> name
//   mapCells  mapsec id -> { x, y, w, h, region } on the Town Map (8 px cells;
//             region 0 Kanto, 1-3 the Sevii Islands 1-2-3, 4-5, 6-7 maps)
//
//   node art/build-data.mjs            (downloads into /tmp/pfr if missing)

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const SRC = "/tmp/pfr";
const RAW = "https://raw.githubusercontent.com/pret/pokefirered/master/";
const FILES = [
  "include/constants/species.h", "include/constants/pokedex.h", "src/data/text/species_names.h",
  "include/constants/moves.h", "src/data/battle_moves.h", "src/data/text/move_names.h",
  "include/constants/abilities.h", "src/data/text/abilities.h",
  "src/data/items.json", "include/constants/items.h", "src/data/region_map/region_map_sections.json",
  "src/region_map.c",
];

async function load(f) {
  const p = path.join(SRC, f);
  if (!fs.existsSync(p)) {
    const res = await fetch(RAW + f);
    if (!res.ok) throw new Error(`fetch ${f}: ${res.status}`);
    fs.mkdirSync(path.dirname(p), { recursive: true });
    fs.writeFileSync(p, await res.text());
  }
  return fs.readFileSync(p, "utf8");
}
const src = Object.fromEntries(await Promise.all(FILES.map(async (f) => [f, await load(f)])));

/** #define NAME value, with values that reference earlier names resolved. */
function defines(text, prefix) {
  const out = {};
  for (const [, name, raw] of text.matchAll(new RegExp(`#define\\s+(${prefix}\\w+)\\s+(.+)`, "g"))) {
    const expr = raw.replace(/\/\/.*|\/\*.*?\*\//g, "").trim().replace(/[A-Z_][A-Z0-9_]*/g, (n) => (n in out ? out[n] : n));
    if (/^[\d\s+\-*()x]+$/i.test(expr)) out[name] = Function(`return (${expr})`)();
  }
  return out;
}
/** The first `enum { ... }` whose members start with [prefix]: NAME -> its value. */
function enumValues(text, prefix) {
  const out = {};
  for (const [, body] of text.matchAll(/enum\s*\{([^}]*)\}/g)) {
    if (!body.includes(prefix)) continue;
    let n = 0;
    for (let line of body.split("\n")) {
      line = line.replace(/\/\/.*/, "").trim().replace(/,$/, "");
      if (!line) continue;
      const m = /^(\w+)(?:\s*=\s*(\d+))?$/.exec(line);
      if (!m) continue;
      if (m[2]) n = Number(m[2]);
      out[m[1]] = n++;
    }
    return out;
  }
  return out;
}
/** [CONST] = _("TEXT") tables. */
function strings(text) {
  const out = {};
  for (const [, k, v] of text.matchAll(/\[(\w+)\]\s*=\s*_\("((?:[^"\\]|\\.)*)"\)/g)) out[k] = v;
  return out;
}
// Game text -> display: keep the game's capitals, map its special glyphs.
const clean = (s) => s.replace(/\{PKMN\}/g, "PKMN").replace(/\{[A-Z_]+\}/g, "").replace(/\\n/g, " ").trim();

const TYPE_KEY = {
  TYPE_NORMAL: "normal", TYPE_FIGHTING: "fighting", TYPE_FLYING: "flying", TYPE_POISON: "poison",
  TYPE_GROUND: "ground", TYPE_ROCK: "rock", TYPE_BUG: "bug", TYPE_GHOST: "ghost", TYPE_STEEL: "steel",
  TYPE_MYSTERY: "unknown", TYPE_FIRE: "fire", TYPE_WATER: "water", TYPE_GRASS: "grass",
  TYPE_ELECTRIC: "electric", TYPE_PSYCHIC: "psychic", TYPE_ICE: "ice", TYPE_DRAGON: "dragon", TYPE_DARK: "dark",
};

// ---- species ----------------------------------------------------------------
const speciesIds = defines(src["include/constants/species.h"], "SPECIES_");
const dexNums = enumValues(src["include/constants/pokedex.h"], "NATIONAL_DEX_");
const speciesNames = strings(src["src/data/text/species_names.h"]);
const species = {};
for (const [k, id] of Object.entries(speciesIds)) {
  if (k === "SPECIES_NONE" || k === "SPECIES_EGG" || !(typeof id === "number") || id > 411) continue;
  const base = k.slice("SPECIES_".length);
  const dex = dexNums["NATIONAL_DEX_" + base];
  const name = speciesNames[k];
  if (dex && name) species[id] = { name: clean(name), dex };
}

// ---- moves ------------------------------------------------------------------
const moveIds = defines(src["include/constants/moves.h"], "MOVE_");
const moveNames = strings(src["src/data/text/move_names.h"]);
const moves = {};
for (const [, k, body] of src["src/data/battle_moves.h"].matchAll(/\[(MOVE_\w+)\]\s*=\s*\{([^}]*)\}/g)) {
  const id = moveIds[k];
  if (!id) continue;
  const type = /\.type\s*=\s*(\w+)/.exec(body)?.[1];
  const pp = Number(/\.pp\s*=\s*(\d+)/.exec(body)?.[1] ?? 0);
  moves[id] = { name: clean(moveNames[k] ?? k.slice(5)), type: TYPE_KEY[type] ?? "unknown", pp };
}

// ---- abilities ----------------------------------------------------------------
const abilityIds = defines(src["include/constants/abilities.h"], "ABILITY_");
const abilityNames = strings(src["src/data/text/abilities.h"]);
const abilities = {};
for (const [k, id] of Object.entries(abilityIds)) if (id && abilityNames[k]) abilities[id] = clean(abilityNames[k]);

// ---- items ----------------------------------------------------------------------
const itemIds = defines(src["include/constants/items.h"], "ITEM_");
const items = {};
for (const it of JSON.parse(src["src/data/items.json"]).items) {
  const id = itemIds[it.itemId];
  if (id && it.english && !/^\?+$/.test(it.english)) items[id] = clean(it.english);
}

// ---- map sections ---------------------------------------------------------------
const mapsecs = {};
JSON.parse(src["src/data/region_map/region_map_sections.json"]).map_sections.forEach((s, i) => {
  if (s.name) mapsecs[i] = clean(s.name);
});

// Which Town Map shows each section: region_map.c lists the Sevii ones per map
// (sSeviiMapsecs), every other FR/LG section is on Kanto's.
const sections = JSON.parse(src["src/data/region_map/region_map_sections.json"]).map_sections;
const seviiBlock = src["src/region_map.c"].match(/sSeviiMapsecs\[3\]\[30\] = \{([\s\S]*?)\n\};/)[1];
const seviiRegion = {};
seviiBlock.split("},").slice(0, 3).forEach((group, i) => {
  for (const [id] of group.matchAll(/MAPSEC_\w+/g)) if (id !== "MAPSEC_NONE") seviiRegion[id] = i + 1;
});
const firstKanto = sections.findIndex((s) => s.id === "MAPSEC_PALLET_TOWN");
const mapCells = {};
sections.forEach((s, i) => {
  if (i < firstKanto || s.x === undefined) return;
  mapCells[i] = { x: s.x, y: s.y, w: s.width, h: s.height, region: seviiRegion[s.id] ?? 0 };
});

// ---- write --------------------------------------------------------------------------
const q = (s) => JSON.stringify(s);
const table = (obj, fmt) =>
  "{\n" + Object.entries(obj).sort((a, b) => a[0] - b[0]).map(([k, v]) => `    [${k}] = ${fmt(v)},`).join("\n") + "\n  }";
const lua = `-- LeafGreen game data, generated by art/build-data.mjs from pret/pokefirered
-- (include/constants/*.h, src/data/*). Do not edit by hand.
return {
  species = ${table(species, (v) => `{ name = ${q(v.name)}, dex = ${v.dex} }`)},
  moves = ${table(moves, (v) => `{ name = ${q(v.name)}, type = ${q(v.type)}, pp = ${v.pp} }`)},
  abilities = ${table(abilities, q)},
  items = ${table(items, q)},
  mapsecs = ${table(mapsecs, q)},
  mapCells = ${table(mapCells, (v) => `{ x = ${v.x}, y = ${v.y}, w = ${v.w}, h = ${v.h}, region = ${v.region} }`)},
}
`;
fs.writeFileSync(path.join(here, "..", "game_data.lua"), lua);
console.log(`species ${Object.keys(species).length}, moves ${Object.keys(moves).length}, abilities ${Object.keys(abilities).length}, items ${Object.keys(items).length}, mapsecs ${Object.keys(mapsecs).length}, mapCells ${Object.keys(mapCells).length}`);
