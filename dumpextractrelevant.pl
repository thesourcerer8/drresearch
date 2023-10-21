#!/usr/bin/perl -w
use strict;
use File::Basename;
use List::MoreUtils qw(uniq);

if(scalar(@ARGV)<3)
{
  print "Usage: $0 <input.dump> <output.dump> <pattern.xml> <casefile.case>\n";
  print "This tool searches the necessary parts from a dump to extract the parameters and writes it to the output.dump\n";
  print "Afterwards you can then upload the output.dump and send it to our reconstruction service\n";
  exit;
}


my $imagefn=$ARGV[0];
my $dumpfn=$ARGV[1];
my $patternxmlfn=$ARGV[2];
my $casefn=$ARGV[3];

print "Extracting all relevant pages from a dump file \"$imagefn\" into an output dump \"$dumpfn\"\n";

my $pagesize=4000; # Bytes
my $eccstart=3145728;
my $eccend=3614367;
$pagesize=$1 if($ARGV[1]=~m/\((\d+)p\)/);
our $pagesperblock=128;
my $ecccoverage=1024;
my $blocksize=$pagesize*$pagesperblock; # !!! NEEDS TO BE ADAPTED LATER ON IN CASE THE VALUES CHANGED

my @datapos=(0,1500);
my $datasize=1024;
my @sapos=(3512);
my $sasize=8;
my @eccpos=(1024,2524);
my $eccsize=476;


if(open XML,"<$patternxmlfn")
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


if(open CASE,"<$casefn")
{
  print "Reading from $casefn\n";
  my @mydatapos=();
  my @myeccpos=();
  my @mysapos=();
  while(<CASE>)
  {
    $pagesize=$1 if(m/<Page_size>(\d+)<\/Page_size>/);
    if(m/<Actual_block_size>(\d+)<\/Actual_block_size>/) # Should we use Nominal or Actual?
    {
      $blocksize=$1;
      $pagesperblock=$blocksize/$pagesize;
    }
    if(m/<Record StructureDefinitionName="(DA|Data area)" StartAddress="(\d+)" StopAddress="(\d+)" \/>/i)
    {
      print "Adding $2 to datapos\n";
      push @mydatapos,$2;
      $datasize=$3-$2+1;
      $ecccoverage=$datasize;
    }
    if(m/<Record StructureDefinitionName="ECC" StartAddress="(\d+)" StopAddress="(\d+)" \/>/)
    {
      push @myeccpos,$1;
      $eccsize=$2-$1+1;
    }
    if(m/<Record StructureDefinitionName="SA" StartAddress="(\d+)" StopAddress="(\d+)" \/>/)
    {
      push @mysapos,$1;
      $sasize=$2-$1+1;
    }
    @datapos=uniq @mydatapos;
    @eccpos=uniq @myeccpos;
    @sapos=uniq @mysapos;
  }
  #$sectors=scalar(@datapos)*$datasize;
  close CASE;
}


our $xorkey="";
if(open XOR,"<$ARGV[0].xor")
{
  binmode XOR;
  undef $/;
  $xorkey=<XOR>;
  close XOR; 
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
  return $_[0] if(!defined($_[0]) || length($_[0])==0);
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

  if(0) #length($xorkey))
  {
    print "pagen%pagesperblock: ".($pagen % $pagesperblock)."\n";
    print "pagesperblock: $pagesperblock\n";
    print "pagesize: $pagesize\n";
    print "length xor: ".length($xorkey)."\n";
    print "start: ".($pagesize*($pagen % $pagesperblock))."\n";
    print "len part: ".length(substr($xorkey,$pagesize*($pagen % $pagesperblock),$pagesize))."\n";
  }

  $in^=substr($xorkey,$pagesize*($pagen % $pagesperblock),$pagesize) if(length($xorkey));
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

  foreach my $result (sort keys %posfound)
  {
    #print "Len: ".length($sector)." result:$result ".($result+59)."\n";
    next if(length($sector)<($result+59));
    my $lbah=substr($sector,$result+23,8);
    my $lbad=fixdecimal(substr($sector,$result+7,12));
    my $lbab=fixdecimal(substr($sector,$result+39,20));
    if(!defined($lbab))
    {
      print STDERR "WARNING: Most likely the pagesize is wrong. Please give the pagesize by naming the dump files like mydump(18324p).dmp\n";
	exit;
    }
    my $lba=undef;
    #print "Found $char at $result (fulladdress:$fulladdress xorpage:$xorpage blockpage:$blockpage)";
    my $lbaD=undef; $lbaD=int($lbad) if(defined($lbad) && $lbad=~m/^(\d+)$/);
    my $lbaH=undef; $lbaH=hex("0x".$1) if(defined($lbah) && $lbah=~m/^([0-9a-fA-F]+)$/);
    my $lbaB=undef; $lbaB=int($lbab/512) if(defined($lbab) && $lbab=~m/^(\d+)$/);
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
  $isgood=1 if(!$isgood && $in=~m/P00000/); # We want to populate the %lbafound first but still add the sector even if we dont find the phi pattern

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
if($percent<99)
{
  print "\nThis dump is incomplete or has not been properly XOR decoded yet.\n";
  print "Trying to automatically XOR decode it now:\n\n";
  my $xorsearch=__FILE__; $xorsearch=~s/\w+\.pl$/xorsearch.pl/;
  my $cmd="perl \"$xorsearch\" \"$imagefn\" \"$imagefn.xor\" \"$casefn\"";
  print "CMD: $cmd\n";
  system $cmd;
  if(-f "$imagefn.xor")
  {
    print "\nXOR key was found, now trying again.\n\n";
    my $cmd="perl \"$0\" \"".join("\" \"",@ARGV)."\" ";
    system $cmd;
  }
  else
  {
    print "\nThe XOR key could not be found automatically, please check whether the pattern has been written to the disk/card correctly, and whether the geometry of the dump is correct\n";
    print "Please check the size and make sure it has been XOR decoded properly. If that doesn't help, please provide the whole dump.\n";
  }
}

#print "Page Offsets for DATA: ".join(",",sort keys(%posfound))."\n";
print STDERR "Done.\n";
