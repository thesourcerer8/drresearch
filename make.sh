#!/bin/bash
perl xorspread.pl
for a in *.xor
do 
	perl tryxor.pl phiphi\ dump.zDb9mRTX.part "$a" >"$a.decoded"
done
