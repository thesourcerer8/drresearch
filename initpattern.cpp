#include <windows.h>
#include <stdio.h>
//#include <iostream>
//using namespace std;


// Converts Gigabytes to LBA Sectors
long long idema_gb2lba(long long advertised)
{
  return((97696368) + (1953504 * (advertised - 50)));
}

int main(int argc, char* argv[])
{
  DWORD Ropen;
  //DWORD LOWpart=0;
  //DWORD HIGHpart=0;
  int wearedone=0;
  long long sector=0;
  long long targetsize=-1;
  BYTE pWriteBlock[4096] = { 0 };
  BYTE *pWriteSector=pWriteBlock;
  int DATAsize=8192;

  if(argc<2)
  {
    fprintf(stderr,"Usage: initpattern.exe \\\\.\\PhysicalDrive1 [size in MB] [data area size in Byte]\n");
    system("wmic diskdrive list brief");
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
  }
  if(argc>3)
  {
    DATAsize=atoi(argv[3]);
    printf("Setting the DATA size to %d\n",DATAsize);
  }

  int eccreal=(DATAsize/512)+1;
  int majority=7;

  long long border0=512*1024*2; // 512MB pattern
  long long border7=1024*1024*2; // 512MB 00
  long long borderf=1280*1024*2; // 256 MB 77
  long long borderphi=1536*1024*2; // 256 MB FF
  long long borderecc=borderphi+eccreal*eccreal*majority*DATAsize*8+1; // lots of ECC (for 512B DA we dont need much, for 4KB we need 11GB, for 8GB a lot more)

  if(targetsize<borderecc*512)
  {
    printf("WARNING: Not all of the pattern will be in the dump! Enlarge the dump size to at least %lld MB or change the dump configuration\n",borderecc/2/1024);
    while(targetsize<borderecc*512)
    {
      DATAsize>>=1;
      borderecc=borderphi+eccreal*eccreal*majority*DATAsize*8+1;
    }
    printf("We have automatically adjusted the DATA size to %d to fit into the device/image.\n",DATAsize);
  }
  if((DATAsize%512)>0)
  {
    printf("ERROR: The datasize is not a multiple of 512 Bytes, please check the parameters!\n");
    exit(-1);
  }
	
  HANDLE hDevice = CreateFileA(argv[1], GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);

  if (hDevice == INVALID_HANDLE_VALUE)
  {
    hDevice = CreateFileA(argv[1], GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_ALWAYS, 0, NULL);
    if (hDevice == INVALID_HANDLE_VALUE)
    {
      printf("CreateFileA returned an error when trying to open the file: %ld", GetLastError());
      return 0;
    }
  }
  printf("Opened successfully\n");

  //sysopen(OUT,
  //seek(OUT,0,2); 
  //my $size=tell(OUT);
  //print "Size: $size Bytes ".($size/1000/1000/1000)." GB\n";


  DeviceIoControl(hDevice, FSCTL_LOCK_VOLUME, NULL, 0, NULL, 0, &Ropen, NULL);

  //LOWpart=GetFileSize(hDevice,&HIGHpart);
  //printf("HIGH: %ld LOW: %ld\n",HIGHpart,LOWpart); // Does not work
  
  printf("Creating old pattern\n");
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
        printf("Error when writing: %ld", GetLastError());  
        return 0;
      }
    }
    sector++;
    if(!(sector&0x1ffff))
    {
      printf("Status: Sector %lld (%lld GB)\n",sector,sector/2/1024/1024);
    }
    if(sector==targetsize) wearedone=1;
  }

  SetFilePointer(hDevice,0,NULL,FILE_BEGIN);
  sector=0;
  wearedone=0;
  printf("Creating new pattern\n");
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
          if(bittargetsector==(patternpos-1) && patternmod)
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
    if(!(sector&0x1ffff))
    {
      printf("Status: Sector %lld (%lld GB)\n",sector,sector/2/1024/1024);
    }
    if(sector==targetsize) wearedone=1;
  }

  DeviceIoControl(hDevice, FSCTL_UNLOCK_VOLUME, NULL, 0, NULL, 0, &Ropen, NULL);
  printf("We are done writing the pattern.\n");
  printf("Please wait a couple of seconds to make sure everything has been written, then eject the drive properly.\nThen connect the NAND flash and dump it.\n");
  return 0;
}


