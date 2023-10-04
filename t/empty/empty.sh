echo "We try an empty case file which should be rejected"
perl ../../controllersim.pl patternempty.dump "simulated(4000p).dump" "simulatedclean(4000p).dump" empty.case

python3 ../../dumpdecoder.py "simulated(4000p).dump" hmatrix_n12000_k8192_m3808.h empty.case "corrected(4000p).dump"

