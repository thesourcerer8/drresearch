#include <windows.h>
#include <stdio.h>

// Converts Gigabytes to LBA Sectors
long long idema_gb2lba(long long advertised)
{
  return((97696368) + (1953504 * (advertised - 50)));
}

char errorbuffer[2000];
const char *noerrorbuffer="No Error.";

const char *GetLastErrorAsString()
{
  DWORD errorMessageID = GetLastError();
  if(errorMessageID==0)
  {
    return noerrorbuffer;
  }
  LPSTR messageBuffer = nullptr;
  size_t size=FormatMessageA(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, NULL, errorMessageID, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), (LPSTR)&messageBuffer, 0, NULL);
  memcpy(errorbuffer,messageBuffer,size);
  errorbuffer[size]=0;
  LocalFree(messageBuffer);
  return errorbuffer;  
}

void showUsage()
{
  fprintf(stderr,"Usage: initpattern.exe \\\\.\\PhysicalDrive1 [size in MB] [data area size in Byte]\n");
  printf("Available disks:\n");
  system("wmic diskdrive list brief");
}

int main(int argc, char* argv[])
{
  DWORD Ropen;
  int wearedone=0;
  long long sector=0;
  long long targetsize=-1; // in Bytes
  BYTE pWriteBlock[4096] = { 0 };
  BYTE *pWriteSector=pWriteBlock;
  int DATAsize=8192; // in Bytes
  char xmlfn[1000]="pattern.xml";
  FILE*handle=NULL;

  if(argc<2)
  {
    showUsage();
    return -1;
  }
  if(argc>2)
  {
    if(strlen(argv[2])>2 && !strcmp(argv[2]+strlen(argv[2])-2,"GB"))
    {
      sscanf(argv[2],"%lldGB",&targetsize);
      targetsize=idema_gb2lba(targetsize)*512;
      printf("Setting the target size to %lld MB / %lld sectors / %lld GiB.\n",targetsize>>11,targetsize,targetsize>>30);
    }
    else
    {    
      targetsize=atol(argv[2])<<11;
      printf("Setting the target size to %lld MB / %lld sectors / %lld GiB.\n",targetsize>>11,targetsize,targetsize>>30);
    }
    sprintf(xmlfn,"%s.xml",argv[1]);
  }
  if(argc>3)
  {
    DATAsize=atoi(argv[3]);
    printf("Setting the DATA size to %d\n",DATAsize);
  }

  int eccreal=(DATAsize/512)+1;
  int majority=5;

  long long border0=512*1024*2; // 512MB pattern
  long long border7=1024*1024*2; // 512MB 00
  long long borderf=1280*1024*2; // 256 MB 77
  long long borderphi=1536*1024*2; // 256 MB FF
  long long borderecc=borderphi+eccreal*eccreal*majority*DATAsize*8+1; // lots of ECC (for 512B DA we dont need much, for 4KB we need 11GB, for 8GB a lot more)
	
  HANDLE hDevice = CreateFileA(argv[1], GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);

  if (hDevice == INVALID_HANDLE_VALUE)
  {
    hDevice = CreateFileA(argv[1], GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_ALWAYS, 0, NULL);
    if (hDevice == INVALID_HANDLE_VALUE)
    {
      printf("CreateFileA returned an error when trying to open the file: %ld\n", GetLastError());
      return 0;
    }
  }
  printf("Opened successfully\n");

  DeviceIoControl(hDevice, FSCTL_LOCK_VOLUME, NULL, 0, NULL, 0, &Ropen, NULL);

  DWORD lpBytesReturned=0;
  DeviceIoControl(hDevice,IOCTL_DISK_GET_LENGTH_INFO,NULL,0,pWriteBlock,sizeof(pWriteBlock),&lpBytesReturned,NULL);
  if(lpBytesReturned==8)
  {
    targetsize=*(unsigned long long *)pWriteBlock;
    printf("Device Size: %lld (%lldGB)\n",targetsize,targetsize/1000/1000/1000);
  }
  else
  {
    printf("Image Size: %lld (%lldGB)\n",targetsize,targetsize/1000/1000/1000);
  }

  if(!targetsize)
  {
    fprintf(stderr,"ERROR: The target size of the disk/card/dumpfile is null.\n");
    showUsage();
    return -2;
  }

  if(targetsize<(borderecc<<9))
  {
    printf("WARNING: The pattern required for a data size of %d is too large to fit into this device/image! Enlarge the image size to at least %lld MB or change the pattern configuration\n",DATAsize,borderecc/2/1024);
    while(targetsize<(borderecc<<9) && DATAsize>512)
    {
      DATAsize/=2;
      eccreal=(DATAsize/512)+1;
      borderecc=borderphi+eccreal*eccreal*majority*DATAsize*8+1;
      //printf("Trying Datasize:%d borderecc:%lld targetsize:%lld\n",DATAsize,(borderecc<<9)/1000/1000,targetsize/1000/1000);
    }
    printf("We have automatically adjusted the DATA size to %d to fit into the device/image.\n",DATAsize);
  }
  if((DATAsize%512)>0)
  {
    fprintf(stderr,"ERROR: The datasize is not a multiple of 512 Bytes, please check the parameters!\n");
    exit(-3);
  }

  printf("Creating old pattern for recovering the FTL\n");
  while(!wearedone)
  {
    pWriteSector=pWriteBlock+((sector&7)<<9); // We set the pointer to the current sector inside the 4096 Byte WriteBlock
    sprintf((char*)pWriteSector,"|Block#%012lld (0x%08llX) Byte: %020lld Pos: %10lld MB\n*** OVERWRITTEN",sector,sector,sector*512,sector>>11);
    memset(pWriteSector+strlen((const char*)pWriteSector),'x',510-strlen((const char*)pWriteSector));
    pWriteSector[510] = '\n';
    pWriteSector[511] = 0x00;
    if (((sector&7)==7) && !WriteFile(hDevice, pWriteBlock, 4096, &Ropen, NULL)) 
    {
      if(GetLastError()==ERROR_SECTOR_NOT_FOUND)
      {
        printf("Reached last sector.\n");
        wearedone=1;
      }
      else
      {
	DWORD errorid=GetLastError();      
        printf("Error when writing: %ld - %s", errorid,GetLastErrorAsString());  
        return 0;
      }
    }
    sector++;
    if(!(sector&0x3ffff))
    {
      printf("Status: Sector %lld (%lld GB)\n",sector,sector/2/1024/1024);
    }
    if((sector<<9)>=targetsize) wearedone=1;
  }

  SetFilePointer(hDevice,0,NULL,FILE_BEGIN);
  sector=0;
  wearedone=0;
  printf("Creating new pattern for recovering XOR and LDPC\n");
  while(!wearedone)
  { 
    pWriteSector=pWriteBlock+((sector&7)<<9); // We set the pointer to the current sector inside the 4096 Byte WriteBlock
    if(sector==border0)
    {
      memset(pWriteBlock, 0, 4096);
    }
    else if(sector==border7)
    {
      memset(pWriteSector, 0x77, 4096);
    }
    else if(sector==borderf)
    {
      memset(pWriteSector, 0xff, 4096);
    }
    else if(sector<border0 || sector >=borderphi)
    {
      sprintf((char*)pWriteSector,"|Block#%012lld (0x%08llX) Byte: %020lld Pos: %10lld MB\n***",sector,sector,sector*512,sector>>11);
      memset(pWriteSector+strlen((const char*)pWriteSector),'x',510-strlen((const char*)pWriteSector));
      pWriteSector[510] = '\n';
      pWriteSector[511] = 0x00;
      if(sector>=borderphi && sector<borderecc)
      {
        int patternsize=eccreal*eccreal*majority;
	long long offset=sector-borderphi;
	long long pattern=offset/patternsize;
	int patternpos=offset%eccreal;
	int patternmod=(offset%(eccreal*eccreal))/eccreal;
	int bittargetsector=(pattern>>3)>>9;
	//printf("\npatternsize:%d\noffset:%d\npattern:%d\npatternpos:%d\nbittargetsector:%d\n",patternsize,offset,pattern,patternpos,bittargetsector);
        if(patternpos>0)
        {
          sprintf((char*)pWriteSector,"P%011llX%04X",pattern,patternpos);
	  for(int tgt=16;tgt<512;tgt+=16)
          {
            memcpy(pWriteSector+tgt,pWriteSector,16);
	  }
          if(bittargetsector==(patternpos-1) && (patternmod&1))
          {
            int bittargetbyte=(pattern>>3) & 0x1FF;
	    int bittargetbit=pattern&7;
	    pWriteSector[bittargetbyte]^=1<<bittargetbit;
          }
        }		
      }
    }
    if (((sector&7)==7) && !WriteFile(hDevice, pWriteBlock, 4096, &Ropen, NULL)) 
    {
      if(GetLastError()==ERROR_SECTOR_NOT_FOUND)
      {
        printf("Reached last sector.\n");
        wearedone=1;
      }
      else
      {
        printf("Error when writing: %ld", GetLastError());  
        return 0;
      }
    }
    sector++;
    if(!(sector&0x3ffff))
    {
      printf("Status: Sector %lld (%lld GB)\n",sector,sector/2/1024/1024);
    }
    if((sector<<9)>=targetsize) wearedone=1;
  }

  DeviceIoControl(hDevice, FSCTL_UNLOCK_VOLUME, NULL, 0, NULL, 0, &Ropen, NULL);
  CloseHandle(hDevice);
  printf("We are done writing the pattern.\n");
  handle=fopen(xmlfn,"w");
  fprintf(handle,"<root overwritten='1'>\n<device>%s</device>\n",argv[1]);
  fprintf(handle,"<pattern type='sectornumber' begin='0' end='%lld' size='%lld'/>\n",border0-1,border0);
  fprintf(handle,"<pattern type='XOR-00' begin='%lld' end='%lld' size='%lld'/>\n",border0,border7-1,border7-border0);
  fprintf(handle,"<pattern type='XOR-77' begin='%lld' end='%lld' size='%lld'/>\n",border7,borderf-1,borderf-border7);
  fprintf(handle,"<pattern type='XOR-FF' begin='%lld' end='%lld' size='%lld'/>\n",borderf,borderphi-1,borderphi-borderf);
  fprintf(handle,"<pattern type='ECC' begin='%lld' end='%lld' size='%lld' coverage='%d' majority='%d'/>\n",borderphi,borderecc-1,borderecc-borderphi,DATAsize,majority);
  fprintf(handle,"<pattern type='sectornumber' begin='%lld' end='%lld' size='%lld'/>\n",borderecc,(targetsize/512)-1,(targetsize/512)-borderecc);
  fprintf(handle,"</root>\n");
  fclose(handle);
  printf("The configuration has been written to %s please provide this file too in the end.\n",xmlfn);
  printf("Please wait a couple of seconds to make sure everything has been written, then eject the drive properly.\nThen connect the NAND flash and dump it.\n");
  return 0;
}
