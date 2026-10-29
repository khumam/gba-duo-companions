#!/usr/bin/env bash
# Render a companion pack with the real GBADuo engine on this Mac (no device needed).
#
#   skill/preview-pack.sh <pack-dir> [--data FILE] [--pages a,b] [--out DIR] [--app DIR] [--no-tall]
#
#   --data   sample values for update()'s return (default: <pack>/preview-data.json)
#   --pages  extra `pages` to open (e.g. battle,detail), shown with the same data
#   --out    where the PNGs go (default: <pack>/preview/)
#   --nav    class of the nav container to click through (default: biggest group of tappable buttons)
#   --app    the gbaduo app repo (default: ../gbaduo next to this repo, or $GBADUO_APP_DIR)
#
# Needs JDK 17 and the Android SDK (the app repo's local.properties). First run is slow
# (Gradle + Robolectric download); later runs take under a minute. Output:
#   screen-<n>.png / screen-<page>.png (1240x1080, the Thor's size), tall-*.png, report.txt
# Copies PreviewRender.kt into the app's tests for the run and always deletes it again.
# Images from gfx.* (ROM-drawn) don't render here: have preview-data.json return
# `asset:` fallbacks for them.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
pack="" data="preview-data.json" pages="" nav="" out="" app="${GBADUO_APP_DIR:-$here/../../gbaduo}" tall=1
while [ $# -gt 0 ]; do
  case "$1" in
    --data) data="$2"; shift 2 ;;
    --pages) pages="$2"; shift 2 ;;
    --out) out="$2"; shift 2 ;;
    --nav) nav="$2"; shift 2 ;;
    --app) app="$2"; shift 2 ;;
    --no-tall) tall=0; shift ;;
    -h|--help) sed -n 2,17p "$0"; exit 0 ;;
    *) pack="$1"; shift ;;
  esac
done
[ -n "$pack" ] || { echo "usage: preview-pack.sh <pack-dir> [options]" >&2; exit 2; }
pack="$(cd "$pack" && pwd)"
app="$(cd "$app" && pwd)"
out="${out:-$pack/preview}"
mkdir -p "$out"; out="$(cd "$out" && pwd)"
[ -f "$pack/manifest.json" ] || { echo "no manifest.json in $pack" >&2; exit 2; }

if [ -z "${JAVA_HOME:-}" ] || ! "$JAVA_HOME/bin/java" -version 2>&1 | grep -q '"17\|"21'; then
  JAVA_HOME="$(/usr/libexec/java_home -v 17)"; export JAVA_HOME
fi

test_dir="$app/app/src/test/java/com/khumam/gbaduo/companion"
test_file="$test_dir/PreviewRender.kt"
cfg_dir="$app/app/build/preview-in"
cleanup() { rm -f "$test_file"; }
trap cleanup EXIT

mkdir -p "$cfg_dir"
printf 'pack=%s\ndata=%s\nout=%s\npages=%s\nnav=%s\n' "$pack" "$data" "$out" "$pages" "$nav" > "$cfg_dir/config.properties"
cp "$here/PreviewRender.kt" "$test_file"
rm -f "$out"/screen-*.png "$out"/tall-*.png "$out/report.txt"

filter="*PreviewRender"
[ "$tall" = 1 ] || filter="*PreviewRender.screen"
(cd "$app" && ./gradlew :app:testDebugUnitTest --tests "$filter" --rerun -q)

echo "--- $out"; ls "$out"
[ -f "$out/report.txt" ] && grep -E 'WARN' "$out/report.txt" || echo "no warnings"
