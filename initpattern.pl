#!/usr/bin/perl -w

my $mydev=($ARGV[0] || "/dev/sdx");

open OUT,">:raw",$mydev; # XXXXXXX YOU HAVE TO CHANGE THIS PARAMETER, be careful that you do use your harddisk!

seek(OUT,0,2); 
my $size=tell(OUT);
seek(OUT,0,0);

print "Size: $size Bytes ".($size/1000/1000/1000)." GB\n";
my $nblocks=$size/512;

foreach my $block (0 .. $size/512)
{
  my $data=sprintf("|Block#%012d (0x%08X) Byte: %020d Pos: %10d MB\n***",$block,$block,$block*512,$block>>11);
  $data.= "x"x(510-length($data))."\n\x00";
  print OUT $data;
  my $percent=int(100*$block/$nblocks);
  print STDERR "$block $percent\%\n" if(!($block %100000));
}


print "Done.\n";
