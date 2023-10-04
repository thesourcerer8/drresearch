echo This script is used for testing the correct loading/saving of known-good parameters and the correct decoding, and the decoding speed. It cannot be used for extracting the parameters since the simulated NAND flash has only one data area per page
echo "The geometry is: 8-DA 8-ECC 4-SA -> Total page size: 20 Bytes"

# This would be too big
#time perl ../../initpattern.pl n64pattern.dump 1800 
#time perl ../../controllersim.pl n64pattern.dump "n64simulated(1400p).dump" n64.case -j 8

# We only do 1 MB of dump and therefore we do not need paralellisation
time perl ../../initpattern.pl n64pattern.dump 1 512
time perl ../../controllersim.pl n64pattern.dump "n64simulated(1400p).dump" "n64clean(1400p).dump" n64.case

# The parameter extraction is not useful for this model since 
#time perl ../../dumpextractrelevant.pl "n64simulated(1400p).dump" "n64upload(1400p).dump" 1400
#time perl ../../dump2g.pl n64upload\(1400p\).dump n64.g n64pattern.dump.xml 
#hexdump -C n64output.g >n64output.g.hex
#hexdump -C gmatrix_n128_k64_m64.g >gmatrix_n128_k64_m64.g.hex
#diff -q gmatrix_n128_k64_m64.g.hex n64output.g.hex 
#python3 ../../g2h.py gmatrix_n128_k64_m64.g hmatrix_n128_k64_m64.h
python3 ../../dumpdecoder.py "n64clean(1400p).dump" hmatrix_n128_k64_m64.h n64.case "n64cleancorrected(1400p).dump"

python3 ../../dumpdecoder.py "n64simulated(1400p).dump" hmatrix_n128_k64_m64.h n64.case "n64corrected(1400p).dump"
diff -q "n64corrected(1400p).dump" "n64clean(1400p).dump"
