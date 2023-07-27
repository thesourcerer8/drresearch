#!/usr/bin/perl -w

my $mydev=($ARGV[0] || "/dev/sdx");

open OUT,">:raw",$mydev; # XXXXXXX YOU HAVE TO CHANGE THIS PARAMETER, be careful that you do use your harddisk!

my $border0=512*1024*2; # 512MB pattern
my $border7=1024*1024*2; # 512MB 00
my $borderf=1280*1024*2; # 256 MB 77
my $borderphi=1536*1024*2; # 256 MB FF

seek(OUT,0,2); 
my $size=tell(OUT);
seek(OUT,0,0);

print "Size: $size Bytes ".($size/1000/1000/1000)." GB\n";
my $nblocks=$size/512;

foreach my $block (0 .. $size/512)
{
  my $data=sprintf("|Block#%012d (0x%08X) Byte: %020d Pos: %10d MB\n***OVERWRITTEN",$block,$block,$block*512,$block>>11);
  $data.= "x"x(510-length($data))."\n\x00";
  print OUT $data;
  my $percent=int(100*$block/$nblocks);
  print STDERR "$block $percent\%\n" if(!($block %100000));
}

seek(OUT,0,0);

foreach my $block (0 .. $size/512)
{
  my $data=sprintf("|Block#%012d (0x%08X) Byte: %020d Pos: %10d MB\n***",$block,$block,$block*512,$block>>11);
  $data.= "x"x(510-length($data))."\n\x00";
  $data="\x00" x 512 if($block>=$border0 && $block<$border7);
  $data="\x77" x 512 if($block>=$border7 && $block<$borderf);
  $data="\xFF" x 512 if($block>=$borderf && $block<$borderphi);  
  print OUT $data;
  my $percent=int(100*$block/$nblocks);
  print STDERR "$block $percent\%\n" if(!($block %100000));
}


print "Done.\n";
