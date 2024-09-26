#!/usr/bin/perl -w

sub readfile($)
{
  if(open(RFIN,"<$_[0]"))
  {
    my $old=$/;
    undef $/;
    binmode RFIN;
    my $content=<RFIN>;
    $/=$old;
    close RFIN;
    return($content);
  }
  return "";
}
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

print "This XOR analyzer tool analyzes the patterns at the start of each page of a XOR key, in which pages/offsets does that pattern occur too?\n";
print "Usage: $0 <pagesize> <xor key filename>\n";

my $pagesize=$ARGV[0] || 18432;
my $xorkey=readfile($ARGV[1] || "01_01.dump.xor");

my $PAGES=length($xorkey)/$pagesize;
print "Pages: $PAGES\n";

foreach my $page(0 .. $PAGES-1)
{
  my $pat=substr($xorkey,$page*$pagesize,16);
  print "$page Searching for ".bin2hex($pat)."\n";


  my $ind=0;
  my $oldind=0;
  while(($ind=index($xorkey, $pat,$ind)) != -1) {
    print "$page found at $ind (".(int($ind/$pagesize))."/".($ind % $pagesize).") (+".($ind-$oldind).")\n";
    $oldind=$ind;
    $ind++;
  }
  print "Done with page $page\n";
}


