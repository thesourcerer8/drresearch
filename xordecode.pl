#!/usr/bin/perl -w
use strict;
use List::MoreUtils qw(uniq);
use Getopt::Long;


if(scalar(@ARGV)<3)
{
  print "Usage: $0 <dumpfile.dump> <xorpattern.xor> <decoded.dump>\n";
  print "Decodes a dump file with a given xor pattern key file\n";
  exit;
}

my $dumpsize=-s $ARGV[0];
my $xorsize=-s $ARGV[1];
my $xorkey="";

print "Loading XOR key...\n";
if(open(IN,"<$ARGV[1]"))
{
  binmode IN;
  read IN,$xorkey,$xorsize;
  close IN;
}
print "XOR key loaded with size: ".length($xorkey)."\n";

print "Warning: The dump file size ($dumpsize) is not a multiple of the XOR key size ($xorsize)!\n" if(($dumpsize % $xorsize)>0);

open IN,"<$ARGV[0]";
binmode IN;
open OUT,">$ARGV[2]";
binmode OUT;

foreach(0 .. $dumpsize/$xorsize)
{
  my $data="";
  my $read=read IN,$data,$xorsize;
  $data^=$xorkey;
  print OUT $data;
  print "$_ blocks processed. ".int($_*$xorsize/1000000000)." GB\n" if(($_ %100)==1);
}
close IN;
close OUT;

print "Warning: The dump file size ($dumpsize) is not a multiple of the XOR key size ($xorsize)!\n" if(($dumpsize % $xorsize)>0);
print STDERR "The decoded dump has been written to $ARGV[2]\n";
print STDERR "Done.\n";
