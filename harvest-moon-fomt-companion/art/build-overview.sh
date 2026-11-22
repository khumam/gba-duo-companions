#!/bin/bash
# Re-renders every page of the pack with the real engine and builds overview/<pack>-overview.png.
# needs: ROM + RAM dump with the save loaded (DUMP), JDK 17, the app repo (see skill/preview-pack.sh)
set -e
cd "$(dirname "$0")/../.."
P=harvest-moon-fomt-companion; ROM=${ROM:-/tmp/hm/hm.gba}; DUMP=${DUMP:-/tmp/hm/run/itd.bin}; S=${S:-/tmp/hm/shots}
python3 $P/art/layout.py
( cd $P && lua ../skill/tools/packkit/run.lua $ROM $DUMP --preview preview-data.json --states art/states.json >/dev/null && python3 -I ../skill/tools/packkit/gfxmock.py $ROM preview-data.json >/dev/null )
python3 - <<PY
import json
d=json.load(open('$P/preview-data.json')); d['ui']={'set':{}}; json.dump(d,open('$P/preview-data.json','w'),indent=1)
base=dict(tbChickens=False,tbCattle=False,tbSheep=False,tbSprites=False,tmShip=False,tmFish=False,tmRec=False,mpTown=False,mpFarm=False)
def var(n,ui,fl):
    e=dict(d); e.update(fl); e['ui']={'set':ui}; json.dump(e,open('/tmp/hm/pv-%s.json'%n,'w'))
var('cattle',{'barnTab':'cattle'},{**base,'tbCattle':True}); var('sheep',{'barnTab':'sheep'},{**base,'tbSheep':True}); var('sprites',{'barnTab':'sprites'},{**base,'tbSprites':True})
var('farmmap',{'mapTab':'farm'},{**base,'mpFarm':True}); var('fish',{'memoTab':'fish'},{**base,'tmFish':True}); var('rec',{'memoTab':'rec'},{**base,'tmRec':True})
var('ship',{'memoTab':'ship'},{**base,'tmShip':True})
var('tool',{'tool':'Mythic Watering Can'},{}); 
e=dict(d); e['ui']={'set':{'animal':1,'kind':'coop','note':'Healed'}}; e.update(dName='Chip',dHealth='Healthy',dHearts=4,dRow=d['chickens'][1]['heartRow']); json.dump(e,open('/tmp/hm/pv-animal.json','w'))
PY
rm -rf $S; mkdir -p $S
skill/preview-pack.sh $P --no-tall --pages farm,ruck,barn,maps,memo --out /tmp/hm/prev >/dev/null 2>&1
for p in farm ruck barn maps memo; do cp /tmp/hm/prev/screen-$p.png $S/$p.png; done
r() { skill/preview-pack.sh $P --no-tall --pages $2 --data /tmp/hm/pv-$1.json --out /tmp/hm/prev_$1 >/dev/null 2>&1; cp /tmp/hm/prev_$1/screen-$2.png $S/$2-$1.png; }
r cattle barn; r sheep barn; r sprites barn; r farmmap maps; r fish memo; r rec memo; r tool ruck; r animal barn
python3 skill/overview-sheet.py $S --order farm,ruck,ruck-tool,barn,barn-animal,barn-cattle,barn-sheep,barn-sprites,maps,maps-farmmap,memo,memo-fish,memo-rec --cols 4 --out overview/$P-overview.png
