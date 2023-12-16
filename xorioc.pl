#!/usr/bin/perl -w

my $npages=30;

print "$0 analyzes a XOR pattern for duplicates\nUsage: $0 <dumpfile> <pagesize>\n";

my $pagesize=$ARGV[1];
my $totalsize=-s $ARGV[0];
open IN,"<$ARGV[0]";
binmode IN;

open OUT,">$ARGV[0].ioc";

sub popcount($)
{
  return unpack("%32b*",$_[0]);
}

my $muster="";

read IN,$muster,$pagesize*$npages;
print OUT $muster;


my $minp=undef;
my $maxp=undef;
my @ps=();
my $minpos=undef;

print "Filesize: $totalsize\n";
print "Pages: ".($totalsize/$pagesize)."\n";

foreach(1 .. $totalsize/$pagesize/2)
{
  seek IN,$_*$pagesize,0;
  read IN,$vergleich,$pagesize*$npages;
  $vergleich^=$muster;
  print OUT $vergleich; 
  my $p=popcount($vergleich);
  print "$_: $p (pos: ".sprintf("%d 0x%X",$_*$pagesize,$_*$pagesize).")\n";
  if(!defined($minp))
  {
    $minp=$p;
    $maxp=$p;
    $minpos=$p;
  }
  $minpos=$_ if($p<$minp);
  $minp=$p if($p<$minp);
  $maxp=$p if($p>$maxp);
  push @ps,$p;
}

if($maxp>2*$minp)
{
  print "the maximum $maxp is more than twice as big as the minimum $minp, therefore I think that there are duplicates\n";
  print "The position was $minpos pages, which is ".sprintf("%d Bytes 0x%X",$minpos*$pagesize,$minpos*$pagesize)."\n";
  print "Recommended way to truncate:\n";
  print "truncate -s ",sprintf("%d Bytes 0x%X",$minpos*$pagesize)."\n";
}
else
{
  print "The maximum $maxp is near the minimum $minp, therefore the XOR key seems to be properly sized\n";
}

close IN;
close OUT;
