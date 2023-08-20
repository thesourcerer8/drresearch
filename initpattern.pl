#!/usr/bin/perl -w

if(!scalar(@ARGV))
{
  print "Usage: $0 <device>\nUsage: $0 <dumpfile> <size in MB>\n";
  exit;
}

my $mydev=($ARGV[0] || "/dev/sdx");

open OUT,">:raw",$mydev; # XXXXXXX YOU HAVE TO CHANGE THIS PARAMETER, be careful that you do use your harddisk!
open XML,">".($ARGV[1] || ":stdout");

my $border0=512*1024*2; # 512MB pattern
my $border7=1024*1024*2; # 512MB 00
my $borderf=1280*1024*2; # 256 MB 77
my $borderphi=1536*1024*2; # 256 MB FF
my $DATAsize=1024;
my $eccreal=($DATAsize/512)+1;
my $majority=5;
my $borderecc=$borderphi+$eccreal*$eccreal*$majority*$DATAsize*8; # lots of ECC

seek(OUT,0,2); 
my $size=tell(OUT);
seek(OUT,0,0);

print XML "<root>\n<device>$ARGV[0]</device>\n<pattern type='sectornumber' begin='0' end='$border0'/>\n<pattern type='XOR-00' begin='$border0' end='$border7'/>\n<pattern type='XOR-77' begin='$border7' end='$borderf'/>\n<pattern type='XOR-FF' begin='$borderf' end='$borderphi'/>\n<pattern type='ECC' begin='$borderphi' end='$borderecc'/>\n<pattern type='sectornumber' begin='$borderecc' end='".($size/512)."'/>\n</root>\n";

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
  if($block>=$borderphi && $block <$borderecc)
  {
    my $patternsize=$eccreal*$eccreal*$majority;
    my $pattern=($block-$borderphi)/$patternsize; # 0 .. DATAsize*8
    my $patternpos=($block-$borderphi) % $eccreal;
    my $bittargetsector=($pattern>>3) >>9;
    if($bittargetsector ==$patternpos)
    {
      my $bittargetbyte=($pattern>>3) & 0x1FF;
      my $bittargetbit=$pattern&7;
      substr($data,$bittargetbyte,1)=substr($data,$bittargetbyte,1)^(1<<$bittargetbit);
    }
  }

  print OUT $data;
  my $percent=int(100*$block/$nblocks);
  print STDERR "$block $percent\%\n" if(!($block %100000));
}
close OUT;
close XML;

print "Done.\n";
