#!/usr/bin/perl -w
use strict;

if(scalar(@ARGV)<3)
{
  print "Usage: $0 <input.dump> <output.dump> <pattern.xml>\n";
  print "Usage: $0 <input.dump> <output.dump> <pagesize>\n";
  print "This tool searches the necessary parts from a dump to extract the parameters and writes it to the output.dump\n";
  print "Afterwards you can then upload the output.dump and send it to our reconstruction service\n";
  exit;
}


my $imagefn=$ARGV[0];
my $dumpfn=$ARGV[1];
my $patternxmlfn=$ARGV[2];

print "Extracting all relevant pages from a dump file \"$imagefn\" into an output dump \"$dumpfn\"\n";

my $pagesize=4000; # Bytes
my $eccstart=3145728;
my $eccend=3614367;
$pagesize=$1 if($ARGV[2]=~m/^(\d+)$/);
my $ecccoverage=1024;

if(open XML,"<$ARGV[2]")
{
  while(<XML>)
  {
    if(m/<pattern type='ECC' begin='(\d+)' end='(\d+)' size='\d+' coverage='(\d+)'/)
    {
      print "Loading pattern configuration from $ARGV[2]\n";
      $eccstart=$1;
      $eccend=$2;
      $ecccoverage=$3;
    }
  }
  close XML;
}

print "Final configuration used:\nECC-start: Sector $eccstart\nECC-end: Sector $eccend\nECC-coverage: $ecccoverage Bytes\n";


open(IN,"<:raw",$imagefn) || die "Could not open dump file $imagefn for reading: $!\n";
binmode IN;
open(OUT,">:raw",$dumpfn) || die "Could not open dump file $dumpfn for writing: $!\n";
binmode OUT;

my $ende=0;
my $pagen=0;
my $outpages=0;

my $char1 = '|Block#';
my $char2 = "xxxxx\x0a\x00";


my %posfound=();
my %lbafound=();

sub fixdecimal($) # Fixes up to 3 bit errors
{
  my $str=$_[0];
  my $count=($str=~tr/[0-9]//);
  return $_[0] if($count==length($_[0]));
  if($count<length($_[0]) && $count>length($_[0])-3)
  {
    #print "Trying to fix $_[0]\n";
    my $d=$_[0];
    foreach(0 .. length($d)-1)
    {
      substr($d,$_,1)=pack("C",(unpack("C",substr($d,$_,1))&0xf|0x30));
    }
    return $d;
  }
  return $_[0];
}

#print fixdecimal("0123456789")."\n";
#print fixdecimal("012345v789")."\n";



while(!$ende)
{
  my $in="";
  my $read=read IN,$in,$pagesize;
  last if(!defined($read) || !$read);
  my $sector=$in;

  my $offset=0;
  my $isgood=0;

  my $result = index($sector, $char1, $offset); # Search for the first sector inside this page
  while ($result != -1)
  {
    $posfound{$result}=1;
    $offset = $result + 1; # Where to search for the next sector inside this page?
    $result = index($sector, $char1, $offset);
  }

  $offset=0;
  $result = index($sector, $char2, $offset); # Search for the first sector inside this page
  while ($result != -1)
  {
    $posfound{$result-512+7}=1;
    $offset = $result + 1; # Where to search for the next sector inside this page?
    $result = index($sector, $char2, $offset);
  }

  $isgood=1 if($in=~m/P00000/);

  foreach my $result (sort keys %posfound)
  {
    next if(length($sector)<($result+59));
    my $lbad=fixdecimal(substr($sector,$result+7,12));
    my $lbah=substr($sector,$result+23,8);
    my $lbab=fixdecimal(substr($sector,$result+39,20));
    if(!defined($lbab))
    {
      print STDERR "WARNING: Most likely the pagesize is wrong. Please give the pagesize by naming the dump files like mydump(18324p).dmp\n";
	exit;
    }
    my $lba=undef;
    #print "Found $char at $result (fulladdress:$fulladdress xorpage:$xorpage blockpage:$blockpage)";
    my $lbaD=int($lbad) if($lbad=~m/^(\d+)$/);
    my $lbaH=hex("0x".$lbah) if($lbah=~m/^([0-9a-fA-F]+)$/);
    my $lbaB=int($lbab/512) if($lbab=~m/^(\d+)$/);
    # Majority-Voting on the LBA address
    $lba=$lbaD if(defined($lbaD) && defined($lbaH) && $lbaD == $lbaH);
    $lba=$lbaD if(defined($lbaD) && defined($lbaB) && $lbaD == $lbaB);
    $lba=$lbaH if(defined($lbaH) && defined($lbaB) && $lbaH == $lbaB);

    #print " LBA:$lba" if(defined($lba));
    #print " LBAd:$lbad($lbaD) LBAh:$lbah($lbaH) LBAb:$lbab($lbaB)" if(defined($lba));
    #print "\n";

    if(defined($lbaD) && $lbaD>=$eccstart && $lbaD<=$eccend)
    {
      $isgood=1;
      $lbafound{$lbaD}++;
    }
    if(defined($lbaB) && $lbaB>=$eccstart && $lbaB<=$eccend)
    {
      $isgood=1;
      $lbafound{$lbaB}++;
    }
    if(defined($lbaH) && $lbaH>=$eccstart && $lbaH<=$eccend)
    {
      $isgood=1;
      $lbafound{$lbaH}++;
    }
    #if($in=~m/1874827776/)
    #{
    #  print "Found 1874827776 D:$lbaD H:$lbaH B:$lbaB isgood:$isgood $eccstart $eccend\n" ;
    #  open DEB,">187.dat";
    #  binmode DEB;
    #  print DEB $in;
    #  close DEB;
    #}
  }
  #print "Found 1874827776\n" if($in=~m/1874827776/);

  if($isgood)
  {
    print OUT $in;
    $outpages++;
    #print "Writing 1874827776\n" if($in=~m/1874827776/);
  }

  $pagen++;
  print STDERR "$pagen pages processed\n" if(!($pagen %100000));
}

close IN;
close OUT;

my $outsize=$outpages*$pagesize;
my $size=$pagen*$pagesize;
print "Input Image Size: $size Bytes ".($size/1000/1000/1000)." GB $pagen pages with pagesize $pagesize - $imagefn\n";
print "Output Dump Size: $outsize Bytes ".($outsize/1000/1000/1000)." GB $outpages Pages with pagesize $pagesize -> $dumpfn\n";

my $missing=0;
my $found=0;
my $inc=($ecccoverage/512)+1;
print "Inc: $inc\n";
my @missings=();
for(my $lba=$eccstart; $lba<=$eccend; $lba+=$inc)
{
  $missing++ if(!defined($lbafound{$lba}));
  $found++ if(defined($lbafound{$lba}));
  push @missings,$lba if(!defined($lbafound{$lba}));
}
my $percent=($found+$missing)?int(100*$found/($found+$missing)) : 0;
print "Found: $found Missing: $missing => $percent % found (Range searched: $eccstart..$eccend inc $inc)\n";
print "Missing: ".join(",",@missings)."\n" if($missing && $missing<20);
print "This dump is incomplete or has not been properly XOR decoded yet. Please check the size and make sure it has been XOR decoded properly. If that doesn't help, please provide the whole dump.\n" if($percent<99);
#print "Page Offsets for DATA: ".join(",",sort keys(%posfound))."\n";
print STDERR "Done.\n";
