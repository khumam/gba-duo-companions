"""Run: python3 tests/check_pokemon_packs.py"""
import json
import re
from pathlib import Path


def css_rule(css, selector):
    match = re.search(rf"(?m)^{re.escape(selector)}\s*\{{([^}}]+)\}}", css)
    assert match, f"Missing CSS rule: {selector}"
    return dict(re.findall(r"([\w-]+):\s*([^;]+);", match[1]))


ROOT = Path(__file__).resolve().parents[1]
PACKS = (
    "pokemon-firered-companion",
    "pokemon-firered-v-companion",
    "pokemon-leafgreen-companion",
    "pokemon-leafgreen-v-companion",
    "pokemon-firered-minimal-companion",
    "pokemon-leafgreen-minimal-companion",
)
PAGES = {"map", "party", "detail", "bag", "dex", "trainer", "battle"}


def walk(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


ids = set()
for name in PACKS:
    pack = ROOT / name
    assert pack.is_dir(), f"Missing variant: {name}"
    manifest = json.loads((pack / "manifest.json").read_text())
    assert manifest["id"] == name, f"Wrong pack ID: {name}"
    assert manifest["id"] not in ids, f"Duplicate ID: {name}"
    ids.add(manifest["id"])
    expected_code = "BPGE" if "leafgreen" in name else "BPRE"
    assert manifest["match"]["gameCode"] == [expected_code], f"Wrong ROM target: {name}"
    if "leafgreen" in name:
        script = (pack / "main.lua").read_text()
        assert "local BASE_STATS_ADDR = 0x08254760" in script, name
        assert "local WILD_HEADERS_ADDR = 0x083C9AF4" in script, name
        assert '["BPGE0"]' in (pack / "town_map.lua").read_text(), name
        assert "0x45475042" in script and "mem.u8(0x080000BC) ~= 0" in script, f"Missing ROM revision guard: {name}"
    for filename in [manifest["layout"], manifest["script"], *manifest["styles"]]:
        assert (pack / filename).is_file(), f"Missing file: {name}/{filename}"
    nodes = list(walk(json.loads((pack / manifest["layout"]).read_text())))
    css = (pack / manifest["styles"][0]).read_text()
    direction = css_rule(css, ".dock")["flex-direction"]
    assert direction == ("column" if name.endswith(("-v-companion", "-minimal-companion")) else "row"), f"Wrong dock orientation: {name}"
    pages = next(node["pages"] for node in nodes if node.get("type") == "pages")
    assert {page["name"] for page in pages} == PAGES, name
    for page in pages:
        dock = next(node for node in walk(page) if node.get("class") == "dock")
        targets = [button["onClick"][0]["navigate"] for button in dock["children"]]
        assert targets == ["map", "party", "bag", "dex", "trainer", "battle"], name
        selected = [button for button in dock["children"] if "on" in button["class"].split()]
        assert len(selected) == 1, name
        assert selected[0]["onClick"][0]["navigate"] == ("party" if page["name"] == "detail" else page["name"]), name
    for node in nodes:
        src = node.get("src", "")
        if src.startswith("asset:"):
            assert (pack / "assets" / src[6:]).is_file(), f"Missing asset: {name}/{src}"

for theme in ("firered", "leafgreen"):
    horizontal = ROOT / f"pokemon-{theme}-companion"
    vertical = ROOT / f"pokemon-{theme}-v-companion"
    for filename in ("main.lua", "game_data.lua", "town_map.lua", "preview-data.json", "layout.json", "art/layout.mjs"):
        assert (horizontal / filename).read_bytes() == (vertical / filename).read_bytes(), f"Variant drift: {theme}/{filename}"

# The minimal packs are the vertical packs with a new skin: the game data is shared, only
# main.lua (card tints) and the look differ. No shipped file may use a font or image they lack.
for theme in ("firered", "leafgreen"):
    vertical = ROOT / f"pokemon-{theme}-v-companion"
    minimal = ROOT / f"pokemon-{theme}-minimal-companion"
    for filename in ("game_data.lua", "town_map.lua", "species_names.lua", "item_names.lua"):
        assert (vertical / filename).read_bytes() == (minimal / filename).read_bytes(), f"Minimal drift: {theme}/{filename}"
    css = (minimal / "style.css").read_text()
    assert "box-shadow" not in css and "hazard" not in css, f"Minimal pack must stay flat: {theme}"
    for font in re.findall(r'url\("assets/(fonts/[^"]+)"\)', css):
        assert (minimal / "assets" / font).is_file(), f"Missing font: {theme}/{font}"

print("PASS: six unique Pokémon packs, navigation, assets and same-theme data parity")
