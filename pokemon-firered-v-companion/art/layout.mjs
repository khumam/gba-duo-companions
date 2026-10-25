// Writes layout.json for the "Pocket-OS" design. The dock is repeated on every
// page (the selected button carries `.on`), so edit it here, not by hand:
//
//   node art/layout.mjs

import fs from "node:fs";

const box = (cls, children, extra = {}) => ({ type: "box", class: cls, children, ...extra });
const text = (cls, t, extra = {}) => ({ type: "text", class: cls, text: t, ...extra });
const img = (cls, src, extra = {}) => ({ type: "image", class: cls, src, ...extra });
const ui = (n) => `asset:ui/${n}.png`;

// ---- shared pieces ---------------------------------------------------------------

const header = box("header", [
  box("stripes", []),
  box("header-body", [
    box("loc-pill", [img("ic8", ui("ic-pin")), text("loc-text", "{location}")]),
    box("grow", []),
    box("hstat", [img("ic8", ui("ic-clock")), text("num hnum", "{time}")]),
    box("hstat", [img("ic8", ui("ic-coin")), text("num hnum", "{money}")]),
  ]),
  box("stripes", []),
]);

const TABS = [
  ["map", "MAP"],
  ["party", "PARTY"],
  ["bag", "BAG"],
  ["dex", "DEX"],
  ["trainer", "CARD"],
  ["battle", "BATTLE"],
];
const dock = (active) =>
  box(
    "dock",
    TABS.map(([page, label]) => ({
      type: "button",
      class: `dock-btn dock-${page}${page === active ? " on" : ""}`,
      onClick: [{ navigate: page }],
      children: [
        box("dock-inner", [img("dock-icon", `asset:dock/${page}.png`), text("dock-label", `[${label}]`)]),
      ],
    })),
  );

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
  bindStyle: { "background-color": `{${p}tone}`, color: `{${p}ink}` },
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

const bigCard = (p) =>
  box(
    "card pcard",
    [
      ring(p),
      sprite(p, "sprite-l"),
      box("pcard-body", [
        box("name-row", [text("mon-name", `{${p}name}`), box("grow", []), text("num lv", `Lv{${p}level}`)]),
        box("name-row", [typeChips(p), box("grow", []), statusChip(p)]),
        hpRow(p, false),
        box("hp-foot", [box("grow", []), text("num hp-big", `{${p}hp}/{${p}maxHp}`)]),
      ]),
      strike(p),
    ],
    { ...cardBase(p), ...(p === "" ? { onClick: openDetail } : {}) },
  );

// ---- pages -------------------------------------------------------------------------

const mapPage = box("content two-col map-cols", [
  panel("radar-panel", "RADAR MAP", [
    box("radar", [
      img("radar-img", "$map.image"),
      {
        type: "list",
        class: "pins",
        items: "$map.pins",
        template: img("pin", ui("ic-pin"), { bindStyle: { left: "{x}%", top: "{y}%" } }),
      },
      box("cross-anchor", [img("crosshair", ui("crosshair")), img("you", ui("ic-you"))], {
        bindStyle: { left: "{map.x}%", top: "{map.y}%" },
        visibleIf: "$map.onMap",
      }),
    ]),
    // Wild Pokemon on this map: tap the method tag for the next method (grass, surf, rods).
    box("wild", [
      {
        type: "button",
        class: "wild-method",
        onClick: { call: "nextWild" },
        children: [text("wild-label", "WILD HERE"), text("wild-method-text", "{map.wildMethod}")],
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
  ], [chip("{map.region}", "chip-red")]),
  panel("quick-panel", "QUICK PARTY", [
    { type: "list", class: "qlist", items: "$party", empty: "NO POKéMON", template: quickCard("") },
  ], [chip("{partyCount} MON", "chip-green")]),
]);

const partyPage = box("content", [
  panel("party-panel", "PARTY", [
    { type: "list", class: "pgrid", items: "$party", empty: "NO POKéMON", template: bigCard("") },
  ], [chip("{partyCount} MON", "chip-blue")]),
]);

const pocket = (title, path) => ({
  title,
  child: {
    type: "list",
    class: "item-grid",
    items: `$bag.${path}`,
    empty: "EMPTY POCKET",
    template: box("item-row", [img("item-icon", "$icon"), text("item-name", "{name}"), box("grow", []), text("num item-count", "{count}")]),
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
  ], [chip("{bag.total} ITEMS", "chip-yellow")]),
]);

const dexStat = (cls, label, num, pct) =>
  box(`dex-stat ${cls}`, [
    box("dex-stat-head", [text("dex-label", label), box("grow", []), text("num dex-of", "/{dex.total}")]),
    text("num dex-num", num),
    { type: "bar", class: "dex-bar", value: pct, max: 1 },
  ]);
const dexPage = box("content two-col", [
  panel("dex-panel", "POKéDEX", [
    dexStat("seen", "SEEN", "{dex.seen}", "$dex.seenPct"),
    dexStat("caught", "CAUGHT", "{dex.caught}", "$dex.caughtPct"),
  ], [chip("KANTO", "chip-green")]),
  panel("dex-side", "COMPLETION", [
    box("complete", [text("num complete-num", "{dex.completion}"), text("complete-sub", "OF KANTO REGISTERED")]),
    box("last", [
      text("last-label", "HIGHEST No."),
      box("last-row", [
        box("sprite-slot sprite-dex", [img("sprite", "$dex.last.sprite")]),
        box("last-id", [text("num last-no", "No.{dex.last.no}"), text("last-name", "{dex.last.name}")]),
      ]),
    ]),
  ]),
]);

const idRow = (k, v, icon) =>
  box("id-row", [...(icon ? [img("ic8", ui(icon))] : []), text("id-key", k), box("grow", []), text("num id-val", v)]);
const trainerPage = box("content two-col trainer-cols", [
  panel("id-panel", "TRAINER CARD", [
    box("id-card", [
      box("id-band", [text("id-band-text", "IDNo."), box("grow", []), text("num id-no", "{trainer.id}")]),
      box("id-main", [
        box("id-photo", [img("id-photo-img", "asset:dock/trainer.png")]),
        box("id-rows", [
          idRow("NAME", "{trainer.name}"),
          idRow("MONEY", "{trainer.money}", "ic-coin"),
          idRow("TIME", "{trainer.time}", "ic-clock"),
          idRow("DEX", "{trainer.caught}"),
          idRow("BADGES", "{trainer.badges}"),
        ]),
      ]),
    ]),
  ]),
  panel("badge-panel", "BADGES", [
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
  ], [chip("{trainer.badges}", "chip-yellow")]),
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
const side = (p, title, cls) =>
  panel(`battle-side ${cls}`, title, [bigCard(p), statList(p)]);
const battlePage = box("content battle-content", [
  box("battle-cols", [side("battle.you.", "YOU", "you-side"), side("battle.foe.", "FOE", "foe-side")], {
    visibleIf: "$battle.inBattle",
  }),
  box("no-battle", [
    box("no-battle-card", [img("no-battle-icon", "asset:dock/battle.png"), text("no-battle-text", "NO BATTLE"), text("no-battle-sub", "STATS APPEAR WHEN A FIGHT STARTS")]),
  ], { visibleIf: "$battle.noBattle" }),
]);

const infoRow = (k, v, extra = []) =>
  box("info-row", [text("info-key", k), box("grow", []), ...extra, text("info-val", v)]);
const detailPage = box("content two-col", [
  panel("sum-panel", "SUMMARY", [
    box("card sum-card", [
      sprite("ui.", "sprite-xl"),
      box("pcard-body", [
        box("name-row", [text("num dex-no", "No.{ui.dex}"), box("grow", []), text("num lv", "Lv{ui.level}")]),
        text("mon-name sum-name", "{ui.name}"),
        box("name-row", [typeChips("ui."), box("grow", []), statusChip("ui.")]),
      ]),
    ], { bindStyle: { "background-color": "{ui.tone}", color: "{ui.ink}" } }),
    box("meter", [
      hpRow("ui.", true),
      box("hp-foot", [text("meter-key", "EXP"), box("grow", []), text("num meter-val", "{ui.toNext} TO NEXT")]),
      { type: "bar", class: "exp", value: "$ui.expPct", max: 1 },
    ]),
    box("info", [
      infoRow("NATURE", "{ui.nature}"),
      infoRow("ABILITY", "{ui.ability}"),
      infoRow("ITEM", "{ui.item}", [img("info-icon", "$ui.itemIcon", { visibleIf: "$ui.hasItem" })]),
    ]),
  ], [{ type: "button", class: "chip back-btn", onClick: "back", children: [text("chip-text", "< BACK")] }]),
  panel("stat-panel", "STATS", [
    {
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
    text("sub-label", "MOVES"),
    {
      type: "list",
      class: "move-grid",
      items: "$ui.moves",
      template: box("move", [
        box("move-top", [img("type-img", "$type"), box("grow", []), text("num move-pp", "{pp}")]),
        text("move-name", "{name}"),
      ]),
    },
  ]),
]);

const page = (name, content) => ({ name, child: box(`page page-${name}`, [content, dock(name)]) });

const layout = box("screen-root", [
  box("waiting", [
    box("boot", [
      box("boot-stripes", []),
      text("boot-title", "POKEMON"),
      text("boot-sub", "FIRERED LINK"),
      box("boot-pill", [text("boot-pill-text", "GBADUO COMPANION PACK")]),
      box("boot-stripes", []),
    ]),
  ], { visibleIf: "$waiting" }),
  box("shell", [
    header,
    {
      type: "pages",
      pages: [
        page("map", mapPage),
        page("party", partyPage),
        { name: "detail", child: box("page page-detail", [detailPage, dock("party")]) },
        page("bag", bagPage),
        page("dex", dexPage),
        page("trainer", trainerPage),
        page("battle", battlePage),
      ],
    },
  ], { visibleIf: "$ready" }),
], { id: "screen" });

fs.writeFileSync(new URL("../layout.json", import.meta.url), JSON.stringify(layout, null, 2) + "\n");
console.log("ok");
