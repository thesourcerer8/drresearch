#!/usr/bin/perl
use strict;
use warnings;
use Fcntl qw(O_RDONLY O_WRONLY O_CREAT O_TRUNC);

my $file1 = $ARGV[0];
my $file2 = $ARGV[1];
my $outfile = $ARGV[2];

if (!defined $file1 || !defined $file2 || !defined $outfile) {
    die "Usage: $0 <file1> <file2> <outfile>\n";
}

my $size1 = -s $file1;
my $size2 = -s $file2;

if (!defined $size1) {
    die "Could not get size of $file1.\n";
}
if (!defined $size2) {
    die "Could not get size of $file2.\n";
}

sysopen(my $fh1, $file1, O_RDONLY) or die "Cannot open $file1: $!";
sysopen(my $fh2, $file2, O_RDONLY) or die "Cannot open $file2: $!";
sysopen(my $out, $outfile, O_WRONLY | O_CREAT | O_TRUNC) or die "Cannot open $outfile: $!";

binmode($fh1);
binmode($fh2);
binmode($out);

# 4 MB blocks
my $buffer_size = 1024 * 1024 * 4; 
my ($buf1, $buf2);
my $bytes_read1;
my $bytes_read2;

my $total_processed = 0;
my $last_print = 0;

print "Starting XOR process...\n";

while (1) {
    $bytes_read1 = sysread($fh1, $buf1, $buffer_size);
    $bytes_read2 = sysread($fh2, $buf2, $buffer_size);

    die "Read error on $file1: $!" unless defined $bytes_read1;
    die "Read error on $file2: $!" unless defined $bytes_read2;

    last if $bytes_read1 == 0 || $bytes_read2 == 0;

    my $min_read = $bytes_read1 < $bytes_read2 ? $bytes_read1 : $bytes_read2;
    
    if ($bytes_read1 != $bytes_read2) {
        $buf1 = substr($buf1, 0, $min_read);
        $buf2 = substr($buf2, 0, $min_read);
    }

    my $xor_res = $buf1 ^ $buf2;
    
    my $written = syswrite($out, $xor_res);
    die "Write error: $!" unless defined $written && $written == length($xor_res);
    
    $total_processed += $written;

    # Print progress every ~1GB
    if ($total_processed - $last_print >= 1024 * 1024 * 1024) {
        printf("Processed %.2f GB\n", $total_processed / (1024*1024*1024));
        $last_print = $total_processed;
    }
}

close($fh1);
close($fh2);
close($out);

print "XOR complete. Processed $total_processed bytes.\n";
