echo Create a 3GB Pattern:
perl initpattern.pl pattern.dump 3000 1024
echo Simulate the writing the pattern to a NAND controller and dumping the NAND Flash
perl controllersim.pl pattern.dump "simulated(4000p).dump" chooseyour.case
echo Extract the necessary parts from the dump for reconstruction
perl dumpextractrelevant.pl "simulated(4000p).dump" "upload(4000p).dump" 4000
echo "Now please provide the pattern.dump.xml and the upload(4000p).dump"
