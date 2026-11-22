#!/usr/bin/env python3
"""probe.py MENUSTEPS CROP lo hi chunk val : zero/fill save-block chunks, screenshot menu, report chunks whose crop differs from baseline.
 MENUSTEPS e.g. "st w40 r w30 a w60"  CROP e.g. 0,0,720,310 (3x px)"""
import sys, subprocess, os, shutil, concurrent.futures as cf
from PIL import Image, ImageChops
steps=sys.argv[1].split(); crop=tuple(int(x) for x in sys.argv[2].split(','))
lo,hi,chunk=int(sys.argv[3],16),int(sys.argv[4],16),int(sys.argv[5],16); val=sys.argv[6] if len(sys.argv)>6 else '00'
tag=sys.argv[7] if len(sys.argv)>7 else 'p'
ROOT='/Users/khoerulumam/Documents/Project/Roomativ/gbaduo-companions'
def run(name,wr):
    d=f'/tmp/hm/pr/{tag}_{name}'; shutil.rmtree(d,ignore_errors=True); os.makedirs(d)
    sav=f'{d}/s.sav'; shutil.copy('/tmp/hm/hm.sav',sav)
    cmd=['python3','-I','skill/tools/harness/play.py','--harness','/tmp/h/gba-harness','--rom','/tmp/hm/hm.gba','--save',sav,'--out',d,'--base','harvest-moon-fomt-companion/art/base.steps','w60']+wr+steps+['shot:s']
    subprocess.run(cmd,cwd=ROOT,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=300)
    p=f'{d}/s.png'
    r=Image.open(p).convert('RGB').crop(crop) if os.path.exists(p) else None
    shutil.rmtree(d,ignore_errors=True)
    return r
base=run('base',[])
def job(a):
    wr=[f'wr:{0x02004DE0+o:08X}={val}:1' for o in range(a,min(a+chunk,hi))]
    im=run(f'{a:x}',wr)
    if im is None: return a,'NOSHOT'
    diff=ImageChops.difference(base,im).getbbox()
    return a,diff
with cf.ThreadPoolExecutor(6) as ex:
    for a,d in ex.map(job,range(lo,hi,chunk)):
        if d: print(f'{a:04x}-{a+chunk:04x}',d,flush=True)
print('done')
