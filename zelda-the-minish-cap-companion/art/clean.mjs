// The flat "Clean" style of the Minish Cap companion: top bar (Ezlo, rupees, kinstones, A / B), five icon tabs and, on every page,
// a master (map, tile grid, list) beside a detail panel. Same bindings as the stone style (main.lua is shared).
// buildClean(h) returns the shell node; h = { box, text, img, button, list, bar, ui, icon, grow } from layout.mjs.

export function buildClean(h) {
  const { box, text, img, button, list, bar, ui, icon, grow } = h;

  const chip = (cls, iconNode, bind) => box(`chip ${cls}`, [iconNode, text("num", bind)]);
  const equip = (key, path) =>
    box(
      `equip equip-${key.toLowerCase()}`,
      [
        box("disc", [img("equip-icon", `$${path}.icon`), box("equip-badge", [text("equip-key", key)])]),
        text("equip-name", `{${path}.name}`),
      ],
      { onDrop: { call: "equip", args: [key, "{drag}"] } },
    );
  const topbar = box("topbar", [
    button("ezlo-btn", [{ set: { hint: true } }], [img("ezlo", "$ezlo")]),
    chip("chip-rupee", img("hicon hicon-rupee", ui("rupee-green")), "{rupees}"),
    chip("chip-kin", img("hicon", icon("kinstone-red")), "{kinstones}"),
    grow(),
    equip("A", "equipA"),
    equip("B", "equipB"),
  ]);
  const hint = box(
    "bubble",
    [
      img("bubble-ezlo", "$ezlo"),
      box("bubble-body", [text("bubble-name", "EZLO"), text("bubble-text", "{ezloHint}"), text("bubble-close", "TAP TO CLOSE")]),
    ],
    { visibleIf: "$ui.hint", onClick: [{ set: { hint: false } }] },
  );

  const ORDER = ["map", "items", "kinstone", "quest", "options"];
  const TITLES = { map: "MAPS", items: "ITEMS", kinstone: "KINSTONE", quest: "QUESTS", options: "OPTIONS" };
  const tabInner = (t, on) => [
    img("tab-icon", ui(`tab-${t}-${on ? "on" : "off"}`)),
    text("tab-label", TITLES[t]),
    ...(t === "kinstone" ? [img("tab-alert", icon("kinstone-red"), { visibleIf: "$kinstone.ready" })] : []),
  ];
  const tabs = (name) =>
    box("tabs", ORDER.map((t) => (t === name ? box("tab on", tabInner(t, true)) : button("tab", [{ navigate: t }], tabInner(t, false)))));

  const pane = (cls, title, body) => box(`pane ${cls}`, [...(title ? [text("pane-title", title)] : []), ...body]);

  // ---- maps ----
  const mapTab = (label, worldAt, on) => ({
    type: "button", class: "map-tab", onClick: [{ set: { mapWorldAt: worldAt } }], classIf: { on }, children: [text("map-tab-label", label)],
  });
  const dungeonView = box(
    "dmap",
    [
      box("dmap-head", [text("dmap-name", "{dungeon.name}")]),
      box("dmap-body", [
        list("dmap-floors", "$dungeon.floors", box("dfloor", [
          box("dfloor-mark", [img("dfloor-link", "$icons.linkHead", { visibleIf: "$here" })]),
          text("num dfloor-name", "{name}"),
          box("dfloor-mark", [img("dfloor-boss", ui("mark-boss"), { visibleIf: "$boss" })]),
        ], { classIf: { here: "$here" } })),
        box("dmap-items", [
          list("ditem-row", "$dungeon.items", box("ditem", [box("ditem-slot", [img("ditem-icon", "$icon")]), text("ditem-name", "{name}")], {
            classIf: { missing: "$missing" },
          })),
          box("dkeys", [img("dkey-icon", "$dungeon.keyIcon"), text("num dkey-num", "{dungeon.keys}")]),
        ]),
      ]),
    ],
    { visibleIf: "$map.showDungeon" },
  );
  const mapPage = box("content content-row", [
    box("master master-map", [
      box("map-view", [
        img("map-img", "$map.image"),
        img("mark mark-link", "$icons.linkHead", { bindStyle: { left: "{map.linkX}%", top: "{map.linkY}%" } }),
        dungeonView,
      ]),
    ]),
    box("detail", [
      pane("p-place", "YOU ARE IN", [
        text("place-name", "{location}"),
        box("map-tabs", [mapTab("WORLD", "{map.visit}", "$map.showWorld"), mapTab("DUNGEON", "", "$map.showDungeon")], { visibleIf: "$map.inDungeon" }),
      ]),
      pane("p-link", "LINK", [
        box("link-row", [img("link-sprite", "$link.sprite")]),
        list("hearts", "$link.hearts", img("heart", "$src"), { visibleIf: "$link.hasHearts" }),
      ]),
    ]),
  ]);

  // ---- items ----
  const pick = [{ set: { pick: "{name}", pickIcon: "{icon}", pickKey: "{equipKey}", picked: true } }];
  const slot = () =>
    box("slot", [
      img("slot-icon", "$icon", { visibleIf: "$owned" }),
      box("slot-count", [text("num count", "{count}")], { visibleIf: "$hasCount" }),
    ], { classIf: { empty: "$empty", movable: "$canEquip" }, onClick: pick, drag: "{equipKey}", dragIf: "$canEquip" });
  const gearRow = (iconName, label, val, pct, cls) =>
    box(`gear-row ${cls}`, [
      img("gear-icon", icon(iconName)),
      box("gear-main", [box("gear-line", [text("gear-label", label), grow(), text("num gear-val", val)]), ...(pct ? [bar("gear-bar", pct)] : [])]),
    ]);
  const equipBtn = (key) => button(`eq-btn eq-${key.toLowerCase()}`, [{ call: "equip", args: [key, "{ui.pickKey}"] }], [text("eq-btn-t", `SET ${key}`)]);
  const itemsPage = box("content content-row", [
    box("master", [pane("p-tiles", "ITEMS", [list("item-grid", "$items", slot())])]),
    box("detail", [
      pane("p-picked", "SELECTED  (TAP A TILE)", [
        box("picked-row", [
          box("picked-tile", [img("picked-icon", "$ui.pickIcon")], { visibleIf: "$ui.picked" }),
          text("picked-name", "{ui.pick}", { visibleIf: "$ui.picked" }),
        ]),
        box("eq-row", [equipBtn("A"), equipBtn("B")], { visibleIf: "$ui.pickKey" }),
      ]),
      pane("p-gear", "GEAR", [
        gearRow("bombs", "BOMBS", "{gear.bombs}/{gear.bombMax}", "$gear.bombPct", "red"),
        gearRow("quiver", "ARROWS", "{gear.arrows}/{gear.arrowMax}", "$gear.arrowPct", "blue"),
        gearRow("farores-charm", "CHARM", "{gear.charmTime}", null, "plain"),
        gearRow("shell", "SHELLS", "{gear.shells}", null, "plain"),
        gearRow("heart-piece", "PIECES", "{gear.heartPieces}", null, "plain"),
      ]),
    ]),
  ]);

  // ---- kinstone ----
  const kinPick = [{ set: { kinName: "{name}", kinIcon: "{icon}", kinId: "{id}", kinAmt: "{amount}", kinPicked: true } }];
  const kinstonePage = box("content content-row", [
    box("master", [
      pane("p-pieces", "KINSTONE BAG", [
        list("piece-list", "$kinstone.pieces", button("piece", kinPick, [
          img("piece-icon", "$icon"),
          text("piece-name", "{name}"),
          text("num piece-id", "{id}"),
          text("num piece-amt", "{amount}"),
        ], { classIf: { red: "$isRed", blue: "$isBlue", green: "$isGreen", gold: "$isGold" } }), { empty: "NO KINSTONE PIECES YET" }),
      ]),
    ]),
    box("detail", [
      box("alert", [img("alert-icon", icon("kinstone-red")), text("alert-text", "{kinstone.readyHint}")], { visibleIf: "$kinstone.ready" }),
      pane("p-fusion", "FUSED", [
        box("fuse-count", [text("num fuse-num", "{kinstone.fused}"), text("num fuse-of", "/{kinstone.fusionTotal}")]),
        bar("fuse-bar", "$kinstone.fusedPct"),
        box("tally", [
          box("tally-cell", [img("tally-icon", icon("kinstone-red")), text("num tally-num", "{kinstone.red}")]),
          box("tally-cell", [img("tally-icon", icon("kinstone-blue")), text("num tally-num", "{kinstone.blue}")]),
          box("tally-cell", [img("tally-icon", icon("kinstone-green")), text("num tally-num", "{kinstone.green}")]),
          box("tally-cell", [img("tally-icon", icon("kinstone-gold")), text("num tally-num", "{kinstone.gold}")]),
        ]),
      ]),
      pane("p-kin-picked", "PIECE  (TAP A ROW)", [
        box("picked-row", [
          box("picked-tile", [img("picked-icon", "$ui.kinIcon")], { visibleIf: "$ui.kinPicked" }),
          box("kin-text", [text("kin-name", "{ui.kinName}"), text("num kin-id", "{ui.kinId}  x{ui.kinAmt}")], { visibleIf: "$ui.kinPicked" }),
        ]),
      ]),
    ]),
  ]);

  // ---- quests ----
  const questPage = box("content content-row", [
    box("master", [
      box("q-scroll", [
        pane("p-dungeons", "DUNGEONS", [
          list("dungeon-list", "$quest.dungeons", box("dungeon", [
            box("dg-mark", [img("dg-check", ui("check"), { visibleIf: "$cleared" }), img("dg-here", "$icons.linkHead", { visibleIf: "$here" })]),
            text("dg-name", "{name}"),
          ], { classIf: { cleared: "$cleared", here: "$here" } })),
        ]),
        pane("p-side", "SIDE QUESTS", [
          list("side-list", "$quest.side", box("side", [img("side-icon", "$icon"), text("side-name", "{name}"), text("side-done", "DONE", { visibleIf: "$done" })], {
            classIf: { done: "$done" },
          }), { empty: "NO ERRANDS RIGHT NOW" }),
        ]),
      ]),
    ]),
    box("detail", [
      pane("p-elements", "ELEMENTS", [
        list("element-row", "$quest.elements", box("element", [img("element-icon", "$icon"), text("element-name", "{name}")], {
          classIf: { owned: "$owned", locked: "$locked" },
        })),
      ]),
      pane("p-counts", "COLLECTION", [
        box("stat", [img("stat-icon", icon("figurines")), text("stat-label", "FIGURINES"), grow(), text("num stat-val", "{quest.figurines}")]),
        box("stat", [img("stat-icon", icon("tiger-scroll")), text("stat-label", "SKILLS"), grow(), text("num stat-val", "{quest.skills}")]),
      ]),
    ]),
  ]);

  // ---- options: the switches and the look ----
  const option = (title, desc, call, onKey, labelKey) =>
    button("opt", call === "writePermission" ? { call } : { call, args: ["toggle"] }, [
      box("opt-text", [text("opt-title", title), text("opt-desc", desc)]),
      box("opt-pill", [text("num opt-state", `{${labelKey}}`)], { classIf: { on: `$${onKey}` } }),
    ]);
  const choice = (label, k, v, flag) => button("choice", [{ set: { [k]: v } }], [text("choice-t", label)], { classIf: { on: `$${flag}` } });
  const lookRow = (title, desc, choices) => box("look", [box("opt-text", [text("opt-title", title), text("opt-desc", desc)]), box("choices", choices)]);
  const optionsPage = box("content", [
    box("opt-list", [
      lookRow("STYLE", "The look of this companion. Starts as Stone at every launch.", [
        choice("STONE", "style", "stone", "styleStone"), choice("CLEAN", "style", "clean", "styleClean"),
      ]),
      lookRow("THEME", "Colours of the clean style.", [
        choice("FOREST", "theme", "forest", "themeForest"), choice("PARCHMENT", "theme", "parchment", "themeParchment"), choice("NIGHT", "theme", "night", "themeNight"),
      ]),
      option("WIDE VIEW", "Paint the world beyond the game's frame. Tap again for extra wide.", "wideView", "_wide", "_wideLabel"),
      option("COLOR AMBIENT", "A richer grade with soft shadows, sunlit edges and drifting clouds.", "ambientView", "_ambient", "_ambientLabel"),
      option("GAME CHANGES", "Lets this pack hide the game's own HUD and equip items. Tap to be asked again.", "writePermission", "_writePerm", "_writePermLabel"),
    ]),
  ]);

  const page = (name, content) => ({ name, child: box(`page page-${name}`, [content, tabs(name)]) });
  const shell = box("shell", [
    topbar,
    box("pages-wrap", [{
      type: "pages", class: "pages",
      pages: [page("map", mapPage), page("items", itemsPage), page("kinstone", kinstonePage), page("quest", questPage), page("options", optionsPage)],
    }]),
    hint,
  ]);
  return box("root", [shell]);
}
