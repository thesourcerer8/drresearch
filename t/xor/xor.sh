echo "We create a 2000MB pattern image for a datasize of 512 bytes"
time perl ../../initpattern.pl pattern512.img 2000 512

time perl ../../lfsr.pl 1240 16

echo "We simulate writing the pattern to a NAND flash and dumping it with 8 parallel processes"
time perl ../../controllersim.pl pattern512.img "simulated(1240p).dump" "simulatedclean(1240p).dump" geo512.case -j 8 --XORfile 'lfsr_(1240p)_16b.xor' --ECCcoversClearSA --XORcoversECC --XORcoversSA
echo "We extract the relevant parts"
time perl ../../dumpextractrelevant.pl "simulated(1240p).dump" "upload(1240p).dump" pattern512.img.xml geo512.case
echo "We extract the generator matrix from the dump"
time perl ../../dump2g.pl upload\(1240p\).dump output.g pattern512.img.xml geo512.case

echo "We verify the extracted matrix against the original matrix:"
diff -q gmatrix_n4896_k4096_m800.g output.g

echo "Now we generate the decoder parameters"
python3 ../../g2h.py gmatrix_n4896_k4096_m800.g hmatrix_n4896_k4096_m800.h

echo "Now we decode the dump (fix the bit errors):"
python3 ../../dumpdecoder.py "simulated(1240p).dump" hmatrix_n4896_k4096_m800.h geo512.case "corrected(1240p).dump"

echo "Now we check the correct decoding:"
diff -q "simulatedclean(1240p).dump" "corrected(1240p).dump"
