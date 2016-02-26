# FinalProject

Final project for ECE 485 Winter 2015

readQueue.c
This is the file with the main code we have done so far. Currently it parses the information from the input file, and enters a while loop to add it to the queue at the correct time.

utlist.h
We are using this C library to handle linear linked lists for us so that we don't have to manually program all of that (adding, removing, searching, etc. to the linear linked list). In our readQueue.c code we are using 2 linear linked lists, 1 for holding all of the input data from the input file, and the second for the DRAM's queue of commands.

test_cases.c
This is for holding all of our testcases, although right now there aren't any. But in this file we do have definitions for all the timing parameters as well as page numbers from the 2Gb_DDR3_SDRAM datasheet that correspond to timing diagrams.

README.txt
This is has where we got the external libraries (utlist.h) we are using as well as links to them and their documentation.

exInput.txt
This is the example input file from the final project assignment

2Gb_DDR3_SDRAM.pdf
This is the datasheet we were using that we got the definitions for the timing parameters from.
