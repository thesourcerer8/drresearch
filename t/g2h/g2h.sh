echo "This test case compares a g2h generated hmatrix with an original hmatrix in decoding"
time perl ../../initpattern.pl g2hpattern.img 1 512
time perl ../../controllersim.pl g2hpattern.img "g2hsimulated(20p).dump" "g2hclean(20p).dump" n64.case
dd "if=g2hsimulated(20p).dump" "of=g2hsimulatedshort(20p).dump" bs=20 count=5
dd "if=g2hclean(20p).dump" "of=g2hcleanshort(20p).dump" bs=20 count=5


python3 ../../g2h.py gmatrix_n128_k64_m64.g g2hmatrix_n128_k64_m64.h
time perl ../../optimizeh.pl g2hmatrix_n128_k64_m64.h optmatrix_n128_k64_m64.h
time perl ../../optimizeh2.pl g2hmatrix_n128_k64_m64.h opt2matrix_n128_k64_m64.h

#python3 ../../g2h.py gmatrix_n12000_k8192_m3808.g hmatrix_n12000_k8192_m3808.h

#echo "At first trying with the original matrix:"
#time python3 ../../dumpdecoder.py "g2hsimulatedshort(20p).dump" hmatrix_n128_k64_m64.h n64.case g2h-orighresolved.dump
#echo "Now trying the optimized version"
#time python3 ../../dumpdecoder.py "g2hsimulatedshort(20p).dump" optmatrix_n128_k64_m64.h n64.case g2h-optresolved.dump
#echo "Now trying to decode with the g2h matrix:"
#time python3 ../../dumpdecoder.py "g2hsimulatedshort(20p).dump" g2hmatrix_n128_k64_m64.h n64.case g2h-g2hresolved.dump
#echo "Both tests are done now. Please compare the results and the speed of both tries"
#diff -q g2h-orighresolved.dump g2h-g2hresolved.dump
