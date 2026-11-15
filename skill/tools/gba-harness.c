// gba-harness: headless mGBA for finding RAM addresses. usage: gba-harness rom   (commands on stdin)
//  load FILE.ss | keys HEX N | run N | dump FILE (IWRAM 32K + EWRAM 256K) | ss FILE | ppm FILE | rd ADDR LEN | wr ADDR VALUE WIDTH
//  io           the 0x400 bytes of display/IO registers as the bus reads them (write-only ones, like BGxHOFS, read 0)
//  ioraw ADDR LEN   the registers' real contents, scroll registers included
//  watch LO HI  count CPU stores into LO..HI by PC ("watch 0 0" stops); wdump prints the PCs and counts; swi 0|1 logs BIOS calls
//  A game.sav / rom.sav next to the ROM is loaded as the save. The harness's own "load" of a state overwrites it with the state's save: copy yours back.
#include <mgba/core/core.h>
#include <mgba/core/blip_buf.h>
#include <mgba/gba/core.h>
#include <mgba/core/serialize.h>
#include <mgba/internal/gba/gba.h>
#include <mgba-util/vfs.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <mgba/internal/arm/arm.h>
static void (*o8)(struct ARMCore*,uint32_t,int8_t,int*);static void (*o16)(struct ARMCore*,uint32_t,int16_t,int*);static void (*o32)(struct ARMCore*,uint32_t,int32_t,int*);
static uint32_t wlo=0,whi=0;static uint32_t pcs[4096];static uint32_t cnt[4096];static int npc=0;static int wactive=0;
static void note(struct ARMCore*cpu,uint32_t a){if(!wactive||a<wlo||a>=whi)return;uint32_t pc=cpu->gprs[15];for(int i=0;i<npc;i++)if(pcs[i]==pc){cnt[i]++;return;}if(npc<4096){pcs[npc]=pc;cnt[npc++]=1;}}
static void (*oswi16)(struct ARMCore*,int);static int swilog=0;
static void sw16(struct ARMCore*c,int imm){if(swilog)printf("SWI %02x r0=%08x r1=%08x r2=%08x lr=%08x\n",imm,c->gprs[0],c->gprs[1],c->gprs[2],c->gprs[14]);oswi16(c,imm);}
static void (*oswi32)(struct ARMCore*,int);
static void sw32(struct ARMCore*c,int imm){if(swilog)printf("SWI32 %02x r0=%08x r1=%08x r2=%08x lr=%08x\n",imm>>16,c->gprs[0],c->gprs[1],c->gprs[2],c->gprs[14]);oswi32(c,imm);}
static void s8(struct ARMCore*c,uint32_t a,int8_t v,int*cy){note(c,a);o8(c,a,v,cy);}
static void s16(struct ARMCore*c,uint32_t a,int16_t v,int*cy){note(c,a);o16(c,a,v,cy);}
static void s32(struct ARMCore*c,uint32_t a,int32_t v,int*cy){note(c,a);o32(c,a,v,cy);}
int main(int argc,char**argv){
  const char*rom=argv[1];
  struct mCore*c=mCoreFind(rom);c->init(c);c->setAudioBufferSize(c,1024);
  blip_set_rates(c->getAudioChannel(c,0),GBA_ARM7TDMI_FREQUENCY,44100);blip_set_rates(c->getAudioChannel(c,1),GBA_ARM7TDMI_FREQUENCY,44100);
  mCoreLoadFile(c,rom);static color_t buf[240*160*4];c->setVideoBuffer(c,buf,240);mCoreInitConfig(c,NULL);mCoreAutoloadSave(c);c->reset(c);{struct GBA*g=(struct GBA*)c->board;struct ARMCore*cpu=g->cpu;o8=cpu->memory.store8;o16=cpu->memory.store16;o32=cpu->memory.store32;oswi16=cpu->irqh.swi16;cpu->irqh.swi16=sw16;oswi32=cpu->irqh.swi32;cpu->irqh.swi32=sw32;cpu->memory.store8=s8;cpu->memory.store16=s16;cpu->memory.store32=s32;}
  int keys=0;char cmd[64],arg[512];
  while(scanf("%63s",cmd)==1){
    if(!strcmp(cmd,"load")){scanf("%511s",arg);struct VFile*vf=VFileOpen(arg,O_RDONLY);if(!vf||!mCoreLoadStateNamed(c,vf,SAVESTATE_SAVEDATA))printf("LOADFAIL\n");else vf->close(vf);}
    else if(!strcmp(cmd,"keys")){int n;scanf("%x %d",&keys,&n);for(int i=0;i<n;i++){c->setKeys(c,keys);c->runFrame(c);}}
    else if(!strcmp(cmd,"run")){int n;scanf("%d",&n);for(int i=0;i<n;i++){c->setKeys(c,keys);c->runFrame(c);}}
    else if(!strcmp(cmd,"dump")){scanf("%511s",arg);FILE*o=fopen(arg,"wb");for(uint32_t a=0x03000000;a<0x03008000;a+=4){uint32_t v=c->busRead32(c,a);fwrite(&v,4,1,o);}for(uint32_t a=0x02000000;a<0x02040000;a+=4){uint32_t v=c->busRead32(c,a);fwrite(&v,4,1,o);}fclose(o);}
    else if(!strcmp(cmd,"ss")){scanf("%511s",arg);struct VFile*vf=VFileOpen(arg,O_WRONLY|O_CREAT|O_TRUNC);mCoreSaveStateNamed(c,vf,SAVESTATE_SAVEDATA);vf->close(vf);}
    else if(!strcmp(cmd,"ppm")){scanf("%511s",arg);FILE*o=fopen(arg,"wb");fprintf(o,"P6\n240 160\n255\n");for(int i=0;i<240*160;i++){unsigned p=buf[i];fputc(p&255,o);fputc((p>>8)&255,o);fputc((p>>16)&255,o);}fclose(o);}
    else if(!strcmp(cmd,"wr")){unsigned a,v,w;scanf("%x %x %u",&a,&v,&w);if(w==1)c->busWrite8(c,a,v);else if(w==2)c->busWrite16(c,a,v);else c->busWrite32(c,a,v);}
    else if(!strcmp(cmd,"watch")){unsigned lo,hi;scanf("%x %x",&lo,&hi);wlo=lo;whi=hi;npc=0;wactive=hi!=0;}
    else if(!strcmp(cmd,"swi")){scanf("%d",&swilog);}
    else if(!strcmp(cmd,"wdump")){for(int i=0;i<npc;i++)printf("PC %08x %u\n",pcs[i],cnt[i]);}
    else if(!strcmp(cmd,"io")){for(unsigned i=0;i<0x400;i++)printf("%02x",c->busRead8(c,0x04000000+i));printf("\n");}
    else if(!strcmp(cmd,"ioraw")){unsigned a,l;scanf("%x %u",&a,&l);struct GBA*g=(struct GBA*)c->board;for(unsigned i=0;i<l;i++)printf("%02x",((uint8_t*)g->memory.io)[(a&0x3ff)+i]);printf("\n");}
    else if(!strcmp(cmd,"rd")){unsigned a,l;scanf("%x %u",&a,&l);for(unsigned i=0;i<l;i++)printf("%02x",c->busRead8(c,a+i));printf("\n");}
    fflush(stdout);
  }
  return 0;}
