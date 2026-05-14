#!/usr/bin/perl -w
use strict;
use File::Spec qw(rel2abs);

print "Analyzes all blocks for a whole dump. For each block, it AND's and OR's all pages together and writes the result into a -AND.dump and -OR.dump. When a XOR key is available it does the same XOR decoded.\n";
print "Usage:\n$! <input-filename.dump> <pagesizeInBytes> <pagesPerBlock>\n";


my $inputfile=$ARGV[0];
my $pagesize=$ARGV[1]; # Bytes
my $pagesperblock=$ARGV[2]; # 




open IN,"<$inputfile";
binmode IN;
my $isXor=-s "$inputfile.xor";
our @xorkey=();

my $path=$ENV{'PWD'};

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

open AND,">$inputfile-AND.dump";
print "Writing to $inputfile-AND.dump : http://localhost/cgi-bin/drresearch/xorviewer.pl?dump=$path/$inputfile-AND.dump&pagesize=$pagesize&pagesperblock=$pagesperblock&xormode=2\n";
open OR,">$inputfile-OR.dump";
print "Writing to $inputfile-OR.dump : http://localhost/cgi-bin/drresearch/xorviewer.pl?dump=$path/$inputfile-X-OR.dump&pagesize=$pagesize&pagesperblock=$pagesperblock&xormode=2\n";

foreach(0 .. $pagesperblock-1)
{
  read XOR,$xorkey[$_],$pagesize;
}

close XOR;

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

  print AND $andp;
  print OR $orp;

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

  }

}

close AND;
close OR;
if($isXor)
{
  close ANDX;
  close ORX;
}

print "Done.\n";
