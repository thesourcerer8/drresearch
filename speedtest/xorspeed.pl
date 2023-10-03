#!/usr/bin/perl -w

my $target="\x01" x 476;
my $xor="\x73" x 476;
foreach(1 .. 10000000)
{
  $target^=$xor;
}
print $target;
