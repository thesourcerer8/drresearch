









#include <stdio.h>
//#include <conio.h>
#include <string.h>
#include <stdlib.h>


int DATA_AREA = 0;
int SA = 0;
int ECC = 0;
int PAGE_SIZE = 0;
char FIRST_ELEMENT[100] = ""; // FOR STRUCTURING THE PAGE //
char SECOND_ELEMENT[100] = ""; // FOR STRUCTURING THE PAGE //
char THIRD_ELEMENT[100] = ""; // FOR STRUCTURING THE PAGE //
float cycle_of_elements = 0; // FOR STRUCTURING THE PAGE //
char strDA[]="DA";
char strSA[]="SA";
char strECC[]="ECC";
char patch[1000]= "";
int x = 0;  // here x is the value that is subtracted from SA+DA+ECC to calculate number of 0 bytes
int zero_counter= 0; //Counts number of zeros to be filled
int xor_offset= 0;
int block_size = 576;
unsigned char* file_buffer = {0};
long file_length = 0;
                                                                                                                                                                


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
																	//MAIN//                                                                                                          //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

int main ()   
               {

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
																	//SIZE ASSIGNMENT//                                                                                               //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


//Enter values of DA SA ECC PAGESIZE//
printf("Enter Data Area size \n");

scanf("%d",&DATA_AREA);
printf("\n");

printf("Enter SA size \n");
scanf("%d",&SA);
printf("\n");

printf("Enter ECC size \n");
scanf("%d", &ECC);
printf("\n");

printf("Enter PAGE SIZE size \n");
scanf("%d",&PAGE_SIZE);
printf("\n");

printf("Entered value of Data Area = %d SA = %d  ECC = %d PAGE Size = %d\n",DATA_AREA,SA,ECC,PAGE_SIZE);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
																	//CYCLE COUNT//                                                                                                   //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//This program calulates how many times SA DA ECC is repeated//

cycle_of_elements = (PAGE_SIZE) / (DATA_AREA+SA+ECC);
printf("Total repetition of SA DA ECC is %f\n",cycle_of_elements);


printf("What do you wish to patch? SA OR DA OR ECC? \n");

scanf(" %10s", patch);


printf("Patching -%s- \n",patch);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
																	//STRUCTURE ASSIGNMENT//                                                                                          //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//This module asks user to enter the structure of page..EG DA SA ECC ,SA DA ECC etc etc.//

printf("Please assign the page structure. For example DA SA ECC and its combinations(caps))\n\n");

printf("Enter the first element in the page \n");
scanf(" %s", FIRST_ELEMENT);

printf("Enter the second element in the page \n");
scanf(" %s", SECOND_ELEMENT);

printf("Enter the third element in the page \n");
scanf(" %s", THIRD_ELEMENT);



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
																	//OPENING OF XOR KEY //                                                                                           //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//This Module opens the xor key and a outfile//
    const char* filename = "DA_9.dmp";

    // Open the file in binary mode
    FILE* file = fopen(filename, "rb");

    if (file == NULL) {
        printf("Error opening the file.\n");
        return 1;
    }

    // Move the file pointer to the end of the file
    fseek(file, 0, SEEK_END);

    // Get the length of the file by finding the position of the file pointer
     file_length = ftell(file);
      rewind(file);



    printf("The length of the file is: %ld bytes.\n", file_length);





    const char* filename2 = "outfile.dmp";

    // Open the file in binary mode
    FILE* file2 = fopen(filename2, "wb+");

    if (file2 == NULL) {
        printf("Error creating  the output file.\n");
        return 1;
    }






////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
																	//SA DA ECC OR ITS COMBINATIONS CASES//                                                                           //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//																	//CASE-I DA SA ECC//                                                                                              //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////




if(((!strcmp(FIRST_ELEMENT,strDA)) && !strcmp(SECOND_ELEMENT,strSA)) && !strcmp(THIRD_ELEMENT,strECC)  )  //DA SA ECC// CASE 1//
{
printf("\t\t CASE-1\n");


	if(!strcmp(patch,strECC) )
	{
	x = ECC;
	}
	
	else{
	if(!strcmp(patch,strDA))
	{
		x = DATA_AREA;
	}
	
	}

			if(!strcmp(patch,strSA))
			{
			x= SA ;
			}
	

	

//printf("value of x is %d \n",x);
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	         																PATCH ECC_CASE1                 DA SA ECC                                                                 //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

if(!strcmp(patch,strECC)) ///////PATCH FOR ECC IN CASE 1 BEGINS//
{

zero_counter =  DATA_AREA + SA + ECC - x ;

printf("Number of zerosbytes to be padded between each structure element is %d \n", zero_counter);


file_buffer = (unsigned char*)malloc(file_length);
    if (!file_buffer) {
        fclose(file);
        perror("Memory allocation failed");
        return 1;
    }

fread(file_buffer, 1, file_length, file);


int zeropadbuffer[zero_counter] = {0};


for (int p = 1 ; p<=block_size ; p++ )
{
for (int q = 1 ; q <= cycle_of_elements ; q++)
{
fwrite(zeropadbuffer, 1, DATA_AREA , file2);
fwrite(zeropadbuffer, 1, SA , file2);
fwrite(&file_buffer[xor_offset], 1, ECC, file2);

}
xor_offset = (ECC*p);
}
printf("OK! WE ARE PATCHING %s with the xor key \n",patch);
} //PATCH ECC FOR CASE 1 ENDS



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	         											ENDS ENDS ENDS ENDS		PATCH ECC_CASE1    ENDS ENDS ENDS ENDS                                                                //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////






////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	         																PATCH DA_CASE1  DA_SA_ECC                                                                                 //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////






if(!strcmp(patch,strDA)) ///////PATCH FOR DA IN CASE 1 BEGINS//
{

zero_counter =  DATA_AREA + SA + ECC - x ;

printf("Number of zerosbytes to be padded between each structure element is %d \n", zero_counter);


file_buffer = (unsigned char*)malloc(file_length);
    if (!file_buffer) {
        fclose(file);
        perror("Memory allocation failed");
        return 1;
    }

fread(file_buffer, 1, file_length, file);


int zeropadbuffer[zero_counter] = {0};


for (int p = 1 ; p<=block_size ; p++ )
{
for (int q = 1 ; q <= cycle_of_elements ; q++)
{
fwrite(&file_buffer[xor_offset], 1, DATA_AREA, file2);

fwrite(zeropadbuffer, 1, SA , file2);
fwrite(zeropadbuffer, 1, ECC , file2);
	
}
xor_offset = (DATA_AREA*p);
}
printf("OK! WE ARE DONE PATCHING %s with the xor key \n",patch);
} //PATCH DA FOR CASE 1 ENDS




////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	         										ENDS ENDS ENDS	    	PATCH DA_CASE1        ENDS ENDS ENDS                                                                      //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////






////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	         																PATCH SA_CASE1  DA_SA_ECC                                                                                 //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

if(!strcmp(patch , strSA)) ///////PATCH FOR SA IN CASE 1 BEGINS//
{

zero_counter =  DATA_AREA + SA + ECC - x ;

printf("Number of zerosbytes to be padded between each structure element is %d \n", zero_counter);


file_buffer = (unsigned char*)malloc(file_length);
    if (!file_buffer) {
        fclose(file);
        perror("Memory allocation failed");
        return 1;
    }

fread(file_buffer, 1, file_length, file);

xor_offset =0; 
int zeropadbuffer[zero_counter] = {0};


for (int p = 1 ; p<=block_size ; p++ )
{
for (int q = 1 ; q <= cycle_of_elements ; q++)
{

fwrite(zeropadbuffer, 1, DATA_AREA , file2);
fwrite(&file_buffer[xor_offset], 1, SA , file2);
fwrite(zeropadbuffer, 1, ECC , file2);
	
}
xor_offset = (SA*p);
}
} //PATCH ECC FOR CASE 1 ENDS




} 	//CASE 1 ENDS//

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//			        	//ENDS ENDS ENDS ENDS//			         	//CASE-I DA SA ECC//    //ENDS ENDS ENDS ENDS//                                                                   //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	











////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//																	//CASE-II SA DA ECC//                                                                                             //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////		

if(((!strcmp(FIRST_ELEMENT,strSA)) && !strcmp(SECOND_ELEMENT,strDA)) && !strcmp(THIRD_ELEMENT,strECC)  )  // SA DA ECC // CASE 1//
{
	
    printf("\t\t CASE-2\n");


	if(!strcmp(patch,strECC) )
	{
	x = ECC;
	}
	
	else{
	if(!strcmp(patch,strDA))
	{
		x = DATA_AREA;
	}
	
	}

			if(!strcmp(patch,strSA))
			{
			x= SA ;
			}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	       																PATCH ECC_CASE2      SA DA ECC                                                                                //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

if(!strcmp(patch,strECC)) ///////PATCH FOR ECC IN CASE 1 BEGINS//
{

zero_counter =  DATA_AREA + SA + ECC - x ;

printf("Number of zerosbytes to be padded between each structure element is %d \n", zero_counter);


file_buffer = (unsigned char*)malloc(file_length);
    if (!file_buffer) {
        fclose(file);
        perror("Memory allocation failed");
        return 1;
    }

fread(file_buffer, 1, file_length, file);


int zeropadbuffer[zero_counter] = {0};


for (int p = 1 ; p<=block_size ; p++ )
{
for (int q = 1 ; q <= cycle_of_elements ; q++)
{
fwrite(zeropadbuffer, 1, SA, file2);

fwrite(zeropadbuffer, 1, DATA_AREA , file2);
fwrite(&file_buffer[xor_offset], 1, ECC, file2);

}
xor_offset = (ECC*p);
}
printf("OK! WE ARE PATCHING %s with the xor key \n",patch);
} //PATCH ECC FOR CASE-2 ENDS

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	       									ENDS ENDS ENDS							PATCH ECC_CASE2      SA DA ECC       ENDS ENDS ENDS                                               //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////









////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	         																PATCH DA_CASE-2            SA DA ECC                                                                      //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////






if(!strcmp(patch,strDA)) ///////PATCH FOR DA IN CASE 2 BEGINS//
{

zero_counter =  DATA_AREA + SA + ECC - x ;

printf("Number of zerosbytes to be padded between each structure element is %d \n", zero_counter);


file_buffer = (unsigned char*)malloc(file_length);
    if (!file_buffer) {
        fclose(file);
        perror("Memory allocation failed");
        return 1;
    }

fread(file_buffer, 1, file_length, file);


int zeropadbuffer[zero_counter] = {0};


for (int p = 1 ; p<=block_size ; p++ )
{
for (int q = 1 ; q <= cycle_of_elements ; q++)
{
fwrite(zeropadbuffer, 1, SA, file2);	
fwrite(&file_buffer[xor_offset], 1, DATA_AREA, file2);
fwrite(zeropadbuffer, 1, ECC, file2);

	
}
xor_offset = (DATA_AREA*p);
}
printf("OK! WE ARE DONE PATCHING %s with the xor key \n",patch);
} //PATCH DA FOR CASE 1 ENDS




////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	         										ENDS ENDS ENDS	    	PATCH DA_CASE1        ENDS ENDS ENDS                                                                      //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	         																PATCH SA_CASE2  SA_DA_ECC                                                                                 //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
							if(!strcmp(patch , strSA)) ///////PATCH FOR SA IN CASE 1 BEGINS//
{

zero_counter =  DATA_AREA + SA + ECC - x ;

printf("Number of zerosbytes to be padded between each structure element is %d \n", zero_counter);


file_buffer = (unsigned char*)malloc(file_length);
    if (!file_buffer) {
        fclose(file);
        perror("Memory allocation failed");
        return 1;
    }

fread(file_buffer, 1, file_length, file);

xor_offset =0; 
int zeropadbuffer[zero_counter] = {0};


for (int p = 1 ; p<=block_size ; p++ )
{
for (int q = 1 ; q <= cycle_of_elements ; q++)
{
fwrite(&file_buffer[xor_offset], 1, SA , file2);
fwrite(zeropadbuffer, 1, DATA_AREA , file2);
fwrite(zeropadbuffer, 1, ECC , file2);
	
}
xor_offset = (SA*p);
}
} //PATCH ECC FOR CASE 1 ENDS




} 	//CASE 2 ENDS//

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//			        	//ENDS ENDS ENDS ENDS//			         	//CASE-II DA SA ECC//    //ENDS ENDS ENDS ENDS//                                                                   //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	





fclose(file);
fclose(file2);
free(file_buffer);
return 0;

}

