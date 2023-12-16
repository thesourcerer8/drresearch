use strict;
use warnings;
use Getopt::Long;

sub run_command {
    my ($command) = @_;
    my $output = qx($command 2>&1);
    my $status = $? >> 8;
    return ($status, $output);
}

my $maxy = -1;
my $bw = 1;
my $help = 0;

GetOptions(
    'max_y=i' => \$maxy,
    'bw=i'    => \$bw,
    'help|?'  => \$help
);

if ($help) {
    print "How to use dmpview:\n";
    print "You can call dmpview without any arguments, then it will display all the .dmp files in the current directory.\n";
    print "You can specify single files to be displayed on the commandline.\n";
    print "Parameters:\n";
    print "  dmpview --max_y=100  -> display only the first 100 pages/records\n";
    print "  dmpview --bw=0  -> display the image as grayscale\n";
    print "  dmpview --bw=1 -> display the image as black\&white\n";
    exit;
}

my @fns = @ARGV;
@fns = <*.dmp> if (!@ARGV);

foreach my $fn (@fns) {

    my $pagesize = 512;
    $pagesize = $1 if ($fn =~ m/\((\d+)[bp].*?\)/);
    $pagesize = $1 / 8 if ($fn =~ m/_m(\d+)[_\.]/);
    $pagesize = $1 * 1024 if ($fn =~ m/\((\d+)[kK].*?\)/);
    $pagesize = $1 / 8 if ($fn =~ m/hmatrix_n(\d+)[_\.]/);

    my $fs = -s $fn;
    if (!defined($fs) || $fs <= 0) {
        print STDERR "Could not load file or file is empty: $fn\n";
        next;
    }
    my $bs = int($fs / $pagesize);
    my $rest = $fs % $pagesize;

    $maxy = $bs if ($maxy < 0);

    print "Warning: There is a rest at the end of the file: $rest Bytes (please check the pagesize!)\n" if ($rest);

    $pagesize *= 8 if ($bw);

    my $convert_cmd = qq{"C:\\Program Files\\ImageMagick-7.1.1-Q16-HDRI\\magick.exe"};
    my $cmd = "$convert_cmd -depth " . ($bw ? 1 : 8) . " -size $pagesize" . "x$maxy -extract $pagesize" . "x$maxy+0+0 \"gray:$fn\" output.png";
    system($cmd);
}
