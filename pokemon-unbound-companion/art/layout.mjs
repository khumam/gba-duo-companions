// Writes layout.json for the Unbound design: the game's own menu (black title bar with page squares,
// slate windows with grey pill labels and cream value rows, cut-corner cyan party cards, hexagon move
// cards, a green bag frame). The header and bar repeat on every page, so edit them here, not by hand:
//
//   node art/layout.mjs

import fs from "node:fs";

const box = (cls, children, extra = {}) => ({ type: "box", class: cls, children, ...extra });
const text = (cls, t, extra = {}) => ({ type: "text", class: cls, text: t, ...extra });
const img = (cls, src, extra = {}) => ({ type: "image", class: cls, src, ...extra });
const ui = (n) => `asset:ui/${n}.png`;

// ---- shared pieces ---------------------------------------------------------------

const GAME = "UNBOUND";

const RING = [
  ["map", "MAP"],
  ["party", "PARTY"],
  ["bag", "BAG"],
  ["dex", "DEX"],
  ["trainer", "CARD"],
  ["battle", "BATTLE"],
];

const tail = [
  box("loc-pill", [img("ic8", ui("ic-pin")), text("loc-text", "{location}")]),
  box("grow", []),
  box("hstat", [img("ic8", ui("ic-clock")), text("num hnum", "{time}")]),
  box("hstat", [img("ic8", ui("ic-coin")), text("num hnum", "{money}")]),
];
const header = (title, active, cls = "") =>
  box(`hdr ${cls}`.trim(), [
    box("hdr-title", [
      text("hdr-name", title),
      ...(active >= 0 ? [box("hdr-dots", RING.map((_, i) => box(`dot${i === active ? " on" : ""}`, [])))] : []),
    ]),
    box("hdr-tail", tail),
  ]);

const navBtn = (to, label, side) => ({
  type: "button",
  class: `bar-btn bar-${side}`,
  onClick: [{ navigate: to }],
  children: [
    ...(side === "l" ? [img("chev", ui("chev-l"))] : []),
    text("bar-label", label),
    ...(side === "r" ? [img("chev", ui("chev-r"))] : []),
  ],
});
const ringBar = (i) => {
  const [pp, pl] = RING[(i + RING.length - 1) % RING.length];
  const [np, nl] = RING[(i + 1) % RING.length];
  return box("bar", [navBtn(pp, pl, "l"), box("bar-mid", [text("bar-title", RING[i][1])]), navBtn(np, nl, "r")]);
};
const backBar = box("bar", [
  { type: "button", class: "bar-btn bar-l", onClick: "back", children: [img("chev", ui("chev-l")), text("bar-label", "BACK")] },
  box("bar-mid", [text("bar-title", "SUMMARY")]),
  { type: "button", class: "bar-btn bar-r", onClick: "back", children: [text("bar-label", "BACK"), img("chev", ui("chev-r"))] },
]);

const panel = (cls, title, body, chips = []) =>
  box(`panel ${cls}`, [
    box("panel-head", [box("panel-tab", [text("panel-title", title)]), box("grow", []), ...chips]),
    box("panel-body", body),
  ]);
const chip = (t, cls = "") => box(`chip ${cls}`.trim(), [text("chip-text", t)]);

// A Pokemon card. `p` prefixes every binding: "" inside a list, "battle.you." outside.
const hpRow = (p, compact) =>
  box("hp-row", [
    box("hp-tag", [text("hp-tag-text", "HP")]),
    {
      type: "bar",
      class: "hp",
      classIf: { high: `$${p}hpHigh`, mid: `$${p}hpMid`, low: `$${p}hpLow` },
      value: `$${p}hpPct`,
      max: 1,
    },
    ...(compact ? [text("num hp-num", `{${p}hp}/{${p}maxHp}`)] : []),
  ]);
// The game sprite (64x64 with transparent margins), drawn larger than its slot.
const sprite = (p, cls) => box(`sprite-slot ${cls}`, [img("sprite", `$${p}sprite`)]);
const statusChip = (p) =>
  box("status", [text("status-text", `{${p}status}`)], {
    visibleIf: `$${p}hasStatus`,
    bindStyle: { "background-color": `{${p}statusColor}`, color: `{${p}statusInk}` },
  });
const cardBase = (p) => ({
  classIf: { lead: `$${p}lead`, fainted: `$${p}fainted` },
});
// Tapping a card copies that Pokemon into $ui (same keys) and opens the detail
// page, which binds everything through "ui.". A whole-string "{field}" keeps the
// value's type, so lists (types, stats, moves) and booleans copy as-is.
const DETAIL_KEYS = [
  "name", "level", "dex", "sprite", "types", "hp", "maxHp", "hpPct", "hpHigh", "hpMid", "hpLow",
  "fainted", "lead", "status", "hasStatus", "statusColor", "statusInk", "tone", "ink",
  "nature", "ability", "item", "itemIcon", "hasItem", "toNext", "expPct", "stats", "moves",
];
const openDetail = [
  { set: Object.fromEntries(DETAIL_KEYS.map((k) => [k, `{${k}}`])) },
  { navigate: "detail" },
];

// A card of a battler (not in the party list) opens that Pokemon's detail page the same way.
const openFrom = (p) => [
  { set: Object.fromEntries(DETAIL_KEYS.map((k) => [k, `{${p}${k}}`])) },
  { navigate: "detail" },
];

const ring = (p) => box("ring", [], { visibleIf: `$${p}lead` });
const strike = (p) => box("strike", [], { visibleIf: `$${p}fainted` });

const quickCard = (p) =>
  box(
    "card qcard",
    [
      ring(p),
      sprite(p, "sprite-s"),
      box("qcard-body", [
        box("name-row", [text("mon-name", `{${p}name}`), statusChip(p), box("grow", []), text("num lv", `Lv{${p}level}`)]),
        hpRow(p, true),
      ]),
      strike(p),
    ],
    { ...cardBase(p), ...(p === "" ? { onClick: openDetail } : {}) },
  );

const typeChips = (p) => ({
  type: "list",
  class: "type-row",
  items: `$${p}types`,
  template: img("type-img", "$src"),
});

// The party card: cut-corner cyan plate, the mon in a ball at the left, name, HP bar, level and HP numbers.
// Battle cards (p set) also show the types.
const bigCard = (p, click) =>
  box(
    "card pcard",
    [
      ring(p),
      sprite(p, "sprite-l"),
      box("pcard-body", [
        box("name-row", [text("mon-name", `{${p}name}`), box("grow", []), statusChip(p)]),
        hpRow(p, false),
        box("hp-foot", [text("num lv", `Lv{${p}level}`), box("grow", []), text("num hp-big", `{${p}hp}/{${p}maxHp}`)]),
        ...(p === "" ? [] : [box("name-row", [typeChips(p)])]),
      ]),
      strike(p),
    ],
    { ...cardBase(p), ...(p === "" ? { onClick: openDetail } : click ? { onClick: click } : {}) },
  );

// ---- pages -------------------------------------------------------------------------

// TOWN: the live area around you, drawn from the game's own map data in RAM (Unbound has no Kanto Town Map to
// draw), slid under the card so walking doesn't redraw it. Beside it: the wild Pokemon of this map.
const mapPage = box("content two-col map-cols", [
  panel("radar-panel", "MAP", [
    box("town-pic", [
      img("area-img", "$map.areaImage"),
      box("area-anchor", [img("area-you", ui("ic-you"))], {
        bindStyle: { left: "{map.areaX}", top: "{map.areaY}" },
        visibleIf: "$map.areaHasMe",
      }),
    ], { visibleIf: "$map.townLive" }),
    box("town-off", [text("town-off-text", "THE AREA MAP DRAWS WHEN YOU ARE OUT IN THE GAME")], { visibleIf: "$map.townOff" }),
  ], [chip("{map.town}", "chip-blue")]),
  // Wild Pokemon on this map: tap the method tag for the next method (grass, surf, rods).
  panel("wild-panel", "WILD HERE", [
    box("wild", [
      {
        type: "button",
        class: "wild-method",
        onClick: { call: "nextWild" },
        children: [text("wild-label", "METHOD"), text("wild-method-text", "{map.wildMethod}")],
      },
      {
        type: "list",
        class: "wild-mons",
        items: "$map.wild",
        // One row per species, most common first; the list scrolls, the method button stays.
        template: box("wild-mon", [
          img("wild-sprite", "$sprite"),
          box("wild-info", [text("wild-name", "{name}"), text("wild-level", "{level}")]),
          box("wild-chance", [text("wild-chance-text", "{chance}")]),
        ]),
      },
    ], { visibleIf: "$map.hasWild" }),
    box("wild wild-none", [text("wild-none-text", "NO WILD POKéMON HERE")], { visibleIf: "$map.noWild" }),
  ]),
]);

const partyPage = box("content", [
  panel("party-panel", "PARTY", [
    { type: "list", class: "pgrid", items: "$party", empty: "NO POKéMON", template: bigCard("") },
  ], [chip("{partyCount} MON", "chip-blue")]),
]);

// A search box with a clear button; what is typed lands in ui.<state> (main.lua reads it).
const searchRow = (state, placeholder) =>
  box("search-row", [
    { type: "input", class: "search-input", state, placeholder, maxLength: 14 },
    {
      type: "button",
      class: "search-clear",
      onClick: { set: { [state]: "" } },
      visibleIf: `$ui.${state}`,
      children: [text("search-clear-x", "X")],
    },
  ]);

const pocket = (title, path) => ({
  title,
  child: {
    type: "list",
    class: "item-grid",
    items: `$bag.${path}`,
    empty: "EMPTY POCKET",
    template: box("item-row", [text("item-name", "{name}"), box("grow", []), img("item-icon", "$icon"), text("num item-count", "{count}")]),
  },
});
const bagPage = box("content", [
  panel("bag-panel", "BAG", [
    {
      type: "tabs",
      class: "pockets",
      tabs: [
        pocket("ITEMS", "items"),
        pocket("KEY", "keyItems"),
        pocket("BALLS", "balls"),
        pocket("TM/HM", "tmHm"),
        pocket("BERRY", "berries"),
      ],
    },
  ], [chip("{bag.total} STACKS", "chip-green")]),
]);

// 24 national numbers at a time (main.lua keeps the window and the selection); tap a row to read its entry.
const dexRow = box(
  "dex-row",
  [
    box("dex-thumb", [img("dex-img", "$sprite", { visibleIf: "$seen" }), text("dex-q", "?", { visibleIf: "$unseen" })]),
    box("dex-info", [text("num dex-no", "No.{no}"), text("dex-name", "{name}")]),
    box("dex-own", [], { visibleIf: "$own" }),
  ],
  { classIf: { sel: "$sel", unseen: "$unseen" }, onClick: [{ call: "dexSelect", args: ["{num}"] }] },
);
const pager = (delta, label) => ({
  type: "button",
  class: "pg-btn",
  onClick: [{ call: "dexPage", args: [delta] }],
  children: [img("chev", ui(label === "<" ? "chev-l" : "chev-r"))],
});
const dexStat = box("dstat dex-srow", [
  text("dstat-name", "{label}"),
  { type: "bar", class: "dstat-bar", value: "$pct", max: 1 },
  text("num dstat-val", "{value}"),
]);
const dexPage = box("content dex-cols", [
  panel("dex-list-panel", "DEX", [
    searchRow("dexQuery", "NAME OR No."),
    box("pager", [pager(-1, "<"), box("pager-mid", [text("pager-text", "{dex.range}"), text("pager-sub", "PAGE {dex.page}")]), pager(1, ">")], { visibleIf: "$dex.notSearching" }),
    box("pager-found", [text("pager-found-text", "{dex.found}")], { visibleIf: "$dex.searching" }),
    { type: "list", class: "dex-list", items: "$dex.entries", empty: "NO MATCH", template: dexRow },
  ], [chip("{dex.caught} OWN", "chip-yellow")]),
  panel("dex-entry-panel", "ENTRY", [
    box("dex-hero", [
      box("dex-big", [img("dex-big-img", "$dex.sel.sprite", { visibleIf: "$dex.sel.seen" }), text("dex-big-q", "?", { visibleIf: "$dex.sel.unseen" })]),
      box("dex-id", [
        text("num dex-sel-no", "No.{dex.sel.no}"),
        text("dex-sel-name", "{dex.sel.name}"),
        text("dex-cat", "{dex.sel.category}"),
        typeChips("dex.sel."),
      ]),
    ]),
    box("dex-meas", [
      box("meas", [text("meas-k", "HT"), text("meas-v", "{dex.sel.height}")]),
      box("meas", [text("meas-k", "WT"), text("meas-v", "{dex.sel.weight}")]),
      box("meas grow", [text("meas-k", "ABILITY"), text("meas-v", "{dex.sel.abilities}")]),
    ]),
    box("dex-desc", [text("dex-desc-text", "{dex.sel.desc}")]),
    { type: "list", class: "dex-stats", items: "$dex.sel.stats", template: dexStat },
  ], [chip("{dex.sel.state}", "chip-green")]),
]);

const optBtn = (label, state, onClick, extra = {}) => ({
  type: "button",
  class: "opt-btn",
  onClick,
  children: [text("opt-label", label), box("grow", []), text("opt-state", state)],
  ...extra,
});
const settingsPanel = panel("set-panel", "SETTINGS", [
  optBtn("WIDE VIEW", "{_wideLabel}", { call: "wideView", args: ["toggle"] }),
]);

const idRow = (k, v, icon) =>
  box("id-row", [box("id-ico-slot", [img("id-ico", ui(icon))]), text("id-key", k), box("grow", []), text("num id-val", v)]);
const trainerPage = box("content two-col trainer-cols", [
  panel("id-panel", "TRAINER CARD", [
    box("id-card", [
      box("id-band", [text("id-band-text", "IDNo."), box("grow", []), text("num id-no", "{trainer.id}")]),
      box("id-main", [
        box("id-rows", [
          idRow("NAME", "{trainer.name}", "id-ball"),
          idRow("MONEY", "{trainer.money}", "id-coin"),
          idRow("TIME", "{trainer.time}", "id-clock"),
          idRow("DEX", "{trainer.caught}", "id-dex"),
          idRow("BADGES", "{trainer.badges}", "id-badge"),
        ]),
      ]),
    ]),
  ]),
  box("side-col", [settingsPanel, panel("badge-panel", "BADGES", [
    {
      type: "list",
      class: "badge-grid",
      items: "$trainer.badgeList",
      template: box(
        "badge",
        [
          img("badge-img", "$src", { visibleIf: "$earned" }),
          img("badge-lock", ui("ic-lock"), { visibleIf: "$locked" }),
          text("badge-name", "{name}"),
        ],
        { classIf: { earned: "$earned", locked: "$locked" } },
      ),
    },
  ], [chip("{trainer.badges}", "chip-yellow")])]),
]);

const statList = (p) => ({
  type: "list",
  class: "stat-list",
  items: `$${p}stats`,
  template: box(
    "stat-row",
    [text("stat-name", "{name}"), box("grow", []), text("num stat-val", "{value}"), box("stage", [text("num stage-text", "{stage}")])],
    { classIf: { up: "$up", down: "$down", flat: "$flat" } },
  ),
});
const tileBtn = (cls, label, sub, idx, on) => ({
  type: "button",
  class: `tile ${cls}`,
  classIf: { on },
  onClick: [{ call: "setAction", args: [idx] }],
  children: [text("tile-label", label), text("tile-sub", sub)],
});
// A move at a glance: type, name, how well it hits the foe, PP. The best one is starred. Tapping one presses FIGHT in
// the game (the moves page opens by itself once the move menu is up).
const moveChip = box(
  "mchip",
  [
    img("type-img", "$type", { visibleIf: "$has" }),
    box("mchip-main", [text("mchip-name", "{name}"), text("num mchip-pp", "PP {pp}")]),
    box("eff", [text("eff-text", "{eff}")], { classIf: { se: "$se", nve: "$nve", imm: "$imm" }, visibleIf: "$has" }),
  ],
  { classIf: { se: "$se", nve: "$nve", imm: "$imm", best: "$best" }, visibleIf: "$has", onClick: [{ call: "setAction", args: [0] }] },
);
// The two Pokemon, their moves, and the four menu buttons: tapping one presses it in the game; the cards open the
// full Pokemon pages.
const battlePage = box("content battle-content", [
  box("battle-main", [
    box("combatants", [
      box("combatant", [bigCard("battle.you.", openFrom("battle.youMon."))]),
      box("combatant", [bigCard("battle.foe.", openFrom("battle.foeMon."))]),
    ]),
    box("moves-preview", [
      text("moves-title", "YOUR MOVES"),
      { type: "list", class: "mchips", items: "$battle.moves", template: moveChip },
    ]),
    box("tiles", [
      {
        type: "button",
        class: "tile t-fight",
        classIf: { on: "$battle.actFight" },
        onClick: [{ call: "setAction", args: [0] }],
        children: [text("tile-label", "FIGHT"), text("tile-sub", "{battle.bestName}")],
      },
      tileBtn("t-bag", "CUBE", "UNBOUND CUBE", 1, "$battle.actBag"),
      tileBtn("t-mon", "POKéMON", "{partyCount} IN TEAM", 2, "$battle.actMon"),
      tileBtn("t-run", "RUN", "{battle.runText}", 3, "$battle.actRun"),
    ]),
  ], { visibleIf: "$battle.inBattle" }),
  box("no-battle", [
    box("no-battle-card", [text("no-battle-text", "NO BATTLE"), text("no-battle-sub", "CONTROLS APPEAR WHEN A FIGHT STARTS")]),
  ], { visibleIf: "$battle.noBattle" }),
]);

// Moves: type, power / accuracy, how well it hits the foe, PP; tap one to use it. The stat stages sit above.
const bside = (p, mon, cls) =>
  box(`bside ${cls}`, [bigCard(p, openFrom(mon)), statList(p)]);
const skill = box(
  "skill",
  [
    img("type-img", "$type", { visibleIf: "$has" }),
    box("skill-main", [text("skill-name", "{name}"), text("skill-sub", "{info}")]),
    box("skill-right", [
      box("eff", [text("eff-text", "{eff}")], { classIf: { se: "$se", nve: "$nve", imm: "$imm" }, visibleIf: "$has" }),
      text("num skill-pp", "{pp}"),
    ]),
  ],
  { classIf: { se: "$se", nve: "$nve", imm: "$imm", on: "$sel" }, visibleIf: "$has", onClick: [{ call: "setMove", args: ["{@index}"] }] },
);
const battleDetailPage = box("content battle-detail", [
  box("sides", [bside("battle.you.", "battle.youMon.", "bside-you"), bside("battle.foe.", "battle.foeMon.", "bside-foe")]),
  { type: "list", class: "skills", items: "$battle.moves", template: skill },
]);
const battleBar = box("bar", [
  { type: "button", class: "bar-btn bar-full", onClick: [{ navigate: "battle" }], children: [text("bar-title", "BATTLE")] },
]);

// A label pill on the slate side, the value on a ruled cream row (the game's Info page).
const infoRow = (k, v, extra = []) =>
  box("irow", [box("ipill", [text("ipill-text", k)]), box("ival", [...extra, text("ival-text", v)])]);
const expRow = box("irow", [
  box("ipill", [text("ipill-text", "EXP")]),
  box("ival ival-col", [
    text("num meter-val", "{ui.toNext} TO NEXT"),
    { type: "bar", class: "exp", value: "$ui.expPct", max: 1 },
  ]),
]);
const hpInfoRow = box("irow", [box("ipill", [text("ipill-text", "HP")]), box("ival ival-col", [hpRow("ui.", true)])]);
// A move, the Moves page's hexagon card: type tag, name, PP; the notches at both ends make the hexagon.
const moveCard = box("mcard", [
  box("hex hex-l", []),
  box("hex hex-r", []),
  box("mc-tag", [img("type-img", "$type")]),
  box("mc-main", [text("mc-name", "{name}"), text("num mc-pp", "PP {pp}")]),
]);
const detailPage = box("content two-col detail-cols", [
  box("detail-left", [
    box("plate", [
      sprite("ui.", "sprite-xl"),
      box("plate-body", [
        box("name-row", [text("plate-name", "{ui.name}"), box("grow", []), text("num lv plate-lv", "Lv{ui.level}")]),
        box("name-row", [typeChips("ui."), box("grow", []), statusChip("ui.")]),
      ]),
    ]),
    box("irows", [
      infoRow("No", "{ui.dex}"),
      hpInfoRow,
      infoRow("NATURE", "{ui.nature}"),
      infoRow("ABILITY", "{ui.ability}"),
      infoRow("ITEM", "{ui.item}", [img("info-icon", "$ui.itemIcon", { visibleIf: "$ui.hasItem" })]),
      expRow,
    ]),
  ]),
  panel("sum-panel", "POKéMON", [
    {
      type: "tabs",
      class: "sum-tabs",
      tabs: [
        { title: "MOVES", child: { type: "list", class: "mcards", items: "$ui.moves", template: moveCard } },
        {
          title: "STATS",
          child: {
            type: "list",
            class: "dstat-list",
            items: "$ui.stats",
            template: box(
              "dstat",
              [
                text("dstat-name", "{name}"),
                { type: "bar", class: "dstat-bar", value: "$pct", max: 1 },
                text("num dstat-val", "{value}"),
              ],
              { classIf: { up: "$up", down: "$down" } },
            ),
          },
        },
      ],
    },
  ]),
]);

const page = (name, content, i) => ({ name, child: box(`page page-${name}`, [header(RING[i][1], i, name === "battle" ? "hdr-battle" : ""), content, ringBar(i)]) });

const layout = box("screen-root", [
  box("waiting", [
    box("boot", [
      text("boot-title", "POKEMON"),
      text("boot-sub", `${GAME} LINK`),
      box("boot-pill", [text("boot-pill-text", "GBADUO COMPANION PACK")]),
    ]),
  ], { visibleIf: "$waiting" }),
  box("shell", [
    {
      type: "pages",
      pages: [
        page("map", mapPage, 0),
        page("party", partyPage, 1),
        { name: "detail", child: box("page page-detail", [header("SUMMARY", -1), detailPage, backBar]) },
        page("bag", bagPage, 2),
        page("dex", dexPage, 3),
        page("trainer", trainerPage, 4),
        page("battle", battlePage, 5),
        { name: "battle-detail", child: box("page page-battle-detail", [header("MOVES", -1, "hdr-battle"), battleDetailPage, battleBar]) },
      ],
    },
  ], { visibleIf: "$ready" }),
], { id: "screen" });

fs.writeFileSync(new URL("../layout.json", import.meta.url), JSON.stringify(layout, null, 2) + "\n");
console.log("ok");
