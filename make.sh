#!/bin/bash
perl xorspread.pl
for a in *.xor
do 
	perl tryxor.pl "Sandisk(18336b_128p).dmp" "$a" >"$a.decoded"
done
perl xorstat.pl
