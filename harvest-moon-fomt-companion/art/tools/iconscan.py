#!/usr/bin/env python3
import sys,os,shutil,subprocess,struct,json,concurrent.futures as cf
ROOT='/Users/khoerulumam/Documents/Project/Roomativ/gbaduo-companions'
rom=open('/tmp/hm/hm.gba','rb').read()
sys.path.insert(0,'/tmp/hm')
def run(tag,wr,steps):
    d=f'/tmp/hm/ic/{tag}'; shutil.rmtree(d,ignore_errors=True); os.makedirs(d)
    shutil.copy('/tmp/hm/hm.sav',d+'/s.sav')
    cmd=['python3','-I','skill/tools/harness/play.py','--harness','/tmp/h/gba-harness','--rom','/tmp/hm/hm.gba','--save',d+'/s.sav','--out',d,'--base','harvest-moon-fomt-companion/art/base.steps','w60']+wr+steps+['vram:v']
    subprocess.run(cmd,cwd=ROOT,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=300)
    return d
def W(off,val,w=1): return f'wr:{0x02004DE0+off:08X}={val:0{2*w}X}:{w}'
def u16w(off,v): return [W(off,v&255),W(off+1,v>>8)]
def palbank(pal,off):
    return pal[off:off+32]
def tools_job(ids):
    # ids: 9 tool ids: sickle slot + 8
    wr=u16w(0x1C60,ids[0])
    for i in range(8): wr+=u16w(0x1C8C+2*i,ids[1+i])
    d=run('t_%x'%ids[0]+'_%x'%ids[1],wr,['st','w40','r','w30','a','w80'])
    try:
        v=open(d+'/v.vram','rb').read(); pal=open(d+'/v.pal','rb').read()
    except Exception: return None
    sb=0x1e*0x800
    def ent(tx,ty): return struct.unpack_from('<H',v,sb+(ty*32+tx)*2)[0]
    cells=[(2,1)]+[(2+3*c,5) for c in range(4)]+[(2+3*c,9) for c in range(4)]
    out=[]
    for (tx,ty),tid in zip(cells,ids):
        a=ent(tx,ty); t=a&0x3ff; bank=a>>12
        blk=v[t*32:t*32+128]; g=rom.find(blk); p=rom.find(pal[bank*32:bank*32+32])
        out.append((tid,g,p,t))
    shutil.rmtree(d,ignore_errors=True)
    return out
def items_job(ids):
    wr=[]
    for k,i in enumerate(ids):
        o=0x1C68+4*k; wr+=[W(o,0),W(o+1,i),W(o+2,0),W(o+3,0)]
    d=run('i_%x'%ids[0],wr,['st','w40','r','w30','a','w80'])
    try:
        v=open(d+'/v.vram','rb').read(); pal=open(d+'/v.pal','rb').read(); oam=open(d+'/v.oam','rb').read()
    except Exception: return None
    sp=[]
    for s in range(128):
        a0,a1,a2,_=struct.unpack_from('<HHHH',oam,s*8)
        if a0&0x300==0x200: continue
        if (a0>>14)==0 and (a1>>14)==1 and (a1&511)>=100 and (a0&255) in range(30,110):
            sp.append((a0&255,a1&511,a2&0x3ff,a2>>12))
    sp.sort()
    out=[]
    for (y,x,t,bank),iid in zip(sp,ids):
        blk=v[0x10000+t*32:0x10000+t*32+128]; g=rom.find(blk); p=rom.find(pal[0x200+bank*32:0x200+bank*32+32])
        out.append((iid,g,p,t,x,y))
    shutil.rmtree(d,ignore_errors=True)
    return out,len(sp)
if __name__=='__main__':
    mode=sys.argv[1]
    os.makedirs('/tmp/hm/ic',exist_ok=True)
    res={}
    if mode=='tools':
        ids=list(range(0x100,0x151)); chunks=[ids[i:i+9] for i in range(0,len(ids),9)]
        for c in chunks:
            while len(c)<9: c.append(0)
        with cf.ThreadPoolExecutor(6) as ex:
            for r in ex.map(tools_job,chunks):
                if r:
                    for tid,g,p,t in r: res[tid]=(g,p)
    else:
        ids=list(range(0,171)); chunks=[ids[i:i+8] for i in range(0,len(ids),8)]
        for c in chunks:
            while len(c)<8: c.append(200)
        with cf.ThreadPoolExecutor(6) as ex:
            for r in ex.map(items_job,chunks):
                if r:
                    out,n=r
                    for iid,g,p,t,x,y in out: res[iid]=(g,p)
    json.dump({str(k):v for k,v in res.items()},open(f'/tmp/hm/ic_{mode}.json','w'))
    print(mode,len(res),sum(1 for v in res.values() if v[0]>=0 and v[1]>=0),'complete')
