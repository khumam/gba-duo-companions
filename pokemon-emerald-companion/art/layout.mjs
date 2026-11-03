// Writes layout.json for the Emerald "trainer console". Every ring page shares a header band (page name +
// ring dots, clock, money, dex, badge gems) and the bottom bar (prev | current | next):
//
//   node art/layout.mjs

import fs from "node:fs";

const box = (cls, children, extra = {}) => ({ type: "box", class: cls, children, ...extra });
const text = (cls, t, extra = {}) => ({ type: "text", class: cls, text: t, ...extra });
const img = (cls, src, extra = {}) => ({ type: "image", class: cls, src, ...extra });
const ui = (n) => `asset:ui/${n}.png`;
const grow = box("grow", []);
const list = (cls, items, template, extra = {}) => ({ type: "list", class: cls, items, template, ...extra });

// ---- chrome ------------------------------------------------------------------------------
const RING = [["bag", "BAG"], ["map", "MAP"], ["party", "POKéMON"], ["dex", "POKéDEX"], ["options", "OPTIONS"]];

const gems = list("gems", "$badges", img("gem", "$src", { classIf: { off: "$locked" } }));
const stat = (icon, value, cls = "") => box(`hstat ${cls}`.trim(), [img("hicon", ui(icon)), text("hval", value)]);
const header = (title, active) =>
  box("hdr", [
    box("hdr-title", [
      text("hdr-name", title),
      box("hdr-dots", RING.map((_, i) => box(`dot${i === active ? " on" : ""}`, []))),
    ]),
    box("hdr-tail", [stat("clock", "{time}"), stat("coin", "{money}", "money"), gems]),
  ]);
const detailHeader = box("hdr", [
  box("hdr-title", [text("hdr-name", "POKéMON INFO")]),
  box("hdr-tail", [stat("clock", "{time}"), stat("coin", "{money}", "money"), gems]),
]);
const battleHeader = (title) =>
  box("hdr hdr-battle", [
    box("hdr-title", [text("hdr-name", title)]),
    box("hdr-tail", [text("hdr-where", "{map.route}"), grow, stat("coin", "{money}", "money")]),
  ]);

const nav = (to, label, side) => ({
  type: "button",
  class: `bar-btn bar-${side}`,
  onClick: [{ navigate: to }],
  children: [
    ...(side === "l" ? [img("chev", ui("chev-l"))] : []),
    text("bar-label", label),
    ...(side === "r" ? [img("chev", ui("chev-r"))] : []),
  ],
});
const ringBar = (i, mid) => {
  const [pp, pl] = RING[(i + RING.length - 1) % RING.length];
  const [np, nl] = RING[(i + 1) % RING.length];
  return box("bar", [nav(pp, pl, "l"), box("bar-mid", [text("bar-title", mid ?? RING[i][1])]), nav(np, nl, "r")]);
};
const backBtn = (side, label = "BACK") => ({
  type: "button",
  class: `bar-btn bar-${side}`,
  onClick: "back",
  children: [text("bar-label", label)],
});

// ---- shared pieces ------------------------------------------------------------------------
const win = (cls, title, body, chip) =>
  box(`win ${cls}`, [
    box("wtop", [box("wtab", [text("wtab-text", title)]), grow, ...(chip ? [chip] : [])]),
    box("wbody", body),
  ]);
const chip = (t, cls = "") => box(`chip ${cls}`.trim(), [text("chip-text", t)]);

const hp = (p) =>
  box("hp-row", [
    box("hp-tag", [text("hp-tag-text", "HP")]),
    {
      type: "bar",
      class: "hp",
      classIf: { high: `$${p}hpHigh`, mid: `$${p}hpMid`, low: `$${p}hpLow` },
      value: `$${p}hpPct`,
      max: 1,
    },
  ]);
const sprite = (p, cls) => box(`sprite-slot ${cls}`, [img("sprite", `$${p}sprite`)]);
const typeRow = (p) => list("type-row", `$${p}types`, img("type-img", "$src"));
const gender = (p) => [
  img("gender", ui("male"), { visibleIf: `$${p}male` }),
  img("gender", ui("female"), { visibleIf: `$${p}female` }),
];
const status = (p) => box("status", [text("status-text", `{${p}status}`)], { visibleIf: `$${p}hasStatus` });
const page = (name, content, bar, head) => ({ name, child: box(`page page-${name}`, [head, content, bar]) });

// ---- 1. bag -------------------------------------------------------------------------------
const row = (k, v) => box("irow", [text("ikey", k), grow, text("ival", v)]);
const selectItem = [{ set: { selName: "{name}", selDesc: "{desc}", selIcon: "{icon}", selHasIcon: "{hasIcon}", selQty: "{count}", selPrice: "{price}" } }];
const pocket = (title, path) => ({
  title,
  child: list(
    "item-list",
    `$bag.${path}`,
    box("item-row", [
      box("item-ico", [img("item-img", "$icon", { visibleIf: "$hasIcon" })]),
      text("item-name", "{name}"),
      grow,
      text("item-count", "{count}"),
    ], { onClick: selectItem }),
    { empty: "NOTHING HERE" },
  ),
});
const bagPage = box("bag-grid", [
  win("list-win", "POCKETS", [
    {
      type: "tabs",
      class: "pockets",
      tabs: [pocket("ITEMS", "items"), pocket("BALLS", "balls"), pocket("TM/HM", "tmHm"), pocket("BERRIES", "berries"), pocket("KEY", "keyItems")],
    },
  ], chip("{bag.total} ITEMS", "chip-lilac")),
  win("insp-win", "ITEM", [
    box("insp-empty", [text("insp-empty-text", "YOUR BAG IS EMPTY"), text("insp-empty-sub", "ITEMS SHOW UP HERE AS YOU FIND THEM")], { visibleIf: "$bag.isEmpty" }),
    box("insp-head", [
      box("insp-slot", [img("insp-img", "$ui.selIcon", { visibleIf: "$ui.selHasIcon" })]),
      box("insp-title", [text("insp-name", "{ui.selName}"), box("name-row", [chip("{ui.selQty}", "chip-peach"), chip("¥{ui.selPrice}", "chip-sage")])]),
    ], { visibleIf: "$bag.hasAny" }),
    box("insp-desc", [text("insp-text", "{ui.selDesc}")], { visibleIf: "$bag.hasAny" }),
    box("insp-foot", [text("slots-k", "BAG SLOTS"), grow, text("slots-v", "{bag.used}/{bag.capacity}")]),
  ]),
]);

// ---- 2. map -------------------------------------------------------------------------------
const tile = (k, v, icon) => box("mtile", [...(icon ? [img("hicon", ui(icon))] : []), box("mtile-body", [text("mtile-k", k), text("mtile-v", v)])]);
const mapPage = box("map-area", [
  box("map-frame", [
    box("map-stage", [
      box("map-pic", [
        img("map-img", "$map.image"),
        box("cross-anchor", [box("halo", []), img("you", ui("pin"))], { visibleIf: "$map.hasMe", bindStyle: { left: "{map.mx}", top: "{map.my}" } }),
      ], { visibleIf: "$map.live" }),
      box("map-off", [text("map-off-text", "THE MAP DRAWS WHEN YOU ARE OUT IN THE GAME")], { visibleIf: "$map.off" }),
    ]),
    box("map-label", [text("map-label-text", "AREA MAP")]),
  ]),
  box("mtiles", [tile("YOU ARE IN", "{map.route}", "pin"), tile("{map.kind}", "X{map.px}  Y{map.py}")]),
]);

// ---- 3. pokemon ---------------------------------------------------------------------------
const DETAIL_KEYS = [
  "name", "level", "dex", "sprite", "types", "hp", "maxHp", "hpPct", "hpHigh", "hpMid", "hpLow", "male", "female",
  "ot", "id", "ability", "abilityText", "nature", "metLevel", "metPlace", "toNext", "expPct", "item", "ribbon",
  "heldIcon", "hasHeld", "friendPct", "status", "hasStatus", "statRows", "exp", "friendship", "moves", "moveDesc", "contestDesc", "condition", "sheen", "sheenPct",
];
const openFrom = (p) => [{ set: Object.fromEntries(DETAIL_KEYS.map((k) => [k, `{${p}${k}}`])) }, { navigate: "detail" }];
const openDetail = [{ set: Object.fromEntries(DETAIL_KEYS.map((k) => [k, `{${k}}`])) }, { navigate: "detail" }];

const card = box(
  "pcard",
  [
    sprite("", "sprite-s"),
    box("pcard-body", [
      box("name-row", [text("mon-name", "{name}"), ...gender(""), grow, text("lv", "Lv{level}")]),
      box("name-row", [typeRow(""), grow, status("")]),
      box("hp-line", [hp(""), text("hp-num", "{hp}/{maxHp}")]),
    ]),
  ],
  { classIf: { lead: "$lead", fainted: "$fainted" }, onClick: openDetail },
);
const partyPage = box("party-area", [
  box("team", [
    img("team-ball", ui("ball")),
    box("team-text", [text("team-k", "TEAM HP"), text("team-v", "{team.hp}/{team.maxHp}")]),
    { type: "bar", class: "hp team-bar", value: "$team.hpPct", max: 1, classIf: { high: "$team.hpHigh", mid: "$team.hpMid", low: "$team.hpLow" } },
    chip("{partyCount}/6", "chip-sage"),
  ]),
  list("pgrid", "$party", card, { empty: "NO POKéMON YET" }),
]);

// ---- 3.1 detail ----------------------------------------------------------------------------
const section = (title, ...body) => box("section", [box("section-tab", [text("section-title", title)]), ...body]);
const pill = (v) => box("pill", [text("pill-text", v)]);

const infoTab = {
  title: "INFO",
  child: box("tab-body t-info", [
    section("PROFILE", row("OT/{ui.ot}", "ID No.{ui.id}"), box("irow", [text("ikey", "TYPE/"), typeRow("ui.")])),
    section("ABILITY", row("{ui.ability}", ""), text("idesc", "{ui.abilityText}")),
    section("TRAINER MEMO", text("idesc", "{ui.nature} nature, met at Lv{ui.metLevel}, {ui.metPlace}.")),
  ]),
};
const statRow = box(
  "srow",
  [
    text("stat-name", "{label}"),
    { type: "bar", class: "sbar", classIf: { up: "$up", down: "$down" }, value: "$pct", max: 1 },
    text("stat-val", "{value}"),
    text("stat-ev", "{ev}"),
  ],
  { classIf: { up: "$up", down: "$down" } },
);
const skillsTab = {
  title: "SKILLS",
  child: box("tab-body t-skills", [
    section("STATS", list("stat-list", "$ui.statRows", statRow)),
    section("EXP.", box("exp-block", [box("irow", [text("ikey", "EXP. POINTS"), grow, text("ival", "{ui.exp}")]), box("irow", [text("ikey", "NEXT LV."), grow, text("ival", "{ui.toNext}")]), { type: "bar", class: "exp", value: "$ui.expPct", max: 1 }])),
  ]),
};
const moveCard = (setKey, descKey, chipNode, sub) =>
  box("mrow", [
    chipNode,
    box("mmain", [text("mname", "{name}"), sub]),
    box("mpp", [text("mpp-num", "{pp}"), { type: "bar", class: "ppbar", value: "$ppPct", max: 1, classIf: { low: "$ppLow" } }]),
  ], { onClick: [{ set: { [setKey]: `{${descKey}}` } }], visibleIf: "$has" });
const movesTab = {
  title: "MOVES",
  child: box("tab-body t-moves", [
    section("MOVES", list("mlist", "$ui.moves", moveCard("moveDesc", "desc", box("mchip", [img("type-img", "$type", { visibleIf: "$has" })]), text("msub", "PWR {power}  ACC {acc}")))),
    section("DESCRIPTION", text("mdesc", "{ui.moveDesc}")),
  ]),
};
const condRow = box("crow", [text("cond-name", "{label}"), { type: "bar", class: "cbar", value: "$pct", max: 1, bindStyle: { "--c": "{color}" } }, text("cond-val", "{value}")]);
const contestTab = {
  title: "CONTEST",
  child: box("tab-body t-contest", [
    section("CONDITION", list("cond-list", "$ui.condition", condRow)),
    section("MOVES", list("mlist compact", "$ui.moves", moveCard("contestDesc", "cdesc", box("mchip wide", [box("cchip", [text("cchip-text", "{contest}")], { visibleIf: "$has", bindStyle: { "background-color": "{contestColor}" } })]), box("none", [])))),
  ]),
};
const detailPage = box("detail-grid", [
  box("mon-col", [
    box("mon-top", [text("dexno", "No.{ui.dex}"), grow, ...gender("ui.")]),
    box("mon-window", [sprite("ui.", "sprite-xl")]),
    text("mon-name big", "{ui.name}"),
    box("name-row", [img("ball-ico", ui("ball")), text("lv", "Lv{ui.level}"), grow, status("ui.")]),
    typeRow("ui."),
    hp("ui."),
    box("name-row", [grow, text("hp-num", "{ui.hp}/{ui.maxHp}")]),
  ]),
  { type: "tabs", class: "dtabs", tabs: [infoTab, skillsTab, movesTab, contestTab] },
]);

// ---- 4. pokedex ---------------------------------------------------------------------------
// 24 national numbers at a time (main.lua keeps the window and the selection); tap a row to read its entry.
const dexRow = box(
  "dex-row",
  [
    box("dex-thumb", [img("dex-img", "$sprite", { visibleIf: "$seen" }), text("dex-q", "?", { visibleIf: "$unseen" })]),
    box("dex-info", [text("dex-no", "No.{no}"), text("dex-name", "{name}")]),
    img("dex-ball", ui("ball"), { visibleIf: "$own" }),
  ],
  { classIf: { sel: "$sel", unseen: "$unseen" }, onClick: [{ call: "dexSelect", args: ["{num}"] }] },
);
const pager = (delta, side) => ({ type: "button", class: "pg-btn", onClick: [{ call: "dexPage", args: [delta] }], children: [img("chev", ui(`chev-${side}`))] });
const dexStat = box("dstat", [text("dstat-name", "{label}"), { type: "bar", class: "sbar", value: "$pct", max: 1 }, text("dstat-val", "{value}")]);
const dexPage = box("dex-grid", [
  win("dex-list-win", "POKéDEX", [
    box("pager", [pager(-1, "l"), box("pager-mid", [text("pager-text", "{dex.range}"), text("pager-sub", "PAGE {dex.page}")]), pager(1, "r")]),
    list("dex-list", "$dex.entries", dexRow),
  ], chip("{dexCaught} OWN", "chip-peach")),
  win("dex-entry-win", "ENTRY", [
    box("dex-hero", [
      box("dex-big", [img("dex-big-img", "$dex.sel.sprite", { visibleIf: "$dex.sel.seen" }), text("dex-big-q", "?", { visibleIf: "$dex.sel.unseen" })]),
      box("dex-id", [
        box("name-row", [text("dex-sel-no", "No.{dex.sel.no}"), grow, img("dex-ball", ui("ball"), { visibleIf: "$dex.sel.own" })]),
        text("dex-sel-name", "{dex.sel.name}"),
        text("dex-cat", "{dex.sel.category}"),
        typeRow("dex.sel."),
      ]),
    ]),
    box("dex-meas", [
      box("meas", [text("meas-k", "HT"), text("meas-v", "{dex.sel.height}")]),
      box("meas", [text("meas-k", "WT"), text("meas-v", "{dex.sel.weight}")]),
      box("meas grow", [text("meas-k", "ABILITY"), text("meas-v", "{dex.sel.abilities}")]),
    ]),
    box("insp-desc", [text("insp-text", "{dex.sel.desc}")]),
    list("dex-stats", "$dex.sel.stats", dexStat),
  ], chip("{dex.sel.state}", "chip-sage")),
]);

// ---- 5. options / trainer ----------------------------------------------------------------
const idRow = (k, v, icon) => box("id-row", [box("id-ico-slot", icon ? [img("id-ico", ui(icon))] : []), text("id-key", k), grow, text("id-val", v)]);
const badge = box("badge", [img("badge-img", "$src", { classIf: { off: "$locked" } })], { classIf: { earned: "$earned", locked: "$locked" } });
const optionsPage = box("options-area", [
  win("card-win", "TRAINER CARD", [
    box("id-card", [
      box("id-band", [text("id-band-text", "{trainer.name}"), grow, text("id-band-no", "ID No.{trainer.id}")]),
      idRow("MONEY", "¥{money}", "coin"),
      idRow("TIME", "{time}", "clock"),
      idRow("POKéDEX", "{dexCaught} OWN", "dex"),
      idRow("BADGES", "{badgeCount}/8", "badge1"),
    ]),
  ]),
  box("side-col", [
    win("set-win", "SETTINGS", [
      { type: "button", class: "opt-btn", onClick: { call: "wideView", args: ["toggle"] }, children: [text("opt-label", "WIDE VIEW"), grow, text("opt-state", "{_wideLabel}")] },
    ]),
    win("badge-win", "BADGES", [list("badge-grid", "$badges", badge)]),
  ]),
]);

// ---- battle --------------------------------------------------------------------------------
const combatant = (p, cls) =>
  box(`combatant ${cls}`, [
    box("c-top", [sprite(p, "sprite-m"), box("c-id", [box("name-row", [text("mon-name", `{${p}name}`), ...gender(p), grow, text("lv", `Lv{${p}level}`)]), typeRow(p), status(p)])]),
    hp(p),
    box("name-row", [chip("STATS", "chip-lilac"), grow, text("hp-num", `{${p}hp}/{${p}maxHp}`)]),
  ], { onClick: openFrom(p === "battle.you." ? "battle.youMon." : "battle.foeMon.") });
const tileBtn = (cls, label, sub, idx, on) => ({
  type: "button",
  class: `tile ${cls}`,
  classIf: { on },
  onClick: [{ call: "setAction", args: [idx] }],
  children: [text("tile-label", label), text("tile-sub", sub)],
});
const battlePage = box("battle-area", [
  box("combatants", [combatant("battle.you.", "c-you"), combatant("battle.foe.", "c-foe")]),
  {
    type: "button",
    class: "fight-btn",
    classIf: { on: "$battle.actFight" },
    onClick: [{ call: "setAction", args: [0] }],
    children: [text("fight-label", "FIGHT"), text("fight-sub", "{battle.best}")],
  },
  box("tiles", [
    tileBtn("t-bag", "BAG", "{battle.bagText}", 1, "$battle.actBag"),
    tileBtn("t-mon", "POKéMON", "{partyCount} IN TEAM", 2, "$battle.actMon"),
    tileBtn("t-run", "RUN", "{battle.runText}", 3, "$battle.actRun"),
  ]),
]);

const stageRow = box("bstat", [text("stat-name", "{name}"), grow, text("stat-stage", "{stage}")], { classIf: { up: "$up", down: "$down" } });
const side = (p, cls) =>
  box(`side ${cls}`, [
    box("name-row", [text("mon-name", `{${p}name}`), ...gender(p), grow, text("lv", `Lv{${p}level}`)]),
    typeRow(p),
    hp(p),
    box("name-row", [chip("STATS", "chip-lilac"), status(p), grow, text("hp-num", `{${p}hp}/{${p}maxHp}`)]),
    list("bstat-list", `$${p}stats`, stageRow, { empty: "STATS UNCHANGED" }),
  ], { onClick: openFrom(p === "battle.you." ? "battle.youMon." : "battle.foeMon.") });
const skill = box(
  "skill",
  [
    img("type-img", "$type", { visibleIf: "$has" }),
    box("skill-main", [text("skill-name", "{name}"), text("skill-sub", "{info}")]),
    box("skill-right", [box("eff", [text("eff-text", "{eff}")], { classIf: { se: "$se", nve: "$nve", imm: "$imm" }, visibleIf: "$has" }), text("skill-pp", "{pp}")]),
  ],
  { classIf: { se: "$se", nve: "$nve", imm: "$imm", on: "$sel" }, visibleIf: "$has", onClick: [{ call: "setMove", args: ["{@index}"] }] },
);
const battleDetailPage = box("battle-area", [
  box("sides", [side("battle.you.", "side-you"), side("battle.foe.", "side-foe")]),
  list("skills", "$battle.moves", skill),
]);
const battleBar = box("bar", [{ type: "button", class: "bar-btn bar-full", onClick: [{ navigate: "battle" }], children: [text("bar-title", "BATTLE")] }]);

// ---- root ----------------------------------------------------------------------------------
const layout = box(
  "screen-root",
  [
    box("waiting", [box("boot", [img("boot-ball", ui("ball")), text("boot-title", "POKéMON"), text("boot-sub", "EMERALD VERSION"), text("boot-pill", "GBA DUO COMPANION PACK")])], { classIf: { gone: "$ready" } }),
    box("shell", [
      {
        type: "pages",
        initial: "bag",
        pages: [
          page("bag", bagPage, ringBar(0), header("BAG", 0)),
          page("map", mapPage, ringBar(1, "{map.route}"), header("MAP", 1)),
          page("party", partyPage, ringBar(2), header("POKéMON", 2)),
          page("detail", detailPage, box("bar", [backBtn("l"), box("bar-mid", [text("bar-title", "POKéMON INFO")]), backBtn("r")]), detailHeader),
          page("dex", dexPage, ringBar(3), header("POKéDEX", 3)),
          page("options", optionsPage, ringBar(4), header("TRAINER", 4)),
          page("battle", battlePage, battleBar, battleHeader("BATTLE")),
          page("battle-detail", battleDetailPage, battleBar, battleHeader("MOVES")),
        ],
      },
    ], { classIf: { on: "$ready" } }),
  ],
  { id: "screen" },
);

fs.writeFileSync(new URL("../layout.json", import.meta.url), JSON.stringify(layout, null, 2) + "\n");
console.log("ok");
