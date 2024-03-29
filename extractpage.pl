#!/usr/bin/perl -w
use strict;
use bigint;

print "$0 dump.dump 0xPosition Pagesize output.dump\n";

if(scalar(@ARGV)>=4 && -f $ARGV[0])
{
  my $pagesize=$ARGV[2];
  print "Pagesize: $pagesize\n";
  open IN,"<$ARGV[0]";
  binmode IN;
  my $tgt=(int(hex($ARGV[1])/$pagesize)*$pagesize);
  print "dd if=$ARGV[0] of=$ARGV[3] bs=1 count=$pagesize skip=$tgt\n";
  print "Orig: ".sprintf("0x%X",hex($ARGV[1]))." Target:".sprintf("0x%X",$tgt)."\n";
  seek IN,$tgt,0;
  my $data="";
  read IN,$data,$pagesize;
  close IN;
  open OUT,">$ARGV[3]";
  binmode OUT;
  print OUT $data;
  close OUT;
}


