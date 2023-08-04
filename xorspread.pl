#!/usr/bin/perl -w

my $pagesize=$ARGV[0] || 18336;

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


foreach(<*.xor>)
{
  next if(m/^spread/);
  my $s=(-s $_);
  if(($s % $pagesize)==0)
  {
    print "Pagesize matches: $_\n";
  }
  else
  {
    #print "Pagesize DOES NOT match: $_\n";
    my $smaller=int($s/$pagesize)*$pagesize;
    #print "orig: $s smaller: $smaller\n";
    #system "cp \"$_\" \"spreadsmall_$_\"";
    #system "truncate -s $smaller \"spreadsmall_$_\"";
    my $larger=$smaller+$pagesize;
    #system "cp \"$_\" \"spreadlarge_$_\"";
    #system "truncate -s $larger \"spreadlarge_$_\"";

    my $orig=1; $orig=$1 if(m/\((\d+)b/);
    $orig=$1*1024 if(m/\((\d+)k/);
    my $n=int($s/$orig);
    my $xor=readfile($_);

    print "origkey:$s origpage:$orig n:$n xorlen:".length($xor)."\n";

    open OUT,">spread_$_";
    binmode OUT;
    if($orig>$pagesize)
    {
      print "We have to shorten\n";
      foreach my $i(0 .. $n-1)
      {
	print OUT substr($xor,$i*$orig,$pagesize);
      }
    }
    else
    {
      print "We have to fillup\n";	
      foreach my $i(0 .. $n-1)
      {
        print OUT substr($xor,$i*$orig,$orig).("\x00"x($pagesize-$orig));
      }
    }
    close OUT;
    my $resl=(-s "spread_$_");
    my $mod=$resl % $pagesize;
    print "resulting size:$resl mod:$mod\n";
  }
}
