all: initpattern.exe

initpattern.exe: initpattern.cpp
	x86_64-w64-mingw32-g++ -static initpattern.cpp -o initpattern.exe -Wall

test:
	perl initpattern.pl test.dump 3000
	perl controllersim.pl test.dump "simp(4000p).dump" 3000.case
	perl dumpextractrelevant.pl "simp(4000p).dump" "upload(4000p).dump" 4000
