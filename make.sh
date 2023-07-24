#!/bin/bash
perl xorspread.pl
for dump in *.dmp
do
  for xor in *.xor
  do 
  	perl tryxor.pl "$dump" "$xor"
  done
done
perl xorstat.pl
