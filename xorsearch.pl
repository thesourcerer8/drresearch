#!/usr/bin/perl -w
use strict;
use List::MoreUtils qw(uniq);
use Getopt::Long;

my $maximumblocks=49;


# Some ideas for improvement:
# Adding in the 77 patterns and the FF patterns into the final calculation
# Switching to single-stepping when needed
# Doing the XOR between the 5 patterns upfront to speed up the performance


if(scalar(@ARGV)<3)
{
  print "Usage: $0 <dumpfile.dump> <xorpattern.xor> <casefile.case>\n";
  print "Searches through a dumpfile for the xorpattern, uses the geometry from the case file, writes the resulting xorpattern to the xorpattern.xor\n";
  exit;
}

if(-f $ARGV[1])
{
  print STDERR "ERROR: The XOR pattern file already exists, to avoid overwriting the wrong file we stop here. If you want to overwrite it, please delete it first.\n";
  exit;
}

my $pagesize=4000; # Bytes
my $ecccoverage=1024; # Bytes
my @datapos=(0,1500);
my $datasize=1024;
my @sapos=(3512);
my $sasize=8;
my @eccpos=(1024,2524);
my $eccsize=476;
my $pagesperblock=128;

my $sectors=scalar(@datapos)*$datasize; # !!! NEEDS TO BE ADAPTED LATER ON IN CASE THE VALUES CHANGED
my $blocksize=$pagesize*$pagesperblock; # !!! NEEDS TO BE ADAPTED LATER ON IN CASE THE VALUES CHANGED


my $debug=0;
my $dumpfn=$ARGV[0];
my $xorfn=$ARGV[1];
my $casefn=$ARGV[2];


my $ECCcoversSA=1;
my $XORcoversECC=0;
my $XORcoversSA=0;

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

sub mymin($$)
{
  return $_[1] if(!defined($_[0]));
  return $_[0] if(!defined($_[1]));
  return $_[0]<$_[1]?$_[0]:$_[1];
}

our $errors=0;
our $warnings=0;

sub maj(@)
{
  my $v=scalar(@_);
  my $taken=$v&1?$v:$v-1;
  my $th=($taken+1)>>1;

  return $_[0] if($v<3);

  my $localwarnings=0;
  my $localerrors=0;
  my $final="";
  foreach my $byte (0 .. length($_[0])-1)
  {
    my $byteval=0;
    foreach my $bit(0 .. 7)
    {
      my $v=0;
      my $bitv=1<<$bit;
      #foreach my $variant(-3 .. -1) #
      foreach my $variant(0 .. $taken-1)
      {
        #print "sol$sol variant:$variant byte:$byte Byte read: ".unpack("C",substr($solutions{$sol}[$variant],$byte,1))."\n";
        $v++ if(unpack("C",substr($_[$variant],$byte,1)) & $bitv);
	#print "bit: $bit $bitv v: $v taken:$taken th:$th\n";
      }
      $byteval|=$bitv if($v>=$th);
      #print "Byteval: $byteval\n";
      $errors++ if($v>1 && $v<($taken-1));
      $localerrors++ if($v>1 && $v<($taken-1));
      $warnings++ if($v>0 && $v<$taken);
      $localwarnings++ if($v>0 && $v<$taken);
    }
    $final.=pack("C",$byteval);
  }
  return $final;
}



GetOptions ("debug=i" => \$debug,
            "XORcoversECC" => \$XORcoversECC,
            "XORcoversSA" => \$XORcoversSA)
or die("Error in command line arguments\n");

if(open CASE,"<$casefn")
{
  print "Reading from $casefn\n";
  my @mydatapos=();
  my @myeccpos=();
  my @mysapos=();
  while(<CASE>)
  {
    s/\x00//g; # FE is UTF-16
    $pagesize=$1 if(m/<Page_size>(\d+)<\/Page_size>/);
    $pagesize=$1 if(m/^Page +(\d+)\s*$/); # FE support
    if(m/^Block +0x([0-9a-fA-F]+)\s*$/) # FE support
    {
      print "FE Chip.txt format detected\n";	    
      $blocksize=hex($1);
      $pagesperblock=$blocksize/$pagesize;
    }
    if(m/<Actual_block_size>(\d+)<\/Actual_block_size>/)
    {
      $blocksize=$1;
      $pagesperblock=$blocksize/$pagesize;
    }
    if(m/<Record StructureDefinitionName="(DA|Data area|DATA)" StartAddress="(\d+)" StopAddress="(\d+)" \/>/i)
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

my $dumpsize=-s $dumpfn;
print "Dump size: $dumpsize\n";
print "Pagesize: $pagesize\n";
print "Pages per Block: $pagesperblock\n";
print "Blocks per Dump: ".int($dumpsize/$pagesize/$pagesperblock)."\n";
print "Datapos: ".join(",",@datapos)."\n";

open(IN,"<:raw",$dumpfn) || die "Could not open image file $dumpfn for reading: $!\n";
binmode IN;
my $ende=0;
my $pagen=0;


my %startpattern=("|Block"=>1,"P00000"=>1,"\x00\x00\x00\x00\x00\x00"=>1,"\x77\x77\x77\x77\x77\x77"=>1,"\xff\xff\xff\xff\xff\xff"=>1);

our %foundpattern=();


my $size=-s $dumpfn;

my $bestpattern=-1;
my $bestmatch=0;
my $bestoffset=0;

for(my $offset=0;$offset<$pagesize;$offset+=2)
{
  print "Loading block starts from dump at offset $offset...\n";
  for(my $pos=$offset;$pos<=($size-512);$pos+=$blocksize)
  {
    seek(IN,$pos,0);
    my $in="";
    my $read=read IN,$in,6;
    $foundpattern{$in}++;
  }
  print "Dump fully loaded.\n";

  my @sortedpat=sort {$foundpattern{$b} <=> $foundpattern{$a}} keys %foundpattern;
  my $npat=scalar(@sortedpat);
  print "Found $npat patterns sorted by occurance:\n";
  if($npat<10)
  {
    foreach(@sortedpat)
    {
      print bin2hex($_)." ".$foundpattern{$_}."\n";
    }
  }
  print "Analyzing for best 00 pattern:\n";
  my $max=$npat>30 ? 30 : $npat;
  $max-- if($max>1 && !($max&1));
  foreach my $i (0 .. $max-1)
  {
    my $thispattern=$sortedpat[$i];
    my $matches=0;
    foreach my $j (0 .. $max-1)
    {
      $matches++ if(defined($startpattern{$thispattern ^ $sortedpat[$j]}));
    }
    if($matches>$bestmatch)
    {
      print "Found better match: $i with $matches matches\n";
      $bestpattern=$thispattern;
      $bestmatch=$matches;
      $bestoffset=$offset;
    }
  }
  my $nbestpatterns=$foundpattern{$bestpattern};
  print "Best match found: $bestmatch at offset $bestoffset - ".bin2hex($bestpattern)." - Occurances: $nbestpatterns\n";
  if($bestmatch>=4)
  {
    print "We found all 5 patterns, we can stop searching.\n";
    last;
  }
}
print "Best pattern: ".bin2hex($bestpattern)." Best match: $bestmatch Best offset: $bestoffset\n";

print "Loading maximum $maximumblocks full blocks from dump...\n";
print "If it takes too much RAM and crashes, then please reduce the \$maximumblocks parameter in the script.\n";
our @majpatterns=();
for(my $pos=0;$pos<=($size-512);$pos+=$blocksize)
{
  seek(IN,$pos,0);
  my $in="";
  my $read=read IN,$in,$blocksize;
  if(substr($in,$bestoffset,6) eq $bestpattern)
  {
    seek(IN,$pos,0);
    read IN,$in,$blocksize;
    push @majpatterns,$in;
    last if(scalar(@majpatterns)>=$maximumblocks);
  }
}
print "Dump fully loaded.\n";

print "Calculating XOR pattern from ".scalar(@majpatterns)." patterns\n";

my $xorpattern=maj(@majpatterns);

open(OUT,">:raw",$xorfn) || die "Could not open XOR key file $xorfn for writing: $!\n";
binmode OUT;
print OUT $xorpattern;
close OUT;

print STDERR "Writing out final XOR pattern to $xorfn\n";
print STDERR "Done.\n";
