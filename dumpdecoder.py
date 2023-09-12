import LDPC_decoder as LDPCdecoder
import scipy.io as scio
import numpy as np
import multiprocessing
import sys
import re

## LDPC Decoder for NAND Flash dump files

if(len(sys.argv)<3):
    print("Usage: dumpdecoder.py <dumpfile.dump> <ldpcparameter.h> <geometry.case> <output.dump>")
    exit(0)


inputdump=sys.argv[1]
ldpcparam=sys.argv[2]
geometry=sys.argv[3]
outputdump=sys.argv[4]

#pagesize = 4000
#dataeccpos = [0, 1500]
#datasize=1024
#eccsize=476

pagesize = 20
datapos = [0]
eccpos = [512]
dataeccpos = [0]
datasize=8
eccsize=8

with open(geometry,"r") as geo:
	print("Reading values from geometry file "+geometry)
	dataeccpos=[]
	datapos=[]
	eccpos=[]
	for line in geo.readlines():
		if re.search('<Page_size>(\d+)<\/Page_size>',line):
			pagesize=int(re.search('<Page_size>(\d+)<\/Page_size>',line).group(1))
		se=re.search('<Record StructureDefinitionName="(DA|Data area)" StartAddress="(\d+)" StopAddress="(\d+)" \/>',line)
		if se:
			dataeccpos.append(int(se.group(2))) # obsolete
			datapos.append(int(se.group(2)))
			datasize=int(se.group(3))-int(se.group(2))+1
		se=re.search('<Record StructureDefinitionName="(ECC)" StartAddress="(\d+)" StopAddress="(\d+)" \/>',line)
		if se:
			eccpos.append(int(se.group(2)))
			eccsize=int(se.group(3))-int(se.group(2))+1
	if len(datapos)<1 or len(eccpos)<1:
		print("Error: The geometry case file "+geometry+" does not contain enough data/ecc structures!")
		exit(-1)


print("datapos: "+str(datapos))
print("eccpos: "+str(eccpos))
print("dataeccpos: "+str(dataeccpos))
print("pagesize: "+str(pagesize))
print("eccsize: "+str(eccsize))


## Noise
EbN = 3
print("EbN: "+str(EbN))

SNR_lin = 10**(EbN/10)
print("SNR_lin: "+str(SNR_lin))
No = 1.0/SNR_lin
print("No: "+str(No))
sigma = np.sqrt(No/2)
print("sigma: "+str(sigma))

n=int(re.search('_n(\d+)[_.]',ldpcparam).group(1))
print("n: "+str(n))

k=int(re.search('_k(\d+)[_.]',ldpcparam).group(1))
print("k: "+str(k))

m=int(re.search('_m(\d+)[_.]',ldpcparam).group(1))
print("m: "+str(m))


H=np.unpackbits(np.fromfile(ldpcparam,dtype=np.uint8),axis=None,bitorder='little').astype(np.float32).reshape(m,n)

with open(inputdump,"rb") as dump:
	with open(outputdump,"wb") as output:
		while dump:
			page = bytearray(dump.read(pagesize))
			for pos in dataeccpos:
				x = np.unpackbits(np.frombuffer(page[pos:pos+datasize+eccsize],dtype=np.uint8),axis=None,bitorder='little').astype(np.float32)
				#print("x: "+str(x))
				r = 2*x-1
				#print("r: "+str(r))
				#print("H: "+str(H))
				decoder = LDPCdecoder.decoder(H)
				#print("r: "+str(r))
				#print("size of r: "+str(r.shape))
				decoder.setInputMSA(r, sigma)
				
				# Get Hard-Bits
				w0 = r
				w0[w0 >= 0] = 1
				w0[w0 < 0] = 0
				w0 = np.array(w0, dtype = int)
				#ErrorUncoded = np.sum(w0 != x)
				#print("Amount of Bit Errors (uncoded) : %d " % ErrorUncoded)
				
				#MSA algorithm
				for n in range(0,200):
		    
					decoded, y = decoder.iterateMinimumSumAlgorithm()
					ErrorSPA = np.sum(y != x)
		
					print("Amount of Bit Errors (SPA) : %d " % ErrorSPA)
					if(decoded):
						break
		
				ErrorSPA = np.sum(y != x)
				print("Iterations:  %d  |  Amount of Bit Errors (SPA) : %d " % (n, ErrorSPA))
				#print("he")
				#print(y)
				#print("Original:")
				#print(u)
				page[pos:pos+datasize+eccsize]=np.packbits(decoded,axis=None,bitorder='little').tobytes()
			output.write(page)
		
