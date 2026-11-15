#!/usr/bin/env bash
# Downloads front sprites for the Gen 4 and 5 Pokemon Light Platinum adds (real national dex 387-649, Black/White
# sprites, 96x96) from the PokeAPI sprites repo into assets/pokemon/<dex>.png. The graphics belong to Nintendo /
# Game Freak / Creatures.
#
#   bash art/fetch-gen45-sprites.sh
set -euo pipefail
cd "$(dirname "$0")/../assets/pokemon"
RAW=https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white
fetch() { n=$1; [ -s "$n.png" ] && return 0; curl -fsS --retry 2 -o "$n.png" "$RAW/$n.png" || { rm -f "$n.png"; echo "missing $n" >&2; }; }
export -f fetch; export RAW
seq 387 649 | xargs -P 12 -I{} bash -c 'fetch {}'
ls | wc -l
