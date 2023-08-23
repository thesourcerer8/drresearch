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

my $pagesize=4000; # Bytes
my $eccstart=3145728;
my $eccend=3514367;
$pagesize=$1 if($ARGV[2]=~m/^(\d+)$/);

if(open XML,"<$ARGV[2]")
{
  while(<XML>)
  {
    if(m/<pattern type='ECC' begin='(\d+)' end='(\d+)' size='\d+'/)
    {
      $eccstart=$1;
      $eccend=$2;
    }
  }
  close XML;
}


open(IN,"<:raw",$imagefn) || die "Could not open dump file $imagefn for reading: $!\n";
binmode IN;
open(OUT,">:raw",$dumpfn) || die "Could not open dump file $dumpfn for writing: $!\n";
binmode OUT;

my $ende=0;
my $pagen=0;
my $outpages=0;

my $char = '|Block#';


while(!$ende)
{
  my $in="";
  my $read=read IN,$in,$pagesize;
  last if(!defined($read) || !$read);
  my $sector=$in;

    my $offset=0;
    my $isgood=0;

    my $result = index($sector, $char, $offset); # Search for the first sector inside this page

    while ($result != -1) {

      my $lbad=substr($sector,$result+7,12);
      my $lbah=substr($sector,$result+23,8);
      my $lbab=substr($sector,$result+39,20);
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
      #
      
      if(defined($lba) && $lba>=$eccstart && $lba<=$eccend)
      {
        $isgood=1;	      
      }


      $offset = $result + 1; # Where to search for the next sector inside this page?
      $result = index($sector, $char, $offset);

    }
  if($isgood)
  {
    print OUT $in;
    $outpages++;
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

print STDERR "Done.\n";
