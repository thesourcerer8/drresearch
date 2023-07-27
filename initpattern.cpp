#include <windows.h>
#include <stdio.h>
#include <iostream>
using namespace std;
unsigned char sco[512] = "                                                                                                                         "; 


int main(int argc, char* argv[])
{
  DWORD Ropen;
  int wearedone=0;
  long long block=0;
  long long targetsize=-1;
  BYTE pMBR[512] = { 0 };
  memcpy(pMBR, sco, sizeof(sco));
  if(argc<2)
  {
    fprintf(stderr,"Usage: initpattern.exe \\\\.\\PhysicalDrive1 [size in MB]\n");
    system("wmic diskdrive list brief");
    return -1;
  }
  if(argc>2)
  {
    targetsize=atoi(argv[2])<<11;
    printf("Setting the target size to %lld sectors (%lld GB).\n",targetsize,targetsize>>30);
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
  printf("Creating old pattern\n");
  while(!wearedone)
  { 
    sprintf((char*)pMBR,"|Block#%012lld (0x%08llX) Byte: %020lld Pos: %10lld MB\n*** OVERWRITTEN",block,block,block*512,block>>11);
    memset(pMBR+strlen((const char*)pMBR),'x',510-strlen((const char*)pMBR));
    pMBR[510] = '\n';
    pMBR[511] = 0x00;
    if (!WriteFile(hDevice, pMBR, 512, &Ropen, NULL)) 
    {
      printf("Error: %ld", GetLastError());
      return 0;
    }
    block++;
    if(!(block&0xffff))
    {
      printf("Status: Block %lld (%lld GB)\n",block,block/2/1000/1000);
    }
    if(block==targetsize) wearedone=1;
  }

  SetFilePointer(hDevice,0,NULL,FILE_BEGIN);
  block=0;
  printf("Creating new pattern\n");
  while(!wearedone)
  { 
    if(block>=border0 && block<border7)
    {
      memset(pMBR, 0, 512);
    }
    else if(block>=border7 && block<borderf)
    {
      memset(pMBR, 0x77, 512);
    }
    else if(block>=borderf && block<borderphi)
    {
      memset(pMBR, 0xff, 512);
    }
    else
    {
      sprintf((char*)pMBR,"|Block#%012lld (0x%08llX) Byte: %020lld Pos: %10lld MB\n***",block,block,block*512,block>>11);
      memset(pMBR+strlen((const char*)pMBR),'x',510-strlen((const char*)pMBR));
      pMBR[510] = '\n';
      pMBR[511] = 0x00;
    }
    if (!WriteFile(hDevice, pMBR, 512, &Ropen, NULL)) 
    {
      printf("Error: %ld", GetLastError());
      return 0;
    }
    block++;
    if(!(block&0xffff))
    {
      printf("Status: Block %lld (%lld GB)\n",block,block/2/1000/1000);
    }
    if(block==targetsize) wearedone=1;
  }

  DeviceIoControl(hDevice, FSCTL_UNLOCK_VOLUME, NULL, 0, NULL, 0, &Ropen, NULL);
  printf("We are done.\n");
  return 0;
}


