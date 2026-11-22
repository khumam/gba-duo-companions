import struct,sys
rom=open('/tmp/hm/hm.gba','rb').read()
def icons(vp, sb=0x1e*0x800):
    v=open(vp,'rb').read()
    def ent(tx,ty): return struct.unpack_from('<H',v,sb+((ty%32)*32+(tx%32))*2)[0]
    out=[]
    for ty in range(31):
        for tx in range(31):
            a,b,c,d=ent(tx,ty),ent(tx+1,ty),ent(tx,ty+1),ent(tx+1,ty+1)
            ta,tb,tc,td=a&0x3ff,b&0x3ff,c&0x3ff,d&0x3ff
            if ta<1000 and tb==ta+1 and tc==ta+2 and td==ta+3 and ta>=40 and (a>>12)==(d>>12):
                blk=v[ta*32:ta*32+128]
                p=rom.find(blk)
                out.append((tx,ty,ta,a>>12,p))
    return out
if __name__=='__main__':
    for o in icons(sys.argv[1]): print(o[0],o[1],o[2],'pal',o[3],hex(o[4]) if o[4]>=0 else None)
