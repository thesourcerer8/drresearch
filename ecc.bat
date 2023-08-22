echo Create a 3GB Pattern:
perl initpattern.pl pattern.dump 3000
echo Simulate the writing the pattern to a NAND controller and dumping the NAND Flash
perl controllersim.pl pattern.dump simulated.dump chooseyour.case
echo Extract the necessary parts from the dump for reconstruction
perl dumpextractrelevant.pl simulated.dump upload.dump 4000
echo Now please upload the upload.dump to https://futureware.at/cgi-bin/eccupload
