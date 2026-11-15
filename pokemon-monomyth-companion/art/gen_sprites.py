import struct,zlib,os,sys
from emu import *
import sys
FRONT=int(sys.argv[1],16) if len(sys.argv)>1 else 0x49f720; PAL=0x4880d0
OUT=sys.argv[2] if len(sys.argv)>2 else 'sprites'
def lzpal(off):
    b=rom; size=b[off+1]|(b[off+2]<<8)|(b[off+3]<<16); p=off+4; out=bytearray()
    while len(out)<size:
        f=b[p]; p+=1
        for i in range(8):
            if len(out)>=size: break
            if f&(0x80>>i):
                a=b[p]; c=b[p+1]; p+=2; n=(a>>4)+3; d=(((a&15)<<8)|c)+1
                for _ in range(n): out.append(out[-d])
            else: out.append(b[p]); p+=1
    return bytes(out)
def png(w,h,rows,pal):
    def chunk(t,d): 
        c=struct.pack('>I',len(d))+t+d; return c+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
    raw=b''.join(b'\x00'+bytes(r) for r in rows)
    plte=b''.join(bytes(c) for c in pal)
    trns=bytes([0])
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,3,0,0,0))+chunk(b'PLTE',plte)+chunk(b'tRNS',trns)+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')
def names():
    out={}
    for i in range(1,420):
        b=rom[0x4E8BBC+11*i:0x4E8BBC+11*i+11]
        if b[0]==0xFF or b[0]==0: break
        out[i]=b
    return out
os.makedirs(OUT,exist_ok=True)
mu=make(); dest=0x02030000; work=0x0201C000
ok=0; bad=[]
N=len(names())
print('species with names',N)
for s in range(1,N+1):
    p=struct.unpack('<I',rom[FRONT+8*(s-1):FRONT+8*(s-1)+4])[0]
    pp=struct.unpack('<I',rom[PAL+8*s:PAL+8*s+4])[0]
    if not (0x08000000<=p<0x0a000000 and 0x08000000<=pp<0x0a000000): bad.append((s,'ptr')); continue
    mu.mem_write(0x02000000,ew); mu.mem_write(dest,b'\x00'*0x4000)
    try: decomp(mu,p,dest,work)
    except UcError as e: bad.append((s,str(e))); continue
    d=bytes(mu.mem_read(dest,2048))
    pal=lzpal(pp-0x08000000)
    if len(pal)<32: bad.append((s,'pal%d'%len(pal),rom[pp-0x08000000:pp-0x08000000+8].hex())); pal=pal+bytes(32-len(pal))
    cols=[]
    for i in range(16):
        v=struct.unpack('<H',pal[2*i:2*i+2])[0]; cols.append(((v&31)*255//31,((v>>5)&31)*255//31,((v>>10)&31)*255//31))
    rows=[]
    for y in range(64):
        row=[]
        for x in range(64):
            t=(y//8)*8+(x//8); o=t*32+(y%8)*4+(x%8)//2
            b=d[o]; row.append((b>>4) if x&1 else (b&15))
        rows.append(row)
    open("%s/%d.png"%(OUT,s),"wb").write(png(64,64,rows,cols))
    ok+=1
print('ok',ok,'bad',bad[:10])
