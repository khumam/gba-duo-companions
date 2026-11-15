"""Turns a Pokemon pack's stylesheet pixel-art: square corners, no gradients or gloss, flat fills,
and the game's own background motif. Run once per pack (it rewrites style.css in place; git has the original).

  python3 -I skill/tools/apply_pixel_css.py pokemon-firered-companion
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]  # the gbaduo-companions folder (this file is in skill/tools/)
BG_SIZE = {"firered": "48px 48px", "leafgreen": "48px 48px", "ruby": "64px 64px", "sapphire": "64px 32px", "emerald": "48px 48px"}
COLOR = r"(var\([^)]*\)|#[0-9A-Fa-f]{3,8}|rgba?\([^)]*\))"


DEPTH_SELECTORS = {
    "frlg": ".panel, .bar-btn, .tile, .fight-btn, .hdr-title, .hdr-tail, .moves-preview",
    "rse": ".win, .bar-btn, .tile, .fight-btn, .hdr, .moves-preview",
}


def transform(css, game):
    # 1. square corners
    css = re.sub(r"border-radius:\s*[^;]+;", "border-radius: 0;", css)
    # 2. gradients -> a flat colour (the lower stop)
    css = re.sub(
        r"background:\s*linear-gradient\([^,]+,\s*" + COLOR + r",\s*" + COLOR + r"\);",
        lambda m: f"background-color: {m.group(2)};",
        css,
    )
    # 3. gloss -> nothing
    css = re.sub(
        r'background-image:\s*url\("assets/ui/gloss\.png"\);\s*background-size:[^;]+;\s*background-repeat:\s*no-repeat;',
        "",
        css,
    )
    # 5. the game's background
    PAGE_BG = "" if game in ("firered", "leafgreen") else (
        '.page, .waiting { background-image: url("assets/ui/px-bg.png"); background-size: ' + BG_SIZE[game] + '; background-repeat: repeat; image-rendering: pixelated; }'
    )
    DEPTH = DEPTH_SELECTORS["frlg" if game in ("firered", "leafgreen") else "rse"]
    css += f"""

/* ---- pixel layer: {game} ---------------------------------------------------------------------- */
#screen {{
  background-image: url("assets/ui/px-bg.png");
  background-size: {BG_SIZE[game]};
  background-repeat: repeat;
  image-rendering: pixelated;
}}
{PAGE_BG}
.hdr-emblem {{ width: 28px; height: 28px; flex-shrink: 0; image-rendering: pixelated; }}
/* hard pixel depth: a solid step of shadow under panels and buttons, no blur */
{DEPTH} {{ box-shadow: 0 4px 0 0 rgba(40, 12, 6, 0.38); }}
"""
    return css


if __name__ == "__main__":
    pack = sys.argv[1]
    game = pack.replace("pokemon-", "").replace("-companion", "")
    p = ROOT / pack / "style.css"
    s = p.read_text()
    if "pixel layer" in s:
        sys.exit("already applied")
    p.write_text(transform(s, game))
    print(pack, "style.css rewritten")
