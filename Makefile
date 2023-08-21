all: initpattern.exe

initpattern.exe: initpattern.cpp
	x86_64-w64-mingw32-g++ -static initpattern.cpp -o initpattern.exe -Wall

test:
	perl initpattern.pl test.dump 3000
	perl controllersim.pl test.dump simp.dump 3000.case
