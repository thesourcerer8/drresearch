#!/usr/bin/perl -w
use strict;

open OUT,">report.html";

sub sanitizeHTML($)
{
  my $v=$_[0];
  $v=~s/</&lt;/g;
  $v=~s/\n/<br\/>\n/g;
  return $v;
}

sub doCmd($)
{
  print OUT "<code><b>".$_[0]."</b></code>\n";
  my $res=`$_[0]`;
  print OUT "<pre>".$res."</pre><br/>\n";
}

sub analyzeH($$)
{
  my $title=$_[0];
  my $fn=$_[1];  
  system "convert -depth 1 -size 128x64 \"gray:$fn\" \"$fn.png\"";
  my $res=`python3 ../../dumpdecoder.py "g2hsimulatedshort(20p).dump" $fn n64.case resolved.dump`;
  print OUT "<img src='$fn.png'> $title<br/><pre>$res</pre>\n";
  print OUT "<b>Result: ".`diff -q resolved.dump \"g2hcleanshort(20p).dump\"`."</b><br/>\n";
}


print OUT "<html><head><title>g2h test report</title></head><body>";
print OUT "<h1>This test case compares a g2h generated hmatrix with an original hmatrix in decoding</h1>\n";

print OUT "<code><b>time perl ../../initpattern.pl g2hpattern.img 1 512</b></code>";
print OUT "<pre>".`ls -la g2hpattern.img`."</pre><br/>\n";

#print OUT "<code>".sanitizeHTML(`cat n64.case`)."</code><br/>\n";
print OUT "<code><b>time perl ../../controllersim.pl g2hpattern.img \"g2hsimulated(20p).dump\" \"g2hclean(20p).dump\" n64.case</b></code><br/>";
print OUT "<pre>".`ls -la g2hsimulated\\(20p\\).dump g2hclean\\(20p\\).dump`."</pre><br/>\n";


#print OUT "<code><b>python3 ../../g2h.py gmatrix_n128_k64_m64.g g2hmatrix_n128_k64_m64.h</b></code><br/>\n";
doCmd("python3 ../../g2h.py gmatrix_n128_k64_m64.g g2hmatrix_n128_k64_m64.h");

system 'convert -depth 1 -size 64x64 "gray:gmatrix_n128_k64_m64.g" gmatrix_n128_k64_m64.g.png';
print OUT "G-Matrix: <img src='gmatrix_n128_k64_m64.g.png'><br/>\n";

analyzeH("Original H-Matrix","hmatrix_n128_k64_m64.h");
analyzeH("G2H H-Matrix","g2hmatrix_n128_k64_m64.h");


#print OUT "<code><b>time perl ../../optimizeh.pl g2hmatrix_n128_k64_m64.h optmatrix_n128_k64_m64.h</b></code><br/>";
doCmd("perl ../../optimizeh.pl g2hmatrix_n128_k64_m64.h optmatrix_n128_k64_m64.h");

analyzeH("Optimized H-Matrix","optmatrix_n128_k64_m64.h");
analyzeH("Optimized H-Matrix2","opt2matrix_n128_k64_m64.h");


#echo "Both tests are done now. Please compare the results and the speed of both tries"

