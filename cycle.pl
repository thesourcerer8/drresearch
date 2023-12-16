#!/usr/bin/perl -w

print "This tool searches for a 4-cycle in a LDPC matrix\n";

sub popcount($)
{
  return unpack("%32b*",$_[0]);
}

# This function converts a binary string to its hex representation for debugging
sub bin2hex($)
{
  my $orig=$_[0];
  my $value="";
  return "" if(!defined($orig) || $orig eq "");
  foreach(0 .. length($orig)-1)
  {
    $value.=sprintf("%02X",unpack("C",substr($orig,$_,1)));
  }
  return $value;
}


my $n=1; $n=$1 if($ARGV[0]=~m/_n(\d+)_/);
my $k=1; $k=$1 if($ARGV[0]=~m/_k(\d+)_/);
my $m=1; $m=$1 if($ARGV[0]=~m/_m(\d+)\./);

print "n: $n k: $k m: $m\n";

our @rules=();
our @pc=();
our $totalpc=0;

open IN,"<$ARGV[0]";
binmode IN;
foreach(0 .. $m-1)
{
  my $data="";	  
  read IN,$data,$n/8;
  push @rules,$data;
  my $p=popcount($data);
  push @pc,$p;
  $totalpc+=$p;
}
close IN;

my $found=0;

  foreach my $i (0 .. $m-2)
  {
    foreach my $j ($i+1 .. $m-1)
    {
      my $new=$rules[$i] & $rules[$j];
      my $newpc=popcount($new); 
      if($newpc>1)
      {
        print "Found a 4-cycle in $ARGV[0]: rows $i,$j:\n";
	print bin2hex($rules[$i])."\n";
	print bin2hex($rules[$j])."\n";
	print bin2hex($new)."\n";
	$found++;
      }
    }
  }


print "We found $found short cycles.\n";

