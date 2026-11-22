import sys,os,shutil,subprocess,struct,json,concurrent.futures as cf
ROOT='/Users/khoerulumam/Documents/Project/Roomativ/gbaduo-companions'
rom=open('/tmp/hm/hm.gba','rb').read()
def job(i):
    d=f'/tmp/hm/ic/s{i}'; shutil.rmtree(d,ignore_errors=True); os.makedirs(d); shutil.copy('/tmp/hm/hm.sav',d+'/s.sav')
    wr=[]
    for k in range(103):
        o=0x02004DE0+0x84+4*k
        v=0x80000000 if k==i else 0
        wr+= [f'wr:{o+b:08X}={(v>>(8*b))&255:02X}:1' for b in range(4)]
    cmd=['python3','-I','skill/tools/harness/play.py','--harness','/tmp/h/gba-harness','--rom','/tmp/hm/hm.gba','--save',d+'/s.sav','--out',d,'--base','harvest-moon-fomt-companion/art/base.steps','w60']+wr+['st','w40','r','r','r','r','r','w30','a','w60','vram:v']
    subprocess.run(cmd,cwd=ROOT,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=300)
    try:
        v=open(d+'/v.vram','rb').read(); oam=open(d+'/v.oam','rb').read(); pal=open(d+'/v.pal','rb').read()
    except Exception: return i,None
    res=None
    for s in range(128):
        a0,a1,a2,_=struct.unpack_from('<HHHH',oam,s*8)
        if a0&0x300==0x200: continue
        if (a0>>14)==0 and (a1>>14)==1 and (a1&511)==8 and (a0&255)>=24 and (a0&255)<=44:
            t=a2&0x3ff; b=a2>>12
            g=rom.find(v[0x10000+t*32:0x10000+t*32+128]); p=rom.find(pal[0x200+b*32:0x200+b*32+32]); res=(g,p); break
    shutil.rmtree(d,ignore_errors=True)
    return i,res
os.makedirs('/tmp/hm/ic',exist_ok=True)
out={}
with cf.ThreadPoolExecutor(6) as ex:
    for i,r in ex.map(job,range(103)):
        out[i]=r
json.dump(out,open('/tmp/hm/ic_ship.json','w'))
print(sum(1 for r in out.values() if r and r[0]>=0 and r[1]>=0),'of 103')
