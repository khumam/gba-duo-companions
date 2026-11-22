#!/bin/bash
# Builds the headless harness (skill/tools/gba-harness.c) against the GBA Duo app's mGBA build.
#   skill/tools/harness/build.sh [OUT]          (default OUT: ./gba-harness)
# Needs the app repo (GBADUO_APP_DIR, default ../gbaduo next to this repo) with an mGBA static library built
# (build/wide-test/mgba/libmgba.a: any CMake build of engine/mgba with -DBUILD_SHARED=OFF works).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
APP="${GBADUO_APP_DIR:-$REPO/../gbaduo}"
OUT="${1:-./gba-harness}"
LIB="$(ls "$APP"/build/*/mgba/libmgba.a 2>/dev/null | head -1 || true)"
if [ -z "$LIB" ]; then
  echo "no libmgba.a under $APP/build/*/mgba. Build mGBA first, e.g.:" >&2
  echo "  cmake -S $APP/engine/mgba -B $APP/build/harness/mgba -DBUILD_QT=OFF -DBUILD_SDL=OFF -DBUILD_SHARED=OFF -DBUILD_STATIC=ON && cmake --build $APP/build/harness/mgba" >&2
  exit 1
fi
GEN="$(dirname "$LIB")/include"
clang -O1 -I"$APP/engine/mgba/include" -I"$GEN" "$REPO/skill/tools/gba-harness.c" "$LIB" \
  -framework CoreFoundation -lz -lm -lpthread -o "$OUT"
echo "built $OUT (mGBA from $LIB)"
