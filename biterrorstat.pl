#!/usr/bin/perl -w

my $pagesize=18270;

my $fn=$ARGV[0];

open IN,"<$fn";
binmode IN;
my $sector="";
my $ende=0;
my $npage=0;
my $mode=0;
my %npatterns=();

while(!$ende)
{
  my $ret=read IN,$sector,$pagesize;
  last if(!defined($ret) || !$ret);
  if(substr($sector,0,1) eq "\x77" || substr($sector,10,1) eq "\x77")
  {
    print "77 Pattern detected!\n";
    $mode=7;
    foreach(0 .. 1023)
    {
      $stat{substr($sector,$_,1) eq "\x77" ? 1 : 0}++;
    }
    $npatterns{'77'}++;
  }
  elsif($substr($sector,0,6) eq "|Block")
  {
    $mode=1;
    $npatterns{'Phi'}++;
  }
  elsif(substr($sector,0,1) eq "\x00" || substr($sector,10,1) eq "\x00")
  {
    print "00 Pattern detected!\n";
    $mode=7;
    foreach(0 .. 1023)
    {
      $stat{substr($sector,$_,1) eq "\x77" ? 1 : 0}++;
    }
    $npatterns{'00'}++;
  }
  else
  {
    print "Unknown pattern!\n";	  
  }
  $npage++;
}
close IN;

my $quote=$stat{1}?($stat{1}+$stat{0})/$stat{1}:"perfect";
print "Statistic for $fn:\nGood: $stat{1}\nBad: $stat{0}\nResult: $quote (higher is better)\n";

foreach(sort keys %npatterns)
{
  print "Number of $_ pattern sectors: $npatterns{$_}\n";
}
