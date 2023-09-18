use strict;
use warnings;

use List::Util qw(reduce);
use vars qw($a $b);

my $pagesize=$ARGV[0] || 800;
my $blocksize=$ARGV[1] || 512;


print "$0 <pagesize> <blocksize>\n";
print "$0 $pagesize $blocksize\n";

print 'Taps: ', set_taps( 8, 7, 2, 1 ), "\n";
#print 'Seed: ', seed_lfsr( 1 ), "\n";

open OUT,">lfsr_($pagesize"."p)_$blocksize"."b.xor";
foreach my $page(0 .. $blocksize-1)
{
  seed_lfsr(1);
  read_lfsr() foreach(0 .. $page*2);
  foreach my $byte(0 .. $pagesize-1)
  {
    my $v=read_lfsr();
    print OUT pack("C",$v);
  }

}
close OUT;



BEGIN {
    my $tap_mask;
    my $lfsr = 0;

    sub read_lfsr {
        $lfsr = ($lfsr >> 1) ^ (-($lfsr & 1) & $tap_mask );

        return $lfsr;
    }

    sub seed_lfsr {
        $lfsr = shift || 0;
        $lfsr &= 0xFF;
    }

    sub set_taps {
        my @taps = @_;

        $tap_mask = reduce { $a + 2**$b } 0, @taps;

        $tap_mask >>= 1;

        $tap_mask &= 0xFF;

        return $tap_mask;
    }
}
