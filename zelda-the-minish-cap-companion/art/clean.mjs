// The "Clean" style of the Minish Cap companion: a slate (design: .idea/plans/mc-design4 in the app repo, after a Sheikah-slate inventory).
// One flat near-black surface. Top bar: five flat category glyphs (the active one white, its name above it), Ezlo, and one fact box
// (rupees, kinstones, the B and A items). Under it every page is a master (grid, map, list) on the left and ONE inspector on the right
// that holds the text (big picture, italic name, hairline, details), marked by a single accent line. Flat outlined buttons sit under
// the master for the page's actions. Same bindings as the stone style (main.lua is shared; the clean-only fields are added at its end).
// The old clean style is in art/clean-v1/.
// buildClean(h) returns the root node; h = { box, text, img, button, list, bar, ui, icon, grow } from layout.mjs.

export function buildClean(h) {
  const { box, text, img, button, list, bar, ui, icon, grow } = h;
  const btn = (cls, onClick, children, extra = {}) => ({ ...button(cls, onClick, children), ...extra });

  // ---- top bar: tabs, Ezlo, the fact box ------------------------------------------------------------------------------------
  const ORDER = ["map", "items", "kinstone", "quest", "options"];
  const TITLES = { map: "Map", items: "Gear", kinstone: "Kinstones", quest: "Quest", options: "Options" };
  const tab = (t, on) =>
    on
      ? box("tab on", [text("tab-label", TITLES[t]), img("tab-glyph", ui(`cg-${t}-on`)), box("tab-line", [])])
      : btn("tab", [{ navigate: t }], [
          box("tab-label-space", []),
          img("tab-glyph", ui(`cg-${t}-off`)),
          ...(t === "kinstone" ? [box("tab-dot", [], { visibleIf: "$kinstone.ready" })] : []),
        ]);
  const equipCell = (key, path) =>
    box(`fact-eq`, [text("fact-key", key), box("fact-well", [img("fact-icon", `$${path}.icon`)])], {
      onDrop: { call: "equip", args: [key, "{drag}"] },
    });
  const topbar = (name) =>
    box("topbar", [
      box("tabs", ORDER.map((t) => tab(t, t === name))),
      grow(),
      btn("ezlo-btn", [{ set: { hint: true } }], [img("ezlo", "$ezlo")]),
      box("facts", [
        box("fact", [img("fact-rupee", ui("rupee-green")), text("num fact-num", "{rupees}")]),
        box("fact", [img("fact-kin", icon("kinstone-red")), text("num fact-num", "{kinstones}")]),
        equipCell("B", "equipB"),
        equipCell("A", "equipA"),
      ]),
    ]);

  // ---- shared pieces ----------------------------------------------------------------------------------------------------------
  const inspector = (children) => box("insp", [box("insp-line", []), box("insp-body", children)]);
  const hair = () => box("hair", []);

  // ---- MAP ------------------------------------------------------------------------------------------------------------------
  const mapTab = (label, worldAt, on) =>
    btn("fbtn", [{ set: { mapWorldAt: worldAt } }], [text("fbtn-t", label)], { classIf: { on } });
  const dungeonView = box(
    "dmap",
    [
      list("dfloors", "$dungeon.floors", box("dfloor", [
        text("dfloor-name", "{name}"),
        grow(),
        img("dfloor-boss", ui("mark-boss"), { visibleIf: "$boss" }),
        img("dfloor-link", "$icons.linkHead", { visibleIf: "$here" }),
      ], { classIf: { here: "$here" } })),
      box("ditems", [
        list("ditem-row", "$dungeon.items", box("dcell", [img("dcell-icon", "$icon")], { classIf: { missing: "$missing" } })),
        box("dcell", [img("dcell-icon", "$dungeon.keyIcon"), text("num badge", "{dungeon.keys}")]),
      ]),
    ],
    { visibleIf: "$map.showDungeon" },
  );
  // The map gets the whole width: the ROM map at 6x (416.5 x 333.2 dp), a narrow inspector beside it, Ezlo's line under both.
  const mapPage = box("content content-col", [
    box("map-row", [
      box("map-view", [
        img("map-img", "$map.image"),
        img("mark-link", "$icons.linkHead", { bindStyle: { left: "{map.linkX}%", top: "{map.linkY}%" } }),
        dungeonView,
      ]),
      inspector([
        box("insp-pic insp-pic-s", [img("insp-sprite", "$link.sprite")]),
        text("insp-name insp-name-s", "{location}"),
        hair(),
        list("hearts", "$link.hearts", img("heart", "$src"), { visibleIf: "$link.hasHearts" }),
        grow(),
        box("map-tabs", [mapTab("World", "{map.visit}", "$map.showWorld"), mapTab("Dungeon", "", "$map.showDungeon")], { visibleIf: "$map.inDungeon" }),
      ]),
    ]),
    btn("say", [{ set: { hint: true } }], [box("insp-line", []), img("say-ezlo", "$ezlo"), text("say-t", "{ezloHint}")]),
  ]);

  // ---- GEAR -----------------------------------------------------------------------------------------------------------------
  const pick = [{ set: { pick: "{name}", pickIcon: "{icon}", pickKey: "{equipKey}", picked: true } }];
  const slot = () =>
    box("cell", [
      img("cell-icon", "$icon", { visibleIf: "$owned" }),
      text("cell-tag", "{onKey}", { visibleIf: "$onKey" }),
      text("num badge", "{count}", { visibleIf: "$hasCount" }),
    ], { classIf: { empty: "$empty", sel: "$sel" }, onClick: pick, drag: "{equipKey}", dragIf: "$canEquip" });
  const gauge = (iconName, val, pct, cls) =>
    box(`gauge ${cls}`, [img("gauge-icon", icon(iconName)), box("gauge-main", [text("num gauge-val", val), ...(pct ? [bar("gauge-bar", pct)] : [])])]);
  const setBtn = (key) =>
    btn("fbtn", [{ call: "equip", args: [key, "{ui.pickKey}"] }], [text("fbtn-t", `Set to ${key}`)], { classIf: { off: "$pickNoEquip" } });
  const itemsPage = box("content", [
    box("master", [
      list("grid", "$items", slot()),
      box("gauges", [
        gauge("bombs", "{gear.bombs}/{gear.bombMax}", "$gear.bombPct", "red"),
        gauge("quiver", "{gear.arrows}/{gear.arrowMax}", "$gear.arrowPct", "blue"),
        gauge("farores-charm", "{gear.charmTime}", null, "plain"),
      ]),
      box("actions", [setBtn("A"), setBtn("B")]),
    ]),
    inspector([
      box("insp-pic", [img("insp-icon", "$ui.pickIcon", { visibleIf: "$ui.picked" })]),
      text("insp-name", "{ui.pick}", { visibleIf: "$ui.picked" }),
      text("insp-name", "Gear", { visibleIf: "$pickNone" }),
      text("insp-sub", "{pickOn}"),
      hair(),
      text("insp-text", "{pickHelp}"),
      grow(),
      hair(),
      box("insp-row", [img("insp-row-icon", "$icons.charm"), text("insp-row-t", "{gear.charm}")]),
    ]),
  ]);

  // ---- KINSTONES --------------------------------------------------------------------------------------------------------------
  const kinPick = [{ set: { kinName: "{name}", kinIcon: "{icon}", kinId: "{id}", kinAmt: "{amount}", kinPicked: true } }];
  const tally = (c) => box("tally", [img("tally-icon", icon(`kinstone-${c}`)), text("num tally-num", `{kinstone.${c}}`)]);
  const kinstonePage = box("content", [
    box("master", [
      list("grid grid-scroll", "$kinstone.pieces", btn("cell", kinPick, [img("cell-kin", "$icon"), text("num badge", "{amount}")], { classIf: { sel: "$sel" } }),
        { empty: "No kinstone pieces yet" }),
      box("alert", [img("alert-icon", icon("kinstone-red")), text("alert-t", "{kinstone.readyHint}")], { visibleIf: "$kinstone.ready" }),
      box("fused", [
        box("fused-line", [text("fused-l", "Fused"), grow(), text("num fused-n", "{kinstone.fused}"), text("num fused-of", " / {kinstone.fusionTotal}")]),
        bar("fused-bar", "$kinstone.fusedPct"),
      ]),
    ]),
    inspector([
      box("insp-pic", [img("insp-kin", "$ui.kinIcon", { visibleIf: "$ui.kinPicked" })]),
      text("insp-name", "{ui.kinName}", { visibleIf: "$ui.kinPicked" }),
      text("insp-name", "Kinstones", { visibleIf: "$kinNone" }),
      text("insp-sub", "{ui.kinId}   {ui.kinAmt}", { visibleIf: "$ui.kinPicked" }),
      hair(),
      text("insp-text", "Fuse a piece with someone who holds its other half.", { visibleIf: "$ui.kinPicked" }),
      text("insp-text", "Tap a piece to see it.", { visibleIf: "$kinNone" }),
      grow(),
      hair(),
      box("tallies", [tally("red"), tally("blue"), tally("green"), tally("gold")]),
    ]),
  ]);

  // ---- QUEST ------------------------------------------------------------------------------------------------------------------
  const qSet = (name, val, src) => [{ set: { qName: name, qVal: val, qIcon: src, qPicked: true } }];
  const stat = (name, src, val, key) => btn("cell", qSet(name, val, `{icons.${key}}`), [img("cell-icon", src), text("num badge", val)]);
  const questPage = box("content", [
    box("master", [
      box("q-grid", [
        list("q-elements", "$quest.elements", btn("cell", qSet("{name}", "{state}", "{icon}"), [img("cell-icon", "$icon")], { classIf: { locked: "$locked" } })),
        stat("Heart pieces", "$icons.heartPiece", "{quest.heartPieces}", "heartPiece"),
      ]),
      box("q-grid", [
        stat("Figurines", "$icons.figurines", "{quest.figurines}", "figurines"),
        stat("Tiger scrolls", "$icons.tigerScroll", "{quest.skills}", "tigerScroll"),
        stat("Shells", "$icons.shell", "{quest.shells}", "shell"),
      ]),
      text("sect", "Errands"),
      list("grid grid-side", "$quest.side", btn("cell", qSet("{name}", "Errand", "{icon}"), [img("cell-icon", "$icon")]), { empty: "No errands right now" }),
    ]),
    inspector([
      box("insp-pic insp-pic-s", [img("insp-icon", "$ui.qIcon")], { visibleIf: "$ui.qPicked" }),
      text("insp-name", "{ui.qName}", { visibleIf: "$ui.qPicked" }),
      text("insp-sub", "{ui.qVal}", { visibleIf: "$ui.qPicked" }),
      text("insp-name", "Dungeons", { visibleIf: "$qNone" }),
      text("insp-sub", "{questDone}", { visibleIf: "$qNone" }),
      hair(),
      list("dlist", "$quest.dungeons", box("drow", [
        box("drow-mark", [img("drow-check", ui("check"), { visibleIf: "$cleared" }), img("drow-here", "$icons.linkHead", { visibleIf: "$here" })]),
        text("drow-name", "{name}"),
      ], { classIf: { cleared: "$cleared", here: "$here" } })),
    ]),
  ]);

  // ---- OPTIONS ----------------------------------------------------------------------------------------------------------------
  const option = (title, desc, call, onKey, labelKey) =>
    btn("opt", call === "writePermission" ? { call } : { call, args: ["toggle"] }, [
      box("opt-text", [text("opt-title", title), text("opt-desc", desc)]),
      text("opt-state", `{${labelKey}}`),
      box("switch", [box("knob", [])], { classIf: { on: `$${onKey}` } }),
    ]);
  const choice = (label, k, v, flag) => btn("choice", [{ set: { [k]: v } }], [text("choice-t", label)], { classIf: { on: `$${flag}` } });
  const lookRow = (title, desc, choices) => box("opt", [box("opt-text", [text("opt-title", title), text("opt-desc", desc)]), box("choices", choices)]);
  const optionsPage = box("content", [
    box("opt-list", [
      lookRow("Style", "The look of this companion. Starts as Stone at every launch.", [
        choice("Stone", "style", "stone", "styleStone"), choice("Clean", "style", "clean", "styleClean"),
      ]),
      lookRow("Theme", "Colours of the clean style.", [
        choice("Slate", "theme", "forest", "themeForest"), choice("Paper", "theme", "parchment", "themeParchment"), choice("Night", "theme", "night", "themeNight"),
      ]),
      option("Wide view", "Paint the world beyond the game's frame. Tap again for extra wide.", "wideView", "_wide", "_wideLabel"),
      option("Colour ambient", "A richer grade with soft shadows, sunlit edges and drifting clouds.", "ambientView", "_ambient", "_ambientLabel"),
      option("Game changes", "Lets this pack hide the game's HUD and equip items. Tap to be asked again.", "writePermission", "_writePerm", "_writePermLabel"),
    ]),
  ]);

  // ---- Ezlo's hint ------------------------------------------------------------------------------------------------------------
  const hint = box("veil", [
    box("bubble", [
      box("insp-line", []),
      box("bubble-pic", [img("bubble-ezlo", "$ezlo")]),
      box("bubble-body", [text("insp-name", "Ezlo"), text("insp-text", "{ezloHint}"), text("bubble-close", "Tap to close")]),
    ]),
  ], { visibleIf: "$ui.hint", onClick: [{ set: { hint: false } }] });

  const page = (name, content) => ({ name, child: box(`page page-${name}`, [topbar(name), content]) });
  return box("root", [
    box("pages-wrap", [{
      type: "pages", class: "pages",
      pages: [page("map", mapPage), page("items", itemsPage), page("kinstone", kinstonePage), page("quest", questPage), page("options", optionsPage)],
    }]),
    hint,
  ]);
}
