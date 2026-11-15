#!/usr/bin/env bash
# Downloads front sprites for national dex 387-905 (Unbound has Gen 4-8 Pokemon) from the PokeAPI sprites repo
# into assets/pokemon/<dex>.png. 387-649 are the Black/White sprites, 650-905 the default ones (both 96x96).
# The graphics belong to Nintendo / Game Freak / Creatures.
#
#   bash art/fetch-unbound-sprites.sh
set -euo pipefail
cd "$(dirname "$0")/../assets/pokemon"
RAW=https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon
fetch() {
  n=$1
  [ -s "$n.png" ] && return 0
  if [ "$n" -le 649 ]; then url="$RAW/versions/generation-v/black-white/$n.png"; else url="$RAW/$n.png"; fi
  curl -fsS --retry 2 -o "$n.png" "$url" || { rm -f "$n.png"; echo "missing $n" >&2; }
}
export -f fetch; export RAW
seq 387 905 | xargs -P 12 -I{} bash -c 'fetch {}'
ls | wc -l
