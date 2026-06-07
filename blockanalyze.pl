#!/usr/bin/perl -w
use strict;
use File::Spec qw(rel2abs);

print "Analyzes all blocks for a whole dump. For each block, it AND's and OR's all pages together and writes the result into a -AND.dump and -OR.dump. When a XOR key is available it does the same XOR decoded.\n";
print "Usage:\n$! <input-filename.dump> <pagesizeInBytes> <pagesPerBlock>\n";


my $inputfile=$ARGV[0];
my $pagesize=$ARGV[1]; # Bytes
my $pagesperblock=$ARGV[2]; # 

sub popcount($)
{
  return unpack("%32b*",$_[0]);
}

sub mymin($$)
{
  return ($_[0]<$_[1])?$_[0]:$_[1];
}


open IN,"<$inputfile";
binmode IN;
my $isXor=-s "$inputfile.xor";
our @xorkey=();

my $path=$ENV{'PWD'};
print "Reading from $inputfile : http://localhost/cgi-bin/drresearch/xorviewer.pl?dump=$path/$inputfile&pagesize=$pagesize&pagesperblock=$pagesperblock&xormode=2\n";

if($isXor)
{
  open XOR,"<$inputfile.xor";
  binmode XOR;
  open ANDX,">$inputfile-X-AND.dump";
  binmode ANDX;
  
  print "Writing to $inputfile-X-AND.dump : http://localhost/cgi-bin/drresearch/xorviewer.pl?dump=$path/$inputfile-X-AND.dump&pagesize=$pagesize&pagesperblock=$pagesperblock&xormode=2\n";
  open ORX,">$inputfile-X-OR.dump";
  binmode ORX;
  print "Writing to $inputfile-X-OR.dump : http://localhost/cgi-bin/drresearch/xorviewer.pl?dump=$path/$inputfile-X-OR.dump&pagesize=$pagesize&pagesperblock=$pagesperblock&xormode=2\n";

}

my $ende=0;

my $sep="\xF0" x ($pagesize);

open OUT,">$inputfile-OUT.dump";
binmode OUT;
print "Writing to $inputfile-OUT.dump : http://localhost/cgi-bin/drresearch/xorviewer.pl?dump=$path/$inputfile-OUT.dump&pagesize=$pagesize&pagesperblock=$pagesperblock&xormode=2\n";
open AND,">$inputfile-AND.dump";
binmode AND;
print "Writing to $inputfile-AND.dump : http://localhost/cgi-bin/drresearch/xorviewer.pl?dump=$path/$inputfile-AND.dump&pagesize=$pagesize&pagesperblock=$pagesperblock&xormode=2\n";
open OR,">$inputfile-OR.dump";
binmode OR;
print "Writing to $inputfile-OR.dump : http://localhost/cgi-bin/drresearch/xorviewer.pl?dump=$path/$inputfile-OR.dump&pagesize=$pagesize&pagesperblock=$pagesperblock&xormode=2\n";

if($isXor)
{
  foreach(0 .. $pagesperblock-1)
  {
    read XOR,$xorkey[$_],$pagesize;
  }
  close XOR;
}

my %occ=();
our %stripes=();

our $counter=0;
while(!$ende)
{
  my @content=();	
  my $andp="";
  my $orp="";
  foreach(0 .. $pagesperblock-1)
  {
    my $ret=read IN,$content[$_],$pagesize;
    $ende=1 if(!defined($ret) || $ret==0);
  }
  $andp=$content[0];
  $orp=$content[0];
  foreach(1 .. $pagesperblock-1)
  {
    $andp &= $content[$_];
    $orp |= $content[$_];
  }

  my $x=$andp^$orp;

  my $pop=popcount($x);
  my $inv=$pagesize*8-$pop;
  my $s=mymin($pop,$inv);
  my $comp=$s<$pop?1:0;
  #print "$counter $s\n";
  $occ{$s}++;

  if($s>3160 && $s<3180)
  {
    print AND $sep if($counter%50==0);
    print AND $andp;
    print OR $sep if($counter%50==0);
    print OR $orp;
    print OUT $sep if($counter%50==0);
    print OUT $x;
    foreach(0 .. $pagesize*8-1)
    {
      if(vec($x,$_,1) ne $comp)
      {
        $stripes{$_}++;
      }
    }
  }

  if($isXor)
  {
    $andp=$content[0]^$xorkey[0];
    $orp=$andp;
    foreach(1 .. $pagesperblock-1)
    {
      $andp &= $content[$_]^$xorkey[$_];
      $orp |= $content[$_]^$xorkey[$_];
    }

    print ANDX $andp;
    print ORX $orp;
    print OUT $andp.$orp.($andp^$orp);

  }
  $counter++;
}

close AND;
close OR;
if($isXor)
{
  close ANDX;
  close ORX;
}

foreach(sort {$a<=>$b} keys %occ)
{
  print "$_: $occ{$_}\n" if($occ{$_}>1);
}

foreach(sort {$a<=>$b} keys %stripes)
{
  print "$_: $stripes{$_} Byte:".int($_/8)." Bit:".($_%8)."\n" if($stripes{$_}>10);
}

print "Done.\n";
