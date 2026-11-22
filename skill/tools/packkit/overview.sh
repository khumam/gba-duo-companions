#!/bin/bash
# Renders a pack's pages with the app's real engine and tiles them into overview/<pack-id>-overview.png.
#   skill/tools/packkit/overview.sh PACK_DIR page1,page2,... [DATA.json]
# DATA defaults to PACK_DIR/preview-data.json and must be an absolute path when given (the preview kit runs from the
# app repo). Needs JDK 17 (JAVA_HOME) and the app repo (GBADUO_APP_DIR or ../gbaduo).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
PACK="$(cd "$1" && pwd)"
PAGES="$2"
DATA="${3:-$PACK/preview-data.json}"
APP="${GBADUO_APP_DIR:-$REPO/../gbaduo}"
export JAVA_HOME="${JAVA_HOME:-/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home}"
ID="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['id'])" "$PACK/manifest.json")"
TMP="$(mktemp -d)"
"$REPO/skill/preview-pack.sh" "$PACK" --app "$APP" --out "$TMP/r" --no-tall --data "$DATA" --pages "$PAGES" | grep -iE "warn|error" || true
mkdir -p "$TMP/s"
IFS=',' read -ra PS <<< "$PAGES"
for p in "${PS[@]}"; do cp "$TMP/r/screen-$p.png" "$TMP/s/$p.png"; done
python3 "$REPO/skill/overview-sheet.py" "$TMP/s" --out "$REPO/overview/$ID-overview.png" --order "$PAGES"
echo "pages kept in $TMP/s"
