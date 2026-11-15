import struct,sys
from unicorn import *
from unicorn.arm_const import *
rom=open('romx/Pokemon Monomyth.gba','rb').read()
dump=open('s6.bin','rb').read()
iw,ew=dump[:32768],dump[32768:32768+0x40000]
def make():
    mu=Uc(UC_ARCH_ARM,UC_MODE_THUMB)
    mu.mem_map(0x08000000,0x02000000); mu.mem_write(0x08000000,rom)
    mu.mem_map(0x02000000,0x40000); mu.mem_write(0x02000000,ew)
    mu.mem_map(0x03000000,0x8000); mu.mem_write(0x03000000,iw)
    mu.mem_map(0x04000000,0x1000)
    mu.mem_map(0x06000000,0x20000)
    mu.mem_map(0x00800000,0x10000)  # sentinel+stack
    return mu
def decomp(mu,src,dest,work,limit=20_000_000):
    mu.reg_write(UC_ARM_REG_R0,src); mu.reg_write(UC_ARM_REG_R1,dest); mu.reg_write(UC_ARM_REG_R2,work)
    mu.reg_write(UC_ARM_REG_SP,0x0080F000)
    mu.reg_write(UC_ARM_REG_LR,0x00800001)
    mu.emu_start(0x08252a80|1,0x00800000,count=limit)
def run(src_addr,size=2048):
    mu=make()
    dest=0x02030000; work=0x0201C000
    mu.mem_write(dest,b'\x00'*0x4000)
    decomp(mu,src_addr,dest,work)
    return bytes(mu.mem_read(dest,size))
if __name__=='__main__':
    T=0x487430
    k=int(sys.argv[1])
    p=struct.unpack('<I',rom[T+8*k:T+8*k+4])[0]
    out=run(p)
    print(len(out), out[:64].hex())
    open('out_%d.bin'%k,'wb').write(out)
