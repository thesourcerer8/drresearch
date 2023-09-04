#!/usr/bin/perl -w
use strict;
use List::MoreUtils qw(uniq);

if(scalar(@ARGV)<3)
{
  print "Usage: $0 <imagefile.img> <dumpfile.dump> <.case>\n";
  print "Simulates writing an image file through a pendrive controller to a NAND flash, doing chip-off and dumping it\n";
  print "You can pass it a .case file for replicating the geometry\n";
  exit;
}

my $debug=0;
my $imagefn=$ARGV[0];
my $dumpfn=$ARGV[1];
my $casefile=$ARGV[2];


if(scalar(@ARGV)==5 && $ARGV[3] eq "-j")
{
  foreach(0 .. $ARGV[4]-1)
  {
    unlink "$_.done";
    system "perl \"$0\" \"$ARGV[0]\" \"$ARGV[1].$_\" \"$ARGV[2]\" \"$ARGV[3]\" \"$ARGV[4]\" $_ &";
   }
  my $done=0;
  while(!$done)
  {
    $done=1;
    foreach(0 .. $ARGV[4]-1)
    {
      $done=0 if(!-f "$_.done");
    }
  }
  print "All jobs are done!\n";
  my @dumps=();
  foreach(0 .. $ARGV[4]-1)
  {
    unlink "$_.done";
    push @dumps,"$dumpfn.$_";
  }
  my $cmd="cat \"".join("\" \"",@dumps)."\" >\"$dumpfn\"";
  print "$cmd\n";
  system($cmd);
  print "$dumpfn written.\n";
  exit;
}
our $totalshares=1;
our $thisshare=0;
if(scalar(@ARGV)==6 && $ARGV[3] eq "-j")
{
  $totalshares=$ARGV[4];
  $thisshare=$ARGV[5];
}



my $pagesize=4000; # Bytes
my $ecccoverage=1024; # Bytes
my @datapos=(0,1500);
my $datasize=1024;
my $sectors=scalar(@datapos)*$datasize;
my @sapos=(3512);
my $sasize=8;
my @eccpos=(1024,2524);
my $eccsize=476;
my $blocksize=$pagesize;
my $biterrors=10;
my $eccmode="LDPC";

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
  print "Reading from $casefile\n";
  my @mydatapos=();
  my @myeccpos=();
  my @mysapos=();
  while(<CASE>)
  {
    $pagesize=$1 if(m/<Page_size>(\d+)<\/Page_size>/);
    $blocksize=$1 if(m/<Nominal_block_size>(\d+)<\/Nominal_block_size>/); # Should we use Nominal or Actual?
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
  $sectors=scalar(@datapos)*$datasize;
  close CASE;
}

print "Pagesize: $pagesize\n";
print "Datapos: ".join(",",@datapos)."\n";


$biterrors=1 if($pagesize<100);


open(IN,"<:raw",$imagefn) || die "Could not open image file $imagefn for reading: $!\n";
binmode IN;
open(OUT,">:raw",$dumpfn) || die "Could not open dump file $dumpfn for writing: $!\n";
binmode OUT;

my $ende=0;
my $pagen=0;

@ldpckey=ldpcauto($ecccoverage*8,$eccsize*8);
#print "LDPCKEY: ".scalar(@ldpckey)." ".length($ldpckey[0])."\n";

while(!$ende)
{
  my $in="";
  my $read=read IN,$in,$sectors;
  last if(!defined($read) || !$read);

  if($pagen%$totalshares!=$thisshare)
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
    substr($out,$_,$datasize)=substr($in,$sectorpos,$datasize);
    $sectorpos+=$datasize;
  }
  # Fill SA blocks
  foreach(@sapos)
  {
    substr($out,$_,$sasize)=cutpad(pack("Q",$pagen),$sasize);
  }
  # Fake LDPC block
  foreach my $eccnum(0 .. $#eccpos)
  {
    my $eccpos=$eccpos[$eccnum];
    my $datapos=$datapos[$eccnum];
    if($eccmode eq "RANDOM")
    {
      foreach ($eccpos .. ($eccpos+$eccsize-1))
      {
        substr($out,$_,1)=pack("C",int(rand(256)));
      }
    }
    elsif($eccmode eq "LDPC")
    {
      substr($out,$eccpos,$eccsize)=ldpcencode(substr($out,$datapos,$ecccoverage));
      if($debug && !$pagen)
      {
        open DECT,">decoder.test";
        print DECT "u = ".numpyarr(substr($out,$datapos,$ecccoverage))."\n";
	print DECT "x = ".numpyarr(substr($out,$eccpos,$eccsize))."\n";
	close DECT;
      }
    }
    elsif($eccmode eq "BCH")
    {
      # to be implemented
    }
  }

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
  print OUT $out;

  $pagen++;
  print STDERR "$pagen\n" if(!($pagen %10000));

}
my $outsize=$pagen*$pagesize;

if(($outsize % $blocksize)>0) # Is the last block filled?
{
  my $todo=$blocksize-($outsize % $blocksize);
  print OUT ' ' x $todo; # Fill the last block
  $outsize+=$todo;
  $pagen+=$todo/$pagesize;
}

close IN;
close OUT;

my $size=$pagen*$sectors;
my $nsectors=$size/512;
print "Input Image Size: $size Bytes ".($size/1000/1000/1000)." GB $nsectors Sectors - $imagefn\n";

print "Output Dump Size: $outsize Bytes ".($outsize/1000/1000/1000)." GB $pagen Pages with pagesize $pagesize -> $dumpfn\n";

if(scalar(@ARGV)==6 && $ARGV[3] eq "-j")
{
  open OUT,">$ARGV[5].done";
  print OUT "done";
  close OUT;
}

print STDERR "Done.\n";
