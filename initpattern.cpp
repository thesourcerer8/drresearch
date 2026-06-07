#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <winioctl.h>

#define BLOCKBYTES   (8LL * 1024 * 1024)
#define BLOCKSECTORS (BLOCKBYTES / 512)

// Converts Gigabytes to LBA Sectors
long long idema_gb2lba(long long advertised)
{
  return((97696368) + (1953504 * (advertised - 50)));
}

// Nimmt den Device-Namen (z.B. "\\.\PhysicalDrive1") und dismountet alle zugehörigen Partitionen
void DismountDependentVolumes(const char* physicalDrivePath)
{
    // 1. Physische Laufwerksnummer aus dem Pfad extrahieren (z.B. "\\.\PhysicalDrive1" -> 1)
    int targetDiskNumber = -1;
    const char* pNum = strrchr(physicalDrivePath, 'e'); // Sucht das 'e' von "Drive"
    if (pNum && *(pNum + 1) != '\0') {
        targetDiskNumber = atoi(pNum + 1);
    } else {
        // Falls ein anderer Pfadtyp übergeben wurde, Fallback oder Abbruch
        targetDiskNumber = atoi(physicalDrivePath + strlen(physicalDrivePath) - 1);
    }

    if (targetDiskNumber < 0) {
        printf("Fehler: Konnte physische Laufwerksnummer nicht aus %s extrahieren.\n", physicalDrivePath);
        return;
    }

    // 2. Alle logischen Laufwerksbuchstaben im System abfragen
    char driveStrings[256];
    DWORD len = GetLogicalDriveStringsA(sizeof(driveStrings), driveStrings);
    if (len == 0 || len > sizeof(driveStrings)) {
        printf("Fehler beim Abrufen der logischen Laufwerke.\n");
        return;
    }

    printf("Analysiere logische Volumes fuer physische Disk %d...\n", targetDiskNumber);

    // GetLogicalDriveStringsA gibt eine durch Nullbytes getrennte Liste zurück, die mit zwei Nullbytes endet
    char* currentDrive = driveStrings;
    while (*currentDrive)
    {
        // Wir brauchen nur den Buchstaben (z.B. "C:" statt "C:\")
        char driveLetter[10];
        snprintf(driveLetter, sizeof(driveLetter), "\\\\.\\%c:", currentDrive[0]);

        // Überspringe Floppy/A/B und optische Laufwerke zur Sicherheit, oder prüfe den DriveType
        UINT driveType = GetDriveTypeA(currentDrive);
        if (driveType == DRIVE_REMOVABLE || driveType == DRIVE_FIXED)
        {
            // Handle auf das logische Volume öffnen
            HANDLE hVolume = CreateFileA(driveLetter, GENERIC_READ | GENERIC_WRITE,
                                         FILE_SHARE_READ | FILE_SHARE_WRITE, NULL,
                                         OPEN_EXISTING, 0, NULL);

            if (hVolume != INVALID_HANDLE_VALUE)
            {
                VOLUME_DISK_EXTENTS extents;
                DWORD bytesReturned;

                // 3. Disk Extents abfragen (Welche physische Platte gehört zu diesem Buchstaben?)
                if (DeviceIoControl(hVolume, IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS,
                                    NULL, 0, &extents, sizeof(extents), &bytesReturned, NULL))
                {
                    // Schauen, ob das Volume auf unserer Ziel-Disk liegt
                    if (extents.NumberOfDiskExtents > 0 && extents.Extents[0].DiskNumber == (DWORD)targetDiskNumber)
                    {
                        // 4. Match gefunden! Jetzt sperren und dismounten
                        if (DeviceIoControl(hVolume, FSCTL_LOCK_VOLUME, NULL, 0, NULL, 0, &bytesReturned, NULL))
                        {
                            if (DeviceIoControl(hVolume, FSCTL_DISMOUNT_VOLUME, NULL, 0, NULL, 0, &bytesReturned, NULL))
                            {
                                printf(" -> [%c:] erfolgreich auf Disk %d gesperrt und ausgehaengt.\n", currentDrive[0], targetDiskNumber);

                                // WICHTIG: Das Handle hVolume wird hier bewusst NICHT geschlossen!
                                // Wenn du es schließt, hebt Windows das Lock sofort wieder auf.
                                // Im Labor-Einsatz reicht es oft, es offen zu lassen (OS bereinigt beim Prozess-Exit)
                                // Alternativ speichert man die Handles in einem Array und schließt sie am Ende von main().
                            }
                            else {
                                printf(" -> [%c:] Lock erfolgreich, aber Dismount fehlgeschlagen.\n", currentDrive[0]);
                                CloseHandle(hVolume);
                            }
                        }
                        else {
                            printf(" -> [%c:] Gefunden, aber Sperrung verweigert (Zugriff blockiert).\n", currentDrive[0]);
                            CloseHandle(hVolume);
                        }
                    }
                    else {
                        // Gehört zu einer anderen physischen Festplatte
                        CloseHandle(hVolume);
                    }
                }
                else {
                    // IOCTL nicht unterstützt (z.B. Netzlaufwerke)
                    CloseHandle(hVolume);
                }
            }
        }
        // Zum nächsten String in der Liste springen (+4 wegen "C:\\0")
        currentDrive += strlen(currentDrive) + 1;
    }
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
  system("powershell -Command \"Get-PhysicalDisk\"");
}

int main(int argc, char* argv[])
{
  DWORD Ropen;
  int wearedone=0;
  long long sector=0;
  long long targetsize=-1; // in Bytes
  long long bufsectors=0;  // sectors currently staged in the write buffer
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
      targetsize=idema_gb2lba(targetsize)<<9;
      printf("Setting the target size to %lld bytes / %lld sectors / %lld MiB / %lld GiB.\n",targetsize,targetsize>>9,targetsize>>20,targetsize>>30);
    }
    else
    {
      targetsize=atol(argv[2])<<20;
      printf("Setting the target size to %lld bytes / %lld sectors / %lld MiB / %lld GiB.\n",targetsize,targetsize>>9,targetsize>>20,targetsize>>30);
    }
    snprintf(xmlfn,sizeof(xmlfn),"%s.xml",argv[1]);
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
  long long borderecc=borderphi+(long long) eccreal*eccreal*majority*DATAsize*8+1; // lots of ECC (for 512B DA we dont need much, for 4KB we need 11GB, for 8GB a lot more)

  BYTE *pWriteBlock=(BYTE*)VirtualAlloc(NULL,(SIZE_T)BLOCKBYTES,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE);
  if(!pWriteBlock)
  {
    fprintf(stderr,"ERROR: could not allocate a %lld byte write buffer.\n",(long long)BLOCKBYTES);
    return -4;
  }

  DismountDependentVolumes(argv[1]);

  HANDLE hDevice = CreateFileA(argv[1], GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, FILE_FLAG_NO_BUFFERING, NULL);

  if (hDevice == INVALID_HANDLE_VALUE)
  {
    hDevice = CreateFileA(argv[1], GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_ALWAYS, FILE_FLAG_NO_BUFFERING, NULL);
    if (hDevice == INVALID_HANDLE_VALUE)
    {
      printf("CreateFileA returned an error when trying to open the file: %ld - %s", GetLastError(),GetLastErrorAsString());
      return -5;
    }
  }
  printf("Opened successfully\n");

  DeviceIoControl(hDevice, FSCTL_LOCK_VOLUME, NULL, 0, NULL, 0, &Ropen, NULL);

  DWORD lpBytesReturned=0;
  DeviceIoControl(hDevice,IOCTL_DISK_GET_LENGTH_INFO,NULL,0,pWriteBlock,8,&lpBytesReturned,NULL);
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
  bufsectors=0;
  while(!wearedone)
  {
    BYTE *pWriteSector=pWriteBlock+(bufsectors<<9); // slot for the current sector inside the large write buffer
    snprintf((char*)pWriteSector,512,"|Block#%012lld (0x%08llX) Byte: %020lld Pos: %10lld MB\n*** OVERWRITTEN",sector,sector,sector*512,sector>>11);
    memset(pWriteSector+strlen((const char*)pWriteSector),'x',510-strlen((const char*)pWriteSector));
    pWriteSector[510] = '\n';
    pWriteSector[511] = 0x00;
    bufsectors++;
    sector++;
    if((sector<<9)>=targetsize) wearedone=1;
    if(bufsectors==BLOCKSECTORS || (wearedone && bufsectors>0))
    {
      if(!WriteFile(hDevice, pWriteBlock, (DWORD)(bufsectors<<9), &Ropen, NULL))
      {
        DWORD errorid=GetLastError();
        if(errorid==ERROR_SECTOR_NOT_FOUND)
        {
          printf("Reached last sector.\n");
          wearedone=1;
        }
        else
        {
          printf("Error when writing: %ld - %s", errorid,GetLastErrorAsString());
          return -6;
        }
      }
      bufsectors=0;
    }
    if(!(sector&0x3ffff))
    {
      printf("Status: Sector %lld (%lld GB)\n",sector,sector/2/1024/1024);
    }
  }

  SetFilePointer(hDevice,0,NULL,FILE_BEGIN);
  sector=0;
  wearedone=0;
  bufsectors=0;
  printf("Creating new pattern for recovering XOR and LDPC\n");
  while(!wearedone)
  {
    BYTE *pWriteSector=pWriteBlock+(bufsectors<<9); // slot for the current sector inside the large write buffer
    if(sector>=border0 && sector<border7)
    {
      memset(pWriteSector, 0x00, 512);
    }
    else if(sector>=border7 && sector<borderf)
    {
      memset(pWriteSector, 0x77, 512);
    }
    else if(sector>=borderf && sector<borderphi)
    {
      memset(pWriteSector, 0xff, 512);
    }
    else // sector<border0 or sector>=borderphi : sector-number pattern (with optional ECC override)
    {
      snprintf((char*)pWriteSector,512,"|Block#%012lld (0x%08llX) Byte: %020lld Pos: %10lld MB\n***",sector,sector,sector*512,sector>>11);
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
    bufsectors++;
    sector++;
    if((sector<<9)>=targetsize) wearedone=1;
    if(bufsectors==BLOCKSECTORS || (wearedone && bufsectors>0))
    {
      if(!WriteFile(hDevice, pWriteBlock, (DWORD)(bufsectors<<9), &Ropen, NULL))
      {
        DWORD errorid=GetLastError();
        if(errorid==ERROR_SECTOR_NOT_FOUND)
        {
          printf("Reached last sector.\n");
          wearedone=1;
        }
        else
        {
          printf("Error when writing: %ld - %s", errorid,GetLastErrorAsString());
          return -7;
        }
      }
      bufsectors=0;
    }
    if(!(sector&0x3ffff))
    {
      printf("Status: Sector %lld (%lld GB)\n",sector,sector/2/1024/1024);
    }
  }

  FlushFileBuffers(hDevice);
  DeviceIoControl(hDevice, FSCTL_UNLOCK_VOLUME, NULL, 0, NULL, 0, &Ropen, NULL);
  CloseHandle(hDevice);
  VirtualFree(pWriteBlock,0,MEM_RELEASE);
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
