#!/usr/bin/perl -w
use strict;
use List::MoreUtils qw(uniq);
use Getopt::Long;
use File::Spec;

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

sub popcount($)
{
  return unpack("%32b*",$_[0]);
}

my $pagesize=4000; # Bytes
my $ecccoverage=1024; # Bytes
my @datapos=();
my $datasize=1024;
my @sapos=();
my $sasize=8;
my @eccpos=();
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

sub bin2ascii($)
{
  my $orig=$_[0];
  my $value="";
  return "" if(!defined($orig) || $orig eq "");
  foreach(0 .. length($orig)-1)
  {
    my $v=unpack("C",substr($orig,$_,1));
    $value.= ($v>=32 && $v < 128)?pack("C",$v):"_";
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

sub maj34(@) # 3/4 majority function to remove random noise in the ECC area, has a threshold of 3/4 if enough samples are given, 2/3 if only 3 samples are given and just returns the first sample if 1 or 2 samples are given
{
  my $v=scalar(@_);
  my $taken=$v&1?$v:$v-1;
  my $th=$v>3 ? int(($taken+1)*3/4) : int(($taken+1)*2/3);

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
print "Blocksize: ".($pagesize*$pagesperblock)."\n";
print "Datapos: ".join(",",@datapos)."\n";

open(IN,"<:raw",$dumpfn) || die "Could not open image file $dumpfn for reading: $!\n";
binmode IN;
my $ende=0;
my $pagen=0;


my %startpattern=("|Block"=>1,"P00000"=>1,"\x00\x00\x00\x00\x00\x00"=>1,"\x77\x77\x77\x77\x77\x77"=>1,"\xff\xff\xff\xff\xff\xff"=>1);

our %foundpattern=();
our %foundpos=();

my $size=-s $dumpfn;

my $nblocks=int($size/$blocksize);

my $bestpattern=-1;
my $bestmatch=0;
my $bestoffset=0;


sub searchBestPattern($$) # ($offset,$page)
{
  my ($offset,$page)=@_;
  %foundpattern=(); # The global hash gets emptied here, so it always contains the results from the latest run
  print "Loading block starts from dump at offset $offset in page $page...\n";
  for(my $pos=$offset+$page*$pagesize;$pos<=($size-512);$pos+=$blocksize)
  {
    seek(IN,$pos,0);
    my $in="";
    my $read=read IN,$in,6;
    $foundpattern{$in}++;
    $foundpos{$in}=$pos if(!defined($foundpos{$in}));
  }
  print "Dump fully loaded.\n";

  my @sortedpat=sort {$foundpattern{$b} <=> $foundpattern{$a}} keys %foundpattern;
  my $npat=scalar(@sortedpat);
  print "Found $npat patterns sorted by occurance:\n";
  if($npat<150)
  {
    foreach(@sortedpat)
    {
      print "Pattern ".bin2hex($_)." ".$foundpattern{$_}." ".int($foundpattern{$_}*$blocksize/1000/1000/1000)."GB\n";
    }
  }
  print "Analyzing for best 00 pattern in page $page:\n";
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
    if($matches>1)
    {
      print "Found match: $i with $matches matches: ".bin2hex($sortedpat[$i])."\n";
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
  $nbestpatterns="N/A" if(!defined($nbestpatterns));
  print "Best match found: $bestmatch at offset $bestoffset - ".bin2hex($bestpattern)." - Occurances: $nbestpatterns\n";
  if($bestmatch>=4)
  {
    print "We found all 5 patterns in page $page, we can stop searching.\n";
    return;
  }
}


print "Searching for the beginning of the first DATA area, where we can find all the patterns\n";
for(my $offset=0;$offset<$pagesize && $bestmatch<4;$offset+=2)
{
  searchBestPattern($offset,0);
}

print "Best pattern: ".bin2hex($bestpattern)." Best match: $bestmatch Best offset: $bestoffset\n";

my $goodblocks=0;
my $nearblocks=0;
my $remainingblocks=0;
my $flashblocks=0;
my %goodblockheaders=();

# Some statistics:
foreach my $pat(sort keys %startpattern)
{
  #$goodblocks+=$foundpattern{$pat^$bestpattern};
  $goodblockheaders{$pat^$bestpattern}=1;
  print "Orig: ".bin2hex($pat)." -> XORed: ".bin2hex($pat ^ $bestpattern)." Found: ".($foundpattern{$pat^$bestpattern}||"none")."\n";
}
my %stat=();
foreach my $pat(sort keys %foundpattern)
{
  my $res="";
  if(defined($goodblockheaders{$pat}))
  {
    $goodblocks+=$foundpattern{$pat};
    $res="GOOD";
  }
  elsif($pat eq"\x00\x00\x00\x00\x00\x00" || $pat eq "\xff\xff\xff\xff\xff\xff" || popcount($pat)<3 || popcount($pat ^"\xff\xff\xff\xff\xff\xff") < 3)
  {
    $flashblocks+=$foundpattern{$pat};
    $res="FLASH";
  }
  else
  {
    my $best=1000;
    foreach my $comp(keys %goodblockheaders)
    {
      my $num=popcount($pat ^ $comp);
      #print "Comparing ".bin2hex($pat)." with ".bin2hex($comp)." -> ".bin2hex($pat ^ $comp)." -> $num\n";
      $best=$num if($best>$num);
    }
    if($best<=2)
    {
      $nearblocks+=$foundpattern{$pat};
      $res="NEAR";
    }
    else
    {
      $remainingblocks+=$foundpattern{$pat};
      $res="UNKNOWN"; # -$best";
    }
  }
  $stat{$res}+=$foundpattern{$pat};
  print "Pattern ".bin2hex($pat)." ".bin2hex($pat^$bestpattern)."(".bin2ascii($pat^$bestpattern).") is $res and found ".$foundpattern{$pat}." times. Example: $foundpos{$pat}\n";
}
foreach(sort keys %stat)
{
  print "Stat: $_ $stat{$_} ".int($stat{$_}*$blocksize/1000/1000/1000)."GB\n";
}
print "Good pattern Blocks: $goodblocks\n00/FF Blocks: $flashblocks\nNear blocks: $nearblocks\nRemaining blocks: ".($nblocks-$goodblocks-$flashblocks-$nearblocks)."\n";

if($bestmatch<4)
{
  print "We could not find all 5 patterns in this dump, so we cannot automatically extract a XOR key from this dump.\n";
  print "This dump seems to be encrypted, not just XOR'ed.\n" if($stat{'UNKNOWN'} > $stat{'GOOD'}*10);
  exit;
}

my $imagefilename=File::Spec->rel2abs($dumpfn); $imagefilename=~s/ /%20/g;

print "Loading maximum $maximumblocks full blocks from dump...\n";
print "If it takes too much RAM and crashes, then please reduce the \$maximumblocks parameter in the script.\n";
our @majpatterns=();
for(my $pos=0;$pos<=($size-512);$pos+=$blocksize)
{
  #next if($imagefilename=~m/2258XT/ && $pos<=1572*$blocksize);
  #last if($imagefilename=~m/2258XT/ && $pos>1572*$blocksize); # Trying a workaround for a 2258XT dump to only use the first 4 blocks
  seek(IN,$pos,0);
  my $in="";
  my $read=read IN,$in,$bestoffset+6;
  if(substr($in,$bestoffset,6) eq $bestpattern)
  {
    seek(IN,$pos,0);
    read IN,$in,$blocksize;
    push @majpatterns,$in;
    print "XOR from block ".($pos/$blocksize).": http://localhost/cgi-bin/drresearch/xorviewer.pl?dump=$imagefilename&pagesize=$pagesize&pagesperblock=$pagesperblock&xormode=2&xoroffset=0&pagestart=".($pos/$pagesize)."&start=0\n";
    last if(scalar(@majpatterns)>=$maximumblocks);
  }
}
print "Dump fully loaded.\n";

print "Calculating XOR pattern from ".scalar(@majpatterns)." patterns\n";

my $xorpattern=maj34(@majpatterns);


print "Trying to improve the XOR key page by page...\n";

foreach my $page(1 .. $pagesperblock-1)
{
  print "Trying page $page\n";
  searchBestPattern($bestoffset,$page);
  print "Page $page Best pattern: ".bin2hex($bestpattern)." Best match: $bestmatch Best offset: $bestoffset\n";

  if($bestmatch>=4)
  {
    my @majpatterns=();
    for(my $pos=$page*$pagesize;$pos<=($size-512);$pos+=$blocksize)
    {
      seek(IN,$pos,0);
      my $in="";
      my $read=read IN,$in,$bestoffset+6;
      if(substr($in,$bestoffset,6) eq $bestpattern)
      {
        seek(IN,$pos,0);
        read IN,$in,$pagesize;
        push @majpatterns,$in;
        print "XOR from block ".($pos/$blocksize).": http://localhost/cgi-bin/drresearch/xorviewer.pl?dump=$imagefilename&pagesize=$pagesize&pagesperblock=$pagesperblock&xormode=2&xoroffset=0&pagestart=".($pos/$pagesize)."&start=0\n";
        last if(scalar(@majpatterns)>=$maximumblocks);
      }
    }
    my $maj=maj34(@majpatterns);
    if(substr($xorpattern,$page*$pagesize,$pagesize) ne $maj)
    {
      print "Improving XOR key for $page\n";
      substr($xorpattern,$page*$pagesize,$pagesize)=$maj;
    }
    else
    {
      print "XOR key was good for page $page\n";
    }
  }

}


print "XOR key generation complete.\n";

open(OUT,">:raw",$xorfn) || die "Could not open XOR key file $xorfn for writing: $!\n";
binmode OUT;
print OUT $xorpattern;
close OUT;

print "Writing out final XOR pattern to $xorfn\n";

if(scalar(@datapos)<1 || scalar(@sapos)<1 || scalar(@eccpos)<1)
{
  print "Analyzing the page areas...\n";

  my $blockpattern=0;
  my %sectorpositions=();
  my %blockpos=();
  for(my $pos=0;$pos<=($size-512);$pos+=$blocksize)
  {
    seek(IN,$pos,0);
    my $in="";
    my $read=read IN,$in,$bestoffset+6;
    if(substr($in,$bestoffset,6) eq ($bestpattern^'|Block'))
    {
      $blockpattern++;
      seek(IN,$pos,0);
      read IN,$in,$blocksize;
      $in^=$xorpattern;
      my $mypos=0;
      my $count=0;
      while(($mypos=index($in,'|Block',$mypos))>=0)
      {
	$count++;
	#print "Found |Block at $mypos -> ".($mypos % $pagesize)."\n";
	$sectorpositions{$mypos % $pagesize}++;
        $mypos+=511;
      }
      $blockpos{$count}=$pos;
      last if($blockpattern>2);
    }
  }
  my @sectorpos=sort {$a <=> $b} keys %sectorpositions;
  print "sectorpos: ".join(",",@sectorpos)."\n";
  foreach(@sectorpos)
  {
    push @datapos,$_ unless(defined($sectorpositions{$_-512}));
  }
  print "datapos: ".join(",",@datapos)."\n";
  $datasize=512;
  while(defined($sectorpositions{$datapos[0]+$datasize}))
  {
    $datasize+=512;
  }
  print "datasize: $datasize\n";

  my $bposk=0;
  foreach(keys %blockpos)
  {
    if($_>=$bposk)
    {
      $bposk=$_;
    }
  }
  my $bposv=$blockpos{$bposk}||0;
  my %bytevote=();
  my $nextpos=0;

  while($nextpos<$pagesize)
  {
    if(defined($sectorpositions{$nextpos}))
    {
      foreach($nextpos .. $nextpos+511)
      {
        $bytevote{$_}='DATA';
      }
      $nextpos+=512;
    }
    else
    {
      #print "Analyzing Byte $nextpos in the page: http://localhost/cgi-bin/drresearch/xorviewer.pl?dump=$imagefilename&pagesize=$pagesize&pagesperblock=$pagesperblock&xormode=0&xoroffset=0&pagestart=388224&start=$nextpos\n";
      my $pv="";
      foreach(0 .. $pagesperblock-2)
      {
        seek(IN,$bposv+$nextpos+$pagesize*$_,0);
	my $in="";
        read IN,$in,1;
        $pv.=$in;
      }
      my $n=length($pv);
      my $threshold=int($n/4);

      my %bitvotes=();
      foreach my $bit (0 .. 7)
      {
	my $bitkind='?';
        my $v=0;
        my $x=0;
        foreach(0 .. $n-1)
        {
          my $nv=vec($pv,($_<<3)+$bit,1);
	  if($v ne $nv)
	  {
            $x++;
	    $v=$nv;
	  }
	}
        $bitkind=$x>$threshold?'ECC':'SA';
	#print "x:$x->$bitkind ";
        $bitvotes{$bitkind}++;
      }
      #print "\n";
      my @bitvote=sort {$bitvotes{$a} <=> $bitvotes{$b}} keys %bitvotes;
      #print "Bits $nextpos:$_ = $bitvotes{$_} votes\n" foreach(@bitvote);
      $bytevote{$nextpos}=$bitvote[-1];
      #print "Decision: $nextpos=$bytevote{$nextpos}\n";
      $nextpos++;
    }
  }

  my @atype=();
  my @asize=();
  my @apos=();
  my $start=0;
  my $t=$bytevote{0};

  foreach(1 .. $pagesize-1)
  {
    if($t ne $bytevote{$_})
    {
      push @atype,$t;
      push @asize,$_-$start;
      push @apos,$start;
      $start=$_;
      $t=$bytevote{$_};
    }
  }
  foreach(1 .. scalar(@atype)-2)
  {
    if($atype[$_-1] eq $atype[$_+1] && $asize[$_]<8)
    {
      print "Detected a short anomaly at $apos[$_] with size $asize[$_] and type $atype[$_] between 2 $atype[$_-1]'s.\n";
      foreach my $p($apos[$_] .. $apos[$_]+$asize[$_]-1)
      {
        $bytevote{$p}=$atype[$_-1];
      }
    }
  }


  $start=0;
  $t=$bytevote{0};
  open CASE,">$dumpfn.discovered.case";
print CASE <<EOF
<?xml version="1.0"?>
<Project>
  <info>This is an artifical case file with values discovered by xorsearch</info>
  <Records>
EOF
;
  foreach(1 .. $pagesize-1)
  {
    if($t ne $bytevote{$_})
    {
      print "$start - ".($_-1)." : $t\n";
      print CASE "    <Record StructureDefinitionName=\"$t\" StartAddress=\"$start\" StopAddress=\"".($_-1)."\" />\n";
      $start=$_;
      $t=$bytevote{$_};
    }
  }
  my $pagem1=$pagesize-1;
  my $actualblocksize=$pagesize*$pagesperblock;
  print CASE <<EOF
  </Records>
  <Records>
    <Record StructureDefinitionName="Page" StartAddress="0" StopAddress="$pagem1" />
  </Records>
  <StructureDefinition Name="Page" Length="2" IsFindStructure="False" />
  <Page_size>$pagesize</Page_size>
  <Actual_block_size>$actualblocksize</Actual_block_size>
</Project>
EOF
;
  close CASE;
}

print "Done.\n";
