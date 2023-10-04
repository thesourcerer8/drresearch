echo Create a 1MB Pattern:
#perl initpattern.pl nano.dump 1
echo Simulate the writing the pattern to a NAND controller and dumping the NAND Flash
#perl controllersim.pl nano.dump "nano(20p).dump" nano.case
echo Extract the necessary parts from the dump for reconstruction
python3 g2h.py gmatrix_n96_k64_m32.g hmatrix_n96_k64_m32.h
echo Now please upload the upload.dump to https://futureware.at/cgi-bin/eccupload
