#!/usr/bin/perl -w
use strict;
use List::MoreUtils qw(uniq);
use Getopt::Long;


if(scalar(@ARGV)<3)
{
  print "Usage: $0 <imagefile.img> <dumpfilewithbiterrors.dump> <dumpfilewithoutbiterrors.dump> <.case>\n";
  print "Simulates writing an image file through a pendrive controller to a NAND flash, doing chip-off and dumping it\n";
  print "You can pass it a .case file for replicating the geometry\n";
  exit;
}

my $debug=0;
my $imagefn=$ARGV[0];
my $dumpfn=$ARGV[1];
my $cleanfn=$ARGV[2];
my $casefile=$ARGV[3];
my $XORfn=undef;

my $FTL="simple";

my $biterrors=10;
my $pagesperblock=128;
my $eccmode="LDPC";
my $ECCcoversClearSA=0;
my $ECCcoversXORedSA=0;
my $ECCcoversXORedDA=0;
my $XORcoversECC=0;
my $XORcoversSA=0;
my $SAdedicatedECC=0;

our $totalshares=1;
our $thisshare=-1;

my @oldargs=@ARGV;

GetOptions ("debug=i" => \$debug,
            "j=i" => \$totalshares,
	    "n=i" => \$thisshare,
            "FTL=s"   => \$FTL,
            "biterrors=i"  => \$biterrors,
            "ECCmode=s" => \$eccmode, # RANDOM, BCH or LDPC
            "ECCcoversClearSA" => \$ECCcoversClearSA,
            "ECCcoversXORedSA" => \$ECCcoversXORedSA,
            "ECCcoversXORedDA" => \$ECCcoversXORedDA,
            "XORcoversECC" => \$XORcoversECC,
            "XORcoversSA" => \$XORcoversSA,
            "XORfile=s" =>\$XORfn,
            "SAdedicatedECC" => \$SAdedicatedECC)
or die("Error in command line arguments\n");




sub calcoffset($)
{
  if($FTL eq "greyblock")
  {
    # TODO grey code implementation
  }
  if($FTL eq "greypage")
  {
    # TODO grey code implementation
  }
  return $_[0];
}


if($totalshares>1 && $thisshare==-1)
{
  foreach(0 .. $totalshares-1)
  {
    unlink "$dumpfn.$_.done";
    my $cmd="perl \"$0\" \"".join("\" \"",@oldargs)."\" -n $_ &";
    #print "$cmd\n";
    system $cmd;
   }
  my $done=0;
  while(!$done)
  {
    $done=1;
    sleep(1);
    foreach(0 .. $totalshares-1)
    {
      $done=0 if(!-f "$dumpfn.$_.done");
      last if(!$done);
    }
  }
  print "All jobs are done!\n";
  foreach(0 .. $totalshares-1)
  {
    unlink "$dumpfn.$_.done";
  }
  print "$dumpfn (with bit errors) and $cleanfn (without bit errors) have been written. You can now try to recover them.\n";
  exit;
}

my $pagesize=4000; # Bytes
my $ecccoverage=1024; # Bytes , this only covers the DA area, not the SA area
my @datapos=(0,1500);
my $datasize=1024;
my @sapos=(3512);
my $sasize=8;
my @eccpos=(1024,2524);
my $eccsize=476;
my @saeccpos=();
my $saeccsize=0;
my $sectors=scalar(@datapos)*$datasize; # !!! NEEDS TO BE ADAPTED LATER ON IN CASE THE VALUES CHANGED
my $blocksize=$pagesize*$pagesperblock; # !!! NEEDS TO BE ADAPTED LATER ON IN CASE THE VALUES CHANGED


our @ldpckey=();
sub ldpcauto($$) # Encoder
{
  my $k=$_[0]; #1024*8; # DATA
  my $m=$_[1]; #476*8; #ECC
  my $n=$k+$m;
  my $m8=$m/8;
  my $fn="gmatrix_n$n"."_k$k"."_m$m.g";
  my @arr=();
  if(-f $fn)
  {
    open KEYIN,"<$fn";
    foreach(0 .. $k-1)
    {
      my $content="";
      read KEYIN,$content,$m8;
      push @arr,$content;
    }
  }
  else
  {
    open OUT,">$fn";
    binmode OUT;
    foreach (0 .. $k-1)
    {
      my $v="";
      foreach (0 .. $m8-1)
      {
	$v.=pack("C",1 << int(rand(8)));
      }
      push @arr,$v;
      print OUT $v;
    }
    close OUT;
  }
  return(@arr);
}

sub ldpcencode($)
{
  my $output="\x00" x length($ldpckey[0]);
  #print "LDPC Length: ".length($ldpckey[0])." ".scalar(@ldpckey)." ".length($output)."\n";
  foreach my $byte(0 .. length($_[0])-1)
  {
    my $bytev=unpack("C",substr($_[0],$byte,1));
    foreach my $bit(0 .. 7)
    {
      $output^=$ldpckey[($byte<<3)+$bit] if($bytev & (1<<$bit));
    }
  }
  return $output;
}

sub cutpad($$)
{
  my $d=substr($_[0],0,length($_[0])>$_[1]?$_[1]:length($_[0]));
  $d.= "\x00" x ($_[1]-length($d));
  return $d;
}

sub numpyarr($)
{
  my $d="[";
  foreach(my $i=0;$i<length($_[0]);$i++)
  {
    my $v=unpack("C",substr($_[0],$i,1));
    foreach(0 .. 7)
    {
      $d.=(($v>>$_)&1).",";
    }
  }
  chomp $d;
  $d.="]";
  return $d;
}


if(open CASE,"<$casefile")
{
  print "Reading from $casefile\n" if($thisshare<1);
  my @mydatapos=();
  my @myeccpos=();
  my @mysapos=();
  my @mysaeccpos=();
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
      print "Adding $2 to datapos\n" if($thisshare<1);
      push @mydatapos,$2;
      $datasize=$3-$2+1;
      $ecccoverage=$datasize;
    }
    if(m/<Record StructureDefinitionName="ECC" StartAddress="(\d+)" StopAddress="(\d+)" \/>/i)
    {
      push @myeccpos,$1;
      $eccsize=$2-$1+1;
    }
    if(m/<Record StructureDefinitionName="SA" StartAddress="(\d+)" StopAddress="(\d+)" \/>/i)
    {
      push @mysapos,$1;
      $sasize=$2-$1+1;
    }
    if(m/<Record StructureDefinitionName="SA[\-_]ECC" StartAddress="(\d+)" StopAddress="(\d+)" \/>/i)
    {
      push @mysaeccpos,$1;
      $saeccsize=$2-$1+1;
    }
    @datapos=uniq @mydatapos;
    @eccpos=uniq @myeccpos;
    @sapos=uniq @mysapos;
    @saeccpos=uniq @mysaeccpos;
  }
  $sectors=scalar(@datapos)*$datasize;
  close CASE;
}


$biterrors=1 if($pagesize<100);

our @xorpattern=();

if(defined($XORfn))
{
  if(open(XOR,"<$XORfn"))
  {
    print "Loading XOR key from $XORfn\n" if($thisshare<1);
    binmode XOR;
    foreach(0 .. $pagesperblock-1)
    {
      my $data="";
      read XOR,$data,$pagesize;
      push @xorpattern,$data;
    }
    close XOR;
  }
  else
  {
    die "Error: Could not load XOR pattern from XOR file $XORfn : $!\n";
  }
}

open(IN,"<:raw",$imagefn) || die "Could not open image file $imagefn for reading: $!\n";
binmode IN;
open(OUT,">>:raw",$dumpfn) || die "Could not open dump file $dumpfn for writing: $!\n";
binmode OUT;
open(CLEANOUT,">>:raw",$cleanfn) || die "Could not open dump file $cleanfn for writing: $!\n";
binmode CLEANOUT;

my $ende=0;
my $pagen=0;

@ldpckey=ldpcauto($ecccoverage*8+(($ECCcoversClearSA||$ECCcoversXORedSA)?$sasize*8 : 0),$eccsize*8) if($eccmode eq "LDPC");
#print "LDPCKEY: ".scalar(@ldpckey)." ".length($ldpckey[0])."\n";

if($thisshare<1)
{
  print "Pagesize: $pagesize\n";
  print "Blocksize: $pagesperblock (=$blocksize Bytes)\n";
  print "Datapos: ".join(",",@datapos)."\n";
  print "Biterrors: $biterrors (bit errors per page)\n";
  print "Data area total size per page: $sectors\n" if($thisshare<1);
}
print "Total shares: $totalshares This share: $thisshare\n";

while(!$ende)
{
  my $in="";
  my $read=read IN,$in,$sectors;
  last if(!defined($read) || !$read);

  if($totalshares>1 && ($pagen%$totalshares)!=$thisshare)
  {
    $pagen++;
    next;
  }

  $in.="\xff" x ($sectors-$read);
  my $out="\xff" x $pagesize;

  # Fill DATA blocks
  my $sectorpos=0;
  foreach(@datapos)
  {
    my $da=substr($in,$sectorpos,$datasize);
    $da^=substr($xorpattern[$pagen % $pagesperblock],$_,$datasize) if(defined($XORfn) && $ECCcoversXORedDA); # XOR before ECC
    substr($out,$_,$datasize)=$da;
    $sectorpos+=$datasize;
  }
  # Fill SA blocks
  foreach(@sapos)
  {
    my $sa=cutpad(pack("Q",$pagen),$sasize);
    $sa^=substr($xorpattern[$pagen % $pagesperblock],$_,$sasize) if(defined($XORfn) && $ECCcoversXORedSA); # XOR before ECC
    substr($out,$_,$sasize)=$sa;
  }
  # ECC block
  foreach my $eccnum(0 .. $#eccpos)
  {
    my $eccpos=$eccpos[$eccnum];
    my $datapos=$datapos[$eccnum];
    my $sapos=$sapos[$eccnum];
    if($eccmode eq "RANDOM")
    {
      foreach ($eccpos .. ($eccpos+$eccsize-1))
      {
        substr($out,$_,1)=pack("C",int(rand(256)));
      }
    }
    elsif($eccmode eq "LDPC")
    {
      substr($out,$eccpos,$eccsize)=ldpcencode(substr($out,$datapos,$ecccoverage).(($ECCcoversClearSA||$ECCcoversXORedSA)?substr($out,$sapos,$sasize):""));
      if($debug && !$pagen)
      {
        open DECT,">decoder.test";
        print DECT "u = ".numpyarr(substr($out,$datapos,$ecccoverage).(($ECCcoversClearSA||$ECCcoversXORedSA)?substr($out,$sapos,$sasize):""))."\n";
        print DECT "x = ".numpyarr(substr($out,$eccpos,$eccsize))."\n";
        close DECT;
      }
    }
    elsif($eccmode eq "BCH")
    {
      # to be implemented
    }
  }
  if(defined($XORfn) && !$ECCcoversXORedDA) # It hasnt been XORed already, so we do it now
  {
    foreach(@datapos)
    {
      substr($out,$_,$datasize)^=substr($xorpattern[$pagen % $pagesperblock],$_,$datasize);
    }
  }
  if(defined($XORfn) && $XORcoversECC)
  {
    foreach(@eccpos)
    {
      substr($out,$_,$eccsize)^=substr($xorpattern[$pagen % $pagesperblock],$_,$eccsize);
    }
  }
  if(defined($XORfn) && $XORcoversSA && !$ECCcoversXORedSA)
  {
    foreach(@sapos)
    {
      substr($out,$_,$sasize)^=substr($xorpattern[$pagen % $pagesperblock],$_,$sasize);
    }
  }


  my $outputoffset=calcoffset($pagen)*$pagesize;

  seek(CLEANOUT,$outputoffset,0);
  print CLEANOUT $out;

  # Add noise
  foreach(0 .. $biterrors)
  {
    my $bittargetbyte=int(rand($pagesize));
    my $bittargetbit=int(rand(8));
    substr($out,$bittargetbyte,1)=substr($out,$bittargetbyte,1)^pack("C",(1<<$bittargetbit));
  }


  if(length($out)!=$pagesize)
  {
    print STDERR "WARNING: The output size has changed, it should be $pagesize but it actually is ".(length($out))."!\n";
  }
  seek(OUT,$outputoffset,0);
  print OUT $out;

  $pagen++;
  print STDERR "$pagen\n" if(!($pagen %10000));

}
my $outsize=$pagen*$pagesize;

if(($outsize % $blocksize)>0) # Is the last block filled?
{
  print "Filling last block with pages with spaces\n";
  my $todo=$blocksize-($outsize % $blocksize);
  seek(OUT,$outsize,0);
  print OUT ' ' x $todo; # Fill the last block
  seek(CLEANOUT,$outsize,0);
  print CLEANOUT ' ' x $todo; # Fill the last block
  $outsize+=$todo;
  $pagen+=$todo/$pagesize;
}

close IN;
close OUT;
close CLEANOUT;

my $size=$pagen*$sectors;
my $nsectors=$size/512;
print "Input Image Size: $size Bytes ".($size/1000/1000/1000)." GB $nsectors Sectors - $imagefn\n";

print "Output Dump Size: $outsize Bytes ".($outsize/1000/1000/1000)." GB $pagen Pages with pagesize $pagesize -> $dumpfn\n";

if($totalshares>1)
{
  open OUT,">$dumpfn.$thisshare.done";
  print OUT "done";
  close OUT;
}

print STDERR "Done.\n";
