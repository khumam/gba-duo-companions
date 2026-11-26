// The "Clean" style of the Oracle of Ages companion: the Minish Cap pack's slate layout (top bar with tabs and one fact box, a
// 5-column master and one inspector that holds the text), dressed in the game's own identity:
//   * the pause screen's off-white panel as the surface and its mauve brick as the hairlines and the inspector line,
//   * the peach HUD strip as the top bar, carrying B [ ] and A [ ], rupees and hearts the way the game's HUD does,
//   * the game's bracket cursor [ ] as the selection, the game's own item icons as the tabs,
//   * Press Start 2P for the small labels and numbers, Jersey 10 for names and text,
//   * three themes: Present (the pause screen), Past (sepia) and Night (the brick wall).
// Page names carry a c prefix (citems, cmap ...) so they never clash with the brick pages. Same main.lua.
// buildClean(h) returns the root node; h = { box, text, img, button, list, ui } from layout.mjs.

export function buildClean(h) {
  const { box, text, img, button, list, ui } = h;
  const grow = () => box("grow", []);
  const brk = (extra = {}) => [box("brk brk-l", [], extra), box("brk brk-r", [], extra)];
  const hair = () => box("hair", []);
  const inspector = (children) => box("insp", [box("insp-line", []), box("insp-body", children)]);

  // ---- top bar: the HUD strip -----------------------------------------------------------------------------------------------
  const TABS = [
    ["citems", "Items", ui("sword")], ["cmap", "Map", ui("cg-map")], ["cseeds", "Seeds", ui("seed-ember")],
    ["crings", "Rings", ui("ring")], ["cstatus", "Status", ui("heart-full")], ["coptions", "Options", ui("cg-options")],
  ];
  const tab = ([name, label, src], on) =>
    on
      ? box("tab on", [box("tab-pic", [...brk(), img("tab-icon", src)])])
      : button("tab", [{ navigate: name }], [box("tab-pic", [img("tab-icon", src)])]);
  const slotHud = (letter, key) =>
    box("hud-eq", [text("hud-key", letter), box("hud-well", [...brk(), img("hud-icon", `$hud.${key}Icon`)])]);
  const topbar = (name) =>
    box("topbar", [
      box("tabs", TABS.map((t) => tab(t, t[0] === name))),
      grow(),
      box("hud", [
        slotHud("B", "b"),
        slotHud("A", "a"),
        box("hud-fact", [img("hud-rupee", ui("rupee")), text("hud-num", "{rupees}")]),
        box("hud-fact", [img("hud-heart", ui("heart-full")), text("hud-num", "{status.hearts}")]),
      ]),
    ]);

  // ---- ITEMS -------------------------------------------------------------------------------------------------------------------
  const pick = [{ set: { pick: "{name}", pickIcon: "{icon}", pickLevel: "{level}", pickTag: "{tag}", picked: true } }];
  const itemsPage = box("content", [
    box("master", [
      list("grid", "$slots", button("cell", pick, [
        ...brk({ visibleIf: "$sel" }),
        img("cell-icon", "$icon"),
        text("cell-tag", "{tag}"),
        text("badge", "{level}"),
      ], { classIf: { empty: "$empty" } })),
      box("eqrow", [
        box("eqcard", [text("eq-key", "B"), img("eq-icon", "$hud.bIcon"), box("eq-text", [text("eq-name", "{hud.bName}"), text("eq-lv", "{hud.bLevel}")])]),
        box("eqcard", [text("eq-key", "A"), img("eq-icon", "$hud.aIcon"), box("eq-text", [text("eq-name", "{hud.aName}"), text("eq-lv", "{hud.aLevel}")])]),
      ]),
    ]),
    inspector([
      box("insp-pic", [img("insp-icon", "$ui.pickIcon")], { visibleIf: "$ui.picked" }),
      text("insp-name", "{ui.pick}", { visibleIf: "$ui.picked" }),
      text("insp-sub", "{ui.pickLevel}", { visibleIf: "$ui.picked" }),
      text("insp-name", "ITEMS", { visibleIf: "$pickNone" }),
      hair(),
      text("insp-text", "Tap an item to look at it. B and A are what Link holds now.", { visibleIf: "$pickNone" }),
      text("insp-text", "On button {ui.pickTag}", { visibleIf: "$ui.pickTag" }),
      text("insp-text", "In the bag. Equip it from the game's item screen.", { visibleIf: "$pickInBag" }),
    ]),
  ]);

  // ---- MAP ---------------------------------------------------------------------------------------------------------------------
  const mapPage = box("content content-col", [
    box("map-row", [
      // pinch / drag the map, or the - / + keys on its corner (app 1.0.3+; older apps show it at 1x)
      box("map-wrap", [
        box("map-view", [
          img("map-img", ui("map-present"), { visibleIf: "$map.present" }),
          img("map-img", ui("map-past"), { visibleIf: "$map.past" }),
          list("map-rows", "$map.rows", list("map-line", "$cells", box("mcell", [], { classIf: { unseen: "$unseen", here: "$here" } }))),
        ], { zoom: { min: 1, max: 4, state: "mapZoom" } }),
        box("zoom-ctl", [
          button("zoom-key", { zoom: "out", state: "mapZoom" }, [text("zoom-key-t", "-")]),
          button("zoom-key", { zoom: "in", state: "mapZoom" }, [text("zoom-key-t", "+")]),
        ]),
      ]),
      inspector([
        text("insp-name", "{map.era}"),
        text("insp-sub", "Era"),
        hair(),
        text("big-num", "{map.count}"),
        text("insp-sub", "rooms seen of 196"),
        hair(),
        text("big-num", "{map.room}"),
        text("insp-sub", "room"),
      ]),
    ]),
    box("strip", [box("insp-line", []), text("strip-l", "EXPLORED"), box("meter", [box("meter-fill", [], { bindStyle: { width: "{exploredPctStr}" } })]), text("strip-n", "{explored}")]),
  ]);

  // ---- SEEDS -------------------------------------------------------------------------------------------------------------------
  const seedPick = [{ set: { seedName: "{name}", seedIcon: "{icon}", seedCount: "{count}", seedTag: "{tag}", seedPicked: true } }];
  const seedsPage = box("content", [
    box("master", [
      // tall seed pouches: the count is the point of the page, so it gets the space
      list("grid tall", "$seeds", button("cell", seedPick, [...brk({ visibleIf: "$sel" }), img("cell-icon", "$icon"), text("tall-num", "{count}"),
        text("cell-tag", "S", { visibleIf: "$picked" })])),
      text("sect", "SUPPLIES"),
      list("supplies", "$supplies", box("supply", [img("cell-icon", "$icon"), text("tall-num", "{value}"), text("supply-l", "{label}")])),
    ]),
    inspector([
      box("insp-pic", [img("insp-icon", "$ui.seedIcon")], { visibleIf: "$ui.seedPicked" }),
      text("insp-name", "{ui.seedName}", { visibleIf: "$ui.seedPicked" }),
      text("insp-sub", "{ui.seedCount} in the satchel", { visibleIf: "$ui.seedPicked" }),
      text("insp-sub", "Shooter / satchel pick", { visibleIf: "$ui.seedTag" }),
      text("insp-name", "SEEDS", { visibleIf: "$seedNone" }),
      hair(),
      text("insp-text", "S marks the seed the satchel throws.", { visibleIf: "$seedNone" }),
    ]),
  ]);

  // ---- RINGS -------------------------------------------------------------------------------------------------------------------
  const ringPick = [{ set: { ringName: "{name}", ringIcon: "{src}", ringState: "{state}", ringId: "{id}", ringPicked: true } }];
  const ringsPage = box("content", [
    box("master", [
      list("grid grid-scroll", "$ringList", button("cell", ringPick, [...brk({ visibleIf: "$sel" }), img("cell-icon", "$src", { classIf: { off: "$off" } })])),
    ]),
    inspector([
      box("insp-pic", [img("insp-icon", "$ui.ringIcon")], { visibleIf: "$ui.ringPicked" }),
      text("insp-name", "{ui.ringName}", { visibleIf: "$ui.ringPicked" }),
      text("insp-sub", "{ui.ringState}", { visibleIf: "$ui.ringPicked" }),
      text("insp-name", "RINGS", { visibleIf: "$ringNone" }),
      text("insp-sub", "{ringCount}", { visibleIf: "$ringNone" }),
      hair(),
      text("sect", "WORN"),
      box("sup", [img("sup-icon", "$ring.wornIcon"), text("sup-l", "{ring.worn}")]),
      text("sect", "RING BOX {ring.boxLevel}"),
      list("box-row", "$ring.box", box("box-cell", [img("box-icon", "$icon")], { classIf: { filled: "$filled" } })),
    ]),
  ]);

  // ---- STATUS ------------------------------------------------------------------------------------------------------------------
  const essPick = [{ set: { essName: "{name}", essIcon: "{src}", essState: "{state}", essPicked: true } }];
  const statusPage = box("content", [
    box("master", [
      box("life", [list("life-hearts", "$status.lifeHearts", img("lheart", "$src")), grow(), list("pieces", "$status.pieces", img("piece", "$src"))]),
      text("sect", "ESSENCES  {status.essenceCount} / 8"),
      list("grid", "$status.essences", button("cell", essPick, [...brk({ visibleIf: "$sel" }), img("cell-ess", "$src", { classIf: { off: "$off" } })])),
      list("facts", "$status.facts", box("fact", [text("fact-l", "{label}"), text("fact-v", "{value}")])),
    ]),
    inspector([
      box("insp-pic", [img("insp-ess", "$ui.essIcon")], { visibleIf: "$ui.essPicked" }),
      text("insp-name", "{ui.essName}", { visibleIf: "$ui.essPicked" }),
      text("insp-sub", "{ui.essState}", { visibleIf: "$ui.essPicked" }),
      text("insp-name", "LINK", { visibleIf: "$essNone" }),
      text("insp-sub", "{status.hearts} hearts", { visibleIf: "$essNone" }),
      hair(),
      text("insp-text", "The eight Essences of Time, one in each dungeon.", { visibleIf: "$essNone" }),
    ]),
  ]);

  // ---- OPTIONS -----------------------------------------------------------------------------------------------------------------
  const choice = (label, k, v, flag) => ({ ...button("choice", [{ set: { [k]: v } }], [...brk({ visibleIf: `$${flag}` }), text("choice-t", label)]), classIf: { on: `$${flag}` } });
  const row = (title, desc, choices) => box("opt", [box("opt-text", [text("opt-title", title), text("opt-desc", desc)]), box("choices", choices)]);
  const optionsPage = box("content", [
    box("opt-list", [
      row("STYLE", "The look of this companion. Starts as Clean at every launch.", [({ ...button("choice", [{ set: { style: "brick", page: "items" } }], [...brk({ visibleIf: "$styleBrick" }), text("choice-t", "Brick")]), classIf: { on: "$styleBrick" } }), choice("Clean", "style", "clean", "styleClean")]),
      row("THEME", "Colours of the clean style.", [choice("Present", "theme", "present", "themePresent"), choice("Past", "theme", "past", "themePast"), choice("Night", "theme", "night", "themeNight")]),
    ]),
  ]);

  const page = (name, content) => ({ name, child: box(`page`, [topbar(name), content]) });
  return box("root", [
    box("pages-wrap", [{
      type: "pages", class: "pages", state: "page", initial: "citems",
      pages: [page("citems", itemsPage), page("cmap", mapPage), page("cseeds", seedsPage), page("crings", ringsPage), page("cstatus", statusPage), page("coptions", optionsPage)],
    }]),
  ]);
}
