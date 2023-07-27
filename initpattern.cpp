#include <windows.h>
#include <stdio.h>
#include <iostream>
using namespace std;

int main(int argc, char* argv[])
{
  DWORD Ropen;
  DWORD LOWpart=0;
  DWORD HIGHpart=0;
  int wearedone=0;
  long long sector=0;
  long long targetsize=-1;
  BYTE pWriteBlock[4096] = { 0 };
  BYTE *pWriteSector=pWriteBlock;
 
  if(argc<2)
  {
    fprintf(stderr,"Usage: initpattern.exe \\\\.\\PhysicalDrive1 [size in MB]\n");
    system("wmic diskdrive list brief");
    return -1;
  }
  if(argc>2)
  {
    targetsize=atol(argv[2])<<11;
    printf("Setting the target size to %lld MB / %lld sectors / %lld GB.\n",targetsize>>11,targetsize,targetsize>>30);
  }

  long long border0=512*1024*2; // 512MB pattern
  long long border7=1024*1024*2; // 512MB 00
  long long borderf=1280*1024*2; // 256 MB 77
  long long borderphi=1536*1024*2; // 256 MB FF


  HANDLE hDevice = CreateFileA(argv[1], GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);

  if (hDevice == INVALID_HANDLE_VALUE)
  {
    printf("CreateFileA returned an error when trying to open the file: %ld", GetLastError());
    return 0;
  }
  printf("Opened successfully\n");

  //sysopen(OUT,
  //seek(OUT,0,2); 
  //my $size=tell(OUT);
  //print "Size: $size Bytes ".($size/1000/1000/1000)." GB\n";


  DeviceIoControl(hDevice, FSCTL_LOCK_VOLUME, NULL, 0, NULL, 0, &Ropen, NULL);

  LOWpart=GetFileSize(hDevice,&HIGHpart);
  printf("HIGH: %ld LOW: %ld\n",HIGHpart,LOWpart);
  
  printf("Creating old pattern\n");
  while(!wearedone)
  {
    pWriteSector=pWriteBlock+(sector&7)<<9; // We set the pointer to the current sector inside the 4096 Byte WriteBlock
    sprintf((char*)pWriteSector,"|Block#%012lld (0x%08llX) Byte: %020lld Pos: %10lld MB\n*** OVERWRITTEN",sector,sector,sector*512,sectr>>11);
    memset(pWriteSector+strlen((const char*)pWriteSector),'x',510-strlen((const char*)pWriteSector));
    pWriteSector[510] = '\n';
    pWriteSector[511] = 0x00;
    if (((sector&7)==7) && !WriteFile(hDevice, pWriteBlock, 4096, &Ropen, NULL)) 
    {
      printf("Error when writing: %ld", GetLastError());
      return 0;
    }
    sector++;
    if(!(sector&0xffff))
    {
      printf("Status: Sector %lld (%lld GB)\n",sector,sector/2/1024/1024);
    }
    if(sector==targetsize) wearedone=1;
  }

  SetFilePointer(hDevice,0,NULL,FILE_BEGIN);
  sector=0;
  printf("Creating new pattern\n");
  while(!wearedone)
  { 
    pWriteSector=pWriteBlock+(sector&7)<<9; // We set the pointer to the current sector inside the 4096 Byte WriteBlock
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
      sprintf((char*)pWriteSector,"|Block#%012lld (0x%08llX) Byte: %020lld Pos: %10lld MB\n***",sector,sectr,sector*512,sector>>11);
      memset(pWriteSector+strlen((const char*)pWriteSector),'x',510-strlen((const char*)pWriteSector));
      pWriteSector[510] = '\n';
      pWriteSector[511] = 0x00;
    }
    if (((sector&7)==7) && !WriteFile(hDevice, pWriteBlock, 4096, &Ropen, NULL)) 
    {
      printf("Error when writing: %ld", GetLastError());
      return 0;
    }
    sector++;
    if(!(sector&0xffff))
    {
      printf("Status: Sector %lld (%lld GB)\n",sector,sector/2/1024/1024);
    }
    if(sector==targetsize) wearedone=1;
  }

  DeviceIoControl(hDevice, FSCTL_UNLOCK_VOLUME, NULL, 0, NULL, 0, &Ropen, NULL);
  printf("We are done.\n");
  return 0;
}


