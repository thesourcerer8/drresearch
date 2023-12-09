#!/usr/bin/perl -w
use strict;
use File::Basename;
use List::MoreUtils qw(uniq);

my $debug=1;

if(scalar(@ARGV)<3)
{
  print "Usage: $0 <input.dump> <output.html> <casefile.case> <pages>\n";
  print "This tool generates a large-scale hex-dump of a dumpfile, where each page is one long line of hex, with SA, DA and ECC colored.\n";
  exit;
}


my $imagefn=$ARGV[0];
my $htmlfn=$ARGV[1];
my $casefn=$ARGV[2];
my $pages=$ARGV[3];

print "Dumping pages from a dump file \"$imagefn\" into an output HTML file \"$htmlfn\"\n";

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

our %fieldlabels=(); # Formatting for HTML outputs
our %bytelabels=();
our %byterange=();
our %bytecolor=();
our %linebreaks=();


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
      print "DATA found at $2\n";
      $datasize=$3-$2+1;
      $ecccoverage=$datasize;
      foreach my $p ($2 .. $2+$datasize-1)
      {
        $bytelabels{$p}="DATA";
        $bytecolor{$p}="#a0ffa0";
      }
      $byterange{$2}=$datasize;
    }
    if(m/<Record StructureDefinitionName="ECC" StartAddress="(\d+)" StopAddress="(\d+)" \/>/)
    {
      push @myeccpos,$1;
      print "ECC found at $1\n";
      $eccsize=$2-$1+1;
      foreach my $p ($1 .. $1+$eccsize-1)
      {
        $bytelabels{$p}="ECC";
        $bytecolor{$p}="#ffffa0";
      }
      $byterange{$1}=$eccsize;
    }
    if(m/<Record StructureDefinitionName="SA" StartAddress="(\d+)" StopAddress="(\d+)" \/>/)
    {
      push @mysapos,$1;
      print "SA found at $1\n";
      $sasize=$2-$1+1;
      foreach my $p ($1 .. $1+$sasize-1)
      {
        $bytelabels{$p}="SA";
        $bytecolor{$p}="#ffa0a0";
      }
      $byterange{$1}=$sasize;
    }
    @datapos=uniq @mydatapos;
    @eccpos=uniq @myeccpos;
    @sapos=uniq @mysapos;
  }
  #$sectors=scalar(@datapos)*$datasize;
  close CASE;
}


open(IN,"<:raw",$imagefn) || die "Could not open dump file $imagefn for reading: $!\n";
binmode IN;
open(OUT,">",$htmlfn) || die "Could not open output file $htmlfn for writing: $!\n";

print OUT "<html><body><pre>\n";
my $ende=0;
my $pagen=0;
my $outpages=0;

my $s=-s $imagefn;


sub msubstr # My SubString is a substr function that annotates the fields while substringing them
{
  $fieldlabels{$_[0]}{$_[1]}{$_[2]}=$_[3]||"?";
  $bytelabels{$_}=$_[3]||"?" foreach($_[1] .. $_[1]+$_[2]-1);
  if($_[1]>length($_[0]))
  {
    my ($package,$filename,$line,$subroutine) = caller(0);
    print STDERR "Error: substring out of range: length:".length($_[0])." pos:$_[1] wantedsize:$_[2] field:$_[3] ($package,$filename:$line - $subroutine)\n";
    return undef;
  }
  return substr($_[0],$_[1],$_[2]);
}
sub dumpAnnotatedHex($)
{
  my $value=$_[0];
  my $content="";
  #print "Starting loop:\n";
  my $prev="";
  foreach(0 .. length($value)-1)
  {
    $content.="<br/>".("&#160;" x $linebreaks{$_})  if($linebreaks{$_});
    my $this=$bytelabels{$_}||"";
    my $next=$bytelabels{$_+1}||"";
    $content.="<div title='$this $_' style='display: inline; background-color:".(defined($bytecolor{$_})?$bytecolor{$_}:$this?"yellow":"white").";'>" if($prev ne $this);
    $content.=sprintf("%02X",unpack("C",substr($value,$_,1)));
    $content.= $this eq $next ? "&#160;":"</div>&#160;";
    $prev=$this;
  }
  #print "Done.\n";
  $content.="\n";
  return $content;
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
# This function converts a binary string to its hex representation for debugging
sub bin2hexLF($)
{
  my $orig=$_[0];
  my $value="";
  return "" if(!defined($orig) || $orig eq "");
  foreach(0 .. length($orig)-1)
  {
    $value.="\n##" if(($_ % 100)==99);
    $value.=sprintf("%02X",unpack("C",substr($orig,$_,1)));
  }
  return $value;
}



print "Dump file size: $s (".($s/$pagesize)." pages)\n";

my $minpage=0;
my $maxpage=int($s/$pagesize);

if($pages=~m/^\d+$/)
{
  $minpage=0;
  $maxpage=$pages;
}
elsif($pages=~m/^(\d+)\-(\d+)$/)
{
  $minpage=$1;
  $maxpage=$2;
}

seek IN,$pagesize*$minpage,0;
$pagen=$minpage;

while(!$ende)
{
  my $in="";
  my $read=read IN,$in,$pagesize;
  last if(!defined($read) || !$read);
  if($pagen>=$minpage && $pagen<=$maxpage)
  {
    print OUT dumpAnnotatedHex($in);
  }

  $pagen++;
  last if($pagen>$maxpage);
  print STDERR "$pagen pages processed\n" if(!($pagen %100000));
}

close IN;
close OUT;

#print "Page Offsets for DATA: ".join(",",sort keys(%posfound))."\n";
print STDERR "Done.\n";
print "firefox $htmlfn\n";
