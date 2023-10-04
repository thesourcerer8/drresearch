#!/bin/bash

cd n64
bash n64.sh &> n64.log &
cd ..

cd nano
bash nano.sh &> nano.log &
cd ..

cd tryall
bash tryall.sh &> tryall.log &
cd ..

cd g2h
bash g2h.sh &> g2h.log &
cd ..

cd 4k
bash 4k.sh &> 4k.log &
cd ..

cd empty
bash empty.sh &> empty.log &
cd ..

cd xor
bash xor.sh &> xor.log &
cd ..

