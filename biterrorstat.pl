#!/usr/bin/perl -w

my $pagesize=18270;

my $fn=$ARGV[0];

open IN,"<$fn";
binmode IN;
my $sector="";
my $ende=0;
while(!$ende)
{
  my $ret=read IN,$sector,$pagesize;
  last if(!defined($ret) || !$ret);
  foreach(0 .. 1023)
  {
    $stat{substr($sector,$_,1) eq "\x77" ? 1 : 0}++;
  }
}
close IN;

print "Statistic for $fn:\nGood: $stat{1}\nBad: $stat{0}\n";
