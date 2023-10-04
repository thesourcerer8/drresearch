echo "We create a 2500MB pattern image for a datasize of 1024 bytes"
time perl ../../initpattern.pl pattern1k.dump 2500 1024
echo "We simulate writing the pattern to a NAND flash and dumping it with 8 parallel processes"
time perl ../../controllersim.pl pattern1k.dump "simulated(4000p).dump" "simulatedclean(4000p).dump" chooseyour.case -j 8
echo "We extract the relevant parts"
time perl ../../dumpextractrelevant.pl "simulated(4000p).dump" "upload(4000p).dump" pattern1k.dump.xml
echo "We extract the generator matrix from the dump"
time perl ../../dump2g.pl upload\(4000p\).dump output.g pattern1k.dump.xml 

echo "We verify the extracted matrix against the original matrix:"
hexdump -C output.g >output.g.hex
hexdump -C gmatrix_n12000_k8192_m3808.g >gmatrix_n12000_k8192_m3808.g.hex
diff -q gmatrix_n12000_k8192_m3808.g.hex output.g.hex 

echo "Now we generate the decoder parameters"
python3 ../../g2h.py gmatrix_n12000_k8192_m3808.g hmatrix_n12000_k8192_m3808.h

echo "Now we decode the dump (fix the bit errors):"
python3 ../../dumpdecoder.py "simulated(4000p).dump" hmatrix_n12000_k8192_m3808.h chooseyour.case "corrected(4000p).dump"

echo "Now we check the correct decoding:"
diff -q "simulatedclean(4000p).dump" "corrected(4000p).dump"
