#!/usr/bin/perl -w



my $pagesize=18270;

my $fn=$ARGV[0] || "xorkeykioxia(18270b_192p).dmp";

open IN,"<$fn";
binmode IN;
open OUT,">filledxor(18270b_192p).dmp";
my $sector="";
my $npage=0;
my $ende=0;
while(!$ende)
{
  seek IN, $npage*$pagesize,0;
  my $ret=read IN,$sector,$pagesize;
  $ende=1 if(!defined($ret) || !$ret);
  my $patch="";
  seek IN, ($npage+37)*$pagesize+1024-70,0;
  read IN,$patch,70;
  $patch="X" x 70 if(length($patch) != 70);
  #print "len: ".length($sector)."\n";
  substr($sector,1028,70)=$patch if(!$ende);
  substr($sector,1028+70,120)=substr($sector,0,120) if(!$ende);

  print OUT $sector;
  $npage++;
}
close IN;
close OUT;
