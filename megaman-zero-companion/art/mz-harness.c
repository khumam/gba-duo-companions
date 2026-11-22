// mz: headless mGBA. usage: mz rom   (commands on stdin)
//  load FILE.ss | boot | keys HEX N | run N | dump FILE (IWRAM 32K + EWRAM 256K) | ss FILE | ppm FILE | rd ADDR LEN
#include <mgba/core/core.h>
#include <mgba/core/blip_buf.h>
#include <mgba/gba/core.h>
#include <mgba/core/serialize.h>
#include <mgba/internal/gba/gba.h>
#include <mgba-util/vfs.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc,char**argv){
  const char*rom=argv[1];
  struct mCore*c=mCoreFind(rom);c->init(c);c->setAudioBufferSize(c,1024);
  blip_set_rates(c->getAudioChannel(c,0),GBA_ARM7TDMI_FREQUENCY,44100);blip_set_rates(c->getAudioChannel(c,1),GBA_ARM7TDMI_FREQUENCY,44100);
  mCoreLoadFile(c,rom);static color_t buf[240*160*4];c->setVideoBuffer(c,buf,240);mCoreInitConfig(c,NULL);c->reset(c);
  int keys=0;char cmd[64],arg[512];
  while(scanf("%63s",cmd)==1){
    if(!strcmp(cmd,"load")){scanf("%511s",arg);struct VFile*vf=VFileOpen(arg,O_RDONLY);if(!vf||!mCoreLoadStateNamed(c,vf,SAVESTATE_SAVEDATA))printf("LOADFAIL\n");else vf->close(vf);}
    else if(!strcmp(cmd,"keys")){int n;scanf("%x %d",&keys,&n);for(int i=0;i<n;i++){c->setKeys(c,keys);c->runFrame(c);}}
    else if(!strcmp(cmd,"run")){int n;scanf("%d",&n);for(int i=0;i<n;i++){c->setKeys(c,keys);c->runFrame(c);}}
    else if(!strcmp(cmd,"dump")){scanf("%511s",arg);FILE*o=fopen(arg,"wb");for(uint32_t a=0x03000000;a<0x03008000;a+=4){uint32_t v=c->busRead32(c,a);fwrite(&v,4,1,o);}for(uint32_t a=0x02000000;a<0x02040000;a+=4){uint32_t v=c->busRead32(c,a);fwrite(&v,4,1,o);}fclose(o);}
    else if(!strcmp(cmd,"ss")){scanf("%511s",arg);struct VFile*vf=VFileOpen(arg,O_WRONLY|O_CREAT|O_TRUNC);mCoreSaveStateNamed(c,vf,SAVESTATE_SAVEDATA);vf->close(vf);}
    else if(!strcmp(cmd,"ppm")){scanf("%511s",arg);FILE*o=fopen(arg,"wb");fprintf(o,"P6\n240 160\n255\n");for(int i=0;i<240*160;i++){unsigned p=buf[i];fputc(p&255,o);fputc((p>>8)&255,o);fputc((p>>16)&255,o);}fclose(o);}
    else if(!strcmp(cmd,"wr")){unsigned a,v,w;scanf("%x %x %u",&a,&v,&w);if(w==1)c->busWrite8(c,a,v);else if(w==2)c->busWrite16(c,a,v);else c->busWrite32(c,a,v);}
    else if(!strcmp(cmd,"rd")){unsigned a,l;scanf("%x %u",&a,&l);for(unsigned i=0;i<l;i++)printf("%02x",c->busRead8(c,a+i));printf("\n");}
    fflush(stdout);
  }
  return 0;}
