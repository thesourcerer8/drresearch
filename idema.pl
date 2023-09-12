#!/usr/bin/perl -w

sub idema_gb2lba($) # ($GB)
{
  my $AdvertisedCapacity=$_[0];
  my $LBAcounts = (97696368) + (1953504 * ($AdvertisedCapacity - 50));
  return($LBAcounts);
}

sub idema_lba2gb($) # ($LBA)
{
  my $LBAcounts=$_[0];	
  my $AdvertisedCapacity = (($LBAcounts - 97696368)/1953504) + 50;
  return($AdvertisedCapacity);
}


foreach(0 .. 2000)
{
  print "$_ GB = ".idema_gb2lba($_)." LBA's = ".(idema_gb2lba($_)*512)." Bytes = ".(idema_gb2lba($_)/2/1024/1024)." GiB = ".(idema_gb2lba($_)*512/1000/1000/1000)." GB\n";
}
