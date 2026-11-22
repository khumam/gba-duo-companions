import struct,sys,subprocess
rom=open('/tmp/hm/hm.gba','rb').read()
SZ={(0,0):(8,8),(0,1):(16,16),(0,2):(32,32),(1,2):(32,16),(2,0):(8,16),(1,1):(32,8),(0,3):(64,64),(1,0):(16,8),(2,1):(8,32)}
def show(name):
    vram=open(f'/tmp/hm/run/{name}.vram','rb').read(); oam=open(f'/tmp/hm/run/{name}.oam','rb').read(); pal=open(f'/tmp/hm/run/{name}.pal','rb').read()
    for i in range(128):
        a0,a1,a2,_=struct.unpack_from('<HHHH',oam,i*8)
        if a0&0x300==0x200: continue
        sh=a0>>14; sz=a1>>14; w,h=SZ.get((sh,sz),(0,0))
        t=a2&0x3ff; n=(w//8)*(h//8); b=a2>>12
        g=rom.find(vram[0x10000+t*32:0x10000+t*32+n*32]); p=rom.find(pal[0x200+b*32:0x200+b*32+32])
        if g<0 and (w,h)==(8,8): continue
        print(name,i,'x',a1&511,'y',a0&255,f'{w}x{h}','t',t,'b',b,hex(g) if g>=0 else None,hex(p) if p>=0 else None)
if __name__=='__main__': show(sys.argv[1])
