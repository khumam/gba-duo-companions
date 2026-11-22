import sys,struct
from PIL import Image
name=sys.argv[1]
v=open(f'/tmp/hm/run/{name}.vram','rb').read(); pal=open(f'/tmp/hm/run/{name}.pal','rb').read()
def col(i):
    c=struct.unpack_from('<H',pal,i*2)[0]
    return ((c&31)*255//31,((c>>5)&31)*255//31,((c>>10)&31)*255//31)
cnt=[int(x,16) for x in sys.argv[2:6]]
for b,c in enumerate(cnt):
    char=((c>>2)&3)*0x4000; bpp8=bool(c&0x80); sb=((c>>8)&31)*0x800; size=(c>>14)&3
    w=256 if size in(0,2) else 512; h=256 if size in(0,1) else 512
    im=Image.new('RGB',(w,h),(255,0,255))
    for ty in range(h//8):
        for tx in range(w//8):
            blk=(tx//32)+(ty//32)*(2 if w==512 else 1)
            ent=struct.unpack_from('<H',v,sb+blk*0x800+((ty%32)*32+(tx%32))*2)[0]
            t=ent&0x3ff; hf=ent>>10&1; vf=ent>>11&1; p=ent>>12
            for y in range(8):
                for x in range(8):
                    xx=7-x if hf else x; yy=7-y if vf else y
                    if bpp8:
                        o=char+t*64+yy*8+xx
                        ci=v[o] if o<len(v) else 0
                        if ci==0: continue
                        im.putpixel((tx*8+x,ty*8+y),col(ci))
                    else:
                        o=char+t*32+yy*4+xx//2
                        ci=(v[o]>>((xx&1)*4))&15 if o<len(v) else 0
                        if ci==0: continue
                        im.putpixel((tx*8+x,ty*8+y),col(p*16+ci))
    im.save(f'/tmp/hm/run/{name}_bg{b}.png'); print(b,hex(c),w,h,'8bpp' if bpp8 else '4bpp')
