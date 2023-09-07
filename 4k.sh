echo "We create a 11000MB (11GB) pattern image for a 4096 Byte data area"
time perl initpattern.pl pattern4k.dump 11000 4096

echo "We simulate writing the pattern to a NAND flash and dumping it with 8 parallel processes"
time perl controllersim.pl pattern4k.dump "simulated(9156p).dump" "simulatedclean(9156p).dump" 4k.case -j 8

echo "We extract the relevant parts"
time perl dumpextractrelevant.pl "simulated(9156p).dump" "upload(9156p).dump" pattern4k.dump.xml

echo "We extract the generator matrix from the dump"
time perl dump2g.pl upload\(9156p\).dump output4k.g pattern4k.dump.xml 

echo "We verify the extracted matrix against the original matrix:"
hexdump -C output4k.g >output4k.g.hex
hexdump -C gmatrix_n36544_k32768_m3776.g >gmatrix_n36544_k32768_m3776.g.hex
diff gmatrix_n36544_k32768_m3776.g.hex output4k.g.hex 

echo "Now we generate the decoder parameters"
python3 g2h.py gmatrix_n36544_k32768_m3776.g hmatrix_n36544_k32768_m3776.h.npy

echo "Now we decode the dump (fix the bit errors):"
python3 dumpdecoder.py "simulated(9156p).dump" hmatrix_n36544_k32768_m3776.h.npy 4k.case "corrected(9156p).dump"

echo "Now we check the correct decoding:"
diff "simulatedclean(9156p).dump" "corrected(9156p).dump"

