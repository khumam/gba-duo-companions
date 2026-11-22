#!/bin/bash
cd /Users/khoerulumam/Documents/Project/Roomativ/gbaduo-companions
exec python3 -I skill/tools/harness/play.py --harness /tmp/h/gba-harness --rom /tmp/hm/hm.gba --save /tmp/hm/hm.sav --out /tmp/hm/run --base harvest-moon-fomt-companion/art/base.steps "$@"
