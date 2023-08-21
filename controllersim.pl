#!/usr/bin/perl -w
use strict;

if(scalar(@ARGV)<3)
{
  print "Usage: $0 <imagefile.img> <dumpfile.dump> <.case>\n";
  print "Simulates writing an image file through a pendrive controller to a NAND flash, doing chip-off and dumping it\n";
  print "You can pass it a .case file for replicating the geometry\n";
  exit;
}

my $imagefn=$ARGV[0];
my $dumpfn=$ARGV[1];
my $casefile=$ARGV[2];

my $pagesize=4000; # Bytes
my $ecccoverage=1024; # Bytes
my @datapos=(0,512,1500,2012,3000);
my $sectors=scalar(@datapos)*512;
my @sapos=(3512);
my @eccpos=(1024,2524);
my $eccsize=476;
my $biterrors=10;

if(open CASE,"<$casefile")
{
  while(<CASE>)
  {
    $pagesize=$1 if(m/pagesize:(\d+)/);
  }
  close CASE;
}



open IN,"<:raw",$imagefn;
binmode IN;
open OUT,">:raw",$dumpfn;
binmode OUT;

my $ende=0;
my $pagen=0;

while(!$ende)
{
  my $in="";
  my $read=read IN,$in,$sectors;
  last if(!defined($read) || !$read);
  $in.="\xff" x ($sectors-$read);
  my $out="\xff" x $pagesize;

  # Fill DATA blocks
  my $sectorpos=0;
  foreach(@datapos)
  {
    substr($out,$_,512)=substr($in,$sectorpos,512);
    $sectorpos+=512;
  }
  # Fill SA blocks
  foreach(@sapos)
  {
    substr($out,$_,8)=pack("Q",$pagen);
  }
  # Fake LDPC block
  foreach my $eccpos(@eccpos)
  {
    foreach ($eccpos .. ($eccpos+$eccsize-1))
    {
      substr($out,$_,1)=pack("C",int(rand(256)));
    }
  }

  # Add noise
  foreach(0 .. $biterrors)
  {
    my $bittargetbyte=int(rand($pagesize));
    my $bittargetbit=int(rand(8));
    substr($out,$bittargetbyte,1)=substr($out,$bittargetbyte,1)^pack("C",(1<<$bittargetbit));
  }


  if(length($out)!=$pagesize)
  {
    print STDERR "WARNING: The output size has changed, it should be $pagesize but it actually is ".(length($out))."!\n";
  }
  print OUT $out;

  $pagen++;
  print STDERR "$pagen\n" if(!($pagen %100000));

}
close IN;
close OUT;

my $size=$pagen*$sectors;
my $nsectors=$size/512;
print "Input Image Size: $size Bytes ".($size/1000/1000/1000)." GB $nsectors Sectors - $imagefn\n";

my $outsize=$pagen*$pagesize;
print "Output Dump Size: $outsize Bytes ".($outsize/1000/1000/1000)." GB $pagen Pages with pagesize $pagesize -> $dumpfn\n";

print STDERR "Done.\n";
