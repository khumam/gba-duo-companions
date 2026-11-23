#!/bin/bash
# Re-renders preview-data.json from the harness dump and renders the pages with the real engine.
#   art/preview.sh DUMP.bin [OUT]
cd "$(dirname "$0")/.."
ROM=${ROM:-/tmp/mm/mmbn.gba}
echo '[{"page":"folder","slot":0}]' > /tmp/mm/states.json
lua ../skill/tools/packkit/run.lua "$ROM" "$1" --preview preview-data.json --states /tmp/mm/states.json >/dev/null 2>&1
python3 -I ../skill/tools/packkit/gfxmock.py "$ROM" preview-data.json >/dev/null
python3 -I - <<'PY'
import json
d=json.load(open('preview-data.json')); d['ui']={'set':{}}
json.dump(d,open('preview-data.json','w'),indent=1)
PY
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home
../skill/preview-pack.sh . --out "${2:-/tmp/mm/prev}" --no-tall --pages folder,library,megaman,email,items,network 2>&1 | grep -i "warn\|error"
